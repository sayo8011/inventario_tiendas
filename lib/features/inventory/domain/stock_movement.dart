import '../../products/domain/product.dart';

enum MovementType {
  initial('initial', 'Stock inicial'),
  entry('in', 'Entrada'),
  exit('out', 'Salida'),
  adjustment('adjustment', 'Ajuste'),
  sale('sale', 'Venta');

  final String code;
  final String label;
  const MovementType(this.code, this.label);

  static MovementType fromCode(String code) =>
      values.firstWhere((t) => t.code == code, orElse: () => adjustment);
}

class StockMovement {
  final int id;
  final String productCode;
  final String productName;
  final ProductUnit unit;
  final MovementType type;

  /// Con signo: positivo entra al stock, negativo sale.
  final int quantityMilli;
  final String? note;
  final DateTime createdAt;

  const StockMovement({
    required this.id,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.type,
    required this.quantityMilli,
    this.note,
    required this.createdAt,
  });

  factory StockMovement.fromMap(Map<String, Object?> map) => StockMovement(
        id: map['id'] as int,
        productCode: map['product_code'] as String,
        productName: map['product_name'] as String,
        unit: ProductUnit.fromCode(map['product_unit'] as String),
        type: MovementType.fromCode(map['type'] as String),
        quantityMilli: map['quantity_milli'] as int,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
