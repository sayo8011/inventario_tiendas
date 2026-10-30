import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/app_database.dart';
import '../domain/product.dart';

class DuplicateProductCodeException implements Exception {
  const DuplicateProductCodeException();
}

class ProductRepository {
  final Future<Database>? _database;
  ProductRepository({Future<Database>? database}) : _database = database;

  Future<Database> get _db => _database ?? AppDatabase.instance.database;

  Future<List<Product>> getAll() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      ORDER BY p.name COLLATE NOCASE
    ''');
    return rows.map(Product.fromMap).toList();
  }

  /// Crea el producto y, si trae stock inicial, su movimiento correspondiente:
  /// o se guardan ambos, o ninguno.
  Future<int> insert(Product product) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    return _guardCode(
      () => db.transaction((txn) async {
        final id = await txn.insert('products', {
          ..._editableColumns(product),
          'stock_milli': product.stockMilli,
          'unit': product.unit.code,
          'created_at': now,
        });
        if (product.stockMilli > 0) {
          await txn.insert('stock_movements', {
            'product_id': id,
            'type': 'initial',
            'quantity_milli': product.stockMilli,
            'created_at': now,
          });
        }
        return id;
      }),
    );
  }

  /// No toca el stock ni la unidad: el stock solo cambia con movimientos, y
  /// cambiar la unidad alteraría el significado del historial.
  Future<int> update(Product product) async {
    final db = await _db;
    return _guardCode(
      () => db.update(
        'products',
        _editableColumns(product),
        where: 'id = ?',
        whereArgs: [product.id],
      ),
    );
  }

  Future<int> setActive(int id, bool active) async {
    final db = await _db;
    return db.update(
      'products',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Map<String, Object?> _editableColumns(Product product) => {
        'code': product.code,
        'name': product.name,
        'category_id': product.categoryId,
        'supplier_id': product.supplierId,
        'cost_cents': product.costCents,
        'sale_cents': product.saleCents,
        'min_stock_milli': product.minStockMilli,
      };

  Future<T> _guardCode<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError('products.code')) {
        throw const DuplicateProductCodeException();
      }
      rethrow;
    }
  }
}
