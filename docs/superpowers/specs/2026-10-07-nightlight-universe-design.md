# Nightlight: a universe around the star

2026-10-07. The eighth pass on Nightlight (`2026-10-06-arcade-nightlight-design.md`
has the game as it stands; this spec replaces its end, its birth and its
empty sky, and leaves the hand, the disc, the tide, the chain, the powers,
the perks and the tiles as they are). Designed in chat; the user's words are
quoted, their three answers are recorded, and everything else is what was
proposed and built when they said "all good, build it".

## 1. What the user asked for

"Let's do some polish into nightlight, i wanna reframe it a little bit. Here
is the flow i'm imagining, we start somewhere around a lot of gas where the
first star born and star pulling everything by the gravity. User send gas to
feed it so it grow and get more and more orbit bodies attracted. After dying,
it explode and eject layers becoming a dwarf, while somewhere around a new
star begins (camera moves to there). The iron ejected start to form planets
and heavy bodies, and the gameplay continues. We are simulating a realistic
env. The idea is that player goes further and further incrementally into
star lifecycle as the born and die process happens. For example, let's say
it reach a point where it become a red giant, star actually grows and user
start to see more around, and as the gravity increase the orbit objects
start to be influenced and lose to the gravity orbiting closer and closer.
It should feel like a real universe around, not something empty."

Asked, they chose:

1. **Three remnants, by mass**: under 8 Suns a planetary nebula and a white
   dwarf, no explosion; from 8 a supernova and a neutron star; past about 20
   a supernova and a black hole. All stay in the world.
