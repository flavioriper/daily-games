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
  `new_puzzle`, `reduce_motion`, `haptics_toggled` (with `on`, 2026-10-03), `tab_opened` (the menu's Versus or Arcade
  category, Stats or Streak, with `tab`; `factory` is no longer sent since 2026-10-13, when it became an Arcade card), and on a board that can be turned,
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
  `undos`, `colour`; checkers adds `taken` and `lost`, pieces; air hockey
  (`game: hockey`, 2026-10-08) sends `shots` as your mallet's hits and adds
  `seconds`, and `level: 4` is two players on one phone, where `won` means
  the bottom mallet's and `shots` both mallets'; Toy Boats (`game: boats`,
  2026-10-09) sends `moves` as your pebbles, `hints`, `sunk` and `lost` in
  boats and `first`, whether you threw first; Penny Drop (`game: penny`,
  2026-10-09) sends `result` won/lost/draw, `moves`, `undos`, `hints` and
  `first`, whether you dropped first; Dominoes (`game: dominoes`,
  2026-10-09) sends `result` won/lost, `moves` as every tile laid by either
  side, `hands`, `hints`, `score`, `score_other` and `first`, whether you
  led the first hand; Reversi (`game: reversi`, 2026-10-09) sends `result`
  won/lost/draw, `moves` as every disc set down by either side, `undos`,
  `hints`, `discs`, `discs_other` and `first`, whether you moved first) and
  `versus_abandon`; since 2026-09-27 (Arcade): `arcade_start` (game),
  `arcade_end` (score, stage, seconds, fired, hits, kills, best;
  Molehill sends stage as the best streak, and whacked, escaped, missed
  and bunnies; Stackwood sends stage as the biggest
  block, and drops, merges, chain and tools; Lucky Thirteen stage as the
  biggest number, and moves, merges, chain, tools and reached; Posy stage
  as the day, and moves, made, cascade, picked and tools; Peapod stage as
  the wave, and kills, caught (gift crates broken), used (gifts started from the tray, since 2026-10-05), fired, rate, power, crit and energy (all the run made), and since 2026-10-06 cart (Sim.Cart, on `arcade_start` too) and own (how many of the cart's own card); Beeline (2026-10-09) sends stage as the ribbons won, 0 to 4, and flaps; Deckchair (2026-10-10) sends stage as the cards home, 0 to 52, and moves, passes (of the stock), undos, hints and won, and `hint_used` with `puzzle_id` deckchair; Eddy (2026-10-10) sends stage as the whirlpool's level, 1 to 10, and small and big (the things of each tier it took); since 2026-10-11 the level is 1 to 20, `arcade_end` also carries great and huge (tiers 3 and 4) and bank (the drops held after the run), `arcade_start` carries spin, pull, mouth and reach (the upgrades' levels) and no longer boosts, and `eddy_upgrade` (tile: spin, pull, mouth or reach; level after the buy; drops paid) is sent for each level bought, and since 2026-10-12 `arcade_start` also carries speed and `eddy_upgrade`'s tile may be speed (the fifth upgrade); Gumdrop (2026-10-10) sent stage as the moulds served, and perfect and last, for one day: since 2026-10-11 it is a daily board and sends the boards' events (`puzzle_start`, `puzzle_complete` with moves as its serves, `puzzle_abandon`, `board_reset`, `puzzle_redo`) and none of the `arcade_*` three) and `arcade_abandon`; since 2026-10-05 (Valley): `valley_enter` (place, trees standing, room), `valley_leave` (place, seconds, felled) and `grove_upgrade` (tile, level, energy paid; since 2026-10-07 tile is a shop tile (axe, reach, swing) or a node of the Grove's tree by its id: room, sprout, raft, jetty, bundle, tying, load, beaver, teeth, crit, critsize, luck, crate, cratesize, `kind:N` for the trunk and `soft:N` / `rich:N` for a kind's boughs, N the tier; `seeds` is no longer sent, what it was is `kind:N` with level 1; level is the node's level after the buy; no event was added for a gather, a landing or a crate); since 2026-10-06 (Nightlight, which is kept and sends none of the `arcade_*` three): `nightlight_enter` (mass, novas), `nightlight_leave` (seconds, eaten, mass, novas), `nightlight_upgrade` (tile, level, light paid), `nightlight_nova` (n, mass, dust), `nightlight_perk` (perk, count, dust paid) and, since the same day's fuel-and-powers pass, `nightlight_power` (power, level, suns: the pick's own mark, not the star's mass); `nightlight_upgrade`'s tile is one of meteor, volley, stream, ice since then, of puff, volley, stream, pure since the gas pass the same day, and of reach, flow, rich, pure since the ring pass (2026-10-07; `Sim.TILES`; a star kept before it loads with volley as reach, stream as flow and puff as rich, so a level reported under an old name and its new one are the same level); it was the gas pass when `nightlight_nova` became (n, suns, dust, how: nova or fade: the star ends by itself) and `nightlight_ignite` (stage: he, c, ne, o or si; suns) was added, and `nightlight_reset` (suns, novas, fades, dust: what the star was when Start over was confirmed) later that day; since 2026-10-07 (the universe pass) `nightlight_nova` also carries `remnant` (wd, ns or bh: what the end left as a relic, read when the end began) and `how` may be nova, nebula or fade; a body lost into a relic (`lost`) is not tracked, it happens several times a minute near a black hole; the ring pass (2026-10-07 to 10-08) added and removed no event: no event ever counted pours, so none changed its meaning when the Gas button went, and a press, a brake, a world eaten and the system's counts are not tracked (`nightlight_leave`'s `eaten` is still all the mass the star ate while the screen was open, gas and solids together; the Arcade card's worlds are read from the file, not sent); snooker's hint and reset
  send the boards' `hint_used` and `board_reset` with `puzzle_id` snooker.
- **`level_switch`** (2026-10-13: `puzzle_id`, `difficulty`, `to`) is sent
  when the in-game level card (`ui/flat/level_card.gd`) opens another level;
  an unfinished board sends `puzzle_abandon` first, as Back does. The win's
  invite still sends `next_level`.
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

**Furrow (2026-10-11)** is kept, so it sends no `arcade_start` or
`arcade_end`: `furrow_enter` (plots, crops, seeds, away in seconds, ripe),
`furrow_leave` (seconds, seeds, picked, sweeps), `furrow_plot` (n, seeds
paid), `furrow_crop` (crop, seeds paid), `furrow_upgrade` (tile, level,
seeds paid), `furrow_sweep` (n, seeds: a clean sweep only). No event a
pick. Since 2026-10-12: `furrow_buy` (tile: coop, hen, rooster, fence,
pasture or cow; seeds paid), `furrow_mile` (tile: egg or milk; n; seeds),
`furrow_fox` (took 0 or 1, hens left); `furrow_upgrade`'s tile is also
mulch, feed, nest, care or pail. No event an egg or a bottle. `rules_opened` carries `puzzle_id` furrow.

**Trivet (2026-10-12)** is a run and sends the Arcade's three:
`arcade_start` (game, boosts), `arcade_end` (score, stage as the level
reached, seconds, placed: stacks set down, chain: the most stacks one move
put away, best) and `arcade_abandon`; `board_reset` and `rules_opened` with
`puzzle_id` trivet. A mat's hop, a stack put away, a tool used and a level
are not tracked.

**Griddle (2026-10-12)** is kept too, so no `arcade_start` or `arcade_end`:
`griddle_enter` (served, stars, coins, away in seconds), `griddle_leave`
(seconds, served, stars, coins), `griddle_buy` (tile: lot, cow, stall,
grill or till; coins paid), `griddle_upgrade` (tile, level, coins paid),
`griddle_rush` (n, coins: a rush of five or more, as it ends),
`griddle_clean` (n, coins), `griddle_star` (n), `griddle_boil` (mood:
garden, vet, crew or town; coins billed), `griddle_favour` (mood, coins
paid). No event a sale, a cut or a cow milked. `rules_opened` carries
`puzzle_id` griddle.
