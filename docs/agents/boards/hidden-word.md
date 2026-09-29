# Hidden Word

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Hidden Word is the first board that can end without a solve** (2026-09-19,
  `puzzles/hidden_word2d.gd`, spec `2026-09-19-hidden-word-flat-design.md`).
  Five letters, six rows: type a guess, commit it, and the row turns over a
  tile at a time -- green in the right place, amber in the word elsewhere,
  grey not in it. **The commit is the one irreversible move on any flat
  board**: there is no Undo and no Check, an Enter spends a row, and when the
  sixth is spent the board calls `PuzzleBase.finish_unsolved()`, which sets
  `_done` and emits **`ended`** rather than `solved`. The host connects it
  on every board (the `has_signal` guard for the frozen island contract went
  with the 3D game on 2026-09-24). The keyboard is
  its tray (`ui/flat/key_board.gd`, `"tray": "keys"`), and it is the first
  board with **no tip card** (`"tip": false`) and no actions row. Its
  `rules()` string is real and the rules sheet is built and refreshed for it
  like any other board, but **there is currently no way to open it**: every
  other board's tip card is the sheet's only door
  (`tip_card.open` to `_open_rules` in `ui/flat/flat_host.gd`), and Hidden
  Word has no tip card. This is an open question for whenever the tip card
  is retired across the other ten boards, tracked in the spec's amendments;
  it is not a claim that the keyboard explains the rule, which it does not.
  **The flip is its signature** and its
  numbers are its own three (`FLIP_STEP`, `FLIP_TIME`, `TOAST_HOLD`), with
  six more for the ending -- the keyboard's exit, two dim levels, the dim's
  time and the sprout's rise -- which stand in the board because nothing else
  in the game can run out, so `core/motion.gd` would never read them. A
  refusal is a toast over the card and never a silence. It ships words:
  `content/hidden_word.json` (968 answers in three bands) and
  `content/hidden_word_accept.txt` (15,921 a guess may be), and `content/*`
  had to join the export preset's `include_filter` to reach the APK at all --
  which was also quietly true of How Big?'s table. **Never call it Wordle**,
  in code, in a comment or on screen; the New York Times owns that, and this
  repo already ships Mastermind as Code Break for the same reason.
  Measured on this Mac with `tests/_shot_anim.gd -- hiddenword` at
  `--resolution 810x1440`: **110** draw calls with the first row committed and
  the keys repainted (109 bare, 109 to 111 over fourteen runs), and **56** in
  the losing reveal, where the keyboard has gone and the grid is dimmed --
  all well inside the 855 budget. Its idle reads about **5.0 ms**, and that
  figure deserves a caveat: fourteen runs spread 3.06 to 7.30 (median 5.00).
  Queens, run as a control in the same session, swung as widely -- 4.40,
  4.62, 4.45, 2.84, 4.55 and 4.52, a factor of 1.6 against the 3.83 recorded
  in its own spec -- which is what shows the spread is this machine's and not
  this board's, and why **a single reading off this harness is worth
  nothing**. Compare a board only against another board measured the same
  hour, and quote every reading, including the flattering one. The reveal,
  which draws half as much, read 1.88 and 1.92. Checked on the phone's driver
  (`--rendering-driver opengl3_angle`): same 110 and 56, and the settled
  frames match the default driver to 21/255 on edge antialiasing alone, so
  nothing has reintroduced an `instance uniform`.
