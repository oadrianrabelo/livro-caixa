import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/core/holidays.dart';
import 'package:livro_caixa/data/database.dart';
import 'package:livro_caixa/domain/finance.dart';
import 'package:livro_caixa/domain/vale.dart';

void main() {
  const vale = Account(
    id: 'va',
    createdAt: 0,
    updatedAt: 0,
    name: 'Vale',
    type: AccountType.vale,
    initialBalance: 0,
    archived: false,
    renewDay: 20,
    renewAmount: 60000,
  );
  Entry buy(String date, int amount, {String account = 'va'}) => Entry(
    id: date + amount.toString(),
    createdAt: 0,
    updatedAt: 0,
    type: EntryType.despesa,
    amount: amount,
    date: date,
    description: 'Mercado',
    accountId: account,
    paid: true,
  );

  test('vale renova no dia 20 e conta só o período atual', () {
    final entries = [
      buy('2026-10-25', 10000), // período anterior (20/10 a 18/11)
      buy('2026-11-20', 15000), // dia da renovação: conta no novo
      buy('2026-12-02', 5000),
      buy('2026-11-21', 9999, account: 'carteira'), // não é do vale
    ];
    final s = valeStatus(vale, entries, DateTime(2026, 12, 5));
    // 20/11 é feriado e 20/12 é domingo: renova nos dias úteis anteriores.
    expect(s.periodStart, DateTime(2026, 11, 19));
    expect(s.nextRenewal, DateTime(2026, 12, 18));
    expect(s.spent, 20000);
    expect(s.left, 40000);
    expect(s.daysUntilRenewal(DateTime(2026, 12, 5)), 13);

    // Antes do dia 20: período começou no mês anterior.
    final before = valeStatus(vale, entries, DateTime(2026, 11, 10));
    expect(before.periodStart, DateTime(2026, 10, 20));
    expect(before.spent, 10000);
  });

  test('gastos com o vale não saem do Disponível', () {
    final s = monthSummary(
      [buy('2026-11-21', 15000), buy('2026-11-22', 3000, account: 'carteira')],
      const [],
      '2026-11',
      valeAccounts: {'va'},
    );
    expect(s.valeSpent, 15000);
    expect(s.expense, 3000);
  });

  test('feriado ou fim de semana no dia 20: renova no dia útil anterior', () {
    // 20/11/2026 é sexta, feriado (Consciência Negra): renovou na quinta, 19.
    final s = valeStatus(vale, [buy('2026-11-19', 7000), buy('2026-11-18', 9000)], DateTime(2026, 11, 19));
    expect(s.periodStart, DateTime(2026, 11, 19));
    expect(s.spent, 7000); // o do dia 18 ficou no período anterior
    expect(s.left, 53000);
    // 20/12/2026 é domingo: próxima renovação na sexta, 18/12.
    expect(s.nextRenewal, DateTime(2026, 12, 18));
    // Na véspera (18/11), ainda é o período antigo.
    expect(valeStatus(vale, const [], DateTime(2026, 11, 18)).nextRenewal, DateTime(2026, 11, 19));
    // Virada de ano: 20/01/2027 é quarta, dia normal.
    expect(valeStatus(vale, const [], DateTime(2026, 12, 25)).nextRenewal, DateTime(2027, 1, 20));
  });

  test('feriados móveis', () {
    expect(easter(2026), DateTime(2026, 4, 5));
    expect(isHoliday(DateTime(2026, 4, 3)), isTrue); // Sexta-feira Santa
    expect(isHoliday(DateTime(2026, 2, 17)), isTrue); // Carnaval
    expect(isHoliday(DateTime(2026, 6, 4)), isTrue); // Corpus Christi
    expect(isBusinessDay(DateTime(2026, 11, 19)), isTrue);
    expect(businessDayOnOrBefore(DateTime(2026, 9, 7)), DateTime(2026, 9, 4)); // segunda feriado -> sexta
  });

  test('entrada no vale (estorno) soma no que resta e fica fora do Disponível', () {
    final refund = Entry(
      id: 'r',
      createdAt: 0,
      updatedAt: 0,
      type: EntryType.receita,
      amount: 2500,
      date: '2026-11-25',
      description: 'Estorno',
      accountId: 'va',
      paid: true,
    );
    final st = valeStatus(vale, [buy('2026-11-21', 10000), refund], DateTime(2026, 11, 26));
    expect(st.left, 60000 - 10000 + 2500);
    final s = monthSummary([refund], const [], '2026-11', valeAccounts: {'va'});
    expect(s.income, 0);
    expect(s.valeIn.single.id, 'r');
  });
}
