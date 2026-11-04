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
  `counted + to_go` against par: 3 within one over par (a dial turned one at
  a time can spell a word on the way), 2 within three, 1 after. The bulb's
  word is free for the stars and counts in `quality()` and the win line.
- **Rusty Lock** (Insane), the roadmap's rule: the deepest dial (rust on
  its slot, an arrow over it) only turns down; dragged past its last letter
  it comes round to its first (`round`), dragged up or tapped above it
  refuses (`PL_SAY_RUSTY`). The bulb's second press ignores the rust.
- No fail state, no Undo, the bin shut (a word found stays found).
- Harness: `tests/_shot_padlock.gd -- <dir> d=<0..3> [tut=<page>|card]`
  (zsh: pass `d=3 tut=2` as two words). Draw calls (opengl3_angle,
  810x1440): 88-114 in play, ~155 on the win, 104-110 a tutorial page.
- Owed: the user's eye and ear (every cue unheard), a phone, pt/es read by
  a native speaker, the word lists read by a person (names and odd forms
  still slip through: `hein`, `ecra`).
