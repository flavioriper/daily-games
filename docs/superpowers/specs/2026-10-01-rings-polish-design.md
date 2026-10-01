# Rings polish: dead ends, Tumble, rewards, motion and sound

2026-10-01, built unattended on `feat/rings-polish-2` (worktree
`../daily-rings`) at the user's word ("let's polish the rings game, add more
smooth animations, reinforce that the sfx sounds are really cozy, add more
visual rewards even if silly to the user to keep engagement, and make sure
the insane difficulty is really insane, with something totally new
(something only us do) that make the game nearly impossible, user can also
fail on insane and hard ... don't worry if you need to redo something on the
logic or design, as long as it keep the cozy vibe").

Pinwheel's pass the same morning (`2026-10-01-pinwheel-polish-design.md`)
is the pattern: hearts, dusk and the card, the streak, the gags, the party
and the seal. No concept tab: polish of a built screen with the user away.
The flat spec (`2026-09-20-rings-flat-design.md` and its amendments) stands
except where this says otherwise. The calls at the end are for the user.

## 0. Why it was too easy

Nothing could be lost: Undo and Reset were always there and a stuck board
only showed a toast. Insane was Hard's deal under a move budget, which with
Undo bound only the finishing line.

## 1. Hard and Insane can be failed: dead ends

A ring-sort move has no single right answer, so a move cannot be judged
against "the" solution. What *can* be judged is a **dead end**: a drop after
which no line of play sorts the pegs. `Gen.verdict()` walks every line from
the position (depth-first over canonical positions, NODE_BUDGET 20000) and
returns 1 (sortable), 0 (proved dead) or -1 (out of nodes, treated as alive:
a heart is only ever taken for a proof).

| band | colours / pegs | hints | hearts | undo |
|---|---|---|---|---|
| Easy (0) | 4 / 6 | 3 | - | yes |
| Medium (1) | 5 / 7 | 3 | - | yes |
| Hard (2) | 6 / **7** (was 8) | **1** | **3** | yes |
| Insane (3) | **Tumble**, 6 / 7 | **0** | **2** | **no** |

- **Hard moved to seven pegs.** On eight pegs under 1 % of legal moves were
  dead ends (Python over random play), so hearts would almost never be at
  stake; on seven it is ~6 % (GDScript probe: 48 of 881). About four deals in
  one are proved; the proof costs a few hundred nodes.
- **A doomed drop** (`would_doom`, checked on a copy before the drop): the
  state never takes it -- the ring is put back at once -- and the picture
  plays it out: it flies over and threads down onto the stack it would doom,
  wobbles there three rocks while the stack shivers (`wobble`), a heart
  splits on the pill, and it hops home (`hop_back`), turning back over if it
  is two-tone. Input, Undo, Hint and Reset wait (`busy()`).
- **Out of hearts**: dusk, `ui/hud/out_of_hearts.gd` with `RG_OUT_BODY` /
  `RG_OUT_REST`; Try again deals the same pegs back with full hearts; One
  more heart once a board.
- The **stuck toast** stays for Easy and Medium (and for a -1 verdict).
- **The old soundness hole is closed**: the solver used to prune "never move
  a uniform peg onto an empty one", which was never proved and is wrong once
  rings turn over. Only sound prunings remain (a locked peg is never a
  source -- the game's own rule -- and a lone plain ring never moves onto an
  empty peg, a pure rename), because a verdict now costs a heart.
- **Cost on this Mac** (GDScript, `would_doom` per legal move along random
  plays, 12 deals a band): Hard 0.32 ms mean, 1.4 ms worst; Insane 3.9 ms
  mean, **43 ms worst**. It runs synchronously in the tap, while the ring
  starts its flight; on a slow phone the worst case may be a visible hitch.

## 2. Insane: Tumble

**Some rings are two-tone -- one colour on top, another underneath -- and
lifting a ring turns it over.** It rises off its post in a somersault
(squashing to its edge, opening with the other colour up) and lands showing
its lower colour. A peg is home when four rings show one colour on top.

- **Why it is ours**: checked 2026-10-01 against the genre's apps and their
  published level mechanics (mystery/hidden balls, frozen balls, locked,
  covered and one-way tubes, wild balls, move limits, timers): none turns a
  piece over when it moves.
- **Why it is nearly impossible**: every lift of a two-tone ring changes the
  colour census on the board, so the player must plan the *parity* of each
  two-tone ring's moves as well as the sort. Two hearts, no hints, no undo,
  and ~11 % of legal moves are dead ends (113 of 1023 in the probe); random
  safe play solved 2 of 12 deals within 80 moves.
- **How it reads**: the band is split at a cream seam -- top colour above with
  its emblem, under colour below with its own small emblem -- so a ring's
  future is printed on it. In hand, the ring already shows what it will land
  as, so the drop rule is the usual one.
- **The encoding**: a plain ring is its colour, 0-5; a two-tone ring is
  `top | (under + 1) << 3`; `Gen.flip` swaps them and is the identity on a
  plain ring, so every rule reads rings through `Gen.top()` and Easy-Hard are
  untouched.
- **The bank**: six of the 24 rings two-tone (unders a derangement of their
  tops, so each colour still has four tops and four unders), dealt over
  seven pegs. Live dealing needs ~48 tries a day at up to 20000 nodes each,
  so 180 deals are mined offline by `tools/insane/rings_tumble_mine.py`
  (Python, the board's same search and move order, kept only when proved
  within 20000 nodes and opening with no peg home; proof work 203 / 637 /
  13635 nodes min / median / max) into `content/insane/rings.json`. The old
  move-budget bank, its `par`, "N moves left", and
  `tools/insane/rings_ladder.gd` are gone. Without a bank Insane deals Hard
  live, plain.
