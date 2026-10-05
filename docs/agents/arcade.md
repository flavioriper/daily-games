<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Arcade

**A fifth tab since 2026-09-27**, between Versus and Stats: games played
alone for a score (spec `2026-09-27-arcade-firefly-design.md`). Like Versus
it is not a registry entry: `ui/menu/arcade_tab.gd` holds one card a game,
`ui/menu.gd`'s `_open_arcade` mounts the game's own screen and closes back
to the tab, and the screen joins the `versus_host` group so Android's back
reaches it. Scores live in `user://arcade.cfg` (`arcade/arcade_record.gd`).

**Three games left for a side project on 2026-09-27**: Hedgerow TD (a path
tower defence), Henhouse (an egg-farm idle clicker, the one timed record)
and Millstream (a factory builder), with Ant March (an incremental gate
runner, built that afternoon and never merged here), went to
`~/dev/garden-games`, a full copy of this repo at `9b55e2c` renamed "Garden
Games" with no git remote, to become a game of its own for the longer
genres (its `SIDE_PROJECT.md` says what is there). Their code, sounds,
harnesses, specs, locale keys and `arcade_record.gd`'s `add_time()` went
from here. Three lessons they taught every harness still apply: **a
harness's mouse events are in window coordinates** (map a canvas point with
`root.get_final_transform()`, or it lands 0.75x off at 810x1440); **a
harness that sends a mouse press must send its release**, wheel included,
or the next press lands on the old mouse-focus control; and **an
autowrapping Label resized in the frame its text changed measures at its
old width** and comes out thousands tall.

**Firefly is the first**: a formation shooter after Namco's 1981 game,
which the spec names once to forbid; **it is called Firefly and nothing
else**. A firefly against gnats, ladybirds and moths in a night garden,
with the arcade's rules kept (two volleys, looping entrances, escorted
dives, a moth's silk beam that carries your ship off and a rescue that
makes a pair, a flyby bonus stage third and every fourth after).

- **The game is pure data** (`arcade/firefly_sim.gd`, field units, fixed
  1/120 s). `tests/_probe_firefly.gd -- [seed] [minutes] [skill]` plays it
  with a bot and tallies the events; run it after touching the sim.
- **The cast is built once and turned by the transform**
  (`arcade/firefly_art.gd`, cached per look, frame and scale), shared with
  the tab's banner. One `draw_mesh` a bug; 101 draw calls with the swarm
  seated since the polish (82 before), 101 on the tab (810x1440).
