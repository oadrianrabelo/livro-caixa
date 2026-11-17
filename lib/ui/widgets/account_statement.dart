// Extrato de uma conta: de onde veio o saldo, lançamento por lançamento.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';
import 'editors.dart';
import 'entry_form.dart';

Future<void> showAccountStatement(BuildContext context, Account account) =>
    showLcSheet<void>(context, maxWidth: 600, builder: (_) => _Statement(accountId: account.id));

class _Statement extends StatelessWidget {
  const _Statement({required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final p = Paper.of(context);
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final a = data.account(accountId);
        if (a == null) return const SizedBox(height: 120);
        final lines = accountStatement(a, data.entries);
        final balance = lines.isEmpty ? a.initialBalance : lines.last.after;
        final pending = [
          for (final e in data.entries)
            if (e.deletedAt == null && !e.paid && deltaFor(a, e) != 0) e,
        ]..sort((x, y) => x.date.compareTo(y.date));

        Widget line(Entry e, int delta, {int? after, bool dim = false}) => LcRow(
          dim: dim,
          title: data.labelOf(e),
          subtitle: [
            formatDate(e.date),
            if (e.type == EntryType.transferencia)
              delta > 0
                  ? 'de ${data.account(e.accountId)?.name ?? '?'}'
                  : 'para ${data.account(e.toAccountId)?.name ?? '?'}',
          ].join(' · '),
          onTap: () => showEntryForm(context, editing: e),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${delta > 0 ? '+' : '−'} ${formatBRL(delta.abs())}',
                style: p.mono(13.5, weight: FontWeight.w600, color: delta > 0 ? p.greenInk : p.ink),
              ),
              if (after != null)
                Text(
                  'fica ${formatBRL(after)}',
                  style: TextStyle(fontSize: 11.5, color: after < 0 ? p.redInk : p.pencil),
                ),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      a.name,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink, letterSpacing: -0.3),
                    ),
                  ),
                  LcButton(
                    'Editar',
                    icon: LucideIcons.pencil,
                    small: true,
                    kind: LcButtonKind.ghost,
                    onPressed: () => showAccountEditor(context, editing: a),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Saldo agora', style: TextStyle(fontSize: 12.5, color: p.pencil)),
              Text(
                formatBRL(balance),
                style: p.mono(28, weight: FontWeight.w700, color: balance < 0 ? p.redInk : p.ink),
              ),
              const SizedBox(height: 16),
              LcGroup(
                title: 'EXTRATO',
                description:
                    'Só contam os lançamentos pagos. Toque num deles para corrigir (conta, valor, data ou "Já pago").',
                children: [
                  for (final l in lines.reversed) line(l.entry, l.delta, after: l.after),
                  LcRow(
                    title: 'Saldo inicial',
                    subtitle: 'O ponto de partida da conta (em Editar → Saldo atual)',
                    trailing: Text(
                      formatBRL(a.initialBalance),
                      style: p.mono(13.5, weight: FontWeight.w600, color: a.initialBalance < 0 ? p.redInk : p.ink),
                    ),
                  ),
                ],
              ),
              if (pending.isNotEmpty)
                LcGroup(
                  title: 'AINDA NÃO PAGOS',
                  description: 'Lançados nesta conta, mas fora do saldo até serem marcados como pagos.',
                  children: [for (final e in pending) line(e, deltaFor(a, e), dim: true)],
                ),
            ],
          ),
        );
      },
    );
  }
}
