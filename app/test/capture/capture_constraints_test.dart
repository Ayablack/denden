import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const window = CaptureSource(id: '42', name: 'Jogo', isWindow: true);

  test('constraints pedem a fonte exata, 60 fps e áudio', () {
    final c = displayMediaConstraints(window, QualityProfile.high, audio: true);
    expect((c['video'] as Map)['deviceId'], {'exact': '42'});
    expect(((c['video'] as Map)['mandatory'] as Map)['frameRate'], 60);
    expect(c['audio'], true);
  });

  test('frameRate vai como double, que é o que o plugin Windows lê', () {
    final c = displayMediaConstraints(
      window,
      QualityProfile.economy,
      audio: false,
    );
    final fps = ((c['video'] as Map)['mandatory'] as Map)['frameRate'];
    expect(fps, isA<double>());
    expect(fps, 30.0);
    expect(c['audio'], false);
  });

  test('minFrameRate nunca abaixo de 1', () {
    for (final p in QualityProfile.values) {
      expect(minFrameRate(p), greaterThanOrEqualTo(1));
    }
  });

  test('só janela isola o áudio do programa', () {
    expect(window.audioIsolated, isTrue);
    const screen = CaptureSource(id: '0', name: 'Tela 1', isWindow: false);
    expect(screen.audioIsolated, isFalse);
  });
}
