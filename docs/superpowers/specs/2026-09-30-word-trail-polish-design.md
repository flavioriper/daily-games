# Word Trail polish: the dandelion, Night Walk, rewards, motion and sound

2026-09-30, built unattended on `feat/word-trail-polish` at the user's word
("let's polish the trail word game, add more smooth animations, reinforce
that the sfx sounds are really cozy, add more visual rewards even if silly
... make sure the insane difficulty is really insane, with something totally
new (something only us do) that make the game nearly impossible, user can
also fail on insane and hard ... don't worry if you need to redo something
on the logic or design, as long as it keep the cozy vibe").

Hidden Word's pass the same day (`2026-09-30-hidden-word-polish-design.md`)
is the pattern: the out card, the stage, the seal, the bubbles, the gags.
No concept tab: polish of a built screen with the user away. The flat spec
(`2026-09-20-word-trail-flat-design.md`) stands except where this says
otherwise. The calls at the end are for the user to judge on the phone.

## 1. Hard and Insane can be failed: the dandelion

Before this pass nothing could be lost: a wrong trail unwound and cost
nothing, so a patient player could try every trail. The flat spec's "the
board never says no" stays true on Easy and Medium.

| band | grid | words | hints | wishes | wrong trail |
|---|---|---|---|---|---|
| Easy (0) | 5x5 | 3-6 | 3 | - | free |
| Medium (1) | 6x6 | 3-7 | 3 | - | free |
| Hard (2) | 7x7 | 4-8 | **1** | **7** | a seed |
| Insane (3) | **8x8, in the dark** | 6-8 | **0** | **5** | a seed |

A board's own hints; a video hint is still offered once they are spent, on
Insane too (the user's call of 2026-09-29, every board).

- **A dandelion clock** stands on the band's right (`State.WISHES`,
  `_dandelion`), a seed per wish. A wrong trail blows one seed off on the
  breeze (`miss`, then `wish`), the head shakes, and the trail's tiles shake
  their heads (`MISS_WOBBLE`). At two left the sprout says "Careful"
  (`wish_low`).
- **Only a trail that could have been a word costs** (`State.could_be`,
  `State.miss`): three tiles or more, as long as some hiding word, and never
  a trail already tried (`tried`, by its cells). A slip, a stray tap or the
  same wrong trail twice is free, and the sprout says so ("You tried that
  one already").
- **Let go off the field** and a wrong trail is put down, never tried, on
  every band (`_off_field`): the way out of a trail without spending a wish,
  and on Insane the way to look around. A right word still locks.
- **Out of wishes**: every tile sags and leans (`DROOP*`, `droop`, a
  lullaby `out_of_wishes`), and Code Break's card (`ui/hud/out_of_rows.gd`,
  this board's `WT_OUT_*` keys, rewarded placement `"wish"`) asks **More
  wishes** (once a board: the tiles perk up and a new head grows three
  seeds, `wish_back`) or **Show the words** (each hiding word locks in turn
  in a paler ribbon, `reveal`, then `lost`, the stage says "Here they were",
  `finish_unsolved()`). `out_of_hearts` is the host's hook, `busy()` holds
  the hint video back, and Undo, Reset and Hint are off while the card is
  up or the words are showing.
- Shown words fill the field but are not a solve: `is_solved()` is false
  with any shown word, and they share as 🟨.
- Misses are counted on every band (only Hard and Insane spend them),
  because the seal reads them.

## 2. Insane: Night Walk

We looked for trail and search word games that hide the field. Hidden-object
games have a "night" mode (find items in a lit circle), and word searches
hide the *word list*. None hides the letters *and the walls* of a trail
field, and none lets finding words light the field back up. So:

- **The field is dark** (`_night_piece`): every cell, wall or tile, is the
  same indigo piece in a night pond with stars where four tiles meet. The
  night tells nothing of the field's shape.
- **A lantern** (Untangle's paper lantern, `LanternFace`) floats up and to
  the left of the finger, so the finger never hides it, and **lights the
  3x3 round it** (`LAMP_REACH`). A press anywhere on the field lights it,
  a wall or a found word included: looking is free. The tiles it leaves
  keep an **afterglow** for `AFTERGLOW` (1.6 s) and fade back into the dark.
- **Every word found is a string of lanterns**: its tiles and all eight
  neighbours of each stay lit for good (`_levels`). The first word is the
  hardest; the night gets easier as it goes.
- **Dawn** on the solve: the pond fades, every tile comes up in a wave from
  the top-left (`dawn`), the lantern floats up and away, then the solve hop
  and the party. Shown words bring the dawn too.
- **Why it is nearly impossible**: the longest six words (6, 7, 8, 8, 8, 8)
  on the biggest field, no hints of its own, five wishes, and a board the player has to
  hold in their head a 3x3 at a time. Solvable by construction as every
  band is. A player with paper can map it; that is the escape valve.
- Rules add `WT_RULES_WISHES` and `WT_RULES_NIGHT`; the tips are per band
  (`TIPS_WISHES`, `TIPS_NIGHT`); `WT_LVL_2` "6 words, 7 × 7, 7 wishes",
  `WT_LVL_3` "Night Walk: 8 × 8 in the dark".

## 3. Rewards, even silly

All of them wait for the word's wave to land.

- **A note up the scale**: every word plucks `combo` a step up the major
  pentatonic, across the game.
- **One bubble a word** (Hidden Word's paper bubble, over the last tile):
  seven letters or more is "Big one!" with confetti along the word; a word
  within six seconds of the last is "Quick!"; three in a row with no
  plausible miss between is "3 in a row!".
- **Gags**, one a word, picked off the word (four in five): **hearts** float
  up off the last tile (`love`), the tiles do a **conga** of two hop waves
  (`conga`), a **butterfly** in the word's colour lifts off and wanders out
  of the card (`flutter`), or the first tile **twirls** a whole turn on a
  hop (`twirl`).
- **The party**, `PARTY_AT` after the solve hop: the tiles **dance**, every
  wall **blooms a flower** in one of the day's colours (they stay), confetti
  twice, and the sprout comes up on the band **in a party hat** beside a
  card with "Every letter found its way." and **a silly cheer** (twelve,
  `WT_CHEER_0..11`, picked by the day's words); `STAMP_AT` later **the seal**
  drops on the card: gold with "Flawless" (no plausible miss), "Sharp eye"
  (1-2), "Right track" (3-5), "Got there!" (6+), "Second wind" (a bought
  wish), or on Insane the night seal with "Night Walk" over it.
- `share_glyphs()` gains `🏅 Flawless` or `🌙 Night Walk · 🏅 Flawless`.
- A restored solve shows the meadow, the stage with the cheer and the seal
  (`completion_record()` keeps the misses and the bought wish for it), and
  on Insane the dawn already up.

## 4. Motion

New, on top of the flat spec's: the tiles pop in on a diagonal cascade
inside the field's wide pop (`CASCADE`); a tile the finger takes hops
(`TAKE_HOP`); a locked word's slot group hops in a wave once its letters
have landed (`SLOT_HOP`); a lifted word's tiles dip as the wave leaves; the
head-shake, the droop and the perk; the gags; the dance and the meadow; the
lantern's glide; the dawn; the stage's rise and the seal's drop. Every cell
has one pose (`_cell_pose`: cascade, perk, droop, dance), and a tile adds
its own on top (`_tile_xf`), with a turn, so a twirling or dancing tile
carries its glyph (`_letter`, Mosaic's recipe with the turn). Under reduce
motion: no cascade, gags, bubbles, droop or dance; flowers stand open, the
seal stands, dawn is instant. The night's afterglow is a rule, not motion,
so it stays.

## 5. Sound

Re-prompted toward felt, paper and kalimba: `select` (quieter, -15),
`place`, `undo`, `hint`, `reset`, `solved`, `enter`. New: `combo`, `streak`,
`big`, `quick`, `love`, `conga`, `flutter`, `twirl`, `miss`, `wish`,
`wish_low`, `droop`, `out_of_wishes`, `wish_back`, `reveal`, `lost`,
`bloom`, `party`, `dance`, `confetti`, `stamp`, `lantern`, `dawn`. Rendered
on the fallback key (the first was out of credits); **unheard**.

## 6. Numbers

Draw-call peaks from `tests/_shot_wordtrail.gd -- d=<n> <mode> [rm]`
(810x1440, `--always-on-top`, `opengl3_angle`), one run each:

| mode | peak |
|---|---|
| rest, Hard (a trail held) | 84 |
| words, Hard (bubbles, gags) | 92 |
| out, Hard (droop, card, new head, shown) | 101 |
| solve, Hard (party, meadow, seal) | 111 |
| night, Insane (lantern, afterglow) | 85 |
| solve, Insane (dawn, party, night seal) | 108 |
| restore, Insane | 85 |
| rest, Easy, reduce motion | 82 |

All far under the 855 budget. Suite: 122778 passed, 0 failed.
`tests/_win.gd -- wordtrail`: PASS.

## 7. Calls for the user

1. **Night Walk on the phone**: whether the indigo reads as night and not as
   a broken board, whether the lantern above-left of the finger is where the
   eye wants it, and whether 1.6 s of afterglow is the right cruelty.
2. **Seven and five wishes** are guesses; a fair player on Hard makes a few
   wrong trails. Only a trail as long as a hiding word counts.
3. **Let go off the field to cancel** is new on every band.
4. **Twelve cheers**: silly on purpose.
5. **Sounds are unheard.**
6. **Review findings, fixed**: an undo or reset left the lifted word's tiles
   frozen mid-dip (the wave's frames stopped before the dip's), and the dip
   went up; letting go just past an edge tile threw a right word away (now a
   right word always locks, and off the field only spares a wrong trail);
   a lock's note, bubble and gag still fired after an undo within half a
   second (a per-word generation, `_lock_gen`, and undo resets the streak);
   Back during Show the words logged an abandon (`out_of_hearts` stays up
   until the reveal ends); the rules sheet read the bought wishes as the
   band's. Left as they are: the harness boots `world/main.tscn`, as
   `_shot_hiddenword.gd` does, so it is not offline.
