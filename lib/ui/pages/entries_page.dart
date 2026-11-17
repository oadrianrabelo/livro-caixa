import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';
import '../widgets/common.dart';
import '../widgets/entry_form.dart';

/// Todos os lançamentos do mês, agrupados por dia, com busca e filtro.
class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  String _month = monthOf(today());
  final _search = TextEditingController();
  EntryType? _filter; // null = todos

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final p = Paper.of(context);
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final q = _search.text.trim().toLowerCase();
        final list = data
            .monthEntries(_month)
            .where((e) => _filter == null || e.type == _filter)
            // Busca também pelo nome da conta (ex.: "bb").
            .where(
              (e) =>
                  q.isEmpty ||
                  data.labelOf(e).toLowerCase().contains(q) ||
                  (data.account(e.accountId)?.name.toLowerCase().contains(q) ?? false) ||
                  (data.account(e.toAccountId)?.name.toLowerCase().contains(q) ?? false),
            )
            .toList();
        final byDay = <String, List<Entry>>{};
        for (final e in list) {
          byDay.putIfAbsent(e.date, () => []).add(e);
        }

        return PageBody(
          title: 'Lançamentos',
          trailing: MonthPicker(month: _month, onChanged: (m) => setState(() => _month = m)),
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: lcInputDecoration(
                context,
                hint: 'Buscar neste mês…',
                prefixIcon: Icon(LucideIcons.search, size: 16, color: p.pencil),
              ),
            ),
            const SizedBox(height: 12),
            LcSegmented<EntryType?>(
              options: const [
                (null, 'Todos'),
                (EntryType.despesa, 'Gastos'),
                (EntryType.receita, 'Entradas'),
                (EntryType.transferencia, 'Transferências'),
              ],
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 18),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Text('Nada por aqui', style: p.hand(30, color: p.pencil)),
                    const SizedBox(height: 4),
                    Text('Use o botão Lançar para começar.', style: TextStyle(fontSize: 13, color: p.pencil)),
                  ],
                ),
              ),
            for (final MapEntry(key: day, value: entries) in byDay.entries)
              LcGroup(
                title: _dayLabel(day),
                children: [for (final e in entries) _EntryRow(entry: e)],
              ),
          ],
        );
      },
    );
  }

  static String _dayLabel(String date) {
    if (date == today()) return 'HOJE';
    final d = DateTime.parse(date);
    const w = ['SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA', 'SÁBADO', 'DOMINGO'];
    return '${w[d.weekday - 1]}, ${formatDate(date).substring(0, 5)}';
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final data = scope.data;
    final p = Paper.of(context);
    final e = entry;
    final cat = data.category(e.categoryId);
    final transfer = e.type == EntryType.transferencia;
    final (sign, color) = switch (e.type) {
      EntryType.receita => ('+', p.greenInk),
      EntryType.despesa => ('−', p.ink),
      EntryType.transferencia => ('', p.pencil),
    };
    final subtitle = [
      data.account(e.accountId)?.name ?? '—',
      if (transfer) '→ ${data.account(e.toAccountId)?.name ?? '—'}',
      ?data.person(e.personId)?.name,
      if (e.recurringId != null) 'fixa',
      if (!e.paid) 'pendente',
    ].join(' · ');

    return LcRow(
      dim: !e.paid,
      leading: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (cat != null ? Color(cat.color) : p.ink).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: transfer
            ? Icon(LucideIcons.arrowLeftRight, size: 15, color: p.ink)
            : Text(cat?.icon ?? '•', style: const TextStyle(fontSize: 15)),
      ),
      title: data.labelOf(e),
      subtitle: subtitle,
      onTap: () => showEntryForm(context, editing: e),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$sign ${formatBRL(e.amount)}',
            style: p.mono(14, weight: FontWeight.w600, color: color),
          ),
          if (!e.paid)
            LcIconButton(
              LucideIcons.check,
              tooltip: e.type == EntryType.receita ? 'Marcar como recebido' : 'Marcar como pago',
              size: 15,
              onPressed: () => scope.db.markPaid(e.id),
            ),
        ],
      ),
    );
  }
}
