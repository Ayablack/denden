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

/// Quadros por segundo pedidos ao capturador: o do perfil.
///
/// Medido em 2026-10-23 (monitor 1080p, fonte a 60 fps, jogo aberto): pedir
/// 120 ou ligar o relógio de 1 ms do Windows não mudou nada (~44 fps nos
/// dois casos) e gastou mais CPU. O limite é o custo da captura.
int captureFrameRate(QualityProfile p) => p.frameRate;

/// Com [excludeProcessId] (só na tela inteira), o som do PC vai sem a árvore
/// desse processo: é assim que o Discord fica de fora (plugin local, ver
/// `packages/flutter_webrtc/DENDEN.md`). [captureFps] troca o padrão de
/// [captureFrameRate] (modo de diagnóstico).
Map<String, Object?> displayMediaConstraints(
  CaptureSource s,
  QualityProfile p, {
  required bool audio,
  int? excludeProcessId,
  int? captureFps,
}) => {
  'video': {
    'deviceId': {'exact': s.id},
    // O plugin Windows lê com findDouble: inteiro seria ignorado.
    'mandatory': {'frameRate': (captureFps ?? captureFrameRate(p)).toDouble()},
  },
  'audio': audio && excludeProcessId != null
      ? {'excludeProcessId': excludeProcessId}
      : audio,
};

/// Tamanho da fonte em pixels, quando se sabe. Para tela inteira é o
/// monitor; para janela não há como saber (o plugin não informa), e usar o
/// monitor reduziria demais uma janela menor que ele.
(int, int)? knownSourceSize(
  CaptureSource s,
  int displayWidth,
  int displayHeight,
) => s.isWindow ? null : (displayWidth, displayHeight);

/// Piso de quadros por segundo: o SFU descarta trilha sem pacotes por 30 s,
/// e telas paradas quase não geram quadros.
int minFrameRate(QualityProfile p) => 5;

/// Erro de captura com código estável (para a interface) e texto claro.
class CaptureError implements Exception {
  const CaptureError(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CaptureError($code): $message';
}

typedef SourceListFn = Future<List<CaptureSource>> Function();
typedef DisplayMediaFn = Future<MediaStream> Function(
  Map<String, Object?> constraints,
);

/// Se a janela não existe mais, o plugin cai no áudio do **computador
/// inteiro** (Discord incluído). Por isso: conferir antes de capturar.
Future<void> ensureWindowExists(SourceListFn list, CaptureSource window) async {
  final current = await list();
  if (!current.any((s) => s.isWindow && s.id == window.id)) {
    throw CaptureError(
      'janela_inexistente',
      'A janela "${window.name}" não existe mais. Abra o jogo e escolha a '
          'janela de novo.',
    );
  }
}

class CaptureService {
  CaptureService({SourceListFn? sourceLister, DisplayMediaFn? getDisplayMedia})
    // Parâmetro nomeado não pode ser privado, então não dá `this._`.
    // ignore: prefer_initializing_formals
    : _sourceLister = sourceLister,
      _getDisplayMedia =
          getDisplayMedia ?? navigator.mediaDevices.getDisplayMedia;

  /// Só para testes; sem ele, lista as fontes reais do Windows.
  final SourceListFn? _sourceLister;
  final DisplayMediaFn _getDisplayMedia;
  MediaStream? _stream;

  Future<List<CaptureSource>> listSources() async {
    final lister = _sourceLister;
    if (lister != null) return lister();
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
    int? excludeProcessId,
    int? captureFps,
  }) async {
    await stop();
    if (s.isWindow && audio) await ensureWindowExists(listSources, s);
    return _stream = await _getDisplayMedia(
      displayMediaConstraints(
        s,
        p,
        audio: audio,
        excludeProcessId: excludeProcessId,
        captureFps: captureFps,
      ),
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
