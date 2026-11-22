'use strict';
/**
 * Idempotent upsert keyed by (userId, clientId).
 *  - Retrying the same push never creates duplicates (unique index + same-version check).
 *  - Conflicts: last-write-wins on the client's updatedAt. A stale write is NOT applied;
 *    the server copy is returned with status "conflict" so the client can adopt it.
 *  - Routine completions from a stale write are merged in (union) so a completed task is never lost.
 *  - Deletes are soft (deletedAt) and use the same rules, so a stale edit cannot resurrect a deleted record.
 */
const Transaction = require('../models/Transaction');
const Routine = require('../models/Routine');
const { toMinor, fromMinor } = require('./money');

const MAX_FUTURE_SKEW_MS = 5 * 60 * 1000; // ignore absurd client clocks

function resolveTimes(data) {
  const now = new Date();
  let at = data.updatedAt ? new Date(data.updatedAt) : now;
  if (at.getTime() > now.getTime() + MAX_FUTURE_SKEW_MS) at = new Date(now.getTime() + MAX_FUTURE_SKEW_MS);
  return { now, at };
}

async function upsertEntity(Model, userId, data, toFields, onStale) {
  const { now, at } = resolveTimes(data);
  const fields = toFields(data);
  const deletedAt = data.deleted ? at : null;

  let doc = await Model.findOne({ userId, clientId: data.clientId });
  if (!doc) {
    try {
      doc = await Model.create({
        userId, clientId: data.clientId, ...fields,
        clientUpdatedAt: at, serverUpdatedAt: now, deletedAt,
      });
      return { status: 'created', doc };
    } catch (e) {
      if (e.code !== 11000) throw e; // parallel retry created it first
      doc = await Model.findOne({ userId, clientId: data.clientId });
    }
  }

  if (at.getTime() === doc.clientUpdatedAt.getTime()) return { status: 'duplicate', doc };
  if (at > doc.clientUpdatedAt) {
    doc.set({ ...fields, clientUpdatedAt: at, serverUpdatedAt: now, deletedAt });
    await doc.save();
    return { status: 'updated', doc };
  }
  if (onStale && onStale(doc, data)) {
    doc.serverUpdatedAt = now;
    await doc.save();
  }
  return { status: 'conflict', doc };
}

const txnFields = (d) => ({
  type: d.type, amountMinor: toMinor(d.amount), category: d.category, note: d.note || '', date: new Date(d.date),
});

const routineFields = (d) => ({
  title: d.title, category: d.category, time: d.time, repeat: d.repeat, daysOfWeek: d.daysOfWeek,
  date: d.date || null, reminderEnabled: d.reminderEnabled, snoozeMinutes: d.snoozeMinutes,
  completedDates: [...new Set(d.completedDates)],
});

const mergeCompletions = (doc, data) => {
  const merged = [...new Set([...doc.completedDates, ...data.completedDates])];
  if (merged.length === doc.completedDates.length) return false;
  doc.completedDates = merged;
  return true;
};

const upsertTransaction = (userId, data) => upsertEntity(Transaction, userId, data, txnFields);
const upsertRoutine = (userId, data) => upsertEntity(Routine, userId, data, routineFields, mergeCompletions);

async function softDelete(Model, userId, clientId) {
  const doc = await Model.findOne({ userId, clientId, deletedAt: null });
  if (!doc) return null;
  const now = new Date();
  doc.deletedAt = now;
  doc.clientUpdatedAt = now;
  doc.serverUpdatedAt = now;
  await doc.save();
  return doc;
}

const pubTxn = (d) => ({
  id: d.clientId, type: d.type, amount: fromMinor(d.amountMinor), category: d.category, note: d.note,
  date: d.date, updatedAt: d.clientUpdatedAt, serverUpdatedAt: d.serverUpdatedAt, deleted: !!d.deletedAt,
});

const pubRoutine = (d) => ({
  id: d.clientId, title: d.title, category: d.category, time: d.time, repeat: d.repeat,
  daysOfWeek: d.daysOfWeek, date: d.date, reminderEnabled: d.reminderEnabled, snoozeMinutes: d.snoozeMinutes,
  completedDates: d.completedDates, updatedAt: d.clientUpdatedAt, serverUpdatedAt: d.serverUpdatedAt,
  deleted: !!d.deletedAt,
});

module.exports = { upsertTransaction, upsertRoutine, softDelete, pubTxn, pubRoutine };
