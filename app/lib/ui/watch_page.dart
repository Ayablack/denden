import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../media/cloudflare_media.dart';
import 'capture_control.dart';

/// Assistir: digitar o código e ver a tela do amigo, com o som do jogo.
class WatchPage extends StatefulWidget {
  const WatchPage({super.key, required this.media, this.initRenderer});

  final MediaPort media;

  /// Só para testes; sem ele, inicializa o renderizador de verdade.
  final Future<void> Function(RTCVideoRenderer)? initRenderer;

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  final _code = TextEditingController();
  RTCVideoRenderer? _renderer;
  ViewingHandle? _viewing;
  StreamSubscription<LinkState>? _sub;
  LinkState? _state;
  String? _error;
  bool _busy = false;

  Future<void> _watch() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final renderer = RTCVideoRenderer();
    try {
      await (widget.initRenderer ?? (r) => r.initialize())(renderer);
      final v = await widget.media.watch(_code.text, renderer);
      _sub = v.states.listen((s) {
        if (mounted) setState(() => _state = s);
      });
      setState(() {
        _renderer = renderer;
        _viewing = v;
        _state = v.state;
      });
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    unawaited(_sub?.cancel());
    await _viewing?.leave();
    if (mounted) {
      setState(() {
        _viewing = null;
        _state = null;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _viewing?.leave();
    _renderer?.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewing = _viewing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistir'),
        actions: [
          if (viewing != null)
            TextButton(onPressed: _leave, child: const Text('Sair')),
        ],
      ),
      body: viewing == null ? _form() : _player(),
    );
  }

  Widget _form() => Center(
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Código da sala',
              hintText: 'K7P-92Q',
            ),
            onSubmitted: (_) => _busy ? null : _watch(),
          ),
          const SizedBox(height: 16),
          if (_busy)
            const CircularProgressIndicator()
          else
            FilledButton(onPressed: _watch, child: const Text('Assistir')),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _watch, child: const Text('Tentar de novo')),
          ],
        ],
      ),
    ),
  );

  Widget _player() {
    final renderer = _renderer;
    return switch (_state) {
      LinkState.ended => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Transmissão encerrada', style: TextStyle(fontSize: 22)),
            TextButton(onPressed: _leave, child: const Text('Voltar')),
          ],
        ),
      ),
      LinkState.live || LinkState.reconnecting when renderer != null => Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            ),
          ),
          if (_state == LinkState.reconnecting)
            const Align(
              alignment: Alignment.topCenter,
              child: Text('Reconectando…'),
            ),
        ],
      ),
      _ => const Center(child: Text('Conectando…')),
    };
  }
}
