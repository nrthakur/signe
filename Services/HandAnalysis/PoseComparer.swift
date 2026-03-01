import Foundation

// MARK: - Comparison Result

struct ComparisonResult: Sendable {
    let overallAccuracy: Float
    let fingerStates: [FingerState]
    let matchStatus: MatchStatus
}

// MARK: - Pose Comparer

struct PoseComparer: Sendable {

    /// Compare a detected hand pose against a reference pose for a specific letter
    func compare(detected: HandPose, letter: ASLLetter) -> ComparisonResult? {
        guard let reference = ReferencePoseData.poses[letter] else { return nil }
        return compare(detected: detected, reference: reference)
    }

    func compare(detected: HandPose, reference: ReferencePoseEntry) -> ComparisonResult {
        let detectedAngles = computeFingerAngles(from: detected)

        // Per-finger comparison
        var fingerStates: [FingerState] = []
        var totalScore: Float = 0

        for finger in Finger.allCases {
            let result = compareFinger(
                finger: finger,
                detected: detectedAngles,
                detectedPose: detected,
                reference: reference
            )
            fingerStates.append(result.state)
            totalScore += result.score
        }

        // Simple average across all 5 fingers (equal weight — keeps things predictable)
        let overallAccuracy = totalScore / Float(Finger.allCases.count)
        let matchStatus = classifyOverall(accuracy: overallAccuracy)

        return ComparisonResult(
            overallAccuracy: overallAccuracy,
            fingerStates: fingerStates,
            matchStatus: matchStatus
        )
    }

    // MARK: - Angle Computation

    private func computeFingerAngles(from pose: HandPose) -> FingerAngles {
        FingerAngles(
            thumbCurl: curlAngle(for: .thumb, in: pose),
            indexCurl: curlAngle(for: .index, in: pose),
            middleCurl: curlAngle(for: .middle, in: pose),
            ringCurl: curlAngle(for: .ring, in: pose),
            littleCurl: curlAngle(for: .little, in: pose),
            thumbIndexSpread: spreadAngle(between: .thumb, and: .index, in: pose),
            indexMiddleSpread: spreadAngle(between: .index, and: .middle, in: pose),
            middleRingSpread: spreadAngle(between: .middle, and: .ring, in: pose),
            ringLittleSpread: spreadAngle(between: .ring, and: .little, in: pose)
        )
    }

    private func curlAngle(for finger: Finger, in pose: HandPose) -> Float {
        let t = finger.curlJointTriplet
        return pose.angleDegrees(at: t.middle, from: t.start, to: t.end) ?? 90
    }

    private func spreadAngle(between f1: Finger, and f2: Finger, in pose: HandPose) -> Float {
        let tip1Joint = f1.joints.last!
        let tip2Joint = f2.joints.last!
        let base1Joint = f1.joints.first!
        let base2Joint = f2.joints.first!

        guard let tip1 = pose.joints[tip1Joint],
              let tip2 = pose.joints[tip2Joint],
              let base1 = pose.joints[base1Joint],
              let base2 = pose.joints[base2Joint] else {
            return 15 // neutral default
        }

        let v1x = tip1.x - base1.x
        let v1y = tip1.y - base1.y
        let v2x = tip2.x - base2.x
        let v2y = tip2.y - base2.y

        let dot = v1x * v2x + v1y * v2y
        let len1 = sqrt(v1x * v1x + v1y * v1y)
        let len2 = sqrt(v2x * v2x + v2y * v2y)
        guard len1 > 0.001, len2 > 0.001 else { return 0 }

        let cosAngle = max(-1, min(1, dot / (len1 * len2)))
        return acos(cosAngle) * 180.0 / .pi
    }

    // MARK: - Per-Finger Comparison

    private struct FingerResult {
        let state: FingerState
        let score: Float  // 0-1
    }

