# DeToca

A modern Gopher client for **Mac OS X 10.6 Snow Leopard** (MacBook2,1 /
Xcode 3.2.6 / GCC 4.2 / 10.6 SDK). The desktop sibling of DeBurrow (Android),
built for the debene gopherspace (`gopher.debene.dev:70`) and the wider Gopher
world. Bundle id: `dev.debene.detoca`.

Toca = burrow. Same family as DeBurrow.

## Why

The 10.6 Gopher ecosystem is effectively empty — TurboGopher is Classic-only,
and newer clients require newer macOS. DeToca fills that gap: RFC 1436 browsing,
multi-window navigation, and — the headline feature — correctly-aligned braille
maps with 256-color ANSI (the gopher-cta live CTA 'L' train maps).

## Building

Everything is plain `.h`/`.m` plus a Makefile. **No Xcode project, no NIBs** —
the whole UI is built in code, so the project reviews as plain diffs.

```sh
make            # build DeToca.app
make run        # build and launch
make test       # build & run the OCUnit (SenTestingKit) parser tests
make spikeb     # build the Spike B command-line fetch tool
make clean
```

The build targets i386 against the 10.6 SDK with `-mmacosx-version-min=10.6`
and compiles clean under `-Wall` (zero warnings). Override `ARCH`, `CC`, or
`SDK` on the command line if needed.

Requirements on the target: Xcode 3.2.6 (for GCC 4.2, the 10.6 SDK, and
`otest` + SenTestingKit under `/Developer`).

## Manual-memory / period-correct constraints

This is a **non-ARC** codebase using classic manual retain/release. It avoids
all modern Objective-C syntax (no `@[]`/`@{}`/`@42`/subscripting), uses explicit
`@synthesize` for every property, and builds with GCC 4.2 / LLVM-GCC. Blocks and
GCD are used sparingly and isolated (see below).

## Architecture

Two layers, cleanly separated:

**Parser layer — pure Foundation, no AppKit, unit-tested** (`make test`):

| Class | Responsibility |
|-------|----------------|
| `GopherItem` | One parsed gophermap line; type → kind + clickability. |
| `GopherMenuParser` | Menu text → `GopherItem[]`. CRLF/LF tolerant, `.`-terminated. |
| `GopherResource` | A resolvable location; parses `gopher://` URLs and bare `host/selector`. |
| `ANSIPalette` | The xterm 256-color palette (16 base + 6×6×6 cube + 24 gray). |
| `ANSISpan` | A styled run of text (RGB stored as bytes — no NSColor). |
| `ANSIParser` | SGR state machine → `ANSISpan[]`. |

**Networking:**

| Class | Responsibility |
|-------|----------------|
| `GopherRequest` | One RFC 1436 transaction on a background queue; main-thread delegate callbacks; 10s connect / 30s read timeouts; cancellable. BSD sockets (10.5-clean). |
| `DTDispatch` | The single wrapper around libdispatch (GCD). *10.6-only*, isolated so the fio-3 10.5 build can swap in an NSThread/NSOperationQueue path. |

**Player (fio 2) — the "radinho":**

| Class | Responsibility |
|-------|----------------|
| `StreamRouting` | Classifies a URL string as an in-app MP3 stream (pure Foundation, unit-tested). |
| `PlayQueueItem` / `PlayQueue` | Gopher-agnostic queue model: ordered (title, URL) items with a current index and next/prev/replace (pure Foundation, unit-tested). |
| `StreamPlayerController` | Singleton dark HUD `NSPanel` playing a `PlayQueue` with QTKit; auto-advance, dead-stream skip, persisted volume. Never imports the parser. |

**AppKit UI:**

| Class | Responsibility |
|-------|----------------|
| `AppDelegate` | Navigation hub; programmatic menu bar; the one `h`/`URL:` dispatch point. |
| `GopherWindowController` | One window per resource: menu (table) or text (ANSI) mode. |
| `AttributedStringRenderer` | `ANSISpan[]` → `NSAttributedString` (the AppKit half of the ANSI pipeline). |
| `GopherTableView` | Table subclass: Return/Enter activates a row. |
| `DTFontManager` | Registers bundled Cascadia Code; vends the document font. |
| `BookmarkStore` | Bookmarks as a hand-editable gophermap. |
| `PreferencesController` | Shows the resolved document font (diagnoses misalignment). |
| `DTInputSheet` | One-field input sheet (search / Open Location). |

## Design decisions

**One dark terminal theme everywhere.** Both menus and documents render on a
black background with light text. The gopher-cta maps are authored for a dark
terminal (their river/expressway colors are unreadable on white), and a gopher
"menu" is often really preformatted content — the askthedeck dcgi returns a
reading as info lines — so a single dark, monospaced surface keeps a page
looking identical whether it arrives as a type-0 document or a type-1 menu.
Explicit ANSI colors layer on top of the light default; unset text is light
grey; info/unknown/error rows are dimmed/tinted for the dark background.

