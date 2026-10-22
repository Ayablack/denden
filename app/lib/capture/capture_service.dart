import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'quality_profile.dart';

/// Tela ou janela que pode ser transmitida.
class CaptureSource {
  const CaptureSource({
    required this.id,
    required this.name,
    required this.isWindow,
  });

  final String id;
  final String name;
  final bool isWindow;

  /// No Windows, o loopback do `flutter_webrtc` captura só o processo dono
  /// da janela. Tela inteira pega o som do PC todo (menos o DenDen), o que
  /// inclui a voz do Discord.
  bool get audioIsolated => isWindow;
}

Map<String, Object?> displayMediaConstraints(
  CaptureSource s,
  QualityProfile p, {
  required bool audio,
}) => {
  'video': {
    'deviceId': {'exact': s.id},
    // O plugin Windows lê com findDouble: inteiro seria ignorado.
    'mandatory': {'frameRate': p.frameRate.toDouble()},
  },
  'audio': audio,
};

/// Tamanho da fonte em pixels, quando se sabe. Para tela inteira é o
/// monitor; para janela não há como saber (o plugin não informa), e usar o
/// monitor reduziria demais uma janela menor que ele.
(int, int)? knownSourceSize(CaptureSource s, int displayWidth, int displayHeight) =>
    s.isWindow ? null : (displayWidth, displayHeight);

/// Piso de quadros por segundo: o SFU descarta trilha sem pacotes por 30 s,
/// e telas paradas quase não geram quadros.
int minFrameRate(QualityProfile p) => 5;

class CaptureService {
  MediaStream? _stream;

  Future<List<CaptureSource>> listSources() async {
    final sources = await desktopCapturer.getSources(
      types: [SourceType.Screen, SourceType.Window],
    );
    return [
      for (final s in sources)
        CaptureSource(
          id: s.id,
          name: s.name,
          isWindow: s.type == SourceType.Window,
        ),
    ];
  }

  Future<MediaStream> start(
    CaptureSource s,
    QualityProfile p, {
    bool audio = true,
  }) async {
    await stop();
    return _stream = await navigator.mediaDevices.getDisplayMedia(
      displayMediaConstraints(s, p, audio: audio),
    );
  }

  Future<void> stop() async {
    final stream = _stream;
    _stream = null;
    if (stream == null) return;
    for (final t in stream.getTracks()) {
      await t.stop();
    }
    await stream.dispose();
  }
}
