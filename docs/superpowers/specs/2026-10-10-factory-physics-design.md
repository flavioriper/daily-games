# Factory: the physics ledger

2026-10-10. The numbers every Factory era obeys, written before the first
build so that no later era invents a power source or a recipe that the
earlier ones contradict. The user's brief: "really slow but funny to play",
and "as physic assertive as possible related to power resources, items
resource and building". The roadmap is `docs/brainstorm/factory-roadmap.html`;
the first build is `2026-10-10-factory-board-and-hand-era-design.md`.

The two reference games are named in the roadmap once, to forbid them, and
not here.

## 1. What "honest" means here

Masses, energies and powers are real: a log weighs what a log weighs, a
kiln burns what a kiln burns, a steam engine wastes what a steam engine
wastes, and a tile of solar panel gives a tile's worth of sun. **Nothing
runs faster than its energy allows**, and every machine's rate falls out of
its rated power and the energy its work takes. The player never sees a
joule, but they feel the ratios: a fire that lasts, a saw that eats little,
a smelter that eats everything, a solar farm that needs a whole plate.

Three things are bent, each once and on purpose:

1. **The clock.** The game runs at **4x**: a real second is four game
   seconds, a real minute is four game minutes, a real day is four game
   days. Every duration below is derived from real energy at real power and
   then divided by four. The player sees real seconds. (At 1x a lime kiln
   takes a shift to fire one stone; at 60x a belt would be a blur.)
2. **Trees.** A tree regrows in game hours, not decades. Rocks, likewise,
   never run out: a plate bought is never used up.
3. **Belts draw no power.** A ten-metre slat conveyor carrying a few logs
   draws tens of watts against a saw's thousands; the ledger rounds it to
   nothing and says so here.

Nothing else is bent, except that the last era is allowed one wonder: the
core and the pads of era 7 have no honest basis and say so in their rows.
Where a real figure is a range the ledger picks a middle value and names
it.

## 2. Units and the clock

| Thing | Unit | Shown to the player as |
|---|---|---|
| Mass | kg | never (an item is an item) |
| Energy | MJ (fuel), kWh (engine and electric) | never |
| Power | kW | a meter, supply over demand, no figure |
| Length | m; **a tile is 2 m by 2 m**, a plate 16 m square | tiles |
| Time | game seconds, 4 a real second | real seconds, minutes |

The sim ticks at 10 Hz in real time (0.4 game seconds a tick) and every
rate is a float per game second; a tick advances each machine's work by
`rated_kw * share * 0.4 / (recipe_mj * 1000)`, kilojoules over kilojoules.

## 3. Items

Every item has a mass, a size on a belt, and if it burns a heat value. A
recipe conserves mass up to a stated loss; the loss is named (sawdust,
driven-off carbon dioxide, slag) and goes nowhere. Prices are the game's,
in coins, rising with value added; they are listed in each era's spec, not
here.

| Item | Mass | On a belt | Burns at | Notes |
|---|---|---|---|---|
| Log | 20 kg | a half tile, like every item | 16 MJ/kg, 320 MJ | 1 m long, 20 cm through, air-dried hardwood at 640 kg/m³ |
| Stone | 20 kg | a half tile | no | limestone; a quarry's rock chips 20 kg a chip |
| Lime | 11 kg | a half tile | no | quicklime; limestone loses 44% as CO₂ when burnt |
| Charcoal | 5 kg | a half tile | 30 MJ/kg, 150 MJ | a retort keeps a quarter of the log's mass as charcoal |
| Plank | 4 kg | a half tile | 16 MJ/kg, 64 MJ | four a log; 20% of the log is sawdust |
| Coal | 20 kg | a half tile | 27 MJ/kg, 540 MJ | bituminous, a drill's chip |
| Iron ore | 20 kg | a half tile | no | about 60% iron by mass |
| Ingot | 10 kg | a half tile | no | a bloomery yields about half the ore's mass as iron |
| Nails (box) | 5 kg | a half tile | no | two boxes an ingot |
| Chair | 12 kg | a half tile | 16 MJ/kg | three planks |
| Table | 28 kg | a half tile | no | six planks and a box of nails |
| Sand | 20 kg | a half tile | no | a shore's shovel |
| Glass | 8 kg | a half tile | no | sand and lime, 40% lost as gas and dross |
| Lamp, bicycle, circuit, radio, robot | later eras' specs | | | |

