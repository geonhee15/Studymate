import Foundation
import Observation

/// A timed 25-problem exam. Free navigation, OMR-style answers, 40-minute countdown, per-problem time tracking.
@MainActor
@Observable
final class MockSession {
    static let timeLimit: TimeInterval = 40 * 60

    let exam: MockSet
    private(set) var index = 0
    private(set) var answers: [Int: String] = [:]
    private(set) var remaining: TimeInterval = MockSession.timeLimit
    private(set) var finished = false
    private(set) var result: MockResult?
    /// Numbers the learner flagged to come back to.
    var flagged: Set<Int> = []

    var onFinish: ((MockResult) -> Void)?

    @ObservationIgnored private let startedAt = Date()
    @ObservationIgnored private var enteredAt = Date()
    @ObservationIgnored private var timeSpent: [Int: TimeInterval] = [:]
    @ObservationIgnored private var timer: Timer?

    init(set: MockSet) {
        self.exam = set
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    var problems: [Problem] { exam.problems }
    var current: Problem { problems[index] }
    var currentNumber: Int { current.number ?? index + 1 }
    var answeredCount: Int { answers.count }
    var elapsed: TimeInterval { Self.timeLimit - remaining }

    private func tick() {
        guard !finished else { return }
        remaining = max(0, Self.timeLimit - Date().timeIntervalSince(startedAt))
        if remaining <= 0 { finish() }
    }

    func answer(_ letter: String) {
        guard !finished, Problem.letters.contains(letter) else { return }
        answers[currentNumber] = letter
    }

    func clearAnswer() {
        answers[currentNumber] = nil
    }

    func go(to i: Int) {
        guard i >= 0, i < problems.count, i != index else { return }
        commitTime()
        index = i
    }

    func next() { go(to: min(index + 1, problems.count - 1)) }
    func previous() { go(to: max(index - 1, 0)) }

    private func commitTime() {
        let now = Date()
        timeSpent[currentNumber, default: 0] += now.timeIntervalSince(enteredAt)
        enteredAt = now
    }

    func finish() {
        guard !finished else { return }
        commitTime()
        finished = true
        timer?.invalidate()
        timer = nil
        let answered = problems.map { p -> MockAnswer in
            let n = p.number ?? 0
            let chosen = answers[n]
            return MockAnswer(number: n, chosen: chosen, correct: chosen.map { $0 == p.answer }, seconds: timeSpent[n] ?? 0, fields: p.fields, lesson: p.lesson)
        }
        let r = MockResult(kind: .app, source: exam.id, title: exam.title, date: Date(), score: answered.filter { $0.correct == true }.count,
                           total: problems.count, seconds: min(Self.timeLimit, Date().timeIntervalSince(startedAt)), answers: answered)
        result = r
        onFinish?(r)
    }

    deinit { timer?.invalidate() }
}

/// 종이 기출 모드: no problem text, just a 40-minute timer and an answer sheet, then self-grading.
@MainActor
@Observable
final class PaperSession {
    static let timeLimit: TimeInterval = 40 * 60

    let year: Int
    private(set) var answers: [Int: String] = [:]
    private(set) var remaining: TimeInterval = PaperSession.timeLimit
    private(set) var phase: Phase = .solving
    /// Self-check: number → correct?
    var verdicts: [Int: Bool] = [:]
    var guessed: Set<Int> = []
    var slow: Set<Int> = []

    enum Phase { case solving, grading, done }

    @ObservationIgnored private let startedAt = Date()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private(set) var usedSeconds: TimeInterval = 0

    init(year: Int) {
        self.year = year
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard phase == .solving else { return }
        remaining = max(0, Self.timeLimit - Date().timeIntervalSince(startedAt))
        if remaining <= 0 { stopSolving() }
    }

    func answer(number: Int, _ letter: String?) {
        guard phase == .solving else { return }
        answers[number] = letter
    }

    func stopSolving() {
        guard phase == .solving else { return }
        usedSeconds = min(Self.timeLimit, Date().timeIntervalSince(startedAt))
        timer?.invalidate()
        timer = nil
        phase = .grading
    }

    var score: Int { verdicts.values.filter { $0 }.count }
    var gradedCount: Int { verdicts.count }

    func finishGrading() { phase = .done }

    deinit { timer?.invalidate() }
}
