# Brain skills on the win screen: design

2026-10-22. Status: approved direction (mockup "option 1"), the rest built
autonomously on the user's word ("all good ... do everything autonomous").

## 1. Intent

The user: "I want this app to not be just another daily puzzle but something
that sharpens the user's brain skills." Finishing a board should tell the player
**what the board trains**, **how today went against their own history**,
**one way to get better**, and **where they stand across all their
skills**. Their numbers should climb as they play more, and with that the
game starts to feel like training.

Prior art the user saw (2026-10-22): WordleBot (a skill score and a better
move for each guess), Elevate (a score for each named skill and a trend), the critique
that Elevate gives "little guidance", and end screens that compare you to your
own best. Of three mockups (Coach card, Sharpness score, Brain map) the user
loved all three and picked the mix with **everything on the end screen**
(`.superpowers/brainstorm/*/content/end-screen-mix.html`, option 1).

**Concept page deviation:** this was judged from the brainstorm companion's
mockups, not a `docs/brainstorm/concepts.html` tab. It is a new screen, not
a new game, and the user approved the mock directly.

### Goals
- Every daily board belongs to one of five skills, shown by name and icon on
  its win.
- A 0-100 score for each skill that rises as the player gets faster, uses fewer
  hints, plays better by the board's own measure, and climbs the levels.
- Today vs the player's usual on this board and level: time, hints, and
  the board's own measure when it has one.
- One tip, chosen from what happened on this solve, out of four written for that
  board.
- All five skills on the win, today's gain marked, and the weakest skill
  pointing to a board that trains it.

### Non-goals
- Move-by-move coaching ("the 8 already placed 8 times"). A later
  `coach()` hook can add it per board, but not here.
- Ranking against other players, or percentiles.
- A separate Brain page in Stats (option 2 was not picked).
- Mistake counts. Most boards have no live mistake counter (hearts are off
  except on Insane), so the mockup's "Mistakes" row is dropped.
- Arcade and Versus. Only `Registry.PUZZLES` gets a skill.

### Anti-goals
- A score that stays at 50 forever because it is only relative. It
  must climb as the player improves (section 4).
- Claims about health or the brain ("improves your memory"). The copy
  says *trains* or *sharpens* a skill and never promises a medical effect.
- A board's tip naming the famous game it follows (house rule, CLAUDE.md).

## 2. The five skills (user-approved 2026-10-22)

| id | Name | Line (what it sharpens) | Icon |
|---|---|---|---|
| `logic` | Logic | Rule things out until only one answer is left. | a 3x3 grid, one square ticked |
| `space` | Space | See shapes, turns, angles and paths in your head. | an isometric cube |
| `planning` | Planning | Think a few moves ahead and choose the order. | a winding dotted path to a flag |
| `focus` | Focus | Close attention to colour, detail and rhythm. | a target, rings and a centre dot |
| `words` | Words | Vocabulary, recall, knowledge and estimation. | a speech bubble with two lines |

The icons are vector shapes in `ui/icons.gd` (`skill_logic`, `skill_space`,
`skill_planning`, `skill_focus`, `skill_words`), drawn like the other HUD
icons (polys and lines in the unit square, any colour, any size). The user
said "find great icons on web, or create them". They are drawn in code
because every icon in this game is (`ui/icons.gd`) and a downloaded image
would not match the house style. Each skill wears one colour, taken from
`Pal.CAT` in that order (my call).

Names and lines are locale keys: `SKILL_<ID>` and `SKILL_<ID>_LINE` in
`locale/ui.csv`, with en, pt and es.

## 3. Which board trains which (user-approved table)

`"skill": "<id>"` on every `Registry.PUZZLES` entry.

- **logic** (9): sudoku, binairo, queens, lightup, shikaku, bridges,
  nonogram, lattice, hedgehogs
- **space** (7): quilt, pinwheel, untangle, fairylights, sunbeam, minigolf,
  horse
- **planning** (7): slider, rings, planes, knight, trestle, train,
  caterpillar
