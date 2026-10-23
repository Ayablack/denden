import 'package:denden/capture/capture_service.dart';
import 'package:denden/lab/lab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Iniciar conecta e coleta amostras; Parar encerra', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LabPage(capture: CaptureService())),
    );
    // O cronômetro redesenha sempre: esperar por tempo, não por "assentar".
    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await wait(const Duration(seconds: 2));
    expect(find.text('Iniciar'), findsOneWidget);
    await tester.tap(find.text('Iniciar'));
    await wait(const Duration(seconds: 10));

    expect(find.text('Estado: connected'), findsOneWidget);
    expect(find.textContaining('Amostras: '), findsOneWidget);
    expect(find.text('Amostras: 0'), findsNothing);

    await tester.tap(find.text('Parar'));
    await wait(const Duration(seconds: 2));
    expect(find.text('Nada sendo recebido'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
