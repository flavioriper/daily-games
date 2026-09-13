# Family D — Perception & Pattern (49-56)

Fast rounds, 15-45 seconds. These test seeing rather than reasoning. None of them can
carry a session alone; all of them are useful as a warm-up (round 1) or a palate
cleanser between heavy rounds. Because they're quick, they're also where *timing*
becomes part of scoring, which changes the feel of the whole product — decide that
deliberately.

---

## 49. Odd one out

**Rules.** One tile is different. Tap it.
**Params.** Grid size, difference type (colour, rotation, size, a missing detail), difference magnitude.
**Generator.** Render N identical tiles, perturb one by a controlled delta. Difficulty is that delta, which gives you a perfectly smooth continuous difficulty dial — rare and valuable.
**Uniqueness.** Exact by construction — you know which tile you changed.
**Touch.** One tap.
**Round.** 5-15s.
**Share.** Time only.
**Risk.** Trivial to build and genuinely satisfying as an opener. Zero depth — it is a reaction test wearing a puzzle costume, and players will call that out if it's weighted equally in scoring. Also, difficulty depends on screen size, brightness, and eyesight, which makes leaderboard comparison less fair than it looks.

## 50. Off-shade colour spot

**Rules.** One square is a slightly different shade. Tap it.
**Params.** Grid size, shade delta in a perceptual colour space.
**Generator.** Pick a base colour, offset one tile by a delta measured in CIELAB (not RGB — RGB deltas are perceptually uneven and produce wildly inconsistent difficulty).
**Uniqueness.** Exact by construction.
**Touch.** One tap.
**Round.** 5-15s.
**Share.** Time.
**Risk.** This one is an accessibility failure by design. Roughly 8% of men have some colour vision deficiency, and for a portion of them the puzzle is not merely harder but *impossible* — and it fails differently depending on which deficiency they have, so you can't compensate. It also fails on cheap screens and in bright sun. Recommend against including it at all, rather than trying to patch it.

## 51. Symmetry completion

**Rules.** Complete the picture so it's symmetrical.
**Params.** Grid size, symmetry axis (vertical, horizontal, diagonal, rotational), how much is pre-filled.
**Generator.** Generate a random pattern, mirror it under the chosen symmetry, then erase one half.
**Uniqueness.** Exact and immediate — the symmetry rule determines every erased cell.
**Touch.** Tap cells to fill.
**Round.** 20-45s.
**Share.** The completed pattern is a two-colour grid. Shares well.
**Risk.** Very low. Rotational symmetry is meaningfully harder than mirror symmetry, which gives you a difficulty step without a new mechanic. Honest limitation: once the player understands the axis it's mechanical copying rather than thinking, so keep it short.

## 52. Rotation matching

**Rules.** Which of these is the same shape, just rotated?
**Params.** Choice count, rotation angles, whether reflections appear among the decoys.
**Generator.** Generate an asymmetric shape, rotate it for the answer, and generate decoys by reflecting it or perturbing it slightly.
**Uniqueness.** Exact. Reflected decoys are the good ones — telling rotation from reflection is the actual mental operation being tested.
**Touch.** Tap to choose.
**Round.** 15-30s.
**Share.** Correct plus time.
**Risk.** Multiple choice, so guessing yields 25-33%. Like fold-the-net, it correlates hard with innate spatial ability and has a shallow learning curve — players don't get better at it, which undercuts a daily's promise of improvement.

## 53. Raven's-style matrix

**Rules.** The pattern follows a rule. Which piece completes it?
**Params.** Grid size (usually 3x3), rule count and type (progression, rotation, addition, XOR of features).
**Generator.** Compose feature transformations along rows and columns, render the cells, blank the last, generate decoys by applying wrong transformations.
**Uniqueness.** Formally the same problem as sequence completion (47), though less acute — multiple choice constrains the answer space, so an alternative interpretation usually isn't on offer. Careful decoy design is what keeps it honest.
**Touch.** Tap to choose.
**Round.** 30-60s.
**Share.** Correct plus time.
**Risk.** This is literally an IQ test item, and it will read that way to players — which is either a feature (people enjoy feeling measured) or a liability (people dislike feeling judged), and it's worth deciding which brand you want. Ambiguity complaints are a real if manageable risk.

## 54. Flash sequence recall (Simon)

**Rules.** Watch the sequence. Repeat it.
**Params.** Sequence length, flash speed, element count, whether the sequence grows across attempts.
**Generator.** Random sequence. Trivial.
**Uniqueness.** Not applicable.
**Touch.** Tap in order.
**Round.** 20-40s.
**Share.** Longest sequence reached. Compares cleanly across players.
**Risk.** This is memory, not deduction — a genuinely different muscle, which is good for variety within a set. But it's also *not a puzzle*: there's nothing to work out, and failure feels arbitrary rather than instructive. Also the one entry here that's strictly worse for older players, which is a real consideration given puzzle-game demographics.

## 55. Hidden shape in noise

**Rules.** There's a shape in there. Find it.
**Params.** Noise density, shape size, contrast between shape and background.
**Generator.** Render noise, embed a shape at controlled contrast. Contrast is the difficulty dial.
**Uniqueness.** Exact by construction.
**Touch.** Tap or trace the shape.
**Round.** 15-45s.
**Share.** Time.
**Risk.** Art-cost heavy if you want it to look good rather than look like television static, and it shares entry 50's problems — depends on screen quality, brightness, and eyesight rather than skill.

## 56. Glyph scan

**Rules.** Tap every X in the grid. There are N of them.
**Params.** Grid size, target count, how similar the distractors are to the target.
**Generator.** Fill with distractors, place N targets. Distractor similarity is the difficulty dial (an O among Qs is hard; an O among Xs is free).
**Uniqueness.** Exact.
**Touch.** Multiple taps, ideally drag-to-select multiple.
**Round.** 20-40s.
**Share.** Time and accuracy.
**Risk.** Shallow, and it's a speed test rather than a puzzle. Useful mainly as a timed tiebreaker or a "wake up your eyes" opener. Do not let it carry score weight. Using letter glyphs re-introduces a mild script dependency — prefer abstract symbols.
