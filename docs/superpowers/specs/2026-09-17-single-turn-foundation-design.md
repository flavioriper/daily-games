# Single-turn foundation — design

Phase 0 of `docs/brainstorm/single-turn-roadmap.md`: one shared turn flow and
one shared backend, so every game after this is a screen, a grader and a
content source. Nothing in this document is a game; it is the floor the
games stand on, proved by a throwaway one.

Date: 2026-09-17. Scope: phase 0 only. Phases 1 to 6 each get their own
design and plan.

## 1. The decisions this settles

The roadmap ends on five open questions plus one the user raised while this
was being designed. Their answers shape everything below.

1. **Where the turn lives.** A card in the camp grid, like any puzzle, with
   its own live diorama. It counts the day exactly as a board does.
2. **Crowd reveal timing.** Immediate at lock, against the prior blended
   with whatever tally has been read; the number moves if the player reopens
   the card later the same day. No push, so the Android export stays on the
   non-gradle path.
3. **Content review in three languages.** Not needed by phase 0; it blocks
   phases 3, 4 and 6 and is answered there.
4. **Cloud Functions or Cloud Run.** Cloud Functions v2 for writes and jobs;
   the client reads Firestore's REST API directly under security rules, so
   the common path has no server code and no cold start. Functions v2 runs
   on Cloud Run underneath, so a later realtime service is an additive
   deploy in the same project rather than a migration.
5. **Phase 5 scoring.** Not needed by phase 0.
6. **Who a player is.** Firebase Auth *anonymous*, over the Identity Toolkit
   REST API. Not the roadmap's self-generated install ID. A leaderboard and
   multiplayer minigames are coming; an unsigned ID cannot be verified by a
   security rule, so a leaderboard built on one is trivially forged, and it
   cannot follow a player to a new phone. An anonymous Auth account upgrades
   in place to a real one later, carrying its history.

Localisation scope: wire the mechanism and translate the turn flow only. The
twelve existing boards keep their hardcoded English and are converted in a
pass of their own.

## 2. Client architecture

### 2.1 `core/stage_view.gd` — extracted

`core/puzzle_base_3d.gd` is 157 lines and about ninety of them have nothing
to do with puzzles: mounting a `Node3D` on the stage, turning the control's
own rect into a camera frame, and turning touches into board-plane hits.
Those move to a new `core/stage_view.gd`, `class_name StageView extends
Control`, which owns:

- `board: Node3D`, mounted by `stage_enter(board_name)` and released by
  `stage_exit()`, with `Stage.show_setting(false)` on the way in and
  `(true)` on the way out
- `_refit()` → `Stage.fit_camera(board_aabb(), viewport_rect(), …)`, driven
  by `resized`
- the framing hooks: `board_size`, `board_height`, `plane_height`,
  `board_pitch`, `board_projection`, `board_yaw`, `board_margin`,
  `board_depth`, `board_aabb`, `viewport_rect`
- the picking maths: `local_to_board`, `local_ray`, `board_to_local`
- `_gui_input`, dispatching touch to `on_board_press/drag/release`, guarded
  by an overridable `accepts_input()`

**The hierarchy.** GDScript is single-inheritance, and `PuzzleBase3D`
already extends `PuzzleBase extends Control`, so it cannot also extend a
`StageView extends Control`. The chain becomes:

```
Control -> StageView -> PuzzleBase -> PuzzleBase3D
Control -> StageView -> TurnBase
```

`core/puzzle_base.gd` changes by one word, to `extends StageView`.
`StageView` deliberately defines **no `_ready` and no `_exit_tree`**, so it
mounts nothing by itself; `PuzzleBase3D` and `TurnBase` each call
`stage_enter()` and `stage_exit()` from their own. A two-dimensional
`PuzzleBase` therefore inherits machinery it never invokes, which is the
price of single inheritance and costs nothing at runtime.

`core/puzzle_base_3d.gd` then keeps only `_ready`, `_exit_tree`, `is_3d()`
and `accepts_input()` returning `not is_done()`.

This is a mechanical move and the only change in phase 0 that touches code
all twelve boards inherit. The existing suite and a windowed `tests/_win.gd`
run are its gate.

### 2.2 `core/turn_base.gd`

`extends StageView`. One committed input a day, an immediate reveal, a
graded result. Never a pass or a fail.

State is one enum, `INPUT → LOCKED → REVEALED`, and it only moves forwards.
`accepts_input()` is `state == INPUT`, so the stage base already does the
freezing.

