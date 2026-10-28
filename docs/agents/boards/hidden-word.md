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
- **The polish pass** (2026-09-30, spec
  `2026-09-30-hidden-word-polish-design.md`) made Hard and Insane losable
  and gave Insane a rule of its own. Rows are ink on Hard and Insane (Reset
  clears only the row being typed) and every clue must be used (the genre's
  hard mode, `State.keeps_clues`, toasts naming the letter). Running out of
  rows on **any** band droops the tiles and brings Code Break's
  `out_of_rows.gd` card in this board's keys -- One more row (a seventh,
  `State.MAX_ROWS`, the grid regrows over `GROW_TIME`) or Show the word
  (the old reveal, `finish_unsolved()`); `out_of_hearts` is the host's hook,
  and `finish_unsolved()` no longer fires on the sixth row's commit.
  **Insane is Snail Mail**: a row turns over sealed (a lavender envelope,
  cool so it never reads as a mark) and its colours arrive when the next row
  is committed, carried by One Line's snail; the answer and the last row come
  at once. Everything that reads colours reads `State.delivered()`, which is
  kept (`sent`) rather than derived so a bought row cannot take a shown
  row's colours back. Insane's words are banked
  (`content/insane/hiddenword*.json`, `tools/insane/hiddenword_ladder.py`,
  Python because it grades a list rather than mining a generator): the
  answers an answer-list-aware solver needs five or more rows for under the
  rule. Rewards (a note up the scale per new green, three gags, row
  reactions with sunglasses and a conga, a party with a meadow in the unused
  rows, a cheer and the seal) all wait for a row to show its colours.
  `tests/_shot_hiddenword.gd` drives every scenario; peaks 125 to 157 draw
  calls on `opengl3_angle`.
- **A tapped bed takes the next letter** (2026-09-30, user request).
  `state.typed` may hold a space for a skipped bed (trailing blanks trimmed,
  so a row typed left to right is just its letters) and `state.cursor` is
  the bed the next letter goes into: typing writes there, over whatever it
  holds, and moves on to the next empty bed (wrapping; `LEN` when full).
  Backspace clears the cursor's bed, or on an empty one the nearest letter to
  its left. The board answers taps only over the row in hand (`_has_point`),
  so the rest of the card lets them through. The keyboard's backspace moved
  to the right end of the bottom row and Enter to the left, where phone
  keyboards keep them. `_shot_hiddenword.gd select` taps bed five for real.
- **The keys tile the tray** (2026-10-15, the user: "on games that require
  words and typing, players are complaining about the built in keyboard
  missing things, can we use the device keyboard?"). Not the device
  keyboard: it cannot carry the key marks, which are the aid this genre
  lives on, it covers near half the screen, and its suggestions spell
  answers on Pearl Dive. The keyboard was dropping letters instead. A key's
  face is 91x100 with 10 px between keys and 14 between rows, and nothing
  was hit in those gaps; worse, the press tween shrinks a held key to 94%
  about its centre, so a finger that landed 1-3 px inside a face and moved
  1-2 px before lifting was outside the key when it lifted and typed
  nothing (a windowed probe sending `ScreenTouch`/`ScreenDrag` through
  `Input.parse_input_event`; headless, nothing reaches a Button at all).
  Every key is a `KeyBoard.KeyButton` now: `_has_point` reaches `REACH` (half a
  gap each way) past the face, so two neighbours meet at a seam, and reads
  the point against the key's unscaled size, so a press never moves the
  edge under the finger. After: every tap from 2 px into the gap to the
  face's centre types, with up to 4 px of jitter; only a finger that lands
  in the gap and crosses the seam before lifting still types nothing. The
  faces are drawn exactly as before. Suite 249567/0; `_shot_hiddenword.gd
  select` on opengl3_angle; unseen on a phone.
- **The board checkup** (2026-10-02, `docs/agents/checkup.md` row 11).
  The lag was the keyboard and the grid. Every key was a Button drawing its
  own `soft_button` StyleBoxFlat and its own letter, two draw calls a key, 56
  of the 125 an Insane board drew at rest; the keys now draw nothing and the
  tray's `Paint` child draws all of them (faces one mesh of looks made once
  per size, face, press and glyph, letters after), re-meshed only on a frame
  whose signature of key transforms and presses changed. Insane idle 125 ->
  68 draws, 9.4 -> 5.1 ms (probe, opengl3_angle, second of two). The grid was
  `_build_grid` writing every round rect a vertex at a time on each animating
  frame (each typed letter, flip, caret glide), 4-7.6 ms and growing with the
  rows; it now runs on `RunMesh` (`_shape`, `_lay_runs`: a caret run per row
  and a cell run sized for a bed, a flip's shadow and a sealed tile, laid for
  `MAX_ROWS` and laid again only when the cell changes -- One more row's
  grow), with the party's meadow, Reset's ghosts and the gags on the tail.
  Build ~1-1.6 ms; Insane play 12.5 -> 5.5 ms, full-board play 10.8 -> 6.5,
  the 44-46 ms frames gone; pixel-identical at rest (max 8/255 on edges).
  `_shot_hiddenword.gd` peaks now 87-99 draws (out, solve, refuse,
  restore). The tutorial (`tutorial_pages()`,
  `ui/hud/hidden_word_tutorial_diagram.gd`) is the board itself as a `Desk`
  (no sounds, reactions, party, card or band; two rows; a `DeskState` that
  accepts any word) over a real `KeyBoard` scaled to 56% of the page, played
  by a finger in the player's language (`WORDS`: en, pt, es): GUESS, CLUES,
  TAP, HINT (bands with hints), ROWS (ink wording on Hard and Insane), STRICT
  (Hard and Insane) and SNAIL (Insane). Still no Undo: an Enter is the check
  and taking a row back is not this game; backspace undoes typing, Reset is
  there on every band.

