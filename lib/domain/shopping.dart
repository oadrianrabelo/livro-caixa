// Histórico do mercado: o que mais se compra, quanto costuma custar e o que
// já está na hora de comprar de novo (para montar a lista).
import '../data/database.dart';

/// "Arroz  Tio João" e "arroz tio joão" contam como o mesmo item.
String normalizeItem(String name) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final lower = name.trim().toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
}

class ProductStats {
  ProductStats(this.key, this.name);
  final String key; // nome normalizado
  String name; // como foi escrito da última vez
  int trips = 0; // em quantas compras apareceu
  int units = 0;
  int lastPrice = 0;
  String lastDate = '';
  int _sum = 0, _count = 0;
  int minPrice = 0, maxPrice = 0;
  final List<String> _dates = [];

  int get avgPrice => _count == 0 ? 0 : (_sum / _count).round();

  /// Intervalo médio entre compras, em dias (null se comprou só uma vez).
  double? get everyDays {
    if (_dates.length < 2) return null;
    final first = DateTime.parse(_dates.first), last = DateTime.parse(_dates.last);
    return last.difference(first).inDays / (_dates.length - 1);
  }

  /// Já passou do intervalo de costume desde a última compra.
  bool dueOn(DateTime today) {
    final every = everyDays;
    if (every == null || every < 1) return false;
    return today.difference(DateTime.parse(lastDate)).inDays >= every * 0.8;
  }

  /// Último preço comparado à média: +0,12 = 12% mais caro que o normal.
  double get priceChange => avgPrice == 0 ? 0 : (lastPrice - avgPrice) / avgPrice;
}

/// Estatísticas por item. [liveEntries]: ids dos lançamentos que ainda existem
/// (se a compra foi excluída, os itens dela não contam).
List<ProductStats> productStats(Iterable<ShopItem> items, Set<String> liveEntries) {
  final byKey = <String, ProductStats>{};
  final sorted = items.where((i) => i.entryId == null || liveEntries.contains(i.entryId)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final i in sorted) {
    final key = normalizeItem(i.name);
    if (key.isEmpty) continue;
    final s = byKey.putIfAbsent(key, () => ProductStats(key, i.name.trim()));
    s.name = i.name.trim();
    s.units += i.qty;
    s._sum += i.price;
    s._count++;
    s.minPrice = s._count == 1 ? i.price : (i.price < s.minPrice ? i.price : s.minPrice);
    s.maxPrice = i.price > s.maxPrice ? i.price : s.maxPrice;
    s.lastPrice = i.price;
    if (s._dates.isEmpty || s._dates.last != i.date) {
      s._dates.add(i.date);
      s.trips++;
    }
    s.lastDate = i.date;
  }
  return byKey.values.toList()..sort((a, b) {
    final t = b.trips.compareTo(a.trips);
    return t != 0 ? t : b.units.compareTo(a.units);
  });
}

/// Sugestão de lista: itens comprados em 2+ idas; os que "já está na hora"
/// vêm primeiro.
List<ProductStats> suggestedList(List<ProductStats> stats, DateTime today) {
  final list = stats.where((s) => s.trips >= 2).toList();
  list.sort((a, b) {
    final d = (b.dueOn(today) ? 1 : 0) - (a.dueOn(today) ? 1 : 0);
    return d != 0 ? d : b.trips.compareTo(a.trips);
  });
  return list;
}

/// Idas ao mercado (uma por lançamento) de um mês "AAAA-MM".
({int trips, int total}) monthTrips(Iterable<ShopItem> items, Set<String> liveEntries, String month) {
  final totals = <String, int>{};
  for (final i in items) {
    if (!i.date.startsWith(month)) continue;
    final trip = i.entryId ?? i.date;
    if (i.entryId != null && !liveEntries.contains(i.entryId)) continue;
    totals.update(trip, (v) => v + i.price * i.qty, ifAbsent: () => i.price * i.qty);
  }
  return (trips: totals.length, total: totals.values.fold(0, (a, b) => a + b));
}
