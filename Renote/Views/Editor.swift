import AppKit
import SwiftUI

/// Edit mode: the page itself is a native text view. Formatting appears as you type;
/// Markdown symbols disappear on every line except the one you're on (like Bear).
struct PageEditor: View {
    @Bindable var store: NoteStore
    @Binding var caretLine: Int?

    var body: some View {
        LiveEditor(text: $store.text, look: store.look, caretLine: $caretLine)
    }
}

struct LiveEditor: NSViewRepresentable {
    @Binding var text: String
    var look: LookSettings
    @Binding var caretLine: Int?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let tv = PageTextView(frame: .zero)
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.drawsBackground = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isContinuousSpellCheckingEnabled = true
        tv.usesFindBar = true
        tv.delegate = context.coordinator
        tv.look = look
        tv.insertionPointColor = NSColor(look.accentColor)
        tv.selectedTextAttributes = [.backgroundColor: NSColor(look.accentColor).withAlphaComponent(0.28)]
        tv.string = text
        scroll.documentView = tv
        context.coordinator.textView = tv
        context.coordinator.restyle()
        DispatchQueue.main.async {
            tv.window?.makeFirstResponder(tv)
            context.coordinator.placeCaret(atLine: caretLine)
            caretLine = nil
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let c = context.coordinator
        c.parent = self
        guard let tv = c.textView else { return }
        if tv.look != look {
            tv.look = look
            tv.insertionPointColor = NSColor(look.accentColor)
            tv.relayout()
            c.restyle()
        }
        if tv.string != text {
            let sel = tv.selectedRange()
            tv.string = text
            c.restyle()
            tv.setSelectedRange(NSRange(location: min(sel.location, (text as NSString).length), length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LiveEditor
        weak var textView: PageTextView?
        private var styling = false

        init(_ parent: LiveEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            restyle()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !styling else { return }
            restyle()
        }

        func restyle() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            styling = true
            let caret = tv.selectedRange()
            let active = (tv.string as NSString).lineRange(for: NSRange(location: min(caret.location, (tv.string as NSString).length), length: 0))
            LiveStyler.apply(to: storage, look: tv.look, activeLine: tv.window?.firstResponder === tv ? active : NSRange(location: NSNotFound, length: 0))
            tv.typingAttributes = LiveStyler.bodyAttributes(tv.look)
            styling = false
        }

        func placeCaret(atLine line: Int?) {
            guard let tv = textView, let line else { return }
            let ns = tv.string as NSString
            var location = 0, current = 0
            while current < line, location < ns.length {
                location = NSMaxRange(ns.lineRange(for: NSRange(location: location, length: 0)))
                current += 1
            }
            let end = NSMaxRange(ns.lineRange(for: NSRange(location: min(location, ns.length), length: 0)))
            let caret = max(location, min(end - 1, ns.length))
            tv.setSelectedRange(NSRange(location: min(caret, ns.length), length: 0))
            tv.scrollRangeToVisible(NSRange(location: location, length: 0))
            restyle()
        }

        // Continue lists, checklists and quotes on Return.
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            let ns = textView.string as NSString
            let caret = textView.selectedRange().location
            let lineRange = ns.lineRange(for: NSRange(location: caret, length: 0))
            let line = ns.substring(with: NSRange(location: lineRange.location, length: caret - lineRange.location))
            let indent = String(line.prefix { $0 == " " || $0 == "\t" })
            let body = line.dropFirst(indent.count)
            var marker: String?
            for m in ["- [ ] ", "- [x] ", "- ( ) ", "- (x) ", "- ", "* ", "> "] where body.hasPrefix(m) {
                marker = m.replacingOccurrences(of: "[x]", with: "[ ]").replacingOccurrences(of: "(x)", with: "( )")
                break
            }
            if marker == nil {
                let digits = body.prefix(while: \.isNumber)
                if !digits.isEmpty, body.dropFirst(digits.count).hasPrefix(". "), let n = Int(digits) { marker = "\(n + 1). " }
            }
            guard let marker else { return false }
            if body.trimmingCharacters(in: .whitespaces) == marker.trimmingCharacters(in: .whitespaces) || body.count <= marker.count && body.trimmingCharacters(in: .whitespaces).hasSuffix(marker.trimmingCharacters(in: .whitespaces)) {
                // Return on an empty item ends the list.
                textView.insertText("", replacementRange: NSRange(location: lineRange.location, length: caret - lineRange.location))
                return true
            }
            textView.insertText("\n" + indent + marker, replacementRange: textView.selectedRange())
            return true
        }
    }
}

/// The text view: keeps a centred column and adds shortcuts and the / menu.
final class PageTextView: NSTextView {
    var look = LookSettings()

