import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/core/money.dart';

void main() {
  group('parseBRL', () {
    const ok = {
      '12': 1200,
      '12,5': 1250,
      '12,50': 1250,
      '1.234,56': 123456,
      '1234.56': 123456,
      '1,234.56': 123456,
      '1.234': 123400,
      r'R$ 99,90': 9990,
      '-10,00': -1000,
      '0,01': 1,
    };
    ok.forEach((input, cents) => test('$input -> $cents', () => expect(parseBRL(input), cents)));

    for (final bad in ['', 'abc', '1,2,3', '12,345']) {
      test('rejeita "$bad"', () => expect(parseBRL(bad), isNull));
    }
  });

  test('centsToInput', () {
    expect(centsToInput(123456), '1.234,56');
    expect(centsToInput(5), '0,05');
    expect(centsToInput(-10000), '-100,00');
    expect(parseBRL(centsToInput(123456789)), 123456789);
  });
}
