// Importar extratos do Nubank (CSV), sem digitar compra por compra.
//
// Formatos aceitos:
//  - Fatura do cartão:  date,title,amount        (2026-10-05,Padaria,12.50)
//    valores negativos são pagamentos/estornos e ficam de fora.
//  - Extrato da conta:  Data,Valor,Identificador,Descrição  (05/10/2026,-12.50,...)
//    negativo = gasto, positivo = entrada.
class ImportedLine {
  const ImportedLine({
    required this.date,
    required this.description,
    required this.amount,
    required this.income,
    required this.key,
  });
  final String date; // AAAA-MM-DD
  final String description;
  final int amount; // centavos, positivo
  final bool income;
  final String key; // identifica a linha (para não importar duas vezes)
}

class ImportResult {
  ImportResult(this.lines, this.skipped, this.format);
  final List<ImportedLine> lines;
  final int skipped; // pagamentos/estornos ou linhas que não deu para ler
  final String format; // 'cartao' | 'conta'
}

/// Divide uma linha de CSV respeitando aspas ("a,b",c).
List<String> _split(String line) {
  final out = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (ch == ',' && !quoted) {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(ch);
    }
  }
  out.add(cur.toString());
  return out.map((s) => s.trim()).toList();
}

int? _cents(String v) {
  final s = v.replaceAll(r'R$', '').replaceAll(' ', '');
  // Nubank usa ponto decimal; aceita vírgula também.
  final normalized = s.contains(',') && !s.contains('.') ? s.replaceAll(',', '.') : s.replaceAll(',', '');
  final d = double.tryParse(normalized);
  return d == null ? null : (d * 100).round();
}

String? _date(String v) {
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v);
  if (iso != null) return '${iso[1]}-${iso[2]}-${iso[3]}';
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})').firstMatch(v);
  if (br != null) return '${br[3]}-${br[2]}-${br[1]}';
  return null;
}

ImportResult parseNubankCsv(String text) {
  final rows = text.replaceAll('\r', '').split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (rows.isEmpty) throw const FormatException('Arquivo vazio.');
  final header = _split(rows.first).map((h) => h.toLowerCase()).toList();
  final isCard = header.contains('title') && header.contains('amount');
  final isAccount = header.contains('valor') && (header.contains('descrição') || header.contains('descricao'));
  if (!isCard && !isAccount) {
    throw const FormatException('Não reconheci o formato. Use o CSV da fatura ou do extrato do Nubank.');
  }
  final iDate = header.indexOf(isCard ? 'date' : 'data');
  final iDesc = isCard ? header.indexOf('title') : header.indexWhere((h) => h.startsWith('descri'));
  final iVal = header.indexOf(isCard ? 'amount' : 'valor');
  final iId = header.indexOf('identificador');

  final lines = <ImportedLine>[];
  final seen = <String, int>{};
  var skipped = 0;
  for (final raw in rows.skip(1)) {
    final c = _split(raw);
    final date = c.length > iDate ? _date(c[iDate]) : null;
    final value = c.length > iVal ? _cents(c[iVal]) : null;
    if (date == null || value == null || value == 0) {
      skipped++;
      continue;
    }
    final desc = c.length > iDesc ? c[iDesc] : '';
    final bool income;
    if (isCard) {
      if (value < 0) {
        skipped++; // pagamento da fatura ou estorno
        continue;
      }
      income = false;
    } else {
      income = value > 0;
    }
    // Chave estável: o identificador do Nubank, ou data+descrição+valor (+ repetição).
    var key = iId >= 0 && c.length > iId && c[iId].isNotEmpty ? c[iId] : '$date|$desc|$value';
    final n = seen.update(key, (v) => v + 1, ifAbsent: () => 0);
    if (n > 0) key = '$key#$n';
    lines.add(ImportedLine(date: date, description: desc, amount: value.abs(), income: income, key: key));
  }
  return ImportResult(lines, skipped, isCard ? 'cartao' : 'conta');
}
