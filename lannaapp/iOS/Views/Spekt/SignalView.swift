//
//  SignalView.swift
//  lannaapp
//
//  The Signal screen — not a settings page, not a profile.
//  A system observing the user. Intelligence shaped by habit and intent.
//
//  Architecture: MVVM. SignalViewModel owns all async ops.
//  Motion principles:
//    - Every data point earns its place by arriving with intention
//    - Cards have depth, not just glass
//    - The core is alive; touch confirms it
//

import SwiftUI

// MARK: - Section Model

enum SignalSection: Int, CaseIterable, Identifiable, Equatable {
    case preferences = 0
    case patterns    = 1
    case context     = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .preferences: return "Preferences"
        case .patterns:    return "Patterns"
        case .context:     return "Context Memory"
        }
    }

    var subtitle: String {
        switch self {
        case .preferences: return "How your AI speaks and thinks"
        case .patterns:    return "When and how you use SPEKT"
        case .context:     return "What your AI remembers"
        }
    }

    var icon: String {
        switch self {
        case .preferences: return "slider.horizontal.3"
        case .patterns:    return "chart.bar.xaxis.ascending"
        case .context:     return "brain.head.profile"
        }
    }

    var accentColor: Color {
        switch self {
        case .preferences: return SpektTheme.Colors.accent
        case .patterns:    return SpektTheme.Colors.accentSecondary
        case .context:     return SpektTheme.Colors.positive
        }
    }
}

// MARK: - Identity Core Canvas

private struct IdentityCoreCanvas: View {
    let time       : CGFloat
    let touchOffset: CGSize

    private let accent    = SpektTheme.Colors.accent
    private let secondary = SpektTheme.Colors.accentSecondary

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width  / 2 + touchOffset.width  * 0.04
            let cy = size.height / 2 + touchOffset.height * 0.04
            let c  = CGPoint(x: cx, y: cy)

            drawRing(&ctx, center: c, r: 100,
                     dots: 16, dotSz: 2.2,
                     rot: time * 6 * (.pi / 180),
                     ringAlpha: 0.07, dotAlpha: 0.28, color: .white)

            drawRing(&ctx, center: c, r: 76,
                     dots: 10, dotSz: 2.8,
                     rot: -time * 11 * (.pi / 180),
                     ringAlpha: 0.11, dotAlpha: 0.48, color: secondary)

            drawRing(&ctx, center: c, r: 54,
                     dots: 6, dotSz: 3.4,
                     rot: time * 20 * (.pi / 180),
                     ringAlpha: 0.16, dotAlpha: 0.70, color: accent)

            let coreR    = CGFloat(36)
            let coreRect = CGRect(x: cx - coreR, y: cy - coreR,
                                  width: coreR * 2, height: coreR * 2)

            ctx.fill(Path(ellipseIn: coreRect), with: .radialGradient(
                Gradient(stops: [
                    .init(color: accent.opacity(0.92),    location: 0.0),
                    .init(color: secondary.opacity(0.65), location: 0.55),
                    .init(color: accent.opacity(0.22),    location: 1.0),
                ]),
                center: CGPoint(x: cx - 9, y: cy - 11),
                startRadius: 0, endRadius: coreR
            ))

            ctx.fill(Path(ellipseIn: coreRect), with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.30), .clear]),
                center: CGPoint(x: cx - 15, y: cy - 17),
                startRadius: 0, endRadius: 18
            ))

            ctx.stroke(Path(ellipseIn: coreRect),
                       with: .color(Color.white.opacity(0.17)),
                       lineWidth: 0.5)
        }
    }

    private func drawRing(
        _ ctx: inout GraphicsContext,
        center: CGPoint, r: CGFloat, dots: Int, dotSz: CGFloat,
        rot: CGFloat, ringAlpha: Double, dotAlpha: Double, color: Color
    ) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.stroke(Path(ellipseIn: rect),
                   with: .color(Color.white.opacity(ringAlpha)),
                   style: StrokeStyle(lineWidth: 0.5))
        for i in 0 ..< dots {
            let angle = CGFloat(i) / CGFloat(dots) * .pi * 2 + rot - .pi / 2
            let pt    = CGPoint(x: center.x + cos(angle) * r,
                                y: center.y + sin(angle) * r)
            let dot   = CGRect(x: pt.x - dotSz / 2, y: pt.y - dotSz / 2,
                               width: dotSz, height: dotSz)
            ctx.fill(Path(ellipseIn: dot), with: .color(color.opacity(dotAlpha)))
        }
    }
}

// MARK: - Identity Core

struct IdentityCore: View {
    var isFocused: Bool = false

    @State private var breathe     = false
    @State private var pulseScale  : CGFloat = 1.0
    @State private var glowScale   : CGFloat = 1.0
    @State private var glowOpacity : Double  = 0.08
    @State private var touchOffset : CGSize  = .zero

    @GestureState private var isPressing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(SpektTheme.Colors.accent.opacity(glowOpacity))
                .frame(width: 178, height: 178)
                .blur(radius: 28)
                .scaleEffect(glowScale)
                .scaleEffect(breathe ? 1.06 : 0.96)

