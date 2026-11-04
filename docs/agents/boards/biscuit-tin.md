# Biscuit Tin

- **Biscuit Tin is a Puzzles card (2026-11-04)**, the third of
  `docs/roadmap-word-boards.md`, under Words, after Padlock. An open
  biscuit tin on a kitchen table, full of broken pieces with two to four
  letters each; lay pieces on the plate (four at most) and whenever the
  plate spells a word it counts at once (1/2/4 points by its pieces); four
  pieces that spell one of the tin's long words knit into a whole biscuit
  (8) that flies to its dimple on the lid. Every biscuit whole is the
  solve. Spec `docs/superpowers/specs/2026-11-04-biscuit-tin-design.md`.
  Id `biscuit`, prefix `BT_`. Built unattended at the user's word, with no
  concept tab first, as Cross Stitch and Padlock were.
- Files: `puzzles/biscuit2d.gd`, `puzzles/biscuit_state.gd`,
  `puzzles/biscuit_world.gd`, `ui/faces/biscuit_art.gd` (piece, whole,
  dimple, plate, tin, case, lid, cloth, sugar, crumbs),
  `ui/hud/biscuit_tutorial_diagram.gd`, `ui/menu/cards/biscuit.gd`,
  `tools/build_biscuit.py`, `content/insane/biscuit*.json`.
- **The banks are the only source, and no dictionary ships**:
  `tools/build_biscuit.py` (wordfreq + spylls in a venv, Honeycomb's dicts
  dir; `[cache dir]` keeps each language's pruned list between runs, the
  Hunspell pass is the slow part) cuts common long words in four, looks up
  every ordered run of one to four pieces with a prefix-pruned search, and
  keeps a deal only when the runs of four that spell a word are exactly its
  biscuits, every piece differs, and no piece and no run of two or three is
  in the rude list. Honeycomb's own lists could not serve (no S, seven
  letters at most). 365 tins a band in every language; Spanish Hard takes
  ~110k tries (two-letter pieces repeat), the whole build ~10 min.
- **Points and stars**: `line` = the biscuits' points and `SHARE`
  (0.15/0.15/0.12/0.12) of what the tin's other fair words (zipf 2.9 up)
  hold, capped at half the biscuits' points again. Stars rise with the
  points (3 at the line, 2 at three fifths, 1 on the solve); a biscuit the
  bulb lays scores 0. Easy tins hold few other words, so Easy's line is
  the biscuits and a word or two. `quality()` is points over the line.
- A biscuit's word spelled with fewer than four pieces counts for nothing
  (it counts only whole). A word on the way counts: CON, then CONSIDER.
- **Crumbs** (Insane): four pieces of a sixth word the tin never takes
  whole; they may make shorter words; swept off when the fifth biscuit
  lands.
- No fail state, no Undo, the bin shut. The way out for a stuck player is
  the bulb (two presses: ring a biscuit's first piece and say its length,
  then lay it whole), and the host's video for one more.
- Probes (headless): `tests/_probe_biscuit.gd` (every bank: shape, no
  repeated piece, no stray run of four, line in range, a hand and the bulb
  each solve 12 tins a bank; 0 bad over 4,380 tins),
  `tests/_probe_biscuit_board.gd` (the board's own `_tap`: lay, refuse a
  fifth, take back, clear, a word and again, a biscuit, the bulb; 0 bad).
- Harness: `tests/_shot_biscuit.gd -- <dir> d=<0..3> [tut=<page> at=<frames>|card]`
  (zsh: split the args, `${=args}`). Draw calls (opengl3_angle, 810x1440):
  121-169 in play, 151-155 on the win, 217-257 a tutorial page.
- Owed: the user's eye and ear (every cue unheard), a phone, pt/es read by
  a native speaker, the word lists read by a person (rare words credited:
  `hame`, `tiro`), the website's game list (`web/scripts/gen_games.py`)
  not regenerated.
