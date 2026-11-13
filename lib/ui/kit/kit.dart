// Kit de componentes do Livro-Caixa: a "cara" própria do app.
//
// Inspirado em Radix/Raycast: rótulo em cima do campo, bordas finas, poucos
// efeitos, foco visível, tudo com a mesma tinta e o mesmo papel do tema.
// Use estes no lugar dos componentes do Material (TextField com rótulo
// flutuante, DropdownButton, Checkbox, SegmentedButton, AlertDialog...).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/paper.dart';

export 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;

const _fast = Duration(milliseconds: 140);
BorderRadius get _r8 => BorderRadius.circular(8);

// ---------------------------------------------------------------------------
// Botões
// ---------------------------------------------------------------------------

enum LcButtonKind { primary, secondary, ghost, danger }

class LcButton extends StatefulWidget {
  const LcButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.kind = LcButtonKind.primary,
    this.small = false,
    this.trailing,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LcButtonKind kind;
  final bool small;
  final Widget? trailing;

  @override
  State<LcButton> createState() => _LcButtonState();
}

class _LcButtonState extends State<LcButton> {
  bool _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final enabled = widget.onPressed != null;
    final (bg, fg, border) = switch (widget.kind) {
      LcButtonKind.primary => (p.ink, p.paper, Colors.transparent),
      LcButtonKind.secondary => (p.paper, p.ink, hairline(p)),
      LcButtonKind.ghost => (Colors.transparent, p.ink, Colors.transparent),
      LcButtonKind.danger => (Colors.transparent, p.redInk, p.redInk.withValues(alpha: 0.35)),
    };
    final overlay = widget.kind == LcButtonKind.primary ? p.paper : p.ink;
    final h = widget.small ? 30.0 : 38.0;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = _down = false),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: _fast,
            child: AnimatedContainer(
              duration: _fast,
              height: h,
              padding: EdgeInsets.symmetric(horizontal: widget.small ? 10 : 14),
              decoration: BoxDecoration(
                color: Color.alphaBlend(overlay.withValues(alpha: _hover && enabled ? 0.08 : 0), bg),
                borderRadius: _r8,
                border: Border.all(color: border),
                boxShadow: widget.kind == LcButtonKind.primary
                    ? [BoxShadow(color: p.ink.withValues(alpha: 0.18), blurRadius: 2, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: widget.small ? 14 : 16, color: fg),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.small ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (widget.trailing != null) ...[const SizedBox(width: 8), widget.trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LcIconButton extends StatefulWidget {
  const LcIconButton(this.icon, {super.key, this.onPressed, this.tooltip, this.size = 18, this.color});
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  State<LcIconButton> createState() => _LcIconButtonState();
}

class _LcIconButtonState extends State<LcIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final enabled = widget.onPressed != null;
    final button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: _fast,
          width: widget.size + 16,
          height: widget.size + 16,
          decoration: BoxDecoration(
            color: _hover && enabled ? p.ink.withValues(alpha: 0.07) : Colors.transparent,
            borderRadius: _r8,
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: (widget.color ?? p.pencil).withValues(alpha: enabled ? 1 : 0.35),
          ),
        ),
      ),
    );
    return widget.tooltip == null ? button : Tooltip(message: widget.tooltip!, child: button);
  }
}

// ---------------------------------------------------------------------------
// Campos
// ---------------------------------------------------------------------------

/// Rótulo pequeno em cima do campo (em vez do rótulo que flutua do Material).
class LcLabel extends StatelessWidget {
  const LcLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Paper.of(context).pencil,
        letterSpacing: 0.1,
      ),
    ),
  );
}

