# Balance, redrawn as a seesaw

Date: 2026-09-27. Replaces the column-of-scales board of
`2026-09-18-balance-flat-design.md` (the id, the name and the fruit cast stay).
Built unattended at the user's word ("do it, surprise me for good").

## 1. What the user asked for

"Redesign the balance game to be more dynamic, instead of just changing
numbers, add some physics and let the user try to get a perfect balance by
placing the items onto the two sides." Then, of four shapes offered, the
seesaw with notches, **with every weight hidden**: "the idea is to let the
user try them and check the weights on the seesaw. Make it less like a boring
puzzle and more dynamic and interactive ... make items roll realistically."

## 2. The game

A garden seesaw: a plank on a trestle, with **cups** at distances 1 to D
either side of the pivot. A basket of fruit under it. Every kind of fruit
has a **hidden** whole-number weight. A fruit in cup `x` (negative left)
pulls with `weight * x`; the beam leans with the sum.

- Drag a fruit out of the basket and let go over the plank: it drops, lands,
  bounces and rolls into the nearest free cup. Drag a seated fruit to another
  cup, or back to the basket. Let go anywhere else and it tumbles to the
  grass and hops back to the basket.
- **Some fruit come pinned** (a brass pin through the stalk): they are part
  of the answer and never move. They are what makes the day's answer unique.
- **Win: every fruit on the plank and the beam dead level.** Exactly one
  arrangement does it (section 4), so the win is also "the" answer, but the
  check is the physics' own: all seated, net torque zero.

**The tilt is a quantity, not a sign** (the research's main lesson: PhET's
free plank only ever says left or right, which turns a weighing puzzle into
trial and error). The trestle's hub carries a hanging counterweight stone, so
the beam behaves like a pendulum balance: it rests at `tan(angle) = torque /
K`. A spirit level sits on the plank over the pivot with **one tick per unit
of torque**, five a side. A lone apple in cup 1 reads its own weight in
ticks; an apple in cup 2 against a pear in cup 3 reads `2a - 3p`. Past five
the beam bottoms out on a hay bale with a thud and the bubble is pressed to
the end of its glass: "more than five", which is information too.

## 3. The physics (`puzzles/balance_sim.gd`, pure data, fixed step)

Deterministic and stepped at `DT = 1/120` on the board's clock, like
Marigold's sim, not Godot's physics server: the board is drawn as meshes on a
Control, a harness can step it headless, reduce motion can skip straight to
rest, and nothing can wedge or escape the card. (Godot physics was the user's
example, not a requirement; this is the same physics, owned.)

- **Beam**: one rotational degree of freedom. `I * a = G * (sum w*x) cos(a)
  - K * G * sin(a) - C * v`, inertia growing with the load (`I0 + sum w*x^2`),
  so a laden beam swings slower. Hard stops at `A_MAX`, restitution 0.3, and
  a stop hit is an event (thud, dust, every seated fruit jolts).
- **Fruit** on the plank live in the plank's frame: a coordinate `s` along
  it (in cup units) and a height `h` above the surface. Gravity pulls down
  the slope (`-g sin(a)`), the target cup's well pulls it home, rolling
  friction damps it, and `spin` integrates `ds / r` so a rolling fruit
  visibly rolls. A seated fruit is a weeble: its spin springs back upright.
  Passing over an occupied cup it rides up over the occupant.
- **Flight**: a released fruit falls in world space from where the finger
  let go, with the finger's velocity (clamped), until it meets the plank
  surface (then it bounces: `h` takes the impact at restitution 0.35 and the
  beam takes an impulse `w * s * v` -- a heavy fruit jolts the beam more) or
  the grass (bounce, then a hop home to the basket).
- **Torque** counts every fruit touching the plank at its current `s`, so a
  fruit rolling outward tips the beam further as it goes.

## 4. The generator (`puzzles/balance_gen.gd`)

Per band: kinds, fruit, reach D, top weight.

| band   | kinds | fruit | cups (2D) | weights |
|--------|-------|-------|-----------|---------|
| Easy   | 3     | 6     | 6         | 1-5     |
| Medium | 4     | 8     | 8         | 1-7     |
| Hard   | 5     | 8     | 8         | 1-9     |
| Insane | 5     | 9     | 10        | 1-12    |

