/**
 * routes/twilio.js
 *
 * Twilio webhook receiver — two endpoints:
 *
 *   POST /twilio/voice
 *     Fires when +1 (910) 773-5824 receives a call.
 *     Returns TwiML that simply records the call.
 *     The AI conversation happens externally; this just captures the audio.
 *
 *   POST /twilio/recording-complete
 *     Fires once the recording is finalised (a few seconds after hangup).
 *     Downloads the audio, transcribes with Whisper, extracts tasks/memories
 *     with GPT-4o, and stores everything so the iOS app can fetch it.
 *
 * NO in-server AI conversation. NO WebSocket. NO Realtime API.
 * The AI at (910) 773-5824 handles the live call. We process the recording.
 */

const { Router } = require('express');
const OpenAI     = require('openai');

const store       = require('../services/sessionStore');
const taskStore   = require('../services/taskStore');
const memoryStore = require('../services/memoryStore');
const validateTwilio              = require('../middleware/twilioValidation');
const { transcribeRecording }     = require('../services/transcription');
const { extractInsights }         = require('../services/intelligence');

const router = Router();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// ── POST /twilio/voice ────────────────────────────────────────────────────────
//
// Twilio POSTs here when a call arrives. We link it to the most recent pending
// session (created by the iOS app just before the user dialed) and return TwiML
// that records the conversation silently in the background.

router.post('/voice', validateTwilio, (req, res) => {
  const { From: callerPhone, CallSid } = req.body;

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
    console.warn(`[Twilio] No pending session for call ${CallSid} — creating one`);
    const newSession = store.create({ userId: callerPhone ?? 'unknown' });
    store.update(newSession.id, {
      callSid:     CallSid,
      callerPhone: callerPhone,
      status:      'in_call',
      progress:    'Call in progress…',
    });
  }

  const baseUrl = process.env.BASE_URL ?? '';

  // Record the full call. When it ends, Twilio POSTs to /twilio/recording-complete.
  const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Record
    action="${baseUrl}/twilio/recording-complete"
    recordingStatusCallback="${baseUrl}/twilio/recording-complete"
    maxLength="3600"
    timeout="10"
    transcribe="false"
    playBeep="false"
  />
</Response>`;

  res.type('text/xml').send(twiml);
});

// ── POST /twilio/recording-complete ──────────────────────────────────────────
//
// Twilio fires this once the recording is ready (usually a few seconds after
// the call ends). We respond 200 immediately (so Twilio doesn't retry) and
// kick off the async processing pipeline.
//
// Twilio sends: CallSid, RecordingUrl, RecordingDuration, RecordingSid, RecordingStatus

router.post('/recording-complete', validateTwilio, (req, res) => {
  res.sendStatus(200); // acknowledge immediately

  const { CallSid, RecordingUrl, RecordingStatus } = req.body;

  // Twilio fires this callback for in-progress AND completed statuses
  if (RecordingStatus && RecordingStatus !== 'completed') {
    console.log(`[Twilio] Recording status: ${RecordingStatus} — waiting for completed`);
    return;
  }

  if (!RecordingUrl) {
    console.error('[Twilio] recording-complete fired with no RecordingUrl');
    return;
  }

  const session = store.findByCallSid(CallSid) ?? store.findMostRecentPending();
  if (!session) {
    console.error(`[Pipeline] No session for CallSid ${CallSid} — dropping`);
    return;
  }

  console.log(`[Pipeline] Recording ready for session ${session.id}, starting pipeline`);

  runPipeline(session.id, RecordingUrl).catch((err) => {
    console.error(`[Pipeline] Fatal for session ${session.id}:`, err.message);
    store.update(session.id, {
      status:       'failed',
      progress:     'Something went wrong processing your call.',
      errorMessage: err.message,
    });
  });
});

// ── Pipeline ──────────────────────────────────────────────────────────────────

async function runPipeline(sessionId, recordingUrl) {
  const session = store.get(sessionId);
  const userId  = session?.userId ?? 'anonymous';

  // Stage 1: Transcription
  store.update(sessionId, {
    status:      'transcribing',
    progress:    'Transcribing conversation…',
    recordingUrl,
  });

  const transcript = await transcribeRecording(openai, recordingUrl);
  console.log(`[Pipeline] Transcribed ${transcript.length} chars`);

  if (!transcript.trim()) {
    store.update(sessionId, {
      status:       'failed',
      progress:     'No speech detected in recording.',
      errorMessage: 'Empty transcript',
    });
    return;
  }

  // Stage 2: GPT-4o extraction
  store.update(sessionId, {
    status:   'extracting',
    progress: 'Extracting insights…',
  });

  const insights = await extractInsights(openai, transcript);
  console.log(
    `[Pipeline] Extracted — ${insights.tasks.length} tasks, ` +
    `${insights.memories.length} memories, ${insights.key_outcomes.length} outcomes`
  );

  // Stage 3: Persist tasks and memories
  const persistedTasks = taskStore.createBatch(insights.tasks, sessionId);
  memoryStore.createBatch(insights.memories, userId);

  // Stage 4: Store results on session
  // Key names must match iOS CodingKeys exactly:
  //   key_outcomes        → case keyOutcomes        = "key_outcomes"
  //   preferences_updates → case preferencesUpdates = "preferences_updates"
  //   processedAt         → case processedAt         (literal camelCase)
  store.update(sessionId, {
    status:   'ready',
    progress: 'Results ready.',
    results:  {
      transcript,
      summary:             insights.summary,
      key_outcomes:        insights.key_outcomes,
      tasks:               persistedTasks,
      memories:            insights.memories,
      preferences_updates: insights.preferencesUpdates,
      processedAt:         new Date().toISOString(),
    },
  });

  console.log(`[Pipeline] Session ${sessionId} ready`);
}

module.exports = router;
