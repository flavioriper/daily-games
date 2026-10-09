# Pearl Dive

- **Pearl Dive is the thirty-fourth card** (2026-10-09,
  `puzzles/pearl2d.gd`, `puzzles/pearl_state.gd`, `ui/faces/pearl_art.gd`;
  no spec and no concept tab -- asked for and built in one sitting, "no
  questions do it autonomous"). A prompt on a card of paper names a kind of
  thing; the player types one on the keyboard under the card; the rarer the
  answer, the deeper a diving bell goes down the water beside the paper. The
  puzzle id is `pearl`.
- **The game it follows is Krillion, and that name goes nowhere else**: not
  in code, comments, commits or on screen. Its rules were looked up on
  2026-10-09 (its listing page, its own FAQ and two third-party listings; it
  was not played): seven prompts a day, the same for everybody, one answer a
  prompt against a clock, a wrong answer costing a little time, six tiers of
  rarity worth 10 to 100 points with one designated top answer a prompt, the
  points shown as a depth, an endless mode on one tank of air that answers
  refill, and loose matching (accents, plurals, spellings). **Its FAQ says
  rarity is authored, not counted from players** (answer sets merged from
  reference sources, tiers by a familiarity database or a model plus a hand
  review), which is what lets ours ship a bank and play offline. Ours keeps
  the one answer a prompt, the clock, the cost of a miss, the tiers, the one
  top answer (the Pearl) and the tank as Insane. Left out on purpose: the
  sixth tier (an answer that only sounds obscure), points (the depth is the
  score, in metres), the ocean's named zones and landmarks, an archive,
  themed packs, friends, and any count of what other players said.
- **The original's tagline plays on its name; ours must not echo it.** The
  first motto written here was "One in a million?" and was changed for that
  reason to "The rarer, the deeper."
- **Its prompts are written by a model, every day**, the second board on
  Golden Acorn's contract: `publishDay` asks through OpenRouter, a second
  model reviews, and the phone reads the document
  (`docs/agents/turns-and-backend.md`, "Pearl Dive, the second game on the contract"). The
  board itself never talks to a model.
- **One move**: a line typed and Enter. The tray is Hidden Word's keyboard
  (`"tray": "keys"`, no actions row, no tip card), so the host sends
  `type_letter`, `erase_letter` and `commit_row`, and the board asks the
  tray to `match_locale()` and `clear_marks()` when it is handed over.
  **Enter is every move there is**: it dives (the card stands ready first,
  with the clock full, so the clock never runs while a rule is being read),
  offers the line, and once an answer is out asks the next prompt -- after
  the last, it ends the day, so the last answer can be read. A tap on the
  card does the first and the last of those too. No Undo, no Check;
  **Reset has nothing to give** (`can_reset()` is false): an answer is final
  and a prompt is not asked twice.
- **An answer**: the first line the list holds ends the prompt (so a player
  thinks before sending: the obvious answer spends the prompt). A line the
  list does not hold costs `MISS_COST` (3 s), shivers the field, is named in
  a toast and cleared, and the prompt goes on. Enter on an empty line is
  refused with a line and costs nothing. A clock that runs out leaves the
  prompt **dry** (0 m).
- **What a line matches** (`State.find`): both sides are folded by
  `State.norm` -- lower case, accents off, everything that is not a letter
  dropped, so spaces, hyphens and apostrophes do not matter and the keyboard
  needs no space key. First any form of an answer in the screen's language,
  then in the other two (a name typed in another language is still the
  thing), then, from five letters up, **one slip away** from a form in the
  screen's language (a letter wrong, missing, extra, or two swapped; the
  commoner answer when two are that near). No stemming: plurals and
  variants are forms the writer lists.
