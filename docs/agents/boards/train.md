# Toy Cannons (built as Toy Train)

- **Toy Train is the thirty-eighth card** (2026-10-12, `puzzles/train2d.gd`,
  `puzzles/train_state.gd`, `ui/faces/train_art.gd`; no spec and no concept
  tab -- asked for from a screenshot and built in one sitting, "do
  autonomous, no questions"). The web game it follows is Pixel Blast (the
  phone game of the same genre is Pixel Flow), and **those names go nowhere
  else**: not in code, comments, commits or on screen. The puzzle id is
  `train` and the locale prefix `TT_`.
- **The rules, as the screenshot showed and the store pages say** (the
  game's page says only that cannons shoot blocks of their own colour and
  the conveyor must not be overloaded; the listings of its genre add the
  ammo number, the five waiting slots and the belt's limit of five). **One
  rule was not found written anywhere and is mine**: a shooter hits only the
  nearest block of the line it is passing. Ours, name for name: the rug and
  its blocks, the loop of track, an engine and its number, the siding, the
  shed.
- **One move**: tap an engine -- the front of a column of the shed, or one
  waiting in the siding. It goes once round the loop, the foot left to
  right, up the right side, back along the top and down the left. At every
  stop it looks straight across the rug and takes the nearest block if that
  block is its colour. Its number is the blocks it has room for. Full, it
  pops off the track for good; round with room to spare, it waits in the
  siding (5 places). At most 5 engines are on the loop, the gate counted
  (`ON_LOOP`), two stops apart as they enter (`GAP`).
- **The loop moves by ticks**, a stop a tick (`State.tick()`, which returns
  what happened: ENTER, PICK, RUN_END, FULL, PARK, HOME, JAM, WHOLE), so the
  same taps on the same ticks play the same game and a probe with no screen
  can prove a deal. The screen keeps the clock (`TICKS`, 0.085 to 0.065 s a
  stop: a lap is about four seconds on every band) and draws an engine
  rolling up to the stop the tick has it at.
- **A siding that is full**: on Easy to Hard an engine with room rolls to
  the back of its own column of the shed (HOME; a toast the first time), so
  **nothing can be stuck and those bands cannot be lost** -- a wanted engine
  buried in a column comes to its front by sending the ones before it round.
  On **Insane the day is lost** (JAM: the shared card with its own words,
  `TT_OUT_*`; its video sends the siding's engines back to the shed, once,
  `State.rescue`). That is the game's own ending and not a count of moves
  ("Insane counts nothing", `docs/agents/flat-screens.md`); the user has not
  ruled on it.
- **The picture** is one of Pixel Garden's bank by this board's own seed:
  10 square on Easy, 12 on Medium (`content/pixel_garden.json`'s first two
  bands), 16 on Hard and Insane (`content/buttons_hard.json`). **Every bare
  square is a block too**, of one more colour the picture does not use
  (`MATS`, the sky first), so the rug is full edge to edge as the
  original's is: 100, 144 and 256 blocks.
- **The deal is built by playing the picture away** (`State._deal`): an
  engine of a colour the loop can see, a load out of the band's range
  (`LOADS`, 3-9, 4-12, 6-18, 8-24) and never more than its colour has left
  unspoken for; one that cannot fill in a lap waits in the line's own
  siding and goes again as soon as it can take anything. A colour's loads
  add up to exactly its blocks. The line never holds more than `REF_PARKED`
  (1, 2, 3, 4) in the siding, and on Medium up (`EARLY`, 0.15, 0.25, 0.4) it
  sometimes stands an engine in the shed before its colour is in sight, so
  that one has to come out and wait. The engines stand in the shed's
  columns (2, 3, 3, 4) in the line's order, the columns kept even. The
  line is `State.line` and its length the par; it is a way to win, not the
  shortest.
- **Proved headless**: `tests/_probe_train.gd` deals every picture of every
  band off a few seeds and plays each four ways -- the line an engine at a
  time, the state's own hand (`hint`) an engine at a time, the same hand as
  fast as the loop lets it, and a careless one. 960 runs at `seeds=2`, 0
  failures: the line wins every deal in its par, Easy to Hard are won every
  way, and Insane is lost by the careless hand on 38 deals of 60 and by the
  greedy one on 36 (6 when it juggles the loop). 15-27 engines a deal, the
  slowest deal 27 ms on this Mac.
- **`State.hint` is a greedy hand**: of the engines a tap can send, the one
  that would take the most alone on the rug as it lies (one that fills
  first, the siding's before the shed's); with nothing to take, the front
  of the column whose wanted engine is nearest. The bulb (3 / 3 / 2, none
  on Insane) sends it. **No Undo on any band** (the loop runs on a clock)
  and no Check; Reset is the rug as it opened.
- **A `bleed` board** (the third): the playroom floor is the whole screen,
  the rug as big as the room between the pill and the yard allows (a
  square is 62 at the most; 51 on Easy and 36 on Hard at 810x1440), the
  siding and the shed at the foot, three rows of the shed seen and a count
  under them. `"tip": false`; the toast, over the pill, says a full loop,
  the first engine sent back to the shed, the bulb and Reset. A post by the
  gate counts the loop (`2/5`, rose when full).
- **Drawn as** `_bg` (the floor), `_yard` (the siding and the shed), `_ring`
  (the rug, its stitching and the track), the blocks one mesh rebuilt when
  one is taken (unit meshes a colour through `Face.FlatBuilder`), the
  engines one mesh a frame while anything moves, and a number an engine.
  **103 draw calls idle and 115 at the peak of a Hard day on
  `opengl3_angle`** (`tests/_probe_perf.gd -- train d=2 x=buzz`, one run).
  An engine's state is its number and where it stands, never a shade of its
  colour. No character: the pieces are toys.
- **Motion that is this board's own**: an engine hopping from the shed to
  the gate and from the gate to the siding (`_glide`, from where it was last
  drawn), the column closing up behind it; a block flying to its engine and
  the engine's bump as it lands; a full engine swelling and popping off the
  track with a puff and a ring; the run's bubble over the engine from the
  third block in a row, confetti at ten, fifteen and twenty; sparkles round
  the loop for a colour whole; and the win: the yard put away and **the
  picture put back whole from its middle outward**, then slid to the middle
  of what the win screen leaves, the seal for a day in no more trips than
  the par, or any Insane one.
- **Sounds** (`SETS["train"]`, seventeen cues, no new take: Lattice's light
  wooden button, its hollow block and its one kalimba note, and Hedgehogs'
  breath). `pick` once a block, climbing a major scale a block along a run
  and an octave at the most (`RUN_SCALE`); `run` two notes for a run of
  five or more; `full` two tocks as an engine goes home; `combo` one note
  the board pitches up along engines home full one after another, none
  parked between; `whole` three rising; `send`, `park`, `home`, `locked`.
  `tools/measure_sfx.py train`: 0 of 17 flagged. Unheard.
- **Harnesses**: `tests/_shot_train.gd` (rest, play, refuse, hint, solve,
  jam, reset, restore, howto); `tests/_probe_train.gd` (headless, the
  rules); `tests/_win.gd -- train` wins through the input path with a
  buried engine tapped and the bulb on the way; `tests/_probe_perf.gd --
  train`.
- **The tutorial** (`ui/hud/train_tutorial_diagram.gd`, four pages played
  by the board on two hand-made rugs, the yard beside the rug): send, only
  the nearest block, the siding, and the bulb or on Insane the warning.
- **Not seen on a phone.** Shots and probes on this Mac only: play on Easy,
  a Hard day to the win, Insane's jam, the tutorial. `refuse`, `hint`,
  `reset`, `restore` and motion reduced were not shot. The sounds are
  unheard by the user; the pt and es lines are unreviewed (locomotiva /
  locomotora, desvio / apartadero, galpão / cobertizo).
- **Calls made without the user** (2026-10-12): the name and the toys; the
  line-of-sight rule; a block a stop; a full engine leaving at once; the
  mat of blocks under the picture; pictures of 16 at the most (24 would be
  27 px a square); the loads and the shed's columns; back to the shed on
  Easy to Hard and the lost day on Insane; no Undo; the lap of four
  seconds; the original's boosters and its shooters that take two slots
  left out (the bulb is the hint).

## 2026-10-13: a shooter, small blocks, fast

The user, off the build: "on toy train after easy, the blocks to be destroyed
should be really small, the whole game idea come from destroying a lot of
things. Also, we need to change it to be something that shoot, like the
original game, not a train, and it should shoot way faster". **Everything
above this heading is the board as it was built; where the two disagree this
section wins.**

- **The title is Toy Cannons** and the toy is a little cannon on two wooden
  wheels that fires corks (`Art.engine`, `Art.cork`). **The id is still
  `train`, the locale prefix `TT_`, the files `train*.gd`, and the names in
  code the train's**: an `engine` is a cannon, its `room` the corks it has
  left, the `siding` the tray it waits in, the `shed` the toy box. The heads
  of `train2d.gd` and `train_state.gd` say so. A full rename (id, saves,
  sound folder, analytics) was not done; it is the user's to ask for. On
  screen and in all three languages: cannon / corks / tray / toy box
  (canhão, rolhas, bandeja, caixa; cañón, corchos, bandeja, caja).
- **The rules did not change**: one shot a stop at the nearest block of the
  line, if it is the cannon's colour; five on the loop, five in the tray.
- **Pictures** (`State.BANDS`, the band of `content/pixel_garden.json` a
  difficulty deals from): Easy 10 square as before, **Medium 24 (576
  blocks), Hard and Insane 32 (1,024)**. `content/buttons_hard.json` is no
  longer read here. Those pictures have no bare square, so no mat is laid.
  A square is about 26 px on Medium and 18 on Hard in an 810 window
  (measured off the shots).
- **Loads** (`LOADS`): 3-9, 10-36, 16-60, 20-80. 25-39 cannons on Medium,
  29-46 on Hard, 21-35 on Insane; the deal's own line is 56-82, 89-173 and
  92-166 laps. The gap between two cannons entering is a band's (`GAPS`, 2,
  4, 5, 5 stops).
