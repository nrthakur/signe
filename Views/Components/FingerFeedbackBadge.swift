import SwiftUI

struct FingerFeedbackBadge: View {
    let state: FingerState
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            // Status indicator
            Circle()
                .fill(state.status.color)
                .frame(width: compact ? 10 : 14, height: compact ? 10 : 14)
                .shadow(color: state.status.color.opacity(0.4), radius: 3)

            // Finger name
            Text(compact ? state.id.shortName : state.id.displayName)
                .font(.system(compact ? .caption2 : .caption, design: .rounded, weight: .medium))
                .foregroundStyle(.primary)

            // Hint text (non-compact only)
            if !compact, state.status != .correct, !state.hint.isEmpty {
                Text(state.hint)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
            }
        }
        .padding(compact ? 4 : 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: compact ? 6 : 10))
    }
}

// MARK: - Feedback Panel

struct FingerFeedbackPanel: View {
    let fingerStates: [FingerState]
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            ForEach(fingerStates) { state in
                FingerFeedbackBadge(state: state, compact: compact)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Most actionable hint from the finger states
    var primaryHint: String? {
        // Find the first incorrect finger with a non-empty hint
        if let incorrect = fingerStates.first(where: { $0.status == .incorrect && !$0.hint.isEmpty }) {
            return incorrect.hint
        }
        if let close = fingerStates.first(where: { $0.status == .close && !$0.hint.isEmpty }) {
            return close.hint
        }
        return nil
    }
}
