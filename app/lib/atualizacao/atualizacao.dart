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

String _junta(String pasta, String nome) =>
    '$pasta${Platform.pathSeparator}$nome';

/// Troca os arquivos de [pasta] pelos de [novos], subpastas incluídas. O
/// Windows não deixa sobrescrever o DenDen aberto, mas deixa renomear: cada
/// arquivo antigo vira `*.antigo-<n>` e é apagado na próxima abertura
/// ([limparRestosDeAtualizacao]). Se algo falhar no meio, desfaz tudo e
/// lança o erro: a versão antiga continua inteira.
void trocarArquivos(Directory novos, Directory pasta) {
  final sufixo = '.antigo-${DateTime.now().millisecondsSinceEpoch}';
  final feitos = <(File, File?)>[];
  try {
    for (final f in novos.listSync(recursive: true).whereType<File>()) {
      final alvo = File(
        _junta(pasta.path, f.path.substring(novos.path.length + 1)),
      );
      alvo.parent.createSync(recursive: true);
      File? antigo;
      if (alvo.existsSync()) antigo = alvo.renameSync('${alvo.path}$sufixo');
      feitos.add((alvo, antigo));
      f.copySync(alvo.path);
    }
  } catch (_) {
    for (final (alvo, antigo) in feitos.reversed) {
      try {
        if (alvo.existsSync()) alvo.deleteSync();
        antigo?.renameSync(alvo.path);
      } catch (_) {
        // Melhor esforço: segue desfazendo o resto.
      }
    }
    rethrow;
  }
}

/// Ao abrir: apaga o que sobrou da última atualização. Arquivo ainda em
/// uso fica para a próxima.
void limparRestosDeAtualizacao([Directory? pasta]) {
  final p = pasta ?? File(Platform.resolvedExecutable).parent;
  try {
    for (final f in p.listSync(recursive: true).whereType<File>()) {
      if (!f.path.contains('.antigo-')) continue;
      try {
        f.deleteSync();
      } catch (_) {
        // Em uso.
      }
    }
  } catch (_) {
    // Pasta sem permissão de leitura: nada a limpar.
  }
}

/// Baixa o zip (avisando o progresso de 0 a 1), troca os arquivos da pasta
/// do DenDen, abre a versão nova e fecha esta.
Future<void> instalarAtualizacao(
  NovaVersao nova, {
  http.Client? client,
  void Function(double)? progresso,
}) async {
  final c = client ?? http.Client();
  final pastaTemp = Directory(
    _junta(Directory.systemTemp.path, 'denden-atualizacao'),
  );
  if (pastaTemp.existsSync()) pastaTemp.deleteSync(recursive: true);
  pastaTemp.createSync(recursive: true);
  final zip = File(_junta(pastaTemp.path, 'DenDen.zip'));
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
  // O tar do Windows (10 em diante) abre zip. Sem PowerShell: lançado pelo
  // app, ele nem chegava a rodar.
  final novos = Directory(_junta(pastaTemp.path, 'novos'))..createSync();
  final tar = _junta(
    _junta(Platform.environment['SystemRoot'] ?? r'C:\Windows', 'System32'),
    'tar.exe',
  );
  final r = await Process.run(tar, ['-xf', zip.path, '-C', novos.path]);
  if (r.exitCode != 0 || !File(_junta(novos.path, 'denden.exe')).existsSync()) {
    throw const FileSystemException('zip sem o DenDen');
  }
  final pasta = File(Platform.resolvedExecutable).parent;
  trocarArquivos(novos, pasta);
  await Process.start(
    _junta(pasta.path, 'denden.exe'),
    const [],
    mode: ProcessStartMode.detached,
    workingDirectory: pasta.path,
  );
  exit(0);
}
