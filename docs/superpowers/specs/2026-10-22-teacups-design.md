# Teacups: a Memory board

2026-10-22, built unattended (the user: "start next roadmap daily puzzle, do
everything autonomous, wire animations, sounds, everything to make it fully
playable and complete like other games"). Roadmap item 5
(`docs/roadmap-next-boards.md`). Item 4, Four Shelves, was skipped. It rides
Golden Acorn's pipeline and is not playable until the user deploys the
functions. The mock is the roadmap page's
(`docs/brainstorm/next-daily-boards.html`), so there is no concept tab, as
with Glimpse, Birdsong and Domino Patio.

The genre it follows is the card game of turning two cards to find pairs
(Concentration, Memory). Neither name is used in code, comments, commits or
on screen: the board is **Teacups**.

## 1. The game

Cups stand upside down on their saucers across a garden tea table. Under
each is a little friend, and every friend is under two cups. Tap a cup to
lift it, then another:

- **The same friend under both** is a pair found. The two cups fly off,
  and the friends stay on their saucers with a gold ring, happy.
- **Two different friends** look worried for a moment and are covered
  again. A tap on another cup covers them at once and lifts that cup, so a
  quick player never waits.
- Every pair found solves the day.

The bulb **peeks**. With a cup in hand, its partner lifts for a second; with
none, the pair still hidden that the player has seen least of peeks out
together. **No Undo** (a cup seen cannot be unseen), **no Check** (nothing
on the table is ever wrong) and **no bin** (`can_reset()` is false: the
same table started over is a table already remembered).

A tap that does nothing still answers (no ghost touch). A cup already in
hand wiggles, a found friend hops, and a tap mid-waltz is hushed.

## 2. Bands (`puzzles/teacups_state.gd`)

| | table | pairs | bulbs | rule |
|---|---|---|---|---|
| Easy | 3 x 4 | 6 | 3 | |
| Medium | 4 x 4 | 8 | 2 | |
| Hard | 4 x 5 | 10 | 1 | |
| Insane, **Waltz** | 4 x 5 | 10 | 1 | every second miss, two hidden cups trade places |

**Waltz** (Insane's own rule, harder by memory and focus, not by a limit):
after every second miss, two hidden cups wiggle for 0.4 s and then trade
places along two arcs over 0.75 s, in plain sight. The waltz picks a cup the
player has seen when there is one, so it moves something the player is
holding. What the player saw of a cup goes with it.

The friends are dealt from the host's rng (the day's seed, per band): the
band's count of the ten, shuffled onto the places. The waltzes come from a
seed drawn off the same rng, so the day is the same for everyone.

## 3. The screen

A bleed board (`"bleed": true`, `"tray": "none"`, `"actions": false`,
`"level_card": true`). The grid stands in the span between the host's rows,
with a line under it: "3 of 8 pairs · 12 lifts".

The world (`puzzles/teacups_world.gd`): a cream sky with paper bunting, a
hedge with roses, the table's far edge with a lace hem, and a rose-and-cream
gingham cloth from there past the foot.

The cup (`ui/faces/teacup.gd`) is new: white porcelain turned over, a dome
with a foot ring on top, a band in the memory skill's blue and a gold rim.
Every cup is the same cup. The friends are **the house's own faces**:
berry, pear, pumpkin, acorn, mushroom, moon, sun, cloud, flower and leaf
(`berry_face.gd` and the rest), each a different silhouette and colour,
drawn by the board from one unparented node per friend and look
(`layers_now()`). A found pair is marked by its cups' going and a gold ring
on the saucer, never by a shade of the friend.

Motion: cups drop in place by place as the board enters; a lift rides up
1.25 cup-widths and tips the cup 0.34 rad off its friend (`back_out`); a
cup put back falls in 0.16 s and lands with a bump; a found pair's cups rise
and fade; the friends hop; on the win they hop in a wave. Under reduce
motion a cup is simply up or down: no drop-in, bump, wiggle or hop, a waltz
swaps at once and a found pair's cups are simply gone.

A miss's hold carries a token (`_hold_tok`): a tap that ends it early
leaves its queued cue and end behind, and they never touch the next miss.

## 4. Sound and touch

Every action is a pop from the bank (`tools/gen_sfx.py` set `teacups`):
`lift` the lip, `down` the token, `pair` three wraps rising, `miss` and
`hush` the tongue, `waltz` a run of wraps. `hint`, `enter`, `solved`,
`confetti` and `party` (a day with no lapse) are Domino Patio's takes,
copied. Nothing was bought. Haptics: `docs/agents/haptics.md` row 28d.

## 5. Brain report

Memory, player-paced, so **not** in `Brain.UNTIMED`. `skill_quality()` is
1 - lapses / pairs. A **lapse** is the second cup of a turn not being the
first cup's partner when that partner had already been seen before the
turn. A miss the player could not have known is luck, not a lapse. Tips
`BRAIN_TC_1..4`. Share line: ☕ and a square per pair, green when found
with no lapse since the last pair, yellow after one.

## 6. Decided for the user, unconfirmed

- The bands' numbers above, and Waltz as Insane's rule (every second miss).
- No bin.
- The bulb's two kinds of peek.
- The ten friends drawn from the house cast, and the cup's look.
- The lapse measure as the brain score, and the count line under the table.
