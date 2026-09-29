<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Turns and the backend

A **turn** is one committed input a day, an immediate reveal and a graded
result -- never a pass or a fail. The only one, How Big?, was 3D and was
removed on 2026-09-24 with the rest of the 3D game; a future turn would be
drawn flat and would need its own host again (`legacy/ui/turn_host.gd` and
`legacy/core/turn_base.gd` are in git history).

**The live project is `daily-games-420bf`** (provisioned 2026-09-17; it
replaced `peeplet-daily`, which now holds nothing this game uses). Firestore
is a `nam5` multi-region database with the rules from `server/` released,
anonymous sign-in is on, and `core/backend.gd`'s `API_KEY` is the project's
Web app key. The project is on Blaze and the three functions are deployed in
`us-central1` (`tools/deploy_functions.sh`), with their schedules enabled and
a one-day cleanup policy on their container images. Everything below was
verified against the local emulator suite first, then against the live
project.

**The project lives in a Google Cloud organisation with the "secure by
default" policies on**, and three of them bite anything that provisions it:
no service-account keys (`iam.disableServiceAccountKeyCreation`), no members
from other domains (`iam.allowedPolicyMemberDomains`, so a navlio account
cannot own the project and billing is attached from the hypertradeworx side),
and no automatic roles for default service accounts
(`iam.automaticIamGrantsForDefaultServiceAccounts`, so a fresh project's
functions cannot even build). Two one-time scripts hold the answers and are
safe to re-run: `tools/ci_identity.sh` (keyless CI sign-in for App
Distribution) and `tools/functions_identity.sh` (build and Firestore roles
for the functions' identity) and `tools/public_invoker.sh` (the domain
restriction also rejects `allUsers`, so `firebase deploy` leaves `submitTurn`
with no invoker and every call answers 403 from Cloud Run; this overrides the
constraint on this project alone and grants the invoker). All three grant
roles or change policy, so a person runs them, not an agent session. Billing
is the navlio account `013342-E2B1D4-0E3351`.

`core/backend.gd` is the only way out of the game. It is static and woken by
`world/main.gd` alone, exactly like `Analytics` -- **unstarted means offline**,
which is how the suite and the harnesses build these screens without touching
the network, and why neither is an autoload.

- Identity is **Firebase Auth anonymous** over the Identity Toolkit REST API,
  not an install id: a security rule cannot verify an unsigned id, and the
  leaderboard is coming. It upgrades in place to a real account later.
- Reads go straight to **Firestore's REST API**; writes go to one Cloud
  Function. Every document a client reads carries a **single `json` field**,
  which is what keeps Firestore's typed values from becoming a decoder.
- There is **no percentile endpoint**: the tally ships the 101-bucket
  histogram and `Backend.percentile()` does the arithmetic on the device.
  Instant reveal, works offline, and "the number moves if you come back" is
  just a second read.
- A submit is queued to disk before it is sent and flushed on the next
  launch. The server keys on uid, day and game, so a double flush is
  harmless. Nothing waits on the network, and in particular **nothing blocks
  Lock**. `submitTurn` itself only accepts a submit dated today or yesterday
  in UTC -- yesterday stays open so the offline queue can still flush after
  the day rolls over mid-queue.
- Server lives in `server/` (Cloud Functions v2, TypeScript, Node 22).
  `tools/deploy_functions.sh` deploys the functions and the rules; it is not
  in CI yet, and it has not been run against `peeplet-daily` for the reason
  above. `server/.gdignore` keeps Godot out of `node_modules`.
- `tools/_backend_probe.gd` drives the whole path against the emulator suite
  and prints what came back. It is a harness, not a suite entry.

