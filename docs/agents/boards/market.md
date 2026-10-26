# Market Sums

- **Market Sums is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  seventh, a numbers board under Logic. Six numbered crates on a garden
  market stall and an order on the chalk board; combine two at a time with
  a sign until a crate holds the order. Spec
  `docs/superpowers/specs/2026-10-22-market-design.md`. The id is `market`
  and the locale prefix `MK_` (`MS_` is the Factory's tools; Factory's
  "market" building is a different thing in `factory/art.gd`).
- Files: `puzzles/market2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/market_state.gd` (the stall, combines, Undo, the bulb's step,
  quality), `puzzles/market_gen.gd` (the one `combine`, the solver, the
  bands and the deal), `puzzles/market_world.gd`, `ui/faces/market_art.gd`
  (crate, label, halo, sign tokens and their marks, the order board),
  `ui/hud/market_tutorial_diagram.gd`, `ui/menu/cards/market.gd`.
- **One combine for everything**: `Gen.combine` is what the board plays,
  and `Gen.reach` writes the same four signs out inline (the solver's whole
  cost; with a call per sign it ran 5x slower). Change one, change both.
- **The solver is by sets**: `reach(nums)` gives, for every set of crates
  (a bit each), every number it makes, each packed with how
  (`a << 22 | b << 8 | half-set << 2 | sign`). `smallest` finds the fewest
  crates that make a number, `steps_of` unfolds a way in playable order.
  Six crates take 4-12 ms headless on the Mac.
- **The phone deals its own day** (no bank): 365 days a band in
  `tests/_probe_market.gd`, worst 15 ms (Insane), and the bulb filled every
  one in exactly the band's fewest steps.
- **A place is a slot**: `slots[6]`, 0 when empty. A combine writes the
  result into the second crate's slot and empties the first; Undo pops a
  snapshot. The board's `_shown_v` lags the state through a slide, so the
  crate a slide lands in keeps its old number until it lands.
- **The board is its own tutorial**: `demo` makes it silent, deaf and laid
  in its own rect; the diagram taps crates and signs with `demo_crate` and
  `demo_sign`. Lessons MAKE, SIGNS (a share refused, a take-away made),
  ORDER (the answer played; on Insane every crate), HINT.
- **Draw calls**: 92-104 in play on Medium and Insane (six numerals, the
  order's strings, the count), 120 in a tutorial page, 6 on the card.
- Harness: `tests/_win.gd -- market` (real touches: a refused share, a step
  and Undo, the bulb's button, then the shortest steps);
  `tests/_shot_market.gd -- <dir> d=<0..3> [tut=<page>|card]` shoots rest,
  picked, refused, sliding, made, undoing, hinted, the win and the reopened
  day.
- **The look redone, 2026-10-23** (the user, after Picket Sums' pass:
  "apply same for market sums"). The card is the game in one look: the
  order board reads 12, crates 5 and 7 on a shelf, the go token's plus
  between them (a circled times read as a close button). Crates are a
  rounded box with a lit rim, two soft grooves and faint posts, the label
  bigger (`LABEL_W` 0.72, `LABEL_H` 0.48) and its numeral
  `Art.numeral_size`; the picked crate a sun ring with a soft glow, not a
  slab. **The step strip** under the signs spells the step being built, a
  slot each for crate, sign and crate ("5 + ?"), and the step just made in
  full ("5 + 6 = 11", the made number on leaf paper) for `EQ_HOLD` or
  until a sign is picked; a refusal takes the strip's place on rose paper,
  and the count under it is plain dim text (no outline). Its mesh is kept
  in `_strip_shown`: built and dropped in `_draw`, it was freed before the
  frame drew ("mesh is null"). Draw calls 95-98 playing, 151-156 at the
  win, card 6. Verdict owed.
- **Made fun, 2026-10-26** (the user: "make picket sums and market sums
  experience way better to play, and game itself way funnier to play, right
  now nobody likes it"). Measured first (`tests/_probe_mk_fun.gd`, 60 days
  a band, every legal first step): only 7 / 15 / 21% of first steps kept
  the fewest steps on Easy / Medium / Hard, and nothing on the stall said
  which, until the count at the win; on Insane 45% of first steps lost the
  way outright, with no Undo. Took Digits' (the newspaper numbers game)
  answers: closeness counts, and three stars rate the way.
  - **Tags of what a crate would make**: with a crate and a sign in hand
    every other crate wears a paper tag "= 150" (leaf when it is the
    order), and a crate the sign would refuse fades (`PEEK_*`,
    `_draw_peeks`, one mesh). Trying is reading, not sums in the head; the
    choice of the way stays the player's.
  - **The order board's line**: "closest 25, 117 off" (`MK_NEAREST`), sun
    once within `WARM` (a tenth) of the order, bumping when a step brings
    the stall nearer; that step's `make` pops up to `NEAR_PITCH` higher.
  - **Three stars on the count line** (`State.stars()`): 3 while the order
    can still be made in the fewest steps, 2 in one more, 1 past that, 0
    once these crates cannot make it. A step that costs stars drops them
    turning off their seats (`slip`, the lip twice falling, a tick), Undo
    pops them back. Read once a move in `_rate` (the solver is a few ms;
    never in `_draw`). Drawn by `ui/flat/star_line.gd` since the same
    evening, shared with Super Slider's count line.
  - **An undone step costs nothing**: `steps` is the length of the way
    kept (the bulb's steps too), so the brain score and the win line are
    the way taken against the fewest; the bin starts it at 0 again.
    `MK_WIN_CLOSE` for one step past the fewest.
  - **Insane is the same rule, a longer way** (the user's call on
    Caterpillar and Paper Planes the same day: a harder board, not other
    rules): Every Crate is gone, Insane deals five steps that need all six
    crates (nothing from five or fewer makes the order) and has Undo.
    Its first steps now lose the way 67% of the time (was 45%), which the
    stars and Undo answer. Deal worst 39 ms on the Mac (Hard 67).
  - Draw calls 96-104 playing (+4 with the tags), 150-159 at the win.
    `_shot_market.gd` shoots `slip` (a detour's stars falling, then Undo).
    Mine, the user's to call: tags on every band, stars that move during
    play, Every Crate dropped, Undo on Insane. Not seen on a phone, not
    heard.
