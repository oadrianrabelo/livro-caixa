// Diálogos de edição: categoria, conta e conta fixa.
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';

const sectionLabels = {
  CategorySection.primicias: 'Dízimo e oferta',
  CategorySection.cartao: 'Cartão',
  CategorySection.casa: 'Casa',
  CategorySection.pessoal: 'Pessoal',
  CategorySection.outros: 'Outros',
};

const accountTypeLabels = {
  AccountType.corrente: 'Conta corrente',
  AccountType.poupanca: 'Poupança',
  AccountType.carteira: 'Carteira',
  AccountType.cartao: 'Cartão de crédito',
  AccountType.investimento: 'Investimento',
  AccountType.vale: 'Vale-alimentação',
};

const accountTypeIcons = {
  AccountType.corrente: LucideIcons.landmark,
  AccountType.poupanca: LucideIcons.piggyBank,
  AccountType.carteira: LucideIcons.wallet,
  AccountType.cartao: LucideIcons.creditCard,
  AccountType.investimento: LucideIcons.trendingUp,
  AccountType.vale: LucideIcons.utensils,
};

const _swatches = [
  0xFF16A34A,
  0xFF2563EB,
  0xFFCA8A04,
  0xFF9333EA,
  0xFFDC2626,
  0xFFDB2777,
  0xFFEA580C,
  0xFF0891B2,
  0xFF4F46E5,
  0xFF64748B,
  0xFF059669,
  0xFF7C5C2E,
];
const _emojis = [
  '🛒',
  '🏠',
  '💡',
  '🚗',
  '🩺',
  '🎉',
  '🍔',
  '📚',
  '📺',
  '📦',
  '💼',
  '✨',
  '🍪',
  '🛵',
  '🐶',
  '💇',
  '🎁',
  '⛽',
  '💊',
  '👕',
];

// ---------------------------------------------------------------------------

Future<void> showCategoryEditor(BuildContext context, {Category? editing}) =>
    showLcDialog(context, builder: (_) => _CategoryEditor(editing: editing));

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({this.editing});
  final Category? editing;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _icon = TextEditingController(text: widget.editing?.icon ?? '🏷️');
  late CategoryKind _kind = widget.editing?.kind ?? CategoryKind.despesa;
  late CategorySection _section = widget.editing?.section ?? CategorySection.casa;
  late int _color = widget.editing?.color ?? _swatches.first;
  bool get _special => widget.editing?.section == CategorySection.primicias;
  final _limit = TextEditingController();
  bool _limitLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_limitLoaded) return;
    _limitLoaded = true;
    final current = AppScope.of(context).data.budgetOf(widget.editing?.id);
    if (current != null) _limit.text = centsToInput(current);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final db = AppScope.of(context).db;
    final section = _kind == CategoryKind.despesa ? _section : null;
    if (widget.editing == null) {
      await db.addCategory(name: name, kind: _kind, icon: _icon.text.trim(), color: _color, section: section);
    } else {
      await db.updateCategory(
        widget.editing!.id,
        name: name,
        icon: _icon.text.trim(),
        color: _color,
        section: _special ? CategorySection.primicias : section,
      );
      // Limite mensal (vazio = sem limite).
      await db.setBudget(widget.editing!.id, _kind == CategoryKind.despesa ? parseBRL(_limit.text) : null);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final c = widget.editing!;
    if (!await lcConfirm(
      context,
      'Os lançamentos dessa categoria ficam "sem categoria".',
      confirm: 'Excluir',
      danger: true,
      title: 'Excluir "${c.name}"?',
    )) {
      return;
    }
    if (!mounted) return;
    final db = AppScope.of(context).db;
    await db.softDelete(db.categories, c.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    const gap = SizedBox(height: 14);
    return LcDialogBody(
      title: widget.editing == null ? 'Nova categoria' : 'Editar categoria',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 76,
                child: LcField(label: 'Ícone', controller: _icon, textAlign: TextAlign.center, maxLength: 4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LcField(label: 'Nome', controller: _name, hint: 'Ex.: Pets', autofocus: widget.editing == null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 2,
            children: [
              for (final e in _emojis)
                GestureDetector(
                  onTap: () => setState(() => _icon.text = e),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(e, style: const TextStyle(fontSize: 18)),
                  ),
                ),
            ],
          ),
          if (widget.editing != null && _kind == CategoryKind.despesa && !_special) ...[
            gap,
            LcField(
              label: 'Limite por mês (opcional)',
              controller: _limit,
              prefix: r'R$ ',
              hint: 'sem limite',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'O app avisa quando os gastos do mês chegarem perto. Aparece em Ano → Orçamento.',
                style: TextStyle(fontSize: 12, color: p.pencil, height: 1.35),
              ),
            ),
          ],
          gap,
          const LcLabel('Cor'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _swatches)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(color: _color == c ? p.ink : Colors.transparent, width: 2),
                    ),
                    child: _color == c ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
                  ),
                ),
            ],
          ),
          if (widget.editing == null) ...[
            gap,
            LcSegmented(
              expand: true,
              options: const [(CategoryKind.despesa, 'Gasto'), (CategoryKind.receita, 'Entrada')],
              value: _kind,
              onChanged: (v) => setState(() => _kind = v),
            ),
          ],
          if (_kind == CategoryKind.despesa && !_special) ...[
            gap,
            LcSelect<CategorySection>(
              label: 'Seção no caderno',
              value: _section,
              options: [
                for (final s in [
                  CategorySection.cartao,
                  CategorySection.casa,
                  CategorySection.pessoal,
                  CategorySection.outros,
                ])
                  LcOption(s, sectionLabels[s]!),
              ],
              onChanged: (v) => setState(() => _section = v),
            ),
          ],
        ],
      ),
      actions: [
        if (widget.editing != null && !_special)
          LcButton('Excluir', kind: LcButtonKind.danger, icon: LucideIcons.trash2, onPressed: _delete),
        LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(context)),
        LcButton(widget.editing == null ? 'Criar' : 'Salvar', onPressed: _save),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

