import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/cards.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';
import 'kbd.dart' show isDesktop;
import 'tithe_dialog.dart';

/// Abre o formulário de lançamento (novo ou edição) numa folha de baixo.
/// Depois de salvar uma ENTRADA, pergunta se quer separar dízimo e oferta.
/// Abre o formulário. Devolve o id do lançamento salvo (null se cancelou).
Future<String?> showEntryForm(
  BuildContext context, {
  Entry? editing,
  EntryType? type,
  String? date,
  int? amount,
  String? accountId,
  String? description,
  String? categoryId,
  bool? paid,
}) async {
  final before = editing;
  final savedId = await showLcSheet<String>(
    context,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: EntryForm(
        editing: editing,
        initialType: type,
        initialDate: date,
        initialAmount: amount,
        initialAccountId: accountId,
        initialDescription: description,
        initialCategoryId: categoryId,
        initialPaid: paid,
      ),
    ),
  );
  if (savedId == null || !context.mounted) return savedId;
  final db = AppScope.of(context).db;
  final saved = await db.getEntry(savedId);
  if (saved == null || saved.type != EntryType.receita || !context.mounted) return savedId;

  if (saved.titheStatus == TitheStatus.pendente && (before == null || before.titheStatus != TitheStatus.pendente)) {
    await showTitheDialog(context, incomes: [saved]);
  } else if (before != null && saved.titheStatus == TitheStatus.separado && saved.amount != before.amount) {
    final diff = saved.amount - before.amount;
    if (diff > 0) {
      await showTitheDialog(context, incomes: [saved], base: diff);
    } else {
      lcToast(
        context,
        'Esta entrada já teve o dízimo separado. Se precisar, ajuste o dízimo e a oferta do mês.',
        icon: LucideIcons.info,
      );
    }
  }
  return savedId;
}

