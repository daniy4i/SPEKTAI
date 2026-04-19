/**
 * taskStore.js
 *
 * Persistent task store (in-memory for now — swap Map for Postgres/Firestore).
 * Tasks are independent from call sessions; they outlive the session that created them.
 *
 * Task shape:
 * {
 *   id:              string        (UUID)
 *   title:           string
 *   detail:          string?
 *   deadline:        string?       (ISO date, date-only "YYYY-MM-DD")
 *   status:          'pending' | 'completed' | 'dismissed'
 *   priority:        'high' | 'medium' | 'low'
 *   sourceSessionId: string?
 *   createdAt:       string        (ISO datetime)
 *   completedAt:     string?       (ISO datetime)
 * }
 */

const { v4: uuidv4 } = require('uuid');

class TaskStore {
  /** @type {Map<string, object>} */
  #tasks = new Map();

  // ── Create ────────────────────────────────────────────────────────────────

  create(data) {
    const task = {
      id:              data.id ?? uuidv4(),
      title:           data.title,
      detail:          data.detail   ?? null,
      deadline:        data.deadline ?? null,
      status:          data.status   ?? 'pending',
      priority:        data.priority ?? 'medium',
      sourceSessionId: data.sourceSessionId ?? null,
      createdAt:       data.createdAt ?? new Date().toISOString(),
      completedAt:     null,
    };
    this.#tasks.set(task.id, task);
    return task;
  }

  /** Bulk create from call extraction results. Returns created tasks. */
  createBatch(items, sourceSessionId) {
    return items.map(item => this.create({ ...item, sourceSessionId }));
  }

  // ── Read ─────────────────────────────────────────────────────────────���────

  get(id) {
    return this.#tasks.get(id) ?? null;
  }

  /**
   * List tasks with optional filters.
   * @param {{ status?: string, priority?: string, limit?: number }} opts
   */
  list({ status, priority, limit } = {}) {
    let results = Array.from(this.#tasks.values());

    if (status)   results = results.filter(t => t.status   === status);
    if (priority) results = results.filter(t => t.priority === priority);

    // Sort: overdue first, then by deadline ASC, then by createdAt DESC
    results.sort((a, b) => {
      const aDeadline = a.deadline ? new Date(a.deadline) : null;
      const bDeadline = b.deadline ? new Date(b.deadline) : null;
      const now = new Date();

      const aOverdue = aDeadline && aDeadline < now && a.status === 'pending';
      const bOverdue = bDeadline && bDeadline < now && b.status === 'pending';

      if (aOverdue && !bOverdue) return -1;
      if (!aOverdue && bOverdue) return  1;
      if (aDeadline && bDeadline) return aDeadline - bDeadline;
      if (aDeadline && !bDeadline) return -1;
      if (!aDeadline && bDeadline) return  1;
      return new Date(b.createdAt) - new Date(a.createdAt);
    });

    if (limit) results = results.slice(0, limit);
    return results;
  }

  // ── Update ────────────────────────────────────────────────────────────────

  update(id, patch) {
    const task = this.#tasks.get(id);
    if (!task) return null;

    const allowedKeys = ['title', 'detail', 'deadline', 'status', 'priority'];
    for (const key of allowedKeys) {
      if (key in patch) task[key] = patch[key];
    }

    if (patch.status === 'completed' && !task.completedAt) {
      task.completedAt = new Date().toISOString();
    } else if (patch.status === 'pending') {
      task.completedAt = null;
    }

    return task;
  }

  // ── Delete ──────────────���────────────────────────────────────��────────────

  delete(id) {
    return this.#tasks.delete(id);
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  stats() {
    const all      = Array.from(this.#tasks.values());
    const pending  = all.filter(t => t.status === 'pending');
    const now      = new Date();
    return {
      total:     all.length,
      pending:   pending.length,
      completed: all.filter(t => t.status === 'completed').length,
      overdue:   pending.filter(t => t.deadline && new Date(t.deadline) < now).length,
    };
  }
}

module.exports = new TaskStore();
