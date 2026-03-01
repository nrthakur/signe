import SwiftUI

struct LetterCard: View {
    let letter: ASLLetter
    var accuracy: Float?
    var isLocked: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .frame(width: 64, height: 64)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(letter.displayName)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(letter.difficulty.color)
                }
            }

            if let accuracy, !isLocked {
                Text("\(Int(accuracy * 100))%")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(isLocked ? 0.5 : 1.0)
    }

    private var cardBackground: some ShapeStyle {
        if isLocked {
            return AnyShapeStyle(.ultraThinMaterial)
        }
        return AnyShapeStyle(.regularMaterial)
    }
}
