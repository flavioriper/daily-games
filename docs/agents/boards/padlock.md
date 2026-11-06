# Padlock

- **Padlock is a Puzzles card (2026-11-04)**, the second of
  `docs/roadmap-word-boards.md`, under Words, after Cross Stitch. A brass
  combination padlock on a shed door: a row of letter dials, one per letter
  of the band's word length; turn them so the window spells words, each
  word lighting its letters gold; light every letter on every dial and the
  shackle springs open. Spec
  `docs/superpowers/specs/2026-11-04-padlock-design.md`. Id `padlock`,
  prefix `PL_`. Built unattended at the user's word, with no concept tab
  first, as Cross Stitch was.
- Files: `puzzles/padlock2d.gd`, `puzzles/padlock_state.gd`,
  `puzzles/padlock_world.gd`, `ui/faces/padlock_art.gd` (body, slot,
  arrow, cell, window, shackle, tag, door, hasp, staple, ivy, can),
  `ui/hud/padlock_tutorial_diagram.gd`, `ui/menu/cards/padlock.gd`,
  `tools/build_padlock.py`, `content/insane/padlock*.json`.
- **The banks are the only source, and no dictionary ships**:
  `tools/build_padlock.py` (needs wordfreq and spylls in a venv, and
  Honeycomb's dicts dir: the LibreOffice Hunspell dictionaries and the
  LDNOOBW lists) stacks a band's seeds (common words) into dials, looks up
  every word the dials spell (wordfreq zipf 1.8 up, Hunspell-checked, rude
  words, rude stems and names left out: `EXTRA_RUDE`, `RUDE_STEMS`,
  `NAMES`) and writes them into each lock with the fair ones (zipf 2.9 up)
  and the par. Unlike Honeycomb's list it keeps S. 365 locks a band in
  every language. A change to the filters wants a rebuild and a read of
  ten locks per bank in pt and es.
- **Par is solved, not assumed**: the fewest fair words that light every
  letter, by exact set cover. `State.fewest_from` solves the fewest still
  needed over every credited word live (branching on the dark letter the
  fewest words light; ~1-3 ms a lock on the Mac, worst ~30 ms on Insane).
  `tests/_probe_padlock.gd`: 0 par mismatches over the twelve banks, no
  start window that is a word, the bulb alone opens 20 locks a bank in
  exactly par.
- **Stars**: only a word that lights a new letter counts; the pill reads
  `counted + to_go` against par: 3 up to `three_line()` (par plus half par,
  rounded up: a dial turned one at a time often spells a word on the way,
  and the first cut, one word of slack, still gave a player dialling the
  par words dial by dial two stars on Easy and Medium), 2 up to twice par,
  1 after. `PL_RULES_ON_THE_WAY` and `BRAIN_PL_4` tell the player.
  `quality()` reads the same line. The bulb's
  word is free for the stars and counts in `quality()` and the win line.
- **Rusty Lock** (Insane), the roadmap's rule: the deepest dial (rust on
  its slot, an arrow over it) only turns down; dragged past its last letter
  it comes round to its first (`round`), dragged up or tapped above it
  refuses (`PL_SAY_RUSTY`). The bulb's second press ignores the rust.
- No fail state, no Undo, the bin shut (a word found stays found).
- `tests/_probe_padlock_board.gd` (headless) drives the board's own
  `_press`/`_move`/`_release`: a tap, a tap mid-spring (the letter is read
  from where the dial was drawn at the press), a word dialled again, the
  rusty dial refusing a tap above and a drag up and coming round.
- Harness: `tests/_shot_padlock.gd -- <dir> d=<0..3> [tut=<page>|card]`
  (zsh: pass `d=3 tut=2` as two words). Draw calls (opengl3_angle,
  810x1440): 88-114 in play, ~155 on the win, 104-110 a tutorial page.
- Owed: the rusty dial's coming round is drawn as a quick slide back up,
  not a wrap; the user's eye and ear (every cue unheard), a phone, pt/es read by
  a native speaker, the word lists read by a person (names and odd forms
  still slip through: `hein`, `ecra`).

## The daily theme (2026-11-06)

