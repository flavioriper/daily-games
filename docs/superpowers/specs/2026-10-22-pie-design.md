# Who Ate the Pie?: a deduction board

2026-10-22, built unattended (the user: "start next roadmap daily puzzle, do
everything autonomous, wire animations, sounds, everything to make it fully
playable and complete like other games"). Roadmap item 10
(`docs/roadmap-next-boards.md`); items 4 and 9 still wait on the user's
functions deploy and item 8 on licensed word lists. The mock is the roadmap
page's (`docs/brainstorm/next-daily-boards.html`), so there is no concept
tab, as with the six boards before it.

The genre it follows is the daily no-guess deduction grid (Clues by Sam).
That name is not used in code, comments, commits or on screen: the board is
**Who Ate the Pie?**

## 1. The game

Bakers stand in a grid of name cards on the bake-sale table at the village
fête, and some of them ate the pie. One baker is cleared at the start and
their clue shows. Tap a baker: the bubble under the table asks "Did Ada eat
the pie?" with two buttons, **Didn't** (leaf) and **Ate pie** (berry).

- **A mark stands only when the clues showing prove it.** A mark nothing
  proves yet is turned away for free ("The clues don't prove that yet.").
  A mark the clues prove the other way is a **slip** ("The clues say
  otherwise: a slip."), counted under the pie, and the baker stays open.
- A baker marked turns over to leaf or berry paper with a tick or a slice,
  and says their clue on the card; the bubble reads it large, and the
  bakers it speaks of ring a moment.
- Tap a marked baker to read their clue again (and ring its bakers).
- Every baker marked is the solve. Every baker speaks, whether they ate or
  not, and every clue is true.

Clues are sums over the grid: so many of a baker's neighbours (the eight
around), of a row or a column, of the bakers above, below, left or right of
a baker (anywhere in that line), on the edge, in the four corners; only one
of two bakers, neither, both; a baker ate or didn't (Easy only); more in one
row or column than another, an odd or even number in a row or column (Hard
and Insane). Rows are numbered and columns lettered on the table's edge.

No Undo (a proven mark has nothing to take back), no bin (a day started
over is a day already reasoned through), no Check. **The bulb** marks one
baker the clues already prove, the picked one if it is proven; a hinted mark
is not a slip and is not the player's move.

## 2. Bands (`puzzles/pie_gen.gd`)

| | grid | ate | dish | clues | bulbs |
|---|---|---|---|---|---|
| Easy | 3 × 3 | 3 | yes | neighbours, rows, columns, pairs, a few "X ate" | 3 |
| Medium | 3 × 4 | 4-5 | yes | + above/below/left/right, edge, corners | 2 |
| Hard | 4 × 4 | 5-7 | yes | + more-than, odd/even | 1 |
| Insane, **Empty Dish** | 4 × 5 | 6-9 | no | as Hard | 1 |

The dish (a pie in the header, a slice per baker who ate, eaten to crumbs as
each is caught) says how many ate. **Empty Dish** (Insane's own rule): the
dish holds only crumbs and nobody says how many; the clues are all there is.

**The deal is a wavefront.** Who ate is drawn, then the clues are handed out
as a player would meet them: the opening baker's, then the clues of everyone
it proves, and so on. Each round's last speaker is given a clue that proves
someone new (fewest it can on Medium and up: `want` 1; Easy `want` 2), the
others clues that prove little; a stall is a retry. Since a mark proven stays
proven as more clues show, any order of play gets through a day the deal got
through. No sentence is said twice in a day.

**The solver** (`Gen.forced`) finds one way the bakers could have eaten that
every clue (and the dish) allows, then for each open baker looks for a way
with the other verdict; a baker is proven when there is none, and two ways
prove nobody they differ on, so a grid costs a handful of searches. The
board judges every mark with the same function.

`tests/_probe_pie.gd` deals 365 days a band and replays each by the
wavefront: every day dealt (no failed deal) and every baker proven, means
3.5 / 16 / 58 / 93 ms and worst 8 / 41 / 407 / 328 ms on the Mac; a move's
proof at worst 17 ms. The phone deals its own day (no bank).

## 3. The screen

A bleed board (`"bleed": true`, `"tray": "none"`, `"actions": false`,
`"level_card": true`): from the top of the span, the pie in its dish and
"2 of 5" (or "2 of ?" on Insane) with the slips under it, the columns'
letters, the grid of cards with the rows' numbers at its left, and the
bubble.

An open card is the baker large in its middle under a cook's hat, the name
under them. A marked card is the paper of its verdict, a small face and the
name along its top and the clue over its whole width, at the largest size
that fits every clue of the day in its card. The badge sits in the top
right. The picked card wears a sun halo; the bakers a clue speaks of a thin
teal one.

The world (`puzzles/pie_world.gd`): pale sky with a string of bunting and a
far hedge where the host's rows lie, a berry gingham cloth under the cards
and the bubble, its scalloped hem, and the lawn past the foot. The pieces are
`ui/faces/pie_art.gd`; the bakers are twenty of the house's faces (berry,
pear, pumpkin, acorn, mushroom, moon, sun, cloud, flower, leaf, bee,
hedgehog, kitten, snail, sprout, conifer, oak, troll, lantern, tent), one
each, never a new drawing. Names are given names (two to a letter, a day
takes one of each and lays them in reading order), never translated.

Motion: cards drop onto the cloth place by place as the board enters; a
mark turns the card over (`FLIP_TIME` 0.32: narrows to an edge, changes
paper, opens), the badge pops, the baker hops, a ring of the verdict's
colour, and on a catch a puff of crumbs from the pie and its bump; a
refusal or a slip shivers the card and the buttons; the slips line shivers
on a slip; the cards hop in a wave on the win. On the win the bubble and the
letters go and the grid fills the win's span. Under reduce motion a card
turns at once and nothing drops, pops, hops or shivers.

## 4. Sound and touch

Every action is a pop from the bank (`tools/gen_sfx.py` set `pie`): `pick`
the pebble, `clear` the token rising, `caught` three wraps rising, `refuse`
the tongue, `slip` the tongue lower and twice, `enter` a run of tokens.
`hint`, `solved`, `confetti` and `party` (every baker proven without a slip)
are Market Sums' takes, copied. Nothing was bought. Haptics:
`docs/agents/haptics.md` row 28g.

## 5. Brain report

Logic. Player-paced, so not in `Brain.UNTIMED`. `skill_quality()` is
1 - 0.25 a slip (floor 0). Tips `BRAIN_PI_1..4`. Share line: 🥧 and a square
a mark in order, green proven, yellow the bulb's, red a slip.

## 6. Decided for the user, unconfirmed

- The bands above: grid sizes, how many ate, which clue kinds each band
  speaks, and **Empty Dish** as Insane's rule.
- Every baker speaks, the guilty too, and always truly.
- A mark nothing proves yet is refused for free; only a mark the clues prove
  wrong is a slip, and a slip leaves the baker open (the truth is not shown).
- Slips cost a quarter of the score each; the bulb costs only what every
  bulb costs in the brain score.
- "Exactly" dropped from the count sentences ("2 bakers in row 3 ate pie.")
  to fit the cards; "ate pie" / "comeu torta" / "comió pastel" throughout.
- The names (forty given names, two to a letter) and that they stay the
  same in every language.
- No Undo, no bin.

Not yet seen or heard: Hard was never shot (Easy, Medium and Insane were);
the sounds are unheard, pt/es unread by a speaker (the clues in pt/es were
never seen on a card), reduce motion unseen, nothing played on a phone. The
deal's worst (407 ms on the Mac, Hard) may be well over a second on a slow
phone: the first thing to look at if opening a level hitches; a bank like
Picket Sums' is the way out. How hard Hard and Insane feel (whether their
days need clues combined, not read one at a time) was never measured.