Signals: `locked`, `revealed`, `graded(score: int)`.

To override:

| Member | Meaning |
|---|---|
| `turn_id() -> String` | registry id, and the `{game}` path segment |
| `title() -> String` | the carved sign's words |
| `prompt_text() -> String` | the day's question, already localised |
| `build(content: Dictionary)` | stand the scene from the day's content |
| `guess() -> Variant` | what the player committed |
| `grade(answer) -> int` | 0 to 100 |
| `reveal()` | the camera move and the comparison |
| `share_text() -> String`, `share_glyphs() -> String` | the share card |

Given: `elapsed`, and `lock()`, which is one-way — it stamps `elapsed`,
freezes input, emits `locked`, runs `reveal()`, then `grade()` and emits
`graded`. There is no undo, no reset and no hint on a turn, ever.

Deliberately **not** a `PuzzleBase`: `moves`, `hints_used`, `checks`,
`capabilities()` and a "Solved" overlay are all the wrong vocabulary for a
graded single input, and inheriting them would hand the mismatch to every
later phase.

### 2.3 `ui/turn_host.gd`

Sibling of `ui/puzzle_host.gd`, and reuses its furniture: `TopBar` (back and
settings only), `DayCard`, `SafeArea`, `CozyTheme`, the `MARGIN`/`GAP`
rhythm and the staggered entrance.

What differs:

- the action bar is replaced by a single **Lock** button, disabled until the
  player has made an input
- the solved overlay is replaced by a reveal panel: the score drawn 0 to 100
  as a bar, "closer than N% of players", and a Share button
- once locked, the panel is what the card shows. Reopening the same day's
  card shows the stored result with a refreshed crowd number and never the
  input again; the stored result lives in `user://turns.cfg`, keyed by game
  and day key.

### 2.4 Registry and menu

`ui/registry.gd` entries gain `"kind": "puzzle" | "turn"`, and the twelve
existing entries default to `"puzzle"` so nothing about them changes.
`ui/menu.gd` routes on `kind` to `Host` or `TurnHost`. `ui/hud/puzzle_card.gd`
and `ui/hud/card_scene.gd` are untouched: a turn's card is a live diorama of
its own pieces like every other card, never a rendered image.

`Progress.touch()` is called from `TurnHost._ready()`, so a turn counts a day
exactly as a board does. One shared counter, as today.

## 3. `core/backend.gd`

### 3.1 Shape and the offline rule

A static class modelled on `core/analytics.gd`: `Backend.start(host)`,
called only by `world/main.gd`.

**Unstarted means offline.** Every call then resolves immediately from the
cache or from content bundled in `res://`. The test suite and the harnesses
build these same screens, so this gives them deterministic, silent,
network-free behaviour by construction — the same rule `CLAUDE.md` already
sets for Analytics, and the reason neither is an autoload.

### 3.2 Identity

On first launch:

```
POST https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=<WEB_API_KEY>
     {"returnSecureToken": true}
  -> {idToken, refreshToken, localId, expiresIn}
```

`localId` is the `uid`. It and the refresh token persist in
`user://player.cfg`. The ID token is held in memory only and renewed through
`https://securetoken.googleapis.com/v1/token` when under five minutes
remain.

The API key is a public client key and belongs in source beside
`Analytics.APP_ID`. The project's only app today is the Android one, whose
key may carry a package-and-certificate restriction that would require
`X-Android-Package` and `X-Android-Cert` on every REST call. A **Web app is
created in the project** so there is a clean browser key with no such
requirement.

A failed sign-up is not an error: the game runs offline and identity retries
next launch.

### 3.3 The three calls

Each is awaitable and answers `{ok: bool, data: Variant, error: String}`:

- `await Backend.day_content(game, date_key)` — Firestore REST GET
- `await Backend.tally(game, date_key)` — Firestore REST GET
- `await Backend.submit(game, date_key, payload)` — POST to `submitTurn`

Reads carry `Authorization: Bearer <idToken>`.

**Documents carry one field.** Firestore's REST API answers in typed values
(`{"fields": {"x": {"stringValue": "…"}}}`), and a general decoder for that
is a tax on every future call. Content and tally documents therefore each
hold a single field, `json`, containing a JSON string. Shard documents are
the exception and hold plain numeric fields, because `FieldValue.increment`
cannot reach inside a string; nothing but the functions ever reads them. The client does
`JSON.parse_string(doc.fields.json.stringValue)` and is finished, and the
server stays free to shape a payload however a game needs.

