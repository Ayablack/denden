import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../capture/capture_service.dart';
import '../capture/pc_sem_discord.dart';
import '../capture/quality_profile.dart';
import '../logging/sanitize.dart';
import '../media/cloudflare_media.dart';
import '../rooms/settings_store.dart';
import '../rooms/worker_api.dart';

/// Modo de diagnóstico: transmite a tela **pelo Worker e pelo SFU de
/// verdade** e assiste no mesmo PC, gravando um CSV por segundo. Serve para
/// separar gargalo do PC (codificação) de gargalo da rede ou do servidor.
/// Ligado pela variável de ambiente `DENDEN_DIAG`, por exemplo:
/// `seg=60;perfil=high;csv=C:/tmp/diag.csv;audio=pc`.
///
/// `audio`: `nao` (padrão), `pc` (PC menos o Discord, como no app) ou
/// `pc-excluindo` com `excluir=<pid>` (para testar a exclusão com um
/// processo qualquer; `excluir=0` não exclui nada além do DenDen).
///
/// `fpscaptura`: troca os quadros por segundo pedidos ao capturador (padrão:
/// `captureFrameRate`, o dobro do perfil). Só vale para `audio=nao`.
///
/// Usa o endereço e a chave salvos no app; a chave não vai para o CSV.
class DiagConfig {
  const DiagConfig({
    required this.duration,
    required this.csvPath,
    this.profile = QualityProfile.high,
    this.audio = 'nao',
    this.excludePid,
    this.captureFps,
    this.screenIndex = 1,
    this.sourceSize,
  });

  final Duration duration;
  final String csvPath;
  final QualityProfile profile;
  final String audio;
  final int? excludePid;
  final int? captureFps;

  /// `tela=2`: qual tela transmitir (1 = a primeira da lista do plugin).
  final int screenIndex;

  /// `fonte=1920x1080`: tamanho da tela transmitida, quando não é a da
  /// janela do DenDen (ex.: monitor secundário).
  final (int, int)? sourceSize;

  static DiagConfig? fromEnvironment() =>
      parse(Platform.environment['DENDEN_DIAG']);

  static DiagConfig? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final kv = {
      for (final part in raw.split(';'))
        if (part.contains('='))
          part.substring(0, part.indexOf('=')).trim(): part
              .substring(part.indexOf('=') + 1)
              .trim(),
    };
    final csv = kv['csv'];
    if (csv == null || csv.isEmpty) throw const FormatException('falta csv=');
    return DiagConfig(
      duration: Duration(seconds: int.tryParse(kv['seg'] ?? '') ?? 60),
      csvPath: csv,
      profile:
          QualityProfile.values
              .where((p) => p.name == kv['perfil'])
              .firstOrNull ??
          QualityProfile.high,
      audio: kv['audio'] ?? 'nao',
      excludePid: int.tryParse(kv['excluir'] ?? ''),
      captureFps: int.tryParse(kv['fpscaptura'] ?? ''),
      screenIndex: int.tryParse(kv['tela'] ?? '') ?? 1,
      sourceSize: switch (kv['fonte']?.split('x')) {
        [final w, final h] when int.tryParse(w) != null => (
          int.parse(w),
          int.tryParse(h) ?? 0,
        ),
        _ => null,
      },
    );
  }
}

/// Uma linha do CSV: o que mudou entre duas leituras de estatísticas.
class DiagRow {
  const DiagRow(this.values);

  final Map<String, Object?> values;

  static const columns = [
    'segundo',
    'enviado_fps',
    'enviado_kbps',
    'alvo_kbps',
    'banda_disponivel_kbps',
    'resolucao_enviada',
    'limitacao',
    'codificar_ms',
    'pedidos_quadro_chave',
    'rtt_ms',
    'recebido_fps',
    'recebido_kbps',
    'resolucao_recebida',
    'pacotes_perdidos',
    'quadros_descartados',
    'travadas',
    'travada_ms',
    'nacks',
    'perda_ate_sfu',
    'buffer_ms',
    'codec',
    'audio_energia_enviada',
    'audio_kbps',
    'capturado_fps',
  ];

  /// Excel pt-BR: separador `;` e vírgula decimal.
  String toCsv() => [
    for (final c in columns)
      switch (values[c]) {
        null => '',
        double d => d.toStringAsFixed(1).replaceAll('.', ','),
        final v => '$v',
      },
  ].join(';');
}

num _sum(List<StatsReport> rs, String type, String kind, String field) => rs
    .where((r) => r.type == type && r.values['kind'] == kind)
    .fold<num>(0, (a, r) => a + ((r.values[field] as num?) ?? 0));

