import 'dart:io';

import 'package:denden/lab/sdp_hints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Resposta SDP real do laço local (Windows, flutter_webrtc 1.6.2).
  final answer = File('test/lab/fixtures/answer.sdp').readAsStringSync();

  test('VP8 ganha x-google-max-bitrate em kbps', () {
    final out = withBitrateHints(answer, maxBitrateBps: 6000000);
    expect(out, contains('a=fmtp:96 x-google-max-bitrate=6000\r\n'));
  });

  test('outros codecs ficam intactos', () {
    final out = withBitrateHints(answer, maxBitrateBps: 6000000);
    expect(
      out,
      contains(
        'a=fmtp:103 level-asymmetry-allowed=1;packetization-mode=1;'
        'profile-level-id=42001f\r\n',
      ),
    );
    expect('x-google'.allMatches(out), hasLength(1));
  });

  test('VP8 com fmtp existente recebe o parâmetro no fim', () {
    const sdp =
        'v=0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
        'a=rtpmap:96 VP8/90000\r\na=fmtp:96 foo=1\r\n';
    expect(
      withBitrateHints(sdp, maxBitrateBps: 3500000),
      'v=0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
      'a=rtpmap:96 VP8/90000\r\na=fmtp:96 foo=1;x-google-max-bitrate=3500\r\n',
    );
  });

  test('aplicar duas vezes não duplica', () {
    final once = withBitrateHints(answer, maxBitrateBps: 6000000);
    expect(withBitrateHints(once, maxBitrateBps: 6000000), once);
  });
}
