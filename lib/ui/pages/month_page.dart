import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../domain/tithe.dart';
import '../../domain/vale.dart';
import '../kit/kit.dart';
import '../nav.dart';
import '../theme/paper.dart';
import '../widgets/entry_form.dart';
import '../widgets/shopping_calc.dart';
import '../widgets/wallet_sheets.dart';
import '../widgets/ledger.dart';
import '../widgets/tithe_dialog.dart';

const _sectionNames = {
  CategorySection.cartao: 'Cartão',
  CategorySection.casa: 'Casa',
  CategorySection.pessoal: 'Pessoal',
  CategorySection.outros: 'Outros',
};

/// A página do mês, como no caderno. Arraste para o lado para virar a página.
class MonthPage extends StatefulWidget {
  const MonthPage({super.key});

  @override
  State<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<MonthPage> {
  static const _origin = 600; // página do mês atual
  final _thisMonth = monthOf(today());
  final _controller = PageController(initialPage: _origin);
  late String _month = _thisMonth;

  String _monthAt(int index) => addMonths(_thisMonth, index - _origin);

  void _go(int delta) => _controller.animateToPage(
    (_controller.page?.round() ?? _origin) + delta,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  void _today() =>
      _controller.animateToPage(_origin, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    monthNav.attach(go: _go, today: _today);
  }

  @override
  void dispose() {
    monthNav.detach();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    Widget arrow(IconData icon, String tip, VoidCallback onTap) => LcIconButton(icon, tooltip: tip, onPressed: onTap);
    return Scaffold(
      // O teclado abre por cima, no formulário; a página de trás não precisa se refazer a cada quadro.
      resizeToAvoidBottomInset: false,
      backgroundColor: p.paperShade,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Row(
              children: [
                arrow(LucideIcons.chevronLeft, 'Mês anterior (←)', () => _go(-1)),
                arrow(LucideIcons.chevronRight, 'Próximo mês (→)', () => _go(1)),
                const SizedBox(width: 6),
                Text(
                  monthLabel(_month),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                ),
                const SizedBox(width: 8),
                AnimatedOpacity(
                  opacity: _month != _thisMonth ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: LcButton(
                    'Hoje',
                    small: true,
                    kind: LcButtonKind.secondary,
                    onPressed: _month != _thisMonth ? _today : null,
                  ),
                ),
                const Spacer(),
                if (monthNav.openPalette != null)
                  arrow(LucideIcons.search, 'Buscar ou executar', () => monthNav.openPalette!()),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) {
                setState(() => _month = _monthAt(i));
                monthNav.changed(_month);
                // Contas fixas: lança o mês ao abrir (até o mês que vem, para planejar).
                if (_month.compareTo(addMonths(_thisMonth, 1)) <= 0) {
                  AppScope.of(context).db.ensureRecurringEntries(_month);
                }
              },
              itemBuilder: (context, i) => _MonthSheet(month: _monthAt(i)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vale-alimentação: quanto resta até renovar. Fica fora do Disponível e do Sobrou.
List<Widget> _valeBlock(BuildContext context, MonthSummary s) {
  final scope = AppScope.of(context);
  final p = Paper.of(context);
  final data = scope.data;
  final vales = data.accounts.where((a) => a.type == AccountType.vale && !a.archived).toList();
  if (vales.isEmpty) return const [];
  final now = DateTime.now();
  return [
    LedgerHeading(
      'Vale',
      trailing: Text('fora do disponível', style: p.hand(17, color: p.pencil)),
    ),
    for (final v in vales)
      Builder(
        builder: (context) {
          final st = valeStatus(v, data.entries, now);
          final days = st.daysUntilRenewal(now);
          return StickyNote(
            action: GestureDetector(
              onTap: () => showShoppingCalc(context),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    'Calcular\ncompras',
                    textAlign: TextAlign.end,
                    style: p
                        .hand(19, color: p.redInk, weight: FontWeight.w700)
                        .copyWith(decoration: TextDecoration.underline, decorationColor: p.redInk, height: 1.1),
                  ),
                ),
              ),
            ),
            text:
                '${v.name}: restam ${formatBRL(st.left)}\n'
                'renova dia ${v.renewDay} (${days == 0
                    ? 'hoje'
                    : days == 1
                    ? 'amanhã'
                    : 'em $days dias'})',
          );
        },
      ),
    for (final e in s.vale)
      LedgerRow(
        label: data.labelOf(e),
        value: e.amount,
        color: p.pencil,
        checked: e.paid,
        onCheck: () => scope.db.setPaid(e.id, !e.paid),
        onTap: () => showEntryForm(context, editing: e),
      ),
  ];
}

String _defaultDate(String month) => month == monthOf(today()) ? today() : '$month-01';

class _MonthSheet extends StatelessWidget {
  const _MonthSheet({required this.month});
  final String month;

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final s = monthSummary(
          data.entries,
          data.categories,
          month,
          valeAccounts: data.valeAccountIds,
          cards: data.cards,
        );
        final pending = pendingTithe(data.entries, month: month);
        return LayoutBuilder(
          builder: (context, c) {
            final left = _incomeBlock(context, s, pending);
            final right = _expenseBlock(context, s);
            final minHeight = c.maxHeight - 24;
            if (c.maxWidth >= 1000) {
              // Livro aberto: entradas à esquerda, gastos à direita.
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LedgerSheet(minHeight: minHeight, children: left),
                    ),
                    if (AppScope.of(context).prefs.bookRings)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: BinderRings(height: minHeight),
                      )
                    else
                      const SizedBox(width: 6),
                    Expanded(
                      child: LedgerSheet(minHeight: minHeight, children: right),
                    ),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: LedgerSheet(minHeight: minHeight, children: [...left, const LedgerGap(), ...right]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _incomeBlock(BuildContext context, MonthSummary s, List<Entry> pending) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    final data = scope.data;
    final pendingTotal = pending.fold(0, (sum, e) => sum + e.amount);

    return [
      LedgerHeading(monthLabel(month).split(' de ').first, big: true),
      LedgerHeading(
        'Entradas',
        trailing: LcIconButton(
          LucideIcons.plus,
          tooltip: 'Nova entrada (E)',
          onPressed: () => showEntryForm(context, type: EntryType.receita, date: _defaultDate(month)),
        ),
      ),
      if (s.incomes.isEmpty) LedgerRow(label: 'Nenhuma entrada ainda', color: p.pencil),
      for (final e in s.incomes)
        LedgerRow(
          label: data.labelOf(e),
          value: e.amount,
          checked: e.recurringId != null ? e.paid : null, // entrada fixa: ✓ quando cair
          onCheck: () => scope.db.setPaid(e.id, !e.paid),
          note: switch (e.titheStatus) {
            TitheStatus.pendente => 'dízimo pendente',
            TitheStatus.isento => 'sem dízimo',
            _ => null,
          },
          onTap: () => showEntryForm(context, editing: e),
        ),
      if (pending.isNotEmpty)
        StickyNote(
          text: 'Dízimo a separar de ${formatBRL(pendingTotal)}',
          action: GestureDetector(
            onTap: () => showTitheDialog(context, incomes: pending),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  'Separar agora',
                  style: p
                      .hand(21, color: p.redInk, weight: FontWeight.w700)
                      .copyWith(decoration: TextDecoration.underline, decorationColor: p.redInk),
                ),
              ),
            ),
          ),
        ),
      const LedgerGap(),
      if (s.tithes.isEmpty && s.income > 0) LedgerRow(label: 'Dízimo', note: 'não separado', color: p.pencil),
      for (final e in [...s.tithes, ...s.offerings])
        LedgerRow(
          label: e.categoryId == dizimoCategoryId ? 'Dízimo' : 'Oferta',
          note: [if (e.percentBp != null) formatBp(e.percentBp!), if (!e.paid) 'a entregar'].join(' · '),
          value: e.amount,
          sign: '−',
          checked: e.paid,
          onCheck: () => scope.db.setPaid(e.id, !e.paid),
          onTap: () => showEntryForm(context, editing: e),
        ),
      LedgerRow(label: 'Disponível', value: s.available, color: p.redInk, bold: true),
    ];
  }

