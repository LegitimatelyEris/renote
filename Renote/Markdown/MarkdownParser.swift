import Foundation

/// A small line-based Markdown parser. It is deliberately forgiving: anything it
/// does not recognise becomes a paragraph, so nothing typed is ever lost.
struct MarkdownParser {
    private var nextID = 0

    static func parse(_ text: String) -> [Block] {
        var parser = MarkdownParser()
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        return parser.parse(lines: lines.enumerated().map { ($0.offset, $0.element) })
    }

    private mutating func make(_ kind: Block.Kind) -> Block {
        defer { nextID += 1 }
        return Block(id: nextID, kind: kind)
    }

    // MARK: Blocks

    private mutating func parse(lines: [(Int, String)]) -> [Block] {
        var blocks: [Block] = []
        var i = 0
        var paragraph: [String] = []

        func flush(_ p: inout [String], into blocks: inout [Block], _ me: inout MarkdownParser) {
            guard !p.isEmpty else { return }
            blocks.append(me.make(.paragraph(p.joined(separator: " "))))
            p.removeAll()
        }

        while i < lines.count {
            let (lineNo, raw) = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flush(&paragraph, into: &blocks, &self)
                i += 1
                continue
            }

            // Fenced code
            if line.hasPrefix("```") {
                flush(&paragraph, into: &blocks, &self)
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                i += 1
                while i < lines.count, !lines[i].1.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[i].1)
                    i += 1
                }
                i += 1
                blocks.append(make(.code(language: lang, text: body.joined(separator: "\n"))))
                continue
            }

            // Toggle: +++ Title ... +++
            if line.hasPrefix("+++") {
                flush(&paragraph, into: &blocks, &self)
                let title = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [(Int, String)] = []
                i += 1
                while i < lines.count, lines[i].1.trimmingCharacters(in: .whitespaces) != "+++" {
                    body.append(lines[i])
                    i += 1
                }
                i += 1
                blocks.append(make(.toggle(title: title.isEmpty ? "Details" : title, body: parse(lines: body))))
                continue
            }

            // Heading
            if let heading = Self.heading(line) {
                flush(&paragraph, into: &blocks, &self)
                blocks.append(make(.heading(level: heading.0, text: heading.1)))
                i += 1
                continue
            }

            // Divider
            if Self.isDivider(line) {
                flush(&paragraph, into: &blocks, &self)
                blocks.append(make(.divider))
                i += 1
                continue
            }

            // Quote / callout
            if line.hasPrefix(">") {
                flush(&paragraph, into: &blocks, &self)
                var quoted: [(Int, String)] = []
                while i < lines.count {
                    let l = lines[i].1.trimmingCharacters(in: .whitespaces)
                    guard l.hasPrefix(">") else { break }
                    var stripped = String(l.dropFirst())
                    if stripped.hasPrefix(" ") { stripped.removeFirst() }
                    quoted.append((lines[i].0, stripped))
                    i += 1
                }
                if let first = quoted.first?.1, first.hasPrefix("[!"), let close = first.firstIndex(of: "]") {
                    let type = String(first[first.index(first.startIndex, offsetBy: 2)..<close])
                    var title = String(first[first.index(after: close)...]).trimmingCharacters(in: .whitespaces)
                    if title.hasPrefix("-") || title.hasPrefix("+") { title.removeFirst() }
                    let style = CalloutStyle(raw: type)
                    let body = parse(lines: Array(quoted.dropFirst()))
                    blocks.append(make(.callout(style: style, title: title.isEmpty ? style.label : title, body: body)))
                } else {
                    blocks.append(make(.quote(quoted.map(\.1).joined(separator: "\n"))))
                }
                continue
            }

            // Flashcard: Q: ... then A: ...
            if let q = Self.strip(prefixes: ["Q:", "q:"], from: line) {
                flush(&paragraph, into: &blocks, &self)
                var question = [q]
                var answer: [String] = []
                i += 1
                var inAnswer = false
                while i < lines.count {
                    let l = lines[i].1.trimmingCharacters(in: .whitespaces)
                    if l.isEmpty { if inAnswer { break } else { i += 1; continue } }
                    if let a = Self.strip(prefixes: ["A:", "a:"], from: l), !inAnswer {
                        inAnswer = true
                        answer.append(a)
                    } else if Self.strip(prefixes: ["Q:", "q:"], from: l) != nil {
                        break
                    } else if inAnswer {
                        answer.append(l)
                    } else {
                        question.append(l)
                    }
                    i += 1
                }
                blocks.append(make(.flashcard(question: question.joined(separator: " "),
                                              answer: answer.joined(separator: "\n"))))
                continue
            }

            // Quiz: ? Question, then - ( ) / - (x) options
            if line.hasPrefix("? ") || line.hasPrefix("?? ") {
                let question = String(line.drop(while: { $0 == "?" })).trimmingCharacters(in: .whitespaces)
                var options: [QuizOption] = []
                var j = i + 1
                while j < lines.count, let option = Self.quizOption(lines[j].1) {
                    options.append(option)
                    j += 1
                }
                if !options.isEmpty {
                    flush(&paragraph, into: &blocks, &self)
                    blocks.append(make(.quiz(question: question, options: options)))
                    i = j
                    continue
                }
            }

            // Table
            if line.hasPrefix("|"), i + 1 < lines.count, Self.isTableSeparator(lines[i + 1].1) {
                flush(&paragraph, into: &blocks, &self)
                let header = Self.cells(line)
                var rows: [[String]] = []
                i += 2
                while i < lines.count {
                    let l = lines[i].1.trimmingCharacters(in: .whitespaces)
                    guard l.hasPrefix("|") else { break }
                    rows.append(Self.cells(l))
                    i += 1
                }
                blocks.append(make(.table(header: header, rows: rows)))
                continue
            }

            // Lists
            if Self.listMarker(raw) != nil {
                flush(&paragraph, into: &blocks, &self)
                var items: [ListItem] = []
                let ordered = Self.listMarker(raw)!.ordered
                while i < lines.count, let marker = Self.listMarker(lines[i].1), marker.ordered == ordered {
                    items.append(ListItem(indent: marker.indent, text: marker.text, checked: marker.checked, line: lines[i].0))
                    i += 1
                }
                blocks.append(make(.list(items: items, ordered: ordered)))
                continue
            }

            // Image on its own line
            if line.hasPrefix("!["), line.hasSuffix(")"),
               let mid = line.range(of: "](") {
                flush(&paragraph, into: &blocks, &self)
                let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<mid.lowerBound])
                let src = String(line[mid.upperBound..<line.index(before: line.endIndex)])
                blocks.append(make(.image(alt: alt, source: src)))
                i += 1
                continue
            }

            // Definition: Term :: meaning
            if let range = line.range(of: " :: ") {
                flush(&paragraph, into: &blocks, &self)
                let term = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let meaning = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                blocks.append(make(.definition(term: term, meaning: meaning)))
                i += 1
                continue
            }

            paragraph.append(line)
            i += 1
            _ = lineNo
        }
        flush(&paragraph, into: &blocks, &self)
        return blocks
    }

    // MARK: Helpers

    static func heading(_ line: String) -> (Int, String)? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.first == " " else { return nil }
        return (hashes, rest.trimmingCharacters(in: .whitespaces))
    }

    static func isDivider(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let c = compact.first, "-*_".contains(c) else { return false }
        return compact.allSatisfy { $0 == c }
    }

    static func strip(prefixes: [String], from line: String) -> String? {
        for p in prefixes where line.hasPrefix(p) {
            return String(line.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    static func quizOption(_ raw: String) -> QuizOption? {
        let l = raw.trimmingCharacters(in: .whitespaces)
        for (marker, correct) in [("- ( )", false), ("- (x)", true), ("- (X)", true), ("* ( )", false), ("* (x)", true)] {
            if l.hasPrefix(marker) {
                return QuizOption(text: String(l.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces), correct: correct)
            }
        }
        return nil
    }

    static func isTableSeparator(_ raw: String) -> Bool {
        let l = raw.trimmingCharacters(in: .whitespaces)
        guard l.hasPrefix("|"), l.contains("-") else { return false }
        return l.allSatisfy { "|-: ".contains($0) }
    }

    static func cells(_ line: String) -> [String] {
        var l = line.trimmingCharacters(in: .whitespaces)
        if l.hasPrefix("|") { l.removeFirst() }
        if l.hasSuffix("|") { l.removeLast() }
        return l.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    struct Marker { var indent: Int; var ordered: Bool; var checked: Bool?; var text: String }

    static func listMarker(_ raw: String) -> Marker? {
        let spaces = raw.prefix(while: { $0 == " " || $0 == "\t" })
        let indent = spaces.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } / 2
        let l = raw.dropFirst(spaces.count)
        if quizOption(String(l)) != nil { return nil }
        var text: Substring
        var ordered = false
        if let f = l.first, "-*+".contains(f), l.dropFirst().first == " " {
            text = l.dropFirst(2)
        } else {
            let digits = l.prefix(while: \.isNumber)
            guard !digits.isEmpty else { return nil }
            let after = l.dropFirst(digits.count)
            guard let dot = after.first, ".)".contains(dot), after.dropFirst().first == " " else { return nil }
            text = after.dropFirst(2)
            ordered = true
        }
        var checked: Bool?
        if text.hasPrefix("[ ] ") { checked = false; text = text.dropFirst(4) }
        else if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") { checked = true; text = text.dropFirst(4) }
        return Marker(indent: indent, ordered: ordered, checked: checked, text: String(text))
    }
}

extension Block {
    /// Everything in this block (and nested blocks) that can be studied.
    var studyCards: [StudyCard] {
        switch kind {
        case let .flashcard(q, a):
            return [StudyCard(kind: .flashcard, front: q, back: a)]
        case let .definition(term, meaning):
            return [StudyCard(kind: .definition, front: term, back: meaning)]
        case let .quiz(q, options):
            return [StudyCard(kind: .quiz(options), front: q, back: options.filter(\.correct).map(\.text).joined(separator: "\n"))]
        case let .paragraph(text) where text.contains("{{"):
            return [StudyCard(kind: .cloze, front: text, back: text)]
        case let .list(items, _):
            return items.filter { $0.text.contains("{{") }.map { StudyCard(kind: .cloze, front: $0.text, back: $0.text) }
        case let .callout(_, _, body), let .toggle(_, body):
            return body.flatMap(\.studyCards)
        default:
            return []
        }
    }
}

struct StudyCard: Identifiable, Hashable {
    enum Kind: Hashable { case flashcard, definition, cloze, quiz([QuizOption]) }
    var kind: Kind
    var front: String
    var back: String
    var id: String { front + "→" + back }

    var label: String {
        switch kind {
        case .flashcard: "Flashcard"
        case .definition: "Definition"
        case .cloze: "Fill the gap"
        case .quiz: "Quiz"
        }
    }
}
