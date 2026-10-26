# Gumdrop, made fun to play

2026-10-26. The user: "I want your help to make gumdrop experience way
better to play, and game itself way funnier [more fun] to play, right now
nobody likes it", then "skip questions, feel free to use web". Built on
the user's standing calls; every call below that the brief did not make is
mine and marked so. The board's history is `docs/agents/boards/gumdrop.md`.

## 1. Why nobody likes it

Read off the shots (`tests/_shot_gumdrop.gd`, Medium, 2026-10-26) and the
notes, and matched by what the web says of the genre (store reviews of the
game the first spec names once to forbid, a publisher's case study of a
paint-matching game, and small colour-mixing games' own notes):

1. **The only verb is holding a thumb.** The card is the pots; the chunk
   stops itself at 100%; nothing can be lost; nothing spills. There is no
   decision and no skill, only a wait: ~2.6 s a chunk at the anchor size,
   longer on big chunks, times up to 14 chunks times up to 5 moulds, plus
   3.3 s of settle and show a serve. Players of the genre quit for exactly
   this ("boring in 2 or 1 minute", "u just put colour into jelly",
   "filling takes too many squirts").
2. **The serve reads as a test.** "NEEDS 65% · 1/3", a "?" until served,
   then a number. The judge is tolerant, so a hand gets 100 nearly always
   and the number means nothing, or gets 89 with no idea why. Players read
   a percentage as pass or fail at their own bar and "retry anything below
   95"; the genre's own game never fails anyone: closeness only raises a
   score and unlocks looks.
3. **The jelly does nothing.** It sits, dark on a dark slab, and takes a
   tint. No wobble when touched, no tremble under the needle, no shiver
   when served. The satisfying thing about a jelly is that it wobbles; the
   satisfying thing in this genre, by every review, is the squeeze.

## 2. Intent

Make the squeeze the fun, the serve a reveal, and a day quick. Nothing in
it reads as a test. The pictures, the night's pipeline, the fluid's passes
and the user's standing rules are untouched.

## 3. Goals, non-goals, anti-goals

**Goals**
- A mould feels good in the hand inside ten seconds: the jelly answers
  every touch, a chunk filling is a thing to watch, 100% lands with a
  pop.
- Serve is a moment, not a grade: a shiver, a sweep of light, a stamp.
- A Medium day by hand takes about two minutes, not five.

**Non-goals** (kept as they are)
- The user's rules: no move or time limit on any band (2026-10-12); a
  chunk takes nothing past 100% and the dye spreads like a tint in water
  (2026-10-14); chunks hold their own colours (2026-10-11); no words over
  the tray (2026-10-11); the gel's darkness and the tray (the user's
  reference screens of 2026-10-14).
