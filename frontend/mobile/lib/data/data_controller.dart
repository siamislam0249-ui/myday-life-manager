import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'notifications.dart';
import 'store.dart';

class AppData {
  const AppData({
    this.ready = false,
    this.txns = const [],
    this.routines = const [],
    this.openingMinor = 0,
    this.syncing = false,
    this.lastSync,
    this.syncError,
  });
  final bool ready, syncing;
  final List<Txn> txns; // not deleted, newest first
  final List<Routine> routines; // not deleted, by time
  final int openingMinor;
  final DateTime? lastSync;
  final String? syncError;

  AppData copyWith({bool? ready, List<Txn>? txns, List<Routine>? routines, int? openingMinor, bool? syncing,
          DateTime? lastSync, Object? syncError = _keep}) =>
      AppData(
        ready: ready ?? this.ready, txns: txns ?? this.txns, routines: routines ?? this.routines,
        openingMinor: openingMinor ?? this.openingMinor, syncing: syncing ?? this.syncing,
        lastSync: lastSync ?? this.lastSync,
        syncError: identical(syncError, _keep) ? this.syncError : syncError as String?,
      );
}

const Object _keep = Object();
const _uuid = Uuid();

class DataController extends StateNotifier<AppData> {
  DataController({required this.userId, required this.dio, required this.reminders}) : super(const AppData()) {
    if (userId != null) _init();
  }

  final String? userId;
  final Dio dio;
  final ReminderService reminders;
  LocalStore? _store;
  StreamSubscription<List<ConnectivityResult>>? _conn;
  Timer? _timer;
  bool _syncing = false, _again = false, _disposed = false;

