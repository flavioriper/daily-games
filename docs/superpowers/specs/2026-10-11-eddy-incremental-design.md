# Eddy as an incremental

The user, 2026-10-11: "eddy game should be a slow incremental where user buy
upgrades to go further and further, not a one take game", then four answers
(runs with a shop between them; Eddy's own points, not gold; new tiers of
things; a climb of days, 60 to 90 runs) and "just build it all". Built the
same day with no concept tab and no plan document. It supersedes calls 2
and 3 of `2026-10-10-arcade-eddy-design.md` (the battery's length, and the
reference's upgrades folded into two gold boosters). Everything that spec
says of the water, the pad, the pond and the camera stands.

## 1. The loop

A run plays as before and ends when the spin is empty. Its score is banked
as **drops**, Eddy's own currency, kept in `user://arcade.cfg` (section
`eddy`: `drops`, `up_spin`, `up_pull`, `up_mouth`, `up_reach`). The end card
says what was banked and shows the bank; its first button is **Upgrades**
when the bank covers one, else Play again. The same shop opens from a
button under the opening lines before the pad is first leaned. A fresh run
is fitted with the levels held (`Sim.fit`). Nothing is earned while the app
is closed and gold buys none of it.

## 2. The four upgrades

`arcade/eddy_upgrades.gd`. None has a top; each level costs `GROWTH`
(1.36) times the last, rounded to fives.

| Upgrade | First price | A level is worth | In the sim |
|---|---|---|---|
| Spin | 40 | 2 seconds of spin | `spin_full` |
| Pull | 50 | 0.05 more of the turning running inward (0.45 at first) | `inflow` |
| Mouth | 60 | 0.6 units of core at level 1 (7 at first) | `core0` |
| Reach | 50 | 0.2 cores of reach (4.5 at first) | `far` |

Pull is the inward part of the water and not its turning: the catch asks a
thing to go round with the water to within `SLIP`, and faster turning would
have changed what is caught. The whirlpool's travel is not sold: the user
asked for it "way slower" the day before.

## 3. Further

Twenty levels (it was ten), and two tiers above the toys, afloat from the
first run and too big for it:

| Kind | Tier | Radius | Worth | Mouth takes it from level |
|---|---|---|---|---|
| Bucket | 3 | 21 | 40 | 10 |
| Watering can | 3 | 24 | 50 | 12 |
| Lilo | 3 | 27 | 60 | 13 |
| Raft | 4 | 33 | 120 | 17 |
| Rowing boat | 4 | 38 | 160 | 19 |

The pond keeps six of tier 3 and three of tier 4. The levels above are for
a whirlpool with no Mouth bought; each Mouth level brings them nearer. The
pond stays 600 by 1000 and the camera stops widening at its width.

## 4. The pace

A run with nothing bought is 30 seconds and 4 back a level (it was 50 and
7): the patient bot ends it at level 4 with about 60 drops, the slower one
at level 3 with about 34. `tests/_probe_eddy.gd -- 6 ladder` plays the
climb: run after run, the score banked, the cheapest upgrade bought, until
a rowing boat goes down.

At a growth of 1.36 (2026-10-11, one climb each):

| Bot | Runs to a rowing boat | Minutes of play | Tier 2, 3, 4 first taken on run |
|---|---|---|---|
| patient (looks every frame, leans all the way) | 40 | 46 | 6, 24, 40 |
| middling (looks twice a second, leans 0.8) | 97 | 115 | 8, 44, 97 |
| slower (looks twice a second, leans 0.6) | 146 | 171 | 18, 74, 127 |

The 60 to 90 runs asked for lie between the patient bot and the middling
one. At 1.40 the three took 42, 97 and 159; at 1.45 the patient one took 55
and the slower one was at level 8 after 140. At 1.32 with the new things
worth 60 to 400 and stronger upgrades it was 19 and 42.

## 5. What went

The two gold boosters (Long spin, Head start) are gone from
`arcade/boosters.gd`; any held are given back at 120 gold each the next
time the screen opens (`Wallet.refund`), with a line saying so. The boost
card no longer stands before a run. The Second chance stays.

## 6. Calls that are mine, unconfirmed

1. The name "drops" and a run's score being its drops one for one.
2. The four upgrades, their first prices and what a level is worth.
3. Pull as inflow, not as faster turning.
4. Travel speed not sold.
5. The five new things and their sizes and worth.
6. The plate that showed the best score shows the bank; the best is on the
   end card only.
7. The tab's "furthest" line is still the biggest whirlpool's level, now
   of 20 (I had said it would become the biggest thing taken).
8. No new sound: buying plays the level's cue, the new tiers the toys'.
9. The gold boosters removed and refunded.
10. The pace itself: the bots bracket a person, they are not one.

## 7. Not done

A phone. The sounds heard. pt and es read by a speaker. A person's climb
timed. The concept tab the rule asks for when rules change.
