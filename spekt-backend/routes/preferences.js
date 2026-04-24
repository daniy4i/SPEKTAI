/**
 * routes/preferences.js
 *
 * Stores AI communication preferences per user.
 * The iOS SignalView lets the user tune these; the Realtime AI prompt
 * should eventually read them to personalize responses.
 *
 *   GET  /api/preferences           → current preferences (or defaults)
 *   POST /api/preferences           → upsert preferences
 */

const { Router } = require('express');

const router = Router();

// In-memory store keyed by userId — swap for DB in production
const prefStore = new Map();

const DEFAULTS = {
  voice_tone:   'Direct & concise',
  style:        'Action-first',
  format:       'Bullet points',
  language:     'English (US)',
  detail_level: 'High signal',
};

// ── GET /api/preferences ──────────────────────────────────────────────────────

router.get('/', (req, res) => {
  const userId = req.query.user_id ?? 'anonymous';
  const prefs  = prefStore.get(userId) ?? { ...DEFAULTS };
  res.json(prefs);
});

// ── POST /api/preferences ─────────────────────────────────────────────────────

router.post('/', (req, res) => {
  const {
    user_id:      userId      = 'anonymous',
    voice_tone:   voiceTone,
    style,
    format,
    language,
    detail_level: detailLevel,
  } = req.body;

  const existing = prefStore.get(userId) ?? { ...DEFAULTS };

  const updated = {
    ...existing,
    ...(voiceTone   !== undefined && { voice_tone:   voiceTone }),
    ...(style       !== undefined && { style }),
    ...(format      !== undefined && { format }),
    ...(language    !== undefined && { language }),
    ...(detailLevel !== undefined && { detail_level: detailLevel }),
  };

  prefStore.set(userId, updated);
  res.json(updated);
});

module.exports = router;
