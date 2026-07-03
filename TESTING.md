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

### Radinho / streams (fio 2)

- [ ] **gopher-spot click-to-play** — click a stream item; the radinho opens and
      plays; the queue is built from all stream items in that menu.
- [ ] **Auto-advance** — let 3+ tracks play; each advances to the next at end;
      the queue position ("2 / 3") updates.
- [ ] **Queue survives its window** — close the menu window that started
      playback; playback continues. Closing the radinho panel stops it.
- [ ] **Option-click external** — ⌥-click an MP3 link opens it in the external
      default handler instead of the radinho.
- [ ] **Dead stream** — a broken stream URL is skipped forward without an alert
      storm (a brief "Skipped…" note, then the next track).
- [ ] **Volume persistence** — set the volume, quit, relaunch; the last volume is
      restored.
- [ ] **M3U export** — File ▸ Export Menu as Playlist… produces a file QuickTime
      Player opens and plays.
- [ ] **Playback menu / shortcuts** — ⌥⌘P / ⌥⌘← / ⌥⌘→ control playback globally;
      space toggles only while the panel is key.

### Verified on hardware (fio 2)

Driven on the 10.6.8 target with a local HTTP server and the real
`StreamPlayerController`: the dark HUD radinho renders; a track plays with a
live elapsed clock; a 3-track queue auto-advances (each track plays fully to
`QTMovieDidEndNotification`, position updates 1/3 → 2/3 → 3/3); a stream that
fails to load moves the queue forward without any alert.

### Live streams + gopher-spot (fio 5)

- [ ] **Type-`s` click-to-play** — a sound item (gopher-spot "Reabrir stream")
      resolves its `.pls` over gopher and plays the live Icecast stream in the
      radinho ("live · gopher-spot").
- [ ] **Now Playing** — the panel title reflects `/spot/now` and updates as the
      track changes.
- [ ] **Transport → control plane** — Next/Prev/Play/Pause in the radinho drive
      gopher `/spot/control/*` (Spotify skips/pauses upstream).
- [ ] **Survives its window** — closing the browser window keeps the stream
      playing; closing the panel stops it.
- [ ] **QTKit vs live** — a finite MP3 still uses the QTKit queue; only live
      streams use CoreAudio.

