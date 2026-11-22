'use strict';
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { z } = require('zod');
const User = require('../models/User');
const Routine = require('../models/Routine');
const auth = require('../middleware/auth');
const ah = require('../utils/asyncHandler');
const { toMinor } = require('../services/money');
const { jwtSecret, jwtExpires } = require('../config');

const router = express.Router();
const DUMMY_HASH = bcrypt.hashSync('timing-equalizer', 12);

const registerSchema = z.object({
  name: z.string().trim().min(1).max(80),
  email: z.string().trim().toLowerCase().email().max(254),
  phone: z.string().trim().regex(/^\+?[0-9]{7,15}$/).optional(),
  password: z.string().min(8).refine((p) => Buffer.byteLength(p) <= 72, 'Password too long (max 72 bytes)'),
  openingBalance: z.number().min(-1e12).max(1e12).default(0),
  tzOffsetMin: z.number().int().min(-720).max(840).default(360),
});
const loginSchema = z.object({
  identifier: z.string().trim().toLowerCase().min(3).max(254), // email or phone
  password: z.string().min(1).max(200),
});

const sign = (u) => jwt.sign({ sub: u.id, tv: u.tokenVersion }, jwtSecret, { expiresIn: jwtExpires, algorithm: 'HS256' });

const DEFAULT_ROUTINES = [
  ['wake', 'ঘুম থেকে ওঠা', '06:30'], ['teeth', 'দাঁত ব্রাশ করা', '06:45'], ['shower', 'গোসল করা', '07:00'],
  ['breakfast', 'নাশতা খাওয়া', '07:30'], ['office', 'অফিসের প্রস্তুতি', '08:00'], ['office', 'অফিসে যাওয়া', '08:30'],
  ['lunch', 'দুপুরের খাবার', '13:00'], ['exercise', 'ব্যায়াম', '18:00'], ['dinner', 'রাতের খাবার', '21:00'],
  ['sleep', 'ঘুমাতে যাওয়া', '23:00'],
];

router.post('/register', ah(async (req, res) => {
  const b = registerSchema.parse(req.body);
  const passwordHash = await bcrypt.hash(b.password, 12);
  let user;
  try {
    user = await User.create({
      name: b.name, email: b.email, phone: b.phone, passwordHash,
      openingBalanceMinor: toMinor(b.openingBalance), tzOffsetMin: b.tzOffsetMin,
    });
  } catch (e) {
    if (e.code === 11000) return res.status(409).json({ error: 'Email or phone already registered' });
    throw e;
  }
  const now = new Date();
  await Routine.insertMany(DEFAULT_ROUTINES.map(([category, title, time]) => ({
    userId: user._id, clientId: crypto.randomUUID(), title, category, time, repeat: 'daily',
    clientUpdatedAt: now, serverUpdatedAt: now,
  })));
  res.status(201).json({ token: sign(user), user });
}));

router.post('/login', ah(async (req, res) => {
  const { identifier, password } = loginSchema.parse(req.body);
  const user = await User.findOne({ $or: [{ email: identifier }, { phone: identifier }] });
  const ok = await bcrypt.compare(password, user ? user.passwordHash : DUMMY_HASH);
  if (!user || !ok) return res.status(401).json({ error: 'Invalid credentials' });
  res.json({ token: sign(user), user });
}));

router.post('/logout', auth, ah(async (req, res) => {
  req.user.tokenVersion += 1; // revokes every previously issued token
  await req.user.save();
  res.json({ ok: true });
}));

router.get('/me', auth, (req, res) => res.json({ user: req.user }));

module.exports = router;
