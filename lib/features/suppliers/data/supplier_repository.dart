import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/app_database.dart';
import '../domain/supplier.dart';

class SupplierRepository {
  final Future<Database>? _database;
  SupplierRepository({Future<Database>? database}) : _database = database;

  Future<Database> get _db => _database ?? AppDatabase.instance.database;

  Future<List<Supplier>> getAll() async {
    final db = await _db;
    final rows = await db.query('suppliers', orderBy: 'name COLLATE NOCASE');
    return rows.map(Supplier.fromMap).toList();
  }

  Future<int> insert(Supplier supplier) async {
    final db = await _db;
    return db.insert('suppliers', supplier.toMap()..remove('id'));
  }

  Future<int> update(Supplier supplier) async {
    final db = await _db;
    return db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }
}
