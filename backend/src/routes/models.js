'use strict';

const express = require('express');
const router  = express.Router();

router.get('/latest',   async (req, res) => res.json({ type: req.query.type, version: 1, size: 0 }));
router.get('/download', async (req, res) => res.json({ url: '', checksum: '' }));
router.post('/feedback', async (req, res) => res.json({ recorded: true }));

module.exports = router;
