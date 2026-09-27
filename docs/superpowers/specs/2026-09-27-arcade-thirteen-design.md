# Lucky Thirteen, the Arcade tab's seventh game

2026-09-27. Built in one sitting while the user was away, from their brief:
"next arcade game is a impossible 13 game [a screenshot of it on VIVERSE],
wire sfx sound as well. I have to leave so do everything. Check on web for
anything needed like rules or references".

## 1. The game

**It is called Lucky Thirteen and nothing else**, in code, in a comment or on
screen (id `thirteen`). The reference is *Impossible 13* (Robowhale; played on
Poki, Lagged and VIVERSE), named here once to forbid it. The rules were read
off its store pages (Poki, Lagged, SEELE, Gogy); the playable build would not
get past its pre-roll, so nothing here was measured off the real game.
What was taken:

- Numbered circles in a grid. **Drag a chain through three or more touching
  circles of one number** -- horizontally, vertically or diagonally, no
  circle twice -- and they merge **into the last one, one number higher**.
  Dragging back onto the circle before the last takes the last one off.
- The circles above the gaps fall; new ones drop in at the top.
- **The game ends when no three touching circles share a number.** The aim is
  13. The pages quote 79.56% of players reaching 9 in a first game and 0.56%
  reaching 13.
- Coins for reaching numbers, spent on boosters. The screenshot shows five
  (a magnet, a circular arrow, a cross, a sort and an upgrade); the pages
  mention restarting and removing a chosen number. Their exact effects are
  not documented, so the five here are our own.

