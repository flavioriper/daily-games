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
