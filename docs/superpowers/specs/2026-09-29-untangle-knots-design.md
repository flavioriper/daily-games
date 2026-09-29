# Untangle: knots, over and under

2026-09-29, the evening pass. Built unattended at the user's word, the same
prompt as the afternoon's ring rebuild with the reference reel again and one
correction: "the untangle come from the nots (that form by passing a cord
over the other), that's why it's important to wire it with a realistic
phisic to the nots". The afternoon build (`2026-09-29-untangle-ring-design.md`)
had the ring, the pegs, the rope, the thread and the kitten, but its rule was
"two ropes cross when their pegs interleave": over and under were only drawn.
This pass makes them the rule. Everything in the ring spec not contradicted
here still stands (reach, thread, the out card, the kitten, the seal).
Built on `feat/untangle-knots`; no concept tab (unattended, as the afternoon).

## 1. The rule

Each pair of ropes keeps **how many times it crosses** (`n`) and **which lies
on top** at each end of that run (a twisted pair's crossings alternate over
and under along each rope, so one bit and the ring say the rest).

A move lifts a peg and carries it **over the top** of everything to an empty
hole. For every rope whose line it passes over:

- if the moved rope lay **on top** at its crossing nearest the moved end, the
  cord slides off: that crossing is gone (`n - 1`);
- if it lay **under**, the cord comes round over the top: the two are wrapped
  once more (`n + 1`).

So lifting the cord on top untangles, and pulling the one underneath knots it
tighter. `n` is odd exactly when the pegs interleave (the old rule is the
parity of the new one; tested over random walks). Two ropes can be wrapped
round each other (`n = 2`) with their pegs side by side and no chord crossing
at all: that is a knot, and it takes the top rope lifted, then the other.
Solved: no pair crosses.

`puzzles/untangle_gen.gd: apply(at, tw, ropes, peg, hole)` is the whole rule,
on plain int arrays: `tw[pair] = n * 2 + t`, `t` the lower rope's side at its
end-0 crossing. Which end of the other rope meets that crossing is read off the
ring when it matters (an even `n`: the only non-crossing way to pair the four
pegs). **A move made back undoes a move exactly** (`at` and `tw` both), which
is what keeps the dealer's construction (walk away from a solved ring, answer =
the walk backwards) and the kitten's backwards deal working unchanged.

## 2. The rope

Physically each rope is still a Verlet chain (`untangle_rope.gd`, 37 points).
What changed:

- **Braids.** A pair wrapped twice or more shares a braid: a short stretch
  where both run along one line, `n * 1.6` rope widths long, placed where two
  ropes pulled tight round each other meet (the point nearest all four pegs:
  the ropes' crossing when the pegs interleave, the crossing of the diagonals
  of the four pegs when they sit side by side), kept inside the ring's cloth.
- **The way.** A wrapped rope runs straight from its peg into its first
  braid, along it, straight on to the next, and to its other peg; the chain is
  held to that way firmly along a braid and gently along the legs, its rest
  length is the way's, and a held point keeps less speed. So a wrap pulls both
  ropes in, a new one cinches, one let go springs apart, and a kicked rope still
  whips.
- **The twist is drawn, not simulated**: on the drawn line (a Catmull-Rom of
  the chain, three pieces a span where it bends or twists, one where it runs
  straight), each rope swings to its side of the braid's line and back,
  `cos(pi * n * u)`, so the two cross exactly `n` times. While a braid cinches
  or lets go its twist turns (`BRAID_SPIN`), so an unwind reads as a spin.
- **Over and under.** Every crossing is found on the drawn lines
  (`Rope.hits`: coarse boxes on the chains, exact only on the drawn pieces
  inside overlapping ones) and given its top from the tangle. The ropes are
  drawn in an order that puts the most-often-under first; wherever a rope
  drawn earlier is on top, a short piece of it is laid back over the other
  (`_build_patches`), reaching halfway to the pair's next crossing so it never
  ends where the other still lies over it, with a small shadow onto the rope
  beneath. The rope in the hand is drawn last.
