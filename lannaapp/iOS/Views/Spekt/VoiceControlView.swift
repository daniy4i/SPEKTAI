//
//  VoiceControlView.swift
//  lannaapp
//
//  The moment before the call. A gateway, not an interface.
//  The orb communicates presence. Tapping it commits to connection.
//
//  States: idle (breathing, waiting) → activating (pulse burst) → call
//  No fake waveform, no simulated listening. Honest about what it does.
//

import SwiftUI

// MARK: - Orb State
/// Two honest states. This screen does one thing: initiate a call.
enum OrbState: Equatable {
    case idle        // Alive, waiting, breathing
    case activating  // Pulse burst — call is imminent
}

// MARK: - Orb Ripple Ring
/// One expanding ring. Scale from ~0.8× → 1.9×, opacity 0→peak→0.
/// Constructed externally so multiple rings can be staggered.
private struct RippleRing: View {
    let baseSize   : CGFloat
    let color      : Color
    let peakOpacity: Double
    let duration   : Double
    let delay      : Double

    @State private var scale:   CGFloat = 0.82
    @State private var opacity: Double  = 0

    var body: some View {
        Circle()
            .strokeBorder(color.opacity(opacity), lineWidth: 1.0)
            .frame(width: baseSize, height: baseSize)
            .scaleEffect(scale)
            .onAppear { fire() }
    }

    private func fire() {
        // Reset to start point without animation
        scale   = 0.82
        opacity = 0

        // Brief delay between rings
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Peak opacity fast, then fade as ring expands
            withAnimation(.easeIn(duration: 0.08)) { opacity = peakOpacity }
            withAnimation(.easeOut(duration: duration)) {
                scale   = 1.90
                opacity = 0
            }
        }
    }
}

// MARK: - Ripple Burst
/// Emits 3 staggered rings. Triggered by incrementing `trigger`.
private struct RippleBurst: View {
    let color  : Color
    let trigger: Int

    // Each render uses a unique ID so rings restart cleanly on re-trigger
    @State private var burstID = UUID()

    var body: some View {
        ZStack {
            RippleRing(baseSize: 168, color: color, peakOpacity: 0.55, duration: 0.82, delay: 0.00)
            RippleRing(baseSize: 168, color: color, peakOpacity: 0.38, duration: 0.90, delay: 0.09)
            RippleRing(baseSize: 168, color: color, peakOpacity: 0.22, duration: 1.00, delay: 0.18)
        }
        .id(burstID) // Force full re-init on each trigger
        .onChange(of: trigger) { _, _ in burstID = UUID() }
    }
}

// MARK: - Ambient Gradient Layer
/// Slow-rotating angular gradient behind the orb.
/// Almost imperceptible — adds warmth and motion without distraction.
private struct AmbientOrbGradient: View {
    @State private var angle: Double = 0

