import SwiftUI

struct LetterHeatmapGrid: View {
    let stats: [LetterStats]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Letter Mastery", systemImage: "square.grid.3x3.fill")
                .font(.system(.headline, design: .rounded))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(stats) { stat in
                    letterCell(stat: stat)
                }
            }

            // Legend
            HStack(spacing: 16) {
                legendItem(color: .green, label: "Mastered")
                legendItem(color: .orange, label: "Practicing")
                legendItem(color: .red, label: "Learning")
                legendItem(color: Color(.systemGray5), label: "Not tried")
            }
            .font(.system(.caption2, design: .rounded))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func letterCell(stat: LetterStats) -> some View {
        Text(stat.letter.displayName)
            .font(.system(.headline, design: .rounded, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(colorForStat(stat), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(textColorForStat(stat))
    }

    private func colorForStat(_ stat: LetterStats) -> Color {
        switch stat.masteryLevel {
        case .mastered: return .green.opacity(0.5)
        case .practicing: return .orange.opacity(0.4)
        case .learning: return .red.opacity(0.35)
        case .notStarted: return Color(.systemGray5)
        }
    }

    private func textColorForStat(_ stat: LetterStats) -> Color {
        switch stat.masteryLevel {
        case .mastered: return .green
        case .practicing: return .orange
        case .learning: return .red
        case .notStarted: return .secondary
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.5))
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
