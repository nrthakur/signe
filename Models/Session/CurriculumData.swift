import Foundation

// MARK: - Lesson

struct Lesson: Identifiable, Sendable {
    let id: Int
    let title: String
    let description: String
    let tier: DifficultyTier
    let letters: [ASLLetter]
    let requiredAccuracy: Float
    let unlockRequirement: Int? // ID of lesson that must be completed first (nil = always unlocked)
}

// MARK: - Curriculum Data

enum CurriculumData {
    static let lessons: [Lesson] = [
        // Level 1: Fist Letters — default unlocked
        Lesson(
            id: 1,
            title: "The Fist Family",
            description: "Letters made with a closed fist. Start here!",
            tier: .fistLetters,
            letters: [.a, .e, .m, .n, .s, .t],
            requiredAccuracy: 0.70,
            unlockRequirement: nil
        ),

        // Level 2: Point Letters
        Lesson(
            id: 2,
            title: "Point & Direct",
            description: "Letters using pointed or extended fingers",
            tier: .pointLetters,
            letters: [.b, .d, .g, .i, .l, .r],
            requiredAccuracy: 0.70,
            unlockRequirement: 1
        ),

        // Level 3: Open Hand
        Lesson(
            id: 3,
            title: "Open Hand Shapes",
            description: "Letters with open palm and curved fingers",
            tier: .openHand,
            letters: [.c, .f, .k, .o, .u, .v, .w],
            requiredAccuracy: 0.75,
            unlockRequirement: 2
        ),

        // Level 4: Complex
        Lesson(
            id: 4,
            title: "Complex Shapes",
            description: "Advanced finger positions and orientations",
            tier: .complex,
            letters: [.h, .j, .p, .q, .x, .y, .z],
            requiredAccuracy: 0.75,
            unlockRequirement: 3
        ),

        // Level 5: Full Alphabet Review
        Lesson(
            id: 5,
            title: "Full Alphabet",
            description: "All 26 letters mixed together",
            tier: .complex,
            letters: ASLLetter.allCases,
            requiredAccuracy: 0.80,
            unlockRequirement: 4
        ),

        // Level 6: Speed Challenge
        Lesson(
            id: 6,
            title: "Speed Round",
            description: "Sign as fast as you can — beat the clock!",
            tier: .complex,
            letters: ASLLetter.allCases,
            requiredAccuracy: 0.70,
            unlockRequirement: 5
        ),
    ]

    static func lesson(withID id: Int) -> Lesson? {
        lessons.first { $0.id == id }
    }
}