            TimelineView(.animation) { tl in
                let t = CGFloat(tl.date.timeIntervalSinceReferenceDate)
                IdentityCoreCanvas(time: t, touchOffset: touchOffset)
            }
            .frame(width: 210, height: 210)

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 15, weight: .ultraLight))
                .foregroundColor(.white.opacity(isPressing ? 0.55 : 0.82))
                .animation(SpektTheme.Motion.interactiveSpring, value: isPressing)
        }
        .scaleEffect(isPressing ? 0.96 : 1.0)
        .animation(SpektTheme.Motion.interactiveSpring, value: isPressing)
        .scaleEffect(pulseScale)
        .scaleEffect(breathe ? 1.018 : 0.984)
        .opacity(isFocused ? 0.52 : 1.0)
        .animation(SpektTheme.Motion.springDefault, value: isFocused)
        .onAppear {
            withAnimation(SpektTheme.Motion.breathe(4.6)) { breathe = true }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glowOpacity = 0.14
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressing) { _, state, _ in state = true }
        )
        .onTapGesture {
            #if os(iOS)
            HapticEngine.impact(.light)
            #endif
            withAnimation(.easeOut(duration: 0.12)) {
                glowOpacity = 0.36
                glowScale   = 1.20
            }
            withAnimation(SpektTheme.Motion.springBouncy) { pulseScale = 1.14 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(SpektTheme.Motion.springSmooth) {
                    glowOpacity = 0.10
                    glowScale   = 1.0
                    pulseScale  = 1.0
                }
            }
        }
    }
}

// MARK: - Pattern Stat Cell

private struct PatternStat: View {
    let value  : String
    let label  : String
    let color  : Color
    var delay  : Double = 0

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .light, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(SpektTheme.Typography.caption)
                .foregroundColor(SpektTheme.Colors.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpektTheme.Spacing.sm + 2)
        .background {
            RoundedRectangle(cornerRadius: SpektTheme.Radius.sm, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: SpektTheme.Radius.sm, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                }
        }
        .scaleEffect(appeared ? 1.0 : 0.72, anchor: .leading)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(SpektTheme.Motion.springBouncy.delay(delay)) {
                appeared = true
            }
        }
    }
}

// MARK: - Activity Strip

/// 24-segment hourly bar chart. Accepts live data from the ViewModel.
private struct ActivityStrip: View {
    var activity: [Double]

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let count = max(1, activity.count)
            let barW  = (geo.size.width - CGFloat(count - 1) * 2) / CGFloat(count)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0 ..< count, id: \.self) { i in
                    let intensity = activity[i]
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(SpektTheme.Colors.accentSecondary.opacity(0.25 + intensity * 0.65))
                        .frame(
                            width : barW,
                            height: appeared ? max(3, geo.size.height * intensity) : 0
                        )
                        .animation(
                            SpektTheme.Motion.springDefault.delay(Double(i) * 0.018),
                            value: appeared
                        )
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { appeared = true }
        }
    }
}

// MARK: - Memory Tag

private struct MemoryTagView: View {
    let topic : String
    let index : Int
    let color : Color

    @State private var appeared = false
    @State private var floating = false

    private var floatPeriod: Double { 2.8 + Double(index % 5) * 0.35 }
    private var floatPhase : Double { Double(index) * 0.28 }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(topic)
                .font(SpektTheme.Typography.caption)
                .foregroundColor(SpektTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        }
        .offset(y: floating ? -2.5 : 2.5)
        .scaleEffect(appeared ? 1.0 : 0.80)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(SpektTheme.Motion.springBouncy.delay(Double(index) * 0.055)) {
                appeared = true
            }
            withAnimation(SpektTheme.Motion.breathe(floatPeriod).delay(floatPhase)) {
                floating = true
            }
        }
    }
}

// MARK: - Preference Definition

private struct PreferenceDef: Identifiable {
    let id     : String
    let icon   : String
    let label  : String
    let options: [String]
}

private let allPrefs: [PreferenceDef] = [
    .init(id: "voice_tone",   icon: "mic.circle",      label: "Voice tone",   options: ["Direct & concise", "Warm & friendly", "Professional", "Casual"]),
    .init(id: "style",        icon: "arrow.up.circle", label: "Style",        options: ["Action-first", "Narrative", "Structured", "Conversational"]),
    .init(id: "format",       icon: "list.bullet",     label: "Format",       options: ["Bullet points", "Prose", "Mixed", "Brief"]),
    .init(id: "language",     icon: "globe",           label: "Language",     options: ["English (US)", "English (UK)", "Español", "Français"]),
    .init(id: "detail_level", icon: "dial.high",       label: "Detail level", options: ["High signal", "Balanced", "Comprehensive", "Brief"]),
]

// MARK: - Preferences Content View

private struct PreferencesContentView: View {
    let accentColor: Color
    @ObservedObject var vm: SignalViewModel

