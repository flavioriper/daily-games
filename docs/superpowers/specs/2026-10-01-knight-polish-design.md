# Knight polish: hearts, Brambles, Start over, rewards and sound

2026-10-01, built unattended on `feat/knight-polish` at the user's word
("let's polish the knight game, add more smooth animations, reinforce that
the sfx sounds are really cozy, add more visual rewards even if silly to the
user to keep engagement, and make sure the insane difficulty is really
insane, with something totally new (something only us do) that make the game
nearly impossible, user can also fail on insane and hard ... Players are
complaining to get stuck sometimes with no button to restart").

Sunbeam's, Caterpillar's, Rings' and Pinwheel's passes the same day are the
pattern for hearts, dusk and the card, the streak, the gags, the party and
the seal. The board's own spec (`2026-09-26-knight-flat-design.md` and its
amendment) stands except where this says otherwise. The calls at the end are
for the user.

## 1. Stuck: the complaint

It was real. Reset sat in the top bar, but nothing on the board ever said
the day was lost, so a player hopped round a dead position not knowing
Reset was the answer. Random play measured (`tests/_probe_knight_bank.gd`):
**a quarter of positions on Medium and half on Hard have no way left to the
king** (95 of 360, 193 of 360), and the old Insane's spent move budget left
the board inert with two small lines of text.

- After every kept hop, once the pieces are still, Easy to Hard run
  `State.lost()`: trapped (every hop is a catch, or there is none) or no line
  by the exact breadth-first search, capped at `LOST_NODES` 6000 (a capped
  search says "alive"). Worst measured 6 ms on Hard.
- Lost: the toast "No way to the king from here. Undo, or start over." and
  **a Start over button** (the sun button, `KN_START_OVER`) pops in under
  the board and nudges once. Undo, a hint's rewind, Reset or the button take
  it away. While it is up the toast moves over the board.
- Insane needs no search: Brambles spends a square every hop, so every
  wrong path ends boxed in (section 3), which the board handles itself.
- The move budget is gone from every band (`slack` 0), with its lines.

## 2. Hard: hearts

| band | board | hints | hearts | undo | |
|---|---|---|---|---|---|
| Easy | 5x5, 1 rose | 3 | - | yes | |
| Medium | 6x6, 2 | 3 | - | yes | |
| Hard | 7x7, 2-3 | **2** | **3** | yes | |
| Insane | **Brambles**, 8x8, 3-4, banked | **0** | **2** | **no** | |

A catch still holds and slides back one move; on Hard and Insane it also
splits a heart on the pill over the board ("Caught! That costs a heart. N
hearts left."). Out of hearts: the garden table dozes (dusk), the card --
Try again (same board, hearts full, clock zero), One more heart (a video,
once), Back.

## 3. Insane: Brambles

**Every square your knight hops off grows a bramble, and nothing lands on a
bramble again -- not you, not a rose knight. A rose knight left with nowhere
to hop is fenced in and naps for the rest of the day: it catches no one and
can be taken.**

- **Why it is ours**: checked 2026-10-01. Knight-move games with vanishing
  squares exist -- *Knights' Tourney* (a two-player isolation duel) and
  *Knight Moves* (squares crumble after three visits) -- but none is a
  single-player proof puzzle where your own trail is the only lever on a
  deterministic guard: fencing the rose side in, and putting a guard to
  sleep by boxing it, is ours.
- **Why it is nearly impossible**: the dance -- hopping back and forth until
  the guard moves aside, the core trick of the other bands -- is gone, since
  no square can be used twice. The bank keeps boards whose shortest line is
  **14 to 30 hops** with **at most 12 winning lines** of up to two hops more;
  46 of the 200 need a nap (no line without one). Two hearts, no hints, no
  Undo; Reset stays and keeps the hearts lost.
- **Boxed in**: when no hop is left that is not a catch, a heart splits,
  your knight shivers ("Boxed in by the brambles! Back to the start."), and
  after `BOXED_HOLD` the brambles wither and every piece slides back to the
  opening. The last heart: dusk and the card.
- **The rules** live in `knight_gen.gd`'s `step(..., mask)` (a napping
  knight is its square plus `NAP` 1000) and `solve` (Brambles keys a
  position by `[int, mask]`). `tools/insane/knight_bramble_mine.py` is the
  same rules in Python: 400000 tries on 8 cores in 36 s, 3613 found, the
  200 kept ranked by line length (a nap counts six). `tests/_probe_knight_bank.gd`
  re-proves all 200 in GDScript: every line replays to a win never caught
  and the board's own search finds a line of the same length (0 bad; worst
  solve 102 ms). Without a bank Insane deals Hard live.
