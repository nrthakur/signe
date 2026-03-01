import SwiftUI

// MARK: - Finger

enum Finger: String, CaseIterable, Sendable, Identifiable, Codable {
    case thumb, index, middle, ring, little

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var shortName: String {
        switch self {
        case .thumb: return "Thm"
        case .index: return "Idx"
        case .middle: return "Mid"
        case .ring: return "Rng"
        case .little: return "Ltl"
        }
    }

    /// The joints that make up this finger (base to tip)
    var joints: [HandJoint] {
        switch self {
        case .thumb: return [.thumbCMC, .thumbMP, .thumbIP, .thumbTip]
        case .index: return [.indexMCP, .indexPIP, .indexDIP, .indexTip]
        case .middle: return [.middleMCP, .middlePIP, .middleDIP, .middleTip]
        case .ring: return [.ringMCP, .ringPIP, .ringDIP, .ringTip]
        case .little: return [.littleMCP, .littlePIP, .littleDIP, .littleTip]
        }
    }

    /// The PIP joint (or IP for thumb) used for curl measurement
    var curlJoint: HandJoint {
        switch self {
        case .thumb: return .thumbIP
        case .index: return .indexPIP
        case .middle: return .middlePIP
        case .ring: return .ringPIP
        case .little: return .littlePIP
        }
    }

    /// Joint triplet for curl angle: (base, middle, tip-side).
    /// The angle is measured at the *middle* joint.
    /// Thumb uses CMC→MP→IP to capture abduction from the palm.
    var curlJointTriplet: (start: HandJoint, middle: HandJoint, end: HandJoint) {
        switch self {
        case .thumb: return (.thumbCMC, .thumbMP, .thumbIP)
        case .index: return (.indexMCP, .indexPIP, .indexDIP)
        case .middle: return (.middleMCP, .middlePIP, .middleDIP)
        case .ring: return (.ringMCP, .ringPIP, .ringDIP)
        case .little: return (.littleMCP, .littlePIP, .littleDIP)
        }
    }
}

// MARK: - Match Status

enum MatchStatus: Sendable, Codable {
    case correct     // < 15 degrees off
    case close       // 15-30 degrees off
    case incorrect   // > 30 degrees off

    var color: Color {
        switch self {
        case .correct: return Color(.systemGreen)
        case .close: return Color(.systemOrange)
        case .incorrect: return Color(.systemRed)
        }
    }

    var label: String {
        switch self {
        case .correct: return "Correct"
        case .close: return "Close"
        case .incorrect: return "Needs adjustment"
        }
    }

    static let correctThreshold: Float = 15.0
    static let closeThreshold: Float = 30.0

    static func from(angleDelta: Float) -> MatchStatus {
        let absDelta = abs(angleDelta)
        if absDelta < correctThreshold { return .correct }
        if absDelta < closeThreshold { return .close }
        return .incorrect
    }
}

// MARK: - Finger State

struct FingerState: Sendable, Identifiable {
    let id: Finger
    var status: MatchStatus
    var angleDelta: Float
    var hint: String

    static func correct(finger: Finger) -> FingerState {
        FingerState(id: finger, status: .correct, angleDelta: 0, hint: "")
    }

    static func placeholder(finger: Finger) -> FingerState {
        FingerState(id: finger, status: .incorrect, angleDelta: 0, hint: "Waiting for detection")
    }
}
