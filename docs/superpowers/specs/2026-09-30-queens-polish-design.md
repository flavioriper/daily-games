# Queens polish: courts that make you think, failing, Morning Mist, rewards, motion and sound

2026-09-30, built unattended on `feat/queens-polish` at the user's word
("let's polish the queens game, add more smooth animations, reinforce that
the sfx sounds are really cozy, add more visual rewards even if silly ...
make sure the insane difficulty is really insane, with something totally new
(something only us do) that make the game nearly impossible, user can also
fail on insane and hard ... I heard players complaining the game is too easy
because there is too much starting single cells, making it way easier to
solve because just by filling the single cells, it create news single
cells").

Nonogram's, Tents', Light Up's, Shikaku's and One Line's passes the same day
are the pattern: this follows them wherever the boards meet, so the game
fails and celebrates one way. No concept tab: polish of a built screen plus a
rule, with the user away. The calls at the end are for the user to judge on
the phone. Sections 1 to 12 of `2026-09-19-queens-flat-design.md` stand
except where this says otherwise.

## 0. The single cells, and courts that make you think

**What the players meant, measured.** A court was grown from its queens and
then *repaired* to a unique answer by moving cells between patches; nothing
stopped repair from shrinking a patch to **one cell**. A one-cell patch is a
queen handed out before the first thought, and seating her crosses her row,
column and neighbours, which often leaves another patch or line with one
cell -- the chain. Before this pass the opening court handed out a mean of
**0.53, 0.45 and 0.93 free queens** on Easy, Medium and Hard (60 seeds a
band).

- **No patch is ever one cell** (`Gen.KEEP` 2: repair refuses a move that
  would shrink a patch below two). The opening now offers no single on any
  band, and singles alone decide nothing on any court measured.
- **A hand-logic solver** (`puzzles/queens_logic.gd`) grades a court by what
  it asks of the player, in rungs: (1) singles; (2) bands -- pigeonholes over
  a run of rows or columns: the patches lying wholly inside the run fill it,
  or the patches reaching into it can only just fill it -- and reach, a cell
  whose queen would leave some line or patch without room; split into
  one-line bands and **wide** bands (two or more lines), which players find
  far harder; (3) suppositions: seat a queen in your head, follow rungs 1 and
  2, cross the cell if the court breaks. A court suppositions finish has
  exactly one answer, reached without guessing.
- **The bands** (`Gen.graded`, `Gen.fits`):
  - Easy (7x7, live): finishes without a wide band or a supposition.
  - Medium (8x8, live): needs thinking at least five times, or a wide band.
    Median 32 ms, worst 190 ms on the Mac (60 seeds, all fitting).
  - Hard (9x9, **banked**): two wide bands or a supposition. Grading it live
    was 184 ms median and 914 ms worst on the Mac, seconds on a phone, so it
    is mined like Insane (`tools/insane/queens_hard_ladder.gd`, id
    `queens_hard`, `content/insane/queens_hard.json`): 200 courts from 1600
    tries. **127 need a supposition** (bands and reach leave 10% to 70% of
    the court open on those, median 35%); the other 73 need two to five wide
    bands (median three). An empty bank falls back to the live grader.
- The level card: `QN_LVL_0`..`3` ("9 × 9, three hearts", "10 × 10, morning
  mist").

## 1. Hard and Insane can be failed

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`), on the family's paper pill
  in a `HEART_ROW` strip over the court.
- **What costs one**: a queen seated where the answer has none. Every seat on
  Hard and Insane is judged as she lands, as in the phone Queens games with
  lives (Queens Master's three lives, Queens Game's Legend mode). The answer
  is unique, so a wrong seat is wrong by proof. Crosses are never judged.
- **The wrong queen** lands like any other (her wave lays her crosses), then
  goes WORRIED, her cell blushes, a heart splits, and `EJECT_AFTER` (0.8 s)
  later she **buzzes off** -- up and wiggling, fading (`FLY_*`) -- her crosses
  draw back into her seat, and a cross in the family's rose (`SHOWN_INK`)
  drops in where she sat **for good** (`state.reveal`: a `shown` cross, out of
  every history entry, refused as a seat with "That seat is empty for sure. A
  heart showed it."). The heart bought the knowledge. Input, undo, hint, check
  and reset wait on `_ejecting`; `busy()` holds the host's hint video.
- **Out of hearts**: the court eases to dusk, the bees doze off along the
  diagonal, and `ui/hud/out_of_hearts.gd` comes up with `QN_OUT_BODY`/`_REST`.
  Try again deals the same court from the top in Reset's wave, every heart
  back and the shown crosses gone (hints spent stay spent, a hint's queens
  keep their seats); One more heart wakes them where they stand.
- **Insane has one hint** (`State.HINTS_BY_BAND`).
- **Check on Hard and Insane** looks at the crosses, since no wrong queen
  ever stays: a cross on a seat the answer wants shivers and blushes.

## 2. Insane: Morning Mist

Star Battle, which Queens is the one-star form of, puts **two** stars in
every row, column and region; its variants change the grid or add clues.
None we could find mixes the two, and none takes a seam away. Morning Mist
does:

- **Mist has faded some seams.** A misty patch is two neighbouring patches
  run together, and it takes **two queens**; every row and column still takes
  one, and no two queens touch. A queen in a misty patch does not cross it
  until its second queen sits; then the rest of it is crossed at once (the
  wave reaches it too).
- **Why it is nearly impossible**: every Queens technique leans on "one per
  patch" -- a patch confined to a row claims that row, k patches in k rows
  claim them. A misty patch claims nothing until both its queens are placed,
  and where the seam between its two colours ran is unknowable. On the banked
  courts, bands and reach leave **51% to 99% of the court undecided** (median
  63%); on Hard it is 0% to 70% (median 35% on the 127 that need a
  supposition at all).
- **The board**: 10x10, eight patches, two of them misty (`Gen.mist`: a
  unique 10x10 is grown, two disjoint touching pairs are merged, and repair
  runs again counting a misty patch as two until one answer is left). Three
  misty patches came back unique 3 times in 24, so two it is.
- **Fair**: kept only when suppositions finish it (so it is unique and needs
  no guess); `from_bank` re-proves every court through the logic solver and a
  quota-aware seating count agreed on every mined court.
- **Banked** (`content/insane/queens.json`, 180 courts from 5600 tries, 493 s
  on 8 threads, `tools/insane/queens_ladder.gd`). Rung = per-mille of the
  court bands and reach leave open, `HARD_RUNG` 500; `work` = suppositions,
  1 to 192 (median 14).
- **How it looks**: a misty patch is its colour `MIST_PALE` toward paper, with
  soft white wisps (`_build_mist`, one cached mesh) drifting over it as a
  whole (`MIST_DRIFT`, `MIST_SPEED`); it rolls in after the court's entrance
  (`mist`) and lifts at the party (`mist_lift`). Its **crowns**: a paper pill
  in its first cell's corner, over the bees, one crown a queen it takes, gold
  once she sits.
- Rules add `QN_RULES_MIST` and the hearts line; tips lead with `QN_TIP_MIST`
  and `QN_TIP_MIST_2` (the supposition, taught); a first queen in a misty
  patch says "One queen in the mist. That patch wants one more."

## 3. Rewards

- **Flowers**: a patch with every queen it takes opens two little daisies (a
  misty one three) in the corners of its free seats, with a twist and a
  stagger (`bloom`), and folds them when it loses a queen. On Easy and Medium
  a flower says only "this patch has its queen", which the board shows
  anyway; on Hard and Insane only right queens stay.
- **Streak**: right seats in a row -- on Hard and Insane the answer's, on Easy
  and Medium any seat the court accepts (it reveals nothing). `combo` pitched
  up the pentatonic from the second, the "x3" bubble, confetti at 5 and 10. A
  lift, a refused seat, a wrong queen, an undo or a reset ends it.
- **Gags**, three of every five right seats by the seat's hash: **little
  hearts float up** off her (`love`); **a drone bee flies a loop** round her
  (`drone`); she **twirls** a whole turn on a hop with a sparkle (`twirl`).
- **The party**, after the solve wave: the court turns into a **meadow**, a
  flower on every free seat along the diagonal; the **bees dance**, swaying on
  the beat (`dance`); confetti twice; on Insane the mist lifts; and the queens
  issue **a royal decree**, one of twelve silly ones picked by the court
  ("By royal decree: snacks count as a hobby.", `QN_DECREE_0`..`11`).
- **Seal**: Flawless (no hint, and no heart lost on Hard and Insane, or no
  Check on Easy and Medium) stamps the gold seal; any Insane solve the night
  seal, "Insane" over "Flawless" or "Morning Mist". `share_glyphs()` gains
  `🏅 Flawless` or `🌙 Morning Mist[ · Flawless]`. A restored solve shows the
  meadow, no mist, and on Insane the night seal.
- `win_delay()` is `WIN_WAIT` + `PARTY_EXTRA`.

## 4. Motion

New, on top of the flat spec's: the wrong queen's worry, blush and buzzing
flight, the rose cross dropping in, the heart split and return, the dusk and
the dozing, the flowers opening and folding, the mist rolling in, drifting
and lifting, the streak bubble, the love hearts, the drone's loop, the twirl,
the meadow, the dance and the seal's drop. Under reduce motion: no gags, no
confetti, no dance; the mist stands still, flowers and the meadow stand open
at once, the seal stands.

## 5. Sound

Re-prompted toward felt, wood, kalimba and soft wings, as the other boards'
were today (the tape-rewind undo and the marimba "bonk" read as a toy or a
scold): `place`, `remove`, `locked`, `undo`, `hint`, `check`, `check_ok`,
`reset`, `enter`, `solved`. New: `combo`, `confetti`, `love`, `drone`,
`twirl`, `bloom`, `heart_lost`, `buzz_off`, `out_of_hearts`, `heart_back`,
`stamp`, `party`, `dance`, `mist`, `mist_lift`. Rendered on the fallback key
(the first was out of credits); **unheard**.

## 6. Numbers

Draw-call peaks from `tests/_shot_queens.gd -- d=<n> <mode> [rm]` (810x1440,
`--always-on-top`, `opengl3_angle`):

| mode | d=0 | d=1 | d=2 | d=3 |
|---|---|---|---|---|
| solve (party included) | -- | 132 | -- | 138 |
| solve, reduce motion | 66 | -- | -- | -- |
| right seats | -- | -- | -- | 115 |
| wrong, to the card and Try again | -- | -- | 115 | 117 |
| restore | -- | -- | -- | 115 |

All far under the 855 budget. Suite: 122778 passed, 0 failed.
`tests/_win.gd -- queens`: PASS.

## 7. Calls for the user

1. **Morning Mist on the phone**: whether the pale patch and its wisps read
   as "one patch, two queens" at a glance, and whether the crown pill says
   "two" loudly enough.
2. **Hard is banked** (200 courts) rather than generated: the daily Hard is
   the same for everyone, as before, but it cycles after 200 days.
3. **Judged seats on Hard**: standard with lives, and it makes Hard losable,
   but a queen that stays is known right, which is more help than the old
   Hard gave.
4. **Twelve royal decrees**: silly on purpose.
5. **Sounds are unheard.**
