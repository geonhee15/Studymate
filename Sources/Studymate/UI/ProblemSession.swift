import Foundation
import Observation
import QuartzCore

/// One run through a list of problems (practice set, unit quiz/test, review). Owns timing, selection, hints and the
/// per-problem results; the view only renders it.
@MainActor
@Observable
final class ProblemSession {
    struct Outcome {
        let problem: Problem
        let attempt: Attempt
    }

    let kind: ProblemSetKind
    let title: String
    let unit: Int
    let lessonID: String?
    let problems: [Problem]
    let scratchStore: ScratchStore
    /// Scratch pad of the problem on screen; a fresh one for every problem (and every visit).
    private(set) var scratch: ScratchDocument

    private(set) var index = 0
    private(set) var selected: String?
    private(set) var submitted = false
    private(set) var hintsRevealed = 0
    var guessed = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var outcomes: [Outcome] = []
    private(set) var finished = false
    var language: WebTemplate.Lang = .en
    /// Pending "why did you get stuck" question for the last submitted problem.
    var pendingReview: Outcome?
    /// Review sessions: problem id → notebook entry.
    var reviewEntryIDs: [String: UUID] = [:]

    var onAttempt: ((Attempt) -> Void)?
    var onFinish: ((SetResult?) -> Void)?

    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var sessionStartedAt = Date()
    @ObservationIgnored private var timer: Timer?

    init(kind: ProblemSetKind, title: String, unit: Int, lessonID: String?, problems: [Problem], scratchStore: ScratchStore) {
        self.kind = kind
        self.title = title
        self.unit = unit
        self.lessonID = lessonID
        self.problems = problems
        self.scratchStore = scratchStore
        scratch = ScratchDocument(problem: problems[0], kind: kind, store: scratchStore, canvasWidth: 0)
        startTimer()
    }

    var current: Problem { problems[index] }
    var total: Int { problems.count }
    var isLast: Bool { index >= problems.count - 1 }
    var overTarget: Bool { elapsed > Double(current.targetSeconds) }
    var score: Int { outcomes.filter { $0.attempt.correct }.count }
    var correctCount: Int { score }
    var hintsAvailable: Int { current.hints.count }
    var canSubmit: Bool { selected != nil && !submitted }

    private func startTimer() {
        startedAt = Date()
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.submitted else { return }
                self.elapsed = Date().timeIntervalSince(self.startedAt)
            }
        }
    }

    func select(_ letter: String) {
        guard !submitted, Problem.letters.contains(letter) else { return }
        selected = letter
    }

    func select(index i: Int) {
        guard i >= 0, i < Problem.letters.count else { return }
        select(Problem.letters[i])
    }

    func revealHint() {
        guard !submitted, hintsRevealed < current.hints.count else { return }
        hintsRevealed += 1
    }

    func submit() {
        guard let selected, !submitted else { return }
        submitted = true
        elapsed = Date().timeIntervalSince(startedAt)
        let p = current
        let attempt = Attempt(problemID: p.id, lesson: p.lesson, unit: p.unitNumber, kind: kind, chosen: selected,
                              correct: selected == p.answer, seconds: elapsed, targetSeconds: p.targetSeconds,
                              hintsUsed: hintsRevealed, guessed: guessed, date: Date(), reason: nil, fields: p.fields,
                              scratchID: scratch.id)
        let outcome = Outcome(problem: p, attempt: attempt)
        outcomes.append(outcome)
        onAttempt?(attempt)
        if attempt.needsReview || hintsRevealed > 0 && kind == .review {
            pendingReview = outcome
        }
    }

    /// Advances; returns false when the set is over.
    @discardableResult
    func next() -> Bool {
        guard submitted else { return true }
        if isLast {
            finish()
            return false
        }
        scratch.flush()
        index += 1
        selected = nil
        submitted = false
        hintsRevealed = 0
        guessed = false
        pendingReview = nil
        scratch = ScratchDocument(problem: current, kind: kind, store: scratchStore, canvasWidth: scratch.pad.canvasWidth)
        startTimer()
        return true
    }

    func finish() {
        guard !finished else { return }
        finished = true
        timer?.invalidate()
        timer = nil
        scratch.flush()
        let result: SetResult?
        switch kind {
        case .quiz, .test:
            result = SetResult(unit: unit, kind: kind, score: score, total: total, date: Date(), seconds: Date().timeIntervalSince(sessionStartedAt))
        default:
            result = nil
        }
        onFinish?(result)
    }

    deinit {
        timer?.invalidate()
    }
}
