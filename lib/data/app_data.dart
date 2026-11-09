import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/dates.dart';

import '../platform/extras.dart';
import '../sync/sync_controller.dart';
import '../updates/updater.dart';
import 'database.dart';
import 'prefs.dart';

/// Mantém em memória as listas do banco e avisa as telas quando mudam.
/// Para um app pessoal (milhares de lançamentos) isso é mais que suficiente
/// e deixa as telas bem simples.
class AppData extends ChangeNotifier {
  AppData(this.db) {
    _subs = [
      db.watchAccounts().listen((v) => _set(() => accounts = v)),
      db.watchCategories().listen((v) => _set(() => categories = v)),
      db.watchAllEntries().listen((v) => _set(() => entries = v)),
      db.watchRecurrings().listen((v) => _set(() => recurrings = v)),
      db.watchPeople().listen((v) => _set(() => people = v)),
      db.watchEnvelopes().listen((v) => _set(() => envelopes = v)),
      db.watchReceivables().listen((v) => _set(() => receivables = v)),
    ];
    db.ensureRecurringEntries(monthOf(today())); // contas fixas do mês atual
  }

  final AppDatabase db;
  late final List<StreamSubscription<void>> _subs;

  List<Account> accounts = [];
  List<Category> categories = [];
  List<Entry> entries = [];
  List<Recurring> recurrings = [];
  List<Person> people = [];
  List<Envelope> envelopes = [];
  List<Receivable> receivables = [];

  /// Cartões de crédito (compras deles vão para a fatura).
  List<Account> get cards => [
    for (final a in accounts)
      if (a.type == AccountType.cartao) a,
  ];

  /// Contas de vale-alimentação (ficam fora do Disponível).
  Set<String> get valeAccountIds => {
    for (final a in accounts)
      if (a.type == AccountType.vale) a.id,
  };

  Person? person(String? id) => people.where((p) => p.id == id).firstOrNull;
  Recurring? recurring(String? id) => recurrings.where((r) => r.id == id).firstOrNull;

  /// Como o lançamento aparece no caderno: "Perfume (1/2)", ou a categoria se não tiver descrição.
  String labelOf(Entry e) {
    final base = e.description.isNotEmpty
        ? e.description
        : category(e.categoryId)?.name ?? (e.type == EntryType.receita ? 'Entrada' : 'Gasto');
    return e.installmentCount != null ? '$base (${e.installmentIndex}/${e.installmentCount})' : base;
  }

  Account? account(String? id) => accounts.where((a) => a.id == id).firstOrNull;
  Category? category(String? id) => categories.where((c) => c.id == id).firstOrNull;

  /// Lançamentos do mês ("AAAA-MM"), mais recentes primeiro.
  List<Entry> monthEntries(String month) =>
      entries.where((e) => e.date.startsWith(month)).toList()
        ..sort((a, b) => b.date.compareTo(a.date) != 0 ? b.date.compareTo(a.date) : b.createdAt.compareTo(a.createdAt));

  void _set(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Dá acesso ao banco, aos dados e ao atualizador em qualquer tela:
/// `AppScope.of(context).data`.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.db,
    required this.data,
    required this.prefs,
    required this.updater,
    required this.sync,
    required this.extras,
    required super.child,
  });

  final AppDatabase db;
  final AppData data;
  final Prefs prefs;
  final Updater updater;
  final SyncController sync;
  final PhoneExtras extras;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => false;
}
