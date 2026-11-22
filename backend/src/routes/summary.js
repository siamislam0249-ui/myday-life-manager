'use strict';
const express = require('express');
const Transaction = require('../models/Transaction');
const auth = require('../middleware/auth');
const ah = require('../utils/asyncHandler');
const { yearMonth } = require('../services/validators');
const { computeMonth, availableBalance, fromMinor } = require('../services/money');

const router = express.Router();
router.use(auth);

// Dashboard: available balance + this month's income/expense
router.get('/', ah(async (req, res) => {
  const tz = req.user.tzOffsetMin;
  const local = new Date(Date.now() + tz * 60000);
  const q = req.query.year || req.query.month
    ? yearMonth.parse(req.query)
    : { year: local.getUTCFullYear(), month: local.getUTCMonth() + 1 };
  const txns = await Transaction.find({ userId: req.user._id, deletedAt: null }).lean();
  const m = computeMonth({ openingBalanceMinor: req.user.openingBalanceMinor, txns, year: q.year, month: q.month, tzOffsetMin: tz });
  res.json({
    year: q.year,
    month: q.month,
    availableBalance: fromMinor(availableBalance(req.user.openingBalanceMinor, txns)),
    opening: fromMinor(m.openingMinor),
    income: fromMinor(m.incomeMinor),
    expense: fromMinor(m.expenseMinor),
    closing: fromMinor(m.closingMinor),
  });
}));

module.exports = router;
