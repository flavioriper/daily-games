# Tally: the fourteenth Arcade game

2026-10-15. Built unattended. The user: "belmatic like game is the next
arcade game, there is a implementation plan spec from a deep search to use
as guidance. Check on web for any reference you need. Build end to end, wire
sfx, smooth and cozy animations based on current games. Do it autonomous."
The research is `reports/Beltmatic game spec.md` (untracked, the user's).

## 1. What it follows, and what it may not be

The reference is Notional Games' *Beltmatic* (2024), a factory game whose
only resource is the integer. **That name and the studio's are written here
once, to forbid them**: none appears in code, comments, commits, locale or
on screen. Nothing of it is here: no art, no sound (its soundtrack is
licensed), no text, no code. What is kept is the shape the report calls
load-bearing: numbers dug from deposits, carried on belts, combined by five
two-input operators, delivered to one hub that asks for one number at a
time; a ladder that hands out the tools; upgrades paid in delivered numbers,
not in coins; saturating 32-bit arithmetic, A ÷ 0 = (0, A), no zero
remainder; no 10 to dig.

What is not kept: the blueprint blue, an endless map, a 3×3 extractor, a
6×6 hub, keyboard controls, copy and paste, priorities, markers.

## 2. The game

**Tally**: a sheet of squared paper on a desk. Wooden number tokens ride
walnut belts with brass chevrons from the digs to the counting box in the
middle, through painted wooden machines that add, multiply, take away,
divide and raise. The box asks for one number, so many times; when it has
them it goes up a level and something new is handed over.

A kept game like the Factory: `user://tally.cfg`, no run, no end card, no
gold, no boosters, no interstitial. **The paper runs only while it is on
screen** (the Factory's rule): nothing is worked out for the time away.

**The pieces** (every one a single square, so a thumb can place it):

| Piece | Unlocked | What it does |
|---|---|---|
| Belt | start | carries one token a square, at the belt's speed; laid by a swipe, a straight run |
| Dig | start | stands on a number printed on the paper and puts that number on every belt leading away from it, up to its level's count of belts |
| Adder | level 1 done | A + B |
| Bridge | level 4 done | made by itself when a run crosses a belt square on |
| Multiplier | level 7 done | A × B |
| Subtractor | level 13 done | A − B |
| Divider | level 16 done | A ÷ B forward, the remainder backward (none when it is 0) |
| Raiser | level 19 done | A to the power B |
| Crate | level 22 done | keeps up to 500 of the first number it gets and lets them out on every belt leading away |
| Counting box | fixed, 4×4 in the middle | takes everything from every side |

**An operator has a facing**: A comes in on its left, B on its right, the
answer goes out of its front (the divider's remainder out of its back). Its
place in a row is the order of A and B, as in the reference, where it is the
machine's shape.

**Belts.** A token goes to the square in front; a belt whose back touches a
belt's side takes every other token from it (a split, round and round); a
belt fed from its side turns the corner. Many belts into one take turns.
A dig and a crate feed only belts leading away from them. Operators take
from belts pointing into their A and B sides and hand onward to a belt, a
machine's side, a crate or the box. A machine holds 4 a side and 2 waiting
to go.

**Numbers** saturate at 2,147,483,647 and −2,147,483,648. Division
truncates; A ÷ 0 gives 0 and A; a zero remainder is not put out. A^B is
repeated multiplication with the same clamp; A^0 = 1 (0^0 too); a negative
power is 0 unless the base is 1 or −1.

**The paper**: 46 by 46 squares, the box at the middle. The digs' numbers
are printed by the save's seed, the small ones close: six 1s within 3 to 6
squares of the box, then 2, 3 ... 9, then 11 to 60, each further out (the
table in `Sim.DEPOSITS`). There is no 10. A number may be dug from the level
the ladder says.

## 3. The ladder and the upgrades

**The box** (counts are the reference's halved to suit a phone, targets
drawn per save in a band round the reference's sample save):

| Level | Target | Count | Reward |
|---|---|---|---|
| 1 | 1 | 10 | Adder |
| 2 | 2 | 15 | |
| 3 | 3 | 20 | dig 2 |
| 4 | 5 | 25 | Bridge |
| 5 | 10 | 30 | dig 3 |
| 6 | ~19 | 50 | dig 4 |
| 7 | ~27 | 75 | Multiplier |
| 8 | ~36 | 120 | dig 5 |
| 9 | ~47 | 160 | dig 6 |
| 10 | ~50 | 200 | |
| 11 | ~82 | 250 | dig 7 |
| 12 | ~174 | 300 | dig 8 |
| 13 | ~248 | 400 | Subtractor |
| 14 | ~324 | 500 | dig 9 |
| 15 | ~466 | 650 | dig 11 |
| 16 | ~594 | 800 | Divider |
| 17 | ~631 | 900 | dig 12 |
| 18 | ~727 | 1,000 | dig 13 |
| 19 | ~891 | 1,100 | Raiser |
| 20 | ~928 | 1,200 | dig 14 |
| 21 | ~1,779 | 1,300 | dig 15 |
| 22 | ~2,805 | 1,400 | Crate |
| 23+ | the last × 1.03 to 1.15, slower past 10^6, never past 10^8 | +100 a level to 2,500 | dig (level − 7) to 60 |

The target band is ±12% on the sample from level 6 to 40; past 40 each
level is the last times a factor drawn from 1.03 to 1.15 (a mean near the
reference's 8.7%), the factor's growth halved past a million.

**Upgrades** are paid in delivered numbers. The box keeps one tally a
number; a level counts its target as it comes and the tally keeps it too,
so the same number may be a level's and an upgrade's. Six tracks, each rank
asking for up to three numbers in counts: the first rank one number, the
second two, from the third a window of three sliding along the track's own
sequence (the oldest dropped, the counts rising). Buying spends the counts;
what is left over is kept.

| Track | Level 1 | Steps | Top |
|---|---|---|---|
| Belt | 1 square/s | +1 to 8, then +0.1 | 20 at 128 |
| Dig | 1 belt | +1 | 4 (a square has four sides) |
| Adder | 0.25/s | 0.333, 0.4, 0.5, 0.667, 1, 1.5, 2, then +0.02 | 4 at 108 |
| Multiplier | 0.2/s | +0.1 to 0.8, 1 at 8, then +0.02 | 3 at 108 |
| Subtractor and divider | the same | | 3 at 108 |
| Raiser | the same | | 3 at 108 |

A track opens with its machine. The numbers a track asks for are its own
sequence, drawn per save near the magnitudes of the reference's wiki table
(belt 1, 16, 22, 34, 121, 247, 562, 854, ...); the counts are a fifth of the
reference's.

## 4. The screen

The paper fills the screen (the rule since 2026-10-10); over it the flat
boards' top bar, a plate row and a tray.

- **The plate row**: the box's goal (the target large, "12 / 30" and a bar,
  the level), and the upgrades' button with a dot when a rank can be bought.
  The goal plate opens the box's card (the next five targets, what the next
  levels give, the tally of what has come in).
- **The tray**, two rows of five: Move, Belt, Dig, Crate, Remove; Adder,
  Multiplier, Subtractor, Divider, Raiser. A piece not yet given is a lock
  with its level.
- **Fingers**: two fingers pan and pinch everywhere. With Move one finger
  pans and a tap on a piece opens its card (what it holds, turn, remove).
  With Belt a swipe lays a straight run in the way of the swipe, shown as a
  ghost until the finger lifts; a tap lays one belt or turns the one under
  it. With a machine a tap places it facing the way last chosen, a tap on
  the same machine turns it, a drag pans. With Remove a swipe lifts what it
  crosses.
- A token is a cream wooden disc with its number in ink; a number past four
  figures is shortened (12.4k, 3.1M).

## 5. Moments, sound and feel

Every touch that changes something is heard and felt. The sounds are the
three measured takes Griddle and Trivet are made of (the light button on
felt, the hollow block, one muffled kalimba note): no new take.

| Cue | When |
|---|---|
| `lay` | a belt square laid (a run ticks a square at a time, quickly) |
| `place` | a machine, dig or crate set down |
| `turn` | a piece turned |
| `lift` | a piece removed |
| `deliver` | a target token into the box (throttled, quiet) |
| `level` | a level done |
| `unlock` | a piece or a number handed over |
| `upgrade` | an upgrade bought |
| `ready` | an upgrade becomes affordable |
| `nope` | a place refused |
| `start` | the paper opened |

A level fills the box with a ring and confetti, the new target rolls in, a
new piece hops into the tray; a machine squashes as it works; tokens slide,
never step; the hub's count bumps. `Motion.reduce` stills all but the words.

## 6. Calls that are mine, the user's to change

1. **The name** Tally and the squared paper, wooden tokens and walnut belts.
2. **Every piece one square**, the operator's sides A left, B right.
3. **A 4×4 box** with 16 sides, a 46×46 paper, values to 60.
4. **Dig level tops at 4.**
5. **Counts halved** for the levels, a fifth for upgrades.
6. **No away progress.**
7. **No priorities, copy, paste, undo, markers.**
8. **Straight runs only**, as the Factory's belt.
9. **A crate of 500**, not 10,000.
10. **No concept tab** (the user said "do it autonomous") and no new sound
    take.
11. **No mascot**: the numbers are marks.
