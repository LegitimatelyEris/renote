import Foundation
import WebKit
import UniformTypeIdentifiers

/// Serves `renote://app/…`: the bundled site, plus the same /api routes as server.js.
final class SchemeHandler: NSObject, WKURLSchemeHandler {
    private let site = Bundle.main.resourceURL!.appendingPathComponent("public")

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        let request = task.request
        guard let url = request.url else { return }
        let response: Response
        if url.path.hasPrefix("/api/") {
            response = NotesAPI.shared.handle(method: request.httpMethod ?? "GET", url: url, body: Self.body(of: request))
        } else {
            response = staticFile(url.path)
        }
        let http = HTTPURLResponse(url: url, statusCode: response.status, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": response.type, "Cache-Control": "no-store"])!
        task.didReceive(http)
        task.didReceive(response.data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}

    private func staticFile(_ path: String) -> Response {
        let clean = path == "/" || path.isEmpty ? "/index.html" : path
        var file = site.appendingPathComponent(String(clean.dropFirst())).standardizedFileURL
        if !file.path.hasPrefix(site.path) || !FileManager.default.fileExists(atPath: file.path) {
            file = site.appendingPathComponent("index.html")
        }
        let data = (try? Data(contentsOf: file)) ?? Data()
        return Response(status: 200, type: Self.mime(file), data: data)
    }

    static func mime(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html": "text/html; charset=utf-8"
        case "js": "text/javascript; charset=utf-8"
        case "css": "text/css; charset=utf-8"
        case "json": "application/json"
        case "svg": "image/svg+xml"
        default: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
    }

    private static func body(of request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}

struct Response {
    var status: Int
    var type: String
    var data: Data

    static func json(_ value: Any, status: Int = 200) -> Response {
        let data = (try? JSONSerialization.data(withJSONObject: value)) ?? Data("{}".utf8)
        return Response(status: status, type: "application/json", data: data)
    }
    static func error(_ message: String, status: Int = 400) -> Response { json(["error": message], status: status) }
}

/// Notes are Markdown files in ~/Documents/Renote. Sub-folders are subjects.
/// Revision sessions are appended to .renote/log.json; trash goes to .renote/trash.
final class NotesAPI {
    static let shared = NotesAPI()
    let root: URL
    private let fm = FileManager.default
    private var log: URL { root.appendingPathComponent(".renote/log.json") }
    private var settings: URL { root.appendingPathComponent(".renote/settings.json") }
    private let noteExtensions: Set<String> = ["md", "markdown", "txt"]

    private init() {
        root = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Renote", isDirectory: true)
        seedIfNeeded()
    }

    private func seedIfNeeded() {
        guard !fm.fileExists(atPath: root.path),
              let samples = Bundle.main.resourceURL?.appendingPathComponent("samples") else { return }
        try? fm.createDirectory(at: root.appendingPathComponent("Biology"), withIntermediateDirectories: true)
        try? fm.copyItem(at: samples.appendingPathComponent("welcome.md"), to: root.appendingPathComponent("Welcome to Renote.md"))
        try? fm.copyItem(at: samples.appendingPathComponent("cell-biology.md"), to: root.appendingPathComponent("Biology/Cell Biology.md"))
    }

    /// Resolves a relative path inside the notes folder, refusing anything outside it.
    private func safe(_ rel: String?) -> URL? {
        let full = root.appendingPathComponent(rel ?? "").standardizedFileURL
        let base = root.standardizedFileURL.path
        return full.path == base || full.path.hasPrefix(base + "/") ? full : nil
    }

    private func relative(_ url: URL) -> String {
        String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
    }

    func handle(method: String, url: URL, body: Data) -> Response {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let param = { (name: String) in query.first { $0.name == name }?.value }
        let input = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]

        switch (method, url.path) {
        case ("GET", "/api/notes"):
            return .json(list())

        case ("GET", "/api/note"):
            guard let file = safe(param("path")), let text = try? String(contentsOf: file, encoding: .utf8) else { return .error("Not found", status: 404) }
            return .json(["path": param("path") ?? "", "text": text])

        case ("PUT", "/api/note"):
            guard let path = input["path"] as? String, let text = input["text"] as? String, let file = safe(path) else { return .error("Bad request") }
            do { try text.write(to: file, atomically: true, encoding: .utf8) } catch { return .error(error.localizedDescription, status: 500) }
            return .json(summary(file, subject: path.contains("/") ? String(path.split(separator: "/")[0]) : nil))

        case ("POST", "/api/note"):
            let subject = input["subject"] as? String
            guard let dir = safe(subject) else { return .error("Bad subject") }
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            var name = "Untitled", n = 2
            while fm.fileExists(atPath: dir.appendingPathComponent(name + ".md").path) { name = "Untitled \(n)"; n += 1 }
            let file = dir.appendingPathComponent(name + ".md")
            try? "# \(name)\n\n".write(to: file, atomically: true, encoding: .utf8)
            return .json(summary(file, subject: subject), status: 201)

        case ("POST", "/api/note/rename"):
            guard let path = input["path"] as? String, let from = safe(path) else { return .error("Bad request") }
            let clean = ((input["name"] as? String) ?? "").replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
            guard !clean.isEmpty else { return .error("Name required") }
            let to = from.deletingLastPathComponent().appendingPathComponent(clean).appendingPathExtension(from.pathExtension)
            if fm.fileExists(atPath: to.path) { return .error("A note with that name already exists", status: 409) }
            do { try fm.moveItem(at: from, to: to) } catch { return .error(error.localizedDescription, status: 500) }
            return .json(["path": relative(to)])

        case ("POST", "/api/note/trash"):
            guard let path = input["path"] as? String, let from = safe(path) else { return .error("Bad request") }
            let trash = root.appendingPathComponent(".renote/trash")
            try? fm.createDirectory(at: trash, withIntermediateDirectories: true)
            let stamp = Int(Date().timeIntervalSince1970 * 1000)
            do { try fm.moveItem(at: from, to: trash.appendingPathComponent("\(stamp)-\(from.lastPathComponent)")) } catch { return .error(error.localizedDescription, status: 500) }
            return .json(["ok": true])

        case ("POST", "/api/subject"):
            let base = ((input["name"] as? String) ?? "New Subject").replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-").trimmingCharacters(in: .whitespaces)
            let clean = base.isEmpty ? "New Subject" : base
            var name = clean, n = 2
            while fm.fileExists(atPath: root.appendingPathComponent(name).path) { name = "\(clean) \(n)"; n += 1 }
            try? fm.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
            return .json(["name": name], status: 201)

        case ("GET", "/api/log"):
            return .json(readLog())

        case ("POST", "/api/log"):
            var entries = readLog()
            var entry = input
            entry["at"] = ISO8601DateFormatter.withMillis.string(from: Date())
            entries.append(entry)
            try? fm.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted]) { try? data.write(to: log) }
            return .json(["ok": true, "count": entries.count], status: 201)

        case ("GET", "/api/settings"):
            let data = (try? Data(contentsOf: settings)) ?? Data("{}".utf8)
            return Response(status: 200, type: "application/json", data: data)

        case ("PUT", "/api/settings"):
            // Fonts, size, width and accent chosen in the Aa panel.
            try? fm.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? body.write(to: settings)
            return Response(status: 200, type: "application/json", data: body)

        case ("GET", "/api/file"):
            guard let file = safe(param("path")), let data = try? Data(contentsOf: file) else { return .error("Not found", status: 404) }
            return Response(status: 200, type: SchemeHandler.mime(file), data: data)

        default:
            return .error("Not found", status: 404)
        }
    }

    private func readLog() -> [[String: Any]] {
        guard let data = try? Data(contentsOf: log) else { return [] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
    }

    private func list() -> [String: Any] {
        var notes: [[String: Any]] = []
        var subjects: [String] = []
        let entries = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        for entry in entries {
            if (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                subjects.append(entry.lastPathComponent)
                let inner = (try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                notes += inner.filter { noteExtensions.contains($0.pathExtension.lowercased()) }.map { summary($0, subject: entry.lastPathComponent) }
            } else if noteExtensions.contains(entry.pathExtension.lowercased()) {
                notes.append(summary(entry, subject: nil))
            }
        }
        subjects.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        notes.sort { ($0["modified"] as? Double ?? 0) > ($1["modified"] as? Double ?? 0) }
        return ["folder": root.path, "subjects": subjects, "notes": notes]
    }

    private func summary(_ file: URL, subject: String?) -> [String: Any] {
        let body = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let lines = body.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let strip: (String) -> String = { $0.replacingOccurrences(of: "[*_=~`{}^+]", with: "", options: .regularExpression) }
        let title = lines.first { $0.hasPrefix("# ") }.map { strip(String($0.dropFirst(2))).trimmingCharacters(in: .whitespaces) }
            ?? file.deletingPathExtension().lastPathComponent
        let preview = lines.filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("```") }.prefix(2).joined(separator: " ")
            .replacingOccurrences(of: "[*_=~`{}^>|]", with: "", options: .regularExpression)
        return [
            "path": relative(file),
            "title": title,
            "preview": String(preview.prefix(160)),
            "subject": subject.map { $0 as Any } ?? NSNull(),
            "modified": modified.timeIntervalSince1970 * 1000,
        ]
    }
}

private extension ISO8601DateFormatter {
    static let withMillis: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
