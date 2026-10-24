import AppKit
import SwiftUI
import Observation

enum Route: Equatable {
    case home
    case unit(Int)
    case lesson(String)
    case cheatsheet
    case mistakes
    case pastpapers
    case mock
    case stats
    case settings

    /// Sidebar row the route belongs to.
    var sidebarItem: SidebarItem {
        switch self {
        case .home: return .home
        case .unit(let n): return .unit(n)
        case .lesson(let id): return .unit(Int(id.split(separator: "-").first ?? "0") ?? 0)
        case .cheatsheet: return .cheatsheet
        case .mistakes: return .mistakes
        case .pastpapers: return .pastpapers
        case .mock: return .mock
        case .stats: return .stats
        case .settings: return .settings
        }
    }
}

enum SidebarItem: Hashable, Identifiable {
    case home, unit(Int), cheatsheet, mistakes, pastpapers, mock, stats, settings

    var id: String {
        switch self {
        case .unit(let n): return "unit-\(n)"
        default: return "\(self)"
        }
    }

    var route: Route {
        switch self {
        case .home: return .home
        case .unit(let n): return .unit(n)
        case .cheatsheet: return .cheatsheet
        case .mistakes: return .mistakes
        case .pastpapers: return .pastpapers
        case .mock: return .mock
        case .stats: return .stats
        case .settings: return .settings
        }
    }
}

/// Cross-cutting UI state: subject, current route, the active problem session, focus mode.
@MainActor
@Observable
final class AppState {
    let library: ContentLibrary
    let progress: ProgressStore
    let mistakes: MistakeStore
    let papers: PastPaperStore
    let mocks: MockStore

    var subject: Subject = .amc8
    var route: Route = .home
    var session: ProblemSession?
    var mockSession: MockSession?
    var paperSession: PaperSession?
    /// A past mock result opened from the history list.
    var mockResultReview: (result: MockResult, set: MockSet)?
    /// Hide the subject bar and sidebar while solving.
    var focusMode: Bool {
        didSet { UserDefaults.standard.set(focusMode, forKey: "focusMode") }
    }
    /// Problems start in Korean when on.
    var koreanFirst: Bool {
        didSet { UserDefaults.standard.set(koreanFirst, forKey: "koreanFirst") }
    }
    var showStuckQuestions = false

    init(library: ContentLibrary, progress: ProgressStore, mistakes: MistakeStore, papers: PastPaperStore, mocks: MockStore) {
        self.library = library
        self.progress = progress
        self.mistakes = mistakes
        self.papers = papers
        self.mocks = mocks
        focusMode = (UserDefaults.standard.object(forKey: "focusMode") as? Bool) ?? true
        koreanFirst = (UserDefaults.standard.object(forKey: "koreanFirst") as? Bool) ?? false
    }

    var chromeHidden: Bool { (session != nil || mockSession != nil || paperSession != nil) && focusMode }

    func open(_ route: Route) {
        withAnimation(.snappy(duration: 0.22)) {
            self.route = route
        }
        if case .lesson(let id) = route { progress.markOpened(lesson: id) }
    }

    // MARK: Sessions

    func startPractice(lesson: Lesson) {
        let solved = progress.solvedProblemIDs()
        // Fresh problems first (in band order), then the ones already solved.
        let ordered = lesson.problems.sorted {
            if solved.contains($0.id) != solved.contains($1.id) { return !solved.contains($0.id) }
            return $0.band.rank < $1.band.rank
        }
        start(ProblemSession(kind: .practice, title: "\(lesson.id) 연습문제", unit: lesson.unit, lessonID: lesson.id, problems: ordered))
    }

    func startQuiz(unit: Unit) {
        guard !unit.quiz.isEmpty else { return }
        start(ProblemSession(kind: .quiz, title: "유닛 \(unit.number) 퀴즈", unit: unit.number, lessonID: nil, problems: unit.quiz))
    }

    func startTest(unit: Unit) {
        guard !unit.test.isEmpty else { return }
        start(ProblemSession(kind: .test, title: "유닛 \(unit.number) 테스트", unit: unit.number, lessonID: nil, problems: unit.test))
    }

    func startReview(entries: [MistakeEntry]) {
        let items: [(Problem, UUID)] = entries.compactMap { e in
            guard let pid = e.problemID, let p = library.problem(pid) else { return nil }
            return (p, e.id)
        }
        guard !items.isEmpty else { return }
        let session = ProblemSession(kind: .review, title: "오답 복습", unit: 0, lessonID: nil, problems: items.map(\.0))
        session.reviewEntryIDs = Dictionary(uniqueKeysWithValues: items.map { ($0.0.id, $0.1) })
        start(session)
    }

    private func start(_ session: ProblemSession) {
        session.language = koreanFirst ? .ko : .en
        session.onAttempt = { [weak self, weak session] attempt in
            guard let self else { return }
            self.progress.record(attempt)
            // Review sessions move the notebook entry: correct without hints → next stage, otherwise back to 1 day.
            if let session, session.kind == .review, let entryID = session.reviewEntryIDs[attempt.problemID] {
                self.mistakes.recordReview(id: entryID, correct: attempt.correct && attempt.hintsUsed == 0)
            }
        }
        session.onFinish = { [weak self] result in
            guard let self, let result else { return }
            self.progress.record(result)
        }
        withAnimation(.snappy(duration: 0.22)) { self.session = session }
    }

    func endSession() {
        session?.finish()
        withAnimation(.snappy(duration: 0.22)) { session = nil }
    }

    // MARK: Mock exams

