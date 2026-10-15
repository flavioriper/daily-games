# Tally: the builder's hand and the upgrades tree

2026-10-15. Follows `2026-10-15-arcade-tally-design.md` (the game as built)
and changes its section 4 (the screen) and the upgrades card. The user's
word, with a phone screenshot of level 2: "I upgraded convey and numbers
stopped, also I want a full polish and redesign about the game, it's too
hard to deal with the conveys since clicking on board place it auto or
rotate it, we need some builder view ... check how those games does on
mobile using web. Also, i want better upgrade sheets, something more tree
view, nicer to look into, something clean but elegant, hand polished for
the best experience".

## 1. What stopped the numbers

Headless, the belt upgrade changes nothing: a dig, a belt and the box make
ten a second at rank 1 and nineteen in ten seconds at rank 2, and keep
making them through a save and a load. The screenshot's loop stops because
the adder's two-pip side (B) is empty: its A queue holds four 1s and it
waits. Four 2s had reached the box, so B was fed once; on the board as
built, two things empty a side without a word: a run of belt drawn across a
belt before bridges are had (level 5) turns that belt to the run's way, and
a tap on an operator with Belt or its own tool in hand turns it. Both are
the complaint ("clicking on board place it auto or rotate it"), and the
game says nothing when a machine starves. Three rules come out of it:

- a drawn path never rewrites a belt it crosses;
- a tap never turns or places anything by itself;
- a machine waiting on one side says so.

## 2. What the mobile games do (research, 2026-10-15)

