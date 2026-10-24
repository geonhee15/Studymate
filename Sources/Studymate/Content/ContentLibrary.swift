import Foundation
import Observation

/// Loads everything under Resources/Content/<subject>/ once at launch:
///   unitN/lessons.md      verbatim slice of docs/AMC8_concepts.md (parsed by LessonParser)
///   unitN/problems.json   practice problems, each tagged with its lesson
///   unitN/quiz.json       unit quiz, unitN/test.json unit test
///   unitN/figures/*.svg   figures attached by name: "<lesson>-<section>.svg" or "<lesson>-ex<N>.svg"
///   common.md             section 0 of the concept doc (stuck questions, exam info)
///   cheatsheet.md         appendix (cheatsheet + flashcards)
@MainActor
@Observable
final class ContentLibrary {
    private(set) var units: [Unit] = []
    private(set) var mockSets: [MockSet] = []
    private(set) var cheatsheet: [CheatsheetSection] = []
    private(set) var commonMarkdown = ""
    /// Problems with validation errors, duplicate ids, etc. Shown by `--probe content`.
    private(set) var issues: [String] = []
    /// Things that are allowed while content is still being written (missing figures/problem sets).
    private(set) var warnings: [String] = []

    let subject: Subject
    let root: URL

    private var problemIndex: [String: Problem] = [:]
    private var lessonIndex: [String: Lesson] = [:]

    init(subject: Subject = .amc8, bundle: Bundle = .main) {
        self.subject = subject
        if let override = ProcessInfo.processInfo.environment["STUDYMATE_CONTENT_DIR"], !override.isEmpty {
            root = URL(fileURLWithPath: override, isDirectory: true).appendingPathComponent(subject.contentFolder, isDirectory: true)
        } else if let url = bundle.url(forResource: "Content", withExtension: nil) {
            root = url.appendingPathComponent(subject.contentFolder, isDirectory: true)
        } else {
            root = bundle.bundleURL.appendingPathComponent("Contents/Resources/Content/\(subject.contentFolder)", isDirectory: true)
        }
        load()
    }

    // MARK: Lookup

    func unit(_ number: Int) -> Unit? { units.first { $0.number == number } }
    func lesson(_ id: String) -> Lesson? { lessonIndex[id] }
    func problem(_ id: String) -> Problem? { problemIndex[id] }
    var allProblems: [Problem] { Array(problemIndex.values) }
    var allLessons: [Lesson] { units.flatMap(\.lessons) }

    func lessonTitle(_ id: String) -> String { lessonIndex[id]?.title ?? id }

    /// Next lesson after the given one, across units.
    func lesson(after id: String) -> Lesson? {
        let all = allLessons
        guard let i = all.firstIndex(where: { $0.id == id }), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    // MARK: Loading

    private func load() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            issues.append("콘텐츠 폴더를 찾을 수 없습니다: \(root.path)")
            return
        }
        let unitDirs = entries.filter { $0.lastPathComponent.hasPrefix("unit") && (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { unitNumber($0) < unitNumber($1) }
        var loaded: [Unit] = []
        for dir in unitDirs {
            do {
                loaded.append(try loadUnit(dir))
            } catch {
                issues.append("\(dir.lastPathComponent): \(error)")
            }
        }
        units = loaded
        for unit in units {
            for lesson in unit.lessons { lessonIndex[lesson.id] = lesson }
        }
        loadMockSets()
        if let common = try? String(contentsOf: root.appendingPathComponent("common.md"), encoding: .utf8) {
            commonMarkdown = common
        }
        if let appendix = try? String(contentsOf: root.appendingPathComponent("cheatsheet.md"), encoding: .utf8) {
            cheatsheet = LessonParser.parseCheatsheet(appendix)
        } else {
            issues.append("cheatsheet.md 없음")
        }
        validate()
    }

    private func unitNumber(_ url: URL) -> Int {
        Int(url.lastPathComponent.dropFirst("unit".count)) ?? 0
    }

    private func loadUnit(_ dir: URL) throws -> Unit {
        let lessonsURL = dir.appendingPathComponent("lessons.md")
        guard let markdown = try? String(contentsOf: lessonsURL, encoding: .utf8) else {
            throw ContentError.missing(lessonsURL.lastPathComponent)
        }
        let parsed = try LessonParser.parseUnit(markdown)
        var lessons = parsed.lessons

        let figures = loadFigures(dir.appendingPathComponent("figures", isDirectory: true))
        let practice = loadProblems(dir.appendingPathComponent("problems.json"), required: false)
        let quiz = loadProblems(dir.appendingPathComponent("quiz.json"), required: false)
        let test = loadProblems(dir.appendingPathComponent("test.json"), required: false)

        for i in lessons.indices {
            let id = lessons[i].id
            lessons[i].problems = practice.filter { $0.lesson == id }
            for s in lessons[i].sections.indices {
                let section = lessons[i].sections[s]
                if let fig = figures["\(id)-\(section.kind.anchor)"] { lessons[i].sections[s].figure = fig }
                if section.kind == .examples {
                    for e in section.examples.indices {
                        if let fig = figures["\(id)-ex\(section.examples[e].number)"] {
                            lessons[i].sections[s].examples[e].figure = fig
                        }
                    }
                }
            }
        }
        for p in practice where !lessons.contains(where: { $0.id == p.lesson }) {
            issues.append("\(p.id): 존재하지 않는 레슨 \(p.lesson)")
        }
        return Unit(number: parsed.number, title: parsed.title, titleEn: parsed.titleEn, lessons: lessons, quiz: quiz, test: test)
    }

    private func loadMockSets() {
        let dir = root.appendingPathComponent("mock", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        var sets: [MockSet] = []
        for file in files where file.pathExtension == "json" && file.lastPathComponent.hasPrefix("set") {
            let name = file.deletingPathExtension().lastPathComponent
            let number = Int(name.dropFirst("set".count)) ?? 0
            let problems = loadProblems(file, required: true).sorted { ($0.number ?? 0) < ($1.number ?? 0) }
            if problems.count != 25 { issues.append("\(file.lastPathComponent): 25문제가 아님 (\(problems.count))") }
            let numbers = problems.compactMap(\.number).sorted()
            if numbers != Array(1...25) { issues.append("\(file.lastPathComponent): number가 1~25를 덮지 않음") }
            for p in problems where p.band != Band.forNumber(p.number ?? 0) { issues.append("\(p.id): band가 번호대와 다름") }
            sets.append(MockSet(id: name, number: number, problems: problems))
        }
        mockSets = sets.sorted { $0.number < $1.number }
    }

    private func loadFigures(_ dir: URL) -> [String: String] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [:] }
        var out: [String: String] = [:]
        for file in files where file.pathExtension == "svg" {
            if let svg = try? String(contentsOf: file, encoding: .utf8) {
                out[file.deletingPathExtension().lastPathComponent] = svg
            }
        }
        return out
    }