    func startMock(set: MockSet) {
        let s = MockSession(set: set)
        s.onFinish = { [weak self] result in self?.mocks.record(result) }
        withAnimation(.snappy(duration: 0.22)) { mockSession = s }
    }

    func endMock(discard: Bool = false) {
        withAnimation(.snappy(duration: 0.22)) { mockSession = nil; mockResultReview = nil }
    }

    func showMockResult(_ result: MockResult, set: MockSet) {
        withAnimation(.snappy(duration: 0.22)) { mockResultReview = (result, set) }
    }

    func startPaper(year: Int) {
        withAnimation(.snappy(duration: 0.22)) { paperSession = PaperSession(year: year) }
    }

    /// Writes the self-graded answers into the past-paper tracker and the mock history.
    func finishPaper(_ s: PaperSession) {
        var answers: [MockAnswer] = []
        for n in 1...25 {
            let correct = s.verdicts[n] ?? false
            papers.update(year: s.year, number: n) { cell in
                if s.guessed.contains(n) && correct { cell.status = .guessed }
                else if s.slow.contains(n) && correct { cell.status = .slow }
                else { cell.status = correct ? .correct : .wrong }
            }
            answers.append(MockAnswer(number: n, chosen: s.answers[n], correct: correct, seconds: 0))
        }
        mocks.record(MockResult(kind: .paper, source: String(s.year), title: "\(s.year) AMC 8 (종이)", date: Date(), score: s.score, total: 25, seconds: s.usedSeconds, answers: answers))
        s.finishGrading()
    }

    func endPaper(discard: Bool = false) {
        withAnimation(.snappy(duration: 0.22)) { paperSession = nil }
    }

    /// 기출 트래커 → 오답노트.
    func sendPaperToNotebook(year: Int, number: Int, note: String? = nil, fields: [Field]? = nil) {
        let cell = papers.cell(year: year, number: number)
        let reason: StuckReason = cell.status == .guessed ? .idea : cell.status == .slow ? .idea : .concept
        let f = fields ?? cell.fields
        mistakes.add(source: .pastPaper(year: year, number: number), fields: f.isEmpty ? [] : f, reason: reason,
                     keyIdea: "", myNote: note ?? cell.note)
        papers.update(year: year, number: number) { $0.sentToNotebook = true }
    }

    // MARK: Debug

    /// STUDYMATE_TAB values, see DebugEnv.
    func open(debugTab: String) {
        let parts = debugTab.split(separator: ":").map(String.init)
        let arg = parts.count > 1 ? parts[1] : ""
        switch parts[0] {
        case "home": route = .home
        case "unit": route = .unit(Int(arg) ?? 1)
        case "lesson": route = .lesson(arg.isEmpty ? "1-1" : arg)
        case "practice":
            if let lesson = library.lesson(arg.isEmpty ? "1-1" : arg) { route = .lesson(lesson.id); startPractice(lesson: lesson) }
        case "quiz": if let unit = library.unit(Int(arg) ?? 1) { route = .unit(unit.number); startQuiz(unit: unit) }
        case "test": if let unit = library.unit(Int(arg) ?? 1) { route = .unit(unit.number); startTest(unit: unit) }
        case "cheatsheet": route = .cheatsheet
        case "mistakes": route = .mistakes
        case "pastpapers": route = .pastpapers
        case "mock":
            route = .mock
            if let set = library.mockSets.first(where: { "\($0.number)" == arg }) { startMock(set: set) }
        case "paper":
            route = .mock
            startPaper(year: Int(arg) ?? 2023)
        case "stats": route = .stats
        case "settings": route = .settings
        default: break
        }
        if let lang = DebugEnv.startLanguage, let l = WebTemplate.Lang(rawValue: lang) { session?.language = l }
    }

    /// STUDYMATE_DEBUG_PROBLEM="select:C" / "hint:2" / "submit:B" / "submit:B,stuck"
    func runProblemScript(_ script: String) {
        if let mock = mockSession {
            for step in script.split(separator: ",") {
                let parts = step.split(separator: ":").map(String.init)
                switch parts[0] {
                case "answer": mock.answer(parts.count > 1 ? parts[1] : "A")
                case "go": mock.go(to: (Int(parts.count > 1 ? parts[1] : "1") ?? 1) - 1)
                case "next": mock.next()
                case "fill":   // fill:C answers every problem with C
                    for i in 0..<mock.problems.count { mock.go(to: i); mock.answer(parts.count > 1 ? parts[1] : "C") }
                case "finish": mock.finish()
                default: break
                }
            }
            return
        }
        if let paper = paperSession {
            for step in script.split(separator: ",") {
                let parts = step.split(separator: ":").map(String.init)
                switch parts[0] {
                case "fill": for n in 1...25 { paper.answer(number: n, parts.count > 1 ? parts[1] : "C") }
                case "grade": paper.stopSolving()
                case "mark": for n in 1...25 { paper.verdicts[n] = n % 4 != 0 }
                default: break
                }
            }
            return
        }
        guard let session else { return }
        for step in script.split(separator: ",") {
            let parts = step.split(separator: ":").map(String.init)
            switch parts[0] {
            case "select": session.select(parts.count > 1 ? parts[1] : "A")
            case "hint": for _ in 0..<(Int(parts.count > 1 ? parts[1] : "1") ?? 1) { session.revealHint() }
            case "guess": session.guessed = true
            case "submit":
                session.select(parts.count > 1 ? parts[1] : "A")
                session.submit()
            case "stuck": showStuckQuestions = true
            case "next": session.next()
            default: break
            }
        }
    }
}
