import SwiftUI

/// Frosted window: a full-height sidebar on the left, a top bar, the "due" banner and
/// whatever screen is open. Everything sits on the window tint.
struct RootView: View {
    @Bindable var store: NoteStore

    var body: some View {
        ZStack {
            // The window tint: chosen colour at chosen opacity over the blurred desktop.
            store.look.windowColor.opacity(store.look.bgAlpha).ignoresSafeArea()
            RadialGradient(colors: [.white.opacity(0.05), .clear], center: .topLeading, startRadius: 0, endRadius: 900)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            Specks().ignoresSafeArea().allowsHitTesting(false)

            HStack(spacing: 0) {
                if !store.sidebarHidden {
                    Sidebar(store: store)
                        .frame(width: 264)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                VStack(spacing: 0) {
                    TopBar(store: store)
                    Banner(store: store)
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea()
        }
        .containerBackground(.clear, for: .window)
        .tint(store.look.accentColor)
        .environment(\.look, store.look)
    }

    @ViewBuilder
    private var content: some View {
        switch store.screen {
        case let .home(subject): HomeView(store: store, subject: subject)
        case .note: NotePage(store: store)
        case .reviseHub: ReviseHub(store: store)
        case .progress: ProgressPage(store: store)
        }
    }
}

private struct LookKey: EnvironmentKey { static let defaultValue = LookSettings() }
extension EnvironmentValues {
    var look: LookSettings {
        get { self[LookKey.self] }
        set { self[LookKey.self] = newValue }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Bindable var store: NoteStore
    @State private var naming = false
    @State private var newSubject = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Button { store.screen = .home(subject: nil) } label: {
                    HStack(spacing: 10) {
                        LogoMark().frame(width: 22, height: 22).background(.white.opacity(0.08), in: .rect(cornerRadius: 6))
                        Text("Renote").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(store.notes.count) notes").font(.system(size: 12)).foregroundStyle(Theme.faint)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Segment(left: "Notes", right: "Progress", rightOn: store.screen == .progress) { right in
                    store.screen = right ? .progress : .home(subject: nil)
                }
                .padding(.vertical, 12)

                SideItem(icon: "square.grid.2x2", title: "All notes", count: store.notes.count, on: store.screen == .home(subject: nil)) { store.screen = .home(subject: nil) }
                SideItem(icon: "rectangle.on.rectangle", title: "Revise", on: store.screen == .reviseHub) { store.screen = .reviseHub }
                SideItem(icon: "chart.bar", title: "Progress", on: store.screen == .progress) { store.screen = .progress }

                SideHeader(title: "Subjects") { naming = true }
                ForEach(store.subjects, id: \.self) { s in
                    SideItem(icon: "folder", title: s, count: store.notes(in: s).count,
                             on: store.screen == .home(subject: s) || (store.screen == .note && store.currentNote?.subject == s)) {
                        store.screen = .home(subject: s)
                    }
                    .contextMenu { Button("New Note in \(s)") { store.newNote(in: s) } }
                }
                let loose = store.notes(in: nil)
                if !loose.isEmpty {
                    SideItem(icon: "doc", title: "Unsorted", count: loose.count, on: store.screen == .home(subject: "")) { store.screen = .home(subject: "") }
                }

                SideHeader(title: "Recents")
                ForEach(store.notes.prefix(6)) { note in
                    SideItem(icon: "bubble.left", title: note.title, on: store.screen == .note && store.current == note.url, iconTint: store.look.accentColor) {
                        store.open(note.url)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 52) // room for the window buttons
            .padding(.bottom, 40)
        }
        .scrollIndicators(.never)
        .background {
            ZStack {
                Frost(material: .hudWindow)
                Color.black.opacity(0.18)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1) }
        .alert("New subject", isPresented: $naming) {
            TextField("Name", text: $newSubject)
            Button("Create") { store.newSubject(named: newSubject); newSubject = "" }
            Button("Cancel", role: .cancel) { newSubject = "" }
        }
    }
}

struct SideItem: View {
    var icon: String
    var title: String
    var count: Int? = nil
    var on = false
    var iconTint: Color? = nil
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(iconTint ?? Theme.muted).frame(width: 18)
                Text(title).font(.system(size: 14)).foregroundStyle(on ? Theme.text : Theme.text.opacity(0.82)).lineLimit(1)
                Spacer(minLength: 4)
                if let count { Text("\(count)").font(.system(size: 12)).foregroundStyle(Theme.faint).monospacedDigit() }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(on ? Color.white.opacity(0.09) : hover ? Color.white.opacity(0.04) : .clear, in: .rect(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct SideHeader: View {
    var title: String
    var add: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.faint)
            Spacer()
            if let add {
                Button(action: add) { Image(systemName: "plus").font(.system(size: 11)).foregroundStyle(Theme.faint) }
                    .buttonStyle(.plain).help("New subject")
            }
        }
        .padding(.horizontal, 10).padding(.top, 18).padding(.bottom, 6)
    }
}

struct Segment: View {
    var left: String
    var right: String
    var rightOn: Bool
    var pick: (Bool) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach([false, true], id: \.self) { isRight in
                let on = isRight == rightOn
                Button { pick(isRight) } label: {
                    Text(isRight ? right : left).font(.system(size: 13))
                        .foregroundStyle(on ? Theme.text : Theme.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(on ? Color(white: 0.15) : .clear, in: .rect(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.35), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.lineSoft))
    }
}

/// The Renote "r" mark.
struct LogoMark: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 24
            var p = Path()
            p.move(to: CGPoint(x: 6 * s, y: 5 * s))
            p.addLine(to: CGPoint(x: 14 * s, y: 5 * s))
            p.addArc(center: CGPoint(x: 14 * s, y: 10 * s), radius: 5 * s, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: 11 * s, y: 15 * s))
            p.addLine(to: CGPoint(x: 16 * s, y: 20 * s))
            ctx.stroke(p, with: .color(Theme.text), style: StrokeStyle(lineWidth: 2.6 * s, lineCap: .round, lineJoin: .round))
        }
        .padding(4)
    }
}

// MARK: - Top bar & banner

struct TopBar: View {
    @Bindable var store: NoteStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 26) {
            if store.sidebarHidden { Spacer().frame(width: 60) } // window buttons
            link("Notes", on: { if case .home = store.screen { return true }; return store.screen == .note }) { store.screen = .home(subject: nil) }
            link("Revise", on: { store.screen == .reviseHub }) { store.screen = .reviseHub }
            link("Progress", on: { store.screen == .progress }) { store.screen = .progress }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.faint)
                TextField("Search notes", text: $store.search)
                    .textFieldStyle(.plain).font(.system(size: 14)).frame(width: 170)
                    .focused($searchFocused)
                    .onChange(of: store.search) { if !store.search.isEmpty, store.screen != .home(subject: nil) { store.screen = .home(subject: nil) } }
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(Color.white.opacity(0.02), in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(searchFocused ? Color.white.opacity(0.25) : Theme.line))
            WhiteButton(title: "New note") { store.newNote(in: currentSubject) }
        }
        .padding(.horizontal, 28)
        .frame(height: 56)
        .background {
            Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture())
        }
        .background(store.look.windowColor.opacity(0.3))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var currentSubject: String? {
        if case let .home(s) = store.screen, let s, !s.isEmpty { return s }
        return store.currentNote?.subject
    }

    private func link(_ title: String, on: () -> Bool, action: @escaping () -> Void) -> some View {
        let active = on()
        return Button(action: action) {
            Text(title).font(.system(size: 14)).foregroundStyle(active ? Theme.text : Theme.muted)
        }
        .buttonStyle(.plain)
    }
}

