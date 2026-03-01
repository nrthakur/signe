import SwiftUI

@main
struct SigneApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(coordinator)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding) {
                        hasCompletedOnboarding = true
                    }
                }
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
        }
    }
}
