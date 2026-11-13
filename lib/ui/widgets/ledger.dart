// Peças da "folha de caderno": pauta, margem, linhas de item, títulos.
// Tudo tem altura múltipla de [kLine], para o texto cair em cima da pauta.
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../theme/paper.dart';
import '../theme/themes.dart';

const double kLine = 34; // distância entre as linhas da pauta
const double kMarginX = 40; // posição da margem vermelha

/// Folha pautada com margem. A pauta rola junto com o conteúdo.
class LedgerSheet extends StatelessWidget {
  const LedgerSheet({super.key, required this.children, this.minHeight = 0, this.padding = 20});
  final List<Widget> children;
  final double minHeight;
  final double padding; // margem direita

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    // Camada própria: rolar a página só desloca a folha já desenhada.
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.paper,
          borderRadius: BorderRadius.circular(5),
          // Sombra macia + a beirada de duas folhas por baixo: um bloco de
          // papel, e não um retângulo solto.
          boxShadow: [
            const BoxShadow(color: Color(0x24000000), blurRadius: 30, spreadRadius: -8, offset: Offset(0, 16)),
            const BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1)),
            BoxShadow(color: p.ink.withValues(alpha: 0.22), spreadRadius: -4, offset: const Offset(0, 7.6)),
            BoxShadow(color: Color.lerp(p.paper, p.ink, 0.07)!, spreadRadius: -4, offset: const Offset(0, 7)),
            BoxShadow(color: p.ink.withValues(alpha: 0.2), spreadRadius: -2, offset: const Offset(0, 4.1)),
            BoxShadow(color: Color.lerp(p.paper, p.ink, 0.035)!, spreadRadius: -2, offset: const Offset(0, 3.5)),
          ],
        ),
        child: CustomPaint(
          painter: _RulePainter(p),
          // O conteúdo fica numa camada própria: passar o mouse ou marcar ✓ não
          // redesenha a pauta e a textura (isso travava o computador).
          child: RepaintBoundary(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(kMarginX + 10, kLine, padding, kLine),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulePainter extends CustomPainter {
  _RulePainter(this.p);
  final Paper p;

  @override
  void paint(Canvas canvas, Size size) {
    if (p.grain) _paintGrain(canvas, size);
    final rule = Paint()
      ..color = p.rule
      ..strokeWidth = 1;
    switch (p.ruling) {
      case Ruling.pautada:
        for (var y = kLine * 2; y < size.height; y += kLine) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
        }
      case Ruling.quadriculada:
        final grid = Paint()
          ..color = p.rule.withValues(alpha: 0.7)
          ..strokeWidth = 0.8;
        const step = kLine / 2;
        for (var y = kLine * 2; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
        }
        for (var x = 0.0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, kLine * 2), Offset(x, size.height), grid);
        }
      case Ruling.pontilhada:
        // Todas as bolinhas numa chamada só (antes era uma chamada por bolinha).
        const step = kLine / 2;
        canvas.drawPoints(
          PointMode.points,
          [
            for (var y = kLine * 2; y < size.height; y += step)
              for (var x = step; x < size.width; x += step) Offset(x, y),
          ],
          Paint()
            ..color = p.rule
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
      case Ruling.lisa:
        break;
    }
    if (p.showMargin) {
      final margin = Paint()
        ..color = p.margin
        ..strokeWidth = 1.2;
      canvas.drawLine(const Offset(kMarginX, 0), Offset(kMarginX, size.height), margin);
      canvas.drawLine(const Offset(kMarginX + 3, 0), Offset(kMarginX + 3, size.height), margin);
    }
  }

  /// Textura leve de papel: pontinhos fixos (gerados uma vez só) desenhados
  /// numa única chamada.
  static final List<Offset> _grain = () {
    final rnd = math.Random(7);
    return [for (var i = 0; i < 1800; i++) Offset(rnd.nextDouble(), rnd.nextDouble())];
  }();

  void _paintGrain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = p.ink.withValues(alpha: p.dark ? 0.05 : 0.035)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    // A textura se repete a cada 600 px, então não cresce com o tamanho da folha.
    const tile = 600.0;
    final pts = <Offset>[];
    for (var ty = 0.0; ty < size.height; ty += tile) {
      for (var tx = 0.0; tx < size.width; tx += tile) {
        for (final o in _grain) {
          final x = tx + o.dx * tile, y = ty + o.dy * tile;
          if (x < size.width && y < size.height) pts.add(Offset(x, y));
        }
      }
    }
    canvas.drawPoints(PointMode.points, pts, paint);
  }

  @override
  bool shouldRepaint(_RulePainter old) =>
      old.p.ruling != p.ruling ||
      old.p.grain != p.grain ||
      old.p.showMargin != p.showMargin ||
      old.p.rule != p.rule ||
      old.p.margin != p.margin ||
      old.p.ink != p.ink ||
      old.p.dark != p.dark;
}

