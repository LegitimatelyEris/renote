import AppKit
import SwiftUI

/// Renote's look: a black canvas, hairline borders, tight sans type, white buttons and
/// one accent colour (adapted from tryprofound.com).
enum Theme {
    static let text = Color(red: 237 / 255, green: 242 / 255, blue: 245 / 255)
    static let body = Color.white.opacity(0.80)
    static let muted = Color.white.opacity(0.60)
    static let faint = Color.white.opacity(0.38)
    static let line = Color.white.opacity(0.10)
    static let lineSoft = Color.white.opacity(0.06)
    static let surface = Color.white.opacity(0.035)
    static let raised = Color(white: 0.08)
}

// MARK: - Fonts

/// Fonts available for headings and body text. All ship with macOS.
enum PageFont: String, CaseIterable, Identifiable {
    case system = "SF Pro"
    case rounded = "SF Pro Rounded"
    case newYork = "New York"
    case charter = "Charter"
    case iowan = "Iowan Old Style"
    case georgia = "Georgia"
    case avenir = "Avenir Next"
    case futura = "Futura"
    case mono = "SF Mono"
    case menlo = "Menlo"
    case hand = "Bradley Hand"

    var id: String { rawValue }

    var note: String {
        switch self {
        case .system: "Clean sans"
        case .rounded: "Soft sans"
        case .newYork: "Editorial serif"
        case .charter: "Book serif"
        case .iowan: "Classic serif"
        case .georgia: "Web serif"
        case .avenir: "Geometric sans"
        case .futura: "Bold geometric"
        case .mono: "Monospace"
        case .menlo: "Typewriter"
        case .hand: "Handwritten"
        }
    }

    /// Accepts names saved by the web version too, mapping them to the closest Mac font.
    init(saved: String?) {
        switch saved ?? "" {
        case let s where PageFont(rawValue: s) != nil: self = PageFont(rawValue: s)!
        case "Newsreader", "Fraunces": self = .newYork
        case "Literata": self = .charter
        case "Instrument Serif": self = .iowan
        case "JetBrains Mono": self = .mono
        case "IBM Plex Mono": self = .menlo
        case "Caveat": self = .hand
        case "Space Grotesk": self = .avenir
        default: self = .system
        }
    }

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system: .system(size: size, weight: weight)
        case .rounded: .system(size: size, weight: weight, design: .rounded)
        case .newYork: .system(size: size, weight: weight, design: .serif)
        case .mono: .system(size: size, weight: weight, design: .monospaced)
        default: .custom(rawValue, size: size).weight(weight)
        }
    }

    func nsFont(_ size: CGFloat, _ weight: NSFont.Weight = .regular, italic: Bool = false) -> NSFont {
        var font: NSFont
        switch self {
        case .system, .rounded, .newYork, .mono:
            font = NSFont.systemFont(ofSize: size, weight: weight)
            let design: NSFontDescriptor.SystemDesign = switch self {
            case .rounded: .rounded
            case .newYork: .serif
            case .mono: .monospaced
            default: .default
            }
            if let d = font.fontDescriptor.withDesign(design), let f = NSFont(descriptor: d, size: size) { font = f }
        default:
            font = NSFont(name: rawValue, size: size) ?? .systemFont(ofSize: size, weight: weight)
            if weight >= .semibold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
        }
        if italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        return font
    }
}

// MARK: - Look settings

/// Fonts, layout and window colour. Saved to .renote/settings.json under "type",
/// the same file and fields the web version uses.
struct LookSettings: Equatable {
    var head: PageFont = .system
    var body: PageFont = .system
    var size: Double = 17
    var width: Double = 720
    var leading: Double = 1.7
    var accent: String = "orange"
    var bg: String = "#0a0a0b"
    var bgAlpha: Double = 0.72

    static let accents: [(String, Color)] = [
        ("orange", Color(hex: "#f97316")), ("amber", Color(hex: "#f59e0b")), ("lime", Color(hex: "#84cc16")),
        ("green", Color(hex: "#22c55e")), ("teal", Color(hex: "#14b8a6")), ("blue", Color(hex: "#3b82f6")),
        ("violet", Color(hex: "#8b5cf6")), ("pink", Color(hex: "#ec4899")), ("red", Color(hex: "#ef4444")),
        ("white", Color(hex: "#e5e5e5")),
    ]
    static let windowColors = ["#0a0a0b", "#1c1c1e", "#0f172a", "#1e1b4b", "#2e1065", "#3b0a24", "#052e2b", "#14261b", "#3a2a0a", "#5c4a1e"]

    var accentColor: Color { Self.accents.first { $0.0 == accent }?.1 ?? Color(hex: "#f97316") }
    var accentLight: Color { accentColor.mix(with: .white, by: 0.45) }
    var windowColor: Color { Color(hex: bg) }
    var isFullWidth: Bool { width >= 1500 }

    init() {}

    init(json: [String: Any]) {
        head = PageFont(saved: json["head"] as? String)
        body = PageFont(saved: json["body"] as? String)
        size = json["size"] as? Double ?? size
        width = json["width"] as? Double ?? width
        leading = json["leading"] as? Double ?? leading
        accent = json["accent"] as? String ?? accent
        bg = json["bg"] as? String ?? bg
        bgAlpha = json["bgAlpha"] as? Double ?? bgAlpha
    }

    var json: [String: Any] {
        ["head": head.rawValue, "body": body.rawValue, "size": size, "width": width, "leading": leading,
         "accent": accent, "bg": bg, "bgAlpha": bgAlpha]
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }

    var hex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02x%02x%02x", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}
