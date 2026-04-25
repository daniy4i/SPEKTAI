import Foundation

enum SpektConfig {
    static let baseURL        = "https://spektai-production.up.railway.app"
    static let useMocks       = false

    // Derived base — used by services that build paths dynamically
    static var apiBase        : String { "\(baseURL)/api" }

    // Named endpoints
    static var sessionsURL    : String { "\(apiBase)/sessions" }
    static var callsURL       : String { "\(apiBase)/calls" }
    static var tasksURL       : String { "\(apiBase)/tasks" }
    static var memoriesURL    : String { "\(apiBase)/memories" }
    static var patternsURL    : String { "\(apiBase)/patterns" }
    static var preferencesURL : String { "\(apiBase)/preferences" }
    static var healthURL      : String { "\(baseURL)/health" }
}
