#if DEBUG
import AppKit

/// Debug only. `Renote -floatTest YES [-openNote "Name.md"] [-openMode view|edit|revise] [-screen home|progress|revise]`
/// floats the window in the bottom-right corner for a few seconds so it can be
/// screenshotted over the desktop, then quits.
enum DebugFloat {
    static func run(window: NSWindow, store: NoteStore) {
        let d = UserDefaults.standard
        guard d.bool(forKey: "floatTest"), let screen = window.screen ?? NSScreen.main else { return }
        if let name = d.string(forKey: "openNote"), let note = store.notes.first(where: { $0.url.lastPathComponent == name }) {
            store.open(note.url, mode: NoteMode(rawValue: d.string(forKey: "openMode") ?? "view") ?? .view)
        }
        switch d.string(forKey: "screen") {
        case "progress": store.screen = .progress
        case "revise": store.screen = .reviseHub
        default: break
        }
        let f = screen.visibleFrame
        let w = d.double(forKey: "floatWidth") > 0 ? d.double(forKey: "floatWidth") : 1240
        let h = d.double(forKey: "floatHeight") > 0 ? d.double(forKey: "floatHeight") : 780
        window.level = .floating
        window.setFrame(NSRect(x: f.maxX - w - 16, y: f.minY + 16, width: w, height: h), display: true)
        window.orderFrontRegardless()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(d.double(forKey: "floatSeconds") > 0 ? d.double(forKey: "floatSeconds") : 6))
            NSApp.terminate(nil)
        }
    }
}
#endif
