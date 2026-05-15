'use strict';

const express = require('express');
const router  = express.Router();

router.post('/invite',         async (req, res) => res.json({ inviteCode: 'inv-' + Date.now() }));
router.post('/accept',         async (req, res) => res.json({ joined: true }));
router.delete('/members/:id',  async (req, res) => res.json({ removed: true }));
router.get('/locations',       async (req, res) => res.json({ members: [] }));

module.exports = router;
