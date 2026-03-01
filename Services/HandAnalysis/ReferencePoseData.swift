import Foundation

// MARK: - Reference Pose Entry

struct ReferencePoseEntry: Sendable {
    let letter: ASLLetter
    let fingerAngles: FingerAngles
    let tolerance: Float

    /// Expected state for each finger
    let expectedStates: [Finger: ExpectedFingerState]
    let constraints: LetterConstraints
    let motionRequirement: MotionRequirement

    init(
        letter: ASLLetter,
        fingerAngles: FingerAngles,
        tolerance: Float,
        expectedStates: [Finger: ExpectedFingerState],
        constraints: LetterConstraints = .none,
        motionRequirement: MotionRequirement = .staticPose
    ) {
        self.letter = letter
        self.fingerAngles = fingerAngles
        self.tolerance = tolerance
        self.expectedStates = expectedStates
        self.constraints = constraints
        self.motionRequirement = motionRequirement
    }
}

// MARK: - Expected Finger State

enum ExpectedFingerState: Sendable, Equatable {
    case extended       // Finger straight (PIP ~145-175°)
    case curled         // Finger fully curled (PIP ~30-70°)
    case bent           // Partially bent (PIP ~80-120°)
    case hooked         // Only DIP bent, PIP relatively straight
    case touchingThumb  // Tip touching thumb tip

    var description: String {
        switch self {
        case .extended: return "Extended straight"
        case .curled: return "Curled into fist"
        case .bent: return "Partially bent"
        case .hooked: return "Hooked at tip"
        case .touchingThumb: return "Touching thumb"
        }
    }
}

enum MotionRequirement: Sendable, Equatable {
    case staticPose
    case jTrace
    case zTrace
}

struct FingerPair: Hashable, Sendable {
    let a: Finger
    let b: Finger

    static let thumbIndex = FingerPair(a: .thumb, b: .index)
    static let thumbMiddle = FingerPair(a: .thumb, b: .middle)
    static let indexMiddle = FingerPair(a: .index, b: .middle)
    static let middleRing = FingerPair(a: .middle, b: .ring)
    static let ringLittle = FingerPair(a: .ring, b: .little)
}

struct LetterConstraints: Sendable {
    let requiredStates: [Finger: ExpectedFingerState]
    let forbiddenStates: [Finger: ExpectedFingerState]
    let requiredTouches: [FingerPair]
    let minTipDistance: [FingerPair: Float]
    let maxTipDistance: [FingerPair: Float]

    static let none = LetterConstraints(
        requiredStates: [:],
        forbiddenStates: [:],
        requiredTouches: [],
        minTipDistance: [:],
        maxTipDistance: [:]
    )
}

// MARK: - Finger Angles
// All angles are 2D image-plane angles in degrees as reported by Vision.
// ~160-175° = straight finger, ~40-70° = curled, ~90-120° = bent.
// Spread angles: ~5° = fingers together, ~20-40° = spread apart.

struct FingerAngles: Sendable {
    let thumbCurl: Float
    let indexCurl: Float
    let middleCurl: Float
    let ringCurl: Float
    let littleCurl: Float

    let thumbIndexSpread: Float
    let indexMiddleSpread: Float
    let middleRingSpread: Float
    let ringLittleSpread: Float

    func curlAngle(for finger: Finger) -> Float {
        switch finger {
        case .thumb: return thumbCurl
        case .index: return indexCurl
        case .middle: return middleCurl
        case .ring: return ringCurl
        case .little: return littleCurl
        }
    }

    func spreadAngle(for finger: Finger) -> Float? {
        switch finger {
        case .thumb: return thumbIndexSpread
        case .index: return indexMiddleSpread
        case .middle: return middleRingSpread
        case .ring: return ringLittleSpread
        case .little: return nil
        }
    }
}

// MARK: - Reference Pose Data

enum ReferencePoseData {
    static let poses: [ASLLetter: ReferencePoseEntry] = {
        var dict: [ASLLetter: ReferencePoseEntry] = [:]
        for entry in allPoses {
            dict[entry.letter] = entry
        }
        return dict
    }()

