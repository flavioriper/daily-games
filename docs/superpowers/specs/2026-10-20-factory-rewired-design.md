# Factory, rewired (spec two): the robot line

2026-10-20. Factory stops being a land of forests, belts and a market
(spec one, `2026-10-10-factory-board-and-hand-era-design.md`; Tally now
owns belt-and-machine building) and becomes a floor of robots the player
programs with nodes. The brainstorm and the clickable prototype are
`docs/brainstorm/concepts.html`, tab "Factory · rewired" (the same page as
the artifact at https://claude.ai/artifact/3Qk54m6rgHjqbRwGpo4grY). This
spec covers the first build, milestones 0 and 1 of the road (the user,
2026-10-20: "let's end at milestone 1 end"); milestone 2 (Repeat, a fourth
robot, Big cell) is specified below because the first build's node model
must carry it, but it is built in the next pass; milestones 3 to 6 are
described only as far as the first build must leave room for them, and
get their own spec later.

The genre's reference is *The Farmer Was Replaced*, named here once so it
is never named in code, comments, commits or on screen (the renamed-genre
rule). Factory is the working name until the user picks one.

**What the user said**, in order, 2026-10-20:
- "let's change factory to have a different concept based on [the
  reference game], we gonna use the same components (or max we can reuse)
  but users will now use nodes like to generate automations, so they can
  learn basic concepts of automation and logical thinking"
- "a small robot that can pick it and drop it, but has a incomplete node
  where it is just moving from place A to place B, back to place A, but
  not performing the picking action for a missing node"
- "it's gonna be a incremental game based on automations, so there is no
  phase"
- "let's avoid adding truck to it ... conveys, automations with robots
  that carry boxes, check quality, organize, maybe add items to the box
  ... the challenge is user learning how to handle linked nodes ... adding
  new nodes features as the game goes, for example loopings, decisions"
- "the grid will have a deliver point at one side where droped boxes
  enters somewhere on a convey, and at other side we have a convey that
  brings colored squares that should be packed together, tagged properly,
  and delivered (this is direction complexity goes)"
- "let's start with the full frame but with robots broken to make it
  easier to understand, the first convey with a lot of gray squares, boxes
  to be used and the picking bot idea. Later we gonna add the label
  concept with different color squares, but not now"
- "nodes should be way way low level for now, it's literally a move node
  where user add the steps number, a pick, release, we gonna make it
  literally minimal as possible for this initial"
- "the idea of nodes being low as possible is to let user deal with node
  for example, being able to create a useless workflow moving to the wrong
  place. We can also maybe think a concept of giving user the power to
  create the bots, for example with a default body, and user can add
  submodules (that gives the bot workflow node types) for example a
  Caterpillar treads that gives move node type, the pick and release one
  that adds pick/release nodes type"
- "add a place where robot recharge, so user gonna feel the bad decisions
  by having to recharge more often"
- "shared dock for now, we can use a battery submodule that later can
  change plug type to add more complex"
- the road: "when user is comfortable on current workflow, we can add
  colored squares with a scan submodule that can identify colors, and a
  tag machine that add a stamp to the box, so user will have to organize
  on box by color, and keep it organized to tag it properly. Later we can
  use same comfortabel approach to add different shapes, and force user
  to use scan to see shape or color, having to change workflow"
- "instead of making milestone by boxe quantity, let's make a boxe by
  second, so we can make sure user will not just keep waiting"; "hold
  minute is great"

## 1. What it is

One factory floor that fills the screen. On the left a belt brings grey
squares in; on the right a belt takes boxes out. Between them a stack of
empty boxes, a pack table and a charging bay. Three robots stand on the
bay. Each robot is a body with parts fitted under it, and each part puts a
kind of node on the robot's program sheet: Treads give Move, a Gripper
gives Pick and Release, a Battery gives nothing but holds the charge. The
sheet is the robot's whole program: a chain of nodes wired from the body
and back to it, run forever. On day one all three programs are broken in a
different way, nothing ships, and the player's first job is to read three
loops and fix them. From then on the floor only grows: belts, plugs, a
fourth robot, Repeat, and later colours, stamps and shapes. There are no
levels and no end. Nothing runs while the floor is off screen; there is no
catch-up (the Factory rule stands).

The game teaches by letting the player build useless programs: a robot
that walks to the wrong tile, releases on the floor, bumps into a wall or
wanders until its battery is flat does exactly that, visibly, and costs
time. Every step costs charge, and charge is only put back at the one bay,
so a wasteful route is paid twice.

## 2. Goals, non-goals, anti-goals

Goals: the three-fault opening is understood without words (the tutor
helps, it does not carry it); a program is edited with a thumb in under
ten seconds; the floor keeps running while the sheet is open, so every
edit shows its effect within one loop; the pace pill tells the player what
the next milestone asks.

