# Button Box

- **Button Box is the thirty-seventh card** (2026-10-11, `puzzles/buttons2d.gd`,
  `puzzles/buttons_state.gd`, `ui/faces/button_art.gd`; no spec and no
  concept tab -- asked for and built in one sitting, "do autonomous, no
  questions"). The web game it follows is Jewel Coloring: Crystal Sorting,
  and **that name goes nowhere else**: not in code, comments, commits or on
  screen. The puzzle id is `buttons` and the locale prefix `BB_`.
- **The rules, as the user gave them and the game's own tutorial frame
  showed** (2026-10-11; the page says only "move it to the matching cell,
  use the storage when the cell is blocked", and its canvas took no click
  from here, so nothing past the first frame was seen played): a picture of
  coloured slots, a piece on every one, all of them on the wrong colour; a
  small case; a tap takes a chain of one colour at once; pieces go into
  open slots of their colour at once; the case gains slots as colours fill.
  Ours, name for name: the patches of dyed cloth, the buttons, the tin, a
  run, sewn.
- **One move**: tap a button out of place. It lifts with every button of
  its colour touching it (`State.run_of`, nearest first). Each goes to the
  nearest bare patch of its own colour and is sewn there for good; with no
  bare patch, into the tin while it has room; the rest stay where they
  were. A patch left bare takes its button out of the tin at once. A sewn
  button is refused (`REFUSED_HOME`), and so is a tap that could move
  nothing: the tin full and no bare patch of that colour (`REFUSED_FULL`,
  with a sun ring for 1.6 s on every button a tap would sew).
- **The tin** starts at 6 places (7 on Hard) of 12 and gains one each time
  a colour is whole (`State.capacity`).
- **Nothing can be stuck.** The bare patches are always as many as the
  buttons in the tin, and the tin never holds a colour a bare patch wants,
  so a button of that colour is still on the cloth and a tap on it sews.
  `tests/_probe_buttons.gd` (headless) plays every picture of the bank on
  every band three ways -- the state's own hand, a careless one, one that
  fills the tin first -- and checks those three things on every tap: 1,080
  runs, 0 failures. So Easy to Hard cannot be lost, and a full tin is only
  a refusal.
- **The bands**: the picture is one of `content/pixel_garden.json`'s band
  (Pixel Garden's hand-drawn bank: 10, 12, 14 and 16 square, 30 a band, 3
  to 7 colours, 32 to 168 buttons), picked by this board's own seed, so the
  two boards do not show one picture on one day except by chance. A bare
  peg there is bare linen here. The scramble reads the picture's colours
  down its columns, cuts them into lengths of 3 to 7, shuffles the lengths
  and lays them along the rows; a button that lands on its own patch trades
  with one that can; a picture that still opens more than a quarter sewn
  (one nearly all one colour) is drawn again, twelve times at the most.
  Undo and the bulb (3 / 3 / 2) up to Hard. **Insane counts taps**
  (`docs/agents/flat-screens.md`, "Insane counts moves"): the taps the
  state's own hand takes (`par`, 30 to 93, median 58) and a quarter more,
  never under three; no Undo and no bulb; out of taps is the shared
  out-of-moves card (its video buys five, once). A careless hand on the
  first Insane day ran out at 126 of 144 sewn.
- **`State.hint` is a greedy hand, not a best**: the run that sews the most
  at once (the tin's own that fall in behind it counted), and with nothing
  to sew, the biggest run the tin takes whole. `par` is its count from the
  opening, so a player may beat it, and the seal asks `<=`.
- **Drawn as** `_bg` (the linen, a layout), `_still` (the stitched border
  and a patch a square), `_tin` (rebuilt when a place opens), and the
  buttons as unit meshes a colour, loose and sewn, baked with
  `Face.FlatBuilder` into `_rest` and, in the air, `_top`; the pill, the
  toast and the streak's bubble on a layer of their own. **84-111 draw
  calls on `opengl3_angle`** at 810x1440 (96 at the peak of an Insane day,
  the second of two readings; 111 through `_probe_perf.gd`'s Medium win;
  127 under the tutorial). A button is coloured
  by index, so **sewn is a shape**: the cross of thread through its holes
  and no shadow. Loose is a shadow and a patch of another colour round it.
  No character: the pieces are marks.
- **A `bleed` board** (the second after Gumdrop): the linen is the whole
  screen, the picture as big as the room between the pill and the tin
  allows (a cell is 84 at the most), the tin at the foot. `set_clear(top,
  bottom, won)`: on the win the tin fades and the picture slides to the
  middle of what the win screen leaves (`_slide_xf`, one transform over
  the meshes built at the new size). `"tip": false`; the toast says what
  the tip card would.
- **Motion that is this board's own**: a run leaving one button after
  another (0.04 s apart, 0.5 s for the whole run at the most), each in an
  arc and growing at the top of it; the tin's own leaving 0.16 s after the
  patch is bare; a bump as one lands, wider when it is sewn, and a ring
  every third; a colour whole hopping outward in rings from the tapped
  button with a few sparkles, and the tin's new place ringed; the streak's
  bubble from the third tap in a row that sewed something, confetti at
  five and ten; confetti for five or more sewn by one tap; the win's hop
  along the diagonals, the seal for a day in no more taps than the par, or
  any Insane one.
- **Sounds** (`SETS["buttons"]`, seventeen cues, no new take: Lattice's
  light wooden button, its hollow block and its one kalimba note, and
  Hedgehogs' breath). `lift` on every tap; `sew` or `tin` once a button as
  the run lands, climbing half a step a button and five at the most;
  `combo` one note the board pitches up to five steps along the streak;
  the landings tick once in 0.075 s at the most (`TICK_GAP`), a wheel
  spun and never a rattle; `run` two notes for a long run; `whole` three rising; `open` two tocks
  of the tin. `tools/measure_sfx.py buttons`: 0 of 17 flagged. Unheard.
- **Harnesses**: `tests/_shot_buttons.gd` (rest, play, refuse, hint, solve,
  out, reset, restore, howto); `tests/_probe_buttons.gd` (headless, the
  rules); `tests/_win.gd -- buttons` wins through the input path with a
  refused tap and the bulb on the way; `tests/_probe_perf.gd -- buttons`.
- **Not seen on a phone.** Shots and probes on this Mac only. The sounds
  are unheard by the user; the pt and es lines are unreviewed (botão /
  botón, retalho / retal, lata, costurado / cosido).
- **Calls made without the user** (2026-10-11): the name, the buttons, the
  linen and the tin; a run as four-way touching; nearest bare patch first;
  a run longer than the tin leaving the rest behind rather than being
  refused; the tin at 6 of 12 and a place a colour whole; Pixel Garden's
  pictures; the scramble's lengths; Insane as counted taps over a greedy
  par; the original's four boosters left out (the bulb is the hint).
