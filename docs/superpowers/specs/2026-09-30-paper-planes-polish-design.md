# Paper Planes polish: crashes, Windy Day, rewards, motion and sound

2026-09-30, built unattended on `feat/planes-polish` (worktree
`../daily-planes`, because sibling polish sessions commit to the main checkout
the same day) at the user's word ("let's polish the paper planes game, add
more smooth animations, reinforce that the sfx sounds are really cozy, add
more visual rewards even if silly to the user to keep engagement, and make
sure the insane difficulty is really insane, with something totally new
(something only us do) that make the game nearly impossible, user can also
fail on insane and hard ... don't worry if you need to redo something on the
logic or design, as long as it keep the cozy vibe. Players are complaining
it's way too easy").

Fairy Lights', Quilt's, Mushroom Patch's and Bridges' passes the same day are
the pattern: the hearts, the dusk and the card, the streak, the gags, the
party and the seal. No concept tab: polish of a built screen with the user
away (Fairy Lights' precedent). The flat spec
(`2026-09-20-paper-planes-flat-design.md`) stands except where this says
otherwise. The calls at the end are for the user to judge on the phone.

## 0. Why it is too easy, said plainly

The board's own notes name it: **a launch only ever empties cells, so it can
never block another plane.** There is no wrong move, no Check, the greedy
solver is complete, and a refused tap costs nothing -- so the fastest way to
play is to tap everything until the sky is empty, without reading a single
lane. Three changes answer that, one per layer:

1. **A tap is judged on Hard and Insane** (section 1): tapping a blocked
   plane is a crash and costs a heart. Now you must *read* the lane before you
   tap. (The genre's own apps do exactly this with lives; it is the floor,
   not the novelty.)
2. **The boards are tighter on every band** (section 2): the carver prefers
   placements that sit in other planes' lanes, so chains are deeper and fewer
   planes are free at once.
3. **Insane breaks the one fact** (section 3): clouds that drift one step
   every time a plane takes off make the *order* matter. A launch can now
   leave the sky stuck. That is the new thing.

## 1. Hard and Insane can be failed: crashes

| band | sky | hints | hearts | undo |
|---|---|---|---|---|
| Easy (0) | 10x14 | 3 | - | yes |
| Medium (1) | 13x18 | 3 | - | yes |
| Hard (2) | 16x22 | **1** | **3** | yes |
| Insane (3) | **Windy Day** (section 3) | **0** | **2** | **no** |

- **A tap on a blocked plane** on Hard and Insane: the plane *does* take off,
  flies up its lane to the blocker (a plane or, on Insane, a cloud), **bonks**
  its nose on it (`crash`), crumples a little, and flutters back to its place
  (`flutter`) while a heart splits on the paper pill over the card
  (`heart_lost`). The blocker shivers. Nothing on the board changes, so there
  is nothing to undo. On Easy and Medium a blocked tap stays the free refusal
  it is today (lane flash, shiver, nudge, tip).
- Input, undo, hint and reset wait while the crash plays (`busy()`).
- **Undo** stays on Easy, Medium and Hard (a launch can never hurt there, so
  undo is only convenience). **Insane has no undo**: a plane in the wind
  never comes back, and undo would turn the timetable into trial and error.
- **Out of hearts**: the planes left droop, dusk falls on the card
  (`out_of_hearts`), and `ui/hud/out_of_hearts.gd` comes up with
  `PP_OUT_BODY` / `PP_OUT_REST`. Try again deals the same sky back in Reset's
  wave with every heart back (hints spent stay spent); One more heart gives a
  heart back where the board stood.
- The hearts sit on the family's paper pill in a strip over the card; the
  card gives up the room.
- Rules add `PP_RULES_HEARTS` ("only tap a plane whose way is clear") on Hard,
  `PP_RULES_WIND` on Insane; Easy and Medium say `PP_RULES_SAFE`.

## 2. Tighter skies on every band

`_carve` keeps its reverse construction (planes placed later launch earlier,
so the sky is solvable before it is drawn) but no longer takes the first head
that fits: it draws several candidate placements and keeps the one whose body
**covers the most lanes of planes already placed** (those launch later, so
each covered lane is one more plane that must wait). Measured before and
after over forty seeds a band: planes, coverage, the share of steps with two
or fewer legal launches (was 22.0 / 16.6 / 12.6 %), and the mean length of
the longest dependency chain. Target: roughly double the tight-step share on
Hard, and a longer chain on every band, without coverage falling under the
band's floor. Easy stays gentle -- it is where the rule is learnt.

## 3. Insane: Windy Day

**It is a windy day. Little clouds hang in the sky, and every time a plane
takes off, the wind blows every cloud one step downwind** (off one edge, back
in at the other). **A plane cannot fly through a cloud.** Everything else is
the same tap, the same lanes, the same win.

- **Why it is ours**: the genre's twists (seen 2026-09-30: deflectors, pause
  blocks, wrapping edges, two-way arrows, "moving items") are all about a
  single flight's path. None makes **every launch a tick of a clock** that
  moves the obstacles. That one change breaks the fact this board was built
  on: a launch can now *hurt*, because it moves the clouds into the lanes of
  the planes left. The sky can get **stuck** -- nothing can fly and nothing
  will move -- and the only way through is to plan the order: which plane
  goes now, so that the clouds stand clear of the right lane at the right
  count. It turns a scanning game into a timetable.
