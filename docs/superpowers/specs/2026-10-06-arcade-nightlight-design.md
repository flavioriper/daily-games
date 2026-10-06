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

## Amendments

### 2026-10-06, the same day, on the first build played on the Mac

**The haze is not drawn.** "Remove this visual indicator of the orbit, keep
only the star at center": the ring at the haze's edge and the grains in
orbit inside it are gone from the sky, the tutorial's pages and the Haze
tile's picture. The haze still drags, catches and makes light exactly as in
section 2; only the star, its light and the bodies show where it is.

**Nothing limits a throw, and a meteor is a fifth of what it was.** "Remove
the asteroid limit on throw, but make it way smaller." The pouch is gone
with everything that hung on it: the four held and the 1.5 s for one to come
back, the Pouch tile (four tiles now, two by two on the card), the Deep pouch
perk (five perks), the dots in the sky's corner and the count under it. A
thrown meteor weighs `METEOR` = 0.2 and each level of the Meteor tile adds
0.2 more; it is drawn 8 px in radius, and no body under 6. Light is let go
in pieces of 0.05 at the least, so a small meteor still sheds four or five
motes on its way in.

What takes the pouch's place as a brake is the hand. The bot throwing every
0.45 s reaches the mark in 5.9, 4.6 and 4.1 minutes; every 0.2 s, in 3.2,
2.2 and 1.7.

**The sky holds 160 bodies at most** (`Sim.MOST`): a throw past it takes the
oldest meteor still up. A circle outside the haze never comes down, and with
no pouch a sky could be parked full of them. Bodies meeting are found on a
grid now: with every pair tried, a sky of 160 cost 2 ms a tick; it costs
0.27.

### 2026-10-06, later the same day: no shadows, and the tide

**Nothing throws a shadow.** "Remove the ground shadow, they are on space it
should have no ground shadow." Every body had a dark wedge lying away from
the star, on the dust its light fell on; the layer, its MultiMesh and its
mesh are gone. A body's far side is still dark, in the shader, and that is
the only dark thing left.

**The star tears what comes too close.** "I want you to do add a more
realistic gravity to the bodies, something orbiting sun too close should rip
apart into smaller pieces." The star's pull is `GM / r^2` at a body's
middle and more on its near side than its far one, by `GM x radius / r^3`.
Against that a big body has its own weight, which also goes by its radius,
so it is torn at one distance whatever its size: `ROCHE` = 3 of the star's
radii. A small one is a stone and held by that too, more the smaller it is,
so it gets nearer:

    torn inside  star_r x ROCHE x (1 + CORE x core)^(1/3) / (1 + (HOLD / radius)^2)^(1/3)

with `HOLD` = 14 px. On a new star (46 px, haze to 230) a planetoid of 8 is
torn at 128 px, a rock at 114, a thrown meteor at 87. A torn body goes in
two to four pieces (`PIECES`), sharing its mass and its unshed light
unevenly, each a little off the body's middle and with **the body's own
velocity and the turn of its tumbling, nothing else**: no push. The nearer
pieces are pulled harder, and that alone draws them out round the star: a
planetoid's are 234 px apart along the path and 66 across it a second and a
half on. A piece is torn again deeper in, down to `CRUMB` = 0.3 of a thrown
meteor; a meteor so comes apart once, in three. Inside the Roche radius
nothing gathers either (`_merge` passes it by), which is why the pieces stay
a stream. Before it is torn a body is drawn up to 1.4 times as long toward
the star and as much thinner (not under reduce motion), and where it tears
its dust is one small puff of light.

Mass and light are the star's as before: the pieces weigh what the body did
and the drag pays by mass. A torn body's pieces fall on slightly different
paths, so a spiral that paid 1.25 light a mass pays 1.15. The bot's lives
are 5.9, 4.4 and 4.2 minutes at a throw every 0.45 s (5.9, 4.6, 4.1 before).

Mine, not asked for: the size rule (the user said "too close"; that small
things get nearer is the stone's strength, and it is what makes a planetoid
crumble in steps), the three pieces of a meteor, no tearing while the sky
holds `FULL` = 300 bodies, the stretch and the puff. **Bodies still do not
pull each other**: only the star does.

### 2026-10-06, later again: the star's own numbers, the hand's shop, powers to pick

The user: "show mass compared to the sun, for example we start as 1x, and
grow bigger, show also temperature, composition and how much fuel it has to
burn. The shop should be related to what player can do, for example bigger
or faster bodies manual send, things like that. And the sun powerup come as
it grow, giving user powerup decisions to pick. For example, after reaching
some Nx sun mass, we could show to player a powerup to use more fuel to
create a solar wind that interfer in surrounding bodies orbit to make them
start fall, or a another powerup that goes into a different direction (user
pick which one)." Asked, they chose: fuel burns to shine and an empty star
dims (nothing lost); a picked power is always on; picks go with the star at
a supernova and stardust still buys the lasting perks; straight to Godot.

