import AppKit
import WebKit

/// The page host. Serves the bundled site over `renote://app/`, lets the top bar
/// drag the window like a title bar, and gives the page native dialogs and links.
final class RenoteWebView: WKWebView, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    /// Areas of the top bar that are buttons or fields, reported by the page.
    private var noDragRects: [CGRect] = []
    private var barHeight: CGFloat = 56

    init() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(SchemeHandler(), forURLScheme: "renote")
        let controller = WKUserContentController()
        // Tell the page it is inside the Mac app before any of its own scripts run.
        controller.addUserScript(WKUserScript(
            source: "document.documentElement.classList.add('native'); window.renoteNative = true;",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController = controller
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        super.init(frame: .zero, configuration: config)
        controller.add(WeakHandler(self), name: "renote")
        navigationDelegate = self
        uiDelegate = self
        setValue(false, forKey: "drawsBackground")
        allowsBackForwardNavigationGestures = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func start() {
        load(URLRequest(url: URL(string: "renote://app/")!))
    }

    func call(_ js: String) {
        evaluateJavaScript("window.renote && window.renote.\(js)")
    }

    // MARK: Window dragging from the page's top bar

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let y = isFlipped ? p.y : bounds.height - p.y
        let onBar = y < barHeight && !noDragRects.contains { $0.contains(CGPoint(x: p.x, y: y)) }
        if onBar, let window {
            if event.clickCount == 2 { window.performZoom(nil) } else { window.performDrag(with: event) }
            return
        }
        super.mouseDown(with: event)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        if let rects = body["noDrag"] as? [[String: Double]] {
            noDragRects = rects.map { CGRect(x: $0["x"] ?? 0, y: $0["y"] ?? 0, width: $0["w"] ?? 0, height: $0["h"] ?? 0) }
            barHeight = body["bar"] as? Double ?? 56
        }
        if let settings = body["window"] as? [String: Any], let window {
            // The page sends its blur setting whenever the Look panel changes.
            WindowBlur.set(window, radius: (settings["blur"] as? NSNumber)?.intValue ?? 30)
        }
        if let text = body["copy"] as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    // MARK: Links open in the browser

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if let url = action.request.url, url.scheme != "renote", url.scheme != "about" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    // MARK: Native alert, confirm and prompt for the page

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.beginSheetModal(for: window!) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window!) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window!) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
    }
}

/// Avoids a retain cycle between the content controller and the web view.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}
