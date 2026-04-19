//
//  SmartGlassesEndpointDiscovery.swift
//  lannaapp
//
//  Network debugging tool to discover HeyCyan smart glasses HTTP endpoints
//

import Foundation
import os.log

/// Discovers and tests HTTP endpoints on the smart glasses web server
@MainActor
final class SmartGlassesEndpointDiscovery: ObservableObject {

    struct EndpointTestResult: Identifiable {
        let id = UUID()
        let url: String
        let method: String
        let statusCode: Int?
        let responseSize: Int?
        let contentType: String?
        let responsePreview: String?
        let success: Bool
        let error: String?
        let testDate: Date
    }

    @Published private(set) var isDiscovering = false
    @Published private(set) var results: [EndpointTestResult] = []
    @Published private(set) var discoveryProgress: String = ""
    @Published private(set) var workingEndpoints: [String] = []

    private let logger = Logger(subsystem: "com.lannaapp", category: "EndpointDiscovery")
    private let service = SmartGlassesService.shared

    // Comprehensive list of endpoints to test
    private let endpointsToTest = [
        // File listing endpoints
        "/files/list",
        "/files/media.config",
        "/files",
        "/media/list",
        "/media",
        "/list",
        "/api/files",
        "/api/media",
        "/api/list",

        // Photo endpoints
        "/photos",
        "/photos/list",
        "/files/photos",
        "/media/photos",
        "/images",
        "/pictures",

        // Video endpoints
        "/videos",
        "/videos/list",
        "/files/videos",
        "/media/videos",

        // Audio endpoints
        "/audio",
        "/audio/list",
        "/files/audio",
        "/media/audio",
        "/recordings",

        // Thumbnail endpoints
        "/thumbnails",
        "/thumbnails/list",
        "/files/thumbnails",
        "/thumb",
        "/preview",

        // Download endpoints
        "/download",
        "/files/download",
        "/media/download",

        // Info/config endpoints
        "/info",
        "/config",
        "/status",
        "/device",
        "/api/info",

        // Root
        "/",
        "/index.html",
        "/index.htm"
    ]

    // Common IP addresses to test
    private let ipAddressesToTest = [
        "192.168.31.1",   // Reported by SDK
        "192.168.1.1",    // Common router default
        "192.168.0.1",    // Common router default
        "192.168.43.1",   // Android hotspot
        "172.20.10.1",    // iOS hotspot
        "10.0.0.1"        // Alternative
    ]

    /// Discovers all working endpoints on the glasses
    func discoverEndpoints() async {
        isDiscovering = true
        results.removeAll()
        workingEndpoints.removeAll()

        logger.info("🔍 Starting endpoint discovery...")
        discoveryProgress = "Initializing discovery..."

        // First, determine which IP address works
        guard let workingIP = await findWorkingIPAddress() else {
            discoveryProgress = "❌ Could not find working IP address"
            isDiscovering = false
            return
        }

        logger.info("✅ Found working IP: \(workingIP)")
        discoveryProgress = "Testing endpoints on \(workingIP)..."

        // Test all endpoints
        let totalEndpoints = endpointsToTest.count
        for (index, endpoint) in endpointsToTest.enumerated() {
            discoveryProgress = "Testing \(index + 1)/\(totalEndpoints): \(endpoint)"

            let result = await testEndpoint(endpoint, ipAddress: workingIP, method: "GET")
            results.append(result)

            if result.success {
                workingEndpoints.append(result.url)
                logger.info("✅ Working endpoint: \(result.url)")
            }

            // Small delay to avoid overwhelming the device
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }

        // Test some endpoints with POST
        discoveryProgress = "Testing POST methods..."
        for endpoint in ["/files/list", "/media/list", "/api/files"] {
            let result = await testEndpoint(endpoint, ipAddress: workingIP, method: "POST")
            results.append(result)

            if result.success {
                workingEndpoints.append(result.url + " [POST]")
                logger.info("✅ Working POST endpoint: \(result.url)")
            }
        }

        // Try to discover file patterns
        await discoverFilePatterns(ipAddress: workingIP)

        discoveryProgress = "✅ Discovery complete! Found \(workingEndpoints.count) working endpoints"
        isDiscovering = false

        // Print summary
        logger.info("📊 Discovery Summary:")
        logger.info("Working endpoints: \(self.workingEndpoints.count)")
        for endpoint in self.workingEndpoints {
            logger.info("  - \(endpoint)")
        }
    }

    /// Quick test to find which IP address responds
    func findWorkingIPAddress() async -> String? {
        logger.info("🔍 Testing IP addresses...")

        // First try the IP from the service
        if let reportedIP = service.advancedStatus.wifiIPAddress {
            discoveryProgress = "Testing reported IP: \(reportedIP)"
            if await testIPAddress(reportedIP) {
                return reportedIP
            }
        }

        // Try all common IPs
        for ip in ipAddressesToTest {
            discoveryProgress = "Testing IP: \(ip)"
            logger.info("Testing IP: \(ip)")

            if await testIPAddress(ip) {
                logger.info("✅ Working IP found: \(ip)")
                return ip
            }

            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        return nil
    }

    /// Tests if an IP address responds
    private func testIPAddress(_ ip: String) async -> Bool {
        // Try multiple common endpoints
        let testEndpoints = ["/", "/files/media.config", "/files", "/info"]

        for endpoint in testEndpoints {
            guard let url = URL(string: "http://\(ip)\(endpoint)") else { continue }

            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 3.0

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode < 500 { // Any response (even 404) means server is there
                    return true
                }
            } catch {
                continue
            }
        }

        return false
    }

