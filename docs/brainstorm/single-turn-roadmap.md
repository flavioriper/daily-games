# Single-turn minigames — roadmap

Status: roadmap drawn from the Playlin top-ten study
(`docs/brainstorm/playlin-top10.html`), 2026-09-17. Not a spec. Each phase
gets its own design and plan through the normal flow before code.

## Scope

**A single turn** is one committed input a day, an immediate reveal, and a
graded result. Never pass or fail: a bad day still produces a number and a
picture worth posting.

**Three languages from day one:** English, Portuguese, Spanish. A game
either treats language as a label (translate strings, done) or as content
(three native versions a day, forever). The roadmap prefers the first kind
and admits the second kind only where the payoff is the whole game.

**Server, database, dictionaries and LLMs are allowed.** Firebase project
`peeplet-daily` already holds analytics and App Distribution; the backend
grows there.

**Filtered out:** anything that depends on songs or films.

- Songless: a song catalogue is a licensing problem no server solves.
- Size It Up's Pop Culture pack: film characters and props. Only the
  original and geography sets are in scope.
- Krillion prompts about films, actors, songs or musicians. The prompt rule
  below bans them outright.
- Krillion's Themed Packs (movies) as a mode.

**Filtered out for the mechanic, not the content:** Poople (a ladder is
many moves), Loopy River (a board, already covered by the catalog's loop
family), 4 × 3's word version (three editorial jobs a day; its idea
survives as the visual hub in phase 5).

## The lineup

| Phase | Game | Source | Size | Why it sits here |
|---|---|---|---|---|
| 0 | Foundation | — | M | the reveal flow and the backend every turn reuses |
| 1 | How Big? | Size It Up | S | language-free, needs only our models and a size table |
| 2 | Colour the Flag | Vexle, build mode | M | language-free, exercises per-layer colouring and the gallery |
| 3 | One in a Krillion | Krillion, one prompt | L | the best share hook on the chart; forces the canonicaliser |
| 4 | Ballpark | Magnitudle | S | reuses phase 1's number reveal and phase 3's content pipeline |
| 5 | The Odd Hub | 4 × 3, visual | M | language-free, generator-only, no server dependency |
| 6 | One Dart | Dartwords, riddle first | L | embeddings, rank scoring, three riddles a day |
| bench | One Swap | Number Waffle | S | a filler warm-up; no server, can land any time |

Sizes are relative. S is a couple of sessions on top of the foundation, M
is a week of sessions, L includes a new service and a content routine.

---

## Phase 0 — Foundation

**Goal.** One shared flow and one shared backend, so each game after this
is a screen, a grader and a content source.

**Client.**

- A `TurnBase` beside `PuzzleBase3D`: states `input → lock → reveal → grade
  → share`. Input is locked once, no undo after lock, the reveal is a
  camera move on the stage, the grade is a 0 to 100 number drawn as a bar
  or a gauge, the share is text plus an image of the reveal.
- A network layer, sibling of `core/analytics.gd`: one `HTTPRequest`
  wrapper with an install ID (anonymous, generated once, stored in
  `user://`), idempotent submits keyed by install, day and game, and an
  offline path. Offline, the turn still plays and grades against the
  bundled prior; the submit syncs when the app is next online.
- Day key is the UTC date, exactly `Daily.date_key()`, so the crowd rolls
  over with the boards.
- Locale: `TranslationServer` for strings, locale-aware number parsing,
  metric everywhere, a `locale` parameter on every analytics event.
- Analytics events: `turn_lock`, `turn_reveal`, `turn_share`,
  `crowd_reveal_opened`. Same rule as today: nothing sends unless
  `Analytics.start()` ran.

**Server.**

- Firestore. Sketch:
  - `days/{yyyymmdd}/turns/{game}`: the published content for the day
    (prompt, answer set, prior).
  - `days/{yyyymmdd}/turns/{game}/submits/{install}`: one document per
    player, written once.
  - `days/{yyyymmdd}/turns/{game}/tally`: aggregated counts, updated by a
    function on submit.
- Cloud Functions or Cloud Run for submit, tally and the nightly publish
  job. Decide once (see decisions).
- A percentile endpoint: given a game, day and score, return "closer than
  N% of players". Phase 1 is its first customer.

**Done when** a stub turn (tap a button, get 50) plays end to end on the
phone, offline and online, and its submit shows up in the tally.

---

## Phase 1 — How Big? (Size It Up)

**Loop.** The scout stands on the dock at true scale. Beside him, a target
from our model set (horse, oak, tent, lantern, fox, later real-world
things) at a wrong size. Drag to scale it until it looks right. Lock. The
camera pulls back and the target snaps to its true size next to the
scout.

