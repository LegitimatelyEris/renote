import AppKit
import SwiftUI

/// Lets menus and the toolbar insert text or wrap the selection in the editor.
@Observable
final class EditorController {
    fileprivate weak var textView: NSTextView?

    func insert(_ snippet: String, asBlock: Bool = true) {
        guard let tv = textView else { return }
        let ns = tv.string as NSString
        var range = tv.selectedRange()
        if range.location == NSNotFound || range.location > ns.length { range = NSRange(location: ns.length, length: 0) }
        var text = snippet
        if asBlock {
            let before = range.location > 0 ? ns.substring(with: NSRange(location: range.location - 1, length: 1)) : "\n"
            if before != "\n" { text = "\n\n" + text }
            else if range.location > 1, ns.substring(with: NSRange(location: range.location - 2, length: 1)) != "\n" { text = "\n" + text }
            text += "\n"
        }
        tv.window?.makeFirstResponder(tv)
        tv.insertText(text, replacementRange: range)
    }

    /// Wraps the selection in markers, or inserts an empty pair with the cursor inside.
    func wrap(_ open: String, _ close: String? = nil) {
        guard let tv = textView else { return }
        let close = close ?? open
        let range = tv.selectedRange()
        let selected = (tv.string as NSString).substring(with: range)
        tv.window?.makeFirstResponder(tv)
        tv.insertText(open + selected + close, replacementRange: range)
        if selected.isEmpty {
            tv.setSelectedRange(NSRange(location: range.location + (open as NSString).length, length: 0))
        }
    }

    /// Adds a prefix (like "# " or "- ") to the start of the current line.
    func prefixLine(_ prefix: String) {
        guard let tv = textView else { return }
        let ns = tv.string as NSString
        let lineRange = ns.lineRange(for: NSRange(location: tv.selectedRange().location, length: 0))
        tv.window?.makeFirstResponder(tv)
        tv.insertText(prefix, replacementRange: NSRange(location: lineRange.location, length: 0))
    }

    func focus() {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
    }
}

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var controller: EditorController
    var accent: Color

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let tv = CenteringTextView(frame: .zero)
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        scroll.documentView = tv
        tv.delegate = context.coordinator
        tv.drawsBackground = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = true
        tv.textContainerInset = NSSize(width: 28, height: 40)
        tv.font = Highlighter.baseFont
        tv.typingAttributes = Highlighter.baseAttributes
        tv.string = text
        context.coordinator.highlight(tv)
        controller.textView = tv
        DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        let tv = scroll.documentView as! NSTextView
        controller.textView = tv
        if tv.string != text {
            let selection = tv.selectedRange()
            tv.string = text
            context.coordinator.highlight(tv)
            let length = (text as NSString).length
            tv.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        }
        if context.coordinator.accent != accent {
            context.coordinator.accent = accent
            context.coordinator.highlight(tv)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        var accent: Color

        init(_ parent: MarkdownEditor) {
            self.parent = parent
            self.accent = parent.accent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            highlight(tv)
            parent.text = tv.string
        }

        func highlight(_ tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            Highlighter.apply(to: storage, accent: NSColor(accent))
        }

        // Continue lists when pressing return.
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            let ns = textView.string as NSString
            let caret = textView.selectedRange().location
            let lineRange = ns.lineRange(for: NSRange(location: caret, length: 0))
            let line = ns.substring(with: NSRange(location: lineRange.location, length: caret - lineRange.location))
            let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            let body = line.dropFirst(indent.count)
            var marker: String?
            for m in ["- [ ] ", "- [x] ", "- ( ) ", "- (x) ", "- ", "* ", "+ ", "> "] where body.hasPrefix(m) {
                marker = m.replacingOccurrences(of: "[x]", with: "[ ]").replacingOccurrences(of: "(x)", with: "( )")
                break
            }
            if marker == nil {
                let digits = body.prefix(while: \.isNumber)
                if !digits.isEmpty, body.dropFirst(digits.count).hasPrefix(". "), let n = Int(digits) {
                    marker = "\(n + 1). "
                }
            }
            guard let marker else { return false }
            // Return on an empty item ends the list.
            let currentMarker = body.prefix(marker.count)
            if body.count <= marker.count, body.trimmingCharacters(in: .whitespaces).count == currentMarker.trimmingCharacters(in: .whitespaces).count,
               body.trimmingCharacters(in: .whitespaces).count == marker.trimmingCharacters(in: .whitespaces).count {
                textView.insertText("", replacementRange: NSRange(location: lineRange.location, length: caret - lineRange.location))
                return true
            }
            textView.insertText("\n" + indent + marker, replacementRange: textView.selectedRange())
            return true
        }
    }
}

