import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/prefs.dart';

void main() {
  test('item da calculadora vai e volta do JSON', () {
    const item = ShopItem(price: 599, qty: 3, name: 'arroz');
    final back = ShopItem.fromJson(item.toJson());
    expect(back.total, 1797);
    expect(back.name, 'arroz');
    expect(ShopItem.fromJson(const ShopItem(price: 250).toJson()).qty, 1);
  });
}
