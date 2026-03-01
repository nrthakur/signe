import SwiftUI

// MARK: - App Coordinator

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var selectedTab: Tab = .learn
    @Published var practiceNavigationPath = NavigationPath()
    @Published var learnNavigationPath = NavigationPath()
    @Published var lessonsNavigationPath = NavigationPath()
    @Published var progressNavigationPath = NavigationPath()
    @Published var sessionLetters: [ASLLetter]?
    @Published var sessionLessonID: Int?

    enum Tab: String, CaseIterable, Sendable {
        case practice
        case learn
        case lessons
        case progress

        var title: String {
            switch self {
            case .practice: return "Quiz"
            case .learn: return "Learn"
            case .lessons: return "Lessons"
            case .progress: return "Progress"
            }
        }

        var systemImage: String {
            switch self {
                case .practice: return "hand.raised.fingers.spread"
                case .learn: return "book.closed.fill"
                case .lessons: return "graduationcap.fill"
                case .progress: return "chart.bar.fill"
            }
        }
    }

    func navigateToLetterDetail(_ letter: ASLLetter) {
        selectedTab = .learn
        learnNavigationPath.append(letter)
    }

    func navigateToPractice(with letters: [ASLLetter]? = nil, lessonID: Int? = nil) {
        sessionLetters = letters
        sessionLessonID = lessonID
        selectedTab = .practice
    }

    func resetNavigation(for tab: Tab) {
        switch tab {
        case .practice: practiceNavigationPath = NavigationPath()
        case .learn: learnNavigationPath = NavigationPath()
        case .lessons: lessonsNavigationPath = NavigationPath()
        case .progress: progressNavigationPath = NavigationPath()
        }
    }
}
