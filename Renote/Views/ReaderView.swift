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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.faint)
                .padding(.bottom, -6)

                BlockList(blocks: blocks, accent: accent, store: store, numberSections: true)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 44)
            .padding(.vertical, 56)
            .background { ColumnGuides() }
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background { Backdrop(accent: accent) }
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
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case let .list(items, ordered):
            ListBlock(items: items, ordered: ordered, accent: accent, store: store)
        case let .quote(text):
            HStack(alignment: .top, spacing: 14) {
                Capsule().fill(accent.opacity(0.5)).frame(width: 3)
                Text(Inline.render(text, .init(accent: accent)))
                    .font(Theme.body.italic())
                    .foregroundStyle(Theme.muted)
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
                ForEach(0..<3) { _ in Circle().fill(Theme.faint).frame(width: 3, height: 3) }
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
                .font(Theme.display(44, .semibold))
                .tracking(-1.2)
                .foregroundStyle(
                    LinearGradient(colors: [.white, Color(white: 0.72)], startPoint: .top, endPoint: .bottom)
                )
                .padding(.bottom, 6)
                .modifier(BlurReveal())
        case 2:
            VStack(alignment: .leading, spacing: 8) {
                if let section {
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", section))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accent)
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }
                }
                Text(rendered)
                    .font(Theme.display(28, .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.ink)
            }
            .padding(.top, 28)
            .modifier(BlurReveal())
        case 3:
            Text(rendered)
                .font(Theme.display(19, .semibold))
                .tracking(-0.3)
                .foregroundStyle(Theme.ink)
                .padding(.top, 10)
        default:
            Text(rendered)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Theme.faint)
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
            .foregroundStyle(Theme.muted)
            .lineSpacing(6)
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
                    .foregroundStyle(item.checked == true ? Theme.faint : Theme.muted)
                    .strikethrough(item.checked == true, color: Theme.faint)
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
                    .foregroundStyle(checked ? accent : Theme.faint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        } else if ordered {
            Text("\(index + 1)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.faint)
                .frame(minWidth: 16, alignment: .trailing)
        } else {
            RoundedRectangle(cornerRadius: 1)
                .fill(item.indent == 0 ? Theme.muted : Theme.faint)
                .frame(width: 8, height: 1.5)
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
        .foregroundStyle(Color(white: 0.85))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.5), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline))
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
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(Theme.faint)
                        .padding(.vertical, 12)
                }
            }
            ForEach(rows.indices, id: \.self) { r in
                Rectangle().fill(Theme.hairline).frame(height: 1).gridCellUnsizedAxes(.horizontal)
                GridRow {
                    ForEach(header.indices, id: \.self) { c in
                        Text(Inline.render(c < rows[r].count ? rows[r][c] : "", .init(accent: accent)))
                            .font(.system(size: 14))
                            .foregroundStyle(c == 0 ? Theme.ink : Theme.muted)
                            .padding(.vertical, 12)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .background(Theme.surface, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline))
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

/// Dark, quiet palette: near-black canvas, hairlines, grey body text with white emphasis.
enum Theme {
    static let body = Font.system(size: 16, weight: .regular)
    static let canvas = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let ink = Color.white
    static let muted = Color(white: 0.62)
    static let faint = Color(white: 0.38)
    static let surface = Color.white.opacity(0.035)
    static let hairline = Color.white.opacity(0.08)

    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
}

/// The page backdrop: black, a soft light bleeding from the top corner, a few specks.
struct Backdrop: View {
    var accent: Color

    var body: some View {
        ZStack {
            Theme.canvas
            RadialGradient(colors: [Color.white.opacity(0.10), .clear], center: .topLeading, startRadius: 0, endRadius: 700)
            RadialGradient(colors: [accent.opacity(0.10), .clear], center: .top, startRadius: 0, endRadius: 520)
                .offset(y: -200)
            Canvas { ctx, size in
                var rng = SplitMix(seed: 7)
                for _ in 0..<70 {
                    let p = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
                    let r = 0.5 + rng.next() * 0.9
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: r, height: r)),
                             with: .color(.white.opacity(0.08 + rng.next() * 0.22)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Dashed vertical guides either side of the reading column.
struct ColumnGuides: View {
    var body: some View {
        HStack {
            dashed
            Spacer()
            dashed
        }
        .allowsHitTesting(false)
    }

    private var dashed: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 1)
            .overlay(
                Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: 0, y: 4000)) }
                    .stroke(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            )
            .clipped()
    }
}

/// Deterministic random numbers so the specks don't jump between redraws.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}

/// Text that sharpens out of a blur as it scrolls into view.
struct BlurReveal: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollTransition(.animated(.smooth(duration: 0.6)).threshold(.visible(0.2))) { view, phase in
            view.blur(radius: phase.isIdentity ? 0 : 8)
                .opacity(phase.isIdentity ? 1 : 0.25)
                .offset(y: phase.isIdentity ? 0 : 8)
        }
    }
}
