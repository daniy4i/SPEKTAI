//
//  SpektHomeView.swift
//  lannaapp
//
//  The home screen. The threshold between the user and intelligence.
//  Not a dashboard. Not a chat interface. A portal.
//

import SwiftUI

// MARK: - Scroll Offset Tracking
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Recent Outcome Model
struct RecentOutcome: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let timeAgo: String
}

extension RecentOutcome {
    static let samples: [RecentOutcome] = [
        .init(
            title: "Booked dinner in SoHo",
            detail: "Nobu · Sat 8PM · 2 guests",
            icon: "fork.knife",
            color: SpektTheme.Colors.positive,
            timeAgo: "2h ago"
        ),
        .init(
            title: "Planned your week",
            detail: "15 tasks · 3 focus blocks",
            icon: "calendar",
            color: SpektTheme.Colors.accent,
            timeAgo: "Yesterday"
        ),
        .init(
            title: "Found flights to Miami",
            detail: "AA 847 · Mar 22 · $189",
            icon: "airplane",
            color: SpektTheme.Colors.warning,
            timeAgo: "2d ago"
        ),
        .init(
            title: "Draft sent to design team",
            detail: "8 people · 2.3MB attached",
            icon: "paperplane",
            color: SpektTheme.Colors.accentSecondary,
            timeAgo: "3d ago"
        ),
    ]
}

// MARK: - Status Dot
/// Soft, looping pulse — communicates that the system is alive and listening.
private struct StatusDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            // Expanding ring — fades as it grows
            Circle()
                .fill(SpektTheme.Colors.positive.opacity(0.22))
                .frame(width: 16, height: 16)
                .scaleEffect(pulsing ? 1.9 : 1.0)
                .opacity(pulsing ? 0 : 1)

            // Core
            Circle()
                .fill(SpektTheme.Colors.positive)
                .frame(width: 7, height: 7)
                .shadow(color: SpektTheme.Colors.positive.opacity(0.6), radius: 4, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Breathing Waveform
/// Three-layer animated sine wave. Amplitude reacts to CTA interaction.
/// Uses TimelineView for frame-accurate GPU-driven animation.
struct BreathingWaveform: View {
    var amplitudeScale: CGFloat = 1.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
            WaveformCanvas(time: t, amplitudeScale: amplitudeScale)
        }
    }
}

private struct WaveformCanvas: View {
    let time: CGFloat
    let amplitudeScale: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let midY = size.height / 2
            let count = Int(size.width)

            // Three layers: primary, secondary, tertiary
            let layers: [(phaseShift: CGFloat, opacity: Double, width: CGFloat, ampMod: CGFloat)] = [
                (0.00, 0.52, 1.4, 1.00),
                (1.30, 0.26, 1.0, 0.72),
                (2.55, 0.13, 0.7, 0.46),
            ]

