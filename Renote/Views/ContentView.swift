import SwiftUI

struct ContentView: View {
    @Bindable var store: NoteStore
    var editor: EditorController
    @State private var renaming: Note?
    @State private var newName = ""

    private var currentTitle: String {
        store.notes.first { $0.url == store.selection }?.title ?? "Renote"
    }

    private var accent: Color { NoteStore.accent(for: currentTitle) }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 340)
        } detail: {
            detail
                .toolbar { toolbar }
                .navigationTitle("")
        }
        .searchable(text: $store.search, placement: .sidebar, prompt: "Search notes")
        .tint(accent)
        .alert("Rename note", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") { if let renaming { store.rename(renaming, to: newName) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $store.selection) {
            ForEach(store.filteredNotes) { note in
                NoteRow(note: note)
                    .tag(note.url)
                    .contextMenu {
                        Button("Rename…") { newName = note.url.deletingPathExtension().lastPathComponent; renaming = note }
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([note.url]) }
                        Divider()
                        Button("Move to Trash", role: .destructive) { store.trash(note) }
                    }
            }
        }
        .overlay {
            if store.notes.isEmpty {
                ContentUnavailableView {
                    Label("No notes yet", systemImage: "note.text")
                } actions: {
                    Button("New Note") { store.newNote() }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button { store.newNote() } label: { Label("New Note", systemImage: "square.and.pencil") }
                    .help("New note (⌘N)")
            }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if store.selection == nil {
            ContentUnavailableView("Pick a note", systemImage: "note.text", description: Text("Or press ⌘N to start a new one."))
        } else {
            switch store.mode {
            case .write:
                MarkdownEditor(text: $store.text, controller: editor, accent: accent)
                    .background(Color(nsColor: .textBackgroundColor))
            case .read:
                ReaderView(store: store, accent: accent)
                    .background(Color(nsColor: .textBackgroundColor))
            case .revise:
                ReviseView(cards: store.blocks.flatMap(\.studyCards), accent: accent, title: currentTitle)
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
            .labelStyle(.titleAndIcon)
            .fixedSize()
            .disabled(store.selection == nil)
        }
        if store.mode == .write, store.selection != nil {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu { FormatMenu(editor: editor) } label: { Label("Format", systemImage: "textformat") }
                    .help("Text formatting")
                Menu { InsertMenu(editor: editor) } label: { Label("Insert", systemImage: "plus") }
                    .help("Insert a component")
            }
        }
    }
}

private struct NoteRow: View {
    var note: Note

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(NoteStore.accent(for: note.title))
                .frame(width: 3)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .lineLimit(1)
                Text(note.preview.isEmpty ? "Empty note" : note.preview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(note.modified, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
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
