//
//  CallSessionService.swift
//  lannaapp
//
//  Manages the SPEKT AI call pipeline from the iOS side:
//
//    1. initiateSession()   — POST /api/sessions/initiate before dialing
//    2. App goes to background (user is on call)
//    3. App returns to foreground → startPolling() begins
//    4. Polls GET /api/sessions/:id/status every 3s
//    5. On status == "ready", publishes results and stops polling
//
//  ProcessingView observes this service for UI state.
//  After the user dismisses results, applyResults() pushes data into
//  SignalViewModel (memories) and the Activity feed.
//

import SwiftUI
import Combine

// MARK: - Errors

enum CallSessionError: LocalizedError {
    case networkError(Error)
    case serverError(Int)
    case decodingError
    case noActiveSession

    var errorDescription: String? {
        switch self {
        case .networkError(let e): return e.localizedDescription
        case .serverError(let c):  return "Server error \(c)"
        case .decodingError:       return "Failed to decode server response"
        case .noActiveSession:     return "No active session"
        }
    }
}

// MARK: - Service

@MainActor
final class CallSessionService: ObservableObject {

    static let shared = CallSessionService()
    private init() {}

    // ── Published State ───────────────────────────────────────────────────

    @Published var currentSession : CallSessionStatusResponse? = nil
    @Published var showProcessing : Bool = false
    @Published var resultsApplied : Bool = false    // prevents double-apply
    @Published var backendError   : String? = nil   // surfaced for debug UI

    // Persisted so polling survives a brief app kill/restart
    @AppStorage("spekt_pending_session_id")
    var pendingSessionId: String = ""

    // Prevents the same completed call from surfacing twice
    @AppStorage("spekt_last_shown_call_id")
    private var lastShownCallId: String = ""

    // ── Config ────────────────────────────────────────────────────────────

    private let baseURL = SpektConfig.apiBase

    private let pollInterval: TimeInterval = 3.0
    private let maxPollDuration: TimeInterval = 10 * 60  // 10 min

    // ── Private ───────────────────────────────────────────────────────────

    private var pollingTask   : Task<Void, Never>? = nil
    private var pollingStarted: Date? = nil

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy  = .convertFromSnakeCase
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: - Public API

    /// Step 1: Called by CallManager before dialing.
    /// Creates a backend session and stores the sessionId.
    func initiateSession(userId: String = "anonymous") async throws {
        struct Body: Encodable { let userId: String }
        let response: InitiateSessionResponse = try await post(
            path: "/sessions/initiate",
            body: Body(userId: userId)
        )
        pendingSessionId = response.sessionId
        currentSession   = nil
        resultsApplied   = false
        print("[CallSession] Session initiated: \(response.sessionId)")
    }

    /// Step 2: Called when app returns to foreground.
    /// If a session was initiated from the app, polls that session.
    /// If no session ID (user called the number directly), fetches the latest
    /// completed call and shows results if it hasn't been seen before.
    func handleAppForeground() {
        if !pendingSessionId.isEmpty {
            showProcessing = true
            startPolling(sessionId: pendingSessionId)
        } else {
            Task { await checkForLatestCall() }
        }
    }