Running the emulator suite locally has three traps worth knowing before you
lose an hour to them. The Firestore emulator needs **JDK 21+**; the `java` on
this Mac's `PATH` is Homebrew's 17, and firebase-tools refuses to start
against it, so every emulator command runs prefixed with
`PATH="/opt/homebrew/opt/openjdk/bin:$PATH"`. The suite itself is started
`--project demo-peeplet` -- the `demo-` prefix is what forces the emulator
into fully offline mode with no real credentials touched -- which is why
`core/backend.gd` reads a `FIREBASE_PROJECT` environment override alongside
`FIREBASE_EMULATOR`, rather than hardcoding the project id it addresses.
And **`firebase functions:shell` cannot invoke a v2 `onSchedule` function** in
CLI 15.14.0: it prints "Successfully invoked function" and does nothing. To
trigger `publishDay` or `rollupTally` by hand, wrap the body in a temporary
`onRequest` function and curl it, or write to Firestore directly over the
emulator's REST API; this has already cost two implementers an afternoon
each. Against the live project, `tools/seed_turn_day.sh <game> <day> <json>`
writes one day's document the way `publishDay` would (create-only), for the
day a game ships on, which the 03:00 scheduler never reaches. How Big?'s
first two days (2026-09-17 and -18) were seeded this way.

**How Big?**, the only turn, was removed with the 3D game on 2026-09-24.
The backend, the functions and `content/how_big.json` are still in place;
whether they stay for a future flat turn is open in
`docs/roadmap-to-release.md`.

`core/locale.gd` picks between `en`, `pt` and `es` and does the number
formatting `TranslationServer` does not. The turn flow's strings are keyed
in `locale/turn.csv` (European Portuguese, unlike everything since), and
since 2026-09-23 `locale/ui.csv` (pt-BR) keys the chrome every flat board
shares -- menu, bottom bar, sheets, actions row, win screen, keyboard -- and
all of Hidden Word's and Word Trail's own text. A static Label or IconButton
holds the key itself, so Godot's auto-translate re-reads it live when the
language changes; anything formatted, drawn or measured goes through `tr()`
(`day_row.gd` re-formats on `NOTIFICATION_TRANSLATION_CHANGED`). Board
titles stay English in every language, by the user's decision. **Every
board is keyed since 2026-09-24**: the other eighteen boards' rules, tips,
refusals, win lines, share lines, the registry's `short`, `motto`, `blurb`
and worded level lines, the trays, the first-play card and the island names
under Day N live in `locale/boards.csv` (500 rows, en/pt-BR/es), beside
`ui.csv` in `project.godot`'s translation list. A board keeps its tip lines
as keys in its constants and `tr()`s them when it speaks. A count in a
sentence is a `_ONE`/`_N` pair of keys, never an English plural built in
code, because pt and es agree the verb and the gender (Mushroom Patch's
number words and Balance's fruit have per-gender keys). Registry `footer`s
stay English because nothing shows them. The pt/es rows are machine-fluent
and still want a native speaker's pass. Upper-case accented capitals turned out to be fine:
`ÁÉÍÓÚ` and `ÃÕÇÑ` both extrude cleanly at weight 700 (18,024 and 21,228
faces, in the same 3,600-5,600-faces-per-glyph range as `GUESS` at 22,356) --
the only glyphs that need the weight dropped to 550 are digits 8 and 9. That
was measured once with a throwaway probe; there is no need to re-run it for
a new accented title.

**The two word boards deal words in the player's language** (2026-09-23).
`Locale.content(path)` turns `content/hidden_word.json` into
`content/hidden_word.pt.json` when that file exists and falls back to the
English one otherwise, and both states cache per language, so a change in the
settings sheet reaches the next board dealt and never an open one. Hidden
Word plays on `Locale.fold()`ed words -- accents off, so CORAÇÃO is typed
CORACAO, the way Portuguese players already know the game -- but **Ñ is a
letter in Spanish** and gets its own key at the end of the middle row
(`KeyBoard.ROWS_ES`, ten keys, the top row's width exactly). `state.written`
keeps the accents for the reveal. The keyboard outlives the board, so
`match_locale()` re-lays it when the language changed under it. Word Trail
types nothing, so its tiles wear the accents. The pt and es lists come from
`wordfreq` (CC-BY-SA 4.0, attributed in each file's `note`), with the answers
curated by hand to the English rules; the accept lists are every five-letter
word `wordfreq` knows, folded, because being told a real word is not a word
is still the worst thing that board can do.

Roadmap: `docs/brainstorm/single-turn-roadmap.md`. Phase 0's design:
`docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md`.
