import Foundation

/// Subjects shown in the top tab bar. Add a case here and a view in RootView to add a subject.
enum Subject: String, CaseIterable, Identifiable {
    case amc8

    var id: String { rawValue }

    var title: String {
        switch self {
        case .amc8: return "AMC 8"
        }
    }

    var icon: String {
        switch self {
        case .amc8: return "function"
        }
    }

    /// Folder under Resources/Content.
    var contentFolder: String { rawValue }
}

/// Problem difficulty shown as the AMC number range it would appear in.
enum Band: String, Codable, CaseIterable, Comparable {
    case easy = "1-10"
    case medium = "11-15"
    case hard = "16-20"
    case hardest = "21-25"

    var title: String {
        switch self {
        case .easy: return "1~10번"
        case .medium: return "11~15번"
        case .hard: return "16~20번"
        case .hardest: return "21~25번"
        }
    }

    var short: String {
        switch self {
        case .easy: return "쉬움"
        case .medium: return "중간"
        case .hard: return "중상"
        case .hardest: return "어려움"
        }
    }

    var rank: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        case .hardest: return 3
        }
    }

    /// Default target time when a problem does not set one.
    var defaultTargetSeconds: Int {
        switch self {
        case .easy: return 60
        case .medium: return 90
        case .hard: return 120
        case .hardest: return 180
        }
    }

    static func < (lhs: Band, rhs: Band) -> Bool { lhs.rank < rhs.rank }

    /// Band of a given AMC 8 problem number (1...25).
    static func forNumber(_ n: Int) -> Band {
        switch n {
        case ...10: return .easy
        case 11...15: return .medium
        case 16...20: return .hard
        default: return .hardest
        }
    }
}

/// 분야 tags used by problems, the mistake notebook and the past-paper tracker.
enum Field: String, Codable, CaseIterable, Identifiable {
    case counting, probability, numberTheory, algebra, geometry, statistics, logic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .counting: return "경우의 수"
        case .probability: return "확률"
        case .numberTheory: return "정수론"
        case .algebra: return "대수"
        case .geometry: return "기하"
        case .statistics: return "통계"
        case .logic: return "논리"
        }
    }

    var icon: String {
        switch self {
        case .counting: return "number"
        case .probability: return "dice"
        case .numberTheory: return "divide"
        case .algebra: return "x.squareroot"
        case .geometry: return "triangle"
        case .statistics: return "chart.bar"
        case .logic: return "brain"
        }
    }
}

struct Example: Identifiable {
    let id: String
    let number: Int
    /// Text after "예제 N." on the first line.
    let title: String
    /// Markdown chunks revealed one at a time.
    let steps: [String]
    var figure: String?
}

enum LessonSectionKind: Equatable {
    case why, basics, intuition, examples, tips, pitfalls
    case extra(String)

    var title: String {
        switch self {
        case .why: return "왜 배우나"
        case .basics: return "기초 설명"
        case .intuition: return "직관 예시"
        case .examples: return "예제 풀이"
        case .tips: return "고급 팁"
        case .pitfalls: return "자주 하는 실수와 함정"
        case .extra(let t): return t
        }
    }

    var anchor: String {
        switch self {
        case .why: return "why"
        case .basics: return "basics"
        case .intuition: return "intuition"
        case .examples: return "examples"
        case .tips: return "tips"
        case .pitfalls: return "pitfalls"
        case .extra(let t): return "extra-" + t.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
        }
    }

    var icon: String {
        switch self {
        case .why: return "target"
        case .basics: return "book"
        case .intuition: return "lightbulb"
        case .examples: return "list.number"
        case .tips: return "bolt"
        case .pitfalls: return "exclamationmark.triangle"
        case .extra: return "text.append"
        }
    }

    static func named(_ title: String) -> LessonSectionKind {
        switch title.trimmingCharacters(in: .whitespaces) {
        case "왜 배우나": return .why
        case "기초 설명": return .basics
        case "직관 예시": return .intuition
        case "예제 풀이": return .examples
        case "고급 팁": return .tips
        case "함정", "자주 하는 실수와 함정": return .pitfalls
        default: return .extra(title)
        }
    }
}

struct LessonSection {
    let kind: LessonSectionKind
    /// Markdown body (empty for the examples section, which uses `examples`).
    var body: String
    var examples: [Example] = []
    var figure: String?
}

struct Lesson: Identifiable {
    /// "1-1"
    let id: String
    let unit: Int
    let index: Int
    let title: String
    let titleEn: String?
    var sections: [LessonSection]
    var problems: [Problem] = []

    var displayTitle: String { titleEn.map { "\(title) (\($0))" } ?? title }
    var examples: [Example] { sections.first { $0.kind == .examples }?.examples ?? [] }
}

struct Unit: Identifiable {
    let number: Int
    let title: String
    let titleEn: String?
    var lessons: [Lesson]
    var quiz: [Problem] = []
    var test: [Problem] = []

    var id: Int { number }
    var displayTitle: String { "유닛 \(number). \(title)" }

    var icon: String {
        switch number {
        case 1: return "number"
        case 2: return "dice"
        case 3: return "divide"
        case 4: return "percent"
        case 5: return "square.on.square"
        case 6: return "triangle"
        case 7: return "circle.hexagongrid"
        case 8: return "x.squareroot"
        case 9: return "brain"
        default: return "book"
        }
    }
}

struct VerifySpec: Codable, Equatable {
    /// Python expression evaluating to the correct value.
    var answer: String?
    /// Python expressions for the five choices (when they are not plain numbers).
    var choices: [String]?
    /// Two or more independent computations that must agree (geometry).
    var methods: [String]?
    var note: String?
}

struct Problem: Identifiable, Codable, Equatable {
    let id: String
    /// Lesson the problem belongs to or tests ("1-1").
    let lesson: String
    let band: Band
    var target: Int?
    var fields: [Field]
    let question: String
    let questionKo: String
    var figure: String?
    let choices: [String]
    var choicesKo: [String]?
    let answer: String
    var hints: [String]
    let solution: String
    var fast: String?
    var verify: VerifySpec?

    var targetSeconds: Int { target ?? band.defaultTargetSeconds }
    var answerIndex: Int { Problem.letters.firstIndex(of: answer) ?? 0 }
    static let letters = ["A", "B", "C", "D", "E"]

    var unitNumber: Int { Int(lesson.split(separator: "-").first ?? "0") ?? 0 }
}

enum ProblemSetKind: String, Codable {
    case practice, quiz, test, review, mock

    var title: String {
        switch self {
        case .practice: return "연습문제"
        case .quiz: return "유닛 퀴즈"
        case .test: return "유닛 테스트"
        case .review: return "오답 복습"
        case .mock: return "모의고사"
        }
    }
}

struct CheatsheetSection: Identifiable {
    let id: String
    let title: String
    let body: String
    /// (front, back) pairs for the flashcard mode.
    let cards: [(String, String)]
}
