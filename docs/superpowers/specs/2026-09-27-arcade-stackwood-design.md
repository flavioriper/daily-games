# Stackwood, the Arcade tab's sixth game

2026-09-27. Built in one sitting while the user was away, from their brief:
"add a new game to arcade, [a screenshot of Stacktris 2048] stacktris like
game, wire sfx as well. have to leave so do everything".

## 1. The game

**It is called Stackwood and nothing else**, in code, in a comment or on
screen. The reference is *Stacktris 2048* (VIVERSE), named here once to
forbid it. It belongs to the drop-and-merge family (numbered blocks dropped
into columns, 2048's doubling): its screenshot showed an isometric numbered
cube falling, a gem count, a trophy and three shop items bought with gems
(a four-colour cube, a bomb, a lightning plunger). What was taken:

- Blocks numbered with powers of two fall one at a time into a shelf **five
  columns wide and seven high**. Press and slide to steer the block over a
  column; let go and it drops. **Left alone it keeps falling** (the "tris"),
  0.55 cells a second at first, +0.012 a drop, capped at 2.4.
- On landing a block **merges with every touching block of its own number**
  (left, right, below; above too after a fall), doubling once for each: two
  8s touching a landed 8 make 32. The blocks above a merged one fall into
  the gap and may merge again, **a chain**, each round worth its number times
  the chain's length.
- A column that stands higher than the shelf once the chain settles **tops
  out** and ends the game.
- The numbers dealt grow with the best block (2-4 at first, up to 64), and
  the smallest **retires** as it grows: no more 2s once 1024 is made, no 4s
  at 4096, no 8s at 16384.
- The **gems are acorns**, earned per block merged away (times the chain),
  and spent on three tools: the **rainbow block** (140) takes the falling
  block's place and on landing becomes the biggest number it touches, so it
  always merges; the **bomb** (120) takes its place and clears the 3x3
  round where it lands; the **zap** (160) clears at once every block of the
  smallest number on the shelf. A replaced block goes back to the front of
  the queue.

The Arcade record keeps the best score and, as its "furthest", the biggest
block made.

## 2. The screen

The flat boards' top bar (Stackwood, motto *Match and merge*), a paper row
with the score, the best and the next block, the shelf in the Arcade's
wooden frame, and a row under it with the acorns and the three tools. The
shelf is painted boards with a faint lane down every other column, a pale
spawn lane over a dashed rose line, a plank under it and a pot of seedlings
at either end. A block is a painted wooden toy block (a face, a darker lip
under it, a lit top edge, a grain line), one colour a number from butter
(2) round the wheel to gold (2048) and dark woods past it; the number is
lettered in Fredoka, ink or paper by the paint's luminance.

Motion: the falling block pops in, wobbles a little and stretches as it
drops; the lane lights under the finger, a ghost shows where it will land;
blocks settle into gaps; a merged-away block slides into the one it joined
and the survivor bumps; a chain says "Chain x3!" over the shelf with rays
(one at a time); 256, 512 and 1024 are a banner, 2048 and above a fanfare
with confetti; a stack one short of the line glows rose; the bomb flings
blocks spinning off the shelf, the zap strikes each one with a bolt; topping
out flings every block off and shows the card, the biggest block landing on
two smaller ones. Reduce motion drops the settle, pop, wobble, stretch,
bump, glow beat and confetti.

## 3. The Arcade tab

A sixth card does not stand one above another on a phone even with the
smallest pictures (it pushed the bar off), so `ui/menu/arcade_tab.gd`'s
`_fit` gained a last level: **two cards a row**, Play reduced to its chevron
and the "furthest" line hidden, the pictures back at their taller size when
they fit (they do at 1080x1920).

## 4. Build

- `arcade/stackwood_sim.gd`: the game as pure data at 1/60 s, seeded. The
  screen calls `aim(col)`, `drop()` and `use(tool)` and drains `events`.
  `tests/_probe_stackwood.gd -- [seed] [skill 0-2] [tools 0/1]` plays it:
  random drops top out in about a minute at ~5,600 with a 256; the greedy
  bot plays 4-10 minutes for 90k-830k with 2048-16384.
- `arcade/stackwood_art.gd`: the blocks, rainbow, bomb, zap and acorn,
  cached per look and size; shared with the tab's banner.
- `arcade/stackwood_screen.gd`, the tab card and banner, `ui/menu.gd`'s
  `_open_arcade`, a vista entry (`sky`), locale keys `ARC_STACKWOOD_BLURB`,
  `ARC_BEST_BLOCK` and `SW_*`.
- `tests/_shot_stackwood.gd -- <outdir> [reduce]` shoots the tab, the ready
  banner, a bot's play, a shelf laid by hand, a real drag through the
  viewport (printed: the column it steered to), a six-round chain, a zap, a
  bomb, a triple 1024, the topple and the end card, and puts
  `user://arcade.cfg` back.
- Draw calls at 810x1440: 194 on the Arcade tab with six cards, 60 at the
  ready, 70-114 in play (a full shelf is ~100: a mesh and two strings a
  block), 90 on the end card.

## 5. Sound

Twenty cues in `tools/gen_sfx.py`'s `stackwood` set, one take each: the
blocks in `CARTOON` wood (move, drop, land, merge -- pitched up the chain --
fuse, bomb, topple) and the rest in `ARCADE` (chain, big, milestone, wild,
buy, zap, refused, warn, retired, go, start, game over, new best). Awaiting
the user's listen.

## 6. Analytics

`arcade_start`, `arcade_end` (score, stage = the biggest block, seconds,
drops, merges, chain, tools, best) and `arcade_abandon`.
