/**
 * routes/memories.js
 *
 * REST API for SPEKT memories — consumed by the iOS SignalView.
 *
 *   GET    /api/memories              → list (newest first, pinned on top)
 *   POST   /api/memories              → create { content }
 *   PATCH  /api/memories/:id          → update { content?, is_pinned? }
 *   DELETE /api/memories/:id          → delete single
 *   DELETE /api/memories              → delete all for user
 */

const { Router } = require('express');
const store = require('../services/memoryStore');

const router = Router();

// ── GET /api/memories ─────────────────────────────────────────────────────────

router.get('/', (req, res) => {
  const userId = req.query.user_id ?? 'anonymous';
  const limit  = req.query.limit ? parseInt(req.query.limit, 10) : 100;

  const memories = store.list({ userId, limit });
  res.json(memories);
});

// ── POST /api/memories ────────────────────────────────────────────────────────

router.post('/', (req, res) => {
  const { content, user_id: userId = 'anonymous' } = req.body;

  if (!content?.trim()) {
    return res.status(400).json({ error: 'content is required' });
  }

  try {
    const memory = store.create({ userId, content });
    res.status(201).json(memory);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ── PATCH /api/memories/:id ───────────────────────────────────────────────────

router.patch('/:id', (req, res) => {
  const { content, is_pinned } = req.body;

  const memory = store.update(req.params.id, { content, is_pinned });

  if (!memory) {
    return res.status(404).json({ error: 'Memory not found' });
  }

  res.json(memory);
});

// ── DELETE /api/memories/:id ──────────────────────────────────────────────────

router.delete('/:id', (req, res) => {
  const deleted = store.delete(req.params.id);

  if (!deleted) {
    return res.status(404).json({ error: 'Memory not found' });
  }

  res.status(204).send();
});

// ── DELETE /api/memories ──────────────────────────────────────────────────────

router.delete('/', (req, res) => {
  const userId = req.query.user_id ?? null;
  store.deleteAll(userId);
  res.status(204).send();
});

module.exports = router;
