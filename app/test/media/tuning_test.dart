import 'package:flutter_test/flutter_test.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:denden/media/tuning.dart';

void main() {
  group('encodingFor', () {
    test('sem tamanho de origem, scaleResolutionDownBy é 1.0', () {
      final encoding = encodingFor(QualityProfile.high);
      expect(encoding.scaleResolutionDownBy, 1.0);
    });

    test('origem 3840x2160 com o perfil high dá redução 2.0', () {
      final encoding = encodingFor(
        QualityProfile.high,
        sourceWidth: 3840,
        sourceHeight: 2160,
      );
      expect(encoding.scaleResolutionDownBy, 2.0);
    });

    test('maxBitrate e maxFramerate iguais aos do perfil', () {
      final encoding = encodingFor(QualityProfile.medium);
      expect(encoding.maxBitrate, QualityProfile.medium.maxBitrateBps);
      expect(encoding.maxFramerate, QualityProfile.medium.frameRate);
    });

    test('active true', () {
      final encoding = encodingFor(QualityProfile.economy);
      expect(encoding.active, isTrue);
    });
  });
}
