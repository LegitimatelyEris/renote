import AppKit
import WebKit

/// Renote for Mac: a native window around the Renote website. The site is bundled
/// in the app and talks to `NotesAPI` through the `renote://` scheme, so no server
/// or Node install is needed. Notes stay as Markdown files in ~/Documents/Renote.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var web: RenoteWebView!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        web = RenoteWebView()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Renote"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 820, height: 560)
        window.contentView = web
        window.setFrameAutosaveName("RenoteMain")
        if !window.setFrameUsingName("RenoteMain") { window.center() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        web.start()
        #if DEBUG
        DebugSnapshot.runIfRequested(web)
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: Menu

    private func buildMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Renote", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Renote", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Renote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(appMenu, title: "Renote", to: main)

        let file = NSMenu(title: "File")
        file.addItem(item("New Note", "n", #selector(newNote)))
        file.addItem(item("New Subject…", "n", #selector(newSubject), [.command, .shift]))
        file.addItem(.separator())
        file.addItem(item("Search Notes", "f", #selector(search)))
        file.addItem(item("Show Notes Folder in Finder", "r", #selector(showFolder), [.command, .shift]))
        file.addItem(.separator())
        file.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        add(file, title: "File", to: main)

        // Standard Edit menu, so copy, paste and undo work inside the page.
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        add(edit, title: "Edit", to: main)

        let view = NSMenu(title: "View")
        view.addItem(item("Toggle View / Edit", "e", #selector(toggleEdit)))
        view.addItem(item("View", "1", #selector(modeRead)))
        view.addItem(item("Edit", "2", #selector(modeWrite)))
        view.addItem(item("Revise", "3", #selector(modeRevise)))
        view.addItem(.separator())
        view.addItem(item("Fonts and Layout…", "t", #selector(showType)))
        view.addItem(item("Toggle Sidebar", "\\", #selector(toggleSidebar)))
        view.addItem(.separator())
        view.addItem(item("All Notes", "0", #selector(home)))
        view.addItem(item("Progress", "p", #selector(progress), [.command, .shift]))
        view.addItem(.separator())
        view.addItem(item("Reload", "r", #selector(reload)))
        let full = view.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        full.keyEquivalentModifierMask = [.command, .control]
        add(view, title: "View", to: main)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        add(windowMenu, title: "Window", to: main)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }

    private func add(_ menu: NSMenu, title: String, to main: NSMenu) {
        let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        holder.submenu = menu
        main.addItem(holder)
    }

    private func item(_ title: String, _ key: String, _ action: Selector, _ mods: NSEvent.ModifierFlags = [.command]) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.keyEquivalentModifierMask = mods
        i.target = self
        return i
    }

    // MARK: Actions (forwarded to the page)

    @objc private func newNote() { web.call("newNote()") }
    @objc private func newSubject() { web.call("newSubject()") }
    @objc private func search() { web.call("focusSearch()") }
    @objc private func modeRead() { web.call("setMode('read')") }
    @objc private func modeWrite() { web.call("setMode('edit')") }
    @objc private func toggleEdit() { web.call("toggleEdit()") }
    @objc private func showType() { web.call("showType()") }
    @objc private func toggleSidebar() { web.call("toggleSidebar()") }
    @objc private func modeRevise() { web.call("setMode('revise')") }
    @objc private func home() { web.call("go('#/')") }
    @objc private func progress() { web.call("go('#/progress')") }
    @objc private func reload() { web.reload() }
    @objc private func showFolder() { NSWorkspace.shared.open(NotesAPI.shared.root) }
}
