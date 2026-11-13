// Relatórios simples: o mês comparado com a média e quem gastou.
import '../core/dates.dart';
import '../data/database.dart';

/// Gasto "de verdade": despesa que não é dízimo, oferta nem dinheiro guardado.
bool isSpending(Entry e) =>
    e.type == EntryType.despesa &&
    e.categoryId != dizimoCategoryId &&
    e.categoryId != ofertaCategoryId &&
    e.envelopeId == null;

class CategoryCompare {
  CategoryCompare(this.categoryId, this.current, this.average);
  final String? categoryId;
  final int current; // neste mês
  final int average; // média dos meses anteriores (só os que tiveram gasto)
  int get diff => current - average;
  double get change => average == 0 ? 0 : diff / average;
}

/// Cada categoria no [month] comparada à média dos [lookback] meses anteriores.
/// Ordena pelo que mais passou da média.
List<CategoryCompare> compareWithAverage(Iterable<Entry> entries, String month, {int lookback = 3}) {
  final past = [for (var i = 1; i <= lookback; i++) addMonths(month, -i)];
  final current = <String?, int>{};
  final perMonth = <String?, Map<String, int>>{};
  for (final e in entries) {
    if (!isSpending(e)) continue;
    final m = e.date.substring(0, 7);
    if (m == month) {
      current.update(e.categoryId, (v) => v + e.amount, ifAbsent: () => e.amount);
    } else if (past.contains(m)) {
      perMonth.putIfAbsent(e.categoryId, () => {}).update(m, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
  }
  final ids = {...current.keys, ...perMonth.keys};
  final list = [
    for (final id in ids)
      CategoryCompare(id, current[id] ?? 0, () {
        final months = perMonth[id];
        if (months == null || months.isEmpty) return 0;
        return (months.values.fold(0, (a, b) => a + b) / lookback).round();
      }()),
  ];
  list.sort((a, b) => b.diff.compareTo(a.diff));
  return list;
}

/// Quanto cada pessoa gastou nos lançamentos cujo dia começa com [prefix]
/// ("2026" para o ano, "2026-11" para o mês). Chave null = sem pessoa.
Map<String?, int> spentByPerson(Iterable<Entry> entries, String prefix) {
  final out = <String?, int>{};
  for (final e in entries) {
    if (!isSpending(e) || !e.date.startsWith(prefix)) continue;
    out.update(e.personId, (v) => v + e.amount, ifAbsent: () => e.amount);
  }
  return out;
}

class BudgetStatus {
  BudgetStatus(this.categoryId, this.limit, this.spent);
  final String categoryId;
  final int limit, spent;
  double get used => limit == 0 ? 0 : spent / limit;
  int get left => limit - spent;
  bool get over => spent > limit;
  bool get near => !over && used >= 0.8;
}

/// Quanto de cada limite mensal já foi usado em [month]. Os mais apertados primeiro.
List<BudgetStatus> budgetStatus(Iterable<Budget> budgets, Iterable<Entry> entries, String month) {
  final spent = <String, int>{};
  for (final e in entries) {
    if (!isSpending(e) || e.categoryId == null || !e.date.startsWith(month)) continue;
    spent.update(e.categoryId!, (v) => v + e.amount, ifAbsent: () => e.amount);
  }
  return [for (final b in budgets) BudgetStatus(b.categoryId, b.limitAmount, spent[b.categoryId] ?? 0)]
    ..sort((a, b) => b.used.compareTo(a.used));
}
