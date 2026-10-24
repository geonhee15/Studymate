import Foundation

/// Builds the HTML shown in `MathWebView`: the page skeleton (KaTeX + our CSS/JS from the app bundle) and the
/// body fragments for lessons, problems and plain documents.
enum WebTemplate {
    /// Directory the page loads KaTeX and studymate.css/js from (relative URLs in the template).
    static let baseURL: URL = {
        if let override = ProcessInfo.processInfo.environment["STUDYMATE_WEB_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return Bundle.main.resourceURL ?? Bundle.main.bundleURL
    }()

    static func page() -> String {
        """
        <!doctype html>
        <html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="KaTeX/katex.min.css">
        <link rel="stylesheet" href="studymate.css">
        <script defer src="KaTeX/katex.min.js"></script>
        <script defer src="KaTeX/contrib/auto-render.min.js"></script>
        <script defer src="studymate.js"></script>
        </head><body><div id="root"></div></body></html>
        """
    }

    /// JSON string literal usable inside evaluateJavaScript.
    static func jsString(_ s: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [s], options: [.withoutEscapingSlashes])
        var text = String(decoding: data, as: UTF8.self)
        text.removeFirst()   // "["
        text.removeLast()    // "]"
        // Keep U+2028/2029 out of the literal; JSON allows them but JavaScript source does not.
        return text.replacingOccurrences(of: "\u{2028}", with: "\\u2028").replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    // MARK: Lesson

    static func lesson(_ lesson: Lesson, unit: Unit) -> String {
        var html = "<article class=\"lesson\"><header>"
        html += "<div class=\"kicker\">유닛 \(unit.number) · \(MarkdownHTML.escape(unit.title)) · 레슨 \(lesson.id)</div>"
        html += "<h1>\(MarkdownHTML.escape(lesson.title))"
        if let en = lesson.titleEn { html += "<span class=\"en\">\(MarkdownHTML.escape(en))</span>" }
        html += "</h1></header>"
        for section in lesson.sections {
            html += renderSection(section)
        }
        html += "</article>"
        return html
    }

    private static func renderSection(_ section: LessonSection) -> String {
        let anchor = section.kind.anchor
        var html = "<section class=\"sec \(anchor)\" id=\"\(anchor)\"><h2>\(MarkdownHTML.escape(section.kind.title))</h2>"
        if let fig = section.figure { html += "<figure>\(fig)</figure>" }
        switch section.kind {
        case .examples:
            for ex in section.examples { html += renderExample(ex) }
        case .why, .tips, .pitfalls:
            html += "<div class=\"body callout\">\(MarkdownHTML.render(section.body))</div>"
        default:
            html += "<div class=\"body\">\(MarkdownHTML.render(section.body))</div>"
        }
        html += "</section>"
        return html
    }

    private static func renderExample(_ ex: Example) -> String {
        var html = "<div class=\"example\" id=\"\(ex.id)\">"
        html += "<div class=\"ex-title\"><span class=\"ex-num\">예제 \(ex.number)</span><span>\(MarkdownHTML.renderInline(ex.title))</span></div>"
        if let fig = ex.figure { html += "<figure>\(fig)</figure>" }
        if !ex.steps.isEmpty {
            html += "<ol class=\"steps\">"
            for step in ex.steps { html += "<li class=\"step\">\(MarkdownHTML.render(step))</li>" }
            html += "</ol>"
            html += "<div class=\"ex-actions\"><button class=\"sm primary\" data-action=\"step\">풀이 보기</button><button class=\"sm\" data-action=\"all\">한 번에 보기</button><span class=\"ex-done\" hidden>풀이 끝</span></div>"
        }
        html += "</div>"
        return html
    }

    // MARK: Problem

    enum Lang: String { case en, ko }

    static func problem(_ p: Problem, lang: Lang, exam: Bool = false) -> String {
        var html = "<div class=\"problem\">"
        if exam, let n = p.number { html += "<div class=\"qnum\">\(n).</div>" }
        html += "<div class=\"q en\"\(lang == .en ? "" : " hidden")>\(MarkdownHTML.render(p.question))</div>"
        html += "<div class=\"q ko\"\(lang == .ko ? "" : " hidden")>\(MarkdownHTML.render(p.questionKo))</div>"
        if let fig = p.figure { html += "<figure>\(fig)</figure>" }
        html += "<ol class=\"choices\">"
        for (i, choice) in p.choices.enumerated() {
            let letter = Problem.letters[i]
            let ko = p.choicesKo.flatMap { i < $0.count ? $0[i] : nil }
            let koAttr = ko.map { " data-ko=\"\(MarkdownHTML.escape(MarkdownHTML.renderInline($0)))\"" } ?? ""
            let body = (lang == .ko && ko != nil) ? ko! : choice
            html += "<li class=\"choice\" data-letter=\"\(letter)\"><span class=\"letter\">\(letter)</span><span class=\"body\"\(koAttr)>\(MarkdownHTML.renderInline(body))</span></li>"
        }
        html += "</ol>"
        if exam { return html + "</div>" }
        html += "<div class=\"hints\">"
        for (i, hint) in p.hints.enumerated() {
            html += "<div class=\"hint\" id=\"hint\(i + 1)\"><span class=\"tag\">힌트 \(i + 1)</span>\(MarkdownHTML.renderInline(hint))</div>"
        }
        html += "</div>"
        html += "<div class=\"result\"></div>"
        html += "<div class=\"solution\"><h3>해설</h3><div class=\"body\">\(MarkdownHTML.render(p.solution))</div>"
        if let fast = p.fast {
            html += "<h3 class=\"fast\">더 빠른 풀이</h3><div class=\"body\">\(MarkdownHTML.render(fast))</div>"
        }
        html += "</div></div>"
        return html
    }

    // MARK: Documents

    static func document(markdown: String, cardGrid: Bool = false) -> String {
        "<div class=\"doc\(cardGrid ? " card-grid" : "")\">\(MarkdownHTML.render(markdown))</div>"
    }

    static func cheatsheet(_ sections: [CheatsheetSection]) -> String {
        var html = "<div class=\"doc card-grid\">"
        for s in sections {
            html += "<div class=\"block\" id=\"\(s.id)\"><h3>\(MarkdownHTML.escape(s.title))</h3>\(MarkdownHTML.render(s.body))</div>"
        }
        return html + "</div>"
    }
}
