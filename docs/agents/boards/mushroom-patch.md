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
