import AppKit

/// Blurs whatever is behind the window, the same way Terminal and iTerm do, so the
/// page's own tint (colour + opacity) sits over a frosted desktop. Uses the window
/// server's blur radius call; if that's ever unavailable, falls back to a plain
/// NSVisualEffectView behind the page.
enum WindowBlur {
    private typealias ConnectionFn = @convention(c) () -> Int32
    private typealias BlurFn = @convention(c) (Int32, Int32, Int32) -> Int32

    private static let functions: (ConnectionFn, BlurFn)? = {
        let handle = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        guard let conn = dlsym(handle, "CGSDefaultConnectionForThread") ?? dlsym(handle, "CGSMainConnectionID"),
              let blur = dlsym(handle, "CGSSetWindowBackgroundBlurRadius") else { return nil }
        return (unsafeBitCast(conn, to: ConnectionFn.self), unsafeBitCast(blur, to: BlurFn.self))
    }()

    /// Makes the window see-through so the page decides how much shows through.
    static func prepare(_ window: NSWindow) {
        window.isOpaque = false
        // Not fully clear: the window server only blurs behind pixels that exist,
        // so use an almost-invisible colour (the same trick Terminal-style apps use).
        window.backgroundColor = NSColor.black.withAlphaComponent(0.001)
        window.hasShadow = true
        if let content = window.contentView {
            content.wantsLayer = true
            content.layer?.backgroundColor = NSColor.clear.cgColor
            content.layer?.isOpaque = false
        }
        window.invalidateShadow()
    }

    static func set(_ window: NSWindow, radius: Int) {
        if let (connection, setBlur) = functions {
            _ = setBlur(connection(), Int32(window.windowNumber), Int32(max(0, min(radius, 100))))
            window.invalidateShadow()
        } else {
            fallback(window, on: radius > 0)
        }
    }

    private static func fallback(_ window: NSWindow, on: Bool) {
        guard let content = window.contentView else { return }
        let existing = content.subviews.first { $0 is NSVisualEffectView } as? NSVisualEffectView
        if on, existing == nil {
            let fx = NSVisualEffectView(frame: content.bounds)
            fx.autoresizingMask = [.width, .height]
            fx.blendingMode = .behindWindow
            fx.material = .underWindowBackground
            fx.state = .active
            content.addSubview(fx, positioned: .below, relativeTo: nil)
        } else if !on {
            existing?.removeFromSuperview()
        }
    }
}
