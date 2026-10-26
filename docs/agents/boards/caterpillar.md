# Caterpillar

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Caterpillar is the twenty-first card** (2026-09-25,
  `puzzles/caterpillar2d.gd`, spec `2026-09-25-caterpillar-flat-design.md`,
  mock `docs/brainstorm/concepts.html#caterpillar`). Drag one walk from leaf
  1 through every square, eating the numbered leaves in order, never across a
  fence; the walk is drawn as the caterpillar (`ui/faces/caterpillar.gd`) and
  the solve turns it into a butterfly. LinkedIn ships the genre under its own
  name; **it is called Caterpillar and nothing else**. Two things travel:
  **a proof capped by a node count is never a proof** -- the first generator
  read a capped search that had found one walk as unique and 14 of 60 hard
  and insane boards had two (`tests/_probe_cat_gen.gd` re-proves uncapped) --
  and **a board whose idle breath rebuilds its whole mesh pays for it every
  frame**: 12.2 ms idle until only the head's small mesh breathed (3.3 ms,
  Pinwheel 2.44 as the control). 58 draw calls on Hard, ANGLE included.
  **Polished on 2026-09-26** (the spec's amendment): a lawn and a
  wooden-framed bed of grass tiles, real leaves under the body with a bite a
  chew, legs that step in a wave while it is dragged, three smooth chews on a
  leaf scrap and a gulp down the body, a head that runs back over a cut rather
  than jumping, and a butterfly that loops away. 58 half-walked, 57 under
  reduce motion, ANGLE agreeing.
  **The tip card is gone from every board** since `1a04e0a` (2026-09-21): the
  bottom-slot figures and tip-card rules elsewhere in this file predate that.
  **Polished again on 2026-10-01** (`2026-10-01-caterpillar-polish-design.md`):
  players said the line lagged, more the longer it grew, and it did -- every
  frame of a drag rebuilt every leaf, fence and segment (7.7 ms at one
  segment, 28.9 at sixty-two on this Mac, `tests/_probe_cat_perf.gd`), a flick
  dropped the squares between two touch events, and the head jumped back to
  restart its slide. Now: **the settled tail is baked and appended to, the
  last sixteen segments are copied from baked triangle lists through a
  transform (`Soup`, `_part`), leaves and fences are cached by their look**
  (2.3 ms at sixty-two, flat), the drag is walked a fifth of a square at a
  time, and the head trails by a melting lag along the walked squares. Two
  things travel: **a board whose cost grows with what the player has drawn
  must keep the settled part baked**, and **a corner the finger cut is an
  ambiguous gesture and never costs a heart**. Hard (3 hearts, 1 hint) prices
  a step that strands a square; Insane is **Peckish** (unnumbered middle
  leaves, a tummy of five bare squares, 2 hearts, no hints, no Undo, any step
  off the one walk priced; 200 gardens mined by
  `tools/insane/caterpillar_ladder.gd`). Streak, row sparkles, burp bubble,
  love hearts, ladybug, the party's flutter, the nap cat and the seal; the
  CLOVER sound set (unheard). Peak 113 draw calls (ANGLE, the party).
  Harness: `tests/_shot_caterpillar.gd`.

## The board checkup (2026-10-02)

- **Made in a reference layout's space.** The bed (`_build_bed`), the leaf,
  fence and badge looks, the body and the head are built while `_in_ref`
  makes `_cell()`/`_origin()` answer the reference layout, and drawn under
  `_relay()`; only the lawn (`_build_lawn`, the whole card) is made again
  when the card changes size. The win card's relayout made all of it again:
  70-97 ms. While the relay is the identity the lawn and the bed are drawn as
  one mesh (`_join`), a draw call fewer. A new garden (`build`, the
  tutorial's `lay`) clears `_ref_cell` so every look is made again.
- **Looks, not rebuilds.** Leaves, fences, badges and every segment part are
  `RunMesh` shapes keyed by look (`_look`, `_cache`, `_look_makers`); the
  resting leaves, fences and given washes go into `_rm`'s runs (one per
  piece, laid by `_lay_rooms`), the badges into `_rm_over`'s, each a rest
  mesh handed back while its signature stands, and whatever moves into
  `_rm_live`; the stretch near the head goes into `_rm_lo`/`_rm_hi` runs per
  segment slot from the seam (`BODY_SLOTS`). The head is `_head_look`: a
  mesh per turn (72), eyes (eighths), sway (fiftieths of a radian) and scrap
  (eighths), under `_top_xf`. The tail is still baked by `Cat.body` every
  eight squares (~2.5 ms then).
- **Small caches.** The hearts-and-tummy pill by what it shows
  (`_hearts_cache`), the party's flutter in sixteen wing beats
  (`_flutter_look`, made at its drawn size: a Builder's feather is absolute
  pixels), and the streak's digits drawn out of sight on the first frame
  (`_warm_combo`).
- **Tutorial**: `tutorial_pages()` and `ui/hud/caterpillar_tutorial_diagram.gd`
  (a `Garden` subclass with no sounds, tips, gags, party or card; `_inset()`
  keeps just the frame's width of lawn on the short page).

## One smooth body (2026-10-02)

- **The beads are gone.** The body was a round segment on every square over a
  thin tube, mitred at every turn; the user found it "too square ... like an
  old browser canvas game". It is now one tube (`Cat.body`, `_spine`,
  `_ribbon`): each segment owns the stretch from the middle of the step
  before it to the middle of the step after, a quadratic through its square's
  centre, so a turn is a round bend; its width eases between neighbours down
  to a pointed tail (`TAIL`, `TIP`). Over a base shaded away from the light: the
  lit body, a lit band leaning toward the top left (`LIGHT`), a crease bowed
  toward the tail between segments, two spots and a short shine per segment
  (`crease`, `decal`). Legs, spots and shadow sit on `Cat.seat` (inside a
  bend, not on the corner). A cut segment pops out as a short piece of tube.
- **Two stretches built apart must meet on one edge**: the tail and the live
  stretch end flat in the middle of a step, and the strip's normals come from
  the curve's own slope, not from neighbouring samples. One-sided normals
  left a light hairline across the body at every bake seam.
- **Cost**: the tube near the head is built whole every frame (it is one
  shape); its creases, spots and shines are RunMesh looks (`_rm_hi`, a look
  per 72nd of a turn for the marks, which lean to the light). Probe
  (`tests/_probe_cat_perf.gd`, Insane): 0.7-1.4 ms before, 0.85-1.7 ms after
  (built with the builder they were 2.3-2.8). Draw calls unchanged (108 peak
  on the Insane solve, ANGLE).

## Insane counts moves (2026-10-04)

- **Peckish prices no step any more** (`docs/agents/flat-screens.md`,
  "Insane counts moves"): `HEARTS_BY` is all zero, so `judged()` is false on
  every band and `judge()` answers "" -- the refused step off the one walk,
  the blush on the stranded squares, the worry and the scoot home are all
  dormant (`_misstep`, `_slip_back`, `_wrong` are still in the file). A step
  the rules allow is simply taken. What still refuses is what Medium refuses
  from the rules alone: a fence, the star too soon, and Peckish's empty
  tummy (`why()`).
  **The budget** is the walk's own steps plus a quarter, three at least
  (`State.moves_budget()`: 63 + 15 = 78 on the banked 8x8; setting the
  caterpillar down on leaf 1 is free). A square crawled onto costs one and
  a square backed off costs one (`State.cut_cost`, `_spend`); a cut the
  counter cannot pay for is not made. The pill (`_draw_moves`) sits where
  the hearts sat with the tummy still beside it, laid out for the full
  count's width so the tummy does not shift as the count loses a digit.
  No Undo, no hint (`capabilities()` is empty on Insane); Reset and Try
  again hand the whole budget back; the card's video buys `MOVES_BONUS`.
  Two things changed about the drag where moves are counted, both so a
  slip is not priced: **a cut corner is stepped through only when the
  rules leave it one side** (with both open the head waits for the finger
  to come round; before, the judge picked the side on the answer, which
  was help), and **a drag that strays over the body further back cuts
  nothing** -- only the square just behind the head is a step back, a
  longer cut is a press on the body. Easy to Hard drag as before.
  New lines at the end of `locale/boards.csv`: `CP_RULES_PECKISH_MOVES`,
  `CP_RULES_MOVES`, `HTP_CP_RESET_BODY_MOVES`, `HTP_CP_MOVES_BODY` (the
  shared `RULES_MOVES_SEQ` says no move is taken back, which is not true of
  a walk). The tutorial drops the HEARTS page and ends on the shared moves
  page. Not seen on a screen yet: `tests/_probe_moves.gd -- id=caterpillar`;
  `tests/_probe_cat_judge.gd` and `_shot_caterpillar.gd`'s wrong-step modes
  describe the old behaviour.

## 2026-10-13: Insane has the bulb again

What this file says of Insane having no hint (or only a video's) is history:
Insane holds as many hints as Hard on every board with a bulb, at the
user's word. `docs/agents/flat-screens.md`, "Insane has the bulb again".

### The kitchen garden is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/caterpillar_world.gd` is the card's mint
lawn with faint mown bands and a low sun at the top right, three of the
bed's tiles as stepping stones, a nibbled leaf and a clover in the gap of
the tools row, and at the foot a low fence, a soil bed of five cabbages
(one nibbled), a terracotta pot, a watering can, daisies, clovers and a
bush in each corner; six dew glints breathe. Once bled the board no
longer paints its card-shaped lawn; the bed's frame is on the host's
margin and the 180 cell cap is off (an Easy cell is 190).

- Registry: `bleed`, `level_card`; no tray, no actions row, as before.
- `opengl3_angle`, 810x1440: 87 draw calls at rest; `tests/_win.gd --
  caterpillar` passes.
- Decided for the user, unconfirmed: the larger Easy cell; the dusk of
  spent moves dimming the world too. Owed: a phone, the level slide.

## Made fun (2026-10-26)

The user: "make catterpillar experience way better to play, and game itself
way funnier to play, right now nobody likes it". Spec:
`docs/superpowers/specs/2026-10-26-caterpillar-fun-design.md`.

- **Measured first** (`tests/_probe_cat_fun.gd`, new, headless): a careful
  player -- one who sees a square a step would strand -- guessing at random
  at each turn and backing off dead ends crawled 49 squares the answer does
  not keep on a 25-square Easy, 99 on Medium, 254 on Hard (1152 on Insane's
  bank). The generator stripped leaves to the fewest that still prove one
  walk, so a day was trial and error, not reading.
- **Gardens are dealt readable** (`Gen.stuck_at`, `_make_readable`,
  `LOOK`): walking the answer, every other way the board allows at a turn
  must die (strand a square, meet a leaf out of turn or a fence) within
  `LOOK[band]` squares (3, 4, 6). Where one does not, a leaf goes 2-8
  squares on (the nearest of a shuffled reach that settles the turn), else a
  fence on a band with fences, else a leaf on the next square; then leaves
  come off again while the garden stays proved and readable, down to the
  band's floor. The look is node-capped (`LOOK_CAP`), never clocked; a
  capped look counts the way alive, so it never passes an unreadable
  garden. After: wasted 3.2 / 7.2 / 17.3 (worst 5 / 10 / 35), leaves 9.2 /
  9.8 / 12.8 (were 7.2 / 8.0 / 9.8), deal worst 14 / 43 / 77 ms;
  `_probe_cat_gen.gd` re-proves 120 deals uncapped, 0 with two walks.
  **Insane is untouched**: its Peckish gardens come from the bank, and
  Insane stays hard on purpose. Its live fallback (no bank) reads Hard's
  row, look and all.
- **The strand is shown, free, on Easy and Medium** (`_check_stuck`,
  `State.stranded_now`, `STUCK_BANDS`): the moment the body strands a
  square it washes rose with a deep-rose rim, the head worries, `strand`
  sounds and the tip says `CP_STUCK`; the squares stay rose until a cut
  frees them, then fade. Nothing is priced and nothing is refused. The
  reader counts the strand as seen, which is why Easy and Medium can be
  dealt with fewer leaves. Hard and Insane show nothing, though Hard's
  look (6) also counts a strand as seen: Hard assumes a sight it does not
  give, which is part of what makes it Hard. A call. Walking the
  answer never blushes (0 of 90 answers); 46% of legal side steps blush at
  once. New tip `CP_TIP_STUCK` on those bands.
- **The next leaf beckons** (`_draw_beckon`, `BECKON_*`): two gold rings
  ripple out of the due leaf's badge (leaf 1 before the first press), one
  cached ring mesh under a transform; steady under reduce motion; not on
  Peckish. +2 draw calls. Before the first press the board keeps redrawing
  for it (`_process`; the head's breath does that once there is a body).
- **The crawl has a sound** (`_crawl_pop`, `CRAWL_CLIMB`, `CRAWL_GAP`):
  every square grown onto is `crawl`, the wrap two steps under combo's and
  quieter, climbing a semitone a square from the last leaf, five at most,
  35 ms apart at closest; a cut is `back`, the lip, low. Both from the bank
  (`tools/gen_sfx.py caterpillar crawl back`). Heard and not felt
  (`_heard` turns Fx2D's echo off for them): the haptics rule that a walk
  knocks on its leaves, not its squares, stands. Unheard by the user.
- **A zoom** (`_zoom`, `ZOOM_*`): five squares inside 0.7 s and the head
  grins (JOY) and every other square kicks up a puff behind it.
- `tests/_shot_caterpillar.gd -- d=0 stuck` shows the blush and its fade.
  opengl3_angle at 810x1440: 88 peak in `stuck` (Easy, Medium), 105 in a
  Hard `drag`. Suite failed=0, `_win.gd -- caterpillar` PASS, the 32
  tutorial pages (four bands) play headless with no error.
- Mine, the user's to call: the look depths, the free blush on Easy and
  Medium only, the beckon, the crawl pop's level, the zoom. Not seen on a
  phone, nothing heard.