- **The depth** (`State.METRES`): 1 m for what everybody says, 3 for a
  well-known one, 6 for a rare one, 8 for a deep one and **10 for the Pearl**,
  exactly one answer of every prompt. The floor of the water is a Pearl a
  prompt (50, 60, 70, 80 m). After an answer the paper says its tier, names
  the Pearl, and two of the deep answers nobody gave (the same two for
  everybody that day, by the deal's key).
- **The bands** (`State.ASKS`, `State.SECONDS`): Easy is 5 prompts of
  everyday kinds at 30 s, Medium 6 at 25 s, Hard 7 narrower ones at 20 s,
  each its own daily. **Easy to Hard cannot be lost**: the day ends when
  the last prompt is answered or dry, and the depth is the result. The bulb
  tells the Pearl's first letter and how many letters it has
  (`State.tell`, once a prompt; two bulbs on Easy, one on Medium and Hard,
  none on Insane).
- **Insane is One Breath**: 8 prompts (three easy, three medium, two hard)
  on one tank of `AIR` (45 s) that runs only while a prompt stands. A right
  answer gives air back by its tier (`AIR_BACK`: 3, 6, 9, 12, 15 s), a miss
  costs the same 3 s, and the tank running out is the end: the out-of-hearts
  card with its own words (`ui/hud/out_of_hearts.gd` takes a fourth
  argument for a title and a button since this board: "Out of air", "More
  air"). **Try again is a new dive, not the same one** (`State.redeal`, from
  the bank): the lost one's Pearls have been shown. The video gives
  `AIR_GIFT` (20 s) once a board and the prompt on the card is asked again.
  A clock and not hearts or a move counter: there is one move a prompt, and
  the tank is what the game it follows already had.
- **The seal**: a dive past the middle of the water ("Deep"), and any One
  Breath that came back up. It drops on the paper's top right corner and the
  prompt re-wraps narrower to make room.
- **Where a deal's prompts come from** (`_deal`), as Golden Acorn's:
  1. A daily whose document this phone already holds
     (`Backend.cached_day`): at once. `world/main.gd` asks for today's
     behind the menu at boot.
  2. A daily with the network up and no document yet: "Fetching today's
     prompts…" on the paper while `Backend.day_content` is awaited, and
     after `FETCH_WAIT` (4 s) the bank deals instead.
  3. Everything else -- unstarted backend (every harness), no network, a
     document that does not validate, a board dealt from New, a second try
     at One Breath -- is the **bank**: `content/pearl.json`, by
     `State.bank_band(key, band)`.
  **`build()` deals nothing**, for Golden Acorn's reason: the host sets
  `daily_key` only after `start()` returns.
- **A prompt** (`tools/pearl/CONTRACT.md`): an id, a level (0 to 2), what it
  asks in en, pt and es, and its answers, each a tier (0 to 4) and its forms
  in the three languages, the first form the name that is shown. A display
  name is at most 26 characters and folds to 2 to 22 letters; no digits; at
  least 14 answers and exactly one of tier 4. `State.valid` holds a prompt to
  that on the phone and `validPrompt` on the server.
- **The bank**: `content/pearl.json`, three levels of prompts. **The source
  is `tools/pearl/level0..2.json`; `python3 tools/build_pearl.py` checks
  every one against the contract and writes the bank** (edit the levels, not
  the output). A band is the head of its level's order for the day and One
  Breath the tail of every level's (`BREATH`: 3, 3, 2), so the four bands of
  a day share no prompt. The order is by `fnv1a` of the day and the id,
  hashed twice as Golden Acorn's, and the server sorts the same way
  (`bankDay` in `pearl.ts`); `tests/_shot_pearl.gd -- bank` and
  `tools/pearl_day.sh` print the same days.
- **The language is the screen's** (`State.lang()` reads
  `TranslationServer.get_locale()`), as Golden Acorn's: the prompt, the
  names shown and which forms count first.
- **Drawn as**: `_still` (the card, the paper, the water in six bands from
  light to dark with its sand, shell and a few bubbles, the clock's track; a
  layout), `_live` (the clock's bar, the field, the mark each answer left
  down the water, the rope and the bell; rebuilt on every frame the clock
  runs and otherwise only when something moves), and a layer of words over
  both. 88-114 draw calls with the keyboard's two. **A tier is told by a
  mark as well as a colour** (`Art.pip`: a cross for dry, a dot whose light
  centre shrinks with the depth, the pearl itself), and the five tiers are
  five hues, not shades of one. No mascot: the pieces are marks, and the
  bell is a thing, not a character.
- **Motion that is this board's own**: the bell sinking to its new depth
  (`DIVE_TIME`, eased out) and the clock, counted aloud on its last five
  seconds. The rest is the flat vocabulary read as curves.
- **A completed daily is put back** on its last prompt from the cached
  document, or the bank when the cache is gone. `completion_record` keeps
  the answer given at each prompt, its tier, and `set` (a hash of the
  prompts' ids): when the prompts put back are not the ones that were
  answered, the answers are dropped and only the tiers are kept, so the pips
  and the depth stay true.
- **The win screen's Again replays the same day** (the host's, as on every
  board): a player who does knows every Pearl. Golden Acorn has the same
  hole; neither closes it.
- **Harnesses**: `tests/_shot_pearl.gd` (rest, play, deep, hint, dry, out,
  doc, restore, `fixed`; `bank` prints three days headless);
  `tests/_probe_perf.gd -- pearl`; `tests/_win.gd -- pearl`. All wait for
  the deal. `docs/agents/harnesses.md` has the commands.
- **The tutorial** (`ui/hud/pearl_tutorial_diagram.gd`, four pages on every
  band: type, rare, a miss, and then the bulb, or on Insane One Breath): the
  board itself on one hand-written prompt ("A fruit", sixteen answers),
  typing by itself a letter a beat through `type_letter` and `commit_row`.
  The screen's keyboard is not on the page, so no finger is drawn but on the
  page's own bulb.
- **Known soft spots**: an answer that is right in the world and missing
  from the list costs the player 3 s, and is the complaint to expect; the
  clock stops while the app is in the background (nothing checks the wall
  clock, so a prompt can be looked up); the one-slip rule can take a wrong
  word that sits one letter from a listed one.
- **Not seen on a phone.** Shots and probes on this Mac only. The sounds are
  one take a cue and unheard by the user; the pt and es lines of the chrome
  are unreviewed.
- **Calls made without the user** (2026-10-09): the name, the bell and the
  Pearl; metres in place of points and five tiers in place of six; four
  bands (5, 6, 7 and 8 prompts at 30, 25, 20 s and one tank) rather than
  seven prompts for everybody; the card standing ready before the clock
  runs; 3 s for a miss; the one-slip rule and a name counting in any of the
  three languages; no space key; the bulb telling the Pearl's first letter
  and length; One Breath as Insane with 45 s and 3 to 15 s back; Try again
  dealing a new dive; the Pearl and two deep answers named after every
  prompt; no score sent to the crowd; rarity authored by the model and its
  reviewer rather than counted.
