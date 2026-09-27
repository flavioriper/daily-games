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