Our tray is **5 across and 6 down** (the screenshot's is 4 by 5), because a
phone's board card has the room and 4 by 5 grinds; the difficulty is tuned
by the spawn window instead.

- The opening tray is ones and twos with a few threes (45/40/15), redealt
  until it has a move.
- A pebble rolling in carries a number from `max - 6` to `max - 2` (never
  under 1, the top never under 3), the small ones likelier. The next big
  number is never handed out: every 13 is made.
- Points: the new number x the pebbles in the chain x 10.
- **Clovers** (the coins): 20 to start, one a pebble past the fifth in a
  chain, and each new biggest number's own worth (a 13 is worth 50).
- **Tools**, prices rising by half their base with every purchase in a game
  (`cost()`), so rescues run dear: **Undo** 25 (the last move, the tray's
  random state included, so a refill cannot be re-rolled), **Swap** 40 (any
  two pebbles of different numbers), **Pluck** 30 (take one out; the column
  falls and refills), **Shuffle** 50 (every pebble, until a move exists),
  **Lift** 80 (one pebble a number up, never the biggest number, so it is
  never a shortcut to 13).
- **Stuck**: a tray with no move while a tool is affordable waits, saying so,
  with an End game button; with nothing affordable it is over. 13 is not the
  end: play goes on to 14 and past.

Tuning (`tests/_probe_thirteen.gd`, 40 seeds a row): random play with tools
reaches 9 in 65% of games and 13 in 2%; the careful bot (one move of
lookahead, every group and end) reaches 13 in 30% without tools and in every
game with them, over ~3,000 moves. The reference's own curve is 80% / 0.56%
for people.

The Arcade record keeps the best score and, as its "furthest", the biggest
number made.

## 2. The screen

The flat boards' top bar (Lucky Thirteen, motto *Make a thirteen*), a paper
row with the score, the best and the biggest pebble so far, the tray in the
Arcade's wooden frame, and a row under it with the clovers and the five
tools. The tray is raked sand with a hollow under every pebble, moss and
daisies in its corners and sunlight across it. A pebble is a painted river
stone slightly out of round (its own way for each number), a darker
underside, a lit crown, speckles and a sheen, one colour a number: 1 rose
and 2 sky as the reference has them, round the wheel to 12's deep teal, 13
gold with a four-leaf clover, dark stones past it.

Motion: the opening tray rolls in a column at a time; a picked pebble lifts
with a halo and hops, a ribbon in its paint joins the chain, the pebbles it
cannot take step back, and from three a gold ring and a little pebble of the
number to come sit on the last one; letting go rolls every pebble along the
chain into the last, which gulps, flashes a ring and puffs; the gaps fall
under gravity and land with a squash; new numbers of 7 and up are a banner,
13 a fanfare with confetti; clovers fly into the bank; a tray left alone
seven seconds breathes a move. Pluck flings the pebble out, Shuffle shakes
the tray, Lift sparkles. The end tumbles every pebble out and shows the
biggest landing between the two below it. Reduce motion drops the roll-in,
hop, fall, squash, gulp, shake, breathing, flight and confetti.

## 3. Build

- `arcade/thirteen_sim.gd`: the game as pure data, seeded, no clock (a move
  resolves at once). The screen calls `begin()`, `extend()`, `commit()`,
  `use()` and `give_up()` and drains `events`; `hint()` and
  `chain_through()` (a bounded depth-first search for the longest chain
  ending on a pebble) serve the idle hint and the bot.
- `arcade/thirteen_art.gd`: pebbles, halos, the clover and the tool
  pictures, cached per look and size; shared with the tab's banner.
- `arcade/thirteen_screen.gd`, the tab card and banner, `ui/menu.gd`'s
  `_open_arcade`, a vista entry (`beach`), locale keys
  `ARC_THIRTEEN_BLURB`, `ARC_BEST_NUMBER` and `LT_*`.
- `tests/_probe_thirteen.gd -- [seed] [skill 0-2] [tools 0/1] [games]`.
- `tests/_shot_thirteen.gd -- <outdir> [reduce]` shoots the tab, the
  roll-in, a chain drawn by a real drag through the viewport (printed: the
  chain the screen took), the merge, a bot's play, Swap armed, a chain of
  twelves made into the 13, a stuck tray, the tumble and the end card, and
  puts `user://arcade.cfg` back.
- Draw calls at 810x1440: 216 on the Arcade tab with seven cards (the
  seventh alone on the fourth row), 125-137 in play, ~148 on the 13's
  fanfare, 96-99 on the end card; ANGLE agreeing.

## 4. Sound

Nineteen cues in `tools/gen_sfx.py`'s `thirteen` set, one take each: the
pebbles in `CARTOON` stone (select -- pitched up the chain --, unselect,
merge -- pitched up the numbers --, land, swap, pluck, shuffle, tumble) and
the rest in `ARCADE` (short, new_number, goal, stuck, arm, undo, lift,
refused, start, game_over, new_best). Awaiting the user's listen.

## 5. Analytics

`arcade_start`, `arcade_end` (score, stage = the biggest number, seconds,
moves, merges, chain, tools, reached = a 13 was made, best) and
`arcade_abandon`.

## 6. Polish (2026-09-27, amendment)

Screen and art only; the sim is untouched.

- **Pebbles dress up as they grow**: a painted band from 5, a second from 9,
  gold flecks from 10, and a rim light on every stone. Now and then a pebble
  at rest glints (a twinkle over its sheen; a 13 glints more often) and
  another gives a small wiggle.
- **The chain is held up off the sand**: its pebbles lift, their shadows and a
  glow stay on the sand, the newest hops and the rest bob in a wave down the
  chain. Beads of light flow along the ribbon toward its end (gold from five
  pebbles), the end's sun ring breathes, a dotted tether runs from the last
  pebble to the finger, and the number to come grows and wobbles as the
  chain lengthens. Letting go drops every pebble back with a squash; a pebble
  dragged back off the chain squashes as it drops.
- **The merge**: the rolling pebbles keep their numbers and leave a fading
  trail in their paint; the pebbles round the merge are knocked outward and
  rock back; a falling pebble stretches with its speed.
- **A new biggest number from 7 up is a reveal**: the pebble rises out of its
  merge to the middle of the tray, big, over a turning sunburst (gold for the
  13, whose line is lettered under it, fitted to the tray), then flies up
  into the Biggest plate, which keeps the old number until it lands. The
  13's fanfare and confetti land with the merge. Reduce motion keeps the old
  text banner.
- **Words sit on paper**: a tool's instruction or a refusal is a paper pill
  over the tray (it used to be white lettering over the pebbles and wrapped
  badly in pt-BR); the stuck tray is a paper card with the line and End game,
  shown only once the tray has settled and any reveal or banner has gone,
  while the tools the bank can buy nudge now and then. Its line does not
  autowrap: a wrapped label shown before its first layout measured the card
  hundreds of pixels tall.
- **An armed tool rings the pebbles it may be used on** (Swap, after its
  first pick, the pebbles of other numbers).
- The bed has a few scallop shells and grit between the hollows.

Draw calls at 810x1440: 125-135 in play, ~143 on the 13's reveal, 99-100 on
the end card; reduce motion drops the reveal, glints, wiggles, bob, tether
flow and knocks.
