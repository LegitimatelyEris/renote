enum SampleNotes {
    static let welcome = #"""
# Welcome to Renote

Renote is plain **Markdown** with a few extras that make revision more fun. Write in *Write* mode, read it beautifully in *Read* mode, and test yourself in *Revise* mode.

## Text formatting

You can write **bold**, *italic*, ~~struck out~~, `inline code`, ==highlighted==, ++underlined++ and ^^small caps^^ text. Colour words with {red|red}, {blue|blue}, {green|green} or {purple|purple}, and add [links](https://www.markdownguide.org).

Hide answers inside a sentence with a gap: the capital of France is {{Paris}}. In Read mode, click the paragraph to reveal it.

## Components

> [!tip] Callouts
> Start a quote with `[!tip]`, `[!note]`, `[!warning]`, `[!important]`, `[!example]`, `[!question]`, `[!summary]` or `[!remember]`.

Q: What does a flashcard look like?
A: A line starting with `Q:` followed by a line starting with `A:`. Click it to flip.

Mitochondria :: The organelle where aerobic respiration happens.

? Which mode turns your notes into a card deck?
- ( ) Write
- ( ) Read
- (x) Revise

+++ Click to expand a toggle
Toggles hide extra detail until you need it. Start with `+++ Title` and finish with `+++`.
+++

## Lists and tables

- [x] Tick checklist items right in Read mode
- [ ] Try the **+** menu in Write mode to insert components
- [ ] Press ⌘1, ⌘2 and ⌘3 to switch modes

| Syntax | Becomes |
|---|---|
| `==text==` | Highlight |
| `{{text}}` | Fill the gap |
| `Term :: meaning` | Definition card |

---

```swift
print("Code blocks work too")
```
"""#

    static let biology = #"""
# Cell Biology

^^Topic 2 · Revision notes^^

## The cell membrane

The membrane is a {{phospholipid bilayer}} with proteins embedded in it. It is ==partially permeable==, so only some substances can cross it.

Diffusion :: The net movement of particles from an area of higher concentration to an area of lower concentration.
Osmosis :: The diffusion of water across a partially permeable membrane.
Active transport :: Movement against a concentration gradient, using energy from respiration.

> [!remember] Exam tip
> Always say **net** movement when you define diffusion.

## Organelles

| Organelle | Job |
|---|---|
| Nucleus | Holds genetic material |
| Mitochondria | Aerobic respiration |
| Ribosome | Protein synthesis |
| Chloroplast | Photosynthesis (plants only) |

Q: Why do muscle cells contain lots of mitochondria?
A: They need lots of energy, which is released by aerobic respiration in the mitochondria.

Q: Which organelle is found in plant cells but not animal cells?
A: The chloroplast (also the cell wall and permanent vacuole).

? Where is protein made?
- ( ) Nucleus
- (x) Ribosome
- ( ) Cell membrane

## Checklist

- [x] Learn the organelles
- [ ] Practise the osmosis required practical
- [ ] Past paper question 4
"""#
}
