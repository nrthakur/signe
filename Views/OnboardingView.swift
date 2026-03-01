import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    var onComplete: () -> Void = {}
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "hand.raised.fingers.spread",
            title: "Learn ASL Fingerspelling",
            description: "Practice the 26 letters of the American Sign Language alphabet with real-time feedback from your camera.",
            color: .indigo
        ),
        OnboardingPage(
            icon: "camera.viewfinder",
            title: "Real-Time Hand Detection",
            description: "Point your front camera at your hand and see a color-coded skeleton showing which fingers are correct, close, or need adjustment.",
            color: .green
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Your Progress",
            description: "Work through progressive lessons, build streaks, and watch your accuracy improve over time.",
            color: .orange
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom section
            VStack(spacing: 16) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? pages[currentPage].color : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }

                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                        isPresented = false
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pages[currentPage].color, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 32)

                // Skip button
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        onComplete()
                        isPresented = false
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundStyle(page.color)

            Text(page.title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Onboarding Page

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}
