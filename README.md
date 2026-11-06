# Renote

A minimalist notes website that runs on your Mac and makes revision more fun. The look is adapted from [tryprofound.com](https://www.tryprofound.com): a black canvas, hairline grid cells, Inter with tight tracking, white buttons and an orange accent.

Notes are plain Markdown files in `~/Documents/Renote`. Sub-folders are **subjects**. Nothing leaves your computer.

## Run it

Needs Node 20 or newer. There are no dependencies to install.

```bash
npm start
```

Then open http://localhost:4321.

Use `RENOTE_DIR=/some/folder npm start` to keep notes somewhere else, or `PORT=5000 npm start` for another port.

## What's in it

- **Read**: each `##` section becomes a row of the grid, with the heading on the left and the content on the right. Flashcards flip, quizzes mark themselves, gaps reveal on click and checklists tick (and save).
- **Write**: Markdown on the left, live preview on the right, plus chips for formatting and components. Saves as you type.
- **Revise**: every flashcard, definition, quiz and gap in the note becomes a shuffled deck. Space flips, → means got it, ← means again.
- **Progress**: every finished Revise session is logged to `.renote/log.json` in your notes folder, giving sessions, accuracy, a day streak and mastery per note. The banner at the top tells you what hasn't been revised this week.
- **Add box**: at the bottom of every note, add text, a flashcard, a definition, a to-do, a gap or a section without leaving Read mode.

Shortcuts: `/` search, `n` new note, `1` `2` `3` switch Read, Write and Revise, `⌘B` `⌘I` `⌘⇧H` `⌘⇧G` in the editor.

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