Non-goals for this build: colours, shapes, scanning, stamps, orders,
quality, signals, routines, a second bay (section 9 says what to leave
room for). No offline progress. No price curves (Factory prices stay
flat). No truck. No free camera beyond pan and the existing zoom.

Anti-goals: a program that crashes or deadlocks the floor (every failure
is soft and visible); a node with hidden settings; a wait node, a go-to
node or any node that does the player's thinking; a tutorial that fixes
the robots for the player; the old Factory's goals, eras or ledger coming
back in another coat.

## 3. The floor

A grid of tiles, 10 wide by 8 high, **drawn top-down**, square tiles
aligned with the screen, full bleed with the top bar and pills over it (the
world-fills-the-screen rule). Coordinates are `Vector2i`, +x right on
screen, +y down on screen, a facing is an index of `DIRS` as in `sim.gd`
today. The corner-on projection of the land (`Art.at`, the `K`/`DEEP`
constants) and the quarter-turn view button go: a Move arrow on the sheet
must be the direction the robot walks on screen, or the read-a-loop lesson
breaks. (My call, the one the prototype embodies; it overturns the turn the
land had, which has no purpose on a square floor.) Tiles are open floor
unless listed:

| Thing | Tile | What it does |
|---|---|---|
| Intake belt | column 0, running down | Delivers grey squares to the intake pad. Holds up to 6 queued, one more every 10 ticks. |
| Intake pad | (1, 5) | A Pick here takes a square from the queue, if any. |
| Charging bay | (1, 1) | The one place a robot charges (section 4). Any number of robots stand on it. A cable to the wall is drawn, nothing more. |
| Box stack | (4, 1) | A Pick here always gives an empty box. |
| Pack table | (4, 5) | Holds nothing or one box. A Release of an empty box onto an empty table sets it down. A Release of a square puts it in the box if the box has fewer than 4; otherwise the robot waits (`…`) and retries each tick. A Pick here gives the box only when it holds 4. |
| Deliver pad | (8, 5) | A Release here sells what is held (section 7) and the thing rides the deliver belt off the top of the screen. |
| Deliver belt | column 9, running up | Drawn; carries the sold thing away. |

Items: `square` (grey), `box` with 0 to 4 squares. Any tile of open floor
may hold a stack of released items; a Pick on open floor takes the top
one. The box stack and the bay are not open floor, but a Release on them
drops to the floor like anywhere else (a robot can litter the bay).

