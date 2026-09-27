# Molehill, the Arcade tab's third game

2026-09-27. Built in one sitting while the user was away, from their brief:
"create another puzzle game, this time it gonna be wack the mole like (check
on web for reference and rules). include sfx. I have to leave so do
everything".

## 1. Where it lives

On the **Arcade tab**, the third card under Firefly and Hedgerow TD, not on
the daily grid. The brief said "puzzle game", but whack-a-mole is a
timed reflex game played for a score, which is what the Arcade tab is for
("games played alone for a score"); the grid's cards are daily boards with a
solve. Moving it would be a registry entry and a solve rule, and is the
user's call.

## 2. The game

**It is called Molehill and nothing else**, in code, in a comment or on
screen. The reference is the boardwalk cabinet *Whac-A-Mole* (Bob's Space
Racers; Hasbro's toy), a trademark, named here once to forbid it. What was
taken from it, checked against the cabinet's published rules and the phone
versions:

- Moles pop up out of holes and sink again; a whack on one while it is up
  scores, and a mole not whacked in time goes down with nothing.
- **The pace rises as the round runs**: each mole stays up for less (1.15 s
  to 0.5 s) and more are up at once (one to four), a new one every 0.85 s
  at the start and every 0.28 s at the end.
- **The round ends on the clock** (60 s), whatever the score.
- From the phone versions: a **golden mole** worth five (up for less), an
  armoured mole that takes **two whacks** (here a terracotta flowerpot worn
  upside down, cracked by the first), and **one you must not whack** (here
  a rabbit who only came to look: -30 and the streak lost).

Its own additions, kept small:

- **A streak**: every whack in a row counts; x2 at 5, x3 at 12, x4 at 20.
  A mole let go, a whack at an empty hill and a whacked rabbit break it.
- **Quick**: +5 before the whack's base for a mole caught in the first 40%
  of its time up.
- **Frenzy**: the last ten seconds count double, and come a little faster.
- A mole about to get away sticks its tongue out and wiggles.

Points: mole 10, pot mole 25, golden 50, each (+5 if quick) times the
streak's multiplier, times two in the frenzy. The Arcade record keeps the
best score and, as its "furthest", the best streak.

## 3. The screen

The flat boards' top bar (Molehill, motto *Mind the rabbit*), a paper row
with the score (its kicker becomes the streak while there is one), the best
and the seconds left (rose in the frenzy), and under them the lawn in the
Arcade's wooden frame: twelve molehills, **three across and four down**
(the cabinet has five in a row; a phone held upright wants a grid, and a
cell is about 320 px wide at 1080). A bar along the top of the lawn empties
with the minute. Every finger counts, so two thumbs can play.

Drawing: the lawn (mown stripes, a hedge with blossom, tufts and daisies)
and the back half of every mound are one still mesh, rebuilt on resize.
Each hill has two children of the field in row order: a **clipping
Control** whose bottom edge is the hole's mouth, the mole lowered into it
by the draw transform, and the mound's **front lip** over it; a row's moles
so stand in front of the row behind. Mallets, dirt, dizzy stars and the
time bar are one live mesh over all of it.

Motion: a mole stretches out of the hole, breathes and looks about while
up, squashes flat under a whack and reels with stars round its head, a pot
wobbles when knocked, the mallet swings down from one side and lifts away,
dirt flies, numbers rise. Reduce motion drops the breathing, the squash,
the wobble, the reel, the swing and the shake; the rise and sink stay,
because they are the game.

## 4. Build

- `arcade/molehill_sim.gd`: the game as pure data at a fixed 1/60 s, seeded.
  The screen calls `whack(hill)` and drains `events`.
  `tests/_probe_molehill.gd -- [seed] [react ms] [slips]` plays it with a
  bot: at 300 ms reaction it scores ~10,000 and lets nothing go, at 600 ms
  ~3,000 with 11-17 escapes, at 800 ms ~1,400 with ~35.
- `arcade/molehill_art.gd`: the cast and the mound, cached per look and
  scale, shared with the tab's banner.
- `arcade/molehill_screen.gd`, the tab card and banner
  (`ui/menu/arcade_tab.gd`), `ui/menu.gd`'s `_open_arcade`, a vista entry.
- `tests/_shot_molehill.gd -- <outdir> [reduce]` shoots the tab, the ready
  banner, play, the whole cast forced up, a real click through the viewport
  (it prints whether the sim counted it), the frenzy and the end card, and
  puts `user://arcade.cfg` back.
- Draw calls at 810x1440: 134 on the Arcade tab with three cards, 55 on
  a bare lawn, 63 with the cast up, 72-75 on the end card; ANGLE the same.

## 5. Sound

Seventeen cues in `tools/gen_sfx.py`'s `molehill` set, one take each: the
whacks in a new `CARTOON` style (a rubbery bonk, a clay pot's clonk and
crack, the rabbit's squeak, a thud on the grass, a mole's raspberry as it
gets away), the jingles in `ARCADE` (start, go, combo, streak lost, tick,
frenzy, game over, new best) and an alarm bell for time up. `pop_up` and
`escape` fire all the time and sit low. Awaiting the user's listen.

## 6. Analytics

`arcade_start`, `arcade_end` (score, stage = best streak, seconds, whacked,
escaped, missed, bunnies, best) and `arcade_abandon`, as the other two.

## 7. Amendment: the polish (2026-09-27)

Screen and art only; the sim is untouched.

- **The cast**: a tuft of hair on every mole's crown, the hole's shadow on
  the fur at the mouth, eyes that look about (a gaze of -1, 0 or 1 on each
  hill's own clock) and blink, both baked into the mesh key; the rabbit
  holds a carrot, which says "only visiting" before the rule has to.
- **The mounds**: clods thrown up round the back of the rim, crumbs on the
  lip's crest, grass tufts growing round both halves, the hole's back wall
  lit. The lip heaves as a mole shoves out and flattens under a whack,
  about its own foot, and a pop throws a few crumbs.
- **The moles move**: stretched thin shooting out, an overshoot as they
  land, squeezed on the way down, and a pancake squash that springs back
  under a whack. Before the round every mole peeks out and looks about,
  ducking on the go; after it they come up to jeer behind the end card.
- **The mallet**: bigger, grained, with a leather grip; a shadow on the
  ground closes in as it comes down, a smear follows the swing, and a
  white-and-sun impact star bursts on a head (gold on a golden mole, with
  a ring).
- **The numbers** are lettered like stickers (an ink outline and a drop),
  pop, rise and drift, and never rise into the time bar; a combo turns rays
  behind it and bumps the score's kicker; a lost streak shivers it.
- **The lawn**: sunlit patches, clover, the hedge's shade, the edges
  darkening toward the frame, a butterfly along the hedge. The frenzy is a
  warm glow breathing in from the edges instead of a flat wash, and the
  time bar burns down with a little sun at its end, striped in the frenzy.
- **The end card**: the mole pops out of its hole once the card is up (the
  seat clips at the mound's foot), and the stats are three plates.
- Reduce motion: no gaze, blink, overshoot, squash, heave, smear, glow
  beat or butterfly flight; the peeks still come and go, eased linearly.
- `tests/_shot_molehill.gd` now unpauses the game when the harness window
  loses focus, which had been pausing it and eating the click.
- Draw calls at 810x1440: 67 at the ready (the peeking moles), 54-57 in
  play, 63-65 with the cast up, 93 on the end card (the jeering moles and
  the stat plates); the Arcade tab unchanged at 134. Suite 122,593/0.

## Amendment 2026-09-27: the cast redrawn

The user found the creatures "too round and simple": every one was an egg
with an oval belly and two pink mitts. `arcade/molehill_art.gd` alone
changed; origin, height and looks are the same, so the screen, the clip and
the card needed nothing.

- **Silhouettes are traced, not ellipses**: a right half of cubic segments
  mirrored (`_sil`), cel-shaded by a smaller copy shifted left over a deep
  fill (`_inset`), with a rim of light up the left. The mole is a broad
  head on shoulders with a pinch at the neck; the rabbit a round-cheeked
  head on a pear of a body.
- **The mole**: a crown tuft and cheek flicks (`_spike`), a cream bib, bead
  eyes in soft dark patches under light brows, a long creased snout ending
  in a pink bulb with nostrils, dotted whisker pads, a w of a mouth and two
  buck teeth, and shovel hands, a pink palm with five pale claws spread
  over the rim. Worried adds a bead of sweat.
- **The golden mole** wears a tilted crown with three gems, knocked over
  one ear when dizzy, and sheen streaks down its fur.
- **The potted mole**: the pot sits down to the brow with a cream painted
  band, and the mole under it looks out with its lids lowered ("stern").
- **The rabbit**: fluffy cheeks, a tuft on the brow, one tall ear and one
  bent at the knee, big glossy eyes with a lash, two muzzle puffs over her
  teeth, a scalloped bib, and the carrot held by a paw either side.
- Draw calls unchanged (one mesh a look): 67 at the ready, 57-58 in play,
  63-65 with the cast up, 93 on the end card, 134 on the tab; ANGLE agrees.

## Amendment 2026-09-27: rewards made loud

Screen only; the sim is untouched. The shared layer `arcade/rewards.gd`
(see Firefly's spec, section 9) carries the stickers and bits.

- **Every whack** throws clods out of the hole and sparks off the head (gold
  stars too on a quick one). A golden mole showers spinning coins, rings,
  letters Golden! and flies stars to the score; a pot breaks into
  terracotta shards (Smash!), and a knock that leaves it on says Clang!.
- **Flurries**: whacks within 0.32 s of each other (two thumbs) letter
  Double!, Triple!, Quadruple!.
- **The streak** is worded at 5, 10, 15, 20, 30 and 40 (Nice!, Great!,
  Whack-tastic!, Mole-arious!, Unstoppable!, Legendary!) with stars,
  sparks, confetti, a flash and a shake, a rain from Mole-arious!. Each
  multiplier step replaces the old rayed pop with a big `x2!` over a
  sunburst, `Points x2` under it, rings and stars flying into the score.
  From five a warm glow beats round the lawn, reddening as the streak grows.
- **Losing it**: the rabbit letters Not the bunny! with hearts and a carrot
  in pieces and a rose flash; a lost streak says Too slow! (a mole let go)
  or Oops! (an empty whack).
- **The last five seconds** are painted big on the lawn under the moles,
  thumped in and fading, so they never cover a mole. The frenzy flashes
  and rains confetti. The score is lettered at 250, 500, 1,000 and on, and
  passing the best letters A new best! with coins from the best plate.
- **The end card**: the score runs up and bursts in coins, a sunburst turns
  behind the mound, the stat plates pop in, and a new best rains coins,
  confetti and stars over the card.

Reduce motion keeps the words (still) and drops the bits, rays, rain,
flash and glow. Draw calls at 810x1440: 58-66 at rest in play (unchanged),
~150-240 at a busy moment, ~210 in the frenzy, 85-95 on the end card.
