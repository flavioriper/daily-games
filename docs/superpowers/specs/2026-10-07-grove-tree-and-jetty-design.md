# The Grove's tree, its jetty and four skills

2026-10-07. Designed with the user in chat from a look at the reference's
own tree (the reference is named once, in
`2026-10-05-valley-grove-design.md`, and nowhere else: not here, not in code,
comments, commits or on screen). What the user said is quoted; the rest was
proposed in chat and built when the user said "all good, build it all".

This reverses two lines of the first spec's section 6: "six tiles, not a
skill tree" and "no automation yet".

## 1. What changes

"On grove game, we gotta create a skills tree." Three things, built in this
order, each leaving the game playable:

1. **The tree.** The shop keeps the axe (Axe, Reach, Swing). Sprout, Room
   and Seeds leave it for a tree drawn as a tree: Seeds is its trunk, every
   kind of tree has two boughs of its own, and four roots hold what is not
   about one kind.
2. **The jetty.** "We need to also add the pick wood to pack and send, since
   it's gonna be shared with other resources, we need to send to storage so
   the pack and deliver should also become a bottleneck to user." A felled
   tree's wood lies where it fell; the circle gathers it to a jetty; there
   it is tied into bundles and a raft takes them away, and only then is it
   wood in `Stock`.
3. **Four skills**, each a root's nodes: a beaver of its own, critical
   chops, lucky wood, crates.

Energy pays for everything ("Energy, like the shop"), the Grove's own number
as before. Nothing here spends wood.

## 2. What the reference's tree taught

Read off its one published tree screen and its players' reviews:

- A lattice of square nodes, a trunk of general nodes, a section a kind of
  tree, each section the same few nodes. Kept: sections by kind.
- A node has levels, and its card says before and after, the level and the
  price. Kept.
- One level in a node opens its neighbours. Kept.
- **Steps nobody felt** ("2560 to 2561 for a huge investment"). Here no
  level is worth less than 5% or one whole unit.
- **Skills nobody understood** (the clover, in five reviews). Here every
  chance says its figure on its node, and the land shows it when it happens.
- **Text too small.** A node carries a picture and a level; the words are on
  a card at the foot, at the shop's sizes.
- **"No significant decisions anywhere."** Energy is one purse for the shop
  and the tree, and a kind's boughs are worth nothing once the kind has left
  the land.
- **It ends when the tree fills.** Here the trunk has no top.

## 3. The tree (`valley/grove_sim.gd`, `valley/grove_tree.gd`)

### Shape

Tall, for a phone, and drawn as a tree: **the trunk** runs up the middle, a
node a kind of tree (Sapling at the foot, then Birch, Oak, Pine, Blossom,
Birch II and on for ever). **Two boughs** leave each trunk node, Soft to its
left and Rich to its right. **Four roots** go down from the foot, a column
each: Land, Jetty, Beavers, Fortune, in that order from the left.

### Rules

- A node has a level, from 0. `cost`, `can_buy`, `buy`, `is_done`,
  `last_level` take a node's id as they took a tile's; the three shop tiles
  are ids like any other.
