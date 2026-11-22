// Offline mirror of backend/src/services/money.js. Same rules:
//   Closing = Opening + Income - Expense
// The account opening balance is stored ONCE; a month's opening is
//   accountOpening + net of every transaction before that month
// so carry-forward is automatic and the opening balance is never double counted.
import 'package:intl/intl.dart';
import '../data/models.dart';

class MonthReport {
  MonthReport({
    required this.year,
    required this.month,
    required this.openingMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.categories,
    required this.transactions,
  });
  final int year, month, openingMinor, incomeMinor, expenseMinor;
  final Map<String, int> categories; // expense per category
  final List<Txn> transactions;
  int get closingMinor => openingMinor + incomeMinor - expenseMinor;
}

DateTime monthStartUtc(int year, int month, int tzOffsetMin) =>
    DateTime.utc(year, month, 1).subtract(Duration(minutes: tzOffsetMin));

MonthReport computeMonth({
  required int openingBalanceMinor,
  required List<Txn> txns,
  required int year,
  required int month,
  int tzOffsetMin = 0,
}) {
  final start = monthStartUtc(year, month, tzOffsetMin);
  final end = month == 12 ? monthStartUtc(year + 1, 1, tzOffsetMin) : monthStartUtc(year, month + 1, tzOffsetMin);
  var opening = openingBalanceMinor, income = 0, expense = 0;
  final cats = <String, int>{};
  final inMonth = <Txn>[];
  for (final t in txns) {
    if (t.deleted) continue;
    final d = t.date.toUtc();
    if (d.isBefore(start)) {
      opening += t.signedMinor;
    } else if (d.isBefore(end)) {
      inMonth.add(t);
      if (t.type == 'income') {
        income += t.amountMinor;
      } else {
        expense += t.amountMinor;
        cats[t.category] = (cats[t.category] ?? 0) + t.amountMinor;
      }
    }
  }
  inMonth.sort((a, b) => a.date.compareTo(b.date));
  return MonthReport(
    year: year, month: month, openingMinor: opening, incomeMinor: income,
    expenseMinor: expense, categories: cats, transactions: inMonth,
  );
}

int availableBalanceMinor(int openingBalanceMinor, List<Txn> txns, [DateTime? until]) {
  final limit = (until ?? DateTime.now()).toUtc();
  var sum = openingBalanceMinor;
  for (final t in txns) {
    if (t.deleted || t.date.toUtc().isAfter(limit)) continue;
    sum += t.signedMinor;
  }
  return sum;
}

int toMinor(num amount) => (amount * 100).round();

String fmtMoney(int minor, {bool sign = false}) {
  final f = NumberFormat('#,##0.00');
  final s = f.format(minor.abs() / 100);
  final neg = minor < 0 ? '-' : (sign && minor > 0 ? '+' : '');
  return '$neg৳$s';
}
