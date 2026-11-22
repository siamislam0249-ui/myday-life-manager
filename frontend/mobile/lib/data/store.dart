// Local JSON document store. Android -> SQLite (sqflite). Web -> IndexedDB (sembast_web).
import 'store_web.dart' if (dart.library.io) 'store_io.dart' as impl;

abstract class LocalStore {
  Future<List<Map<String, dynamic>>> all(String col);
  Future<Map<String, dynamic>?> get(String col, String id);
  Future<void> put(String col, String id, Map<String, dynamic> json);
  Future<String?> meta(String key);
  Future<void> setMeta(String key, String value);
  Future<void> close();
}

/// One database per user id, so users on the same device never see each other's data.
Future<LocalStore> openStore(String userId) => impl.openStore('myday_$userId');
