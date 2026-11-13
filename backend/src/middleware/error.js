'use strict';

const config = require('../config');
const { HttpError } = require('../utils/httpError');

/** Ismeretlen végpont -> 404 JSON. */
function notFoundHandler(req, res, next) {
  next(new HttpError(404, `Ismeretlen végpont: ${req.method} ${req.originalUrl}`));
}

/** Egységes JSON hibaformátum: { error: { message, details? } }. */
// eslint-disable-next-line no-unused-vars
function errorHandler(error, req, res, next) {
  const status = Number.isInteger(error.status) ? error.status : 500;

  if (status >= 500) {
    console.error('[error]', error);
  }

  const message = status >= 500 && config.isProd
    ? 'Váratlan szerverhiba történt.'
    : error.message;

  res.status(status).json({
    error: {
      message,
      ...(error.details ? { details: error.details } : {}),
    },
  });
}

module.exports = { notFoundHandler, errorHandler };