    @ObservedObject private var store = PreferencesStore.shared
    @State private var expandedID    : String? = nil
    @State private var recentSavedID : String? = nil

    var body: some View {
        VStack(spacing: 0) {

            // ── Live summary bar ─────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(accentColor.opacity(0.55))
                Text(store.contextSummary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(SpektTheme.Colors.textTertiary)
                    .lineLimit(1)
                    .animation(SpektTheme.Motion.springDefault, value: store.contextSummary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpektTheme.Spacing.md)
            .padding(.vertical, 9)

            GlassDivider(opacity: 0.06)

            // ── Preference rows ──────────────────────────────────────────
            ForEach(Array(allPrefs.enumerated()), id: \.element.id) { i, pref in
                prefRow(pref: pref, index: i)
                if i < allPrefs.count - 1 {
                    GlassDivider(opacity: 0.06)
                        .padding(.horizontal, SpektTheme.Spacing.md + 26)
                }
            }

            GlassDivider(opacity: 0.06)

            // ── Save to cloud ────────────────────────────────────────────
            saveButton

            // ── Reset (visible only when non-default) ────────────────────
            if !store.isDefault {
                GlassDivider(opacity: 0.06)
                resetButton
                    .transition(.cardBodyReveal)
            }
        }
        .padding(.vertical, SpektTheme.Spacing.xs)
        .animation(SpektTheme.Motion.springDefault, value: expandedID)
        .animation(SpektTheme.Motion.springDefault, value: store.isDefault)
        .animation(SpektTheme.Motion.springDefault, value: vm.prefsSaveState)
    }

    // MARK: Preference Row

    @ViewBuilder
    private func prefRow(pref: PreferenceDef, index: Int) -> some View {
        let isExpanded   = expandedID == pref.id
        let currentValue = value(for: pref)
        let justSaved    = recentSavedID == pref.id

        VStack(spacing: 0) {
            HStack(spacing: SpektTheme.Spacing.sm) {
                Image(systemName: pref.icon)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(accentColor.opacity(0.70))
                    .frame(width: 18)

                Text(pref.label)
                    .font(SpektTheme.Typography.bodySmall)
                    .foregroundColor(SpektTheme.Colors.textSecondary)

                Spacer()

                if justSaved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(accentColor)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    Text(currentValue)
                        .font(SpektTheme.Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(isExpanded ? accentColor : SpektTheme.Colors.textPrimary)
                        .transition(.opacity)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isExpanded ? accentColor.opacity(0.70) : SpektTheme.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(SpektTheme.Motion.springSnappy, value: isExpanded)
            }
            .padding(.horizontal, SpektTheme.Spacing.md)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .cardPress()
            .onTapGesture {
                #if os(iOS)
                HapticEngine.selection()
                #endif
                withAnimation(SpektTheme.Motion.springDefault) {
                    expandedID = isExpanded ? nil : pref.id
                }
            }
            .staggeredAppear(index: index, baseDelay: 0.045)

            if isExpanded {
                optionPicker(pref: pref, currentValue: currentValue)
                    .transition(.cardBodyReveal)
            }
        }
        .animation(SpektTheme.Motion.springSnappy, value: justSaved)
    }

    // MARK: Option Picker

    private func optionPicker(pref: PreferenceDef, currentValue: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpektTheme.Spacing.sm) {
                ForEach(pref.options, id: \.self) { option in
                    let isSelected = currentValue == option
                    Button {
                        #if os(iOS)
                        HapticEngine.impact(.light)
                        #endif
                        withAnimation(SpektTheme.Motion.springSnappy) {
                            setValue(option, for: pref)
                            expandedID = nil
                        }
                        withAnimation(SpektTheme.Motion.springSnappy) {
                            recentSavedID = pref.id
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                            withAnimation(SpektTheme.Motion.springSnappy) {
                                if recentSavedID == pref.id { recentSavedID = nil }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            Text(option)
                                .font(SpektTheme.Typography.caption)
                                .fontWeight(isSelected ? .semibold : .regular)
                        }
                        .foregroundColor(isSelected ? .white : SpektTheme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(isSelected ? accentColor : Color.white.opacity(0.07))
                                .overlay {
                                    Capsule().strokeBorder(
                                        isSelected ? accentColor.opacity(0.40) : Color.white.opacity(0.08),
                                        lineWidth: 0.5
                                    )
                                }
                        }
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.94))
                }
            }
            .padding(.horizontal, SpektTheme.Spacing.md)
            .padding(.bottom, SpektTheme.Spacing.sm + 2)
            .padding(.top, 4)
        }
    }

    // MARK: Save Button

