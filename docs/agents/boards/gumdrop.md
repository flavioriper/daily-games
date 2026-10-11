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
- **Insane counts serves** (`docs/agents/flat-screens.md`, "Insane counts
  moves"): the budget is the moulds and `Sim.SLACK` (1) more, a serve costs
  one whatever it scores, and a flop that leaves fewer serves than moulds
  is the day lost (`over`): `out_of_hearts`, the shared out-of-moves card,
  whose video buys `MOVES_BONUS` (2) serves once. Reset and Try again are
  the day from its first mould with the serves back (`Sim.restart`); an
  emptied mould there would be a flop taken back for nothing. **The
  counted move is named on screen**, because the day is lost with fewer
  serves than moulds and not at none, and the shared words ("Out of moves",
  "when they are gone the board is lost") said otherwise beside a pill
  still reading 4: the shared `MovesPill` beside the squeeze button reads
  "N serves left" (`MovesPill.keys`, new, `Table.SERVES`), the card is "Not
  enough serves" with its own body and button (`GD_OUT_*`), and the
  tutorial's last page is the shared diagram under "Count your serves" and
  `GD_RULES_SERVES`. **The user picked "under the mark loses the day"; the
  one spare serve was put to them in the design and stood.**
- **No Undo, bulb or Check on any band** (`capabilities()` is empty): syrup
  cannot be taken out and the match is a `?` beside the card until Serve.
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
- **A mould is polygons made by rule** (`puzzles/gumdrop_mould.gd`): an
  outline cut into sectors, a core and sectors, or bands. The sim's grid
  and the art's meshes are both made from them. A wall is 5 units for a
  reason: the syrup is drawn from squares 2.8 units wide, and a thinner
  wall let the next cell's colour show at a cell's edge.
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
- Owed: a phone (the fluid's 22 small passes a frame are untimed there,
  and the judge's readback at serve), the user's verdict on the pour, the
  sounds heard, pt and es read (neither was shot), the win and the play
  under `reduce` (only the Insane loss was run so), the card's video path
  (no video is ready on this Mac, so `heart_back` ran in the probe's sim
  only). **Calls that are the user's**: the marks (60/65/70/75) and the
  counts (2/3/4/5), nobody but the bot has played Hard or Insane; Three
  Pots as Insane's rule; the one spare serve; Reset on Easy to Hard keeping
  the day's serves counted; the win's three gumdrops.
