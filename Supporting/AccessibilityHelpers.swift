import SwiftUI
import UIKit

// MARK: - Accessibility Announcements

@MainActor
enum AccessibilityAnnouncement {
    static func letterMatched(_ letter: ASLLetter) {
        announce("Correct! You signed \(letter.displayName)")
    }

    static func letterTimeout(_ letter: ASLLetter) {
        announce("Time's up for letter \(letter.displayName)")
    }

    static func fingerHint(_ hint: String) {
        announce(hint)
    }

    static func sessionComplete(accuracy: Float, correct: Int, total: Int) {
        announce("Session complete. \(correct) of \(total) correct. Overall accuracy \(Int(accuracy * 100)) percent")
    }

    static func countdownTick(_ remaining: Int) {
        announce("\(remaining)")
    }

    static func holdProgress() {
        announce("Hold your sign steady")
    }

    private static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Accessibility View Modifiers

extension View {
    func letterCardAccessibility(letter: ASLLetter, accuracy: Float?) -> some View {
        self
            .accessibilityLabel("Letter \(letter.displayName)")
            .accessibilityValue(accuracy.map { "Accuracy \(Int($0 * 100)) percent" } ?? "Not practiced yet")
            .accessibilityHint("Double tap to view details")
    }

    func lessonAccessibility(lesson: Lesson, status: LessonStatus) -> some View {
        let statusLabel: String
        switch status {
        case .locked: statusLabel = "Locked"
        case .unlocked: statusLabel = "Available"
        case .inProgress(let accuracy): statusLabel = "In progress, best accuracy \(Int(accuracy * 100)) percent"
        case .completed(let accuracy): statusLabel = "Completed with \(Int(accuracy * 100)) percent accuracy"
        }

        return self
            .accessibilityLabel("Level \(lesson.id): \(lesson.title)")
            .accessibilityValue(statusLabel)
            .accessibilityHint(status.isAccessible ? "Double tap to start" : "Complete the previous lesson to unlock")
    }

    func fingerBadgeAccessibility(state: FingerState) -> some View {
        self
            .accessibilityLabel("\(state.id.displayName) finger: \(state.status.label)")
            .accessibilityValue(state.hint.isEmpty ? "" : state.hint)
    }
}