    private var saveButton: some View {
        Button {
            #if os(iOS)
            HapticEngine.impact(.light)
            #endif
            Task { await vm.savePreferences() }
        } label: {
            HStack(spacing: 6) {
                switch vm.prefsSaveState {
                case .saving:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                        .scaleEffect(0.7)
                    Text("Saving…")
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(SpektTheme.Colors.positive)
                    Text("Saved to cloud")
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(SpektTheme.Colors.positive)
                case .failed:
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(SpektTheme.Colors.destructive)
                    Text("Save failed — tap to retry")
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(SpektTheme.Colors.destructive)
                default:
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(accentColor.opacity(0.70))
                    Text("Save to cloud")
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(accentColor.opacity(0.80))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
        .disabled(vm.prefsSaveState == .saving)
    }

    // MARK: Reset Button

    private var resetButton: some View {
        Button {
            #if os(iOS)
            HapticEngine.impact(.light)
            #endif
            withAnimation(SpektTheme.Motion.springDefault) {
                store.resetToDefaults()
                expandedID = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .medium))
                Text("Reset to defaults")
                    .font(SpektTheme.Typography.caption)
            }
            .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.65))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
    }

    // MARK: Store bridge

    private func value(for pref: PreferenceDef) -> String {
        switch pref.id {
        case "voice_tone":   return store.voiceTone
        case "style":        return store.style
        case "format":       return store.format
        case "language":     return store.language
        case "detail_level": return store.detailLevel
        default:             return pref.options.first ?? ""
        }
    }

    private func setValue(_ value: String, for pref: PreferenceDef) {
        switch pref.id {
        case "voice_tone":   store.voiceTone   = value
        case "style":        store.style        = value
        case "format":       store.format       = value
        case "language":     store.language     = value
        case "detail_level": store.detailLevel  = value
        default:             break
        }
    }
}

// MARK: - Memory Row

private struct MemoryRow: View {
    let memory     : SpektMemory
    let accentColor: Color
    let onDelete   : () -> Void
    let onPin      : () -> Void
    let onEdit     : () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: SpektTheme.Spacing.md) {

            // Pin / dot indicator
            VStack {
                Circle()
                    .fill(memory.isPinned ? accentColor : Color.white.opacity(0.18))
                    .frame(width: 6, height: 6)
                    .padding(.top, 5)
                Spacer()
            }
            .frame(width: 6)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.content)
                    .font(SpektTheme.Typography.bodySmall)
                    .foregroundColor(SpektTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(memory.timestamp, style: .relative)
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(SpektTheme.Colors.textTertiary)

                    if memory.isPinned {
                        HStack(spacing: 3) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                            Text("Pinned")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(accentColor.opacity(0.70))
                    }
                }
            }

            Spacer(minLength: 0)

            // Actions
            HStack(spacing: 12) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.55))
                }
                .buttonStyle(PressableButtonStyle(scale: 0.88))

                Button {
                    onPin()
                } label: {
                    Image(systemName: memory.isPinned ? "pin.slash" : "pin")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(memory.isPinned ? accentColor : SpektTheme.Colors.textTertiary.opacity(0.55))
                }
                .buttonStyle(PressableButtonStyle(scale: 0.88))

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(SpektTheme.Colors.destructive.opacity(0.65))
                }
                .buttonStyle(PressableButtonStyle(scale: 0.88))
            }
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.vertical, 10)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault) { appeared = true }
        }
    }
}

// MARK: - Memory List Content

private struct MemoryListContent: View {
    let accentColor: Color
    @ObservedObject var vm: SignalViewModel

    @State private var editingMemory: SpektMemory? = nil
    @State private var editText     : String       = ""

    var body: some View {
        VStack(spacing: 0) {

            // ── Memory count hero ────────────────────────────────────────
            MemoryCountHero(count: vm.memoriesCount, accentColor: accentColor)

            GlassDivider(opacity: 0.06)
                .padding(.horizontal, SpektTheme.Spacing.md)

            // ── State routing ────────────────────────────────────────────
            if case .failed(let msg) = vm.memoriesState, vm.memories.isEmpty {
                memoriesErrorState(message: msg)
            } else if vm.memoriesState == .loading && vm.memories.isEmpty {
                loadingPlaceholder
            } else if vm.memories.isEmpty {
                emptyState
            } else {
                memoryList
            }

            GlassDivider(opacity: 0.06)
                .padding(.horizontal, SpektTheme.Spacing.md)
                .padding(.top, 4)

            // ── Actions ──────────────────────────────────────────────────
            actionRow
        }
        .padding(.vertical, SpektTheme.Spacing.sm)
        .sheet(item: $editingMemory) { memory in
            EditMemorySheet(memory: memory, initialText: editText, accentColor: accentColor, vm: vm)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(SpektTheme.Colors.base)
                .presentationCornerRadius(SpektTheme.Radius.xl)
        }
    }

