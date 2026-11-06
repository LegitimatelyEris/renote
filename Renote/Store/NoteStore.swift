import AppKit
import Observation
import SwiftUI

struct Note: Identifiable, Hashable {
    var url: URL
    var title: String
    var preview: String
    var modified: Date
    /// The subject folder the note lives in, or nil for loose notes.
    var subject: String?
    var id: URL { url }
}

enum NoteMode: String, CaseIterable, Identifiable {
    case write, read, revise
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .write: "pencil.line"
        case .read: "book"
        case .revise: "rectangle.on.rectangle.angled"
        }
    }
}

/// Owns the notes folder: lists, loads, saves, creates and trashes Markdown files.
@Observable
final class NoteStore {
    private(set) var notes: [Note] = []
    var selection: URL? {
        didSet { if oldValue != selection { load() } }
    }
    var text: String = "" {
        didSet { if text != oldValue, !isLoading { scheduleSave() } }
    }
    var mode: NoteMode = .read
    var search: String = ""
    private(set) var subjects: [String] = []
    /// Heading the Read view should scroll to (set from the Outline panel).
    var jumpTarget: Int?

    private(set) var folder: URL
    private var isLoading = false
    /// The file `text` came from; saves always go here, never to a newer selection.
    private var loadedURL: URL?
    private var saveTask: Task<Void, Never>?

    static let folderKey = "notesFolder"

    init() {
        if let path = UserDefaults.standard.string(forKey: Self.folderKey) {
            folder = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Renote", isDirectory: true)
        }
        prepareFolder()
        refresh()
        selection = notes.first?.url
        load()
    }

