// Relatório do mercado: idas no mês, o que mais se compra, preços que
// subiram e uma lista de compras montada pelo histórico.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../domain/shopping.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';

Future<void> showShoppingReport(BuildContext context) =>
    showLcSheet<void>(context, maxWidth: 640, builder: (_) => const _ShoppingReport());

class _ShoppingReport extends StatefulWidget {
  const _ShoppingReport();

  @override
  State<_ShoppingReport> createState() => _ShoppingReportState();
}

class _ShoppingReportState extends State<_ShoppingReport> {
  Set<String>? _picked; // chaves (nome normalizado) marcadas para a lista
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final data = scope.data;
    final p = Paper.of(context);
    final now = DateTime.now();
    final stats = data.memo(#productStats, () => productStats(data.shopItems, data.entryIds));
    final suggested = suggestedList(stats, now);
    final month = monthOf(today());
    final thisMonth = monthTrips(data.shopItems, data.entryIds, month);
    final lastMonth = monthTrips(data.shopItems, data.entryIds, addMonths(month, -1));
    // Começa marcando o que "já está na hora" e o que já estava na lista.
    final plan = {for (final n in scope.prefs.shoppingPlan) normalizeItem(n)};
    final picked = _picked ??= {
      for (final s in suggested)
        if (s.dueOn(now) || plan.contains(s.key)) s.key,
    };
    final chosen = [
      for (final s in suggested)
        if (picked.contains(s.key)) s,
    ];
    final estimate = chosen.fold(0, (sum, s) => sum + s.lastPrice);
    final pricier = [
      for (final s in stats)
        if (s.trips >= 2 && s.priceChange >= 0.1) s,
    ];
    final shown = _showAll ? stats : stats.take(12).toList();

    Widget stat(String label, String value, {String? hint}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: p.pencil)),
        Text(value, style: p.mono(18, weight: FontWeight.w700)),
        if (hint != null) Text(hint, style: TextStyle(fontSize: 11.5, color: p.pencil)),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mercado',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          Text(
            'Montado com o que vocês anotam na calculadora de compras.',
            style: TextStyle(fontSize: 12.5, color: p.pencil),
          ),
          const SizedBox(height: 14),
          if (stats.isEmpty)
            LcGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Ainda não há compras anotadas. No mercado, use a calculadora (com o nome dos itens) e '
                    'lance a compra no fim: aqui aparecem o que mais compram, os preços e uma lista pronta.',
                    style: TextStyle(fontSize: 13.5, color: p.ink, height: 1.4),
                  ),
                ),
              ],
            )
          else ...[
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                stat(
                  'Idas neste mês',
                  '${thisMonth.trips}',
                  hint: lastMonth.trips > 0 ? 'mês passado: ${lastMonth.trips}' : null,
                ),
                stat(
                  'Gasto no mercado',
                  formatBRL(thisMonth.total),
                  hint: lastMonth.total > 0 ? 'mês passado: ${formatBRL(lastMonth.total)}' : null,
                ),
                if (thisMonth.trips > 0) stat('Por ida', formatBRL((thisMonth.total / thisMonth.trips).round())),
              ],
            ),
            const SizedBox(height: 18),
            LcGroup(
              title: 'MONTAR A LISTA',
              description: suggested.isEmpty
                  ? 'Depois de duas idas com os mesmos itens, a lista aparece aqui.'
                  : 'Marcados: o que já está na hora de comprar de novo (pelo intervalo de costume). '
                        'Estimativa pelo último preço: ${formatBRL(estimate)}.',
              children: [
                for (final s in suggested.take(30))
                  LcRow(
                    title: s.name,
                    subtitle: [
                      'último ${formatBRL(s.lastPrice)}',
                      if (s.everyDays != null) 'a cada ~${s.everyDays!.round()} dias',
                      if (s.dueOn(now)) 'na hora',
                    ].join(' · '),
                    leading: Icon(
                      picked.contains(s.key) ? LucideIcons.squareCheck : LucideIcons.square,
                      size: 18,
                      color: picked.contains(s.key) ? p.accent : p.pencil,
                    ),
                    trailing: const SizedBox.shrink(),
                    onTap: () => setState(() => picked.contains(s.key) ? picked.remove(s.key) : picked.add(s.key)),
                  ),
                if (suggested.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        LcButton(
                          'Copiar lista',
                          icon: LucideIcons.copy,
                          kind: LcButtonKind.secondary,
                          small: true,
                          onPressed: chosen.isEmpty
                              ? null
                              : () async {
                                  final text = ['Lista de compras', for (final s in chosen) '- ${s.name}'].join('\n');
                                  await Clipboard.setData(ClipboardData(text: text));
                                  if (context.mounted) lcToast(context, 'Lista copiada. Cole no WhatsApp.');
                                },
                        ),
                        LcButton(
                          'Usar na calculadora',
                          icon: LucideIcons.listChecks,
                          small: true,
                          onPressed: () async {
                            await scope.prefs.setShoppingPlan([for (final s in chosen) s.name]);
                            if (context.mounted) {
                              lcToast(
                                context,
                                chosen.isEmpty
                                    ? 'Lista da calculadora limpa.'
                                    : '${chosen.length} itens em "Para pegar" na calculadora.',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (pricier.isNotEmpty)
              LcGroup(
                title: 'FICARAM MAIS CAROS',
                description: 'Último preço pelo menos 10% acima da média.',
                children: [
                  for (final s in pricier.take(8))
                    LcRow(
                      title: s.name,
                      subtitle: 'média ${formatBRL(s.avgPrice)} · mais barato ${formatBRL(s.minPrice)}',
                      trailing: Text(
                        '${formatBRL(s.lastPrice)}  +${(s.priceChange * 100).round()}%',
                        style: p.mono(13, color: p.redInk, weight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            LcGroup(
              title: 'MAIS COMPRADOS',
              children: [
                for (final s in shown)
                  LcRow(
                    title: s.name,
                    subtitle:
                        '${s.trips} ${s.trips == 1 ? 'vez' : 'vezes'} · ${s.units} un. · '
                        'última em ${formatDate(s.lastDate).substring(0, 5)}',
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatBRL(s.lastPrice), style: p.mono(13, weight: FontWeight.w600)),
                        if (s.trips >= 2)
                          Text('média ${formatBRL(s.avgPrice)}', style: TextStyle(fontSize: 11, color: p.pencil)),
                      ],
                    ),
                  ),
                if (!_showAll && stats.length > shown.length)
                  LcRow(
                    title: 'Ver todos (${stats.length})',
                    leading: Icon(LucideIcons.chevronDown, size: 16, color: p.pencil),
                    onTap: () => setState(() => _showAll = true),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
