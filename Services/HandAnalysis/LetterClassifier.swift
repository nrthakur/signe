import Foundation
import simd

// MARK: - Target Evaluation

struct TargetLetterEvaluation: Sendable {
    let targetLetter: ASLLetter
    let targetScore: Float
    let matchStatus: MatchStatus
    let fingerStates: [FingerState]
    let bestLetter: ASLLetter
    let bestScore: Float
    let runnerUpLetter: ASLLetter?
    let runnerUpScore: Float
    let marginToBestNonTarget: Float
    let isHoldEligible: Bool
    let guidance: String?
}

// MARK: - Letter Classifier

@MainActor
final class LetterClassifier {
    private struct ScoredLetter {
        let letter: ASLLetter
        let score: Float
        let baseResult: ComparisonResult
        let violations: [String]
    }

    private let comparer = PoseComparer()

    // Stricter decision gates than target-only scoring.
    private let strictAcceptScore: Float = 0.82
    private let strictAcceptMargin: Float = 0.12
    private let closeScore: Float = 0.70
    private let closeMargin: Float = 0.05

    // Temporal tracking for J/Z motion and confusion analytics.
    private var indexTrace: [(t: Double, p: SIMD2<Float>)] = []
    private var littleTrace: [(t: Double, p: SIMD2<Float>)] = []
    private let traceWindow: Double = 2.0
    private var confusionCounts: [String: Int] = [:]

    func resetTracking() {
        indexTrace.removeAll()
        littleTrace.removeAll()
        confusionCounts.removeAll()
    }

    func resetMotionTraces() {
        indexTrace.removeAll()
        littleTrace.removeAll()
    }

    func evaluateTarget(pose: HandPose, target: ASLLetter) -> TargetLetterEvaluation? {
        updateTraces(with: pose)

        var scored: [ScoredLetter] = []
        scored.reserveCapacity(ASLLetter.allCases.count)

        for letter in ASLLetter.allCases {
            guard let result = comparer.compare(detected: pose, letter: letter),
                  let reference = ReferencePoseData.poses[letter] else { continue }
            let constrained = applyConstraints(
                to: result,
                letter: letter,
                reference: reference,
                pose: pose
            )
            scored.append(
                ScoredLetter(
                    letter: letter,
                    score: constrained.score,
                    baseResult: result,
                    violations: constrained.violations
                )
            )
        }

        guard !scored.isEmpty else { return nil }
        guard let targetEntry = scored.first(where: { $0.letter == target }) else { return nil }

        let ranked = scored.sorted { $0.score > $1.score }
        guard let best = ranked.first else { return nil }
        let runnerUp = ranked.count > 1 ? ranked[1] : nil
        let bestNonTarget = ranked.first(where: { $0.letter != target })

        let targetScore = targetEntry.score
        let nonTargetScore = bestNonTarget?.score ?? 0
        let margin = targetScore - nonTargetScore

        let strictPass = (best.letter == target) && targetScore >= strictAcceptScore && margin >= strictAcceptMargin
        let closePass = targetScore >= closeScore && margin >= closeMargin

        let status: MatchStatus
        if strictPass {
            status = .correct
        } else if closePass {
            status = .close
        } else {
            status = .incorrect
        }

        if best.letter != target {
            let key = "\(target.rawValue)->\(best.letter.rawValue)"
            confusionCounts[key, default: 0] += 1
        }

        let guidance = makeGuidance(
            target: target,
            best: best,
            margin: margin,
            status: status
        )

        return TargetLetterEvaluation(
            targetLetter: target,
            targetScore: targetScore,
            matchStatus: status,
            fingerStates: targetEntry.baseResult.fingerStates,
            bestLetter: best.letter,
            bestScore: best.score,
            runnerUpLetter: runnerUp?.letter,
            runnerUpScore: runnerUp?.score ?? 0,
            marginToBestNonTarget: margin,
            isHoldEligible: strictPass,
            guidance: guidance
        )
    }

    // MARK: - Constraints

