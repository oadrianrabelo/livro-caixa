import 'package:flutter/material.dart';

import 'fonts.dart';
import 'themes.dart';

/// Tudo que define a aparência do caderno. Pegue com `Paper.of(context)`.
@immutable
class Paper extends ThemeExtension<Paper> {
  const Paper({
    required this.paper,
    required this.paperShade,
    required this.rule,
    required this.margin,
    required this.ink,
    required this.redInk,
    required this.pencil,
    required this.greenInk,
    required this.sticky,
    required this.accent,
    required this.handFont,
    required this.monoFont,
    required this.uiFont,
    required this.ruling,
    required this.showMargin,
    required this.grain,
    required this.dark,
  });

  final Color paper; // fundo da folha
  final Color paperShade; // folha de trás, barra lateral
  final Color rule; // linhas da pauta
  final Color margin; // linha da margem
  final Color ink; // caneta principal
  final Color redInk; // caneta vermelha: títulos, totais, ✓
  final Color pencil; // lápis: textos secundários
  final Color greenInk; // valores positivos
  final Color sticky; // post-it
  final Color accent; // foco, interruptores, destaques
  final String handFont, monoFont, uiFont;
  final Ruling ruling;
  final bool showMargin, grain, dark;

  static Paper of(BuildContext context) => Theme.of(context).extension<Paper>()!;

  factory Paper.from(
    PaperSpec s, {
    required String ink,
    required String hand,
    required String mono,
    required String ui,
    required Ruling ruling,
    required bool showMargin,
    required bool grain,
  }) {
    final option = inkOptions.firstWhere((o) => o.id == ink, orElse: () => inkOptions.first);
    final inkColor = (s.dark ? option.dark : option.light) ?? s.ink;
    return Paper(
      paper: s.paper,
      paperShade: s.paperShade,
      rule: s.rule,
      margin: s.margin,
      ink: inkColor,
      redInk: s.redInk,
      pencil: s.pencil,
      greenInk: s.greenInk,
      sticky: s.sticky,
      accent: s.accent,
      handFont: hand,
      monoFont: mono,
      uiFont: ui,
      ruling: ruling,
      showMargin: showMargin,
      grain: grain,
      dark: s.dark,
    );
  }

  /// Letra de mão (títulos, itens do caderno).
  TextStyle hand(double size, {Color? color, FontWeight? weight}) => TextStyle(
    fontFamily: handFont,
    fontSize: size * handScale(handFont),
    color: color ?? ink,
    fontWeight: weight,
    height: 1.1,
  );

  /// Números (valores alinhados).
  TextStyle mono(double size, {Color? color, FontWeight? weight}) => TextStyle(
    fontFamily: monoFont,
    // Letra de mão nos números: um pouco maior, para ficar do tamanho das de máquina.
    fontSize: handFonts.contains(monoFont) ? size * handScale(monoFont) * 1.2 : size,
    color: color ?? ink,
    fontWeight: weight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  @override
  Paper copyWith({String? handFont, String? monoFont, String? uiFont}) => Paper(
    paper: paper,
    paperShade: paperShade,
    rule: rule,
    margin: margin,
    ink: ink,
    redInk: redInk,
    pencil: pencil,
    greenInk: greenInk,
    sticky: sticky,
    accent: accent,
    handFont: handFont ?? this.handFont,
    monoFont: monoFont ?? this.monoFont,
    uiFont: uiFont ?? this.uiFont,
    ruling: ruling,
    showMargin: showMargin,
    grain: grain,
    dark: dark,
  );

  @override
  Paper lerp(Paper? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    final o = t < 0.5 ? this : other;
    return Paper(
      paper: c(paper, other.paper),
      paperShade: c(paperShade, other.paperShade),
      rule: c(rule, other.rule),
      margin: c(margin, other.margin),
      ink: c(ink, other.ink),
      redInk: c(redInk, other.redInk),
      pencil: c(pencil, other.pencil),
      greenInk: c(greenInk, other.greenInk),
      sticky: c(sticky, other.sticky),
      accent: c(accent, other.accent),
      handFont: o.handFont,
      monoFont: o.monoFont,
      uiFont: o.uiFont,
      ruling: o.ruling,
      showMargin: o.showMargin,
      grain: o.grain,
      dark: o.dark,
    );
  }
}

/// Linha fina usada em bordas e divisórias.
Color hairline(Paper p) => p.ink.withValues(alpha: p.dark ? 0.14 : 0.12);

ThemeData paperTheme(Paper p) {
  final brightness = p.dark ? Brightness.dark : Brightness.light;
  final line = hairline(p);
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: brightness).copyWith(
    primary: p.ink,
    onPrimary: p.paper,
    secondary: p.accent,
    surface: p.paper,
    onSurface: p.ink,
    onSurfaceVariant: p.pencil,
    outline: line,
    outlineVariant: line,
    surfaceTint: Colors.transparent,
    error: p.redInk,
  );
  final base = (p.dark ? Typography.material2021().white : Typography.material2021().black).apply(
    fontFamily: p.uiFont,
    bodyColor: p.ink,
    displayColor: p.ink,
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: p.uiFont,
    textTheme: base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      titleMedium: base.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
    ),
    scaffoldBackgroundColor: p.paperShade,
    canvasColor: p.paper,
    extensions: [p],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: p.ink.withValues(alpha: 0.05),
    focusColor: p.accent.withValues(alpha: 0.18),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.25),
      selectionHandleColor: p.accent,
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(6)),
      textStyle: TextStyle(fontFamily: p.uiFont, fontSize: 12, color: p.paper),
      waitDuration: const Duration(milliseconds: 400),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent, linearTrackColor: line),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final t in TargetPlatform.values) t: const FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

/// Rolagem com "elástico" (como no Mac/iOS), sem o brilho do Android.
class SoftScrollBehavior extends MaterialScrollBehavior {
  const SoftScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