    private func compareFinger(
        finger: Finger,
        detected: FingerAngles,
        detectedPose: HandPose,
        reference: ReferencePoseEntry
    ) -> FingerResult {
        let refCurl = reference.fingerAngles.curlAngle(for: finger)
        let detCurl = detected.curlAngle(for: finger)
        let tolerance = reference.tolerance

        // How far the detected angle is from the reference
        let curlDelta = detCurl - refCurl          // positive = more extended than ref
        let curlDistance = abs(curlDelta)

        // Score: 1.0 when within tolerance, drops linearly to 0 at tolerance+90°
        let effectiveDistance = max(0, curlDistance - tolerance)
        let curlScore = max(0, 1.0 - effectiveDistance / 90.0)

        // Spread contributes a small bonus/penalty
        var spreadPenalty: Float = 0
        if let refSpread = reference.fingerAngles.spreadAngle(for: finger),
           let detSpread = detected.spreadAngle(for: finger) {
            let spreadDistance = abs(detSpread - refSpread)
            if spreadDistance > 15 {
                spreadPenalty = min(0.2, spreadDistance / 200.0)
            }
        }

        var combinedScore = max(0, curlScore - spreadPenalty)

        // Per-finger status is based on the effective distance (after tolerance)
        var status: MatchStatus
        if effectiveDistance < MatchStatus.correctThreshold {
            status = .correct
        } else if effectiveDistance < MatchStatus.closeThreshold {
            status = .close
        } else {
            status = .incorrect
        }

        // Contact-sensitive letters (F, D variants, etc.) need stronger gating.
        if let expected = reference.expectedStates[finger], expected == .touchingThumb, finger != .thumb {
            let touch = normalizedTipDistance(between: .thumb, and: finger, in: detectedPose) ?? 1
            let touchScore = max(0, 1 - max(0, touch - 0.20) / 0.40)
            combinedScore = max(0, (curlScore * 0.35) + (touchScore * 0.65) - spreadPenalty)

            if touch <= 0.28 {
                status = .correct
            } else if touch <= 0.42 {
                status = .close
            } else {
                status = .incorrect
            }
        }

        let hint = generateHint(
            for: finger,
            curlDelta: curlDelta,
            effectiveDistance: effectiveDistance,
            expectedState: reference.expectedStates[finger]
        )

        let state = FingerState(
            id: finger,
            status: status,
            angleDelta: curlDelta,
            hint: hint
        )

        return FingerResult(state: state, score: combinedScore)
    }

    private func normalizedTipDistance(between f1: Finger, and f2: Finger, in pose: HandPose) -> Float? {
        guard let tip1 = pose.joints[f1.joints.last!],
              let tip2 = pose.joints[f2.joints.last!] else {
            return nil
        }

        let dx = tip1.x - tip2.x
        let dy = tip1.y - tip2.y
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

    // MARK: - Hint Generation

    private func generateHint(
        for finger: Finger,
        curlDelta: Float,
        effectiveDistance: Float,
        expectedState: ExpectedFingerState?
    ) -> String {
        // No hint needed if within threshold
        guard effectiveDistance > MatchStatus.correctThreshold else { return "" }

        let name = finger.displayName.lowercased()

        guard let expected = expectedState else {
            // Fallback: delta > 0 means user's finger is more extended than reference
            if curlDelta > 0 { return "Curl your \(name) more" }
            return "Extend your \(name) more"
        }

        switch expected {
        case .extended:
            if curlDelta < 0 { return "Extend your \(name) straight" }
        case .curled:
            if curlDelta > 0 { return "Curl your \(name) into fist" }
        case .bent:
            if curlDelta > 0 { return "Bend your \(name) more" }
            if curlDelta < 0 { return "Straighten your \(name) a bit" }
        case .hooked:
            if curlDelta > 0 { return "Hook your \(name) at the tip" }
            if curlDelta < 0 { return "Straighten your \(name) slightly" }
        case .touchingThumb:
            return "Touch your \(name) to thumb"
        }

        return ""
    }

    // MARK: - Classification

    private func classifyOverall(accuracy: Float) -> MatchStatus {
        if accuracy >= 0.70 { return .correct }
        if accuracy >= 0.45 { return .close }
        return .incorrect
    }
}
