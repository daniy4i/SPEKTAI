//
//  SpektAPI.swift
//  lannaapp
//
//  Lightweight async/await REST client for the SPEKT AI backend.
//  All endpoints fall back to mock data when the server is unreachable
//  so the app remains fully demonstrable before production is live.
//
//  To wire up a real server: set `baseURL` to the live endpoint.
//  The mock-fallback pattern means zero code changes elsewhere.
//

import Foundation

// MARK: - Errors

enum SpektAPIError: LocalizedError {
    case invalidURL
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "Invalid API URL."
        case .serverError(let code):  return "Server returned \(code)."
        case .decodingError(let e):   return "Decode error: \(e.localizedDescription)"
        case .networkError(let e):    return e.localizedDescription
        }
    }
}

// MARK: - Client

/// Singleton. All methods are `async throws` and return strongly-typed models.
/// When `useMocks` is true (default) the network layer is bypassed entirely
/// and mock data is returned after a brief simulated latency.
final class SpektAPI {

    static let shared = SpektAPI()
    private init() {}

    private let baseURL  = SpektConfig.apiBase
    private let useMocks = SpektConfig.useMocks

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Generic Request (real network)

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw SpektAPIError.invalidURL
        }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw SpektAPIError.serverError(http.statusCode)
            }
            return try decoder.decode(T.self, from: data)
        } catch let e as SpektAPIError { throw e }
          catch let e as DecodingError  { throw SpektAPIError.decodingError(e) }
          catch let e                   { throw SpektAPIError.networkError(e) }
    }

    // Simulates server latency in mock mode so animations behave realistically
    private func mockDelay(_ seconds: Double = 0.4) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    // MARK: - Memories

    func fetchMemories() async throws -> [SpektMemory] {
        if useMocks {
            await mockDelay(0.5)
            return SpektMemory.mocks
        }
        let list: [SpektMemory] = try await request("GET", path: "/memories")
        return list
    }

    func addMemory(_ content: String) async throws -> SpektMemory {
        if useMocks {
            await mockDelay(0.3)
            return SpektMemory(
                id: UUID().uuidString,
                content: content,
                timestamp: Date(),
                isPinned: false
            )
        }
        let body = AddMemoryRequest(content: content)
        return try await request("POST", path: "/memories", body: body)
    }

    func deleteMemory(id: String) async throws {
        if useMocks { await mockDelay(0.25); return }
        let _: EmptyResponse = try await request("DELETE", path: "/memories/\(id)")
    }

    func pinMemory(id: String, pinned: Bool) async throws {
        if useMocks { await mockDelay(0.2); return }
        struct PinBody: Encodable { let isPinned: Bool; enum CodingKeys: String, CodingKey { case isPinned = "is_pinned" } }
        let _: EmptyResponse = try await request("PATCH", path: "/memories/\(id)", body: PinBody(isPinned: pinned))
    }

    func editMemory(id: String, content: String) async throws -> SpektMemory {
        if useMocks {
            await mockDelay(0.2)
            return SpektMemory(id: id, content: content, timestamp: Date(), isPinned: false)
        }
        struct Body: Encodable { let content: String }
        return try await request("PATCH", path: "/memories/\(id)", body: Body(content: content))
    }

    func deleteAllMemories() async throws {
        if useMocks { await mockDelay(0.6); return }
        let _: EmptyResponse = try await request("DELETE", path: "/memories")
    }

    // MARK: - Patterns

    func fetchPatterns() async throws -> UsagePattern {
        if useMocks {
            await mockDelay(0.6)
            return .mock
        }
        return try await request("GET", path: "/patterns")
    }

    // MARK: - Preferences

    func savePreferences(_ payload: PreferencesPayload) async throws {
        if useMocks { await mockDelay(0.4); return }
        let _: EmptyResponse = try await request("POST", path: "/preferences", body: payload)
    }
}

// Placeholder for void responses
private struct EmptyResponse: Decodable {}
