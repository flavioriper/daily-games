# Millstream -- a small factory on the Arcade tab

2026-09-27. The fifth Arcade game: a much smaller Satisfactory/Factorio for a
phone, seen from above, played by touch like a city builder (no avatar, no
walking, no combat). Research behind it:
`reports/Satisfactory game spec and data.md` (untracked).

**It is called Millstream and nothing else.** The reference game is named
here once, to forbid it; nothing in code, on screen or in a commit borrows
its name, its art or its words. Its recipe ratios are mechanics and are used
as they are.

## The whole game (agreed design)

- **A painted valley** of grass tiles with a stream down one side and the
  **Mill** (3x3, the reference's HUB) on its bank. Deposits of iron, copper
  and stone, each poor, normal or rich (0.5x, 1x, 2x a drill's base rate).
  Hand-made map.
- **Buildings**: Mill, Drill (2x2 on a deposit), Kiln (2x2, ore to ingot),
  Workbench (2x2, one in one out, recipe picked), Belt, Splitter, Merger,
  Crate.
- **Recipes** (per minute, the reference's ratios): iron/copper ingot 30 ore
  to 30; plate 30 ingot to 20; rod 15 to 15; screw 10 rod to 40; wire 15
  copper ingot to 30; cable 60 wire to 30; concrete 45 stone to 15.
- **Loop**: parts reaching the Mill go into its stock; the stock pays for
  buildings and is handed in for **milestones** (about seven, each
  unlocking the next building or resource), ending in a final order. The
  record is the quickest finish (`Record.add_time`).
- **Belts drawn cell by cell** (approach A): drag from an output through
  cells, snapping to 90-degree turns; one speed, one splitter and one merger
  in the first layer, no undergrounds. Items ride visibly, four slots a
  cell.
- **Touch**: one finger pans, pinch zooms, a tap acts; a building chosen in
  the panel under the map is placed by a tap; the eraser refunds in full.
- **No power** in the first layer (it arrives as its own layer).
- **Persistent**: `user://millstream.cfg`, saved on leaving, on pause and
  every 30 s. The factory **pauses while the app is closed**; no offline
  catch-up.
- **Code**: `arcade/millstream_sim.gd` (pure data, fixed DT 1/30 s),
  `arcade/millstream_art.gd` (cached meshes, shared with the tab's banner),
  `arcade/millstream_screen.gd` (draws it and plays its events). Arcade
  analytics (`arcade_start`, `arcade_end`, `arcade_abandon`). Sounds in the
  `CARTOON` style for the hands and the machines, `ARCADE` for the jingles.
  No new test suites (the MVP rule); probe and shot harnesses only.

## Slice 1 (this build): hand extraction and the auto kiln

The first playable cut, so it can be felt on a phone before belts exist.

- The valley as above, 20 x 28 tiles, the camera panning and pinch-zooming
  over it. Iron deposits are live; copper and stone stand on the map
  locked ("later").
- **Hand extraction**: a tap on an iron deposit chips off one ore, which
  flies to the stock.
- **The Kiln** is the one building: bought for 10 iron ore from a chip in
  the panel, placed by a tap on free grass (a red ghost where it cannot
  go). It **smelts by itself**: one ore to one ingot every 2 s (30/min), no
  fuel. A tap on a kiln collects its ingots into the stock and tops its
  hopper up from the stock's ore (hopper 20, output shelf 50). A kiln
  stalls visibly when its hopper is empty or its shelf is full.
- The eraser lifts a kiln and refunds it (and whatever it held).
- **Milestone 1, "First ingots"**: 20 iron ingots handed in at the Mill
  from a button on the panel's milestone card. Handing it in ends the
  slice: a banner, the time, and "Drills come next". The factory stays
  open to play on.
- Saved and resumed as above; the top bar's restart starts a new valley.

## Amendment, 2026-09-27: the bag, and things to pick up

The user's first refinement after playing slice 1: what the hands and the
kilns make should land in the valley and be gathered, and the stock
should be a bag that is opened, not a row of numbers.

- **Dug ore pops out of the vein onto the grass** (`Sim.loose`), 1.35-1.9
  tiles from the deposit's centre, always on open grass. A tap on the grass
  picks up everything within a fingertip (0.6 tiles, or 60 screen px,
  whichever is wider), and each piece flies across the screen into the
  **bag**, a sack on a paper disc in the valley's bottom-right corner that
  counts it on arrival. A tap on the rocks still digs, so rocks dig and
  grass gathers.
- **The bag is a button**: a tap opens a strip of four slots along the
  valley's foot (ore, ingots, two for later), and the paper row of stock
  above the valley is gone (the time moved beside the milestone's name).
- **A kiln is loaded by dragging**: a slot of ore dragged out of the bag
  onto a kiln fills its hopper from the bag (up to 20). The drop target is
  outlined green where the drop will take and rose where it will not; a
  refused drop flies back into its slot. A tap on a kiln opens the bag and
  says how, or how much ore it has left.
- **Each ingot pops out of the kiln's mouth onto the grass in front of it**
  and is picked up the same way. The kiln's shelf is gone: nothing piles up
  inside it, so a kiln only stalls for want of ore.
- **Ingots dragged onto the Mill hand the milestone in**, beside the
  panel's Hand in button.
- The save is version 2 (`loose` is kept); a version 1 save loads with its
  kilns' shelves emptied into the bag.
- Two new sounds, `pick` and `bag`. The probe finishes at 36 s at 3 taps a
  second and 48 s at 1.5 (picking every 4 s); nothing lands on water or a
  building.
