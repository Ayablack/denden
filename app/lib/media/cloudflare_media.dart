import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../capture/quality_profile.dart';
import '../lab/sdp_hints.dart';
import '../lab/session_lock.dart';
import '../logging/sanitize.dart';
import '../rooms/worker_api.dart';
import '../usage/media_stats.dart';
import 'tuning.dart';

enum LinkState { connecting, live, reconnecting, ended }

/// O que as telas usam. `CloudflareMedia` é a versão real; os testes usam
/// uma falsa.
abstract class BroadcastHandle {
  String get roomCode;
  LinkState get state;
  Stream<LinkState> get states;
  Stream<ReportReply> get replies;
  Future<void> replaceVideo(
    MediaStreamTrack track,
    QualityProfile profile, {
    int? sourceWidth,
    int? sourceHeight,
  });
  Future<void> stop();
}

abstract class ViewingHandle {
  LinkState get state;
  Stream<LinkState> get states;
  Future<void> leave();
}

abstract class MediaPort {
  Future<BroadcastHandle> publish(
    MediaStream stream,
    QualityProfile profile, {
    int? sourceWidth,
    int? sourceHeight,
  });

  Future<ViewingHandle> watch(String code, RTCVideoRenderer renderer);
}

/// Nome de cada trilha publicada: o tipo, com sufixo se repetir. O espectador
/// pede as trilhas por esse nome à sessão de quem transmite.
List<LocalTrack> localTracksFromMids(List<(String?, String)> midsAndKinds) {
  final seen = <String, int>{};
  return [
    for (final (mid, kind) in midsAndKinds)
      () {
        if (mid == null || mid.isEmpty) {
          throw StateError('Trilha $kind sem mid depois da oferta.');
        }
        final n = (seen[kind] = (seen[kind] ?? 0) + 1);
        return LocalTrack(mid: mid, trackName: n == 1 ? kind : '$kind-$n');
      }(),
  ];
}

QualityProfile? profileFromWire(String name) =>
    QualityProfile.values.where((p) => p.name == name).firstOrNull;

const _reportEvery = Duration(seconds: 10);

/// Uma operação por vez em todo o app (ver `LoopbackSession`).
final _lock = SessionLock();

Future<RTCPeerConnection> _peer(IceServers ice) => createPeerConnection({
  'iceServers': ice,
  'bundlePolicy': 'max-bundle',
  'sdpSemantics': 'unified-plan',
});

LinkState _map(RTCPeerConnectionState s, LinkState current) => switch (s) {
  RTCPeerConnectionState.RTCPeerConnectionStateConnected => LinkState.live,
  RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
    LinkState.reconnecting,
  RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
  RTCPeerConnectionState.RTCPeerConnectionStateClosed => LinkState.ended,
  _ => current,
};

/// Mesma ordem do laboratório: nenhum retorno de chamada novo, tirar as
/// trilhas, fechar e liberar a conexão.
Future<void> _teardown(RTCPeerConnection pc) async {
  pc.onIceCandidate = null;
  pc.onTrack = null;
  pc.onConnectionState = null;
  for (final s in await pc.getSenders()) {
    try {
      await pc.removeTrack(s);
    } catch (_) {
      // Conexão já fechando: nada a tirar.
    }
  }
  await pc.close();
  await pc.dispose();
}

/// Publica e assiste pelo Cloudflare Realtime SFU, falando com o Worker.
class CloudflareMedia implements MediaPort {
  CloudflareMedia(this.api, this.key, {this.log});

  final WorkerApi api;
  final String key;
  final void Function(String)? log;

