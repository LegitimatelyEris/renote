import AppKit
import SwiftUI

extension CalloutStyle {
    var tint: Color {
        switch self {
        case .note: Color(white: 0.7)
        case .tip: Color(hex: "#4ade80")
        case .info: Color(hex: "#60a5fa")
        case .important: Color(hex: "#c084fc")
        case .warning: Color(hex: "#fb923c")
        case .danger: Color(hex: "#f87171")
        case .example: Color(hex: "#2dd4bf")
        case .question: Color(hex: "#818cf8")
        case .summary: Color(hex: "#5eead4")
        case .remember: Color(hex: "#f472b6")
        }
    }
}

/// Body text with hidden gaps; click to reveal them.
struct GapParagraph: View {
    var text: String
    var look: LookSettings
    var lede = false
    @State private var revealed = false

    var body: some View {
        Text(Inline.render(text, .init(accent: look.accentColor, revealCloze: revealed)))
            .font(look.body.font(look.size * (lede ? 1.2 : 1)))
            .foregroundStyle(Theme.body)
            .lineSpacing(look.size * (look.leading - 1.2))
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { revealed.toggle() } }
            .help(revealed ? "Click to hide the gaps" : "Click to reveal the gaps")
    }
}

struct ListBlock: View {
    var items: [ListItem]
    var ordered: Bool
    var store: NoteStore

    var body: some View {
        let look = store.look
        VStack(alignment: .leading, spacing: look.size * 0.35) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if let checked = item.checked {
                        Button { withAnimation(.snappy) { store.toggleChecklist(line: item.line) } } label: {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(checked ? look.accentColor : .clear)
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(checked ? look.accentColor : Color.white.opacity(0.3)))
                                .overlay { if checked { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.black) } }
                                .frame(width: 17, height: 17)
                                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                        }
                        .buttonStyle(.plain)
                    } else if ordered {
                        Text("\(index + 1)").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.faint).frame(minWidth: 16, alignment: .trailing)
                    } else {
                        Rectangle().fill(Theme.faint).frame(width: 10, height: 1.5).alignmentGuide(.firstTextBaseline) { $0[.bottom] + look.size * 0.3 }
                    }
                    Group {
                        if item.text.contains("{{") { GapParagraph(text: item.text, look: look) }
                        else {
                            Text(Inline.render(item.text, .init(accent: look.accentColor)))
                                .font(look.body.font(look.size)).lineSpacing(look.size * (look.leading - 1.3))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .foregroundStyle(item.checked == true ? Theme.faint : Theme.body)
                    .strikethrough(item.checked == true, color: Theme.faint)
                }
                .padding(.leading, CGFloat(item.indent) * 22)
            }
        }
    }
}

struct CalloutView: View {
    var style: CalloutStyle
    var title: String
    var content: [Block]
    var store: NoteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: style.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(style.tint)
                    .frame(width: 24, height: 24).background(style.tint.opacity(0.15), in: .rect(cornerRadius: 7))
                Text(Inline.render(title, .init(accent: style.tint))).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text)
            }
            ForEach(content) { b in BlockView(block: b, store: store) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(glow: style.tint)
    }
}

struct CodeBlock: View {
    var language: String
    var text: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(language.isEmpty ? "code" : language, systemImage: "chevron.left.forwardslash.chevron.right")
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: { Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") }
                .buttonStyle(.plain)
            }
            .font(.system(size: 12)).foregroundStyle(Theme.faint)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.lineSoft).frame(height: 1) }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text).font(.system(size: 13, design: .monospaced)).foregroundStyle(Color(white: 0.83)).lineSpacing(5)
                    .padding(.horizontal, 16).padding(.vertical, 14).textSelection(.enabled)
            }
        }
        .panel()
    }
}

struct TableBlock: View {
    var header: [String]
    var rows: [[String]]
    var look: LookSettings

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(header.indices, id: \.self) { i in
                    Text(Inline.render(header[i], .init(accent: look.accentColor))).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.faint)
                        .padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            ForEach(rows.indices, id: \.self) { r in
                Rectangle().fill(r == 0 ? Theme.line : Theme.lineSoft).frame(height: 1).gridCellUnsizedAxes(.horizontal)
                GridRow {
                    ForEach(header.indices, id: \.self) { c in
                        Text(Inline.render(c < rows[r].count ? rows[r][c] : "", .init(accent: look.accentColor)))
                            .font(.system(size: 14)).foregroundStyle(c == 0 ? Theme.text : Theme.muted)
                            .padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .panel()
    }
}

struct FlashcardView: View {
    var question: String
    var answer: String
    var look: LookSettings
    @State private var flipped = false

    var body: some View {
        ZStack {
            face(answer: false).opacity(flipped ? 0 : 1)
            face(answer: true).opacity(flipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0), perspective: 0.4)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(duration: 0.55, bounce: 0.15)) { flipped.toggle() } }
        .help("Click to flip")
    }

