import 'dart:async';

import 'package:flutter/material.dart';

import '../rooms/worker_api.dart';
import '../usage/format.dart';
import 'capture_control.dart';
import 'componentes.dart';
import 'tema.dart';

/// Painel de consumo do mês. Números sempre rotulados: o que é estimativa do
/// DenDen, o que o Cloudflare confirmou e o que foi faturado de fato.
class UsagePage extends StatefulWidget {
  const UsagePage({super.key, required this.load, this.autoRefresh = true});

  /// `GET /consumo` (amigo) ou `GET /admin/consumo` (administrador).
  final Future<Map<String, dynamic>> Function() load;
  final bool autoRefresh;

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  Map<String, dynamic>? _data;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    if (widget.autoRefresh) {
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consumo'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: d == null
          ? Center(child: Text(_error ?? 'Carregando…'))
          : _UsageView(d, error: _error),
    );
  }
}

num _n(Object? v) => (v as num?) ?? 0;

class _UsageView extends StatelessWidget {
  const _UsageView(this.d, {this.error});

  final Map<String, dynamic> d;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final config = Map<String, dynamic>.from(d['config'] as Map);
    final budgetGb = _n(config['budgetGb']);
    final percent = _n(d['percentOfBudget']);
    final effective = _n(d['effectiveEgressBytes']);
    final projection = _n(d['projectionBytes']);
    final confirmed = d['confirmedGb'] as num?;
    final billed = d['billedBrl'] as num?;
    final warnings = [
      for (final w in (d['warnings'] as List? ?? const []))
        Map<String, dynamic>.from(w as Map),
    ];
    final rooms = [
      for (final r in (d['rooms'] as List? ?? const []))
        Map<String, dynamic>.from(r as Map),
    ];
    final history = [
      for (final h in (d['history'] as List? ?? const []))
        Map<String, dynamic>.from(h as Map),
    ];

    final c = Theme.of(context).colorScheme;
    final cheio = percent >= 90;
    return CorpoTela(
      larguraMaxima: 1100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Faixa(error!, erro: true),
            const SizedBox(height: 12),
          ],
          if (d['emergency'] == true) ...[
            const Faixa(
              'Emergência ligada: transmissões desligadas.',
              erro: true,
            ),
            const SizedBox(height: 12),
          ],
          Painel(
            titulo: 'Mês ${d['month']} (UTC)',
            icone: Icons.calendar_month_outlined,
            acao: Selo(
              '${formatPercent(percent)} do orçamento '
              '(${formatBytes(budgetGb * 1e9)})',
              cor: cheio ? DenDenCores.aviso : c.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    color: cheio ? DenDenCores.aviso : c.primary,
                    value: (percent / 100).clamp(0, 1).toDouble(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in warnings)
                      Selo(
                        w['reached'] == true
                            ? '${w['percent']}% atingido'
                            : '${w['percent']}%',
                        cor: w['reached'] == true
                            ? DenDenCores.aviso
                            : c.onSurfaceVariant,
                      ),
                  ],
                ),
                if (projection > budgetGb * 1e9) ...[
                  const SizedBox(height: 12),
                  Faixa(
                    'No ritmo atual, o mês fecha em ${formatBytes(projection)}, '
                    'acima do orçamento. Para gastar menos, transmita em Média ou '
                    'Economia.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final colunas = box.maxWidth >= 900 ? 4 : 2;
              final largura = (box.maxWidth - 16 * (colunas - 1)) / colunas;
              final metricas = [
                _Metrica(
                  'Estimado',
                  Icons.query_stats,
                  formatBytes(effective),
                  [
                    'Relatado pelos apps: '
                        '${formatBytes(_n(d['reportedEgressBytes']))}',
                    'Calculado pelo servidor: '
                        '${formatBytes(_n(d['serverEgressBytes']))}',
                    'Vale a maior das duas estimativas.',
                    'Franquia gratuita: ${formatBytes(effective)} de '
                        '${formatBytes(_n(config['freeGb']) * 1e9)}',
                  ],
                ),
                _Metrica(
                  'Confirmado pelo Cloudflare',
                  Icons.verified_outlined,
                  confirmed == null ? '—' : formatBytes(confirmed * 1e9),
                  const [],
                ),
                _Metrica(
                  'Custo estimado',
                  Icons.payments_outlined,
                  formatUsd(_n(d['estimatedCostUsd'])),
                  [
                    '${formatUsd(_n(d['estimatedCostUsd']))} '
                        '(≈ ${formatBrl(_n(d['estimatedCostBrl']))}, câmbio '
                        'estimado ${formatBrl(_n(config['brlPerUsd']))}; tarifa '
                        '${formatUsd(_n(config['usdPerGb']))}/GB acima da '
                        'franquia)',
                  ],
                ),
                _Metrica(
                  'Faturado',
                  Icons.receipt_long_outlined,
                  billed == null ? '—' : formatBrl(billed),
                  const [],
                ),
              ];
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final m in metricas) SizedBox(width: largura, child: m),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final aoVivo = Painel(
                titulo: 'Transmissões ao vivo',
                icone: Icons.sensors,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rooms.isEmpty) const Dica('Nenhuma agora.'),
                    for (final r in rooms) ...[
                      Text(
                        'Sala ${formatRoomCode(r['code'] as String)}: '
                        '${formatBytes(_n(r['egressBytes']))} enviados aos '
                        'espectadores (transmissor mandou '
                        '${formatBytes(_n(r['publisherSentBytes']))})',
                      ),
                      for (final (i, v) in (r['viewers'] as List).indexed)
                        Dica(
                          '   Espectador ${i + 1}: '
                          '${formatBytes(_n((v as Map)['receivedBytes']))}',
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              );
              final historico = Painel(
                titulo: 'Histórico',
                icone: Icons.history,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (history.isEmpty)
                      const Dica('Nenhuma transmissão encerrada.'),
                    for (final h in history)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${formatRoomCode(h['code'] as String)}: '
                          '${((_n(h['endedAt']) - _n(h['startedAt'])) / 60000).round()} min, '
                          '${h['reason']}, ${formatBytes(_n(h['egressBytes']))}',
                        ),
                      ),
                  ],
                ),
              );
              if (box.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [aoVivo, const SizedBox(height: 16), historico],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: aoVivo),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: historico),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Faixa(d['notice'] as String? ?? ''),
        ],
      ),
    );
  }
}

/// Um dos quatro números do mês, sempre com o rótulo.
class _Metrica extends StatelessWidget {
  const _Metrica(this.titulo, this.icone, this.valor, this.detalhes);

  final String titulo;
  final IconData icone;
  final String valor;
  final List<String> detalhes;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(titulo)),
                Icon(icone, size: 18, color: c.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valor,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            for (final t in detalhes) ...[const SizedBox(height: 4), Dica(t)],
          ],
        ),
      ),
    );
  }
}
