## Code Break

`puzzles/codebreak2d.gd` draws `puzzles/codebreak_state.gd`; puzzle id
`mastermind` (sounds in `assets/sfx/mastermind/`). The rule every drawing
keeps: **the score is a count and never a map** (`docs/agents/flat-screens.md`).

### Failing, the Shell Game, motion, rewards and sound (2026-09-29)

Spec `docs/superpowers/specs/2026-09-29-codebreak-polish-design.md`, built
unattended on `feat/codebreak-polish` at the user's word.

- **Bands** (`State.setup`, `HINTS_BY_BAND`): Easy 4/6 no repeats, 8 rows,
  3 hints; Medium 4/6 repeats, 8, 3; Hard 5/7, **7 rows, 1 hint**; Insane
  5/7, 7 rows, **no hints** (no bulb: `capabilities()` drops `hint`).
- **Hard and Insane can be failed.** Before this, Reset wiped the played
  rows, which was unlimited rows for anyone who remembered the scores. On
  Hard and Insane (`keeps_rows`) played rows are ink and Reset clears only
  the row in hand (`State.reset_row`, `_reset_row`). Easy and Medium keep
  the full Reset.
- **Hinted seats carry.** `State.revealed` seats the hinted friend in every
  later row; until this pass `_fresh_row` forgot it and the next hint
  showed seat one again.
- **Out of rows** (every band): the lids rattle, the row goes SLEEPY, and
  `ui/hud/out_of_rows.gd` offers One more row (rewarded placement `"row"`,
  once a board, left off when no video is ready; no free path for buyers)
  or Show the code. The board sets `out_of_hearts` while the card is up so
  the host's Back ends it unsolved. **A lost day now ends through
  `finish_unsolved()`**: it used to set `_done` by hand, so the host never
  logged `puzzle_complete {solved: false}` for a Code Break loss. There is
  no Try again, because the same code after eight read scores is free.
- **Insane's Shell Game**: after every scored row that did not crack it,
  two seats of the code trade places (`State.swaps[g]`, drawn from the
  day's rng **after** the code, so every other band's code is the draw it
  always was). The lids hop past each other (one high, one low) and each
  played row keeps a `SwapMark` arc under the two columns, so the swap is
  on the record. `State.code` is the code as it sits now; `code_at(g)` is
  what row g was scored against; `swap_after(g)` is the pair (none after
  the last row). `add_row()` makes the swap the lost row did not.
  `restore_completed_board` replays through `code_at`, and takes one row
  more than the band (a bought row).
- **Motion**: the flier leans `FLY_LEAN` and looks where it is going; the
  seated friends glance at it (`_glance`, `GLANCE_TIME`). A checked row
  wears one expression (JOY at one short or better, else HAPPY). Idle: a
  lid lifts every `PEEK_EVERY`..+`PEEK_JITTER` s and two eyes blink out of
  the dark (`Peeker`, white on ink, the same for every friend).
- **Rewards**, each the whole row's (`_react`): a clean miss puts on
  sunglasses (`CB_COOL`); every friend present but not solved does a
  two-lap conga (`CB_ALL_HERE`); a new best right-seat count says Warmer!,
  or So close! with confetti at one short, and the pouch glows. A reaction
  holds the row big until `SLIDE_AT_REACT` so it is seen with faces on.
- **Stamp and party**: the solve stamps the shared seal
  (`ui/flat/seal.gd`, moved out of Binairo) on the code's right with a word
  by rows used (`CB_STAMP_1`..`8`, `CB_STAMP_MORE` for a bought row); on
  Insane the night seal with "Shell Game" (`CB_SHELL_SEAL`). The share
  glyphs gain `🏅 <word>` or `🌙 Shell Game · <word>`. Hats pop on the code
  and the cracking row with two confetti sweeps; `WIN_DELAY_PARTY` 3.3.
- **Sound**: `full`, `locked`, `check`, `score` re-prompted toward felt and
  kalimba (the wooden bonks read as a scold, as Binairo's did). `note` is
  layered under `place` up the pentatonic by seat, so a row filling plays a
  run; `pip` lands per pip, a step higher each, in pile order. New:
  `warmer`, `so_close`, `all_here`, `cool`, `shuffle`, `peek` (-15),
  `stamp`, `party`, `confetti`, `out_of_rows`, `row_back`. Not yet judged
  by ear.

**Draw calls, `opengl3_angle`, 810x1440, `tests/_shot_anim.gd`**: fullest
Insane board (six rows, marks) idle 257; Easy fullest 255; Insane `solve`
window (after the party) 192. Far under 855.

### Review fixes (2026-09-29)

- **No Reset once the day is out of reach** (`can_reset()`, read by the
  flat top bar and actions row when a board offers it): out of rows, after
  Show the code, or on Easy/Medium past a bought row. It was a free replay
  against a code the player had just seen -- older than this pass, since a
  lost day was always Reset-able -- and it logged the day twice.
- `completion_record()` carries `bought`, so an old Hard save solved on row
  eight (Hard had eight rows) does not stamp "Second wind".
- `hints_left()` is 0 once every seat is revealed, so no hint video is
  offered for nothing. A full Reset restarts the idle peeks, and stops a
  code pop still running (it could show a friend under a shut lid).
- The clean miss counts the different friends it ruled out (`CB_COOL_1`,
  `CB_COOL_N`).
- **A tapped seat is chosen** (2026-09-30, user request): tapping an empty
  seat of the active row rims it in `Pal.ACCENT` all round (`TARGET_RIM`)
  and the next chip fills it (`state.place(v, at)`); tapping it again lets
  go. Tapping a seated friend still sends them back, and that seat is then
  chosen. A pick, a Check and a Reset clear the choice; with none, a chip
  fills the first free seat as before. The accent, not the sun: the sun rim
  already means a hint's seat.
