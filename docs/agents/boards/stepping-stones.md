# Stepping Stones

- **Stepping Stones is a Puzzles card (2026-11-04)**, the fourth of
  `docs/roadmap-word-boards.md`, under Words, after Biscuit Tin. A brook
  across the screen between two grassy banks, a word on a slab on each;
  type a stone, a word one letter from the one before, on the phone's own
  keyboard and it drops into the brook; a stone a step from the far bank's
  word makes the crossing. Letters matching the far bank stand on moss; the
  letter a stone changed is inked gold (a stone the bulb laid, blue). Spec
  `docs/superpowers/specs/2026-11-04-stepping-stones-design.md`. Id
  `stones`, prefix `SS_`. Built unattended at the user's word, with no
  concept tab first, as the three before it were.
- Files: `puzzles/stones2d.gd`, `puzzles/stones_state.gd`,
  `puzzles/stones_world.gd`, `ui/faces/stones_art.gd` (stone, slab, moss,
  ripples, brook, bank, reed, lily, current),
  `ui/hud/stones_tutorial_diagram.gd`, `ui/menu/cards/stones.gd`,
  `tools/build_stones.py`, `content/stones_<4|5>[.lang].json`,
  `content/insane/stones*.json`.
- **Words**: `tools/build_stones.py <dicts> <cache>` reads Biscuit Tin's
  pruned wordfreq cache (`build_biscuit.lexicon` + `proper`, so the same
  rude lists, stems and names are out) and writes the word lists (`fair`
  zipf 2.9 up, commonest first; `more` 1.8 to 2.9 and `CRUDE`; `shown`
  accents) and the banks. Five-letter bands also accept Hidden Word's
  accept list, so a real word is not refused there (it accepts junk like
  AAAAH too; it is what Hidden Word accepts). `CRUDE` words (FARTS was on an
  English route in the first build) may be typed but are never on a bank,
  a route, the par or the bulb. A build takes ~6 min (English Insane ~120k
  tries: swaps between common English five-letter words are rare).
- **Banks**: 365 crossings a band a language. Ends zipf 3.5 up, each word on
  a bank twice at most; every letter differs from bank to bank (Easy,
  Medium; one may match on Hard and Insane); two shortest ways at least;
  `route` the shortest way through the commonest words. Easy par 3 with the
  route's middle given; Medium par 4-5; Hard five letters par 4-5; Insane
  (Slippery) five letters par 4-6 counting swaps, kept when a shortest way
  takes a swap or the plain way is longer.
- **The state searches at load**: `_bfs(to)` over the fair words (and to the
  given on Easy), so `dist`, `to_go`, the stars and the bulb need no table.
  A typed word that is not fair reads its distance through its fair
  neighbours.
- **A line is judged when it holds the band's length** (`_set_typed` ->
  `_offer` deferred); Enter judges sooner. A refused line stays so it can
  be mended and is not judged again unchanged (`_refused`). Refusals: not a
  word, more than one letter off (the line says how many: a phone keyboard
  can autocorrect), already on the way (or a bank), the same word.
- **Easy's given** joins by itself when a stone is a step from it (kind
  `given`), and Undo lifts it with the stone that called it. The bulb routes
  through it while it is on a shortest way.
- **Stars**: stones laid plus the fewest still to go, 3 up to par + 1, 2 up
  to par + 3. Only the stones on the way at the crossing count, so Undo and
  the bin are free. `quality()` counts a bulb's stone twice. A party at par
  with no bulb.
- **The bulb** (two presses): the first rings the letter of the last stone
  to change (two on a swap), or says which stone to go back to from a dead
  end; the second lifts back to it and lays the stone (kind `bulb`).
- **Layout**: Five Clues' keyboard way (`_field`, `_summon`, `_watch_osk`,
  `osk_override`). Rows shrink from 150 to 70 (60 with the keyboard up) as
  stones come; past that the oldest fold into one "+n" pebble. Easy's way
  runs at 0.42 of the width, the given waiting at 0.8.
- Probes (headless): `tests/_probe_stones.gd` (every bank in every
  language: par re-found by the state's search, route fair and stepwise,
  Easy's given the route's middle, the hand and the bulb each cross 40 a
  bank at par), `tests/_probe_stones_board.gd` (the board typed through
  `type_letter`: lay, refuse unknown/used/far, Undo, the bulb's two
  presses, the bin, the crossing, Easy's given called in and lifted, an
  Insane route with its swap).
