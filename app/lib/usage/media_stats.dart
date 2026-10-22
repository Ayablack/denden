import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../logging/sanitize.dart';

/// Retrato das estatísticas WebRTC de uma conexão num instante.
class MediaStatsSnapshot {
  const MediaStatsSnapshot({
    required this.at,
    required this.bytesSent,
    required this.bytesReceived,
    this.framesPerSecond,
    this.frameWidth,
    this.frameHeight,
    this.codec,
    this.jitterMs,
    this.audioVideoSkewMs,
    this.encoderImplementation,
    this.qualityLimitationReason,
    this.targetBitrateBps,
    this.audioBytesReceived = 0,
    this.audioLevel,
  });

  final DateTime at;

  /// Só bytes de mídia RTP (vídeo + áudio), sem overhead de ICE/DTLS.
  final int bytesSent;
  final int bytesReceived;
  final double? framesPerSecond;
  final int? frameWidth;
  final int? frameHeight;

  /// `mimeType` do codec de vídeo, ex.: `video/H264`.
  final String? codec;

  /// Jitter do vídeo recebido.
  final double? jitterMs;

  /// O WebRTC não expõe isso; a sincronia é medida com um vídeo de teste
  /// (Fase A, A8).
  final double? audioVideoSkewMs;

  /// Ex.: `libvpx`, `OpenH264` (software). Só no lado que envia.
  final String? encoderImplementation;

  /// `none`, `cpu`, `bandwidth` ou `other`. Só no lado que envia.
  final String? qualityLimitationReason;
  final int? targetBitrateBps;

  /// Bytes de áudio recebidos: prova objetiva de que o som chega (A1/A2).
  final int audioBytesReceived;

  /// Nível do áudio recebido, de 0 a 1. Perto de 0 quando a fonte está muda.
  final double? audioLevel;
}

MediaStatsSnapshot parseStats(List<StatsReport> reports, DateTime at) {
  final codecs = {
    for (final r in reports)
      if (r.type == 'codec') r.id: r.values['mimeType'] as String?,
  };
  var sent = 0;
  var received = 0;
  var audioReceived = 0;
  double? audioLevel;
  Map<dynamic, dynamic>? video;
  for (final r in reports) {
    final v = r.values;
    if (r.type == 'outbound-rtp') {
      sent += (v['bytesSent'] as num? ?? 0).toInt();
    } else if (r.type == 'inbound-rtp') {
      received += (v['bytesReceived'] as num? ?? 0).toInt();
      if (v['kind'] == 'audio') {
        audioReceived += (v['bytesReceived'] as num? ?? 0).toInt();
        audioLevel = (v['audioLevel'] as num?)?.toDouble() ?? audioLevel;
      }
    } else {
      continue;
    }
    if (v['kind'] == 'video') video = v;
  }
  final jitter = video?['jitter'] as num?;
  return MediaStatsSnapshot(
    at: at,
    bytesSent: sent,
    bytesReceived: received,
    framesPerSecond: (video?['framesPerSecond'] as num?)?.toDouble(),
    frameWidth: (video?['frameWidth'] as num?)?.toInt(),
    frameHeight: (video?['frameHeight'] as num?)?.toInt(),
    codec: codecs[video?['codecId']],
    jitterMs: jitter == null ? null : jitter * 1000,
    encoderImplementation: video?['encoderImplementation'] as String?,
    qualityLimitationReason: video?['qualityLimitationReason'] as String?,
    targetBitrateBps: (video?['targetBitrate'] as num?)?.toInt(),
    audioBytesReceived: audioReceived,
    audioLevel: audioLevel,
  );
}

/// Lê `getStats` periodicamente. Erros são registrados e ignorados: o
/// painel nunca derruba a transmissão.
class StatsSampler {
  StatsSampler(
    this._pc, {
    Duration every = const Duration(seconds: 10),
    void Function(String)? log,
  }) : _log = log ?? ((_) {}) {
    _timer = Timer.periodic(every, (_) => _sample());
  }

  final RTCPeerConnection _pc;
  final void Function(String) _log;
  final _snapshots = StreamController<MediaStatsSnapshot>.broadcast();
  late final Timer _timer;

  Stream<MediaStatsSnapshot> get snapshots => _snapshots.stream;

  Future<void> _sample() async {
    try {
      final reports = await _pc.getStats();
      if (!_snapshots.isClosed) {
        _snapshots.add(parseStats(reports, DateTime.now()));
      }
    } catch (e, st) {
      _log(describeError(e, st));
    }
  }

  void dispose() {
    _timer.cancel();
    _snapshots.close();
  }
}
