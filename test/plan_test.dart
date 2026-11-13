import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/database.dart';

void main() {
  test('lista da casa: põe, tira e põe de novo; limite por categoria', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addToPlan({'arroz': 'Arroz', 'leite': 'Leite'});
    await db.removeFromPlan(['arroz']);
    expect((await db.watchPlan().first).map((i) => i.name), ['Leite']);
    await db.addToPlan({'arroz': 'Arroz'}); // volta, mesmo id
    expect((await db.watchPlan().first).length, 2);

    await db.setBudget('seed-cat-mercado', 40000);
    await db.setBudget('seed-cat-mercado', 50000);
    expect((await db.watchBudgets().first).single.limitAmount, 50000);
    await db.setBudget('seed-cat-mercado', null);
    expect(await db.watchBudgets().first, isEmpty);
    await db.setBudget('seed-cat-mercado', 30000);
    expect((await db.watchBudgets().first).single.limitAmount, 30000);
  });
}
