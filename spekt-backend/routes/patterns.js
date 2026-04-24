/**
 * routes/patterns.js
 *
 *   GET /api/patterns   → UsagePattern computed from the session store
 *
 * Returns real computed stats when sessions exist, otherwise a
 * baseline "new user" pattern so the iOS UI has something to render.
 */

const { Router } = require('express');
const store = require('../services/sessionStore');

const router = Router();

router.get('/', (_req, res) => {
  const sessions = store.all().filter(s => s.status === 'ready');

  if (sessions.length === 0) {
    return res.json(baselinePattern());
  }

  res.json(computePattern(sessions));
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function computePattern(sessions) {
  const now        = new Date();
  const weekStart  = new Date(now);
  weekStart.setDate(now.getDate() - now.getDay()); // Sunday of this week
  weekStart.setHours(0, 0, 0, 0);

  const thisWeek = sessions.filter(s => new Date(s.createdAt) >= weekStart);

  // Hourly activity: count sessions per hour-of-day across all sessions
  const hourCounts = Array(24).fill(0);
  for (const s of sessions) {
    const hour = new Date(s.createdAt).getHours();
    hourCounts[hour]++;
  }
  const maxCount = Math.max(...hourCounts, 1);
  const hourlyActivity = hourCounts.map(c => parseFloat((c / maxCount).toFixed(2)));

  // Average session length from sessions that have a transcript
  const durationsMin = sessions
    .filter(s => s.results?.transcript)
    .map(s => {
      // Rough estimate: 130 words per minute on average
      const words = (s.results.transcript.split(/\s+/).length);
      return words / 130;
    });
  const avgMin = durationsMin.length
    ? durationsMin.reduce((a, b) => a + b, 0) / durationsMin.length
    : 3.5;

  // Peak hours
  const morningPeak  = peakRangeLabel(hourlyActivity, 5, 12);
  const afternoonPeak = peakRangeLabel(hourlyActivity, 12, 20);

  // Categories from tasks
  const categoryCounts = {};
  let totalTasks = 0;
  for (const s of sessions) {
    for (const task of s.results?.tasks ?? []) {
      const cat = inferCategory(task.title);
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      totalTasks++;
    }
  }

  const categories = Object.entries(categoryCounts)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 5)
    .map(([name, count]) => ({
      name,
      count,
      fraction: parseFloat((count / Math.max(totalTasks, 1)).toFixed(2)),
    }));

  return {
    sessions_this_week:  thisWeek.length,
    avg_session_minutes: parseFloat(avgMin.toFixed(1)),
    peak_morning:        morningPeak,
    peak_afternoon:      afternoonPeak,
    hourly_activity:     hourlyActivity,
    categories:          categories.length ? categories : defaultCategories(),
  };
}

function peakRangeLabel(hourly, startHour, endHour) {
  let peakHour = startHour;
  let peakVal  = 0;
  for (let h = startHour; h < endHour; h++) {
    if (hourly[h] > peakVal) { peakVal = hourly[h]; peakHour = h; }
  }
  const endH = Math.min(peakHour + 2, 23);
  return `${formatHour(peakHour)}–${formatHour(endH)}`;
}

function formatHour(h) {
  if (h === 0)  return '12 AM';
  if (h === 12) return '12 PM';
  return h < 12 ? `${h} AM` : `${h - 12} PM`;
}

function inferCategory(title) {
  const t = title.toLowerCase();
  if (/book|reserv|restaurant|dinner|hotel/i.test(t))   return 'Booking';
  if (/schedule|meet|calendar|call|zoom/i.test(t))       return 'Scheduling';
  if (/fly|flight|travel|trip|airport/i.test(t))         return 'Travel';
  if (/email|send|message|draft|reply/i.test(t))         return 'Communication';
  if (/research|find|look up|search/i.test(t))           return 'Research';
  if (/buy|order|purchase|shop/i.test(t))                return 'Shopping';
  return 'Tasks';
}

function defaultCategories() {
  return [
    { name: 'Planning',   count: 0, fraction: 0 },
    { name: 'Scheduling', count: 0, fraction: 0 },
  ];
}

function baselinePattern() {
  return {
    sessions_this_week:  0,
    avg_session_minutes: 0,
    peak_morning:        '8–10 AM',
    peak_afternoon:      '2–4 PM',
    hourly_activity:     Array(24).fill(0),
    categories:          defaultCategories(),
  };
}

module.exports = router;