Belts the player lays (milestone 1) are the belts `sim.gd` has today:
`lay_belt`, `turn`, `flip_line`, `line_through`, bridges, the fast belt,
the pill and the Tally-style tracing in `screen.gd` (`_trace_to`,
`_trace_straight`, `_path_run`, `_lay_path`). The splitter leaves (nothing
splits). A belt carries items as it does now. A robot walks over a belt
tile as over floor; belts never block or carry a robot. A Release onto a
belt tile puts the item on the belt (`put`); a Pick on a belt tile takes
the belt's front item (`front_of`). An item a belt delivers onto the
intake pad, the table or the deliver pad behaves as a Release there would:
the table takes a square into a box with room, the deliver pad sells. A
belt whose end feeds a tile that will not take the item waits, nothing is
lost, as today. The intake belt and the deliver belt are drawn by the view
and are not belts the sim moves items along; the intake is a queue, the
deliver pad a sale. (My call: this keeps milestone 1 to "a belt from the
intake pad to the table halves the picker's walk".)

**Amended 2026-10-21 (the user overturns "drawn top-down").** The user,
on the build: "factory redesign is wrong, it was suppose to use at most the
elements factory already had on design, not recreate them all", and asked
to "use the same components (or max we can reuse)". So the floor is seen
**corner on, as the land was** (`Art.at`, `ISO`, `K`, `DEEP`), one plate of
10 by 8 on the pond with its shore, washes, `water` and `light`, and the
**quarter-turn view button is back** (`life.turn`, `seen`/`tile_at`). The
read-a-loop lesson is kept the other way round: **a Move's arrow on the
sheet is drawn on the diagonal the robot walks on screen at the current
turn** (`sheet.arrow_of`, the facing turned with the view through
`Art.ISO`), and the sheet is redrawn on a turn. The sim is unchanged
(its tiles, +x and +y, facings and stations). The stations are the land's
own pieces: the intake and deliver columns are its belts under the belt
material (the intake down column 0 and round a bend into the intake pad,
the deliver belt from the market up column 9, both driven for show); the
deliver pad is the market's hatch, its leaves swinging on each sale; the
charging bay is the engine, its flywheel turning while a robot charges;
the pack table is the joiner's out-tray alone on its tile, made big enough
for a box; the box stack is empty boxes heaped as `HEAP`/`heap_of` heaped
logs. New art only for the robot (body, treads, face from `ui/faces/`,
bubble, battery bar), the node sheet, the grey squares and the boxes, the
last two corner on in the land's item style. Calls the builder made are in
`docs/agents/factory.md`.

**Amended again 2026-10-21 (the corner-on view is overturned the same
day).** The user, on the corner-on build: "now redesign it again to keep
current visual elements, but make it topdown like the previous version".
So the grid is this section's own again: **square tiles aligned with the
screen, +x right, +y down**, the 10 by 8 floor filling the screen, **no
turn button**, and a Move's arrow on the sheet is → ↓ ← ↑ as the robot
walks. **The corner-on pieces are kept** (the plate on the pond with its
earth, the light, the shader belts with their bends, legs and bridge, the
market's hatch and its sale, the engine and its flywheel, the tray, the
box heap, the robots, squares, boxes, bubbles and bars), re-projected at
the root: `Art.at(t) = t * 104` (a tile 104 view units, K 52), the ground
not foreshortened, and what stands rising up the screen a view unit for a
view unit of height (a mild three-quarter oblique: a piece shows its top
and its front). The plate's earth shows on its front edge only. Everything
above on the stations and the new art still stands.

**Amended a third time 2026-10-21.** The user, on the top-down build:
"redesign it so it has no water showing, both side convey should take the
full height, the convey that receive queue item at end, the conveyh that
delivers finished boxes keep running up. Also, remove the bots types at
top, user click on bot to check node, there is no distinction between
pick, deliver, since they are all the same with different submodules".
So: **no water anywhere** on the screen or the tutor's pages: the ground
(the neutral plate cut straight on every side) goes on past the floor
(`Life.GROUND`, 2 tiles either side, 16 above and below) and the view
never shows past it; the far zoom (its button, the pinch, the wheel) is
gone, since the floor is as wide as the screen. **The floor is 10 by 12**
and the work row (intake, table, deliver) is its bottom row, the bay and
the stack four rows above (`Sim.WORK_ROW`, `WORK_UP`), so every program
and the tutor's "Move ↓ 4" are unchanged. **The intake belt runs straight
down column 0** the floor's whole height, no bend, and the squares queue at
its end beside the intake pad, back up the belt; **the deliver belt** is a
bend at the market's side, then straight up column 9; both go on up
through the ground off the top of the screen. The view stands the floor's
foot on the screen's and pans only between that and the floor's top row
under the pills. **The robot chips are gone**: a robot is tapped on the
floor; a robot with a fault the player can see wears a red dot on its
shoulder; the robots have no job names ("Robot 1", "Robot 2", "Robot 3"
on the sheet and in the tutor), keeping their tints. Save `VERSION` 6.

**Amended a fourth time 2026-10-22 (the room).** The user, on the 10 by 12
build: "redesign factory to be way more elegant, fit the board to the
height and make the width wider to avoid making it stretched, instead it
should be more space on landscape. Also, right now the recharge is weird
to see, move it to the wall somewhere, with some marked area with a
lightning ... polish bots way more to be more cozy ... everything look way
too poorly draw". So: **the floor is 10 by 5**, the rows the loops walk
and no more (`Sim.ROWS` 5, `WORK_UP` 4 unchanged: the bay and the stack on
row 0, the pads on row 4; every program, the pace numbers and the tutor's
"Move ↓ 4" unchanged), and **it is a room**: a back wall stands along its
top edge (`Art.WALL_TALL` 64 view units of face, its top `WALL_TOP` 12
seen from above) with a doorway over each of the floor's two belts, hung
with a strip curtain, two windows and a clock; the side walls show their
tops only and the front a low kerb. **The charger hangs on the back wall**
over the bay, a cable down to a socket on the bay's pad, its lamp lit
(breathing) while a robot charges; the bay's tile is a painted charging
pad, yellow with a hazard border and a bolt; every other station's tile a
plain painted pad. The land's engine leaves the floor and the Arcade card
(the card shows the wall and the charger). **The view fits the room's
height** to the field's free height (under the pills, over the safe area),
the room wider than the field, and pans sideways only; with the sheet up
the room shrinks to fit the strip over the sheet, so the whole floor shows
while a program is edited; it opens on the room's left end (the bay, the
intake). The tutor's pages stack the room over the sheet. **The robots are
redrawn** (capsule treads, a chunky drum with a bumper and a lid, a cream
face plate on the lid, a gold bulb; the heading is a chevron on the floor
past the treads, since the face took the lid) and the floor is a floor of
slabs. Save `VERSION` 8 (a 7 floor quietly wiped). Builder's calls, none
judged by the user: five rows and not six (an apron in front was
considered); the room's width on screen (about 2.5 fields at 810x1440; a
smaller tile would shrink the robots); the chevron on the floor; the lamp's
breath; the windows and the clock.

