# Henhouse, the Arcade tab's fourth game

2026-09-27. Built in one sitting while the user was away, from their brief:
"check on web how this game works fully" (a screenshot of an egg-farm idle
clicker on VIVERSE), then "create this game into our arcade, include sfx,
end to end, i have to leave so do everything".

## 1. Where it lives

On the **Arcade tab**, the fourth card under Firefly, Hedgerow TD and
Molehill. It is a run for a result, not a daily board with a solve. It is
the first Arcade game whose best is a **time** (the quickest retirement),
so `arcade/arcade_record.gd` gained `add_time()` (lowest wins; a run that
never retires counts a play and its stage, never a best) and the tab reads
`TIMED` to show the best as `m:ss`. The card's "furthest" is the biggest
flock.

## 2. The game

**It is called Henhouse and nothing else**, in code, in a comment or on
screen. The reference is *The MachinEGG* by JC / Quantum Games Studio,
named here once to forbid it. What was taken from it, checked against its
store pages, the developer's devlog and players' comments:

- Buy hens; keep them **fed and watered** or they stop laying, and a flock
  kept dry is lost a hen at a time. Food is the early pressure on money.
- **Drag each egg** to market by hand at first; then a **conveyor belt**
  carries eggs dropped on it through machines that raise their value
  (washer, stamp, packer here) to the crate, where they sell.
- **Stroke the hens** with the finger: happiness makes them lay faster and
  fades.
- **Automation** takes the chores away one by one: auto-feeder,
  auto-waterer, a basket for a handful at once (the reference's magnet),
  and **squirrels** who fetch the eggs to the belt.
- A **rooster** makes some eggs fertile; left lying they hatch into chicks
  that eat twice as much and grow into hens. **A tap puts a chick to
  sleep** (asleep it neither eats nor grows), which is the reference's
  early-game trick. Squirrels leave fertile eggs to hatch while the pen has
  room.
- A radio (the reference's music) makes them lay faster and stay happy
  longer. Golden eggs are rare and worth ten.
- **Retire** is bought for a million; the run's result is its time. The
  farm closes if the last hen is lost with nothing left to buy another.
- A cap of 30 birds and 45 eggs on the ground, as the reference caps its
  own for the device's sake. Hens have names and say hello when they come.

Not taken: its modes (Speedrun, Adam & Eve, Egg Jam, Endless) and its
sanctuary. One mode, kept small.

## 3. Numbers

`arcade/henhouse_sim.gd` holds them all. Start: $20, one hen, troughs
full. A hen costs 10 x 1.2^n (n bought, so bred hens do not raise it), lays
every 5 s x (1 + happiness) x 1.25 with the radio. An egg is $2 x 2^feed
grade (five grades), x1.5 washed, x2 stamped, x3 packed, x10 golden.
Troughs hold 100 + 15 a bird; a bird eats 0.5 and drinks 0.6 a second, a
chick awake twice that; feed is $0.10 a unit (x1.35 a grade), water $0.06.
Dry for 20 s loses a hen, then one every 8 s. Prices: belt 30, basket 80,
washer 120, squirrels 200 / 2,500 / 25,000, auto-feeder and auto-waterer
250 each, radio 400, rooster 600, stamp 1,000, packer 8,000, feed grades
100 / 600 / 4,000 / 25,000 / 120,000, retire 1,000,000.

`tests/_probe_henhouse.gd -- [seed] [skill 0-2]` plays it with a one-finger
bot that refills, buys greedily and drags or strokes at a human's pace:
it retires in about **11.5 min** stroking hard (skill 2), **12.5-15 min**
stroking a little (1) and **18.5 min** never stroking (0).

## 4. The screen

The flat boards' top bar (Henhouse, motto *Treat the hens well*), a paper
row with money, flock (n/30, rose while the troughs are dry) and the time,
the farm in the Arcade's wooden frame, and the shop under it: two tabs
(Farm: hen, rooster, radio, better feed, auto-feeder, auto-waterer; Barn:
belt, basket, squirrel, washer, stamp, packer) of six paper chips (picture,
name, what it does, price or Owned, level pips), and the Retire button
beside the tabs, a bar filling toward the million.

The farm: a lawn with a fenced pen of trodden earth and straw with two
nests, the water tank on the left and the feed silo on the right (glass
tubes whose level falls, glowing rose and wearing a price tag when low; a
tap refills), and the barn wall below with the belt running to a crate
under a striped awning. An unbought belt is grey with a for-sale sign; an
unbought machine is a faint outline over it.

Drawing: a still mesh (lawn, pen, fence, trough frames, barn, belt bed,
crate), rebuilt on resize and when the barn changes; a front mesh of the
machines' bodies the eggs pass under; each frame one live mesh under the
birds (levels, the belt's slats, eggs), one draw call a bird sorted by
depth, one live mesh over them (the shower, the stamp's press, the packer's
flap, carried and held eggs, hearts, "!" over hungry hens, the radio and
its notes, a hen's hello), then text. Birds are drawn 1.3x a field unit and
eggs 6.2 units tall, so a thumb finds them.

Toasts teach it once each a run: drag the egg, buy the belt, drop eggs on
the belt, the basket, refill, hunger, stroking, the rooster's blue eggs,
sleeping chicks, and "press Retire".

Reduce motion: no walk cycle, bob, breath, pecking, heart float, belt run,
press or flap; eggs appear without the pop.

## 5. Build

- `arcade/henhouse_sim.gd`, `arcade/henhouse_art.gd` (the cast, eggs and
  the chips' icons, cached per look and scale), `arcade/henhouse_screen.gd`.
- The tab's card and banner (`ui/menu/arcade_tab.gd`). The card now puts
  Play beside the name, with the best and the furthest under it, so four
  cards fit, and a third fit level shortens the pictures to 104.
- `ui/menu.gd`'s `_open_arcade`, a vista entry, `locale/ui.csv` (`HH_*`).
- `tests/_shot_henhouse.gd -- <outdir> [reduce]`: the tab, the ready
  banner, a real drag through the viewport from an egg to the crate
  (printed: whether it sold), a grown farm, eggs held with the troughs low,
  the Barn tab, and the end card after retiring. It puts `user://arcade.cfg`
  back. A harness sending mouse events must map canvas to window
  coordinates (`root.get_final_transform()`); Molehill's hit boxes are big
  enough to hide the 0.75 at 810x1440, Henhouse's eggs are not.
- Draw calls at 810x1440: 149 on the Arcade tab with four cards, 101 at the
  start, 113-118 on a grown farm, 140 on the end card; ANGLE the same.
  Suite 122,593/0.

## 6. Sound

Twenty-six cues in `tools/gen_sfx.py`'s `henhouse` set, one take each: the
birds and the farm in `CARTOON` (cluck, lay, pick, drop, feed and water
pours, a content coo for a stroke, a hatch's peep, a grown hen, a sleepy
chick, the rooster's crow, a worried cluck, the shower, the stamp, the
box, a squirrel's chitter), the shop and the jingles in `ARCADE` (sell,
golden sale, buy, refused, lost, start, retire, game over, new best), and
`radio`, a six-second country loop that plays while the radio is owned.
The chatty ones sit low. Awaiting the user's listen.

## 7. Analytics

`arcade_start`, `arcade_end` (score = seconds to retire or 0, stage =
biggest flock, seconds, won, earned, sold, hatched, lost, best) and
`arcade_abandon`, as the other three.