- **Rewards made loud on 2026-09-27** (the spec's section 9) through
  `arcade/rewards.gd`, the sticker-and-bits kit lifted into one layer that
  Firefly and Molehill share: kill scraps and stars to the score, a chain
  of kills worded (Nice! to Legendary!) with a warm edge glow, Escort bonus,
  Saved!, Double fire!, Clear!, a flyby bonus, Extra firefly!, milestones,
  a new best, and an end card that counts up. **Sunbursts over the night
  sky are added (`set_additive`), not laid over**: laid over, pale gold
  read as grey haze. 93-156 draw calls in play, ~420 at a forced pile-up.
- **Polished on 2026-09-27** (the spec's section 8), screen-side only: a
  leaning, recoiling firefly with a wake, bobbing and squashing seats, a
  wriggle into a dive, kill bursts, shake and hit-stop on a lost firefly,
  a better beam, a swaying, living garden. The grass, clouds and stars are
  built once and moved by transform: laid into the live mesh they cost
  4.65 ms a frame on this Mac, now about 1 ms.
- **A slide, not a spot**: the firefly follows the finger's movement at
  1.35x, and holding fires.
- **Haptics** (2026-10-03, `docs/agents/haptics.md` row 33): the sim's
  events ask through `_feel(kind)` and the frame knocks once with the
  strongest (`_knock_now`); only the end card's `new_best` is a mapped cue.
  `tests/_probe_arcade_buzz.gd -- firefly [rm]` plays a run through the real
  screen with a bot (`SECS`) and prints each event against what landed; it
  overhears `_play_events` through a subclass made at run time, which the
  next Arcade games can reuse where they have that function.
- **A wrapped Label hidden before its first layout measures thousands of
  pixels tall** (it has a width of one), so the tab's fit measures its lines
  off the font instead. The Versus tab reads its labels and may have the
  same trouble.
- Sounds take a new style in `tools/gen_sfx.py`, `ARCADE` (soft 8-bit
  synth), awaiting the user's listen. `tests/_shot_firefly.gd` shoots every
  beat and puts `user://arcade.cfg` back.

**Molehill is the second** (2026-09-27, spec
`2026-09-27-arcade-molehill-design.md`): whack-a-mole after the boardwalk
cabinet, whose trademark the spec names once to forbid; **it is called
Molehill**. The brief said "puzzle game"; it went on the Arcade tab because
it is a timed game for a score with no solve. Twelve molehills (3x4) and a
minute: moles (10), golden ones (50), flowerpot moles that take two whacks
(25), and a rabbit who must be left alone (-30). A streak multiplies (x2 at
5, x3 at 12, x4 at 20) and breaks on a mole let go, an empty whack or the
rabbit; the last ten seconds count double. The record's "furthest" is the
best streak.

- **The game is pure data** (`arcade/molehill_sim.gd`, fixed 1/60 s,
  `whack(hill)` and `events`). `tests/_probe_molehill.gd -- [seed] [react
  ms] [slips]` plays it with a bot: ~10,000 at 300 ms, ~1,400 at 800 ms.
- **A mole sinks by a clip, not by a cut mesh**: each hill is a clipping
  Control whose bottom edge is the hole's mouth, the mole lowered into it by
  the draw transform, then the mound's front lip as a second child over it,
  both in row order so a row stands in front of the one behind.
- `tests/_shot_molehill.gd -- <outdir> [reduce]` shoots every beat, clicks a
  mole through the viewport (prints whether it counted) and puts
  `user://arcade.cfg` back. 134 draw calls on the tab with three cards, 55
  on a bare lawn, 63 with the cast up, 72-75 on the end card, ANGLE agreeing.
- 17 sounds, whacks in a new `CARTOON` style and jingles in `ARCADE`,
  awaiting the user's listen.
- **Rewards made loud on 2026-09-27** (the spec's last amendment), through
  `arcade/rewards.gd`: clods, coins and shards off every whack, flurries
  (Double!, Triple!), the streak worded, a big `x2!` over a sunburst at each
  multiplier step, a warm glow round the lawn, Not the bunny! with hearts,
  the last five seconds painted on the lawn under the moles, milestones, a
  new best, and an end card that counts up. ~150-240 draw calls at a busy
  moment.
- **Polished on 2026-09-27** (the spec's section 7), screen and art only:
  moles that look about, blink, overshoot and pancake, peek before the
  round and jeer after it; mounds that heave; a mallet with a shadow, a
  smear and an impact star; sticker numbers kept clear of the time bar; a
  frenzy glow from the edges. 54-57 draw calls in play, 93 on the end card.

**Stackwood is the third** (2026-09-27, spec
`2026-09-27-arcade-stackwood-design.md`): a falling-block number merge
after a drop-and-merge game the spec names once to forbid; **it is called
Stackwood**. Numbered wooden blocks fall into a shelf 5 wide and 7 high;
slide to steer, let go to drop, and a block merges with every touching
block of its number, doubling once for each, the blocks above falling in
and chaining. Topping out ends it. Acorns from merges buy a rainbow block,
a bomb and a zap. Its "furthest" is the biggest block.

- **The game is pure data** (`arcade/stackwood_sim.gd`, fixed 1/60 s).
  `tests/_probe_stackwood.gd -- [seed] [skill 0-2] [tools 0/1]` plays it
  with a bot; run it after touching the sim.
- **Six cards do not stand one above another**: the Arcade tab's `_fit`
  now ends in two cards a row (Play as a chevron alone). 194 draw calls on
  the tab, 60-114 in play, 90 on the end card (810x1440).
- **A new locale key reads as its key until the CSV is reimported**
  (`godot --headless --import`), and a `%d` key then throws a string
  formatting error rather than failing quietly.
- 20 sounds (`CARTOON` wood, `ARCADE` jingles), awaiting the user's listen.
  `tests/_shot_stackwood.gd` puts `user://arcade.cfg` back.
- **Polished on 2026-09-27** (the spec's section 7), screen and art only:
  bevelled blocks dressed up with the number (a frame from 128, gilt and
  twinkles from 1024), a cabinet with posts, crown, ivy and bunting, a
  falling block that glides and leans (an exactly solved spring, because
  the explicit one blew up on a long frame), landing squash and column dip,
  gravity settles, merge gulp and flash, acorns flying into the bank.
  `Motion.bump` compounds when bumps overlap; the screen's `_kick` restarts
  from one. 69-75 draw calls in play, ~135 at a chain's peak.
- **Rewards made loud on 2026-09-27** (the spec's section 8): Lucky
  Thirteen's sticker and bits kit carried over -- splinters and sparks off
  every merge, hopping words (Nice! to Legendary!) with `Chain xN` and
  `Combo xN` under them, a warm edge glow for a combo of merging drops, a
  new biggest block lettered up top, a gold flash and acorn rain from 2048,
  Phew! off the line, acorn comet trails, an end card that counts up.
  81-127 draw calls in play, ~250 at a big chain's peak.

**Lucky Thirteen is the fourth** (2026-09-27, spec
`2026-09-27-arcade-thirteen-design.md`): a chain-merge number game after a
browser game the spec names once to forbid; **it is called Lucky
Thirteen** (id `thirteen`). Drag through three or more touching pebbles of a
number (diagonals count) and they merge into the last, one higher; the aim
is 13, and a tray with no three touching is stuck. Clovers buy five tools
(undo, swap, pluck, shuffle, lift) whose prices climb with each purchase.

- **The game is pure data with no clock** (`arcade/thirteen_sim.gd`): a
  move resolves at once and the screen animates the settle after it.
  `tests/_probe_thirteen.gd -- [seed] [skill 0-2] [tools 0/1] [games]`
  plays it with a bot; run it after touching the spawn window or the
  clovers. Random play reaches 9 in ~65% of games, 13 in ~2%.
- **A connected group of three or more always holds a chain of three**, so
  "stuck" is a flood fill (`groups_of`), but not every pebble of a group can
  *end* one (the middle of a star cannot): `chain_through` may come back
  short, and anything picking an end must try another.
- 216 draw calls on the tab with seven cards, 125-148 in play, 99 on the end
  card, ANGLE agreeing. 19 sounds (`CARTOON` pebbles, `ARCADE` jingles),
  awaiting the user's listen. `tests/_shot_thirteen.gd` puts
  `user://arcade.cfg` back.
- **Polished on 2026-09-27** (the spec's section 6), screen and art only:
  banded pebbles that glint and wiggle, a chain held up off the sand with
  flowing beads and a tether to the finger, merges that knock their
  neighbours, a new number from 7 revealed big and flown to the plate, words
  on paper pills and a stuck card. 125-135 draw calls in play, ~143 on the
  13's reveal.
- **Rewards made loud on 2026-09-27** (the spec's section 7): Posy's
  sticker and bits kit carried over -- tier rings while a chain is drawn,
  chips and stars off every merge, chain words (Nice! to Legendary!), a
  streak of long chains with a warm edge glow, a 13 that flashes gold and
  rains coins, clover comet trails, an end card that counts up. 131-192
  draw calls in play, 94 on the end card.

**Posy is the fifth** (2026-09-27, spec
`2026-09-27-arcade-posy-design.md`): a swap-three garden after the
candy-swapping game the spec names once to forbid; **it is called Posy**
(the user's mock said Pixel Garden, which the twenty-seventh board already
is). Swap neighbours to line up three; four leave a breeze (row or column),
an L or T a seed bomb that goes off twice, five a rainbow posy. Each day
asks for so many of two or three kinds in so many moves; leftover moves
bloom as breezes, then the next day is dealt. Its "furthest" is the day.

- **The game is pure data** (`arcade/posy_sim.gd`, no clock): a move
  resolves at once and leaves every cascade step as an event.
  `tests/_probe_posy.gd -- [seed] [skill 0-2] [tools 0/1] [games]`; run it
  after touching the sim or `day_plan()`.
- **The screen plays the events off a queue and keeps its own picture of
  the bed** (`_tiles`, id -> where it is going), and the paper row follows
  the queue: the sim is a whole cascade ahead by the time the first step is
  drawn, so nothing on screen may read the sim's grid while `busy()`.
- **A harness must put `user://arcade.cfg` back on every exit path**, a
  timeout included: the first `_shot_posy` run timed out after its bot had
  lost a game and left a real Posy score in this Mac's save.
- 236 draw calls on the tab with eight cards, 131-151 in play, 100-104 on
  the end card, ANGLE agreeing. 26 sounds (`CARTOON` garden, `ARCADE`
  shimmer and jingles), awaiting the user's listen.
- **Polished on 2026-09-27** (the spec's section 6), screen and art only:
  the rewards made loud -- words lettered a hopping letter at a time over
  sunbursts (day, cascades, combos, specials made, last move), petals,
  leaves, sparks and stars thrown by every pick and blast, a flashing bed and
  a cascade's edge glow, stamped goal seals, and a day's end of one to three
  stars, a petal rain, every spare move thrown from the moves plate as a gold
  star, and the gift flown to its tool. 148-200 draw calls in play, ~254 at
  the day's end peak, ANGLE agreeing.
- **The genre pass on 2026-09-28** (the spec's section 7), from a look at
  Royal Match and Gardenscapes: a **bee** from a square of four that flies
  to the cell the goals want most, chosen when it goes off; **weeds, stones
  and moss** from day three (one a day, taking a goal) and **shaped beds**
  from day four -- tiles fall past holes, stones and moss, so gravity stays
  a column compaction; **five more moves once a game** (`Phase.OFFER`);
  **tap a special** to set it off for a move; and moves allowed while tiles
  are still landing, with a tap hurrying the rest. A harness laying tiles by
  hand (`_put`) must skip cells with no tile: a stone's `{}` written into
  becomes a half tile the sim then trips on.

**Peapod is the sixth** (2026-10-04, spec
`2026-10-04-arcade-peapod-design.md`): a pea cannon against numbered crates,
after the cannon-and-numbers phone shooters the spec names once to forbid;
**it is called Peapod**. The cart only slides and never stops firing; a
crate takes as many peas as its number; gift crates drop a token that must
be caught (a pea more a volley, a quicker gun, a heavier pea, a helper cart
for twelve seconds); a firecracker takes its neighbours, a golden crate pays
five times. Two waves of a wall five across, then one of a millipede winding
down a path, whose plates shot off knock it back. Whatever reaches the
chalk line ends the run. Its "furthest" is the wave.

- **The game is pure data** (`arcade/peapod_sim.gd`, fixed 1/60 s, field
  units, `target_x` or `axis` in, `events` out). `tests/_probe_peapod.gd --
  [seed] [skill 0-2] [games]` plays it with a bot; run it after touching
  `hp_base()`, the gifts or the speeds. Skill 0 ends on wave 5-10, skills 1
  and 2 near wave 20-23 in about six minutes.
- **The gun is heard and never felt**: `shot` and `hit` fire several times a
  second and play through `_quiet`, a second `Fx2D` with `buzzes` off, so
  no ECHO rides on them. The next game with a constant sound can do the
  same.
- **A crate's paint is its number's weight** (`Art.tier_of`, a step each
  time it trebles) and is read off the hp it has left, so a crate changes
  colour as it is worn down. The hit flash is a small one (1.22 on the
  modulate, a tenth of a second): at 1.7 a volley of three landing made a
  blue plate read as a cyan one, a colour of its own.
- **The millipede head's number is lettered last**, on a dark plate over
  the head: lettered with the plates' numbers it ran into the plate behind
  it on every turn of the path.
- A harness ends a run with `sim.wall_y = 1000.0` (a wall) or
  `sim.segs[0].s = Sim.path_len()` (the millipede). `revive()` measures its
  shove from the line, not from where the wall was, or a wall forced far
  past the line comes back still past it.
- 262 draw calls on the tab with six cards, 52 at rest, 73-85 in play, ~124
  with a wall of fifteen and four gifts falling, 105-118 on the end card,
  ANGLE agreeing. 22 sounds (`CARTOON` crates, `ARCADE` jingles), awaiting
  the user's listen. `tests/_shot_peapod.gd` shoots every beat, slides the
  cart through the viewport (prints whether it rolled) and puts
  `user://arcade.cfg` back on every way out, a timeout included.
- **The second pass (2026-10-04, the user's play: lag on the millipede and
  on big walls, a gift at the edge out of reach, too easy with the helper,
  more shots and gifts wanted).**
  - **Where the lag was** (`tests/_perf_peapod.gd`, `_probe_peapod_perf.gd`):
    not the draw calls (164 on a full wall) but script. Every pea was laid
    into a mesh in script each frame, the chalk line's dashes rebuilt each
    frame (0.6 ms of nothing), and on a millipede every pea asked the path
    for every plate it passed (506 usec a step with a full gun against 21
    on a wall). Now: peas, sparks, crates and plates are MultiMeshes (one
    draw a look), the dashes and the gun's plates are meshes built with the
    garden, plate positions are worked out once a step (`_place_segs`, 53
    usec), and a slow frame catches up four steps at most, not twelve.
    Script a frame on this Mac went from 2.3-4.7 ms to under 1; draws 126
    on a full wall, 100 on a 24-plate millipede. The numbers are still two
    text draws a crate. **Not measured on a phone.**
  - **A token drifts in** to where the cart can stand (`TOKEN_DRIFT`): the
    millipede comes in from x = -26 and the cart stops at 22 with a reach
    of 30, so a gift plate shot on the way in could never be caught.
  - **Three pods**, held ten seconds, one at a time (`sim.pod`): Fan (two
    more peas, leaning out), Dart (a pea goes through three, `left`/`last`
    on the shot), Berry (a pea's neighbours take half, quietly). **Three
    gifts**: Magnet (gifts fly to the cart ten seconds; never the rotten
    one), Frost (whatever is coming at 0.35 for five), Shove (the wall up
    60, the millipede 200 back). What is running shows on the right of the
    grass, each with a ring that runs down.
  - **Harder**: the helper is six seconds, one plain pea, from wave 4 and
    every other wave at most; a **rotten gift** (from wave 3) drops a token
    to keep out from under -- it takes a pea, else a rate step; an **iron
    crate** (from wave 5; plates from 9) takes one a pea whatever the pea
    weighs, a firecracker takes it whole; the millipede's knock is 9, not
    16, and it runs up to 1.6 times quicker as it shortens. The numbers'
    curve was left alone: the wider gift bag thins the peas and rate, and
    that was enough. Bots now: skill 0 wave 4-7 (two to three minutes),
    skills 1 and 2 wave 10-17 (four to six).
  - `Sim.holds_token(kind)` is the test for a gift, not `kind >= PEA`: the
    new kinds sit after `HEAD` so the old numbers stand.
  - Five more sounds (`clank` through `_quiet`, `pod`, `frost`, `shove`,
    `rot`), unheard by the user like the rest.

- **The soft pass (2026-10-04, the spec's section 7)**, screen and art only:
  Lucky Thirteen's pastel pieces and Posy's card and hedges, the animations
  eased, the rewards made more of. The sim is untouched.
  - **The look**: the parchment card (no wooden frame), a pale sky and soft
    hills, a crate a rounded pastel tile with a lip and its number in ink
    (one text draw a crate, not two), a gift crate a cream parcel showing
    its token's medallion (`Art.medal`), the millipede round paper discs
    behind a plum head, paper pills for the gun's line. `Art.number()` takes
    the kind last, for the ink (`number_colour`).
  - **The sky and the land are two meshes** (`_scene`, `_land`) with the sun
    (`ui/faces/sun_face.gd`) between them, so it comes up from behind the
    far hills; `_land` is the first thing `_draw_over` draws, unshaken. A
    tutorial page has no sun node and gets a plain pale disc.
  - **A MultiMesh holds one buffer**: the same mesh gathered twice in a
    frame from one MultiMesh showed the second draw's copies both times (a
    gift flying home took the medallion off its own pill). `_cast_add`
    gathers into the frame's current draw (`_casts[_cast_turn]`) and
    `_cast_draw` moves on, so it is called the same number of times every
    frame whether or not anything was gathered.
  - **A pea landing is a white blink over the piece** (`Art.blank`, in a
    draw of its own after the pieces') and a swell of its number, never a
    brighter paint. The swell and the score pops are `draw_set_transform`
    over one size of letter, so no glyph is cut at a new size mid-run.
  - **Gold thinned over the pale sky goes to mud**: the clear's stars leave
    by shrinking, not by alpha.
  - **The rewards**: the streak's pill (count and the time left, from 5),
    one to three stars a cleared wave by how near the line was let
    (`STAR_PEAKS`) and a flower up along the grass for each (`_blooms`, kept
    for the run, shown on the end card), the pod crowned and the sun in a
    party hat once the best is passed, a gift flying to its place on the
    grass (`_flights`), the cart's hop, the big moments held a beat
    (`_hold`, off under reduce motion). The stars tick (`Haptics.TICK`).
  - 64 draw calls at rest, 73-84 in play, 116-120 with the whole cast, 77 on
    a full wall and on a 24-plate millipede (126 at the head's end), 112-122
    on the end card, ANGLE agreeing. `tests/_shot_peapod.gd` shoots the
    clear (3b: prints stars, flowers, the crown) and a gift in flight (3c);
    its `reduce` is set right before the screen opens, or the menu's
    settings load puts it back.
  - `tests/_probe_arcade_buzz.gd -- peapod` plays the run but fails at its
    end-card step (`_s._end` is null after three seconds); it fails the same
    on the commit before this pass.

- **The third pass (2026-10-05, the user: "remove the debuff, it make no
  sense", more rewards and more blocks, and no wave whose gifts are useless
  -- "a magnet as reward in a wave where there is no shoot buff")**, the sim
  and what named the rotten gift.
  - **The rotten gift is gone**: `Kind.ROT`, its crate, token, medallion,
    `rot.ogg`, its warn, its lines and its place on the tutorial's gifts
    page (two gifts caught now). **`Kind.IRON` is 14, not 15**: nothing
    stores a kind, but a harness's list by kind had to lose a name.
  - **A wave's gifts are planned together** (`_plan_gifts`, then
    `_gift_places`), not drawn crate by crate. Drawn one by one a wave could
    hold a magnet and a frost and nothing for the gun, and the next wave's
    numbers were past it. The rules, which `gift_count` and the constants
    carry: three gifts a wave, one more every third wave, six at most; the
    gun's (pea, rate, weight) are half of them at least and never fewer
    than two, never the same one twice running, and the first met is one of
    them; the rest are one each at most of a pod, the magnet, the frost,
    the helper and the shove. **A magnet only comes to a wave of four or
    more, and the two gifts after it sit on the next two rows up (the next
    two plates)**, since it holds ten seconds. Gifts are spread up the wall
    one to a row, clear of the lowest, and down the millipede's length.
  - **More to shoot**: a wall is six rows on wave 1 and twelve at most (was
    four and nine), a cell is left empty one time in ten (was one in
    seven), a millipede is `9 + wave` plates, 26 at most (was 24). About 27
    crates on wave 1, 36 on wave 4.
  - **The numbers climb faster to meet the fatter gun**: `hp_base` is 1.46 a
    wave to wave 10 and 1.38 after (was 1.45 and 1.25). With the old curve
    the aiming bots ran to wave 23 on a pea worth 60.
  - **The bots** (`tests/_probe_peapod.gd`, which takes a fourth argument
    now, the share of gifts a skilled bot does not go for): skill 0 wave
    4-10 (was 4-7), skill 1 missing six in ten wave 11-16, skill 2 wave
    17-19 in five to six minutes (was 10-17). The spread between runs is
    much narrower than it was: that was the luck of the gifts.
  - 75-85 draw calls on a twelve-row wall and a 26-plate millipede, 97-124
    as the head goes, ANGLE agreeing (`tests/_perf_peapod.gd`). The shot
    harness and the tutorial's seven pages were shot. **Nothing was run on
    a phone, and no person has played the new curve.**

- **The fourth pass (2026-10-05, the user's design, talked through in
  chat): nothing is caught, and the gun grows in a shop.** What the lines
  above say of tokens, the magnet, the helper, the gun's three gifts and
  "peas a volley" is history.
  - **A gift is had as its crate breaks** (`_killed` -> `_take`, the `gift`
    event). `tokens`, `Kind.MAGNET`, `Kind.TWIN`, `Kind.PEA/RATE/POWER`,
    `peas`, `twin_t` and their events are gone; **`Kind` is renumbered**
    (`CRATE, GOLD, BOMB, HEAD, FAN, PIERCE, BURST, ZAP, FLAME, FROST, SHOVE,
    IRON`; `holds_gift`, `is_pod`). The extra pea went because it was the
    heavier pea under another name (both +1 on a factor of the same
    product), fifty numbers a second cannot be read, and the shots in the
    air were the lag.
  - **Energy and the shop.** Energy is counted in orbs, `ORBS` (4) to one
    energy: a crate is worth 1, a golden one 5, and a millipede's head makes
    its wave up to a wall's worth (`wave_crates`). A wave cleared, its beat
    over, the sim goes to `Phase.SHOP` if anything can be bought and waits
    for `leave_shop()`; the screen's card (`_open_shop`) sells `Card.DAMAGE`
    (+1), `SPEED` (+1 volley a second, 8 levels), `CRIT` (+10% of a pea
    landing three times, 5 levels) and `ENERGY` (+0.1 of a crate's worth, no
    cap). **A price is `PRICE` x (1 + `PRICE_STEP` x bought) x the wall's
    size over wave 1's**, so a wave's energy buys the same on any wave and a
    card left for later is never cheaper; `bought` is the shop's count, so a
    booster's head start raises no price. Unspent energy is kept, and a
    Second chance keeps everything.
  - **Two more pods**, held one at a time like the rest: `ZAP` (lightning on
    from what the pea hit to the nearest thing in `ZAP_REACH`, four jumps,
    half the pea each) and `FLAME` (what a pea lands on burns three seconds,
    bitten every half second for the weight of the pea that lit it, not
    stacking: it rewards sweeping). A thing alight wears a drawn flame at
    its corner, never a tint: its paint is its number. A wave holds one to
    four gifts (`gift_count`), a pod first and never the one the wave before
    began with, then the frost (wave 3), the shove (wave 4) and a second pod.
  - **Every hit says what it took** (`dmg`, `crit`, `how`: `Hit.PEA`, `SIDE`,
    `BOOM`, `BURN`), and a `hit` now comes for the blow that breaks a thing
    too (the screen plays its spark and sound only while `hp > 0`). The
    screen floats the number (`_nums`, 26 at most): a pea's hops down out
    from under the crate, clear of the crate's own number, a crit's bigger
    and gold with a "!", a splash's, a jump's and a burn's small at the
    thing's corner. No transform of their own and one size a look, so they
    batch. The spent pea tumbles off (`_crumbs`), a heavier pea is drawn
    bigger (`fat`), and the Fan's side peas come back off the garden's sides
    (the sim's, real).
  - **The orbs** (`_drop_orbs`, `_step_orbs`, `_draw_orbs`, on `Orbs`, a
    layer over the whole screen, one MultiMesh): one a quarter energy, thrown
    out of the crate and slowing, hanging a beat, then round a bend of their
    own into the ENERGY plate, slow and then quick, one after another,
    pulled long by their speed. The plate counts what has landed
    (`_orb_due`), each landing a click a semitone up a short run (`hit`
    through `_quiet`). 28 a crate and 150 at once at most; the shop opening
    lands whatever is in the air. Under reduce motion none fly.
  - **The numbers**: `hp_base` is 1.32 a wave to wave 10 and 1.27 after (was
    1.46 and 1.38), tuned on `tests/_probe_peapod.gd`, whose fourth argument
    is now the shopper (0 the best worth for its price, 1-3 one card only, 4
    two Energy first, 5 at random). Shopper 0 ends on wave 13-17 in about six
    minutes, 4 on 14-17, 5 on 11-17, damage only on 10-13, speed only on
    7-8, crit only on 7. **A hand's speed no longer tells the bots apart**
    (nothing is caught): what a run is worth is what it bought.
  - **The boosters**: `pp_pea` is a heavier pea from the start (it was a
    second pea), `pp_quick` one level of the rate (it was two of the old,
    smaller ones).
  - **No new sound was made**: a gift starting plays the pods' `pod`, `frost`
    or `shove`, the shop opening `gift`, a card bought `catch`, Go `go`, an
    orb landing `hit`. `lost.ogg` and `twin.ogg` are unused; `twin_off` is
    still a pod running out. Lightning and the flame have no sound of their
    own.
  - 97-124 draw calls under a full gun on a twelve-row wall, a 26-plate
    millipede and the wall again under lightning and under the flame, 131 at
    worst as the head goes, both drivers agreeing (`tests/_perf_peapod.gd`,
    two more loads); 113 with the shop up. Suite, the shot harness on both
    drivers and under reduce motion, the tutorial's eight pages (a page for
    the shop), the haptics and wallet probes. **Nothing was run on a phone,
    nothing was heard, and no person has played the new curve or the
    shop's prices.**

- **The fifth pass (2026-10-05, the user: "since upgrades don't stack, a
  wave with a eletric shot + burst make user one of them useless", and
  "instead of auto activate the buff, let's keep the last 2 buffs on screen
  so user can activate anytime, and new buffs replace the old one").** What
  the fourth pass says of a gift starting as its crate breaks and of one pod
  at a time is history.
  - **A gift is kept, not started** (`_take`): it goes to one of two places
    (`sim.held`, `TRAY`), an empty one first, else the place of the gift had
    longest (the `gift` event's `slot` and `lost`). A place never moves, so
    a button is the same button until it is used. `use(slot)` starts it
    (the `use` event) and is refused in the beat between waves (`can_use`):
    there is nothing to use it against. The frost and the shove are kept
    like the pods. The tray lives through the shop and a Second chance.
  - **Two kinds of pod run together**: how the peas go (`shape`: Fan, Dart,
    Burst; `is_shape`) and what they are made of (`element`: lightning,
    flame; `is_element`), one of each at once, each with its own ten
    seconds; a second of a kind takes the first's place. `sim.pod`/`pod_t`
    are gone. A pea carries how it lands (`left`, `burst`, `el`) and is
    drawn as its element when it has one (`k`), so there is no new pea to
    draw; the Fan's side peas are made of the same, and each of a Dart's
    three landings jumps or lights. `pod_off` says which `kind` ran out.
  - **A wave's second pod is of the other kind than its first**
    (`_a_match`), so two pods in a wave always run together.
  - **The buttons** (`_slot_px`, `_draw_slot_seats`, `_draw_slot_tokens`):
    two paper seats on the right of the grass, 28 units across, an empty one
    hollow, a kept gift breathing on it and pale while it cannot be started.
    The gift flies from its crate to its button (`_flights` with a `slot`),
    a gift pushed out tumbles off (`_slot_out`), and one started hops from
    its button to its ring. **A press that lands on a button is never the
    cart's** (`_slot_hit`: a thumb's width round each and down to the foot of
    the field, an empty button too), whichever finger it is, so one thumb
    slides while the other presses; the keys 1 and 2 do the same. A touch is
    also sent as a mouse press: `_press_slot` takes one a frame a button.
  - **The rings** (`_timed`) are up to three now (shape, element, frost),
    laid leftwards from beside the buttons and a size down (10 units, 20.5
    apart) to clear the crit's pill.
  - **Sound and feel**: a gift kept plays `catch` and knocks good; one
    started plays what starting played (`pod`, `frost`, `shove`) and knocks
    bump; a refused press ticks and the button shakes its head. No new sound.
  - **The tutorial**: the gifts page's finger leaves the slide, goes to the
    button and presses it (`taps` in a lesson's plan, `Garden.tap`); the
    pods page breaks a shape and then an element and runs both. Three lines
    rewritten in three languages (`PP_READY_LINE`, `TUT_PEAPOD_GIFTS*`,
    `TUT_PEAPOD_PODS_BODY`); a body is 188 px of 230 at its longest.
  - **The bots** (`tests/_probe_peapod.gd`, a fifth argument, the keeper: 0
    starts a gift at once, 1 keeps a pod for its match and the frost and the
    shove for when the line is near). Eight runs, shopper 0, before: wave
    13-17, most on 16. Keeper 0: 13-19, most on 16. Keeper 1: 14-19, most on
    17. About a wave further; `hp_base` was left alone. On paper a Fan or a
    Dart of lightning is nine plain peas against three for either alone.
  - 77-86 draw calls with a gift kept, pressed and started, 119 (124 at
    worst) on a wave-19 wall under a full gun's Fan of lightning or of flame,
    164 on the shot harness's cast, both drivers agreeing. `_shot_peapod.gd`
    presses the button through the viewport (3e-3g: prints whether the gift
    was kept, whether the press started it and whether the cart was left
    alone); `_probe_arcade_buzz.gd`'s bot presses a gift a second after it
    is had. **Nothing was run on a phone (two thumbs at once least of all),
    nothing was heard, and no person has played with the tray.**

- **The sixth pass (2026-10-05, the user: "add +1 shoot on shop, but make it
  expensive", "instead of crit being the change, we make chance fixed but
  increase crit damage", "send it in sequence instead of parallel", "make
  crit upgrade expensiver along with speed one", "an infinite queue, as
  fifo", and then, on seeing a "+N" badge: "show it like a bingo ball with
  two slots going outside screen, when player use one, another ball roll
  in").** What the fifth pass says of a newer gift taking the older one's
  place, of a place that never moves and of `lost` is history.
  - **A pea more a volley** (`Card.SHOTS`, `sim.peas`, three levels,
    `MAX_SHOTS`): the peas of a volley leave one after another from wherever
    the cart is by then (`_seq`, `SEQ_GAP` 0.06 s, less when the gun is too
    quick for it), never side by side. A `shot` event says `more` for the
    ones behind the first; the screen plays the click once a volley. The
    card is appended to `Card`, so the old numbers stand; the shop lays its
    rows by `SHOP_ORDER`. **80 on wave 1 and as much again each time**
    (`PRICE`, `PRICE_STEP` 1.0): at 45 the bots ran six waves further.
  - **The crit is how hard, not how often**: none before the first level;
    from it `CRIT_CHANCE` (one pea in ten) lands `crit_mult(lv)` times (x3,
    one more a level), and the chance goes up 5% every fifth level
    (`crit_chance`, 50% at most). No cap on the level. The grass's third
    pill shows the multiplier ("-" with none bought).
  - **Dearer**: the quicker gun and the crit are 14 with a step of 0.4 (were
    9 and 0.3).
  - **The gifts are one line** (`held` its first two, `queue` the rest,
    oldest first, nothing lost): a gift started, everything behind it moves
    up one (`use` says `next`). On the grass a chute runs from the two
    buttons off the garden's right side, the next in turn half in at its
    mouth (`_slot_px(TRAY)`), and the line rolls along a place
    (`_slot_roll`, `_rolled`); a gift still flying goes to where its place
    now is. The buttons moved 9 units left and are 31 apart to show the
    mouth; the rings start at `W - 84`, 20 apart, and three of them touch
    the crit's pill.
  - **`Motion.bump` on a label compounds**: it swells from whatever scale
    the node has, so a bump begun inside the last one left the score a
    tenth bigger each time and a streak blew it up over its plate (the
    user's screenshot). The screen's labels beat through `_beat`, which
    stops the last tween and starts from one. Any other screen bumping a
    label on every kill has the same bug.
  - **The numbers**: `hp_base` is 1.30 a wave after wave 10 (was 1.27).
    `tests/_probe_peapod.gd` (shopper 6: as 0 but never the extra pea).
    Eight runs, skill 2: gifts started at once wave 13-17 (was 13-19),
    kept for their match 19-20 (was 14-19, most on 17), no extra pea 16-19,
    at random 11-16. **The keeping bot's runs are about nine minutes, not
    six**: with nothing lost it has a frost or a shove for every close
    call. Whether a person plays that way is not known.
  - 80-87 draw calls with the chute full, 170 on the shot harness's cast,
    133 at worst under four peas a volley at full rate with a Fan of
    lightning; the sim 256 usec a step on a 24-plate millipede with 83 peas
    in the air (`tests/_probe_peapod_perf.gd`). Suite 249790/0, the shot harness on both
    drivers and under reduce motion. **Not done: the tutorial's shop page
    with its fifth row (not shot), a phone, and nothing heard.**

- **The seventh pass (2026-10-05, the user, after playing the sixth: "the
  price increase should only be applied when player buy it", "elemental
  shoots should change the pea color (red, yellow, etc), instead of
  replacing it to the element", "only elemental should not stack, if I have
  fire shot and get a burst buff, it should keep the fire shot", "new buffs
  always enter as the first in queue, not last").** What the passes above
  say of a price growing with the walls, of one shape at a time
  (`sim.shape`), of a pea drawn as its element and of the oldest gift first
  is history.
  - **A price moves only when its card is bought** (`price`): the walls'
    size is out of it. A wave's energy still grows with its wall (27 crates
    on wave 1, 54 from wave 12), so the climb a purchase is steeper to keep
    the runs where they were: `PRICE_STEP` is 0.7, 0.9, 0.9, 0.6 and 1.5
    (the extra pea is 80, 200, 320). With the sixth pass's steps the bots
    ran to wave 25.
  - **The shapes all run together**, each with its own ten seconds
    (`shape_t`, by `kind - Kind.FAN`; `has_shape`); a shape started again
    begins its time again. **Only an element takes an element's place.** A
    pea that is both a Dart and a Berry goes through three and bursts on
    each; the Fan's side peas are still plain ones of the element.
  - **An element is a pea's colour, not its shape** (`Art.shot(look, u,
    el)`): lightning's peas are yellow (`BOLT`), the flame's red (`FIRE`),
    as a pea, a dart or a berry. `Sim.Shot` is the three shapes only; the
    screen keeps a MultiMesh a shape and element (nine, the empty ones not
    drawn).
  - **A new gift goes in at the head of the line** (`_take`: always `slot`
    0), the rest moving back one, the second button's into the chute. The
    line rolls back from the first button (`_roll_way` -1) and forward on a
    gift started (1).
  - **The rings are up to five** (three shapes, an element, the frost): past
    three they close up and overlap (`_timed_at`), and the gun's pills are
    52 apart (were 56) to leave them room.
  - **The bots**, eight runs, skill 2: gifts started at once wave 14-17,
    kept for their match 19-20, at random 11-19. The same as the sixth pass.
  - 158-160 draw calls on the shot harness's cast, 73-86 with the chute in
    use. Suite 249790/0. Two tutorial lines rewritten in three languages
    (`TUT_PEAPOD_PODS_BODY`, `TUT_PEAPOD_SHOP_BODY`). The shot harness on both drivers and under
    reduce motion. **Not done: the tutorial's pages (not shot), a phone, and
    nothing heard.**

**Tutorials** (2026-10-04, `docs/agents/checkup.md`, the last section): each
screen has `tutor` (`ui/hud/screen_tutor.gd`) and `tutorial_pages()`, the
pages played by a quiet subclass of the screen over a hand-laid sim
(`ui/hud/<game>_tutorial_diagram.gd`). A run with a clock is left paused
under the card. **A new Arcade game needs both**, and
`top_bar.refresh(self)` in `_ready` before `_ask(false)`, or Undo and the
bulb show behind the boost card. A harness that opens a screen through the
menu sets `ScreenTutor.no_first_play`.

**Lucky Thirteen's lit stones and sand** (2026-10-04, `feat/thirteen-painted`).
The pebbles and the tray's sand are no longer flat fills: each is a height
field in a canvas shader (`shaders/pebble_bake_2d.gdshader`,
`shaders/sand_bake_2d.gdshader`), lit by one shared light from the upper left
(`SUN`; `LIGHT` is a canvas built-in and will not compile as a constant).
Neither shader is ever on screen. `Art.bake()` draws them once into a
SubViewport and keeps the picture: the sixteen stones as a 1280x1280 atlas
(`Art.ensure_skin`, `Art.skin()`), the sand at the field's size
(`_bake_bed`). `Art.pebble(v, s)` then returns a textured quad instead of the
flat mesh and every call site passes `Art.skin()` as `draw_mesh`'s texture, so
the draw calls are what they were (peak 237 in the shot harness, ANGLE too).
Until the bake lands, and for good under `--headless`, `skin()` is null and
the old flat pebble and `_build_bed()` mesh are drawn. Both shaders write
straight alpha with `blend_disabled`, or the atlas would carry a dark fringe.
No image file was added: a generated picture cannot be re-posed, a height
field can. The frame wears `CozyTheme.wood_grain(13.0)`.

**The same day, restyled to the soft cel look** (the user found the lit clay
"poorly drawn"; the reference was a clean casual board: chunky tokens, one
line weight, flat tones). The bake stays, the shaders changed: a stone is a
token with a thick side under its face, a line of its own paint deepened
(`Art.line_colour`, the shader's `deepen()`), a bevelled rim and three eased
bands, no gloss or grit; the sand is two flat tones with a pressed seat under
each stone. The number is lettered into the atlas by Labels in the bake
viewport (paper, lined in the stone's deep colour), so `Art.number()` returns
at once when the skin exists and the board lost a draw per stone (peak 174).
The chain is a white-rimmed ribbon of the paint with a lit upper edge, a deep
lower one and a white-rimmed pad under every stone; the frame is a StyleBox
with a thick lower lip, no grain.

**Nothing but a falling stone is cut by the tray's edge** (2026-10-04, user
request). `field` no longer clips. Its drawing is three layers kept in step by
`_redraw()`: the field itself (sand, the chain's ribbon and pads), `_stones`
inside `_clip` (the only clipped layer, opened `CLIP_PAD` past the field at
the sides and foot and 14 px above, so a waiting stone stays hidden) and
`_top` (glints, the badge of what the chain makes, pops); `_fx` sits above
them. Ask for a redraw through `_redraw()`, never `field.queue_redraw()`.

**Redrawn after Binairo, cozy and soft** (2026-10-04, user request: "based
on binairo... cozy and soft"; the user chose rounded-square tiles over round
pebbles). What the paragraphs above say of the stones' look, the sand and
the wooden frame describes what was; the bake, the atlas and the three layers
stand.
- **A piece is a tile** (`shaders/tile_bake_2d.gdshader`, was
  `pebble_bake_2d`): a rounded square of one flat pastel with a thin lip of
  the same colour deepened under its foot (`Art.ROUND`, `Art.LIP`, the
  shader's constants of the same names), a faint ground shadow, no line, no
  gloss, no bevel. `PAINT` keeps its hues pulled toward paper, so every
  effect that asks `Art.paint()` softened with it. The number is one Label in
  ink warmed with the tile's lip (`number_colour`), paper on 14-16. A paler
  stitch inside the edge from 10, a gold one past 13; 13 keeps its clover.
  The code still says pebble (`Art.pebble`, `_vis`); the screen says tile
  (`peça`, `ficha`) in ten strings, and `LT_WORD_4` lost its rock pun.
  Strings changed in `locale/ui.csv` show only after `godot --headless
  --path . --import` (the `.translation` files are ignored by git).
- **The tray is the flat boards' card** (`CozyTheme.lifted(Pal.PARCHMENT,
  36, ...)` with the hairline, as `ui/flat/flat_host.gd` builds it).
  `sand_bake_2d.gdshader`, `_bake_bed`, the rake, moss and shells are gone;
  `_bed` is one mesh of seats, a shade deeper than the card, seen only while
  tiles are falling in.
- **Nothing fades for a chain** (the rule on pieces coloured by index): the
  picked tiles lift and a sheet of paper lies under them -- a pad a tile, a
  band between with the paint down its middle, a soft shadow -- ending in a
  sun ring cut to the tile's shape. Hint, armed tool and the swap's first
  pick are the same rounded square in `Pal.SUN`. A stuck tray goes pale
  under a veil of the card's paper (`_wash`, a StyleBoxFlat so the flash and
  the veil keep the card's corners) instead of a brown one.
- `tests/_shot_thirteen.gd`, second reading on `opengl3_angle`: 105 at rest,
  139 on the 13's reveal, 154 after the bot's play (187 on the first
  reading; 220 before the change), 256 on the tab.
- `tests/_shot_howto_screen.gd -- thirteen` prints `Parameter "mesh" is
  null` every frame; it did before this pass too (the same with the change
  stashed) and the pages draw. Not looked into.

**Round, and moved more quietly** (2026-10-04, later the same day, user
request: "smoother and elegant animations, and circle items instead of
squares"; this replaces the rounded square chosen that morning). The bake,
the atlas, the three layers and every string stand.
- **A piece is a disc**: the face a circle, the lip the same circle swept
  `LIP` down (the shader's `pill()`), `Art.PIECE` (0.88) of a cell across.
  `Art.tile_outline` kept its name and returns a circle, so the seats, the
  pads, the sun ring, the hint, the armed tool, the swap's pick, the tool
  icons, the tutorial pages and the tab's banner turned round with it. The
  thirteen's clover sits under its number, which is lettered higher and a
  size smaller.
- **Nothing snaps.** A picked piece rides a spring (`_lift_to`, `LIFT_K`,
  `LIFT_DAMP`: up a tenth past and home) and comes down on it; its pad grows
  out from under it and the band reaches the newest piece over `SEG_T`. A
  merged piece eases along the chain, shrinks and fades into the last
  (`JOIN_T` 0.26; one still waiting its turn is drawn where it stood -- it
  used to vanish for a frame or two), a long chain's pieces all arriving
  within two `JOIN_STEP`s. The grown piece swells once (`BUMP_T`); a landing
  gives once and comes back, the fall's stretch let go softly; a merge's
  neighbours go out and back the once.
- **A tool's move is a glide** (`_glide`): eased at both ends and bowed to
  one hand, so two swapped pieces pass each other, straight down included
  (`vis.glide`, set by Swap, Shuffle and Undo; a gap closing is still a
  fall). Shuffle no longer jitters the tray first; a plucked piece's gap
  closes after 0.06 s, not a merge's wait.
- **A disc is never turned**: the lip and the shadow would turn with it. The
  idle wiggle is a small swell. Only a piece knocked out tumbles.
- **The tray shakes for the thirteen only**, half as far and slower. The
  end's tumble goes from the foot up, a row after a row.
- Second reading on `opengl3_angle`: 105 at rest, 145 on the 13's reveal,
  129 after the bot's play, 256 on the tab; 153-199 on the tutorial card.
  Shots and frame strips on this Mac only, nothing run on a phone.

**The Arcade's sounds left the chiptune on 2026-10-05** (the user: cozy,
never synth). `ARCADE` in `tools/gen_sfx.py` is a real kalimba, music box,
tongue drum and hand bells now, and all 86 cues under it were re-prompted
and re-taken across the six games; Firefly's shot, pop, dive and beam take
the new `NIGHT` foley. Every note above that says "`ARCADE` jingles" or
"soft 8-bit synth" describes the sets before that day. The `CARTOON` cues
are the old takes. Lengths and levels are unchanged, so no screen was
touched; none judged by ear. `docs/art/sound-direction.md`, "No synth".

**Peapod's and Lucky Thirteen's sounds were hated on 2026-10-05** ("i
really really hate peapod and lucky 13 sounds so much, it's annoying"), and
both sets were redone whole, the screens with them, under the rule the user
gave on the second go: **what repeats a lot is a click, never a bell or a
ring, and a constant action keeps a faint click rather than silence.**
Peapod: every shot is a 50 ms click at -24 dBFS, the peas landing are heard
once in `HIT_GAP` **and pitched by the number left on what they hit**
(`_hit_pitch`, off the `hp` the sim's `hit` event now carries: a damped
wooden tock on the note of the crate's paint, `HIT_NOTES` by
`Art.tier_of`, a major pentatonic, the user's ask and Peggle's trick), `pop` climbs to 1.25
and no further, and the crates are `PEAPATCH` foley. Lucky Thirteen: `select` is its first take, a pebble
click, 5% higher a pebble up to 1.5 (`_chain_pitch`; a kalimba up the
pentatonic was tried and turned down), `merge` is a clack with no chime,
`land` is heard once in `LAND_GAP`, the end card counts on `unselect`, and
the pebbles are `RIVERBED` foley. Firefly's `shoot` and `pop` and Posy's
`collect` are dry clicks for the same reason. The haptics follow the cues
as before; fewer landings are felt because fewer are heard.
`tests/_probe_arcade_buzz.gd` ran both games to their end cards; its
365,000 "Drawing is only allowed" lines on thirteen are there without this
change too. `docs/art/sound-direction.md`, the last section.