**Amended a fifth time 2026-10-22 evening (the big room, one robot a
tile).** The user: "make the grid bigger, we want at least 3x more cells in
the column, it's too close right now. Also, bots should never fill the same
cell of another bot, or boxes or things like that"; asked, they chose 30 by
15 (it pans), a robot working a station from the tile it faces, a blocked
step that waits, and three charging pads. So: **the floor is 30 by 15**,
fit to height as before (about 62 px a tile at 810x1440, some 13 columns
in view); the first floor's stations sit in its back left corner
(`Sim.WORK`, 7 by 6): the three pads on row 0 under the one charger, the
stack at (3, 2), the table at (2, 4), the market at (5, 4), the intake pad
at (1, 5) by the intake belt's end; the intake belt comes down column 0 to
row 5 only, the deliver belt leaves the market's side up column 6 to the
wall, and the rest of the room is open floor. With the sheet up the view
fits that corner, not the room, and pans up and down to keep the picked
robot in the strip; the tutor's pages frame the corner. Save `VERSION` 9.
Section 4's "robots share tiles freely and never collide" is overturned:
see its amendment.

## 4. Robots, parts, battery, bay

A robot is `{name, dock, parts, nodes, next, pc, tile, held, charge, ...}`.
All three docks are the bay. Robots share tiles freely and never collide
(my call; it avoids every deadlock before the player has a way to
coordinate robots).

**Amended 2026-10-22 evening (one robot a tile).** Each robot has its own
dock, one of the bay's three pads (`Sim.BAYS`), and charges only there. A
robot never stands on a station (but its own pad), a belt (laid or drawn),
a thing lying on the floor or another robot (its tile, or the one it is
stepping off): `Sim.blocked`. A Pick and a Release work the tile the robot
faces (`Bots.ahead`), never the one it stands on, so every station is
worked from beside it. A step onto a tile taken waits with the `...`
bubble, for no charge, and is tried again every tick; two robots walking
into each other wait for good, which is soft and visible (the anti-goal
stands as "no crash, nothing hidden"), and is the player's to fix. A belt
is never laid under a robot (`refused` "robot") and nothing is let go onto
one. The first floor's three loops each walk a lane of their own and never
wait on one another once fixed: the Picker down column 1 to face the
intake, then the table on its right; the Boxer down column 2 to face the
stack, then the table below it; the Shipper round by column 4 to the
table's right, then the market. Their faults: the Picker has no gripper
and no Pick (fix: fit it, Pick after the first Move); the Boxer's first
Move is 1, a tile short of the stack (fix: 2); the Shipper's wire after
its Pick is loose (fix: wire it to the Turn after it). Loops cost 14, 14
and 22 of 30. The pace bot reads 280 ticks a box (gaps 336, 224, 336), so
milestone 1 is 340 and 2 is 170 (the all fast floor reads 193).

Parts are a list of ids fitted under the body. The first build's parts:

| Part | Gives | Price | From |
|---|---|---|---|
| Treads | the Move node | spare: none | fitted on all three at start |
| Gripper | Pick and Release | spare: none | fitted on Boxer and Shipper; the Picker's lies in the bin, free |
| Battery | nothing; holds 30 units with the standard plug | spare: none | fitted on all three |
| Fast plug | nothing; charges 2 units a tick instead of 1 | 40 | the bin, from milestone 1 |
| Fast treads | Move at 2 ticks a tile instead of 4 | 30 | the bin, from milestone 1 |
| Second body | a fourth robot, standing on the bay with Treads, Gripper and Battery; on buying, the player picks an empty sheet or a copy of one of the robots' programs (the user: "user can copy another robot or create a new one") | 60 | the bin, from milestone 2 (next pass) |
| Big cell | the Battery holds 60 | 80 | the bin, from milestone 2 (next pass) |
| Counter | the Repeat node | 60 | the bin, from milestone 2 (next pass) |

Prices are flat (the Factory rule) and all placeholders to tune (my call).
A part is fitted and taken off from the sheet; a part taken off goes back
to the bin. Fast treads replace Treads' speed and also give Move; Fast
plug and Big cell are fitted beside the Battery and do nothing without it.
A robot whose program uses a node its parts no longer give draws the node
dashed and skips it with a `!` (section 5). A robot with no Battery stands
with `no cell` over it and runs nothing.

