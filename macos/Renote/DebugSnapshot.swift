#if DEBUG
import AppKit
import WebKit

/// Debug only: `Renote -snapshotDir /path` saves PNGs of a few screens, then quits.
/// Lets the layout be checked without screen recording permission.
enum DebugSnapshot {
    private typealias CaptureFn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

    /// CGWindowListCreateImage is hidden from the current SDK, so look it up directly.
    static func windowImage(_ window: NSWindow) -> CGImage? {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        let capture = unsafeBitCast(sym, to: CaptureFn.self)
        // .optionIncludingWindow = 1 << 3, .boundsIgnoreFraming = 1 << 0
        return capture(.null, 1 << 3, UInt32(window.windowNumber), 1 << 0)?.takeRetainedValue()
    }

    /// Debug only: `Renote -floatTest YES` floats a small window in the bottom-right
    /// corner for a few seconds so its transparency can be screenshotted, then quits.
    static func floatTestIfRequested(_ web: RenoteWebView) {
        guard UserDefaults.standard.bool(forKey: "floatTest"), let window = web.window, let screen = window.screen ?? NSScreen.main else { return }
        let f = screen.visibleFrame
        window.level = .floating
        window.setFrame(NSRect(x: f.maxX - 720, y: f.minY + 120, width: 700, height: 460), display: true)
        window.orderFrontRegardless()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            NSApp.terminate(nil)
        }
    }

    static func runIfRequested(_ web: RenoteWebView) {
        guard let dir = UserDefaults.standard.string(forKey: "snapshotDir") else { return }
        let pages = UserDefaults.standard.string(forKey: "snapshotPages")?.components(separatedBy: ",") ?? ["#/"]
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            for (i, hash) in pages.enumerated() {
                _ = try? await web.evaluateJavaScript("location.hash = '\(hash)'; document.head.insertAdjacentHTML('beforeend', '<style>*{transition:none!important}</style>'); 1")
                try? await Task.sleep(for: .seconds(2))
                if UserDefaults.standard.bool(forKey: "snapshotProbe"),
                   let probe = try? await web.evaluateJavaScript("JSON.stringify({ tint: getComputedStyle(document.getElementById('tint')).opacity, winAlpha: document.documentElement.style.getPropertyValue('--win-alpha'), native: document.documentElement.className, htmlBg: getComputedStyle(document.documentElement).backgroundColor, bodyBg: getComputedStyle(document.body).backgroundColor, settings: null })") {
                    print("PROBE", probe)
                    let s = try? await web.evaluateJavaScript("fetch('/api/settings').then(r => r.text())")
                    print("SETTINGS", String(describing: s))
                }
                if let image = try? await web.takeSnapshot(configuration: nil),
                   let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("app-\(i).png"))
                }
                // The whole composited window (with its transparency), to check what the desktop would see.
                if let window = web.window, let image = windowImage(window) {
                    let rep = NSBitmapImageRep(cgImage: image)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("win-\(i).png"))
                }
            }
            NSApp.terminate(nil)
        }
    }
}
#endif
