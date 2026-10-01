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

| # | Board | Done | Notes |
|---|---|---|---|
| 1 | binairo | 2026-10-01 | MultiMesh coins and faces (391 -> 147 draws full Insane); 5-page tutorial; Undo on Insane |
| 2 | mastermind (Code Break) | 2026-10-01 | played rows baked to one mesh each (300 -> 147 draws full Insane); 4-page tutorial; undo/reset already there |
| 3 | balance | 2026-10-01 | already ~100 draws; the lag was a glyph-rasterising hitch on the first big sticker (solve 27-47 ms frame) -> shared `Rewards.warm()`; 3-6 page tutorial; Undo on Insane |
| 4 | untangle | 2026-10-01 | resting pegs baked to one mesh (Insane idle 130 -> 95 draws, ~10.8 -> ~8.4 ms); carrying 16.7 -> 11.9 ms (rope mesh writer, crossings kept per pair, binds only when changed); shared `Face.Builder` stroke/fan/feather and `Scenery.soft_disc` write whole arrays; 3-5 page tutorial; undo/reset/hint already there |
| 5 | shikaku | | |
| 6 | tents | | |
| 7 | lightup | | |
| 8 | oneline | | |
| 9 | nonogram | | |
| 10 | queens | | |
| 11 | hiddenword | | |
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
