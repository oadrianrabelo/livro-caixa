// Backup em arquivo JSON. Também serve de "sincronização manual":
// exporte no celular, importe no computador (ou no celular da esposa).
// A importação MESCLA: para cada registro fica a versão com `updatedAt`
// mais recente. Exclusões viajam junto (via `deletedAt`).
import 'package:drift/drift.dart';

import '../data/database.dart';

const backupFormat = 'livro-caixa-backup';
const backupVersion = 1;

class MergeResult {
  int added = 0, updated = 0, skipped = 0;
  @override
  String toString() => '$added novos, $updated atualizados, $skipped sem mudança';
}

Future<Map<String, dynamic>> exportData(AppDatabase db) async {
  Future<List<Map<String, dynamic>>> dump<T extends DataClass>(TableInfo<Table, T> t) async => [
    for (final r in await db.select(t).get()) r.toJson(),
  ];
  return {
    'format': backupFormat,
    'version': backupVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'data': {
      'accounts': await dump(db.accounts),
      'categories': await dump(db.categories),
      'entries': await dump(db.entries),
      'budgets': await dump(db.budgets),
      'recurrings': await dump(db.recurrings),
      'people': await dump(db.people),
      'envelopes': await dump(db.envelopes),
      'receivables': await dump(db.receivables),
      'shopItems': await dump(db.shopItems),
    },
  };
}

Future<MergeResult> importData(AppDatabase db, Object? json) async {
  if (json is! Map || json['format'] != backupFormat || json['data'] is! Map) {
    throw const FormatException('Arquivo não é um backup válido do Livro-Caixa.');
  }
  if ((json['version'] as int) > backupVersion) {
    throw const FormatException('Backup feito numa versão mais nova do app. Atualize o app primeiro.');
  }
  final data = json['data'] as Map;
  final result = MergeResult();

  Future<void> merge<T extends DataClass>(
    TableInfo<Table, T> table,
    String key,
    T Function(Map<String, dynamic>) fromJson,
    String Function(T) idOf,
    int Function(T) updatedAtOf,
  ) async {
    final incoming = [for (final r in (data[key] as List? ?? const [])) fromJson(Map<String, dynamic>.from(r as Map))];
    final local = {for (final r in await db.select(table).get()) idOf(r): r};
    for (final rec in incoming) {
      final existing = local[idOf(rec)];
      if (existing == null) {
        result.added++;
      } else if (updatedAtOf(rec) > updatedAtOf(existing)) {
        result.updated++;
      } else {
        result.skipped++;
        continue;
      }
      await db.into(table).insertOnConflictUpdate(rec as Insertable<T>);
    }
  }

  await db.transaction(() async {
    await merge(db.accounts, 'accounts', Account.fromJson, (r) => r.id, (r) => r.updatedAt);
    await merge(db.categories, 'categories', Category.fromJson, (r) => r.id, (r) => r.updatedAt);
    await merge(db.entries, 'entries', Entry.fromJson, (r) => r.id, (r) => r.updatedAt);
    await merge(db.budgets, 'budgets', Budget.fromJson, (r) => r.id, (r) => r.updatedAt);
    await merge(db.recurrings, 'recurrings', Recurring.fromJson, (r) => r.id, (r) => r.updatedAt);
    await merge(db.people, 'people', Person.fromJson, (r) => r.id, (r) => r.updatedAt);
    await merge(db.envelopes, 'envelopes', Envelope.fromJson, (r) => r.id, (r) => r.updatedAt);
    await merge(db.receivables, 'receivables', Receivable.fromJson, (r) => r.id, (r) => r.updatedAt);
    await merge(db.shopItems, 'shopItems', ShopItem.fromJson, (r) => r.id, (r) => r.updatedAt);
  });
  return result;
}
