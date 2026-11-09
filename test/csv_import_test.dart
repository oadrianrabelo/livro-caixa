import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/domain/csv_import.dart';

void main() {
  test('fatura do cartão: ignora pagamento e diferencia compras repetidas', () {
    final r = parseNubankCsv(
      'date,title,amount\n'
      '2026-10-05,Padaria,12.50\n'
      '2026-10-05,Padaria,12.50\n'
      '2026-10-10,Pagamento recebido,-500.00\n'
      '2026-10-12,"Loja, Centro",99.9\n',
    );
    expect(r.format, 'cartao');
    expect(r.lines.map((l) => l.amount), [1250, 1250, 9990]);
    expect(r.lines[0].key == r.lines[1].key, isFalse);
    expect(r.lines[2].description, 'Loja, Centro');
    expect(r.skipped, 1);
  });

  test('extrato da conta: negativo é gasto, positivo é entrada', () {
    final r = parseNubankCsv(
      'Data,Valor,Identificador,Descrição\n'
      '05/10/2026,-35.00,abc-1,Barbeiro\n'
      '06/10/2026,4053.01,abc-2,Salário\n',
    );
    expect(r.format, 'conta');
    expect(r.lines[0].date, '2026-10-05');
    expect(r.lines[0].income, isFalse);
    expect(r.lines[1].income, isTrue);
    expect(r.lines[1].amount, 405301);
    expect(r.lines[1].key, 'abc-2');
  });

  test('formato desconhecido dá erro claro', () {
    expect(() => parseNubankCsv('a,b,c\n1,2,3'), throwsFormatException);
  });
}
