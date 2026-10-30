import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_tiendas/core/utils/formatters.dart';

void main() {
  group('Money.parse', () {
    test('entiende el formato colombiano y variantes comunes', () {
      expect(Money.parse('1500'), 150000);
      expect(Money.parse('1.500'), 150000);
      expect(Money.parse('1.234.567'), 123456700);
      expect(Money.parse('1.500,50'), 150050);
      expect(Money.parse('1500,5'), 150050);
      expect(Money.parse('1500.5'), 150050);
      expect(Money.parse(r'$ 1.500,50'), 150050);
      expect(Money.parse('0'), 0);
    });

    test('no pierde centavos por redondeo', () {
      expect(Money.parse('19,99'), 1999);
      expect(Money.parse('1,10'), 110);
      expect(Money.parse('4,35'), 435);
    });

    test('rechaza valores inválidos', () {
      for (final bad in ['', 'abc', '-5', '1,234', '1,2,3', '1.5.5', '12.34.56']) {
        expect(Money.parse(bad), isNull, reason: bad);
      }
    });
  });

  test('Money.format usa pesos colombianos', () {
    final text = Money.format(123456789).replaceAll(' ', ' ');
    expect(text, r'$ 1.234.567,89');
  });

  test('Money.toInput se puede volver a leer sin cambiar el valor', () {
    for (final cents in [0, 5, 50, 100, 150050, 123456700, 123456789]) {
      expect(Money.parse(Money.toInput(cents)), cents);
    }
  });

  group('Quantity', () {
    test('parse acepta coma y punto como decimal', () {
      expect(Quantity.parse('10'), 10000);
      expect(Quantity.parse('1,5'), 1500);
      expect(Quantity.parse('1.250'), 1250);
      expect(Quantity.parse('0,001'), 1);
    });

    test('parse rechaza valores inválidos', () {
      for (final bad in ['', 'abc', '-1', '1,2345', '1.2.3']) {
        expect(Quantity.parse(bad), isNull, reason: bad);
      }
    });

    test('format muestra solo los decimales necesarios', () {
      expect(Quantity.format(10000), '10');
      expect(Quantity.format(1500), '1,5');
      expect(Quantity.format(1250000), '1.250');
    });

    test('toInput se puede volver a leer sin cambiar el valor', () {
      for (final milli in [0, 1, 1500, 1250000, 1250500]) {
        expect(Quantity.parse(Quantity.toInput(milli)), milli);
      }
    });
  });
}
