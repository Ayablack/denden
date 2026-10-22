import 'dart:math';

/// Perfis de qualidade da transmissão (seção 4.4 da spec).
enum QualityProfile {
  high(1920, 1080, 60, 6000000, 'Alta (1080p60)'),
  medium(1280, 720, 60, 3500000, 'Média (720p60)'),
  economy(1280, 720, 30, 2000000, 'Economia (720p30)');

  const QualityProfile(
    this.width,
    this.height,
    this.frameRate,
    this.maxBitrateBps,
    this.label,
  );

  final int width;
  final int height;
  final int frameRate;
  final int maxBitrateBps;
  final String label;

  /// GB (10^9 bytes) recebidos por um espectador em 1 h no bitrate máximo.
  double get gbPerViewerHour => maxBitrateBps * 3600 / 8 / 1e9;
}

/// Fator `scaleResolutionDownBy` para a fonte caber no perfil, sem ampliar.
double scaleDownFor(QualityProfile p, int sourceWidth, int sourceHeight) =>
    max(1.0, max(sourceWidth / p.width, sourceHeight / p.height));
