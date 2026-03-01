import CoreHaptics
import AudioToolbox
import UIKit

// MARK: - Haptic Engine

@MainActor
final class HapticEngine {
    private var engine: CHHapticEngine?
    private var isAvailable: Bool = false
    private var supportsCoreHaptics: Bool = false
    private var lastFiredTime: Double = 0
    private let throttleInterval: Double = 0.300

    // Pre-loaded patterns
    private var correctPattern: CHHapticPattern?
    private var incorrectPattern: CHHapticPattern?
    private var holdConfirmPattern: CHHapticPattern?
    private var streakPattern: CHHapticPattern?

    // UIKit fallback generators (work across more devices/configurations)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)

    // MARK: - Setup

    func prepare() {
        if engine != nil {
            return
        }

        supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        // Prepare UIKit generators regardless of CoreHaptics availability.
        notificationFeedback.prepare()
        impactLight.prepare()
        impactRigid.prepare()

        guard supportsCoreHaptics else {
            isAvailable = false
            return
        }

        do {
            let engine = try CHHapticEngine()

            engine.stoppedHandler = { [weak self] reason in
                Task { @MainActor [weak self] in
                    self?.handleEngineStopped(reason: reason)
                }
            }

            engine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.restartEngine()
                }
            }

            try engine.start()
            self.engine = engine
            isAvailable = true
            preloadPatterns()
        } catch {
            isAvailable = false
        }
    }

    // MARK: - Fire Patterns

    func fireCorrect() {
        _ = firePattern(correctPattern)
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }

    func fireIncorrect() {
        _ = firePattern(incorrectPattern)
        notificationFeedback.notificationOccurred(.warning)
        notificationFeedback.prepare()
        if !supportsCoreHaptics {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    func fireHoldConfirm() {
        _ = firePattern(holdConfirmPattern)
        impactRigid.impactOccurred(intensity: 1.0)
        impactRigid.prepare()
        if !supportsCoreHaptics {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    func fireStreak() {
        _ = firePattern(streakPattern)
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }

    /// Simple impact for UI feedback
    func fireLight() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    // MARK: - Internal

    @discardableResult
    private func firePattern(_ pattern: CHHapticPattern?) -> Bool {
        if !isAvailable, supportsCoreHaptics {
            restartEngine()
        }
        guard isAvailable, let engine, let pattern else { return false }

        let now = CACurrentMediaTime()
        guard now - lastFiredTime >= throttleInterval else { return true }
        lastFiredTime = now

        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            // Graceful degradation — haptics fail silently
            return false
        }
    }

    private func handleEngineStopped(reason: CHHapticEngine.StoppedReason) {
        isAvailable = false
    }

    private func restartEngine() {
        do {
            try engine?.start()
            isAvailable = true
        } catch {
            isAvailable = false
        }
    }

    // MARK: - Pattern Definitions

    private func preloadPatterns() {
        // Correct: Single crisp tap — clear, satisfying feedback
        correctPattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                ],
                relativeTime: 0
            ),
        ], parameters: [])

        // Incorrect: Double soft pulse — noticeable but not jarring
        incorrectPattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
                ],
                relativeTime: 0.12
            ),
        ], parameters: [])

        // Hold Confirm: Rising continuous into a final tap
        holdConfirmPattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                ],
                relativeTime: 0,
                duration: 0.3
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                ],
                relativeTime: 0.35
            ),
        ], parameters: [])

        // Streak (5+): Triple light tap — celebratory
        streakPattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                ],
                relativeTime: 0.08
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                ],
                relativeTime: 0.16
            ),
        ], parameters: [])
    }
}
