//
//  SpektConfig.swift
//  lannaapp
//
//  Single source of truth for backend connectivity.
//  Change baseURL here — it propagates to every service automatically.
//

import Foundation

enum SpektConfig {

    // ── Backend URL ───────────────────────────────────────────────────────────
    //
    // Development:  use your ngrok URL, e.g. "https://abc123.ngrok.io"
    // Production:   paste your Railway URL here after first deploy.
    //               Railway dashboard → your service → Settings → Domains
    //
    // The /api prefix is appended below; do NOT include it here.
    static let baseURL = "https://your-backend.railway.app"

    // ── Mock fallback ─────────────────────────────────────────────────────────
    //
    // true  — network calls are bypassed; mock data returned immediately.
    //         Use during UI development before the backend is deployed.
    // false — all calls hit the real backend at baseURL.
    //
    static let useMocks = false

    // ── Derived base ──────────────────────────────────────────────────────────

    static var apiBase: String { "\(baseURL)/api" }

    // ── Named endpoints ───────────────────────────────────────────────────────

    static var sessionsURL    : String { "\(apiBase)/sessions" }
    static var callsURL       : String { "\(apiBase)/calls" }
    static var tasksURL       : String { "\(apiBase)/tasks" }
    static var memoriesURL    : String { "\(apiBase)/memories" }
    static var patternsURL    : String { "\(apiBase)/patterns" }
    static var preferencesURL : String { "\(apiBase)/preferences" }
}
