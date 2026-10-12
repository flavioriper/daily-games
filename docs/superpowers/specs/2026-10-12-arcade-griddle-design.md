# Griddle: the twelfth Arcade game

2026-10-12. Built unattended. The user, of a screenshot of a 2006 browser
game: "check what you can find on web of the fully spec of this old flash
... game", then "can we create our own version of the game, without naming
[the brand]?", then "create it no need for playable on tab, on arcade tab,
check any reference you need on web, wire everything even sound, do
autonomous, no questions. Cozy animations, good animations on key events,
satisfactory sounds on combos".

## 1. What it follows, and what it may not be

The reference is Molleindustria's *McDonald's Videogame* (2005/6), a satire
in which a fast-food chain's four sectors (farmland, feedlot, restaurant,
headquarters) run at once and only stay solvent by vice. **That name, the
studio's, the brand's and the game's other portal name are written here
once, to forbid them**: none appears in code, comments, commits, locale or
on screen. The game is CC BY-NC-SA; this one carries ads, so **nothing of
it is here**: no art, no sound, no text, no code, and none of its numbers.
Its rules were read (from the web, which has no numbers, and from the
published file) only to understand the shape.

What is kept is the shape: **four places running at once whichever is on
the screen, each with a shortcut that pays now and annoys somebody, and
meters of that annoyance that push back**. What is not kept: the satire
(bribery, a burnt village, cattle fed to cattle, slaughter), the brand, a
real partner's name, the red and yellow, bankruptcy as the only end, and a
sale capped whatever is built.

## 2. The game

**Griddle**: a toastie stand. Bread from the fields, cheese from the cows,
the two grilled together and sold over the counter. A kept game like
Furrow and Nightlight (`user://griddle.cfg`, no run, no end card, no gold,
no interstitial), and it has no loss: a mood at the top costs something
and settles.

Every place works by itself, slowly, and a finger does the same at once:

| Place | By itself | A finger | The shortcut | Who minds |
|---|---|---|---|---|
| Fields | a cart cuts one ripe lot every 8 s | cuts a ripe lot at once; a lot's card sets wheat, clover or rest | tonic on a lot: half as much again, soil worn three times as fast | the gardeners |
| Yard | a pail takes one full cow every 6 s | takes a full cow's milk at once; tucks a poorly cow up | scraps in the trough (a feed lasts 12 s, not 8); two cows more than the stalls | the vet |
| Counter | a cook lays a toastie every 6 s a grill, a till sells one every 9 s | sells the front toastie to the front of the queue at once: a link of the rush | the hurry bell: the crew half as fast again, worn three times as fast | the crew |
| Office | - | the signboard's four notches, the four favours, the ledger | a loud signboard: 35% more customers a notch | the neighbours |

**The rush** is the combo. A toastie sold by hand within 3 s of the last
is a link; each link pays 8% more than the one before, to fifteen links
and no further; the 5th, 10th and 15th are named; a queue emptied by a
rush of five or more is a **clean counter**, paid a quarter of the rush
again. A till's own sale is no link and breaks none. The tills are slower
than the grills on purpose: left alone, the pass fills and the queue
grows, and the hand that comes back sells it all in one rush.

**The stand's stars** are the goal the reference lacks: the 20th, 80th,
250th, 700th, 2,000th ... toastie is a star (2.2 times the last after the
tenth), each star 15% on the price and 5% more customers, for good.

## 3. The numbers

All in `arcade/griddle_sim.gd`, all mine.

| Thing | Number |
|---|---|
| Lots | 12; 3 open (wheat, clover, clover); the next 25, each 1.6 times the last; a new lot opens resting |
| Wheat / clover | 18 s for 3 loaves / 14 s for 4 feed, on good soil |
| Soil | 100; a cut takes 1 (tonic 3); a resting lot gets 0.25 a second; gives fall to half at 0; under 30 the lot is tired |
| Larder | 24 loaves, 24 feed, 24 cheese; a level 8 more of each |
| Cows | 1, to stalls + 2; the next 40, each 1.7 times; stalls 2 to 6, 60 and 1.8 times |
| A cow | one feed each 8 s, one cheese's milk in 12 s; unfed 40 s she is poorly; poorly as she fills: 1%, 5% more a cow over the stalls, 7% more on scraps; tucked up she lies in 25 s |
| Grills, tills | 1 to 3 each; 250 then 2,500, 200 then 2,000 |
| Pass | 6 toasties, a level 2 more |
| Queue | 5 a till; a customer waits 40 s and goes |
| Customers | one each 9 s; 12% a level of the signboard's paint, 35% a notch of its loudness, 5% a star; halved while the signboard is down |
| Price | 4; 10% a level of the recipe, 15% a star |
| Pep | 100; 0.25 a second at work (bell: 3 times); tea is 15 s and gives 6 a second; pace from half at 0 to whole at 100; under 25 they are worn |
| Moods | 0 to 100, a warning at 60, the top at 100, then 35; each calms 2 a minute |
| Gardeners | 4 a minute a lot on tonic, 3 a tired lot. At the top: 15% of the coins held, tonic off and refused 2 minutes |
| Vet | 10 a minute on scraps, 5 a cow over the stalls, 6 a poorly cow left. At the top: 15% of the coins, scraps off, the herd lies in |
| Crew | 12 a minute under the bell, 6 worn with no tea. At the top: they walk out 45 s, the bell off |
| Neighbours | 0, 2, 8, 14 a minute by the notch (the first notch is free). At the top: the signboard down and customers halved 2 minutes |
| A favour | ten toasties' price, each a quarter dearer than the last for that mood; calms 50; a minute between two |
| Upgrades | no top, each level 1.55 times: Seed 40 (20% more a cut), Cart 30, Pail 40, Churn 60, Griddle 60, Tills 50 (each 10% quicker), Larder 50, Shelf 45, Recipe 80, Paint 70 |
| Away | the fields and the yard go on into the larder for 15 minutes at most; nothing is sold, no mood moves, no cow sickens |

