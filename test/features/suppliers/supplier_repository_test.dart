import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_tiendas/core/database/app_database.dart';
import 'package:inventario_tiendas/features/products/data/product_repository.dart';
import 'package:inventario_tiendas/features/products/domain/product.dart';
import 'package:inventario_tiendas/features/suppliers/data/supplier_repository.dart';
import 'package:inventario_tiendas/features/suppliers/domain/supplier.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late Database db;
  late SupplierRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('inventario_test');
    db = await databaseFactoryFfi.openDatabase(
      p.join(dir.path, 'test.db'),
      options: AppDatabase.openOptions(),
    );
    repo = SupplierRepository(database: Future.value(db));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('crea, ordena por nombre y edita', () async {
    await repo.insert(const Supplier(name: 'Zeta'));
    final id = await repo.insert(
      const Supplier(name: 'alfa', phone: '300', email: 'a@b.co', address: 'Calle 1'),
    );

    expect((await repo.getAll()).map((s) => s.name), ['alfa', 'Zeta']);

    await repo.update(Supplier(id: id, name: 'Alfa SAS'));
    final edited = (await repo.getAll()).first;
    expect(edited.name, 'Alfa SAS');
    expect(edited.phone, isNull);
  });

  test('eliminar un proveedor deja sus productos sin proveedor', () async {
    final id = await repo.insert(const Supplier(name: 'Norte'));
    final products = ProductRepository(database: Future.value(db));
    await products.insert(
      Product(code: 'A1', name: 'Arroz', supplierId: id, costCents: 1, saleCents: 1),
    );
    expect((await products.getAll()).single.supplierId, id);

    await repo.delete(id);

    expect(await repo.getAll(), isEmpty);
    expect((await products.getAll()).single.supplierId, isNull);
  });
}
