import Foundation

// MARK: - Progress Record

struct ProgressRecord: Codable, Sendable, Identifiable {
    let id: UUID
    let date: Date
    let letter: ASLLetter
    let accuracy: Float
    let matched: Bool
    let timeToMatch: Double?
    let sessionID: UUID
    let lessonID: Int?

    static func from(attempt: LetterAttempt, sessionID: UUID, lessonID: Int? = nil) -> ProgressRecord {
        ProgressRecord(
            id: UUID(),
            date: Date(),
            letter: attempt.letter,
            accuracy: attempt.accuracy,
            matched: attempt.matched,
            timeToMatch: attempt.timeToMatch,
            sessionID: sessionID,
            lessonID: lessonID
        )
    }
}

// MARK: - Letter Stats

struct LetterStats: Sendable, Identifiable {
    let letter: ASLLetter
    var totalAttempts: Int
    var correctCount: Int
    var averageAccuracy: Float
    var ema: Float

    var id: String { letter.rawValue }

    var masteryLevel: MasteryLevel {
        if totalAttempts == 0 { return .notStarted }
        if ema >= 0.8 { return .mastered }
        if ema >= 0.6 { return .practicing }
        return .learning
    }

    static func empty(letter: ASLLetter) -> LetterStats {
        LetterStats(letter: letter, totalAttempts: 0, correctCount: 0, averageAccuracy: 0, ema: 0.5)
    }

    /// Update EMA with a new accuracy observation (alpha = 0.3)
    mutating func updateEMA(with accuracy: Float) {
        let alpha: Float = 0.3
        ema = alpha * accuracy + (1 - alpha) * ema
    }
}

// MARK: - Mastery Level

enum MasteryLevel: Sendable {
    case notStarted
    case learning
    case practicing
    case mastered

    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .learning: return "Learning"
        case .practicing: return "Practicing"
        case .mastered: return "Mastered"
        }
    }
}

// MARK: - User Progress

struct UserProgress: Codable, Sendable {
    var completedLessonIDs: Set<Int> = []
    var lessonBestAccuracies: [Int: Float] = [:]
    var totalPracticeSeconds: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastPracticeDate: Date?
    var sessionsCompleted: Int = 0
    var hasCompletedOnboarding: Bool = false

    enum CodingKeys: String, CodingKey {
        case completedLessonIDs
        case lessonBestAccuracies
        case totalPracticeSeconds
        case currentStreak
        case longestStreak
        case lastPracticeDate
        case sessionsCompleted
        case hasCompletedOnboarding
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completedLessonIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .completedLessonIDs) ?? []
        lessonBestAccuracies = try container.decodeIfPresent([Int: Float].self, forKey: .lessonBestAccuracies) ?? [:]
        totalPracticeSeconds = try container.decodeIfPresent(Int.self, forKey: .totalPracticeSeconds) ?? 0
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        lastPracticeDate = try container.decodeIfPresent(Date.self, forKey: .lastPracticeDate)
        sessionsCompleted = try container.decodeIfPresent(Int.self, forKey: .sessionsCompleted) ?? 0
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
    }
}
