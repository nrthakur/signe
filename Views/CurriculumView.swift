import SwiftUI

struct CurriculumView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                allLettersSection
            }
            .padding(.vertical)
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Learn")
    }

    private var allLettersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("All Letters", systemImage: "textformat.abc")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)

            difficultyLegend

            let columns = [GridItem(.adaptive(minimum: 72, maximum: 100), spacing: 12)]

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ASLLetter.allCases) { letter in
                    NavigationLink(value: letter) {
                        LetterCard(letter: letter)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }

    private var difficultyLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Easy")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Hard")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DifficultyTier.allCases, id: \.rawValue) { tier in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tier.color)
                                .frame(width: 10, height: 10)

                            Text("\(tier.difficultyLabel) · \(tier.title)")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tier.color.opacity(0.12), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(tier.color.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Lesson Card

struct LessonCard: View {
    let lesson: Lesson
    let status: LessonStatus
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Level \(lesson.id)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(lesson.tier.color)
                            .textCase(.uppercase)

                        statusBadge
                    }

                    Text(lesson.title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(status.isAccessible ? .primary : .secondary)
                }

                Spacer()

                lessonIcon
            }

            // Description
            Text(lesson.description)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)

            // Letter pills
            HStack(spacing: 6) {
                ForEach(lesson.letters.prefix(8)) { letter in
                    Text(letter.displayName)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            lesson.tier.color.opacity(status.isAccessible ? 0.15 : 0.05),
                            in: Capsule()
                        )
                        .foregroundStyle(status.isAccessible ? lesson.tier.color : .secondary)
                }

                if lesson.letters.count > 8 {
                    Text("+\(lesson.letters.count - 8)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Accuracy bar (if attempted)
            accuracySection

            // Start button
            if status.isAccessible {
                Button(action: onStart) {
                    HStack {
                        Image(systemName: startIcon)
                        Text(startLabel)
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(lesson.tier.color, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .opacity(status.isAccessible ? 1.0 : 0.6)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .locked:
            Label("Locked", systemImage: "lock.fill")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        case .unlocked:
            Label("New", systemImage: "sparkle")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.indigo)
        case .inProgress:
            Label("In Progress", systemImage: "circle.lefthalf.filled")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.orange)
        case .completed:
            Label("Complete", systemImage: "checkmark.circle.fill")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.green)
        }
    }

    private var lessonIcon: some View {
        ZStack {
            Circle()
                .fill(lesson.tier.color.opacity(status.isAccessible ? 0.15 : 0.05))
                .frame(width: 48, height: 48)

            if case .locked = status {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            } else {
                Text("\(lesson.id)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(lesson.tier.color)
            }
        }
    }

    @ViewBuilder
    private var accuracySection: some View {
        switch status {
        case .inProgress(let accuracy), .completed(let accuracy):
            HStack(spacing: 8) {
                Text("Best: \(Int(accuracy * 100))%")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(lesson.tier.color)
                            .frame(width: geometry.size.width * CGFloat(accuracy), height: 4)
                    }
                }
                .frame(height: 4)

                Text("Need \(Int(lesson.requiredAccuracy * 100))%")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        default:
            EmptyView()
        }
    }

    private var startIcon: String {
        switch status {
        case .completed: return "arrow.counterclockwise"
        case .inProgress: return "play.fill"
        default: return "play.fill"
        }
    }

    private var startLabel: String {
        switch status {
        case .completed: return "Practice Again"
        case .inProgress: return "Continue"
        default: return "Start Lesson"
        }
    }
}
