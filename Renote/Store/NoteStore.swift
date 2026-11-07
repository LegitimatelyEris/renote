import AppKit
import Observation
import SwiftUI

struct Note: Identifiable, Hashable {
    var url: URL
    var title: String
    var preview: String
    var modified: Date
    var subject: String?
    var id: URL { url }
}

struct LogEntry: Identifiable, Hashable {
    var path: String
    var title: String
    var subject: String?
    var cards: Int
    var known: Int
    var at: Date
    var id: String { path + at.description }
}

enum Screen: Hashable {
    case home(subject: String?) // nil = all notes, "" = unsorted
    case note
    case reviseHub
    case progress
}

enum NoteMode: String { case view, edit, revise }

/// Everything Renote knows: the notes folder (~/Documents/Renote, sub-folders are
/// subjects), the open note, the revision log and the look settings. Uses the same
/// files as the web version, so both can be used on the same notes.
@Observable
final class NoteStore {
    // Library
    private(set) var notes: [Note] = []
    private(set) var subjects: [String] = []
    private(set) var log: [LogEntry] = []
    let root: URL

    // Navigation
    var screen: Screen = .home(subject: nil)
    var mode: NoteMode = .view
    var search = ""
    var sidebarHidden = false

    // Open note
    private(set) var current: URL?
    var text: String = "" {
        didSet { if text != oldValue, !loading { scheduleSave() } }
    }
    private(set) var savedText = ""
    private var loading = false
    private var saveTask: Task<Void, Never>?

    // Look
    var look = LookSettings() {
        didSet { if look != oldValue { scheduleLookSave() } }
    }
    private var lookTask: Task<Void, Never>?

    private let fm = FileManager.default
    private var renoteDir: URL { root.appendingPathComponent(".renote", isDirectory: true) }

