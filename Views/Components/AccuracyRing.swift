import SwiftUI

struct AccuracyRing: View {
    let accuracy: Float
    let status: MatchStatus
    var size: CGFloat = 80
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, accuracy))))
                .stroke(
                    status.color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: accuracy)

            // Percentage text
            VStack(spacing: 0) {
                Text("\(Int(accuracy * 100))")
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                Text("%")
                    .font(.system(size: size * 0.14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Small Accuracy Indicator

struct AccuracyDot: View {
    let accuracy: Float

    var color: Color {
        if accuracy >= 0.75 { return .green }
        if accuracy >= 0.50 { return .orange }
        return .red
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}
