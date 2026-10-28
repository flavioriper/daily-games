# Hedgehogs

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Hedgehogs is the twenty-fourth card** (2026-09-26,
  `puzzles/hedgehogs2d.gd`, spec `2026-09-26-hedgehogs-flat-design.md`, mock
  `docs/brainstorm/concepts.html#hedgehogs`). Rake an autumn lawn's leaf
  piles; a number counts the hedgehogs asleep in the eight cells round it,
  a nought blows its neighbours clear, and a wrong rake only wakes one up
  grumpy (`woken`, on the win screen and the share line). It is the
  dig-and-flag game Mushroom Patch was drawn *away* from, off the same
  reference; **it is called Hedgehogs**. Two things travel: **a proof that
  plays the day out from its opening is also its uniqueness** --
  `hedgehogs_gen.gd`'s `prove` rakes every bare cell by singles, subsets and
  the count, never guessing, so no separate second-answer search is asked --
  and **a board whose moves all resolve in the state at once needs no input
  lock**: every cell carries its own gust timers, so a tap mid-gust is taken
  and the drawing still lands on the state. Its drawings are
  `ui/faces/leaf_pile.gd` (shared with the tray and the card) and
  `ui/faces/hedgehog_face.gd`. 79 draw calls bare, 80 raked, 83 with one
  woken and 115 on the win wave, ANGLE agreeing.
  Sounds generated (2026-09-26), one take a cue, awaiting the user's listen.
  **Polished on 2026-09-26** (the spec's section 11): an autumn lawn with a
  wooden bed round the grid, heaped piles of almond, maple and oak leaves, a
  flag that drops in and presses its pile down, a rake pulled across each
  raked cell, leaves that spiral off and settle, wind streaks on a big flood,
  a breeze through one row at a time, a woken hedgehog that peeks, and a win
  where the sleepers stretch, yawn and hop under a swirl of leaves. The
  still mesh is cut into bands of three rows rebuilt only when a cell's look
  changes. 84 bare, 85 played, 119 on the win, ANGLE agreeing.
- **Polished again on 2026-10-01** (unattended, spec
  `2026-10-01-hedgehogs-polish-design.md`): Hard (3 hearts) and Insane (2)
  can be failed -- a wake costs a heart, out of hearts is dusk and the card.
  **Insane is Sleepwalkers**: every third rake the moon's bell rings and one
  sleeping hedgehog not under a flag steps to a covered pile beside it; the
  two piles rustle alike (never the direction) and wear paw prints. A walk
  is taken only if `Gen.prove_from` still plays the lawn out from what the
  player can see, so whatever the rake order there is never a forced guess
  (`tests/_probe_hh_walk.gd`). **The numbers drawn are `_num_view`, a copy**
  synced after each gesture except one that rang the bell -- read it, not
  `g.num`, or a walk's new counts show before its rustle. No tidy-row reward:
  it would leak that the row's covered piles are hedgehogs. HARVEST sound
  set (unheard). Peak 138 draw calls (party), ANGLE agreeing.
- **Checkup on 2026-10-02** (`docs/agents/checkup.md`, row 24). The bands
  stay, but nothing on a cell is drawn in script while it plays: every
  cell's ground, pile at rest, pile pressed under a flag and mound-and-rim
  are looks made once at a reference cell (`_make_look`, ids `Look * 4096 +
  cell`), each leaf kind a look painted through two slots, the flag a look
  painted `Lawn.flag_inks()`. A band is a `RunMesh` with a run a cell
  (ground + pile + 64), its flags, pins and paws on the tail; the live mesh
  is a `RunMesh` with no runs, moving cells sorted latest-settling first.
  Both are built in the reference layout's space (`_into_ref`) and drawn
  under `_relay()`; a new deal (`build`) takes the reference afresh, the win
  card's relayout keeps it. `ui/faces/leaf_pile.gd` gained `leaves()` (a
  pile's leaves as data, which `pile()` now draws), `back()` and
  `flag_inks()`; its drawings are byte-identical. `build()` is split so
  `_dealt()` can start a hand-made lawn (the tutorial's `Board.lay`), and
  `_pad()` / `_hearts_at()` are layout hooks the tutorial overrides. The
  bell's walk proof still runs inside the third rake's tap (~1-2.5 ms on this
  Mac). The tutorial (`ui/hud/hedgehogs_tutorial_diagram.gd`) plays one 5x4
  lawn (hedgehogs under 11, 12, 19, opening from 9) whose walk seed
  2310537765 makes the board's own walk, after rakes 10, 15, 16 with 11 and
  12 flagged, send 19 to 18 -- found by a throwaway search over seeds; a
  change to `State.walk()`'s order would need a new seed.

- **Insane counts moves** (2026-10-04, `docs/agents/flat-screens.md`,
  "Insane counts moves"). `State.HEARTS_BY` is `[0, 0, 0, 0]`: a wake is
  Medium's on every band (the hedgehog shown on its rose patch, the day
  going on). Sleepwalkers hands out **one move for every bare pile the
  opening left covered, + 3** (`State.to_clear`, `moves_budget()`; 63 to 77
  over 25 nights), and **every pile cleared costs one**: raked by hand,
  blown off by a nought, raked round a number. A hedgehog raked awake costs
  one and clears nothing, so three wakes are the slack; flags are free. It
  is the placing boards' formula, a flood priced like a Nonogram stroke, tile
  by tile. **Counting gestures or hand-raked piles was tried and dropped**:
  the walks move the noughts, so the same night played by logic alone in
  eight orders cost anywhere from 0.7 to 1.8 of the dealt lawn's own proof,
  and any budget off it was either unfair or never reached. Piles cleared
  is the one count a walk cannot change (it is between covered piles), so a
  clean night costs exactly `to_clear` in any order (75 plays checked). A
  flood bigger than the moves left is taken whole and the count stops at
  nought. `max_moves` is set in `build()` only: the tutorial's lawns come in
  through `_dealt()` and count nothing. No Undo (it was greyed), hint or
  Check; Reset hands the budget back. New lines: `HH_RULES_WALKERS_MOVES`,
  `HTP_HH_WOKE_BODY_MOVES`, `HTP_HH_RESET_BODY_MOVES`, `HH_MOVES_BACK`.

### The raking-day garden is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/hedgehogs_world.gd` is cream air turning
into the card's lawn with faint mown bands, a washing line with three
pegged things in the gap of the tools row, a drift of leaves and acorns
under the bed (`set_foot(y)`), a wheelbarrow of leaves left of the
tray's chips and a wicker basket with the rake leant on it at their
right, tufts and toadstools along the foot; six motes breathe. Once bled
the board's lawn mesh keeps only the wooden bed and its soil. The lawns
are taller than wide, so height binds and the bed stands centred inside
the margin; 96 is kept open under it for the drift.

- Registry: `bleed`, `level_card`, no actions row, and **the tray
  stays** (`"tray": "lawn"`). **Check is gone**: the lawn solves itself.
- `opengl3_angle`, 810x1440: 91 draw calls at rest; `tests/_win.gd --
  hedgehogs` passes.
- Decided for the user, unconfirmed: the tray kept, no Check, the 96 of
  drift, the tally on bare lawn. Owed: a phone, the level slide.

### Made fun (2026-10-28)

The user: "make hedgehogs experience way better to play, and game itself
way funnier to play, right now nobody likes it", autonomous, push when
done. References: the classic dig-and-flag game's mobile apps (tap a number
to chord, flag controls the most argued-over thing on a phone, no-guess
boards) and a fourteen-variant game of the same genre (numbers that can no longer matter dim,
a hint that lights the cell, the clues and the reason and leaves the
deduction to you). The name of the original stays out of everything else.