Charge: every tile stepped, every Pick, Release and bump costs 1 unit.
When the loop returns to the body (section 5) and the robot stands on the
bay, it pauses there and charges to full: 1 unit a tick (standard plug),
2 (Fast plug). The pause is the game's main cost, and the pace pill makes
it visible. A robot at 0 away from the bay stops where it stands, `flat`,
holding what it held; the sheet's body shows "Tow to the bay", which puts
it on the bay **with the charge it had (0)**, holding what it held, at the
body, so it charges a whole cell before it moves. Towing is free and
instant; the pause and the lost loop are the price (my call). Waiting
(`…`) costs nothing; only the Release that finally lands costs 1.

## 5. The program

A program is a graph of nodes with one input and one or more output ports
each, wired by `next[node][port] -> node | null`. The body is a node with
no input in the usual sense but an input bar for the loop-back wire, one
output port and the parts port underneath. The first build's nodes:

| Node | Setting | On the floor |
|---|---|---|
| Move | a direction (one of four arrows) and a count 1..9 | walks that many tiles that way, 4 ticks a tile (2 with Fast treads). The direction lives on the node, there is no Turn node (my call, embodied in the prototype). |
| Pick | none | 4 ticks; takes what the tile gives (section 3) into the hand, if the hand is empty; otherwise nothing. |
| Release | none | 4 ticks; puts down what is held as the tile takes it; with nothing held, nothing. |
| Repeat (milestone 2) | a count 1..9 | two output ports, `do` and `then`. Entered by its input from outside, it sets its counter to 0; entered by the wire that comes back from the end of its `do` chain, it adds 1. Below N it goes out by `do`, at N by `then`. The `do` chain ends by wiring into the Repeat's input. How it tells the two entries apart: a flag on the Repeat, set when it leaves by `do` and consumed by the next entry; passing the body clears every Repeat's flag and counter (my call; the sheet shows the count mid-loop, `pack()` saves flag and counter). |

The body costs 2 ticks and then goes out by its output. A chain whose last
node wires back into the body runs forever. Program state is `pc` (the
node id, "body" at rest), `t` (ticks into it) and `left` (tiles left of a
Move).

Soft failures, all of them visible and none of them fatal:
- An output wired to nothing: the robot finishes the node and stops with a
  `?` until the player wires it.
- A node whose part is missing: skipped with a `!`, 4 ticks, 1 unit.
- A Move into the edge of the floor: a bump, 4 ticks, 1 unit, the rest of
  that Move is dropped and the program goes on.
- Release where the tile will not take it (a square on an empty table, a
  box on a full table): the robot waits with `…` and retries every tick.
- Release on open floor: the item lies there. Pick on an empty tile: nothing.
- Flat: section 4.

Editing: any change to a robot's program or parts puts it on the bay at
the body **with the charge and the item it had**, so it charges there as
any loop end does before it moves; an edit never refills a cell (my call;
otherwise two taps on a node skip the pause, which is the game's main
cost). The floor and the other robots keep running through every edit;
nothing pauses while the sheet is open.

**Amended 2026-10-21 (the Turn node).** The user: "add a turn node so bot
has to turn before moving". A robot faces a way (down when new and after
every edit, kept from one loop to the next). A Move has a count and no
way: it walks the way the robot faces. A Turn (from the treads) turns it a
quarter right or left, in 4 ticks and a unit of charge, the same as a Pick.
A loop that comes back to the bay facing another way wears the fault dot.
The sheet draws each Move's arrow as the facing the chain reaches it with.
The rules are in docs/agents/factory.md, "The Turn node".

## 6. Time

The sim ticks at 10 Hz under the existing `step`/`_tick` (`TICK 0.1`,
`STEP_MOST 0.25`), deterministic, and every duration above is in ticks:
Move 4 a tile, Fast treads 2, Pick/Release/skip/bump 4, body 2, charge 1 or
2 units a tick, intake 1 square per 10 ticks. The 10 Hz step runs only
while the Factory tab or screen is shown, owned by `factory_tab.gd` as
today (one sim, lent to the screen, returned on close). The view
interpolates a walking robot between tiles with `alpha` as items are
interpolated now.

## 7. Money, the bin, pace and milestones

One money, coins. A Release on the deliver pad pays: a full box 6, a box
with n squares n, a loose square 1, an empty box 0. Lifetime `earned` is
kept for the card. The bin (section 4) sells parts and `lay_belt` sells
belts at their flat prices; a part or belt sold back returns its price as
`sell` does today.

