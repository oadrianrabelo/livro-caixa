import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';

/// Página com largura máxima confortável no computador.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.title, this.trailing, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
            children: [
              // Tela estreita: os botões vão para baixo do título, em vez de espremê-lo.
              LayoutBuilder(
                builder: (context, c) {
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.headlineSmall),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!, style: TextStyle(fontSize: 13.5, color: p.pencil)),
                        ),
                    ],
                  );
                  if (trailing == null) return heading;
                  if (c.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        const SizedBox(height: 12),
                        SingleChildScrollView(scrollDirection: Axis.horizontal, child: trailing),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: heading),
                      trailing!,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class MonthPicker extends StatelessWidget {
  const MonthPicker({super.key, required this.month, required this.onChanged});
  final String month;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      LcIconButton(LucideIcons.chevronLeft, tooltip: 'Mês anterior', onPressed: () => onChanged(addMonths(month, -1))),
      SizedBox(
        width: 150,
        child: Text(
          monthLabel(month),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      LcIconButton(LucideIcons.chevronRight, tooltip: 'Próximo mês', onPressed: () => onChanged(addMonths(month, 1))),
    ],
  );
}

/// Cores de dinheiro positivo/negativo do tema.
Color moneyColor(BuildContext context, {required bool positive}) {
  final p = Paper.of(context);
  return positive ? p.greenInk : p.redInk;
}

Future<bool> confirm(BuildContext context, String message) => lcConfirm(context, message);
