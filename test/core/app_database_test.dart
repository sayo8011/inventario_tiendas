import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_tiendas/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _v1Schema = [
  'CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL UNIQUE, description TEXT)',
  'CREATE TABLE suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, phone TEXT, email TEXT, address TEXT)',
  'CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'code TEXT NOT NULL UNIQUE, name TEXT NOT NULL, '
      'category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL, '
      'supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL, '
      'cost_price REAL NOT NULL DEFAULT 0, sale_price REAL NOT NULL DEFAULT 0, '
      'stock INTEGER NOT NULL DEFAULT 0, min_stock INTEGER NOT NULL DEFAULT 0, '
      'active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)',
  'CREATE TABLE stock_movements(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE, '
      'type TEXT NOT NULL, quantity INTEGER NOT NULL, note TEXT, '
      'created_at TEXT NOT NULL)',
  'CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'total REAL NOT NULL, created_at TEXT NOT NULL)',
  'CREATE TABLE sale_items(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE, '
      'product_id INTEGER NOT NULL REFERENCES products(id), '
      'quantity INTEGER NOT NULL, unit_price REAL NOT NULL)',
  'CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, '
      "role TEXT NOT NULL DEFAULT 'employee')",
];

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('inventario_test');
    path = p.join(dir.path, 'test.db');
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> createV1(Future<void> Function(Database db) seed) async {
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final sql in _v1Schema) {
            await db.execute(sql);
          }
        },
      ),
    );
    await seed(db);
    await db.close();
  }

  Future<Database> openCurrent() =>
      databaseFactoryFfi.openDatabase(path, options: AppDatabase.openOptions());

  Future<Set<String>> schemaOf(Database db) async {
    final rows = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL "
      "AND name NOT LIKE 'sqlite_%'",
    );
    return rows
        .map((r) => (r['sql'] as String)
            .replaceAll(' IF NOT EXISTS', '')
            .replaceAll(RegExp(r'\s+'), ' '))
        .toSet();
  }

  test('migrar desde v1 conserva los datos y los convierte', () async {
    await createV1((db) async {
      await db.insert('categories', {'id': 1, 'name': 'ELECTRODOMESTICOS', 'description': 'Tecnlogia'});
      await db.insert('categories', {'id': 2, 'name': 'Bebidas'});
      await db.insert('categories', {'id': 3, 'name': 'bebidas'});
      await db.insert('suppliers', {'id': 1, 'name': 'Proveedor'});
      await db.insert('users', {'id': 1, 'username': 'admin', 'password_hash': 'x'});
      await db.insert('products', {
        'id': 7, 'code': 'A1', 'name': 'Gaseosa', 'category_id': 3,
        'supplier_id': 1, 'cost_price': 19.99, 'sale_price': 1500.5,
        'stock': 4, 'min_stock': 2, 'created_at': '2026-01-01',
      });
      await db.insert('stock_movements', {'product_id': 7, 'type': 'in', 'quantity': 5, 'created_at': 'x'});
      await db.insert('stock_movements', {'product_id': 7, 'type': 'sale', 'quantity': 1, 'created_at': 'x'});
      await db.insert('sales', {'id': 1, 'total': 1500.5, 'created_at': 'x'});
      await db.insert('sale_items', {'sale_id': 1, 'product_id': 7, 'quantity': 1, 'unit_price': 1500.5});
    });

    final db = await openCurrent();
    addTearDown(db.close);

    expect(await db.getVersion(), AppDatabase.schemaVersion);

    final categories = await db.query('categories', orderBy: 'id');
    expect(categories.map((c) => c['id']), [1, 2]);
    expect(categories.first['description'], 'Tecnlogia');

    final product = (await db.query('products')).single;
    expect(product['id'], 7);
    expect(product['category_id'], 2, reason: 'apunta a la categoría unificada');
    expect(product['supplier_id'], 1);
    expect(product['cost_cents'], 1999);
    expect(product['sale_cents'], 150050);
    expect(product['stock_milli'], 4000);
    expect(product['min_stock_milli'], 2000);
    expect(product['unit'], 'unidad');

    final movements = await db.query('stock_movements', orderBy: 'id');
    expect(movements.map((m) => m['quantity_milli']), [5000, -1000]);

    expect((await db.query('sales')).single['total_cents'], 150050);
    final item = (await db.query('sale_items')).single;
    expect(item['quantity_milli'], 1000);
    expect(item['unit_price_cents'], 150050);
    expect(item['unit_cost_cents'], 1999);

    expect((await db.query('suppliers')).single['name'], 'Proveedor');
    expect((await db.query('users')).single['username'], 'admin');
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('una base migrada queda igual a una base nueva', () async {
    await createV1((_) async {});
    final migrated = await openCurrent();
    final migratedSchema = await schemaOf(migrated);
    await migrated.close();

    await File(path).delete();
    final fresh = await openCurrent();
    addTearDown(fresh.close);

    // Las tablas intactas en la migración conservan el texto original de v1.
    final compared = {
      for (final sql in migratedSchema)
        if (!sql.contains('TABLE suppliers') && !sql.contains('TABLE users')) sql,
    };
    expect(await schemaOf(fresh), containsAll(compared));
  });

  group('restricciones del esquema', () {
    late Database db;

    setUp(() async {
      db = await openCurrent();
      await db.insert('products', {'id': 1, 'code': 'A', 'name': 'A', 'created_at': 'x'});
    });

    tearDown(() => db.close());

    test('rechaza precios y stock negativos', () async {
      for (final column in ['cost_cents', 'sale_cents', 'stock_milli', 'min_stock_milli']) {
        expect(
          db.update('products', {column: -1}),
          throwsA(isA<DatabaseException>()),
          reason: column,
        );
      }
    });

    test('no deja borrar un producto con historial', () async {
      await db.insert('stock_movements', {
        'product_id': 1, 'type': 'initial', 'quantity_milli': 1000, 'created_at': 'x',
      });
      await expectLater(db.delete('products'), throwsA(isA<DatabaseException>()));
    });

    test('las categorías no se repiten aunque cambien las mayúsculas', () async {
      await db.insert('categories', {'name': 'Bebidas'});
      await expectLater(
        db.insert('categories', {'name': 'BEBIDAS'}),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
