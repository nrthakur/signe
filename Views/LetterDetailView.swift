import SwiftUI
import UIKit

struct LetterDetailView: View {
    let letter: ASLLetter
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var referenceImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large letter display
                ZStack {
                    Circle()
                        .fill(letter.difficulty.color.opacity(0.15))
                        .frame(width: 160, height: 160)

                    Text(letter.displayName)
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(letter.difficulty.color)
                }
                .padding(.top, 16)

                // Difficulty badge
                Label(letter.difficulty.title, systemImage: "chart.bar.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(letter.difficulty.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(letter.difficulty.color.opacity(0.1), in: Capsule())

                referenceImageSection

                // Hand description
                VStack(alignment: .leading, spacing: 12) {
                    Label("How to sign", systemImage: "hand.raised.fill")
                        .font(.system(.headline, design: .rounded))

                    Text(letter.handDescription)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Finger positions
                fingerPositionSection

                // Practice button
                Button {
                    coordinator.navigateToPractice(with: [letter])
                } label: {
                    Label("Practice This Letter", systemImage: "play.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.indigo, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Letter \(letter.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: letter.rawValue) {
            referenceImage = loadReferenceImage()
        }
    }

    private var fingerPositionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Finger Positions", systemImage: "hand.point.up.left.fill")
                .font(.system(.headline, design: .rounded))

            ForEach(Finger.allCases) { finger in
                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)

                    Text(finger.displayName)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .frame(width: 60, alignment: .leading)

                    Text(fingerHint(for: finger))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var referenceImageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hand Reference", systemImage: "photo")
                .font(.system(.headline, design: .rounded))

            if let image = referenceImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .padding(8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Reference image unavailable for this letter.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func loadReferenceImage() -> UIImage? {
        let name = letter.displayName
        var candidateBundles: [Bundle] = []

        #if SWIFT_PACKAGE
        candidateBundles.append(.module)
        #endif

        candidateBundles.append(.main)
        candidateBundles.append(contentsOf: Bundle.allBundles)
        candidateBundles.append(contentsOf: Bundle.allFrameworks)

        for bundle in candidateBundles {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                return image
            }

            if let url = bundle.url(forResource: name, withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }

            if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "ASLImages"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }

            if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "Supporting/ASLImages"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        return nil
    }

    private func fingerHint(for finger: Finger) -> String {
        // Simplified finger hints derived from the letter's hand description
        // These will be enhanced with actual ReferencePoseData in Phase 2
        switch (letter, finger) {
        case (.a, .thumb): return "Alongside index"
        case (.a, _): return "Curled into fist"
        case (.b, .thumb): return "Tucked across palm"
        case (.b, _): return "Extended straight up"
        case (.c, _): return "Curved into C shape"
        case (.d, .index): return "Extended straight up"
        case (.d, .thumb): return "Touching middle finger"
        case (.d, _): return "Curled down"
        case (.l, .index): return "Extended straight up"
        case (.l, .thumb): return "Extended sideways"
        case (.l, _): return "Curled into fist"
        case (.v, .index), (.v, .middle): return "Extended apart"
        case (.v, _): return "Curled down"
        case (_, .thumb): return "Natural position"
        case (_, _): return "See description above"
        }
    }
}