InputDecoration lcInputDecoration(
  BuildContext context, {
  String? hint,
  String? prefix,
  String? suffix,
  Widget? prefixIcon,
}) {
  final p = Paper.of(context);
  final border = OutlineInputBorder(
    borderRadius: _r8,
    borderSide: BorderSide(color: hairline(p)),
  );
  return InputDecoration(
    hintText: hint,
    suffixText: suffix,
    // O "R$" fica sempre à vista (o prefixText do Material some com o campo vazio).
    prefixIcon:
        prefixIcon ??
        (prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 12, right: 2),
                child: Text(prefix, style: TextStyle(color: p.pencil, fontSize: 14.5)),
              )),
    prefixIconConstraints: prefix != null && prefixIcon == null
        ? const BoxConstraints()
        : const BoxConstraints(minWidth: 36),
    isDense: true,
    filled: true,
    fillColor: p.paper,
    contentPadding: EdgeInsets.fromLTRB(prefix != null && prefixIcon == null ? 4 : 12, 11, 12, 11),
    hintStyle: TextStyle(color: p.pencil.withValues(alpha: 0.65)),
    prefixStyle: TextStyle(color: p.pencil),
    suffixStyle: TextStyle(color: p.pencil),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: _r8,
      borderSide: BorderSide(color: p.accent, width: 1.6),
    ),
  );
}

class LcField extends StatefulWidget {
  const LcField({
    super.key,
    this.label,
    required this.controller,
    this.hint,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.obscure = false,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.money = false,
    this.capitalize = true,
  });
  final String? label;
  final TextEditingController controller;
  final String? hint, prefix, suffix;
  final TextInputType? keyboardType;
  final bool obscure, autofocus;
  final ValueChanged<String>? onChanged, onSubmitted;
  final FocusNode? focusNode;
  final int? maxLength;
  final TextAlign textAlign;
  final bool money; // fonte dos números, maior
  final bool capitalize; // primeira letra maiúscula (campos de texto)

  @override
  State<LcField> createState() => _LcFieldState();
}

class _LcFieldState extends State<LcField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  bool get _numeric => widget.keyboardType?.index == TextInputType.number.index;
  bool get _decimal => _numeric && (widget.keyboardType?.decimal ?? false);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(LcField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _own)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  /// Entrou num campo de número já preenchido: seleciona tudo, para digitar por cima.
  void _onFocus() {
    final c = widget.controller;
    if (_focus.hasFocus && _numeric && c.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_focus.hasFocus) c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
      });
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final signed = widget.keyboardType?.signed ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) LcLabel(widget.label!),
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          // Sem ação própria, o "Enter" do teclado pula para o próximo campo.
          textInputAction: widget.onSubmitted == null ? TextInputAction.next : TextInputAction.done,
          textCapitalization: widget.capitalize && !widget.obscure && !_numeric
              ? TextCapitalization.sentences
              : TextCapitalization.none,
          // Campos de número só aceitam número (e vírgula, nos de dinheiro).
          inputFormatters: [
            if (_decimal)
              FilteringTextInputFormatter.allow(RegExp(signed ? r'[0-9.,\-]' : r'[0-9.,]'))
            else if (_numeric)
              FilteringTextInputFormatter.digitsOnly,
          ],
          maxLength: widget.maxLength,
          textAlign: widget.textAlign,
          cursorColor: p.accent,
          style: widget.money ? p.mono(20, weight: FontWeight.w600) : TextStyle(fontSize: 14.5, color: p.ink),
          decoration: lcInputDecoration(
            context,
            hint: widget.hint,
            prefix: widget.prefix,
            suffix: widget.suffix,
          ).copyWith(counterText: ''),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seletor (popover)
// ---------------------------------------------------------------------------

class LcOption<T> {
  const LcOption(this.value, this.label, {this.leading, this.subtitle});
  final T value;
  final String label;
  final String? leading; // emoji ou símbolo
  final String? subtitle;
}

/// Fecha o teclado do celular. Escolher uma opção (tipo, conta, categoria)
/// não precisa dele, e ele tapava o formulário.
void hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

class LcSelect<T> extends StatefulWidget {
  const LcSelect({
    super.key,
    this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = 'Escolher…',
  });
  final String? label;
  final T value;
  final List<LcOption<T>> options;
  final ValueChanged<T> onChanged;
  final String placeholder;

  @override
  State<LcSelect<T>> createState() => _LcSelectState<T>();
}

