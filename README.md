# Renote

A minimalist notes website that runs on your Mac and makes revision more fun. The look is adapted from [tryprofound.com](https://www.tryprofound.com): a black canvas, hairline grid cells, Inter with tight tracking, white buttons and an orange accent.

Notes are plain Markdown files in `~/Documents/Renote`. Sub-folders are **subjects**. Nothing leaves your computer.

## Mac app

`macos/` wraps the site in a native window. The site is bundled inside the app and the app reads and writes your notes itself, so there's no server and no Node needed. The top bar doubles as the title bar, and the menus have New Note (⌘N), Search (⌘F), Read, Write and Revise (⌘1 ⌘2 ⌘3) and Progress (⌘⇧P).

Build it with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
cd macos
xcodegen
xcodebuild -project Renote.xcodeproj -scheme Renote -configuration Release -derivedDataPath build build
ditto build/Build/Products/Release/Renote.app /Applications/Renote.app
```

## Run it in a browser instead

Needs Node 20 or newer. There are no dependencies to install.

```bash
npm start
```

Then open http://localhost:4321.

Use `RENOTE_DIR=/some/folder npm start` to keep notes somewhere else, or `PORT=5000 npm start` for another port.

## What's in it

- **A page, not a box**: each note is one blog-style page (title, lede, numbered sections). Flip the **View / Edit** switch in the bottom-right corner (or press ⌘E) and click any part of the page to edit it right there, in the page's own type. Enter starts a new block, Backspace at the start joins it to the one above, ↑/↓ move between blocks, and typing `/` in an empty block opens a menu of components. A small bar above the block you're editing does bold, italic, highlight, gaps and colours.
- **Your type**: the **Aa** button sets the heading font and body font separately (Inter, Geist, Space Grotesk, Atkinson Hyperlegible, Newsreader, Literata, Fraunces, Instrument Serif, JetBrains Mono, IBM Plex Mono, Caveat), plus size, page width, line spacing and the accent colour. Saved to `.renote/settings.json`.
- **View**: flashcards flip, quizzes mark themselves, gaps reveal on click and checklists tick (and save). The ⋯ menu has Edit as Markdown, Rename, Trash and Hide sidebar (⌘\\).
- **Revise**: every flashcard, definition, quiz and gap in the note becomes a shuffled deck. Space flips, → means got it, ← means again.
- **Progress**: every finished Revise session is logged to `.renote/log.json` in your notes folder, giving sessions, accuracy, a day streak and mastery per note. The banner at the top tells you what hasn't been revised this week.

Shortcuts: `⌘E` view/edit, `/` search, `n` new note, `1` `2` `3` view, edit, revise, `⌘\\` hide sidebar, and `⌘B` `⌘I` `⌘U` `⌘⇧H` `⌘⇧G` while editing.

Deleted notes go to `.renote/trash` inside your notes folder, so nothing is lost.

## Syntax

| Write | Get |
|---|---|
| `**bold**` `*italic*` `~~strike~~` `` `code` `` | the usual |
| `==text==` | highlight |
| `++text++` | underline |
| `^^text^^` | small caps |
| `{red\|text}` | coloured text (red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown, gray) |
| `{{text}}` | a gap to fill, hidden until clicked |
| `Q: …` then `A: …` | flashcard |
| `Term :: meaning` | definition |
| `? Question` then `- ( ) wrong` / `- (x) right` | quiz |
| `> [!tip] Title` | callout (note, tip, info, important, warning, danger, example, question, summary, remember) |
| `+++ Title` … `+++` | toggle |
| `- [ ] task` | checklist |

Plus headings, lists, quotes, tables, code blocks, images and dividers.
