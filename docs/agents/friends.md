## Friends

2026-10-04, spec `docs/superpowers/specs/2026-10-04-friends-design.md`. A
link makes two players friends; a friend is asked to a live Versus game.
Read `docs/agents/versus.md` ("Online") and
`docs/agents/turns-and-backend.md` ("The Realtime Database") first.

### Server, Social and the match

Where the spec and the code differ the code is right; the differences are
listed at the end of this section.

- **The server is rules, as it is for Versus online**
  (`server/database.rules.json`; the paths and what each rule holds are in
  `docs/agents/turns-and-backend.md`, "Friends on the Realtime Database").
  Nothing is deployed: the emulator only.
- **`core/social.gd` (`Social`)** is static like `Backend`, started only by
  `world/main.gd` (`Social.start(host)`), and unstarted it answers offline
  without a byte sent. Started, it **sleeps until `enable()`** (the Friends
  sheet opened, a link shared or opened; kept in `user://friends.cfg` with
  the code and the uid the code belongs to), so a puzzle-only player holds
  no stream. `my_code()` and `add()` call `enable()` themselves.
  - API: `start`, `started`, `enable`, `my_code` (await; made on the first
    ask, up to six tries against a collision; once a session a code from
    the file is looked up and written again if the server has lost it),
    `link(code)`, `code_in(text)` (a link, `peepletdaily://f/…`, or typed
    text with spaces or dashes; "" for anything else), `add(code)` (await;
    `{ok, uid, why}`, why `offline`/`unknown`/`self`/`already`),
    `remove(uid)` (await), `friends()` (oldest first), `is_friend`,
    `loaded`, `refresh_presence()` (await), `is_online(uid)`,
    `invite_from(uid)`, `decline(from)`, `busy_with`, `in_game`, and
    `hub()` -- a Node that is there from the first ask (so a screen
    connects before anything is started) with `changed`, `befriended(uid)`,
    `invited(from, game)`, `withdrawn(from)`, `matched(from, game)`.
  - **It follows state**, with `Match._apply`: one `Live.Stream` on
    `social/{uid}` (a child of the hub), the document kept in `_doc`, and
    after every event `_digest` says what it implies that has not been
    said. A reopened stream sends the whole again; there is no reconnect
    code and none should be added.
  - **`add` waits for the identity** (`await Backend.token()`): on a cold
    start from a link `world/main.gd` calls it on the frame `Backend.start`
    was called, before there is a uid. `offline` is only an unstarted
    Backend or no token to be had.
  - **`befriended` is said from `add`'s own write**, not from the stream:
    a link opened as the game starts lands before the first whole read, and
    a friend that is in the first read is not news. `_known` keeps each
    said once. At the other end it comes off the stream.
  - **Invites are judged against the server's clock** once a second
    (`_judge`): fresh under 10 s (`Live.server_now()`), `invited` once as
    one turns fresh, `withdrawn` as it goes, goes stale, gains `match`, or
    asks for another game (then `invited` again). One 61 s stale is deleted,
    only once the clock has been read off a stamped write (`Live.clocked()`:
    presence's first beat). An invite from someone not in the list is not
    said.
  - **`in_game` declines at once** (the invite is deleted; the one asking
    sees "can't play right now"). **`busy_with == from`** makes it
    `matched` in place of `invited`.
  - **Presence**: `presence/{uid}` is written every 20 s while enabled and
    the application has focus (`NOTIFICATION_APPLICATION_FOCUS_*` and
    `PAUSED`/`RESUMED` on the hub; a paused tree does not tick it), and at
    once on focus coming back. Each beat also reads every friend's
    (`refresh_presence`, in parallel), so the tab's count moves without the
    screens asking; `changed` only when someone came or went. Online is a
    heartbeat under 50 s old.
  - **`Social.fake(state)`** (`{code, friends, online, codes, invites}`)
    makes it started with no network for a harness; the harness says the
    hub's signals itself. Under `BACKEND_PLAYER` the cfg is beside that
    identity (`<player>_friends.cfg`), so two processes are two players.
- **`Match`** gains `invite(game, uid)`, `accept(game, uid)` and
  `gone(why)`. The ticket of an invite is `social/{uid}/invites/{me}`
  (`{game, at}`), written and kept fresh by the code that keeps a queue
  ticket (`_seek`, `_write_ticket`, the 4 s heartbeat); the queue is never
  read (`_friend` is set). `match` on it -> `_join(mid, 0)`; the ticket
  gone under it -> `gone("declined")`; the write refused by the rules ->
  `gone("unfriend")`; `nobody` after `wait` and the asking goes on.
  `accept` is the claim in one PATCH (the match with `p0` the friend, `p1`
  this player, and `match` on their invite): yes -> `_join(mid, 1)`,
  refused -> `gone("expired")`, no answer -> `offline`; abandoned with the
  claim on its way, a match that was made is resigned, as in `_scan`.
  **`_reseek` is `gone("void")` with a friend**: void, a `cancel` on the
  match stream, or a result before both were seen. From JOINING on nothing
  is different. The stranger path is untouched: `seek` clears `_friend`.
- **`Online`**: `Online.with_friend = {uid, accept}` is read and cleared in
  `_init`; `online.friend` is the uid. `open()` asks (or, the first time
  with `accept`, takes the invite; **or takes an invite to this game that
  is already here**, because two invites that crossed a while apart would
  only wait on each other). `Match.gone` raises the lobby's gone card and
  never the queue; a match given up inside the found beat is `gone("void")`
  with a friend. `Social.matched` while the lobby waits and the game is the
  same: the end with the smaller uid calls `accept` (which drops its own
  invite), the other goes on waiting and is taken. `matched` when this end
  is not asking (the end card, the gone card) or for another game is said
  again as `invited` on the hub, so the menu's card comes up. `_tell` sets
  `Social.busy_with` and `in_game` (a stranger's game sets `in_game` too)
  and an Online on its way out only clears them if it was the last to set
  them (`_teller`). `again_button()` reads Rematch. The record and
  `versus_online_found`/`versus_online_end` are the stranger's. No screen
  changed.
- **The lobby**: `show_waiting(uid)`, `show_no_answer(uid)` (Keep waiting
  is `keep`, Back is `cancel`), `show_gone(uid, why)` (`declined`,
  `expired`, `void`; Ask again is the new signal `again`; `unfriend` has
  Back only -- `Online` turns any `gone` into it when the friend is no
  longer in the list). States `WAITING`, `NO_ANSWER`, `GONE`. Keys
  `VS_FRIEND_*` in `locale/ui.csv`, after the `VS_END_` block.
- **The wire**: a friendship is one root PATCH
  `{social/A/friends/B: {at, via: CODE}, social/B/friends/A: {at}}` by B;
  removing is one root PATCH of both halves and both invites to null; an
  invite is a PUT of `{game, at}` and a PATCH of `{at}` every 4 s; the
  accept is `{matches/ID: {...}, social/me/invites/them/match: ID}`.
- **Probes** (emulators up: `cd server && PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
  firebase emulators:start --only auth,database --project demo-peeplet`):
  - `tests/_probe_live_rules.sh` (65 s; `QUICK=1` 12 s): 120 cases, 62 of
    them friends' -- every rule and each way to cheat it.
  - `FIREBASE_EMULATOR=127.0.0.1 FIREBASE_PROJECT=demo-peeplet godot
    --headless --path . --script res://tests/_probe_friends.gd` (about
    70 s): three processes, three new identities. b's first call is `add`
    on the frame Backend starts (the cold link); both lists, `befriended`,
    presence; then a asks b through a real `Online` on a bare Control:
    declined, withdrawn, accepted and six moves to `end`, both pressing
    Rematch on one tick (`matched`), a resignation, b removes a and a's next
    asking is `unfriend`. The conductor is a third player whose invite to a
    in the middle of the first game must be deleted unseen. It refuses to
    run without `FIREBASE_EMULATOR` and puts `user://versus.cfg` back.
  - `tests/_probe_match.gd` and `tests/_probe_online.gd -- chess` still
    pass unchanged.
- **Where it is not the spec**: both halves of a friendship must be in the
  one write, the opener's half too (the spec let the other's half land
  alone), and **a deletion must take both halves** (one half alone would
  leave a friend in one list who can neither be asked nor seen). `match` on
  an invite is refused from the one who asked (the spec's rule let either
  writer of the invite set it; nobody would have said Play).
  `gone("unfriend")` and the lobby's fourth gone card are not in the spec.
  `open()` taking an invite already here is not in the spec.

**Toy Boats is offered to a friend** (2026-10-09): the fourth game in
`ui/menu/invite_card.gd`'s `GAMES` and in the rules' three lists; its wire is
in `docs/agents/versus.md`. Not probed with a friend (the stranger's path was).
The picker holds four games and Cancel (`tests/_shot_friends.gd`, 378 draw
calls over the sheet at 810x1440).

**Penny Drop is offered to a friend** (2026-10-09): the fifth game in
`GAMES` and in the rules' three lists, its wire `{m: column}`. Not probed
with a friend (the stranger's path was, `tests/_probe_online.gd -- penny`).
The picker holds five games and Cancel and still fits its card at 810x1440.

**Dominoes is offered to a friend** (2026-10-09): the sixth game in `GAMES`
and in the rules' three lists, its wire `{d: tiles drawn, m: move}`, both
ends dealing from the match's seed. Not probed with a friend (the
stranger's path was, `tests/_probe_online.gd -- dominoes`), and the picker
with six games and Cancel was not shot.

**Reversi is offered to a friend** (2026-10-09): the seventh game in `GAMES`
and in the rules' three lists, its wire `{m: square}`, the turn kept by a
seat whose move leaves the other no square. Not probed with a friend (the
stranger's path was, `tests/_probe_online.gd -- reversi`), and the picker
with seven games and Cancel was not shot.

**Air hockey is not offered to a friend** (2026-10-08): it has no game
online (`docs/agents/versus.md`), `VersusTab.plays_online("hockey")` is false
and `ui/menu/invite_card.gd`'s `GAMES` is still the three.

### Screens

(2026-10-04; spec section 4.)

- **The Versus tab's row** (`ui/menu/versus_tab.gd`, `_friends_row`): a
  Button drawn by its children above the three cards -- plaque, Friends, a
  line (`FRIENDS_ROW_NONE` with no friends, `FRIENDS_ROW_AWAY`, or a filled
  dot and `FRIENDS_ONLINE_ONE/_N`), a chevron. Signal `friends`. Presence is
  read as the tab comes up (`_read_friends`, only for a player who has
  friends) and the line repaints on the hub's `changed`. It is one more child
  of the tab's column, so `_fit` counts it: **at 1080x1920 the cards now give
  up the lines under their names** (level 1 of `_compact`; the Online blurb
  with them) and the pictures stand at 167.
- **`ui/menu/friends_sheet.gd`**, a house `Sheet` (`menu.friends_sheet`).
  `_on_open` calls `Social.enable()`, awaits `Social.my_code()` and paints one
  of three states: `LOADING` (the body with the buttons off), `READY`,
  `OFFLINE` (Social not started, or no code: the sleepy moon, a line and Try
  again, nothing else). `READY` is Invite a friend (`Share.text` of
  `FRIENDS_INVITE_TEXT % Social.link(code)`; when it answers false the button
  reads Link copied for 2 s), the code on a tile with a copy button (the
  caption reads Code copied), Enter a code, the sprout, then the list:
  a count line and a row a friend -- face (sleepy when away), name, a filled
  dot and Online or a ring and Away, Play (the sun when online, paper when
  away; both work) and a round remove. Past 5.5 rows the list scrolls.
  Presence: `refresh_presence()` as it opens and every `REFRESH` 15 s. Signal
  `play(game, uid)`, said after the sheet has closed. `adding()` is true
  while the code dialog is up.
- **`ui/menu/code_dialog.gd`**: the card stands 300 under the top so the
  keyboard comes up under it. The field keeps itself to `Social.ALPHABET`,
  upper case, 8 (`_on_typed`; a whole link typed in is cut to its code), and
  takes the caret on a touch by `edit()` (a touch is not a click here).
  Paste reads the clipboard through `Social.code_in`. One line under the
  field per answer: `FRIENDS_ADDED` (green; Add becomes Close, Paste goes),
  `FRIENDS_ADD_UNKNOWN / _SELF / _ALREADY / _OFFLINE`, `FRIENDS_ADD_NO_CODE`
  for a paste with no code in it.
- **`ui/menu/invite_card.gd`**, one card for four things: `invite(uid,
  game)` (Play / Not now), `friend(uid)` (Play / Close; Play turns it into
  the picker; `can_play = false` leaves only Close), `pick(uid)` (the three
  games, Cancel), `remove(uid)` (Keep is the sun button, Remove the pill).
  Signals `play(game)`, `confirmed`, `dismissed`; `leave()` goes without a
  word. It knows no Social.
- **The menu's side** (`ui/menu.gd`, "# --- friends ---"):
  - `open_friend_game(game, uid, accept) -> bool`: leaves the card, closes
    every sheet, sends every host out by its own `_on_back` (so an abandon is
    still counted) with `_switching` set, which makes `_left_game` skip both
    the list and `Ads.leaving_game()`; then `Online.with_friend = {uid,
    accept}` and `_open_versus(game, Record.ONLINE)`. False while
    `Social.in_game`.
  - `invited` -> the invite card (`friend_card`, the menu's last child while
    it lives, z 30; `_raise_card` keeps it last when a host is mounted under
    it). Play accepts; Not now and Android's back `Social.decline`;
    `withdrawn` takes the card down. One card at a time: `_next_ask` looks
    for another friend's fresh invite when one goes.
  - `befriended` -> the new friend card, unless the code dialog is up (it
    says so itself) or a card already is; no Play while `Social.in_game`.
  - `friend_link_failed(why)`: a line on a pill for 4 s, for
    `world/main.gd` when a link made no friend (`self`, `unknown`, else the
    offline line).
  - `go_back` needed no change: every card and dialog has `is_open()` and
    `close()`, and the newest is found first.
- **Analytics from here**: `friends_invite_shared`, `friends_added` (via
  code), `friends_removed`, `versus_friend_answer` (play, not_now, and
  expired when the card is up as the invite goes). `versus_friend_invite` is
  `Online`'s, not the picker's.
- **Shots**: `caffeinate -d -i -u godot --path . --resolution 810x1440
  --always-on-top --script res://tests/_shot_friends.gd -- <outdir>
  [lang=en|pt|es] [rm]` -- 27 shots and 17 checks, `Social.fake`,
  `tests/_fake_match.gd`, `tests/_offline_main.gd`; it pokes
  `Social._faked`, `_friends` and `_invites` for the offline sheet and the
  invites, and puts the clipboard, `versus.cfg` and `friends.cfg` back.
  Without `lang=` it runs in this Mac's saved language.
- **Draw calls** (810x1440, the same en, pt, es and rm): the tab 163 (150
  before the row); the sheet with five friends 301, empty 212, offline 188;
  the picker over the sheet 324, the remove question 329; the code dialog
  251-254; the invite card over the tab 189, over a board 135; the new
  friend card 186, its picker 195; the lobby's friend states 152-160.
- **Open**: nothing here was touched on a phone -- the field taking the
  caret and the keyboard on a touch, a drag on a row scrolling the list
  (rows pass the event; a drag begun on Play or the remove does not scroll),
  Android's share sheet. `Social.add` answering `already` with no `uid`
  would print the line with a hole. A new friend who arrives while an invite
  card is up gets no card (they are in the list). The pt and es strings want
  a native eye.

### The link

**The forms.** `https://daily-games-420bf.web.app/f/<CODE>` is what is
shared (`Social.link`); `peepletdaily://f/<CODE>` is what the page's button
opens; on Android the button is
`intent://f/<CODE>#Intent;scheme=peepletdaily;package=com.peeplet.daily;end`,
which is the same link with the package named, so a phone without the game
goes to the store. `Social.code_in` reads the code out of any of them.

**The page** is `server/site/f/index.html`, one self-contained file: no
request, no tracker, nothing kept. `server/firebase.json` rewrites `/f/**`
to it. The code is the address's last piece, upper-cased and held to the
alphabet x 8; anything else shows "This link is not complete". `?c=<CODE>`
is the same for a server with no rewrite, which is how it is looked at:

    python3 -m http.server 8765 --directory server/site
    # http://127.0.0.1:8765/f/index.html?c=FRND2345   (TESTCODE has an O: the bad state)

en/pt/es by `navigator.language`; the by-hand route is spelled with the
game's own words (`FRIENDS_TITLE`, `FRIENDS_ENTER_CODE` in `locale/ui.csv`),
so a change there is a change here. Headless Chrome will not lay a window
out under 500 px wide: a phone-width shot is the page in a 390 px iframe.
Seen at 390 and 320, light and dark. The og: tags are the same for every
code (a static file cannot say whose link it is).

**Hosting.** The `ignore` list used to be `**/.*`, which would have dropped
`.well-known`; it now names `.gdignore` and `.DS_Store` only, and a header
serves the statement as `application/json`. `tools/deploy_site.sh` ships
the whole of `server/site` (hosting only), run by a person. **Not deployed
yet**: until it is, a shared link is a 404.

**The manifest.** `tools/patch_android_template.sh` adds an activity-alias
`.FriendLink` on `.GodotApp`, after the launcher's, to the template's
`src/main/AndroidManifest.xml` (the exporter writes only `src/debug` and
`src/release`; Gradle merges main under them): one filter for
`peepletdaily://f/...` and one for `https://daily-games-420bf.web.app/f/...`
with `autoVerify`. The script used to leave as soon as it found the AGP
already raised; now each patch is skipped when it is there and both always
run, and a manifest that is not one `.GodotApp` and one `.GodotAppLauncher`
fails loudly. CI and `tools/deploy_android.sh` both run it before the
export. Proven 2026-10-04 by a debug export to a scratch path and

    aapt2 dump xmltree --file AndroidManifest.xml friends.apk

which shows `activity-alias name="com.godot.game.FriendLink"
targetActivity="com.godot.game.GodotApp" exported=true`, a filter with
`scheme="peepletdaily" host="f"` and one with `autoVerify=true
scheme="https" host="daily-games-420bf.web.app" pathPrefix="/f/"`, each
VIEW + DEFAULT + BROWSABLE.

**The statement** is `server/site/.well-known/assetlinks.json`, for
`com.peeplet.daily`, with two SHA-256 fingerprints:

- `73:2D:29:9E:...:45:6C:74`, the debug keystore `~/.android/debug.keystore`
  (`keytool -list -v -alias androiddebugkey -storepass android`, and the
  same digest from `apksigner verify --print-certs` on the exported APK).
  CI signs with the same key: its `ANDROID_DEBUG_KEYSTORE` secret is the
  base64 of that file (`docs/agents/ci.md`), so every App Distribution
  build carries it. That the secret still holds this key was read from the
  docs, not checked.
- `C3:CD:C0:FE:...:27:0C:B4`, the Play app-signing certificate, copied from
  Play Console > App signing on 2026-10-04 and handed over by the
  coordinator; not seen first-hand by the agent that wrote the file.

Missing: an upload/release keystore's, if a build signed with one is ever
installed outside Play (there is none in the repo). Unverified, an https
link opens the page in the browser and the page's button does the rest, so
nothing depends on verification; it only saves a tap. Android verifies at
install, and re-reads the statement rarely: after the first deploy,
`adb shell pm verify-app-links --re-verify com.peeplet.daily` and
`adb shell pm get-app-links com.peeplet.daily` say where it stands.

**`core/deep_link.gd`** -- `DeepLink.take()` answers the link the game was
opened with once, "" after. Android: `AndroidRuntime.getActivity()
.getIntent().getDataString()`; a link tapped with the game open arrives
through `onNewIntent`, where `GodotActivity` calls `setIntent` (read off
the 4.7 template's classes with `javap`), and the intent is still there on
every later resume, so what was taken is remembered (by the intent's
`hashCode` and its text where the bridge reaches `hashCode`, by the text
alone otherwise). Elsewhere: the user argument `--link=<url>`, once.

**`core/share.gd`** -- `Share.text(text, title) -> bool`: Android's share
sheet through `Intent.parseUri` (the ACTION_SEND, its type and the text as
a uri-encoded string extra in one `intent:` uri, so no Java constructor)
and `Intent.createChooser`; true only if every step answered with an
object. Anything else, or any failure, is the clipboard and false, and the
caller says "Link copied". `Share.last` says which ("sheet", "clipboard").

**`world/main.gd`** starts `Social` after `Backend` and calls `_take_link()`
at `_ready` and on `NOTIFICATION_APPLICATION_RESUMED`: `DeepLink.take()` →
`Social.code_in` → `Social.enable()` → `await Social.add(code)` →
`friends_added {via: link}` on a yes. A failure that deserves a word
(`self`, `unknown`, `offline`; not `already`) goes to
`menu.friend_link_failed(why)` **if `ui/menu.gd` has that method** -- it
is looked up with `has_method`, so until the menu grows it a failed link
is silent. `_take_link` does nothing while `Social` is unstarted and leaves
the link untaken, so `tests/_offline_main.gd` calls it too and stays
offline. A link at a cold start reaches `Social.add` on the first frame,
before the backend has signed in: `add` has to wait for the identity
rather than answer `offline`, or the commonest case fails.

**A link on desktop.** The real game: `godot --path . -- --link=https://daily-games-420bf.web.app/f/FRND2345`
(or `peepletdaily://f/FRND2345`). A harness: give the game a `Social.fake`
whose `codes` holds the code, build the main scene on
`tests/_offline_main.gd`, and pass the same argument after `--`; probed
headless that way 2026-10-04 (both forms befriend, a bad code and the
player's own do not).

**Unproven on a device** (none was attached): everything on the phone's
side of the bridge. The Java calls were checked against what could be read
here -- Godot 4.7's class reference documents `JavaClassWrapper.wrap`,
`JavaObject.has_java_method` and nothing else (the descriptions are empty;
Java methods are called by name, as `core/haptics.gd` already does), the
`AndroidRuntime` plugin's `getActivity()` and `GodotActivity.onNewIntent`
were read from the template's `classes.jar`, and the engine library names
`CharSequence` among the types it converts, which `createChooser`'s title
needs -- but none of it has run: that `take()` sees a link at a cold start
and on a resume, that a tap on the https link opens the game once the
statement is deployed, that the share sheet rises, and that the page's
`intent://` button opens the game or the store. If `createChooser` will not
take a GDScript String, `Share.text` falls to the clipboard on its own.

**iOS has no way in** without a native plugin (no URL scheme in the export,
no universal link, no share sheet): the page shows the code and the player
types it; `Share.text` copies the link.

### After the review (2026-10-04)

- **The first whole read is not news.** `_on_event` used to set `_loaded`
  before `_digest`, so every friend already had was said `befriended` at
  each launch and the menu raised the New friend card for the oldest one.
  `_digest(mine, first)` now keeps the first read quiet; a friend made by
  this player's own `add` before that read is still news.
- **Removing a friend deals a new code** (`Social.new_code()`, which
  `remove()` ends with, not awaited). A code is all it takes to be a
  friend, and the one removed still holds it: without this they are back
  with one tap. The cost: every link this player sent before stops working,
  redeemed or not. There is no button for a new code on its own, and no
  block list; both are open.
- **`my_code()` is one ask at a time** (`_coding`): two at once each dealt
  a code and the loser stayed in `/codes` as a working orphan.
- **The one who accepts does not delete the invite** (`Match._join`): the
  asker (p0) does. An asker whose ticket stream reopened in that gap read
  nothing there and called it declined, with a match naming them made.
- **Android's back, `open_friend_game` and `world/main.gd`'s `_modal_open`
  only count a `CanvasItem` that answers `is_open()`.** `Live.Stream` has
  `is_open()` and `close()` too and sits under an online screen: back
  closed the ticket or match stream and the game went deaf. This was on
  `main` for a stranger's game as well.
- **A link waits for the age question** (`_take_link` returns, link
  untaken, while `UI/AgeScreen` is up; the answer calls it again).
- **An invite whose Play could not open the game is declined**, so the one
  who asked hears no in place of waiting out "no answer".
- **`DeepLink` ignores an intent flagged `LAUNCHED_FROM_HISTORY`** (a task
  relaunched from Recents carries the link it began with). Not run on a
  phone, like the rest of the Android half.
- Rules: `via` is a string of 8.

### Open

- **Server side** (2026-10-04): the rules are not deployed
  (`tools/deploy_live.sh`, by a person) and nothing of friends has met the
  live database or two phones. No game through a real board with a friend
  was probed (the probe's moves are bare; the screens did not change, and
  `_probe_online.gd` proves them against a stranger). Not probed: the 61 s
  sweep of a stale invite, an accept abandoned mid-claim, `matched` for a
  different game, presence stopping on focus lost, a code collision. Codes
  are never deleted and a player with a new identity leaves the old one's
  friendships behind in the other lists. An invite reaches a friend only
  while their game is open and focused enough to hold its stream; there is
  no push.
