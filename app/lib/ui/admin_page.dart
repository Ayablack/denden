import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rooms/worker_api.dart';
import 'capture_control.dart';
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
      _month,
      _confirmedGb,
      _billedBrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 18)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
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
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_notice != null)
            Text(_notice!, style: const TextStyle(color: Colors.green)),
          _title('Emergência'),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _emergency ? null : Colors.red,
            ),
            onPressed: _toggleEmergency,
            child: Text(
              _emergency
                  ? 'Religar transmissões'
                  : 'Desligar todas as transmissões',
            ),
          ),
          _title('Chaves dos amigos'),
          for (final k in _keys)
            Row(
              children: [
                Expanded(
                  child: Text(k.revoked ? '${k.name} (revogada)' : k.name),
                ),
                if (!k.revoked)
                  TextButton(
                    onPressed: () => _revoke(k),
                    child: const Text('Revogar'),
                  ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome do amigo'),
                ),
              ),
              TextButton(
                onPressed: _createKey,
                child: const Text('Criar chave'),
              ),
            ],
          ),
          _title('Limites (o Worker é quem bloqueia)'),
          TextField(
            controller: _budget,
            decoration: const InputDecoration(
              labelText: 'Orçamento do mês (GB)',
            ),
          ),
          TextField(
            controller: _warns,
            decoration: const InputDecoration(labelText: 'Avisos (%)'),
          ),
          TextField(
            controller: _ceiling,
            decoration: const InputDecoration(labelText: 'Teto (%)'),
          ),
          TextField(
            controller: _usdPerGb,
            decoration: const InputDecoration(labelText: r'Tarifa (US$/GB)'),
          ),
          TextField(
            controller: _brlPerUsd,
            decoration: const InputDecoration(labelText: r'Câmbio (R$/US$)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveConfig,
            child: const Text('Salvar limites'),
          ),
          _title('Valores do provedor (do painel/fatura do Cloudflare)'),
          TextField(
            controller: _month,
            decoration: const InputDecoration(labelText: 'Mês (AAAA-MM)'),
          ),
          TextField(
            controller: _confirmedGb,
            decoration: const InputDecoration(
              labelText: 'Confirmado pelo Cloudflare (GB)',
            ),
          ),
          TextField(
            controller: _billedBrl,
            decoration: const InputDecoration(labelText: r'Faturado (R$)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveConfirmed,
            child: const Text('Salvar valores do provedor'),
          ),
        ],
      ),
    ),
  );
}
