# Renote (native Swift)

A minimalist Mac notes app that makes revision more fun, written in SwiftUI and AppKit. It's the native rewrite of the web-based Renote (branch `web`), using the same notes, settings and revision log.

- **Notes are plain Markdown** in `~/Documents/Renote`. Sub-folders are subjects.
- **Frosted window**: the desktop shows through, blurred, under your chosen window colour and opacity (Aa → Window). The full-height sidebar has a heavier frost.
- **View / Edit** switch in the bottom-right corner (⌘E). View is an article-style page: title, intro, numbered sections, flashcards that flip, quizzes, gaps you click to reveal, checklists you can tick. Double-click anything to jump into Edit there.
- **Edit** is a native live-Markdown editor: formatting appears as you type and the symbols disappear on every line except the one you're on. Type `/` on an empty line for headings, lists, flashcards, quizzes, callouts, toggles, tables and code. ⌘B ⌘I ⌘U ⇧⌘H (highlight) ⇧⌘G (gap) ⇧⌘X (strike) ⇧⌘C (code).
- **Aa**: heading and body fonts, size, width (up to full), spacing, accent, window colour and opacity. Saved to `.renote/settings.json`.
- **Revise** (⌘3): every flashcard, definition, quiz and gap becomes a shuffled deck. Sessions are logged to `.renote/log.json` and shown on **Progress**.

## Build

Needs Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen
xcodebuild -project Renote.xcodeproj -scheme Renote -configuration Release -derivedDataPath build build
ditto build/Build/Products/Release/Renote.app "/Applications/Renote (Swift).app"
```

The bundle id is `com.eriskelmendi.renote.native`, so it can sit next to the web-based app while it's being tried.
