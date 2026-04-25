/**
 * sessionStore.js
 *
 * In-memory session store with a simple API.
 * Sessions expire after 2 hours. Swap the Map for Postgres/Redis/Firestore
 * in production — the interface is identical.
 *
 * Session shape:
 * {
 *   id:              string        (UUID)
 *   userId:          string
 *   callerPhone:     string?       (set when Twilio webhook arrives)
 *   callSid:         string?       (Twilio CallSid)
 *   recordingUrl:    string?
 *   status:          SessionStatus
 *   progress:        string?       (human-readable progress line)
 *   createdAt:       Date
 *   results:         SessionResults?
 * }
 *
 * SessionStatus: 'pending' | 'in_call' | 'processing' | 'transcribing' |
 *                'extracting' | 'ready' | 'failed'
 */

const { v4: uuidv4 } = require('uuid');
const persistence = require('./persistenceStore');

const TTL_MS = 2 * 60 * 60 * 1000; // 2 hours

class SessionStore {
  /** @type {Map<string, object>} */
  #sessions = new Map();

  constructor() {
    // Load any persisted sessions from previous run
    const persisted = persistence.load();
    const stored = persisted.sessions ?? {};
    for (const [id, session] of Object.entries(stored)) {
      this.#sessions.set(id, session);
      this.#scheduleExpiry(id);
    }
    console.log(`[SessionStore] Loaded ${this.#sessions.size} persisted sessions`);
  }

  // ── Create ────────────────────────────────────────────────────────────────

  create({ userId }) {
    const session = {
      id:           uuidv4(),
      userId,
      callerPhone:  null,
      callSid:      null,
      recordingUrl: null,
      status:       'pending',
      progress:     'Waiting for call…',
      createdAt:    new Date(),
      results:      null,
    };
    this.#sessions.set(session.id, session);
    this.#scheduleExpiry(session.id);
    return session;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  get(id) {
    return this.#sessions.get(id) ?? null;
  }

  /** Finds the most recent 'pending' session, optionally matching userId. */
  findMostRecentPending(userId = null) {
    let best = null;
    for (const s of this.#sessions.values()) {
      if (s.status !== 'pending') continue;
      if (userId && s.userId !== userId) continue;
      if (!best || s.createdAt > best.createdAt) best = s;
    }
    return best;
  }

  findByCallSid(callSid) {
    for (const s of this.#sessions.values()) {
      if (s.callSid === callSid) return s;
    }
    return null;
  }

  // ── Update ────────────────────────────────────────────────────────────────

  update(id, patch) {
    const session = this.#sessions.get(id);
    if (!session) return null;
    Object.assign(session, patch);
    // Persist to disk after every update
    persistence.save({ sessions: Object.fromEntries(this.#sessions), updatedAt: new Date().toISOString() });
    return session;
  }

  // ── Housekeeping ──────────────────────────────────────────────────────────

  #scheduleExpiry(id) {
    setTimeout(() => this.#sessions.delete(id), TTL_MS);
  }

  /** Debug: list all active sessions */
  all() {
    return Array.from(this.#sessions.values());
  }
}

module.exports = new SessionStore();
