import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_tiendas/core/database/app_database.dart';
import 'package:inventario_tiendas/features/inventory/data/stock_movement_repository.dart';
import 'package:inventario_tiendas/features/inventory/domain/stock_movement.dart';
import 'package:inventario_tiendas/features/products/data/product_repository.dart';
import 'package:inventario_tiendas/features/products/domain/product.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late Database db;
  late StockMovementRepository repo;
  late int productId;

  Future<int> stock() async =>
      (await db.query('products', where: 'id = ?', whereArgs: [productId]))
          .single['stock_milli'] as int;

  /// Lo que dice el producto debe coincidir siempre con su historial.
  Future<int> sumOfMovements() async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(quantity_milli), 0) AS total FROM stock_movements',
    );
    return rows.single['total'] as int;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('inventario_test');
    db = await databaseFactoryFfi.openDatabase(
      p.join(dir.path, 'test.db'),
      options: AppDatabase.openOptions(),
    );
    repo = StockMovementRepository(database: Future.value(db));
    productId = await ProductRepository(database: Future.value(db)).insert(
      const Product(
        code: 'A1',
        name: 'Arroz',
        costCents: 100,
        saleCents: 200,
        stockMilli: 10000,
        unit: ProductUnit.kg,
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('una entrada suma al stock', () async {
    await repo.register(
      productId: productId,
      type: MovementType.entry,
      quantityMilli: 2500,
      note: 'Compra',
    );

    expect(await stock(), 12500);
    final latest = (await repo.getRecent()).first;
    expect(latest.type, MovementType.entry);
    expect(latest.quantityMilli, 2500);
    expect(latest.note, 'Compra');
    expect(latest.productName, 'Arroz');
    expect(latest.unit, ProductUnit.kg);
  });

  test('una salida resta del stock y queda negativa en el historial', () async {
    await repo.register(
      productId: productId,
      type: MovementType.exit,
      quantityMilli: 1500,
    );

    expect(await stock(), 8500);
    expect((await repo.getRecent()).first.quantityMilli, -1500);
  });

  test('una salida puede dejar el stock exactamente en cero', () async {
    await repo.register(
      productId: productId,
      type: MovementType.exit,
      quantityMilli: 10000,
    );
    expect(await stock(), 0);
  });

  test('una salida mayor al stock se rechaza sin cambiar nada', () async {
    await expectLater(
      repo.register(
        productId: productId,
        type: MovementType.exit,
        quantityMilli: 10001,
      ),
      throwsA(
        isA<InsufficientStockException>()
            .having((e) => e.availableMilli, 'disponible', 10000),
      ),
    );

    expect(await stock(), 10000);
    expect(await repo.getRecent(), hasLength(1));
  });

  test('un ajuste deja el stock en la cantidad contada', () async {
    await repo.register(
      productId: productId,
      type: MovementType.adjustment,
      quantityMilli: 7250,
    );
    expect(await stock(), 7250);
    expect((await repo.getRecent()).first.quantityMilli, -2750);

    await repo.register(
      productId: productId,
      type: MovementType.adjustment,
      quantityMilli: 0,
    );
    expect(await stock(), 0);
  });

  test('un ajuste sin diferencia se rechaza', () async {
    await expectLater(
      repo.register(
        productId: productId,
        type: MovementType.adjustment,
        quantityMilli: 10000,
      ),
      throwsA(isA<NoStockChangeException>()),
    );
    expect(await repo.getRecent(), hasLength(1));
  });

  test('si falla el historial, el stock no cambia', () async {
    await db.execute('''
      CREATE TRIGGER fail_movement BEFORE INSERT ON stock_movements
      BEGIN SELECT RAISE(ABORT, 'fallo simulado'); END
    ''');

    await expectLater(
      repo.register(
        productId: productId,
        type: MovementType.entry,
        quantityMilli: 1000,
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await stock(), 10000);
  });

  test('el stock siempre coincide con la suma de movimientos', () async {
    await repo.register(productId: productId, type: MovementType.entry, quantityMilli: 3333);
    await repo.register(productId: productId, type: MovementType.exit, quantityMilli: 1111);
    await repo.register(productId: productId, type: MovementType.adjustment, quantityMilli: 5000);
    await repo.register(productId: productId, type: MovementType.entry, quantityMilli: 1);

    expect(await stock(), 5001);
    expect(await sumOfMovements(), 5001);
  });

  test('el historial viene del más reciente al más antiguo', () async {
    await repo.register(productId: productId, type: MovementType.entry, quantityMilli: 1000);
    await repo.register(productId: productId, type: MovementType.exit, quantityMilli: 1000);

    final types = (await repo.getRecent()).map((m) => m.type);
    expect(types, [MovementType.exit, MovementType.entry, MovementType.initial]);
  });

  test('las ventas y el stock inicial no se registran a mano', () async {
    for (final type in [MovementType.sale, MovementType.initial]) {
      await expectLater(
        repo.register(productId: productId, type: type, quantityMilli: 1000),
        throwsArgumentError,
      );
    }
  });
}
