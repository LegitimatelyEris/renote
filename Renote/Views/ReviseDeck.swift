import SwiftUI

/// Revise: every flashcard, definition, quiz and gap in the note as a shuffled deck.
/// Space flips, → means got it, ← means again. Finished passes go into the log.
struct ReviseDeck: View {
    var store: NoteStore
    var cards: [StudyCard]

    @State private var deck: [StudyCard] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var known: Set<String> = []
    @State private var again: [StudyCard] = []
    @State private var round = 1
    @State private var logged = false
    @FocusState private var focused: Bool

    var body: some View {
        let look = store.look
        VStack {
            if cards.isEmpty {
                empty
            } else if index >= deck.count {
                finished(look)
            } else {
                session(look)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable().focusEffectDisabled().focused($focused)
        .onAppear { start(); focused = true }
        .onKeyPress(.space) { flip(); return .handled }
        .onKeyPress(.return) { flip(); return .handled }
        .onKeyPress(.rightArrow) { if flipped { answer(true) }; return .handled }
        .onKeyPress(.leftArrow) { if flipped { answer(false) }; return .handled }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Text("Nothing to revise yet").font(.system(size: 26, weight: .medium)).foregroundStyle(Theme.text)
            Text("Add a flashcard (Q: / A:), a definition (Term :: meaning),\na quiz, or hide words with {{gaps}} and they'll show up here.")
                .multilineTextAlignment(.center).foregroundStyle(Theme.muted)
            WhiteButton(title: "Start writing") { store.mode = .edit }.padding(.top, 8)
        }
    }

    private func session(_ look: LookSettings) -> some View {
        let card = deck[index]
        return VStack(spacing: 0) {
            HStack {
                Text(store.currentNote?.title ?? "").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
                Spacer()
                Text(round > 1 ? "Round \(round) · \(index + 1) of \(deck.count)" : "\(index + 1) of \(deck.count)")
                    .font(.system(size: 13)).foregroundStyle(Theme.faint).monospacedDigit()
            }
            .padding(.bottom, 10)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(LinearGradient(colors: [look.accentColor.opacity(0.5), .white], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, g.size.width * Double(index) / Double(deck.count)))
                }
            }
            .frame(height: 2).padding(.bottom, 22)

            ZStack {
                face(card, answer: false, look).opacity(flipped ? 0 : 1)
                face(card, answer: true, look).opacity(flipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (0, 1, 0))
            }
            .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0), perspective: 0.35)
            .frame(height: 320)
            .contentShape(Rectangle())
            .onTapGesture { flip() }
            .id(card.id + "\(round)")

            HStack(spacing: 10) {
                if flipped {
                    GreyButton(title: "Again", icon: "arrow.uturn.backward") { answer(false) }
                    WhiteButton(title: "Got it", icon: "checkmark") { answer(true) }
                } else {
                    WhiteButton(title: "Show answer", icon: "arrow.trianglehead.2.clockwise.rotate.90") { flip() }
                }
            }
            .padding(.top, 26)
            Text(flipped ? "← again · → got it" : "space to flip").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.faint).padding(.top, 14)
        }
        .frame(maxWidth: 640)
        .padding(40)
    }

    private func face(_ card: StudyCard, answer: Bool, _ look: LookSettings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(answer ? "ANSWER" : card.label.uppercased()).font(.system(size: 12)).tracking(1.2)
                .foregroundStyle(answer ? Color.black.opacity(0.45) : look.accentLight)
            Spacer(minLength: 0)
            Group {
                switch card.kind {
                case .cloze:
                    Text(Inline.render(card.front, .init(accent: look.accentColor, revealCloze: answer, clozeHiddenColor: .clear)))
                case .definition where !answer:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Define").font(.system(size: 14)).foregroundStyle(Theme.faint)
                        Text(Inline.render(card.front, .init(accent: look.accentColor))).font(look.head.font(34, .medium))
                    }
                case let .quiz(options) where !answer:
                    VStack(alignment: .leading, spacing: 14) {
                        Text(Inline.render(card.front, .init(accent: look.accentColor)))
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(options.indices, id: \.self) { i in
                                HStack(spacing: 10) {
                                    Text(String(UnicodeScalar(65 + i)!)).font(.system(size: 13, design: .monospaced)).foregroundStyle(look.accentLight)
                                    Text(Inline.render(options[i].text, .init(accent: look.accentColor)))
                                }
                            }
                        }
                        .font(.system(size: 16)).foregroundStyle(Theme.muted)
                    }
                default:
                    Text(Inline.render(answer ? card.back : card.front, .init(accent: look.accentColor)))
                }
            }
            .font(look.head.font(26, .medium))
            .foregroundStyle(answer ? Color(white: 0.07) : Theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if answer {
                RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.96)).shadow(color: .white.opacity(0.12), radius: 40)
            } else {
                RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.055))
                    .overlay(RoundedRectangle(cornerRadius: 22).fill(RadialGradient(colors: [look.accentColor.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 420)))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.line))
                    .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
            }
        }
    }

    private func finished(_ look: LookSettings) -> some View {
        let pct = Double(known.count) / Double(max(1, cards.count))
        return VStack(spacing: 16) {
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 6)
                Circle().trim(from: 0, to: pct).stroke(AngularGradient(colors: [look.accentColor, .white], center: .center), style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int((pct * 100).rounded()))%").font(.system(size: 30, weight: .medium)).monospacedDigit().foregroundStyle(Theme.text)
            }
            .frame(width: 128, height: 128)
            Text(pct == 1 ? "All done. You know this note." : "Round complete").font(.system(size: 28, weight: .medium)).tracking(-0.6).foregroundStyle(Theme.text)
            Text("\(known.count) of \(cards.count) cards known" + (again.isEmpty ? "" : " · \(again.count) to go again")).foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                if !again.isEmpty {
                    WhiteButton(title: "Revise the \(again.count) missed") {
                        withAnimation(.snappy) { deck = again.shuffled(); again = []; index = 0; flipped = false; round += 1 }
                    }
                }
                GreyButton(title: "Start over") { withAnimation(.snappy) { start() } }
                GreyButton(title: "See progress") { store.screen = .progress }
            }
            .padding(.top, 6)
        }
        .onAppear {
            guard !logged else { return }
            logged = true
            store.logSession(cards: cards.count, known: known.count, rounds: round)
        }
    }

    private func start() {
        deck = cards.shuffled(); index = 0; flipped = false; known = []; again = []; round = 1; logged = false
    }

    private func flip() {
        guard index < deck.count else { return }
        withAnimation(.spring(duration: 0.55, bounce: 0.15)) { flipped.toggle() }
    }

    private func answer(_ knewIt: Bool) {
        let card = deck[index]
        if knewIt { known.insert(card.id) } else { again.append(card) }
        withAnimation(.snappy(duration: 0.3)) { flipped = false; index += 1 }
    }
}