The lock hides the day's word.

- **Deal**: on a daily dealt from its day (`bank_step == 0`, `daily_key`
  set, never the tutorial's demo lock) `_deal_themed` hands
  `ThemedPictures.theme_pool(daily_key)` and the band's bank
  (`InsaneBank.boards(State.BANKS[band])`, each lock's **fair** words) to
  `ThemedPictures.bank_pick` and deals that lock instead of
  `InsaneBank.pick`. No pool or no hit: the bank's turn as ever. The lock
  and its par are the bank's, untouched. With the fixture pool every band
  in every language hits (en Easy `tent`, Medium `flame`, Hard and Insane
  `basket`; pt `fogo`, `cesta`, `tronco`, `caneca`; es `leña`, `fuego`,
  `ceniza`). The bank folds keeping ñ, as `Locale.fold` does for es.
- **The tag**: a kraft luggage tag on a red string, a little sun printed by
  its hole (`Art.luggage`, `Art.sun`), tied to the shackle's right flank
  (THEME_KNOT on the arc, lifting with it), hanging at THEME_TILT and
  swaying THEME_SWAY in `_process` (it runs at rest; it is one cached mesh
  under a transform, the word one `draw_string`). Blank, a pencil dash line
  waits; the word length is no secret (every word on a lock is the dials'
  length). Sized THEME_TAG_H and shrunk whole to stay on the door.
- **Found**: the day's word dialled (by hand or by the bulb's second press:
  it is a word like any other and counts for par and stars exactly as any)
  is written on the tag in ink as its letters land, a warm halo glows
  behind it (a halo, never a shade of the card or of the gold cells), the
  tag kicks (THEME_KICK, settles in ~1.5 s), `fx.ring` and `fx.sparkle` in
  `Pal.SUN` round it, the `theme` cue 0.14 s after the word's own, and the
  line under the lock says `PL_SAY_THEME` ("Today's word: TENT!") in place
  of the letters count. Its tag in the found row wears the sun on its hole.
  When it is the word that opens the lock, `PL_PERFECT`/`PL_DONE` takes
  the line 0.3 s later (the win line names it).
- **Win**: the tag rides the shackle up and kicks again as it springs.
  Opened without the word, the tag gets it in pencil at the spring (the
  board's to show once the day is done). Subtitle `PL_WIN_THEME` ("Today's
  word: %s! %s") or `PL_WIN_THEME_MISSED` ("Today's word was %s. %s"),
  the board's own line kept as the second `%s`; `win_delay` adds
  THEME_HOLD 0.6 only when it was found. The rules sheet adds
  `PL_RULES_THEME` on a themed lock. A reopened themed day re-deals the
  same lock (same day key, same cached night) and shows the tag written
  (ink, or pencil if missed); the win card covers most of it, the eye
  shows it. `day_dict` says `"source": "theme"`, `"theme": <word as
  written>`. Under `Motion.reduce` the tag hangs still and the word is
  written without its pop.
- Draw calls (opengl3_angle 810x1440, `theme`): Easy 89 at rest, 111
  as the word lights, 96 with the tag written, 156 won; Hard 93, 121, 100,
  160 won (plain Hard was 92, 115, 97, 158).
- Sound: new `theme` (one wrap and two above it, Pie's row); the rest of
  the set was already bank pops by job, nothing changed.
- Harness: `tests/_shot_padlock.gd -- <dir> d=<n> theme|themiss
  [lang=pt|es]` (zsh: separate words) reads the fixture pool
  (THEME_FIXTURE, in the 2026-11-06 session's scratchpad), sets the
  board's static seam `theme_pool_override` and re-deals through
  `start()`; `theme` dials the day's word at step 2 (`theme_lit`,
  `theme_tag`), `themiss` opens the lock without it. The harness boots
  world/main, so with no `theme` arg the real path reads today's cached
  night: Medium dealt on `shirt` (2026-11-06). `tests/_win.gd` has no
  `padlock` solver yet, so it reports FAIL whatever the board does.
- Owed: phone, ear (the `theme` cue unheard), pt/es read by a native
  speaker (`argola`, `gancho` for the shackle in the rules line).
