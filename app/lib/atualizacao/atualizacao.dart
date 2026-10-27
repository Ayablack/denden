import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Versão deste build. O workflow de release passa
/// `--dart-define=DENDEN_VERSAO=<tag sem o v>`; compilado à mão fica `dev`
/// e nunca oferece atualização.
const versaoAtual = String.fromEnvironment(
  'DENDEN_VERSAO',
  defaultValue: 'dev',
);

const _releases = 'https://api.github.com/repos/Ayablack/denden/releases';

class NovaVersao {
  const NovaVersao(this.versao, this.urlZip, this.tamanho);

  /// Sem o `v`, ex.: `1.0.2`.
  final String versao;
  final String urlZip;
  final int tamanho;
}

List<int>? _numeros(String v) {
  final partes = v.replaceFirst(RegExp('^v'), '').split('.');
  final n = partes.map(int.tryParse).toList();
  return n.contains(null) ? null : n.cast<int>();
}

/// Positivo se [a] for mais nova que [b]. Versões que não são números
/// (ex.: `dev`) contam como a mais antiga possível.
int compararVersoes(String a, String b) {
  final x = _numeros(a) ?? const [];
  final y = _numeros(b) ?? const [];
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// A maior versão publicada, com zip para Windows, mais nova que [atual].
/// Versões de teste (pre-release) contam: hoje todas são.
NovaVersao? escolherVersaoNova(
  List<dynamic> releases, {
  required String atual,
}) {
  if (_numeros(atual) == null) return null;
  NovaVersao? melhor;
  for (final r in releases.whereType<Map<String, dynamic>>()) {
    if (r['draft'] == true) continue;
    final tag = r['tag_name'];
    if (tag is! String || _numeros(tag) == null) continue;
    final zip = (r['assets'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((a) => '${a['name']}'.endsWith('-windows.zip'))
        .firstOrNull;
    if (zip == null) continue;
    final versao = tag.replaceFirst(RegExp('^v'), '');
    if (compararVersoes(versao, atual) <= 0) continue;
    if (melhor != null && compararVersoes(versao, melhor.versao) <= 0) continue;
    melhor = NovaVersao(
      versao,
      zip['browser_download_url'] as String,
      (zip['size'] as num?)?.toInt() ?? 0,
    );
  }
  return melhor;
}

/// Lê a lista pública de releases. Não manda nada do usuário. Qualquer
/// erro (sem internet, limite do GitHub) vira `null`: o app segue normal.
Future<NovaVersao?> conferirAtualizacao(
  http.Client client, {
  String atual = versaoAtual,
}) async {
  try {
    final r = await client
        .get(
          Uri.parse('$_releases?per_page=20'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    return escolherVersaoNova(jsonDecode(r.body) as List, atual: atual);
  } catch (_) {
    return null;
  }
}

String _aspas(String s) => "'${s.replaceAll("'", "''")}'";

/// Script que roda depois que o DenDen fecha: troca os arquivos da pasta
/// e abre o DenDen de novo. Se a troca falhar, abre a versão que estiver
/// lá, para ninguém ficar sem o app.
String scriptAtualizacao({
  required int pid,
  required String zip,
  required String pasta,
}) =>
    '''
\$ErrorActionPreference = 'Stop'
try { Wait-Process -Id $pid -Timeout 30 } catch {}
\$novo = Join-Path \$env:TEMP 'denden-atualizacao-novo'
try {
  if (Test-Path -LiteralPath \$novo) { Remove-Item -LiteralPath \$novo -Recurse -Force }
  Expand-Archive -LiteralPath ${_aspas(zip)} -DestinationPath \$novo -Force
  Copy-Item -Path (Join-Path \$novo '*') -Destination ${_aspas(pasta)} -Recurse -Force
} finally {
  Start-Process -FilePath (Join-Path ${_aspas(pasta)} 'denden.exe')
}
''';

/// Baixa o zip (avisando o progresso de 0 a 1), prepara o script e fecha
/// o DenDen para ele trocar os arquivos.
Future<void> instalarAtualizacao(
  NovaVersao nova, {
  http.Client? client,
  void Function(double)? progresso,
}) async {
  final c = client ?? http.Client();
  final pastaTemp = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}denden-atualizacao',
  )..createSync(recursive: true);
  final zip = File('${pastaTemp.path}${Platform.pathSeparator}DenDen.zip');
  final resposta = await c.send(http.Request('GET', Uri.parse(nova.urlZip)));
  if (resposta.statusCode != 200) {
    throw HttpException('download ${resposta.statusCode}');
  }
  final total = resposta.contentLength ?? nova.tamanho;
  final saida = zip.openWrite();
  var recebido = 0;
  await for (final pedaco in resposta.stream) {
    saida.add(pedaco);
    recebido += pedaco.length;
    if (total > 0) progresso?.call(recebido / total);
  }
  await saida.close();
  if (nova.tamanho > 0 && zip.lengthSync() != nova.tamanho) {
    throw const HttpException('download incompleto');
  }
  final script = File('${pastaTemp.path}${Platform.pathSeparator}trocar.ps1')
    // Com BOM: o PowerShell 5.1 lê sem BOM como ANSI e estraga acentos
    // no caminho da pasta.
    ..writeAsStringSync(
      '﻿${scriptAtualizacao(pid: pid, zip: zip.path, pasta: File(Platform.resolvedExecutable).parent.path)}',
    );
  await Process.start('powershell.exe', [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-WindowStyle',
    'Hidden',
    '-File',
    script.path,
  ], mode: ProcessStartMode.detached);
  exit(0);
}