Verified on the 10.6.8 target against real gopher-spot
(`gopher://10.0.100.112:70`, Icecast at `10.0.100.113:8000`): `DTAudioStreamer`
reaches sustained playback of the live stream (CoreAudio, where QTKit errored);
the radinho plays in stream mode with a live clock; the `Next` button fired
`/spot/control/next` and the now-playing title changed ("Dilemma" → "Rich
Girl"); 0 leaks under `MallocStackLogging`. `make test` = 47 tests green
(adds the PLSParser suite).

### The radinho as a gopher-spot menu (fio 6)

- [ ] **Expand on play** — activating `[SND] Reabrir stream` opens the radinho
      already expanded: transport + search field + the gopher-spot root menu.
- [ ] **Search** — type a query in "buscar músicas…" → Faixas / Artistas / Albuns.
- [ ] **Drill-down + Back** — a track opens its detail page; an album lists its
      tracks; the `‹` button steps back through the nav stack.
- [ ] **Play** — `>> Tocar agora` plays the track on Spotify and ensures the
      local stream is on (you hear it); the list shows now-playing.
- [ ] **fio-1 regression** — floodgap/debene menus still render + activate
      (menu rendering moved into the shared `GopherMenuView`).
- [ ] Known: **artist** drill-down errors (gopher-spot server returns Spotify
      HTTP 403); the radinho just renders the error menu.

Verified on the 10.6.8 target: the radinho expands into the gopher-spot browser,
renders the root menu in the dark theme, and shows the polled now-playing title.
`make test` = 50 tests green (adds the SpotSelectors suite).

### Preferences + media keys (fio 8)

Preferences (mostly driven over SSH via UI scripting + `screencapture`):

- [ ] **Server section renders** — Cmd-, shows a "gopher-spot Server" section
      with Host + Port fields prefilled from the current backend, Test Connection
      + Save buttons, above the Document Font section.
- [ ] **Validation gates Save** — clear the host or type a port outside 1–65535:
      Save (and Test) disable; a valid host/port re-enables them.
- [ ] **Test Connection — success** — with a live address, the status shows
      "Connected · N ms · M bytes"; the UI never freezes while it runs.
- [ ] **Test Connection — error** — a closed port / bad host shows "Failed: …".
- [ ] **Legacy defaults respected** — `defaults write dev.debene.detoca DTSpotHost
      …` then Cmd-,: the window shows that value.
- [ ] **Save reconnects** — change the host/port and Save: the radinho tears down
      and reconnects to the new backend (same as Cmd-R).

Media keys — **hardware validation (Felipe, at the MacBook2,1):**

- [ ] **⏯ toggles** — with the radinho live, the play/pause key pauses/resumes
      (and the transport mirrors upstream).
- [ ] **⏭ / ⏮ skip** — next/previous keys skip tracks (same as the panel buttons).
- [ ] **⏯ revives** — with the radinho closed/idle, ⏯ reconnects + starts playing.
      ⏭ / ⏮ while idle do nothing (silent).
- [ ] **iTunes stays shut** — pressing ⏯ with DeToca running does **not** launch
      iTunes (the event is consumed).
- [ ] **Keys return on quit** — after quitting DeToca, the media keys control
      iTunes/the system again.
- [ ] Note which F-keys map to prev/play/next and whether `fn` is needed on this
      hardware (record in the fio-8 report).

Verified over SSH on the 10.6.8 target (agent-permitting):

- `make` builds `DeToca.app` clean under `-Wall` — **zero warnings**.
- `make test` — **66 OCUnit tests green** (adds 16: DTServerPrefs validation +
  defaults/persistence, DTMediaKeyRouter decode + policy).
- Fresh launch logs `[mediakeys] event tap installed (session tap,
  NX_SYSDEFINED)` — the session tap is granted on 10.6.8 **without** the
  "assistive devices" toggle; app launches and quits cleanly.
- Preferences window renders correctly (screenshot): Server section with the real
  host/port, Test/Save buttons, divider, Document Font section — no clipping.
- gopher-spot root (`10.0.100.112:70`) is reachable over the app's socket path
  (`spikeb`), the substrate Test Connection uses.

### The player + playlist (fio 9)

Data layer is unit-tested (`SpotAPITests`: parser, snapshot, interpolation). The
rest is driven over SSH against the live API (`10.0.100.112:70`) + `screencapture`;
the physical double-click and media keys are Felipe's manual gate.

- [ ] **Player reflects the API** — with a track playing, the window shows
      "track — artist" (amber), album, duration, and the **seek bar advances**
      between polls (interpolated via `ts`).
- [ ] **Transport** — prev/play-pause/next hit the API (Spotify skips/pauses);
      the play glyph tracks state.
- [ ] **Seek** — drag the seek bar → the track jumps (allow ~1–2 s for Spotify's
      eventual consistency to settle; re-poll shows it).
- [ ] **Volume** — the slider sets the device volume (audible).
- [ ] **Playlist search** — Cmd-Y, type a query, Enter → a **flat track list**
      (no menu drilling), UTF-8 intact.
- [ ] **Click / Return to play** — double-click (or ↑/↓ + Return) a row → that
      track plays; the player reflects it; the row glows amber. *(Manual: SSH
      can't synthesize a real double-click / key-window focus.)*
- [ ] **Media keys → player** — F7/F8/F9 drive the player's API transport; play
      while closed reveals + plays.
- [ ] **Dark skin** — player, playlist and Preferences share the dark/amber CRT
      look; nothing is a bright system form.
- [ ] **Listen test** — audio actually comes out of the Icecast stream (fio-5
      `DTAudioStreamer`, unchanged).

Verified over SSH on the 10.6 target (agent-permitting):

- `make` builds clean under `-Wall` — **zero warnings**; `make test` **78 green**
  (adds 12: `DTNowSnapshot` parser + interpolation).
- Live API: with "Construção" playing, the player showed "Construção — Chico
  Buarque" (amber) / album / 6:23 and the seek advanced **0:33 → 0:39** across two
  shots; firing a derived `/spot/play?uri` switched the track (Construção →
  Cotidiano) in `/now`; playlist search "chico buarque" returned a flat 10-track
  list; row selection works (screenshot).
- Player, playlist and Preferences all render in the dark/amber skin
  (screenshots), no clipping. `leaks` = **0** on the running app.

## Verified on hardware (fio 1)

Built and run on the actual target (Mac OS X 10.6.8, MacBook2,1, i386,
Xcode 3.2.6), driven over SSH with `screencapture`:

- `make test` — 30/30 OCUnit tests pass, zero warnings.
- `make` — `DeToca.app` builds clean under `-Wall` (zero warnings).
- Home menu (`gopher.debene.dev`), Floodgap menu, and the gopher-cta ANSI
  braille map all render correctly; the map is **aligned with correct
  256-color** output on the dark background.
- Bookmarks seed file is created as a valid, hand-editable gophermap.