Map<dynamic, dynamic>? _first(List<StatsReport> rs, String type, String kind) =>
    rs
        .where((r) => r.type == type && r.values['kind'] == kind)
        .firstOrNull
        ?.values;

/// Par de candidatos em uso: tem a banda disponível estimada e o RTT.
Map<dynamic, dynamic>? _pair(List<StatsReport> rs) => rs
    .where(
      (r) =>
          r.type == 'candidate-pair' &&
          (r.values['nominated'] == true || r.values['state'] == 'succeeded') &&
          r.values['availableOutgoingBitrate'] != null,
    )
    .firstOrNull
    ?.values;

/// Compara duas leituras ([secs] segundos entre elas) do envio e da
/// recepção. Pura, para dar para testar sem WebRTC.
DiagRow diagRow({
  required int second,
  required double secs,
  required List<StatsReport> prevTx,
  required List<StatsReport> tx,
  required List<StatsReport> prevRx,
  required List<StatsReport> rx,
}) {
  double delta(List<StatsReport> a, List<StatsReport> b, String t, String f) =>
      (_sum(b, t, 'video', f) - _sum(a, t, 'video', f)).toDouble();

  final encoded = delta(prevTx, tx, 'outbound-rtp', 'framesEncoded');
  final emitted = delta(prevRx, rx, 'inbound-rtp', 'jitterBufferEmittedCount');
  final out = _first(tx, 'outbound-rtp', 'video') ?? const {};
  final inb = _first(rx, 'inbound-rtp', 'video') ?? const {};
  final pair = _pair(tx);
  final codecId = out['codecId'];
  final codec = tx
      .where((r) => r.type == 'codec' && r.id == codecId)
      .firstOrNull
      ?.values['mimeType'];
  String? res(Map<dynamic, dynamic> m) =>
      m['frameWidth'] == null ? null : '${m['frameWidth']}x${m['frameHeight']}';

  return DiagRow({
    'segundo': second,
    'enviado_fps': encoded / secs,
    'enviado_kbps':
        delta(prevTx, tx, 'outbound-rtp', 'bytesSent') * 8 / 1000 / secs,
    'alvo_kbps': (out['targetBitrate'] as num?)?.toDouble().let(
      (b) => b / 1000,
    ),
    'banda_disponivel_kbps': (pair?['availableOutgoingBitrate'] as num?)
        ?.toDouble()
        .let((b) => b / 1000),
    'resolucao_enviada': res(out),
    'limitacao': out['qualityLimitationReason'],
    'codificar_ms': encoded == 0
        ? null
        : delta(prevTx, tx, 'outbound-rtp', 'totalEncodeTime') * 1000 / encoded,
    'pedidos_quadro_chave': delta(
      prevTx,
      tx,
      'outbound-rtp',
      'pliCount',
    ).toInt(),
    'rtt_ms': (pair?['currentRoundTripTime'] as num?)?.toDouble().let(
      (s) => s * 1000,
    ),
    'recebido_fps': delta(prevRx, rx, 'inbound-rtp', 'framesDecoded') / secs,
    'recebido_kbps':
        delta(prevRx, rx, 'inbound-rtp', 'bytesReceived') * 8 / 1000 / secs,
    'resolucao_recebida': res(inb),
    'pacotes_perdidos': delta(prevRx, rx, 'inbound-rtp', 'packetsLost').toInt(),
    'quadros_descartados': delta(
      prevRx,
      rx,
      'inbound-rtp',
      'framesDropped',
    ).toInt(),
    'travadas': delta(prevRx, rx, 'inbound-rtp', 'freezeCount').toInt(),
    'travada_ms':
        delta(prevRx, rx, 'inbound-rtp', 'totalFreezesDuration') * 1000,
    // Pedidos de reenvio que o SFU fez a quem transmite.
    'nacks': delta(prevTx, tx, 'outbound-rtp', 'nackCount').toInt(),
    // Pacotes de vídeo perdidos entre quem transmite e o SFU.
    'perda_ate_sfu': delta(
      prevTx,
      tx,
      'remote-inbound-rtp',
      'packetsLost',
    ).toInt(),
    'buffer_ms': emitted == 0
        ? null
        : delta(prevRx, rx, 'inbound-rtp', 'jitterBufferDelay') *
              1000 /
              emitted,
    'codec': codec,
    // Energia do som capturado (antes de codificar): ~0 é silêncio.
    'audio_energia_enviada':
        (_sum(tx, 'media-source', 'audio', 'totalAudioEnergy') -
                _sum(prevTx, 'media-source', 'audio', 'totalAudioEnergy'))
            .toDouble()
            .toStringAsExponential(1),
    'audio_kbps':
        (_sum(tx, 'outbound-rtp', 'audio', 'bytesSent') -
            _sum(prevTx, 'outbound-rtp', 'audio', 'bytesSent')) *
        8 /
        1000 /
        secs,
    // Quadros que o capturador entregou ao WebRTC (antes do codificador).
    'capturado_fps':
        (_sum(tx, 'media-source', 'video', 'frames') -
            _sum(prevTx, 'media-source', 'video', 'frames')) /
        secs,
  });
}

