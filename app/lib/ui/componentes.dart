import 'package:flutter/material.dart';

import 'tema.dart';

/// Peças comuns das telas, no visual do Stitch (docs/design/).

/// Conteúdo da tela: largura máxima, centralizado e rolável.
class CorpoTela extends StatelessWidget {
  const CorpoTela({
    super.key,
    required this.child,
    this.larguraMaxima = 960,
    this.centralizar = false,
  });

  final Widget child;
  final double larguraMaxima;

  /// No meio da janela (formulários curtos); senão, no topo.
  final bool centralizar;

  @override
  Widget build(BuildContext context) => Align(
    alignment: centralizar ? Alignment.center : Alignment.topCenter,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: larguraMaxima),
        child: child,
      ),
    ),
  );
}

/// Cartão com título (e ícone) em cima, uma linha e o conteúdo embaixo.
class Painel extends StatelessWidget {
  const Painel({
    super.key,
    required this.titulo,
    required this.child,
    this.icone,
    this.acao,
  });

  final String titulo;
  final Widget child;
  final IconData? icone;

  /// À direita do título (ex.: um selo).
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icone != null) ...[
                  Icon(icone, color: c.primary, size: 20),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?acao,
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: c.outlineVariant),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Selo pequeno de estado, com um ponto colorido.
class Selo extends StatelessWidget {
  const Selo(this.texto, {super.key, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.12),
      border: Border.all(color: cor.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: cor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Faixa de aviso (âmbar) ou de erro (vermelha) com ícone.
class Faixa extends StatelessWidget {
  const Faixa(this.texto, {super.key, this.erro = false});

  final String texto;
  final bool erro;

  @override
  Widget build(BuildContext context) {
    final cor = erro ? Theme.of(context).colorScheme.error : DenDenCores.aviso;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        border: Border.all(color: cor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            erro ? Icons.error_outline : Icons.warning_amber_rounded,
            color: cor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

/// Dica pequena embaixo de um campo.
class Dica extends StatelessWidget {
  const Dica(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
