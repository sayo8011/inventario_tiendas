import 'package:intl/intl.dart';

/// Dinero en pesos colombianos, guardado como entero en centavos.
class Money {
  Money._();

  static final _display = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    customPattern: '¤ #,##0.00',
  );

  static final _plainInteger = RegExp(r'^\d{1,13}$');
  static final _groupedInteger = RegExp(r'^\d{1,3}(\.\d{3}){1,4}$');

  static String format(int cents) => _display.format(cents / 100);

  /// Texto para precargar un campo, sin separadores de miles: `1234,5`.
  static String toInput(int cents) {
    final decimals = (cents % 100).toString().padLeft(2, '0');
    final whole = cents ~/ 100;
    return decimals == '00' ? '$whole' : '$whole,$decimals';
  }

  /// Convierte a centavos, o `null` si el texto no es un valor válido.
  /// La coma es decimal y el punto es de miles (`1.234,50`). También acepta
  /// `1234.5`, porque un punto sin tres cifras detrás no puede ser de miles.
  static int? parse(String input) {
    var text = input.replaceAll(RegExp(r'[\s$]'), '');
    if (!text.contains(',') && !_groupedInteger.hasMatch(text)) {
      text = text.replaceFirst('.', ',');
    }

    final parts = text.split(',');
    if (parts.length > 2) return null;

    final whole = parts[0];
    final decimals = parts.length == 2 ? parts[1] : '';
    if (!_plainInteger.hasMatch(whole) && !_groupedInteger.hasMatch(whole)) {
      return null;
    }
    if (!RegExp(r'^\d{0,2}$').hasMatch(decimals)) return null;

    final pesos = int.parse(whole.replaceAll('.', ''));
    return pesos * 100 + int.parse(decimals.padRight(2, '0'));
  }
}

/// Cantidades de stock, guardadas como entero en milésimas (1,5 kg = 1500).
class Quantity {
  Quantity._();

  static final _display = NumberFormat('#,##0.###', 'es_CO');
  static final _valid = RegExp(r'^\d{1,12}([.,]\d{1,3})?$');

  static String format(int milli) => _display.format(milli / 1000);

  /// Texto para precargar un campo, sin separadores de miles: `1250,5`.
  static String toInput(int milli) {
    final decimals = (milli % 1000).toString().padLeft(3, '0');
    final trimmed = decimals.replaceFirst(RegExp(r'0+$'), '');
    final whole = milli ~/ 1000;
    return trimmed.isEmpty ? '$whole' : '$whole,$trimmed';
  }

  /// Convierte a milésimas, o `null` si no es válido. A diferencia del dinero,
  /// aquí el punto también es decimal: `1.250` kg son 1,25 kg, no 1250 kg.
  static int? parse(String input) {
    final text = input.trim();
    if (!_valid.hasMatch(text)) return null;

    final parts = text.split(RegExp(r'[.,]'));
    final decimals = parts.length == 2 ? parts[1] : '';
    return int.parse(parts[0]) * 1000 + int.parse(decimals.padRight(3, '0'));
  }
}
