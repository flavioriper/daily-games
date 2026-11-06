# Garden Fence

- **Garden Fence is a Puzzles card (2026-11-04)**, the fifth and last of
  `docs/roadmap-word-boards.md`, under Words, after Stepping Stones. A
  garden bed on a lawn with a low fence round it, three posts a side, a
  letter on each post's cap; string twine post to post to spell words,
  never two posts in a row from one side, each word starting on the post the
  last one ended on, until every post is in bloom. Spec
  `docs/superpowers/specs/2026-11-04-garden-fence-design.md`. Id `fence`,
  prefix `FN_` (`GF_` is Mini Golf's). Built unattended at the user's word,
  with no concept tab first, as the four before it were.
- Files: `puzzles/fence2d.gd`, `puzzles/fence_state.gd`,
  `puzzles/fence_world.gd`, `ui/faces/fence_art.gd` (lawn, bed, sprout,
  post, daisy, twine, knot, gate, sign, tag),
  `ui/hud/fence_tutorial_diagram.gd`, `ui/menu/cards/fence.gd`,
  `tools/build_fence.py`, `content/fence_words[.lang].json`,
  `content/insane/fence*.json`.
- **Words**: `tools/build_fence.py <dicts> <cache>` reads Biscuit Tin's
  pruned wordfreq cache (`build_biscuit.lexicon` + `proper`) and looks up
  three-letter words itself (cached as `fence_lex3_<lang>.json`: in the
  Hunspell dictionary in lower case only, so no abbreviations). Words with a
  letter twice in a row are dropped (a fence never strings them). One word
  list a language ships (0.4 MB en, ~1 MB pt/es), grouped by first letter;
  the state filters it by the day's posts at load. Per-fence lists were
  4-5 MB a band. `CRUDE` words are taken but never offered or on a route.
  A full build of the three languages takes a few minutes (the pentagon is
  the slow band: every word a fence takes is read for a two-word chain).
- **Banks**: 365 fences a band a language. Seeds: two common words (three
  on the pentagon) chaining last letter to first and using exactly the
  fence's letters, each seed twice a bank at most; letters shared three a
  side by a backtracking colouring. The par is the seed's length, proved
  over every word the fence takes (`fewest`: largest letter sets only, with
  a count bound), not only the fair ones. Easy a triangle (9, par 2),
  Medium a square (12, par 2), Hard a pentagon (15, par 3), Insane a square
  with a gate post the last word must end on (par 2 counting the gate).
- **Input**: tap a post to string it, or press and drag across posts (back
  over the post before takes the last strand off); tap the trail's last
  post again, or the sign, to tie. A post from the last one's side shivers
  with the tongue; while a trail is open that side's letters are dimmed.
  The twine is gold while the trail spells a word the garden knows (the
  `ready` wrap sounds as it turns), so the player knows when a knot takes.
- **Undo** takes back a letter, or with none past the joint unties the last
  word (its twine recoils); the bin unties them all. Free: only the words
  tied at the solve count.
- **Stars**: words tied plus the fewest still to go (searched two deep over
  the fair words, three past that), 3 up to par + 1, 2 up to par + 3.
  `quality()` counts a bulb's word twice. A party at par with no bulb.
- **The bulb** (two presses): the first rings the next word's first and last
  posts and says its length (from nothing tied, the route's first word; a
  dead end names the word to untie); the second strings it a post at a time
  and ties it, its tag edged blue. The three-word search has a budget
  (`BUDGET` middle words, the starts that string the most new posts first);
  past it, the word from the joint that strings the most new posts.
- **Meshes**: the bed and rail one mesh a layout; each post's plain and used
  mesh cached and drawn under its transform; the tied twine one mesh while
  the words stand; the trail one mesh while it stands (its newest strand
  grows on its own); passing meshes are held in `_frame` until the next
  draw (a mesh let go of inside `_draw` is freed before it renders: the
  first harness run printed "mesh is null" every frame).
- Probes (headless): `tests/_probe_fence.gd` (every bank in every language:
  three posts a side, letters once, the route strings, chains and is par
  long, a hand tying it solves at par, the bulb alone solves; prints the
  load and bulb times), `tests/_probe_fence_board.gd` (the board under
  `demo_tap`: strung, side refused, short refused, tie, chain, unknown
  refused and kept, Undo a letter then a word, the bulb's two presses, the
  bin, the route solves, restore, Insane's gate, the pentagon, the
  triangle).
- Harness: `tests/_shot_fence.gd -- <dir> d=<0..3> [tut=<page>] [at=<f>] [card]`.
- Owed: the user's eye and ear (every cue unheard), a phone (post size at
  the pentagon, drag feel, load time of the pt/es lists), pt/es read by a
  native speaker (the locale rows and the seed words), the word lists read
  by a person, the website's game list (`web/scripts/gen_games.py`) not
  regenerated.

## The daily theme (2026-11-06)

