import SwiftUI

/// One note as a page. View reads it, Edit types straight onto it, Revise tests you.
/// A dock in the bottom-right corner switches between them.
struct NotePage: View {
    @Bindable var store: NoteStore
    @State private var showLook = false
    @State private var editorCaretLine: Int?
    @State private var renaming = false
    @State private var newName = ""

    var body: some View {
        let blocks = MarkdownParser.parse(store.text)
        let cards = blocks.flatMap(\.studyCards)
        ZStack(alignment: .bottomTrailing) {
            Group {
                switch store.mode {
                case .view:
                    PageReader(store: store, blocks: blocks, cardCount: cards.count) { line in
                        editorCaretLine = line
                        store.mode = .edit
                    }
                case .edit:
                    PageEditor(store: store, caretLine: $editorCaretLine)
                case .revise:
                    ReviseDeck(store: store, cards: cards)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Dock(store: store, cardCount: cards.count, showLook: $showLook, renaming: $renaming, newName: $newName)
                .padding(22)
        }
        .alert("Rename note", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Rename") { if let note = store.currentNote { store.rename(note, to: newName) } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// Meta line above a page: subject, reading time, edited, cards to revise.
struct PageMeta: View {
    var store: NoteStore
    var cardCount: Int

    var body: some View {
        let words = store.text.split { $0.isWhitespace || $0.isNewline }.count
        HStack(spacing: 10) {
            if let subject = store.currentNote?.subject {
                Button(subject) { store.screen = .home(subject: subject) }.buttonStyle(.plain)
                dot
            }
            Text("\(max(1, words / 200)) min read")
            dot
            if let note = store.currentNote {
                Text("Edited \(note.modified.formatted(.relative(presentation: .named)))")
            }
            if cardCount > 0 {
                dot
                Button("\(cardCount) to revise") { store.mode = .revise }.buttonStyle(.plain).foregroundStyle(store.look.accentLight)
            }
        }
        .font(.system(size: 13)).foregroundStyle(Theme.faint)
    }

    private var dot: some View { Circle().fill(Theme.faint).frame(width: 3, height: 3) }
}

// MARK: - View mode

struct PageReader: View {
    var store: NoteStore
    var blocks: [Block]
    var cardCount: Int
    var editAt: (Int) -> Void

    var body: some View {
        let look = store.look
        GeometryReader { geo in
            let column = columnWidth(geo.size.width, look)
            ScrollView {
                VStack(alignment: .leading, spacing: look.size * 1.05) {
                    PageMeta(store: store, cardCount: cardCount).padding(.bottom, 4)
                    let sections = Self.sectionNumbers(blocks)
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        BlockView(block: block, store: store, section: sections[block.id],
                                  isLede: index == 1 && Self.isTitle(blocks.first))
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { editAt(block.line) }
                    }
                    if blocks.isEmpty {
                        Text("This page is empty. Press ⌘E or the Edit switch to start writing.")
                            .font(look.body.font(look.size)).foregroundStyle(Theme.faint)
                            .onTapGesture(count: 2) { editAt(0) }
                    }
                }
                .frame(width: column, alignment: .leading)
                .padding(.top, 72).padding(.bottom, 180)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.automatic)
        }
    }

    static func isTitle(_ b: Block?) -> Bool { if case .heading(1, _) = b?.kind { return true }; return false }

    static func sectionNumbers(_ blocks: [Block]) -> [Int: Int] {
        var r: [Int: Int] = [:], n = 0
        for b in blocks { if case .heading(2, _) = b.kind { n += 1; r[b.id] = n } }
        return r
    }
}

/// The reading column: your chosen width, with room left for section numbers.
func columnWidth(_ available: CGFloat, _ look: LookSettings) -> CGFloat {
    let room = max(320, available - 168)
    return look.isFullWidth ? room : min(look.width, room)
}

struct BlockView: View {
    var block: Block
    var store: NoteStore
    var section: Int? = nil
    var isLede = false

    var body: some View {
        let look = store.look
        let accent = look.accentColor
        switch block.kind {
        case let .heading(level, text):
            heading(level, text, look)
        case let .paragraph(text):
            if text.contains("{{") {
                GapParagraph(text: text, look: look, lede: isLede)
            } else {
                Text(Inline.render(text, .init(accent: accent)))
                    .font(look.body.font(look.size * (isLede ? 1.2 : 1)))
                    .foregroundStyle(isLede ? Theme.muted : Theme.body)
                    .lineSpacing(look.size * (look.leading - 1.2))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case let .list(items, ordered):
            ListBlock(items: items, ordered: ordered, store: store)
        case let .quote(text):
            HStack(alignment: .top, spacing: 16) {
                Rectangle().fill(accent).frame(width: 2)
                Text(Inline.render(text, .init(accent: accent))).italic()
                    .font(look.body.font(look.size)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case let .callout(style, title, body):
            CalloutView(style: style, title: title, content: body, store: store)
        case let .code(language, text):
            CodeBlock(language: language, text: text)
        case .divider:
            Line().stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(height: 1).padding(.vertical, 18)
        case let .table(header, rows):
            TableBlock(header: header, rows: rows, look: look)
        case let .flashcard(q, a):
            FlashcardView(question: q, answer: a, look: look)
        case let .definition(term, meaning):
            DefinitionRow(term: term, meaning: meaning, look: look)
        case let .quiz(q, options):
            QuizView(question: q, options: options, look: look)
        case let .toggle(title, body):
            ToggleBlock(title: title, content: body, store: store)
        case let .image(alt, source):
            ImageBlock(alt: alt, source: source, folder: store.current?.deletingLastPathComponent())
        }
    }

    @ViewBuilder
    private func heading(_ level: Int, _ text: String, _ look: LookSettings) -> some View {
        let rendered = Inline.render(text, .init(accent: look.accentColor))
        switch level {
        case 1:
            Text(rendered).font(look.head.font(look.size * 3, .medium)).tracking(-look.size * 0.075)
                .foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
        case 2:
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(Theme.line).frame(height: 1).padding(.bottom, look.size)
                Text(rendered).font(look.head.font(look.size * 1.65, .medium)).tracking(-look.size * 0.03)
                    .foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
                    .overlay(alignment: .topLeading) {
                        if let section {
                            Text(String(format: "%02d", section)).font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(look.accentColor).offset(x: -64, y: look.size * 0.4)
                        }
                    }
            }
            .padding(.top, look.size * 1.2)
        case 3:
            Text(rendered).font(look.head.font(look.size * 1.25, .medium)).foregroundStyle(Theme.text).padding(.top, look.size * 0.6)
        default:
            Text(rendered).font(.system(size: 12, weight: .semibold)).textCase(.uppercase).tracking(1).foregroundStyle(Theme.faint)
        }
    }
}

nonisolated struct Line: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p }
}

// MARK: - Dock

struct Dock: View {
    @Bindable var store: NoteStore
    var cardCount: Int
    @Binding var showLook: Bool
    @Binding var renaming: Bool
    @Binding var newName: String

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                seg("View", "book", .view)
                seg("Edit", "pencil", .edit)
            }
            .padding(2)
            .background(Color.white.opacity(0.04), in: .rect(cornerRadius: 10))
            Rectangle().fill(Theme.line).frame(width: 1, height: 20).padding(.horizontal, 3)
            Button { showLook.toggle() } label: {
                Text("Aa").font(.system(size: 14, weight: .semibold)).frame(minWidth: 32, minHeight: 32)
            }
            .buttonStyle(DockButtonStyle(on: showLook))
            .help("Fonts, layout and window colour")
            .popover(isPresented: $showLook, arrowEdge: .top) { LookPanel(store: store) }
            Button { store.mode = .revise } label: {
                Image(systemName: "rectangle.on.rectangle").font(.system(size: 13)).frame(width: 32, height: 32)
                    .overlay(alignment: .topTrailing) {
                        if cardCount > 0 {
                            Text("\(cardCount)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.black)
                                .padding(.horizontal, 4).frame(minWidth: 16, minHeight: 16)
                                .background(store.look.accentColor, in: .capsule).offset(x: 4, y: -4)
                        }
                    }
            }
            .buttonStyle(DockButtonStyle(on: store.mode == .revise))
            .help("Revise this note")
            Menu {
                Button(store.sidebarHidden ? "Show Sidebar" : "Hide Sidebar") { withAnimation(.snappy) { store.sidebarHidden.toggle() } }
                Button("Rename…") { newName = store.currentNote?.url.deletingPathExtension().lastPathComponent ?? ""; renaming = true }
                Button("Show in Finder") { store.revealInFinder() }
                Divider()
                Button("Move to Trash", role: .destructive) { if let n = store.currentNote { store.trash(n) } }
            } label: {
                Image(systemName: "line.3.horizontal").font(.system(size: 13)).frame(width: 32, height: 32)
            }
            .menuStyle(.button).menuIndicator(.hidden).buttonStyle(DockButtonStyle(on: false)).fixedSize()
        }
        .padding(5)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        .background(Color(white: 0.08).opacity(0.7), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.5), radius: 25, y: 12)
    }

    private func seg(_ title: String, _ icon: String, _ mode: NoteMode) -> some View {
        let on = store.mode == mode
        return Button { store.mode = mode } label: {
            Label(title, systemImage: icon).font(.system(size: 13))
                .foregroundStyle(on ? Color(white: 0.07) : Theme.muted)
                .padding(.horizontal, 12).frame(height: 30)
                .background(on ? Color.white : .clear, in: .rect(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(title) (⌘E)")
    }
}

struct DockButtonStyle: ButtonStyle {
    var on: Bool
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(on || hover ? Theme.text : Theme.muted)
            .background(on || hover ? Color.white.opacity(0.08) : .clear, in: .rect(cornerRadius: 8))
            .onHover { hover = $0 }
    }
}

// MARK: - Look panel

struct LookPanel: View {
    @Bindable var store: NoteStore
    @State private var tab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Look").font(.system(size: 14, weight: .medium))
                Spacer()
                Button("Reset") { store.look = LookSettings() }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.faint)
            }
            Picker("", selection: $tab) {
                Text("Headings").tag(0)
                Text("Body").tag(1)
            }
            .pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(PageFont.allCases) { f in
                        let on = (tab == 0 ? store.look.head : store.look.body) == f
                        Button {
                            if tab == 0 { store.look.head = f } else { store.look.body = f }
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(f.rawValue).font(f.font(17))
                                Spacer()
                                Text(f.note).font(.system(size: 11)).foregroundStyle(Theme.faint)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(on ? store.look.accentColor.opacity(0.15) : .clear, in: .rect(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(on ? store.look.accentColor.opacity(0.6) : .clear))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 230)

            slider("Size", $store.look.size, 14...22, step: 1) { "\(Int($0))px" }
            slider("Width", $store.look.width, 560...1500, step: 20) { $0 >= 1500 ? "Full" : "\(Int($0))" }
            slider("Spacing", $store.look.leading, 1.4...2.1, step: 0.05) { String(format: "%.2f", $0) }
            HStack(alignment: .top) {
                Text("Accent").frame(width: 62, alignment: .leading).foregroundStyle(Theme.muted)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 7), count: 8), alignment: .leading, spacing: 7) {
                    ForEach(LookSettings.accents, id: \.0) { name, color in
                        Button { store.look.accent = name } label: {
                            Circle().fill(color).frame(width: 20, height: 20)
                                .overlay(Circle().strokeBorder(.white, lineWidth: store.look.accent == name ? 2 : 0).padding(-3))
                        }
                        .buttonStyle(.plain).help(name)
                    }
                }
            }