`scratchpad/touch-builder-research.md` (the session's, not in the repo):
Mindustry's `MobileInput.java`, Builderment's changelog and reviews,
shapez mobile's version history, Assembly Line, Mini Motorways, and the
reference game's own forum. The findings that hold across all of them:

- **No tool held: one finger pans and a tap on the board never builds.
  Tool held: one finger builds, two fingers pan**, the finger near the edge
  pans the view.
- **A belt's direction is the drag order**, never "tap again to turn".
  Turning after the fact is a selection action or a button on a ghost.
- **A machine goes down as a ghost** with a rotate button and a confirm
  (Mindustry added it because a direct commit put lines a tile off "with no
  way to immediately prevent or undo").
- **Deleting is its own tool**, tap one or drag many; tap-each-segment is
  the universal complaint.
- The reference game's players: "I always end up creating junctions I
  don't want to because I drift out of the line I started in"; no undo for
  a wrong delete.

Taken: path drawing with a ghost and commit on release, an undo chip after
(Builderment, Mini Motorways); ghost, turn and confirm for pieces
(Mindustry); the pan rule everywhere.

## 3. The hand

The tray keeps two rows of five: **Look**, Belt, Dig, Crate, Remove; Adder,
Multiplier, Subtractor, Divider, Raiser. Pressing the held tool again puts
it down (Look). A held tool wears the sun ring. A machine's tool pressed
again no longer turns anything.

**Two fingers pan and pinch whatever is held.** The wheel zooms on a desk.

### Look (nothing held)

One finger pans with a fling. A tap:

- on a piece (a belt, bridge, dig, crate, machine): the **piece pill**
  floats by the square, Turn (belts and machines; a bridge has none),
  Remove, Info (opens the piece's card as today). The square wears a sun
  ring while the pill is up. A tap anywhere else closes it. Nothing changes
  without a pill button.
- on the box: the box's card.
- on a printed number: the "dig it" sticker as today.
- on bare paper: the touch sound.

### Belt

One finger **traces a path**: the squares under the finger's way,
4-connected (between two samples the path steps the larger axis first,
then the other), a step back onto the previous square takes it off the
path. The path shows as a ghost as it goes: green where it can be laid,
red from the first square it cannot, and it is cut there. On release each
square faces the next; the last faces as the one before it (a path of one
square faces the way of the last trace). Begun on a dig, a machine, a
crate or the box, the first square is dropped and the path starts beside
it; ended on one, that square is dropped and the square before faces into
it.

**Crossing**: a belt across the path's way in its middle becomes a bridge
when bridges are had, and otherwise cuts the path there (red); it is
never turned. A belt along the path's way takes the path's face (so a line
can be extended or reversed by drawing over it). At the path's ends a
belt across the way is left as it is and the path stops beside it.

A **tap** (no movement) on bare paper lays one belt facing the way of the
last trace and opens the piece pill over it, so a wrong one is turned or
taken in one more tap. A tap on a piece opens its pill.

Near the view's edge while tracing, the view moves (as today).

### Dig, Crate and the five machines

A tap drops a **ghost** of the piece on the square, snapped, with the
**builder pill** beside it: Turn (machines only), Place (check), Cancel
(cross). The ghost is green where the piece can go and red where it
cannot (Place is then dim and does nothing; the refusal sticker says
why on a press). Dragging from the ghost moves it square by square;
dragging elsewhere pans; a tap on another square moves the ghost there.
Place sets it down facing the ghost's way, keeps the tool in hand and
clears the ghost. A tap on a standing piece opens the piece pill (never
turns it). A tap on a machine with another machine's tool shows the
ghost of the swap on it, placed in the old one's facing.

### Remove

A tap lifts one piece; a drag lifts what the finger crosses (as today).

### Undo

After a path is laid, a tap-laid belt, a lift or a swipe of lifts, an
**undo chip** (a round paper button with `undo_back`) rests at the
tray's top-left for six seconds; it puts back exactly what that one
gesture changed (kinds and faces of the squares touched; tokens riding
there fall off; a crate's contents are not kept). One step only.

### The pills

The pills are the board's, drawn in screen space over the paper and hit
by the board's own press and release (the tutorial's scripted finger and
the harness press them through `press`/`release`), not Controls. A pill
is a paper capsule (`CozyTheme.lifted`) of round buttons 84 px, icons
from `ui/icons.gd` (`turn`, `check`, `cross`, `bin`, `help`), labels
under them at 20 px, placed under the square and over it when the square
is in the lower third of the view, clamped inside the view. Every button
is heard (`touch`) and felt (tap). Opening a pill is `touch`.

## 4. The machines say what they wait for

`Sim.starving(i)` is 0 for A, 1 for B or -1: the side whose queue has been
empty for `STARVE_AFTER` (3 s) while the other side holds at least one
token and the machine is idle. The board draws the starving side's pips
in amber with a slow pulse ring, and the piece's card and pill title say
"Waiting for B". A level with twenty or more numbers into the box that
are not the target while none of the target came says once, over the
box: "The box wants 2s now, the 1s don't count" (`TL_SAY_NOT_TARGET`).

## 5. The upgrades tree

A card over the whole screen in the Grove's skill-tree manner
(`git show 65ad7b2b:valley/grove_tree.gd`: a head with a round X, a
field that pans up and down under a finger, node plates, a foot card with
one sun bar that buys), redrawn in Tally's materials.

**The tree**: the counting box at the root along the foot of the field
(its teal chest, small), a trunk of pencil line up the middle on squared
paper, and the six tracks as boughs in the order they open, alternating
sides:

| Row (from the root) | Left | Right |
|---|---|---|
| 1 | Belts | Digs |
| 2 | Adders (level 2) | |
| 3 | | Multipliers (level 8) |
| 4 | Subtract and divide (level 14) | |
| 5 | | Raisers (level 20) |

A node is a paper plate 128 px with a soft lift, the track's piece drawn
on it (`Art.icon`), a brass rank chip on its top-right corner ("Lv 3"),
and a thin ring round the plate in three (or one, or two) segments, one
per number the next rank asks, filled green where met. A node whose rank
can be bought wears the sun dot the HUD's button wears. A track not open
is dim behind a pencil-dashed bough with a lock and "Lv 8" under it. A
track at its top wears a small crown. The pencil boughs join the trunk
with a round joint; a bough opened is drawn in ink, one not yet in dashed
pencil.

**The foot card**: the chosen node's name, its line ("Level 3 · 3/s →
4/s"), the next rank's asks as tokens with the number and "have / need"
under each, a thin bar under each filled to have/need, green when met;
under them, dim, "Then" and the rank after's numbers with their counts,
so the player sees the ladder; and the sun bar, "Up", which buys when all
are met and otherwise says what is short ("Need 24 more 16s"). Buying
squashes the node, refills the ring, moves the "then" row up and writes
the sticker the screen already has. Nothing else here is a Button.

Belts and Digs are chosen first when the card opens (whichever can be
bought first, else Belts). The HUD's upgrades button carries a count
badge of ranks that can be bought.

## 6. Tutorial, harness, probe

- The tutorial's pages drive the board through `press`/`drag`/`release`
  as now; page 1 taps the 1 with Dig, then taps Place on the pill, then
  traces to the box; page 3 drops the adder's ghost, turns it once and
  places it; page 4's split, merge and bridge are traces. Page bodies say
  "Drag to draw a belt" and "Tap Place".
- `tests/_shot_tally.gd`: the Dig tap is followed by a tap on Place; the
  belt swipe becomes a traced path with a corner where the route turns;
  the Move tap on the adder opens the pill and a tap on Info the card; the
  upgrades shot shows the tree and a bought rank.
- `tests/_probe_tally.gd` adds: a traced path with a corner faces each
  square to the next; a path across a belt before level 5 stops before
  it and never turns it; after level 5 it bridges; a path along a belt
  reverses it; undo puts a path back; a one-sided adder makes nothing and
  `starving` names B.

## 7. Calls that are mine, the user's to change

1. A tap with Belt lays one belt and opens its pill (not nothing, not a
   turn).
2. One undo step, six seconds, for belts and lifts only (not for a placed
   machine: it has Cancel before and Remove after).
3. The tree's shape: six boughs alternating by unlock order, the box at
   the root; no rank-by-rank chain drawn (ranks reach 108).
4. Pills under the square, over it in the lower third; 84 px buttons.
5. Starving after 3 s; the "don't count" hint after 20 non-targets.
6. The tray keeps two rows of five; "Move" is renamed Look (id `move`
   kept in code and saves).
7. No double-tap path selection, no drag-box delete, no copy or paste.