**The star.** A new star is one Sun (`suns()` = mass / 10); the supernova's
mark is 100 Suns. It is 70% hydrogen, 28% helium and 2% rock. A body brings
hydrogen by its kind: a thrown meteor 30%, a pebble 20%, a rock 15%, a
comet 90%, a planetoid 60%, an ash 10%; the rest of it is rock. The star
burns hydrogen into helium at `BURN` (0.0015) of its mass a second times its
Suns to the power `HOT` (0.25: a heavier star burns more of itself), and a
mass burnt is `SHINE` (2) light, let go as motes off its own face. Its
temperature is read off its mass: 3,000 K at one Sun, 5,800 at ten, 9,500
at a hundred, 28,000 past three thousand. With no hydrogen it is **dim**: a
dull ember at 55% of its temperature, its powers asleep, nothing burnt and
nothing lost; it lights again once 3% of it is hydrogen.

The screen's plate says the three: Sun masses, temperature, and fuel as the
time it lasts at the present burning (red under ten seconds, "Empty" when
dim), over a bar of what it is made of with each share named.

**The shop is the hand's**, bought with light, gone at a supernova:

| Tile | Each level | Levels | Light |
|---|---|---|---|
| Meteor | a thrown meteor one first-meteor heavier | no end | 10, then x1.5 |
| Volley | one more meteor a throw, side by side | no end | 60, then x2.6 |
| Stream | meteors keep leaving while the finger is down: every 0.6 s, then 15% sooner a level, 0.08 s at the least | no end | 30, then x1.8 |
| Ice | 10% more of a meteor is hydrogen, up to 90% | 6 | 20, then x1.7 |

Haze, Glow and Sky are no longer tiles: they are powers.

**Powers.** At 2, 4, 8, 15, 30 and 60 Suns, and at every doubling after
(120, 240, ...), a card comes up by itself with two powers that go different
ways (catching, light, saving), and the sky waits until one is taken. A
power is always on while the star is lit, stacks if picked again, and burns
more hydrogen, as a share of the star's plain burning:

| Power | Does | Burns |
|---|---|---|
| Solar wind | a drag of 0.012 a level on what is outside the haze, out to three of its radii: a parked circle comes down in under a minute | +40% |
| Wide haze | the haze 15% wider | +25% |
| Beacon | bodies pass 20% sooner and 20% heavier | +30% |
| Radiance | 30% more light from the haze | +30% |
| Tidal furnace | a torn body pays 0.15 light a mass as it breaks | +25% |
| Fusion | the star's own burning pays one `SHINE` more | +20% |
| Slow burn | everything burns 30% less | none |

Slow burn is never the first offer. The two on offer are kept in the file,
so leaving and coming back does not draw again. A star kept from before has
every pick it grew past to make.

**The pace, by the bot** (a throw every 0.45 s or as fast as Stream lets
it, cheapest tile first, either power at random): the first supernova at
3.9 to 4.0 min (5.9 before: Volley and Stream are worth more than the three
tiles they replaced), then lives of 2.1 to 4.2 min. The star ends a life
between 2% and 48% hydrogen and was dim in one life of twelve, for 29 s,
with a build of heavy burners and no Slow burn; a hand that never buys Ice
would be dim far more.

Mine, not asked for: every number above; hydrogen/helium/rock as the three
shares; fuel shown as time; the shares by kind; Volley, Stream and Ice as
the other three tiles; the six powers besides the wind; the card coming up
by itself and pausing the sky; meteors paler the icier they are; a comet's
tail not drawn inside the Roche radius (a torn comet was a burst of rays).

### 2026-10-06, a fifth time: half the speed, and a star nearer its real size

The user, on the build: "we need to reduce bodies movement speed, it's way
too fast. Also, let's try to get somewhere closer to real sizings, I know
sun is too big to be in real size, but let's try to make it bigger, right
now it look way too small compared to the bodies around". Straight to
Godot, no questions asked.

**Everything moves at half the speed.** `G` is 2.8e5 (a quarter of
1.13e6), a passer's `SPARE` 115 px/s and a body's tumbling half what they
were, so every path gravity draws is the shape it was and takes twice as
long. `DRAG` is 0.1 (0.25 before), two fifths and not half, so a spiral
still goes round. A trail is a point every six ticks (1.2 s of path, the
length on the screen it had), and the dotted line of a throw looks seven
seconds ahead.

