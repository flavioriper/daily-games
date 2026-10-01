# Marigold polish: hearts, Sweethearts, sillier rewards and the pond's sound

2026-10-01, built unattended on `feat/marigold-polish` at the user's word
("let's polish the marigolds game, add more smooth animations, reinforce
that the sfx sounds are really cozy, add more visual rewards even if silly
to the user to keep engagement, and make sure the insane difficulty is
really insane, with something totally new (something only us do) that make
the game nearly impossible, user can also fail on insane and hard ... also
don't worry if you need to redo something on the logic or design, as long
as it keep the cozy vibe").

Super Slider's, Knight's and Hedgehogs' passes the same day are the pattern
for hearts, dusk and the card, the streak, the gags, the party and the seal.
The board's own spec (`2026-09-26-marigold-flat-design.md` and its three
amendments) stands except where this says otherwise. The calls at the end
are for the user.

## 1. Bands

| band | marigolds | seeds | hints | hearts | the cost |
|---|---|---|---|---|---|
| Easy | 12 | 10 | 3 | - | - (the garden grows back, free) |
| Medium | 18 | 10 | 3 | - | - |
| Hard | 25 | 10 | **2** | **3** | running out of seeds; Reset after a seed has flown |
| Insane | **Sweethearts**, 12 pairs | 8 | **0** | **2** | the same |

