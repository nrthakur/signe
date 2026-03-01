import Vision
import simd

// MARK: - Hand Joint Enum

enum HandJoint: String, CaseIterable, Sendable, Hashable {
    case wrist
    // Thumb
    case thumbCMC, thumbMP, thumbIP, thumbTip
    // Index
    case indexMCP, indexPIP, indexDIP, indexTip
    // Middle
    case middleMCP, middlePIP, middleDIP, middleTip
    // Ring
    case ringMCP, ringPIP, ringDIP, ringTip
    // Little
    case littleMCP, littlePIP, littleDIP, littleTip

    /// Which finger this joint belongs to (nil for wrist)
    var finger: Finger? {
        switch self {
        case .wrist: return nil
        case .thumbCMC, .thumbMP, .thumbIP, .thumbTip: return .thumb
        case .indexMCP, .indexPIP, .indexDIP, .indexTip: return .index
        case .middleMCP, .middlePIP, .middleDIP, .middleTip: return .middle
        case .ringMCP, .ringPIP, .ringDIP, .ringTip: return .ring
        case .littleMCP, .littlePIP, .littleDIP, .littleTip: return .little
        }
    }

    /// Map to Vision framework joint name
    var visionJointName: VNHumanHandPoseObservation.JointName {
        switch self {
        case .wrist: return .wrist
        case .thumbCMC: return .thumbCMC
        case .thumbMP: return .thumbMP
        case .thumbIP: return .thumbIP
        case .thumbTip: return .thumbTip
        case .indexMCP: return .indexMCP
        case .indexPIP: return .indexPIP
        case .indexDIP: return .indexDIP
        case .indexTip: return .indexTip
        case .middleMCP: return .middleMCP
        case .middlePIP: return .middlePIP
        case .middleDIP: return .middleDIP
        case .middleTip: return .middleTip
        case .ringMCP: return .ringMCP
        case .ringPIP: return .ringPIP
        case .ringDIP: return .ringDIP
        case .ringTip: return .ringTip
        case .littleMCP: return .littleMCP
        case .littlePIP: return .littlePIP
        case .littleDIP: return .littleDIP
        case .littleTip: return .littleTip
        }
    }

    /// Reverse lookup from Vision joint name
    static func from(visionJoint: VNHumanHandPoseObservation.JointName) -> HandJoint? {
        allCases.first { $0.visionJointName == visionJoint }
    }

    /// Bone connections for skeleton rendering
    static let boneConnections: [(HandJoint, HandJoint)] = [
        // Thumb chain
        (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
        // Index chain
        (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
        // Middle chain
        (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
        // Ring chain
        (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
        // Little chain
        (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip),
        // Knuckle bridge
        (.indexMCP, .middleMCP), (.middleMCP, .ringMCP), (.ringMCP, .littleMCP),
    ]
}

// MARK: - Hand Pose

struct HandPose: Sendable {
    /// Joint positions in normalized coordinates (0-1), Vision coordinate system
    let joints: [HandJoint: SIMD3<Float>]

    /// Per-joint confidence (0-1)
    let confidences: [HandJoint: Float]

    /// Overall detection confidence
    let confidence: Float

    /// Timestamp from the camera frame
    let timestamp: Double

    /// Get the position for a specific joint, returns nil if not detected
    func position(for joint: HandJoint) -> SIMD3<Float>? {
        joints[joint]
    }

    /// Convert Vision normalized coords to SwiftUI view coords.
    /// Vision: origin bottom-left, Y up. SwiftUI: origin top-left, Y down.
    /// The front camera preview is mirrored by AVCaptureConnection, but Vision
    /// coords are in the original buffer space — so we mirror X to match the preview.
    func viewPosition(for joint: HandJoint, in size: CGSize, sourceAspectRatio: CGFloat) -> CGPoint? {
        guard let pos = joints[joint] else { return nil }
        let nx = 1.0 - CGFloat(pos.x) // mirror X for front camera preview
        let ny = 1.0 - CGFloat(pos.y) // flip Y for SwiftUI coordinate space

        guard size.width > 0, size.height > 0, sourceAspectRatio > 0 else {
            return CGPoint(x: nx * size.width, y: ny * size.height)
        }

        let viewAspect = size.width / size.height

        if viewAspect > sourceAspectRatio {
            // AspectFill scales to width and crops top/bottom.
            let renderedHeight = size.width / sourceAspectRatio
            let yCrop = (renderedHeight - size.height) / 2
            return CGPoint(
                x: nx * size.width,
                y: ny * renderedHeight - yCrop
            )
        } else {
            // AspectFill scales to height and crops left/right.
            let renderedWidth = size.height * sourceAspectRatio
            let xCrop = (renderedWidth - size.width) / 2
            return CGPoint(
                x: nx * renderedWidth - xCrop,
                y: ny * size.height
            )
        }
    }

    /// Compute the 2D angle (degrees) at the middle joint formed by start→middle→end.
    /// Uses only x,y (image plane) — z is unreliable from a single camera.
    /// Returns 180° for a perfectly straight finger, ~0° for fully curled.
    func angleDegrees(at middle: HandJoint, from start: HandJoint, to end: HandJoint) -> Float? {
        guard let a = joints[start], let b = joints[middle], let c = joints[end] else { return nil }
        let v1x = a.x - b.x
        let v1y = a.y - b.y
        let v2x = c.x - b.x
        let v2y = c.y - b.y
        let dot = v1x * v2x + v1y * v2y
        let len1 = sqrt(v1x * v1x + v1y * v1y)
        let len2 = sqrt(v2x * v2x + v2y * v2y)
        guard len1 > 0.0001, len2 > 0.0001 else { return nil }
        let cosAngle = max(-1, min(1, dot / (len1 * len2)))
        return acos(cosAngle) * 180.0 / .pi
    }
}
