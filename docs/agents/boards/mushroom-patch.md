# Mushroom Patch

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Mushroom Patch is the thirteenth board, and the first that was added
  rather than swapped in** (2026-09-20, `puzzles/mushroom2d.gd`, spec
  `2026-09-20-mushroom-patch-flat-design.md`, mock
  `docs/brainstorm/concepts.html#mushroom`). Every number counts the
  mushrooms in the eight cells touching it; plant a mushroom where you have
  proved one is, lay a pebble where you have proved one is not, and the
  patch is done when the last mushroom is planted. **Nothing is revealed by
  a tap and nothing can be lost**, and no board needs a guess: the generator
  carves each one backwards out of a full field and its solver proves it by
  logic alone before it is handed over. Queens, Hidden Word and Word Trail
  each took a `soon` card's slot; this one took no slot, which is what put
  the first screen back on a pager -- see "The first screen" above. Its
  signature is the **count wash**, a running feedback no other flat board
  gives: a number turns the moment its count is satisfied, so the board
  answers a move without being asked to check, and `docs/art/flat-motion.md`
  is where that is recorded. It needed nothing new from `core/motion.gd`.
  **Its title is the widest in the game**: `Mushroom Patch` measures 635 in
  Fredoka 700 at GameWordmark's 84 against a four-button block of 496, where
  Hidden Word's 482 was the widest that had ever fitted, so it is the first
  *title* on a four-button bar to be lettered smaller. It lands at 65,
  through the bar's own fit (the bullet below) and at no cost to the board.
- **The polish pass** (2026-09-30, spec
  `2026-09-30-mushroom-polish-design.md`) made Hard and Insane losable and
  gave Insane a rule of its own. Hard and Insane judge every mushroom as she
  lands (`State.HEARTS` 3 and 2): a wrong one worries, splits a heart,
  wilts back into the soil and leaves a pebble on a rose halo for good
  (`state.reveal`, `shown`, out of every history entry; `_settle`'s `quiet`
  lets the wilt own that cell's moment while the count wash still reads
  it). Pebbles are never judged, and Check there only *counts* pebbles on
  mushrooms (pointing would hand a mushroom over). Out of hearts is Queens'
  dusk and `out_of_hearts.gd` card with `MP_OUT_*`. Hints are 3/3/1/0.
  **Insane is Fairy Rings**: half the turned cells count the sixteen cells
  two steps out instead of the eight touching (`Gen.ring`, `state.rings`,
  `state.reach`), drawn inside a ring of little violet caps that grow in
  after the entrance and glow gold at the party. Its fields are carved
  twice -- the subsets solver, then a deep one that may suppose a cell and
  follow it to a contradiction (`Gen.solve`, `_propagate`) -- and **banked**
  (`content/insane/mushroom.json`, `tools/insane/mushroom_ladder.gd`, 240
  fields needing 13 to 29 suppositions). The phone trusts a banked field
  after checking its numbers against its mushrooms: the deep re-proof is
  72 ms on the Mac. Easy to Hard deal the very fields they dealt before
  (0 of 120 seeds differ). Pressing any number lights what it counts
  (`_reach`), which replaced the old refusal on a turned cell. Rewards: a
  streak up the pentatonic with the x3 bubble and confetti, three gags
  (hearts, a twirl, a sneeze of spores), a flower on every *finished*
  number (all it counts marked, its count holding: `state.finished`, read
  off the player's marks), and a party (meadow, dance, a line of mushroom
  wisdom, the seal; the night seal on Insane). `tests/_shot_mushroom.gd`
  drives every scenario; peaks 81 to 147 draw calls on `opengl3_angle`.
- **The board checkup** (2026-10-02, `docs/agents/checkup.md` row 13). The
  floor and the ground are put together by two `ui/flat/run_mesh.gd`s
  (`_frm`, `_grm`) from shapes made at the first layout's cell (`_ref`) and
  drawn scaled after a smaller one (the win card): `_floor_shape` (bed, sod,
  each cell's tuft, each ring grown) into one run per cell (`_lay_floor`),
  `_ground_shape` (square, disc, pebble and its shadow, halo, flower) into
  runs per part in paint order (`_lay_ground`, relaid when `state.shown`
  grows; pebbles leaving go on the tail). A ring's caps are drawn live while
  any is still growing (`_ring_grown`). The mushrooms at rest are one mesh
  (`_bake_caps`, `CapBake`), each hidden by her slot while baked. The
  tutorial (`ui/hud/mushroom_tutorial_diagram.gd`) is the board itself,
  quietened, on a fixed 5x5 of five mushrooms, through the layout hooks
  `_pad()` and `_tally_h()` (no card air, no tally strip on the page), with a
  drawn chip tray the finger taps to switch chips.

### Fairy Rings without suppositions (2026-10-04)

The user, after Nonogram, Sudoku and Queens: "include them both in this new
rules" (Bridges and Mushroom Patch). Easy to Hard were already carved by a
solver that never supposes. Insane's second carve let it suppose a cell and
follow it to a contradiction, and the bank kept fields needing 13 to 29 of
those.

- `Gen.solvable(given, n, k, subsets, rings)` is the only solver; `solve`,
  `deep`, `supposed` and `probes` are gone, and `generate` lost its `deep`
  argument and the second carve. `from_bank(board, true)` re-proves with the
  subsets solver.
- The ladder keeps a field the subsets solver finishes and the plain rules do
  not, with at least `RINGS_MIN` (6) rings left after the carve; the rung is
  the cells without a number. Re-mined: 2719 of 3000 passed, the 240 kept
  show 14 to 19 numbers and 6 to 14 rings, all re-proved. A live ring field
  is 32 ms mean, 55 worst.
- Easy to Hard deal the fields they dealt before. A banked Insane day
  finished earlier restores a different field. No tip mentioned supposing.

- **Insane counts moves** (2026-10-04, `docs/agents/flat-screens.md`,
  "Insane counts moves"). `State.HEARTS` is `[0, 0, 0, 0]`, so `judged()` is
  false on every band: no mushroom wilts, no pebble is laid for the player
  (`reveal` and `shown` stay in the file, never reached) and Check points
  again on Hard. Fairy Rings hands out `mushrooms.size() + 3` moves
  (`State.MOVES_SLACK`, `moves_budget()`; 17 for a field of 14): a mushroom
  planted costs one, one pulled up costs one (`move_cost`), pebbles and
  sweeps are free. `_spend` takes them off in `_tap`; out of moves is the old
  dusk and the card with `MOVES_BONUS`. No Undo, hint or Check on Insane, and
  its tutorial drops the Undo page (it taught Undo and Check) for the shared
  moves page. What stays is what Medium shows from the player's own marks:
  the count wash, the flowers on finished numbers, the streak (a plant that
  sends no number over), `MP_MISPLACED`. The tutorial diagram's HEARTS lesson
  is no longer reached by any band.
