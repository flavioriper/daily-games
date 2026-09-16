# Models

Drop Blender exports here as `<slot>.glb`. The game looks for these names
(see `core/models.gd` SLOTS) and falls back to a primitive placeholder for
any that are missing:

| slot | what it is |
|---|---|
| `tile` | one board cell: a cube of side 0.84 standing on the platform, an assembly of four layers -- the `Stone` body, a `Slate_flat` slab on each of the two moon walls, and the `Sun` and `Moon` inlaid in opposite pairs of walls, like the pips of a die. Top and bottom are bare, which is the empty state |
| `rim_edge` | moss strip, 1 x 0.5, on one cell of the platform lip (outward side at +Z in Godot) |
| `rim_corner` | moss square, 0.5 x 0.5, on a platform corner (outward corner at +X +Z) |
| `platform` | 1 x 1 stone slab the board stretches to its size, top at y = 0 |
| `water` | flat water plane far below the platform |
| `mascot_pom` | POM the puppy, an assembly of 18 layered parts, one mesh per layer, with arms, a moss backpack and a moon-white map; Code Break seats it on a boulder beside its top rows |
| `socket` | Code Break's slab: `Stone` body tinted by whether its row is active, plus a `Well_flat` disc; the feedback slab hides the well |
| `peg` | a colour peg: `Shell` dome tinted per colour, seven `Mark_flat` pip layers of which the game shows one, and a `Shine_flat` highlight patch on the dome's upper-left |
| `pip` | a feedback pip: `Well_flat` disc and a `Pip` ball tinted slate or cream, hidden until scored |
| `lid` | the stone lid over one code slot, `Lid` body and wooden `Knob` |
| `pipe_pad` | Pipes's bevelled slab a pipe rests on, `Stone` body |
| `pipe_cap` | a pipe with one opening, modelled opening `UP`: `Steel` shell, `Collar` rings and a `Flow_flat` water tube that `_dress` gives its own flow material |
| `pipe_straight` | a pipe with two opposite openings, modelled `UP \| DOWN`; same three layers as `pipe_cap` |
| `pipe_elbow` | a pipe with two adjacent openings, modelled `UP \| RIGHT`; same three layers as `pipe_cap` |
| `pipe_tee` | a pipe with three openings, modelled `UP \| RIGHT \| DOWN`; same three layers as `pipe_cap` |
| `pipe_cross` | a pipe with all four openings, modelled `UP \| RIGHT \| DOWN \| LEFT`; same three layers as `pipe_cap` |
| `valve` | the bolted ring the source and the drain wear: `Metal` torus and four `Bolt_flat` bolts inlaid in the pad |
| `horse` | Horse Pen's horse in profile facing +X: `Hide` body, `Mane` mane and tail, `Eye_flat` eyes; cut down from a BlenderKit asset in `art/horse.blend` |
| `fence` | one cell of timber fence along X, `Timber`, exactly a cell long so runs meet post to post |
| `apple` | the meadow's bonus: `Fruit` with a flat `Stem_flat` and `Leaf_flat` |
| `snake_head` | Snake Apple's head facing +X, neck at the origin: `Scale` and `Eye_flat`; the body is a tube the board builds |
| `burrow` | the snake's burrow: `Earth` rim (mossy once open) around a `Hole_flat` disc |
| `deck` | one strip of Code Break's dock along X, `Deck` planks with a seam gap; the board stretches it |
| `pier_post` | a log at the deck's far edge, `Bark`, standing in the river |
| `boulder` | a rock beside the deck: `Rock` body, `Moss_flat` cap |
| `bush` | a cluster of leaf blobs, `Leaf` |
| `daisy` | a flower on the bank: `Petal_flat`, `Centre_flat`, `Stem_flat` |
| `tuft` | three grass blades, `Grass_sway_flat`, scattered as one MultiMesh |
| `signpost` | the hanging sign: `Bark` post, `Timber` plank, `Paper_flat` sheet, `Ink_flat` words |
| `title_sign` | the HUD title board: plank, leaf sprigs and screws; the words are TextMesh (`ui/hud/sign_view.gd`) |
| `mascot_camper` | the menu's camper, one textured mesh (`Camper_Tex`) cut down from a Meshy export in `art/mascot_camper.blend`; lit through the textured toon path |
| `camp_sign` | the menu's fence diorama, one textured mesh (`Camp_Sign_flat`) from `art/camp_sign.blend`; `world/camp.gd` letters a plank across its post stubs |

`tile` is recoloured **by material name**: its `Stone` body and `Slate_flat`
moon faces take the colour the cell is entitled to -- darker when it is a
given -- while the inlaid `Sun` and `Moon` keep the colours they were modelled
with. No layer's colour depends on which face is up. The other slots are never
tinted and may use several materials.

The `platform`, `water`, `rim_edge`, `rim_corner` and `Slate_flat` materials
must be named with the `_flat` suffix (for example `Rock_flat`), or they get
an outline shell the design does not want on them. The rim's grass, petals
and pollen also carry `_sway` so they wave in the wind; the moss does not.

The rim pieces here are generated: `tools/build_models.sh` rebuilds them from
`tools/build_pieces.py`, exports through the contract checks and re-imports.
The tile and the mascots are not: they are modelled by hand in `art/tile.blend`
and `art/mascot_<name>.blend` (both tracked in git) and exported from there as
a collection, one `.glb` holding every layer. The same script exports the tile
in the same run. Code Break's four pieces are hand-modelled too, in
`art/codebreak.blend`, one collection per slot. So are Pipes' seven in
`art/pipes.blend`, Balance's ten in `art/balance.blend`, Untangle's post in
`art/untangle.blend` and Shikaku's four in `art/shikaku.blend` (the plot
floor, the dry-stone wall, the corner post and the marker stone, whose nine
numerals are real glyphs converted to meshes rather than segment bars) and
Tents' four in `art/tents.blend` (the turf cell, the conifer, the tent and the
cairn; its row and column counts reuse Shikaku's marker stone).

Full rules: `docs/art/blender-contract.md`.
Concept reference: `docs/art/concept-binairo-island.png`.