    // ──────────────────────────────────────────────
    // Reference values tuned for Vision 2D image-plane angles.
    //
    // Curl angle convention  (measured at PIP / MP for thumb):
    //   ~160-170° straight / extended
    //   ~90-120° partially bent
    //   ~40-70°  fully curled
    //
    // Tolerance is per-letter; the PoseComparer subtracts it
    // before applying the correct/close/incorrect thresholds.
    // ──────────────────────────────────────────────

    private static let allPoses: [ReferencePoseEntry] = [

        // ── Level 1: Fist Letters ──────────────────

        // A: Fist with thumb alongside
        ReferencePoseEntry(
            letter: .a,
            fingerAngles: FingerAngles(
                thumbCurl: 150, indexCurl: 55, middleCurl: 55,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 8, indexMiddleSpread: 5,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .extended, .index: .curled, .middle: .curled,
                .ring: .curled, .little: .curled
            ]
        ),

        // E: Fingers curled, thumb tucked under
        ReferencePoseEntry(
            letter: .e,
            fingerAngles: FingerAngles(
                thumbCurl: 70, indexCurl: 55, middleCurl: 55,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 5, indexMiddleSpread: 5,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .curled, .index: .curled, .middle: .curled,
                .ring: .curled, .little: .curled
            ]
        ),

        // M: Thumb under first three fingers
        ReferencePoseEntry(
            letter: .m,
            fingerAngles: FingerAngles(
                thumbCurl: 60, indexCurl: 60, middleCurl: 60,
                ringCurl: 60, littleCurl: 55,
                thumbIndexSpread: 5, indexMiddleSpread: 8,
                middleRingSpread: 8, ringLittleSpread: 5
            ),
            tolerance: 28,
            expectedStates: [
                .thumb: .curled, .index: .curled, .middle: .curled,
                .ring: .curled, .little: .curled
            ]
        ),

        // N: Thumb under first two fingers
        ReferencePoseEntry(
            letter: .n,
            fingerAngles: FingerAngles(
                thumbCurl: 60, indexCurl: 60, middleCurl: 60,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 5, indexMiddleSpread: 8,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 28,
            expectedStates: [
                .thumb: .curled, .index: .curled, .middle: .curled,
                .ring: .curled, .little: .curled
            ]
        ),

        // S: Fist with thumb across fingers
        ReferencePoseEntry(
            letter: .s,
            fingerAngles: FingerAngles(
                thumbCurl: 110, indexCurl: 50, middleCurl: 50,
                ringCurl: 50, littleCurl: 50,
                thumbIndexSpread: 5, indexMiddleSpread: 5,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .bent, .index: .curled, .middle: .curled,
                .ring: .curled, .little: .curled
            ]
        ),

        // T: Thumb between index and middle, fist
        ReferencePoseEntry(
            letter: .t,
            fingerAngles: FingerAngles(
                thumbCurl: 100, indexCurl: 55, middleCurl: 55,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 12, indexMiddleSpread: 8,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 28,
            expectedStates: [
                .thumb: .bent, .index: .curled, .middle: .curled,
                .ring: .curled, .little: .curled
            ]
        ),

        // ── Level 2: Point Letters ─────────────────

        // B: Flat hand, fingers extended, thumb tucked
        ReferencePoseEntry(
            letter: .b,
            fingerAngles: FingerAngles(
                thumbCurl: 60, indexCurl: 160, middleCurl: 160,
                ringCurl: 160, littleCurl: 160,
                thumbIndexSpread: 5, indexMiddleSpread: 5,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 22,
            expectedStates: [
                .thumb: .curled, .index: .extended, .middle: .extended,
                .ring: .extended, .little: .extended
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .thumb: .curled, .index: .extended, .middle: .extended,
                    .ring: .extended, .little: .extended
                ],
                forbiddenStates: [:],
                requiredTouches: [],
                minTipDistance: [:],
                maxTipDistance: [.thumbIndex: 0.33]
            )
        ),

        // D: Index up, others curled, thumb touches middle
        ReferencePoseEntry(
            letter: .d,
            fingerAngles: FingerAngles(
                thumbCurl: 90, indexCurl: 165, middleCurl: 55,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 15, indexMiddleSpread: 15,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .bent, .index: .extended, .middle: .curled,
                .ring: .curled, .little: .curled
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .index: .extended, .middle: .curled, .ring: .curled, .little: .curled
                ],
                forbiddenStates: [:],
                requiredTouches: [.thumbMiddle],
                minTipDistance: [:],
                maxTipDistance: [:]
            )
        ),

        // G: Index and thumb point sideways, others curled
        ReferencePoseEntry(
            letter: .g,
            fingerAngles: FingerAngles(
                thumbCurl: 155, indexCurl: 155, middleCurl: 55,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 35, indexMiddleSpread: 12,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 28,
            expectedStates: [
                .thumb: .extended, .index: .extended, .middle: .curled,
                .ring: .curled, .little: .curled
            ]
        ),

        // I: Pinky extended, others curled
        ReferencePoseEntry(
            letter: .i,
            fingerAngles: FingerAngles(
                thumbCurl: 100, indexCurl: 55, middleCurl: 55,
                ringCurl: 55, littleCurl: 160,
                thumbIndexSpread: 5, indexMiddleSpread: 5,
                middleRingSpread: 5, ringLittleSpread: 20
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .bent, .index: .curled, .middle: .curled,
                .ring: .curled, .little: .extended
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .index: .curled, .middle: .curled, .ring: .curled, .little: .extended
                ],
                forbiddenStates: [.thumb: .extended],
                requiredTouches: [],
                minTipDistance: [.ringLittle: 0.22],
                maxTipDistance: [:]
            )
        ),

        // L: L shape with index and thumb
        ReferencePoseEntry(
            letter: .l,
            fingerAngles: FingerAngles(
                thumbCurl: 160, indexCurl: 165, middleCurl: 55,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 60, indexMiddleSpread: 12,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .extended, .index: .extended, .middle: .curled,
                .ring: .curled, .little: .curled
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .thumb: .extended, .index: .extended, .middle: .curled, .ring: .curled, .little: .curled
                ],
                forbiddenStates: [:],
                requiredTouches: [],
                minTipDistance: [.thumbIndex: 0.35],
                maxTipDistance: [:]
            )
        ),

        // R: Index and middle crossed/together extended
        ReferencePoseEntry(
            letter: .r,
            fingerAngles: FingerAngles(
                thumbCurl: 90, indexCurl: 160, middleCurl: 160,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 8, indexMiddleSpread: 3,
                middleRingSpread: 12, ringLittleSpread: 5
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .bent, .index: .extended, .middle: .extended,
                .ring: .curled, .little: .curled
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .index: .extended, .middle: .extended, .ring: .curled, .little: .curled
                ],
                forbiddenStates: [:],
                requiredTouches: [],
                minTipDistance: [:],
                maxTipDistance: [.indexMiddle: 0.16]
            )
        ),

