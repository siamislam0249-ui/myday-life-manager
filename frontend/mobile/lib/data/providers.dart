import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api.dart';
import 'data_controller.dart';
import 'models.dart';
import 'notifications.dart';

const _storage = FlutterSecureStorage();

class SessionState {
  const SessionState({this.loading = true, this.user});
  final bool loading;
  final UserInfo? user;
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._ref) : super(const SessionState()) {
    _restore();
  }
  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);

  Future<void> _restore() async {
    final token = await _storage.read(key: 'token');
    final u = await _storage.read(key: 'user');
    // Offline-first: a stored session opens the app without needing the network.
    state = SessionState(loading: false, user: token != null && u != null ? UserInfo.decode(u) : null);
  }

  Future<void> _save(Map<String, dynamic> data) async {
    await _storage.write(key: 'token', value: data['token']);
    final user = UserInfo.fromJson(data['user']);
    await _storage.write(key: 'user', value: user.encode());
    state = SessionState(loading: false, user: user);
  }

  Future<void> login(String identifier, String password) async {
    final res = await _dio.post('/auth/login', data: {'identifier': identifier, 'password': password});
    await _save(res.data);
  }

  Future<void> register({required String name, required String email, required String password,
      String? phone, double opening = 0}) async {
    final res = await _dio.post('/auth/register', data: {
      'name': name, 'email': email, 'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'openingBalance': opening,
      'tzOffsetMin': DateTime.now().timeZoneOffset.inMinutes,
    });
    await _save(res.data);
  }

  /// [serverSide] revokes the token on the server too (needs network; best effort).
  Future<void> logout({bool serverSide = true}) async {
    if (serverSide) {
      try {
        await _dio.post('/auth/logout');
      } catch (_) {/* offline: still sign out locally */}
    }
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');
    state = const SessionState(loading: false);
  }
}

final dioProvider = Provider<Dio>((ref) => buildDio(
      token: () => _storage.read(key: 'token'),
      onUnauthorized: () => ref.read(sessionProvider.notifier).logout(serverSide: false),
    ));

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) => SessionNotifier(ref));

final reminderProvider = Provider<ReminderService>((ref) => ReminderService());

final dataProvider = StateNotifierProvider<DataController, AppData>((ref) {
  final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
  return DataController(userId: userId, dio: ref.watch(dioProvider), reminders: ref.watch(reminderProvider));
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