**Build.** Client: a scale gesture on a 3D instance, one lock. Content: a
table of real dimensions per model (height, length), translated labels
only. Server: percentile from phase 0.

**Grade.** Log ratio error. Twice too big and twice too small score the
same. Within 6% is 100, a factor of five or worse is 0; tune the curve on
the first week's tally, not by hand.

**Reveal and share.** Your guess as a ghost outline beside the true size,
the percentage off, "closer than N% of players". The share image is the
reveal frame.

**Languages.** Labels and units. Nothing else.

**Risks.** Depth cues: the target must stand on the same ground plane as
the scout so perspective does not lie. Pinch versus drag on Android; pick
one.

**Done when** a month of pairs is in the table and a week of tallies shows
a spread, not a spike at 100.

---

## Phase 2 — Colour the Flag (Vexle, build mode)

**Loop.** A grey flag with six to eight regions on a plank. Tap a region,
tap a palette colour. Lock. The real flag drops in beside it.

**Build.** Client: region meshes on a plank, one material per region (the
one-mesh-per-layer rule already does this), palette of eight to twelve
colours. Content: flags as simplified region maps, built once from
public-domain SVG; countries whose flags need more than eight regions or
an emblem are skipped or reduced to their fields. Server: percentile,
plus storage of the coloured result for the gallery.

**Grade.** Regions right over regions total, weighted by area.

**Reveal and share.** Yours beside the real one. The gallery shows a
dozen other players' attempts for the same day, which is the second-best
share card on the chart. Later, "colour the scout from memory" reuses the
whole thing on a mascot.

**Languages.** Country names.

**Risks.** Moderation: a flag with eight regions and twelve colours can be
made offensive. An image classifier gates the gallery; nothing shows to
others unmoderated. Emblems: Brazil's motto band and Mexico's eagle do not
survive simplification; either accept reduced flags or skip those
countries on this game.

**Done when** 60 flags are mapped and the gallery has shown a week of
moderated results.

---

## Phase 3 — One in a Krillion (Krillion, one prompt)

**Loop.** One category prompt a day. Type one answer under a timer. Lock.
The dive: your answer's rarity tier and depth, then the crowd's answers as
a school of fish, common ones near the surface, yours marked.

**Build.**

- Client: text input with the on-screen keyboard, a timer, the depth
  gauge on the stage (the river is right there).
- Server: the canonicaliser. Normalise (case, whitespace, keep diacritics
  for display, fold them for matching), then map the string to one entity
  with the LLM, ideally a Wikidata ID, cached by prompt, language and
  string. Closed categories (countries, elements) match against a curated
  list first and only fall back to the LLM. Tally counts entities, not
  strings.
- Content pipeline: a nightly job drafts prompts, a person approves them
  in a review queue, nothing publishes unreviewed. Each prompt ships with
  an LLM-estimated popularity prior over the likely answers.
