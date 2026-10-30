import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/app_database.dart';
import '../domain/stock_movement.dart';

class InsufficientStockException implements Exception {
  final int availableMilli;
  const InsufficientStockException(this.availableMilli);
}

class NoStockChangeException implements Exception {
  const NoStockChangeException();
}

class StockMovementRepository {
  static const int recentLimit = 500;

  final Future<Database>? _database;
  StockMovementRepository({Future<Database>? database}) : _database = database;

  Future<Database> get _db => _database ?? AppDatabase.instance.database;

  Future<List<StockMovement>> getRecent() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT m.*, p.code AS product_code, p.name AS product_name,
        p.unit AS product_unit
      FROM stock_movements m
      JOIN products p ON p.id = m.product_id
      ORDER BY m.created_at DESC, m.id DESC
      LIMIT $recentLimit
    ''');
    return rows.map(StockMovement.fromMap).toList();
  }

  /// Registra una entrada, una salida o un ajuste y actualiza el stock en una
  /// sola transacción. En los ajustes, [quantityMilli] es la cantidad contada;
  /// en los demás, cuánto entra o sale.
  Future<void> register({
    required int productId,
    required MovementType type,
    required int quantityMilli,
    String? note,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['stock_milli'],
        where: 'id = ?',
        whereArgs: [productId],
      );
      final current = rows.single['stock_milli'] as int;

      final delta = switch (type) {
        MovementType.entry => quantityMilli,
        MovementType.exit => -quantityMilli,
        MovementType.adjustment => quantityMilli - current,
        _ => throw ArgumentError('Tipo no registrable a mano: $type'),
      };
      if (delta == 0) throw const NoStockChangeException();
      if (current + delta < 0) throw InsufficientStockException(current);

      await txn.update(
        'products',
        {'stock_milli': current + delta},
        where: 'id = ?',
        whereArgs: [productId],
      );
      await txn.insert('stock_movements', {
        'product_id': productId,
        'type': type.code,
        'quantity_milli': delta,
        'note': note,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }
}
