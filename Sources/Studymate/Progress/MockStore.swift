import Foundation
import Observation

/// One answered problem inside a mock exam.
struct MockAnswer: Codable, Equatable {
    let number: Int
    let chosen: String?
    let correct: Bool?
    /// Seconds the problem was on screen (app mode only).
    let seconds: Double
    var fields: [Field] = []
    var lesson: String?
    /// Scratch pad used on this problem, when it has content.
    var scratchID: UUID? = nil
}

/// A finished mock exam (app set or a paper past paper).
struct MockResult: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case app, paper }

    var id = UUID()
    let kind: Kind
    /// "set1" or "2019" for paper mode.
    let source: String
    let title: String
    let date: Date
    let score: Int
    let total: Int
    /// Seconds actually used (≤ 2400).
    let seconds: Double
    let answers: [MockAnswer]

    var accuracy: Double { total > 0 ? Double(score) / Double(total) : 0 }

    /// Time per band segment (1~10 / 11~20 / 21~25).
    var segmentSeconds: [Double] {
        var s = [0.0, 0.0, 0.0]
        for a in answers {
            let i = a.number <= 10 ? 0 : a.number <= 20 ? 1 : 2
            s[i] += a.seconds
        }
        return s
    }

    static let segmentGuide: [Double] = [600, 900, 900]
    static let segmentTitles = ["1~10번", "11~20번", "21~25번"]
}

/// 실전 모의고사 기록, persisted in mocks.json.
@MainActor
@Observable
final class MockStore {
    private(set) var results: [MockResult] = []
    private let file = JSONFile<[MockResult]>(name: "mocks.json")

    init() {
        results = file.load() ?? []
    }

    func record(_ result: MockResult) {
        results.append(result)
        save()
    }

    func remove(id: UUID) {
        results.removeAll { $0.id == id }
        save()
    }

    func results(source: String) -> [MockResult] {
        results.filter { $0.source == source }.sorted { $0.date > $1.date }
    }

    var sortedByDate: [MockResult] { results.sorted { $0.date > $1.date } }

    private func save() { file.save(results) }
    func flush() { file.flush() }
}
