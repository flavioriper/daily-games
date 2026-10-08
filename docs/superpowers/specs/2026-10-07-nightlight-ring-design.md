# Nightlight: a ring to tend

2026-10-07. The ninth pass on Nightlight (`2026-10-06-arcade-nightlight-design.md`
and `2026-10-07-nightlight-universe-design.md` have the game as it stands).
This spec replaces the hand: the Gas button and its pour go, and the player
presses the sky to brake what circles the star. It adds a ring the star is
born with, worlds that pull, and a reward that depends on what falls in. The
disc's drag, the tide, the chain, the three ends, the relics, the camera's
move to a new star, the powers and the perks stand. Designed in chat; the
user's words are quoted, their answers recorded, and everything else is
proposed here and marked as mine in section 19.

## 1. What the user asked for

"Let's redesign the nightlight game, instead of user throwing bodies, let's
make it interact with the game in a different way. Here is the picture, the
user start with a small star and tons of gas spinning around outside orbit.
User can click into regions to slow it down and make it fall, as the star
grows, more mass start to be captured by the gravity and making it faster."

"Just to add more context, as the star go to supernova and we have more
iron, planets start to form later. We should reward more as the object have
more mass, so sending raw gas should give way less than sending real bodies
to it like meteros, planets, etc."

"I want the user to feel like handling a real solar system."

Asked, they chose:

1. **Supply: a ring plus a slow trickle.** Each star is born with one big
   ring; new gas drifts in from the far sky. (Over "one finite ring a life"
   and "a ring that refills fully".)
2. **The press: a tap brakes, a hold keeps braking.** (Over "tap only" and
   "hold only, with a ramp".)
3. **Self-feeding: mostly itself, the hand speeds it up.** Early on nothing
   falls without the hand; by a few Suns the star takes in a steady stream
   alone. (Over "a trickle, the hand always matters" and "runaway".)
4. **The pick card still pops up, guarded.** (Over "no pop-up, a badge".)
5. **In this pass: worlds pull too, and a readout of the system.** Not in
   this pass: a drag that lifts an orbit.

This reverses the user's ruling of 2026-10-06 ("instead of user clicking
anywhere on screen to place items, let's add buttons near bottom"), which
was made because a card came up under a finger. Answer 4 is the guard.

## 2. What was looked up

