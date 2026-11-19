// Vale-alimentação: dinheiro separado, que NÃO entra no Disponível.
// Renova todo mês no dia `renewDay` com `renewAmount`.
// - Depois que o saldo é acertado (Editar → Saldo atual, guarda `balanceDate`),
//   o que sobra ACUMULA: saldo de partida + renovações depois do acerto +
//   entradas (estorno) − compras.
// - Sem acerto (contas antigas), conta só o período atual, como antes.
import '../core/holidays.dart';
import '../data/database.dart';

class ValeStatus {
  const ValeStatus({
    required this.periodStart,
    required this.nextRenewal,
    required this.amount,
    required this.spent,
    this.credits = 0,
    required this.balance,
  });
  final DateTime periodStart; // última renovação
  final DateTime nextRenewal;
  final int amount; // valor da renovação
  final int spent; // gasto desde a última renovação
  final int credits; // entradas no vale no período (estorno, crédito extra)
  final int balance; // saldo acumulado agora

  /// Quanto tem no vale agora (acumula de um mês para o outro).
  int get left => balance;
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
  final from = _iso(start), until = _iso(next), now = _iso(t);
  var spent = 0, credits = 0, moves = 0;
  for (final e in entries) {
    if (e.deletedAt != null || e.accountId != vale.id || e.date.compareTo(now) > 0) continue;
    final d = switch (e.type) {
      EntryType.despesa => -e.amount,
      EntryType.receita => e.amount,
      EntryType.transferencia => 0,
    };
    moves += d;
    if (e.date.compareTo(from) < 0 || e.date.compareTo(until) >= 0) continue;
    if (e.type == EntryType.despesa) spent += e.amount;
    if (e.type == EntryType.receita) credits += e.amount;
  }
  final amount = vale.renewAmount ?? 0;
  return ValeStatus(
    periodStart: start,
    nextRenewal: next,
    amount: amount,
    spent: spent,
    credits: credits,
    balance: vale.balanceDate == null
        ? amount +
              credits -
              spent // ainda sem acerto: zera a cada renovação
        : vale.initialBalance + renewalsAfter(vale, DateTime.parse(vale.balanceDate!), t) * amount + moves,
  );
}

/// Quantas renovações caíram depois de [from] (exclusive) até [today] (inclusive).
int renewalsAfter(Account vale, DateTime from, DateTime today) {
  final start = DateTime(from.year, from.month, from.day);
  var n = 0;
  for (var i = 0; ; i++) {
    final month = DateTime(start.year, start.month + i);
    if (month.isAfter(DateTime(today.year, today.month))) break;
    final r = valeRenewalIn(vale, month.year, month.month);
    if (r.isAfter(start) && !r.isAfter(today)) n++;
  }
  return n;
}
