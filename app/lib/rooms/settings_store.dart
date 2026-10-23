import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// O que o DenDen precisa saber para falar com o Worker. As chaves ficam só
/// neste PC, num arquivo da pasta de dados do app; nunca vão para log.
class AppSettings {
  const AppSettings({this.workerUrl, this.key, this.adminKey});

  final Uri? workerUrl;
  final String? key;
  final String? adminKey;

  bool get isComplete => workerUrl != null && key != null && key!.isNotEmpty;

  AppSettings copyWith({Uri? workerUrl, String? key, String? adminKey}) =>
      AppSettings(
        workerUrl: workerUrl ?? this.workerUrl,
        key: key ?? this.key,
        adminKey: adminKey ?? this.adminKey,
      );

  @override
  String toString() =>
      'AppSettings(worker: $workerUrl, chave: ${key == null ? 'não' : 'sim'}, '
      'admin: ${adminKey == null ? 'não' : 'sim'})';
}

class SettingsStore {
  SettingsStore(this.file);

  final File file;

  static Future<SettingsStore> standard() async {
    final dir = await getApplicationSupportDirectory();
    return SettingsStore(
      File('${dir.path}${Platform.pathSeparator}denden.json'),
    );
  }

  Future<AppSettings> load() async {
    try {
      if (!await file.exists()) return const AppSettings();
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final url = j['workerUrl'] as String?;
      return AppSettings(
        workerUrl: url == null ? null : Uri.parse(url),
        key: j['key'] as String?,
        adminKey: j['adminKey'] as String?,
      );
    } catch (_) {
      // Arquivo ruim: começa do zero em vez de travar o app.
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings s) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'workerUrl': s.workerUrl?.toString(),
        'key': s.key,
        'adminKey': s.adminKey,
      }),
    );
  }
}
