import 'package:denden/capture/capture_service.dart';
import 'package:denden/rooms/worker_api.dart';
import 'package:denden/ui/broadcast_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> open(
  WidgetTester tester,
  FakeMedia media,
  FakeCapture capture,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BroadcastPage(media: media, capture: capture),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sugere uma janela que não é o DenDen como fonte do áudio', (
    tester,
  ) async {
    await open(tester, FakeMedia(), FakeCapture());
    expect(find.text('Jogo'), findsOneWidget);
    expect(find.textContaining('Só o som desta janela'), findsOneWidget);
  });

  testWidgets('transmitir mostra o código formatado e Copiar', (tester) async {
    final c = FakeCapture();
    await open(tester, FakeMedia(), c);
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();
    expect(find.text('K7P-92Q'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(c.lastAudioWindow?.name, 'Jogo');
  });

  testWidgets('janela do jogo fechou: aviso claro na tela', (tester) async {
    final c = FakeCapture();
    await open(tester, FakeMedia(), c);
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();
    c.errorsCtl.add(
      const CaptureError(
        'janela_fechou',
        'A janela "Jogo" fechou. O áudio foi interrompido.',
      ),
    );
    await tester.pump();
    expect(find.textContaining('O áudio foi interrompido'), findsOneWidget);
  });

  testWidgets('orçamento esgotado ao iniciar: mensagem e captura liberada', (
    tester,
  ) async {
    final c = FakeCapture();
    final m = FakeMedia()
      ..publishError = const BudgetBlocked(
        403,
        'orcamento',
        'Limite do mês atingido. Novas transmissões estão bloqueadas.',
      );
    await open(tester, m, c);
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();
    expect(
      find.text('Limite do mês atingido. Novas transmissões estão bloqueadas.'),
      findsOneWidget,
    );
    expect(c.stopped, isTrue);
  });

  testWidgets('parar encerra a transmissão e a captura', (tester) async {
    final c = FakeCapture();
    final m = FakeMedia();
    await open(tester, m, c);
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parar'));
    await tester.pumpAndSettle();
    expect(m.broadcast.stopped, isTrue);
    expect(c.stopped, isTrue);
  });
}
