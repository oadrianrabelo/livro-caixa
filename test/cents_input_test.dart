import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/ui/kit/kit.dart';

String type(String text, {bool signed = false}) =>
    CentsInputFormatter(signed: signed).formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text)).text;

void main() {
  test('vírgula automática, como nos bancos', () {
    expect(type('1'), '0,01');
    expect(type('12'), '0,12');
    expect(type('1234'), '12,34');
    expect(type('123456'), '1.234,56');
    expect(type('0'), '');
    expect(type('1.234,567'), '12.345,67'); // digitou mais um número
    expect(type('-500'), '5,00'); // sem sinal: ignora o "-"
    expect(type('-500', signed: true), '-5,00');
  });
}
