import 'dart:io';

import 'package:denden/rooms/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('denden-settings'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('sem arquivo: configurações vazias, sem erro', () async {
    final s = await SettingsStore(File('${dir.path}/x.json')).load();
    expect(s.isComplete, isFalse);
    expect(s.workerUrl, isNull);
  });

  test('salva e carrega endereço, chave e chave de admin', () async {
    final store = SettingsStore(File('${dir.path}/s.json'));
    await store.save(
      AppSettings(
        workerUrl: Uri.parse('https://denden.x.workers.dev'),
        key: 'chave-ana',
        adminKey: 'admin',
      ),
    );
    final s = await store.load();
    expect(s.workerUrl.toString(), 'https://denden.x.workers.dev');
    expect(s.key, 'chave-ana');
    expect(s.adminKey, 'admin');
    expect(s.isComplete, isTrue);
  });

  test('toString não mostra as chaves', () {
    final s = AppSettings(
      workerUrl: Uri.parse('https://x'),
      key: 'segredo',
      adminKey: 'chave-admin-xyz',
    );
    expect(s.toString(), isNot(contains('segredo')));
    expect(s.toString(), isNot(contains('chave-admin-xyz')));
  });

  test('arquivo corrompido volta ao vazio em vez de quebrar o app', () async {
    final f = File('${dir.path}/ruim.json')..writeAsStringSync('{nao-e-json');
    expect((await SettingsStore(f).load()).isComplete, isFalse);
  });
}
