import 'package:denden/rooms/worker_api.dart';
import 'package:denden/ui/admin_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdmin implements AdminPort {
  final calls = <String>[];
  List<KeyInfo> keys = [
    const KeyInfo(name: 'Ana', hash: 'h-ana', revoked: false),
    const KeyInfo(name: 'Bia', hash: 'h-bia', revoked: true),
  ];
  Object? keysError;
  Object? configError;
  bool emergencyOn = false;

  @override
  Future<List<KeyInfo>> listKeys() async {
    if (keysError != null) throw keysError!;
    return keys;
  }

  @override
  Future<(String, String)> createKey(String name) async {
    calls.add('criar:$name');
    return ('chave-nova-de-$name', 'h-$name');
  }

  @override
  Future<void> revokeKey(String hash) async => calls.add('revogar:$hash');

  @override
  Future<void> setEmergency(bool on) async {
    emergencyOn = on;
    calls.add('emergencia:$on');
  }

  @override
  Future<Map<String, dynamic>> usage() async => {'emergency': emergencyOn};

  @override
  Future<void> setConfig(Map<String, Object?> config) async {
    if (configError != null) throw configError!;
    calls.add('config:$config');
  }

  @override
  Future<void> setConfirmed(String month, double? gb, double? brl) async =>
      calls.add('confirmado:$month:$gb:$brl');
}

Future<FakeAdmin> open(WidgetTester tester, [FakeAdmin? a]) async {
  final admin = a ?? FakeAdmin();
  // Janela de PC (densidade 1): com a densidade padrão do teste, 3, seriam
  // só 400 px de largura.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: AdminPage(admin: admin)));
  await tester.pumpAndSettle();
  return admin;
}

void main() {
  testWidgets('emergência pede confirmação antes de desligar', (tester) async {
    final a = await open(tester);
    await tester.tap(find.text('Desligar todas as transmissões'));
    await tester.pumpAndSettle();
    expect(a.calls, isEmpty);
    expect(find.textContaining('Tem certeza'), findsOneWidget);
    await tester.tap(find.text('Desligar'));
    await tester.pumpAndSettle();
    expect(a.calls, ['emergencia:true']);
    expect(find.text('Religar transmissões'), findsOneWidget);
  });

  testWidgets('criar chave mostra a chave uma única vez', (tester) async {
    final a = await open(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome do amigo'),
      'Caio',
    );
    await tester.tap(find.text('Criar chave'));
    await tester.pumpAndSettle();
    expect(a.calls, ['criar:Caio']);
    expect(find.text('chave-nova-de-Caio'), findsOneWidget);
    expect(find.textContaining('aparece uma vez só'), findsOneWidget);
  });

  testWidgets('revogar pede confirmação e chama o Worker', (tester) async {
    final a = await open(tester);
    expect(find.text('Bia (revogada)'), findsOneWidget);
    await tester.tap(find.text('Revogar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revogar'));
    await tester.pumpAndSettle();
    expect(a.calls, ['revogar:h-ana']);
  });

  testWidgets('limites inválidos: mostra o erro do Worker', (tester) async {
    final a = FakeAdmin()
      ..configError = const WorkerError(
        400,
        'config_invalida',
        'Limites inválidos.',
      );
    await open(tester, a);
    await tester.enterText(
      find.widgetWithText(TextField, 'Orçamento do mês (GB)'),
      '0',
    );
    await tester.tap(find.text('Salvar limites'));
    await tester.pumpAndSettle();
    expect(find.text('Limites inválidos.'), findsOneWidget);
  });

  testWidgets('limites válidos vão para o Worker com os tipos certos', (
    tester,
  ) async {
    final a = await open(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Orçamento do mês (GB)'),
      '500',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Avisos (%)'),
      '50, 80, 100',
    );
    await tester.tap(find.text('Salvar limites'));
    await tester.pumpAndSettle();
    expect(a.calls.single, contains('budgetGb: 500.0'));
    expect(a.calls.single, contains('warnPercents: [50.0, 80.0, 100.0]'));
  });

  testWidgets('chave de admin errada: mensagem clara', (tester) async {
    await open(
      tester,
      FakeAdmin()
        ..keysError = const WorkerError(
          403,
          'nao_e_admin',
          'Só o administrador pode fazer isto.',
        ),
    );
    expect(find.text('Só o administrador pode fazer isto.'), findsOneWidget);
  });

  testWidgets('duração máxima vai para o Worker em horas', (tester) async {
    final a = await open(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Duração máxima (h)'),
      '3',
    );
    await tester.tap(find.text('Salvar limites'));
    await tester.pumpAndSettle();
    expect(a.calls.single, contains('maxSessionHours: 3.0'));
  });
}
