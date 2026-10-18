# Bagatelle: the fifteenth Arcade game

2026-10-15. Built unattended. The user, with nine screenshots of a web
game: "here is next arcade game to be created, check on web for further
references. Wire sounds, cozy animations, rewards, great player experience
like the arcade games have. Do everything autonomous."

## 1. What it follows, and what it may not be

The reference is the idle pin-drop game the user played on a web portal
(screenshots of 2026-10-15), itself after the television game show's
pin-board. **That name is written here once, to forbid it: Plinko.** It
appears nowhere in code, comments, commits, locale or on screen; neither
does the portal's game title. Nothing of the reference is kept but the
shape:

- a board of pins, balls dropped from the top by a tap or by an auto
  dropper, landing in cups along the foot that pay the ball's worth times
  the cup's multiplier;
- a cup levels up the more balls land in it, and its multiplier with it;
- coins buy run upgrades (ball count, ball value, auto drop, ball weight);
- balls come in tiers; ten of one tier merge into one of the next;
- cash out: a run's coins become a permanent second currency spent in a
  shop of lasting upgrades; bonus pins (a plus pin and a times pin) can be
  moved about the board.

What is not kept: the night-sky purple, the XP bar, investments, ascend,
the slots and stats tabs, skins, the watch-an-ad tier ball, away progress.

## 2. The game

**Bagatelle**: the old parlour board. A tall board of plum velvet edge to
edge, brass pins in staggered rows, matte clay and glass marbles falling
through them, seven turned wooden cups along the foot, each with its
multiplier painted on and its level on a little tag. A brass dropper glides
back and forth along the top.

- **Tap the board** (or hold Drop) and a marble leaves the jar at the
  tap's across, kept within the middle band (0.36 to 0.64 of the board),
  dropped from the top; a finger held on the board keeps dropping every
  0.16 s. The auto dropper (an upgrade) lets one go where it is as it
  glides over the same band (±0.14 of the board from the middle).
- **The jar** holds every marble you own. A marble in the air is out of
  it; landing, it rolls back. The jar is shown in the top-left of the
  board as one chip a tier: the tier's marble, "in jar / owned".
- The jar lets the **best marble it holds** go first.
- A marble pays `value × worth(tier) × cup multiplier × pin bonus ×
  polish × (1 + 0.1 × sqrt(stars ever earned))` in coins.