- **The clock** (`TICKS`): 0.045, 0.024, 0.02, 0.02 s a stop, so a lap is
  about two seconds on every band (it was four) and a cannon fires 22, 42
  and 50 corks a second.
- **The shot**: a cork flies from the muzzle to the block (`PICK_FLY`,
  0.06 s), the block stands until it lands and then bursts where it stood
  (`BURST`, growing and fading), and the cannon kicks back (`RECOIL`).
  Nothing flies to the cannon any more. A cannon on the loop points across
  the rug, square to the track (`_heading`). Motion reduced: the block is
  gone and nothing flies.
- **The track keeps its size on small squares**: a lane (`_lane`) is a
  square but never under `LANE_MIN` (34), and the rug's edge, the track's
  reach and gauge are in lanes (`_edge`, `_reach`); a cannon on the loop is
  60 long at the least (`LOOP_MIN`).
- **The blocks are a mesh a patch** of 8 squares a side (`CHUNK`,
  `_draw_blocks`): a block shot rebuilds its patch, not the picture. Under
  30 px a block is two plain squares (`Art.SMALL`). The opening and the win
  are still one mesh a frame. **95 to 119 draw calls on Medium, 106 to 118
  on Hard, in play on `opengl3_angle`** (`tests/_shot_train.gd -- d=1|2
  play`, one run each).
