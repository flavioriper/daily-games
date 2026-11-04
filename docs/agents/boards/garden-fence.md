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