class _LcSelectState<T> extends State<LcSelect<T>> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  bool _hover = false;
  double _width = 200;

  bool _up = false; // abre para cima quando falta espaço embaixo
  double _maxH = 300;

  double get _itemsHeight => widget.options.fold(8.0, (h, o) => h + (o.subtitle == null ? 36 : 46));

  void _toggle() {
    hideKeyboard();
    if (_portal.isShowing) {
      _portal.hide();
      setState(() {});
      return;
    }
    final mq = MediaQuery.of(context);
    // No celular, a lista abre numa folha: cabe tudo e os toques são folgados.
    if (mq.size.width < 600) {
      _openSheet();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    _width = box?.size.width ?? 200;
    final bottom = box == null ? 0.0 : box.localToGlobal(Offset(0, box.size.height)).dy;
    final below = mq.size.height - mq.viewInsets.bottom - bottom - 12;
    final above = bottom - 42 - mq.padding.top - 12;
    // Cabe embaixo? Abre para baixo. Senão, para o lado com mais espaço.
    _up = below < _itemsHeight && above > below;
    _maxH = math.min(math.max(_up ? above : below, 120), 420).toDouble();
    _portal.show();
    setState(() {});
  }

  Future<void> _openSheet() async {
    final picked = await showLcSheet<LcOption<T>>(
      context,
      builder: (_) => _SelectSheet<T>(title: widget.label, options: widget.options, value: widget.value),
    );
    if (picked != null) widget.onChanged(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final current = widget.options.where((o) => o.value == widget.value).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) LcLabel(widget.label!),
        CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (_) => _menu(context, p),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: _fast,
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(p.ink.withValues(alpha: _hover ? 0.03 : 0), p.paper),
                    borderRadius: _r8,
                    border: Border.all(
                      color: _portal.isShowing ? p.accent : hairline(p),
                      width: _portal.isShowing ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (current?.leading != null) ...[Text(current!.leading!), const SizedBox(width: 8)],
                      Expanded(
                        child: Text(
                          current?.label ?? widget.placeholder,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.5, color: current == null ? p.pencil : p.ink),
                        ),
                      ),
                      Icon(LucideIcons.chevronsUpDown, size: 15, color: p.pencil),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menu(BuildContext context, Paper p) {
    // Abre já mostrando a opção escolhida.
    final index = widget.options.indexWhere((o) => o.value == widget.value);
    final scroll = ScrollController(initialScrollOffset: index <= 0 ? 0 : math.max(0, index * 36.0 - _maxH / 2 + 18));
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toggle),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: _up ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: _up ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(0, _up ? -4 : 4),
          child: _PopIn(
            child: Container(
              width: _width,
              constraints: BoxConstraints(maxHeight: _maxH),
              decoration: BoxDecoration(
                color: p.paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: hairline(p)),
                boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(4),
                shrinkWrap: true,
                children: [
                  for (final o in widget.options)
                    _MenuItem(
                      option: o,
                      selected: o.value == widget.value,
                      onTap: () {
                        _toggle();
                        widget.onChanged(o.value);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A lista de opções numa folha (celular). Com muitas opções, ganha uma busca.
class _SelectSheet<T> extends StatefulWidget {
  const _SelectSheet({required this.title, required this.options, required this.value});
  final String? title;
  final List<LcOption<T>> options;
  final T value;

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final mq = MediaQuery.of(context);
    final q = _query.text.trim().toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (q.isEmpty || o.label.toLowerCase().contains(q)) o,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  widget.title!,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink, letterSpacing: -0.3),
                ),
              ),
            if (widget.options.length > 10)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  cursorColor: p.accent,
                  style: TextStyle(fontSize: 14.5, color: p.ink),
                  decoration: lcInputDecoration(
                    context,
                    hint: 'Buscar…',
                    prefixIcon: Icon(LucideIcons.search, size: 16, color: p.pencil),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(8, 0, 8, 12 + mq.padding.bottom),
                children: [
                  for (final o in shown)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context, o);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: o.value == widget.value ? p.ink.withValues(alpha: 0.06) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (o.leading != null) ...[
                              SizedBox(width: 28, child: Text(o.leading!, style: const TextStyle(fontSize: 17))),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(o.label, style: TextStyle(fontSize: 15.5, color: p.ink)),
                                  if (o.subtitle != null)
                                    Text(o.subtitle!, style: TextStyle(fontSize: 12.5, color: p.pencil)),
                                ],
                              ),
                            ),
                            if (o.value == widget.value) Icon(LucideIcons.check, size: 17, color: p.accent),
                          ],
                        ),
                      ),
                    ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nada encontrado', style: TextStyle(color: p.pencil)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem<T> extends StatefulWidget {
  const _MenuItem({required this.option, required this.selected, required this.onTap});
  final LcOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MenuItem<T>> createState() => _MenuItemState<T>();
}

