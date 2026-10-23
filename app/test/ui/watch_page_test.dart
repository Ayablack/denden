import 'package:denden/media/cloudflare_media.dart';
import 'package:denden/rooms/worker_api.dart';
import 'package:denden/ui/watch_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> open(WidgetTester tester, FakeMedia media) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WatchPage(media: media, initRenderer: (_) async {}),
    ),
  );
  await tester.enterText(find.byType(TextField), 'k7p-92q');
  await tester.tap(find.widgetWithText(FilledButton, 'Assistir'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('sala cheia mostra a mensagem do Worker', (tester) async {
    final m = FakeMedia()
      ..watchError = const RoomFull(
        409,
        'sala_cheia',
        'A sala já tem 5 espectadores.',
      );
    await open(tester, m);
    expect(find.text('A sala já tem 5 espectadores.'), findsOneWidget);
  });

  testWidgets('transmissão encerrada', (tester) async {
    final m = FakeMedia();
    await open(tester, m);
    m.viewing.state = LinkState.ended;
    m.viewing.statesCtl.add(LinkState.ended);
    await tester.pump();
    expect(find.text('Transmissão encerrada'), findsOneWidget);
  });

  testWidgets(
    'Worker fora do ar: erro claro e Tentar de novo, sem ficar girando',
    (tester) async {
      final m = FakeMedia()
        ..watchError = const WorkerUnavailable('Sem servidor.');
      await open(tester, m);
      expect(find.text('Sem servidor.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
