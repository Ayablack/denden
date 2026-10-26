import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../capture/quality_profile.dart';

/// Codificação do perfil: bitrate, fps e redução para caber na resolução.
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

/// Aplica o perfil ao envio de vídeo. Chamar **depois** da negociação: antes
/// dela o `scaleResolutionDownBy` fica guardado mas não chega ao codificador
/// (medido na Fase A).
///
/// Devolve `false` se o libwebrtc recusou. Até a correção do plugin (ver
/// `packages/flutter_webrtc/DENDEN.md`) ele dizia `true` e ignorava tudo.
Future<bool> tuneVideoSender(
  RTCRtpSender rtpSender,
  MediaStreamTrack track,
  QualityProfile p, {
  int? sourceWidth,
  int? sourceHeight,
}) async {
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
  return rtpSender.setParameters(params);
}
