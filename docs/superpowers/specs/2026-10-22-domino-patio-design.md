# Domino Patio: a numbers board

2026-10-22, built unattended (the user: "start next roadmap daily puzzle, do
everything autonomous, wire animations, sounds, everything to make it fully
playable and complete like other games"). Roadmap item 3
(`docs/roadmap-next-boards.md`); the mock is the roadmap page's
(`docs/brainstorm/next-daily-boards.html`), so there is no concept tab, as
with Glimpse and Birdsong.

The genre it follows is the New York Times' domino-placing daily, Pips.
That name is never used in code, comments, commits or on screen, and
neither is the same word for the dots on a tile: they are **spots**. The
board is **Domino Patio**.

## 1. The game

A patio of squares, parted into flower beds, each bed with a tag that is
its rule. A rack of the house's dominoes under it. Lay every tile on two
squares side by side so the patio is covered and every bed keeps its rule.

| Tag | Rule |
|---|---|
| a number | the bed's spots add up to it |
| `<n` | they add up to less than n (Medium on) |
| `>n` | to more than n (Medium on) |
| `=` | every number in the bed is the same |
| crossed `=` | every number in the bed is different (Hard on) |
| none | anything (bare stone, no tag) |

- **Drag** a tile from its bay onto the patio; a ghost shows the two squares
  it would take (the nearest pair that fits within 0.75 of a square of the
  finger). Let go over the patio where it cannot lie: refused (rose halo,
  shiver, it goes back). Let go off the patio: back to its bay (from the
  patio, that is a move).
- **Tap** a tile to turn it a quarter clockwise: freely on the rack; on the
  patio about its first square, then about its second, the first way that
  fits, else refused.
- **Undo** every band but Insane (its seal). **The bin** asks, then puts
  every tile back. **The bulb** lays one tile of the answer where it goes,
  and sends whatever lay there back to the rack. **No Check**: the tags say
  how each bed stands, from the rule alone, on every band: a leaf tick when
  the bed is full and keeps it, a rose ring when what lies in it already
  breaks it.
- The patio covered with a bed unhappy: "A bed's rule is broken" over the
  rack. The patio covered and every bed kept: solved. Any laying that keeps
  every rule wins; the answer is only the bulb's.

## 2. Bands (`puzzles/patio_gen.gd`)

| | tiles | box | rules | bulbs |
|---|---|---|---|---|
| Easy | 4 | 4x4 | sum, = | 3 |
| Medium | 6 | 5x5 | + under, over | 2 |
| Hard | 8 | 5x6 | + all different | 1 |
| Insane, **The Spare** | 8 + 1 spare | 6x6 | as Hard | 1 |

**The Spare** (Insane's own rule, harder by logic, not by a limit): one tile
more than the patio holds; it goes nowhere, and the player has to find
which.

## 3. The day

Built from its answer, from the host's rng (the day's seed per band): a
patio grown a domino at a time inside the band's box (snug pairs likelier,
so it grows round, not in arms); different dominoes of the double-six set
dealt onto that tiling; the squares parted into beds (sizes 1-4 by band,
a bed spreading over its seed's number three times in four, so all-the-same
beds come up); a rule per bed read off the answer.

Then tightened until **only one answer exists, counted by what the beds can
see**: two layings are the same answer when every bed holds the same
spots (a tile turned end for end inside one bed changes nothing a bed can
see). A solver counts to two; on a second answer a bed that differs is made
stricter (a loose rule becomes its exact sum or `=`). Three partings with
three deals of numbers each are tried before a bed is ever split; a split
leaves lone squares. A count past 4,000 steps throws the day away.

Measured over 120 seeds a band (`tests/_probe_patio_gen.gd`, this Mac): every
day unique; mean 0.4 / 4 / 59 / 67 ms, worst 1 / 24 / 254 / 267 ms. Beds a
day 4.3 / 5.8 / 8.1 / 9.3, of which lone squares 1.4 / 1.6 / 3.0 / 5.0.

## 4. The screen

A bleed board (`"bleed": true`, `"tray": "none"`, `"actions": false`,
`"level_card": true`). From the top of the span: the patio (squares in
their bed's colour, Queens' pastels without tan and silver; bare beds are
stone; a line round every bed with a tag), then the rack, a wooden tray
with a bay for every tile, the empty ones outlined. The tags sit on each
bed's first square's corner, over the tiles.

The world (`puzzles/patio_world.gd`): a sunny terrace; cream sky with a
pergola beam and vines hanging into the tools row's gap, a garden wall with
a hedge, sandstone flags in a running bond, two pots of geraniums at the
foot.

The tiles are the house's (`ui/faces/domino_tile.gd`, lifted out of Versus
Dominoes unchanged, which now draws through it too). Every state is a mark
round a thing, never a shade of it: the coloured-by-index rule holds twice
(spots by number, beds by index).

Motion: the patio pops in, the tags drop in, the rack's tiles pop in one by
one; a tile glides to wherever the rules put it (a drop, Undo, the bulb and
the bin alike) and spins a quarter when turned; a laid tile bumps; a
refused one shivers inside a rose halo; a kept bed's tag bumps, ticks and
sparkles; a broken one shivers; the win is a hop wave across the patio,
then confetti, and the patio eases into the win's span.

## 5. Sound and touch

All pops from `tools/sfx_bank/`, by their jobs: `pick` the pebble, `set` the
token (varied 0.94-1.06), `turn` the wrap, `lift` / `back` / `undo` the lip,
`refuse` / `broken` the tongue, `bed` three wraps rising (pitched up a step
for each extra bed kept by one move). `hint`, `reset`, `confetti`, `solved`,
`party` (no bulb and no refusal) are Birdsong's takes copied; `enter` its
token phrase. Nothing bought. Unheard.

## 6. Brain report

Logic (the arithmetic-inside-Logic call). Timed, no `skill_quality()`: the
roadmap's "time and hints only". Tips `BRAIN_DP_1..4`. Share line: a
flower and a green square a ruled bed.

## 7. Decided for the user, unconfirmed

- The name, the terrace world, the beds as flower beds.
- The bands' numbers above; The Spare as Insane's rule.
- Turning by tap (on the patio, about the first square, then the second).
- Tags over the tiles at each bed's first square; `≠` drawn as a crossed `=`.
- The tags' tick and ring on every band, Insane included.
- The worst generation time over Quilt's 194 ms gate on Hard and Insane
  (~260 ms on this Mac), and Insane's share of lone-square beds (about half).
