import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/database.dart';
import 'package:livro_caixa/domain/reports.dart';
import 'package:livro_caixa/domain/shopping.dart';

Entry spend(String date, int amount, {String? cat, String? person}) => Entry(
  id: '$date$amount$cat',
  createdAt: 0,
  updatedAt: 0,
  type: EntryType.despesa,
  amount: amount,
  date: date,
  description: '',
  accountId: 'c',
  paid: true,
  categoryId: cat,
  personId: person,
);

ShopItem item(String date, String name, int price, {int qty = 1, String entry = 'e'}) => ShopItem(
  id: '$date$name',
  createdAt: 0,
  updatedAt: 0,
  name: name,
  price: price,
  qty: qty,
  date: date,
  entryId: entry,
);

void main() {
  test('mês comparado à média dos 3 anteriores', () {
    final list = compareWithAverage([
      spend('2026-08-05', 30000, cat: 'mercado'),
      spend('2026-09-05', 30000, cat: 'mercado'),
      spend('2026-10-05', 30000, cat: 'mercado'),
      spend('2026-11-05', 45000, cat: 'mercado'),
      spend('2026-11-06', 10000, cat: dizimoCategoryId), // não é gasto
    ], '2026-11');
    expect(list.single.categoryId, 'mercado');
    expect(list.single.average, 30000);
    expect(list.single.change, closeTo(0.5, 0.001));
  });

  test('quem gastou', () {
    final m = spentByPerson([
      spend('2026-11-01', 100, person: 'a'),
      spend('2026-11-02', 50, person: 'b'),
      spend('2026-11-03', 25, person: 'a'),
      spend('2026-10-03', 999, person: 'a'),
    ], '2026-11');
    expect(m, {'a': 125, 'b': 50});
  });

  test('itens: mesmo nome com acento/maiúscula, preço médio e intervalo', () {
    final stats = productStats(
      [
        item('2026-10-01', 'Feijão', 800, entry: '1'),
        item('2026-10-15', 'feijao ', 900, entry: '2'),
        item('2026-10-29', 'FEIJÃO', 1000, entry: '3'),
        item('2026-10-29', 'Leite', 500, qty: 6, entry: '3'),
        item('2026-10-29', '', 300, entry: '3'), // sem nome: não entra
        item('2026-10-30', 'Café', 2000, entry: 'apagado'),
      ],
      {'1', '2', '3'},
    );
    expect(stats.length, 2);
    final f = stats.first;
    expect(f.name, 'FEIJÃO');
    expect(f.trips, 3);
    expect(f.avgPrice, 900);
    expect(f.lastPrice, 1000);
    expect(f.everyDays, 14);
    expect(f.dueOn(DateTime(2026, 11, 10)), isTrue);
    expect(f.dueOn(DateTime(2026, 10, 31)), isFalse);
    expect(suggestedList(stats, DateTime(2026, 11, 10)).map((s) => s.key), ['feijao']);
    final trips = monthTrips(
      [item('2026-11-02', 'a', 500, qty: 2, entry: 'x'), item('2026-11-02', 'b', 100, entry: 'x')],
      {'x'},
      '2026-11',
    );
    expect(trips.trips, 1);
    expect(trips.total, 1100);
  });

  test('orçamento: usado, perto e estourado', () {
    Budget b(String cat, int limit) =>
        Budget(id: 'budget-$cat', createdAt: 0, updatedAt: 0, categoryId: cat, month: '', limitAmount: limit);
    final list = budgetStatus(
      [b('mercado', 40000), b('lazer', 10000), b('pets', 5000)],
      [
        spend('2026-11-05', 34000, cat: 'mercado'),
        spend('2026-11-06', 12000, cat: 'lazer'),
        spend('2026-10-06', 99999, cat: 'pets'), // outro mês
      ],
      '2026-11',
    );
    expect(list.map((s) => s.categoryId), ['lazer', 'mercado', 'pets']);
    expect(list[0].over, isTrue);
    expect(list[1].near, isTrue);
    expect(list[1].left, 6000);
    expect(list[2].spent, 0);
  });
}
