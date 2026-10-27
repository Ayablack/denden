import 'dart:convert';

import 'package:denden/atualizacao/atualizacao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> release(
  String tag, {
  bool draft = false,
  bool zip = true,
}) => {
  'tag_name': tag,
  'draft': draft,
  'assets': [
    if (zip)
      {
        'name': 'DenDen-$tag-windows.zip',
        'browser_download_url': 'https://github.com/x/$tag.zip',
        'size': 21000000,
      },
  ],
};

void main() {
  group('comparar versões', () {
    test('número a número, não como texto', () {
      expect(compararVersoes('1.0.10', '1.0.2'), greaterThan(0));
      expect(compararVersoes('1.0.2', '1.0.2'), 0);
      expect(compararVersoes('v1.1.0', '1.0.9'), greaterThan(0));
      expect(compararVersoes('1.0.1', '1.2'), lessThan(0));
    });
  });

  group('escolher a versão nova', () {
    test('a maior versão com zip, ignorando rascunhos', () {
      final n = escolherVersaoNova([
        release('v1.0.1'),
        release('v1.0.4', draft: true),
        release('v1.0.3', zip: false),
        release('v1.0.2'),
      ], atual: '1.0.1')!;
      expect(n.versao, '1.0.2');
      expect(n.urlZip, 'https://github.com/x/v1.0.2.zip');
    });

    test('nada novo: nulo', () {
      expect(escolherVersaoNova([release('v1.0.1')], atual: '1.0.1'), isNull);
      expect(escolherVersaoNova([release('v1.0.0')], atual: '1.0.1'), isNull);
    });

    test('versão de desenvolvimento nunca oferece atualização', () {
      expect(escolherVersaoNova([release('v9.0.0')], atual: 'dev'), isNull);
    });
  });

  group('conferir no GitHub', () {
    test('lê a lista pública de releases', () async {
      late Uri pedida;
      final client = MockClient((req) async {
        pedida = req.url;
        return http.Response(jsonEncode([release('v1.0.2')]), 200);
      });
      final n = await conferirAtualizacao(client, atual: '1.0.1');
      expect(n?.versao, '1.0.2');
      expect(pedida.host, 'api.github.com');
      expect(pedida.path, '/repos/Ayablack/denden/releases');
    });

    test('erro ou sem internet: nulo, sem exceção', () async {
      final erro = MockClient((_) async => http.Response('limite', 403));
      expect(await conferirAtualizacao(erro, atual: '1.0.1'), isNull);
      final semRede = MockClient((_) async => throw http.ClientException('x'));
      expect(await conferirAtualizacao(semRede, atual: '1.0.1'), isNull);
    });
  });

  test('script espera o DenDen fechar, troca os arquivos e abre de novo', () {
    final s = scriptAtualizacao(
      pid: 1234,
      zip: r'C:\Temp\d\novo.zip',
      pasta: r"C:\Jogos\DenDen do Zé's",
    );
    expect(s, contains('Wait-Process -Id 1234'));
    expect(s, contains(r"Expand-Archive -LiteralPath 'C:\Temp\d\novo.zip'"));
    // Aspas simples dentro do caminho são dobradas no PowerShell.
    expect(s, contains(r"'C:\Jogos\DenDen do Zé''s'"));
    expect(s, contains('denden.exe'));
    expect(s.indexOf('Wait-Process'), lessThan(s.indexOf('Copy-Item')));
  });
}
