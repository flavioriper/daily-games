## Valley

**A sixth tab since 2026-10-05**, between Arcade and Stats: slow places
that share one inventory and have no finish (spec
`2026-10-05-valley-grove-design.md`; the concept and its four passes are
`docs/brainstorm/concepts.html#valley`). Like Versus and Arcade it is not a
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
the finger and chops what is inside it; nothing chops by itself. A felled
tree gives wood (to Stock) and the same energy (the Grove's own), and energy
buys six tiles.

**The land takes the screen and the tiles are a card over it** (the user,
2026-10-06: "game should take most of screen, and shop should be a dialog
inside the game that opens by clicking a button"). Under the two plates the
pond runs down to one row: the **Shop** button on the left (the sun button,
`trend`, its badge the number of tiles the energy reaches; left because the
thumb that chops rests on the right) and the count and the hint on the
right. `open_shop` shows a card built once (`_build_shop`: `Dialog.card`,
the energy held on a pill, a round X, the six tiles three to a row as they
were); the X, a press on the scrim and Android's back close it. The grove
goes on behind it, but nothing is chopped.

**The card's layout was polished the same day** (the user, on a shot of it:
"polish shop layout"). What was wrong: a tile was 264 tall for 276 of
content, so the picture touched its top and the price sat on its bottom
edge; a tile the energy did not reach was the whole button at 0.78 alpha,
so the card's sprigs showed through five of the six on a new grove; a tree
stood out of its disc and hid it while Swing's arcs were small in theirs;
the card was 1020 wide over a column of 1000. Now (`_tile`,
`_draw_tile_icon`, `_refresh_tiles`):
- **A tile is 344 tall** (`TILE_H`), the card 1000 by 868: the picture on a
  disc of `DISC_R` 60, the name and the effect centred in what is left, and
  the price on a bar along the tile's foot (`PRICE_H` 64, as wide as the
  tile less `TILE_PAD`).
- **The price bar alone says whether the energy reaches**: the sun button's
  own (ink on `SUN`, a `SUN_DEEP` lip) when it does, paper (`PRICE_OFF`) and
  dim figures when it does not. **No tile is faded**: the picture, the name
  and the effect of what is being saved for stay as sharp as the rest.
- **A tile with no level left keeps its bar**, a leaf one with a tick and
  `GROVE_MAX`, so six bars line up; its corner chip goes on saying its
  level (it said "max").
- **Every picture is fitted to its disc** by its mesh's own box
  (`DISC_FIT` 0.78 of the width; a small one grown `DISC_GROW` 1.3 at most,
  or Swing's strokes come out twice as thick as the axe's).
- The effect line is still 24 px on one line: the longest it gets
  ("Bétula XI também cresce") is 273 of the 277 there are, and at 26 a
  line of the first grove wraps in Portuguese. **A new effect string is
  measured in pt and es before it ships.**
- Draw calls where they were: 131 on a new grove with the card open, 232-262
  on the land of thirty (810x1440, and 810x1755 on `opengl3_angle`).
- **Not done: a phone**, and the user has not seen it.

**The land is seen in isometric since 2026-10-06** (the user: "redesign
grove game to have a isometric view, with a studio ... looking like"). The
look is the game's soft painted one (`docs/art/shading-direction.md`); the
studio is named nowhere. The rules, the numbers, the six tiles and the
shop's card are untouched.
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
  twice the trees late on**, which no bot here measures.
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

The tab's card takes the whole tab for the tall picture. **It is called the Grove and nothing else**: the game it
follows is named once, in the spec.

- **The game is pure data** (`valley/grove_sim.gd`): land units on the
  ground, `step(dt, holding, at)`, `events` for the screen to drain, `buy`,
  and its own keeping (`save(now)`, `load_saved(now)`, `Sim.path`). It never
  touches Stock: the screen hands each felled tree's wood over.
  `tests/_probe_grove.gd` checks the arithmetic (33 checks) and
  `-- pace [visits] [seconds] [days]` or `-- marathon [hours]` plays it with
  a bot; **run `pace` after touching any number** and put the table in the
  spec's section 4.
- **Every tree starts at 4** (`Sim.HP`; the user: "each tree start as 4hp").
  Axe and Seeds have no last level; Reach, Swing, Sprout and Room stop.
- **Away is worked out, never run**: `load_saved` adds the trees that came
  up since `seen`, up to the room. The tab keeps its own sim from the file
  and steps it for the card's picture; **Play saves that sim first**, so the
  screen opens on the same trees.
- **One mesh a tree** (`valley/grove_art.gd`, cached per look), one for the
  whole pond and land (`Art.ground`, rebuilt on resize only), one MultiMesh
  for the tufts and one for the flowers, a draw a number. 92 draw calls on a new grove, 246-286 on a land of thirty with a
  circle over a dozen trees and their numbers, about 230 under the tutorial
  card (810x1440, 2026-10-05; the same on `opengl3_angle`, 92 and 275).
  Frames came 8 to 10 ms apart through the whole harness run on both.
  **With the tiles off the screen (2026-10-06): 46 on a new grove, 176-201
  on the land of thirty under the circle, 246-265 with the shop's card
  open, about 180 under the tutorial card**, both drivers.
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
  The wood's logs fly as they did. Under reduce motion nothing flies and
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
  - **Not done: a phone** (the shader has only run on this Mac's two
    drivers), and nobody has watched it move: every judgement was made on
    stills a third of a second apart.
- **The fonts have no arrow and no star.** A tile says "chop 1, then 2" and
  a tree past the fifth tier is "Birch II" (`tree_name`).
- **Sounds** (`assets/sfx/grove/`, `tools/gen_sfx.py grove`): `chop` is a 90
  ms click, the quietest of the set, since it repeats for as long as the
  finger is held; `fell`, `buy`, `no`. Unheard by the user.
- **Haptics** (`docs/agents/haptics.md` row 40): fell taps, a tile bought
  bumps, one refused warns; a chop that hits is felt only as its sound's
  echo.
- **Analytics**: `valley_enter` (place, trees, room), `valley_leave` (place,
  seconds, felled), `grove_upgrade` (tile, level, energy).
- `tests/_shot_grove.gd` shoots the tab, a new grove, a chop, a fell (and
  two frames of its motes), a middle and a late grove, the shop opened by
  its button with a tile bought and closed by its X, the tutorial's three pages and the
  tab again, on throwaway files. It prints frames and their mean gap between
  shots; `Performance.TIME_PROCESS` read 100 ms on frames 9 ms apart under
  `--script` and is not printed.
- **Not built**: automation, chests, critical hits, timed days, a skill
  tree, ads, a growing land, a second place. Nothing run on a phone.
