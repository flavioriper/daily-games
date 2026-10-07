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

**The sim.** `brake(at: Vector2, r: float) -> int`: every body within `r`
of `at` (gas and solids alike, in the sim's pixels) has its velocity
multiplied by `1 - BRAKE * (1 - d / r)`, `BRAKE` 0.2, and its `sink` set to
1. It returns how many it braked and appends `{"kind": "brake", "at", "n"}`.
Nothing else: no drag is added and nothing is moved. What follows is the
orbit's own.

- Braked by a factor `f` on a circle at `R`, a body's nearest point becomes
  `R * f^2 / (2 - f^2)`, half a turn later and on the far side. At the
  ring's middle (655 px) the centre of a press (`f` 0.8) dips to 308 px,
  0.68 of the disc, in 48 s; the edge of the press (`f` 0.95) dips to 539
  px and misses the disc, so a light touch only ruffles the ring.
- A second press on the same gas (`f` 0.64) sends it to 0.26 of `R`, inside
  the disc's heart: it is eaten after a short spiral and pays little light.
  A gentle brake pays the most light for gas; a long hold feeds the star
  fastest. That is the drag's own rule, not a new one.
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

## 8. Worlds pull

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

- `frost` is set at birth to the ring's middle (`(ring.x + ring.y) / 2`,
  653 px at one Sun) and `frost_r()` is `frost * (1 + GIANT * swell)`: the
  inner ring makes rock, the outer ring makes comets and giants, for the
  whole life, and a giant thaws it. Today it is 2.2 star radii and follows
  the star, which would leave the ring all ice at first and all rock from
  1.8 Suns.
- `SOLIDS` 24 becomes 40: what the gas may make by itself.

## 11. The shop, the perk, the words of the powers

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

- `_offer` waits until no finger is down and `OFFER_CALM` 0.6 s have passed
  since the last one lifted.
- The pick card reads no press for `PICK_DEAF` 0.5 s after it shows.
- Section 5's list keeps the sky deaf under every card.

## 14. The file

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

No new file. `pour` is the press (section 5). `docs/agents/haptics.md` and
`docs/agents/analytics.md` are read before the screen is touched; an event
that counted pours counts presses that braked something. Nothing new is
tracked.

## 17. Checks and measurements

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
click, the flush, and then gas that sinks 5 px in 5 s and reaches the disc
in 48. That is the speed the user asked for on 2026-10-06 ("way too
fast"), and a pour took longer to pay, but a pour was not aimed. If the
press feels dead, the first lever is the ring nearer the disc (`RING_IN`,
`RING_OUT`), then `BRAKE`; `G` is not touched.