- **Sound**: no new take. `pick` is asked for once in 60 ms however many
  corks land (`PICK_GAP`: `fx.cue` holds the sound but knocks the phone
  every time it is asked), and climbs its scale a step every 1, 3, 4, 4
  blocks (`RUN_STEP`). The run's bubble is from 5, its two notes from 12,
  confetti at 20, 40 and 60.
- **The deal** keeps how deep each stop has looked (`_seen_from`): the
  slowest deal is 63 to 69 ms on this Mac (it was 91 before the cache, on the
  same pictures).
- **`State.hint` minds the tray**: a cannon that would empty first, then
  one out of the tray, and no new one that would come back when four
  places are taken. With it Insane is lost by the hand an engine at a time
  on 7 deals of 18 and by the juggling one on 2; the careless hand loses
  all 18 (it lost 38 of 60 on the 16-square pictures). Easy to Hard are won
  every way. `tests/_probe_train.gd -- seeds=1`: 336 runs, 0 failures (it
  takes a minute now; `band=` plays one).
- **Proved**: suite 249797/0; `tests/_win.gd -- train` PASS on Medium (74
  sent, par 85); two windowed runs, Hard and Medium in play.
- **Calls made without the user**: the name and the toy; Medium at 24 and
  not 32; the loads; the lap of two seconds; one cork a stop kept (a shot
  that went through a run of its colour would clear more a lap, and is not
  the original's rule); the old wooden tock for a shot; the share text is
  the whole picture, 32 lines on Hard.
- **The tutorial keeps the old clock** (`LESSON_TICK`, 0.085 s a stop, in
  `train_tutorial_diagram.gd`): at the day's a rug of twelve stops was gone
  round before its caption was read. Seen on Insane's four pages
  (`tests/_shot_train.gd -- d=3 howto`).
- **Not seen**: the menu card with the cannon on it, the
  win on a 32 picture, Insane's jam, motion reduced, a phone. pt and es are
  unreviewed.

## 2026-10-13, later: a cannon stays on the loop

The user: "after canon is placed, keep it looping on the path instead of
doing just one run". **This section wins over the two above.**

- **A cannon sent goes round and round** for as long as a lap hits
  anything (`State.got`, the blocks since it last passed the gate; `tick`
  puts it back at stop 0 with its run unbroken). Out of corks it is done, as
  before. **A whole lap with nothing hit sends it to the tray** (and on
  Insane, with the tray full, loses the day): that is mine, so a cannon
  whose colour is buried does not hold one of the loop's five places for
  ever. The user asked only for the looping.
- **The deal and the hint play the same rule** (`_laps`: laps until one
  takes nothing). Cannons mostly empty in one send now, so the line is
  short: 31-48 sends on Medium, 44-67 on Hard, 39-60 on Insane (they were
  56-82, 89-173, 92-166).
- **Insane is easier for it**: the hand a cannon at a time loses 4 deals of
  18, the juggling one none, the careless one 5 (it lost all 18).
  Not retuned.
- **The deal is slower**: 114 ms the slowest on Hard on this Mac (a lap a
  colour became several). Not measured on a phone.
- `tests/_probe_train.gd -- seeds=1`: 336 runs, 0 failures. Suite
  249797/0. `tests/_win.gd -- train` PASS on Medium, 36 sent, par 40. The
  rules, the tutorial's bodies and one caption reworded in en, pt and es;
  the motto is "Round and round, pop".
- **Not seen**: a cannon coming round the gate's bend into a second lap, the
  tutorial after the change, a phone.

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
  the day's `pictures` document, Toy Cannons's daily takes its band's size from
  it in place of the bank's (`core/themed_pictures.gd`,
  `docs/agents/days-dashboard.md`, "The daily theme, stage 2"). New, the
  suite and every harness are the bank's as before.

  **Since 2026-10-14 the picture is any side within the band's range**
  (`ThemedPictures.RULES.side`: 10 to 18 at Easy, up to 40 at Insane), a
  shaded sprite kept at the squares it was drawn at; this board lays the
  side it is handed.
