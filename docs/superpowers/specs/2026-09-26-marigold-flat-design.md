# Marigold, flat: the twenty-sixth board

A pond garden at dusk under a wooden arbor. **The family's sun sits at the
top with a leaf spout; drag to aim, let go, and it shoots a seed** down
through a field of flower buds. Every bud the seed touches blooms, and the
blooms are picked when the seed has gone. **Bloom every orange marigold** to
finish the garden.

The reference is the one the user asked for on 2026-09-26: Peggle (PopCap),
with the Xbox Peggle 2 manual for the rules, and a screenshot of a level
(blue and orange pegs in staggered rows over a mountain lake, a unicorn's
launcher at the top, a ball tube on the left, a fever meter on the right, a
bucket at the foot). That name is written here once, in order to forbid it:
**it is called Marigold and nothing else**, in code, in a comment, in a
commit or on screen -- the chain Code Break, Hidden Word, Word Trail,
Bridges, Quilt, Paper Planes, Pinwheel, Caterpillar, Sunbeam, Knight,
Hedgehogs.

Built in one sitting while the user was away, from the rules and the
screenshot, without a concept tab in `docs/brainstorm/concepts.html` first --
Super Slider's precedent, recorded so it is not read as an oversight.

---

## 1. What is built

| File | What it is |
| --- | --- |
| `puzzles/marigold_state.gd` | The rules and the physics: the garden's generator, a shot stepped at a fixed `DT`, the pot, the full bloom, the hint's search. Scene-free. |
| `puzzles/marigold2d.gd` | The board: the meshes, the aim, the shot loop, the picking, the HUD band. |
| `ui/faces/marigold_parts.gd` | The drawing -- buds, blooms, seed, pot, sun, spout -- shared with the menu card. |
| `core/palette.gd` | `MG_*`. |
| `ui/registry.gd`, `locale/boards.csv`, `ui/menu/vistas.gd`, `ui/menu/card_art.gd` | The card: entry, strings (en/pt-BR/es), banner vista (dusk), picture. |
| `tools/gen_sfx.py`, `assets/sfx/marigold/` | Sixteen cues, one take each. |
| `tests/_shot_anim.gd`, `tests/_probe_marigold.gd` | The strip's hook (`marigold`, `marigold fever`) and the headless probe. |

## 2. The rules, as the reference has them

| The reference | Marigold |
| --- | --- |
| Blue peg, 10 | **Bluebell** bud, 10 |
| Orange peg, 100, clear them all | **Marigold** bud, 100, bloom them all |
| Green peg, the master's power | **Clover**: the seed splits in two (the multiball power) |
| Purple peg, 500, moves every shot | **Violet**, 500, moves to another bluebell after every shot |
| 10 balls | 10 **seeds** (8 on Insane) |
| Free-ball bucket sliding along the foot | A terracotta **pot** sliding along the bank: a seed in it comes back |
| Multiplier x1, x2, x3, x5, x10 at 10, 15, 19, 22 of 25 oranges | The same steps as shares of the marigolds (0.4, 0.6, 0.76, 0.88) |
| A free ball at 25,000 / 75,000 / 125,000 in one shot | The same |
| A stuck ball clears the pegs round it | A seed that has not gone lower for 2.2 s clears the blooms within 8 units; past 30 s, all of them |
| Extreme Fever on the last orange: slow motion, five fever buckets (10k, 50k, 100k, 50k, 10k), Ode to Joy | **Full bloom**: slow motion (x0.25 for 1.5 s), a sunburst out of the last marigold, a rainbow over the pond, the banner, and five pots with the same worths; every seed left is worth 10,000 |
| Out of balls: level failed | Out of seeds: **the same garden grows back** and the day goes on (a try, never a loss; the tries are on the share line) |
| The launcher's guide shows the path to the first peg; Bjorn's Super Guide shows further | The dotted aim runs to the first bud it will touch (at most 30 units); the **hint** is the Super Guide |

Scoring is the reference's: each bloom is its worth times the multiplier at
that moment, summed over the shot. Style shots, the coin flip and the
masters' other powers are not in.

**No Undo** (a seed cannot be taken back), no Check, no tray, no actions
row: Hint and Reset ride in the top bar -- Pinwheel's shape.

## 3. The garden

`W` 100 by `H` 140 units, y down; buds between y 25 and 124. The day's rng
splits that height into two or three bands and fills each with one figure --
staggered rows (the reference's own), smiles (concentric arcs), rings, sine
waves, chevrons, pillars, a diamond lattice -- in the left half, mirrored, so
the garden is symmetric like the reference's levels. Buds nearer than 6
units are dropped, and mirrored pairs are thinned to the band's count. Then
the marigolds and clovers are dealt at random and the violet placed.

| Band | Buds | Marigolds | Seeds | Pot | Clovers |
| --- | --- | --- | --- | --- | --- |
| Easy | ~54 | 12 | 10 | 17 | 2 |
| Medium | ~72 | 18 | 10 | 15 | 2 |
| Hard | ~90 | 25 | 10 | 13 | 2 |
| Insane | ~100 | 25 | 8 | 11 | 1 |

## 4. The physics

Pure data in `marigold_state.gd`, stepped at `DT` 1/240 s: gravity 92 u/s²,
launch 72 u/s from the spout's mouth (`MUZZLE` 4.9 out from the sun's
middle), a bud gives back 0.68 of the speed along the hit and the walls 0.8,
speed capped at 150. Buds sit in a 6-unit grid so a step checks nine cells. A
seed balanced on a bud's crown is nudged off. The pot's two rims are round
lips; a seed crossing its mouth between them is caught; its sides turn a seed
away. The aim is kept 0.1 rad off level either side.

