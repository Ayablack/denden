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
    final c = Theme.of(context).colorScheme;
    final pequeno = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            widget.versao == 'dev'
                ? 'Versão de desenvolvimento'
                : 'Versão ${widget.versao}',
            style: pequeno,
          ),
          const SizedBox(width: 16),
          // Janela estreita: os textos encurtam com "…" em vez de estourar.
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_erro != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        _erro!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.error),
                      ),
                    ),
                  ),
                if (n != null && p == null) ...[
                  Flexible(
                    child: Text(
                      'Versão ${n.versao} disponível',
                      overflow: TextOverflow.ellipsis,
                      style: pequeno,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _atualizar(n),
                    child: const Text('Atualizar'),
                  ),
                ] else if (p != null) ...[
                  Flexible(
                    child: Text(
                      'Baixando… o DenDen vai fechar e abrir de novo.',
                      overflow: TextOverflow.ellipsis,
                      style: pequeno,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: LinearProgressIndicator(value: p),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
