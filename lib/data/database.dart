import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'database.steps.dart';

import 'package:uuid/uuid.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Modelo de dados (SQLite, via drift)
//
// Regras que deixam o app pronto para juntar dados de dois aparelhos:
//  - IDs são UUIDs gerados no aparelho -> sem colisão entre o seu celular e
//    o da sua esposa.
//  - Todo registro tem `updatedAt` -> na mesclagem, a versão mais nova vence.
//  - Nada é apagado de verdade: marcamos `deletedAt` ("lápide"), assim a
//    exclusão também viaja na mesclagem.
//
// Mudou alguma tabela? Passo a passo (nunca apague dados):
//  1. Edite as tabelas e suba o `schemaVersion`.
//  2. `dart run build_runner build` e depois `dart run drift_dev make-migrations`
//     (guarda o esquema novo em drift_schemas/ e gera database.steps.dart).
//  3. Escreva o passo `fromXToY` em `migration` e rode os testes:
//     test/drift/ confere que a migração chega exatamente no esquema novo.
// ---------------------------------------------------------------------------

/// `vale`: vale-alimentação. Fica FORA do Disponível: tem saldo próprio que
/// renova todo mês no dia [Accounts.renewDay] com [Accounts.renewAmount].
enum AccountType { corrente, poupanca, carteira, cartao, investimento, vale }

enum CategoryKind { despesa, receita }

enum EntryType { despesa, receita, transferencia }

/// Situação do dízimo e da oferta de uma ENTRADA (receita).
/// - pendente: ainda não separado (o app lembra na página do mês)
/// - separado: dízimo e oferta já lançados
/// - isento: não gera dízimo (ex.: um empréstimo que voltou)
/// Nulo em despesas e transferências.
enum TitheStatus { pendente, separado, isento }

/// Seções da página do mês, como no caderno.
enum CategorySection { primicias, cartao, casa, pessoal, outros, guardado }

/// IDs fixos das categorias especiais (criadas pelo app, ver _seedCategories).
const dizimoCategoryId = 'seed-cat-dizimo';
const ofertaCategoryId = 'seed-cat-oferta';
const guardadoCategoryId = 'seed-cat-guardado';

mixin SyncColumns on Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()(); // millisecondsSinceEpoch
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get type => textEnum<AccountType>()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))(); // centavos
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get renewDay => integer().nullable()(); // vale: dia do mês em que renova (1-28)
  IntColumn get renewAmount => integer().nullable()(); // vale: valor que entra a cada renovação
  IntColumn get closingDay => integer().nullable()(); // cartão: dia em que a fatura fecha
  IntColumn get dueDay => integer().nullable()(); // cartão: dia em que a fatura vence
}

class Categories extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get kind => textEnum<CategoryKind>()();
  TextColumn get icon => text()(); // emoji
  IntColumn get color => integer()(); // 0xAARRGGBB
  TextColumn get section => textEnum<CategorySection>().nullable()(); // só despesas
  TextColumn get project => text().nullable()(); // agrupa entradas e gastos de um "negócio" (ex.: Alfajor)
}

/// Lançamentos (despesa, receita ou transferência).
class Entries extends Table with SyncColumns {
  TextColumn get type => textEnum<EntryType>()();
  IntColumn get amount => integer()(); // centavos, sempre positivo
  TextColumn get date => text()(); // AAAA-MM-DD
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get accountId => text()();
  TextColumn get toAccountId => text().nullable()(); // só transferências
  TextColumn get categoryId => text().nullable()();
  BoolColumn get paid => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  TextColumn get titheStatus => textEnum<TitheStatus>().nullable()();
  IntColumn get percentBp => integer().nullable()(); // dízimo/oferta: % usado, em centésimos (250 = 2,5%)
  TextColumn get recurringId => text().nullable()(); // gerado por uma conta fixa
  TextColumn get installmentGroup => text().nullable()(); // parcelas da mesma compra
  IntColumn get installmentIndex => integer().nullable()(); // 1, 2, 3...
  IntColumn get installmentCount => integer().nullable()(); // total de parcelas
  TextColumn get personId => text().nullable()(); // quem lançou / de quem é
  TextColumn get envelopeId => text().nullable()(); // guardar (gasto) ou tirar (entrada) de um envelope
}

