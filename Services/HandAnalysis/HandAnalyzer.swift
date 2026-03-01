import Vision
import CoreVideo

// MARK: - Hand Analyzer

actor HandAnalyzer {
    private let request: VNDetectHumanHandPoseRequest
    private let confidenceThreshold: Float = 0.5

    init() {
        request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
    }

    /// Analyze a camera frame and return the detected hand pose.
    /// The data-output connection delivers portrait-oriented, non-mirrored buffers
    /// (videoOrientation = .portrait, isVideoMirrored = false).
    /// Orientation `.up` tells Vision the buffer is already upright — no rotation needed.
    func analyze(frame: CameraFrame) -> HandPose? {
        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else { return nil }
        return parseObservation(observation, timestamp: frame.timestamp)
    }

    // MARK: - Parse Vision Observation

    private func parseObservation(
        _ observation: VNHumanHandPoseObservation,
        timestamp: Double
    ) -> HandPose? {
        var joints: [HandJoint: SIMD3<Float>] = [:]
        var confidences: [HandJoint: Float] = [:]
        var totalConfidence: Float = 0
        var jointCount: Float = 0

        for handJoint in HandJoint.allCases {
            let visionJoint = handJoint.visionJointName

            guard let point = try? observation.recognizedPoint(visionJoint),
                  point.confidence > confidenceThreshold else {
                continue
            }

            // Vision returns normalised coords: x 0-1 left→right, y 0-1 bottom→top.
            // Store as 2D (z = 0) — all angle math is image-plane only.
            let position = SIMD3<Float>(
                Float(point.location.x),
                Float(point.location.y),
                0
            )

            joints[handJoint] = position
            confidences[handJoint] = Float(point.confidence)
            totalConfidence += Float(point.confidence)
            jointCount += 1
        }

        // Need at least 17 of 21 joints for a reliable comparison
        guard jointCount >= 17 else { return nil }

        let avgConfidence = totalConfidence / jointCount

        return HandPose(
            joints: joints,
            confidences: confidences,
            confidence: avgConfidence,
            timestamp: timestamp
        )
    }
}
