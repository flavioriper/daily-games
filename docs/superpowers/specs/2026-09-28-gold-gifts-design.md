# Gold, gifts and the Arcade shop

2026-09-28. Built while the user was away, on their word ("do everything")
after a short design in chat: gold as the reason to come back (mostly from
the daily boards, a trickle from the Arcade), a 7-day calendar plus a gift
for filling today's hearts, and gold spent on boosters for the five Arcade
games (approach C: two pre-game boosters a game plus a shared Second
chance).

## 1. What the web says, and what we took

- **Login calendars** run 7/14/30 days with the best reward on the milestone
  day, and forgive a missed day more and more often (grace days, freezes)
  rather than resetting ([MAF](https://maf.ad/en/blog/daily-login-rewards-engagement-retention/),
  [Mistplay](https://business.mistplay.com/resources/daily-login-rewards)).
  Nearly half the US top-100 grossing iOS games escalate their daily reward
  ([GameRefinery](https://www.gamerefinery.com/feature-spotlight-progression-daily-rewards/)).
  Duolingo's streak freeze is reported to have cut at-risk churn by 21%
  ([Deconstructor of Fun](https://duolingo.deconstructoroffun.com/mechanics/streaks)).
  -> a 7-day calendar, day 7 the big one, one missed day forgiven.
- **Pre-level boosters** (Royal Match's rocket, TNT, light ball) are the
  moment players spend most willingly, and King hands out free "samplers" so
  a booster's value is felt first
  ([Game Developer](https://www.gamedeveloper.com/business/match-3-monetisation-new-booster-selling-trend-in-king-games),
  [Medium](https://medium.com/@ekinmelissezer/game-analysis-for-royal-match-and-toon-blast-9c4bff8ef48b)).
  -> a boost card before each Arcade run, and one of everything free at the start.
- **Brazil's Lei 15.211/2025** (in force 17 March 2026) bans loot boxes --
  *paid* random items -- in games minors are likely to reach
  ([PocketGamer.biz](https://www.pocketgamer.biz/brazil-bans-loot-boxes-for-under-18s-in-online-child-safety-measure/)).
  pt-BR is one of our three languages. -> **gold is never sold** and **every
  gift shows what is in it before it is claimed**; nothing here is random.
- Timed chests every few hours ([MLBB](https://mobile-legends.fandom.com/wiki/Chest_Rewards))
  were considered and turned down: a calm game, once or twice a day.

## 2. Gold: where it comes from

All on the device (`user://wallet.cfg`), never sent anywhere but analytics.

| Source | Gold | Notes |
|---|---|---|
| Welcome (first launch) | 150 | plus one of every booster and one Second chance |
| A daily board solved | 20 | first solve of each board per UTC day, any level (29 boards: 580 at most) |
| Hearts gift (3 boards today) | 100 | plus the day's featured booster; claimed by hand |
| Calendar day 1..7 | 50, 75, *Second chance*, 100, *2 featured boosters*, 150, 250 + Second chance + 2 boosters | one claim a UTC day |
| An Arcade run finished | 5, +20 on a new best | at most 60 a day from the Arcade |

A typical day (three boards, the hearts gift, the calendar, a few runs) comes
to about 250-300 gold, about two boosters: "a booster is about half a day".

**The calendar** keeps `step` (0-6, the next day to claim) and `last` (the
date key of the last claim). A claim is open when today > last. If today is
more than two days after `last` (two missed days in a row), `step` goes back
to 0 before the claim; one missed day is forgiven. After day 7 it wraps to
day 1.

**The featured booster** of a date rotates through the ten game boosters by
the date key, so everyone gets the same one on the same day.

## 3. What gold buys

| Game | Booster | Effect | Price |
|---|---|---|---|
| Firefly | Spare firefly | start with 4 ships | 120 |
| Firefly | Twin start | start as a pair | 120 |
| Molehill | +10 seconds | the round runs 70 s | 120 |
| Molehill | Steady hand | the first two streak-breakers are forgiven | 120 |
| Stackwood | Acorn pouch | start with 200 acorns | 120 |
| Stackwood | Low start | the first 10 blocks dealt are 2s and 4s | 120 |
| Lucky Thirteen | Clover pouch | start with +40 clovers | 120 |
| Lucky Thirteen | Head start | every pebble starts one number higher | 120 |
| Posy | Tool kit | +1 of each tool | 120 |
| Posy | Opening bloom | a breeze and a seed bomb in the bed at the start | 120 |
| all | Second chance | once a run, on game over: Firefly a ship back, Molehill +15 s, Stackwood clears the top two rows, Lucky Thirteen a free shuffle, Posy +5 moves | 200 |

Boosters **only help a run survive or start; none multiplies the score**.
A best made with any booster or a Second chance is kept like any other and
marked with a small leaf on its Arcade card ("boosted").

## 4. Screens

- **Menu header**: a fourth button, a gift, left of remove-ads, with a badge
  counting claimable gifts (calendar, hearts). It opens the **gifts sheet**.
  The sheet also opens by itself once a day, the first time the menu shows
  with the calendar claimable.
- **Gifts sheet** (`ui/hud/gifts_sheet.gd`): the gold pill; seven day tiles
  (claimed, today, to come) each showing what it holds; Claim; then the
  hearts gift row -- three hearts filling, what it holds, Claim when full.
  A claim bursts coins from the tile into the pill, which rolls up.
- **Arcade tab**: a strip on top, the gold pill and a Shop button.
- **Shop sheet** (`ui/hud/shop_sheet.gd`): the gold pill, a chip per game,
  and that game's two boosters and the Second chance: icon, name, a line,
  how many owned, and Buy with the price. Buying needs the gold; there is no
  other price.
- **Boost card** (`arcade/boost_card.gd`), over the field before every run
  (first start, Again, restart) when the player owns one of that game's
  boosters or has the gold for one: the two boosters as toggles (owned count,
  or the price when none is owned -- a toggled one with none owned is bought
  on Play), the gold pill, and Play. Nothing starts selected.
- **Second chance** (`arcade/second_chance.gd`), over the field at game
  over, once a run, when one is owned or affordable: what it does in this
  game, Use (owned) or Buy and use (200), and No thanks. No timer.
- **End cards** carry the gold the run earned ("+25").

## 5. Code

- `core/wallet.gd`, autoload `Wallet`: gold, items, the calendar, the hearts
  gift, the daily earning caps; `changed` signal; `path` overridable so a
  harness never writes a real save.
- `arcade/boosters.gd`: the catalogue (ids, game, keys, icon, price) and
  `apply(sim, ids)` / `revive(sim)` per game.
- Each sim gains what the boosters need (`bonus` time and `forgive` on
  Molehill, `small_left` on Stackwood, a `revive()` on all five).
- `ui/menu/gold_pill.gd`: the coin and the count, rolling.
- Icons: `coin`, `gift`, `clock`, `shield`.
- Analytics: `gold_earned` (source, amount, balance), `gold_spent` (item,
  amount), `booster_used` (item, game), `gift_claimed` (kind, step).
- Sounds: `assets/sfx/wallet/` (coin, claim, buy, gift), awaiting the user's
  listen.
