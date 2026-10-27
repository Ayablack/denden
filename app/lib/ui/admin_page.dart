import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rooms/worker_api.dart';
import 'capture_control.dart';
import 'componentes.dart';
import 'tema.dart';
import 'usage_page.dart';

class KeyInfo {
  const KeyInfo({
    required this.name,
    required this.hash,
    required this.revoked,
  });
  final String name;
  final String hash;
  final bool revoked;
}

/// O que a tela de administração pede ao Worker. Toda rota confere a chave
/// de administrador lá: a tela só mostra, quem bloqueia é o Worker.
abstract class AdminPort {
  Future<List<KeyInfo>> listKeys();
  Future<(String key, String hash)> createKey(String name);
  Future<void> revokeKey(String hash);
  Future<void> setEmergency(bool on);
  Future<Map<String, dynamic>> usage();
  Future<void> setConfig(Map<String, Object?> config);
  Future<void> setConfirmed(String month, double? gb, double? brl);
}

class WorkerAdmin implements AdminPort {
  WorkerAdmin(this.api, this.adminKey);

  final WorkerApi api;
  final String adminKey;

  @override
  Future<List<KeyInfo>> listKeys() async {
    final j = await api.adminGet(adminKey, 'chaves');
    return [
      for (final k in (j['keys'] as List))
        KeyInfo(
          name: (k as Map)['name'] as String,
          hash: k['hash'] as String,
          revoked: k['revoked'] == true,
        ),
    ];
  }

  @override
  Future<(String, String)> createKey(String name) async {
    final j = await api.admin(adminKey, 'chaves', {'name': name});
    return (j['key'] as String, j['hash'] as String);
  }

  @override
  Future<void> revokeKey(String hash) =>
      api.admin(adminKey, 'chaves/$hash/revogar');

  @override
  Future<void> setEmergency(bool on) =>
      api.admin(adminKey, 'emergencia', {'on': on});

  @override
  Future<Map<String, dynamic>> usage() => api.adminGet(adminKey, 'consumo');

  @override
  Future<void> setConfig(Map<String, Object?> config) =>
      api.admin(adminKey, 'config', config);

