import 'dart:io';

import 'package:denden/lab/diagnostico.dart';
import 'package:denden/lab/registro_qualidade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

StatsReport inb(int frames) => StatsReport('i', 'inbound-rtp', 0, {
  'kind': 'video',
  'framesDecoded': frames,
});

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('registro'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('nome do arquivo tem data, lado e sala', () {
    expect(
      nomeRegistro(
        DateTime(2026, 10, 27, 9, 5, 3),
        enviando: false,
        sala: 'K7P92Q',
      ),
      '2026-10-27_09-05-03_assistir_K7P92Q.csv',
    );
    expect(
      nomeRegistro(DateTime(2026, 1, 2, 3, 4, 5), enviando: true, sala: 'ABC'),
      '2026-01-02_03-04-05_transmitir_ABC.csv',
    );
  });

  test(
    'grava cabeçalho e uma linha por leitura, a partir da segunda',
    () async {
      var frames = 0;
      final r = RegistroQualidade(
        () async => [inb(frames += 60)],
        File('${dir.path}/a.csv'),
        enviando: false,
      );
      await r.amostrar();
      await r.amostrar();
      await r.amostrar();
      final linhas = File('${dir.path}/a.csv').readAsLinesSync();
      expect(linhas.first, DiagRow.columns.join(';'));
      expect(linhas, hasLength(3));
    },
  );

  test('erro ao ler as estatísticas não derruba nada', () async {
    final r = RegistroQualidade(
      () async => throw StateError('conexão fechada'),
      File('${dir.path}/b.csv'),
      enviando: true,
    );
    await r.amostrar();
    expect(File('${dir.path}/b.csv').readAsLinesSync(), hasLength(1));
  });

  test('guarda só os registros mais novos', () {
    for (var i = 0; i < 5; i++) {
      File('${dir.path}/2026-10-0${i + 1}_00-00-00_assistir_X.csv')
          .writeAsStringSync('x');
    }
    limparRegistrosAntigos(dir, manter: 2);
    final nomes = dir.listSync().map((f) => f.uri.pathSegments.last).toList()
      ..sort();
    expect(nomes, [
      '2026-10-04_00-00-00_assistir_X.csv',
      '2026-10-05_00-00-00_assistir_X.csv',
    ]);
  });
}
