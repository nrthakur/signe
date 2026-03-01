import SwiftUI

struct ProgressDashboardView: View {
    @StateObject private var viewModel = ProgressViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !viewModel.isLoaded {
                    ProgressView("Loading progress...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                } else if viewModel.sessionsCompleted == 0 {
                    emptyState
                } else {
                    // Summary stats
                    statsRow

                    // Accuracy chart
                    AccuracyChartView(data: viewModel.dailyAccuracies)

                    // Letter heatmap
                    LetterHeatmapGrid(stats: viewModel.letterStats)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress")
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Accuracy",
                value: "\(Int(viewModel.overallAccuracy * 100))%",
                icon: "target",
                color: .indigo
            )

            StatCard(
                title: "Streak",
                value: "\(viewModel.streakDays)d",
                icon: "flame.fill",
                color: .orange
            )

            StatCard(
                title: "Mastered",
                value: "\(viewModel.masteredCount)/26",
                icon: "star.fill",
                color: .yellow
            )

            StatCard(
                title: "Sessions",
                value: "\(viewModel.sessionsCompleted)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "chart.bar.fill")
                .font(.system(size: 56))
                .foregroundStyle(.indigo.opacity(0.4))

            Text("Track Your Progress")
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text("Complete practice sessions to see your accuracy charts, letter mastery heatmap, and streak data here.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