    var body: some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: [
                        SpektTheme.Colors.accent.opacity(0.06),
                        Color.clear,
                        SpektTheme.Colors.accentSecondary.opacity(0.09),
                        Color.clear,
                        SpektTheme.Colors.accent.opacity(0.05),
                        Color.clear,
                    ],
                    center: .center
                )
            )
            .frame(width: 280, height: 280)
            .rotationEffect(.degrees(angle))
            .blur(radius: 18)
            .onAppear {
                withAnimation(.linear(duration: 48).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

// MARK: - Voice Orb
/// The central interactive element. Everything else is support.
///
/// Layers (bottom → top):
///   1. AmbientOrbGradient  — very slow rotation, almost imperceptible
///   2. Glow circle         — breathing opacity + scale, bursts on activation
///   3. RippleBurst         — 3 rings expand outward on tap
///   4. Angular ring        — slow rotation, light-catching stroke
///   5. Glass disc          — ultraThinMaterial, breathing scale
///   6. Core sphere         — 3D-lit radial gradient
///   7. Mic icon            — crisp, centered
struct VoiceOrb: View {
    var state         : OrbState = .idle
    var rippleTrigger : Int      = 0  // Increment to fire ripple rings

    @State private var breathe    = false
    @State private var ringAngle  : Double  = 0
    @State private var glowScale  : CGFloat = 1.0
    @State private var glowOpacity: Double  = 0.10

    // Activation: core sphere briefly expands + brightens
    @State private var coreScale  : CGFloat = 1.0

    private var accentColor: Color {
        state == .activating
            ? SpektTheme.Colors.accentSecondary
            : SpektTheme.Colors.accent
    }

    var body: some View {
        ZStack {
            // 1 — Ambient gradient (barely visible, alive)
            AmbientOrbGradient()

            // 2 — Glow (breathing)
            Circle()
                .fill(accentColor.opacity(glowOpacity))
                .frame(width: 240, height: 240)
                .blur(radius: 38)
                .scaleEffect(glowScale)

            // 3 — Ripple rings (fire on tap)
            RippleBurst(color: accentColor, trigger: rippleTrigger)

            // 4 — Outer rotating ring
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.22),
                        ],
                        center: .center
                    ),
                    lineWidth: 0.7
                )
                .frame(width: 196, height: 196)
                .rotationEffect(.degrees(ringAngle))

            // 5 — Glass disc (breathing scale)
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(Color.white.opacity(0.07)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                .frame(width: 158, height: 158)
                .scaleEffect(breathe ? 1.014 : 0.988)

            // 6 — Core sphere (3D lit)
            coreLayer
                .scaleEffect(coreScale)

            // 7 — Icon
            Image(systemName: "mic")
                .font(.system(size: 28, weight: .ultraLight, design: .rounded))
                .foregroundColor(.white.opacity(0.90))
        }
        .animation(SpektTheme.Motion.springDefault, value: state)
        .onAppear { startLoops() }
        .onChange(of: state) { _, new in
            if new == .activating { runActivationBurst() }
        }
    }

    // MARK: - Core Sphere
    private var coreLayer: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.92),
                            accentColor.opacity(0.54),
                        ],
                        center: UnitPoint(x: 0.38, y: 0.33),
                        startRadius: 0,
                        endRadius: 52
                    )
                )
            // Specular highlight (upper-left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.30), .clear],
                        center: UnitPoint(x: 0.28, y: 0.26),
                        startRadius: 0,
                        endRadius: 28
                    )
                )
            // Depth shadow (lower-right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(0.24)],
                        center: UnitPoint(x: 0.65, y: 0.72),
                        startRadius: 14,
                        endRadius: 50
                    )
                )
            Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
        }
        .frame(width: 96, height: 96)
    }

    // MARK: - Continuous Animations
    private func startLoops() {
        // Breathing: glass disc + glow scale
        withAnimation(SpektTheme.Motion.breathe(4.2)) { breathe = true }

        // Glow opacity pulse (different period from scale for organic feel)
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            glowOpacity = 0.16
        }

        // Ring slow rotation
        withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
            ringAngle = 360
        }
    }

    // MARK: - Activation Burst
    /// Called when state → .activating. Glow surges, core pops, rings fire.
    private func runActivationBurst() {
        // Glow surge
        withAnimation(.easeOut(duration: 0.12)) {
            glowOpacity = 0.40
            glowScale   = 1.18
        }
        // Core pop
        withAnimation(SpektTheme.Motion.interactiveSpring) { coreScale = 1.10 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(SpektTheme.Motion.springSmooth) {
                glowOpacity = 0.13
                glowScale   = 1.0
                coreScale   = 1.0
            }
        }
    }
}

// MARK: - Voice Control View
struct VoiceControlView: View {

    @ObservedObject private var prefs       = PreferencesStore.shared
    @ObservedObject private var callSession = CallSessionService.shared
    @State private var orbState     : OrbState = .idle
    @State private var rippleTrigger: Int      = 0

    // Appear states
    @State private var headerVisible  = false
    @State private var orbVisible     = false
    @State private var labelVisible   = false

    // "Tap to speak" slow fade pulse
    @State private var labelPulse     = false

    // Page-level ambient (breathes behind orb on the base layer)
    @State private var pageAmbient    = false