**Measured first** (`tests/_probe_hh_fun.gd`, headless, 40 nights a band):

| | Easy | Medium | Hard | Insane |
|---|---|---|---|---|
| a reader of one number at a time stalls | 2/40 | 4/40 | **40/40, 47 bare piles left** | **40/40, 46 left** |
| nights the opening's first reading decided <= 1 pile | 2 | 3 | 14 | 9 |
| taps, a pile a tap -> numbers first (both chords) | 35.6 -> 26.4 | 49.4 -> 34.7 | 65.7 -> 45.8 | 70.8 -> 49.8 |
| raked numbers already spent at half way | 22% | 38% | 46% | 52% |

On Hard one night in four needed a pair of numbers read together straight
after the opening, and most before half way: a player who did not know the
pattern met a wall and guessed (a wake is free), which is the board telling
them nothing.

**What changed:**

- **Deals warm up** (`Gen._warm`, `BANDS[].late`, `FIRST_READ`): the
  opening's first reading decides at least two piles on every band, and a
  reader of single numbers gets at least half way on Hard (`late` 0.5) and a
  fifth on Insane (0.8) before the first pair is needed. After: the stall
  leaves 14.8 bare piles on Hard (47.1 before), 26.6 on Insane; no night
  opens on one pile. Deals stay the same wherever the first accepted lawn
  already passed. Generation: Hard 17 ms mean, Insane 33 ms mean, worst 311
  attempts of 400 (one fallback in 40 at 0.65, none at 0.8).
