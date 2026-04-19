/**
 * intelligence.js
 *
 * Two-pass extraction pipeline:
 *
 *   Pass 1 — extractInsights(): full structured analysis
 *     Returns: summary, tasks[], memories[], preferencesUpdates[]
 *
 *   Pass 2 — refineTask(): AI refinement for ambiguous tasks
 *     Called on-demand when a task title is vague.
 *     Returns a cleaner, more actionable title + optional deadline.
 *
 * Uses response_format: json_object to guarantee parseable output.
 */

// ── Helpers ───────────────────────────────────────────────────────────────

/** Returns today's date as YYYY-MM-DD in local time */
function todayStr() {
  return new Date().toISOString().slice(0, 10);
}

/** Returns a date N days from today as YYYY-MM-DD */
function daysFromNow(n) {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return d.toISOString().slice(0, 10);
}

/** Returns the date of the next occurrence of weekday (0=Sun…6=Sat) */
function nextWeekday(weekday) {
  const d = new Date();
  const diff = (weekday - d.getDay() + 7) % 7 || 7;
  d.setDate(d.getDate() + diff);
  return d.toISOString().slice(0, 10);
}

// ── Main Extraction Prompt ────────────────────────────────────────────────

function buildSystemPrompt() {
  const today     = todayStr();
  const tomorrow  = daysFromNow(1);
  const thisFri   = nextWeekday(5);
  const nextMon   = nextWeekday(1);
  const endMonth  = (() => {
    const d = new Date();
    return new Date(d.getFullYear(), d.getMonth() + 1, 0).toISOString().slice(0, 10);
  })();

  return `You are an AI assistant that extracts structured intelligence from phone call transcripts.

Today is ${today}. Use this when inferring deadlines.

Return ONLY valid JSON with exactly this shape — no extra keys, no markdown:

{
  "summary": "2-3 sentence overview of what was discussed and decided",
  "key_outcomes": [
    "Concise statement of a key decision or fact from this call (1 sentence)"
  ],
  "tasks": [
    {
      "id": "t1",
      "title": "Imperative verb phrase, max 60 chars",
      "detail": "Brief context from the conversation (1 sentence max)",
      "deadline": "${tomorrow}" or null,
      "priority": "high | medium | low"
    }
  ],
  "memories": [
    {
      "id": "m1",
      "content": "Long-term fact to remember about this user"
    }
  ],
  "preferencesUpdates": [
    {
      "field": "voice_tone | style | format | language | detail_level",
      "value": "new value",
      "reason": "why this was inferred from the conversation"
    }
  ]
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
KEY OUTCOMES RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Capture 2–5 high-signal facts from the call:
  • Decisions made ("Agreed to push the launch to Q3")
  • Commitments received ("Alex will send the deck by Friday")
  • Important context ("Budget is capped at $15k")
  • Relationship updates ("Sarah is now leading the project")

NOT outcomes:
  • Tasks (those go in "tasks")
  • Filler conversation
  • Anything already captured in the summary verbatim

Format: declarative past tense. No bullet markers in the string. Max 100 chars each.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TASK EXTRACTION RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INCLUDE as tasks:
  • Direct commitments:  "I'll ...", "I need to ...", "remind me to ..."
  • Requests to the AI: "book ...", "schedule ...", "find ...", "send ..."
  • Implied follow-ups:  "let me get back to you", "I should check on ..."
  • Time-sensitive items explicitly mentioned

EXCLUDE from tasks:
  • Past actions already completed ("I already called Alex")
  • Pure opinions or discussion without actionable outcome
  • Hypotheticals with no commitment ("maybe we could someday...")

TITLE RULES:
  • Always start with an imperative verb: Book, Call, Send, Schedule, Buy,
    Follow up with, Review, Draft, Research, Cancel, Reply to, Confirm
  • Be specific: "Book dinner at Nobu" NOT "dinner"
  • If the speaker was vague, generate the most reasonable interpretation.
    Add "(inferred)" to the detail field so the user knows.
  • Strip filler words. Max 60 characters.

DEADLINE INFERENCE (map these phrases to absolute dates):
  • "today", "tonight"      → ${today}
  • "tomorrow"              → ${tomorrow}
  • "this week", "by Friday" → ${thisFri}
  • "next week", "Monday"   → ${nextMon}
  • "end of month"          → ${endMonth}
  • "ASAP", "urgent", "now" → ${tomorrow}
  • "no rush", "eventually" → null
  • No time mentioned       → null

PRIORITY:
  • high   — urgent language ("ASAP", "today", "urgent", "before the meeting"),
             high-stakes consequences, user's own deadline pressure
  • medium — clear timeline ("this week", "soon"), normal business items
  • low    — vague timing ("whenever", "someday"), nice-to-have

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MEMORY RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Only capture facts that are:
  • Stable over time (not just relevant to this one call)
  • About the user's identity, relationships, preferences, or recurring patterns
  • Not already obvious from context

Examples of GOOD memories:
  "Has a weekly team sync every Monday at 3 PM"
  "Prefers Zoom over phone calls for meetings"
  "Works with a designer named Alex"

Examples of BAD memories (too transient):
  "Booked dinner for Saturday" — that's a task, not a memory
  "Feeling tired today" — not stable

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PREFERENCES RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Only update if the conversation CLEARLY reveals a communication preference.
Allowed field values:
  voice_tone:   "Direct & concise" | "Warm & friendly" | "Professional" | "Casual"
  style:        "Action-first" | "Narrative" | "Structured" | "Conversational"
  format:       "Bullet points" | "Prose" | "Mixed" | "Brief"
  language:     "English (US)" | "English (UK)" | "Español" | "Français"
  detail_level: "High signal" | "Balanced" | "Comprehensive" | "Brief"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return empty arrays [] for sections with nothing to report.
`;
}

