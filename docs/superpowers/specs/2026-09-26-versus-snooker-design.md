# Versus tab and Snooker (local, against the computer)

2026-09-26. Asked for by the user, who was away while it was built, so every
call below was made without them; each is one they may overturn.

## 1. The ask

- The first tab ("Home") is renamed **Puzzles**.
- A new bottom-bar tab for player-vs-player games, named **Versus**
  (pt/es "Duelos"), hosts the first one: **snooker**.
- Rules checked on the web (WPBSA rulebook, Wikipedia's "Rules of
  snooker"), realistic physics, **local only for now: you against the
  computer**.
- Reference layout: the user's mock (portrait table, black end at the top,
  the D at the bottom, flat top bar with reset / hint (3) / settings, a
  ball-tally column down the left, a treehouse terrace around it).

## 2. What was built

| Piece | File |
|---|---|
| Physics (pure data, headless) | `versus/snooker_sim.gd` |
| Referee | `versus/snooker_rules.gd` |
| Computer player and hints | `versus/snooker_ai.gd` |
| Table drawing and touch | `versus/snooker_table.gd` |
| Spin pad and power slot | `versus/snooker_controls.gd` |
| The screen | `versus/snooker_screen.gd` |
| Win/loss record (local) | `versus/versus_record.gd` |
| The tab | `ui/menu/versus_tab.gd` |
| Sounds | `assets/sfx/snooker/*.ogg` (`tools/gen_sfx.py snooker`) |

