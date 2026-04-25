/**
 * persistenceStore.js
 * Writes session/call data to a JSON file so it survives process restarts.
 * Falls back to in-memory only if filesystem is read-only (some cloud envs).
 */

const fs   = require('fs');
const path = require('path');

const DATA_DIR  = path.join(__dirname, '../data');
const DATA_FILE = path.join(DATA_DIR, 'sessions.json');

function ensureDir() {
    try {
        if (!fs.existsSync(DATA_DIR)) {
            fs.mkdirSync(DATA_DIR, { recursive: true });
        }
        return true;
    } catch {
        return false;
    }
}

function load() {
    try {
        if (!fs.existsSync(DATA_FILE)) return {};
        const raw = fs.readFileSync(DATA_FILE, 'utf8');
        return JSON.parse(raw);
    } catch {
        return {};
    }
}

function save(data) {
    try {
        if (!ensureDir()) return;
        fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
    } catch (err) {
        console.warn('[PersistenceStore] Could not write to disk:', err.message);
    }
}

module.exports = { load, save };
