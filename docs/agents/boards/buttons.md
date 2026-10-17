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
- **The tin keeps its colours in sequence** (2026-10-14, the user: "when
  moving pieces to case box or after placing them, we need to reorder it
  to make sure colors stay in sequence. For example if green is first and
  yellow second, and I move in green, it should be added right after green
  and move yellow to the next available slot"): its buttons sit packed
  from the first place in groups of a colour, in the order the colours
  came. `State.stow` packs, then puts the new ones right after the last of
  their colour (at the end with none there), the buttons past that
  sliding along as many places; `State.sew` out of the tin packs after,
  so no gap is left. Each button moved along is a `State.SLIDE` move
  (both ends places), which the board plays as a short hop between the
  two places (`SLIDE_TIME` 0.18 s, all at once, no tick) and the state's
  own solver skips. Undo keeps the tin as it was. Checked by random play
  on every band: 4,751 taps, 30,791 slides, never a gap nor a colour
  split; `_probe_buttons.gd` 648 runs, 0 failures; `_win.gd` buttons PASS.
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

## The aim, the shortcut and smaller buttons (2026-10-12)

The user: "improve and polish the jogability, add some helper to place the
piece even if user don't hit exactly above the cell, and add some shortcut
to send the piece to the case. Also, the buttons are too big, let's make it
bit smaller so user can see better the color below it".

- **The aim** (`aim(at)`, which `_gui_input` asks in place of
  `_cell_under`; press and release must aim at one square). Only with a
  pick in hand, and only for placing: a touch that lands on nothing at
  all -- linen, the border, a sewn button -- goes to the nearest bare patch
  of the pick's colour within `AIM_REACH` 1.5 squares of the finger (46 px
  on Insane whole, where a square is 30). **A square whose tap means
  something keeps it** but for the edge by the patch: on a button that can
  be picked, or a bare patch of another colour, a touch sews only within
  `AIM_EDGE` 0.7 of a square of the right patch's middle (a fifth of the
  way in), so a button's middle is still a pick, or the pick put down, and
  "That patch is another colour" is still said (the first cut gave a wrong
  patch the whole reach and so chose between two browns for the player:
  taken back the same day). Nothing in reach is what it was: the pick goes
  down. The tin, and what a zoom hides, are never aimed past. `tap(i)`
  itself is not changed: harnesses, probes and the tutorial tap squares.
  On Hard and Insane it can sew a patch the finger only neared; the patch
  is on the screen in its colour, so nothing is told that was hidden.
- **Two quick taps on a button send its run to the tin** (`TWICE` 0.35 s,
  `tap(i, true)`): the first picks it, or puts it down, as ever; the second
  on any button of that run goes through `tap_tin()`, so the count, Undo,
  the flights, the sounds and the haptics are the tin's own, and a full tin
  refuses and leaves the run picked. A slow second tap still puts the pick
  down. A pick put down by a tap and tapped again at once goes in too (any
  two quick taps on one run). The timer is cleared by any other tap, a drop or the tin. The
  board's own timing, not the engine's `double_tap` flag: `_gui_input`
  takes touches and mouse alike. `BB_RULES_TIN` and `HTP_BB_TIN_BODY` say
  so in en, pt and es; the tutorial does not play it.
- **A button is two thirds of its square across** (`Art.RIM` 0.335, was
  0.4; the face, dish, holes and shadow with it), so the patch shows all
  round it. `RIM` stays over the seat ring's 0.3: the ring says bare and a
  button must hide it. The tin's buttons keep their size (`TIN_FIT` 1.0 of
  a place, `TIN_RING`). The menu card and the tutorial draw the same piece.
- **Checked**: `tests/_probe_buttons_board.gd` has an aim section through
  `_gui_input` (Medium and Insane: two touches stow, a slow second drops, a
  touch beside a bare patch from every side aims at it and sews, a
  button's middle is its own and its edge the patch's, a far touch drops,
  an empty hand aims at nothing): 29 checks, the zoom and 28 days, 0
  failures. Rules probe 648 runs, 0; the suite 249,804. One window
  (`tests/_shot_buttons.gd -- d=3 big`, `opengl3_angle`, 810x1440): the
  monkey on Insane whole and close, buttons read as buttons at 30 px with
  the patch round each; 77 to 107 draw calls. `tests/_shot_buttons.gd --
  refuse` taps the first bare patch of another colour through the input
  path: at its middle, so it is still refused.
