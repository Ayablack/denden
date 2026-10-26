import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:denden/lab/lab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FakeCapture implements CaptureService {
  @override
  Future<List<CaptureSource>> listSources() async => const [
    CaptureSource(id: '0', name: 'Tela 1', isWindow: false),
    CaptureSource(id: '42', name: 'Jogo', isWindow: true),
  ];

  @override
  Future<MediaStream> start(
    CaptureSource s,
    QualityProfile p, {
    bool audio = true,
    int? excludeProcessId,
    int? captureFps,
  }) => throw UnimplementedError();

  @override
  Future<void> stop() async {}
}

Future<void> pumpLab(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(home: LabPage(capture: FakeCapture(), tickStopwatch: false)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tela inteira avisa que o Discord entra no áudio', (
    tester,
  ) async {
    await pumpLab(tester);
    expect(find.text('Tela 1'), findsOneWidget);
    expect(find.textContaining('voz do Discord também'), findsOneWidget);
  });

  testWidgets('janela avisa que só o som do programa vai', (tester) async {
    await pumpLab(tester);
    await tester.tap(find.text('Tela 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jogo').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('só o som deste programa'), findsOneWidget);
  });

  testWidgets('mostra perfil padrão, Iniciar e cronômetro', (tester) async {
    await pumpLab(tester);
    expect(find.text('Alta (1080p60)'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
    expect(find.text('00:00:00.000'), findsOneWidget);
    expect(find.textContaining('não comprova'), findsOneWidget);
  });

  testWidgets('dá para esconder o vídeo recebido (A4 mais justo)', (
    tester,
  ) async {
    await pumpLab(tester);
    expect(find.text('Mostrar vídeo recebido'), findsOneWidget);
  });
}
