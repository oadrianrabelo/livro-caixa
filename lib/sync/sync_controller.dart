// Liga a sincronização ao app: quando sincronizar e o que mostrar na tela.
//
// Sincroniza sozinho: ao abrir o app, ao voltar para ele, e alguns segundos
// depois de cada mudança. Sem internet, só tenta de novo na próxima vez:
// o app continua funcionando 100% offline.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../data/app_data.dart';
import '../data/database.dart';
import 'crypto.dart';
import 'drive_store.dart';
import 'google_auth.dart';
import 'sync_engine.dart';

enum SyncStatus { off, needsPassphrase, idle, syncing, error }

class SyncController extends ChangeNotifier {
  SyncController(this._db, this._data) : _auth = GoogleAuth.create(_db) {
    _lifecycle = AppLifecycleListener(onResume: () => syncSoon(const Duration(seconds: 1)));
    _data.addListener(_onDataChanged);
    _start();
  }

  final AppDatabase _db;
  final AppData _data;
  final GoogleAuth _auth;
  late final AppLifecycleListener _lifecycle;

  SyncStatus status = SyncStatus.off;
  String? error;
  DateTime? lastSync;
  SyncEngine? _engine;
  DriveStore? _store;
  Timer? _debounce;
  bool _busy = false, _suppress = false;

  bool get configured => _auth.configured;
  bool get enabled => status != SyncStatus.off;

  void _set(SyncStatus s, {String? err}) {
    status = s;
    error = err;
    notifyListeners();
  }

  Future<Map<String, String>> get _settings => _db.watchSettings().first;

  Future<String> _deviceId() async {
    final id = (await _settings)['device_id'];
    if (id != null && id.isNotEmpty) return id;
    final created = newId();
    await _db.setSetting('device_id', created);
    return created;
  }

  Future<void> _start() async {
    final s = await _settings;
    if (s['sync_enabled'] != '1' || !configured) return;
    final key = s['sync_key'];
    if (key == null || key.isEmpty) return _set(SyncStatus.needsPassphrase);
    await _connect(base64.decode(key), interactive: false);
  }

  Future<bool> _connect(List<int> key, {required bool interactive}) async {
    try {
      final client = await _auth.client(interactive: interactive);
      if (client == null) {
        _set(SyncStatus.error, err: 'Entre de novo com a conta Google.');
        return false;
      }
      _store = DriveStore(client);
      _engine = SyncEngine(db: _db, store: _store!, key: key, deviceId: await _deviceId());
      _set(SyncStatus.idle);
      await syncNow();
      return true;
    } catch (e) {
      _set(SyncStatus.error, err: _friendly(e));
      return false;
    }
  }

  /// Passo 1: entrar com a conta Google da casa.
  Future<void> signIn() async {
    try {
      final client = await _auth.client(interactive: true);
      if (client == null) return;
      _store = DriveStore(client);
      await _db.setSetting('sync_enabled', '1');
      _set(SyncStatus.needsPassphrase);
    } catch (e) {
      _set(SyncStatus.off, err: _friendly(e));
    }
  }

  /// Se o Drive já tem cofre (outro aparelho criou) -> pedir a senha; senão, criar.
  Future<bool> vaultExistsRemote() async {
    _store ??= DriveStore((await _auth.client(interactive: true))!);
    return vaultExists(_store!);
  }

  /// Passo 2: senha da casa. Devolve a mensagem de erro, ou null se deu certo.
  Future<String?> unlock(String passphrase) async {
    try {
      _store ??= DriveStore((await _auth.client(interactive: true))!);
      final key = await unlockVault(_store!, passphrase);
      await _db.setSetting('sync_key', base64.encode(key));
      await _connect(key, interactive: true);
      return null;
    } on WrongKeyException {
      return 'Senha diferente da criada no outro aparelho.';
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<void> signOut() async {
    _debounce?.cancel();
    await _auth.signOut();
    await _db.setSetting('sync_enabled', '0');
    await _db.setSetting('sync_key', '');
    _engine = null;
    _store = null;
    lastSync = null;
    _set(SyncStatus.off);
  }

  bool _changedWhileBusy = false;

  void _onDataChanged() {
    if (_suppress) {
      // Pode ser o que chegou do outro aparelho, ou um lançamento feito bem na
      // hora da sincronização. Na dúvida, confere de novo depois (se nada
      // mudou, a rodada extra não envia nada).
      _changedWhileBusy = true;
      return;
    }
    if (_engine != null) syncSoon(const Duration(seconds: 6));
  }

  void syncSoon(Duration delay) {
    if (_engine == null) return;
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  Future<void> syncNow() async {
    final engine = _engine;
    if (engine == null || _busy) return;
    _busy = true;
    _set(SyncStatus.syncing);
    try {
      _suppress = true; // o que chega do outro aparelho não dispara outra rodada
      await engine.sync();
      lastSync = DateTime.now();
      _set(SyncStatus.idle);
    } catch (e) {
      _set(SyncStatus.error, err: _friendly(e));
    } finally {
      _busy = false;
      // deixa as atualizações das telas passarem antes de voltar a observar
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        _suppress = false;
        if (_changedWhileBusy) {
          _changedWhileBusy = false;
          syncSoon(const Duration(seconds: 6));
        }
      });
    }
  }

  static String _friendly(Object e) {
    final s = '$e';
    if (e is WrongKeyException) return s;
    if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup')) {
      return 'Sem internet. Tenta de novo sozinho mais tarde.';
    }
    if (s.contains('canceled') || s.contains('cancelled')) return 'Login cancelado.';
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _lifecycle.dispose();
    _data.removeListener(_onDataChanged);
    super.dispose();
  }
}
