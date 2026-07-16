# Inkworm

An ePub reader, written in Flutter, that supports pagination. Built to support Paladin, but will work on any desktop.

## Features

- **Paginated reading** — books are laid out as fixed pages rather than a continuous scroll, like a physical e-reader. Tap the left/right edge of the screen to turn pages; tap the middle to open Settings.
- **Footnotes** - footnotes appear on the page that they reference as with normal books.
- **Chapter and other links** — tapping a table-of-contents entry, cross-reference, or footnote marker jumps straight to the target location.
- **Text selection, dictionary lookup, and sharing** — long-press a word to select it, drag the handles to extend the selection, then use the floating menu to look the word/phrase up in Wiktionary or share it to another app.
- **Resume where you left off** — the current book, chapter, page, and font size are saved locally and restored the next time you open the app.
- **Adjustable font size** — pick a reading size from Settings, optionally set it as the default for future books.
- **Table and drop-caps support** — HTML tables are laid out with per-column widths, and decorative drop-cap first letters are rendered correctly.
- **Open ePubs from other apps** — files can be opened directly or shared in from another app (e.g. a browser or file manager) via the OS "Open with"/share intent.
- **In-app update checks** — the app checks for and can install newer builds (an archive manifest on desktop, GitHub releases on Android).