// ── Task Refinement Prompt (pass 2) ──────────────────────────────────────

const REFINE_SYSTEM = `You refine ambiguous task titles into clear, actionable ones.

Given a vague task title and optional context, return ONLY valid JSON:
{
  "title": "Refined imperative title, max 60 chars",
  "detail": "Brief clarification of what this task involves",
  "deadline": "YYYY-MM-DD or null",
  "priority": "high | medium | low"
}

Rules:
- Title MUST start with an imperative verb
- Make the task as specific as possible given the context
- If truly ambiguous, generate the most useful interpretation`;

// ── Exports ───────────────────────────────────────────────────────────────

/**
 * Full transcript analysis.
 * @param {import('openai').OpenAI} openai
 * @param {string} transcript
 */
async function extractInsights(openai, transcript) {
  const completion = await openai.chat.completions.create({
    model:           'gpt-4o',
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: buildSystemPrompt() },
      { role: 'user',   content: `Transcript:\n\n${transcript}` },
    ],
    temperature: 0.2,
    max_tokens:  2000,
  });

  const raw = completion.choices[0]?.message?.content ?? '{}';
  let parsed;
  try { parsed = JSON.parse(raw); }
  catch { throw new Error('GPT returned invalid JSON'); }

  return {
    summary:            parsed.summary            ?? 'No summary available.',
    key_outcomes:       Array.isArray(parsed.key_outcomes)       ? parsed.key_outcomes       : [],
    tasks:              Array.isArray(parsed.tasks)              ? parsed.tasks              : [],
    memories:           Array.isArray(parsed.memories)           ? parsed.memories           : [],
    preferencesUpdates: Array.isArray(parsed.preferencesUpdates) ? parsed.preferencesUpdates : [],
  };
}

/**
 * Refine a single vague task into a clear, actionable one.
 * @param {import('openai').OpenAI} openai
 * @param {string} vagueTitle
 * @param {string} [context]
 */
async function refineTask(openai, vagueTitle, context = '') {
  const completion = await openai.chat.completions.create({
    model:           'gpt-4o',
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: REFINE_SYSTEM },
      {
        role: 'user',
        content: `Task: "${vagueTitle}"\nContext: ${context || 'none provided'}`,
      },
    ],
    temperature: 0.3,
    max_tokens:  200,
  });

  const raw = completion.choices[0]?.message?.content ?? '{}';
  try { return JSON.parse(raw); }
  catch { return { title: vagueTitle, detail: null, deadline: null, priority: 'medium' }; }
}

module.exports = { extractInsights, refineTask };
