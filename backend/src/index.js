'use strict';

const config = require('./config');
const { createApp } = require('./app');
const { checkConnection, pool } = require('./db/pool');

const app = createApp();

const server = app.listen(config.port, () => {
  console.log(`[server] Motoros Konvoj API fut: http://localhost:${config.port} (${config.env})`);
  console.log(`[server] Health: http://localhost:${config.port}/health`);
  console.log(`[server] API dokumentáció: http://localhost:${config.port}/api/docs`);

  checkConnection()
    .then(() => console.log('[db] adatbázis kapcsolat OK'))
    .catch((error) => console.warn('[db] adatbázis nem érhető el:', error.message));
});

async function shutdown(signal) {
  console.log(`[server] ${signal} jelzés, leállás...`);
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

module.exports = { server };
