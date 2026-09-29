## Binairo

### Hearts, Insane and the fibbing sign (2026-09-29)

Spec `docs/superpowers/specs/2026-09-29-binairo-insane-polish-design.md`,
section 1, built on `feat/binairo-insane-polish` in `puzzles/binairo2d.gd`
and `ui/hud/out_of_hearts.gd`.

- **Hearts**: Hard 3, Insane 1 (`HEART_COUNTS`), drawn as one mesh on their
  own layer in a `HEART_ROW` (64) strip the layout keeps over the grid only
  on a board that has hearts, so Easy and Medium lay out exactly as before.
  The day card's hearts at the top right are the day's streak, not these.
- **A wrong tile** costs a heart at once when set with a brush or as a moon;
  a sun set by a *tap* waits `WRONG_GRACE` (0.4 s) first, because tapping
  cycles empty, sun, moon and every tapped moon passes through a sun. Without
  the grace, half of all tapped moons would cost a heart. Any later change to
  the cell cancels the wait. Then: crack, shiver, WORRIED + squash,
  `heart_lost`, and `EJECT_AFTER` later `state.clear_silent()` (no move, no
  history). Input on that tile is locked until it ejects.
- **While a liar hides**, the board does not blush the ends of a broken sign
  (the state reads the liar as its true kind, so a blush where the *shown*
  sign is kept would name it) and `broken_rule()` never says 4.
- **Out of hearts**: input and the clock stop at once, the faces go SLEEPY
  along the diagonal and the tiles sag 4 px after the eject, then the card.
  Try again rebuilds from the same data (hearts full, clock, moves, hints and
  checks zeroed; hints a video paid for stay). One more heart is rewarded
  placement `"heart"` (counts toward the daily video cap like `double` and
  `continue`), once a board, hidden when no video is ready; a remove-ads
  player takes it with no video, as the spec asks -- which departs from
  "no free-reward path" in `docs/agents/ads-and-purchase.md`. Back to camp
  calls `finish_unsolved()` and the board's `leave` signal, wired to the
  host's `_on_back`, so the host logs `puzzle_complete {solved: false}` and
  no abandon; `_on_back` also ends a heartless board unsolved on its own.
- **Insane** takes `Gen.insane_board(rng, bank_step)` (10x10, 12 signs, one
  liar) and falls back to Hard's live row with no liar when the bank is
  empty. At the solve the liar's badge swells (x2.7), blushes, turns over
  onto a sheepish face with a "Caught you!" bubble, turns back onto its true
  glyph, and keeps the blush; cue `liar`; the solve wave and `solved` wait
  `UNMASK_WAVE` (1.6 s) and `win_delay()` tells the host.

**Draw calls, `opengl3_angle`, 810x1440, `tests/_shot_anim.gd`, second of
two readings**: Hard 8x8 (d=2) 207 before, 203 after (the harness's first
tap is a sun, which ejects when the answer is a moon); Insane 10x10 (d=3) 227. A
throwaway probe with the Insane board full but one cell read 367, and Hard
partly filled 219. All far under 855, so the tiles were not baked.
