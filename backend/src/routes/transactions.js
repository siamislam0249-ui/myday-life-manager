'use strict';
const express = require('express');
const crypto = require('crypto');
const { z } = require('zod');
const Transaction = require('../models/Transaction');
const auth = require('../middleware/auth');
const ah = require('../utils/asyncHandler');
const { txnInput, isoDate } = require('../services/validators');
const { upsertTransaction, softDelete, pubTxn } = require('../services/syncService');

const router = express.Router();
router.use(auth);

const listQuery = z.object({
  from: isoDate.optional(),
  to: isoDate.optional(),
  type: z.enum(['income', 'expense']).optional(),
  category: z.string().trim().max(50).optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

router.get('/', ah(async (req, res) => {
  const q = listQuery.parse(req.query);
  const filter = { userId: req.user._id, deletedAt: null }; // always scoped to the caller
  if (q.type) filter.type = q.type;
  if (q.category) filter.category = q.category;
  if (q.from || q.to) filter.date = { ...(q.from && { $gte: new Date(q.from) }), ...(q.to && { $lt: new Date(q.to) }) };
  const [items, total] = await Promise.all([
    Transaction.find(filter).sort({ date: -1 }).skip((q.page - 1) * q.limit).limit(q.limit),
    Transaction.countDocuments(filter),
  ]);
  res.json({ items: items.map(pubTxn), page: q.page, limit: q.limit, total });
}));

router.post('/', ah(async (req, res) => {
  const body = txnInput.parse(req.body);
  const r = await upsertTransaction(req.user._id, { ...body, clientId: body.clientId || crypto.randomUUID() });
  res.status(r.status === 'created' ? 201 : 200).json({ status: r.status, transaction: pubTxn(r.doc) });
}));

router.put('/:id', ah(async (req, res) => {
  const body = txnInput.parse(req.body);
  const existing = await Transaction.findOne({ userId: req.user._id, clientId: req.params.id, deletedAt: null });
  if (!existing) return res.status(404).json({ error: 'Not found' });
  const r = await upsertTransaction(req.user._id, { ...body, clientId: req.params.id, updatedAt: body.updatedAt || new Date().toISOString() });
  res.json({ status: r.status, transaction: pubTxn(r.doc) });
}));

router.delete('/:id', ah(async (req, res) => {
  const doc = await softDelete(Transaction, req.user._id, req.params.id);
  if (!doc) return res.status(404).json({ error: 'Not found' });
  res.json({ ok: true });
}));

module.exports = router;