    private var laidOutWidth: CGFloat = -1

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Only react to width changes. Height changes come from the text itself,
        // and adjusting margins then would loop the layout.
        if abs(newSize.width - laidOutWidth) > 0.5 {
            laidOutWidth = newSize.width
            DispatchQueue.main.async { [weak self] in self?.relayout() }
        }
    }

    func relayout() {
        let width = bounds.width
        let column = columnWidth(width, look)
        let inset = (max(32, (width - column) / 2)).rounded()
        let next = NSSize(width: inset, height: 72)
        if textContainerInset != next { textContainerInset = next }
    }

    override func becomeFirstResponder() -> Bool {
        defer { (delegate as? LiveEditor.Coordinator)?.restyle() }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        defer { DispatchQueue.main.async { (self.delegate as? LiveEditor.Coordinator)?.restyle() } }
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        switch (mods, key) {
        case ([.command], "b"): wrap("**"); return true
        case ([.command], "i"): wrap("*"); return true
        case ([.command], "u"): wrap("++"); return true
        case ([.command, .shift], "h"): wrap("=="); return true
        case ([.command, .shift], "g"): wrap("{{", "}}"); return true
        case ([.command, .shift], "x"): wrap("~~"); return true
        case ([.command, .shift], "c"): wrap("`"); return true
        default: return super.performKeyEquivalent(with: event)
        }
    }

    func wrap(_ open: String, _ close: String? = nil) {
        let close = close ?? open
        let range = selectedRange()
        let selected = (string as NSString).substring(with: range)
        insertText(open + selected + close, replacementRange: range)
        setSelectedRange(NSRange(location: range.location + (open as NSString).length, length: (selected as NSString).length))
    }

