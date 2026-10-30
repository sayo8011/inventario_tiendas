enum ProductUnit {
  unidad('unidad', 'und', 'Unidad', false),
  caja('caja', 'cj', 'Caja', false),
  paquete('paquete', 'paq', 'Paquete', false),
  kg('kg', 'kg', 'Kilogramo (kg)', true),
  g('g', 'g', 'Gramo (g)', true),
  l('l', 'l', 'Litro (l)', true),
  ml('ml', 'ml', 'Mililitro (ml)', true),
  m('m', 'm', 'Metro (m)', true);

  final String code;
  final String symbol;
  final String label;
  final bool allowsDecimals;
  const ProductUnit(this.code, this.symbol, this.label, this.allowsDecimals);

  static ProductUnit fromCode(String code) =>
      values.firstWhere((u) => u.code == code, orElse: () => unidad);
}

class Product {
  final int? id;
  final String code;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final int? supplierId;
  final int costCents;
  final int saleCents;
  final int stockMilli;
  final int minStockMilli;
  final ProductUnit unit;
  final bool active;

  const Product({
    this.id,
    required this.code,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.supplierId,
    required this.costCents,
    required this.saleCents,
    this.stockMilli = 0,
    this.minStockMilli = 0,
    this.unit = ProductUnit.unidad,
    this.active = true,
  });

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as int,
        code: map['code'] as String,
        name: map['name'] as String,
        categoryId: map['category_id'] as int?,
        categoryName: map['category_name'] as String?,
        supplierId: map['supplier_id'] as int?,
        costCents: map['cost_cents'] as int,
        saleCents: map['sale_cents'] as int,
        stockMilli: map['stock_milli'] as int,
        minStockMilli: map['min_stock_milli'] as int,
        unit: ProductUnit.fromCode(map['unit'] as String),
        active: map['active'] == 1,
      );

  bool get isOutOfStock => stockMilli == 0;
  bool get isLowStock => stockMilli <= minStockMilli;

  bool matchesSearch(String query) {
    final q = _fold(query.trim());
    return _fold(name).contains(q) || _fold(code).contains(q);
  }

  /// Minúsculas y sin tildes, para que "cafe" encuentre "Café".
  static String _fold(String text) {
    const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
    return text
        .toLowerCase()
        .replaceAllMapped(RegExp('[áéíóúü]'), (m) => accents[m[0]]!);
  }
}
