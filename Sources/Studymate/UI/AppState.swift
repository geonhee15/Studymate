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

    var subject: Subject = .amc8
    var route: Route = .home
    var session: ProblemSession?
    /// Hide the subject bar and sidebar while solving.
    var focusMode: Bool {
        didSet { UserDefaults.standard.set(focusMode, forKey: "focusMode") }
    }
    /// Problems start in Korean when on.
    var koreanFirst: Bool {
        didSet { UserDefaults.standard.set(koreanFirst, forKey: "koreanFirst") }
    }
    var showStuckQuestions = false

    init(library: ContentLibrary, progress: ProgressStore, mistakes: MistakeStore, papers: PastPaperStore) {
        self.library = library
        self.progress = progress
        self.mistakes = mistakes
        self.papers = papers
        focusMode = (UserDefaults.standard.object(forKey: "focusMode") as? Bool) ?? true
        koreanFirst = (UserDefaults.standard.object(forKey: "koreanFirst") as? Bool) ?? false
    }

    var chromeHidden: Bool { session != nil && focusMode }

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
        session.onAttempt = { [weak self] attempt in self?.progress.record(attempt) }
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
        case "mock": route = .mock
        case "stats": route = .stats
        case "settings": route = .settings
        default: break
        }
        if let lang = DebugEnv.startLanguage, let l = WebTemplate.Lang(rawValue: lang) { session?.language = l }
    }

    /// STUDYMATE_DEBUG_PROBLEM="select:C" / "hint:2" / "submit:B" / "submit:B,stuck"
    func runProblemScript(_ script: String) {
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
