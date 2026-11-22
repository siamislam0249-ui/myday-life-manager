'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { toMinor, computeMonth, computeYear, availableBalance } = require('../src/services/money');

const tx = (type, amount, date, category = 'Food') => ({ type, amountMinor: toMinor(amount), date, category });

test('Closing = Opening + Income - Expense (design example 20,000 + 15,000 - 8,000 = 27,000)', () => {
  const txns = [tx('income', 15000, '2025-11-04T04:00:00Z'), tx('expense', 8000, '2025-11-05T07:00:00Z')];
  const m = computeMonth({ openingBalanceMinor: toMinor(20000), txns, year: 2025, month: 11, tzOffsetMin: 360 });
  assert.equal(m.openingMinor, 2000000);
  assert.equal(m.closingMinor, 2700000);
});

test('previous closing carries forward and opening balance is never double counted', () => {
  const txns = [tx('income', 50, '2025-10-10T06:00:00Z')];
  const args = { openingBalanceMinor: toMinor(100), txns, tzOffsetMin: 360 };
  const oct = computeMonth({ ...args, year: 2025, month: 10 });
  const nov = computeMonth({ ...args, year: 2025, month: 11 });
  assert.equal(oct.closingMinor, 15000);
  assert.equal(nov.openingMinor, oct.closingMinor); // 150, not 250
});

test('decimal amounts use integer minor units (0.1 + 0.2 == 0.30)', () => {
  const txns = [tx('income', 0.1, '2025-11-02T06:00:00Z'), tx('income', 0.2, '2025-11-02T07:00:00Z')];
  const m = computeMonth({ txns, year: 2025, month: 11 });
  assert.equal(m.incomeMinor, 30);
});

test('month boundary respects the user timezone (UTC+6)', () => {
  // 2025-10-31 19:00 UTC == 2025-11-01 01:00 in Dhaka -> November
  const txns = [tx('expense', 10, '2025-10-31T19:00:00Z')];
  const nov = computeMonth({ txns, year: 2025, month: 11, tzOffsetMin: 360 });
  const oct = computeMonth({ txns, year: 2025, month: 10, tzOffsetMin: 360 });
  assert.equal(nov.expenseMinor, 1000);
  assert.equal(oct.expenseMinor, 0);
});

test('deleted transactions are ignored', () => {
  const t = { ...tx('income', 999, '2025-11-02T06:00:00Z'), deletedAt: new Date() };
  assert.equal(computeMonth({ txns: [t], year: 2025, month: 11 }).incomeMinor, 0);
  assert.equal(availableBalance(0, [t]), 0);
});

test('yearly report chains months and totals match', () => {
  const txns = [
    tx('income', 1000, '2025-01-15T06:00:00Z'), tx('expense', 300, '2025-03-10T06:00:00Z', 'Rent'),
    tx('expense', 200, '2025-12-20T06:00:00Z', 'Food'),
  ];
  const y = computeYear({ openingBalanceMinor: toMinor(50), txns, year: 2025, tzOffsetMin: 0 });
  for (let i = 0; i < 11; i++) assert.equal(y.months[i].closingMinor, y.months[i + 1].openingMinor);
  assert.equal(y.closingMinor, y.openingMinor + y.incomeMinor - y.expenseMinor);
  assert.equal(y.closingMinor, toMinor(550));
  assert.equal(y.categories[0].category, 'Rent');
});

test('category percentages are computed from expenses', () => {
  const txns = [tx('expense', 75, '2025-11-02T06:00:00Z', 'A'), tx('expense', 25, '2025-11-03T06:00:00Z', 'B')];
  const m = computeMonth({ txns, year: 2025, month: 11 });
  assert.deepEqual(m.categories.map((c) => c.percent), [75, 25]);
});
