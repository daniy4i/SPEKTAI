//
//  MotionSystem.swift
//  lannaapp
//
//  Reusable animation modifiers, transitions, and haptic utilities.
//  Design rules:
//    - Physical, never decorative
//    - Instant feedback on direct touch
//    - Spring-based everywhere except continuous loops
//    - No animated blur (GPU-expensive, perceptually weak at small radii)
//

import SwiftUI

// MARK: - View Extensions
extension View {

    /// Scale + opacity — for non-card interactive views (labels, icons).
    func pressScale(_ scale: CGFloat = 0.96) -> some View {
        modifier(PressScaleModifier(scale: scale))
    }

    /// Glass card press — scale + brightness. Surface darkens as it recedes.
    /// Physically accurate: glass absorbs light at the contact point.
    func cardPress() -> some View {
        modifier(CardPressModifier())
    }

    /// Staggered appear — opacity + upward drift, per-index delay.
    func staggeredAppear(index: Int, baseDelay: Double = 0.06) -> some View {
        modifier(StaggeredAppearModifier(index: index, baseDelay: baseDelay))
    }

    /// Skeleton shimmer — horizontal sweep for loading states.
    func shimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

// MARK: - Press Scale Modifier
/// Scale + opacity — lightweight feedback for icons, labels, secondary controls.
struct PressScaleModifier: ViewModifier {
    @GestureState private var isPressed = false
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .opacity(isPressed ? 0.88 : 1.0)
            .animation(SpektTheme.Motion.interactiveSpring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
            )
    }
}

// MARK: - Card Press Modifier
/// Premium press feel for glass card surfaces.
/// Uses brightness reduction (not opacity) — the surface darkens as it recedes
/// under touch, then springs back on release. No transparency change preserves
/// the glass material appearance throughout the interaction.
struct CardPressModifier: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.975 : 1.0)
            .brightness(isPressed ? -0.03 : 0)
            .animation(SpektTheme.Motion.interactiveSpring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
            )
    }
}

// MARK: - Staggered Appear Modifier
/// Opacity + upward drift only. No blur — animated blur is GPU-expensive and
/// adds no perceptual value at small radii; clean opacity is faster and sharper.
struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 14)
            .onAppear {
                withAnimation(
                    SpektTheme.Motion.springDefault
                        .delay(Double(index) * baseDelay)
                ) {
                    visible = true
                }
            }
    }
}

// MARK: - Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -0.4

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.07), .clear],
                        startPoint: .init(x: phase, y: 0.5),
                        endPoint:   .init(x: phase + 0.35, y: 0.5)
                    )
                    .blendMode(.plusLighter)
                    .onAppear {
                        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                            phase = 1.4
                        }
                    }
                }
            }
            .clipped()
    }
}

// MARK: - Transitions

extension AnyTransition {

    /// Primary screen/tab transition.
    /// Insertion: drift up from 14pt below + fade + very slight scale.
    /// Removal: drift up 8pt + fade. Gives depth without feeling heavy.
    static var glassReveal: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 14).combined(with: .opacity).combined(with: .scale(scale: 0.98)),
            removal:   .offset(y: -8).combined(with: .opacity)
        )
    }

    /// Sheet / panel slide up from below.
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal:   .move(edge: .bottom).combined(with: .opacity)
        )
    }

    /// Subtle inline content swap — tags, metadata, badges.
    static var fadeDrift: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 10).combined(with: .opacity),
            removal:   .offset(y: -6).combined(with: .opacity)
        )
    }

    /// Expand/collapse for card body content.
    /// Insertion reveals from above (content drops in under the header).
    /// Removal fades immediately so the card closes without linger.
    static var cardBodyReveal: AnyTransition {
        .asymmetric(
            insertion: .offset(y: -8).combined(with: .opacity),
            removal:   .opacity
        )
    }
}

// MARK: - Haptic Engine
#if os(iOS)
enum HapticEngine {

    // Prepare generators lazily so first-use latency is eliminated.
    private static let selectionGen  = UISelectionFeedbackGenerator()
    private static let lightGen      = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen     = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGen      = UIImpactFeedbackGenerator(style: .heavy)
    private static let notifyGen     = UINotificationFeedbackGenerator()

    /// Light: tab switches, list row selection, toggle.
    static func selection() {
        selectionGen.selectionChanged()
    }

    /// Impact: button presses, card interactions. Default: light.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        switch style {
        case .light:  lightGen.impactOccurred()
        case .medium: mediumGen.impactOccurred()
        case .heavy:  heavyGen.impactOccurred()
        default:      lightGen.impactOccurred()
        }
    }

    /// Notification: success/error/warning events.
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notifyGen.notificationOccurred(type)
    }
}
#endif

// MARK: - Animated Number
/// Integer that smoothly counts to new values. Spring-driven via contentTransition.
struct AnimatedNumber: View {
    let value: Int
    var font: Font  = SpektTheme.Typography.displayMedium
    var color: Color = SpektTheme.Colors.textPrimary

    @State private var displayed: Int = 0

    var body: some View {
        Text("\(displayed)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear { displayed = value }
            .onChange(of: value) { _, newValue in
                withAnimation(SpektTheme.Motion.springDefault) {
                    displayed = newValue
                }
            }
    }
}

// MARK: - Pulse Ring
/// Expanding ring for active/listening states. Fades as it grows.
struct PulseRing: View {
    let color: Color
    var size: CGFloat = 160
    @State private var scale:   CGFloat = 1.0
    @State private var opacity: Double  = 0.5

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    scale   = 1.55
                    opacity = 0
                }
            }
    }
}
