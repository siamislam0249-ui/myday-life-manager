'use strict';
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    clientId: { type: String, required: true },
    title: { type: String, required: true, trim: true, maxlength: 100 },
    category: { type: String, default: 'custom' },
    time: { type: String, required: true }, // "HH:mm"
    repeat: { type: String, enum: ['once', 'daily', 'weekly'], default: 'daily' },
    daysOfWeek: { type: [Number], default: [] }, // 0=Sun..6=Sat (weekly)
    date: { type: String, default: null }, // "YYYY-MM-DD" (once)
    reminderEnabled: { type: Boolean, default: true },
    snoozeMinutes: { type: Number, default: 10 },
    completedDates: { type: [String], default: [] }, // "YYYY-MM-DD"
    clientUpdatedAt: { type: Date, required: true },
    serverUpdatedAt: { type: Date, required: true },
    deletedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

schema.index({ userId: 1, clientId: 1 }, { unique: true });
schema.index({ userId: 1, serverUpdatedAt: 1 });

module.exports = mongoose.model('Routine', schema);