    private var loadingPlaceholder: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                .scaleEffect(0.8)
            Text("Loading memories…")
                .font(SpektTheme.Typography.bodySmall)
                .foregroundColor(SpektTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpektTheme.Spacing.xl)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.40))
            Text("No memories yet")
                .font(SpektTheme.Typography.bodySmall)
                .foregroundColor(SpektTheme.Colors.textTertiary)
            Text("Add context your AI should always remember.")
                .font(SpektTheme.Typography.caption)
                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.60))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpektTheme.Spacing.xl)
        .padding(.horizontal, SpektTheme.Spacing.md)
    }

    @ViewBuilder
    private func memoriesErrorState(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22, weight: .ultraLight))
                .foregroundColor(SpektTheme.Colors.destructive.opacity(0.70))
            Text("Couldn't load memories")
                .font(SpektTheme.Typography.bodySmall)
                .foregroundColor(SpektTheme.Colors.textSecondary)
            Text(message)
                .font(SpektTheme.Typography.caption)
                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.60))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Button {
                #if os(iOS)
                HapticEngine.impact(.light)
                #endif
                Task { await vm.retryMemories() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                    Text("Retry")
                        .font(SpektTheme.Typography.caption.weight(.medium))
                }
                .foregroundColor(accentColor)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.94))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpektTheme.Spacing.xl)
        .padding(.horizontal, SpektTheme.Spacing.md)
    }

    private var memoryList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.memories.enumerated()), id: \.element.id) { i, memory in
                MemoryRow(
                    memory     : memory,
                    accentColor: accentColor,
                    onDelete   : { vm.deleteMemory(memory) },
                    onPin      : { vm.togglePin(memory) },
                    onEdit     : {
                        editText     = memory.content
                        editingMemory = memory
                    }
                )
                if i < vm.memories.count - 1 {
                    GlassDivider(opacity: 0.05)
                        .padding(.horizontal, SpektTheme.Spacing.md + 18)
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: SpektTheme.Spacing.sm) {
            Button {
                #if os(iOS)
                HapticEngine.selection()
                #endif
                vm.showAddMemory = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Add Memory")
                        .font(SpektTheme.Typography.caption.weight(.medium))
                }
                .foregroundColor(accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    Capsule()
                        .fill(accentColor.opacity(0.10))
                        .overlay(Capsule().strokeBorder(accentColor.opacity(0.25), lineWidth: 0.5))
                }
            }
            .buttonStyle(PressableButtonStyle())

            Spacer()

            if !vm.memories.isEmpty {
                Button {
                    #if os(iOS)
                    HapticEngine.selection()
                    #endif
                    vm.showResetConfirm = true
                } label: {
                    Text("Reset Identity")
                        .font(SpektTheme.Typography.caption.weight(.medium))
                        .foregroundColor(SpektTheme.Colors.destructive.opacity(0.75))
                }
                .buttonStyle(PressableButtonStyle(scale: 0.94))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.top, 10)
        .padding(.bottom, SpektTheme.Spacing.sm)
    }
}

// MARK: - Memory Count Hero

private struct MemoryCountHero: View {
    let count      : Int
    let accentColor: Color

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(count)")
                .font(.system(size: 38, weight: .light, design: .rounded))
                .foregroundColor(SpektTheme.Colors.textPrimary)
                .scaleEffect(appeared ? 1.0 : 0.68, anchor: .leading)
                .opacity(appeared ? 1 : 0)
                .contentTransition(.numericText())
                .animation(SpektTheme.Motion.springBouncy, value: count)

            VStack(alignment: .leading, spacing: 2) {
                Text("memory nodes")
                    .font(SpektTheme.Typography.bodySmall)
                    .foregroundColor(SpektTheme.Colors.textSecondary)
                Text("AI context layer")
                    .font(SpektTheme.Typography.caption)
                    .foregroundColor(SpektTheme.Colors.textTertiary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)

            Spacer()
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.vertical, 10)
        .onAppear {
            withAnimation(SpektTheme.Motion.springBouncy.delay(0.06)) { appeared = true }
        }
    }
}

// MARK: - Patterns Content View

private struct PatternsContentView: View {
    let accentColor: Color
    @ObservedObject var vm: SignalViewModel

    var body: some View {
        let p = vm.effectivePatterns

        VStack(spacing: SpektTheme.Spacing.md) {

            if case .failed(let msg) = vm.patternsState {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 22, weight: .ultraLight))
                        .foregroundColor(SpektTheme.Colors.destructive.opacity(0.70))
                    Text("Couldn't load patterns")
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textSecondary)
                    Text(msg)
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.60))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Button {
                        #if os(iOS)
                        HapticEngine.impact(.light)
                        #endif
                        Task { await vm.retryPatterns() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                            Text("Retry")
                                .font(SpektTheme.Typography.caption.weight(.medium))
                        }
                        .foregroundColor(accentColor)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.94))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpektTheme.Spacing.xl)
            } else if vm.patternsState == .loading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                        .scaleEffect(0.8)
                    Text("Loading patterns…")
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpektTheme.Spacing.xl)
            } else {

                // Stat grid
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: SpektTheme.Spacing.sm
                ) {
                    PatternStat(
                        value: "\(p.sessionsThisWeek)",
                        label: "sessions this week",
                        color: accentColor, delay: 0.00
                    )
                    PatternStat(
                        value: String(format: "%.1f min", p.avgSessionMinutes),
                        label: "avg session length",
                        color: SpektTheme.Colors.accent, delay: 0.06
                    )
                    PatternStat(
                        value: p.peakMorning,
                        label: "peak morning window",
                        color: SpektTheme.Colors.warning, delay: 0.12
                    )
                    PatternStat(
                        value: p.peakAfternoon,
                        label: "peak afternoon",
                        color: SpektTheme.Colors.positive, delay: 0.18
                    )
                }
                .padding(.horizontal, SpektTheme.Spacing.md)

                // Hourly activity bar chart
                if p.hourlyActivity.count == 24 {
                    ActivityStrip(activity: p.hourlyActivity)
                        .frame(height: 28)
                        .padding(.horizontal, SpektTheme.Spacing.md)
                }

                // Category pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SpektTheme.Spacing.sm) {
                        ForEach(Array(p.categories.enumerated()), id: \.element.id) { i, cat in
                            HStack(spacing: 5) {
                                Text(cat.name)
                                    .font(SpektTheme.Typography.caption)
                                    .foregroundColor(SpektTheme.Colors.textSecondary)
                                Text("\(cat.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(accentColor)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                Capsule()
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))
                            }
                            .staggeredAppear(index: i, baseDelay: 0.05)
                        }
                    }
                    .padding(.horizontal, SpektTheme.Spacing.md)
                }
            }
        }
        .padding(.vertical, SpektTheme.Spacing.md)
    }
}

