# DeToca — Testing

## Automated (parser layer)

```sh
make test
```

Runs the OCUnit / SenTestingKit suite (`tests/ParserTests.m`) against the
pure-Foundation parser layer: 30 tests covering gophermap parsing, the ANSI/SGR
state machine (including the fbterm `38;5;n` "case 38" hazard), the 256-color
palette, and `gopher://` / location parsing. Must pass on both the Studio and
the 10.6 target.

> Note: on 10.6 SenTestingKit lives under `/Developer`, and `otest` must be run
> `arch -arch i386` with `OBJC_DISABLE_GC=YES` — the Makefile handles both.

## Spike B (networking)

```sh
make spikeb
./spikeb                                   # gopher.debene.dev root
./spikeb gopher.debene.dev 70 /map.ansi    # a gopher-cta map selector
```

Prints the raw response to stdout and a parsed summary to stderr. Confirms the
BSD-socket path (resolve → connect → send → read-to-EOF, with timeouts) against
the live server before any UI is involved.

## Manual checklist

Launch with `make run` (opens the Home window on `gopher.debene.dev`).

- [ ] **Home** — `gopher.debene.dev:70` root: menu, info lines inline, type tags.
- [ ] **Floodgap** — Open Location `gopher://gopher.floodgap.com/1/`; browse a
      few menus and open a text file.
- [ ] **Veronica-2 search** — a type-7 item prompts (Cmd-driven sheet); results
      render as a menu.
- [ ] **gopher-cta braille map** — open `→ colour (ANSI): map`
      (`gopher://gopher.debene.dev/0/map.ansi`): braille **aligned**, 256-color
      correct (train dots, cyan lake), readable on the dark background.
- [ ] **gopher-blog phlog post** — a plain type-0 document renders legibly.
- [ ] **gopher-askthedeck** — a dcgi endpoint returns and renders.
- [ ] **gopher-spot stream link** — an `h`/`URL:` item opens in the external
      default handler (QuickTime Player / browser), not in DeToca.
- [ ] **Bookmarks round-trip** — Cmd-D on a window appends a line to
      `~/Library/Application Support/DeToca/bookmarks.gophermap`; Bookmarks →
      Show Bookmarks renders it; the appended item opens correctly.
- [ ] **Unknown / error rows** — unknown types render dimmed and inert; type-3
      renders as an error row.
- [ ] **Errors as sheets** — an unreachable host / bad port surfaces an alert
      **sheet** on the requesting window; never a crash.
- [ ] **Cascaded windows** — open 20+ menu links; windows cascade; Cmd-W closes;
      the Window menu lists them. Run once under `MallocStackLogging` to confirm
      no leaks when closing many windows.
- [ ] **Preferences** — Cmd-, shows the resolved document font (should read
      "Cascadia Code 12.0"); changing it via the font panel persists.

## Verified on hardware (this fio)

Built and run on the actual target (Mac OS X 10.6.8, MacBook2,1, i386,
Xcode 3.2.6), driven over SSH with `screencapture`:

- `make test` — 30/30 OCUnit tests pass, zero warnings.
- `make` — `DeToca.app` builds clean under `-Wall` (zero warnings).
- Home menu (`gopher.debene.dev`), Floodgap menu, and the gopher-cta ANSI
  braille map all render correctly; the map is **aligned with correct
  256-color** output on the dark background.
- Bookmarks seed file is created as a valid, hand-editable gophermap.
