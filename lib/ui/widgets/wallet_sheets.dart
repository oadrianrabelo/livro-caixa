// Diálogos da carteira: fatura do cartão, envelopes (Guardado) e A receber.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/cards.dart';
import '../../domain/csv_import.dart';
import '../../domain/envelopes.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';
import 'entry_form.dart';

// ---------------------------------------------------------------------------
// Fatura
// ---------------------------------------------------------------------------

Future<void> showInvoiceSheet(BuildContext context, Invoice inv) => showLcSheet(
  context,
  builder: (c) {
    final p = Paper.of(c);
    final data = AppScope.of(c).data;
    final db = AppScope.of(c).db;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Fatura ${inv.card.name}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink),
            ),
            const SizedBox(height: 2),
            Text(
              'Vence ${formatDate(inv.dueDate)} · ${inv.purchases.length} compra(s)',
              style: TextStyle(fontSize: 13, color: p.pencil),
            ),
            const SizedBox(height: 12),
            Text(formatBRL(inv.total), style: p.mono(28, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            Flexible(
              child: LcGroup(
                children: [
                  for (final e in inv.purchases)
                    LcRow(
                      title: data.labelOf(e),
                      subtitle: formatDate(e.date),
                      trailing: Text(formatBRL(e.amount), style: p.mono(13.5)),
                      onTap: () {
                        Navigator.pop(c);
                        showEntryForm(context, editing: e);
                      },
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LcButton(
                  inv.paid ? 'Desmarcar como paga' : 'Marcar fatura como paga',
                  icon: inv.paid ? LucideIcons.undo2 : LucideIcons.check,
                  kind: inv.paid ? LcButtonKind.secondary : LcButtonKind.primary,
                  onPressed: () async {
                    await db.setPaidAll(inv.purchases.map((e) => e.id), !inv.paid);
                    if (c.mounted) Navigator.pop(c);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

// ---------------------------------------------------------------------------
// Envelopes
// ---------------------------------------------------------------------------

/// Guardar num envelope (ou tirar dele). Se não houver envelope, oferece criar.
Future<void> showMoveEnvelope(
  BuildContext context, {
  required bool save,
  int? amount,
  String? date,
  Envelope? envelope,
}) async {
  final data = AppScope.of(context).data;
  if (data.envelopes.where((e) => !e.archived).isEmpty) {
    await showEnvelopeEditor(context);
    if (!context.mounted || AppScope.of(context).data.envelopes.isEmpty) return;
  }
  if (!context.mounted) return;
  await showLcDialog(
    context,
    builder: (_) => _MoveEnvelope(save: save, amount: amount, date: date ?? today(), envelope: envelope),
  );
}

class _MoveEnvelope extends StatefulWidget {
  const _MoveEnvelope({required this.save, this.amount, required this.date, this.envelope});
  final bool save;
  final int? amount;
  final String date;
  final Envelope? envelope;

  @override
  State<_MoveEnvelope> createState() => _MoveEnvelopeState();
}

class _MoveEnvelopeState extends State<_MoveEnvelope> {
  late final _amount = TextEditingController(text: widget.amount == null ? '' : centsToInput(widget.amount!));
  String? _envelopeId, _accountId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final data = scope.data;
    final envs = data.envelopes.where((e) => !e.archived).toList();
    final accounts = data.accounts
        .where((a) => !a.archived && a.type != AccountType.vale && a.type != AccountType.cartao)
        .toList();
    final env = envs.where((e) => e.id == (_envelopeId ?? widget.envelope?.id)).firstOrNull ?? envs.firstOrNull;
    final acc = accounts.where((a) => a.id == _accountId).firstOrNull ?? accounts.firstOrNull;
    return LcDialogBody(
      title: widget.save ? 'Guardar' : 'Tirar do guardado',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LcField(
            label: 'Valor',
            controller: _amount,
            prefix: r'R$ ',
            money: true,
            autofocus: widget.amount == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          LcSelect<String?>(
            label: 'Envelope',
            value: env?.id,
            options: [
              for (final e in envs)
                LcOption(e.id, e.name, leading: e.icon, subtitle: formatBRL(envelopeBalance(e, data.entries))),
            ],
            onChanged: (v) => setState(() => _envelopeId = v),
          ),
          const SizedBox(height: 14),
          LcSelect<String?>(
            label: widget.save ? 'Sai de' : 'Volta para',
            value: acc?.id,
            options: [for (final a in accounts) LcOption(a.id, a.name)],
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 10),
          Text(
            widget.save
                ? 'Sai do Disponível do mês, mas não é gasto: fica no envelope.'
                : 'Volta para o Disponível sem dízimo (já foi separado quando entrou).',
            style: TextStyle(fontSize: 12.5, color: Paper.of(context).pencil),
          ),
        ],
      ),
      actions: [
        LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(context)),
        LcButton(
          widget.save ? 'Guardar' : 'Tirar',
          icon: widget.save ? LucideIcons.piggyBank : LucideIcons.arrowDownLeft,
          onPressed: () async {
            final cents = parseBRL(_amount.text);
            if (cents == null || cents <= 0 || env == null || acc == null) return;
            await scope.db.moveEnvelope(
              envelope: env,
              amount: cents,
              save: widget.save,
              date: widget.date,
              accountId: acc.id,
            );
            if (context.mounted) {
              Navigator.pop(context);
              lcToast(context, widget.save ? 'Guardado em ${env.name}.' : 'Tirado de ${env.name}.');
            }
          },
        ),
      ],
    );
  }
}

Future<void> showEnvelopeEditor(BuildContext context, {Envelope? editing}) =>
    showLcDialog(context, builder: (_) => _EnvelopeEditor(editing: editing));

class _EnvelopeEditor extends StatefulWidget {
  const _EnvelopeEditor({this.editing});
  final Envelope? editing;

  @override
  State<_EnvelopeEditor> createState() => _EnvelopeEditorState();
}

class _EnvelopeEditorState extends State<_EnvelopeEditor> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _icon = TextEditingController(text: widget.editing?.icon ?? '🏺');
  late final _initial = TextEditingController(
    text: widget.editing == null || widget.editing!.initialBalance == 0
        ? ''
        : centsToInput(widget.editing!.initialBalance),
  );
  late final _goal = TextEditingController(
    text: widget.editing?.goal == null ? '' : centsToInput(widget.editing!.goal!),
  );

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    const gap = SizedBox(height: 14);
    return LcDialogBody(
      title: widget.editing == null ? 'Novo envelope' : 'Editar envelope',
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
                child: LcField(
                  label: 'Nome',
                  controller: _name,
                  hint: 'Ex.: Férias, Reserva',
                  autofocus: widget.editing == null,
                ),
              ),
            ],
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: LcField(
                  label: 'Já tem guardado',
                  controller: _initial,
                  prefix: r'R$ ',
                  hint: '0,00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LcField(
                  label: 'Meta (opcional)',
                  controller: _goal,
                  prefix: r'R$ ',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.editing != null)
          LcButton(
            'Arquivar',
            kind: LcButtonKind.danger,
            icon: LucideIcons.archive,
            onPressed: () async {
              final e = widget.editing!;
              await db.updateEnvelope(
                e.id,
                name: e.name,
                icon: e.icon,
                initialBalance: e.initialBalance,
                goal: e.goal,
                archived: true,
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
        LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(context)),
        LcButton(
          widget.editing == null ? 'Criar' : 'Salvar',
          onPressed: () async {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final icon = _icon.text.trim().isEmpty ? '🏺' : _icon.text.trim();
            final initial = parseBRL(_initial.text) ?? 0;
            final goal = parseBRL(_goal.text);
            if (widget.editing == null) {
              await db.addEnvelope(name: name, icon: icon, initialBalance: initial, goal: goal);
            } else {
              await db.updateEnvelope(widget.editing!.id, name: name, icon: icon, initialBalance: initial, goal: goal);
            }
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// A receber
// ---------------------------------------------------------------------------

Future<void> showReceivableEditor(BuildContext context) =>
    showLcDialog(context, builder: (_) => const _ReceivableEditor());

class _ReceivableEditor extends StatefulWidget {
  const _ReceivableEditor();

  @override
  State<_ReceivableEditor> createState() => _ReceivableEditorState();
}

class _ReceivableEditorState extends State<_ReceivableEditor> {
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  String? _due;

  @override
  Widget build(BuildContext context) => LcDialogBody(
    title: 'A receber',
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcField(label: 'O quê', controller: _desc, hint: 'Ex.: Adiantamento emprestado', autofocus: true),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LcLabel('Volta em'),
                  LcButton(
                    _due == null ? 'Escolher data' : formatDate(_due!),
                    icon: LucideIcons.calendar,
                    kind: LcButtonKind.secondary,
                    onPressed: () async {
                      final d = await showLcDatePicker(context, _due == null ? DateTime.now() : DateTime.parse(_due!));
                      if (d != null) setState(() => _due = toIsoDate(d));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Quando voltar, marque como recebido: entra como entrada, sem dízimo.',
          style: TextStyle(fontSize: 12.5, color: Paper.of(context).pencil),
        ),
      ],
    ),
    actions: [
      LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(context)),
      LcButton(
        'Salvar',
        onPressed: () async {
          final cents = parseBRL(_amount.text);
          if (_desc.text.trim().isEmpty || cents == null || cents <= 0) return;
          await AppScope.of(context).db.addReceivable(description: _desc.text.trim(), amount: cents, dueDate: _due);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    ],
  );
}

/// Marcar como recebido: escolhe a conta onde o dinheiro entrou.
Future<void> showReceive(BuildContext context, Receivable r) async {
  final scope = AppScope.of(context);
  final accounts = scope.data.accounts
      .where((a) => !a.archived && a.type != AccountType.vale && a.type != AccountType.cartao)
      .toList();
  String? accountId = accounts.firstOrNull?.id;
  await showLcDialog(
    context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => LcDialogBody(
        title: 'Recebeu ${formatBRL(r.amount)}?',
        content: LcSelect<String?>(
          label: 'Entrou em',
          value: accountId,
          options: [for (final a in accounts) LcOption(a.id, a.name)],
          onChanged: (v) => setState(() => accountId = v),
        ),
        actions: [
          LcButton('Ainda não', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(c)),
          LcButton(
            'Recebi',
            icon: LucideIcons.check,
            onPressed: () async {
              if (accountId == null) return;
              await scope.db.receive(r, accountId: accountId!, date: today());
              if (c.mounted) Navigator.pop(c);
            },
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Importar extrato do Nubank (CSV)
// ---------------------------------------------------------------------------

Future<void> showImportCsv(BuildContext context) async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv']);
  if (file == null || !context.mounted) return;
  final ImportResult result;
  try {
    result = parseNubankCsv(utf8.decode(await file.readAsBytes(), allowMalformed: true));
  } on FormatException catch (e) {
    if (context.mounted) lcToast(context, e.message, icon: LucideIcons.circleAlert);
    return;
  }
  if (!context.mounted) return;
  await showLcDialog(context, builder: (_) => _ImportPreview(result: result));
}

class _ImportPreview extends StatefulWidget {
  const _ImportPreview({required this.result});
  final ImportResult result;

  @override
  State<_ImportPreview> createState() => _ImportPreviewState();
}

class _ImportPreviewState extends State<_ImportPreview> {
  String? _accountId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    final r = widget.result;
    final isCard = r.format == 'cartao';
    final accounts = scope.data.accounts
        .where(
          (a) =>
              !a.archived &&
              (isCard ? a.type == AccountType.cartao : a.type != AccountType.cartao && a.type != AccountType.vale),
        )
        .toList();
    final acc = accounts.where((a) => a.id == _accountId).firstOrNull ?? accounts.firstOrNull;
    final out = r.lines.where((l) => !l.income).fold(0, (s, l) => s + l.amount);
    final inn = r.lines.where((l) => l.income).fold(0, (s, l) => s + l.amount);
    return LcDialogBody(
      title: isCard ? 'Importar fatura do cartão' : 'Importar extrato da conta',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${r.lines.length} lançamentos · gastos ${formatBRL(out)}'
            '${inn > 0 ? ' · entradas ${formatBRL(inn)}' : ''}'
            '${r.skipped > 0 ? '\n${r.skipped} linha(s) ignorada(s) (pagamentos/estornos)' : ''}',
            style: TextStyle(fontSize: 13.5, color: p.ink, height: 1.45),
          ),
          const SizedBox(height: 14),
          if (accounts.isEmpty)
            Text(
              isCard ? 'Crie o cartão na Carteira primeiro (com fechamento e vencimento).' : 'Crie uma conta primeiro.',
              style: TextStyle(fontSize: 13, color: p.redInk),
            )
          else
            LcSelect<String?>(
              label: isCard ? 'Em qual cartão' : 'Em qual conta',
              value: acc?.id,
              options: [for (final a in accounts) LcOption(a.id, a.name)],
              onChanged: (v) => setState(() => _accountId = v),
            ),
          const SizedBox(height: 10),
          Text(
            'Entram sem categoria (dá para ajustar depois). Importar o mesmo arquivo de novo não duplica nada.'
            '${inn > 0 ? ' As entradas pedem para separar o dízimo.' : ''}',
            style: TextStyle(fontSize: 12.5, color: p.pencil),
          ),
        ],
      ),
      actions: [
        LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(context)),
        LcButton(
          'Importar',
          icon: LucideIcons.download,
          onPressed: acc == null
              ? null
              : () async {
                  final added = await scope.db.importLines(
                    lines: [
                      for (final l in r.lines)
                        (date: l.date, description: l.description, amount: l.amount, income: l.income, key: l.key),
                    ],
                    accountId: acc.id,
                    card: isCard,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    lcToast(
                      context,
                      added == 0 ? 'Nada novo: já estava tudo importado.' : '$added lançamento(s) importado(s).',
                    );
                  }
                },
        ),
      ],
    );
  }
}
