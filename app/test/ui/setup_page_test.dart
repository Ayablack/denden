import 'package:denden/rooms/settings_store.dart';
import 'package:denden/rooms/worker_api.dart';
import 'package:denden/ui/setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('O endereço precisa começar com https://'), findsOneWidget);
  });
}