extension<T extends Object> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// Roda o diagnóstico e encerra o processo: código 0 se terminou, 2 se deu
/// erro (a mensagem vai para o CSV, sem a chave).
Future<Never> runDiagnostic(
  DiagConfig c, {
  required int width,
  required int height,
  void Function(RTCVideoRenderer)? onWatching,
}) async {
  final csv = File(c.csvPath);
  void write(String line) =>
      csv.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);

  csv.writeAsStringSync(
    '# perfil=${c.profile.name} seg=${c.duration.inSeconds} '
    'fpscaptura=${c.captureFps ?? captureFrameRate(c.profile)} '
    'tela=${width}x$height início=${DateTime.now().toIso8601String()}\n',
  );
  write(DiagRow.columns.join(';'));
  final capture = CaptureService();
  final pcAudio = PcWithoutDiscordCapture(capture: capture);
  final renderer = RTCVideoRenderer();
  Broadcast? broadcast;
  Viewing? viewing;
  var code = 0;
  try {
    final s = await (await SettingsStore.standard()).load();
    if (!s.isComplete) {
      throw StateError('Configure o endereço e a chave antes.');
    }
    final media = CloudflareMedia(WorkerApi(s.workerUrl!), s.key!);
    final screens = [
      for (final x in await capture.listSources())
        if (!x.isWindow) x,
    ];
    final screen = screens[c.screenIndex - 1];
    final (srcW, srcH) = c.sourceSize ?? (width, height);
    write('# tela: ${screen.name} ${srcW}x$srcH');
    final stream = switch (c.audio) {
      'pc' => await pcAudio.start(screen, c.profile),
      'pc-excluindo' => await capture.start(
        screen,
        c.profile,
        excludeProcessId: c.excludePid == 0 ? null : c.excludePid,
      ),
      _ => await capture.start(
        screen,
        c.profile,
        audio: false,
        captureFps: c.captureFps,
      ),
    };
    pcAudio.errors.listen((e) => write('# AVISO ${e.code}: ${e.message}'));
    broadcast = await media.publish(
      stream,
      c.profile,
      sourceWidth: srcW,
      sourceHeight: srcH,
    );
    await renderer.initialize();
    viewing = await media.watch(broadcast.roomCode, renderer);
    // Quem assiste está no mesmo PC: tocar o som recebido faria a captura
    // pegar de novo o próprio som.
    await viewing.muteAudio();
    // Mostra o vídeo recebido na janela, como na tela de assistir.
    onWatching?.call(renderer);
    write(
      '# renderizador: ${renderer.srcObject?.getVideoTracks().length} '
      'trilha(s) de vídeo, ${renderer.srcObject?.getAudioTracks().length} '
      'de áudio',
    );

    var prevTx = await broadcast.rawStats();
    var prevRx = await viewing.rawStats();
    var prevAt = DateTime.now();
    for (var i = 1; i <= c.duration.inSeconds; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final tx = await broadcast.rawStats();
      final rx = await viewing.rawStats();
      final now = DateTime.now();
      write(
        diagRow(
          second: i,
          secs: now.difference(prevAt).inMilliseconds / 1000,
          prevTx: prevTx,
          tx: tx,
          prevRx: prevRx,
          rx: rx,
        ).toCsv(),
      );
      prevTx = tx;
      prevRx = rx;
      prevAt = now;
      // Confere se o perfil chegou mesmo ao libwebrtc.
      if (i == 2) {
        write('# codificação: ${await broadcast.describeEncodings()}');
      }
    }
  } catch (e, st) {
    code = 2;
    write('# ERRO ${describeError(e, st)}');
  }
  await viewing?.leave();
  await broadcast?.stop();
  await pcAudio.stop();
  await capture.stop();
  await renderer.dispose();
  exit(code);
}
