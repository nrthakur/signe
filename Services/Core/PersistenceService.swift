import Foundation

// MARK: - Persistence Service

actor PersistenceService {
    static let shared = PersistenceService()

    private let documentsURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Cached data
    private var cachedProgress: UserProgress?
    private var cachedRecords: [ProgressRecord]?

    init() {
        documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Progress Records

    func saveRecord(_ record: ProgressRecord) throws {
        var records = loadRecordsSync()
        records.append(record)
        try writeToDisk(records, filename: "progress_records.json")
        cachedRecords = records
    }

    func saveRecords(_ newRecords: [ProgressRecord]) throws {
        var records = loadRecordsSync()
        records.append(contentsOf: newRecords)
        try writeToDisk(records, filename: "progress_records.json")
        cachedRecords = records
    }

    func loadRecords() -> [ProgressRecord] {
        if let cached = cachedRecords { return cached }
        let records = loadRecordsSync()
        cachedRecords = records
        return records
    }

    private func loadRecordsSync() -> [ProgressRecord] {
        (try? readFromDisk(filename: "progress_records.json")) ?? []
    }

    // MARK: - User Progress

    func loadUserProgress() -> UserProgress {
        if let cached = cachedProgress { return cached }
        let progress: UserProgress = (try? readFromDisk(filename: "user_progress.json")) ?? UserProgress()
        cachedProgress = progress
        return progress
    }

    func saveUserProgress(_ progress: UserProgress) throws {
        try writeToDisk(progress, filename: "user_progress.json")
        cachedProgress = progress
    }

    func updateUserProgress(_ update: @Sendable (inout UserProgress) -> Void) throws {
        var progress = loadUserProgress()
        update(&progress)
        try saveUserProgress(progress)
    }

    // MARK: - Letter Stats

    func computeLetterStats() -> [ASLLetter: LetterStats] {
        let records = loadRecords()
        var stats: [ASLLetter: LetterStats] = [:]

        for letter in ASLLetter.allCases {
            var letterStat = LetterStats.empty(letter: letter)
            let letterRecords = records.filter { $0.letter == letter }

            letterStat.totalAttempts = letterRecords.count
            letterStat.correctCount = letterRecords.filter { $0.matched }.count

            if !letterRecords.isEmpty {
                letterStat.averageAccuracy = letterRecords.map(\.accuracy).reduce(0, +) / Float(letterRecords.count)

                // Compute EMA
                var ema: Float = 0.5
                for record in letterRecords {
                    ema = 0.3 * record.accuracy + 0.7 * ema
                }
                letterStat.ema = ema
            }

            stats[letter] = letterStat
        }

        return stats
    }

    // MARK: - Generic JSON Helpers

    private func writeToDisk<T: Encodable>(_ value: T, filename: String) throws {
        let url = documentsURL.appendingPathComponent(filename)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func readFromDisk<T: Decodable>(filename: String) throws -> T? {
        let url = documentsURL.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Reset (for testing)

    func resetAllData() throws {
        let filenames = ["progress_records.json", "user_progress.json"]
        for filename in filenames {
            let url = documentsURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
        cachedProgress = nil
        cachedRecords = nil
    }
}