Future<void> showAccountEditor(BuildContext context, {Account? editing}) =>
    showLcDialog(context, builder: (_) => _AccountEditor(editing: editing));

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({this.editing});
  final Account? editing;

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _initial = TextEditingController(
    text: widget.editing == null || widget.editing!.initialBalance == 0
        ? ''
        : centsToInput(widget.editing!.initialBalance),
  );
  late final _renewAmount = TextEditingController(
    text: widget.editing?.renewAmount == null ? '' : centsToInput(widget.editing!.renewAmount!),
  );
  late final _renewDay = TextEditingController(text: '${widget.editing?.renewDay ?? 20}');
  late final _closing = TextEditingController(
    text: widget.editing?.closingDay == null ? '' : '${widget.editing!.closingDay}',
  );
  late final _due = TextEditingController(text: widget.editing?.dueDay == null ? '' : '${widget.editing!.dueDay}');
  late AccountType _type = widget.editing?.type ?? AccountType.corrente;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final db = AppScope.of(context).db;
    final vale = _type == AccountType.vale;
    final initial = vale ? 0 : parseBRL(_initial.text) ?? 0;
    final renewAmount = vale ? parseBRL(_renewAmount.text) ?? 0 : null;
    final renewDay = vale ? (int.tryParse(_renewDay.text) ?? 20).clamp(1, 28) : null;
    final card = _type == AccountType.cartao;
    final closing = card ? int.tryParse(_closing.text)?.clamp(1, 28) : null;
    final due = card ? int.tryParse(_due.text)?.clamp(1, 28) : null;
    if (widget.editing == null) {
      await db.addAccount(
        name: name,
        type: _type,
        initialBalance: initial,
        renewAmount: renewAmount,
        renewDay: renewDay,
        closingDay: closing,
        dueDay: due,
      );
    } else {
      await db.updateAccount(
        widget.editing!.id,
        name: name,
        type: _type,
        initialBalance: initial,
        renewAmount: renewAmount,
        renewDay: renewDay,
        closingDay: closing,
        dueDay: due,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    final vale = _type == AccountType.vale;
    return LcDialogBody(
      title: widget.editing == null ? 'Nova conta' : 'Editar conta',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LcField(label: 'Nome', controller: _name, hint: 'Ex.: Nubank', autofocus: widget.editing == null),
          gap,
          LcSelect<AccountType>(
            label: 'Tipo',
            value: _type,
            options: [for (final t in AccountType.values) LcOption(t, accountTypeLabels[t]!)],
            onChanged: (v) => setState(() => _type = v),
          ),
          gap,
          if (vale) ...[
            Row(
              children: [
                Expanded(
                  child: LcField(
                    label: 'Valor todo mês',
                    controller: _renewAmount,
                    prefix: r'R$ ',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: LcField(label: 'Renova dia', controller: _renewDay, keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'O vale fica fora do Disponível. Lance as compras com ele para ver quanto resta.',
              style: TextStyle(fontSize: 12.5, color: Paper.of(context).pencil),
            ),
          ] else if (_type == AccountType.cartao) ...[
            Row(
              children: [
                Expanded(
                  child: LcField(
                    label: 'Fatura fecha dia',
                    controller: _closing,
                    hint: '3',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LcField(label: 'Vence dia', controller: _due, hint: '10', keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lance as compras neste cartão: elas somam na fatura certa, que aparece em Cartão no mês do vencimento.',
              style: TextStyle(fontSize: 12.5, color: Paper.of(context).pencil),
            ),
          ] else
            LcField(
              label: 'Saldo inicial',
              controller: _initial,
              prefix: r'R$ ',
              hint: '0,00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
        ],
      ),
      actions: [
        LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(context)),
        LcButton(widget.editing == null ? 'Criar' : 'Salvar', onPressed: _save),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

Future<void> showRecurringEditor(BuildContext context, Recurring r) =>
    showLcDialog(context, builder: (_) => _RecurringEditor(r: r));

class _RecurringEditor extends StatefulWidget {
  const _RecurringEditor({required this.r});
  final Recurring r;

  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  late final _desc = TextEditingController(text: widget.r.description);
  late final _amount = TextEditingController(text: centsToInput(widget.r.amount));
  late final _day = TextEditingController(text: '${widget.r.day}');
  late bool _variable = widget.r.variable;
  late bool _active = widget.r.active;

  Future<void> _save() async {
    await AppScope.of(context).db.updateRecurring(
      widget.r.id,
      description: _desc.text.trim().isEmpty ? widget.r.description : _desc.text.trim(),
      amount: parseBRL(_amount.text) ?? widget.r.amount,
      day: int.tryParse(_day.text) ?? widget.r.day,
      variable: _variable,
      active: _active,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return LcDialogBody(
      title: 'Conta fixa',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LcField(label: 'Descrição', controller: _desc),
          gap,
          Row(
            children: [
              Expanded(
                child: LcField(
                  label: 'Valor',
                  controller: _amount,
                  prefix: r'R$ ',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: LcField(label: 'Dia', controller: _day, keyboardType: TextInputType.number),
              ),
            ],
          ),
          gap,
          LcToggleRow(
            title: 'O valor muda todo mês',
            subtitle: 'O mês seguinte vem com o valor do anterior, para você corrigir (ex.: luz).',
            value: _variable,
            onChanged: (v) => setState(() => _variable = v),
          ),
          LcToggleRow(
            title: 'Repetir nos próximos meses',
            subtitle: 'Desligue para parar (os meses já lançados ficam).',
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 4),
          Text(
            'A mudança vale para os próximos meses; os já lançados você edita no próprio mês.',
            style: TextStyle(fontSize: 12.5, color: Paper.of(context).pencil),
          ),
        ],
      ),
      actions: [
        LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(context)),
        LcButton('Salvar', onPressed: _save),
      ],
    );
  }
}
