/**
 * server.js — SPEKT AI Backend
 *
 * Pipeline: iOS call → Twilio recording → Whisper → GPT-4o → structured output
 *
 * Routes:
 *   POST /api/sessions/initiate      — iOS: create session before dialing
 *   GET  /api/sessions/:id/status    — iOS: poll for status + results
 *   POST /twilio/voice               — Twilio: inbound call webhook
 *   POST /twilio/recording-complete  — Twilio: recording ready webhook
 *
 * Deploy to Railway, Render, or Fly.io.
 * Set BASE_URL to the public HTTPS URL so Twilio webhooks reach this server.
 */

require('dotenv').config();

const express = require('express');
const cors    = require('cors');

const sessionsRouter = require('./routes/sessions');
const tasksRouter    = require('./routes/tasks');
const twilioRouter   = require('./routes/twilio');

const app  = express();
const PORT = process.env.PORT ?? 3000;

// ── Middleware ────────────────────────────────────────────────────────────

// Twilio sends URL-encoded bodies for webhooks
app.use('/twilio', express.urlencoded({ extended: false }));

// iOS sends JSON
app.use('/api', express.json());

// CORS — lock to your app's domain in production
app.use(cors({
  origin: process.env.ALLOWED_ORIGIN ?? '*',
}));

// ── Routes ────────────────────────────────────────────────────────────────

app.use('/api/sessions', sessionsRouter);
app.use('/api/tasks',    tasksRouter);
app.use('/twilio',       twilioRouter);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', ts: new Date().toISOString() });
});

// ── Start ─────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`SPEKT backend listening on :${PORT}`);
  console.log(`Base URL: ${process.env.BASE_URL ?? 'NOT SET — webhooks will fail'}`);
});
