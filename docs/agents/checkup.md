## The board checkup (started 2026-10-01)

Each board in `Registry.PUZZLES` order gets: a performance pass (Insane
first, with `tests/_probe_perf.gd`; lag has so far been draw calls per
piece), a proper tutorial (`tutorial_pages()`: one animated lesson per rule,
level-aware), the in-game ? (shared, top bar; Settings > How to play opens
the same card), and Undo and Reset reachable on every level. "Next game on
the list" means the first row below without a date.

Shared fixes made on the way, which every board already has: the rules
sheet no longer rebuilds its labels on every move; the ? button; the clock
holds while the tutorial is up; `Face._mesh_for` memoises per face.
`Rewards.warm(text, fs)` (Balance, 2026-10-01) is there for any board to
call: a board whose first big sticker hitches warms its words at open.
Since Untangle (2026-10-01) `Face.Builder.stroke`, `fan`, `_feather` and
`Scenery.soft_disc` write their vertices into local arrays sized once and
append them whole (byte-identical output, checked against the old code):
any board that rebuilds a Builder mesh every frame got cheaper.
Since Shikaku (2026-10-01): `Face.FlatBuilder` bakes many cached meshes
into one with native copies (flattened once into a cache the board owns;
`Builder.append` loops every index in script); `Face.bake_into(b, xf, tint,
rest)` bakes a face eyes open and looking ahead, `at_rest()` says whether it
is drawn so, and hats/glasses fully on are baked; `Fx2D` asks the loader
thread for the board's sounds at open, so a cue's first play is no longer a
1-3 ms load mid-move.
Since Tents (2026-10-01): `Face._mesh_for`'s per-face memo keys on
`_kind()` as well, so a face whose kind changes (a tent pegged, a bee
pinned, a lantern lit) gets its new mesh; `CountChip.numeral()` and the
"numeral" skip let a board draw every chip's number itself. A tutorial page
can hold the board itself, quietened (Tents' `Meadow`), instead of
re-drawing it.
Since Light Up (2026-10-01): `Face.FlatBuilder.append_flat(f)` and
`FlatBuilder.flat_of(builder)` let a board keep its own cache of flat
triangle lists (no ArrayMesh per entry), and an append under the identity
transform copies without transforming. A board whose pieces fade through a
colour can cache a few steps of it (Light Up's stones, eight warmth levels)
so even a moving piece is a native copy. A board that bakes what is at rest
must keep building until everything is at rest: the last frame of a fade
is a step short (`busy` while anything is live), or the stale live mesh
stays on screen.
Since One Line (2026-10-02): a flat triangle list is four times an indexed
mesh's vertices, and that costs ~1.3 ms a frame to draw at rest on a big
figure; One Line keeps its mesh indexed by giving every piece a fixed run
of vertices (sized at layout for its largest look) so a cached look's
indices are offset once (`_slot` in `puzzles/oneline2d.gd`). One MultiMesh
per look was far worse (draw calls).
Since Nonogram (2026-10-02): a shape drawn in slot colours (`_slot`) keeps
its colour runs (a fan's body, its feather), so painting it any colours is
one `fill()` a run, no per-vertex script, and one cached shape serves every
piece that shares its geometry (`_shape`/`_ink`/`_put` in
`puzzles/nonogram2d.gd`); `ui/faces/mosaic_tile.gd` hands out a tile's and a
socket's outlines and colours separately for that.
Since Queens (2026-10-02): Nonogram's machinery is shared as
`ui/flat/run_mesh.gd` (`RunMesh`: `room` a run per piece in paint order,
`put` a cached shape painted by slot colours under a transform, `mesh`); a
board hands it a Callable that draws shape `id` in `RunMesh.slot(k)` colours.
Make the shapes (and any still floor) at a reference cell size and draw them
scaled, and keep them across a relayout that only rescales: the win card's
slide relays the board out (`_thaw_board`), which was a 45-75 ms frame on
Queens while every shape, run and index offset was made again. And never
test a restore's stamped moment by its sign: the boards' clock counts from
launch, so `now - 10` is negative for a day reopened in the first seconds
(Queens, Untangle and Pinwheel fixed with a `-INF` sentinel; Paper
Planes still carries the test; Quilt was checked at its checkup and does not:
its restore leaves `_solved_at` at -1 and stamps nothing it tests by sign).
Since Hidden Word (2026-10-02): a Button with its own StyleBoxFlat and text
costs two draw calls (the box is a polygon, the text a glyph batch); a tray
of them is the lever, not the board. `ui/flat/key_board.gd` keeps its
Buttons for input and motion, blanks their styles and text, and paints
them all from one `Paint` child (faces as one mesh of cached looks under each
Button's transform, then every letter) -- the pattern for Sudoku's
`digit_pad.gd` and any other tray of Buttons. A tutorial page can hold the
real tray too, scaled, with its chips set to ignore the mouse and the finger
firing them (`button_down`, then `button_up` and `pressed`).
Since Word Trail (2026-10-02): `RunMesh.put_builder` writes a Builder made
this frame into the open run when it has room (the tail otherwise), so a
live drawing (a ribbon's wave, the beam) keeps its paint order. Shapes made
at the first layout and drawn scaled after the win card's relayout cannot
include anything laid out with fixed-pixel gaps between cells (a path
through cell centres, a frame round the field): draw those live when the
layout is not the reference one (`_relaid()`). A tutorial board can be laid
out its own way by overriding the board's layout hooks (`_cell_for`,
`_origin`, `_slots_*`, `_puff_foot`, `_lamp_rest`).
Since Mushroom Patch (2026-10-02): a board can run two `RunMesh`es (its
floor and its ground) from one reference cell; a run can be laid only where
a piece can be (a turned cell gets no sod, no pebble) and laid again when that
changes (Mushroom's rose halos), and a rare, transient piece (a pebble on its
way out) can go on the tail rather than reserve a run under every cell -- the
reserved vertices are uploaded on every rebuild. Faces that are nodes can be
baked at rest the way Shikaku's signs are; a twin drawn by its node over the
bake should drop its own shadow (`shadowless`), and that flag must be lifted
while it bakes, since `bake_into` honours it too. `zsh` does not word-split
`$v`: a loop over `"d=3 fill"` hands the probe one argument and `fill` never
reaches it -- `${=v}`.
Since Sudoku (2026-10-02): `RunMesh.put(id, [], xf)` puts a shape in the
colours it was drawn in, for a still drawing with more colours than slots
(Sudoku's tray and nine panels as one shape); a shape put on the tail keeps
its offset indices for that place (`_tail_offsets`), so pieces that come and
go and are put first on the tail (Sudoku's washes, the same shape cell after
cell) need no run reserved under every cell -- reserving 81 runs made the
mesh 28k vertices and its upload cost what the runs saved. `RunMesh.close()`
sends the next pieces to the tail. `ui/flat/digit_pad.gd` paints its chips
the way `key_board.gd` does (and reuses its `_shadow`, `_rounded`, `_held`,
`_blank`), with `CozyTheme.paper()` on the paint so the chips keep their
grain. A tutorial page can look through a magnifying window
(`clip_contents` and the board scaled about one cell) when the band's board
is too fine to read at page size (Sudoku's 9x9 hills).
Since Bridges (2026-10-02): a board can build its shapes **in a reference
layout's own space** and draw the whole mesh under one transform onto the
layout it has now (`_in_ref` makes `_cell()`/`_origin()` answer the
reference; `_relay()` maps it), so the win card's smaller relayout reuses
every shape without each piece being made about its own origin; the
reference is taken again only when the layout grows. A layer whose pieces
all stand as they stood hands its last mesh back (`_runs_sig`,
`_islets_sig`): an islet bumping does not rebuild the runs. A room must be
laid **before** `RunMesh.begin()` -- one laid mid-build moves `_fixed` and
the tail's indices already written point into it -- and rooms must be
opened **in the order they were laid**: a put truncates the mesh to its
cursor, so opening a lower room after a higher one cuts the higher one's
pieces off (Bridges' runs vanished when a lane went to nothing and came
back, reordering `state.runs`; caught in review). Not everything the
renderer pays for is vertices: Bridges' sea is ~1 ms of its idle on native
GL from stacked translucent full-pool layers (fill), which no mesh work
reaches. The probe's shots freeze when the Mac's display sleeps (every frame
identical; under ANGLE the readback is all zeros): run windowed harnesses
under `caffeinate -d -i -u`.
Since Quilt (2026-10-02): a board whose pieces are **dragged** pays its
rebuild on every frame the finger is down, not just while something
animates -- Quilt's whole quilt and rack were built in script on every
frame of a drag (4.4-6 ms and 2.6-3 ms on a full Scrap Basket), so holding
a patch still cost 11.7 ms a frame. The split that fixed it is the general
one for a board of pieces that move as wholes: every piece is **at rest**
(its look, made once about its own top-left, put where it lies into a still
mesh that is handed back while its plan -- look, x, y per piece -- is
unchanged), **moving as a whole** (the same look under one transform: a
wiggle, a squash, a hop, a dance; a colour change the look cannot hold is a
few cached steps of it, the solve's sheen in eight), or **changing**
(drawn live). The looks go through `RunMesh.put(id, [], xf)` with no rooms
at all -- everything on the tail -- so the still mesh stays indexed and its
places' offsets are kept. The live mesh keeps paint order by flushing a
Builder (`put_builder`) before each look it puts. Order changes this makes
(a still seam under a moving neighbour, a moving patch over still ones) only
show while something moves.
Since Fairy Lights (2026-10-02): a board can **paint its faces from one
mesh** instead of letting each node draw itself: `Face.painted` makes a
face's node draw nothing and `Face.layers_now()` hands its owner the layers
it would have drawn (mesh and transform each), which the owner puts under
the node's own transform (`slot.get_transform() * face.get_transform()`)
into a `RunMesh` with no rooms, a shape per shared layer mesh. **Round the
put's origin to a whole pixel**: the renderer puts a node's origin on one,
and the painted faces sat half a pixel off the nodes' frames until they did
(then pixel-identical). A face its node must draw (a tint on `modulate`, a
hidden one) is left to the node. A board whose rest pieces depend only on a
few bits (Fairy Lights' wire: its stubs, which of them meet, lit or dark)
can key every pass's shape on those bits and build the rest mesh from the
cell's look codes, handed back while the codes are the ones it was built
from; a cell is drawn live only while any curve reader on it is not at its
resting value. Tutorial gardens that are short on a wide page can hang the
hearts beside the grid (`_heart_row()` 0, `_hearts_at()`, `_inset()`).
Since Paper Planes (2026-10-02): a RunMesh with runs pads every build to
all its runs, so a live layer must not borrow it (a few trails a frame
uploaded the still mesh's 57k reserved vertices): `RunMesh.share_shapes`
gives a second RunMesh with no runs the same shape cache. Put a board's
looks once in their runs as the layout is laid, so the offsets' script loop
is paid at open and not on the first change mid-game. An entrance that
pops every piece in is a look under a transform per piece (in its own run),
not a live build of the whole board.

Since Pinwheel (2026-10-02): a look painted more than one way can serve
several layers of one piece: Pinwheel's silhouette is put three times (the
shadow under its offset in a translucent ink, the lip under `EDGE` in the
deep cloth, the cloth itself), so a swinging piece is its looks under one
turn about the pin with the screen-space offsets composed outside it, never
a live build. A RunMesh whose earlier puts change size every frame (a live
stain, a tugged ribbon) moves every later look to a new place, and a put on
a new place offsets its indices in script: Pinwheel's one top mesh spent
2-3 ms a frame doing that for sixteen wheels, so layers that change on
their own clocks get their own meshes (each a draw call) and a come-and-go
piece (a button) goes after the steady ones. Prime the looks at open
(`_prime_looks`, 35 ms once on Insane, inside the opening frame) so a first
turn mid-game makes nothing.

Since Rings (2026-10-02): a board whose pieces are a few looks under
transforms can keep its per-piece meshes and only change how they are made:
Rings' stations were already a mesh each, rebuilt only when their look
changed, but every rebuild drew each ring's ~2.5k feathered vertices in
script (2.5-5 ms a station), so a landing's squash, a lock's glint and the
solve's spin (every station, every frame) still cost 16-35 ms frames. Now
every ring part is a `RunMesh` shape made once at the ring's size about its
own origin (the band per ring code, the face per colour, each emblem at the
size it is drawn so its feather stays 1.5 px, painted through slots with
its fade in 16 steps, the glint in a slot), and a station or the ring in
hand is those shapes copied under the moment's squash, lean and turn (a
station ~0.4 ms, the ring in hand ~0.2). A shape whose geometry changes
with one length (the post into the top ring's hole) is a look a whole pixel
of that length. And a judge's search is script too: Rings' dead-end
verdict (10-15 ms on Insane) ran inside the drop's tap; it now runs on a
`WorkerThreadPool` task from the moment the ring is lifted (`prejudge`,
`settle_judge` on a new deal and on leaving the tree), and the drop reads
its answer.

Since Caterpillar (2026-10-02): **the win card's relayout is a frame every
board pays unless it was built for it.** Caterpillar's took 70-97 ms on
Insane because the lawn, the bed, every leaf look and the whole baked tail
were made again at the smaller size; now everything on the bed is made in
the reference layout's space and drawn under `_relay()`, and only the lawn
(it covers the whole card, whose shape changes) is made again. Two meshes
that only part company under the win card can be **joined while the relay is
the identity** (`_join`: one mesh's vertices first, so only the other's
indices are offset, once): the lawn and bed apart were a draw call, ~0.3 ms
an idle frame. A leaf, fence or badge layer that rebuilt all of itself while
any one piece moved is a **rest mesh in runs** (`RunMesh` rooms, one per
piece, so a piece changing its look offsets only its own indices; on one
tail a change re-offset every look after it, 5-10 ms) plus a small live mesh
on a second RunMesh sharing the shapes. A per-frame drawing of a character
whose look depends on a few small numbers (the head: its turn, eyes, sway,
scrap) is a **look cache keyed on those numbers in steps**, put under the
moment's breath and squash. A board's first streak sticker can hitch on its
glyphs like Balance's words: draw its digits out of sight on the first
frame. And **this Mac's frame times are worthless while Spotlight indexes**
(`mdworker_shared` at 250% CPU swung identical runs by 2 ms): check `ps`
before believing a regression, and compare script times and vertex counts
when it is busy.

Since Sunbeam (2026-10-02): **a look that changes every frame of a drag
must not be the whole piece.** Sunbeam's mirror wore its sheen (sliding
with the peg) inside its look, so a held mirror was a new 4.4k-index look
every frame, offset in script; the sheen is now its own small look put over
the glass. And **a RunMesh tail is only cheap while everything before a put
stays the same size**: a landing's lift steps, a target peg coming and
going and a drop turning wet moved every later look to a new place, so the
cups, drops and mirrors went into rooms of their own (`_lay_rooms`), laid
again on a new deal. A round-capped stroke is mostly its caps (two discs a
run, in script): Sunbeam's beam and pulses stroke their bodies capless and
put each cap as a disc look. And **under ANGLE on this Mac the renderer's
CPU share is not the meshes' cost**: freezing the old board's redraw made it
*slower* (3.9 -> 5.8 ms render-cpu), so idle render-cpu swings with GPU
clocks; settle a render question on the native GL driver (Sunbeam's idle
3.85 vs 4.37 ms, play 4.3 vs 8.15 there).

Since Super Slider (2026-10-02): **a shared drawing can be split into its
layers rather than rewritten**: `slider_block.gd`'s `block()` now calls
`shadow`, `wood`, `sheen`, `carving`, `face` and `chevrons` in turn (checked
identical, vertex for vertex, against the old function), so the menu card
keeps calling `block()` and the board makes each layer once as a look. A
layer that only appears while lifted (the outer shadow, the sheen) is put
**always**, at no alpha while resting, so a block's run never changes size
and nothing after it moves place when it lifts. And **a solver-backed
tutorial must keep its trays crowded**: a 4x5 sliding tray's graph explodes
with empty cells (eight empties: 288k positions, 6 s), and a lesson's judged
move is not judged until the solve is done; the page waits for it before its
first drag and keeps each tray's solve for the session (`Board._solved`).
And a Homesick dead end never comes near home: the bank's shallowest is 10
moves out, and no hand-made or searched small tray has one, so its page
plays a real crowded mid-game tray.

| # | Board | Done | Notes |
|---|---|---|---|
| 1 | binairo | 2026-10-01 | MultiMesh coins and faces (391 -> 147 draws full Insane); 5-page tutorial; Undo on Insane |
| 2 | mastermind (Code Break) | 2026-10-01 | played rows baked to one mesh each (300 -> 147 draws full Insane); 4-page tutorial; undo/reset already there |
| 3 | balance | 2026-10-01 | already ~100 draws; the lag was a glyph-rasterising hitch on the first big sticker (solve 27-47 ms frame) -> shared `Rewards.warm()`; 3-6 page tutorial; Undo on Insane |
| 4 | untangle | 2026-10-01 | resting pegs baked to one mesh (Insane idle 130 -> 95 draws, ~10.8 -> ~8.4 ms); carrying 16.7 -> 11.9 ms (rope mesh writer, crossings kept per pair, binds only when changed); shared `Face.Builder` stroke/fan/feather and `Scenery.soft_disc` write whole arrays; 3-5 page tutorial; undo/reset/hint already there |
| 5 | shikaku | 2026-10-01 | signs at rest baked (eyes-open twin, blinks drawn over it), beds at rest baked, fence still/moving split, crop one mesh (Insane idle 129 -> 100 draws, ~9.0 -> ~7.2 ms; full 156 -> ~115; solve peak 253 -> 164); shared `Face.FlatBuilder`, `bake_into(rest)`, Fx2D sound prefetch; 3-6 page tutorial; undo/hint/check/reset already there |
| 6 | tents | 2026-10-01 | ground at rest baked (a full meadow's ground rebuild was ~28 ms a frame while anything moved), faces drawn as MultiMesh bodies + one numeral run (Insane idle 142 -> 95 draws; full 182 -> 109, ~14.8 -> ~9.7 ms, p95 25 -> 10.6; solve peak 211 -> 134); shared `Face._mesh_for` memo keys on `_kind()`; 4-6 page tutorial played by a real board; undo/hint/check/reset already there |
| 7 | lightup | 2026-10-01 | the court was built whole in script every frame anything moved (floor ~10 ms + ground ~8 ms full Insane): stones, blocks, chips and lamp shadows at rest baked from parts made once, a moving stone a cached step of eight warmth levels, a moving block its cached body under its pose (Insane play 26.8 -> 12.8 ms, p95 32 -> 17); lanterns and cats one MultiMesh per mesh, moths one mesh (near-full idle 150 -> 109 draws, 12.2 -> 10.4 ms); shared `FlatBuilder.append_flat`/`flat_of`, identity appends skip the transform; 5-7 page tutorial played by a real board; undo/hint/check/reset already there |
| 8 | oneline | 2026-10-02 | the whole figure was built in script every frame anything moved (16-20 ms full Insane): now one indexed mesh put together from pieces that each own a run of vertices sized at layout, a look made once and copied natively, a moving piece its look under a transform, only colour changes built live (Insane play 23.1 -> 9.3 ms, step hitch 17 -> ~3 ms; idle and draw calls unchanged); 5-6 page tutorial played by a real board on a little house; undo/hint/check/reset already there |
| 9 | nonogram | 2026-10-02 | the whole floor (33k vertices: sockets, tiles, X's, tabs, leaves, daisies) was built in script on every frame anything on it moved, 14 ms a build on a full Insane floor: now every piece is a shape made once about its origin, copied natively under its transform into a run of vertices laid out for it (One Line's pattern) and painted a colour run at a time with fills, finished moments pruned so a resting piece skips the curve readers (build 14 -> ~1.5 ms headless; Insane play 12.4 -> 7.8 ms, p95 16 -> 8.3; full-board animating frames ~22 -> 8-12 ms, solve spikes 57-61 -> 15-27 ms; idle and draw calls unchanged, pixel-identical at rest); shared `Mosaic.tile_outlines/tile_colours/socket_outline/socket_colour`; 4-6 page tutorial played by a real board on a 5x5 house; undo/hint/check/reset already there |
| 10 | queens | 2026-10-02 | the ground (washes, flowers, halos, shadows, every X) was built in script on every frame anything moved (9-13 ms full Insane, a 56-60 ms frame on a seat's wave) and the floor (3 ms) with it: now the floor is made once a court and the ground is put together by the new shared `RunMesh` from four shapes copied natively into per-cell runs (ground build ~2 ms, p95 2.5; Insane play 10.7 -> 8.5 ms, p95 11.7 -> 9.1; full-board play p95 24 -> 11, the per-move spikes gone; draw calls unchanged, pixel-identical at rest); shapes and floor kept across the win card's relayout (a 45-75 ms frame gone); a restored day opened in the first ten seconds showed its crosses and crowns again (`-INF` sentinel; Untangle too); 4-6 page tutorial played by a real board on a 5x5 court; undo/hint/check/reset already there |
| 11 | hiddenword | 2026-10-02 | the keyboard was 56 of 125 idle draw calls (each key a Button: its StyleBoxFlat a polygon, its letter a glyph batch): the Buttons still take taps and carry the press, bump and slide tweens but draw nothing, and one `Paint` control draws every face as one mesh (a look made once, copied under each key's transform) and every letter after it, rebuilt only on a frame where a key moved or was repainted (Insane idle 125 -> 68 draws, 9.4 -> 5.1 ms); the grid (beds, tiles, envelopes, caret, flip shadows) was built in script on every animating frame, 4-7.6 ms and growing with the rows: now on `RunMesh`, shapes made at the cell and runs laid per cell, relaid only when the cell changes (build ~1-1.6 ms; Insane play 12.5 -> 5.5 ms, full-board play 10.8 -> 6.5 ms, the 44-46 ms type/solve spikes gone; pixel-identical at rest); 5-7 page band-aware tutorial played by a real, quietened board (two rows, no band) over the real keyboard; no Undo by design (an Enter is the check; backspace is the undo of typing), hint/reset/? already there |
| 12 | wordtrail | 2026-10-02 | the field (walls, tiles, ribbons, glows, flowers, the night sky and the lantern's pool, ~20k vertices on Insane) was built in script on every frame anything moved, 8.5 ms, and the slots 3 ms with it: now both on `RunMesh`, every cell's piece a shape copied natively into its run, a word's whole ribbon its own shape, only a moving wave, glint or beam drawn live into its word's run (`put_builder` now fills the open run); field build ~1.7 ms, slots ~0.4 (Insane play 21.0 -> 9.2 ms, full board 24.0 -> 9.8 ms; night and miss scenarios 16.5 -> 9.4 and 14.4 -> 8.0 ms; idle and draw calls unchanged, pixel-identical in play); shapes kept from the first layout and drawn scaled on the win card's half-size board (that frame 20 -> 10 ms; whole ribbons and the sky drawn live there, the gap being fixed pixels; tile lips proportionally thinner there); 4-5 page band-aware tutorial played by a real, quietened board on a 4x4 field in the player's language, laid out field-left, slots-right: tracing a word, the boxes as the only clue (a wrong trail unwinds, or let go off the field where wishes count), the dandelion's wishes, Night Walk, Undo/Reset, the bulb; undo/hint/reset/? already there |
| 13 | mushroom | 2026-10-02 | the floor (beds, sods, tufts, fairy rings; 28k vertices) was built in script on every frame anything moved, ~12 ms on Insane, and the ground (pebbles, discs, flowers, halos) 6-12 ms more on a full patch: both now on `RunMesh` from shapes made at the cell (floor ~1.2 ms, ground <1 ms; a ring's caps drawn live only while they grow in); the mushrooms at rest baked into one mesh, eyes-open twins under any that blink (full Insane idle 124 -> 100 draws, 10.1 -> 8.0 ms); Insane play 20.7 -> 9.0 ms (p95 25 -> 10.4, max 67 -> 16), full-board play p95 26.5 -> 10.4 (the remaining ~33 ms frame is the host's solve overlay, every board's); pixel-identical at rest but for sub-pixel AA on ring caps and baked mushrooms; 4-6 page band-aware tutorial played by a real, quietened board on a 5x5 patch with a chip tray beside it: a number held lights what it counts and the covered one is planted (green), pebbles by stroke and rubbed out, Fairy Rings (Insane), hearts (Hard/Insane), Undo/Reset, the bulb (bands with hints); undo/hint/check/reset/? already there |
| 14 | sudoku | 2026-10-02 | the digit pad was 25 of Insane's 104 idle draw calls (each chip a Button: its StyleBoxFlat a polygon, its digit a glyph batch, the cross three Icons polylines): now Hidden Word's pattern, the Buttons take the taps and carry the squash but draw nothing, and one `Paint` control draws every face and the cross as one mesh and every digit after it, the paper grain on the paint (Insane idle 104 -> 81 draws, ~9.1 -> ~7.3 ms); the grid (tray, floor, nine panels, every wash, daisy, the selected tile and Insane's ~25 hills) was built in script on every frame anything moved, 3.3-8 ms: now on `RunMesh`, the tray and panels one shape in their own colours (`put` with no colours), each wash, daisy, the selected tile and each hill at rest a shape under its transform, washes on the tail where a place keeps its indices (`_tail_offsets`), only a landing, a hill's reach and a hill or daisy on the move drawn live (build ~1.0-1.3 ms; Insane play 11.5 -> ~8.8 ms, now render-bound); pixel-identical at rest, the selected tile's lift and shadow swelling with its bump by under a pixel; 4-5 page band-aware tutorial played by a real, quietened board on the band's own grid (6x6 or 9x9) with the real pad scaled beside it: placing the missing number of a row and the row lighting up, a clash and the cross (Easy/Medium) or a heart lost and the number crossed out (Hard/Insane), Hilltops through a magnifying window (Insane), Undo/Reset, the bulb; undo/hint/check/reset/? already there (Check left out on judged bands by design). The ~40 ms frames left are the host's win card, every board's |
| 15 | bridges | 2026-10-02 | the whole board (84k vertices: every run's planks, slats and posts, every islet's drum, moss, sprouts, coin and ring) was built in script on every frame anything moved, 30-53 ms a build: now two `RunMesh`es built in a reference layout's space and drawn under one relay transform, an islet its body, pennant, coin (painted through slots) or lantern and ring as shapes under its own scale and offset, a run at rest one cached shape and a run rolling, previewed, shivering or half lit drawn live into its room, each layer handing back its last mesh while nothing on it changed (build ~1.5-2 ms; Insane play 37.5 -> ~8-13 ms, p95 54 -> 13-15, max 70 -> 20; full-board Insane play 18.7 -> 10.5, p95 43 -> 14; Easy play 21 -> 10.2; idle and draw calls unchanged, pixel-identical at rest); the win card's relayout reuses every shape (the sea is still made again there, its pool changes shape: ~17 ms once, inside the host's win frame); 6-page band-aware tutorial played by a real, quietened board on hand-made 5x5 seas: two planks from an islet to the one it faces and its ring filling, a crossing drag refused, two groups joined into one network and the gold wave, a plank too many turning an islet rose with Check and taps on the water (Easy/Medium) or a wrong plank sinking for a heart and its buoy (Hard/Insane), Lantern Night's lantern counting islets (Insane), Undo/Reset, the bulb (bands with hints); undo/hint/check/reset/? already there (Check left out on judged bands by design) |
| 16 | quilt | 2026-10-02 | the whole quilt (every sewn patch, its print, stitch and button, every seam) and the rack (every waiting patch and empty bay) were built in script on every frame of a drag or any animation, 4.4-6 ms and 2.6-3 ms on a full Scrap Basket: now every patch, bay and finished seam at rest is a look made once and put into a still mesh handed back while nothing at rest changed, a patch that only moves (wiggle, boing, the solve's hop and dance) is its look under a transform, the solve's sheen and the hem's warming eight cached steps, and only a patch sewing, blushing, flying or popping a button drawn live (quilt build 0.6-1.0 ms, rack ~0.2 ms; Insane play 8.6 -> 5.2 ms, p95 10 -> 6; full Scrap Basket with a patch held 11.7 -> 4.7 ms; full Insane play 8.4 -> 5.4, p95 13.6 -> 7.4; Easy play 5.8 -> 4.0; draw calls unchanged but +1 for the ghost's own mesh while a drag is live; pixel-identical at rest); 5-page band-aware tutorial played by a real, quietened board on a hand-made 4x3 quilt laid out quilt-left, rack-right: two patches dragged on and the quilt lighting up, a patch held over another refused with the rose halo and then fitting as drawn, a sewn patch dragged off (Easy/Medium) or a wrong patch snapping its stitch for a heart and its spot chalked (Hard/Insane), Scrap Basket's scrap left in the basket (Insane), Undo and Reset (Reset alone on judged bands, where a right patch stays), the bulb (bands with hints); undo/hint/reset/? already there (no Check by design: nothing wrong can be sitting on the quilt) |
| 17 | fairylights | 2026-10-02 | the whole wire layer (washes, pins, three glow bands, every piece's shade, face and sheen, beads, clips, the post, the tags; 15k vertices on Insane) was built in script on every frame anything moved, 7-20 ms a build, and the lanterns were 48 of Insane's 130 idle draw calls (a LanternFace node is two or three): now every piece at rest is a shape keyed on its look (stubs, which meet, lit, mid bead, clip, tag reading and gold) put by `RunMesh` into a rest mesh handed back while the cells' looks are unchanged, only a piece turning, pressed, shivering, fading, flaring or popping drawn live over it, both built in a reference layout's space and drawn under `_relay()` (the win card's smaller relayout rebuilds nothing); every lantern painted from one mesh (`Face.painted`/`layers_now()`, origins on whole pixels), a pressed one left to its node (rest rebuild ~2 ms, handed back ~0.7; Insane idle 130 -> 83 draws, 10.5 -> 7.3 ms; Insane play 16 -> 7.8 ms; full Insane idle 13.4 -> 8.5, play 15.9 -> 9.0, p95 21.7 -> 15.2, max 55 -> 25; Easy 9.1/10.6 -> 6.7/6.5; pixel-identical at rest in rest, tags, fuse, restore, max diff 2); 4-6 page band-aware tutorial played by a real, quietened board (`Garden`) on a hand-made 4x4 garden: a piece tapped round until it joins the lit wire and the lantern at its end wakes, the last loose end turned home and the chase, a right piece tapped for a fuse, a heart and its clip (Hard/Insane), a tagged lantern lit at its count ticking gold (Insane), Undo and Reset, the bulb (bands with hints); the hearts hang beside the garden on the page; undo/hint/reset/? already there (no Check by design) |
| 18 | planes | 2026-10-02 | first the sky became a maze at the user's word (Easy/Medium/Hard 12x17, 16x23, 21x30 at 0.95-0.98 cover, long bent planes, a key-ordered carve; Insane keeps its banked Windy Day sky); then: the still mesh (panel, glows, every plane at rest) was built whole in script on every change to the moving set (every launch, landing, beat, press, flutter; 14-18 ms old Insane, 28-38 ms Hard maze) and the entrance drew every plane live (30 ms frames on a Hard maze): now a `RunMesh` of looks made once a layout in runs whose offsets are worked out while the board opens, the ground (dots, leaves) its own mesh keyed on which planes stand, fly or are gone, a popping plane its look under its pop, a beating or shivering one its trail slid plus a live dart (new `RunMesh.share_shapes`), and the sky's clouds and sock one mesh instead of a draw call each (Insane idle 88 -> 81 draws; still rebuild 14-18 -> 0.3-1 ms; Insane play 10.8 -> 9.1 ms, max 28-36 -> 19-27; Hard maze, old board code against new: play 14.4-15.4 -> 10.5 ms, p95 33-35 -> 16.5, max 72-75 -> ~30, idle max 57-64 -> 10-17; at rest unchanged by eye, run-to-run noise the only pixel diff); 5-6 page band-aware tutorial played by a real, quietened board on a hand-made 6x5 sky: a clear plane launched, a blocked one waiting for free (Easy/Medium) or the one in front first and a crash for a heart (Hard/Insane), Windy Day's cloud blowing past (Insane), the last planes and the solve wave, Undo and Reset (Reset alone on Insane), the bulb; undo/hint/reset/? already there (no Check by design; no Undo on Insane by design) |
| 19 | pinwheel | 2026-10-02 | the still layer (every resting piece's shadow, lip, cloth, print, stitch and edge; 18k vertices on Insane) and the live layer (the stain, the ribbons, sixteen wheels; 24k) were built in script on every frame anything moved, the idle breeze's gusts included, 7-24 ms and 8-20 ms a build: now every piece is a silhouette painted three ways (shadow, lip, cloth), a print and a trim painted in its thread and edge (so the solve's warmth is a fill), each wheel, its shadow, the tack, the button, every resting ribbon and each settled stain a look, all made at open in a reference layout's space and put by `RunMesh` under a transform (a swinging piece is its look turned about its pin, the lip and shadow under their own offsets), drawn under `_relay()`; the still, stain, ribbon and wheel meshes are separate and each handed back while its plan is unchanged, so a live part of one never moves where another's looks land; only a crossing stain wave, a tugged ribbon and a refusal's halo are drawn live (build ~2-3 ms in play; Insane play 24.2 -> 10.1 ms; full Insane idle p95 21.8 -> 9.3, max 40 -> 10, play p95 22 -> 11, max 53 -> 18; Easy play 11.9 -> 9.3, idle 9.1 -> 8.5, p95 12.6 -> 9.1; +1-2 draw calls; at rest identical but for sub-pixel AA on the wheels' hubs); a restored day reopened in the first ten seconds lost its solved warmth (`-INF` sentinel); 4-5 page band-aware tutorial played by a real, quietened board (`Frame`) on a hand-made 4x3 frame (an L, a T, a domino, a bar): the L turned twice round its pin off two dark squares, the last piece turned home over the quarter the frame skips and the solve wave, a home piece snagging for a heart and its gold button (Hard/Insane), one tap on the top pinwheel tugging two tied pieces home, the crossed one the other way (Insane), Undo and Reset (Reset alone on Insane), the bulb (bands with hints); the hearts hang beside the frame on the page; undo/hint/reset/? already there (no Check by design; no Undo or hints on Insane by design) |
| 20 | rings | 2026-10-02 | each station was already its own rest-pose mesh, but every rebuild (a landing's squash and bump, a lock's glint and cap, the twirl, the solve's spin of every peg) drew its rings in script, 2.5-5 ms a station (16-35 ms for all seven), and the ring in hand 1-2 ms every frame it moved, through a per-vertex identity Callable: now every ring part is a `RunMesh` look made once (band per code, face per colour, emblems at drawn size painted through slots with a stepped fade, glint, shadow, socket, daisy, hover disc, leaf mark, the post a look per whole pixel of length) copied under the moment's squash, lean and turn (all seven stations 3-4 ms, the ring in hand ~0.2 ms); the dead-end judge (`Gen.verdict`, 10-15 ms a drop on Insane, inside the tap) runs on a worker thread from the lift (Insane play 10.0 -> 9.3 ms, p95 13 -> ~10, max 24 -> 14-16, no slow drop left; full Insane play p95 13.8 -> 10.3, the solve spin's 25-28 ms frames gone, the remaining spike the host's win card; Easy play 10.2 -> 9.7; draw calls unchanged; at rest identical but for sub-pixel AA on two stations); a restored day reopened in the first ten seconds now keeps `_solved_at` (`-INF` sentinel); 4-5 page band-aware tutorial played by a real, quietened board (`Yard`, one row of three pegs, two colours) on hand-made pegs: a ring lifted, refused on another colour and set on an empty peg, a ring onto its own colour locking the peg and the last one home with the solve wave, the only empty peg spent on the wrong ring (a dead end found by searching every two-colour three-peg deal) wobbling for a heart and the right ring going there (Hard/Insane), a two-tone ring turning over as it lifts and landing as the colour it shows (Insane), Undo and Reset (Reset alone on Insane), the bulb (bands with hints); undo/hint/reset/? already there (no Check by design; no Undo or hints on Insane by design) |
| 21 | caterpillar | 2026-10-02 | already polished for lag on 2026-10-01 (baked tail, cached parts); what was left: the win card's relayout rebuilt the lawn, bed, every leaf look and the whole tail (a 70-97 ms solve frame on Insane, 65 ms on Hard), the head built in script every frame idle included (0.5-2 ms), the leaves, fences and badges rebuilt whole on every frame of a chew or a refusal (1-2 ms, 5-10 ms spikes once on one tail), the hearts-and-tummy pill rebuilt on every Peckish step (2.8 ms), the party's flutter drawn live (~3 ms a frame for 2 s) and the streak's x3 rasterising cold (~20 ms): now the bed, leaves, fences, badges, body and head are made in a reference layout's space and drawn under `_relay()` (only the lawn made again on the win card; the lawn and bed one joined mesh in play), the leaves, fences and badges RunMesh looks in runs of their own with a rest mesh handed back and a small live one, the head a look per turn/eyes/sway/scrap under its breath, the stretch near the head put into runs per segment slot (indexed, ~35% fewer vertices uploaded a drag frame), the pill cached by what it shows, the flutter sixteen looks, the digits warmed at open (full Insane idle 12.3 -> ~10 ms, play p95 15 -> 12.5-13, the solve's 87-97 ms frame gone, the 30-37 ms left the host's win card; empty Insane idle ~8.6, play 9.6, p95 13 -> 11.5, the 28-33 ms hitches gone; Easy play 11.1 -> 10.2-10.5, p95 14 -> 11.7; native GL harness solve 9.4 -> 7.3, wrong 7.8 -> 6.2, Easy leaf-by-leaf 7.9 -> 6.7; draw calls unchanged; pixel-identical at rest); 5-7 page band-aware tutorial played by a real, quietened board (`Garden`) on hand-made 4x3 gardens walked as a snake: leaf 1 pressed and the garden walked and solved into the butterfly, the last leaf and a leaf out of turn refused (Easy-Hard), a fence refused and walked round (Medium on), a wrong turn dragged back over the body, a stranding step (Hard) or a step off the one walk (Insane) costing a heart and scooting back, Peckish's tummy emptying, refusing a bare square and refilling on a leaf (Insane), Undo and Reset (Reset alone on Insane), the bulb (bands with hints); undo/hint/reset/? already there (no Check by design; no Undo or hints on Insane by design) |
| 22 | sunbeam | 2026-10-02 | every piece was drawn in script on every frame anything moved, a held piece included (live 3.2-6 ms a frame on Insane), the air (sun, motes, pulses, glints, bud) ~1 ms every idle frame, and the win card's relayout made the whole greenhouse again (11-18 ms): now cups, mirrors (the sheen its own look), drops, glows, sparks and rings are looks in rooms of their own (`_lay_rooms`), the beam capless strips plus cap looks on the cups' mesh, the air looks too, the frame, floor, rails, pots and window made once in a reference layout and drawn under `_relay()` (only the glass made again on the win card; glass and bed joined while the relay is the identity), the streak's digits warmed at open (drag frames' script ~0.8 ms; native GL Insane play 8.15 -> 4.3 ms, idle 4.37 -> 3.85, Hard play max 17 -> 10, Insane max 21 -> 13; +2 draw calls; pixel-identical at rest); the probe drags every piece home on a dark way (BFS, no sleeper woken), the old greedy order ran Insane out of hearts and its 43-60 ms "spike" was the host's out-of-hearts card; 4-6 page band-aware tutorial played by a real, quietened board (`Floor`) on hand-made 5x4 and 5x3 floors: a mirror slid into the light turning it into the bud, the bud reached with a drop dry and then the light swung over it (Easy-Hard), a cup sending the light back one lane over, a held piece's light on a snail a free peek and a let-go one waking it for a heart (Hard), Shy Dew's drops drying for a heart and then every drop lit at once (Insane), Undo and Reset (Reset alone on Insane), the bulb (bands with hints); the hearts hang beside the floor on the page (`_inset()`, `_heart_row()`, `_hearts_at()`); undo/hint/reset/? already there (no Check by design; no Undo or hints on Insane by design) |
| 23 | knight | 2026-10-02 | every piece, bramble, hoofprint and mark was drawn in script on every frame anything moved -- and on Brambles a napping rose knight keeps the board moving, so a late Insane board built ~20k vertices a frame, 8-22 ms: now the pieces are looks made once at a reference cell (a knight per side and eye -- open, blink, joy, dizzy --, the king per fallen/crowned/dozing, the crown, a shadow painted per alpha) put under the affine map Piece.knight/king already used (foot, squash, lean, cell size), brambles a look per square scaled as they grow, hoofprints a look per hop direction and age, marks a look per kind; the ground (brambles or trail, and the marks) is its own mesh handed back while what it shows is unchanged, so a napper's breath rebuilds only the pieces (builds ~1-2 ms ground, ~0.5-0.9 ms pieces; same-conditions full Insane idle 10.3 -> 8.6 ms, p95 15.3 -> 9.1, max 32 -> 13, play 12.5 -> 8.8, p95 15.3 -> 9.1; empty Insane play 9.4 -> 8.8, max 16.5 -> 13.4, now on the frame-pacing floor; +1 draw call; pixel-identical at rest but for sub-pixel AA on an ear tip and an eye); the frame and squares kept across the win card's relayout and drawn scaled (3-4 ms a rebuild; the table, which covers the card, is still made again, ~4 ms); a curled-up nap cat now follows the frame onto the win card (she was left over its buttons); 5-7 page band-aware tutorial played by a real, quietened board (`Board`) on hand-made 5x5 positions checked against `Gen.step`: a dot tapped and the hop in an L, then the king; a hop into rose corners caught (a heart on Hard/Insane) and slid back, a safe hop the rose knight answers, then the king; a rose knight in a green ring taken; Brambles: a bramble on the square left and a guard boxed in by its king and its friend napping (Insane); a hop into the corner leaving no way to the king and Start over beside the board tapped (Easy-Hard), or boxed in for a heart and the brambles withering back (Insane), then the way that works; Undo and Reset (Reset alone on Insane), the bulb (bands with hints); the hearts hang beside the board, or over Start over in a side column; undo/hint/reset/? already there (no Check by design; no Undo or hints on Insane by design) |
| 24 | hedgehogs | 2026-10-02 | the still lawn was cut into bands of three rows rebuilt whole in script whenever one cell's look changed, ~17 ms a band on Insane (78k vertices for the four) -- and a breeze or a gust settles its cells a frame apart, so one row's rustle rebuilt its band at the start and again as each cell settled (the idle 25-48 ms spikes), a rustling row drew its piles live (~3 ms a frame) and the win card's relayout made all four bands again (~30 ms): now every cell's ground (covered, raked, woken), its pile as it rests, pressed under a flag, and its mound and rim alone, the flag (painted through slots), a pin and the paw prints are looks made once at a reference cell, and each leaf kind a look painted its colour and midrib's, put by `RunMesh` -- a band's cells into runs of their own as long as ground and pile, its flags, pins and paws on the tail (none reaches a neighbour, so nothing changes pixel), a moving pile its look under the moment's squash, a rustle its mound-and-rim look and the top leaves lifted one look each, a gust's and the win swirl's flying leaves one look each, the moving cells put latest-settling first so a cell that settles or starts to blow moves no look before it; bands and live mesh built in the reference layout's space and drawn under `_relay()` (only the lawn made again on the win card, ~1.7 ms); `RunMesh` now reads a shape's colour runs only when it is first painted (a band ~1.5 ms; a rustling row ~0.7-1 ms; native GL Insane play 6.6-6.9 -> 5.2 ms, p95 9.1 -> 5.6-6.1, max 19-31 -> 11-14, idle max 6-12 -> 6-8; full Insane play max 37-39 -> 13-22; Easy play 6.2 -> 5.0, p95 8.3 -> 5.6; ANGLE idle unchanged at ~9.8 ms with its max 25-48 -> 12-13 and play p95 14 -> 11.7, but play mean +0.5 ms as its render-cpu rose 6.6 -> 8.0 -- Sunbeam's ANGLE swing; draw calls unchanged; pixel-identical at rest); the streak's digits warmed at open; a curled nap cat follows the bed onto the win card; 6-page band-aware tutorial played by a real, quietened board (`Board`) on one hand-made 5x4 lawn checked against the state (a search found it): a pile raked shows its 2 and a blank one blows its neighbours clear, a 1 touching one pile and the pile held for a flag and a 2 touching two, a 2 with its flags tapped raking the rest round it and a 1 after it, a guess between two piles waking a hedgehog (a heart on Hard/Insane), Sleepwalkers' three rakes lighting the moon and the bell sending the hedgehog under 19 to 18 by the board's own walk (its seed found by searching) with paw prints on both and the numbers still leading (Insane), Undo and Reset (Reset alone on Insane), the bulb pinning a sleeper and raking a pile (bands with hints); the hearts hang beside the bed; undo/hint/check/reset/? already there (no Undo, hints or Check on Insane by design) |
| 25 | slider | 2026-10-02 | every block, the hollows, Homesick's line, the trail and the doors were drawn in script on every frame anything moved -- a drag, a blink, the gaze easing -- ~5 ms and 12.9k vertices a frame on Insane: now `slider_block.gd`'s `block()` is split into its layers (shadow, wood, sheen, carving, face, chevrons; identical output, the menu card unchanged) and the board makes each once as a `RunMesh` look at the drawn cell (shadow and sheen per lift in 16 steps, the face per expression and eye in 8), put under the block's place, lift and twirl, with the floor's moving bits (mat glow, hollows, Homesick's line, trail, rings) a small mesh of their own handed back while unchanged (build ~5 -> ~0.14 ms; native GL Insane play 9.4 -> 4.8 ms, idle 4.1 -> 3.8, full Insane play 6.3 -> 4.4, p95 9.7 -> 5.0, max 19-28 -> 7; ANGLE Insane play 11.4 -> 8.0-8.4; Easy play 9.3 -> 5.1 and its 55 ms spike gone; +1 draw call; pixel-identical at rest but for sub-pixel AA); the probe drags the solver's line through the board's input a cell a step; 4-5 page band-aware tutorial played by a real, quietened board (`Board`, count line left of the tray and hearts right of it) on hand-made trays checked against the solver: two squares slid aside and the red block down and out of the gate, squares taken round corners in one drag each (the count says one move), Hard's bar held under the gate (the red block sweats) and let go for a heart and a slide back, then the way out, Homesick's head shake and a cell down too soon stranding it for a heart (a real tray ten moves from home: no nearer dead end exists) then the solver's next move, Undo and Reset (Reset alone on Insane), the bulb three times to the gate (bands with hints); undo/hint/reset/? already there (no Check by design; no Undo or hints on Insane by design) |
| 26 | marigold | 2026-10-02 | every bud strip a seed brushed past was drawn in script whole on every frame it shivered (~3.7 ms a strip, ~22 ms all six, 50k vertices on Insane), and the blooms (breathing through a shot), the ribbons (3.5 ms a bloom on Sweethearts), the bits, the ripples, the frog and ducks, the full bloom's pots and the band's pips (a whole bloom a pip, ~8 ms by the end of a garden) were drawn live: buds, blooms (an opening step each, a fade step each), ribbons (a pair and style each), the garden's pieces and the pots are RunMesh looks made once at the reference scale, a layer a RunMesh sharing the shapes (strips at rest by code, moving buds apart); bits and ripples a mesh a kind of copies with tiled indices; looks primed one a frame after the entrance (native GL Insane play 9.1 -> 4.9 ms, p95 14.2 -> 7.1, max 28-57 -> 13-15; ANGLE 11.7 -> 9.5, p95 18.5 -> 13.3; draws 83 -> 88 at rest, peak 214 -> 208); Undo on every band (the last shot taken back; a heart on Hard and Insane, as Reset, grey at one heart); a 7-page band-aware tutorial played by a real, quietened board on hand-made rows, every shot an exact angle found by `tests/_mg_tut_search.gd` |
| 27 | pixelgarden | 2026-10-03 | every bead on the board was drawn in script by `Bead.bead` on every frame it moved -- and the win wave moves all 256 at once (27-38 ms a frame for 2.3 s on Insane, the table and its 256 pegs, 27k vertices, also made again on every frame of the bare pegs' fade), a plate's iron moves 64 -- and the head (the box with every bead left in it, 14k vertices) was made again on every bead seated and every frame the tweezers or bar moved (5-10 ms): now a bead, a bare peg and a box bead are each a `Kit` of looks sharing one topology (`puzzles/pixel_garden_looks.gd`: Bead.bead's drawing with every part always drawn and every ellipse a fixed point count, its fuse, shine, fade and shade in steps, the shade split off so a lifted bead leaves it on the board), and every layer is copies -- looks transformed and appended natively, one copy's indices tiled n times once and sliced -- so nothing is offset in script; the bead kit is made at a reference cell and drawn scaled; the bare pegs fade by their mesh's alpha; the head is five layers (under the heaps, the chosen compartment lit, the heaps -- each compartment's whole heap laid out once and a slice of it shown --, the lips and labels, and the tweezers, hearts and bar), each made only when it changes; the pattern card is made about its own corner, so the win card's relayout moves it (relayout ~25 -> ~7 ms); the tiled indices grow a few copies a frame after the entrance (native GL Insane play 8.4 -> 4.6-6.1 ms, p95 11.4 -> 5-7, max 17-26 -> 6-10; full Insane through the win 9.0 -> 5.8, p95 28 -> 7.6, max 50-55 -> 9; ANGLE full Insane play 13.9 -> ~10, p95 34 -> 11-12, max 55 -> 16-18, idle p95 24 -> 11; draws 92 -> 96 peak, +6 at rest; pixel-identical at rest but for sub-pixel AA); a 6-7 page band-aware tutorial played by a real, quietened board (`Board`, laid out side by side for the short page) on a hand-made 6x6 tulip: a colour picked, a peg tapped and a run dragged, a bead on a wrong peg making its colour run out and lifted back, a plate ironed right and another with a bead astray hopping home (a heart on Hard/Insane), the picture held big, Windblown's turned square matched to its plate by its clip (Insane), Check's halo (Easy/Medium), Undo and Reset, the bulb (bands with hints); undo/hint/check/reset/? already there (no Check on Hard or Insane, no hints on Insane, by design) |
| 28 | drumbeat | 2026-10-03 | the whole song was drawn in script on every frame: the gauge, ticks, star and hearts (0.7 ms every frame), the ring's three strokes, bar lines and marks, each drum's mark and ripple, every firework's trails (2.7-4.4 ms a frame through Go-Go's volley and the finale), and the shared reward layer drew every bit in script (`arcade/rewards.gd`, 1.3-4 ms through a win's rain): now everything that only moves, swells or fades is a `RunMesh` shape copied natively into three meshes (the road's, the top's, the one over the drums), tinted through a slot in 24 steps, a ribbon two round ends and a stretched body, a firework one look a step of its life copied with tiled indices into the sky's mesh, the drums' marks baked into their looks, the reward bits a look a kind copied with tiled indices (a mesh a kind in the air); the song's looks warmed two a frame from the open (native GL Insane through the win 6.08 -> 4.0 ms, p95 9.5 -> 5.5, max 16-25 -> 8-11; the densest song 6.7 -> 4.4, p95 10.6 -> 5.9, max 20 -> 11; script a frame 1.3-4.2 -> 0.3-0.8 ms; draws 94 -> 93 at rest, 115 -> 117 mean, peak 263 -> 266; ANGLE unchanged inside its swing, 10.0-10.9 -> 10.75); a 5-7 page band-aware tutorial played by a real, quietened board with no stage (strike, drums and twins, ribbons, golden bars and balloons, the gauge and hearts, Echo, the top bar); the song pauses under the ? and the settings; **no Undo** (a note is judged as it passes), Reset in the top bar on every level |
| 29 | trestle | 2026-10-03 | the bridge was drawn in script on every frame of a test (every member's strokes, seams and rope ticks, every bolt and pin: 4.0 ms a frame on Insane's 37 members), the front layer on every idle frame (the water's face, glints, the troll's ledge, the cups, the hearts' sign: 1.3 ms on an empty board, 2.0 with the bunting up), and the still scene and sky were built again on every relayout (5.6 ms): now every member is a `RunMesh` look a material and a length, put turned and stretched to where it is and painted by its load in 24 steps, the front and the budget bar are looks under transforms (the water a strip of vertices, the tea four), the hung bunting and the sag line are one look each (`RunMesh.forget`), the load tags and the reach dots are kept, and the still scene is drawn shifted while the win card only slides it up (bridge 4.0 -> 0.38 ms a frame of a test, front 1.3 -> 0.35 idle; native GL Insane idle 4.70 -> 3.68 ms, a full bridge standing 7.39 -> 4.00, build+test+win mean 7.43 -> 4.57, p95 10.0 -> 6.1, max 57 -> 12-14; ANGLE play 10.9 -> 8.4, p95 15.6 -> 9.9, max 71 -> 22-35; 92 draw calls as they were). The solve's 30-65 ms frame was the strip lettering a "★" (not in the game's fonts: 12.6 ms of fallback hunt) -- the stars are drawn, the words warmed. Shared: `arcade/rewards.gd` letters a sticker a pass at a time (the win's 366 draw calls -> 127, every board's stickers), `RunMesh.forget`, the host releases the clock whenever the tutorial card leaves the tree. The sim's substeps run on locals (16% less a step; every banked proof gives the same joints and peaks, bank re-proved 122 of 122). A 5-7 page band-aware tutorial played by a real, quietened board on hand-made three-step gaps with its own Go to press (build and Go, triangles and loads, chips and budget, rope, hearts, the Tea Party, Undo and Reset, the bulb) in three languages; a running test waits while the ? or the settings are up; Undo in the top bar and Reset beside Go were already on every level |
| 30 | minigolf | 2026-10-05 | built to the checkup's rules rather than passed through it: the lawn, the hole at rest and the pips are cached meshes (a hole is built once and moved by transform as the next slides in), and only a few hundred vertices of ball, flag, aim and gates are made a frame; 85-97 draw calls playing, ~115 at the win, on both drivers; 3-7 page tutorial (the board on hand-made holes, putts from `tests/_gf_tut_search.gd`); no Undo on any band (a stroke played is on the card), Reset is the course from the first tee, the bulb on Easy to Hard |
| 31 | horse | 2026-10-08 | built to the checkup's rules rather than passed through it: every drawing is a unit mesh under a transform baked with `Face.FlatBuilder` (the meadow and its water a layout, the wheat only while the reach changes, the bales and the win's flowers only while they move), the horse and the bees a layer of their own; 76-103 draw calls on both drivers, one 34 ms frame as the win begins; 4-7 page tutorial (the board on hand-made meadows); Undo and the bulb on Easy to Hard, neither on Insane, Submit on every band (it is the ending), Reset the bare field |
| 32 | how_big | 2026-10-08 | built to the checkup's rules rather than passed through it: `_still` a layout, `_live` (both silhouettes, the brackets, the grip, the truth) rebuilt only on a frame the finger moves or something animates -- a silhouette is redrawn at its size, not scaled, so its feather stays 1.5 px -- and the pills, captions, result card and seal a layer of their own; 81-118 draw calls on both drivers; 4-5 page tutorial (the board itself on hand-picked pairs, drawn at 0.58: `ui/hud/how_big_tutorial_diagram.gd`); the bulb on Easy to Hard (which way the truth lies), no Undo on any band (a lock is final), Lock then Next on the Check button, Reset the round's starting size and nothing after a lock |
| 33 | acorn | 2026-10-08 | built to the checkup's rules rather than passed through it: `_still` a layout (the card and the question's paper), `_live` (the four plates, their letters' discs, ticks and crosses) rebuilt only on a frame something moves, and the words (pills, subject, question, answers, why, seal, toast) a layer of their own, the words on a plate under one transform a plate; 80-114 draw calls on both drivers; 4 page tutorial (the board itself on two hand-written questions, drawn at about 0.4: `ui/hud/acorn_tutorial_diagram.gd`); the bulb on Easy to Hard (two wrong answers off the card), no Undo on any band (a lock is final), Lock then Next then Finish on the Check button, Reset has nothing to give (`can_reset()` false); the first board whose deal waits on the backend, so every harness waits for the deal; `tests/_win.gd -- acorn` 1/1 |
| 34 | pearl | 2026-10-09 | built to the checkup's rules rather than passed through it: `_still` a layout (the card, the paper, the water with its sand, shell and bubbles, the clock's track), `_live` (the clock's bar, the line the answer is typed on, the marks down the water, the rope and the bell) rebuilt on every frame the clock runs and otherwise only when something moves, and the words (pills, clock, prompt, typed line, what the answer came to, seal, toast) a layer of their own; 88-114 draw calls with the keyboard's two; 4 page tutorial (the board itself on one hand-written prompt, typing by itself, drawn at about 0.4: `ui/hud/pearl_tutorial_diagram.gd`); the bulb on Easy to Hard (the Pearl's first letter and its length), no Undo, no Check and no actions row (Enter is every move), Reset has nothing to give (`can_reset()` false); deals a frame after it opens, as Golden Acorn does, so every harness waits for the deal |

Since Knight (2026-10-02): **a piece drawn through an affine map is a look
under that map.** Knight's `Piece.knight` and `Piece.king` already drew every
point as `foot + ((p - FOOT) * flip * squash * size).rotated(tilt)`, so a look
made once at a reference cell, looking one way, is the piece in any pose under
one Transform2D (a negative x-scale is the turn to look the other way; strokes
thicken with a squash by under a pixel). Only what the map cannot hold stays
live: a fading knight (the taken one's tumble), a withering bramble, marks
mid-fade. **An idle animation that never stops** (Knight's nappers breathing,
forever on Insane) keeps a board rebuilding on every frame, so split off what
it does not touch: the ground hands its mesh back while its key (layout,
route, brambles, foes, legal squares) holds. And a node the board places once
(the nap cat, curled) must be placed again on a relayout, or the win card's
smaller board leaves it behind.

Since Hedgehogs (2026-10-02): **a board that settles its cells a frame
apart rebuilds its rest mesh a frame apart.** Hedgehogs' bands were already
rebuilt only when a cell's look changed, but a breeze or a gust touches a row
of cells that each settle on their own clock, so one rustle rebuilt a 17 ms
band once per cell; nothing about the band split could fix that, only making
a rebuild cheap (a band of looks in runs, ~1.5 ms). **A drawing whose parts
move apart is a look per part kind**: a pile at rest is one look per cell
(hashed, exact), but a rustling pile is its mound-and-rim look plus each top
leaf a leaf-kind look under its own place, turn, length and flip, and a gust
is seven leaf looks a pile -- three leaf looks serve every pile, painted
through two slots (leaf, midrib). **Reserve runs only for what every piece
wears**: marks only a few wear (flags, paw prints) go on the tail after the
runs when they never reach a neighbour, which keeps the paint order's result
(Hedgehogs' bands 149k -> 99k reserved vertices). On one tail, **order the
moving pieces by when they settle**, latest first: a piece that ends or
changes size then shifts nothing put before it. `RunMesh` reads a shape's
colour runs only when it is first painted, so a look only ever put in its own
colours skips a script pass over its vertices. The probe gains `lang=<code>`
to read a tutorial's pages in each language.

Since Marigold (2026-10-02): **one RunMesh building every layer shares one
cache of offset indices, and that cache is cleared past `OFFSETS_MAX`** --
the frame after, every layer offsets all its indices again in script (4-7
ms, at no particular moment). Give each layer its own RunMesh sharing the
shapes (`share_shapes`; Marigold's `_layer(name)`), and keep each layer's
places steady: blooms put in the order they bloomed with the ones still
opening last (a look that changes size moves every later one). **A painted
stroke is a script pass a colour**: its colour runs alternate along it, so
`ink()` walks every vertex, and a fading ripple was a new colour every frame
-- bake the colour and fade into the look's id instead (Marigold's ripples,
6 inks x 16 steps). **Many copies of looks sharing one topology need no
offsets at all**: a mesh of their transformed vertices with the look's
indices tiled for n copies once (`_tiled_for`), sliced natively --
Marigold's bits (a mesh a kind) and ripples (one point count for every
step). **Warming big lettering out of sight can cost more than it saves**: a
sticker hops in a letter at a time, so its glyphs rasterise over several
frames (4-7 ms at worst), while drawing the whole word at once with both
rims cost 20-26 ms a word. And **a chaotic board's tutorial plays exact
angles**: Marigold's dense rows make no run of angles giving one shot wider
than ~0.01 rad, so each lesson's shot was searched offline and is played at
its angle, with the pot put in one place as the seed leaves (a seed off its
rim can fly back into the buds); the fixed-step physics repeats it exactly.

Since Pixel Garden (2026-10-03): **copies of looks that share one topology
need no offsets and no runs.** A drawing whose looks differ only in colour
and in where its points sit (a bead fusing: the hole closes, a gloss comes
up; a shine; a fade) can be made with every part always drawn (a part that
is gone at alpha 0) and every ellipse a fixed number of points, so all its
looks have one vertex count and one index list. Then any number of copies
is one native transform-and-append a copy and one copy's indices tiled n
times, made once and sliced (`Kit`/`Copies` in
`puzzles/pixel_garden_looks.gd`, Marigold's `_tiled_for` grown into a
kit): no `RunMesh` rooms reserved and uploaded, no index offsets in script
when a piece changes size -- Pixel Garden's win wave, 256 beads each a new
look every frame, went from 27-38 ms to under 10. A part that must not move
with the rest (a bead's shade while it lifts) is split off the look and put
under its own transform. Grow the tiled indices a few copies a frame after
the entrance, so the first frame that moves everything finds them made. **A
prefix of a still layer is a slice**: a heap shown as its first `left`
beads is its whole heap laid out once and `slice(0, left * count)` of the
vertices. **A fade that is the same for a whole layer is the mesh's
alpha** (the bare pegs at the win), never a rebuild. **A drawing whose size
never changes but whose place does** (the pattern card) is made about its
own corner and drawn under a translation, so a relayout only moves it. And
**a tutorial board must keep drawing through its entrance**: a page that
deals the board and waits before its first tap drew one frame before the
pop and nothing after (the Windblown page was blank for six seconds) --
`_busy_for` the entrance when dealing.

Since Drumbeat (2026-10-03): **under ANGLE on this Mac a draw call costs
~77 us and script savings do not show**, so a rewrite that trades script for
draw calls reads *slower* there (Drumbeat's first pass turned each cached
look into its own `draw_mesh` with a tint: native GL 6.1 -> 4.0 ms, ANGLE
10.4 -> 11.2 with 13 more draw calls). The looks went back into meshes
copied natively -- **a look that needs a tint is a slot-coloured shape
painted with the tint cut into steps** (`_q`, 24 steps: the painted colours
are found again instead of filling `RunMesh`'s cache with a colour a frame)
-- and the draw calls came back to the old count with the script still gone.
Take the first ANGLE reading with a second: Drumbeat's baseline read 8.5,
then 10.9 and 10.0. **A board that redraws every frame anyway needs no rest
mesh, only cheap frames**: three RunMeshes with no rooms, the steady shapes
put first so their places (and offset indices) hold, the comers and goers
last. **A shape that changes with one number that moves rarely is a shape an
id of that number** (the gauge's fill, a shape a half-pixel of width, made on
a hit and found on every frame between). **A stretch needs a look feathered
along its sides only**: a rectangle's feather stretched with it (a ribbon's
body ran 900 px past its ends); a capless stroke a pixel long is the body,
round ends put over it. **A firework is a look a step of its life**: its
trails' lengths and widths divided by how far it has opened, so one
transform opens it, with its colours a slot each and one index list tiled.
**The shared reward bits** are copies too (`Rewards._draw_bits`): a look a
kind at size 1, a mesh a kind, the fade in 16 steps. **Assigning into a
packed array reached through a cast or an Array's element changes a copy**
(`(arrays[k] as PackedColorArray).append_array(...)` did nothing): take it
into a typed local, change it, and put it back. **A real-time board pauses
on the edge of `clock_held`, never while it is held**: a harness that frees
the tutorial card leaves the clock held, and the board paused again on every
frame (the probes now release it). The host holds the clock while the
settings are up too. And **a tutorial board for a real-time game is the
board with its stage taken off** (`_staged()` false: the road and the drums
alone, 588 units tall for 1000 wide), running a hand-made chart on the
microsecond clock with a finger a drum striking through the board's own
strokes; a still page (reduce motion) is the song held at a moment
(`freeze`).

Since Trestle (2026-10-03), the last row: **a character the game's fonts
lack is a hitch the first time it is lettered** -- Trestle's solved strip
drew its stars as "★" in a string, and the text server's hunt for a fallback
font was 12.6 ms inside the solve's frame (the win card's subtitle carried
them too); draw such a mark as a shape. **Lettering goes a pass at a time**:
`Rewards._draw_stickers` drew each letter's shadow, two rims and face in
turn, and each pass's glyphs live in their own atlas, so every letter was
four draw calls (Trestle's win, five stickers up, 300); every letter's
shadow, then every rim, then every face, is four a sticker. A board whose
pieces are **segments between moving points** (a truss member, a rope, a
cord) is a look made lying along x at its rest length, put with its x axis
along the segment (stretched to the length it has now) and its y axis the
side that should be lit, the load or fade painted through slots in steps
(`_put_member`, `_load_inks`); a pennant's swinging tip is a shear of its
look, a pole growing a scale of it. A look that changes now and then (the
sag line after a test, the bunting once hung) is one shape made again on
`RunMesh.forget(id)`, in a space of its own (grid points at the reference
step) under one transform, so a relayout makes nothing. Things that come and
go inside a mesh put together every frame are **put always** (a glint clear
while it is out, a drop at no size), or everything after them lands on a new
place and its indices are offset in script. **A `Vector3` keeps 32-bit
floats**: a "built for this size" key held in one never equalled the 64-bit
step it was compared with, and the still scene was built on every frame
(5.6 ms) until the key became plain floats -- compare a cached build's key
in the types it was made from, and time the frame after adding a cache. A
tutorial board in a short wide slot wants **layout hooks, not a second
drawing**: Trestle's `_view()` (the rows shown), `_strip_shown()`,
`_scene_top()`, `_sign_top()`/`_sign_left()` and `_deal(level, band)` let
the page deal a three-step gap at 100 px a step; a board whose Check is the
host's button gets a drawn one on the page for the finger to press. And the
sim that a bank was proved on can still be made cheaper **if the arithmetic
and its order stay exactly the same**: hash every joint and peak of every
banked proof before and after (`_probe_trestle_bank.gd` then re-proves it).
The probe's frame split (`x=tr_win`: the nodes' process to
`frame_pre_draw`, the draw to `frame_post_draw`, the rest) is what found
both the "★" and the still scene; `Performance.TIME_PROCESS` only moves
once a second and says nothing about one frame.

**The checkup is complete**: all twenty-nine rows are dated. "Next game on
the list" now means the first row again (Binairo), for a second pass.

## The tutorials of the nine games off the registry (2026-10-04)

The user asked that every game have "a proper tutorial and HUD UI buttons
pattern". A headless walk of the registry (every board, every level) found
the twenty-nine boards whole: the ? showing, 3-7 pages each, Reset on the
bar or the actions row at every level. The **Versus and Arcade screens**
were not: they wear `FlatTopBar`, whose ? is always showing, and nothing
was connected to it; no card on a first play; no How to play in their
settings.

- **`ui/hud/screen_tutor.gd`** is the host's part for a screen that is its
  own host: `tutor = ScreenTutor.new(self, puzzle_id(), "Title", hold)` then
  `tutor.wire(top_bar, settings_sheet)`. It mounts the boards' own card
  (`ui/hud/how_to_play.gd`) over the screen for the ?, for the settings'
  How to play (`SettingsSheet.with_rules`, shown without New puzzle) and for
  the first play. **Only `ui/menu.gd` asks for the first play's card**
  (`screen.tutor.first_play()` in `_open_versus`/`_open_arcade`); a harness
  that opens a screen through the menu sets `ScreenTutor.no_first_play`, or
  the card stands over the run and takes its clicks (thirteen harnesses do).
  `go_back()` closes the card first. `hold` is called as the card goes up
  and as it leaves: a run with a clock is paused and left paused, a tap from
  going on (Firefly, Molehill, Stackwood, Peapod); the Versus screens hold
  the computer's answer (`_held`: no move played or heard behind a page).
- **The pages are the screen's `tutorial_pages()`**, a diagram a game in
  `ui/hud/<game>_tutorial_diagram.gd`, each played by the real thing on a
  hand-made position: the Versus diagrams hold the board node quietened by a
  subclass (chess, checkers: a clipped window four or five ranks deep;
  snooker: the top end of the table, its referee judging each shot), the
  Arcade diagrams a quiet subclass of the screen with only its field (and
  the plates or tool row a lesson needs) over a subclass of the sim with a
  hand-laid deal. A finger goes through the screen's own input. The screens
  gained small hooks for it and nothing else: `_build_frame`/`_build_field`
  lifted out of `_build`, `_unit`/`_fit` for the slice shown, `_rows()`,
  `_cols()`, `_hill_count()`; Stackwood's sim takes its width and height
  (`wide`, `high`, the constants by default: the bot probe prints the same
  run on two seeds before and after).
- Text is `TUT_<GAME>_*` in `locale/ui.csv`, en/pt/es. Name the settings
  sheet as its own title does (`SETTINGS_TITLE`: Configurações, Ajustes).
- `tests/_shot_howto_screen.gd -- <game> <outdir> [lang=] [level=] [secs=]
  [every=] [reduce]` shoots any of the nine screens' pages as they play and
  prints body lines against the room (`OVERFLOWS`) and draw calls; the card
  is freed, not continued, so the progress file is not marked.
- **A second locale key of the same name wins or loses by load order**:
  Peapod wore Paper Planes' motto (`PP_MOTTO` in both `ui.csv` and
  `boards.csv`; Peapod's is `PEAPOD_MOTTO` now) and a Henhouse leftover
  shadowed Hedgehogs' `HH_MOTTO`. A new game's prefix is checked against
  both files.

| Game | Pages | What they play |
|---|---|---|
| snooker | 7 | aim, draw back, let go; a red then a colour (the referee's own verdicts); what each ball is worth; two fouls; the spin pad; the bulb's gold line and notch; the buttons |
| chess | 7 | tap or drag; rook, bishop, queen; knight, king, pawn; check and mate; castling, en passant, promotion; stalemate and the draws; Undo, bulb, Reset |
| checkers | 6 | a step; a jump, backwards too; taking is a must, the most first; the crown and the flying king; how it ends; Undo, Reset, bulb |
| hockey | 5 | a finger leads the mallet, up to the line; a swing into the far slot; a still mallet stops it, a moving one sends it back; off a long rail when the way is shut; two players (built with the game, 2026-10-08) |
| firefly | 7 | slide and hold; the swarm's worth; dives and seeds; a moth's escorts; the silk beam and the rescue; the flyby; lanterns and buttons |
| molehill | 7 | a whack and the quick bonus; gold and flowerpots; the rabbit; the streak; the last ten seconds; boosters; the buttons |
| stackwood | 7 | slide and let go; merges; chains; the line; acorns and the rainbow block; zap and bomb; the bar and boosters |
| thirteen | 6 | a chain; the last one grows; the 13; a stuck tray and Swap; the five tools and their climbing prices; Restart and boosters |
| posy | 7 | a swap; the day's goals and spare moves; the four specials; weeds, stones, moss; out of moves and the +5; the tools; buttons and boosters |
| peapod | 8 | the cart; numbers, paints and the line; the frost and the shove, had as their crates break (nothing is caught since 2026-10-05); the five pods; the shop's four cards (a list, like the last page); golden, iron, firecracker; the millipede; boosters and buttons |

None is level-aware: Versus levels change only how well the computer plays,
and the Arcade has none. Draw calls with a page up: 140-230 a frame.

**The buttons, fixed on the way**: Undo and the bulb showed on Firefly,
Molehill, Stackwood, Lucky Thirteen and Posy while the boost card stood
before a run (the bar was first refreshed by `_new_game`; `_ready` does it
now); Firefly's Reset greys while there is no run; chess and checkers grey
Reset while a move is in the air (`can_reset()`) and a second press of the
bulb shows the same hint again and spends nothing (`_hint_move`); the
bulb's badge keeps its count while the bulb waits its turn (`hints_held()`,
read by `FlatTopBar.refresh`); Lucky Thirteen's stuck card steps aside while
a tool is armed (it stood over the pebbles Swap, Pluck and Lift are used
on); the snooker table's balls-on rings stand still under reduce motion.
**Left as they are**: a new Stackwood block always appears over the middle
column (`_next_piece` reads `piece.col` after the piece is cleared, so "keep
the last column" never runs); the first play's card opens over the boost
card when one is due, and Continue leaves the boost card; none of the nine
was heard, felt or run on a phone or under `opengl3_angle`.
