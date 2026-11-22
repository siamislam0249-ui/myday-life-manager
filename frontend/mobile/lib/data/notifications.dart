import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';

const int _snoozeBase = 900000; // ids >= this are one-off snoozes

/// Local reminders (Android). On web the browser cannot schedule background
/// notifications, so reminders are shown inside the app only.
class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _snoozeCounter = 0;

  Future<void> init() async {
    if (kIsWeb || _ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {/* falls back to UTC */}
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _ready = true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'routine', 'Daily routine',
      channelDescription: 'Reminders for your daily routine',
      importance: Importance.high, priority: Priority.high,
    ),
  );

  tz.TZDateTime _next(String hhmm, {int? weekday}) {
    final parts = hhmm.split(':');
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    while (t.isBefore(now) || (weekday != null && t.weekday != weekday)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  /// Rebuilds all routine reminders (keeps pending snoozes).
  Future<void> rescheduleAll(List<Routine> routines) async {
    if (kIsWeb || !_ready) return;
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id < _snoozeBase) await _plugin.cancel(p.id);
    }
    var id = 1;
    Future<void> schedule(String title, tz.TZDateTime at, DateTimeComponents? match) => _plugin.zonedSchedule(
          id++, title, 'MyDay reminder', at, _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: match,
        );
    for (final r in routines) {
      if (r.deleted || !r.reminderEnabled) continue;
      if (r.repeat == 'daily') {
        await schedule(r.title, _next(r.time), DateTimeComponents.time);
      } else if (r.repeat == 'weekly') {
        for (final d in r.daysOfWeek) {
          await schedule(r.title, _next(r.time, weekday: d == 0 ? 7 : d), DateTimeComponents.dayOfWeekAndTime);
        }
      } else if (r.date != null) {
        final dp = r.date!.split('-').map(int.parse).toList();
        final tp = r.time.split(':').map(int.parse).toList();
        final at = tz.TZDateTime(tz.local, dp[0], dp[1], dp[2], tp[0], tp[1]);
        if (at.isAfter(tz.TZDateTime.now(tz.local))) await schedule(r.title, at, null);
      }
    }
  }

  Future<void> snooze(Routine r) async {
    if (kIsWeb || !_ready) return;
    final at = tz.TZDateTime.now(tz.local).add(Duration(minutes: r.snoozeMinutes));
    await _plugin.zonedSchedule(
      _snoozeBase + (_snoozeCounter++ % 50), r.title, 'Snoozed reminder', at, _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
