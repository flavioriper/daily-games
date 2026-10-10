# Factory: the board and the hand era (spec one)

2026-10-10. The first build of Factory, the game that replaces the Valley
tab: the board of plates, the first two eras (by hand, fire), the tab swap,
the save, the tutorial and the harnesses. The long road is
`docs/brainstorm/factory-roadmap.html`; every number about mass, energy and
power comes from `2026-10-10-factory-physics-design.md` (the ledger) and is
not re-derived here. Later eras are later specs.

What the user said is quoted. The user's brief for the whole game: "really
slow but funny to play", "as physic assertive as possible related to power
resources, items resource and building", "no click to hurry, no anxiety",
"comfortable and lovely to play to any age player", "farm -> factory ->
sell", "the only way to create outcome is by selling", "no earning while
closed", "one money", isometric with no free camera, "fully replace the
valley tab ... all features will be within the game instead of splitted",
and plates "connected like a board" where "the user decide what is the
next grid to be placed".

## 1. What it is

A piece of land in a pond, seen corner on, the Grove's. Trees stand on it
and a market at its front. The player taps a tree, the beaver bites it
down, a log lies where it fell; a belt laid on that tile carries the log to
the market, which sells it. Coins buy belts, a second plate of land with a
kind the player picks, a fire and a kiln. The land only runs while the
player is on it, nothing is hurried, nothing is lost, and the game never
ends.

**Factory is the working name** and the tab's label until the user picks
one; the roadmap lists candidates. Nothing in code is named after either
reference game.

## 2. The tab

Factory takes the Valley tab's slot, sixth of the tabs, between Arcade and
Stats. Like Versus and Arcade it is not a registry entry.

- `ui/menu/factory_tab.gd` replaces `ui/menu/valley_tab.gd`: one card, as
  wide as the column, a live miniature of the land (the Grove's tab card
  drew the grove the same way, through `grove_life.gd`'s `place` on a
  smaller scale) with the coin count on a pill and the word Play. The
  miniature runs the sim: the land moves on the tab too, so a glance shows
  the belts going.
- `ui/menu.gd`'s `_open_valley` becomes `_open_factory`: mounts
  `factory/screen.gd` over the menu, joins the `versus_host` group so
  Android's back reaches it, closes back to the tab. **Leaving calls no
  `Ads.leaving_game()`**, as the Valley rule said: a land is looked in on
  for a minute.
- **The Grove goes in this pass**: `valley/grove_screen.gd`,
  `grove_sim.gd`, `grove_tree.gd`, `grove_life.gd`, `grove_art.gd`,
  `ui/menu/valley_tab.gd`, `tests/_probe_grove.gd`, `tests/_shot_grove.gd`
  and the `Stock` autoload (`core/stock.gd`, used nowhere outside the
  Valley; checked 2026-10-10). What the Factory reuses is moved into
  `factory/` first (section 9), so nothing is reached by its old path. The
  Grove's last state is commit `1f261898`.
- `user://grove.cfg` and `user://stock.cfg` are left where they are and
  never read. The Factory saves to `user://factory.cfg`.
- The Grove's tutorial pages go; the Factory's are section 11.
- `docs/agents/valley.md` is renamed `docs/agents/factory.md` and its
  Grove history kept under a heading that says the Grove was dropped on
  2026-10-10 and why; `CLAUDE.md`'s table row follows.
- Locale: `FACTORY_*` keys in `locale/ui.csv`, en/pt/es, every string on
  the screen; the Valley's `VALLEY_*` and `GROVE_*` keys are removed.

## 3. The board

The land is plates. A plate is a grid of **8 by 8 tiles**, a tile 2 m, drawn
as the Grove's land: one rounded diamond on a block of earth in the pond,
`Art.ground` as it is. Plates join edge to edge on a square lattice; the
seam between two is drawn as a low bank of turf and is a tile like any
other to a belt.

- **The first plate is a forest**, given. The market stands on its front
  corner (2x2, the four tiles nearest the front point), facing the land.
