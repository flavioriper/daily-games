# Versus online: a live game against a stranger

2026-10-04. Snooker, chess and checkers gain a fourth choice beside Easy,
Medium and Hard: **Online**. Play then looks for another player who is
looking at the same moment, and the two play one live game.

Decided with the user: strangers through a queue (no friend codes); live,
both present, a clock on every move; when nobody is around the game says so
and offers the computer openly (never a bot dressed as a person); all three
games in this version; each player has an assigned name and face, no typed
text and no chat (the app has an age gate); wins and losses online are kept
on the device beside the computer's record; no rating.

## 1. Transport: the Realtime Database over REST

The game has no Firebase SDK, only REST (`core/backend.gd`). Firestore's REST
API cannot listen, so a live game on it would be polling. The **Realtime
Database's REST API streams** (`Accept: text/event-stream`: `put`, `patch`,
`keep-alive`, `cancel`, `auth_revoked`), takes the same anonymous id token
(`?auth=<idToken>`), has atomic multi-path `PATCH`, and its rules can read the
server's clock (`now`) and stamp it (`{".sv": "timestamp"}`). That is enough
to do matchmaking, moves, clocks and forfeits **with rules alone and no Cloud
Function**, which also keeps clear of the organisation's `allUsers` policy
(`tools/public_invoker.sh`) and of cold starts.

- `core/live.gd`, static like `Backend` and answering only when `Backend` is
  started: `Live.read(path, query)`, `Live.write(path, value)` (PUT),
  `Live.patch(path, dict)`, `Live.remove(path)`, each returning
  `{ok, code, data}`; and `Live.Stream`, a `Node` holding one `HTTPClient`
  that follows the 307, parses the event stream in `_process`, reconnects with
  a fresh token on `auth_revoked` or a drop, and emits `event(kind, path,
  data)` and `dropped`.
- Host: `https://<project>-default-rtdb.firebaseio.com`; under
  `FIREBASE_EMULATOR`, `http://<emu>:9000` with `ns=<project>-default-rtdb`.
  One const (`Live.HOST`) holds the live URL, because an instance outside
  us-central1 has a different one.
- `Backend.token()` hands out the id token (awaits `_ensure_token`).
  `BACKEND_PLAYER` (environment) overrides `PLAYER_PATH`, so two processes on
  one Mac are two players.
- Server time: every write that stamps `{".sv":"timestamp"}` answers with the
  resolved value; `Live` keeps `server_now()` from the last one seen.

## 2. Data

```
/queue/{game}/{uid}      { since, at, match? }
/matches/{id}            { game, p0, p1, first, seed, at,
                           n, turn, turnAt,
                           moves: { "0": {s, d}, "1": ... },
                           seen:  { "0": ms, "1": ms },
                           result: { winner, why } }
```

`p0`/`p1` are uids; a **seat** is 0 or 1. `first` is the seat that opens
(white in chess, the break in snooker). `seed` is one random int both ends
share. `moves/{i}.d` is a JSON string the game owns; `s` is the seat that
sent it. `n` is the number of moves; `turn` is the seat to act and `turnAt`
when its clock started. `result.winner` is a seat or -1 (draw, void).

### Matchmaking (rules only)

1. The seeker writes its ticket (`since` and `at` stamped by the server) and
   opens a stream on it. It refreshes `at` every 4 s.
2. It reads the queue (`orderBy="since"`, `.indexOn`), and takes the oldest
   other ticket that has no `match`, whose `at` is under 10 s old and whose
   `since` is older than its own (uid breaks a tie). Older tickets are
   claimed, newer ones claim: two seekers never claim each other at once.
3. Claim = one multi-path `PATCH` at the root: the match document, and
   `match: id` on both tickets. The rules let anyone signed in set `match` on
   a ticket only if it has none, is fresh, and the new match names exactly
   that ticket's owner and the writer. A second claimer is refused and reads
   the queue again.
4. The claimed player sees `match` arrive on its stream. Both delete their
   tickets and open a stream on the match.
5. With no one to claim, the seeker re-reads the queue every 3 s. After
   **25 s** the lobby says nobody is around: **Keep looking** or **Play the
   computer**.
6. A match whose other player never writes `seen` within 10 s is void
   (`result {winner: -1, why: "void"}`); the seeker goes back to looking
   without a word.

### The match

- Both write `seen/{seat}` (server stamp) every 5 s.
- A move is one `PATCH` on the match: `moves/{n}`, `n: n+1`, `turn`,
  `turnAt: now`. Rules: the writer holds the seat `turn`, `moves/{n}` did not
  exist, `n` goes up by exactly one, there is no result.
- A result is written once. Rules allow: `resign` (winner is the other
  seat); `timeout` (winner is the writer, `turn` is the other seat and
  `turnAt + LIMIT < now`); `left` (winner is the writer and the other's `seen`
  is over 20 s old); `end` (the game's own ending: written by the seat that
  made the last move); `void` as above.
- `LIMIT` is 60 s for every game: one number in the rules.
- Nothing on the server knows the games' rules. Each end checks the other's
  move against its own rules; a move that is not legal is treated as the
  other player having left. Records live on the device, so a lie about a
  result fools only the liar.