    private func applyConstraints(
        to result: ComparisonResult,
        letter: ASLLetter,
        reference: ReferencePoseEntry,
        pose: HandPose
    ) -> (score: Float, violations: [String]) {
        var violations: [String] = []
        let constraints = reference.constraints
        let observedStates = detectFingerStates(in: pose)
        var score = result.overallAccuracy

        for (finger, requiredState) in constraints.requiredStates {
            if observedStates[finger] != requiredState {
                violations.append("\(finger.displayName) should be \(requiredState.description.lowercased())")
            }
        }

        for (finger, forbiddenState) in constraints.forbiddenStates {
            if observedStates[finger] == forbiddenState {
                violations.append("\(finger.displayName) should not be \(forbiddenState.description.lowercased())")
            }
        }

        for pair in constraints.requiredTouches {
            if !isTouching(pair: pair, in: pose) {
                violations.append("\(pair.a.displayName) should touch \(pair.b.displayName)")
            }
        }

        for (pair, minDistance) in constraints.minTipDistance {
            if let d = normalizedTipDistance(pair: pair, in: pose), d < minDistance {
                violations.append("\(pair.a.displayName)/\(pair.b.displayName) should be farther apart")
            }
        }

        for (pair, maxDistance) in constraints.maxTipDistance {
            if let d = normalizedTipDistance(pair: pair, in: pose), d > maxDistance {
                violations.append("\(pair.a.displayName)/\(pair.b.displayName) should be closer")
            }
        }

        if !motionSatisfied(for: reference.motionRequirement) {
            switch reference.motionRequirement {
            case .jTrace:
                violations.append("Trace a J motion with your pinky")
            case .zTrace:
                violations.append("Trace a Z motion with your index finger")
            case .staticPose:
                break
            }
        }

        if !violations.isEmpty {
            // Hard penalties ensure confusable letters do not pass on similar static shapes.
            let severe = violations.count >= 3
            score = severe ? score * 0.25 : max(0, score - Float(violations.count) * 0.18)
        }

        // J and Z should rarely pass from static posture alone.
        if reference.motionRequirement != .staticPose && !motionSatisfied(for: reference.motionRequirement) {
            score = min(score, 0.40)
        }

        return (score: max(0, min(1, score)), violations)
    }

    private func detectFingerStates(in pose: HandPose) -> [Finger: ExpectedFingerState] {
        var states: [Finger: ExpectedFingerState] = [:]
        for finger in Finger.allCases {
            let t = finger.curlJointTriplet
            let angle = pose.angleDegrees(at: t.middle, from: t.start, to: t.end) ?? 90

            let state: ExpectedFingerState
            switch finger {
            case .thumb:
                if angle >= 145 { state = .extended }
                else if angle <= 80 { state = .curled }
                else { state = .bent }
            default:
                if angle >= 145 { state = .extended }
                else if angle <= 75 { state = .curled }
                else if angle <= 125 { state = .bent }
                else { state = .extended }
            }
            states[finger] = state
        }
        return states
    }

    private func isTouching(pair: FingerPair, in pose: HandPose) -> Bool {
        guard let d = normalizedTipDistance(pair: pair, in: pose) else { return false }
        return d <= 0.24
    }

    private func normalizedTipDistance(pair: FingerPair, in pose: HandPose) -> Float? {
        guard let tipA = pose.joints[pair.a.joints.last!],
              let tipB = pose.joints[pair.b.joints.last!] else {
            return nil
        }
        let dx = tipA.x - tipB.x
        let dy = tipA.y - tipB.y
        let distance = sqrt(dx * dx + dy * dy)
        guard let scale = handScale(in: pose), scale > 0.0001 else { return nil }
        return distance / scale
    }

