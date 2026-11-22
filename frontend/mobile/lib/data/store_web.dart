import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';
import 'store.dart';

Future<LocalStore> openStore(String name) async {
  final db = await databaseFactoryWeb.openDatabase(name); // IndexedDB
  return _WebStore(db);
}

class _WebStore implements LocalStore {
  _WebStore(this._db);
  final Database _db;
  final _meta = stringMapStoreFactory.store('meta');
  StoreRef<String, Map<String, Object?>> _col(String c) => stringMapStoreFactory.store(c);

  @override
  Future<List<Map<String, dynamic>>> all(String col) async {
    final recs = await _col(col).find(_db);
    return recs.map((r) => Map<String, dynamic>.from(r.value)).toList();
  }

  @override
  Future<Map<String, dynamic>?> get(String col, String id) async {
    final v = await _col(col).record(id).get(_db);
    return v == null ? null : Map<String, dynamic>.from(v);
  }

  @override
  Future<void> put(String col, String id, Map<String, dynamic> json) async {
    await _col(col).record(id).put(_db, json);
  }

  @override
  Future<String?> meta(String key) async => (await _meta.record(key).get(_db))?['v'] as String?;

  @override
  Future<void> setMeta(String key, String value) async {
    await _meta.record(key).put(_db, {'v': value});
  }

  @override
  Future<void> close() => _db.close();
}
