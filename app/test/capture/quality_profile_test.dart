import 'package:denden/capture/quality_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valores dos perfis seguem a spec', () {
    expect(QualityProfile.high.width, 1920);
    expect(QualityProfile.high.height, 1080);
    expect(QualityProfile.high.frameRate, 60);
    expect(QualityProfile.high.maxBitrateBps, 6000000);
    expect(QualityProfile.medium.height, 720);
    expect(QualityProfile.medium.frameRate, 60);
    expect(QualityProfile.medium.maxBitrateBps, 3500000);
    expect(QualityProfile.economy.frameRate, 30);
    expect(QualityProfile.economy.maxBitrateBps, 2000000);
    expect(QualityProfile.high.gbPerViewerHour, closeTo(2.7, 0.01));
  });

  test('rótulos mostram resolução e taxa', () {
    expect(QualityProfile.high.label, 'Alta (1080p60)');
    expect(QualityProfile.medium.label, 'Média (720p60)');
    expect(QualityProfile.economy.label, 'Economia (720p30)');
  });

  test('scaleDownFor não amplia e encaixa', () {
    expect(
      scaleDownFor(QualityProfile.high, 2560, 1440),
      closeTo(1.333, 0.001),
    );
    expect(scaleDownFor(QualityProfile.high, 1280, 720), 1.0);
    expect(
      // Ultrawide: a largura manda (3440 / 1280).
      scaleDownFor(QualityProfile.medium, 3440, 1440),
      closeTo(2.6875, 0.001),
    );
  });
}
