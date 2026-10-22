# Market Sums: a numbers board

2026-10-22, built unattended (the user: "start next roadmap daily puzzle, do
everything autonomous, wire animations, sounds, everything to make it fully
playable and complete like other games"). Roadmap item 7
(`docs/roadmap-next-boards.md`); item 4, Four Shelves, still waits on the
user's functions deploy. The mock is the roadmap page's
(`docs/brainstorm/next-daily-boards.html`), so there is no concept tab, as
with Glimpse, Birdsong, Domino Patio, Teacups and Picket Sums.

The genre it follows is the number game of reaching a target from six
numbers (the 24 game, NYT Digits). Neither name is used in code, comments,
commits or on screen: the board is **Market Sums**.

## 1. The game

Six wooden crates stand on the two shelves of a garden market stall, a
number on each, and the chalk order board under the awning names a number.
Tap a crate, a sign token (+, take away, times, share) and another crate:
the first crate slides into the second along an arc and the two are one
crate holding what they make, where the second stood. The new crate stays
picked, so a chain goes on with a sign and a crate.

- **Take away** always takes the smaller from the larger; two equal crates
  are refused (they would make nothing).
- **Share** divides the larger by the smaller and is refused unless it
  shares evenly.
- A crate past 9999 is refused (never on a shortest way).
- A refusal shivers both crates, puts the sign back and says why under the
  counter. It costs nothing.
- **A crate holding the order fills it**: the label turns leaf, the order
  board ticks, the crates hop. On Insane the order must be the last crate
  left.

When the crates on the stall can no longer make the order, the line under
the counter says so once ("Try Undo", or on Insane "Start over").

Undo on Easy to Hard (Insane keeps none, its seal), the bin on every band,
no Check: the order board says when it is filled and nothing on the stall
is ever wrong. **The bulb** makes one step of a shortest way on from the
stall as it stands, after walking back the player's steps until the order
can be made again; a hinted step is not a step taken.

## 2. Bands (`puzzles/market_gen.gd`)

| | numbers | fewest steps | order | bulbs |
|---|---|---|---|---|
| Easy | six of 1-9 | 2 | 12-60 | 3 |
| Medium | five of 1-10, one of 12/15/20/25 | 3 | 40-150 | 2 |
| Hard | four of 1-10, two of 11-25 | 4 | 100-450 | 1 |
| Insane, **Every Crate** | as Hard | 5 (all six) | 100-500 | 1 |

The order is drawn from the numbers its band's count of crates can make and
no fewer can, so the fewest steps is exactly the band's. **Every Crate**
(Insane's own rule, harder by planning, not by a limit): the order is made
from all six crates, and cannot be made from four or fewer.

The solver works by sets: for every set of the crates on the stall, every
number they make with how. Six crates are 63 sets; it runs in under 15 ms
in GDScript on the Mac, so the phone deals its own day from the host's rng
(no bank). `tests/_probe_market.gd` deals 365 days a band and has the bulb
play each from the opening: every day filled in exactly the band's fewest
(worst deal 15 ms, Insane).

## 3. The screen

A bleed board (`"bleed": true`, `"tray": "none"`, `"actions": false`,
`"level_card": true`): from the top of the span, the awning, the order
board hung under it ("Order", the number in chalk, and on Insane "use
every crate"), two shelves of three crates, the counter with the four sign
tokens, and the line "2 steps · fewest 3" under them.

The world (`puzzles/market_world.gd`): pale sky and far hills where the
host's rows lie, a rose and cream striped awning with a scalloped hem, a
plank wall, two shelves, two posts, the counter and its front boards, and
cobbles past the foot. The crates, labels, tokens and the order board are
`ui/faces/market_art.gd`; the numbers are draw_string calls, the signs'
marks are shapes. No character: the pieces are marks.

Motion: crates drop onto their shelves place by place as the board enters
and on the bin; a picked crate rides up over a sun halo; a combine slides
along an arc (`SLIDE_TIME` 0.26) and the crate it lands in bumps with a
ring; Undo is the slide backwards; a refusal shivers; the order's number
bumps as it fills and a leaf tick pops; the crates hop in a wave on the
win. On the win the signs and the count are put away and the order and
the crates fill the win's span. Under reduce motion a slide lands at once
and nothing drops, bumps, shivers or hops.

## 4. Sound and touch

Every action is a pop from the bank (`tools/gen_sfx.py` set `market`):
`pick` the pebble, `drop` the lip, `sign` the token, `make` two wraps
rising, `refuse` the tongue, `undo` the lip falling, `reset` a run of
tokens falling, `enter` a run of tokens. `hint`, `solved`, `confetti` and
`party` (the order filled in the fewest steps) are Teacups' takes, copied.
Nothing was bought. Haptics: `docs/agents/haptics.md` row 28f.

## 5. Brain report

Logic (arithmetic folds into Logic, the roadmap's call). Player-paced, so
not in `Brain.UNTIMED`. `skill_quality()` is fewest / steps taken, where
steps undone still count (the rules say so). Tips `BRAIN_MK_1..4`. Share
line: 🧺 and a square a step, green within the fewest, yellow past them.

## 6. Decided for the user, unconfirmed

- The bands' numbers and ranges above, and Every Crate as Insane's rule.
- Take away and share order-free (the larger always first), against the
  original's fixed order; 9999 as the cap.
- The new crate staying picked after a combine.
- Undo off on Insane, as Domino Patio.
- The bulb walking back lost steps before its step.
- Steps undone counting against the score.
- Showing the fewest steps on screen during play ("fewest 3").
- The bin keeps the steps taken (as Undo does): starting over counts every
  step made before it. The rules line says only that undone steps count.

Not yet seen or heard: Hard was never shot (Easy, Medium and Insane were);
the sounds are unheard, pt/es unread by a speaker, reduce motion unseen,
nothing played on a phone. `_land()` runs the solver after every combine
(4-12 ms on the Mac) to say when the way is lost: the first thing to look at
if a phone stutters on a move.