Measured by `tests/_probe_griddle.gd -- pace`: a stand only looked on
(buying, never serving) takes 1,776 coins in its first hour and 113
customers walk off; a hand going round the places takes 2,729 and loses 5.
Stars at 3, 12, 34, 82, 191 and 387 minutes of that play.

## 4. The screen

The world fills the screen (the rule since 2026-10-10): one place at a
time, edge to edge, the flat boards' top bar and three plates over it
(coins, the rush, toasties to the next star), and at the foot a tray: the
shop's button on the left, then the four places, each with a dot when it
wants looking at (amber: something waits; red: it is going wrong).
Switching slides the land sideways.

- **Fields**: twelve lots on a meadow, the barn's cart going round. A ripe
  lot is cut by the touch; any other touch on an open lot opens its card
  (wheat, clover, rest, tonic). The next lot is bought at its signboard.
- **Yard**: the barn's stalls, each cow with her milk shown as it fills; a
  full cow carries a cheese over her; a poorly one a blanket and is tucked
  up by a touch. The trough, the scraps' bucket (a switch), a signboard
  each for the next cow and the next stall.
- **Counter**: the stand under its awning (teal and cream), the grills
  behind, the pass, the tills and the queue before them. A touch anywhere
  on the queue or the pass sells. The kettle sends the crew to tea, the
  bell is a switch, a bar shows their pep.
- **Office**: the signboard's four notches, four jars (one a mood) each
  with its favour, and the ledger: sold today and yesterday, the best
  rush, the stars.

No mascot: the stand's people are small round folk in the scenery
(`arcade/griddle_art.gd`), not faces to animate; the cows are Furrow's.

## 5. Moments, sound and feel

Every touch that changes something is heard and felt (the rule since
2026-10-10). The sounds are the three measured takes Beeline, Eddy, Gumdrop
and Furrow are made of (the light button on felt, the hollow block, one
muffled kalimba note): no new take.

| Cue | When | What |
|---|---|---|
| `serve` | a toastie sold by hand | the button; a semitone higher a link to five, and holds |
| `till` | a till's own sale, on the counter only | the button, a fourth down, quiet |
| `cook` | a toastie onto the pass, on the counter only | the block, one low knock |
| `cut` | a lot cut by hand | the block, three steps down |
| `milk` | a cow's milk taken by hand | the block twice, the second lower |
| `plant` | a lot's crop set | the block, lower |
| `switch` | tonic, scraps, bell, a notch | the button twice |
| `tea` | the kettle | two slow notes |
| `nope` | not enough coins, a full larder, nothing to sell | two low notches alike |
| `rush` | the 5th, 10th, 15th link | two notes up a third, a step higher each |
| `clean` | a clean counter | five up a step at a time |
| `tally` | a rush of three or more over | two knocks, the second a third up |
| `buy` | a lot, a cow, a stall, a grill, a till | three notches up |
| `level` | an upgrade | two notes up a fourth |
| `star` | a star | four notes up |
| `warn` | a mood at 60, a cow poorly | two slow notes down |
| `boil` | a mood at the top | three slow notes down |
| `favour` | a favour done | three notes, up and settling |
| `start` | the stand opened | two notes up, quiet |

The cart's and the pail's own work are silent: they are not the player's
touch. Motion: a cut's sheaf or bale flies to the barn, a cheese to the
shelf, a toastie from the pass to the customer who hops and walks off, the
coins to the plate; the rush's sum is lettered as it grows; a clean
counter and a star rain confetti; a jar at the top shakes. `Motion.reduce`
stills all of it but the letters.

## 6. Calls that are mine, the user's to change

1. **The name** Griddle, and that it is toasties: no meat, no slaughter.
2. **Cozy trade-offs in place of the satire** (the user was asked "cozy or
   dark" and answered "create it" under the recommendation for cozy).
3. **No loss.** A mood at the top takes 15% of the coins or a minute or
   two of something.
4. **Four moods, one a place**, not the reference's five.
5. **Favours bought once each time**, not paid monthly.
6. **Only a hand's sale is a link**, and the tills are slower than the
   grills so a rush is there to come back to.
7. **The stars**, their counts and what they give.
8. **Away fills the larder and nothing else**, 15 minutes at most.
9. **Soil that tires** and is rested by hand: no helper rotates the lots.
10. **Every number** in section 3.
11. **No concept tab** (waived by the user) and no new sound take.
12. **No mascot, no voices**, the cows shared with Furrow.