/// Conta fixa: aparece sozinha todo mês (aluguel, internet, luz, salário...).
/// O lançamento de cada mês tem id FIXO `rec-<id>-<AAAA-MM>`: assim dois
/// aparelhos geram o mesmo lançamento e a mesclagem não duplica.
class Recurrings extends Table with SyncColumns {
  TextColumn get type => textEnum<EntryType>()(); // despesa ou receita
  TextColumn get description => text()();
  IntColumn get amount => integer()(); // centavos (valor base)
  BoolColumn get variable => boolean().withDefault(const Constant(false))(); // ex.: luz: repete o do mês anterior
  IntColumn get day => integer()(); // dia do mês (1-28)
  TextColumn get accountId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get personId => text().nullable()();
  TextColumn get startMonth => text()(); // AAAA-MM
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Envelope do "Guardado" (Férias, Reserva...). O saldo é o inicial + o que
/// foi guardado (gastos com envelopeId) − o que foi tirado (entradas com envelopeId).
class Envelopes extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('🏺'))();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  IntColumn get goal => integer().nullable()(); // meta (centavos)
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Dinheiro que alguém deve devolver (ex.: o adiantamento emprestado).
class Receivables extends Table with SyncColumns {
  TextColumn get description => text()();
  IntColumn get amount => integer()();
  TextColumn get dueDate => text().nullable()(); // AAAA-MM-DD
  TextColumn get receivedEntryId => text().nullable()(); // a entrada criada quando voltou
}

/// Itens anotados na calculadora de compras: o histórico do mercado.
/// Gravados quando a compra é lançada; servem para os relatórios e para
/// sugerir preço e lista de compras.
class ShopItems extends Table with SyncColumns {
  TextColumn get name => text().withDefault(const Constant(''))(); // como foi digitado
  IntColumn get price => integer()(); // centavos, por unidade
  IntColumn get qty => integer().withDefault(const Constant(1))();
  TextColumn get date => text()(); // AAAA-MM-DD
  TextColumn get entryId => text().nullable()(); // o lançamento da compra
}

/// Lista de compras da casa ("Para pegar"): compartilhada entre os aparelhos.
/// O id vem do nome (`plan-arroz`), então o mesmo item posto nos dois
/// celulares vira um só.
@DataClassName('PlanItem')
class PlanItems extends Table with SyncColumns {
  TextColumn get name => text()();
}

/// Pessoas da casa (para saber quem lançou / de quem é o gasto).
@DataClassName('Person')
class People extends Table with SyncColumns {
  TextColumn get name => text()();
}

/// Orçamento mensal por categoria (ainda sem tela: bom primeiro exercício!).
class Budgets extends Table with SyncColumns {
  TextColumn get categoryId => text()();
  TextColumn get month => text()(); // AAAA-MM
  IntColumn get limitAmount => integer()(); // centavos
}

/// Preferências deste aparelho (percentuais, fontes, tema). Chave -> valor em texto.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