### 3.4 No percentile endpoint

The roadmap asks for an endpoint that takes a game, a day and a score and
answers "closer than N% of players". This design ships the **score histogram
in the tally document** instead — 101 buckets, a few hundred bytes — and the
client computes the percentile itself.

That removes a round trip from the reveal, makes the reveal instant, makes
it work offline once the day has been read once, and reduces "the number
moves if you come back" to a second read of a document we already fetch.

### 3.5 Cache and the offline queue

- `user://backend_cache/<game>-<date_key>-content.json` and `-tally.json`
  hold the last good read. A read answers from cache at once and refreshes
  behind it.
- `user://backend_queue.json` holds submits that have not landed. `submit()`
  appends and then tries; a failure leaves it queued. `Backend.start()`
  flushes the queue. A double flush is harmless because the server keys a
  submit on `uid + day + game`.
- Every request times out at five seconds and nothing blocks a frame. In
  particular **nothing blocks Lock**: locking grades against whatever is in
  hand, and the crowd number catches up on the next read.

## 4. The server

### 4.1 Layout

A `server/` directory at the repo root holding `firebase.json`,
`firestore.rules`, `firestore.indexes.json` and `functions/` (TypeScript,
Node 22, `firebase-functions` v2). `server/.gdignore` keeps Godot from
importing `node_modules`; `server/functions/node_modules` and
`server/functions/lib` are ignored in git.

### 4.2 Firestore layout

```
days/{yyyymmdd}/turns/{game}                → { json }  public content: prompt, prior,
                                                        and the answer when it is not secret
days/{yyyymmdd}/turns/{game}/secret/answer  → { json }  deny-all; for a game whose answer
                                                        must not leak (phase 6's word)
days/{yyyymmdd}/turns/{game}/submits/{uid}  → score, guess, locale, at   written once
days/{yyyymmdd}/turns/{game}/shards/{0..9}  → count, histogram{}, byLocale{}
                                                        server-only; plain numeric fields,
                                                        because they take FieldValue.increment
days/{yyyymmdd}/turns/{game}/tally/current  → { json }  count, histogram, by-locale split
players/{uid}                               → reserved for the leaderboard
```

`{yyyymmdd}` is `Daily.date_key()`, the UTC date, so a turn rolls over with
the boards.

Shards exist because a single Firestore document takes about one write a
second and a popular day would exceed that. Ten shards give ten a second,
and the rollup means a client still reads exactly one document.

### 4.3 Functions

- **`submitTurn`** — `onRequest`. Verifies the ID token with
  `getAuth().verifyIdToken()`, writes `submits/{uid}` create-only (an
  existing document is returned unchanged, which is what makes a retry and
  the offline flush safe), and `FieldValue.increment`s one bucket of a
  randomly chosen shard. It holds a per-uid rate limit.
- **`rollupTally`** — `onSchedule("every 5 minutes")`. Merges today's and
  yesterday's shards into `tally/current` for each active game.
- **`publishDay`** — `onSchedule("every day 03:00")`. Writes the next day's
  content documents. Phase 0's stub generates its content deterministically,
  which is what proves this path end to end.

### 4.4 Rules

Default deny. An authenticated player may read the day's content document
and `tally/current`, and may read their own submit and no one else's.
Nothing is client-writable: every write goes through a function on the admin
SDK, which bypasses rules. `secret/**` is unreadable by any client.

### 4.5 Scoring, cheating and what is accepted

Phase 0 lets the client compute its own score and send it. For a turn that
is fine — faking a size guess wins nothing. For the leaderboard it will not
be, so `submitTurn` is written with the server-side grading hook present
from the start; it already holds the content and can read the secret
collection, so moving a game's scoring across is a change inside one
function rather than a redesign.

Firebase App Check is not available to us: Play Integrity attestation needs
native code and the export is deliberately non-gradle. The defences are
therefore authentication, create-once submits and the per-uid rate limit.
This is accepted, and is revisited when the leaderboard is designed.

### 4.6 Deploy

`tools/deploy_functions.sh`, wrapping
`firebase deploy --only functions,firestore:rules --project peeplet-daily`,
run by hand. Wiring it into `.github/workflows/android.yml` needs a deploy
service account secret and is a follow-up, not part of phase 0.

### 4.7 Project prerequisites

Verified on 2026-09-17 with the Firebase CLI:

