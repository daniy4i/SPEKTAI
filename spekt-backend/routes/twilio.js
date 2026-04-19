/**
 * routes/twilio.js
 *
 * Twilio webhooks — these fire from Twilio's servers, not the iOS app.
 *
 *   POST /twilio/voice
 *     — Fires when the AI phone number receives an inbound call.
 *       Matches the call to the most recent pending session by timing.
 *       Returns TwiML that greets the caller and starts recording.
 *
 *   POST /twilio/recording-complete
 *     — Fires when the recording is finalised (a few seconds after hangup).
 *       Kicks off the full pipeline:
 *         download recording → Whisper transcription → GPT extraction → store
 *
 * Security note: In production add Twilio webhook signature validation:
 *   const twilio = require('twilio');
 *   const validateRequest = twilio.validateRequest(...);
 */

const { Router } = require('express');
const OpenAI = require('openai');
const store     = require('../services/sessionStore');
const taskStore = require('../services/taskStore');
const { transcribeRecording } = require('../services/transcription');
const { extractInsights } = require('../services/intelligence');

const router = Router();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// ── POST /twilio/voice ────────────────────────────────────────────────────
//
// Twilio sends: From, To, CallSid, CallStatus
// We respond with TwiML.

router.post('/voice', (req, res) => {
  const { From: callerPhone, CallSid } = req.body;

  // Link call to most recent pending session
  const session = store.findMostRecentPending();
  if (session) {
    store.update(session.id, {
      callSid:     CallSid,
      callerPhone: callerPhone,
      status:      'in_call',
      progress:    'Call in progress…',
    });
    console.log(`[Twilio] Call ${CallSid} linked to session ${session.id}`);
  } else {
    console.warn(`[Twilio] No pending session found for call ${CallSid} from ${callerPhone}`);
  }

  const baseUrl = process.env.BASE_URL;

  // TwiML response: greet + record
  const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="Polly.Joanna" language="en-US">
    Hey, I'm ready. Go ahead — I'm listening and recording.
  </Say>
  <Record
    action="${baseUrl}/twilio/recording-complete"
    recordingStatusCallback="${baseUrl}/twilio/recording-status"
    maxLength="3600"
    timeout="5"
    transcribe="false"
    playBeep="false"
  />
  <Say voice="Polly.Joanna">I didn't catch anything. Call back whenever you're ready.</Say>
</Response>`;

  res.type('text/xml').send(twiml);
});

// ── POST /twilio/recording-complete ──────────────────────────────────────
//
// Twilio sends: CallSid, RecordingUrl, RecordingDuration, RecordingSid
// This fires *after* the call ends and the recording is ready.
// We do NOT await the full pipeline here — we kick it off async and
// respond 200 immediately so Twilio doesn't retry.

router.post('/recording-complete', (req, res) => {
  const { CallSid, RecordingUrl } = req.body;

  res.sendStatus(200); // Acknowledge immediately

  // Find session and kick off pipeline async
  const session = store.findByCallSid(CallSid) ?? store.findMostRecentPending();
  if (!session) {
    console.error(`[Pipeline] No session for CallSid ${CallSid}`);
    return;
  }

  console.log(`[Pipeline] Starting for session ${session.id}`);
  runPipeline(session.id, RecordingUrl).catch((err) => {
    console.error(`[Pipeline] Fatal error for session ${session.id}:`, err);
    store.update(session.id, {
      status:       'failed',
      progress:     'Something went wrong.',
      errorMessage: err.message,
    });
  });
});

// ── POST /twilio/recording-status (optional status callback) ─────────────

router.post('/recording-status', (req, res) => {
  console.log('[Twilio] Recording status:', req.body.RecordingStatus);
  res.sendStatus(200);
});

// ── Pipeline ──────────────────────────────────────────────────────────────

async function runPipeline(sessionId, recordingUrl) {
  // Stage 1: Processing
  store.update(sessionId, {
    status:      'processing',
    progress:    'Processing your call…',
    recordingUrl,
  });

  // Stage 2: Transcription
  store.update(sessionId, {
    status:   'transcribing',
    progress: 'Transcribing conversation…',
  });

  const transcript = await transcribeRecording(openai, recordingUrl);
  console.log(`[Pipeline] Transcription complete (${transcript.length} chars)`);

  // Stage 3: Intelligence extraction
  store.update(sessionId, {
    status:   'extracting',
    progress: 'Extracting insights…',
  });

  const insights = await extractInsights(openai, transcript);
  console.log(`[Pipeline] Insights extracted — ${insights.tasks.length} tasks, ${insights.memories.length} memories`);

  // Stage 4: Persist tasks to task store
  const persistedTasks = taskStore.createBatch(insights.tasks, sessionId);
  console.log(`[Pipeline] Persisted ${persistedTasks.length} tasks`);

  // Stage 5: Store structured output on session
  const results = {
    transcript,
    summary:            insights.summary,
    tasks:              persistedTasks,   // use persisted (have stable IDs)
    memories:           insights.memories,
    preferencesUpdates: insights.preferencesUpdates,
    processedAt:        new Date().toISOString(),
  };

  store.update(sessionId, {
    status:   'ready',
    progress: 'Results ready.',
    results,
  });

  console.log(`[Pipeline] Session ${sessionId} ready`);
}

module.exports = router;
