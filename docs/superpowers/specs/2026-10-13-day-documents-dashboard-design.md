# Day documents and the quality dashboard

2026-10-13. The user: "we need some simple dashboard (but elegant) where I
can easily see games data, solution, so I can measure quality of daily
challenges one by one", then: "we should store into db all daily schemas, so
the both game and dashboard should only read the schema".

## What it is for

The user wants to go through the daily challenges one at a time, board by
board and day by day, see the puzzle as dealt beside its solution with the
figures a board can give, and judge whether the day is good. Weak days
should stand out in a list before they are opened.

The stored day is the contract. This version defines it and reads it from
local files; the db, publishing, and the game reading a stored day are a
second project, decided on 2026-10-13 ("Schema now, game later").

## What is true today

- A board's day is `Daily.seed_for(seed_as or id, level, date)` handed to
  the board's `build(rng, level)` (`ui/flat/flat_host.gd:620`,
  `ui/puzzle_host.gd`). All 33 `puzzles/*2d.gd` have `build`.
- What `build` deals is a dictionary of the board's own shape: 33 shapes.
- About a dozen boards pick their day out of a bank in `content/*.json`.
  Golden Acorn's day is written by the server (`publishDay`) and the bank
  is what a phone deals when nobody published.
- **A day is not the same on every phone for every board.**
  `sudoku_gen.gd:186-200` stops at a wall-clock deadline, so a slow phone
  can deal another Sudoku than a fast one. Ten more generators read a clock
  or a budget (caterpillar, horse, fairy_lights, lightup, knight, queens,
  pinwheel, rings, untangle, trestle); whether theirs change the result is
  not checked yet. For those, the export is what this Mac deals.

## The day document

One per board, date and level.

    {
      "board": "sudoku",          registry id
      "seed_as": "sudoku",        the id the seed was mixed with
      "date": 20261013,           Daily.date_key
      "level": 2,                 0..3
      "seed": 123456789,
      "source": "generator",      generator | bank | server
      "gen_ms": 84,               wall time of build() on the exporting Mac
      "budget_hit": false,        only where a generator reports it
      "kind": "grid",             grid | text: what the page draws with
      "payload": { ... },         the board's dealt data, its own shape
      "solution": { ... },        the board's own shape
      "metrics": { ... },         flat name -> number|bool|string
      "view": { ... }             only for kind "grid", see below
    }

`payload` and `solution` are not normalized. `metrics` holds only what the
board already knows after `build` (size, clues given, solution length,
unique, attempts, nodes): no new solver is written for this version.
`gen_ms` is left out of the determinism check, being a clock reading.

### `view`: what the shared grid renderer reads

So that one renderer serves the grid boards without knowing each payload:

    "view": {
      "w": 9, "h": 9,
      "puzzle":   [ cell, ... ],   row-major, w*h
      "solution": [ cell, ... ],
      "regions":  [ int, ... ],    optional, thick lines between ids
      "edges":    [ [x1,y1,x2,y2,n], ... ],   optional (bridges, paths)
      "row_clues": [...], "col_clues": [...]  optional (nonogram)
    }

A cell is `{ "t": text, "c": colour index or -1, "wall": bool, "given":
bool }`, every field optional. A board whose day does not fit this writes
`kind: "text"` and no `view`; the page shows its payload, solution and
metrics as text. Those get a drawing in a later pass.

## Game code: `day_dict()`

Each `puzzles/*2d.gd` gains one method, `func day_dict() -> Dictionary`,
returning `{source, kind, payload, solution, metrics, view?, budget_hit?}`
for what `build` just dealt. It only reads; nothing in the game calls it.
It is the seam a later `from_day()` uses.

It is on the board, not in the exporter, because the board's level table
and its dealing are the board's: an exporter with its own copy of 33 level
tables would drift.

## The exporter: `tools/export_days.gd`

A `SceneTree` script, headless:

    godot --headless --path . --script res://tools/export_days.gd -- \
        from=2026-10-13 days=30 [boards=sudoku,binairo] [levels=0,1,2,3]

For each board in `Registry.all()`, each level and each date: the seed as
the host mixes it, the board instanced under the root, a frame stepped
(`_ready` is deferred headless), `build(rng, level)` timed, `day_dict()`
read, the envelope written, the board freed. `Analytics`, `Backend` and
`Ads` are never started. Progress is pointed at a harness file as
`tests/_win.gd` does.

A board that errors or deals nothing writes a document with
`"error": "..."` and the run goes on; the page shows the gap.

Golden Acorn is dealt from its bank and marked `source: "bank"`; the
server's day is not fetched.

Output: `tools/days/<board>.json`, an array of day documents, and
`tools/days/index.json` (boards, dates, levels, when exported, the commit).
`tools/*` is already left out of the APK (`export_presets.cfg`).
`tools/days/` is git-ignored: it is made, not written.

`tools/build_dashboard.py` inlines `tools/days/*.json` into the page as
`tools/dashboard.html`, since a page opened from `file://` cannot fetch
its neighbours. Also git-ignored; `tools/dashboard.src.html` is the source.

## The dashboard

One static page, no server, no framework.

- Left: the boards in registry order, each with a small mark when any of
  its exported days is flagged.
- Top: the date and the level; left/right keys step the day, up/down the
  board, 1-4 the level.
- Middle: puzzle and solution side by side (grid renderer, or text).
- Under them: the day's figures.
- Bottom: a strip of the exported days for this board and level, one
  column a day, the chosen figure as a bar, the open day marked; a click
  opens that day.

Flags, computed by the page from the documents: `error`, `budget_hit`,
a figure more than two and a half deviations from the board-and-level mean (two flagged a day in twenty by chance), and a
payload identical to another day's in the range (a repeat).

Light and dark, the game's paper palette, Fredoka for titles as the game.

## Checks (throwaway, no new tests)

- The same range exported twice: identical but for `gen_ms`.
- The exporter's seed for today equals what `flat_host` would spawn.
- `godot --headless --check-only` on every touched board; the suite count
  unchanged.
- The headless path is proved on Binairo and Sudoku before the other 31.
- The page opened in a browser and a day stepped through on a grid board
  and a text board.

## Order of work

1. Exporter + `day_dict()` on Binairo and Sudoku; the page with the grid
   renderer; the user looks.
2. `day_dict()` on the other 31 (grid boards with `view`, the rest text).
3. Flags and the strip.

## Not in this version

The db, publishing, the game reading a stored day, curating or replacing a
day, bespoke drawings for the boards that are not grids, new solvers or
difficulty estimates, whether the ten budgeted generators are
hardware-dependent (worth its own look; it is the argument for stored
days).
