import SwiftUI
import Combine

// MARK: - Practice View Model

@MainActor
final class PracticeViewModel: ObservableObject {
    // MARK: - Published State

    @Published var currentLetter: ASLLetter = .a
    @Published var handPose: HandPose?
    @Published var fingerStates: [FingerState] = Finger.allCases.map { .placeholder(finger: $0) }
    @Published var overallAccuracy: Float = 0
    @Published var matchStatus: MatchStatus = .incorrect
    @Published var isDetecting: Bool = false
    @Published var handDetected: Bool = false
    @Published var sessionState: SessionState = .idle
    @Published var session: PracticeSession?
    @Published var showNoHandPrompt: Bool = false
    @Published var recognitionGuidance: String?
    @Published var videoAspectRatio: CGFloat = 9.0 / 16.0

    // MARK: - Services

    let cameraService = CameraService()
    private let handAnalyzer = HandAnalyzer()
    private let letterClassifier = LetterClassifier()
    let hapticEngine = HapticEngine()

    // MARK: - Processing State

    private var processingTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var noHandTimer: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?
    private var simulationTask: Task<Void, Never>?

    // Rolling average buffer
    private var recentResults: [ComparisonResult] = []
    private let rollingWindowSize = 8

    // Debounce — 50ms gives ~20 comparisons/sec, enough for smooth feedback
    private var lastProcessTime: Double = 0
    private let debounceInterval: Double = 0.050
    private let passiveDebounceInterval: Double = 0.120

    // Hold confirm
    private var holdStartTime: Double?
    private var signingStartFrameTimestamp: Double?
    private var currentLessonID: Int?
    private var timeoutStartTime: Date?

    // MARK: - Lifecycle

    func startSession(letters: [ASLLetter], lessonID: Int? = nil) {
        guard !letters.isEmpty else { return }
        hapticEngine.prepare()
        cancelSessionTasks()
        letterClassifier.resetTracking()
        currentLessonID = lessonID
        session = PracticeSession.create(letters: letters)
        currentLetter = letters.first ?? .a
        resetState()
        startCountdown()
    }

    func startQuickPractice() {
        let letters = Array(ASLLetter.allCases.shuffled().prefix(SessionConstants.defaultSessionLength))
        startSession(letters: letters, lessonID: nil)
    }

    func retryCurrentSession() {
        guard let existingSession = session else { return }
        startSession(letters: existingSession.targetLetters, lessonID: currentLessonID)
    }

    func setupHaptics() {
        hapticEngine.prepare()
    }

    func stopSession() {
        cancelSessionTasks()
        letterClassifier.resetTracking()
        stopDetection()
        cameraService.stop()
        session = nil
        currentLessonID = nil
        resetState()
        isDetecting = false
        sessionState = .idle
    }

    /// Return to idle after a completed session while keeping camera preview active.
    func returnToIdle() {
        cancelSessionTasks()
        letterClassifier.resetTracking()
        stopDetection()
        cameraService.start()
        session = nil
        currentLessonID = nil
        resetState()
        isDetecting = false
        sessionState = .idle
    }

    // MARK: - Camera Pipeline

    func startDetection() {
        guard !isDetecting else { return }
        isDetecting = true

        if useSimulatorMode {
            startSimulatorDetection()
            return
        }

        cameraService.start()
        processingTask = Task.detached { [weak self] in
            guard let self else { return }
            let frames = self.cameraService.frames

            for await frame in frames {
                guard !Task.isCancelled else { break }
                await self.processFrame(frame)
            }
        }
    }

    func stopDetection() {
        processingTask?.cancel()
        processingTask = nil
        simulationTask?.cancel()
        simulationTask = nil
        isDetecting = false
    }

    // MARK: - Frame Processing

    private func analyzeFrame(_ frame: CameraFrame) async -> HandPose? {
        await handAnalyzer.analyze(frame: frame)
    }

