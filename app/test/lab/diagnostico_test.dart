import 'package:denden/capture/quality_profile.dart';
import 'package:denden/lab/diagnostico.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

StatsReport out(Map<String, Object?> v) =>
    StatsReport('o', 'outbound-rtp', 0, {'kind': 'video', ...v});
StatsReport inb(Map<String, Object?> v) =>
    StatsReport('i', 'inbound-rtp', 0, {'kind': 'video', ...v});

void main() {
  test('lê a configuração da variável de ambiente', () {
    final c = DiagConfig.parse('seg=30;perfil=medium;csv=C:/tmp/d.csv')!;
    expect(c.duration, const Duration(seconds: 30));
    expect(c.profile, QualityProfile.medium);
    expect(c.csvPath, 'C:/tmp/d.csv');
    expect(DiagConfig.parse(null), isNull);
    expect(() => DiagConfig.parse('seg=5'), throwsFormatException);
  });

  test('calcula fps, kbps, perdas e codificação entre duas leituras', () {
    final row = diagRow(
      second: 3,
      secs: 2,
      prevTx: [
        out({'framesEncoded': 100, 'bytesSent': 0, 'totalEncodeTime': 1.0}),
      ],
      tx: [
        out({
          'framesEncoded': 160,
          'bytesSent': 1000000,
          'totalEncodeTime': 2.2,
          'frameWidth': 1920,
          'frameHeight': 1080,
          'qualityLimitationReason': 'cpu',
        }),
      ],
      prevRx: [
        inb({'framesDecoded': 90, 'bytesReceived': 0, 'packetsLost': 2}),
      ],
      rx: [
        inb({'framesDecoded': 150, 'bytesReceived': 750000, 'packetsLost': 7}),
      ],
    ).values;
    expect(row['enviado_fps'], 30);
    expect(row['enviado_kbps'], 4000);
    expect(row['codificar_ms'], closeTo(20, 0.001));
    expect(row['resolucao_enviada'], '1920x1080');
    expect(row['limitacao'], 'cpu');
    expect(row['recebido_fps'], 30);
    expect(row['recebido_kbps'], 3000);
    expect(row['pacotes_perdidos'], 5);
  });

  test('mede travadas, retransmissões e perda até o SFU', () {
    StatsReport remote(int lost) => StatsReport('r', 'remote-inbound-rtp', 0, {
      'kind': 'video',
      'packetsLost': lost,
    });
    final row = diagRow(
      second: 2,
      secs: 1,
      prevTx: [
        out({'nackCount': 4}),
        remote(10),
      ],
      tx: [
        out({'nackCount': 9}),
        remote(13),
      ],
      prevRx: [
        inb({'freezeCount': 1, 'totalFreezesDuration': 0.5}),
      ],
      rx: [
        inb({'freezeCount': 2, 'totalFreezesDuration': 1.7}),
      ],
    ).values;
    expect(row['travadas'], 1);
    expect(row['travada_ms'], closeTo(1200, 0.001));
    expect(row['nacks'], 5);
    expect(row['perda_ate_sfu'], 3);
  });

  test('só um lado: o outro fica zerado, sem erro', () {
    final row = diagRow(
      second: 1,
      secs: 1,
      prevTx: const [],
      tx: const [],
      prevRx: [
        inb({'framesDecoded': 0}),
      ],
      rx: [
        inb({'framesDecoded': 60}),
      ],
    ).values;
    expect(row['recebido_fps'], 60);
    expect(row['enviado_fps'], 0);
  });

  test('CSV com ponto e vírgula e vírgula decimal', () {
    final line = const DiagRow({'segundo': 1, 'enviado_fps': 29.97}).toCsv();
    expect(line, startsWith('1;30,0;'));
    expect(line.split(';'), hasLength(DiagRow.columns.length));
  });
}