**The star is 100 px, the bodies two thirds of what they were.** `STAR_R`
100 (46), `BODY_R` 9 (14): a planetoid is 18 px against the star's 100
where it was 28 against 46, a thrown meteor 6 (the least drawn). The view
draws back from 130 px on the screen (`SEEN`, `SEEN_LOG` 36): 176 px at
100 Suns, 203 at 1,000. The haze and the Roche radius stay about where
they were in pixels, so they are fewer of the star's radii: `HAZE` 2.6
(260 px on a new star, 230 before), `ROCHE` 1.8 (180 px, 138 before; a
real star as dense as the Sun tears a loose rock at about 1.9), `HOLD` 9.
`LIGHT` is 2.1 (1.5): the haze is a shorter way down, and a spiral pays
what it did. The ashes' paths are in the new star's radii (`ASH_NEAR` 1.9,
`ASH_REACH` 4.1, `ASH_FAR` 9.8: the same pixels on a first star), or an
Ember star would be born over its nearest ashes. The star's light on the
dust reaches 4.5 of its radii (9).

**Measured** (the probe; before in brackets): a turn at the haze's edge
15.7 s at 104 px/s, at the star's surface 3.8 s at 167 px/s (6.5 s at
221, 0.6 s at 495); a circle at 0.8 of the haze is eaten after 28.6 s and
3.7 turns, 116 to 176 px/s (14.3 s, 6.0 turns, 248 to 530); a drop at
rest from 400 px takes 5.1 s and reaches 216 px/s (2.6 s, 703). A
planetoid's pieces are 222 px along the path 4.5 s after it is torn (234
after 1.5 s).

**The price is the pace.** A body is up twice as long, so the light and
the hydrogen come later and a fast hand fills the sky sooner. The bot at a
throw every 0.45 s reaches the first supernova in 4.2, 4.1 and 5.0 min
(3.9, 4.0, 3.9 before; in the third the star was dim 44 s); at one every
0.2 s in 2.9 min (2.1).

Mine, not asked for: half, and not some other share; the star's 100 px and
the bodies' two thirds; `DRAG` at two fifths; the haze, the Roche radius
and the ashes moved to keep their pixels; the tutorial's pages retimed
(loops of 22, 14 and 12 s where each was 9; its meteor from nearer and
less slow, or it met the star first time round; the circle at 0.6 of the
haze, the comet at 0.5). The Solar wind's 0.012 is unchanged: a circle at
one and a half of the haze comes down in 67 s (52).

### 2026-10-06, a sixth time: a press throws, nothing is aimed

The user: "on nightlight, when user click on screen to throw bodies make
them spawn insta in orbit where user click, so he can keep clicking and
sending without needing to aim".

**A press on the sky is a throw.** The meteor is there at once, under the
finger, already going round the star the way most passers do. There is no
drag, no dotted line, and no tap that lets a meteor fall: section 4, The
hand, is replaced by this. Every finger that comes down throws;
with Stream the first finger held keeps throwing from wherever it is now.
A small puff of light marks where it was set, since the finger hides it.

**Inside 0.8 of the haze the path is a circle.** Farther out a circle
would never come down (nothing spirals without the haze), and the haze is
13% of a new star's field, so the meteor leaves slower than a circle and
its path is a longer round that dips into the haze, deeper the farther off
it began (`Sim.throw_vel`, `LOW`). Every throw from anywhere on the screen
is the star's inside a minute: 29 s from 0.8 of the haze, 36 from its
edge, 51 from twice as far, paying 1.9 to 2.7 light on a meteor of 1.0. A
throw at half the haze is down in 6 s and pays 0.54.

**Measured.** The bot now throws anywhere from 0.5 to 1.5 of the haze and
reaches the first supernova in 4.9 min on three seeds (4.2, 4.1, 5.0
before, aiming into the outer haze).

Mine, not asked for: the dipping path outside the haze and its 0.8, the
puff, two fingers, Stream following the finger, the tutorial's first two
pages redrawn and reworded (three taps; two circles in the haze).

### 2026-10-06, a seventh time: gas, worlds, the chain, and a star that ends by itself

The user: "some more changes to nightlight, I want something that is
closer to the star lifecycle, right now it's too simple. Make sun way
bigger related to the bodies around, instead of player sending bodies he
should send gas, and gas orbiting around gas condense into bodies just like
real life. Check on web about how the sun behave and bodies around it,
that's the whole idea, game is simple and cozy but should work around it.
Movement of bodies should be slower, it should be a slower relaxing game.
Remove the white dash behind the bodies, create it only when body has ice
and is closer to sun, as the star grow it start to pull more objects around
because of gravity. It should be a slower gameplay, going from 1x -> 2x sun
is not so fast like throwing 3 bodies into it. We should also add the sun
fusion phisic on it (check on web as well), light elements fusion into
heavy elements." With a picture of the Sun in extreme ultraviolet: "give it
a more space view sun". Then: "supernova animation should be more nice to
see, not just a flash, but the layers exploding and being ejected into gas
to the space". Then: "instead of user clicking anywhere on screen to place
items, let's add buttons near bottom to user click or hold, right now it
happens that user click on the screen to place item and click on upgrade
that popup".

