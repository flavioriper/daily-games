# Glimpse

- **Glimpse is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  first and the first Memory board. Pixel Garden from memory: the day's
  little mirrored picture is held up over the pegboard for 5-7 s, then
  covered; rebuild it bead for bead. Spec
  `docs/superpowers/specs/2026-10-22-glimpse-design.md`.
- **It is Pixel Garden's code.** `puzzles/glimpse2d.gd` extends
  `pixel_garden2d.gd`; `glimpse_state.gd` extends its state and swaps the
  bank for a generator. Pixel Garden gained two hooks for it and nothing
  else: `_draw_thumb()` (the card's picture at rest) and the state's
  `_palette()` (the letters' colour names). A change to Pixel Garden's board
  is a change to Glimpse: check both.
- What Glimpse overrides: `_press`/`_release` (a tap while the picture is up
  puts it down; a tap on the cover spends a look; the picture never goes
  down on a finger lifted), `_blocked` (nothing plays while it is up),
  `_draw_thumb` (the cover, `cover()`, static so the tutorial and the menu
  card draw the same one), `_draw_peek` (the bar of time), `capabilities`
  (Undo only), `hints_left` (0), `_zoomable` (never), `_party` (flawless),
  `flat_win`, `skill_quality`, `completion_record` (`looks`, `first`).
- Tutorial: `pixel_garden_tutorial_diagram.gd` gained lessons GLIMPSE and
  LOOK (the diagram's Board draws the cover when `covered`); Glimpse's pages
  are GLIMPSE, SEAT, PLATE (its own body), LOOK, UNDO.
- Menu card `ui/menu/cards/glimpse.gd` extends Pixel Garden's: a blue mat,
  a half-beaded bug, the covered card where the iron lay. Vista: sky.
- Sounds: `tools/gen_sfx.py` set `glimpse` (22 cues), every take copied
  from `build/sfx_raw/pixelgarden/` or the bank, none bought. Unheard.
- Seen once windowed (810x1440, Medium): held-up picture, cover, a look,
  the iron, the win with the six-row report; peak 165 draw calls. Not seen:
  a phone, pt/es by a speaker, Hard and Insane rendered, reduce motion.

### Made fun (2026-10-29)

Same ask as Pixel Garden's "Made fun" (same spec). Memory Matrix's
loop: tiles shown for a moment, each tap judged on the spot, and the
grid grows with success. Glimpse showed one picture and said nothing until
the last bead was down.

- **Every bead is judged as it goes down** (`_paint`, `_miss`): a bead the
  picture does not want on that peg sits a moment and hops back to its
  compartment, the peg ringed rose (`_more_marks`). It counts a miss
  (`misses`, `State.miss` keeps it as the peg's first try), and the stroke
  that missed paints no more pegs, so a run swept one peg too far costs
  one miss. Toast `GL_MISS_FIRST`, then `GL_MISS`. Nothing wrong can
  stand, so **Undo is gone** (`capabilities` is `[]`, the tutorial's UNDO
  page too).
- **Runs**: right beads in a row climb in pitch (`_climb`, up to +0.3),
  with `GL_WORD_RUN` ("5 in a row!"), `steady` and a sparkle every
  `RUN_WORD` (5). `best_run` is kept.
- **Live stars** by misses plus looks (`GL_STARS_CUT` [0, 2]). Flawless
  is no miss and no look. `skill_quality` is 1 minus misses over beads,
  less `LOOK_COST` a look. The win says "Every bead right the first
  time!" or how many slips and the best run (`GL_WIN_MISS_ONE/N`,
  `GL_WIN_RUN`). The record keeps `misses` and `run`.
- Pixel Garden's leaves sprout here too. Its card ring, fading, guides and
  Easy trace are off (`_reads_card()` false), since they would read the
  covered card out.
- `GL_RULES_JUDGE` added; `HTP_GL_PLATE_BODY` rewritten.
- Rounds (one picture after another, growing, Memory Matrix's other half)
  were left out: they would change the one-picture day record.
- `_win.gd -- glimpse` taps one wrong bead first (a miss, two stars, the
  toast) and PASSes. Medium 94 draw calls at peak in play. Unseen on a
  phone; pt/es unread by a speaker.
