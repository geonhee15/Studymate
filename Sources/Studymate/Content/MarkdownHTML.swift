import Foundation

/// Small Markdown → HTML converter for the lesson/problem text. Math ($...$, $$...$$) is protected from
/// Markdown processing and left for KaTeX auto-render in the web view. Raw `<svg>`/`<figure>` blocks pass through.
enum MarkdownHTML {
    static func render(_ markdown: String) -> String {
        var math: [String] = []
        let protected = protectMath(markdown, into: &math)
        let html = renderBlocks(protected)
        return restoreMath(html, from: math)
    }

    /// Inline-only rendering (choice text, hints shown in native views, …).
    static func renderInline(_ markdown: String) -> String {
        var math: [String] = []
        let protected = protectMath(markdown, into: &math)
        return restoreMath(inline(protected), from: math)
    }

    // MARK: Math placeholders

    private static let open: Character = "\u{E000}"
    private static let close: Character = "\u{E001}"

    private static func protectMath(_ text: String, into store: inout [String]) -> String {
        var out = ""
        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]
            if c == "\\", text.index(after: i) < text.endIndex, text[text.index(after: i)] == "$" {
                out.append("$")
                i = text.index(i, offsetBy: 2)
                continue
            }
            if c == "$" {
                let display = text.index(after: i) < text.endIndex && text[text.index(after: i)] == "$"
                let delimiter = display ? "$$" : "$"
                let start = text.index(i, offsetBy: delimiter.count)
                if let end = text.range(of: delimiter, range: start..<text.endIndex) {
                    let body = String(text[start..<end.lowerBound])
                    if !body.isEmpty, !(body.first == " " && body.last == " " && !display) {
                        store.append(delimiter + body + delimiter)
                        out.append(open)
                        out.append(String(store.count - 1))
                        out.append(close)
                        i = end.upperBound
                        continue
                    }
                }
            }
            out.append(c)
            i = text.index(after: i)
        }
        return out
    }

    private static func restoreMath(_ html: String, from store: [String]) -> String {
        var out = ""
        var i = html.startIndex
        while i < html.endIndex {
            if html[i] == open, let end = html[i...].firstIndex(of: close) {
                let numberText = html[html.index(after: i)..<end]
                if let n = Int(numberText), n < store.count {
                    out += escape(store[n])
                    i = html.index(after: end)
                    continue
                }
            }
            out.append(html[i])
            i = html.index(after: i)
        }
        return out
    }

    // MARK: Blocks

    private static func renderBlocks(_ text: String) -> String {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var html = ""
        var paragraph: [String] = []
        var i = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html += "<p>" + paragraph.map(inline).joined(separator: "<br>") + "</p>\n"
            paragraph.removeAll()
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { flushParagraph(); i += 1; continue }
            if trimmed.hasPrefix("<") {   // raw html block (svg, figure, div …) until a blank line
                flushParagraph()
                var block: [String] = []
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    block.append(lines[i]); i += 1
                }
                html += block.joined(separator: "\n") + "\n"
                continue
            }
            if trimmed == "---" || trimmed == "***" { flushParagraph(); html += "<hr>\n"; i += 1; continue }
            if let heading = headingLevel(trimmed) {
                flushParagraph()
                let body = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                html += "<h\(heading)>\(inline(body))</h\(heading)>\n"
                i += 1; continue
            }
            if trimmed.hasPrefix("|") {
                flushParagraph()
                var rows: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    rows.append(lines[i].trimmingCharacters(in: .whitespaces)); i += 1
                }
                html += table(rows)
                continue
            }
            if listItem(line) != nil {
                flushParagraph()
                var block: [String] = []
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    block.append(lines[i]); i += 1
                }
                html += list(block)
                continue
            }
            paragraph.append(trimmed)
            i += 1
        }
        flushParagraph()
        return html
    }

    private static func headingLevel(_ line: String) -> Int? {
        var n = 0
        for c in line { if c == "#" { n += 1 } else { break } }
        guard n > 0, n <= 6, line.dropFirst(n).first == " " else { return nil }
        return n
    }

    /// (indent, ordered?, text) for a list line.
    private static func listItem(_ line: String) -> (Int, Bool, String)? {
        let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
        let rest = line.dropFirst(indent)
        if rest.hasPrefix("- ") || rest.hasPrefix("* ") || rest.hasPrefix("• ") {
            return (indent, false, String(rest.dropFirst(2)))
        }
        var digits = ""
        for c in rest { if c.isNumber { digits.append(c) } else { break } }
        if !digits.isEmpty, rest.dropFirst(digits.count).hasPrefix(". ") {
            return (indent, true, String(rest.dropFirst(digits.count + 2)))
        }
        return nil
    }

    private static func list(_ block: [String]) -> String {
        var html = ""
        var stack: [(indent: Int, ordered: Bool)] = []
        var openItem = false
        func closeItem() { if openItem { html += "</li>\n"; openItem = false } }
        func closeList() { closeItem(); if let top = stack.popLast() { html += top.ordered ? "</ol>\n" : "</ul>\n"; openItem = true } }

        for line in block {
            if let (indent, ordered, text) = listItem(line) {
                if let top = stack.last, indent > top.indent {
                    html += ordered ? "<ol>\n" : "<ul>\n"
                    stack.append((indent, ordered))
                    openItem = false
                } else {
                    while let top = stack.last, indent < top.indent { closeList() }
                    if stack.isEmpty {
                        html += ordered ? "<ol>\n" : "<ul>\n"
                        stack.append((indent, ordered))
                    } else {
                        closeItem()
                    }
                }
                html += "<li>" + inline(text)
                openItem = true
            } else {
                // Continuation line of the current item.
                html += "<br>" + inline(line.trimmingCharacters(in: .whitespaces))
            }
        }
        while !stack.isEmpty { closeList() }
        closeItem()
        return html
    }

    private static func table(_ rows: [String]) -> String {
        func cells(_ row: String) -> [String] {
            var r = row
            if r.hasPrefix("|") { r.removeFirst() }
            if r.hasSuffix("|") { r.removeLast() }
            return r.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        var html = "<table>\n"
        var bodyStarted = false
        for (index, row) in rows.enumerated() {
            let c = cells(row)
            if c.allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" } && !$0.isEmpty }) { continue }
            let isHeader = index == 0 && rows.count > 1 && cells(rows[1]).allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" } })
            if isHeader {
                html += "<thead><tr>" + c.map { "<th>\(inline($0))</th>" }.joined() + "</tr></thead>\n"
            } else {
                if !bodyStarted { html += "<tbody>\n"; bodyStarted = true }
                html += "<tr>" + c.map { "<td>\(inline($0))</td>" }.joined() + "</tr>\n"
            }
        }
        if bodyStarted { html += "</tbody>\n" }
        return html + "</table>\n"
    }

    // MARK: Inline

    static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for c in s {
            switch c {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(c)
            }
        }
        return out
    }

    private static func inline(_ raw: String) -> String {
        var s = escape(raw)
        s = replacePairs(in: s, delimiter: "`", open: "<code>", close: "</code>", escapeInner: false)
        s = replacePairs(in: s, delimiter: "**", open: "<strong>", close: "</strong>", escapeInner: false)
        s = replaceItalic(in: s)
        s = replaceLinks(in: s)
        return s
    }

    private static func replacePairs(in s: String, delimiter: String, open: String, close: String, escapeInner: Bool) -> String {
        var out = ""
        var rest = Substring(s)
        while let start = rest.range(of: delimiter) {
            let afterStart = start.upperBound
            guard let end = rest.range(of: delimiter, range: afterStart..<rest.endIndex), end.lowerBound > afterStart else {
                out += rest[rest.startIndex..<afterStart]
                rest = rest[afterStart...]
                continue
            }
            out += rest[rest.startIndex..<start.lowerBound]
            out += open + rest[afterStart..<end.lowerBound] + close
            rest = rest[end.upperBound...]
        }
        return out + rest
    }

    /// *text* → <em>, but only when the asterisk hugs a non-space character on the inside.
    private static func replaceItalic(in s: String) -> String {
        guard s.contains("*") else { return s }
        var out = ""
        var rest = Substring(s)
        while let start = rest.firstIndex(of: "*") {
            let afterStart = rest.index(after: start)
            guard afterStart < rest.endIndex, rest[afterStart] != " ",
                  let end = rest[afterStart...].firstIndex(of: "*"), rest[rest.index(before: end)] != " " else {
                out += rest[rest.startIndex...start]
                rest = rest[afterStart...]
                continue
            }
            out += rest[rest.startIndex..<start] + "<em>" + rest[afterStart..<end] + "</em>"
            rest = rest[rest.index(after: end)...]
        }
        return out + rest
    }

    /// [text](url)
    private static func replaceLinks(in s: String) -> String {
        guard s.contains("](") else { return s }
        var out = ""
        var rest = Substring(s)
        while let lb = rest.firstIndex(of: "["),
              let rb = rest[lb...].firstIndex(of: "]"),
              rest.index(after: rb) < rest.endIndex, rest[rest.index(after: rb)] == "(",
              let rp = rest[rb...].firstIndex(of: ")") {
            let text = rest[rest.index(after: lb)..<rb]
            let url = rest[rest.index(rb, offsetBy: 2)..<rp]
            out += rest[rest.startIndex..<lb] + "<a href=\"\(url)\">\(text)</a>"
            rest = rest[rest.index(after: rp)...]
        }
        return out + rest
    }
}
