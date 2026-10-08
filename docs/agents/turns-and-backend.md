<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Turns and the backend

A **turn** is one committed input a day, an immediate reveal and a graded
result -- never a pass or a fail. The only one, How Big?, was 3D and was
removed on 2026-09-24 with the rest of the 3D game. **It came back on
2026-10-08 as a board, not a turn** (`docs/agents/boards/how-big.md`): a
Puzzles-grid card with four bands, graded on the phone, with no publish, no
submit and no crowd. Nothing in the game is a turn today; one would need its
own host again (`legacy/ui/turn_host.gd` and `legacy/core/turn_base.gd` are
in git history).

**One board reads its day from the backend: Golden Acorn** (2026-10-08,
`docs/agents/boards/golden-acorn.md`). Its questions are written by a model
at night and published as that day's document; see "A day written by a
model" below. It sends nothing back.

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

**How Big?**, the only turn, was removed with the 3D game on 2026-09-24 and
came back flat on 2026-10-08 as a board that never talks to the backend.
`content/how_big.json` is the board's table (things, sizes, sources). **Its
`GAMES` entry is gone from `server/functions/src/index.ts` since 2026-10-08**
(with the functions' own stale copy of the table), but **the deployed
functions still publish it** until `tools/deploy_functions.sh` is next run.
`tools/_backend_probe.gd` and `tools/seed_turn_day.sh` name `how_big` only as
an example game id. `locale/turn.csv` lost its `HOWBIG_*` rows the same day
and keeps the `TURN_*` ones (`TURN_LANGUAGE` is the settings sheet's).

## A day written by a model

2026-10-08, for Golden Acorn, and written to be followed: the next game
whose day is generated (the user named one, "krill") adds a file beside
`acorn.ts` and one line to `GAMES`.

**The shape.** Generation runs on the server at night, never on a phone:
the key stays in one place, every player gets the same day, and a phone
costs nothing. `publishDay` (03:00 UTC, today and tomorrow) calls each
game's `make(day, recent)` and `create()`s `days/<day>/turns/<game>` with
the result as its one `json` field -- the document, the rule that lets any
signed-in player read it, `Backend.day_content` and its cache are the turn
foundation's, unchanged. Three things changed in `index.ts`:

- `GAMES` is `Record<string, (day, recent) => Promise<unknown>>`. `recent`
  is what the game published on the last `RECENT_DAYS` (10) days, newest
  first, parsed; a game turns it into "do not repeat these".
- **A day already published is never made again**: `publishDays` reads the
  document first and skips. `create()` is still what writes, so two runs
  racing cannot overwrite either.
- The schedule has `timeoutSeconds: 1500`, `memory: "512MiB"` and
  `secrets: ["OPENROUTER_API_KEY"]`.

**`server/functions/src/generate.ts` is the only place a model is called.**
It asks through **OpenRouter** (`https://openrouter.ai/api/v1/chat/completions`,
a plain `fetch`, no SDK), which speaks one dialect for every maker's models,
with the key in `OPENROUTER_API_KEY`: a secret on the deployed function, an
environment variable anywhere else (this Mac's `~/.zshrc` has one). That is
the third provider in one evening, each the user's call (2026-10-08): Claude
Opus 5.5 through Anthropic's SDK first (`f7ea2a3c`), then a model on Vertex
AI for the Google Cloud credits (`1485033f`, never run: the owner's gcloud
login had expired), then "let's use my openrouter key so we can use a cheap
model able to do it".

- **Which model is a name**, read from the environment: `DAILY_MODEL` (the
  writer, default `anthropic/claude-haiku-5.5`) and `DAILY_REVIEW_MODEL`
  (the reviewer, default `openai/gpt-6-luna`). Both were $0.10 a million
  tokens in and $0.50 out on OpenRouter's own list on 2026-10-08, and both
  take structured outputs. **They are of different makers on purpose**: a
  reviewer from the writer's family shares its mistakes. `DAILY_MODEL=off`,
  no key, or the emulator's host in the environment mean no model
  (`available()`).
- `ask<T>({system, prompt, schema, role?})` sends one request (16,000
  tokens at most, 240 s) and returns the parsed JSON or throws. It asks the
  endpoint to hold the model to the schema (`response_format: json_schema`);
  on a 400 it asks again for plain JSON (`json_object`), the schema being
  spelled out in the system text either way, and `jsonIn` reads the object
  out of a fenced answer. **So the schema is a request, not a guarantee**,
  and the game's validator is what is trusted.
- **A day is asked for in pieces**: a cheap model's answer has a low
  ceiling, and a piece that fails costs the day that piece.

**What a game's file owes** (`acorn.ts` is the model to copy):

1. **A prompt and a schema.** The standing rules in `system`, today's
   request in `prompt`, the answer's JSON schema. Schemas are plain: no
   length or count limits in them (not relied on; whether the API would
   hold the model to them was not looked up), those are checked in code.
2. **A validator** (`validQuestion`): the shape and the limits the screen
   can hold. Everything the model returns goes through it before it is
   believed, and the phone runs the same checks on what it reads
   (`State.valid`).
3. **A review.** A second `ask`, in another role, that does not see the
   first one's answer key. Golden Acorn's reviewer is shown each question
   with its four answers shuffled (`shownOrder`) and unmarked, answers it
   itself, and names what is wrong with it (arguable, dated, lost in
   translation, unsuitable, a giveaway). A question is kept only when the
   reviewer picked the answer the writer meant, said it was sure, and found
   nothing (`passing`). Ask the writer for more than the day needs
   (`DRAFTS` 9/9/9/13 for 7/7/7/10) so the review has some to turn down.
4. **A reserve the game ships**, and a rule for the gap: `makeDay` **never
   throws**. It writes and reviews **a band a request** (eight requests a
   day), each band told what the last days and today's earlier bands asked;
   a band whose request fails is the bank's and the others stand. No model
   at all: the day is the bank's
   (`content/acorn.json`, copied beside the source by `npm run build` as the
   ignored `src/acorn_bank.json`). A band left short by the review is
   filled from the bank; a short Climb is the bank's whole, because two
   hands' questions spliced together would not rise. The document says
   which it was (`source`: `model`, `mixed`, `bank`).
5. **The phone derives the reserve's day the same way** (`bankDay` there,
   `State.bank_band` here), so a night the model failed and a phone that
   never reached the network deal the same day.

**The client's half** is `puzzles/acorn2d.gd`'s `_deal`: cache first, one
short wait on the network, then the reserve; and `world/main.gd` fetching
the day behind the menu at boot. A board cannot ask in `build()`: the host
sets `daily_key` after `start()` returns.

**Cost and time, measured.** Two whole days were written from this Mac on
2026-10-08 with the default pair: **about three and a half minutes each**
(3:28 and 3:35 for the eight requests, one after another). The cost was not
read off OpenRouter's dashboard; by the tokens (some 15,000 written and as
many read again) it is **a few cents a day** at the list prices above.

**What the model's days were like** (two days read): the review kept
8/6/9/11 and 8/8/7/10 of the 9/9/9/13 drafted, so one day needed one bank
question and the other none. The facts read true, the Portuguese and
Spanish natural, the subjects spread, with Brazilian questions among them
(the 1889 republic, Carlos Gomes, Dom Casmurro). Two things to know:
**the Climb's top is softer than "one adult in ten"** -- the reviewer turns
down most of what is really hard, as not sure enough, so one Climb ended on
Vasco da Gama and the other on carpe diem -- and **a bank question can
repeat a fact the model just asked** (both had the adult body's 206 bones
in one band), which the fill now passes over by its answer. Nobody but me
has read them; `tools/acorn_day.sh` prints one.

**By hand** (run by a person; the last two change production):

- `tools/acorn_day.sh [yyyymmdd]` prints the day `makeDay` would publish and
  writes nothing (`DAILY_MODEL=...` in front to try another writer,
  `DAILY_MODEL=off` for the bank's day).
- `cd server && firebase functions:secrets:set OPENROUTER_API_KEY --project
  daily-games-420bf`, once, **before** `tools/deploy_functions.sh`: a deploy
  that names a secret that does not exist fails.
- `tools/deploy_functions.sh`. The 03:00 UTC run publishes today and
  tomorrow; `tools/publish_day.sh` (application default credentials and the
  key in the environment) does the same from this Mac for a day the
  scheduler will not reach. To pin other models on the deployed function,
  put `DAILY_MODEL=...` in `server/functions/.env`.

**Verified, and not** (2026-10-08). `npm run build` is clean. `publishDays`
ran against the Firestore emulator (`firebase emulators:exec --only
firestore --project demo-peeplet`, `FIRESTORE_EMULATOR_HOST` set,
`node lib/cli.js publish`): it wrote `days/<today>/turns/acorn` once with
the bank's day and left it untouched on a second run. `makeDay` ran against
a stand-in for the model (a throwaway script that replaced `ask`): a clean
day, a question over the limits dropped, a strict reviewer and a reviewer
that disagreed both filled from the bank, a throwing writer gave the bank's
day. **The model's own half is proven from this Mac and no further**: the
requests, the schema as OpenRouter takes it, the review and the fill ran for
real, twice. What is not proven is the function doing it: the secret
reaching it, and three and a half minutes inside a scheduled run.

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

## The Realtime Database (Versus online)

2026-10-04, spec `2026-10-04-versus-online-design.md`. The one live thing in
the game is a Versus game against a stranger (`docs/agents/versus.md`,
"Online"), and it runs on the **Realtime Database, not Firestore**. The game
has no Firebase SDK, only REST, and Firestore's REST API cannot listen: a
live game on it would be polling. The Realtime Database's REST API streams
(`Accept: text/event-stream`: `put`, `patch`, `keep-alive`, `cancel`,
`auth_revoked`), takes the same anonymous id token (`?auth=`), has an atomic
multi-path `PATCH`, and its rules can read the server's clock (`now`) and
stamp it (`{".sv": "timestamp"}`).

**Rules only, no function.** `server/database.rules.json` is the whole
server: matchmaking, moves in turn, the clocks and the results. That keeps
clear of the organisation's `allUsers` policy (`tools/public_invoker.sh`)
and of cold starts. Nothing on the server knows a game's rules; each end
checks the other's move, and records live on the device, so a lie about a
result fools only the liar.

```
/queue/{game}/{uid}      { since, at, match? }
/matches/{id}            { game, p0, p1, first, seed, at,
                           n, turn, turnAt,
                           moves: { "0": {s, d}, "1": ... },
                           seen:  { "0": ms, "1": ms },
                           result: { winner, why } }
```

`game` is `snooker`, `chess` or `checkers`. `p0`/`p1` are uids and a seat is
0 or 1; the claimed ticket's owner is `p0`. `first` is the seat that opens,
`seed` one int both ends share, `d` a JSON string the game owns (20,000
characters at most), `s` the seat that sent it, `n` the count of moves,
`turn` the seat to act and `turnAt` when its clock started. `winner` is a
seat or -1. What the rules hold, in the order a game meets them:

- **A ticket** is written by its owner with `since` and `at` equal to `now`
  (or unchanged); `/queue/{game}` is readable by anyone signed in and
  indexed on `since`. Anyone may delete a ticket whose `at` is over 60 s
  old.
- **A claim is one `PATCH` at the root**: the match document and `match:
  id` on both tickets, each rule checking the other through `newData`, so
  they land together or not at all. `match` is set once, only while the
  ticket's `at` is under 10 s old, only to a match that does not exist yet
  and names exactly that ticket's owner and the writer. A match is created
  only with both tickets pointing at it, `n` 0, `turn == first`, `at` and
  `turnAt` now, and no moves, seen or result. A second claimer gets a 401.
- **A match is read by its two players** and nobody else.
- **A move** is one `PATCH` on the match: `moves/{n}` (new, `s` the seat to
  act), `n` up by exactly one, `turn` (the same seat again is allowed:
  snooker's shot before its table), `turnAt: now`. Each of the four is
  refused without the others.
- **`seen/{seat}`** is written by its own seat, as `now`.
- **A result is written once**, by a player: `resign` (the winner is the
  other seat), `timeout` (the winner is the writer, the turn is the other's
  and `turnAt + 60000 < now`), `left` (the winner is the writer and the
  other's `seen` is over 20 s old), `end` (winner -1, 0 or 1; after at least
  one move, by the seat that made the last one), `void` (winner -1; 10 s
  after `at`, by a player whose opponent has no `seen`). No move after it.
- The clocks are numbers in the rules and again in
  `versus/online/match.gd` (`VOID_MS`, `LEFT_MS`, `LIMIT_MS`, `FRESH_MS`,
  `STALE_MS`) and `versus/online/online.gd` (`LIMIT`): change them together.
- There is no sweep. Finished matches stay.

**Friends on the Realtime Database** (2026-10-04, spec
`2026-10-04-friends-design.md`; the client is in `docs/agents/friends.md`).
Four more paths, rules alone again:

```
/codes/{code}                     uid
/social/{uid}/friends/{other}     { at, via? }
/social/{uid}/invites/{from}      { game, at, match? }
/presence/{uid}                   { at }
```

- **A code** is eight of `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (the rule's
  regex). Written only where there is none, with the writer's uid; deleted
  only by its owner; read one at a time by anyone signed in; `/codes` is
  not readable, so they cannot be listed.
- **A friendship is two entries made in one root PATCH** by the one who
  opened the link. `social/$uid/friends/$other` is created only with the
  other half in the same write, by `$uid`, or by `$other` with `via` a code
  whose value is `$uid` -- so knowing the code is the whole permission and
  one half never stands alone. `at` is `now`. Never `$uid === $other`, no
  update, and **deleted only with the other half gone in the same write**,
  by either of the two.
- **`/social/{uid}` is read by `uid` alone**: one stream carries friends
  and invites.
- **An invite** `social/{to}/invites/{from}` is written by `from` while
  `social/{to}/friends/{from}` exists (`game` one of the three, `at` `now`
  or unchanged), read by `from` too, deleted by either. **`match` is set
  once, by `to` only**, while `at` is under 10 s old, to a match that does
  not exist and that the same write makes with `p0 === from`, `p1 === to`
  and the invite's `game`.
- **A match is created one of two ways**: both queue tickets pointing at
  it, or `social/{p1}/invites/{p0}/match === $id` with the same `game`.
  Everything after creation is the same rule as before.
- **Presence** `presence/{uid}` is `{at: now}`, written by `uid`, read by
  `uid` and by anyone in `social/{uid}/friends`.
- The 10 s here is `Social.FRESH_MS` and the rules'; the invite's
  heartbeat is `Match.TICKET_BEAT`. Change them together.
- No sweep: codes, friendships and presence stay.

**`core/live.gd`** (`Live`) is static like `Backend` and rides on its
identity. `Live.read(path, query)`, `write(path, value)` (PUT),
`patch(path, changes)` (a key may be a path, "moves/3"), `remove(path)`,
each answering `{ok, code, data}`; `Live.STAMP`; `Live.server_now()` (ms;
this device's clock plus an offset taken from the first stamp found in the
last stamped write's answer, at the middle of the round trip) and
`Live.clocked()`. **Unstarted `Backend` means offline here too**: every verb
answers `{ok = false, code = 0}` and a stream stays shut, without touching
the network. A 401 is retried once with a fresh token unless the body says
"Permission denied": a rule's refusal is an answer. `Live.lose` (an int, for
a probe, as `Stream.drop()` is): the next that many requests are made and
land, and answer `{ok = false, code = 0}` -- a network that went quiet
mid-request.

`Live.Stream` is a `Node` holding one `HTTPClient`: `open(path)`, `close()`,
`is_open()`, `drop()` (cuts it as a bad network would, for a probe),
`opens`; signals `event(kind, path, data)` (`put`, `patch`, `cancel`; the
path is relative to the one opened) and `dropped` (once an outage). It
follows the 307 the live database answers with when the data lives on
another host (up to four, and goes back to the first host after a drop),
reads the body in `_process` a whole line at a time (a chunk ends anywhere,
mid-character too), renews the token on `auth_revoked`, and after a drop or
40 s of quiet (the server's `keep-alive` is every 30 s) opens again with a
wait that grows from 0.5 s to 8 s. The first event after a reopen is the
whole of the data again, which is why `Match` follows state and has no
reconnect code. `cancel`, or a refusal that says "Permission denied", ends
the stream for good.

**`Backend` changed for this**:

- `Backend.token(fresh := false)` hands out the id token (awaits
  `_ensure_token`; "" when unstarted or when none can be had); `fresh`
  renews it even if it looks good.
- `BACKEND_PLAYER` (environment) names another file for the identity in
  place of `PLAYER_PATH`, so two processes on one Mac are two players. The
  online probes set it per child.
- **A refresh that got no answer keeps its refresh token.** `_refresh` used
  to drop the token on any failure and `_ensure_token` then signed up, which
  handed a player a new uid whenever the network blinked -- in the middle of
  a game online, a new uid is a stranger to its own match. Now only a 4xx
  (the token is dead) drops it, and `_ensure_token` signs up only when there
  is no refresh token at all.

**Emulator specifics.** `server/firebase.json` has `database` (the rules
file) and the emulator on port **9000**; start it with
`cd server && PATH="/opt/homebrew/opt/openjdk/bin:$PATH" firebase
emulators:start --only auth,database --project demo-peeplet`. The emulator's
host names nothing, so the database is picked by `ns`:
**`ns=demo-peeplet-default-rtdb`** (`Live.url` adds it under
`FIREBASE_EMULATOR`, from `FIREBASE_PROJECT`). Two ways it is not the live
database, both handled in `Live.Stream` and both worth knowing before
"fixing" it: its event stream answers **`Connection: close`**, and a read
the rules deny is a **plain 401 with "Permission denied" in the body, not a
`cancel` event** (`_refused` turns it into one). It does send `keep-alive`
every 30 s. `tests/_probe_live_rules.sh` reads `FIREBASE_EMULATOR` and
`FIREBASE_PROJECT` the same way.

**Not yet done on the live project** (2026-10-04) -- online play works
against the emulator and nowhere else:

- **The Realtime Database instance exists since 2026-10-04** (created in
  the Firebase console, us-central1, locked mode: every read and write is
  refused until the rules are deployed). Its host is the one `Live.HOST`
  spells out, `https://daily-games-420bf-default-rtdb.firebaseio.com`
  (seen: `/.json` answers 401 "Permission denied", where it answered 404
  before).
- **`tools/deploy_live.sh` is run by a person** (`firebase deploy --only
  database --project daily-games-420bf`), like `tools/deploy_functions.sh`.
  It has not been run.
- **Nothing has been verified against production**: not the 307, not
  `auth_revoked`, not the rules as deployed, not two real devices. Until
  the rules are deployed a player who picks Online with the network up will
  fail to write a ticket and see the No connection card, and Friends says
  it is offline.
