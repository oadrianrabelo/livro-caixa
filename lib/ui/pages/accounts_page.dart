import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../core/dates.dart';
import '../../domain/cards.dart';
import '../../domain/envelopes.dart';
import '../../domain/finance.dart';
import '../../domain/vale.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';
import '../widgets/common.dart';
import '../widgets/editors.dart';
import '../widgets/wallet_sheets.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  Future<void> _remove(BuildContext context, Account a) async {
    final scope = AppScope.of(context);
    final used = scope.data.entries.any((e) => e.accountId == a.id || e.toAccountId == a.id);
    if (used) {
      if (await lcConfirm(
        context,
        '"${a.name}" tem lançamentos, então não dá para excluir. Arquivar esconde a conta dos formulários, '
        'mas mantém o histórico.',
        confirm: 'Arquivar',
        title: 'Arquivar conta?',
      )) {
        await scope.db.setAccountArchived(a.id, true);
      }
    } else if (await lcConfirm(
      context,
      'Essa conta não tem lançamentos.',
      confirm: 'Excluir',
      danger: true,
      title: 'Excluir "${a.name}"?',
    )) {
      await scope.db.softDelete(scope.db.accounts, a.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    return ListenableBuilder(
      listenable: scope.data,
      builder: (context, _) {
        final data = scope.data;
        final now = DateTime.now();
        int balanceOf(Account a) =>
            a.type == AccountType.vale ? valeStatus(a, data.entries, now).left : accountBalance(a, data.entries);
        final active = data.accounts.where((a) => !a.archived).toList();
        final archived = data.accounts.where((a) => a.archived).toList();
        final total = active
            .where((a) => a.type != AccountType.vale && a.type != AccountType.cartao)
            .fold(0, (s, a) => s + balanceOf(a));

        Widget row(Account a) {
          final balance = balanceOf(a);
          final vale = a.type == AccountType.vale;
          return LcRow(
            dim: a.archived,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: p.ink.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
              child: Icon(accountTypeIcons[a.type], size: 16, color: p.ink),
            ),
            title: a.name,
            subtitle: vale
                ? 'Vale · renova dia ${a.renewDay} com ${formatBRL(a.renewAmount ?? 0)}'
                : accountTypeLabels[a.type],
            onTap: () => showAccountEditor(context, editing: a),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatBRL(balance),
                      style: p.mono(14, weight: FontWeight.w600, color: balance < 0 ? p.redInk : p.ink),
                    ),
                    if (vale) Text('restam', style: TextStyle(fontSize: 11.5, color: p.pencil)),
                  ],
                ),
                const SizedBox(width: 4),
                a.archived
                    ? LcIconButton(
                        LucideIcons.archiveRestore,
                        tooltip: 'Desarquivar',
                        size: 15,
                        onPressed: () => scope.db.setAccountArchived(a.id, false),
                      )
                    : LcIconButton(
                        LucideIcons.archive,
                        tooltip: 'Arquivar ou excluir',
                        size: 15,
                        onPressed: () => _remove(context, a),
                      ),
              ],
            ),
          );
        }

        final banks = active.where((a) => a.type != AccountType.cartao && a.type != AccountType.vale).toList();
        final cards = active.where((a) => a.type == AccountType.cartao).toList();
        final vales = active.where((a) => a.type == AccountType.vale).toList();
        final envs = data.envelopes.where((e) => !e.archived).toList();
        final savedTotal = envs.fold(0, (sum, e) => sum + envelopeBalance(e, data.entries));
        final pendingReceivables = data.receivables.where((r) => r.receivedEntryId == null).toList();
        final toReceive = pendingReceivables.fold(0, (sum, r) => sum + r.amount);

        Widget cardRow(Account a) {
          final open = invoicesFor([a], data.entries, invoiceDueMonth(a, today())).firstOrNull;
          return LcRow(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: p.ink.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
              child: Icon(LucideIcons.creditCard, size: 16, color: p.ink),
            ),
            title: a.name,
            subtitle: a.closingDay == null
                ? 'Defina o fechamento para somar a fatura'
                : 'Fecha dia ${a.closingDay} · vence dia ${a.dueDay ?? a.closingDay}',
            onTap: () => open != null ? showInvoiceSheet(context, open) : showAccountEditor(context, editing: a),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatBRL(open?.total ?? 0), style: p.mono(14, weight: FontWeight.w600)),
                    Text('fatura aberta', style: TextStyle(fontSize: 11.5, color: p.pencil)),
                  ],
                ),
                LcIconButton(
                  LucideIcons.pencil,
                  tooltip: 'Editar cartão',
                  size: 15,
                  onPressed: () => showAccountEditor(context, editing: a),
                ),
              ],
            ),
          );
        }

        Widget envRow(Envelope e) {
          final balance = envelopeBalance(e, data.entries);
          final goal = e.goal;
          return LcRow(
            leading: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.greenInk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(e.icon, style: const TextStyle(fontSize: 15)),
            ),
            title: e.name,
            subtitle: goal == null
                ? null
                : 'Meta ${formatBRL(goal)} · ${(balance * 100 / goal).clamp(0, 999).round()}%',
            onTap: () => showEnvelopeEditor(context, editing: e),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatBRL(balance),
                  style: p.mono(14, weight: FontWeight.w600, color: p.greenInk),
                ),
                LcIconButton(
                  LucideIcons.plus,
                  tooltip: 'Guardar',
                  size: 15,
                  onPressed: () => showMoveEnvelope(context, save: true, envelope: e),
                ),
                LcIconButton(
                  LucideIcons.minus,
                  tooltip: 'Tirar',
                  size: 15,
                  onPressed: () => showMoveEnvelope(context, save: false, envelope: e),
                ),
              ],
            ),
          );
        }

        Widget summary(String label, int value, {Color? color, String? note}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: p.pencil, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                // Encolhe para caber: no celular os três valores dividem a largura.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatBRL(value),
                    style: p.mono(22, weight: FontWeight.w700, color: color),
                  ),
                ),
                if (note != null) Text(note, style: TextStyle(fontSize: 11.5, color: p.pencil)),
              ],
            ),
          ),
        );

        return PageBody(
          title: 'Carteira',
          subtitle: 'Onde o dinheiro está, o que está guardado e o que vai voltar.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LcButton(
                'Importar extrato',
                icon: LucideIcons.fileUp,
                kind: LcButtonKind.ghost,
                onPressed: () => showImportCsv(context),
              ),
              const SizedBox(width: 6),
              LcButton(
                'Nova conta',
                icon: LucideIcons.plus,
                kind: LcButtonKind.secondary,
                onPressed: () => showAccountEditor(context),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: p.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hairline(p)),
              ),
              child: Row(
                children: [
                  summary('Nas contas', total, color: total < 0 ? p.redInk : p.ink, note: 'sem vale e cartões'),
                  summary('Guardado', savedTotal, color: p.greenInk),
                  summary('A receber', toReceive),
                ],
              ),
            ),
            LcGroup(title: 'CONTAS', children: [for (final a in banks) row(a)]),
            if (cards.isNotEmpty) LcGroup(title: 'CARTÕES', children: [for (final a in cards) cardRow(a)]),
            if (vales.isNotEmpty) LcGroup(title: 'VALE', children: [for (final a in vales) row(a)]),
            LcGroup(
              title: 'GUARDADO',
              description:
                  'Envelopes para separar dinheiro (férias, reserva). Guardar tira do Disponível do mês sem ser gasto.',
              trailing: LcButton(
                'Novo envelope',
                small: true,
                kind: LcButtonKind.secondary,
                icon: LucideIcons.plus,
                onPressed: () => showEnvelopeEditor(context),
              ),
              children: [
                if (envs.isEmpty) const LcRow(title: 'Nenhum envelope ainda'),
                for (final e in envs) envRow(e),
              ],
            ),
            LcGroup(
              title: 'A RECEBER',
              description: 'Dinheiro que vai voltar. Quando voltar, entra sem dízimo.',
              trailing: LcButton(
                'Adicionar',
                small: true,
                kind: LcButtonKind.secondary,
                icon: LucideIcons.plus,
                onPressed: () => showReceivableEditor(context),
              ),
              children: [
                if (pendingReceivables.isEmpty) const LcRow(title: 'Nada a receber'),
                for (final r in pendingReceivables)
                  LcRow(
                    leading: Icon(LucideIcons.handCoins, size: 17, color: p.pencil),
                    title: r.description,
                    subtitle: r.dueDate == null ? null : 'Volta em ${formatDate(r.dueDate!)}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatBRL(r.amount), style: p.mono(14, weight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        LcButton('Recebi', small: true, onPressed: () => showReceive(context, r)),
                        LcIconButton(
                          LucideIcons.trash2,
                          tooltip: 'Excluir',
                          size: 15,
                          onPressed: () async {
                            if (await lcConfirm(
                              context,
                              'Excluir "${r.description}"?',
                              confirm: 'Excluir',
                              danger: true,
                            )) {
                              await scope.db.softDelete(scope.db.receivables, r.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (archived.isNotEmpty) LcGroup(title: 'ARQUIVADAS', children: [for (final a in archived) row(a)]),
          ],
        );
      },
    );
  }
}
