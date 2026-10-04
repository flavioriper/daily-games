# Friends — design

2026-10-04. Decided without the user in the loop, at their word ("do
everything autonomous"). Builds on Versus online
(`2026-10-04-versus-online-design.md`, `docs/agents/versus.md`,
`docs/agents/turns-and-backend.md`).

## What it is

A player sends a link. Whoever opens it is their friend from that moment,
both ways, with nothing to confirm. A friend can be asked to a game of
snooker, chess or checkers; the friend sees a card, says Play, and the two
are in the same live game Versus online already plays (a minute a move).

Kept from Versus online: anonymous identity (the Firebase uid), the assigned
face and name (`Names`, "Hedgehog 482"), no typed names, no chat, no rating,
rules-only server on the Realtime Database, REST only.

Out of this version: push notifications (a friend is reached only while the
game is open), nicknames, blocking beyond Remove, a friends leaderboard,
install-referrer (a link opened before the game is installed leaves a code
to type or paste).

## 1. Data and rules (`server/database.rules.json`)

```
/codes/{code}                     uid
/social/{uid}/friends/{other}     { at, via? }
/social/{uid}/invites/{from}      { game, at, match? }
/presence/{uid}                   { at }
```

- **A code** is 8 characters of `ABCDEFGHJKMNPQRSTUVWXYZ23456789`. Created
  only where none exists, with the writer's own uid as value; deleted only
  by its owner. Readable one at a time by anyone signed in; `/codes` itself
  is not readable (no listing).
- **A friendship is two entries**, `social/A/friends/B` and
  `social/B/friends/A`, written by B (who opened A's link) in one root
  PATCH. `social/$uid/friends/$other` may be **created**
  - by `$other`, with `via` a code whose value is `$uid` (knowing A's code
    is the whole permission), or
  - by `$uid`, when the other half exists in the same write
    (`social/$other/friends/$uid` in `newData`),
  and never with `$uid === $other`. `at` is `now`. It may be **deleted** by
  either of the two. No updates.
- `/social/{uid}` is readable by `uid` (one stream carries friends and
  invites).
- **An invite** `social/{to}/invites/{from}` is a private ticket: written
  by `from` only while `social/{to}/friends/{from}` exists, `game` one of
  the three, `at` `now` (re-stamped every 4 s). Readable by `from` too.
  Deleted by either. `match` is set once, by `to`, while `at` is under 10 s
  old, to a match that does not exist yet and that the same write creates
  with `p0 === from`, `p1 === to` and the same `game`.
- **A match** may now be created two ways: both queue tickets pointing at
  it (as before), **or** `social/{p1}/invites/{p0}/match === $id` in the
  same write with the invite's `game` equal to the match's. Everything
  after creation (seen, moves, clocks, results) is unchanged.
- **Presence** `presence/{uid}/at` is `now`, written by `uid`; readable by
  anyone in `social/{uid}/friends`.

## 2. `core/social.gd` (`Social`)

Static like `Backend`, woken only by `world/main.gd`
(`Social.start(host)`): unstarted means every call answers offline and
nothing is listened to. Holds one `Live.Stream` on `social/{uid}` and a
timer node under `host`.

It stays asleep (no stream, no presence) until the player **has social**:
they opened the Friends sheet, shared a link, or opened someone's. That is
`user://friends.cfg` (`enabled`, `code`), so a puzzle-only player holds no
connection.

```
static func start(host: Node) -> void
static func started() -> bool
static func enable() -> void                 # has social from now on; opens the stream
static func my_code() -> String              # await: this player's code, made on first ask; "" offline
static func link(code: String) -> String     # https://daily-games-420bf.web.app/f/<code>
static func code_in(text: String) -> String  # a code out of a link, a peepletdaily:// url or typed text; "" if none
static func add(code: String) -> Dictionary  # await: {ok, uid, why}; why: "" | "offline" | "unknown" | "self" | "already"
static func remove(uid: String) -> bool      # await
static func friends() -> Array[String]       # uids, oldest friendship first
static func is_friend(uid: String) -> bool
static func loaded() -> bool                 # the list has been read at least once
static func refresh_presence() -> void       # await: reads every friend's presence
static func is_online(uid: String) -> bool   # from the last refresh: at under 50 s old
static func invite_from(uid: String) -> String   # the game a fresh invite from uid asks for, or ""
static func decline(from: String) -> void    # deletes the invite
static var busy_with := ""                   # the friend Online is waiting on or playing
static var in_game := false                  # a live online game is on
signals (on Social.hub(), a Node): changed, befriended(uid), invited(from, game),
    withdrawn(from), matched(from, game)
```

- `befriended` is said for a friend that appears after the first whole
  read, at either end (the one who opened the link hears it from its own
  write landing).
- An invite is **fresh** while its `at` is under 10 s old by
  `Live.server_now()`; `invited` once when a fresh one appears, `withdrawn`
  when it goes or goes stale. One 61 s stale is deleted.
- While `in_game`, a fresh invite is declined at once. While `busy_with ==
  from` and not `in_game`, it is `matched` instead of `invited` (both
  pressed Rematch, or both asked each other).
- Presence beats every 20 s while enabled, the window focused and not
  paused.

## 3. `Match`, `Online`, the lobby

- `Match.invite(game, uid)`: the ticket is `social/{uid}/invites/{me}`
  (`{game, at}`), heartbeat as a queue ticket, no scan. `match` on it →
  `_join(mid, 0)`. The ticket deleted under it → `gone("declined")`.
  `nobody` after `wait` as now (the looking goes on). `leave()` removes
  the ticket.
- `Match.accept(game, uid)`: the claim PATCH (the match with `p0 = uid`,
  `p1 = me`, and `social/{me}/invites/{uid}/match`); yes → `_join(mid, 1)`,
  no → `gone("expired")`.
- A private match that is void, or given up before it began, does not go
  to the queue: `gone("void")`.
- New signal `gone(why)`. Everything from JOINING on is the code that is
  there.
- `Online.with_friend := {}` (static; `{uid, accept}`), read and cleared in
  `Online._init`: the menu sets it before it builds the screen at level 3.
  `online.friend` is the uid ("" against a stranger). `open()` invites or
  accepts instead of seeking; sets `Social.busy_with`/`in_game` and clears
  them on the way out. On `Social.matched(friend, game)` while waiting, the
  end with the smaller uid leaves its own invite and accepts the other's.
- The lobby gains `show_waiting(uid)` (the friend's face, "Waiting for
  Hedgehog 482…", Cancel), `show_no_answer(uid)` (Keep waiting / Back) and
  `show_gone(uid, why)` (Ask again / Back). `again_button()` reads Rematch
  with a friend and asks them again. A friend's game counts in the same
  online record (`chess_3`).

## 4. The screens

- **Versus tab**: one row above the cards, "Friends" with how many are
  online, opening the Friends sheet. It takes its height out of `_fit`'s
  room.
- **Friends sheet** (`ui/menu/friends_sheet.gd`, a house `Sheet`): Invite a
  friend (the sun button: shares the link); the player's code with a copy
  button; Enter a code; then the friends, each a face, a name, Online or
  Away, a Play button and a remove (asks first). Empty: a face and one line
  that says a link is all it takes. Play asks which game (three buttons),
  closes the sheet and opens the screen.
- **Enter a code**: a house dialog with one `LineEdit` (upper-cased, the
  alphabet only, 8), Paste, Add; it accepts a pasted link. It says who was
  added, or why not.
- **The invite card** (`ui/menu/invite_card.gd`): over anything but a live
  online game — the friend's face and name, "wants to play Chess", Play /
  Not now. It goes when the invite does. Play closes whatever is open (no
  interstitial in between) and opens the game at level 3 accepting.
- **New friend card**: `befriended` → the friend's face, "is your friend
  now", Play / Close.
- All of it through `tests/_fake_social.gd`-style stand-ins for shots;
  nothing in a harness touches the network.

## 5. The link

- `https://daily-games-420bf.web.app/f/<CODE>` (Firebase Hosting,
  `server/site/f/index.html`, a rewrite of `/f/**`). The page: the game's
  name, "A friend wants to play", an **Open the game** button, the code
  with Copy, and how to enter it by hand (Versus › Friends › Enter a
  code). en/pt/es by `navigator.language`. On Android the button is
  `intent://f/<CODE>#Intent;scheme=peepletdaily;package=com.peeplet.daily;end`
  (Play Store when not installed); elsewhere `peepletdaily://f/<CODE>`.
- **Android**: `tools/patch_android_template.sh` adds an activity-alias on
  `.GodotApp` with two filters: `peepletdaily://f/…` and
  `https://daily-games-420bf.web.app/f/…` (`autoVerify`), and
  `server/site/.well-known/assetlinks.json` names the signing certificates
  known. Unverified, the https link opens the page and its button does the
  rest.
- `core/deep_link.gd` (`DeepLink.take() -> String`): on Android the
  activity's intent data, once per intent, read at start and on
  `NOTIFICATION_APPLICATION_RESUMED`; elsewhere `--link=<url>` on the
  command line (for harnesses). `world/main.gd` hands what it gets to
  `Social.code_in` → `Social.enable()` → `Social.add()`; the new friend
  card follows from `befriended`.
- `core/share.gd` (`Share.text(text) -> bool`): Android's chooser through
  `JavaClassWrapper` (`Intent.parseUri` + `createChooser`); anywhere else,
  or if that fails, the text goes to the clipboard and it answers false so
  the caller says "Link copied".
- **iOS** has no way in without a native plugin: the page shows the code
  and the player enters it. Noted in the docs as open.

## 6. Proving it

- `tests/_probe_live_rules.sh` gains the cases for codes, friendships,
  invites, the private claim and presence, each with the ways to cheat it.
- `tests/_probe_friends.gd`, two processes against the emulator: a code
  made, a link opened, both lists and `befriended`; presence; an invite
  accepted into a match that trades moves to a result; one declined; one
  withdrawn; both asking at once (`matched`); a friend removed and an
  invite then refused.
- `tests/_shot_friends.gd`, windowed, no network: the tab's row, the sheet
  empty and with friends, the code dialog and its answers, the picker, the
  invite card, the new friend card, the lobby's three new states, pt and
  es, reduce motion, draw calls a shot.
- An Android debug export to see the manifest merge.

## 7. Analytics

`friends_invite_shared` (`how`: sheet|copy), `friends_added` (`via`:
link|code), `friends_removed`, `versus_friend_invite` (`game`),
`versus_friend_answer` (`game`, `choice`: play|not_now|expired).
