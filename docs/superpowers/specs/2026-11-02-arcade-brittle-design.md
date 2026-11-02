# Brittle: an Arcade game

2026-11-02. Built unattended. The user, with one screenshot of a web game:
"here is the new game we need to add to arcade. Do everything autonomous,
make sure it uses all the quality patterns".

## 1. What it follows, and what it may not be

The reference is a neon web ball shooter. **That name is written here once,
to forbid it: Bricks Breaker** (the genre's other title, Ballz, likewise). It
appears nowhere in code, comments, commits, locale or on screen. Kept from it
is the shape: a stream of balls aimed from the floor, numbered blocks that lose
one a hit, rows coming down a step a volley, a growing ball count, a button
that calls the balls home, and an undo.

The neon is not kept. **The set**: a tin of nut brittle cut in squares on the
house's wooden floor, sugar balls poured from a scoop, sugar plums (+1 ball),
popping candy, wedges. The name is the sweet and the word for what it is.

## 2. Rules (arcade/brittle_sim.gd)

- A tin seven cells wide with nine rows and a lane over the floor.
- Hold and slide to aim, let go to pour. The dots are `trace`, the sim's own
  physics. Sliding back to the scoop takes the aim back.
- A ball takes one off a square. A square is worth the step, a hard one twice
  that from step 6.
- The first ball down sets the next pour's place. All home: the squares come
  down a row and a new one is laid. A square past the last row ends the run.
- Every row holds a plum, so a run can always grow.
- Wedges from step 3, row and column lines from 5, popping candy (breaks into
  its eight neighbours) from 7, sparks (turn a ball anywhere) from 9.
- A cleared tin is worth ten times the step.
- Score is numbers taken off. Stage is the step.

## 3. Nobody waits

A volley speeds up the longer it runs (`Board.PACE`: 1x, 1.6x, 2.6x, 4x), and
from 26 s a little weight pulls every ball down, so no volley can last for
ever. After a bounce a ball keeps a share of its speed going up or down, so it
cannot run wall to wall.

## 4. Tools

Undo takes the last volley back, the same row included (2 a run, +2 with a
booster). The bulb shows the next aim three bounces deep (2 a run). The arrow
calls the balls home. Boosters: A full scoop (+4 balls), Second thoughts (+2
undos). Second chance: the three lowest rows are swept off.

## 5. Draw calls

Each piece is a cached mesh, one `draw_mesh` a cell, so a knock is a transform.
All the balls are one MultiMesh, one buffer a frame.