- **Not seen or owed**: a finger on a phone (the reach, the edge and the
  0.35 s are numbers off a desk); Easy and Medium on a screen at the new
  size; the menu card; the new lines read in pt and es.
- **Mine, not the user's**: two taps as the shortcut (not a long press or
  a flick, which a zoomed picture's one-finger pan would fight), and that
  **on Insane a slip of two taps is a counted move with no Undo**; the
  two reach numbers; that the aim never helps a pick, only a place; two
  thirds as "a bit smaller"; the tin's buttons left as they were.

## Hard is 16 square, and Insane counts nothing (2026-10-12)

The user: "the hard mode on button box is way too hard based on the
progress on easy and medium, also let's remove the limited moves on insane
for drawing games like button box". Asked which way, they chose 16-square
pictures for Hard and both picture boards (this one and Pixel Garden) for
the count.

- **Hard plays its own thirty pictures, 16 squares a side**
  (`content/buttons_hard.json`, `State.hard_pictures()`, `HARD` 2): the
  hand-drawn band that was the shared bank's Insane until the big pictures
  (git 19c96f98^), 87 to 168 buttons in 6 or 7 colours. It takes back
  "Hard is 24 square" for this board only: **Pixel Garden's Hard is still
  the shared bank's 24**. `BIG_FROM` is 3, so Hard has the old scramble
  (`CHUNK` 3-7), no zoom, no ZOOM page and no `BB_RULES_BIG`; it keeps what
  the user gave Hard before: no rings, two hints, Undo. Its buttons are the
  whole ones whatever the square (`lite` asks `_big()` too: 16 squares are
  44 px at 810 wide, on the edge of `Art.SMALL`). 25 `PG_PIC_*` names the
  big pictures had dropped are back in `locale/boards.csv`. A harness's
  `PG_BANK` is still played band for band.
- **`par` medians 17 / 31 / 72 / 370** (Hard 42-125; it was 241). Insane is
  still five times Hard: the user's choice of the four offered (the others:
  24 made kinder, cut-outs only, every band a step down).
