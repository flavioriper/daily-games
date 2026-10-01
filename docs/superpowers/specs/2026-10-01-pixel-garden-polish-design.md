# Pixel Garden polish: four plates, the iron, Windblown, rewards and the bead box's sound

2026-10-01, built unattended on `feat/pixel-garden-polish` at the user's word
("let's polish the pixel garden game, add more smooth animations, reinforce
that the sfx sounds are really cozy, add more visual rewards even if silly
to the user to keep engagement, and make sure the insane difficulty is
really insane, with something totally new (something only us do) that make
the game nearly impossible, user can also fail on insane and hard ...
Divide the board into 4 pieces with some lines to guidance like the real
board does, also show the pegs into slot cases to emulate like if it's
someone with a real board on the table"). The two references were a big
clear pegboard of square plates with clips on their edges, and a clear
compartment box of fuse beads beside a pegboard and steel tweezers.

Marigold's, Super Slider's and Knight's passes the same day are the pattern
for hearts, dusk and the card, the party and the seal. The board's own spec
(`2026-09-27-pixel-garden-flat-design.md` and its amendment) stands except
where this says otherwise. The calls at the end are for the user.

## 1. Four plates, and the iron as the judge

The board is **four plates** in the tray, a seam `GAP` 0.3 of a cell between
them and a wooden clip on each plate's top edge, as a big real pegboard is
four small ones clipped together. The pattern card is drawn the same way:
four squares with a seam (`THUMB_GAP`), so a plate is copied from its own
square.

**A plate holding as many beads as the picture puts on it is ironed at
once** (`State.plates_full`, `iron_plate`). A little iron with a face
(`ui/faces/iron.gd`: a mint body, a squarish heel, a cord, a cream handle,
a lamp that glows while it works) settles onto the plate and glides down its
diagonal, steam puffing behind it:

- **right**: every bead fuses as the iron passes (hole to a dimple, gloss,
  a glint), the plate is fixed for good (`locked` = `FUSED`), the iron
  twirls once and goes, and a word pops: "Perfect plate!", or "N in a row!"
  for plates right first time running, with a note up the scale and
  confetti from the third;
- **wrong**: the iron stops worried and shivers, the beads astray hop on an
  arc back into their own compartments (`HOME_TIME`), and the toast says how
  many (`PG_PLATE_OFF_*`). On Hard and Insane it costs a heart
  (`PG_PLATE_HEART_*`, with the hearts left).

The state judges at once; the board shows it when the iron gets there.
Strokes on the plate under the iron wait; **the other three plates stay
live**, so a quick player is never held up (the first build held the whole
board for the iron's 1.3 s, and the win harness's fast taps fell through).
Undo, Hint, Reset and Check wait for the iron. A hint's lock (`HINTED`) and
an iron's (`FUSED`) are told apart, so Try again keeps a hint's pegs and
melts the plates. A plate the picture leaves bare is done from the start.

A plate is only judged whole, so nothing answers a bead at a time -- the
board's first rule (spec 2026-09-27, section 2) holds.

## 2. Bands

| band | size | hints | Check | hearts | the cost |
|---|---|---|---|---|---|
| Easy | 10 | 3 | yes | - | - (beads astray hop home, free) |
| Medium | 12 | 3 | yes | - | - |
| Hard | 14 | **2** | **no** | **3** | a plate ironed with a bead astray |
| Insane | **Windblown**, 16 | **0** | **no** | **2** | the same |

`State.HINTS_BY` / `HEARTS_BY`; `capabilities()` drops Check on Hard (the
iron is the judge: Check before the last bead would make a heart
impossible to lose) and Hint too on Insane. Out of hearts: dusk, the card
(`PG_OUT_BODY` / `PG_OUT_REST`: "The iron has gone cold") -- Try again (the
same picture on a bare board, a hint's pegs kept, hearts full, clock and
moves from zero; hints spent stay spent), One more heart (a video, once;
play goes on), Back. The hearts sit at the right end of the picture's name
line, smiling; a lost one splits and falls. `PG_LVL_2` says three hearts.

## 3. Insane: Windblown

**The wind blew the pattern card's four squares about. Each landed
somewhere else, turned; the board must still be the true picture.** Each
board plate has a colour (sun, sky, rose, leaf, `PLATE_TINTS`, apart in
lightness as well as hue) and its clip carries 1 to 4 white pips. On the
card, every square is framed in the colour of the plate it shows, with that
plate's clip on the edge that is the plate's top -- so which plate and which
way up is always on screen; the player turns it in their head.

- **Why it is ours**: checked 2026-10-01. Bead-pattern and pixel-art apps
  show the reference as is. Puzzles that scramble and turn pieces (Dot
  Piece Puzzle's Kaiten mode, PicShift's hard mode, Beauties' Thrilling
  Shots, Pixort) scramble **the pieces you move**, and the task is to turn
  them back. Here nothing on screen turns: the **reference** is scrambled
  and turned, and the picture is built bead by bead into the true
  orientation, a mental rotation held for every bead.
- **Why it is nearly impossible**: 16 x 16, 6 to 7 colours with close
  shades side by side, four 8 x 8 squares each moved and turned (no square
  left in its place upright, at least three turned: `State.blow`), no hints,
  no Check, two hearts, and a plate judged only whole -- one bead turned the
  wrong way is a heart.
- **Fair, always**: `card_peg(q, u, v)` maps every square's pixel to one
  board peg (a bijection, checked by the probe); the clip marks the top; the
  held card grows over the board as before, clips and all. The picture is
  the band's hand-drawn picture, not mined: any picture is fair under a
  turn.
- `PG_LVL_3` "Windblown: the pattern's squares blew about"; the tip
  `PG_WIND_TIP` at the start; rules `PG_RULES_WIND`. A solve shares
  `🌬️ Windblown[ · Flawless]` and stamps the night seal.

## 4. The bead box and the tweezers

The chips became **a clear plastic compartment box**: a compartment a
colour, each heaped with little beads (holes and all) as many as are left
(`HEAP` 11 for a full one, rows of 4, 3, 3, 1, jittered off the day), a
clear lip with a gloss, and a paper label with the count and a dot of the
colour. The chosen compartment is lit from under. **Steel tweezers** rest in
it, glide to a new one (`TWEEZ_TIME`, over a little arc) and dip as they take
hold. An empty compartment is bare, its count dim.

## 5. Rewards, even silly

- The iron's twirl, the plate words and the streak (above).
- **Hearts of love** off a happy iron, or **a butterfly** that flutters in
  and rests on the finished plate (`FLY_SIT` 2.6 s), alternating.
- **Steady hand!** for a stroke seating 8 beads, **Whoosh!** for 14 (with a
  sparkle), at most every 5 s; a run's `place` clicks climb a little as it
  goes.
- **The party** after the win's iron (which the iron itself now rides):
  confetti twice, hearts of love off the tray's corner, the nap cat hopping
  from the box onto the pattern card and curling up on it (`purr`), bead
  wisdom (`PG_CHEER_0..9`), and the seal: gold for Flawless (no hint, no
  Check, no plate ironed wrong), night for any Windblown.
  `completion_record()` keeps `hearts` and `flawless`; a restored day shows
  the cat asleep and the seal. `win_delay` waits for the cat.

## 6. Sound

A new style pair in `tools/gen_sfx.py`: **BEADBOX** -- close-mic foley of a
real craft table: small plastic fuse beads, a clear compartment box, steel
tweezers, a pegboard, a warm iron on baking paper, "no synth, no electronic
tones, no beeps" -- and **BEADBOX_TUNE** -- a real kalimba, music box and
hand bells. Every cue rolled off above 7 kHz. All 13 old cues taken again
(the house glockenspiel and marimba and the tape-rewind undo are gone;
`place` and `lift` cut to their first click) and 13 new: `steam`, `plate`,
`astray`, `heart_lost`, `out_of_hearts`, `heart_back`, `combo`, `steady`,
`confetti`, `flutter`, `stamp`, `party`, `purr`. 26 cues, rendered on the
fallback key; **unheard** by a person.

## 7. Numbers

`tests/_shot_pixel_garden.gd` at `--resolution 810x1440 --always-on-top`,
windowed, one at a time, peak draw calls from 0.5 s:

| mode | band | peak |
|---|---|---|
| rest | Insane | 74 |
| plate (a plate ironed right) | Easy / Insane | 96 / 79 (79 on ANGLE) |
| astray (a heart) | Hard | 92; 89 reduce motion |
| out (three hearts, the card, Try again) | Hard | 111 |
| wind (the card, held up) | Insane | 73 |
| solve (the win's iron, the party) | Medium / Insane | 124 / 87-88 |
| restore | Insane | 83 |

Peak 124, 731 under the 855 budget. The suite `passed=122403 failed=0`;
`tests/_probe_pixel_garden.gd` (headless, reduce motion, through touches)
solves every band, loses Hard's three hearts on plates astray to the card
and Try again, and checks Windblown's mapping; `tests/_win.gd --
pixelgarden` PASS; `tests/_shot_anim.gd -- pixelgarden` 92 and `solve` 105.

## 8. Bugs fixed on the way

- **Restore**: a reopened, solved day under 100 s after launch drew the bare
  pegs and fired the band's tip (`_solved_at` pushed negative; Marigold's
  and Super Slider's bug). `_won` says it now, and the tip waits for an
  unfinished board.

## 9. Calls for the user

- **Insane is Windblown.** Considered: a mirrored pattern (one fixed
  flip is learned in a day), a pattern shown only for a few seconds (memory
  is not this board's skill, and blind copying is not fun), beads that
  fade from the kit (a timer on a calm board).
- **Hard's and Insane's heart is a whole plate**, judged when full; Check is
  gone from both so a heart can be lost at all.
- **Easy and Medium iron plates too**, free: a wrong plate's beads hop home,
  which is a kind check -- with Check still there.
- The look (plates, clips, box, tweezers, iron, cat on the card) was judged
  on stills. Sounds unheard.