- Tips: `RG_TIP_TUMBLE`, `RG_TIP_UNDER`, `RG_TIP_NO_UNDO`, `RG_TIP_HEARTS`.
  `RG_LVL_3` "Tumble: two-tone rings, two hearts". A Tumble solve shares 🙃.

## 3. Rewards, even silly

- **The streak**: drops onto a ring of their own colour in a row (an empty
  peg is neutral; a dead end, undo or reset ends it). `combo` up the
  pentatonic from the second, the "x3" bubble over the post from the third,
  confetti at 4, 7 and every 5.
- **A gag** on one streak drop in four (any twelve drops share the three
  kinds), one at a time: the top ring **twirls** a whole turn on its post
  (`twirl`); **love hearts** float off the post (`love`); a **bumblebee**
  (drawn in code) buzzes in, loops twice round the post and drifts off
  (`buzz`).
- **A lock** now hops for joy with a pinch of confetti, on top of the glint
  and the daisy.
- **The party**: every peg's solve hop, confetti twice (`party`), a
  **runaway hoop** in the day's colour rolling across the terrace, wobbling
  and spinning down flat (`hoop`), **the nap cat** hopping in by the lower
  plank and curling up (`purr`), the sprout's **ring wisdom** (one of twelve,
  `RG_CHEER_0..11`), and **the seal**: gold for Flawless (no hint, and no
  heart lost on Hard and Insane / no undo on Easy and Medium), night for any
  Tumble ("Insane" over Flawless or Tumble). `completion_record()` keeps
  `hearts` and `flawless`; restore shows every colour home, the cat asleep
  and the seal.

## 4. Motion

New: a **press dip** on the peg under the finger; Tumble's **somersault** on
the lift, on a put-back, an undo and a hint; the **doomed drop**'s wobble and
hop home; the **lock hop**; the **twirl**; the heart pill and its split; the
dusk; love hearts, the bee, the bubble, the hoop, the cat and the seal. On
Easy and Medium a soft leaf ring breathes round every post the held ring
may land on. Under reduce motion: no flights, gags, confetti or hoop; a
doomed drop only shivers the stack and splits the heart; cat and seal at
once.

## 5. Sound

A new style, `TERRACE` -- hollow wooden rings on felt, kalimba and a music
box on a sunny terrace. Re-prompted: `lift`, `drop`, `lock`, `refused`,
`undo` (no more tape rewind), `hint`, `reset`, `enter`, `solved`. New:
`combo`, `confetti`, `twirl`, `love`, `buzz`, `tumble`, `wobble`,
`heart_lost`, `hop_back`, `out_of_hearts`, `heart_back`, `stamp`, `party`,
`hoop`, `purr`. Rendered on the fallback key (the first was out of quota);
**unheard** by a person.

## 6. Numbers

`tests/_shot_rings.gd` at `--resolution 810x1440 --always-on-top`, windowed,
one at a time, peak draw calls from 0.5 s (through `world/main.tscn`):

| state | band | peak draw calls |
|---|---|---|
| rest | Easy / Medium / Hard / Insane | 86 / 86 / 87 / 72 (two runs) |
| lift (somersault, put back) | Insane | 73 (ANGLE 73) |
| doom (wobble, heart, hop back) | Hard | 89 |
| out (dusk, card, Try again) | Hard | **110** |
| press (the dip) | Medium | 87 |
| right (streak, bubble, confetti, gags, undo) | Easy | 92 |
| solve and party (hoop, cat, night seal) | Insane | flawless, `🙃 Tumble · Flawless` |

Peak 110, 745 under the 855 budget. Suite `passed=122403 failed=0`;
`tests/_win.gd -- rings` winnable 1/1.

## 7. Calls for the user

- **The judge is "dead end", not "wrong"**: a heart is lost only for a drop
  proved to leave the pegs unsortable. It leaks one bit (that drop was
  fatal) and the ring hops back, so the board is never left dead.
- **Hard is now seven pegs** (it was eight, the reference's own). On eight
  the judge almost never fired.
- **No undo on Insane**; Reset stays and keeps the hearts lost.
- **Six two-tone rings** a Tumble deal (`TWO_TONE` in the miner). More is
  harder to read and needs a bigger proof budget.
- **The streak counts drops onto their own colour**, not "right" moves -- the
  board cannot say a move is right.
- Easy and Medium now show where the held ring may land (a leaf ring round
  the post). Remove `_landing_mark` if it reads as hand-holding.
- Bee, hoop, love-heart sizes, the wobble's 0.55 s and the somersault -- all
  judged on stills only.

- **Review findings, fixed**: Hard on seven pegs ran out of its 40 deal
  tries about once in 440 seeds and fell back to a proved-dead deal (every
  drop a heart, for everyone that day) -- `ATTEMPTS` is 400 now and the nine
  reported seeds all deal sortable boards (worst deal 20 ms); the doom check
  has its own `DOOM_BUDGET` 4000 (out of nodes = alive, so it can only let a
  dead end through, never take a heart wrongly) and caught 110 of 1040 on
  Insane with a 42 ms worst on this Mac; lifting a ring off a peg another ring
  was still threading down onto drew that ring twice (an old bug) -- the
  flight lands first now; the 🙃 share and the night seal key on a Tumble
  deal, not on the band. Left: a reopened Tumble solve shows its colours home
  as plain rings (the record does not keep the rings).
