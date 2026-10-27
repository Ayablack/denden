import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/capture_service.dart';
import '../capture/quality_profile.dart';
import '../media/cloudflare_media.dart';
import '../rooms/worker_api.dart';
import '../usage/format.dart';
import 'capture_control.dart';
import 'componentes.dart';
import 'tema.dart';

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
      body: _broadcast == null
          ? CorpoTela(larguraMaxima: 520, child: _setup())
          : CorpoTela(child: _live(_broadcast!)),
    ),
  );

  Widget _erro() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      _error!,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  Widget _botaoComIcone(IconData icone, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icone, size: 20), const SizedBox(width: 8), Text(texto)],
  );

  DropdownButtonFormField<CaptureSource> _campoTela() =>
      DropdownButtonFormField<CaptureSource>(
        key: ValueKey(_screen),
        initialValue: _screen,
        decoration: const InputDecoration(labelText: 'Tela'),
        items: [
          for (final s in _screens)
            DropdownMenuItem(value: s, child: Text(s.name)),
        ],
        onChanged: (s) => setState(() => _screen = s),
      );

  DropdownButtonFormField<QualityProfile> _campoQualidade() =>
      DropdownButtonFormField<QualityProfile>(
        key: ValueKey(_profile),
        initialValue: _profile,
        decoration: const InputDecoration(labelText: 'Qualidade'),
        items: [
          for (final p in QualityProfile.values)
            DropdownMenuItem(value: p, child: Text(p.label)),
        ],
        onChanged: (p) => setState(() => _profile = p ?? _profile),
      );

  Widget _setup() => Painel(
    titulo: 'Transmitir',
    icone: Icons.cast,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_screens.length > 1) ...[_campoTela(), const SizedBox(height: 16)],
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
        const SizedBox(height: 6),
        Dica(switch (_audio) {
          PcAudio() =>
            'Vai todo o som do PC, menos o Discord. Outros apps de voz '
                '(WhatsApp, Discord no navegador) entram.',
          WindowAudio() =>
            'Só o som desta janela vai junto. A voz do Discord não entra.',
          NoAudio() => 'Sem áudio.',
        }),
        const SizedBox(height: 16),
        _campoQualidade(),
        const SizedBox(height: 24),
        if (_busy)
          const Center(child: CircularProgressIndicator())
        else
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _start,
              child: _botaoComIcone(Icons.videocam_outlined, 'Transmitir'),
            ),
          ),
        if (_error != null) _erro(),
      ],
    ),
  );

  Widget _live(BroadcastHandle b) {
    final c = Theme.of(context).colorScheme;
    final reply = _reply;
    final avisos = [
      ?_captureWarning,
      if (reply != null && reply.level != 'normal')
        switch (reply.level) {
          'warn' => 'Atenção: mais de 90% do limite do mês.',
          'blocked' =>
            'Limite do mês atingido: qualidade reduzida para Economia.',
          _ =>
            'Acima do teto do mês: a transmissão será encerrada em instantes.',
        },
      if (_minutesLeft(reply) case final left?)
        'A transmissão termina em $left min pela duração máxima. '
            'Para continuar, transmita de novo.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _barraEstado(c),
        for (final a in avisos) ...[const SizedBox(height: 12), Faixa(a)],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final codigo = _painelCodigo(b, c);
            final lado = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (reply?.roomEgressBytes != null ||
                    reply?.monthEgressBytes != null) ...[
                  _painelConsumo(reply!, c),
                  const SizedBox(height: 16),
                ],
                _painelAjustes(),
              ],
            );
            if (box.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [codigo, const SizedBox(height: 16), lado],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: codigo),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: lado),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _barraEstado(ColorScheme c) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: switch (_state) {
                LinkState.live => Selo('Transmitindo', cor: c.primary),
                LinkState.reconnecting => const Selo(
                  'Reconectando…',
                  cor: DenDenCores.aviso,
                ),
                LinkState.ended => Selo('Transmissão encerrada', cor: c.error),
                _ => Selo('Conectando…', cor: c.onSurfaceVariant),
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.error,
              foregroundColor: Colors.white,
            ),
            onPressed: _stop,
            child: _botaoComIcone(Icons.stop_circle_outlined, 'Parar'),
          ),
        ],
      ),
    ),
  );

  Widget _painelCodigo(BroadcastHandle b, ColorScheme c) {
    final code = formatRoomCode(b.roomCode);
    return Painel(
      titulo: 'Código da sala',
      icone: Icons.key_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.outlineVariant),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                const Dica('Passe este código no Discord:'),
                const SizedBox(height: 8),
                SelectableText(
                  code,
                  style: TextStyle(
                    fontSize: 48,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Consolas',
                    color: c.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: _botaoComIcone(Icons.copy, 'Copiar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _painelConsumo(ReportReply r, ColorScheme c) => Painel(
    titulo: 'Consumo',
    icone: Icons.data_usage,
    child: Column(
      children: [
        if (r.roomEgressBytes case final bytes?)
          _linhaValor('Consumo desta transmissão', formatBytes(bytes), c),
        if (r.monthEgressBytes case final bytes?)
          _linhaValor('Consumo do mês', formatBytes(bytes), c),
      ],
    ),
  );

  Widget _linhaValor(String rotulo, String valor, ColorScheme c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text('$rotulo:')),
        Text(
          valor,
          style: TextStyle(color: c.primary, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _painelAjustes() => Painel(
    titulo: 'Ajustes da transmissão',
    icone: Icons.tune,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_screens.isNotEmpty) ...[_campoTela(), const SizedBox(height: 16)],
        _campoQualidade(),
        const SizedBox(height: 20),
        if (_busy)
          const Center(child: CircularProgressIndicator())
        else
          FilledButton.tonal(onPressed: _apply, child: const Text('Aplicar')),
        if (_error != null) _erro(),
      ],
    ),
  );

  /// Minutos até o fim pela duração máxima, só nos últimos 5 minutos.
  int? _minutesLeft(ReportReply? reply) {
    final end = reply?.sessionEndsAtMs;
    if (end == null) return null;
    final ms = end - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0 || ms > 5 * 60 * 1000) return null;
    return (ms / 60000).ceil();
  }
}
