# Furrow, the Arcade tab's eleventh game

2026-10-11. Built in one sitting while the user was away, from their brief:
"a idle farm game is the next arcade game to be created, check any
reference you need on web, wire everything even sound, do autonomous, no
questions. Cozy animations, good animations on key events, satisfactory
sounds on combos". No concept tab came first: nobody was there to judge
one, so it went spec to Godot as the other unattended builds have, and
every call the brief did not make is listed in section 8 as mine.

## 1. Where it lives

On the **Arcade tab**, the eleventh card, after Eddy
(`ui/menu/arcade_tab.gd`, `ui/menu.gd`'s `_open_arcade`). It is a **kept
game**, as Nightlight is: no run, no end card, no boosters, no Second
chance and no gold. Leaving it is not a moment for an interstitial.

## 2. The game

**It is called Furrow and nothing else**, in code, in a comment, in a
sound prompt, in a commit or on screen. No one game was followed. The brief
named a genre, and the genre's well-known names (the farm games whose
titles end in "Ville" or begin with "Hay", and the idle farms of the
stores) are named here once, to forbid them: no word of theirs is used.
What the web gave was thin and general (two searches, a handful of
write-ups and jam pages): small frequent gains feel better than rare big
ones; most idle games cap the hours earned while shut; unlocks are paced
by price; players of jam farm games ask for a harvest to say what it paid
and for a chain of harvests to feel different from single ones. The rest is
this repo's own rules for idle games (the Valley's, 2026-10-05 to 10-07:
slow, no caps, "finger picks, the rest runs", nothing rots).

- **A field of 20 plots**, four across and five down, four open on a new
  field. A plot grows one crop, and grows it again as soon as it is picked.
- **Eight crops**, each slower and worth more a second than the last:
  radish 10 s for 1 seed, carrot 30 s for 4, lettuce 90 s for 14, tomato
  4 min for 45, corn 10 min for 130, pumpkin 30 min for 450, sunflower 2 h
  for 2,100, watermelon 8 h for 10,000. The quick ones are for staying, the
  slow ones for going away.
- **It grows while the game is shut**, on the wall clock. What ripens
  **waits for the finger and never rots**; nothing is picked, sold or
  banked while away. So time away is worth one full field, however long it
  was, and no cap on hours is needed. A clock set back gives nothing and
  takes nothing.
- **The chain is the game.** A crop picked within 1.6 s of the last is a
  link, and each link pays 5% more than the one before, up to as many links
  as there are open plots (a chain kept going past that stays at its top,
  so nothing runs away). A field left to ripen and picked in one stroke of
  the finger pays far more than the same crops picked one by one: waiting
  is rewarded, which is what makes it an idle game and not a tapping one.
  The 5th, 10th, 15th and 20th link are moments. **The whole field in one
  chain is a clean sweep** and pays a quarter of the chain again (from six
  open plots, once a chain).
- **One ripening in twenty-five is golden** and pays five times.
- **Seeds are Furrow's own coin**; gold buys nothing here. They open the
  next plot (15 seeds, then 1.62 times dearer each; the order runs from the
  middle out), buy the next crop's packet (60, 600, 6,000, 50,000, 400,000,
  3 million, 25 million) and three upgrades in the shed with no top, each
  level 1.45 times the last: **Compost** (everything grows 4% faster a
  level, from 50), **Basket** (every crop pays 8% more, from 80), **Knack**
  (each link pays half a point more, from 120).
- **Sowing.** A packet tapped on the tray is taken in hand, and the finger
  then sows that crop on every bed it touches (a ripe bed is picked first;
  a growing one starts again). Tapped again, the packet is put back and the
  finger picks. A new plot is sown with what is in hand.

## 3. The pace

Measured by `tests/_probe_furrow.gd -- pace`, two bots that spend as a
player would. One stays and picks the field the moment it is all ripe: the
last crop and the whole field after **146 hours of play**. One looks in
every 45 minutes of a 16-hour day for five minutes and sleeps eight: **17.6
days** (carrot in the first minutes, tomato in the first evening, corn on
day 1, pumpkin on day 2, sunflower on day 5). After that the three
upgrades go on for ever. The first numbers tried (packets a sixth of these,
upgrades at 6% and 12%, 1.36 a level) gave 2.2 days and were thrown out.

## 4. The screen

