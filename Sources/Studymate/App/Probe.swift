import AppKit

/// `Studymate --probe content` loads every content file the way the app does and prints what it found plus every
/// structural issue; exits 1 when there is any. `--probe render` additionally converts every lesson and problem to
/// HTML and reports empty output or leftover placeholders.
enum Probe {
    @MainActor
    static func run(_ what: String) -> Int32 {
        let library = ContentLibrary()
        print("content root: \(library.root.path)")
        var problemCount = 0
        for unit in library.units {
            let practice = unit.lessons.reduce(0) { $0 + $1.problems.count }
            problemCount += practice + unit.quiz.count + unit.test.count
            print("unit \(unit.number) \(unit.title): \(unit.lessons.count) lessons, \(practice) practice, quiz \(unit.quiz.count), test \(unit.test.count)")
            for lesson in unit.lessons {
                let sections = lesson.sections.map { $0.kind.title }.joined(separator: " · ")
                let figures = lesson.sections.filter { $0.figure != nil }.count + lesson.examples.filter { $0.figure != nil }.count
                print("  \(lesson.id) \(lesson.title): \(lesson.examples.count) examples, \(lesson.problems.count) problems, \(figures) figures  [\(sections)]")
            }
        }
        print("cheatsheet: \(library.cheatsheet.count) sections, \(library.cheatsheet.reduce(0) { $0 + $1.cards.count }) flashcards")
        print("problems total: \(problemCount)")

        let katex = WebTemplate.baseURL.appendingPathComponent("KaTeX/katex.min.js")
        let css = WebTemplate.baseURL.appendingPathComponent("studymate.css")
        let fonts = (try? FileManager.default.contentsOfDirectory(atPath: WebTemplate.baseURL.appendingPathComponent("KaTeX/fonts").path))?.count ?? 0
        print("katex: \(FileManager.default.fileExists(atPath: katex.path) ? "ok" : "MISSING") (\(fonts) fonts), css: \(FileManager.default.fileExists(atPath: css.path) ? "ok" : "MISSING")")

        var issues = library.issues
        if !FileManager.default.fileExists(atPath: katex.path) { issues.append("KaTeX 번들 없음") }

        if what == "render" || what == "all" {
            for lesson in library.allLessons {
                let html = WebTemplate.lesson(lesson, unit: library.unit(lesson.unit)!)
                if html.contains("\u{E000}") { issues.append("\(lesson.id): 수식 자리표시자가 남음") }
                for section in lesson.sections where section.kind != .examples && section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append("\(lesson.id): '\(section.kind.title)' 본문이 비어 있음")
                }
            }
            for p in library.allProblems {
                let html = WebTemplate.problem(p, lang: .en)
                if html.contains("\u{E000}") { issues.append("\(p.id): 수식 자리표시자가 남음") }
            }
            print("render: \(library.allLessons.count) lessons, \(library.allProblems.count) problems converted")
        }

        if !library.warnings.isEmpty {
            print("warnings: \(library.warnings.count) (콘텐츠 작성 중인 항목)")
            for w in library.warnings { print("  △ \(w)") }
        }
        if issues.isEmpty {
            print("issues: none")
            return 0
        }
        print("issues: \(issues.count)")
        for issue in issues { print("  ✖ \(issue)") }
        return 1
    }
}