- **A node is open when the node before it has a level** (or it has one
  itself, which is how a kept grove's Sprout stays bought whatever Room is).
  The first node of each root and the Sapling's boughs are open from the
  start.
- **What is drawn**: every node with a level and every open node. Nothing
  past them. A node the energy reaches wears the sun button's rim; one it
  does not, paper and dim figures; one with no level left, a leaf and a tick.
- Ids: `room`, `sprout`, `jetty`, `tying`, `bundle`, `raft`, `load`,
  `beaver`, `teeth`, `crit`, `critsize`, `luck`, `crate`, `cratesize`;
  `kind:N`, `soft:N`, `rich:N` for tier N.

### The trunk and the boughs

The trunk is Seeds: `kind:N` (N from 1) is bought when `kind:N-1` is, costs
what Seeds cost (120, x7 a kind) and sets `lv.seeds` to N. `kind:0` is
owned. A kept grove's Seeds level is its trunk.

With P the kind's own price (20 for the Sapling):

| Bough | Each level | Levels | Energy |
|---|---|---|---|
| Soft (left) | that kind takes a quarter fewer chops | 2 | 0.5 P, 1.5 P |
| Rich (right) | that kind gives half as much again, wood and energy (the Sapling: twice) | 2 (the Sapling: 1) | 0.75 P, 2.25 P (the Sapling: 1.5 P) |

`Sim.hp_of(tier)` and `Sim.give_of(tier)` stay what a kind is before its
boughs; `sim.hp(tier)` and `sim.give(tier)` are what it is now. Buying Soft
takes standing trees of that kind down to their new most.

**A kind that no longer comes up** (the land grows the best kind and the two
under it) keeps its boughs' levels, but they cannot be bought any more:
`sim.grows(tier)`. Its three nodes are drawn faded and the foot card says it
no longer grows here, so nobody pays for a bough that does nothing.

A new kind still asks 2.6 times the chops for twice the yield, and comes
with bare boughs, so the first spec's race goes on: Seeds helps once the axe
has caught up, and now once the new kind's boughs are bought.

### The roots

| Root | Node | id | Each level | Start | Last | Energy |
|---|---|---|---|---|---|---|
| Land | Room | `room` | one more tree | 3 | 27 | 12, x1.5 |
| Land | Sprout | `sprout` | trees 7% sooner | 6 s | 20 | 15, x1.65 |
| Jetty | Raft | `raft` | there and back 8% sooner | 12 s | 15 | 50, x1.7 |
| Jetty | Jetty | `jetty` | room for 3 more piles | 8 | 20 | 20, x1.45 |
| Jetty | Bundle | `bundle` | one more pile a bundle | 4 | 7 | 60, x2.2 |
| Jetty | Tying | `tying` | a bundle 10% sooner | 6 s | 15 | 40, x1.7 |
| Jetty | Load | `load` | one more bundle aboard | 1 | 3 | 300, x3 |
| Beavers | Beavers | `beaver` | one more beaver | none | 5 | 250, x4 |
| Beavers | Teeth | `teeth` | a bite 10 points nearer a chop | 50% of a chop | 5 | 500, x2.4 |
| Fortune | Keen edge | `crit` | 5 points more chance of a keen chop | 0% | 10 | 80, x1.8 |
| Fortune | Heavy blow | `critsize` | a keen chop counts half a chop more | 2 chops | 6 | 150, x2 |
| Fortune | Lucky wood | `luck` | 4 points more chance of a double pile | 0% | 10 | 100, x1.8 |
| Fortune | Crates | `crate` | the first: a crate every 180 s; then 10% sooner | none | 10 | 200, x1.9 |
| Fortune | Full crates | `cratesize` | a crate holds a fifth more | 15 of the best tree | 10 | 250, x1.9 |

Room and Sprout keep the prices and the last levels they had as tiles, and a
kept grove keeps its levels of both. Each root is a chain in the order
written.

### The card

A second button beside Shop, on the left (the thumb that chops rests on the
right): **Skills** (`tree` icon), its badge the number of nodes the energy
reaches. It opens a card over the grove as the shop does (the same head: the
energy on a pill, a round X; the scrim, the X and Android's back close it;
the grove goes on behind, nothing is chopped).

- The tree is drawn on a field that **pans up and down under a finger**
  (`ScreenTouch` / `ScreenDrag`, and the mouse on a desktop). It opens with
  the foot in the lower third: the roots under a line of soil, the trunk
  rising out of it.
- **A tap on a node chooses it**, and a card along the foot says its name,
  what it is now and what the next level makes it ("every 6.0 s, then 5.6":
  the fonts carry no arrow), its level of its last (the level alone where
  there is no last), and its price on the sun bar, which is the button that
  buys. A bar the energy does not reach shakes its head.
- Links are one mesh, a node is one mesh for its plate and picture and one
  draw for its figure. Never a Button a node.
- A kind's node wears the tree itself (`Art.tree`).

**The shop** is three tiles on one row; nothing else about it changes.

## 4. The jetty (`valley/grove_sim.gd`)

"Finger picks, the rest runs." "Jetty has room, logs wait."

1. **A felled tree** gives its energy at once, as before. Its wood is **a
   pile** lying where it stood, worth that tree's wood. A pile that comes
   down within 70 of another joins it (the stack counts the piles and adds
   the wood), so a land chopped for an hour is not a thousand piles.
2. **The circle gathers.** On each swing, every pile under the circle that
   has lain 0.9 s (the fall) goes to the jetty, as many of a stack as the
   jetty has room for. **A full jetty takes none**: piles lie, never rot,
   and trees go on coming up.
3. **The jetty holds piles**: loose ones and the ones in bundles waiting for
   the raft. Eight, before any node.
4. **Tying**: while a whole bundle's worth of loose piles is there, a
   bundle is being tied, and takes them when its time is up. **Fewer are
   tied only when the raft is home and nothing is waiting for it**, so no
   pile is ever stranded and a short bundle never takes a place on the raft
   that a whole one wanted.
5. **The raft**: home and with a bundle waiting, it takes as many as it
   carries and goes; half its time out, half back. **Its wood is counted
   when it gets there**: the sim holds it as `owed` and whoever holds the
   sim (the screen, the tab) hands it to `Stock`. The far side is the
   screen's edge; nothing is drawn there.
6. **Away** the tying and the raft are worked out for what was on the jetty,
   by the same function with all the seconds at once, and then they stop.

The chain counts **piles, not wood**, so it is measured in the unit the axe
is, trees a minute, and a richer kind sends more wood through the same raft.
Before any node the raft carries twenty piles a minute and the tying forty:
a new grove fells about ten trees a minute, so there is no neck in the first
minutes, and one by the end of the first day, when Room and Sprout have the
land felling seventy.

`wood_per_min()` is the most the chain can send in a minute at its levels
(the slower of tying and rafting, in piles, times what a pile of the land's
mix is worth). The tab's chip shows it from the first day; it was "--".

`wood_made` goes on counting at the fell. `wood_sent` counts what the raft
has landed. A kept grove's wood in `Stock` is untouched and it starts with
an empty jetty. **A landing is seen**: the raft leaves the screen, so the
wood plate swells and "+N" rises by it as the raft gets there.

**The jetty is planks off the land's front left edge**, not a step or a
terrace (the land is one flat piece). It is in the ground's mesh; piles,
bundles and the raft are drawn by `valley/grove_life.gd` for all the
holders. A small plate by it says how many it holds of how many. The wood
plate at the top counts `Stock` and swells when the raft lands.

## 5. The four skills

- **A beaver of its own** (`beaver`, `teeth`). Each takes the oldest
  standing tree no other beaver has and bites it once a second for a share
  of the axe's chop. Its tree falls as any does: energy at once, a pile
  lying. **A beaver gathers nothing.** With someone there it never rests.
  **Away, each beaver fells the land once over at most**: as many trees as
  the land has room for, a beaver, fewer if the seconds gone were too few,
  worked out, and their piles are lying there on the return. (Trees away
  fill the land once and no further; a beaver's share is the same size.) It is drawn as the beaver that comes to a
  chopped tree is (`ui/faces/beaver.gd`).
- **Keen edge** (`crit`, `critsize`): each chop on each tree has the chance
  to count for more. Its number comes up large with a ring. A beaver's bite
  is never keen.
- **Lucky wood** (`luck`): the chance that a felled tree's pile is worth
  double. The pile is drawn as two with "x2" over it as it lands. Energy is
  not doubled: luck is wood through the same raft.
- **Crates** (`crate`, `cratesize`): with one level, a crate washes up at
  the land's front edge when its time has run, one at a time; a swing with
  the circle over it opens it for energy, as motes. Away the time goes on
  counting and at most one is waiting.

Left out: the reference's two other skills, its timed days and its animals.
A beaver that carries piles to the jetty is the obvious next node and is not
built.

## 6. How slow it is

The pace is the design. The grove as shipped (a wait a place, 2026-10-06)
reads Birch on day 1, Oak on day 4 and Pine on day 10 for eight visits of
two minutes, and the user has not said whether that stands. **The tree must
not make the trunk faster than that** for a bot that buys the cheapest thing
it can anywhere, shop or tree; the prices in section 3 are tuned until it
does not. `tests/_probe_grove.gd -- pace` is run after each stage and its
table goes in section 10, with the wood that reached `Stock` beside the wood
felled: the gap between the two is the bottleneck the user asked for.

## 7. Screens, words, sound

- `valley/grove_tree.gd`: the card. `valley/grove_screen.gd`: the second
  button (each 320 wide: the row is the column's 1000), the count on the
  right and the hint gone from the row (it is the tutorial's first title),
  the jetty's plate, piles flying to the jetty, keen numbers, the crate,
  `owed` to `Stock`. `ui/menu/valley_tab.gd`: `owed` to `Stock`, the chip.
- Every string is a locale key in en, pt and es; a node's effect line is
  measured in pt and es at the card's size before it ships.
- The tutorial's second page says the wood is left lying and gathered; a
  fourth page shows the jetty and the raft.
- Sounds are the four the Grove has (`chop`, `fell`, `buy`, `no`), reused:
  a pile gathered is the mote's quiet `chop`, a raft landing and a crate
  opened are `fell`. New takes are owed.
- Analytics: `grove_upgrade` carries a node's id as `tile`.

## 8. Not built, on purpose

A beaver that carries; a second raft; anything on the far shore; a node that
makes the land bigger; a cap on levels where the land does not ask for one
beyond the tables above; new sounds; cloud save.

## 9. What playing the concept changed

The concept page's sixth pass (`docs/brainstorm/concepts.html#valley`) was
played by a bot before the chain was built, and four of this spec's first
figures and rules did not survive it:

- **Short bundles made the first Jetty levels send less wood**, not more
  (room 6: 60 piles in twenty minutes; room 8: 54; room 10: 52), because a
  bundle of two took a place on the raft. Hence the rule in section 4.4.
- **The neck slammed shut in the first minute**: a jetty full 90% of the
  time, 31% of the wood landed, the first wood 52 s in. Tying started at
  20 s and the raft at 60 s; they start at 12 s and 24 s.
- **Beavers were dead on arrival**: they rested while as many piles lay as
  the land had room for trees, and piles never rot, so one beaver rested
  94% of twenty minutes. They never rest now, and what bounds them is the
  size of their share away.
- **Boughs of a kind gone from the land had no sign.** Hence `grows`.

A second run, on those rules, moved three more things:

- **The Jetty root opened with two nodes nobody could feel**: every jetty
  size landed the same 148 piles in twenty minutes, the raft's rate, and
  tying (then 6 s) was four times quicker than the raft. The root now opens
  with the Raft, then the Jetty's room (felt as "full" coming later and more
  sent while away), Bundle, Tying, Load; and tying starts at 12 s, twice the
  raft's rate, so it becomes the neck after a few levels of Raft and Bundle.
- **A beaver's share away was three trees** on a new grove for 250 energy.
  It is the land once over for each beaver.
- **A beaver's bite was a quarter of a chop**, and beside a finger it did
  nothing seen. It starts at half.

**Then the game's own bot played the built sim** (`tests/_probe_grove.gd --
pace`, 2026-10-07), which fells far more than the page's did: 77 trees a
minute over the first day, once Room and Sprout are bought. On the figures
above (a raft of 24 s, bundles of 3, tying 12 s, a jetty of 6) the eight
visits of two minutes landed 14% of the first day's wood, the jetty was full
97 to 99% of every day after, a third of the month's wood was landed and
91,169 piles lay on day 30. So the chain was widened to the table's figures:
the raft 12 s, a bundle 4, tying 6 s, the jetty 8 and 3 more a level, and
Load stops at 3 (its last levels never bound: tying was the neck by then).
Bundles growing by two a level were tried and opened the neck for good in a
week. Section 10 has the tables.

Left as they are, and the user's to judge: **the neck opens for good once
the Jetty root is bought out**, about six to eight hours of play in, until
the land fells more than 534 piles a minute (a bundle of 11 every 1.24 s);
if the neck should never open, the root's nodes lose their last levels as
the Axe has none. Also: piles never rot, so while the land fells more than
the raft carries they pile up (the bot's month peaked near 6,000 lying, in
sixty-odd stacks at the most, since stacks keep 70 apart, and had them all
sent by day 30); Crates is the
fourth node of its root; Lucky wood and the whole Jetty root return no
energy, by design, while nothing in the valley spends wood yet.

## 10. Measured

2026-10-07, at a39ee9f3, the last code commit of the branch. Everything
here was run again for this record; the tables of the first figures (a raft
of 24 s, bundles of 3, tying 12 s, a jetty of 6) are not kept, section 9
says what they read.

```
godot --headless --path . --script res://tests/_probe_grove.gd
probe_grove: 135 checks, 0 failed
godot --headless --path . --script tests/run_tests.gd
passed=249790 failed=0
```

### The pace

`tests/_probe_grove.gd -- pace [visits a day] [seconds a visit] [days]
[ids never bought]` plays days of short visits spread through sixteen
waking hours, the time between them worked out as time away. Its player
buys the cheapest thing it can, in the shop or on the tree, except an id or
a part named in the last argument. It holds the circle on a crate when one
lies, else on the oldest tree, and with no tree standing on the biggest
stack: **it never leaves a tree for a pile**, so it gathers what lies under
its chopping and what it goes to when the land is bare. `-- marathon
[hours]` is one visit of that length. The sim is seeded, so a command
prints the same table every time.

A day's line: the levels; the wood felled and the wood the raft has
delivered since the start; the piles lying and the piles on the jetty as
the day ends; `full`, the share of the frames played **since the line
before** on which the jetty was full; the trees felled and how many of
them by beavers; the energy held; the hours played. After the last day,
when each kind was bought: `seeds 1` is Birch, `seeds 2` Oak, `seeds 3`
Pine.

**Run 1. Eight visits of two minutes, buying everything** (32 s):

```
godot --headless --path . --script res://tests/_probe_grove.gd -- pace 8 120 30
pace: 8 visits a day of 120 s, 30 days
day 1: axe 8 reach 2 swing 3 sprout 5 room 6 seeds 1 | soft 3 rich 2 | raft 2 jetty 5 bundle 1 tying 3 crit 1 | wood 2240 felled, 738 delivered, 732 piles lying, 23 of 23 on the jetty, full 87% | trees 1237, 0 by beavers | energy 14 | 0.3 h played
day 2: axe 11 reach 3 swing 4 sprout 7 room 8 seeds 1 | soft 4 rich 3 | raft 4 jetty 8 bundle 3 tying 4 load 1 beaver 1 crit 3 critsize 2 luck 2 crate 1 cratesize 1 | wood 8419 felled, 2881 delivered, 1990 piles lying, 32 of 32 on the jetty, full 97% | trees 3425, 22 by beavers | energy 5 | 0.5 h played
day 3: axe 13 reach 4 swing 5 sprout 8 room 10 seeds 1 | soft 4 rich 3 | raft 5 jetty 10 bundle 4 tying 6 load 1 beaver 1 teeth 1 crit 4 critsize 3 luck 4 crate 2 cratesize 2 | wood 19009 felled, 8525 delivered, 3158 piles lying, 38 of 38 on the jetty, full 97% | trees 6469, 121 by beavers | energy 583 | 0.8 h played
day 5: axe 16 reach 5 swing 7 sprout 10 room 12 seeds 2 | soft 6 rich 4 | raft 7 jetty 12 bundle 5 tying 7 load 2 beaver 2 teeth 2 crit 5 critsize 4 luck 5 crate 4 cratesize 3 | wood 52193 felled, 29979 delivered, 4289 piles lying, 44 of 44 on the jetty, full 97% | trees 12996, 1093 by beavers | energy 1490 | 1.3 h played
day 7: axe 18 reach 6 swing 8 sprout 11 room 14 seeds 2 | soft 6 rich 5 | raft 8 jetty 14 bundle 6 tying 9 load 3 beaver 2 teeth 3 crit 7 critsize 5 luck 6 crate 5 cratesize 4 | wood 109241 felled, 72365 delivered, 5301 piles lying, 50 of 50 on the jetty, full 96% | trees 21353, 2617 by beavers | energy 1774 | 1.9 h played
day 10: axe 20 reach 7 swing 9 sprout 13 room 16 seeds 3 | soft 7 rich 6 | raft 10 jetty 16 bundle 6 tying 10 load 3 beaver 3 teeth 3 crit 8 critsize 6 luck 7 crate 6 cratesize 5 | wood 228123 felled, 175105 delivered, 5931 piles lying, 56 of 56 on the jetty, full 96% | trees 35918, 5712 by beavers | energy 5469 | 2.7 h played
day 14: axe 23 reach 9 swing 10 sprout 14 room 18 seeds 3 | soft 8 rich 7 | raft 11 jetty 18 bundle 7 tying 12 load 3 beaver 3 teeth 4 crit 9 critsize 6 luck 9 crate 7 cratesize 7 | wood 509143 felled, 444493 delivered, 4411 piles lying, 62 of 62 on the jetty, full 96% | trees 57291, 9275 by beavers | energy 5246 | 3.7 h played
day 21: axe 26 reach 10 swing 12 sprout 16 room 21 seeds 4 | soft 9 rich 7 | raft 13 jetty 20 bundle 7 tying 14 load 3 beaver 4 teeth 5 crit 10 critsize 6 luck 10 crate 9 cratesize 8 | wood 1358739 felled, 1251238 delivered, 5980 piles lying, 68 of 68 on the jetty, full 95% | trees 108567, 19876 by beavers | energy 14813 | 5.6 h played
day 30: axe 30 reach 11 swing 13 sprout 18 room 23 seeds 4 | soft 10 rich 9 | raft 15 jetty 20 bundle 7 tying 15 load 3 beaver 5 teeth 5 crit 10 critsize 6 luck 10 crate 10 cratesize 10 | wood 3160643 felled, 3158499 delivered, 38 piles lying, 33 of 68 on the jetty, full 50% | trees 174187, 34280 by beavers | energy 60345 | 8.0 h played
seeds 1 on day 1 (0.3 h played)
seeds 2 on day 4 (1.0 h played)
seeds 3 on day 10 (2.5 h played)
seeds 4 on day 21 (5.5 h played)
```

**Run 2. The same, never Beavers and never Fortune** (22 s):

```
godot --headless --path . --script res://tests/_probe_grove.gd -- pace 8 120 30 beaver,teeth,crit,critsize,luck,crate,cratesize
pace: 8 visits a day of 120 s, 30 days, never beaver,teeth,crit,critsize,luck,crate,cratesize
day 1: axe 8 reach 2 swing 3 sprout 5 room 6 seeds 1 | soft 3 rich 2 | raft 2 jetty 5 bundle 1 tying 3 | wood 2266 felled, 743 delivered, 733 piles lying, 23 of 23 on the jetty, full 87% | trees 1238, 0 by beavers | energy 120 | 0.3 h played
day 2: axe 12 reach 4 swing 5 sprout 7 room 9 seeds 1 | soft 4 rich 3 | raft 5 jetty 9 bundle 3 tying 5 load 1 | wood 8991 felled, 3562 delivered, 1907 piles lying, 35 of 35 on the jetty, full 97% | trees 3596, 0 by beavers | energy 170 | 0.5 h played
day 3: axe 14 reach 5 swing 6 sprout 9 room 11 seeds 2 | soft 5 rich 3 | raft 6 jetty 11 bundle 4 tying 6 load 1 | wood 18737 felled, 9976 delivered, 2840 piles lying, 25 of 41 on the jetty, full 97% | trees 6710, 0 by beavers | energy 218 | 0.8 h played
day 5: axe 17 reach 6 swing 7 sprout 11 room 13 seeds 2 | soft 6 rich 5 | raft 8 jetty 13 bundle 5 tying 8 load 2 | wood 47709 felled, 35302 delivered, 2377 piles lying, 47 of 47 on the jetty, full 97% | trees 12565, 0 by beavers | energy 1183 | 1.3 h played
day 7: axe 20 reach 7 swing 8 sprout 12 room 15 seeds 2 | soft 6 rich 5 | raft 9 jetty 15 bundle 6 tying 9 load 3 | wood 92675 felled, 81899 delivered, 1794 piles lying, 53 of 53 on the jetty, full 96% | trees 20211, 0 by beavers | energy 2059 | 1.9 h played
day 10: axe 21 reach 8 swing 9 sprout 13 room 16 seeds 3 | soft 7 rich 6 | raft 10 jetty 17 bundle 7 tying 10 load 3 | wood 166911 felled, 166349 delivered, 23 piles lying, 10 of 59 on the jetty, full 45% | trees 29770, 0 by beavers | energy 2748 | 2.7 h played
day 14: axe 23 reach 9 swing 10 sprout 14 room 18 seeds 3 | soft 8 rich 7 | raft 11 jetty 18 bundle 7 tying 12 load 3 | wood 317895 felled, 317322 delivered, 22 piles lying, 24 of 62 on the jetty, full 0% | trees 44626, 0 by beavers | energy 13554 | 3.7 h played
day 21: axe 26 reach 10 swing 12 sprout 16 room 20 seeds 3 | soft 8 rich 7 | raft 13 jetty 20 bundle 7 tying 14 load 3 | wood 729743 felled, 728909 delivered, 23 piles lying, 26 of 68 on the jetty, full 0% | trees 79528, 0 by beavers | energy 32709 | 5.6 h played
day 30: axe 28 reach 10 swing 12 sprout 17 room 22 seeds 4 | soft 10 rich 8 | raft 14 jetty 20 bundle 7 tying 14 load 3 | wood 1202875 felled, 1201818 delivered, 17 piles lying, 14 of 68 on the jetty, full 0% | trees 106565, 0 by beavers | energy 53796 | 8.0 h played
seeds 1 on day 1 (0.2 h played)
seeds 2 on day 3 (0.8 h played)
seeds 3 on day 8 (2.1 h played)
seeds 4 on day 22 (5.8 h played)
```

**Run 3. Six visits of ten minutes, buying everything** (1 min 58 s):

```
godot --headless --path . --script res://tests/_probe_grove.gd -- pace 6 600 30
pace: 6 visits a day of 600 s, 30 days
day 1: axe 14 reach 5 swing 6 sprout 9 room 11 seeds 2 | soft 5 rich 3 | raft 6 jetty 11 bundle 4 tying 6 load 1 beaver 1 teeth 1 crit 4 critsize 3 luck 4 crate 3 cratesize 2 | wood 26948 felled, 12304 delivered, 4275 piles lying, 41 of 41 on the jetty, full 95% | trees 8702, 54 by beavers | energy 509 | 1.0 h played
day 2: axe 19 reach 6 swing 8 sprout 11 room 14 seeds 2 | soft 6 rich 5 | raft 8 jetty 14 bundle 6 tying 9 load 3 beaver 2 teeth 3 crit 7 critsize 5 luck 6 crate 5 cratesize 5 | wood 115964 felled, 74332 delivered, 6003 piles lying, 50 of 50 on the jetty, full 97% | trees 22379, 2093 by beavers | energy 588 | 2.0 h played
day 3: axe 21 reach 7 swing 9 sprout 13 room 16 seeds 3 | soft 7 rich 6 | raft 10 jetty 16 bundle 7 tying 10 load 3 beaver 3 teeth 4 crit 8 critsize 6 luck 8 crate 6 cratesize 6 | wood 268620 felled, 205710 delivered, 6017 piles lying, 56 of 56 on the jetty, full 96% | trees 39352, 4707 by beavers | energy 3100 | 3.0 h played
day 5: axe 25 reach 9 swing 11 sprout 15 room 19 seeds 3 | soft 8 rich 7 | raft 12 jetty 20 bundle 7 tying 13 load 3 beaver 4 teeth 5 crit 10 critsize 6 luck 10 crate 8 cratesize 8 | wood 911056 felled, 839745 delivered, 4246 piles lying, 68 of 68 on the jetty, full 96% | trees 82480, 9980 by beavers | energy 21678 | 5.0 h played
day 7: axe 28 reach 10 swing 12 sprout 17 room 22 seeds 4 | soft 10 rich 8 | raft 14 jetty 20 bundle 7 tying 14 load 3 beaver 4 teeth 5 crit 10 critsize 6 luck 10 crate 9 cratesize 9 | wood 1890680 felled, 1888641 delivered, 25 piles lying, 26 of 68 on the jetty, full 67% | trees 129405, 15550 by beavers | energy 17689 | 7.0 h played
day 10: axe 31 reach 12 swing 14 sprout 19 room 25 seeds 4 | soft 10 rich 9 | raft 15 jetty 20 bundle 7 tying 15 load 3 beaver 5 teeth 5 crit 10 critsize 6 luck 10 crate 10 cratesize 10 | wood 4454152 felled, 4450528 delivered, 32 piles lying, 47 of 68 on the jetty, full 10% | trees 214400, 27463 by beavers | energy 131369 | 10.0 h played
day 14: axe 34 reach 12 swing 15 sprout 20 room 27 seeds 5 | soft 12 rich 10 | raft 15 jetty 20 bundle 7 tying 15 load 3 beaver 5 teeth 5 crit 10 critsize 6 luck 10 crate 10 cratesize 10 | wood 8409264 felled, 8406401 delivered, 24 piles lying, 20 of 68 on the jetty, full 26% | trees 303110, 37963 by beavers | energy 12842 | 14.0 h played
day 21: axe 38 reach 12 swing 15 sprout 20 room 27 seeds 6 | soft 12 rich 11 | raft 15 jetty 20 bundle 7 tying 15 load 3 beaver 5 teeth 5 crit 10 critsize 6 luck 10 crate 10 cratesize 10 | wood 18127424 felled, 18125248 delivered, 8 piles lying, 6 of 68 on the jetty, full 4% | trees 452094, 55397 by beavers | energy 1000007 | 21.0 h played
day 30: axe 40 reach 12 swing 15 sprout 20 room 27 seeds 6 | soft 13 rich 12 | raft 15 jetty 20 bundle 7 tying 15 load 3 beaver 5 teeth 5 crit 10 critsize 6 luck 10 crate 10 cratesize 10 | wood 28685728 felled, 28682496 delivered, 21 piles lying, 11 of 68 on the jetty, full 1% | trees 555205, 69879 by beavers | energy 2508331 | 30.0 h played
seeds 1 on day 1 (0.3 h played)
seeds 2 on day 1 (1.0 h played)
seeds 3 on day 3 (2.6 h played)
seeds 4 on day 6 (5.9 h played)
seeds 5 on day 11 (11.0 h played)
seeds 6 on day 20 (19.6 h played)
```

**Run 4. Two hours without stopping** (7 s):

```
godot --headless --path . --script res://tests/_probe_grove.gd -- marathon 2
pace: 1 visits a day of 7200 s, 1 days
day 1: axe 18 reach 6 swing 8 sprout 11 room 14 seeds 2 | soft 6 rich 5 | raft 8 jetty 14 bundle 6 tying 9 load 3 beaver 2 teeth 3 crit 7 critsize 5 luck 6 crate 5 cratesize 5 | wood 114449 felled, 71912 delivered, 6154 piles lying, 50 of 50 on the jetty, full 96% | trees 22093, 1823 by beavers | energy 1693 | 2.0 h played
seeds 1 on day 1 (0.3 h played)
seeds 2 on day 1 (1.0 h played)
```

**Run 5. Eight visits of two minutes, never Beavers (Fortune alone)** (26 s):

```
godot --headless --path . --script res://tests/_probe_grove.gd -- pace 8 120 30 beaver,teeth
pace: 8 visits a day of 120 s, 30 days, never beaver,teeth
day 1: axe 8 reach 2 swing 3 sprout 5 room 6 seeds 1 | soft 3 rich 2 | raft 2 jetty 5 bundle 1 tying 3 crit 1 | wood 2240 felled, 738 delivered, 732 piles lying, 23 of 23 on the jetty, full 87% | trees 1237, 0 by beavers | energy 14 | 0.3 h played
day 2: axe 11 reach 3 swing 4 sprout 7 room 8 seeds 1 | soft 4 rich 3 | raft 4 jetty 8 bundle 3 tying 4 load 1 crit 3 critsize 2 luck 2 crate 1 cratesize 1 | wood 8385 felled, 2941 delivered, 1944 piles lying, 32 of 32 on the jetty, full 97% | trees 3402, 0 by beavers | energy 221 | 0.5 h played
day 3: axe 14 reach 4 swing 5 sprout 8 room 10 seeds 1 | soft 4 rich 3 | raft 5 jetty 10 bundle 4 tying 6 load 1 crit 4 critsize 3 luck 4 crate 2 cratesize 2 | wood 18737 felled, 8609 delivered, 3022 piles lying, 38 of 38 on the jetty, full 97% | trees 6370, 0 by beavers | energy 403 | 0.8 h played
day 5: axe 16 reach 5 swing 7 sprout 10 room 12 seeds 2 | soft 6 rich 4 | raft 7 jetty 12 bundle 5 tying 7 load 2 crit 6 critsize 4 luck 5 crate 4 cratesize 3 | wood 48745 felled, 30029 delivered, 3575 piles lying, 44 of 44 on the jetty, full 97% | trees 12362, 0 by beavers | energy 44 | 1.3 h played
day 7: axe 18 reach 6 swing 8 sprout 11 room 14 seeds 2 | soft 6 rich 5 | raft 8 jetty 14 bundle 5 tying 9 load 3 crit 7 critsize 5 luck 6 crate 5 cratesize 4 | wood 99283 felled, 72722 delivered, 3711 piles lying, 50 of 50 on the jetty, full 97% | trees 19709, 0 by beavers | energy 1964 | 1.9 h played
day 10: axe 20 reach 7 swing 9 sprout 12 room 16 seeds 3 | soft 7 rich 6 | raft 9 jetty 16 bundle 6 tying 10 load 3 crit 8 critsize 6 luck 7 crate 6 cratesize 5 | wood 197703 felled, 175403 delivered, 2603 piles lying, 56 of 56 on the jetty, full 96% | trees 32456, 0 by beavers | energy 1788 | 2.7 h played
day 14: axe 22 reach 8 swing 10 sprout 14 room 18 seeds 3 | soft 8 rich 6 | raft 11 jetty 18 bundle 7 tying 11 load 3 crit 9 critsize 6 luck 9 crate 7 cratesize 7 | wood 425059 felled, 424171 delivered, 38 piles lying, 29 of 62 on the jetty, full 49% | trees 50201, 0 by beavers | energy 10337 | 3.7 h played
day 21: axe 26 reach 10 swing 12 sprout 16 room 20 seeds 3 | soft 8 rich 7 | raft 13 jetty 20 bundle 7 tying 13 load 3 crit 10 critsize 6 luck 10 crate 9 cratesize 8 | wood 1106827 felled, 1105548 delivered, 27 piles lying, 25 of 68 on the jetty, full 0% | trees 92175, 0 by beavers | energy 19053 | 5.6 h played
day 30: axe 28 reach 11 swing 13 sprout 18 room 22 seeds 4 | soft 10 rich 8 | raft 14 jetty 20 bundle 7 tying 15 load 3 crit 10 critsize 6 luck 10 crate 10 cratesize 10 | wood 2349439 felled, 2347646 delivered, 34 piles lying, 33 of 68 on the jetty, full 0% | trees 142231, 0 by beavers | energy 40159 | 8.0 h played
seeds 1 on day 1 (0.3 h played)
seeds 2 on day 4 (0.9 h played)
seeds 3 on day 10 (2.6 h played)
seeds 4 on day 23 (5.9 h played)
```

**Run 6. Eight visits of two minutes, never Fortune (Beavers alone)** (28 s):

```
godot --headless --path . --script res://tests/_probe_grove.gd -- pace 8 120 30 crit,critsize,luck,crate,cratesize
pace: 8 visits a day of 120 s, 30 days, never crit,critsize,luck,crate,cratesize
day 1: axe 8 reach 2 swing 3 sprout 5 room 6 seeds 1 | soft 3 rich 2 | raft 2 jetty 5 bundle 1 tying 3 | wood 2266 felled, 743 delivered, 733 piles lying, 23 of 23 on the jetty, full 87% | trees 1238, 0 by beavers | energy 120 | 0.3 h played
day 2: axe 12 reach 4 swing 5 sprout 7 room 9 seeds 1 | soft 4 rich 3 | raft 4 jetty 9 bundle 3 tying 5 load 1 beaver 1 | wood 9062 felled, 3482 delivered, 1968 piles lying, 35 of 35 on the jetty, full 97% | trees 3635, 46 by beavers | energy 409 | 0.5 h played
day 3: axe 14 reach 5 swing 6 sprout 9 room 11 seeds 2 | soft 4 rich 3 | raft 6 jetty 11 bundle 4 tying 6 load 1 beaver 1 teeth 1 | wood 19160 felled, 9684 delivered, 3049 piles lying, 41 of 41 on the jetty, full 97% | trees 6885, 159 by beavers | energy 311 | 0.8 h played
day 5: axe 17 reach 6 swing 7 sprout 11 room 14 seeds 2 | soft 6 rich 5 | raft 8 jetty 13 bundle 5 tying 8 load 2 beaver 2 teeth 2 | wood 52868 felled, 34672 delivered, 3495 piles lying, 47 of 47 on the jetty, full 97% | trees 13601, 1849 by beavers | energy 1057 | 1.3 h played
day 7: axe 20 reach 7 swing 8 sprout 12 room 15 seeds 2 | soft 6 rich 5 | raft 9 jetty 15 bundle 6 tying 9 load 3 beaver 3 teeth 3 | wood 104412 felled, 81400 delivered, 3840 piles lying, 53 of 53 on the jetty, full 97% | trees 22286, 3852 by beavers | energy 3966 | 1.9 h played
day 10: axe 21 reach 8 swing 9 sprout 13 room 17 seeds 3 | soft 7 rich 6 | raft 10 jetty 17 bundle 7 tying 11 load 3 beaver 3 teeth 4 | wood 203506 felled, 196996 delivered, 630 piles lying, 59 of 59 on the jetty, full 95% | trees 34267, 7317 by beavers | energy 6655 | 2.7 h played
day 14: axe 24 reach 9 swing 10 sprout 15 room 18 seeds 3 | soft 8 rich 7 | raft 11 jetty 19 bundle 7 tying 12 load 3 beaver 4 teeth 5 | wood 419350 felled, 418750 delivered, 19 piles lying, 27 of 65 on the jetty, full 17% | trees 54368, 12742 by beavers | energy 16502 | 3.7 h played
day 21: axe 27 reach 10 swing 12 sprout 16 room 21 seeds 4 | soft 9 rich 8 | raft 13 jetty 20 bundle 7 tying 14 load 3 beaver 4 teeth 5 | wood 943506 felled, 942550 delivered, 20 piles lying, 5 of 68 on the jetty, full 20% | trees 95861, 25764 by beavers | energy 21291 | 5.6 h played
day 30: axe 29 reach 11 swing 13 sprout 18 room 23 seeds 4 | soft 10 rich 8 | raft 15 jetty 20 bundle 7 tying 15 load 3 beaver 5 teeth 5 | wood 1797098 felled, 1796286 delivered, 17 piles lying, 22 of 68 on the jetty, full 7% | trees 140329, 41435 by beavers | energy 3017 | 8.0 h played
seeds 1 on day 1 (0.2 h played)
seeds 2 on day 3 (0.8 h played)
seeds 3 on day 8 (2.1 h played)
seeds 4 on day 20 (5.1 h played)
```

### What they say

| Run | Birch | Oak | Pine | Fourth kind | Wood felled | Wood delivered | Share | Most piles lying on a printed day |
|---|---|---|---|---|---|---|---|---|
| 1. 8 x 120 s, everything | day 1 | day 4 | day 10 | day 21 | 3,160,643 | 3,158,499 | 99.93% | 5,980 (day 21); 38 on day 30 |
| 2. 8 x 120 s, never Beavers or Fortune | day 1 | day 3 | day 8 | day 22 | 1,202,875 | 1,201,818 | 99.91% | 2,840 (day 3); 17 on day 30 |
| 3. 6 x 600 s, everything | day 1 | day 1 | day 3 | day 6 (fifth 11, sixth 20) | 28,685,728 | 28,682,496 | 99.99% | 6,017 (day 3); 21 on day 30 |
| 4. two hours without stopping | 0.3 h | 1.0 h | not reached | - | 114,449 | 71,912 | 63% | 6,154 (the end) |
| 5. 8 x 120 s, never Beavers | day 1 | day 4 | day 10 | day 23 | 2,349,439 | 2,347,646 | 99.92% | 3,711 (day 7); 34 on day 30 |
| 6. 8 x 120 s, never Fortune | day 1 | day 3 | day 8 | day 20 | 1,797,098 | 1,796,286 | 99.95% | 3,840 (day 7); 17 on day 30 |

"Most piles lying" is the highest of the printed days, not a peak the bot
tracked. How long the jetty stays full, the same way (each figure is for
the days since the line before):

| Run | The jetty full |
|---|---|
| 1 | 87% of day 1; 95 to 97% from day 2 to day 21; 50% of days 22 to 30 |
| 2 | 87% of day 1; 96 to 97% from day 2 to day 7; 45% of days 8 to 10; 0% after |
| 3 | 95 to 97% from day 1 to day 5; 67% of days 6 and 7; 10% of days 8 to 10; 26% of days 11 to 14; 4% and 1% after |
| 4 | 96% of the two hours |
| 5 | 87% of day 1; 96 to 97% from day 2 to day 10; 49% of days 11 to 14; 0% after |
| 6 | 87% of day 1; 95 to 97% from day 2 to day 10; 17%, 20% and 7% after |

Run 1's wood delivered of its wood felled, as the month goes: 33% on day
1 (738 of 2,240), 57% on day 5, 77% on day 10, 92% on day 21, 99.93% on
day 30.

- **The trunk.** The bot that buys everything reads day 1, 4 and 10, what
  the grove read before the tree (section 6), so the tree as a whole does
  not make the trunk faster. That is two things cancelling. Fortune costs
  the cheapest-first buyer a day on Oak and two on Pine (runs 1 and 5
  against runs 6 and 2) and Beavers move none of the three (run 6 against
  run 2). **A player who leaves the Fortune root alone reads day 1, 3 and
  8**, two days sooner on Pine than the pace section 6 says the tree must
  not beat. It was left as it is.
- **The neck binds from the first day.** Day 1 of run 1 lands a third of
  its wood with the jetty full 87% of the frames played: the bot fells 77
  trees a minute over that day (1,237 in sixteen minutes), not the ten of
  a grove's first minutes.
- **And it opens for good later.** Run 1 between 5.6 and 8.0 hours of
  play, run 3 between 5 and 7, run 5 between 2.7 and 3.7, and run 2 by 2.7
  hours, before its Jetty root is complete (raft 10, jetty 17, tying 10):
  that bot fells fewer trees. From there every pile felled is delivered.
  By arithmetic from the constants the finished chain ties a bundle of 11
  every 1.24 s, 534 piles a minute, and its raft carries four bundles
  every 3.44 s, 768; the bot fells about 191 trees a minute over the last
  nine days of run 3.
- **Piles never rot and the backlog stays small**: about 6,000 piles at
  the most on any printed day, cleared once the neck opens.
- Not measured: a person who sweeps for piles, or who sweeps many trees at
  a stroke. No bot here does either.

### Draw calls

`tests/_shot_grove.gd`, 54 shots, 810x1440, budget 855. Each driver was
run twice, one window at a time; the second reading is the one to quote.
Trees come up at random spots, so the late beats move by tens from run to
run. The `opengl3_angle` runs were under reduce motion. `git diff
project.godot` was empty after each.

```
caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_grove.gd -- <outdir> > <log> 2>&1
caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_grove.gd -- <outdir> reduce > <log> 2>&1
```

The harness's header says what each beat is. The last column is the land
of the default driver's second run at that shot: the trees standing, the
stacks lying, the piles the jetty holds of its room.

| Beat | Default, first | Default, second | `opengl3_angle` + reduce, first | `opengl3_angle` + reduce, second | The land |
|---|---|---|---|---|---|
| `1_tab` | 111 | 111 | 111 | 111 | - |
| `2_start` | 59 | 59 | 59 | 59 | trees 1, stacks 0, jetty 0/8 |
| `3_chop` | 73 | 74 | 72 | 72 | trees 1, stacks 0, jetty 0/8 |
| `4_fell` | 76 | 77 | 74 | 74 | trees 0, stacks 1, jetty 0/8 |
| `4b_motes_hang` | 73 | 74 | 72 | 72 | trees 0, stacks 1, jetty 0/8 |
| `4c_motes_in` | 64 | 65 | 58 | 58 | trees 0, stacks 1, jetty 0/8 |
| `5_mid` | 90 | 90 | 86 | 86 | trees 9, stacks 1, jetty 0/8 |
| `6_mid_chop` | 108 | 101 | 109 | 99 | trees 8, stacks 2, jetty 0/8 |
| `6b_skills` | 143 | 138 | 134 | 136 | trees 8, stacks 2, jetty 0/8 |
| `j1_piles` | 95 | 92 | 91 | 91 | trees 10, stacks 7, jetty 0/14 |
| `j2_gather` | 112 | 110 | 101 | 96 | trees 9, stacks 5, jetty 5/14 |
| `j3_part_full` | 95 | 96 | 91 | 93 | trees 9, stacks 7, jetty 7/14 |
| `j4_raft_half` | 95 | 95 | 91 | 93 | trees 9, stacks 7, jetty 7/14 |
| `sw_0` | 94 | 92 | 90 | 92 | trees 9, stacks 7, jetty 7/14 |
| `sw_1` | 95 | 92 | 93 | 95 | trees 9, stacks 7, jetty 7/14 |
| `j5_full` | 113 | 106 | 105 | 105 | trees 10, stacks 7, jetty 44/44 |
| `j6_landed` | 106 | 100 | 99 | 99 | trees 10, stacks 7, jetty 44/44 |
| `s1_gone` | 161 | 160 | 159 | 159 | trees 10, stacks 7, jetty 0/44 |
| `s1b_gone_kind` | 159 | 158 | 157 | 157 | trees 10, stacks 7, jetty 0/44 |
| `s1c_first_level` | 161 | 160 | 159 | 159 | trees 10, stacks 7, jetty 0/44 |
| `s2_beaver` | 83 | 83 | 82 | 82 | trees 6, stacks 0, jetty 0/44 |
| `s2b_beaver_bites` | 85 | 85 | 83 | 83 | trees 6, stacks 0, jetty 0/44 |
| `s3_rest` | 83 | 83 | 82 | 82 | trees 0, stacks 0, jetty 0/44 |
| `s4_keen` | 103 | 103 | 103 | 98 | trees 9, stacks 0, jetty 0/44 |
| `s4b_keen_fell` | 106 | 105 | 112 | 100 | trees 8, stacks 1, jetty 0/44 |
| `s5_lucky` | 102 | 99 | 95 | 95 | trees 8, stacks 1, jetty 0/44 |
| `s5b_lucky_later` | 91 | 90 | 82 | 82 | trees 8, stacks 1, jetty 0/44 |
| `s6_crate_afloat` | 87 | 87 | 86 | 86 | trees 9, stacks 0, jetty 0/44 |
| `s6b_crate_thrown` | 87 | 87 | 86 | 86 | trees 9, stacks 0, jetty 0/44 |
| `s6c_crate_ashore` | 87 | 87 | 86 | 86 | trees 9, stacks 0, jetty 0/44 |
| `s6d_crate_ashore_later` | 87 | 87 | 86 | 86 | trees 9, stacks 0, jetty 0/44 |
| `s7_crate_opened` | 104 | 105 | 98 | 100 | trees 8, stacks 1, jetty 0/44 |
| `s7b_crate_motes` | 103 | 103 | 98 | 98 | trees 8, stacks 1, jetty 0/44 |
| `s8_soft` | 143 | 143 | 142 | 142 | trees 9, stacks 0, jetty 0/44 |
| `7w_0` | 232 | 236 | 231 | 233 | trees 30, stacks 39, jetty 0/68 |
| `7w_1` | 232 | 236 | 231 | 233 | trees 30, stacks 39, jetty 0/68 |
| `7w_2` | 247 | 251 | 246 | 248 | trees 30, stacks 39, jetty 0/68 |
| `7w_3` | 248 | 252 | 253 | 254 | trees 25, stacks 39, jetty 0/68 |
| `7w_4` | 251 | 253 | 243 | 244 | trees 25, stacks 39, jetty 0/68 |
| `7w_5` | 270 | 272 | 243 | 259 | trees 25, stacks 39, jetty 0/68 |
| `7_late` | 363 | 379 | 334 | 326 | trees 21, stacks 39, jetty 68/68 |
| `7j_late_jetty` | 370 | 362 | 305 | 305 | trees 21, stacks 39, jetty 64/68 |
| `8_bought` | 382 | 378 | 323 | 353 | trees 26, stacks 39, jetty 64/68 |
| `9_tut_chop` | 334 | 338 | 325 | 333 | trees 30, stacks 39, jetty 64/68 |
| `10_tut_gifts` | 319 | 323 | 312 | 320 | trees 30, stacks 39, jetty 20/68 |
| `10b_tut_gifts_carried` | 320 | 324 | 311 | 319 | trees 30, stacks 39, jetty 20/68 |
| `11_tut_wait` | 311 | 315 | 309 | 317 | trees 30, stacks 39, jetty 9/68 |
| `13a_tut_send_gather` | 327 | 331 | 311 | 319 | trees 30, stacks 39, jetty 9/68 |
| `13_tut_send` | 316 | 320 | 309 | 317 | trees 30, stacks 39, jetty 0/68 |
| `13b_tut_send_out` | 316 | 320 | 310 | 318 | trees 30, stacks 39, jetty 0/68 |
| `13c_tut_send_landed` | 317 | 321 | 310 | 318 | trees 30, stacks 39, jetty 0/68 |
| `w1_worst_land` | 461 | 459 | 394 | 426 | trees 30, stacks 68, jetty 68/68 |
| `w2_worst_skills` | 385 | 390 | 374 | 386 | trees 30, stacks 68, jetty 68/68 |
| `12_tab_after` | 241 | 241 | 241 | 241 | - |

The highest second reading is 459 on `w1_worst_land` (the late levels, 68
stacks laid in rows, a full jetty, the circle on the land), 426 on
`opengl3_angle` under reduce motion. The highest of any run is 471, read
by the fix pass that added the beat. That is 55% of the budget.
