<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Gold, gifts and the shop

**Since 2026-09-28** (spec `2026-09-28-gold-gifts-design.md`, built while
the user was away): gold is earned, never sold -- a board's first daily
solve (20), a 7-day calendar (one missed day forgiven, day 7 the big one),
a hearts gift for three boards, and a trickle from Arcade runs (5, +20 on a
best, 60 a day at most) -- and spent on ten Arcade boosters (two a game) and
a shared Second chance. Nothing is random and every gift shows what it holds
before it is claimed: Brazil's Lei 15.211/2025 bans *paid* random items in
games minors reach, and pt-BR is one of our languages.

- `core/wallet.gd` is the autoload `Wallet` (`user://wallet.cfg`); point
  `Wallet.path` elsewhere and call `reload()` in a harness, as
  `tests/_shot_gold.gd` and `tests/_probe_wallet.gd` do.
- `arcade/boosters.gd` is the catalogue and `apply()`/`revive()`; every sim
  has a `revive()`. A screen calls `_ask()` (the boost card, or straight in)
  wherever it used to call `_new_game()` from outside, and its game-over
  function starts with `if _offer_chance(): return`.
- Boosters never multiply a score; a best made with one carries
  `best_boosted` in `arcade.cfg` and a leaf on its Arcade card.
- The gift button's badge counts claimable gifts; the gifts sheet opens by
  itself once a day (`Wallet.should_auto_open`).
- Sounds are `assets/sfx/wallet/` (claim, buy, coin, refused), awaiting the
  user's listen. Redone 2026-10-10 against the cozy rules
  (`docs/agents/sound.md`, the `wallet` row): no coin rings, `coin` is one
  notch of a wheel on the pill's own player (`ui/menu/gold_pill.gd`, not
  Fx2D), 50 ms a coin, and climbs 0.03 a coin with one random draw a throw
  (`CLINK_STEP`, `CLINK_VARY`; it was 0.05, 7.6 semitones at the twelfth).
  Spending gold in `arcade/second_chance.gd` and `arcade/boost_card.gd`
  plays no wallet cue. `tests/_probe_wallet.gd` (headless, sims and arithmetic),
  `tests/_probe_chance.gd` (every screen's Second chance through the real
  menu), `tests/_shot_gold.gd` (windowed, every new screen).
