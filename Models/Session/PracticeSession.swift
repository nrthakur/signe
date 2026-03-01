import Foundation

// MARK: - Session State

enum SessionState: Sendable {
    case idle
    case countdown(remaining: Int)
    case signing
    case holdConfirm(elapsed: Double)
    case letterComplete(matched: Bool)
    case timeout
    case summary
}

// MARK: - Practice Session

struct PracticeSession: Sendable, Identifiable {
    let id: UUID
    let startDate: Date
    var targetLetters: [ASLLetter]
    var attempts: [LetterAttempt]
    var currentIndex: Int
    var state: SessionState

    var currentLetter: ASLLetter? {
        guard currentIndex < targetLetters.count else { return nil }
        return targetLetters[currentIndex]
    }

    var isComplete: Bool {
        currentIndex >= targetLetters.count
    }

    var overallAccuracy: Float {
        guard !attempts.isEmpty else { return 0 }
        return attempts.map(\.accuracy).reduce(0, +) / Float(attempts.count)
    }

    var correctCount: Int {
        attempts.filter(\.matched).count
    }

    static func create(letters: [ASLLetter]) -> PracticeSession {
        PracticeSession(
            id: UUID(),
            startDate: Date(),
            targetLetters: letters,
            attempts: [],
            currentIndex: 0,
            state: .idle
        )
    }
}

// MARK: - Letter Attempt

struct LetterAttempt: Sendable, Identifiable {
    let id: UUID
    let letter: ASLLetter
    var matched: Bool
    var accuracy: Float
    var timeToMatch: Double?
    var fingerStates: [FingerState]

    static func create(letter: ASLLetter) -> LetterAttempt {
        LetterAttempt(
            id: UUID(),
            letter: letter,
            matched: false,
            accuracy: 0,
            timeToMatch: nil,
            fingerStates: Finger.allCases.map { .placeholder(finger: $0) }
        )
    }
}

// MARK: - Session Constants

enum SessionConstants {
    static let countdownDuration: Int = 3
    static let holdDuration: Double = 1.5
    static let timeoutDuration: Double = 10.0
    static let defaultSessionLength: Int = 6
}
