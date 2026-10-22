import 'package:denden/lab/lab_log.dart';
import 'package:denden/usage/media_stats.dart';
import 'package:flutter_test/flutter_test.dart';

MediaStatsSnapshot snap(int sec, {int sent = 0, int received = 0}) =>
    MediaStatsSnapshot(
      at: DateTime.utc(2026, 1, 1, 0, 0, sec),
      bytesSent: sent,
      bytesReceived: received,
      framesPerSecond: 60,
      frameWidth: 1920,
      frameHeight: 1080,
      codec: 'video/VP8',
      encoderImplementation: 'libvpx',
      qualityLimitationReason: 'cpu',
      targetBitrateBps: 5600000,
      jitterMs: 4,
    );

void main() {
  test('Mbps entre duas leituras', () {
    expect(mbpsBetween(snap(0, sent: 0), snap(2, sent: 1500000)), 6.0);
    expect(
      mbpsBetween(snap(0, received: 0), snap(1, received: 250000), received: true),
      2.0,
    );
  });

  test('leituras no mesmo instante dão 0, não infinito', () {
    expect(mbpsBetween(snap(1), snap(1, sent: 1000)), 0);
  });

  test('cronômetro com milissegundos', () {
    expect(
      formatStopwatch(const Duration(minutes: 1, seconds: 23, milliseconds: 4)),
      '00:01:23.004',
    );
  });

  test('CSV com cabeçalho e uma linha por amostra', () {
    final csv = labCsv([
      LabSample(
        elapsed: const Duration(seconds: 2),
        state: 'connected',
        tx: snap(2, sent: 1500000),
        rx: snap(2, received: 1400000),
        sendMbps: 6,
        receiveMbps: 5.6,
      ),
    ]);
    final lines = csv.trim().split('\n');
    expect(
      lines.first,
      'tempo_s,estado,largura,altura,fps_enviado,fps_recebido,codec,'
      'codificador,limitacao,alvo_mbps,enviado_mbps,recebido_mbps,jitter_ms',
    );
    expect(
      lines[1],
      '2,connected,1920,1080,60.0,60.0,video/VP8,libvpx,cpu,5.60,6.00,5.60,4.0',
    );
  });
}