- **The model** (`planes_state.gd`): a board has a wind direction (east or
  west, along the rows) and a set of clouds, each one cell (a pair of
  neighbouring clouds reads as one big cloud). A cloud's cell after `k`
  launches is its start shifted `k` cells downwind, wrapping. A lane is
  clear when no plane **and no cloud at the current count** stands in it.
  Clouds sit over the sky, not in it: a plane's body may be under one.
- **Stuck**: no plane left can fly. The tip says so ("The clouds closed in")
  and the heart pill pulses: **tapping a cloud then spends a heart to blow the
  wind on one step** (`gust`) -- a count without a launch. Out of hearts while
  stuck, or out of hearts from crashes, is the card. Cloud taps do nothing
  when the sky is not stuck (no accidental heart).
- **Why it is nearly impossible**: the sky is solvable (the generator carves
  it backwards, as every band does, with the clouds' clock counted back from
  the end: the plane placed `j`-th launches `j + 1` ticks before the last,
  so its lane is kept clear of the clouds at exactly that tick), but random
  or greedy play gets stuck almost always. The miner keeps boards where a
  **random legal playout gets stuck at least 95% of the time** -- computed
  exactly over every reachable launched set rather than sampled -- and the
  greedy "launch the first free plane in reading order" play gets stuck,
  and ranks them by that chance (then by doomed states met by the exact
  search). No hints, two hearts, no undo.
- **The deal** (mined off the phone, banked in
  `content/insane/planes.json` through `tools/mine_insane.gd` with
  `tools/insane/planes_ladder.gd`): a sky small enough to plan (the miner
  picks the size where the exact search finishes and the playout gate holds:
  **10x14 with 8 clouds**, planes of 3-7 cells, section 7). The phone checks an entry
  holds together (planes in bounds, no overlap, clouds in bounds, the stored
  order replays to an empty sky) and trusts the miner for the rest. An empty
  or broken bank deals a live Windy Day sky built with its clock and
  replayed, without the gate.
- **How it looks**: soft white clouds (a few overlapping puffs, cached as one
  mesh, drawn over the planes at a little transparency so bodies read
  through), a faint dotted outline where each cloud **will** be after the
  next launch, and a wind sock on the panel's rim pointing downwind. Every
  launch the clouds glide one cell (0.35 s ease); a cloud leaving one edge
  slides out as its twin slides in at the other. A lane blocked only by a
  cloud flashes to the cloud.
- Tips lead with `PP_TIP_WIND`, `PP_TIP_WIND_2`, `PP_TIP_STUCK`,
  `PP_TIP_HEARTS`. `PP_LVL_2` "16 × 22 sky, three hearts", `PP_LVL_3`
  "Windy Day: two hearts". A Windy Day solve shares as 🌬️.

## 4. Rewards, even silly

- **The streak**: launches in a row without a refusal or crash (an undo, a
  reset or a gust ends it too). `combo` up the pentatonic from the second, the
  "x3" bubble over the launch spot, confetti at 5, 10, 20 and every 10 after.
- **A gag on a launch**, one launch in four by a hash spread evenly per day,
  one at a time: **a loop-the-loop** as it leaves the edge (`loop`); **a
  little bird** flaps after it for a moment (`tweet`); **a barrel roll**
  (`whoosh`); or **hearts** in its contrail (`love`).
- **The last few**: when three planes are left, the tip counts them down and
  each gets a little glow.
- **The party**, after the last flight: the planes that flew **come back as
  a flock**, sweep across the card in a V and loop out (`flock`); confetti
  twice (`party`); **the nap cat** hops onto the panel's foot, bats at the
  last passing plane and curls up (`purr`); on Windy Day the clouds turn gold,
  smile and drift away (`clouds`); and the sprout shares **a bit of paper
  plane wisdom**, one of twelve (`PP_CHEER_0..11`).
