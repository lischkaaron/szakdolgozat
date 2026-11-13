'use strict';

/**
 * HTTP hibák egységes reprezentációja.
 * A middleware/error.js alakítja JSON válasszá.
 */
class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.details = details;
  }

  static badRequest(message, details) {
    return new HttpError(400, message, details);
  }

  static unauthorized(message = 'Hiányzó vagy érvénytelen hitelesítés.') {
    return new HttpError(401, message);
  }

  static forbidden(message = 'Nincs jogosultságod ehhez a művelethez.') {
    return new HttpError(403, message);
  }

  static notFound(message = 'Az erőforrás nem található.') {
    return new HttpError(404, message);
  }

  static conflict(message) {
    return new HttpError(409, message);
  }
}

module.exports = { HttpError };