- The pictures, `Mould`, `jelly.ts`, the themed pipeline, the fluid's
  passes (no pass added: the phone's passes are still untimed).
- Overflow across seams, a stop-at-the-line pour, a serves budget: each
  would add tension by breaking a rule above. Not done.

**Anti-goals**
- A number that reads as failure.
- Any new per-frame mesh rebuild or fluid pass; the phone must not get
  slower (`docs/agents/harnesses.md`; the budget is draw calls).
- A wobble that moves the tray, the card or the buttons: only the jelly
  wobbles.

## 4. The parts

### 4.1 The pour is quick (mine)

- `Fluid.RATE` 3.6 → 8.0 at the anchor chunk (92 squares, the mushroom's
  stalk): about 1.2 s of hold to the card's shade, the root rule of
  2026-10-15 kept (a big chunk still takes longer, a small one less).
  `Sim.RATE` (the headless tally) scaled by the same factor so the probe
  and the screen agree. The drain follows (`DRAIN` is a multiple of the
  rate).
- `Sim.SETTLE_T` 0.9 → 0.45; `Sim.SHOW_T` 2.4 → 2.0, filled by the reveal
  (4.4). `METER_EASE` 12 → 20 so the ring keeps up.

### 4.2 The jelly wobbles (mine)

The jelly (the gel floor, the syrup, the seams and rim: `_floor`, the
dye quad, `_walls`) is drawn under its own transform about the mould's
centre, inside the tray's `_group()`; the tray slab, the card, pots and
buttons never move with it. The transform is a decaying squash with a
little shear: scale `(1 + w, 1 - w)`, skew `0.5 w`, `w = A sin(2π f t)
e^{-t/τ}` with f 4.5 Hz, τ 0.35 s. No mesh is rebuilt; it is a cached
mesh under a transform (CLAUDE.md).

What sets it off (`A`):
- a finger coming down on the tray: 0.02
- the squeeze button going down: 0.03; while held, a tremble of 0.006
  at 9 Hz under the needle (added to the squash, not decaying)
- the drain button going down: 0.02
- a chunk landing at 100% (4.3): 0.04
- the serve: 0.09, the tray's own `_wobble` of today moved onto the jelly
  (the tray no longer shakes)

Under `Motion.reduce` the jelly is still. The tutorial's bench shares the
table and gets all of it for free.

### 4.3 A chunk lands (mine)

The frame the meter first reads the chunk under the tip at or over
`LAND` 0.97 of `C_FULL` while the button is held:
- the ring snaps white for a moment and the number goes green;
- a pop: a new cue `land` from the bank's `wrap` ("anything repeated:
  landings", `docs/agents/sound.md`), pitch varied `TICK_VARY`;
- a haptic (the kind per `docs/agents/haptics.md`'s rules for a landing;
  the builder reads row 55 and picks the kind the rules give);
- a burst of sparkles from `ui/fx2d.gd` at the tip, in the chunk's colour,
  no new mesh;
- the wobble of 4.2.

Once per chunk per fill: the chunk is armed again when it is drained
under `LAND - 0.1`. Headless (no meter) the sim's own tally fires it, so
the probe can prove it.

### 4.4 The serve is a reveal, never a grade

**Serve never fails** (the web's one firm lesson; mine to apply). The
mark goes: `Sim.MARK`, `mark()`, `GD_NEED`, `GD_NEEDED`, the "needs N%"
sentence in `GD_RULES` and `TUT_GUMDROP_MATCH_BODY`, the `need` field of
the verdict (kept at 0 in the dictionary so nothing that reads it breaks).
A served mould is taken away whatever it reads; the day is the moulds
served. `Phase.SHOW` under the mark and `again` after a serve are gone
(`again` stays as Reset's event). The record `{"pct": [...]}` is unchanged,
`skill_quality` reads the same marks, the win's "Served at 100% · 98%"
stays, and `Sim.finish` is unchanged.

**But a jelly must be coloured to be served** (mine): `can_serve()` is
every chunk over `Sim.WET`, not just one. The gold button is greyed until
then; a press on it while grey gives the tongue pop (`bank:tongue`, "not
allowed") and the small refusal haptic, nothing else (no words over the
tray). The tutorial's bench prefills, so its rounds still serve.

**Tiers** (mine; `Sim.TIER_PERFECT` 95, `TIER_GREAT` 80):
- 95 and over: "Perfect!" (`GD_PERFECT`), the `perfect` cue, the confetti
  and star rain as today, the number in gold;
- 80 to 94: "Great!" (`GD_GREAT`, new row), the `good` cue, the number in
  the leaf's green;
- under 80: "Served!" (`GD_GOOD`), the `good` cue a few steps lower, the
  number in ink. No "it needed"; no flop cue.

**The reveal** (mine), in `SHOW_T`:
1. the needle lifts away and the meter fades (as today);
2. the big wobble (4.2);
3. a sweep of light: one soft white band, a cached mesh the width of the
   tray, drawn under a transform that carries it from the lower left to
   the upper right of the jelly over 0.5 s, alpha rising and falling,
   clipped to the mould by drawing it through the syrup Control's
   transform between the dye and the seams (the seams and rim are drawn
   over it, so it reads as light on the jelly, not on the tray);
4. the stamp: the number and the tier's word as the `Rewards` stickers
   today, 0.35 s after the serve;
5. the card's "?" becomes the number in the tier's colour;
6. the tray slides off as today and the next is set down.

Under `Motion.reduce`: no wobble, no sweep; the stamp and the card as
they are.

### 4.5 The card's line (mine)

"NEEDS 65% · 1/3" becomes "1 OF 3" (`GD_OF`, new row, "%d OF %d"; on a
one-mould day nothing). After the serve the line is the tier's word in
small caps under the number. The `?` stays until served.

### 4.6 Sounds (mine, under the house sound)

| Moment | Cue |
|---|---|
| a pot picked | `pick`, `bank:pebble` (a select), replacing the button click |
| the squeeze or drain button down | the button's own `fx.touch` (token), as today |
| a chunk lands | `land`, `bank:wrap` |
| the serve button, live | `fx.touch` then `serve` as today |
| the serve button, greyed | `nope`, `bank:tongue` |
| the pour and drain loops, `mix`, `deal`, `perfect`, `good` | as today |

`flop` and `game_over` are no longer cued (left in the set; nothing
loads them by name). New rows go in `tools/gen_sfx.py`'s gumdrop set as
`bank:<take>` rows and the set is regenerated; the bank copies need no
API key. `godot --headless --path . --import` after.

### 4.7 Words

`GD_RULES`, `GD_BLURB`, `TUT_GUMDROP_MATCH_BODY` and
`TUT_GUMDROP_HUD_BODY` lose the mark and gain the tiers in one sentence
("Serve it when every piece has colour: the nearer the card, the better
the stamp. 95% is Perfect."). `GD_LVL_*` unchanged. en, pt, es in one
row each; titles stay English.

## 5. What is measured before it is called done

- `tests/_probe_gumdrop.gd`: the day's run with serve-never-fails (a 30%
  serve takes the mould away), every chunk wet to serve, the landing
  event once per fill and again after a drain, the tiers at 79/80/94/95.
- `tests/_shot_gumdrop.gd -- <out> 1` and `-- 2` on `opengl3_angle` at
  810x1440: draw calls in play, at the serve's sweep and on the win,
  against 115-122 today and the 855 budget; the reveal shot at 0.3 s
  after the serve; a chunk's hold to 100% read by `pour` against the
  1.2 s intended. One windowed run a band, two readings of any number
  quoted.
- The suite's parse guard; `tests/_win.gd -- gumdrop`.

## 6. Left to the builder

- The sweep band's softness and the sparkle count (within Fx2D's
  vocabulary, `docs/art/flat-motion.md`).
- The haptic kinds, by `docs/agents/haptics.md`'s rules.
- The exact green and gold of the tiers (`core/palette.gd`'s own).
- Where `LAND` is read (the meter's eased value or the raw reading); it
  must never fire before the ring shows 97.

## 7. Calls that are the user's, unmade

- Serve never fails (4.4) against a grid card's "solve": the solve is
  now "every piece coloured", the number the polish. One constant and
  the rows put a mark back.
- The gel and tray stay dark (their 2026-10-14 reference); a lighter
  table was considered and not done.
- A shelf of the day's served jellies across days, free play into a
  served jelly, and a decision layer for Hard and Insane (pour order
  through a porous seam, or recipe shares at 2:1) were considered and
  left for a later pass: the first two are collection features, the
  third brushes the chunks-hold-their-colours rule.