## 2026-10-14: more to see of a shot

The user: "polish and improve the toy cannon, the good part of the game is
seeing a lot of particles and things being destroyed fast, so we need way
more pixels, animations, pop sfx sounds, shoots, also increase the space
between the cannon and the drawing, it's too close user barely see the
shoot". **This section wins over the ones above where they disagree.** The
rules did not change: `train_state.gd` is untouched, and so are the bands,
the loads, the clock and the deal.

- **The open rug.** The track's reach is 2.4 lanes off the picture
  (`REACH`, it was 0.95) and the rug's edge 3.15 (`EDGE`, 1.85), the lane
  now clamped between `LANE_MIN` 34 and `LANE_MAX` 40 canvas pixels so Easy's
  big squares do not open a border of their own. Read off the harness's new
  `layout:` line (canvas units, 1080 wide): **the muzzle stands 52 off the
  picture's edge on Medium and Hard and 66 on Easy; it stood 2 and 14.** The
  yard gave the room back: a cannon at rest is 84 long (`REST`, 92) and the
  gaps 14 (`GAP`, 18), so the rug is 867 square where it was 830 and a
  square lost little: Medium's 24 is 27.2 (29.3), the 40-square themed day
  16.3 (17.6), Easy's 10 is 61.5 (60.6).
