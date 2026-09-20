# Bridges, flat: a screen for a grid that has run out of slots

Hashiwokakero, themed as islets in a river joined by plank bridges. Twelve
flat boards stand on the first screen and every slot is taken, so section 2
is about where this one goes rather than which cell it takes; it was designed
on 2026-09-20 alongside two other boards with the same problem.

**It is called Bridges and nothing else**, in code, in a comment or on
screen. Hashiwokakero is Nikoli's name for it and the reference the design
came from ships it as "Metrô"; neither belongs in this repo. This is the
fourth time the repo has renamed a game it did not invent (Code Break,
Hidden Word, Word Trail), and the rule those three set holds here: the
original name is recorded once, in this paragraph, in order to forbid it.

The playable mock is `docs/brainstorm/concepts.html#bridges`, built before
this spec as the house order requires. **Every measurement below is ported
from that mock**, which is the reference for the build; where a figure came
from the mock's JavaScript rather than from Godot, this document says so,
because a JS timing is not a GDScript timing.

## 1. What is built

A lattice of water cells with islets standing on some of them, each islet
showing a number. A **run** is the 0 to 3 planks laid in the straight lane
between two islets that face each other orthogonally across open water.

The rules, and there are only four:

- A run is orthogonal only, and at most three planks join the same pair.
- Runs may not cross. A lane ends at the first islet it meets, so a run can
  never pass over an islet.
- Every islet must end with exactly its number of plank-ends.
- Every islet must end in **one single network**.

The fourth rule is the puzzle. Without it most boards have several legal
fillings and no generator can promise one answer; with it, the position the
player spends the last third of the board in -- every number met, the islets
in two separate rings -- is the thing being solved. The reference's own rules
card does not state it. This one does, in `rules()` and on the tip card.

## 2. Where it stands on the first screen

The grid is twelve cards, three across and four down, and all twelve are
live. On the day this was designed two other boards were in flight on their
own branches, each adding a thirteenth card and **each having independently
built a pager in `ui/menu.gd`** to make room for it. This board is the third
in that queue and does not touch `ui/menu.gd` at all: it adds a registry
entry and a card picture, and whichever pager merges first carries it.

That is a deliberate narrowing, and it has a sharper cost than this spec
first claimed. The original wording here said the card simply would not
appear on a full grid. **That was wrong, and the build proved it wrong.**
`ui/menu.gd:139` loops `for i in Registry.PUZZLES.size()` into a 3-column
grid with no cap of any kind, so a thirteenth entry *does* get a card, the
grid becomes five rows, and **the bottom bar is pushed off the bottom of the
screen**. The menu shot drops from 322 draw calls to 313, and the nine
missing calls are the bar leaving, not a saving.

So the constraint is not "the card is invisible until a pager lands", it is
**this branch cannot merge to `main` before a pager does**. That is a merge
ordering requirement, not a defect in this board: nothing here is wrong, and
the moment a pager is in front of it the card takes its slot. It is written
down in this paragraph because the symptom -- a first screen with no bottom
bar -- looks nothing like its cause, and the next person to see it will not
guess that a registry entry three files away did it.

The card picture is drawn and verified on its own (section 11); its
draw-call contribution to a full page is not, and cannot be until a pager
lands.

`ui/registry.gd` gains one `PUZZLES` entry:

```
"id": "bridges", "kind": "puzzle", "title": "Bridges",
"blurb": "Plank every islet to its number, and join them all.",
"short": "Plank every islet\nto its number.",
"motto": "Join every islet",
"footer": "Link · Count · Cross",
"script": "res://puzzles/bridges2d.gd",
"shell": "flat", "tray": "none", "difficulties": [0, 1, 2],
```

No `seed_as`: this board shadows no island. It picks nothing up, so it asks
for no tray; it has a real Check, so unlike Balance and Untangle it keeps the
actions row. `Bridges` at GameWordmark 84 is far inside the four-button 496
block, so `_fit_title` leaves both the title and the 16-character motto
alone -- this is not one of the four labels that get lettered smaller.

## 3. The state is the one truth

`puzzles/bridges_state.gd`, a scene-free `RefCounted`, as every flat board's
rules are. It holds the lattice size, the islets and their numbers, the
answer's runs, the player's runs, and the history. The board
(`puzzles/bridges2d.gd`) only draws it.

