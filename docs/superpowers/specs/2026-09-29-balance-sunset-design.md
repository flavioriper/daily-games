# Balance: sunset, springy bales, motion, silly rewards, cozy sound

2026-09-29. The user asked for the whole pass unattended ("polish the balance
game, add more smooth animations, reinforce that the sfx sounds are really
cozy, add more visual rewards even if silly ... make sure the insane
difficulty is really insane, with something totally new ... user can also
fail on insane and hard ... do everything yourself"). Every section here is
the agent's own and open to review. Built on `feat/balance-sunset` (the old
`feat/balance-polish` is the 2026-09-27 pass, already on `main`).

## 1. Hard and Insane can be lost: the sunset

Before this pass nothing could be lost: moves were counted and never judged.

| band | loose fruit (typ.) | sun (moves) | hints | undo | One more hour |
|---|---|---|---|---|---|
| Easy (0) | 4-5 | none | 3 | yes | - |
| Medium (1) | 5-7 | none | 3 | yes | - |
| Hard (2) | 4-6 | **loose + 10** | **1** | yes, **costs a step** | +4 |
| Insane (3) | 4-6 | **loose + 8** | **0** | **no** | +3 |

- Every move is a step of the sun: a drop on the plank, a tap home, an undo,
  and on Hard a hint (the board's one or a video's: video hints stay
  unlimited, the user's call of 2026-09-29, but cannot outlast the day).
  Reset is free (it tells nothing new, and every fruit it sends home costs a
  move to bring back).
- The sun in the sky's corner **is** the clock: it walks down toward the far
  hill a step a move, sitting on the hilltop by the last move, and the sky
  warms to a dusk wash. A paper pill in the top corner counts the moves
  left, pops on each, and warms at three (`BAL_SUN_LOW`, a low kalimba note).
- Out of moves with the beam settled short of the win: the sun dips behind
  the hill, stars come out, the fruit nod off (SLEEPY, a z floating off
  each), and after 1.8 s Code Break's card (`ui/hud/out_of_rows.gd`, now
  keyed so a board passes its own words) offers **One more hour** (rewarded
  placement `"hour"`, once a board, no free path) or **Show the answer**.
- Show the answer: every loose fruit hops to its answer cup, the weight tags
  swing down, `finish_unsolved()` logs `puzzle_complete {solved: false}`.
  No Try again: the readings already taken make the same day free.
- While the card is up the board sets `out_of_hearts`, so the host's Back
  ends it unsolved (the hook Binairo and Code Break use).

## 2. Insane: springy bales ("Boing Bales")

**The bales under the plank's ends are springs.** When the beam comes to
rest lying on a bale (it reads past the glass, |pull| > 5), the bale
bounces every *loose* fruit on that low side up and home to the basket, head
over heels, seeing stars. Pinned fruit stay.

- Why it is Insane: the glass only reads ±5, and Insane's pinned fruit
  alone usually pull 40-120 units. The player cannot weigh by piling on and
  reading, because anything past the glass on the low side flies home. Every
  weighing has to be built inside a five-unit window, blind at first, with a
  sun that sets. Weights reach 12 over ten cups.
- Readable: the bales wear a red coil and a brass cap on Insane only; the
  first toast says it (`BAL_TIP_BOING`), the rules say it, and each bounce
  says "Boing!" with straw flying.
- Fair: the generator only deals an Insane day whose answer can be placed
  one fruit at a time without a bounce (`Gen.safe_order`: after each
  placement the beam reads within 5, or nothing placed and loose sits on its
  low side). When a unique board has no such order it is usually one pin
  from one, and a pin more never makes the answer less unique, so a pin is
  added (never below four loose fruit) before the board is thrown away.
- Reference: Shasha's "Seesaw Gold" drops weights off a tilting seesaw's end
  and the 1997 game *Swing* flings a ball across the field; neither hides
  the weights, and here the bounce is also what bounds the weighing.
- Cost: Insane generation now averages ~70 ms on this Mac (worst ~245 ms
  over 60 seeds, was 29 ms); bands 0-2 draw exactly what they did.

