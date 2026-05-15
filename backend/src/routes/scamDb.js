'use strict';

const express = require('express');
const router  = express.Router();

router.get('/latest-version', async (req, res, next) => {
  try {
    /* TODO: query db_meta table */
    res.json({ version: 1, recordCount: 0, updatedAt: new Date().toISOString() });
  } catch (err) { next(err); }
});

router.get('/download', async (req, res, next) => {
  try {
    const { version } = req.query;
    /* TODO: stream delta JSON for the requested version */
    res.json({ version, entries: [] });
  } catch (err) { next(err); }
});

router.post('/report', async (req, res, next) => {
  try {
    const { phoneOrDomain, category, evidence } = req.body;
    if (!phoneOrDomain || !category) {
      return res.status(400).json({ error: 'phoneOrDomain and category required' });
    }
    /* TODO: insert into pending_reports table for moderation */
    res.status(202).json({ received: true });
  } catch (err) { next(err); }
});

router.get('/stats', async (req, res, next) => {
  try {
    res.json({ totalRecords: 0, lastUpdated: new Date().toISOString() });
  } catch (err) { next(err); }
});

module.exports = router;