- A protoplanetary disc is a few percent of its star's mass, and solids are
  a small share of the disc. Past the snow line (1.6 to 5 AU by model; about
  2.7 AU by the asteroid belt) water is ice, which raises the solids there
  about fourfold; that is why giant planets' cores form outside it and the
  inner planets stay rock ([snow line](https://arxiv.org/abs/astro-ph/0602217),
  [disc mass fraction](https://arxiv.org/pdf/2509.14101),
  [why distance decides](https://briankoberlein.com/blog/how-a-planets-distance/)).
- A planet holds what is inside its Hill sphere, `r_H = a * (m / 3M)^(1/3)`:
  53 million km for Jupiter, a tenth of its distance from the Sun
  ([Hill sphere](https://www.physicsforums.com/threads/hill-sphere-formula-understanding-mass-twin-planets-eccentricity.198441/)).
- A star takes gas from its cloud faster the heavier it is: Bondi's rate
  goes as the mass squared
  ([formation of massive stars](https://arxiv.org/pdf/astro-ph/0602012),
  [notes on star formation](https://arxiv.org/pdf/1511.03457)). The game
  keeps the direction and not the exponent (section 7): the square grows
  without bound in a finite time.

## 3. What stands, what goes

Amended: see section 22.

**Stands**: the sim's frame and tick, gravity and the disc's drag, light as
the drag's work, the tide, `_meet` (condensing, sweeping, gulping, merging),
the chain, Suns, `on()`, the powers and their picks, the perks, stardust,
the three ends and their remnants, relics, the far sky, the camera's pull
back and pan, the birth, Start over, the sounds, the passers.

**Stands, with one number moved**: where a new star is born (section 4:
the lobe rule reads the ring, not the disc) and the Wind power (section 7:
`WIND` is a twentieth of what it was).

**Goes**: `Sim.pour`, `pour_r`, `_inlet` and the `IN_*` constants,
`puff_mass`, `volley`, `stream_gap`, the tiles `puff`, `volley` and
`stream`; the screen's `_gas_b`, `_gas_button`, `_on_gas_input`, `_pour`,
`_press`, `_let_go`, `GAS_W`; `_lay_gas` as the way a star's gas is laid
(section 4 keeps a few puffs of it); the strings `NL_GAS`, `NL_PUFF`,
`NL_VOLLEY`, `NL_FX_PUFF`, `NL_FX_VOLLEY`. The ruling that the pour rides
a giant's rim goes with the pour; `tick`'s `bind` on `star_r()` stays.

## 4. The ring (`arcade/nightlight_sim.gd`)

Amended: see section 22.

A star is born with a ring of gas on near-circles outside its disc, all
turning the way the disc turns.

- `ring: Vector2` is its inner and outer radius in the sim's pixels, set
  when the star is born and **fixed for that star's life**: `RING_IN` 1.15
  and `RING_OUT` 1.75 times the newborn's plain disc (`main_r() *
  haze_wide()` with no power: 450 px at one Sun, so 518 to 788 px). The
  Ember perk makes a heavier newborn and so a wider ring.
- `_lay_ring(count, mass, h, dust_share)` lays `count` puffs evenly by
  area between the two radii, each at the circle's speed times
  `randf_range(0.98, 1.02)`, `age = COOL`, `mass / count` each give or take
  40%. `RING` 180 puffs, `RING_M` 15 (1.5 Suns) for a first star, times `1 +
  RICHER * novas` after an end, as the ashes were.
- **A puff's dust is absolute**, the rule the pour had: it carries the dust
  a puff of `PUFF * ASH_M` at `dust_share` would, whatever it weighs
  (`b.dust = dust_share * PUFF * ASH_M / b.m`). Otherwise a ring of heavy
  puffs at a supernova's 30% makes a giant of every pair.
- `born()` lays a first ring at 2% dust; `end()` lays the next from the
  dead star's layers (`ash_dust`, unchanged). `dusty` keeps that share for
  the star's life; the trickle (section 7) uses it.
- **A few puffs are already falling**: `RING_FALLING` 6 of the count are
  laid by the old rule (`_lay_gas`, dipping into the disc), so a new star
  opens with something winding in and the player sees what a fall is.
- Left alone at one Sun the rest never comes down: a circle outside the
  disc is closed. The probe checks it (section 17).
- `MOST` 150 becomes 260 puffs and `FULL` 300 becomes 400 bodies.
- **A new star is born far enough for its ring, not only its disc.**
  `end()`'s distance becomes `D = LOBE * ring.y * (1 + sqrt(rm / mass))`
  with the newborn's `ring.y` (it read `haze_r()`). Left on the disc, a
  dwarf of 0.6 Suns sat 1,280 px off and 490 px from the ring's near edge,
  where it pulled half again as hard as the star and stripped the ring.
  On the ring it is 2,240 px off, the star's own lobe against it is 1,840
  px, and the ring's 788 is inside half of that, where a round holds. A
  black hole of 3 Suns: 3,440 px off, half a lobe 830 px. The camera's
  `fit` already follows `D`; `VIEW_LEAST` 0.3 holds a dwarf's birth (0.34)
  and not a hole's (0.22, as today's 0.225 did not), so the harness's
  `where` step says whether it comes down. A relic leaves `RELIC_REACH`
  after two or three lives where it took three or four. A kept star's
  gifted ring (section 14) may lose its near edge to a relic that was
  placed by the old rule.

## 5. The press

Amended: see section 22.

**The sim.** `brake(at: Vector2, r: float) -> int`: every body within `r`
of `at` (gas and solids alike, in the sim's pixels) has its velocity
multiplied by `1 - BRAKE * (1 - d / r)`, `BRAKE` 0.2, and its `sink` set to
1. It returns how many it braked and appends `{"kind": "brake", "at", "n"}`.
Nothing else: no drag is added and nothing is moved. What follows is the
orbit's own.

- Braked by a factor `f` on a circle at `R`, a body's nearest point becomes
  `R * f^2 / (2 - f^2)`, half a turn later and on the far side. At the
  ring's middle (655 px) the centre of a press (`f` 0.8) dips to 308 px,
  0.68 of the disc: it enters the disc at 32 s, is nearest at 48 and is
  eaten at 113 (a pour at the rim took 76); the edge of the press (`f` 0.95) dips to 539
  px and misses the disc, so a light touch only ruffles the ring.
- Pressed again, the same gas comes down sooner and pays less (integrated
  with the built drag from the ring's middle): once, eaten at 113 s for
  0.61 of a perfect spiral's light; twice (`f` 0.64), 68 s and 0.38; three
  times (`f` 0.51), straight in at 31 s for 0.08. A gentle brake pays the
  most light for gas; a long hold feeds the star fastest. That is the
  drag's own rule, not a new one.
- `press_r()` is `PRESS_R` 95 of the design's pixels, times `1 + REACH_STEP
  * lv.reach`, divided by `zoom()`: the circle is the same under the finger
  whatever the star weighs.
- `sink` falls to 0 over `FLUSH` 6 s and is not saved.

**The screen** (`arcade/nightlight_screen.gd`). The sky's field takes
`InputEventScreenTouch` and `InputEventScreenDrag` (and the left mouse
button and its motion, as the Gas button did) and nothing else on the
screen reads them.

- A finger that comes down brakes at once where it is, through
  `sky`'s inverse of `world()`. While it stays down it brakes again every
  `flow_gap()` (`FLOW` 0.6 s times `FLOW_STEP` 0.88 a level, never under
  `FLOW_LEAST` 0.15) wherever it is now. Every finger counts.
- A press that braked something cues `pour` (the dry click, a little off
  pitch each time, once in `FELT` at most) and `Haptics.TAP`. A press on
  empty sky is silent and unfelt.
- No press is read while `_held_back`, the settings sheet, the pick card,
  the shop, the perks, the powers or the reset card is up, or while
  `sky.ending()` or `sim.ending() != ""`. A card opening drops every held
  finger.

**The sky** (`arcade/nightlight_sky.gd`). `set_down(at, r)` lays a soft
round glow of the press's own radius in the warm batch (`Art.glow`, no
edge, no ring, no ray), fading over 0.5 s; under `Motion.reduce` it does
not grow. A body with `sink > 0` is drawn warmer and a little brighter by
that much. Each puff is drawn as three soft lights (two more at seeded
offsets inside `gas_r()`), so the ring reads three times as dense as the
sim holds; `GAS_MOST` 1,400 becomes 2,000.

## 6. The camera

`zoom()` becomes the smaller of today's log rule and `FRAME / ring.y`,
`FRAME` 500 of the design's pixels: the whole ring is inside the 1080-wide
field. `seen_r()` becomes `star_r() * zoom()`.

- At one Sun the zoom is 0.635 and the star 95 px in radius (150 today).
  It holds there while the star grows on screen: 120 px at 2 Suns, 163 at
  5, 205 at 10, where today's log rule (0.63) takes over as it does now. A
  giant reaches the log rule sooner.
- The end's `view0`, `fit`, the midpoint framing and the tutorial's own
  scale are unchanged. `gone` (`FAR / zoom()`) is 3,780 px at the start.

## 7. Self-feeding

Amended: see section 22.

- **The disc grows and the ring does not.** With no power the disc covers
  15% of the ring's area at 2 Suns, 44% at 3, 92% at 5 and all of it from
  5.4. What it covers is dragged and spirals in unaided. The Haze power
  brings each of those sooner and gets no new rule.
- **The Wind power is cut to a twentieth**: `WIND` 0.006 becomes 0.0003.
  It drags everything from the disc out to three discs, which was empty
  sky and is now the whole ring: at 0.006 a circle there halves in under a
  minute, so one pick would have emptied the ring into the star at any
  mass, the runaway the user did not choose. At 0.0003 a level halves a
  ring circle in 19 minutes: the ring leans in over a life and the hand
  still matters. Its words stand ("slow down and start to fall").
- **The trickle.** `_trickle()` adds gas at `TRICKLE * pow(suns(),
  TRICKLE_UP) * (1 + RICH_STEP * lv.rich) * (1 + HAND * perk.hand)` of mass
  a second, `TRICKLE` 0.017 (a tenth of a Sun a minute at one Sun),
  `TRICKLE_UP` 1.0. When a puff's worth (`RING_M / RING`) has gathered it
  is set on a circle at a random angle between 0.9 and 1.0 of `ring.y`,
  with `puff_h()` hydrogen (the Pure tile) and `dusty` dust. At `MOST` it is
  added to a puff already in the outer ring, as the pour did. A new puff
  fades in over 2 s.
- Once the disc is past `ring.y` the trickle lands inside it and feeds the
  star with no hand at all. A giant's envelope takes what is left, as built.
- A star nobody touches eats only the six falling puffs, runs out of
  hydrogen, dims and fades by the rule that exists; the next star gets a
  ring.

## 7a. Amended while building: what really brings the ring down

Found by the probe on 2026-10-07, before any screen work. Section 7's first
bullet is wrong and this replaces it; sections 4 and 9's numbers named here
move with it.

- **The ring does not stay put.** As the star eats, its pull grows and every
  orbit round it shrinks (a circle's radius times the star's mass stays the
  same). The disc also widens, as the cube root of the mass. So the ring's
  inner edge meets the disc once the star has gained 11%, half the ring is
  inside at 30% and all of it by about half a Sun gained, whatever the hand
  does after that. This is the user's "as the star grows, more mass start to
  be captured by the gravity and making it faster", and it is the sim's own
  gravity, not a rule.
- **So a heavy ring is the runaway the user did not choose.** At 1.5 Suns
  (2.25 after a supernova) the first tenth of a Sun eaten brought the rest
  down by itself. `RING_M` is 3 (0.3 Suns, a real disc's share of its star
  is a few percent to a few tenths): what the hand sends then brings about
  half as much again, and stops. The trickle carries the rest of the life.
  Gas that drifts in at the ring's outer edge needs the star to grow by a
  half at one Sun, a quarter at 2 and a twelfth at 4 before it comes down
  unaided; from 5.4 Suns it lands in the disc. That is "early on nothing
  falls without you, by a few Suns it feeds itself", by the orbit's own rule.
- **Dust is a plain share of a puff** (section 4's "absolute" rule made an
  iron-rich ring half solid, 150 planets' worth, and a first ring made
  planets inside a minute): `FIRST_DUST` 0.005 for a first star, `ASH_DUST`
  0.01 plus `METAL` 0.25 of the dead star's heavy layers, never over
  `ASH_MOST` 0.06, and `IRONY` 0.016 for the iron-dark paint.
- **Relics and worlds act by their tide.** The sim keeps the star still, so
  a relic's whole pull landed on the ring while the star felt none of it,
  and no ring survived beside one. Each relic's pull at the star's own
  place is now taken off every body, which is what a star-centred frame
  owes. `LOBE` is 2.0, not 1.6: a ring at 0.35 of the way to a comparable
  mass does not hold, at 0.28 it does. A dwarf's birth is about 2,800 px
  off; the camera's `fit` for it is 0.27, under `VIEW_LEAST` 0.3.
- **A world pulls solids; only a growing core pulls gas**, and only inside
  its own Hill radius. Gas scattered like points by every planet emptied a
  ring in five minutes; real gas is accreted or flows round. Rocks and
  comets are still stirred and flung.

## 8. Worlds pull

Amended: see section 22.

A solid of `PLANET_M` or more (the kinds PLANET and GIANT) pulls what is
near it. The `WORLDS` 8 heaviest do.

- In `tick`, each of them is added to the table the relics use (position,
  `G * m`, and a reach): a body within `PULL_REACH` 6 Hill radii of a world
  (`hill_r = r * pow(m / (3 * mass), 1/3)`, `r` the world's distance from
  the star) gets `G * m / (d^2 + s^2)` toward it, `s` the world's own
  `body_r`. A world does not pull itself, worlds pull each other, the star
  is not pulled, a world eats nothing by this rule (`_meet` still does the
  touching) and tears nothing.
- **Gas inside half a Hill radius of a world that can gulp it is held**
  (`CORE_M` or more and under `GIANT_MOST`, `_meet`'s own test): its
  velocity eases toward the world's at `MOON_DRAG` 0.05 a second. Without
  something that takes energy away nothing is ever captured; real gas
  loses it in shocks. So a growing giant gathers a small swirl and gulps
  it as now. A planet under `CORE_M` and a giant that is full hold
  nothing, or the puffs would pile on them for ever.
- Scale, from the built masses: a planet of 0.01 at 655 px round a one-Sun
  star has a Hill radius of 45 px and a round at its edge takes 86 s; a
  giant of 0.04, 72 px. Against a 10-Sun star they are 2.2 times smaller.
- **What to expect, not promised**: gas clumping near worlds, a giant
  wearing a small disc and growing, thin lanes in the ring where a world
  has swept, now and then a rock or comet turned inward. The effects are
  slow (several rounds of 150 s). Moons of solids will be rare: nothing
  takes a solid's energy away.

## 9. What a thing pays

Amended: see section 22.

Light is the reward; mass stays mass (a planet feeds the star what it
weighs).

- `Body.rank` is the mass of the biggest solid a body is or has been part
  of: 0 for gas, raised to `m` whenever a solid's mass grows, and **given
  whole to every piece when the tide tears it**. `pay(rank)` is `PAY_GAS` 1
  for gas, `PAY_GRAIN` 4 under `GRAIN_M`, `PAY_ROCK` 10 under `PLANET_M`,
  `PAY_WORLD` 25 from there.
- The drag's light is multiplied by `pay(rank)`; `Body.paid` counts what a
  body has let go so far (shared out by mass in a tear and a merge).
- **A solid pays in full when the star eats it**: `m * spiral_light() *
  pay(rank)` less `paid + e`, never under 0, as one `shed` event where it
  went in. A solid's path does not matter. Gas is paid only by the drag, so
  gas dropped straight in still pays almost nothing.
- A body a relic takes pays nothing, as now.
- Why the steps are 4, 10 and 25 and not the 2, 3 and 5 said in chat:
  solids are a few percent of a ring's mass, and a planet of 0.01 at five
  times gas is a fifth of one light. At 25 it is one light, about eight
  seconds of feeding gas at today's pace.
- The Furnace power (light when a body is torn) is not changed.

## 10. The frost line and the worlds' cap

Amended: see section 22.

- `frost` is set at birth to the ring's middle (`(ring.x + ring.y) / 2`,
  653 px at one Sun) and `frost_r()` is `frost * (1 + GIANT * swell)`: the
  inner ring makes rock, the outer ring makes comets and giants, for the
  whole life, and a giant thaws it. Today it is 2.2 star radii and follows
  the star, which would leave the ring all ice at first and all rock from
  1.8 Suns.
- `SOLIDS` 24 becomes 40: what the gas may make by itself.

## 11. The shop, the perk, the words of the powers

Amended: see section 22.

The hand's tiles (`Sim.TILES`, `TILE`, `lv`), bought with light:

| Tile | What a level does | Starts | Steps | Levels |
|---|---|---|---|---|
| `reach` | the press is `REACH_STEP` 25% wider | 40 | 2.2 | 6 |
| `flow` | held, it brakes `FLOW_STEP` sooner | 30 | 2.0 | no end |
| `rich` | `RICH_STEP` 50% more gas drifts in | 12 | 1.8 | no end |
| `pure` | the gas that drifts in is 4% more hydrogen | 20 | 1.9 | 6 |

The Hand perk is 30% more gas drifting in. The powers keep their rules;
`NL_POW_BEACON_FX`, `NL_POW_WIND_FX` and `NL_POW_HAZE_FX` are read again
against the ring and reworded only if they now say something false.

## 12. The readout

Amended: see section 22.

`Sim.system()` returns the counts of PLANET, GIANT, COMET and ROCK.

- **The screen**: one quiet line on the left of the field's top, under the
  header: "3 planets · 1 giant · 22 rocks · 4 comets", a kind with none
  left out and no line with none at all. `NL_SYS_PLANETS_ONE/_N`,
  `NL_SYS_GIANTS_ONE/_N`, `NL_SYS_ROCKS_ONE/_N`, `NL_SYS_COMETS_ONE/_N`.
  It is hidden while the sky plays an end.
- **The Arcade card**: `Sim.kept()` gains `worlds` (planets and giants) and
  the card's line gains " · 3 worlds" before the relics
  (`NL_CARD_WORLDS_ONE/_N`).

## 13. The card guard

Amended: see section 22.

- `_offer` waits until no finger is down and `OFFER_CALM` 0.6 s have passed
  since the last one lifted.
- The pick card reads no press for `PICK_DEAF` 0.5 s after it shows.
- Section 5's list keeps the sky deaf under every card.

## 14. The file

Amended: see section 22.

`KEPT` 4 adds `ring` (two numbers), `frost`, `dusty`, the tiles' new keys,
and a body's `rank` and `paid` as its eleventh and twelfth columns.

A `KEPT` 3 file loads with its star, light, stardust, perks, powers, relics
and bodies as they are, and:

- `lv.reach = min(volley, 6)`, `lv.flow = stream`, `lv.rich = puff`,
  `lv.pure = pure`;
- `ring` and `frost` as a newborn of `START * pow(EMBER, perk.ember)` would
  have them, and a ring laid there at `ASH_DUST`. On a star already heavier
  than 5.4 Suns the ring is inside the disc and simply falls: a gift, and
  the trickle then feeds it as it would any star of that mass;
- every solid's `rank` is its mass, `paid` 0.

Older files load as they do now.

## 15. The tutorial and the words

Amended: see section 22.

- **GAS page** (`ui/hud/nightlight_tutorial_diagram.gd`): the page's own
  ring is laid at the disc's rim so the lesson fits its loop; a drawn
  finger presses it twice and the gas winds in. `TUT_NL_GAS` "Slow the gas",
  `TUT_NL_GAS_BODY`: "Gas circles the star and never falls by itself. Press
  it to slow it: it drops into the disc, winds in and feeds the star. Hold
  to keep slowing it."
- **WORLDS page**: its body gains "A world pays far more light than the gas
  it was made from. Gas left in the ring makes them."
- `NL_HINT`: "Press the gas to slow it". `NL_REACH`, `NL_RICH`,
  `NL_FX_REACH`, `NL_FX_RICH`; `NL_STREAM` and `NL_FX_STREAM` stay for
  `flow` with the second reworded ("slows every %s s, then %s s");
  `NL_PERK_HAND_FX`: "30% more gas drifts in". All in en, pt and es; titles
  stay English.

## 16. Sound, haptics, analytics

Amended: see section 22.

No new file. `pour` is the press (section 5). `docs/agents/haptics.md` and
`docs/agents/analytics.md` are read before the screen is touched; an event
that counted pours counts presses that braked something. Nothing new is
tracked.

## 17. Checks and measurements

Amended: see section 22.

**The probe** (`tests/_probe_nightlight.gd`; it keeps its checks, as every
pass has). New: a ring is laid between `ring.x` and `ring.y`, all turning
one way, and but for the six nothing of it is inside the disc after 300 s
untouched at one Sun; a braked body's nearest point is `R * f^2 / (2 -
f^2)` within 2%; a puff braked once at the ring's middle is eaten and pays
light; a second brake pays less; `press_r()` times `zoom()` is the same at
1 and at 20 Suns; a solid eaten pays `m * spiral_light() * pay(rank)`
whatever its path; a torn planet's pieces keep its rank; gas dropped
straight in pays under a tenth of a spiral's; a grain set half a Hill
radius from a planet is turned by it and one past the reach is not; gas
inside half a Hill radius of a core stays with it for ten rounds and none
stays with a planet under `CORE_M`; an untouched ring beside a dwarf and
beside a 3-Sun hole, each at its `D`, keeps nine puffs in ten for ten
minutes; with Wind picked once a ring circle is no less than 0.8 of its
radius after five minutes; the trickle
at 4 Suns is `pow(4, TRICKLE_UP)` times the trickle at one; an untouched
5-Sun star eats more of its ring in ten minutes than an untouched one-Sun
star does (how much is printed, not checked); `zoom()` shows `ring.y` at 500 px; a
`KEPT` 3 file loads as section 14 says. The checks on `pour` go.

**The bot** (`-- pace [min] [seed] [takes] [held] [gas|worlds]`):
`bot_press` brakes every gap at the ring's densest cell outside the disc,
or with `worlds` at the heaviest solid outside it. It prints Suns and light
a minute, when each ring share was eaten, the system's counts, and the
first end.

**The harness** (`tests/_shot_nightlight.gd`) presses the sky with a
ScreenTouch and a ScreenDrag where it pressed the button, sets the sky's
own filter to IGNORE while it does (a real pointer over the window
would brake too), and gains beats for the ring
at birth, a press with its glow, a braked arc mid-fall, the ring half
eaten, an iron-rich ring with worlds and their swirls, and the readout. On
both drivers, under reduce motion, in en, pt and es.

**Budgets.** Draw calls: the three lights a puff are in the gas batch, the
press's glow in the warm batch, the readout is one label; every beat within
5 of today's (94 new, 138 to 146 heavy, 211 with the shop), against 855. A
tick with 400 bodies, 8 worlds and 12 relics in reach: under 1.2 ms on this
Mac's debug build (608 us today with 300 and 12); if it is over, `WORLDS`
comes down before `MOST` does.

## 18. The pace to tune toward

Amended: see section 22.

Every number in sections 4 to 11 is a starting value. The bot tunes
`RING_M`, `TRICKLE`, `TRICKLE_UP`, `BRAKE`, the `PAY_*` steps, `LIGHT` and
the tiles' prices until:

- an attentive hand takes a first star from 1 to 2 Suns in about five
  minutes (the user's answer of 2026-10-06);
- its first end comes at 25 to 30 minutes, as now;
- a first star's light a minute is within 15% of today's bot's, so the
  shop moves as it does;
- the third star, in an iron-rich ring, earns about twice a first star's
  light a minute for a hand that sends worlds;
- a hand that only ever sends raw gas earns under half of what one that
  waits for worlds does, on that third star.

## 19. Mine, not asked for

Every number. Also: approach A (the world as built and the camera farther
out, over a narrower disc or a painted ring); the ring's radii fixed for a
life; the six falling puffs; the brake acting on solids; a light touch that
misses; three lights a puff; Bondi's direction without its exponent; the
frost line fixed at the ring's middle; the lobe rule on the ring; `WIND`
cut to a twentieth; worlds as the eight heaviest, their reach, and the hold
on gas inside half a Hill radius of a core; `rank` passed whole
to torn pieces; a solid paid in full whatever its path; the steps 4, 10
and 25; the tiles' names, prices and what the old levels become; the gift
of a ring to a kept star; the readout's wording and place; the card's
"worlds"; `OFFER_CALM` and `PICK_DEAF`; the tutorial's words.

## 20. Not in this pass

A drag that lifts an orbit (asked, not chosen). The concept tab, which
still shows the first game. New sounds. A phone. Worlds tearing or eating
by their pull, moons of solids, rings round a world. The star being pulled
by anything. The relics' nebulae as real gas. Retuning the powers against
each other.

## 21. The risk to judge by playing

A press does not look like much for the first seconds: the glow, the
click, the flush, and then gas that sinks 5 px in 5 s, enters the disc at
32 s and is eaten at 113. That is the speed the user asked for on 2026-10-06 ("way too
fast"), and a pour took longer to pay, but a pour was not aimed. If the
press feels dead, the first lever is the ring nearer the disc (`RING_IN`,
`RING_OUT`), then `BRAKE`; `G` is not touched.

## 22. As built

2026-10-08. Sections 1 to 21 are the design as it was written on 2026-10-07,
with 7a added while the sim was being built. This section lists every place
the game as built departs from them, each with its reason and the number it
ended on; where it and an earlier section differ, this one is the game. A
section it overrides says so under its heading. Built by six tasks on
`feat/nightlight-ring` (base `1415a7ff`) and one fix wave after the whole
branch was reviewed (`f3f3c7e0`; "the final wave" wherever it changed
something, and a paragraph of its own near the end). The notes for whoever
touches the game next are `docs/agents/arcade.md`, "A ninth time", which
names the command, the log or the task's report behind most of the figures
here; the few that come only from a report or a review (the gas layer's
cost, one reading of a tick) say so. Section 7a is left as it was written;
where its numbers moved again, the paragraphs below say so.

**What stands, what goes (section 3).** Three things section 3 said would
stand were changed: gravity gained a term (a relic's pull at the star's own
place is taken off every body, 7a), the Furnace power pays by another rule
(below), and a comet's tail is no longer drawn by the frost line (below).
`_lay_gas` lays only the six falling puffs of a ring. `Sim.DUSTY` is left
in the sim and only the probe reads it.

**The ring (sections 4 and 7a).**

- `RING_M` is 3.0, 0.3 Suns in `RING` 180 puffs (7a's reason: orbits shrink
  as the star grows, so a heavy ring all comes down by itself).
- `RING_MOST` 0.3 is new: no ring weighs more than 0.3 of its newborn, and
  a later ring is no heavier than a first one. Section 4 laid `RING_M * (1 +
  RICHER * novas)`; at two supernovas that was 0.6 Suns round a one-Sun
  star and 95 to 97% of it came down by itself. The probe now reads 33% of
  a first ring brought down by a star that grows 15%, and 33%, 21% and 34%
  after one, two and four supernovas. `RICHER` is in what drifts in
  (`trickle_rate()`), not in the ring's weight. An Ember newborn of two
  Suns gets the same 0.3 Suns, 0.15 of itself.
- `ring_m` is new state: what the ring weighed at birth, which the far sky
  makes it up to. It is in the file.
- Dust is a plain share (7a), and the pace task moved 7a's numbers once
  more: `FIRST_DUST` 0.004 (7a: 0.005), `ASH_DUST` 0.01, `METAL` 0.07
  (0.25), `ASH_MOST` 0.03 (0.06), `IRONY` 0.008 (0.016). At `METAL` 0.25 a
  supernova's gas was 0.032 dust and a third star had up to fifteen worlds
  at once in its first ten minutes. The rings the bot's five first
  supernovas left are 0.017 to 0.018 dust, fully iron-dark (that is from
  twice `IRONY`); the cap is reached only by a star with more than 0.29 of
  itself in silicon, iron and rock, which the probe builds by hand.
- `LOBE` is 2.0 (7a). By `end()`'s rule a dwarf's birth is 2,800 to 2,940
  px off (a dwarf of 0.6 to 0.75 Suns) and a neutron star's 3,440; the
  camera's `fit` for both is under `VIEW_LEAST` 0.3 and is held there (see
  the camera, below).
- "Left alone at one Sun the rest never comes down" holds for an untouched
  star's first hundred minutes and not for its life (see "An untouched
  star", below).
- A `KEPT` 2 file is given a ring too (section 14 said older files load as
  they do now): such a star would have opened with nothing to press.

**The press (section 5).** The sim's `brake`, `press_r()` and `flow_gap()`
are as written, with the numbers as written (`BRAKE` 0.2, `PRESS_R` 95,
`REACH_STEP` 0.25, `FLOW` 0.6, `FLOW_STEP` 0.88, `FLOW_LEAST` 0.15, `FLUSH`
6).

- **What a braked puff pays was underestimated.** From the ring's middle,
  under the finger's middle: once, in the disc at 32 s and eaten at 112 s
  for 0.92 of a perfect spiral's light (section 5 said 113 s and 0.61);
  twice, 68 s and 0.57 (0.38); three times, 31 s and 0.12 (0.08). The order
  stands: a gentle brake pays most, a long hold feeds fastest. Three
  quarters of the way to a press's edge (`f` 0.95) the nearest point is
  537 px and the gas stays up.
- **The screen** is as written, and besides: the sky knows every finger on
  it whether or not its press was read (`_touching`), so a thumb resting
  through an end still holds a card back; a touch and a mouse press within
  `TWICE_MS` 60 ms are one press; the press's light is laid whether or not
  anything was caught, and only the click and the tap wait for a catch.
- **The sky.** The press's light is `DOWN_A` 0.6 at its brightest and
  `DOWN_WIDE` 1.15 of the press's reach (the plan's 0.35 and 1.0 were hard
  to find on a still). Braked gas is drawn toward the
  disc's warm colour by `sqrt(sink)` and 0.3 brighter (`FLUSH_A`). A puff's
  two extra lights are `HAZE_WIDE` 4.0 times as wide as its own, `HAZE_A`
  0.65 of its light and up to `HAZE_FAR` 2.2 of `gas_r()` off (section 5
  put them inside `gas_r()`, where they bridged nothing between puffs 50
  px apart), and `GAS_A` is 0.26.
- **The gas is on a layer of its own that covers as well as adds**
  (`Gas`, between `Light` and `Warm`, premultiplied alpha, `GAS_BODY` 0.75
  of what is under each light covered). The spec left the gas where it
  was, on a layer that only adds; with lights wide enough to make a cloud,
  pure add burnt to a white ball wherever a finger held. It is still one
  MultiMesh and one draw. A relic's nebula and an end's shells are in the
  same batch and cover nothing. Its cost was measured once, on this Mac
  only: 1.9 to 2.6 ms a frame. That figure is in the look task's report
  (`.superpowers/sdd/2026-10-07-nightlight-ring/task-4-report.md`,
  Concerns, 2) and nowhere else: the log it names was written over, and
  the measurement was not made again. `GAS_MOST` is 2,000, as written.
- **A comet's tail is not in this spec and had to move**: it was drawn
  inside the frost line, which section 10 put at the ring's middle, so
  every icy body in the inner ring wore one. A tail is drawn inside
  `TAIL_R` 2.2 star radii and outside the Roche radius.

**The camera (sections 4 and 6).** `zoom()` and `FRAME` 500 are as written:
0.635 at one Sun, the star 95 px, the ring 328 to 500 px from it on a
1,000 px field. `VIEW_LEAST` stays 0.3. With `LOBE` 2.0 the dead star and
the birthplace are both in frame from the end of the pull back and through
the pan in every run, 655 px apart for a neutron star's birth and 532 to
560 for a dwarf's (471 to 484 for an Ember newborn, whose ring is wider);
half way through the pull back the birthplace is still outside the field
for every dwarf, and for the neutron star on one run of four. In the
eighth pass's game it was in frame from the first reading.

**The trickle (sections 7 and 7a).**

- **It is fed by need.** `_trickle()` adds `trickle_rate() * need() * STEP`
  and `need()` is `1 - gas outside the disc / ring_m`, held to 0 and 1: a
  full ring gets nothing, an emptied one all of it, and gas that has
  landed inside a grown star's disc does not count. Section 7's steady
  trickle piled up outside an idle star (4.2 Suns in 30 minutes on its
  first numbers) and, once tuned, came down at once (1.15 to 4.8 Suns in
  two minutes, at minute 13 to 15).
- `TRICKLE` is 0.2 (1.2 Suns a minute at one Sun at the most; section 7:
  0.017) and `TRICKLE_UP` is -0.75 (section 7: 1.0). An emptied ring is
  nearly full again in a minute (1.90 of its 3.0 at 15 s, 2.60 at 30 s,
  2.95 at 60 s), so the early pace is the hand's and the ring never looks
  used: that is nearer "a ring that refills fully", which the user turned
  down, than "a ring plus a slow trickle", which they chose (the open
  list, below). With the power at 0 a first star ended at 18 minutes and 37 Suns, because past 5.4 Suns
  the disc covers the ring, the need is always 1 and the Rich tile
  multiplies the rest. The most the far sky gives now thins as the star
  grows: 0.42 Suns a minute at 4 Suns, 0.25 at 8, 0.15 at 16. What a star
  takes with no hand still rises with its mass up to 5.4 Suns. **This
  turns the direction section 2 kept from Bondi upside down**, and it is
  one number.
- New gas lands anywhere in the ring, evenly by area (section 7: between
  0.9 and 1.0 of `ring.y`), on a circle, and since the final wave the ring
  it lands in is out by a giant's envelope (below). `DRIFT_MOST` 8 puffs a
  tick at most, and what is owed past that waits. At `MOST` it goes into
  a puff already out in the ring, the next along the list every time (the
  final wave; until then all of it into the last puff in the list, which
  was not always one in the outer ring and grew to a tenth of a Sun and
  more). A new puff
  comes up from a fifth of its light over 0.4 s, the sky's old rule, not
  over 2 s.
- `RICHER` 0.5 a supernova multiplies `trickle_rate()`, with `RICH_STEP`
  and `HAND` as written. On a ring that is full none of the three adds
  anything.
- `WIND` is 0.0003, as written.

**An untouched star (section 7's last bullet).** It does not dim and fade.
It eats the falling few and sits at 1.01 to 1.05 Suns for a hundred
minutes with its ring full, and nothing piles up. At one Sun the helium
flash (0.45 Suns of helium made, 107 minutes of burning) comes before the
hydrogen is out (167 minutes; 166.7), and the giant's disc, 990 px, is
past the whole ring, 788 px, so the ring falls in. As first built the far
sky then fed the star in full: helium lit at 103.1 minutes, 1.15 Suns a
minute later and 4.82 the minute after (the one jump of the run), a
supernova at 121.9 minutes and 16.4 Suns. Since the final wave the gas
drifts in 1,138 px and farther out round a giant, outside the disc of one
that light, so the far sky makes a ring up out there and the star climbs
as that ring comes down: 2 Suns at 107.9 minutes, 4 at 115.5, 8 at 120.0,
never more than 1.09 Suns in a minute, a supernova at 128.5 minutes and
14.1 Suns. Either way it is the chain's own arithmetic and was not forced.

**Worlds and relics (section 8, as 7a amended it).** `WORLDS` 8,
`PULL_REACH` 6, `HILL_HOLD` 0.5 and `MOON_DRAG` 0.05 are as written. A
world pulls solids out to six Hill radii; gas feels only a world that
`holds` it (`CORE_M` or more and under `GIANT_MOST`), inside one Hill
radius, and is eased toward it inside half of one. Each relic's pull at the
star's own place is taken off every body. The worlds have their own packed
arrays, not the relics' table. A tick with 300 bodies and 12 relics is 900
to 952 us on this Mac's debug build, under the 1.2 ms line.

**What a thing pays (section 9).**

- The steps are 4, 10 and 25, as written. They were 2, 3 and 6 for one
  round of the pace task, where solids paid 23 to 44 light of a first
  life's 1,400 to 3,600, and went back.
- `LIGHT` is 7.5 (it was 6.0 before this pass), so a first star's first
  ten minutes earn what the last build's did.
- **The Furnace is changed, though section 9 said it was not.** It paid
  200 light a mass at every tear, and a torn world's pieces are torn
  again: with solids paying in full it was half a later life's light. It
  pays `FURNACE_SHARE` 0.5 a level of the body's own worth (`m *
  spiral_light() * pay(rank)`), over and above that worth, once: the
  pieces carry `Body.torn` and pay nothing more. A world of 0.02 or 0.04
  pays 0.50 of its worth at one level and 1.00 at two, at 1 and at 4 Suns.
  **A body first torn while the Furnace is unlit** (not owned, or the star
  dim) is marked torn all the same and never pays it: "its first tear"
  read plainly, a ruling made while building. Cost: a few worlds'
  half-share lost round a dim spell.
- An `eat` event carries `e`, all the light that body paid. A solid's one
  `shed` is drawn as up to `SHED_ORBS` 12 motes; all of it is counted.

**Grains and the frost line (section 10).** The frost line and `SOLIDS` 40
are as written. `STICK` 0.0006 is new: two cooled dusty puffs within reach
make a grain only that share of the times `_meet` looks at them. A ring is
laid cool, and without it 27 to 31 grains formed in its first second. A
first ring left alone now has 4 solids at 10 s, 8 at a minute, 29 at
three, 38 at ten.

**The shop (section 11).** The four tiles and their prices are as written.
Rich and the Hand perk multiply the most the far sky gives; they do
nothing while the ring is full. A Reach at its sixth level says "as wide
as it gets" (`NL_DONE_REACH`, the final wave; it said Pure's "as pure as
it gets").

**The readout (section 12).** `system()` counts only bodies on closed
paths (`v^2 * r < 2 GM`): a planetoid passing through flickered into the
count. The file's `worlds` follows. The line sits at the sky's top left,
or under the powers' discs when there are any, and gives way to a note
said across it. The bodies are counted for it every quarter of a second
(the final wave; every frame before).

**The guard (section 13).** `OFFER_CALM` 0.6 is as written, and `PICK_WAIT`
0.6 starts again after it, so a card comes up 1.2 s after the last finger
lifts. **The deaf half second is a shield and is judged on the landing**:
`_shield`, an empty Control in front of everything, is STOP for `PICK_DEAF`
0.5 s after a card comes up by itself, and a press that lands on it stays
its own however late it lifts. As written (a time test in `_on_pick`) a
finger that landed on the fresh card and lifted after the half second
still took a power. **The perks card after an end is guarded the same
way** and waits for a calm sky (`_perks_due`); it was the other card that
raises itself. Cost: the top bar is deaf for that half second too.

**The file (section 14).** `KEPT` 4 also holds `ring_m`, `worlds`, and a
body's `torn` as a thirteenth column (a row without it has not been torn).
A bad `ring` falls back to the newborn's, and so does one more than ten
times the newborn's across; `ring_m` is held between half and one and a
half times the newborn's own; a `frost` or a `dusty` that is not a finite
number is the newborn's frost line or `FIRST_DUST` (the ten times and
these two are the final wave's). A `KEPT` 2 or 3 star is given
a ring of `RING_M` at `ASH_DUST`, fewer puffs if the sky has no room
(never past `FULL`).

**The tutorial (section 15).** No finger is drawn: the GAS page shows its
two presses as the game shows the player's, by their light. A page has no
ring of the game's own (`ring` is none), so it keeps its old scale and
frost line, nothing drifts in, and each puff is one light (`PAGE_WIDE` 1.8,
`PAGE_A` 1.5). `TALL` for GAS is 1,300; its loop is `GAS_LOOP` 30 s from
`GAS_SEED` 7. **The hint** (`NL_HINT`) is said until a press of this visit
has braked something (the final wave). As first built it went once the
star had eaten anything: a star kept from before the ring opened with no
button, no hint and no tutorial, and a new star lost the hint to the
first puff that fell by itself.

**Sound, haptics, analytics (section 16).** No event counted pours, so no
event's meaning moved. `nightlight_upgrade`'s tile is now reach, flow,
rich or pure.

**Checks and measurements (section 17).** The probe is 216 checks (204
before the final wave). The two
"ring beside a relic" checks compare against a twin sky with the relic
removed (at least 0.95 of it, and a floor of 0.8 of the start), not
against nine in ten of the start, which charged the relic for puffs the
ring's own cores gulped. "Left alone the ring does not come down" asserts
that nothing that started in the ring is inside the disc at 300 s and that
the star ate no more than the falling few. The untouched-star check that
asked for a fade is two checks on why it does not. The bot's hands are
`gas`, impatient, and `worlds`, patient (gas a quarter as often, and every
planet or giant on a closed path sent once). The harness's ring-at-birth
beat is `2b_ring`, in its `fresh` mode only; "the ring half eaten" could
not be shot (a ring is refilled by need) and that beat is
`6e_disc_over_ring`; "worlds and their swirls" shows the worlds and no
swirl. Draw calls: 89 to 92 on a new star, 135 to 139 heavy, 202 to 206
with the shop, against 855. The harness has 26 guards (24 before the
final wave).

**The pace (section 18), a steady impatient hand, five seeds.**

| Target | Result |
|---|---|
| 1 to 2 Suns in about five minutes | met: 5.6, 5.3, 5.4, 5.0, 5.4 min |
| a first end at 25 to 30 minutes | met by the mean (28.5): 26.2, 29.0, 31.7, 25.6, 30.2 min, at 15.0 to 17.8 Suns, always a neutron star (the last build: 19 to 21 Suns, one black hole in three) |
| a first star's light within 15% of the last build's | met by the mean on the first ten minutes: 11.8 a minute against 12.7 (by seed 10.3, 14.4, 11.7, 11.5, 11.0) |
| a third star earns about twice a first | dropped as a target when the pay went back to 4, 10, 25; it earns about twice all the same (55.9 and 60.5 light a minute for the two hands against 29.5 and 27.7, and six times as much from solids: 11.8 and 11.5 against 2.1 and 1.8) |
| a gas-only hand earns under half of one that waits for worlds | **not met, and the other way round**: on a third star the patient hand earns 8% less light in all (55.9 against 60.5 a minute) |

Effort matters less than section 1's answer 3 wanted: a finger down 40% of
the time reaches 2 Suns at 5.9, 5.5 and 6.1 minutes against 5.6, 5.3 and
5.4; at 15% it is 7.4, 7.2 and 7.6. By four to five Suns the disc is over
the ring and takes every world whatever the hand did.

The table is the game before the final wave, and the five seeds were not
run again after it. Seed 1 was: a first end at 30.9 minutes and 17.7 Suns,
a neutron star, and 69.2 light a minute over the life, where it had 26.2,
15.0 and 43.3. Most of that is the powers the seed drew the second time
(Fusion once and Thrift twice). With the powers and the perks out, the
same seed on the game before and after the wave ends at 27.5 and 27.6
minutes and earns 42.0 and 47.5 light a minute.

**The final wave (after the whole-branch review; `f3f3c7e0`).**

- **Gas that drifts in follows a giant's envelope. This is the
  controller's ruling, not the user's.** `_trickle` sets a puff down at
  `_ring_spot() * envelope()`, `envelope()` being `1 + GIANT * swell`,
  which the frost line already went by. The ring's place was fixed at the
  newborn's 518 to 788 px and a giant's mouth is past it: at 13 Suns as a
  supergiant every puff was eaten in the tick it landed and paid no light,
  so from the helium flash on, a third of a life, the hand had nothing to
  press. Now, at 8 Suns as a giant, it lands 1,138 to 1,733 px out, between
  a mouth of 620 and a disc of 1,980, and a puff is eaten 69 s on for 0.68
  of a perfect spiral's light; at 13 Suns as a supergiant 1,760 to 2,678
  px, between 1,127 and 3,598, 82 s and 0.84. Cost if wrong: a giant phase
  that earns more light than was tuned for; measured on one seed with the
  powers out it is 13% more light over a life, nearly all of it the
  disc's gas, and the same end. Nothing was retuned. One thing the ruling
  did not say: the disc covers where the gas lands only from 5.36 Suns,
  so a lighter giant has a ring to press and is not fed in full (the
  untouched star, above), and most of that ring is off the field.
- **With the sky at `MOST`, what drifts in is shared out**: each puff's
  worth to the next puff out in the ring after the last one fed (a cursor,
  no number drawn), never to one inside the star's mouth. Three Suns, six
  levels of Rich, no hand, two minutes: the heaviest puff ever was 0.083
  of mass where one puff had reached 5.78.
- **The hint** waits for a first press that brakes something; **a full
  Reach** has its own words; `end()` clears what the far sky owed; the
  readout counts every quarter of a second; the sky places a body by the
  scale it already has; **the file** holds a `ring`, a `frost` and a
  `dusty` to finite, sane numbers.
- Checked: the probe, 216 checks, 0 failed; the suite, 249,790 passed, 0
  failed; the harness, 26 guards, 0 failed, on the default driver and on
  `opengl3_angle`.

**Mine, not asked for (section 19), added by the build.** `RING_MOST`; the
trickle by need and its negative power; `STICK`; `DRIFT_MOST`; the Furnace
as a share paid once; counting only closed paths; the shield and the perks
card's guard; the covering gas layer and every drawing constant above;
`TAIL_R`; the twin-sky checks; a ring for a `KEPT` 2 star; the tide in the
star's frame; `LOBE` 2.0; the bot's two hands; a body first torn with the
Furnace unlit never paying it; and, from the final wave, gas following a
giant's envelope (the controller's ruling), the cursor that shares out an
overflow, and the hint's rule.

**Not done (section 20), added by the build.** The patient hand is not
rewarded. The late game slows where the user said "making it faster". An
untouched star ends as a supernova after two hours. Worlds are hard to see
under the cloud and no swirl is visible round a core. The cloud is cut by
the field's sides on a new star. The gas layer's cost is unmeasured on a
phone. Nobody has played any of it.

**Open, for the user to judge.** Each was surfaced and none was changed.

- **The ring refills fast.** The user chose "a ring plus a slow trickle"
  over "a ring that refills fully". As tuned an emptied ring is nearly
  full again in a minute, so the ring never looks used and the limit is
  the hand, not the sky: nearer the option they turned down. `TRICKLE` is
  the number.
- **Waiting for worlds is not rewarded**: on a third star the patient
  hand earns 8% less light in all (the table above; every run is in the
  pace task's fix round).
- **The late game's supply thins** (`TRICKLE_UP` -0.75) where the user
  said "making it faster".
- **Effort between 40% and 100% barely shows** in the bot's one-slice
  hand.
- **A kill in the middle of a save leaves a file that cannot be read, and
  a file that cannot be read is a new star.** Older than this pass; a
  second file and a rename would close it.
- **A tick read 1,255 us once** for 400 bodies with 12 relics all in
  reach (the whole-branch review's reading), over the plan's 1,200 line.
  No game makes that sky: births are 2,800 px apart.
- **A giant's gas is faint on a still, and a giant under 5.36 Suns has
  most of it off the field** (the final wave).
- **`opengl3_angle`, the phone's driver, is slower on this Mac on some
  runs and it is not explained**: its beats' mean frames ran 17 to 27 ms
  on the notes' run and 10 to 28 on the final wave's, where the default
  driver's ran 9 to 18 and 4 to 18; one earlier run of it read 9 to 20.