  @override
  Future<void> setConfirmed(String month, double? gb, double? brl) => api.admin(
    adminKey,
    'confirmado',
    {'month': month, 'confirmedGb': ?gb, 'billedBrl': ?brl},
  );
}

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.admin});

  final AdminPort admin;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<KeyInfo> _keys = const [];
  bool _emergency = false;
  String? _error;
  String? _notice;
  final _name = TextEditingController();
  final _budget = TextEditingController();
  final _warns = TextEditingController();
  final _ceiling = TextEditingController();
  final _usdPerGb = TextEditingController();
  final _brlPerUsd = TextEditingController();
  final _maxHours = TextEditingController();
  final _month = TextEditingController(
    text: () {
      final n = DateTime.now().toUtc();
      return '${n.year}-${n.month.toString().padLeft(2, '0')}';
    }(),
  );
  final _confirmedGb = TextEditingController();
  final _billedBrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _do(Future<void> Function() op, {String? done}) async {
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await op();
      if (done != null && mounted) setState(() => _notice = done);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    }
  }

  Future<void> _reload() => _do(() async {
    final keys = await widget.admin.listKeys();
    final u = await widget.admin.usage();
    final c = u['config'] as Map?;
    if (!mounted) return;
    setState(() {
      _keys = keys;
      _emergency = u['emergency'] == true;
      if (c != null && _budget.text.isEmpty) {
        _budget.text = '${c['budgetGb']}';
        _warns.text = (c['warnPercents'] as List).join(', ');
        _ceiling.text = '${c['ceilingPercent']}';
        _usdPerGb.text = '${c['usdPerGb']}';
        _brlPerUsd.text = '${c['brlPerUsd']}';
        if (c['maxSessionHours'] != null) {
          _maxHours.text = '${c['maxSessionHours']}';
        }
      }
    });
  });

  Future<bool> _confirm(String title, String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _toggleEmergency() async {
    final on = !_emergency;
    if (on &&
        !await _confirm(
          'Emergência',
          'Tem certeza? Isto encerra todas as salas agora e recusa novas '
              'transmissões até você religar.',
          'Desligar',
        )) {
      return;
    }
    await _do(() => widget.admin.setEmergency(on));
    await _reload();
  }

  Future<void> _createKey() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await _do(() async {
      final (key, _) = await widget.admin.createKey(name);
      _name.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Chave de $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(key),
              const SizedBox(height: 8),
              const Text(
                'Esta chave aparece uma vez só. Mande por mensagem privada só '
                'para essa pessoa.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: key)),
              child: const Text('Copiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    });
    await _reload();
  }

  Future<void> _revoke(KeyInfo k) async {
    if (!await _confirm(
      'Revogar chave',
      '${k.name} não vai mais conseguir transmitir nem assistir.',
      'Revogar',
    )) {
      return;
    }
    await _do(() => widget.admin.revokeKey(k.hash));
    await _reload();
  }

  Future<void> _saveConfig() => _do(() {
    final warns = [
      for (final p in _warns.text.split(RegExp(r'[,;\s]+')))
        if (p.isNotEmpty) double.tryParse(p),
    ];
    final config = <String, Object?>{
      'budgetGb': ?_num(_budget.text),
      if (_warns.text.trim().isNotEmpty) 'warnPercents': warns,
      'ceilingPercent': ?_num(_ceiling.text),
      'usdPerGb': ?_num(_usdPerGb.text),
      'brlPerUsd': ?_num(_brlPerUsd.text),
      'maxSessionHours': ?_num(_maxHours.text),
    };
    return widget.admin.setConfig(config);
  }, done: 'Limites salvos.');

  Future<void> _saveConfirmed() => _do(
    () => widget.admin.setConfirmed(
      _month.text.trim(),
      _num(_confirmedGb.text),
      _num(_billedBrl.text),
    ),
    done: 'Valores do provedor salvos.',
  );

  @override
  void dispose() {
    for (final c in [
      _name,
      _budget,
      _warns,
      _ceiling,
      _usdPerGb,
      _brlPerUsd,
      _maxHours,
      _month,
      _confirmedGb,
      _billedBrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _campo(TextEditingController c, String rotulo) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      decoration: InputDecoration(labelText: rotulo),
    ),
  );

  Widget _chaves(ColorScheme c) => Painel(
    titulo: 'Chaves dos amigos',
    icone: Icons.vpn_key_outlined,
    acao: Selo(
      '${_keys.where((k) => !k.revoked).length} ativas',
      cor: c.onSurfaceVariant,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome do amigo'),
                onSubmitted: (_) => _createKey(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _createKey,
              child: const Text('Criar chave'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Dica('Cada amigo tem a própria chave. Revogar tira o acesso.'),
        const SizedBox(height: 16),
        if (_keys.isEmpty) const Dica('Nenhuma chave criada ainda.'),
        for (final k in _keys)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.outlineVariant)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: k.revoked ? c.onSurfaceVariant : c.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    k.revoked ? '${k.name} (revogada)' : k.name,
                    style: TextStyle(
                      color: k.revoked ? c.onSurfaceVariant : c.onSurface,
                    ),
                  ),
                ),
                if (!k.revoked)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.error,
                      side: BorderSide(color: c.error.withValues(alpha: 0.6)),
                    ),
                    onPressed: () => _revoke(k),
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Revogar'),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _limites() => Painel(
    titulo: 'Limites',
    icone: Icons.speed,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Dica(
          'Quem bloqueia é o servidor: estes valores valem para todos.',
        ),
        const SizedBox(height: 14),
        _campo(_budget, 'Orçamento do mês (GB)'),
        _campo(_warns, 'Avisos (%)'),
        _campo(_ceiling, 'Teto (%)'),
        _campo(_maxHours, 'Duração máxima (h)'),
        _campo(_usdPerGb, r'Tarifa (US$/GB)'),
        _campo(_brlPerUsd, r'Câmbio (R$/US$)'),
        FilledButton(
          onPressed: _saveConfig,
          child: const Text('Salvar limites'),
        ),
      ],
    ),
  );

  Widget _provedor() => Painel(
    titulo: 'Valores do provedor',
    icone: Icons.receipt_long_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Dica('Copie do painel ou da fatura do Cloudflare.'),
        const SizedBox(height: 14),
        _campo(_month, 'Mês (AAAA-MM)'),
        _campo(_confirmedGb, 'Confirmado pelo Cloudflare (GB)'),
        _campo(_billedBrl, r'Faturado (R$)'),
        OutlinedButton(
          onPressed: _saveConfirmed,
          child: const Text('Salvar valores do provedor'),
        ),
      ],
    ),
  );

  Widget _emergencia(ColorScheme c) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: c.error.withValues(alpha: 0.6)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: c.error),
              const SizedBox(width: 10),
              Text(
                'Emergência',
                style: TextStyle(
                  color: c.error,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Dica(
            _emergency
                ? 'Todas as transmissões estão desligadas.'
                : 'Encerra todas as salas na hora e recusa novas transmissões '
                      'até você religar.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _emergency ? null : c.error,
              foregroundColor: _emergency ? null : Colors.white,
            ),
            onPressed: _toggleEmergency,
            child: Text(
              _emergency
                  ? 'Religar transmissões'
                  : 'Desligar todas as transmissões',
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administração'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UsagePage(load: widget.admin.usage),
              ),
            ),
            child: const Text('Ver consumo'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CorpoTela(
        larguraMaxima: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Faixa(_error!, erro: true),
              const SizedBox(height: 12),
            ],
            if (_notice != null) ...[
              Selo(_notice!, cor: DenDenCores.ok),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, box) {
                final lado = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _limites(),
                    const SizedBox(height: 16),
                    _provedor(),
                    const SizedBox(height: 16),
                    _emergencia(c),
                  ],
                );
                if (box.maxWidth < 860) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [_chaves(c), const SizedBox(height: 16), lado],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _chaves(c)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: lado),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
