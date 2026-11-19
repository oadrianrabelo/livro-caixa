// Dias úteis no Brasil: fins de semana e feriados nacionais (incluindo os
// móveis: Carnaval, Sexta-feira Santa e Corpus Christi, quando os bancos
// fecham). Feriados estaduais e municipais não entram.

/// Domingo de Páscoa (algoritmo de Meeus/Jones/Butcher).
DateTime easter(int year) {
  final a = year % 19, b = year ~/ 100, c = year % 100;
  final d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

final Map<int, Set<String>> _cache = {};

Set<String> _holidays(int year) => _cache.putIfAbsent(year, () {
  String k(DateTime d) => '${d.month}-${d.day}';
  final p = easter(year);
  return {
    '1-1', '4-21', '5-1', '9-7', '10-12', '11-2', '11-15', '11-20', '12-25', // fixos
    k(p.subtract(const Duration(days: 48))), // Carnaval (segunda)
    k(p.subtract(const Duration(days: 47))), // Carnaval (terça)
    k(p.subtract(const Duration(days: 2))), // Sexta-feira Santa
    k(p.add(const Duration(days: 60))), // Corpus Christi
  };
});

bool isHoliday(DateTime d) => _holidays(d.year).contains('${d.month}-${d.day}');

bool isBusinessDay(DateTime d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday && !isHoliday(d);

/// O próprio dia, se for útil; senão, o dia útil anterior (ex.: o vale do
/// dia 20 que cai num feriado entra no dia 19).
DateTime businessDayOnOrBefore(DateTime d) {
  var x = DateTime(d.year, d.month, d.day);
  while (!isBusinessDay(x)) {
    x = x.subtract(const Duration(days: 1));
  }
  return x;
}
