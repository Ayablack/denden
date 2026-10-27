import 'package:flutter/material.dart';

import '../rooms/settings_store.dart';
import 'capture_control.dart';
import 'componentes.dart';

/// Primeira vez: endereço do Worker e a chave pessoal do amigo. A chave é
/// testada no Worker antes de ser salva.
class SetupPage extends StatefulWidget {
  const SetupPage({
    super.key,
    required this.initial,
    required this.check,
    required this.save,
    required this.onDone,
    this.onCancel,
  });

  /// Voltar sem salvar. Nulo na primeira configuração, quando não há para
  /// onde voltar.
  final VoidCallback? onCancel;

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
  bool _showKey = false;
  bool _showAdmin = false;

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

  /// Olho para conferir a chave colada: escondida por padrão.
  Widget _visibilityToggle(bool visible, VoidCallback toggle) => IconButton(
    tooltip: visible ? 'Esconder' : 'Mostrar',
    icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
    onPressed: toggle,
  );

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _admin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('DenDen — Configurar'),
      leading: widget.onCancel == null
          ? null
          : IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onCancel,
            ),
    ),
    body: CorpoTela(
      larguraMaxima: 560,
      centralizar: true,
      child: Painel(
        titulo: 'Conexão com o servidor',
        icone: Icons.dns_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Dica(
              'Peça ao dono do grupo o endereço do servidor e a sua chave.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              // O hintText some quando o campo perde o foco; o helperText
              // fica sempre visível.
              decoration: const InputDecoration(
                labelText: 'Endereço do servidor',
                helperText: 'Ex.: https://denden-worker.xxx.workers.dev',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _key,
              obscureText: !_showKey,
              decoration: InputDecoration(
                labelText: 'Sua chave',
                helperText: 'Chave pessoal que o dono do grupo te mandou.',
                suffixIcon: _visibilityToggle(
                  _showKey,
                  () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _admin,
              obscureText: !_showAdmin,
              decoration: InputDecoration(
                labelText: 'Chave de administrador (só o dono)',
                helperText: 'Deixe em branco se você não é o dono do grupo.',
                suffixIcon: _visibilityToggle(
                  _showAdmin,
                  () => setState(() => _showAdmin = !_showAdmin),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Faixa(_error!, erro: true),
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: _busy
                  ? const CircularProgressIndicator()
                  : FilledButton(onPressed: _save, child: const Text('Salvar')),
            ),
          ],
        ),
      ),
    ),
  );
}
