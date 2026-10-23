import 'package:flutter/material.dart';

import '../rooms/settings_store.dart';
import 'capture_control.dart';

/// Primeira vez: endereço do Worker e a chave pessoal do amigo. A chave é
/// testada no Worker antes de ser salva.
class SetupPage extends StatefulWidget {
  const SetupPage({
    super.key,
    required this.initial,
    required this.check,
    required this.save,
    required this.onDone,
  });

  final AppSettings initial;

  /// Confere endereço e chave no Worker (lança o erro do Worker se não der).
  final Future<void> Function(Uri workerUrl, String key) check;
  final Future<void> Function(AppSettings) save;
  final void Function(AppSettings) onDone;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  late final _url = TextEditingController(
    text: widget.initial.workerUrl?.toString() ?? '',
  );
  late final _key = TextEditingController(text: widget.initial.key ?? '');
  late final _admin = TextEditingController(
    text: widget.initial.adminKey ?? '',
  );
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    final url = Uri.tryParse(_url.text.trim());
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      setState(() => _error = 'O endereço precisa começar com https://');
      return;
    }
    final key = _key.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Cole a sua chave.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.check(url, key);
      final admin = _admin.text.trim();
      final s = AppSettings(
        workerUrl: url,
        key: key,
        adminKey: admin.isEmpty ? null : admin,
      );
      await widget.save(s);
      widget.onDone(s);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _admin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DenDen — Configurar')),
    body: Center(
      child: SizedBox(
        width: 460,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Peça ao dono do grupo o endereço do servidor e a sua chave.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Endereço do servidor',
                hintText: 'https://denden-worker.xxx.workers.dev',
              ),
            ),
            TextField(
              controller: _key,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Sua chave'),
            ),
            TextField(
              controller: _admin,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Chave de administrador (só o dono)',
              ),
            ),
            const SizedBox(height: 20),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(onPressed: _save, child: const Text('Salvar')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    ),
  );
}
