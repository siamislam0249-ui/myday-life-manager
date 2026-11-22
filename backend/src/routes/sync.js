'use strict';
const express = require('express');
const { z } = require('zod');
const Transaction = require('../models/Transaction');
const Routine = require('../models/Routine');
const auth = require('../middleware/auth');
const ah = require('../utils/asyncHandler');
const { pushInput, isoDate } = require('../services/validators');
const { upsertTransaction, upsertRoutine, pubTxn, pubRoutine } = require('../services/syncService');

const router = express.Router();
router.use(auth);
const PULL_LIMIT = 1000;

// Device -> server. Safe to retry: same clientId + version never duplicates.
router.post('/push', ah(async (req, res) => {
  const body = pushInput.parse(req.body);
  const out = { transactions: [], routines: [] };
  for (const t of body.transactions) {
    const r = await upsertTransaction(req.user._id, t);
    out.transactions.push({ id: t.clientId, status: r.status, server: r.status === 'conflict' ? pubTxn(r.doc) : undefined });
  }
  for (const t of body.routines) {
    const r = await upsertRoutine(req.user._id, t);
    out.routines.push({ id: t.clientId, status: r.status, server: r.status === 'conflict' ? pubRoutine(r.doc) : undefined });
  }
  res.json({ results: out, serverTime: new Date().toISOString() });
}));

// Server -> device. Use nextSince as the next `since`; repeat while hasMore.
router.get('/pull', ah(async (req, res) => {
  const { since } = z.object({ since: isoDate.optional() }).parse(req.query);
  const filter = { userId: req.user._id, ...(since && { serverUpdatedAt: { $gte: new Date(since) } }) };
  const [txns, routines] = await Promise.all([
    Transaction.find(filter).sort({ serverUpdatedAt: 1 }).limit(PULL_LIMIT),
    Routine.find(filter).sort({ serverUpdatedAt: 1 }).limit(PULL_LIMIT),
  ]);
  const hit = [txns, routines].filter((l) => l.length === PULL_LIMIT).map((l) => l[l.length - 1].serverUpdatedAt);
  const hasMore = hit.length > 0;
  const serverTime = new Date().toISOString();
  res.json({
    transactions: txns.map(pubTxn),
    routines: routines.map(pubRoutine),
    openingBalance: req.user.openingBalanceMinor / 100,
    hasMore,
    nextSince: hasMore ? new Date(Math.min(...hit.map(Number))).toISOString() : serverTime,
  });
}));

module.exports = router;
