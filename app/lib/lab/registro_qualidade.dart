import 'dart:async';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

import 'diagnostico.dart';

/// Registro de qualidade das transmissões de verdade: uma linha por segundo
/// num CSV (mesmas colunas do diagnóstico), dos dois lados. Serve para achar
/// a causa das travadas do vídeo sem ferramenta extra. Fica em
/// `%APPDATA%\com.denden\denden\registros`. Erros são ignorados: o registro
/// nunca derruba a transmissão.
class RegistroQualidade {
  RegistroQualidade(this._ler, this._arquivo, {required this.enviando}) {
    _escrever(DiagRow.columns.join(';'));
  }

  final Future<List<StatsReport>> Function() _ler;
  final File _arquivo;

  /// `true` do lado que transmite; `false` do lado que assiste.
  final bool enviando;
  List<StatsReport>? _anterior;
  DateTime? _horaAnterior;
  var _segundo = 0;
  Timer? _timer;

  static Future<RegistroQualidade?> iniciar(
    RTCPeerConnection pc, {
    required bool enviando,
    required String sala,
  }) async {
    try {
      final base = await getApplicationSupportDirectory();
      final pasta = Directory('${base.path}${Platform.pathSeparator}registros')
        ..createSync(recursive: true);
      limparRegistrosAntigos(pasta, manter: 20);
      final arquivo = File(
        '${pasta.path}${Platform.pathSeparator}'
        '${nomeRegistro(DateTime.now(), enviando: enviando, sala: sala)}',
      );
      final r = RegistroQualidade(pc.getStats, arquivo, enviando: enviando);
      r._timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => r.amostrar(),
      );
      return r;
    } catch (_) {
      return null;
    }
  }

  Future<void> amostrar() async {
    try {
      final agora = await _ler();
      final hora = DateTime.now();
      final antes = _anterior;
      if (antes != null) {
        final secs = hora.difference(_horaAnterior!).inMilliseconds / 1000;
        final row = diagRow(
          second: ++_segundo,
          secs: secs <= 0 ? 1 : secs,
          prevTx: enviando ? antes : const [],
          tx: enviando ? agora : const [],
          prevRx: enviando ? const [] : antes,
          rx: enviando ? const [] : agora,
        );
        _escrever(row.toCsv());
      }
      _anterior = agora;
      _horaAnterior = hora;
    } catch (_) {
      // Conexão fechando ou disco cheio: o registro é só ajuda.
    }
  }

  void _escrever(String linha) {
    try {
      _arquivo.writeAsStringSync('$linha\n', mode: FileMode.append);
    } catch (_) {
      // Idem.
    }
  }

  void parar() => _timer?.cancel();
}

String nomeRegistro(
  DateTime t, {
  required bool enviando,
  required String sala,
}) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${dois(t.month)}-${dois(t.day)}_'
      '${dois(t.hour)}-${dois(t.minute)}-${dois(t.second)}_'
      '${enviando ? 'transmitir' : 'assistir'}_$sala.csv';
}

/// Os nomes começam pela data, então a ordem alfabética é a ordem no tempo.
void limparRegistrosAntigos(Directory pasta, {required int manter}) {
  final arquivos =
      pasta
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.csv'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in arquivos.take(
    arquivos.length - manter < 0 ? 0 : arquivos.length - manter,
  )) {
    try {
      f.deleteSync();
    } catch (_) {
      // Arquivo aberto em outro programa: fica para a próxima.
    }
  }
}