- **The seal**: Flawless (no hint, and no crash or gust on Hard and Insane,
  or no undo on Easy and Medium) stamps the gold seal; any Insane solve the
  night seal, "Insane" over "Flawless" or "Windy Day". `completion_record()`
  keeps `flawless` and `hearts`. `share_glyphs()` adds `🏅 Flawless` or
  `🌬️ Windy Day[ · Flawless]`. Restore shows the cat asleep and the seal.
- `win_delay()` adds the party.

## 5. Motion

New: a **press dip** (the plane sinks and shades under the finger, and
springs as it launches); an **idle flutter** (every few seconds one plane at
rest lifts its wing tip a hair -- one plane at a time, only it leaves the
still mesh); the crash's flight, bonk, crumple and flutter home; the heart
pill and its split; the clouds' glide and the wind sock's sway; the gags; the
streak bubble; the flock, the cat and the seal's drop. Under reduce motion:
no gags, confetti, idle flutter, flock or cat walk-in; the crash has no
flight (the heart splits and the blocker is ringed), the clouds jump, the
dusk and the seal stand at once.

## 6. Sound

Re-prompted toward soft paper, felt and kalimba: `launch`, `refuse`, `undo`,
`hint`, `reset`, `enter`, `solved`, `wake` (whatever the board plays today
keeps its name). New: `combo`, `confetti`, `loop`, `tweet`, `whoosh`, `love`,
`crash`, `flutter`, `heart_lost`, `gust`, `drift`, `stuck`, `out_of_hearts`,
`heart_back`, `stamp`, `party`, `flock`, `purr`, `clouds`. Rendered on
ElevenLabs (the fallback key when the first is out); **unheard** by a person.

## 7. Numbers

**The state and the deal** (2026-09-30, GDScript on this Mac, throwaway
probes not kept). *Tighter skies* (section 2), forty seeds a band, before
-> after. "Tight" is the share of steps with two or fewer legal launches
over ten random legal playouts a board; the 22.0 / 16.6 / 12.6 % recorded in
the board notes came from the flat build's Python probe and could not be
reproduced by method, so both columns here are the same probe's:

| band | planes | coverage (mean / worst) | tight | free a step | longest chain | ms a board |
|---|---|---|---|---|---|---|
| Easy | 25.4 -> 24.7 | 0.802 / 0.721 -> 0.812 / 0.736 | 14.8 -> **19.7 %** | 6.6 -> 6.2 | 4.3 -> **5.2** | 1.1 -> 2.5 |
| Medium | 37.6 -> 34.5 | 0.779 / 0.726 -> 0.781 / 0.726 | 10.0 -> **19.1 %** | 9.0 -> 7.4 | 4.9 -> **7.3** | 1.9 -> 5.9 |
| Hard | 51.8 -> 46.2 | 0.750 / 0.696 -> 0.754 / 0.722 | 7.5 -> **17.6 %** | 11.9 -> 8.7 | 5.7 -> **8.9** | 6.1 -> 20.0 |