    private func processFrame(_ frame: CameraFrame) async {
        if frame.width > 0 && frame.height > 0 {
            // Camera buffers can report landscape dimensions even when preview is portrait.
            // Normalize to portrait-like aspect to match preview-layer orientation.
            let w = CGFloat(frame.width)
            let h = CGFloat(frame.height)
            let nextRatio = min(w, h) / max(w, h)
            if abs(nextRatio - videoAspectRatio) > 0.001 {
                videoAspectRatio = nextRatio
            }
        }

        // Determine if we should process scoring (signing or confirming hold)
        let isScoringState: Bool
        switch sessionState {
        case .signing, .holdConfirm:
            isScoringState = true
        default:
            isScoringState = false
        }

        // Debounce. Non-scoring states (countdown/transition) run at lower frequency
        // to reduce CPU/thermal load while still keeping the overlay alive.
        let now = frame.timestamp
        let interval = isScoringState ? debounceInterval : passiveDebounceInterval
        guard now - lastProcessTime >= interval else { return }
        lastProcessTime = now

        // Analyze hand pose
        guard let pose = await analyzeFrame(frame) else {
            handPose = nil
            if recognitionGuidance != nil {
                recognitionGuidance = nil
            }
            if isScoringState, handDetected {
                handDetected = false
            }
            if isScoringState {
                startNoHandTimer()
            }
            return
        }

        // Update visualization
        handPose = pose
        if !handDetected {
            handDetected = true
        }
        cancelNoHandTimer()

        // If not in a scoring state, skip the comparison
        guard isScoringState else { return }
        if signingStartFrameTimestamp == nil {
            signingStartFrameTimestamp = now
        }

        // Compare target letter against all confusable letters and apply margin gating.
        guard let evaluation = letterClassifier.evaluateTarget(pose: pose, target: currentLetter) else { return }

        // Rolling average
        let result = ComparisonResult(
            overallAccuracy: evaluation.targetScore,
            fingerStates: evaluation.fingerStates,
            matchStatus: evaluation.matchStatus
        )
        recentResults.append(result)
        if recentResults.count > rollingWindowSize {
            recentResults.removeFirst()
        }

        let avgAccuracy: Float = recentResults.map(\.overallAccuracy).reduce(0, +) / Float(recentResults.count)

        // Update UI on main actor
        fingerStates = evaluation.fingerStates
        overallAccuracy = avgAccuracy
        matchStatus = evaluation.matchStatus
        recognitionGuidance = evaluation.guidance

        // Hold confirm logic
        handleHoldConfirm(
            accuracy: avgAccuracy,
            timestamp: now,
            isHoldEligible: evaluation.isHoldEligible
        )
    }

    // MARK: - Hold Confirm

    private func handleHoldConfirm(accuracy: Float, timestamp: Double, isHoldEligible: Bool) {
        if isHoldEligible {
            if holdStartTime == nil {
                holdStartTime = timestamp
            }

            let elapsed = timestamp - (holdStartTime ?? timestamp)
            sessionState = .holdConfirm(elapsed: elapsed)

            if elapsed >= SessionConstants.holdDuration {
                // Letter confirmed!
                hapticEngine.fireHoldConfirm()
                completeCurrentLetter(matched: true, accuracy: accuracy, timestamp: timestamp)
            }
        } else {
            // Reset hold if accuracy drops
            if holdStartTime != nil {
                holdStartTime = nil
                sessionState = .signing
            }
        }
    }

    // MARK: - Session Flow

    private func startCountdown() {
        sessionState = .countdown(remaining: SessionConstants.countdownDuration)

        countdownTask = Task {
            for i in stride(from: SessionConstants.countdownDuration, through: 1, by: -1) {
                sessionState = .countdown(remaining: i)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
            }
            beginSigning()
        }
    }

    private func beginSigning() {
        sessionState = .signing
        recentResults.removeAll()
        letterClassifier.resetMotionTraces()
        holdStartTime = nil
        signingStartFrameTimestamp = nil
        timeoutStartTime = nil
        showNoHandPrompt = false

        startDetection()
        startTimeoutTimer()
    }

    private func startTimeoutTimer() {
        timeoutTask?.cancel()
        timeoutStartTime = Date()
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(SessionConstants.timeoutDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            handleTimeout()
        }
    }