What it exposes, and nothing more -- this is the surface as built, and the
board is written against it: `build(rng, difficulty)`; `lane_at(a, b)` and
`facing(cell, dir)` for finding the lane a gesture means; `blocked_by(key)`;
`cycle(key)`, which advances a run 0→1→2→3→0 and is the only way a plank is
laid; `clear_run(key)`; `undo()`; `reset_board()`; `hint()`; `wrong_runs()`;
`degree(cell)`; `groups()`; `is_solved()`; and `share_glyphs()`. Runs are
keyed by lane, `"x,y|x,y"` with the two cells sorted, so the end a gesture
starts from never matters.

**A run is wrong when it carries *more* planks than the answer lays there**,
including a run on a lane the answer never names. An under-laid run is
unfinished, not wrong. The distinction is not pedantry: marking every
under-laid lane would print the answer, which is exactly what section 10
says this screen does not do. It also matches the house convention that
`nonogram_state.wrong_tiles` and `lightup_state.wrong_lamps` already set.

Two things are **derived and never stored**, which is Queens' rule and the
reason undo needs no bookkeeping for them: an islet's current degree, summed
from its runs, and the network's connected groups, flooded from the runs on
demand. Storing either would mean a second truth to keep in step, and undo
would have to unwind it.

`is_solved()` is the conjunction and never one half of it: every islet's
degree equals its number **and** one flood from any islet reaches them all.

## 4. Generation: grow the answer, then prove it unique

`puzzles/bridges_gen.gd`. The generator does not search for a puzzle; it
grows an answer and then proves the clues admit only that answer.

1. **Grow.** Place one islet at random. Repeatedly pick an existing islet, a
   free direction, a distance up to the band's max span, and a run of one to
   three planks; refuse anything that crosses a laid run, lands on or passes
   over a taken cell, or pushes either degree past 6. Stop at the band's
   islet count. The network is connected by construction, so rule four is
   satisfied by the answer before anything is checked.
2. **Close some loops.** The grow step lays exactly one run per new islet, so
   on its own it can only ever build a **tree** -- and on a tree the
   connectivity rule never bites and no lane is ever a decoy. A second pass
   joins a few pairs that already face each other. It is bounded by the
   degree cap rather than by the number asked for: past a point, asking for
   more loops changes nothing.
3. **Centre and reach.** The walk wanders, so a raw board sits in a corner
   with two empty rows. The islets are slid so their bounding box is centred,
   which changes no lane, no crossing and no answer, and the board is
   rejected unless that box comes within one row *and* one column of the
   lattice edge.
4. **Clues.** Each islet's degree is its number. The cap is **6**, not the 8
   the original game allows. Six keeps growth tractable and every number
   inside one glyph; the cost, stated because it is real, is that an 8 --
   all four lanes nearly full, the best free opening clue a Hashi board has
   -- never appears on this screen.
5. **Prove it.** A solver runs range propagation over every lane (each pair's
   `lo..hi` narrowed by each islet's remaining need, its still-open
   directions, and the lanes a laid run now blocks), plus **the group rule**,
   which has two halves and needs both. Flood the islets over the lanes that
   must carry at least one plank; if that leaves more than one group, then a
   group with **no** way out still open is a contradiction, and a group with
   **exactly one** way out must take it. The first half is the connectivity
   rule as most people state it; **the second half is what pins lanes without
   a guess**, and dropping it moves the guess-free rates off 100/81/69 by a
   wide margin. Then a DFS counts answers and **stops at two**. A board with a
   second answer is thrown away and the grow restarts.
6. **Grade.** The generator records how far pure propagation gets before the
   first guess. **Band 0 must need no guess at all**; the other two may.

### The bands

| Band | Lattice | Islets | Max span | Loop pass | Guess-free |
|---|---|---|---|---|---|
| 0 | 7x7 | 11 | 5 | 4 | required |
| 1 | 9x9 | 16 | 5 | 6 | not required |
| 2 | 11x11 | 24 | 5 | 10 | not required |

Eleven islets on the 7x7 and not ten: at ten, a board averaged 0.7 decoy
lanes and 0.6 crossing pairs, so **the no-crossing rule effectively never
appeared on the easy band**; eleven gives 1.0 and 1.0 for a tenth of an
attempt more. Even at eleven the crossing rule shows up about once a board,
which is thin -- see section 15.

Max span stays at 5. Shortening it to 3 to pack the board tighter was
measured and is the wrong lever: it made boards no denser in decoys (1.3
against 1.1) and cost the hard band 70 attempts and 41 ms against 7.3 and
5.9. The lever that works on density is the islet count.

