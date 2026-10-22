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

String labCsv(List<LabSample> samples) {
  String n(num? v, [int digits = 1]) => v == null ? '' : v.toStringAsFixed(digits);
  final b = StringBuffer(
    'tempo_s,estado,largura,altura,fps_enviado,fps_recebido,codec,'
    'codificador,limitacao,alvo_mbps,enviado_mbps,recebido_mbps,jitter_ms\n',
  );
  for (final s in samples) {
    final target = s.tx.targetBitrateBps;
    b.writeln(
      [
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
      ].join(','),
    );
  }
  return b.toString();
}
