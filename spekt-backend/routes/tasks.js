/**
 * routes/tasks.js
 *
 * REST API for task CRUD — consumed by the iOS app.
 *
 *   GET    /api/tasks               → list (supports ?status= and ?priority=)
 *   GET    /api/tasks/stats         → { total, pending, completed, overdue }
 *   POST   /api/tasks               → create single task
 *   POST   /api/tasks/batch         → create multiple tasks (from call extraction)
 *   PATCH  /api/tasks/:id           → update (title, detail, deadline, status, priority)
 *   DELETE /api/tasks/:id           → hard delete
 */

const { Router } = require('express');
const taskStore  = require('../services/taskStore');

const router = Router();

// ── GET /api/tasks ────────────────────────────────────────────────────────

router.get('/', (req, res) => {
  const { status, priority, limit } = req.query;
  const tasks = taskStore.list({
    status:   status   ?? undefined,
    priority: priority ?? undefined,
    limit:    limit    ? parseInt(limit, 10) : undefined,
  });
  res.json(tasks);
});

// ── GET /api/tasks/stats ──────────────────────────────────────────────────

router.get('/stats', (_req, res) => {
  res.json(taskStore.stats());
});

// ── POST /api/tasks ───────────────────────────────────────────────────────

router.post('/', (req, res) => {
  const { title, detail, deadline, priority, sourceSessionId } = req.body;

  if (!title?.trim()) {
    return res.status(400).json({ error: 'title is required' });
  }

  const task = taskStore.create({ title, detail, deadline, priority, sourceSessionId });
  res.status(201).json(task);
});

// ── POST /api/tasks/batch ─────────────────────────────────────────────────

router.post('/batch', (req, res) => {
  const { tasks, sourceSessionId } = req.body;

  if (!Array.isArray(tasks) || tasks.length === 0) {
    return res.status(400).json({ error: 'tasks array is required' });
  }

  const created = taskStore.createBatch(tasks, sourceSessionId);
  res.status(201).json(created);
});

// ── PATCH /api/tasks/:id ──────────────────────────────────────────────────

router.patch('/:id', (req, res) => {
  const task = taskStore.update(req.params.id, req.body);

  if (!task) {
    return res.status(404).json({ error: 'Task not found' });
  }

  res.json(task);
});

// ── DELETE /api/tasks/:id ─────────────────────────────────────────────────

router.delete('/:id', (req, res) => {
  const deleted = taskStore.delete(req.params.id);

  if (!deleted) {
    return res.status(404).json({ error: 'Task not found' });
  }

  res.status(204).send();
});

module.exports = router;