### What the mock measured

500 seeds a band, in the mock's JavaScript, on this Mac:

| Band | Attempts | Rejected for a 2nd answer | No guess needed | Lanes pinned by propagation | Generate |
|---|---|---|---|---|---|
| 7x7 | 3.0 mean, 13 worst | 54% | 100% (required) | 100% | 0.41 ms mean, 5.3 ms worst |
| 9x9 | 3.9 mean, 19 worst | 70% | 82% | 94% | 0.33 ms mean, 2.1 ms worst |
| 11x11 | 6.8 mean, 47 worst | 82% | 71% | 87% | 0.93 ms mean, 7.0 ms worst |

**The port then reproduced them**, which is the reason this table is left
standing rather than replaced. 200 boards a band in GDScript, two sequential
readings: attempts 3.26 / 4.14 / 6.71 mean and 19 / 20 / 53 worst against the
mock's 3.0 / 3.9 / 6.8 and 13 / 19 / 47; second answers rejected on 53% / 72%
/ 84% against 54% / 70% / 82%; guess-free on 100% / 81% / 68.5% against 100%
/ 82% / 71%. Every figure within two points of a different language's
implementation of the same rules, which is a stronger statement about the
solver than either run alone. **Worst case 14.4 / 13.9 / 56.7 ms against the
194 ms gate** -- 3.4x of headroom on the hard band. The port's solver was
also cross-checked the way the mock's was, against an independent counter
with no propagation and no group rule, on 102 boards: 0 mismatches.

The uniqueness claim is **cross-checked rather than asserted**: on 380 boards
an independent counter -- a plain DFS over every lane with no propagation and
no connectivity pruning -- agreed with the solver's count every time, 0
mismatches, and the grown answer verified legal on all 380.

**These are JavaScript figures and the port's budget is a GDScript one.** The
honest reading is that there is roughly twenty times headroom against the
~194 ms the Sudoku generator was gated at, and that **the number to watch in
the port is attempts, not milliseconds**: the worst case is 47 attempts on
the hard band, and it is the retry loop, not the solver, that will decide
whether this fits. The port's own timing is measured in section 14 and this
paragraph is not a substitute for it.

## 5. The finger

Press an islet and drag toward a neighbour. The drag takes its dominant axis
and lights the lane to the first islet that way, so the player sees what they
are about to join before they let go. Release on it and the run cycles
**0→1→2→3→0**. A tap on the water of an existing run wipes that run to 0 in
one go.

Two gestures are refused, and a refusal flashes the lane and puts the broken
rule on the tip card, which is the tip card's established job on these
screens:

