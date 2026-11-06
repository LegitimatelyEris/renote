#if DEBUG
import AppKit

/// Debug-only: `Renote.app/Contents/MacOS/Renote -snapshotDir /path` renders the
/// window in each mode to PNGs, then quits. Used to check layouts without screen recording.
enum DebugSnapshot {
    static func runIfRequested(store: NoteStore) {
        guard let dir = UserDefaults.standard.string(forKey: "snapshotDir") else { return }
        let note = UserDefaults.standard.string(forKey: "snapshotNote")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if let note, let match = store.notes.first(where: { $0.title == note }) { store.selection = match.url }
            for mode in NoteMode.allCases {
                store.mode = mode
                try? await Task.sleep(for: .seconds(1.2))
                capture(to: URL(fileURLWithPath: dir).appendingPathComponent("\(mode.rawValue).png"))
            }
            NSApp.terminate(nil)
        }
    }

    private static func capture(to url: URL) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
