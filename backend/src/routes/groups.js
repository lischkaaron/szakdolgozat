'use strict';

const express = require('express');
const { pool, query } = require('../db/pool');
const { asyncHandler } = require('../utils/asyncHandler');
const { HttpError } = require('../utils/httpError');
const {
  requireString,
  optionalString,
  requireEmail,
  requireUuid,
} = require('../utils/validate');
const { toGroup, toGroupMember } = require('../utils/serializers');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// Minden csoport-végpont csak bejelentkezve hívható.
router.use(requireAuth);

const GROUP_COLUMNS = 'g.id, g.name, g.description, g.owner_id, g.created_at, g.updated_at';

/**
 * A bejelentkezett felhasználó tagságának betöltése.
 * Ha nem tag, 404-et adunk (nem áruljuk el, hogy létezik-e a csoport).
 */
async function loadMembership(groupId, userId) {
  const result = await query(
    'SELECT group_id, role FROM group_members WHERE group_id = $1 AND user_id = $2',
    [groupId, userId],
  );

  if (result.rowCount === 0) {
    throw HttpError.notFound('A csoport nem található, vagy nem vagy a tagja.');
  }

  return result.rows[0];
}

/** Egy csoport tagjai (tulajdonos elöl), a felhasználó adataival együtt. */
async function loadMembers(groupId, selfId = null) {
  const result = await query(
    `SELECT gm.user_id, gm.role, gm.joined_at, u.display_name, u.email, u.motorcycle
     FROM group_members gm
     JOIN users u ON u.id = gm.user_id
     WHERE gm.group_id = $1
     ORDER BY (gm.role = 'owner') DESC, u.display_name`,
    [groupId],
  );

  return result.rows.map((row) => toGroupMember(row, selfId));
}

/** Csoport + tagok + a kérő szerepe (owner / member). */
async function serializeGroupForUser(groupId, userId) {
  const membership = await loadMembership(groupId, userId);

  const result = await query(
    `SELECT ${GROUP_COLUMNS} FROM groups g WHERE g.id = $1`,
    [groupId],
  );

  if (result.rowCount === 0) {
    throw HttpError.notFound('A csoport nem található.');
  }

  const members = await loadMembers(groupId, userId);

  return toGroup({ ...result.rows[0], my_role: membership.role }, members);
}

/**
 * GET /api/groups
 * A bejelentkezett felhasználó csoportjai (tagként vagy tulajdonosként),
 * taglétszámmal és a tagok rövid listájával.
 */
router.get('/', asyncHandler(async (req, res) => {
  const groups = await query(
    `SELECT ${GROUP_COLUMNS}, gm.role AS my_role,
            (SELECT count(*)::int FROM group_members m WHERE m.group_id = g.id) AS member_count
     FROM groups g
     JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1
     ORDER BY g.name`,
    [req.user.id],
  );

  if (groups.rowCount === 0) {
    res.json({ groups: [] });
    return;
  }

  const ids = groups.rows.map((row) => row.id);
  const members = await query(
    `SELECT gm.group_id, gm.user_id, gm.role, gm.joined_at,
            u.display_name, u.email, u.motorcycle
     FROM group_members gm
     JOIN users u ON u.id = gm.user_id
     WHERE gm.group_id = ANY($1::uuid[])
     ORDER BY (gm.role = 'owner') DESC, u.display_name`,
    [ids],
  );

  const membersByGroup = new Map(ids.map((id) => [id, []]));
  for (const row of members.rows) {
    membersByGroup.get(row.group_id)?.push(toGroupMember(row, req.user.id));
  }

  res.json({
    groups: groups.rows.map((row) => toGroup(row, membersByGroup.get(row.id) ?? [])),
  });
}));

/**
 * POST /api/groups
 * Body: { name, description? }
 * A létrehozó automatikusan tulajdonos tag lesz. 201 -> { group }
 */
