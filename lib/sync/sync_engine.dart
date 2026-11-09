// Motor da sincronização (sem Google, sem tela -> testável).
//
// No Drive ficam:
//   cofre.json         sal da senha + um teste para saber se a senha confere
//   aparelho-<id>.lcx  o retrato cifrado dos dados de cada aparelho
//
// Sincronizar = baixar os retratos dos OUTROS aparelhos que mudaram, juntar
// (a edição mais recente vence; exclusões também viajam) e subir o nosso.
import 'dart:convert';

import '../backup/backup.dart';
import '../data/database.dart';
import 'crypto.dart';
import 'remote_store.dart';

const vaultFile = 'cofre.json';
const _check = 'livro-caixa';

String deviceFile(String deviceId) => 'aparelho-$deviceId.lcx';

/// Primeiro aparelho cria o cofre; os outros conferem a senha.
/// Devolve a chave (para guardar neste aparelho) ou lança [WrongKeyException].
Future<List<int>> unlockVault(RemoteStore store, String passphrase) async {
  final existing = await store.read(vaultFile);
  if (existing == null) {
    final salt = randomBytes(16);
    final key = await deriveKey(passphrase, salt);
    final check = await seal(_check, key);
    await store.write(
      vaultFile,
      utf8.encode(jsonEncode({'v': 1, 'salt': base64.encode(salt), 'check': base64.encode(check)})),
    );
    return key;
  }
  final vault = jsonDecode(utf8.decode(existing)) as Map<String, dynamic>;
  final key = await deriveKey(passphrase, base64.decode(vault['salt'] as String));
  if (await open(base64.decode(vault['check'] as String), key) != _check) throw const WrongKeyException();
  return key;
}

Future<bool> vaultExists(RemoteStore store) async => (await store.list()).any((f) => f.name == vaultFile);

class SyncReport {
  int devices = 0; // retratos de outros aparelhos que foram juntados
  int added = 0, updated = 0;
  bool pushed = false;
}

class SyncEngine {
  SyncEngine({required this.db, required this.store, required this.key, required this.deviceId});

  final AppDatabase db;
  final RemoteStore store;
  final List<int> key;
  final String deviceId;

  /// Última versão vista de cada arquivo (para não baixar o que não mudou).
  final Map<String, DateTime> _seen = {};
  String? _lastPushedHash;

  Future<SyncReport> sync() async {
    final report = SyncReport();
    final mine = deviceFile(deviceId);
    for (final f in await store.list()) {
      if (!f.name.startsWith('aparelho-') || f.name == mine) continue;
      if (_seen[f.name] == f.modified) continue;
      final bytes = await store.read(f.name);
      if (bytes == null) continue;
      final result = await importData(db, await open(bytes, key));
      _seen[f.name] = f.modified;
      report
        ..devices += 1
        ..added += result.added
        ..updated += result.updated;
    }

    // Sobe o nosso retrato só se algo mudou desde a última vez.
    final snapshot = await exportData(db);
    final data = snapshot['data'];
    final hash = await jsonHash(data!);
    if (hash != _lastPushedHash) {
      await store.write(mine, await seal(snapshot, key));
      _lastPushedHash = hash;
      report.pushed = true;
    }
    return report;
  }
}
