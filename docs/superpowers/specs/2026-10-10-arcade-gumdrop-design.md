# Gumdrop, the Arcade tab's eleventh game

2026-10-10. Built in one sitting while the user was away, from their brief
over a screenshot of the reference running in a browser: "is the next
arcade game to be created, check rules on web, wire everything even sound,
do autonomous, no questions". No concept tab came first: nobody was there
to judge one, so it went spec to Godot as the other unattended builds have,
and every call below that the brief did not make is listed in section 8 as
mine.

## 1. Where it lives

On the **Arcade tab**, the eleventh card, after Eddy
(`ui/menu/arcade_tab.gd`, `ui/menu.gd`'s `_open_arcade`). A run played alone
for a score, with the Arcade's boosters, Second chance, gold and end card.

## 2. The game

**It is called Gumdrop and nothing else**, in code, in a comment, in a
sound prompt, in a commit or on screen. The reference is Egor Davydov's
browser and phone game *Jelly Dye*, named here once to forbid it. What the
web gave of it (its portal page, its store listing, a search of its
write-ups, and its own screen as the user's screenshot and one load of the
portal show it; the one strategy guide refused the fetch, and **the game
could not be played from here**: its keys went to the page around it):

- A dark tray holds a clear jelly in a mould whose shape is cut up by
  walls. A small card over it shows the jelly as it is wanted.
- Pots of colour stand under the tray. One is touched to pick it, a syringe
  is dragged about, and a button held injects from its tip.
- The colour "flows and blends"; the guides warn of overflows and say to
  look at the picture first, and that the nearer the picture the better
  the score. No timer.
- Levels follow one another; new syringes unlock, which are looks.

What was kept is that skeleton: a walled mould, a card, pots, a dropper
moved by a finger and squeezed by a held button, colour that spreads and
runs over, and a verdict by how near the card it is. What the reference
has not got and an Arcade run needs is an end and a score, and those are
mine (section 4).

## 3. The syrup

*(As built on 2026-10-10. Section 9 replaces the depth, the sills and the
pots' slack as of 2026-10-11.)*

`arcade/gumdrop_sim.gd`, pure data, stepped at 1/60 s. The mould is a
square of 100 units and a grid of 36 by 36 squares lies over it. Each
square holds a depth of red, yellow and blue pigment.

- **Syrup runs from a deeper square to a shallower one beside it** and
  carries its colour: 0.22 of the difference a pass, no more than a fifth
  of what the square holds, two passes a step. Nothing is moved by rule.
  So it piles up under the dropper while it is squeezed and spreads after.
- **A wall is a sill between two squares**, one depth high between two
  cells and 1.15 between a cell and the tray. Syrup crosses only where it
  stands higher than the sill. So a cell squeezed from its middle fills
  evenly and one squeezed beside a wall spills while it is half empty; a
  small cell wants it a little at a time.
- **Two colours level with each other go on blending** (`BLEND`), so two
  pigments squeezed into one cell become the flavour between them.
- **The dropper** pours 48 squares a second into the squares within 1.6 of
  its tip that are in the tip's own cell.

**Six flavours**: cherry, lemon and blueberry are the three pigments;
orange, lime and grape are two of them half and half. All three together
are mud.

**A mould** (`arcade/gumdrop_mould.gd`) is an outline (round, egg, heart,
drop, two flowers, a clover, a star) cut one of three ways: into sectors
about a point inside it, into a core and sectors round it, or into bands
straight across. Twenty-four designs, easiest first, two cells to eight; a
level draws from three about its place in the list. A wall is 5 units wide.
From 2 flavours (levels 1 and 2) to 3 (to level 6) to 4. **From level 5 one
flavour on the card has no pot**: it is an odd one, and only the two
pigments beside it are stood by the tray.

**The pots** hold what the mould wants of each and a slack over it: 1.6
times at level 1, 0.04 less a level, never under 1.2.

## 4. The run

*(The judge, the tray's cost, the self-serving mould and the set cells
changed on 2026-10-11: section 9.)*

Mould after mould, no clock. **Serve** judges the mould after 0.7 s of
settling: each cell is how full it is (a mean depth of 0.85 is full) times
how near its flavour (half the summed difference of the pigments' shares,
1.5 times over); the cells are weighed by their size; what lies on the tray
is taken off whole. That is the match, 0 to 100.

- **The mark** is 60 at level 1 and 2 more a level, 80 at most. A mould
  served under it ends the run.
- **The score** is the match of every mould served over its mark, and 50
  more for one at 95 or over ("Perfect!"). The mould that ends the run is
  worth nothing. The tab's "furthest" is the most moulds served.
- A mould serves itself 1.6 s after every pot is empty and the syrup still.
- A cell at 0.9 or over "sets": a note, a ring, a few sparks.

## 5. The screen

`arcade/gumdrop_screen.gd`. **The kitchen table is the whole screen**, edge
to edge (CLAUDE.md). On it, top to foot: the card (the picture, and beside
it the match so far and "NEEDS n%"), the tray as big as the room allows,
the pots in a row, and two round buttons: **squeeze**, pink, in the middle
of the foot, and **serve**, gold, to its left (the right thumb hides the
lower right). Over the table lie the top bar and three plates (score, best,
the mould's number).

- **A finger drawn over the tray moves the dropper's tip as far as the
  finger goes**, wherever on the tray it is, so the finger never hides the
  tip. A tap puts the tip under it.
- A pot touched is the flavour in the dropper; it stands in a white ring (a
  ring, never a shade of its own colour).
- The squeeze button pours for as long as it is held. One finger can move
  and another squeeze.
- A served mould shakes as a jelly does, its number is lettered over it,
  and the tray is slid away left and the next in from the right.

Drawn as three Controls: the table, tray and mould's floor; the syrup, the
grid as one 36 by 36 texture through `shaders/gumdrop_syrup_2d.gdshader`
(a four-tap cubic, so no square shows); the walls, card, pots, buttons and
dropper over it.

## 6. The Arcade's kit

- Boosters (`arcade/boosters.gd`), as built: **Fuller pots** (`gd_full`:
  a third more syrup in every pot, all run) and **Taller walls**
  (`gd_tall`: the sills 1.3 times as high, all run). *Both retired on
  2026-10-11 (section 9).*
- **Second chance**: the mould that ended the run is clear again and its
  pots full. Not offered to a run
  that served nothing.

## 7. Sound and feel

`SETS["gumdrop"]`, twelve cues, all of them the three measured takes
Beeline and Eddy are made of: `pour` (the dropper's tick, six a second
while it is held, -21), `deal`, `spill`, `empty`, `serve`, and the notes
`set`, `good`, `perfect`, `flop`, `start`, `game_over`, `new_best`.
Nothing here is a liquid. `tools/measure_sfx.py gumdrop`: 12 files, 0
flagged. Haptics: `docs/agents/haptics.md` row 55.

## 8. Calls that are mine, unconfirmed

1. The name, and the kitchen: jelly, syrup, a dropper, jars.
2. **The run's end**: a mark that rises from 60 to 80, and one mould under
   it ends the run. The reference has no fail.
3. **Limited syrup** (1.6 times what is wanted, down to 1.2), and no undo.
4. The match shown live beside the card.
5. Mixing from level 5, by halves, of three pigments.
6. The dropper moved by a relative drag, and the two buttons at the foot.
7. Moulds made by rule (eight outlines, three cuts), not drawn pictures of
   things as the reference's are.
8. The two boosters and what the Second chance does.
9. The score: the match itself, 50 for a perfect one.
10. The pace: 48 squares a second, a big mould about 14 s of squeezing.

Of these, the user settled 2 (no fail: kept the mark, so the run still
ends), 3 (limited syrup: **rejected**, the pots are bottomless) and 4 (the
match shown live: **rejected**, hidden until served) on 2026-10-11.

## 9. 2026-10-11: a liquid in a jelly, no leak, no limit, no peeking

The user, over the reference's screen: "remove the leak feature, no need
for it. Also remove the tint limit, more tint color only make the color
stronger. Also, the color should behave more like a liquid, that's why
it's called jelly, it should act like a colored liquid filling a jelly
particles, spreading inside it. Check no web how to do it realistic. Also
the user should not be able to see the accuracy till it clicks to check".

**What the web said of the real thing.** A gel has no free surface and no
bulk flow of its own: dye injected into it is pressed outward through the
pores while the plunger is down (a plume that grows at a steady pace, the
front where the pressure runs out), then spreads only by diffusion, with a
front that slows as the square root of time and an edge that softens as it
goes. Students' agar labs measure exactly that. The games that look like
this on a GPU run a velocity field with a pressure solve (Stam's
"Real-Time Fluid Dynamics for Games", 2003) and advect the dye through it;
that is a liquid in a bowl, not a dye in a gel, and it costs a phone a
Jacobi solve a frame. **What was built is the gel**: no velocity field.

- **A square is jelly with a concentration of pigment in it**, no top to
  it, and the liquid pressed into it and not yet drunk (`liq`). The liquid
  runs down its own gradient between neighbouring squares of one cell
  (0.22 of the difference a pass, at most a fifth of what a square holds,
  two passes a step), carrying pigment held back a little by the jelly
  (`HOLD` 0.35: the colour's front trails the liquid's, dense at the tip
  and soft at the edge), and the jelly drinks 2% of it a step (`SOAK`).
  So a bloom grows under a held button at a steady pace and comes to rest
  once it is let go; after that the pigment only diffuses, 6% of a
  difference a step, once a step, and the sim counts the jelly as still
  when under 0.0006 a square moves in a step.
- **Nothing crosses a wall or the rim.** The only edges are pairs of
  squares in one cell. Over a wall or on the tray the tip squeezes
  nothing. There is no spill, no sill, no tray cost, no `spill` cue.
- **The jelly has a grain**: a square's permeability is one, ±45%, read
  smoothly from a lattice of seven by seven random heights dealt with the
  mould; an edge passes at the pair's harmonic mean. A bloom's edge is
  ragged for it. The shader bends its read by a grain of its own (two
  wound sines, 0.28 of a texel), so the rag holds at pixel size.
- **The pots are bottomless.** No `left`, no `empty`, no slack, no mould
  that serves itself when they run dry. The dropper gives 90 squares of
  liquid a second (a square is a concentration of one).
- **More is stronger, without limit, and past the card's shade deeper.**
  A square's strength is 1 - exp(-c / 0.5), scaled to 1 at a
  concentration of 1.25 (`C_FULL`, the card's own shade); past it the hue
  is deepened toward its square, 45% at twice `C_FULL`. That deepening is
  the only brake on a heavy hand.
- **The judge compares colours.** A square's match is one less its
  colour's distance from the card's flavour, as a share of the distance
  from clear to that flavour (so a pale lemon and a pale cherry are judged
  alike); a cell's is the mean of its squares', the mould's of all its
  squares. No fill, no hue cost, no tray.
- **The match is hidden while a mould is played**: a `?` beside the card
  where the number was, the number once served. No cell "sets" any more
  (a ring and a note at 0.9 were live accuracy); the `set` cue went.
- **The boosters are Softer jelly** (`gd_soft`: the jelly drinks half as
  fast, a hold reaches further) **and Kinder marks** (`gd_kind`: every
  mould needs 10 less). Held `gd_full` and `gd_tall` come back as gold
  when the screen opens, as Eddy's did.
- **The tutorial's second page** is "Let it soak": one long squeeze off
  the middle of a half blooms to the wall and no further, evens out once
  let go, and a second squeeze makes it stronger.

Measured in `tests/_probe_gumdrop.gd`: a half-round cell of 324 squares
held from its middle is at the card's shade in 4.5 s and at 97% after a
rest; held 8 s it is 89% (darker than the card); the careful bot serves 32
moulds of two runs, 10.6 s a mould, the worst 93%; the careless one (the
first pot, a second at every cell's edge) is over at level 1; a step with
a wet mould is 0.9 ms on this Mac.

Calls that are mine, unconfirmed: the gel model over a velocity field; the
deepening as the brake (and its strength, 45% at twice the shade); the
grain; the pace (90 a second); the judge in colour distance; the two
replacement boosters and the refund; the `?`.