// MARK: - Add Memory Sheet

private struct AddMemorySheet: View {
    @ObservedObject var vm: SignalViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
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

                Spacer().frame(height: 28)

                // Icon
                ZStack {
                    Circle()
                        .fill(SpektTheme.Colors.positive.opacity(0.10))
                        .frame(width: 60, height: 60)
                        .overlay(Circle().strokeBorder(SpektTheme.Colors.positive.opacity(0.18), lineWidth: 0.5))
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(SpektTheme.Colors.positive)
                }
                .scaleEffect(appeared ? 1 : 0.80)

                Spacer().frame(height: 20)

                Text("Add Memory")
                    .font(SpektTheme.Typography.titleLarge)
                    .foregroundColor(SpektTheme.Colors.textPrimary)

                Text("Your AI will remember this context in every conversation.")
                    .font(SpektTheme.Typography.bodySmall)
                    .foregroundColor(SpektTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpektTheme.Spacing.xxl)
                    .padding(.top, 6)

                Spacer().frame(height: 28)

                // Text input
                ZStack(alignment: .topLeading) {
                    if vm.addMemoryText.isEmpty {
                        Text("e.g. Prefers morning calls before 10 AM")
                            .font(SpektTheme.Typography.bodySmall)
                            .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.55))
                            .padding(.top, 10)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $vm.addMemoryText)
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(height: 88)
                        .padding(.horizontal, 10)
                        .focused($focused)
                }
                .background {
                    RoundedRectangle(cornerRadius: SpektTheme.Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: SpektTheme.Radius.md, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                        }
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)

                Spacer().frame(height: 24)

                // Actions
                VStack(spacing: 10) {
                    Button {
                        Task { await vm.submitAddMemory() }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isAddingMemory {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.75)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                            }
                            Text(vm.isAddingMemory ? "Saving…" : "Save Memory")
                                .font(SpektTheme.Typography.titleSmall)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background {
                            Capsule()
                                .fill(SpektTheme.Colors.positive)
                                .overlay {
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors: [Color.white.opacity(0.16), Color.clear],
                                            startPoint: .top, endPoint: .center
                                        ))
                                }
                                .shadow(color: SpektTheme.Colors.positive.opacity(0.40), radius: 16, x: 0, y: 5)
                        }
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.97))
                    .disabled(vm.addMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isAddingMemory)
                    .opacity(vm.addMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1.0)

                    Button {
                        vm.addMemoryText = ""
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(SpektTheme.Typography.bodyMedium)
                            .foregroundColor(SpektTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }
}

// MARK: - Edit Memory Sheet

private struct EditMemorySheet: View {
    let memory     : SpektMemory
    let initialText: String
    let accentColor: Color
    @ObservedObject var vm: SignalViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var text    = ""
    @State private var saving  = false
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)

                Spacer().frame(height: 24)

                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.10))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().strokeBorder(accentColor.opacity(0.18), lineWidth: 0.5))
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(accentColor)
                }
                .scaleEffect(appeared ? 1 : 0.80)

                Spacer().frame(height: 18)

                Text("Edit Memory")
                    .font(SpektTheme.Typography.titleLarge)
                    .foregroundColor(SpektTheme.Colors.textPrimary)

                Spacer().frame(height: 22)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Memory content…")
                            .font(SpektTheme.Typography.bodySmall)
                            .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.50))
                            .padding(.top, 10)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(height: 80)
                        .padding(.horizontal, 10)
                        .focused($focused)
                }
                .background {
                    RoundedRectangle(cornerRadius: SpektTheme.Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: SpektTheme.Radius.md, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                        }
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)

                Spacer().frame(height: 22)

                VStack(spacing: 10) {
                    Button {
                        guard !saving else { return }
                        saving = true
                        Task {
                            await vm.editMemory(memory, newContent: text)
                            saving = false
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if saving {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.75)
                            } else {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
                            }
                            Text(saving ? "Saving…" : "Save Changes")
                                .font(SpektTheme.Typography.titleSmall)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background {
                            Capsule()
                                .fill(accentColor)
                                .overlay { Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.16), Color.clear], startPoint: .top, endPoint: .center)) }
                                .shadow(color: accentColor.opacity(0.40), radius: 16, x: 0, y: 5)
                        }
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.97))
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving || text == memory.content)
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text == memory.content ? 0.45 : 1.0)

                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(SpektTheme.Typography.bodyMedium)
                            .foregroundColor(SpektTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
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
            text = initialText
            withAnimation(SpektTheme.Motion.springDefault.delay(0.05)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }
}

