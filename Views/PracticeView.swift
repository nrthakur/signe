import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = PracticeViewModel()
    @StateObject private var thermalMonitor = ThermalMonitor()
    @State private var cameraPermission: CameraPermission = .notDetermined

    init() {
        #if targetEnvironment(simulator)
        _cameraPermission = State(initialValue: .granted)
        #else
        _cameraPermission = State(initialValue: CameraService.checkPermission())
        #endif
    }

    var body: some View {
        ZStack {
            switch cameraPermission {
            case .notDetermined:
                permissionRequestView
            case .granted:
                cameraContentView
            case .denied:
                permissionDeniedView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.setupHaptics()
            thermalMonitor.startMonitoring()
            #if targetEnvironment(simulator)
            cameraPermission = .granted
            consumePendingSessionIfNeeded()
            #else
            cameraPermission = CameraService.checkPermission()
            if cameraPermission == .granted {
                await startCamera()
                consumePendingSessionIfNeeded()
            }
            #endif
        }
        .onChange(of: coordinator.sessionLetters) { _ in
            consumePendingSessionIfNeeded()
        }
        .onChange(of: cameraPermission) { newValue in
            guard newValue == .granted else { return }
            consumePendingSessionIfNeeded()
        }
        .onDisappear {
            viewModel.stopSession()
            thermalMonitor.stopMonitoring()
        }
    }

    // MARK: - Permission Request

    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.indigo)

            Text("Camera Access Needed")
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text("Signe uses your front camera to detect hand signs and provide real-time feedback.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    let granted = await CameraService.requestPermission()
                    cameraPermission = granted ? .granted : .denied
                    if granted {
                        await startCamera()
                        consumePendingSessionIfNeeded()
                    }
                }
            } label: {
                Text("Enable Camera")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text("Please enable camera access in Settings to use Signe for ASL practice.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Camera Content

    private var cameraContentView: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: viewModel.cameraService.captureSession)
                .ignoresSafeArea()

            // Hand skeleton overlay
            HandOverlayView(
                handPose: viewModel.handPose,
                fingerStates: viewModel.fingerStates,
                sourceAspectRatio: viewModel.videoAspectRatio
            )
            .ignoresSafeArea()

            // UI overlay
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomPanel
            }

            if isSimulatorMode {
                Label("Simulator Demo Mode (No Camera)", systemImage: "desktopcomputer")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.55), in: Capsule())
            }

            if case .idle = viewModel.sessionState {
                idleStateOverlay
            }

            // Thermal warning
            if thermalMonitor.thermalState == .serious || thermalMonitor.thermalState == .critical {
                VStack {
                    Spacer()
                    ThermalWarningView(thermalState: thermalMonitor.thermalState)
                    Spacer()
                }
            }

            // Session summary overlay
            if case .summary = viewModel.sessionState, let session = viewModel.session {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                ScrollView {
                    SessionSummaryView(
                        session: session,
                        onRetry: {
                            viewModel.retryCurrentSession()
                        },
                        onDone: {
                            viewModel.returnToIdle()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 8) {
            // Session state indicator
            sessionStateView

            // Target letter
            Text(viewModel.currentLetter.displayName)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var sessionStateView: some View {
        switch viewModel.sessionState {
        case .idle:
            EmptyView()
        case .countdown(let remaining):
            Text("\(remaining)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .transition(.scale)
        case .signing:
            if viewModel.showNoHandPrompt {
                Label("Show your hand", systemImage: "hand.raised")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        case .holdConfirm(let elapsed):
            holdProgressView(elapsed: elapsed)
        case .letterComplete(let matched):
            letterCompleteView(matched: matched)
        case .timeout:
            timeoutView
        case .summary:
            EmptyView()
        }
    }

    private var idleStateOverlay: some View {
        VStack(spacing: 12) {
            Text("Start Practicing")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Text("Run a quick random session or pick a specific letter from Learn.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.startQuickPractice()
            } label: {
                Label("Quick Practice", systemImage: "play.fill")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(.white)
            }

            Button {
                coordinator.selectedTab = .learn
            } label: {
                Text("Choose Letter in Learn")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func holdProgressView(elapsed: Double) -> some View {
        VStack(spacing: 4) {
            Text("Hold it...")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white)

            ProgressView(value: elapsed, total: SessionConstants.holdDuration)
                .tint(.green)
                .frame(width: 120)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func letterCompleteView(matched: Bool) -> some View {
        Label(
            matched ? "Correct!" : "Moving on...",
            systemImage: matched ? "checkmark.circle.fill" : "arrow.right.circle.fill"
        )
        .font(.system(.headline, design: .rounded))
        .foregroundStyle(matched ? .green : .orange)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var timeoutView: some View {
        VStack(spacing: 8) {
            Label("Time's up", systemImage: "clock.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.orange)

            Text(viewModel.currentLetter.handDescription)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            // Accuracy ring, feedback, and status
            if case .signing = viewModel.sessionState {
                HStack(spacing: 16) {
                    accuracyRing
                    VStack(spacing: 8) {
                        fingerFeedbackRow
                        statusText
                        timeRemainingView
                    }
                }
            } else if case .holdConfirm = viewModel.sessionState {
                HStack(spacing: 16) {
                    accuracyRing
                    VStack(spacing: 8) {
                        fingerFeedbackRow
                        Text("Great! Hold steady...")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.green)
                        timeRemainingView
                    }
                }
            }

            // Session progress
            if let session = viewModel.session {
                sessionProgressBar(session: session)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var statusText: some View {
        let classifierHint = viewModel.recognitionGuidance ?? ""
        let primaryHint = viewModel.fingerStates
            .first { $0.status != .correct }
            .map { $0.hint } ?? ""

        let statusLabel: String
        switch viewModel.matchStatus {
        case .correct:
            statusLabel = "Perfect!"
        case .close:
            if !classifierHint.isEmpty {
                statusLabel = classifierHint
            } else {
                statusLabel = primaryHint.isEmpty ? "Getting close!" : primaryHint
            }
        case .incorrect:
            if !classifierHint.isEmpty {
                statusLabel = classifierHint
            } else {
                statusLabel = primaryHint.isEmpty ? "Keep adjusting" : primaryHint
            }
        }

        return Text(statusLabel)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(viewModel.matchStatus.color)
            .lineLimit(2)
    }

    private var accuracyRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(viewModel.overallAccuracy))
                .stroke(
                    viewModel.matchStatus.color,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: viewModel.overallAccuracy)

            Text("\(Int(viewModel.overallAccuracy * 100))%")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(width: 56, height: 56)
    }

    private var timeRemainingView: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = viewModel.remainingLetterTime(at: context.date)
            let secondsLeft = Int(ceil(max(0, remaining)))
            let isUrgent = remaining <= 3

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    Text("\(secondsLeft)s left")
                }
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(isUrgent ? .orange : .secondary)

                ProgressView(value: viewModel.timeoutProgress(at: context.date))
                    .tint(isUrgent ? .orange : .indigo)
            }
        }
    }

    private var fingerFeedbackRow: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.fingerStates) { state in
                VStack(spacing: 2) {
                    Circle()
                        .fill(state.status.color)
                        .frame(width: 10, height: 10)
                    Text(state.id.shortName)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func sessionProgressBar(session: PracticeSession) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<session.targetLetters.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(progressColor(for: index, session: session))
                    .frame(height: 4)
            }
        }
    }

    private func progressColor(for index: Int, session: PracticeSession) -> Color {
        if index < session.attempts.count {
            return session.attempts[index].matched ? .green : .red.opacity(0.6)
        }
        if index == session.currentIndex {
            return .indigo
        }
        return .white.opacity(0.3)
    }

    // MARK: - Helpers

    private func startCamera() async {
        #if targetEnvironment(simulator)
        cameraPermission = .granted
        #else
        do {
            try await viewModel.cameraService.configure()
            viewModel.cameraService.start()
        } catch {
            cameraPermission = .denied
        }
        #endif
    }

    private func consumePendingSessionIfNeeded() {
        guard cameraPermission == .granted else { return }
        guard let letters = coordinator.sessionLetters else { return }
        viewModel.startSession(letters: letters, lessonID: coordinator.sessionLessonID)
        coordinator.sessionLetters = nil
        coordinator.sessionLessonID = nil
    }

    private var isSimulatorMode: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
