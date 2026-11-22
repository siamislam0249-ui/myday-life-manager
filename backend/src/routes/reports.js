'use strict';
const express = require('express');
const { z } = require('zod');
const Transaction = require('../models/Transaction');
const auth = require('../middleware/auth');
const ah = require('../utils/asyncHandler');
const { yearMonth } = require('../services/validators');
const { computeMonth, computeYear, monthBounds, fromMinor } = require('../services/money');
const { toCsv, toXlsx, toPdf } = require('../services/exports');

const router = express.Router();
router.use(auth);

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const yearOnly = yearMonth.pick({ year: true });

async function load(user, endExclusive) {
  return Transaction.find({ userId: user._id, deletedAt: null, date: { $lt: endExclusive } }).lean();
}

function localStamp(date, tz) {
  return new Date(new Date(date).getTime() + tz * 60000).toISOString().slice(0, 16).replace('T', ' ');
}

function toView(report, period, tz) {
  const d = (m) => fromMinor(m);
  return {
    title: period === 'monthly' ? `MyDay Monthly Report - ${MONTHS[report.month - 1]} ${report.year}` : `MyDay Yearly Report - ${report.year}`,
    period,
    year: report.year,
    month: report.month,
    summary: { opening: d(report.openingMinor), income: d(report.incomeMinor), expense: d(report.expenseMinor), closing: d(report.closingMinor) },
    categories: report.categories.map((c) => ({ category: c.category, total: d(c.totalMinor), percent: c.percent })),
    transactions: report.transactions.map((t) => ({
      date: localStamp(t.date, tz), type: t.type, category: t.category, amount: d(t.amountMinor), note: t.note || '',
    })),
    months: report.months && report.months.map((m) => ({
      label: MONTHS[m.month - 1], opening: d(m.openingMinor), income: d(m.incomeMinor), expense: d(m.expenseMinor), closing: d(m.closingMinor),
    })),
  };
}

async function buildView(user, period, q) {
  const tz = user.tzOffsetMin;
  const base = { openingBalanceMinor: user.openingBalanceMinor, tzOffsetMin: tz };
  if (period === 'monthly') {
    const { year, month } = yearMonth.parse(q);
    const txns = await load(user, monthBounds(year, month, tz).end);
    return toView(computeMonth({ ...base, txns, year, month }), 'monthly', tz);
  }
  const { year } = yearOnly.parse(q);
  const txns = await load(user, monthBounds(year, 12, tz).end);
  return toView(computeYear({ ...base, txns, year }), 'yearly', tz);
}

router.get('/monthly', ah(async (req, res) => res.json(await buildView(req.user, 'monthly', req.query))));
router.get('/yearly', ah(async (req, res) => res.json(await buildView(req.user, 'yearly', req.query))));

// /api/reports/export?period=monthly&year=2025&month=11&format=xlsx|pdf|csv
router.get('/export', ah(async (req, res) => {
  const { period, format } = z.object({
    period: z.enum(['monthly', 'yearly']),
    format: z.enum(['xlsx', 'pdf', 'csv']),
  }).parse(req.query);
  const view = await buildView(req.user, period, req.query);
  const name = `myday-${period}-${view.year}${period === 'monthly' ? `-${String(view.month).padStart(2, '0')}` : ''}.${format}`;
  const types = {
    xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    pdf: 'application/pdf',
    csv: 'text/csv; charset=utf-8',
  };
  const body = format === 'csv' ? Buffer.from(toCsv(view), 'utf8') : format === 'xlsx' ? await toXlsx(view) : await toPdf(view);
  res.set({ 'Content-Type': types[format], 'Content-Disposition': `attachment; filename="${name}"`, 'Cache-Control': 'no-store' });
  res.send(body);
}));

module.exports = router;
