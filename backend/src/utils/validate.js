'use strict';

const { HttpError } = require('./httpError');

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Kötelező, nem üres szöveg (trim-elve) adott hosszhatárokkal. */
function requireString(value, field, { min = 1, max = 255 } = {}) {
  if (typeof value !== 'string') {
    throw HttpError.badRequest(`A(z) "${field}" mező kötelező.`);
  }

  const trimmed = value.trim();

  if (trimmed.length < min) {
    throw HttpError.badRequest(`A(z) "${field}" mező legalább ${min} karakter legyen.`);
  }

  if (trimmed.length > max) {
    throw HttpError.badRequest(`A(z) "${field}" mező legfeljebb ${max} karakter lehet.`);
  }

  return trimmed;
}

/** Opcionális szöveg: hiányzó érték -> null, üres szöveg -> null. */
function optionalString(value, field, { max = 255 } = {}) {
  if (value === undefined || value === null || value === '') {
    return null;
  }

  if (typeof value !== 'string') {
    throw HttpError.badRequest(`A(z) "${field}" mező szöveg kell legyen.`);
  }

  const trimmed = value.trim();

  if (trimmed.length === 0) {
    return null;
  }

  if (trimmed.length > max) {
    throw HttpError.badRequest(`A(z) "${field}" mező legfeljebb ${max} karakter lehet.`);
  }

  return trimmed;
}

/** E-mail cím validálás + normalizálás (kisbetűs, trim-elt). */
function requireEmail(value) {
  const email = requireString(value, 'email', { min: 3, max: 254 }).toLowerCase();

  if (!EMAIL_PATTERN.test(email)) {
    throw HttpError.badRequest('Érvénytelen e-mail cím formátum.');
  }

  return email;
}

/** Jelszó: 8-72 karakter (a bcrypt maximuma 72 bájt). */
function requirePassword(value) {
  if (typeof value !== 'string') {
    throw HttpError.badRequest('A "password" mező kötelező.');
  }

  if (value.length < 8) {
    throw HttpError.badRequest('A jelszó legalább 8 karakter legyen.');
  }

  if (value.length > 72) {
    throw HttpError.badRequest('A jelszó legfeljebb 72 karakter lehet.');
  }

  return value;
}

/** UUID validálás (útvonal-paraméterekhez, pl. /friends/:id). */
function requireUuid(value, field = 'id') {
  if (typeof value !== 'string' || !UUID_PATTERN.test(value)) {
    throw HttpError.badRequest(`A(z) "${field}" érvénytelen azonosító (UUID) formátumú.`);
  }

  return value;
}

module.exports = { requireString, optionalString, requireEmail, requirePassword, requireUuid };
