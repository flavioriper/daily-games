# Hedgerow, the second Arcade game

2026-09-27. Built in one sitting while the user was away, from their brief:
"add a new arcade game based on element td (check on web for reference,
rules), include sfx. have to leave now, do everything".

## 1. The reference

The genre is the element tower defence of the Warcraft III custom map and
its sequel, named here once to forbid it: *Element TD*. **It is called
Hedgerow and nothing else**, in code, in a comment or on screen. What was
taken from it, checked against the sequel's Steam beginner's guide and its
tower lists:

- **Mazing**: the pests walk the shortest way from a gap to a goal round
  whatever stands on the field, so the towers are also the walls. A tower
  that would close the last way through is refused. Flyers ignore the maze.
- **Two plain towers always available** (arrow and cannon there, Thorn and
  Acorn here), with no element.
- **Six elements in a ring**, each doing double to the next and half to the
  one before: Light > Darkness > Water > Fire > Nature > Earth > Light. Here
  Sun > Shade > Rain > Ember > Leaf > Stone > Sun.
- **Element picks** at set waves; a picked element unlocks its tower.
- **Dual towers**: any single element tower fuses with a second picked
  element into one of fifteen duals, each with its own trick (the sequel's
  Lightning chains, Ice stuns, Poison ticks, Well hastes, Blacksmith buffs,
  Vapor hits a line, Disease executes...).
- The singles' tricks follow the sequel's: Light gains on the same target,
  Darkness spills a kill's leftover, Water splashes a second target, Fire
  heats up while firing, Nature hits fresh creeps harder, Earth pulses.
- **Interest** on banked gold at each wave's end, a **bounty** a kill,
  **lives** lost per leak (a boss costs five), wave types (normal, fast,
  mass, armoured, healing, air, boss).

Left out for a phone session: triples, quads and the periodic tower,
essence, element levels, the eleven picks (four here, so which fusions you
can reach is a real choice), overlapping waves and multiplayer.

## 2. Rules as built

- The lawn is **9 by 12 cells**. Pests come in at the gap in the top hedge
  (column 4) and make for the vegetable patch under the last row. The gap
  and the patch cells can't be built on, nor a cell a pest stands on or is
  stepping into.
- **20 lives, 110 gold, 40 waves.** Waves come on a 16 s break (40 s before
  the first); **Send** calls one early and the break's seconds come back as
  half their number in gold. A cleared wave pays `10 + 2n` and 3% interest
  on the bank, capped at 60. Wave 40 is three bosses.
- **Picks at waves 1, 7, 14 and 21**: four of the six. The game waits on the
  pick card. The ring is on every orb: "Strong against Shade".
- The waves repeat a ten-long pattern: aphids, ants (quick), gnats (a
  swarm, half health), beetles (a shell that halves plain towers), aphids,
  slugs (heal 3% a second), wasps (fly a weaving line straight down the
  gap's column over the maze), ants, gnats, a stag beetle boss. Waves 1-2
  carry no element; from 3 on they cycle Sun, Shade, Rain, Ember, Leaf,
  Stone.
- **Plain towers do 60% to an elemental pest** (`PLAIN`). Without it a bot
  planting only Thorns along the straight walk reached wave 37, and the
  elements were not worth their price. A dual's hit takes the mean of its
  two elements' multipliers.
- Singles build for 100 and upgrade twice (220, 520); duals fuse for 260
  and upgrade once (700). Selling returns 75% of what went in.

Every tower's numbers and trick are one table, `TOWERS` in the sim.

## 3. Build

- `arcade/hedgerow_sim.gd`: the whole game as pure data in cell units, at a
  fixed 1/60 s. The maze is a breadth-first distance field from the patch,
  rebuilt when a tower comes or goes; a pest steps to a neighbour one closer
  and keeps its heading on a tie, so its walk runs straight rather than in
  stairs. Hits are instant (the screen draws the shot); the screen drains
  `events`.
- `arcade/hedgerow_art.gd`: the pests (aphid, ant, gnat, beetle, slug,
  wasp, stag beetle) in their element's colour, built at the origin facing
  up and turned by transform; the towers on stone slabs (a bramble, an
  acorn sling, a clay pot with its element's orb; a dual's orb split in its
  two colours) with a pip a level; the six glyphs. Shared with the tab's
  banner.
- `arcade/hedgerow_screen.gd`: top bar, a paper row (gold, lives, wave),
  the lawn in a wooden frame, and a paper panel under it. The lawn is one
  mesh built on resize; every tower and the pests' route are one mesh
  rebuilt when a tower changes; each pest is one `draw_mesh`; shots, pulses,
  bars and marks are two live meshes a frame.
- **The panel is the whole interface.** Nothing chosen: the next wave (its
  pest on a disc in its element's colour), Send with the break's clock and
  the gold it would pay, and x1/x2. A bare cell: a chip a tower you can
  plant, with its price, or why not (the gap, a pest, the last way
  through). A tower: its name, level and trick, Upgrade, a chip per dual it
  can fuse into, and Sell. A chip it cannot afford is dimmed but pressable,
  so the gold plate can bump.

## 4. Sounds

`tools/gen_sfx.py hedgerow`, 28 cues in the `ARCADE` style, one take each,
awaiting the user's listen. Shots are one cue per element (and `zap`,
`freeze` for Lightning and Frost), throttled to one every 70 ms however
many towers fire. ElevenLabs refuses a duration under 0.5 s; the first run
stopped on that and the cues were raised to 0.5.

## 5. Tuning, by bot

`tests/_probe_hedgerow.gd -- seed skill picks` (skill 0: thorns along the
straight walk, no maze; 1: a three-wall serpentine with singles; 2: the
same with fusions). After the tuning above, on this Mac:

| bot | result |
| --- | --- |
| 0, thorns, no maze | out at wave 21 |
| 1, singles, `lthe` | out at wave 36 |
| 1, singles, `rtsh` | out at wave 37 |
| 2, duals, `sreh` | out at wave 40 with 6 lives left at 39 |
| 2, duals, `hlrt` | out at wave 40 |

The duals bot never upgrades a tower past level 1 and uses 24 cells of wall;
a player who upgrades and builds a longer maze should hold wave 40. That is
a guess about a thumb, not a measurement. A 40-wave game is about 24
minutes at x1.

## 6. Measured

`tests/_shot_hedgerow.gd` at `--resolution 810x1440`: **118** draw calls on
the Arcade tab with both cards, **87** on the pick card, **75** on a build
panel over a 24-tower maze, 59-64 during a wave, 81 on the end card. The
harness also presses the panel's chips and taps the field, and prints a
`check` line a move (build, upgrade, fuse, sell, the gap refused, a tap
landing on its cell). The sim runs a whole 40-wave game in about 3-13 s
headless (13 s with fusions' chains and splashes).

## 7. The tab

Two cards now; the "more arcade soon" card went, as Versus's did, to make
room. A card's furthest line is in its own words (`ARC_BEST_STAGE`,
`ARC_BEST_WAVE`). Hedgerow's banner is a strip of lawn with a walk winding
between towers and pests on it in their colours, over the meadow vista.

## 8. Open

- Difficulty wants a thumb on a phone: the final wave, the 16 s break and
  whether four picks is enough.
- The pt/es strings are machine-fluent.
- The pick card covers the lawn; a player may want to see the maze while
  choosing.
