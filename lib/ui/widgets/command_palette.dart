// Paleta de comandos (⌘K / Ctrl+K), no espírito do Raycast:
// digite para filtrar ações e lançamentos; ↑ ↓ escolhem, Enter executa, Esc fecha.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/tithe.dart';
import '../nav.dart';
import '../theme/paper.dart';
import 'entry_form.dart';
import 'shopping_calc.dart';
import 'kbd.dart';
import 'tithe_dialog.dart';

class _Command {
  const _Command(this.icon, this.title, this.run, {this.subtitle, this.trailing, this.keys});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final List<String>? keys;
  final Future<void> Function(BuildContext context) run;
}

/// [goTab]: troca a aba do app (0 Mês, 1 Lançamentos, 2 Ano, 3 Carteira, 4 Ajustes).
Future<void> showCommandPalette(BuildContext context, {required void Function(int) goTab}) => showGeneralDialog(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Fechar',
  barrierColor: Colors.black.withValues(alpha: 0.25),
  transitionDuration: const Duration(milliseconds: 140),
  transitionBuilder: (context, anim, _, child) => FadeTransition(
    opacity: anim,
    child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(anim), child: child),
  ),
  pageBuilder: (dialogContext, _, _) => _Palette(hostContext: context, goTab: goTab),
);

class _Palette extends StatefulWidget {
  const _Palette({required this.hostContext, required this.goTab});
  final BuildContext hostContext;
  final void Function(int) goTab;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  int _selected = 0;

  List<_Command> _commands() {
    final data = AppScope.of(context).data;
    final q = _query.text.trim().toLowerCase();
    final pending = pendingTithe(data.entries);
    final actions = <_Command>[
      _Command(LucideIcons.circleMinus, 'Novo gasto', (c) => showEntryForm(c, date: monthNav.defaultDate), keys: ['N']),
      _Command(
        LucideIcons.circlePlus,
        'Nova entrada',
        (c) => showEntryForm(c, type: EntryType.receita, date: monthNav.defaultDate),
        keys: ['E'],
      ),
      if (pending.isNotEmpty)
        _Command(
          LucideIcons.handCoins,
          'Separar dízimo e oferta',
          (c) => showTitheDialog(c, incomes: pending),
          subtitle: '${pending.length} entrada(s) pendente(s)',
        ),
      _Command(LucideIcons.calculator, 'Calculadora de compras', (c) => showShoppingCalc(c)),
      _Command(LucideIcons.calendarCheck, 'Ir para o mês atual', (c) async {
        widget.goTab(0);
        monthNav.goToday();
      }, keys: ['T']),
      _Command(LucideIcons.chevronLeft, 'Mês anterior', (c) async {
        widget.goTab(0);
        monthNav.go(-1);
      }, keys: ['←']),
      _Command(LucideIcons.chevronRight, 'Próximo mês', (c) async {
        widget.goTab(0);
        monthNav.go(1);
      }, keys: ['→']),
      _Command(LucideIcons.receiptText, 'Abrir lançamentos', (c) async => widget.goTab(1), keys: ['2']),
      _Command(LucideIcons.chartColumn, 'Abrir o ano', (c) async => widget.goTab(2), keys: ['3']),
      _Command(LucideIcons.wallet, 'Abrir a carteira', (c) async => widget.goTab(3), keys: ['4']),
      _Command(LucideIcons.slidersHorizontal, 'Abrir ajustes', (c) async => widget.goTab(4), keys: ['5']),
    ].where((a) => q.isEmpty || a.title.toLowerCase().contains(q)).toList();

    // Lançamentos que batem com a busca (os 30 mais recentes).
    final entries = q.length < 2
        ? <_Command>[]
        : (data.entries.where((e) => data.labelOf(e).toLowerCase().contains(q)).toList()
                ..sort((a, b) => b.date.compareTo(a.date)))
              .take(30)
              .map(
                (e) => _Command(
                  e.type == EntryType.receita ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                  data.labelOf(e),
                  (c) => showEntryForm(c, editing: e),
                  subtitle: '${formatDate(e.date)} · ${data.account(e.accountId)?.name ?? ''}',
                  trailing: formatBRL(e.amount),
                ),
              )
              .toList();
    return [...actions, ...entries];
  }

  void _run(_Command c) {
    Navigator.pop(context);
    c.run(widget.hostContext);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e, List<_Command> list) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1).clamp(0, list.length - 1));
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = (_selected - 1).clamp(0, list.length - 1));
    } else if (e.logicalKey == LogicalKeyboardKey.enter && list.isNotEmpty) {
      _run(list[_selected]);
    } else {
      return KeyEventResult.ignored;
    }
    _scroll.animateTo(
      (_selected * 48.0 - 120).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final list = _commands();
    if (_selected >= list.length) _selected = list.isEmpty ? 0 : list.length - 1;
    final size = MediaQuery.sizeOf(context);

    return Align(
      alignment: const Alignment(0, -0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600, maxHeight: size.height * 0.6),
          child: Material(
            color: p.paper,
            elevation: 24,
            shadowColor: Colors.black45,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: hairline(p)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Focus(
              onKeyEvent: (n, e) => _onKey(n, e, list),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                    child: Row(
                      children: [
                        Icon(LucideIcons.search, size: 18, color: p.pencil),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            autofocus: true,
                            style: const TextStyle(fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: 'Buscar lançamento ou ação…',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onChanged: (_) => setState(() => _selected = 0),
                          ),
                        ),
                        const Kbd(['Esc']),
                      ],
                    ),
                  ),
                  const Divider(),
                  Flexible(
                    child: list.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('Nada encontrado.', style: TextStyle(color: p.pencil)),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(6),
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final c = list[i];
                              final selected = i == _selected;
                              return MouseRegion(
                                onHover: (_) => _selected != i ? setState(() => _selected = i) : null,
                                child: GestureDetector(
                                  onTap: () => _run(c),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 80),
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: selected ? p.ink.withValues(alpha: 0.07) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(c.icon, size: 18, color: selected ? p.ink : p.pencil),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                              ),
                                              if (c.subtitle != null)
                                                Text(c.subtitle!, style: TextStyle(fontSize: 12, color: p.pencil)),
                                            ],
                                          ),
                                        ),
                                        if (c.trailing != null) Text(c.trailing!, style: p.mono(13)),
                                        if (c.keys != null && isDesktop) Kbd(c.keys!),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
