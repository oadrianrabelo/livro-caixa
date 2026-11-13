// Calculadora de compras: no mercado, vai anotando o preço de cada coisa e
// no fim tem o total exato para passar no vale (ou lançar como gasto).
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
import 'entry_form.dart';
import 'shopping_report.dart';

Future<void> showShoppingCalc(BuildContext context) async {
  final result = await showLcSheet<int>(context, builder: (_) => const _ShoppingCalc());
  if (result == null || !context.mounted) return;
  // Lançar o total: no vale, se houver um.
  final scope = AppScope.of(context);
  final vale = scope.data.accounts.where((a) => a.type == AccountType.vale && !a.archived).firstOrNull;
  final cart = scope.prefs.shopping;
  final savedId = await showEntryForm(context, amount: result, accountId: vale?.id, description: 'Compras', paid: true);
  if (savedId == null) return;
  // Guarda os itens no histórico (relatórios e sugestões) e limpa a calculadora.
  final entry = await scope.db.getEntry(savedId);
  await scope.db.recordShopping(
    entryId: savedId,
    date: entry?.date ?? today(),
    items: [for (final i in cart) (name: i.name, price: i.price, qty: i.qty)],
  );
  final bought = {for (final i in cart) normalizeItem(i.name)};
  await scope.db.removeFromPlan(bought.where((k) => k.isNotEmpty)); // comprado: sai da lista da casa
  await scope.prefs.setShopping(const []);
}

class _ShoppingCalc extends StatefulWidget {
  const _ShoppingCalc();

  @override
  State<_ShoppingCalc> createState() => _ShoppingCalcState();
}

class _ShoppingCalcState extends State<_ShoppingCalc> {
  final _price = TextEditingController();
  final _name = TextEditingController();
  final _priceFocus = FocusNode();
  int _qty = 1;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    _name.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  Future<void> _add(Prefs prefs) async {
    final cents = parseBRL(_price.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Digite o preço.');
      return;
    }
    final item = CartItem(price: cents, qty: _qty, name: _name.text.trim());
    final items = [...prefs.shopping];
    final at = _editing;
    if (at != null && at < items.length) {
      items[at] = item; // corrigindo um item já anotado
    } else {
      items.insert(0, item);
    }
    await prefs.setShopping(items);
    _price.clear();
    _name.clear();
    setState(() {
      _qty = 1;
      _error = null;
      _editing = null;
    });
    _priceFocus.requestFocus(); // pronto para o próximo preço
  }

  /// Preenche com um item do histórico (nome e último preço).
  void _fill(ProductStats s) {
    _name.text = s.name;
    if (parseBRL(_price.text) == null) _price.text = centsToInput(s.lastPrice);
    setState(() => _error = null);
    _priceFocus.requestFocus();
    _price.selection = TextSelection(baseOffset: 0, extentOffset: _price.text.length);
  }

  int? _editing; // posição do item que está sendo corrigido

  /// Toque num item anotado: volta para os campos, para corrigir preço, nome ou quantidade.
  void _edit(CartItem item, int index) {
    _price.text = centsToInput(item.price);
    _name.text = item.name;
    setState(() {
      _qty = item.qty;
      _editing = index;
      _error = null;
    });
    _priceFocus.requestFocus();
  }

