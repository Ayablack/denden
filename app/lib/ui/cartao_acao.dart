import 'package:flutter/material.dart';

/// Cartão grande da tela inicial (Transmitir / Assistir). O [destaque] é
/// preenchido com a cor principal; o outro fica no tom de cartão.
class CartaoAcao extends StatelessWidget {
  const CartaoAcao({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.onTap,
    this.destaque = false,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fundo = destaque ? c.primary : c.surfaceContainer;
    final texto = destaque ? c.onPrimary : c.onSurface;
    final fraco = destaque
        ? c.onPrimary.withValues(alpha: 0.75)
        : c.onSurfaceVariant;
    return SizedBox(
      width: 300,
      height: 200,
      child: Material(
        color: fundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: destaque ? c.primary : c.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: destaque
              ? c.secondary.withValues(alpha: 0.5)
              : c.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: destaque
                        ? c.onPrimary.withValues(alpha: 0.08)
                        : c.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icone, color: destaque ? c.onPrimary : c.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  titulo,
                  style: TextStyle(
                    color: texto,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descricao,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fraco, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
