import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/database.dart';
import 'package:livro_caixa/sync/crypto.dart';
import 'package:livro_caixa/sync/remote_store.dart';
import 'package:livro_caixa/sync/sync_engine.dart';

void main() {
  test('cifra e decifra; senha errada é recusada', () async {
    final salt = randomBytes(16);
    final key = await deriveKey('nossa casa', salt);
    final sealed = await seal({'segredo': 'texto-secreto-da-casa-123'}, key);
    expect(await open(sealed, key), {'segredo': 'texto-secreto-da-casa-123'});
    final wrong = await deriveKey('outra', salt);
    expect(() => open(sealed, wrong), throwsA(isA<WrongKeyException>()));
    // Nenhum texto legível no arquivo.
    expect(String.fromCharCodes(sealed).contains('texto-secreto-da-casa'), isFalse);
  });

  test('cofre: o primeiro cria, o segundo confere a senha', () async {
    final store = MemoryStore();
    expect(await vaultExists(store), isFalse);
    final a = await unlockVault(store, 'senha da casa');
    final b = await unlockVault(store, 'senha da casa');
    expect(b, a);
    expect(() => unlockVault(store, 'errada'), throwsA(isA<WrongKeyException>()));
  });

  test('dois celulares: gastos, edições e exclusões chegam no outro', () async {
    final store = MemoryStore();
    final key = await unlockVault(store, 'senha');
    final adrian = AppDatabase(NativeDatabase.memory());
    final andressa = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await adrian.close();
      await andressa.close();
    });
    final syncA = SyncEngine(db: adrian, store: store, key: key, deviceId: 'a');
    final syncB = SyncEngine(db: andressa, store: store, key: key, deviceId: 'b');

    final id = await adrian.saveEntry(
      type: EntryType.despesa,
      amount: 10000,
      date: '2026-11-05',
      description: 'Pão do mês',
      accountId: 'seed-conta-carteira',
      paid: true,
    );
    expect((await syncA.sync()).pushed, isTrue);
    final rb = await syncB.sync();
    expect(rb.devices, 1);
    expect((await andressa.getEntry(id))!.description, 'Pão do mês');

    // Andressa corrige o valor; Adrian recebe.
    final e = (await andressa.getEntry(id))!;
    await Future<void>.delayed(const Duration(milliseconds: 2)); // updatedAt maior
    await andressa.saveEntry(
      id: id,
      type: e.type,
      amount: 12000,
      date: e.date,
      description: e.description,
      accountId: e.accountId,
      paid: true,
    );
    await syncB.sync();
    await syncA.sync();
    expect((await adrian.getEntry(id))!.amount, 12000);

    // Adrian apaga; some na Andressa também.
    await adrian.softDelete(adrian.entries, id);
    await syncA.sync();
    await syncB.sync();
    expect((await andressa.watchAllEntries().first), isEmpty);

    // Nada mudou: não sobe de novo.
    expect((await syncA.sync()).pushed, isFalse);
  });

  test('retrato cifrado com outra senha dá erro (não estraga os dados)', () async {
    final store = MemoryStore();
    final good = await unlockVault(store, 'certa');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final other = await deriveKey('errada', randomBytes(16));
    await SyncEngine(db: db, store: store, key: other, deviceId: 'x').sync();
    expect(() => SyncEngine(db: db, store: store, key: good, deviceId: 'y').sync(), throwsA(isA<WrongKeyException>()));
  });
}
