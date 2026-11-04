# Roadmap: the next word boards

Started 2026-11-04 (the user: "check on web for more great wording games to
add"). Five Puzzles-grid boards under Words, chosen from what the web's daily
word games do that the Words row does not yet, and from what the house's own
word lists can generate without a writer. The proposal page with a drawn mock
of each board is `docs/brainstorm/next-word-boards.html`, published at
https://claude.ai/artifact/Sa35iz8AFcaDGVrRzx1poY.

Nothing here is built or specced. Each board follows the house order: a
concept tab in `docs/brainstorm/concepts.html`, then a spec, then the build
(`Registry.PUZZLES` entry under `"skill": "words"`, `skill_quality()`, locale
keys en/pt/es, pops from `tools/sfx_bank/`, four levels, stars, the
two-press bulb, a card, a tutorial). Names below are house names; the
original genre is named once, to forbid it in code, comments, commits and on
screen.

## Why these

The Words row on 2026-11-04: Hidden Word (Wordle), Word Trail (Strands),
Honeycomb (Spelling Bee), Four Shelves (Connections), Five Clues (Pinpoint),
Golden Acorn, Pearl Dive, How Big?: 8 of 39 cards. What the web recommends
this month mostly duplicates one of them: LinkedIn's Wend (June 2026) is
Word Trail, Squaredle and Blossom are Honeycomb, Termo/Letreco/Quordle/
Pairdle/Phrazle are Hidden Word, Conexo is Four Shelves.

The market read, candidly: GamesBeat reported that Pinpoint and Crossclimb
are LinkedIn's least played games and its last four releases were logic;
NYT's keepers are Connections, Spelling Bee, the Mini and Wordle; the indie
hits of the last two years (Waffle, Quartiles, Typeshift, Knotwords, Letter
Boxed) are made from a dictionary, no clue writer; the editorial hits
(Bracket City, Apple's Emoji Game, Crossclimb, crosswords) need an author
every day in three languages. Brazil knows Termo (450k a day by 2022) and
Contexto (Brazilian-made). Most "best word games 2026" pages are SEO lists
selling their own game. Four sources were read from search summaries only
(GamesBeat, Forbes, thinkygames, LinkedIn's Wend page refused the fetch).

## The lists the boards run on (counted 2026-11-04)

- Hidden Word answers, five letters: en 968, pt 746, es 762
  (`content/hidden_word*.json`); accept lists en 15,921, pt 26,792,
  es 31,208 (`content/hidden_word_accept*.txt`).
- Word Trail by length 3..8: en 108/160/199/222/272/171,
  pt 81/229/260/273/248/178, es 79/217/211/196/181/142
  (`content/word_trail*.json`). Thin for anything but dealing.
- Honeycomb dictionaries (wordfreq + spylls, rude lists applied):
  en 23,164, pt 33,098, es 34,206 (`content/honeycomb*.json`,
  `tools/build_honeycomb.py`). Any band that needs 4-, 6- or 7-letter
  words at volume takes a cut of these, not Word Trail's lists.

## Decide first (the user's calls, open)

- [ ] **A. Build order.** Proposed: Cross Stitch, Padlock, Biscuit Tin,
      Stepping Stones, Garden Fence.
- [ ] **B. How many.** Proposed: the first three now (Words 8 -> 11 of 42),
      two more if they earn their place after a week on the phone.
- [ ] **C. Hot and Cold** (Contexto): a concept tab of its own, decided
      separately; the only candidate with a server cost and a real pt
      audience.
- [ ] **D. Hidden Word Insane as four words** (Quordle): a mode, not a card.
- [ ] **E. House names** as written; none is the original's name.

## Shortlist (start here, in this order)

- [x] **1. Cross Stitch** (Waffle). Built 2026-11-04: spec
      `docs/superpowers/specs/2026-11-04-cross-stitch-design.md`, notes
      `docs/agents/boards/cross-stitch.md`. As proposed below, except Easy
      deals one across and one down word whole and Insane allows one more
      swap (16). Six five-letter words on a sampler,
      three across and three down crossing on a 5x5 with four holes; the
      letters are stitched in the wrong places; drag a letter onto another
      to swap; green sits, amber is on the right thread, grey a stray;
      fifteen swaps, a perfect solve ten. Runs on Hidden Word's answers.
      Generator easy: three across and three down agreeing on nine
      crossings, shuffled by a known number of swaps so the minimum is
      known. Stars: swaps left against the minimum. Levels: Easy 5x5 with
      two words given; Medium 5x5; Hard 5x5 with fewer swaps (a 7x7 is
      eight seven-letter words and needs a seven-letter Honeycomb cut, so
      not for the first pass); Insane *Loose Thread*: no amber. Shares as a
      colour grid.
- [x] **2. Padlock** (Typeshift). Built 2026-11-04: spec
      `docs/superpowers/specs/2026-11-04-padlock-design.md`, notes
      `docs/agents/boards/padlock.md`. As proposed below, except: the
      words come from wordfreq's lists (Hunspell-checked, rude words and
      names pruned; Honeycomb's own lists drop every S word) and each lock
      carries its words, so no dictionary ships; Hard takes five seeds and
      Insane six; three stars allow one word over par; the rusty dial
      comes round past its last letter so no lock is ever stuck.
      A combination padlock with letter dials;
      slide a dial so the window row spells a word; every letter on every
      dial belongs to a word; spell them all and the lock opens. One-thumb
      vertical drag, nothing to type. Runs on Hidden Word's answers for the
      five-letter bands and its accept lists to credit any other real word;
      four- and six-letter bands take a Honeycomb cut. Generator trivial:
      stack four to six answers by column, shuffle each dial, count every
      word the dials can make. Stars: dialled words against the minimum
      that uses every letter. Levels: Easy four-letter dials; Medium five;
      Hard six, deeper dials; Insane *Rusty Lock*: one dial only turns one
      way.
- [ ] **3. Biscuit Tin** (Quartiles). Twenty broken biscuit pieces, two to
      four letters each; tap pieces in order to make a word of one to four
      pieces; five whole biscuits of exactly four pieces are hidden; find
      all five and the tin is empty; shorter words score on the way. Runs
      on Honeycomb's dictionaries. Generator easy: five 8-13 letter words
      cut in four, every ordered combination of up to four pieces scored,
      a deal rejected if its chunks spell a rude word. Stars: points to the
      day's line, as Honeycomb's jar; all five is the solve. Levels: Easy
      three biscuits, bigger chunks; Medium five; Hard two-letter chunks;
      Insane *Crumbs*: a sixth biscuit's pieces mixed in and never fitting.
      (The published mock's tin shows one whole biscuit; redraw it from
      five real words for the concept tab.)
- [ ] **4. Stepping Stones** (word ladder; Weaver, Crossclimb). A brook
      with a word on each bank; each stone is a word one letter from the
      last; reach the far bank in few stones; any real word is a stone.
      Phone keyboard as Five Clues types. Needs a four-letter cut of the
      Honeycomb dictionaries (Word Trail's 4s are 160/229/217, too thin);
      the accept lists judge typed stones. Generator easy: BFS over the
      one-letter-apart graph, deal pairs with shortest path 4-6 and several
      routes. Stars: stones against the shortest, Market Sums' metric.
      Levels: Easy three stones with the middle given; Medium four letters;
      Hard five letters; Insane *Slippery*: a stone may also swap two
      neighbours. Later, when the night can write again, a clue a stone
      makes a Hard band that plays like Crossclimb.
- [ ] **5. Garden Fence** (Letter Boxed). Twelve letters on the posts of a
      square fence, three a side; string words post to post, never two in a
      row from one side, each word starting with the last letter of the
      one before; use every post. Longest round here (3-6 min). Runs on
      Honeycomb's dictionaries. Generator moderate: deal twelve letters,
      prove a two-word solution (the par), reject deals whose best is worse
      than three. Stars: words against par. Levels: Easy a triangle of nine
      posts; Medium the square; Hard a pentagon; Insane *Gate*: one post
      must be the last letter used.

## Authored content, ranked below

Each needs words written every day in three languages by the night
pipeline (Haiku writes, Opus reviews), which is unpaid since 2026-10-29 and
mid-move. After the five above, and only once the night is paid for.

- [ ] **Hot and Cold** (Contexto, Semantle). Nothing written: a ranking of
      ~20k words by closeness of meaning to the day's word, per language,
      from embeddings at night, shipped as a day document; a guess shows its
      rank. Strong in pt; a round is 30-100 guesses and the embeddings are a
      new server dependency. Call C.
- [ ] **Clued Stepping Stones** (Crossclimb): a Hard band of 4, one clue a
      stone.
- [ ] **Mini crossword** (the NYT Mini): a 5x5 grid from the lists is list
      work; ten clues a day in three languages, each reviewed, is the cost.
- Matryoshka (Bracket City): no. English idiom nested in English idiom;
  does not translate.
- Emoji phrases (Apple's Emoji Game): no. Puns do not cross languages, and
  the house draws its own characters.

## Left out on purpose

Wend, Squaredle, Blossom, Conexo, Quordle, Pairdle, Phrazle, Crosswordle:
already a card or a mode. Redactle: English encyclopedia, twenty minutes.
Tiled Words: needs clues, and the rotation is Pinwheel's. Newspaper anagram
jumble: Honeycomb and Padlock cover it. Any guess-and-feedback code board:
removed 2026-10-13, not to be re-proposed.
