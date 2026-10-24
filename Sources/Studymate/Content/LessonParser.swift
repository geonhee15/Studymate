import Foundation

/// Parses one unit's `lessons.md` (a verbatim slice of docs/AMC8_concepts.md) into a Unit with lessons and sections.
///
/// Format: `## 유닛 N. 제목 (English)` then `### N-M. 제목 (English)` per lesson; inside a lesson, a line that is
/// nothing but `**제목**` starts a section (왜 배우나 / 기초 설명 / 직관 예시 / 예제 풀이 / 고급 팁 / 함정, anything
/// else is kept as an extra section). In 예제 풀이, `예제 N. …` starts an example whose top-level list items become
/// the steps revealed one at a time.
enum LessonParser {
    struct ParsedUnit {
        var number: Int
        var title: String
        var titleEn: String?
        var lessons: [Lesson]
    }

    static func parseUnit(_ markdown: String) throws -> ParsedUnit {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var unitNumber: Int?
        var unitTitle = ""
        var unitTitleEn: String?
        var lessons: [Lesson] = []

        var currentID: String?
        var currentTitle = ""
        var currentTitleEn: String?
        var currentLines: [String] = []

        func flushLesson() {
            guard let id = currentID, let unit = unitNumber else { return }
            let index = Int(id.split(separator: "-").last ?? "0") ?? 0
            let sections = parseSections(currentLines, lessonID: id)
            lessons.append(Lesson(id: id, unit: unit, index: index, title: currentTitle, titleEn: currentTitleEn, sections: sections))
            currentID = nil
            currentLines = []
        }

        for line in lines {
            if line.hasPrefix("## ") {
                let (number, title, en) = splitHeading(String(line.dropFirst(3)))
                unitNumber = Int(number.replacingOccurrences(of: "유닛", with: "").trimmingCharacters(in: .whitespaces))
                unitTitle = title
                unitTitleEn = en
                continue
            }
            if line.hasPrefix("### ") {
                flushLesson()
                let (number, title, en) = splitHeading(String(line.dropFirst(4)))
                currentID = number
                currentTitle = title
                currentTitleEn = en
                continue
            }
            if currentID != nil { currentLines.append(line) }
        }
        flushLesson()
        guard let number = unitNumber else { throw ContentError.malformed("유닛 제목(## 유닛 N.)이 없습니다") }
        return ParsedUnit(number: number, title: unitTitle, titleEn: unitTitleEn, lessons: lessons)
    }

    /// "1-1. 합의 법칙과 곱의 법칙 (Addition & Multiplication Principles)" → ("1-1", "합의 법칙과 곱의 법칙", "Addition …")
    static func splitHeading(_ text: String) -> (String, String, String?) {
        var heading = text.trimmingCharacters(in: .whitespaces)
        var number = ""
        if let dot = heading.range(of: ". ") {
            number = String(heading[..<dot.lowerBound])
            heading = String(heading[dot.upperBound...])
        }
        var en: String?
        if heading.hasSuffix(")"), let open = heading.lastIndex(of: "(") {
            let candidate = heading[heading.index(after: open)..<heading.index(before: heading.endIndex)]
            // Only treat the parenthetical as an English title when it is ASCII.
            if candidate.unicodeScalars.allSatisfy({ $0.isASCII }) {
                en = String(candidate)
                heading = String(heading[..<open]).trimmingCharacters(in: .whitespaces)
            }
        }
        return (number.trimmingCharacters(in: .whitespaces), heading, en)
    }

    private static func parseSections(_ lines: [String], lessonID: String) -> [LessonSection] {
        var sections: [LessonSection] = []
        var kind: LessonSectionKind?
        var body: [String] = []

        func flush() {
            guard let k = kind else { return }
            var text = body
            while let last = text.last, last.trimmingCharacters(in: .whitespaces).isEmpty || last.trimmingCharacters(in: .whitespaces) == "---" { text.removeLast() }
            while let first = text.first, first.trimmingCharacters(in: .whitespaces).isEmpty { text.removeFirst() }
            if k == .examples {
                sections.append(LessonSection(kind: k, body: "", examples: parseExamples(text, lessonID: lessonID)))
            } else {
                sections.append(LessonSection(kind: k, body: text.joined(separator: "\n")))
            }
            body = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("**"), trimmed.hasSuffix("**"), trimmed.count > 4,
               !trimmed.dropFirst(2).dropLast(2).contains("**") {
                flush()
                kind = LessonSectionKind.named(String(trimmed.dropFirst(2).dropLast(2)))
                continue
            }
            if kind == nil {
                if trimmed.isEmpty { continue }
                kind = .extra("소개")
            }
            body.append(line)
        }
        flush()
        return sections
    }

    private static func parseExamples(_ lines: [String], lessonID: String) -> [Example] {
        var examples: [Example] = []
        var number = 0
        var title = ""
        var bodyLines: [String] = []

        func flush() {
            guard number > 0 else { return }
            examples.append(Example(id: "\(lessonID)-ex\(number)", number: number, title: title, steps: splitSteps(bodyLines)))
            bodyLines = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("예제 "), let n = exampleNumber(trimmed) {
                flush()
                number = n.0
                title = n.1
                continue
            }
            if number > 0 { bodyLines.append(line) }
        }
        flush()
        return examples
    }

