<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Analytics

Gameplay events go to Firebase (project `daily-games-420bf`) over the GA4
Measurement Protocol, in `core/analytics.gd`. No native SDK of its own --
the Android export moved to the Gradle path for AdMob's and godot-iap's,
see "Ads and the purchase" below.

- **Nothing sends unless `Analytics.start()` runs**, and only `world/main.gd`
  calls it. Tests and harnesses build the same screens and stay silent; keep
  it that way rather than making this an autoload.
- The API secret lives in `analytics_secret.cfg` beside `project.godot`:
  untracked, packed by the preset's `include_filter`, overridable with
  `GA_API_SECRET`. Missing secret means the game runs untracked, not broken.
- Events: `game_open`, `puzzle_start`, `puzzle_complete`, `puzzle_abandon`,
  `hint_used`, `undo_used`, `check_used`, `board_reset`, `rules_opened`,
  `new_puzzle`, `reduce_motion`, `haptics_toggled` (with `on`, 2026-10-03), `tab_opened` (the menu's Stats or Streak
  tab, with `tab`), and on a board that can be turned,
  `view_turn` and `peek_used`. A daily turn adds `turn_lock`, `turn_reveal`,
  `turn_share` and `crowd_reveal_opened`. Board events carry puzzle_id,
  difficulty, day, seconds, moves, hints, checks; the last two tell us
  whether Pipes' third dimension is a puzzle or a nuisance. Since 2026-09-25:
  `store_opened` (with `door`: banner, header or settings), `purchase_started`,
  `purchase_complete`, `purchase_failed` (with `reason`), `restore_used` (with
  `found`), `consent_failed`, and `ad_banner_loaded` / `ad_banner_failed` /
  `ad_banner_impression`, and since 2026-09-29 `age_answered` (band), `ad_interstitial_shown`, `ad_interstitial_skipped` (`reason`), `ad_rewarded_offered` / `ad_rewarded_started` / `ad_rewarded_completed` (`placement`) and `ad_load_failed` (`format`, `error`) -- see "Ads and the purchase" below. Since 2026-09-26
  (Versus): `versus_start` (game, level), `versus_end` (won, both scores,
  shots, your highest break; chess: `result` won/lost/draw, `moves`,
  `undos`, `colour`; checkers adds `taken` and `lost`, pieces) and
  `versus_abandon`; since 2026-09-27 (Arcade): `arcade_start` (game),
  `arcade_end` (score, stage, seconds, fired, hits, kills, best;
  Molehill sends stage as the best streak, and whacked, escaped, missed
  and bunnies; Stackwood sends stage as the biggest
  block, and drops, merges, chain and tools; Lucky Thirteen stage as the
  biggest number, and moves, merges, chain, tools and reached; Posy stage
  as the day, and moves, made, cascade, picked and tools; Peapod stage as
  the wave, and kills, caught (gift crates broken), fired, rate, power, crit and energy (all the run made)) and `arcade_abandon`; snooker's hint and reset
  send the boards' `hint_used` and `board_reset` with `puzzle_id` snooker.
- **`puzzle_complete` carries a `solved` boolean**, added when Hidden Word
  landed (2026-09-19): until then `done` implied solved, so the event had
  nothing to say either way. Hidden Word can run out of rows
  (`PuzzleBase.finish_unsolved`) without solving, and that ending fires
  `puzzle_complete` with `solved: false` from `ui/puzzle_host.gd`'s
  `_on_ended` -- a lost board is still a terminal event, and without one a
  player who reads six rows and backs out looks identical to a crash. Every
  other board only ever sends `solved: true`, from `_on_solved`. Since
  2026-09-24 a flat daily solve's `puzzle_complete` also carries `hearts`
  (that day's boards, 0-3) and `streak`; a board dealt from New carries
  neither, because it is not a daily and is not logged.
- **`locale` rides on every event**, stamped by `Analytics.track()` beside
  `session_id` and `engagement_time_msec` on whatever it is handed, so any
  event can be split by language without a caller remembering to pass it.
- To debug the wiring: `Analytics.validate = true` posts to GA4's validation
  endpoint and prints the verdict instead of recording; `Analytics.debug_mode`
  puts events in the console's DebugView.
- `tools/analytics_secret.sh <secret>` installs the secret in both places that
  need it (the untracked file and the `ANALYTICS_API_SECRET` repo secret) and
  then sends one DebugView-tagged event, so the wiring is visible rather than
  assumed. GA4's collect endpoint answers 204 to everything, so DebugView is
  the only proof a secret actually works.
- **Versus online** (2026-10-04, level 3; all four from
  `versus/online/online.gd`, every one with `game`):
  `versus_online_seek` (each look: the screen opening, and every Find
  another); `versus_online_found` (`wait_s`, whole seconds from the seek);
  `versus_online_nobody` (`choice`: `keep` and `computer` off the nobody
  card, `offline` for Play the computer off the No connection card, `cancel`
  for Cancel or Android's back while looking or on the nobody card -- so it
  also fires for a player who cancels before the card ever said nobody; Back
  on the No connection card sends nothing); `versus_online_end` (`why`:
  `end` on the board, `resign`, `timeout`, `left`; `won`; `result`
  won/lost/draw; `moves` -- chess's fullmove, checkers' move number,
  snooker's shots), once a game, from `settle`. **A game online fires
  `versus_online_end`, never `versus_end`**, and a resignation through Back
  is a `versus_online_end` with `why: resign`, never a `versus_abandon`. A
  foul (the other end's move was not legal) is `why: left`, won.
  `versus_start` still fires with `level: 3` as an online screen opens,
  before anyone is found, and again with the computer's level when Play the
  computer is taken; count games online from `versus_online_found`.
- **Friends** (2026-10-04): `friends_invite_shared` (`how`: `sheet` when
  the phone's share sheet took the link, `copy` when it went to the
  clipboard, and for the code's copy button; `ui/menu/friends_sheet.gd`);
  `friends_added` (`via`: `code` from `ui/menu/code_dialog.gd`, `link` from
  `world/main.gd`); `friends_removed` (the sheet, once the remove landed);
  `versus_friend_invite` (`game`; `versus/online/online.gd`, as the asking
  begins, so Rematch and Ask again count too); `versus_friend_answer`
  (`game`, `choice`: `play` and `not_now` from the invite card in
  `ui/menu.gd`, Android's back counting as `not_now`; `expired` from the
  menu when the invite goes with its card up, and from `Online` when Play
  was pressed on one already gone). A friend's game then sends
  `versus_online_found` and `versus_online_end` as a stranger's does, and
  no `versus_online_seek` or `versus_online_nobody`.