## 3. Motion

- **Aim**: the cup a held fruit would drop into glows under it, pulsing.
- **Glances**: the basket's fruit watch a fruit in the hand; fruit on the
  plank near a landing turn to look at it (`Face.look`).
- **The bounce**: a hop 2.3x as high, 1.7x as long, with one or two flips;
  the bale squashes and springs back (`_bale_scale`); dizzy stars circle the
  bounced fruit in the basket and they sway for a while.
- **Sunset**: the sun walks down and warms to orange; the dusk wash and
  twinkling stars fade in; tapping the sun makes it giggle and wobble.
- **Sim fix**: a beam lying on a bale under a heavy load thudded on every
  1/120 s step (one step's push was more than the "knock" threshold), and
  each thud jolted the seated fruit upward: on an Insane day with a heavy
  pinned side the pinned fruit floated a couple of cups over the plank and
  the beam never read as calm. A beam already on its stop is now resting
  contact.

## 4. Rewards, even silly

- **Nice toss!**: a fruit let go fast from 1.6+ cups away that lands in its
  cup puts on sunglasses; a third toss in a row is a **Trick shot!**.
- **Party**: after the solve's hops, a party hat pops onto every fruit from
  the middle out, with confetti.
- **The stamp**: the shared seal (`ui/flat/seal.gd`) drops onto the empty
  basket, worded by moves beyond one a loose fruit: Mind reader (0), Sharp
  eye (3), Steady hands (7), Well weighed (12), Got there!; Second wind after
  One more hour. On Insane the night seal with "Boing Bales". The share text
  gains `🏅 <word>` / `🌙 Boing Bales · <word>`; `completion_record()` keeps
  the word for a reopened daily.
- **The reveal**: every fruit's weight swings down on a paper tag under its
  cup, from the middle out -- at the solve and after Show the answer.
- The existing Closer!/Level!/Balanced! run stays; a bounce resets it.

## 5. Sound

Re-prompted toward felt and kalimba: `step` (a fruit seating), `refused`
(was a wooden "bonk"), `thud` (cushioned). New: `boing` (cartoon spring),
`sunset` (music-box lullaby), `hour_back`, `sun_low`, `toss`, `giggle`,
`reveal`, `stamp`, `party`, `confetti`. Not yet judged by ear.

## 6. Verification

No new permanent tests (MVP). Suite green; `tests/_win.gd -- balance`
passes; a throwaway probe drove Hard to sunset (card up, Reset/Undo off),
One more hour (+4, card gone), a second sunset (no video offered), Show the
answer (done, unsolved, tags); an Insane bounce; an Insane solve along
`safe_order()` with the night stamp and record. `tests/_shot_anim.gd --
balance` gains `sunset` (d=2) and `boing` (d=3). Draw calls on
`opengl3_angle` at 810x1440: Hard at rest 109, Insane at rest 91, the
reduce-motion sunset 124, the solve's peak 240. Far under 855.

## Review fixes (2026-09-29)

An independent review of the branch found, and this pass fixed:

- A fruit held while Undo, Hint or Reset ran stayed HELD in the sim, so the
  beam never came to rest and the sunset card never opened (a soft lock).
  `_drop_held()` sends it back where the rules say first.
- Video hints on Hard went around the sun; they now cost a step, and the
  bulb leaves the bar once the sun is down (no video for nothing).
- `out_of_hearts` reads true from the step that spent the last of the sun,
  so the host's Back in the moments before the card counts as a loss, not
  an abandon. The card itself is `_out_card`.
- The stamp's baseline leaves out hinted fruit and counts a hint as a step;
  a daily solved before stamps restores with no stamp; a finished day hides
  the pill; a fling back into a fruit's own cup is not a toss; the stars
  rebuild ten times a second, not every frame; the low-sun pulse keeps the
  pill redrawing.
- Known and left: a lost day is not saved, so reopening it deals it fresh
  with a full sun -- Code Break has the same gap; it needs the host to keep
  an unsolved ending per day, which is its own change.
