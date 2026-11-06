# Four Shelves

- **Four Shelves is a Puzzles card (2026-10-22)**, roadmap item 4, under
  Words. Jam jars on a pantry dresser hide shelves of four; pick four and
  shelve them, four hearts a day. Spec
  `docs/superpowers/specs/2026-10-22-shelves-design.md`. Id `shelves`,
  prefix `FS_`.
- Files: `puzzles/shelves2d.gd`, `puzzles/shelves_state.gd`,
  `puzzles/shelves_world.gd`, `ui/faces/shelves_art.gd` (jar, halo, plank,
  shelf, the hearts drawn straight), `ui/hud/shelves_tutorial_diagram.gd`,
  `ui/menu/cards/shelves.gd`; the night's `server/functions/src/shelves.ts`.
  The keys under the dresser are Honeycomb's (`honeycomb_art.gd`'s `key`).
- **The day is fetched as Golden Acorn's is** (`_deal`: the cached document,
  else one FETCH_WAIT on the network, else the bank), and `world/main.gd`
  fetches it at boot and the next day's ahead (`AHEAD`).
- **The bank pick is the server's**: least double FNV of
  `shelves|<day>|<id>`. Change one and change both.
- **A revealed day is not a solve**: `is_solved()` is false once any shelf
  went up by Show the shelves; the reveal ends with `finish_unsolved`. The
  card's queued opening checks `_revealing`, or it opened over the reveal.
- The tutorial deals the bank's first puzzle of Easy (Insane for CROWDED),
  so a new bank changes its words.
- Harness: `tests/_win.gd -- shelves` (real touches: a close four, the same
  four again, Clear, the bulb's real button, every shelf);
  `tests/_shot_shelves.gd -- <dir> d=<0..3> [tut=<page>|card|out]`.
  `tests/_probe_shelves.gd` prints the bank's picks and plays the rules.
- Draw calls: 100-129 in play, 140-177 a tutorial page, 6 on the card.
- **Made fun (2026-10-28, the user: "right now nobody likes it")**. The
  cause was the content: the first bank had no red herrings at all (one
  idea a group, "Musical instruments: DRUM FLUTE PIANO VIOLIN" in four
  puzzles), because the blind reviewer's `sure` gate turned down every board
  that made it hesitate, which is every board with a real decoy.
  - The night (`shelves.ts`): the writer names its red herrings
    (`traps`, a word and the group it seems to fit, `TRAPS` = 1/3/4/5 a
    band in every language, at most 8) and is told the fun is being fooled;
    the tired ideas are banned by name (`STOCK`), at most one plain "kinds
    of X" past Easy. The reviewer solves as a player, says how often it was
    `fooled` (past Easy it must be fooled once) and may call a board `dull`;
    `sure` is gone. Shelves are re-ordered as the reviewer found them, so
    the plank colours climb with real difficulty. The bands are written side
    by side with a second try each (the half-hour budget).
  - Writer: the night stays on Haiku (the new brief makes it decent, US$0.13
    for two Hard boards). The bank's Hard and Insane were written by Opus
    (`DAILY_MODEL=anthropic/claude-opus-5.5`, ~US$0.50 a board, much
    better: "An animal hides inside: BATTER SCATTER COWARD PIGMENT" beside
    card games with SNAP and HEARTS).
  - The board: Shelve makes the four hop one after another, a pop each a
    little higher, and only then judges (`JUDGE_*`; a repeat and reduce
    motion judge at once); a picked jar is full of jam with its label dyed
    (`JAM`); a shelf going up fills its jars with its colour; a shelf up is
    cheered (`FS_CHEER_1..6`, `FS_SNEAKY` for the day's subtlest); a wrong
    four's line varies (`FS_WRONG*`); with one shelf left it goes up by
    itself (`_last_up`, counted as the player's guess, `FS_LAST`).
  - Bank 16/16/12/11 (Insane by Haiku, ib003 dropped by hand for "JUKEBOX" under "Words before box").
  - Not deployed: the night's new prompts need `tools/deploy_functions.sh`
    (a person runs it); until then the nightly days are the old writer's.
- **The day's theme shelf (2026-11-06, daily-theme roadmap wave 1).** On a
  themed day the night's writer (`shelves.ts` `themeAsk`) makes one plain
  group of every board the theme's: four things of its scene, the board's
  most obvious group, labelled with the place in warm words (never the
  theme's bare title), and at least one red herring of another group that
  seems to belong on it. The group carries `"theme": true`; the blind
  reviewer is never told. `themeFirst` puts that shelf first in every
  language (the day card prints the theme, so the player sorts it first and
  it wears the first plank), and drops the flag when a language has none or
  more than one; the log says when the reviewer did not find it first. A
  band tries again for a themed board and takes a plain one only when the
  second try has none. Bank puzzles never carry the flag.
  - The board: a theme shelf wears a paper rosette with a star at its left
    end (`shelves_art.gd` `rosette`, its own colours, never the plank's
    shade: the shelves are coloured by index), its label and words keep
    clear of it (72% of the plank), and going up it is rung and sparkled
    `THEME_PIN` after the rise with the `theme` cue (the shelf's wraps
    carried up an octave, `bank:wrap` 7,12,16) and the line `FS_THEME`.
  - Harness: `tests/_shot_shelves.gd -- <dir> d=1 theme` marks the first
    shelf the theme's. 113-155 draw calls.
  - Unheard; the night's writer is undeployed until a person runs
    `tools/deploy_functions.sh`, and the first themed board is the first
    day published after that.
- **The gate and the writer, fixed 2026-11-06** (the user: "fix it", after
  ~30 smoke drafts on the Neon AI Gateway passed none, themed or not):
  - A blind sort that differs is no longer fatal: being fooled is the
    game. Those languages go to a sighted check (`check`, `CHECKER`, one
    Sonnet ask a band) shown the intended groups only (shown the blind
    sort too, it called everything ambiguous), which must write out an
    other complete sorting to call it not unique, and says `wrong` when a
    word does not fit its own label. What the blind pass says of a group it
    never found (obscure, ambiguous) is the check's to judge; unsuitable
    stands. Order stays the writer's when the blind sort differs.
  - Red herrings: English needs the band's `TRAPS`, pt/es one fewer.
  - No letter tricks (hidden words, letters, sounds, rhymes): the model
    cannot see inside words and almost every `wrong` was one. pt/es never
    get a partner-word group (they came out as English compounds put into
    other words: "palavras antes de 'quente'"); they use double meanings,
    things you can do to something, roles.
  - The theme shelf is asked as a precise idea of the scene in the
    writer's own words (an example in the ask was copied by every draft).
  - Result: Medium/Hard themed, 1 of 6 drafts passed (a band has 6 a
    night), against 0 of ~30 before: "Camping gear you pack / Sweet treats
    / Words before 'fly' / Things you can break". Tested by
    `writeBand` alone, never the whole night.
