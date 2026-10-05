# Peapod, the Arcade tab's sixth game

2026-10-04. Built in one sitting while the user was away, from two
screenshots of a phone ad and the brief: "implement this new arcade game, do
it end to end, make sure it's fully wired and with same quality of others
games ... feel free to use web for references and rules based on top
trending games of the same direction".

## 1. The game

**It is called Peapod and nothing else**, in code, in a comment or on
screen (id `peapod`). The references are the cannon-against-numbers phone
games -- *Ball Blast* (Voodoo) and the block-wall and number-snake shooters
that follow it, named here once to forbid them. What was taken from them:

- A cannon at the foot of the screen that **only slides and never stops
  firing**; the finger aims, nothing else.
- **Every target wears a number**: the peas it takes. Its paint says the
  weight of the number (a step up each time it trebles: green, teal, blue,
  indigo, violet, plum, maroon, dusk) and changes as it is worn down.
- **Gift targets** among them (the ad's `+bullet`, `+cannon` and barrel
  tiles) that give the gun more shots, a quicker rate or a second cannon.
- Two kinds of level, as the two screenshots show: **a wall of numbered
  tiles five across** coming down, and **a snake of numbered plates behind
  a head** winding down a path.
- Whatever reaches the cannon's line ends the run.

Its own choices:

- **A gift must be caught.** A gift crate shot open drops a token, and the
  cart has to be under it: aiming and catching pull against each other,
  which is the whole of the play once the gun is strong.
- **Four gifts**: one more pea a volley (five at most), a quicker gun
  (eight steps, 5 to 9.8 volleys a second), a heavier pea (+1 a pea, no
  cap), and a helper cart for twelve seconds that rolls a column over. A
  gift already at its most is a heavier pea instead.
- **A firecracker crate** from wave four takes its eight neighbours with it;
  **a golden crate** pays five times its number.
- **The millipede** is every third wave. A plate shot off knocks the whole
  of it back along the path (16 units); the head is worth six plates, and
  with the head gone the rest goes off plate by plate, each paid for.
- **The score is the numbers shot down**, plus 50 a wave cleared times the
  wave. The record's "furthest" is the wave.
- A wall still high up comes down five times as fast, so a cleared sky
  never waits; the same for the millipede's first stretch.

Numbers: a crate's is `2.4 x 1.45^(w-1)` to wave ten and `x 1.25` a wave
after, times `1 + 0.3 x row` and a roll of 0.7-1.3. A wall has `4 + w/2`
rows (nine at most), two gifts (three every fourth wave) and comes down at
6.5 to 15.5 units a second. `tests/_probe_peapod.gd`'s bots: one that
wanders and lets most gifts fall ends on wave 5-10 in two to four minutes;
one that aims and catches ends near wave 20-23 in about six.

## 2. The screen

The Arcade's wooden frame under the flat boards' top bar (Peapod, motto
*Hold the line*) and a paper row: score, best, wave. The garden is 300 x 460
field units stood on its bottom edge, the extra height of a phone given to
the sky. A chalk line of dashes marks what nothing may reach; it reddens
and runs, with a red glow from the edges, as something nears it. On the
grass under the cart, the gun's line: peas, rate and weight, each a picture
and a number.