class _MenuItemState<T> extends State<_MenuItem<T>> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final o = widget.option;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: o.subtitle == null ? 36 : 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover ? p.ink.withValues(alpha: 0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              if (o.leading != null) ...[SizedBox(width: 22, child: Text(o.leading!)), const SizedBox(width: 6)],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.label,
                      style: TextStyle(fontSize: 14, color: p.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (o.subtitle != null) Text(o.subtitle!, style: TextStyle(fontSize: 12, color: p.pencil)),
                  ],
                ),
              ),
              if (widget.selected) Icon(LucideIcons.check, size: 15, color: p.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: _fast,
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * -4), child: child),
    ),
    child: child,
  );
}

// ---------------------------------------------------------------------------
// Interruptores, caixinhas, segmentado, chips
// ---------------------------------------------------------------------------

class LcSwitch extends StatelessWidget {
  const LcSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return GestureDetector(
      onTap: onChanged == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              hideKeyboard();
              onChanged!(!value);
            },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: _fast,
          width: 36,
          height: 21,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? p.accent : p.ink.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99),
          ),
          child: AnimatedAlign(
            duration: _fast,
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 17,
              height: 17,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha "título + descrição ........ [interruptor]".
class LcToggleRow extends StatelessWidget {
  const LcToggleRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.ink),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: TextStyle(fontSize: 12.5, color: p.pencil, height: 1.35)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            LcSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class LcSegmented<T> extends StatelessWidget {
  const LcSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.expand = false,
  });
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final children = [
      for (final (v, label) in options)
        _wrap(
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              hideKeyboard();
              onChanged(v);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: _fast,
                height: 32,
                padding: EdgeInsets.symmetric(horizontal: expand ? 6 : 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == value ? p.paper : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: v == value
                      ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: v == value ? FontWeight.w600 : FontWeight.w500,
                      color: v == value ? p.ink : p.pencil,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.ink.withValues(alpha: 0.06), borderRadius: _r8),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: children),
    );
  }

  Widget _wrap(Widget w) => expand ? Expanded(child: w) : w;
}

class LcChip extends StatelessWidget {
  const LcChip(this.label, {super.key, required this.selected, required this.onTap, this.leading});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        hideKeyboard();
        onTap();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: _fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? p.ink : p.paper,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? p.ink : hairline(p)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: selected ? p.paper : p.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grupos (como os Ajustes do Mac)
// ---------------------------------------------------------------------------

class LcGroup extends StatelessWidget {
  const LcGroup({super.key, this.title, this.description, required this.children, this.trailing});
  final String? title, description;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.pencil, letterSpacing: 0.2),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: p.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hairline(p)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 14, color: hairline(p)),
                  children[i],
                ],
              ],
            ),
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(description!, style: TextStyle(fontSize: 12.5, color: p.pencil, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

/// Linha de um [LcGroup]: [ícone] título/subtítulo ........ [à direita]
class LcRow extends StatefulWidget {
  const LcRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dim = false,
  });
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  final bool dim;

  @override
  State<LcRow> createState() => _LcRowState();
}

class _LcRowState extends State<LcRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _fast,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: _hover && widget.onTap != null ? p.ink.withValues(alpha: 0.03) : Colors.transparent,
          child: Opacity(
            opacity: widget.dim ? 0.5 : 1,
            child: Row(
              children: [
                if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.ink),
                      ),
                      if (widget.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.subtitle!,
                            style: TextStyle(fontSize: 12.5, color: p.pencil, height: 1.35),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[const SizedBox(width: 10), widget.trailing!],
                if (widget.onTap != null && widget.trailing == null)
                  Icon(LucideIcons.chevronRight, size: 16, color: p.pencil.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogos, confirmação, aviso (toast)
// ---------------------------------------------------------------------------

Future<T?> showLcDialog<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  double width = 420,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Fechar',
  barrierColor: Colors.black.withValues(alpha: 0.28),
  transitionDuration: const Duration(milliseconds: 160),
  transitionBuilder: (context, anim, _, child) {
    final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: t,
      child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(t), child: child),
    );
  },
  pageBuilder: (dialogContext, _, _) {
    final p = Paper.of(dialogContext);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            // A sombra fica por fora do recorte (por dentro, vazava nas bordas).
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 16))],
              ),
              child: Material(
                color: p.paper,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: hairline(p)),
                ),
                clipBehavior: Clip.antiAlias,
                child: builder(dialogContext),
              ),
            ),
          ),
        ),
      ),
    );
  },
);

