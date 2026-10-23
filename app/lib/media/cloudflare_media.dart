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
class CloudflareMedia {
  CloudflareMedia(this.api, this.key, {this.log});

  final WorkerApi api;
  final String key;
  final void Function(String)? log;

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
class Broadcast {
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
  final String roomCode;
  QualityProfile _profile;
  final int? _sourceWidth;
  final int? _sourceHeight;
  Timer? _timer;
  LinkState _state = LinkState.connecting;
  final _states = StreamController<LinkState>.broadcast();
  final _replies = StreamController<ReportReply>.broadcast();
  final _stats = StreamController<MediaStatsSnapshot>.broadcast();

  LinkState get state => _state;
  QualityProfile get profile => _profile;
  Stream<LinkState> get states => _states.stream;
  Stream<ReportReply> get replies => _replies.stream;
  Stream<MediaStatsSnapshot> get stats => _stats.stream;

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
        await tuneVideoSender(
          s,
          track!,
          p,
          sourceWidth: _sourceWidth,
          sourceHeight: _sourceHeight,
        );
      }
    }
  }

  Future<void> _report() async {
    try {
      final snap = parseStats(await _pc.getStats(), DateTime.now());
      if (!_stats.isClosed) _stats.add(snap);
      final reply = await _media.api.report(
        _media.key,
        roomCode,
        'publisher',
        snap.bytesSent,
      );
      if (!_replies.isClosed) _replies.add(reply);
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
class Viewing {
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

  LinkState get state => _state;
  Stream<LinkState> get states => _states.stream;
  Stream<MediaStatsSnapshot> get stats => _stats.stream;

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
      renderer.srcObject = stream;
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

  Future<void> leave() => _lock.run(() async {
    _timer?.cancel();
    renderer.srcObject = null;
    await _teardown(_pc);
    _set(LinkState.ended);
    await _states.close();
    await _stats.close();
  });
}
