import SwiftUI

@main
struct RenoteApp: App {
    @State private var store = NoteStore()
    @State private var editor = EditorController()
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("Renote", id: "main") {
            ContentView(store: store, editor: editor)
                .frame(minWidth: 760, minHeight: 520)
                .onAppear {
                    delegate.store = store
                    #if DEBUG
                    DebugSnapshot.runIfRequested(store: store)
                    #endif
                }
        }
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") { store.newNote() }.keyboardShortcut("n")
            }
            CommandGroup(after: .saveItem) {
                Button("Save") { store.saveNow() }.keyboardShortcut("s")
                Divider()
                Button("Show in Finder") { store.revealInFinder() }.keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Choose Notes Folder…") { store.chooseFolder() }
            }
            CommandMenu("Note") {
                ForEach(Array(NoteMode.allCases.enumerated()), id: \.element) { i, mode in
                    Button(mode.label) { store.mode = mode }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")))
                }
                Button("Toggle Write / Read") { store.mode = store.mode == .write ? .read : .write }
                    .keyboardShortcut("e")
            }
            CommandMenu("Format") {
                FormatMenu(editor: editor, shortcuts: true)
                    .disabled(store.mode != .write)
            }
            CommandMenu("Insert") {
                InsertMenu(editor: editor)
                    .disabled(store.mode != .write)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: NoteStore?
    func applicationWillTerminate(_ notification: Notification) { store?.saveNow() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