        // ── Level 3: Open Hand ─────────────────────

        // C: Curved hand forming a C shape
        ReferencePoseEntry(
            letter: .c,
            fingerAngles: FingerAngles(
                thumbCurl: 140, indexCurl: 110, middleCurl: 110,
                ringCurl: 110, littleCurl: 110,
                thumbIndexSpread: 30, indexMiddleSpread: 8,
                middleRingSpread: 8, ringLittleSpread: 8
            ),
            tolerance: 30,
            expectedStates: [
                .thumb: .extended, .index: .bent, .middle: .bent,
                .ring: .bent, .little: .bent
            ]
        ),

        // F: Thumb and index form circle, other fingers extended
        ReferencePoseEntry(
            letter: .f,
            fingerAngles: FingerAngles(
                thumbCurl: 85, indexCurl: 80, middleCurl: 160,
                ringCurl: 160, littleCurl: 160,
                thumbIndexSpread: 5, indexMiddleSpread: 15,
                middleRingSpread: 8, ringLittleSpread: 8
            ),
            tolerance: 28,
            expectedStates: [
                .thumb: .touchingThumb, .index: .touchingThumb, .middle: .extended,
                .ring: .extended, .little: .extended
            ],
            constraints: LetterConstraints(
                requiredStates: [.middle: .extended, .ring: .extended, .little: .extended],
                forbiddenStates: [:],
                requiredTouches: [.thumbIndex],
                minTipDistance: [:],
                maxTipDistance: [.indexMiddle: 0.38]
            )
        ),

