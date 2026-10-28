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

## Made fun (2026-10-28, unattended)

The user: "make honeycomb experience way better to play, and game itself
way funnier to play, right now nobody likes it ... show the words as a
list in order of placement instead of reordering, something more elegant".

- **The words found are wax chips in the order found** (`_lay_chips`,
  `Art.chip`): a new word flies from the entry row into its own chip at the
  end and the chip pops in; no chip moves to let it in. A full comb's chip
  is honey. Rows centred, top-aligned; the chips shrink from `CHIP_SIZE` to
  `CHIP_MIN`, and past that the earliest row makes way and is counted on a
  first chip (`HC_EARLIER_ONE/_N`). A word sent again lights its chip
  (`_flash_i`). One mesh for the chips, the newest a cached mesh under a
  transform; the lit chip's ring is kept in `_flash_mesh` (a temporary
  freed before the frame drew it: "mesh is null"), and every chip's draw
  starts with `draw_set_transform(Vector2.ZERO)` (the last chip's text
  transform otherwise carried into the next chip's mesh).
- **Honey is one a letter** (`Words.points`), seven more for a full comb.
  A four-letter word poured one before, and a player finding the short
  words first filled the jar a drop at a time (Medium ~19 words). The lines
  are `SHARE` [0.18, 0.2, 0.24, 0.24]: `tests/_probe_hc_pace.gd` puts the
  line at 5-7 words on Easy, 8-10 Medium, 11-15 Hard (an any-order player
  and a shortest-first one, all three languages). `_probe_honeycomb.gd`:
  unfillable 0, clashes 0. `_win.gd -- honeycomb`: Medium's day 20 words
  before, 10 after.
- **Three ranks on the way to the line** (`State.RANKS` 25/50/75% of it):
  Buzzing, Busy bee, Honey maker (`HC_RANK_n`, toasts `HC_RANK_n_SAY`), a
  hex pip each on the strip that lights and bumps when the word reaching it
  lands, with the `rank` cue (four wraps rising, pitched up a rank) and a
  sparkle. The honey count moved under the strip (`label_y`, `LABEL_H`),
  with the rank's name before it: the pips sat where the centred numbers
  were. Names are ours; the original's are never used.
- **The search's map**: under each cell's letter, how many of the day's
  words still to find begin with it (`State.starts()`, with the queen as she
  is now, so it follows her flights on Insane; cached on found count and
  queen). The count line says how many full combs still hide
  (`HC_FULL_LEFT_ONE/_N`). `HC_RULES_MAP` explains both in the rules.
- **The praise is said in the entry's row** once the word has left it
  (`_say_now(key, after)`, `_draw_say`): bigger, in honey for praise, dim
  for a refusal, gone at the next letter. Under the keys only the count line
  stays (it sat where the thumb is).
- **Runs**: every third word in a row with no refusal says "%d in a row!"
  (`HC_STREAK`); the word's pop rides up the run. A word already found does
  not break a run.
- **The swarm**: one more drifting bee joins every three words found (two
  to seven), popping in as the word lands.
- Draw calls (`opengl3_angle`, 810x1440): 110-119 in play (Easy, Medium,
  Insane), 170 on the win, 146 a tutorial page.
- Owed: the `rank` cue heard, the phone, pt/es names read by a speaker.
