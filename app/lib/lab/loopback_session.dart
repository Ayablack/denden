import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../capture/quality_profile.dart';
import 'sdp_hints.dart';
import 'session_lock.dart';

enum LoopbackState { connecting, connected, disconnected, closed }

RTCRtpEncoding encodingFor(
  QualityProfile p, {
  int? sourceWidth,
  int? sourceHeight,
}) => RTCRtpEncoding(
  active: true,
  maxBitrate: p.maxBitrateBps,
  maxFramerate: p.frameRate,
  scaleResolutionDownBy: sourceWidth == null || sourceHeight == null
      ? 1.0
      : scaleDownFor(p, sourceWidth, sourceHeight),
);

/// Duas conexões WebRTC no mesmo processo, sem servidor: valida captura,
/// codificação e reprodução (Fase A). **Não** comprova a transmissão pelo
/// SFU, que é da Fase B.
class LoopbackSession {
  LoopbackSession._(this.sender, this.receiver, this.remoteRenderer);

  final RTCPeerConnection sender;
  final RTCPeerConnection receiver;
  final RTCVideoRenderer remoteRenderer;

  final _states = StreamController<LoopbackState>.broadcast();
  LoopbackState _state = LoopbackState.connecting;

  LoopbackState get state => _state;
  Stream<LoopbackState> get states => _states.stream;

  /// Uma operação por vez em todo o app: uma sessão só começa depois que a
  /// anterior terminou de liberar tudo. Medido: abrir a 2ª sessão logo após
  /// encerrar a 1ª derrubava o processo (0xC0000005 na worker_thread do
  /// WebRTC) sob o `flutter test`.
  static final _lock = SessionLock();

  bool _closing = false;

  static Future<LoopbackSession> start(
    MediaStream captured,
    QualityProfile p, {
    int? sourceWidth,
    int? sourceHeight,
  }) => _lock.run(
    () => _start(
      captured,
      p,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    ),
  );

  static Future<LoopbackSession> _start(
    MediaStream captured,
    QualityProfile p, {
    int? sourceWidth,
    int? sourceHeight,
  }) async {
    const config = {'iceServers': [], 'sdpSemantics': 'unified-plan'};
    final sender = await createPeerConnection(config);
    final receiver = await createPeerConnection(config);
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    final session = LoopbackSession._(sender, receiver, renderer);

    // Candidatos atrasados não podem chegar a uma conexão em encerramento.
    sender.onIceCandidate = (c) {
      if (c.candidate == null || session._closing) return;
      receiver.addCandidate(c).catchError((Object _) {});
    };
    receiver.onIceCandidate = (c) {
      if (c.candidate == null || session._closing) return;
      sender.addCandidate(c).catchError((Object _) {});
    };
    receiver.onTrack = (e) {
      if (e.streams.isNotEmpty) renderer.srcObject = e.streams.first;
    };
    receiver.onConnectionState = session._onPcState;

    // Qualquer falha daqui para baixo fecha tudo; senão sobram conexões
    // nativas a cada "Iniciar" que falhar.
    try {
      // Vídeo e áudio no mesmo stream: o WebRTC sincroniza os dois.
      final video = <(RTCRtpSender, MediaStreamTrack)>[];
      for (final track in captured.getTracks()) {
        final rtpSender = await sender.addTrack(track, captured);
        if (track.kind == 'video') video.add((rtpSender, track));
      }

      final offer = await sender.createOffer();
      await sender.setLocalDescription(offer);
      await receiver.setRemoteDescription(offer);
      final answer = await receiver.createAnswer();
      await receiver.setLocalDescription(answer);
      await sender.setRemoteDescription(
        RTCSessionDescription(
          withBitrateHints(answer.sdp!, maxBitrateBps: p.maxBitrateBps),
          answer.type,
        ),
      );
      // Só depois da negociação: antes dela, o scaleResolutionDownBy fica
      // guardado nos parâmetros mas não chega ao codificador (medido).
      for (final (rtpSender, track) in video) {
        await session._tune(rtpSender, track, p, sourceWidth, sourceHeight);
      }
    } catch (_) {
      await session._teardown();
      rethrow;
    }
    return session;
  }

  Future<void> _tune(
    RTCRtpSender rtpSender,
    MediaStreamTrack track,
    QualityProfile p,
    int? sourceWidth,
    int? sourceHeight,
  ) async {
    // No Windows o getSettings não existe: vale o tamanho informado (tela).
    var w = sourceWidth;
    var h = sourceHeight;
    try {
      final s = track.getSettings();
      w = (s['width'] as num?)?.toInt() ?? w;
      h = (s['height'] as num?)?.toInt() ?? h;
    } catch (_) {
      // getSettings não existe em todas as plataformas nativas.
    }
    final params = rtpSender.parameters;
    params.encodings = [encodingFor(p, sourceWidth: w, sourceHeight: h)];
    // Jogo rápido: preferir manter a taxa de quadros a manter a resolução.
    params.degradationPreference = RTCDegradationPreference.MAINTAIN_FRAMERATE;
    await rtpSender.setParameters(params);
  }

  /// Mesma regra do `WebRtcPeerLink` do AppMusica: depois de conectar,
  /// queda é "desconectado", não "conectando".
  void _onPcState(RTCPeerConnectionState s) {
    final next = switch (s) {
      RTCPeerConnectionState.RTCPeerConnectionStateConnected =>
        LoopbackState.connected,
      RTCPeerConnectionState.RTCPeerConnectionStateClosed =>
        LoopbackState.closed,
      RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
      RTCPeerConnectionState.RTCPeerConnectionStateFailed =>
        LoopbackState.disconnected,
      _ =>
        _state == LoopbackState.connecting
            ? LoopbackState.connecting
            : LoopbackState.disconnected,
    };
    if (next == _state || _state == LoopbackState.closed) return;
    _state = next;
    _states.add(next);
  }

  Future<void> close() => _lock.run(() async {
    if (_closing) return;
    await _teardown();
    if (_state != LoopbackState.closed) {
      _state = LoopbackState.closed;
      _states.add(LoopbackState.closed);
    }
    await _states.close();
  });

  /// Ordem de encerramento: nenhum retorno de chamada novo, tirar as trilhas
  /// do envio, fechar e liberar as conexões e só então o renderizador. A
  /// captura é parada por quem a abriu, depois disto.
  Future<void> _teardown() async {
    _closing = true;
    for (final pc in [sender, receiver]) {
      pc.onIceCandidate = null;
      pc.onTrack = null;
      pc.onConnectionState = null;
    }
    for (final s in await sender.getSenders()) {
      await sender.removeTrack(s);
    }
    remoteRenderer.srcObject = null;
    await sender.close();
    await receiver.close();
    await sender.dispose();
    await receiver.dispose();
    await remoteRenderer.dispose();
  }
}
