import 'package:denden/rooms/settings_store.dart';
import 'package:denden/rooms/worker_api.dart';
import 'package:denden/sistema/reducao_volume.dart';
import 'package:denden/ui/setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDucking implements VolumeDucking {
  FakeDucking({this.off = false});

  bool off;

  @override
  Future<bool> isOff() async => off;

  @override
  Future<void> setOff(bool value) async => off = value;
}

void main() {
  testWidgets('interruptor desliga a redução de volume do Windows', (
    tester,
  ) async {
    final ducking = FakeDucking();
    await tester.pumpWidget(
      MaterialApp(
        home: SetupPage(
          initial: const AppSettings(),
          check: (_, _) async {},
          save: (_) async {},
          onDone: (_) {},
          ducking: ducking,
        ),
      ),
    );
    await tester.pump();
    final tile = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump();
    expect(ducking.off, isTrue);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
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

  Future<void> open(
    WidgetTester tester, {
    required Future<void> Function(Uri, String) check,
    required List<AppSettings> saved,
    required List<AppSettings> done,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupPage(
          initial: const AppSettings(),
          check: check,
          save: (s) async => saved.add(s),
          onDone: done.add,
          ducking: FakeDucking(),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Endereço do servidor'),
      'https://denden.x.workers.dev',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Sua chave'),
      'chave-ana',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('chave aceita pelo Worker: salva e segue', (tester) async {
    final saved = <AppSettings>[];
    final done = <AppSettings>[];
    await open(tester, check: (_, _) async {}, saved: saved, done: done);
    expect(saved.single.key, 'chave-ana');
    expect(saved.single.workerUrl.toString(), 'https://denden.x.workers.dev');
    expect(done, hasLength(1));
  });

  testWidgets('chave recusada: mostra o erro e não salva', (tester) async {
    final saved = <AppSettings>[];
    await open(
      tester,
      check: (_, _) async => throw const InvalidKey(
        401,
        'chave_invalida',
        'Chave do grupo inválida.',
      ),
      saved: saved,
      done: [],
    );
    expect(find.text('Chave do grupo inválida.'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('o olho mostra e esconde a chave; o exemplo fica visível', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupPage(
          initial: const AppSettings(),
          check: (_, _) async {},
          save: (_) async {},
          onDone: (_) {},
          ducking: FakeDucking(),
        ),
      ),
    );
    EditableText key() => tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextField, 'Sua chave'),
        matching: find.byType(EditableText),
      ),
    );
    expect(key().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar').first);
    await tester.pump();
    expect(key().obscureText, isFalse);
    await tester.tap(find.byTooltip('Esconder'));
    await tester.pump();
    expect(key().obscureText, isTrue);
    expect(find.textContaining('Ex.: https://'), findsOneWidget);
  });

  testWidgets('endereço que não é https é recusado antes de chamar o Worker', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SetupPage(
          initial: const AppSettings(),
          check: (_, _) async => called = true,
          save: (_) async {},
          onDone: (_) {},
          ducking: FakeDucking(),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Endereço do servidor'),
      'http://inseguro',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Sua chave'), 'k');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();
    expect(called, isFalse);
    expect(
      find.text('O endereço precisa começar com https://'),
      findsOneWidget,
    );
  });
}
