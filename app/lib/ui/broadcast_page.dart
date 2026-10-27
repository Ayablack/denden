import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/capture_service.dart';
import '../capture/quality_profile.dart';
import '../media/cloudflare_media.dart';
import '../rooms/worker_api.dart';
import '../usage/format.dart';
import 'capture_control.dart';

/// Transmitir: vídeo da tela inteira e áudio só da janela do jogo.
class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key, required this.media, required this.capture});

  final MediaPort media;
  final CaptureControl capture;

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  List<CaptureSource> _screens = const [];
  List<CaptureSource> _windows = const [];
  CaptureSource? _screen;
  AudioChoice _audio = const PcAudio();
  QualityProfile _profile = QualityProfile.high;
  BroadcastHandle? _broadcast;
  final _subs = <StreamSubscription<Object>>[];
  LinkState? _state;
  ReportReply? _reply;
  String? _error;
  String? _captureWarning;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sources = await widget.capture.listSources();
    if (!mounted) return;
    setState(() {
      _screens = sources.where((s) => !s.isWindow).toList();
      // A própria janela do DenDen não serve de fonte de áudio.
      _windows = sources
          .where((s) => s.isWindow && !s.name.contains('DenDen'))
          .toList();
      _screen = _screens.firstOrNull;
    });
  }

  Future<void> _start() async {
    final screen = _screen;
    if (screen == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _captureWarning = null;
    });
    try {
      final size = View.of(context).display.size;
      final stream = await widget.capture.start(screen, _audio, _profile);
      final b = await widget.media.publish(
        stream,
        _profile,
        sourceWidth: size.width.round(),
        sourceHeight: size.height.round(),
      );
      _subs
        ..add(b.states.listen((s) => setState(() => _state = s)))
        ..add(
          b.replies.listen((r) {
            final wanted = profileFromWire(r.profile);
            setState(() {
              _reply = r;
              if (wanted != null) _profile = wanted;
            });
          }),
        )
        ..add(
          widget.capture.errors.listen(
            (e) => setState(() => _captureWarning = e.message),
          ),
        );
      setState(() {
        _broadcast = b;
        _state = b.state;
      });
    } catch (e) {
      await widget.capture.stop();
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final b = _broadcast;
    final screen = _screen;
    if (b == null || screen == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final size = View.of(context).display.size;
      final forcedEconomy =
          _reply?.level == 'blocked' || _reply?.level == 'ceiling';
      final targetProfile = forcedEconomy ? QualityProfile.economy : _profile;
      final track = await widget.capture.startVideo(screen, targetProfile);
      await b.replaceVideo(
        track,
        targetProfile,
        sourceWidth: size.width.round(),
        sourceHeight: size.height.round(),
      );
      if (mounted) {
        setState(() => _profile = targetProfile);
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    // Não esperar o cancelamento: em streams broadcast ele é imediato.
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    await _broadcast?.stop();
    await widget.capture.stop();
    if (mounted) {
      setState(() {
        _broadcast = null;
        _state = null;
        _reply = null;
      });
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _broadcast?.stop();
    widget.capture.stop();
    super.dispose();
  }

  /// Sair da tela derruba a transmissão: com ela no ar (ou conectando), a
  /// seta de voltar e o Esc perguntam antes.
  bool get _canLeave => _broadcast == null && !_busy;

  Future<void> _onLeaveAttempt(bool didPop, Object? _) async {
    if (didPop || _busy) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parar a transmissão?'),
        content: const Text('Quem está assistindo vai perder a imagem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar transmitindo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Parar e sair'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    await _stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _canLeave,
    onPopInvokedWithResult: _onLeaveAttempt,
    child: Scaffold(
      appBar: AppBar(title: const Text('Transmitir')),
      body: Center(
        child: SizedBox(
          width: 460,
          child: _broadcast == null ? _setup() : _live(_broadcast!),
        ),
      ),
    ),
  );

  Widget _setup() => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.all(16),
    children: [
      if (_screens.length > 1)
        DropdownButtonFormField<CaptureSource>(
          key: ValueKey(_screen),
          initialValue: _screen,
          decoration: const InputDecoration(labelText: 'Tela'),
          items: [
            for (final s in _screens)
              DropdownMenuItem(value: s, child: Text(s.name)),
          ],
          onChanged: (s) => setState(() => _screen = s),
        ),
      DropdownButtonFormField<AudioChoice>(
        key: ValueKey(_audio),
        initialValue: _audio,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Áudio de'),
        items: [
          const DropdownMenuItem(
            value: PcAudio(),
            child: Text('PC inteiro, menos o Discord'),
          ),
          for (final w in _windows)
            DropdownMenuItem(
              value: WindowAudio(w),
              child: Text(w.name, overflow: TextOverflow.ellipsis),
            ),
          const DropdownMenuItem(value: NoAudio(), child: Text('Sem áudio')),
        ],
        onChanged: (a) => setState(() => _audio = a ?? _audio),
      ),
      const SizedBox(height: 4),
      Text(switch (_audio) {
        PcAudio() =>
          'Vai todo o som do PC, menos o Discord. Outros apps de voz '
              '(WhatsApp, Discord no navegador) entram.',
        WindowAudio() =>
          'Só o som desta janela vai junto. A voz do Discord não entra.',
        NoAudio() => 'Sem áudio.',
      }, style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 12),
      DropdownButtonFormField<QualityProfile>(
        key: ValueKey(_profile),
        initialValue: _profile,
        decoration: const InputDecoration(labelText: 'Qualidade'),
        items: [
          for (final p in QualityProfile.values)
            DropdownMenuItem(value: p, child: Text(p.label)),
        ],
        onChanged: (p) => setState(() => _profile = p ?? _profile),
      ),
      const SizedBox(height: 20),
      if (_busy)
        const Center(child: CircularProgressIndicator())
      else
        FilledButton(onPressed: _start, child: const Text('Transmitir')),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
    ],
  );

  Widget _live(BroadcastHandle b) {
    final code = formatRoomCode(b.roomCode);
    final reply = _reply;
    final roomBytes = reply?.roomEgressBytes;
    final monthBytes = reply?.monthEgressBytes;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        const Center(child: Text('Passe este código no Discord:')),
        Center(
          child: SelectableText(
            code,
            style: const TextStyle(fontSize: 48, letterSpacing: 4),
          ),
        ),
        Center(
          child: TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(switch (_state) {
            LinkState.live => 'Transmitindo',
            LinkState.reconnecting => 'Reconectando…',
            LinkState.ended => 'Transmissão encerrada',
            _ => 'Conectando…',
          }),
        ),
        if (roomBytes != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text('Consumo desta transmissão: ${formatBytes(roomBytes)}'),
          ),
        ],
        if (monthBytes != null) ...[
          const SizedBox(height: 4),
          Center(child: Text('Consumo do mês: ${formatBytes(monthBytes)}')),
        ],
        if (_captureWarning != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _captureWarning!,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        if (reply != null && reply.level != 'normal')
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(switch (reply.level) {
              'warn' => 'Atenção: mais de 90% do limite do mês.',
              'blocked' =>
                'Limite do mês atingido: qualidade reduzida para Economia.',
              _ => 'Acima do teto do mês: a transmissão será encerrada em instantes.',
            }, style: const TextStyle(color: Colors.orange)),
          ),
        if (_minutesLeft(reply) case final left?)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'A transmissão termina em $left min pela duração máxima. '
              'Para continuar, transmita de novo.',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        const SizedBox(height: 16),
        if (_screens.isNotEmpty)
          DropdownButtonFormField<CaptureSource>(
            key: ValueKey(_screen),
            initialValue: _screen,
            decoration: const InputDecoration(labelText: 'Tela'),
            items: [
              for (final s in _screens)
                DropdownMenuItem(value: s, child: Text(s.name)),
            ],
            onChanged: (s) => setState(() => _screen = s),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<QualityProfile>(
          key: ValueKey(_profile),
          initialValue: _profile,
          decoration: const InputDecoration(labelText: 'Qualidade'),
          items: [
            for (final p in QualityProfile.values)
              DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: (p) => setState(() => _profile = p ?? _profile),
        ),
        const SizedBox(height: 12),
        if (_busy)
          const Center(child: CircularProgressIndicator())
        else
          FilledButton.tonal(
            onPressed: _apply,
            child: const Text('Aplicar'),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(onPressed: _stop, child: const Text('Parar')),
        ),
      ],
    );
  }

  /// Minutos até o fim pela duração máxima, só nos últimos 5 minutos.
  int? _minutesLeft(ReportReply? reply) {
    final end = reply?.sessionEndsAtMs;
    if (end == null) return null;
    final ms = end - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0 || ms > 5 * 60 * 1000) return null;
    return (ms / 60000).ceil();
  }
}
