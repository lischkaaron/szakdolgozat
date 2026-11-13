'use strict';

/**
 * Fejlesztői mintaadatok betöltése (idempotens).
 *
 * Létrehozza a README-ben szereplő két tesztfelhasználót (Alice, Bobber),
 * barátságot köt közöttük, majd egy demó csoportot hoz létre Alice
 * tulajdonosként, Bobbal tagként. Többszöri futtatás esetén a meglévő
 * rekordokat frissíti, ezért nem hoz létre duplikátumokat.
 *
 * Futtatás:  npm run seed
 */

const bcrypt = require('bcryptjs');
const config = require('../config');
const { pool } = require('./pool');

const DEMO_PASSWORD = 'titkosJelszo123';

const DEMO_USERS = [
  { email: 'alice@example.com', displayName: 'Alice', motorcycle: 'Yamaha MT-07' },
  { email: 'bob@example.com', displayName: 'Bobber', motorcycle: 'Honda CB500X' },
];

const DEMO_GROUP = {
  name: 'Betyár Riders Klub',
  description: 'Hétvégi túrázó csapat',
};

/** Felhasználó létrehozása vagy frissítése e-mail cím alapján. */
async function upsertUser(client, { email, displayName, motorcycle }) {
  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, config.bcryptRounds);

  const { rows } = await client.query(
    `INSERT INTO users (email, password_hash, display_name, motorcycle)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (email) DO UPDATE
        SET password_hash = EXCLUDED.password_hash,
            display_name  = EXCLUDED.display_name,
            motorcycle    = EXCLUDED.motorcycle
     RETURNING id, email, display_name`,
    [email, passwordHash, displayName, motorcycle],
  );

  return rows[0];
}

/** Szimmetrikus barátság létrehozása (a friends tábla két sort tárol). */
async function ensureFriendship(client, userA, userB) {
  await client.query(
    `INSERT INTO friends (user_id, friend_id)
     VALUES ($1, $2), ($2, $1)
     ON CONFLICT DO NOTHING`,
    [userA.id, userB.id],
  );

  // A köztük lévő függő kérés már felesleges.
  await client.query(
    `DELETE FROM friend_requests
      WHERE status = 'pending'
        AND ((requester_id = $1 AND addressee_id = $2)
          OR (requester_id = $2 AND addressee_id = $1))`,
    [userA.id, userB.id],
  );
}

/** Demó csoport létrehozása (ha még nincs ilyen neve az adott tulajdonosnak). */
async function ensureGroup(client, owner, members) {
  const existing = await client.query(
    'SELECT id FROM groups WHERE owner_id = $1 AND name = $2',
    [owner.id, DEMO_GROUP.name],
  );

  let groupId;

  if (existing.rows.length > 0) {
    groupId = existing.rows[0].id;
    await client.query(
      'UPDATE groups SET description = $2 WHERE id = $1',
      [groupId, DEMO_GROUP.description],
    );
  } else {
    const { rows } = await client.query(
      `INSERT INTO groups (name, description, owner_id)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [DEMO_GROUP.name, DEMO_GROUP.description, owner.id],
    );
    groupId = rows[0].id;
  }

  await client.query(
    `INSERT INTO group_members (group_id, user_id, role)
     VALUES ($1, $2, 'owner')
     ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'owner'`,
    [groupId, owner.id],
  );

  for (const member of members) {
    await client.query(
      `INSERT INTO group_members (group_id, user_id, role)
       VALUES ($1, $2, 'member')
       ON CONFLICT (group_id, user_id) DO NOTHING`,
      [groupId, member.id],
    );
  }

  return groupId;
}

async function seed() {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const users = [];

    for (const demoUser of DEMO_USERS) {
      users.push(await upsertUser(client, demoUser));
    }

    const [alice, bob] = users;
    await ensureFriendship(client, alice, bob);

    const groupId = await ensureGroup(client, alice, [bob]);

    await client.query('COMMIT');

    console.log('[seed] kész.');
    users.forEach((user) => {
      console.log(`  felhasználó: ${user.email} (${user.display_name}) – jelszó: ${DEMO_PASSWORD}`);
    });
    console.log(`  barátság: ${alice.display_name} <-> ${bob.display_name}`);
    console.log(`  csoport: ${DEMO_GROUP.name} (id: ${groupId}, tulajdonos: ${alice.display_name}, tag: ${bob.display_name})`);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

seed().catch((error) => {
  console.error('[seed] HIBA:', error.message);
  process.exitCode = 1;
});
