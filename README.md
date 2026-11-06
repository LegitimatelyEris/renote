# Renote

A minimalist macOS notes app that makes revision more fun. Notes are plain Markdown files (in `~/Documents/Renote` by default), and every note has three modes:

- **Write** (⌘1): a calm, centred Markdown editor with light syntax colouring, list continuation, and Format / Insert menus.
- **Read** (⌘2): your note as a typographic page with numbered sections, flippable flashcards, quizzes, callouts and tickable checklists.
- **Revise** (⌘3): every flashcard, definition, quiz and gap in the note becomes a shuffled card deck. Space flips, → means "got it", ← means "again", and missed cards come back in another round.

## Syntax

| Write | Get |
|---|---|
| `**bold**` `*italic*` `~~strike~~` `` `code` `` | the usual |
| `==text==` | highlight |
| `++text++` | underline |
| `^^text^^` | small caps |
| `{red\|text}` | coloured text (red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown, gray) |
| `{{text}}` | a gap to fill (hidden in Read mode until clicked) |
| `Q: …` then `A: …` | flashcard |
| `Term :: meaning` | definition card |
| `? Question` then `- ( ) wrong` / `- (x) right` | quiz |
| `> [!tip] Title` | callout (note, tip, info, important, warning, danger, example, question, summary, remember) |
| `+++ Title` … `+++` | toggle |
| `- [ ] task` | checklist |

Plus headings, lists, quotes, tables, code blocks, images and dividers.

## Building

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen
open Renote.xcodeproj
```
