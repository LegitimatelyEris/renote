import SwiftUI

// MARK: - Home: the notes grid

struct HomeView: View {
    @Bindable var store: NoteStore
    var subject: String? // nil = all, "" = unsorted

    var body: some View {
        let q = store.search.trimmingCharacters(in: .whitespaces).lowercased()
        let base: [Note] = switch subject {
        case nil: store.notes
        case ""?: store.notes(in: nil)
        case let s?: store.notes(in: s)
        }
        let notes = q.isEmpty ? base : base.filter { ($0.title + " " + $0.preview).lowercased().contains(q) }
        let groups: [(String?, [Note])] = (subject != nil || !q.isEmpty) ? [(subject, notes)] :
            (store.subjects.map { s in (s, notes.filter { $0.subject == s }) } + [("", notes.filter { $0.subject == nil })]).filter { !$0.1.isEmpty }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(eyebrow: "\(notes.count) \(notes.count == 1 ? "note" : "notes") · \(store.subjects.count) subjects",
                     title: !q.isEmpty ? "Results for “\(store.search)”" : subject == nil ? "Your notes" : subject == "" ? "Unsorted" : subject!,
                     lede: "Write in plain Markdown, read it beautifully, then turn it into a deck of cards and test yourself.") {
                    HStack {
                        Chip(title: "All", icon: "square.grid.2x2", on: subject == nil) { store.screen = .home(subject: nil) }
                        ForEach(store.subjects, id: \.self) { s in
                            Chip(title: s, icon: "folder", on: subject == s) { store.screen = .home(subject: s) }
                        }
                        Spacer()
                        let target = (subject?.isEmpty == false) ? subject : nil
                        WhiteButton(title: target.map { "New note in \($0)" } ?? "New note", icon: "plus") { store.newNote(in: target) }
                    }
                }
                ForEach(groups, id: \.0) { s, ns in
                    if groups.count > 1 {
                        HStack(spacing: 10) {
                            Image(systemName: "folder").font(.system(size: 12))
                            Text(s == "" ? "Unsorted" : s ?? "").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text)
                            Text("\(ns.count)")
                        }
                        .font(.system(size: 13)).foregroundStyle(Theme.faint)
                        .padding(.horizontal, 48).padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 0)], spacing: 0) {
                        ForEach(ns) { note in NoteCell(note: note) { store.open(note.url) } }
                        if q.isEmpty {
                            NewCell(title: (s?.isEmpty == false) ? "New note in \(s!)" : "New note") { store.newNote(in: (s?.isEmpty == false) ? s : nil) }
                        }
                    }
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
                if notes.isEmpty {
                    Text(q.isEmpty ? "No notes here yet." : "Nothing matches that search.")
                        .foregroundStyle(Theme.faint).padding(48)
                }
            }
        }
        .scrollIndicators(.automatic)
    }
}

struct Hero<Bar: View>: View {
    var eyebrow: String
    var title: String
    var lede: String
    @ViewBuilder var bar: Bar

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow).font(.system(size: 13)).foregroundStyle(Theme.faint).padding(.bottom, 18)
            Text(title).font(.system(size: 54, weight: .medium)).tracking(-2.8).foregroundStyle(Color(white: 0.82))
                .lineLimit(2)
            Text(lede).font(.system(size: 18)).foregroundStyle(Theme.muted).lineSpacing(3)
                .frame(maxWidth: 640, alignment: .leading).padding(.top, 14)
            bar.padding(.top, 30)
        }
        .padding(.horizontal, 48).padding(.top, 64).padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

struct Chip: View {
    var title: String
    var icon: String? = nil
    var on = false
    var small = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: small ? 11 : 12)) }
                Text(title).font(.system(size: small ? 12 : 13))
            }
            .foregroundStyle(on ? Color(white: 0.07) : Theme.text)
            .padding(.horizontal, small ? 11 : 14).frame(height: small ? 28 : 34)
            .background(on ? Color.white : Color.white.opacity(0.02), in: .capsule)
            .overlay(Capsule().strokeBorder(on ? Color.white : Theme.line))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct NoteCell: View {
    var note: Note
    var open: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(note.subject ?? "Unsorted")
                    Spacer()
                    Text(note.modified, format: .relative(presentation: .named))
                }
                .font(.system(size: 12)).foregroundStyle(Theme.faint)
                Text(note.title).font(.system(size: 18, weight: .medium)).tracking(-0.3).foregroundStyle(Theme.text).lineLimit(2)
                Text(note.preview.isEmpty ? "Empty note" : note.preview)
                    .font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(3).lineSpacing(2)
                Spacer(minLength: 0)
                Label("Open", systemImage: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 28).padding(.vertical, 26)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(hover ? Color.white.opacity(0.025) : .clear)
            .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1) }
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct NewCell: View {
    var title: String
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "plus").font(.system(size: 16))
                Text(title).font(.system(size: 15))
            }
            .foregroundStyle(hover ? Theme.text : Theme.muted)
            .padding(28)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Revise hub

