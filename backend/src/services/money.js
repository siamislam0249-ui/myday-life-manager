'use strict';
/**
 * Pure balance logic (no DB) so it is easy to test.
 *   Closing = Opening + Income - Expense
 * The account opening balance is stored ONCE. A month's opening is derived as
 *   accountOpening + net of every transaction before that month
 * which is the previous month's closing, carried forward automatically and
 * impossible to double count.
 */
const toMinor = (amount) => {
  const n = Math.round(Number(amount) * 100);
  if (!Number.isSafeInteger(n)) throw new RangeError('Invalid amount');
  return n;
};
const fromMinor = (m) => m / 100;

function monthBounds(year, month, tzOffsetMin = 0) {
  const at = (y, m) => new Date(Date.UTC(y, m - 1, 1) - tzOffsetMin * 60000);
  return { start: at(year, month), end: month === 12 ? at(year + 1, 1) : at(year, month + 1) }; // [start,end)
}

const signed = (t) => (t.type === 'income' ? t.amountMinor : -t.amountMinor);

function rankCategories(map, expense) {
  return [...map.entries()]
    .map(([category, totalMinor]) => ({
      category,
      totalMinor,
      percent: expense ? Math.round((totalMinor * 1000) / expense) / 10 : 0,
    }))
    .sort((a, b) => b.totalMinor - a.totalMinor);
}

function computeMonth({ openingBalanceMinor = 0, txns, year, month, tzOffsetMin = 0 }) {
  const { start, end } = monthBounds(year, month, tzOffsetMin);
  let opening = openingBalanceMinor;
  let income = 0;
  let expense = 0;
  const cats = new Map();
  const inMonth = [];

  for (const t of txns) {
    if (t.deletedAt) continue;
    const d = new Date(t.date);
    if (d < start) {
      opening += signed(t);
    } else if (d < end) {
      inMonth.push(t);
      if (t.type === 'income') income += t.amountMinor;
      else {
        expense += t.amountMinor;
        cats.set(t.category, (cats.get(t.category) || 0) + t.amountMinor);
      }
    }
  }

  inMonth.sort((a, b) => new Date(a.date) - new Date(b.date));
  return {
    year,
    month,
    openingMinor: opening,
    incomeMinor: income,
    expenseMinor: expense,
    closingMinor: opening + income - expense,
    categories: rankCategories(cats, expense),
    transactions: inMonth,
  };
}

function computeYear({ openingBalanceMinor = 0, txns, year, tzOffsetMin = 0 }) {
  const months = [];
  for (let m = 1; m <= 12; m++) months.push(computeMonth({ openingBalanceMinor, txns, year, month: m, tzOffsetMin }));

  const cats = new Map();
  let income = 0;
  let expense = 0;
  const transactions = [];
  for (const m of months) {
    income += m.incomeMinor;
    expense += m.expenseMinor;
    transactions.push(...m.transactions);
    for (const c of m.categories) cats.set(c.category, (cats.get(c.category) || 0) + c.totalMinor);
  }

  return {
    year,
    openingMinor: months[0].openingMinor,
    incomeMinor: income,
    expenseMinor: expense,
    closingMinor: months[11].closingMinor,
    months,
    categories: rankCategories(cats, expense),
    transactions,
  };
}

function availableBalance(openingBalanceMinor, txns, until = new Date()) {
  return txns.reduce((sum, t) => (t.deletedAt || new Date(t.date) > until ? sum : sum + signed(t)), openingBalanceMinor);
}

module.exports = { toMinor, fromMinor, monthBounds, computeMonth, computeYear, availableBalance };
