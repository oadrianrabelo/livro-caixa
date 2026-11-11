// Calculadora de compras: no mercado, vai anotando o preço de cada coisa e
// no fim tem o total exato para passar no vale (ou lançar como gasto).
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../data/prefs.dart';
import '../../domain/vale.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';
import 'entry_form.dart';

Future<void> showShoppingCalc(BuildContext context) async {
  final result = await showLcSheet<int>(
    context,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: const _ShoppingCalc(),
    ),
  );
  if (result == null || !context.mounted) return;
  // Lançar o total: no vale, se houver um.
  final scope = AppScope.of(context);
  final vale = scope.data.accounts.where((a) => a.type == AccountType.vale && !a.archived).firstOrNull;
  final saved = await showEntryForm(context, amount: result, accountId: vale?.id, description: 'Compras');
  if (saved) await scope.prefs.setShopping(const []);
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
    final item = ShopItem(price: cents, qty: _qty, name: _name.text.trim());
    await prefs.setShopping([item, ...prefs.shopping]);
    _price.clear();
    _name.clear();
    setState(() {
      _qty = 1;
      _error = null;
    });
    _priceFocus.requestFocus(); // pronto para o próximo preço
  }

  Future<void> _remove(Prefs prefs, int index) async {
    final items = [...prefs.shopping]..removeAt(index);
    await prefs.setShopping(items);
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

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Calculadora de compras',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink, letterSpacing: -0.3),
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
                onSubmitted: (_) => _add(scope.prefs),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(fontSize: 12.5, color: p.redInk)),
              ],
              const SizedBox(height: 12),
              LcButton('Anotar', icon: LucideIcons.plus, onPressed: () => _add(scope.prefs)),
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
                          child: Text(
                            [
                              if (items[i].name.isNotEmpty) items[i].name,
                              if (items[i].qty > 1) '${items[i].qty} × ${formatBRL(items[i].price)}',
                              if (items[i].name.isEmpty && items[i].qty == 1) 'Item ${items.length - i}',
                            ].join(' · '),
                            style: TextStyle(fontSize: 14, color: p.ink),
                            overflow: TextOverflow.ellipsis,
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