    // Typing / at the start of an empty line opens a menu of components.
    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        guard (string as? String) == "/" else { return }
        let ns = self.string as NSString
        let caret = selectedRange().location
        let line = ns.lineRange(for: NSRange(location: caret - 1, length: 0))
        let text = ns.substring(with: line).trimmingCharacters(in: .newlines)
        if text == "/" { showSlashMenu(replacing: NSRange(location: line.location, length: 1)) }
    }

    private struct SlashItem { var title: String; var symbol: String; var text: String; var select: Int? = nil; var length = 0 }

    private let slashItems: [SlashItem] = [
        .init(title: "Title", symbol: "textformat.size.larger", text: "# "),
        .init(title: "Section heading", symbol: "textformat.size", text: "## "),
        .init(title: "Sub-heading", symbol: "textformat.size.smaller", text: "### "),
        .init(title: "Bulleted list", symbol: "list.bullet", text: "- "),
        .init(title: "Numbered list", symbol: "list.number", text: "1. "),
        .init(title: "Checklist", symbol: "checklist", text: "- [ ] "),
        .init(title: "Quote", symbol: "text.quote", text: "> "),
        .init(title: "Flashcard", symbol: "rectangle.on.rectangle.angled", text: "Q: Question\nA: Answer", select: 3, length: 8),
        .init(title: "Definition", symbol: "character.book.closed", text: "Term :: What it means", select: 0, length: 4),
        .init(title: "Quiz", symbol: "checklist.checked", text: "? Question\n- ( ) Wrong answer\n- (x) Right answer\n- ( ) Wrong answer", select: 2, length: 8),
        .init(title: "Gap fill", symbol: "eye.slash", text: "{{answer}}", select: 2, length: 6),
        .init(title: "Callout: Tip", symbol: "lightbulb", text: "> [!tip] Tip\n> Write the key point here", select: 15, length: 24),
        .init(title: "Callout: Remember", symbol: "brain", text: "> [!remember] Remember\n> Write the key point here", select: 25, length: 24),
        .init(title: "Callout: Warning", symbol: "exclamationmark.triangle", text: "> [!warning] Watch out\n> Write the key point here", select: 25, length: 24),
        .init(title: "Toggle", symbol: "chevron.right.square", text: "+++ Click to expand\nHidden details\n+++", select: 4, length: 15),
        .init(title: "Table", symbol: "tablecells", text: "| Column | Column |\n|---|---|\n| Cell | Cell |", select: 2, length: 6),
        .init(title: "Code block", symbol: "chevron.left.forwardslash.chevron.right", text: "```\ncode\n```", select: 4, length: 4),
        .init(title: "Divider", symbol: "minus", text: "---\n"),
    ]

    private var slashRange = NSRange()

    private func showSlashMenu(replacing range: NSRange) {
        slashRange = range
        let menu = NSMenu()
        for (i, item) in slashItems.enumerated() {
            let mi = NSMenuItem(title: item.title, action: #selector(pickSlash(_:)), keyEquivalent: "")
            mi.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
            mi.tag = i
            mi.target = self
            menu.addItem(mi)
        }
        guard let rect = layoutManager.flatMap({ lm -> NSRect? in
            guard let tc = textContainer else { return nil }
            let glyphs = lm.glyphRange(forCharacterRange: NSRange(location: range.location, length: 1), actualCharacterRange: nil)
            return lm.boundingRect(forGlyphRange: glyphs, in: tc)
        }) else { return }
        let point = NSPoint(x: rect.minX + textContainerOrigin.x, y: rect.maxY + textContainerOrigin.y + 6)
        menu.popUp(positioning: nil, at: point, in: self)
    }

    @objc private func pickSlash(_ sender: NSMenuItem) {
        let item = slashItems[sender.tag]
        insertText(item.text, replacementRange: slashRange)
        if let s = item.select {
            setSelectedRange(NSRange(location: slashRange.location + s, length: item.length))
        }
    }
}

// MARK: - Styling

/// Applies the page's typography to Markdown source. Symbols are hidden (zero-width,
/// clear) everywhere except the line being edited, where they show faintly.
enum LiveStyler {
    static func bodyAttributes(_ look: LookSettings) -> [NSAttributedString.Key: Any] {
        [.font: look.body.nsFont(look.size), .foregroundColor: NSColor.white.withAlphaComponent(0.84), .paragraphStyle: paragraph(look)]
    }