- **A plus stands on every free edge of the board** (a free edge is a
  plate's side with no plate beyond it). Tapping it opens the plate card:
  the kinds the era allows, each a tile with a picture and a line, and the
  price on a bar at the foot. Picking one builds the plate there: the earth
  rises out of the pond over 3 s (`Motion.rise`), the turf lays itself, its
  trees or rocks come up.
- **Price climbs with the count owned, not the kind**: the second plate 50,
  the third 150, then each 3x the last. A plate is never sold.
- **Kinds in this spec**: forest (trees), quarry (rocks), meadow (room,
  flowers, nothing to gather). Pond, hill and shore come with era 4 and 5.
- **The view** is the Grove's isometric, `Art.see`, no rotation. The board
  is laid out in world space and the field scrolls: a drag on open ground
  pans, with an ease out and a soft stop at the board's bounds plus a
  plate's width of pond. Two zoom levels, the Grove's scale and half of it,
  by pinch or by a round button under the coin pill; the button is there
  because a pinch is hard to explain to a child. (Your call pending on
  whether zoom exists at all; this is the default if you say nothing.)
- A new plate pans the view to show it, then leaves the view alone.

## 4. Era 1, by hand

**The forest plate.** Six trees up on a new land, at random stands as the
Grove placed them (`stands`: inside the edge, off the corners, and now off
the market and off any tile holding a module or an item). Trees keep
coming up at random to a cap of **ten a plate**, one every 90 s while under
the cap. A felled tree leaves a stump; **the stump grows the tree back in
4 minutes** (the ledger's one bend on biology), so a plate's trees are
never used up and a fuller forest is the reward of a plate bought.

**Chopping.** A tap on a tree calls the beaver, who bites three times at
the Grove's pace and the tree comes down the Grove's way: creak, drop,
settle, burst of leaves, chips flying. **A log lies on the tile at its
foot**, drawn as the Grove's pile of one. A second tap while the beaver is
at work does nothing; a tap on another tree calls a second beaver (three
beavers a plate at most, the fourth tap waits its turn, no queue shown).
Nothing hurries anything: a tap is the labour, and there is no tap that
makes a machine faster, in this era or any other.

**Rocks** stand only on a quarry plate (era 2). A tap chips a stone off
(the beaver does not come; the rock cracks and a stone rolls to the tile
in front of it). The rock then shows no crack for **60 s** and a tap on it
does nothing but a soft wobble; then a crack shows and the next chip is
ready. Three rocks a quarry plate. A rock never runs out.

**Belts.** One coin a tile, laid at once, 0.25 m/s, an item a metre (the
ledger, section 8). A belt is laid by picking it in the drawer and
dragging across tiles: each tile the finger crosses gets a belt facing the
way the finger left it, and a belt laid onto a tile holding an item takes
the item. A tap on a laid belt turns it a quarter clockwise. A belt's
front tile may be a belt, a machine's input side, the market, or nothing:
at nothing the item stops at the belt's end and waits, and what is behind
it waits too. Two belts feeding one tile from different sides both feed it,
alternating when both have an item ready (the honest behaviour of a side
load; a merger tile comes in era 4 only for the look of it).

**The market** is given, 2x2, and sells **one item every 4 s** at level 1,
taking from any side. An item that enters is sold for its price when its
turn comes; items waiting are shown as a small stack on the market's
counter, up to six, and the belt behind waits past that. The market's
level raises its rate: level 2 one every 3 s (price 30), level 3 one every
2 s (80), level 4 one a second (200), and on, each 2.5x the last, no cap
(Peapod's rule: price is the brake).

**Prices in this era.** Log 1, stone 2. Everything a player earns in era 1
comes from logs: about three a minute from six trees, five a minute from a
full plate of ten. The second plate (50) is bought at about twelve minutes
of play from a new land; a kiln's fire at about twenty. That is slow on
purpose: "really slow but funny to play". What is fun in those minutes is
the beaver, the first belt going, and the plate rising from the pond.

**Lesson of the era:** things ride belts, a laid belt is a decision, and
the plate chooses what the next twenty minutes are about.

## 5. Era 2, fire

Opens with the **second plate** (the first one bought), whichever kind,
because the drawer gains the firebox, the kiln and the retort at that
moment. There is no key module to buy; the plate is the key.

**The firebox** (20 coins, 1x1). A fuel item (a log, later charcoal and
coal) reaches it by belt on any side and lies in its hopper, five at most;
a tap on the firebox lights one. Lit, it burns at the ledger's rates: 12 kW
banked with nothing drawing, up to 60 kW with a kiln and a retort working
beside it. When the fuel is spent the fire dims to embers and **waits for
the next tap**; nothing that touched it breaks, it only pauses, calm. With
one kiln working a log is a tap every 22 minutes; the hopper of five is
nearly two hours. The firebox's fire is drawn at its draw (a roar under a
working kiln, a low glow banked) and the fuel item in it shrinks as it is
spent.

**The kiln** (40 coins, 1x2, faces four ways): stone in at the back, lime
out at the front, needs heat, so it must touch a firebox on one of its long
sides. A stone takes 3 min 50 s at full heat. Lime sells for **10**.

**The retort** (40 coins, 1x2): a log in, charcoal out, needs heat,
2 min 15 s. Charcoal sells for **4** or is fuel for the firebox: a
charcoal lasts 10 minutes where a log lasts 22, which is honest and which
the card says, so the player learns the retort is for the smelter of a
later era, not for burning.

**Sharing a fire**: a firebox touching a kiln and a retort runs both, each
at 60 over 100 of its rated draw; the card's cycle time lengthens to say
so. The player finds that each wants its own fire and buys a second
firebox. Heat does not cross a plate seam or a belt: only touching tiles.

**Levels**: firebox 60, 90, 120 kW (prices 60, 180, 540); kiln and retort
have no levels in this spec (a bigger kiln is the same kiln's rated power
in a later era's spec, if at all).

**Prices in this era.** A log tapped is 1; the same log as charcoal is 4;
a stone chipped is 2, as lime 10. With one kiln and one firebox a quarry
plate's three rocks (three stones a minute at most, 60 s a chip) keep the
kiln fed with room to spare, and the kiln is the brake at 3 min 50 s. A
second kiln on the same fire halves both. Era 2 ends when the player buys
the Stoker, which era 3's spec adds to the drawer with its price (400);
until era 3 ships the drawer ends at the retort and the land simply goes
on.

**Lesson of the era:** machines want power, a fire has a draw, and the
player felt the chore of lighting it just long enough to want a stoker.

## 6. Controls

- **The coin pill** sits at the top middle, `count_chip` style, counting
  up on a sale.
- **The drawer** is on the **left** edge (the building thumb is the right
  one; the thumb-side rule): a round button that opens a column of tiles,
  the Grove's shop tile cut down (picture on a disc, the name, the price
  bar that alone says whether coins reach; nothing faded). Tiles in this
  spec: Belt, Firebox, Kiln, Retort, and under a rule the Market's level.
  A tile not yet unlocked by the era is not shown. The drawer closes on a
  tap outside it, on Android's back, or when a module is placed; the belt
  stays picked until the drawer is opened again, since belts are laid in
  runs.
- **Placing**: with a tile picked, a tap on an empty tile stands the
  module facing the way the finger came from the market (so a kiln placed
  beside a belt faces along it); the price leaves the pill; the beavers
  build it over its build time with the frame rising; a tap on a tile it
  will not fit wobbles the ghost and places nothing. A ghost of the module
  follows the finger while it is held before the tap lands, so a child can
  see where it goes.
- **A tap on a placed module** opens its card (`Dialog.card`): the picture,
  what it makes from what, its cycle at the heat or power it has now, its
  level with the price of the next, and a Sell button that returns the full
  price; the card is where the ledger's plain sentence is, under a press
  and hold on the picture.
- **A tap on a belt** turns it a quarter. A **long press** on a belt or a
  module (0.5 s, a ring closing) sells it back; what was on it lies on its
  tiles.
- **A tap on a tree, a rock or a firebox** is the labour of sections 4
  and 5.
- **A drag on open ground** pans; **a pinch** zooms between the two levels.
  A drag that began on a tree is a pan, not a chop: the chop is the tap.
- **Every finger is a `ScreenTouch` or `ScreenDrag`**; the project has
  `emulate_mouse_from_touch` off and the Grove could not be chopped on a
  phone for that reason. The desktop mouse is read beside them.
- `Motion.reduce`: no beaver hop, no leaf burst, no frame rising; the
  module appears, the tree lies down in one beat.

## 7. The sim

`factory/sim.gd`, a `RefCounted` with no node, ticked at 10 Hz by whoever
holds it (the screen, the tab's card, the probe), deterministic from its
save and its seed, so that a harness can run it headless.

- `Board`: `plates: Dictionary[Vector2i, Plate]`; `Plate`: `kind`,
  `tiles: Array[Tile]` of 64; `Tile`: `module` (null, or a `Module` with
  `kind`, `facing`, `level`, `root` for a 2x2 or 1x2, `work` 0..1, `fuel`
  for a firebox, `hopper`), `item` (null or an item kind), `tree` (a
  `Tree` as the Grove's, with `stand`, `age`, `stump_at`), `rock` (with
  `ready_at`).
- **Belts move in one pass from the front of each chain to its back**: the
  sim first marks every belt whose front is free (nothing, a free machine
  input, the market with room), advances those items by the belt's speed,
  then walks back along each chain, so an item never advances twice in a
  tick and a chain shuffles as one. An item on a belt is `at` 0..1 along
  the tile; it leaves at 1 into the front tile at 0 if that tile accepts.
  Two feeders alternate by a `turn` bit on the fed tile.
- **Machines** hold one input item and one output slot; `work` advances by
  `rated_kw * share * 40 s / recipe_mj` a tick, `share` being the fraction
  the source gives (section 4 of the ledger); the output goes to the front
  tile when it accepts. A firebox's `fuel` burns down by its draw.
- **Heat** is resolved each tick before the machines: for each firebox,
  the touching sinks and their wants, capped at the firebox's level, the
  share handed back.
- **Money** is an int of coins; a sale adds the item's price. `Sim.earned`
  is the all-time total, for the tab's line and for milestones later.
- **The save** (`user://factory.cfg`): `version`, `coins`, `earned`,
  `seed`, every plate with its kind and every tile that holds anything,
  the market's level, the drawer's picked tile; written at most every 2 s
  and when the screen or the app is left (`NOTIFICATION_APPLICATION_PAUSED`
  and `WM_CLOSE_REQUEST`, as the Grove did). Nothing is recorded about
  the clock: the land has no notion of time passing while closed.
- `Sim.path` can be pointed elsewhere by a harness and `reload()` called.

## 8. The look

The Grove's painted look, `docs/art/shading-direction.md`, and its draw
plan under the 855 budget:

- **A plate's ground is one mesh** (`Art.ground`), built when the plate is
  bought and kept. The seam bank is part of the newer plate's mesh.
- **Belts are one MultiMesh** for the whole land: a tile an instance with
  its facing, the slats drawn once, a `wind_2d`-style shader scrolling the
  slat lines by time and the belt's speed. A belt laid or turned rebuilds
  the instance buffer, nothing else.
- **Items are one MultiMesh a kind**: a log instance, a stone instance,
  placed along its tile by `at`. Four kinds in this spec, four draws.
- **A machine is one cached mesh a kind** under a transform, and its moving
  part (the kiln's glow, the firebox's fire, the retort's smoke) a second
  instance of a shared mesh whose colour and scale say the draw. A frame
  rising during the build is the same mesh under a growing clip.
- **Trees, shadows, beavers, falls, stumps, chips and piles** are the
  Grove's `grove_life.gd`, moved to `factory/life.gd`, placed per plate.
- **The light** (`Art.light`) is one mesh over all. No motes: a mote was
  the Grove's energy and there is no energy here.
- **Targets**, 810x1440: under 150 draw calls on a new land, under 450 on
  a board of four plates with belts across all of them, measured on
  `opengl3_angle` too. The Grove's late land at 379 is the known floor.
- The market is a new building drawn in code (`ui/faces/` has nothing like
  it): a stall with an awning in the Grove's palette, a counter where the
  waiting items stack, and a shopkeeper who is a `Face` and not a picture.

## 9. What moves from the Grove

Moved, not copied, so there is one source: `valley/grove_art.gd` becomes
`factory/art.gd` (ground, pond, light, see, oval dropped, cast kept),
`valley/grove_tree.gd` becomes `factory/tree.gd`, `valley/grove_life.gd`
becomes `factory/life.gd` with the raft, jetty, crate and the grove's own
beavers' rows cut out, `ui/faces/beaver.gd` stays where it is. The shop
tile, `_tile` and `_draw_tile_icon` from `grove_screen.gd`, become
`factory/tile.gd` for the drawer and the plate card. The rest of the Grove
is deleted.

## 10. Sound and haptics

Named cues only in this spec, wired in a later pass under the cozy rules
(`docs/agents/sound.md`, the standing guideline at its top): chop (the
Grove's dry tick, kept), fell (the Grove's, kept), chip, lay (a belt tile,
the low tick), turn, place, built, sell (a low tock, a semitone a sale,
held at five), light (a soft whump, low), plate (the earth rising, a
breath). A belt makes no sound. Haptics to match, `docs/agents/haptics.md`,
every sound felt, the fire's light the ECHO kind.

## 11. Tutorial

`screen_tutor.gd` pages, as Versus and Arcade have, shown once on a new
land and again from the ? button: (1) tap a tree, (2) drag a belt from the
log to the market, (3) buy a plate from the plus. Three pictures, three
lines, no reading needed to get through them. The fire's tap is taught by
the firebox's own card the first time one is bought.

## 12. Harnesses and measurement

- `tests/_probe_factory.gd`: headless, drives the sim: a tap fells a tree
  and a log lies; a belt laid under it carries it; the market sells at its
  rate and no faster; two feeders alternate; a full belt waits and nothing
  is lost; a firebox banked lasts the ledger's time to the tick; a kiln on
  a shared fire runs at 60 over 100; a sold module returns its price and
  its items lie; a save round-trips; the clock while closed changes
  nothing.
- `tests/_shot_factory.gd`: windowed, `--resolution 810x1440` before
  `--script`, `--always-on-top`, under `caffeinate`, one at a time, two
  readings: a new land, the land at twelve minutes, a board of four plates,
  the drawer open, a card open, the plate card, each on `opengl3_angle`
  too and under `Motion.reduce`. Pokes on one frame, `force_draw()` on the
  next, presses with `ScreenTouch`.
- **The pace bot**: plays a new land in sessions of two minutes, tapping
  every ready tree and rock and laying belts as a sensible player would,
  and reports the play-minute of the second plate, the first lime, the
  third plate. The numbers in sections 4 and 5 are what it should find
  within a third; if not, the ledger is not changed, the prices are.
- The suite's parse guard walks `factory/`.

## 13. Decided here and still yours

Decided in the brainstorm: a free grid with hand-laid belts; items are the
only money through a market with a rate; one money; nothing while closed;
no hurry taps; fixed isometric; the Grove dropped and its art reused;
plates bought on an edge with a kind the player picks; the physics ledger
as the source of every rate.

Changed from the roadmap page by the ledger, and the page updated to
match: the saw needs shaft power, which fire alone cannot give, so **era 2
is the kiln and the retort** and the saw opens era 3 with the boiler and
engine; era 2 opens with the second plate rather than with a module.

Still yours, each with the default this spec takes if you say nothing:
the name (Factory); 8 by 8 tiles a plate; sell back at full price; power
with no wires (heat and shaft by touching, electric land-wide); rocks never
run out and trees regrow; zoom (two levels, pinch and a button); no reading
needed to play; the fire tended by a tap (one fuel item a tap, the fire
waiting dim between); belts from the first tap (a log lies and rides the
first belt laid on its tile).
