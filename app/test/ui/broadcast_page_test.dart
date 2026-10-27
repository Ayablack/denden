import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:denden/rooms/worker_api.dart';
import 'package:denden/ui/broadcast_page.dart';
import 'package:denden/ui/capture_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> open(
  WidgetTester tester,
  FakeMedia media,
  FakeCapture capture,
) async {
  tester.view.physicalSize = const Size(1200, 1600);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: BroadcastPage(media: media, capture: capture),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('padrão: som do PC menos o Discord', (tester) async {
    await open(tester, FakeMedia(), FakeCapture());
    expect(find.text('PC inteiro, menos o Discord'), findsOneWidget);
    expect(find.textContaining('menos o Discord. Outros'), findsOneWidget);
  });

  testWidgets('dá para escolher só uma janela, mas não o DenDen', (
    tester,
  ) async {
    final c = FakeCapture();
    await open(tester, FakeMedia(), c);
    await tester.tap(find.text('PC inteiro, menos o Discord'));
    await tester.pumpAndSettle();
    expect(find.text('DenDen'), findsNothing);
    await tester.tap(find.text('Jogo').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Só o som desta janela'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();
    expect((c.lastAudio! as WindowAudio).window.name, 'Jogo');
  });

  testWidgets('transmitir mostra o código formatado e Copiar', (tester) async {
    final c = FakeCapture();
    await open(tester, FakeMedia(), c);
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();
    expect(find.text('K7P-92Q'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(c.lastAudio, isA<PcAudio>());
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

  group('voltar durante a transmissão', () {
    Future<(FakeMedia, FakeCapture)> live(WidgetTester tester) async {
      final c = FakeCapture();
      final m = FakeMedia();
      tester.view.physicalSize = const Size(1200, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BroadcastPage(media: m, capture: c),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      return (m, c);
    }

    testWidgets('pergunta antes de sair e continua no ar', (tester) async {
      final (m, _) = await live(tester);
      expect(find.text('Parar a transmissão?'), findsOneWidget);
      await tester.tap(find.text('Continuar transmitindo'));
      await tester.pumpAndSettle();
      expect(m.broadcast.stopped, isFalse);
      expect(find.text('K7P-92Q'), findsOneWidget);
    });

    testWidgets('confirmar para a transmissão e volta', (tester) async {
      final (m, c) = await live(tester);
      await tester.tap(find.text('Parar e sair'));
      await tester.pumpAndSettle();
      expect(m.broadcast.stopped, isTrue);
      expect(c.stopped, isTrue);
      expect(find.text('Abrir'), findsOneWidget);
    });
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

  testWidgets('aviso nos últimos 5 minutos da duração máxima', (tester) async {
    final m = FakeMedia();
    await open(tester, m, FakeCapture());
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();
    final now = DateTime.now().millisecondsSinceEpoch;
    m.broadcast.repliesCtl.add(
      ReportReply(
        'normal',
        'high',
        const [],
        null,
        sessionEndsAtMs: now + 60 * 60 * 1000,
      ),
    );
    await tester.pump();
    expect(find.textContaining('duração máxima'), findsNothing);
    m.broadcast.repliesCtl.add(
      ReportReply(
        'normal',
        'high',
        const [],
        null,
        sessionEndsAtMs: now + 4 * 60 * 1000,
      ),
    );
    await tester.pump();
    expect(find.textContaining('duração máxima'), findsOneWidget);
    expect(find.textContaining('transmita de novo'), findsOneWidget);
  });

  testWidgets('troca de tela e de qualidade ao vivo com Aplicar', (
    tester,
  ) async {
    final c = FakeCapture();
    final m = FakeMedia();
    await open(tester, m, c);
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tela 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tela 2').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(QualityProfile.high.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(QualityProfile.medium.label).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();

    expect(c.lastVideoScreen?.name, 'Tela 2');
    expect(c.lastVideoProfile, QualityProfile.medium);
    expect(m.broadcast.replacedProfile, QualityProfile.medium);
    expect(m.broadcast.replacedTrack?.id, 'video-1-medium');
    expect(c.stopped, isFalse);
    expect(m.broadcast.stopped, isFalse);
  });

  testWidgets('economy forçado pelo orçamento continua valendo ao Aplicar', (
    tester,
  ) async {
    final c = FakeCapture();
    final m = FakeMedia();
    await open(tester, m, c);
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();

    m.broadcast.repliesCtl.add(
      const ReportReply('blocked', 'economy', [100], null),
    );
    await tester.pumpAndSettle();
    expect(find.text(QualityProfile.economy.label), findsOneWidget);

    await tester.tap(find.text(QualityProfile.economy.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(QualityProfile.high.label).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();

    expect(c.lastVideoProfile, QualityProfile.economy);
    expect(m.broadcast.replacedProfile, QualityProfile.economy);
    expect(find.text(QualityProfile.economy.label), findsOneWidget);
  });

  testWidgets('mostra consumo desta transmissão e do mês', (tester) async {
    final m = FakeMedia();
    await open(tester, m, FakeCapture());
    await tester.tap(find.widgetWithText(FilledButton, 'Transmitir'));
    await tester.pumpAndSettle();

    m.broadcast.repliesCtl.add(
      const ReportReply(
        'normal',
        'high',
        [],
        null,
        roomEgressBytes: 250 * 1000 * 1000,
        monthEgressBytes: 1500 * 1000 * 1000,
      ),
    );
    await tester.pump();

    expect(find.text('Consumo desta transmissão: 250 MB'), findsOneWidget);
    expect(find.text('Consumo do mês: 1,50 GB'), findsOneWidget);
  });
}
