# Binairo: hearts, the fibbing sign, motion, rewards, cozy sound

2026-09-29. Sections 1 and 2 were approved in chat; the user asked for the
rest to be built unattended ("build everything"), so sections 3 and 4 are the
agent's own and open to review after the fact.

## 1. Hearts, Insane and the fibbing sign

**Hearts (Hard = difficulty 2: 3 hearts; Insane = 3: 1 heart).** Easy and
Medium unchanged (no hearts, Check stays).

- A free tile placed against the solution costs a heart at once. Clearing a
  tile never costs. The tile cracks, its face yelps (WORRIED + a jolt), and it
  empties itself after a beat, so a wrong symbol never stays on the board.
  The emptying goes through the state without a history entry and without a
  move.
- Hearts are drawn in code as a row of small hearts (one mesh) in the board's
  status area.
- `capabilities()` drops `check` on Hard and Insane; Insane also drops `hint`
  and `undo`.
- Last heart gone: faces go SLEEPY along the diagonal, tiles sag 4 px, an
  "Out of hearts" card shows with **Try again** (same board, full hearts,
  clock and streak restart) and **One more heart** (a rewarded video, once a
  board, asked never pushed; the same Ads path the hint video uses; hidden
  when no ad is ready or the player has remove-ads -- a remove-ads player
  gets the heart without a video). Leaving from the card calls
  `finish_unsolved()` so the host logs `puzzle_complete {solved:false}`.

**Insane board.** 10x10, stripped to minimal clues, 12 signs, **exactly one
sign lies**. No hints, no undo, one heart. The liar looks like the rest and
its badge never turns red during play (no sign on Insane shows broken while
the liar is hidden -- a red badge would name it). At the solve it is
unmasked: blush, glyph flips (= to x or back), a sheepish "caught you!" face.

**Generator.** A lying "=" is an "x". A board is valid when keeping every sign
true gives 0 solutions, and the sum over each sign i of solve_count(signs with
i flipped) is exactly 1. The liar index is the i that gave it. Too slow for
the 194 ms live gate, so it is mined by `tools/mine_insane.gd` into
`content/insane/binairo.json` and read through `core/insane_bank.gd`. With no
bank, Insane falls back to Hard's live row with no liar (hearts still 1).

**Data contract** (shared by generator, state, board):
- A generated/bank board dict gains `"liar": int` -- index into `signs`, -1
  when none. `signs` holds the signs *as shown* (the liar's shown kind is
  the false one).
- `State.liar: int`. `State.sign_broken(i)` is false for every sign while a
  liar is set and the board is unsolved. `State.is_wrong(r, c)` compares
  with the solution. `State.unmask_liar()` returns the index.
- `State` legality (`bad_lines`/`signs_ok`) treats the liar as its true kind.

## 2. Motion and rewards

Everything through `core/motion.gd`; reduce-motion keeps state changes and
drops decoration.

- **Flip**: a symbol change turns the tile like a coin (scale.x to 0, face
  swapped at the edge, back with overshoot), ~0.24 s, replacing pop-out/pop-in.
- **Glance**: faces within two tiles look toward a tapped tile for ~0.6 s.
- **Eased blush**: sine-eased blush and heartbeat; a hinted tile warms into
  the given sand instead of snapping.
- **Wrong tile**: crack line, shiver, face jolt, eject with drop-and-fade;
  the status heart splits and its halves fall.
- **Out of hearts**: diagonal yawns, 4 px sag, then the card.
- **Combo streak**: correct placements in a row; from 3 a paper "x3" bubble
  by the tile; `place` cue pitch climbs a pentatonic step per streak, capped
  at x8; confetti of mini suns and moons at 5 and 10 (`Fx2D.confetti()`,
  a CPUParticles2D like the others). A lost heart ends it with a deflate.
  Undo and hint do not count toward it.
- **Silly line moments**: a completed row/column plays one of: suns slide on
  sunglasses, a moon sneezes stars, the line leans into a high-five wave.
  Chosen by a hash of the completing cell. Accessories are a temporary face
  layer, ~1.2 s.
- **Flawless stamp**: solved with no heart lost and no hint -> gold
  "Flawless" stamp drops, squashes, rings. On Insane a crescent "Insane" seal.
  The share glyphs gain a marker line.
- **Solve party**: the existing diagonal wave, then party hats, confetti, a
  big sun and moon sliding in for an eclipse hug at the centre. On Insane the
  liar is caught first.
- **Budget**: 10x10 = 100 tiles + faces. Measure on `opengl3_angle` first;
  if over 855, bake tiles and tints into one mesh like the Signs layer.

## 3. Sound

The set stays soft wood, kalimba, marimba, glockenspiel, paper; up is good,
down is not yet; never a buzzer (`docs/art/sound-direction.md`). Re-prompt the
cues that read least cozy (`blush_in`'s "bonk", `check`) toward muffled felt
and kalimba, and add:

| cue | idea |
|---|---|
| `heart_lost` | a soft felt-mallet two-note fall, a little "oh" |
| `out_of_hearts` | a sleepy three-note music-box lullaby descending, a yawn |
| `heart_back` | a warm rising kalimba pair |
| `combo` | one bright kalimba pluck; pitched per streak step by `cue(pitch)` |
| `confetti` | a paper-confetti flutter with a tiny glockenspiel twinkle |
| `line_silly` | a playful slide-whistle-free boing on soft wood |
| `flawless` | a paper stamp thump then a warm glockenspiel chime |
| `liar` | a sneaky tiptoe pizzicato, caught red-handed, cheeky |
| `party` | a cozy celebratory kalimba and glockenspiel flourish with a soft party blower |

One take each; the user names redos.

## 4. Verification

No new permanent tests (MVP). Parse checks with `--check-only`, the existing
suite and win harness stay green, throwaway self-driven probes for: a mined
board has exactly one (grid, liar) solution; a wrong tap costs a heart and
empties the tile; the third heart on Hard opens the card; Try again restores
hearts; Insane hides the liar until solve; draw calls at 10x10 on
`opengl3_angle` under 855. Screenshots of the new moments.
