#if DEBUG
import AppKit
import WebKit

/// Debug only: `Renote -snapshotDir /path` saves PNGs of a few screens, then quits.
/// Lets the layout be checked without screen recording permission.
enum DebugSnapshot {
    static func runIfRequested(_ web: RenoteWebView) {
        guard let dir = UserDefaults.standard.string(forKey: "snapshotDir") else { return }
        let pages = UserDefaults.standard.string(forKey: "snapshotPages")?.components(separatedBy: ",") ?? ["#/"]
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            for (i, hash) in pages.enumerated() {
                _ = try? await web.evaluateJavaScript("location.hash = '\(hash)'; document.head.insertAdjacentHTML('beforeend', '<style>*{transition:none!important}</style>'); 1")
                try? await Task.sleep(for: .seconds(2))
                if let image = try? await web.takeSnapshot(configuration: nil),
                   let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("app-\(i).png"))
                }
            }
            NSApp.terminate(nil)
        }
    }
}
#endif