- **The look**: a bramble is a low leafy mound with two thorny canes and a
  small wild rose, springing up (`BRAMBLE_GROW`) as your knight takes off
  and withering (`WITHER_TIME`) when the board goes back. A napping knight
  shuts its eyes, nods and breathes slowly, with z's rising off its ear; the
  first nap says "Fenced in! That rose knight is napping now." A tap on a
  bramble: "Thorns grow there now. No square twice."
- `KN_LVL_3` "Brambles: every square you leave grows thorns"; tips
  `KN_TIP_BRAMBLE`, `KN_TIP_FENCE`, `KN_TIP_NAP`, `KN_TIP_CORNERS`,
  `KN_TIP_HEARTS`; rules `KN_RULES_BRAMBLES`. A Brambles solve shares
  `🌿 Brambles[ · Flawless]` and stamps the night seal.

## 4. Rewards, even silly

- **The streak**: kept hops in a row that are not hints (a catch, boxed in,
  Undo, Hint or Reset ends it): `combo` up the pentatonic from the second,
  the "x3" bubble over your knight from the third, confetti at 4, 7 and
  every 5.
- **Gags** on one kept hop in three, off the day's hash, one at a time:
  **a somersault** (the hop does a whole flip over the top, a sparkle on
  landing); **love hearts** float off your knight; **a butterfly** flutters
  in, rests on its ear (following it) and flies off.
- **A take**: dizzy gold stars circle the rose knight as it tumbles away,
  with a sparkle.
- **The party**: the king topples as before, but his crown now flies up and
  **lands on your knight's head**, where it stays (and on a reopened day);
  confetti twice, the nap cat hops onto the frame's foot and curls up,
  knightly wisdom (one of twelve, `KN_CHEER_0..11`), and the seal: gold for
  Flawless (no hint, and no heart lost on Hard and Insane / no Undo on Easy
  and Medium), night for any Brambles. When the king stands in the board's
  lower right quarter the seal takes the lower left and the cat the middle,
  so neither covers the finish. `completion_record()` keeps `hearts` and
  `flawless`.

## 5. Motion

New: a press on a square you can hop to crouches your knight, ready, and
swells the dot; the hop goes on the release over the same square (slide off
to take it back). The somersault; the hearts' pop and split; the dusk; the
brambles' sprout and wither; the naps' nod, breath and z's; the stars; the
crown's flight; the Start over button's pop and nudge; the cat and the
seal. Under reduce motion: no flips, z's drift or gags; the bramble is
simply there; cat and seal at once; a boxed-in board goes back after
`Motion.REDUCED_TIME`.

## 6. Sound

A new style, `PADDOCK` (`tools/gen_sfx.py`): a sunny garden table,
felt-bottomed wooden toy pieces on paper, kalimba and a music box, a hush of
leaves. Re-prompted: `hop`, `answer`, `take` (a cartoon bonk and twinkle),
`caught`, `slide`, `refuse` (was a wooden bonk), `undo` (was a tape
rewind), `hint`, `reset`, `solved` (now with a pony's nicker), `enter`. New:
`flip`, `bramble`, `nap`, `stuck`, `boxed`, `wither`, `heart_lost`,
`out_of_hearts`, `heart_back`, `combo`, `confetti`, `love`, `flutter`,
`crown`, `stamp`, `party`, `purr` (COZY). Rendered on the fallback key (the
main one is out of quota); **unheard** by a person.

## 7. Numbers

`tests/_shot_knight.gd` at `--resolution 810x1440 --always-on-top`,
windowed, one at a time, peak draw calls from 0.5 s:

| mode | band | peak |
|---|---|---|
| rest | Hard | 81 |
| caught | Hard | 84 (rm 83) |
| out (dusk, card, Try again) | Hard | **105** |
| lost (Start over) | Medium | 94 |
| boxed | Insane | 91 (rm 90) |
| nap and solve | Insane | 74 (ANGLE 77) |
| streak and gags | Easy | 90 |
| solve, reduce motion | Easy | 87 |
| restore | Insane | 74 |

Peak 105, 750 under the 855 budget. Suite `passed=122403 failed=0`;
`tests/_win.gd -- knight` PASS.

## 8. Calls for the user

- **Lost is told at once on Easy to Hard.** It is a little free knowledge
  (the board says the position is dead), but it is the honest answer to
  "stuck with no button". Insane never tells: there the brambles end every
  dead path on their own.
- **Brambles block the rose side too.** That is what makes fencing and naps
  possible; if rose knights could cross them the mode would be plain
  harder but less ours.
- **Boxed in costs a heart and restarts the board**; a dead position that is
  not yet boxed in plays on until it is. A player can also press Reset any
  time, keeping hearts lost.
- **Two hearts on Insane, three on Hard**; `HEARTS_BY` in the state.
- The crown on your knight's head and the brambles' look were judged on
  stills only. Sounds unheard.
