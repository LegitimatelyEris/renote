import SwiftUI

struct ContentView: View {
    @Bindable var store: NoteStore
    var editor: EditorController
    @State private var renaming: Note?
    @State private var renamingSubject: String?
    @State private var newName = ""
    @State private var collapsed: Set<String> = []
    @State private var showInspector = true

    private var currentNote: Note? { store.notes.first { $0.url == store.selection } }
    private var currentTitle: String { currentNote?.title ?? "Renote" }
    private var accent: Color { NoteStore.accent(for: currentTitle) }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 360)
        } detail: {
            detail
                .toolbar { toolbar }
                .navigationTitle(store.selection == nil ? "Renote" : currentTitle)
                .inspector(isPresented: $showInspector) {
                    NoteInspector(store: store, accent: accent)
                        .inspectorColumnWidth(min: 230, ideal: 290, max: 360)
                }
        }
        .searchable(text: $store.search, placement: .sidebar, prompt: "Search notes")
        .tint(accent)
        .preferredColorScheme(.dark)
        .alert("Rename note", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") { if let renaming { store.rename(renaming, to: newName) } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename subject", isPresented: Binding(get: { renamingSubject != nil }, set: { if !$0 { renamingSubject = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") { if let renamingSubject { store.renameSubject(renamingSubject, to: newName) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $store.selection) {
            Button { store.newNote() } label: {
                Label("New note", systemImage: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)

            if !store.search.isEmpty {
                Section("Results") {
                    ForEach(store.filteredNotes) { note in row(note, showSubject: true) }
                }
            } else {
                Section {
                    ForEach(store.subjects, id: \.self) { subject in
                        DisclosureGroup(isExpanded: Binding(
                            get: { !collapsed.contains(subject) },
                            set: { open in if open { collapsed.remove(subject) } else { collapsed.insert(subject) } }
                        )) {
                            let notes = store.notes(in: subject)
                            if notes.isEmpty {
                                Text("No notes").foregroundStyle(Theme.faint).selectionDisabled()
                            }
                            ForEach(notes) { note in row(note) }
                        } label: {
                            Label(subject, systemImage: "folder")
                                .contextMenu {
                                    Button("New Note in \(subject)") { store.newNote(in: subject) }
                                    Button("Rename…") { newName = subject; renamingSubject = subject }
                                }
                        }
                    }
                } header: {
                    HStack {
                        Text("Subjects")
                        Spacer()
                        Button { store.newSubject() } label: { Image(systemName: "plus") }
                            .buttonStyle(.plain)
                            .help("New subject")
                    }
                }

                let loose = store.notes(in: nil)
                if !loose.isEmpty {
                    Section("Notes") {
                        ForEach(loose) { note in row(note) }
                    }
                }
            }
        }
        .overlay {
            if store.notes.isEmpty && store.subjects.isEmpty {
                ContentUnavailableView {
                    Label("No notes yet", systemImage: "note.text")
                } actions: {
                    Button("New Note") { store.newNote() }
                }
            }
        }
    }

    private func row(_ note: Note, showSubject: Bool = false) -> some View {
        HStack {
            Text(note.title).lineLimit(1)
            if showSubject, let subject = note.subject {
                Spacer()
                Text(subject).font(.system(size: 11)).foregroundStyle(Theme.faint)
            }
        }
        .tag(note.url)
        .contextMenu {
            Button("Rename…") { newName = note.url.deletingPathExtension().lastPathComponent; renaming = note }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([note.url]) }
            Divider()
            Button("Move to Trash", role: .destructive) { store.trash(note) }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if store.selection == nil {
            ContentUnavailableView("Pick a note", systemImage: "note.text", description: Text("Or press ⌘N to start a new one."))
                .background { Backdrop(accent: accent) }
        } else {
            ZStack(alignment: .bottom) {
                switch store.mode {
                case .write:
                    MarkdownEditor(text: $store.text, controller: editor, accent: accent)
                        .background { Backdrop(accent: accent) }
                case .read:
                    ReaderView(store: store, accent: accent)
                case .revise:
                    ReviseView(cards: store.blocks.flatMap(\.studyCards), accent: accent, title: currentTitle)
                }
                if store.mode != .revise {
                    // Content fades out under the composer, like a chat transcript.
                    LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas], startPoint: .top, endPoint: .bottom)
                        .frame(height: 150)
                        .allowsHitTesting(false)
                    Composer(store: store, accent: accent)
                        .frame(maxWidth: 730)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 14)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Mode", selection: $store.mode) {
                ForEach(NoteMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.titleOnly)
            .fixedSize()
            .disabled(store.selection == nil)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if store.mode == .write, store.selection != nil {
                Menu { FormatMenu(editor: editor) } label: { Label("Format", systemImage: "textformat") }
                    .help("Text formatting")
                Menu { InsertMenu(editor: editor) } label: { Label("Insert", systemImage: "plus") }
                    .help("Insert a component")
            }
            Button { showInspector.toggle() } label: { Label("Panel", systemImage: "sidebar.right") }
                .help("Show or hide the outline panel")
        }
    }
}

// MARK: - Menus (shared by the toolbar and the menu bar)

struct FormatMenu: View {
    var editor: EditorController
    /// Only the menu bar copy registers shortcuts, so they never fire twice.
    var shortcuts = false

    var body: some View {
        Button("Bold") { editor.wrap("**") }.shortcut("b", on: shortcuts)
        Button("Italic") { editor.wrap("*") }.shortcut("i", on: shortcuts)
        Button("Underline") { editor.wrap("++") }.shortcut("u", on: shortcuts)
        Button("Strikethrough") { editor.wrap("~~") }.shortcut("x", modifiers: [.command, .shift], on: shortcuts)
        Button("Highlight") { editor.wrap("==") }.shortcut("h", modifiers: [.command, .shift], on: shortcuts)
        Button("Hide as Gap") { editor.wrap("{{", "}}") }.shortcut("g", modifiers: [.command, .shift], on: shortcuts)
        Button("Inline Code") { editor.wrap("`") }.shortcut("k", modifiers: [.command, .shift], on: shortcuts)
        Button("Small Caps") { editor.wrap("^^") }
        Menu("Colour") {
            ForEach(["red", "orange", "yellow", "green", "teal", "blue", "purple", "pink", "gray"], id: \.self) { c in
                Button(c.capitalized) { editor.wrap("{\(c)|", "}") }
            }
        }
        Divider()
        Button("Link") { editor.wrap("[", "](https://)") }.shortcut("k", on: shortcuts)
        Divider()
        Button("Heading 1") { editor.prefixLine("# ") }.shortcut("1", modifiers: [.command, .option], on: shortcuts)
        Button("Heading 2") { editor.prefixLine("## ") }.shortcut("2", modifiers: [.command, .option], on: shortcuts)
        Button("Heading 3") { editor.prefixLine("### ") }.shortcut("3", modifiers: [.command, .option], on: shortcuts)
        Button("Bulleted List") { editor.prefixLine("- ") }
        Button("Numbered List") { editor.prefixLine("1. ") }
        Button("Quote") { editor.prefixLine("> ") }
    }
}

struct InsertMenu: View {
    var editor: EditorController

    var body: some View {
        Section("Revision") {
            Button { editor.insert("Q: Question\nA: Answer") } label: { Label("Flashcard", systemImage: "rectangle.on.rectangle.angled") }
            Button { editor.insert("Term :: What it means") } label: { Label("Definition", systemImage: "character.book.closed") }
            Button { editor.insert("? Question\n- ( ) Wrong answer\n- (x) Right answer\n- ( ) Wrong answer") } label: { Label("Quiz", systemImage: "checklist") }
            Button { editor.wrap("{{", "}}") } label: { Label("Gap to Fill", systemImage: "eye.slash") }
        }
        Section("Components") {
            Menu {
                ForEach(CalloutStyle.allCases, id: \.self) { style in
                    Button { editor.insert("> [!\(style.rawValue)] \(style.label)\n> ") } label: { Label(style.label, systemImage: style.symbol) }
                }
            } label: { Label("Callout", systemImage: "text.bubble") }
            Button { editor.insert("+++ Title\nHidden details\n+++") } label: { Label("Toggle", systemImage: "chevron.right.square") }
            Button { editor.insert("- [ ] To do\n- [ ] To do") } label: { Label("Checklist", systemImage: "checkmark.circle") }
            Button { editor.insert("| Column | Column |\n|---|---|\n| Cell | Cell |") } label: { Label("Table", systemImage: "tablecells") }
            Button { editor.insert("```\ncode\n```") } label: { Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right") }
            Button { editor.insert("![Caption](image.png)") } label: { Label("Image", systemImage: "photo") }
            Button { editor.insert("---") } label: { Label("Divider", systemImage: "minus") }
        }
    }
}

private extension View {
    func shortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command, on: Bool) -> some View {
        keyboardShortcut(on ? KeyboardShortcut(key, modifiers: modifiers) : nil)
    }
}
