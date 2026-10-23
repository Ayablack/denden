import 'package:denden/capture/quality_profile.dart';
import 'package:denden/lab/soak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê modo, ciclos, segundos, janela e log', () {
    final c = SoakConfig.parse(
      'modo=hibrido;ciclos=20;seg=5;janela=DenDen Jogo;log=C:/tmp/s.log',
    )!;
    expect(c.mode, SoakMode.hibrido);
    expect(c.cycles, 20);
    expect(c.hold, const Duration(seconds: 5));
    expect(c.windowTitle, 'DenDen Jogo');
    expect(c.logPath, 'C:/tmp/s.log');
  });

  test('vazio ou ausente desliga o modo de estresse', () {
    expect(SoakConfig.parse(null), isNull);
    expect(SoakConfig.parse(''), isNull);
  });

  test('padrões: 10 ciclos de 5 s', () {
    final c = SoakConfig.parse('modo=tela-mudo;log=x.log')!;
    expect(c.mode, SoakMode.telaMudo);
    expect(c.cycles, 10);
    expect(c.hold, const Duration(seconds: 5));
  });

  test('modo inválido ou sem log é erro claro', () {
    expect(() => SoakConfig.parse('modo=xyz;log=x'), throwsFormatException);
    expect(() => SoakConfig.parse('modo=tela'), throwsFormatException);
    expect(
      () => SoakConfig.parse('modo=hibrido;log=x'),
      throwsFormatException,
      reason: 'híbrido e janela precisam do título da janela',
    );
  });

  test('perfil escolhido, padrão Alta', () {
    expect(SoakConfig.parse('modo=tela;log=x')!.profile, QualityProfile.high);
    expect(
      SoakConfig.parse('modo=tela;perfil=medium;log=x')!.profile,
      QualityProfile.medium,
    );
  });
}