/// Keeps the text in a centred, readable column however wide the window is.
final class CenteringTextView: NSTextView {
    static let column: CGFloat = 720

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let inset = max(28, (newSize.width - Self.column) / 2)
        if abs(textContainerInset.width - inset) > 0.5 {
            textContainerInset = NSSize(width: inset, height: 40)
        }
    }
}

/// Light-touch syntax colouring: headings are larger, Markdown markers fade back.
enum Highlighter {
    static let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    static var baseAttributes: [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 5
        return [.font: baseFont, .foregroundColor: NSColor.labelColor, .paragraphStyle: p]
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    private static let heading = regex(#"^(#{1,6}) .*$"#)
    private static let marker = regex(#"^\s*([-*+] (\[[ xX]\] |\([ xX]\) )?|\d+[.)] |> ?(\[![a-zA-Z]+\])?|Q:|A:|\? |\+\+\+)"#)
    private static let bold = regex(#"(\*\*|__)(?=\S)(.+?)(\1)"#)
    private static let italic = regex(#"(?<![\*\w])(\*|_)(?=\S)([^*_\n]+?)\1(?![\*\w])"#)
    private static let highlight = regex(#"(==)(.+?)(==)"#)
    private static let cloze = regex(#"(\{\{)(.+?)(\}\})"#)
    private static let code = regex(#"`[^`\n]+`"#)
    private static let fence = regex(#"^```[\s\S]*?^```"#)
    private static let definition = regex(#"^(.+?)( :: )"#)
    private static let divider = regex(#"^\s*([-*_]\s*){3,}$"#)

    static func apply(to storage: NSTextStorage, accent: NSColor) {
        let text = storage.string
        let full = NSRange(location: 0, length: (text as NSString).length)
        let faded = NSColor.tertiaryLabelColor
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: full)

        for m in heading.matches(in: text, range: full) {
            let level = (text as NSString).substring(with: m.range(at: 1)).count
            let size: CGFloat = [22, 19, 17, 15, 14, 14][level - 1]
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: size, weight: .bold), range: m.range)
            storage.addAttribute(.foregroundColor, value: faded, range: m.range(at: 1))
        }
        for m in marker.matches(in: text, range: full) {
            storage.addAttribute(.foregroundColor, value: accent, range: m.range(at: 0))
        }
        for m in bold.matches(in: text, range: full) {
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold), range: m.range(at: 2))
            storage.addAttribute(.foregroundColor, value: faded, range: m.range(at: 1))
            storage.addAttribute(.foregroundColor, value: faded, range: m.range(at: 3))
        }
        for m in italic.matches(in: text, range: full) {
            let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: italicFont, range: m.range(at: 2))
            storage.addAttribute(.foregroundColor, value: faded, range: m.range(at: 1))
        }
        for m in highlight.matches(in: text, range: full) {
            storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: m.range(at: 2))
            storage.addAttribute(.foregroundColor, value: faded, range: m.range(at: 1))
            storage.addAttribute(.foregroundColor, value: faded, range: m.range(at: 3))
        }
        for m in cloze.matches(in: text, range: full) {
            storage.addAttribute(.backgroundColor, value: accent.withAlphaComponent(0.18), range: m.range(at: 2))
            storage.addAttribute(.foregroundColor, value: accent, range: m.range(at: 1))
            storage.addAttribute(.foregroundColor, value: accent, range: m.range(at: 3))
        }
        for m in definition.matches(in: text, range: full) {
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold), range: m.range(at: 1))
            storage.addAttribute(.foregroundColor, value: accent, range: m.range(at: 2))
        }
        for m in divider.matches(in: text, range: full) {
            storage.addAttribute(.foregroundColor, value: faded, range: m.range)
        }
        for m in code.matches(in: text, range: full) {
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
        }
        for m in fence.matches(in: text, range: full) {
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
            storage.addAttribute(.font, value: baseFont, range: m.range)
        }
        storage.endEditing()
    }
}
