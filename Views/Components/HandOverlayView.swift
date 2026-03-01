import SwiftUI

struct HandOverlayView: View {
    let handPose: HandPose?
    let fingerStates: [FingerState]
    let sourceAspectRatio: CGFloat

    private let jointRadius: CGFloat = 8
    private let boneWidth: CGFloat = 2.5

    var body: some View {
        Canvas { context, size in
            guard let pose = handPose else { return }

            let points = computeScreenPoints(pose: pose, size: size)

            // Draw bones first (behind joints)
            drawBones(context: &context, points: points)

            // Draw joints on top
            drawJoints(context: &context, points: points)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Screen Coordinate Computation

    private func computeScreenPoints(pose: HandPose, size: CGSize) -> [HandJoint: CGPoint] {
        var points: [HandJoint: CGPoint] = [:]

        for joint in HandJoint.allCases {
            if let viewPoint = pose.viewPosition(for: joint, in: size, sourceAspectRatio: sourceAspectRatio) {
                points[joint] = viewPoint
            }
        }

        return points
    }

    // MARK: - Drawing

    private func drawBones(context: inout GraphicsContext, points: [HandJoint: CGPoint]) {
        for (start, end) in HandJoint.boneConnections {
            guard let startPoint = points[start],
                  let endPoint = points[end] else { continue }

            let color = boneColor(for: start, end: end)

            var path = Path()
            path.move(to: startPoint)
            path.addLine(to: endPoint)

            context.stroke(
                path,
                with: .color(color.opacity(0.8)),
                style: StrokeStyle(lineWidth: boneWidth, lineCap: .round)
            )
        }
    }

    private func drawJoints(context: inout GraphicsContext, points: [HandJoint: CGPoint]) {
        for joint in HandJoint.allCases {
            guard let point = points[joint] else { continue }

            let color = jointColor(for: joint)
            let rect = CGRect(
                x: point.x - jointRadius,
                y: point.y - jointRadius,
                width: jointRadius * 2,
                height: jointRadius * 2
            )

            // Outer glow for correct joints
            if color == MatchStatus.correct.color {
                let glowRect = rect.insetBy(dx: -3, dy: -3)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(color.opacity(0.3))
                )
            }

            // Joint circle
            context.fill(
                Path(ellipseIn: rect),
                with: .color(color)
            )

            // White border for visibility against camera
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(0.8)),
                style: StrokeStyle(lineWidth: 1.5)
            )
        }
    }

    // MARK: - Color Mapping

    private func jointColor(for joint: HandJoint) -> Color {
        guard let finger = joint.finger else {
            // Wrist: use overall status
            let hasIncorrect = fingerStates.contains { $0.status == .incorrect }
            return hasIncorrect ? MatchStatus.close.color : MatchStatus.correct.color
        }

        if let state = fingerStates.first(where: { $0.id == finger }) {
            return state.status.color
        }

        return .white
    }

    private func boneColor(for start: HandJoint, end: HandJoint) -> Color {
        let joint = end.finger != nil ? end : start
        return jointColor(for: joint)
    }
}
