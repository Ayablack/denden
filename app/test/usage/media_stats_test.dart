import 'dart:convert';
import 'dart:io';

import 'package:denden/usage/media_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

List<StatsReport> loadFixture(String name) => [
  for (final m in jsonDecode(
    File('test/usage/fixtures/$name').readAsStringSync(),
  ) as List)
    StatsReport.fromMap(Map<String, dynamic>.from(m as Map)),
];

void main() {
  test('soma bytes de vídeo e áudio e lê codec', () {
    final s = parseStats(loadFixture('sender_h264.json'), DateTime.utc(2026));
    // candidate-pair não entra: só bytes de mídia (RTP).
    expect(s.bytesSent, 1500000 + 40000);
    expect(s.bytesReceived, 0);
    expect(s.codec, 'video/H264');
    expect(s.frameWidth, 1920);
    expect(s.frameHeight, 1080);
    expect(s.framesPerSecond, 60);
    expect(s.encoderImplementation, 'OpenH264');
    expect(s.qualityLimitationReason, 'cpu');
    expect(s.targetBitrateBps, 5600000);
  });

  test('lado receptor: bytes recebidos e jitter do vídeo em ms', () {
    final s = parseStats(loadFixture('receiver_vp8.json'), DateTime.utc(2026));
    expect(s.bytesReceived, 1200000 + 30000);
    expect(s.codec, 'video/VP8');
    expect(s.framesPerSecond, 59.5);
    expect(s.jitterMs, closeTo(4.0, 1e-9));
    expect(s.audioBytesReceived, 30000);
    expect(s.audioLevel, closeTo(0.25, 1e-9));
  });

  test('relatório vazio vira zeros, não erro', () {
    final s = parseStats(const [], DateTime.utc(2026));
    expect(s.bytesSent, 0);
    expect(s.bytesReceived, 0);
    expect(s.codec, isNull);
    expect(s.framesPerSecond, isNull);
  });
}
