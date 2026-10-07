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
table goes in section 9, with the wood that reached `Stock` beside the wood
felled: the gap between the two is the bottleneck the user asked for.

## 7. Screens, words, sound

- `valley/grove_tree.gd`: the card. `valley/grove_screen.gd`: the second
  button (both narrower: the row is 730 wide), the count on the right and
  the hint gone from the row (it is the tutorial's first title), the jetty's
  plate, piles flying to the jetty, keen numbers, the crate, `owed` to
  `Stock`. `ui/menu/valley_tab.gd`: `owed` to `Stock`, the chip.
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
a hundred or so stacks, and had them all sent by day 30); Crates is the
fourth node of its root; Lucky wood and the whole Jetty root return no
energy, by design, while nothing in the valley spends wood yet.

## 10. Measured

Added by the build, stage by stage.
