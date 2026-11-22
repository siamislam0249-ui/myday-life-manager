'use strict';
const express = require('express');
const { z } = require('zod');
const auth = require('../middleware/auth');
const ah = require('../utils/asyncHandler');
const { toMinor } = require('../services/money');

const router = express.Router();
router.use(auth);

router.get('/', (req, res) => res.json({ user: req.user }));

router.put('/', ah(async (req, res) => {
  const b = z.object({
    name: z.string().trim().min(1).max(80).optional(),
    tzOffsetMin: z.number().int().min(-720).max(840).optional(),
  }).parse(req.body);
  if (b.name !== undefined) req.user.name = b.name;
  if (b.tzOffsetMin !== undefined) req.user.tzOffsetMin = b.tzOffsetMin;
  await req.user.save();
  res.json({ user: req.user });
}));

// Sets the account opening balance (the balance before your first transaction). Counted once.
router.put('/opening-balance', ah(async (req, res) => {
  const { amount } = z.object({ amount: z.number().min(-1e12).max(1e12) }).parse(req.body);
  req.user.openingBalanceMinor = toMinor(amount);
  await req.user.save();
  res.json({ user: req.user });
}));

module.exports = router;
