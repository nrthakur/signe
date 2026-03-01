import SwiftUI

struct SessionSummaryView: View {
    let session: PracticeSession
    let onRetry: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: headerIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(headerColor)

                Text(headerTitle)
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text("\(passedCount) of \(session.attempts.count) correct")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // Overall accuracy ring
            AccuracyRing(
                accuracy: session.overallAccuracy,
                status: MatchStatus.from(angleDelta: (1.0 - session.overallAccuracy) * 60),
                size: 100,
                lineWidth: 10
            )

            // Per-letter results
            VStack(alignment: .leading, spacing: 8) {
                Text("Letter Breakdown")
                    .font(.system(.headline, design: .rounded))
                    .padding(.horizontal, 4)

                ForEach(session.attempts) { attempt in
                    letterResultRow(attempt: attempt)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Action buttons
            HStack(spacing: 16) {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.counterclockwise")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.indigo, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(16)
    }

    // MARK: - Letter Result Row

    private func letterResultRow(attempt: LetterAttempt) -> some View {
        let grade = grade(for: attempt.accuracy)

        return HStack(spacing: 12) {
            // Letter
            Text(attempt.letter.displayName)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .frame(width: 32)

            // Status icon
            Image(systemName: grade.icon)
                .foregroundStyle(grade.color)

            // Accuracy bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(grade.color)
                        .frame(width: geometry.size.width * CGFloat(attempt.accuracy), height: 6)
                }
            }
            .frame(height: 6)

            // Percentage
            Text("\(Int(attempt.accuracy * 100))%")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            // Time
            if let time = attempt.timeToMatch {
                Text(String(format: "%.1fs", time))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Header Helpers

    private var passedCount: Int {
        session.attempts.filter { $0.accuracy >= 0.80 }.count
    }

    private func grade(for accuracy: Float) -> (icon: String, color: Color) {
        if accuracy >= 0.80 {
            return ("checkmark.circle.fill", .green)
        }
        if accuracy >= 0.50 {
            return ("exclamationmark.circle.fill", .yellow)
        }
        return ("xmark.circle.fill", .red)
    }

    private var headerIcon: String {
        if session.overallAccuracy >= 0.8 { return "star.fill" }
        if session.overallAccuracy >= 0.6 { return "hand.thumbsup.fill" }
        return "arrow.up.circle.fill"
    }

    private var headerColor: Color {
        if session.overallAccuracy >= 0.8 { return .yellow }
        if session.overallAccuracy >= 0.6 { return .green }
        return .orange
    }

    private var headerTitle: String {
        if session.overallAccuracy >= 0.8 { return "Excellent!" }
        if session.overallAccuracy >= 0.6 { return "Good Job!" }
        return "Keep Practicing"
    }
}
