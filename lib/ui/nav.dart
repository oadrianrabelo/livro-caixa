// Ligação entre o "chassi" do app (atalhos, paleta de comandos, botão Lançar)
// e a página do mês, que é quem sabe qual mês está aberto.
import 'package:flutter/foundation.dart';

import '../core/dates.dart';

class MonthNav extends ChangeNotifier {
  String _month = monthOf(today());
  String get month => _month;

  // A página do mês registra aqui como navegar (com animação).
  /// Abre a paleta de comandos (registrado pelo chassi do app).
  VoidCallback? openPalette;

  /// Troca de aba (registrado pelo chassi do app). 1 = Mercado.
  void Function(int index)? goTab;

  void Function(int delta)? _go;
  VoidCallback? _today;

  void attach({required void Function(int) go, required VoidCallback today}) {
    _go = go;
    _today = today;
  }

  void detach() => _go = _today = null;

  void changed(String month) {
    _month = month;
    notifyListeners();
  }

  void go(int delta) => _go?.call(delta);
  void goToday() => _today?.call();

  /// Data padrão para um lançamento novo no mês aberto.
  String get defaultDate => _month == monthOf(today()) ? today() : '$_month-01';
}

final monthNav = MonthNav();