Pace: the sim keeps the sim-time of every full box sold in the last 600
ticks; the pace pill on the floor reads "a box every N s" from the mean
gap of those, blank under two. A milestone has a rate and opens when the
rate has been met for 600 consecutive ticks ("held for a minute", the
user's choice), which, because nothing runs unseen, means a minute with
the floor on screen. A total of boxes never opens anything (the user:
"make sure user will not just keep waiting"). The milestones of this
build:

| # | Name | Opens at | Adds |
|---|---|---|---|
| 0 | The broken line | start | the floor of section 3, the three robots of section 8, Treads, Gripper, Battery |
| 1 | Walk less | a full box every 30 s | belts in the drawer; Fast plug and Fast treads in the bin |
| 2 | Do it again | a full box every 15 s | Counter (Repeat), Second body, Big cell in the bin. **Next pass**: the first build ends when milestone 1 is open and its bin rows work; the sim keeps the milestone row so the save carries it. |

Rates are placeholders (my call), and the builder sets them from play, not
from the table: the rewritten probe runs the three fixed programs with a
pace bot, reads the rolling window, and milestone 1 is set to what the
three fixes alone sustain, with margin, since the road says the three
fixes clear it (the tick arithmetic of this spec's numbers puts the fixed
Picker near 33 s a box before stalls, so 30 s is likely too tight);
milestone 2 is set the same way from belts and plugs. The rolling window
and the hold live in the sim and are saved as tick counts, never as a time
of day. A milestone once open stays open. The bin before milestone 1 shows
its rows as "later"; the tutor's sixth page points at the pace pill.

Also settled (my calls): every belt kind the drawer has today (belt, fast
belt, bridge) opens together at milestone 1, and no belt goes on a station
tile; the Second body is bought from a `+` chip at the end of the robot-chip
row and stands on the bay; a new floor starts with 0 coins.

## 8. The first session

The floor starts with all three robots on the bay, each with a fault. The
programs, as node chains from the body:

- **Picker** (Treads, Battery; no Gripper): Move ↓ 4, Move → 3, Release,
  Move ← 3, Move ↑ 4, back to the body. It walks to the intake, to the
  table and home carrying nothing. The fix: fit the Gripper from the bin,
  then insert Pick after Move ↓ 4.
- **Boxer** (Treads, Gripper, Battery): Move → 3, Pick, Move ↓ 3, Release,
  Move ↑ 3, Move ← 3, back. The down Move stops one tile above the table,
  so boxes land on the floor at (4, 4) and the up Move drifts it. The fix:
  both vertical Moves to 4.
- **Shipper** (Treads, Gripper, Battery): Move → 3, Move ↓ 4, Pick, then
  the wire after Pick is loose; Move → 4, Release, Move ← 4, Move ↑ 4,
  Move ← 3 sit wired among themselves and back to the body. It walks to the
  table, picks nothing (the table has no full box) and stops with a `?`.
  The fix: wire Pick to Move → 4.

The fixes work in any order (my call); the tutor suggests Picker, Boxer,
Shipper because each fix makes the next fault visible (the Picker stands
at the table holding a square with nowhere to put it; the Boxer's box then
fills; the Shipper's `?` is the last thing standing). The tutor is
`ui/hud/screen_tutor.gd` as on every Arcade game, with a first-play card
and six pages that follow the prototype's six steps: power on, the Picker,
the Boxer, the Shipper, the first box, spend. A page says what to look at
and what to tap; it never edits a program.

## 9. The road, and what the first build leaves room for

Milestones 3 to 6 are the prototype's: Colours (coloured squares mixed
into the intake, a Scan part giving `If colour?` with two outputs, a tag
press that stamps a box, a second table, a stamped same-colour box paying
10 and a mixed box 2), Shapes (circles and triangles, a Scan that sees one
property, `If shape?`, Wide scan, an orders board), Quality (cracked
pieces, a scrap bin, returns), Teams (a Bell part with Send and Wait, a
shelf, an Induction plug, a second bay). None of it is built now, but the
first build must not make it hard:

- `next` is keyed by node and output port from the start, and a node's
  port list comes from its kind, so a two-output node is a kind, not a
  rework (Repeat already needs it).
- Items are `{kind, colour, shape, squares...}` dictionaries with the
  fields unset, not strings.
- Stations are rows of a `stations` table (`tile -> kind`), so a second
  table, a press, a bin or a second bay is a row, and `what a tile gives`
  and `what a tile takes` are two functions over that table.
- A part declares the node kinds it gives and any numbers it changes
  (speed, cell size, charge rate), so Scan and Bell are rows of `PARTS`.
- The sheet draws a node from its kind's glyph, settings and port list; it
  must not know the four kinds by name.

## 10. The sheet

The sheet is a panel that slides up over the lower part of the floor when
a robot is tapped (on the floor, or its chip in a row of robot chips), the
floor still running above it and the camera keeping that robot in view. It
closes with a swipe down or the back arrow. Its grammar is the
prototype's, which follows a node-editor convention the user showed (a
rounded box with a glyph, a bar on the input side, a dot on the output
side, a `+` past a loose output, a `+` on the middle of every wire, a dotted
grid behind, the body as the start node with a bolt, parts hanging under
it on dashed wires from a diamond port, the loop-back wire drawn round the
top with an "again" label):

