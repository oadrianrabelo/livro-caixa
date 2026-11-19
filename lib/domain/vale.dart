// Vale-alimentação: dinheiro separado, que NÃO entra no Disponível.
// Renova todo mês no dia `renewDay` com `renewAmount`. O app só mostra quanto
// resta até a próxima renovação (se vocês lançarem as compras com o vale).
import '../core/holidays.dart';
import '../data/database.dart';

class ValeStatus {
  const ValeStatus({required this.periodStart, required this.nextRenewal, required this.amount, required this.spent});
  final DateTime periodStart; // última renovação
  final DateTime nextRenewal;
  final int amount; // valor da renovação
  final int spent; // gasto desde a última renovação

  int get left => amount - spent;
  int daysUntilRenewal(DateTime today) => DateTime(
    nextRenewal.year,
    nextRenewal.month,
    nextRenewal.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
}

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Dia em que o vale renova no mês: o dia combinado, ou o dia útil anterior
/// quando ele cai em fim de semana ou feriado (a empresa antecipa).
DateTime valeRenewalIn(Account vale, int year, int month) =>
    businessDayOnOrBefore(DateTime(year, month, (vale.renewDay ?? 1).clamp(1, 28)));

ValeStatus valeStatus(Account vale, Iterable<Entry> entries, DateTime today) {
  final t = DateTime(today.year, today.month, today.day);
  // Mês "de referência" da renovação atual (DateTime aceita mês 0 e 13).
  var m = t.month;
  var start = valeRenewalIn(vale, t.year, m);
  if (t.isBefore(start)) start = valeRenewalIn(vale, t.year, --m);
  final next = valeRenewalIn(vale, t.year, m + 1);
  final from = _iso(start), until = _iso(next);
  var spent = 0;
  for (final e in entries) {
    if (e.deletedAt != null || e.accountId != vale.id || e.type != EntryType.despesa) continue;
    if (e.date.compareTo(from) >= 0 && e.date.compareTo(until) < 0) spent += e.amount;
  }
  return ValeStatus(periodStart: start, nextRenewal: next, amount: vale.renewAmount ?? 0, spent: spent);
}