**A slide, not a spot** (Firefly's rule): the cart moves as far as the
finger did, times 1.35. Left and right on a keyboard.

Drawing: the garden is one still mesh. Each crate, plate, token and part of
the cart is a cached mesh moved by the transform; the numbers are lettered
over them; the peas, sparks, line and glows are two live meshes. 52 draw
calls at rest, 73-85 in play, ~124 with a full wall of fifteen and every
gift falling, 105-118 on the end card, 262 on the tab with six cards
(810x1440), ANGLE agreeing.

## 3. Sound and touch

22 sounds (`CARTOON` crates and peas, `ARCADE` jingles). `shot` and `hit`
fire several times a second, so they sit very low and play through a second
`Fx2D` with `buzzes` off: the gun is heard and never felt. Everything else
asks through `_feel` and the frame knocks once with the strongest
(docs/agents/haptics.md, row 38).

## 4. Gold

Two boosters at 120: **Second pea** (start with two a volley) and **Quick
pod** (start two steps quicker). The Second chance shoves the wall four and
a half rows back up, or the millipede 700 units back along its path.

## 5. Not done

No tutorial page (no Arcade game has one; the ready line says "Slide to aim.
Catch the gifts."). The sounds are one take each and unheard by the user.
The balance is a bot's, not a hand's.

## 6. The second pass (same day)

After the user played it: the helper is six seconds and one pea, not twelve
and a full volley; three pods (Fan, Dart, Berry) and three gifts (Magnet,
Frost, Shove) joined the four; a rotten gift and an iron crate came in; the
millipede knocks back less and quickens as it shortens; a token drifts into
the cart's reach. The lag was script, not draws. The detail and the numbers
are in `docs/agents/arcade.md`.

## 7. The soft pass (2026-10-04, the user: "redesign based on Posy's style and Lucky Thirteen's, polish the animations, more visual rewards even if silly, always elegant")

Screen, art and the tutorial's rim only; the sim is untouched, so the bots'
figures stand.

**The look.** The wooden frame and the saturated sky with its blue peaks are
gone. The garden sits on the flat boards' parchment card (Lucky Thirteen's),
Posy's hedges round its foot. Inside it: a pale sky going to cream, three
rows of soft hills, round trees and daisied bushes, pastel grass with a
scalloped edge. A crate is a rounded pastel tile with a thin lip in its own
paint deepened and its number in ink (paper on the dusk tier), no line round
it; the eight paints are Lucky Thirteen's pastels. A gift crate is a cream
parcel showing the medallion of the token it holds, so the crate and what
drops out of it are one picture. The millipede is a row of round paper discs
(Lucky Thirteen's piece, with legs) behind a plum head seen from above; its
number rides a paper tag. The cart is pale wood, the pod pale green; a pea
trails a wake. The gun's line is three paper pills on the grass, the running
gifts paper seats with a ring of their own colour. Banners are stickers with
their line on a paper pill; the stickers wear pastel letters
(`Rewards.sticker_cols`).

**The sun** (`ui/faces/sun_face.gd`, the game's own) comes up from behind
the far hills on the right, clear of the sky the crates come down. It
watches the cart, beams through a streak and a cleared wave, frets as the
line is neared, and puts a party hat on when the best is passed.

**Motion.** A crate gone leaves its shape swelling away; a pea landing is a
white blink laid over the piece and a swell of its number (never a shade of
its paint); a parcel sways and breathes; the plates waddle; the muzzle is a
pale ring; the cart hops as a gift is caught and bounces twice on a clear;
dust off the wheels of a cart rolled hard; a gift caught flies in an arc to
its place on the grass, which swells as it lands; clouds drift. The big
moments are held a beat (`_hold`: the head shot off, a clear, a firecracker,
the end), the run slowed and eased back. None of it under reduce motion.

**Rewards.**
- A streak of five or more is counted on a paper pill at the top, the time
  it has left running down under the count.
- A wave cleared is stamped one to three stars by how near the line was let
  (`STAR_PEAKS`: under 0.2 of `danger()` three, under 0.65 two), each a note
  higher, and **a flower comes up along the grass for each**: the run's
  garden, kept to its end and shown either side of the cart on the end card.
- The pod lets off a volley of confetti on a clear.
- The best passed mid-run **crowns the pod** for the rest of the run (and on
  the end card).

**Not done.** No new sounds: the stars reuse `catch` pitched up, a gift
landing `hit`. Nothing was run on a phone. The stars change nothing in the
score.

## 8. The third pass (2026-10-05, the user: "remove the debuff, it make no sense. Also, increase the number of rewards but also the blocks", and no wave whose gifts are useless)

The rotten gift is removed outright. A wave holds three to six gifts (three,
one more every third wave) and they are planned as a set: at least half are
the gun's own (pea, rate, weight), never fewer than two, the first one met
is one of them, and each of the others (a pod, the magnet, the frost, the
helper, the shove) comes once a wave at most. A magnet needs a wave of four
gifts and is laid with two of them right behind it. Walls are six to twelve
rows with fewer gaps, the millipede `9 + wave` plates up to 26, and the
numbers climb 1.46 a wave to wave 10 and 1.38 after, tuned on the bots
until the aiming ones ended where they used to (wave 17-19, five to six
minutes) and the careless one a little further (4-10). The detail is in
`docs/agents/arcade.md`.

**Not done.** Nothing was run on a phone and nobody has played the new
curve; the bots catch more gifts than a hand does.