        // K: Index up, middle up, thumb between them
        ReferencePoseEntry(
            letter: .k,
            fingerAngles: FingerAngles(
                thumbCurl: 120, indexCurl: 165, middleCurl: 155,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 25, indexMiddleSpread: 20,
                middleRingSpread: 12, ringLittleSpread: 5
            ),
            tolerance: 28,
            expectedStates: [
                .thumb: .bent, .index: .extended, .middle: .extended,
                .ring: .curled, .little: .curled
            ]
        ),

        // O: Fingers curved into O touching thumb
        ReferencePoseEntry(
            letter: .o,
            fingerAngles: FingerAngles(
                thumbCurl: 100, indexCurl: 100, middleCurl: 100,
                ringCurl: 100, littleCurl: 100,
                thumbIndexSpread: 8, indexMiddleSpread: 5,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 30,
            expectedStates: [
                .thumb: .bent, .index: .bent, .middle: .bent,
                .ring: .bent, .little: .bent
            ]
        ),

        // U: Index and middle extended together
        ReferencePoseEntry(
            letter: .u,
            fingerAngles: FingerAngles(
                thumbCurl: 80, indexCurl: 165, middleCurl: 165,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 8, indexMiddleSpread: 5,
                middleRingSpread: 12, ringLittleSpread: 5
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .curled, .index: .extended, .middle: .extended,
                .ring: .curled, .little: .curled
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .index: .extended, .middle: .extended, .ring: .curled, .little: .curled
                ],
                forbiddenStates: [:],
                requiredTouches: [],
                minTipDistance: [:],
                maxTipDistance: [.indexMiddle: 0.14]
            )
        ),