    /// Tests a specific endpoint
    private func testEndpoint(_ endpoint: String, ipAddress: String, method: String) async -> EndpointTestResult {
        guard let url = URL(string: "http://\(ipAddress)\(endpoint)") else {
            return EndpointTestResult(
                url: "http://\(ipAddress)\(endpoint)",
                method: method,
                statusCode: nil,
                responseSize: nil,
                contentType: nil,
                responsePreview: nil,
                success: false,
                error: "Invalid URL",
                testDate: Date()
            )
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.timeoutInterval = 5.0

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return EndpointTestResult(
                    url: url.absoluteString,
                    method: method,
                    statusCode: nil,
                    responseSize: nil,
                    contentType: nil,
                    responsePreview: nil,
                    success: false,
                    error: "Invalid response type",
                    testDate: Date()
                )
            }

            let success = (200..<300).contains(httpResponse.statusCode)
            let contentType = httpResponse.mimeType
            let responsePreview = createResponsePreview(data: data, contentType: contentType)

            return EndpointTestResult(
                url: url.absoluteString,
                method: method,
                statusCode: httpResponse.statusCode,
                responseSize: data.count,
                contentType: contentType,
                responsePreview: responsePreview,
                success: success,
                error: success ? nil : "HTTP \(httpResponse.statusCode)",
                testDate: Date()
            )

        } catch {
            return EndpointTestResult(
                url: url.absoluteString,
                method: method,
                statusCode: nil,
                responseSize: nil,
                contentType: nil,
                responsePreview: nil,
                success: false,
                error: error.localizedDescription,
                testDate: Date()
            )
        }
    }

    /// Discovers file naming patterns
    private func discoverFilePatterns(ipAddress: String) async {
        logger.info("🔍 Discovering file patterns...")
        discoveryProgress = "Discovering file naming patterns..."

        // Test common file naming patterns
        let patterns = [
            "/files/IMG_0001.jpg",
            "/files/PHOTO_0001.jpg",
            "/files/PIC_0001.jpg",
            "/files/DSC_0001.jpg",
            "/files/20250101_120000.jpg",
            "/files/photo0001.jpg",
            "/files/image001.jpg",
            "/media/IMG_0001.jpg",
            "/photos/0001.jpg",
            "/thumbnails/IMG_0001.jpg",
            "/thumbnails/0001.jpg",
            "/thumb/IMG_0001.jpg"
        ]

        for pattern in patterns {
            let result = await testEndpoint(pattern, ipAddress: ipAddress, method: "GET")
            results.append(result)

            if result.success {
                logger.info("✅ File pattern works: \(pattern)")
                workingEndpoints.append(pattern)
            }
        }

        // Test numbered access patterns
        for i in 0...5 {
            let patterns = [
                "/files/\(i)",
                "/files/\(i).jpg",
                "/media/\(i)",
                "/media/\(i).jpg",
                "/photos/\(i).jpg",
                "/thumbnails/\(i).jpg"
            ]

            for pattern in patterns {
                let result = await testEndpoint(pattern, ipAddress: ipAddress, method: "GET")
                results.append(result)

                if result.success {
                    logger.info("✅ Numbered pattern works: \(pattern)")
                    workingEndpoints.append(pattern)
                }
            }
        }
    }

    /// Creates a preview of the response data
    private func createResponsePreview(data: Data, contentType: String?) -> String {
        // If it's JSON, try to format it
        if let contentType = contentType, contentType.contains("json") {
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let string = String(data: prettyData, encoding: .utf8) {
                return String(string.prefix(500))
            }
        }

        // If it's text, show it
        if let string = String(data: data, encoding: .utf8) {
            return String(string.prefix(500))
        }

        // If it's binary, show hex preview
        let hexString = data.prefix(50).map { String(format: "%02x", $0) }.joined(separator: " ")
        return "Binary data: \(hexString)..."
    }

    /// Export results to a text file
    func exportResults() -> String {
        var output = "HeyCyan Smart Glasses - Endpoint Discovery Results\n"
        output += "Date: \(Date())\n"
        output += "=" + String(repeating: "=", count: 70) + "\n\n"

        output += "WORKING ENDPOINTS (\(workingEndpoints.count)):\n"
        output += "-" + String(repeating: "-", count: 70) + "\n"
        for endpoint in workingEndpoints {
            output += "✅ \(endpoint)\n"
        }
        output += "\n"

        output += "DETAILED RESULTS:\n"
        output += "-" + String(repeating: "-", count: 70) + "\n"

        for result in results.sorted(by: { $0.success && !$1.success }) {
            output += "\n[\(result.success ? "✅" : "❌")] \(result.method) \(result.url)\n"
            if let statusCode = result.statusCode {
                output += "    Status: \(statusCode)\n"
            }
            if let contentType = result.contentType {
                output += "    Content-Type: \(contentType)\n"
            }
            if let size = result.responseSize {
                output += "    Size: \(size) bytes\n"
            }
            if let error = result.error {
                output += "    Error: \(error)\n"
            }
            if let preview = result.responsePreview {
                output += "    Preview:\n\(preview.components(separatedBy: .newlines).map { "        \($0)" }.joined(separator: "\n"))\n"
            }
        }

        return output
    }

    /// Clear all results
    func clearResults() {
        results.removeAll()
        workingEndpoints.removeAll()
        discoveryProgress = ""
    }
}
