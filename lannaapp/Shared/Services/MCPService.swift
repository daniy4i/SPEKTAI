import Foundation

/// Lightweight JSON-RPC 2.0 client for the MCP Android control server.
class MCPService {
    static let shared = MCPService()

    private let serverURL = URL(string: "https://api.agi.tech/v1/mcp")!
    private let authToken = "bee0df85-057e-47ab-ba34-2de9281541cf"
    private let session = URLSession.shared

    private init() {}

    /// Calls an MCP tool by name with the given arguments and returns the result dict.
    func callTool(name: String, arguments: [String: Any] = [:]) async throws -> [String: Any] {
        let rpcBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: rpcBody)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw MCPError.serverError(statusCode: httpResponse.statusCode, message: body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.invalidResponse
        }

        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown MCP error"
            throw MCPError.rpcError(message: message)
        }

        return json["result"] as? [String: Any] ?? [:]
    }
}

enum MCPError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case rpcError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from MCP server"
        case let .serverError(statusCode, message):
            return "MCP server error (\(statusCode)): \(message)"
        case let .rpcError(message):
            return "MCP RPC error: \(message)"
        }
    }
}
