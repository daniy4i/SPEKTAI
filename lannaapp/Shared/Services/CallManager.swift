//
//  CallManager.swift
//  lannaapp
//
//  Manages outbound phone calls to the SPEKT AI number.
//  Handles device capability checks, confirmation gating, and URL-scheme dispatch.
//

import SwiftUI

// MARK: - Constant
// Replace this with the real SPEKT AI phone number before shipping.
let SPEKT_PHONE_NUMBER = "+15550001234"

/// Formats a raw E.164 US number into "(XXX) XXX-XXXX".
func formattedPhoneNumber(_ raw: String = SPEKT_PHONE_NUMBER) -> String {
    let digits = raw.filter(\.isNumber)
    guard digits.count == 11, digits.hasPrefix("1") else { return raw }
    let d      = String(digits.dropFirst())
    let area   = String(d.prefix(3))
    let prefix = String(d.dropFirst(3).prefix(3))
    let line   = String(d.dropFirst(6).prefix(4))
    return "(\(area)) \(prefix)-\(line)"
}

// MARK: - Call Manager
/// Singleton that drives the full call flow:
///   callSpektAI() → optional confirmation gate → tel:// URL dispatch → fallback alert
@MainActor
final class CallManager: ObservableObject {

    static let shared = CallManager()
    private init() {}

    // MARK: Published State
    @Published var showingUnsupportedAlert = false
    @Published var showingConfirmation     = false

    // Persisted across launches
    @AppStorage("spekt_confirmBeforeCalling") var confirmBeforeCalling = false

    // Held between confirmation prompt and user accepting
    private var pendingNumber: String?

    // MARK: - Public API

    /// Initiates a call to the SPEKT AI number (or a custom override).
    /// Creates a backend session first, then respects the `confirmBeforeCalling` preference.
    func callSpektAI(number: String = SPEKT_PHONE_NUMBER) {
        guard canMakeCall else {
            showingUnsupportedAlert = true
            return
        }

        if confirmBeforeCalling {
            pendingNumber = number
            showingConfirmation = true
        } else {
            initiateAndDial(number)
        }
    }

    /// Called by `CallConfirmSheet` when the user taps "Call".
    func confirmCall() {
        guard let number = pendingNumber else { return }
        pendingNumber = nil
        initiateAndDial(number)
    }

    /// Creates a backend session (async) then dials.
    /// The session ID is stored by `CallSessionService`; it starts polling
    /// when the app returns to foreground after the call.
    private func initiateAndDial(_ number: String) {
        Task {
            // Best-effort — if session creation fails we still place the call
            try? await CallSessionService.shared.initiateSession()
            dial(number)
        }
    }

    /// Dismisses the confirmation sheet without calling.
    func cancelCall() {
        pendingNumber = nil
        showingConfirmation = false
    }

    // MARK: - Device Capability

    /// `true` on real iPhones. `false` on iPad, iPod Touch, and Simulator.
    var canMakeCall: Bool {
        URL(string: "tel://")
            .map { UIApplication.shared.canOpenURL($0) }
            ?? false
    }

    // MARK: - Private

    private func dial(_ number: String) {
        // Keep only digits — tel:// rejects spaces, dashes, parens
        let digits = number.filter(\.isNumber)
        guard
            !digits.isEmpty,
            let url = URL(string: "tel://\(digits)"),
            UIApplication.shared.canOpenURL(url)
        else {
            showingUnsupportedAlert = true
            return
        }
        UIApplication.shared.open(url)
    }
}

// MARK: - Call Confirm Sheet
/// Minimal confirmation bottom sheet — shown when `confirmBeforeCalling` is on.
struct CallConfirmSheet: View {
    @ObservedObject private var manager = CallManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            VStack(spacing: 0) {

                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)

                Spacer().frame(height: 36)

                // Phone icon
                ZStack {
                    Circle()
                        .fill(SpektTheme.Colors.accent.opacity(0.10))
                        .frame(width: 76, height: 76)
                        .overlay(
                            Circle().strokeBorder(SpektTheme.Colors.accent.opacity(0.18), lineWidth: 0.5)
                        )
                    Image(systemName: "phone.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(SpektTheme.Colors.accent)
                }
                .scaleEffect(appeared ? 1 : 0.80)

                Spacer().frame(height: 24)

                Text("Call your AI?")
                    .font(SpektTheme.Typography.titleLarge)
                    .foregroundColor(SpektTheme.Colors.textPrimary)

                Spacer().frame(height: 8)

                Text(SPEKT_PHONE_NUMBER)
                    .font(SpektTheme.Typography.bodyMedium)
                    .tracking(1.0)
                    .foregroundColor(SpektTheme.Colors.textTertiary)

                Spacer().frame(height: 44)

                // Action buttons
                VStack(spacing: 10) {
                    Button {
                        dismiss()
                        // Small delay so dismiss animation completes before system call sheet appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            manager.confirmCall()
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 14, weight: .regular))
                            Text("Call")
                                .font(SpektTheme.Typography.titleSmall)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            Capsule()
                                .fill(SpektTheme.Colors.accent)
                                .overlay {
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors: [Color.white.opacity(0.16), Color.clear],
                                            startPoint: .top, endPoint: .center
                                        ))
                                }
                                .shadow(color: SpektTheme.Colors.accent.opacity(0.45), radius: 18, x: 0, y: 6)
                        }
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.97))

                    Button {
                        manager.cancelCall()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(SpektTheme.Typography.bodyMedium)
                            .foregroundColor(SpektTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.98))
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)

                Spacer()
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault.delay(0.05)) { appeared = true }
        }
    }
}

// MARK: - View Modifier
/// Attaches the call manager's alert and confirmation sheet to any view.
/// Apply once at the root (SpektMainView) to cover all tabs.
struct CallManagerModifier: ViewModifier {
    @ObservedObject private var manager = CallManager.shared

    func body(content: Content) -> some View {
        content
            // Unsupported device fallback
            .alert(
                "Calling unavailable",
                isPresented: $manager.showingUnsupportedAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Phone calls are not supported on this device.")
            }
            // Confirmation sheet
            .sheet(isPresented: $manager.showingConfirmation) {
                CallConfirmSheet()
                    .presentationDetents([.height(380)])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(SpektTheme.Colors.base)
                    .presentationCornerRadius(SpektTheme.Radius.xl)
            }
    }
}

extension View {
    /// Attaches call manager alerts and sheets. Call once on the root view.
    func withCallManager() -> some View {
        modifier(CallManagerModifier())
    }
}
