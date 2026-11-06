import AppKit
import Observation
import SwiftUI

struct Note: Identifiable, Hashable {
    var url: URL
    var title: String
    var preview: String
    var modified: Date
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
            try? SampleNotes.biology.write(to: folder.appendingPathComponent("Cell Biology.md"), atomically: true, encoding: .utf8)
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

    func refresh() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey],
                                                options: [.skipsHiddenFiles])) ?? []
        notes = urls
            .filter { ["md", "markdown", "txt"].contains($0.pathExtension.lowercased()) }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                return Self.summarise(url: url, body: body, modified: modified)
            }
            .sorted { $0.modified > $1.modified }
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
            notes[index] = Self.summarise(url: url, body: text, modified: .now)
            notes.sort { $0.modified > $1.modified }
        }
    }

    func newNote() {
        saveNow()
        var name = "Untitled"
        var n = 2
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(name + ".md").path) {
            name = "Untitled \(n)"; n += 1
        }
        let url = folder.appendingPathComponent(name + ".md")
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
