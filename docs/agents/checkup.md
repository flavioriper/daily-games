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
(Queens and Untangle fixed with a `-INF` sentinel; Pinwheel, Paper Planes
and Quilt still carry the test).
Since Hidden Word (2026-10-02): a Button with its own StyleBoxFlat and text
costs two draw calls (the box is a polygon, the text a glyph batch); a tray
of them is the lever, not the board. `ui/flat/key_board.gd` keeps its
Buttons for input and motion, blanks their styles and text, and paints
them all from one `Paint` child (faces as one mesh of cached looks under each
Button's transform, then every letter) -- the pattern for Sudoku's
`digit_pad.gd` and any other tray of Buttons. A tutorial page can hold the
real tray too, scaled, with its chips set to ignore the mouse and the finger
firing them (`button_down`, then `button_up` and `pressed`).

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
| 12 | wordtrail | | |
| 13 | mushroom | | |
| 14 | sudoku | | |
| 15 | bridges | | |
| 16 | quilt | | |
| 17 | fairylights | | |
| 18 | planes | | |
| 19 | pinwheel | | |
| 20 | rings | | |
| 21 | caterpillar | | |
| 22 | sunbeam | | |
| 23 | knight | | |
| 24 | hedgehogs | | |
| 25 | slider | | |
| 26 | marigold | | |
| 27 | pixelgarden | | |
| 28 | drumbeat | | |
| 29 | trestle | | |