/// Corpo padrão de diálogo: título, conteúdo e botões à direita.
class LcDialogBody extends StatelessWidget {
  const LcDialogBody({super.key, required this.title, this.content, this.actions = const []});
  final String title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink, letterSpacing: -0.3),
          ),
          if (content != null) ...[const SizedBox(height: 12), content!],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

Future<bool> lcConfirm(
  BuildContext context,
  String message, {
  String confirm = 'Confirmar',
  bool danger = false,
  String title = 'Tem certeza?',
}) async {
  final ok = await showLcDialog<bool>(
    context,
    builder: (c) => LcDialogBody(
      title: title,
      content: Text(message, style: TextStyle(fontSize: 14, color: Paper.of(c).ink, height: 1.45)),
      actions: [
        LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(c, false)),
        LcButton(
          confirm,
          kind: danger ? LcButtonKind.danger : LcButtonKind.primary,
          onPressed: () => Navigator.pop(c, true),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Aviso rápido que aparece e some (no lugar do SnackBar).
/// Aviso rápido no rodapé. Com [actionLabel]/[onAction] vira tocável
/// (ex.: "Desfazer") e fica um pouco mais na tela.
void lcToast(
  BuildContext context,
  String message, {
  IconData icon = LucideIcons.circleCheck,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  late OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  final overlay = Overlay.of(context, rootOverlay: true);
  final p = Paper.of(context);
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.paddingOf(context).bottom + 80,
      child: IgnorePointer(
        ignoring: onAction == null,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: p.ink,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: p.paper),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(message, style: TextStyle(fontSize: 13.5, color: p.paper, height: 1.35)),
                    ),
                    if (onAction != null) ...[
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () {
                          remove();
                          onAction();
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Text(
                            actionLabel ?? 'Desfazer',
                            style: TextStyle(fontSize: 13.5, color: p.accent, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(Duration(milliseconds: onAction == null ? 2800 : 5000), remove);
}

// ---------------------------------------------------------------------------
// Calendário (no lugar do seletor de data do Material)
// ---------------------------------------------------------------------------

const _weekdays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
const _months = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

Future<DateTime?> showLcDatePicker(BuildContext context, DateTime initial) =>
    showLcDialog<DateTime>(context, width: 340, builder: (c) => _Calendar(initial: initial));

class _Calendar extends StatefulWidget {
  const _Calendar({required this.initial});
  final DateTime initial;

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final today = DateTime.now();
    final first = DateTime(_month.year, _month.month);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = first.weekday % 7; // domingo = 0
    bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_months[_month.month - 1]} ${_month.year}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.ink),
                ),
              ),
              LcIconButton(
                LucideIcons.chevronLeft,
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              LcIconButton(
                LucideIcons.chevronRight,
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(fontSize: 12, color: p.pencil, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < offset; i++) const SizedBox(),
              for (var d = 1; d <= days; d++)
                Builder(
                  builder: (context) {
                    final date = DateTime(_month.year, _month.month, d);
                    final selected = same(date, widget.initial);
                    final isToday = same(date, today);
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, date),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: selected ? p.ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday && !selected ? Border.all(color: p.accent) : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$d',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected || isToday ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? p.paper : p.ink,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LcButton(
                'Hoje',
                small: true,
                kind: LcButtonKind.secondary,
                onPressed: () => Navigator.pop(context, DateTime(today.year, today.month, today.day)),
              ),
              LcButton('Cancelar', small: true, kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(context)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Folha inferior (formulários)
// ---------------------------------------------------------------------------

Future<T?> showLcSheet<T>(BuildContext context, {required WidgetBuilder builder, double maxWidth = 560}) {
  final p = Paper.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: p.paper,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    constraints: BoxConstraints(maxWidth: maxWidth),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      side: BorderSide(color: hairline(p)),
    ),
    builder: builder,
  );
}
