# Trestle, the bridge-building board

Date: 2026-09-28. The twenty-ninth card. Built unattended at the user's word
("next puzzle daily is a build bridge game like [a search page of bridge
builders], wire sfx sound as well. I have to leave so do everything. Check
on web for anything needed like rules or references"). No concept tab: the
user left and asked for the build.

## 1. The reference, and the name

The genre is the physics bridge builder: Chronic Logic's *Bridge Builder*
(2000), Dry Cactus' *Poly Bridge* and BoomBit's *Build a Bridge!* are the
ones on the user's search page. The rules they share, as a web search
summarised them (Poly Bridge's Steam manual, its wiki, GameFAQs):

- a gap, fixed anchor points on its banks, and a budget;
- materials: a road the vehicles drive on, structural beams (wood, then
  steel), cables that pull but never push;
- members join at joints, the bridge takes its own weight and then the
  vehicles', and a member pushed or pulled past its limit snaps;
- a stress view, green to red; triangles are strong, squares fold.

It is called **Trestle** and nothing else, in code, in a comment or on
screen. "Bridges" is already the Hashiwokakero board, and the three
references are trade names.

## 2. The game

A river gap between two banks, the right one level with the left or up to
two steps higher or lower. Red **pins** on the banks: always the two road
ends, plus pins on the cliff faces, and on some days a **rock** in the river
with a pin on top, or **posts** on the banks for rope. Build dots mark the
lattice over the gap.

- **Lay a member**: drag from a pin or a bolt to a lattice point in reach
  (at most a knight's step, (2, 1)); or tap a bolt and then tap points to
  lay a chain. **Tap a member** to take it down.
- **Materials** (chips over the scene): **road** (the cart drives on it,
  heavy, weak), **wood** (light, strong), **rope** from Medium (lightest,
  strongest in tension, pushes nothing). Road climbs at most one in one.
- **Budget**: every member costs by material and length; a member that
  would pass the budget is refused. The bar carries a star at the cost of
  the day's proof.
- **Go** (the Check button, relabelled, with a play glyph): the test runs.
  The bridge takes its weight over 0.6 s, the cart drives on, members tint
  by load. **The cart on the far bank is the solve.** A cart in the river
  sends the board back to building after 2 s with the snapped members
  marked red and a toast saying how many. **Build** (the same button) stops
  a test.
- **Hint** (3, none on Insane): one member of the day's proof, laid in gold;
  it stays through Reset. When the budget will not stretch, the player's own
  members furthest from it come down to pay for it.
- **Stars**: three for a bridge as cheap as the proof, two inside half the
  slack over it, one for any crossing. On the win card and the share line.

## 3. The physics (`puzzles/trestle_sim.gd`, pure data)

XPBD with small steps: `DT` 1/120, 10 substeps, one pass each. Joints are
point masses (half of each member's mass, plus a bolt's), pins are fixed;
members are distance constraints with compliance `rest / EA`, so the
multiplier a substep needs *is* the member's force. Tension positive. The
force is smoothed over 0.05 s and judged against the material's limit: past
it the member **snaps** into two stubs dangling from its ends (carrying
nothing, never breaking), and the design member is recorded as broken.

**The cart is a moving mass, not a wheeled body.** On a road member it lends
its mass to the member's two joints in proportion to where it stands, so its
weight goes into the bridge exactly as a load does and it is drawn where the
bent deck puts it. At a member's end it takes the road that carries straight
on; with none, or when its member snaps, it flies and falls until it lands
on a road, a bank or the river. It is deterministic and cannot wedge, which
a wheeled body on a jointed deck would.

| | cost / unit | mass / unit | EA | tension | compression |
|------|-----|------|------|----|----|
| road | 200 | 0.15 | 2400 | 30 | 30 |
| wood | 150 | 0.08 | 3200 | 44 | 36 |
| rope | 120 | 0.03 | 2000 | 60 | -- |

Gravity 10; the cart is 1.2 / 1.6 / 2.0 / 2.4 by band. **A bare road deck
cannot hold even itself up** over the narrowest gap: the first lesson.

## 4. The levels are mined (`tools/mine_trestle.gd`)

Generation needs a physics run per candidate (0.1-0.3 s each in GDScript),
so the phone never grows a level. The miner deals a shape per band, builds
full candidate trusses (a Pratt truss one or two rows under the road, one
over it, both; diagonals both ways, or falling, or rising toward the middle;
every pin linked to every candidate joint in reach), keeps those whose run
gets the cart over under 0.85 of every limit, and **prunes** the two
cheapest: members are tried out most expensive first, and wood is tried as
rope, keeping every change that still proves. The cheapest survivor is the
level's **proof** (and its hints); the budget is its cost times the band's
slack.

| band | gap | cart | slack | extras |
|------|-----|------|-------|--------|
| Easy | 4-5 | 1.2 | 1.6 | road and wood only |
| Medium | 5-7 | 1.6 | 1.4 | rope, ramps of one, posts |
| Hard | 7-9 | 2.0 | 1.25 | rocks, posts |
| Insane | 8-10 | 2.4 | 1.12 | ramps of two, a rock always at 10 |

`tools/merge_trestle.py` gathers the bands into `content/trestle.json`
(dropping repeats); `tests/_probe_trestle_bank.gd` **re-proves every level
against the sim as it stands** and, with `write`, drops any that no longer
hold. Run it after any change to the physics: a change to the cart's start
line alone shifts every run.

## 5. The screen

One board card (`"tray": "none"`), the actions row Reset and Go, Undo and
Hint in the top bar -- Pixel Garden's shape. In the card: a paper strip with
the three chips and the budget; under it the scene, one world unit `_u`
fitted to the gap plus 1.8 either side and the river.

Drawn as `still` (sky, hills, clouds, river, banks, rock, posts, build dots;
rebuilt on relayout), `frame` (the bridge; rebuilt when the design changes
and every frame of a test), `halo` (the pulsing marks, faded by the draw's
modulate), the cart (a body mesh and a wheel mesh moved by transform, with
one to four fruit passengers from `ui/faces/fruit.gd` who worry at a creak,
gasp at a fall and cheer on the far bank), and the front layer (the water's
face over anything that fell in, the ghost member under the finger, the
strip, the toast). `ui/faces/trestle_parts.gd` is shared with the menu card.

## 6. Sound

`tools/gen_sfx.py trestle`: `enter`, `select`, `place_road`, `place_wood`,
`place_rope`, `remove`, `refused`, `undo`, `hint`, `reset`, `go` (a toy
whistle), `roll` (a loop of wheels on planks whose level follows the cart,
snooker's `_roll_sound`), `creak` (a member past 0.8 of its limit, once
each), `snap`, `snap_rope`, `whoa` (the cart leaving the road), `bump`,
`splash`, `fail`, `cross` (two toy horn honks) and `solved`. Building is the
house marimba, the test foley and cartoon. One take a cue, awaiting the
user's listen.

## 7. What was not done, on purpose

- No steel and no hydraulics: three materials already make the budget a
  real trade (road is the only thing the cart drives on, rope is cheap but
  only pulls), and a phone screen has room for three chips.
- No wheeled vehicle physics (section 3), no multiple vehicles, no boats
  under the bridge.
- No free placement: members join lattice points, so a design is exact and
  a hint is one member.
- A reopened solved daily shows the day's proof, not the player's own
  bridge (the design is not kept with the completion).

## 8. Measured

At `--resolution 810x1440` (`tests/_shot_trestle.gd`): 79-81 draw calls
building and testing, ~146 on the win's confetti, ANGLE agreeing on every
count; idle at the 120 Hz vsync ceiling in every state, including mid-test.
Mining: 5-65 s a level; 76 levels (17 / 19 / 20 / 20), worst proof stress
0.86 of a limit. `tests/_win.gd -- trestle` lays the proof by touch, takes a
member off and back with Undo, and presses Go.
