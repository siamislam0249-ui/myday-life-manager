import 'package:flutter_test/flutter_test.dart';
import 'package:myday/core/money.dart';
import 'package:myday/data/models.dart';

Txn t(String id, String type, int minor, DateTime date) => Txn(
    id: id, type: type, amountMinor: minor, category: type == 'income' ? 'Salary' : 'Food',
    date: date, updatedAt: DateTime.utc(2026, 1, 1));

void main() {
  final txns = [
    t('a', 'income', 100000, DateTime.utc(2026, 1, 5)),
    t('b', 'expense', 30000, DateTime.utc(2026, 1, 10)),
    t('c', 'income', 50000, DateTime.utc(2026, 2, 3)),
    t('d', 'expense', 20000, DateTime.utc(2026, 2, 4)),
  ];

  test('closing = opening + income - expense', () {
    final m = computeMonth(openingBalanceMinor: 10000, txns: txns, year: 2026, month: 1);
    expect(m.openingMinor, 10000);
    expect(m.closingMinor, 10000 + 100000 - 30000);
  });

  test('previous closing carries forward and opening is not double counted', () {
    final jan = computeMonth(openingBalanceMinor: 10000, txns: txns, year: 2026, month: 1);
    final feb = computeMonth(openingBalanceMinor: 10000, txns: txns, year: 2026, month: 2);
    expect(feb.openingMinor, jan.closingMinor);
    expect(feb.closingMinor, 10000 + 100000 - 30000 + 50000 - 20000);
  });

  test('deleted transactions are ignored', () {
    final withDeleted = [...txns, t('e', 'expense', 999999, DateTime.utc(2026, 1, 6)).copyWith(deleted: true)];
    final m = computeMonth(openingBalanceMinor: 0, txns: withDeleted, year: 2026, month: 1);
    expect(m.expenseMinor, 30000);
  });

  test('available balance sums everything up to now once', () {
    expect(availableBalanceMinor(10000, txns, DateTime.utc(2026, 12, 31)), 10000 + 100000 - 30000 + 50000 - 20000);
  });

  test('timezone offset moves a transaction into the right local month', () {
    // 2026-01-31 20:00 UTC is already Feb 1 in Bangladesh (UTC+6)
    final x = [t('z', 'expense', 100, DateTime.utc(2026, 1, 31, 20))];
    expect(computeMonth(openingBalanceMinor: 0, txns: x, year: 2026, month: 2, tzOffsetMin: 360).expenseMinor, 100);
    expect(computeMonth(openingBalanceMinor: 0, txns: x, year: 2026, month: 1, tzOffsetMin: 360).expenseMinor, 0);
  });

  test('routine repeat rules', () {
    final r = Routine(id: 'r1', title: 'Gym', time: '18:00', repeat: 'weekly', daysOfWeek: [1], updatedAt: DateTime.utc(2026, 1, 1));
    expect(r.appliesOn(DateTime(2026, 11, 23)), isTrue); // Monday
    expect(r.appliesOn(DateTime(2026, 11, 22)), isFalse); // Sunday
  });

  test('transaction JSON round trip keeps integer amount', () {
    final a = t('x', 'income', 12345, DateTime.utc(2026, 3, 1));
    expect(Txn.fromLocal(a.toLocal()).amountMinor, 12345);
    expect(a.toPush()['amount'], 123.45);
  });
}
