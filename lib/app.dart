import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_data.dart';
import 'data/database.dart';
import 'ui/lock.dart';
import 'ui/nav.dart';
import 'ui/pages/accounts_page.dart';
import 'ui/pages/entries_page.dart';
import 'ui/pages/month_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/year_page.dart';
import 'ui/theme/paper.dart';
import 'ui/widgets/command_palette.dart';
import 'ui/widgets/entry_form.dart';
import 'ui/widgets/kbd.dart';
import 'ui/widgets/sync_card.dart';
import 'sync/sync_controller.dart';
import 'ui/widgets/update_banner.dart';

const appName = 'Livro-Caixa';

class LivroCaixaApp extends StatelessWidget {
  const LivroCaixaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SoftScrollBehavior(),
        theme: paperTheme(prefs.paper(Brightness.light)),
        darkTheme: paperTheme(prefs.paper(Brightness.dark)),
        themeMode: prefs.themeMode,
        // Tamanho do texto escolhido nos Ajustes (multiplica o do sistema).
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: _Scaled(mq.textScaler, prefs.textScale)),
            child: child!,
          );
        },
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const LockGate(child: Shell()),
      ),
    );
  }
}

class _Scaled extends TextScaler {
  const _Scaled(this.base, this.factor);
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.scale(1) * factor;
}

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon, this.page);
  final String label;
  final IconData icon, selectedIcon;
  final Widget page;
}

const _destinations = [
  _Dest('Mês', LucideIcons.bookOpen, LucideIcons.bookOpen, MonthPage()),
  _Dest('Lançamentos', LucideIcons.list, LucideIcons.list, EntriesPage()),
  _Dest('Ano', LucideIcons.chartColumn, LucideIcons.chartColumn, YearPage()),
  _Dest('Carteira', LucideIcons.wallet, LucideIcons.wallet, AccountsPage()),
  _Dest('Ajustes', LucideIcons.settings2, LucideIcons.settings2, SettingsPage()),
];