    /// Fetches GET /api/calls/latest and surfaces results if they're new.
    private func checkForLatestCall() async {
        guard let url = URL(string: "\(baseURL)/calls/latest") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            // 404 = no calls yet — not an error
            guard status == 200 else { return }
            let decoded = try decoder.decode(CallSessionStatusResponse.self, from: data)
            guard decoded.status == .ready,
                  decoded.results != nil,
                  decoded.sessionId != lastShownCallId else { return }
            currentSession = decoded
            showProcessing  = true
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            // Silently ignore — user is likely still on the call
        } catch let urlError as URLError where urlError.code == .timedOut {
            print("[CallSession] Backend timed out — will retry on next foreground")
        } catch let urlError as URLError where urlError.code == .cannotConnectToHost {
            print("[CallSession] Cannot reach backend — check SpektConfig.baseURL")
            backendError = "Cannot reach backend. Check your Railway URL."
        } catch {
            print("[CallSession] checkForLatestCall: \(error.localizedDescription)")
        }
    }

    /// Step 3: Manually start polling (called from handleAppForeground or after dial).
    func startPolling(sessionId: String) {
        pollingTask?.cancel()
        pollingStarted = Date()

        pollingTask = Task {
            while !Task.isCancelled {
                // Timeout guard
                if let start = pollingStarted,
                   Date().timeIntervalSince(start) > maxPollDuration {
                    currentSession = CallSessionStatusResponse(
                        sessionId: sessionId,
                        status: .failed,
                        progress: "Timed out waiting for results.",
                        results: nil,
                        error: "Polling timeout"
                    )
                    break
                }

                if let response = try? await fetchStatus(sessionId: sessionId) {
                    currentSession = response
                    if response.status.isTerminal {
                        print("[CallSession] Terminal status: \(response.status.rawValue)")
                        break
                    }
                }

                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }

    /// Step 4: Dismiss processing view, clear state.
    func dismiss() {
        if let id = currentSession?.sessionId { lastShownCallId = id }
        pollingTask?.cancel()
        pollingTask      = nil
        pollingStarted   = nil
        pendingSessionId = ""
        currentSession   = nil
        showProcessing   = false
        resultsApplied   = false
    }

    /// Step 5: Apply results to Signal + Activity screens.
    /// Safe to call multiple times — guards with resultsApplied.
    func applyResults(to signalVM: SignalViewModel) {
        guard !resultsApplied,
              let results = currentSession?.results else { return }
        resultsApplied = true

        // Push memories to SignalViewModel
        for extracted in results.memories {
            let memory = SpektMemory(
                id       : extracted.id,
                content  : extracted.content,
                timestamp: Date(),
                isPinned : false
            )
            withAnimation(SpektTheme.Motion.springDefault) {
                signalVM.memories.insert(memory, at: 0)
            }
        }

        // Import extracted tasks into TaskService
        Task { await TaskService.shared.importTasks(results.tasks, sessionId: currentSession!.sessionId) }

        // Apply preference updates to PreferencesStore
        let store = PreferencesStore.shared
        for update in results.preferencesUpdates {
            switch update.field {
            case "voice_tone":   store.voiceTone   = update.value
            case "style":        store.style        = update.value
            case "format":       store.format       = update.value
            case "language":     store.language     = update.value
            case "detail_level": store.detailLevel  = update.value
            default: break
            }
        }

        // Post notification for ActivityView to refresh
        NotificationCenter.default.post(
            name:   .spektNewCallResults,
            object: results
        )
    }

    // MARK: - Computed

    var progressFraction: Double {
        currentSession?.status.progressFraction ?? 0.05
    }

    var statusText: String {
        currentSession?.progress
            ?? currentSession?.status.displayText
            ?? "Waiting for call…"
    }

    var hasResults: Bool {
        currentSession?.status == .ready && currentSession?.results != nil
    }

    var hasFailed: Bool {
        currentSession?.status == .failed
    }

    // MARK: - Networking

    private func fetchStatus(sessionId: String) async throws -> CallSessionStatusResponse {
        guard let url = URL(string: "\(baseURL)/sessions/\(sessionId)/status") else {
            throw CallSessionError.networkError(URLError(.badURL))
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CallSessionError.serverError(http.statusCode)
        }
        guard let decoded = try? decoder.decode(CallSessionStatusResponse.self, from: data) else {
            throw CallSessionError.decodingError
        }
        return decoded
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw CallSessionError.networkError(URLError(.badURL))
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CallSessionError.serverError(http.statusCode)
        }
        guard let decoded = try? decoder.decode(ResponseBody.self, from: data) else {
            throw CallSessionError.decodingError
        }
        return decoded
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let spektNewCallResults = Notification.Name("spektNewCallResults")
}
