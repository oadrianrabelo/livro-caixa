import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/database.dart';
import 'package:livro_caixa/domain/finance.dart';

void main() {
  test('excluir conta levando os lançamentos para outra mantém os valores', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const wallet = 'seed-conta-carteira';
    final errada = await db.addAccount(name: 'Errada', type: AccountType.corrente, initialBalance: 0);
    Future<String> add(EntryType type, int amount, String from, {String? to}) => db.saveEntry(
      type: type,
      amount: amount,
      date: '2026-11-10',
      description: '',
      accountId: from,
      toAccountId: to,
      paid: true,
    );
    await add(EntryType.receita, 100000, errada);
    await add(EntryType.despesa, 30000, errada);
    await add(EntryType.transferencia, 5000, wallet, to: errada); // entre as duas: some

    await db.deleteAccountMoving(errada, wallet);

    final accounts = await (db.select(db.accounts)..where((a) => a.deletedAt.isNull())).get();
    expect(accounts.map((a) => a.id), [wallet]);
    final live = await (db.select(db.entries)..where((e) => e.deletedAt.isNull())).get();
    expect(live.length, 2);
    expect(live.every((e) => e.accountId == wallet), isTrue);
    expect(accountBalance(accounts.single, live), 70000);
  });
}