- Sizes in the 810-wide space: body 112, nodes 96 high, Pick and Release
  96 wide, Move 128 wide showing its arrow and count large; ports with hit
  zones of at least 80 px; the chain laid left to right from the body, the
  parts row under it; the pane pans sideways by drag.
- Tap a node: it is selected and a `ui/hud/piece_pill.gd` pill stands by it
  with its buttons: a Move gets `turn` (cycles the arrow), `minus`, `plus`
  and `lift` (remove); Pick and Release get `lift`; a part gets `lift`
  (take off); the body gets `info` (the battery and the loop's cost, as the
  prototype's strip) and, flat, `place` relabelled Tow. New pill buttons
  need icons from `ui/icons.gd`; the builder adds what is missing.
- Tap a `+`: a one-row tray appears at the sheet's foot with the node kinds
  the robot's parts give, locked kinds shown dim with the part they need;
  tapping one inserts it after that `+`'s node (or on that wire).
- Tap the parts `+`: the same tray shows the bin, with prices, "in the bin"
  for spares and "later" for parts a milestone has not opened.
- Wire: drag an output dot onto a node, or tap the dot (it arms) and then
  the node. Dropping on a node wires to its input; wiring to the body is
  the loop. A node may have several incoming wires; a port has one
  outgoing wire, and a new one replaces it.
- The running node glows; a loose output dot is red; a dead node is dashed
  with "needs Gripper" under it.
- Drawn as one baked `ArrayMesh` for the graph (wires, boxes, ports,
  glyphs as `draw_mesh` once per rebuild), rebuilt on edit, with the glow
  and the pill drawn over it; the 855 draw-call budget and the
  `opengl3_angle` check apply as everywhere. Robots, squares and boxes on
  the floor go through Tally's `Batch` (`arcade/tally_board.gd`), which
  moves to a shared file both games preload (same component, same code).

**Amended 2026-10-21.** A Move's arrow is drawn on the screen diagonal
the robot walks at the view's current quarter turn (`sheet.arrow_of`: the
facing turned with the view through `Art.ISO`), and the sheet is redrawn
on a turn; `turn` on the pill still turns the sim's facing a quarter. See
section 3's amendment.

**Amended again 2026-10-21.** The diagonal arrow is gone with the
corner-on view: `arrow_of` is the facing itself, right, down, left or up.

## 11. What stays, what leaves

`factory/sim.gd` keeps its shape (pure data, 10 Hz, `events`, `dirty`,
`pack`/`save`/`load_saved`, `alpha`, flat `price`, `no_cost`) and its belt
machinery (`lay_belt`, `turn`, `flip_line`, `line_through`, `line_tiles`,
`_move_belts`, `_run_lane`, `_enter`, `put`, `front_of`, `out_tile`,
`item_pos`, bridges, the fast belt). It loses plates, forests, mines,
sources, the market and its selling, goals, the firebox, retort, kiln,
stoker, heat, power, the splitter and `GOALS`. It gains `robots`, `PARTS`,
`NODES`, `stations`, the bay, the intake queue, the deliver sale, charge,
pace and milestones, and a `factory/bots.gd` (or a section of sim.gd, the
builder's call) that walks a program a tick at a time with the soft
failures of section 5. Robot programs are plain dictionaries inside
`pack()`.

`factory/screen.gd` keeps the camera's pan, zoom and edge pan
(`_zoom_by_hand`, `_step_view`, `_edge_pan`) with `to_field`, `screen_of`
and `tile_under` rewritten for square tiles, the field input, the belt
drawer and tracing, the pill, the coin pill, the top bar and
`tutorial_pages`. It loses `turn_view` and the view-turn button, the
plate, module, forest and goal cards and the drawer's modules. It gains the robot chips, the sheet
(section 10, its own scene or script under `factory/`) and the pace pill.
`factory/life.gd` draws the new floor for every holder (screen, tab card,
tutorial pages) as it draws the land now; `factory/art.gd` is cut to what
the floor needs and gains the robot (a code character from `ui/faces/`,
never an image), the squares, boxes, pads, bay, the two fixed belts and
the stations. `factory/tile.gd` stays for the drawer's belt tiles.

`ui/menu/factory_tab.gd` keeps the one-sim rule and the save; its card
reads coins, pace and the open milestone. `ui/menu/cards/arc_factory.gd`
is redrawn for the robots. `ui/hud/factory_tutorial_diagram.gd` is
replaced by the six pages of section 8. Factory stays a row of
`arcade_tab.gd`'s `GAMES`, not of `Registry.ARCADE`, as today.

Checks: `tests/_probe_factory.gd` is rewritten for the new sim (a new
floor, the three faults, each fix, the first full box and its coin, a
useless program going flat, towing, the pace window and the hold, a belt
from the intake pad to the table, a Fast plug and Fast treads bought and
felt in the pace, save and load round trip; Repeat and Second body join
in the next pass) and `tests/_shot_factory*.gd` for the new screen and sheet
(the sheet opened, a node inserted, a wire dragged, the pill, draw counts
on `opengl3_angle`). No new test files beyond these (the MVP rule);
throwaway touch probes are fine. Harness flags as `docs/agents/harnesses.md`.

Locale: every string through `locale/ui.csv` keys in en, pt and es; the
64 `FACTORY_*` rows that name logs, plates, forests and goals are retired
and the new ones added (node names, part names, the tutor's six pages,
the pace pill, the bin, the milestone names). Titles stay English.

**Amended 2026-10-21.** The paragraph above is overturned where it speaks
of the view: `factory/screen.gd` keeps `turn_view` and the Turn button
(beside the zoom), and `to_field`, `screen_of`, `tile_under` and the belt
tracing are main's corner-on, turn-aware ones. `factory/art.gd` is main's
land art cut to what the floor needs (plate, water, light, belts, market,
engine, tray, ghost, icons) with the plate made any size; it gains only
the robot, its face, bubbles and bar, the square, the box and the box heap.
`factory/life.gd` is main's (the turn, the belt MultiMeshes, the
depth-sorted standing list) with the robots standing among the stations.
The sheet (section 10) draws a Move's arrow on the screen diagonal at the
view's turn.