### The meadow and its letter box are the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/hidden_word_world.gd` is cream air
with clouds, a sealed letter, a loose paper tile and a letter box on a
post in the left air (the right is Insane's snail's), two far hills and
the meadow from the ground line down, paler under the keyboard so the
keys read; six pollen motes breathe. The board's own band scenery moved
into the world and the board tells it the ground line (`set_ground(y)`).
Height binds, so the grid is narrower than the margins and centred (170
of air each side at 1080). On the win or a lost day the world rides
vertically so the crown stays under the grid.

- Registry: `bleed`, `level_card`, and **the keyboard stays**
  (`"tray": "keys"`).
- `opengl3_angle`, 810x1440: 82 draw calls at rest; `tests/_win.gd --
  hiddenword` passes.
- Decided for the user, unconfirmed: the grid not widened; the toast over
  the first row (it touches Hint). Owed: a phone, the lost day's look.
- **A themed day's Easy word** (2026-10-14, the daily theme's stage 3,
  `docs/agents/days-dashboard.md`): Easy's daily takes the first of
  `ThemedPictures.words(daily_key, "hiddenword")` its answer list holds as
  spelt, any band of the list; Medium up, New and Snail Mail as before.
- **No word on two bands of a day** (2026-10-15, the user, of the word
  games: "make sure to generate unique words for each difficulty"). The
  bands are nested slices of one list (217 / 467 / 968), so two bands of a
  day could meet (2 days in a year measured). `State.deal` draws as before
  and steps on to the band's next word past any of `avoid`; the board's
  `_day_words` deals Insane's banked word and the bands below from their
  own daily seeds, so Easy keeps clear of Insane's, Medium of both, Hard of
  all three. A day that met nothing deals as it did. A year measured: 0.
  The nested slices themselves stay (a Medium word may be an Easy word of
  another day).

- **The sprout is a Peeplet (2026-10-27, `feat/peeplet-brand`).** The
  reveal's character is no longer `ui/faces/sprout_face.gd` (deleted): it is a
  `PeepletView` dressed as the day's first Peeplet (`Cast.dress(view, 0)`),
  built on the first ending and kept (`_peeplet`, `_raise_peeplet(win)`,
  `_ride_peeplet`; the rise, fade and seat are the sprout's own, `PEEPLET_AT`,
  `PEEPLET_R`). Framed as Pie's card (`frame_height 1.0`, `aim_y 0.46`,
  `idle_fps 0.0`: a held portrait). A win stands it and laughs it once the card
  is up (the walker's silent `laugh_time`, the board has its own sounds); a
  loss sits it (`PeepletView.seated`, new: the walker sits and the pose is
  settled by hand, because a held walker is not processed). The party hat and
  the sprout's `hat` / `glasses` fields are gone; the persona wears its own.
  The menu card seats the same Peeplet on its tump, held.

### The phone's keyboard, and the words left (2026-10-28)

The user: "make word trail and hidden word experience way better to play,
and game itself way funnier to play, right now nobody likes it", then
"users want to use the native keyboard as well on hidden word like on five
clues". This reverses the 2026-10-15 call above for this board (Pearl Dive
keeps the tray), and keeps what that call protected: the key marks.

