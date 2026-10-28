import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/app_database.dart';
import '../domain/category.dart';

class CategoryRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<Category>> getAll() async {
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'name COLLATE NOCASE');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insert(Category category) async {
    final db = await _db;
    return db.insert('categories', category.toMap()..remove('id'));
  }

  Future<int> update(Category category) async {
    final db = await _db;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}