import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'capture_service.dart';
import 'quality_profile.dart';

typedef LocalStreamFn = Future<MediaStream> Function(String label);
typedef HybridCaptureError = CaptureError;

/// Vídeo da tela inteira (captura DirectX, rápida) com o áudio só do
/// processo de uma janela (sem a voz do Discord).
///
/// No plugin Windows o loopback de áudio é um só e para no `OnStop` de
/// qualquer captura de vídeo. Por isso o vídeo da janela não é parado: fica
/// vivo a 1 fps, desligado e fora do stream enviado.
///
/// Se a janela não existe, o plugin cai no áudio do computador inteiro.
/// Por isso a janela é conferida antes de iniciar e vigiada durante a
/// transmissão: se ela some, o áudio para e [errors] avisa.
class HybridCapture {
  HybridCapture({
    DisplayMediaFn? getDisplayMedia,
    LocalStreamFn? createStream,
    SourceListFn? listSources,
    this.watchEvery = const Duration(seconds: 2),
  }) : _getDisplayMedia =
           getDisplayMedia ?? navigator.mediaDevices.getDisplayMedia,
       _createStream = createStream ?? createLocalMediaStream,
       _listSources = listSources ?? CaptureService().listSources;

  final DisplayMediaFn _getDisplayMedia;
  final LocalStreamFn _createStream;
  final SourceListFn _listSources;
  final Duration watchEvery;

  final _owned = <MediaStream>[];
  final _errors = StreamController<HybridCaptureError>.broadcast();
  MediaStream? _audioSource;
  CaptureSource? _window;
  Timer? _watch;
  bool _checking = false;
  final _alreadyStopped = <String>{};

  /// Erros durante a transmissão, ex.: `janela_fechou`.
  Stream<HybridCaptureError> get errors => _errors.stream;

  /// O áudio da janela ainda está sendo capturado.
  bool get audioActive => _audioSource != null;

  Future<MediaStream> start({
    required CaptureSource screen,
    required CaptureSource audioWindow,
    required QualityProfile profile,
  }) async {
    if (screen.isWindow) {
      throw ArgumentError.value(screen.name, 'screen', 'precisa ser uma tela');
    }
    if (!audioWindow.isWindow) {
      throw ArgumentError.value(
        audioWindow.name,
        'audioWindow',
        'precisa ser uma janela',
      );
    }
    await stop();
    await ensureWindowExists(_listSources, audioWindow);
    try {
      final video = await _getDisplayMedia(
        displayMediaConstraints(screen, profile, audio: false),
      );
      _owned.add(video);
      final audioSource = await _getDisplayMedia({
        'video': {
          'deviceId': {'exact': audioWindow.id},
          'mandatory': {'frameRate': 1.0},
        },
        'audio': true,
      });
      _owned.add(audioSource);
      final audioTracks = audioSource.getAudioTracks();
      if (audioTracks.isEmpty) {
        throw const HybridCaptureError(
          'sem_audio',
          'A janela escolhida não entregou áudio.',
        );
      }
      for (final t in audioSource.getVideoTracks()) {
        t.enabled = false;
      }
      final combined = await _createStream('denden-hibrido');
      _owned.add(combined);
      await combined.addTrack(video.getVideoTracks().first);
      await combined.addTrack(audioTracks.first);
      _audioSource = audioSource;
      _window = audioWindow;
      _watch = Timer.periodic(watchEvery, (_) => _checkWindow());
      return combined;
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> _checkWindow() async {
    final window = _window;
    if (_checking || window == null || _audioSource == null) return;
    _checking = true;
    try {
      await ensureWindowExists(_listSources, window);
    } on CaptureError {
      if (_window == window) await _loseAudio(window);
    } catch (_) {
      // Falha ao listar janelas não é motivo para parar o áudio.
    } finally {
      _checking = false;
    }
  }

  /// Para a captura da janela inteira (vídeo e áudio): o `OnStop` do plugin
  /// derruba o loopback, e nada cai no áudio geral. O vídeo da tela segue.
  Future<void> _loseAudio(CaptureSource window) async {
    final audioSource = _audioSource;
    _audioSource = null;
    _watch?.cancel();
    _watch = null;
    if (audioSource == null) return;
    for (final t in audioSource.getTracks()) {
      _alreadyStopped.add(t.id ?? '');
      await t.stop();
    }
    _errors.add(
      HybridCaptureError(
        'janela_fechou',
        'A janela "${window.name}" fechou. O áudio foi interrompido para não '
            'capturar o som do computador inteiro.',
      ),
    );
  }

  Future<void> stop() async {
    _watch?.cancel();
    _watch = null;
    _window = null;
    _audioSource = null;
    final owned = List.of(_owned);
    _owned.clear();
    // Trilhas já paradas por _loseAudio não são paradas de novo.
    final stopped = {..._alreadyStopped};
    _alreadyStopped.clear();
    for (final s in owned) {
      for (final t in s.getTracks()) {
        if (stopped.add(t.id ?? '')) await t.stop();
      }
    }
    for (final s in owned) {
      await s.dispose();
    }
  }
}
