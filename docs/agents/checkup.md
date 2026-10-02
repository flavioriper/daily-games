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
| 23 | knight | | |
| 24 | hedgehogs | | |
| 25 | slider | | |
| 26 | marigold | | |
| 27 | pixelgarden | | |
| 28 | drumbeat | | |
| 29 | trestle | | |
