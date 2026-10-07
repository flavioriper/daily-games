## Valley

**A sixth tab since 2026-10-05**, between Arcade and Stats: slow places
that share one inventory and have no finish (spec
`2026-10-05-valley-grove-design.md`; the concept and its four passes are
`docs/brainstorm/concepts.html#valley`; since 2026-10-07 the Grove's tree
and jetty have a spec of their own,
`2026-10-07-grove-tree-and-jetty-design.md`, and the concept a sixth
pass). Like Versus and Arcade it is not a
registry entry: `ui/menu/valley_tab.gd` holds a card a place, `ui/menu.gd`'s
`_open_valley` mounts the place's own screen and closes back to the tab, and
the screen joins the `versus_host` group so Android's back reaches it.
**Leaving a place calls no `Ads.leaving_game()`**: a place is looked in on
many times a day for a minute.

**The pace is the design** (the user: "really slow, not something the user
will nail in 2 hours", "infinite"). Do not make a number faster to make a
shot or a demo easier: change the harness's preset instead.

- **`Stock`** (`core/stock.gd`, autoload, `user://stock.cfg`) is the shared
  inventory: `count`, `add`, `can_pay`, `pay`, `changed`. A place talks to
  Stock and never to another place. **A place never spends a shared
  resource on itself** (the user's rule): its upgrade currency is its own,
  in its own save. Point `Stock.path` elsewhere and `reload()` in a harness.
  It writes at most every two seconds and when the app is left; `flush()`
  writes now.
- **The Grove is the only place.** No card, chip or line on the tab names a
  second one: the user took the Sawmill and the rest out ("we still gonna
  plan the future").

### The Grove

A piece of land in a pond; trees come up at random spots; a circle follows
the finger and chops what is inside it. A felled tree gives energy (the
Grove's own) at once and the same wood, and energy buys the shop's tiles
and the nodes of a tree of skills. **Corrected 2026-10-07**: until that day
this paragraph said "nothing chops by itself", that a felled tree's wood
went straight to Stock, and that energy bought six tiles. Now a beaver of
the grove's own chops once it is bought, the wood lies where the tree stood
as a pile and is wood in Stock only when a raft has taken it off the
screen, and the shop has three tiles (Axe, Reach, Swing) beside a tree that
holds the rest. **The tree, the jetty and the four skills have their own
section at the end of this file.** What stands between here and there is
the history of the land, the shop's card and the look, kept as it was
written and corrected, with the date, where that day made a line untrue.

**The land takes the screen and the tiles are a card over it** (the user,
2026-10-06: "game should take most of screen, and shop should be a dialog
inside the game that opens by clicking a button"). Under the two plates the
pond runs down to one row: the **Shop** button on the left (the sun button,
`trend`, its badge the number of tiles the energy reaches; left because the
thumb that chops rests on the right) and the count and the hint on the
right. `open_shop` shows a card built once (`_build_shop`: `Dialog.card`,
the energy held on a pill, a round X, the six tiles three to a row as they
were); the X, a press on the scrim and Android's back close it. The grove
goes on behind it, but nothing is chopped. **Since 2026-10-07** the row is
Shop, Skills and the count: a second button (`Skills`, the `tree` icon, the
paper `IconButton` where Shop is the sun one, its badge the nodes the
energy reaches) stands beside Shop, each `BUTTON_W` 320 by 104, and the
hint has left the row (`GROVE_HINT` is gone; the tutorial's first title
says it). The card holds three tiles on one row (`Sim.SHOP`), and its head
is `Dialog.energy_head`, which the Skills card is built with too.

**The card's layout was polished the same day** (the user, on a shot of it:
"polish shop layout"). What was wrong: a tile was 264 tall for 276 of
content, so the picture touched its top and the price sat on its bottom
edge; a tile the energy did not reach was the whole button at 0.78 alpha,
so the card's sprigs showed through five of the six on a new grove; a tree
stood out of its disc and hid it while Swing's arcs were small in theirs;
the card was 1020 wide over a column of 1000. Now (`_tile`,
`_draw_tile_icon`, `_refresh_tiles`):
- **A tile is 344 tall** (`TILE_H`), the card 1000 by 868 (1000 by 508
  since 2026-10-07, three tiles on one row): the picture on a
  disc of `DISC_R` 60, the name and the effect centred in what is left, and
  the price on a bar along the tile's foot (`PRICE_H` 64, as wide as the
  tile less `TILE_PAD`).
- **The price bar alone says whether the energy reaches**: the sun button's
  own (ink on `SUN`, a `SUN_DEEP` lip) when it does, paper (`PRICE_OFF`) and
  dim figures when it does not. **No tile is faded**: the picture, the name
  and the effect of what is being saved for stay as sharp as the rest.
- **A tile with no level left keeps its bar**, a leaf one with a tick and
  `GROVE_MAX`, so six bars line up (three since 2026-10-07); its corner
  chip goes on saying its level (it said "max").
- **Every picture is fitted to its disc** by its mesh's own box
  (`DISC_FIT` 0.78 of the width; a small one grown `DISC_GROW` 1.3 at most,
  or Swing's strokes come out twice as thick as the axe's).
- The effect line is still 24 px on one line: the longest it gets
  ("Bétula XI também cresce") is 273 of the 277 there are, and at 26 a
  line of the first grove wraps in Portuguese. **A new effect string is
  measured in pt and es before it ships.** (That longest line was the
  Seeds tile's. Since 2026-10-07 Seeds, Sprout and Room say theirs on the
  tree's foot card, 790 wide at 30 px, and the shop's three are Axe's,
  Reach's and Swing's.)
- Draw calls where they were: 131 on a new grove with the card open, 232-262
  on the land of thirty (810x1440, and 810x1755 on `opengl3_angle`).
  2026-10-07, on another land (room for thirty, about forty stacks of wood
  lying, every skill bought): 378 with the three-tile card open, 353 on
  `opengl3_angle` under reduce motion.
- **Not done: a phone**, and the user has not seen it.

**The land is seen in isometric since 2026-10-06** (the user: "redesign
grove game to have a isometric view, with a studio ... looking like"). The
look is the game's soft painted one (`docs/art/shading-direction.md`); the
studio is named nowhere. The rules, the numbers, the six tiles (three and
a tree since 2026-10-07) and the shop's card are untouched.
- **It is one flat piece of land.** The first build was the concept tab's
  recommendation, a long island of 149 tiles in three steps with ragged
  sides, and the user on seeing it: "it's terrible, make a single land
  piece, no need for aclive, declive". So: **no tiles, no steps, no ragged
  edge**, and nothing that brings them back without being asked. The land
  is one square of ground seen corner on, a diamond with its corners
  rounded, on one block of earth. (`docs/brainstorm/concepts.html#valley`
  section 0 still shows the island and the steps; it is the record of what
  was turned down.)
- **The ground** (`Sim.HALF` 520, `Sim.LAND` 1040 square): x runs across
  the screen and y from the back corner to the front one, so the land is
  the points within `HALF` of the middle, across and deep added.
  `Sim.stands(p)` is where a tree may come up: `EDGE` (44) inside the edge
  and `TIP` (120) from the four corners. It is about half the ground the
  810 by 1300 rectangle was (541 k against 1.05 M), near the first build's
  810 by 800, because a diamond as wide as the screen is that big at the
  size the trees are drawn. **A grove kept on any earlier land has its
  trees planted again** (the file's `land` key, `KEPT_ON` 3).
- **The view** (`Art.see`): across as it is, `Sim.DEEP` (0.66) as deep.
  `Art.VIEW` is the box the land and its earth take; a screen scales and
  places it (`px`, and `unit` back). The land is as wide as the field, so
  it takes about half the field's height with pond over and under it:
  **that is what a diamond costs on a portrait screen**, and the user chose
  the single piece knowing the island filled it.
- **The circle is an oval** (`Art.oval`, `DEEP` as tall as wide): a circle
  on the ground, measured on the ground, as it always was.
- **A tree is chopped along the line it stands on**, from its foot back to
  under its crown's middle (`Sim.STAND`, about 3.2 of its radius): the
  finger goes to the tree, and a blossom's foot is well under its crown.
- **Trees are drawn `Art.TREE` (1.25) over their footprint**, the meshes of
  this morning, each throwing its shadow to its right, sorted by depth.
- **The ground is still one mesh** (`Art.ground(size, origin, u)`). The
  pond: pale at the top, deep at the foot, soft clouds lying on it
  (`_glow`, a patch with nothing at its edge), lilies in twos and threes,
  one in flower, a stone. The land (`_land_into`): its mirror on the water,
  the earth and the clay under it as two bands along the front edge
  (`_front`, each point with how far it looks from the sun, so the lit left
  goes over to the shaded right round the front corner), a pale line and
  broken rings at the water, turf hanging over in scallops, then the grass
  as one polygon under a wash of warm and cool glows, the sun on the near
  left edge and along the back, combed strokes, pale dabs, pebbles. Tufts
  and flowers (in drifts) are the two MultiMeshes.
- **`Art.light(size)`** is one more mesh over the trees (the Top layer's
  first draw, the tab card's last): warm from the upper left, the frame a
  little darker at its edges. No motes hang in the air: a mote is energy.
- The field clips its children, so a crown never leaves the pond.
- **Measured** (810x1440, 2026-10-06): 49 draw calls on a new grove, 154 on
  the land of thirty at rest, 242 under the oval, 302 with the shop open,
  about 200 under the tutorial; 49, 253 and 283 on `opengl3_angle` under
  reduce motion. The probe's 33 checks pass. The pace bot: Birch day 5 and
  Oak day 21 for eight visits of two minutes, as before; day 2, 7 and 20
  for six of ten minutes (was 2, 8, 21); Birch at 1 h 42 of two hours. It
  chops one tree at a time: **on half the ground a swept oval catches about
  twice the trees late on**, which no bot here measures. (2026-10-07,
  after the tree, the jetty and the skills: 59 on a new grove, 379 on a
  late land under the oval, 378 with the shop open, 315 to 338 under the
  tutorial, and 459 on the worst land the harness lays. That late land is
  not this one: every skill is bought and about forty stacks of wood lie
  on it. The tree's section has the table.)
- **Not done**: a phone; nobody has held the oval under a thumb; the
  tutorial's words still say circle; the pace of a person sweeping.
- **A finger is a `ScreenTouch`, never a mouse button.** The project has
  `emulate_mouse_from_touch` off (b707b9a, 2026-09-22). The field read the
  mouse alone from the day it was built, so **on a phone nothing could be
  chopped** (the user, 2026-10-06: "the click is not working (can't farm)
  on device"), and a tap on the shop's scrim did not close it; buttons
  worked, being Godot's own. `_on_field_input` takes `ScreenTouch` and
  `ScreenDrag` now (one finger holds the circle, `_finger`), beside the
  mouse for the desktop. It was missed because every check pressed with a
  mouse button: `tests/_shot_grove.gd` presses with a `ScreenTouch` now.
  Proved by a throwaway run sending `ScreenTouch` through
  `Input.parse_input_event`: before, held 2.6 s, nothing felled; after, the
  sapling felled and the scrim closed. A drag was not driven.

**Beavers, cast shadows and a real fall (2026-10-06)**, the user: "polish
the grove animation, for each chop show a beaver that bite the tree, also
improve the falling animation to something better animated, right now even
shadow rotate. I would love to see some subtle lightning shadows casted upon
trees dynamic instead of a round". Read as: tree-shaped shadows thrown by the
trees, moving with them, in place of the oval. **Shadows falling on other
trees' crowns were not built**; if that was the wish, it is still owed.
- **`valley/grove_life.gd` holds what stands and moves on the land** for all
  three holders (the screen, the tab's card, the tutorial's pages): trees,
  shadows, beavers, falls, stumps, chips and burst leaves. A holder calls
  `place(origin, u, its global transform)`, `step` after the sim's own,
  `hit` / `fell` for the sim's events, `draw_shade` on a Control wearing
  `life.shade` and `draw` on one wearing `Art.wind()`. The screen's `_hit`,
  `_falls`, `SQUASH` and `FALL` went there. **A new look for the land goes
  in Life, not in three files.** Since 2026-10-07 it also holds the piles
  lying, what is on the jetty, the raft, the crate and the grove's own
  beavers, all read off the sim each frame. The screen also calls `left`,
  `gather`, `washed` and `opened` for the sim's events and hears `carried`
  and `doubled`; the tutorial's pages call `left` and `gather`; the tab
  plays no events and calls none.
- **A shadow is not in the tree's mesh any more** (it was an oval baked in,
  so it turned over with a falling tree). `Art.shade(look)` is the tree's
  own outline in one piece: the tree drawn into an `Outline` builder and its
  shapes melted with `Geometry2D.merge_polygons`, **so nothing overlaps and
  no part of one shadow is darker** (two trees' shadows still add where
  they cross, as the ovals did). `Art.cast(at, scale, lean)` is the
  transform that lays it on the ground: width back into the land
  (`CAST_ACROSS`), height off to the right (`CAST_ALONG`), tone `CAST`
  (alpha 0.24). `lean` is how far the tree has turned over: **the shadow
  never turns, it runs out along the ground and ends under the lying tree.**
- **Shadows move with the wind and stop at the turf.** `Art.shade_wind()` is
  a third material off `wind_2d.gdshader` (one each holder, `blow()` winds
  them all): the vertex still has the tree's height, so it leans on its own
  tree's gust, and `along` turns the lean the way a shadow goes. The shader
  has a fragment stage now: `land_half` over 0 fades what is drawn outside
  the land's diamond (corners cut as the land's are rounded; `Art.keep_to`
  sets where the land is on the screen, every frame, since a card slides).
  Trees and grass leave `land_half` at 0 and are untouched.
- **The beaver is `ui/faces/beaver.gd`**: three kept meshes (tail about its
  joint, body, head about its neck, open-mouthed or biting), three draws a
  beaver, mirrored to face its trunk and so lit from no side. One comes to
  every tree the circle takes (`Sim.reaches`, split out of `_chop`; since
  2026-10-07 also to a tree one of the grove's own beavers is gnawing,
  the same animal at the same place) and
  stays `LINGER` after; it rears back as the next chop comes due and its
  teeth are in on the frame the sim says `hit`, two chips flying. Left of an
  even tree id, right of an odd; **the tree comes down away from it**, and
  it hops twice (`CHEER`) before it goes. **The Axe tile, the word chop and
  the `chop` sound are unchanged**: nobody asked, and the sound is a dry
  tick that passes for a bite.
- **A fall is four beats, 0.9 s** (`CREAK` 0.1 back, `DROP` 0.42 over as a
  falling thing goes, `SETTLE` 0.18 one bounce with a burst of its leaves,
  `GONE` 0.2 drawn in toward its crown), and a gnawed stump (`Art.stump`,
  none for a sapling) stays `STUMP` 0.5 more. `landed` is the screen's dust
  (`Fx2D.puff`); `gave` is when the logs and the motes leave, **from where
  the crown lies, 0.7 s after the last bite**. The wood plate counts a
  tree's wood when its last log lands (`_wood_air`), as the energy plate
  counts motes. The sim, Stock and the `fell` sound are still at the event.
  **Since 2026-10-07 no log flies to the wood plate** (`_wood_air` and the
  screen's `_flies` are gone): at `gave` the motes leave and the tree's
  wood drops out of the lying crown onto the grass as a pile (`DROP_IN`
  0.18 s). Stock gets nothing at a fell; the wood plate counts Stock, which
  moves when the raft lands. The sim's energy and the `fell` sound are
  still at the event.
- **Reduce motion**: a beaver is there or not and only changes its face, a
  felled tree fades where it stands, both signals come at once, shadows
  stand still.
- **Measured** (810x1440, 2026-10-06): 50 draw calls on a new grove, 64 with
  a beaver at its sapling, 178 on the land of thirty at rest (was 152), 287
  under the oval with a dozen beavers (was 233), 337 with the shop open, 220
  to 230 under the tutorial, the tab 110 and 168; `opengl3_angle` under
  reduce motion 50, 181-188, 284 and 338. Frame gaps as before on both
  drivers (ANGLE reads 19-23 ms on this Mac with or without the change).
  Suite 249790/0; the probe's 33 checks. (2026-10-07: 59 on a new grove,
  83 with one of the grove's own beavers at a tree, 236 to 272 on a late
  land at rest and 379 under the oval, 378 with the shop open, 315 to 338
  under the tutorial, the tab 111 and 241; `opengl3_angle` under reduce
  motion 59, 233 to 259, 326 and 353. The late land is another one now,
  with every skill bought and about forty stacks lying. **The gap from
  287 is not all the jetty's**: the same beat read 330 when it was run
  again on the branch before a pile was drawn, at fcde1339, which the
  builder put down to the second button, its badge and more figures under
  the oval; the piles, the jetty and the skills are the rest. The tree's section has the table.)
- **Not done**: a phone (the fragment stage and the melted outlines have
  only run on this Mac's two drivers); nobody has watched it at speed, every
  judgement was made on frames stepped a sixtieth apart; a fall behind a
  front tree's crown is mostly hidden (it is sorted by its foot); a late
  grove sweeping many trees a second was not looked at.

The tab's card takes the whole tab for the tall picture. **It is called the Grove and nothing else**: the game it
follows is named once, in the spec. Since 2026-10-07 the card's land has
the jetty, the piles lying (with no counts on them: `Life.counts` is off
there), what the jetty holds, the raft and a crate, and none of the grove's
own beavers.

**The card says what the place makes** (the user, 2026-10-06: "show what the
grove game has as outcome, for example wood, so user can understand it's
meant to farm wood. Show a wood/min rate (gonna be -- till automation is
enabled)"). Beside the card's name, on the right, a chip
(`valley_tab.gd` `_makes_chip`): the log of the pill above, `GROVE_WOOD`,
and a rate with `VALLEY_PER_MIN` ("/ min" in all three languages). (What
follows is the chip as built on 2026-10-06; the next paragraph says what it
reads since 2026-10-07.) The rate
is `Sim.wood_per_min()`, **0.0 until something chops by itself, and a rate
of none is written "--", never 0** (`_write_rate`; one decimal under ten a
minute, `Art.short` over). Automation, when it is built, answers in that
one function and the chip follows on the tab's next `refresh()`. A second
place gets the same chip for what it makes. Four draw calls more on the tab
(109 and 138 against 105 and 134, 810x1440). Not seen on a phone.

**The chip reads a figure from the first day since 2026-10-07, and that is
not what the quote above asked.** `wood_per_min()` is the sim's own now
(`sim.wood_per_min()`, no longer a flat 0.0): the most the jetty's chain
can send in a minute at its levels, 20 on a new grove (how it is worked
out is in the tree's section). So "--" is only what a tab shows before it
has read a grove. It is a ceiling that needs a finger to gather the wood,
not wood that comes in by itself, and the automation that was built, the
beavers, does not move it. The user's words were "gonna be -- till
automation is enabled"; the ceiling was put there on their behalf and they
have not judged it. Putting "--" back is one line in `_write_rate`. The tab
reads 111 draw calls on a new grove and 241 on the worst land the harness
lays (810x1440, 2026-10-07, both drivers).

- **The game is pure data** (`valley/grove_sim.gd`): land units on the
  ground, `step(dt, holding, at)` (and a fourth argument, `here`, since
  2026-10-07), `events` for the screen to drain, `buy`, and its own keeping
  (`save(now)`, `load_saved(now)`, `Sim.path`). It never touches Stock: the
  screen handed each felled tree's wood over until 2026-10-07, and since
  then hands over what the raft has landed (`take_owed`).
  `tests/_probe_grove.gd` checks the arithmetic (40 checks then, 135 on
  2026-10-07) and `-- pace [visits] [seconds] [days]` (with a fourth
  argument since 2026-10-07, the ids the bot never buys) or
  `-- marathon [hours]` plays it with a bot; **run `pace` after touching
  any number** and put the table in the spec's section 4 (the six-tile
  grove's tables are there; the tree's and the jetty's are in
  `2026-10-07-grove-tree-and-jetty-design.md`, section 10).
- **Every felled tree's place counts by itself** (the user, 2026-10-06:
  "the count down for each tree should start moment it's cutted, not one
  after another ... if I cut 5 tree same time, it takes 5s to respawn 5
  trees, not 25 seconds"). `Sim._due` holds the seconds left for each empty
  place, one a place: `_chop` starts one at `spawn_time()` as a tree comes
  down (`_fell` since 2026-10-07, for a beaver's tree as for the axe's),
  `_grow` takes `dt` off them all and plants where one has run out,
  and `_owe` starts one for a place that has none (Room just bought, a tree
  taken off the land by hand, as the tutorial and the probe do). Buying
  Sprout shortens the ones already counting. Away, every place counts the
  seconds gone (`catch_up`). **The wait is exactly the sprout time**: the
  0.6 to 1.4 of it that the single wait had (`GAP_MIN`, `GAP_MAX`) is gone,
  so five felled by one chop are back on the same frame. The file keeps
  `due`; one kept before has `wait`, which the first empty place takes.
  **It made the grove several times faster and nothing was retuned**: Birch
  on day 1, Oak on day 4, Pine on day 10 for the eight visits of two
  minutes (day 5, 21, 59 before), 40,832 wood in two hours without stopping
  (1,697). The spec's section 4 has the table, with what a first sprout
  time of 18 s and of 30 s would read; **the user has not said whether the
  pace stands.** `tests/_probe_grove.gd` is 40 checks (five trees felled at
  a stroke are all back six seconds on; one felled three seconds later is
  three behind). Nothing is drawn for a place counting. The Sprout tile's
  line ("every 6.0 s, then 5.6") was left as it is. (2026-10-07: the probe
  is 135 checks; Sprout is a node of the tree and the line is its foot
  card's; the bot that buys everything still reads Birch on day 1, Oak on
  day 4 and Pine on day 10, and the user has still not said.)
- **Every tree starts at 4** (`Sim.HP`; the user: "each tree start as 4hp").
  Axe and Seeds have no last level; Reach, Swing, Sprout and Room stop.
  Since 2026-10-07 Seeds is the tree's trunk (`kind:N`, still without a
  top), every other node of the tree stops, and a kind's Soft bough takes
  a quarter of its chops off a level: `sim.hp(tier)` is what a kind takes
  now, `Sim.hp_of(tier)` what it took before its boughs.
- **A level of the Axe adds half a point** (`Sim.AXE_STEP` 0.5, 2026-10-06;
  it added one, and the user: "it's too fast at start going from 1 -> 2,
  let's do 1 -> 1.5"). `power()` is a float and so is a tree's `hp` after a
  chop (the file keeps it as one; a grove kept with whole numbers reads the
  same). **A chop's figure goes through `Art.amount`** (1, 1.5, 31.5, then
  `Art.short` past a thousand), with a comma in pt and es: the hit numbers
  and the Axe tile's line (`GROVE_FX_AXE` takes two `%s`). Its price is
  unchanged. The pace bot reads within half a percent before and after
  (Pine one day later for the ten-minute player): its grove waits on trees
  coming up, not on the axe (the spec's section 4).
- **Away is worked out, never run**: `load_saved` adds the trees whose
  places finished counting since `seen`. The tab keeps its own sim from the file
  and steps it for the card's picture; **Play saves that sim first**, so the
  screen opens on the same trees. Since 2026-10-07 time away (`catch_up`)
  also gives the beavers their share, ties and rafts what was on the jetty
  and may wash a crate up; an app brought back alive from the background
  is time away too; and the tab steps its sim with `here` false and keeps
  it on every landing. The tree's section has each.
- **One mesh a tree** (`valley/grove_art.gd`, cached per look), one for the
  whole pond and land (`Art.ground`, rebuilt on resize only), one MultiMesh
  for the tufts and one for the flowers, a draw a number. 92 draw calls on a new grove, 246-286 on a land of thirty with a
  circle over a dozen trees and their numbers, about 230 under the tutorial
  card (810x1440, 2026-10-05; the same on `opengl3_angle`, 92 and 275).
  Frames came 8 to 10 ms apart through the whole harness run on both.
  **With the tiles off the screen (2026-10-06): 46 on a new grove, 176-201
  on the land of thirty under the circle, 246-265 with the shop's card
  open, about 180 under the tutorial card**, both drivers. (2026-10-07: 59,
  379, 378 and 315 to 338; the tree's section has the table and says what
  that land holds.)
- **Energy is Peapod's motes of light** (`ui/motes.gd`; the user,
  2026-10-06: "use the same energy as the peapod game (not shared energy
  but same pattern and animations)"). The green eight-pointed spark is gone
  from the plate, the six prices, the air and the tutorial's page. A felled
  tree lets go 4 motes (a sapling) to 12 (two more a tier), `ORBS` (4) to
  one energy as in Peapod, out of its crown: they drift, lift, hang
  breathing, and go round a bend to the energy plate leaving dust, the
  plate glowing and swelling as they land and **counting only what has
  landed** (`_motes.due`). Each landing is `chop` again, quiet and a
  semitone up a short run, through `_quiet` (no buzz, like Peapod's). The
  energy itself is still the Grove's own number in the Grove's own save.
  The wood's logs fly as they did (until 2026-10-07: the wood is a pile on
  the grass now, and nothing flies to the wood plate). Under reduce motion
  nothing flies and
  the count is there at once. The tutorial's gifts page steps a layer of
  its own (`auto` off, `always` on, seeded), played again on a resize when
  it stands still. Two draws more while motes are up (107 with a sapling's
  four in the air, 304 on the late grove's shot; 810x1440, 2026-10-06).
  **Not done: a phone, and the landing clicks are unheard.**
- **The trees and the grass were redrawn and the wind blows over them**
  (the user, 2026-10-06: "polish design of trees, grass, add some wind
  movement").
  - **Trees** (`Art._tree_into`, `_trunk`, `_crown`, `_tier`), lit from the
    upper left: a crown is four tones (its shade showing under it, a body,
    the lit side, a few bright clumps) with loose leaves of one tone dabbed
    over another; a trunk flares at its foot, forks under the crown and is
    darker down its right; the pine's skirts hang in scallops with a lit
    left side and a shadow under each; the sapling's leaves have a lit half
    and a rib; the blossom has dropped petals at its foot. Still one cached
    mesh a look, the same sizes as before (`height`, `RADIUS`).
  - **Grass**: the ground (still one mesh) has soft hollows and rises,
    short combed strokes of both, pebbles, layers in the earth edge and the
    turf hanging over it in scallops. **The tufts and the flowers left the
    ground mesh**: `Art.grass(land)` is a MultiMesh of each (one tuft and
    one flower mesh, tinted an instance), so they can lean.
  - **Wind is a vertex shader, nothing is rebuilt**
    (`shaders/wind_2d.gdshader`, `Art.wind()` for trees, `Art.wind(true)`
    for grass: two materials off one file, no instance uniform). A mesh
    standing on its own (0, 0) leans more the higher a vertex is above its
    foot; the gust is a slow wave crossing from the left with a quicker
    sway on it, read from the model matrix's origin (a draw's transform and
    a MultiMesh instance's alike), and a crown's vertices shiver each on
    their own time. **What is drawn where it lies (y >= 0 in its item: the
    ground, a bar, a circle, text) does not move**, which is why the tab's
    card and the tutorial's pond wear the tree material on the one item
    that draws everything. `Art.blow()` is called every frame by whatever
    shows the land: it sets the clock, and `amp` 0 under reduce motion (two
    frames 1.5 s apart are pixel-identical). `Art.gust` is the same wave in
    script.
  - **The screen's field is layers now**: the field draws the ground once;
    `Grass` (drawn once, moved by its material), `Trees`, `Leaves`, `Top`
    (lap marks, bars, the circle, the numbers: over every tree, not
    between them). **Loose leaves** (`_step_leaves`, one MultiMesh, 14 at
    most): the wind takes one off a standing tree now and then, sooner in
    a gust and on a fuller land, in that tree's colour (a petal off a
    blossom), and carries it right, sinking and turning over. None under
    reduce motion.
  - 48 draw calls on a new grove, 147-149 on the land of thirty at rest,
    194-210 under the circle, about 250 with the shop open (810x1440,
    2026-10-06); 145 and 199 on `opengl3_angle`, where it leans the same.
    (2026-10-07: 59, 236 to 272, 379 and 378, on a late land with every
    skill bought and about forty stacks lying; the tree's section has the
    table.)
  - **Not done: a phone** (the shader has only run on this Mac's two
    drivers), and nobody has watched it move: every judgement was made on
    stills a third of a second apart.
- **The fonts have no arrow and no star.** A tile says "chop 1, then 2" and
  a tree past the fifth tier is "Birch II" (`tree_name`). No
  multiplication sign either: a double pile says "x2" (2026-10-07).
- **Sounds** (`assets/sfx/grove/`, `tools/gen_sfx.py grove`): `chop` is a 90
  ms click, the quietest of the set, since it repeats for as long as the
  finger is held; `fell`, `buy`, `no`. Unheard by the user. The jetty and
  the skills reuse these four (2026-10-07, the tree's section); no new take
  was made.
- **Haptics** (`docs/agents/haptics.md` row 40): fell taps, a tile bought
  bumps, one refused warns; a chop that hits is felt only as its sound's
  echo. Since 2026-10-07 a raft's landing and a crate opened tap too (both
  cue `fell`), a node bought on the tree bumps and one refused warns, and
  a gathered log, a beaver's own tree coming down and a mote landing are
  heard and not felt (`_quiet`).
- **Analytics**: `valley_enter` (place, trees, room), `valley_leave` (place,
  seconds, felled), `grove_upgrade` (tile, level, energy). Since 2026-10-07
  `tile` is a shop tile or a node's id (`room`, `raft`, `kind:3`,
  `soft:2`); the trunk sends `kind:N`, never `seeds`.
- `tests/_shot_grove.gd` shoots the tab, a new grove, a chop, a fell (and
  two frames of its motes), a middle and a late grove, the shop opened by
  its button with a tile bought and closed by its X, the tutorial's three pages and the
  tab again, on throwaway files. (As of 2026-10-06. Since 2026-10-07 the
  tutorial has four pages and the harness shoots 54 frames: the tree's
  section lists the beats.) It prints frames and their mean gap between
  shots; `Performance.TIME_PROCESS` read 100 ms on frames 9 ms apart under
  `--script` and is not printed.
- **Not built** (as of 2026-10-06): automation, chests, critical hits, timed
  days, a skill tree, ads, a growing land, a second place. Nothing run on a
  phone. **2026-10-07**: the skill tree, automation (a beaver of the
  grove's own), chests (crates) and critical hits (keen chops) were built,
  with lucky wood and the jetty. Still not built: timed days, the
  reference's two other skills and its animals, ads, a growing land, a
  second place, a beaver that carries piles, a second raft, anything on
  the far shore, new sounds, cloud save.

### The Grove's tree, jetty and four skills (2026-10-07)

Spec `2026-10-07-grove-tree-and-jetty-design.md`: its section 3 has every
node's price and last level as a table, its section 9 what playing the
concept changed before and during the build, its section 10 the pace
tables and the draw calls a beat. Built on `feat/grove-tree`.

**What the user said, and what was decided for them.** "on grove game, we
gotta create a skills tree". Asked how the tree sits with the shop they
chose "Split like the reference"; asked what pays, "Energy, like the shop".
Of the new skills offered they took all four (a beaver of its own, chests,
critical chops, lucky wood) and added the jetty themselves: "we need to
also add the pick wood to pack and send, since it's gonna be shared with
other resources, we need to send to storage so the pack and deliver should
also become a bottleneck to user". On who picks, packs and sends: "Finger
picks, the rest runs". On the backlog: "Jetty has room, logs wait". On the
design as it was laid out in chat: "all good, build it all". **Those are
all the user said of the tree and the jetty. Every figure, name, order and
drawing below was proposed by an agent and built without the user's
judgement, and the user has seen none of it running**: not the card, not
the jetty, nothing on a phone. What that leaves open is listed under Not done. The reference is
named nowhere here; the first spec names it once.

Three things were built, in this order, each leaving the game playable:
the tree (the shop keeps Axe, Reach and Swing; Sprout, Room and Seeds
became nodes), the jetty (a felled tree's wood has a way to go before it
is wood in `Stock`), and four skills. Energy pays for all of it, the
Grove's own number as before. Nothing in the Grove spends wood.

**The tree** (`valley/grove_sim.gd` holds the rules, `valley/grove_tree.gd`
the card).
- **Shape.** A trunk up the middle, a node a kind of tree: `kind:0` is the
  Sapling and is owned, `kind:N` is what Seeds was (`KIND`: 120, x7 a kind;
  buying it sets `lv.seeds` to N; no top). Two boughs leave each kind:
  `soft:N` on its left (a quarter of the kind's chops off a level, two
  levels, at 0.5 and 1.5 of the kind's price) and `rich:N` on its right
  (half the kind's yield more a level, wood and energy alike, two levels at
  0.75 and 2.25; the Sapling's is one level at 1.5 that doubles it: `RICH`,
  `RICH_SAPLING`). A kind's price is `kind_price(tier)`, 20 for the Sapling
  (`SAPLING`). Four roots go down under a line of soil, each a chain in the
  order written (`ROOT_ORDER`, `ROOTS`): Land `room sprout`; Jetty `raft
  jetty bundle tying load`; Beavers `beaver teeth`; Fortune `crit critsize
  luck crate cratesize`. Every root node's and shop tile's first price,
  multiplier and last level are one row of `Sim.NODE`.
- **Rules.** `level`, `last_level`, `is_done`, `cost`, `before`, `is_open`,
  `can_buy` and `buy` take an id, a shop tile's like any other (`seeds`
  still answers, as the next kind). **A node is open when the one before it
  has a level, or it has one itself**: that second clause is how a kept
  grove's Sprout stays bought whatever its Room is. `shown()` is what the
  card draws: the trunk up to the next kind, each owned kind's two boughs,
  and every root node that is open or has a level. On a new grove that is
  eight nodes (the Sapling, its two boughs, Birch, Room, Raft, Beavers,
  Keen edge). `reachable()` counts the shown nodes the energy reaches, for
  the button's badge. `value(id, level)` is the figure a node's line is
  written from, and `_figure(id, n)` is the one place a root node's figure
  is worked out: the land's readers (`room()`, `tie_time()`, `bite()` and
  the rest) and the card both answer from it, so they cannot say two
  things.
- **A grove kept before this loads** (`load_saved`): its `lv` keys keep
  their names and levels, its Seeds level is its trunk, its boughs are bare
  (`[tree] soft` and `rich` in the file, a level a tier), its jetty is
  empty and its wood in Stock is untouched.
- **A kind gone from the land.** The land grows the best kind and the two
  under it (`MIX`), so `grows(tier)` is false under `seeds - 2`. Such a
  kind's boughs keep their levels and cannot be bought (`can_buy`). On the
  card its three nodes are flat paper with no rim and no price tag, their
  pictures faded (`_faded`, `GONE` 0.45: every colour mixed 55% toward the
  paper; at 45% alpha a crown's clumps showed through each other), and the
  foot card says `GROVE_GONE` ("Sapling no longer grows here") over an
  empty bar that does nothing when pressed.
- **The card.** `open_skills` shows a card built once, the shop's own kind
  (the same scrim, `Dialog.card(1000, 26)`, `Dialog.energy_head`): 1000 by
  1428 on the 1080 by 1920 canvas, a field 948 by 1000 (`FIELD_MOST`, never
  under `FIELD_LEAST` 620) over a foot card 244 tall. The grove goes on
  behind it and nothing is chopped; the X, a press on the scrim and
  Android's back close it. The field is one Control: the paper, hills and
  earth are one mesh (`_back`), the roots, trunk and boughs another
  (`_links`: pale to a node with no level, a bough in leaf by its level),
  each node one kept mesh for its plate and picture (`_plate`, by picture
  and state) and one string (its level on a corner chip, or its price on a
  tag under it while it has none), a ring under the chosen one, and
  `_frame` over it all. Never a Button a node. The grid is `CELL` 236 by
  216 with `PLATE` 128 (`cell(id)`, `spot(id)`). A kind wears `Art.tree`,
  the other nodes `Art.icon(id)` (`_node_into`). The mote beside a price
  is `Motes.icon(side)` and the paper of a price the energy does not reach
  is `Art.PRICE_OFF`, both the shop's too.
- **The hand on it.** The field pans up and down under a finger
  (`ScreenTouch` and `ScreenDrag`; the mouse and its wheel on a desktop).
  A press that moves less than `TAP` 24 px is a tap and chooses the node
  under it (the plan's 12 is under a phone's own touch slop); a tap that
  stops a running field and a touch the system canceled choose nothing; a
  finger let go while moving lets the field run on (not under reduce
  motion). It opens with the soil a third up the field (`_seat`), or on
  the node last bought when that would be out of sight, and comes to a
  bought node when what it opened lies past the field's edge.
- **The foot card**: the node's name, its line, its level of its last (the
  level alone where there is none) and the bar that buys (520 by 84, its
  own size), which shakes its head when the energy does not reach. A line
  is "now, then" from `line(id, now, then)`, a key a node (`GROVE_FX_<ID>`)
  with `FX` saying how each figure is written. A node that is nothing
  before its first level says only what that level brings (`FIRSTS`:
  Beavers, Keen edge, Lucky wood, Crates; `GROVE_FX_<ID>_FIRST`). **A Soft
  bough's line counts whole chops with the axe as it is** (`_chops`: "chops
  to fell: 3, then 2"), not the kind's points, so with a strong axe both
  figures can be the same one. The widest line measured as it was built is
  Portuguese Lucky wood, 645 of the 790 px there are at 30 px. **A new line
  is measured in pt and es before it ships**, as the shop's are.

**The jetty** (`valley/grove_sim.gd`).
- **The chain, a step a constant.**
  1. A fell (`_fell`, the axe's tree and a beaver's alike) gives its energy
     at once and leaves its wood as a pile where the tree stood (`_leave`,
     `_drop`). A pile that comes down within `MERGE` 70 of a stack joins
     the nearest, so `logs` is stacks: `{n, wood, tier, lucky, born}`.
  2. On each swing the circle gathers (`_gather`): every stack within
     `reach()` of its centre that has lain `LIES` 0.9 s since its last pile
     came down, oldest first, as many of its piles as the jetty has room
     for. A full jetty takes none and says `full`, once a swing. **Piles
     never rot.**
  3. The jetty holds `JETTY` 8 piles, loose and bundled together
     (`jetty_room()`, `jetty_held()`), 3 more a level.
  4. Tying (`TIE` 6 s for a bundle of `BUNDLE` 4): a bundle is tied while a
     whole one's worth is loose; **fewer are tied only when the raft is
     home and no bundle waits**, so a short bundle never takes a whole
     one's place on the raft and no pile is stranded.
  5. The raft (`RAFT` 12 s there and back, one bundle before Load): home
     with a bundle waiting it takes what it carries and goes, **lands its
     wood at half its time** (`owed`, `wood_sent`) and is home at the whole.
  Steps 3 to 5 are `_send(dt)`, which moves by what happens next and never
  by the second, so a frame and three days away cost the same.
- **The chain counts piles, not wood**, so it is measured in the unit the
  axe is, trees a minute, and a richer kind sends more wood through the
  same raft. Before any node it ties 40 piles a minute and rafts 20. Bought
  out (Raft 15, Jetty 20, Bundle 7, Tying 15, Load 3) the jetty holds 68,
  tying makes a bundle of 11 every 1.24 s, 534 piles a minute, and the raft
  carries four bundles every 3.44 s, 768 (arithmetic from the constants,
  not a measurement).
- **`owed`, and who hands it to `Stock`.** The sim never touches Stock.
  Whoever holds a sim asks `take_owed()` every frame and gives what comes
  back to `Stock.add("wood", n, "grove")`: the screen and the tab, each in
  its `_process`. **Both keep the grove at once on a landing** (the screen
  by `_save()`, the tab by `save` and `Stock.flush()`), because a grove
  kept from before the landing would land the same wood again on the next
  read. `wood_made` still counts at the fell (a lucky pile's double with
  it); `wood_sent` is what the raft has landed.
- **Leaving.** `_on_back` keeps the grove, sets `_left` and stops the
  screen's `_process` before it says `closed`, and `_save` returns on
  `_left`: a screen that stepped once more beside the tab could land the
  same raft twice, and one that saved again as it left the tree would
  write over what the tab had kept since.
- **Away** is `catch_up(seconds)`, asked by `load_saved` as before: the
  trees that came up (`_grow`), the beavers' share (`_gnaw_away`), the
  chain for what was on the jetty (`_send`), a crate (`_wash`), then the
  events are cleared.
- **An app brought back alive is time away too** (0a09f03c). A phone runs
  no frame of a paused app, and the next ordinary save would have stamped
  the hours as seen: the whole-branch review measured 8 hours in the
  background as worth nothing. Now the screen saves and keeps `_paused_at`
  on `NOTIFICATION_APPLICATION_PAUSED` and calls `catch_up(now -
  _paused_at)` on `RESUMED`; the tab, if it is showing, reads the file
  again (`refresh()`). Both step by `minf(delta, Sim.STEP_MOST)` (0.25 s),
  so a first frame as long as the pause is not played as well. A window
  that loses the focus on a desktop is not a pause. Proved headless by
  sending the two notifications to the real screen (8 hours: 30 energy, 30
  piles lying, 10 wood landed, the land full, a crate, the same as a
  reload). **RESUMED never fires on a desktop, so no device has run this.**
- **What the tab's sim runs**: trees coming up, the chain, a crate washing
  up, and **not the beavers** (`step(dt, false, Vector2.ZERO, false)`: the
  fourth argument is `here`). Their share of those seconds is time away at
  the next read of the file, but only for the seconds since the file was
  last kept, and the tab keeps it on every landing and as Play is pressed.
  The seconds before that stamp are the beavers' loss; `step`'s comment
  says so. It was left.
- **A file's jetty is not trusted** (`_read_jetty`, `_count`, `_piles`,
  `_fit_jetty`): a count is a whole number up to `MOST` or none, at most
  `ROWS` 256 stacks and bundles are read, a jetty holding more than its
  room has the rest put back on the land at `by_jetty()`, and a tree whose
  hp is no number is whole. A file whose figures pass is believed.
- **`wood_per_min()`** is the chain's ceiling: the slower of tying and
  rafting, in piles, times what a pile of the land's mix is worth, times
  `1 + luck_chance()`. 20 on a new grove. The tab's chip shows it (the
  paragraph on the chip, above, says why that is still to be judged).

**The four skills** (the sim).
- **A beaver of its own** (`beaver` to 5, `teeth` to 5; `_gnaw`,
  `gnawing`). Each takes the oldest standing tree no other beaver is at
  and bites it every `BITE_EVERY` 1 s for `BITE` 0.5 of the axe's chop, a
  tenth more a level of Teeth (a whole chop at the last). Its tree falls
  as any does: energy at once, a pile lying. **It gathers nothing. With
  someone there it never rests** while a tree stands free, however many
  piles lie: a first rule that rested them on a littered land left one
  beaver idle 94% of the concept bot's twenty minutes. **Away each fells
  the land once over at most** (`_gnaw_away`: `beavers() * room()` trees a
  return, fewer when the seconds do not cover them, their piles lying
  ripe). A bite is never keen; a beaver's pile rolls for luck like any.
  `gnawing` is not kept in the file.
- **Keen edge** (`crit`, 5 points a level to 50%; `critsize`, "Heavy
  blow", from 2 chops and half a chop more a level to 5): every tree a
  swing hits rolls on its own.
- **Lucky wood** (`luck`, 4 points a level to 40%): the felled tree's pile
  is worth double. Its energy never is: luck is wood through the same
  raft.
- **Crates** (`crate`, `cratesize`): with a level, one washes up every
  `CRATE` 180 s (10% sooner a level after the first) within `SHORE` 140 of
  the land's two front edges, one at a time, away as well. A swing with
  the circle's centre within `reach()` of it opens it for the energy of
  `CRATE_GIVE` 15 felled trees of the best kind as it is before its Rich
  bough (`give_of(seeds)`), a fifth more a level of Full crates (added,
  not compounded: three times at the last).

**On the land** (`valley/grove_art.gd` draws it, `valley/grove_life.gd`
holds it for the screen, the tab's card and the tutorial alike).
- **The jetty is in the ground's mesh** (`_jetty_shade_into`,
  `_jetty_into`): planks off the middle of the front left edge
  (`deck(across, out)`, `JETTY_WIDE` 144, `JETTY_LONG` 196). **They are
  level with the turf** (the first plank lies `JETTY_IN` 16 on the grass:
  no step, notch or terrace, the land stays one flat piece), so the jetty
  stands on posts `DEPTH` 116 down to the pond and **the raft floats that
  far below its end** (`raft_at(k)`, `RAFT_OUT` 62 past it). Nothing is
  drawn between the two: a bundle is on the planks one frame and on the
  raft the next. The pond keeps its lilies and ripples clear (`_berth`);
  one lily group moved on the tab's card.
- **Life draws the wood**: stacks sorted in with the trees by depth
  (`Art.pile(n, lucky)`: five heaps by `heap_of(n)`, a lucky stack with a
  small twin baked in, one draw whatever it holds, and its count over it
  from two piles up where the holder has `counts` on); the loose heap on
  the jetty (`Art.jetty()`); up to `BUNDLES` 6 bundles (`Art.slot(i)`),
  then a count; the raft (`Art.raft(aboard)`, up to four bundles baked in,
  rocking at home by its transform, getting away as `k^2.2`, not drawn
  past the holder's left edge). A pile is not seen until its tree has
  landed (`left`, `_owed`, a `DROP_IN` 0.18 s drop out of the crown).
  `gather` throws up to `THROWN` 3 logs a stack (`Art.billet`, `FLIGHT`
  0.45 s, `THROWS` 18 in the air at most), and the jetty's heap counts
  them as they land (`carried`).
- **Nothing new sways.** The wind's shader leans whatever stands above its
  own item's y = 0, and all of this is drawn on the layer that wears it.
  So every new mesh is built through `Art._still`, which hangs it `STILL`
  200 under its own origin (asserted in debug), and drawn through
  `Art.still(at, scale, turn)`, which puts it back; the raft's rocking is
  that transform's turn. **A new thing on the land that must not lean goes
  through those two.** Checked as it was built with the wind at full, each
  mesh alone, two frames 1.5 s apart: 0 pixels differ on every pile, the
  bundle, the billet, the rafts and the crate, 3,640 on a tree. The
  harness's `sw_0` / `sw_1` and `s6c` / `s6d` are the same check in the
  game.
- **The screen's own signs** (`valley/grove_screen.gd`). The jetty's plate
  on the water by it (`_draw_jetty_plate`: held of room; the warn colour
  for `WARN_HOLD` 2.5 s after a full jetty refused a gather while it is at
  least half full; a shiver at the first refusal of a run and never within
  `SHIVER_GAP` 4 s).
  A keen chop's figure at 60 in gold with one of `Fx2D`'s rings
  (`KEEN_RINGS` 6 on the land at most, none under reduce motion), and a
  fell's "+N" `KEEN_LIFT` higher when the chop that made it was keen. "x2"
  over a lucky pile for `TWICE` 1.2 s as it comes to rest (Life's
  `doubled`). A landing: the raft is off the screen when it gets there, so
  the wood plate swells and "+N" rises beside its count (`_gains`, `GAIN`
  1.3 s, drawn by `_draw_over`).
- **The crate and the beavers are Life's.** A crate lies at `sim.crate.pos`
  in with the trees (`Art.crate`); on `washed` it bobs in off the nearer
  front edge and is thrown up onto the grass (`WASH` 0.6 s), beside the
  jetty's posts and never through them (`WASH_CLEAR`); on `opened` it
  bursts into `BOARDS` 9 boards (`Art.board`), with the screen's dust and
  `CRATE_MOTES` 16 motes. One of the grove's own beavers is the same three
  meshes at the same place by its tree as the circle's (`_step_own`): one
  beaver a tree, so the circle on a gnawed tree brings no second; it
  arrives `ARRIVE` 0.6 s after it took the tree; with no tree to go to it
  sits along the back right edge (`rest_at(i)`). A bite writes no figure.
- **Keeping**: a hand's fell, a gather and a crate opened within
  `SAVE_GAP` 5 s; what only the beavers or the pond did within `SAVE_SLOW`
  20 s (`_gnawed`), since beavers work for as long as the screen is open;
  a landing, a buy, a pause and leaving at once.
- **Reduce motion**: nothing is thrown and the heap has its piles at once,
  a pile is there as its tree fades, the raft lies still, a crate is there
  or gone, no ring.

**The tutorial has four pages** (`tutorial_pages`,
`ui/hud/grove_tutorial_diagram.gd`; it had three). CHOP's body counts the
chops a sapling takes on this grove as it is (`_chops_line`,
`TUT_GROVE_CHOP_BODY_ONE` / `_N`). GIFTS was rewritten: the pile lies and
the circle comes back for it, and no log flies to a wood plate. WAIT is as
it was. SEND is new (`Lesson.SEND`, `TUT_GROVE_SEND`): two stacks
gathered, a bundle tied, the raft off the picture's left edge, "+4" by the
wood plate, 8 s a round, with Tying 10 and Raft 7 bought on the page's own
sim (levels the game sells, no number changed). Each body was measured at
4 lines or fewer in the three languages on the card's 230.

**Words.** Every string is a key in `locale/ui.csv` in en, pt and es:
`GROVE_SKILLS`, `GROVE_SKILLS_HELP`, a name a node (`GROVE_<ID>`,
`GROVE_SOFT`, `GROVE_RICH`), a line a node (`GROVE_FX_<ID>`, and `_FIRST`
for Beavers, Keen edge, Lucky wood and Crates), `GROVE_GONE`,
`TUT_GROVE_SEND` and its body.
`GROVE_HINT`, `GROVE_SEEDS` and `TUT_GROVE_CHOP_BODY` are gone. The
`.translation` files are not tracked: `godot --headless --path . --import`
after a csv edit. Seconds take a comma in pt and es (`Art.decimal`).

**Sounds are the four the Grove had, reused, and what is felt follows
them** (`assets/sfx/grove/`, no new take; `docs/agents/haptics.md` row
40).
- A raft's landing: `fell` at -9 dB, felt as a tap.
- A crate opened: `fell`, a tap.
- A node bought: `buy`, a bump. One the energy does not reach: `no`, a
  warn. A press on a gone kind's bar: nothing.
- A gathered log landing on the jetty: `chop` at 0.8 pitch and -11 dB
  through `_quiet`, so unfelt, never two within `CARRY_GAP` 0.05 s. Under
  reduce motion nothing is thrown, and the same click is played once for
  the gather.
- A tree one of the grove's own beavers brings down: `chop` at 0.7 pitch
  and -12 dB through `_quiet`, never two within `GNAW_GAP` 0.3 s; no
  `fell`, no "+N", nothing felt. A beaver's bite is silent.
- A keen chop and a full jetty have no sound of their own.

**The probe and the pace bot** (`tests/_probe_grove.gd`, headless,
throwaway files).
- `godot --headless --path . --script res://tests/_probe_grove.gd`: 135
  checks in about a second (it was 40). The chain's checks read every
  figure from the sim (`Sim.JETTY`, `sim.tie_time()`), so a retune does not
  break them.
- `-- pace [visits a day] [seconds a visit] [days] [ids never bought]`. The
  fourth argument is a comma list of ids or parts (`beaver,teeth`,
  `soft,rich`) the bot never buys. `-- marathon [hours]` is one visit of
  that length and takes no fourth. On this Mac: `pace 8 120 30` about 30 s,
  `pace 6 600 30` two minutes, `marathon 2` seven seconds.
- **The bot**: buys the cheapest thing it can, shop or tree, and looks
  again only when its energy has changed. It holds the circle on a crate
  when one lies, else on the oldest tree, and with no tree standing on the
  biggest stack. **It never leaves a tree for a pile**, so it gathers what
  lies under its chopping and what it goes to when the land is bare.
  Nobody has measured a person who sweeps for piles, or one who sweeps
  many trees at a stroke.
- **A day's line**: the levels; the wood felled and the wood delivered
  since the start; the piles lying and the piles on the jetty as the day
  ends; `full N%`, the share of the frames played **since the line
  before** on which the jetty was full; the trees felled and how many of
  them by beavers. After the last day, the day and the hours played at
  which each kind was bought.
- **Run `pace` after touching any number of the sim** and put the tables
  in the new spec's section 10.

**The harness** (`tests/_shot_grove.gd`, windowed, about 50 s, 54 shots;
its header says each beat). Through the real menu, the circle held by a
`ScreenTouch`: `1` the tab; `2` to `6` a new grove, a chop, a fell and its
motes, a grove some days in; `6b` the Skills card with Room bought; `j1`
to `j6` stacks of every size lying, a gather with logs in the air, the
jetty part full, the raft half out, the jetty full and refusing, a landing
(`sw_0` and `sw_1` between them: a still chain 1.5 s apart, for the wind);
`s1` to `s8` (`SKILLS`) the faded nodes of kinds gone from the land, a
beaver of its own rearing and biting, five resting, a keen chop and one
that fells, a lucky pile under "x2", a crate afloat, thrown, ashore and
opened, a living Soft bough at a weak axe; `7w` and `7` the late grove
(`LATE`: the chain and every skill bought out, a land of thirty littered
into about forty stacks) at rest and under the circle; `7j` its jetty; `8`
the shop with an Axe bought; `9` to `13c` the tutorial's four pages; `w1`
and `w2` (`WORST`) the worst land, 68 stacks laid in rows through the
sim's own `_drop`, under the circle and then under the Skills card; `12`
the tab on that land. At each shot it prints the draw calls, the trees,
the stacks and what the jetty holds. It waits two frames after a poke
before it shoots. Wallet, Stock, the grove and Progress are throwaway
files (the tutorial's Continue wrote to the real `progress.cfg` until
a39ee9f3). **Why 68**: piles dropped at random jam a land at sixty-odd
stacks (they keep `MERGE` apart), 68 is the most the whole-branch review's
fuzz saw a played land hold, and rows laid as tight as stacks may be hold
98, which no played land was seen to reach.

**Measured** (2026-10-07 at a39ee9f3; the spec's section 10 has every
table and every beat).
- `godot --headless --path . --script res://tests/_probe_grove.gd`:
  `probe_grove: 135 checks, 0 failed`. `godot --headless --path . --script
  tests/run_tests.gd`: `passed=249790 failed=0`.
- **Pace**, the bot above (`-- pace 8 120 30` and the rest; "all" buys
  everything):

  | Run | Birch, Oak, Pine | Wood delivered of felled | Most piles lying on a printed day | The jetty full |
  |---|---|---|---|---|
  | 8 x 120 s, all | day 1, 4, 10 | 3,158,499 of 3,160,643 on day 30; 738 of 2,240 on day 1 | 5,980 (day 21) | 87% of day 1, 95 to 97% to day 21, 50% of days 22 to 30 |
  | 8 x 120 s, never Beavers or Fortune | day 1, 3, 8 | 1,201,818 of 1,202,875 | 2,840 (day 3) | 87% of day 1, 96 to 97% to day 7, 45% of days 8 to 10, then never |
  | 6 x 600 s, all | day 1, 1, 3 | 28,682,496 of 28,685,728 | 6,017 (day 3) | 95 to 97% to day 5, 67% of days 6 and 7, 10% and under after but for 26% of days 11 to 14 |
  | 2 h without stopping, all | 0.3 h, 1.0 h, not reached | 71,912 of 114,449 | 6,154 (the end) | 96% |
  | 8 x 120 s, never Beavers | day 1, 4, 10 | 2,347,646 of 2,349,439 | 3,711 (day 7) | 87% of day 1, 96 to 97% to day 10, 49% of days 11 to 14, then never |
  | 8 x 120 s, never Fortune | day 1, 3, 8 | 1,796,286 of 1,797,098 | 3,840 (day 7) | 87% of day 1, 95 to 97% to day 10, 20% and under after |

- **What the tables say.** The trunk reads day 1, 4 and 10 for the bot
  that buys everything, which is what the grove read before the tree, so
  the tree as a whole does not make it faster. **That is two things
  cancelling**: the Fortune root costs the cheapest-first buyer a day on
  Oak and two on Pine, and a player who leaves it alone reads day 1, 3 and
  8, sooner than the pace the spec's section 6 says the tree must not
  beat. Beavers move none of the three and bring the fourth kind two days
  sooner (day 20 against 22 without Fortune, 21 against 23 with it).
  **The neck binds from the first day.** Day 1 lands a third of its wood
  with the jetty full 87% of the frames played. The bot fells 77 trees a
  minute over that day, and its raft carries 20 piles a minute as the day
  starts and about 30 as it ends (the 30 is arithmetic from the levels it
  bought). **And it opens for good later**: between 5.6 and 8.0 hours of
  play for the two-minute player who buys everything, between 5 and 7 for
  the ten-minute one, and by 2.7 hours for the one who never buys Beavers
  or Fortune, before that bot's Jetty root is even complete (it fells
  fewer trees). From there every pile felled is delivered and the jetty
  decides nothing: the bot fells about 191 trees a minute over the last
  nine days of the ten-minute run, and the finished chain ties 534. Piles
  never rot, and the most lying on any printed day is about 6,000.
- **Draw calls** (810x1440, budget 855; each driver run twice, one window
  at a time, the second reading quoted and the first in brackets; trees
  come up at random, so the late beats move by tens between runs;
  `opengl3_angle` was run under reduce motion). `caffeinate -d -i -u godot
  --path . --resolution 810x1440 --always-on-top --script
  res://tests/_shot_grove.gd -- <outdir>`, and with `--rendering-driver
  opengl3_angle` before `--script` and `reduce` after the outdir.

  | Beat | default driver | `opengl3_angle`, reduce |
  |---|---|---|
  | the tab, a new grove | 111 (111) | 111 (111) |
  | a new grove (it was 50) | 59 (59) | 59 (59) |
  | a fell on it | 77 (76) | 74 (74) |
  | the Skills card, some days in | 138 (143) | 136 (134) |
  | the Skills card with faded nodes | 160 (161) | 159 (159) |
  | seven stacks lying | 92 (95) | 91 (91) |
  | a gather, logs in the air | 110 (112) | 96 (101) |
  | the jetty full, 44 of 44 | 106 (113) | 105 (105) |
  | a beaver of its own; five resting | 83; 83 | 82; 82 |
  | a keen chop; a lucky pile; a crate opened | 103; 99; 105 | 98; 95; 100 |
  | the late grove at rest, six frames | 236 to 272 (232 to 270) | 233 to 259 (231 to 253) |
  | the late grove under the circle | 379 (363) | 326 (334) |
  | its jetty, a full raft out | 362 (370) | 305 (305) |
  | the shop open over it | 378 (382) | 353 (323) |
  | the tutorial's pages over it | 315 to 338 (311 to 334) | 317 to 333 (309 to 325) |
  | **the worst land, 68 stacks, under the circle** | **459** (461) | **426** (394) |
  | the Skills card over the worst land | 390 (385) | 386 (374) |
  | the tab, on the worst land | 241 (241) | 241 (241) |

  The highest reading of any run is 471, the fix pass's own on the worst
  land; that is 55% of the budget. Frames, for what one Mac's milliseconds
  are worth (the frame that saved the shot before left out): 2.5 ms apart
  on a new grove, 7 on the late land at rest, 9.4 on the worst land on the
  default driver; 8, 17 and 30 on `opengl3_angle`, where the notes of
  2026-10-06 read 19 to 23 on that day's late land. Nobody has timed a
  phone.

**Not done.**
- **A phone.** Nothing of this ran on one: not the pan and the tap on the
  tree, not the gather, not the pause and resume, not the frame time of a
  late land.
- **Nothing was watched moving or heard.** Every judgement of the raft's
  way, the logs' flight, the crate washing up, a beaver arriving, the
  keen ring, the plate's shiver and the late chain's tempo (a bundle every
  1.2 s, the raft every 3.4 s) was made on stills. No sound was listened
  to.
- **pt and es were written by the agents and no speaker has read them.**
- **Known and left**: a tap during the eased pan after a buy still
  chooses; away beavers fell slightly more than live ones on a bite that
  overkills; `energy`, `wood_made` and `felled` are read from a file with
  no bound; the late land is busy (forty counts, keen figures over them);
  the links to a gone kind's boughs are not faded; a resting beaver can
  stand behind a crown; a pile's baked shadow is not cut at the land's
  edge.
- **Decided for the user and not judged by them**, each one line to change
  or one table to retune:
  - The prices and last levels of every node (`Sim.NODE`, `KIND`,
    `SOFT_PRICE`, `RICH`), and what a level is worth.
  - The chain's figures (jetty 8 and 3 a level, tying 6 s, a bundle of 4,
    the raft 12 s, Load to 3), widened once after the bot's first month
    landed a third of its wood; and that **the neck opens for good once
    the Jetty root is bought out, about six to eight hours of play in**
    (sooner for a player who fells less). The user asked for a bottleneck;
    if it should never open, the root's nodes lose their last levels as
    the Axe has none.
  - Piles never rot. The user's choice was "Jetty has room, logs wait";
    that they wait for ever and in any number is the agent's reading of
    it. While the land fells more than the raft carries they pile up, to
    about 6,000 for the bot.
  - Beavers never rest with someone there, and fell the land once over
    each while away, a share for every return.
  - A beaver gathers nothing. One that carries piles is the obvious next
    node and is not built.
  - Boughs of a kind gone from the land cannot be bought.
  - The Jetty root's order: Raft, Jetty, Bundle, Tying, Load.
  - Crates is the fourth node of its root, behind Keen edge, Heavy blow
    and Lucky wood.
  - The button is called Skills (pt and es "Habilidades"), and is the
    paper button beside the sun one.
  - The tab's chip shows the chain's ceiling ("20 / min" on a new grove)
    where the user's words on 2026-10-06 were "gonna be -- till automation
    is enabled".
  - The jetty stands level with the turf on tall posts, with the raft far
    below its end and nothing drawn of a bundle going down.
  - The tab's card shows no counts on its stacks and no beavers.
  - New sounds are owed: a landing and a crate are `fell`, a gathered log
    and a beaver's tree are `chop`.
  - Smaller: `TAP` 24; faded is a mix toward paper, not alpha; a gone
    node's bar is empty and silent; a beaver's own fell is a quiet click
    with no "+N"; `SAVE_SLOW` 20 s; the tab's beavers lose the seconds
    before a landing's save; Lucky wood and the whole Jetty root return no
    energy while nothing in the valley spends wood; a player who skips
    Fortune reaches Pine two days sooner than the grove did before the
    tree.