- **The look**: one ribbon per rope whose colour runs across it (dark rim,
  light on its back, shade on the far side) -- a round cord -- with slanted
  strand seams and their lit ridges, laid by length so a patch matches the rope
  under it; a two-band soft shadow. Colours stay one per rope with a matching
  inlay in both pegs (the reference's cream and yellow are two of them).
- **Quiet.** A rope at rest sleeps. Three ropes wrapped round one another can
  pull in a circle; after 1.2 s with nothing touching the ring a rope still
  moving is damped down to rest (`QUIET_AFTER`).

## 3. Bands, measured

| band | holes | ropes | walk | par | most crossings | pairs wrapped | wraps per pair | thread |
|---|---|---|---|---|---|---|---|---|
| Easy | 10 | 4 | 3 | 3 | 6 | 0 | 1 | - |
| Medium | 13 | 6 | 5 | 5 | 10 | 1 | 2 | - |
| Hard | 17 | 8 | 6 | 6 | 13 | 2 | 2 | par + 4 |
| Insane | 19 | 9 | 8 | 8 | 16 | 3 | 3 | par + 3, kitten |

No dealt rope is wrapped round more than two others (`WRAPS_PER_ROPE`): more
and the picture is a snarl. Par is the walk backwards or the beam search's
answer if shorter (it never was in the samples: the knots make the walk hard
to beat).

How hard, measured on 16 boards a band with a narrow beam search standing in
for a careful player (width 2, 4 and 8, depth = the thread): Hard is solved
inside the thread 11/16 at every width; Insane 0/16, 1/16 and 4/16. A greedy
"fewest crossings next" player does much worse: it often never finishes at all,
because undoing a wrap means crossing more first. Before the caps (walks of 7
and 9 on Hard and Insane, par + 3 and + 2) Hard was 4-10/16 and Insane 0-2/16
with 20-40 crossings on the ring -- unreadable as well as unfair.

Generation: Easy 3 ms, Medium 7-14, Hard 23-42, Insane 60-120 on this Mac. A
hint from two random moves off the answer: under 25 ms to Hard, 20-51 ms on
Insane, and every one found a move (a hint without the kitten falls back to
taking the last move back, which is always a step toward the start).

## 4. What the player sees of the rule

- Hovering a hole with a peg in the hand shows what the drop would do: **"-2"
  in green** for crossings it undoes, **"+1" in coral** for ones it makes, and
  a little loop beside it when it would wrap a pair tighter
  (`State.preview`, `_draw_preview`). This is where the rule is learned.
- The crossing marks are now **soft coral halos under the ropes** (not beads
  over them), so they never hide which rope is on top.
- Tips: "Lift the rope that lies on top. Moving the one underneath wraps it
  tighter." and "Two ropes twisted together need the top one lifted, turn by
  turn." The rules sheet says so, and the tutorial's lesson now shows the top
  cord (with rims, so over and under read) lifted off: "Lift the rope on top and
  it slides off". Level lines: Easy "4 ropes · over and under", Medium "6
  ropes · twisted pairs".

## 5. Rewards added

- **Unwound!** when a wrapped pair comes apart: the braid spins loose, hearts
  puff from where it was, a green ring, the `unwind` cue.
- **Free rope!** when a rope is left with nothing crossing it: it does a happy
  wiggle, both its pegs grin for a second, sparkles run along it, the `free`
  cue.
- **Wrapped!** (coral, sinking) and the `cinch` creak when a move wraps a pair
  tighter.
- Everything from the ring spec stays (Double untie ... Wowza wool!, Yarn
  streak!, One to go!, Oopsie tangled!, the solve's glow, grins, party hats,
  confetti and seal).

## 6. Sound

Measured, not heard (the user was away): per cue the spectral centroid, the
share of energy above 6 kHz, the attack and the levels, against the Balance
set as the cozy reference. `enter` -- the board's first sound -- was 94% above
6 kHz (hiss), and `pick`, `put`, `taut`, `stitch` and `reset` 30-60%.
`tools/gen_sfx.py` gained `"warm:<Hz>"` (two low-pass poles, a high shelf, a
4 ms ease-in); those five are warmed from their cached takes (now 1-4% above
6 kHz), `enter` is re-prompted as low marimba ticks, `confetti` is softened,
and `cinch`, `unwind` and `free` are new. The user names any to redo.

## 7. Cost

This Mac, 810x1440, `opengl3`, the harness's own readings: Insane idle 4.2 ms,
carrying a peg 8-9 ms (the ring build: 3.6-3.9 / 5.7-6.9), draw calls 99-126
at rest and up to 181 carrying, far under 855. Where it went: crossing search
and patches, and a rope mesh per moving rope (about 0.6 ms each). Taken back
on the way: the ribbon in place of four strokes (a full rebuild 16 ms -> 9),
two-stage crossing search (3 ms -> 1.1), the thread row and the yarn cached
until they change (1.5 ms -> 0.3), braids laid out only when a peg or a braid
moved, adaptive smoothing. Not run on a phone or ANGLE.

## 8. Open

- A rope wrapped round three or more others at once (the player can make it)
  draws as a busy zig-zag; it settles, it reads, it is not pretty.
- The kitten is still Insane's one look and her swats are full moves over the
  top, so she wraps ropes as readily as she frees them -- on purpose.
- Carrying a peg on Insane costs about 2 ms more than the ring build did; a
  phone reading is owed.