- **It types on the phone's own keyboard**, Five Clues' way
  (`docs/agents/boards/clues.md`): an unseen `LineEdit` (`_field`) over the
  grid, `keep_editing_on_text_submit`, called up when the word is dealt
  (`_want_osk`, once the board is laid out and nothing holds the clock) and
  by any tap on the grid (`_has_point` takes the whole block while a row can
  be typed); `_watch_osk` follows the keyboard's height, `osk_override`
  stands in for one off a phone. **The field's text is the row**, left to
  right: `_on_field` folds it (`Locale.fold`, accents off, letters of the
  language's alphabet only, five at most), erases back to where it and the
  last reading part and types on from there through `type_letter` /
  `erase_letter`, so a phone letter pops in as a key's does and an
  autocorrect that rewrites the line simply retypes it. Anything else that
  writes the row (a key, a bed, Enter, Reset) puts the field back
  (`_sync_field`). Enter on the phone is `commit_row`; a refusal keeps the
  line. A solve or the last row puts the keyboard away.
- **The board keeps its own keys**, the same `KeyBoard` (`ui/flat/key_board.gd`),
  now its child and laid by it (`_place_keys`); the registry's tray is
  `"none"`. With the phone's keyboard down they are where the tray was, full
  size, and the game plays as before (desktop too: the field takes a real
  keyboard). With it up they shrink to `KEYS_MINI` (0.4) just above it, the
  **mirror of the marks** the phone's keyboard cannot wear, QWERTY because
  the phone's own is right under them (and Spanish keeps its Ñ), still
  tappable. The band shrinks to `BAND_OSK` and the meadow's ground sits
  under the grid. They leave as the party starts and on Show the word, and
  come back with Reset, as the tray did. The tutorial's `Desk` sets
  `own_keys = false` and keeps the page's scaled keyboard.
- Above a 16:9 phone's keyboard (`osk=806`, 42% of 1920) the grid gets 510
  to 948 of 1920: cells 61 px with six rows, 51 with the seventh, keys 970 to
  1106, the keyboard's top at 1114.
- **The words-left chip** (`State.words_left`, `_count_left`, `_draw_chip`):
  under the grid, "467 words left", how many of the band's words still fit
  every row showing its colours -- Easy's 217, Medium's 467, Hard's and
  Insane's whole 968, plus the answer wherever it came from (themed, banked),
  so it is never zero. It moves when a row shows its colours (`state.seen`,
  so on Snail Mail when the snail brings it), counting down LEFT_TIME after
  the row's reactions with a wrap pop (the board's `combo`) a step, five at
  most, climbing; one left reads "Only one word fits!" in gold with
  `sprout`. Beside the small keys while the phone's keyboard is up. Insane
  counts the whole list rather than its banked hard words: the
  bank is a grading of the same list, and saying "of the hard ones" would
  tell the player the word is a trap. `HW_LEFT_N`, `HW_LEFT_ONE` en/pt/es.
- The praise by row was already there (the seal's `HW_STAMP_1..6`).
- `HTP_HW_GUESS_BODY` names the phone's keyboard (en/pt/es).
- `tests/_shot_hiddenword.gd`: `osk=<px>`, mode `field` (typed through the
  line: letters, a backspace, a sixth letter and accents folded away, Enter)
  and a `layout:` line. `tests/_win.gd -- hiddenword`: the layout above a
  42% keyboard, a wrong word through the field (the row commits, the line
  empties, fewer words fit), the answer on the board's own keys: PASS.
- Draw calls on `opengl3_angle`: 85 peak playing rows with or without the
  phone's keyboard (the keys' paint is the tray's two), 103 on Insane's out
  of rows; Insane's solve peaked 153 under the party's confetti.
- Decided for the user, unconfirmed: the keyboard comes up by itself when a
  word is dealt; QWERTY mirror at 0.4 rather than an alphabet strip; the
  count over the band's list. Owed: a phone (the keyboard's real height,
  Android's back, autocorrect on a five-letter line).
