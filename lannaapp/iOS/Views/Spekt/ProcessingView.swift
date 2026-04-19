//
//  ProcessingView.swift
//  lannaapp
//
//  Full-screen post-call experience.
//
//  Phase 1 — Processing
//    Animated sine wave reacts to pipeline stage + stage dot indicators.
//
//  Phase 2 — Results
//    Editorial layout. Sections appear sequentially:
//      1. Summary  2. Key Outcomes  3. Tasks Created  4. SPEKT Learned + CTA
//

import SwiftUI

// MARK: - Conversation Wave

/// Three-layer animated sine wave. Amplitude scales with pipeline activity.
private struct ConversationWave: View {
    let color              : Color
    var amplitudeMultiplier: CGFloat = 1.0

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t    = CGFloat(tl.date.timeIntervalSinceReferenceDate)
                let midY = size.height / 2.0
                let freq = CGFloat.pi * 2.0 / size.width * 2.5

                func wave(phase: CGFloat, amp: CGFloat) -> Path {
                    var p = Path()
                    let y0 = midY + sin(phase) * amp * amplitudeMultiplier
                    p.move(to: CGPoint(x: 0, y: y0))
                    var x: CGFloat = 1.5
                    while x <= size.width {
                        let y = midY + sin(freq * x + t * 1.4 + phase) * amp * amplitudeMultiplier
                        p.addLine(to: CGPoint(x: x, y: y))
                        x += 1.5
                    }
                    return p
                }

                ctx.stroke(wave(phase: 0.0, amp: 18), with: .color(color.opacity(0.44)), lineWidth: 1.2)
                ctx.stroke(wave(phase: 1.2, amp: 11), with: .color(color.opacity(0.24)), lineWidth: 1.2)
                ctx.stroke(wave(phase: 2.5, amp:  7), with: .color(color.opacity(0.13)), lineWidth: 1.2)
            }
        }
        .frame(height: 72)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stage Dots

private struct StageDots: View {
    let currentStatus: CallSessionStatus?

    private var cur: Int {
        switch currentStatus {
        case .pending, .processing, nil: return 0
        case .inCall:                    return 1
        case .transcribing:              return 2
        case .extracting:                return 3
        case .ready, .failed:            return 4
        }
    }

    private let labels = ["Capture", "Transcribe", "Analyze", "Ready"]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                let ordinal = i + 1
                let done    = cur > ordinal
                let active  = cur == ordinal

                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(done   ? SpektTheme.Colors.positive :
                                  active ? SpektTheme.Colors.accent    :
                                           Color.white.opacity(0.12))
                            .frame(width: 8, height: 8)

                        if done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 4, weight: .black))
                                .foregroundColor(.black)
                        }
                    }
                    .animation(SpektTheme.Motion.springBouncy, value: cur)

                    Text(labels[i])
                        .font(.system(size: 9, weight: active ? .semibold : .regular))
                        .tracking(0.3)
                        .foregroundColor(
                            done   ? SpektTheme.Colors.positive :
                            active ? .white :
                                     Color.white.opacity(0.28)
                        )
                        .animation(SpektTheme.Motion.springDefault, value: cur)
                }
                .frame(maxWidth: .infinity)

                // Connector between stages — top-aligned to sit at dot center
                if i < 3 {
                    Rectangle()
                        .fill(cur > ordinal
                              ? SpektTheme.Colors.positive.opacity(0.40)
                              : Color.white.opacity(0.10))
                        .frame(width: 20, height: 0.5)
                        .padding(.top, 3.75)   // centers on the 8pt dot
                        .animation(SpektTheme.Motion.springDefault, value: cur)
                }
            }
        }
        .padding(.horizontal, SpektTheme.Spacing.xxl)
    }
}

// MARK: - Result Task Row

private struct ResultTaskRow: View {
    let task: ExtractedTask

