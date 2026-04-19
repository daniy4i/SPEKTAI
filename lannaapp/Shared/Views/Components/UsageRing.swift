import SwiftUI

// MARK: - Usage Ring Component

struct UsageRing: View {
    let progress: Double
    let size: CGFloat
    let color: Color
    
    private var strokeWidth: CGFloat {
        size * 0.1
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.2), lineWidth: strokeWidth)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
            
            // Progress text
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.2, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        UsageRing(progress: 0.65, size: 60, color: .blue)
        UsageRing(progress: 0.30, size: 80, color: .orange)
        UsageRing(progress: 0.15, size: 100, color: .red)
    }
    .padding()
}
