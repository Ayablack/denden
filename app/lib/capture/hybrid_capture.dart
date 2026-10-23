import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'capture_service.dart';
import 'quality_profile.dart';

typedef DisplayMediaFn = Future<MediaStream> Function(
  Map<String, Object?> constraints,
);
typedef LocalStreamFn = Future<MediaStream> Function(String label);

class HybridCaptureError implements Exception {
  const HybridCaptureError(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'HybridCaptureError($code): $message';
}

/// EXPERIMENTO: vídeo da tela inteira (captura DirectX, rápida) com o áudio
/// só do processo de uma janela (sem a voz do Discord).
///
/// No plugin Windows o loopback de áudio é um só e para no `OnStop` de
/// qualquer captura de vídeo. Por isso o vídeo da janela não é parado: fica
/// vivo a 1 fps, desligado e fora do stream enviado.
class HybridCapture {
  HybridCapture({DisplayMediaFn? getDisplayMedia, LocalStreamFn? createStream})
    : _getDisplayMedia =
          getDisplayMedia ?? navigator.mediaDevices.getDisplayMedia,
      _createStream = createStream ?? createLocalMediaStream;

  final DisplayMediaFn _getDisplayMedia;
  final LocalStreamFn _createStream;
  final _owned = <MediaStream>[];

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
      return combined;
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    final owned = List.of(_owned);
    _owned.clear();
    final stopped = <String>{};
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
