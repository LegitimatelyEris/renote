import Foundation

/// A parsed piece of a note. Renote understands generic Markdown plus a few
/// revision-friendly components (flashcards, quizzes, definitions, toggles, callouts).
struct Block: Identifiable, Hashable {
    let id: Int
    let kind: Kind

    indirect enum Kind: Hashable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case list(items: [ListItem], ordered: Bool)
        case quote(String)
        case callout(style: CalloutStyle, title: String, body: [Block])
        case code(language: String, text: String)
        case divider
        case table(header: [String], rows: [[String]])
        case flashcard(question: String, answer: String)
        case definition(term: String, meaning: String)
        case quiz(question: String, options: [QuizOption])
        case toggle(title: String, body: [Block])
        case image(alt: String, source: String)
    }
}

struct ListItem: Hashable {
    var indent: Int
    var text: String
    /// nil for a normal bullet, true/false for a checklist item.
    var checked: Bool?
    /// Line in the source, so a tick in Read mode can be written back.
    var line: Int
}

struct QuizOption: Hashable {
    var text: String
    var correct: Bool
}

enum CalloutStyle: String, CaseIterable, Hashable {
    case note, tip, info, important, warning, danger, example, question, summary, remember

    init(raw: String) {
        switch raw.lowercased() {
        case "hint": self = .tip
        case "caution", "attention": self = .warning
        case "error", "bug", "fail": self = .danger
        case "faq", "help": self = .question
        case "tldr", "abstract": self = .summary
        case "memo", "key", "keypoint": self = .remember
        default: self = CalloutStyle(rawValue: raw.lowercased()) ?? .note
        }
    }

    var symbol: String {
        switch self {
        case .note: "pencil"
        case .tip: "lightbulb"
        case .info: "info.circle"
        case .important: "exclamationmark.circle"
        case .warning: "exclamationmark.triangle"
        case .danger: "flame"
        case .example: "list.bullet.rectangle"
        case .question: "questionmark.circle"
        case .summary: "text.alignleft"
        case .remember: "brain"
        }
    }

    var label: String { rawValue.capitalized }
}