    private var priorityColor: Color {
        switch task.priority {
        case "high":   return SpektTheme.Colors.destructive
        case "medium": return SpektTheme.Colors.warning
        default:       return SpektTheme.Colors.positive
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1)
                .fill(priorityColor)
                .frame(width: 2, height: 32)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(SpektTheme.Typography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(SpektTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = task.detail, !detail.isEmpty {
                    Text(detail)
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                }
            }

            Spacer(minLength: 0)

            if let due = task.dueDate {
                Text(due)
                    .font(SpektTheme.Typography.caption)
                    .foregroundColor(SpektTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Processing View

struct ProcessingView: View {
    @ObservedObject private var service = CallSessionService.shared

    /// Injected so results can be pushed into the Signal screen.
    var signalVM: SignalViewModel?

    @State private var appeared    = false
    @State private var showResults = false
    /// 0 = header only, 1 = summary, 2 = outcomes, 3 = tasks, 4 = learned + CTA
    @State private var revealStep  = 0

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            // Ambient glow
            RadialGradient(
                colors: [statusColor.opacity(0.12), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.32),
                startRadius: 0, endRadius: 380
            )
            .blur(radius: 36)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(SpektTheme.Motion.springSmooth, value: statusColor)

            if showResults {
                if let results = service.currentSession?.results {
                    resultsContent(results)
                        .transition(.opacity)
                }
            } else {
                processingPhase
                    .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault.delay(0.12)) { appeared = true }
            // Handle case where results were ready before view appeared
            if service.hasResults {
                showResults = true
                revealStep  = 4
            }
        }
        .onChange(of: service.currentSession?.status) { _, newStatus in
            guard let s = newStatus else { return }
            if s == .failed {
                #if os(iOS)
                HapticEngine.notify(.error)
                #endif
                return
            }
            guard s == .ready else { return }
            #if os(iOS)
            HapticEngine.impact(.medium)
            #endif
            withAnimation(SpektTheme.Motion.springDefault.delay(0.45)) {
                showResults = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {
                withAnimation(SpektTheme.Motion.springDefault) { revealStep = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                withAnimation(SpektTheme.Motion.springDefault) { revealStep = 2 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) {
                withAnimation(SpektTheme.Motion.springDefault) { revealStep = 3 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
                withAnimation(SpektTheme.Motion.springDefault) { revealStep = 4 }
            }
        }
    }

    // MARK: - Processing Phase

    private var processingPhase: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Text(service.hasFailed ? "Something went wrong." : "Analyzing your conversation.")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(SpektTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(SpektTheme.Motion.springDefault, value: service.statusText)

                Text(service.hasFailed
                     ? "The call was not processed."
                     : "Stay in the app while we work.")
                    .font(SpektTheme.Typography.bodySmall)
                    .foregroundColor(SpektTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(SpektTheme.Motion.springDefault, value: appeared)
            .padding(.horizontal, SpektTheme.Spacing.xxl)

            Spacer().frame(height: 44)

            ConversationWave(color: statusColor, amplitudeMultiplier: waveAmplitude)
                .opacity(service.hasFailed ? 0.25 : (appeared ? 1 : 0))
                .padding(.horizontal, SpektTheme.Spacing.md)
                .animation(SpektTheme.Motion.springSmooth, value: waveAmplitude)

            Spacer().frame(height: 40)

            StageDots(currentStatus: service.currentSession?.status)
                .opacity(appeared ? 0.88 : 0)
                .animation(SpektTheme.Motion.springDefault, value: appeared)

            Spacer()

            if service.hasFailed {
                VStack(spacing: 10) {
                    Button {
                        #if os(iOS)
                        HapticEngine.impact(.medium)
                        #endif
                        // Re-attempt polling with the same session ID
                        service.startPolling(sessionId: service.pendingSessionId)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .regular))
                            Text("Try again")
                                .font(SpektTheme.Typography.bodySmall)
                        }
                        .foregroundColor(SpektTheme.Colors.accent)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.94))

                    Button { service.dismiss() } label: {
                        Text("Dismiss")
                            .font(SpektTheme.Typography.bodySmall)
                            .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.50))
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.94))
                }
                .padding(.bottom, SpektTheme.Spacing.xxl)
                .opacity(appeared ? 1 : 0)
                .transition(.opacity)
            } else {
                Button { service.dismiss() } label: {
                    Text("Cancel")
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.55))
                }
                .buttonStyle(PressableButtonStyle(scale: 0.94))
                .padding(.bottom, SpektTheme.Spacing.xxl)
                .opacity(appeared ? 1 : 0)
                .transition(.opacity)
            }
        }
    }

    private var waveAmplitude: CGFloat {
        switch service.currentSession?.status {
        case .transcribing: return 1.30
        case .extracting:   return 1.60
        case .failed:       return 0.20
        default:            return 1.00
        }
    }

    // MARK: - Results Phase

    @ViewBuilder
    private func resultsContent(_ results: CallSessionResults) -> some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CALL PROCESSED")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.4)
                            .foregroundColor(SpektTheme.Colors.textTertiary)

                        Text("Here's what I captured.")
                            .font(.system(size: 26, weight: .light))
                            .foregroundColor(SpektTheme.Colors.textPrimary)
                    }
                    .padding(.top, 56)
                    .padding(.horizontal, SpektTheme.Spacing.xl)

                    // ── Summary ───────────────────────────────────────────
                    sectionDivider(visible: revealStep >= 1)

                    resultSection(label: "SUMMARY", visible: revealStep >= 1) {
                        Text(results.summary)
                            .font(SpektTheme.Typography.bodyMedium)
                            .foregroundColor(SpektTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }

                    // ── Key Outcomes ──────────────────────────────────────
                    if !results.keyOutcomes.isEmpty {
                        sectionDivider(visible: revealStep >= 2)

                        resultSection(label: "KEY OUTCOMES", visible: revealStep >= 2) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(results.keyOutcomes.enumerated()), id: \.offset) { _, outcome in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(SpektTheme.Colors.accent)
                                            .frame(width: 4, height: 4)
                                            .padding(.top, 6)
                                        Text(outcome)
                                            .font(SpektTheme.Typography.bodySmall)
                                            .foregroundColor(SpektTheme.Colors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    // ── Tasks Created ─────────────────────────────────────
                    if !results.tasks.isEmpty {
                        sectionDivider(visible: revealStep >= 3)

                        resultSection(
                            label: "TASKS CREATED  ·  \(results.tasks.count)",
                            visible: revealStep >= 3
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(results.tasks) { task in
                                    ResultTaskRow(task: task)
                                }
                            }
                        }
                    }

                    // ── SPEKT Learned ─────────────────────────────────────
                    let hasLearned = !results.memories.isEmpty || !results.preferencesUpdates.isEmpty
                    if hasLearned {
                        sectionDivider(visible: revealStep >= 4)

                        resultSection(label: "SPEKT LEARNED", visible: revealStep >= 4) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(results.memories) { mem in
                                    learnedRow(text: mem.content,
                                               dotColor: SpektTheme.Colors.positive)
                                }
                                ForEach(results.preferencesUpdates, id: \.field) { pref in
                                    learnedRow(
                                        text: "\(pref.field.replacingOccurrences(of: "_", with: " ").capitalized) → \(pref.value)",
                                        dotColor: SpektTheme.Colors.accentSecondary
                                    )
                                }
                            }
                        }
                    }

                    Spacer(minLength: 128)
                }
            }

            // ── CTA ───────────────────────────────────────────────────────
            ctaButtons
                .opacity(revealStep >= 4 ? 1 : 0)
                .offset(y: revealStep >= 4 ? 0 : 16)
                .animation(SpektTheme.Motion.springDefault, value: revealStep >= 4)
        }
    }

    // MARK: - Layout Helpers

    @ViewBuilder
    private func sectionDivider(visible: Bool) -> some View {
        GlassDivider(opacity: 0.09)
            .padding(.horizontal, SpektTheme.Spacing.xl)
            .padding(.vertical, SpektTheme.Spacing.lg)
            .opacity(visible ? 1 : 0)
            .animation(SpektTheme.Motion.springDefault, value: visible)
    }

    @ViewBuilder
    private func resultSection<C: View>(
        label: String,
        visible: Bool,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.0)
                .foregroundColor(SpektTheme.Colors.textTertiary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpektTheme.Spacing.xl)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 18)
        .animation(SpektTheme.Motion.springDefault, value: visible)
    }

    @ViewBuilder
    private func learnedRow(text: String, dotColor: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(SpektTheme.Typography.bodySmall)
                .foregroundColor(SpektTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ctaButtons: some View {
        VStack(spacing: 10) {
            Button {
                #if os(iOS)
                HapticEngine.impact(.medium)
                #endif
                if let vm = signalVM {
                    service.applyResults(to: vm)
                }
                service.dismiss()
            } label: {
                Text("Save to Signal & Activity")
                    .font(SpektTheme.Typography.titleSmall)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background {
                        Capsule()
                            .fill(SpektTheme.Colors.accent)
                            .shadow(color: SpektTheme.Colors.accent.opacity(0.40),
                                    radius: 16, x: 0, y: 6)
                    }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))

            Button { service.dismiss() } label: {
                Text("Dismiss")
                    .font(SpektTheme.Typography.bodySmall)
                    .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.70))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.98))
        }
        .padding(.horizontal, SpektTheme.Spacing.xl)
        .padding(.bottom, SpektTheme.Spacing.xl)
        .padding(.top, SpektTheme.Spacing.md)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    GlassDivider(opacity: 0.08)
                }
        }
    }

    // MARK: - Status Color

    private var statusColor: Color {
        switch service.currentSession?.status {
        case .pending, .inCall, .processing, nil: return SpektTheme.Colors.accent
        case .transcribing:                        return SpektTheme.Colors.accentSecondary
        case .extracting:                          return SpektTheme.Colors.warning
        case .ready:                               return SpektTheme.Colors.positive
        case .failed:                              return SpektTheme.Colors.destructive
        }
    }
}

// MARK: - Preview

#Preview {
    ProcessingView()
        .preferredColorScheme(.dark)
}
