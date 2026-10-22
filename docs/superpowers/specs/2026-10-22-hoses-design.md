# Hosepipes: a path board

2026-10-22, built unattended (the user: "start next roadmap daily puzzle, do
everything autonomous, wire animations, sounds, everything to make it fully
playable and complete like other games"). Roadmap item 11
(`docs/roadmap-next-boards.md`); items 4 and 9 wait on the user's functions
deploy and item 8 on word lists. The mock is the roadmap page's
(`docs/brainstorm/next-daily-boards.html`), so there is no concept tab, as
with the boards built before it today.

The genre it follows is the join-the-coloured-pairs path puzzle (Flow Free).
That name is used nowhere in code, comments, commits or on screen: the
board is **Hosepipes**.

## 1. The game

A raised garden bed of soil squares, seen from above, on a lawn. Each colour
has a garden tap (a valve wheel in its colour on a stone plate) and a
flower (a closed bud of its colour) on the bed. Drag a hose from either end
to the other: it follows the finger a square at a time, up, down and
sideways, and the bud opens when its hose arrives. Hoses never share a
square. **The bed is done when every flower is reached and every square is
watered** (the win is exactly what the deal proves has one answer).

- A stroke starts on an end (that hose starts again from it) or on a hose
  (cut back to that square and drawn on from it). Bare soil or a seed
  pressed is heard and nothing happens.
- Backing over the hose shortens it; a finger slid far back along it cuts
  it back to there.
- Dragging across another hose cuts it at that square, with a puff; sliding
  back off it in the same stroke grows it back. (The other hoses are always
  the stroke's start, cut at the first square the live hose holds now.)
- Another hose's tap or flower is refused (a tongue, the end shivers).
- A hose that has reached its flower goes no further.
- Every flower joined with squares still dry: the count line says so once
  ("Every flower is reached, but some squares are still dry.").

Each tap and its flower carry the same small mark (dot, triangle, square,
diamond, plus, ring, bar, chevron), so a pair is matched by shape as well as
colour. The colours are `Pal.CAT` in the order the bed takes them, the most
different first (`hoses_art.gd` `ORDER`: teal, terracotta, lavender, mustard,
sky, rose, sage, stone), so a five-hose bed never holds both terracotta and
rose. No state is told by a shade of a hose's own colour: the hose in hand
wears a cream halo at its head, a reached flower opens, a watered square's
soil turns dark.

Undo (a stroke at a time) on Easy to Hard, the bin on every band, no Check.
**The bulb** lays the first hose that is not as the answer has it, drawn out
from its tap over half a second, cutting whatever is in its way.

## 2. Bands (`puzzles/hoses_gen.gd`)

| | bed | hoses | where it is dealt | bulbs |
|---|---|---|---|---|
| Easy | 5 x 5 | 4-5 | the phone (365 days: worst 37 ms on the Mac, mean 7) | 3 |
| Medium | 6 x 6 | 5-6 | the phone (365 days: worst 134 ms, mean 27) | 2 |
| Hard | 7 x 7 | 6-7 | bank, 240 days (`content/insane/hoses_hard.json`) | 1 |
| Insane, **Seedlings** | 8 x 8 | 7-8 | bank, 225 days (`content/insane/hoses.json`) | 1 |

**Seedlings** (Insane's own rule): three taps lead to bare seeds in soil
mounds instead of flowers. A hose from one of those taps may water any seed,
and the seed blooms in its colour; the player works out which goes where.
The deal proves the bed has one answer over every assignment of seeds.

The deal: every square starts as a hose of one, and two hoses whose ends are
side by side are joined (the shortest first), never so that a hose runs
alongside itself, until the band's count is left, each at least three
squares long. The first version cut one random walk through every square
into pieces; almost every piece ran alongside itself and a 7 x 7 was proven
unique once in hundreds of tries. A bed is kept only when the solver proves
one answer. The proof is never capped by a node count (Caterpillar's
lesson); it is kept fast by pruning: every empty square needs two ways in,
every open hose a way on, and every patch of empty ground an open hose whose
head and flower both touch it. On Insane, a bed with one answer and no seeds
is tried with a few different choices of seeded hoses (a seed only loosens a
bed). Hard deals took 131 ms on average (worst 385) and Insane 1.4 s, too
slow for a phone at board open, so both are mined on the Mac
(`tools/insane/hoses_ladder.gd`, `hoses_hard_ladder.gd`, through
`tools/mine_insane.gd`) and the live deal is only the fallback.
`tests/_probe_hoses.gd` deals the live bands, re-proves every banked day
(all 465 hold, a load under 0.1 ms) and plays the state to a solve on each
band.

## 3. The screen

A bleed board (`"bleed": true`, `"tray": "none"`, `"actions": false`,
`"level_card": true`): the bed centred in the span, the count line under
it ("2 of 6 hoses joined · 38% watered").

The world (`puzzles/hoses_world.gd`): pale sky and far hills where the
host's rows lie, a white picket fence along the lawn's back, the lawn mown
in broad stripes, tufts and daisies about the bed, stepping stones off past
the foot. The bed's frame, soil, hoses, taps, flowers and seeds are
`ui/faces/hoses_art.gd`. No character: the pieces are things in a garden.

Motion: the ends pop in one after another as the board enters and on the
bin; the head's halo bumps as the hose grows; a cut puffs in the cut hose's
colour; a reached flower opens with a ring and a sparkle, and three cream
drops of water run down the hose from its tap; a refused end shivers; on
the win the flowers hop in a wave by column. Under reduce motion a flower
opens at once, no water runs, the bulb's hose is laid whole and nothing
pops, bumps, shivers or hops.

## 4. Sound and touch

Every action is a pop from the bank (`tools/gen_sfx.py` set `hoses`): `pick`
the pebble, `grow` a wrap a square (pitched up along the hose at play, so
the run rides the drag), `back` the lip, `cut` the lip twice falling, `join`
three wraps rising, `refuse` the tongue, `hush` a quiet pebble (bare soil),
`dry` the tongue twice low, `undo` the lip falling, `reset` a run of tokens
falling, `enter` a run of tokens. `hint`, `solved`, `confetti` and `party`
(every hose in one stroke, no bulb) are Market Sums' takes, copied. Nothing
was bought. Haptics: `docs/agents/haptics.md` row 28h.

## 5. Brain report

Space (the roadmap's skill; Planning is its second). Player-paced, so not
in `Brain.UNTIMED`. No `skill_quality()`: as the roadmap has it, time and
hints only, like the grid boards. Tips `BRAIN_HS_1..4`. Share line: 🌷, a
green square a hose and a bulb a hint. The win's line: "6 hoses in 8
strokes", and "Every hose in one go." when there were no more strokes than
hoses.

## 6. Decided for the user, unconfirmed

- The bands above, three seeds on Insane, and Seedlings as its rule.
- A cut hose growing back when the stroke backs off (kept: it falls out of
  keeping the stroke's start).
- A hose that has reached its flower refusing to go further.
- Undo off on Insane, as Market Sums and Domino Patio.
- The bulb laying a whole hose rather than a square.
- The pair marks on taps and flowers, and the colour order.
- The party for every hose drawn in one stroke with no bulb.

Not yet seen or heard: the sounds are unheard, pt/es unread by a speaker,
reduce motion unseen, nothing played on a phone; the JOIN, WATER and HINT
tutorial pages were not shot one by one (CUT and SEEDS were). Only Medium
was driven end to end through `_gui_input` by real touches
(`tests/_win.gd`); the other bands were played through `demo_press`/
`demo_move`, which share `_press` and `_drag` but not the input layer.
Medium's worst live deal (134 ms on the Mac) is the first thing to look at
if a phone hitches on opening it; banking it is the way out.

The SEEDS tutorial page first drew today's Insane bed from the bank, which
showed one of the day's answers; it plays a fixed bank entry now (found in
review before the merge).
