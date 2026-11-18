// Dinheiro é SEMPRE guardado em centavos (int).
// Nunca use double para dinheiro: 0.1 + 0.2 != 0.3.
import 'package:intl/intl.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

/// 123456 -> "R$ 1.234,56"
String formatBRL(int cents) => _brl.format(cents / 100);

/// Converte o que o usuário digitou em centavos.
/// Aceita "1.234,56", "1234,56", "1234.56", "R$ 12", "12".
/// Retorna null se não for um valor válido.
int? parseBRL(String input) {
  var s = input.replaceAll(RegExp(r'[R$\s]'), '');
  if (s.isEmpty) return null;

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma > lastDot) {
    // vírgula é decimal (padrão BR): remove pontos de milhar
    s = s.replaceAll('.', '').replaceFirst(',', '.');
  } else if (lastDot > -1 && lastComma > -1) {
    // ponto é decimal e vírgula é milhar (padrão US)
    s = s.replaceAll(',', '');
  } else if (lastDot > -1 && RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    // "1.234" sem decimais -> milhar
    s = s.replaceAll('.', '');
  }

  if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(s)) return null;
  final negative = s.startsWith('-');
  final parts = s.replaceFirst('-', '').split('.');
  final dec = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  final cents = int.parse(parts[0]) * 100 + int.parse(dec);
  return negative ? -cents : cents;
}

/// Centavos -> texto editável num campo ("1234,56")
String centsToInput(int cents) {
  final s = cents.abs().toString().padLeft(3, '0');
  final intPart = s.substring(0, s.length - 2);
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '${cents < 0 ? '-' : ''}$buf,${s.substring(s.length - 2)}';
}