- **A number taps both ways** (`State.chord`, kind `"flagged"`): a raked
  number whose covered unflagged piles are exactly the hedgehogs it still
  needs flags them all in one tap (pennants a FLAG_STEP apart, one undo
  step). Decided off the player's own flags and the shown number, like the
  rake chord. Flags only, so it never rings Sleepwalkers' bell.
- **Spent numbers fade** to SPENT_ALPHA (`_is_spent`, `_spent_level`): no
  covered unflagged pile round it, read off raked/flags/woken, never the
  hedgehogs (a wrong flag dims a number just as a right one does). A
  solved lawn brings every number back.
- **Hold a number** and its covered piles wash in sun (`_draw_light`, one
  cached mesh); the tap fires on the release, so a finger slid off does
  nothing. The long press is now covered piles only (it used to chord a
  number at 0.4 s).
- **The bulb teaches in two presses** (`State.hint_step` now explains:
  `cells`, `why`, `rule` single/pair/count, `need`; `_why_line`): the first
  press, one hint, rings the numbers it reads (a sun disc under each), rims
  the piles they decide and says why on the toast for WHY_HOLD (HH_WHY_*).
  The player may do it themselves; a second press while it stands plays it
  all, free (`hints_left()` counts the reading, `hints_held()` is the
  badge). On Sleepwalkers a reading of bare piles is played one pile a
  press (a rake may ring the bell, whose walk must land before the next
  rake, or `_num_view` takes the walked counts early); it stands, free,
  till done. A walk, Undo or Reset puts the reading out. The tutorial's hint
  page lights, then plays (HTP_HH_HINT_CAP).
- **Live stars** on the tally (`ui/flat/star_line.gd`, `_rate`): three with
  nobody woken, two with one, one with more; `woken` is the day's tally, so
  Reset never wins one back. No failing comes back (the user took hearts
  and limits out on 2026-10-04 and 2026-10-12).
- **Lines that reached nobody now toast**: the opening tip (a number is a
  button, `HH_TIP_TAP_NUMBER`; Insane says the bell), Whoosh, every walk,
  the bell with nobody walking. `_cycle_tip` reads the band's own tips. The
  toast always lies under the bed (a two-line reason lies over the tray's
  top), never over a pile.

Draw calls on opengl3_angle, 810x1440: Hard mid-play 100-102 with the
light, Insane solve peak 213 (212 before, the party). Suite 303252/0;
`_win.gd -- hedgehogs` PASS; `_probe_hh_walk.gd` 0 bad. New harness modes
`fun` and `pair` in `tests/_shot_hedgehogs.gd`.

Decided for the user, unconfirmed: the warm-up thresholds, the second
press free, stars by wakes (hints free), SPENT_ALPHA 0.32, the toast over
the tray's top. Sleepwalkers kept as designed. Owed: a phone, the pt/es
wording by a reader, no new sounds.