Asked, they chose: **the star decides** how its life ends; the bodies the
gas makes **stay as a system**; 1x to 2x takes **about five minutes**.

**This replaces sections 3 to 6 and every amendment's meteors, throws and
the 100-Sun mark.** What stands: the haze (now called the disc) and its
light, the tide, Suns, the powers and their picks, the perks, stardust,
the kept file.

**What was looked up, and what the game does with it.**

- A young star is fed by a disc of gas that loses its turn by rubbing on
  itself and gives the fall off as light. The hand sends **gas**: a puff is
  0.002 Suns, 70% hydrogen, 28% helium, 1% dust. It comes in at the disc's
  rim, where a stream that goes round the star once in 200 s is now, and
  winds in over about 80 s.
- A disc is 99% gas and 1% dust; grains stick, pebbles gather into
  planetesimals and planets, and beyond the frost line ice joins in. Two
  puffs that have been up 12 s and come within 30 px drop their dust as a
  **grain**; a grain takes the dust of every puff it crosses; solids that
  touch become one; from 0.0012 Suns a planet keeps the gas too, up to
  0.004 Suns. Past 2.2 of the star's radii there is twice as much ice again
  as dust. Nothing forms inside the Roche radius (1.5 radii).
- Small things are carried by the gas and big ones are not: the disc has
  all its hold on a body 3 px in radius and less by the square on a bigger
  one. A planet of a thousandth of a Sun is dragged a tenth as hard as gas.
- Ice boils off within about 3 AU and the tail points away from the Sun.
  **No body leaves a trail.** One that is 30% ice or more, inside the frost
  line and outside the Roche radius, has a tail lying away from the star.
- The Sun is 99.86% of its system and ten Jupiters wide. The star is 150 px
  in radius, a planet of a thousandth of a Sun 9.5, a grain 3.
- A heavier star draws passers sooner (its Suns to the 0.3) and bends more
  of them in.
- A star fuses hydrogen into helium; helium lights when the core of it is
  about 0.45 Suns (the helium flash, a hundred million kelvin); carbon only
  in stars of eight Suns and more, with a core over 1.06 Suns; then neon,
  oxygen and silicon, each paying less and going quicker (a star of
  twenty-five Suns has seven million years of hydrogen and a day of
  silicon); an iron core past 1.4 Suns cannot hold itself up. The game
  keeps those four numbers as they are. The bar on the star's plate shows
  all of it; a line under it says which core is growing and how hot the
  core is (15 million K to 2.7 billion).
- A Sun is 5,800 K and a heavy star tens of thousands; a red supergiant is
  3,600 K. The star's colour is its temperature, and burning carbon it
  swells by 28% and goes red.

**The end.** With an iron core of 1.4 Suns the star goes supernova without
being asked: the core falls in for a second, then each thing it is made of
leaves as a shell of gas in its own colour, hydrogen first and furthest,
in nine fingers and not a ring; iron stays, a point of light. A new star
of one Sun comes up among gas the old one left, which is 5% dust, so its
planets come sooner. It pays 3 stardust, more for a heavier star (by the
square root of its Suns over eight). A star with nothing at all to burn is
dim, says so, and after 60 s lets its layers go the same way, slowly, for 1
stardust. Fresh hydrogen in that minute lights it again.

**The hand.** One Gas button at the foot, on the right: a press is a puff,
held it is one every 0.6 s. The sky takes no press. The four tiles: Puff
(half a first puff heavier a level), Volley (one more at a time), Flow
(quicker while held), Pure gas (4% more hydrogen, six levels).

**Pace, measured** (`tests/_probe_nightlight.gd -- pace`, the button held
all the time, the cheapest tile bought as soon as it can be): 2 Suns at
5.0 min, 4 at 10.5, 8 at 17.5, the helium flash at 15.9, carbon at 24.1, a
supernova at 26.7 min and 21 Suns for 4 stardust. Held two thirds of the
time: 2 Suns at 7.0, the supernova at 33 min. Later lives begin at 2 Suns
in 3 to 4 min.

Mine, not asked for: every number above but the four from the real star;
gas coming in as a wandering stream at the rim (asked for was a button);
the button on the right; a puff's dust staying the same when the Puff tile
makes it heavier; the minute of grace and the 1 stardust; the giant's
swelling; the line said over the sky as a stage lights; an old kept star
coming back with its mass and without its sky; the tutorial's four pages.

Not done: no sound, nothing on a phone, no person has played the pace, the
concept tab is the first game still, a planet does not pull the gas or
another planet, fuel never runs short for a hand that pours (it only
matters to a star left alone), and no power was retuned for gas.