- **Marbles do not knock each other**: each falls alone through the pins
  (the genre's rule, and what keeps a hundred in the air cheap).

**Cups**: seven, base multipliers 2, 1, 0.5, 0.5, 0.5, 1, 2 (5/2/1/0.5/1/2/5
until 2026-10-16, when the user found the rewards "too high since
beginning"). Each landing is a
point to that cup; a cup goes up a level at `need(lv)` points, and its
multiplier is `base × (1 + 0.1 × lv)`. The middle fills fastest, the edges
pay most.

**Tiers**: twelve, Clay, Glass, Agate, Swirl, Cat's-eye, Opal, Moonstone,
Pearl, Ember, Frost, Comet, Star; tier k is worth `20^k`. Ten of a tier
merge into one of the next (the Marbles card: Merge per row, Merge all). A
merged marble is worth twice the ten, but drops one at a time: a jar too
merged runs dry between drops. That is the choice.

**Run upgrades** (coins; Buy ×1 or Max):

| Upgrade | Rank 0 | A rank | Price |
|---|---|---|---|
| Marbles | 3 clay | +1, +1, +2, +2, +3 ... marbles a rank (of the Finer marbles tier) | 10 × 4.25^n (10, 42, 180, 767) |
| Value | 1 | `1 + n` | 2 × 1.6^n |
| Auto drop | off | `2.4 s × 0.9^(n−1)`, at least 0.1 s; 40 ranks | 30 × 1.3^n |
| Weight | gravity ×1 | +12% gravity, 25 ranks | 60 × 1.45^n |

**Cash out**: stars = `floor((log10(coins earned this run) − 3.0)^2.5 ×
shine)`: about 10K coins pay one, 1M fifteen, 1e8 fifty-five, 1e15 five
hundred (3.7 until 2026-10-16, when the prices rose and the cups fell). (A square root of the coins was tried first and ran
away: every ×20 tier went straight into the stars and each cash out
doubled the last in seconds.) Every star ever earned also adds to every
coin, `1 + 0.1 × sqrt(stars ever)`, a root so it converges. A cash out
resets coins, upgrades, cups and marbles. Stars are kept for ever and buy:

| Star shop | Ranks | What a rank does | Prices in stars |
|---|---|---|---|
| Plus pin | 5 | one more gold pin: a marble that touches it is worth +50% (once a pin) | 2, 5, 12, 30, 75 |
| Times pin | 3 | one more rose pin: ×2 (once a pin) | 10, 40, 150 |
| Polish | 10 | every coin ×1.25 | 5 × 2^n |
| Full jar | 5 | the run starts with 3 more clay marbles | 1, 3, 8, 20, 50 |
| Finer marbles | 6 | marbles bought come a tier better (the tiers' road) | 20, 80, 300, 1000, 3000, 9000 |
| Twins | 5 | a drop lets go two marbles one time in five more | 4, 10, 25, 60, 150 |
| Warm cups | 5 | cups start a run at level 5 a rank | 3, 8, 20, 50, 120 |
| Shine | 5 | +25% stars from a cash out | 5, 15, 40, 100, 250 |

Bonus pins stand on pins of the board; **a finger held on one carries it**
to another pin. They stay where they are put across cash outs.

**Numbers are floats.** Tier 11 alone is worth 20^11 ≈ 2×10^14; with
value, cups and polish a coin count passes int64. Coins, worth and prices
are floats, shown 999, 12.4K, 3.1M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc, then
1.2e36.

**The physics is the sim's own**, fixed steps of 1/120 s, circle against
pin, a seeded RNG for the scatter, no physics bodies, so the probe can
replay a seed. Marbles do not touch each other. **A blow sends a marble
left or right afresh** (170 to 250 across, 40% against the side struck):
without it a drifting marble rides the staggered pins' diagonal to a wall.
The wide rows' two outermost places are left bare, as a pin there stands
closer to the wall than a marble is wide. A fall takes about 2.4 to 2.9 s.

**The bot's pace** (`tests/_probe_bagatelle.gd -- 7 120`, a greedy buyer
tapping four times a second, cashing out at half its stars ever): first
cash out at 5.8 minutes, ten stars at 20, 474 by two hours. A bot's, not a
promise.

**Kept like Tally**: `user://bagatelle.cfg`, no run end, no end card, no
gold, no boosters, no interstitial. **The board runs only while it is on
screen** (the Factory's and Tally's rule).

## 3. The screen

The board fills the screen, and the whole board -- pins, dropper and the
seven cups along its foot -- is laid inside the room between the plate row
and the tray. Over it the flat boards' top bar and a plate
row: coins (and the coins a second, smoothed), stars (and "Cash out +N"
when a cash out would pay). At the foot a tray of four round buttons:
Upgrades, Jar, Stars, and the big Drop on the left (the thumb side).
**Draw calls**: the pins are one cached mesh; every marble in the air is
laid into one mesh rebuilt a frame (one `draw_mesh` for the swarm), the
pin halos into one more; the cups one cached mesh and their tags strings.
A marble that touched a bonus pin wears a ring of the pin's colour, never a
shade of its own (the marbles are coloured by tier).

Cards (the house Dialog card) for Upgrades, the Jar (its's tiers, Merge
and Merge all), Stars (cash out and the star shop).

## 4. Moments, sound and feel

Every touch is heard and felt. The takes are the bank's
(`tools/sfx_bank/`, the user's 2026-10-15 rules): pins the pebble (very
quiet, a step down a row, throttled), a cup landing the bubble wrap, a
buy the jar coin, refused the tongue, a cup's level and a new tier the
kalimba notes, a cash out the longest rise.

A hit pin glows softly (a halo, never rays) and the marble shivers off it;
a landing squashes its cup and floats its coins; a big landing sends coins
to the plate; a cup's level hops its tag and rings it; a new tier is named
with confetti; a cash out rains stars. `Motion.reduce` stills all but the
words.

## 5. Calls that are mine, the user's to change

1. **The name** Bagatelle and the plum velvet, brass pins, clay marbles.
2. **Tap where to drop**, kept to the middle band (the reference drops
   from the middle only); the dropper glides only over that band (at
   ±0.36 it fed the ×5 edge cups and paid half again over a tap).
3. **Seven cups**, base 2/1/0.5/0.5/0.5/1/2 (5/2/1/0.5/1/2/5 until 2026-10-16), +10% a level.
4. **Twelve tiers**, 10 into 1, worth ×20.
5. **One prestige layer** (stars) and its shop; no investments, no ascend,
   no XP bar. Stars from the coins' digit count, and the star bonus.
6a. **Every figure** in the tables: upgrade prices, the cups' +10%, the
   star formula, the shop's prices. Tuned on a bot only.
6. **No away progress**, no gold, no ads in the game.
7. **No concept tab** (the user said "do everything autonomous").
8. **No mascot**: the marbles are pieces, not characters.

## Amendment, 2026-10-18: the redesign

The user: "polish and redesign bagatelle to something more cozier and
elegant ... there is a element moving at top but ball spawn always at
middle, balls sometimes falls outside the multiplier buckets ... game
progression is insanely bad ... 3 -> 10, 10 - 20, 20 - 50". What changed
(the detail is in `docs/agents/arcade.md`, "Bagatelle redrawn"):

- Call 2 is over: the dropper is the only place a marble comes from, it
  glides on its own and nothing steers it; a tap, Drop and Auto each let
  one go where it is. The empty-jar sticker is gone.
- Auto lets one marble go at a time, from the dropper; sixty marbles in
  the air at most (a draft that re-dropped every landed marble was
  refused: "it should auto drop 1 ball, not all").
- Brass fins between the cups: a marble always lands inside one, and is
  seen settling into it.
- The jar climbs 1, 2, 3, 5, 10, 20, 50, 100 ...; a rank's price follows
  the ladder to a power. Value is +1 a rank still.
- The field is 1150 tall with thirteen rows.
- The look is redrawn (lamplight, walnut, domed pins, glass marbles,
  trails, sparks, motes, cup glows); `land` pitched by the cup, a big
  landing is the jar coin with a kalimba fifth under it.
- A pace test times every buy; see the arcade notes for the ratios.
