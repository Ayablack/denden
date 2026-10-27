import 'package:flutter/material.dart';

/// Cores e componentes do DenDen, do DESIGN.md feito no Stitch
/// (docs/design/). Escuro em camadas: fundo, painel, cartão e controle,
/// separados por bordas finas em vez de sombra. A fonte é a do Windows
/// (Segoe UI): a Inter do Stitch precisaria ir embutida no app.
abstract final class DenDenCores {
  static const fundo = Color(0xFF0B0F17);
  static const painel = Color(0xFF111722);
  static const cartao = Color(0xFF182030);
  static const controle = Color(0xFF222D42);
  static const borda = Color(0xFF1E293B);
  static const bordaForte = Color(0xFF334155);
  static const ciano = Color(0xFF00E5C9);
  static const cianoHover = Color(0xFF00B4D8);
  static const texto = Color(0xFFF1F5F9);
  static const textoFraco = Color(0xFF94A3B8);
  static const desligado = Color(0xFF475569);
  static const aviso = Color(0xFFF59E0B);
  static const erro = Color(0xFFEF4444);
  static const ok = Color(0xFF10B981);
}

const _escuro = ColorScheme(
  brightness: Brightness.dark,
  primary: DenDenCores.ciano,
  onPrimary: DenDenCores.fundo,
  secondary: DenDenCores.cianoHover,
  onSecondary: DenDenCores.fundo,
  tertiary: DenDenCores.aviso,
  onTertiary: DenDenCores.fundo,
  error: DenDenCores.erro,
  onError: DenDenCores.texto,
  surface: DenDenCores.fundo,
  onSurface: DenDenCores.texto,
  onSurfaceVariant: DenDenCores.textoFraco,
  surfaceContainerLowest: DenDenCores.fundo,
  surfaceContainerLow: DenDenCores.painel,
  surfaceContainer: DenDenCores.cartao,
  surfaceContainerHigh: DenDenCores.cartao,
  surfaceContainerHighest: DenDenCores.controle,
  outline: DenDenCores.bordaForte,
  outlineVariant: DenDenCores.borda,
);

/// O claro usa a mesma estrutura, com o ciano escurecido para ter contraste
/// em fundo branco.
const _claro = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF006B5D),
  onPrimary: Colors.white,
  secondary: Color(0xFF00708A),
  onSecondary: Colors.white,
  tertiary: Color(0xFFB45309),
  onTertiary: Colors.white,
  error: Color(0xFFDC2626),
  onError: Colors.white,
  surface: Color(0xFFF8FAFC),
  onSurface: Color(0xFF0F172A),
  onSurfaceVariant: Color(0xFF475569),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF1F5F9),
  surfaceContainer: Colors.white,
  surfaceContainerHigh: Colors.white,
  surfaceContainerHighest: Color(0xFFE2E8F0),
  outline: Color(0xFFCBD5E1),
  outlineVariant: Color(0xFFE2E8F0),
);

ThemeData temaDenDen(Brightness brilho) {
  final c = brilho == Brightness.dark ? _escuro : _claro;
  final cantoBotao = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4),
  );
  OutlineInputBorder borda(Color cor, [double largura = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: cor, width: largura),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: c,
    scaffoldBackgroundColor: c.surface,
    dividerColor: c.outlineVariant,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surfaceContainerLow,
      foregroundColor: c.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 48,
      shape: Border(bottom: BorderSide(color: c.outlineVariant)),
      titleTextStyle: TextStyle(
        color: c.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            shape: cantoBotao,
            minimumSize: const Size(0, 36),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? c.surfaceContainerHighest
                  : s.contains(WidgetState.hovered)
                  ? c.secondary
                  : c.primary,
            ),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: cantoBotao,
        minimumSize: const Size(0, 36),
        foregroundColor: c.onSurface,
        side: BorderSide(color: c.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: cantoBotao,
        foregroundColor: c.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceContainer,
      isDense: true,
      border: borda(c.outlineVariant),
      enabledBorder: borda(c.outlineVariant),
      focusedBorder: borda(c.primary, 1.5),
      hintStyle: TextStyle(color: c.onSurfaceVariant),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surfaceContainer,
    ),
    bannerTheme: MaterialBannerThemeData(
      backgroundColor: c.surfaceContainerLow,
      dividerColor: c.outlineVariant,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.outline),
      ),
    ),
  );
}
