'use strict';
const { z } = require('zod');

const clientId = z.string().min(8).max(64).regex(/^[A-Za-z0-9_-]+$/);
const isoDate = z.string().datetime({ offset: true });
const dateKey = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const syncMeta = { updatedAt: isoDate.optional(), deleted: z.boolean().optional() };

const txnBase = z.object({
  clientId: clientId.optional(),
  type: z.enum(['income', 'expense']),
  amount: z.number().positive().max(1e12),
  category: z.string().trim().min(1).max(50),
  note: z.string().trim().max(500).optional().default(''),
  date: isoDate,
  ...syncMeta,
});

const routineBase = z.object({
  clientId: clientId.optional(),
  title: z.string().trim().min(1).max(100),
  category: z
    .enum(['wake', 'teeth', 'shower', 'breakfast', 'office', 'lunch', 'exercise', 'dinner', 'sleep', 'custom'])
    .default('custom'),
  time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  repeat: z.enum(['once', 'daily', 'weekly']).default('daily'),
  daysOfWeek: z.array(z.number().int().min(0).max(6)).max(7).default([]),
  date: dateKey.nullable().optional(),
  reminderEnabled: z.boolean().default(true),
  snoozeMinutes: z.number().int().min(1).max(120).default(10),
  completedDates: z.array(dateKey).max(800).default([]),
  ...syncMeta,
});

const refineRoutine = (s) =>
  s.superRefine((r, ctx) => {
    if (r.repeat === 'weekly' && r.daysOfWeek.length === 0)
      ctx.addIssue({ code: 'custom', path: ['daysOfWeek'], message: 'Choose at least one day' });
    if (r.repeat === 'once' && !r.date) ctx.addIssue({ code: 'custom', path: ['date'], message: 'Date required' });
  });

const txnInput = txnBase;
const syncTxn = txnBase.extend({ clientId });
const routineInput = refineRoutine(routineBase);
const syncRoutine = refineRoutine(routineBase.extend({ clientId }));

const pushInput = z.object({
  transactions: z.array(syncTxn).max(500).default([]),
  routines: z.array(syncRoutine).max(500).default([]),
});

const yearMonth = z.object({
  year: z.coerce.number().int().min(2000).max(2100),
  month: z.coerce.number().int().min(1).max(12),
});

module.exports = { txnInput, syncTxn, routineInput, syncRoutine, pushInput, yearMonth, dateKey, isoDate };
