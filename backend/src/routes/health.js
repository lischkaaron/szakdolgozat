'use strict';

const express = require('express');
const { checkConnection } = require('../db/pool');
const { version } = require('../../package.json');

const router = express.Router();

/**
 * GET /health
 * 200, ha az API és az adatbázis is elérhető; 503, ha az adatbázis nem.
 * A Flutter kliens és a docker healthcheck is ezt hívhatja.
 */
router.get('/health', async (req, res) => {
  let db = 'up';

  try {
    await checkConnection();
  } catch (error) {
    db = 'down';
    console.warn('[health] adatbázis hiba:', error.message);
  }

  res.status(db === 'up' ? 200 : 503).json({
    status: db === 'up' ? 'ok' : 'degraded',
    db,
    service: 'moto-konvoj-backend',
    version,
    time: new Date().toISOString(),
  });
});

module.exports = router;