router.post('/', asyncHandler(async (req, res) => {
  const name = requireString(req.body?.name, 'name', { min: 2, max: 80 });
  const description = optionalString(req.body?.description, 'description', { max: 280 });

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const created = await client.query(
      `INSERT INTO groups (name, description, owner_id)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [name, description, req.user.id],
    );

    const groupId = created.rows[0].id;

    await client.query(
      `INSERT INTO group_members (group_id, user_id, role)
       VALUES ($1, $2, 'owner')`,
      [groupId, req.user.id],
    );

    await client.query('COMMIT');

    res.status(201).json({ group: await serializeGroupForUser(groupId, req.user.id) });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}));

/**
 * GET /api/groups/:id
 * Csoport részletei (tagokkal). Csak tagok láthatják.
 */
router.get('/:id', asyncHandler(async (req, res) => {
  const groupId = requireUuid(req.params.id, 'id');
  res.json({ group: await serializeGroupForUser(groupId, req.user.id) });
}));

/**
 * PATCH /api/groups/:id
 * Body: { name?, description? } - csak a tulajdonos módosíthat.
 */
router.patch('/:id', asyncHandler(async (req, res) => {
  const groupId = requireUuid(req.params.id, 'id');
  const membership = await loadMembership(groupId, req.user.id);

  if (membership.role !== 'owner') {
    throw HttpError.forbidden('Csak a csoport tulajdonosa szerkesztheti a csoportot.');
  }

  const updates = [];
  const params = [groupId];

  if (req.body?.name !== undefined) {
    const name = requireString(req.body.name, 'name', { min: 2, max: 80 });
    params.push(name);
    updates.push(`name = $${params.length}`);
  }

  if (req.body?.description !== undefined) {
    const description = optionalString(req.body.description, 'description', { max: 280 });
    params.push(description);
    updates.push(`description = $${params.length}`);
  }

  if (updates.length === 0) {
    throw HttpError.badRequest('Nincs módosítható mező. Add meg a name és/vagy description mezőt.');
  }

  await query(`UPDATE groups SET ${updates.join(', ')} WHERE id = $1`, params);

  res.json({ group: await serializeGroupForUser(groupId, req.user.id) });
}));

/**
 * DELETE /api/groups/:id
 * A csoport (és a tagságok) törlése. Csak a tulajdonos teheti meg.
 */
router.delete('/:id', asyncHandler(async (req, res) => {
  const groupId = requireUuid(req.params.id, 'id');

  const result = await query(
    'DELETE FROM groups WHERE id = $1 AND owner_id = $2 RETURNING id',
    [groupId, req.user.id],
  );

  if (result.rowCount === 0) {
    const membership = await query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, req.user.id],
    );

    if (membership.rowCount === 0) {
      throw HttpError.notFound('A csoport nem található, vagy nem vagy a tagja.');
    }

    throw HttpError.forbidden('Csak a csoport tulajdonosa törölheti a csoportot.');
  }

  res.status(204).send();
}));

/**
 * POST /api/groups/:id/members
 * Body: { userId } vagy { email } - csak a tulajdonos, és csak barátot lehet hozzáadni.
 * 201 -> { group }
 */
router.post('/:id/members', asyncHandler(async (req, res) => {
  const groupId = requireUuid(req.params.id, 'id');
  const membership = await loadMembership(groupId, req.user.id);

  if (membership.role !== 'owner') {
    throw HttpError.forbidden('Csak a csoport tulajdonosa adhat hozzá tagot.');
  }

  const { userId, email } = req.body || {};
  let target;

  if (email !== undefined) {
    const targetEmail = requireEmail(email);
    const found = await query('SELECT id FROM users WHERE email = $1', [targetEmail]);
    target = found.rows[0];
  } else if (userId !== undefined) {
    const targetId = requireUuid(userId, 'userId');
    const found = await query('SELECT id FROM users WHERE id = $1', [targetId]);
    target = found.rows[0];
  } else {
    throw HttpError.badRequest('Add meg a tag e-mail címét (email) vagy azonosítóját (userId).');
  }

  if (!target) {
    throw HttpError.notFound('Nem található felhasználó a megadott adatokkal.');
  }

  const friendship = await query(
    'SELECT 1 FROM friends WHERE user_id = $1 AND friend_id = $2',
    [req.user.id, target.id],
  );

  if (friendship.rowCount === 0) {
    throw HttpError.badRequest('Csak a barátaidat adhatod a csoporthoz. Előbb jelöld be barátnak.');
  }

  try {
    await query(
      `INSERT INTO group_members (group_id, user_id, role)
       VALUES ($1, $2, 'member')`,
      [groupId, target.id],
    );
  } catch (error) {
    if (error.code === '23505') {
      throw HttpError.conflict('Ez a felhasználó már tagja a csoportnak.');
    }
    throw error;
  }

  res.status(201).json({ group: await serializeGroupForUser(groupId, req.user.id) });
}));

/**
 * DELETE /api/groups/:id/members/:userId
 * A tulajdonos eltávolíthat egy tagot; mindenki más csak saját magát
 * (azaz kiléphet a csoportból). A tulajdonos nem léphet ki.
 */
router.delete('/:id/members/:userId', asyncHandler(async (req, res) => {
  const groupId = requireUuid(req.params.id, 'id');
  const targetId = requireUuid(req.params.userId, 'userId');
  const membership = await loadMembership(groupId, req.user.id);
  const isSelf = targetId === req.user.id;

  if (!isSelf && membership.role !== 'owner') {
    throw HttpError.forbidden('Csak a csoport tulajdonosa távolíthat el más tagot.');
  }

  if (isSelf && membership.role === 'owner') {
    throw HttpError.badRequest(
      'A csoport tulajdonosa nem léphet ki. Töröld a csoportot, vagy add át másnak a vezetését.',
    );
  }

  const removed = await query(
    'DELETE FROM group_members WHERE group_id = $1 AND user_id = $2 RETURNING group_id',
    [groupId, targetId],
  );

  if (removed.rowCount === 0) {
    throw HttpError.notFound('A felhasználó nem tagja a csoportnak.');
  }

  res.status(204).send();
}));

module.exports = router;



