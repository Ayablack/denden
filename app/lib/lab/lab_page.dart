import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../capture/capture_service.dart';
import '../capture/quality_profile.dart';
import '../logging/sanitize.dart';
import '../usage/media_stats.dart';
import 'lab_log.dart';
import 'loopback_session.dart';

/// Laboratório da Fase A: transmite a tela para o próprio PC, sem servidor,
/// e mostra o que chega do outro lado.
class LabPage extends StatefulWidget {
  const LabPage({super.key, required this.capture, this.tickStopwatch = true});

  final CaptureService capture;

  /// Desligado nos testes de widget (o cronômetro nunca "assenta").
  final bool tickStopwatch;

  @override
  State<LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<LabPage> {
  static const _sampleEvery = Duration(seconds: 2);

  List<CaptureSource> _sources = const [];
  CaptureSource? _source;
  QualityProfile _profile = QualityProfile.high;
  LoopbackSession? _session;
  Timer? _sampler;
  Timer? _ticker;
  final _clock = Stopwatch()..start();
  DateTime? _startedAt;
  MediaStatsSnapshot? _lastTx;
  MediaStatsSnapshot? _lastRx;
  final _samples = <LabSample>[];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.tickStopwatch) {
      _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (mounted) setState(() {});
      });
    }
    _loadSources();
  }

  Future<void> _loadSources() async {
    try {
      final sources = await widget.capture.listSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _source = sources.isEmpty ? null : sources.first;
      });
    } catch (e, st) {
      _fail(e, st);
    }
  }

  void _fail(Object e, StackTrace st) {
    if (!mounted) return;
    setState(() => _error = describeError(e, st));
  }

  Future<void> _start() async {
    final source = _source;
    if (source == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _samples.clear();
      _lastTx = null;
      _lastRx = null;
    });
    try {
      final display = View.of(context).display.size;
      final stream = await widget.capture.start(source, _profile);
      final session = await LoopbackSession.start(
        stream,
        _profile,
        sourceWidth: display.width.round(),
        sourceHeight: display.height.round(),
      );
      session.states.listen((_) {
        if (mounted) setState(() {});
      });
      _startedAt = DateTime.now();
      _sampler = Timer.periodic(_sampleEvery, (_) => _sample());
      setState(() => _session = session);
    } catch (e, st) {
      await widget.capture.stop();
      _fail(e, st);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sample() async {
    final session = _session;
    final startedAt = _startedAt;
    if (session == null || startedAt == null) return;
    try {
      final now = DateTime.now();
      final tx = parseStats(await session.sender.getStats(), now);
      final rx = parseStats(await session.receiver.getStats(), now);
      final lastTx = _lastTx;
      final lastRx = _lastRx;
      _lastTx = tx;
      _lastRx = rx;
      if (lastTx == null || lastRx == null || !mounted) return;
      setState(() {
        _samples.add(
          LabSample(
            elapsed: now.difference(startedAt),
            state: session.state.name,
            tx: tx,
            rx: rx,
            sendMbps: mbpsBetween(lastTx, tx),
            receiveMbps: mbpsBetween(lastRx, rx, received: true),
          ),
        );
      });
    } catch (e, st) {
      // Uma leitura perdida não para o teste.
      debugPrint(describeError(e, st));
    }
  }

  Future<void> _stop() async {
    _sampler?.cancel();
    _sampler = null;
    final session = _session;
    setState(() => _session = null);
    await session?.close();
    await widget.capture.stop();
  }

  Future<void> _exportCsv() async {
    final home = Platform.environment['USERPROFILE'] ?? Directory.current.path;
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final file = File('$home\\Documents\\denden-lab-$stamp.csv');
    try {
      await file.writeAsString(labCsv(_samples));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV salvo em ${file.path}')));
    } catch (e, st) {
      _fail(e, st);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sampler?.cancel();
    _session?.close();
    widget.capture.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final running = session != null;
    final last = _samples.isEmpty ? null : _samples.last;
    final source = _source;
    return Scaffold(
      appBar: AppBar(title: const Text('DenDen — Laboratório (Fase A)')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 380,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  formatStopwatch(
                    widget.tickStopwatch ? _clock.elapsed : Duration.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 40,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Laço local: o vídeo vai e volta dentro deste PC. '
                  'Isto não comprova a transmissão pelo servidor (Fase B).',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                DropdownButton<CaptureSource>(
                  isExpanded: true,
                  value: source,
                  items: [
                    for (final s in _sources)
                      DropdownMenuItem(
                        value: s,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: running ? null : (s) => setState(() => _source = s),
                ),
                if (source != null)
                  Text(
                    source.audioIsolated
                        ? 'Janela: só o som deste programa é transmitido.'
                        : 'Tela inteira: o som do PC todo vai junto, e a voz '
                              'do Discord também. Para jogos, prefira a janela.',
                    style: TextStyle(
                      color: source.audioIsolated ? null : Colors.orange,
                    ),
                  ),
                const SizedBox(height: 8),
                DropdownButton<QualityProfile>(
                  isExpanded: true,
                  value: _profile,
                  items: [
                    for (final p in QualityProfile.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: running
                      ? null
                      : (p) => setState(() => _profile = p ?? _profile),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: running || _busy ? null : _start,
                      child: const Text('Iniciar'),
                    ),
                    OutlinedButton(
                      onPressed: running ? _stop : null,
                      child: const Text('Parar'),
                    ),
                    OutlinedButton(
                      onPressed: _samples.isEmpty ? null : _exportCsv,
                      child: const Text('Exportar CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (session != null) Text('Estado: ${session.state.name}'),
                if (last != null) ..._statsLines(last),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          Expanded(
            child: session == null
                ? const Center(child: Text('Nada sendo recebido'))
                : RTCVideoView(
                    session.remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _statsLines(LabSample s) {
    String f(num? v, [int d = 1]) => v == null ? '—' : v.toStringAsFixed(d);
    final target = s.tx.targetBitrateBps;
    return [
      Text('Tempo: ${formatStopwatch(s.elapsed).substring(0, 8)}'),
      Text(
        'Enviado: ${s.tx.frameWidth ?? '—'}×${s.tx.frameHeight ?? '—'} '
        '@ ${f(s.tx.framesPerSecond, 0)} fps',
      ),
      Text('Recebido: ${f(s.rx.framesPerSecond, 0)} fps'),
      Text('Codec: ${s.rx.codec ?? '—'} (${s.tx.encoderImplementation ?? '—'})'),
      Text('Limitação: ${s.tx.qualityLimitationReason ?? '—'}'),
      Text(
        'Bitrate: ${f(s.sendMbps, 2)} Mbps '
        '(alvo ${target == null ? '—' : f(target / 1e6, 2)})',
      ),
      Text('Jitter: ${f(s.rx.jitterMs)} ms'),
      Text('Amostras: ${_samples.length}'),
    ];
  }
}
