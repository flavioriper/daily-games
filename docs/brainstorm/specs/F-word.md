# Family F — Word & Language (62-69)

Every entry here is **language-locked**. That single property dominates all their other
characteristics, so read this first:

Shipping a word puzzle globally means, *per locale*: a curated and licensed wordlist,
a frequency/obscurity ranking so difficulty is calibrated (a word that's common in
Portuguese is not common in English), an offensive-word blocklist, a separate difficulty
curve, and — for the authored puzzles (63, 67, 69) — a human writing content every day,
forever, in that language. That is not a feature you build once. It is an ongoing
editorial operation, and it is the reason NYT employs puzzle editors.

Launching in one language only is a legitimate choice. But note it makes the *market*
one language, which for Brazilian Portuguese is a much smaller audience than the
language-free families reach with the same build.

---

## 62. Wordle-like guess

**Rules.** Guess the hidden word. Each guess tells you which letters are right and in the right place.
**Params.** Word length, guess budget, whether guesses must be real words, hard mode.
**Generator.** Pick from a curated answer list. The answer list and the (much larger) accepted-guess list must be separate — that distinction is what stops obscure words being answers while still accepting them as guesses.
**Uniqueness.** Not applicable. What matters is calibration: simulate a solver to check the answer is findable within the budget from a typical opener.
**Touch.** On-screen keyboard with per-letter colour state. Well-understood pattern.
**Round.** 2-4 min.
**Share.** The emoji grid — the most successful share mechanic in the history of casual games, and the reason Wordle spread.
**Risk.** Overwhelming saturation. There are thousands of clones in every app store and every language, most free and browser-based. Entering here means competing on brand and polish alone, with no mechanical advantage. Also note entry 20 (Mastermind) is structurally the same game with an identical share grid and zero language cost.

## 63. Connections-like grouping

**Rules.** Find the four groups of four that belong together.
**Params.** Grid size (16), category count, how many deliberate red-herring overlaps.
**Generator.** **Not generatable.** The entire craft is in the misdirection — a word that plausibly belongs to two categories — and that judgement is semantic, cultural, and current. Automated attempts produce either trivially separable groups or nonsense.
**Uniqueness.** Authored and hand-verified.
**Touch.** Tap four, submit. Clean.
**Round.** 3-5 min.
**Share.** Coloured row grid; shares very well.
**Risk.** This is a *permanent daily editorial job* in every language you ship. Extremely popular and extremely good, but it is a publishing business, not a software project. Recommend against for a solo developer.

## 64. Anagram unscramble

**Rules.** Rearrange the letters to make a word.
**Params.** Word length, letter-set ambiguity.
**Generator.** Pick a word, shuffle. Check that no *other* word uses the same multiset of letters, or accept any valid anagram as correct.
**Uniqueness.** Checkable against the dictionary by comparing sorted letter multisets.
**Touch.** Drag letter tiles into slots.
**Round.** 30-60s.
**Share.** Time.
**Risk.** Cheap to build, and it feels cheap — anagrams are a rote skill with little depth. Combined with the per-locale dictionary cost, the value-for-effort ratio is poor.

## 65. Word ladder

**Rules.** Change one letter at a time, making a real word at every step, to get from the first word to the last.
**Params.** Word length, ladder length, whether intermediate steps are hinted.
**Generator.** Build a graph over same-length dictionary words with an edge for every one-letter change, then take pairs at the desired shortest-path distance. The graph is precomputed once per locale.
**Uniqueness.** Shortest path length is exact via BFS; multiple ladders of equal length usually exist, which is fine.
**Touch.** Tap a position, tap a letter.
**Round.** 90s-3 min.
**Share.** Step count versus optimum.
**Risk.** The word graph is sparse and *very* dictionary-sensitive — whether a marginal word is included changes which puzzles are solvable at all. Players who don't know an obscure required word are simply stuck, with no way to reason it out. That failure mode is much worse than in Wordle, where guesses still yield information.

## 66. Strands-like themed word search

**Rules.** Find the themed words hidden in the grid. They can bend.
**Params.** Grid size, word count, whether every letter must be used.
**Generator.** Grid packing is automatable. The *theme and word set* are authored — that's what makes it a puzzle rather than a search.
**Uniqueness.** Packing is verifiable; theme quality is not.
**Touch.** Drag across letters. Good gesture.
**Round.** 3-6 min.
**Share.** Hint usage grid.
**Risk.** Same editorial treadmill as Connections, though lighter — the theme carries less weight than Connections' misdirection does. Still a daily human job per locale.

## 67. Mini crossword

**Rules.** Fill the grid from the clues.
**Params.** Grid size (5x5), symmetry, black-square count.
**Generator.** Grid *filling* is automatable with a good wordlist and backtracking. **Clue writing is not.** A crossword's quality is entirely in its clues, and machine-generated clues are transparently bad.
**Uniqueness.** Fill is verifiable; clue fairness is not.
**Touch.** Tap a cell, type on a keyboard, with clue banners above. A well-trodden but detail-heavy UI — direction toggling, auto-advance, clue navigation.
**Round.** 2-5 min.
**Share.** Time. The NYT Mini's leaderboard *is* its social layer, and it works.
**Risk.** The heaviest editorial and UI cost in the catalog combined. A full-time job at NYT. Recommend against.

## 68. Letter Boxed

**Rules.** Spell words using the letters around the square. Consecutive letters can't come from the same side. Each word starts with the last letter of the one before. Use every letter.
**Params.** Letters per side (3), target word count.
**Generator.** Choose a letter arrangement, then verify by search that a solution exists within the word budget. The arrangement is generatable; verification needs the dictionary.
**Uniqueness.** Many solutions typically exist; the minimum word count is the scored quantity, computable by search.
**Touch.** Tap letters around the perimeter. Distinctive and attractive layout.
**Round.** 3-6 min.
**Share.** Word count versus the published best.
**Risk.** Genuinely elegant, and the most mechanically interesting entry in this family. Still fully dictionary-bound, and solution quality varies hugely with the wordlist. Solve times have high variance, which fights the 1-2 minute round budget.

## 69. Cryptic clue, single

**Rules.** One cryptic clue. One answer. The clue contains both a definition and a wordplay route to the same answer.
**Params.** Clue type (anagram, hidden word, charade, container, homophone, double definition), answer length.
**Generator.** Anagram and hidden-word clues are *partly* machine-generatable; everything that makes cryptics delightful is not.
**Uniqueness.** Authored.
**Touch.** Keyboard entry with letter-count hints.
**Round.** 1-5 min, enormous variance.
**Share.** Solved plus time.
**Risk.** Tiny addressable audience (cryptics are a British and Commonwealth tradition, near-unknown in Brazil and largely unknown in the US), fully authored, and the conventions take months to learn. Charming, entirely unscalable. Recommend against.
