'use strict';

require('dotenv').config();

const express    = require('express');
const helmet     = require('helmet');
const cors       = require('cors');
const rateLimit  = require('express-rate-limit');
const { logger } = require('./utils/logger');

const authRoutes   = require('./routes/auth');
const scamDbRoutes = require('./routes/scamDb');
const modelRoutes  = require('./routes/models');
const userRoutes   = require('./routes/user');
const familyRoutes = require('./routes/family');
const safetyRoutes = require('./routes/safety');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') ?? [] }));
app.use(express.json({ limit: '1mb' }));

/* Global rate limiter */
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,  /* 15 min */
  max:      100,
  standardHeaders: true,
  legacyHeaders:   false,
}));

/* Routes */
app.use('/api/v1/auth',     authRoutes);
app.use('/api/v1/scam-db',  scamDbRoutes);
app.use('/api/v1/models',   modelRoutes);
app.use('/api/v1/user',     userRoutes);
app.use('/api/v1/family',   familyRoutes);
app.use('/api/v1/safety',   safetyRoutes);

app.get('/health', (_, res) => res.json({ status: 'ok', ts: Date.now() }));

/* Global error handler */
app.use((err, req, res, _next) => {
  logger.error({ err, path: req.path });
  const status = err.status ?? 500;
  res.status(status).json({ error: err.message ?? 'Internal server error' });
});

app.listen(PORT, () => logger.info(`API server listening on port ${PORT}`));

module.exports = app;
