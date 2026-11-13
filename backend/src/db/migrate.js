'use strict';

/**
 * Egyszerű SQL migrációs futóprogram.
 *
 * A migrations/ mappában lévő .sql fájlokat név szerint növekvő sorrendben
 * futtatja, mindegyiket külön tranzakcióban. A lefutott fájlok nevét a
 * schema_migrations táblában tárolja, így a parancs többször is futtatható.
 */

const fs = require('node:fs');
const path = require('node:path');
const { pool } = require('./pool');

const migrationsDir = path.join(__dirname, '..', '..', 'migrations');

async function runMigrations() {
  const client = await pool.connect();

  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename   text PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    `);

    const { rows } = await client.query('SELECT filename FROM schema_migrations');
    const alreadyApplied = new Set(rows.map((row) => row.filename));

    const files = fs
      .readdirSync(migrationsDir)
      .filter((file) => file.endsWith('.sql'))
      .sort();

    if (files.length === 0) {
      console.log('[migrate] nincs .sql fájl a migrations/ mappában.');
      return;
    }

    let appliedCount = 0;

    for (const file of files) {
      if (alreadyApplied.has(file)) {
        console.log(`[migrate] kihagyva (már lefutott): ${file}`);
        continue;
      }

      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      console.log(`[migrate] futtatás: ${file}`);

      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
        await client.query('COMMIT');
        appliedCount += 1;
      } catch (error) {
        await client.query('ROLLBACK');
        throw new Error(`${file} futtatása sikertelen: ${error.message}`);
      }
    }

    console.log(`[migrate] kész. Új migrációk: ${appliedCount}.`);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigrations().catch((error) => {
  console.error('[migrate] HIBA:', error.message);
  process.exitCode = 1;
});