    /// "예제 2. 각 자리 …" → (2, "각 자리 …")
    private static func exampleNumber(_ line: String) -> (Int, String)? {
        let rest = line.dropFirst("예제 ".count)
        var digits = ""
        for c in rest { if c.isNumber { digits.append(c) } else { break } }
        guard let n = Int(digits) else { return nil }
        var title = rest.dropFirst(digits.count)
        if title.hasPrefix(".") { title = title.dropFirst() }
        return (n, title.trimmingCharacters(in: .whitespaces))
    }

    /// Top-level list items become steps; a leading plain paragraph becomes the first step; indented lines attach
    /// to the step before them.
    private static func splitSteps(_ lines: [String]) -> [String] {
        var steps: [[String]] = []
        var sawList = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if var last = steps.popLast() { last.append(""); steps.append(last) }
                continue
            }
            let indent = line.prefix(while: { $0 == " " }).count
            let isItem = isListLine(trimmed)
            if isItem && indent == 0 {
                steps.append([line])
                sawList = true
            } else if steps.isEmpty || (!sawList && indent == 0 && !isItem && false) {
                steps.append([line])
            } else {
                steps[steps.count - 1].append(line)
            }
        }
        return steps.map { chunk in
            var lines = chunk
            while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeLast() }
            // Drop the list marker of the first line: the step number comes from the UI.
            if let first = lines.first, isListLine(first.trimmingCharacters(in: .whitespaces)) {
                lines[0] = stripMarker(first)
            }
            return lines.joined(separator: "\n")
        }
    }

    private static func isListLine(_ s: String) -> Bool {
        if s.hasPrefix("- ") || s.hasPrefix("* ") { return true }
        var digits = ""
        for c in s { if c.isNumber { digits.append(c) } else { break } }
        return !digits.isEmpty && s.dropFirst(digits.count).hasPrefix(". ")
    }

    private static func stripMarker(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("- ") || t.hasPrefix("* ") { return String(t.dropFirst(2)) }
        var digits = ""
        for c in t { if c.isNumber { digits.append(c) } else { break } }
        if !digits.isEmpty, t.dropFirst(digits.count).hasPrefix(". ") { return String(t.dropFirst(digits.count + 2)) }
        return t
    }

    // MARK: Cheatsheet

    /// `### 제목` sections of the appendix; table rows and "a = b" lines become flashcards.
    static func parseCheatsheet(_ markdown: String) -> [CheatsheetSection] {
        let lines = markdown.components(separatedBy: "\n")
        var sections: [CheatsheetSection] = []
        var title: String?
        var body: [String] = []
        func flush() {
            guard let t = title else { return }
            let text = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(CheatsheetSection(id: t, title: t, body: text, cards: flashcards(title: t, body: body)))
            body = []
        }
        for line in lines {
            if line.hasPrefix("### ") { flush(); title = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces); continue }
            if line.hasPrefix("## ") || line.hasPrefix("# ") { continue }
            if title != nil { body.append(line) }
        }
        flush()
        return sections
    }

    private static func flashcards(title: String, body: [String]) -> [(String, String)] {
        var cards: [(String, String)] = []
        // Table with header row "n" and value rows → one card per column.
        let rows = body.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("|") }
        if rows.count >= 3 {
            func cells(_ r: String) -> [String] {
                var s = r; if s.hasPrefix("|") { s.removeFirst() }; if s.hasSuffix("|") { s.removeLast() }
                return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            let header = cells(rows[0])
            let data = rows.dropFirst(2).map(cells)
            if header.count > 1 {
                if title.contains("제곱") {   // n / n^2 / n^3 rows → "n = 7" ↔ "49, 343"
                    for col in 1..<header.count {
                        let n = header[col]
                        var backs: [String] = []
                        for row in data where col < row.count && !row[col].isEmpty {
                            backs.append("\(row[0]) = \(row[col])")
                        }
                        if !backs.isEmpty { cards.append(("n = \(n)", backs.joined(separator: ", "))) }
                    }
                } else {   // first column is the prompt, the rest is the answer
                    for row in data where row.count > 1 {
                        cards.append((row[0], row.dropFirst().filter { !$0.isEmpty }.joined(separator: " · ")))
                    }
                }
            }
        }
        // "a = b" items separated by commas on a line, or "name: value" pairs.
        for line in body where !line.hasPrefix("|") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("=") && !trimmed.contains("$") {
                for part in trimmed.components(separatedBy: ", ") {
                    let halves = part.components(separatedBy: " = ")
                    if halves.count == 2 { cards.append((halves[0], halves[1])) }
                }
            } else if trimmed.contains("$") && trimmed.contains("=") {
                for part in trimmed.components(separatedBy: ", ") {
                    guard let eq = part.range(of: " = ") else { continue }
                    var front = String(part[..<eq.lowerBound]).trimmingCharacters(in: .whitespaces)
                    var back = String(part[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if front.hasPrefix("$"), !front.hasSuffix("$") { front += "$" }
                    if back.hasSuffix("$"), !back.hasPrefix("$") { back = "$" + back }
                    cards.append((front, back))
                }
            } else if trimmed.contains(": ") && trimmed.components(separatedBy: " / ").count > 1 {
                for part in trimmed.components(separatedBy: " / ") {
                    let halves = part.components(separatedBy: ": ")
                    if halves.count == 2 { cards.append(("\(halves[0])의 거듭제곱 일의 자리", halves[1])) }
                }
            }
        }
        return cards
    }
}

enum ContentError: Error, CustomStringConvertible {
    case malformed(String)
    case missing(String)

    var description: String {
        switch self {
        case .malformed(let m): return "형식 오류: \(m)"
        case .missing(let m): return "파일 없음: \(m)"
        }
    }
}
