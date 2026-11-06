import SwiftUI

extension CalloutStyle {
    var tint: Color {
        switch self {
        case .note: .gray
        case .tip: .green
        case .info: .blue
        case .important: .purple
        case .warning: .orange
        case .danger: .red
        case .example: .teal
        case .question: .indigo
        case .summary: .mint
        case .remember: .pink
        }
    }
}

struct CalloutView: View {
    var style: CalloutStyle
    var title: String
    var content: [Block]
    var accent: Color
    var store: NoteStore?

    init(style: CalloutStyle, title: String, body: [Block], accent: Color, store: NoteStore?) {
        self.style = style
        self.title = title
        self.content = body
        self.accent = accent
        self.store = store
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(Inline.render(title, .init(accent: style.tint)))
                    .font(.system(.callout, design: .rounded).weight(.semibold))
            } icon: {
                Image(systemName: style.symbol)
            }
            .foregroundStyle(style.tint)
            if !content.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    BlockList(blocks: content, accent: style.tint, store: store)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.tint.opacity(0.08), in: .rect(cornerRadius: 14))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14)
                .fill(style.tint)
                .frame(width: 3)
        }
    }
}

struct FlashcardView: View {
    var question: String
    var answer: String
    var accent: Color
    @State private var flipped = false

    var body: some View {
        ZStack {
            face(label: "Question", text: question, symbol: "questionmark")
                .opacity(flipped ? 0 : 1)
            face(label: "Answer", text: answer, symbol: "checkmark")
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0), perspective: 0.4)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(duration: 0.5, bounce: 0.2)) { flipped.toggle() } }
        .help("Click to flip")
    }

    private func face(label: String, text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label.uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .tracking(1)
                Spacer()
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.caption)
            }
            .foregroundStyle(label == "Answer" ? .white.opacity(0.8) : accent)
            Text(Inline.render(text, .init(accent: label == "Answer" ? .white : accent)))
                .font(.system(size: 19, weight: .medium, design: .serif))
                .foregroundStyle(label == "Answer" ? .white : .primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background {
            if label == "Answer" {
                RoundedRectangle(cornerRadius: 18).fill(accent.gradient)
            } else {
                RoundedRectangle(cornerRadius: 18).fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(accent.opacity(0.25)))
            }
        }
    }
}

struct DefinitionView: View {
    var term: String
    var meaning: String
    var accent: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(Inline.render(term, .init(accent: accent)))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .frame(width: 150, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(Inline.render(meaning, .init(accent: accent)))
                .font(Theme.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(accent.opacity(0.06), in: .rect(cornerRadius: 12))
    }
}

struct QuizView: View {
    var question: String
    var options: [QuizOption]
    var accent: Color
    @State private var picked: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(Inline.render(question, .init(accent: accent)))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checklist").foregroundStyle(accent)
            }
            VStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { i in
                    optionRow(i)
                }
            }
            if let picked {
                Text(options[picked].correct ? "Nice one." : "Not quite, the right answer is highlighted.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.03), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.07)))
    }

    private func optionRow(_ i: Int) -> some View {
        let option = options[i]
        let answered = picked != nil
        let isPicked = picked == i
        let tint: Color = !answered ? .primary.opacity(0.05)
            : option.correct ? .green.opacity(0.18)
            : isPicked ? .red.opacity(0.15) : .primary.opacity(0.03)
        return Button {
            withAnimation(.snappy) { picked = picked == nil ? i : nil }
        } label: {
            HStack {
                Text(Inline.render(option.text, .init(accent: accent)))
                    .font(.system(size: 15))
                Spacer()
                if answered && option.correct { Image(systemName: "checkmark").foregroundStyle(.green) }
                else if isPicked { Image(systemName: "xmark").foregroundStyle(.red) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tint, in: .rect(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ToggleBlock: View {
    var title: String
    var body_: [Block]
    var accent: Color
    var store: NoteStore?
    @State private var open = false

    init(title: String, body: [Block], accent: Color, store: NoteStore?) {
        self.title = title
        self.body_ = body
        self.accent = accent
        self.store = store
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { open.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .foregroundStyle(accent)
                    Text(Inline.render(title, .init(accent: accent)))
                        .font(.system(size: 17, weight: .medium, design: .serif))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 12) {
                    BlockList(blocks: body_, accent: accent, store: store)
                }
                .padding(.leading, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.primary.opacity(0.03), in: .rect(cornerRadius: 12))
        .clipped()
    }
}
