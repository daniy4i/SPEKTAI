/**
 * server.js — SPEKT AI Backend
 *
 * The AI lives at +1 (910) 773-5824 — this server does NOT host it.
 * This server receives Twilio recording webhooks after calls end,
 * processes them, and serves the results to the iOS app.
 *
 * iOS endpoints:
 *   POST /api/sessions/initiate      — create session before dialing
 *   GET  /api/sessions/:id/status    — poll for processing status + results
 *   GET  /api/calls                  — list all completed calls
 *   GET  /api/calls/latest           — most recent completed call
 *   GET  /api/calls/:id              — specific call
 *   GET  /api/tasks                  — list tasks
 *   POST /api/tasks                  — create task
 *   PATCH  /api/tasks/:id            — update task
 *   DELETE /api/tasks/:id            — delete task
 *   GET  /api/memories               — list memories
 *   POST /api/memories               — create memory
 *   PATCH  /api/memories/:id         — pin / edit memory
 *   DELETE /api/memories/:id         — delete memory
 *   DELETE /api/memories             — delete all memories
 *   GET  /api/patterns               — usage pattern stats
 *   GET  /api/preferences            — get preferences
 *   POST /api/preferences            — save preferences
 *
 * Twilio webhook endpoints:
 *   POST /twilio/voice               — inbound call (returns Record TwiML)
 *   POST /twilio/recording-complete  — recording ready → transcribe + extract
 *
 * Deploy to Railway / Render / Fly.io.
 * Set BASE_URL to your public HTTPS URL so Twilio can reach the webhooks.
 */

require('dotenv').config();

const express = require('express');
const cors    = require('cors');

const app  = express();
const PORT = process.env.PORT ?? 3000;

// ── Env check ─────────────────────────────────────────────────────────────────

const REQUIRED = [
  'OPENAI_API_KEY',
  'TWILIO_ACCOUNT_SID',
  'TWILIO_AUTH_TOKEN',
  'TWILIO_PHONE_NUMBER',
  'BASE_URL',
];
const missing = REQUIRED.filter(k => !process.env[k]);
if (missing.length) {
  console.warn(`[Config] Missing env vars: ${missing.join(', ')} — see .env.example`);
}

// ── Middleware ────────────────────────────────────────────────────────────────

app.use('/twilio', express.urlencoded({ extended: false })); // Twilio POSTs form-encoded
app.use('/api',    express.json());                          // iOS POSTs JSON

app.use(cors({ origin: process.env.ALLOWED_ORIGIN ?? '*' }));

// ── Routes ────────────────────────────────────────────────────────────────────

const sessionsRouter    = require('./routes/sessions');
const tasksRouter       = require('./routes/tasks');
const callsRouter       = require('./routes/calls');
const memoriesRouter    = require('./routes/memories');
const patternsRouter    = require('./routes/patterns');
const preferencesRouter = require('./routes/preferences');
const twilioRouter      = require('./routes/twilio');

app.use('/api/sessions',    sessionsRouter);
app.use('/api/tasks',       tasksRouter);
app.use('/api/calls',       callsRouter);
app.use('/api/memories',    memoriesRouter);
app.use('/api/patterns',    patternsRouter);
app.use('/api/preferences', preferencesRouter);
app.use('/twilio',          twilioRouter);

// ── Health ────────────────────────────────────────────────────────────────────

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', ts: new Date().toISOString() });
});

// ── Start ─────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  const base = process.env.BASE_URL ?? 'http://localhost:' + PORT;
  console.log(`SPEKT backend :${PORT}`);
  console.log(`  Voice webhook:     POST ${base}/twilio/voice`);
  console.log(`  Recording webhook: POST ${base}/twilio/recording-complete`);
  console.log(`  iOS calls API:     GET  ${base}/api/calls/latest`);
});
