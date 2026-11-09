import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/tithe.dart';
import '../ui/theme/fonts.dart';
import '../ui/theme/paper.dart';
import '../ui/theme/themes.dart';
import 'database.dart';

/// Preferências deste aparelho, guardadas na tabela `settings`.
class Prefs extends ChangeNotifier {
  Prefs(this._db) {
    _sub = _db.watchSettings().listen((v) {
      _values = v;
      notifyListeners();
    });
  }

  final AppDatabase _db;
  late final StreamSubscription<void> _sub;
  Map<String, String> _values = {};

  int _int(String k, int d) => int.tryParse(_values[k] ?? '') ?? d;
  String _str(String k, String d, [List<String>? allowed]) {
    final v = _values[k];
    return v != null && (allowed == null || allowed.contains(v)) ? v : d;
  }

  int get titheBp => _int('tithe_bp', defaultTitheBp);
  int get offeringBp => _int('offering_bp', defaultOfferingBp);

  /// Se a oferta já foi definida (nos Ajustes ou ao separar).
  bool get hasOfferingBp => _values.containsKey('offering_bp');
  String get handFont => _str('hand_font', defaultHandFont, handFonts);
  String get uiFont => _str('ui_font', defaultUiFont, uiFonts);
  String get lightTheme => _str('light_theme', 'papel');
  String get darkTheme => _str('dark_theme', 'noite');
  String get ink => _str('ink', 'folha');
  Ruling get ruling => Ruling.values.asNameMap()[_values['ruling']] ?? Ruling.pautada;
  bool get showMargin => _values['show_margin'] != '0';
  bool get grain => _values['grain'] != '0';
  bool get bookRings => _values['book_rings'] != '0';
  double get textScale => double.tryParse(_values['text_scale'] ?? '') ?? 1.0;

  bool get reminders => _values['reminders'] == '1';
  Future<void> setReminders(bool v) => _db.setSetting('reminders', v ? '1' : '0');

  // Bloqueio do app (só neste aparelho).
  bool get lockEnabled => (_values['lock_hash'] ?? '').isNotEmpty;
  String get lockHash => _values['lock_hash'] ?? '';
  String get lockSalt => _values['lock_salt'] ?? '';
  bool get lockBiometric => _values['lock_bio'] == '1';
  Future<void> setLock(String hash, String salt) async {
    await _db.setSetting('lock_salt', salt);
    await _db.setSetting('lock_hash', hash);
  }

  Future<void> clearLock() => _db.setSetting('lock_hash', '');
  Future<void> setLockBiometric(bool v) => _db.setSetting('lock_bio', v ? '1' : '0');

  Future<void> setUiFont(String v) => _db.setSetting('ui_font', v);
  Future<void> setLightTheme(String v) => _db.setSetting('light_theme', v);
  Future<void> setDarkTheme(String v) => _db.setSetting('dark_theme', v);
  Future<void> setInk(String v) => _db.setSetting('ink', v);
  Future<void> setRuling(Ruling v) => _db.setSetting('ruling', v.name);
  Future<void> setShowMargin(bool v) => _db.setSetting('show_margin', v ? '1' : '0');
  Future<void> setGrain(bool v) => _db.setSetting('grain', v ? '1' : '0');
  Future<void> setBookRings(bool v) => _db.setSetting('book_rings', v ? '1' : '0');
  Future<void> setTextScale(double v) => _db.setSetting('text_scale', '$v');

  /// Monta a aparência para claro ou escuro.
  Paper paper(Brightness b) => Paper.from(
    specById(b == Brightness.dark ? darkTheme : lightTheme),
    ink: ink,
    hand: handFont,
    mono: monoFont,
    ui: uiFont,
    ruling: ruling,
    showMargin: showMargin,
    grain: grain,
  );
  String get monoFont => _str('mono_font', defaultMonoFont, monoFonts);
  ThemeMode get themeMode => ThemeMode.values.asNameMap()[_values['theme_mode']] ?? ThemeMode.system;

  /// De quem é este aparelho (pessoa padrão ao lançar).
  String get mePerson => _str('me_person', 'seed-pessoa-1');
  Future<void> setMePerson(String id) => _db.setSetting('me_person', id);

  Future<void> setTitheBp(int v) => _db.setSetting('tithe_bp', '$v');
  Future<void> setOfferingBp(int v) => _db.setSetting('offering_bp', '$v');
  Future<void> setHandFont(String v) => _db.setSetting('hand_font', v);
  Future<void> setMonoFont(String v) => _db.setSetting('mono_font', v);
  Future<void> setThemeMode(ThemeMode v) => _db.setSetting('theme_mode', v.name);

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
