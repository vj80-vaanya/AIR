'use strict';

const express = require('express');
const router  = express.Router();

/* Server-side SOS backup — fires if the device can't send SMS directly */
router.post('/sos-alert', async (req, res, next) => {
  try {
    const { userId, contacts, latitude, longitude, timestamp } = req.body;
    if (!userId || !contacts?.length) {
      return res.status(400).json({ error: 'userId and contacts required' });
    }
    /* TODO: send SMS/push notifications to contacts via Twilio / FCM */
    res.json({ dispatched: true, contactCount: contacts.length });
  } catch (err) { next(err); }
});

router.get('/history', async (req, res, next) => {
  try {
    /* TODO: query safety_events for authenticated user */
    res.json({ events: [] });
  } catch (err) { next(err); }
});

module.exports = router;