        // V: Index and middle extended apart (peace sign)
        ReferencePoseEntry(
            letter: .v,
            fingerAngles: FingerAngles(
                thumbCurl: 80, indexCurl: 165, middleCurl: 165,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 8, indexMiddleSpread: 25,
                middleRingSpread: 12, ringLittleSpread: 5
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .curled, .index: .extended, .middle: .extended,
                .ring: .curled, .little: .curled
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .index: .extended, .middle: .extended, .ring: .curled, .little: .curled
                ],
                forbiddenStates: [:],
                requiredTouches: [],
                minTipDistance: [.indexMiddle: 0.20],
                maxTipDistance: [:]
            )
        ),

        // W: Index, middle, ring extended apart
        ReferencePoseEntry(
            letter: .w,
            fingerAngles: FingerAngles(
                thumbCurl: 65, indexCurl: 165, middleCurl: 165,
                ringCurl: 165, littleCurl: 55,
                thumbIndexSpread: 8, indexMiddleSpread: 18,
                middleRingSpread: 18, ringLittleSpread: 12
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .curled, .index: .extended, .middle: .extended,
                .ring: .extended, .little: .curled
            ]
        ),

        // ── Level 4: Complex ───────────────────────

        // H: Index and middle extend sideways
        ReferencePoseEntry(
            letter: .h,
            fingerAngles: FingerAngles(
                thumbCurl: 80, indexCurl: 165, middleCurl: 165,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 5, indexMiddleSpread: 5,
                middleRingSpread: 12, ringLittleSpread: 5
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .curled, .index: .extended, .middle: .extended,
                .ring: .curled, .little: .curled
            ]
        ),

        // J: Same base handshape as I, but requires a J motion trace.
        ReferencePoseEntry(
            letter: .j,
            fingerAngles: FingerAngles(
                thumbCurl: 100, indexCurl: 55, middleCurl: 55,
                ringCurl: 55, littleCurl: 160,
                thumbIndexSpread: 5, indexMiddleSpread: 5,
                middleRingSpread: 5, ringLittleSpread: 20
            ),
            tolerance: 28,
            expectedStates: [
                .thumb: .bent, .index: .curled, .middle: .curled,
                .ring: .curled, .little: .extended
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .index: .curled, .middle: .curled, .ring: .curled, .little: .extended
                ],
                forbiddenStates: [.thumb: .extended],
                requiredTouches: [],
                minTipDistance: [.ringLittle: 0.20],
                maxTipDistance: [:]
            ),
            motionRequirement: .jTrace
        ),

        // P: K handshape pointed downward
        ReferencePoseEntry(
            letter: .p,
            fingerAngles: FingerAngles(
                thumbCurl: 120, indexCurl: 155, middleCurl: 145,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 25, indexMiddleSpread: 18,
                middleRingSpread: 12, ringLittleSpread: 5
            ),
            tolerance: 30,
            expectedStates: [
                .thumb: .bent, .index: .extended, .middle: .extended,
                .ring: .curled, .little: .curled
            ]
        ),

        // Q: G handshape pointed downward
        ReferencePoseEntry(
            letter: .q,
            fingerAngles: FingerAngles(
                thumbCurl: 145, indexCurl: 145, middleCurl: 55,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 18, indexMiddleSpread: 12,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 30,
            expectedStates: [
                .thumb: .extended, .index: .extended, .middle: .curled,
                .ring: .curled, .little: .curled
            ]
        ),

        // X: Index finger hooked, others curled
        ReferencePoseEntry(
            letter: .x,
            fingerAngles: FingerAngles(
                thumbCurl: 90, indexCurl: 110, middleCurl: 55,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 8, indexMiddleSpread: 8,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 28,
            expectedStates: [
                .thumb: .bent, .index: .hooked, .middle: .curled,
                .ring: .curled, .little: .curled
            ]
        ),

        // Y: Thumb and pinky extended, others curled
        ReferencePoseEntry(
            letter: .y,
            fingerAngles: FingerAngles(
                thumbCurl: 160, indexCurl: 55, middleCurl: 55,
                ringCurl: 55, littleCurl: 160,
                thumbIndexSpread: 45, indexMiddleSpread: 5,
                middleRingSpread: 5, ringLittleSpread: 25
            ),
            tolerance: 25,
            expectedStates: [
                .thumb: .extended, .index: .curled, .middle: .curled,
                .ring: .curled, .little: .extended
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .thumb: .extended, .index: .curled, .middle: .curled, .ring: .curled, .little: .extended
                ],
                forbiddenStates: [:],
                requiredTouches: [],
                minTipDistance: [.thumbIndex: 0.22, .ringLittle: 0.20],
                maxTipDistance: [:]
            )
        ),

        // Z: Index extended with a required Z motion trace.
        ReferencePoseEntry(
            letter: .z,
            fingerAngles: FingerAngles(
                thumbCurl: 90, indexCurl: 165, middleCurl: 55,
                ringCurl: 55, littleCurl: 55,
                thumbIndexSpread: 12, indexMiddleSpread: 12,
                middleRingSpread: 5, ringLittleSpread: 5
            ),
            tolerance: 28,
            expectedStates: [
                .thumb: .bent, .index: .extended, .middle: .curled,
                .ring: .curled, .little: .curled
            ],
            constraints: LetterConstraints(
                requiredStates: [
                    .index: .extended, .middle: .curled, .ring: .curled, .little: .curled
                ],
                forbiddenStates: [:],
                requiredTouches: [],
                minTipDistance: [:],
                maxTipDistance: [:]
            ),
            motionRequirement: .zTrace
        ),
    ]
}
