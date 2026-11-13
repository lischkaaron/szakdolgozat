'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');
const config = require('../config');
const { query } = require('../db/pool');
const { asyncHandler } = require('../utils/asyncHandler');
const { HttpError } = require('../utils/httpError');
const { requireEmail, requirePassword, requireString, optionalString } = require('../utils/validate');
const { toPublicUser } = require('../utils/serializers');
const { signToken } = require('../middleware/auth');

const router = express.Router();

/**
 * POST /api/auth/register
 * Body: { email, password, displayName, motorcycle? }
 * 201 -> { token, user }
 */
router.post('/register', asyncHandler(async (req, res) => {
  const email = requireEmail(req.body?.email);
  const password = requirePassword(req.body?.password);
  const displayName = requireString(req.body?.displayName, 'displayName', { min: 2, max: 80 });
  const motorcycle = optionalString(req.body?.motorcycle, 'motorcycle', { max: 120 });

  const passwordHash = await bcrypt.hash(password, config.bcryptRounds);

  let created;

  try {
    const result = await query(
      `INSERT INTO users (email, password_hash, display_name, motorcycle)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, display_name, motorcycle, created_at`,
      [email, passwordHash, displayName, motorcycle],
    );
    created = result.rows[0];
  } catch (error) {
    if (error.code === '23505') {
      throw HttpError.conflict('Ezzel az e-mail címmel már létezik felhasználó.');
    }
    throw error;
  }

  const user = toPublicUser(created);
  res.status(201).json({ token: signToken(user), user });
}));

/**
 * POST /api/auth/login
 * Body: { email, password }
 * 200 -> { token, user }
 */
router.post('/login', asyncHandler(async (req, res) => {
  const email = requireEmail(req.body?.email);
  const password = requireString(req.body?.password, 'password', { min: 1, max: 72 });

  const result = await query(
    `SELECT id, email, password_hash, display_name, motorcycle, created_at
     FROM users
     WHERE email = $1`,
    [email],
  );

  const row = result.rows[0];
  const passwordMatches = row ? await bcrypt.compare(password, row.password_hash) : false;

  if (!row || !passwordMatches) {
    throw HttpError.unauthorized('Hibás e-mail cím vagy jelszó.');
  }

  const user = toPublicUser(row);
  res.json({ token: signToken(user), user });
}));

module.exports = router;
