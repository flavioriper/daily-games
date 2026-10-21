# Gumdrop

- **Gumdrop is the thirty-sixth card** (2026-10-11, `puzzles/gumdrop2d.gd`,
  `puzzles/gumdrop_table.gd`, `puzzles/gumdrop_sim.gd`,
  `puzzles/gumdrop_mould.gd`, `puzzles/gumdrop_art.gd`,
  `puzzles/gumdrop_fluid.gd`, `shaders/gumdrop/`; specs
  `2026-10-10-arcade-gumdrop-design.md` for the pour and
  `2026-10-11-gumdrop-daily-design.md` for the day). Clear jelly in a walled
  mould, coloured with a dropper of syrup to match a card, after a browser
  game the first spec names once to forbid; **it is called Gumdrop and
  nothing else**. It was the eleventh Arcade game for a day (built
  2026-10-10); the user, 2026-10-11: "i want you to convert gumdrop into a
  daily game not arcade", then two calls in chat (a set of moulds per band;
  the full-screen table with the daily chrome over it) and "all good, build
  it". No concept tab: the look and the pour are the built screen's.
- **A day is a band's few moulds** (`Mould.BANDS`, `Mould.day(band, rng)`,
  off the day's seed, easiest first): Easy 2 moulds of 2 or 3 cells in two
  flavours at 60%; Medium 3 of 3 to 5 cells in three at 65%; Hard 4 of 3 to
  6 cells in three or four, one of them mixed from two pots, at 70%; Insane
  is **Three Pots**, 5 moulds of 4 to 8 cells at 75% with only cherry, lemon
  and blueberry stood by the tray, so every orange, lime and grape is mixed.
  A mould at its mark or over is taken away and the next set down; the last
  one served is the day solved, there and then (`done` comes with the
  verdict, not after its showing).
- **Easy to Hard cannot be lost**: a mould under the mark shows its number,
  is emptied and poured again (`again`). Reset empties the mould on the
  tray (`Sim.empty`).
- **Insane counts nothing** (since 2026-10-12, the user: "remove any move
  limit or time limit from insane, all insane games must be insane for
  difficulty not because it limit player movements"; commit 517c37ff): a
  flop on Insane is emptied and poured again as on every band, and no day
  can be lost. Until then Insane had a budget of serves (the moulds and one
  more), a "Not enough serves" card with a video, a serves pill beside the
  squeeze button and a tutorial page on it; the count's leftovers (the
  sim's `budget`, `SLACK`, `Phase.OVER`, `revive`; the table's pill; the
  board's card path, `max_moves` and the page; `GD_SERVES_*`, `GD_OUT_*`,
  `GD_RULES_SERVES`, `TUT_GUMDROP_SERVES`; the harness's `lose` mode; the
  probe's five checks, failing since) went on 2026-10-14 at the user's
  word ("can we fix this insane serves pill?", put to them as restore or
  remove: remove). Reset on every band empties the mould on the tray.
- **No Undo, bulb or Check on any band** (`capabilities()` is empty): the
  match is a `?` beside the card until Serve, and syrup is taken out by
  the table's own grey button (the drain, 2026-10-14, below), not an Undo.
  A serve is the one move, so the win's line counts serves as moves.
- **The table is the whole screen** (`"bleed": true`; the host's side of it
  is in `docs/agents/flat-screens.md`). The board is a thin
  `puzzle_base` over `gumdrop_table.gd`, which was the Arcade screen: the
  field, the syrup, the top, the fingers, the fluid's drive, the stickers.
  The host says what its rows cover (`set_clear(top, bottom, won)`) and the
  table lays the card, the tray, the pots and the two buttons in what is
  left. The table hands each of the sim's events on (`happened`); the board
  counts the serve, ends the day on `done` and opens the card on `over`.
- **The win is one transform**: the card, the pots, the buttons and the
  dropper fade (`_win_k`) and the tray is carried to the middle of the span
  the win screen leaves (`_win_tray`), scaled, with no mesh rebuilt. The
  win screen's row is three gumdrops (`Jelly` in `gumdrop2d.gd`, seated as a
  board's faces are; no mascot, the pieces are marks) and its line the
  day's numbers ("Served at 100% · 98%").
- **The done day**: the fluid cannot be saved, so the record is each
  mould's match (`{"pct": [...]}`) and a finished day reopened is its last
  mould filled as the card has it (`Sim.finish`, through the tutorial's
  prefill) under the same win.
- **The sim is the day, not the syrup** (`puzzles/gumdrop_sim.gd`, fixed
  1/60 s): `set_day()`/`deal_day()`, `pick()`, `aim()`, `squeeze()`,
  `serve()`, `empty()`, `restart()`, `revive()`, `finish()`, `step()`,
  `events`, the mould, the pots, the tip and which cell it is over
  (`tip_cell`, a 36 by 36 grid plus the inner polygon, so a wall is no
  cell), the mark, the serves, and the colour maths (`hue`, `strength`,
  `deep`, `colour`, `nearness`). A served mould settles `SETTLE_T` and
  emits `judge`; the table answers `judge(near, all)` from the fluid and
  the verdict follows. `tests/_probe_gumdrop.gd` (headless, seconds) proves
  the moulds, the bands' days, the colour maths and the day's run with a
  judge answered by hand; the syrup cannot run headless, so
  `tests/_shot_gumdrop.gd` is the play test, its bot reading the fluid
  back.
- **The syrup is `puzzles/gumdrop_fluid.gd`**, a Node of sibling
  SubViewports in tree order (this renderer draws them in that order in
  one frame; the first of a frame reads the last of the frame before):
  advect, curl, vorticity, divergence, `JACOBI` sweeps of pressure,
  gradient, dye, keep, judge; the mask first. Velocity `SIM` 128
  square, dye `DYE` 256. Shaders in `shaders/gumdrop/`, the maths in
  `fluid.gdshaderinc`. **Eight bits a channel** (no HDR 2D on
  gl_compatibility): signed values are packed across two bytes and
  fetched by texel, the velocity blended by hand. **The dropper is a
  jet** that turns slowly, never a push straight out (all divergence, the
  pressure takes it back). **The dye settles** toward its neighbours
  each frame (`SETTLE`, `SETTLE_R` 3 texels: it irons a fold) and the
  jelly turns viscous once the button is let go; a cell nothing is being
  poured into settles toward eight texels far off as well (`FAR` 0.4,
  `FAR_R` 14), which is what makes two flavours one shade (the entry of
  2026-10-11 below); past `POUR_TOP` new dye displaces old, so
  a second flavour shifts a full cell. **The dye is fetched by texel
  with a mask check on every tap**: read through the sampler's linear
  filter it blended with the black wall texels and the settling blur
  drained every cell from its rim (fills fell from full to 0.65 in five
  seconds of rest). **The judge has an eye's tolerance** (`NEAR_FREE`
  0.1, `NEAR_GONE` 0.8 of the way off). Each frame the table's `_drive` sets the
  tip, its cell, the squeeze, the pigment and the drag, and `tick(delta)`
  writes the uniforms; `set_running` turns the passes off under a card (`held`) and
  five seconds after the day is done (`DONE_RUN`). `measure()` reads the judge pass
  back (once a serve, or a bot's few times a second; nothing headless).
  A tutorial page's prefilled cell goes in through `sim.prefill` and the
  dye pass's `fill_cell`.
- **The colour is the sim's** (`Sim.hue`, `strength`, `deep`, `colour`,
  `nearness`), because the judge compares colours: a texel's strength is
  `1 - exp(-c / C0)` scaled to 1 at `C_FULL` (the card's own shade), and
  past `C_FULL` the hue is deepened toward its square, `DEEP` at twice it.
  **The match of a texel is how near its colour is to the card's**, as a
  share of the way from clear to the card's colour (so lemon and cherry
  are judged alike); a cell's is its texels' mean, the mould's all of
  them. A heavy hand goes darker than the card and matches less: that is
  the brake, now that nothing spills and the pots are bottomless. `Art`
  reads `FLAVOURS` from the sim, and the shaders carry the same maths
  word for word.
