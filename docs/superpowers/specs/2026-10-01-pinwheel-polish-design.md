# Pinwheel polish: snags, Ribbons, rewards, motion and sound

2026-10-01, built unattended on `feat/pinwheel-polish` (worktree
`../daily-pinwheel`, because sibling polish sessions commit to the main
checkout the same days) at the user's word ("let's polish the pinwheel game,
add more smooth animations, reinforce that the sfx sounds are really cozy,
add more visual rewards even if silly to the user to keep engagement, and
make sure the insane difficulty is really insane, with something totally new
(something only us do) that make the game nearly impossible, user can also
fail on insane and hard ... don't worry if you need to redo something on the
logic or design, as long as it keep the cozy vibe").

Fairy Lights', Quilt's and Paper Planes' passes of 2026-09-30 are the
pattern: the hearts, the dusk and the card, the streak, the gags, the party
and the seal. No concept tab: polish of a built screen with the user away
(Fairy Lights' precedent). The flat spec
(`2026-09-20-pinwheel-flat-design.md`, with its 2026-09-26 amendment) stands
except where this says otherwise. The calls at the end are for the user to
judge on the phone.

## 0. Why it was too easy

Overlap is the working state and nothing is ever judged: the fastest way to
play was to tap every wheel round until the stain cleared, reading nothing.
Nothing could be lost, and Insane was only a bigger frame (7x8, sixteen
pieces) dealt live like the rest.

## 1. Hard and Insane can be failed: snags

A rotation board cannot judge where a piece *lands*: a piece passes through
wrong quarters on its way to its right one. What a player who deduces never
does is **turn a piece that is already home** (Fairy Lights' rule, carried
over). The answer is proved unique, and **every movable piece opens off its
answer**, so a piece is only ever home because the player (or a ribbon) put
it there.

| band | frame | hints | hearts | undo |
|---|---|---|---|---|
| Easy (0) | 5x5, 9 pieces | 3 | - | yes |
| Medium (1) | 5x7, 11 | 3 | - | yes |
| Hard (2) | 6x8, 13 | **1** | **3** | yes |
| Insane (3) | **Ribbons**, 7x8, 16 | **0** | **2** | **no** |

- **A tap on a piece already home** (Hard and Insane, on a proved board):
  the piece starts its quarter, **catches on its own thread** about 24°
  round, strains a moment and springs back home with the back ease's
  overshoot (`snag`, 0.62 s). A heart splits on the paper pill as it catches
  (`heart_lost`), and a **gold button** with a cross of rose thread is sewn
  onto the pin cell's corner (`tack`). The button is for good: the heart
  bought the knowledge, as Mushroom Patch's pebble and Fairy Lights' clip do.
  A sewn piece is refused for free ("That one is sewn down. It's home."), is
  never tugged by a ribbon, and Reset leaves it home; Try again unpicks
  every button. A hint on a judged band sews its piece too.
- Nothing turns, so a snag pushes no history; `tack` drops the sewn piece's
  own entries, so an undo can never turn a proved piece off again.
- Input, Undo, Hint and Reset wait while a snag plays (`busy()`); a piece
  still swinging when it is tapped again is not judged (the player has not
  seen it land).
- **Out of hearts**: the breeze stops, dusk falls (`out_of_hearts`), and
  `ui/hud/out_of_hearts.gd` comes up with `PW_OUT_BODY` / `PW_OUT_REST`.
- Rules close with `PW_RULES_SAFE` (Easy, Medium), `PW_RULES_HEARTS` (Hard)
  or `PW_RULES_RIBBONS` (Insane).

## 2. Insane: Ribbons

**Some pinwheels are tied together with satin ribbons. Turning a pinwheel
tugs every piece tied below it round a quarter too** -- the same way along a
rose ribbon, **the other way** along a crossed blue one -- and on down the
ribbons tied to those. A sewn piece holds still and tugs nothing below it.

- **Why it is ours**: the genre's apps (the original is named once in the
  flat spec, not here) give each piece one pivot and turn one piece a tap;
  checked 2026-10-01 against the genre's published how-to (one pivot a
  piece, "rotate the pieces to fit them within the frame", a score that
  decays with time). Coupled rotation turns up in gear toys; a search the same
  day found it on no pinned polyomino cover. It changes what a tap *is*: a turn is no longer local, so
  "spin it till it looks right" stops working -- spinning a piece at the top
  of a ribbon throws everything below it out again.
