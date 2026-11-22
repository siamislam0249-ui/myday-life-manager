'use strict';
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { jwtSecret } = require('../config');

module.exports = async (req, res, next) => {
  try {
    const [scheme, token] = (req.headers.authorization || '').split(' ');
    if (scheme !== 'Bearer' || !token) return res.status(401).json({ error: 'Unauthorized' });
    const payload = jwt.verify(token, jwtSecret, { algorithms: ['HS256'] });
    const user = await User.findById(payload.sub);
    if (!user || user.tokenVersion !== payload.tv) return res.status(401).json({ error: 'Unauthorized' });
    req.user = user;
    next();
  } catch (_) {
    res.status(401).json({ error: 'Unauthorized' });
  }
};
