//
//  DebugInfoView.swift
//  lannaapp
//
//  Long-press the "SPEKT" header on the home screen to open.
//  Lets you verify the Railway URL and test each endpoint without leaving the app.
//

import SwiftUI

struct DebugInfoView: View {

    @State private var healthResult  : String? = nil
    @State private var latestResult  : String? = nil
    @State private var tasksResult   : String? = nil
    @State private var isLoadingHealth  = false
    @State private var isLoadingLatest  = false
    @State private var isLoadingTasks   = false

    var body: some View {
        NavigationStack {
            ZStack {
                SpektTheme.Colors.base.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── URL ──────────────────────────────────────────────
                        Group {
                            label("BACKEND URL")
                            Text(SpektConfig.baseURL)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(SpektTheme.Colors.textSecondary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }

                        GlassDivider(opacity: 0.10)

                        // ── Endpoints ────────────────────────────────────────
                        label("ENDPOINT TESTS")
                        Text("Results print to Xcode console. Tap to test.")
                            .font(SpektTheme.Typography.caption)
                            .foregroundColor(SpektTheme.Colors.textTertiary)

                        endpointRow(
                            title:    "GET /health",
                            url:      "\(SpektConfig.baseURL)/health",
                            result:   healthResult,
                            loading:  isLoadingHealth
                        ) {
                            await testEndpoint(
                                url:     "\(SpektConfig.baseURL)/health",
                                result:  &healthResult,
                                loading: &isLoadingHealth
                            )
                        }

                        endpointRow(
                            title:    "GET /api/calls/latest",
                            url:      "\(SpektConfig.callsURL)/latest",
                            result:   latestResult,
                            loading:  isLoadingLatest
                        ) {
                            await testEndpoint(
                                url:     "\(SpektConfig.callsURL)/latest",
                                result:  &latestResult,
                                loading: &isLoadingLatest
                            )
                        }

                        endpointRow(
                            title:    "GET /api/tasks",
                            url:      SpektConfig.tasksURL,
                            result:   tasksResult,
                            loading:  isLoadingTasks
                        ) {
                            await testEndpoint(
                                url:     SpektConfig.tasksURL,
                                result:  &tasksResult,
                                loading: &isLoadingTasks
                            )
                        }

                        GlassDivider(opacity: 0.10)

                        // ── Derived URLs ─────────────────────────────────────
                        label("DERIVED ENDPOINTS")
                        VStack(alignment: .leading, spacing: 6) {
                            urlLine("Sessions", SpektConfig.sessionsURL)
                            urlLine("Calls",    SpektConfig.callsURL)
                            urlLine("Tasks",    SpektConfig.tasksURL)
                            urlLine("Memories", SpektConfig.memoriesURL)
                            urlLine("Patterns", SpektConfig.patternsURL)
                            urlLine("Prefs",    SpektConfig.preferencesURL)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(SpektTheme.Spacing.xl)
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func endpointRow(
        title: String,
        url: String,
        result: String?,
        loading: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await action() }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(SpektTheme.Colors.accent)
                    Spacer()
                    if loading {
                        ProgressView().scaleEffect(0.7).tint(SpektTheme.Colors.accent)
                    } else {
                        Image(systemName: "play.circle")
                            .font(.system(size: 16))
                            .foregroundColor(SpektTheme.Colors.accent)
                    }
                }
                .padding(10)
                .background(SpektTheme.Colors.accent.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .disabled(loading)

            if let result {
                Text(result)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(result.hasPrefix("✅") ? SpektTheme.Colors.positive : SpektTheme.Colors.destructive)
                    .lineLimit(3)
                    .padding(.horizontal, 4)
            }
        }
    }

    @ViewBuilder
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(2.0)
            .foregroundColor(SpektTheme.Colors.textTertiary)
    }

    @ViewBuilder
    private func urlLine(_ name: String, _ url: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(name + ":")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(SpektTheme.Colors.textTertiary)
                .frame(width: 70, alignment: .leading)
            Text(url)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(SpektTheme.Colors.textSecondary)
        }
    }

    private func testEndpoint(
        url: String,
        result: inout String?,
        loading: inout Bool
    ) async {
        loading = true
        result  = nil
        defer { loading = false }
        guard let u = URL(string: url) else {
            result = "❌ Invalid URL"
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: u)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8)?.prefix(120) ?? "(empty)"
            result = "✅ \(code) — \(body)"
            print("[Debug] \(url) → \(code): \(body)")
        } catch {
            result = "❌ \(error.localizedDescription)"
            print("[Debug] \(url) error: \(error)")
        }
    }
}

#Preview {
    DebugInfoView()
}
