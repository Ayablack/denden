// EXPERIMENTO: captura híbrida (vídeo da tela + áudio só de uma janela)
// contra a captura de janela. Abre janelas de teste próprias: "Jogo" (anima e
// toca som), "Jogo Mudo" (anima, sem som) e "Falso Discord" (toca som o tempo
// todo, no papel da voz dos amigos).
import 'dart:io';

import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/hybrid_capture.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:denden/lab/loopback_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:integration_test/integration_test.dart';

const _helper =
    r'C:\Projetos\denden\app\integration_test\helpers\janela_teste.ps1';
const _somJogo = r'C:\Windows\Media\Alarm01.wav';
const _somDiscord = r'C:\Windows\Media\Ring05.wav';

// Marcas gravadas na hora: se o app cair, o print se perde, o arquivo não.
final _marcas = File('${Directory.systemTemp.path}\\denden-marcas.txt');
void marca(String m) => _marcas.writeAsStringSync(
  '${DateTime.now().toIso8601String()} $m\n',
  mode: FileMode.append,
  flush: true,
);

class Medida {
  Medida(this.nome);
  final String nome;
  double fps = 0;
  int? largura;
  int? altura;
  String? limitacao;
  double codificaMs = 0;
  double bufferMs = 0;
  double decodificaMs = 0;
  double energiaAudio = 0;
  double cpuProcesso = 0;
  double? cpuSistema;

  @override
  String toString() =>
      'MEDIDA $nome: ${largura}x$altura @ ${fps.toStringAsFixed(1)} fps; '
      'limitação $limitacao; codificar ${codificaMs.toStringAsFixed(1)} ms/quadro; '
      'buffer ${bufferMs.toStringAsFixed(1)} ms; decodificar '
      '${decodificaMs.toStringAsFixed(1)} ms/quadro; energia de áudio '
      '${energiaAudio.toStringAsExponential(2)}; CPU do DenDen '
      '${cpuProcesso.toStringAsFixed(0)}% de 1 núcleo; CPU do sistema '
      '${cpuSistema?.toStringAsFixed(0) ?? '—'}%';
}

Future<Process> abrirJanela(
  String titulo, {
  String? wav,
  int x = 50,
  int y = 50,
}) => Process.start('powershell', [
  '-NoProfile',
  '-ExecutionPolicy',
  'Bypass',
  '-File',
  _helper,
  '-Titulo',
  titulo,
  if (wav != null) ...['-Wav', wav],
  '-X',
  '$x',
  '-Y',
  '$y',
]);

Future<CaptureSource> esperarFonte(CaptureService c, String titulo) async {
  final fim = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(fim)) {
    final s = (await c.listSources()).where((s) => s.name == titulo);
    if (s.isNotEmpty) return s.first;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('janela "$titulo" não apareceu');
}

Future<double> cpuMsDoProcesso() async {
  final r = await Process.run('powershell', [
    '-NoProfile',
    '-c',
    '(Get-Process -Id $pid).TotalProcessorTime.TotalMilliseconds',
  ]);
  return double.parse((r.stdout as String).trim().replaceAll(',', '.'));
}

Future<double?> cpuDoSistema() async {
  final r = await Process.run('powershell', [
    '-NoProfile',
    '-c',
    '(Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average',
  ]);
  return double.tryParse((r.stdout as String).trim().replaceAll(',', '.'));
}

num _soma(List<StatsReport> rs, String type, String kind, String campo) => rs
    .where((r) => r.type == type && r.values['kind'] == kind)
    .fold<num>(0, (a, r) => a + ((r.values[campo] as num?) ?? 0));