            for layer in layers {
                var path = Path()
                let amp = 8 * amplitudeScale * layer.ampMod

                for x in 0 ... count {
                    let relX  = CGFloat(x) / CGFloat(max(count, 1))
                    let angle = relX * .pi * 5.2 + time * 1.3 + layer.phaseShift
                    let y     = midY + amp * sin(angle)

                    x == 0
                        ? path.move(to: CGPoint(x: CGFloat(x), y: y))
                        : path.addLine(to: CGPoint(x: CGFloat(x), y: y))
                }

                ctx.stroke(
                    path,
                    with: .color(SpektTheme.Colors.accent.opacity(layer.opacity)),
                    style: StrokeStyle(lineWidth: layer.width, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .animation(SpektTheme.Motion.springDefault, value: amplitudeScale)
    }
}

// MARK: - Outcome Card
private struct OutcomeCard: View {
    let outcome: RecentOutcome
    let index: Int

    @State private var appeared = false

    var body: some View {
        GlassCard(intensity: .thin, cornerRadius: SpektTheme.Radius.md) {
            HStack(spacing: SpektTheme.Spacing.md) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(outcome.color.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: outcome.icon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(outcome.color)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(outcome.title)
                        .font(SpektTheme.Typography.bodyMedium)
                        .foregroundColor(SpektTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(outcome.detail)
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Meta
                VStack(alignment: .trailing, spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(SpektTheme.Colors.positive.opacity(0.65))
                    Text(outcome.timeAgo)
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, SpektTheme.Spacing.md)
            .padding(.vertical, 13)
        }
        .cardPress()
        // Staggered fade + slide
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(
                SpektTheme.Motion.springDefault
                    .delay(0.42 + Double(index) * 0.09)
            ) {
                appeared = true
            }
        }
    }
}

// MARK: - Ambient Light Layer
/// Reacts to CTA interaction — slightly shifts and intensifies on press.
private struct AmbientLight: View {
    var intensity: Double
    var yOffset: CGFloat

    var body: some View {
        RadialGradient(
            colors: [
                SpektTheme.Colors.accent.opacity(intensity),
                SpektTheme.Colors.accentSecondary.opacity(intensity * 0.4),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0.28 + yOffset / 600),
            startRadius: 0,
            endRadius: 340
        )
        .blur(radius: 28)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Home View
struct SpektHomeView: View {
    var onShowActivity: (() -> Void)? = nil

    // Scroll
    @State private var scrollOffset: CGFloat = 0

    // Waveform
    @State private var waveAmplitude: CGFloat = 1.0

    // Ambient background
    @State private var ambientIntensity: Double = 0.09
    @State private var ambientYOffset: CGFloat  = 0

    // Appear states
    @State private var headerAppeared  = false
    @State private var promptAppeared  = false
    @State private var waveAppeared    = false
    @State private var ctaAppeared     = false

    // Pre-call animation state
    @State private var ctaScale: CGFloat = 1.0

    // Debug overlay — long-press the "SPEKT" header to open
    @State private var showDebug = false

    // Live outcomes — populated from real call results
    @State private var recentOutcomes: [RecentOutcome] = []
    @State private var isCalling = false

    // ── Parallax: hero moves at ~72% of scroll speed
    private var heroParallax: CGFloat {
        guard scrollOffset < 0 else { return 0 }
        return -scrollOffset * 0.28
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1 — Base
            SpektTheme.Colors.base.ignoresSafeArea()

            // 2 — Ambient light (always behind everything)
            AmbientLight(intensity: ambientIntensity, yOffset: ambientYOffset)
                .animation(SpektTheme.Motion.springSmooth, value: ambientIntensity)
                .animation(SpektTheme.Motion.springSmooth, value: ambientYOffset)

            // 3 — Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Scroll tracking probe — zero height, reads its position
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("home")).minY
                        )
                    }
                    .frame(height: 0)

                    // ── HERO BLOCK (parallax)
                    VStack(spacing: 0) {
                        headerRow
                            .padding(.top, 64)

                        heroText
                            .padding(.top, 52)

                        waveformRow
                            .padding(.top, 28)

                        ctaButton
                            .padding(.top, 32)

                        Text(formattedPhoneNumber())
                            .font(.system(size: 13, weight: .light))
                            .tracking(1.8)
                            .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.60))
                            .padding(.top, 10)
                            .opacity(ctaAppeared ? 1 : 0)
                    }
                    .offset(y: heroParallax)
                    .padding(.bottom, 52)

                    // ── RECENT OUTCOMES (natural scroll)
                    recentSection
                        .padding(.bottom, 120) // tab bar + safe area clearance
                }
            }
            .coordinateSpace(name: "home")
            .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
        }
        .onAppear { staggerIn() }
        .sheet(isPresented: $showDebug) {
            DebugInfoView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .spektNewCallResults)) { notification in
            guard let results = notification.object as? CallSessionResults else { return }
            var newOutcomes: [RecentOutcome] = []

            // Prefer key outcomes; fall back to a summary card
            if !results.keyOutcomes.isEmpty {
                newOutcomes = results.keyOutcomes.prefix(2).map { outcome in
                    RecentOutcome(
                        title:   outcome,
                        detail:  String(results.summary.prefix(55)) + (results.summary.count > 55 ? "…" : ""),
                        icon:    "brain",
                        color:   SpektTheme.Colors.accent,
                        timeAgo: "just now"
                    )
                }
            } else {
                newOutcomes = [RecentOutcome(
                    title:   results.summary.prefix(70).description,
                    detail:  "\(results.tasks.count) tasks · \(results.memories.count) memories",
                    icon:    "phone.badge.waveform",
                    color:   SpektTheme.Colors.accentSecondary,
                    timeAgo: "just now"
                )]
            }

            withAnimation(SpektTheme.Motion.springDefault) {
                recentOutcomes.insert(contentsOf: newOutcomes, at: 0)
                recentOutcomes = Array(recentOutcomes.prefix(6))
                isCalling = false
            }
            #if os(iOS)
            HapticEngine.notify(.success)
            #endif
        }
    }

    // MARK: Header Row
    private var headerRow: some View {
        HStack(spacing: 7) {
            StatusDot()

            Text("SPEKT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.8)
                .foregroundColor(SpektTheme.Colors.textSecondary)
        }
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : -10)
        .onLongPressGesture(minimumDuration: 1.5) {
            #if os(iOS)
            HapticEngine.impact(.medium)
            #endif
            showDebug = true
        }
    }

    // MARK: Hero Text
    private var heroText: some View {
        VStack(spacing: 10) {
            Text("What do you")
                .font(.system(size: 44, weight: .light, design: .default))
                .foregroundColor(SpektTheme.Colors.textPrimary)

            Text("need?")
                .font(.system(size: 44, weight: .light, design: .default))
                // Slight accent tint on the question word — barely perceptible
                .foregroundStyle(
                    LinearGradient(
                        colors: [SpektTheme.Colors.textPrimary, SpektTheme.Colors.textPrimary.opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .multilineTextAlignment(.center)
        .opacity(promptAppeared ? 1 : 0)
        .offset(y: promptAppeared ? 0 : 18)
    }

    // MARK: Waveform Row
    private var waveformRow: some View {
        BreathingWaveform(amplitudeScale: waveAmplitude)
            .frame(height: 48)
            .padding(.horizontal, SpektTheme.Spacing.xxl + 8)
            .opacity(waveAppeared ? 1 : 0)
    }

    // MARK: CTA Button
    private var ctaButton: some View {
        Button {
            guard !isCalling else { return }
            handleCallAI()
        } label: {
            HStack(spacing: 10) {
                if isCalling {
                    ProgressView()
                        .scaleEffect(0.75)
                        .tint(.white)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 16, weight: .regular))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(isCalling ? "Connecting…" : "Call your AI")
                    .font(.system(size: 17, weight: .semibold))
                    .animation(SpektTheme.Motion.springDefault, value: isCalling)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
            .background {
                Capsule()
                    .fill(isCalling ? SpektTheme.Colors.accent.opacity(0.70) : SpektTheme.Colors.accent)
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .shadow(color: SpektTheme.Colors.accent.opacity(0.50), radius: 22, x: 0, y: 8)
                    .shadow(color: SpektTheme.Colors.accent.opacity(0.20), radius: 40, x: 0, y: 16)
            }
        }
        .disabled(isCalling)
        .buttonStyle(PressableButtonStyle(scale: isCalling ? 1.0 : 0.96))
        .scaleEffect(ctaScale)
        .opacity(ctaAppeared ? 1 : 0)
        .offset(y: ctaAppeared ? 0 : 10)
        .animation(SpektTheme.Motion.springDefault, value: isCalling)
    }

    // MARK: Recent Outcomes Section
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: SpektTheme.Spacing.md) {

            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text("RECENT OUTCOMES")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundColor(SpektTheme.Colors.textTertiary)

                Spacer()

                if !recentOutcomes.isEmpty {
                    Button {
                        #if os(iOS)
                        HapticEngine.selection()
                        #endif
                        onShowActivity?()
                    } label: {
                        Text("See all")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SpektTheme.Colors.accent)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.92))
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, SpektTheme.Spacing.xl)

            if recentOutcomes.isEmpty {
                // Empty state — first launch, no calls yet
                VStack(spacing: SpektTheme.Spacing.sm) {
                    Image(systemName: "phone.badge.waveform")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.50))
                    Text("Make your first call to see outcomes here.")
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.60))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpektTheme.Spacing.xxl)
                .padding(.horizontal, SpektTheme.Spacing.xl)
                .transition(.opacity)
            } else {
                // Live outcome cards
                VStack(spacing: SpektTheme.Spacing.sm) {
                    ForEach(Array(recentOutcomes.enumerated()), id: \.element.id) { i, outcome in
                        OutcomeCard(outcome: outcome, index: i)
                    }
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)
                .transition(.opacity)
            }
        }
        .animation(SpektTheme.Motion.springDefault, value: recentOutcomes.isEmpty)
    }

    // MARK: Appear Animation
    private func staggerIn() {
        withAnimation(SpektTheme.Motion.springDefault.delay(0.05))  { headerAppeared = true }
        withAnimation(SpektTheme.Motion.springSmooth.delay(0.12))   { promptAppeared = true }
        withAnimation(SpektTheme.Motion.springDefault.delay(0.24))  { waveAppeared   = true }
        withAnimation(SpektTheme.Motion.springBouncy.delay(0.30))   { ctaAppeared    = true }
    }

    // MARK: CTA Interaction
    private func handleCallAI() {
        #if os(iOS)
        HapticEngine.impact(.medium)
        #endif

        withAnimation(SpektTheme.Motion.springDefault) { isCalling = true }

        // 1 — Immediate visual burst: waveform + ambient light + CTA scale-in
        withAnimation(SpektTheme.Motion.interactiveSpring) { ctaScale = 0.93 }
        withAnimation(SpektTheme.Motion.springBouncy)      { waveAmplitude = 2.4 }
        withAnimation(SpektTheme.Motion.springDefault) {
            ambientIntensity = 0.26
            ambientYOffset   = -60
        }

        // 2 — Spring back (200 ms window — within 150–250 ms spec)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(SpektTheme.Motion.springBouncy) { ctaScale = 1.0 }
            withAnimation(SpektTheme.Motion.springSmooth) {
                waveAmplitude    = 1.0
                ambientIntensity = 0.09
                ambientYOffset   = 0
            }

            // 3 — Initiate call (confirmation gate handled inside CallManager)
            CallManager.shared.callSpektAI()

            // 4 — Reset calling state after a reasonable window
            //     (results notification will also reset it when outcomes arrive)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                withAnimation(SpektTheme.Motion.springDefault) { isCalling = false }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SpektHomeView()
        .preferredColorScheme(.dark)
}
