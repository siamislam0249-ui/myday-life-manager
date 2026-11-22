'use strict';
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 80 },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    phone: { type: String, unique: true, sparse: true, trim: true },
    passwordHash: { type: String, required: true },
    // Balance BEFORE the first transaction. Stored once; never added again anywhere else.
    openingBalanceMinor: { type: Number, default: 0 },
    tzOffsetMin: { type: Number, default: 360 }, // Bangladesh = UTC+6
    tokenVersion: { type: Number, default: 0 }, // bump on logout to revoke old JWTs
  },
  { timestamps: true }
);

userSchema.set('toJSON', {
  transform: (_d, ret) => ({
    id: ret._id,
    name: ret.name,
    email: ret.email,
    phone: ret.phone,
    openingBalance: ret.openingBalanceMinor / 100,
    tzOffsetMin: ret.tzOffsetMin,
  }),
});

module.exports = mongoose.model('User', userSchema);
