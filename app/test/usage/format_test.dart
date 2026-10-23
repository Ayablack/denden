import 'package:denden/usage/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MB abaixo de 1 GB, GB acima, com vírgula decimal', () {
    expect(formatBytes(0), '0 MB');
    expect(formatBytes(512 * 1000 * 1000), '512 MB');
    expect(formatBytes(999_400_000), '999 MB');
    expect(formatBytes(2_700_000_000), '2,70 GB');
    expect(formatBytes(1_234_567_890_123), '1.234,57 GB');
  });

  test('reais e dólares', () {
    expect(formatBrl(0), r'R$ 0,00');
    expect(formatBrl(1234.5), r'R$ 1.234,50');
    expect(formatUsd(10), r'US$ 10,00');
  });

  test('porcentagem com uma casa', () {
    expect(formatPercent(80), '80,0%');
    expect(formatPercent(104.96), '105,0%');
  });
}