- **Why it is nearly impossible**: sixteen pieces, about eight ribbons, a
  third of them crossed; two hearts, no hints, **no undo**; and a snag for
  every piece already home that is touched. The only safe way through is to
  **read the whole tiling first**, then turn the pins **from the top of each
  ribbon down**, never touching a piece once it is home.
- **The deal** (`Gen._ribbon_deal`, live, no bank): grow, pin, prove and
  colour as every band does, then tie the movable pins into a **forest**
  (each piece pulled by at most one ribbon; two a pin at most; three deep at
  most; pins within two king moves; no ribbon crossing another or passing
  within half a cell of a stranger's pin; 45 % of the pieces that could tie
  left untied) and require half the movable pieces tied with a run at least
  three deep. The opening is worked **backwards from the answer**: pick how
  many taps each pin will take on the way home, add every tug from above, and
  start each piece that far back -- kept only when **no movable piece opens
  home**, worth the band's `min_turns` on the top-down route, under
  `max_stack`, tidiest first. A forest's tugs only run downhill, so the
  top-down route always solves it and no search is needed.
- **How it looks**: a satin band pin to pin, bowed a little (an S when
  crossed), two chevrons pointing down it, a knot by the pulling wheel and a
  short curved arrow round the tied wheel saying which way it will turn. A
  tug reaches each piece a ribbon later (0.09 s) and the ribbon goes taut and
  springs back (`tug`). At the party the ribbons slip loose and float up out
  of the frame (`ribbons`).
- Tips lead with `PW_TIP_RIBBON`, `PW_TIP_CROSSED`, `PW_TIP_TOP`,
  `PW_TIP_HEARTS`. `PW_LVL_2` "13 pieces, 6 × 8, three hearts", `PW_LVL_3`
  "Ribbons: 16 pieces, two hearts". A Ribbons solve shares as 🎀.

## 3. Rewards, even silly

- **The streak**: taps in a row that leave the frame tidier (fewer bare or
  doubled squares -- read off the stain, so it reveals nothing the frame does
  not show). A tap that changes nothing is neutral; a messier one, a snag, an
  undo or a reset ends it. `combo` up the pentatonic from the second, the
  "x3" bubble over the pin from the third, confetti at 4, 7 and every 5.
- Each square a tap un-doubles **sparkles** as the stain lifts (three at
  most).
- **A gag** on one tidying tap in four (any twelve taps share the three
  kinds), one at a time: the wheel **whirls** two whole turns in a happy gust
  (`whirl`); **love hearts** float out of the pin (`love`); or a **butterfly**
  flutters in, sits on the wheel opening and closing its wings, and flutters
  off (`flutter`).
- **The party**, after the solve: the breeze through every wheel (the
  existing win gust), confetti twice (`party`), **a kite** with a bowed tail
  swooping across the card (`kite`), on Ribbons the ribbons slipping loose,
  **the nap cat** hopping onto the frame's foot and curling up (`purr`), and
  the sprout sharing **a bit of pinwheel wisdom**, one of twelve
  (`PW_CHEER_0..11`).
- **The seal**: Flawless (no hint, and no snag on Hard and Insane, or no
  undo on Easy and Medium) stamps the gold seal; any Ribbons solve the night
  seal, "Insane" over "Flawless" or "Ribbons". `completion_record()` keeps
  `hearts` and `flawless`; `share_glyphs()` adds `🏅 Flawless` or
  `🎀 Ribbons[ · Flawless]` under the squares. Restore shows the cat asleep,
  the seal and a frame with its ribbons gone.
- `win_delay()` is the party's start plus 3.2 s.

## 4. Motion

New: a **press dip** on the wheel under the finger; **true quarters** on
every swing (an index step over a skipped orientation is two quarters, and
a symmetric piece lands on its own picture early -- the old swing turned one
quarter from a pose the piece was never in); the snag's catch, strain and
spring; the button popping on; the tug's lag down the ribbons and the
ribbon's spring; the heart pill and its split; the dusk; the streak bubble,
the whirl, hearts and butterfly; the kite, the ribbons floating off, the
cat and the seal. Under reduce motion: no gags, confetti or kite, no swing
on a snag (the heart splits and the button is simply there), the ribbons
simply gone, the cat and seal at once.

