'use strict';

const express = require('express');
const { pool, query } = require('../db/pool');
const { asyncHandler } = require('../utils/asyncHandler');
const { HttpError } = require('../utils/httpError');
const { requireEmail, requireUuid } = require('../utils/validate');
const { toFriend, toFriendRequest } = require('../utils/serializers');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// Minden barát-végpont csak bejelentkezve hívható.
router.use(requireAuth);

/**
 * GET /api/friends
 * A bejelentkezett felhasználó barátai.
 */
router.get('/', asyncHandler(async (req, res) => {
  const result = await query(
    `SELECT u.id, u.email, u.display_name, u.motorcycle, f.created_at AS friends_since
     FROM friends f
     JOIN users u ON u.id = f.friend_id
     WHERE f.user_id = $1
     ORDER BY u.display_name`,
    [req.user.id],
  );

  res.json({ friends: result.rows.map(toFriend) });
}));

/**
 * GET /api/friends/requests
 * Bemenő és kimenő barátkérések: { pending: [...], history: [...] }
 */
router.get('/requests', asyncHandler(async (req, res) => {
  const result = await query(
    `SELECT fr.id, fr.status, fr.created_at, fr.responded_at,
            fr.requester_id, fr.addressee_id,
            rq.display_name AS requester_name,
            ad.display_name AS addressee_name
     FROM friend_requests fr
     JOIN users rq ON rq.id = fr.requester_id
     JOIN users ad ON ad.id = fr.addressee_id
     WHERE fr.requester_id = $1 OR fr.addressee_id = $1
     ORDER BY fr.created_at DESC`,
    [req.user.id],
  );

  const requests = result.rows.map((row) => toFriendRequest({
    ...row,
    direction: row.addressee_id === req.user.id ? 'incoming' : 'outgoing',
  }));

  res.json({
    pending: requests.filter((request) => request.status === 'pending'),
    history: requests.filter((request) => request.status !== 'pending'),
  });
}));

/**
 * POST /api/friends/requests
 * Body: { email } vagy { userId }
 * 201 -> { request }
 */
router.post('/requests', asyncHandler(async (req, res) => {
  const { email, userId } = req.body || {};
  let target;

  if (email !== undefined) {
    const targetEmail = requireEmail(email);
    const found = await query(
      'SELECT id, display_name, email, motorcycle FROM users WHERE email = $1',
      [targetEmail],
    );
    target = found.rows[0];
  } else if (userId !== undefined) {
    const targetId = requireUuid(userId, 'userId');
    const found = await query(
      'SELECT id, display_name, email, motorcycle FROM users WHERE id = $1',
      [targetId],
    );
    target = found.rows[0];
  } else {
    throw HttpError.badRequest('Add meg a barát e-mail címét (email) vagy azonosítóját (userId).');
  }

  if (!target) {
    throw HttpError.notFound('Nem található felhasználó a megadott adatokkal.');
  }

  if (target.id === req.user.id) {
    throw HttpError.badRequest('Saját magadat nem jelölheted be barátnak.');
  }

  const alreadyFriends = await query(
    'SELECT 1 FROM friends WHERE user_id = $1 AND friend_id = $2',
    [req.user.id, target.id],
  );

  if (alreadyFriends.rowCount > 0) {
    throw HttpError.conflict('Ez a felhasználó már a barátod.');
  }

  const reverseRequest = await query(
    `SELECT id FROM friend_requests
     WHERE requester_id = $1 AND addressee_id = $2 AND status = 'pending'`,
    [target.id, req.user.id],
  );

  if (reverseRequest.rowCount > 0) {
    throw HttpError.conflict('Ez a felhasználó már küldött neked barátkérést, azt fogadd el.');
  }

  let created;

  try {
    const inserted = await query(
      `INSERT INTO friend_requests (requester_id, addressee_id)
       VALUES ($1, $2)
       RETURNING id, status, created_at`,
      [req.user.id, target.id],
    );
    created = inserted.rows[0];
  } catch (error) {
    if (error.code === '23505') {
      throw HttpError.conflict('Már küldtél barátkérést ennek a felhasználónak.');
    }
    throw error;
  }

  res.status(201).json({
    request: {
      id: created.id,
      status: created.status,
      createdAt: created.created_at,
      addressee: { id: target.id, displayName: target.display_name },
    },
  });
}));

/**
 * POST /api/friends/requests/:id/accept
 * Csak a címzett fogadhatja el. Tranzakcióban írja be a friends táblát
 * mindkét irányban.
 */
router.post('/requests/:id/accept', asyncHandler(async (req, res) => {
  const requestId = requireUuid(req.params.id, 'id');
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const found = await client.query(
      `SELECT id, requester_id, addressee_id, status
       FROM friend_requests
       WHERE id = $1
       FOR UPDATE`,
      [requestId],
    );

    const request = found.rows[0];

    if (!request) {
      throw HttpError.notFound('A barátkérés nem található.');
    }

    if (request.addressee_id !== req.user.id) {
      throw HttpError.forbidden('Csak a címzett fogadhatja el a barátkérést.');
    }

    if (request.status !== 'pending') {
      throw HttpError.conflict('A barátkérés már nem függő állapotban van.');
    }

    await client.query(
      `UPDATE friend_requests SET status = 'accepted', responded_at = now() WHERE id = $1`,
      [requestId],
    );

    await client.query(
      `INSERT INTO friends (user_id, friend_id)
       VALUES ($1, $2), ($2, $1)
       ON CONFLICT DO NOTHING`,
      [request.requester_id, request.addressee_id],
    );

    await client.query('COMMIT');

    res.json({ accepted: true, friendId: request.requester_id });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}));

/**
 * POST /api/friends/requests/:id/decline
 */
router.post('/requests/:id/decline', asyncHandler(async (req, res) => {
  const requestId = requireUuid(req.params.id, 'id');

  const result = await query(
    `UPDATE friend_requests
     SET status = 'declined', responded_at = now()
     WHERE id = $1 AND addressee_id = $2 AND status = 'pending'
     RETURNING id`,
    [requestId, req.user.id],
  );

  if (result.rowCount === 0) {
    throw HttpError.notFound('Nincs elutasítható, függő barátkérés ezzel az azonosítóval.');
  }

  res.json({ declined: true });
}));

/**
 * DELETE /api/friends/requests/:id
 * A küldő visszavonja a még függő (pending) barátkérését.
 */
router.delete('/requests/:id', asyncHandler(async (req, res) => {
  const requestId = requireUuid(req.params.id, 'id');

  const result = await query(
    `DELETE FROM friend_requests
     WHERE id = $1 AND requester_id = $2 AND status = 'pending'
     RETURNING id`,
    [requestId, req.user.id],
  );

  if (result.rowCount === 0) {
    throw HttpError.notFound('Nincs visszavonható, függő barátkérés ezzel az azonosítóval.');
  }

  res.status(204).send();
}));

/**
 * DELETE /api/friends/:userId
 * Barátság megszüntetése (mindkét irányban).
 */
router.delete('/:userId', asyncHandler(async (req, res) => {
  const friendId = requireUuid(req.params.userId, 'userId');

  const result = await query(
    `DELETE FROM friends
     WHERE (user_id = $1 AND friend_id = $2)
        OR (user_id = $2 AND friend_id = $1)`,
    [req.user.id, friendId],
  );

  if (result.rowCount === 0) {
    throw HttpError.notFound('Ez a felhasználó nem szerepel a barátaid között.');
  }

  res.status(204).send();
}));

module.exports = router;