    private func handleTimeout() {
        switch sessionState {
        case .signing, .holdConfirm:
            break
        default:
            return
        }
        timeoutTask?.cancel()
        timeoutTask = nil
        timeoutStartTime = nil
        cancelNoHandTimer()
        sessionState = .timeout
        hapticEngine.fireIncorrect()

        // Record the attempt as failed
        if var currentSession = session {
            var attempt = LetterAttempt.create(letter: currentLetter)
            attempt.matched = false
            attempt.accuracy = overallAccuracy
            attempt.fingerStates = fingerStates
            currentSession.attempts.append(attempt)
            session = currentSession
        }

        // Auto-advance after 3 seconds
        advanceTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            advanceToNextLetter()
        }
    }

    private func completeCurrentLetter(matched: Bool, accuracy: Float, timestamp: Double) {
        timeoutTask?.cancel()
        timeoutTask = nil
        timeoutStartTime = nil
        cancelNoHandTimer()
        sessionState = .letterComplete(matched: matched)

        let timeToMatch = signingStartFrameTimestamp.map { max(0, timestamp - $0) }

        if var currentSession = session {
            var attempt = LetterAttempt.create(letter: currentLetter)
            attempt.matched = matched
            attempt.accuracy = accuracy
            attempt.timeToMatch = timeToMatch
            attempt.fingerStates = fingerStates
            currentSession.attempts.append(attempt)
            session = currentSession
        }

        // Brief pause then advance
        advanceTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            advanceToNextLetter()
        }
    }

    private func advanceToNextLetter() {
        guard var currentSession = session else { return }
        currentSession.currentIndex += 1
        session = currentSession

        if currentSession.isComplete {
            sessionState = .summary
            stopDetection()
            persistSessionResults(currentSession)
        } else if let nextLetter = currentSession.currentLetter {
            currentLetter = nextLetter
            resetState()
            startCountdown()
        }
    }

    // MARK: - Persistence

    private func persistSessionResults(_ session: PracticeSession) {
        let lessonID = currentLessonID
        let lessonAccuracy = session.overallAccuracy
        let records = session.attempts.map { attempt in
            ProgressRecord.from(
                attempt: attempt,
                sessionID: session.id,
                lessonID: lessonID
            )
        }

        Task {
            let persistence = PersistenceService.shared
            try? await persistence.saveRecords(records)
            try? await persistence.updateUserProgress { progress in
                if let lessonID {
                    let existing = progress.lessonBestAccuracies[lessonID] ?? 0
                    progress.lessonBestAccuracies[lessonID] = max(existing, lessonAccuracy)

                    if let lesson = CurriculumData.lesson(withID: lessonID),
                       lessonAccuracy >= lesson.requiredAccuracy {
                        progress.completedLessonIDs.insert(lessonID)
                    }
                }

                let now = Date()
                let calendar = Calendar.current
                let sessionSeconds = max(1, Int(now.timeIntervalSince(session.startDate)))
                progress.totalPracticeSeconds += sessionSeconds
                progress.sessionsCompleted += 1

                if let lastDate = progress.lastPracticeDate {
                    let lastDay = calendar.startOfDay(for: lastDate)
                    let today = calendar.startOfDay(for: now)
                    let dayDelta = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

                    if dayDelta == 1 {
                        progress.currentStreak += 1
                    } else if dayDelta > 1 {
                        progress.currentStreak = 1
                    }
                } else {
                    progress.currentStreak = 1
                }

                progress.longestStreak = max(progress.longestStreak, progress.currentStreak)
                progress.lastPracticeDate = now
            }
        }
    }

    // MARK: - No Hand Detection

    private func startNoHandTimer() {
        guard noHandTimer == nil else { return }
        noHandTimer = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            showNoHandPrompt = true
        }
    }

    private func cancelNoHandTimer() {
        noHandTimer?.cancel()
        noHandTimer = nil
        showNoHandPrompt = false
        recognitionGuidance = nil
    }

    // MARK: - Helpers

    private func resetState() {
        cancelNoHandTimer()
        handPose = nil
        fingerStates = Finger.allCases.map { .placeholder(finger: $0) }
        overallAccuracy = 0
        matchStatus = .incorrect
        recentResults.removeAll()
        holdStartTime = nil
        signingStartFrameTimestamp = nil
        timeoutStartTime = nil
        showNoHandPrompt = false
    }

    private func cancelSessionTasks() {
        processingTask?.cancel()
        processingTask = nil
        simulationTask?.cancel()
        simulationTask = nil
        countdownTask?.cancel()
        countdownTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        timeoutStartTime = nil
        noHandTimer?.cancel()
        noHandTimer = nil
        advanceTask?.cancel()
        advanceTask = nil
    }

    // MARK: - Simulator Demo Mode

    private var useSimulatorMode: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private func startSimulatorDetection() {
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.runSimulatorTick()
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    private func runSimulatorTick() {
        let isScoringState: Bool
        switch sessionState {
        case .signing, .holdConfirm:
            isScoringState = true
        default:
            isScoringState = false
        }

        guard isScoringState else { return }

        let now = Date().timeIntervalSinceReferenceDate
        if signingStartFrameTimestamp == nil {
            signingStartFrameTimestamp = now
        }

        let elapsed = now - (signingStartFrameTimestamp ?? now)
        let simulatedAccuracy = min(0.94, Float(0.45 + elapsed * 0.28))
        let status: MatchStatus
        if simulatedAccuracy >= 0.82 {
            status = .correct
        } else if simulatedAccuracy >= 0.65 {
            status = .close
        } else {
            status = .incorrect
        }

        handPose = nil
        handDetected = true
        cancelNoHandTimer()

        overallAccuracy = simulatedAccuracy
        matchStatus = status
        recognitionGuidance = status == .correct ? nil : "Simulator mode: auto-detecting hand shape"
        fingerStates = Finger.allCases.map { finger in
            FingerState(
                id: finger,
                status: status,
                angleDelta: 0,
                hint: status == .correct ? "" : "Adjust \(finger.displayName.lowercased())"
            )
        }

        handleHoldConfirm(
            accuracy: simulatedAccuracy,
            timestamp: now,
            isHoldEligible: simulatedAccuracy >= 0.84
        )
    }

    // MARK: - Timer UI

    func remainingLetterTime(at date: Date = Date()) -> Double {
        guard let timeoutStartTime else { return SessionConstants.timeoutDuration }
        let elapsed = date.timeIntervalSince(timeoutStartTime)
        return max(0, SessionConstants.timeoutDuration - elapsed)
    }

    func timeoutProgress(at date: Date = Date()) -> Double {
        guard SessionConstants.timeoutDuration > 0 else { return 0 }
        return max(0, min(1, remainingLetterTime(at: date) / SessionConstants.timeoutDuration))
    }
}