- Harness: `tests/_shot_stones.gd -- <dir> d=<0..3> [osk=<px>] [tut=<page>|card]`.
- Owed: the user's eye and ear (every cue unheard), a phone (the keyboard
  layout and autocorrect), pt/es read by a native speaker (verb forms on
  the banks: SUMIU, DIRÉ), the word lists read by a person, the website's
  game list (`web/scripts/gen_games.py`) not regenerated.

## The daily theme (2026-11-06)

The bank word boards' wave: the day's crossing comes from the night's
theme words (`ThemedPictures.theme_pool` and `bank_pick`, 1753f58a).

- **The deal**: on a daily dealt from its day (`bank_step == 0`,
  `daily_key != 0`, never the tutorial's board) `_themed_entry()` runs
  `bank_pick` over the band's bank twice: a crossing whose banks (`from`,
  `to`) hold a theme word first, else one whose route (and Easy's given)
  does, and deals that entry with `load_day`. The crossing, its par and
  route are the bank's as built; no hit deals `InsaneBank.pick` as ever.
  `_theme` = `{word (folded), at: "to" | "from" | "way"}`. With the
  scratch fixture's pools every band in every language found one (en Easy
  ends: bark, camp, fire, tent, wood; en Hard cider, smoke; en Insane
  only toast).
- **The mark**: a little sun medallion (`Art.sun_mark`: rays, a dark rim,
  the sun disc) on the top right corner of the word's slab or stone,
  baked into that slab's or stone's cached mesh, so it costs no draw
  call. Never a shade of the stone. A bank's sun is there from the start;
  a route stone's comes with the stone (Easy's given wears it while it
  waits at the side).
- **Reaching it**: a route stone laid (by hand, the bulb or Easy's given
  coming in) plays `theme` with a ring and a sparkle at its sun
  Motion.DROP_TIME after the lay (the given: when its slide ends) and
  says `SS_SAY_THEME` ("Today's word: MOSS!") over the given's line. A
  bank's word: at the crossing, `theme` and the sparkle at its slab's sun
  THEME_AT 0.12 after the far bank's `bank`; the solve's flourish waits
  THEME_SHIFT 0.2 more. The win card waits THEME_HOLD 0.45 longer.
- **The win**: `SS_WIN_THEME` ("Today's word: SMOKE! Across in 5 stones.
  At par!"); a route word the player's way went round is named as
  `SS_WIN_THEME_WAY` ("Today's word hid on the way: %s. %s"). Words are
  shown as written (`written()`: MAÇÃ). `day_dict` says
  `"source": "theme"` and `"theme"` (the written word). The completion
  record keeps the crossing (`from`, `to`) and `_theme`, and a reopened
  day whose deal has moved since (the night's words came in after it was
  played) is laid back on the record's crossing (`_redeal_as_played`).
- Draw calls (opengl3_angle 810x1440 `theme`): Easy en (TENT, near bank)
  89 rest, 91-102 play, 155 won; Hard en (SMOKE, far bank) 87 rest,
  87-121 play, 159 won; Easy `theme=moss` (a route stone) the same as
  Easy; pt `theme=maçã` 89-100, 155. The same as a plain day.
- Sound: new `theme` (the boards' wrap climbing 7/12/16); `lay` moved from
  the token to the bank's plop (the house sound: a thing set down on a
  water board), its treatment kept. Both unheard.
- Harness: `tests/_shot_stones.gd -- <dir> d=<n> theme|theme=<word>
  [lang=pt|es]`: the fixture pool (or one word) is set on the board's
  `static var theme_pool_override` before the board opens (Backend is not
  started in a `--script` run), shots are prefixed `theme_` and add
  `theme_reach` (the crossing's sun sparkling) and `theme_stone` (a route
  word laid again after the bin, when the run gets that far; on
  `d=0 theme=moss` the bulb crosses first, and `theme_laid` shows the
  toast). `lang` sets `Locale._current`, saving nothing.
- `tests/_win.gd stones` reports FAIL: `_win.gd` has no Stepping Stones
  solver (none of the 2026-11-04 word boards has one); the board's own
  probes and the shot harness cross it.
- Owed: phone, ear (`theme`, the new `lay`), pt/es native read of the
  three lines, reduce motion written (the sun is baked, nothing pulses)
  but unseen.
