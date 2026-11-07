import AppKit
import SwiftUI

@main
struct RenoteApp: App {
    @State private var store = NoteStore()
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("Renote", id: "main") {
            RootView(store: store)
                .frame(minWidth: 960, minHeight: 600)
                .background(WindowConfigurator(store: store))
                .onAppear { delegate.store = store }
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 860)
        .commands { RenoteCommands(store: store) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: NoteStore?
    func applicationWillTerminate(_ notification: Notification) { store?.saveNow() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct RenoteCommands: Commands {
    var store: NoteStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") { store.newNote(in: store.currentNote?.subject) }.keyboardShortcut("n")
        }
        CommandGroup(after: .saveItem) {
            Button("Save") { store.saveNow() }.keyboardShortcut("s")
            Button("Show in Finder") { store.revealInFinder() }.keyboardShortcut("r", modifiers: [.command, .shift])
        }
        CommandMenu("Note") {
            Button("Toggle View / Edit") {
                guard store.screen == .note else { return }
                store.mode = store.mode == .edit ? .view : .edit
            }
            .keyboardShortcut("e")
            Button("View") { if store.screen == .note { store.mode = .view } }.keyboardShortcut("1")
            Button("Edit") { if store.screen == .note { store.mode = .edit } }.keyboardShortcut("2")
            Button("Revise") { if store.screen == .note { store.mode = .revise } }.keyboardShortcut("3")
            Divider()
            Button("All Notes") { store.screen = .home(subject: nil) }.keyboardShortcut("0")
            Button("Progress") { store.screen = .progress }.keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Toggle Sidebar") { withAnimation(.snappy) { store.sidebarHidden.toggle() } }.keyboardShortcut("\\")
        }
    }
}

/// Makes the window see-through and blurs the desktop behind it, like Terminal.
/// The page then paints the chosen colour at the chosen opacity on top.
struct WindowConfigurator: NSViewRepresentable {
    var store: NoteStore

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = false
            window.appearance = NSAppearance(named: .darkAqua)
            WindowBlur.prepare(window)
            WindowBlur.set(window, radius: 30)
            #if DEBUG
            DebugFloat.run(window: window, store: store)
            #endif
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// A native frosted material, used for the sidebar's heavier frost.
struct Frost: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}
