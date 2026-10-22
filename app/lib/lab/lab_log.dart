import '../usage/media_stats.dart';

/// Uma leitura do laboratório: lado que envia e lado que recebe.
class LabSample {
  const LabSample({
    required this.elapsed,
    required this.state,
    required this.tx,
    required this.rx,
    required this.sendMbps,
    required this.receiveMbps,
  });

  final Duration elapsed;
  final String state;
  final MediaStatsSnapshot tx;
  final MediaStatsSnapshot rx;
  final double sendMbps;
  final double receiveMbps;
}

double mbpsBetween(
  MediaStatsSnapshot a,
  MediaStatsSnapshot b, {
  bool received = false,
}) {
  final ms = b.at.difference(a.at).inMilliseconds;
  if (ms <= 0) return 0;
  final bytes = received
      ? b.bytesReceived - a.bytesReceived
      : b.bytesSent - a.bytesSent;
  return bytes * 8 / (ms / 1000) / 1e6;
}

String formatStopwatch(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:'
      '${two(d.inSeconds % 60)}.'
      '${(d.inMilliseconds % 1000).toString().padLeft(3, '0')}';
}

/// Pasta onde o CSV é salvo. Com o OneDrive, `Documents` pode não existir
/// dentro da pasta do usuário; aí vai na própria pasta do usuário.
String csvFolder(String home, bool Function(String path) exists) {
  final documents = '$home\\Documents';
  return exists(documents) ? documents : home;
}

/// CSV para o Excel em português: BOM UTF-8, ";" entre colunas, vírgula
/// decimal e quebra de linha do Windows.
String labCsv(List<LabSample> samples) {
  const nl = '\r\n';
  String n(num? v, [int digits = 1]) =>
      v == null ? '' : v.toStringAsFixed(digits).replaceAll('.', ',');
  const header = [
    'tempo_s',
    'estado',
    'largura',
    'altura',
    'fps_enviado',
    'fps_recebido',
    'codec',
    'codificador',
    'limitacao',
    'alvo_mbps',
    'enviado_mbps',
    'recebido_mbps',
    'jitter_ms',
    'audio_recebido_kb',
    'nivel_audio',
  ];
  final b = StringBuffer('﻿${header.join(';')}$nl');
  for (final s in samples) {
    final target = s.tx.targetBitrateBps;
    final row = [
      s.elapsed.inSeconds,
      s.state,
      s.tx.frameWidth ?? '',
      s.tx.frameHeight ?? '',
      n(s.tx.framesPerSecond),
      n(s.rx.framesPerSecond),
      s.rx.codec ?? '',
      s.tx.encoderImplementation ?? '',
      s.tx.qualityLimitationReason ?? '',
      target == null ? '' : n(target / 1e6, 2),
      n(s.sendMbps, 2),
      n(s.receiveMbps, 2),
      n(s.rx.jitterMs),
      n(s.rx.audioBytesReceived / 1000),
      n(s.rx.audioLevel, 2),
    ];
    b.write('${row.join(';')}$nl');
  }
  return b.toString();
}
