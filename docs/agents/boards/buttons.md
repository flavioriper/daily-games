# Button Box

- **Button Box is the thirty-seventh card** (2026-10-11, `puzzles/buttons2d.gd`,
  `puzzles/buttons_state.gd`, `ui/faces/button_art.gd`; no spec and no
  concept tab -- asked for and built in one sitting, "do autonomous, no
  questions"). The web game it follows is Jewel Coloring: Crystal Sorting,
  and **that name goes nowhere else**: not in code, comments, commits or on
  screen. The puzzle id is `buttons` and the locale prefix `BB_`.
- **The rules, as the user gave them and the game's own tutorial frame
  showed** (2026-10-11; the page says only "move it to the matching cell,
  use the storage when the cell is blocked", and its canvas took no click
  from here, so nothing past the first frame was seen played): a picture of
  coloured slots, a piece on every one, all of them on the wrong colour; a
  small case; a tap takes a chain of one colour at once; pieces go into
  open slots of their colour at once; the case gains slots as colours fill.
  Ours, name for name: the patches of dyed cloth, the buttons, the tin, a
  run, sewn.
- **One move** (as first built; **replaced the same day**, see "Pick, then
  place" at the foot): tap a button out of place. It lifts with every button of
  its colour touching it (`State.run_of`, nearest first). Each goes to the
  nearest bare patch of its own colour and is sewn there for good; with no
  bare patch, into the tin while it has room; the rest stay where they
  were. A patch left bare takes its button out of the tin at once. A sewn
  button is refused (`REFUSED_HOME`), and so is a tap that could move
  nothing: the tin full and no bare patch of that colour (`REFUSED_FULL`,
  with a sun ring for 1.6 s on every button a tap would sew).
- **The tin** starts at 6 places (7 on Hard) of 12 and gains one each time
  a colour is whole (`State.capacity`).
- **Nothing can be stuck.** The bare patches are always as many as the
  buttons in the tin, and the tin never holds a colour a bare patch wants,
  so a button of that colour is still on the cloth and a tap on it sews.
  `tests/_probe_buttons.gd` (headless) plays every picture of the bank on
  every band three ways -- the state's own hand, a careless one, one that
  fills the tin first -- and checks those three things on every tap: 1,080
  runs, 0 failures. So Easy to Hard cannot be lost, and a full tin is only
  a refusal.
- **The bands**: the picture is one of `content/pixel_garden.json`'s band
  (Pixel Garden's hand-drawn bank: 10, 12, 14 and 16 square, 30 a band, 3
  to 7 colours, 32 to 168 buttons **until 2026-10-11; Hard is 24 square
  and Insane 32 since, 576 and 1,024 buttons, and cut another way: "Big
  pictures" at the foot**), picked by this board's own seed, so the
  two boards do not show one picture on one day except by chance. A bare
  peg there is bare linen here. The scramble reads the picture's colours
  down its columns, cuts them into lengths of 3 to 7, shuffles the lengths
  and lays them along the rows; a button that lands on its own patch trades
  with one that can; a picture that still opens more than a quarter sewn
  (one nearly all one colour) is drawn again, twelve times at the most.
  Undo and the bulb (3 / 3 / 2) up to Hard. **Insane counts taps**
  (`docs/agents/flat-screens.md`, "Insane counts moves"): the taps the
  state's own hand takes (`par`, 30 to 93, median 58) and a quarter more,
  never under three; no Undo and no bulb; out of taps is the shared
  out-of-moves card (its video buys five, once). A careless hand on the
  first Insane day ran out at 126 of 144 sewn.
- **`State.hint` is a greedy hand, not a best**: the run that sews the most
  at once (the tin's own that fall in behind it counted), and with nothing
  to sew, the biggest run the tin takes whole (**its ties and its choice
  for the tin were rewritten on 2026-10-11, "Big pictures"**). `par` is its
  count from the opening, so a player may beat it, and the seal asks `<=`.
- **Drawn as** `_bg` (the linen, a layout), `_still` (the stitched border
  and a patch a square), `_tin` (rebuilt when a place opens), and the
  buttons as unit meshes a colour, loose and sewn, baked with
  `Face.FlatBuilder` into `_rest` and, in the air, `_top` (**`_rest` is
  gone since 2026-10-11: a mesh a block, a live mesh, and three layers;
  "Big pictures"**); the pill, the
  toast and the streak's bubble on a layer of their own. **84-111 draw
  calls on `opengl3_angle`** at 810x1440 (96 at the peak of an Insane day,
  the second of two readings; 111 through `_probe_perf.gd`'s Medium win;
  127 under the tutorial). A button is coloured
  by index, so **sewn is a shape**: the cross of thread through its holes
  and no shadow. Loose is a shadow and a patch of another colour round it.
  No character: the pieces are marks.
- **A `bleed` board** (the second after Gumdrop): the linen is the whole
  screen, the picture as big as the room between the pill and the tin
  allows (a cell is 84 at the most), the tin at the foot. `set_clear(top,
  bottom, won)`: on the win the tin fades and the picture slides to the
  middle of what the win screen leaves (`_slide_xf`, one transform over
  the meshes built at the new size). `"tip": false`; the toast says what
  the tip card would.
- **Motion that is this board's own**: a run leaving one button after
  another (0.04 s apart, 0.5 s for the whole run at the most), each in an
  arc and growing at the top of it; the tin's own leaving 0.16 s after the
  patch is bare; a bump as one lands, wider when it is sewn, and a ring
  every third; a colour whole hopping outward in rings from the tapped
  button with a few sparkles, and the tin's new place ringed; the streak's
  bubble from the third tap in a row that sewed something, confetti at
  five and ten; confetti for five or more sewn by one tap; the win's hop
  along the diagonals, the seal for a day in no more taps than the par, or
  any Insane one.
- **Sounds** (`SETS["buttons"]`, seventeen cues, no new take: Lattice's
  light wooden button, its hollow block and its one kalimba note, and
  Hedgehogs' breath). `lift` on every tap; `sew` or `tin` once a button as
  the run lands, climbing half a step a button and five at the most;
  `combo` one note the board pitches up to five steps along the streak;
  the landings tick once in 0.075 s at the most (`TICK_GAP`), a wheel
  spun and never a rattle; `run` two notes for a long run; `whole` three rising; `open` two tocks
  of the tin. `tools/measure_sfx.py buttons`: 0 of 17 flagged. Unheard.
- **Harnesses**: `tests/_shot_buttons.gd` (rest, play, refuse, hint, solve,
  out, reset, restore, howto, and since 2026-10-11 big and howzoom); `tests/_probe_buttons.gd` (headless, the
  rules); `tests/_win.gd -- buttons` wins through the input path with a
  refused tap and the bulb on the way; `tests/_probe_perf.gd -- buttons`.
- **Not seen on a phone.** Shots and probes on this Mac only. The sounds
  are unheard by the user; the pt and es lines are unreviewed (botão /
  botón, retalho / retal, lata, costurado / cosido).
- **Calls made without the user** (2026-10-11): the name, the buttons, the
  linen and the tin; a run as four-way touching; nearest bare patch first;
  a run longer than the tin leaving the rest behind rather than being
  refused; the tin at 6 of 12 and a place a colour whole; Pixel Garden's
  pictures; the scramble's lengths; Insane as counted taps over a greedy
  par; the original's four boosters left out (the bulb is the hint).

## Pick, then place (2026-10-11)

The user, having played the first build: "User must click on the piece and
do another click where it goes, not do it automatic. if it click in a red
button, all red buttons (on the wrong place) linked to it (all directions,
even diagonal) start to be pulled together. If user click on the case they
go to case, instead of land on the right place". So:

- **A move is two taps and nothing lands by itself.** The first picks: a
  button out of place with every one of its colour touching it, **corners
  counted** (`State.NEAR` is eight ways), or, on a button in the tin, every
  button of that colour in the tin (`tin_of`). The second says where: a
  bare patch of their colour (`State.sew`: onto the bare patches nearest
  the tapped one, as many as there are) or, for a run off the cloth, the
  tin (`State.stow`: as many as it has room for). The tin no longer gives
  a button back on its own.
- **A pick** lifts, grows a tenth, draws 22% of the way toward the tapped
  button and bobs (`_held_pos`), and where it may go is ringed in sun: the
  bare patches of its colour and the tin's free places. Tapping it again,
  or bare linen, puts it down; tapping another button picks that run.
  A bare patch tapped with nothing picked says "Pick up a button first",
  one of another colour "That patch is another colour".
- **A pick never outlives its move, and a full tin's buttons can always be
  picked.** The first cut kept the buttons no patch was left for picked,
  and a tap on the tin with a run picked always tried to stow it: with the
  tin full, the tin's own buttons -- the only way on -- could not be
  picked without first tapping bare linen (the user: "something is causing
  the game to get stuck"; `tests/_shot_buttons.gd -- d=0 solve trace` showed
  the state's own hand stalled at 40 of 56). Now the leftover is let go,
  a refused stow lets go too, and a tap on a button in a full tin picks it
  whatever is held.
- **Still nothing can be stuck**, by the same count (bare patches equal the
  buttons in the tin). `tests/_probe_buttons.gd` plays the rules three
  ways (1,080 runs, 0 failures) and **`tests/_probe_buttons_board.gd`
  plays the board's own `tap` and `tap_tin`, headless**, with a hand that
  taps anything at all and one that always tries the tin first: 32 days,
  0 failures. Run it after any change to the taps.
- **A move, not a tap, is what is counted**: `par` is the hand's moves (7
  to 127, median 18 / 39 / 59 / 76 by band; taking a button out of the tin
  is a move now), Insane's budget a quarter over it, and the lines say
  moves. The bulb picks, and half a second on taps where it goes.
- **Not re-shot after the stuck fix**: the win harness, the perf probe's
  buzz walk and the tutorial's pages were last run on the cut before it
  (the user asked for fewer windows); the tutorial's lessons do not depend
  on what changed. The draw calls above are the first build's; a pick adds
  nothing but its rings to the same meshes (90-99 read on the first cut of
  these rules).

## Second polish (2026-10-11)

The user, the same day: "lets remove the link diagonal after easy, make too
easy. Also, hard and insane should never show where to place, also should
only auto place in linked tiles, not fill all board on the same color.
Another change, when user select a color, it should keep selected until end
or use click on it again, so user can select for example a color, and click
into different places of board to keep placing".

- **Corners link on Easy only** (`State.near`, `CORNERS_TO` 0); from Medium
  a run is the four sides. The rules sheet adds `BB_RULES_CORNERS` on Easy.
- **Hard and Insane ring nothing** (`State.guides`, `GUIDES_TO` 1): no sun
  ring on the bare patches or the tin's free places while a pick is held.
  The pick itself still lifts and draws together on every band.
- **A tap fills a stretch, not the cloth**: `State.sew` puts the pick onto
  the tapped bare patch and the bare patches of that colour joined to it
  (`bare_run`, by the band's own `near`), nearest first. A bare patch of
  the colour elsewhere is another tap. Read as a rule for every band, not
  only Hard and Insane: it is what makes the next point worth having.
- **A pick stays picked** until it is used up or tapped again: what a sew
  had no patch for, and what the tin had no room for, stay in the hand. This
  takes back "a pick never outlives its move" above and keeps the half of
  it that mattered: **a tap on a button in the tin is always a pick,
  whatever is held** (a run off the cloth goes in on a free place or the
  tin's wood). The bulb's move lets its leftover go.
- `par` is the hand's moves under these rules (one sew a stretch): median
  20 / 46 / 67 / 95 by band, 7 to 142 (**18 / 43 / 283 / 450 since
  2026-10-11**, the hand a little better and the last two bands big).
- Checked with no window (the user had asked for fewer): the rules probe
  1,080 runs, the board probe 32 days through `tap` and `tap_tin`, both 0
  failures; the tutorial's SEW and TIN lessons replayed on `Small`
  headless (12 of 12 sewn; three sewn and the tin at 4 of 5); the suite
  249,804. **Not seen on a screen**: the missing rings on Hard, the pick
  left in the hand after a sew, the reworded lines, the win harness and the
  buzz walk.

## Big pictures (2026-10-11)

The user: "on Button box and pixel garden, the hard and insane should have
really big and complex images ... Something that the user have even to zoom
in to see". Decided with them since: the shared bank's Hard band is 24
square and Insane 32, filled scenes of 8 to 12 colours (576 and 1,024
buttons, a button on every square); Easy and Medium as they were; the rules
as they were; a zoom and a pan. "all good, just build it".

- **What a move can sew is what the tin holds, and that is the whole
  arithmetic of a big day.** The bare patches are always as many as the
  buttons in the tin, so no sew is ever bigger than the tin: 6 or 7 places
  at the start, 12 at the end. 1,024 buttons at 6 a move is 170 moves with
  every move a full chain and not one button put in the tin; the brief
  asked for a par of 100-140 on Hard and 160-220 on Insane by cutting the
  scramble longer, and **the lengths are not the lever**: with the old
  scramble, `CHUNK` from 3-7 up to 60-120 moved Hard's median from 438 to
  422 and Insane's from 773 to 758 (24 synthetic deals a band). A bigger
  tin is not the lever either with this hand (10 and 12 places of 18 gave
  242 and 410). What moved it:
  - **Big pictures are scrambled a strip at a time** (`_scramble_strips`,
    `BIG_FROM` 2): the picture is cut along its rows into strips of one
    colour, `CHUNK` long at the most (5-7 on Hard, 6 on Insane: a tinful),
    and the strips of one length trade their buttons round a ring, no
    strip getting its own colour. A strip lifted bares a strip's worth of
    one colour, which another strip fills whole. 438 to 294, 773 to 479.
    Easy and Medium keep the old scramble, call for call.
  - **The hand takes a run up by the patches under it** (`_tidy`): when
    only some of a run will go, the buttons standing on the biggest joined
    stretch of one colour of patch go first, so what they leave bare is
    one stretch. And of two sews as big it takes the one that leaves fewer
    colours bare, then the shorter run; for the tin, the run that opens
    the most patches in the fewest colours. To 266 and 385 on the
    synthetic bank. A "neat sews only" rule (never nibble a long run for a
    small stretch) was tried and made Insane worse (504-536): out.
  - **Measured on the real bank** (12 pictures a band, 8-10 colours on
    Hard and 10-12 on Insane, all squares filled): **par 228-340, median
    283 on Hard; 357-511, median 450 on Insane** (budget a quarter over:
    about 560). That is two to three times the brief's figure and is the
    floor of these rules with a greedy hand, not a tuning left undone:
    the user's to call (a shorter day wants fewer buttons or other rules,
    not other lengths). Easy and Medium moved to 18 and 43 (were 20 and
    46): the same hand, a little better.
- **The par is counted in a few dozen ms.** Counted the old way (the cloth
  read again for every move) a 32-square day opened in 1.0 s. The hand now
  keeps what it sees from move to move (`_solve_taps`: a run only ever
  loses buttons, so a move changes the one run it picked; the bare patches
  are never more than the tin), a redraw of the picture no longer counts a
  par each (`setup` counts once), and `colours_done`, `homes` and `count`
  are kept and not scanned (`_off`; `capacity()` was 12 scans of the cloth
  a call). `state.setup`: 18 ms on Hard, 32 on Insane (median of 24, 46
  the worst); the board's whole `start`, layout and meshes with it, 39 and
  64 ms. `hint()` itself reads the cloth: 1.4 and 2.4 ms a call.
  `tests/_probe_buttons.gd` checks the two agree (the hand ends on the
  par) on every deal.
- **`PG_BANK`** in a debug build points `State.bank()` at another file, as
  Pixel Garden's does.
- **Drawn in three layers.** The board's own `_draw` is the linen, the tin
  and the tin's buttons, which never scale. `_cloth` (a child Control over
  the picture's room, `clip_contents` only while zoomed) draws the border
  and the patches, **the buttons at rest a mesh a block** (`_blocks`: 8
  squares a side on a picture over 16 square, so 9 meshes on Hard and 16
  on Insane; one block on Easy and Medium), the ones doing something
  (`_live`, one mesh a frame) and the pick (`_held_mesh`). `_over`, above
  both and never clipped, draws what flies. A button leaves its block for
  `_live` when it is picked, lands, hops or shivers (`_mark`) and goes back
  when all of them are still; a block is rebuilt only then (0.25 ms).
  Before this every button was rebuilt every frame anything moved.
- **A big picture's pieces are light** (`Art.button_lite`, `Art.patch`'s
  `lite`): polygons with only the outline feathered. Seen whole (a square
  is 30.5 px of the 1080 on Insane, 40.7 on Hard) the button is a rim, a
  face and a dish, **and sewn is a bold cross from edge to edge**: the four
  holes would be a pixel each. Seen close (from 46 px a square, back at
  42) it is the whole button, holes and thread. 227k vertices for Insane's
  thousand plain and 516k close, where `Art.button` would be 1.3 million
  and the patches another 650k; the patches are 37k.
- **A picture of over 300 buttons moves as blocks**: it pops in whole, not
  a button at a time; the win hops a block at a time along the diagonals;
  a colour whole hops six squares out from the tapped one and no further,
  with twelve sparkles at the most; a run rings eight times at the most; a
  pick of over 48 does not bob and is built once (`_held_still`), and a
  pick draws together no further than 0.9 of a square a button (a sky of
  360 pulled a fifth of the way left its patches: seen, fixed).
- **The zoom** (`ui/flat/pan_zoom.gd`, shared with Pixel Garden; not
  changed here): Hard and Insane only (`_zoom_limits`), one transform over
  the same meshes, the picture's room between the pill and the tin as its
  view. Two fingers pinch and pan; one finger dragged past 14 px pans a
  picture seen close (`one_finger_pan`: this board is taps); the wheel on a
  desk. A gesture that begins drops the press in hand and ticks
  (`fx.touch`), so letting go taps nothing; a pick in hand stays. **The
  button** is an 84 px `IconButton` at the room's bottom left, 12 in (the
  thumb's side stays clear), plus when whole and minus when close, to 60
  px a square (the most a pinch goes is 84); hidden on Easy and Medium,
  on a done day and from the win. Squares are hit through
  `zoom.to_layout` and only inside the room; the tin is never zoomed. A
  flight keeps each end in its own measure (`fc`, `tc`) and the cloth end
  goes through the zoom every frame, so an arc from a close picture to
  the tin is one arc. The bulb brings a close picture to its pick and
  then to its place (`show_point`). Reset, a new day and a day reopened
  are whole; the win glides whole and the slide starts from the zoom it
  found (`_from_zoom`). `cell_centre` is the layout's; **a harness presses
  `cell_screen`**.
- **The share** is 12 or 16 marks a side on a big picture, each the colour
  most of its squares are (`SHARE_MAX`). The menu card is its fixed swatch.
- **The tutorial has a ZOOM page on Hard and Insane** (`Lesson.ZOOM`): a
  6-by-8 cloth that zooms whatever its band, two fingers that are real
  touches going apart, one dragged, and the page's own button back to
  whole. `HTP_BB_ZOOM*`, `BB_RULES_BIG`, and `BB_LVL_2` and `BB_LVL_3`
  reworded, in en, pt and es.
- **Probes** (headless, the real bank): `tests/_probe_buttons.gd` 612 runs,
  0 failures (three seeds on Easy and Medium, **one on Hard and Insane**;
  its moves are drawn at random off one pass of the cloth now, the old
  listing of every run against every bare patch was a second a move at 32
  square; 29 s). `tests/_probe_buttons_board.gd` 28 days, 0 failures
  (**one day each on Hard and Insane**: a hand that taps anything takes
  19,000 and 38,000 taps there) and the zoom through `_gui_input` with
  ScreenTouch and ScreenDrag, 0 failures: the button close and back, a tap
  on the square under the finger whole, close and after a pan, a finger
  that barely moves still taps, a pan and a pinch tap nothing, a pan keeps
  the pick, a pinch stops at the most and at whole, the picture always
  covers its room, the tin taken from a close picture, Reset whole. The
  suite 249,804 passed.
- **Seen** (three windows, `opengl3_angle`, 810x1440; `tests/_shot_buttons.gd
  -- d=3 big`, twice, and `-- d=2 howzoom`): Insane whole, 0 and 66 sewn
  (buttons read as buttons, sewn as crosses, bare patches as patches);
  close with a run picked; six in the air to the tin; panned; whole again;
  the ZOOM page playing. **Draw calls 84 to 90 in play on Insane** whole
  and close (the second run's readings; 86-88 the first), 163 in the one
  frame the harness makes twelve moves at once, 129 under the tutorial.
- **Not seen or owed**: a phone (the pinch with real fingers, the frame
  time of 516k vertices close, the button under a thumb); Hard on a screen
  but for the tutorial's backdrop; the win of a big picture (the block
  hop, the slide from a zoom, the seal); the bulb bringing the picture to
  its move (its ring is thrown where the pick was before the glide, so on
  a pick out of sight the picture moves out from under it: known, not
  fixed); the new lines in a real locale (shot as raw keys, no reimport);
  the win harness and the perf probe, not rerun. A mouse cannot pan (the
  wheel zooms about the pointer). The pt and es lines are unreviewed.
- **Calls made without the user**: the strip scramble and the better hand
  in place of longer lengths; a par of 283 and 450; the button's place and
  its 60 px; the plain button under 46 px; blocks in place of a button at
  a time on a big picture's entrance and win; "A big picture, 24 × 24:
  zoom in" and "A huge picture, 32 × 32, counted moves".

## The wave (2026-10-11)

The user: "part of the cozy satisfactory is the buttons moving in sequence
but fast, so when user click somewhere to remove or add button, start
pushing them in sequence on linked ones like a wave", and "let's say user
has 6 pieces selected, he can click into 2 different places and they will
move together but each one in it own sequence, not all at once".

- **A pick comes up as a wave** out of the tapped button: each picked
  button starts its lift `PICK_STEP` (0.045 s) a square of distance from the
  tapped one later, the farthest no later than `PICK_CAP` (0.5 s)
  (`_held_lag`). The tin's own, picked, do the same along the tin.
- **A move's buttons leave further apart**: `RUN_STEP` 0.04 to 0.06 s and
  the whole run 0.9 s at the most (0.5 before), so six read as six and not
  as one. They land outward from the tapped patch (`bare_run`'s order).
- **Two moves run at once**: nothing waits for the first to land, so a pick
  of six tapped onto two stretches flies as two sequences side by side.
  That was already so; only the tapped square's own arriving button is
  held back.
- Reduce-motion has no lag. Probed headless (the board probe 28 days and
  the zoom, 0 failures; the suite 249,804). **Not seen on a screen**: the
  steps are mine to tune once the user has felt them.

## Sewn is the colour, and the zoom has a step (2026-10-11)

- **A sewn button is its square in the colour, whole** (the user: "it's hard
  to see button box when button is on right place, can we make the button
  blend to the ground and become just the color?"). `Art.sewn`: the cell
  edge to edge, no rim, holes or thread, so sewn squares run together into
  the picture. This takes back "sewn is the cross of thread" above. Bare
  and sewn still differ by a shape, never a shade: **a bare patch carries a
  ring where its button sits** (`Art._seat`, hidden under any button), which
  is what tells white sewn from white bare. The menu card's the same. Seen
  on Hard (`big`): 98 to 125 draw calls.
- **The zoom's button goes a step at a time** (the user: "user should be
  able to do another step of zoom out"): whole, half way (`sqrt(k_near)`),
  close, and back out the same way (`PanZoom.cycle`, the icon from
  `next_in`); two quick presses are two steps. `toggle` stays for code that
  wants whole at once (Reset, the win). Pixel Garden's button is the same.
  The probes, the harnesses and both tutorials press twice where they meant
  close. Read as "a step between", not "smaller than whole": whole already
  shows all of the picture. Probed headless; the half-way step not seen on
  a screen.
- **Corners link on every band again** (the user, 2026-10-11: "move back
  the diagonal link"; `CORNERS_TO` 3). It takes back "Corners link on Easy
  only" above. Both a pick and the stretch a sew fills go by the eight
  ways, and `BB_RULES_CORNERS` is read on every band. `par` medians: 18 /
  34 / 267 / 439 (rules probe 612 runs, board probe 28 days, 0 failures;
  the suite 249,804).
- **The tin is twenty places, ten open** (the user, 2026-10-11: "the case
  should be bigger, 20 slots, 10 free and 10 to unlock"; `CASE_BASE` 10 on
  every band, `CASE_MAX` 20, still one more a colour whole). It takes back
  "6 places (7 on Hard) of 12" above. Two rows of ten (`TIN_ROW` 10, a
  place about 70 px at 810 wide; `_tin_row()` keeps the tutorial's small
  tin one row). A picture has twelve colours at the most, so the last
  places never open: the user's number, kept. `par` medians: 17 / 31 / 265
  / 395. Rules probe 612 runs, board probe 28 days, 0 failures; the suite
  249,804; seen on Insane (`play`), 103 draw calls at the peak.
- **A colour whole opens two places** (the user, 2026-10-11: "since now we
  have 10 hidden slots, each unlock must unlock 2 not 1, so they all
  become available near the end"; `CASE_STEP` 2, `State.base()` is the
  number the rules print). It takes back "still one more a colour whole"
  above. Every place a tap opens gets its ring (`_open_places`; a tap can
  make two colours whole), clamped to the places drawn, since the
  tutorial's tin shows six. The pictures have 3-4 colours on Easy, 4-5 on
  Medium, 6-10 on Hard and 8-12 on Insane, so the tin ends at 16-18 on
  Easy and Medium and is all twenty by the fifth colour on Hard and
  Insane, about half way: the user's number, kept, a rate by band not
  asked. `tests/_probe_buttons_board.gd` tapped tin places 0-11 only and
  left a last button in place 12 for 200,000 taps; it taps all twenty now.
  `par` medians: 17 / 31 / 241 / 370.
- **A pick comes up only a little** (the user, 2026-10-11: "it should not
  raise so high because it become bad to understand where is each piece,
  make it slightly raise"). `HELD_RISE` 0.06 of a square (0.14), and the
  draw toward the tapped button, which was what took a button half a
  square off its own, is `PULL` 0.05 up to `PULL_MOST` 0.12 (0.22 up to
  0.9). `HELD_SCALE` and the bob as they were. Seen on Medium (`play`),
  92 draw calls at the peak: each picked button over its own square.

## Cut-outs among the big pictures (2026-10-11)

- **A third of Hard and Insane is one subject on bare linen** (the user,
  with a screenshot of a monkey on a plain board: "let's make sure the
  button box don't have only square images"). Until now every one of the
  24 big pictures filled its square edge to edge. Twelve cut-outs joined
  the shared bank, six a band, so each big band is 18 (12 scenes, 6
  cut-outs): teapot, squirrel, robin, toadstool, turtle, whale on Hard;
  monkey, penguin, elephant, giraffe, watering can, cupcake on Insane.
  Painted in `tools/paint_pixel_garden.py` (`CUT`, `edge()`: a dark line
  on every bare peg beside a filled one; the penguin's is grey), with
  rules of their own there and in `tools/check_pixel_garden.py`: 30 to 70%
  filled, 5 to 10 colours on 24 and 6 to 12 on 32, the rest as a scene.
  Parts of one colour are painted a peg apart so the line parts them (the
  squirrel's tail from its back, the monkey's arms from its body).
- **No rule of the board changed**: bare linen on a big picture went
  through `_scramble_strips` (a strip ends at a bare peg), the light
  pieces and the block meshes as it does on Easy. Measured: cut-outs are
  267-381 buttons on Hard with a par of 116-196, 455-682 on Insane with
  249-315 (scenes: 576, 205-303; 1,024, 340-436); the bands' medians are
  now 241 and 377. **A subject mostly one colour opens part sewn**: the
  elephant all grey opened with 132 of 682 at home (grey strips trade with
  grey), so its ears are lilac and its blanket wide; keep a cut-out's
  biggest colour near a quarter of the board.
- Pixel Garden plays the same twelve (the bank is shared; its probe
  passes). Rules probe 648 runs, board probe 28 days, Pixel Garden's probe,
  0 failures; the suite 249,804. Seen once: the monkey on Insane
  (`PG_BANK` of one picture, `tests/_shot_buttons.gd -- d=3 play`), 105
  draw calls at the peak. The other eleven seen only on the checker's
  sheet; the robin and the whale's spout are the weakest drawings.
- **Mine, not the user's**: a third and not half or all; the twelve
  subjects; Pixel Garden getting them too; the square dashed frame round
  the room still drawn on a cut-out.