  List<Widget> _expenseBlock(BuildContext context, MonthSummary s) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    final data = scope.data;
    final hasAny = s.sections.values.any((l) => l.isNotEmpty) || s.invoices.isNotEmpty;

    return [
      if (!hasAny) ...[LedgerHeading('Gastos'), LedgerRow(label: 'Nenhum gasto ainda', color: p.pencil)],
      for (final MapEntry(key: section, value: list) in s.sections.entries)
        if (list.isNotEmpty || (section == CategorySection.cartao && s.invoices.isNotEmpty)) ...[
          LedgerHeading(
            _sectionNames[section]!,
            trailing: Text(formatBRL(s.sectionTotal(section)), style: p.mono(15, weight: FontWeight.w700)),
          ),
          if (section == CategorySection.cartao)
            for (final inv in s.invoices)
              LedgerRow(
                label: inv.card.name,
                note: 'fatura · vence ${formatDate(inv.dueDate).substring(0, 5)}',
                value: inv.total,
                checked: inv.paid,
                onCheck: () => scope.db.setPaidAll(inv.purchases.map((e) => e.id), !inv.paid),
                onTap: () => showInvoiceSheet(context, inv),
              ),
          for (final e in list)
            LedgerRow(
              label: data.labelOf(e),
              note: e.recurringId != null ? 'fixa' : null,
              value: e.amount,
              checked: e.paid,
              onCheck: () => scope.db.setPaid(e.id, !e.paid),
              onTap: () => showEntryForm(context, editing: e),
            ),
        ],
      if (s.saved.isNotEmpty) ...[
        LedgerHeading(
          'Guardado',
          trailing: Text(
            formatBRL(s.savedTotal),
            style: p.mono(15, weight: FontWeight.w700, color: p.greenInk),
          ),
        ),
        for (final e in s.saved)
          LedgerRow(
            label: data.labelOf(e),
            value: e.amount,
            color: p.greenInk,
            onTap: () => showEntryForm(context, editing: e),
          ),
      ],
      ..._valeBlock(context, s),
      const LedgerGap(),
      LedgerRow(
        label: s.left >= 0 ? 'Sobrou' : 'Faltou',
        value: s.left.abs(),
        color: s.left >= 0 ? p.greenInk : p.redInk,
        bold: true,
      ),
      if (s.left > 0)
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: kLine,
            child: GestureDetector(
              onTap: () => showMoveEnvelope(context, save: true, amount: s.left, date: _defaultDate(month)),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  'guardar a sobra →',
                  style: p
                      .hand(20, color: p.greenInk)
                      .copyWith(decoration: TextDecoration.underline, decorationColor: p.greenInk),
                ),
              ),
            ),
          ),
        ),
      if (s.unpaid > 0) LedgerRow(label: 'Ainda a pagar', value: s.unpaid, color: p.pencil),
    ];
  }
}