    init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Renote", isDirectory: true)
        seedIfNeeded()
        refresh()
        loadLog()
        loadLook()
    }

    // MARK: Folder

    private func seedIfNeeded() {
        guard !fm.fileExists(atPath: root.path) else { return }
        try? fm.createDirectory(at: root.appendingPathComponent("Biology"), withIntermediateDirectories: true)
        if let welcome = Bundle.main.url(forResource: "welcome", withExtension: "md") {
            try? fm.copyItem(at: welcome, to: root.appendingPathComponent("Welcome to Renote.md"))
        }
        if let bio = Bundle.main.url(forResource: "cell-biology", withExtension: "md") {
            try? fm.copyItem(at: bio, to: root.appendingPathComponent("Biology/Cell Biology.md"))
        }
    }

    func refresh() {
        var found: [Note] = []
        var folders: [String] = []
        let entries = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        for entry in entries {
            if (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                folders.append(entry.lastPathComponent)
                let inner = (try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                found += inner.filter(Self.isNote).map { read($0, subject: entry.lastPathComponent) }
            } else if Self.isNote(entry) {
                found.append(read(entry, subject: nil))
            }
        }
        subjects = folders.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        notes = found.sorted { $0.modified > $1.modified }
    }

    private static func isNote(_ url: URL) -> Bool { ["md", "markdown", "txt"].contains(url.pathExtension.lowercased()) }

    private func read(_ url: URL, subject: String?) -> Note {
        let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return Self.summarise(url: url, body: body, modified: modified, subject: subject)
    }

    static func summarise(url: URL, body: String, modified: Date, subject: String?) -> Note {
        let lines = body.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let titleLine = lines.first { $0.hasPrefix("# ") }
        let title = titleLine.map { Inline.plain(String($0.dropFirst(2))) }.flatMap { $0.isEmpty ? nil : $0 } ?? url.deletingPathExtension().lastPathComponent
        let preview = lines.filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("```") && !MarkdownParser.isDivider($0) }
            .prefix(2).map { Inline.plain($0.trimmingCharacters(in: CharacterSet(charactersIn: ">-*+? "))) }.joined(separator: " ")
        return Note(url: url, title: title, preview: String(preview.prefix(160)), modified: modified, subject: subject)
    }

    func notes(in subject: String?) -> [Note] { notes.filter { $0.subject == subject } }

    var currentNote: Note? { notes.first { $0.url == current } }

    func relativePath(_ url: URL) -> String {
        String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
    }

    // MARK: Opening and saving

    func open(_ url: URL, mode: NoteMode = .view) {
        saveNow()
        loading = true
        current = url
        text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        savedText = text
        loading = false
        self.mode = mode
        screen = .note
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        guard let url = current, text != savedText else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        savedText = text
        if let i = notes.firstIndex(where: { $0.url == url }) {
            notes[i] = Self.summarise(url: url, body: text, modified: .now, subject: notes[i].subject)
        }
    }

    var isDirty: Bool { text != savedText }

    // MARK: Creating, renaming, trashing

    func newNote(in subject: String? = nil) {
        saveNow()
        let dir = subject.map { root.appendingPathComponent($0, isDirectory: true) } ?? root
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var name = "Untitled", n = 2
        while fm.fileExists(atPath: dir.appendingPathComponent(name + ".md").path) { name = "Untitled \(n)"; n += 1 }
        let url = dir.appendingPathComponent(name + ".md")
        try? "# \(name)\n\n".write(to: url, atomically: true, encoding: .utf8)
        refresh()
        open(url, mode: .edit)
    }

    func newSubject(named name: String) {
        let clean = name.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
        var final = clean.isEmpty ? "New Subject" : clean, n = 2
        let base = final
        while fm.fileExists(atPath: root.appendingPathComponent(final).path) { final = "\(base) \(n)"; n += 1 }
        try? fm.createDirectory(at: root.appendingPathComponent(final), withIntermediateDirectories: true)
        refresh()
        screen = .home(subject: final)
    }

    func rename(_ note: Note, to newName: String) {
        let clean = newName.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        saveNow()
        let target = note.url.deletingLastPathComponent().appendingPathComponent(clean).appendingPathExtension(note.url.pathExtension)
        guard !fm.fileExists(atPath: target.path), (try? fm.moveItem(at: note.url, to: target)) != nil else { return }
        if current == note.url { current = target }
        refresh()
    }

    /// Moves a note into .renote/trash inside the notes folder, so nothing is lost.
    func trash(_ note: Note) {
        if current == note.url { saveNow() }
        let trash = renoteDir.appendingPathComponent("trash", isDirectory: true)
        try? fm.createDirectory(at: trash, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        try? fm.moveItem(at: note.url, to: trash.appendingPathComponent("\(stamp)-\(note.url.lastPathComponent)"))
        if current == note.url { current = nil; text = ""; savedText = "" }
        refresh()
        screen = .home(subject: nil)
    }

    func revealInFinder() {
        if let current { NSWorkspace.shared.activateFileViewerSelecting([current]) } else { NSWorkspace.shared.open(root) }
    }

    /// Ticks or unticks a checklist line while reading.
    func toggleChecklist(line: Int) {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(line) else { return }
        let l = lines[line]
        if let r = l.range(of: "[ ]") { lines[line] = l.replacingCharacters(in: r, with: "[x]") }
        else if let r = l.range(of: "[x]") ?? l.range(of: "[X]") { lines[line] = l.replacingCharacters(in: r, with: "[ ]") }
        text = lines.joined(separator: "\n")
    }

    // MARK: Revision log

    private var logURL: URL { renoteDir.appendingPathComponent("log.json") }
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func loadLog() {
        guard let data = try? Data(contentsOf: logURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { log = []; return }
        log = raw.compactMap { e in
            guard let path = e["path"] as? String, let at = (e["at"] as? String).flatMap({ Self.iso.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }) else { return nil }
            return LogEntry(path: path, title: e["title"] as? String ?? path, subject: e["subject"] as? String,
                            cards: e["cards"] as? Int ?? 0, known: e["known"] as? Int ?? 0, at: at)
        }
    }

    func logSession(cards: Int, known: Int, rounds: Int) {
        guard let note = currentNote else { return }
        var raw = ((try? Data(contentsOf: logURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] }) ?? []
        raw.append(["path": relativePath(note.url), "title": note.title, "subject": note.subject as Any? ?? NSNull(),
                    "cards": cards, "known": known, "rounds": rounds, "at": Self.iso.string(from: .now)])
        try? fm.createDirectory(at: renoteDir, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted]) { try? data.write(to: logURL) }
        loadLog()
    }

    /// Notes not revised in the last week.
    var dueNotes: [Note] {
        let latest = Dictionary(log.map { ($0.path, $0.at) }, uniquingKeysWith: max)
        return notes.filter { note in
            guard let last = latest[relativePath(note.url)] else { return true }
            return Date().timeIntervalSince(last) > 7 * 86400
        }
    }

    // MARK: Look settings

    private var settingsURL: URL { renoteDir.appendingPathComponent("settings.json") }

    private func loadLook() {
        guard let data = try? Data(contentsOf: settingsURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = raw["type"] as? [String: Any] else { return }
        let loaded = LookSettings(json: type)
        lookTask?.cancel()
        look = loaded
        lookTask?.cancel()
    }

    private func scheduleLookSave() {
        lookTask?.cancel()
        let snapshot = look
        lookTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            var raw = ((try? Data(contentsOf: self.settingsURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) ?? [:]
            var type = raw["type"] as? [String: Any] ?? [:]
            for (k, v) in snapshot.json { type[k] = v }
            raw["type"] = type
            try? self.fm.createDirectory(at: self.renoteDir, withIntermediateDirectories: true)
            if let data = try? JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted]) { try? data.write(to: self.settingsURL) }
        }
    }
}
