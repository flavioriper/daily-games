# The Grove's Tree and Jetty Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Grove gets a skill tree (Sprout, Room and Seeds leave the shop for it), a jetty its wood has to leave by, and four skills (a beaver of its own, keen chops, lucky wood, crates).

**Architecture:** All rules go in the pure-data sim (`valley/grove_sim.gd`), which still never draws, reads the clock or touches `Stock`. The tree is one new Control (`valley/grove_tree.gd`) over the sim's node ids. What lies and moves on the land (piles, bundles, the raft, a crate, own beavers) is drawn by `valley/grove_life.gd` so the screen, the tab's card and the tutorial get it alike.

**Tech Stack:** Godot 4 (gl_compatibility), GDScript, the repo's own `ui/` kit. No new dependency.

**Spec:** `docs/superpowers/specs/2026-10-07-grove-tree-and-jetty-design.md`. Read it whole before any task. Also read `docs/agents/valley.md` (the Grove's history and rules), `docs/agents/harnesses.md`, and `CLAUDE.md`.

## Global Constraints

- The reference game is named nowhere: not in code, comments, commits, strings or docs. Write "the reference".
- **No new tests.** The project is an MVP: verify with `tests/_probe_grove.gd` (kept running, a few checks added where this plan says), the shot harness, and throwaway probes. If the suite breaks because a constant or a shape changed, make the smallest edit that unbreaks it.
- The sim never touches `Stock`, never draws, never reads the clock.
- Energy pays for everything. Nothing in the Grove spends wood.
- A kept grove (`user://grove.cfg` written before this) must load: its `lv` keys keep their names (`axe reach swing sprout room seeds`) and levels.
- Budget: 855 draw calls at 810x1440. A drawing is a cached `ArrayMesh` issued by one `draw_mesh`; never a Button a node; no `instance uniform`.
- A finger is an `InputEventScreenTouch` / `ScreenDrag`; `emulate_mouse_from_touch` is off. Hand-written input takes both touch and mouse.
- Every string is a key in `locale/ui.csv` with en, pt, es. The fonts carry no arrow, no star and no multiplication sign: "6.0 s, then 5.6", "x2". Seconds are written with a comma in pt and es (`_decimal`).
- Motion from `core/motion.gd`; honour `Motion.reduce`. Rings and puffs from `ui/fx2d.gd`. Energy is motes (`ui/motes.gd`), never rays or sparks.
- Characters are code (`ui/faces/`): the beaver is `ui/faces/beaver.gd`.
- Buttons keep their own size (shrink-centre; a container never stretches one). Readouts and buttons go on the left: the right thumb chops.
- Windowed harnesses: one at a time, `--resolution 810x1440` before `--script`, `--always-on-top`, under `caffeinate -d -i -u`, output to a file (never piped into `head`). Godot may re-save `project.godot` with a header comment after a windowed run: `git checkout project.godot` only if `git diff project.godot` shows nothing else.
- Commits: conventional, `feat(grove): ...`, one or more a task. Never push. Never commit `docs/brainstorm/concepts.html` (another agent is editing it).
- At most one background process at a time; kill what you start.

## Review Focus

- A grove kept before this build, with Sprout 9, Room 12, Seeds 3 and a full land: it loads with those levels, the trunk shows four kinds owned, nothing is refunded or lost.
- The app is killed between the raft landing and the next save: wood is neither counted twice nor lost beyond one landing.
- Three days away with a full jetty and five beavers: the load is instant (no per-second loop), the jetty is empty, the land holds at most `room()` piles more than it did.
- A full jetty with the circle held over a stack of 40 piles: none is taken, nothing flickers, trees keep coming up and are chopped.
- Portuguese and Spanish: no node name, effect line or button label is clipped or wraps on the card at 810 wide.

## File Structure

| File | Role |
|---|---|
| `valley/grove_sim.gd` (modify) | nodes, boughs, the chain, beavers, fortune, keeping |
| `valley/grove_tree.gd` (create) | the Skills card: the drawn tree, panning, the foot card |
| `valley/grove_screen.gd` (modify) | three-tile shop, Skills button, jetty plate, flies, numbers, `owed` |
| `valley/grove_art.gd` (modify) | planks in the ground mesh; pile, bundle, raft, crate meshes; node icons |
| `valley/grove_life.gd` (modify) | piles, bundles, raft, crate, own beavers, for every holder |
| `ui/menu/valley_tab.gd` (modify) | `owed` to `Stock`; the chip |
| `ui/hud/grove_tutorial_diagram.gd` (modify) | a SEND lesson |
| `tests/_probe_grove.gd`, `tests/_shot_grove.gd` (modify) | kept running; new checks, new beats |
| `locale/ui.csv` (modify) | every new string |
| `docs/agents/valley.md`, `haptics.md`, `analytics.md`, the spec's section 9 | the record |

---

### Task 1: The sim's nodes, trunk and boughs

**Files:** modify `valley/grove_sim.gd`, `tests/_probe_grove.gd`; smallest compile fixes only in `valley/grove_screen.gd` (it reads `Sim.TILES`).

**Interfaces produced** (exact names; later tasks call these):

```gdscript
const SHOP := ["axe", "reach", "swing"]
const ROOT_ORDER := ["land", "jetty", "beavers", "fortune"]
const ROOTS := {
	"land": ["room", "sprout"],
	"jetty": ["jetty", "tying", "bundle", "raft", "load"],
	"beavers": ["beaver", "teeth"],
	"fortune": ["crit", "critsize", "luck", "crate", "cratesize"],
}
## id -> [first price, what a level multiplies it by, last level (0: none)]
const NODE := {
	"axe": [10.0, 1.38, 0], "reach": [40.0, 2.1, 12], "swing": [30.0, 1.9, 15],
	"room": [12.0, 1.5, 27], "sprout": [15.0, 1.65, 20],
	"jetty": [20.0, 1.45, 20], "tying": [40.0, 1.7, 15], "bundle": [60.0, 2.2, 7],
	"raft": [50.0, 1.7, 15], "load": [300.0, 3.0, 5],
	"beaver": [250.0, 4.0, 5], "teeth": [500.0, 2.4, 5],
	"crit": [80.0, 1.8, 10], "critsize": [150.0, 2.0, 6], "luck": [100.0, 1.8, 10],
	"crate": [200.0, 1.9, 10], "cratesize": [250.0, 1.9, 10],
}
const KIND := [120.0, 7.0]        # kind:N costs 120 * 7^(N-1), N from 1
const SAPLING := 20.0             # the Sapling's own price, for its boughs
const SOFT_PRICE := [0.5, 1.5]    # of the kind's price, a level
const RICH_PRICE := [0.75, 2.25]  # the Sapling's one level: 1.5
const SOFT_STEP := 0.25           # of the kind's chops, a level
const RICH_STEP := 0.5            # of the kind's yield, a level (the Sapling: 1.0)

var lv := {...}             # every NODE id and "seeds", all 0
var soft: Array[int] = []   # by tier, grown on demand
var rich: Array[int] = []

static func part_of(id: String) -> String   # "kind" / "soft" / "rich" for "kind:3"; else the id
static func tier_of(id: String) -> int      # 3 for "soft:3"; -1 for a plain id
static func kind_price(tier: int) -> float  # SAPLING for 0, else KIND
func level(id: String) -> int               # kind:N is 1 when lv.seeds >= N
func last_level(id: String) -> int          # kind 1, soft 2, rich 2 (rich:0 is 1), NODE[id][2]
func is_done(id: String) -> bool
func cost(id: String) -> int
func before(id: String) -> String           # "" for a root's first node and soft:0 / rich:0;
                                            # kind:N-1 for kind:N; kind:N for soft:N and rich:N;
                                            # the node above it in its root otherwise
func is_open(id: String) -> bool            # before(id) == "" or level(before(id)) > 0 or level(id) > 0
func can_buy(id: String) -> bool            # open, not done, energy >= cost
func buy(id: String) -> bool
func shown() -> Array[String]               # the tree's nodes to draw: every root node that has a
                                            # level or is open; kind:0 .. kind:seeds+1; soft:N and
                                            # rich:N for N in 0 .. seeds. Never a SHOP id.
func reachable() -> int                     # how many of shown() can be bought now
func hp(tier: int) -> float                 # hp_of(tier) * (1 - SOFT_STEP * soft level)
func give(tier: int) -> int                 # give_of(tier) with the Rich bough: +50% a level, the Sapling x2
func value(id: String, at := -1) -> float   # the figure a node stands for at level `at` (-1: now):
                                            # room -> trees, sprout -> seconds, soft:N -> chops of that
                                            # kind, rich:N -> its yield; 0.0 where it has none yet
```

- [ ] **Step 1:** Read the spec's section 3 and the whole of `valley/grove_sim.gd` and `tests/_probe_grove.gd`. `grep -rn "Sim.TILES\|Sim.TILE\b\|hp_of\|give_of\|\.lv\b" --include=*.gd .` and list every caller.
- [ ] **Step 2:** Replace `TILES` / `TILE` by the constants above. Keep `TILES` as `const TILES := SHOP` only if a caller outside the Grove needs it; otherwise remove it and fix callers. `cost`, `last_level`, `is_done`, `can_buy`, `buy` take any id. `buy("kind:N")` requires `N == lv.seeds + 1` and raises `lv.seeds`; `buy("seeds")` stays as a synonym for the next kind so old callers and the probe work.
- [ ] **Step 3:** `_plant` gives a tree `hp(tier)`; `_chop` gives `give(tree.tier)`; buying `soft:N` clamps standing trees of tier N to the new `hp(N)`. `hp_of` / `give_of` stay static and mean "before the boughs". Everything that shows a tree's bar against its most (`grove_screen.gd` `_draw_top`, the tab, the tutorial diagram, Life) uses `sim.hp(tier)`.
- [ ] **Step 4:** Keeping: `save` writes every `lv` key, and `soft` / `rich` as arrays under a `tree` section. `load_saved` reads them with the same clamps as today (a level never above its last); a file without the new keys loads as today's grove with bare boughs.
- [ ] **Step 5:** The probe: keep its 40 checks passing (rename what moved), and add: a kept file with `sprout 9, room 12, seeds 3` loads with those levels and `shown()` holds `kind:0..kind:4`; `is_open("sprout")` is false on a new grove and true once `room` has a level; `soft:0` at level 1 makes a new sapling 3 chops of 1; `rich:1` at level 1 makes a birch give 3; `cost("soft:2")` is `round(0.5 * 840)`. The pace bot buys the cheapest thing `can_buy` allows over `SHOP + shown()`, and takes an optional last argument, a comma list of ids it never buys (`-- pace 8 120 30 soft,rich`: any id whose `part_of` or id is in the list).
- [ ] **Step 6:** Verify.
  - `godot --headless --path . --check-only --script valley/grove_sim.gd` and the same for `valley/grove_screen.gd`: no errors.
  - `godot --headless --path . --script res://tests/_probe_grove.gd`: prints `probe_grove: N checks, 0 failed`.
  - `godot --headless --path . --script res://tests/_probe_grove.gd -- pace 8 120 30` and again with `soft,rich`: both tables in your report, with the day Birch, Oak and Pine open.
  - The suite as `docs/agents/harnesses.md` / `docs/agents/ci.md` run it: 0 failed.
- [ ] **Step 7:** Commit `feat(grove): the sim's nodes, trunk and boughs`.

The screen is not finished by this task: Sprout, Room and Seeds are not buyable from it until Task 2. It must parse and run.

### Task 2: The Skills card, the three-tile shop

**Files:** create `valley/grove_tree.gd`; modify `valley/grove_screen.gd`, `valley/grove_art.gd` (icons), `locale/ui.csv`.

**Consumes:** Task 1's interface, exactly as written above.

**Produces:**

```gdscript
# valley/grove_tree.gd  (extends Control; built once by the screen, like the shop)
signal bought(id: String, paid: int)
signal refused(id: String)
func setup(sim: RefCounted, tree_name: Callable) -> void   # tree_name(tier) -> String, the screen's own
func open() -> void
func close() -> void
func is_open() -> bool
func refresh() -> void            # after energy or a level changed
func select(id: String) -> void   # choose a node (the harness uses it)
func buy_selected() -> void
func pan_to(id: String) -> void
# valley/grove_art.gd
static func icon(tile: String, look := 1) -> ArrayMesh   # now answers every root node id too
```

- [ ] **Step 1:** Read the spec's section 3 ("The card") and `grove_screen.gd` `_build_shop`, `_tile`, `_refresh_tiles`, `_effect`, `_on_tile`, `go_back`. The card copies the shop's head (energy pill, round X), scrim and closing rules.
- [ ] **Step 2: Layout.** Grid units, x across and y up, the Sapling at (0, 0): `kind:N` at (0, N), `soft:N` at (-1, N), `rich:N` at (1, N); the roots in columns -1.5, -0.5, 0.5, 1.5 (`ROOT_ORDER`), a root's nodes at y = -1, -2, ... A cell is about 236 by 216 px at 810 wide, a node's plate about 128 square: four root columns must fit the card's inner width with a margin. A line of soil crosses at y = -0.5: paper above, the Grove's earth tones (`Art.EARTH`) below.
- [ ] **Step 3: Drawing.** One Control draws everything: the soil and background as one cached mesh; the links (trunk thick, boughs and roots thinner, bark brown, drawn only between shown nodes) as one mesh rebuilt when `shown()` changes; each node one cached mesh for plate plus picture, keyed by picture and state (reachable: sun rim; open but not reachable: paper; has levels: paper with a level chip; done: leaf with a tick; chosen: a ring), and one `draw_string` for its figure (the level, or the price under an open node with no level). A kind's picture is `Art.tree(Sim.look_of(tier))` fitted to the plate, with the lap's gold marks. Count the draw calls with the card open and put the figure in your report.
- [ ] **Step 4: Input.** Touch and mouse: a press that moves under 12 px is a tap and chooses the node under it (or nothing); a drag pans, vertically only, clamped so the lowest root and the highest shown node can both reach the middle. Opening puts the foot in the lower third, or the last bought node in view.
- [ ] **Step 5: The foot card.** Name; one effect line ("now X, then Y", built from `sim.value(id)` and `sim.value(id, level + 1)`, each node its own locale key); the level as "n / N", or n alone where there is no last; the price on the shop's sun bar (`_refresh_tiles` shows the three looks: reachable, not, done). The bar is the only Button. Pressing it: `sim.buy`, emit `bought`, or shake and emit `refused`. With nothing chosen the card says one line of help.
- [ ] **Step 6: The screen.** The shop grid shows `Sim.SHOP` (one row; the card shrinks to fit). A second `IconButton` "Skills" (`tree` icon, key `GROVE_SKILLS`) beside Shop; both about 240 wide so the row of 730 keeps the count on the right; the hint label leaves the row. Its badge is `sim.reachable()`; Shop's badge counts `SHOP` only. `bought` plays `buy`, tracks `grove_upgrade` with the node id as `tile`, saves; `refused` plays `no`. The card open stops the chopping as the shop does; `go_back` closes it first. The tutorial's hold and the settings sheet behave as with the shop.
- [ ] **Step 7: Words.** Keys for the button, the card's title, the help line, each root node's name and effect line, Soft and Rich (name takes the tree's name: "Soft Birch"), a kind's line ("Birch grows too" already exists as `GROVE_FX_SEEDS`). Names as the spec's table. Measure every effect line in pt and es at the card's font size against the room it has (a throwaway headless script with `Font.get_string_size`), and shorten what does not fit.
- [ ] **Step 8:** Verify.
  - `--check-only` on the three scripts.
  - A throwaway windowed probe (`tests/_tmp_tree.gd`, deleted before the commit; model it on `tests/_shot_grove.gd`: throwaway files, the field's mouse filter ignored, poke on one frame and `force_draw()` on the next): shots of the card on a new grove, on a grove with `seeds 3` and several levels with a node chosen, panned to the top, the shop with three tiles, the row with both buttons, in en and in pt. Look at every shot (Read tool) and fix what is clipped, overlapping or unreadable. Report the draw calls of each.
  - The probe and the suite still pass.
- [ ] **Step 9:** Commit `feat(grove): the skills tree and a three-tile shop`.

### Task 3: The sim's jetty, beavers and fortune

**Files:** modify `valley/grove_sim.gd`, `tests/_probe_grove.gd`; smallest fixes in `valley/grove_screen.gd` and `ui/menu/valley_tab.gd` so wood still reaches `Stock` (see Step 6).

**Consumes:** Task 1. **Produces:**

```gdscript
const MERGE := 70.0      # a pile that comes down this near another joins it
const LIES := 0.9        # seconds before a pile can be gathered (the fall)
const JETTY := 6;  const JETTY_STEP := 2
const TIE := 12.0; const TIE_STEP := 0.9
const BUNDLE := 3
const RAFT := 24.0; const RAFT_STEP := 0.92
const BITE_EVERY := 1.0; const BITE := 0.5; const BITE_STEP := 0.1
const CRIT_STEP := 0.05; const CRIT_SIZE := 2.0; const CRIT_SIZE_STEP := 0.5
const LUCK_STEP := 0.04
const CRATE := 180.0; const CRATE_STEP := 0.9; const CRATE_GIVE := 15; const CRATE_GIVE_STEP := 0.2

var logs: Array[Dictionary] = []   # lying: {id, pos, n, wood, tier, lucky, born}
var loose := {"n": 0, "wood": 0}   # on the jetty, not tied yet
var bundles: Array[Dictionary] = []  # tied, waiting: {n, wood}
var raft := {"n": 0, "wood": 0, "t": 0.0, "away": false}
var tie_t := 0.0                   # seconds into the bundle being tied
var owed := 0                      # wood the raft has landed that Stock has not been given
var wood_sent := 0
var crate := {}                    # {} or {pos}
var gnawing: Array[Dictionary] = []  # a beaver each: {tree (id, 0: resting), t}

func jetty_room() -> int;  func jetty_held() -> int   # loose and bundled, not what is on the raft
func tie_time() -> float;  func bundle_size() -> int
func raft_time() -> float; func raft_load() -> int
func raft_at() -> float            # 0 home, 1 at the far side, back to 0
func lying() -> int                # piles lying on the land, stacks counted through
func beavers() -> int;     func bite() -> float       # the share of power() a bite takes
func crit_chance() -> float; func crit_size() -> float; func luck_chance() -> float
func crate_time() -> float         # 0.0 without the node
func crate_give() -> int
func take_owed() -> int            # returns owed and sets it to 0
func grows(tier: int) -> bool      # tier >= lv.seeds - 2: the land still grows it
func wood_per_min() -> float       # the chain's most, spec section 4
# events, added: {kind: "log", log}, {kind: "gather", pos, tier, n, wood},
#   {kind: "tied", n, wood}, {kind: "sailed", n, wood}, {kind: "landed", wood},
#   {kind: "crate", pos}, {kind: "opened", pos, give}
# events, changed: "hit" gains keen: bool and by: "axe" | "beaver";
#   "fell" gains lucky: bool and by; "fell".give stays the energy given
```

- [ ] **Step 1:** Read the spec's sections 4, 5 and 6.
- [ ] **Step 1b: The Jetty root's order.** Task 1 wrote `ROOTS.jetty` as `["jetty", "tying", "bundle", "raft", "load"]`. The spec's table is now `["raft", "jetty", "bundle", "tying", "load"]` (the node that widens the neck first): change the constant, and anything in the probe that assumed the old order. Fill `value(id, at)` for every root node now (`jetty` piles, `tying` seconds, `bundle` piles, `raft` seconds, `load` bundles, `beaver` count, `teeth` percent of a chop, `crit` percent, `critsize` chops, `luck` percent, `crate` seconds between crates (0.0 at level 0), `cratesize` energy in a crate): the Skills card writes its lines from it.
- [ ] **Step 2: Piles.** A fell appends a pile at the tree's place (or joins one within `MERGE`): `n` 1, `wood` `give(tier)`, doubled with `lucky` when `luck_chance()` hits. `wood_made` counts at the fell as before; energy is unchanged. On each swing, after the chop, every pile at least `LIES` old and within `reach()` of the circle's centre gives the jetty `min(n, jetty_room() - jetty_held())` of its piles and that share of its wood (rounded so nothing is created or lost over a stack); an emptied pile is erased.
- [ ] **Step 3: The chain**, in one function `_send(dt)` that works by events and so takes any `dt` (it is what `catch_up` calls with the seconds away): tying runs while `loose.n >= bundle_size()`, or while `loose.n > 0` with the raft home and no bundle waiting (spec 4.4: a short bundle only when the chain would otherwise stand still), and takes up to `bundle_size()` piles when `tie_time()` is up; the raft, home with a bundle waiting, takes up to `raft_load()` and leaves; at half `raft_time()` its wood goes to `owed` and `wood_sent` (event `landed`); at the whole it is home. `catch_up` clears the events it made but leaves `owed`.
- [ ] **Step 4: Beavers.** `gnawing` holds `beavers()` entries. A resting beaver takes the standing tree with the lowest id no other has; with someone there it never rests otherwise. Every `BITE_EVERY` it takes `power() * bite()` off its tree (event `hit`, `by: "beaver"`, never keen); a tree brought down by a bite falls as any does (`by: "beaver"`). A beaver whose tree the axe fells rests. Away (`catch_up`): the beavers fell at most `beavers() * room()` trees (the land once over a beaver, spec section 5), each drawn from the mix as `_plant` draws, taking `hp(tier) / (beavers() * power() * bite() / BITE_EVERY)` seconds from the seconds gone; each gives its energy and leaves a pile at a spot `_spot()` finds; no loop over seconds.
- [ ] **Step 4b: Kinds gone from the land.** `grows(tier)`; `can_buy` is false for `soft:N` and `rich:N` when `not grows(N)` (their levels are kept and still shown).
- [ ] **Step 5: Fortune.** Each tree hit by the axe rolls `crit_chance()` for `power() * crit_size()` (`keen: true`). With `crate` at a level, a timer of `crate_time()` runs while no crate lies; at its end one appears at a point on the land within 140 of the front corner's two edges (event `crate`); a swing with the circle over it gives `crate_give()` energy (event `opened`) and the timer starts again. Away the timer counts and at most one crate is waiting. `crate_give()` is `CRATE_GIVE * give_of(lv.seeds)` grown by `CRATE_GIVE_STEP` a level of `cratesize`.
- [ ] **Step 6: Wood to Stock.** `grove_screen.gd` stops adding wood at `fell` and, each frame, hands `sim.take_owed()` to `Stock.add("wood", n, GAME)` and marks itself dirty; `valley_tab.gd` does the same for its own sim. The wood plate counts `Stock` alone (`_wood_air` goes). Nothing new is drawn yet: piles are invisible until Task 4, which is fine for one commit.
- [ ] **Step 7: Keeping.** Save `logs`, `loose`, `bundles`, `raft`, `tie_t`, `owed`, `wood_sent`, the crate and its timer. A file without them loads with an empty jetty.
- [ ] **Step 8: The probe.** Add: a felled sapling leaves one pile of one wood and `Stock` is not touched; held 1 s more it is on the jetty; six piles on a jetty of six and a seventh stays lying; `_send` over 10,000 s empties a full jetty into `owed` and equals the same seconds stepped a frame at a time (same `owed`, same `wood_sent`); two fells 40 apart are one stack of two; with one beaver and nobody holding, a sapling comes down in `hp / (power * bite)` seconds and its pile lies; a beaver goes on biting with fifty piles lying; three days away with five beavers fells exactly `5 * room()` trees and returns at once; `soft:0` cannot be bought once `lv.seeds` is 3 and `grows(0)` is false; with room 8 and a bundle of 3, eight piles on the jetty leave as 3, 3 and, only once the raft is home with nothing waiting, 2. The pace bot: holds on the oldest tree and, with no tree standing, on the biggest pile; hands `take_owed()` to a counter; prints, a day, the wood felled and the wood delivered beside what it prints now.
- [ ] **Step 9:** Verify: `--check-only`; the probe 0 failed; the suite 0 failed; and these four pace runs, all in your report with the days Birch, Oak and Pine open, and wood felled against wood delivered on day 30:
  `-- pace 8 120 30`, `-- pace 8 120 30 beaver,teeth,crit,critsize,luck,crate,cratesize`, `-- pace 6 600 30`, `-- marathon 2`.
- [ ] **Step 10:** Commit `feat(grove): the jetty, beavers and fortune in the sim`.

### Task 4: The jetty on the land

**Files:** modify `valley/grove_art.gd`, `valley/grove_life.gd`, `valley/grove_screen.gd`, `ui/menu/valley_tab.gd`, `ui/hud/grove_tutorial_diagram.gd`, `locale/ui.csv`.

**Consumes:** Task 3's state and events.

- [ ] **Step 1:** Read `docs/agents/valley.md` from "Beavers, cast shadows and a real fall" down: Life is where a new look for the land goes, and the wind's shader leans every vertex above its item's own y = 0. **Nothing here may sway**: build these meshes so the shader leaves them alone (the doc says what stays still), and prove it with two frames 1.5 s apart.
- [ ] **Step 2: Art.** Planks off the land's front left edge into the pond, baked into `Art.ground` (posts, a shadow on the water, no step in the land). `Art.jetty() -> Vector2` (view units: where piles are stacked) and `Art.raft_at(k: float) -> Vector2` (view units, k as `sim.raft_at()`: home at the jetty's end, off the field's left edge at 1). Cached meshes: `Art.pile(n)` (one, two, three or more logs), `Art.bundle()`, `Art.raft()`. Painted as the rest is (`docs/art/shading-direction.md`), lit from the upper left.
- [ ] **Step 3: Life.** In `draw`: lying piles sorted by depth with the trees (a stack over one shows its count; a lucky one is drawn doubled); on the jetty, the loose piles as a heap that grows with `loose.n` and each waiting bundle (draw at most six, then a count); the raft at `Art.raft_at(sim.raft_at())` with its bundles, rocking a little unless `Motion.reduce`, gone past the field's edge, never anything on a far shore. A pile appears when its tree has landed (Life's `gave`), not at the sim's event.
- [ ] **Step 4: The screen.** `gather` events throw logs from the pile to the jetty (the `_flies` the wood plate had, re-aimed; a quiet `chop` each, as the motes' landing is); `landed` kicks the wood plate, plays `fell` quietly and raises "+N" in gold beside the plate (the raft is off the screen when it lands, so this is the only sign); the wood plate rolls up `Stock`. A small paper plate by the jetty says `held / room` (`draw_string` in the Top layer; it turns the warn colour and shivers once when a gather is refused because the jetty is full). The tab's card and the tutorial get piles and raft through Life with no code of their own beyond what Step 3 needs.
- [ ] **Step 5: The tab.** The chip shows `sim.wood_per_min()` (it is never zero now; keep `_write_rate`'s "--" for zero).
- [ ] **Step 6: The tutorial.** `TUT_GROVE_GIFTS_BODY` says the wood is left lying and the circle carries it to the jetty; a fourth page, `Lesson.SEND` (`TUT_GROVE_SEND`, `TUT_GROVE_SEND_BODY`), shows piles going to the jetty, a bundle tied and the raft leaving, on the diagram's own sim.
- [ ] **Step 7:** Verify with `tests/_shot_grove.gd` extended by beats for: piles lying after a fell, the circle gathering, the jetty part full with a bundle, the raft half way, the jetty full with piles left lying, the tutorial's fourth page. Run it once at 810x1440, and once with `--rendering-driver opengl3_angle` and `reduce`. Look at every shot. Report the draw calls of each beat on both drivers (the late grove under the circle read 287 before this; say what it reads now).
- [ ] **Step 8:** Commit `feat(grove): piles, the jetty and the raft on the land`.

### Task 5: The skills on the land

**Files:** modify `valley/grove_art.gd`, `valley/grove_life.gd`, `valley/grove_screen.gd`, `ui/hud/grove_tutorial_diagram.gd` only if it breaks, `locale/ui.csv` if a word is missing.

- [ ] **Step 1: Own beavers.** Life shows a beaver at every tree in `sim.gnawing` exactly as it shows one at a tree the circle takes (it rears as its bite comes due and its teeth are in on the sim's `hit` with `by: "beaver"`); a resting beaver sits at the land's back edge. No new drawing of the animal.
- [ ] **Step 2: Keen chops.** A `hit` with `keen` shows its number half as large again, in `Art.MARK`, with a ring from `ui/fx2d.gd` at the tree. A beaver's bites show no number.
- [ ] **Step 3: Lucky wood.** As a lucky pile lands, "x2" rises over it as a fell's gold number does.
- [ ] **Step 4: Crates.** `Art.crate()` (a wooden crate with rope, cached); Life draws it at `sim.crate.pos`, bobbing in from the water over 0.6 s on the `crate` event unless reduced; `opened` bursts it (a puff, the planks as chips) and drops `give * ORBS` motes from it to the energy plate, with `fell` as its sound and its haptic.
- [ ] **Step 4b: Kinds gone from the land, on the Skills card.** In `valley/grove_tree.gd`, the three nodes of a kind with `not sim.grows(tier)` are drawn faded (the plate at paper, the picture at 45% alpha, no rim), the foot card's effect line is replaced by a locale line saying it no longer grows here (`GROVE_GONE`, en / pt / es, measured), and its price bar shows no price.
- [ ] **Step 5:** Verify with `tests/_shot_grove.gd` extended by beats for: the Skills card on a grove with `seeds 4` (the Sapling's and the Birch's nodes faded), a beaver alone at a tree with nobody holding, a keen number, a lucky pile, a crate ashore, a crate opened. Both drivers as in Task 4; draw calls in the report.
- [ ] **Step 6:** Commit `feat(grove): own beavers, keen chops, lucky wood and crates on the land`.

### Task 6: The record

**Files:** `docs/agents/valley.md`, `docs/agents/haptics.md`, `docs/agents/analytics.md`, `docs/agents/checkup.md` if it counts the Grove's tutorial pages, the spec's section 9, `tests/_shot_grove.gd` header.

- [ ] **Step 1:** Run the final measurements, one at a time: the probe; the suite; the four pace runs of Task 3 Step 9; the shot harness on both drivers.
- [ ] **Step 2:** `docs/agents/valley.md`: a section for the tree, the jetty and the skills in the file's own voice (what the user said, quoted; the rules; where each thing lives; what was measured; **Not done**: a phone, sounds heard, the user's verdict on the pace and on each default the spec lists). Change the lines the build made untrue ("nothing chops by itself", "six tiles", "Not built: automation, chests, critical hits ... a skill tree", the tutorial of three pages, the shop's layout). Do not rewrite history: date what changed.
- [ ] **Step 3:** The spec's section 9: the pace tables and the draw calls, with the commands that made them. `haptics.md` row 40 and `analytics.md`: the new cues and `grove_upgrade`'s `tile` values.
- [ ] **Step 4:** Commit `docs(grove): the tree, the jetty and the skills -- notes and measurements`.