## 5. Sound

A new style, `LINEN` -- a sewing basket on a breezy porch: soft paper
whirrs, linen and felt, kalimba and a music box. Re-prompted: `place`,
`refused`, `undo` (no more tape rewind), `hint`, `reset`, `enter`, `solved`.
New: `combo`, `confetti`, `whirl`, `love`, `flutter`, `snag`, `heart_lost`,
`tack`, `out_of_hearts`, `heart_back`, `tug`, `stamp`, `party`, `kite`,
`purr`, `ribbons`. Rendered on ElevenLabs on the fallback key (the first was
out of credits); **unheard** by a person.

## 6. Numbers

**The deal** (GDScript on this Mac, a throwaway probe over 30 seeds, two
runs agreeing): an Insane board in **37 ms mean, 102 ms worst** against the
194 ms gate; **7.8 ribbons** a board (2.8 crossed); **28 taps** on the
top-down route; every one of the 30 solved by top-down taps through the
state, and none opened with a movable piece home. (Before thinning: 10.3
ribbons and 47 / 125 ms; it read as a net.)

**The board** (`tests/_shot_pinwheel.gd` at `--resolution 810x1440
--always-on-top`, windowed one at a time, peak draw calls from 0.5 s on,
the second of two readings for rest). This harness opens the board through
`world/main.tscn` with the day card behind it, so its floor is not
`_shot_anim.gd`'s bare-host 56:

| state | band | peak draw calls |
|---|---|---|
| rest | Easy / Medium / Hard / Insane | 80 / 80 / 82 / **76** (ANGLE: 76) |
| snag (catch, split, button) | Hard | 82 (81 under reduce motion) |
| ribbon (one tap tugging three) | Insane | 83 |
| out (three snags, dusk, card, Try again) | Hard | **104** |
| right (streak, whirl, love, butterfly, x3, undo) | Easy | 88 |
| solve and party (kite, ribbons loose, cat, night seal) | Insane | 101 (84 under reduce motion) |
| restore (flawless, a heart gone) | Insane | 84 |

The peak is the out-of-hearts card over Hard at **104**, 751 under the 855
budget. Ribbons cost nothing extra at rest: they are inside the live mesh
with the stain and the wheels. The hearts' strip takes 64 off the top on
Hard and Insane; Hard's cell is 157 (bound by the width), Insane's 134.

Suite `passed=123188 failed=0`; `tests/_win.gd -- pinwheel` winnable 1/1
(Medium, through the HUD's hint); `_shot_pinwheel.gd solve` cleared an
Insane frame through the pins top-down with both hearts kept (flawless,
night seal, `🎀 Ribbons · Flawless`).

## 7. Calls for the user

Decisions the build made while you were away -- each is one constant or a
few lines to change:

- **The judge is Fairy Lights' rule**: turning a piece already home costs a
  heart. It leaks one bit (that piece *was* home) and pays for it with the
  heart; the button makes the bit permanent. Still unconfirmed by you on
  either board.
- **A snag tugs nothing**: the piece never actually turns, so its ribbons
  stay put.
- **A sewn piece stops the ribbon**: it does not move, so nothing tied below
  it is tugged either. That makes a snag on Insane change the puzzle a
  little (the subtree below goes free). The alternative -- a sewn piece that
  still passes the tug down -- is harder to read.
- **No undo on Insane** (as Windy Day); Reset stays and keeps the buttons.
- **The streak counts tidier, not right**: the board never says which piece
  is home, so the streak is read off the stain alone. A tap that only moves
  the mess is neutral.
- Ribbons are about eight a board; they read as a net at ten (the first
  cut). `RIBBON_SKIP`, `RIBBON_SHARE` and `RIBBON_CLEAR` in the generator.
- The heart pill sits just over the frame's rim, not at the top of the card:
  Insane's frame is bound by the width and left a gap.
- Butterfly, kite and button sizes, the snag's 24° and 0.62 s, the tug's
  0.09 s a ribbon -- all judged on stills only.