  @override
  Future<Broadcast> publish(
    MediaStream stream,
    QualityProfile profile, {
    int? sourceWidth,
    int? sourceHeight,
  }) => _lock.run(() async {
    final pc = await _peer(await api.iceServers(key));
    try {
      for (final track in stream.getTracks()) {
        await pc.addTransceiver(
          track: track,
          kind: track.kind == 'video'
              ? RTCRtpMediaType.RTCRtpMediaTypeVideo
              : RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendOnly,
            streams: [stream],
          ),
        );
      }
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      // Os mids só existem depois da oferta local: buscar de novo.
      final transceivers = await pc.getTransceivers();
      final tracks = localTracksFromMids([
        for (final t in transceivers) (t.mid, t.sender.track?.kind ?? 'video'),
      ]);
      final room = await api.createRoom(key, profile.name, offer.sdp!, tracks);
      await pc.setRemoteDescription(
        RTCSessionDescription(
          withBitrateHints(
            room.answerSdp,
            maxBitrateBps: profile.maxBitrateBps,
          ),
          'answer',
        ),
      );
      final b = Broadcast._(
        this,
        pc,
        room.code,
        profile,
        sourceWidth,
        sourceHeight,
      );
      await b._applyProfile(profile);
      b._start();
      return b;
    } catch (_) {
      await _teardown(pc);
      rethrow;
    }
  });

  @override
  Future<Viewing> watch(String code, RTCVideoRenderer renderer) =>
      _lock.run(() async {
        final normalized =
            normalizeRoomCode(code) ??
            (throw const RoomNotFound(
              404,
              'sala_inexistente',
              'Código inválido.',
            ));
        final pc = await _peer(await api.iceServers(key));
        try {
          final v = Viewing._(this, pc, normalized, renderer);
          pc.onTrack = v._onTrack;
          final joined = await api.joinRoom(key, normalized);
          await pc.setRemoteDescription(
            RTCSessionDescription(joined.offerSdp, 'offer'),
          );
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          await api.answer(key, normalized, joined.viewerId, answer.sdp!);
          v._viewerId = joined.viewerId;
          v._start();
          return v;
        } catch (_) {
          await _teardown(pc);
          rethrow;
        }
      });
}

/// Transmissão em andamento. Relata o consumo a cada 10 s e obedece ao
/// perfil que o Worker mandar (ex.: Economia quando o orçamento chega a 100%).
class Broadcast implements BroadcastHandle {
  Broadcast._(
    this._media,
    this._pc,
    this.roomCode,
    this._profile,
    this._sourceWidth,
    this._sourceHeight,
  );

  final CloudflareMedia _media;
  final RTCPeerConnection _pc;
  @override
  final String roomCode;
  QualityProfile _profile;
  int? _sourceWidth;
  int? _sourceHeight;
  bool _forcedEconomy = false;
  Timer? _timer;
  LinkState _state = LinkState.connecting;
  final _states = StreamController<LinkState>.broadcast();
  final _replies = StreamController<ReportReply>.broadcast();
  final _stats = StreamController<MediaStatsSnapshot>.broadcast();

  @override
  LinkState get state => _state;
  QualityProfile get profile => _profile;
  @override
  Stream<LinkState> get states => _states.stream;
  @override
  Stream<ReportReply> get replies => _replies.stream;
  Stream<MediaStatsSnapshot> get stats => _stats.stream;

  /// Estatísticas cruas da conexão (modo de diagnóstico).
  Future<List<StatsReport>> rawStats() => _pc.getStats();

  /// Parâmetros de codificação do vídeo, como o libwebrtc os guarda
  /// (modo de diagnóstico).
  Future<String> describeEncodings() async => [
    for (final s in await _pc.getSenders())
      if (s.track?.kind == 'video')
        for (final e in s.parameters.encodings ?? const <RTCRtpEncoding>[])
          'escala=${e.scaleResolutionDownBy} teto=${e.maxBitrate} '
              'fps=${e.maxFramerate} ativo=${e.active}',
  ].join(' | ');

  void _set(LinkState s) {
    if (s == _state || _state == LinkState.ended) return;
    _state = s;
    _states.add(s);
  }

  void _start() {
    _pc.onConnectionState = (s) => _set(_map(s, _state));
    _timer = Timer.periodic(_reportEvery, (_) => _report());
  }

  Future<void> _applyProfile(QualityProfile p) async {
    _profile = p;
    for (final s in await _pc.getSenders()) {
      final track = s.track;
      if (track?.kind == 'video') {
        final ok = await tuneVideoSender(
          s,
          track!,
          p,
          sourceWidth: _sourceWidth,
          sourceHeight: _sourceHeight,
        );
        // Transmite assim mesmo, só que sem o perfil: melhor que cair.
        if (!ok) _media.log?.call('perfil ${p.name} recusado pelo libwebrtc');
      }
    }
  }

  @override
  Future<void> replaceVideo(
    MediaStreamTrack track,
    QualityProfile profile, {
    int? sourceWidth,
    int? sourceHeight,
  }) => _lock.run(() async {
    if (sourceWidth != null) _sourceWidth = sourceWidth;
    if (sourceHeight != null) _sourceHeight = sourceHeight;
    final effective = _forcedEconomy ? QualityProfile.economy : profile;
    _profile = effective;
    for (final s in await _pc.getSenders()) {
      final old = s.track;
      if (old?.kind == 'video') {
        await s.replaceTrack(track);
        final ok = await tuneVideoSender(
          s,
          track,
          effective,
          sourceWidth: _sourceWidth,
          sourceHeight: _sourceHeight,
        );
        if (!ok) {
          _media.log?.call('perfil ${effective.name} recusado pelo libwebrtc');
        }
        if (old != null && old.id != track.id) {
          await old.stop();
        }
      }
    }
  });

