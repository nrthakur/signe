import SwiftUI

struct LessonsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = CurriculumViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(viewModel.lessons) { lesson in
                    LessonCard(
                        lesson: lesson,
                        status: viewModel.completionStatus(for: lesson),
                        onStart: {
                            coordinator.navigateToPractice(
                                with: viewModel.createSession(for: lesson),
                                lessonID: lesson.id
                            )
                        }
                    )
                }
            }
            .padding(.vertical)
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Lessons")
        .task {
            await viewModel.loadProgress()
        }
    }
}
