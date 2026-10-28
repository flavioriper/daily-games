# Shikaku

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Shikaku's clues can ask for a shape** (2026-09-25). A clue is
  `{pos, area, shape}`: `shape` is `shikaku_gen.gd`'s `Shape` (any, square,
  tall, wide) and `area` 0 means no number -- the plot may be any size of
  that shape. `Gen.fits()` is the one rule every check goes through. The
  ladder is `shikaku_state.gd`'s `SHAPES`: Easy numbers only, Medium shapes
  on some numbers, Hard and Insane take numbers off shaped clues (about 19%
  and 54% of clues over 40 seeds), each removal kept only if the board stays
  unique. The solver is a cell-first exact cover now, because a numberless
  clue breaks the "areas sum to the field" shortcut; worst generation 57.5 ms
  on Insane. The sign *is* the shape (`marker_face.gd`'s `PLAQUES`), and a
  shaped sign carries an inked inner frame so a square never reads as the
  plain card. The win's flowers are coloured so no two touching beds match.
- **A plot may not spill over another** (2026-09-30). `commit(rect, own)`
  refuses a drag that overlaps any plot but `own`, the one the finger went
  down in, with `{"kind": "taken", "plot": i}`: the board blushes that bed,
  shivers its sign and says `SK_TAKEN`. Drawing from inside a plot still
  redraws it. The pending wash turns rose while it overlaps another plot, so
  the refusal is seen before the release. Hints still clear what they cover.

### Failing, Scarecrows, rewards, motion and sound (2026-09-30)

Spec `docs/superpowers/specs/2026-09-30-shikaku-polish-design.md`, built
unattended on `feat/shikaku-polish`.

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`). A heart goes only on a bed
  that fits its sign (`fitted_clue`) and is not the answer; the bed wilts and
  `_eject` takes the move back with `state.undo()` (a redraw gives back what
  it replaced). Everything waits on `_ejecting`. Out of hearts reuses
  `ui/hud/out_of_hearts.gd`, which now takes a board's own body keys.
- **Insane is Scarecrows**: banked 8x10 (`content/insane/shikaku.json`,
  `tools/insane/shikaku_ladder.gd`), three signs whose number counts the beds
  sharing a fence with theirs (`clue.crow`), everything else shaped and
  stripped of numbers while unique, and kept only when the board is not
  unique with the scarecrows read as blank signs. One hint.
- **Settled beds sprout** (the seedling at `SPROUT_U`, in the bed's mesh);
  the planting wave grows on from the shoots. On a board with hearts only the
  answer's beds sprout, so a bed about to wilt never does.
- **Streak, gags, butterflies, seal, party**: see the spec. Hats needed
  `MarkerFace._hat_place` (the base seat is a cell above a plaque).
- **Harness**: `tests/_shot_shikaku.gd -- d=0..3 rest|right|wrong|solve|perf
  [rm]`. Draw calls (angle): 151 mid-board with butterflies, 272 peak across
  the Insane solve.

### Performance checkup and the tutorial (2026-10-01)

- **Measured first** (`tests/_probe_perf.gd shikaku d=3 [fill]`, ANGLE,
  810x1440, second of two runs; the probe now drags Shikaku's answer bed by
  bed, and `fill` leaves two whole drags): Insane idled at **129 draw calls,
  ~9.0 ms**, play ~11.1 ms with 27-32 ms frames; a near-full field idled at
  **156, ~12.1 ms**; the solve peaked at **253** with 25-30 ms frames through
  the planting wave and ~60 ms as the crop was folded into the beds. The
  signs were a third of the board's calls (stake, plaque, numeral each), the
  beds one call apiece, the wave one call a seedling, and the fence was
  rebuilt whole every frame it moved (1.5-2 ms).
- **Signs at rest are one mesh** (`_bake_signs`, `SignBake`): every sign
  standing still in its slot is baked eyes open and looking ahead
  (`Face.bake_into(..., rest)`) with its numeral (`MarkerFace.numeral()`),
  remade only when one joins, leaves or changes face; a party hat or glasses
  fully on is baked too. A sign that is only blinking or glancing draws
  itself over its baked twin (the plaque is opaque), so blinks never rebake.
- **`Face.FlatBuilder`**: the bake flattens each source mesh once into a
  plain triangle list (cached in a dict the board owns, `_flat_cache`), so a
  bake is native array copies; `Builder.append`'s per-index loop made a sign
  bake 4-8 ms, this ~0.8.
- **Beds at rest are one mesh** (`_beds_baked`): untinted, unmoved beds that
  are done tilling and sprouting; arriving, wilting and flashing beds draw on
  their own after it (beds never overlap).
- **The fence is two meshes** (`_build_fence`): finished stretches in
  `_fence_still`, made again only when that set changes; growing or leaving
  ones and their posts in `_fence`, every frame they move.
- **The crop is its own mesh** (`_crop_bake`): the wave is one mesh a frame
  from the cached seedlings, and the planted field keeps it; the beds are
  never rebuilt with the crop in them (`_build_bed` lost its `planted`).
- **After**: Insane idle **100 / ~7.2 ms**, play 119 / ~9 ms; near-full
  idle **~115 / ~9.3 ms**; the solve's peak **164**, mean ~11 ms. Easy,
  Medium and Hard idle 96-99 / ~7 ms. Still open: the solve's own frame
  (~23 ms: the release, `_on_solved` and the host's save) and the win card's
  first frame (~55 ms, the shared host, every board); no phone reading.
- **Undo, Hint, Check and Reset** were already on every band.
- **The tutorial is three to six pages** (`tutorial_pages()`,
  `ui/hud/shikaku_tutorial_diagram.gd`): a 4x3 field drawn by an off-tree
  board instance (`_art`) with the lesson's own State -- its ground, beds,
  pinned line, fence, dashed wash, count disc and heart pill -- under real
  MarkerFace signs; every move goes through `State.commit`, `undo` and
  `apply_hint`, so the signs beam, puzzle and blush as on the board. Draw a
  bed (DRAG), one sign in each and a tap to clear (ONE); then shapes from
  Medium (SHAPES), the hint with the band's count (HINT), hearts on Hard and
  Insane (HEARTS: a fitting bed that is not the answer wilts) and Insane's
  scarecrows (CROW: its neighbours counted). Reduce motion shows each
  lesson's answer.
- **Insane counts moves (2026-10-04)** (`docs/agents/flat-screens.md`,
  "Insane counts moves"). `HEARTS` is all zero, so `_judge` never calls
  `_wrong_bed` and `_settle` sprouts any bed whose sign is met, as on
  Medium (it used to hold the shoots back for the answer's beds); the
  HEARTS lesson is unreachable. That code is left in place, dormant.
  Scarecrows hands out `clues.size() + 3` moves (`State.moves_budget`; 21
  on an 18-sign field). `State.move_cost(rect, own)`: a bed fenced is one,
  a bed cleared is one, **a redraw from inside a bed is two** (one off, one
  down; a redraw landing on the same bed is free), and a refused drag
  (overlap) costs nothing. A redraw with one move left is refused with
  `SK_MOVES_SHORT`. The rules sentence is the board's own, `SK_RULES_MOVES`,
  because the shared one does not say what a redraw costs. No Undo, Hint
  (`HINTS_BY_BAND[3]` is 0) or Check. Signs still beam, strain and puzzle,
  and a scarecrow still counts its neighbours.

### The meadow is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/shikaku_world.gd` is the card's
meadow with faint mown bands, a run of the garden's fence with three
flowers in the gap of the tools row, and flowers and tufts in whatever
band the field leaves at the foot: the board tells the world where its
field ends (`set_foot(y)`), since the fields differ per level (Medium
leaves 77 of 1920). The field's edges are on the host's margin; a pill row
(hearts, Insane's counter) keeps 64 over it and travels with it on the win.

- Registry: `bleed`, `level_card`, no actions row. **Check is gone**
  (`capabilities()`): the board solves itself; `check()` is unreached.
- `opengl3_angle`, 810x1440: 89 draw calls at rest (`_shot_anim.gd`);
  `tests/_win.gd -- shikaku` passes with real drags.
- Decided for the user, unconfirmed: no Check; the fence in the tools gap
  (it stands over "Well done!" on the win); the field's own sand panel
  kept. Owed: a phone, the level slide's look.

## Made fun (2026-10-28)

The user: "make shikaku experience way better to play, and game itself way
funnier to play, right now nobody likes it", autonomous, push when done.
References from the web, by genre: store listings of the rectangle apps
advertise showing *the possible areas around a clue*, *clear explanations
when a selection is rejected* and *width x height counting while drawing*;
the solving guides all teach the same two first moves (a sign that fits
only one way; a square only one sign can reach). No reviews worth citing.

**Measured first** (`tests/_probe_sk_fun.gd`, headless, 40 days a band,
`puzzles/shikaku_reader.gd`): reading the field the way those guides teach
read 94% of Easy's beds on average but **3 of 40 Easy fields not at all**
(a field of vertical 3s needs lookahead a beginner does not have), Hard
39/40 whole, Insane's scarecrow bank 0/40 (its counts are not read). It
never laid a wrong bed. The board's lines (refusals, "N squares still bare",
"wrong size") had no place on screen: nothing read `tip_line()` since the
bleed redesign. A fitting bed that is not the answer was accepted, sprouted
and counted in the streak, and the player found out only at "every square
planted, but...", with nothing pointing at which bed. No band had stakes.
The baseline `right` shot already shows plenty of spectacle (streak bubble,
gags, butterflies); the gap was reading and stakes, so no new sounds, gags
or celebration.

**What changed**:

- **Readable deals**: Easy to Hard deal again until the reader reads the
  whole field (`State.READABLE_TRIES` 16, the last try stands). Probe after:
  40/40 on all three; setup mean 0.8 / 1.6 / 6.2 ms, worst 17 ms on Hard.
  Today's Easy-Hard fields changed. Insane's bank untouched.
- **The reader** (`puzzles/shikaku_reader.gd`): every sign keeps the beds
  it could still be; one way, only sign (a square one sign alone reaches),
  crowded (a square every bed of a sign covers). Sound with scarecrows.
- **The bulb teaches in two presses** (`hint`, `_read`, `_why`): the first
  reads from the beds the player has right, rims the sign (and the square
  the rule turned on, and for crowded the other sign) in sun and says why
  (`SK_WHY_ONE_WAY/ONLY/CROWD`, `SK_WHY_START` where nothing decides, which
  is most of Insane), for one hint; a second press draws and pins it, free
  (`State.apply_hint(target)`). Any move or Undo puts the reading out. The
  tutorial's HINT page presses twice (`HTP_SK_READ_CAP`); its body no longer
  names Check.
- **A press on a sign washes its reach** (`_build_reach`): every square a
  bed it could still be covers, clear of the other beds as they stand. One
  mesh, made at the press.
- **The count disc says the sides** ("2 x 3") under the area once the
  rectangle is more than a strip.
- **Stuck squares** (`_find_stuck`): after every move, with no bed
  blushing, the reader takes the beds as laid; bare squares no sign can
  reach any more are rimmed rose and `SK_STUCK` says a bed beside them is
  wrong (a sign boxed in with no room is rimmed when there are no such
  squares). Public reasoning, never the answer.
- **A bed that does not fit says why**: `SK_NOT_SIZE` ("asks for 6; this
  bed has 4"), `SK_NOT_SQUARE/TALL/WIDE`.
- **The toast** (`_toast_say`, `_draw_toast`, its own layer): a paper card
  the field's width on the half of the field away from what it is about,
  for refusals, why-nots, blushing beds, stuck squares, the wrong full field
  and the reading (6 s, or until a move puts the reading out; the rims
  stay). 3.6 s otherwise. A blush pops it only for the bed just drawn.
- **Live stars** (`ui/flat/star_line.gd`) in a 48 px row over the field
  (`STAR_ROW`; hearts or a counter keep `HEART_ROW`), by moves over par (a
  bed a sign; `State.move_cost`: fenced 1, cleared 1, redrawn 2):
  `STARS_BY_BAND` three up to +2/+2/+3/+4, two up to +5/+6/+8/+10. The
  bulb's beds and Undo count nothing; Reset keeps the day's moves. The
  win's subtitle is the moves (`SK_WIN_MOVES_N`) and `SK_WIN_PAR` at par or
  the best run (`SK_WIN_STREAK`), one line. `completion_record` keeps moves
  and run, so a reopened day shows its stars.

opengl3_angle 810x1440, `perf` mid-board: 86 / 89 / 86 / 88 draw calls
(Easy to Insane); Insane's solve peaks at 153 (was 164). `_win.gd
shikaku` PASS; suite 303252/0. Unseen on a phone; the star cuts, the toast's
placement and the reach wash's sun are my calls, unconfirmed; pt/es unread
by a speaker. Left as is: a sign boxed in with no room stands on a bare
square, so the stuck rim can ring the square a sign stands on (the line
still reads true).