  Future<void> _report() async {
    try {
      final snap = parseStats(await _pc.getStats(), DateTime.now());
      if (!_stats.isClosed) _stats.add(snap);
      final reply = await _media.api.report(
        _media.key,
        roomCode,
        'publisher',
        snap.bytesSent,
        profile: _profile.name,
      );
      if (!_replies.isClosed) _replies.add(reply);
      _forcedEconomy = reply.level == 'blocked' || reply.level == 'ceiling';
      final wanted = profileFromWire(reply.profile);
      if (wanted != null && wanted != _profile) await _applyProfile(wanted);
    } on RoomNotFound {
      // O Worker encerrou a sala (teto, emergência, queda).
      _set(LinkState.ended);
      _timer?.cancel();
    } catch (e, st) {
      _media.log?.call(describeError(e, st));
    }
  }

  @override
  Future<void> stop() => _lock.run(() async {
    _timer?.cancel();
    try {
      await _media.api.endRoom(_media.key, roomCode);
    } catch (_) {
      // Já encerrada ou sem rede: o Worker encerra por inatividade em 30 s.
    }
    await _teardown(_pc);
    _set(LinkState.ended);
    await _states.close();
    await _replies.close();
    await _stats.close();
  });
}

/// Assistindo uma sala. O vídeo vai para o [renderer]; o áudio toca sozinho.
class Viewing implements ViewingHandle {
  Viewing._(this._media, this._pc, this.roomCode, this.renderer);

  final CloudflareMedia _media;
  final RTCPeerConnection _pc;
  final String roomCode;
  final RTCVideoRenderer renderer;
  String? _viewerId;
  Timer? _timer;
  LinkState _state = LinkState.connecting;
  final _states = StreamController<LinkState>.broadcast();
  final _stats = StreamController<MediaStatsSnapshot>.broadcast();
  MediaStream? _remote;

  @override
  LinkState get state => _state;
  @override
  Stream<LinkState> get states => _states.stream;
  Stream<MediaStatsSnapshot> get stats => _stats.stream;

  /// Estatísticas cruas da conexão (modo de diagnóstico).
  Future<List<StatsReport>> rawStats() => _pc.getStats();

  /// Não tocar o som recebido (modo de diagnóstico, que assiste no mesmo PC).
  Future<void> muteAudio() async {
    for (final r in await _pc.getReceivers()) {
      final track = r.track;
      if (track?.kind == 'audio') track!.enabled = false;
    }
  }

  void _set(LinkState s) {
    if (s == _state || _state == LinkState.ended) return;
    _state = s;
    _states.add(s);
  }

  void _onTrack(RTCTrackEvent e) {
    final stream = e.streams.isNotEmpty ? e.streams.first : null;
    if (stream == null) return;
    // O SFU pode entregar áudio e vídeo em streams separados; o vídeo manda
    // no renderizador, o áudio toca de qualquer jeito.
    if (e.track.kind == 'video' || _remote == null) {
      _remote = stream;
      // Pela trilha: o plugin não acha o stream remoto do SFU e a imagem
      // ficava em branco (ver packages/flutter_webrtc/DENDEN.md).
      unawaited(
        renderer.setSrcObject(
          stream: stream,
          trackId: e.track.kind == 'video' ? e.track.id : null,
        ),
      );
    }
  }

  void _start() {
    _pc.onConnectionState = (s) => _set(_map(s, _state));
    _timer = Timer.periodic(_reportEvery, (_) => _report());
  }

  Future<void> _report() async {
    final id = _viewerId;
    if (id == null) return;
    try {
      final snap = parseStats(await _pc.getStats(), DateTime.now());
      if (!_stats.isClosed) _stats.add(snap);
      await _media.api.report(_media.key, roomCode, id, snap.bytesReceived);
    } on RoomNotFound {
      _set(LinkState.ended);
      _timer?.cancel();
    } catch (e, st) {
      _media.log?.call(describeError(e, st));
    }
  }

  @override
  Future<void> leave() => _lock.run(() async {
    _timer?.cancel();
    renderer.srcObject = null;
    await _teardown(_pc);
    _set(LinkState.ended);
    await _states.close();
    await _stats.close();
  });
}
