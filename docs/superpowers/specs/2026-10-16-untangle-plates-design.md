# Untangle on plates (2026-10-16)

The user, 2026-10-16, with a page of untangle games (peg grids among them):
"redo untangled game so we can add more complexity based on different grids
not only the current one, and also let's remove the cat from insane and just
make the insane being a way harder and bigger board"; then "Both" (outline
shapes and full peg grids), "Keep knots everywhere", "build it", and of the
kitten: "i just want you to remove the cat that keep shuffling things on
insane, not the cat itself".

## What changed

- **A plate is where the holes are** (`puzzles/untangle_plate.gd`, made once
  per id and shared): `ring:N` (the old board), hoops `square:N`, `hex:N`,
  `tri:N` (holes round a bowed edge, in order), and boards `grid:RxC`,
  `honey:19`, `honey:23` (holes drilled all over a wooden plank). Holes are
  in plate units; a ring's lie on the unit circle as before.
- **No three holes in a line.** Hoops bow out (the square is a
  superellipse); a board's holes sit `JITTER` 0.075 of a spacing off the
  lattice, by a hash of the plate id, so every copy is the same.
- **The rule on geometry.** `o` is the turn table of every three holes;
  `crosses` is two ropes' pegs on either side of each other's line. A carry
  passes rope y when the carried rope's line (from its other peg) crosses y
  before and not after, or after and not before. On a ring or hoop that is
  the old interleaving rule exactly: a probe played the new rule against a
  copy of the old one, 7200 of 7200 random moves equal on rings of 10, 13,
  17 and 19 (live carry included). On a board it also counts the rope
  sweeping past one of y's pegs. Either way a pair's count is odd exactly
  when the straight lines cross (13200 moves over every plate, parity and
  move-made-back both checked: `tests/_probe_ut_plates.gd`).
- **Which end pairs with which** across an evenly wrapped pair is read off
  the holes: the pairing whose joins do not cross, and the shorter when
  neither does (the four not in convex position). Any function of the holes
  keeps a move made back exact; this one is the ring's on a ring.
- **Reach is a length** (plate units), not a span of holes.
- **The deal**: a crossing-free start is `_pair_up` round a ring or hoop and
  a random tie-up uncrossed by swaps on a board (each swap is shorter, so it
  ends). Bands pick a plate by the day's draw:

| Band | Plates (ropes) | Moves | Par | Wraps | Knots | Most crossings |
|---|---|---|---|---|---|---|
| Easy | ring:10 (4), square:12, hex:12, tri:12 (5) | 3 | 3 | 1 | 0 | 6 |
| Medium | ring:13 (6), square:16, tri:15 (7) | 5 | 5 | 2 | 1 | 10 |
| Hard | honey:19 (8), grid:5x4 (9) | 6 | 6 | 2 | 2 | 13 |
| Insane | grid:5x5 (11), honey:23 (10) | 10 | 10 | 3 | 4 | 22 |

- **Insane is way harder by numbers** (8 seeds a plate, this Mac): par 10
  against Hard's 6 (the old Insane's was 8), crossings median 17-18 against
  10-11, knots median 4 against 2, 25 or 23 holes and 10-11 ropes against
  19-20 and 8-9. Its deal searches with a beam of 16 (`beam` in the band):
  mean 221 / 142 ms, worst 676 / 215 (grid / honey), par unchanged at 10.
  The old Insane was 161 / 611. The deal is made on the frame the board
  opens; a phone reading is owed.
- **The kitten no longer swipes.** Gen, State and the board lost her
  schedule, targets, swipes, paw, yarn countdown and ghost; the tutorial's
  CAT page, `UT_TIP_CAT`, `UT_CAT_SWIPE`, `HTP_UT_CAT*`, `HTP_UT_SWAT_CAP`
  and the `pounce` cue went. She stays on Insane over the plate: pettable
  (`purr`), watching the peg in the hand, joyful on the win, sleepy when
  thread runs out. Undo is open on Insane now that nothing is random.
  The Insane seal reads `BN_INSANE_SEAL` (`UT_CAT_SEAL` went).
- **Drawing**: `_build_plate` lays a ring (as before), a hoop (the ring's
  wood along the curve, offset by normals) or a board (one plank, edge,
  light, grain; the ropes lie on the wood). Knots are kept inside by the
  plate's edge table (a radius a degree). Pegs on a board are
  `PEG_OF_SPACING` 0.27 of the spacing. Three rope colours were added for
  Insane's eleven ropes. The kitten's head room is 196 (was 176) so she
  clears a square board's corner.
- **Tutorial**: Hard and Insane add a second page, BOARD: a nine-hole board,
  a peg lifted out of the middle over the other rope, both come free.

## Decided for the user (unconfirmed)

- The band table above: which plates, how many ropes on each.
- The thread stays off on every band (`slack` 0, as it already was); the
  rules text no longer promises it.
- The kitten watches the held peg; the seal is the shared Insane one.
- Level labels: "Rings and hoops", "Hoops", "Peg boards · 8 or 9 ropes",
  "Big peg boards · 10 or 11 ropes" (pt/es written by me).
- A rope may lie over a peg in a hole it does not end in (the reference's
  ropes do); the rule does not read it.

## Owed

A phone run (deal time on Insane, the plates at phone size), the pt/es
reads, the user's verdict on the plates.