- **Firestore is not enabled** in `peeplet-daily`
  (`HTTP 403 … Cloud Firestore API has not been used in project
  peeplet-daily before or it is disabled`). It must be provisioned.
- The project has **one app, the Android one**
  (`1:881491152475:android:0e88e9f9a22583fdd0b97e`), key
  `AIzaSyBNOdkzD4FxethS5qbRuEeuxNfPWdMWYGc`. A Web app is added for an
  unrestricted browser key; see 3.2.
- The **Anonymous** sign-in provider must be enabled.
- Cloud Functions v2 requires the **Blaze** plan. Unverified: `gcloud` auth
  on this Mac has expired. If `peeplet-daily` is on Spark, section 4 is
  blocked until billing is attached; sections 2, 3 and 5 are not.

## 5. The stub turn

The roadmap's stub is "tap a button, get 50", which proves nothing about
content or grading. Phase 0 ships **Guess the Number** instead:
`publishDay` writes a target, the player drags a slider, locks, is graded on
distance, and the reveal shows the crowd's histogram.

Its answer is public — the game is client-graded, so the target sits in the
day's content document, and a bundled prior in `res://` lets the turn play
and grade on a phone that has never reached the network.

One throwaway screen, and it exercises the whole path: publish → read →
play → grade → submit → shard → rollup → re-read. It is deleted when How
Big? lands in phase 1.

## 6. Localisation

`locale/turn.csv`, keyed for the turn flow only, imported by Godot as
translations and registered in `project.godot`.

`core/locale.gd` holds:

- detection: `OS.get_locale_language()` → `en` / `pt` / `es`, falling back
  to `en`
- an override persisted in `user://player.cfg` beside the uid, exposed as a
  language row on `ui/hud/settings_sheet.gd` — mostly so all three can be
  seen without changing the phone
- `number()` and `parse_number()`. Portuguese and Spanish write a thousands
  separator as `.` and a decimal comma as `,`; phase 4 depends on parsing
  this and the stub's percentage exercises formatting it.

**One real unknown.** A turn's title goes on a carved sign through
`ui/hud/sign_view.gd` and `core/lettering.gd`, and `TextMesh` already fails
to extrude this display face's digits 8 and 9 at weight 700. É, Ã, Ç and Ñ
must be checked the same way before a Portuguese or Spanish title goes on a
board. If they fail, the fix is the one already in `core/lettering.gd`:
drop that line's weight.

## 7. Analytics

New events: `turn_lock`, `turn_reveal`, `turn_share`,
`crowd_reveal_opened`, carrying `turn_id`, `day`, `score` and `seconds`.

`locale` is added centrally inside `Analytics.track()` rather than at every
call site, which means raising the reserved-parameter count in
`Analytics._clean` from three to four. The existing rule holds: nothing
sends unless `Analytics.start()` ran, and only `world/main.gd` calls it.

## 8. Verification

No new test files: the project is in MVP mode and spends its time on the
feature, not the suite. Throwaway self-driven checks only. The gates are:

1. **The existing suite passes unchanged** after the `stage_view`
   extraction, plus a windowed `tests/_win.gd` run. This is the hard gate;
   the extraction sits under all twelve boards.
2. **Firebase emulators**, locally: publish → read → submit → rollup →
   re-read.
3. **On the phone**, through `tools/deploy_android.sh`: the stub card is on
   the menu, plays, locks, grades and shows a crowd number; the submit
   document is readable in Firestore and the tally moves after a rollup.
4. **Airplane mode**: the turn still plays and grades against the bundled
   prior, and the queued submit reaches Firestore after reconnecting.
5. **Three locales** render, and the accented capitals extrude on the sign.

## 9. Risks

- **The extraction.** Mechanical, but it is under everything. Mitigated by
  the suite and the win harness, and by making it its own commit so it can
  be reverted alone.
- **Blaze billing** on `peeplet-daily`, unverified. Blocks section 4 only.
- **`submitTurn` cold start**, one to three seconds. This is precisely why
  nothing waits on it and Lock grades locally.
- **Draw calls.** A thirteenth menu card adds a diorama to the screen whose
  855-call budget is the binding constraint. Measured, not assumed.
- **An Android-restricted API key** breaking REST auth. Pre-empted by
  creating a Web app for a browser key.

## 10. Out of scope

The leaderboard. Any multiplayer transport. Server-side scoring. CI deploy
of the functions. App Check. Converting the twelve boards' strings to keys.
Phases 1 to 6, each of which gets its own design.