2. **Relics still act**: an old star keeps its gravity, a black hole relic
   bends what passes near it. (Over "decoration only" and "decoration, and
   the player can look around".)
3. **Approach A with honest masses**: the sim stays centred on the live
   star and relics are extra point masses at real-ish remnant masses; the
   new star is born far enough that its disc is safe, so the relic sits
   just past the screen's edge while the star is young.

## 2. What was looked up

- A star under about 8 Suns ends as a carbon-oxygen white dwarf after
  shedding its layers as a planetary nebula; a white dwarf is under 1.4 Suns
  (Chandrasekhar). From 8 to about 20 Suns the core collapses into a
  neutron star of about 1.4 Suns; heavier stars leave a black hole
  ([stellar remnants](https://astronomy.ac.uk/astronomy/section3/remnants)).
- A red giant loses mass, so a planet's orbit widens; what eats planets is
  the swollen envelope and the tidal drag it brings ([giant branch
  systems](https://arxiv.org/html/2405.09399v2), [orbits round
  giants](https://arxiv.org/pdf/0910.2396)). In this game the fed star
  gains mass all its life, so its gravity does rise, and the engulfment is
  given honestly as the disc following the envelope (section 6).
- A supernova's shock compresses nearby gas and can start new stars in it;
  the Sun's own cloud was seeded by one ([triggered star
  formation](https://arxiv.org/pdf/1312.4394)).

## 3. Relics (`arcade/nightlight_sim.gd`)

A **relic** is what a dead star leaves: `{kind, m, pos, layers, age, novas}`
in the live star's frame, where `kind` is `WD` (white dwarf), `NS`
(neutron star) or `BH` (black hole), `m` is in the sim's mass (10 a Sun),
`layers` is what it threw off (`Sim.layers()` at its death, for its
nebula's colours), `age` in seconds of play and `novas` the count it was
born at (for seeds). `relics` is an `Array[Dictionary]` on the sim.

- **Pull.** Every tick every body gets `G * relic.m / d^2` toward each
  relic, added to the star's pull before the drag; gas too. Relics do not
  pull the star, the star does not move: the frame is the star's. Nothing
  is torn by a relic; nothing merges at one.
- **Eating.** A body within `relic_r(relic)` of a relic is gone: `events`
  gets `{"kind": "lost", "at", "m", "relic": i}`; a black hole adds the
  mass to its own `m`, the other two do not. `relic_r`: a white dwarf
  `WD_R` (8 px), a neutron star `NS_R` (5 px), a black hole
  `BH_R + BH_R_M * suns_of(relic)` (10 + 3 px a Sun).
- **Masses at death.** White dwarf `WD_M` 0.6 Suns + `WD_M_PER` 0.05 for
  every Sun the star weighed, never over `WD_MOST` 1.3. Neutron star `IRON`
  (1.4 Suns, the core as it is). Black hole `BH_SHARE` 0.2 of the star,
  `BH_LEAST` 3 Suns. The remnant kind: `BH` from `COLLAPSE` 20 Suns, `NS`
  for a supernova under that, `WD` for a nebula or a fade.
- **How many.** `RELICS_MOST` 12: when a thirteenth is born, the farthest
  is dropped. A relic farther than `RELIC_REACH` (6,000 px) is kept for the
  record but pulls nothing (the loop skips it): off every view, its pull
  is noise.
- Cost: bodies times relics, at 300 bodies and 12 relics 3,600 more
  square roots a tick; measured in the probe, under 60 us on this Mac.

## 4. The three ends

`ending()` returns `"nova"`, `"nebula"` or `"fade"`:

- **Nova**: an iron core of `IRON` Suns, as today. The remnant is `NS`
  under `COLLAPSE` Suns, `BH` from it. Stardust as today (`dust_for`).
- **Nebula** (new): the helium core (`made[1]`) reaches `CARBON` (1.06)
  Suns while the star is under `HEAVY` (8) Suns. It cannot light carbon
  and sheds its layers. Remnant `WD`. Pays `NEBULA_DUST` 2.
- **Fade**: dim for `GRACE` seconds, as today. Remnant `WD`. Pays
  `FADE_DUST` 1.

`goal()` for a star under 8 Suns with helium lit says `{"which": "c",
"heavy": false}` as today, and the screen's line reads **"Carbon lights on
a star of 8× · sheds at 1.06 Suns of helium"** (`NL_GOAL_C_WAIT`
rewritten): the race is visible. Once the star is 8 Suns the line is the
plain carbon line.

**The sky's end** (`arcade/nightlight_sky.gd`, `END` gets a `nebula`
entry): the layers leave as a round shell with two or three soft lobes
(`LOBES_NEBULA` 3, the lobes 0.75 to 1.0 of each other) over `life` 6.5 s,
slower and softer than a supernova's nine fingers; hydrogen first and
furthest, helium behind, no veil over the screen, no white core-fall, the
star thinning as a fade's does. After the swap the relic is drawn where
the star was (section 7). The `fade` end plays as today and leaves the
same white dwarf.

**What the ends leave for the next star** (`end()`): the ejected gas is
laid on closed paths round the new star as today (`ASHES`, `ASH_*`), but
its dust is the old star's heavy layers: `ash_dust = ASH_DUST + METAL *
(layers[si] + layers[fe] + layers[rock])` with `METAL` 2.5, so a
supernova's child gets gas of 10 to 15% dust where a nebula's gets 5%.
`_condense` and `_sweep` are unchanged: richer dust is grains sooner and
planets heavier. **A solid made from gas over `IRONY` 0.08 dust is painted
iron-dark** (`Art.PAINT_IRON`, a cool slate): `Body` gets `metal` (0..1,
the dust share of the gas it came from, kept through merges by mass, the
file's tenth column), and `Art.paint_of` darkens toward `PAINT_IRON` by
it.

## 5. Birth and the camera

**Where.** `end()` picks the new star's place: direction `away` from the
mean of the relics' positions (the old star's included, at the origin) plus
`randf_range(-0.7, 0.7)` radians; a first relic (no others) takes a random
direction. Distance `D = LOBE * disc * (1 + sqrt(relic.m / new_mass))`,
with `LOBE` 1.6 and `disc` the new star's `haze_r()`: the new disc sits
inside the new star's gravitational lobe with that margin (the lobe's
radius is `D / (1 + sqrt(M_relic / M_star))`). On a 1-Sun star with a
450 px disc: 1,280 px for a 0.6-Sun white dwarf, 1,570 for a neutron star,
2,330 for a black hole of 5 Suns. Then every relic's `pos` shifts by `-D *
away`, the old star becomes a relic at `-D * away`, every body is cleared
(as today) and the ashes are laid round the new star.

**The camera** (`arcade/nightlight_sky.gd`): the sky gets `shift: Vector2`
(pixels; the live star is drawn at `centre + shift`) and `view: float`
(a factor on `zoom()`), both 0 / 1 except while an end plays. The end's
timeline after the layers have left (`swap` on): `pull_back` 1.2 s, the
view easing to show both the relic's place and the birthplace (`view` so
that `D` fits in 0.7 of the sky's height, never under 0.3); `pan` 3.0 s:
after the swap the frame is the new star's, so `shift` starts at `D *
away * zoom * u` (the old star's place still drawn at `centre`) and eases
to zero (the relic drifting off toward the edge, its nebula with it); `close` 4.0 s, `view` easing
back to 1 while the new star condenses (`_rise`). Under `Motion.reduce`
the pan is a cut at the swap and the star fades in over 2 s. `END.nova.all`
and the others grow by the pan's seconds; `end_swap()` is unchanged (the
sim ends when the layers have left) and the relic is drawn from the swap on.

**The birth.** The new star does not pop in at `_rise` 0: for the `close`
seconds it is drawn small and dim in the gas, the nearest ash puffs drawn
drifting into it (sky-side: the puffs the sim laid nearest are drawn with
an added inward offset that eases to 0), its light coming up with `_rise`.
The screen's `born` cue plays at the swap as today.

**A first game** opens the same way with no relic: `Sim.new()` lays
`FIRST_CLOUD` 36 puffs of gas (`ASH_M`, 70% hydrogen, 2% dust) on closed
paths round the star, `ASH_NEAR` to `ASH_FAR`, and the screen plays the
`close` part of the birth (the star condensing out of them, 4 s). A kept
star opens as today, no birth. Start over plays the birth too.

## 6. The giant

- **When.** `swell` rises toward 1 from the helium flash (`ignited[1]`),
  not only from carbon or starvation: a real giant comes before the flash,
  and the flash is what every fed star reaches. A star burning carbon or
  past it is a supergiant: `swell` toward 2 (`SWELL` 30 s a step as today).
  Dim (not `h_on`) still swells as today.
- **How big.** `GIANT` 1.2 (0.28): `star_r = main_r * (1 + GIANT * swell)`,
  so a giant is 2.2 times its plain radius and a supergiant 3.4. On the
  screen `SEEN_LOG` 70 (40): a 1-Sun giant is 206 px where the plain star
  was 150 and the view's scale falls to 0.62, a supergiant of 8 Suns 262 px
  at 0.26, so the star grows on screen and the sky shows two to four times
  as much around it.
- **The disc follows the envelope.** `haze_r()`, `frost_r()` and the eat
  radius are on `star_r()` (`main_r()` today), so a giant's disc reaches
  2.2 times as far: bodies parked on circles outside the plain disc are
  dragged, spiral in and are engulfed, and planets inside the envelope are
  eaten. `roche_r()` stays on `main_r()` (density): nothing is torn inside
  the envelope, it is swallowed whole. `LIGHT`'s `bind` is on `main_r()`
  as today. `wind_r()` follows `haze_r()`.
- **Colour** as today (3,600 K as a giant). The temperature's lerp uses
  `minf(1, swell)` so a supergiant is as red, not redder.

## 7. The universe around (`arcade/nightlight_sky.gd`, `arcade/nightlight_art.gd`)

- **Relics drawn.** From the sim's `relics`, in the live frame through
  `px()`: a white dwarf is a small white-blue point (`Art.WD`, 8 px at
  zoom 1, never under 4 on screen) with a soft glow of 40 px in the warm
  layer; a neutron star a 5 px violet-white point with a tighter, slowly
  pulsing glow (no beam); a black hole a dark disc (`Art.SHADE`, its
  `relic_r` in pixels, never under 10 on screen) in the body layer with a
  soft warm ring of 1.6 radii in the warm layer. Cozy light has no shape:
  no rays, no lensing arcs.
- **Nebulae.** Each relic carries its shell: `NEBULA_PUFFS` 48 soft lights
  in the gas batch, in `Art.MADE` colours by its `layers` (hydrogen and
  helium for a white dwarf's, the heavier colours at the heart of a
  supernova's), on a seeded ring that expands from 1.5 to `NEBULA_FAR` 3.5
  of the relic's distance-free radius (`NEBULA_R` 500 px) over `NEBULA_LIFE`
  600 s of the relic's `age` and fades from alpha 0.22 to 0.06, where it
  stays. `GAS_MOST` 480 goes to 1,100 (12 relics × 48 and the sim's gas).
  `Art.sky(size, novas)` loses its supernova clouds (the nebulae are
  world-anchored now); its specks stay.
- **Far stars.** `Art.far_field(seed)`: one mesh of `FAR_STARS` 90 soft
  points in three tints over a `FAR_WIDE` 6,000 px square, drawn under the
  gas at `FAR_PARALLAX` 0.25 of the live frame's scale and offset: it slides
  by a quarter of the pan and never otherwise. The sim keeps `drift:
  Vector2`, the sum of every `-D * away` so far, so the field is the same
  on reopening. One draw.
- **Neighbour stars.** `NEIGHBOURS` 5 decoration stars with no mass: a
  `far: Array[Vector2]` on the sim, seeded at `Sim.new()`, 2,500 to 5,000
  px off in the live frame, shifted with the relics at each birth, drawn
  as 3 to 6 px warm points with a glow. Nothing reads them. They give the
  pan parallax against the far field.
- **Draw calls**: a relic in view is 2 to 3 (point, glow, a black hole's
  ring); the nebulae and gas are the one gas batch; the far field one
  mesh. A new sky is about 92 (90), a heavy star with three relics in view
  about 150 (137-139). Measured in the harness.

## 8. Pace, stardust, the file, words

- The pace of a life is unchanged on purpose; the only new end is the
  nebula, which a hand that cannot pass 8 Suns before a 1.06-Sun helium core
  reaches first. The bot held two thirds of the time makes 8 Suns at about
  17.5 min and the carbon core at 24; the probe's pace mode reports which
  end came and the remnant.
- **The file** (`KEPT` 3): `relics` (kind, m, pos.x, pos.y, age, novas,
  layers[8]), `far` (x, y pairs), `drift`, and a body's `metal` as a tenth
  column. A `KEPT` 2 file loads with no relics, no `far` (seeded fresh),
  `drift` zero and `metal` 0. `Sim.kept()` adds `relics` (the count) for
  the Arcade card: its line reads "N× the Sun · M relics" past the first.
- **Analytics**: `nightlight_nova` gets `how` ("nova", "nebula", "fade")
  and `remnant` ("wd", "ns", "bh"); new `nightlight_lost` is not tracked
  (several a minute near a black hole).
- **Words** (`locale/ui.csv`, en/pt/es): `NL_END_NEBULA` ("The star lets
  its layers go · a white dwarf is left"), `NL_END_NOVA` gains the remnant
  ("… a neutron star is left" / "… a black hole is left": `NL_END_NOVA_NS`,
  `NL_END_NOVA_BH`), `NL_END_FADE` ("… a white dwarf is left"),
  `NL_GOAL_C_WAIT` rewritten, `NL_CARD_RELICS_ONE/_N`, and the tutorial's
  END page (`TUT_NL_END_BODY`) rewritten for the three ends and the relic
  that stays. Titles stay English.
- **Haptics/sound**: the nebula end cues `fade` (the slow letting-go take)
  and its thud; `lost` (a body into a relic) is silent and unfelt.

## 9. Testing

- `tests/_probe_nightlight.gd` gains checks: a body at rest between the
  star and a relic of twice its mass falls toward the relic; a body inside
  a black hole's radius is lost and the hole weighs more; a white dwarf
  does not grow; a 4-Sun star with a 1.06-Sun helium core ends "nebula"
  and leaves a `WD` of 0.6 + 0.15 Suns; a 10-Sun supernova leaves `NS`, a
  25-Sun one `BH` of 5 Suns; after `end()` the relic is at `-D * away`
  with `D` by the lobe rule and the new disc inside the lobe; relics past
  twelve drop the farthest; `haze_r` is 2.2 times wider at `swell` 1; a
  circle at 1.5 of the plain disc spirals in once the star is a giant;
  ash dust after a supernova is over 0.1 and a grain from it has `metal`
  over `IRONY`; `metal` survives a merge by mass; save and load round-trip
  relics, `far`, `drift` and `metal`, and a `KEPT` 2 file loads clean.
  `-- pace` reports the end's kind and remnant, and times a tick with 300
  bodies and 12 relics.
- `tests/_shot_nightlight.gd` gains beats: `9a_nebula_leaving` (a 4-Sun
  star shedding), `9b_relic_wd` (the dwarf and its nebula after the pan),
  `8d_pull_back` and `8e_pan` for a supernova (the relic drifting off),
  `6_giant` reshot with a parked body spiralling in and the view drawn
  back, `6c_relics` (a heavy star with three relics in view), `0_birth`
  (the first game's cloud condensing), and `17_tab_after` with the card's
  relics line. Both drivers, reduce motion, en/pt/es, draw calls quoted.
- The suite (`tests/run_tests.gd`) stays green.

## 10. Not done

Nothing on a phone, nobody has played it, the concept tab is the first game
still, relics do not tear, a relic's own nebula is decoration (its gas is
not the sim's), the player cannot look around (the sky takes no press, by
the user's earlier choice), a white dwarf never goes nova however much it
eats, and the far field and neighbour stars are the only things in the
universe that are not the player's own doing.

Mine, not asked for: every number; the nebula end's trigger (the helium
core at 1.06 under 8 Suns); the stardust the nebula pays; `METAL` and the
iron paint; the lobe rule's 1.6; the three-part camera and its seconds;
the first game's cloud; the giant's 2.2 and the supergiant's 3.4; the disc
following the envelope; the relic cap and reach; the far field, the
neighbour stars and their parallax; the words.

## Amendment, 2026-10-07: as built

The build (`bbf3a05d..63068a4d`, five tasks, reviewed) kept the design and
changed these. The code's values are the ones quoted; the notes in
`docs/agents/arcade.md` (the eighth-time bullet under Nightlight) carry the
measurements and the rest of what the build left.

- **The pour stays at the plain disc** (section 6). `haze_r()`, `frost_r()`
  and the eat radius follow `star_r()`, but the hand's gas still comes in at
  the new `pour_r()` (`main_r() * haze_wide()`): a giant's wider disc does
  not move where the player's gas arrives. `giant()` is `minf(1, swell)` for
  the temperature, and `swell` runs 0..`SUPER` 2.0.
- **"Helium core" is the carbon core** (sections 4, 8 and the words). In the
  sim `made[0]` is helium and `made[1]` is carbon; the nebula's trigger is
  `made[1]` reaching `CARBON` 1.06 Suns with helium lit, carbon not lit and
  the star under `HEAVY` 8 Suns: a star too light to light the carbon it
  made. The spec's "helium core" was wrong. The tutorial's END page says
  "carbon core", and `NL_END_NOVA` is gone (`NL_END_NOVA_NS` and `_BH` read
  in its place). A white dwarf's mass is `WD_M` + `WD_M_PER` for every Sun
  *above the first* (the spec's own test, a 4-Sun star leaving 0.6 + 0.15,
  says so; its prose said "for every Sun the star weighed").
- **The far field's scale** (section 7). The spec put `FAR_PARALLAX` 0.25 in
  both the scale and the offset; the mesh came out 675 px wide with
  sub-pixel stars. The scale is `u * maxf(0.6, zoom * view)` and the
  parallax is only in the offsets (`centre + shift * FAR_PARALLAX - slid *
  FAR_PARALLAX * s`): the backdrop still slides a quarter of the pan and
  never otherwise. `drift` is wrapped into [-3000, 3000), not [0, 6000), so
  the mesh always reaches at least 2,250 scaled px from the centre.
- **A black hole's disc is on the top layer** (section 7 said the body
  layer). The body shader lights `COLOR`, so a `SHADE` disc there is a lit
  crescent; the discs are one batch (`_holes`) drawn first in `_draw_top`.
  A body falling in vanishes under the disc a frame early.
- **The black hole's ring is at 2.6 r** (section 7 said 1.6 r): at 1.6 r
  almost all the ring was under the disc and the hole read as a hard dark
  dot. It is two warm glows, 2.6 r and 1.9 r, alpha 0.5 each.
- **The camera frames the midpoint** (section 5). The pull back brings the
  midpoint of the dead star and the birthplace under `centre` while `view`
  eases to `fit`, and the pan goes from the midpoint to the new star; the
  spec pinned the old star under `centre` and measured `D` against the
  sky's height, so the birthplace was never in frame. `fit = clamp(FIT *
  min(size) / (D * zoom * u), VIEW_LEAST, 1)` with `FIT` 0.45 of the
  field's shorter side and `VIEW_LEAST` 0.3. `view` starts at `view0 =
  clamp(old zoom / new zoom, 0.3, 1)`, not 1, so the frame does not jump
  3.6 times when a giant is swapped for a young star; the pull back can
  therefore close in. The shells stay round the dead star's place after the
  swap, and the new star is a dim seed (`SEED` 0.3) while the camera
  travels.
- **`GAS_MOST` is 1,400 and `WARM_MOST` 704** (section 7 said 1,100 for the
  gas and said nothing of the warm lights, capped at `MOST` 320): 300 gas + 12 relics x 48 nebula puffs
  + a fade's 7 x 72 shell puffs is 1,380, and each body can take two warm
  lights. `WARM_MOST` is `MOST * 2 + 64`, by sizing, not measurement.
- **The goal line's wording** (section 4). The spec's "Carbon lights on a
  star of 8× · sheds at 1.06 Suns of helium" overflowed into "Power at 4×"
  on the same row in pt, and `Art.short(CARBON)` printed "1". The line reads
  "Carbon core 1.06 · sheds unless 8× · core 100 million K" (pt "Núcleo de
  carbono 1,06 · se desfaz sem 8× · a 100 milhões de K"; es has the same shape,
  "Núcleo de carbono %s · se deshace sin %s× · a %s" in the csv); the 1.06 shown
  is the carbon core the star has now, not the threshold.
- **The end's seconds** (section 5). The nova's end is 11.8 s, not the
  spec's 7.4 s plus the pan: `swap` 3.6 + `pull_back` 1.2 + `pan` 3.0 +
  `close` 4.0, where the old tail after the swap was 3.8. Every later
  harness beat moved +4.4 s. The `all` entry is gone; `end_time()` adds the
  phases.
- **Measured against the spec's expectations.** A tick with 300 bodies and
  12 relics in reach is 608-622 us (280 with no relic, a debug build), not
  "under 60 us" for the relics: accepted. A heavy star with three relics is
  142-146 draw calls, not about 150. The bot holding the button nonstop
  ends on seed 1 at 26.9 min and 20.9 Suns, as a black hole (25.4 min and
  23.2 Suns before the giant change, +5.9%); section 8 said the pace of a life
  was unchanged on purpose, and the giant moved it by that much.
- **Also built, not in the spec**: the pull table in `tick` is four packed
  arrays; `Art.sky(size, novas)` keeps its signature and `CLOUDS` is gone;
  `REDUCED_RISE` 2 s; `END.birth`; `Sim.fresh`; the harness's `fresh` mode,
  `9c_nebula_pan` and `16b_tut_end_pan`; `9b_relic_wd` renamed
  `9b_after_nebula` (the dwarf is off screen at the time of the shot).