- Prompt rules: the answer space is entities, never words ("a word for a
  baby animal" fails in Portuguese). Answerable from all three cultures.
  No films, actors, songs, musicians, TV. No people who are alive and
  private.

**Grade.** Global rarity, one pool across languages, six tiers as on the
chart. Cold start: blend the prior with the live count, weighted toward
the live count as it grows. The reveal shows the split by language;
"obvious in Brazil, rare in Spain" is the card people post.

**Reveal timing.** Two options, decide in the design: immediate against
the blended prior, or a provisional tier now and the true crowd tier
pushed in the evening. The push is a second daily open.

**Languages.** The whole design is built for it. Watch the locale split
in analytics; if one locale passes about 80% of players, switch rarity to
within-language pools.

**Risks.** LLM validation of open categories will be wrong sometimes;
log every rejection for review, and let a rejected answer score Plankton
rather than zero on appeal. Cost: one LLM call per uncached string, so
the cache and the curated lists matter. Abuse: the crowd's answer list is
user text shown to others; moderate before display.

**Done when** thirty prompts are approved ahead, the canonicaliser's cache
hit rate is above 80% after week one, and the tier distribution looks
like a pyramid rather than a slab.

---

## Phase 4 — Ballpark (Magnitudle)

**Loop.** One "how many, how big" question. Type a number with ×1K to ×1Q
buttons. Lock. A log ruler shows your number, the answer, and the crowd's
curve.

**Build.** Client: phase 1's number reveal with a log ruler, locale number
parsing from phase 0. Content: phase 3's pipeline drafts questions in
three languages; every answer carries a cited source and a person checks
it. Server: tally of guesses for the crowd curve.

**Grade.** Logarithmic, out of 100: within a factor of two or three is
90 plus, one order of magnitude off is 70 to 80, two orders 50 to 60.

**Languages.** Questions translate because they are facts. Units metric.
Number formatting differs (1.000,5 versus 1,000.5); parse per locale.

**Risks.** An unsourced answer is the one thing this game cannot survive.
No question publishes without a citation in the review queue. Questions
that depend on a country ("how many people live in your capital") are
banned; the answer must be one number for everyone.

**Done when** a month of sourced questions is approved ahead.

---

## Phase 5 — The Odd Hub (4 × 3, visual)

**Loop.** Nine toon pieces on the board, differing by colour, shape, size
and pattern. Four groups of three share one attribute each. Exactly one
piece is in all four groups. Tap it. Lock. The groups light up one by one
and the hub glows.

**Build.** Client: a 3 × 3 arrangement of instanced pieces; the Code Break
palette pieces are a starting point. Generator: pick the hub's four
attributes, pick two partners per attribute that share it and nothing
else, then verify no other piece satisfies all four. Build-then-check,
the same shape as the catalog's Tier 1. No server needed; percentile is
optional.

**Grade.** Right or wrong is too flat for a turn. Score by time to lock
against the crowd's median, or offer a second tap at half points.
Decide in the design.

**Languages.** None on screen.

**Risks.** Colour as an attribute needs a colour-blind-safe set plus
patterns that carry the same information. Attribute overload: four axes
on nine pieces gets busy; the pieces have to read at phone size.

**Done when** the generator produces a month of boards with one hub each
and the pieces pass a colour-blind check.

---

## Phase 6 — One Dart (Dartwords, riddle first)

**Loop.** Read the day's riddle. Type one word. Throw. Your dart lands on
the board by closeness in meaning; the crowd's darts appear as a heat
map.

**Build.** Server: an embedding service with a multilingual model, a
vocabulary per language, and rank scoring: the guess's rank among that
language's words by closeness to the secret. Content: the pipeline picks
a secret that exists as one plain word in all three languages and drafts
a riddle natively three times; review checks that no version leaks more
(grammatical gender is the usual leak). Client: the board, the throw, the
heat map.

**Grade.** Rank mapped to rings. Bullseye is the word itself, the next
ring the top ten, and so on.

**Languages.** Cross-language cosine distances are not comparable, hence
rank inside the guesser's language. Word validation per language uses
the vocabulary, not the LLM.

**Risks.** Three riddles a day is the heaviest content routine on this
list, which is why it is last. Embedding oddities: proper nouns and
plurals sit strangely; fold plurals before scoring.

**Done when** a month of secrets and riddles is approved ahead and the
rank distribution of guesses looks similar across the three languages.

---

## Bench — One Swap (Number Waffle)

A Latin square one swap from solved. Tap two cells. Provable by trying
every swap, digits only, no server. A warm-up filler for any day that
needs one; not a headline.

---

## Cross-cutting

**Backend.** Firestore plus Cloud Functions or Cloud Run in
`peeplet-daily`. Anonymous install IDs, no accounts, one submit per
install per day per game. Rules deny reads of other players' submits;
the client only ever reads the published content and the tally.

**Content pipeline.** One nightly job, one review queue, one publish
flag. Phases 3, 4 and 6 depend on it; phases 1, 2 and 5 do not. Content
is prepared at least two weeks ahead so a missed review night is not a
blank day.

**Prior and cold start.** Every crowd-scored game ships a prior with the
day's content and blends it with the live tally. The blend weight follows
the number of submits so the first player and the thousandth see the same
kind of result.

**Moderation.** Text through an LLM classifier covering all three
languages before it is shown to anyone else. Images through a vision
classifier. Anything flagged is hidden, never deleted, so it can be
reviewed.

**Localisation in the client.** Strings through `TranslationServer`.
The carved signs upper-case titles; Portuguese and Spanish keep accents
on capitals, so the display font's É, Ã, Ç and Ñ need checking in
TextMesh before a localised title goes on a board.

**Where the turn lives.** Decision below. The candidates: a bonus on the
camp after the day's board, or a warm-up before it. Either way the
progress file and streak logic need to know whether a turn counts as a
day played.

---

## Decisions before phase 0

1. Where the turn lives: camp bonus after the board, or warm-up before
   it. Changes the menu and whether streaks count it.
2. Crowd reveal timing: immediate against the prior, or provisional now
   and the true tier pushed later.
3. Who reviews content in three languages, and how often. Phases 3, 4
   and 6 are blocked without an answer.
4. Cloud Functions or Cloud Run.
5. Whether phase 5 is scored by time or by a half-points second tap.

## Out, in one line each

- Songless: song catalogue, licensing.
- Poople: a ladder is many moves; a dictionary per language on top.
- Loopy River: a board, covered by the catalog's loop entries.
- 4 × 3 word version: three native puzzles a day, forever.
- Size It Up Pop Culture, Krillion movie packs: the film and song filter.
