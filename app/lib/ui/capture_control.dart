import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../capture/capture_service.dart';
import '../capture/hybrid_capture.dart';
import '../capture/quality_profile.dart';
import '../rooms/worker_api.dart';

/// O que a tela de transmitir precisa da captura. A versão real usa a
/// captura híbrida: vídeo da tela, áudio só da janela escolhida.
abstract class CaptureControl {
  Future<List<CaptureSource>> listSources();

  /// Sem [audioWindow], transmite sem áudio. Nunca captura o áudio geral do
  /// computador (a voz do Discord iria junto).
  Future<MediaStream> start(
    CaptureSource screen,
    CaptureSource? audioWindow,
    QualityProfile p,
  );

  Future<void> stop();

  /// Ex.: `janela_fechou`.
  Stream<CaptureError> get errors;
}

class RealCaptureControl implements CaptureControl {
  final _capture = CaptureService();
  final _hybrid = HybridCapture();

  @override
  Future<List<CaptureSource>> listSources() => _capture.listSources();

  @override
  Future<MediaStream> start(
    CaptureSource screen,
    CaptureSource? audioWindow,
    QualityProfile p,
  ) => audioWindow == null
      ? _capture.start(screen, p, audio: false)
      : _hybrid.start(screen: screen, audioWindow: audioWindow, profile: p);

  @override
  Future<void> stop() async {
    await _capture.stop();
    await _hybrid.stop();
  }

  @override
  Stream<CaptureError> get errors => _hybrid.errors;
}

/// Mensagem para a pessoa, sem detalhes técnicos nem chaves.
String messageFor(Object e) => switch (e) {
  WorkerError(:final message) => message,
  CaptureError(:final message) => message,
  _ => 'Algo deu errado. Tente de novo.',
};
