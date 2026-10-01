# Sunbeam polish: snails, Shy Dew, rewards and sound

2026-10-01, built unattended on `feat/sunbeam-polish` at the user's word
("let's polish the sunbeam game, add more smooth animations, reinforce that
the sfx sounds are really cozy, add more visual rewards even if silly to the
user to keep engagement, and make sure the insane difficulty is really
insane, with something totally new (something only us do) that make the game
nearly impossible, user can also fail on insane and hard ... don't worry if
you need to redo something on the logic or design, as long as it keep the
cozy vibe").

Caterpillar's, Rings' and Pinwheel's passes the same day are the pattern for
hearts, dusk and the card, the streak, the gags, the party and the seal. The
board's own spec (`2026-09-26-sunbeam-flat-design.md` and its amendment)
stands except where this says otherwise. The calls at the end are for the
user.

## 1. The rule both bands share: sleepers

Sunbeam had no wrong move -- every arrangement is reachable and the beam is
traced live. The fail state is therefore about **where the light is let
go**, never about where a piece stands:

- **Holding a piece is a free peek.** The beam follows the finger as before;
  nothing is judged until the release.
- **A move let go with the light resting on a sleeper** costs a heart, and
  the move is taken back (`State.judge`, `State.take_back`). The solving move
  is never judged.
- Every committed arrangement is therefore sleeper-free, so Undo and the
  drag back always lead somewhere safe, and from the opening the generator
  proves a way home that never wakes one.

| band | floor | hints | hearts | undo | sleepers |
|---|---|---|---|---|---|
| Easy | 5x6 | 3 | - | yes | - |
| Medium | 6x7 | 3 | - | yes | - |
| Hard | 7x8, 6 pieces | **2** | **3** | yes | **3 snails** |
| Insane | **Shy Dew**, 7x8, 7 pieces, crossing rails | **0** | **2** | **no** | **the drops** |

## 2. Hard: snails

Three snails nap on floor tiles (`ui/faces/snail_face.gd`, One Line's
walker, SLEEPY, with z's drifting up in the air mesh). The light passes over
them; letting go with it on one wakes it: a startled hop and a rose "!", a
heart splits, `EJECT_AFTER` 0.8 s later the piece slides back
(`SNAP_TIME`), and the snail dozes off again. While a held piece's light
lies on a snail it worries (WORRIED) and murmurs (`stir`).

**Where they sleep** (`Gen.lay_snails`): off the answer's beam, off every
rail, the lamp, the bud, drops and pots, never two side by side, and never
on a cell the light crosses on a **reference way home** -- every off-home
piece slid straight home, one at a time, in one of six orders tried from the
opening. Among those cells, the ones the most **near misses** light (one
piece a peg off, at any point along that way). So the floor can always be
finished without waking one, and the snails sit where a careless release
puts the light. Measured on 20 seeds: 7-57 ms on top of Hard's grow.

**The hint** slides home the first piece along the answer whose homing wakes
no snail (`_quiet_home`): 240 hints over 40 Hard floors, none left a snail
lit (`tests/_probe_sb_hint.gd`).

## 3. Insane: Shy Dew

**The dewdrops are shy: a move let go with the light on any drop dries it --
unless that move lights every drop at once and ends in the bud.** So the
floor must be set in the shade and the light let in by one last move.

- **Why it is ours**: checked 2026-10-01 against the light-and-mirror genre
  (rail-sliding mirrors, target rings, coloured lasers, multi-target
  levels): every one asks that targets be lit at some point or at the end,
  and none forbids lighting them *on the way* -- a goal that is also the
  thing you must not touch until the very end.
- **Why it is nearly impossible**: the player has to find the one answer
  (proved unique as before) and also an *order*, and a held piece only peeks
  -- arranging the rest of the floor while the light is shut out means
  setting it up blind and peeking by holding the curtain piece open. A
  natural strategy is discoverable ("close the light off first, set the
  floor in the shade, then open it", `SB_TIP_CURTAIN`), but on the banked
  floors it is not enough: **every banked floor's shortest dark way takes at
  least one move more than one a piece** -- a detour the player has to find.
  Two hearts, no hints, no Undo; Reset stays and keeps the hearts lost.
- **The look**: a drop under a held piece's light trembles in a rose halo
  (rule: no state by a shade of the piece's own colour) and the sprout warns
  once a drag (`SB_SHY_WARN`); a dried drop shrinks to a speck in a puff of
  steam and fills back up as the move slides back. On the solve every drop
  catches the light at once: rings on all of them, sparkles together and a
  `chorus`.
- **The proof** (`Gen.dark_path`): breadth first over every arrangement
  (mixed-radix index, the lean tracer `Gen.Fast`), exact, from the opening to
  any dark arrangement one move from home. 0.1-0.6 s a floor here, so Insane
  is banked; without a bank it deals Hard's floor live, snails and all.
- **The bank**: `tools/insane/sunbeam_ladder.gd` through
  `tools/mine_insane.gd`: 1600 tries, 1348 ms a try a thread, 270 s wall on 8
  threads. Rung = the detour (dark way minus pieces off home): 1364 tries at
  0, 195 at 1, 33 at 2, 7 at 3, 1 at 4; the 200 kept are every rung of 1 or
  more and the 159 best-trapped of rung 1. `work` = opening moves that would
  dry a drop.
- `SB_LVL_3` "Shy Dew: light every drop at once"; tips `SB_TIP_SHY`,
  `SB_TIP_HOLD`, `SB_TIP_CURTAIN`, `SB_TIP_ONCE`, `SB_TIP_HEARTS`; rules
  `SB_RULES_SHY`. A Shy Dew solve shares `🫣 Shy Dew[ · Flawless]` and stamps
  the night seal.

## 4. Rewards, even silly

- **The streak**: moves in a row that light a drop the light had not reached
  before (a move that darkens one, a wrong move, Undo, Hint or Reset ends
  it): `combo` up the pentatonic from the second, the "x3" bubble over the
  drop from the third, confetti at 4, 7 and every 5.
- **Gags** on one newly lit drop in three, one at a time: **a little rainbow**
  springs up out of the drop on two puffs of cloud (light through dew);
  **love hearts** float off it; **a butterfly** flutters in, sips at it and
  flies off.
- **The party**, after the bloom: confetti twice, **a rainbow arch** drawn
  across the glass from foot to foot, **butterflies rising off the flower**,
  **the nap cat** hopping onto the frame's foot and curling up, **sunny
  wisdom** (one of twelve, `SB_CHEER_0..11`), and **the seal**: gold for
  Flawless (no hint, and no heart lost on Hard and Insane / no Undo on Easy
  and Medium), night for any Shy Dew. `completion_record()` keeps `hearts`
  and `flawless`; restore shows the cat asleep and the seal.

## 5. Motion

New: the hearts' pop and split; the wrong move's landing, startle (hop and
"!") or steam, and slide back; the dusk; the snails' z's and their worry
under a peek; the shy drop's tremble and the dried drop's refill; the
rainbow, hearts, butterfly, arch, flutter, cat and seal. Under reduce motion:
no z's, gags, confetti, arch or flutter; a wrong move shows its "!" or dried
drop and takes the move back at once; cat and seal at once.

**Fixed on the way**: a solved day reopened within 100 s of launch showed the
bud shut -- `_solved_at` and `_bloom_at` used `t - 100` for "long ago" and a
negative value for "never". Both are `AGO` (-1e9) now.

## 6. Sound

A new style, `GLASSHOUSE` (`tools/gen_sfx.py`): a warm sunlit greenhouse,
soft glass and music box chimes, felt-soft brass ticks on wood, kalimba,
hushed. Re-prompted: `lift`, `slide`, `drop`, `dew`, `dry`, `refuse`,
`undo` (was a tape rewind), `hint`, `reset`, `solved`, `enter`. New: `stir`,
`shy`, `wake`, `sizzle`, `heart_lost`, `slip`, `out_of_hearts`,
`heart_back`, `combo`, `confetti`, `rainbow`, `love`, `flutter`, `chorus`,
`stamp`, `party`, `purr` (COZY). `step` untouched. Rendered on the fallback
key (the main one is out of quota); **unheard** by a person.

## 7. Numbers

`tests/_shot_sunbeam.gd` at `--resolution 810x1440 --always-on-top`,
windowed, one at a time, peak draw calls from 0.5 s:

| mode | band | peak |
|---|---|---|
| rest | Medium / Hard | 78 / 85 |
| hold (peek on a sleeper) | Insane | 64 |
| wrong | Hard / Insane | 86 / 66 |
| out (dusk, card, Try again) | Hard | **107** |
| right (streak, gags) | Medium | 80 |
| solve and party | Insane | 94 (ANGLE 94) |
| restore | Insane | 72 |
| solve, reduce motion | Easy | 85 |

Peak 107, 748 under the 855 budget. Suite `passed=122403 failed=0`;
`tests/_win.gd -- sunbeam` PASS.

## 8. Calls for the user

- **The fail rule is about the release, not the piece.** Holding is free, so
  a heart is only lost by letting go somewhere the board showed. If Hard
  should be harsher, the snails could also wake when the light only passes
  them mid-drag.
- **Shy Dew forbids a drop lit at rest, not only all of them.** One drop lit
  is already a dried drop. The softer variant ("never light *all but one*")
  would make the curtain trick unnecessary.
- **No Undo on Insane**; dragging a piece back still works, Reset keeps the
  hearts lost. Hard keeps Undo, which can only return to snail-free floors.
- **Three snails on Hard**; 2 is gentler (`BANDS[2].snails`).
- Snails sleep only where the reference ways home never light; a player who
  finds a *different* order might be forced to detour round one -- that is
  the puzzle, and backtracking always works.
- Rainbow, butterfly, arch and the snails' startle were judged on stills and
  numbers only. Sounds unheard.

- **Review findings, fixed**: Reset and Try again kept a hint's pins and
  were never judged, so the floor they dealt could leave the light on a
  snail, and in 2 of 595 probed Hard resets no dark way home was left at all
  (Try again dealt the same dead floor forever) -- on a floor with sleepers,
  Reset now drops the pins and goes back to the proved opening (hints spent
  stay spent); and the tip cycle read Easy's tips on every band, so Hard and
  Insane showed one band tip and then Easy's, Shy Dew's including "light
  every dewdrop" -- it cycles `_tips()` now. Checked clean by the review:
  `Gen.Fast` agrees with `Gen.trace` on 300 random arrangements of each of
  the 200 banked floors and 40 Hard floors; every banked opening is dark with
  a dark way home and one answer; every Hard opening wakes no snail.

## 9. Amendment: the light gathers strength from the dew (2026-10-01)

Asked for by the user the same morning ("make the beam start weak visually
and get stronger as it pass on the water, so if the player direct the laser
to the plant weak, it only grow the plant a little bit").

- **The beam leaves the sun weak**: `WEAK_WIDTH` 0.3 of its width and
  `WEAK_ALPHA` 0.28 of its alpha, and gains an even step at every drop the
  drawn light passes (`_drop_marks`, from `_trace_live`'s `drop_at`, snails
  excluded), full once it has passed them all. It is stroked a stretch per
  drop (`_draw_beam`, `Parts.beam`'s new `width`); the pulses flowing at rest
  follow the same strength (`_power_at`). The joins sit under the drops, so
  the step reads as the drop lighting it up.
- **The bud grows by the light that reaches it**: (drops passed + 1) /
  (drops + 1) of the way -- the stem stretches, a second pair of leaves
  unfolds, the bud swells -- but it stays shut; only the solve blooms it
  (`Parts.bud`'s new `grow`). It eases up over `GROW_UP` 0.25 s and back
  over `GROW_DOWN` 0.8 s when the light leaves, and follows the light live,
  so a held piece previews it too. The dry-bud line now says "The bud grew a
  little. Pass N more drops for a stronger light."
- On Shy Dew the light at rest never passes a drop, so it always arrives
  weak until the last move -- which brightens it all at once.
- Draw calls unchanged (one mesh): 94 solving Insane, 107 out of hearts.
  `tests/_shot_sunbeam.gd`'s new `weak` mode lays the answer with one or two
  pieces off and shoots every arrangement whose light reaches the bud
  through fewer drops; on a proved board they are rare (none on some
  floors), so the grow is seen mostly mid-drag.
