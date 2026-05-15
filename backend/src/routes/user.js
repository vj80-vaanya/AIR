'use strict';

const express = require('express');
const router  = express.Router();

router.get('/profile',  async (req, res) => res.json({ id: '', phone: '', name: '' }));
router.put('/profile',  async (req, res) => res.json({ updated: true }));
router.get('/devices',  async (req, res) => res.json({ devices: [] }));
router.delete('/data',  async (req, res) => res.json({ deleted: true }));
router.post('/export',  async (req, res) => res.json({ jobId: 'export-' + Date.now() }));

module.exports = router;