    static func paragraph(_ look: LookSettings, spacingBefore: CGFloat = 0) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = look.size * (look.leading - 1.25)
        p.paragraphSpacing = look.size * 0.45
        p.paragraphSpacingBefore = spacingBefore
        return p
    }

    private static func rx(_ pattern: String) -> NSRegularExpression { try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) }

    private static let heading = rx(#"^(#{1,6} )(.*)$"#)
    private static let bold = rx(#"(\*\*|__)(?=\S)(.+?)(\1)"#)
    private static let italic = rx(#"(?<![\*\w])(\*|_)(?=\S)([^*_\n]+?)\1(?![\*\w])"#)
    private static let strike = rx(#"(~~)(.+?)(~~)"#)
    private static let mark = rx(#"(==)(.+?)(==)"#)
    private static let underline = rx(#"(\+\+)(?=\S)(.+?)(\+\+)"#)
    private static let caps = rx(#"(\^\^)(.+?)(\^\^)"#)
    private static let gap = rx(#"(\{\{)(.+?)(\}\})"#)
    private static let code = rx(#"(`)([^`\n]+)(`)"#)
    private static let color = rx(#"(\{(?:red|orange|yellow|green|mint|teal|blue|indigo|purple|pink|brown|gray|grey)\|)([^}\n]*)(\})"#)
    private static let link = rx(#"(\[)([^\]\n]+)(\]\([^)\n]+\))"#)
    private static let listMarker = rx(#"^\s*([-*+] (?:\[[ xX]\] |\([ xX]\) )?|\d+[.)] )"#)
    private static let checked = rx(#"^\s*[-*+] \[[xX]\] (.*)$"#)
    private static let quote = rx(#"^(> ?)(\[![A-Za-z]+\][+-]?)?(.*)$"#)
    private static let qa = rx(#"^([QqAa]:)"#)
    private static let quizQ = rx(#"^(\?{1,2} )(.*)$"#)
    private static let definition = rx(#"^(.+?)( :: )"#)
    private static let fence = rx(#"^```[^\n]*\n[\s\S]*?^```.*$"#)
    private static let toggle = rx(#"^\+\+\+.*$"#)
    private static let table = rx(#"^\|.*\|\s*$"#)
    private static let divider = rx(#"^\s*([-*_]\s*){3,}$"#)

    static func apply(to storage: NSTextStorage, look: LookSettings, activeLine: NSRange) {
        let text = storage.string
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let accent = NSColor(look.accentColor)
        let accentLight = NSColor(look.accentLight)
        let faint = NSColor.white.withAlphaComponent(0.32)
        let muted = NSColor.white.withAlphaComponent(0.6)
        let size = look.size
        let mono = NSFont.monospacedSystemFont(ofSize: size * 0.82, weight: .regular)

        storage.beginEditing()
        storage.setAttributes(bodyAttributes(look), range: full)

        /// Shows a symbol faintly on the line being edited, hides it everywhere else.
        func symbol(_ r: NSRange) {
            guard r.location != NSNotFound, r.length > 0 else { return }
            if NSIntersectionRange(r, activeLine).length > 0 || (activeLine.location != NSNotFound && NSLocationInRange(r.location, activeLine)) {
                storage.addAttribute(.foregroundColor, value: faint, range: r)
            } else {
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: r)
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 0.01), range: r)
            }
        }
        func each(_ re: NSRegularExpression, _ f: (NSTextCheckingResult) -> Void) { re.enumerateMatches(in: text, range: full) { m, _, _ in if let m { f(m) } } }
        func addFontTrait(_ r: NSRange, _ trait: NSFontTraitMask) {
            storage.enumerateAttribute(.font, in: r) { value, sub, _ in
                guard let f = value as? NSFont, f.pointSize > 1 else { return }
                storage.addAttribute(.font, value: NSFontManager.shared.convert(f, toHaveTrait: trait), range: sub)
            }
        }

        // Blocks
        each(heading) { m in
            let level = m.range(at: 1).length - 1
            let (scale, weight): (CGFloat, NSFont.Weight) = switch level {
            case 1: (3.0, .medium)
            case 2: (1.65, .medium)
            case 3: (1.25, .medium)
            default: (0.8, .semibold)
            }
            let p = paragraph(look, spacingBefore: level == 2 ? size * 1.6 : level == 1 ? 0 : size * 0.6) as! NSMutableParagraphStyle
            p.lineSpacing = 2
            storage.addAttributes([.font: look.head.nsFont(size * scale, weight), .foregroundColor: NSColor(Theme.text), .paragraphStyle: p, .kern: -size * scale * 0.022], range: m.range)
            symbol(m.range(at: 1))
        }
        each(quote) { m in
            storage.addAttribute(.foregroundColor, value: muted, range: m.range(at: 3))
            if m.range(at: 2).location != NSNotFound {
                storage.addAttributes([.foregroundColor: accent, .font: NSFont.systemFont(ofSize: size * 0.8, weight: .semibold)], range: m.range(at: 2))
            } else {
                addFontTrait(m.range(at: 3), .italicFontMask)
            }
            storage.addAttribute(.foregroundColor, value: accent, range: m.range(at: 1))
        }
        each(listMarker) { m in storage.addAttribute(.foregroundColor, value: accent.withAlphaComponent(0.8), range: m.range(at: 1)) }
        each(checked) { m in storage.addAttributes([.foregroundColor: faint, .strikethroughStyle: NSUnderlineStyle.single.rawValue], range: m.range(at: 1)) }
        each(qa) { m in storage.addAttributes([.foregroundColor: accent, .font: NSFont.systemFont(ofSize: size * 0.85, weight: .bold)], range: m.range(at: 1)) }
        each(quizQ) { m in
            storage.addAttribute(.foregroundColor, value: accent, range: m.range(at: 1))
            addFontTrait(m.range(at: 2), .boldFontMask)
        }
        each(definition) { m in
            addFontTrait(m.range(at: 1), .boldFontMask)
            storage.addAttribute(.foregroundColor, value: NSColor(Theme.text), range: m.range(at: 1))
            storage.addAttribute(.foregroundColor, value: accent, range: m.range(at: 2))
        }
        each(toggle) { m in storage.addAttribute(.foregroundColor, value: accent, range: m.range) }
        each(table) { m in storage.addAttributes([.font: mono, .foregroundColor: muted], range: m.range) }
        each(divider) { m in storage.addAttribute(.foregroundColor, value: faint, range: m.range) }

        // Inline
        each(bold) { m in addFontTrait(m.range(at: 2), .boldFontMask); storage.addAttribute(.foregroundColor, value: NSColor.white, range: m.range(at: 2)); symbol(m.range(at: 1)); symbol(m.range(at: 3)) }
        each(italic) { m in addFontTrait(m.range(at: 2), .italicFontMask); symbol(m.range(at: 1)); symbol(m.range(at: 3)) }
        each(strike) { m in storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: m.range(at: 2)); symbol(m.range(at: 1)); symbol(m.range(at: 3)) }
        each(mark) { m in storage.addAttributes([.backgroundColor: accent.withAlphaComponent(0.22), .foregroundColor: accentLight], range: m.range(at: 2)); symbol(m.range(at: 1)); symbol(m.range(at: 3)) }
        each(underline) { m in storage.addAttributes([.underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: accent], range: m.range(at: 2)); symbol(m.range(at: 1)); symbol(m.range(at: 3)) }
        each(caps) { m in storage.addAttributes([.foregroundColor: faint, .kern: 1.4, .font: NSFont.systemFont(ofSize: size * 0.8, weight: .medium)], range: m.range(at: 2)); symbol(m.range(at: 1)); symbol(m.range(at: 3)) }
        each(gap) { m in storage.addAttributes([.backgroundColor: accent.withAlphaComponent(0.2), .foregroundColor: accentLight], range: m.range(at: 2)); symbol(m.range(at: 1)); symbol(m.range(at: 3)) }
        each(color) { m in
            let name = ns.substring(with: m.range(at: 1)).dropFirst().dropLast().lowercased()
            if let c = Inline.palette[name] { storage.addAttribute(.foregroundColor, value: NSColor(c), range: m.range(at: 2)) }
            symbol(m.range(at: 1)); symbol(m.range(at: 3))
        }
        each(link) { m in
            storage.addAttributes([.foregroundColor: NSColor(Theme.text), .underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: NSColor.white.withAlphaComponent(0.35)], range: m.range(at: 2))
            symbol(m.range(at: 1)); symbol(m.range(at: 3))
        }
        each(code) { m in
            storage.addAttributes([.font: mono, .backgroundColor: NSColor.white.withAlphaComponent(0.08), .foregroundColor: NSColor.white.withAlphaComponent(0.9)], range: m.range(at: 2))
            symbol(m.range(at: 1)); symbol(m.range(at: 3))
        }
        // Code blocks last, so nothing inside them gets styled as Markdown.
        each(fence) { m in
            storage.setAttributes([.font: mono, .foregroundColor: NSColor(white: 0.82, alpha: 1), .paragraphStyle: paragraph(look)], range: m.range)
        }
        storage.endEditing()
    }
}
