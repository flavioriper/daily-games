# Nightlight

2026-10-06. Designed with the user in one sitting, through a playable tab on
the concept page (`docs/brainstorm/concepts.html#nightlight`) and built the
same day. What the user said is quoted; the rest is what was proposed on the
page and built when the user said "all good, build it".

## 1. What it is

The seventh game on the Arcade tab, and the one that is kept. "A new arcade
incremental game about black hole and galaxies", "a little bit more complex,
let's play with gravity and phisic": "player start with a small star, get
random perks to buy, no movement, he can just throw things into it"; "the
star in the middle having gravity on it as the mass grow, user can throw
meteors on it, and random bodies pass and can be caught by the gravity".

It follows *Black Hole Idle*, which is named here once and nowhere else: not
in code, comments, commits or on screen. **It is called Nightlight.**

Asked whether a game of it ends, the user chose kept and endless, and then:
"the run never ends, but player can rebirth star to buy some new perks that
make journey faster and faster. The rebirth a star (lets keep only star for
now) create a supernova that eject everything to the space, making the next
run fater for having more objects around to eat." So there is no black hole
yet, no game over, no score, and none of the Arcade's end card, record,
boosters or Second chance.

**The physics and the light are the point.** "The main idea here is to play
with the lightning, real phisic, to give something that look realistic but in
a cozy light style." Of the reference: "objects fall into the black hole as a
hole in the screen, instead I wanted something way more realistic, where the
objects start to spin faster and faster by gravity till being eat."

## 2. The physics (`arcade/nightlight_sim.gd`)

- **Gravity is Newton's**: GM / r^2 toward the star, and nothing else pulls.
  Bodies do not pull each other. The star's mass is the M, so ten times the
  mass is ten times the pull.
- **The haze** is the one invented rule. An orbit in empty space never
  decays, and a passing body always leaves again, so the star wears a haze
  five of its radii wide: inside it a body is dragged, by
  `DRAG * (1 - r / haze)^2` of its speed a second, most near the star.
- **Faster and faster is not animated.** A meteor set on a circle at 0.8 of
  the haze starts at 248 px/s, goes round 6.6 times in 13.5 s and meets the
  star at 517 px/s; one dropped at rest from 400 px is eaten in 2.6 s without
  a turn (`tests/_probe_nightlight.gd`).
- **Light is the drag's work.** What the drag takes from a body is counted as
  a share of what a perfect spiral from far off down to the star's surface
  gives up, and paid as light: `LIGHT` (1.5) for each of the body's mass at
  most. The spiral above pays 1.25, the drop 0.06. A body that only brushes
  the haze and leaves pays for the brush.
- **Catching.** A passer comes from 1350 px out with 230 px/s to spare, aimed
  to miss the star by up to 760 px, three in four turning the way the haze
  turns. It is caught only by losing that spare speed in the haze, or by
  meeting another body. A star of 10 left alone for five minutes reaches
  about 45; a heavy one bends far paths into its haze.
- **Meeting.** Two bodies that touch become one and keep their momentum.
- **Growing.** The star's radius is 46 px at 10 mass and the cube root of the
  mass after. Past 80 px on the screen it grows by the logarithm and the view
  draws back (`zoom()`).
- Fixed step 1/120 s, semi-implicit; `advance` runs whole ticks.

## 3. The loop

| Body | Mass | Share of what passes |
|---|---|---|
| Meteor (thrown) | 1 | the pouch: 4 held, one back every 1.5 s |
| Pebble | 0.5 | half |
| Rock | 1.5 | three in ten |
| Comet | 3 | three in twenty |
| Planetoid | 8 | one in twenty |

A body passes about every 3.2 s.

| Tile | Each level | Levels | Light |
|---|---|---|---|
| Meteor | a thrown meteor 1 mass heavier | no end | 10, then x1.5 |
| Pouch | one more held, back 5% sooner | no end | 15, then x1.6 |
| Haze | a haze 8% wider | 10 | 25, then x1.7 |
| Glow | 20% more light | no end | 20, then x1.6 |
| Sky | bodies 8% sooner and 20% heavier | no end | 30, then x1.65 |

**The supernova** is a button from 1,000 mass on, behind a question (it takes
the tiles). It pays `floor(3 * sqrt(mass / 1000))` stardust: three at the
mark, six at four times it. The star's mass, its light and the tiles go. A
star of 10 is left, among 24 ashes or more (14 and 10 for each tenfold of the
old mass over a hundred, 48 at most), each of about 2 mass and half again for
every supernova so far, on closed paths that all turn one way, the nearest
already in the haze. What passes is half again as heavy for every supernova,
for good, and a soft cloud stays in the sky for each.

**The mark does not rise.** The concept tab's first numbers raised it four
times a life, and its bot's lives came out at 4, 7.5 and 14 minutes: longer
each time, the opposite of "faster and faster". With the mark fixed and a
heavier star paying more, the bot reaches 1,000 in 4.0, then 3.1 and 3.5
minutes, and then spends five or six minutes a life going to 2,800, 4,000,
5,400, 7,100 and 9,300 mass, because the next perk costs more.

**Perks** are drawn at random from six for stardust: the first costs 2, each
one after 1 more, and one drawn twice counts twice. Dense core (gravity
+15%), Bright haze (light +25%), Heavy hand (meteors 30% heavier), Deep pouch
(2 more held), Crowded sky (bodies 15% sooner), Ember (a new star starts
twice as heavy).

## 4. The hand

Press on the sky: a meteor waits under the finger. Drag: it will leave the
way the finger went, and a drag of 200 px (of the design's 1080) is the speed
of a circle at the bare haze's edge, whatever the star weighs, up to 520 px.
The dotted line is `Sim.predict`, the real path for three and a half
seconds. Let go to throw. Under 24 px of drag it is a tap and the meteor
falls from where it is. No throw starts on the star. An empty pouch shakes
its count.

## 5. The light (`nightlight_sky.gd`, `nightlight_art.gd`)

- **The star is the only lamp.** A body is one flat colour on a white lump;
  `shaders/nightlight_body_2d.gdshader` lights the side that faces the star,
  leaves the other a deep violet, dims it with distance and warms it in the
  haze. The star's place is one plain uniform: no instance uniform.
- **Shadows** are thrown straight away from the star, one MultiMesh.
- **The star's colour is its mass**: ember at 10, gold at 100, cream at
  1,000, blue-white past 30,000. It breathes and swells a little as it eats.
- **Light has no shape**: the star's glow on the dust, the haze's grains
  (the inner ones lapping the outer), a body's warmth, a comet's tail lying
  away from the star, and the motes that fly to the light plate (ui/motes.gd
  with a gold mesh) are round falloffs on layers that add.
- The supernova is a warm light that takes the sky in 0.8 s and thins in 1.1.

## 6. The screen

The Grove's shell: the top bar, two paper plates (mass, light) and a third
for stardust once there is any (it opens the perks), a bar toward the
supernova, the sky, and under it the Shop button on the left and the pouch's
count and the hint on the right. The pouch's dots and the Supernova button
are in the sky's lower left, clear of the throwing thumb. The shop is the
Grove's card with five tiles.

Kept in `user://nightlight.cfg`: the star, the tiles, the perks, the pouch
and every body in the sky. Nothing happens while the game is closed. Leaving
it is not a moment for an interstitial (`ui/menu.gd`, as for the Valley).

## 7. Not built

A black hole and anything past a star; sounds (no file: every cue is silent,
and only the mapped ones are felt); time away; a tab for the perks outside
the game. The pace has been played by a bot only.