Future<Medida> medir(
  String nome,
  MediaStream stream, {
  int? largura,
  int? altura,
}) async {
  marca('$nome: stream pronto');
  final session = await LoopbackSession.start(
    stream,
    QualityProfile.high,
    sourceWidth: largura,
    sourceHeight: altura,
  );
  try {
    marca('$nome: laço iniciado');
    // O estimador de banda leva ~25 s para chegar ao alvo.
    await Future<void>.delayed(const Duration(seconds: 25));
    final tx0 = await session.sender.getStats();
    final rx0 = await session.receiver.getStats();
    final cpu0 = await cpuMsDoProcesso();
    final t0 = DateTime.now();
    await Future<void>.delayed(const Duration(seconds: 5));
    final sistema = await cpuDoSistema();
    await Future<void>.delayed(const Duration(seconds: 5));
    final tx1 = await session.sender.getStats();
    final rx1 = await session.receiver.getStats();
    final cpu1 = await cpuMsDoProcesso();
    final ms = DateTime.now().difference(t0).inMilliseconds;

    num d(
      List<StatsReport> a,
      List<StatsReport> b,
      String t,
      String k,
      String c,
    ) => _soma(b, t, k, c) - _soma(a, t, k, c);
    final quadros = d(tx0, tx1, 'outbound-rtp', 'video', 'framesEncoded');
    final decodificados = d(rx0, rx1, 'inbound-rtp', 'video', 'framesDecoded');
    final emitidos = d(
      rx0,
      rx1,
      'inbound-rtp',
      'video',
      'jitterBufferEmittedCount',
    );
    final video = tx1.firstWhere(
      (r) => r.type == 'outbound-rtp' && r.values['kind'] == 'video',
    );

    marca('$nome: medido');
    final m = Medida(nome)
      ..fps = quadros * 1000 / ms
      ..largura = (video.values['frameWidth'] as num?)?.toInt()
      ..altura = (video.values['frameHeight'] as num?)?.toInt()
      ..limitacao = video.values['qualityLimitationReason'] as String?
      ..codificaMs = quadros == 0
          ? 0
          : d(tx0, tx1, 'outbound-rtp', 'video', 'totalEncodeTime') *
                1000 /
                quadros
      ..decodificaMs = decodificados == 0
          ? 0
          : d(rx0, rx1, 'inbound-rtp', 'video', 'totalDecodeTime') *
                1000 /
                decodificados
      ..bufferMs = emitidos == 0
          ? 0
          : d(rx0, rx1, 'inbound-rtp', 'video', 'jitterBufferDelay') *
                1000 /
                emitidos
      ..energiaAudio = d(
        rx0,
        rx1,
        'inbound-rtp',
        'audio',
        'totalAudioEnergy',
      ).toDouble()
      ..cpuProcesso = (cpu1 - cpu0) / ms * 100
      ..cpuSistema = sistema;
    marca(m.toString());
    return m;
  } finally {
    await session.close();
  }
}

