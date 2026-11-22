'use strict';
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    clientId: { type: String, required: true }, // generated on device => idempotent sync
    type: { type: String, enum: ['income', 'expense'], required: true },
    amountMinor: { type: Number, required: true, min: 1 }, // integer poisha, avoids float errors
    category: { type: String, required: true, trim: true, maxlength: 50 },
    note: { type: String, default: '', maxlength: 500 },
    date: { type: Date, required: true },
    clientUpdatedAt: { type: Date, required: true },
    serverUpdatedAt: { type: Date, required: true },
    deletedAt: { type: Date, default: null }, // soft delete so deletions can sync
  },
  { timestamps: true }
);

schema.index({ userId: 1, clientId: 1 }, { unique: true });
schema.index({ userId: 1, date: -1 });
schema.index({ userId: 1, serverUpdatedAt: 1 });

module.exports = mongoose.model('Transaction', schema);
