'use strict';

const jwt = require('jsonwebtoken');
const config = require('../config');
const { HttpError } = require('../utils/httpError');

/** JWT access token kiállítása a felhasználóhoz. */
function signToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn },
  );
}

/**
 * Bearer token ellenőrzése. Siker esetén req.user = { id, email }.
 * A védett végpontokon ezt a middleware-t kell használni.
 */
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(HttpError.unauthorized('Hiányzó Bearer token az Authorization fejlécben.'));
  }

  try {
    const payload = jwt.verify(token, config.jwt.secret);
    req.user = { id: payload.sub, email: payload.email };
    return next();
  } catch (error) {
    const message = error.name === 'TokenExpiredError'
      ? 'Lejárt a token, jelentkezz be újra.'
      : 'Érvénytelen token.';
    return next(HttpError.unauthorized(message));
  }
}

module.exports = { signToken, requireAuth };