**The land is seen from a corner.** The first build drew the plots as a
flat grid of beds, one plant each. The user saw it being made and sent a
picture of a farm game drawn isometric, whole fields of one crop with dirt
roads between them, a house, a barn, a mill and animal pens: "this is what
i was thinking". (The game in the picture is a store farm game with
"Happy" and "Story" in its title, named here once to forbid it.) So, the
same evening, with the rules untouched: a plot is a **lot**, a diamond of
turned earth planted with three rows of three of its crop; the lots lie
three and two a row, each row half a lot nearer, with road between; a
house, a barn and a mill whose sails turn stand in a yard behind them, and
trees and hay where a row of two leaves the side free. The plots open from
the middle out. The buildings are scenery: nothing is made or kept in them.

The land is the whole screen (`arcade/furrow_screen.gd` over
`arcade/furrow_field.gd`): grass edge to edge, the yard and the lots
between the plates and the tray. Over it the flat top bar (back, ?, gear;
no Undo, no Reset), three plates (seeds, the chain, ripe of open) and at
the foot the tray: the shed's button on the left, away from the thumb that
picks, then the eight packets, each with its growing time under it, the
next one with its price, the ones after it faint.

What moves, all honouring `Motion.reduce`: the mill's sails turn; every
lot's plants lean in the wind; a stage pops in with a squash (mound,
sprout, young, ripe); a ripe lot swells and glints, a golden one is gilt
with four glints going round it; three crops pop out of a picked lot and
fly in an arc to the seeds' plate, which bumps; the earth puffs; the
chain's sum is lettered under the plates and
grows with each link; a bunch is named ("Handful!", "Basketful!",
"Barrowful!", "Cartload!") with stars and a ring; a clean sweep is
lettered across the field with rays and confetti; a chain ending sends its
stars to the plate; a new plot's bed pops in with clods; a new packet is
named with rays and taken in hand; the next plot's signboard hops when it
can be afforded; a packet or a signboard that cannot be afforded shivers
and says how many seeds are short; the whole field ripe says so, once.

Draw calls, on `opengl3_angle` at 810x1440: 66 a new field, 84 the whole
field ripe, 153 at a clean sweep, 164 with the shed open. The budget is 855.

## 5. Sound and touch

`tools/gen_sfx.py furrow`, eleven cues, 0 flagged by
`tools/measure_sfx.py`, none heard by anyone. No new take: the set is the
three measured takes Beeline, Eddy and Gumdrop are made of.

- `pick`, the chain's tick (a light wooden button on felt): **a semitone
  higher each link, to five and no further**, so a stroke across the field
  climbs and then holds; 692 Hz at rest, 924 Hz at the top.
- `bunch`, two kalimba notes up a third, played 0, 2, 4 and 5 semitones up
  for the 5th, 10th, 15th and 20th link.
- `sweep`, five notes up a step at a time; `tally`, two knocks of the
  block as a chain of three or more ends (nothing falls); `gold`, one note.
- `sow`, `plot`, `nope` on the block; `level` (an upgrade), `crop` (a new
  packet), `start` (the field opened) on the kalimba.

Every touch that changes anything is heard and felt (tick a pick or a
sowing, bump a golden pick or a chain's end, good a bunch, a plot or an
upgrade, win a sweep or a new packet, warn a refusal, tap a packet or the
shed). A touch on a plant still growing letters its time left, nods the
plant, and is silent: it changed nothing.

## 6. Kept

`user://furrow.cfg` (`Sim.path`), saved on every purchase, at the end of a
chain, every twenty seconds, when the app loses focus and on Back. The
Arcade card reads it (`Sim.kept()`): the seeds held and the plots open.

## 7. Analytics

`furrow_enter` (plots, crops, seeds, away, ripe), `furrow_leave` (seconds,
seeds, picked, sweeps), `furrow_plot` (n, seeds), `furrow_crop` (crop,
seeds), `furrow_upgrade` (tile, level, seeds), `furrow_sweep` (n, seeds).
No event a pick.

## 8. Calls that are mine

1. The name, and that it is a kept game with no gold, no boosters and no
   interstitial.
2. It grows while shut, against the Factory's "no earning while closed":
   that was the Factory's rule and "idle" is this one's name. Nothing is
   banked away, only ripened.
3. **No helper that picks for you.** The chain rewards a field left to
   ripen, and a helper would pick it out from under the stroke. If one is
   wanted it should pick without a chain, and be a late upgrade.
4. The chain: 1.6 s, 5% a link, held at the open plots, the sweep at a
   quarter from six plots.
5. Eight crops and their numbers; 20 plots, four open; the three upgrades
   and that none has a top.
6. The pace: 17.6 days for a diligent bot, 146 hours for one that never
   leaves.