A fence's route words (two or three long seeds) almost never are theme
words (the lead's 25 nights: 0-4 fences a band), so a fence counts as
themed when a theme word **can be strung on it** by the board's own rules
and the board would take it.

- **The deal**: on a daily dealt from its day (`bank_step == 0`,
  `daily_key != 0`, never the tutorial's fence) the board takes
  `ThemedPictures.theme_pool(daily_key)`, keeps the words the garden takes
  (`State.theme_accepted`: in the language's `fence_words` list, `fair` or
  `more`, and not `State.CRUDE`, a copy of `tools/build_fence.py`'s, since
  the shipped list does not mark them), and hands the band's bank to
  `ThemedPictures.bank_pick` with `State.theme_words` (every letter on a
  post, never two in a row from one side). The fence is dealt as banked:
  its posts, route and par never change. No hit deals as before.
  `State.theme_bits` (each word's letters as bits) skips a fence that lacks
  a letter before the side rule is read: the pick is 1.6 (Easy), 3.5
  (Medium), 6.3-8.9 (Hard), 3.1-5.0 (Insane) ms on this Mac; the first
  `theme_accepted` a session also loads the word list the board loads
  anyway (8 ms en, 19 ms pt).
- **Themed fences a band** with the fixture pool (2026-11-06's campfire
  night, the harness's): en 131 / 322 / 361 / 300 of 365; pt 172 / 339 /
  364 / 340. The strongest word wins (LANTERN on Easy, Medium and Insane,
  CAMPFIRE on Hard in en; LANTERNA, then FOGUEIRA in pt). Words with a
  letter twice in a row (wood, moss, kettle) are never on a fence.
- **The tease**: while the word is hidden a seed packet with a sun on it
  hangs by the sign's left end (in the sign's mesh), and THEME_TEASE_AT
  1.1 s after the fence comes in the line says `FN_SAY_THEME_HIDDEN`
  ("Today's word is hiding in the fence."). The word itself is never shown.
- **Found** (by hand or by the bulb): the word's twine is a rose ribbon a
  little wider than twine (RIBBON, a colour no twine state uses: green
  strung, gold known, jute tied) with a bow on its first strand that pops
  in over BOW_TIME 0.36 s; its seed tag gets a bow through its hole; the
  `theme` cue and a sparkle on each of its posts come THEME_CUE_AT 0.22 s
  after the tie; the line says `FN_SAY_THEME` ("Today's word: LANTERN!")
  in place of the +N line (not when that tie solves: the win's line comes
  then). It counts as any word; stars, par and quality are untouched.
  Untied, the ribbon and bow go and the packet comes back.
- **The win**: found, the ribbon sparkles again with the confetti and the
  card waits THEME_HOLD 0.6 s longer; subtitle `FN_WIN_THEME` ("Today's
  word: LANTERN! In bloom with 2 words. At par!"). Not found:
  `FN_WIN_THEME_WAS` after the board's line ("... Today's word was
  LANTERN."). The word is shown as the list writes it (`written`: MAÇÃ,
  not MACA). A reopened day shows the ribbon if it was tied: the
  completion record keeps the fence's `posts` and `theme`, and
  `restore_completed_board` deals that fence back from the bank when the
  day's deal came out another (the cached day fetched or lost since;
  `theme=drop` in the harness). `day_dict` says `"source": "theme"`, `"theme": <word>`.
  Reduce: no pop, the bow and ribbon simply there.
- Draw calls, opengl3_angle 810x1440 `theme`: Easy 99-115 play, 178-179
  won; Medium 107-123, 188; Hard 113-129, 197. The ribbon is in the tied
  mesh, the packet in the sign's, the tag's bow in the tags'; the bow on
  the strand is one cached mesh (one call).
- Sound: new `theme` row (the boards' wrap climbing, as Pie's). The rest of
  the set read against "The house sound": no clear violation (pebble
  select, wrap repeats, lip take-backs, tongue refusals, token set-downs,
  breeze bulb, borrowed moments).
- Harness: `tests/_shot_fence.gd -- <dir> d=<n> theme [lang=pt|es]` hands
  the board the fixture pool through `theme_pool_seam` (a static set before
  the board is built, so the reopened day is themed too), prints every
  band's themed count and pick time, strings the word first
  (`theme_rest`, `theme_tease`, `theme_strung`, `theme_tied`,
  `theme_sparkle`, `theme_found`), then the bulb finishes; `theme=miss`
  never strings it (the softer line); `theme=drop` takes the pool away
  before the reopen. Backend never starts in a harness, so
  the real path finds no pool.
- `tests/_win.gd fence` FAILs: it has no `fence` solver (nor do the other
  2026-11-04 word boards), before and after this.
- Owed: phone, ear (`theme` unheard), pt/es native read of the four rows,
  es in a harness (ñ is a letter of its own there), the user's eye on the
  ribbon's rose and the packet.
