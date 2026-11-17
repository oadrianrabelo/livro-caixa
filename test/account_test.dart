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

  test('extrato: saldo linha a linha, só pagos', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final bb = await db.addAccount(name: 'BB', type: AccountType.corrente, initialBalance: 0);
    Future<void> add(EntryType type, int amount, String date, {bool paid = true, String from = 'x', String? to}) =>
        db.saveEntry(
          type: type,
          amount: amount,
          date: date,
          description: '',
          accountId: from,
          toAccountId: to,
          paid: paid,
        );
    await add(EntryType.despesa, 10000, '2026-11-02', from: bb);
    await add(EntryType.transferencia, 10000, '2026-11-10', from: 'seed-conta-carteira', to: bb);
    await add(EntryType.despesa, 5000, '2026-11-12', from: bb, paid: false);
    final account = (await (db.select(db.accounts)..where((a) => a.id.equals(bb))).get()).single;
    final lines = accountStatement(account, await db.select(db.entries).get());
    expect([for (final l in lines) l.after], [-10000, 0]);
  });
}