- **A jelly is a real thing in chunks** (`puzzles/gumdrop_mould.gd`,
  2026-10-11; the walled moulds cut by rule into sectors, a core or bands
  are in git before it). The user, over the screen of the game the first
  spec names once: "the jelly on the game should not have borders, it
  should be a real jelly with different colors and instead of a color
  picker it should be a needle that inject the color tint ... also we want
  to show real images to the user not random simple forms". **And, of a
  first build where the whole jelly was one piece and the tint ran
  through all of it: "it's wrong, the jelly need individual chunks to
  hold the colors"** -- so no wall is drawn, and every part of the picture
  is still its own chunk that holds its own tint. `PICTURES` is 29 things
  drawn in code (`parts(id)`: mushroom, watermelon, carrot ... rocket,
  balloon, rainbow), each its parts from the one underneath to the one on
  top, a flavour and the shapes it is made of (`ell`, `box`, `soft`,
  `within`). `build(id)` gives `cells` in that order (a part in two pieces
  is two cells; they overlap, and the chunk a point belongs to is the
  last that holds it, `cell_at`), `want`, the whole `outline`, and
  `seams`, what of each chunk's edge shows. The flavours are the
  picture's own; a band only says how the pots are stood (`dress`).
  `BANDS` rows: Easy 0-7 (two flavours), Medium 8-18 (three), Hard 11-26
  (one mixed flavour's pot left out where the picture has one), Insane
  19-28 (four and more, Three Pots). The fluid's mask is the cells drawn
  in order, the judge's table is 16 (`CELLS_TOP`), and the dye's fence is
  the chunk's number as it was the cell's, so the settling of the entry
  below works a chunk at a time; the flow may cross a seam, the dye never
  does. `Art.gloss_of` draws the seams as thin lines (`SEAM` 1.3 units,
  wider than the dye's texel so two tints never show meeting) and the
  clear rim; `Art.needle` and `Art.plunger` are the dropper's place, the
  plunger sinking as the button is held. `tests/_shot_gumdrop_bank.gd`
  draws every picture on one sheet (windowed): run it after touching
  `parts`. Seen on Medium on `opengl3_angle`: house, and two more, 100%
  each by the bot (which now goes from square to square of a chunk), 103
  to 112 draw calls. The probe's "twice the shade matches less" check
  was failing before this and is rewritten to what is true (1.00: the
  eye's tolerance made the heavy hand free). **Not seen**: the tutorial's
  pages on the mushroom, Hard and Insane, the menu card (the balloon),
  pt and es. **The user's to call**: the pictures themselves and their
  colours, which rows a band draws, pictures with parts as small as a
  fish's fin (14 squares).
- **The syrup is drawn once** through `shaders/gumdrop_syrup_2d.gdshader`
  from the fluid's dye texture: plain colour by the sim's maths, the
  strength in alpha. Lighting the dye from its slope (tried the same day)
  made every fold a crease of foil. **A canvas shader's `COLOR` already
  holds the texture's sample**: multiplying the result by it drew every
  flavour twice as dark (the first shots' mustard lemon). `LIGHT` is a
  canvas shader's own name: a constant called that fails to compile.
- **Three Controls, one over the other**: the field (table, tray, the
  mould's floor), the syrup, the top (walls, card, pots, buttons, dropper,
  one live mesh). The walls are strokes of the cells' own outlines drawn
  over the syrup, which is what hides it under them. Draw calls are in the list below.
- **The fingers are the field's** (`_on_field_input`): ScreenTouch,
  ScreenDrag and the mouse, hit by hand against the tray, the pots and
  the two buttons (`_place` lays them all). The drag is relative, so the
  finger is never on the tip. The harness presses with real touches.
- **The fingers are the field's** (`_on_field_input`): ScreenTouch,
  ScreenDrag and the mouse, hit by hand against the tray, the pots and
  the two buttons (`_place` lays them all). The drag is relative, so the
  finger is never on the tip. The harness presses with real touches.
- **The tutorial's bench is the same table** (`Bench` in
  `ui/hud/gumdrop_tutorial_diagram.gd`): laid out on 1040 by 640 of its
  own (`_place` overridden) and scaled to the page, worked by a `Round`
  whose plan says what the hand does when. Five pages: fill, soak, match
  (the number only once served, and the band's mark), mix, the buttons;
  Insane adds the serves page.
- **The boosters are gone**: `gd_full`, `gd_tall`, `gd_soft` and `gd_kind`
  held from its Arcade days come back as gold when the board opens (`OLD`,
  `Wallet.refund`, a sticker over the tray on the table's first sized
  frame; the harness holds two `gd_soft` and read 200 gold become 440). The
  best-moulds record in `arcade.cfg` is left where it is and read by
  nothing.
- **No words over the tray** (the user, 2026-10-11, of "Colour the jelly /
  Slide over the tray..." laid over the mould before the first squeeze:
  "remove this tutorial text on gumdrop, no other game have it"). The
  banner, its two labels, `_hint` and `GD_READY`/`GD_READY_LINE` are gone;
  `greet()` is the start sound only. The entry below is its history.
- **The words over the tray before the first squeeze were off the screen**
  until this pass: a wrapping label says how tall it is from the width it
  has, and at the deal that was none, so the box came out 5,765 tall with
  its lines centred far below the foot. `_place_banner` gives the two lines
  their width and `_fit_banner` sizes the box a frame later.
- **Sounds**: the Arcade set (`assets/sfx/gumdrop/`), found by the board's
  `puzzle_id`. `new_best` is unused; `game_over` is the day run out of
  serves. **The pour is liquid** (the user, 2026-10-11: "we need a more
  liquid sound for when adding liquid and mixing colors"): `pour` is a
  loop of syrup running, on the table's own player (`_pour_sound`), up
  while syrup goes into a cell and down when it stops; `drop` the first of
  it as the squeeze button goes down over a cell; `mix` bubbles every
  `MIX_GAP` while a flavour goes into a cell another has gone into
  (`_cell_pots`, cleared with the mould). The tutorial's bench has no set
  and so no loop. `docs/agents/sound.md` has the takes and the measure
  (`pour` reads `high`); the harness saw the loop start and stop and the
  bubbles on Hard's mixed cell. Unheard.
- **Measured 2026-10-11** (`tests/_shot_gumdrop.gd`, 810x1440,
  `opengl3_angle`, real touches, through the menu and the host): 100 to
  111 draw calls in play, 71 to 78 on the win and the done day, 163 to 168
  under the tutorial card. Easy: a mould served nearly clear at 49% is
  emptied, then 100% and 98%, solved in 3 serves, reopened done, Redo and
  Reset. Hard: the bot's four moulds at 91, 77, 96 and 76% in 7 serves (it
  mixes badly: it pours by strength, not by share). Insane with `lose`:
  two flops, the card, Try again with 6 serves, and the same under
  `reduce`. `tests/_win.gd -- gumdrop`
  winnable 1/1 (cells prefilled, served by a real press). The suite's parse
  guard walks the registry: 249,802 passed.
- **Two flavours in a cell become one shade in a second or two** (the
  user, 2026-10-11, with an Insane mould whose grape petal was red at one
  end and blue at the other: "colors are hard to mix"). The near settle
  alone never did it: read 3 texels off it crosses a petal of 70 texels
  in a quarter of a minute and more, and in eight bits it stops at a slope
  of two steps a read, about a fifth of the scale across the petal, so a
  mixed cell stayed two shades for good and the judge, a mean of texels,
  marked it down however right its share. The far settle is in
  `dye.gdshader`, eight taps each checked against the mask like the rest,
  and is off in the cell under a held tip, so a pour fills no faster than
  it did. No pass added. Seen on Hard on `opengl3_angle`
  (`tests/_shot_gumdrop.gd`): the mixed cell one even shade at the serve,
  107 draw calls; the bot's marks 88, 74, 98, 74 in 8 serves (91, 77, 96,
  76 in 7 before: it still pours by strength, and an even cell of the
  wrong share reads 0.2 to 0.5 near). Not changed, the user's to call: a
  mix poured onto a full cell climbs to `POUR_TOP` before it displaces, so
  it runs deeper than the card; and how wide of the share the judge
  forgives.
- **Each chunk is a tank of its own** (the user, 2026-10-12: "when player
  is pooring the tint, it keep doing the right waveling movement, but it's
  limited instead of filling all space, it only happen when user release,
  when doing it, it auto fill everything, it's not natural"). Since the
  chunks touched with no wall the flow ran across the seams and the dye
  did not: what the jet carried to a seam was lost there, and the flow
  coming back in on the other side kept that end clear for good. The far
  settle, off under a held tip, then levelled the chunk at the release:
  that was the flood. `shut_at` (`fluid.gdshaderinc`) makes another chunk
  a wall to divergence, pressure and gradient, as the tray is; advect,
  curl and vorticity are as they were, and so is the dye and its far
  settle. Read off the dye by `tests/_shot_gumdrop.gd -- <out> 1 pour`
  (the button held 4 s on Medium's first mould, then let go;
  `opengl3_angle`), share of the chunk tinted and its mean amount:
  before, 0.71 at 0.5 s and 0.72 at 4 s, then 1.00 half a second after
  the release with the mean fallen from 0.40 to 0.20 in two; after, 0.77
  at 0.5 s, 0.98 at 1.5 s, 1.00 by 2.5 s, and the mean 0.748 held and
  0.752 two seconds let go. Tried first and dropped: the far settle on in
  every chunk always (no flood, but the chunk one flat shade in half a
  second, no swirl), and the same at `FAR` 0.1 (the dye still left by the
  seam: 0.45 to 0.07 in two seconds). The bot still solves Hard: 96, 89, 74, 96
  in 5 serves on this day's moulds (another day's than the 88, 74, 98, 74
  above, so no before and after), 103 to 112 draw calls. **The
  user's to call**: the pour is now stronger, since nothing leaks (this
  chunk passes the card's shade, 0.5, inside a second, and a 4 s hold
  that left 0.20 leaves 0.75); `RATE` is the knob. Not played by hand, no
  phone.
- Owed: a phone (the fluid's 22 small passes a frame are untimed there,
  and the judge's readback at serve), the user's verdict on the pour, the
  sounds heard, pt and es read (neither was shot), the win and the play
  under `reduce` (only the Insane loss was run so), the card's video path
  (no video is ready on this Mac, so `heart_back` ran in the probe's sim
  only). **Calls that are the user's**: the marks (60/65/70/75) and the
  counts (2/3/4/5), nobody but the bot has played Hard or Insane; Three
  Pots as Insane's rule; the one spare serve; Reset on Easy to Hard keeping
  the day's serves counted; the win's three gumdrops.

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

### The day's theme (2026-10-14)

The user: "the gumdrop game should use the same picture themed approach of
the others picture games"; and, of an Insane day whose first mould was the
themed crab and the last a traffic light: "what this has to do with the
theme?". Spec: `docs/superpowers/specs/2026-10-14-gumdrop-themed-jelly-design.md`.

- **Every mould is a thing of the day's theme** when the night wrote it:
  Easy the theme's first two things, Medium three, Hard four, Insane five,
  each at its band's row of `Mould.THEMED` (flavours, mixed among them,
  chunks; one piece, inside 4-96, 9 squares a chunk, 20-75% covered). The
  night (`server/functions/src/jelly.ts`) writes them as parts in the
  twenty-nine's own shapes, so `build_parts` builds and `Art` draws them as
  it does `parts()`; `jelly.ts` RULES and `THEMED` change together.
- `ThemedPictures.jellies(daily_key, band)` reads the `pictures` document's
  `jellies` list for the band, builds each and drops one that breaks its
  row; `Mould.day(band, rng, themed)` deals them first in the theme's
  order and fills the places left from the band's rows, never a picture of
  a themed one's name. New (`bank_step`), no backend, no document: the
  twenty-nine as before. A themed jelly's id is `themed_<thing>`.
- The themed Insane crab (14 chunks; the twenty-nine stop at 6) poured and
  served at 89% by `tests/_shot_gumdrop.gd -- 3`'s bot, 118 draw calls.
  `tests/_probe_gumdrop.gd` checks the made days' jellies
  (`tools/days/themed-pixel/`) against `THEMED` and their deal; its five
  Insane-serves checks fail on `main` as well (Insane stopped counting
  serves on 2026-10-12) and were left as they are.
- Only this Mac sees it until `publishDay` writes `pictures` (the theme
  spec's stage 4, the user's deploy). Owed: a day with all fourteen kept
  (the first run lost five to an empty OpenRouter account), a phone, the
  user's eye on the jellies.

### A jelly, a drain and a meter (2026-10-14)

The user, over two screens of the game the first spec names once to
forbid (a green world map and a yellow banana, each a black glossy jelly
on a dark tray with the colour vivid inside it): "polish gumdrop ... to
make it way more like a jelly (right now borders make it look weird ...),
the tint should be more satisfactory to see it filling, also we need
another tool to remove fluid and a indicator about % of filled, so user
can have a reference when doing like 50% of each color. Do everything
autonomous". Built unattended on that; nothing of it seen by the user.

- **The jelly is a dark glossy gel** (`Art.floor_of`, `Art.gloss_of`;
  `GEL` 1e1f28 on a tray lightened to 474b5c so the two are no longer one
  value): two soft shadows, the gel's side (`GEL_SIDE`, `Mould.RIM` out
  from the outline) with a lit crescent along its upper left (a stroke of
  the outline moved up and left, which the gel then covers but for that
  crescent), the body a little lighter toward its middle (three insets of
  `offset_polygon`, 3.5% white each) and the sheen on top. **No light
  outline anywhere**: the grey strokes of the outline and the light seam
  lines were the "borders". A seam is a groove in the gel's own colour
  (`SEAM` 1.3 units, still wider than a dye texel) with a faint light edge
  on its upper-left side, so the chunks still read as pieces (the rule of
  2026-10-11 stands). The tint ends at the gel's side under a thin stroke
  of `GEL_SIDE` on the outline, so the dye's blurred edge never shows. The
  menu card's jelly (`ui/menu/cards/gumdrop.gd`) copies the same drawing.
- **The tint is a blob with a body** (`shaders/gumdrop_syrup_2d.gdshader`):
  opaque wherever the amount passes a short ramp (`EDGE_LO` 0.02 to
  `EDGE_HI` 0.09 of an amount), a darker lip just inside that edge (`LIP`
  0.72 up to `LIP_TO` 0.22), the colour `mix(MILK, colour_of, strength)`:
  **at the card's shade it is the card's colour exactly** (the judge's
  `colour_of`, the card's `FLAVOURS`), under it pale toward milk, as
  `nearness_of` sees a weak tint (it mixes toward white), and over it the
  deepening as before. No lighting from the dye's slope (foil, 2026-10-11).
- **The pour is paced for a meter** (`Fluid.RATE` 0.9, `SQUARES_REF` 23;
  superseded 2026-10-15, below: a bigger chunk takes longer now):
  pigment a second at the tip is the rate into a chunk of 23 squares or
  fewer and grows with a bigger chunk in proportion, so every chunk takes
  about the same hold to reach the card's shade. Before, 20 into any
  chunk: the mushroom's stalk passed the card's shade in half a second
  (0.57 of the texture's top at 0.5 s, read 2026-10-14 before the change),
  which no meter could be read against; the 2026-10-12 entry left `RATE`
  as the user's knob and a meter to hit 50% by is that call made. Read
  now (`tests/_shot_gumdrop.gd -- <out> 1 pour`, `opengl3_angle`): the
  stalk 21% at 0.5 s of hold, 58% at 1.5, 90% at 2.5 (the meter's own
  reading 95%), 134% at 4 s; let go, it holds (139% two seconds later).
  **The jet is untouched** (the spread across the chunk is 2026-10-12's).
- **The drain** (`Sim.drain`, `Sim.draining`; the dye pass's `draining`
  and `drain` uniforms; `Art.drain_button`): a grey round button
  (`DRAIN` 7b8496, no flavour's colour: the pots are coloured by index)
  to the right of the squeeze button, at `SERVE_OFF`, the serve's mirror,
  held like the squeeze: pigment is taken out about the tip at the pour's
  rate (`Fluid.DRAIN` 1.0), every pigment in its share, and the far settle,
  on since nothing is squeezed, levels the chunk down with it. The needle's
  plunger rises, the rings run into the tip, the pour loop plays lower
  (`DRAIN_PITCH` 0.78), the button greys while nothing is in the mould.
  Read: 139% to 113% at 0.5 s of hold, 54% at 1.5, 6% at 3 s. **Nothing
  is added to the jet**: a point sink is all divergence and the pressure
  cancels it, as the push straight out was. The drain stands where Insane's
  serves pill once stood (the pill was dead code by then, see "Insane
  counts nothing" above, and went the same day).
- **The sim's tally is per chunk and put right by the fluid**
  (`Sim.tank`, `learn`, `WET` 0.02, `RATE` 0.5 amounts a second): `wet()`
  used to be "ever squeezed", so a mould drawn fully out would still serve
  (at 0%, a serve spent on Insane). Now each chunk's amount is the sim's
  reckoning until the table hands it the meter's reading (`learn`, every
  frame the tip is over a chunk and the meter has been read), and the
  mould is wet while any chunk holds more than a trace. Headless, the sim
  reckons alone.
- **The meter** (`shaders/gumdrop/meter.gdshader`, `Fluid.level`,
  `Art.meter`, the table's `_draw_meter`): a pass of `CELLS_TOP` texels
  by one, each a chunk's mean pigments over the dye at a stride of 4,
  read back at most every `METER_GAP` 0.1 s (sixteen texels, in place of
  the judge's whole picture). The squeeze button's white rim is the
  track: it fills clockwise from the top with the chunk under the tip,
  **a segment a pigment** (cherry, lemon, blueberry in the card's
  colours), 100% the card's shade (`C_FULL` of amounts), marks a quarter
  apart, the number under the drop (`METER_FONT` 28); past full by more
  than `METER_SLACK` (8%) the number turns ink and a dark ring climbs
  outside the rim, to 160% at the dye's top. So a mixed flavour's "half
  of each" is two equal halves of the ring. Eased at `METER_EASE` 12 a
  second toward the reading, faded at `METER_FADE` 6 when the tip is over
  the tray or the mould is served; "0%" shows over an empty chunk. The
  mesh is built each frame it is shown (its arcs change), as the rings
  are.
- **The words**: `GD_RULES` gained the grey button and the ring in the
  three languages; `TUT_GUMDROP_HUD_BODY` no longer says syrup cannot be
  taken out; a sixth page, `TUT_GUMDROP_DRAIN` ("Draw it back out",
  `Lesson.DRAIN` after SOAK) prefilling the stalk at 150% and draining it
  to about 90% as the ring reads it. The bench lays three buttons
  smaller (`_squeeze_r` 92, `_serve_r` 56, `_drain_r` 56, the radii now
  vars the board's `_place` sets from the constants). Reimported with
  `godot --headless --path . --import` (a CSV row is nothing on screen
  until then: the first tutor run read "TUT_GUMDROP_DRAIN").
- **Measured** (`opengl3_angle`, 810x1440; the probe 0 failed once the serves checks went): play 115 to 122 draw calls
  (100 to 111 before: the meter's mesh and string, the third button, the
  gel's insets), the win 75 to 82, the tutorial 176 to 180. Medium by the
  bot: 100, 85, 100 in 4 serves (one flop by hand first), the win, the
  done day, Redo and Reset as before. The probe's five Insane-serves
  checks fail as they did on `main`. `tests/_shot_gumdrop.gd -- <out> 1
  pour` now holds the drain three seconds after the pour and prints the
  meter's reading, the shown number and the sim's tally at each still.
- **Calls that are the user's**: the rate (2.6 s of hold to the card's
  shade on a 92-square chunk; `RATE`) and the drain at the same; the gel's
  darkness against the tray; the milky pale of a thin pour (the judge's
  own reading of it, so pale means "more"); the number on the button
  rather than at the tip or by the card; the pill's corner on Insane; the
  grey of the drain button. Owed: a phone (the meter pass's 65k fetches
  and its tiny readback are untimed there), pt and es, the sounds heard (the loop at 0.78 was not).

### A pour let go stays where it is (2026-10-14, later)

The user, with the day in hand: "the pour pace is right, but there is a
problem yet, for example when I click to pour and release, the liquid
should not change but keep filling everything as it spread. Right now when
player release, the liquid auto fill everything." Read with
`tests/_shot_gumdrop.gd -- <out> 1 dab` (new: the button held 0.7 s over
the biggest chunk, the mushroom's cap, and the chunk read 0.1 to 4 s after
the release): the cap was 49% tinted at the release and 100% four seconds
later, one flat shade. Three things spread it, found one at a time:

- **The far settle pulled clear texels up** (`FAR` 0.4 a frame, read 14
  texels off): any texel of the chunk blended with eight far ones, so the
  clear half filled from the tinted half in a second. Now a texel under
  `front` (0.03 of the texture, just under the blob's visible edge) is
  clear to both settles: it neither takes nor gives, and a far tap that is
  clear counts as the texel's own. The blob's body still levels, shade and
  amount, and two flavours in it still become one (Hard by the bot 99,
  89, 87, 82 in 5 serves, the mixed chunk among them). Tried and dropped:
  blending the shade only and not the amount (the blob held, but a chunk
  poured unevenly stayed uneven and the bot's Hard fell to 84, 79, 73, 71
  in 9 serves).
- **The near settle leaked into clear texels** (`SETTLE` 0.25, 3 texels
  off, in eight bits): gated the same way, and `SETTLE` 0.14.
- **The dye rode a flow that never rests**: semi-Lagrangian advection
  traced back a fraction of a texel reads a blend of neighbours, and the
  flow at rest is slow but never nothing, so a blob let go smeared over
  its chunk in a few seconds whatever `VISC_REST` was (2 or 8: the same
  read). Now the dye rides the flow only while its chunk is poured into
  and for a moment after (`carry`, e^-t/`Fluid.CARRY` 0.15 s after the
  release), and a texel the flow moves under `still` 0.2 texel a frame
  keeps its own dye. `VISC_REST` is 8 (the flow dies in a quarter second,
  which nothing sees now). Tried and dropped: decaying the pressure's warm
  start with the flow (the projection fell apart: the dye drained to a
  sixth and the flow grew), and taking the pressure off only while poured
  (the flow still read a few texels a second, which turned out to be the
  harness reading a three-byte image as four; the readout now uses
  `get_pixel`).

Read after: the cap 49% tinted at the release, 58% half a second later
(the jet's last push) and 58% at 4 s, the mean amount the same throughout,
the top amount falling from 0.57 to 0.28 as the body levels; the jet's
fingers stay as the blob's outline. The pour while held is as it was
(`pour` reads the same). Unseen by the user on this; the knobs are
`front`, `still`, `CARRY`.

### A tint in water (2026-10-14, evening)

The user, over the day before's "a pour let go stays where it is": "right
now when player release button, the color freeze. Instead, it should keep
doing the exactly same behavior of moving around to fill available space,
the difference is that the color will be way lighter after space filled.
Also, if user keep pressing the button, the color should keep expanding to
take all available space, since it's a liquid as user keep pressed, the
new liquid will pull the already in liquid further and further till it
fill everything, if 100% no more liquid can be added. It has to act
exactly like water tint." So the earlier "auto fill everything" was about
the result (the chunk one flat shade, as dark as the pour, in a second),
not about the spreading; the three gates of that entry read it too far
and are gone.

- **The dye spreads and keeps its pigment** (`shaders/gumdrop/
  dye.gdshader`): it rides the flow held or let go (`carry` and `still`
  gone), and both settles work on every texel of every chunk, clear or
  tinted, under the tip or not (`front` gone, the far settle no longer off
  in the poured chunk). Each settle is a mean over a symmetric stencil
  whose taps outside the chunk read the texel's own, so the chunk's
  pigment is kept as it spreads (textbook advection-diffusion, mass
  conserved): a dab let go goes on spreading until it is one shade over
  the chunk, paler for it; a pour held pushes what is in ahead of it to
  the far end. `FAR` is 0.08 (0.4 made the chunk one shade in a second,
  the "auto fill"; a tint now takes a few seconds to reach the far end,
  and two flavours in a chunk a few more to become one).
- **The flow coasts** (`Fluid.VISC_REST` gone): the jelly keeps the same
  viscosity held or let go (`VISC` 0.6), so the jet's last push carries
  the dye round for a few seconds and dies on its own. The vorticity
  confinement stays held-only: on at rest it fed the swirl for good (top
  speed 103 texels a second four seconds after the release, half the
  pour's own; with it held-only, 84 at two seconds and falling).
- **A chunk takes no more past the card's shade** (`Fluid.rate_now`,
  `FULL_EASE` 0.06; `Sim.step`): the rate eases to nothing over the last
  6% of `C_FULL` as the meter reads the chunk under the tip, and headless
  the sim's own tally stops at `C_FULL`. The ring stops at 100 and the
  grey button is the only way down. **Gone with it**: a second flavour
  poured on a full chunk no longer shifts it toward itself (the drain is
  the fix now; `pour_top` still caps a texel so nothing goes black under
  the tip), and the meter's past-full ink and dark ring are reached only
  by the tutorial's drain page (prefilled at 150%). `GD_RULES` and the
  SOAK page still say "past the card's shade it goes darker": true of the
  tutorial's prefill and a texel under the tip, not of a chunk's mean;
  left as they are.
- **The syrup's lip is faint** (`gumdrop_syrup_2d.gdshader` `LIP` 0.92,
  was 0.72): at 0.72 the thin front of a spreading tint was a grey fringe
  over half the chunk.
- **Read** (`tests/_shot_gumdrop.gd -- <out> 1 dab` and `pour`,
  `opengl3_angle`, 810x1440): the cap held 0.7 s is 59% tinted at the
  release, 82% half a second on, 91% at 1 s, 100% at 2 s, its mean amount
  0.150 to 0.149 of the texture across the four seconds (0.168 at the
  peak) while its top falls 0.565 to 0.216: the same yellow, pale over the
  whole cap. The stalk held: 21% at 0.5 s, 61% at 1.5, 98% at 2.5, 100% at
  4 (the meter 1.25 amounts exactly), 100% still two seconds after the
  release; drained 92, 44, 15 at 0.5, 1.5, 3 s of hold. The drain leaves a
  clear hollow about the tip that the settles close more slowly than they
  did (seen in the drain shot; not raised with the user). Hard by the bot
  (`-- <out> 2`): 92, 88, 80, 90 in 5 serves after the flop by hand (99,
  89, 87, 82 the day before: the mixed chunks read 0.4 to 0.7 near, since
  two flavours take longer to become one at `FAR` 0.08, and the bot waits
  five seconds). The headless probe 0 failed, the suite passed; play 115
  to 121 draw calls, the win 75 to 80, as before.

### The cap on the GPU, and the drain's own rate (2026-10-14, later)

The user, with a Hard stalk reading 144% on their desk: "gumdrop not yet,
it should never pass 100%". Not reproduced here with the commit before
this one: the stalk held 18 s stopped at 100 and stayed there (`pour` on
Hard, and a new `wander` mode that draws the tip about the chunk and over
its seam while held, with the pots changed in turn in a throwaway), so
their game was most likely launched before that commit. Two things were
wrong all the same:

- **The drain took nothing out of a full chunk**: it took at `rate`, which
  the cap had just made nothing at 100%. The dye pass has `drain_rate`
  now (the pour's rate before any cap, times `Fluid.DRAIN`): a full stalk
  drained reads 77, 32, 5 at 0.5, 1.5, 3 s of hold.
- **The cap is the dye pass's**: it reads the meter's last frame
  (`meter` uniform, `full_ease`) for the chunk under the tip and eases the
  pour to nothing over the last 6% of `C_FULL`, a frame behind rather
  than a readback behind. `Fluid.rate_now` is the plain rate again (the
  CPU cut used `level()`, a 0.1 s cache of a GPU readback: right in every
  harness, but the one link that could fail on a desk). The sim's own
  tally still stops headless.

Read on Hard (`wander`, `opengl3_angle`): 22% at 0.5 s, 67 at 1.5, 98 at
2.5, 99 at 4, 100 from 7 s to 18 s and after the release, then the drain
as above. The probe and the suite as before.


### A chunk a piece, a segment a pot (2026-10-14, night)

The user, with an Insane cupcake on their phone whose cup was a lemon part
either side of a stripe laid over it, and the meter one ring for both
sides: "every part of the picture should have its own 0-100% even within
the same chunk, not share it. Also if there is orange on bucket for
example, it should show 100% filled of orange, not 50% of yellow and 50%
red, the split % is only shown if the slot is manual filled with both
colors."

- **Every piece a later chunk leaves of an earlier one is a cell of its
  own** (`Mould.build_parts`): the parts' pieces are the chunks as the
  night counts them (`laid`, and `source[c]` says which each cell came
  from), and each is clipped by every chunk over it; a chunk left in one
  piece keeps its whole polygon (what lies over it covers the rest, so a
  hole costs nothing to draw), one cut in two or more is as many cells,
  each its own tank, fence, meter texel and judge cell. A piece under
  `SLIVER` (24 units², about three of the sim's squares) is given to the
  first later chunk it touches rather than stood as a chunk too small to
  pour in (the 20261019 Insane fruit basket had one of 2 squares). Over
  the bank only the bee splits (4 to 6: the body either side of its two
  stripes); the night's striped mug splits on every band (4 to 6, 5 to 8),
  and the most any kept jelly comes to is 14 cells, under `CELLS_TOP` 16.
  `Mould.unfit` keeps the night's own count: its chunk rule and the
  9-squares rule go by `laid` and `source`, and the `CELLS_TOP` cap by
  the cells ("%d cells"). `jelly.ts` `why()` refuses the same, counting
  each chunk's pieces of the 100-grid once the later ones are laid over
  it (`CELLS_TOP`, `SLIVER` there), so a jelly the night keeps builds
  here; **that is on this Mac until the user deploys `publishDay`**, and
  until then a night could in principle keep a jelly of 17 cells, which
  the phone would drop for a bank picture (none of the made days comes
  past 14). The probe's squares check reads by `source` and prints the
  smallest cell cut; `day_dict`'s `cells` counts the cut cells now. A seam
  along a cut runs the same line twice (the piece's edge and the
  cutter's); nothing seen of it in the Medium shots.
- **The meter is a segment a pot** (`_meter_segments`, `_pot_shares`,
  `Art.meter(r, segments, total)`): `_cell_pots` already knew which pots
  had gone into a chunk (for the mix sound); the ring now shows one
  segment a pot in the order they went in, each the share of the reading
  that pot's pigment accounts for, least squares over the pots' pigment
  vectors (one pot: all of it; two: solved by hand; three: a `Basis`
  inverse, or a segment a pigment when they cannot be told apart, cherry,
  lemon and orange all in one chunk). So the orange pot poured reads one
  orange segment, and cherry then lemon by hand reads the two shares. A
  chunk drawn back under `Sim.WET` forgets its pots; a chunk no pot is
  known to have gone into (a tutorial's prefill) shows the one flavour its
  pigments make within 0.04, else a segment a pigment as before.
- **Measured** (`opengl3_angle`, 810x1440): the headless probe 0 failed;
  the suite 249,567 passed, 0 failed; `_win.gd -- gumdrop hoop` both PASS.
  `_shot_gumdrop.gd -- <out> 1` (Medium, the day's cupcake then the
  night's striped mug and a third): the mug's body on the tray as three
  bands with a seam each side of its stripes, the bot 100, 100, 100 in 4
  serves after the flop by hand, play 115 to 122 draw calls, the win 77
  to 82, the done day 75. Hard (`-- 2`): 71, 88, 93, 93 in 6 serves (the
  bot still pours a mix by strength, 0.4 to 0.5 near on the mixed chunk,
  as it has since 2026-10-11). **Seen**: a primary poured as one segment
  (the shot of the squeeze, lemon at 65%); a pot of a mixed flavour as one
  segment, a hand mix as two, and the three-pot fall-back are proved by
  `_pot_shares` headless (orange alone 0.8; cherry and lemon 0.3 and 0.5;
  orange then cherry 0.4 and 0.4; orange and lime 0.4 and 0.6; cherry,
  lemon, blueberry 0.2, 0.3, 0.4; cherry, lemon and orange empty; a
  -0.01 of noise clamped), not by a shot: the harness's flop pours lemon
  into a grape chunk and the meter fades at the serve. Unseen on a phone.

### A big chunk takes longer (2026-10-15)

The user: "on gumdrop, bigger spaces to fill should take longer than small
ones, if there is a small circle, it should not take same time to fill as
a big chunck". Since 2026-10-14 the rate grew with the chunk in
proportion past 23 squares, so every chunk but the tiniest took the same
hold.

- **The hold grows as the root of the chunk's squares** (`Sim.pace`,
  `Sim.SQUARES_REF` 92, `Fluid.RATE` 3.6 at 92 squares, `Fluid.rate_now`):
  the rate is `RATE * sqrt(squares / 92)`, so the mushroom's stalk (92
  squares, the pace the user called right) is unchanged, a chunk four
  times its size takes twice as long, a quarter of it half as long. The
  drain follows (`drain_rate` is `rate_now() * DRAIN`), so a big chunk
  drains slower too. The headless tally (`Sim.step`, `RATE` 0.5 at 92
  squares) uses the same `pace`, so the probe and the screen agree.
- **Chunk sizes** (60 seeds a band, every mould): 14 to 328 squares; the
  median 164 on Easy, 80 Medium, 68 Hard, 96 Insane; a tenth of them 24
  squares or fewer.
- **Measured** (`_shot_gumdrop.gd -- <out> 1 pour small|big`, new args
  that pour into the mould's smallest or biggest chunk; `opengl3_angle`,
  810x1440; the meter's shown number at each second of hold): 14 squares
  26, 53, 79, 100 at 0.5, 1, 1.5, 2.5 s; 242 squares 13, 23, 33, 49, 80,
  106 at 0.5, 1, 1.5, 2.5, 4, 7 s (on the commit before, 20, 36, 51, 80,
  100, 106). The probe 0 failed.
- **Not this change**: the biggest chunk reads 104 to 106% after a long
  hold, on the commit before as well (the cap is eased off the meter a
  frame behind; a 242-square chunk spreads slower than the meter's last
  frame). Open.
- **Calls that are the user's**: the root (a time per chunk between the
  same-for-all before and the proportional, 4.7 times as long on 306
  squares as on 14 by the rate, 2.5 by the measured hold since a tint
  spreads); the stalk as the anchor. Unseen by the user, no phone.

### The jelly is drawn, then read (2026-10-16)

The user: "images on gumdrop and yarn hoop are terrible, i want you to
deeply polish it to make a great image in any difficulty based on theme".
The night's jellies were a text model placing ellipses and boxes on a field
of 100: a spiral shell four rings, a barnacle rock a blue blob.

- **Each jelly is drawn as a sticker first** (`jelly.ts` `STICKER`,
  `drawJelly`, `readJelly`): the thing in only the six flavours' own
  colours, big rounded shapes touching, on the green screen
  (`facets.ts` `KEY_WORDS`; on white, the flash model's white spots and
  sticker border joined the board and bit holes in a mushroom's cap), Easy
  in exactly 2 colours and 2-4 shapes, Medium 3 and 3-6, Hard 3-4 and 4-8,
  Insane 4-6 and 6-12, the band's mixed flavours asked by name.
- **Read**: each pixel the nearest flavour; the drawing grown 5 pixels out
  over the board (`SWELL`, which joins a claw drawn a hair from the body
  and fattens a thin limb into something to pour in), seams and specks
  dissolved, chunks under `DRAWN_LEAST` (520 of the 256 reading, LEAST_SQUARES
  with room) joined to a neighbour, then the nearest until the band's most
  chunks, a joined chunk keeping the bigger one's flavour. Each region's
  outline is simplified to at most 16 points, grown 0.9 so the soft
  corners leave no clear seam, and laid as a `soft` shape, the biggest
  outline first (so what lies inside one is laid over it); a flavour's
  shapes are one part when the parts would pass 8. `why()` judges it as
  before; up to `DRAWINGS` stickers (3, 3, 2, 2 by band: Insane's step must end inside its half hour), then the old written way.
  No blind look on a drawn jelly.
- The phone is unchanged: `from_doc` and `build_parts` take the soft
  outlines as they took the written ones.
- Drawn on `DAILY_SHAPES_MODEL` (flash on Vertex), as Yarn Hoop's
  (`docs/agents/boards/hoop.md`, 2026-10-16). Made on this Mac for
  20261019; **the deployed `themeDay` writes the old way until the user
  deploys the functions**. Unconfirmed: the user's eye, the green screen,
  the swell, no blind look.

### The jelly is written by a model, under an eye (2026-10-21)

The user, 2026-10-21, with the day viewer open on 20261021: Gumdrop's
pictures "is even worse" (than Yarn Hoop's), beside a reference of glossy,
shaded gummy things; then "We can use the llm to make sure high quality
outcome ... a specific port for each game"; after the hoop's spike, "let's
try to do something similar for the other games and the gumdrop"; and
"amazing, apply it". Spec
`docs/superpowers/specs/2026-10-21-picture-ports-design.md` ("The jelly
written by a model"); the spike script is `spike_jelly_map.js` in
`docs/superpowers/specs/2026-10-21-picture-ports-spike/`. Built on
`feat/picture-ports`, not pushed, not deployed, **nothing run on Vertex
yet**. The other picture boards on the night's drawn path are the bead
boards, already model-written and model-reviewed, so Gumdrop is the second
port beside Yarn Hoop's (`docs/agents/boards/hoop.md`, 2026-10-21).

- **The rules are untouched**: `RULES` (flavours, mixed, chunks a band),
  `MOULDS`, `DRAWINGS` `[3, 3, 2, 2]`, the 16-point cap. The user's two
  open calls fell to the defaults at approval: Easy's counts do not rise
  (two flavours cannot be the reference's glossy snail, but the Medium
  snail at 3 parts read as a snail once the model wrote it) and the cap
  stays.
- **The model writes the jelly** (`jelly.ts` `mapJelly`, `role: "review"`,
  Opus): the sticker drawing (`STICKER(what, band, key)`, the key colour
  chosen a thing as the hoop's is, `key.ts`; "a sharp, true silhouette",
  white, cream or grey forbidden outright) with a 0-100 grid over it
  (`gridOver(d, JELLY_GRID_N 20, 5)`, labels 0..100) goes to the model,
  which answers parts (`{flavour, shapes: [{kind: "soft", n}]}`) under the
  band's rules **stated in full in the ask** (`mapRules(band)`, every
  number from the constants `why()` uses): flavours and mixed counts,
  chunks, at most `MOST_PARTS` 8 parts and `MOST_SHAPES` 8 shapes a part,
  `LEAST_POINTS` 6 to `MOST_POINTS` 16 points a polygon, inside `FIT`
  9-91 (the spec said 10-90), one connected piece, **`COVER` 20-75% of the field**, **every
  chunk at least `LEAST_SQUARES` 9 of the sim's 36-grid** (a frog's eye dot
  cannot be a chunk of its own), nothing thinner than `THINNEST` 6 units,
  at most `CELLS_TOP` cells once cut; the white border, outlines,
  highlights and shading of the drawing ignored, each region the flavour
  nearest its colour. Why so much: in the spike **every refusal was a rule
  the prompt had not stated** ("covers 18%" twice, "a chunk too small to
  pour in", "a soft's numbers"); the second try repeated "covers 18%"
  because the ask never named the floor.
- **The answer is type-checked** (`asParts`, never throws; anything else is
  `null`, the try's why "a shape's numbers"), then `why()` judges it as it
  always has, then the parts are rendered and the eye scores them. A
  refusal is folded into the next ask as the brief's sentence ("Your last
  answer was refused by the board's checker: ...") and the eye's complaint
  as "A reviewer scored your last answer N of 10[, took it for X], and
  said: ... Write it again, mending that." Up to `JELLY_ASKS` 3 asks a
  drawing.
- **The render the eye sees**: the parts as soft shapes in the six inks on
  the board's cream `#f3ead8`, 600 px, no outline, in the order the board
  lays them (`renderPolygons` of `polygon(s)`), as the card draws them.
- **First kept wins** (ruling, the controller's; the hoop keeps the best
  of its tries): a try is kept when the eye named the thing, found nothing
  wrong and scored at least `FLOOR.jelly` 7, and **the first kept try ends
  that thing's asks, its drawings and its written fallback**. A Hard band of
  four things at up to 6 maps + 6 eyes a thing would blow the budget and send
  the later things to the bank. Cost if wrong: a 7 ships where a later try
  might have been an 8. (Checked with the model stubbed: 4 map asks and 2
  eye calls where the first draft made 9 and 7.)
- **The clock** (ruling, the controller's, superseding the pre-flight idea
  of 5 minutes a thing): `JELLY_BUDGET_MS` 12 minutes from the start of the
  band's loop, or the run's own limit if that comes first (`until`,
  themeday.ts: 6 minutes before the 30-minute lease ends, 2026-10-21 review
  fix); past it no draw, ask, reader or written try begins, and the judge of
  one already asked still runs. A thing
  not reached is recorded as one try with `why: "out of time"` and the board
  fills its place from the bank. The worst case, Insane (5 things x 2
  drawings x 3 asks and the reviews), would pass the 30-minute lease
  unbounded; the spec's anti-goal (a night that runs out of its step) binds
  over the ask count. Cost if wrong: Insane bands lose things on a slow
  night.
- **The fallbacks**: when no drawn try was kept, `readJelly` (the pixel
  reader, 2026-10-16 above) on the last drawing as a `reader` try through
  `why()` and the eye; and when that is not kept, **the written way**
  (`writeJelly`: Opus writes the parts, `TRIES` 2, `DAILY_ROWS_MODEL`, now
  through `asParts`, `why()` and the eye with no source). The written
  fallback no longer takes the bead look (`lookThing` is gone from this
  route and `JellyTry.look` with it, which nothing read; the eye names the
  thing too, and a second gate on top would be one gate too many).
  `makeJellies` returns `{jellies, tries, ports}`, a `Port` a thing.
- **What the spike measured** (2026-10-21, 16:13, run 2's sticker drawings,
  a 0-100 grid, Opus, one refusal folded into one retry; 7-20 s and
  US$0.02-0.04 a try):

  | Card | Model's jelly | Checker | Reader's parts |
  |---|---|---|---|
  | rain boot, Easy | 2 parts, score 6 | refused twice, "covers 18%" | score 5 |
  | snail, Medium | 3 parts, score 7 | passed | score 6 |
  | frog, Hard | 4 parts, score 7 | refused, "a soft's numbers" then "a chunk too small to pour in" | score 4 (refused) |
  | kettle, Insane | 5 parts, score 6 | the same two refusals | score 4 (refused) |

  The silhouettes were whole, clean and true to the sticker, the eyes and
  cheeks placed as drawn; the reader's parts of the same drawings were
  lumpy blobs with the head or sole lost. Scored against the cruder
  render, so the numbers are low by some.
- **Checked offline** (Task 6; `check_jelly.js` and two stubbed flows, no
  model): the snail and frog spike maps through `why()` (`""` and "a chunk
  too small to pour in"), `asParts` on a dozen bad shapes, the clock
  pushed past the budget (every port exactly one "out of time" try, no
  calls), a flow where try 0 is a null number, try 1 "1 flavours", try 2
  scored 6 (not kept) and try 3 scored 8 (kept).
- **Unconfirmed**: nothing has run on Vertex. The user's check is
  `build/port_jelly.js` (git-ignored; Rainy Day, band 2, its five things,
  drawings to `build/port_jelly/`; command in
  `.superpowers/sdd/2026-10-21-picture-ports/task-6-report.md`), expecting 3
  of 4 things kept at 7 or more or a logged fallback. The phone's
  jellies, and how often a thing comes from the bank. `jelly.ts` is 902
  lines, and its port section (about 290) is a clean seam for a
  `jelly_port.ts`. **The deployed `themeDay` writes jellies the old way
  until the functions are deployed** (the deploy list,
  `docs/agents/turns-and-backend.md`).

### The gummy finish on the card's picture (2026-10-21)

The user, 2026-10-21, of the day viewer's gummy jelly: "i loved the gumdrop
with the gummy finish look, would love if we could add the same view to the
ingame". The viewer's finish is an SVG filter (`GumDefs` in
`tools/day_viewer/src/App.jsx`, the spike's `GUM`: a specular highlight
from a point light at (20, -10), a dark inner rim, a soft shadow); the
game's is `gumdrop_art.gd` `picture()`.

- **Where it is**: `Art.picture()` only, the jelly **on the level card**
  (the picture the player matches). Laid in one `ArrayMesh`, as before,
  back to front: a soft shadow (the outline moved `(1.5, 2.5)u`,
  `Color(0.35, 0.23, 0.16, 0.25)`, replacing the old ink rim shadow; the
  white rim is `Mould.RIM` 1.6 so the shadow shows past it on the lower
  right), the white rim and the cells, **a dark rim** (two bands inside the
  outline, d = 1.2u at alpha 0.18 and d = 2.4u at 0.1, in
  `(0.23, 0.1, 0.19)`; each is the outline minus its inner offset
  `Geometry2D.offset_polygon(-d)`, drawn as a closed stroke of width d on
  the centreline at -d/2), **the sheen** (a stroke of width 1.4u, white at
  0.28, moved `(+0.9, +1.2)u`, each quad mitred per vertex and clipped to
  the outline with `Geometry2D.intersect_polygons`, the builder's feather
  set to 0 for those pieces so shared edges leave no ticks) and **the
  glint** (`gloss_of`'s nine-point search for the spot, its glint ellipse at
  0.35 and its small hot spot at 0.55; the broad 0.12 ellipse left out,
  the stroke is the sheen now). `floor_of` and `gloss_of` are untouched.
- **The brief's sheen sign was wrong, and the build's stands** (ruling, the
  controller's): the brief moved the stroke `(-0.9, -1.2)u`; a clipped
  stroke 1.4u wide sitting 1.5u outside the body along the upper left
  keeps nothing there, only a band inside the lower-right edge, the
  opposite of "along the upper left". `floor_of` can move up and left
  because the gel covers its stroke, and here the stroke is clipped to the
  inside. The flipped sign agrees with the shadow's light direction and the
  spike's light. The glint alphas (0.35 and 0.55) are the implementer's.
- **The menu card gets it too** (ruling, the controller's): `ui/menu/
  card_art.gd` calls the same `picture()`, so the card on the Puzzles
  grid wears the finish; one picture, one look, accepted and **unviewed**.
  Cost if wrong: the menu card's jelly looks different from what the user
  approved there.
- **Where it is not: the tint, the gel, the pour.** The user turned
  lighting on the syrup down twice: 2026-10-11 (lighting the dye from its
  slope "made every fold a crease of foil", above; the user: the jelly
  "should not have borders, it should be a real jelly") and 2026-10-14
  ("right now borders make it look weird ..."; the notes' rule: "no light
  outline anywhere", the grey strokes and light seam lines were the
  "borders"), and the mould's gel is glossy already (`floor_of`, `gloss_of`, the dark glossy gel of
  2026-10-14). The finish is on the picture to match, not on the colour
  you pour. It is still, so `Motion.reduce` has nothing new to honour.
- **Measured** (`opengl3_angle`, 810x1440, band 1, run twice, the second
  reading): ready 119, squeeze 120, flop 119, again 115, served 122, mid
  118, win 82/77/75, redo 121, **identical with and without the finish**
  (the commit stashed): it adds no draw. The 115-122 of play is the
  2026-10-14 night's figure; the older 100-112 figures above predate it
  and this branch. Well under the 855 budget. `godot --headless
  --check-only` on `gumdrop_art.gd` is clean. Seen as a windowed shot and
  its 4x crop: the dark inner rim, the sheen along the upper-left edges, the
  glint on a boot's cuff and the shadow to the lower right; the tray, gel
  and mould as before.
- **Unconfirmed**: the card's picture is about 90 px, so the finish is
  subtle at phone scale and **not seen on a phone**. Known small
  faults left: sheen quads have no mitre compensation at sharp corners;
  parts thinner than 2.4u lose the outer rim band; a feather-0 piece still
  appends a feather ring. Ships with the APK through the push to `main`
  (the only phone-side file of the picture ports).
