import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'store.dart';

Future<LocalStore> openStore(String name) async {
  final dir = await getDatabasesPath();
  final db = await openDatabase(
    p.join(dir, '$name.db'),
    version: 1,
    onCreate: (db, _) async {
      await db.execute('CREATE TABLE docs(col TEXT NOT NULL, id TEXT NOT NULL, json TEXT NOT NULL, PRIMARY KEY(col, id))');
      await db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT NOT NULL)');
    },
  );
  return _SqliteStore(db);
}

class _SqliteStore implements LocalStore {
  _SqliteStore(this._db);
  final Database _db;

  @override
  Future<List<Map<String, dynamic>>> all(String col) async {
    final rows = await _db.query('docs', where: 'col = ?', whereArgs: [col]);
    return rows.map((r) => jsonDecode(r['json'] as String) as Map<String, dynamic>).toList();
  }

  @override
  Future<Map<String, dynamic>?> get(String col, String id) async {
    final rows = await _db.query('docs', where: 'col = ? AND id = ?', whereArgs: [col, id], limit: 1);
    return rows.isEmpty ? null : jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
  }

  @override
  Future<void> put(String col, String id, Map<String, dynamic> json) => _db.insert(
      'docs', {'col': col, 'id': id, 'json': jsonEncode(json)},
      conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<String?> meta(String key) async {
    final rows = await _db.query('meta', where: 'k = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['v'] as String;
  }

  @override
  Future<void> setMeta(String key, String value) =>
      _db.insert('meta', {'k': key, 'v': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> close() => _db.close();
}