            Divider().padding(.vertical, 4)
            Text("Window").font(.system(size: 12)).foregroundStyle(Theme.faint)
            HStack(alignment: .top) {
                Text("Colour").frame(width: 62, alignment: .leading).foregroundStyle(Theme.muted)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 7), count: 8), alignment: .leading, spacing: 7) {
                    ForEach(LookSettings.windowColors, id: \.self) { hex in
                        Button { store.look.bg = hex } label: {
                            RoundedRectangle(cornerRadius: 6).fill(Color(hex: hex)).frame(width: 20, height: 20)
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(store.look.bg == hex ? 1 : 0.2), lineWidth: store.look.bg == hex ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                    ColorPicker("", selection: Binding(get: { store.look.windowColor }, set: { store.look.bg = $0.hex }), supportsOpacity: false)
                        .labelsHidden().frame(width: 20, height: 20)
                }
            }
            slider("Opacity", $store.look.bgAlpha, 0...1, step: 0.01) { "\(Int(($0 * 100).rounded()))%" }
        }
        .font(.system(size: 13))
        .padding(14)
        .frame(width: 320)
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, step: Double, format: @escaping (Double) -> String) -> some View {
        HStack(spacing: 10) {
            Text(label).frame(width: 62, alignment: .leading).foregroundStyle(Theme.muted)
            Slider(value: value, in: range, step: step)
            Text(format(value.wrappedValue)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.faint).frame(width: 44, alignment: .trailing)
        }
    }
}