    private func face(answer: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(answer ? "Answer" : "Question").font(.system(size: 12))
                Spacer()
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90").font(.system(size: 11))
            }
            .foregroundStyle(answer ? Color.black.opacity(0.45) : Theme.faint)
            Text(Inline.render(answer ? self.answer : question, .init(accent: look.accentColor)))
                .font(look.body.font(look.size * 1.0, .medium))
                .foregroundStyle(answer ? Color(white: 0.07) : Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(answer ? Color(white: 0.96) : Color(white: 0.08), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(answer ? .clear : Theme.line))
    }
}

struct DefinitionRow: View {
    var term: String
    var meaning: String
    var look: LookSettings

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(look.accentColor).frame(width: 6, height: 6)
                Text(Inline.render(term, .init(accent: look.accentColor))).font(look.body.font(look.size * 0.9, .medium)).foregroundStyle(Theme.text)
            }
            .frame(width: 170, alignment: .leading)
            Text(Inline.render(meaning, .init(accent: look.accentColor))).font(look.body.font(look.size * 0.9)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .panel(radius: 12)
    }
}

struct QuizView: View {
    var question: String
    var options: [QuizOption]
    var look: LookSettings
    @State private var picked: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quiz", systemImage: "checklist").font(.system(size: 12)).foregroundStyle(Theme.faint)
            Text(Inline.render(question, .init(accent: look.accentColor))).font(look.body.font(look.size, .medium)).foregroundStyle(Theme.text)
            VStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { i in option(i) }
            }
            if let picked {
                Text(options[picked].correct ? "Nice one." : "Not quite. The right answer is marked.").font(.system(size: 13)).foregroundStyle(Theme.faint)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .panel(radius: 16, glow: look.accentColor)
    }

    private func option(_ i: Int) -> some View {
        let o = options[i]
        let answered = picked != nil, isPicked = picked == i
        let edge: Color = !answered ? Theme.line : o.correct ? .green.opacity(0.5) : isPicked ? .red.opacity(0.5) : Theme.line
        let fill: Color = !answered ? .white.opacity(0.02) : o.correct ? .green.opacity(0.08) : isPicked ? .red.opacity(0.08) : .clear
        return Button { withAnimation(.snappy) { picked = picked == nil ? i : nil } } label: {
            HStack(spacing: 12) {
                Text(String(UnicodeScalar(65 + i)!)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.faint)
                    .frame(width: 22, height: 22).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
                Text(Inline.render(o.text, .init(accent: look.accentColor))).font(.system(size: 14))
                    .foregroundStyle(answered && !o.correct && !isPicked ? Theme.faint : Theme.text)
                Spacer()
                if answered && o.correct { Image(systemName: "checkmark").foregroundStyle(.green) }
                else if isPicked { Image(systemName: "xmark").foregroundStyle(.red) }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(fill, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(edge))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ToggleBlock: View {
    var title: String
    var content: [Block]
    var store: NoteStore
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { withAnimation(.snappy) { open.toggle() } } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).rotationEffect(.degrees(open ? 90 : 0)).foregroundStyle(Theme.faint)
                    Text(Inline.render(title, .init(accent: store.look.accentColor))).font(store.look.body.font(store.look.size * 0.9)).foregroundStyle(Theme.text)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(content) { b in BlockView(block: b, store: store) }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .panel(radius: 12)
    }
}

struct ImageBlock: View {
    var alt: String
    var source: String
    var folder: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if source.hasPrefix("http"), let url = URL(string: source) {
                AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { RoundedRectangle(cornerRadius: 12).fill(Theme.surface).frame(height: 160) }
                    .clipShape(.rect(cornerRadius: 12))
            } else if let folder, let image = NSImage(contentsOf: folder.appendingPathComponent(source)) {
                Image(nsImage: image).resizable().scaledToFit().clipShape(.rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
            }
            if !alt.isEmpty { Text(alt).font(.system(size: 13)).foregroundStyle(Theme.faint) }
        }
    }
}
