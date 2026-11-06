import SwiftUI

/// A floating glass bar at the bottom of a note, like a chat composer: type a line,
/// a flashcard or a definition and press Return to add it to the end of the note.
struct Composer: View {
    var store: NoteStore
    var accent: Color

    enum Kind: String, CaseIterable, Identifiable {
        case text, flashcard, definition, todo, gap
        var id: String { rawValue }
        var label: String {
            switch self {
            case .text: "Text"
            case .flashcard: "Flashcard"
            case .definition: "Definition"
            case .todo: "To-do"
            case .gap: "Gap fill"
            }
        }
        var detail: String {
            switch self {
            case .text: "Markdown"
            case .flashcard: "Q & A"
            case .definition: "Term"
            case .todo: "Checklist"
            case .gap: "Hidden word"
            }
        }
        var symbol: String {
            switch self {
            case .text: "text.alignleft"
            case .flashcard: "rectangle.on.rectangle.angled"
            case .definition: "character.book.closed"
            case .todo: "checkmark.circle"
            case .gap: "eye.slash"
            }
        }
        var firstPrompt: String {
            switch self {
            case .text: "Add to this note"
            case .flashcard: "Question"
            case .definition: "Term"
            case .todo: "Something to do"
            case .gap: "Sentence, with the {{hidden part}} in double braces"
            }
        }
        var secondPrompt: String? {
            switch self {
            case .flashcard: "Answer"
            case .definition: "What it means"
            default: nil
            }
        }
    }

    @State private var kind: Kind = .text
    @State private var first = ""
    @State private var second = ""
    @FocusState private var focus: Field?
    enum Field { case first, second }

