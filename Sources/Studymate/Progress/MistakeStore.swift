import Foundation
import Observation

enum MistakeSource: Codable, Equatable, Hashable {
    case problem(id: String, lesson: String)
    case pastPaper(year: Int, number: Int)

    var title: String {
        switch self {
        case .problem(let id, _): return "레슨 문제 \(id)"
        case .pastPaper(let year, let number): return "\(year) AMC 8 \(number)번"
        }
    }
}

struct ReviewRecord: Codable, Equatable {
    let date: Date
    let correct: Bool
}

/// One mistake-notebook entry with its spaced-repetition state.
struct MistakeEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    let source: MistakeSource
    var fields: [Field]
    var reason: StuckReason
    /// 핵심 아이디어 한 줄
    var keyIdea: String
    /// 내 풀이 메모
    var myNote: String
    /// 0 → 1 day, 1 → 3 days, 2 → 7 days, 3 → 14 days; passing stage 3 graduates the entry.
    var stage: Int = 0
    var nextReview: Date
    var createdAt: Date
    var reviews: [ReviewRecord] = []
    var graduated = false

    static let intervals = [1, 3, 7, 14]

    var isDue: Bool { !graduated && nextReview <= Date() }
    var intervalDays: Int { MistakeEntry.intervals[min(stage, MistakeEntry.intervals.count - 1)] }

    var problemID: String? {
        if case .problem(let id, _) = source { return id }
        return nil
    }

    var lessonID: String? {
        if case .problem(_, let lesson) = source { return lesson }
        return nil
    }
}

/// 오답노트. Persisted in mistakes.json.
@MainActor
@Observable
final class MistakeStore {
    private(set) var entries: [MistakeEntry] = []
    private let file = JSONFile<[MistakeEntry]>(name: "mistakes.json")

    init() {
        entries = file.load() ?? []
    }

    func entry(for source: MistakeSource) -> MistakeEntry? {
        entries.first { $0.source == source && !$0.graduated }
    }

    /// Adds a new entry, or refreshes an existing (non-graduated) one for the same source: back to stage 0, due tomorrow.
    @discardableResult
    func add(source: MistakeSource, fields: [Field], reason: StuckReason, keyIdea: String, myNote: String = "") -> MistakeEntry {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        if let i = entries.firstIndex(where: { $0.source == source && !$0.graduated }) {
            entries[i].reason = reason
            if !keyIdea.isEmpty { entries[i].keyIdea = keyIdea }
            if !myNote.isEmpty { entries[i].myNote = myNote }
            entries[i].fields = fields
            entries[i].stage = 0
            entries[i].nextReview = tomorrow
            save()
            return entries[i]
        }
        let entry = MistakeEntry(source: source, fields: fields, reason: reason, keyIdea: keyIdea, myNote: myNote,
                                 stage: 0, nextReview: tomorrow, createdAt: Date())
        entries.append(entry)
        save()
        return entry
    }

    /// Correct without looking at the solution → next stage (14-day stage passed → graduated); wrong → back to 1 day.
    func recordReview(id: UUID, correct: Bool) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].reviews.append(ReviewRecord(date: Date(), correct: correct))
        let today = Calendar.current.startOfDay(for: Date())
        if correct {
            if entries[i].stage >= MistakeEntry.intervals.count - 1 {
                entries[i].graduated = true
            } else {
                entries[i].stage += 1
                entries[i].nextReview = Calendar.current.date(byAdding: .day, value: entries[i].intervalDays, to: today)!
            }
        } else {
            entries[i].stage = 0
            entries[i].nextReview = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        }
        save()
    }

    func update(id: UUID, keyIdea: String? = nil, myNote: String? = nil, reason: StuckReason? = nil, fields: [Field]? = nil) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        if let keyIdea { entries[i].keyIdea = keyIdea }
        if let myNote { entries[i].myNote = myNote }
        if let reason { entries[i].reason = reason }
        if let fields { entries[i].fields = fields }
        save()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    var active: [MistakeEntry] { entries.filter { !$0.graduated } }
    var due: [MistakeEntry] { entries.filter(\.isDue).sorted { $0.nextReview < $1.nextReview } }
    var graduated: [MistakeEntry] { entries.filter(\.graduated) }

    /// Fields with the most new mistakes in the last 7 days, strongest first.
    func weakFields(days: Int = 7, limit: Int = 2) -> [(field: Field, count: Int)] {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        var counts: [Field: Int] = [:]
        for e in entries {
            let recentFail = e.createdAt >= since || e.reviews.contains { $0.date >= since && !$0.correct }
            guard recentFail else { continue }
            for f in e.fields { counts[f, default: 0] += 1 }
        }
        return counts.sorted { ($0.value, $0.key.rawValue) > ($1.value, $1.key.rawValue) }.prefix(limit).map { (field: $0.key, count: $0.value) }
    }

    private func save() { file.save(entries) }
    func flush() { file.flush() }
}