`State.HINTS_BY` / `HEARTS_BY`. On Hard and Insane a garden run out of
seeds costs a heart: the heart splits and falls off its sign, the toast says
how many are left (`MG_OUT_HEART[_ONE]`), and the garden grows back as
before. Reset (the host's) once a seed of this try has flown costs one too
(`MG_RESET_HEART[_ONE]`): otherwise Reset would be a free fresh garden.
Reset waits while a seed is out (`can_reset()`, `busy()`). Out of hearts:
the sun nods off (SLEEPY), dusk falls, the card (`MG_OUT_BODY` /
`MG_OUT_REST`) -- Try again (the garden as dealt, hearts full, tries, clock
and moves from zero; hints spent stay spent), One more heart (a video, once;
the garden grows back), Back.

The hearts hang on **a little wooden sign off the arch**, left of the sun
(`SIGN_AT`): the HUD band was full (trough, score, tag, pips).

## 2. Insane: Sweethearts

**The marigolds come in pairs tied by a ribbon. A marigold stays in bloom
only if its sweetheart blooms in the same shot; one that blooms alone folds
back into a bud when the shot ends.**

- **Why it is ours**: checked 2026-10-01 against the reference and its
  sequels and spin-offs (special pegs: green powers, purple bonus, armoured
  two-hit pegs, bumpers, bombs, hatching eggs). Every peg in the family is
  scored on its own; none ties two pegs together, and none takes a hit back.
- **Why it is nearly impossible**: 24 marigolds, 8 seeds, so a try needs a
  pair and a half a shot, and the pairs are tied far apart (at least
  `APART` 22 units, often across the garden). A shot that opens one end and
  misses the other gives nothing but bluebells, and those are gone. No
  hints, two hearts. Measured on the probe: a bot that knows the physics
  exactly (the hint's 65-angle search, every shot) clears about half the
  gardens in two tries; a person aims with a 30-unit guide.
- **Fair, always**: the gardens are mined. `tools/mine_marigold_sweethearts.gd`
  deals an Insane garden with every bud a bluebell (the clover kept), then
  plays six shots from the opening: each sweeps 97 angles, takes one of the
  better ones, and ties two pairs out of what that shot bloomed (the two
  farthest apart, then the next two). So **every pair can be bloomed
  together from the opening**, and `proof`'s six shots bloom them all. Each
  entry is read back through `State.from_bank` and replayed before it is
  kept; `tests/_probe_marigold.gd` replays all 160 from the shipped file
  (`bad=0`). `tools/merge_marigold_sweethearts.py` keeps the 160 gardens
  with the fewest `openers` (opening shots that bloom any pair, 4 to 17 of
  65). The proof plays only from the opening and only with the pot where
  the miner had it; after a lonely shot the garden has changed, which is
  the point.
- **Never mirrored**: a shot is chaotic, and a mirrored garden's float
  rounding (and the crown nudge's and clover's `i % 2`) lost every proof.
  Positions ship at nine significant digits, exact for the phone's float32;
  rounding to a thousandth lost proofs too.
- **The rule in the state**: `_hit` counts a marigold as bloomed at once
  (the multiplier and the last marigold's approach work as before);
  `end_shot` folds back every marigold of `shot_bloomed` whose sweetheart is
  still UP -- an unstuck one too -- and gives back its share. The last
  marigold always completes its pair, so the full bloom is unchanged.
- **The look**: each pair has a ribbon in one of six colours, sagging
  between them under the buds, and a collar in the same colour round each
  end, so a pair is told at a glance. While one end is open in a shot its
  ribbon brightens and a little heart beats over it; when its sweetheart
  opens the ribbon goes gold, love hearts rise off both and `MG_PAIR`
  ("Sweethearts!") or Double!/Triple! by pairs. A lonely one droops and
  shuts (`FOLD_TIME`), its pip empties with a puff, `MG_APART` ("Apart!")
  and, the first time, the toast `MG_APART_TIP`.
- `MG_LVL_3` "Sweethearts: marigolds bloom only in pairs"; tips
  `MG_TIP_SWEET`, `MG_TIP_SWEET_PLAN`, `MG_TIP_SWEET_HEARTS`; rules
  `MG_RULES_SWEET`. A solve shares `💞 Sweethearts[ · Flawless]` and stamps
  the night seal. Without the bank Insane deals the old band 3 garden.

## 3. Rewards, even silly

- **The frog** on the left lily pad: eyes on top following the seed,
  blinks, a smile; it croaks at a seed that drains (`ribbit`, throat
  puffing), hops on a Caught! and on every shot word, and turns a
  somersault from Flower-ful! and at the party, landing with a splash ring.
- **The ducks**: a duck and three ducklings paddle across the pond
  (`quack`) after a shot of 10 blooms, in the full bloom and at the party.
- **The sun's sunglasses** drop on (`shades`) from Petal power! (15 blooms)
  for `SHADES_STAY`, and stay through the full bloom and the win.
- **The streak**: shots in a row that keep a marigold (a pair on Insane):
  "N in a row!" from the second, a note up the scale, confetti from the
  third.
- **The party** after the win: confetti, the frog's somersault, the ducks,
  the nap cat hopping in from the right onto the right lily pad and curling
  up (`purr`), garden wisdom (`MG_CHEER_0..9`), and the seal: gold for
  Flawless (no hint, and no heart lost on Hard and Insane or the first try
  on Easy and Medium), night for any Sweethearts. The rain carries hearts
  on a Sweethearts win. `completion_record()` keeps `hearts` and
  `flawless`.

## 4. Smoother motion

The spout follows the finger at `AIM_RATE` instead of jumping; buds a seed
brushes past without touching shiver (`RUSTLE_TIME`, one strip rebuilt);
open blooms breathe while the seed is out; a lonely marigold droops and
shuts, then pops back up as a bud; the hearts split and fall, and pop back.
All of it off under reduce motion (the fold is then instant).

## 5. Sound

Two new styles in `tools/gen_sfx.py`: **POND** -- close-mic foley of a real
garden by a pond (seeds, clay pots, leaves, water), "no synth, no electronic
tones, no beeps" -- and **POND_TUNE** -- a real kalimba, wooden music box
and hand bells recorded close. Every cue rolled off above 7 kHz. All 18 old
cues taken again (the house marimba and glockenspiel are gone; `hit` is now
one kalimba note, checked to be a single onset at ~370 Hz since it is
pitched up the scale) and 14 new: `heart_lost`, `out_of_hearts`,
`heart_back`, `pair`, `apart`, `combo`, `confetti`, `ribbit`, `splash`,
`quack`, `shades`, `stamp`, `party`, `purr`. `wall` and `pop` came back as
two or three ticks in four takes running, so a new `cut:<s>` flag keeps
only a take's first transient. `music.ogg` (Ode to Joy, synthesised) is
unchanged. Rendered mostly on the fallback key; **unheard** by a person.

## 6. Numbers

`tests/_shot_marigold.gd` at `--resolution 810x1440 --always-on-top`,
windowed, one at a time, peak draw calls from 0.5 s:

| mode | band | peak |
|---|---|---|
| rest | Hard | 92 (78 before: the sign, the frog) |
| shot (a 25-bloom shot) | Hard | 178 |
| sweet (proof shot, then a lonely one) | Insane | 165; 166 on ANGLE; 161 reduce motion |
| out (dusk, card, Try again) | Hard | 113-130 |
| reset (a heart) | Hard | 154 |
| gags | Easy | 163 |
| solve, full bloom and party | Medium | 224 |
| restore | Insane | 129 |

Peak 224, 631 under the 855 budget. The suite `passed=122403 failed=0`;
`tests/_probe_marigold.gd` solves every band's days with the hint's aim and
replays all 160 Insane proofs (`bad=0`). `tests/_win.gd -- marigold` FAILs,
as it does on `main` before this branch: it has no way to aim a seed.

## 7. Bugs fixed on the way

- **Restore**: a reopened, solved day under 100 s after launch showed the
  sun not joyful (`_solved_at` pushed negative; Super Slider's and
  Sunbeam's bug). `_won` says it now. A restored day also cheered "Points
  x10!" as it opened (the tag stepped from x1); it starts at x10 now.
- **The shot word** was never reset between shots (`_word_tier` only on a
  new try), so after one long shot the words never came again that try.

## 8. Calls for the user

- **Insane is Sweethearts.** Considered: a pond that rises a row of buds
  each shot (drowned marigolds lost) -- gravity already carries seeds low,
  so it was neither new enough nor nearly impossible; buds that only show
  near the seed's light -- unfair, and blind aiming is not fun.
- **Hard's heart is a whole garden**, since running out of seeds is the
  only way to lose in this genre. Three hearts against a garden the hint
  clears in ~6 shots of 10 can still be lost by a player, rarely.
- **Reset costs a heart** on Hard and Insane once a seed has flown.
- **The proof is from the opening only** and assumes the pot where the
  miner had it (a caught seed changes the count, not the blooms).
- The look (ribbons, frog, ducks, sunglasses, cat on the lily pad) was
  judged on stills. Sounds unheard.
