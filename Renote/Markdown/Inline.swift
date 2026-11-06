import SwiftUI

/// Turns inline Markdown (plus Renote extras) into an AttributedString.
///
/// Supported: **bold**, *italic*, _italic_, ~~strike~~, `code`, ==highlight==,
/// ++underline++, [link](url), {{cloze}}, {red|coloured text}, ^^small caps^^.
enum Inline {
    struct Options {
        var accent: Color
        var revealCloze: Bool = true
        var clozeHiddenColor: Color = .clear
    }

    static let palette: [String: Color] = [
        "red": .red, "orange": .orange, "yellow": .yellow, "green": .green,
        "mint": .mint, "teal": .teal, "blue": .blue, "indigo": .indigo,
        "purple": .purple, "pink": .pink, "brown": .brown, "gray": .gray, "grey": .gray,
    ]

    static func render(_ text: String, _ options: Options) -> AttributedString {
        render(Substring(text), options)
    }

    /// Plain text with markers removed (used for titles and search).
    static func plain(_ text: String) -> String {
        String(render(text, Options(accent: .accentColor)).characters)
    }

    private static let pairs: [(open: String, close: String)] = [
        ("`", "`"), ("{{", "}}"), ("**", "**"), ("__", "__"), ("~~", "~~"), ("==", "=="),
        ("++", "++"), ("^^", "^^"), ("*", "*"), ("_", "_"),
    ]

    private static func render(_ s: Substring, _ o: Options) -> AttributedString {
        var out = AttributedString()
        var buffer = ""
        var i = s.startIndex

        func flushBuffer() {
            if !buffer.isEmpty { out += AttributedString(buffer); buffer = "" }
        }

        outer: while i < s.endIndex {
            let rest = s[i...]

            // Escapes
            if rest.hasPrefix("\\"), let next = s.index(i, offsetBy: 1, limitedBy: s.endIndex), next < s.endIndex {
                buffer.append(s[next])
                i = s.index(after: next)
                continue
            }

            // Links [text](url)
            if rest.hasPrefix("["), let closeBracket = rest.range(of: "]("),
               let closeParen = rest[closeBracket.upperBound...].firstIndex(of: ")") {
                let label = rest[rest.index(after: rest.startIndex)..<closeBracket.lowerBound]
                let url = String(rest[closeBracket.upperBound..<closeParen])
                if !label.contains("]") {
                    flushBuffer()
                    var piece = render(label, o)
                    if let u = URL(string: url) { piece.link = u }
                    piece.foregroundColor = o.accent
                    piece.underlineStyle = .single
                    out += piece
                    i = rest.index(after: closeParen)
                    continue
                }
            }

            // Colour: {red|text}
            if rest.hasPrefix("{"), !rest.hasPrefix("{{"), let bar = rest.firstIndex(of: "|"),
               let close = rest[bar...].firstIndex(of: "}") {
                let name = rest[rest.index(after: rest.startIndex)..<bar].lowercased()
                if let color = palette[name] {
                    flushBuffer()
                    var piece = render(rest[rest.index(after: bar)..<close], o)
                    piece.foregroundColor = color
                    out += piece
                    i = rest.index(after: close)
                    continue
                }
            }

            for pair in pairs where rest.hasPrefix(pair.open) {
                let contentStart = rest.index(rest.startIndex, offsetBy: pair.open.count)
                guard contentStart < rest.endIndex,
                      !rest[contentStart].isWhitespace || pair.open == "`",
                      let close = rest[contentStart...].range(of: pair.close),
                      close.lowerBound > contentStart
                else { continue }
                // Single _ inside words (snake_case) is not emphasis.
                if pair.open == "_", i > s.startIndex, s[s.index(before: i)].isLetter { continue }

                flushBuffer()
                let inner = rest[contentStart..<close.lowerBound]
                var piece: AttributedString
                switch pair.open {
                case "`":
                    // A padded grey pill, like inline code in ChatGPT.
                    piece = AttributedString("\u{2009}" + String(inner) + "\u{2009}")
                    piece.inlinePresentationIntent = .code
                    piece.backgroundColor = Color.white.opacity(0.10)
                    piece.foregroundColor = Color(white: 0.92)
                case "{{":
                    piece = render(inner, o)
                    piece.backgroundColor = o.accent.opacity(o.revealCloze ? 0.18 : 0.85)
                    if !o.revealCloze {
                        piece.foregroundColor = o.clozeHiddenColor
                    } else {
                        piece.foregroundColor = o.accent
                    }
                    piece = AttributedString("\u{2009}") + piece + AttributedString("\u{2009}")
                case "**", "__":
                    piece = render(inner, o)
                    applyIntent(.stronglyEmphasized, to: &piece)
                    // Bold lifts out of the grey body text to full white.
                    for run in piece.runs where piece[run.range].foregroundColor == nil {
                        piece[run.range].foregroundColor = .white
                    }
                case "~~":
                    piece = render(inner, o)
                    piece.strikethroughStyle = .single
                case "==":
                    piece = render(inner, o)
                    piece.backgroundColor = Color(red: 1, green: 0.78, blue: 0.3).opacity(0.22)
                    for run in piece.runs where piece[run.range].foregroundColor == nil {
                        piece[run.range].foregroundColor = Color(red: 1, green: 0.88, blue: 0.6)
                    }
                case "++":
                    piece = render(inner, o)
                    piece.underlineStyle = Text.LineStyle(pattern: .solid, color: o.accent)
                case "^^":
                    piece = AttributedString(Inline.plain(String(inner)).uppercased())
                    piece.kern = 1.2
                    piece.foregroundColor = Color.secondary
                default: // * and _
                    piece = render(inner, o)
                    applyIntent(.emphasized, to: &piece)
                }
                out += piece
                i = close.upperBound
                continue outer
            }

            buffer.append(s[i])
            i = s.index(after: i)
        }
        flushBuffer()
        return out
    }

    /// Adds an intent to every run without clobbering nested intents (bold inside italic).
    private static func applyIntent(_ intent: InlinePresentationIntent, to piece: inout AttributedString) {
        for run in piece.runs {
            let existing = piece[run.range].inlinePresentationIntent ?? []
            piece[run.range].inlinePresentationIntent = existing.union(intent)
        }
    }
}