/// Chassi do app: barra lateral (computador) ou barra inferior (celular),
/// botão Lançar, atalhos de teclado e paleta de comandos.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  int _index = 0;

  // Trocar de aba: a página nova entra com um leve esmaecer e subir.
  late final _tabIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  late final _tabCurve = CurvedAnimation(parent: _tabIn, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    monthNav.openPalette = _palette;
  }

  @override
  void dispose() {
    _tabIn.dispose();
    super.dispose();
  }

  void _goTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _tabIn.forward(from: 0);
  }

  void _palette() => showCommandPalette(context, goTab: _goTab);
  void _newExpense() => showEntryForm(context, date: monthNav.defaultDate);
  void _newIncome() => showEntryForm(context, type: EntryType.receita, date: monthNav.defaultDate);

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.keyK, control: true): _palette,
    const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _palette,
    const SingleActivator(LogicalKeyboardKey.keyN): _newExpense,
    const SingleActivator(LogicalKeyboardKey.keyE): _newIncome,
    const SingleActivator(LogicalKeyboardKey.keyT): () {
      _goTab(0);
      monthNav.goToday();
    },
    const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _index == 0 ? monthNav.go(-1) : null,
    const SingleActivator(LogicalKeyboardKey.arrowRight): () => _index == 0 ? monthNav.go(1) : null,
    for (var i = 0; i < _destinations.length; i++)
      SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i)): () => _goTab(i),
  };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final p = Paper.of(context);
    final showLaunch = _index <= 1;
    final pages = Stack(
      children: [
        Column(
          children: [
            const UpdateBanner(),
            Expanded(
              // Só a aba aberta é montada (e recalculada a cada mudança). O Mês fica
              // sempre montado para não perder a página em que você estava.
              child: FadeTransition(
                opacity: _tabCurve,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(_tabCurve),
                  child: IndexedStack(
                    index: _index,
                    children: [
                      for (var i = 0; i < _destinations.length; i++)
                        if (i == 0)
                          TickerMode(enabled: _index == 0, child: _destinations[0].page)
                        else if (i == _index)
                          _destinations[i].page
                        else
                          const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showLaunch)
          Positioned(
            right: wide ? 28 : 16,
            bottom: wide ? 24 : 16,
            child: _LaunchButton(onPressed: _newExpense, showKey: wide && isDesktop),
          ),
      ],
    );

    final body = wide
        ? Row(
            children: [
              _Sidebar(index: _index, onSelect: _goTab, onSearch: _palette),
              VerticalDivider(width: 1, color: hairline(p)),
              Expanded(child: pages),
            ],
          )
        : Column(
            children: [
              Expanded(child: SafeArea(bottom: false, child: pages)),
              _TabBar(index: _index, onSelect: _goTab),
            ],
          );

    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(autofocus: true, child: Scaffold(resizeToAvoidBottomInset: false, body: body)),
    );
  }
}

/// Barra lateral no estilo Arc/Raycast: marca, busca (⌘K) e itens discretos.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelect, required this.onSearch});
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return Container(
      width: 236,
      color: p.paperShade,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
            // Letras largas (Excalifont, Coming Soon) encolhem em vez de quebrar a linha.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '📒 $appName',
                maxLines: 1,
                style: p.hand(28, color: p.redInk, weight: FontWeight.w700),
              ),
            ),
          ),
          _SidebarSearch(onTap: onSearch),
          const SizedBox(height: 14),
          for (var i = 0; i < _destinations.length; i++)
            _SidebarItem(dest: _destinations[i], selected: i == index, shortcut: '${i + 1}', onTap: () => onSelect(i)),
          const Spacer(),
          ListenableBuilder(
            listenable: AppScope.of(context).sync,
            builder: (context, _) {
              final sync = AppScope.of(context).sync;
              if (!sync.enabled) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Row(
                  children: [
                    const SyncDot(),
                    const SizedBox(width: 8),
                    Text(switch (sync.status) {
                      SyncStatus.syncing => 'Sincronizando…',
                      SyncStatus.error => 'Sem sincronizar',
                      SyncStatus.needsPassphrase => 'Falta a senha da casa',
                      _ => 'Sincronizado',
                    }, style: TextStyle(fontSize: 12.5, color: p.pencil)),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'N gasto · E entrada · ← → mês',
              style: TextStyle(fontSize: 11.5, color: p.pencil.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSearch extends StatelessWidget {
  const _SidebarSearch({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return Material(
      color: p.paper.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: hairline(p)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 16, color: p.pencil),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Buscar…', style: TextStyle(fontSize: 13.5, color: p.pencil)),
              ),
              if (isDesktop) Kbd([Kbd.mod, 'K']),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({required this.dest, required this.selected, required this.shortcut, required this.onTap});
  final _Dest dest;
  final bool selected;
  final String shortcut;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final selected = widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? p.paper
                  : _hover
                  ? p.ink.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? hairline(p) : Colors.transparent),
              boxShadow: selected
                  ? const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? widget.dest.selectedIcon : widget.dest.icon,
                  size: 18,
                  color: selected ? p.ink : p.pencil,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.dest.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? p.ink : p.pencil,
                    ),
                  ),
                ),
                if (_hover && isDesktop) Kbd([widget.shortcut]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior do celular: ícone + rótulo, sem "pílula" do Android.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.paperShade,
        border: Border(top: BorderSide(color: hairline(p))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(i);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: i == index ? 1.08 : 1,
                          duration: const Duration(milliseconds: 140),
                          child: Icon(
                            i == index ? _destinations[i].selectedIcon : _destinations[i].icon,
                            size: 22,
                            color: i == index ? p.ink : p.pencil.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _destinations[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                            color: i == index ? p.ink : p.pencil.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão principal: tinta escura, cantos suaves, atalho visível no computador.
class _LaunchButton extends StatelessWidget {
  const _LaunchButton({required this.onPressed, required this.showKey});
  final VoidCallback onPressed;
  final bool showKey;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return Material(
      color: p.ink,
      elevation: 6,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        hoverColor: p.paper.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.pencilLine, size: 16, color: p.paper),
              const SizedBox(width: 8),
              Text(
                'Lançar',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.paper),
              ),
              if (showKey) ...[
                const SizedBox(width: 8),
                const Kbd(['N'], inverted: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