- **focus** (5): pixelgarden, hoop, gumdrop, buttons, drumbeat
- **words** (5): hiddenword, wordtrail, pearl, acorn, how_big

## 4. The scores (my calls)

### 4.1 One solve's performance `p` (0..1)

Made of up to three parts:

**Time part `pt`** (boards where time is fair, column "T" in section 6):
`start` = the median of the player's first three timed solves of this board
at this level, with this solve counted while there are fewer than three.
`pt = clamp(0.5 + 0.5 * log2(start / t), 0, 1)`: the starting pace gives 0.5,
twice as fast gives 1, twice as slow gives 0. Because it is measured against
where the player *started*, and not against a moving average, it climbs as
they improve, which is the anti-goal in section 1.

**Quality part `q`** (0..1): the board's own measure, from the board's new
`skill_quality() -> float` method. It returns -1 when it has none. The
formulas are in section 6.

**Mix:** with both parts, `p = 0.5*pt + 0.5*q`. With time only, `p = pt`.
With quality only (untimed boards), `p = q`.

**Hints:** `p *= max(0.4, 1 - 0.15 * hints_used)`.

### 4.2 One solve's score `s` (0..100)

Climbing a level is part of getting sharper, so each level has its own range:

| Level | range |
|---|---|
| Easy | 20 + 40p (20-60) |
| Medium | 35 + 45p (35-80) |
| Hard | 50 + 45p (50-95) |
| Insane | 60 + 40p (60-100) |

### 4.3 A skill's score

The skill's solves, every board in it in date order, are averaged with
an exponential moving average, α = 0.25, starting at the first solve's `s`.
The result is rounded for display. A skill never played shows "—" and
"Not trained yet". The **gain** on the win is the score after this solve
minus the score before it, shown as "+3" or "−2", and hidden when it is 0.

### 4.4 Where it comes from

All of it is worked out from `Progress.solve_log()` and never stored, as Stats
does (`core/player_stats.gd`). Each log record gains:
- `"q"`: the solve's quality (float, missing when the board has none). Old
  records have no `q`, so their `p` is time and hints only.

That gives every existing player scores from their history on day one,
with no migration. The work lives in a new `core/brain.gd` (static
functions over the log, like PlayerStats). Records of boards that have
left the registry are skipped.

**Untimed boards:** acorn, how_big, pearl, drumbeat, gumdrop and minigolf have no
time part. An old record of one (no `q`) counts as `p = 0.5` before hints, so
Words and Focus have scores from history on day one too.

**A random New game** (`_day_key == 0`) is not logged. Its win shows the
comparison and the tip, and the skill bars as they stand, with no gain. **A
reopened finished daily** shows the report as it is now, with no gain.

## 5. The win screen (user-picked option 1)

From the top:

1. **The art, compact.** `WellDone` gets a compact form, `COMPACT_HEIGHT =
   340` (was 640): the sun and moon at about half size, "Well done!" under
   them, and the subtitle line kept (several boards put their result there
   through `flat_win()`: Golden Acorn's right answers, Mini Golf's strokes,
   Gumdrop's moulds). A board with a cast (`set_cast`) keeps its cast,
   scaled into the same strip.
2. **The report card** (new `ui/flat/brain_report.gd`) takes the board's
   place in the middle. It is a paper plate in the house style, the size of the
   room between the art and the bottom rows, coming in as the board's wave
   ends (`max(SLOT_TIME, hold)`). The solved board fades out under it. An
   **eye button** at the card's top right (Icons `eye`) brings the board
   back while held (hold to peek) for picture boards. Inside the card:
   - **Skill line:** the icon, "Sudoku trains **Logic**", and the skill's line
     in small type.
   - **Score row:** a ring with the skill's score (the ring fills to the
     score, in the skill's colour), and beside it: the gain, the time with
     "1:28 faster" or "0:40 slower" against the player's mean on this board
     and level, the hints with "1 fewer" or "2 more" against their mean, and
     for a board with a measure, "Precision N%" (`q` as a percent). The first
     solve of a board and level says "Your starting point" instead of
     comparisons.
   - **Tip panel:** "Next time try" and the chosen tip (section 6).
   - **Your brain:** five rows, icon, name, score and bar, today's skill
     first and highlighted, with the gain drawn as a green tip on its bar. Below
     them, one line: "<Skill> is your lowest. Try <Board>." The board is the
     least-solved board of the lowest skill, ties going to registry
     order. A skill not yet trained counts as lowest ("You haven't trained Words yet.
     Try Hidden Word."). The line is hidden when the lowest skill is today's.
3. **The bottom rows** as they are: stats card (day, hearts and gold line,
   "m:ss · moves · hints"), the next-level invite, Redo and Back.

**Fitting it:** the card measures the room it was given. When the room is
short, the brain rows shrink from 76 to 52 design pixels. Below that, the five
rows fold into a single row of five icons with their scores.

**Motion:** from `core/motion.gd`. The card slides up and fades in, and the
ring and the bars fill from 0 over 0.6 s with `Motion.EASE`-style easing. The
gain counts up with the ring. `Motion.reduce` sets everything at once.

**Sound:** the ring filling plays no sound of its own (the win already has
its fanfare). Holding the eye is a touch, so it gets a pebble (select) from
the bank and a haptic, per "no ghost touch".

**Draw calls:** the ring, the bars and the plate are drawn in one `_draw` and
cached as one mesh (`docs/agents/flat-screens.md`), with labels as nodes.
The total stays under 855 on the heaviest board.

**Bleed boards** (Gumdrop, Jewel Box, Toy Cannons, Hidden Word...): the card
is a plate over the world, like the other chrome, and `set_clear` is told the
card's rect.

## 6. Every board: measure and tips

Columns: **T** = time counts. **q** = `skill_quality()`. Tips: **1** is the
starter (first solves), **2** is "before you ask for a hint", **3** is
"sharpen" (below par or slower than usual), and **4** is the Insane technique or
the board's deeper tip. Tip text is in English here. Each tip becomes the key
`BRAIN_<PFX>_<n>` in `locale/boards.csv` (PFX = the board's locale prefix:
HW, SD, RG...), with pt and es written alongside.

**Choosing the tip (my call):**
1. Insane and no hints → tip 4.
2. The first or second solve of this board at any level → tip 1.
3. Hints used → tip 2.
4. `q < 0.7`, or the time more than 25% over the player's mean → tip 3.
5. Otherwise rotate between tips 1, 3 and 4 by the day key, so a clean
   player sees a different tip each day.

### Logic

| board | T | q | tips |
|---|---|---|---|
| sudoku | ✓ | — | 1 Scan one number across a band of regions to find the only cell left for it. · 2 Look for a cell that can take just one number before asking. · 3 Pencil in candidates, then find two cells in a unit that share the same pair. · 4 A hill with no dots is smaller than every neighbour; four dots, larger than all. |
| binairo | ✓ | — | 1 Two alike side by side: the cells at both ends get the other symbol. · 2 Two alike with one gap between: the gap gets the other symbol. · 3 Once a line holds half of one symbol, the rest are the other. · 4 A × means one of each, a = means the same: follow the chains. |
| queens | ✓ | — | 1 Start with the smallest colour patch. · 2 A patch that lies in one row or column rules out the rest of that line. · 3 If N patches fit inside N rows, every other patch is barred from those rows. · 4 A cell that would cross out a whole patch can never hold a queen. |
| lightup | ✓ | — | 1 A 4, or a 3 against a wall, has only one way to place its lanterns: do those first. · 2 A 0 means no lantern next to it: mark all its neighbours off. · 3 Find a dark stone only one empty spot can still light: that spot holds a lantern. · 4 When a number is met, every other cell beside it is empty. |
| shikaku | ✓ | — | 1 Start with big numbers and numbers in corners: they fit few ways. · 2 A cell only one number can reach belongs to that number's plot. · 3 A 5 or a 7 can only be a straight line. · 4 Use the square, tall and wide signs to cut the choices. |
| bridges | ✓ | — | 1 A number twice its neighbour count needs two planks to each neighbour. · 2 A 3 with two neighbours needs at least one plank to each. · 3 Two 1s can't link only each other, or they're cut off. · 4 Before the last planks, check no group is closed off from the rest. |
| nonogram | ✓ | — | 1 Slide a run to both ends of its line: cells covered both times are filled. · 2 Start with lines whose clue nearly fills them. · 3 Cross out cells you know are empty; they force the runs elsewhere. · 4 Switch between rows and columns: each pass opens the other. |
| lattice | ✓ | par/swaps | 1 Look for two tiles that belong in each other's cells: one swap sends both home. · 2 A line can't repeat a number: rule out what's already green in its row and column. · 3 Only swap when at least one tile goes home. · 4 A knot's sum, less the green tiles it points at, tells you what the rest add up to. |
| hedgehogs | ✓ | 1/(1+woken) | 1 When a number equals its covered neighbours, they're all hedgehogs. · 2 When a number's flags are all down, tap it to rake the rest. · 3 Compare two neighbouring numbers: the difference speaks about the cells only one touches. · 4 Flag early on Sleepwalkers: a flagged hedgehog never walks. |

### Space

| board | T | q | tips |
|---|---|---|---|
| quilt | ✓ | — | 1 Lay the biggest or oddest patch first. · 2 Fill corners and narrow gaps early: few shapes fit them. · 3 Count the bare squares and check the patches left add up to it. · 4 In the Scrap Basket, that count tells you which patches are extras. |
| pinwheel | ✓ | par/moves | 1 Settle corner and edge cells first: few pieces reach them. · 2 A piece pinned fast is a wall to build around. · 3 Count the quarter turns before you tap: one too many costs three more. · 4 On Ribbons, work from the top of each ribbon down. |
| untangle | ✓ | par/moves | 1 Move the peg of the rope lying on top: it slides off free. · 2 Clear ropes that cross only one other rope first. · 3 Leave the rope underneath for last: moving it wraps it once more. · 4 Short ropes reach only nearby holes: plan them early. |
| fairylights | ✓ | par/moves | 1 Start with corners and edges: a piece there can't point off the board. · 2 A piece by the edge often has one way to sit. · 3 Turns only go clockwise: count them before tapping. · 4 On Wish Tags, follow the distance numbers back to the post. |
| sunbeam | ✓ | par/moves | 1 Work back from the bud: which mirror could feed it? · 2 A cup sends light back one lane over. · 3 Hold a piece to see the beam before letting go. · 4 On Shy Dew, set every drop's path first and light them in one last move. |
| minigolf | — | par/strokes | 1 Bank off the kerbs when the cup is blocked. · 2 Hit softer near sand and water: a short putt is cheaper than a pond. · 3 Leave the ball where the next putt is easy, not just closer. · 4 On Swing Gates, putt so the gate you need is open when the ball arrives. |
| horse | ✓ | score/best | 1 Water and boulders are free walls: spend bales only on the gaps. · 2 One bale across a narrow neck seals a whole region. · 3 Bend the fence out to take in apples and keep beehives out. · 4 With tunnels, both mouths go inside the pen or both outside. |

### Planning

| board | T | q | tips |
|---|---|---|---|
| slider | ✓ | par/moves | 1 Work back from the gate: which blocks must leave the red block's path? · 2 Keep a pocket free for blocks to wait in. · 3 One long drag counts once: beat several short ones. · 4 On Homesick, clear the way below before the red block comes down. |
| rings | ✓ | par/moves | 1 Keep one peg empty as working space. · 2 Never start an empty peg with a colour you can't finish soon. · 3 Build the colour that's closest to a full tower first. · 4 On Hidden, uncover face-down rings early so you can plan. |
| planes | ✓ | — | 1 Start at the rim: planes pointing out near the edge go first. · 2 Follow a blocked plane's lane to the one in its way, and clear that. · 3 Sweep the sky in passes, not at random. · 4 On Windy Day, check where the clouds go next before launching. |
| knight | ✓ | opt/moves | 1 Never land where a rose knight can hop. · 2 Picture each rose knight's next hop before yours. · 3 Work back from the king: plan a route to a square one hop away. · 4 On Brambles, keep open squares behind you; don't box yourself in. |
| trestle | ✓ | 1/tests | 1 Build in triangles: squares fold. · 2 Run diagonals from the road down to the bank pins. · 3 After a test, add a beam beside the reddest member. · 4 At the Tea Party, keep the road flat and well held along its length. |
| train | ✓ | par/taps | 1 Send a cannon only when its colour shows on the rug's edge. · 2 Keep tray slots free: a parked cannon blocks the space. · 3 Clear blocks that cover other colours first. · 4 Look at what's next in every line before choosing which to fire. |
| caterpillar | ✓ | — | 1 Never leave a square with one open neighbour, unless it's the last leaf. · 2 Sweep edges and corners early so they aren't stranded. · 3 Follow walls and fences in long runs instead of zig-zags. · 4 Count squares like a chessboard to check the next leaf can still be reached. |

### Focus

| board | T | q | tips |
|---|---|---|---|
| pixelgarden | ✓ | — | 1 Drag along rows and columns to lay whole runs at once. · 2 Work one colour at a time. · 3 If a colour runs out early, one of its beads is in the wrong place. · 4 Count from a fixed landmark: an edge or the middle. |
| hoop | ✓ | 1/(1+0.2·slips) | 1 Count each panel's corners before you thread it. · 2 Thread shared sides: one thread finishes two panels. · 3 Keep your finger down and chain sides into long runs. · 4 On big pictures, zoom in and finish one patch at a time. |
| gumdrop | — | mean match | 1 Go a little at a time: past the card's shade it only gets darker. · 2 Watch the fill ring on the pink button. · 3 Small pieces darken fast: fill them gently. · 4 To mix, put half of each flavour into the same piece. |
| buttons | ✓ | par/taps | 1 Set a jewel where it floods the biggest bare patch of its colour. · 2 Runs already touching their own slots finish in one tap. · 3 Use the case to join scattered runs, so one tap moves them all. · 4 Don't fill the case with colours whose slots are still blocked. |
| drumbeat | — | accuracy | 1 Watch the ring, not the berries far up the road. · 2 Hold through ribbons until they end. · 3 Don't tap when nothing is due: stray taps break the combo. · 4 On Echo, repeat the bar you just played from memory. |

### Words

| board | T | q | tips |
|---|---|---|---|
| hiddenword | ✓ | (8−rows)/7 | 1 Open with five different common letters. · 2 Use an early guess to test new letters, not to win. · 3 An amber letter goes somewhere else next time. · 4 On Snail Mail, plan two guesses that share no letters. |
| wordtrail | ✓ | 1/(1+0.5·misses) | 1 Start at dead ends: a tile with one open neighbour starts or ends a word. · 2 Match the longest word to the long open corridors. · 3 Don't leave a pocket of tiles no word can fill. · 4 Look for common word endings against the walls. |
| pearl | — | depth/max | 1 The first listed answer ends the prompt: skip the obvious one. · 2 List a few options in your head before you type. · 3 Wrong answers cost seconds: don't guess wildly. · 4 On narrow prompts, think of the odd corners of the topic. |
| acorn | — | rights/questions | 1 Rule out the clearly wrong answers first. · 2 Save the bulb for a question you're split on. · 3 Read the line after each answer: topics come back. · 4 On The Climb, slow down as the questions get harder. |
| how_big | — | total/max | 1 Compare what the bracket measures, not the whole outline. · 2 Work out how many times bigger before you drag. · 3 Within 6% is full marks: don't over-fiddle. · 4 On the Ladder, an early miss carries up every rung. |

`q` formulas are clamped to 0..1. "par/moves" means `par / max(moves, par)`.
The builder takes each variable from the board's own state, using the names
in the survey notes (section 9).

## 7. Analytics

`puzzle_complete` gains `skill` (id), `skill_score` (after) and `p`
(rounded to 2 places), so the tuning in section 4 can be read from
Firebase later.

## 8. Left to the builder

- Exact pixel layout inside the card, as long as section 5's order and
  the fitting rule hold.
- The icons' exact geometry within section 2's descriptions.
- pt and es wording for every new key.
- Where `q` is read on each board (a `skill_quality()` on the board script,
  reading its state), and logging it through `kept` in `_on_solved`.

## 9. Survey notes (where each board's measure lives)

Hearts and move budgets are off on every board except Insane on Hidden Word,
Toy Cannons, Golden Acorn, How Big?, Trestle and Drumbeat. `checks` counts
nothing on most boards. Measures: lattice `state.swaps`/`state.par`; pinwheel
`moves`/`_state.par`; untangle `moves`/`state.par` (`_all_moves`); fairylights
`moves`/`state.shortest_solve()`; sunbeam `moves`/`_state.shortest_solve()`;
slider `moves`/`_state.par`; rings `moves` against the solver line; knight
`moves`/`g.opt`; trestle `_tests`; train and buttons `state.taps`/`state.par`;
hedgehogs `_state.woken`; hoop `state.refused`; gumdrop `sim.marks`;
drumbeat `_st.goods/oks/bads`; hiddenword `state.rows.size()`; wordtrail
`_state.misses`; pearl `state.results[].t` (max 10 a prompt); acorn
`state.results[].right`; how_big `state.results` scores (max 100 a round);
minigolf `_state.card` against `par_total()`; horse `state.score()`/`state.best`.

## 10. Builder check answers (2026-10-22, my calls)

- **Every daily board is `bleed`.** None has a board slot, so the card doesn't
  replace a slot. It is a plate laid over the world in the room between the
  compact art and the bottom rows. The host only
  tells boards a smaller top inset (`set_clear` with the compact art's
  height), so each board lays its solved picture in that room, under the card,
  as it does today. No board script changes for the layout. The world stays
  visible around the card. **The eye is on every board**: while it is held the card
  fades out and the solved picture shows.
- **Old untimed records:** `p = 0.5` before hints (section 4.4).
- **The subtitle stays** in the compact art (section 5).
- **The measure line** is "Precision N%" from `q`. Nothing raw is logged, only `q`.
- **Marigold** (Arcade, flat host, no skill) keeps today's win: full art, no
  card. `flat_host` keeps both layouts, chosen by whether the entry has a `skill`.
- **Mini Golf is untimed.**
- **Redo's solve** isn't logged (one record per board, level and day), so it
  shows the report with no gain, like a reopened daily.
- **Motion:** the eases come from `core/motion.gd`'s own helpers.

## 11. As built (2026-10-22)

- A drop in score shows as "−N" in dim ink. Only a gain is green.
- Draw calls on Gumdrop's win: 75 → 158 with the plate (budget 855). The
  plate is drawn with plain `draw_*` calls rather than baked into a mesh. Bake it if a
  heavier board's win ever comes near the budget.
- Boards whose `flat_win()` sets a cast or a subtitle with no faces hide the sun
  and the moon (`set_cast`). That was so before this change, and the compact
  strip keeps it.
- Trestle's `q` reads `_tests_all` (every Go since the board opened), because `_tests`
  resets on Try again. Rings' line comes from the solver at the win (its par is 0
  on every band), and Gumdrop's `sim.marks` holds only passing serves.
- Verified: the headless suite (163137 passed, 0 failed); `tests/_win.gd` over
  every board, 30/34, where Hoop, Drumbeat and Marigold fail on main too and
  Gumdrop passes alone; windowed shots of Sudoku and Gumdrop with seeded
  history; probes of `Brain.report`.
