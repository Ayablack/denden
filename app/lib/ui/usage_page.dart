import 'dart:async';

import 'package:flutter/material.dart';

import '../rooms/worker_api.dart';
import '../usage/format.dart';
import 'capture_control.dart';

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

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (d['emergency'] == true)
            const Text(
              'Emergência ligada: transmissões desligadas.',
              style: TextStyle(color: Colors.red),
            ),
          Text('Mês ${d['month']} (UTC)', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (percent / 100).clamp(0, 1).toDouble(),
          ),
          Text(
            '${formatPercent(percent)} do orçamento '
            '(${formatBytes(budgetGb * 1e9)})',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final w in warnings)
                Chip(
                  label: Text(
                    w['reached'] == true
                        ? '${w['percent']}% atingido'
                        : '${w['percent']}%',
                  ),
                  backgroundColor: w['reached'] == true
                      ? Colors.orange.shade200
                      : null,
                ),
            ],
          ),
          if (projection > budgetGb * 1e9)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No ritmo atual, o mês fecha em ${formatBytes(projection)}, '
                'acima do orçamento. Para gastar menos, transmita em Média ou '
                'Economia.',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
          _label('Estimado'),
          Text(formatBytes(effective), style: const TextStyle(fontSize: 22)),
          Text(
            'Relatado pelos apps: ${formatBytes(_n(d['reportedEgressBytes']))}',
          ),
          Text(
            'Calculado pelo servidor: ${formatBytes(_n(d['serverEgressBytes']))}',
          ),
          const Text('Vale a maior das duas estimativas.'),
          Text(
            'Franquia gratuita: ${formatBytes(effective)} de '
            '${formatBytes(_n(config['freeGb']) * 1e9)}',
          ),
          _label('Confirmado pelo Cloudflare'),
          Text(confirmed == null ? '—' : formatBytes(confirmed * 1e9)),
          _label('Custo estimado'),
          Text(
            '${formatUsd(_n(d['estimatedCostUsd']))} '
            '(≈ ${formatBrl(_n(d['estimatedCostBrl']))}, câmbio estimado '
            '${formatBrl(_n(config['brlPerUsd']))}; tarifa '
            '${formatUsd(_n(config['usdPerGb']))}/GB acima da franquia)',
          ),
          _label('Faturado'),
          Text(billed == null ? '—' : formatBrl(billed)),
          _label('Transmissões ao vivo'),
          if (rooms.isEmpty) const Text('Nenhuma agora.'),
          for (final r in rooms) ...[
            Text(
              'Sala ${formatRoomCode(r['code'] as String)}: '
              '${formatBytes(_n(r['egressBytes']))} enviados aos espectadores '
              '(transmissor mandou ${formatBytes(_n(r['publisherSentBytes']))})',
            ),
            for (final (i, v) in (r['viewers'] as List).indexed)
              Text(
                '   Espectador ${i + 1}: '
                '${formatBytes(_n((v as Map)['receivedBytes']))}',
              ),
          ],
          _label('Histórico'),
          if (history.isEmpty) const Text('Nenhuma transmissão encerrada.'),
          for (final h in history)
            Text(
              '${formatRoomCode(h['code'] as String)}: '
              '${((_n(h['endedAt']) - _n(h['startedAt'])) / 60000).round()} min, '
              '${h['reason']}, ${formatBytes(_n(h['egressBytes']))}',
            ),
          const SizedBox(height: 16),
          Text(
            d['notice'] as String? ?? '',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
