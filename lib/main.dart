import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/app_data.dart';
import 'data/database.dart';
import 'data/prefs.dart';
import 'platform/extras.dart';
import 'sync/sync_controller.dart';
import 'updates/updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  final db = AppDatabase();
  final data = AppData(db);
  final prefs = Prefs(db);
  final sync = SyncController(db, data);
  final extras = PhoneExtras(data, prefs);
  final updater = Updater();
  // Procura atualização ao abrir, sem atrapalhar (erros ficam só na tela de Ajustes).
  updater.check();

  runApp(
    AppScope(
      db: db,
      data: data,
      prefs: prefs,
      updater: updater,
      sync: sync,
      extras: extras,
      child: const LivroCaixaApp(),
    ),
  );
}