**Items are physical on the ground and on belts.** A log on a tile lies
there until a belt is laid on that tile; two items ride a tile at most, one a half tile; a belt that is full
waits. Nothing is destroyed except by the
market's sale and a retort's or kiln's burn.

## 4. Power comes in three kinds

Honest machines want one of three things, and a source gives one of them:

| Kind | What it is | Reaches | Sources | Sinks |
|---|---|---|---|---|
| **Heat** | a fire's thermal output, kW | the tiles touching the fire (a flue is not built) | firebox (logs, charcoal, coal), later the core | kiln, retort, boiler, smelter, glassworks |
| **Shaft** | turning power, kW | the tiles touching the engine, and along a **shaft** tile laid like a belt (a line shaft) | steam engine (from a boiler), water wheel, windmill | saw, lathe, joiner, stonecutter, nailer, dynamo |
| **Electric** | kW on one land-wide grid | every tile on the land (the lines are buried and never drawn) | dynamo (from shaft), solar panel, battery, the core | every era-5-and-later machine, and the lodge and drill once converted |

A sink draws its rated power while it has work and a little while idle
(the idle fraction is in the sink's row). Over demand, **every sink on that
source runs at supply over demand**: slower, never stopped, never tripped.
A fire with nothing drawing from it banks down to its idle rate and the
fuel lasts longer. Nothing is ever lost to a shortfall.

## 5. Sources

| Source | Era | Gives | Rated | Takes | Honest basis |
|---|---|---|---|---|---|
| **Firebox** (hand-fed) | 2 | heat | 60 kW, banked to 12 kW with no draw | one log, charcoal or coal at a time, lit by a tap; a hopper of five fed by belt | a small shaft kiln or masonry firebox; wood at 16 MJ/kg |
| **Stoker** on a firebox | 3 | the same | the same | feeds the next fuel when the fire dims | a mechanical stoker |
| **Boiler and engine** | 3 | shaft 7.5 kW | 94 kW heat in at full load (8% overall), 20 kW banked | sits on a firebox's heat | a small single-cylinder mill engine; 5 to 10% thermal efficiency, 8 chosen |
| **Water wheel** | 4 | shaft 3 kW | steady, no fuel | a pond plate's rim tile; three a plate at most | an overshot wheel on 3 m of head at 0.15 m³/s at 65%; 3 kW |
| **Windmill** | 4 | shaft 2 to 6 kW | varies over a game day on a slow sine, 4 kW mean | a hill plate's tile; three a plate | a traditional tower mill, 10 kW at best, 4 on average |
| **Dynamo** | 5 | electric | 90% of the shaft it is given | a shaft source's touching tile | a belt-driven DC generator |
| **Solar panel** | 6 | electric 0.8 kW peak a tile, 0.2 kW mean | follows the game day: a cosine from dawn to dusk, nothing at night | any tile | 4 m² at 200 W/m² peak; a day's mean a quarter of peak |
| **Battery** | 6 | electric | stores 20 kWh a tile, 95% round trip | charges from surplus, gives on shortfall | 100 kg of lithium cells at 0.2 kWh/kg |
| **Core** | 7 | heat and electric | 1 MW, then levels | nothing | the one source with no honest basis; the game's end is allowed one wonder |

**A game day** is six real hours (24 game hours at 4x). Windmills and
solar follow it; the sky over the land does too, gently. Nothing else
minds the time of day. Day and night are drawn from era 4; before it there
is nothing on the land that depends on them.

## 6. Sinks and recipes

Each sink's cycle time is its recipe's energy over its rated power, then
over four for the clock. Power draw during a cycle is the rated figure;
idle is the fraction given.

| Sink | Era | Wants | Rated | Idle | Recipe | Energy | Cycle (real) |
|---|---|---|---|---|---|---|---|
| **Kiln** | 2 | heat | 60 kW | 20% | 1 stone → 1 lime, 9 kg of CO₂ gone | 55 MJ (5 MJ a kg of lime, a traditional kiln) | 3 min 50 s |
| **Retort** | 2 | heat | 60 kW | 20% | 1 log → 1 charcoal, 15 kg driven off as gas | 32 MJ (10% of the wood's own heat, the rest the charcoal keeps) | 2 min 15 s |
| **Saw** | 3 | shaft | 7.5 kW | 15% | 1 log → 4 planks, 4 kg sawdust | 0.6 MJ (0.15 a cut) | 20 s |
| **Stonecutter** | 3 | shaft | 7.5 kW | 15% | 1 stone → 1 block | 0.9 MJ | 30 s |
| **Joiner** | 3 | shaft | 4 kW | 15% | 3 planks → 1 chair; from era 4 also 6 planks + 1 nails → 1 table | 0.3 MJ a chair, 0.6 a table | 19 s, 38 s |
| **Lathe** | 3 | shaft | 4 kW | 15% | 1 plank → 2 spindles | 0.2 MJ | 12 s |
| **Smelter** (bloomery) | 4 | heat, 15 kW from the fire; burns its own charcoal at 75 kW | 90 kW in all | 25% | 1 ore + 1 charcoal → 1 ingot, slag gone | 180 MJ (18 MJ a kg of iron; 150 of it is the charcoal's own) | 8 min 20 s |
| **Nailer** | 4 | shaft | 4 kW | 15% | 1 ingot → 2 nails | 0.5 MJ | 31 s |
| **Glassworks** | 5 | heat | 120 kW | 30% | 2 sand + 1 lime → 2 glass | 60 MJ (7.5 a kg of glass) | 2 min 5 s |
| **Assembler** | 5 | electric | 10 kW | 10% | three inputs, per product | per product | per product |
| **Lodge** | 3 | none in eras 3 and 4, electric 0.5 kW from era 5 | 0 | 0 | chops a tree in its reach every 45 s | the beavers' own | 45 s |
| **Drill** | 3 | shaft; electric from era 5 | 7.5 kW | 10% | 1 stone or 1 coal a cycle from the plate's rock | 2 MJ | 67 s |
| **Market** | 1 | nothing | 0 | 0 | sells so many items a second, by level; one thing lies on its hatch at a time, for the whole interval (2026-10-11; a counter of six before, the first sold as it landed) | | |

A machine that wants heat must touch a fire; one that wants shaft must
touch an engine, a wheel, a mill or a shaft tile that leads to one; one
that wants electric only needs a grid with something on it. **A kiln on a
firebox's far side from the boiler shares its heat**: 60 kW split by draw,
so a firebox feeding both a kiln and an engine runs both slow, and the
player learns to give each its own fire.

In eras 3 and 4 the Lodge chops with no power (beavers) and the Drill
wants a whole engine to itself (7.5 kW, a small steam drill); from era 5
both take the grid, the Lodge with a lamp, chopping twice as fast.

## 7. What a fire does over time

A fuel item lit in a firebox burns at the firebox's draw. The firebox's
draw is the sum of what touches it, rated when working and idle when not,
capped at 60 kW and never under 12 kW while lit. When a fuel's energy is
spent the fire dims; with a stoker and a hopper the next item lights
itself, without them it waits for a tap. Worked examples at 4x:

| Fire feeding | Draw | A log lasts | A charcoal lasts | A coal lasts |
|---|---|---|---|---|
| nothing (banked) | 12 kW | 1 h 51 min | 52 min | 3 h 7 min |
| one kiln, working | 60 kW | 22 min | 10 min | 37 min |
| a boiler, engine at full | 60 kW (the boiler wants 94, the fire gives 60: the saw runs at 64%) | 22 min | 10 min | 37 min |
| a boiler at the firebox's own level 2 (90 kW) | 90 kW | 15 min | 7 min | 25 min |

So **a tap on the fire is once every twenty minutes**, calm by the user's
rule, and the stoker is bought for leaving the plate, not for relief. The
firebox's levels raise its cap (60, 90, 120 kW); the boiler's raise the
engine's shaft (7.5, 10, 15 kW) and its hunger with it.

## 8. Belts and shafts

| Thing | Era | Speed | Carries | Honest basis |
|---|---|---|---|---|
| **Belt** | 1 | 0.25 m/s (a tile in 2 real s) | **two items a tile**, one a half tile, whatever the item | a slat conveyor; an item a real second |
| **Fast belt** | 3 | 0.5 m/s | the same spacing | a rubber belt |
| **Express belt** | 5 | 1 m/s | the same | |
| **Splitter**, **merger**, **bridge** | 3, 4, 5 | the belt's | one item in flight a side | |
| **Shaft** | 3 | carries shaft power, loses 3% a tile | one source a line | a line shaft with bearings |
| **Drone pad** | 6 | one item a trip, 4 m/s, between two pads | | |
| **Pad** | 7 | at once | | the wonder's second half |

A belt neither spills nor stops: full, it waits, and what feeds it waits
behind it. A tile crossing a plate seam is a tile like any other.

## 9. Buildings

A module is bought with coins and **built on the spot by the beavers**
over a build time, the frame rising as they work. A module has a
footprint, a facing, an input side and an output side, and it stands on
the plate's ground (a wheel on a pond's rim, a mill on a hill). Nothing is
built faster by tapping. Sold back, it returns its full price at once and
what was on it lies on its tiles.

| Module | Footprint | Build time | Faces | In | Out |
|---|---|---|---|---|---|
| Belt | 1x1 | at once | four ways | back | front |
| Market | 1x1 (2x2 until 2026-10-11) | given | none | any of its four sides | none |
| Firebox | 1x1 | 20 s | none | hopper on any side | heat to all four |
| Kiln, retort | 1x2 | 40 s | four | back | front |
| Boiler and engine | 2x2 | 60 s | none | heat from any side | shaft to all four |
| Saw, stonecutter, joiner, lathe, nailer | 1x2 | 40 s | four | back | front |
| Water wheel | 1x2 on a rim | 60 s | along the rim | | shaft inland |
| Windmill | 2x2 | 90 s | none | | shaft to all four |
| Smelter | 2x2 | 90 s | front | back | front |
| Lodge, drill | 2x2 | 60 s | front | the plate's trees or rock in reach (3 tiles) | front |
| Dynamo | 1x1 | 30 s | none | shaft from any side | the grid |
| Solar panel | 1x1 | 10 s | none | | the grid |
| Battery | 1x1 | 30 s | none | the grid | the grid |

## 10. What the player sees of all this

No figure in a unit. A fire is drawn at its draw: a bright roar under a
working engine, a low glow banked. A fuel item in the fire shrinks as it
is spent. An engine's flywheel turns at supply over demand; a saw's blade
and a kiln's glow too. The power bar beside the coins (from era 3) is one
bar a source kind, supply over demand, green to amber, never red, with no
number on it. A machine's card says what it makes, what it wants, its
level and its cycle in seconds, and, pressed and held, the plain sentence
behind it ("A log holds as much heat as this fire gives in twenty
minutes"): the one place the ledger speaks, for the curious.

## 11. What later specs take from here

Each era's spec takes its sources, sinks, items and modules from these
tables and adds prices, levels, the look and the tutorial. A number that
turns out wrong at play is corrected **here first**, with the honest basis
beside it, and the era's spec follows. A new machine gets a row here before
it gets a tile there.

## 12. The closed forest (2026-10-11)

The user, 2026-10-11: "the forest must be a closed grid that only output
the material, user should not be able to build inside of it, only upgrade.
It should have a output to connect convey in every side. User click on the
grid to farm wood, and the first upgrade is a wood / second automation",
and "remove mine keep only forest for now". Asked what the upgrade meant
they chose "Auto, 1 wood a second"; asked what a tap does, "One tap, one
log". **These are the user's numbers and they are not honest ones**: a
plate of fourteen trees does not give a log a second, and rule 2 of
section 1 (a tree regrows in game hours) no longer governs anything, since
a forest's trees are never felled. The forest is the ledger's second
wonder, beside era 7's, and says so here.

| What | Figure | Whose |
|---|---|---|
| A tap on a forest | 1 log into its stock, at once | the user's |
| A forest holds | 12 logs (`FOREST_ROOM`) before a tap is refused and its own work waits | an agent's |
| It gives by | a gate in each side, one log a gate a tick into what takes it beyond, the sides by turns; with no taker, one lies on bare ground past a gate | the gates the user's, the rest an agent's |
| Level 1 | 1 log a second by itself, 60 coins | the rate the user's, the price an agent's |
| Levels 2, 3, 4 | 2, 3, 4 logs a second for 180, 540, 1,620 coins | an agent's |
| The most a forest can send | 4 logs a second: a belt carries one a second (section 8) and there are four gates | follows from section 8 |

What this does to the rest: a level-1 market sells a log every 4 s, so one
automated forest makes four times what a new market sells, and **the
market's level is the brake on income now, not the trees**. A log is still
320 MJ in a fire box and 1 coin at the market. Stone, lime and the kiln
keep their rows above but nothing gives stone: the quarry is removed and
the kiln cannot be bought until a plate gives stone again. The meadow is
renamed neutral: white ground, the only kind that is built on.

## 13. The mine (2026-10-12)

The user, 2026-10-12, leaving the land to be built on unattended: "we need
to create new things to create with wood, the mine, add more convey
options". The mine comes back as **the forest's twin**, by the pattern they
chose on 2026-10-11, and not as the quarry of section 6 (rocks chipped
every three minutes, a drill on an engine): a closed plate, tapped, a gate
in each side, the same stock and the same levels. Like the forest it is a
wonder and says so: nine rocks do not give a stone a second.

| What | Figure | Whose |
|---|---|---|
| A tap on a mine | 1 stone into its stock, at once | the forest's rule, taken for it by an agent |
| A mine holds | 12 stones (`SOURCE_ROOM`) | an agent's |
| It gives by | a gate in each side, as a forest does | the forest's |
| Levels 1 to 4 | 1, 2, 3, 4 stones a second for 60, 180, 540, 1,620 coins | the forest's figures, an agent's |
| The kiln | in the drawer once a mine is owned (and a plate bought, as before) | an agent's |

Stone is still 20 kg and 2 coins, lime 10 coins, and the kiln's row in
section 6 stands: 55 MJ at 60 kW, 3 min 50 s a stone. So one kiln on one
fire turns a stone a second into a lime every four minutes: **the mine
outruns its kiln two hundred times over**, and what a mine is for, until
the stonecutter, is a belt of stone to the market at twice a log's price
and as many kilns as the player cares to light. The Drill's row and the
Lodge's in section 6 no longer describe anything that will be built.

## 14. More belts, and goals (2026-10-12)

The user, 2026-10-12: "add more convey options", and of the two reference
games the roadmap names, "use [them] as reference on web on features to add
to make the game progress". What was taken from them, and nothing else: a
belt that is faster, a tile that shares one belt among three, and things
opened by what has been delivered rather than by what has been bought.

| Thing | Figure | Honest basis, or whose |
|---|---|---|
| **Fast belt** | 0.5 m/s, a tile in a real second, the same two items a tile: two items a second | section 8's row, a rubber belt; 4 coins a tile (an agent's) |
| **Splitter** | a belt tile at the belt's speed; what crosses it leaves ahead and by each side in turn, one way after another; a way that takes nothing now (no belt, a belt pointing in, a full belt) is passed over, never waited on | section 8's row, brought forward from era 3; 15 coins (an agent's) |
| **Merging** | two belts into one tile take turns, as they always did | no tile of its own: section 8's merger is a belt run into another's side |

A plain belt becomes a fast one, or a splitter, for the difference in
price, and is sold back for what it is. **The bridge is not built**: it is
era 5's, and belts still cannot cross.

**Goals.** The market counts what it sells by kind from a land's first
sale (`sold`). A goal is so many of a thing sold, and reaching it opens a
module for good. All goals are open at once; none is lost by doing another
first; nothing is paid for one and nothing is given but the module.

| Goal | Opens | Why that many |
|---|---|---|
| 30 logs sold | the splitter | half an hour of a new market by hand, a few minutes of a forest at its first level: the first belt is long laid by then |
| 10 charcoal sold | the fast belt | ten cycles of a retort, 2 min 15 s each: a player who has kept one fire going |

The fire box and the retort are still opened by the first plate bought and
the kiln by a mine (section 13): a plate is a goal of its own kind.

## 15. Steam, and what wood becomes (2026-10-12)

The user, 2026-10-12: "we need to create new things to create with wood".
Era 3's wood side, built on the closed forest: the engine, the saw, the
joiner and the stoker. Their rows in sections 5, 6 and 7 stand, with what
is changed here.

| Thing | As built | Honest basis, and what moved |
|---|---|---|
| **Engine** | **one tile**, no facing; asks 94 kW of the fire box that touches it while a machine on it works and 20 kW banked; gives 7.5 kW of shaft at full heat, and its share of that at less | section 5's "boiler and engine", 8% overall. Section 9 gave it 2 by 2: it is 1 by 1, a vertical boiler with one cylinder on its side (a donkey engine of ten horsepower stands on a two-metre square) |
| **Shaft** | reaches the machines **touching** the engine, on its own plate, shared supply over demand like heat | section 4. **No shaft tile is built**: section 8's line shaft waits |
| **Saw** | 1 by 2; 1 log in, **4 planks** out one after another; 0.6 MJ at 7.5 kW, 15% idle | section 6's row: 20 s a log at full shaft. On a first fire box (60 kW of the 94 asked) it is 31 s, and 34 with an idle joiner on the same engine |
| **Joiner** | 1 by 2; **3 planks** in (gathered one at a time), 1 chair out; 0.3 MJ at 4 kW, 15% idle | section 6's row: 19 s a chair at full shaft. The table waits for nails |
| **Stoker** | fitted to a fire box once; the fire lights the next fuel in its hopper by itself, and one that is out with fuel waiting | section 5's row; a fire with one never needs a tap |
| **Plank** | burns in a fire box, 64 MJ | section 3 |

A saw and a joiner on one engine ask 11.5 kW of its 7.5 and both run
slower; a fire box at its third level (120 kW) gives the engine all it
asks. One log is four planks (8 coins at the market where the log was 1)
or a chair and a plank (14).

Prices and goals, the game's and an agent's:

| | Price | Opened by |
|---|---|---|
| Engine | 150 | 25 charcoal sold |
| Saw | 80 | 25 charcoal sold |
| Stoker | 100, once a fire box | 25 charcoal sold |
| Joiner | 120 | 100 planks sold |
| Plank sells for | 2 | |
| Chair sells for | 12 | |

**What it does to the pace.** The market is still the brake (section 12):
a sale is a sale whatever is sold, so a land's income is its market's rate
times the price of what reaches it, and the chair is the first thing worth
twelve logs a sale.