struct ReviseHub: View {
    var store: NoteStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(eyebrow: "Revise", title: "Pick a note and test yourself",
                     lede: "Every flashcard, definition, quiz and gap in a note becomes a card. Space flips, arrows mark it.") { EmptyView() }
                VStack(spacing: 0) {
                    ForEach(store.notes) { note in
                        let last = store.log.last { $0.path == store.relativePath(note.url) }
                        LogRow(title: note.title, detail: last.map { "Last " + $0.at.formatted(.relative(presentation: .named)) } ?? "Never revised",
                               score: last.map { "\(Int((Double($0.known) / Double(max(1, $0.cards)) * 100).rounded()))%" } ?? "·") {
                            store.open(note.url, mode: .revise)
                        }
                    }
                }
                .panel()
                .padding(.horizontal, 48).padding(.vertical, 32)
            }
        }
    }
}

struct LogRow: View {
    var title: String
    var detail: String
    var score: String
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title).font(.system(size: 14)).foregroundStyle(Theme.text)
                Spacer()
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.faint)
                Text(score).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted).frame(minWidth: 40, alignment: .trailing)
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(hover ? Color.white.opacity(0.02) : .clear)
            .overlay(alignment: .top) { Rectangle().fill(Theme.lineSoft).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Progress

struct ProgressPage: View {
    var store: NoteStore

    var body: some View {
        let log = store.log
        let reviewed = log.reduce(0) { $0 + $1.cards }
        let known = log.reduce(0) { $0 + $1.known }
        let days = Set(log.map { Calendar.current.startOfDay(for: $0.at) })
        let streak: Int = {
            var n = 0
            var d = Calendar.current.startOfDay(for: .now)
            while days.contains(d) { n += 1; d = Calendar.current.date(byAdding: .day, value: -1, to: d)! }
            return n
        }()
        let latest = Dictionary(log.map { ($0.path, $0) }, uniquingKeysWith: { $1 }).values
            .map { ($0, Double($0.known) / Double(max(1, $0.cards))) }.sorted { $0.1 > $1.1 }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(eyebrow: "Progress · logged in .renote/log.json", title: "Your revision, at a glance",
                     lede: "Every finished Revise session is logged, so you can see what's sticking and what needs another go.") { EmptyView() }
                HStack(spacing: 0) {
                    stat("\(log.count)", "Sessions")
                    stat("\(reviewed)", "Cards reviewed")
                    stat("\(reviewed == 0 ? 0 : Int((Double(known) / Double(reviewed) * 100).rounded()))%", "Known first time")
                    stat("\(streak)", "Day streak", last: true)
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mastery by note").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.text)
                    Text("Your latest score on each note").font(.system(size: 13)).foregroundStyle(Theme.faint).padding(.bottom, 16)
                    if latest.isEmpty {
                        Text("Finish a Revise session to see it here.").font(.system(size: 14)).foregroundStyle(Theme.faint)
                    }
                    ForEach(latest, id: \.0.id) { entry, pct in
                        HStack(spacing: 14) {
                            Text(entry.title).font(.system(size: 13)).foregroundStyle(Theme.muted).frame(width: 180, alignment: .leading).lineLimit(1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.05))
                                    Capsule().fill(LinearGradient(colors: [store.look.accentColor.opacity(0.55), store.look.accentLight], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * pct)
                                }
                            }
                            .frame(height: 8)
                            Text("\(Int(pct * 100))%").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.faint).frame(width: 44, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .padding(24).panel()
                .padding(.horizontal, 48).padding(.vertical, 32)

                VStack(spacing: 0) {
                    ForEach(log.reversed().prefix(30)) { e in
                        LogRow(title: e.title, detail: e.at.formatted(date: .abbreviated, time: .shortened), score: "\(e.known)/\(e.cards)") {
                            if let note = store.notes.first(where: { store.relativePath($0.url) == e.path }) { store.open(note.url, mode: .revise) }
                        }
                    }
                    if log.isEmpty { Text("No sessions yet.").foregroundStyle(Theme.faint).padding(24) }
                }
                .panel()
                .padding(.horizontal, 48).padding(.bottom, 48)
            }
        }
    }

    private func stat(_ value: String, _ label: String, last: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 34, weight: .medium)).tracking(-1).foregroundStyle(Theme.text)
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 28).padding(.vertical, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) { if !last { Rectangle().fill(Theme.line).frame(width: 1) } }
    }
}

// MARK: - Shared panel style

struct Panel: ViewModifier {
    var radius: CGFloat = 14
    var glow: Color? = nil

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.035), Color.white.opacity(0.015)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        if let glow {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(RadialGradient(colors: [glow.opacity(0.14), .clear], center: .topLeading, startRadius: 0, endRadius: 320))
                        }
                    }
            }
            .clipShape(.rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.line))
    }
}

extension View {
    func panel(radius: CGFloat = 14, glow: Color? = nil) -> some View { modifier(Panel(radius: radius, glow: glow)) }
}
