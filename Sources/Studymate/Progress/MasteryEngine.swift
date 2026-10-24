import Foundation

enum MasteryLevel: Int, Codable, Comparable, CaseIterable {
    case none = 0, attempted, familiar, proficient, mastered

    var title: String {
        switch self {
        case .none: return "미시작"
        case .attempted: return "시도함"
        case .familiar: return "익숙함"
        case .proficient: return "숙련"
        case .mastered: return "마스터"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle"
        case .attempted: return "circle.lefthalf.filled"
        case .familiar: return "circle.fill"
        case .proficient: return "checkmark.circle.fill"
        case .mastered: return "crown.fill"
        }
    }

    static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Khan-style mastery. Rules (also shown in the app under "숙련도 기준"):
///   시도함   레슨 연습문제를 1개 이상 풀었다
///   익숙함   연습문제 7개 이상 풀었고 최근 10개의 정답률이 70% 이상
///   숙련     익숙함 + 유닛 퀴즈 통과(8문제 중 6개 이상)
///   마스터   숙련 + 유닛 테스트 통과(15문제 중 12개 이상) + 첫 테스트 통과 7일 뒤 이후에 퀴즈나 테스트를 다시 통과
enum MasteryEngine {
    static let familiarMinimumAttempts = 7
    static let familiarAccuracy = 0.70
    static let familiarWindow = 10
    static let quizPassScore = 6
    static let quizTotal = 8
    static let testPassScore = 12
    static let testTotal = 15
    static let recheckDays = 7

    static let explanation = """
    시도함: 레슨 연습문제를 1개 이상 풀었을 때
    익숙함: 연습문제를 7개 이상 풀고, 최근 10개의 정답률이 70% 이상일 때
    숙련: 익숙함 상태에서 유닛 퀴즈(8문제)를 6개 이상 맞혀 통과했을 때
    마스터: 숙련 상태에서 유닛 테스트(15문제)를 12개 이상 맞혀 통과하고, 그로부터 7일이 지난 뒤 퀴즈나 테스트를 한 번 더 통과했을 때
    틀린 문제는 오답노트에 들어가 1일 → 3일 → 7일 → 14일 간격으로 다시 나옵니다.
    """

    static func level(lessonID: String, unit: Int, attempts: [Attempt], results: [SetResult]) -> MasteryLevel {
        let practice = attempts.filter { $0.lesson == lessonID && $0.kind == .practice }
        guard !practice.isEmpty else { return .none }
        let recent = practice.suffix(familiarWindow)
        let accuracy = Double(recent.filter(\.correct).count) / Double(recent.count)
        guard practice.count >= familiarMinimumAttempts, accuracy >= familiarAccuracy else { return .attempted }

        let unitResults = results.filter { $0.unit == unit && $0.passed }.sorted { $0.date < $1.date }
        guard unitResults.contains(where: { $0.kind == .quiz }) else { return .familiar }
        guard let firstTest = unitResults.first(where: { $0.kind == .test }) else { return .proficient }
        let recheckAfter = Calendar.current.date(byAdding: .day, value: recheckDays, to: firstTest.date) ?? firstTest.date
        let rechecked = unitResults.contains { $0.date >= recheckAfter && $0.id != firstTest.id }
        return rechecked ? .mastered : .proficient
    }

    /// Lesson-level accuracy over the recent window (nil when nothing was attempted).
    static func recentAccuracy(lessonID: String, attempts: [Attempt]) -> Double? {
        let practice = attempts.filter { $0.lesson == lessonID && $0.kind == .practice }.suffix(familiarWindow)
        guard !practice.isEmpty else { return nil }
        return Double(practice.filter(\.correct).count) / Double(practice.count)
    }

    static func passed(kind: ProblemSetKind, score: Int, total: Int) -> Bool {
        switch kind {
        case .quiz: return total > 0 && Double(score) / Double(total) >= Double(quizPassScore) / Double(quizTotal)
        case .test: return total > 0 && Double(score) / Double(total) >= Double(testPassScore) / Double(testTotal)
        default: return false
        }
    }
}