    private func handScale(in pose: HandPose) -> Float? {
        guard let wrist = pose.joints[.wrist] else { return nil }
        let anchor = pose.joints[.middleMCP] ?? pose.joints[.middleTip]
        guard let anchor else { return nil }
        let dx = wrist.x - anchor.x
        let dy = wrist.y - anchor.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Motion Tracking

    private func updateTraces(with pose: HandPose) {
        let now = pose.timestamp
        if let indexTip = pose.joints[.indexTip] {
            indexTrace.append((t: now, p: SIMD2<Float>(indexTip.x, indexTip.y)))
        }
        if let littleTip = pose.joints[.littleTip] {
            littleTrace.append((t: now, p: SIMD2<Float>(littleTip.x, littleTip.y)))
        }
        indexTrace.removeAll { now - $0.t > traceWindow }
        littleTrace.removeAll { now - $0.t > traceWindow }
    }

    private func motionSatisfied(for requirement: MotionRequirement) -> Bool {
        switch requirement {
        case .staticPose:
            return true
        case .jTrace:
            return isJTraceDetected()
        case .zTrace:
            return isZTraceDetected()
        }
    }

    private func isJTraceDetected() -> Bool {
        let trace = filteredTrace(points: littleTrace.map(\.p), minimumStep: 0.0035)
        guard trace.count >= 6 else { return false }
        guard let first = trace.first, let last = trace.last else { return false }

        let dx = last.x - first.x
        let dy = last.y - first.y
        let xRange = (trace.map(\.x).max() ?? first.x) - (trace.map(\.x).min() ?? first.x)

        // J: noticeable downward motion and sideways hook.
        return dy < -0.06 && abs(dx) > 0.02 && xRange > 0.04
    }

    private func isZTraceDetected() -> Bool {
        let trace = filteredTrace(points: indexTrace.map(\.p), minimumStep: 0.0035)
        guard trace.count >= 7 else { return false }
        let xs = trace.map(\.x)
        let ys = trace.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return false
        }

        let xRange = maxX - minX
        let yRange = maxY - minY
        let turns = horizontalDirectionChanges(points: trace, minimumRunDistance: 0.018)
        let verticalDrop = (trace.last?.y ?? maxY) - (trace.first?.y ?? minY)

        // Z: horizontal zig-zag with at least 2 turns and enough sweep.
        return xRange > 0.07 && yRange > 0.02 && verticalDrop < -0.015 && turns >= 2
    }

    private func horizontalDirectionChanges(points: [SIMD2<Float>], minimumRunDistance: Float) -> Int {
        guard points.count >= 3 else { return 0 }
        var previousSign = 0
        var changes = 0
        var runDistance: Float = 0

        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x
            let absDX = abs(dx)
            if absDX < 0.0025 { continue }
            let sign = dx > 0 ? 1 : -1

            if previousSign == 0 {
                previousSign = sign
                runDistance = absDX
                continue
            }

            if sign == previousSign {
                runDistance += absDX
                continue
            }

            if runDistance >= minimumRunDistance {
                changes += 1
            }

            previousSign = sign
            runDistance = absDX
        }
        return changes
    }

    private func filteredTrace(points: [SIMD2<Float>], minimumStep: Float) -> [SIMD2<Float>] {
        guard let first = points.first else { return [] }
        var filtered: [SIMD2<Float>] = [first]

        for point in points.dropFirst() {
            guard let last = filtered.last else {
                filtered.append(point)
                continue
            }
            let dx = point.x - last.x
            let dy = point.y - last.y
            if sqrt(dx * dx + dy * dy) >= minimumStep {
                filtered.append(point)
            }
        }

        return filtered
    }

    // MARK: - Guidance

    private func makeGuidance(
        target: ASLLetter,
        best: ScoredLetter,
        margin: Float,
        status: MatchStatus
    ) -> String? {
        if status == .correct { return nil }

        if !best.violations.isEmpty {
            return best.violations.first
        }

        if best.letter != target, margin < 0.05 {
            return "Looks closer to \(best.letter.displayName). Emphasize \(target.displayName)'s distinct shape."
        }
        if best.letter != target {
            return "Currently reads as \(best.letter.displayName). Adjust toward \(target.displayName)."
        }
        if status == .close {
            return "Almost there. Keep the \(target.displayName) shape steadier."
        }
        return nil
    }
}