- **What a shot leaves** (`_draw_shot`, all of it appended to the frame's
  one mesh with the cannons: fifty shots a second would starve `fx.puff`'s
  pool of four, so no particle node is used for anything that comes with a
  shot). The cork flies for 0.09 s (`PICK_FLY`, 0.06) with two ghosts behind
  it (`TRAIL`); the muzzle flashes a pale disc for 0.05 s (`FLASH`) and lets
  a wisp of smoke drift out and fade over 0.32 (`SMOKE`); the cannon kicks
  back 0.22 of its length (`RECOIL_PX`, 0.12). The block still bursts where
  it stands and, with it, **five shards** (`SHARDS`) fly on along the shot,
  flat squares of its two tones a quarter to half a square across, spun,
  pulled down at 900 px/s² and faded over the last two fifths of 0.42 s
  (`SHARD_*`). A colour whole throws confetti over the rug as well as its
  sparkles; an emptied cannon's puff is ten stars and its ring bigger.
  Motion reduced: nothing flies, as before.
- **The sound is two** (`docs/agents/sound.md`): `shoot` as the cork
  leaves and `pop` as the block bursts, once in 70 ms however many corks
  fly (`PICK_GAP`), the pop climbing five steps at the most (`RUN_SCALE`,
  it was an octave). `shoot` is asked for with the knocks off so a shot is
  one knock, the pop's tick (`HAPTICS`).
- **Measured** on `opengl3_angle` at 810x1440, one run each: Hard play 135
  draw calls at the peak (111-123 on the shots), Medium play 111, Easy at
  rest 89, the Hard tutorial 151. `tests/_probe_train.gd -- seeds=1` 0
  failures; `tests/_win.gd -- train` PASS (Medium, 35 sent, par 32).
- **Mine, the user's to call**: the gap's size (fifty canvas pixels, about
  the cannon's length), five shards a block, the smoke, the yard made
  smaller to pay for the rug, and the pop as a hollow block's tock (a cork
  drawn from a bottle and a cork on felt both failed the cozy measure).
- **Not seen**: the shards and the smoke in motion (shots only), a phone,
  the sounds heard, Insane, reduced motion, the win and the jam after the
  change. A `Parse JSON failed ... getting token` line prints in every
  windowed run of the harness, on main before this change too.

## 2026-10-26: made fun -- bold colours, corks that go through

The user: "I want your help to make toy cannon experience way better to
play, and game itself way funnier to play, right now nobody likes it. Use
web for reference on how good games does it. Do it autonomous". **This
section wins over the ones above where they disagree.**

- **What was wrong, measured** (a throwaway probe playing the state's own
  hand as fast as the loop takes it): a cannon on the loop hit a block at
  **12% of its stops on Medium and 9% on Hard**; the rest of every lap was
  rolling. Pictures past Easy had 9 to 12 colours, half of them shades of
  another (white, cream and silver; red, coral, rose and maroon; three
  greens), so a cannon's colour was hard to tell from the next one's and few
  of a colour were ever on the outside. On screen the cannons on the loop
  were 60 px with 16 px numbers. The web had little: the genre's listings
  sell "every hit leaves the board crisp", fast one-tap sessions and the
  tray as the only pressure; players' complaints are repeated levels and
  ads, not the rules.
