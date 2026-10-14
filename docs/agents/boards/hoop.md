# Yarn Hoop

- **Yarn Hoop is the thirty-ninth card** (2026-10-14, `puzzles/hoop2d.gd`,
  `puzzles/hoop_state.gd`, `ui/hud/hoop_tutorial_diagram.gd`,
  `ui/menu/cards/hoop.gd`; no spec and no concept tab -- asked for from two
  screenshots and built in one sitting, "Build end to end ... Do it
  autonomous"). The web game it follows is Rope Stitch Puzzle, and **that
  name goes nowhere else**: not in code, comments, commits or on screen.
  The puzzle id is `hoop` and the locale prefix `YH_`.
- **The rules, as the screenshots showed** (the game's page says only that
  you connect points with a rope and the shapes form a hidden picture):
  a low-poly picture is hidden on linen, only its corners showing as pins;
  a small mark in each unfilled panel says how many corners it has (the
  screenshots' 3s and 4s; ours are that many dots, the panel's own shape in
  small, because a numeral a panel is a draw call). Drag a thread from pin
  to pin: it is taken only along a panel's side, refused (rose ring,
  `locked`) between pins that share none. A panel whose every side is
  threaded knits in, in its colour. A pin with nothing left to thread pops
  off. The pill reads panels filled of all, as the screenshots' 5/54.
- **Combos** (the user: "Combos come from filling multiple panels at once
  (by connecting around and triggering the next one)"): one drag goes on
  from pin to pin (it can also walk along threads already laid, and goes on
  from a pin that has just popped off), and every panel it closes counts; the bubble
  shows xN from 2, `fill` climbs a step a panel (five at the most), a side
  two panels share fills both (`double`), and a drag of 3+ ends on `run`
  and a sparkle, 5+ with confetti. A press and release on one pin holds it,
  and a press on another lays the thread between them (tap-tap, for one
  hand).
- **The picture** is cut from the bead pictures Pixel Garden, Button Box and
  Toy Cannons deal (`content/pixel_garden.json`, band = level, or the day's
  themed one of that side, `ThemedPictures.picture`): a lattice of pins at a
  stride that gives about `PANELS` (26, 50, 90, 140) panels, jittered off
  the rng, each cell cut on the diagonal that keeps its halves the more one
  colour, each half the colour most of its beads are, a half that is mostly
  bare left out, two halves of one colour sometimes one quad (`QUADS`). So
  the daily theme reaches this board with no server work. Measured off six
  seeds: 27-36 / 49-64 / 88-104 / 137-156 panels, about 15% quads.
- **Insane** is the biggest picture with no corner marks (`YH_RULES_INSANE`,
  the BLIND tutorial page). Nothing counts and nothing can be lost.
- **Tools row**: the bulb on every band (3, 3, 2, 2; it threads a side of
  the panel nearest done) and the bin. **No Undo**: a thread is only ever
  taken along a side, so nothing laid is wrong. The seal: any Insane day, or
  a day with no thread refused ("Neat stitch").
- **The look**: a sewing table of oat check, the hoop's wood ring with its
  screw, linen with a weave, purple pins, terracotta yarn with a twist; a
  filled panel is a darker ground in its bead colour with columns of lighter
  V stitches, each panel a shade of its own so the picture reads as facets.
  Two balls of yarn and a needle dress the foot. The win swells the picture
  once, then slides the hoop to the win's span.
- **Meshes**: the table, the hoop and the clamp built a layout; the knitting
  in chunks of ten panels, rebuilt when one fills; threads, pins and marks a
  mesh each, rebuilt on a thread; what moves as two meshes a frame. Draw
  calls on `opengl3_angle` at 810x1440: 78 at rest, 82-90 during a combo on
  Medium, 94-121 on the Insane win (budget 855). Building every panel's
  knitting on Insane takes ~27 ms headless.
- **Sounds** (`tools/gen_sfx.py` "hoop", no new take: Button Box's raws
  copied into `build/sfx_raw/hoop/`): `pick`, `stitch`, `fill`, `locked`,
  `enter`, `reset`, `double`, `run`, `whole`, `hint`, `solved`, `party`,
  `stamp`. All 13 pass `measure_sfx.py`; **none has been heard by the user**.
- **Harnesses**: `tests/_shot_hoop.gd -- d=<0..3> rest|play|solve` (a greedy
  drag through the board's own input path), `tests/_probe_hoop.gd`
  (headless, every band), `tests/_win.gd -- hoop` (PASS, Medium, bulb then
  every side dragged through the window).

## Decided for the user, unconfirmed (2026-10-14)

- The name, the hoop-and-knitting look, the purple pins and terracotta yarn.
- Panel marks as dots, not numerals; Insane hides them.
- Wrong threads refused rather than laid and judged; hence no Undo, and the
  seal's "no thread refused".
- Panel counts per band (26/50/90/140) and the quad share; Easy's pictures
  are crude at ~30 panels (the daisy reads, a mushroom only just).
- The combo rules (from 2, a step a panel, `run` from 3).
- The tutorial (five pages, hand-laid three triangles and a square) and the
  menu card (a low-poly heart in a hoop, the go button a ball of yarn).
- Owed: a phone (pin size at ~65 px spacing on Insane; the snap is 24-46 px
  by spacing), the sounds heard, pt/es read, haptics felt.
