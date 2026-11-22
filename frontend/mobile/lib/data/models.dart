import 'dart:convert';

class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.category,
    this.note = '',
    required this.date,
    required this.updatedAt,
    this.deleted = false,
    this.dirty = true,
  });

  final String id; // generated on device => idempotent sync
  final String type; // income | expense
  final int amountMinor; // integer poisha, no float errors
  final String category, note;
  final DateTime date, updatedAt;
  final bool deleted, dirty;

  int get signedMinor => type == 'income' ? amountMinor : -amountMinor;

  Txn copyWith({String? type, int? amountMinor, String? category, String? note, DateTime? date,
      DateTime? updatedAt, bool? deleted, bool? dirty}) =>
      Txn(
        id: id, type: type ?? this.type, amountMinor: amountMinor ?? this.amountMinor,
        category: category ?? this.category, note: note ?? this.note, date: date ?? this.date,
        updatedAt: updatedAt ?? this.updatedAt, deleted: deleted ?? this.deleted, dirty: dirty ?? this.dirty,
      );

  Map<String, dynamic> toLocal() => {
        'id': id, 'type': type, 'amountMinor': amountMinor, 'category': category, 'note': note,
        'date': date.toUtc().toIso8601String(), 'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted, 'dirty': dirty,
      };

  factory Txn.fromLocal(Map<String, dynamic> j) => Txn(
        id: j['id'], type: j['type'], amountMinor: j['amountMinor'], category: j['category'],
        note: j['note'] ?? '', date: DateTime.parse(j['date']), updatedAt: DateTime.parse(j['updatedAt']),
        deleted: j['deleted'] == true, dirty: j['dirty'] == true,
      );

  /// Body for POST /sync/push
  Map<String, dynamic> toPush() => {
        'clientId': id, 'type': type, 'amount': amountMinor / 100, 'category': category, 'note': note,
        'date': date.toUtc().toIso8601String(), 'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  /// From the server's public shape (sync/pull, conflict results)
  factory Txn.fromServer(Map<String, dynamic> j) => Txn(
        id: j['id'], type: j['type'], amountMinor: ((j['amount'] as num) * 100).round(),
        category: j['category'], note: j['note'] ?? '', date: DateTime.parse(j['date']),
        updatedAt: DateTime.parse(j['updatedAt']), deleted: j['deleted'] == true, dirty: false,
      );
}

class Routine {
  Routine({
    required this.id,
    required this.title,
    this.category = 'custom',
    required this.time,
    this.repeat = 'daily',
    this.daysOfWeek = const [],
    this.date,
    this.reminderEnabled = true,
    this.snoozeMinutes = 10,
    this.completedDates = const [],
    required this.updatedAt,
    this.deleted = false,
    this.dirty = true,
  });

  final String id, title, category, time, repeat; // time = "HH:mm"
  final List<int> daysOfWeek; // 0=Sun..6=Sat
  final String? date; // yyyy-MM-dd for repeat == once
  final bool reminderEnabled, deleted, dirty;
  final int snoozeMinutes;
  final List<String> completedDates;
  final DateTime updatedAt;

  bool appliesOn(DateTime day) {
    if (repeat == 'daily') return true;
    final key = dateKey(day);
    if (repeat == 'once') return date == key;
    return daysOfWeek.contains(day.weekday % 7); // Dart: Mon=1..Sun=7 -> Sun=0
  }

  bool doneOn(DateTime day) => completedDates.contains(dateKey(day));

  Routine copyWith({String? title, String? category, String? time, String? repeat, List<int>? daysOfWeek,
      String? date, bool? reminderEnabled, int? snoozeMinutes, List<String>? completedDates,
      DateTime? updatedAt, bool? deleted, bool? dirty}) =>
      Routine(
        id: id, title: title ?? this.title, category: category ?? this.category, time: time ?? this.time,
        repeat: repeat ?? this.repeat, daysOfWeek: daysOfWeek ?? this.daysOfWeek, date: date ?? this.date,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled, snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
        completedDates: completedDates ?? this.completedDates, updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted, dirty: dirty ?? this.dirty,
      );

  Map<String, dynamic> toLocal() => {
        'id': id, 'title': title, 'category': category, 'time': time, 'repeat': repeat,
        'daysOfWeek': daysOfWeek, 'date': date, 'reminderEnabled': reminderEnabled,
        'snoozeMinutes': snoozeMinutes, 'completedDates': completedDates,
        'updatedAt': updatedAt.toUtc().toIso8601String(), 'deleted': deleted, 'dirty': dirty,
      };

  factory Routine.fromLocal(Map<String, dynamic> j) => Routine(
        id: j['id'], title: j['title'], category: j['category'] ?? 'custom', time: j['time'],
        repeat: j['repeat'] ?? 'daily', daysOfWeek: List<int>.from(j['daysOfWeek'] ?? const []),
        date: j['date'], reminderEnabled: j['reminderEnabled'] ?? true, snoozeMinutes: j['snoozeMinutes'] ?? 10,
        completedDates: List<String>.from(j['completedDates'] ?? const []),
        updatedAt: DateTime.parse(j['updatedAt']), deleted: j['deleted'] == true, dirty: j['dirty'] == true,
      );

  Map<String, dynamic> toPush() => {
        'clientId': id, 'title': title, 'category': category, 'time': time, 'repeat': repeat,
        'daysOfWeek': daysOfWeek, 'date': date, 'reminderEnabled': reminderEnabled,
        'snoozeMinutes': snoozeMinutes, 'completedDates': completedDates,
        'updatedAt': updatedAt.toUtc().toIso8601String(), 'deleted': deleted,
      };

  factory Routine.fromServer(Map<String, dynamic> j) => Routine(
        id: j['id'], title: j['title'], category: j['category'] ?? 'custom', time: j['time'],
        repeat: j['repeat'] ?? 'daily', daysOfWeek: List<int>.from(j['daysOfWeek'] ?? const []),
        date: j['date'], reminderEnabled: j['reminderEnabled'] ?? true, snoozeMinutes: j['snoozeMinutes'] ?? 10,
        completedDates: List<String>.from(j['completedDates'] ?? const []),
        updatedAt: DateTime.parse(j['updatedAt']), deleted: j['deleted'] == true, dirty: false,
      );
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class UserInfo {
  UserInfo({required this.id, required this.name, required this.email, required this.tzOffsetMin});
  final String id, name, email;
  final int tzOffsetMin;

  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
        id: j['id'], name: j['name'], email: j['email'], tzOffsetMin: (j['tzOffsetMin'] ?? 360) as int);

  String encode() => jsonEncode({'id': id, 'name': name, 'email': email, 'tzOffsetMin': tzOffsetMin});
  factory UserInfo.decode(String s) => UserInfo.fromJson(jsonDecode(s));
}
