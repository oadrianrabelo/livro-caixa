import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../backup/backup.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/tithe.dart';
import '../../updates/updater.dart';
import '../kit/kit.dart';
import '../lock.dart';
import '../theme/fonts.dart';
import '../theme/paper.dart';
import '../theme/themes.dart';
import '../widgets/common.dart';
import '../widgets/editors.dart';
import '../widgets/sync_card.dart';
import '../widgets/wallet_sheets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.prefs, scope.data]),
      builder: (context, _) => const PageBody(
        title: 'Ajustes',
        children: [
          SyncCard(),
          _Privacy(),
          _Appearance(),
          _Tithe(),
          _Recurrings(),
          _Categories(),
          _People(),
          _Backup(),
          _About(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacidade e avisos
// ---------------------------------------------------------------------------

class _Privacy extends StatefulWidget {
  const _Privacy();

  @override
  State<_Privacy> createState() => _PrivacyState();
}

class _PrivacyState extends State<_Privacy> {
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    biometricAvailable().then((v) => mounted ? setState(() => _bio = v) : null);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final prefs = scope.prefs;
    return LcGroup(
      title: 'PRIVACIDADE E AVISOS',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              LcToggleRow(
                title: 'Bloquear com PIN',
                subtitle: 'Pede o PIN ao abrir e ao voltar depois de 1 minuto fora do app.',
                value: prefs.lockEnabled,
                onChanged: (v) async {
                  if (v) {
                    await showSetPin(context);
                  } else {
                    await prefs.clearLock();
                  }
                },
              ),
              if (prefs.lockEnabled && _bio)
                LcToggleRow(
                  title: 'Usar digital ou rosto',
                  value: prefs.lockBiometric,
                  onChanged: prefs.setLockBiometric,
                ),
              if (Platform.isAndroid)
                LcToggleRow(
                  title: 'Lembretes no celular',
                  subtitle: 'Contas que vencem (véspera e no dia), o vale que renova e o dízimo a separar.',
                  value: prefs.reminders,
                  onChanged: (v) async {
                    if (v && !await scope.extras.requestPermission()) {
                      if (context.mounted) {
                        lcToast(
                          context,
                          'Permita as notificações para receber os lembretes.',
                          icon: LucideIcons.bellOff,
                        );
                      }
                      return;
                    }
                    await prefs.setReminders(v);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Aparência
// ---------------------------------------------------------------------------

class _Appearance extends StatelessWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final p = Paper.of(context);
    final lights = paperSpecs.where((s) => !s.dark).toList();
    final darks = paperSpecs.where((s) => s.dark).toList();
    Widget sub(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Text(
        t,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.pencil),
      ),
    );
    Widget pad(Widget w) => Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: w);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcGroup(
          title: 'TEMA',
          trailing: LcSegmented<ThemeMode>(
            options: const [(ThemeMode.system, 'Auto'), (ThemeMode.light, 'Claro'), (ThemeMode.dark, 'Escuro')],
            value: prefs.themeMode,
            onChanged: prefs.setThemeMode,
          ),
          description: 'No "Auto", o app segue o sistema: usa o papel claro de dia e o escuro à noite.',
          children: [
            pad(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sub('Papel claro'),
                  _ThemeGallery(specs: lights, selected: prefs.lightTheme, onTap: prefs.setLightTheme),
                  const SizedBox(height: 14),
                  sub('Papel escuro'),
                  _ThemeGallery(specs: darks, selected: prefs.darkTheme, onTap: prefs.setDarkTheme),
                ],
              ),
            ),
            pad(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sub('Cor da caneta'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final o in inkOptions)
                        _InkDot(option: o, selected: prefs.ink == o.id, onTap: () => prefs.setInk(o.id)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        LcGroup(
          title: 'FOLHA',
          children: [
            pad(
              LcSegmented<Ruling>(
                expand: true,
                options: [for (final r in Ruling.values) (r, rulingNames[r]!)],
                value: prefs.ruling,
                onChanged: prefs.setRuling,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  LcToggleRow(title: 'Margem vermelha', value: prefs.showMargin, onChanged: prefs.setShowMargin),
                  LcToggleRow(
                    title: 'Textura de papel',
                    subtitle: 'Um granulado bem leve, como papel de verdade.',
                    value: prefs.grain,
                    onChanged: prefs.setGrain,
                  ),
                  LcToggleRow(
                    title: 'Argolas de fichário',
                    subtitle: 'No computador, entre as duas páginas do livro aberto.',
                    value: prefs.bookRings,
                    onChanged: prefs.setBookRings,
                  ),
                ],
              ),
            ),
          ],
        ),
        LcGroup(
          title: 'TIPOGRAFIA',
          children: [
            pad(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sub('Interface'),
                  _FontPicker(
                    fonts: uiFonts,
                    selected: prefs.uiFont,
                    onTap: prefs.setUiFont,
                    sample: (f) => Text(
                      'Lançar',
                      style: TextStyle(fontFamily: f, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 14),
                  sub('Letra de mão'),
                  _FontPicker(
                    fonts: handFonts,
                    selected: prefs.handFont,
                    onTap: prefs.setHandFont,
                    sample: (f) => Text('Setembro', style: p.copyWith(handFont: f).hand(22)),
                  ),
                  const SizedBox(height: 14),
                  sub('Números'),
                  _FontPicker(
                    fonts: monoFonts,
                    selected: prefs.monoFont,
                    onTap: prefs.setMonoFont,
                    sample: (f) => Text(r'R$ 1.234,56', style: p.copyWith(monoFont: f).mono(14)),
                  ),
                  const SizedBox(height: 14),
                  sub('Tamanho do texto'),
                  LcSegmented<double>(
                    expand: true,
                    options: textScales,
                    value: prefs.textScale,
                    onChanged: prefs.setTextScale,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Miniaturas dos papéis: um pedacinho de folha com pauta, margem e tinta.
class _ThemeGallery extends StatelessWidget {
  const _ThemeGallery({required this.specs, required this.selected, required this.onTap});
  final List<PaperSpec> specs;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final s in specs)
          GestureDetector(
            onTap: () => onTap(s.id),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 104,
                    height: 70,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected == s.id ? p.accent : hairline(p),
                        width: selected == s.id ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: CustomPaint(
                        painter: _SwatchPainter(s),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 8, 8, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Novembro',
                                style: TextStyle(fontFamily: p.handFont, fontSize: 15, color: s.redInk, height: 1),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r'R$ 405,30',
                                style: TextStyle(fontFamily: p.monoFont, fontSize: 9.5, color: s.ink),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected == s.id ? FontWeight.w600 : FontWeight.w500,
                      color: selected == s.id ? p.ink : p.pencil,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.s);
  final PaperSpec s;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = s.paper);
    final rule = Paint()..color = s.rule;
    for (var y = 22.0; y < size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    canvas.drawLine(const Offset(15, 0), Offset(15, size.height), Paint()..color = s.margin);
  }

  @override
  bool shouldRepaint(_SwatchPainter old) => old.s != s;
}

class _InkDot extends StatelessWidget {
  const _InkDot({required this.option, required this.selected, required this.onTap});
  final InkOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final color = (p.dark ? option.dark : option.light);
    return Tooltip(
      message: option.name,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? p.accent : Colors.transparent, width: 2),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                gradient: color == null ? SweepGradient(colors: [p.ink, p.redInk, p.greenInk, p.ink]) : null,
                border: Border.all(color: hairline(p)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FontPicker extends StatelessWidget {
  const _FontPicker({required this.fonts, required this.selected, required this.onTap, required this.sample});
  final List<String> fonts;
  final String selected;
  final ValueChanged<String> onTap;
  final Widget Function(String font) sample;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in fonts)
          Tooltip(
            message: f,
            child: GestureDetector(
              onTap: () => onTap(f),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == f ? p.ink.withValues(alpha: 0.06) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected == f ? p.accent : hairline(p), width: selected == f ? 1.6 : 1),
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: p.ink),
                    child: sample(f),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dízimo e oferta
// ---------------------------------------------------------------------------

class _Tithe extends StatelessWidget {
  const _Tithe();

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    return LcGroup(
      title: 'DÍZIMO E OFERTA',
      description:
          'Sugeridos no botão "Separar dízimo e oferta". Ao separar dá para ajustar na hora; '
          'o percentual da oferta digitado lá fica lembrado.',
      children: [
        LcRow(
          title: 'Dízimo',
          trailing: _PercentField(bp: prefs.titheBp, onSave: prefs.setTitheBp),
        ),
        LcRow(
          title: 'Oferta',
          trailing: _PercentField(bp: prefs.offeringBp, onSave: prefs.setOfferingBp),
        ),
      ],
    );
  }
}

/// Campo de percentual que salva ao sair do campo (ou Enter), sem perder o foco.
class _PercentField extends StatefulWidget {
  const _PercentField({required this.bp, required this.onSave});
  final int bp;
  final Future<void> Function(int) onSave;

  @override
  State<_PercentField> createState() => _PercentFieldState();
}

class _PercentFieldState extends State<_PercentField> {
  late final _controller = TextEditingController(text: _text(widget.bp));
  final _focus = FocusNode();

  static String _text(int bp) => formatBp(bp).replaceAll('%', '');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void didUpdateWidget(_PercentField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.bp != widget.bp) _controller.text = _text(widget.bp);
  }

  void _save() {
    final bp = parseBp(_controller.text);
    if (bp == null) {
      _controller.text = _text(widget.bp);
    } else if (bp != widget.bp) {
      widget.onSave(bp);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      textAlign: TextAlign.end,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Paper.of(context).mono(14),
      decoration: lcInputDecoration(context, suffix: '%'),
      onSubmitted: (_) => _save(),
      onTapOutside: (_) => _focus.unfocus(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Contas fixas, categorias, pessoas
// ---------------------------------------------------------------------------

class _Recurrings extends StatelessWidget {
  const _Recurrings();

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    return LcGroup(
      title: 'CONTAS FIXAS',
      description: 'Aparecem sozinhas todo mês para marcar ✓. Para criar, marque "Conta fixa" ao lançar.',
      children: [
        if (data.recurrings.isEmpty) const LcRow(title: 'Nenhuma ainda'),
        for (final r in data.recurrings)
          LcRow(
            dim: !r.active,
            leading: Icon(
              r.type == EntryType.receita ? LucideIcons.arrowDownLeft : LucideIcons.repeat,
              size: 17,
              color: Paper.of(context).pencil,
            ),
            title: r.description,
            subtitle: [
              'dia ${r.day}',
              r.variable ? 'valor muda' : formatBRL(r.amount),
              if (!r.active) 'parada',
            ].join(' · '),
            onTap: () => showRecurringEditor(context, r),
          ),
      ],
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories();

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final p = Paper.of(context);
    Widget row(Category c) => LcRow(
      leading: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(c.color).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(c.icon, style: const TextStyle(fontSize: 15)),
      ),
      title: c.name,
      subtitle: c.kind == CategoryKind.receita ? 'Entrada' : sectionLabels[c.section] ?? 'Outros',
      onTap: () => showCategoryEditor(context, editing: c),
    );
    final expenses = data.categories.where((c) => c.kind == CategoryKind.despesa).toList();
    final incomes = data.categories.where((c) => c.kind == CategoryKind.receita).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcGroup(
          title: 'CATEGORIAS DE GASTO',
          trailing: LcButton(
            'Nova',
            small: true,
            kind: LcButtonKind.secondary,
            icon: LucideIcons.plus,
            onPressed: () => showCategoryEditor(context),
          ),
          children: [for (final c in expenses) row(c)],
        ),
        LcGroup(title: 'CATEGORIAS DE ENTRADA', children: [for (final c in incomes) row(c)]),
        if (p.dark) const SizedBox.shrink(),
      ],
    );
  }
}

class _People extends StatelessWidget {
  const _People();

  Future<void> _rename(BuildContext context, Person person) async {
    final controller = TextEditingController(text: person.name);
    final name = await showLcDialog<String>(
      context,
      builder: (c) => LcDialogBody(
        title: 'Nome',
        content: LcField(controller: controller, autofocus: true, onSubmitted: (v) => Navigator.pop(c, v.trim())),
        actions: [
          LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(c)),
          LcButton('Salvar', onPressed: () => Navigator.pop(c, controller.text.trim())),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) await AppScope.of(context).db.renamePerson(person.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    return LcGroup(
      title: 'PESSOAS DA CASA',
      description: 'A pessoa deste aparelho vem marcada ao lançar.',
      children: [
        for (final person in scope.data.people)
          LcRow(
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: p.ink.withValues(alpha: 0.08),
              child: Text(
                person.name.characters.first,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink),
              ),
            ),
            title: person.name,
            subtitle: scope.prefs.mePerson == person.id ? 'Este aparelho' : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scope.prefs.mePerson != person.id)
                  LcButton(
                    'É este aparelho',
                    small: true,
                    kind: LcButtonKind.ghost,
                    onPressed: () => scope.prefs.setMePerson(person.id),
                  ),
                LcIconButton(
                  LucideIcons.pencil,
                  tooltip: 'Trocar o nome',
                  size: 15,
                  onPressed: () => _rename(context, person),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Backup e versão
// ---------------------------------------------------------------------------

class _Backup extends StatelessWidget {
  const _Backup();

  Future<void> _export(BuildContext context) async {
    final db = AppScope.of(context).db;
    final json = const JsonEncoder.withIndent('  ').convert(await exportData(db));
    final saved = await FilePicker.saveFile(
      fileName: 'livro-caixa-backup-${today()}.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
    );
    if (saved != null && context.mounted) lcToast(context, 'Backup salvo.');
  }

  Future<void> _import(BuildContext context) async {
    final db = AppScope.of(context).db;
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null) return;
    try {
      final result = await importData(db, jsonDecode(utf8.decode(await file.readAsBytes())));
      if (context.mounted) lcToast(context, 'Importado: $result.');
    } on FormatException catch (e) {
      if (context.mounted) lcToast(context, e.message, icon: LucideIcons.circleAlert);
    }
  }

  @override
  Widget build(BuildContext context) => LcGroup(
    title: 'BACKUP',
    description: 'Um arquivo com tudo. Importar junta com o que já existe: vale a edição mais recente.',
    children: [
      LcRow(
        leading: const Icon(LucideIcons.download, size: 17),
        title: 'Exportar backup',
        onTap: () => _export(context),
      ),
      LcRow(
        leading: const Icon(LucideIcons.upload, size: 17),
        title: 'Importar backup…',
        onTap: () => _import(context),
      ),
      LcRow(
        leading: const Icon(LucideIcons.fileSpreadsheet, size: 17),
        title: 'Importar extrato do Nubank (CSV)…',
        subtitle: 'Fatura do cartão ou extrato da conta',
        onTap: () => showImportCsv(context),
      ),
    ],
  );
}

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    final updater = AppScope.of(context).updater;
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final status = switch (updater.status) {
          UpdateStatus.idle || UpdateStatus.checking => 'Procurando atualização…',
          UpdateStatus.upToDate => 'Versão mais recente.',
          UpdateStatus.downloading =>
            'Baixando a ${updater.available?.version}'
                '${updater.progress != null ? ' (${(updater.progress! * 100).round()}%)' : ''}…',
          UpdateStatus.ready || UpdateStatus.permissionRequired => 'A ${updater.available?.version} está pronta.',
          UpdateStatus.installing => 'Instalando…',
          UpdateStatus.unsupported => updater.error ?? 'Atualização automática desligada (build local).',
          UpdateStatus.error => 'Não deu para verificar: ${updater.error}',
        };
        return LcGroup(
          title: 'SOBRE',
          children: [
            LcRow(
              leading: const Text('📒', style: TextStyle(fontSize: 18)),
              title: 'Livro-Caixa ${updater.currentVersion}',
              subtitle: status,
              trailing: updater.status == UpdateStatus.ready
                  ? LcButton('Atualizar', small: true, onPressed: updater.install)
                  : LcIconButton(LucideIcons.refreshCw, tooltip: 'Procurar agora', size: 16, onPressed: updater.check),
            ),
          ],
        );
      },
    );
  }
}
