import Foundation
import Observation

enum PaperStatus: String, Codable, CaseIterable, Identifiable {
    case unsolved, correct, wrong, slow, guessed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unsolved: return "안 풂"
        case .correct: return "맞음"
        case .wrong: return "틀림"
        case .slow: return "오래 걸림"
        case .guessed: return "찍어서 맞음"
        }
    }

    var icon: String {
        switch self {
        case .unsolved: return "circle.dotted"
        case .correct: return "checkmark"
        case .wrong: return "xmark"
        case .slow: return "clock"
        case .guessed: return "questionmark"
        }
    }

    /// Statuses that belong in the mistake notebook.
    var needsReview: Bool { self == .wrong || self == .slow || self == .guessed }
}

struct PaperCell: Codable, Equatable {
    var status: PaperStatus = .unsolved
    var seconds: Int?
    var fields: [Field] = []
    var note: String = ""
    var sentToNotebook = false
    var updatedAt: Date?
}

struct PastPaperData: Codable {
    var cells: [String: PaperCell] = [:]
    var reservedLocked = true
}

/// 기출 트래커: one cell per (year, problem number). AMC 8 2000–2023 except 2021 (no contest that year: the
/// MAA moved the AMC 8 to January starting with the 2022 contest). 2024–2026 are kept for mock exams behind a lock.
@MainActor
@Observable
final class PastPaperStore {
    static let years: [Int] = Array(2000...2020) + [2022, 2023]
    static let reservedYears: [Int] = [2024, 2025, 2026]
    static let problemCount = 25

    private(set) var data: PastPaperData
    private let file = JSONFile<PastPaperData>(name: "pastpapers.json")

    init() {
        data = file.load() ?? PastPaperData()
    }

    static func key(year: Int, number: Int) -> String { "\(year)-\(number)" }

    static func aopsURL(year: Int, number: Int) -> URL {
        URL(string: "https://artofproblemsolving.com/wiki/index.php/\(year)_AMC_8_Problems/Problem_\(number)")!
    }

    var reservedLocked: Bool {
        get { data.reservedLocked }
        set { data.reservedLocked = newValue; save() }
    }

    var visibleYears: [Int] { reservedLocked ? Self.years : Self.years + Self.reservedYears }

    func cell(year: Int, number: Int) -> PaperCell {
        data.cells[Self.key(year: year, number: number)] ?? PaperCell()
    }

    func update(year: Int, number: Int, _ change: (inout PaperCell) -> Void) {
        var cell = self.cell(year: year, number: number)
        change(&cell)
        cell.updatedAt = Date()
        data.cells[Self.key(year: year, number: number)] = cell
        save()
    }

    func cells(year: Int) -> [PaperCell] {
        (1...Self.problemCount).map { cell(year: year, number: $0) }
    }

    /// Cells that are wrong / slow / guessed and not yet in the notebook.
    var pendingForNotebook: [(year: Int, number: Int, cell: PaperCell)] {
        var out: [(Int, Int, PaperCell)] = []
        for (key, cell) in data.cells where cell.status.needsReview && !cell.sentToNotebook {
            let parts = key.split(separator: "-")
            if parts.count == 2, let y = Int(parts[0]), let n = Int(parts[1]) { out.append((y, n, cell)) }
        }
        return out.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map { (year: $0.0, number: $0.1, cell: $0.2) }
    }

    var solvedCount: Int { data.cells.values.filter { $0.status != .unsolved }.count }

    private func save() { file.save(data) }
    func flush() { file.flush() }
}
