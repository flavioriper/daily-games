# Blender contract

The whole agreement between a model made in Blender and the game. If a model
follows these rules, exporting it to `assets/models/<slot>.glb` is the entire
integration: the game finds it by name, converts its materials to the toon
shader, adds the outline, and places it. Nothing else to configure.

## Slots

| slot | footprint (X by Y in Blender) | max height (Z) | notes |
|---|---|---|---|
| `tile` | 1.0 x 1.0, reaches 0.87 x 0.87 | 0.9 | an **assembly** of four layers: a cube of side 0.84 standing on the platform, base at Z = 0, carrying its symbols the way a die carries its pips. `Tile_Body` (material `Stone`) and `Moon_Face` (`Slate_flat`, a slab on each of the two moon walls, inside the body's bevel and 0.0015 proud) are the two the game tints, by whether the cell is locked. `Sun` and `Moon` are inlaid in opposite pairs of walls, 0.05 thick with 0.015 standing proud. The top and bottom faces are bare: that is the empty state. No layer's colour depends on which face is up, so a roll changes no colour |
| `rim_edge` | exactly 1.0 x 0.5 | 0.12 | moss strip on one cell of the platform lip; runs along X, outward side (toward the water) at **-Y** in Blender, which is +Z in Godot; materials Moss_flat plus Grass_sway_flat, Petal_sway_flat, Pollen_sway_flat |
| `rim_corner` | exactly 0.5 x 0.5 | 0.12 | moss square on a platform corner; outward corner at **+X -Y** in Blender, +X +Z in Godot; materials Moss_flat plus Grass_sway_flat, Petal_sway_flat, Pollen_sway_flat |
| `platform` | exactly 1.0 x 1.0 (enforced) | 0.6, a guide |  a unit stone slab; the board stretches it to (cols + 1, rows + 1), so keep the material a plain colour |
| `water` | any, about 60 x 60 | flat | the water plane far below the platform |
| `tree` | up to 1.4 x 1.4 | 2.0 | island scenery, an **assembly**: `Tree_Trunk` (`Bark`), `Tree_Canopy` (`Leaf`, three overlapping blobs in one mesh, one layer) and `Tree_Bloom` (`Bloom_flat`). Still, not `_sway`: the wind shader reaches full strength 0.10 above the base, so a whole canopy would shimmy rather than bend, and `_sway` would cost it its outline |
| `socket` | 0.94 x 0.94 | 0.15 | Code Break's slab, an **assembly**: `Socket_Body` (`Stone`, tinted by whether its row is active) and `Socket_Well` (`Well_flat`, the floor of the well rather than a disc laid proud on the slab: `Socket_Body` carries a 0.03 recess cut into its crown by a countersunk Boolean, and the disc sits in it at Z 0.09, 0.0015 proud of the floor, so a peg seats below the slab's top). The feedback slab is a socket with its well hidden |
| `peg` | 0.6 across | 0.5 | a colour peg, an **assembly**: `Peg_Body` (`Shell`, tinted per colour), `Peg_Mark_1` … `Peg_Mark_7` (`Mark_flat`, one to seven pips on the crown in die layouts, each disc 0.012 thick, rotated onto the crown's normal and centred on the surface so 0.006 stands proud, the tile's inlay treatment) and `Peg_Shine` (`Shine_flat`, a small cream patch on the dome's upper-left, half buried in it so it reads as a highlight rather than a sticker, and no outline); the game shows the one mark matching the colour |
| `pip` | 0.2 across | 0.2 | a feedback pip, an **assembly**: `Pip_Well` (`Well_flat`) and `Pip_Ball` (`Pip`, tinted slate or cream, hidden until scored) |
| `lid` | 0.94 x 0.94 | 0.3 | the stone lid over one code slot: `Lid_Body` (`Lid`) and `Lid_Knob` (`Knob`) |
| `pipe_pad` | 1.0 x 1.0 | 0.15 | Pipes's bevelled slab: `Pad_Body` (`Stone`), the surface a pipe piece rests on |
| `pipe_cap` | 1.0 x 1.0 | 0.38 | a pipe with one opening, modelled opening `UP`; an **assembly** of `Pipe_Shell` (`Steel`, the hub and two shell segments per open arm either side of a sight hole), `Pipe_Collar` (`Collar`, a ring at each side of every hole plus one at each open mouth) and `Pipe_Water` (`Flow_flat`, the tube running every open arm's full length plus a hub ball, dry grey until `Models._dress` swaps in a fresh `Toon.pipe_flow()` material) |
| `pipe_straight` | 1.0 x 1.0 | 0.38 | a pipe with two opposite openings, modelled `UP \| DOWN`; same three layers as `pipe_cap` |
| `pipe_elbow` | 1.0 x 1.0 | 0.38 | a pipe with two adjacent openings, modelled `UP \| RIGHT`; same three layers as `pipe_cap` |
| `pipe_tee` | 1.0 x 1.0 | 0.38 | a pipe with three openings, modelled `UP \| RIGHT \| DOWN`; same three layers as `pipe_cap` |
| `pipe_cross` | 1.0 x 1.0 | 0.38 | a pipe with all four openings, modelled `UP \| RIGHT \| DOWN \| LEFT`; same three layers as `pipe_cap` |
| `valve` | 0.65 x 0.65 | 0.12 | the bolted ring the source and the drain wear: `Valve_Ring` (`Metal`, a torus around the cell's hub) and `Valve_Bolts` (`Bolt_flat`, four bolts resting proud on the pad on the diagonals outside the ring, not inlaid -- the valve has no slab of its own to sink into) |
| `block` | **exactly 1.0 x 1.0** | 1.0, and 1.015 with the cap | the unit Pipes' island is built out of: `Block_Earth` (`Earth`, a full 1 x 1 x 1 cube) and `Block_Grass` (`Grass`, the crown the board tints, a 0.09 slab inlaid in that crown 0.94 across with 0.015 standing proud). Exact, not budgeted: the board tiles it edge to edge in three dimensions, and a block 0.98 across would leave a seam of sky in every wall -- which is also why the cube is not shortened to make room for the cap. The cap is inset so a lip of earth rings the turf and the outline draws a line at every cell edge; without it a field of crowns reads as one green sheet with no cells in it. Only a crown shows its cap at all -- on any other block the proud 0.015 is inside the block above, where nothing can see it |
| `pump` | 1.0 x 1.0 | 1.0 (2 x `ARM_LEN`) | the piece that lifts water a level, the straight pipe stood on end: `Pump_Shell` (`Steel`), `Pump_Collar` (`Collar`) and `Pump_Water` (`Flow_flat`) exactly as `pipe_straight` carries them, opening `UP \| DOWN` along Z in Blender, plus `Pump_Housing` (`Brass`, a drum round the hub) and `Pump_Ring` (`Lit`, a ring round the housing, modelled dark iron because the board lights it while the run is climbing -- a ring already amber would have nothing left to say). **The one piece whose hub is not at `TUBE_Y`**: an arm reaching `ARM_LEN` down from a hub 0.175 up would end at -0.323, and the base-at-zero rule forbids it, so the hub sits a whole arm up at `Placeholders.PUMP_HUB` (0.498) and the down mouth lands exactly on the base. That is where the height comes from too -- two arms, not one -- and the board hangs this model at -`PUMP_HUB` under its pivot where every other piece is hung at -`TUBE_Y` |
| `source_tank` | 1.0 x 1.0 | 0.6 | where the water comes from, standing on a block's crown: `Tank_Body` (`Stone`, a low square cap), `Tank_Orb` (`Glass`, a lit orb sunk a third of the way into it, whose crown is what fixes the 0.6) and one arm's worth of pipe -- `Tank_Shell` (`Steel`), `Tank_Collar` (`Collar`) and `Tank_Water` (`Flow_flat`) -- so the mouth the player taps looks like a mouth and wets like one. The arm's hub is at `TUBE_Y` with every other piece's, and it points at **-Y** in Blender, which is Godot +Z; the board turns the whole piece onto whichever side the generator chose |
| `drain_pool` | 1.0 x 1.0 | 0.38 | where the water is going: `Pool_Rim` (`Stone`, the rim and the basin floor as two lobes of one mesh), `Pool_Water` (`Water_flat`, the surface, which `Models._dress` swaps for the stage's own water the way it does the `channel`'s, dark until the flood arrives) and the tank's same one arm as `Pool_Shell` (`Steel`), `Pool_Collar` (`Collar`) and `Pool_Water_Tube` (`Flow_flat`), pointing at Blender -Y again. The surface lies well under the rim's top, so the rim's shadow falling into it is what gives the basin depth. 0.38 rather than the 0.3 the spec's table guessed: the arm puts a mouth collar at `TUBE_Y` + `COLLAR_R` = 0.35, the same reason every pipe shape gets 0.38 |
| `scale_stand` | 0.7 x 0.7 | 1.1 | Balance's scale post, an **assembly**: `Stand_Body` (`Stone`, the foot and the column as two lobes of one mesh) and `Stand_Cap` (`Cap`, a collar ringing the pivot just under it, which the board turns green the moment that scale sits level -- keep it wider than `scale_beam`'s hub or the green never shows) |
| `scale_beam` | 3.2 x 0.3 | 0.3 | the balance arm, an **assembly**: `Beam_Arm` (`Wood`) and `Beam_Hub` (`Metal`). Modelled **base at Z = 0** like every other slot, not pivot-at-origin: the board hangs it at -0.13 (the hub radius) under the node that turns, which puts the hub's centre on the fulcrum. Wider than a cell by design -- the arm reaches a pan each way |
| `scale_pan` | 1.3 x 1.3 | 0.4 | a hanging pan, an **assembly**: `Pan_Dish` (`Pan`) and `Pan_Cords` (`Cord_flat`, three cords meeting at the hang point; `_flat` because a 0.03 cord is thinner than the outline shell would be). Also base at Z = 0: the board hangs it at -0.34 (`PAN_DROP`) so the cords' meeting point lands on the beam's end |
| `plinth` | 1.0 x 2.0 | 0.2 | where a weight is set, an **assembly**: `Plinth_Body` (`Stone`, two pads a cell apart as one layer), `Plinth_Well` (`Well_flat`, the disc the stack rises from, on the far pad) and `Plinth_Num_1` … `Plinth_Num_9` (`Num_flat`, carved numerals on the near pad; the board shows the one matching the weight). Two cells deep on purpose: the far pad's tap adds a disc and the near pad's takes one away, so each is a whole cell of tap target |
| `weight_disc` | 0.65 x 0.65 | 0.12 | one unit of weight: `Disc_Body` (`Disc`, tinted by its shape's colour). The board stacks these, so keep it thin and keep the gap between two visible -- the stack's height is the number the player reads |
| `token_ball`, `token_cube`, `token_prism`, `token_gem`, `token_cross` | 0.5 x 0.5 | 0.35 | the five shapes being weighed, in `core/shapes.gd`'s kind order (circle, square, triangle, diamond, plus). One layer each, `Token_Body` (`Token`, tinted). The silhouette is what a colour-blind player reads, so keep the five distinct from above **and** from the side -- Balance is the one board the camera looks at from 44 degrees, not 68 |
| `post` | 0.5 x 0.5 | 0.7 | Untangle's mooring post, an **assembly**: `Post_Body` (`Wood`, a tapered shaft with a cleat collar at the rope height and a foot on the stone, three lobes of one layer) and `Post_Cap` (`Cap`, tinted by the board -- held, crowded, hinted or plain -- so it must stay its own layer). Untangle's **ropes are not a slot**: the board rebuilds each one as a tube from its own Verlet simulation every frame it moves, so there is nothing to model or export |
| `plot_pad` | 1.0 x 1.0 | 0.15 | Shikaku's floor slab, one per cell: `Pad_Body` (`Stone`, tinted by whether a rectangle has claimed the cell). Shared with Light Up, whose court is paved with the same slab -- tinted cold where no lamp reaches it and warm where one does |
| `wall_edge` | **exactly 1.0** x 0.25 | 0.25 | one cell's length of dry-stone wall, running along X, resting across the seam between two floor slabs. The board **stretches it along X** to cover a whole run of seam (the way the platform slab is stretched), so the length must be exactly one cell or every run ends short, and the relief along its length should be gentle enough to survive being stretched. `Wall_Body` (`Wall`) |
| `wall_post` | 0.3 x 0.3 | 0.3 | the block that closes a wall corner, junction or dead end: `Post_Block` (`Wall`, the same material name as `wall_edge` so tinting one tints both) |
| `clue_stone` | 0.7 x 0.7 | 0.24 | the clue's marker stone, a low hexagonal drum: `Clue_Body` (`Stone`) and `Clue_Num_0` … `Clue_Num_9` (`Num_flat`, carved numerals on the crown, as the `plinth` carries them); the board shows the one matching the number it is standing for. Shared with Tents, whose row and column counts stand on the same stone and are often zero, which is why the zero is there at all. Six sides on purpose -- a piece is told apart by its silhouette first, and the square and the circle are taken |
| `turf_pad` | 1.0 x 1.0 | 0.12 | Tents' field cell: `Turf_Body` (`Turf`, tinted darker on the cell a tree stands on). Its shadow casting is off in `Models._dress` -- a flush slab's own shadow cannot show a pixel |
| `camp_tree` | 0.7 x 0.7 | 0.8 | the conifer a tent is pitched beside, an **assembly**: `Tree_Trunk` (`Bark`) and `Tree_Canopy` (`Leaf`, three tapered tiers as one layer, each overhanging the one above so the silhouette reads as three rings from the board's pitch rather than one green disc). Not the island's scenery `tree`, which is twice as tall and wider than a cell |
| `tent` | 0.7 x 0.7 | 0.45 | a pitched tent, an **assembly**: `Tent_Canvas` (`Canvas`, a ridge wedge the board tints -- duller when a hint pitched it, rose when it breaks a rule) and `Tent_Door` (`Door_flat`, a rounded slab centred on the gable facing the player, half proud and half buried, the tile's inlay treatment). The ridge runs along Blender Y, so the door is on **-Y**, which is Godot +Z |
| `cairn` | 0.5 x 0.5 | 0.3 | the pebbles marking a cell the player has ruled out: `Cairn_Body` (`Pebble`, three squashed pebbles as one layer). Laid in a triangle, **not** stacked -- at the board's 68-degree pitch a stack hides its own top pebble and the mark reads as one grey smudge |
| `wall_block` | 1.0 x 1.0, reaches 0.92 x 0.92 | 0.44 | Light Up's wall, the rough stone that stops the light: `Block_Body` (`Block`, tinted -- green once the block touches exactly its number of lanterns, rose once it touches too many) and `Block_Num_0` … `Block_Num_4` (`Num_flat`, carved numerals on the crown, as the `clue_stone` carries them, pale so they read on the dark block); the board shows the one matching its clue, or none on an unnumbered wall. Zero to four only -- a wall touches at most four cells. Deliberately shorter than a Binairo cube: it has to read as solid from the board's 68-degree pitch without hiding the cell behind it |
| `lantern` | 0.6 x 0.6 | 0.55 | what the player sets down to light a cell, an **assembly**: `Lantern_Iron` (`Iron`, a broad foot, which the board turns pale stone on a lamp a hint lit -- the given cue, because nothing the eye can find survives the toon ramp between two ambers) and `Lantern_Glass` (`Glass`, the globe sunk into it, which the board tints amber when lit and rose when the lantern can see another lantern). **Nothing stands on top of the globe.** Two passes were spent learning that: a wide cap and then a narrow finial both hid the glass at the board's 68-degree pitch and the lantern read as a dark blob with an amber rim. What a piece means has to be in its silhouette from above, and what this one means is the light, so the light gets the whole silhouette; the foot is wider than the globe instead and shows as a dark ring around it, which is what says the lamp stands on the stone. Light Up's court floor is `plot_pad` and the chip that rules a cell out is `cairn`, tinted slate -- neither needs a slot of its own |
| `horse` | 0.9 x 0.9 | 0.9 | Horse Pen's horse, an **assembly** cut down from a BlenderKit asset (`art/horse.blend`, the Draft Horse with its rig, teeth and hair particles stripped): `Horse_Body` (`Hide`, chestnut), `Horse_Mane` and `Horse_Tail` (`Mane`, flaxen, two objects of one layer), `Horse_Eye_L/R` (`Eye_flat`). Stands in **profile along X, facing +X**, so the board camera sees its silhouette. The mane is a crest as wide as the neck and the tail hangs: at the board's 72-degree pitch a modest mane and a nub of a tail contribute nothing, and the pale crest down the neck is what tells the eye this is the animal. The board scales it off its own mesh bounds to fill 0.9 of a cell, so a re-cut export needs no code change. The meadow it stands on is Tents' `turf_pad`, the water is the `channel` and a boulder is Code Break's `boulder` |
| `fence` | **exactly 1.0** x 0.3 | 0.5 | one cell of timber fence running along X, cut down from BlenderKit's Simple Wooden Fence: `Fence_Timber` (`Timber`). Exactly a cell long, posts included, so a run of fences meets post to post. **No board places it any more**: Horse Pen's polish pass replaced it with the `bale`, because two rails and two posts are mostly air and a run of them read as a dotted line on the meadow rather than as something a horse could not step over. Kept as a model in case a board wants a fence |
| `bale` | 0.8 x 0.8 | 0.5 | Horse Pen's hay bale, the barrier the player drops, an **assembly**: `Bale_Straw` (`Straw`, tinted older and darker on a bale a hint dropped) and `Bale_Straps` (`Straps`, two bands wrapping the bale over the top and down both sides as two lobes of one layer, standing 0.012 proud). It has a top, a front and a shadow, which is what the fence never had; the straps are what keep a run of bales from reading as one gold smear on the pale wheat. No orientation -- a run of bales is a row of the same piece |
| `channel` | **exactly 1.0 x 1.0** | 0.1 | one cell of Horse Pen's water channel, an **assembly**: `Channel_Water` (`Water_flat`, the surface 0.06 under the turf top, which `Models._dress` swaps for the stage's own water material so a splash rings it) and `Channel_Bank_N`, `_E`, `_S`, `_W` (`Bank`, one lip per side, all four the same material so tinting one tints them all, each its own mesh because the board hides them one at a time). The board shows a lip only where that neighbour is not water, so a stream reads as one cut with continuous banks and two streams that meet read as one; a side facing off the field shows none, and the ring's own turf face is the bank there. Exact footprint, not merely budgeted: the turf pad is 0.96 with a seam, but two channels side by side must meet, or a stream comes out as a row of puddles. Remember the axes -- `Bank_N` faces Godot -Z, which is Blender **+Y** |
| `stalk` | 0.3 x 0.3 | 0.32 | one tuft of Horse Pen's wheat: `Stalk_Blades` (`Stalk_sway_flat`, three tapered blades as one layer). The board scatters three per cell as one MultiMesh and scales them with the horse's reach, so the meadow that grows and sinks costs one draw call. `_sway` so it moves in the same wind as the rim's grass, `_flat` because the outline shell would swallow a blade and cannot follow the sway; keep the planted part under Z 0.03, where the wind shader leaves it alone |
| `flower` | 0.25 x 0.25 | 0.08 | the bloom that opens over a closed pen: `Flower_Bloom` (`Bloom_flat`, five petals round a low crown as one layer). Lies open on the grass with no stem -- from the board's 72-degree pitch a stem would only lift the bloom off the cell it belongs to. Scattered as one MultiMesh, built when the day is won |
| `apple` | 0.45 x 0.45 | 0.45 | the bonus lying on the meadow, from BlenderKit's Lowpoly Apples: `Apple_Fruit` (`Fruit`), `Apple_Stem` (`Stem_flat`) and `Apple_Leaf` (`Leaf_flat`); stem and leaf are both thinner than the outline shell, which would swallow them whole, so neither carries one |
| `snake_head` | 0.9 x 0.9 | 0.5 | Snake Apple's head, cut from a BlenderKit snake (`art/snake.blend`): `Snake_Skull` (`Scale`, the board's body tube is the same colour) and `Snake_Eye` (`Eye_flat`). Faces **+X** with the back of the head at the origin, so the tube the board builds along the snake's cells runs into it. The **body is not a slot**: the board rebuilds it as a tube from its cells every frame it moves, as Untangle does its ropes |
| `burrow` | 1.0 x 1.0 | 0.14 | where the snake goes home: `Burrow_Rim` (`Earth`, a ring of dug earth the board turns mossy once every apple is eaten) and `Burrow_Hole` (`Hole_flat`, the dark disc inside it) |
| `deck` | **exactly 1.0** x up to 1.0 | 0.6 | one strip of Code Break's dock, running along X: `Deck_Planks` (`Deck`), two planks side by side as one layer with a 0.06 gap between them and 0.03 at each edge, so the outline shells meet in the gaps and draw the seams. The board stretches it along X and lays one per unit of depth, edge to edge |
| `pier_post` | 0.4 x 0.4 | 2.1 | a round log with a rounded top, `Pier_Body` (`Bark`); stands in the river at the deck's far edge and reaches above the deck |
| `boulder` | 1.0 x 1.0 | 0.6 | a rounded stone beside the deck: `Rock_Body` (`Rock`) and `Rock_Moss` (`Moss_flat`), a cap on top. Placed at varied yaw and scale, one flattened as POM's seat |
| `bush` | 1.0 x 1.0 | 0.7 | `Bush_Leaves` (`Leaf`), four or five overlapping blobs as one layer, the lowest touching the ground |
| `daisy` | 0.3 x 0.3 | 0.25 | `Daisy_Petals` (`Petal_flat`), `Daisy_Centre` (`Centre_flat`), `Daisy_Stem` (`Stem_flat`); all flat, a petal being thinner than an outline shell |
| `tuft` | 0.3 x 0.3 | 0.25 | `Tuft_Blades` (`Grass_sway_flat`), three blades as one layer; the scenery scatters it as one MultiMesh, and the wind shader sways each instance |
| `signpost` | 1.4 x 0.4 | 1.8 | a post with an arm at the **left** end, `Sign_Post` (`Bark`); a plank hanging from the arm, `Sign_Board` (`Timber`); `Sign_Paper` (`Paper_flat`) on the plank's face, on Blender **-Y** (Godot +Z); `Sign_Words` (`Ink_flat`), the words as mesh on the paper. Wider than a cell on purpose; the footprint is still centred on the origin |
| `title_sign` | unbounded | unbounded | the menu's and HUD's title board, an **assembly**: `Sign_Plank` (`Plank`, Pal.PLAQUE, so core/toon.gd grains it at runtime), `Sign_Leaves` (`Leaf`, both sprigs in one mesh -- two lobes of one layer), `Sign_Screws` (`Screw_flat`, both heads). Chrome, not a piece: it is drawn in its own SubViewport at whatever size the Control layout gives it, so no cell footprint applies -- but it still keeps the base-at-Z=0 and centred-footprint rules. The title and motto are **not** modelled here: ui/hud/sign_view.gd extrudes them with TextMesh from the display face, so the words stay data |
| `mascot_<name>` | up to 1.4 x 1.4 | 1.4 | a character, e.g. `mascot_pom`; an **assembly**, see below |

Concept reference: `docs/art/concept-binairo-island.png`. The rim pieces are
the moss trim; `core/platform.gd` lays one `rim_edge` per cell along each side
and a `rim_corner` at each corner, so the lip is exactly one rim piece deep
(`Platform.LIP`, 0.5). Cliffs and the rest of the island come later.

Mascots are a family rather than a row: any slot starting with `mascot_` gets
the same generous budget, so a new character needs no change to the exporter.

The list lives in code as `SLOTS` in `core/models.gd`. New puzzles add rows.
The export script enforces each slot's footprint and height budget from this
table (an unlisted slot falls back to 1.0 x 1.0 x 0.6). Slots the board tiles
edge to edge are checked for an *exact* footprint, not a maximum: `platform`
(1 x 1, height free, because the board scales it by (cols + 1, rows + 1)),
`rim_edge` (1 x 0.5) and `rim_corner` (0.5 x 0.5), since a short rim piece
leaves a gap in the ring. `water` is unbounded.

Most slots are one cell, but the budget is the rule, not the cell: Balance's
`scale_beam`, `scale_pan` and `plinth` are larger than 1 x 1 on purpose,
because a balance arm and its pans span a band of the board rather than a
square of it. A piece bigger than a cell still obeys every other rule --
centred on the origin, base at Z = 0.

## Rules

1. **Units.** Metric, unit scale 1.0. One Blender unit is one board cell.
2. **Origin at the centre of the base.** The lowest vertex is at Z = 0 and
   the footprint is centred on X = Y = 0. Blender is Z-up; the glTF exporter
   converts to Godot's Y-up for you, so model with Z as up and do nothing else.
   For directional pieces remember the mapping: Blender (x, y, z) becomes
   Godot (x, z, -y), so Blender -Y is Godot +Z (toward the player). A shape
   whose openings cancel (an opposite pair, or all four) keeps its mass
   centred on its hub and satisfies this normally. One whose openings do
   not cancel (Pipes' `pipe_cap`, `pipe_elbow`, `pipe_tee` -- a dead end, an
   elbow, a T) cannot: its hub, the true pivot, must still sit at the
   origin, but its mass leans toward whichever sides are open, so its
   bounding box cannot be centred there. For exactly those slots the
   exporter checks that the footprint still fits the 1 x 1 cell around the
   origin instead of being centred within it; every other slot still needs
   the centred footprint.
3. **Apply transforms.** Rotation (0, 0, 0), scale (1, 1, 1) before export.
4. **Shade smooth with shared vertices, everywhere.** No split edges, no
   flat shading. For a hard-edged look, add a small Bevel modifier (width
   about 0.02, 2 segments) and stay smooth. Never use Auto Smooth / Smooth by
   Angle, Weighted Normal, Edge Split, or custom split normals — all of them
   split vertices at export. Reason: the outline draws a second copy of the
   mesh pushed out along the vertex normals; split vertices leave visible
   gaps at every corner. The exporter rejects meshes with custom split
   normals or an Edge Split / Weighted Normal / Smooth by Angle modifier,
   and a Bevel with **Harden Normals** on, which writes split normals the
   moment the modifier is applied. It measures the modifier result, not the
   cage, so a Solidify or Displace that grows the mesh past its budget is
   caught too.
5. **Materials are colours.** One Principled BSDF per material, Base Color set,
   nothing else needed. The game replaces every material with the toon shader
   using that base colour. Textures export fine but are ignored by the toon
   shader for now -- the one figured surface in the game, wood grain, is
   procedural and keyed on the colour (rule 12).
6. **Named materials on slots the game recolours.** The game recolours by
   material *name*, one colour per name, so a recoloured slot must carry
   exactly the names the game expects: the `tile` layers the game tints are
   called `Stone` and `Slate_flat`, and every other material on that slot
   keeps the colour it was modelled with. That is deliberate for `Sun` and
   `Moon` -- they must not be tinted, or a moon cell would paint its own
   crescent slate and show nothing. Slots that are never tinted (`rim_edge`,
   `rim_corner`, `platform`, `water`) may use as many materials as they like;
   the `socket` tints `Stone`, the `peg` tints `Shell` and `Mark_flat`, the
   `pip` tints `Pip`. Everything above keys on the *material* name, never the
   object name: several pipe pieces modelled in the same file each export an
   object literally called `Pipe_Shell`, and Blender's own uniquifying keeps
   only the first one bare, so the rest come back as `Pipe_Shell.001`,
   `.002` and so on (`Pipe_Shell_001` … `_004` once Godot's importer
   sanitizes the dot). Harmless today because nothing reads an object's name,
   but a future helper that keyed on one instead of on the mesh's material
   would be surprised by the suffix.
7. **`_flat` suffix.** A material named like `Wood_flat` gets toon shading but
   no outline. Use it for any surface that should not read as a piece. The
   `platform`, `water`, `rim_edge`, `rim_corner` and the tile's `Slate_flat`
   materials **must** carry the suffix (for example `Rock_flat`, `Moss_flat`); without
   it they get an outline shell the design does not want on them. A mesh
   keeps its outline unless *every* one of its material names ends in `_flat`.
8. **No parent.** Export objects with no parent. The exporter measures world
   space but moves the object in parent space, so a parented object exports
   somewhere other than where it was checked; clear the parent (Alt+P, Clear
   Parent and Keep Transform) first. The exporter rejects parented objects.
9. **No `.001` suffixes.** Blender's automatic duplicate suffix on an *object*
   name breaks the slot lookup (`Tile.001` exports as `tile.001.glb`, which
   the game never loads — the exporter prints a `WARN` for it), and on a
   *material* name it breaks the `_flat` check (`Rock_flat.001` does not end
   in `_flat`, so it gets an unwanted outline). Rename before exporting.
10. **Export settings.** glTF Binary (`.glb`), +Y Up, Apply Modifiers,
    Selected Objects, Materials: Export, no cameras, no lights, no animation.
    File name is the slot name. The script below does all of this.
11. **`_sway` marker.** A material whose name contains `_sway` bends in the
    game's wind (`shaders/toon_wind.gdshader`): vertices above local Z 0.03
    lean sideways, more the higher they are, so keep the planted part of a
    tuft below that height. Use it for grass, petals, leaves. Until the
    outline follows the wind, a `_sway` material must also end in `_flat`
    (`Grass_sway_flat`), and `core/toon.gd` reads the mark anywhere in the
    name. The rim pieces carry `Grass_sway_flat`, `Petal_sway_flat` and
    `Pollen_sway_flat` beside a still `Moss_flat`.
12. **Wood grains itself.** A surface that arrives in one of the palette's
    woods (`DECK`, `WOOD`, `BARK`, `TIMBER`) gets the grain shader instead of
    the flat one -- no marker, no material name to remember, because the
    colour is the mark. What you do owe it is a mesh with a length: the grain
    runs along the object's longest local side (`core/toon.gd grain_axis`),
    so a plank modelled long in X grains along X and a post tall in Z
    (Blender) grains up its height. A wood layer modelled near-square has no
    length to read and falls back to standing rings, which is fine for a knob
    and wrong for a board -- if a plank comes out with its grain crossing it,
    the mesh is the thing to look at, not the shader.

## Assemblies

A piece made of several objects — today the mascots — exports as a *collection*
instead of an object. The collection name is the slot name (`Mascot_Pom`
writes `mascot_pom.glb`), and every mesh inside it goes into that one file.

Why not one mesh: each coloured region is its own object with its own
material, so a layer can be recoloured, retextured, hidden or animated without
touching the rest. Parts overlap as closed solids rather than sharing an edge,
which keeps every part a clean closed smooth surface — the shape the
inverted-hull outline wants.

This is a rule, not a preference: **one mesh per layer**. Never merge two
layers into one mesh and never give one mesh two materials. A layer that is
its own object can be UV-unwrapped and textured on its own later; a merged one
cannot. Two lobes of the *same* layer (one material, like the muzzle) may share
a mesh. Add a detail as a new object with a new material, not as new faces on
an existing part.

The rules change in two places:

* **Rule 2 applies to the assembly, not to each part.** The union of the parts
  has its lowest vertex at Z = 0 and its footprint centred on X = Y = 0. Parts
  sit wherever they belong and all share the assembly's origin; the exporter
  measures the union.
* **Rule 6 does not apply.** An assembly is never tinted by state, so it may
  carry as many materials as it has layers. Rule 7 still does: give a face
  detail that should not read as its own piece a `_flat` material, as
  `Pom_Mouth_flat`, `Pom_Tongue_flat`, `Pom_Eye_flat`, `Pom_Cheek_flat` and
  `Pom_Map_flat` do.

Everything else holds per part: transforms applied, smooth with shared
vertices, no parent, no `.001` names, plain-colour Principled materials.

## Mascots

Mascots are **modelled by hand in Blender**, not generated. The `.blend` is the
source and is tracked in git (`art/mascot_<name>.blend`, un-ignored in
`.gitignore`); open it, move the parts, and re-export. Never write a script
that rebuilds a mascot from scratch — it would overwrite the hand edits.

`art/mascot_pom.blend` holds POM as 18 layers: `Pom_Body` (the cream egg),
`Pom_Cap` (the orange coat: a copy of the body mesh pushed out 0.012 by a
Displace modifier and cut by a Boolean with the `Pom_Cap_Cutter` ellipsoid, so
the cream face-and-belly oval is a shape the cutter moves and scales; copy the
body mesh into it again after reshaping the body), `Pom_Ear_L/R`,
`Pom_Eye_L/R` (closed happy arcs), `Pom_Muzzle` (two lobes, one layer),
`Pom_Nose`, `Pom_Mouth`, `Pom_Tongue`, `Pom_Cheek_L/R`, `Pom_Foot_L/R`,
`Pom_Tail`, `Pom_Arms` (`Pom_Arm`, both arms as two lobes of one layer),
`Pom_Pack` (`Pom_Pack`, the moss backpack) and `Pom_Map` (`Pom_Map_flat`,
the map held up in the right paw). The cutter lives in a `Pom_Helpers`
collection so it never exports. Concept reference: the mascot
sheet in `~/Downloads/chars.png`.

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/mascot_pom.blend \
  --python tools/blender_export.py -- Mascot_Pom
godot --headless --path . --import
godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- mascot_pom
open /tmp/shot_model_mascot_pom.png
```

`tests/_shot_model.gd` previews any slot on the real stage — toon materials,
outlines, island light — with the camera at eye level instead of the board's
top-down pitch.

## Building the pieces

The **tile is hand-modelled** and its `.blend` is the source, like a mascot:
`art/tile.blend` is tracked in git (un-ignored in `.gitignore`) and holds one
object, `Tile` — a 0.84 cube, every face inset by 0.03, a Bevel modifier at
0.024 with two segments and Harden Normals off, shaded smooth, one `Stone`
material. Open it, change the cube, re-export. `tools/build_pieces.py` must
never write a `Tile` again or the next run would overwrite those hand edits.

The rest of the Binairo pieces are still procedural: `tools/build_pieces.py`
builds five with bmesh (both emblems, empty mark, both rim pieces), following
every rule above, and saves `art/pieces.blend` as a by-product for looking at
them (the `.blend` is git-ignored; the script is the source). Each piece is a
flat outline extruded to height, bevelled on every edge, then each flat face
inset by a hair: with shared smooth vertices the bevel tilts the normals along
a face's rim, and the inset keeps that tilt in a thin band so the face reads
as one toon tone. Rebuild both, export and re-import in one go:

```bash
tools/build_models.sh
```

To change a procedural shape, edit the script and rerun; hand edits in
`art/pieces.blend` are overwritten. To change the tile, edit
`art/tile.blend` and re-export it alone:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/tile.blend \
  --python tools/blender_export.py -- Tile
godot --headless --path . --import
```

## Export script

`tools/blender_export.py` checks the rules and exports. Inside Blender, open
the Scripting tab, load the file and run it with the objects selected, or
from a shell (`art/pieces.blend` exists once `tools/build_models.sh` has run;
it is not in git):

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/pieces.blend \
  --python tools/blender_export.py -- Rim_Edge Rim_Corner
```

The names are Blender *object* names, or a *collection* name for an assembly;
each is lowercased to form the slot name (`Rim_Edge` writes `rim_edge.glb`,
the `Tile` collection writes `tile.glb`). With no names it exports the selected
objects; with nothing selected, every top-level mesh. Each object prints one
line, `OK` with the output path or `SKIP` with the rule it broke, preceded by
a `WARN` line when the slot name is not one the game loads, and the process
exits non-zero if anything was skipped.

## Seeing it in the game

```bash
godot --headless --path . --import          # register the new .glb
godot --path . --resolution 540x960 --script res://tests/_shot.gd
open /tmp/shot_binairo.png
```
