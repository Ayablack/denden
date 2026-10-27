import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../atualizacao/atualizacao.dart';

/// Rodapé da tela inicial: a versão instalada e, se houver uma mais nova
/// no GitHub, o botão Atualizar. Só existe na tela inicial, então nunca
/// aparece no meio de uma transmissão.
class AvisoAtualizacao extends StatefulWidget {
  const AvisoAtualizacao({
    super.key,
    this.versao = versaoAtual,
    this.conferir,
    this.instalar,
  });

  final String versao;

  /// Só para testes; sem ele, pergunta ao GitHub.
  final Future<NovaVersao?> Function()? conferir;
  final Future<void> Function(NovaVersao, void Function(double))? instalar;

  @override
  State<AvisoAtualizacao> createState() => _AvisoAtualizacaoState();
}

class _AvisoAtualizacaoState extends State<AvisoAtualizacao> {
  NovaVersao? _nova;
  double? _progresso;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final conferir =
        widget.conferir ??
        () => conferirAtualizacao(http.Client(), atual: widget.versao);
    conferir().then((n) {
      if (mounted) setState(() => _nova = n);
    });
  }

  Future<void> _atualizar(NovaVersao n) async {
    setState(() {
      _progresso = 0;
      _erro = null;
    });
    final instalar =
        widget.instalar ?? (n, p) => instalarAtualizacao(n, progresso: p);
    try {
      await instalar(n, (p) {
        if (mounted) setState(() => _progresso = p);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _progresso = null;
          _erro = 'Não deu para atualizar. Tente de novo mais tarde.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _nova;
    final p = _progresso;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (n != null) ...[
            Text('Versão ${n.versao} disponível'),
            const SizedBox(height: 8),
            if (p == null)
              FilledButton(
                onPressed: () => _atualizar(n),
                child: const Text('Atualizar'),
              )
            else ...[
              SizedBox(width: 240, child: LinearProgressIndicator(value: p)),
              const SizedBox(height: 4),
              const Text('Baixando… o DenDen vai fechar e abrir de novo.'),
            ],
            if (_erro != null)
              Text(_erro!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          Text(
            widget.versao == 'dev'
                ? 'Versão de desenvolvimento'
                : 'Versão ${widget.versao}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
