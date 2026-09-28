# Posy, the Arcade tab's eighth game

2026-09-27. Built in one sitting while the user was away, from their brief:
"next arcade game is a candy crush like game [a mock titled Pixel Garden:
a day, three collect goals, moves, an 8x8 bed of flowers, leaves, drops,
mushrooms and berries, and four tools with three uses each], wire sfx sound
as well. I have to leave so do everything. Check on web for anything needed
like rules or references".

## 1. The game

**It is called Posy and nothing else** (id `posy`). The reference is *Candy
Crush Saga*, named here once to forbid it. The mock's own title, Pixel
Garden, is already the twenty-seventh board's name, so it could not be used.
The special-tile rules were checked against the genre's published guides
(the Candy Crush wikis and King's help pages):

- **Swap two neighbours; a swap that lines up three or more is taken**, one
  that lines up nothing slides back and costs nothing.
- **Four in a line leave a breeze** (the striped candy): four across leave a
  breeze down the column, four down one across the row, as the reference has
  it. **An L or a T leaves a seed bomb** (the wrapped candy): it picks the
  three by three round it, stays lit, falls, and goes off a second time.
  **Five in a line leave a rainbow posy** (the colour bomb): swapped with a
  tile it picks every tile of that kind; caught in a blast it picks the
  commonest kind.
- Pairs: breeze + breeze a cross; breeze + bomb three rows and three
  columns; bomb + bomb a five by five; rainbow + breeze or bomb turns every
  tile of the other's kind into one and sets them all off; rainbow +
  rainbow the whole bed.
- A special is left where the player moved if that cell is in the group,
  else where its lines cross, else its middle.
- A bed with no move is shuffled in place for free.

**Days** (the mock's *Dia 5*): each asks for so many of two (day 1) or three
kinds in so many moves: 12 each on day 1, four more every day to 60; 20
moves, 24 from day 5, when a sixth kind (the acorn) joins the bed. When a
day's goals are met, every move left is worth 250 and turns a tile into a
breeze, they all go off (the reference's end-of-level bonus), and the next
day is dealt with a tool as a gift. Out of moves short of the goals, the
game is over. The Arcade record keeps the best score and, as its furthest,
the day reached.

**Tools** (the mock's four, three each to start, free of a move): the
trowel digs one tile up (setting off a special), the swap trades any two
neighbours, the bomb picks a three by three, the rainbow seed turns a tile
into a rainbow posy.

Tuning (`tests/_probe_posy.gd`, 20 seeds a row): random play ends on day
4-5, the hint-follower on days 5-7, the goal-aware bot (one move of
lookahead) on days 7-12.

## 2. The screen

As the mock: the flat boards' top bar (Posy, motto *Pick the garden's
posy*), a paper row with the day, its sprout and the score, a plate per
goal (the tile, *got / need*, a green seal when done) and the moves (red
from five), the bed of cream cells in a pale frame that hugs it with hedges
and daisies round it, and the four tools under it with blue count badges.
A tile is drawn, not an image: a five-petal flower, a veined leaf, a drop,
a yellow mushroom, a plum berry, an acorn, the rainbow posy.

Input: drag a tile toward a neighbour, or tap one and then the other.
Motion: the day rolls in a column at a time; a swap slides, a refused one
slides back with a wiggle; picked tiles pop (or slide into the special they
made); the specials' breezes sweep their lines, bombs ring and shake the
bed, a rainbow throws a thread to every tile it takes; tiles the day wants
fly up into their goal plate, which counts them as they land; falls
stretch and land with a squash; cascades of 3, 5 and 7 steps earn a word;
a bed left alone five seconds shows a move; the day's end is a banner,
confetti and the bloom; the game's end tips the bed away and shows the end
card with a fan of tiles. Reduce motion drops the slides, falls, pops,
flights, wiggles and shake.

## 3. Build

- `arcade/posy_sim.gd`: the game as pure data, seeded, no clock. `swap()`
  and `use()` resolve a move at once; every cascade step is its own event
  (`swap`, `clear`, `fall`, `convert`, `shuffle`, `goal_done`, `day_done`,
  `gift`, `deal`, `over`).
- `arcade/posy_art.gd`: the tiles, the breeze and bomb overlays, the tool
  pictures and the sprout, cached per look and size; shared with the tab's
  banner.
- `arcade/posy_screen.gd`: **plays the events off a queue** and keeps its
  own picture of the bed (id -> where it is going), because the sim is a
  whole cascade ahead by the time the first step is drawn; the paper row
  follows the queue, not the sim.
- The tab card and banner, `ui/menu.gd`'s `_open_arcade`, a vista entry
  (`meadow`), locale keys `ARC_POSY_BLURB`, `ARC_BEST_DAY` and `PS_*`.
- `tests/_probe_posy.gd -- [seed] [skill 0-2] [tools 0/1] [games]`.
- `tests/_shot_posy.gd -- <outdir> [reduce]`: the tab, the deal, a swap
  dragged through the viewport, the pick, a bot's play, Swap armed, a
  rainbow made by five, a breeze and bomb pair, a day done, the next day,
  the wilt and the end card; puts `user://arcade.cfg` back (on a timeout
  too).
- Draw calls at 810x1440: 236 on the Arcade tab with eight cards, 131-151
  in play, 100-104 on the end card; ANGLE agreeing.

## 4. Sound

Twenty-six cues in `tools/gen_sfx.py`'s `posy` set, one take each: the
garden in `CARTOON` (select, swap, bad_swap, match -- pitched up the
cascade --, land, breeze, bomb, deal, shuffle, trowel, out_of_moves) and
the rest in `ARCADE` (collect, made_breeze, made_bomb, made_rainbow,
rainbow, goal, cheer, day_done, convert, gift, arm, refused, start,
game_over, new_best). Awaiting the user's listen.

## 5. Analytics

`arcade_start`, `arcade_end` (score, stage = the day, seconds, moves, made,
cascade, picked, tools, best) and `arcade_abandon`.

## 6. Polish: the rewards (2026-09-27)

The user's ask: "polish and improve design and animation of posy. The
rewards even if silly should be way more visual to keep users playing".
Screen and art only; the sim is untouched.

- **Stickers**: words lettered over everything a letter at a time
  (`_sticker`, drawn in `_air`): each letter hops in, rocks and the word
  swells away, a white rim and a dark one under the colour. Big words are
  lettered in six colours with a sunburst turning behind them: the day's
  title on the deal, *Day done!*, the cascade words (a fourth, *Unbe-leaf-
  able!*, at step 9) and *Super combo!* when two or more specials go off on
  the move's first step. A counter, *Cascade xN*, sits on the bed's top edge
  from the second step. A special made says so over its tile (*Breeze!*,
  *Seed bomb!*, *Rainbow!*); *Last move!* hangs under the moves plate;
  *Done!* under a goal plate; *A gift!* over the day's tool.
- **Bits**: petals, leaves, sparks, stars, seeds, confetti and rings, in the
  field (`_bits`) and in the air (`_air_bits`), laid into the live meshes,
  capped at 420 a layer. Every picked tile throws petals of its colour (a
  leaf throws leaves) and a ring; a made special a sunburst behind it,
  stars and a ring; a breeze sheds leaves down its line behind two comet
  heads; a bomb throws sparks, stars and seeds with two rings; a rainbow's
  threads curve and each carries a twinkle, with six coloured rings.
- **The bed flashes** on a blast, and a long cascade warms its edges with a
  glow that grows by step (Molehill's frenzy glow).
- **Goals**: a flight trails a tail of its colour and lands with petals and a
  ring; a goal met stamps its seal on (it slams in and turns), throws stars
  and leaves, and says *Done!*. The goal cue now fires on the stamp, when
  the last tile lands, not when the sim met it.
- **The day's end**: *Day done!* with one to three stars slammed in (one
  for finishing, two with a fifth of the day's moves left, three with two
  fifths), a rain of petals and confetti over the whole screen, the bed
  flashing; then **every move left is thrown from the moves plate as a gold
  star** to the tile it turns into a breeze, the plate counting down as they
  land, each worth its +250; then the gift flies from the bed to its tool
  (its badge waits for it) and lands with a burst and a *+1*.
- **At rest** the tiles breathe (a slight squash, out of phase across the
  bed); the moves pulse red from five. Score pops are coloured by the kind
  picked and the big ones wobble.
- **The end card**: a sunburst behind the posy, the score running up from
  nothing, the three stats popping in one after another, confetti every
  time (more for a new best).
- Reduce motion drops the bits, rays, hops, flights, breath and count-up;
  the stickers still appear, still.
- New keys `PS_WORD_4`, `PS_MADE_*`, `PS_CASCADE`, `PS_COMBO`,
  `PS_LAST_MOVE`, `PS_GOAL_DONE`, `PS_GIFT`. `tests/_shot_posy.gd` adds 10b
  (the stars thrown) and 10c (the gift in flight).
- Draw calls at 810x1440: 148 at the deal, 150-200 in play, ~254 at the
  peak of the day's end, 97 on the end card; ANGLE agreeing.

## 7. The genre pass (2026-09-28)

The user's ask: "check on web for same style games to see what we can do to
improve posy game", then "build them all 5". Against the genre's leaders
(Royal Match, Gardenscapes, the published deconstructions), Posy's specials
and rewards were at par; what it lacked was variety, agency and a way back
from a near miss. Five changes, sim and screen:

- **The bee** (`Sp.BEE`, Royal Match's propeller): four in a square leave a
  bee. Going off it picks the four round it and flies to the cell that does
  the day most good (`_bee_mark`: a stone, moss or weed a goal wants, then a
  tile a goal wants, then a special to set off), chosen when it goes, so it
  never flies at a tile a cascade already took. A bee swapped with a breeze
  or a bomb carries it off and sets it off at its mark; two bees send three;
  a rainbow and a bee turn every tile of the kind into bees. A line of four
  or more, or an L, still beats a square. A swap that only makes a square is
  taken (`_takes`), and the deal bans squares as it bans lines.
- **The bed's ground**, from day three, one obstacle a day in turn, taking
  one of the three goals: **weeds** under tiles (a patch grown from three
  roots; two layers from day six), pulled when the tile on them is picked;
  **stones** in the lower rows (two knocks from day seven), knocked by a
  match beside them or a blast over them; **moss**, knocked the same way,
  which creeps into a plain tile beside it after any move that left it
  alone. The moss goal is all of it (`need` is cleared plus standing).
  **Shaped beds** from day four on even days: five templates of holes.
  Tiles fall past holes, stones and moss (the genre's gaps), which keeps
  gravity a column compaction. The trowel and the bomb reach stones and
  moss.
- **Five more moves, once a game** (`Phase.OFFER`, `keep_going()`,
  `decline()`): out of moves short of the day, a card shows what each goal
  still wants and offers five more; free, no ad. `arcade_end` carries
  `more_moves` (0 or 1).
- **Tap a special to set it off**, for a move (`fire()`), when no tile is
  picked; a tap with a tile picked still swaps.
- **Pace**: a move may be made while tiles are still landing once the queue
  has caught up with the sim; a tap before then hurries everything 2.6x
  (the day's end included); later cascade steps play quicker (to 0.6x); the
  day's end and the gift wait less.

Tuning (`tests/_probe_posy.gd`, 20 seeds, tools on, before and after): random
play days 4-6 (unchanged), the hint-follower 5-7 (unchanged), the goal-aware
bot 5-12 against 7-12 (obstacle days bite a little, the offer gives some
back). Over 12 random games with taps mixed in, bees are made about as often
as rainbows and more often than breezes.

`tests/_shot_posy.gd` adds 14-22: day three's weeds, a bee made and tapped
(through the viewport) in flight, day four's stones in a shaped bed, day
five's moss before and after it creeps, the offer and the moves given. Draw
calls at 810x1440: 150-250 in play. Ten new cues (`made_bee`, `bee`,
`bee_hit`, `weed`, `stone`, `stone_break`, `moss`, `moss_clear`, `offer`,
`more_moves`), one take each, awaiting the user's listen.