- A dropped stream reconnects and receives the whole match again; the client
  is a **follower of state**: it keeps the match dictionary, applies `put`
  and `patch` by path, and hands the game every move from the count it has
  already played up to `n`. Reconnecting therefore needs no special case.
- Finished matches and stale tickets are left in place in this version
  (a match is a few KB). A ticket older than 60 s may be removed by anyone.
  A sweep is a later job.

## 3. The client

- `versus/online/match.gd` (`Node`): `seek(game)`, `cancel()`,
  `send(d: Dictionary, next_turn: int)`, `end(winner, why)`, `resign()`,
  `leave()`; signals `found(seat, first, seed, opponent_uid)`, `nobody`,
  `move(d: Dictionary)`, `ended(winner, why)`, `clock(seat, seconds_left)`,
  `offline`. It owns the ticket, both streams, the heartbeats, the clock and
  the timeout/left claims. Offline (`Backend` not started, or the first
  write fails) it emits `offline`.
- `versus/online/names.gd`: `face_of(uid)` and `name_of(uid)` from a hash of
  the uid: one of the drawn faces in `ui/faces/` and its translated name
  with a three-digit number ("Hedgehog 482"). No adjective, so pt and es
  need no agreement. Characters are code: no image.
- `versus/online/lobby.gd`: the card over the board while looking
  (`VS_LOOKING`, a Cancel), when nobody is around (Keep looking / Play the
  computer), when offline (Play the computer), and "found" (the opponent's
  face and name for a beat). Built from `ui/hud/dialog.gd`'s look.
- **Level 3 is Online.** `versus_tab.gd` gets a fourth chip; `Record`
  already keys by level, so `chess_3` is the online record. `VS_SOON_LINE`
  goes. The chips must still fit at 810 wide; if four do not, Online is an
  icon chip.
- Each screen, when `level == 3`:
  - opens with the lobby up and the board idle behind it;
  - on `found`: the opponent's name and face replace the moon; `first`
    decides who opens; the game starts;
  - the computer's seat is the match: where the screen calls `_think("ai")`
    it waits for `move`; the player's own move is `send` as it is played;
  - undo, reset and hint are off (greyed as Reset already is mid-move);
  - the side to move shows its seconds left on the scoreboard, quiet above
    15 and warning under;
  - Back asks (the house dialog) and resigns;
  - the end card says why (`VS_END_RESIGN`, `_TIMEOUT`, `_LEFT`) when the
    game did not end on the board, and its button is **Find another**;
  - "Play the computer" from the lobby sets the level to the last one played
    against the computer and starts a normal game.
  - The tutorial's first-play card does not open over an online game.
- Chess sends `{m: int}`, checkers `{m: [int...]}`.
- **Snooker** cannot trust two phones to roll a shot alike, so the shooter
  is the authority. At release it sends `{shot: {dir, speed, tip, cue}}`
  (turn unchanged) and the other end plays the shot with its own sim so the
  balls move at once. When the shooter's table settles and its referee has
  judged, it sends `{table: <every ball>, rules: <the referee's whole
  state>}` with the next turn. The watcher waits for both its own roll to
  end and that message, then takes the table and the referee's state as
  sent (a ball that differs slides to its place in 0.15 s). Placing the cue
  ball in hand is sent with the shot.
- Analytics: `versus_online_seek`, `versus_online_found` (wait_s),
  `versus_online_nobody` (choice), `versus_online_end` (why, won, moves).
- Haptics: finding a player is `GOOD`; the clock under 10 s on your move is
  one `WARN`.

## 4. Server files

- `server/database.rules.json` (the rules above), `server/firebase.json`
  gains `database` and the emulator on port 9000.
- `tools/deploy_live.sh`: `firebase deploy --only database`. Run by a
  person, like the other deploy scripts. The Realtime Database instance has
  to be created once in the project first.

## 5. Checks (no suite entries; throwaway probes, kept under tests/)

- `tests/_probe_live_rules.sh`: curl against the emulator: a claim, a second
  claim refused, a move out of turn refused, an early timeout refused, a
  late one allowed.
- `tests/_probe_online.gd -- chess|checkers|snooker`: headless, the real
  screen, the player's seat driven by the game's computer, against the
  emulator; two processes with different `BACKEND_PLAYER` play one whole
  game to the same result. Puts `user://versus.cfg` back.
- `tests/_shot_online.gd`: windowed shots of the lobby's states and an
  online board (a `Match` with a scripted stand-in, no network).

## 6. Build order

1. Rules, emulator config, rules probe, deploy script.
2. `Live`, `Backend.token()`/`BACKEND_PLAYER`, `Match`, `names.gd`; a
   two-process probe trading raw moves.
3. Lobby, the tab's Online chip, locale keys, chess; whole game over the
   emulator; shots.
4. Checkers.
5. Snooker.
6. Docs (`versus.md`, `turns-and-backend.md`, `analytics.md`,
   `haptics.md`), review, merge locally.

## Not in this version

Friends and codes, rating, chat or emotes, draw offers, rejoining a game
after the app was killed, spectating, a server that checks moves, a sweep
of old matches, push notifications.
