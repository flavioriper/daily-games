# Honeycomb

- **Honeycomb is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  eighth, a words board under Words. Seven letters on a comb, the queen bee
  on the middle one; spell words that hold her letter and pour their honey
  into the jar until it reaches the day's line. Spec
  `docs/superpowers/specs/2026-10-22-honeycomb-design.md`. The id is
  `honeycomb` and the locale prefix `HC_`.
- Files: `puzzles/honeycomb2d.gd` (the board, extends
  `core/puzzle_base.gd`), `puzzles/honeycomb_state.gd` (entry, judging,
  honey, the queen's flight, the bulb's word), `puzzles/honeycomb_words.gd`
  (the list, read once a session per language), `puzzles/honeycomb_world.gd`,
  `ui/faces/honeycomb_art.gd` (cell, bee, keys, strip),
  `ui/hud/honeycomb_tutorial_diagram.gd`, `ui/menu/cards/honeycomb.gd`;
  the builder `tools/build_honeycomb.py`.
- **Every word and every hive is built on the Mac**:
  `tools/build_honeycomb.py <dicts>` (a venv with `wordfreq` and `spylls`;
  `<dicts>` holds the LibreOffice Hunspell en_US, en_GB, pt_BR, es_ES
  `.dic/.aff` and the LDNOOBW lists as `rude_<lang>.txt`) writes
  `content/honeycomb[.lang].json` and the twelve banks
  `content/insane/honeycomb_{easy,medium,hard}[.lang].json` and
  `honeycomb[.lang].json` (Insane). Rerun it after any rule about words
  changes, then `godot --headless --path . --import`.
- **The win is the jar's line**, a share of the first queen's day's honey
  (`State.SHARE`). Tier 3 words score but are not in the total. Change the
  honey rule (`Words.points`) and the line moves with it.
- **The queen flies every four words and whenever her letter is spent**
  (`flies_now`, `_spent`): without the second rule a day could stick.
- **A day's four combs never share letters**: the higher band steps to its
  next hive (`State.deal`); `tests/_probe_honeycomb.gd` counts 0 a year in
  each language.
- **The board is its own tutorial**: `demo` with `demo_day` (a fixed bank
  entry, never today's: `Diagram.hive`) makes it silent, deaf and laid in
  its own rect; the diagram taps with `demo_tap`/`demo_key`. Lessons SPELL,
  QUEEN, FULL, WANDER (Insane only), HINT.
- **Meshes**: the strip and the keys are one mesh, rebuilt only while a key
  or the strip bumps; a cell is a cached unit under a transform; the queen
  and the drifting bees two cached meshes (wings up, wings down); the words
  found are one string a row.
- **Draw calls** (`opengl3_angle`, 810x1440): 93-105 in play on Medium and
  Insane, 169-170 on the win with the report, 119-124 a tutorial page, 7
  the card.
- Probe: `tests/_probe_honeycomb.gd [langs]` loads each list, fills every
  banked hive to its line from the day's words (none unfillable in 4,392)
  and counts same-day clashes. Harness: `tests/_win.gd -- honeycomb` (real
  touches: an entry with no middle letter refused, a letter and Delete,
  Shuffle, the bulb and its word finished, then the day's words to the
  line); `tests/_shot_honeycomb.gd -- <dir> d=<0..3> [tut=<page>|card]`
  shoots rest, spelling, refused, taken, shuffling, hinted, busy, the
  queen's flight, the win and the reopened day.