Harnesses: `tests/_probe_snooker.gd` (physics), `tests/_probe_snooker_frame.gd`
(a whole frame, computer against computer; `LEVEL=0..2 SEED=n VERBOSE=1`),
`tests/_shot_snooker.gd` (tab, table, break, computer's turn, end card),
`tests/_tap_snooker.gd` (the same driven by input alone).

## 3. Physics

Metres and seconds, regulation playing area (3569 x 1778 mm) stood on end.
**Balls and pockets are 1.3x regulation** (`Sim.SCALE`): a 52.5 mm ball on a
phone-sized table is 18 px across; everything else is to size. Pocket mouths
are about 1.87 ball widths (corners) and 2.1 (middles), close to a real
table's and a little kinder.

The cloth model is the standard slide-then-roll one: `roll` is the spin
about the horizontal axes expressed as the contact point's surface speed, so
a ball rolls when `roll == vel`; while they differ, sliding friction
(mu 0.2) pulls them together, the centre at mu*g and the spin at 5/2 mu*g.
Stun, follow and screw come out of that alone, because a ball keeps its
spin through a collision. Rolling resistance mu 0.010. Side spin wears at
0.7 m/s^2 of surface speed and grips a cushion (running side widens the
angle, check side narrows it). Ball restitution 0.94, cushion 0.78.
Collisions are rewound to their time of impact inside the 1/480 s step, so a
thin cut goes where the guide said. Cushions and pocket jaws are capsule
segments, so balls rattle in the jaws.

## 4. Rules (what the referee enforces)

Reds and colours alternate; the colour **struck first is the nominated
one** (no spoken nomination, as every digital snooker does it); colours
re-spot while reds remain (own spot, else highest free, else toward the top
cushion); then colours in order and they stay down. Fouls: nothing hit,
wrong ball first, a ball not on potted, in-off; penalty is the highest of
four, the ball on and every ball involved. After an in-off the opponent has
the ball in hand in the D. **Free ball** when the player coming in is
snookered on every ball on (both extreme edges tested). The frame ends on
the last black (potted or fouled); a tie re-spots the black with the player
drawn at random.

**Left out on purpose**: the miss rule (the offender is never put back),
the choice to make the offender play again, touching ball, concession,
and the seven-point penalties for specific infringements (successive reds
without a colour cannot happen here; everything else is covered by the
general penalty).

Found and fixed in the frame probe: the referee first read the ball on
after the potted colour had already left the table, so every legal colour
in the clearance was a foul and frames never ended.

## 5. The computer

Ghost-ball geometry over every ball on and pocket (straight lines only),
the five easiest pots rehearsed on a copy of the table with three tips and
two paces each, scored on the pot and on the next ball's ease. No pot worth
taking: safeties that touch a ball on and leave the least, and when
snookered, 64 escape directions at two paces off the cushions. A thinking
budget of 1.8 s; it runs on a worker thread. The levels differ only in the
arm: aim wobble 1.15 / 0.46 / 0.16 degrees and pace wobble 10 / 6 / 3 %,
plus the Easy computer not seeing marginal pots. Frame probes (computer vs
computer): Easy highest breaks ~5-8 over ~106 shots, Medium ~8-13 over ~70,
Hard ~20-25 over ~50-60. The break-off is scripted: from beside the yellow,
thin on the pack's back corner with side.

The hint (three a frame, the top bar's bulb) is the same planner at Hard
for you: it lays the line in gold, sets the tip and marks the pace on the
power slot.

## 6. The screen

The flat boards' top bar (`FlatTopBar`, with Reset riding in it and the
hint's badge), a scoreboard (the **sun is you, the moon is the computer**,
the menu header's pair, and the ball on painted between them, gold-ringed
for a free ball, with the break and the points left), and the table on a
wooden deck. **The reference's ball-tally column became the controls
column**: the spin pad (a big cue ball, touch where to strike, limited to
the miscue radius) and the power slot (pull down, let go to play, push back
to the top to cancel). The scoreboard already says what is on, and a phone
needs the thumb room.

Aim: touch the table where to aim and drag to swing. In hand: drag the cue
ball round the D. The guide shows the ghost ball, the object ball's line
and the cue ball's stun line.

The painted plate is the dusk vista (the treehouse, as in the reference).
Measured with `tests/_shot_snooker.gd` at `--resolution 810x1440`: **91**
draw calls on the Versus tab, **146** at the table, **150** while the
computer lines up, **163** on the end card; the same under
`--rendering-driver opengl3_angle`. Home reads 261 with the fourth tab.

## 7. Open for the user

- Online play (the tab is named for it); the local screen has no network.
- Whether balls at 1.3x are right on the phone.
- The sounds are one take each, not yet listened to.
- No concept-page tab was made before the Godot code this time (the user
  was away and asked for everything to be built).

## 8. Amendment: polish (2026-09-26)

Built directly after the first pass, on the same day.

- **Table**: cushions read as raised rubber (a darker body, a shaded back
  edge, a lit nose over the cloth) and the rail carries a lit inner edge; the
  cloth has a warm lamp pool along its length and a faint nap of short
  strokes (first drawn long and bright, which read as rain); pockets deepen
  toward the back.
- **Motion on the table**: a fast ball leaves a short smear of its own colour
  that catches up with it as it slows; two balls meeting flash and ring at
  the contact, scaled by the speed; a hard cushion strike glints; a potted
  ball rolls over the jaw and drops, shrinking and darkening, under a gold
  ring at the pocket and a puff in its own colour.
- **The cue** slides up behind the ball at every turn, feathers slightly
  while you line up, goes through the ball and a little past it from the
  point it was struck (not chasing the ball), and fades away. The guide's
  dashes march toward the target and the ghost ball is filled; the D glows
  while the ball is in hand.
- **The toast now clears on the strike**: before, it hid whatever rolled
  through the table's middle.
- **Power slot**: a pale groove in a wooden housing instead of the black
  tube, which was the heaviest thing on the screen; the fill warms by depth,
  and the cue's butt carries a shadow.
- **Scoreboard**: scores tick up a point at a time, the points (or a foul's
  penalty) rise as "+N" in gold beside the score they go to (this replaced
  the "+N" toast), and the ball-on pops when it changes. The end card drops
  in with an overshoot, and a won frame throws bursts in the ball colours
  round it.
- Every decorative piece is off under reduce-motion.

Measured with `tests/_shot_snooker.gd` at `--resolution 810x1440`: **149**
at the table (146 before), 157 while the computer lines up, 170 on the end
card; the same under `--rendering-driver opengl3_angle`.
