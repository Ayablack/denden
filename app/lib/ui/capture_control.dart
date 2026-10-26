import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../capture/capture_service.dart';
import '../capture/hybrid_capture.dart';
import '../capture/pc_sem_discord.dart';
import '../capture/quality_profile.dart';
import '../rooms/worker_api.dart';

/// De onde vem o som da transmissão.
sealed class AudioChoice {
  const AudioChoice();
}

/// O som do PC todo, menos o Discord (padrão).
class PcAudio extends AudioChoice {
  const PcAudio();
}

/// Só o som de uma janela (ex.: o jogo).
class WindowAudio extends AudioChoice {
  const WindowAudio(this.window);

  final CaptureSource window;

  @override
  bool operator ==(Object other) =>
      other is WindowAudio && other.window.id == window.id;

  @override
  int get hashCode => window.id.hashCode;
}

class NoAudio extends AudioChoice {
  const NoAudio();
}

/// O que a tela de transmitir precisa da captura: vídeo da tela inteira e o
/// som escolhido em [AudioChoice]. A voz do Discord nunca vai junto.
abstract class CaptureControl {
  Future<List<CaptureSource>> listSources();

  Future<MediaStream> start(
    CaptureSource screen,
    AudioChoice audio,
    QualityProfile p,
  );

  Future<void> stop();

  /// Ex.: `janela_fechou`, `discord_fora`.
  Stream<CaptureError> get errors;
}

class RealCaptureControl implements CaptureControl {
  RealCaptureControl() {
    _hybrid.errors.listen(_errors.add);
    _pc.errors.listen(_errors.add);
  }

  final _capture = CaptureService();
  final _hybrid = HybridCapture();
  final _pc = PcWithoutDiscordCapture();
  final _errors = StreamController<CaptureError>.broadcast();

  @override
  Future<List<CaptureSource>> listSources() => _capture.listSources();

  @override
  Future<MediaStream> start(
    CaptureSource screen,
    AudioChoice audio,
    QualityProfile p,
  ) => switch (audio) {
    PcAudio() => _pc.start(screen, p),
    WindowAudio(:final window) => _hybrid.start(
      screen: screen,
      audioWindow: window,
      profile: p,
    ),
    NoAudio() => _capture.start(screen, p, audio: false),
  };

  @override
  Future<void> stop() async {
    await _capture.stop();
    await _hybrid.stop();
    await _pc.stop();
  }

  @override
  Stream<CaptureError> get errors => _errors.stream;
}

/// Mensagem para a pessoa, sem detalhes técnicos nem chaves.
String messageFor(Object e) => switch (e) {
  WorkerError(:final message) => message,
  CaptureError(:final message) => message,
  _ => 'Algo deu errado. Tente de novo.',
};
