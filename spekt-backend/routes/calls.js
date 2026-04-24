/**
 * routes/calls.js
 *
 * Read-only API for processed call results — consumed by the iOS app.
 *
 * Returns completed sessions in the same shape as GET /api/sessions/:id/status
 * so the existing iOS CallSessionStatusResponse decoder works without changes.
 *
 *   GET /api/calls            → array of all completed calls, newest first
 *   GET /api/calls/latest     → most recently completed call (or 404)
 *   GET /api/calls/:id        → specific call by session ID
 */

const { Router } = require('express');
const store = require('../services/sessionStore');

const router = Router();

// ── GET /api/calls ────────────────────────────────────────────────────────────

router.get('/', (_req, res) => {
  const calls = store.all()
    .filter(s => s.status === 'ready' && s.results)
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
    .map(toCallResponse);

  res.json(calls);
});

// ── GET /api/calls/latest ─────────────────────────────────────────────────────
// Must be declared BEFORE /:id to avoid "latest" being treated as an ID.

router.get('/latest', (_req, res) => {
  const latest = store.all()
    .filter(s => s.status === 'ready' && s.results)
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0];

  if (!latest) {
    return res.status(404).json({ error: 'No completed calls found' });
  }

  res.json(toCallResponse(latest));
});

// ── GET /api/calls/:id ────────────────────────────────────────────────────────

router.get('/:id', (req, res) => {
  const session = store.get(req.params.id);

  if (!session) {
    return res.status(404).json({ error: 'Call not found' });
  }

  res.json(toCallResponse(session));
});

// ── Helper ────────────────────────────────────────────────────────────────────

/**
 * Maps a session object to the CallSessionStatusResponse shape the iOS app
 * already knows how to decode.
 */
function toCallResponse(session) {
  return {
    sessionId: session.id,
    status:    session.status,
    progress:  session.progress ?? null,
    results:   session.status === 'ready' ? session.results : null,
    error:     session.errorMessage ?? null,
  };
}

module.exports = router;
