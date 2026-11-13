'use strict';

const express = require('express');
const { query } = require('../db/pool');
const { asyncHandler } = require('../utils/asyncHandler');
const { HttpError } = require('../utils/httpError');
const { requireString, optionalString } = require('../utils/validate');
const { toPublicUser } = require('../utils/serializers');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

const USER_COLUMNS = 'id, email, display_name, motorcycle, created_at';

/**
 * GET /api/users/me
 * A bejelentkezett felhasználó profilja.
 */
router.get('/me', requireAuth, asyncHandler(async (req, res) => {
  const result = await query(`SELECT ${USER_COLUMNS} FROM users WHERE id = $1`, [req.user.id]);

  if (result.rowCount === 0) {
    throw HttpError.unauthorized('A tokenhez tartozó felhasználó már nem létezik.');
  }

  res.json({ user: toPublicUser(result.rows[0]) });
}));

/**
 * PATCH /api/users/me
 * Body: { displayName?, motorcycle? } - csak a megadott mezők módosulnak.
 */
router.patch('/me', requireAuth, asyncHandler(async (req, res) => {
  const updates = [];
  const params = [req.user.id];

  if (req.body?.displayName !== undefined) {
    const displayName = requireString(req.body.displayName, 'displayName', { min: 2, max: 80 });
    params.push(displayName);
    updates.push(`display_name = $${params.length}`);
  }

  if (req.body?.motorcycle !== undefined) {
    const motorcycle = optionalString(req.body.motorcycle, 'motorcycle', { max: 120 });
    params.push(motorcycle);
    updates.push(`motorcycle = $${params.length}`);
  }

  if (updates.length === 0) {
    throw HttpError.badRequest('Nincs módosítható mező. Add meg a displayName és/vagy motorcycle mezőt.');
  }

  const result = await query(
    `UPDATE users SET ${updates.join(', ')}
     WHERE id = $1
     RETURNING ${USER_COLUMNS}`,
    params,
  );

  if (result.rowCount === 0) {
    throw HttpError.unauthorized('A tokenhez tartozó felhasználó már nem létezik.');
  }

  res.json({ user: toPublicUser(result.rows[0]) });
}));

/**
 * GET /api/users/search?q=...
 * Barátkeresés név vagy e-mail alapján (a saját fiók nélkül).
 */
router.get('/search', requireAuth, asyncHandler(async (req, res) => {
  const term = requireString(req.query.q, 'q', { min: 2, max: 80 });

  const result = await query(
    `SELECT ${USER_COLUMNS}
     FROM users
     WHERE id <> $1
       AND (email ILIKE $2 OR display_name ILIKE $2)
     ORDER BY display_name
     LIMIT 20`,
    [req.user.id, `%${term}%`],
  );

  res.json({ users: result.rows.map(toPublicUser) });
}));

/**
 * GET /api/users/:id
 * Egy felhasználó nyilvános adatai (pl. túra résztvevőinek megjelenítéséhez).
 * A barátlistán szereplő felhasználókat, illetve önmagunkat lehet lekérdezni.
 */
router.get('/:id', requireAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;

  if (id !== req.user.id) {
    const friendCheck = await query(
      'SELECT 1 FROM friends WHERE user_id = $1 AND friend_id = $2',
      [req.user.id, id],
    );

    if (friendCheck.rowCount === 0) {
      throw HttpError.forbidden('Csak a barátaid adatait tekintheted meg.');
    }
  }

  const result = await query(`SELECT ${USER_COLUMNS} FROM users WHERE id = $1`, [id]);

  if (result.rowCount === 0) {
    throw HttpError.notFound('A felhasználó nem található.');
  }

  res.json({ user: toPublicUser(result.rows[0]) });
}));

module.exports = router;
