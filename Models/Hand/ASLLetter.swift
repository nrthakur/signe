import SwiftUI

// MARK: - ASL Letter Enum

enum ASLLetter: String, CaseIterable, Codable, Sendable, Identifiable {
    case a, b, c, d, e, f, g, h, i, j,
         k, l, m, n, o, p, q, r, s, t,
         u, v, w, x, y, z

    var id: String { rawValue }

    var displayName: String { rawValue.uppercased() }

    var sfSymbol: String { "\(rawValue).circle.fill" }

    var difficulty: DifficultyTier {
        switch self {
        case .a, .e, .m, .n, .s, .t:
            return .fistLetters
        case .b, .d, .g, .i, .l, .r:
            return .pointLetters
        case .c, .f, .k, .o, .u, .v, .w:
            return .openHand
        case .h, .j, .p, .q, .x, .y, .z:
            return .complex
        }
    }

    /// Short description of the hand shape for this letter
    var handDescription: String {
        switch self {
        case .a: return "Fist with thumb alongside index finger"
        case .b: return "Flat hand, fingers together, thumb tucked"
        case .c: return "Curved hand forming a C shape"
        case .d: return "Index finger up, others curled, thumb touches middle"
        case .e: return "Fingers curled down, thumb tucked under"
        case .f: return "Index and thumb form circle, other fingers extended"
        case .g: return "Index and thumb point sideways, others curled"
        case .h: return "Index and middle extend sideways, others curled"
        case .i: return "Pinky extended, others curled, thumb across"
        case .j: return "Pinky extended, trace J motion downward"
        case .k: return "Index and middle up in V, thumb between them"
        case .l: return "L shape with index and thumb"
        case .m: return "Thumb under first three fingers"
        case .n: return "Thumb under first two fingers"
        case .o: return "Fingers curved into O shape touching thumb"
        case .p: return "K handshape pointed downward"
        case .q: return "G handshape pointed downward"
        case .r: return "Index and middle crossed"
        case .s: return "Fist with thumb across fingers"
        case .t: return "Thumb between index and middle, fist"
        case .u: return "Index and middle extended together"
        case .v: return "Index and middle extended apart (peace sign)"
        case .w: return "Index, middle, ring extended apart"
        case .x: return "Index finger hooked, others curled"
        case .y: return "Thumb and pinky extended, others curled"
        case .z: return "Index finger traces Z shape in air"
        }
    }
}

// MARK: - Difficulty Tier

enum DifficultyTier: Int, Codable, Sendable, Comparable, CaseIterable {
    case fistLetters = 1
    case pointLetters = 2
    case openHand = 3
    case complex = 4

    static func < (lhs: DifficultyTier, rhs: DifficultyTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .fistLetters: return "Fist Letters"
        case .pointLetters: return "Point Letters"
        case .openHand: return "Open Hand"
        case .complex: return "Complex"
        }
    }

    var difficultyLabel: String {
        switch self {
        case .fistLetters: return "Easy"
        case .pointLetters: return "Medium"
        case .openHand: return "Hard"
        case .complex: return "Hardest"
        }
    }

    var color: Color {
        switch self {
        case .fistLetters: return .green
        case .pointLetters: return .teal
        case .openHand: return .orange
        case .complex: return .red
        }
    }
}
