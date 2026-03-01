import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            NavigationStack(path: $coordinator.learnNavigationPath) {
                CurriculumView()
                    .navigationDestination(for: ASLLetter.self) { letter in
                        LetterDetailView(letter: letter)
                    }
            }
            .tabItem {
                Label(
                    AppCoordinator.Tab.learn.title,
                    systemImage: AppCoordinator.Tab.learn.systemImage
                )
            }
            .tag(AppCoordinator.Tab.learn)

            NavigationStack(path: $coordinator.lessonsNavigationPath) {
                LessonsView()
            }
            .tabItem {
                Label(
                    AppCoordinator.Tab.lessons.title,
                    systemImage: AppCoordinator.Tab.lessons.systemImage
                )
            }
            .tag(AppCoordinator.Tab.lessons)

            NavigationStack(path: $coordinator.practiceNavigationPath) {
                PracticeView()
            }
            .tabItem {
                Label(
                    AppCoordinator.Tab.practice.title,
                    systemImage: AppCoordinator.Tab.practice.systemImage
                )
            }
            .tag(AppCoordinator.Tab.practice)

            NavigationStack(path: $coordinator.progressNavigationPath) {
                ProgressDashboardView()
            }
            .tabItem {
                Label(
                    AppCoordinator.Tab.progress.title,
                    systemImage: AppCoordinator.Tab.progress.systemImage
                )
            }
            .tag(AppCoordinator.Tab.progress)
        }
        .tint(.indigo)
    }
}
