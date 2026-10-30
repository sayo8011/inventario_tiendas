import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_tiendas/core/database/app_database.dart';
import 'package:inventario_tiendas/features/products/data/product_repository.dart';
import 'package:inventario_tiendas/features/products/domain/product.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late Database db;
  late ProductRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('inventario_test');
    db = await databaseFactoryFfi.openDatabase(
      p.join(dir.path, 'test.db'),
      options: AppDatabase.openOptions(),
    );
    repo = ProductRepository(database: Future.value(db));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Product sample({
    int? id,
    String code = 'A1',
    int stockMilli = 0,
    ProductUnit unit = ProductUnit.unidad,
  }) =>
      Product(
        id: id,
        code: code,
        name: 'Arroz',
        costCents: 100050,
        saleCents: 150000,
        stockMilli: stockMilli,
        minStockMilli: 500,
        unit: unit,
      );

  test('guarda y lee el producto con el nombre de su categoría', () async {
    final categoryId = await db.insert('categories', {'name': 'Granos'});
    await repo.insert(
      Product(
        code: 'A1',
        name: 'Arroz',
        categoryId: categoryId,
        costCents: 100050,
        saleCents: 150000,
        stockMilli: 1500,
        unit: ProductUnit.kg,
      ),
    );

    final product = (await repo.getAll()).single;
    expect(product.categoryName, 'Granos');
    expect(product.costCents, 100050);
    expect(product.stockMilli, 1500);
    expect(product.unit, ProductUnit.kg);
    expect(product.active, isTrue);
  });

  test('el stock inicial genera su movimiento', () async {
    final id = await repo.insert(sample(stockMilli: 2500));

    final movement = (await db.query('stock_movements')).single;
    expect(movement['product_id'], id);
    expect(movement['type'], 'initial');
    expect(movement['quantity_milli'], 2500);
  });

  test('sin stock inicial no se crea ningún movimiento', () async {
    await repo.insert(sample());
    expect(await db.query('stock_movements'), isEmpty);
  });

  test('un código repetido da un error claro y no guarda nada', () async {
    await repo.insert(sample(stockMilli: 1000));

    await expectLater(
      repo.insert(sample(stockMilli: 2000)),
      throwsA(isA<DuplicateProductCodeException>()),
    );
    expect(await repo.getAll(), hasLength(1));
    expect(await db.query('stock_movements'), hasLength(1));
  });

  test('editar hacia un código ajeno también da el error claro', () async {
    await repo.insert(sample(code: 'A1'));
    final id = await repo.insert(sample(code: 'B2'));

    await expectLater(
      repo.update(sample(id: id, code: 'A1')),
      throwsA(isA<DuplicateProductCodeException>()),
    );
  });

  test('si falla el movimiento no queda el producto a medias', () async {
    await db.execute('''
      CREATE TRIGGER fail_movement BEFORE INSERT ON stock_movements
      BEGIN SELECT RAISE(ABORT, 'fallo simulado'); END
    ''');

    await expectLater(
      repo.insert(sample(stockMilli: 1000)),
      throwsA(isA<DatabaseException>()),
    );
    expect(await repo.getAll(), isEmpty);
  });

  test('editar cambia el proveedor, pero no el stock ni la unidad', () async {
    final supplierId = await db.insert('suppliers', {'name': 'Proveedor'});
    final id = await repo.insert(
      Product(
        code: 'A1',
        name: 'Arroz',
        costCents: 100,
        saleCents: 200,
        stockMilli: 1500,
        unit: ProductUnit.kg,
      ),
    );

    await repo.update(
      Product(
        id: id,
        code: 'A2',
        name: 'Arroz premium',
        supplierId: supplierId,
        costCents: 300,
        saleCents: 400,
        stockMilli: 9999000,
      ),
    );

    final product = (await repo.getAll()).single;
    expect(product.code, 'A2');
    expect(product.name, 'Arroz premium');
    expect(product.costCents, 300);
    expect(product.stockMilli, 1500);
    expect(product.unit, ProductUnit.kg);
    expect(product.supplierId, supplierId);
  });

  test('desactivar conserva el producto y su historial', () async {
    final id = await repo.insert(sample(stockMilli: 1000));

    await repo.setActive(id, false);
    expect((await repo.getAll()).single.active, isFalse);
    expect(await db.query('stock_movements'), hasLength(1));

    await repo.setActive(id, true);
    expect((await repo.getAll()).single.active, isTrue);
  });

  test('borrar una categoría deja el producto sin categoría', () async {
    final categoryId = await db.insert('categories', {'name': 'Granos'});
    await repo.insert(
      Product(code: 'A1', name: 'Arroz', categoryId: categoryId, costCents: 1, saleCents: 1),
    );

    await db.delete('categories');

    final product = (await repo.getAll()).single;
    expect(product.categoryId, isNull);
    expect(product.categoryName, isNull);
  });

  group('Product', () {
    test('la búsqueda ignora mayúsculas y tildes, y mira el código', () {
      const product = Product(code: 'BC-77', name: 'Café Molido', costCents: 1, saleCents: 1);
      expect(product.matchesSearch('cafe'), isTrue);
      expect(product.matchesSearch('MOLIDO'), isTrue);
      expect(product.matchesSearch('bc-7'), isTrue);
      expect(product.matchesSearch(''), isTrue);
      expect(product.matchesSearch('té'), isFalse);
    });

    test('stock bajo incluye el límite exacto', () {
      Product withStock(int stock) => Product(
            code: 'A',
            name: 'A',
            costCents: 1,
            saleCents: 1,
            stockMilli: stock,
            minStockMilli: 1000,
          );
      expect(withStock(1001).isLowStock, isFalse);
      expect(withStock(1000).isLowStock, isTrue);
      expect(withStock(0).isOutOfStock, isTrue);
    });
  });
}