    private var isCallActive: Bool {
        !callSession.pendingSessionId.isEmpty || callSession.showProcessing
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack {
            // ── Base ──────────────────────────────────────────────────────
            SpektTheme.Colors.base.ignoresSafeArea()

            // ── Page ambient (very low, breathes slowly) ─────────────────
            RadialGradient(
                colors: [
                    SpektTheme.Colors.accent.opacity(pageAmbient ? 0.07 : 0.04),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.40),
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Content ───────────────────────────────────────────────────
            VStack(spacing: 0) {

                headerSection
                    .padding(.top, SpektTheme.Spacing.xl + 8)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : -10)

                Spacer()

                orbSection

                Spacer()

                // Phone number — the destination, shown clearly
                Text(formattedPhoneNumber())
                    .font(.system(size: 20, weight: .light))
                    .tracking(3.0)
                    .foregroundColor(SpektTheme.Colors.textSecondary)
                    .opacity(labelVisible ? 1 : 0)
                    .offset(y: labelVisible ? 0 : 10)
                    .padding(.bottom, SpektTheme.Spacing.xxl + SpektTheme.Spacing.xl)
            }
        }
        .onAppear { animateIn() }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 5) {
            Text(dateString.uppercased())
                .font(SpektTheme.Typography.overline)
                .foregroundColor(SpektTheme.Colors.textTertiary)
                .tracking(1.8)
            Text(timeString)
                .font(.system(size: 17, weight: .light))
                .foregroundColor(SpektTheme.Colors.textSecondary)
        }
    }

    // MARK: - Orb Section
    private var orbSection: some View {
        VStack(spacing: 28) {

            // The orb
            Button { if !isCallActive { handleTap() } } label: {
                VoiceOrb(state: isCallActive ? .activating : orbState, rippleTrigger: rippleTrigger)
            }
            .buttonStyle(PressableButtonStyle(scale: isCallActive ? 1.0 : 0.97))
            .opacity(orbVisible ? 1 : 0)
            .scaleEffect(orbVisible ? 1 : 0.82)
            .animation(SpektTheme.Motion.springDefault, value: isCallActive)

            // Label + status
            VStack(spacing: 10) {
                Text(isCallActive ? "Processing your call…" : "Tap to speak")
                    .font(SpektTheme.Typography.bodyMedium)
                    .foregroundColor(
                        isCallActive
                            ? SpektTheme.Colors.accent
                            : SpektTheme.Colors.textSecondary.opacity(labelPulse ? 0.55 : 0.88)
                    )
                    .animation(SpektTheme.Motion.springDefault, value: isCallActive)
                    .animation(nil, value: labelPulse)

                // Status pill — always visible
                HStack(spacing: 6) {
                    Circle()
                        .fill(isCallActive ? SpektTheme.Colors.warning : SpektTheme.Colors.positive)
                        .frame(width: 6, height: 6)
                        .shadow(
                            color: (isCallActive ? SpektTheme.Colors.warning : SpektTheme.Colors.positive).opacity(0.6),
                            radius: 4
                        )
                    Text(isCallActive ? "SPEKT AI  •  In call" : "SPEKT AI  •  Active")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.8)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                        .animation(SpektTheme.Motion.springDefault, value: isCallActive)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                }

                // Active preference context — updates live when prefs change
                if !isCallActive {
                    Text(prefs.contextSummary)
                        .font(.system(size: 10, weight: .light))
                        .tracking(0.2)
                        .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.50))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .padding(.top, 2)
                        .animation(SpektTheme.Motion.springDefault, value: prefs.contextSummary)
                        .transition(.opacity)
                }
            }
            .opacity(labelVisible ? 1 : 0)
            .offset(y: labelVisible ? 0 : 8)
            .animation(SpektTheme.Motion.springDefault, value: isCallActive)
        }
    }

    // MARK: - Tap Handler
    private func handleTap() {
        #if os(iOS)
        HapticEngine.impact(.medium)
        #endif

        // 1 — Fire ripple rings immediately
        rippleTrigger += 1

        // 2 — Transition orb to activating state (burst)
        withAnimation(SpektTheme.Motion.interactiveSpring) {
            orbState = .activating
        }

        // 3 — Reset orb + initiate call after activation window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(SpektTheme.Motion.springSmooth) {
                orbState = .idle
            }
            CallManager.shared.callSpektAI()
        }
    }

    // MARK: - Appear Sequence
    private func animateIn() {
        withAnimation(SpektTheme.Motion.springSmooth.delay(0.04))  { headerVisible = true }
        withAnimation(SpektTheme.Motion.springBouncy.delay(0.14))  { orbVisible    = true }
        withAnimation(SpektTheme.Motion.springDefault.delay(0.26)) { labelVisible  = true }

        withAnimation(SpektTheme.Motion.breathe(4.5).delay(0.5)) { pageAmbient = true }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(1.0)) {
            labelPulse = true
        }
    }
}

// MARK: - Preview
#Preview {
    VoiceControlView()
        .preferredColorScheme(.dark)
}