7. Golden crops, one in 25 for five times.
8. Sowing by a packet in hand, and that a growing bed sown again loses
   what it had grown.
9. No start-over button and no Reset.
10. No new sound take; the pick's climb of a semitone a link.
11. No mascot: the field has no face.
12. A touch on a growing plant is silent.
13. **How much of the picture was taken**: its view, its fields and its
    buildings as scenery. Not taken: animals and their pens, buildings
    that make things (a mill that grinds, a market that sells), roads to
    lay, people and carts, a land bigger than the screen. Each would be a
    rule, not a look, and none was asked for in words.
14. Three lots and two a row (so twenty stand upright on a phone), nine
    plants a lot, the yard's three buildings.
15. The words: seeds, the shed, Compost, Basket, Knack, the four bunches,
    "Clean sweep!", and their Portuguese and Spanish.

## 9. Not done

A phone. The sounds heard. Portuguese and Spanish read by a speaker. A
person's climb timed. A Furrow bot in `tests/_probe_arcade_buzz.gd`. The
still (`reduce`) shots.

## 10. The farm (2026-10-12)

The user, the day after: "when user click on the plant for the first time
it should display a dialog about how much it cost to sell and takes to be
ready, if user want to see again, must hold touch on it for a while. Also,
user must select and click to plant on soil after harvest, no auto for
now. We need cows for milk (user can upgrade to care cows), and chickens
for eggs (same, should upgrade). Cows and chickens must have it own
milestones, for example chicken generate eggs on ground, cow must be
clicked to give milk, user can buy upgrade to increase egg time, buy
rooster to get newborn from egg chance, fix the fence (case not, animals
can eat chickens). Plants can die if not harvest within time. Do
everything, and also do a polish on the design to make it more polished
and cozier, not so canvas looking". Built unattended, with no concept tab
and no questions; this section changes sections 2 to 8 where it differs
(what is ripe no longer waits for ever, a picked plot does not grow
again, call 13's animals are built).

**The rules as built** (`arcade/furrow_sim.gd`):

| | |
|---|---|
| A picked plot | bare until sown by hand; a new plot opens bare; a new field's four are sown with radish |
| Sowing | only a bare plot; a growing crop is dug up from its card |
| Keeping | ripe keeps 3 times its growing, 90 s at least; Mulch +10% a level; then dead: no seeds, cleared by a touch, no link |
| A thing's card | the first touch on a crop, a hen or a cow shows it and does nothing else; a finger held 0.5 s shows it again (a packet too) |
| The coop | 300; 2 hens, room for 8; a hen 150, each 1.5 times dearer; an egg a hen each 40 s, 3 a hen on the ground; an egg 5 seeds |
| Coop upgrades | Feed (+5% laying a level, from 150), Nest box (+10% an egg, from 200), each level 1.45 times the last |
| The rooster | 2,500, once; 8% of eggs are a chick, a hen in 5 minutes, to the coop's room |
| The fence | down when the coop is built; mended for 60 + 40 a hen, it holds 24 h |
| The fox | with the fence down, every 15 min (0.7 to 1.3 of it); 6 s on its way; a touch sends it off; else a hen, never the last; 2 at most while shut |
| The pasture | 4,000; 1 cow, room for 5; a cow 2,500, each 1.7 times dearer; full in 150 s, then she waits for a touch; a bottle 60 seeds |
| Pasture upgrades | Care (+5% filling a level, from 900), Pail (+10% a bottle, from 1,200) |
| Milestones | eggs 10, 50, 200, 1,000, 5,000, 20,000 pay 60, 400, 2,000, 12,000, 70,000, 300,000; bottles 5, 25, 100, 500, 2,500, 10,000 pay 300, 2,000, 10,000, 60,000, 350,000, 1,500,000; each reached is +10% on that animal's pay, for good |
| The chain | eggs and bottles are links; the clean sweep is every open plot picked in one chain, whatever else is in it |

The pace with all of it, by the probe's two bots: 97.9 hours staying,
16.5 days looking in.

**Calls that are mine, the user's to confirm**: every number in the
table; that the first touch shows the card and does not also pick; Dig it
up; that the packet stays in hand; Mulch; hens and cows capped by their
pens' room (Peapod's "no caps" was Peapod's); eggs and milk as links;
that the fence comes down again; that the fox can be shooed and how much
it takes away; no animal voices; the pens round, in the yard; the shed's
three pages; the field standing still while the guide is read.

**Not done**: a phone; the sounds heard; pt and es read; the `reduce`
shots; a concept tab.
