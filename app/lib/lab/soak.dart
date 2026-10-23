import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../capture/capture_service.dart';
import '../capture/hybrid_capture.dart';
import '../capture/quality_profile.dart';
import '../logging/sanitize.dart';
import 'loopback_session.dart';

/// Modo de estresse: ciclos de iniciar / transmitir / parar sem a ferramenta
/// de testes, para separar quedas do app de quedas do `flutter test`.
/// Ligado pela variável de ambiente `DENDEN_SOAK`, por exemplo:
/// `modo=hibrido;ciclos=20;seg=5;janela=DenDen Jogo;log=C:/tmp/soak.log`.
enum SoakMode {
  tela('tela'),
  telaMudo('tela-mudo'),
  hibrido('hibrido'),
  janela('janela');

  const SoakMode(this.key);
  final String key;
}

class SoakConfig {
  const SoakConfig({
    required this.mode,
    required this.cycles,
    required this.hold,
    required this.logPath,
    this.windowTitle,
    this.profile = QualityProfile.high,
  });

  final SoakMode mode;
  final int cycles;
  final Duration hold;
  final String logPath;
  final String? windowTitle;
  final QualityProfile profile;

  static SoakConfig? fromEnvironment() =>
      parse(Platform.environment['DENDEN_SOAK']);

  static SoakConfig? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final kv = {
      for (final part in raw.split(';'))
        if (part.contains('='))
          part.substring(0, part.indexOf('=')).trim(): part
              .substring(part.indexOf('=') + 1)
              .trim(),
    };
    final mode = SoakMode.values.where((m) => m.key == kv['modo']).firstOrNull;
    if (mode == null) throw FormatException('modo inválido: ${kv['modo']}');
    final log = kv['log'];
    if (log == null || log.isEmpty) throw const FormatException('falta log=');
    final window = kv['janela'];
    if ((mode == SoakMode.hibrido || mode == SoakMode.janela) &&
        (window == null || window.isEmpty)) {
      throw const FormatException('falta janela= para este modo');
    }
    return SoakConfig(
      mode: mode,
      cycles: int.tryParse(kv['ciclos'] ?? '') ?? 10,
      hold: Duration(seconds: int.tryParse(kv['seg'] ?? '') ?? 5),
      logPath: log,
      windowTitle: window,
      profile:
          QualityProfile.values
              .where((p) => p.name == kv['perfil'])
              .firstOrNull ??
          QualityProfile.high,
    );
  }
}

/// Roda os ciclos e encerra o processo: código 0 se todos terminaram,
/// 2 se algum ciclo lançou exceção. Queda nativa aparece como outro código.
Future<Never> runSoak(
  SoakConfig c, {
  required int width,
  required int height,
}) async {
  final log = File(c.logPath);
  void mark(String m) => log.writeAsStringSync(
    '${DateTime.now().toIso8601String()} $m\n',
    mode: FileMode.append,
    flush: true,
  );

  mark(
    'INÍCIO modo=${c.mode.key} perfil=${c.profile.name} ciclos=${c.cycles} seg=${c.hold.inSeconds} '
    'pid=$pid',
  );
  final capture = CaptureService();
  final hybrid = HybridCapture();
  hybrid.errors.listen((e) => mark('AVISO ${e.code}: ${e.message}'));
  var code = 0;
  try {
    final sources = await capture.listSources();
    final screen = sources.firstWhere((s) => !s.isWindow);
    for (var i = 1; i <= c.cycles; i++) {
      mark('ciclo $i: iniciar captura');
      CaptureSource window() =>
          sources.firstWhere((s) => s.isWindow && s.name == c.windowTitle);
      final MediaStream stream = switch (c.mode) {
        SoakMode.tela => await capture.start(screen, c.profile),
        SoakMode.telaMudo => await capture.start(
          screen,
          c.profile,
          audio: false,
        ),
        SoakMode.janela => await capture.start(window(), c.profile),
        SoakMode.hibrido => await hybrid.start(
          screen: screen,
          audioWindow: window(),
          profile: c.profile,
        ),
      };
      mark('ciclo $i: iniciar laço');
      final session = await LoopbackSession.start(
        stream,
        c.profile,
        sourceWidth: c.mode == SoakMode.janela ? null : width,
        sourceHeight: c.mode == SoakMode.janela ? null : height,
      );
      mark('ciclo $i: transmitindo');
      // Em blocos de 5 s, para ver o áudio parar se a janela fechar.
      final end = DateTime.now().add(c.hold);
      while (DateTime.now().isBefore(end)) {
        final left = end.difference(DateTime.now());
        await Future<void>.delayed(
          left < const Duration(seconds: 5) ? left : const Duration(seconds: 5),
        );
        if (c.hold > const Duration(seconds: 10)) {
          final rs = await session.receiver.getStats();
          final e = rs
              .where(
                (r) => r.type == 'inbound-rtp' && r.values['kind'] == 'audio',
              )
              .fold<num>(
                0,
                (a, r) => a + ((r.values['totalAudioEnergy'] as num?) ?? 0),
              );
          mark('ciclo $i: energia acumulada=$e áudio=${hybrid.audioActive}');
        }
      }
      final rx = await session.receiver.getStats();
      final tx = await session.sender.getStats();
      num sum(List<StatsReport> rs, String type, String kind, String f) => rs
          .where((r) => r.type == type && r.values['kind'] == kind)
          .fold<num>(0, (a, r) => a + ((r.values[f] as num?) ?? 0));
      mark(
        'ciclo $i: quadros=${sum(tx, 'outbound-rtp', 'video', 'framesEncoded')} '
        'energia=${sum(rx, 'inbound-rtp', 'audio', 'totalAudioEnergy')}',
      );
      mark('ciclo $i: parar laço');
      await session.close();
      mark('ciclo $i: parar captura');
      await capture.stop();
      await hybrid.stop();
      mark('ciclo $i: ok');
    }
    mark('FIM ok');
  } catch (e, st) {
    code = 2;
    mark('ERRO ${describeError(e, st)}');
    await capture.stop();
    await hybrid.stop();
  }
  exit(code);
}
