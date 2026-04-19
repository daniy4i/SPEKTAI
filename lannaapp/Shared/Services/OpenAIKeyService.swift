import Foundation

/// Service to securely fetch OpenAI API key from backend
final class OpenAIKeyService: ObservableObject {
    private enum Constants {
        static let keyEndpoint = "https://creative-agent-alqqs7uqwa-uc.a.run.app/openai-key"
    }

    private let session: URLSession
    private var cachedKey: String?
    private var keyExpiryDate: Date?

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches the OpenAI API key from the backend
    /// Uses cached key if available and not expired
    func getAPIKey(forUserId userId: String) async throws -> String {
        // Return cached key if still valid
        if let cachedKey = cachedKey,
           let expiryDate = keyExpiryDate,
           Date() < expiryDate {
            return cachedKey
        }

        guard let url = URL(string: Constants.keyEndpoint) else {
            throw OpenAIKeyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userId, forHTTPHeaderField: "x-user-uid")

        let body: [String: Any] = [
            "userId": userId,
            "purpose": "realtime-chat"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIKeyError.requestFailed(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiKey = json["apiKey"] as? String else {
            throw OpenAIKeyError.invalidResponse
        }

        // Cache the key for 30 minutes
        self.cachedKey = apiKey
        self.keyExpiryDate = Date().addingTimeInterval(30 * 60)

        return apiKey
    }

    /// Clears the cached API key
    func clearCache() {
        cachedKey = nil
        keyExpiryDate = nil
    }
}

enum OpenAIKeyError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .requestFailed(let statusCode):
            return "Failed to fetch API key (status: \(statusCode))"
        case .invalidResponse:
            return "Invalid response from backend"
        }
    }
}