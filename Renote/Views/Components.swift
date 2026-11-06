import SwiftUI

extension CalloutStyle {
    var tint: Color {
        switch self {
        case .note: Color(white: 0.7)
        case .tip: Color(red: 0.35, green: 0.85, blue: 0.55)
        case .info: Color(red: 0.40, green: 0.65, blue: 1.0)
        case .important: Color(red: 0.70, green: 0.55, blue: 1.0)
        case .warning: Color(red: 1.0, green: 0.62, blue: 0.25)
        case .danger: Color(red: 1.0, green: 0.42, blue: 0.40)
        case .example: Color(red: 0.30, green: 0.80, blue: 0.80)
        case .question: Color(red: 0.55, green: 0.60, blue: 1.0)
        case .summary: Color(red: 0.45, green: 0.85, blue: 0.75)
        case .remember: Color(red: 1.0, green: 0.50, blue: 0.70)
        }
    }
}

/// The shared look for every component: a faint raised panel with a hairline edge.
struct Panel: ViewModifier {
    var radius: CGFloat = 14
    var glow: Color? = nil

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(Theme.surface)
                    .overlay(alignment: .top) {
                        if let glow {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(RadialGradient(colors: [glow.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 320))
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)],
                                                 startPoint: .top, endPoint: .bottom))
            }
    }
}

extension View {
    func panel(radius: CGFloat = 14, glow: Color? = nil) -> some View { modifier(Panel(radius: radius, glow: glow)) }
}

/// Small uppercase label used at the top of components.
struct Eyebrow: View {
    var text: String
    var color: Color = Theme.faint
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
            Text(text.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1)
        }
        .foregroundStyle(color)
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
            HStack(spacing: 8) {
                Image(systemName: style.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(style.tint)
                    .frame(width: 24, height: 24)
                    .background(style.tint.opacity(0.14), in: .rect(cornerRadius: 7))
                Text(Inline.render(title, .init(accent: style.tint)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            if !content.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    BlockList(blocks: content, accent: style.tint, store: store)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(glow: style.tint)
    }
}

struct FlashcardView: View {
    var question: String
    var answer: String
    var accent: Color
    @State private var flipped = false

    var body: some View {
        ZStack {
            face(isAnswer: false, text: question)
                .opacity(flipped ? 0 : 1)
            face(isAnswer: true, text: answer)
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0), perspective: 0.4)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(duration: 0.5, bounce: 0.2)) { flipped.toggle() } }
        .help("Click to flip")
    }

    private func face(isAnswer: Bool, text: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: isAnswer ? "Answer" : "Question", color: isAnswer ? accent : Theme.faint)
                Spacer()
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
            Text(Inline.render(text, .init(accent: accent)))
                .font(.system(size: 18, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(isAnswer ? Theme.muted : Theme.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .panel(radius: 18, glow: isAnswer ? accent : .white)
    }
}

struct DefinitionView: View {
    var term: String
    var meaning: String
    var accent: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(Inline.render(term, .init(accent: accent)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 150, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(Inline.render(meaning, .init(accent: accent)))
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .overlay(alignment: .leading) {
            Capsule().fill(accent).frame(width: 2, height: 16).offset(x: -1)
        }
        .panel(radius: 12)
    }
}

struct QuizView: View {
    var question: String
    var options: [QuizOption]
    var accent: Color
    @State private var picked: Int?

    private let right = Color(red: 0.35, green: 0.85, blue: 0.55)
    private let wrong = Color(red: 1.0, green: 0.42, blue: 0.40)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Quiz", color: accent, symbol: "checklist")
            Text(Inline.render(question, .init(accent: accent)))
                .font(.system(size: 18, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { i in optionRow(i) }
            }
            if let picked {
                Text(options[picked].correct ? "Nice one." : "Not quite. The right answer is marked.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
                    .transition(.opacity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(radius: 16, glow: accent)
    }

    private func optionRow(_ i: Int) -> some View {
        let option = options[i]
        let answered = picked != nil
        let isPicked = picked == i
        let edge: Color = !answered ? Theme.hairline : option.correct ? right.opacity(0.6) : isPicked ? wrong.opacity(0.6) : Theme.hairline
        let fill: Color = !answered ? Color.white.opacity(0.03) : option.correct ? right.opacity(0.10) : isPicked ? wrong.opacity(0.10) : .clear
        return Button {
            withAnimation(.snappy) { picked = picked == nil ? i : nil }
        } label: {
            HStack(spacing: 12) {
                Text(String(Character(UnicodeScalar(65 + i)!)))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.faint)
                    .frame(width: 20, height: 20)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.hairline))
                Text(Inline.render(option.text, .init(accent: accent)))
                    .font(.system(size: 14))
                    .foregroundStyle(answered && !option.correct && !isPicked ? Theme.faint : Theme.ink)
                Spacer()
                if answered && option.correct { Image(systemName: "checkmark").foregroundStyle(right) }
                else if isPicked { Image(systemName: "xmark").foregroundStyle(wrong) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
    var accent: Color
    var store: NoteStore?
    @State private var open = false

    init(title: String, body: [Block], accent: Color, store: NoteStore?) {
        self.title = title
        self.content = body
        self.accent = accent
        self.store = store
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { open.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .foregroundStyle(Theme.faint)
                    Text(Inline.render(title, .init(accent: accent)))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 12) {
                    BlockList(blocks: content, accent: accent, store: store)
                }
                .padding(.leading, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .panel(radius: 12)
        .clipped()
    }
}
