'use strict';
const mongoose = require('mongoose');
const { port, mongoUri } = require('./config');
const app = require('./app');

(async () => {
  await mongoose.connect(mongoUri);
  await Promise.all(Object.values(mongoose.models).map((m) => m.init())); // build unique indexes before serving
  const server = app.listen(port, () => console.log(`MyDay API listening on :${port}`));
  const stop = () => server.close(() => mongoose.disconnect().then(() => process.exit(0)));
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
})().catch((e) => { console.error('Startup failed:', e.message); process.exit(1); });