- **No band counts its moves**: `State.moves_budget()` is 0, so Insane has
  Undo again (`capabilities` `["undo"]`), no bulb (`HINTS_BY` 0), no moves
  page, and its pill reads sewn of all (so "on Insane a slip of two taps
  is a counted move with no Undo", the section above, is no longer so). `COUNTED_FROM` is `INSANE`: the
  band of the seal for any day sewn. The board's counter, the out-of-moves
  card and `MOVES_BONUS` are still in the script for a budget over 0, and
  unreached. `BB_LVL_2` and `BB_LVL_3` reworded in en, pt and es.
  `tests/_shot_buttons.gd`'s `out` mode has nothing to show now, and `big`
  is Insane's alone.
- **Checked**: rules probe 864 runs (Hard's thirty, three seeds), board
  probe 38 days (six on Hard), the zoom (none on Hard) and the aim, 0
  failures; the suite 249,804. One window (`-- d=2 play`, `opengl3_angle`):
  a 16-square whale of 145, Undo and the bulb in the bar, no rings, 102
  draw calls at the peak.
- **Not seen or owed**: Insane with its Undo on a screen; the reworded
  level lines; the win harness and the perf probe, not rerun; a phone.
- **Mine, not the user's**: Insane keeping the seal for any day and no
  bulb; the dead counter left in the script; Hard keeping "no rings".

## Whole colours trade places (2026-10-12)

The user: "we must find a way to make the pieces for satisfacting, right
now everything is too sparse and spreaded, making the player to select one
by one, and all the satisfactory about the game is to see the pieces
reacting in chain", and then, asked what the order was: "what if we change
the shuffle logic, so we can pick for example all blues, and swap with red,
if still blue we pick the next color, and do it to the end", over a
screenshot of the game this board follows ("see how the game follow a
pattern? this way, player can relax because things usually chain
together"). "build it".

- **One scramble on every band** (`State._scramble`): the patches are read
  colour by colour -- the biggest colour first, the others in the day's own
  shuffled order, each colour a region at a time (`near()`) -- and the
  buttons are that same line moved along by the biggest colour's count. A
  colour's patches lie under the next colour's buttons, and where those run
  out the one after carries on. Nothing opens sewn unless one colour is
  more than half the cloth (then as few as can be: the redraw in `setup`
  stands). The lengths of 3 to 7 (`CHUNK`), Insane's strips
  (`_scramble_strips`) and `_trade_home` are gone; `BIG_FROM` now only
  means "zooms".
- **Measured before it was built**, the state's own hand over the whole
  bank, one seed a picture (a proxy for a player, and a greedy one: it
  keeps sewing singles while it can). Old to new, Easy / Medium / Hard /
  Insane: buttons opening alone 10 / 11 / 17 / 8 % to 5 / 2 / 4 / 1 %; the
  mean run at the opening 5.0 / 4.3 / 3.4 / 4.8 to 7.5 / 8.3 / 7.8 / 20.8;
  moves of one button 58 / 54 / 64 / 45 % to 42 / 34 / 45 / 35 %; buttons a
  move 2.3 / 2.5 / 2.1 / 2.9 to 3.3 / 3.6 / 3.3 / 4.8.
- **The day is about a third shorter**: par medians 12 / 22 / 42 / 223
  (were 17 / 31 / 72 / 370).
- **What was tried and is not the lever**: the picture cut into blobs of
  one patch colour, 4 to 7 buttons, blobs of one size trading round a ring
  (Insane's strips in two dimensions) left the moves of one at 57 / 52 /
  58 / 37 %. Sizes that must match leave remainders; whole colours never
  mismatch, since the run is nearly always longer than the stretch.
- **What is left is the tail**: a picture's small marks (an eye, an
  outline) are single patches whatever the scramble. Two rule changes were
  measured and **not built, the user's to call**: the tin emptying itself
  when a patch of its colour opens (with the swap: moves of one 12 / 12 /
  32 / 28 %; it takes back "nothing lands by itself", the user's own of
  2026-10-11) and a sew filling its colour's bare patches anywhere, not
  only those joined to the tapped one (a few points; that rule was my
  reading). All three, with a hand that stows again when sews fall under
  four: 6 / 6 / 11 / 10 %, about six buttons a move.
- **Checked**: `tests/_probe_buttons.gd` 864 runs, 0 failures;
  `tests/_probe_buttons_board.gd` 38 days, 0; the suite 249,804. Four
  windows, `rest` on each band on `opengl3_angle`: 84 / 84 / 84 / 91 draw
  calls. Seen in four stills of the opening; not played by anyone, no
  phone. A day in progress is not kept, so nothing saved is broken; today's
  deal changes for everyone.

## The toast is for a key event (2026-10-12)

The user, the same morning as the swap: "remove the annoying message that
keep showing after sending pieces around, no message needed at all if not a
key event". With whole colours trading, nearly every run is longer than the
tin, so "The tin was full: N stayed behind" came up on most moves.

- **Gone from the toast**: `BB_KEPT_ONE` / `BB_KEPT_N` (the rest of the run
  simply stays picked), and every refusal -- `BB_REFUSE_FULL`,
  `BB_REFUSE_PICK`, `BB_REFUSE_WRONG`, `BB_REFUSE_HOME`. A refused tap is
  the `locked` cue and the shiver, as before. The keys are left in the
  locale, unread.
- **Kept**: a colour whole (`BB_WHOLE`, `BB_WHOLE_OPEN`), and the lines
  that answer a button of the bar (`BB_HINTED`, `BB_RESET`). Mine: that
  those two count, and that a full tin needs no words.
- The aim's section of `tests/_probe_buttons_board.gd` counts 25 checks
  since the swap (29 before): the deals changed, not the aim.
- Board probe 38 days, 0 failures; the suite 249,804. Not seen on a screen.

## 2026-10-13: a big pick's ghost, and a tin as big as the picture

The user, off the phone: "on button box there is a issue where on harder
difficulties after selecting a color and sending buttons to another place,
they keep showing on the old spot till selection is undone. Also, the case
buttons box size should change based on the quantity of pieces to avoid
making it too small and harder images being annoying to fill, you can use
more than 2 rows if needed. Always round to floor even number, and blocked
ones should be all free after 4 color filled (1/4 each color)".

- **The ghost.** A pick of more than `HELD_BOB_MAX` (48) buttons does not
  bob: `_held_mesh` is built once and kept (`_held_still`). `tap` and
  `tap_tin` put what a move left in the hand into `_held_cells` and did not
  clear the flag, so the whole pick's mesh went on being drawn until the
  pick was put down. Only Hard and Insane have picks that long. **Anything
  that changes `_held_cells` or `_held_places` clears `_held_still`.**
- **The tin's size is the picture's** (`State.places_for`): a place every
  `CASE_PER` (5) buttons, rounded down to an even number, `CASE_MIN` (20)
  at the least and `CASE_CAP` (64) at the most. Half open; each of the
  first `CASE_WHOLE` (4) colours whole opens a quarter of the rest
  (`capacity()`, whole numbers rounded down, all of them at the fourth).
  `CASE_MAX`, `CASE_BASE` and `CASE_STEP` are gone; `state.places()` is the
  tin's length and `state.tin.size()`. It takes back "twenty places, ten
  open" and "a colour whole opens two" above. By band: Easy and Medium 20
  (32-100 buttons), Hard 20 to 32 (87-168), Insane 64 (455-1,024: every
  picture is at the cap). The tutorial's tin (`tin_base` 4) is its own: six
  places, both locked ones open with its one colour (`CASE_OWN`).
- **The rows** (`_layout`, `TIN_ROWS`, `TIN_SMALL`): the fewest rows that
  keep a place at three quarters of what it is ten to a row, four at the
  most. 20: two of ten. 22-26: two of 11-13. 28-32: three of 10-11. 64:
  four of sixteen (a place 61 px of a 1080 canvas, 96 on the small tins).
  A short last row is in the middle (`Art.tin_place`). Hard is bound by its
  height: three rows take its square from 60.6 to about 55 px; Insane's
  from 30.5 to 28.7.
- **Measured**: `tests/_probe_buttons.gd -- seeds=3`, 864 runs, 0 failures,
  par medians 12 / 22 / 39 / 161 (Hard was 45, Insane 223; with `CASE_PER`
  8, 12 or 16 Hard stays at 20 places and 45). `_probe_buttons_board.gd --
  days=4`: 26 days, 0 failures. One windowed run, `_shot_buttons.gd -- d=3
  play` on opengl3_angle at 810x1440: thirty-two red in a tin of four rows,
  113 draw calls at the peak.
- **Mine, the user's to call**: a place every five buttons; the cap of 64
  (so every Insane picture has the same tin); half open at the start, as
  before; the floor of 20, so Easy and Medium are as they were but for the
  quarters (10, 12, 15, 17, 20 where it was 10, 12, 14, 16, 18); a tin of
  22 opening at 11 (the even number is the whole tin's, not the open
  half's); longer rows before more rows.
- **Seen after the commit**: `_shot_buttons.gd -- d=2 refuse`, the koi pond
  (168 buttons): 32 places as rows of 11, 11 and 10, the short row in the
  middle, sixteen open and full, 87 draw calls.
- The ghost was not Hard's and Insane's alone: with motion reduced every
  pick stands still, so there it stayed drawn on every band.
- **Not seen**: the tutorial after the change, the ghost's fix on a
  screen, a phone. pt and es lines
  reworded by me, unread.

### The level card and the tools row (2026-10-13)

The last of the redesign's rows (`docs/agents/flat-screens.md`, "Every
board gets a world of its own"): this board was already a bleed board, so
it only gained `"level_card": true`. The top bar is back, the title, ? and
the gear; the levels stand where the day card was; Undo, the bin (it asks
first) and Hint are a row under them, greyed where the board has no such
capability. The board is told a span 130 shorter and lays itself in it as
before; its world was not redrawn. `opengl3_angle`, 810x1440: rest,
`tests/_win.gd` and `tests/_probe_level_slide.gd` all pass (the slide
writes the board's `position.x`: it has no `set_shift`, so its world
slides with it). Owed: a phone; whether its ground wants the richer foot
the later boards have.

- **A daily may deal a themed picture (2026-10-13)**: when this phone holds
  the day's `pictures` document, Button Box's daily takes its band's size from
  it in place of the bank's (`core/themed_pictures.gd`,
  `docs/agents/days-dashboard.md`, "The daily theme, stage 2"). New, the
  suite and every harness are the bank's as before.

  **Since 2026-10-14 the picture is any side within the band's range**
  (`ThemedPictures.RULES.side`: 10 to 18 at Easy, up to 40 at Insane), a
  shaded sprite kept at the squares it was drawn at; this board lays the
  side it is handed.
## Slots in the colour, joined, and a socket (2026-10-14)

The user, with a bead-art app's board beside ours: "colored has a really
good view of the board, let's use as reference to redesign the board itself
on button box, we keep the button but make it smaller, join the same color
slots to make it look more like a image, and show a better empty slot, so
the button slide in the slot and make it full when color is right, also the
slots color are not accurate, make sure the slot has the same color of the
respective button". Until then a patch was a rounded square with a rim and
a gap to its neighbour, in the button's colour washed 0.42 toward the linen
(`Art.dyed`), which is why the slots were not the buttons' colour.

- **A patch is its square in the button's exact colour, edge to edge**
  (`Art.patch` is now `Art.sewn` plus `Art.socket`: the same hair-over
  square a sewn button is, `Art.colour` with no wash). The patches of one
  colour join into one flat area with no rim or gap, so the picture reads
  as the picture from afar, and a sewn square is the same square with the
  socket gone under it. `Art.dyed`, `PATCH`, `PATCH_RADIUS` and the
  octagon `_cut` are gone; nothing else used them (the card and the swatch
  call `patch` with four arguments, as before).
- **The empty slot is a socket** (`Art.socket`, in place of `_seat`): a ring
  of `SOCKET` 0.235 of the square, `maxf(2, 0.06 cell)` wide, in the
  colour darkened 0.34 round a floor darkened 0.1, the floor set 0.018 low
  so the ring is thicker along the top, a recess lit from above. Bare and
  sewn still differ by a shape, never a shade alone. `lite` (the far look)
  cuts it in 12 sides, the near one 20. At 14 px a square (a 56-square
  themed Insane) it is a ring of 3.3 px, 2 wide: arithmetic, not seen.
- **The button is 0.56 of its square across** (`Art.RIM` 0.28, was 0.335;
  `FACE_R` 0.25, `DISH` 0.165, `HOLE` 0.032, `HOLE_AT` 0.059 with it), so a
  loose button of the wrong colour has the slot's colour all round it. RIM
  stays over SOCKET: a button hides the socket under it. The shadow is
  `SHADOW_R` 0.31 and `SHADOW_DOWN` 0.085 in both looks. The tin's buttons
  keep their size: `TIN_FIT` 1.196 (0.335 / RIM), `TIN_RING` 0.577 (0.69 /
  TIN_FIT).
- **A landed button settles into its socket, and on its own colour the
  square fills out from under it.** A flight to a patch now ends
  `SETTLE_DROP` (0.1 of a square) above the socket and still at
  `HELD_SCALE` (`_play`'s `k1`; `_draw_over` adds the hair); then
  `_build_live` draws it loose, sinking with `Motion.drop_in_lift` and
  coming down to size with the release's back ease over
  `Motion.RELEASE_TIME`, so it dips a hair past the socket and comes back.
  If it is home, the sewn square is then drawn over it, from the button's
  width (`2 RIM + 0.04`) to the whole square with the sine over
  `Motion.LIFT_TIME`; a square that only grows never overlaps its
  neighbours, which are flush now. The landing bump is gone from the cloth
  (the tin's stays). Reduce-motion: sewn at once, as before. The only new
  constant is `SETTLE_DROP`.
- **Draw calls unchanged in kind**: the still mesh is still one mesh (the
  patches join inside it), the blocks one each, the live buttons one.
  `opengl3_angle`, 810x1440, two windows: `-- d=3 big` (a 32-square cabin,
  110 sewn by the harness's own moves before the first shot) 143 at rest
  with the harness's rings and streak bubble still up, 156 in the frame of
  twelve moves at once, 98-121 close, to the tin, panned and whole again;
  `-- d=1 play` (a 16-square toadstool) 94 at the peak. One reading of
  each mode, not the second of two.
- **Seen** (those shots): Insane whole at 28.7 px a square -- the cabin
  reads as a picture, the purple, blue, brown and white regions flat and
  joined, the empty sockets as dark rings on the white and the purple, the
  plain buttons as small discs with the slot's colour round them; close at
  84 px -- the whole button with its holes, the sockets on blue and white
  as rings, the sewn squares flat and joined; Medium at 50 px -- the
  toadstool's outline, cap, spots and stem as flat regions, the sockets on
  the dark outline and the white stem, a pick lifted, twelve sewn as flat
  squares. The settle and the fill were not caught by a shot (the play
  mode's frames fall in the flight, not the landing): `_shot_buttons.gd`'s
  `play` now shoots once more 0.45 s after the place, for the next run. A
  throwaway headless check called `_build_live` at 0.05, 0.2, 0.3, 0.36
  and 0.5 s after a landing on a home square and a wrong one: loose and
  shadow through the settle, the sewn square added through the fill, both
  back to their blocks after.
- **Checked**: `tests/_probe_buttons_board.gd -- days=4`, 26 days, the zoom
  and the aim, 0 failures; the suite 249,565 passed, 0 failed.
- **Not seen or owed**: the settle and the fill in motion; the socket at 14
  px (no bank picture is under 28.7 px a square; only a themed 56-square
  day gets there); the menu card at the new sizes (`ui/menu/cards/
  buttons.gd` and `card_art.gd`'s swatch draw the same `patch` and parse;
  not shot); the socket on the darkest colours (`dark` 4a3226's ring is
  the colour darkened 0.34: readable in the Medium shot's outline, faint);
  the tutorial; a phone.
- **Mine, not the user's**: a ring as the socket rather than a dimple or an
  inset square; 0.56 as "smaller"; the sizes of the socket and its tones;
  the settle over RELEASE_TIME and the fill over LIFT_TIME; the tin's
  buttons kept at their size; no bevel between squares of different
  colours (the reference has a light bevel a bead; ours are flat, as the
  sewn squares already were).

## The gem tile (2026-10-14, afternoon)

The user: "on button box, make the button in a more diamond shape rather
than plain rounded so it can fill a bit more of the square, and make it bit
bigger, to not let user guess so easy what is the picture early"; then,
over a first cut as a rhombus, a picture of a pixel butterfly made of
faceted square gems: "a shape like this, not a triangle"; then, over a tile
0.92 of its square: "smaller, it's too big, keep it like 80% of the cell";
then "make the case slots follow the same button shape, not circle" and
"same for the slot of empty cells on the picture".

- **A loose button is a gem tile** (`ui/faces/button_art.gd`: `tile`,
  `facets`, `button`, `button_lite`): a rounded square `RIM` 0.4 out from
  its middle to each side (0.8 of its square across, 0.64 of it covered;
  the round button was 0.56 across and 0.25), its corners rounded by `TIP`
  0.1, four bevel facets from its edge to a flat centre face `FACE` 0.22
  out (`FACET`: the top lifted 0.2, the sides 0.06 either way, the bottom
  sunk 0.22), a pale sliver of gloss on the face's top left, the four
  holes in the face (`HOLE_AT` 0.085). The patch's colour shows as a thin
  border round it, so the picture is harder to read with the buttons on.
  The plain look of a big picture whole is the tile with its facets and no
  holes, its sewn cross as before; close it is the whole gem. The shadow is
  a tile too (`SHADOW_R` 0.41). The tin's buttons keep their size
  (`TIN_FIT` 0.838, `TIN_RING` 0.824). The menu card's go button draws its
  chevron on the tile's face.
- **The tin's hollows and the bare patch's socket are the tile's shape**
  (`tin`, `socket`): a square recess, the unopened places a square outline.
- Read on `opengl3_angle`, 810x1440: Medium play peak 106 draw calls (92
  before), Insane's picture whole at rest 149 and close 97 to 101;
  `tests/_probe_buttons.gd` 756 runs, 0 failures. Shots at
  `tests/_shot_buttons.gd -- d=1 play` seen by me, not yet by the user on a
  phone.

## The socket back on a bared patch, and Hard zooms (2026-10-14, evening)

The user, with a phone shot of Insane mid-play: "on Button box there is a
bug where the slot is not showing, the purple is empty and it show as
filled, and the hard mode should have a zoom feature just like insane".

- **The cut tile forgot its centre** (`Art.tile` with `fine` false, the
  eight-point tile of 2026-10-14 afternoon): its points were laid about the
  origin, never moved to `at`. Every other use builds a unit about the
  origin and places it by transform (the lite button's under-tile, face
  and shadow in `units`), so those drew where they belonged; the bare
  patch's socket is the one tile built in place (`_build_still`, a cell's
  centre handed in), and on every big picture (`_cell` under `Art.SMALL`,
  Hard and Insane) all of its sockets lay in a heap at the cloth's top
  left corner. A bared patch was a flat square, the same as a sewn one:
  "filled". Reproduced on this Mac with `tests/_shot_buttons.gd -- d=3
  big` (the run lifted to the tin bared flat squares) and with a
  throwaway probe printing the socket's vertices at 15 and 24 px (all
  about (0, 0)). The tile now adds `at`, and its points run round in one
  direction: before they zigzagged at each corner (a bow-tie the fan still
  mostly covered, with a notch at each corner). The 44 px and over socket
  (`round_rect`) was never wrong, so Easy and Medium showed theirs.
- **Hard zooms** (`State.BIG_FROM` 2): the zoom button at the room's foot,
  the pinch and the one-finger pan, the picture cut to its room when
  close, the "Come close to a big picture" rules line and the tutorial's
  ZOOM page, all as Insane has them. Hard deals the bank's 32s since the
  morning (`BANK_BAND`), so its squares are 24 px on this screen and were
  not pickable by sight without it. `tests/_probe_buttons.gd` plays Hard
  one seed now, as a big band (its `band < BIG_FROM` test); 648 runs, 0
  failures.
- Read on `opengl3_angle`, 810x1440: Insane `big` whole at rest peak 149,
  close 97 to 101 (as before); Hard `big` on a 40-square themed day (the
  Mac's, 1128 buttons) whole at rest peak 225, going close 240, close 91
  to 102; the Hard tutorial's five pages peak 157. Bared patches in the
  `big` shots show the sunk ring on blue and white (they were flat in the
  same shot before the fix). Not on a phone.

**2026-10-15, a pick out of the tin outlived the pack** (the user: "after
placing a piece it stays showing as available on the case till I click
outside, making impossible to keep playing because it says i don't have
the color on case even tho i have"). A sew out of the tin that left some
of the colour picked kept `_held_places` as the places they had before
`State._pack` slid the tin down, so the pick pointed at another colour or
at nothing and the next sew was refused as the wrong colour. The kept pick
is now `state.tin_of(_held_c)`, and a SLIDE whose end is a picked place
draws no hop (the button hangs over it). `_probe_buttons_board.gd` caught
it before the fix (five days stuck, a pick held, not run for c53bcbe6) and
finishes every day after; its two `zoom` failures on band 2 are there with
and without the fix.

## A pale socket on a dark patch (2026-10-17)

- **The user**: "since the empty slot is dark, when there is empty slot on
  darker backgrounds colors, it's impossible to see". The socket's ring was
  the patch colour darkened 0.34 (owed since 2026-10-14 as "faint" on
  `dark`). Under `SOCKET_DARK` (0.42 luminance: dark 0.21, navy 0.30,
  maroon 0.32, brown, forest and purple 0.40) the ring is the colour
  lightened 0.34 and the floor darkened 0.22, a pale lip round a sunk
  floor; every other colour is as it was. Still a shape, not a state told
  by a shade alone. `Art.socket` is shared, so the menu card's swatch
  follows.
- **Checked**: a throwaway sheet of every bead colour's bare patch at 40
  and 60 px, windowed: the ring reads on all six dark ones. Not seen in a
  game with a bare dark patch, nor on a phone.
