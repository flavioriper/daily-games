# Pixel Garden

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Pixel Garden is the twenty-seventh card** (2026-09-27,
  `puzzles/pixel_garden2d.gd`, `puzzles/pixel_garden_state.gd`, spec
  `2026-09-27-pixel-garden-flat-design.md`, no concept tab -- built while the
  user was away, from their mock). Copy a little picture onto a pegboard
  bead for bead: pick a chip, tap a peg or drag a run, tap a bead of the
  chosen colour to lift it; hold the picture to see it big. The pictures are
  **hand-drawn and banked** (`content/pixel_garden.json`, ten a band, 10 to
  16 pegs square -- 24 and 32 on Hard and Insane since 2026-10-11, see "Big
  pictures" -- in the nineteen `Pal.PG_BEADS`), never generated, and each
  one's name is a `PG_PIC_*` key. Two things travel: **the kit holds exactly
  the beads the picture needs**, so a misplaced bead is felt as a colour
  running out before its shape is done -- a nudge the player finds -- where
  a counter of correct beads would give the picture away a peg at a time
  (the bar counts beads seated, right or wrong); and **Check rings, never
  tints**, a bead being coloured by index. The chips live in the card beside
  the picture (Quilt's shape): `"tray": "none"`, the actions row is Reset
  and Check. The solve is ironed: a warm band crosses the diagonal, each
  bead's hole closes and the bare pegs fade. Drawing is `ui/faces/bead.gd`,
  shared with the menu card; still beads in bands of four rows. `PG_BANK`
  (debug builds) points a harness at another bank.
  77-78 draw calls with a stroke seated on every band, 101-103 at the iron's
  peak, idle 3.2-3.6 ms; ANGLE agrees on 78 (frames within 1/255) and the
  reduce-motion pair is pixel-identical. 13 sounds generated (2026-09-27),
  one take a cue, awaiting the user's listen.
- **Polish (2026-10-01, unattended, spec
  `2026-10-01-pixel-garden-polish-design.md`).** The board is four plates
  with a seam and clips; a plate full is ironed at once by an iron with a
  face (`ui/faces/iron.gd`): right fuses it for good (`locked` FUSED, a
  hint's is HINTED), wrong sends the beads astray home -- a heart on Hard
  (3) and Insane (2), which have no Check. Only the plate under the iron
  waits; the rest of the board stays live. Insane was **Windblown**: the
  pattern card's squares shuffled and turned (`perm`, `turn`,
  `card_peg`), each framed in its plate's colour with its clip (pips 1-4)
  on the plate's top edge. **Windblown was removed on 2026-10-11** ("Big
  pictures" below): none of those names exist now, and the card always shows
  the true picture. The chips are a clear compartment box with
  heaps of beads and steel tweezers. Rewards: plate words and streak,
  love hearts or a butterfly, Steady hand!/Whoosh!, the party (nap cat on
  the pattern card, seal). BEADBOX sound set, 26 cues, unheard. Use `_won`,
  never `_solved_at < 0` (a restored day's clock can be negative). Peak 124
  draw calls; `tests/_shot_pixel_garden.gd`, `tests/_probe_pixel_garden.gd`.
  Amended the same day (spec section 11): hairline seams, every bead left
  drawn in its compartment, and a seated bead flies there from the box.
  Then (section 12): a stroke locks to its row or column after 0.7 of a
  cell, and a peg holding another colour refuses a bead (`taken`).
- **Checkup (2026-10-03, `docs/agents/checkup.md` row 27).** Beads, bare
  pegs and the box's beads are copies of `Kit` looks
  (`puzzles/pixel_garden_looks.gd`): one topology a kit, so a layer is
  native copies and tiled indices. `Looks.bead_kit` must stay in step with
  `Bead.bead` by hand (the menu card still draws through `Bead.bead`); a look
  that breaks the topology trips the kit's assert. The board's beads are in
  bands of four rows at rest (`_update_bands`, keyed on colour and fused) and
  one live mesh of the moving ones (`_live_beads`), with Check's halos and a
  hint's dots in `_marks` over both. The head is five meshes (`_head_under`,
  `_head_pick`, `_heaps`, `_head_over`, `_head_lid`). The tutorial is
  `ui/hud/pixel_garden_tutorial_diagram.gd` (lessons SEAT, KIT, PLATE, PEEK,
  WIND, CHECK, UNDO, HINT) on a hand-made 6x6 tulip, five beads a plate; its
  Windblown card was `PERM` [3, 2, 1, 0], `TURN` [1, 2, 3, 1] (WIND, `PERM`
  and `TURN` went with Windblown on 2026-10-11; ZOOM stands in WIND's
  place). Probe flags
  `x=pg_count`, `x=pg_relay`, `x=pg_hud`.
- **The iron waits for a full board (2026-10-04, the user's call).** A plate
  filled on its own is no longer ironed: four irons a picture read as the
  finish playing on every plate. `State.plates_due()` (it replaced
  `plates_full()`) is empty until the plates not yet ironed hold as many
  beads as the picture puts on them; then `_maybe_iron` irons every plate
  that is right (fused, with its word and streak) or holds a bead astray
  (home it goes), one after another, and leaves alone a plate that is only
  short. One pass costs one heart at most on Insane (`_plate_done`'s
  `costs`), however many plates are wrong, or two wrong plates would end a
  two-heart board at once. A board finished right still skips the plate
  irons for the win's own. `PG_RULES_PLATES` and the two `HTP_PG_PLATE_BODY`
  strings say so in the three languages; the tutorial's PLATE diagram still
  draws one plate ironed alone and `HTP_PG_LAST_CAP` still says "one bead
  short of a full plate" -- both are owed a redraw. `_probe_pixel_garden.gd`
  was already stale (five Hard-hearts checks, since hearts went to Insane
  only); its "plate 0 ironed by the moved bead" and "not flawless" checks
  now fail too, by design.
- **Insane counts moves (2026-10-04, `docs/agents/flat-screens.md`).**
  `HEARTS_BY` is all zero. Windblown handed out `target + 3` moves
  (`State.moves_budget`; 105 to 171 over the ten banked pictures; since
  2026-10-11 Insane's slack is a twentieth of the picture, never under
  three): a bead
  seated or lifted is one (`move_cost`), a refused put (fixed, taken, colour
  used up) is free, and a run stops where the budget does (`_paint` spends
  bead by bead; the last move gone unsolved ends the stroke in hand). **No
  plate is ironed on Windblown** (`_maybe_iron` returns when `max_moves >
  0`): a verdict on a plate was the answer, and the beads it sent home were
  moves made for the player. A full board that is not the picture just sits
  there, its bar gold; the iron comes only for the win. No Undo, Hint or
  Check; Reset and Try again hand the budget back. The kit running out
  (`PG_NONE_LEFT`) stays: it is the rule, and Medium shows it. The pill is
  drawn in `_draw_head_text` at the right end of the name's line, where the
  hearts sat (not in the lid's mesh: one more draw call). The tutorial
  drops PLATE and UNDO on Insane and ends on the moves page; the rules drop
  `PG_RULES_PLATES`, and "Check rings..." left `PG_RULES` for its own key,
  `PG_RULES_CHECK`, read only on a band with Check. `PG_LVL_2` still reads
  "three hearts" (Hard's, stale since ce192ab; rewritten 2026-10-11). Not
  seen rendered.
- **The bank is 120 pictures, thirty a band (2026-10-09).** Ten a band came
  back within days: the pick was `rng.randi() % 10`, so a picture could
  return the next morning. Eighty more were drawn (twenty a band, on the
  END of each band's list -- append, never reorder), and the day now walks
  one fixed shuffle of its band (`State.day_pick`, InsaneBank's rule, seeded
  by `fnv1a("pixelgarden|<band>")` and `InsaneBank.day_ordinal()`), so a
  band goes thirty days before a picture returns; New is the next in that
  order (`bank_step`), no longer a random one. The board's `rng` no longer
  chooses the picture. `tools/check_pixel_garden.py` is the validator the
  first spec described and never shipped (size, colours by band, 30-70%
  filled, never all four edges, no id or name twice); `--sheet out.png
  [--band N] [--skip 10]` draws the pictures as beads for a cull. Windblown's
  budget now runs 90 (the heron) to 171 (true of the 16 square Insane
  pictures, which the big ones replaced on 2026-10-11). The new pictures were judged on the
  contact sheet only, by their author; the weakest are the woodpecker, the
  garden gate, the wheelbarrow, the hummingbird and the mallard, and the
  swan, the badger and the snowman carry white in bulk. The pt and es names
  are unread by a speaker. One windowed shot (Insane, the snowman, six
  chips): 81 draw calls at rest. A day finished before this landed reopens
  on the new pick's picture, fused (the record keeps no `pic_id`).
- **Big pictures (2026-10-11).** The user: "on Button box and pixel garden,
  the hard and insane should have really big and complex images (instead of
  having a bugged board for example like today on pixel garden). Something
  that the user have even to zoom in to see", and then, of the plan (Hard 24
  square, Insane 32, filled scenes, Windblown out, counted moves kept, zoom
  and pan in), "all good, just build it". What read as bugged was
  Windblown's shuffled, turned pattern card.
  - **Windblown is gone, all of it**: `blow`, `perm`, `turn`, `card_peg`,
    `windblown()`, `WINDBLOWN`, `THUMB_GAP_WIND`, `PLATE_TINTS`, the framed
    and pipped squares, the tutorial's WIND lesson, and `PG_RULES_WIND`,
    `PG_WIND_TIP`, `PG_WIND_SEAL`, `HTP_PG_WIND*`, `HTP_PG_BLOWN_CAP`,
    `HTP_PG_CLIP_CAP`, `HTP_PG_TOP_CAP` in the three languages. A plate's
    clip is plain wood on every band (and sits just inside the plate's top
    edge now, where the field is clipped). Insane's seal reads "Insane" over
    Flawless or the board's motto (`PG_MOTTO`), its share line is the medal
    and "Insane". No save ever held `perm` or `turn` (`completion_record` is
    hearts, flawless, moves), so a day finished under the old rules reopens
    as any other; the probe reopens one with those two keys in its record.
  - **Insane's slack scales**: `State.moves_budget()` is `target + max(3,
    target / 20)` (`MOVES_SLACK`, `MOVES_SLACK_PART`): 998 beads get 1,047
    moves. The card's video buys `max(5, max_moves / 40)` (`_moves_bonus`;
    26 there) -- five moves were nothing on a thousand beads, and that one
    is this pass's own call, not the user's.
  - **Sizes.** `State` takes any square picture; nothing in it knew 16.
    `PG_LVL_2` and `PG_LVL_3` say 24 and 32. Past seven colours
    (`ROW_MOST`) the box is **two rows** of compartments in a taller head
    (`HEAD_BIG` 300 against 212; the pattern card grows to 300 with it):
    the big boards are bound by the card's width, so the head's 88 px cost
    the pegs nothing at 1000 by 1350 (the card is 1,326 tall; a shorter
    screen gives them up). Twelve colours are 98.7 by 102 each, ten are 118
    by 102, the count under each at 22 (`COUNT_SMALL`). **A heap is capped
    at what a compartment holds** at the smallest bead (`_heap_most`, 145
    to 175 here) and drawn to scale past it (`_heap_shown`): a sky of 320
    beads would have run up through the label and the name. The bar leaves the tally
    the room its widest reading needs (`_tally_room`). The pattern card of
    a board past 16 (`BIG`) is plain squares (4.7k vertices; `Bead.pixel`'s
    round ones were 82k), whole on the card and a hair apart when held up
    (`_peek_mesh`), and **held up it is as wide as the card** (`PEEK_EDGE`):
    29 px a square at 32.
  - **Zoom and pan, Hard and Insane only** (`ui/flat/pan_zoom.gd`,
    `_zoomable()`). A peg is 36.5 px on Hard and 27.6 on Insane; the button
    goes to 56 (`PEG_NEAR`; k 1.53 and 2.03) and fingers to 84 (`PEG_MOST`).
    The zoom is one transform, never a new `_cell`: `_ground` (the table
    and the tray) and `_field` (plates, pegs, bands, the live beads, the
    marks; `clip_contents`, at the tray's floor) are two children drawn
    **behind** this Control (`show_behind_parent`), and the head, the beads
    in the air, the words, the held picture, the toast and the seal stay in
    `_draw`, over them, unscaled. Not a negative `z_index`: that goes under
    the host's card. What flies about the board (`_live`: irons, love, the
    butterfly, a hint's ring) is drawn over the rim by `_draw` while the
    board is whole, as it always was, and clipped in the field when close;
    `_mask` puts the tray's round corners back over the field's square
    clip. `_prepare` builds what the three drawings share, whichever draws
    first, and `_stale` (set by `_refresh`) keeps a pan, a toast or a chip
    from looking the bands over.
  - **Input.** `_gui_input` hands every event to `zoom.feed` first. One
    finger paints as before; every peg is found through `zoom.to_layout`
    and only on the tray's floor, the 0.7 cell before a run takes its row is
    measured as laid out (so it is 0.7 of a peg as shown), and a finger
    past the floor's edge paints nothing out of sight. **A second finger
    cancels the stroke in hand** (`_pinch_began`, `_cancel_stroke`,
    `State.cancel_stroke`): its beads are put back, last first, its moves
    are handed back, and if it had spent the last move the board is not
    over (`_stroke_ended` keeps that stroke open until its finger lifts or
    the card comes). A held picture is set down. `cell_to_local` is where a
    peg shows, so a harness taps what a player would.
  - **The button** (`_zoom_b`, an `IconButton`, 84 px, 12 in from the
    floor's lower left; the thumb side stays clear): plus when whole, minus
    when close, whoever zoomed; to the peg last touched, or the middle.
    Hidden on Easy and Medium, during the entrance, while the picture is
    held, out of moves and once won. The pegs under it are reached by
    pushing the board up: `zoom.slack_hi` lets a close board rise the
    button's height clear of it (the floor shows under it). The toast sits
    above the button on those bands. The win, Reset and Try again glide
    back to the whole board, a new day and a restore start there, a hint or
    Check's first ring out of sight is brought into it (`_show_peg`).
  - **Timings at a thousand beads.** The win's iron crosses in 1.44 s at
    most (`IRON_SPAN`, a 16 board's own) and a plate's in 0.8 (`PLATE_SPAN`):
    a step a diagonal was 2.9 s and four plates 7.5. A board past 16 wins
    another way (`_win_front`): no hop, a bead live only while the iron is
    on it (`IRON_TIME_BIG`), and the still beads cut along the iron's
    diagonals (`_cut_bands`, `BAND_DIAG`, 16 bands), so a frame makes again
    the band the iron enters and the one it leaves. Half way 182 beads are
    live where all 998 were; all of them live was 9 ms of script a frame on
    this Mac.
  - **`ui/flat/pan_zoom.gd` was changed twice** (shared with Button Box):
    `slack_lo`/`slack_hi`, zero by default; and **two fingers are followed
    as a pair** (`_held`, `_stirred`). An event a finger, a pan was a pinch
    in and a pinch out by turns, and against the view's edge the clamp bit
    between the two: the board crept back the way it was pushed from (the
    probe's pan to the corner ended in the opposite corner).
  - **Tutorial**: a ZOOM page on Hard and Insane (`HTP_PG_ZOOM*`): two
    fingers spread on the tulip, dragged, a bead seated on the zoomed board,
    the button back. The PLATE page and `HTP_PG_LAST_CAP` are still owed
    their redraw.
  - **Measured.** `tests/_probe_pixel_garden.gd` is rewritten to these rules
    (headless, touches by finger): 103 checks, 0 failed, on a temp bank
    through `PG_BANK` and on the bank as it stood. The suite 249,804
    passed. `tests/_shot_pixel_garden.gd -- d=3 tour` (touches; `wind` is
    now `peek`) on opengl3_angle at 810x1440, a synthetic 32 square scene of
    12 colours: **90 draw calls whole and 90 close** with a third of the
    board seated and a run in the air (the second of two readings each),
    **115 at the peak** across the win and its card. Hard (`d=2`, 24
    square, 10 colours, its fuller HUD): 112 whole, 112 close, 134 at the
    peak. The tour also plays the tutorial's ZOOM page on a sheet over the
    screen (the diagram alone, not the real card): the pinch, the push, the
    bead and the button were seen there. The menu card is a fixed toadstool
    and the win screen draws no picture (`flat_win` has no faces), so
    neither needed a change; the share is a block of pegs a square past 16
    (`SHARE_SIDE`: 12 rows for 24, 16 for 32). A bead is 435 vertices
    at a 27.6 px cell, so a full Insane board is 434k vertices at rest in
    eight bands (a 16 board was 111k), drawn every frame.
  - **Owed.** The locale reimport (the level lines and the new keys showed
    raw or stale in every shot). A phone: the pinch, whether 56 px is close enough, and the
    frame time of 434k vertices (frames ran 10-13 ms on this Mac, where
    draw calls usually set them). The pt and es lines unread by a speaker.
    A run does not pan the board as it nears the floor's edge. Zoomed, a
    bead's 1.5 px feather is 3 to 4.5 px: soft, not wrong; a kit made at
    the close size would be crisp there and a third heavier.
- **The zoom's button goes a step at a time (2026-10-11)**: whole, half
  way, close, and back out (`PanZoom.cycle`; `docs/agents/boards/buttons.md`,
  "the zoom has a step"). The probe and the tutorial press twice for close.
- **Cut-outs among the big pictures (2026-10-11)**: Hard and Insane are 18
  pictures each, 12 scenes and 6 subjects on a bare board (asked of Button
  Box; `docs/agents/boards/buttons.md`, "Cut-outs among the big pictures").
  This board got them by sharing the bank, not by the user's word.

## Insane counts no moves (2026-10-12)

- The user: "let's remove the limited moves on insane for drawing games
  like button box" (and, asked, both this board and Button Box).
  `State.moves_budget()` is 0 on every band, so on Insane `max_moves` is 0:
  **its plates are ironed as any band's are** (the iron was withheld only
  because a verdict would have been moves made for the player), Undo is
  back (`capabilities` `["undo"]`), and it still has no hint and no Check.
  The rules sheet and the tutorial follow `max_moves` and so show the
  plates and no moves page. `PG_LVL_3` reworded in en, pt and es. The
  counter, `move_cost`, the out-of-moves card and its video are still in
  the scripts for a budget over 0, and unreached; `tests/_probe_pixel_garden.gd`
  hands its second-finger section a budget so that path stays checked
  (PASS, 0 failed).
- Hard here is still 24 square: Button Box alone went to 16
  (`docs/agents/boards/buttons.md`).
- **Not seen on a screen.** Mine: the iron back on Insane's plates, and
  Undo back; the user asked only for the limit to go.

### The craft mat is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/pixel_garden_world.gd` is the card's aqua
craft mat under a cream window light, with a faint cutting grid, five
loose beads in the gap of the tools row, and at the foot a printed ruler,
a glass jar of beads on its side with a spill, steel tweezers and a sheet
of ironing paper with a small fused flower; six glints breathe. The
garden table is gone. The board tells the world its tray's foot
(`set_foot(y)`): Hard and Insane, with the two-row bead box, leave 84
and show the ruler only.

- Registry: `bleed`, `level_card`, no actions row. **Check is gone**:
  the board solves itself and Check only haloed wrong beads.
- `opengl3_angle`, 810x1440: 92 draw calls at rest; `tests/_win.gd --
  pixelgarden` passes.
- Decided for the user, unconfirmed: no Check; a mat, not the table. Owed:
  a phone, the pinch zoom on Hard and Insane.

- **A daily may deal a themed picture (2026-10-13)**: when this phone holds
  the day's `pictures` document, Pixel Garden's daily takes its band's size from
  it in place of the bank's (`core/themed_pictures.gd`,
  `docs/agents/days-dashboard.md`, "The daily theme, stage 2"). New, the
  suite and every harness are the bank's as before.

  **Since 2026-10-14 the picture is any side within the band's range**
  (`ThemedPictures.RULES.side`: 10 to 18 at Easy, up to 40 at Insane), a
  shaded sprite kept at the squares it was drawn at; this board lays the
  side it is handed.
### Made fun (2026-10-29)

The user: "make pixel garden and glimpse experience way better to play, and
game itself way funnier to play, right now nobody likes it", autonomous,
push when done. Spec `docs/superpowers/specs/2026-10-29-pixel-garden-glimpse-fun-design.md`.
References from the web: colour-by-number apps (Pixel Painter, Pixel
Coloring, Pixel Art Numbers listings) earn their pleasure from a palette
that shows what is left of each colour, a pop on every cell, quick feedback
on each cell and a payoff at the end, and above all from **the cell telling
you what it wants**.

**Measured first** (`tests/_probe_pg_fun.gd`, the bank, the first bead
seated the wrong colour, the rest right in reading order): the beads
seated after a slip before the board says anything. Until the kit runs dry
(`PG_NONE_LEFT`): median 30 / 48 / 478 / 913 by band. Until the iron:
47 / 65 / 575 / 1023. A leaf at the end of each finished row speaks at
2 / 1 / 23 / 31. So the board kept the genre's counts, pops, zoom and payoff
but hid where the player was and said nothing of a slip for hundreds of
beads.

**What changed** (`pixel_garden2d.gd`, "the made-fun pass" block):

- **A leaf on a finished row** (`_check_rows`, `_draw_leaves`, in `_marks`):
  a row that is just as the picture has it, with at least one bead
  (`State.row_right`), sprouts a leaf past its last peg with a climbing
  `combo` note (-7 dB) and a green sparkle. A row that goes wrong loses its
  leaf. A deal or a restore is quiet (`_rows_quiet`). It confirms whole
  rows only, never a bead. A won board wears none. `_check_rows` runs in
  `_refresh` (every frame an animation runs, an n-squared scan that stops
  early at a row's first wrong peg); the tour's frame times stayed at
  10-17 ms.
- **The pattern card reads where you are** (`_draw_card_reading`): the
  square under the finger is ringed while a stroke is in hand, and every
  square whose peg holds a bead is faded (right or wrong, the bar's own
  rule, so it gives nothing away). Two small meshes over the card.
- **Guides** (`_draw_guides`, in `_plates`): a hairline every `GUIDE` (4)
  pegs out from the seam, both ways, on boards whose plates are wider than
  4. Not on the card (its squares are 5-8 px).
- **Easy traces the shape**: darker wells under the pegs the picture
  covers, never a colour (`_traces()`).
- **The bulb reads before it fixes** (`hint()`, `_fix()`, `_reading`), the
  house's two-press bulb: the first press rims every bead astray in rose
  and counts them (`PG_READ_ASTRAY_ONE/N`), or, with none astray, rings
  the bare peg nearest the last touch in sun and puts its colour in the
  tweezers (`PG_READ_NEXT`). That costs one hint. A second press fixes the
  read peg for free (`State.hint(at)`). A stroke puts the reading out.
  `hints_left` counts a reading that is standing. `HTP_PG_HINT_BODY_ONE/N`
  is rewritten; the tutorial's HINT diagram still plays one press.
- **Live stars** (`star_line.gd`, at the right end of the name's line):
  slips are beads the iron sent home (`sent_home`) plus bulbs read; 0 keeps
  three stars, up to 3 keeps two (`STARS_CUT`). `completion_record` keeps
  `slips` and `stars`, and a restore sets the stars quietly. Undo and Reset
  put out a standing reading.
- Owed, found on the way: the pattern card on an odd side (a themed
  17-square picture) draws `half` x `half` squares a plate, so it leaves
  out the last row and column. That was true before this pass.
- `PG_RULES_LEAF` added to the rules.
- Kept as the user had them: the iron waits for a full board, no moves, no
  Check, the deals.
- Hooks for Glimpse: `_reads_card()` (card ring, fading, guides, trace),
  `_slips()`, `_star_cut()`, `_climb()`, `_more_marks()`.
- Harnesses: `_win.gd -- pixelgarden` presses the bulb twice (a reading,
  then the fix); `_shot_pixel_garden.gd` has `id=glimpse` and the `fun` and
  `gl` modes. `_probe_pixel_garden.gd` presses four times for its two hints
  and expects Insane's `["undo", "hint"]`. That check was already failing
  before this pass. The probe now gives 0 failed.
- opengl3_angle 810x1440 (second readings): Medium 99 at peak in play;
  Insane tour 101-105 whole and close, 125 at the win, 170 with the
  tutorial sheet. `_win.gd pixelgarden` PASS; suite 303252/0. No new
  sounds. Unseen on a phone; pt/es unread by a speaker.