1. Distinct weights per kind; a basket with every kind at least once.
2. Scatter the fruit into cups until the torque is zero: the day's answer.
3. Reject an answer that balances **whatever the weights are** (each kind's
   own signed distances sum to zero) -- it teaches nothing.
4. Pin the answer's fruit one at a time, each time the one that leaves the
   fewest completions under the true weights, until exactly one completion
   is left. Prototyped over 30 seeds a band: 1-2 pins on Easy, 1-3 Medium,
   2-3 Hard, 2-5 Insane.

The counter is a memoised walk over the free cups (remaining kinds, torque),
capped once it passes what the greedy pick needs.

## 5. The screen

One board card, no tray, no actions row (`"tray": "none"`, `"actions":
false`): Undo, Reset and Hint in the top bar, Pinwheel's shape.

- Sky and two far hills, a cloud; the meadow; the trestle (two splayed legs,
  a hub), the counterweight stone swinging on its rope under the hub; the
  plank with its cups and distance pips (1, 2, 3 ... dots on its face); the
  spirit level on top at the middle; hay bales under the ends.
- The wicker basket across the foot of the card, its fruit in a row grouped
  by kind.
- The fruit are the cast (`ui/faces/fruit.gd`), all one size so size says
  nothing about weight. On the plank a fruit on the low end worries, one on
  the high end is delighted, one held or flying is puzzled; at level they
  smile. At the win every fruit hops and the win screen lays each kind out
  **with its weight under it** -- the reveal.
- **Level is a moment**: the bubble settles into its ring, the ring glows,
  the hub rings and the `level` cue plays. Level with fruit still in the
  basket says so in a toast ("Level! Now the rest of the basket").
- Hint (3, none on Insane): one loose fruit flies from wherever it is into
  its answer cup and is pinned there with a gold pin; a fruit already in
  that cup hops home first.
- Undo takes the last move back (the fruit flies to where it was); Reset
  sends every loose fruit home to the basket.

## 6. Sound

The existing set (`step`, `level`, `refused`, `undo`, `hint`, `reset`,
`solved`, `enter`) plus `lift` (pick a fruit up), `land` (a fruit landing on
the plank, pitched by its weight: heavy is lower), `thud` (the plank hitting
a bale), `seat` (a fruit settling into its cup), `tock` (the reading
settles). `Fx2D.cue` plays silence for any file not yet generated.

## 7. What was not done, on purpose

- No concept tab first: the user left and asked for the build.
- No candidate chips or weighing notebook (the research's Ballast idea):
  the gauge reading is exact, so the player's own notes are enough to begin
  with. Worth revisiting if the phone play shows people forgetting readings.
- No par: moves are counted and shown on the win screen, never graded.

## Amendments (the build, 2026-09-27)

- **The cup has a stiff core** (`balance_sim.gd`'s `CORE`, `CORE_DRAG`,
  `CORE_W`): with only the wide well, a fruit on a plank leaning its full
  0.16 rad settles 0.13 cup downhill of its cup and never counts as seated,
  so the beam never read as at rest and the sign stayed dim.
- **The stops are resting contact**: a knock under 0.12 rad/s no longer
  bounces, or a plank on a bale micro-bounced for ever.
- **A held fruit's speed fades while the finger is still**, and an upward
  fling keeps a third of itself: lifting a fruit out of the basket is not a
  throw.
- **Each kind is seated by its drawn radius** (`_drawn_r`): the mushroom and
  the acorn fill less of their seat than the round fruit and stood a few
  pixels above the plank.
- **Faces here are `shadowless`** (a new `Face` flag): against the sky the
  offset shadow disc read as a grey halo round every fruit on the plank.
- **The sign carries a little seesaw icon** leaning the way the beam does,
  not an arrow; the arrow at that size read as "up".
- The scene: the seesaw stands mid-card and the basket sits on the lawn in
  front of it; far trees, flowers and tufts dress the lawn.
- Measured at `--resolution 810x1440`: 87 draw calls, idle 3.3-3.5 ms,
  ANGLE agreeing on 87 and within 4/255; generation worst 0.7 / 10.4 / 5.9 /
  29.2 ms (Easy to Insane, 40 seeds a band); the win harness solves it by
  touch.
