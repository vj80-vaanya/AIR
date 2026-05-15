'use strict';

const express = require('express');
const router  = express.Router();
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcryptjs');
const jwt    = require('jsonwebtoken');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  next();
};

router.post('/register',
  body('phone').isMobilePhone('en-IN'),
  body('password').isLength({ min: 8 }),
  validate,
  async (req, res, next) => {
    try {
      const { phone, password } = req.body;
      const hash = await bcrypt.hash(password, 12);
      /* TODO: persist to PostgreSQL */
      const token = jwt.sign({ phone }, process.env.JWT_SECRET, { expiresIn: '30d' });
      res.status(201).json({ token });
    } catch (err) {
      next(err);
    }
  },
);

router.post('/login',
  body('phone').isMobilePhone(),
  body('password').notEmpty(),
  validate,
  async (req, res, next) => {
    try {
      /* TODO: load user from DB, compare hash */
      const token = jwt.sign({ phone: req.body.phone }, process.env.JWT_SECRET, { expiresIn: '30d' });
      res.json({ token });
    } catch (err) {
      next(err);
    }
  },
);

router.post('/logout', (req, res) => {
  /* Token invalidation via Redis blocklist in production */
  res.json({ success: true });
});

module.exports = router;
