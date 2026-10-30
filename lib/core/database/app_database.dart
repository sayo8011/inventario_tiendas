import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Convenciones del esquema:
/// - Dinero en centavos (`*_cents`) y cantidades en milésimas (`*_milli`),
///   siempre enteros, para evitar errores de redondeo.
/// - Los productos no se borran, se desactivan: `ON DELETE RESTRICT` protege
///   su historial de ventas y movimientos.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int schemaVersion = 2;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'inventario.db');

    return databaseFactoryFfi.openDatabase(path, options: openOptions());
  }

  static OpenDatabaseOptions openOptions() => OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) => _createSchemaV2(db),
        onUpgrade: _onUpgrade,
      );

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) await _migrateToV2(db);
  }

  /// Las bases nuevas parten de este esquema. No lo modifiques: los cambios
  /// futuros van en una migración nueva que también debe aplicarse en onCreate.
  static Future<void> _createSchemaV2(DatabaseExecutor db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE IF NOT EXISTS categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        description TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
        cost_cents INTEGER NOT NULL DEFAULT 0 CHECK (cost_cents >= 0),
        sale_cents INTEGER NOT NULL DEFAULT 0 CHECK (sale_cents >= 0),
        stock_milli INTEGER NOT NULL DEFAULT 0 CHECK (stock_milli >= 0),
        min_stock_milli INTEGER NOT NULL DEFAULT 0 CHECK (min_stock_milli >= 0),
        unit TEXT NOT NULL DEFAULT 'unidad',
        active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'employee'
      )
    ''');

    // quantity_milli lleva signo: positivo entra al stock, negativo sale.
    batch.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        type TEXT NOT NULL
          CHECK (type IN ('initial', 'in', 'out', 'adjustment', 'sale')),
        quantity_milli INTEGER NOT NULL CHECK (quantity_milli <> 0),
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
        payment_method TEXT NOT NULL DEFAULT 'cash'
          CHECK (payment_method IN ('cash', 'card', 'transfer', 'other')),
        created_at TEXT NOT NULL
      )
    ''');

    // unit_cost_cents congela el costo de la venta para calcular ganancias.
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sale_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        quantity_milli INTEGER NOT NULL CHECK (quantity_milli > 0),
        unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents >= 0),
        unit_cost_cents INTEGER NOT NULL CHECK (unit_cost_cents >= 0)
      )
    ''');

    for (final index in const [
      'products_name_idx ON products(name COLLATE NOCASE)',
      'products_category_idx ON products(category_id)',
      'products_supplier_idx ON products(supplier_id)',
      'stock_movements_product_idx ON stock_movements(product_id, created_at)',
      'sales_created_idx ON sales(created_at)',
      'sale_items_sale_idx ON sale_items(sale_id)',
      'sale_items_product_idx ON sale_items(product_id)',
    ]) {
      batch.execute('CREATE INDEX IF NOT EXISTS $index');
    }

    await batch.commit(noResult: true);
  }

  /// Reconstruye las tablas que cambian, porque SQLite no permite alterar
  /// tipos ni restricciones. Se eliminan de hijas a padres para que los
  /// `ON DELETE` no toquen los datos. sqflite ejecuta todo en una transacción.
  static Future<void> _migrateToV2(Database db) async {
    const tables = ['categories', 'products', 'stock_movements', 'sales', 'sale_items'];

    for (final table in tables) {
      await db.execute('CREATE TEMP TABLE v1_$table AS SELECT * FROM $table');
    }
    for (final table in tables.reversed) {
      await db.execute('DROP TABLE $table');
    }

    await _createSchemaV2(db);

    // Las categorías que solo difieren en mayúsculas se unen en la más antigua.
    await db.execute('''
      INSERT INTO categories(id, name, description)
      SELECT id, name, description FROM v1_categories c
      WHERE id = (
        SELECT MIN(id) FROM v1_categories x
        WHERE x.name = c.name COLLATE NOCASE
      )
    ''');

    await db.execute('''
      INSERT INTO products(id, code, name, category_id, supplier_id, cost_cents,
        sale_cents, stock_milli, min_stock_milli, active, created_at)
      SELECT id, code, name,
        (SELECT MIN(x.id) FROM v1_categories x
         WHERE x.name = (SELECT c.name FROM v1_categories c
                         WHERE c.id = p.category_id) COLLATE NOCASE),
        supplier_id,
        CAST(ROUND(MAX(cost_price, 0) * 100) AS INTEGER),
        CAST(ROUND(MAX(sale_price, 0) * 100) AS INTEGER),
        MAX(stock, 0) * 1000, MAX(min_stock, 0) * 1000, active, created_at
      FROM v1_products p
    ''');

    await db.execute('''
      INSERT INTO stock_movements(id, product_id, type, quantity_milli, note,
        created_at)
      SELECT id, product_id,
        CASE WHEN type IN ('initial', 'in', 'out', 'adjustment', 'sale')
          THEN type ELSE 'adjustment' END,
        CASE WHEN type IN ('out', 'sale') THEN -ABS(quantity) ELSE quantity END
          * 1000,
        note, created_at
      FROM v1_stock_movements
      WHERE quantity <> 0
    ''');

    await db.execute('''
      INSERT INTO sales(id, total_cents, created_at)
      SELECT id, CAST(ROUND(MAX(total, 0) * 100) AS INTEGER), created_at
      FROM v1_sales
    ''');

    // El costo histórico no existía: el costo actual es la mejor aproximación.
    await db.execute('''
      INSERT INTO sale_items(id, sale_id, product_id, quantity_milli,
        unit_price_cents, unit_cost_cents)
      SELECT i.id, i.sale_id, i.product_id, i.quantity * 1000,
        CAST(ROUND(MAX(i.unit_price, 0) * 100) AS INTEGER), p.cost_cents
      FROM v1_sale_items i
      JOIN products p ON p.id = i.product_id
      WHERE i.quantity > 0
    ''');

    for (final table in tables) {
      await db.execute('DROP TABLE v1_$table');
    }
  }
}
