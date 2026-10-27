import 'package:denden/sistema/reducao_volume.dart';
import 'package:denden/ui/aviso_reducao_volume.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDucking implements VolumeDucking {
  FakeDucking({this.off = false, this.falha = false});

  bool off;
  final bool falha;

  @override
  Future<bool> isOff() async => falha ? throw Exception('registro') : off;

  @override
  Future<void> setOff(bool value) async => off = value;
}

Widget app(VolumeDucking d) => MaterialApp(
  home: Scaffold(body: AvisoReducaoVolume(ducking: d)),
);

void main() {
  testWidgets('Windows ainda abaixa o som: desliga sozinho e avisa', (t) async {
    final d = FakeDucking();
    await t.pumpWidget(app(d));
    await t.pump();
    expect(d.off, isTrue);
    expect(find.textContaining('Reinicie o PC'), findsOneWidget);
    await t.tap(find.text('Entendi'));
    await t.pump();
    expect(find.textContaining('Reinicie o PC'), findsNothing);
  });

  testWidgets('já desligado: não mostra nada', (t) async {
    await t.pumpWidget(app(FakeDucking(off: true)));
    await t.pump();
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('erro ao ler a opção: não mostra nada', (t) async {
    await t.pumpWidget(app(FakeDucking(falha: true)));
    await t.pump();
    expect(find.byType(MaterialBanner), findsNothing);
  });

  test('lê a opção na saída do reg query', () {
    expect(
      duckingFromRegQuery(
        'HKEY_CURRENT_USER\\Software\\Microsoft\\Multimedia\\Audio\r\n'
        '    UserDuckingPreference    REG_DWORD    0x3\r\n',
      ),
      3,
    );
    // Sem o valor, vale o padrão do Windows (reduzir 80%).
    expect(duckingFromRegQuery('ERRO: valor não encontrado'), 1);
  });
}