class EntryForm extends StatefulWidget {
  const EntryForm({
    super.key,
    this.editing,
    this.initialType,
    this.initialDate,
    this.initialAmount,
    this.initialAccountId,
    this.initialDescription,
    this.initialCategoryId,
    this.initialPaid,
  });
  final Entry? editing;
  final EntryType? initialType;
  final String? initialDate;
  final int? initialAmount; // ex.: total da calculadora de compras
  final String? initialAccountId;
  final String? initialDescription;
  final String? initialCategoryId;
  final bool? initialPaid;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  late EntryType _type = widget.editing?.type ?? widget.initialType ?? EntryType.despesa;
  late final _amount = TextEditingController(
    text: widget.editing != null
        ? centsToInput(widget.editing!.amount)
        : widget.initialAmount != null
        ? centsToInput(widget.initialAmount!)
        : '',
  );
  late final _description = TextEditingController(text: widget.editing?.description ?? widget.initialDescription ?? '');
  late String _date = widget.editing?.date ?? widget.initialDate ?? today();
  late String? _accountId = widget.editing?.accountId ?? widget.initialAccountId;
  late String? _toAccountId = widget.editing?.toAccountId;
  late String? _categoryId = widget.editing?.categoryId ?? widget.initialCategoryId;
  // Novo lançamento: ainda a pagar (a calculadora de compras passa "pago": foi no caixa).
  late bool _paid = widget.editing?.paid ?? widget.initialPaid ?? false;
  late bool _tithable = widget.editing?.titheStatus != TitheStatus.isento;
  String? _personId;
  bool _personReady = false;
  bool _recurring = false; // conta fixa (só ao criar)
  bool _variable = false; // conta fixa cujo valor muda (luz)
  int _installments = 1; // parcelas (só ao criar um gasto)
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_personReady) return;
    _personReady = true;
    _personId = widget.editing != null ? widget.editing!.personId : AppScope.of(context).prefs.mePerson;
  }

  bool get _isNew => widget.editing == null;

  /// Situação do dízimo a gravar (só para entradas).
  TitheStatus? get _titheStatus {
    if (_type != EntryType.receita) return null;
    if (!_tithable) return TitheStatus.isento;
    final old = widget.editing?.titheStatus;
    return old == TitheStatus.separado ? null : TitheStatus.pendente; // null = mantém "separado"
  }

  /// Lançamentos anteriores com descrição parecida (o mais recente de cada).
  List<Widget> _descSuggestions(AppData data) {
    final q = _description.text.trim().toLowerCase();
    if (q.length < 2) return const [];
    final index = data.memo(#descIndex, () {
      final byDesc = <String, (Entry, int)>{};
      for (final e in data.entries) {
        if (e.description.isEmpty || e.recurringId != null || e.installmentCount != null) continue;
        final k = '${e.type.name}|${e.description.trim().toLowerCase()}';
        final cur = byDesc[k];
        final newer = cur == null || e.date.compareTo(cur.$1.date) > 0;
        byDesc[k] = (newer ? e : cur.$1, (cur?.$2 ?? 0) + 1);
      }
      return byDesc.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    });
    final hits = [
      for (final (e, _) in index)
        if (e.type == _type && e.description.toLowerCase().contains(q) && e.description.toLowerCase() != q) e,
    ].take(3).toList();
    if (hits.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in hits)
            LcChip(
              '${e.description} · ${formatBRL(e.amount)}',
              selected: false,
              onTap: () => setState(() {
                _description.text = e.description;
                _categoryId = e.categoryId;
                _accountId = e.accountId;
                if (parseBRL(_amount.text) == null) _amount.text = centsToInput(e.amount);
              }),
            ),
        ],
      ),
    ];
  }

  /// Abre um lançamento novo igual a este, com a data de hoje.
  void _duplicate() {
    final e = widget.editing!;
    final nav = Navigator.of(context);
    nav.pop();
    showEntryForm(
      nav.context,
      type: e.type,
      amount: e.amount,
      accountId: e.accountId,
      description: e.description,
      categoryId: e.categoryId,
    );
  }

  Future<void> _delete() async {
    final e = widget.editing!;
    // Só pergunta quando há algo a avisar; no resto, exclui e oferece "Desfazer".
    if (e.titheStatus == TitheStatus.separado &&
        !await lcConfirm(
          context,
          'Esta entrada já teve dízimo e oferta separados; eles continuam lançados.',
          confirm: 'Excluir',
          danger: true,
          title: 'Excluir "${e.description.isEmpty ? 'este lançamento' : e.description}"?',
        )) {
      return;
    }
    if (!mounted) return;
    final db = AppScope.of(context).db;
    final nav = Navigator.of(context);
    await db.softDelete(db.entries, e.id);
    nav.pop();
    if (nav.mounted) {
      lcToast(
        nav.context,
        '"${AppScope.of(nav.context).data.labelOf(e)}" excluído.',
        icon: LucideIcons.trash2,
        actionLabel: 'Desfazer',
        onAction: () => db.restore(db.entries, e.id),
      );
    }
  }

  bool _saving = false; // evita lançar duas vezes com toque duplo

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    try {
      await _doSave();
    } finally {
      _saving = false;
    }
  }

  Future<void> _doSave() async {
    final scope = AppScope.of(context);
    final from = _accountsFor(scope.data).any((a) => a.id == _accountId)
        ? _accountId
        : _accountsFor(scope.data).firstOrNull?.id;
    final cents = parseBRL(_amount.text);
    String? error;
    if (cents == null || cents <= 0) error = 'Informe um valor maior que zero.';
    if (from == null) error = 'Crie uma conta primeiro.';
    if (_type == EntryType.transferencia && (_toAccountId == null || _toAccountId == from)) {
      error = 'Escolha uma conta de destino diferente.';
    }
    if (error != null) return setState(() => _error = error);

    final transfer = _type == EntryType.transferencia;
    final description = _description.text.trim();
    final db = scope.db;
    String id;
    if (_isNew && _recurring && !transfer) {
      id = await db.createRecurring(
        type: _type,
        description: description.isEmpty ? scope.data.category(_categoryId)?.name ?? 'Conta fixa' : description,
        amount: cents!,
        variable: _variable,
        day: int.parse(_date.substring(8)),
        accountId: from!,
        categoryId: _categoryId,
        personId: _personId,
        startMonth: monthOf(_date),
      );
      if (_paid) await db.setPaid(id, true);
      if (_type == EntryType.receita && !_tithable) await db.setTitheStatus([id], TitheStatus.isento);
    } else if (_isNew && _installments > 1 && _type == EntryType.despesa) {
      id = await db.saveInstallments(
        installment: cents!,
        count: _installments,
        date: _date,
        description: description,
        accountId: from!,
        categoryId: _categoryId,
        personId: _personId,
        firstPaid: _paid,
      );
    } else {
      id = await db.saveEntry(
        id: widget.editing?.id,
        type: _type,
        amount: cents!,
        date: _date,
        description: description.isEmpty && transfer ? 'Transferência' : description,
        accountId: from!,
        toAccountId: transfer ? _toAccountId : null,
        categoryId: transfer ? null : _categoryId,
        paid: _paid,
        titheStatus: _titheStatus,
        personId: _personId,
      );
    }
    if (mounted) Navigator.pop(context, id);
  }

  Future<void> _pickDate() async {
    hideKeyboard();
    final picked = await showLcDatePicker(context, DateTime.parse(_date));
    if (picked != null) setState(() => _date = toIsoDate(picked));
  }

  /// Contas que fazem sentido para o tipo (vale-alimentação só para gastos).
  List<Account> _accountsFor(AppData data) => data.accounts
      .where((a) => !a.archived || a.id == _accountId)
      .where((a) => _type == EntryType.despesa || a.type != AccountType.vale)
      .toList();

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final p = Paper.of(context);
    final accounts = _accountsFor(data);
    final from = accounts.any((a) => a.id == _accountId) ? _accountId : accounts.firstOrNull?.id;
    final onVale = data.valeAccountIds.contains(from);
    final editing = widget.editing;
    final rec = data.recurring(editing?.recurringId);
    final kind = _type == EntryType.receita ? CategoryKind.receita : CategoryKind.despesa;
    // As mais usadas primeiro: a que você quer quase sempre está no topo.
    final uses = data.memo(#categoryUses, () {
      final m = <String, int>{};
      for (final e in data.entries) {
        if (e.categoryId != null) m.update(e.categoryId!, (v) => v + 1, ifAbsent: () => 1);
      }
      return m;
    });
    final categories = data.categories.where((c) => c.kind == kind).toList()
      ..sort((a, b) {
        final d = (uses[b.id] ?? 0).compareTo(uses[a.id] ?? 0);
        return d != 0 ? d : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final transfer = _type == EntryType.transferencia;
    const gap = SizedBox(height: 14);
    Widget note(String text, {IconData icon = LucideIcons.info}) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: p.pencil),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: p.pencil, height: 1.35)),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            editing == null ? 'Lançar' : 'Editar lançamento',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink, letterSpacing: -0.3),
          ),
          const SizedBox(height: 14),
          LcSegmented<EntryType>(
            expand: true,
            options: const [
              (EntryType.despesa, 'Gasto'),
              (EntryType.receita, 'Entrada'),
              (EntryType.transferencia, 'Transferência'),
            ],
            value: _type,
            onChanged: (v) => setState(() {
              _type = v;
              _categoryId = null;
            }),
          ),
          gap,
          LcField(
            label: _installments > 1 ? 'Valor de cada parcela' : 'Valor',
            controller: _amount,
            autofocus: editing == null && widget.initialAmount == null,
            money: true,
            prefix: r'R$ ',
            hint: '0,00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _installments > 1 ? setState(() {}) : null,
            // No computador, Enter já salva; no celular, pula para a descrição.
            onSubmitted: isDesktop ? (_) => _save() : null,
          ),
          gap,
          LcField(
            label: 'Descrição',
            controller: _description,
            hint: transfer ? 'Transferência' : 'Ex.: Feira do mês',
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => isDesktop ? _save() : hideKeyboard(),
          ),
          // Já lançou algo parecido? Toque para repetir categoria, conta e valor.
          if (_isNew && !transfer) ..._descSuggestions(data),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LcLabel('Data'),
                    SizedBox(
                      height: 42, // mesma altura do seletor ao lado
                      child: LcButton(
                        formatDate(_date),
                        icon: LucideIcons.calendar,
                        kind: LcButtonKind.secondary,
                        onPressed: _pickDate,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LcSelect<String?>(
                  label: transfer ? 'De' : 'Conta',
                  value: from,
                  options: [for (final a in accounts) LcOption(a.id, a.name)],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
              ),
            ],
          ),
          gap,
          if (transfer)
            LcSelect<String?>(
              label: 'Para',
              value: _toAccountId,
              options: [for (final a in accounts.where((a) => a.id != from)) LcOption(a.id, a.name)],
              onChanged: (v) => setState(() => _toAccountId = v),
            )
          else
            LcSelect<String?>(
              label: 'Categoria',
              value: _categoryId,
              options: [
                const LcOption(null, 'Sem categoria', leading: '·'),
                for (final c in categories) LcOption(c.id, c.name, leading: c.icon),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          if (onVale) note('Pago com o vale-alimentação: não sai do Disponível.', icon: LucideIcons.utensils),
          if (_type == EntryType.despesa && data.account(from)?.type == AccountType.cartao)
            note(
              'Entra na fatura que vence em ${monthLabel(invoiceDueMonth(data.account(from)!, _date)).toLowerCase()}.',
              icon: LucideIcons.creditCard,
            ),
          if (!transfer && data.people.isNotEmpty) ...[
            gap,
            const LcLabel('Quem'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final person in data.people)
                  LcChip(
                    person.name,
                    selected: _personId == person.id,
                    onTap: () => setState(() => _personId = _personId == person.id ? null : person.id),
                  ),
              ],
            ),
          ],
          gap,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hairline(p)),
            ),
            child: Column(
              children: [
                LcToggleRow(
                  title: _type == EntryType.receita ? 'Já recebido' : 'Já pago',
                  value: _paid,
                  onChanged: (v) => setState(() => _paid = v),
                ),
                if (_type == EntryType.receita)
                  LcToggleRow(
                    title: 'Gera dízimo e oferta',
                    subtitle: editing?.titheStatus == TitheStatus.separado
                        ? 'Já separado.'
                        : 'Desligue para dinheiro que só está voltando (ex.: empréstimo).',
                    value: _tithable,
                    onChanged: (v) => setState(() => _tithable = v),
                  ),
                if (_isNew && !transfer)
                  LcToggleRow(
                    title: 'Conta fixa',
                    subtitle: 'Repete todo mês (aluguel, internet, salário).',
                    value: _recurring,
                    onChanged: (v) => setState(() {
                      _recurring = v;
                      if (v) _installments = 1;
                    }),
                  ),
                if (_isNew && _recurring)
                  LcToggleRow(
                    title: 'O valor muda todo mês',
                    subtitle: 'O próximo mês vem com o valor deste, para corrigir (ex.: luz).',
                    value: _variable,
                    onChanged: (v) => setState(() => _variable = v),
                  ),
                if (_isNew && _type == EntryType.despesa && !_recurring)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parcelas',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.ink),
                              ),
                              if (_installments > 1 && parseBRL(_amount.text) != null)
                                Text(
                                  'Total ${formatBRL(parseBRL(_amount.text)! * _installments)}',
                                  style: TextStyle(fontSize: 12.5, color: p.pencil),
                                ),
                            ],
                          ),
                        ),
                        LcIconButton(
                          LucideIcons.minus,
                          size: 15,
                          onPressed: _installments > 1 ? () => setState(() => _installments--) : null,
                        ),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '$_installments×',
                            textAlign: TextAlign.center,
                            style: p.mono(14, weight: FontWeight.w600),
                          ),
                        ),
                        LcIconButton(
                          LucideIcons.plus,
                          size: 15,
                          onPressed: _installments < 48 ? () => setState(() => _installments++) : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (editing?.installmentCount != null)
            note('Parcela ${editing!.installmentIndex} de ${editing.installmentCount}. A edição vale só para esta.'),
          if (rec != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: note(
                      rec.active
                          ? 'Conta fixa: a edição vale só para este mês.'
                          : 'Conta fixa parada (não aparece nos próximos meses).',
                      icon: LucideIcons.repeat,
                    ),
                  ),
                  if (rec.active)
                    LcButton(
                      'Parar de repetir',
                      small: true,
                      kind: LcButtonKind.ghost,
                      onPressed: () async {
                        await AppScope.of(context).db.updateRecurring(rec.id, active: false);
                        if (context.mounted) lcToast(context, 'Não vai mais repetir nos próximos meses.');
                      },
                    ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: TextStyle(color: p.redInk, fontSize: 13)),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (editing != null) ...[
                LcIconButton(LucideIcons.trash2, tooltip: 'Excluir', color: p.redInk, onPressed: _delete),
                if (editing.recurringId == null && editing.installmentCount == null)
                  LcIconButton(
                    LucideIcons.copy,
                    tooltip: 'Duplicar (lançar de novo, com a data de hoje)',
                    onPressed: _duplicate,
                  ),
              ],
              const Spacer(),
              LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 8),
              LcButton(editing == null ? 'Adicionar' : 'Salvar', onPressed: _save),
            ],
          ),
        ],
      ),
    );
  }
}
