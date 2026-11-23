// Aba Mercado: o vale, a lista de compras e a calculadora num lugar só.
// Em casa: vai digitando a lista (Enter, próximo). No mercado: toque no item,
// digite o preço, Enter. O total fica sempre embaixo, com o botão de lançar.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../data/prefs.dart';
import '../../domain/shopping.dart';
import '../../domain/vale.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';
import '../widgets/entry_form.dart';
import '../widgets/shopping_report.dart';

/// Lança o carrinho (no vale, se houver), guarda os itens no histórico e
/// recomeça lista e carrinho.
Future<void> launchCart(BuildContext context) async {
  final scope = AppScope.of(context);
  final cart = scope.prefs.shopping;
  if (cart.isEmpty) return;
  final total = cart.fold(0, (s, i) => s + i.total);
  final vale = scope.data.accounts.where((a) => a.type == AccountType.vale && !a.archived).firstOrNull;
  final savedId = await showEntryForm(context, amount: total, accountId: vale?.id, description: 'Compras', paid: true);
  if (savedId == null) return;
  final entry = await scope.db.getEntry(savedId);
  await scope.db.recordShopping(
    entryId: savedId,
    date: entry?.date ?? today(),
    items: [for (final i in cart) (name: i.name, price: i.price, qty: i.qty)],
  );
  await scope.db.clearPlan(); // a lista era desta ida
  await scope.prefs.setShopping(const []);
}

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final _listInput = TextEditingController();
  final _listFocus = FocusNode();
  final _price = TextEditingController();
  final _priceFocus = FocusNode();
  final _name = TextEditingController();

  @override
  void dispose() {
    _listInput.dispose();
    _listFocus.dispose();
    _price.dispose();
    _priceFocus.dispose();
    _name.dispose();
    super.dispose();
  }

  // ---- Lista ----

  /// Enter no campo: põe na lista e já fica pronto para o próximo.
  Future<void> _addToList() async {
    final name = _listInput.text.trim();
    if (name.isEmpty) return;
    _listInput.clear();
    _listFocus.requestFocus();
    await AppScope.of(context).db.addToPlan({normalizeItem(name): name});
  }

  Future<void> _renameListItem(String name) async {
    final c = TextEditingController(text: name);
    final fixed = await showLcDialog<String>(
      context,
      builder: (d) => LcDialogBody(
        title: 'Corrigir item',
        content: LcField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(d, v.trim())),
        actions: [
          LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(d)),
          LcButton('Salvar', onPressed: () => Navigator.pop(d, c.text.trim())),
        ],
      ),
    );
    if (fixed == null || fixed.isEmpty || fixed == name || !mounted) return;
    await AppScope.of(context).db.renamePlanItem(normalizeItem(name), normalizeItem(fixed), fixed);
  }

  // ---- Carrinho ----

  /// Pede preço e quantidade de um item (do zero, da lista ou corrigindo).
  Future<CartItem?> _askPrice({required String name, int? price, int qty = 1, bool editName = false}) {
    final priceC = TextEditingController(text: price == null ? '' : centsToInput(price));
    final nameC = TextEditingController(text: name);
    var q = qty;
    return showLcDialog<CartItem>(
      context,
      width: 380,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) {
          void done() {
            final cents = parseBRL(priceC.text);
            if (cents == null || cents <= 0) return;
            Navigator.pop(d, CartItem(price: cents, qty: q, name: editName ? nameC.text.trim() : name));
          }

          final p = Paper.of(d);
          return LcDialogBody(
            title: editName ? 'Corrigir' : (name.isEmpty ? 'Anotar' : name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (editName) ...[LcField(label: 'O que é', controller: nameC), const SizedBox(height: 12)],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LcField(
                        label: 'Preço (cada)',
                        controller: priceC,
                        autofocus: true,
                        money: true,
                        prefix: r'R$ ',
                        hint: '0,00',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onSubmitted: (_) => done(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _QtyStepper(qty: q, onChanged: (v) => setLocal(() => q = v), p: p),
                  ],
                ),
              ],
            ),
            actions: [
              LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(d)),
              LcButton(editName ? 'Salvar' : 'Pôr no carrinho', icon: LucideIcons.check, onPressed: done),
            ],
          );
        },
      ),
    );
  }

  /// Toque num item da lista: preço (sugere o último) e vai para o carrinho.
  Future<void> _pick(String name, ProductStats? st) async {
    final item = await _askPrice(name: name, price: st?.lastPrice);
    if (item == null || !mounted) return;
    final prefs = AppScope.of(context).prefs;
    await prefs.setShopping([item, ...prefs.shopping]);
  }

  /// Anotar algo que não estava na lista (preço + nome opcional, sem janela).
  Future<void> _addLoose() async {
    final cents = parseBRL(_price.text);
    if (cents == null || cents <= 0) return;
    final prefs = AppScope.of(context).prefs;
    await prefs.setShopping([CartItem(price: cents, name: _name.text.trim()), ...prefs.shopping]);
    _price.clear();
    _name.clear();
    _priceFocus.requestFocus();
  }

  Future<void> _editCart(Prefs prefs, int index) async {
    final items = [...prefs.shopping];
    final it = items[index];
    final fixed = await _askPrice(name: it.name, price: it.price, qty: it.qty, editName: true);
    if (fixed == null) return;
    items[index] = fixed;
    await prefs.setShopping(items);
  }

  Future<void> _clearCart(Prefs prefs) async {
    if (await lcConfirm(
      context,
      'Tira todos os itens do carrinho.',
      confirm: 'Esvaziar',
      title: 'Esvaziar o carrinho?',
    )) {
      await prefs.setShopping(const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.data, scope.prefs]),
      builder: (context, _) {
        final data = scope.data;
        final now = DateTime.now();
        final vale = data.accounts.where((a) => a.type == AccountType.vale && !a.archived).firstOrNull;
        final st = vale == null ? null : valeStatus(vale, data.entries, now);
        final cart = scope.prefs.shopping;
        final total = cart.fold(0, (s, i) => s + i.total);
        final count = cart.fold(0, (s, i) => s + i.qty);
        final stats = data.memo(#productStats, () => productStats(data.shopItems, data.entryIds));
        final byKey = {for (final s in stats) s.key: s};
        final inCart = {for (final i in cart) normalizeItem(i.name)};
        final plan = [for (final i in data.plan) i.name];
        final planKeys = {for (final n in plan) normalizeItem(n)};
        final typed = normalizeItem(_listInput.text);
        // Sugestões: enquanto digita, o que combina; senão, o que "está na hora".
        final ideas = [
          for (final s in typed.length >= 2 ? stats : suggestedList(stats, now))
            if (!planKeys.contains(s.key) && (typed.length >= 2 ? s.key.contains(typed) : s.dueOn(now))) s,
        ].take(8).toList();
        final period = st == null
            ? const <Entry>[]
            : ([
                for (final e in data.entries)
                  if (e.accountId == vale!.id &&
                      e.deletedAt == null &&
                      e.date.compareTo(toIsoDate(st.periodStart)) >= 0 &&
                      e.date.compareTo(toIsoDate(st.nextRenewal)) < 0)
                    e,
              ]..sort((a, b) => b.date.compareTo(a.date)));
        final days = st?.daysUntilRenewal(now);

        final body = ListView(
          padding: EdgeInsets.fromLTRB(20, 24, 20, cart.isEmpty ? 40 : 120),
          children: [
            Row(
              children: [
                Expanded(child: Text('Mercado', style: Theme.of(context).textTheme.headlineSmall)),
                LcButton(
                  'Relatório',
                  icon: LucideIcons.chartPie,
                  small: true,
                  kind: LcButtonKind.ghost,
                  onPressed: () => showShoppingReport(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ---- Vale ----
            if (vale != null && st != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(color: p.sticky, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vale.name,
                            style: TextStyle(fontSize: 13, color: p.pencil, fontWeight: FontWeight.w600),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatBRL(st.left),
                              style: p.mono(28, weight: FontWeight.w700, color: st.left < 0 ? p.redInk : null),
                            ),
                          ),
                          Text(
                            'renova dia ${st.nextRenewal.day} '
                            '(${days == 0
                                ? 'hoje'
                                : days == 1
                                ? 'amanhã'
                                : 'em $days dias'}) · '
                            'gasto no período ${formatBRL(st.spent)}',
                            style: TextStyle(fontSize: 12.5, color: p.pencil),
                          ),
                        ],
                      ),
                    ),
                    LcIconButton(
                      LucideIcons.plus,
                      tooltip: 'Lançar algo no vale',
                      onPressed: () => showEntryForm(context, accountId: vale.id, paid: true),
                    ),
                  ],
                ),
              ),
            // ---- Lista ----
            LcGroup(
              title: 'LISTA',
              trailing: plan.isEmpty
                  ? null
                  : Text(
                      '${plan.where((n) => inCart.contains(normalizeItem(n))).length} de ${plan.length} no carrinho',
                      style: TextStyle(fontSize: 12, color: p.pencil),
                    ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _listInput,
                          focusNode: _listFocus,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _addToList(),
                          cursorColor: p.accent,
                          style: TextStyle(fontSize: 14.5, color: p.ink),
                          decoration: lcInputDecoration(context, hint: 'Pôr na lista… (Enter adiciona)'),
                        ),
                      ),
                      LcIconButton(LucideIcons.plus, tooltip: 'Adicionar', onPressed: _addToList),
                    ],
                  ),
                ),
                if (ideas.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in ideas)
                          LcChip(
                            s.name,
                            selected: false,
                            leading: Icon(LucideIcons.plus, size: 13, color: p.pencil),
                            onTap: () {
                              _listInput.clear();
                              setState(() {});
                              scope.db.addToPlan({s.key: s.name});
                            },
                          ),
                      ],
                    ),
                  ),
                if (plan.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text(
                      'Em casa, vá pondo o que falta. No mercado, toque no item, digite o preço e Enter.',
                      style: TextStyle(fontSize: 12.5, color: p.pencil, height: 1.35),
                    ),
                  ),
                for (final n in plan)
                  _ListRow(
                    name: n,
                    lastPrice: byKey[normalizeItem(n)]?.lastPrice,
                    done: inCart.contains(normalizeItem(n)),
                    onTap: () => _pick(n, byKey[normalizeItem(n)]),
                    onEdit: () => _renameListItem(n),
                    onRemove: () => scope.db.removeFromPlan([normalizeItem(n)]),
                  ),
              ],
            ),
            // ---- Carrinho ----
            LcGroup(
              title: 'CARRINHO',
              trailing: cart.isEmpty
                  ? null
                  : LcButton(
                      'Esvaziar',
                      small: true,
                      kind: LcButtonKind.ghost,
                      onPressed: () => _clearCart(scope.prefs),
                    ),
              children: [
                // Avulso: o que não estava na lista, sem abrir janela.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: LcField(
                          controller: _price,
                          focusNode: _priceFocus,
                          prefix: r'R$ ',
                          hint: '0,00',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onSubmitted: (_) => _addLoose(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LcField(controller: _name, hint: 'o quê (opcional)', onSubmitted: (_) => _addLoose()),
                      ),
                      LcIconButton(LucideIcons.plus, tooltip: 'Anotar', onPressed: _addLoose),
                    ],
                  ),
                ),
                if (cart.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text(
                      'Nada no carrinho. Toque num item da lista ou anote aqui em cima.',
                      style: TextStyle(fontSize: 12.5, color: p.pencil),
                    ),
                  ),
                for (var i = 0; i < cart.length; i++)
                  LcRow(
                    title: cart[i].name.isEmpty ? 'Item ${cart.length - i}' : cart[i].name,
                    subtitle: cart[i].qty > 1 ? '${cart[i].qty} × ${formatBRL(cart[i].price)}' : null,
                    onTap: () => _editCart(scope.prefs, i),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatBRL(cart[i].total), style: p.mono(14, weight: FontWeight.w600)),
                        LcIconButton(
                          LucideIcons.x,
                          size: 15,
                          tooltip: 'Tirar',
                          color: p.pencil,
                          onPressed: () => scope.prefs.setShopping([...cart]..removeAt(i)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // ---- Compras no vale ----
            if (vale != null && period.isNotEmpty)
              LcGroup(
                title: 'NO VALE, DESDE A ÚLTIMA RENOVAÇÃO',
                children: [
                  for (final e in period)
                    LcRow(
                      title: data.labelOf(e),
                      subtitle: formatDate(e.date),
                      onTap: () => showEntryForm(context, editing: e),
                      trailing: Text(
                        '${e.type == EntryType.receita ? '+' : '−'} ${formatBRL(e.amount)}',
                        style: p.mono(
                          13.5,
                          weight: FontWeight.w600,
                          color: e.type == EntryType.receita ? p.greenInk : p.ink,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: body),
              ),
              // Barra do carrinho: total sempre à vista e o botão de lançar.
              if (cart.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: _CartBar(
                        total: total,
                        count: count,
                        left: st?.left,
                        onLaunch: () => launchCart(context),
                        hasVale: vale != null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.name,
    required this.lastPrice,
    required this.done,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });
  final String name;
  final int? lastPrice;
  final bool done;
  final VoidCallback onTap, onEdit, onRemove;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: hairline(p))),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Row(
                    children: [
                      Icon(
                        done ? LucideIcons.circleCheck : LucideIcons.circle,
                        size: 18,
                        color: done ? p.greenInk : p.pencil,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: done ? p.pencil : p.ink,
                            decoration: done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (lastPrice != null)
                        Text('~${formatBRL(lastPrice!)}', style: TextStyle(fontSize: 12, color: p.pencil)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          LcIconButton(LucideIcons.pencil, size: 14, tooltip: 'Corrigir', color: p.pencil, onPressed: onEdit),
          LcIconButton(LucideIcons.x, size: 15, tooltip: 'Tirar da lista', color: p.pencil, onPressed: onRemove),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.total,
    required this.count,
    required this.left,
    required this.onLaunch,
    required this.hasVale,
  });
  final int total, count;
  final int? left;
  final bool hasVale;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final over = left != null && total > left!;
    return DecoratedBox(
      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(14), boxShadow: lcFloatShadow),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatBRL(total),
                    style: p.mono(20, weight: FontWeight.w700, color: p.paper),
                  ),
                  Text(
                    [
                      '$count ${count == 1 ? 'item' : 'itens'}',
                      if (left != null)
                        over ? 'passa ${formatBRL(total - left!)} do vale' : 'fica ${formatBRL(left! - total)} no vale',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: over ? const Color(0xFFFFB4A8) : p.paper.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: p.paper,
                foregroundColor: p.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: onLaunch,
              icon: const Icon(LucideIcons.check, size: 16),
              label: Text(hasVale ? 'Lançar no vale' : 'Lançar', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged, required this.p});
  final int qty;
  final ValueChanged<int> onChanged;
  final Paper p;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const LcLabel('Qtd.'),
      Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: hairline(p)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            LcIconButton(LucideIcons.minus, size: 16, onPressed: qty > 1 ? () => onChanged(qty - 1) : null),
            SizedBox(
              width: 24,
              child: Text('$qty', textAlign: TextAlign.center, style: p.mono(16)),
            ),
            LcIconButton(LucideIcons.plus, size: 16, onPressed: () => onChanged(qty + 1)),
          ],
        ),
      ),
    ],
  );
}
