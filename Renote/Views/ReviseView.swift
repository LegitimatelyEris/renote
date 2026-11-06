import SwiftUI

/// Revise mode: every flashcard, definition, quiz and gap in the note as a deck.
struct ReviseView: View {
    var cards: [StudyCard]
    var accent: Color
    var title: String

    @State private var deck: [StudyCard] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var known: Set<String> = []
    @State private var again: [StudyCard] = []
    @State private var round = 1
    @State private var quizPick: Int?
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if cards.isEmpty {
                empty
            } else if index >= deck.count {
                finished
            } else {
                session
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(accent.opacity(0.04))
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { start(cards); focused = true }
        .onChange(of: cards) { _, new in start(new) }
        .onKeyPress(.space) { flip(); return .handled }
        .onKeyPress(.return) { flip(); return .handled }
        .onKeyPress(.rightArrow) { if flipped { answer(knewIt: true) }; return .handled }
        .onKeyPress(.leftArrow) { if flipped { answer(knewIt: false) }; return .handled }
    }

    // MARK: States

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(accent)
            Text("Nothing to revise yet")
                .font(.system(size: 22, weight: .semibold, design: .serif))
            Text("Add a flashcard (Q: / A:), a definition (Term :: meaning),\na quiz, or hide words with {{gaps}} and they will show up here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var session: some View {
        let card = deck[index]
        return VStack(spacing: 28) {
            VStack(spacing: 10) {
                HStack {
                    Text(title).font(.system(.callout, design: .serif).weight(.semibold))
                    Spacer()
                    Text(round > 1 ? "Round \(round) · \(index + 1) of \(deck.count)" : "\(index + 1) of \(deck.count)")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                ProgressView(value: Double(index), total: Double(deck.count))
                    .tint(accent)
            }
            .frame(maxWidth: 560)

            CardFace(card: card, flipped: flipped, accent: accent, quizPick: $quizPick)
                .frame(maxWidth: 560, minHeight: 300)
                .id(card.id + "\(round)")
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .onTapGesture { flip() }

            HStack(spacing: 14) {
                if flipped {
                    Button { answer(knewIt: false) } label: {
                        Label("Again", systemImage: "arrow.uturn.backward")
                            .frame(minWidth: 120)
                    }
                    Button { answer(knewIt: true) } label: {
                        Label("Got it", systemImage: "checkmark")
                            .frame(minWidth: 120)
                    }
                    .tint(accent)
                    .buttonStyle(.glassProminent)
                } else {
                    Button { flip() } label: {
                        Label("Show answer", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(.glass)
                }
            }
            .buttonStyle(.glass)
            .controlSize(.large)

            Text(flipped ? "← again   ·   → got it" : "space to flip")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(40)
    }

    private var finished: some View {
        let score = cards.isEmpty ? 0 : Int((Double(known.count) / Double(cards.count) * 100).rounded())
        return VStack(spacing: 18) {
            ZStack {
                Circle().stroke(accent.opacity(0.15), lineWidth: 10)
                Circle().trim(from: 0, to: Double(score) / 100)
                    .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score)%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 120, height: 120)
            Text(score == 100 ? "All done. You know this note." : "Round complete")
                .font(.system(size: 24, weight: .semibold, design: .serif))
            Text("\(known.count) of \(cards.count) cards known" + (again.isEmpty ? "" : " · \(again.count) to go again"))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if !again.isEmpty {
                    Button("Revise the \(again.count) missed") {
                        withAnimation(.snappy) {
                            deck = again.shuffled(); again = []; index = 0; flipped = false; round += 1
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(accent)
                }
                Button("Start over") { withAnimation(.snappy) { start(cards) } }
                    .buttonStyle(.glass)
            }
            .controlSize(.large)
            .padding(.top, 6)
        }
    }

    // MARK: Actions

    private func start(_ cards: [StudyCard]) {
        deck = cards.shuffled()
        index = 0
        flipped = false
        known = []
        again = []
        round = 1
        quizPick = nil
    }

    private func flip() {
        guard index < deck.count else { return }
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) { flipped.toggle() }
    }

    private func answer(knewIt: Bool) {
        let card = deck[index]
        if knewIt { known.insert(card.id) } else { again.append(card) }
        withAnimation(.snappy(duration: 0.35)) {
            flipped = false
            quizPick = nil
            index += 1
        }
    }
}

private struct CardFace: View {
    var card: StudyCard
    var flipped: Bool
    var accent: Color
    @Binding var quizPick: Int?

    var body: some View {
        ZStack {
            front.opacity(flipped ? 0 : 1)
            back.opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0), perspective: 0.35)
    }

    private var front: some View {
        face(dark: false) {
            switch card.kind {
            case .cloze:
                Text(Inline.render(card.front, .init(accent: accent, revealCloze: false, clozeHiddenColor: .clear)))
            case let .quiz(options):
                VStack(alignment: .leading, spacing: 16) {
                    Text(Inline.render(card.front, .init(accent: accent)))
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(options.indices, id: \.self) { i in
                            Text("\(Character(UnicodeScalar(65 + i)!))   ").foregroundStyle(accent).bold()
                                + Text(Inline.render(options[i].text, .init(accent: accent)))
                        }
                    }
                    .font(.system(size: 17))
                }
            case .definition:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Define").font(.system(.callout, design: .rounded)).foregroundStyle(.secondary)
                    Text(Inline.render(card.front, .init(accent: accent)))
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                }
            case .flashcard:
                Text(Inline.render(card.front, .init(accent: accent)))
            }
        }
    }

    private var back: some View {
        face(dark: true) {
            switch card.kind {
            case .cloze:
                Text(Inline.render(card.back, .init(accent: .white, revealCloze: true)))
            case .definition:
                VStack(alignment: .leading, spacing: 10) {
                    Text(Inline.render(card.front, .init(accent: .white)))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .opacity(0.75)
                    Text(Inline.render(card.back, .init(accent: .white)))
                }
            default:
                Text(Inline.render(card.back, .init(accent: .white)))
            }
        }
    }

    private func face<Content: View>(dark: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(dark ? "ANSWER" : card.label.uppercased())
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .tracking(1.2)
                Spacer()
            }
            .foregroundStyle(dark ? .white.opacity(0.75) : accent)
            Spacer(minLength: 0)
            content()
                .font(.system(size: 24, weight: .medium, design: .serif))
                .lineSpacing(6)
                .foregroundStyle(dark ? .white : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if dark {
                RoundedRectangle(cornerRadius: 26).fill(accent.gradient)
                    .shadow(color: accent.opacity(0.35), radius: 24, y: 12)
            } else {
                RoundedRectangle(cornerRadius: 26).fill(.background)
                    .shadow(color: .black.opacity(0.10), radius: 24, y: 12)
                    .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.primary.opacity(0.06)))
            }
        }
        .contentShape(Rectangle())
    }
}
