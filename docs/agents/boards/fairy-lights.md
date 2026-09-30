# Fairy Lights

- **What it is** (2026-09-20, `puzzles/fairy_lights2d.gd`, rules in
  `puzzles/fairy_lights_state.gd`, deals in `puzzles/fairy_lights_gen.gd`,
  spec `docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md`, mock
  `docs/brainstorm/concepts.html#fairylights`). A garden of paving stones, a
  lantern post in the middle and a length of wire on every stone; a tap turns
  a piece a quarter turn clockwise, and that is the only gesture. Wire joined
  back to the post runs gold. Done when every stub meets a stub and every
  lantern is lit. The flat spec names the genre it follows once, to forbid
  it; nothing else does. **Live is derived, never stored** (`state.depths()`
  every call), and the board keeps only *moments* (`_live_at`, `_out_at`,
  `_wake_at`, `_dark_at`), so undo needs no book.
- **The polish** (2026-09-30, `feat/fairylights-polish`, spec
  `docs/superpowers/specs/2026-09-30-fairylights-polish-design.md`): Hard and
  Insane judge one mistake, **a turn of a piece that is already right** (a
  fuse: sparks, a brown-out, a heart, and a brass clip that holds the piece
  for good); Insane is **Wish Tags**, an 8x8 garden the ordinary rules cannot
  finish, whose lanterns wear their distance along the wire from the post,
  banked in `content/insane/fairylights.json` (150 gardens, 4 tags each,
  mined through `tools/insane/fairylights_ladder.gd`); the streak, join
  sparks, moth / hum / love gags, the party (dance, fireflies, the nap cat,
  gold tags, the seal); re-prompted cozy sounds (unheard).

## Numbers

| band | garden | cell | hints | hearts |
|---|---|---|---|---|
| Easy | 5x5 | 188 | 3 | - |
| Medium | 6x6 | 157 | 3 | - |
| Hard | 7x7 | 134 | 1 | 3 |
| Insane | 8x8 Wish Tags | 118 | 0 | 2 |

Peak draw calls at 810x1440 (the spec's section 6 has every mode): rest
102-125, fuse 124 (Hard), out with the card 139, tags 144, solve 139 (Easy) /
173 (Insane, and on ANGLE), restore 152 -- far under 855. Suite 123054/0;
`tests/_win.gd -- fairylights` winnable 1/1 (6x6, 33 turns).

## Harness

    godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_fairylights.gd -- d=2 fuse

Modes `rest press fuse out tags howto restore right solve`, `d=0..3`, `rm`
for reduce motion, `out=<dir>` for the frames (default `/tmp`). Windowed and
one at a time.

## Review findings, fixed (2026-09-30)

- **One finger turns a piece**: the press keeps its touch index
  (`_press_finger`, -1 for the mouse) and another finger's press, slide and
  release are ignored. The turn fires only when the finger lifts from the
  piece it went down on while still held -- before, a slide from one piece to
  the next turned the second, a second finger turned a second piece, and a
  cancelled touch or a release with no press (one pressed during a fuse)
  still turned whatever was under it, which on Hard and Insane can be a fuse.
- **A wake chime still to come dies with its lantern**: `_settle` drops
  queued `_wake_cues` for any cell the move left dark, and `_run_out` drops
  them all. An undo or Reset inside the wash had still rung the lantern awake
  and played its moth, hum or love over it going dark.
- **`can_reset()`** greys Reset during a fuse, out of hearts and once done
  (the host logged a `board_reset` that did nothing).
- Checked and left: the board stops rebuilding after the party and after a
  restore (the mesh is the same object 1.5 s apart, `_animating()` false,
  the life layer quiet); under reduce motion lantern transforms are identical
  1.5 s apart; Try again clears clips, gives every heart back and keeps a
  hint's pin; the winning turn's join spark lands 0.2 s after the tap, before
  the chase, so it is not over the party.
