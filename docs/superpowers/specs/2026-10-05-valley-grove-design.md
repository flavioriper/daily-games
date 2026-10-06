# Valley and the Grove

2026-10-05. Designed with the user in one sitting, through a playable tab on
the concept page (`docs/brainstorm/concepts.html#valley`, four passes) and
built the same day. What the user said is quoted; the rest is what was
proposed on the page and built when the user said "build it".

## 1. What it is

**Valley is a sixth tab**: "another category of incremental connected games",
slow places that "share a single inventory between them". One place gathers
wood, a later one might turn wood into something else, another might make
power for the rest. Only the first is planned and built: **the Grove**. The
others are "still to plan", so the tab holds one card and the wood count and
nothing that promises a second place.

The Grove follows the gathering zone of *Tiny Biomes: Cozy Idle*, which is
named here once and nowhere else: not in code, comments, commits or on
screen.

**Pace is the design.** "For all idle games the idea is to be really slow,
not something the user will nail in 2 hours. They will be infinite
incremental connected, so it's important to keep slow pace." Nothing in the
Valley has a finish.

## 2. The shared inventory

`core/stock.gd`, the autoload `Stock`, `user://stock.cfg`: a count for each
named resource (`wood` today). `count`, `add`, `can_pay`, `pay` (all or
nothing), `changed` and `gained`. A place reads and writes Stock and never
another place. Written at most once every two seconds and whenever the app is
left, because a place adds as fast as trees fall.

**A place never spends a shared resource on itself.** "Each tree delivers
energy that is going to be used to upgrade the tree, to avoid using wood
since it's a shared resource with other games." So a place keeps its own
upgrade currency in its own save, and Stock holds only what places exchange.

Gold stays in `Wallet`. Nothing in the Valley is bought with gold, sold for
gold, or random.

## 3. The Grove's rules (`valley/grove_sim.gd`)

"A piece of land with growing trees over time, and the user starts clicking
to chop the area around the touch point, no automation yet."

- **The land** holds `room` trees. While there is room a new tree comes up at
  a random free spot ("trees spawn randomly, not at a fixed spot") after the
  sprout time times 0.6 to 1.4. A full land waits.
- **The circle** is there while a finger is down and follows it. Every swing,
  each tree whose crown is inside takes the axe's strength. Holding and
  tapping chop at the same pace.
- **A felled tree** gives the same number of wood (to Stock) and energy (to
  the Grove).
- **Away**: when the grove is next read, trees have come up at the sprout
  time for the seconds gone, until the land was full. A clock set back grows
  nothing; one set forward fills the land once.

"Start with very very small trees and spawn time" and "each tree starts as
4 hp, so the user has to hit 4 times at the beginning to get wood": a new
grove is one sapling, room for three, a tree about every six seconds, one
chop every half second.

| Tier | Look | To fell | Wood and energy |
|---|---|---|---|
| 0 | Sapling | 4 | 1 |
| 1 | Birch | 10 | 2 |
| 2 | Oak | 27 | 4 |
| 3 | Pine | 70 | 8 |
| 4 | Blossom | 183 | 16 |
| n | the looks again from Birch, a gold mark a lap | x2.6 a tier | x2 a tier |

A richer tree asks more than it pays, so Seeds helps only once the axe has
caught up: that race is what has no end. A new tree is the best tier opened
55% of the time, the one below 30%, the one below that 15%.

| Tile | Each level | Start | Last level | Energy |
|---|---|---|---|---|
| Axe | +1 a chop | 1 | none | 10, x1.38 |
| Reach | circle 8% wider | radius 90 of a land 810 wide | 12 | 40, x2.1 |
| Swing | 7% less between chops | 0.5 s | 15 | 30, x1.9 |
| Sprout | trees 7% sooner | 6 s | 20 | 15, x1.65 |
| Room | one more tree | 3 | 27 | 12, x1.5 |
| Seeds | the next tier | saplings | none | 120, x7 |

Four tiles stop because a circle cannot outgrow the land and the land holds
about thirty trees.

## 4. How slow it is

`tests/_probe_grove.gd -- pace` plays the real sim with a player who holds
the circle on the oldest tree and buys the cheapest tile it can (2026-10-05):

| Player | Birch | Oak | Pine | Then |
|---|---|---|---|---|
| 8 visits a day of 2 minutes | day 5 | day 21 | day 59 | day 60: Axe 20, Room 16 of 27 |
| 6 visits a day of 10 minutes | day 2 | day 8 | day 21 | day 21: Axe 20, Room 16 of 27 |
| 2 hours without stopping | at 1 h 42 | no | no | Axe 9, Room 7 of 27, 1,726 wood |

**2026-10-06, the land 1300 tall instead of 800** (the tiles went into the
shop's card and the land took their room): the same three runs read the
same, Birch on day 5, Oak on day 21, Pine on day 59; day 2, 8 and 21; Birch
at 1 h 42 with Axe 9 and Room 7. The bot chops one tree at a time, so it
does not say what a wider-spread land is to a person sweeping the circle
over several.

**2026-10-06, the land in isometric**: one flat square of ground seen
corner on, about half the ground of the rectangle (a tree chopped along the
line it stands on). Birch on day 5 and Oak on day 21 for the eight visits of
two minutes, as before; day 2, 7 and 20 for the six of ten minutes; Birch at
1 h 42. `docs/agents/valley.md` has the land's rules and what the bot does
not measure.

**2026-10-06, a level of the Axe adds half a point** (`Sim.AXE_STEP` 0.5;
it added one, and the user: "it's too fast at start going from 1 -> 2, let's
do 1 -> 1.5"). A tree's hp may be a half after a chop. The three runs,
each taken before and after: Birch on day 5, Oak on day 21, Pine on day 59
with Axe 20 and Room 16 on day 60 both times (70,311 wood against 70,651);
day 2, 7 and 21 (Pine was day 20: 20.1 hours played against 20.0); Birch at
1 h 42 with Axe 9 and Room 7 and 1,697 wood both times. **The bot's grove
waits on trees coming up, not on the axe**, so halving what a level adds
changes how many chops a tree takes and hardly how long the grove takes; a
person sweeping a full late land is the case it does not measure.

## 5. The screens

- **The tab** (`ui/menu/valley_tab.gd`): the wood pill and the Grove's card,
  whose picture is the land as it stands, read from the file and growing in
  front of you, with a bar of trees over room. Play writes the grove back
  first, so the screen opens on the trees the card was showing.
- **The Grove** (`valley/grove_screen.gd`): the top bar, two plates (energy,
  wood), the pond with the land in it, the count, six tiles (since
  2026-10-06 on a card of their own, behind a Shop button). Its own host
  like an Arcade screen. Drawn flat in our palette, not the reference's
  pixels; trees have no faces. A tutorial of three pages (chop, wood and
  energy, trees take their time).
- No timer, no days, no end card. Leaving a place shows no interstitial.

## 6. Not built, on purpose

Every other place; automation ("no automation yet"); the reference's chests,
critical hits, timed days and skill tree; ads of any kind; a land that
grows; cloud save (the valley is on the device, like gold).

## 7. Open

- **Energy** is the Grove's word and its picture was a green spark; since
  2026-10-06 it is Peapod's mote of light (`ui/motes.gd`), by the user's
  word, the number still the Grove's own. The user
  also described a later game that makes *power* for the others; the words
  are close and nothing here settles what the next place calls its own.
- **Past Blossom** the looks repeat (Birch II, with one gold mark). Whether
  every tier wants its own tree was asked on the page and not answered.
- The numbers were judged on the page and by the probe's bot, not by a
  person playing for a week.