// MARK: - Signal Card

struct SignalCard: View {
    let section : SignalSection
    @Binding var expanded: SignalSection?
    @ObservedObject var vm: SignalViewModel

    @ObservedObject private var prefs = PreferencesStore.shared

    private var isExpanded: Bool { expanded == section }
    private var isDimmed  : Bool { expanded != nil && !isExpanded }

    var body: some View {
        GlassCard(
            intensity:    isExpanded ? .elevated : .thin,
            cornerRadius: SpektTheme.Radius.lg,
            isElevated:   isExpanded
        ) {
            VStack(spacing: 0) {
                headerRow
                    .contentShape(Rectangle())
                    .cardPress()
                    .onTapGesture {
                        withAnimation(SpektTheme.Motion.normal) {
                            expanded = isExpanded ? nil : section
                        }
                        #if os(iOS)
                        HapticEngine.selection()
                        #endif
                        // Lazy-load data when card is first opened
                        if !isExpanded {
                            Task { await lazyLoad() }
                        }
                    }

                if isExpanded {
                    GlassDivider()
                        .padding(.horizontal, SpektTheme.Spacing.md)
                        .padding(.top, 2)

                    expandedContent
                        .transition(.cardBodyReveal)
                }
            }
        }
        .opacity(isDimmed ? 0.44 : 1.0)
        .scaleEffect(isDimmed ? 0.975 : 1.0)
        .animation(SpektTheme.Motion.normal, value: isExpanded)
        .animation(SpektTheme.Motion.normal, value: isDimmed)
    }

    private func lazyLoad() async {
        switch section {
        case .context:
            if vm.memoriesState == .idle { await vm.loadMemories() }
        case .patterns:
            if vm.patternsState == .idle { await vm.loadPatterns() }
        case .preferences:
            break
        }
    }

    // MARK: Header Row

    private var headerRow: some View {
        HStack(spacing: SpektTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(section.accentColor.opacity(isExpanded ? 0.20 : 0.12))
                    .frame(width: 36, height: 36)
                    .animation(SpektTheme.Motion.springSnappy, value: isExpanded)
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(section.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(SpektTheme.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(SpektTheme.Colors.textPrimary)

                Text(section == .preferences && !isExpanded
                        ? prefs.collapsedSummary
                        : section == .context && !isExpanded
                            ? "\(vm.memoriesCount) nodes"
                            : section == .patterns && !isExpanded
                                ? "\(vm.effectivePatterns.sessionsThisWeek) sessions this week"
                                : section.subtitle
                )
                .font(SpektTheme.Typography.bodySmall)
                .foregroundColor(SpektTheme.Colors.textTertiary)
                .lineLimit(1)
                .animation(SpektTheme.Motion.springSnappy, value: prefs.collapsedSummary)
                .animation(SpektTheme.Motion.springSnappy, value: vm.memoriesCount)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(
                    isExpanded
                        ? section.accentColor.opacity(0.70)
                        : SpektTheme.Colors.textTertiary
                )
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(SpektTheme.Motion.springSnappy, value: isExpanded)
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.vertical, 12)
    }

    // MARK: Expanded Content Router

    @ViewBuilder
    private var expandedContent: some View {
        switch section {
        case .preferences:
            PreferencesContentView(accentColor: section.accentColor, vm: vm)
        case .patterns:
            PatternsContentView(accentColor: section.accentColor, vm: vm)
        case .context:
            MemoryListContent(accentColor: section.accentColor, vm: vm)
        }
    }
}

// MARK: - Scroll Offset Key

private struct SignalScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Signal View

struct SignalView: View {
    /// Inject the shared ViewModel from the root (SpektMainView).
    /// The default value lets previews and standalone usage work without ceremony.
    @ObservedObject var vm: SignalViewModel

    // Context Memory opens by default — the page's core value
    @State private var expandedSection: SignalSection? = .context

    @State private var headerVisible = false
    @State private var coreVisible   = false
    @State private var handleVisible = false
    @State private var pill1Visible  = false
    @State private var pill2Visible  = false
    @State private var cardsVisible  = false

    @State private var scrollOffset: CGFloat = 0

    private var coreParallax: CGFloat {
        guard scrollOffset < 0 else { return 0 }
        return -scrollOffset * 0.22
    }

    private var displayHandle: String {
        AuthService.shared.user?.email?.components(separatedBy: "@").first
            ?? UserDefaults.standard.string(forKey: "mockAuth_email")?.components(separatedBy: "@").first
            ?? "your-signal"
    }

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()
            ambientLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    GeometryReader { geo in
                        Color.clear.preference(
                            key: SignalScrollOffsetKey.self,
                            value: geo.frame(in: .named("signal")).minY
                        )
                    }
                    .frame(height: 0)

                    titleRow
                        .padding(.top, SpektTheme.Spacing.xl)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : -10)

                    VStack(spacing: SpektTheme.Spacing.md) {
                        IdentityCore(isFocused: expandedSection != nil)
                            .padding(.top, SpektTheme.Spacing.xl)

                        identityBadge
                    }
                    .offset(y: coreParallax)
                    .opacity(coreVisible ? 1 : 0)
                    .scaleEffect(coreVisible ? 1 : 0.88)

                    VStack(spacing: SpektTheme.Spacing.sm) {
                        ForEach(SignalSection.allCases) { section in
                            SignalCard(section: section, expanded: $expandedSection, vm: vm)
                        }
                    }
                    .padding(.horizontal, SpektTheme.Spacing.xl)
                    .padding(.top, SpektTheme.Spacing.xl)
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 20)

