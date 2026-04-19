/**
 * routes/sessions.js
 *
 * iOS-facing endpoints:
 *
 *   POST /api/sessions/initiate
 *     — Called by the app before dialing.
 *       Creates a pending session and returns its ID.
 *       App stores the ID, dials the Twilio number, then polls status.
 *
 *   GET /api/sessions/:id/status
 *     — Long-poll-friendly status endpoint.
 *       Returns current status + progress message + results (when ready).
 *
 *   GET /api/sessions (debug only, remove in production)
 */

const { Router } = require('express');
const store = require('../services/sessionStore');

const router = Router();

// ── POST /api/sessions/initiate ───────────────────────────────────────────

router.post('/initiate', (req, res) => {
  const { userId = 'anonymous' } = req.body;

  const session = store.create({ userId });

  res.status(201).json({
    sessionId:   session.id,
    phoneNumber: process.env.TWILIO_PHONE_NUMBER,
    expiresIn:   7200,  // seconds
  });
});

// ── GET /api/sessions/:id/status ──────────────────────────────────────────

router.get('/:id/status', (req, res) => {
  const session = store.get(req.params.id);

  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }

  // Shape returned to iOS
  const payload = {
    sessionId: session.id,
    status:    session.status,
    progress:  session.progress,
    results:   null,
  };

  if (session.status === 'ready' && session.results) {
    payload.results = session.results;
  }

  if (session.status === 'failed') {
    payload.error = session.errorMessage ?? 'Processing failed';
  }

  res.json(payload);
});

// ── GET /api/sessions (debug) ─────────────────────────────────────────────

router.get('/', (_req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(403).json({ error: 'Forbidden' });
  }
  res.json(store.all());
});

module.exports = router;
