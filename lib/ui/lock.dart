// Bloqueio do app: PIN (4 a 6 dígitos) e, onde existir, digital/rosto.
// Trava ao abrir e ao voltar depois de mais de 1 minuto fora do app.
// O PIN fica só neste aparelho, guardado como hash (nunca o número em si).
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../data/app_data.dart';
import '../sync/crypto.dart' show randomBytes;
import 'kit/kit.dart';
import 'theme/paper.dart';

Future<String> hashPin(String pin, String salt) async =>
    base64.encode((await Sha256().hash(utf8.encode('$salt:$pin'))).bytes);

Future<(String hash, String salt)> newPinHash(String pin) async {
  final salt = base64.encode(randomBytes(16));
  return (await hashPin(pin, salt), salt);
}

/// Digital/rosto disponível neste aparelho?
Future<bool> biometricAvailable() async {
  if (!(Platform.isAndroid || Platform.isWindows)) return false;
  try {
    return await LocalAuthentication().isDeviceSupported();
  } catch (_) {
    return false;
  }
}

class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = true;
  bool _decided = false;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    final prefs = AppScope.of(context).prefs;
    // As preferências chegam do banco logo depois de abrir.
    void decide() {
      if (_decided) return;
      _decided = true;
      setState(() => _locked = prefs.lockEnabled);
    }

    Future<void>.delayed(const Duration(milliseconds: 400), decide);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _leftAt == null ? Duration.zero : DateTime.now().difference(_leftAt!);
      _leftAt = null;
      if (AppScope.of(context).prefs.lockEnabled && away > const Duration(minutes: 1)) setState(() => _locked = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final showLock = !_decided || (_locked && prefs.lockEnabled);
    return Stack(
      children: [
        // O app fica por baixo, mas invisível e sem receber toques.
        // ExcludeFocus: o teclado vai para o PIN, não para o app escondido.
        ExcludeFocus(
          excluding: showLock,
          child: Offstage(offstage: showLock, child: widget.child),
        ),
        if (showLock) _decided ? _LockScreen(onUnlock: () => setState(() => _locked = false)) : const _Blank(),
      ],
    );
  }
}

class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) => ColoredBox(color: Paper.of(context).paperShade, child: const SizedBox.expand());
}

class _LockScreen extends StatefulWidget {
  const _LockScreen({required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  String _pin = '';
  bool _wrong = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      final prefs = AppScope.of(context).prefs;
      if (prefs.lockBiometric) _biometric();
    });
  }

  Future<void> _biometric() async {
    try {
      final ok = await LocalAuthentication().authenticate(localizedReason: 'Abrir o Livro-Caixa');
      if (ok) widget.onUnlock();
    } catch (_) {}
  }

  Future<void> _type(String d) async {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += d;
      _wrong = false;
    });
    if (_pin.length < 4) return;
    final prefs = AppScope.of(context).prefs;
    if (await hashPin(_pin, prefs.lockSalt) == prefs.lockHash) {
      widget.onUnlock();
    } else if (_pin.length == 6) {
      HapticFeedback.heavyImpact();
      setState(() {
        _wrong = true;
        _pin = '';
      });
    }
  }

  void _back() => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1));

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final prefs = AppScope.of(context).prefs;
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => SizedBox(
      width: 76,
      height: 64,
      child: GestureDetector(
        onTap: onTap ?? () => _type(label),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: label.isEmpty && icon == null ? Colors.transparent : p.paper,
              borderRadius: BorderRadius.circular(14),
              border: label.isEmpty && icon == null ? null : Border.all(color: hairline(p)),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 20, color: p.ink)
                : Text(label, style: p.mono(22, weight: FontWeight.w600)),
          ),
        ),
      ),
    );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        // Lê pela tecla (funciona também no teclado numérico e onde o
        // sistema não manda o caractere).
        final label = e.logicalKey.keyLabel.replaceAll('Numpad ', '');
        final c = RegExp(r'^\d$').hasMatch(label) ? label : e.character;
        if (c != null && RegExp(r'^\d$').hasMatch(c)) {
          _type(c);
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.backspace) {
          _back();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: p.paperShade,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📒', style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 6),
                Text(
                  'Livro-Caixa',
                  style: p.hand(34, color: p.redInk, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _wrong ? 'PIN errado. Tente de novo.' : 'Digite o PIN',
                  style: TextStyle(fontSize: 14, color: _wrong ? p.redInk : p.pencil),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 6; i++)
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length ? p.ink : Colors.transparent,
                          border: Border.all(color: i < 4 ? p.ink.withValues(alpha: 0.5) : hairline(p)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) key(d)]),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    prefs.lockBiometric
                        ? key('', icon: LucideIcons.fingerprint, onTap: _biometric)
                        : key('', onTap: () {}),
                    key('0'),
                    key('', icon: LucideIcons.delete, onTap: _back),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Criar o PIN (pede duas vezes). Devolve true se salvou.
Future<bool> showSetPin(BuildContext context) async {
  final a = TextEditingController(), b = TextEditingController();
  String? error;
  final ok = await showLcDialog<bool>(
    context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => LcDialogBody(
        title: 'Criar PIN',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LcField(
              label: 'PIN (4 a 6 números)',
              controller: a,
              obscure: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 12),
            LcField(
              label: 'Repita o PIN',
              controller: b,
              obscure: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: TextStyle(color: Paper.of(c).redInk, fontSize: 13)),
              ),
            const SizedBox(height: 8),
            Text(
              'O PIN fica só neste aparelho. Se esquecer, apague os dados do app (os dados do Drive continuam).',
              style: TextStyle(fontSize: 12.5, color: Paper.of(c).pencil),
            ),
          ],
        ),
        actions: [
          LcButton('Cancelar', kind: LcButtonKind.ghost, onPressed: () => Navigator.pop(c, false)),
          LcButton(
            'Salvar',
            onPressed: () async {
              if (!RegExp(r'^\d{4,6}$').hasMatch(a.text)) return setState(() => error = 'Use de 4 a 6 números.');
              if (a.text != b.text) return setState(() => error = 'Os PINs não batem.');
              final (hash, salt) = await newPinHash(a.text);
              if (!c.mounted) return;
              await AppScope.of(c).prefs.setLock(hash, salt);
              if (c.mounted) Navigator.pop(c, true);
            },
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}
