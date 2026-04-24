/**
 * services/memoryStore.js
 *
 * In-memory store for SPEKT memories.
 * Swap the Map for Postgres/Firestore in production — interface is identical.
 *
 * Memory shape:
 * {
 *   id:         string   (UUID)
 *   user_id:    string
 *   content:    string
 *   timestamp:  string   (ISO datetime)
 *   is_pinned:  boolean
 * }
 */

const { v4: uuidv4 } = require('uuid');

class MemoryStore {
  /** @type {Map<string, object>} */
  #memories = new Map();

  // ── Create ──────────────────────────────────────────────────────────────────

  create({ userId = 'anonymous', content, isPinned = false } = {}) {
    if (!content?.trim()) throw new Error('content is required');

    const memory = {
      id:        uuidv4(),
      user_id:   userId,
      content:   content.trim(),
      // Strip fractional seconds so Swift's .iso8601 date strategy can parse it
      timestamp: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
      is_pinned: isPinned,
    };
    this.#memories.set(memory.id, memory);
    return memory;
  }

  /**
   * Bulk-create memories extracted from a call.
   * Skips items with empty content.
   */
  createBatch(items, userId = 'anonymous') {
    return items
      .filter(item => item.content?.trim())
      .map(item =>
        this.create({ userId, content: item.content, isPinned: false })
      );
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  get(id) {
    return this.#memories.get(id) ?? null;
  }

  /**
   * List memories for a user, newest first.
   * @param {{ userId?: string, limit?: number }} opts
   */
  list({ userId = null, limit = 100 } = {}) {
    let results = Array.from(this.#memories.values());

    if (userId) results = results.filter(m => m.user_id === userId);

    // Pinned first, then newest first
    results.sort((a, b) => {
      if (a.is_pinned && !b.is_pinned) return -1;
      if (!a.is_pinned && b.is_pinned) return  1;
      return new Date(b.timestamp) - new Date(a.timestamp);
    });

    return results.slice(0, limit);
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  update(id, patch) {
    const memory = this.#memories.get(id);
    if (!memory) return null;

    if (patch.content   !== undefined) memory.content   = patch.content.trim();
    if (patch.is_pinned !== undefined) memory.is_pinned = Boolean(patch.is_pinned);

    return memory;
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  delete(id) {
    return this.#memories.delete(id);
  }

  deleteAll(userId = null) {
    if (!userId) {
      this.#memories.clear();
      return;
    }
    for (const [id, m] of this.#memories.entries()) {
      if (m.user_id === userId) this.#memories.delete(id);
    }
  }

  // ── Stats ───────────────────────────────────────────────────────────────────

  count(userId = null) {
    if (!userId) return this.#memories.size;
    return Array.from(this.#memories.values()).filter(m => m.user_id === userId).length;
  }
}

module.exports = new MemoryStore();
