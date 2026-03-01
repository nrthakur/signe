import SwiftUI

// MARK: - Progress View Model

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published var letterStats: [LetterStats] = []
    @Published var dailyAccuracies: [DailyAccuracy] = []
    @Published var totalPracticeTime: Int = 0
    @Published var streakDays: Int = 0
    @Published var longestStreak: Int = 0
    @Published var sessionsCompleted: Int = 0
    @Published var overallAccuracy: Float = 0
    @Published var masteredCount: Int = 0
    @Published var isLoaded: Bool = false

    private let persistence = PersistenceService.shared

    // MARK: - Data Loading

    func loadData() async {
        let records = await persistence.loadRecords()
        let stats = await persistence.computeLetterStats()
        let progress = await persistence.loadUserProgress()

        letterStats = ASLLetter.allCases.compactMap { stats[$0] }
        computeDailyAccuracies(from: records)

        totalPracticeTime = progress.totalPracticeSeconds
        streakDays = progress.currentStreak
        longestStreak = progress.longestStreak
        sessionsCompleted = progress.sessionsCompleted
        overallAccuracy = 0

        if !letterStats.isEmpty {
            let attempted = letterStats.filter { $0.totalAttempts > 0 }
            if !attempted.isEmpty {
                overallAccuracy = attempted.map(\.ema).reduce(0, +) / Float(attempted.count)
            }
        }

        masteredCount = letterStats.filter { $0.masteryLevel == .mastered }.count
        isLoaded = true
    }

    // MARK: - Daily Accuracy Computation

    private func computeDailyAccuracies(from records: [ProgressRecord]) {
        let calendar = Calendar.current

        // Group records by day
        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.date)
        }

        dailyAccuracies = grouped.map { date, dayRecords in
            let avgAccuracy = dayRecords.map(\.accuracy).reduce(0, +) / Float(dayRecords.count)
            return DailyAccuracy(
                date: date,
                accuracy: avgAccuracy,
                attempts: dayRecords.count
            )
        }
        .sorted { $0.date < $1.date }
        .suffix(30) // Last 30 days
        .map { $0 } // Convert from ArraySlice
    }
}

// MARK: - Daily Accuracy

struct DailyAccuracy: Identifiable, Sendable {
    let date: Date
    let accuracy: Float
    let attempts: Int

    var id: Date { date }
}