- a drag with no islet facing it that way ("Nothing faces it across the
  water.");
- a drag whose lane is already crossed by another run ("Another run crosses
  that lane.").

An islet pushed **over** its number is not refused. It is drawn wrong -- a
`BAD` ring, its turf washed out, one shiver -- and the player fixes it. That
is the house rule that feedback beats a mode: nothing on these boards stops a
finger from making a mistake it can see.

The cycle wrapping at 3 means clearing a full run takes three drags, with
tap-to-wipe as the shortcut. **Nothing on screen teaches the tap**, and that
is carried as an open call in section 15 rather than solved here.

## 6. The screen, measured

At 1080x1920 design space, top to bottom: 40 margin, a 180 top bar, 20, the
120 day card, 20, the **1190 board card**, 20, the 130 actions row, 20, the
140 tip card, 40. That is 1920 exactly, and a **290 bottom slot** -- the same
shape as Shikaku, Tents, Light Up and One Line, so `ui/flat/flat_host.gd`
needs no change at all.

Inside the card, a sea pool inset 28 from the paper. The lattice is **920
wide at every band**, so the width binds and a cell is **131 / 102 / 84** on
the three bands. That leaves 214 of pool height over, and because the lattice
is square in a tall slot, `card_centred()` is `true` and the slack is
**halved: 107 above and 107 below**.

An islet is a turf disc on a sand rim with its number in ink. A plank is
**0.115 of a cell thick with 0.095 between two of them**, so a full run of
three spans 0.59 of a cell -- wide enough to read as three at 84 px and
narrow enough to leave water either side.

## 7. Colour

This is the first flat board whose field is not paper, and the sea was
re-pitched once before this spec was written: the first cut used `WATER`
straight and read as the loudest surface in the game. Every value below is a
**mix of exactly two `core/palette.gd` entries**; nothing here is invented
and nothing was added to the palette.

| Surface | Value | Mix |
|---|---|---|
| Open water | `#a4cde6` | `mix(WATER_HI, PAPER, 0.46)` |
| Shallows | `#cfdfe4` | `mix(WATER_HI, PAPER, 0.74)` |
| Pool edge | `#5896c2` | `mix(WATER_HI, TEXT, 0.20)` |
| Islet shadow | `#336e99` at 0.30 | `mix(WATER, TEXT, 0.35)` |
| Ripples | at 0.24 | `WATER` straight |

Letting `WATER_HI` down into **`PAPER`** rather than into `SKY_TOP` or
`SURFACE` is what carries the warmth: the paper's red comes up as the blue
comes down, so the result is a warm pale blue rather than a cool sky one,
which is what `docs/art/shading-direction.md` asks for.

Two things invert on a pale ground, and both are counter-intuitive enough to
be worth writing down: **the ripples are darker than the water they lie on**
(`WATER_HI` strokes vanished, so the old sea's blue became the new sea's
mark), and **the shallow band is paler than the open water**, not deeper.

The islets: turf is `BANK`, and the beach around it is **`ACORN`** with
`mix(ACORN, TEXT, 0.22)` offset down 0.07R for the wet sand at the
waterline. The beach was `STONE` in the first cut and **the islets stopped
reading entirely** -- `STONE` is value 237 against a 230 sea, seven points
apart, so the rim disappeared. `ACORN` sits 29 of value below the water and
warm against a cool ground. It is far enough from `DECK` that a beach and a
plank never read as the same material.

### Warm ink on the sea

The first cut needed a special case -- `BAD` at any alpha over deep `WATER`
came back mauve, so the refusal band had to be drawn opaque and dissolved by
mixing toward the water. **The pale sea deletes that special case**: the
refusal band is now plain `BAD` at a fading alpha, and so is the blocker
highlight.

The rest of the warm ink moved the other way, because the problem flipped
from "too weak against dark" to "too pale against light":

| Ink | Was | Is |
|---|---|---|
| Refusal band | opaque `BAD`, dissolved by a mix | `BAD` at a fading alpha to 0.88 |
| Drag beam | `SUN_RAY` at 0.78 | `SUN` at 0.72 |
| Hint glow | `SUN_RAY` at 0.70 | `SUN_RAY` at 0.85 |
| Answer dashes (`?peek`) | white at 0.30 | `TEXT` at 0.34 |
| Turf sun cap | `mix(BANK, #ffffff, 0.26)` | `mix(BANK, SURFACE, 0.26)` |

The solve wave's gold (`mix(DECK, SUN_RAY, 0.72)`) and the `GOOD` satisfied
ring are **unchanged**: both read better against the pale sea than they did
against the dark one.

**The rule this screen owns, and the reason the table above records both
columns: a warm-ink alpha tuned against a dark ground is not portable to a
light one, in either direction.** Three of the five re-tunes above were
reversals rather than adjustments. Any alpha fixed as a constant on this
board must say which ground it was measured on.

## 8. The cast: nobody new

**This board adds nothing to `ui/faces/`**, which makes it the fourth in a
row to add nothing (Nonogram, Hidden Word, Word Trail). Its islets are drawn
shapes rather than characters -- a disc, a rim, a number -- and the only face
on the screen is the shared sprout on the tip card. Check `ui/faces/` before
drawing a character was the rule; here nothing on the board is a character in
the first place, so there is nothing to check for.

The drawing follows Word Trail's arrangement exactly: **one `ArrayMesh`** for
the sea, the ripples, the islets, the runs and the hint glow, with the
numbers as `draw_string` commands over the top, because a glyph in a mesh
cache key multiplies every state by ten. And with it comes Word Trail's
hard-won rule -- **a canvas command holds a mesh by RID, not by reference** --
so the board keeps the mesh its last `_draw` handed over in `_shown` until
the next one replaces it, or a harness's `force_draw()` will photograph a
freed RID.

## 9. Motion

Everything comes from `core/motion.gd`'s vocabulary and
`docs/art/flat-motion.md`; the board's own constants are only the two the
wave needs. A plank drops in; an islet that has just met its number bumps and
takes its ring; a refusal flashes the lane; entrance and reset are the
recipes' own.

**The signature is the network wave.** When the board is solved, light runs
outward along the planks from the islet the player finished at, in breadth
-first order over the network, one step per run: the front crosses a run in
`WAVE_EDGE`, planks behind it wear a lit deck, and each islet flares, bumps
and sparkles as the front arrives. The network the player built is the wave's
own graph, which is why this board could not borrow another's solve -- the
shape of the animation is the shape of the answer.

Reduce motion stills it as it stills every other board: the lit state is
applied at once and no front travels.

## 10. The hint, the check, and the silence

Three hints. A hint lays **one plank the answer has and the board lacks** --
never an overshoot, so a hint can never be the thing that pushes an islet
over. It walks the answer's lanes in sorted order, so the hint a board gives
is stable however that board's answer happened to be grown. One edge case is
worth knowing: when every remaining under-laid lane is crossed by a run the
player laid wrong, the hint lifts that blocker first, which is always safe
because the answer's own runs never cross each other. That lift is its own
history entry, so in that one case a hint costs two undos rather than one.
Verified over 120 boards hinted to completion: 0 overshoots, and every board
finished. Check marks the runs that differ from the answer, costs a check, and is
the board's only door to the one thing it will not tell you.

**The near-miss is unsignposted, deliberately.** When every number is met but
the islets are in two rings, the board says nothing: no group count, no tint,
no line. Seeing the split network is the puzzle, and Check is the door at the
price of a check. This is the same rule Code Break's screen is built on --
the screen never hands over the deduction the player is there to make -- and
it was taken as a decision rather than an oversight.

## 11. The menu card

One branch of `ui/menu/card_art.gd`'s `_build` and one of `_draw`: three
turf islets with their numbers on a small sea panel, two joined by a double
run and one waiting. Drawn furniture, no character, no image, no
`SubViewport` -- the card and the board are the same drawing, as every other
card is.

## 12. What the board says

`rules()` is the four rules of section 1, in that order, connectivity last
and stated plainly. The tip card's resting line is "Press an islet and drag
at the one facing it."; its two refusal lines are in section 5.

`flat_win()` returns `{"faces": [], "subtitle": ...}` -- the no-cast form
Light Up uses. The joined network stays on the card under the win screen,
because the board is the answer and there is nothing better to show.

`share_glyphs()` takes Shikaku's one-line form rather than Light Up's grid:
an 11x11 emoji lattice would be mostly blank water. One line with the
lattice, the islet count and the planks laid.

## 13. Analytics

Nothing new. `puzzle_start`, `puzzle_complete` with `solved: true`,
`puzzle_abandon`, `hint_used`, `check_used`, `undo_used`, `board_reset`,
`rules_opened` -- all from the host, all carrying this board's `puzzle_id`.
This board cannot end without a solve, so it never sends `solved: false`.

## 14. Calls this screen is for

To be filled from the port: draw calls and idle at `--resolution 810x1440`
with `tests/_shot_anim.gd -- bridges`, against the 855 budget, with another
board run as a control in the same session -- because a single reading off
that harness is worth nothing, and every reading gets quoted including the
flattering one. Generation time per band in GDScript, against the ~194 ms
gate, with the attempt counts beside it. And the `--rendering-driver
opengl3_angle` check that nothing has reintroduced an `instance uniform`.

## 15. Open calls carried from the concept build

Five, none of them blocking, all measured or argued rather than guessed:

1. **An easy board is mostly open water.** Eleven islets on a 7x7 with a
   reach test still leaves a hollow middle. It is what this puzzle looks
   like, but it may read as under-filled on a phone, and the only lever that
   moves it is the islet count.
2. **The crossing rule barely appears on the easy band** -- about one
   crossing pair a board. That band may never teach its own hardest rule.
3. **Closed, and recorded rather than dropped.** The first cut's sea forced
   warm ink to be drawn opaque over water -- `BAD` came back a bruise, the
   drag beam olive. The colour pass removed the cause, and no warm ink on
   this board is drawn opaque any more. What survives the fix is the rule at
   the end of section 7, which is the general lesson and not this board's
   accident.
4. **Nothing teaches tap-to-wipe** (section 5).
5. **No user mock exists for this board.** The layout is a proposal read off
   the other flat screens' chrome, not a reading of anyone's drawing. Every
   other flat board was ported from a mock the user had seen; this one
   inverts that order, and section 6's numbers should be treated as a first
   pitch rather than a settled composition.
