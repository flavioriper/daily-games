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
  in the rude list. On top of Padlock's filters, `proper()` drops the
  inflections of every rude word of five letters or more (a word that
  starts with one and runs three letters past it: BUNDAO, TRANSAS, PERRAS)
  and the board's `BISCUIT_STEMS`: the first build's scan found ESTUPROU
  and VAGABUNDA as biscuits, which the lid writes out. It costs a few
  innocent words (CRACKER, HEROINE, DROGARIA, TRANSACAO). A change to the
  filters wants a rebuild, then the substring scan of every biscuit and
  credited word against the rude lists, read by eye. Honeycomb's own lists could not serve (no S, seven
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
  121-169 in play on all four bands, 151-155 on the win, 217-257 a tutorial page.
- Owed: the user's eye and ear (every cue unheard), a phone, pt/es read by
  a native speaker, the word lists read by a person (rare words credited:
  `hame`, `tiro`), the website's game list (`web/scripts/gen_games.py`)
  not regenerated.

## The daily theme (2026-11-06)

The bank word boards' wave: the tin of the day holds one of the day's
theme words (`ThemedPictures.theme_pool` / `bank_pick`, 1753f58a).

- **The deal**: on a daily dealt from its day (`bank_step == 0`,
  `daily_key != 0`, never the tutorial's tin) `_themed_tin()` runs
  `bank_pick` over the band's bank first with the tins' biscuit words
  only, then (no hit) with every word a tin credits, and deals that entry
  whole (`State.load_day`) in place of `InsaneBank.pick`. No hit deals the
  bank's turn as ever. `_theme` is the word as the tin spells it,
  `_theme_b` its biscuit or -1. On the fixture pool (campfire night) only
  Hard holds a theme biscuit in each language (MUSHROOM, COGUMELO,
  LINTERNA); the other bands take a shorter word (EMBER, TENT, CESTA,
  FRUTA...), which the solve does not need.
- **Before it is made**: a little paper tag with a gold-rimmed sun hangs
  in the middle of the lid's lower rim (TAG_H 54), never the word.
- **Made**: the tag pops open over TAG_POP 0.35 s to name it (sun, word in
  deep gold), a gold sparkle at the plate and one at the tag, the `theme`
  cue THEME_CUE 0.14 s after the word's own (`word` or `biscuit`), and the
  say line reads `BT_SAY_THEME` ("Today's word: EMBER! +2";
  `BT_SAY_THEME_FREE` when the bulb laid it). A theme biscuit wears a gold
  ring on the lid (the lid's mesh, no draw call) and its word is written
  in rim gold; a gold `fx.ring` as it lands. No shade of a piece's colour.
- **Missed** (a shorter word the player never made): at the win the tag
  opens and names it, quietly (no cue), under "Well done!".
- **Win**: subtitle `BT_WIN_THEME` ("Today's word: %s! %s", the plain
  line after it) or `BT_WIN_THEME_MISSED` ("Today's word was %s. %s").
  The card waits THEME_HOLD 0.6 s longer only when the win carries a
  theme beat (the theme biscuit made last, or the word named at the win;
  never under `Motion.reduce`). A reopened themed day shows the tag open.
  `day_dict()` says `"source": "theme"`, `"theme": <word as written>`.
- Draw calls (opengl3_angle 810x1440, `theme`): Easy en 128 rest, 129-139
  as the word is made, 153 won; Medium pt 156 rest, 160-167, 157 won;
  Hard en 156 rest, 147-166, 157 won. The tag is one cached mesh and one
  string. `_win.gd biscuit` has no Biscuit Tin solver (FAIL
  solved=false, as before this pass); the shot harness solves it.
- Sound: new `theme` row (Pie's: the wrap climbing to the octave and a
  third). The set's other rows keep the house sound by job (token set
  down, lip taken off, wrap repeated, tongue refused); `hint` stays the
  breeze copied from Honeycomb and `enter` a token run, as the other
  boards have them.
- Harness: `tests/_shot_biscuit.gd -- <dir> d=<n> theme|theme=miss
  [lang=pt|es]` hands the board's seam (`pool_for_shots`, a static) the
  scratchpad fixture pool, folded, before the deal, makes the word by
  pointer and adds `theme_flying`, `theme_found`, `theme_tag`,
  `theme_settled`, `theme_won`; `theme=miss` never makes a shorter word.
  The harness boots world/main, so even without `theme` the real path
  reads this Mac's cached night (Medium en dealt SHIRT on 2026-11-06).
- Owed: phone, ear (the `theme` cue unheard), pt/es read by a native
  speaker, and an es run (pt and en seen); reduce motion written (tag
  open at once, no hold) but unseen.
