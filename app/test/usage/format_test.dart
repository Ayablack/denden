import 'package:denden/usage/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatBytes', () {
    test('zero e valores muito pequenos', () {
      expect(formatBytes(0), '0 MB');
      expect(formatBytes(500), '0 MB');
      expect(formatBytes(512 * 1000 * 1000), '512 MB');
    });

    test('valores abaixo de 1 GB em MB, ou GB se arredondar para 1000 MB', () {
      expect(formatBytes(999_400_000), '999 MB');
      expect(formatBytes(999_999_999), '1,00 GB');
    });

    test('valores de 1 GB ou mais em GB com 2 casas decimais', () {
      expect(formatBytes(1_000_000_000), '1,00 GB');
      expect(formatBytes(1_500_000_000), '1,50 GB');
      expect(formatBytes(2_700_000_000), '2,70 GB');
    });

    test('valores muito grandes formatam corretamente', () {
      expect(formatBytes(1_234_567_890_123), '1.234,57 GB');
      expect(formatBytes(1234567890123456), '1.234.567,89 GB');
    });
  });

  group('formatBrl', () {
    test('zero e valores muito pequenos', () {
      expect(formatBrl(0), r'R$ 0,00');
      expect(formatBrl(0.001), r'R$ 0,00');
      expect(formatBrl(0.005), r'R$ 0,01'); // arredondamento
      expect(formatBrl(0.999), r'R$ 1,00');
    });

    test('valores grandes e arredondamento', () {
      expect(formatBrl(1234.5), r'R$ 1.234,50');
      expect(formatBrl(1234567.89), r'R$ 1.234.567,89');
      expect(formatBrl(123456789.12), r'R$ 123.456.789,12');
    });

    test('valores negativos', () {
      expect(formatBrl(-1234.56), r'-R$ 1.234,56');
    });
  });

  group('formatUsd', () {
    test('valores comuns', () {
      expect(formatUsd(10), r'US$ 10,00');
      expect(formatUsd(1234.5), r'US$ 1.234,50');
    });
  });

  group('formatPercent', () {
    test('zero e valores muito pequenos', () {
      expect(formatPercent(0), '0,0%');
      expect(formatPercent(0.01), '0,0%');
      expect(formatPercent(0.05), '0,1%'); // arredondamento
    });

    test('valores grandes e arredondamento', () {
      expect(formatPercent(80), '80,0%');
      expect(formatPercent(99.99), '100,0%');
      expect(formatPercent(104.96), '105,0%');
      expect(formatPercent(12345.67), '12.345,7%');
    });

    test('valores negativos', () {
      expect(formatPercent(-0.05), '-0,1%');
    });
  });
}
