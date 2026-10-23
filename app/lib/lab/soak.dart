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
      final metrics = _Metrics();
      // Em blocos de 5 s, para ver o áudio parar se a janela fechar.
      final end = DateTime.now().add(c.hold);
      while (DateTime.now().isBefore(end)) {
        final left = end.difference(DateTime.now());
        await Future<void>.delayed(
          left < const Duration(seconds: 5) ? left : const Duration(seconds: 5),
        );
        if (c.hold > const Duration(seconds: 10)) {
          await metrics.sample(session, hybrid.audioActive, mark, i);
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

/// Medidas periódicas da sessão longa: fps, resolução, limitação, áudio,
/// atraso de reprodução de áudio e de vídeo (indício de sincronia) e CPU.
class _Metrics {
  List<StatsReport>? _tx;
  List<StatsReport>? _rx;
  DateTime? _at;
  double? _cpuMs;
  DateTime? _cpuAt;

  static num _sum(List<StatsReport> rs, String type, String kind, String f) =>
      rs
          .where((r) => r.type == type && r.values['kind'] == kind)
          .fold<num>(0, (a, r) => a + ((r.values[f] as num?) ?? 0));

  static StatsReport? _first(List<StatsReport> rs, String type, String kind) =>
      rs.where((r) => r.type == type && r.values['kind'] == kind).firstOrNull;

  Future<void> sample(
    LoopbackSession session,
    bool audioActive,
    void Function(String) mark,
    int cycle,
  ) async {
    final now = DateTime.now();
    final tx = await session.sender.getStats();
    final rx = await session.receiver.getStats();
    final prevTx = _tx;
    final prevRx = _rx;
    final prevAt = _at;
    _tx = tx;
    _rx = rx;
    _at = now;
    if (prevTx == null || prevRx == null || prevAt == null) return;
    final secs = now.difference(prevAt).inMilliseconds / 1000;
    double delta(
      List<StatsReport> a,
      List<StatsReport> b,
      String t,
      String k,
      String f,
    ) => (_sum(b, t, k, f) - _sum(a, t, k, f)).toDouble();
    final frames = delta(prevTx, tx, 'outbound-rtp', 'video', 'framesEncoded');
    double bufferMs(String kind) {
      final n = delta(
        prevRx,
        rx,
        'inbound-rtp',
        kind,
        'jitterBufferEmittedCount',
      );
      return n == 0
          ? 0
          : delta(prevRx, rx, 'inbound-rtp', kind, 'jitterBufferDelay') *
                1000 /
                n;
    }

    final v = _first(tx, 'outbound-rtp', 'video')?.values ?? const {};
    final encodeMs = frames == 0
        ? 0
        : delta(prevTx, tx, 'outbound-rtp', 'video', 'totalEncodeTime') *
              1000 /
              frames;
    final va = _first(
      rx,
      'inbound-rtp',
      'video',
    )?.values['estimatedPlayoutTimestamp'];
    final aa = _first(
      rx,
      'inbound-rtp',
      'audio',
    )?.values['estimatedPlayoutTimestamp'];
    final playout = va is num && aa is num
        ? '${(va - aa).toStringAsFixed(0)} ms'
        : '—';
    var cpu = '';
    if (_cpuAt == null ||
        now.difference(_cpuAt!) >= const Duration(seconds: 60)) {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-c',
        '(Get-Process -Id $pid).TotalProcessorTime.TotalMilliseconds',
      ]);
      final ms = double.tryParse(
        (r.stdout as String).trim().replaceAll(',', '.'),
      );
      if (ms != null && _cpuMs != null && _cpuAt != null) {
        final wall = now.difference(_cpuAt!).inMilliseconds;
        cpu = ' cpu=${((ms - _cpuMs!) / wall * 100).toStringAsFixed(0)}%núcleo';
      }
      _cpuMs = ms;
      _cpuAt = now;
    }
    mark(
      'ciclo $cycle: fps=${(frames / secs).toStringAsFixed(1)} '
      '${v['frameWidth']}x${v['frameHeight']} lim=${v['qualityLimitationReason']} '
      'codificar=${encodeMs.toStringAsFixed(1)}ms '
      'buffer_video=${bufferMs('video').toStringAsFixed(0)}ms '
      'buffer_audio=${bufferMs('audio').toStringAsFixed(0)}ms '
      'playout_v-a=$playout '
      'energia+=${delta(prevRx, rx, 'inbound-rtp', 'audio', 'totalAudioEnergy').toStringAsExponential(2)} '
      'áudio=$audioActive$cpu',
    );
  }
}