  /// Põe um item na lista da casa (aparece nos dois celulares).
  Future<void> _addToPlan() async {
    final controller = TextEditingController();
    final name = await showLcDialog<String>(
      context,
      builder: (c) => LcDialogBody(
        title: 'Pôr na lista de compras',
        content: LcField(
          controller: controller,
          autofocus: true,
          hint: 'Ex.: sabão em pó',
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
        actions: [
          LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(c)),
          LcButton('Adicionar', onPressed: () => Navigator.pop(c, controller.text.trim())),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await AppScope.of(context).db.addToPlan({normalizeItem(name): name});
  }

  Future<void> _remove(Prefs prefs, int index) async {
    final items = [...prefs.shopping]..removeAt(index);
    await prefs.setShopping(items);
    if (_editing != null) setState(() => _editing = null);
  }

  Future<void> _clear(Prefs prefs) async {
    if (prefs.shopping.isEmpty) return;
    if (!await lcConfirm(context, 'Apaga todos os itens anotados.', confirm: 'Limpar', title: 'Limpar a lista?')) {
      return;
    }
    await prefs.setShopping(const []);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.prefs, scope.data]),
      builder: (context, _) {
        final items = scope.prefs.shopping;
        final total = items.fold(0, (sum, i) => sum + i.total);
        final count = items.fold(0, (sum, i) => sum + i.qty);
        final vale = scope.data.accounts.where((a) => a.type == AccountType.vale && !a.archived).firstOrNull;
        final left = vale == null ? null : valeStatus(vale, scope.data.entries, DateTime.now()).left;
        final data = scope.data;
        final stats = data.memo(#productStats, () => productStats(data.shopItems, data.entryIds));
        final byKey = {for (final s in stats) s.key: s};
        final inCart = {for (final i in items) normalizeItem(i.name)};
        final plan = [for (final i in data.plan) i.name]; // lista da casa (sincroniza)
        final query = normalizeItem(_name.text);
        final suggestions = query.length < 2
            ? const <ProductStats>[]
            : stats.where((s) => s.key.contains(query) && s.key != query).take(4).toList();
        Widget chip(String label, VoidCallback onTap, {bool done = false}) => LcChip(
          label,
          selected: false,
          onTap: onTap,
          leading: done ? Icon(LucideIcons.check, size: 13, color: p.greenInk) : null,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calculadora de compras',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink, letterSpacing: -0.3),
                    ),
                  ),
                  LcButton(
                    'Relatório',
                    icon: LucideIcons.chartPie,
                    small: true,
                    kind: LcButtonKind.ghost,
                    onPressed: () => showShoppingReport(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Total grande, como no visor.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: p.sticky, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      count == 0 ? 'Nada anotado ainda' : '$count ${count == 1 ? 'item' : 'itens'}',
                      style: TextStyle(fontSize: 12.5, color: p.pencil),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(formatBRL(total), style: p.mono(34, weight: FontWeight.w700)),
                    ),
                    if (left != null)
                      Text(
                        total <= left
                            ? 'No vale: restam ${formatBRL(left)} · sobra ${formatBRL(left - total)}'
                            : 'Passa ${formatBRL(total - left)} do que resta no vale (${formatBRL(left)})',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: total <= left ? p.greenInk : p.redInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              ...[
                const SizedBox(height: 12),
                const LcLabel('Lista da casa (para pegar)'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final n in plan)
                      chip(
                        byKey[normalizeItem(n)] == null ? n : '$n · ${formatBRL(byKey[normalizeItem(n)]!.lastPrice)}',
                        () {
                          final s = byKey[normalizeItem(n)];
                          s != null ? _fill(s) : setState(() => _name.text = n);
                        },
                        done: inCart.contains(normalizeItem(n)),
                      ),
                    LcChip(
                      'Item',
                      selected: false,
                      onTap: _addToPlan,
                      leading: Icon(LucideIcons.plus, size: 13, color: p.pencil),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: LcField(
                      label: 'Preço',
                      controller: _price,
                      focusNode: _priceFocus,
                      autofocus: true,
                      money: true,
                      prefix: r'R$ ',
                      hint: '0,00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) => _add(scope.prefs),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Quantidade: − 1 +
                  Column(
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
                            LcIconButton(
                              LucideIcons.minus,
                              size: 16,
                              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                            ),
                            SizedBox(
                              width: 26,
                              child: Text('$_qty', textAlign: TextAlign.center, style: p.mono(16)),
                            ),
                            LcIconButton(LucideIcons.plus, size: 16, onPressed: () => setState(() => _qty++)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LcField(
                label: 'O que é (opcional)',
                controller: _name,
                hint: 'Ex.: arroz',
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _add(scope.prefs),
              ),
              // Já comprou antes? Toque para usar o nome e o último preço.
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final st in suggestions) chip('${st.name} · ${formatBRL(st.lastPrice)}', () => _fill(st)),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(fontSize: 12.5, color: p.redInk)),
              ],
              const SizedBox(height: 12),
              LcButton(
                _editing == null ? 'Anotar' : 'Salvar correção',
                icon: _editing == null ? LucideIcons.plus : LucideIcons.check,
                onPressed: () => _add(scope.prefs),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (var i = 0; i < items.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: hairline(p))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _edit(items[i], i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                [
                                  if (items[i].name.isNotEmpty) items[i].name,
                                  if (items[i].qty > 1) '${items[i].qty} × ${formatBRL(items[i].price)}',
                                  if (items[i].name.isEmpty && items[i].qty == 1) 'Item ${items.length - i}',
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: p.ink,
                                  fontWeight: _editing == i ? FontWeight.w700 : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        Text(formatBRL(items[i].total), style: p.mono(14)),
                        LcIconButton(
                          LucideIcons.x,
                          size: 15,
                          tooltip: 'Tirar',
                          color: p.pencil,
                          onPressed: () => _remove(scope.prefs, i),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    LcButton(
                      'Limpar',
                      icon: LucideIcons.trash2,
                      kind: LcButtonKind.ghost,
                      onPressed: () => _clear(scope.prefs),
                    ),
                    const Spacer(),
                    LcButton(
                      vale != null ? 'Lançar no vale' : 'Lançar gasto',
                      icon: LucideIcons.check,
                      onPressed: () => Navigator.pop(context, total),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