/// Argolas de fichário entre as duas páginas do livro aberto.
class BinderRings extends StatelessWidget {
  const BinderRings({super.key, required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return RepaintBoundary(
      child: SizedBox(
        width: 22,
        height: height,
        child: CustomPaint(painter: _RingsPainter(p)),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.p);
  final Paper p;

  @override
  void paint(Canvas canvas, Size size) {
    final metal = Paint()
      ..shader = LinearGradient(
        colors: p.dark
            ? const [Color(0xFF5C5C62), Color(0xFFB9B9C0), Color(0xFF4A4A50)]
            : const [Color(0xFF9A9AA2), Color(0xFFF1F1F4), Color(0xFF8A8A92)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 10))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final hole = Paint()..color = Colors.black.withValues(alpha: p.dark ? 0.5 : 0.22);
    for (var y = 70.0; y < size.height - 40; y += 120) {
      canvas.drawCircle(Offset(3, y), 3.2, hole);
      canvas.drawCircle(Offset(size.width - 3, y), 3.2, hole);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(size.width / 2, y), width: size.width + 2, height: 14),
        3.3,
        2.8,
        false,
        metal,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.p.dark != p.dark;
}

/// Título de seção sublinhado ("Cartão", "Casa"...). Ocupa 2 linhas.
class LedgerHeading extends StatelessWidget {
  const LedgerHeading(this.text, {super.key, this.trailing, this.big = false});
  final String text;
  final Widget? trailing;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return SizedBox(
      height: kLine * 2,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                text,
                style: p
                    .hand(big ? 40 : 28, color: big ? p.redInk : p.ink, weight: FontWeight.w600)
                    .copyWith(decoration: big ? null : TextDecoration.underline, decorationColor: p.ink),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Uma linha do caderno: [✓] descrição ........ valor
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.label,
    this.value,
    this.sign = '',
    this.checked,
    this.onCheck,
    this.onTap,
    this.color,
    this.bold = false,
    this.note,
    this.noteColor,
  });

  final String label;
  final int? value; // centavos
  final String sign; // '−', '+' ou ''
  final bool? checked; // null = sem caixinha
  final VoidCallback? onCheck;
  final VoidCallback? onTap;
  final Color? color;
  final bool bold;
  final String? note; // texto pequeno a lápis depois do rótulo
  final Color? noteColor; // ex.: vermelho para conta atrasada

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final c = color ?? p.ink;
    // Os pontinhos ficam atrás, na largura toda; o texto e o valor têm fundo
    // de papel e "apagam" os pontinhos embaixo deles. Assim o valor fica
    // sempre encostado à direita, como numa coluna de caderno.
    final valueStyle = p.mono(15, color: c, weight: bold ? FontWeight.w700 : FontWeight.w500);
    final valueText = value == null
        ? null
        : bold
        // Totais (Disponível, Sobrou): o número "corre" até o valor novo.
        ? TweenAnimationBuilder<double>(
            tween: Tween(end: value!.toDouble()),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text('$sign${formatBRL(v.round())}', style: valueStyle),
          )
        : Text('$sign${formatBRL(value!)}', style: valueStyle);
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: kLine,
          child: Stack(
            children: [
              if (value != null) Positioned(left: 0, right: 0, bottom: 7, height: 3, child: _Dots(color: p.rule)),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: ColoredBox(
                        color: p.paper,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (checked != null)
                                SizedBox(
                                  width: 30,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onCheck == null
                                        ? null
                                        : () {
                                            HapticFeedback.lightImpact();
                                            onCheck!();
                                          },
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: _Check(checked: checked!, ink: p.redInk, pencil: p.pencil),
                                    ),
                                  ),
                                ),
                              // Rótulo + anotação a lápis num texto só: se faltar espaço,
                              // corta a anotação primeiro, e o rótulo fica inteiro.
                              Flexible(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: label,
                                        style: p.hand(23, color: c, weight: bold ? FontWeight.w700 : null),
                                      ),
                                      if (note != null && note!.isNotEmpty)
                                        TextSpan(
                                          text: '  $note',
                                          style: p.hand(17, color: noteColor ?? p.pencil),
                                        ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (valueText != null)
                      ColoredBox(
                        color: p.paper,
                        child: Padding(padding: const EdgeInsets.only(left: 6), child: valueText),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A caixinha da linha: um círculo a lápis; ao marcar, o ✓ é riscado à caneta.
class _Check extends StatelessWidget {
  const _Check({required this.checked, required this.ink, required this.pencil});
  final bool checked;
  final Color ink, pencil;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: checked ? 1 : 0),
    duration: Duration(milliseconds: checked ? 260 : 140),
    curve: Curves.easeOutCubic,
    builder: (context, t, _) => CustomPaint(size: const Size(24, 24), painter: _CheckPainter(t, ink, pencil)),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.ink, this.pencil);
  final double t;
  final Color ink, pencil;

  // Um ✓ com cara de feito à mão (um pouco torto, perna longa).
  static final Path _mark = Path()
    ..moveTo(3, 13)
    ..quadraticBezierTo(6.5, 15, 9, 20.5)
    ..quadraticBezierTo(13, 10, 22.5, 2.5);

  @override
  void paint(Canvas canvas, Size size) {
    if (t < 1) {
      canvas.drawCircle(
        const Offset(8, 15),
        5.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = pencil.withValues(alpha: pencil.a * (1 - t)),
      );
    }
    if (t > 0) {
      final m = _mark.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.ink != ink || old.pencil != pencil;
}

/// Pontinhos ligando a descrição ao valor.
class _Dots extends StatelessWidget {
  const _Dots({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(height: 8, child: CustomPaint(painter: _DotsPainter(color)));
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawCircle(Offset(x, size.height / 2), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// Linha vazia da pauta (espaçador).
class LedgerGap extends StatelessWidget {
  const LedgerGap({super.key, this.lines = 1});
  final int lines;

  @override
  Widget build(BuildContext context) => SizedBox(height: kLine * lines);
}

/// Bilhete tipo post-it, para lembretes. Ocupa 3 linhas.
class StickyNote extends StatelessWidget {
  const StickyNote({super.key, required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return SizedBox(
      height: kLine * 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        // Só o papel fica torto; o texto continua reto (girar o texto deixava borrado).
        child: Stack(
          children: [
            Positioned.fill(
              child: Transform.rotate(
                angle: -0.008,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.sticky,
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(1, 2))],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(text, style: p.hand(21), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    ?action,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
