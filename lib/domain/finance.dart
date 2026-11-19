// Regras de negócio puras (sem banco, sem tela) -> fáceis de testar.
import '../data/database.dart';
import 'cards.dart';

/// Saldo atual de uma conta, considerando só lançamentos pagos.
int accountBalance(Account account, Iterable<Entry> entries) {
  var balance = account.initialBalance;
  for (final e in entries) {
    if (e.deletedAt != null || !e.paid) continue;
    switch (e.type) {
      case EntryType.receita when e.accountId == account.id:
        balance += e.amount;
      case EntryType.despesa when e.accountId == account.id:
        balance -= e.amount;
      case EntryType.transferencia:
        if (e.accountId == account.id) balance -= e.amount;
        if (e.toAccountId == account.id) balance += e.amount;
      default:
    }
  }
  return balance;
}

/// Uma linha do extrato: quanto mexeu na conta e o saldo logo depois.
typedef StatementLine = ({Entry entry, int delta, int after});

/// Quanto um lançamento muda o saldo de uma conta (0 se não mexe nela).
int deltaFor(Account account, Entry e) => switch (e.type) {
  EntryType.receita when e.accountId == account.id => e.amount,
  EntryType.despesa when e.accountId == account.id => -e.amount,
  EntryType.transferencia => (e.toAccountId == account.id ? e.amount : 0) - (e.accountId == account.id ? e.amount : 0),
  _ => 0,
};

/// Extrato da conta: os lançamentos pagos que mexeram nela, do mais antigo
/// ao mais novo, com o saldo depois de cada um (começa no saldo inicial).
List<StatementLine> accountStatement(Account account, Iterable<Entry> entries) {
  final moves = [
    for (final e in entries)
      if (e.deletedAt == null && e.paid && deltaFor(account, e) != 0) e,
  ]..sort((a, b) => a.date != b.date ? a.date.compareTo(b.date) : a.createdAt.compareTo(b.createdAt));
  var balance = account.initialBalance;
  return [for (final e in moves) (entry: e, delta: deltaFor(account, e), after: balance += deltaFor(account, e))];
}

/// A página do mês, como no caderno:
///   Entradas − Dízimo − Oferta = Disponível
///   Disponível − (Cartão + Casa + Pessoal + Outros) = Sobrou
class MonthSummary {
  final List<Entry> incomes = [];
  final List<Entry> tithes = [];
  final List<Entry> offerings = [];

  /// Gastos por seção, na ordem do caderno (sem as primícias).
  final Map<CategorySection, List<Entry>> sections = {
    CategorySection.cartao: [],
    CategorySection.casa: [],
    CategorySection.pessoal: [],
    CategorySection.outros: [],
  };

  /// Gastos pagos com o vale-alimentação: aparecem, mas não saem do Disponível.
  final List<Entry> vale = [];

  /// Entradas no vale (estorno, crédito extra): também fora do Disponível.
  final List<Entry> valeIn = [];

  /// Faturas de cartão que vencem neste mês (entram em Cartão).
  final List<Invoice> invoices = [];

  /// Dinheiro guardado em envelopes neste mês (sai do Disponível, mas não é gasto).
  final List<Entry> saved = [];

  int get income => _sum(incomes);
  int get valeSpent => _sum(vale);
  int get tithe => _sum(tithes);
  int get offering => _sum(offerings);

  /// O que temos depois de tirar o que é de Deus. É daqui que se conta.
  int get available => income - tithe - offering;
  int get invoicesTotal => invoices.fold(0, (s, i) => s + i.total);
  int get savedTotal => _sum(saved);
  int sectionTotal(CategorySection s) => _sum(sections[s]!) + (s == CategorySection.cartao ? invoicesTotal : 0);
  int get expense => sections.values.fold(0, (sum, list) => sum + _sum(list)) + invoicesTotal;
  int get left => available - expense - savedTotal;

  /// Gastos (e primícias) ainda não pagos/entregues.
  int get unpaid =>
      [
        ...tithes,
        ...offerings,
        for (final l in sections.values) ...l,
      ].where((e) => !e.paid).fold(0, (s, e) => s + e.amount) +
      invoices.where((i) => !i.paid).fold(0, (s, i) => s + i.total);

  static int _sum(List<Entry> l) => l.fold(0, (s, e) => s + e.amount);
}

/// Resumo de um mês ("AAAA-MM"). Transferências não entram (o dinheiro só muda de lugar).
/// Lançamentos nas contas [valeAccounts] (vale-alimentação) ficam à parte.
MonthSummary monthSummary(
  Iterable<Entry> entries,
  Iterable<Category> categories,
  String month, {
  Set<String> valeAccounts = const {},
  Iterable<Account> cards = const [],
}) {
  final sectionOf = {for (final c in categories) c.id: c.section};
  final cardIds = {for (final c in cards) c.id};
  final s = MonthSummary();
  s.invoices.addAll(invoicesFor(cards, entries, month));
  for (final e in entries) {
    if (cardIds.contains(e.accountId) && e.type == EntryType.despesa) continue; // vão para a fatura
    if (e.deletedAt != null || !e.date.startsWith(month)) continue;
    if (valeAccounts.contains(e.accountId)) {
      if (e.type == EntryType.despesa) s.vale.add(e);
      if (e.type == EntryType.receita) s.valeIn.add(e);
      continue;
    }
    switch (e.type) {
      case EntryType.receita:
        s.incomes.add(e);
      case EntryType.despesa when e.categoryId == dizimoCategoryId:
        s.tithes.add(e);
      case EntryType.despesa when e.categoryId == ofertaCategoryId:
        s.offerings.add(e);
      case EntryType.despesa when e.envelopeId != null || sectionOf[e.categoryId] == CategorySection.guardado:
        s.saved.add(e);
      case EntryType.despesa:
        final section = sectionOf[e.categoryId] ?? CategorySection.outros;
        s
            .sections[section == CategorySection.primicias || section == CategorySection.guardado
                ? CategorySection.outros
                : section]!
            .add(e);
      case EntryType.transferencia:
    }
  }
  for (final l in [s.incomes, s.tithes, s.offerings, s.vale, s.saved, ...s.sections.values]) {
    l.sort((a, b) => a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : a.createdAt.compareTo(b.createdAt));
  }
  return s;
}
