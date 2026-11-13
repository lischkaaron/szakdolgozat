'use strict';

require('dotenv').config();

const DEFAULTS = {
  PORT: '3000',
  NODE_ENV: 'development',
  DATABASE_URL: 'postgres://moto:moto_dev_pw@localhost:5432/moto_konvoj',
  JWT_SECRET: 'dev-only-insecure-secret-change-me',
  JWT_EXPIRES_IN: '7d',
  BCRYPT_ROUNDS: '10',
  CORS_ORIGIN: '*',
};

function read(name) {
  const value = process.env[name];
  return value === undefined || value === '' ? DEFAULTS[name] : value;
}

const config = {
  env: read('NODE_ENV'),
  port: Number.parseInt(read('PORT'), 10),
  databaseUrl: read('DATABASE_URL'),
  bcryptRounds: Number.parseInt(read('BCRYPT_ROUNDS'), 10),
  corsOrigin: read('CORS_ORIGIN'),
  jwt: {
    secret: read('JWT_SECRET'),
    expiresIn: read('JWT_EXPIRES_IN'),
  },
  get isProd() {
    return this.env === 'production';
  },
};

if (config.isProd && config.jwt.secret === DEFAULTS.JWT_SECRET) {
  throw new Error('Éles módban a JWT_SECRET nem maradhat az alapértelmezett értéken!');
}

module.exports = config;