- **Bold colours** (`State._bolden`, `FAMILY`, `BOLD`): a picture's beads
  are folded into their families (white/cream/silver, red/maroon,
  pink/coral/rose, orange/rust, yellow/butter, lilac/purple, blue/navy,
  greens, tan/brown), then the two nearest families (redmean RGB,
  `_apart`) into one, the smaller into the bigger, until **4, 6, 7, 8**
  are left (Easy to Insane). Nearest-first keeps an eye or a beak; folding
  the rarest first lost the duck's beak. Only `adopt` folds: the
  tutorial's hand-laid rugs (`adopt_laid`) keep their legend. Themed days
  fold the same.
- **A cork goes through** (`State.pierce`, `_stop`, `_lap`): at a stop the
  cannon takes the nearest block if it is its colour, then the next nearest
  while that is its colour too, a cork a block, while it has corks. The
  deal and the hint play the same rule, so a colour's loads still add up to
  its blocks. A PICK carries how many came before it that stop; the screen
  sends that cork `VOLLEY` (0.028 s) later, the block standing until it
  leaves, so a stop is a stream of corks down a row.
- **Measured after** (same probe): hits at **48% of stops on Medium and 46%
  on Hard**; the fast hand clears Medium in 6.5 s and Hard in 9.7 s of loop
  (24 and 45 s before); 88 and 105 blocks a second (24 and 23).
  `tests/_probe_train.gd -- seeds=2`: 672 runs, 0 failures; sends 27-41 on
  Medium, 35-62 on Hard; the slowest deal 39 ms (it was 114).
- **Insane** stands more cannons in the box before their colour is in sight
  (`EARLY` 0.7, it was 0.4): with piercing at 0.4 the careless hand lost 1
  deal in 18; at 0.7 the hint's hand a cannon at a time loses 3 of 36 and
  the careless one 3. The tray is still the only way to lose.
- **The screen**: a cannon on the loop is 74 long (`LOOP_MIN`, 60), its
  number 0.3 of it (0.27); the rug's edge and the track's reach grew to
  hold it (`EDGE` 3.5, `REACH` 2.6), the muzzle still 51 px off the
  picture. A block bursts white for the first 45% of its burst (`BLINK`).
  **The room shakes** (`_shake`, board's own): 5 px when a cannon empties,
  11 when a colour is whole, dying over 0.32 s, none under reduced motion;
  the rug, the blocks, the yard and the cannons shake, the floor does not.
  **A halo** (`HALO`, pale sun, never the cannon's own shade) under every
  cannon a tap can send whose colour some stop sees now (`_in_sight`,
  rebuilt when a block goes). **The end runs faster**: with nothing left in
  the box or the tray the loop's clock is 0.55 of the band's (`ENDGAME`).
  Small blocks (under 30 px) have a seam on the right as well as the foot,
  so a field of them reads as blocks and not as ruled paper. A run's two
  notes from 24 (12), confetti at 25, 50, 100, 150.
- **Words**: `TT_RULES` and `HTP_TT_LINE_BODY` say the cork flies on
  through a row of its colour, in en, pt and es.
- **Measured on screen** (810x1440, one run each): Medium play peak 120
  draw calls, the Hard tutorial 155, Hard at rest 110; Hard play 147 on
  `opengl3_angle`, the same as on desktop gl. `tests/_win.gd -- train` PASS (Medium, 32
  sent, par 38). Suite failed=0.
- **Mine, the user's to call**: the pierce rule itself (the genre's is not
  written anywhere I found); the colour caps and folding a picture's shades
  together (a shaded picture loses its shading); the halo, which tells
  which cannons can hit now; the shake; the faster end; Insane's `EARLY`.
- **Not seen**: a phone, the shake and the volleys in motion (frames only),
  the sounds at the new rate, pt/es read by a reader, reduced motion.
