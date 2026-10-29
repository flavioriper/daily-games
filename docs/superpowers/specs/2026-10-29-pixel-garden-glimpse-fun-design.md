# Pixel Garden and Glimpse made fun (2026-10-29)

The user: "make pixel garden and glimpse experience way better to play, and
game itself way funnier to play, right now nobody likes it", autonomous,
push when done.

## Diagnosis

- **Pixel Garden** follows colour-by-number apps (and the user's own
  bead-kit refs). Those apps please through quick feedback on every cell, a
  palette that shows what is left of each colour, and a clear payoff at the
  end. Most of all, the cell tells you what it wants. This board kept the
  counts, the pops, the zoom and the iron, but it hides where the player is
  and stays silent about a slip. `tests/_probe_pg_fun.gd` (the bank, the
  first bead seated in the wrong colour, the rest seated right in reading
  order) counts the beads that go down after a slip before the board says
  anything. Until the kit runs dry: median 30 / 48 / 478 / 913 by band.
  Until the iron: 47 / 65 / 575 / 1023. A leaf on each finished row would
  speak at 2 / 1 / 23 / 31.
- **Glimpse** follows Memory Matrix, which shows tiles for a moment, judges
  each tap, and adapts. Glimpse shows one picture and says nothing until
  the last bead is down.

## Pixel Garden

1. **A leaf on a finished row**: when a row of the picture is right (every
   peg in it as the picture wants, at least one bead), a little leaf sprouts
   at the row's right end on the tray's rim, with a soft climbing note. If a
   bead later goes wrong in that row, the leaf goes. It confirms a whole
   row only, the way the old Check did, but never one bead.
2. **Where am I**: while a finger is on the board, the pattern card rings
   the square under it. Squares whose pegs already hold a bead are dimmed on
   the card (bead seated, right or wrong, the bar's own rule). Guides every
   four pegs from the seam, on the board and on the card (cross-stitch aida).
3. **Easy traces**: the board shows the picture's outline as darker
   wells under the pegs (shape only, never colour).
4. **The bulb reads before it fixes** (the house's two-press bulb): the
   first press rims every bead astray in rose and says how many, or rims
   the next bare peg the picture wants and names its colour. It costs one
   hint. A second press while the reading stands fixes one, for free.
5. **Live stars** by slips: beads the iron sent home plus bulbs read. 0 is
   three stars, up to 3 is two, more is one.
6. Kept: the iron waits for a full board, no moves, no Check, the deals.

## Glimpse

1. **Every bead is judged on the spot**: a bead the picture does not want
   there hops straight back to its compartment, the peg rimmed rose, a
   miss counted (the first try at that peg is kept, so "right first time"
   still holds). A right bead stays and climbs in pitch.
2. **Runs**: right beads in a row climb in pitch; from 5 in a row, a big
   word at each 5. The win names the best run.
3. **Live stars** by misses plus looks: 0 is three stars, up to 2 is two,
   more is one. Flawless is no miss and no look.
4. Undo goes (nothing wrong can stand). Off in Glimpse: the card's ring,
   dimming and guides (the card is covered), Easy's outline (it would read
   the answer), the bulb.
5. Rounds (one picture after another, growing) were considered and left
   out: they would change the one-picture day record.