    var filteredNotes: [Note] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return notes }
        return notes.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.preview.localizedCaseInsensitiveContains(q) }
    }

    var blocks: [Block] { MarkdownParser.parse(text) }

    // MARK: Folder

    private func prepareFolder() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try? SampleNotes.welcome.write(to: folder.appendingPathComponent("Welcome to Renote.md"), atomically: true, encoding: .utf8)
            let biology = folder.appendingPathComponent("Biology", isDirectory: true)
            try? fm.createDirectory(at: biology, withIntermediateDirectories: true)
            try? SampleNotes.biology.write(to: biology.appendingPathComponent("Cell Biology.md"), atomically: true, encoding: .utf8)
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.directoryURL = folder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveNow()
        folder = url
        UserDefaults.standard.set(url.path, forKey: Self.folderKey)
        refresh()
        selection = notes.first?.url
    }

    func revealInFinder() {
        if let selection { NSWorkspace.shared.activateFileViewerSelecting([selection]) }
        else { NSWorkspace.shared.open(folder) }
    }

    /// Reads the folder: loose notes at the top level, and one level of subject folders.
    func refresh() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        let top = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        var found: [Note] = []
        var folders: [String] = []
        for url in top {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                folders.append(url.lastPathComponent)
                let inner = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
                found += inner.filter(Self.isNote).map { Self.read($0, subject: url.lastPathComponent) }
            } else if Self.isNote(url) {
                found.append(Self.read(url, subject: nil))
            }
        }
        subjects = folders.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        notes = found.sorted { $0.modified > $1.modified }
    }

    private static func isNote(_ url: URL) -> Bool {
        ["md", "markdown", "txt"].contains(url.pathExtension.lowercased())
    }

    private static func read(_ url: URL, subject: String?) -> Note {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var note = summarise(url: url, body: body, modified: modified)
        note.subject = subject
        return note
    }

    func notes(in subject: String?) -> [Note] {
        notes.filter { $0.subject == subject }
    }

    func newSubject() {
        var name = "New Subject"
        var n = 2
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path) {
            name = "New Subject \(n)"; n += 1
        }
        try? FileManager.default.createDirectory(at: folder.appendingPathComponent(name), withIntermediateDirectories: true)
        refresh()
    }

    func renameSubject(_ subject: String, to newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        guard !clean.isEmpty, clean != subject else { return }
        saveNow()
        let from = folder.appendingPathComponent(subject)
        let to = folder.appendingPathComponent(clean)
        guard (try? FileManager.default.moveItem(at: from, to: to)) != nil else { return }
        if let sel = selection, sel.path.hasPrefix(from.path + "/") {
            let moved = to.appendingPathComponent(sel.lastPathComponent)
            loadedURL = moved
            refresh()
            selection = moved
        } else {
            refresh()
        }
    }

    /// Appends a snippet to the end of the open note, separated by a blank line.
    func append(_ snippet: String) {
        guard selection != nil else { return }
        var base = text
        while base.hasSuffix("\n\n\n") { base.removeLast() }
        let gap = base.isEmpty ? "" : base.hasSuffix("\n\n") ? "" : base.hasSuffix("\n") ? "\n" : "\n\n"
        text = base + gap + snippet + "\n"
    }

    private static func summarise(url: URL, body: String, modified: Date) -> Note {
        let lines = body.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let titleLine = lines.first { $0.hasPrefix("# ") }
        let title = titleLine.map { Inline.plain(String($0.dropFirst(2))) } ?? url.deletingPathExtension().lastPathComponent
        let preview = lines
            .filter { !$0.isEmpty && $0 != titleLine && !$0.hasPrefix("```") && !MarkdownParser.isDivider($0) }
            .prefix(2)
            .map { Inline.plain($0.trimmingCharacters(in: CharacterSet(charactersIn: "#>-*+? "))) }
            .joined(separator: " ")
        return Note(url: url, title: title, preview: preview, modified: modified)
    }

    // MARK: Notes

    private func load() {
        saveNow()
        isLoading = true
        defer { isLoading = false }
        loadedURL = selection
        guard let selection else { text = ""; return }
        text = (try? String(contentsOf: selection, encoding: .utf8)) ?? ""
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard let url = loadedURL, !isLoading else { return }
        let current = (try? String(contentsOf: url, encoding: .utf8))
        guard current != text else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        if let index = notes.firstIndex(where: { $0.url == url }) {
            let subject = notes[index].subject
            notes[index] = Self.summarise(url: url, body: text, modified: .now)
            notes[index].subject = subject
            notes.sort { $0.modified > $1.modified }
        }
    }

    func newNote(in subject: String? = nil) {
        saveNow()
        let dir = subject.map { folder.appendingPathComponent($0, isDirectory: true) } ?? folder
        var name = "Untitled"
        var n = 2
        while FileManager.default.fileExists(atPath: dir.appendingPathComponent(name + ".md").path) {
            name = "Untitled \(n)"; n += 1
        }
        let url = dir.appendingPathComponent(name + ".md")
        try? "# \(name)\n\n".write(to: url, atomically: true, encoding: .utf8)
        refresh()
        mode = .write
        selection = url
    }

    func rename(_ note: Note, to newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        guard !clean.isEmpty else { return }
        saveNow()
        let target = note.url.deletingLastPathComponent().appendingPathComponent(clean).appendingPathExtension(note.url.pathExtension)
        guard (try? FileManager.default.moveItem(at: note.url, to: target)) != nil else { return }
        let wasSelected = selection == note.url
        refresh()
        if wasSelected {
            loadedURL = target
            selection = target
        }
    }

    func trash(_ note: Note) {
        if selection == note.url { saveNow(); loadedURL = nil }
        try? FileManager.default.trashItem(at: note.url, resultingItemURL: nil)
        refresh()
        if selection == note.url { selection = notes.first?.url }
    }

    /// Ticks or unticks a checklist item from Read mode.
    func toggleChecklist(line: Int) {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(line) else { return }
        let l = lines[line]
        if let r = l.range(of: "[ ]") { lines[line] = l.replacingCharacters(in: r, with: "[x]") }
        else if let r = l.range(of: "[x]") ?? l.range(of: "[X]") { lines[line] = l.replacingCharacters(in: r, with: "[ ]") }
        text = lines.joined(separator: "\n")
    }

    /// Accent colour for a note, stable per title.
    static func accent(for title: String) -> Color {
        let colors: [Color] = [
            // Warm and cool glows that read well on black.
            Color(red: 1.00, green: 0.55, blue: 0.25), Color(red: 0.45, green: 0.60, blue: 1.00),
            Color(red: 0.40, green: 0.88, blue: 0.70), Color(red: 0.72, green: 0.55, blue: 1.00),
            Color(red: 1.00, green: 0.78, blue: 0.35), Color(red: 1.00, green: 0.48, blue: 0.62),
        ]
        let hash = title.unicodeScalars.reduce(5381) { ($0 &* 33) &+ Int($1.value) }
        return colors[abs(hash) % colors.count]
    }
}