/// Um cenário por processo (`--dart-define=CENARIO=S1`): uma queda num
/// cenário não apaga as medidas dos outros.
const cenario = String.fromEnvironment('CENARIO');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captura híbrida: cenário $cenario', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: Text('Experimento de captura'))),
    );
    final display = tester.view.display.size;
    final w = display.width.round();
    final h = display.height.round();
    final abertos = <Process>[];
    final capture = CaptureService();
    final hybrid = HybridCapture();
    marca('$cenario: começo');
    try {
      final tela = (await capture.listSources()).firstWhere((s) => !s.isWindow);
      Future<CaptureSource> janela(
        String t, {
        String? wav,
        int x = 50,
        int y = 50,
      }) async {
        abertos.add(await abrirJanela(t, wav: wav, x: x, y: y));
        return esperarFonte(capture, t);
      }

      switch (cenario) {
        case 'S1': // método anterior: vídeo e áudio da janela do jogo
          final jogo = await janela('DenDen Jogo', wav: _somJogo);
          final m = await medir(
            'S1 janela (anterior)',
            await capture.start(jogo, QualityProfile.high),
          );
          expect(m.energiaAudio, greaterThan(0));
        case 'S2': // híbrido com o jogo tocando
          final jogo = await janela('DenDen Jogo', wav: _somJogo);
          final m = await medir(
            'S2 híbrido + jogo com som',
            await hybrid.start(
              screen: tela,
              audioWindow: jogo,
              profile: QualityProfile.high,
            ),
            largura: w,
            altura: h,
          );
          expect(m.energiaAudio, greaterThan(0));
        case 'S3': // híbrido com jogo mudo e "Discord" tocando: Discord não entra
          final mudo = await janela('DenDen Jogo Mudo');
          await janela('DenDen Falso Discord', wav: _somDiscord, x: 720, y: 50);
          await medir(
            'S3 híbrido + jogo mudo, Discord tocando',
            await hybrid.start(
              screen: tela,
              audioWindow: mudo,
              profile: QualityProfile.high,
            ),
            largura: w,
            altura: h,
          );
        case 'S4': // controle: tela inteira com áudio do sistema; Discord entra
          await janela('DenDen Jogo Mudo');
          await janela('DenDen Falso Discord', wav: _somDiscord, x: 720, y: 50);
          final m = await medir(
            'S4 controle tela inteira, Discord tocando',
            await capture.start(tela, QualityProfile.high),
            largura: w,
            altura: h,
          );
          expect(m.energiaAudio, greaterThan(0));
        case 'S3B': // S3 com o "Discord" tocando o mesmo som que funcionou no jogo
          final mudo = await janela('DenDen Jogo Mudo');
          await janela('DenDen Falso Discord', wav: _somJogo, x: 720, y: 50);
          await medir(
            'S3B híbrido + jogo mudo, Discord tocando Alarm01',
            await hybrid.start(
              screen: tela,
              audioWindow: mudo,
              profile: QualityProfile.high,
            ),
            largura: w,
            altura: h,
          );
        case 'S4B': // controle do S3B
          await janela('DenDen Jogo Mudo');
          await janela('DenDen Falso Discord', wav: _somJogo, x: 720, y: 50);
          await medir(
            'S4B controle tela inteira, Discord tocando Alarm01',
            await capture.start(tela, QualityProfile.high),
            largura: w,
            altura: h,
          );
        // S3C/S4C: o "Falso Discord" é aberto pelo script, fora da árvore de
        // processos do DenDen (filhos do DenDen são excluídos na tela inteira).
        case 'S3C':
          final mudo = await janela('DenDen Jogo Mudo');
          await esperarFonte(capture, 'DenDen Falso Discord Externo');
          await medir(
            'S3C híbrido + jogo mudo, Discord externo tocando',
            await hybrid.start(
              screen: tela,
              audioWindow: mudo,
              profile: QualityProfile.high,
            ),
            largura: w,
            altura: h,
          );
        case 'S4C':
          await janela('DenDen Jogo Mudo');
          await esperarFonte(capture, 'DenDen Falso Discord Externo');
          await medir(
            'S4C controle tela inteira, Discord externo tocando',
            await capture.start(tela, QualityProfile.high),
            largura: w,
            altura: h,
          );
        case 'S2C': // controle do S3C sem a tela inteira: mira a janela do Discord externo
          final discord = await esperarFonte(
            capture,
            'DenDen Falso Discord Externo',
          );
          await medir(
            'S2C híbrido mirando o Discord externo',
            await hybrid.start(
              screen: tela,
              audioWindow: discord,
              profile: QualityProfile.high,
            ),
            largura: w,
            altura: h,
          );
        case 'S5': // janela que sumiu antes de começar (o jogo fechou)
          await janela('DenDen Falso Discord', wav: _somDiscord, x: 720, y: 50);
          final fechada = await janela('DenDen Janela Fechada');
          abertos.last.kill();
          await Future<void>.delayed(const Duration(seconds: 2));
          try {
            await medir(
              'S5 híbrido + janela já fechada, Discord tocando',
              await hybrid.start(
                screen: tela,
                audioWindow: fechada,
                profile: QualityProfile.high,
              ),
              largura: w,
              altura: h,
            );
          } catch (e) {
            marca('MEDIDA S5: start falhou com $e');
          }
        case 'S6': // estabilidade: iniciar e parar 5 vezes no mesmo processo
          final jogo = await janela('DenDen Jogo', wav: _somJogo);
          for (var i = 1; i <= 5; i++) {
            marca('S6 ciclo $i: iniciar');
            final s = await hybrid.start(
              screen: tela,
              audioWindow: jogo,
              profile: QualityProfile.high,
            );
            final l = await LoopbackSession.start(
              s,
              QualityProfile.high,
              sourceWidth: w,
              sourceHeight: h,
            );
            await Future<void>.delayed(const Duration(seconds: 5));
            marca('S6 ciclo $i: parar');
            await l.close();
            await hybrid.stop();
            marca('S6 ciclo $i: parado');
          }
          marca('MEDIDA S6: 5 ciclos sem cair');
        default:
          fail('CENARIO desconhecido: "$cenario"');
      }
    } finally {
      await capture.stop();
      await hybrid.stop();
      for (final p in abertos) {
        p.kill();
      }
      marca('$cenario: fim');
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