The board runs the same `step()` off its frame clock (at most 60 steps a
frame), so **the aim's guide and the hint are exact**: both play the shot on
a `clone()`.

**The hint** plays 65 angles across the fan for up to 8 s each and takes the
best by marigolds, then points, then a seed in the pot. About 330 ms on this
Mac, so it runs on a `WorkerThreadPool` task while the sun spins; the aim
turns to it and shows the long guide (through three blooms). Three a day.
Played on every shot, it clears every band's garden in one try on the probe's
days (4-9 shots).

## 5. The drawing

Meshes, most cached (see the file's header): the card and the dusk garden
(sky, moon and stars, two ranges with snow, the reference's castle on the far
shore, the pond with its glints and lily pads, reeds, the bank, the arbor
with a vine and marigolds up its posts), the buds in six strips down the
field so a bloom rebuilds one strip, the blooms (rebuilt only while one opens
or is picked), the guide, the wake. The pot, the seed and the sun's rays,
body and spout are built once and moved by transform. The HUD band carries
the seeds as beads, the score, the multiplier's pill, and a pip a marigold,
gapped where the multiplier steps.

A bud's kind is told by its mark as well as its colour: a marigold carries
its folded creases and a green sepal, a clover three lobes, a violet five.

## 6. The motion

A bud blooms over `BLOOM_TIME` 0.24 (`Motion.back_out`), a note of a major
scale higher each bloom of the shot (up an octave and a fifth, then held).
When the last seed is gone the blooms are picked in the order they opened,
`PICK_STEP` 0.07 apart (the shot within `PICK_ALL` 1.3), each growing and
fading over `PICK_TIME` 0.2 with a petal puff and the scale again, then the
shot's points rise over the pot. The sun's rays turn slowly, faster in the
full bloom and while the hint looks; it looks down the aim, blinks, beams on
a marigold and worries on the last seed. The pot's mouth glows as a seed
drops in.

## 7. Figures

`tests/_shot_anim.gd -- marigold` at `--resolution 810x1440`, 2026-09-26:
**74** draw calls bare (`empty`), **76-78** with a seed out, **87** in the full
bloom (`fever`: the five pots' worths are five labels), and 78 played on ANGLE
(`--rendering-driver opengl3_angle`). Idle **3.44 ms** bare --
the pot always slides, so the garden redraws every frame, but rebuilds
nothing -- and 5.3 ms with seeds out and blooms opening. The menu's last page,
Super Slider's card and this one, reads 118. The suite: 122,593 passed, 0
failed. `tests/_probe_marigold.gd` deals two days a band and plays each out
with the hint's aim; a throwaway probe drove hint, shot, running out and the
garden growing back through the real board.

Owed: a listen to the sixteen sounds (one take each; `hit` is pitched up the
scale, so it has to be a single clean note), the hint's
wait on a phone, and the user's call on the name.

---

## Amendment: the polish of 2026-09-26

Bounded, built directly. **The look**: bluebells and marigolds sit in a
collar of two leaves, a bluebell carries bell seams and a marigold a warm
halo (it is the goal); every bud's reflection lies under it; the blooms'
petals have lit tips and a marigold stamens. The seed is a striped kernel
(`Parts.kernel`) pointing along its flight, turned by transform; its wake is
pollen. The pot has a painted band and a marigold on its belly. The pond
holds the near range and the castle upside down, a moon's road and mist
along the far shore; a water lily opens on one pad; clover and daisies line
the bank. The arch is a thicker grained beam with a swagged garland (a
marigold in each swag) and two lanterns; the sun has a soft light round it.
The band's seeds lie in a wooden trough with dents for the ones shot, the
pips sit in a wooden groove and fill with tiny marigolds, the multiplier is
a wooden tag that turns orange past x1.

**The motion**, all off under reduce motion: every bloom rings the water
(`RIPPLE_TIME`); a bloomed marigold flies up to its pip (`FLY_TIME`), which
fills only when it lands, with a sparkle; a picked bloom rises and turns as
it fades (`PICK_RISE`); the sun bobs, and a shot kicks it back up its aim
and squashes it (`RECOIL_TIME`); the pot wobbles when it turns at an end
(`WOBBLE_TIME`) and squashes about its foot on a catch (`CATCH_TIME`); the
tag pops with a ring when the multiplier steps (`TAG_TIME`); the score rolls
up; fireflies, twinkling stars, glints drifting across the pond and the
lanterns' flicker breathe under the buds; a marigold glints now and then
(`GLINT_EVERY`); the full bloom rains petals (`PETAL_TIME`). Two small
live meshes carry all of it, one under the buds and one over everything.

**Figures** (`tests/_shot_anim.gd -- marigold`, 810x1440): **78** draw
calls bare (74 before) at 4.40 / 4.33 ms idle over two readings (3.44
before), **83** with a seed out (76-78 before) at 7.93 / 7.97 ms (5.81 read
the same session before the polish), **91** in the full bloom (87 before),
84 on ANGLE rendering the same, and the menu's last page still 118. The
suite: 122,593 passed, 0 failed; the probe solves every band.
