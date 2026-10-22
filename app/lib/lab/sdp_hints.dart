/// Sem `x-google-max-bitrate`, o libwebrtc limita o vídeo pela tabela padrão
/// por resolução (2,5 Mbps de 720p para cima), ignorando o `maxBitrate` da
/// codificação. Medido na Fase A: o alvo travava em 2,5 Mbps com 4,7 Mbps
/// disponíveis.
///
/// Só no VP8: é o codec usado hoje, e o único testado com o parâmetro.
String withBitrateHints(String sdp, {required int maxBitrateBps}) {
  const nl = '\r\n';
  final hint = 'x-google-max-bitrate=${maxBitrateBps ~/ 1000}';
  final lines = sdp.split(nl);
  final vp8 = {
    for (final l in lines)
      ?RegExp(r'^a=rtpmap:(\d+) VP8/90000$').firstMatch(l)?[1],
  };
  final hasFmtp = <String>{};
  final out = <String>[];
  for (final l in lines) {
    final m = RegExp(r'^a=fmtp:(\d+) (.*)$').firstMatch(l);
    if (m != null && vp8.contains(m[1])) {
      hasFmtp.add(m[1]!);
      out.add(m[2]!.contains('x-google-max-bitrate') ? l : '$l;$hint');
    } else {
      out.add(l);
    }
  }
  final result = <String>[];
  for (final l in out) {
    result.add(l);
    final pt = RegExp(r'^a=rtpmap:(\d+) VP8/90000$').firstMatch(l)?[1];
    if (pt != null && !hasFmtp.contains(pt)) result.add('a=fmtp:$pt $hint');
  }
  return result.join(nl);
}
