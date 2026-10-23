import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'capture_service.dart';
import 'discord.dart';
import 'quality_profile.dart';

typedef ProcessListFn = Future<List<ProcessEntry>> Function();
typedef DiscordPidsFn = Future<Set<int>> Function();

/// Tela inteira com o som do PC todo, **menos o Discord** (a voz da call não
/// vai para quem assiste).
///
/// O Windows exclui a árvore de processos do Discord que estava aberto no
/// início. Se depois aparecer um Discord fora dela (abriu durante a
/// transmissão, ou fechou e abriu de novo), o áudio é silenciado e [errors]
/// avisa: melhor ficar sem som do que vazar a voz.
class PcWithoutDiscordCapture {
  PcWithoutDiscordCapture({
    CaptureService? capture,
    ProcessListFn? listProcesses,
    DiscordPidsFn? runningDiscordPids,
    this.watchEvery = const Duration(seconds: 3),
  }) : _capture = capture ?? CaptureService(),
       _listProcesses = listProcesses ?? _defaultListProcesses,
       _runningDiscordPids = runningDiscordPids ?? _defaultRunningPids;

  static Future<List<ProcessEntry>> _defaultListProcesses() => listProcesses();
  static Future<Set<int>> _defaultRunningPids() => runningDiscordPids();

  final CaptureService _capture;
  final ProcessListFn _listProcesses;
  final DiscordPidsFn _runningDiscordPids;
  final Duration watchEvery;

  final _errors = StreamController<CaptureError>.broadcast();
  MediaStream? _stream;
  int? _excludedRoot;
  Timer? _watch;
  bool _checking = false;

  /// Ex.: `discord_fora`.
  Stream<CaptureError> get errors => _errors.stream;

  /// O som ainda está indo (não foi silenciado pelo vigia).
  bool get audioActive =>
      _stream?.getAudioTracks().any((t) => t.enabled) ?? false;

  Future<MediaStream> start(CaptureSource screen, QualityProfile p) async {
    if (screen.isWindow) {
      throw ArgumentError.value(screen.name, 'screen', 'precisa ser uma tela');
    }
    await stop();
    final int? root;
    try {
      root = discordRoot(await _listProcesses());
    } on DiscordError catch (e) {
      throw CaptureError(e.code, e.message);
    }
    _excludedRoot = root;
    final stream = await _capture.start(screen, p, excludeProcessId: root);
    _stream = stream;
    _watch = Timer.periodic(watchEvery, (_) => _check());
    return stream;
  }

  Future<void> _check() async {
    if (_checking || _stream == null) return;
    _checking = true;
    try {
      final running = await _runningDiscordPids();
      if (discordLeaks(excludedRoot: _excludedRoot, running: running)) {
        _silence();
      }
    } catch (_) {
      // Falha ao listar processos não é motivo para cortar o som.
    } finally {
      _checking = false;
    }
  }

  void _silence() {
    _watch?.cancel();
    _watch = null;
    for (final t in _stream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = false;
    }
    _errors.add(
      const CaptureError(
        'discord_fora',
        'Um Discord abriu depois do início. O som foi cortado para a voz da '
            'call não vazar. Pare e transmita de novo para voltar o som.',
      ),
    );
  }

  Future<void> stop() async {
    _watch?.cancel();
    _watch = null;
    _stream = null;
    _excludedRoot = null;
    await _capture.stop();
  }
}
