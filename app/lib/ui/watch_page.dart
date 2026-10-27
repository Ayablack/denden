import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../media/cloudflare_media.dart';
import 'capture_control.dart';
import 'componentes.dart';
import 'tema.dart';

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

  Widget _form() {
    final c = Theme.of(context).colorScheme;
    return CorpoTela(
      larguraMaxima: 520,
      centralizar: true,
      child: Painel(
        titulo: 'Assistir a uma transmissão',
        icone: Icons.live_tv,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Dica('Digite o código que quem transmite passou no Discord.'),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              autofocus: true,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 20,
                letterSpacing: 4,
                color: c.primary,
              ),
              decoration: const InputDecoration(
                labelText: 'Código da sala',
                hintText: 'K7P-92Q',
              ),
              onSubmitted: (_) => _busy ? null : _watch(),
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _watch,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 20),
                      SizedBox(width: 8),
                      Text('Assistir'),
                    ],
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Faixa(_error!, erro: true),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _watch,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tentar de novo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _player() {
    final renderer = _renderer;
    return switch (_state) {
      LinkState.ended => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tv_off,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text('Transmissão encerrada', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _leave, child: const Text('Voltar')),
          ],
        ),
      ),
      LinkState.live || LinkState.reconnecting when renderer != null => Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
            ),
          ),
          if (_state == LinkState.reconnecting)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Selo('Reconectando…', cor: DenDenCores.aviso),
              ),
            ),
        ],
      ),
      _ => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Conectando…'),
          ],
        ),
      ),
    };
  }
}