                    Spacer(minLength: 120)
                }
            }
        }
        .coordinateSpace(name: "signal")
        .onPreferenceChange(SignalScrollOffsetKey.self) { scrollOffset = $0 }
        .onAppear { staggerIn() }
        .task { await vm.loadAll() }
        // Add Memory sheet
        .sheet(isPresented: $vm.showAddMemory) {
            AddMemorySheet(vm: vm)
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(SpektTheme.Colors.base)
                .presentationCornerRadius(SpektTheme.Radius.xl)
        }
        // Reset Identity confirmation
        .confirmationDialog(
            "Reset AI Identity?",
            isPresented: $vm.showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All Memories", role: .destructive) {
                Task { await vm.resetIdentity() }
            }
            Button("Cancel", role: .cancel) {
                vm.showResetConfirm = false
            }
        } message: {
            Text("This will permanently delete all \(vm.memoriesCount) memory nodes. Your AI will start fresh.")
        }
    }

    // MARK: Ambient Layer

    @ViewBuilder
    private var ambientLayer: some View {
        let color = expandedSection?.accentColor.opacity(0.11) ?? Color.clear
        RadialGradient(
            colors: [color, Color.clear],
            center: .bottom, startRadius: 0, endRadius: 420
        )
        .blur(radius: 24)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(SpektTheme.Motion.slow, value: expandedSection)
    }

    // MARK: Title Row

    private var titleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR SIGNAL")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3.2)
                    .foregroundColor(SpektTheme.Colors.textTertiary)
                Text("AI Identity")
                    .font(SpektTheme.Typography.displayMedium)
                    .foregroundColor(SpektTheme.Colors.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, SpektTheme.Spacing.xl)
    }

    // MARK: Identity Badge

    private var identityBadge: some View {
        VStack(spacing: SpektTheme.Spacing.sm) {
            Text(displayHandle)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(SpektTheme.Colors.textSecondary)
                .opacity(handleVisible ? 1 : 0)
                .offset(y: handleVisible ? 0 : 6)

            HStack(spacing: SpektTheme.Spacing.sm) {
                GlassPillTag(label: "\(vm.memoriesCount) memories", dot: SpektTheme.Colors.accent)
                    .opacity(pill1Visible ? 1 : 0)
                    .scaleEffect(pill1Visible ? 1.0 : 0.80)
                    .offset(y: pill1Visible ? 0 : 5)
                    .contentTransition(.numericText())
                    .animation(SpektTheme.Motion.springBouncy, value: vm.memoriesCount)

                GlassPillTag(label: "Active", dot: SpektTheme.Colors.positive)
                    .opacity(pill2Visible ? 1 : 0)
                    .scaleEffect(pill2Visible ? 1.0 : 0.80)
                    .offset(y: pill2Visible ? 0 : 5)
            }
        }
    }

    // MARK: Stagger In

    private func staggerIn() {
        withAnimation(SpektTheme.Motion.springDefault.delay(0.04)) { headerVisible = true }
        withAnimation(SpektTheme.Motion.springBouncy.delay(0.12))  { coreVisible   = true }
        withAnimation(SpektTheme.Motion.springDefault.delay(0.22)) { handleVisible = true }
        withAnimation(SpektTheme.Motion.springBouncy.delay(0.30))  { pill1Visible  = true }
        withAnimation(SpektTheme.Motion.springBouncy.delay(0.38))  { pill2Visible  = true }
        withAnimation(SpektTheme.Motion.springDefault.delay(0.32)) { cardsVisible  = true }
    }
}

// MARK: - Preview

#Preview {
    SignalView(vm: SignalViewModel())
        .preferredColorScheme(.dark)
}
