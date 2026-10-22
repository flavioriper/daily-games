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