const _uuid = Uuid();
String newId() => _uuid.v4();
int now() => DateTime.now().millisecondsSinceEpoch;

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Entries,
    Budgets,
    Settings,
    Recurrings,
    People,
    Envelopes,
    Receivables,
    ShopItems,
    PlanItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// O arquivo `livro_caixa.sqlite` fica na pasta de dados do app
  /// (Windows: %APPDATA%, Linux: `~/.local/share/<id>`, Android: dados do app).
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'livro_caixa',
              native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory),
            ),
      );

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(accounts).insert(
        AccountsCompanion.insert(
          id: 'seed-conta-carteira',
          createdAt: 0,
          updatedAt: 0,
          name: 'Carteira',
          type: AccountType.carteira,
        ),
      );
      await _seedCategories();
      await _seedPeople();
      await _seedProjects();
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.categories, schema.categories.section);
        await m.addColumn(schema.entries, schema.entries.titheStatus);
        await m.addColumn(schema.entries, schema.entries.percentBp);
        await m.createTable(schema.settings);
        await _seedCategories(); // cria Dízimo, Oferta etc. e preenche as seções
      },
      from2To3: (m, schema) async {
        await m.addColumn(schema.accounts, schema.accounts.renewDay);
        await m.addColumn(schema.accounts, schema.accounts.renewAmount);
        for (final c in [
          schema.entries.recurringId,
          schema.entries.installmentGroup,
          schema.entries.installmentIndex,
          schema.entries.installmentCount,
          schema.entries.personId,
        ]) {
          await m.addColumn(schema.entries, c);
        }
        await m.createTable(schema.recurrings);
        await m.createTable(schema.people);
        await _seedPeople();
      },
      from3To4: (m, schema) async {
        await m.addColumn(schema.accounts, schema.accounts.closingDay);
        await m.addColumn(schema.accounts, schema.accounts.dueDay);
        await m.addColumn(schema.categories, schema.categories.project);
        await m.addColumn(schema.entries, schema.entries.envelopeId);
        await m.createTable(schema.envelopes);
        await m.createTable(schema.receivables);
        await _seedCategories(); // cria Guardado e Ingredientes do alfajor
        await _seedProjects();
      },
      from4To5: (m, schema) async {
        await m.createTable(schema.shopItems);
      },
      from5To6: (m, schema) async {
        await m.createTable(schema.planItems);
      },
    ),
  );

  /// Alfajor é um "negócio": entradas e gastos dele aparecem juntos (lucro).
  Future<void> _seedProjects() => customStatement(
    "UPDATE categories SET project = 'Alfajor' WHERE id IN ('seed-cat-alfajor', 'seed-cat-ingredientes') AND project IS NULL",
  );

  /// As duas pessoas da casa, com IDs fixos (iguais em todos os aparelhos).
  /// Os nomes podem ser trocados nos Ajustes.
  Future<void> _seedPeople() async {
    for (final (id, name) in [('seed-pessoa-1', 'Adrian'), ('seed-pessoa-2', 'Andressa')]) {
      await customStatement('INSERT OR IGNORE INTO people (id, created_at, updated_at, name) VALUES (?, 0, 0, ?)', [
        id,
        name,
      ]);
    }
  }

  /// Categorias padrão com IDs FIXOS e updatedAt = 0: assim o celular e o PC
  /// criam as mesmas, e a mesclagem do backup não duplica nada (qualquer
  /// edição feita depois vence, porque tem updatedAt maior).
  /// Roda na criação e nas migrações: só insere o que falta e só preenche a
  /// seção de quem ainda não tem.
  Future<void> _seedCategories() async {
    for (final (slug, name, kind, icon, color, section) in _defaultCategories) {
      await customStatement(
        'INSERT OR IGNORE INTO categories (id, created_at, updated_at, name, kind, icon, color, section) '
        'VALUES (?, 0, 0, ?, ?, ?, ?, ?)',
        ['seed-cat-$slug', name, kind.name, icon, color, section?.name],
      );
      if (section != null) {
        await customStatement('UPDATE categories SET section = ? WHERE id = ? AND section IS NULL', [
          section.name,
          'seed-cat-$slug',
        ]);
      }
    }
  }

  // ---- Leituras (Streams: a tela se atualiza sozinha quando o banco muda) ----

  Stream<List<Account>> watchAccounts() =>
      (select(accounts)
            ..where((a) => a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm(expression: a.name)]))
          .watch();

  Stream<List<Category>> watchCategories() =>
      (select(categories)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .watch();

  Stream<List<Entry>> watchAllEntries() => (select(entries)..where((e) => e.deletedAt.isNull())).watch();

  /// Lançamentos de um mês ("AAAA-MM"), mais recentes primeiro.
  Stream<List<Entry>> watchMonthEntries(String month) =>
      (select(entries)
            ..where((e) => e.deletedAt.isNull() & e.date.like('$month-%'))
            ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.createdAt)]))
          .watch();

  // ---- Escritas ----

  Future<void> addAccount({
    required String name,
    required AccountType type,
    int initialBalance = 0,
    int? renewDay,
    int? renewAmount,
    int? closingDay,
    int? dueDay,
  }) {
    final t = now();
    return into(accounts).insert(
      AccountsCompanion.insert(
        id: newId(),
        createdAt: t,
        updatedAt: t,
        name: name,
        type: type,
        initialBalance: Value(initialBalance),
        renewDay: Value(renewDay),
        renewAmount: Value(renewAmount),
        closingDay: Value(closingDay),
        dueDay: Value(dueDay),
      ),
    );
  }

  Future<void> updateAccount(
    String id, {
    required String name,
    required AccountType type,
    required int initialBalance,
    int? renewDay,
    int? renewAmount,
    int? closingDay,
    int? dueDay,
  }) => (update(accounts)..where((a) => a.id.equals(id))).write(
    AccountsCompanion(
      name: Value(name),
      type: Value(type),
      initialBalance: Value(initialBalance),
      renewDay: Value(renewDay),
      renewAmount: Value(renewAmount),
      closingDay: Value(closingDay),
      dueDay: Value(dueDay),
      updatedAt: Value(now()),
    ),
  );

  Future<void> updateCategory(
    String id, {
    required String name,
    required String icon,
    required int color,
    CategorySection? section,
    String? project,
  }) => (update(categories)..where((c) => c.id.equals(id))).write(
    CategoriesCompanion(
      name: Value(name),
      icon: Value(icon),
      color: Value(color),
      section: Value(section),
      project: Value(project),
      updatedAt: Value(now()),
    ),
  );

  Future<void> setAccountArchived(String id, bool archived) => (update(
    accounts,
  )..where((a) => a.id.equals(id))).write(AccountsCompanion(archived: Value(archived), updatedAt: Value(now())));

  Future<void> addCategory({
    required String name,
    required CategoryKind kind,
    required String icon,
    required int color,
    CategorySection? section,
    String? project,
  }) {
    final t = now();
    return into(categories).insert(
      CategoriesCompanion.insert(
        id: newId(),
        createdAt: t,
        updatedAt: t,
        name: name,
        kind: kind,
        icon: icon,
        color: color,
        section: Value(section),
        project: Value(project),
      ),
    );
  }

  Future<Entry?> getEntry(String id) => (select(entries)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Cria (id == null) ou atualiza um lançamento. Devolve o id.
  /// [titheStatus]: só para receitas; `null` mantém o que já estava.
  Future<String> saveEntry({
    String? id,
    required EntryType type,
    required int amount,
    required String date,
    required String description,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required bool paid,
    TitheStatus? titheStatus,
    String? personId,
    String? envelopeId,
  }) async {
    final t = now();
    var data = EntriesCompanion(
      personId: Value(personId),
      // Ao editar, não apaga o envelope se o formulário não mandou.
      envelopeId: envelopeId == null && id != null ? const Value.absent() : Value(envelopeId),
      type: Value(type),
      amount: Value(amount),
      date: Value(date),
      description: Value(description),
      accountId: Value(accountId),
      toAccountId: Value(toAccountId),
      categoryId: Value(categoryId),
      paid: Value(paid),
      updatedAt: Value(t),
    );
    if (type != EntryType.receita) {
      data = data.copyWith(titheStatus: const Value(null));
    } else if (titheStatus != null) {
      data = data.copyWith(titheStatus: Value(titheStatus));
    }
    if (id != null) {
      await (update(entries)..where((e) => e.id.equals(id))).write(data);
      return id;
    }
    final newEntryId = newId();
    await into(entries).insert(data.copyWith(id: Value(newEntryId), createdAt: Value(t)));
    return newEntryId;
  }

  Future<void> setPaid(String id, bool paid) => (update(
    entries,
  )..where((e) => e.id.equals(id))).write(EntriesCompanion(paid: Value(paid), updatedAt: Value(now())));

  Future<void> markPaid(String id) => setPaid(id, true);

  /// Marca vários de uma vez (ex.: todas as compras de uma fatura).
  Future<void> setPaidAll(Iterable<String> ids, bool paid) => (update(
    entries,
  )..where((e) => e.id.isIn(ids))).write(EntriesCompanion(paid: Value(paid), updatedAt: Value(now())));

  Future<void> setTitheStatus(Iterable<String> ids, TitheStatus status) => (update(
    entries,
  )..where((e) => e.id.isIn(ids))).write(EntriesCompanion(titheStatus: Value(status), updatedAt: Value(now())));

  /// Lança o dízimo e a oferta e marca as [incomes] como "separado".
  /// Valores zerados não viram lançamento. Os lançamentos nascem como
  /// "a entregar" (não pagos): marque ✓ quando entregar na igreja.
  Future<void> separateTithe({
    required List<Entry> incomes,
    required int tithe,
    required int titheBp,
    required int offering,
    required int offeringBp,
  }) {
    final date = incomes.map((e) => e.date).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final accountId = incomes.first.accountId;
    return transaction(() async {
      final t = now();
      for (final (amount, bp, categoryId, label) in [
        (tithe, titheBp, dizimoCategoryId, 'Dízimo'),
        (offering, offeringBp, ofertaCategoryId, 'Oferta'),
      ]) {
        if (amount <= 0) continue;
        await into(entries).insert(
          EntriesCompanion.insert(
            id: newId(),
            createdAt: t,
            updatedAt: t,
            type: EntryType.despesa,
            amount: amount,
            date: date,
            description: Value(label),
            accountId: accountId,
            categoryId: Value(categoryId),
            paid: const Value(false),
            percentBp: Value(bp),
          ),
        );
      }
      await setTitheStatus(incomes.map((e) => e.id), TitheStatus.separado);
    });
  }

  // ---- Contas fixas ----

  Stream<List<Recurring>> watchRecurrings() =>
      (select(recurrings)
            ..where((r) => r.deletedAt.isNull())
            ..orderBy([(r) => OrderingTerm(expression: r.day)]))
          .watch();

  /// Cria a conta fixa e já lança o mês [startMonth]. Devolve o id do lançamento.
  Future<String> createRecurring({
    required EntryType type,
    required String description,
    required int amount,
    required bool variable,
    required int day,
    required String accountId,
    String? categoryId,
    String? personId,
    required String startMonth,
  }) async {
    final t = now();
    final id = newId();
    await into(recurrings).insert(
      RecurringsCompanion.insert(
        id: id,
        createdAt: t,
        updatedAt: t,
        type: type,
        description: description,
        amount: amount,
        variable: Value(variable),
        day: day.clamp(1, 28),
        accountId: accountId,
        categoryId: Value(categoryId),
        personId: Value(personId),
        startMonth: startMonth,
      ),
    );
    await ensureRecurringEntries(startMonth);
    return recurringEntryId(id, startMonth);
  }

  Future<void> updateRecurring(String id, {bool? active, bool? variable, int? amount, int? day, String? description}) =>
      (update(recurrings)..where((r) => r.id.equals(id))).write(
        RecurringsCompanion(
          description: description == null ? const Value.absent() : Value(description),
          active: active == null ? const Value.absent() : Value(active),
          variable: variable == null ? const Value.absent() : Value(variable),
          amount: amount == null ? const Value.absent() : Value(amount),
          day: day == null ? const Value.absent() : Value(day.clamp(1, 28)),
          updatedAt: Value(now()),
        ),
      );

  static String recurringEntryId(String recurringId, String month) => 'rec-$recurringId-$month';

  /// Lança as contas fixas do mês que ainda não foram lançadas. Pode chamar
  /// à vontade: o id fixo por mês impede duplicar, e um lançamento apagado
  /// continua apagado (não volta).
  Future<void> ensureRecurringEntries(String month) async {
    final list = await (select(
      recurrings,
    )..where((r) => r.deletedAt.isNull() & r.active.equals(true) & r.startMonth.isSmallerOrEqualValue(month))).get();
    if (list.isEmpty) return;
    await transaction(() async {
      for (final r in list) {
        var amount = r.amount;
        if (r.variable) {
          // Valor que muda (luz, água): usa o do último mês lançado.
          final last =
              await (select(entries)
                    ..where((e) => e.recurringId.equals(r.id) & e.date.isSmallerThanValue('$month-01'))
                    ..orderBy([(e) => OrderingTerm.desc(e.date)])
                    ..limit(1))
                  .getSingleOrNull();
          amount = last?.amount ?? r.amount;
        }
        final t = now();
        await into(entries).insert(
          EntriesCompanion.insert(
            id: recurringEntryId(r.id, month),
            createdAt: t,
            updatedAt: t,
            type: r.type,
            amount: amount,
            date: '$month-${r.day.toString().padLeft(2, '0')}',
            description: Value(r.description),
            accountId: r.accountId,
            categoryId: Value(r.categoryId),
            personId: Value(r.personId),
            paid: const Value(false),
            recurringId: Value(r.id),
            titheStatus: Value(r.type == EntryType.receita ? TitheStatus.pendente : null),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  // ---- Parcelas ----

  /// Lança uma compra parcelada: uma parcela por mês a partir de [date].
  /// [installment] é o valor de cada parcela. Devolve o id da primeira.
  Future<String> saveInstallments({
    required int installment,
    required int count,
    required String date,
    required String description,
    required String accountId,
    String? categoryId,
    String? personId,
    required bool firstPaid,
  }) async {
    final group = newId();
    final [y, m, d] = date.split('-').map(int.parse).toList();
    String? firstId;
    await transaction(() async {
      for (var i = 1; i <= count; i++) {
        final month = DateTime(y, m + i - 1);
        final lastDay = DateTime(month.year, month.month + 1, 0).day;
        final day = d > lastDay ? lastDay : d;
        final t = now();
        final id = newId();
        firstId ??= id;
        await into(entries).insert(
          EntriesCompanion.insert(
            id: id,
            createdAt: t,
            updatedAt: t,
            type: EntryType.despesa,
            amount: installment,
            date: '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
            description: Value(description),
            accountId: accountId,
            categoryId: Value(categoryId),
            personId: Value(personId),
            paid: Value(i == 1 && firstPaid),
            installmentGroup: Value(group),
            installmentIndex: Value(i),
            installmentCount: Value(count),
          ),
        );
      }
    });
    return firstId!;
  }

  // ---- Compras (calculadora) ----

  Stream<List<ShopItem>> watchShopItems() => (select(shopItems)..where((t) => t.deletedAt.isNull())).watch();

  /// Guarda os itens de uma compra lançada.
  Future<void> recordShopping({
    required String entryId,
    required String date,
    required List<({String name, int price, int qty})> items,
  }) => transaction(() async {
    final t = now();
    for (final i in items) {
      await into(shopItems).insert(
        ShopItemsCompanion.insert(
          id: newId(),
          createdAt: t,
          updatedAt: t,
          name: Value(i.name.trim()),
          price: i.price,
          qty: Value(i.qty),
          date: date,
          entryId: Value(entryId),
        ),
      );
    }
  });

  // ---- Lista de compras compartilhada ----

  Stream<List<PlanItem>> watchPlan() =>
      (select(planItems)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .watch();

  /// Põe itens na lista (quem já estava continua).
  Future<void> addToPlan(Map<String, String> byKey) => transaction(() async {
    final t = now();
    for (final MapEntry(:key, :value) in byKey.entries) {
      await into(planItems).insertOnConflictUpdate(
        PlanItemsCompanion.insert(
          id: 'plan-$key',
          createdAt: t,
          updatedAt: t,
          name: value.trim(),
          deletedAt: const Value(null), // volta, se já tinha sido tirado
        ),
      );
    }
  });

  /// Tira itens da lista (comprados, ou desmarcados).
  Future<void> removeFromPlan(Iterable<String> keys) => transaction(() async {
    for (final k in keys) {
      await softDelete(planItems, 'plan-$k');
    }
  });

  // ---- Orçamento por categoria ----

  Stream<List<Budget>> watchBudgets() => (select(budgets)..where((t) => t.deletedAt.isNull())).watch();

  /// Limite mensal de uma categoria (vale para todos os meses). null = sem limite.
  Future<void> setBudget(String categoryId, int? limit) async {
    final id = 'budget-$categoryId';
    if (limit == null || limit <= 0) return softDelete(budgets, id);
    final t = now();
    await into(budgets).insertOnConflictUpdate(
      BudgetsCompanion.insert(
        id: id,
        createdAt: t,
        updatedAt: t,
        categoryId: categoryId,
        month: '',
        limitAmount: limit,
        deletedAt: const Value(null),
      ),
    );
  }

  // ---- Guardado (envelopes) ----

  Stream<List<Envelope>> watchEnvelopes() =>
      (select(envelopes)
            ..where((e) => e.deletedAt.isNull())
            ..orderBy([(e) => OrderingTerm(expression: e.createdAt)]))
          .watch();

  Future<String> addEnvelope({required String name, String icon = '🏺', int initialBalance = 0, int? goal}) async {
    final t = now();
    final id = newId();
    await into(envelopes).insert(
      EnvelopesCompanion.insert(
        id: id,
        createdAt: t,
        updatedAt: t,
        name: name,
        icon: Value(icon),
        initialBalance: Value(initialBalance),
        goal: Value(goal),
      ),
    );
    return id;
  }

  Future<void> updateEnvelope(
    String id, {
    required String name,
    required String icon,
    required int initialBalance,
    int? goal,
    bool? archived,
  }) => (update(envelopes)..where((e) => e.id.equals(id))).write(
    EnvelopesCompanion(
      name: Value(name),
      icon: Value(icon),
      initialBalance: Value(initialBalance),
      goal: Value(goal),
      archived: archived == null ? const Value.absent() : Value(archived),
      updatedAt: Value(now()),
    ),
  );

  /// Guardar (sai do Disponível) ou tirar (volta para o Disponível, sem dízimo:
  /// o dízimo já foi separado quando o dinheiro entrou).
  Future<String> moveEnvelope({
    required Envelope envelope,
    required int amount,
    required bool save,
    required String date,
    required String accountId,
  }) => saveEntry(
    type: save ? EntryType.despesa : EntryType.receita,
    amount: amount,
    date: date,
    description: save ? 'Guardado em ${envelope.name}' : 'Tirado de ${envelope.name}',
    accountId: accountId,
    categoryId: save ? guardadoCategoryId : null,
    paid: true,
    titheStatus: save ? null : TitheStatus.isento,
    envelopeId: envelope.id,
  );

  // ---- A receber ----

  Stream<List<Receivable>> watchReceivables() =>
      (select(receivables)
            ..where((r) => r.deletedAt.isNull())
            ..orderBy([(r) => OrderingTerm(expression: r.dueDate)]))
          .watch();

  Future<void> addReceivable({required String description, required int amount, String? dueDate}) {
    final t = now();
    return into(receivables).insert(
      ReceivablesCompanion.insert(
        id: newId(),
        createdAt: t,
        updatedAt: t,
        description: description,
        amount: amount,
        dueDate: Value(dueDate),
      ),
    );
  }

  /// O dinheiro voltou: vira uma entrada SEM dízimo (não é dinheiro novo).
  Future<void> receive(Receivable r, {required String accountId, required String date}) => transaction(() async {
    final id = await saveEntry(
      type: EntryType.receita,
      amount: r.amount,
      date: date,
      description: r.description,
      accountId: accountId,
      paid: true,
      titheStatus: TitheStatus.isento,
    );
    await (update(receivables)..where((x) => x.id.equals(r.id))).write(
      ReceivablesCompanion(receivedEntryId: Value(id), updatedAt: Value(now())),
    );
  });

  // ---- Importação de extrato ----

  /// Grava as linhas importadas. Cada linha tem id fixo (conta + chave do
  /// extrato): importar o mesmo arquivo de novo não duplica nada.
  /// Devolve quantas eram novas.
  Future<int> importLines({
    required List<({String date, String description, int amount, bool income, String key})> lines,
    required String accountId,
    required bool card,
  }) => transaction(() async {
    var added = 0;
    final t = now();
    for (final l in lines) {
      final id = 'imp-$accountId-${base64Url.encode(utf8.encode(l.key))}';
      final inserted = await into(entries).insert(
        EntriesCompanion.insert(
          id: id,
          createdAt: t,
          updatedAt: t,
          type: l.income ? EntryType.receita : EntryType.despesa,
          amount: l.amount,
          date: l.date,
          description: Value(l.description),
          accountId: accountId,
          // Do extrato da conta, já aconteceu; no cartão, fica para a fatura.
          paid: Value(!card),
          titheStatus: Value(l.income ? TitheStatus.pendente : null),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      if (inserted > 0) added++;
    }
    return added;
  });

  // ---- Pessoas ----

  Stream<List<Person>> watchPeople() =>
      (select(people)
            ..where((p) => p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm(expression: p.id)]))
          .watch();

  Future<void> renamePerson(String id, String name) => (update(
    people,
  )..where((p) => p.id.equals(id))).write(PeopleCompanion(name: Value(name), updatedAt: Value(now())));

  // ---- Preferências ----

  Stream<Map<String, String>> watchSettings() =>
      select(settings).watch().map((rows) => {for (final r in rows) r.key: r.value});

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(Setting(key: key, value: value));

  /// Exclusão lógica: marca `deletedAt` (funciona em qualquer tabela com SyncColumns).
  /// Desfaz uma exclusão (o "Desfazer" do aviso).
  Future<void> restore(TableInfo<Table, dynamic> table, String id) => customUpdate(
    'UPDATE ${table.actualTableName} SET deleted_at = NULL, updated_at = ? WHERE id = ?',
    variables: [Variable.withInt(now()), Variable.withString(id)],
    updates: {table},
  );

  Future<void> softDelete(TableInfo<Table, dynamic> table, String id) {
    final t = now();
    return customUpdate(
      'UPDATE ${table.actualTableName} SET deleted_at = ?, updated_at = ? WHERE id = ?',
      variables: [Variable.withInt(t), Variable.withInt(t), Variable.withString(id)],
      updates: {table},
    );
  }
}

const _defaultCategories = <(String, String, CategoryKind, String, int, CategorySection?)>[
  // Primícias: separadas pelo botão "Separar dízimo e oferta"
  ('dizimo', 'Dízimo', CategoryKind.despesa, '⛪', 0xFF7C5C2E, CategorySection.primicias),
  ('oferta', 'Oferta', CategoryKind.despesa, '🕊️', 0xFF9A7B4F, CategorySection.primicias),
  // Cartão
  ('fatura', 'Fatura do cartão', CategoryKind.despesa, '💳', 0xFF4F46E5, CategorySection.cartao),
  // Casa
  ('mercado', 'Mercado', CategoryKind.despesa, '🛒', 0xFF16A34A, CategorySection.casa),
  ('moradia', 'Moradia', CategoryKind.despesa, '🏠', 0xFF2563EB, CategorySection.casa),
  ('contas', 'Contas da casa', CategoryKind.despesa, '💡', 0xFFCA8A04, CategorySection.casa),
  // Pessoal
  ('transporte', 'Transporte', CategoryKind.despesa, '🚗', 0xFF9333EA, CategorySection.pessoal),
  ('saude', 'Saúde', CategoryKind.despesa, '🩺', 0xFFDC2626, CategorySection.pessoal),
  ('lazer', 'Lazer', CategoryKind.despesa, '🎉', 0xFFDB2777, CategorySection.pessoal),
  ('restaurantes', 'Restaurantes', CategoryKind.despesa, '🍔', 0xFFEA580C, CategorySection.pessoal),
  ('educacao', 'Educação', CategoryKind.despesa, '📚', 0xFF0891B2, CategorySection.pessoal),
  ('assinaturas', 'Assinaturas', CategoryKind.despesa, '📺', 0xFF4F46E5, CategorySection.pessoal),
  ('outros', 'Outros', CategoryKind.despesa, '📦', 0xFF64748B, CategorySection.outros),
  ('ingredientes', 'Ingredientes do alfajor', CategoryKind.despesa, '🧈', 0xFFB45309, CategorySection.outros),
  // Guardar dinheiro num envelope (sai do Disponível, mas não é gasto de verdade)
  ('guardado', 'Guardado', CategoryKind.despesa, '🏺', 0xFF0F766E, CategorySection.guardado),
  // Entradas (todas geram dízimo e oferta, a não ser que a entrada seja marcada como isenta)
  ('salario', 'Salário', CategoryKind.receita, '💼', 0xFF059669, null),
  ('extra', 'Extra', CategoryKind.receita, '✨', 0xFF0D9488, null),
  ('alfajor', 'Alfajor', CategoryKind.receita, '🍪', 0xFFB45309, null),
  ('corridas', 'Corridas e entregas', CategoryKind.receita, '🛵', 0xFF0369A1, null),
  ('rendimentos', 'Rendimentos', CategoryKind.receita, '📈', 0xFF65A30D, null),
];
