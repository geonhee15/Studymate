import Foundation
import Observation

enum StuckReason: String, Codable, CaseIterable, Identifiable {
    case concept, idea, calculation, misread

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concept: return "개념 몰랐음"
        case .idea: return "아이디어 안 떠오름"
        case .calculation: return "계산 실수"
        case .misread: return "문제 잘못 읽음"
        }
    }

    var icon: String {
        switch self {
        case .concept: return "book.closed"
        case .idea: return "lightbulb.slash"
        case .calculation: return "plus.forwardslash.minus"
        case .misread: return "eyeglasses"
        }
    }
}

/// One answered problem.
struct Attempt: Codable, Identifiable, Equatable {
    var id = UUID()
    let problemID: String
    let lesson: String
    let unit: Int
    let kind: ProblemSetKind
    let chosen: String
    let correct: Bool
    let seconds: Double
    let targetSeconds: Int
    let hintsUsed: Int
    let guessed: Bool
    let date: Date
    var reason: StuckReason?
    var fields: [Field] = []
    /// Scratch pad of this attempt (scratch/<problemID>/<id>.json), when one was saved.
    var scratchID: UUID? = nil

    var overTarget: Bool { seconds > Double(targetSeconds) }
    /// Wrong, too slow, or guessed → goes to the mistake notebook.
    var needsReview: Bool { !correct || overTarget || guessed }
}

/// A finished quiz / test / mock.
struct SetResult: Codable, Identifiable, Equatable {
    var id = UUID()
    let unit: Int
    let kind: ProblemSetKind
    let score: Int
    let total: Int
    let date: Date
    let seconds: Double
    var passed: Bool { MasteryEngine.passed(kind: kind, score: score, total: total) }
}

struct ProgressData: Codable {
    var attempts: [Attempt] = []
    var results: [SetResult] = []
    var lastLessonID: String?
    var lastOpened: [String: Date] = [:]
}

/// Everything the learner has done, persisted in ~/Library/Application Support/Studymate/progress.json.
@MainActor
@Observable
final class ProgressStore {
    private(set) var data: ProgressData
    private let file = JSONFile<ProgressData>(name: "progress.json")

    init() {
        data = file.load() ?? ProgressData()
    }

    var attempts: [Attempt] { data.attempts }
    var results: [SetResult] { data.results }
    var lastLessonID: String? { data.lastLessonID }

    func record(_ attempt: Attempt) {
        data.attempts.append(attempt)
        save()
    }

    func updateReason(attemptID: UUID, reason: StuckReason) {
        if let i = data.attempts.firstIndex(where: { $0.id == attemptID }) {
            data.attempts[i].reason = reason
            save()
        }
    }

    func record(_ result: SetResult) {
        data.results.append(result)
        save()
    }

    func markOpened(lesson id: String) {
        data.lastLessonID = id
        data.lastOpened[id] = Date()
        save()
    }

    func reset() {
        data = ProgressData()
        save()
    }

    // MARK: Derived

    func attempts(lesson id: String) -> [Attempt] { data.attempts.filter { $0.lesson == id } }

    func mastery(lesson: Lesson) -> MasteryLevel {
        MasteryEngine.level(lessonID: lesson.id, unit: lesson.unit, attempts: data.attempts, results: data.results)
    }

    func mastery(lessonID: String, unit: Int) -> MasteryLevel {
        MasteryEngine.level(lessonID: lessonID, unit: unit, attempts: data.attempts, results: data.results)
    }

    /// 0...1 average of lesson levels in a unit.
    func unitProgress(_ unit: Unit) -> Double {
        guard !unit.lessons.isEmpty else { return 0 }
        let total = unit.lessons.map { Double(mastery(lesson: $0).rawValue) }.reduce(0, +)
        return total / Double(unit.lessons.count * MasteryLevel.mastered.rawValue)
    }

    func recentAccuracy(lessonID: String) -> Double? {
        MasteryEngine.recentAccuracy(lessonID: lessonID, attempts: data.attempts)
    }

    func bestResult(unit: Int, kind: ProblemSetKind) -> SetResult? {
        data.results.filter { $0.unit == unit && $0.kind == kind }.max { ($0.score, $0.date) < ($1.score, $1.date) }
    }

    func lastResult(unit: Int, kind: ProblemSetKind) -> SetResult? {
        data.results.filter { $0.unit == unit && $0.kind == kind }.max { $0.date < $1.date }
    }

    /// Problems answered correctly at least once (practice), used to pick fresh ones first.
    func solvedProblemIDs() -> Set<String> {
        Set(data.attempts.filter(\.correct).map(\.problemID))
    }

    var attemptsToday: [Attempt] {
        data.attempts.filter { Calendar.current.isDateInToday($0.date) }
    }

    private func save() { file.save(data) }
    func flush() { file.flush() }
}
