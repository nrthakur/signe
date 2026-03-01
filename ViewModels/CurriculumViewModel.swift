import SwiftUI

// MARK: - Curriculum View Model

@MainActor
final class CurriculumViewModel: ObservableObject {
    @Published var lessons: [Lesson] = CurriculumData.lessons
    @Published var completedLessonIDs: Set<Int> = []
    @Published var lessonAccuracies: [Int: Float] = [:]
    @Published var isLoaded: Bool = false

    private let persistence = PersistenceService.shared

    // MARK: - Lesson State

    func isLessonUnlocked(_ lesson: Lesson) -> Bool {
        guard let requirement = lesson.unlockRequirement else {
            return true // No requirement = always unlocked
        }
        return completedLessonIDs.contains(requirement)
    }

    func bestAccuracy(for lesson: Lesson) -> Float? {
        lessonAccuracies[lesson.id]
    }

    func completionStatus(for lesson: Lesson) -> LessonStatus {
        if let accuracy = lessonAccuracies[lesson.id] {
            if accuracy >= lesson.requiredAccuracy {
                return .completed(accuracy: accuracy)
            }
            return .inProgress(bestAccuracy: accuracy)
        }
        if isLessonUnlocked(lesson) {
            return .unlocked
        }
        return .locked
    }

    // MARK: - Session Creation

    func createSession(for lesson: Lesson) -> [ASLLetter] {
        // Shuffle the lesson's letters for variety
        return lesson.letters.shuffled()
    }

    // MARK: - Adaptive Letter Selection

    /// Select the next letter with EMA-weighted probability (weaker letters appear more often)
    func selectWeightedLetters(from lesson: Lesson, letterStats: [ASLLetter: Float], count: Int) -> [ASLLetter] {
        var selected: [ASLLetter] = []

        for _ in 0..<count {
            let letter = selectOneWeighted(from: lesson.letters, stats: letterStats, excluding: selected.last)
            selected.append(letter)
        }

        return selected
    }

    private func selectOneWeighted(from letters: [ASLLetter], stats: [ASLLetter: Float], excluding last: ASLLetter?) -> ASLLetter {
        let candidates: [ASLLetter]
        if let last, letters.count > 1 {
            let filtered = letters.filter { $0 != last }
            candidates = filtered.isEmpty ? letters : filtered
        } else {
            candidates = letters
        }

        // Weight is inversely proportional to EMA accuracy
        let weights: [(ASLLetter, Float)] = candidates.map { letter in
            let ema = stats[letter] ?? 0.5
            let weight = max(0.1, 1.0 - ema) // Lower accuracy = higher weight
            return (letter, weight)
        }

        let totalWeight = weights.map(\.1).reduce(0, +)
        var random = Float.random(in: 0..<totalWeight)

        for (letter, weight) in weights {
            random -= weight
            if random <= 0 {
                return letter
            }
        }

        return candidates.last ?? .a
    }

    // MARK: - Progress Updates

    func loadProgress() async {
        let progress = await persistence.loadUserProgress()
        completedLessonIDs = progress.completedLessonIDs
        lessonAccuracies = progress.lessonBestAccuracies
        isLoaded = true
    }

    func recordSessionResult(lessonID: Int, accuracy: Float) async {
        // Update best accuracy
        if let existing = lessonAccuracies[lessonID] {
            lessonAccuracies[lessonID] = max(existing, accuracy)
        } else {
            lessonAccuracies[lessonID] = accuracy
        }

        // Check completion
        if let lesson = CurriculumData.lesson(withID: lessonID),
           accuracy >= lesson.requiredAccuracy {
            completedLessonIDs.insert(lessonID)
        }

        let best = lessonAccuracies[lessonID] ?? accuracy
        try? await persistence.updateUserProgress { progress in
            let existing = progress.lessonBestAccuracies[lessonID] ?? 0
            progress.lessonBestAccuracies[lessonID] = max(existing, best)

            if let lesson = CurriculumData.lesson(withID: lessonID),
               best >= lesson.requiredAccuracy {
                progress.completedLessonIDs.insert(lessonID)
            }
        }
    }
}

// MARK: - Lesson Status

enum LessonStatus {
    case locked
    case unlocked
    case inProgress(bestAccuracy: Float)
    case completed(accuracy: Float)

    var isAccessible: Bool {
        switch self {
        case .locked: return false
        default: return true
        }
    }
}
