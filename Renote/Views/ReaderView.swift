import SwiftUI

/// Read mode: the note laid out as a calm, typographic page.
struct ReaderView: View {
    @Bindable var store: NoteStore
    var accent: Color

    var body: some View {
        let blocks = store.blocks
        let cards = blocks.flatMap(\.studyCards).count
        let words = store.text.split { $0.isWhitespace || $0.isNewline }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Text("\(max(1, words / 200)) min read")
                    if cards > 0 {
                        Text("·")
                        Button { store.mode = .revise } label: {
                            Label("\(cards) to revise", systemImage: "rectangle.on.rectangle.angled")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(accent)
                    }
                }
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, -6)

                BlockList(blocks: blocks, accent: accent, store: store, numberSections: true)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 44)
            .frame(maxWidth: .infinity)
        }
        .textSelection(.enabled)
    }
}

struct BlockList: View {
    var blocks: [Block]
    var accent: Color
    var store: NoteStore?
    var numberSections = false

    var body: some View {
        let sectionNumbers = numberSections ? Self.sectionNumbers(blocks) : [:]
        ForEach(blocks) { block in
            BlockView(block: block, accent: accent, store: store, section: sectionNumbers[block.id])
        }
    }

    static func sectionNumbers(_ blocks: [Block]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        var n = 0
        for b in blocks {
            if case .heading(2, _) = b.kind { n += 1; result[b.id] = n }
        }
        return result
    }
}

struct BlockView: View {
    var block: Block
    var accent: Color
    var store: NoteStore?
    var section: Int?

    var body: some View {
        switch block.kind {
        case let .heading(level, text):
            HeadingView(level: level, text: text, accent: accent, section: section)
        case let .paragraph(text):
            if text.contains("{{") {
                ClozeParagraph(text: text, accent: accent)
            } else {
                Text(Inline.render(text, .init(accent: accent)))
                    .font(Theme.body)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case let .list(items, ordered):
            ListBlock(items: items, ordered: ordered, accent: accent, store: store)
        case let .quote(text):
            HStack(alignment: .top, spacing: 14) {
                Capsule().fill(accent.opacity(0.5)).frame(width: 3)
                Text(Inline.render(text, .init(accent: accent)))
                    .font(Theme.body.italic())
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        case let .callout(style, title, body):
            CalloutView(style: style, title: title, body: body, accent: accent, store: store)
        case let .code(language, text):
            CodeBlock(language: language, text: text)
        case .divider:
            HStack(spacing: 8) {
                ForEach(0..<3) { _ in Circle().fill(.tertiary).frame(width: 4, height: 4) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        case let .table(header, rows):
            TableBlock(header: header, rows: rows, accent: accent)
        case let .flashcard(q, a):
            FlashcardView(question: q, answer: a, accent: accent)
        case let .definition(term, meaning):
            DefinitionView(term: term, meaning: meaning, accent: accent)
        case let .quiz(q, options):
            QuizView(question: q, options: options, accent: accent)
        case let .toggle(title, body):
            ToggleBlock(title: title, body: body, accent: accent, store: store)
        case let .image(alt, source):
            ImageBlock(alt: alt, source: source, folder: store?.folder)
        }
    }
}

// MARK: - Text blocks

struct HeadingView: View {
    var level: Int
    var text: String
    var accent: Color
    var section: Int?

    var body: some View {
        let rendered = Inline.render(text, .init(accent: accent))
        switch level {
        case 1:
            Text(rendered)
                .font(.system(size: 38, weight: .bold, design: .serif))
                .tracking(-0.5)
                .padding(.bottom, 4)
        case 2:
            VStack(alignment: .leading, spacing: 6) {
                if let section {
                    Text(String(format: "%02d", section))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(accent)
                }
                Text(rendered)
                    .font(.system(size: 25, weight: .semibold, design: .serif))
            }
            .padding(.top, 22)
        case 3:
            Text(rendered)
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .padding(.top, 10)
        default:
            Text(rendered)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }
}

struct ClozeParagraph: View {
    var text: String
    var accent: Color
    @State private var revealed = false

    var body: some View {
        Text(Inline.render(text, .init(accent: accent, revealCloze: revealed)))
            .font(Theme.body)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { revealed.toggle() } }
            .help(revealed ? "Click to hide the gaps" : "Click to reveal the gaps")
    }
}

struct ListBlock: View {
    var items: [ListItem]
    var ordered: Bool
    var accent: Color
    var store: NoteStore?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    marker(for: item, index: index)
                    Group {
                        if item.text.contains("{{") {
                            ClozeParagraph(text: item.text, accent: accent)
                        } else {
                            Text(Inline.render(item.text, .init(accent: accent)))
                                .font(Theme.body)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .foregroundStyle(item.checked == true ? .secondary : .primary)
                    .strikethrough(item.checked == true, color: .secondary)
                }
                .padding(.leading, CGFloat(item.indent) * 22)
            }
        }
    }

    @ViewBuilder
    private func marker(for item: ListItem, index: Int) -> some View {
        if let checked = item.checked {
            Button {
                withAnimation(.snappy) { store?.toggleChecklist(line: item.line) }
            } label: {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(checked ? accent : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        } else if ordered {
            Text("\(index + 1)")
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(accent)
                .frame(minWidth: 16, alignment: .trailing)
        } else {
            Circle()
                .fill(item.indent == 0 ? accent : accent.opacity(0.4))
                .frame(width: 6, height: 6)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                .frame(width: 16)
        }
    }
}

struct CodeBlock: View {
    var language: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !language.isEmpty {
                Text(language.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.045), in: .rect(cornerRadius: 12))
    }
}

struct TableBlock: View {
    var header: [String]
    var rows: [[String]]
    var accent: Color

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 0) {
            GridRow {
                ForEach(header.indices, id: \.self) { i in
                    Text(Inline.render(header[i], .init(accent: accent)))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 10)
                }
            }
            ForEach(rows.indices, id: \.self) { r in
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    ForEach(header.indices, id: \.self) { c in
                        Text(Inline.render(c < rows[r].count ? rows[r][c] : "", .init(accent: accent)))
                            .font(.system(size: 15))
                            .padding(.vertical, 10)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .background(.primary.opacity(0.03), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.07)))
    }
}

struct ImageBlock: View {
    var alt: String
    var source: String
    var folder: URL?

    var body: some View {
        VStack(spacing: 8) {
            if let url = resolved {
                if url.isFileURL, let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFit()
                        .clipShape(.rect(cornerRadius: 12))
                } else {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit().clipShape(.rect(cornerRadius: 12))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(.quaternary).frame(height: 160)
                    }
                }
            }
            if !alt.isEmpty {
                Text(alt).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var resolved: URL? {
        if source.hasPrefix("http") { return URL(string: source) }
        if source.hasPrefix("/") { return URL(fileURLWithPath: source) }
        return folder?.appendingPathComponent(source)
    }
}

enum Theme {
    static let body = Font.system(size: 17, design: .serif)
}
