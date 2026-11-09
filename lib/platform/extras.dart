// Recursos do celular: lembretes (notificações) e widget da tela inicial.
// No computador não fazem nada (lá os lembretes já aparecem nos post-its).
import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/dates.dart';
import '../core/money.dart';
import '../data/app_data.dart';
import '../data/database.dart';
import '../data/prefs.dart';
import '../domain/finance.dart';
import '../domain/tithe.dart';

class PhoneExtras {
  PhoneExtras(this._data, this._prefs) {
    if (!Platform.isAndroid) return;
    _data.addListener(_changed);
    _prefs.addListener(_changed);
    _changed();
  }

  final AppData _data;
  final Prefs _prefs;
  final _notes = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Timer? _debounce;

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      _updateWidget();
      _scheduleReminders();
    });
  }

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }
    await _notes.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
  }

  /// Pede a permissão de notificações (Android 13+). Devolve se foi concedida.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    await _init();
    final android = _notes.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'lembretes',
      'Lembretes',
      channelDescription: 'Contas que vencem, vale e dízimo a separar',
      importance: Importance.defaultImportance,
    ),
  );

  /// Reagenda tudo: contas que vencem (véspera e no dia, 9h), renovação do
  /// vale e dízimo a separar. Só os próximos 14 dias.
  Future<void> _scheduleReminders() async {
    try {
      await _init();
      await _notes.cancelAll();
      if (!_prefs.reminders) return;
      final now = tz.TZDateTime.now(tz.local);
      var id = 0;
      Future<void> at(DateTime day, int hour, String title, String body) async {
        final when = tz.TZDateTime(tz.local, day.year, day.month, day.day, hour);
        if (when.isBefore(now) || id >= 60) return;
        await _notes.zonedSchedule(
          id: id++,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
        );
      }

      final until = toIsoDate(DateTime.now().add(const Duration(days: 14)));
      final cards = {for (final c in _data.cards) c.id};
      for (final e in _data.entries) {
        if (e.type != EntryType.despesa || e.paid || cards.contains(e.accountId)) continue;
        if (_data.valeAccountIds.contains(e.accountId)) continue;
        if (e.date.compareTo(today()) < 0 || e.date.compareTo(until) > 0) continue;
        final due = DateTime.parse(e.date);
        final label = _data.labelOf(e);
        await at(due.subtract(const Duration(days: 1)), 9, 'Vence amanhã', '$label · ${formatBRL(e.amount)}');
        await at(due, 9, 'Vence hoje', '$label · ${formatBRL(e.amount)}');
      }
      for (final v in _data.accounts.where((a) => a.type == AccountType.vale && !a.archived)) {
        final d = v.renewDay ?? 20;
        final n = DateTime.now();
        final next = n.day < d ? DateTime(n.year, n.month, d) : DateTime(n.year, n.month + 1, d);
        await at(next, 9, 'O vale renova hoje', '${v.name}: ${formatBRL(v.renewAmount ?? 0)} de novo.');
      }
      final pending = pendingTithe(_data.entries);
      if (pending.isNotEmpty) {
        final total = pending.fold(0, (s, e) => s + e.amount);
        await at(
          DateTime.now().add(const Duration(days: 1)),
          19,
          'Dízimo a separar',
          'Entradas de ${formatBRL(total)} esperando.',
        );
      }
    } catch (_) {
      // Lembrete é um extra: se o aparelho não deixar, o app segue normal.
    }
  }

  /// Widget da tela inicial: Disponível, Sobrou e A pagar do mês.
  Future<void> _updateWidget() async {
    try {
      final month = monthOf(today());
      final s = monthSummary(
        _data.entries,
        _data.categories,
        month,
        valeAccounts: _data.valeAccountIds,
        cards: _data.cards,
      );
      await HomeWidget.saveWidgetData<String>('month', monthLabel(month).split(' de ').first);
      await HomeWidget.saveWidgetData<String>('available', formatBRL(s.available));
      await HomeWidget.saveWidgetData<String>('left', '${s.left >= 0 ? 'Sobra' : 'Falta'} ${formatBRL(s.left.abs())}');
      await HomeWidget.saveWidgetData<String>('unpaid', 'A pagar ${formatBRL(s.unpaid)}');
      await HomeWidget.updateWidget(androidName: 'LivroWidget');
    } catch (_) {}
  }
}