    private func loadProblems(_ url: URL, required: Bool) -> [Problem] {
        guard let data = try? Data(contentsOf: url) else {
            if required { issues.append("\(url.lastPathComponent) 없음") }
            return []
        }
        do {
            let problems = try JSONDecoder().decode([Problem].self, from: data)
            for p in problems {
                if problemIndex[p.id] != nil { issues.append("\(p.id): id 중복") }
                problemIndex[p.id] = p
            }
            return problems
        } catch {
            issues.append("\(url.lastPathComponent): \(error)")
            return []
        }
    }

    /// Structural checks every content file must pass (answers are verified by Scripts/verify_content.py).
    private func validate() {
        for p in allProblems {
            if p.choices.count != 5 { issues.append("\(p.id): 선택지가 \(p.choices.count)개") }
            if Set(p.choices.map { $0.trimmingCharacters(in: .whitespaces) }).count != p.choices.count { issues.append("\(p.id): 선택지 중복") }
            if !Problem.letters.contains(p.answer) { issues.append("\(p.id): 정답 문자 '\(p.answer)' 잘못됨") }
            if p.hints.count > 3 { issues.append("\(p.id): 힌트가 3개를 넘음") }
            if p.hints.isEmpty { issues.append("\(p.id): 힌트 없음") }
            if p.fields.isEmpty { issues.append("\(p.id): 분야 태그 없음") }
            if p.fields.contains(.geometry), p.figure == nil { issues.append("\(p.id): 기하 문제에 그림 없음") }
            if p.question.isEmpty || p.questionKo.isEmpty { issues.append("\(p.id): 영어/한국어 문제 누락") }
            if p.solution.isEmpty { issues.append("\(p.id): 해설 없음") }
            if lessonIndex[p.lesson] == nil { issues.append("\(p.id): 레슨 \(p.lesson) 없음") }
            if let ko = p.choicesKo, ko.count != 5 { issues.append("\(p.id): 한국어 선택지가 5개가 아님") }
        }
        for unit in units {
            for lesson in unit.lessons {
                let kinds = lesson.sections.map(\.kind)
                for required: LessonSectionKind in [.why, .basics, .intuition, .pitfalls] where !kinds.contains(required) {
                    issues.append("\(lesson.id): '\(required.title)' 섹션 없음")
                }
                if lesson.unit >= 5, lesson.unit <= 7 {
                    let hasFigure = lesson.sections.contains { $0.figure != nil || $0.examples.contains { $0.figure != nil } }
                    if !hasFigure { warnings.append("\(lesson.id): 기하 레슨에 그림 없음") }
                }
                if lesson.problems.isEmpty { warnings.append("\(lesson.id): 연습문제 없음") }
            }
            if unit.quiz.isEmpty { warnings.append("유닛 \(unit.number): 퀴즈 없음") }
            if unit.test.isEmpty { warnings.append("유닛 \(unit.number): 테스트 없음") }
            for (kind, set) in [("퀴즈", unit.quiz), ("테스트", unit.test)] where !set.isEmpty {
                let expected = kind == "퀴즈" ? MasteryEngine.quizTotal : MasteryEngine.testTotal
                if set.count != expected { issues.append("유닛 \(unit.number) \(kind): \(set.count)문제 (기대 \(expected))") }
            }
            for lesson in unit.lessons where !lesson.problems.isEmpty && lesson.problems.count < 10 {
                issues.append("\(lesson.id): 연습문제 \(lesson.problems.count)개 (최소 10)")
            }
        }
    }
}