    private var canSend: Bool {
        !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (kind.secondPrompt == nil || !second.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(kind.firstPrompt, text: $first, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($focus, equals: .first)
                    .onSubmit { kind.secondPrompt == nil ? send() : (focus = .second) }
                if let prompt = kind.secondPrompt {
                    Divider().opacity(0.4)
                    TextField(prompt, text: $second, axis: .vertical)
                        .lineLimit(1...6)
                        .focused($focus, equals: .second)
                        .onSubmit(send)
                }
                HStack(spacing: 14) {
                    Menu {
                        ComposerTemplates(store: store)
                    } label: {
                        Image(systemName: "plus").font(.system(size: 15, weight: .medium))
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Add a component")

                    Spacer()

                    Menu {
                        Picker("Add as", selection: $kind) {
                            ForEach(Kind.allCases) { k in
                                Label(k.label, systemImage: k.symbol).tag(k)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        HStack(spacing: 4) {
                            Text(kind.label).foregroundStyle(Theme.ink)
                            Text(kind.detail).foregroundStyle(Theme.faint)
                            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.faint)
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()

                    Button(action: send) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(canSend ? Color.black : Theme.faint)
                            .frame(width: 28, height: 28)
                            .background(canSend ? Color.white : Color.white.opacity(0.12), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .help("Add to note (Return)")
                }
                .foregroundStyle(Theme.muted)
            }
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(Theme.raised, in: .rect(cornerRadius: 24))
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 8)

            Text(hint)
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
        }
        .onChange(of: kind) { focus = .first }
    }

    private var hint: String {
        kind == .gap ? "Gaps are hidden in Read mode and quizzed in Revise." : "Return adds it to the end of this note."
    }

    private func send() {
        guard canSend else { return }
        let a = first.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = second.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet: String
        switch kind {
        case .text: snippet = a
        case .flashcard: snippet = "Q: \(a)\nA: \(b)"
        case .definition: snippet = "\(a) :: \(b)"
        case .todo: snippet = "- [ ] \(a)"
        case .gap: snippet = a.contains("{{") ? a : "{{\(a)}}"
        }
        withAnimation(.snappy) { store.append(snippet) }
        first = ""
        second = ""
        focus = .first
    }
}

/// Component templates the composer's + menu drops at the end of the note.
struct ComposerTemplates: View {
    var store: NoteStore

    var body: some View {
        Button { store.append("## New section") } label: { Label("Section Heading", systemImage: "number") }
        Button { store.append("? Question\n- ( ) Wrong answer\n- (x) Right answer\n- ( ) Wrong answer") } label: { Label("Quiz", systemImage: "checklist") }
        Menu {
            ForEach(CalloutStyle.allCases, id: \.self) { style in
                Button { store.append("> [!\(style.rawValue)] \(style.label)\n> Write here") } label: { Label(style.label, systemImage: style.symbol) }
            }
        } label: { Label("Callout", systemImage: "text.bubble") }
        Button { store.append("+++ Title\nHidden details\n+++") } label: { Label("Toggle", systemImage: "chevron.right.square") }
        Button { store.append("| Column | Column |\n|---|---|\n| Cell | Cell |") } label: { Label("Table", systemImage: "tablecells") }
        Button { store.append("```\ncode\n```") } label: { Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right") }
        Button { store.append("---") } label: { Label("Divider", systemImage: "minus") }
    }
}

/// The right-hand panel, laid out like ChatGPT's Outputs / Sources cards.
struct NoteInspector: View {
    var store: NoteStore
    var accent: Color

    var body: some View {
        let blocks = store.blocks
        let cards = blocks.flatMap(\.studyCards)
        ScrollView {
            VStack(spacing: 12) {
                card(title: "Outline", action: { store.append("## New section") }) {
                    let headings = blocks.compactMap { b -> (Int, Int, String)? in
                        if case let .heading(level, text) = b.kind, level <= 3 { return (b.id, level, text) }
                        return nil
                    }
                    if headings.isEmpty {
                        Text("Add a heading to see it here").foregroundStyle(Theme.faint)
                    } else {
                        ForEach(headings, id: \.0) { id, level, text in
                            Button {
                                store.mode = .read
                                Task { try? await Task.sleep(for: .milliseconds(80)); store.jumpTarget = id }
                            } label: {
                                Text(Inline.plain(text))
                                    .foregroundStyle(level == 1 ? Theme.ink : Theme.muted)
                                    .lineLimit(1)
                                    .padding(.leading, CGFloat(level - 1) * 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                card(title: "Revise", action: { store.append("Q: Question\nA: Answer") }) {
                    if cards.isEmpty {
                        Text("Flashcards, definitions, quizzes and gaps show up here").foregroundStyle(Theme.faint)
                    } else {
                        let counts = Dictionary(grouping: cards, by: \.label).mapValues(\.count)
                        ForEach(counts.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key).foregroundStyle(Theme.muted)
                                Spacer()
                                Text("\(counts[key]!)").foregroundStyle(Theme.faint).monospacedDigit()
                            }
                        }
                        Button { store.mode = .revise } label: {
                            Text("Revise \(cards.count) cards")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(.white, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }

                card(title: "Note") {
                    let words = store.text.split { $0.isWhitespace || $0.isNewline }.count
                    detail("Words", "\(words)")
                    detail("Reading time", "\(max(1, words / 200)) min")
                    if let note = store.notes.first(where: { $0.url == store.selection }) {
                        detail("Subject", note.subject ?? "None")
                        detail("Edited", note.modified.formatted(.relative(presentation: .named)))
                    }
                    Button("Show in Finder") { store.revealInFinder() }
                        .buttonStyle(.plain)
                        .foregroundStyle(accent)
                        .padding(.top, 2)
                }
            }
            .padding(12)
        }
        .font(.system(size: 13))
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.faint)
            Spacer()
            Text(value).foregroundStyle(Theme.muted)
        }
    }

    private func card<Content: View>(title: String, action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink)
                Spacer()
                if let action {
                    Button(action: action) { Image(systemName: "plus").foregroundStyle(Theme.muted) }
                        .buttonStyle(.plain)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.raised, in: .rect(cornerRadius: 16))
    }
}