  Future<void> _init() async {
    _store = await openStore(userId!);
    await _reload();
    await _safeReschedule();
    _conn = Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((x) => x != ConnectivityResult.none)) sync();
    });
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => sync());
    sync();
  }

  @override
  void dispose() {
    _disposed = true;
    _conn?.cancel();
    _timer?.cancel();
    _store?.close();
    super.dispose();
  }

  /// Notifications are optional: a failure here must never break data sync.
  Future<void> _safeReschedule() async {
    try {
      await reminders.init();
      await reminders.rescheduleAll(state.routines);
    } catch (e) {
      debugPrint('reminder scheduling failed: $e');
    }
  }

  Future<void> _reload() async {
    final s = _store!;
    final txns = (await s.all('txns')).map(Txn.fromLocal).where((t) => !t.deleted).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final routines = (await s.all('routines')).map(Routine.fromLocal).where((r) => !r.deleted).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final opening = int.tryParse(await s.meta('openingMinor') ?? '') ?? 0;
    if (_disposed) return;
    state = state.copyWith(ready: true, txns: txns, routines: routines, openingMinor: opening);
  }

  // ---------- transactions ----------
  Future<void> addTxn({required String type, required int amountMinor, required String category,
      String note = '', required DateTime date}) async {
    final t = Txn(id: _uuid.v4(), type: type, amountMinor: amountMinor, category: category, note: note,
        date: date, updatedAt: DateTime.now().toUtc());
    await _store!.put('txns', t.id, t.toLocal());
    await _afterWrite();
  }

  Future<void> updateTxn(Txn t) async {
    await _store!.put('txns', t.id, t.copyWith(updatedAt: DateTime.now().toUtc(), dirty: true).toLocal());
    await _afterWrite();
  }

  Future<void> deleteTxn(Txn t) async {
    await _store!.put('txns', t.id, t.copyWith(deleted: true, updatedAt: DateTime.now().toUtc(), dirty: true).toLocal());
    await _afterWrite();
  }

  // ---------- routines ----------
  Future<void> saveRoutine(Routine r, {bool isNew = false}) async {
    final next = r.copyWith(updatedAt: DateTime.now().toUtc(), dirty: true);
    await _store!.put('routines', next.id, next.toLocal());
    await _afterWrite(routinesChanged: true);
  }

  Routine newRoutine({required String title, required String time, String category = 'custom',
          String repeat = 'daily', List<int> days = const [], String? date, bool reminder = true, int snooze = 10}) =>
      Routine(id: _uuid.v4(), title: title, time: time, category: category, repeat: repeat, daysOfWeek: days,
          date: date, reminderEnabled: reminder, snoozeMinutes: snooze, updatedAt: DateTime.now().toUtc());

  Future<void> deleteRoutine(Routine r) async {
    await _store!.put('routines', r.id, r.copyWith(deleted: true, updatedAt: DateTime.now().toUtc(), dirty: true).toLocal());
    await _afterWrite(routinesChanged: true);
  }

  Future<void> setDone(Routine r, DateTime day, bool done) async {
    final k = dateKey(day);
    final set = {...r.completedDates};
    done ? set.add(k) : set.remove(k);
    await saveRoutine(r.copyWith(completedDates: set.toList()..sort()));
  }

  Future<void> snooze(Routine r) => reminders.snooze(r);

  // ---------- opening balance ----------
  Future<void> setOpening(int minor) async {
    await _store!.setMeta('openingMinor', '$minor');
    await _store!.setMeta('openingDirty', '1');
    await _afterWrite();
  }

  Future<void> _afterWrite({bool routinesChanged = false}) async {
    await _reload();
    if (routinesChanged) await _safeReschedule();
    unawaited(sync());
  }

  // ---------- synchronisation ----------
  /// Push local changes, then pull server changes. Safe to call any time / repeatedly.
  Future<void> sync() async {
    if (_store == null || _disposed) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    state = state.copyWith(syncing: true);
    String? error;
    try {
      await _push();
      await _pull();
      await _reload();
      await _safeReschedule();
    } on DioException catch (e) {
      // Offline is normal for an offline-first app: keep data dirty and retry later.
      final offline = e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      error = offline ? null : 'Sync failed: ${e.response?.statusCode ?? e.message}';
    } catch (e) {
      final msg = '$e';
      error = 'Sync failed: ${msg.length > 120 ? '${msg.substring(0, 120)}…' : msg}';
    } finally {
      _syncing = false;
      if (!_disposed) {
        state = state.copyWith(syncing: false, syncError: error, lastSync: error == null ? DateTime.now() : null);
      }
    }
    if (_again && !_disposed) {
      _again = false;
      unawaited(sync());
    }
  }

  Future<void> _push() async {
    final s = _store!;
    if (await s.meta('openingDirty') == '1') {
      final sent = await s.meta('openingMinor');
      await dio.put('/profile/opening-balance', data: {'amount': int.parse(sent ?? '0') / 100});
      if (await s.meta('openingMinor') == sent) await s.setMeta('openingDirty', '0');
    }
    final dirtyTx = (await s.all('txns')).map(Txn.fromLocal).where((t) => t.dirty).toList();
    final dirtyRo = (await s.all('routines')).map(Routine.fromLocal).where((r) => r.dirty).toList();
    if (dirtyTx.isEmpty && dirtyRo.isEmpty) return;

    // Batches of 500 (server limit)
    for (var i = 0; i < dirtyTx.length || i < dirtyRo.length; i += 500) {
      final tx = dirtyTx.skip(i).take(500).toList();
      final ro = dirtyRo.skip(i).take(500).toList();
      final res = await dio.post('/sync/push', data: {
        'transactions': tx.map((t) => t.toPush()).toList(),
        'routines': ro.map((r) => r.toPush()).toList(),
      });
      final results = res.data['results'] as Map<String, dynamic>;

      for (final r in (results['transactions'] as List).cast<Map<String, dynamic>>()) {
        final sent = tx.firstWhere((t) => t.id == r['id']);
        if (r['status'] == 'conflict' && r['server'] != null) {
          await s.put('txns', sent.id, Txn.fromServer(r['server']).toLocal()); // server copy wins
        } else {
          final cur = await s.get('txns', sent.id);
          if (cur != null && DateTime.parse(cur['updatedAt']) == sent.updatedAt) {
            await s.put('txns', sent.id, {...cur, 'dirty': false}); // not edited again meanwhile
          }
        }
      }
      for (final r in (results['routines'] as List).cast<Map<String, dynamic>>()) {
        final sent = ro.firstWhere((x) => x.id == r['id']);
        if (r['status'] == 'conflict' && r['server'] != null) {
          final server = Routine.fromServer(r['server']);
          final union = {...server.completedDates, ...sent.completedDates}.toList()..sort();
          final needsPush = union.length != server.completedDates.length;
          await s.put('routines', sent.id,
              server.copyWith(completedDates: union, dirty: needsPush, updatedAt: needsPush ? DateTime.now().toUtc() : null).toLocal());
        } else {
          final cur = await s.get('routines', sent.id);
          if (cur != null && DateTime.parse(cur['updatedAt']) == sent.updatedAt) {
            await s.put('routines', sent.id, {...cur, 'dirty': false});
          }
        }
      }
    }
  }

  Future<void> _pull() async {
    final s = _store!;
    var since = await s.meta('since');
    for (var page = 0; page < 50; page++) {
      final res = await dio.get('/sync/pull', queryParameters: {if (since != null) 'since': since});
      final d = res.data as Map<String, dynamic>;

      for (final j in (d['transactions'] as List).cast<Map<String, dynamic>>()) {
        final remote = Txn.fromServer(j);
        final cur = await s.get('txns', remote.id);
        if (cur != null) {
          final local = Txn.fromLocal(cur);
          if (local.dirty && local.updatedAt.isAfter(remote.updatedAt)) continue; // newer local edit still to push
        }
        await s.put('txns', remote.id, remote.toLocal());
      }
      for (final j in (d['routines'] as List).cast<Map<String, dynamic>>()) {
        final remote = Routine.fromServer(j);
        final cur = await s.get('routines', remote.id);
        if (cur != null) {
          final local = Routine.fromLocal(cur);
          if (local.dirty && local.updatedAt.isAfter(remote.updatedAt)) continue;
          final union = {...remote.completedDates, ...local.completedDates}.toList()..sort();
          if (union.length != remote.completedDates.length) {
            await s.put('routines', remote.id, remote.copyWith(completedDates: union, dirty: true, updatedAt: DateTime.now().toUtc()).toLocal());
            continue;
          }
        }
        await s.put('routines', remote.id, remote.toLocal());
      }
      if (await s.meta('openingDirty') != '1') {
        await s.setMeta('openingMinor', '${((d['openingBalance'] as num) * 100).round()}');
      }
      since = d['nextSince'] as String;
      await s.setMeta('since', since);
      if (d['hasMore'] != true) break;
    }
  }
}

@visibleForTesting
String newClientId() => _uuid.v4();
