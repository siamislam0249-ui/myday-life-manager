'use strict';
const express = require('express');
const crypto = require('crypto');
const { z } = require('zod');
const Routine = require('../models/Routine');
const auth = require('../middleware/auth');
const ah = require('../utils/asyncHandler');
const { routineInput, dateKey } = require('../services/validators');
const { upsertRoutine, softDelete, pubRoutine } = require('../services/syncService');

const router = express.Router();
router.use(auth);

const appliesOn = (r, day) => {
  if (r.repeat === 'daily') return true;
  if (r.repeat === 'once') return r.date === day;
  return r.daysOfWeek.includes(new Date(`${day}T00:00:00Z`).getUTCDay());
};

router.get('/', ah(async (req, res) => {
  const items = await Routine.find({ userId: req.user._id, deletedAt: null }).sort({ time: 1 });
  res.json({ items: items.map(pubRoutine) });
}));

// Today's tasks for a given local date (dashboard "Today's Tasks")
router.get('/today', ah(async (req, res) => {
  const { date } = z.object({ date: dateKey }).parse(req.query);
  const items = await Routine.find({ userId: req.user._id, deletedAt: null }).sort({ time: 1 });
  res.json({
    date,
    items: items.filter((r) => appliesOn(r, date)).map((r) => ({ ...pubRoutine(r), done: r.completedDates.includes(date) })),
  });
}));

router.post('/', ah(async (req, res) => {
  const body = routineInput.parse(req.body);
  const r = await upsertRoutine(req.user._id, { ...body, clientId: body.clientId || crypto.randomUUID() });
  res.status(r.status === 'created' ? 201 : 200).json({ status: r.status, routine: pubRoutine(r.doc) });
}));

router.put('/:id', ah(async (req, res) => {
  const body = routineInput.parse(req.body);
  const existing = await Routine.findOne({ userId: req.user._id, clientId: req.params.id, deletedAt: null });
  if (!existing) return res.status(404).json({ error: 'Not found' });
  const r = await upsertRoutine(req.user._id, { ...body, clientId: req.params.id, updatedAt: body.updatedAt || new Date().toISOString() });
  res.json({ status: r.status, routine: pubRoutine(r.doc) });
}));

// Mark a task done / not done for one day
router.post('/:id/complete', ah(async (req, res) => {
  const { date, done } = z.object({ date: dateKey, done: z.boolean().default(true) }).parse(req.body);
  const doc = await Routine.findOne({ userId: req.user._id, clientId: req.params.id, deletedAt: null });
  if (!doc) return res.status(404).json({ error: 'Not found' });
  const set = new Set(doc.completedDates);
  if (done) set.add(date); else set.delete(date);
  const now = new Date();
  doc.completedDates = [...set].slice(-800);
  doc.clientUpdatedAt = now;
  doc.serverUpdatedAt = now;
  await doc.save();
  res.json({ routine: pubRoutine(doc) });
}));

router.delete('/:id', ah(async (req, res) => {
  const doc = await softDelete(Routine, req.user._id, req.params.id);
  if (!doc) return res.status(404).json({ error: 'Not found' });
  res.json({ ok: true });
}));

module.exports = router;