**Menus render in an `NSTableView`, not an `NSTextView`.** The spec left this to
the implementer. A table gives first-class row selection, keyboard navigation
(arrow keys + Return via `GopherTableView`), per-row hit-testing, and trivially
inert info/error/unknown rows (`-tableView:shouldSelectRow:`) — all of which
would be fiddly to reproduce with link attributes in a text view. Rows use the
monospaced document font with zero intercell spacing (plus a few px so
descenders aren't clipped) so ASCII-art info lines — boxes, rules, the dcgi
tarot cards — align and their borders connect vertically. Type tags are
period-correct bracketed ASCII (`[DIR] [TXT] [FND] [WWW] [ERR] [ ? ]`), not
emoji, dimmed by kind.

**Text/ANSI documents** never wrap — the text container is unbounded and the
user scrolls horizontally for preformatted maps.

**Braille alignment (Spike A).** No stock 10.6 font carries the U+2800–U+28FF
braille block with correct advance width; Apple Symbols misaligns (10 vs 8 pt).
**Cascadia Code** (static TTF v2404.023) was the tested winner. It is bundled in
`Resources/`, registered at launch via `CTFontManagerRegisterFontsForURL`
(process scope, *10.6-only*), and is the default document font. The resolved
font name is shown in Preferences so misalignment is diagnosable. (DejaVu Sans
Mono does *not* carry the braille block — do not fall back to it.)

**The `ANSIParser` gets `38;5;n` right** — the fbterm "case 38" bug (swallowing
the parameters after a 256-color intro) is explicitly guarded and regression-
tested (`testCase38DoesNotSwallowFollowingParams`).

**fio-3 (10.5 / PowerPC) seams** are marked with `// 10.6-only:` comments and
kept small: GCD lives only behind `DTDispatch`; font registration is one call.

## Navigation model

TurboGopher-style: every menu link opens a **new window**, cascaded from its
parent. No back/forward — the window trail *is* the history. Cmd-W closes; the
Window menu lists open windows. Each window's title is the item's display
string; the status bar shows `host:port/selector`.

Shortcuts: **Cmd-Shift-H** Home (`gopher.debene.dev`), **Cmd-L** Open Location,
**Cmd-D** Add Bookmark, **Cmd-,** Preferences.

You can also launch straight to a location:

```sh
open DeToca.app --args gopher://gopher.debene.dev/0/map.ansi
```

## Streams — the radinho (fio 2)

gopher-spot serves menu items (`h`/`URL:`) pointing at HTTP MP3 streams. Clicking
one opens the **radinho**: a single global floating panel that plays in-app via
QTKit. The queue is built from **all** playable stream items in that menu, in
order, starting at the clicked item; auto-advance moves through them, and end of
queue parks on the last track. The panel is independent of browser windows —
**playback survives closing every menu window** and stops only when the panel is
closed or the app quits. A dead stream is skipped forward without an alert storm.

- **Routing** lives in the single fio-1 seam `-openExternalURLString:`: an
  http(s) URL whose path ends in `.mp3` plays in-app; everything else keeps the
  fio-1 external-handoff behavior.
- **Option-click always forces external open**, even for MP3 links (escape hatch).
- **Playback menu**: Play/Pause `⌥⌘P`, Previous `⌥⌘←`, Next `⌥⌘→` (global), plus
  Show Radinho. Space toggles play/pause only while the panel is key.
- **File ▸ Export Menu as Playlist…** writes the frontmost menu's stream items as
  Extended M3U (`#EXTM3U` / `#EXTINF:-1,<title>`) for use in an external player.
- Volume persists across relaunches (`NSUserDefaults`).

## Bookmarks

Stored as a plain-text gophermap at
`~/Library/Application Support/DeToca/bookmarks.gophermap` and rendered through
the ordinary menu path. Hand-editable — it's just a gophermap.

## Scope (fio 1)

**In:** protocol core; item types 0/1/7/i/h/3 + unknown; multi-window nav; menu
& text rendering; ANSI + 256-color + braille; bookmarks; Home; Open Location.

**Out (later fios):** in-app QTKit stream player (fio 2 — swaps in at
`-openExternalURLString:`); universal ppc/i386 10.5 build (fio 3); images,
binary downloads, Gopher+, caching, TLS, tabs.

## Icon (fio 4)

`Resources/DeToca.icns` — a dark rounded tile with an amber CRT "scope" showing a
pixel-art gopher wearing headphones (browser + radinho in one glyph). Chosen from
two candidates in `design/` for legibility at Dock/Finder sizes; the amber
line-art reads more clearly when shrunk than the green matrix alternative
(`design/icon-green-matrix.png`). The tile was cropped from the source render and
its corners masked to transparency (`design/icon-amber-gopher-tile.png`), then
built into a multi-size `.icns` and referenced via `CFBundleIconFile`. To rebuild
from a different source, regenerate the `.iconset` and run `iconutil -c icns`.

## Font license

Cascadia Code is bundled under the SIL Open Font License 1.1
(`Resources/OFL.txt`).