struct Banner: View {
    var store: NoteStore

    var body: some View {
        let due = store.dueNotes
        if !store.notes.isEmpty {
            HStack(spacing: 12) {
                Text(due.isEmpty ? "On track" : "Due for revision")
                    .font(.system(size: 13)).foregroundStyle(store.look.accentLight)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(store.look.accentColor.opacity(0.16), in: .rect(cornerRadius: 6))
                if let first = due.first {
                    Button {
                        store.open(first.url, mode: .revise)
                    } label: {
                        HStack(spacing: 6) {
                            Text(due.count == 1 ? "\(first.title) hasn't been revised this week" : "\(due.count) notes haven't been revised this week")
                            Image(systemName: "arrow.right").font(.system(size: 11))
                        }
                        .font(.system(size: 14)).foregroundStyle(Theme.text)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Every note has been revised this week. Nice.").font(.system(size: 14)).foregroundStyle(Theme.text)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }
}

struct WhiteButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Color(white: 0.13))
            .padding(.horizontal, 14).frame(height: 34)
            .background(.white, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct GreyButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14).frame(height: 34)
            .background(Color(white: 0.17), in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// Faint specks on fixed spots of a large virtual sky, so resizing never shuffles them.
struct Specks: View {
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 7
            func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }
            for _ in 0..<260 {
                let a = 0.06 + rnd() * 0.2, r = 0.4 + rnd() * 0.8, x = rnd() * 3840, y = rnd() * 2400
                guard x < size.width + 2, y < size.height + 2 else { continue }
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(a)))
            }
        }
    }
}
