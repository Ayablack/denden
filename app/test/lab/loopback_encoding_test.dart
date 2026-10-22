import 'package:denden/capture/quality_profile.dart';
import 'package:denden/lab/loopback_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('codificação segue bitrate e fps do perfil', () {
    final e = encodingFor(
      QualityProfile.high,
      sourceWidth: 2560,
      sourceHeight: 1440,
    );
    expect(e.maxBitrate, 6000000);
    expect(e.maxFramerate, 60);
    expect(e.scaleResolutionDownBy, closeTo(1.333, 0.001));
  });

  test('sem resolução conhecida da fonte, não reduz', () {
    final e = encodingFor(QualityProfile.economy);
    expect(e.maxBitrate, 2000000);
    expect(e.maxFramerate, 30);
    expect(e.scaleResolutionDownBy, 1.0);
  });
}