Hard's tight share is 2.35x, every chain is longer and no board now falls
under the 0.72 floor (Hard's worst did before). The carve draws 3 / 6 / 10
placements a step (`picks`) with 1.5 / 1.0 / 0.6 of random lift (`noise`;
under 1 it only breaks ties, since the score is a whole count of lanes);
a step stops drawing after `picks * 4` draws (`DRAWS_A_PICK`), which took
Hard from 32 to 20 ms without loosening it. Medium came out as tight as
Easy by this measure; its chain (7.3) and plane count still sit between.

*Windy Day* (section 3): **10x14, 8 clouds, planes of 3-7 cells**, the
carve at 16 picks with the lane-crossed-by-clouds weight `wind_w` 1.0. Tried
and dropped: 9x12 with 6 clouds (17.8 planes, 1 in 20 passing the gate),
10x14 with 6 or 10 clouds, `wind_w` 0-5, two-cell planes (more planes but
the exact search overran its budget more often). Over 3,000 mined tries
(`godot --headless --path . --script tools/mine_insane.gd -- planes 150
3000`): 570 passed the gate (19 %), 3 overran the search budget of 400,000
launched sets, 478 ms a try per thread, **180 s wall on 8 threads**. The
bank keeps the hardest 150 (rungs 9-22, rung = floor(-log2 p)): 19-28
planes (mean 22.8), **a random playout clears at most 0.19 % of them, median
0.033 %** (stuck 99.8-99.99+ %), and greedy play sticks on every one. The
exact chance agreed with 400 sampled playouts on every seed checked (seed
5: 90.5 % stuck sampled against 87.7 % exact; seed 9: 50.2 % against
52.4 %). The phone's check of a banked sky
(`from_bank`, replay included) costs 0.27 ms; the exact search a hint would
use took at most 75 ms from a sky one launch in. The live fallback carves in
about 8 ms and is not gated. The whole bank is 276 KB.

**Decisions off the spec**: the Windy Day sky is carved backwards with the
clock counted from the end, not forwards; the playout gate is the exact
probability, not 400 samples; a gust is refused by the state unless the sky
is stuck (so no board bug can spend a heart on a free sky); undo stays in the
state on Insane (Reset flies planes home through it) and `undo_allowed` is
what the board offers.

**The board** (2026-09-30, `tests/_shot_planes.gd` at `--resolution
810x1440 --always-on-top`, peak draw calls from 0.5 s on, each state run
twice and the second quoted; both readings agreed on every state). This
harness opens the board through `world/main.tscn` with the day card's art
behind it, so its floor is **77** on Easy at rest -- the pre-polish board
read **77** under the same harness the same afternoon (stashed and re-run),
so the 53 in the board notes is `tests/_shot_anim.gd`'s figure on a bare
host and not a regression:

| state | band | peak draw calls | mean ms |
|---|---|---|---|
| rest | Easy / Medium / Hard / Insane | 77 / 77 / 78 / **83** | 4.1-4.3 |
| press (dip, launch) | Easy / Insane (with the glide) | 78 / 84 | 5.6 / 6.3 |
| refuse | Easy | 77 | 4.8 |
| crash (a plane) | Hard / Insane | 79 / 84 | 8.7 / 7.5 |
| crash (a cloud) | Insane | 84 | 7.2 |
| out (droop, dusk, card, Try again) | Hard / Insane | 100 / **104** | 6.0 / 4.8 |
| stuck | Insane | 88 | 9.1 |
| gust | Insane | 88 | 7.2 |
| solve (stored order, tap by tap) | Insane | 88 | 10.3 |
| restore | Hard | 78 | 4.4 |

The peak is the out-of-hearts card over Windy Day at **104**, 751 under the
855 budget. Windy Day costs **+6 at rest** (eight clouds under a transform
each, one ghost mesh, the sock; a cloud wrapping draws twice, so +5 more
mid-glide at most) and the hearts' pill +1. On the phone's driver
(`--rendering-driver opengl3_angle`) Windy Day at rest reads the same 83
and draws the same picture. The cells: the hearts' strip takes 64 off the
top on Hard and Insane, which leaves Hard width-bound at **59** (the card
measured 1000 x 1480 in this harness) and Insane at **94**.

The suite is green (`passed=123188 failed=0`) and `tests/_win.gd -- planes`
passes (Medium, 31 planes, the hint on the last); `_win.gd` now plays a
Windy Day sky in `solve_order()` and skips the hint on a band with none, and
`_shot_planes.gd solve` cleared a banked Insane sky tap by tap through the
board's input with both hearts kept.

## 8. Calls for the user

Decisions the build made while you were away -- each is one constant or a
few lines to change:

- **The last heart can buy a gust.** A crash that spends the last heart is
  the card (as on every family board), but a gust that spends it is not: the
  wind blows, and only a sky stuck again with no heart, or a crash with none,
  ends it. Otherwise One more heart on a stuck sky would be gone before it
  could be used.
- **A plane launches when the finger lifts**, not on the press (Fairy
  Lights' input rules): a stray thumb can no longer cost a heart, and a
  finger that slides off launches nothing. It is a hair slower to play fast.
- **A tap through a cloud goes to the plane under it**; only a stuck sky
  turns a cloud into a button.
- **The press shades a plane** (all three papers darken alike for a moment)
  and the **droop** dims every plane left: neither tells one plane from
  another, so the colour stays identity.
- The hearts' strip costs the grid 64 px of height (Quilt's), and the wind
  sock stands at the panel's upwind top corner beside the pill.
- Cloud opacity 0.8, ghost rings at 0.42, glide 0.35 s, crash 13 cells/s
  with a 0.16 s bonk and a 0.55 s flutter home -- all judged on stills only.
- The how-to-play lesson was wrong (a triangle sliding diagonally under
  "draw each plane from its head"); it now shows the tap.