**Amended again 2026-10-21.** The amendment above is overturned where it
keeps the turn: `turn_view`, the Turn button, `life.turn` and the sheet's
turned arrows are gone; `factory/art.gd` keeps main's pieces under a
top-down projection (`at`, `PLANE`, `_p`), as section 3's second amendment
says.

## 12. Save

`user://factory.cfg`, section `factory`, `VERSION 5`, `var_to_bytes(pack())`
as base64 as today. `pack()` holds the robots with their parts, nodes,
`next` and program state, the belts and items as now, coins, earned, the
bin's spares, the pace window and hold as tick counts, and the open
milestone. A `VERSION 4` file is not readable by this build and is
**wiped quietly** (the user, 2026-10-20): `load_saved` returns false on
any other version, the tab starts a new floor and the next save overwrites
the file; no message, no gift. Nothing in the save is a time of day.

## 13. House finish

Sounds from `tools/sfx_bank/` through `bank:` rows (`docs/agents/sound.md`,
"The house sound"): a node set down and a part fitted are the token, a
wire landing the pebble, Pick the lip, Release the token, a refusal (loose
wire, flat, a take-off refused) the tongue, the sale the Factory's own
jar coin (`factory/coin`, kept), charging a soft wrap riding the pause.
Haptics rows per `docs/agents/haptics.md` for each. Motion from
`core/motion.gd` (the sheet slides, the pill pops, the node glow breathes,
`Motion.reduce` honoured). Analytics events named `factory_fix` (which
fault), `factory_milestone` (which), `factory_part` (which), recorded in
`docs/agents/analytics.md`; `Analytics.start()` only from `world/main.gd`
as always. `docs/agents/factory.md` gets a new top section that says what
stands, and keeps the land's history below it.

## 14. Left to the builder

The exact look of the robot, the pads and the sheet within the house style
and the 855 budget; whether the program walker lives in `sim.gd` or
`bots.gd`; the chain's auto-layout on the sheet (orphans after the
reachable chain, as the prototype does, is enough); the pill's new icons;
the tray's chips; how the camera keeps a tapped robot in view with the
sheet open; the harness shots; the order of the milestones' bin rows; the
card face. Anything numeric marked "my call" above is a placeholder the
builder keeps in one constants block so it can be tuned in play.

## 15. Open calls

Answered by the user, 2026-10-20 ("wipe quietly, let's end at milestone 1
end. Name later keep factory, user can copy aonther robot or create a new
one"):
1. A `VERSION 4` save is wiped quietly (section 12).
2. The first build ends with milestone 1 open and working; milestone 2 is
   the next pass (sections 4, 7).
3. The name stays Factory for now; a name comes later.
4. A Second body, when it comes, offers an empty sheet or a copy of
   another robot's program (section 4).

Mine, embodied in the prototype and open to be overturned: the floor is
top-down and the land's view turn goes; the direction on the Move node (no
Turn node); the pack table only giving up a full box; robots sharing tiles;
an edit sends a robot to the bay with the charge it had, never full; a tow
is free and arrives at 0; waiting costs nothing; the Repeat entry flag;
belts never block or carry a robot; the intake and deliver belts are drawn,
not simulated; milestone rates set by the probe's pace bot; every number
in sections 3 to 7.
