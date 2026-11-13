'use strict';

const path = require('node:path');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const config = require('./config');
const healthRoutes = require('./routes/health');
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const friendRoutes = require('./routes/friends');
const groupRoutes = require('./routes/groups');
const { notFoundHandler, errorHandler } = require('./middleware/error');

const DOCS_HTML = `<!doctype html>
<html lang="hu">
  <head>
    <meta charset="utf-8" />
    <title>Motoros Konvoj API</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
  </head>
  <body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script>
      window.ui = SwaggerUIBundle({ url: '/openapi.yaml', dom_id: '#swagger-ui' });
    </script>
  </body>
</html>`;

function createApp() {
  const app = express();

  app.set('trust proxy', true);
  app.disable('x-powered-by');

  app.use(helmet({ crossOriginResourcePolicy: false }));
  app.use(cors({
    origin: config.corsOrigin === '*'
      ? true
      : config.corsOrigin.split(',').map((origin) => origin.trim()),
  }));
  app.use(express.json({ limit: '1mb' }));

  // Egyszerű kérésnaplózás a fejlesztéshez.
  app.use((req, res, next) => {
    const startedAt = Date.now();
    res.on('finish', () => {
      console.log(`[http] ${req.method} ${req.originalUrl} -> ${res.statusCode} (${Date.now() - startedAt} ms)`);
    });
    next();
  });

  // Nyilvános végpontok
  app.use(healthRoutes);
  app.get('/openapi.yaml', (req, res) => {
    res.sendFile(path.join(__dirname, '..', 'openapi.yaml'));
  });
  app.get('/api/docs', (req, res) => {
    res.type('html').send(DOCS_HTML);
  });

  // API végpontok
  app.use('/api/auth', authRoutes);
  app.use('/api/users', userRoutes);
  app.use('/api/friends', friendRoutes);
  app.use('/api/groups', groupRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
