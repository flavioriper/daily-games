extends "res://core/puzzle_base.gd"

## Bridges as a flat board: a pale sea inset in the card, islets standing on
## it with the number of plank-ends each one wants, and runs of one to three
## planks laid in the lanes between the pairs that face each other. The rules
## live in puzzles/bridges_state.gd, which this only draws.
##
## **The fourth rule is the puzzle.** Every number met is not a solve: the
## islets have to end on one single network. The first cut said nothing at
## all about the near-miss where the numbers are all met and the islets stand
## in two groups (spec section 10), and players read the silence as a broken
## board; since the polish (2026-09-30) the line names it and the stray
## groups pulse.
##
## How it is drawn, and it is Word Trail's arrangement wholesale. A still
## mesh carries the sea (its basin, shallows, sandbars and ripples), a small
## one the laps spreading on it while one is, and one `ArrayMesh` everything
## else with no glyph on it -- the lit lane under the finger, a refusal's
## band, the hint glows, the planks and their pilings, the islets and their
## coins -- and the numbers go over the top as `draw_string` commands, because
## a glyph in a mesh cache key multiplies every state by ten. With it comes
## Word Trail's hard-won rule: **a canvas command holds a mesh by RID and not
## by reference**, so the mesh the last `_draw` handed over is kept in
## `_shown` until the next one replaces it, or a harness's `force_draw()`
## photographs a freed RID ("Parameter mesh is null", and an empty card).
##
## **The order is not a preference, because an islet is opaque and a run ends
## under one**: the pool, the ripples, the lit lane and a refusal's band, the
## runs over those, the islets over them, and the numbers last.
##
## **The polish of 2026-09-30** (spec 2026-09-30-bridges-polish-design.md).
## Players could not tell what the game wanted, so it now says it: two planks
## at most, as everywhere else; a ring of slots round every coin that fills a
## slot per plank; a tap on the water between two islets lays a plank; a
## ghost finger shows the drag on a first board; and the near-miss -- every
## number met, the islets in two groups -- is named out loud. Hard and Insane
## can be failed: every plank is judged as it lands, and a wrong one cracks
## and sinks, costs a heart and leaves a buoy on that lane for good. Insane is
## **Lantern Night**: a lantern counts the islets it is joined to rather than
## its planks, and some islets are dark and show nothing. A right plank
## builds a streak, a met islet raises a pennant and now and then plays a gag
## (a fish leaps, hearts float, the coin twirls), and the solve throws a
## party: the islets dance, confetti, a paper boat sails the pool, a bit of
## bridge wisdom and the seal.
##
## Spec: docs/superpowers/specs/2026-09-20-bridges-flat-design.md, sections 6
## and 7. Ported number for number from the canvas mock at
## docs/brainstorm/concepts.html#bridges, which is the reference for every
## measure here.

const State = preload("res://puzzles/bridges_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Seal = preload("res://ui/flat/seal.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")
const Haptics = preload("res://core/haptics.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const MovesPill = preload("res://ui/flat/moves_pill.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
## The moves the out-of-moves card's video buys, once a board.
const MOVES_BONUS := 5

## The out-of-hearts card's Back to camp.
signal leave

# --- the polish (2026-09-30) ---
## The ring of slots round a coin, one per plank (or per friend on a
## lantern) its number asks for, filling as they come: its radius off the
## coin, its thickness in islet radii (with a floor for the 11x11), and the
## gap between slots in radians.
const SLOT_R := 1.22
const SLOT_W := 0.17
const SLOT_MIN := 4.5
const SLOT_GAP := 0.28
## The coin flips over COIN_FLIP when its number comes right.
const COIN_FLIP := 0.34
## A plank settles into place after it lands: it dips SETTLE of its thickness
## and comes back over SETTLE_TIME.
const SETTLE := 0.28
const SETTLE_TIME := 0.2
## The hearts, on the family's paper pill in a strip over the pool.
const HEART_ROW := 64.0
const HEART_R := 21.0
const HEART_GAP := 12.0
const HEART_PILL_PAD := Vector2(18.0, 8.0)
const HEART_PILL_RIM := 2.0
const SPLIT_TIME := 0.7
const SPLIT_FALL := 56.0
const SPLIT_SPREAD := 14.0
const SPLIT_TURN := 0.7
const HEART_BACK_TIME := 0.3
## A wrong plank rolls out and lands like any other, stands CRACK_AFTER, then
## cracks in two and sinks over SINK_TIME, tipping SINK_TURN, dropping
## SINK_FALL of a cell and fading, with bubbles.
const CRACK_AFTER := 0.45
const SINK_TIME := 0.7
const SINK_TURN := 0.35
const SINK_FALL := 0.35
## A lane a heart ruled carries a small buoy in its water for good: BUOY_R of
## a cell, bobbing BUOY_BOB on its own slow clock.
const BUOY_R := 0.13
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## The streak: a note up the pentatonic from the second right plank, the
## bubble from the third, confetti at five and ten.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
## The bubble shows its number this long, then deflates on its own; the
## streak itself runs on, and the next right move pops it back in.
const COMBO_HOLD := 1.2
const COMBO_FONT := 44
## Three met islets in five play a gag, by the islet's hash.
const GAG_ODDS := 5
const GAGS := 3
const LOVE_HEARTS := 4
const LOVE_TIME := 1.3
const LOVE_RISE := 0.7
const LOVE_R := 0.14
const TWIRL_TIME := 0.55
const FISH_TIME := 0.9
const FISH_LEAP := 0.9
const FISH_SPAN := 1.4
## A met islet raises a pennant on its back edge: FLAG_H of a radius tall,
## popping up over FLAG_TIME, folding over FLAG_FOLD when it comes apart.
const FLAG_H := 0.95
const FLAG_TIME := 0.4
const FLAG_FOLD := 0.2
## The near-miss, named: every number met and the islets in groups. The
## groups that are not the biggest pulse SPLIT_PULSES times.
const SPLIT_PULSES := 3
const SPLIT_BEAT := 0.34
## The ghost finger that shows the drag on Easy and Medium until the first
## plank: it waits COACH_AFTER, then drags over COACH_DRAG, holds, lifts, and
## goes round again every COACH_LOOP.
const COACH_AFTER := 1.6
const COACH_DRAG := 0.9
const COACH_LOOP := 2.6
## Lantern Night: the night laid over the water, and the lantern's glow.
const NIGHT_ALPHA := 0.42
const NIGHT_STARS := 16
const LANTERN_GLOW := 1.7
const LANTERN_GLOW_ALPHA := 0.26
## The party, PARTY_AT after the solve wave.
const PARTY_AT := 0.5
const PARTY_EXTRA := 1.8
const DANCE_BEATS := 4
const DANCE_BEAT := 0.22
const DANCE_HOP := -9.0
const BOAT_TIME := 3.2
const BOAT_W := 0.9
const CHEERS := 12
const STAMP_AT := 1.0
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22
## The lines the tips cycle while nothing else is being said.
const TIPS := ["BR_TIP_REST", "BR_TIP_SLOTS", "BR_TIP_TAP", "BR_TIP_TWO", "BR_TIP_ONE_NET"]
const TIP_CYCLE := 7.0

# --- the screen, measured (spec section 6) ---
## The sea pool's inset from the card, and the lattice's own inset inside the
## pool. These two are the whole of it: **the lattice is measured off the
## pool the card actually hands over and never off a constant**, so the 920 it
## comes to at 1080 wide -- a 1000 card, a 944 pool, a cell of 131 / 102 / 84
## on the three bands -- is a measurement recorded in the spec's section 6 and
## not a number anything here reads.
const INSET := 28.0
const FIELD_PAD := 12.0
## A plank's thickness and the air between two of them, in cells: three planks
## span 0.59 of a cell, wide enough to read as three at 84 px and narrow
## enough to leave water either side.
const PLANK := 0.115
const PLANK_GAP := 0.095
## This board's own two, and the only two it needs: how long the solve wave's
## front takes to cross one run, and how long it rests on an islet. The wave
## itself is the board's signature and lands with the motion pass; `win_delay`
## already spends them, so the win waits exactly as long as the wave will run.
const WAVE_EDGE := 0.14
const WAVE_HOLD := 0.06

# --- the pool, in the mock's own pixels ---
## The pool's corner.
const POOL_RADIUS := 34.0
## The ripples: how many, how thick, how far they are let through, and the
## box they are sown in -- in from the water's left, down from its top, and
## how much of its width and height they spread over. The span is short of the
## pool by more than a ripple's length on purpose: a mesh cannot be clipped to
## the pool, so they are sown clear of the rim instead of cut at it.
const RIPPLES := 14
const RIPPLE_W := 5.0
const RIPPLE_ALPHA := 0.7
const RIPPLE_AT := Vector2(60.0, 70.0)
const RIPPLE_SPAN := Vector2(190.0, 140.0)
const RIPPLE_LEN := Vector2(40.0, 60.0)
const RIPPLE_BOW := 8.0

# --- an islet, in cells or in fractions of its own radius ---
## The islet's radius as a fraction of the cell, and everything else as a
## fraction of that radius. An islet is a small island standing in the water
## (the polish, 2026-09-26): a soft shadow on the sea, a wet-sand foot under a
## dry beach lit along its top, a turf crown standing proud of the beach with
## its own lit rim, and a paper coin on the turf that carries the number.
const ISLET_R := 0.43
## The islet is drawn from a little above (the reference, 2026-09-26): its
## top is an ellipse TOP_Y as tall as it is wide, and under it the drum's side
## shows SIDE of a radius deep, SIDE_R as wide as the top, wet from WET_AT of
## the way down.
const TOP_Y := 0.86
const SIDE := 0.52
const SIDE_R := 0.94
const WET_AT := 0.62
## The shadow the drum throws on the water: how wide and tall.
const SHADOW_RX := 1.2
const SHADOW_RY := 0.5
const SHADOW_ALPHA := 0.34
## The moss on top: the hanging lip TURF_DROP under it in BANK_DEEP, the lit
## rim toward LEAF_LIGHT by TURF_LIT, and the face TURF_R of the top, sitting
## TURF_TOP down, toned off the islet's hash within TONE.
const TURF_R := 0.86
const TURF_DROP := 0.06
const TURF_TOP := 0.07
const TURF_LIT := 0.5
const TONE := 0.035
## The sprouts on the moss's back edge, TUFT_H of a radius tall, and the
## share of islets that carry a flower.
const TUFT_H := 0.3
const FLOWER_SHARE := 0.3
## **The number stands on a paper coin**, as every other board's clues stand on
## paper: COIN_R of the islet, lifted COIN_LIFT over its own edge, which shows
## COIN_LIP under it in COIN_EDGE toward ink, with a soft shadow on the turf.
## The coin is what answers for the islet's count, the way Mushroom Patch's
## numbers do: LEAF_TILE with its numeral in LEAF_DEEP once the number is met
## exactly, BAD_TILE with BAD ink once the finger has pushed it over, and gold
## once the solve's wave has reached it. **It replaces the standing ring** the
## first cut drew round a met islet: a wash on the thing carrying the number
## reads at a glance on the 11x11, where a 4 px ring was a hair.
const COIN_R := 0.58
const COIN_LIFT := 0.08
const COIN_LIP := 0.11
const COIN_EDGE := 0.20
const COIN_SHADOW := 0.16
## LEAF_TILE alone sat too close to the paper coin beside it to read as a
## change of state at a glance, so a met coin is carried COIN_MET toward GOOD.
const COIN_MET := 0.22
## The ring `fx` throws off an islet as it meets its number, in islet radii.
const RING_R := 1.13
const NUMBER_SIZE := 0.86
const NUMBER_AT := -0.02
## An islet that has just come right glints: its coin shines SHINE toward
## SURFACE over GLINT_TIME, GLINT_LAG after it is met.
const GLINT_TIME := 0.42
const GLINT_LAG := 0.1
const SHINE := 0.7
## How much wider than the turf a press may land and still take the islet: an
## islet is round and the corners of its cell are water.
const GRAB := 1.25

# --- the lit lane under the finger, and the band a refusal flashes ---
## **The player has to see which islet they are about to join before they let
## go**, which is the whole of the drag's feedback: a gold band down the lane
## and a gold ring round the far islet, both drawn off `_aim` and `_aim_dir`
## in `_draw` -- a variable and a `queue_redraw`, never a node.
##
## The band is 0.62 of a cell wide, which is the mock's own number and which
## is what makes it read at **both ends of the band table**: 81 px on the 7x7
## and 52 px on the 11x11, against runs of 15 and 10. It is wider than a run
## of three planks (0.59 of a cell) by a hair, so a lit lane never reads as a
## run that is already there.
const BEAM_W := 0.62
const BEAM_RADIUS := 0.4
## How far the lit lane is let in under the two islets it joins, in islet
## radii, so it meets the turf instead of stopping short of it.
const BEAM_TUCK := 0.4
const BEAM_ALPHA := 0.86
## **The aim ring, and it is not the satisfied ring.** The gold band the drag
## throws round the islet the finger is about to join, for as long as the
## finger is down: its radius and its thickness in islet radii, the floor
## under that thickness so an 11x11 still draws a ring rather than a hair,
## and how far its gold is let through. **This is the ring the spec's
## section 9 measures** -- at the 11x11's 84 px cell the ratio gives 4.7 px
## and the 5 px floor is what saves it. A met islet wears no standing ring
## since the polish (2026-09-26): its coin is washed instead.
const BEAM_RING := 1.22
const BEAM_RING_W := 0.14
const BEAM_RING_MIN := 5.0
const BEAM_RING_ALPHA := 0.9
## A refusal's own band, and the highlight under the run that is in the way.
## Both are **plain `BAD` at a fading alpha**, which the pale sea is what
## allows: on the first cut's deep water `BAD` at any alpha came back mauve
## and the band had to be drawn opaque and dissolved by a mix (spec section 7).
## An alpha tuned against a dark ground is not portable to a light one, so
## these two say out loud that they were measured on the pale sea.
const REFUSE_ALPHA := 0.88
const BLOCKER_ALPHA := 0.95

# --- a plank ---
## Its corner as a fraction of its own thickness, the lip the deck stands on,
## the shadow it throws on the water and where, and the slats across it.
const PLANK_RADIUS := 0.34
const PLANK_EDGE := 4.0
const PLANK_SHADOW := Vector2(3.0, 7.0)
const PLANK_SHADOW_ALPHA := 0.22
const SLAT_STEP := 0.30
const SLAT_ALPHA := 0.28
const SLAT_W := 0.022
const SLAT_MIN := 2.0
## The light along a plank's upper edge (its left on a vertical run): DECK
## toward SURFACE by PLANK_LIT, PLANK_BEVEL of the plank's thickness wide. Each
## plank in a run is toned off its lane and index within PLANK_TONE, so a run
## of three reads as three boards and not as a striped one.
const PLANK_LIT := 0.38
const PLANK_BEVEL := 0.2
const PLANK_TONE := 0.06
## The pilings a run stands on: one each side of it at both ends, POST_R of a
## cell, stood POST_OUT of their own radius out into the water from the beach.
const POST_R := 0.052
const POST_OUT := 1.3
const POST_LIT := 0.34
## **A plank is laid across from the islet the finger left** (the polish's
## signature): it rolls out along the lane over LAY_TIME with the cubic ease,
## lifted LAY_LIFT of its thickness while it travels, and lands on the far
## islet at LAND_AT of that time -- which is when the far islet bumps
## LAND_BUMP, the water splashes and a number that came right answers. A run
## lifted to nothing draws back into the islet it was pulled from over
## PULL_TIME. A plank nobody's finger laid (a hint, an undo) rolls out from its
## middle both ways.
const LAY_TIME := 0.3
const LAY_LIFT := 0.9
const LAND_AT := 0.8
const LAND_BUMP := 0.12
const PULL_TIME := 0.22
## The next state of the lane under the finger, shown before the finger lets
## go: the plank the drag would lay at PREVIEW_ALPHA, or the run it would lift
## faded to it.
const PREVIEW_ALPHA := 0.5

# --- the hint's glow, and the check's mark ---
## The halo round a run a hint laid: its pad off the run's own box, its
## corner, how far its gold is let through, and the dashed outline over it.
const GLOW_PAD := 0.13
const GLOW_RADIUS := 1.6
const GLOW_ALPHA := 0.85
const DASH_ON := 0.13
const DASH_OFF := 0.1
const DASH_W := 0.05
const DASH_MIN := 3.0
## How far a run the check marked is carried toward BAD, deck and lip alike,
## **at the peak of its flash**. The flash is `Motion.flash_level` read off
## the moment Check named the run, which is the beat that draws the eye -- on
## an 11x11 with 24 islets something has to say *look here*.
const BAD_MIX := 0.85
const BAD_DEEP_MIX := 0.6
## **And then the mark stays**, at this fraction of the flash's own peak,
## until the player's next move lifts it: 0.425 of the way from `DECK` to
## `BAD` on the deck (`#b5825a` to `#c4745a`) and 0.30 on the lip
## (`#9c7350` to `#ae6d53`). Quiet enough to read as a mark and not as a
## second alarm.
##
## **0.50 and not less, and that was measured rather than picked.** `DECK`
## and `BAD` are both warm, so the mix moves far less than the number
## suggests: at 0.35 the marked plank came back `#c0785a`, eleven units of
## red off an unmarked one, and beside a right run on a rendered frame it
## was there only if you already knew. Shot at both ends of the band table
## with a marked run standing next to an unmarked one -- the 7x7 at a
## 131 px cell and the 11x11 at 84 -- 0.50 reads at both and 0.65 goes
## salmon. A tint tuned at one cell size is not portable to the other, which
## is why both were shot.
##
## **This is a deliberate departure from Nonogram**, whose wrong-tile blush
## simply decays. On that board a check is decoration over a board that
## already shows its own state; here Check is the **only door** to the
## near-miss (spec section 10) and it costs a check to open, so a player who
## has paid for an answer keeps it until they act on it. It is also what
## makes Check mean anything under reduce motion, which draws no flash at
## all: without the held tint a reduce-motion player spends a check and is
## shown nothing whatsoever.
const BAD_HELD := 0.50
## How far an over-filled islet's turf is washed out (spec section 5): it is
## drawn wrong, never refused.
const OVER_MIX := 0.42

# --- the solve wave's gold (spec sections 7 and 9) ---
## How far a lit plank's deck and lip are carried into `SUN_RAY`, and how far
## an islet's turf goes with it as the front arrives. The deck's 0.72 is the
## spec's own `mix(DECK, SUN_RAY, 0.72)`, **left unchanged by the colour
## pass** because it separates cleanly from the unlit brown against the pale
## sea; the flare is the same gold at the islet, read off `flash_level` so it
## rises and settles as the wave goes past.
const WAVE_GOLD := 0.72
const WAVE_DEEP := 0.55
const WAVE_FLARE := 0.62

# --- the sea, and everything on it (spec section 7) ---
## **This is the first flat board whose field is not paper**, and every value
## here is a mix of exactly *two* `core/palette.gd` entries. Nothing is
## invented and nothing was added to the palette. Letting `WATER_HI` down into
## **PAPER** rather than into a cool entry is what carries the warmth: the
## paper's red comes up as the blue comes down.
##
## Two of them invert on a pale ground and both are worth writing down: the
## **ripples are darker** than the water they lie on (WATER_HI strokes
## vanished, so the old sea's blue became the new sea's mark), and the
## **shallow band is paler** than the open water, not deeper.
const SEA := 0.10          # WATER_HI into PAPER -- #6cb5e7, the open water
const SEA_PALE := 0.34     # WATER_HI into PAPER -- #92c6e6, the shallows
const SEA_SHADE := 0.35    # WATER into TEXT     -- #336e99, an islet's shadow
## The islet: turf is BANK on an **ACORN** beach. The beach was STONE in the
## first cut and the islets stopped reading entirely -- STONE is value 237
## against a 230 sea, seven points apart, so the rim disappeared. ACORN sits
## 29 of value below the water and warm against a cool ground.
const BANK_HI := 0.26      # BANK into SURFACE, the turf's sun cap
const BANK_DEEP := 0.28    # BANK into TEXT, the turf's own lip
const SAND_DEEP := 0.22    # ACORN into TEXT, the wet sand at the waterline

# --- the sea as a basin (the polish, 2026-09-26) ---
## **The pool is sunk into the card**, the family's bed: its wall shows
## BASIN_WALL along the top in WATER WALL_DEEP toward ink, so the water reads
## as lying below the paper. The water pales from the clear blue in the middle
## to SEA_PALE at the wall over SHORE_W, and a line of foam FOAM_W wide runs
## round it FOAM_IN in from the edge.
const BASIN_WALL := 14.0
const WALL_DEEP := 0.18
const SHORE_W := 64.0
const FOAM_IN := 7.0
const FOAM_W := 4.0
const FOAM_ALPHA := 0.55
## Every islet stands in a patch of paler water, SANDBAR radii across, with a
## ring of white FOOT_RING radii out at its waterline.
const SANDBAR := 1.8
const SANDBAR_ALPHA := 0.7
const FOOT_RING := 1.28
const FOOT_RING_ALPHA := 0.45
## A few deeper patches over the open water, WATER at DEPTH_ALPHA.
const DEPTHS := 7
const DEPTH_ALPHA := 0.3
## The ripples keep RIPPLE_CLEAR cells off every islet.
const RIPPLE_CLEAR := 0.9
## The pool's dressing: DRESS_SPOTS places round the rim for a rock, a plant
## or a pad, and up to PADS lily pads in the open water, one corner between
## cells in PAD_SHARE; anything that would crowd an islet is left out.
const DRESS_SPOTS := 14
const PADS := 6
const PAD_SHARE := 0.22
## **The sea is alive at rest, and it costs no rebuild.** Every LAP_EVERY
## seconds (give or take a fifth) one islet laps: a ring of foam SURFACE at
## LAP_ALPHA spreads from LAP_FROM to LAP_TO of its radius over LAP_TIME,
## thinning as it goes, and a second follows LAP_GAP behind it. The rings are
## their own small mesh drawn between the sea and the board, so the board's
## own mesh is not rebuilt for them, and nothing laps under reduce motion.
const LAP_EVERY := 2.4
const LAP_TIME := 1.7
const LAP_GAP := 0.4
const LAP_FROM := 1.02
const LAP_TO := 1.9
const LAP_W := 0.13
const LAP_ALPHA := 0.6
## The solve's islets hop as the wave reaches them, and once it has crossed
## the network a light runs over it along the diagonal: it sets off
## WIN_GLINT_AT after the wave and reaches each islet and run WIN_GLINT_STEP a
## diagonal later.
const WIN_GLINT_AT := 0.12
const WIN_GLINT_STEP := 0.035

## The tip card names the rule a gesture just broke; it is the only thing on
## this screen that explains itself, and it is the board's only door to the
## rules sheet.
##
## **There are exactly two refusals and there is no third** (spec section 5).
## An islet pushed *over* its number is not one of them: it is drawn wrong --
## a `BAD` ring and washed turf -- and the finger fixes it, which is the house
## rule that feedback beats a mode.
const TIP_REST := "BR_TIP_REST"
const TIP_NONE := "BR_TIP_NONE"
const TIP_CROSS := "BR_TIP_CROSS"

var state = State.new()

## The board's own effects node, as on every flat board: the puff a plank
## lands with, the ring a satisfied islet takes and the wave's sparkles come
## through it and nowhere else (docs/art/flat-motion.md, rule 5).
var fx: Node2D

## The mesh the last `_draw` built, and the one it actually handed to the
## canvas item. The first is dropped whenever something changed so the next
## `_draw` rebuilds it; the second is held because a canvas command keeps a
## mesh by RID and not by reference.
## The board's meshes as the last build left them -- [under, runs, islets] --
## or null when the next `_draw` must build them again.
var _mesh = null
## The runs and the islets, each put together from shapes made once (the
## checkup of 2026-10-02): an islet's body, pennant, coin and ring, and a run
## at rest, copied natively under their transforms; only a run rolling out,
## shivering, previewed or half lit is drawn live. A room per islet and per
## lane that has carried planks (`RunMesh.room`), so a shape's indices are
## offset once.
var _rm_runs := RunMesh.new(_shape)
var _rm_islets := RunMesh.new(_shape)
## lane key -> its index: the room it owns in `_rm_runs`, laid the first time
## the lane is drawn and kept until the shapes are made again.
var _lane_ix: Dictionary = {}
## A run's look at rest ([key, count, glow, blush, wave u, low]) -> its shape
## id, and the id -> the look it was made from.
var _run_ids: Dictionary = {}
var _run_looks: Dictionary = {}
## The layout the shapes were made at: the board's own space while it builds
## (`_in_ref`), drawn under `_relay()` onto the layout it has now -- so the
## win card's half-size relayout makes nothing again (Queens' lesson).
var _ref_cell := 0.0
var _ref_origin := Vector2.ZERO
var _in_ref := false
## Each layer's last mesh and what it was built from: a build whose pieces
## all stand as they stood hands the last mesh back (an islet bumping does
## not rebuild the runs, a plank rolling out does not rebuild the islets).
var _runs_mesh: ArrayMesh
var _runs_sig: Array = []
var _islets_mesh: ArrayMesh
var _islets_sig: Array = []
## The still sea -- basin, shallows, sandbars and ripples -- built once a size
## and a board, and dropped only by a resize or a new board.
var _sea: ArrayMesh
## Every mesh the last `_draw` handed over: the sea, the laps and the board.
var _shown: Array = []

## The laps on the water: `[{"cell": Vector2i, "at": float}]`, when the next
## one is due, and the draw keeps running while one is still spreading. Their
## own generator, so an idle never touches the puzzle's.
var _laps: Array = []
var _next_lap := 0.0
var _lap_rng := RandomNumberGenerator.new()

## When the board opened, and how long anything on it is still moving. The
## card redraws while the clock has not passed `_anim_until` and stands still
## the rest of the time, which is what keeps a settled board at no cost.
var _opened := -1.0e9
var _anim_until := 0.0

## The islet the finger went down on, and where it went down, while a drag is
## live. NOWHERE when nothing is held.
var _from := State.NOWHERE
## The lane the drag is asking for, once the travel has passed half a cell,
## and the direction it took. "" and ZERO until then.
var _aim := ""
var _aim_dir := Vector2i.ZERO
## The laid run the press landed on the water of, for the tap that wipes.
var _on_run := ""
## The refusal on screen, or {} when there is none:
## `{"at": float, "from": Vector2i, "dir": Vector2i, "key": String,
## "blocker": String}`. The lane is kept as a key and a direction rather than
## as pixels, so a resize mid-flash moves the band with the lattice. Nothing
## is recorded under reduce motion -- the tip card still names the rule, but
## there is no flash to redraw for.
var _refuse: Dictionary = {}
## The islet the last run was laid from: where the solve wave will start.
var _last := State.NOWHERE

## Every lane a hint laid a plank on, so the board can show what was given.
var _given: Dictionary = {}
## Every lane the last Check marked, and when: the mark is `Motion.flash_level`
## and `Motion.shiver_offset` read off that moment, so it blushes, rattles and
## settles rather than standing until the next move.
var _wrong: Dictionary = {}

# --- the moments the drawn pieces are read off ---
## Each lane that has just gained planks: `{"at": float, "from": int}`, where
## `from` is the count it had, so every plank at or past that index is still
## falling in with `Motion.drop_in_lift` and fading with `appear_level`.
var _laid: Dictionary = {}
## Runs that have gone: `[{"key": String, "count": int, "at": float}]`, drawn
## at their old size shrinking away with `Motion.pop_out_scale`. Only a run
## that went **to zero** leaves a ghost -- a run going 3 to 2 re-centres its
## survivors, so there is no one plank that left for a ghost to be.
var _ghosts: Array = []
## The islets that have just met their number, and the ones the finger has
## just pushed over: the first bumps and rings, the second shivers.
var _met_at: Dictionary = {}
var _shiver_at: Dictionary = {}
## The far islet a rolling plank lands on, by the moment it lands: it bumps.
var _land_at: Dictionary = {}
## When each islet's coin glints, and each run's deck: a number come right,
## and the win's light crossing the network.
var _glint: Dictionary = {}
var _glint_run: Dictionary = {}
## What waits for a plank to land -- the splash, a met islet's ring and cue:
## `[{"at": float, "call": Callable}]`, fired from `_process`.
var _pending: Array = []
## Reset's wave: each islet's hop, by the moment it begins.
var _hop_at: Dictionary = {}
## The islet under the finger, when it went down and when it came up (-1 while
## it is still down): what `Motion.press_scale` is handed, so a drawn islet
## sinks under a press and springs back exactly as a tile node would.
var _press_cell := Vector2i(-1, -1)
var _press_at := -1.0e9
var _press_up := -1.0

## The solve wave. `_solved_at` is when it began and `_depth` is the
## breadth-first walk it runs over -- the same walk `_wave_depth()` measures
## and `win_delay()` spends, taken from the same `_last`, so the wave and the
## win screen can never disagree about how long the wave is. `_sparked` is
## the islets whose sparkle has already gone up.
var _solved_at := -INF
var _depth: Dictionary = {}
var _sparked: Dictionary = {}

var _tip_text := tr(TIP_REST)
var _tip_mood := Face.Expr.HAPPY

# --- the polish's state ---
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
## Insane's move counter (ui/flat/moves_pill.gd): `max_moves` is 0 on a band
## that does not count. Out of moves unsolved is `out_of_hearts`, the name
## the host and the card already know.
var moves_left := 0
var max_moves := 0
var _moves_pill := MovesPill.new()
var _lost_ever := false
var _asleep := false
var _sinking_busy := false
var _heart_card: Control
var _split_index := -1
var _split_at := -INF
var _back_index := -1
var _back_at := -INF
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _dusk_tw: Tween
## Wrong planks: `[{"key", "count", "at", "src"}]` -- `count` the planks the
## run held before, `at` when the wrong one was laid (it rolls, lands, cracks
## and sinks on that clock).
var _sinking: Array = []
var _flawless := false
var _streak := 0
var _combo_n := 0
var _combo_at := -INF
var _combo_pos := Vector2.ZERO
var _combo_popped := false
var _combo_out_at := -INF
var _combo_layer: Control
var _combo_shown: ArrayMesh
var _life_layer: Control
var _life_shown: Array = []
var _life_alive := false
var _love: Array = []
var _love_mesh: ArrayMesh
var _fish: Array = []
var _stamp_at := INF
var _seal_mesh: ArrayMesh
var _twirl: Dictionary = {}      # islet -> at: its coin spins a turn then
var _flip: Dictionary = {}       # islet -> at: its coin flips to met then
var _flag: Dictionary = {}       # islet -> {"at", "open"}: its pennant rising or folding
var _pulse: Dictionary = {}      # islet -> at: a split group pulsing then
var _groups := 1
## True while the board settles a move the hand made: only then does an
## islet met, one pushed over or the split named knock (docs/agents/haptics.md).
var _by_hand := false
var _dance_at := INF
var _boat_at := INF
var _glow_at := INF
var _coach_lane := ""
var _coach_from := State.NOWHERE
var _tip_timer: Timer
var _tip_idx := 0
var _hold_until := 0.0
## Bumped by every rebuild, so a callback owed to the last board does nothing.
var _gen := 0

func puzzle_id() -> String: return "bridges"
func title() -> String: return "Bridges"

## The rules in plain words, connectivity last and underlined, then the
## night's two clues on Insane and what its moves are for.
func rules() -> String:
	var out: String = tr("BR_RULES")
	if not state.lanterns.is_empty():
		out += "\n\n" + tr("BR_RULES_LANTERNS")
	if max_moves > 0:
		out += "\n\n" + tr("BR_RULES_MOVES") % max_moves
	elif max_hearts > 0:
		out += "\n\n" + tr("BR_RULES_HEARTS") % max_hearts
	else:
		out += "\n\n" + tr("BR_RULES_SAFE")
	return out

## The tutorial, a page a rule, each played on a little sea of its own
## (`ui/hud/bridges_tutorial_diagram.gd`): planks to a number, no crossing,
## one network, then what a mistake does (rose and Check), Lantern Night's
## lanterns, Undo and Reset, and the bulb on a band that has hints. Insane
## has no Check, Undo or hint to teach: its last page is the move counter.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/bridges_tutorial_diagram.gd")
	var hints: int = int(State.HINTS[state.band]) if state != null else 0
	var steps := [
		[Diagram.Lesson.NUMBERS, "HTP_BR_NUM",
			tr("HTP_BR_NUM_BODY") + ("" if max_hearts > 0 else " " + tr("HTP_BR_NUM_BODY_TAP"))],
		[Diagram.Lesson.CROSS, "HTP_BR_CROSS", tr("HTP_BR_CROSS_BODY")],
		[Diagram.Lesson.NETWORK, "HTP_BR_NET", tr("HTP_BR_NET_BODY")],
	]
	if max_moves <= 0:
		steps.append([Diagram.Lesson.OVER, "HTP_BR_OVER", tr("HTP_BR_OVER_BODY")])
	if state != null and not state.lanterns.is_empty():
		steps.append([Diagram.Lesson.LANTERNS, "HTP_BR_LANTERN", tr("BR_RULES_LANTERNS")])
	if max_moves <= 0:
		steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO",
			tr("HTP_BR_UNDO_BODY_JUDGED") if max_hearts > 0 else tr("HTP_BR_UNDO_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_BR_HINT_BODY_ONE") if hints == 1 else tr("HTP_BR_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = state.band if state != null else 0
		d.hearts = max_hearts
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves))
	return pages

## Undo, Hint and Check below Insane. Insane counts moves: no Undo (going
## round a lane's cycle is the take-back, and it costs), no hint and no
## Check, which would each say what is wrong.
func capabilities() -> Array[String]:
	if state != null and state.band >= 3:
		return []
	return ["undo", "hint", "check"]

## The lines the tips cycle: a counted board leads with the moves', Lantern
## Night with its two.
func _tips() -> Array:
	var lead: Array = ["TIP_MOVES_SEQ"] if max_moves > 0 else []
	if not state.lanterns.is_empty():
		return lead + ["BR_TIP_LANTERN", "BR_TIP_LANTERN_2"] + TIPS
	return lead + TIPS

## What the phone does under each cue (docs/agents/haptics.md). A plank laid
## taps (right or not: on Hard and Insane the heart says so as it lands) and
## a run lifted ticks. `met`, `over` and `split` are not mapped: a hint, an
## Undo and Reset settle the board through them too, so an islet come right
## bumps as the plank lands, and one pushed over its number or the islets
## named in groups warns, only under the hand's own move (`_by_hand`). The
## streak's confetti is the other milestone. `solved` is not mapped either:
## it fires as the finger lifts, and the win knocks when the last plank lands
## and the wave sets off (`_on_solved`). An islet read, the lane lit under
## the finger, a refused lane (`locked`, `ruled`), two groups joined, the
## plank sinking and its buoy, the streak's notes, the gags and the party say
## nothing. The seal thuds as it lands (`_party`).
const HAPTICS := {
	"place": Haptics.TAP,
	"remove": Haptics.TICK,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"confetti": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"check_ok": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"check": Haptics.WARN,
	"heart_lost": Haptics.BAD,
	"out_of_hearts": Haptics.LOSE,
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	fx.haptics = HAPTICS
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	_heart_layer = _layer("Hearts", 1, _draw_hearts)
	_life_layer = _layer("Life", 3, _draw_life)
	_combo_layer = _layer("Combo", 4, _draw_combo)
	resized.connect(_resized)
	solved.connect(_on_solved)

## A full-rect layer over the board, drawn by `draw` (One Line's).
func _layer(nm: String, z: int, draw: Callable) -> Control:
	var layer := Control.new()
	layer.name = nm
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(draw)
	add_child(layer)
	return layer

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state = State.new()
	state.build(rng, difficulty, bank_step)
	max_hearts = int(State.HEARTS[state.band])
	max_moves = state.moves_budget()
	_begin()

## Everything a newly dealt `state` starts from, and its entrance: what
## `build` does after the deal, and what the tutorial's own sea does after it
## lays one by hand.
func _begin() -> void:
	_heart_used = false
	_lost_ever = false
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	_refuse = {}
	_last = State.NOWHERE
	_given = {}
	_wrong = {}
	_laid = {}
	_ghosts = []
	_met_at = {}
	_shiver_at = {}
	_hop_at = {}
	_land_at = {}
	_glint = {}
	_glint_run = {}
	_pending = []
	_laps = []
	_sea = null
	_ref_cell = 0.0
	_press_cell = State.NOWHERE
	_press_up = -1.0
	_solved_at = -INF
	_depth = {}
	_sparked = {}
	_anim_until = 0.0
	_lap_rng.seed = hash(state.islets)
	_deal()
	_pick_coach()
	_tip_idx = 0
	_hold_until = 0.0
	_say(_tip(0), Face.Expr.HAPPY)
	if _tip_timer != null:
		_tip_timer.start()
	_enter()
	_refresh()

## The board as it is dealt, and as Try again deals it back: every heart,
## the day's light, nothing judged, no streak, pennant or party.
func _deal() -> void:
	hearts = max_hearts
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_sinking_busy = false
	_split_index = -1
	_back_index = -1
	_sinking = []
	_flawless = false
	_streak = 0
	_combo_n = 0
	_combo_out_at = -INF
	_love = []
	_fish = []
	_twirl = {}
	_flip = {}
	_flag = {}
	_pulse = {}
	_groups = state.islets.size()
	_dance_at = INF
	_boat_at = INF
	_glow_at = INF
	_stamp_at = INF
	_seal_mesh = null
	_love_mesh = null
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

# --- the layout, ported from the mock ---

## The sea pool, inset from the card on every side.
func _pool() -> Rect2:
	var row := _heart_row()
	return Rect2(INSET, INSET + row, maxf(0.0, size.x - 2.0 * INSET),
		maxf(0.0, size.y - 2.0 * INSET - row))

## The strip the hearts take over the pool, on a board that has them. The
## pool is taller than the lattice at every band, so it comes out of the
## pool's slack and the cell does not shrink.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 or max_moves > 0 else 0.0

## Where the hearts' pill is centred: in the strip over the pool.
func _hearts_y() -> float:
	return INSET + HEART_ROW * 0.5

## The largest cell the pool holds, with the lattice's own pad inside it.
## **The width binds at every band** -- 920 of lattice against 1110 of pool
## height at 1080 wide -- because the lattice is square and the slot is tall.
func _cell() -> float:
	if _in_ref:
		return _ref_cell
	if state.n <= 0:
		return 0.0
	var p := _pool()
	return maxf(0.0, minf((p.size.x - 2.0 * FIELD_PAD) / float(state.n),
		(p.size.y - 2.0 * FIELD_PAD) / float(state.n)))

func _field_size() -> float:
	return _cell() * float(state.n)

## The lattice's top-left: centred across the card, and the 214 of pool height
## it does not spend **halved above and below** -- 107 each, which is what
## `card_centred()` says on the card and this says inside the pool.
func _origin() -> Vector2:
	if _in_ref:
		return _ref_origin
	var p := _pool()
	var g := _field_size()
	return Vector2(size.x * 0.5 - g * 0.5, p.position.y + (p.size.y - g) * 0.5)

## Control-local point over the centre of the cell at (row, column) -- the
## name every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	var s := _cell()
	return _origin() + Vector2(float(c) + 0.5, float(r) + 0.5) * s

## The centre of an islet, which is `Vector2i(column, row)` here as it is
## everywhere in this board's state.
func _at(cell: Vector2i) -> Vector2:
	return cell_to_local(cell.y, cell.x)

## The cell under a local point as `Vector2i(column, row)`, or (-1, -1) when
## the point is off the lattice.
func local_to_cell(p: Vector2) -> Vector2i:
	var s := _cell()
	if s <= 0.0:
		return State.NOWHERE
	var q := (p - _origin()) / s
	var at := Vector2i(int(floor(q.x)), int(floor(q.y)))
	if at.x < 0 or at.y < 0 or at.x >= state.n or at.y >= state.n:
		return State.NOWHERE
	return at

func _islet_r() -> float:
	return _cell() * ISLET_R

## Where a run's planks stand: the lane between the two islets' rims, so a
## plank never runs under the turf it ends at.
## Returns {"horiz": bool, "a": Vector2, "b": Vector2}, the two ends of the
## run's centreline.
func _lane_ends(key: String) -> Dictionary:
	var lane: Dictionary = state.lanes[key]
	var a := _at(lane.a)
	var b := _at(lane.b)
	var r := _islet_r()
	var horiz: bool = int(lane.a.y) == int(lane.b.y)
	if horiz:
		var lo := minf(a.x, b.x) + r
		var hi := maxf(a.x, b.x) - r
		return {"horiz": true, "a": Vector2(lo, a.y), "b": Vector2(hi, a.y)}
	var top := minf(a.y, b.y) + r * (TOP_Y + SIDE)
	var bot := maxf(a.y, b.y) - r * TOP_Y
	return {"horiz": false, "a": Vector2(a.x, top), "b": Vector2(a.x, bot)}

## Every pixel it is given: the pool fills the card and the lattice is centred
## in the pool, so the board never hands a slot back.
func card_height(available: float) -> float:
	return available

## True, and the slack it centres is spent inside the pool rather than by the
## host: `card_height()` hands every pixel back, so the host has nothing left
## to halve. It says true because the lattice is square in a tall slot, which
## is the same reason Tents, Light Up and Queens say it.
func card_centred() -> bool:
	return true

## Drops the mesh so the next `_draw` rebuilds it, and asks for that draw. The
## mesh the last `_draw` handed over is still held by `_shown`, so the
## renderer is never left pointing at a freed RID.
func _refresh() -> void:
	_mesh = null
	queue_redraw()

## A new size moves every islet, so the still sea is rebuilt with the board.
func _resized() -> void:
	_sea = null
	_love_mesh = null
	_seal_mesh = null
	_refresh()
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

# --- the drawing ---

## Three meshes and then the numbers over the top: the still sea, the laps
## spreading on it, and the board -- everything else with no glyph on it. The
## order is the only one that works: an islet is opaque and a run ends under
## one, and a lap is water, so it goes under both.
## The whole card pops in wide about the pool's centre and fades as it comes
## (rule 7: a wide thing enters from most of the way, because the back ease's
## tenth of overshoot on a thousand units of width is a wobble), and the
## numbers take the same transform so a glyph never floats off the islet it
## belongs to.
func _draw() -> void:
	if state.islets.is_empty() or _cell() <= 0.0:
		return
	var t := _now()
	if _sea == null:
		_sea = _build_sea()
	_take_ref()
	_in_ref = true
	if _mesh == null:
		_mesh = _build(t)
	_in_ref = false
	var lap := _build_laps(t)
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	var grow := Motion.wide_pop_scale(since)
	var mid := _pool().get_center()
	var page := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var board := page * _relay()
	if seen > 0.0:
		for m in [_sea, lap]:
			if m != null:
				draw_mesh(m, null, page, Color(1.0, 1.0, 1.0, seen))
		for m in _mesh:
			if m != null:
				draw_mesh(m, null, board, Color(1.0, 1.0, 1.0, seen))
		_in_ref = true
		_draw_numbers(t, board, seen)
		_in_ref = false
	_shown = [_sea, lap] + _mesh

## The layout the shapes are made at: the first one with room on it, and any
## larger one after (a shape made small and drawn large would blur). A
## smaller one -- the win card's -- keeps it and is drawn under `_relay()`.
func _take_ref() -> void:
	var c := _cell()
	if c <= 0.0:
		return
	if _ref_cell <= 0.0 or c > _ref_cell + 0.01:
		_ref_cell = c
		_ref_origin = _origin()
		_rm_runs.reset()
		_rm_islets.reset()
		_lane_ix = {}
		_run_ids = {}
		_run_looks = {}
		_runs_sig = []
		_islets_sig = []
		_mesh = null

## The reference layout onto the one the board has now.
func _relay() -> Transform2D:
	if _ref_cell <= 0.0:
		return Transform2D.IDENTITY
	var k := _cell() / _ref_cell
	return Transform2D(0.0, Vector2(k, k), 0.0, _origin() - _ref_origin * k)

## The order the mock draws in, and it is not a preference either: the lit
## lane and a refusal's band go **under** the runs, so a highlight on the run
## in the way reads as a glow beneath it rather than a coat of paint over it,
## and everything goes under the islets, which are opaque. The lane under the
## finger is drawn with the runs even while it is bare, because its preview
## is the plank the drag would lay.
##
## Three meshes since the checkup (2026-10-02), in that order: the bands under
## the runs, drawn live (there is rarely one); the runs, a lane at a time in
## its own room, a run at rest one cached shape and a moving one drawn live
## into its room, then what sinks and the buoys; and the islets, each its
## body, pennant, coin and ring as shapes under its own scale and offset.
## Built in the reference layout's space (`_in_ref`).
func _build(t: float) -> Array:
	var b := Face.Builder.new()
	_aim_band(b)
	_refusal(b, t)
	var under: ArrayMesh = b.mesh() if not b.verts.is_empty() else null
	return [under, _build_runs(t), _build_islets(t)]

## Shape ids: an islet's body is BODY + its index * 2 + over; a pennant FLAG
## + its hue; the coin and the lantern one each; a ring of slots RING + want *
## 1000 + got * 2 + over; a run at rest RUN + the order its look was first met.
const SHAPE_BODY := 0
const SHAPE_FLAG := 100000
const SHAPE_COIN := 200000
const SHAPE_LANTERN := 200001
const SHAPE_RING := 300000
const SHAPE_RUN := 1000000
## Rooms: one per lane in `_rm_runs`, one per islet in `_rm_islets`.
const ROOM_LANE := 0
const ROOM_ISLET := 1
## Seconds after a plank is laid before its run is drawn from a shape: the
## roll, the landing's dip and the far posts' pop are all over by then.
const RUN_REST := 1.0
## And after a Check mark, before the marked run is: the flash and the
## rattle are over, the held tint stays.
const MARK_REST := 0.7

func _build_runs(t: float) -> ArrayMesh:
	var drawn := {}
	for key in state.runs:
		drawn[String(key)] = true
	if _aim != "" and state.planks(_aim) <= 0:
		drawn[_aim] = true
	for ghost: Dictionary in _ghosts:
		drawn[String(ghost["key"])] = true
	# Every run's look, and whether any of them moves.
	var looks: Array = []
	var sig: Array = [state.ruled.duplicate()]
	var live := not _ghosts.is_empty() or not _sinking.is_empty()
	for k in drawn:
		var key := String(k)
		if not state.lanes.has(key):
			continue
		# Its room before the build begins: a room laid mid-build would move
		# the tail out from under indices already written for it.
		_lane_room(key)
		var rl := _run_look(key, t)
		var rest = null if rl.is_empty() else _run_rest(rl)
		if rest == null and not rl.is_empty():
			live = true
		looks.append([key, rl, rest])
		sig.append(rest)
	# Put in room order: a put truncates the mesh to its cursor, so opening
	# a lower room after a higher one would cut the higher one's run off --
	# and `state.runs` reorders as lanes go to nothing and come back.
	looks.sort_custom(func(x: Array, y: Array) -> bool:
		return int(_lane_ix[x[0]]) < int(_lane_ix[y[0]]))
	sig = [sig[0]]
	for entry: Array in looks:
		sig.append(entry[2])
	if not live and _runs_mesh != null and sig == _runs_sig:
		return _runs_mesh
	_runs_sig = [] if live else sig
	_rm_runs.begin()
	for entry: Array in looks:
		var key := String(entry[0])
		_rm_runs.open(ROOM_LANE, int(_lane_ix[key]))
		_put_run(key, entry[1], entry[2])
		for ghost: Dictionary in _ghosts:
			if String(ghost["key"]) == key:
				var g := Face.Builder.new()
				_ghost(g, ghost, t)
				_rm_runs.put_builder(g)
	_rm_runs.close()
	var b := Face.Builder.new()
	for sink: Dictionary in _sinking:
		_sink(b, sink, t)
	for key in state.ruled:
		# A wrong plank's buoy bobs up once it has gone under, not before.
		if _sinking.any(func(k: Dictionary) -> bool: return String(k.key) == String(key)):
			continue
		_buoy(b, String(key))
	_rm_runs.put_builder(b)
	_runs_mesh = _rm_runs.mesh()
	return _runs_mesh

## The room `key` owns, laid the first time it is drawn: as long as its
## largest look but the hint's halo -- two planks and the wave's gold half on
## (a hinted run is rare and runs on the tail, which is still under the
## islets).
func _lane_room(key: String) -> int:
	var ix = _lane_ix.get(key)
	if ix != null:
		return ix
	ix = _lane_ix.size()
	_lane_ix[key] = ix
	var b := Face.Builder.new()
	_planks(b, key, State.MAX_PLANKS, {"wave": {"u": 0.5, "low": true}})
	_rm_runs.room(ROOM_LANE, ix, b.verts.size() + 64)
	return ix

## One run (`rl` its look, `rest` its key at rest or null): its cached
## shape when nothing on it moves, else drawn live.
func _put_run(key: String, rl: Dictionary, rest) -> void:
	if rl.is_empty():
		return
	if rest == null:
		var b := Face.Builder.new()
		_run_draw(b, key, rl)
		_rm_runs.put_builder(b)
		return
	var id = _run_ids.get(rest)
	if id == null:
		id = SHAPE_RUN + _run_ids.size()
		_run_ids[rest] = id
		var still: Dictionary = rl.duplicate(true)
		still.look["shine"] = 0.0
		_run_looks[id] = still
	_rm_runs.put(id, [], Transform2D.IDENTITY)

## A run's look as a key when nothing on it moves, or null: no plank still
## rolling or landing, no preview, no flash or rattle, the wave's gold all on
## or not yet come (and the win's glint is under the gold).
func _run_rest(rl: Dictionary):
	var look: Dictionary = rl.look
	if look.has("alpha") or look.has("faint_from"):
		return null
	if not Motion.reduce and float(look.since) < RUN_REST:
		return null
	var mark := float(look.since_wrong)
	if mark > -1.0e8 and mark < MARK_REST and not Motion.reduce:
		return null
	var wave: Dictionary = look.wave
	var u := float(wave.get("u", 0.0))
	if u > 0.0 and u < 1.0:
		return null
	if u <= 0.0 and float(look.shine) > 0.0:
		return null
	return [rl.key, int(rl.count), bool(rl.glow), float(look.blush), u, bool(wave.get("low", true))]

func _build_islets(t: float) -> ArrayMesh:
	if not _rm_islets.laid():
		for i in state.islets.size():
			var cell: Vector2i = state.islets[i]
			var want := state.need_of(cell)
			var room := _rm_islets.size_of(SHAPE_BODY + i * 2) \
				+ _rm_islets.size_of(SHAPE_FLAG) \
				+ maxi(_rm_islets.size_of(SHAPE_COIN), _rm_islets.size_of(SHAPE_LANTERN)) \
				+ _rm_islets.size_of(SHAPE_RING + want * 1000 + want * 2)
			_rm_islets.room(ROOM_ISLET, i, room + 128)
	var looks: Array = []
	var live := false
	for i in state.islets.size():
		var look := _islet_look(i, t)
		live = live or bool(look[8])
		looks.append(look)
	looks.append(_solved_at == -INF)
	if not live and _islets_mesh != null and looks == _islets_sig:
		return _islets_mesh
	_islets_sig = looks
	_rm_islets.begin()
	for i in state.islets.size():
		_rm_islets.open(ROOM_ISLET, i)
		_put_islet(i, looks[i], t)
	_islets_mesh = _rm_islets.mesh()
	return _islets_mesh

## What an islet looks like at `t`: [scale, middle, over, pennant, coin,
## turn, got, want, drawn live].
func _islet_look(i: int, t: float) -> Array:
	var cell: Vector2i = state.islets[i]
	var want: int = state.need_of(cell)
	var got: int = state.count(cell)
	var turn := _coin_turn(cell, t)
	return [_islet_scale(cell, t), _at(cell) + _islet_off(cell, t), got > want, _flag_k(cell, t),
		_coin_colour(cell, t, want, got), turn, got, want,
		state.lanterns.has(cell) and absf(turn) < 1.0, _lantern_glow(t) if state.lanterns.has(cell) else 0.0]

## An islet as its shapes under its scale and offset (what `_islet` draws,
## piece by piece): the body, the pennant, the coin or the lantern -- a
## turning lantern drawn live -- and the ring of slots.
func _put_islet(i: int, look: Array, t: float) -> void:
	var cell: Vector2i = state.islets[i]
	var sc: Vector2 = look[0]
	if sc.x <= 0.001 or sc.y <= 0.001:
		return
	var r := _islet_r()
	var mid: Vector2 = look[1]
	var over: bool = look[2]
	var want: int = look[7]
	var got: int = look[6]
	var xf := Transform2D(0.0, sc, 0.0, mid)
	_rm_islets.put(SHAPE_BODY + i * 2 + int(over), [], xf)
	var k: float = look[3]
	if k > 0.01:
		var foot := Vector2(r * 0.55, -r * TOP_Y * 0.55)
		_rm_islets.put(SHAPE_FLAG + _hue_of(cell), [], xf * Transform2D(0.0, Vector2(k, k), 0.0, foot))
	var coin: Color = look[4]
	var turn: float = look[5]
	if state.lanterns.has(cell):
		if bool(look[8]):
			var b := Face.Builder.new()
			_lantern(b, cell, mid - Vector2(0.0, r * sc.y * COIN_LIFT), r * sc.x, r * sc.y, coin, t)
			_rm_islets.put_builder(b)
		else:
			_rm_islets.put(SHAPE_LANTERN, _lantern_inks(coin, float(look[9])), xf)
	else:
		_rm_islets.put(SHAPE_COIN, [Color(Pal.TEXT, COIN_SHADOW), coin.lerp(Pal.TEXT, COIN_EDGE), coin],
			xf * Transform2D(0.0, Vector2(absf(turn), 1.0), 0.0, Vector2.ZERO))
	if _solved_at == -INF:
		var shown := 0 if over else got
		_rm_islets.put(SHAPE_RING + want * 1000 + shown * 2 + int(over), [],
			xf * Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0.0, -r * COIN_LIFT)))

## Makes shape `id` in the reference layout, about its own origin for an
## islet's and in the board's space for a run's.
func _shape(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var r := _islet_r()
	if id >= SHAPE_RUN:
		var rl: Dictionary = _run_looks[id]
		_run_draw(b, String(rl.key), rl)
	elif id >= SHAPE_RING:
		var code := id - SHAPE_RING
		var ring := r * COIN_R * SLOT_R
		_slots(b, Vector2.ZERO, ring, ring, code / 1000, (code % 1000) / 2, r, code % 2 == 1)
	elif id == SHAPE_LANTERN:
		_lantern_draw(b, Vector2(0.0, -r * COIN_LIFT), r, r, 1.0,
			[RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2), RunMesh.slot(3), RunMesh.slot(4)])
	elif id == SHAPE_COIN:
		var cx := r * COIN_R
		Scenery.soft_disc(b, Vector2(0.0, r * COIN_LIP * 0.8), cx * 1.14 + 1.0, cx * 1.08, RunMesh.slot(0))
		b.ellipse(Vector2(0.0, r * (COIN_LIP - COIN_LIFT)), cx, cx, RunMesh.slot(1))
		b.ellipse(Vector2(0.0, -r * COIN_LIFT), cx, cx, RunMesh.slot(2))
	elif id >= SHAPE_FLAG:
		_pennant_draw(b, Vector2.ZERO, r * FLAG_H, r, id - SHAPE_FLAG)
	else:
		var i := (id - SHAPE_BODY) / 2
		_islet_body(b, state.islets[i], Vector2.ZERO, r, r, id % 2 == 1)
	return b

## A wrong plank on Hard or Insane: it rolls out from the islet the finger
## left and lands like any other, stands a beat, then cracks in two and sinks
## -- each half tipping away from the crack, dropping and fading -- while the
## run's own right planks stand beside it.
func _sink(b, sink: Dictionary, t: float) -> void:
	var key := String(sink.key)
	if not state.lanes.has(key) or Motion.reduce:
		return
	var e := t - float(sink.at)
	var land := LAY_TIME
	var count: int = int(sink.count) + 1
	if e < land + CRACK_AFTER:
		# Rolling out and standing: the plank drawn as the run's newest.
		_planks_only(b, key, count, count - 1, e, sink.get("src", State.NOWHERE), 0.0, 0.0)
		return
	var u := clampf((e - land - CRACK_AFTER) / SINK_TIME, 0.0, 1.0)
	if u >= 1.0:
		return
	_planks_only(b, key, count, count - 1, 1.0e9, State.NOWHERE, u, 1.0 - u * u)

## The newest plank of a run of `count`, for a wrong one: `since` its roll,
## and once `crack` is past zero, split into two halves that tip, sink and
## fade to `alpha`. The run's right planks are drawn by `_run` as usual.
func _planks_only(b, key: String, count: int, index: int, since: float, src: Vector2i,
		crack: float, alpha: float) -> void:
	var s := _cell()
	var g := _lane_ends(key)
	var horiz: bool = g.horiz
	var thick := s * PLANK
	var air := s * PLANK_GAP
	# Beside the run's standing planks (`index` of them, centred as `_run`
	# draws them), never on top of one.
	var standing := float(index) * thick + float(maxi(index - 1, 0)) * air
	var off := 0.0 if index <= 0 else standing * 0.5 + air + thick * 0.5
	var lo: Vector2 = Vector2(minf(g.a.x, g.b.x), minf(g.a.y, g.b.y))
	var run: float = absf(g.b.x - g.a.x) if horiz else absf(g.b.y - g.a.y)
	var face: Color = Pal.DECK.lerp(Pal.BAD, 0.55 * minf(1.0, crack * 4.0 + (0.0 if since < 1.0e8 else 1.0)))
	var deep: Color = Pal.WOOD_DEEP.lerp(Pal.BAD, 0.4)
	if crack <= 0.0:
		var u := _ease(since / LAY_TIME)
		var side := _side(key, src)
		var span := run * u
		var shift := 0.0 if side > 0 else ((run - span) if side < 0 else (run - span) * 0.5)
		var at: Vector2
		var box: Vector2
		if horiz:
			at = Vector2(lo.x + shift, g.a.y + off - thick * 0.5)
			box = Vector2(span, thick)
		else:
			at = Vector2(g.a.x + off - thick * 0.5, lo.y + shift)
			box = Vector2(thick, span)
		if span <= 0.5:
			return
		at.y -= thick * LAY_LIFT * (1.0 - u)
		_plank(b, at, box, horiz, minf(box.x, box.y) * PLANK_RADIUS,
			Pal.DECK, Pal.WOOD_DEEP, {})
		return
	# Cracked: two halves, each about its own middle, tipping away from the
	# crack and sinking.
	var shade: Color = Pal.WATER.lerp(Pal.TEXT, SEA_SHADE)
	for h in 2:
		var half := run * 0.5
		var at: Vector2
		var box: Vector2
		if horiz:
			at = Vector2(lo.x + half * h, g.a.y + off - thick * 0.5)
			box = Vector2(half, thick)
		else:
			at = Vector2(g.a.x + off - thick * 0.5, lo.y + half * h)
			box = Vector2(thick, half)
		var mid := at + box * 0.5
		var turn := SINK_TURN * crack * (1.0 if h == 1 else -1.0)
		var drop := Vector2(0.0, s * SINK_FALL * crack * crack)
		var shrink := 1.0 - 0.3 * crack
		var pts := Face.Builder.round_rect(-box * 0.5 * shrink, box * shrink,
			minf(box.x, box.y) * PLANK_RADIUS)
		var lip := PackedVector2Array()
		var top := PackedVector2Array()
		for q in pts:
			lip.append(mid + drop + (q + Vector2(0.0, PLANK_EDGE * 0.5)).rotated(turn))
			top.append(mid + drop + q.rotated(turn))
		b.polygon(lip, Color(deep, alpha))
		b.polygon(top, Color(face, alpha))
	# Bubbles where it went down.
	var m := (Vector2(g.a) + Vector2(g.b)) * 0.5
	for k in 3:
		var bu := clampf(crack * 1.4 - float(k) * 0.2, 0.0, 1.0)
		if bu <= 0.0 or bu >= 1.0:
			continue
		var p := m + Vector2((float(k) - 1.0) * s * 0.18, s * 0.1 - s * 0.35 * bu)
		b.stroke(Face.Builder.ring(p, s * 0.05 * (0.6 + bu), s * 0.05 * (0.6 + bu)),
			maxf(1.5, s * 0.015), Color(Pal.SURFACE, 0.8 * (1.0 - bu)), true)
	b.stroke(Face.Builder.ring(m, s * (0.2 + 0.5 * crack), s * (0.12 + 0.3 * crack)),
		maxf(2.0, s * 0.03), Color(shade.lerp(Pal.SURFACE, 0.6), 0.5 * (1.0 - crack)), true)

## A heart's lesson, standing for good: a small red-and-white buoy in the
## lane's water, a rope ring on the lane's middle. It says "no more planks
## here" -- a lane ruled at 0 wears a cross on the buoy's band, one ruled at
## 1 a single bar.
func _buoy(b, key: String) -> void:
	if not state.lanes.has(key):
		return
	var s := _cell()
	var g := _lane_ends(key)
	var m := (Vector2(g.a) + Vector2(g.b)) * 0.5
	var laid := state.planks(key)
	var total := _run_width(maxi(laid, 1)) if laid > 0 else 0.0
	# Beside the run when it carries planks, on the lane when it is empty.
	if laid > 0:
		m += (Vector2(0.0, 1.0) if bool(g.horiz) else Vector2(1.0, 0.0)) * (total * 0.5 + s * BUOY_R * 1.3)
	var r := s * BUOY_R
	Scenery.soft_disc(b, m + Vector2(0.0, r * 0.7), r * 1.4, r * 0.55,
		Color(Pal.WATER.lerp(Pal.TEXT, SEA_SHADE), 0.3))
	b.stroke(Face.Builder.ring(m + Vector2(0.0, r * 0.55), r * 1.25, r * 0.5),
		maxf(1.5, r * 0.14), Color(Pal.SURFACE, 0.7), true)
	b.disc(m, r, Pal.SURFACE)
	b.fan(Face.Builder.round_rect(m - Vector2(r, r * 0.34), Vector2(2.0 * r, r * 0.68), r * 0.2), Pal.BAD)
	b.disc(m - Vector2(r * 0.3, r * 0.45), r * 0.22, Color(Pal.SURFACE, 0.8))
	var ink := Pal.SURFACE
	var w := maxf(1.5, r * 0.16)
	if int(state.ruled[key]) <= 0:
		b.stroke(PackedVector2Array([m + Vector2(-r * 0.3, -r * 0.2), m + Vector2(r * 0.3, r * 0.2)]), w, ink)
		b.stroke(PackedVector2Array([m + Vector2(-r * 0.3, r * 0.2), m + Vector2(r * 0.3, -r * 0.2)]), w, ink)
	else:
		b.stroke(PackedVector2Array([m + Vector2(-r * 0.4, 0.0), m + Vector2(r * 0.4, 0.0)]), w, ink)

## The lane the finger is asking for, lit: a gold band down it and a gold ring
## round the islet at the far end. This is the drag's whole answer, and it is
## drawn rather than mounted -- `_aim` and `_aim_dir` are the only state under
## it, so a drag costs a variable and a `queue_redraw`.
func _aim_band(b) -> void:
	if _aim == "" or _from == State.NOWHERE or not state.lanes.has(_aim):
		return
	var r := _islet_r()
	_band(b, _lane_ends(_aim), r * BEAM_TUCK, Color(Pal.SUN, BEAM_ALPHA))
	var lane: Dictionary = state.lanes[_aim]
	var other: Vector2i = lane.b if lane.a == _from else lane.a
	b.stroke(Face.Builder.ring(_at(other), r * BEAM_RING, r * BEAM_RING),
		maxf(BEAM_RING_MIN, r * BEAM_RING_W), Color(Pal.SUN, BEAM_RING_ALPHA), true)

## A refused drag: the lane flashes in BAD, and on a crossed lane the run in
## the way flashes under it, so the refusal names the plank the finger has to
## clear rather than only saying that one exists. The level is the
## vocabulary's own flash read as a curve (`Motion.flash_level`) off the
## moment the refusal happened, the way Shikaku and Light Up read theirs; it
## is zero under reduce motion, which is why nothing is recorded there.
func _refusal(b, t: float) -> void:
	if _refuse.is_empty():
		return
	var level := Motion.flash_level(t - float(_refuse.at))
	if level <= 0.0:
		return
	var key := String(_refuse.key)
	if key == "":
		# Nothing faces it: the band runs from the islet's rim out to the wall,
		# down the empty water the finger asked for.
		_band(b, _empty_lane(Vector2i(_refuse.from), Vector2i(_refuse.dir)), 0.0,
			Color(Pal.BAD, level * REFUSE_ALPHA))
	else:
		_band(b, _lane_ends(key), _islet_r() * BEAM_TUCK,
			Color(Pal.BAD, level * REFUSE_ALPHA))
	var blocker := String(_refuse.blocker)
	if blocker != "" and state.lanes.has(blocker):
		_band(b, _lane_ends(blocker), 0.0, Color(Pal.BAD, level * BLOCKER_ALPHA))

## One band down a lane: `tuck` is how far past each end it reaches, which is
## an islet's shoulder for a real lane and nothing for a lane that ends at the
## wall or for the blocker's own run.
func _band(b, g: Dictionary, tuck: float, ink: Color) -> void:
	if ink.a <= 0.0:
		return
	var w := _cell() * BEAM_W
	var at: Vector2
	var box: Vector2
	if bool(g.horiz):
		at = Vector2(minf(g.a.x, g.b.x) - tuck, g.a.y - w * 0.5)
		box = Vector2(absf(g.b.x - g.a.x) + 2.0 * tuck, w)
	else:
		at = Vector2(g.a.x - w * 0.5, minf(g.a.y, g.b.y) - tuck)
		box = Vector2(w, absf(g.b.y - g.a.y) + 2.0 * tuck)
	if box.x <= 0.0 or box.y <= 0.0:
		return
	b.fan(Face.Builder.round_rect(at, box, w * BEAM_RADIUS), ink)

## The empty water a refused drag ran down: from the islet's rim out to the
## edge of the lattice, in the shape `_lane_ends` hands back so one `_band`
## draws both. There is no islet at the far end, which is the refusal.
func _empty_lane(cell: Vector2i, dir: Vector2i) -> Dictionary:
	var mid := _at(cell)
	var o := _origin()
	var g := _field_size()
	var a := mid + Vector2(dir) * _islet_r()
	if dir.x != 0:
		return {"horiz": true, "a": a,
			"b": Vector2(o.x + g if dir.x > 0 else o.x, mid.y)}
	return {"horiz": false, "a": a,
		"b": Vector2(mid.x, o.y + g if dir.y > 0 else o.y)}

## The lean a refused islet takes: out along the drag the finger just made and
## back again. It is `Motion.nudge_offset` read as a curve off the refusal's
## own moment -- a refusal that does not move is not a refusal -- and nothing
## here is a number of this board's: the recipe's own `NUDGE` and `NUDGE_TIME`
## carry it, as they carry every other board's nudge.
func _lean(cell: Vector2i, t: float) -> Vector2:
	if _refuse.is_empty() or cell != Vector2i(_refuse.from):
		return Vector2.ZERO
	return Vector2(_refuse.dir) * Motion.nudge_offset(t - float(_refuse.at))

## Seconds since the scene started: the one clock every curve here is read at.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Keeps the card redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## The entrance: the pool pops in wide about its own centre and the islets pop
## onto it a beat later with the squash, along the diagonal from the top-left
## corner. Nothing here is a number of this board's -- the recipes' own carry
## it, exactly as they carry Light Up's court and Word Trail's field.
func _enter() -> void:
	_opened = _now()
	var far := 0
	for cell: Vector2i in state.islets:
		far = maxi(far, cell.x + cell.y)
	_busy_for(maxf(_enter_delay(far) + Motion.POP_IN,
		Motion.ENTER_DELAY + Motion.ENTER_POP))
	_next_lap = _anim_until + LAP_EVERY * 0.5
	if fx != null:
		fx.cue("enter")
		if not state.lanterns.is_empty():
			# The lanterns come on once the islets have risen. A reopened
			# solved day has no entrance to follow (Sudoku's review finding).
			_after(_anim_until - _opened, func() -> void:
				if not is_done():
					fx.cue("lanterns"))

func _enter_delay(diagonal: int) -> float:
	return Motion.ENTER_DELAY + Motion.ENTER_FACE_LAG \
		+ Motion.stagger(diagonal, Motion.ENTER_STAGGER)

## Retires what has finished, sends up the sparkles the wave's front has
## reached, and keeps the card redrawing while anything is still moving.
func _process(delta: float) -> void:
	super(delta)
	if state.islets.is_empty() or _cell() <= 0.0:
		return
	var t := _now()
	_fire(t)
	_sweep(t)
	_spark(t)
	_lap(t)
	_tick_layers(t)
	if _twirling(t) or _dancing(t):
		_busy_for(0.05)
	if t < _anim_until:
		_refresh()
	elif not _laps.is_empty():
		# A lap is its own mesh: the board's stands as it is.
		queue_redraw()

## Runs what was waiting on a plank to land.
func _fire(t: float) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	for job: Dictionary in _pending:
		if t >= float(job.at):
			(job.call as Callable).call()
		else:
			keep.append(job)
	_pending = keep

## Calls `call` at clock time `at`, or now if that has passed.
func _later(at: float, call: Callable) -> void:
	if at <= _now():
		call.call()
	else:
		_pending.append({"at": at, "call": call})

## Drops the refusal once its flash has died -- the flash outlasts the lean,
## so it is the one that says when the refusal is over -- and the ghosts of
## the runs that have shrunk away to nothing.
func _sweep(t: float) -> void:
	if not _refuse.is_empty() and t - float(_refuse.at) >= Motion.FLASH_IN + Motion.FLASH_OUT:
		_refuse = {}
		_refresh()
	if _ghosts.is_empty():
		return
	var keep: Array = []
	for ghost: Dictionary in _ghosts:
		if t - float(ghost["at"]) < maxf(Motion.POP_OUT, PULL_TIME):
			keep.append(ghost)
	if keep.size() != _ghosts.size():
		_ghosts = keep
		_refresh()

## The still sea, sunk into the card: the basin's wall along the top, the
## clear blue paling to the shallows at the wall, a thin line of foam round
## the water's edge, a few deeper patches, the ring of lighter water at every
## islet's foot, the white ripple dashes, and the pool's dressing -- rocks and
## leafy plants on the rim and lily pads in the open water. Built once a size
## and a board -- nothing here moves -- so the board's own mesh can be
## rebuilt as often as it likes without this one.
func _build_sea() -> ArrayMesh:
	var p := _pool()
	if p.size.x <= 2.0 * SHORE_W or p.size.y <= 2.0 * SHORE_W + BASIN_WALL:
		return null
	var b := Face.Builder.new()
	var sea: Color = Pal.WATER_HI.lerp(Pal.PAPER, SEA)
	var pale: Color = Pal.WATER_HI.lerp(Pal.PAPER, SEA_PALE)
	var wall: Color = Pal.WATER.lerp(Pal.TEXT, WALL_DEEP)
	b.fan(Face.Builder.round_rect(p.position, p.size, POOL_RADIUS), wall)
	var water := Rect2(p.position + Vector2(0.0, BASIN_WALL), p.size - Vector2(0.0, BASIN_WALL))
	b.fan(Face.Builder.round_rect(water.position, water.size, POOL_RADIUS), pale)
	var deep := water.grow(-SHORE_W)
	_shore(b, water, deep, POOL_RADIUS, pale, sea)
	b.fan(Face.Builder.round_rect(deep.position, deep.size, 0.0), sea)
	b.stroke(Face.Builder.round_rect(water.position + Vector2.ONE * FOAM_IN,
		water.size - Vector2.ONE * 2.0 * FOAM_IN, POOL_RADIUS - FOAM_IN), FOAM_W,
		Color(Pal.SURFACE, FOAM_ALPHA), true)
	_depths(b, water)
	var r := _islet_r()
	for cell in state.islets:
		var foot := _at(cell) + Vector2(0.0, r * (SIDE + 0.1))
		Scenery.soft_disc(b, foot, r * SANDBAR, r * SANDBAR * 0.8, Color(pale, SANDBAR_ALPHA))
		b.stroke(Face.Builder.ring(foot, r * FOOT_RING, r * FOOT_RING * 0.8), r * 0.07,
			Color(Pal.SURFACE, FOOT_RING_ALPHA), true)
	_ripples(b, water)
	_dress(b, p, water)
	if not state.lanterns.is_empty():
		_night(b, water)
	return b.mesh()

## Lantern Night's sky on the water: a dusk-blue veil over the pool and a
## scatter of reflected stars in the open water, kept off the islets. The
## lanterns' own glow is drawn with them, over this.
func _night(b, water: Rect2) -> void:
	b.fan(Face.Builder.round_rect(water.position, water.size, POOL_RADIUS),
		Color(Pal.MOON_DEEP, NIGHT_ALPHA))
	var s := _cell()
	var placed := 0
	var i := 0
	while placed < NIGHT_STARS and i < NIGHT_STARS * 10:
		var at := water.position + Vector2(_hash(i, 91), _hash(i, 93)) * water.size
		i += 1
		if not water.grow(-s * 0.3).has_point(at) or _near_islet(at, _islet_r() * 1.6):
			continue
		var r := s * (0.025 + 0.03 * _hash(i, 95))
		b.polygon(Seal.star(at, r * 1.6), Color(Pal.SUN_RAY, 0.55))
		placed += 1

## A few deeper patches in the open water: soft blots of WATER, kept off
## the islets so none reads as an islet's shadow.
func _depths(b, water: Rect2) -> void:
	var s := _cell()
	var ink := Color(Pal.WATER, DEPTH_ALPHA)
	var placed := 0
	var i := 0
	while placed < DEPTHS and i < DEPTHS * 10:
		var at := water.position + Vector2(_hash(i, 41 + _salt()), _hash(i, 43)) * water.size
		var rad := s * (0.18 + 0.2 * _hash(i, 47))
		i += 1
		if not water.grow(-rad * 2.0).has_point(at) or _near_islet(at, _islet_r() * 1.8 + rad):
			continue
		Scenery.soft_disc(b, at, rad * 1.3, rad, ink)
		Scenery.soft_disc(b, at + Vector2(rad * 0.9, rad * 0.5), rad * 0.8, rad * 0.6, ink)
		placed += 1

## A salt off the board, so two boards of the same size are dressed apart.
func _salt() -> int:
	var h := 0
	for cell: Vector2i in state.islets:
		h += cell.x * 7 + cell.y * 13
	return posmod(h, 97)

## The pool's dressing, all of it off the hash and kept clear of the islets
## so nothing sits where a finger lands or a plank has to run: rocks and
## leafy plants on the rim, standing half on the paper and half in the water,
## and lily pads in the open water, some carrying a white flower.
func _dress(b, pool: Rect2, water: Rect2) -> void:
	var s := _cell()
	var r := _islet_r()
	var salt := _salt()
	# Every piece placed so far, as [centre, radius], so none lands on another.
	var taken: Array = []
	# The corners first, always dressed: a bush with a rock tucked in, or a
	# pair of rocks, sized down or left bare only where an islet crowds them.
	var corners := [pool.position, Vector2(pool.end.x, pool.position.y),
		Vector2(pool.position.x, pool.end.y), pool.end]
	for ci in 4:
		var c: Vector2 = corners[ci]
		var inward := (pool.get_center() - c).normalized()
		var size := s * 0.5
		var at: Vector2 = c + inward * size * 1.1
		while size > s * 0.2 and _near_islet(at, r * 1.3 + size):
			size *= 0.75
			at = c + inward * size * 1.1
		if size <= s * 0.2:
			continue
		taken.append([at, size * 1.6])
		if _hash(ci, 81 + salt) < 0.55:
			_plant(b, at, size, -inward, ci + salt)
			var along := Vector2(signf(inward.x), 0.0) if ci < 2 else Vector2(0.0, signf(inward.y))
			_rocks(b, at + along * size * 0.9, size * 0.55, ci + 5 + salt)
		else:
			_rocks(b, at, size * 0.8, ci + salt)
	# The rim, walked round from the top-left corner.
	var perimeter := 2.0 * (pool.size.x + pool.size.y)
	var spots := DRESS_SPOTS
	for i in spots:
		var u := (float(i) + 0.3 + 0.4 * _hash(i, 3 + salt)) / float(spots)
		var d := u * perimeter
		var at: Vector2
		var out: Vector2
		if d < pool.size.x:
			at = pool.position + Vector2(d, BASIN_WALL * 0.5)
			out = Vector2.UP
		elif d < pool.size.x + pool.size.y:
			at = pool.position + Vector2(pool.size.x, d - pool.size.x)
			out = Vector2.RIGHT
		elif d < 2.0 * pool.size.x + pool.size.y:
			at = pool.position + Vector2(pool.size.x - (d - pool.size.x - pool.size.y), pool.size.y)
			out = Vector2.DOWN
		else:
			at = pool.position + Vector2(0.0, pool.size.y - (d - 2.0 * pool.size.x - pool.size.y))
			out = Vector2.LEFT
		# Pulled in off the corners' curve, so nothing hangs over bare card.
		at = at.clamp(pool.position + Vector2.ONE * POOL_RADIUS * 0.6,
			pool.end - Vector2.ONE * POOL_RADIUS * 0.6)
		var size := s * (0.3 + 0.16 * _hash(i, 5 + salt))
		if _near_islet(at, r * 1.4 + size):
			size *= 0.6
			if _near_islet(at, r * 1.4 + size):
				continue
		if _crowded(taken, at, size):
			continue
		taken.append([at, size])
		var kind := _hash(i, 9 + salt)
		if kind < 0.45:
			_rocks(b, at - out * size * 0.25, size, i + salt)
		elif kind < 0.8:
			_plant(b, at - out * size * 0.2, size * 1.1, out, i + salt)
		else:
			_pad(b, at - out * size * 1.1, size * 0.62, i + salt, true)
	# The pads in the open water, at the corners between cells.
	var o := _origin()
	var pads := 0
	for gy in range(1, state.n):
		for gx in range(1, state.n):
			if pads >= PADS or _hash(gx * 31 + gy, 17 + salt) > PAD_SHARE:
				continue
			var at := o + Vector2(gx, gy) * s + (Vector2(_hash(gx, gy + 3), _hash(gy, gx + 5))
				- Vector2.ONE * 0.5) * s * 0.3
			var size := s * (0.13 + 0.07 * _hash(gx, gy + 11))
			if _near_islet(at, r * 1.45 + size) or not water.grow(-size * 2.0).has_point(at) \
					or _crowded(taken, at, size):
				continue
			taken.append([at, size])
			_pad(b, at, size, gx * 7 + gy + salt, _hash(gx + 2, gy) < 0.35)
			pads += 1

## True when a piece of `size` at `at` would land on one already `taken`.
static func _crowded(taken: Array, at: Vector2, size: float) -> bool:
	for piece in taken:
		if (piece[0] as Vector2).distance_to(at) < float(piece[1]) + size * 1.2:
			return true
	return false

## One rock, or a big one with a smaller beside it: a rounded blob in BOULDER
## on its own shade, lit across the top, with a soft shadow into the water.
func _rocks(b, at: Vector2, size: float, seed_i: int) -> void:
	var shade := Color(Pal.WATER.lerp(Pal.TEXT, SEA_SHADE), 0.3)
	var parts := [[Vector2.ZERO, 1.0]]
	var side := 0.9 if _hash(seed_i, 23) < 0.5 else -0.9
	if _hash(seed_i, 21) < 0.75:
		parts.append([Vector2(side, 0.35), 0.62])
	if _hash(seed_i, 25) < 0.4:
		parts.append([Vector2(-side * 0.8, 0.45), 0.45])
	for part in parts:
		var c: Vector2 = at + (part[0] as Vector2) * size
		var rs: float = size * float(part[1])
		if part != parts[0]:
			c += Vector2(0.0, size * 0.1)
		Scenery.soft_disc(b, c + Vector2(0.0, rs * 0.55), rs * 1.3, rs * 0.55, shade)
		b.fan(_blob(c + Vector2(0.0, rs * 0.12), rs, rs * 0.78, seed_i), Pal.BOULDER.lerp(Pal.TEXT, 0.28))
		b.fan(_blob(c, rs * 0.96, rs * 0.72, seed_i), Pal.BOULDER)
		b.fan(_blob(c + Vector2(-rs * 0.18, -rs * 0.3), rs * 0.6, rs * 0.34, seed_i + 1),
			Pal.BOULDER.lerp(Pal.SURFACE, 0.4))

## A lumpy, roughly round outline: an ellipse with its radius nudged by two
## slow waves off the hash, so no two stones are the same.
func _blob(c: Vector2, rx: float, ry: float, seed_i: int) -> PackedVector2Array:
	var pts := Face.Builder.ring(c, rx, ry)
	var ph := _hash(seed_i, 29) * TAU
	for k in pts.size():
		var a := TAU * float(k) / float(pts.size())
		var wob := 1.0 + 0.07 * sin(3.0 * a + ph) + 0.04 * sin(5.0 * a + ph * 2.0)
		pts[k] = c + (pts[k] - c) * wob
	return pts

## A leafy bush on the rim, three layers of broad leaves fanned out of a
## root and leaning off the paper into the water -- the back ring in shade,
## the middle in leaf, the front lit -- and now and then a white flower.
func _plant(b, at: Vector2, size: float, out: Vector2, seed_i: int) -> void:
	var lean := (-out).angle()
	Scenery.soft_disc(b, at + Vector2.from_angle(lean) * size * 0.5 + Vector2(0.0, size * 0.3),
		size * 1.1, size * 0.6, Color(Pal.WATER.lerp(Pal.TEXT, SEA_SHADE), 0.25))
	var layers := [[Pal.LEAF_DEEP, 6, 2.6, 0.95], [Pal.LEAF, 5, 2.0, 0.78],
		[Pal.LEAF_LIGHT, 3, 1.3, 0.58]]
	for li in layers.size():
		var layer: Array = layers[li]
		var n: int = layer[1]
		for k in n:
			var u := float(k) / float(n - 1) - 0.5
			var ang := lean + u * float(layer[2]) + (_hash(seed_i, 33 + k + li * 9) - 0.5) * 0.35
			var lng := size * float(layer[3]) * (0.8 + 0.35 * _hash(seed_i, 37 + k + li * 9))
			_leaf(b, at, ang, lng, lng * 0.8, layer[0])
	if _hash(seed_i, 39) < 0.6:
		_flower(b, at + Vector2.from_angle(lean + 0.4) * size * 0.55, size * 0.22)

## One leaf from `root` pointing along `ang`: two arcs meeting at a tip.
func _leaf(b, root: Vector2, ang: float, lng: float, wide: float, col: Color) -> void:
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal() * wide * 0.5
	var tip := root + dir * lng
	var pts := PackedVector2Array()
	pts.append_array(Face.Builder.bezier2(root, root + dir * lng * 0.45 + side, tip, 8))
	pts.append_array(Face.Builder.bezier2(tip, root + dir * lng * 0.45 - side, root, 8))
	b.polygon(pts, col)

## A lily pad: a round leaf with its wedge cut out, on a darker rim, with a
## lit vein or two; `bloom` sets a white flower on it.
func _pad(b, at: Vector2, size: float, seed_i: int, bloom: bool) -> void:
	var turn := _hash(seed_i, 51) * TAU
	var pts := PackedVector2Array([at])
	var n := 20
	for k in n + 1:
		var a := turn + 0.5 + (TAU - 1.0) * float(k) / float(n)
		pts.append(at + Vector2(cos(a), sin(a) * 0.82) * size)
	var shade := Color(Pal.WATER.lerp(Pal.TEXT, SEA_SHADE), 0.22)
	Scenery.soft_disc(b, at + Vector2(0.0, size * 0.35), size * 1.15, size * 0.6, shade)
	var foot := PackedVector2Array()
	for q in pts:
		foot.append(q + Vector2(0.0, size * 0.12))
	b.polygon(foot, Pal.LEAF_DEEP)
	b.polygon(pts, Pal.MOSS)
	b.stroke(PackedVector2Array([at, at + Vector2.from_angle(turn + PI) * size * 0.7]),
		maxf(1.0, size * 0.08), Color(Pal.LEAF_LIGHT, 0.8))
	if bloom:
		_flower(b, at + Vector2.from_angle(turn + PI * 0.7) * size * 0.3, size * 0.42)

## A small white flower: five petals round a sun-yellow eye.
func _flower(b, at: Vector2, size: float) -> void:
	for k in 5:
		var a := TAU * float(k) / 5.0 - PI * 0.5
		b.ellipse(at + Vector2.from_angle(a) * size * 0.55 + Vector2(0.0, size * 0.08),
			size * 0.42, size * 0.38, Pal.SURFACE.lerp(Pal.LINE, 0.35))
		b.ellipse(at + Vector2.from_angle(a) * size * 0.55, size * 0.42, size * 0.38, Pal.SURFACE)
	b.disc(at, size * 0.28, Pal.SUN_RAY)

## The band of water between the basin's edge and the open water, coloured
## `outer` at the wall and `inner` where the open water starts, so the sea
## pales toward the wall with no step in it. Both outlines take the same
## number of points, corner for corner, which is what lets them be stitched.
func _shore(b, outer: Rect2, inner: Rect2, radius: float, outer_col: Color,
		inner_col: Color) -> void:
	var o := _corners(outer, radius)
	var i := _corners(inner, 0.0)
	var n := o.size()
	var first: int = b.verts.size()
	for k in n:
		b.vertex(o[k], outer_col)
	for k in n:
		b.vertex(i[k], inner_col)
	for k in n:
		var j := (k + 1) % n
		b.tri(first + k, first + j, first + n + k)
		b.tri(first + j, first + n + j, first + n + k)

## A rounded rectangle's outline with a fixed count of points a corner, so two
## of them of different radii line up point for point.
static func _corners(rect: Rect2, radius: float) -> PackedVector2Array:
	const SEG := 8
	var rr := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var at := rect.position
	var sz := rect.size
	var out := PackedVector2Array()
	var centres := [at + Vector2(sz.x - rr, rr), at + Vector2(sz.x - rr, sz.y - rr),
		at + Vector2(rr, sz.y - rr), at + Vector2(rr, rr)]
	for c in 4:
		var from := -PI * 0.5 + PI * 0.5 * c
		for k in SEG + 1:
			out.append(centres[c] + Vector2.from_angle(from + PI * 0.5 * k / SEG) * rr)
	return out

## The ripples over the open water: short white dashes with a bow in them,
## some with a shorter twin under, sown off the hash and kept clear of every
## islet, so none runs under one.
func _ripples(b, water: Rect2) -> void:
	var ink := Color(Pal.SURFACE, RIPPLE_ALPHA)
	var clear := _cell() * RIPPLE_CLEAR
	var placed := 0
	var i := 0
	while placed < RIPPLES and i < RIPPLES * 8:
		var span := RIPPLE_LEN.x + _hash(i, 3) * RIPPLE_LEN.y
		var at := water.position + RIPPLE_AT + Vector2(
			_hash(i, 7 + _salt()) * (water.size.x - RIPPLE_SPAN.x),
			_hash(i, 11) * (water.size.y - RIPPLE_SPAN.y))
		i += 1
		if _near_islet(at + Vector2(span * 0.5, 0.0), clear + span * 0.5):
			continue
		b.stroke(Face.Builder.bezier2(at, at + Vector2(span * 0.5, -RIPPLE_BOW),
			at + Vector2(span, 0.0)), RIPPLE_W, ink)
		if _hash(i, 13) < 0.5:
			var twin := at + Vector2(span * 0.3, RIPPLE_W * 3.2)
			b.stroke(Face.Builder.bezier2(twin, twin + Vector2(span * 0.3, -RIPPLE_BOW * 0.6),
				twin + Vector2(span * 0.6, 0.0)), RIPPLE_W * 0.8, Color(ink, RIPPLE_ALPHA * 0.7))
		placed += 1

func _near_islet(at: Vector2, within: float) -> bool:
	for cell in state.islets:
		if _at(cell).distance_to(at) < within:
			return true
	return false

## The laps spreading on the water, as their own small mesh: two rings of foam
## an islet sends out, the second LAP_GAP behind the first, each widening with
## the ease out and thinning as it fades. Null while nothing laps.
func _build_laps(t: float) -> ArrayMesh:
	if _laps.is_empty():
		return null
	var b := Face.Builder.new()
	var r := _islet_r()
	for lap: Dictionary in _laps:
		for k in 2:
			var e := t - float(lap.at) - float(k) * LAP_GAP
			if e <= 0.0 or e >= LAP_TIME:
				continue
			var u := e / LAP_TIME
			var rad := r * lerpf(LAP_FROM, LAP_TO, 1.0 - pow(1.0 - u, 2.0))
			var a := LAP_ALPHA * (1.0 - u) * minf(1.0, u * 6.0) * (1.0 if k == 0 else 0.6)
			b.stroke(Face.Builder.ring(_at(lap.cell), rad, rad), r * LAP_W * (1.0 - 0.6 * u),
				Color(Pal.SURFACE, a), true)
	return b.mesh() if not b.verts.is_empty() else null

## Sends an islet lapping every LAP_EVERY or so, once the board has entered
## and while nothing else on it is moving, and retires the laps that have
## spread out. Nothing laps under reduce motion.
func _lap(t: float) -> void:
	if not _laps.is_empty():
		var keep: Array = []
		for lap: Dictionary in _laps:
			if t - float(lap.at) < LAP_TIME + LAP_GAP:
				keep.append(lap)
		if keep.size() != _laps.size():
			_laps = keep
			queue_redraw()
	if Motion.reduce or t < _next_lap:
		return
	if t >= _anim_until and _from == State.NOWHERE:
		var cell: Vector2i = state.islets[_lap_rng.randi() % state.islets.size()]
		_laps.append({"cell": cell, "at": t})
	_next_lap = t + LAP_EVERY * _lap_rng.randf_range(0.8, 1.2)

## One run as it stands: the halo if a hint laid it, then a plank per count,
## each on its own coloured shadow, and the pilings at its ends. Three recipes
## meet on a run and every one of them is read as a curve -- a plank that has
## just been laid is still rolling out across the lane, a run the last Check
## marked blushes toward BAD with `flash_level` and rattles across its own lane
## with `shiver_offset`, and a run the solve wave has reached wears the lit
## deck from the end the front came in at.
##
## The lane under the finger shows what letting go would do: the plank the
## drag would lay, faint, beside the ones standing, or the whole run faint
## when the drag would lift it.
func _run(b, key: String, t: float) -> void:
	var rl := _run_look(key, t)
	if not rl.is_empty():
		_run_draw(b, key, rl)

## What `_run` draws, as {key, count, glow, look}, or {} for nothing.
func _run_look(key: String, t: float) -> Dictionary:
	var count: int = state.planks(key)
	var next := _preview(key)
	if count <= 0 and next <= 0:
		return {}
	var glow := _given.has(key) and not is_done() and count > 0
	var laid: Dictionary = _laid.get(key, {})
	# The check's mark, in one level: the flash while it lasts, and never
	# below BAD_HELD for as long as the mark is standing. Under reduce motion
	# the flash is zero from the first frame, so the mark simply appears at
	# its held tint -- which is the whole of Check's answer there.
	var since_wrong := -1.0e9
	var mark := 0.0
	if _wrong.has(key):
		since_wrong = t - float(_wrong[key])
		mark = maxf(BAD_HELD, Motion.flash_level(since_wrong))
	var look := {
		"since": t - float(laid.get("at", -1.0e9)),
		"first_new": int(laid.get("from", count)),
		"src": laid.get("src", State.NOWHERE),
		"since_wrong": since_wrong,
		"blush": mark,
		"wave": _wave_of(key, t),
		"shine": _shine(_glint_run, key, t),
	}
	if next == 0:
		look["alpha"] = PREVIEW_ALPHA
	elif next > count:
		look["faint_from"] = count
		count = next
	return {"key": key, "count": count, "planks": state.planks(key), "glow": glow, "look": look}

func _run_draw(b, key: String, rl: Dictionary) -> void:
	if bool(rl.glow):
		_glow(b, _lane_ends(key), _run_width(int(rl.planks)))
	_planks(b, key, int(rl.count), rl.look)

## What the lane under the finger would hold once the finger lets go, or -1
## when `key` is not that lane or the lane is refused.
func _preview(key: String) -> int:
	if key != _aim or _from == State.NOWHERE or not state.lanes.has(key):
		return -1
	if state.blocked_by(key) != "":
		return -1
	if state.judged():
		# Judged planks are only ever added: nothing past two, and nothing a
		# heart has already ruled out.
		var next := state.planks(key) + 1
		if next > State.MAX_PLANKS or (state.ruled.has(key) and next > int(state.ruled[key])):
			return -1
		return next
	return (state.planks(key) + 1) % (State.MAX_PLANKS + 1)

## A run that has gone, still leaving: drawn back into the islet the finger
## pulled it from, or closing to nothing about its planks' own centres with
## `Motion.pop_out_scale` when nobody's finger pulled it (a wipe, an undo,
## Reset's wave).
func _ghost(b, ghost: Dictionary, t: float) -> void:
	var key := String(ghost["key"])
	if not state.lanes.has(key) or Motion.reduce:
		return
	var e := t - float(ghost["at"])
	var src: Vector2i = ghost.get("src", State.NOWHERE)
	var look := {}
	if src != State.NOWHERE:
		if e >= PULL_TIME:
			return
		look = {"pull": 1.0 - _ease(e / PULL_TIME), "src": src,
			"posts": Motion.pop_out_scale(e, PULL_TIME)}
	else:
		var grow := Motion.pop_out_scale(e)
		if grow <= 0.0:
			return
		look = {"grow": grow, "posts": grow}
	_planks(b, key, int(ghost["count"]), look)

## The cubic ease out a plank rolls with, 0 to 1.
static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)

## The thickness a run of `count` planks and the air between them comes to:
## what the hint's halo is drawn round.
func _run_width(count: int) -> float:
	var s := _cell()
	return float(count) * s * PLANK + float(count - 1) * s * PLANK_GAP

## Which end of `key`'s drawn lane `src` stands at: 1 the low end (`g.a`), -1
## the high end, 0 when no islet laid it and it grows from its middle.
func _side(key: String, src: Vector2i) -> int:
	if src == State.NOWHERE or not state.lanes.has(key):
		return 0
	var lane: Dictionary = state.lanes[key]
	if src != lane.a and src != lane.b:
		return 0
	var other: Vector2i = lane.b if src == lane.a else lane.a
	var p := _at(src)
	var q := _at(other)
	return 1 if p.x + p.y < q.x + q.y else -1

## The planks themselves, and the pilings at their ends. `look` says how they
## stand, every key optional:
## - `grow`: closes them about their own centres (a ghost leaving);
## - `since`, `first_new`, `src`: which of them are still rolling out, from
##   when and from which islet;
## - `pull`: how much of the lane a run being drawn back still spans;
## - `since_wrong`, `blush`: Check's rattle and how far its mark carries the
##   wood toward BAD;
## - `wave`: what `_front` said about this lane;
## - `shine`: the win's light crossing the deck;
## - `alpha`, `faint_from`: the preview -- the whole run faint, or the planks
##   from that index on;
## - `posts`: the pilings' own scale when a ghost takes them away.
func _planks(b, key: String, count: int, look: Dictionary) -> void:
	var s := _cell()
	var g := _lane_ends(key)
	var horiz: bool = g.horiz
	var thick := s * PLANK
	var air := s * PLANK_GAP
	var total := float(count) * thick + float(count - 1) * air
	var grow: float = look.get("grow", 1.0)
	var since: float = look.get("since", 1.0e9)
	var first_new: int = look.get("first_new", count)
	var side := _side(key, look.get("src", State.NOWHERE))
	var pull: float = look.get("pull", 1.0)
	var alpha: float = look.get("alpha", 1.0)
	var faint_from: int = look.get("faint_from", count)
	var blush: float = look.get("blush", 0.0)
	var shine: float = look.get("shine", 0.0)
	var wave: Dictionary = look.get("wave", {})
	var rattle := Motion.shiver_offset(look.get("since_wrong", -1.0e9))
	var shake := Vector2(0.0, rattle) if horiz else Vector2(rattle, 0.0)
	var face: Color = Pal.DECK.lerp(Pal.BAD, BAD_MIX * blush)
	var deep: Color = Pal.WOOD_DEEP.lerp(Pal.BAD, BAD_DEEP_MIX * blush)
	var shade: Color = Pal.WATER.lerp(Pal.TEXT, SEA_SHADE)
	var lo: Vector2 = Vector2(minf(g.a.x, g.b.x), minf(g.a.y, g.b.y))
	var run: float = absf(g.b.x - g.a.x) if horiz else absf(g.b.y - g.a.y)
	for i in count:
		var off := float(i) * (thick + air) - (total - thick) * 0.5
		var at: Vector2
		var box: Vector2
		if horiz:
			at = Vector2(lo.x, g.a.y + off - thick * 0.5)
			box = Vector2(run, thick)
		else:
			at = Vector2(g.a.x + off - thick * 0.5, lo.y)
			box = Vector2(thick, run)
		if grow != 1.0:
			var mid := at + box * 0.5
			box *= grow
			at = mid - box * 0.5
		at += shake
		# How much of the lane this plank spans: all of it standing, less while
		# it rolls out or is drawn back, anchored at the islet it comes from.
		var u := pull
		var a := alpha * (PREVIEW_ALPHA if i >= faint_from else 1.0)
		var settle := 0.0
		if i >= first_new and i < faint_from and not Motion.reduce:
			u = _ease(since / LAY_TIME)
			a *= Motion.appear_level(since)
			# Landed: it dips into the water a hair and bobs back up.
			var e := since - LAY_TIME
			if e > 0.0 and e < SETTLE_TIME:
				settle = -thick * SETTLE * sin(PI * e / SETTLE_TIME)
		if u <= 0.0 or a <= 0.0:
			continue
		var lift := settle
		if u < 1.0:
			var span := run * u
			var slack := run - span
			var shift := 0.0 if side > 0 else (slack if side < 0 else slack * 0.5)
			if horiz:
				at.x += shift
				box.x = span
			else:
				at.y += shift
				box.y = span
			lift = thick * LAY_LIFT * (1.0 - u) if pull >= 1.0 else 0.0
		var r := minf(box.x, box.y) * PLANK_RADIUS
		b.fan(Face.Builder.round_rect(at + PLANK_SHADOW, box, r),
			Color(shade, PLANK_SHADOW_ALPHA * a))
		at.y -= lift
		var tone := (_hash(hash(key) % 997, i) - 0.5) * 2.0 * PLANK_TONE
		var toned: Color = face.lightened(tone) if tone > 0.0 else face.darkened(-tone)
		_plank(b, at, box, horiz, r, Color(toned.lerp(Pal.SURFACE, shine * SHINE * 0.5), a),
			Color(deep, a), wave)
	_posts(b, g, total, shake, look, since, side)

## The pilings a run stands on: one each side of it at both of its ends, out
## in the water off the beach. A run rolling out drives the posts at the islet
## it came from first and the far pair as the plank lands; a ghost takes them
## with it at `look.posts`.
func _posts(b, g: Dictionary, total: float, shake: Vector2, look: Dictionary,
		since: float, side: int) -> void:
	var horiz: bool = g.horiz
	var pr := _cell() * POST_R
	var alpha: float = look.get("alpha", 1.0)
	if int(look.get("first_new", 1)) == 0 and int(look.get("faint_from", 99)) == 0:
		alpha *= PREVIEW_ALPHA
	var along := Vector2(1.0, 0.0) if horiz else Vector2(0.0, 1.0)
	var across := Vector2(0.0, 1.0) if horiz else Vector2(1.0, 0.0)
	var ends: Array = [g.a, g.b]
	# g.a is the low end whichever way the lane is stored.
	if horiz and g.a.x > g.b.x or not horiz and g.a.y > g.b.y:
		ends = [g.b, g.a]
	var shade: Color = Pal.WATER.lerp(Pal.TEXT, SEA_SHADE)
	var lit: Color = Pal.DECK.lerp(Pal.SURFACE, POST_LIT)
	for e in 2:
		var inward := along if e == 0 else -along
		# Which end the plank lands at: the far one from the islet it left, or
		# both at once when it grew from its middle.
		var far := side == 0 or (side > 0) == (e == 1)
		var grow: float = look.get("posts", 1.0)
		if int(look.get("first_new", 1)) == 0 and not Motion.reduce and since < 1.0e8:
			grow *= Motion.pop_in_scale(since - (LAY_TIME * LAND_AT if far else 0.0)).x
		if grow <= 0.001:
			continue
		var base: Vector2 = Vector2(ends[e]) + inward * pr * POST_OUT + shake
		for sgn in [-1.0, 1.0]:
			var at: Vector2 = base + across * sgn * (total * 0.5 + pr * 1.2)
			var rr := pr * grow
			b.disc(at + PLANK_SHADOW * 0.5, rr * 1.1, Color(shade, PLANK_SHADOW_ALPHA * alpha))
			b.disc(at, rr, Color(Pal.WOOD_DEEP, alpha))
			b.disc(at - Vector2(0.0, rr * 0.28), rr * 0.72, Color(lit, alpha))

## A plank: WOOD_DEEP under DECK, with a lip along its lower edge, the light
## along its upper one and slats across it. `wave` lays the solve wave's gold
## over the part of it the front has already crossed, from the end the front
## came in at, so the light runs along the plank rather than switching it on.
func _plank(b, at: Vector2, box: Vector2, horiz: bool, r: float, face: Color,
		deep: Color, wave: Dictionary) -> void:
	b.fan(Face.Builder.round_rect(at, box, r), deep)
	var top := Vector2(box.x, box.y - PLANK_EDGE) if horiz else Vector2(box.x - PLANK_EDGE, box.y)
	b.fan(Face.Builder.round_rect(at, top, r), face)
	var bevel := maxf(1.5, minf(box.x, box.y) * PLANK_BEVEL)
	var lit := Color(Color(face, 1.0).lerp(Pal.SURFACE, PLANK_LIT), face.a)
	var strip := Vector2(top.x, bevel) if horiz else Vector2(bevel, top.y)
	b.fan(Face.Builder.round_rect(at, strip, bevel * 0.5), lit)
	var ink := Color(deep, SLAT_ALPHA * deep.a)
	var wide := maxf(SLAT_MIN, _cell() * SLAT_W)
	var step := _cell() * SLAT_STEP
	var span: float = box.x if horiz else box.y
	var s := step * 0.6
	while s < span - step * 0.3:
		var line := PackedVector2Array()
		if horiz:
			line.append(at + Vector2(s, 2.0))
			line.append(at + Vector2(s, box.y - 5.0))
		else:
			line.append(at + Vector2(2.0, s))
			line.append(at + Vector2(box.x - 5.0, s))
		b.stroke(line, wide, ink)
		s += step
	var u: float = float(wave.get("u", 0.0))
	if u <= 0.0:
		return
	var run: float = box.x if horiz else box.y
	var lit_at := at
	var lit_box := Vector2(run * u, box.y) if horiz else Vector2(box.x, run * u)
	if not bool(wave.get("low", true)):
		lit_at += Vector2(run * (1.0 - u), 0.0) if horiz else Vector2(0.0, run * (1.0 - u))
	b.fan(Face.Builder.round_rect(lit_at, lit_box, r),
		Color(Pal.WOOD_DEEP.lerp(Pal.SUN_RAY, WAVE_DEEP), face.a))
	var lit_top := Vector2(lit_box.x, lit_box.y - PLANK_EDGE) if horiz \
		else Vector2(lit_box.x - PLANK_EDGE, lit_box.y)
	b.fan(Face.Builder.round_rect(lit_at, lit_top, r),
		Color(Pal.DECK.lerp(Pal.SUN_RAY, WAVE_GOLD), face.a))
	var gold_strip := Vector2(lit_top.x, bevel) if horiz else Vector2(bevel, lit_top.y)
	b.fan(Face.Builder.round_rect(lit_at, gold_strip, bevel * 0.5),
		Color(Pal.SUN_RAY.lerp(Pal.SURFACE, PLANK_LIT), face.a))

## The halo a hint leaves round a whole run, so a given reads at a glance
## rather than plank by plank: a pale gold box under a dashed gold outline,
## the language every board in this game uses for a given.
func _glow(b, g: Dictionary, total: float) -> void:
	var s := _cell()
	var pad := s * GLOW_PAD
	var at: Vector2
	var box: Vector2
	if bool(g.horiz):
		at = Vector2(minf(g.a.x, g.b.x) - pad, g.a.y - total * 0.5 - pad)
		box = Vector2(absf(g.b.x - g.a.x) + 2.0 * pad, total + 2.0 * pad)
	else:
		at = Vector2(g.a.x - total * 0.5 - pad, minf(g.a.y, g.b.y) - pad)
		box = Vector2(total + 2.0 * pad, absf(g.b.y - g.a.y) + 2.0 * pad)
	var ring := Face.Builder.round_rect(at, box, pad * GLOW_RADIUS)
	b.fan(ring, Color(Pal.SUN_RAY, GLOW_ALPHA))
	for dash in _dashes(ring, s * DASH_ON, s * DASH_OFF):
		b.stroke(dash as PackedVector2Array, maxf(DASH_MIN, s * DASH_W), Pal.SUN_DEEP)

## An islet, seen from a little above: an earth drum standing in the water --
## its side in soil, darker at the waterline, with a stratum or two -- under
## a mossy top whose edge is lumpy and hangs a little over the side, a few
## sprouts along its back edge and now and then a white flower, and the paper
## coin on top that carries the number. The top's centre is the cell's, so a
## finger lands where it always did. The coin answers for the count:
## LEAF_TILE once it is met, BAD_TILE once the finger has pushed it over --
## **drawn wrong, never refused** (spec section 5) -- and gold once the
## solve's wave has reached it. `lean` is the nudge a refused islet takes,
## which is why the whole thing is drawn about `mid` rather than its cell.
func _islet(b, cell: Vector2i, t: float) -> void:
	var sc := _islet_scale(cell, t)
	if sc.x <= 0.001 or sc.y <= 0.001:
		return
	var r := _islet_r()
	var mid := _at(cell) + _islet_off(cell, t)
	var rx := r * sc.x
	var ry := r * sc.y
	var want: int = state.need_of(cell)
	var got: int = state.count(cell)
	var over := got > want
	_islet_body(b, cell, mid, rx, ry, over)
	_pennant(b, cell, mid, rx, ry * TOP_Y, t)
	# The coin: its shadow on the moss, its edge, its face. It flips over
	# when its number comes right and spins a turn for the twirl gag, both
	# read off its horizontal scale; a lantern stands a paper lantern on the
	# moss instead, glowing.
	var coin := _coin_colour(cell, t, want, got)
	var cx := rx * COIN_R * _coin_turn(cell, t)
	var cy := ry * COIN_R
	var at := mid - Vector2(0.0, ry * COIN_LIFT)
	if state.lanterns.has(cell):
		_lantern(b, cell, at, rx, ry, coin, t)
	else:
		Scenery.soft_disc(b, mid + Vector2(0.0, ry * COIN_LIP * 0.8), absf(cx) * 1.14 + 1.0, cy * 1.08,
			Color(Pal.TEXT, COIN_SHADOW))
		if absf(cx) > 0.5:
			b.ellipse(at + Vector2(0.0, ry * COIN_LIP), absf(cx), cy, coin.lerp(Pal.TEXT, COIN_EDGE))
			b.ellipse(at, absf(cx), cy, coin)
	if _solved_at == -INF:
		_slots(b, at, rx * COIN_R * SLOT_R, ry * COIN_R * SLOT_R, want, got, r)

## The islet under its coin: its shadow on the water, the drum, the moss and
## its sprouts and flower, about `mid` at radii `rx` and `ry`.
func _islet_body(b, cell: Vector2i, mid: Vector2, rx: float, ry: float, over: bool) -> void:
	var r := _islet_r()
	var seed_i := cell.x * 17 + cell.y * 5
	var top_y := ry * TOP_Y
	var depth := ry * SIDE
	Scenery.soft_disc(b, mid + Vector2(0.0, depth + top_y * 0.55), rx * SHADOW_RX,
		ry * SHADOW_RY, Color(Pal.WATER.lerp(Pal.TEXT, SEA_SHADE), SHADOW_ALPHA))
	# The drum's side: its foot dark with wet, then the soil over it.
	var sx := rx * SIDE_R
	var sy := top_y * SIDE_R
	b.ellipse(mid + Vector2(0.0, depth), sx, sy, Pal.BED_FURROW)
	b.fan(Face.Builder.round_rect(mid - Vector2(sx, 0.0), Vector2(2.0 * sx, depth * WET_AT), 0.0),
		Pal.CAMP_SOIL)
	b.ellipse(mid + Vector2(0.0, depth * WET_AT), sx, sy, Pal.CAMP_SOIL)
	for k in 2:
		var y := mid.y + depth * (0.35 + 0.3 * k) + sy * 0.55
		var x0 := mid.x + sx * (-0.7 + 0.5 * _hash(seed_i, 61 + k))
		b.stroke(PackedVector2Array([Vector2(x0, y), Vector2(x0 + sx * 0.45, y + sy * 0.06)]),
			maxf(1.0, r * 0.05), Color(Pal.BED_FURROW, 0.55))
	# The mossy top: its hanging lip in shade, the lit moss, then its face.
	var tone := (_hash(cell.x, cell.y) - 0.5) * 2.0 * TONE
	var turf: Color = Pal.BANK.lightened(tone) if tone > 0.0 else Pal.BANK.darkened(-tone)
	if over:
		turf = turf.lerp(Pal.BAD, OVER_MIX)
	b.fan(_moss(mid + Vector2(0.0, ry * TURF_DROP), rx, top_y, seed_i, true),
		Pal.BANK.lerp(Pal.TEXT, BANK_DEEP))
	b.fan(_moss(mid, rx, top_y, seed_i, false), turf.lerp(Pal.LEAF_LIGHT, TURF_LIT))
	b.ellipse(mid + Vector2(0.0, top_y * TURF_TOP), rx * TURF_R, top_y * TURF_R, turf)
	# Sprouts on the back edge, and a flower on some.
	var sprouts := 2 + int(_hash(seed_i, 63) * 2.0)
	for k in sprouts:
		var a := -PI * 0.5 + (float(k) - (sprouts - 1) * 0.5) * 0.5 \
			+ (_hash(seed_i, 65 + k) - 0.5) * 0.3
		var root := mid + Vector2(cos(a) * rx * 0.8, sin(a) * top_y * 0.8)
		_sprout(b, root, r * TUFT_H * ry / r, Pal.LEAF_DEEP.lerp(Pal.BANK, 0.3))
	if _hash(seed_i, 67) < FLOWER_SHARE:
		var side := -1.0 if _hash(seed_i, 69) < 0.5 else 1.0
		_flower(b, mid + Vector2(side * rx * 0.72, top_y * 0.3), r * 0.16)

## The slots round a coin: one arc per plank the number asks for (per islet,
## on a lantern), set round its lower half and filled in wood as they come,
## so a number reads as "this many planks, and this many are in". Over its
## number they all go rose.
func _slots(b, at: Vector2, rx: float, ry: float, want: int, got: int, r: float,
		over := false) -> void:
	var w := maxf(SLOT_MIN, r * SLOT_W)
	over = over or got > want
	# Round the whole coin, starting at the top, clockwise.
	var step := TAU / float(want)
	var gap := minf(SLOT_GAP, step * 0.4)
	for k in want:
		var a0 := -PI * 0.5 + step * float(k) + gap * 0.5
		var a1 := a0 + step - gap
		var pts := PackedVector2Array()
		var segs := maxi(3, int(ceil((a1 - a0) / 0.2)))
		for q in segs + 1:
			var a := lerpf(a0, a1, float(q) / float(segs))
			pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
		# An empty slot is a socket pressed into the moss; a filled one is a
		# plank's end in wood; a met islet's all go leaf; over, all rose.
		var ink: Color
		if over:
			ink = Pal.BAD
		elif k < got:
			ink = Pal.DECK if got < want else Pal.LEAF_DEEP
		else:
			ink = Pal.BANK.lerp(Pal.TEXT, 0.38)
		if k < got or over:
			b.stroke(pts, w + 2.0, Pal.WOOD_DEEP if not over and got < want else ink.darkened(0.25))
		b.stroke(pts, w, ink)

## How wide the coin stands, 1 face on: it flips over (|cos|, through zero)
## as its number comes right and spins a full turn for the twirl.
func _coin_turn(cell: Vector2i, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var k := 1.0
	if _flip.has(cell):
		var e: float = t - float(_flip[cell])
		if e > 0.0 and e < COIN_FLIP:
			k *= absf(cos(PI * e / COIN_FLIP))
	if _twirl.has(cell):
		var e2: float = t - float(_twirl[cell])
		if e2 > 0.0 and e2 < TWIRL_TIME:
			k *= cos(TAU * _ease(e2 / TWIRL_TIME))
	return k

## Whether the coin is past the middle of its flip: the met wash shows from
## there on, so it turns over into its new colour.
func _flipped(cell: Vector2i, t: float) -> bool:
	if Motion.reduce or not _flip.has(cell):
		return true
	return t - float(_flip[cell]) >= COIN_FLIP * 0.5

## A lantern on the moss: a warm glow on the water round it, a paper body in
## the coin's own wash, a cap and a foot in wood, ribs, and a little handle.
## Its number goes on the paper like any coin's.
func _lantern(b, cell: Vector2i, at: Vector2, rx: float, ry: float, paper: Color, t: float) -> void:
	_lantern_draw(b, at, rx, ry, absf(_coin_turn(cell, t)), _lantern_inks(paper, _lantern_glow(t)))

## How bright the lanterns glow at `t`: the party's flash over the standing
## glow.
func _lantern_glow(t: float) -> float:
	var glow := LANTERN_GLOW_ALPHA
	if _glow_at < INF and t >= _glow_at:
		glow += 0.3 * Motion.flash_level(t - _glow_at, 0.2, 0.8)
	return glow

## A lantern's five inks: its glow, the paper's edge and face, the ribs and
## the wood.
static func _lantern_inks(paper: Color, glow: float) -> Array:
	return [Color(Pal.SUN_RAY, glow), paper.lerp(Pal.TEXT, COIN_EDGE), paper.lerp(Pal.SUN_RAY, 0.35),
		Color(Pal.SUN_DEEP, 0.35), Pal.WOOD_DEEP]

## A lantern `k` face on, in `inks` (`_lantern_inks`, or slot colours for its
## shape).
func _lantern_draw(b, at: Vector2, rx: float, ry: float, k: float, inks: Array) -> void:
	Scenery.soft_disc(b, at, rx * LANTERN_GLOW, ry * LANTERN_GLOW, inks[0])
	var w := rx * 0.62 * k
	var h := ry * 0.72
	if w > 0.5:
		b.fan(Face.Builder.round_rect(at - Vector2(w, h) + Vector2(0.0, ry * 0.08), Vector2(2.0 * w, 2.0 * h), w * 0.7),
			inks[1])
		b.fan(Face.Builder.round_rect(at - Vector2(w, h), Vector2(2.0 * w, 2.0 * h), w * 0.7),
			inks[2])
		for sx in [-0.5, 0.5]:
			b.stroke(PackedVector2Array([at + Vector2(w * sx, -h * 0.8), at + Vector2(w * sx * 1.1, 0.0),
				at + Vector2(w * sx, h * 0.8)]), maxf(1.0, rx * 0.03), inks[3])
	var cap := Vector2(rx * 0.42 * maxf(k, 0.3), ry * 0.14)
	b.fan(Face.Builder.round_rect(at + Vector2(-cap.x, -h - cap.y), cap * Vector2(2.0, 1.6), cap.y * 0.5), inks[4])
	b.fan(Face.Builder.round_rect(at + Vector2(-cap.x, h - cap.y * 0.4), cap * Vector2(2.0, 1.4), cap.y * 0.5), inks[4])
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, -h - cap.y), cap.x * 0.6, PI, TAU),
		maxf(1.5, rx * 0.05), inks[4])

## A met islet's pennant on the back of its moss: a little pole and a
## triangular flag, popping up when the number comes right and folding back
## down when it comes apart.
func _pennant(b, cell: Vector2i, mid: Vector2, rx: float, top_y: float, t: float) -> void:
	var k := _flag_k(cell, t)
	if k <= 0.01:
		return
	_pennant_draw(b, mid + Vector2(rx * 0.55, -top_y * 0.55), _islet_r() * FLAG_H * k, rx, _hue_of(cell))

## How far up an islet's pennant stands at `t`, 0 when it has none.
func _flag_k(cell: Vector2i, t: float) -> float:
	if not _flag.has(cell):
		return 0.0
	var f: Dictionary = _flag[cell]
	var e: float = t - float(f.at)
	if bool(f.open):
		return 1.0 if Motion.reduce else Motion.pop_in_scale(e, FLAG_TIME).y
	if Motion.reduce or e >= FLAG_FOLD:
		return 0.0
	return 1.0 - e / FLAG_FOLD

static func _hue_of(cell: Vector2i) -> int:
	return posmod(cell.x * 3 + cell.y, 4)

## A pennant `h` tall standing at `foot`, in hue `hue`.
func _pennant_draw(b, foot: Vector2, h: float, rx: float, hue: int) -> void:
	var top := foot - Vector2(0.0, h)
	b.stroke(PackedVector2Array([foot, top]), maxf(1.5, rx * 0.06), Pal.WOOD_DEEP)
	var fw := h * 0.55
	var ink: Color = [Pal.FLOWER, Pal.SUN, Pal.ACCENT, Pal.BERRY][hue]
	b.polygon(PackedVector2Array([top, top + Vector2(fw, h * 0.16), top + Vector2(0.0, h * 0.34)]), ink)
	b.disc(top, maxf(1.5, rx * 0.06), Pal.SUN_RAY)

## The moss's outline about `c`: an ellipse whose edge is lumpy off the hash,
## and, for the hanging lip (`drips`), a few tongues that run a little down
## the front of the drum.
func _moss(c: Vector2, rx: float, ry: float, seed_i: int, drips: bool) -> PackedVector2Array:
	var n := 40
	var ph := _hash(seed_i, 71) * TAU
	var pts := PackedVector2Array()
	pts.resize(n)
	for k in n:
		var a := TAU * float(k) / float(n)
		var wob := 1.0 + 0.045 * sin(9.0 * a + ph)
		var p := c + Vector2(cos(a) * rx, sin(a) * ry) * wob
		if drips and sin(a) > 0.0:
			p.y += ry * 0.1 * maxf(0.0, sin(4.0 * a + ph)) * sin(a)
		pts[k] = p
	return pts

## A sprout: three small leaves out of `root`, standing up.
func _sprout(b, root: Vector2, h: float, col: Color) -> void:
	_leaf(b, root, -PI * 0.5 - 0.55, h * 0.8, h * 0.42, col)
	_leaf(b, root, -PI * 0.5 + 0.55, h * 0.8, h * 0.42, col.lerp(Pal.LEAF_LIGHT, 0.3))
	_leaf(b, root, -PI * 0.5, h, h * 0.36, col.lerp(Pal.LEAF_LIGHT, 0.15))

## What an islet's coin is washed with at `t`: paper, LEAF_TILE met, BAD_TILE
## over, gold as the wave reaches it (with the wave's flare on the way), and
## the glint's shine over whichever.
func _coin_colour(cell: Vector2i, t: float, want: int, got: int) -> Color:
	var coin: Color = Pal.SURFACE
	if got > want:
		coin = Pal.BAD_TILE
	elif got == want and _flipped(cell, t):
		coin = Pal.LEAF_TILE.lerp(Pal.GOOD, COIN_MET)
	var arrived := _arrived(cell, t)
	if arrived >= 0.0:
		coin = coin.lerp(Pal.SUN_TILE, clampf(arrived / WAVE_EDGE, 0.0, 1.0))
		coin = coin.lerp(Pal.SUN_RAY, Motion.flash_level(arrived, WAVE_EDGE) * WAVE_FLARE)
	return coin.lerp(Pal.SURFACE, _shine(_glint, cell, t) * SHINE)

## The ink an islet's number is drawn in: TEXT, LEAF_DEEP met, BAD over, and
## the plaque's brown once the wave has turned its coin gold.
func _number_ink(cell: Vector2i, t: float) -> Color:
	var want: int = state.need_of(cell)
	var got: int = state.count(cell)
	var ink: Color = Pal.TEXT
	if got > want:
		ink = Pal.BAD
	elif got == want and _flipped(cell, t):
		ink = Pal.LEAF_DEEP
	var arrived := _arrived(cell, t)
	if arrived >= 0.0:
		ink = ink.lerp(Pal.PLAQUE_DEEP, clampf(arrived / WAVE_EDGE, 0.0, 1.0))
	return ink

## How far into its glint `key` is in `glints`, 0 to 1 and back.
func _shine(glints: Dictionary, key, t: float) -> float:
	if Motion.reduce or not glints.has(key):
		return 0.0
	var e: float = t - float(glints[key])
	if e <= 0.0 or e >= GLINT_TIME:
		return 0.0
	return sin(PI * e / GLINT_TIME)

## An islet's scale: the entrance pop it came in on, the bump it took when it
## met its number or a plank landed on it, and the bump the wave's front gives
## it on the way past. Every one of them is a reader off `core/motion.gd`
## handed the seconds since its own moment began, and they multiply, so an
## islet that is bumped mid-entrance does both rather than losing one.
func _islet_scale(cell: Vector2i, t: float) -> Vector2:
	var sc := Motion.pop_in_scale(t - _opened - _enter_delay(cell.x + cell.y))
	sc *= Motion.bump_scale(t - float(_met_at.get(cell, -1.0e9)))
	sc *= Motion.bump_scale(t - float(_land_at.get(cell, -1.0e9)), LAND_BUMP)
	if cell == _press_cell:
		sc *= Motion.press_scale(t - _press_at,
			-1.0 if _press_up < 0.0 else t - _press_up)
	var arrived := _arrived(cell, t)
	if arrived >= 0.0:
		sc *= Motion.bump_scale(arrived)
	if _pulse.has(cell) and not Motion.reduce:
		for beat in SPLIT_PULSES:
			sc *= Motion.bump_scale(t - float(_pulse[cell]) - beat * SPLIT_BEAT)
	return sc

## Where an islet stands against its cell: the lean a refused drag gives the
## islet under the finger, the shiver of one the finger has just pushed over
## its number, the hop Reset's wave carries it away on, and the hop the
## solve's wave gives it as it arrives.
##
## **The over-filled islet takes `shiver_offset` and not `nudge_offset`, on
## purpose.** `shiver_offset` is the vocabulary's reader for a shiver, which
## is the table's Refused row; `nudge_offset` is the *directional lean* a
## neighbour takes when something lands beside it, and on this board it is
## already spoken for by `_lean` above. The plan's prose said nudge; the
## user confirmed the shiver on 2026-09-20. Do not "correct" it back.
func _islet_off(cell: Vector2i, t: float) -> Vector2:
	var off := _lean(cell, t)
	off.x += Motion.shiver_offset(t - float(_shiver_at.get(cell, -1.0e9)))
	off.y += Motion.hop_lift(t - float(_hop_at.get(cell, -1.0e9)),
		Motion.RESET_HOP, Motion.HOP_TIME)
	var arrived := _arrived(cell, t)
	if arrived >= 0.0:
		off.y += Motion.hop_lift(arrived, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
	if _dancing(t):
		# The party: every islet hops on the beat, neighbours off by half a
		# beat, so the sea bobs like a crowd.
		var e := t - _dance_at - float((cell.x + cell.y) % 2) * DANCE_BEAT * 0.5
		if e > 0.0:
			off.y += DANCE_HOP * absf(sin(PI * e / DANCE_BEAT)) * (_cell() / 100.0)
	return off

## The numbers, over the mesh, one `draw_string` each, standing on their
## coins. Each one takes its islet's own scale and the page's entrance
## through one `draw_set_transform_matrix` -- Nonogram's way with its clue
## lines -- so a glyph pops in, bumps, hops and leans with the coin it stands
## on rather than floating over a piece that has moved out from under it.
func _draw_numbers(t: float, page: Transform2D, seen: float) -> void:
	var r := _islet_r()
	var font: Font = CozyTheme.display(700)
	var px := maxi(1, int(round(r * NUMBER_SIZE)))
	# A number standing still is drawn under the page's own transform, so the
	# resting ones batch together (a transform set per glyph is a draw call
	# per glyph); only one scaled or turning takes one of its own.
	draw_set_transform_matrix(page)
	var plain := true
	for cell in state.islets:
		var sc := _islet_scale(cell, t)
		if sc.x <= 0.001 or sc.y <= 0.001:
			continue
		var ink := _number_ink(cell, t)
		var mid := _at(cell) + _islet_off(cell, t)
		var turn := _coin_turn(cell, t)
		if absf(turn) < 0.08:
			continue
		var sx := sc.x * absf(turn)
		var own := sx != 1.0 or sc.y != 1.0
		if own:
			draw_set_transform_matrix(page * Transform2D(0.0, Vector2(sx, sc.y), 0.0,
				Vector2(mid.x * (1.0 - sx), mid.y * (1.0 - sc.y))))
		elif not plain:
			draw_set_transform_matrix(page)
		plain = not own
		_glyph(font, px, str(state.need_of(cell)), Color(ink, ink.a * seen),
			mid + Vector2(0.0, r * (NUMBER_AT - COIN_LIFT)))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## One glyph centred on `at`, as Nonogram centres a clue number.
func _glyph(font: Font, px: int, text: String, ink: Color, at: Vector2) -> void:
	if ink.a <= 0.0:
		return
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var rise := font.get_height(px) * 0.5 - font.get_descent(px)
	draw_string(font, at + Vector2(-wide * 0.5, rise), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)

## The closed outline `pts` cut into dashes of `on` with `off` between them.
static func _dashes(pts: PackedVector2Array, on: float, off: float) -> Array:
	var out: Array = []
	if pts.size() < 2 or on <= 0.0 or off <= 0.0:
		return out
	var cur := PackedVector2Array([pts[0]])
	var lit := true
	var spent := 0.0
	for i in pts.size():
		var a := pts[i]
		var z := pts[(i + 1) % pts.size()]
		var span := a.distance_to(z)
		if span <= 0.001:
			continue
		var walked := 0.0
		while walked < span:
			# Never zero: a dash that ended exactly on a corner would otherwise
			# walk nowhere for ever.
			var want := maxf((on if lit else off) - spent, 0.001)
			if walked + want >= span:
				spent += span - walked
				walked = span
				if lit:
					cur.append(z)
			else:
				walked += want
				var p := a.lerp(z, walked / span)
				if lit:
					cur.append(p)
					if cur.size() >= 2:
						out.append(cur)
					cur = PackedVector2Array()
				else:
					cur = PackedVector2Array([p])
				lit = not lit
				spent = 0.0
	if lit and cur.size() >= 2:
		out.append(cur)
	return out

## A settled number in 0..1 from two ints: what keeps the ripples from lying
## in a comb without a seeded generator in the drawing.
static func _hash(a: int, b: int) -> float:
	return float(posmod(hash(Vector2i(a, b)), 1000)) / 1000.0

# --- the finger ---

## Press an islet, drag at the one facing it, let go: a plank goes in (on
## Easy and Medium the run cycles 0-1-2-0). A tap on the water between two
## islets does the same for that lane -- the way most tellings of the puzzle
## are played -- and a tap on an islet reads its number out.
##
## The lit lane under the finger, the two refusals and everything they put on
## the tip card land with the rest of the gesture; this is the path the win
## harness drives, and it goes through the state exactly as a finger does.
func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts or _sinking_busy:
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			if _press(event.position):
				accept_event()
		else:
			if _from != State.NOWHERE or _on_run != "":
				_release(event.position)
				accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) \
			and _from != State.NOWHERE:
		_aim_at(event.position)
		accept_event()

## True when the press landed on something this board answers for.
func _press(at: Vector2) -> bool:
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	var cell := local_to_cell(at)
	if cell == State.NOWHERE:
		return false
	if state.is_islet(cell):
		# The disc and a little air round it, not the whole cell: an islet is
		# round and the corners of its cell are water.
		if at.distance_to(_at(cell)) > _islet_r() * GRAB:
			return false
		_from = cell
		_press_cell = cell
		_press_at = _now()
		_press_up = -1.0
		_busy_for(Motion.PRESS_TIME)
		_refresh()
		return true
	_on_run = _lane_over(cell)
	return _on_run != ""

## The lane whose water covers `cell`: the laid run there if there is one,
## else the only lane through it. A cell two bare lanes cross belongs to
## neither -- which one was meant is a guess, and the drag is there for it.
func _lane_over(cell: Vector2i) -> String:
	var through: Array = []
	for key in state.lanes:
		if (state.lanes[key].cells as Array).has(cell):
			if state.planks(String(key)) > 0:
				return String(key)
			through.append(String(key))
	return through[0] if through.size() == 1 else ""

## The drag takes its dominant axis and, once the travel has passed half a
## cell, names the lane to the first islet that way -- so the run the finger
## is asking for is never a guess about which pair was meant.
func _aim_at(at: Vector2) -> void:
	var s := _cell()
	var d := at - _at(_from)
	if absf(d.x) < s * 0.5 and absf(d.y) < s * 0.5:
		if _aim_dir != Vector2i.ZERO:
			_aim = ""
			_aim_dir = Vector2i.ZERO
			_refresh()
		return
	var dir: Vector2i
	if absf(d.y) > absf(d.x):
		dir = Vector2i(0, 1 if d.y > 0.0 else -1)
	else:
		dir = Vector2i(1 if d.x > 0.0 else -1, 0)
	if dir == _aim_dir:
		return
	_aim_dir = dir
	var other := state.facing(_from, dir)
	_aim = "" if other == State.NOWHERE else state.lane_at(_from, other)
	_refresh()

## Let go. The ways it can end, and there is no other: the lit lane takes a
## plank, a refused lane flashes and names its rule, a tap on the water lays
## a plank on that lane, or a tap on an islet reads its number out.
##
## **A press that never travelled half a cell is not a gesture and is not
## refused** -- the finger went down on an islet and came up again, which is
## how a player reads a number, so the line reads it for them.
func _release(at := Vector2(-1.0e9, -1.0e9)) -> void:
	var from := _from
	var lane := _aim
	var dir := _aim_dir
	var tapped := _on_run
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	if _press_cell != State.NOWHERE and _press_up < 0.0:
		_press_up = _now()
		_busy_for(Motion.RELEASE_TIME)
	if from != State.NOWHERE:
		if dir == Vector2i.ZERO:
			_read_islet(from)
			_refresh()
			return
		if lane == "":
			_refuse_at(from, dir, "", "", TIP_NONE)
			return
		var blocker := state.blocked_by(lane)
		if blocker != "":
			_refuse_at(from, dir, lane, blocker, TIP_CROSS)
			return
		_move(lane, from)
		return
	# A tap on the water counts only where it lifts: a finger that slid off
	# the lane has changed its mind, and on Hard that must not cost a heart.
	if tapped != "" and at.x > -1.0e8 and _lane_over(local_to_cell(at)) != tapped:
		tapped = ""
	if tapped != "":
		var blocked := state.blocked_by(tapped)
		if blocked != "":
			var la: Dictionary = state.lanes[tapped]
			var d := Vector2i(signi(la.b.x - la.a.x), signi(la.b.y - la.a.y))
			_refuse_at(la.a, d, tapped, blocked, TIP_CROSS)
			return
		_move(tapped, State.NOWHERE)
		return
	_refresh()

## One plank's worth of move on `key`, laid across from `from` when a finger
## dragged it (NOWHERE for a tap on the water): judged against the answer on
## Hard and Insane, cycled 0-1-2-0 on Easy and Medium.
func _move(key: String, from: Vector2i) -> void:
	if state.judged():
		_judged_move(key, from)
		return
	# Insane counts moves: a step the budget cannot pay for is not taken.
	var cost: int = state.move_cost(key) if max_moves > 0 else 0
	if cost > moves_left:
		_refresh()
		return
	var before: int = state.planks(key)
	var snap := _snapshot()
	if state.cycle(key) == before:
		_refresh()
		return
	var laid := state.planks(key) > before
	# The cycle runs 0-1-2 and back to 0: a plank laid, or the run lifted.
	fx.cue("place" if laid else "remove")
	if from != State.NOWHERE:
		_last = from
	else:
		_last = state.lanes[key].a
	_after_move(snap, from, key)
	if laid and not _pushed_over(key):
		_on_right(key)
	else:
		_break_streak()
	_spend(cost, _now() + (0.0 if Motion.reduce else LAY_TIME))

## Whether either end of `key` now stands over its number.
func _pushed_over(key: String) -> bool:
	var lane: Dictionary = state.lanes[key]
	for cell in [lane.a, lane.b]:
		if state.count(cell) > state.need_of(cell):
			return true
	return false

## Hard and Insane: a plank is only ever added, and it is held against the
## answer as it lands. A right one stays; a wrong one rolls out, lands, cracks
## and sinks and costs a heart; a full run, or a lane a heart already ruled,
## is refused for free.
func _judged_move(key: String, from: Vector2i) -> void:
	var before: int = state.planks(key)
	var snap := _snapshot()
	var got: int = state.add(key)
	match got:
		State.Judged.RIGHT:
			fx.cue("place")
			_last = from if from != State.NOWHERE else state.lanes[key].a
			_after_move(snap, from, key)
			_on_right(key)
		State.Judged.WRONG:
			_wrong_plank(key, before, from)
		State.Judged.FULL:
			_speak(tr("BR_FULL"), Face.Expr.HAPPY)
			fx.cue("locked")
			_refresh()
		State.Judged.RULED:
			_speak(tr("BR_RULED"), Face.Expr.HAPPY)
			fx.cue("ruled")
			_refresh()
		_:
			_refresh()

## A tap on an islet reads it out: how many planks it wants and has, or on a
## lantern how many islets it wants to be joined to.
func _read_islet(cell: Vector2i) -> void:
	var want := state.need_of(cell)
	var got := state.count(cell)
	var line: String
	var base := "BR_READ_LANTERN" if state.lanterns.has(cell) else "BR_READ"
	if want == 1:
		line = tr(base + "_ONE") % got
	else:
		line = tr(base + "_N") % [want, got]
	_speak(line, Face.Expr.HAPPY)

## A refused drag: the rule on the tip card, and the flash and the lean that
## carry it. The two refusals are the whole list -- an islet pushed over its
## number is drawn wrong and never comes through here.
##
## Reduce motion keeps the line and drops the movement, so nothing is recorded
## and the board does not redraw for six tenths of a second to show nothing.
func _refuse_at(from: Vector2i, dir: Vector2i, key: String, blocker: String,
		line: String) -> void:
	_speak(tr(line), Face.Expr.STRAIN)
	_break_streak()
	fx.cue("locked")
	if not Motion.reduce:
		_refuse = {"at": _now(), "from": from, "dir": dir, "key": key,
			"blocker": blocker}
		_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)
	_refresh()

## Every move clears the last Check's marks -- the board has changed under
## them -- and the refusal standing over it, hands the pieces that changed
## their moments, and counts itself, which is what ends the puzzle when the
## last plank lands on one single network.
func _after_move(snap: Dictionary, src := State.NOWHERE, key := "") -> void:
	_wrong = {}
	_refuse = {}
	_coach_lane = ""
	_hold_until = 0.0
	_resume_tips()
	_by_hand = true
	_settle(snap, Callable(), src)
	_network(key)
	_by_hand = false
	note_move()

## What the move did to the network: two groups joined by it sparkle along
## the lane, and the near-miss -- every number met with the islets still in
## groups -- is named, and the groups that are not the biggest pulse, so the
## player can see what is left to join.
func _network(key: String) -> void:
	var groups := state.groups()
	var was := _groups
	_groups = groups.size()
	if state.is_solved():
		return
	var land := 0.0 if Motion.reduce else LAY_TIME * LAND_AT
	if _groups < was and key != "" and state.planks(key) > 0 and _groups > 1:
		_after(land, func() -> void:
			if is_done() or not state.lanes.has(key):
				return
			fx.sparkle(_lane_middle(key), Pal.SUN_RAY)
			fx.cue("join"))
	if _groups > 1 and state.numbers_met():
		_near_miss(groups, land)

## Every number met and the islets in `groups.size()` groups: the line says
## so, and every islet outside the biggest group pulses a few beats with a
## rose ring, so the split is on the board and not only in the words.
func _near_miss(groups: Array, delay: float) -> void:
	_pulse = {}
	var biggest := 0
	for k in groups.size():
		if (groups[k] as Array).size() > (groups[biggest] as Array).size():
			biggest = k
	var t := _now() + delay
	var hand := _by_hand
	for k in groups.size():
		if k == biggest:
			continue
		for cell in groups[k]:
			_pulse[cell] = t
	_busy_for(delay + SPLIT_BEAT * SPLIT_PULSES + Motion.BUMP_TIME)
	_after(delay, func() -> void:
		if is_done() or not state.numbers_met() or state.groups().size() <= 1:
			return
		_speak(tr("BR_SPLIT") % groups.size(), Face.Expr.WORRIED)
		fx.cue("split")
		if hand:
			fx.buzz(Haptics.WARN)
		for cell in _pulse:
			if not Motion.reduce:
				for beat in SPLIT_PULSES:
					_after(beat * SPLIT_BEAT, func() -> void:
						if not is_done():
							fx.ring(_at(cell), _islet_r() * RING_R, Pal.FLOWER)))

# --- what changed, and when each piece answers for it ---

## The board as it stands, taken before a move so `_settle` can diff against
## it. An islet is kept as its degree **less** its number, so zero is met and
## anything above it is over: the two states the drawing answers for.
func _snapshot() -> Dictionary:
	var runs := {}
	for key in state.runs:
		runs[key] = int(state.runs[key])
	var islets := {}
	for cell in state.islets:
		islets[cell] = state.count(cell) - state.need_of(cell)
	return {"runs": runs, "islets": islets}

## Diffs the board against `snap` and hands every piece that changed the
## moment it begins to move, with `when` -- a Callable taking a lane key --
## saying how long that piece waits. Reset passes its wave; a move passes
## nothing and everything answers at once. This is Queens' `_settle` in this
## board's terms: one place that decides who moves, and one Callable that
## decides when. `src` is the islet the finger dragged from, when there was
## one: a plank rolls out of it and lands on the far islet, and a run lifted
## to nothing is drawn back into it. **The far end answers when the plank
## lands** -- its bump, the splash, and any islet the move met, whose ring and
## glint wait for the landing so the count comes right as the wood touches.
func _settle(snap: Dictionary, when := Callable(), src := State.NOWHERE) -> void:
	var t := _now()
	var was_runs: Dictionary = snap["runs"]
	var was_islets: Dictionary = snap["islets"]
	var keys := {}
	# `snap` may come from before a board the islets are no longer on.
	for key in was_runs:
		keys[key] = true
	for key in state.runs:
		keys[key] = true
	var longest := 0.0
	var landed := 0.0
	for k in keys:
		var key := String(k)
		var was := int(was_runs.get(key, 0))
		var now_count := state.planks(key)
		if now_count == was:
			continue
		var delay := 0.0
		if when.is_valid():
			delay = float(when.call(key))
		longest = maxf(longest, delay)
		var lane: Dictionary = state.lanes[key]
		var from := src if src == lane.a or src == lane.b else State.NOWHERE
		if now_count > was:
			_laid[key] = {"at": t + delay, "from": was, "src": from}
			var land := 0.0 if Motion.reduce else LAY_TIME * LAND_AT
			landed = maxf(landed, delay + land)
			if from != State.NOWHERE:
				var far: Vector2i = lane.b if from == lane.a else lane.a
				_land_at[far] = t + delay + land
				_later(t + delay + land, _splash.bind(key, far))
			else:
				_later(t + delay + land, _splash.bind(key, State.NOWHERE))
		else:
			_laid.erase(key)
			# Only a run that went **to zero** leaves a ghost: a run going 3
			# to 2 re-centres the planks it keeps, so there is no one plank
			# that left for a ghost to stand in for.
			if now_count == 0:
				_ghosts.append({"key": key, "count": was, "at": t + delay, "src": from})
	for cell in state.islets:
		var was_d := int(was_islets.get(cell, -999))
		var now_d := state.count(cell) - state.need_of(cell)
		if now_d == was_d:
			continue
		if now_d == 0:
			_met_at[cell] = t + landed
			_flip[cell] = t + landed
			_glint[cell] = t + landed + GLINT_LAG
			_later(t + landed, _met.bind(cell, _by_hand))
		else:
			if was_d == 0 and _flag.has(cell) and bool(_flag[cell].open):
				_flag[cell] = {"at": t, "open": false}
			if now_d > 0 and was_d <= 0:
				_shiver_at[cell] = t
				fx.cue("over")
				if _by_hand:
					fx.buzz(Haptics.WARN)
	_busy_for(maxf(longest + maxf(LAY_TIME + SETTLE_TIME, maxf(Motion.BUMP_TIME,
		maxf(PULL_TIME, Motion.SHIVER_TIME))), landed + GLINT_LAG + GLINT_TIME))
	_refresh()

## The water a landing plank throws up: at the far islet's beach when it was
## laid across from the other, at the lane's middle when it grew from there.
func _splash(key: String, far: Vector2i) -> void:
	if not state.lanes.has(key):
		return
	var at := _lane_middle(key)
	if far != State.NOWHERE:
		var g := _lane_ends(key)
		at = Vector2(g.a) if Vector2(g.a).distance_to(_at(far)) < Vector2(g.b).distance_to(_at(far)) \
			else Vector2(g.b)
	fx.puff(at, Pal.WATER_HI)

## An islet that has just come right: its ring and its note, its pennant
## up, and three times in five a gag.
func _met(cell: Vector2i, by_hand := false) -> void:
	# The solve has already raised every pennant and plays its own wave.
	if is_done() or not state.is_islet(cell) or state.count(cell) != state.need_of(cell):
		return
	fx.ring(_at(cell), _islet_r() * RING_R, Pal.GOOD)
	fx.cue("met")
	if by_hand:
		fx.buzz(Haptics.BUMP)
	_flag[cell] = {"at": _now(), "open": true}
	_busy_for(FLAG_TIME)
	_gag(cell)

## The middle of a lane in the board's own pixels: where a plank's puff goes.
func _lane_middle(key: String) -> Vector2:
	var g := _lane_ends(key)
	return (Vector2(g.a) + Vector2(g.b)) * 0.5

# --- the sprout's line ---

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

## How long a spoken line owns the card before the tips come back.
const SAY_HOLD := 3.2

## A line that owns the card for SAY_HOLD seconds, after which the cycling
## tips resume (Sudoku's).
func _speak(line: String, mood: int) -> void:
	_say(line, mood)
	_hold_until = _now() + SAY_HOLD
	if get_tree() == null:
		return
	get_tree().create_timer(SAY_HOLD).timeout.connect(_resume_tips)

func _resume_tips() -> void:
	if is_done() or out_of_hearts or _now() < _hold_until - 0.01:
		return
	_say(_tip(_tip_idx), Face.Expr.HAPPY)

func _tip(k: int) -> String:
	var tips := _tips()
	return tr(tips[k % tips.size()])

func _cycle_tip() -> void:
	if is_done() or out_of_hearts or _now() < _hold_until:
		return
	_tip_idx = (_tip_idx + 1) % _tips().size()
	_say(_tip(_tip_idx), Face.Expr.HAPPY)

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and not _sinking_busy and state.can_undo()

## An undo is not a move, so it does not go through `note_move()` and has to
## ask the contract itself -- `core/puzzle_base.gd` says hints and undos call
## `check_solved()` directly. Undo can only ever return to a position that was
## already checked when it was made, so today it never fires; leaving the call
## out would make that invariant load-bearing and nothing states or tests it.
func undo() -> bool:
	if is_done() or out_of_hearts or _sinking_busy:
		return false
	var snap := _snapshot()
	if not state.undo():
		return false
	_wrong = {}
	_refuse = {}
	_break_streak()
	_resume_tips()
	_settle(snap)
	_network("")
	fx.cue("undo")
	moved.emit()
	check_solved()
	return true

func hints_left() -> int:
	return maxi(0, int(State.HINTS[state.band]) + hints_extra - hints_used)

## Lays one plank the answer has and the board lacks -- never an overshoot, so
## a hint can never itself be the thing that pushes an islet over its number.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or out_of_hearts or _sinking_busy:
		return false
	var snap := _snapshot()
	var key := state.hint()
	if key == "":
		return false
	hints_used += 1
	_given[key] = true
	_wrong = {}
	_refuse = {}
	_speak(tr("BR_HINT"), Face.Expr.HAPPY)
	_coach_lane = ""
	_settle(snap)
	_network(key)
	fx.cue("hint")
	# The hint's own pair, over the plank the answer wanted: a ring out of the
	# lane and sparkles rising off it, which is the Hint row of the table.
	var at := _lane_middle(key)
	fx.ring(at, _islet_r() * BEAM_RING, Pal.SUN)
	fx.sparkle(at, Pal.SUN)
	_busy_for(Motion.RING_TIME)
	moved.emit()
	check_solved()
	return true

## Marks the runs carrying more planks than the answer lays there. **An
## under-laid run is unfinished and not wrong**: marking every lane still
## missing would print the answer, which is the one thing this screen does not
## do (spec section 10). Easy and Medium only: Hard and Insane judge every
## plank as it lands, so there is nothing left for Check to find.
func check() -> int:
	if is_done() or max_hearts > 0:
		return 0
	checks += 1
	var wrong: Array = state.wrong_runs()
	var t := _now()
	_wrong = {}
	_refuse = {}
	for key in wrong:
		_wrong[key] = t
	if not wrong.is_empty():
		_busy_for(maxf(Motion.FLASH_IN + Motion.FLASH_OUT, Motion.SHIVER_TIME))
	_speak((tr("BR_CHECK_ONE") if wrong.size() == 1 else tr("BR_CHECK_N") % wrong.size())
		if not wrong.is_empty() else tr("BR_CHECK_OK"),
		Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_refresh()
	return wrong.size()

## Every plank goes, in a wave from the far corner with the islets hopping as
## it passes -- the table's Reset row, in this board's pieces. The hints a
## player spent are not refunded, only unpinned.
func reset_board() -> void:
	if out_of_hearts or _sinking_busy:
		return
	_wipe()
	_break_streak()
	# Bare water is the board from the top, so the moves come back too.
	moves_left = max_moves
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	_running = true

## Reset's half that Try again shares: every plank carried off in a wave from
## the far corner with the islets hopping as it passes, the state back to
## bare water, every moment gone. The hints a player spent are not refunded,
## only unpinned.
func _wipe() -> void:
	# Anything `_after` still owes the board being wiped does nothing.
	_gen += 1
	var snap := _snapshot()
	var t := _now()
	state.reset_board()
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	_refuse = {}
	_last = State.NOWHERE
	_given = {}
	_wrong = {}
	_met_at = {}
	_shiver_at = {}
	_land_at = {}
	_glint = {}
	_glint_run = {}
	_pending = []
	_press_cell = State.NOWHERE
	_press_up = -1.0
	_solved_at = -INF
	_depth = {}
	_sparked = {}
	_sinking = []
	_pulse = {}
	_flip = {}
	for cell in _flag:
		_flag[cell] = {"at": t, "open": false}
	_groups = state.islets.size()
	moves = 0
	_resume_tips()
	_settle(snap, _reset_wave)
	fx.cue("reset")
	for cell in state.islets:
		_hop_at[cell] = t + _reset_delay(cell)
	_busy_for(_reset_delay(Vector2i.ZERO) + Motion.HOP_TIME)

## How long a lane waits in Reset's wave: the far corner goes first.
func _reset_wave(key: String) -> float:
	var lane: Dictionary = state.lanes[key]
	var a: Vector2i = lane.a
	var b: Vector2i = lane.b
	return _reset_delay(Vector2i(maxi(a.x, b.x), maxi(a.y, b.y)))

func _reset_delay(cell: Vector2i) -> float:
	return Motion.stagger((state.n - 1 - cell.x) + (state.n - 1 - cell.y),
		Motion.RESET_STAGGER)

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	if state.band == 3:
		out += " · 🏮 " + tr("BR_LANTERN_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += " · 🏅 " + tr("BN_FLAWLESS")
	return out

## Whether the solve was flawless, so a reopened daily keeps its seal, and
## how many hearts it kept.
func completion_record() -> Dictionary:
	return {"flawless": _flawless, "hearts": hearts}

# --- the win ---

## The no-cast form Light Up uses: the joined network stays on the card under
## the win screen, because the board *is* the answer and there is nothing
## better to show.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("BR_WIN")}

## Long enough for the wave that lights the network, which runs outward from
## the islet the player finished at. It spends the wave's own clock
## (`_wave_at`), so the win screen and the wave can never disagree about how
## long the wave is.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return _land_lag() + _wave_at(_wave_depth()) + Motion.SOLVE_TIME * 0.5 + PARTY_AT + PARTY_EXTRA

## How long after the last move the wave sets off: the last plank has to land
## before the light can run along it.
func _land_lag() -> float:
	return 0.0 if Motion.reduce else LAY_TIME * LAND_AT

## The solve: the wave's graph is the network the player built, walked once
## from the islet the last plank was laid at and then never walked again.
func _on_solved() -> void:
	# A finger still down (a hint from a second touch solved it) lets go.
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	if _press_cell != State.NOWHERE and _press_up < 0.0:
		_press_up = _now()
	_solved_at = _now() + _land_lag()
	_depth = _wave_steps()
	_sparked = {}
	_refuse = {}
	_wrong = {}
	# Once the wave has crossed the network, a light runs over it along the
	# diagonal: every coin and every deck glints as it passes.
	var light := _solved_at + _wave_at(_wave_depth()) + Motion.SOLVE_TIME * 0.5 + WIN_GLINT_AT
	for cell: Vector2i in state.islets:
		_glint[cell] = light + float(cell.x + cell.y) * WIN_GLINT_STEP
	for key in state.runs:
		var lane: Dictionary = state.lanes[key]
		_glint_run[key] = light + float(lane.a.x + lane.a.y + lane.b.x + lane.b.y) * 0.5 \
			* WIN_GLINT_STEP
	_busy_for(light - _now() + float(2 * state.n) * WIN_GLINT_STEP + GLINT_TIME)
	fx.cue("solved")
	_after(_land_lag(), fx.buzz.bind(Haptics.WIN))
	_tip_timer.stop()
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 or max_moves > 0 else checks == 0)
	_combo_out_at = _now() if _combo_n >= COMBO_FROM else -INF
	for cell in state.islets:
		if not _flag.has(cell) or not bool(_flag[cell].open):
			_flag[cell] = {"at": _now(), "open": true}
	_party(light - _now())
	_refresh()

## A completed daily is rebuilt from its seed, so it opens on bare water. Lay
## every run the answer lays and settle the card as it stands once the solve's
## wave has passed: every islet met and ringed, the network lit gold from end
## to end, no Check marks, no ghosts, no entrance and no sparkle still owed.
## Not check_solved(): the host owns the win screen and `solved` must not fire
## a second time.
func restore_completed_board() -> void:
	var t := _now()
	state.runs = {}
	for key in state.answer:
		if int(state.answer[key]) > 0:
			state.runs[key] = int(state.answer[key])
	state.history.clear()
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	_refuse = {}
	_last = State.NOWHERE
	_given = {}
	_wrong = {}
	_laid = {}
	_ghosts = []
	_met_at = {}
	_shiver_at = {}
	_hop_at = {}
	_land_at = {}
	_glint = {}
	_glint_run = {}
	_pending = []
	_press_cell = State.NOWHERE
	_press_up = -1.0
	# The entrance and the wave both long over: `_front` reads far past the
	# deepest islet, so every run wears the lit deck and no islet still flares.
	_opened = t - 100.0
	_solved_at = t - 100.0
	_depth = _wave_steps()
	_sparked = _depth.duplicate()
	_anim_until = 0.0
	_deal()
	_groups = 1
	var rec := completed_record
	_flawless = bool(rec.get("flawless", false))
	if rec.has("hearts") and max_hearts > 0:
		hearts = int(rec.hearts)
	for cell in state.islets:
		_flag[cell] = {"at": t - 100.0, "open": true}
	if _flawless or state.band == 3:
		_stamp_at = t - 100.0
	if not state.lanterns.is_empty():
		_glow_at = t - 100.0
	_tip_timer.stop()
	_say(tr("BR_WIN"), Face.Expr.JOY)
	_refresh()

# --- the wave, and the one function that says where its front is ---

## **Where the front is, in islets deep, at clock time `t`**, and -1 before
## the board is solved. This is the one truth the whole wave is read off --
## which planks are lit, which islet is flaring, where a sparkle goes -- which
## is the rule Word Trail's `_front` set: four things reading four clocks is
## how a wave drifts apart. It crosses a run in `WAVE_EDGE` and rests on the
## islet it reached for `WAVE_HOLD`, so the return runs `0 .. 1` across the
## first run, holds at 1, then `1 .. 2` across the second.
##
## Under reduce motion it answers INF: the lit state is applied at once and no
## front travels, which is what stilling this wave means.
func _front(t: float) -> float:
	if _solved_at == -INF:
		return -1.0
	if Motion.reduce:
		return INF
	var step := _wave_at(1)
	var since := t - _solved_at
	if since <= 0.0 or step <= 0.0:
		return 0.0
	var d := floorf(since / step)
	return d + clampf((since - d * step) / WAVE_EDGE, 0.0, 1.0)

## `_front`'s inverse, and the only other place the wave's clock is written:
## when the front reaches an islet `d` runs out from the start.
func _wave_at(d: int) -> float:
	return float(d) * (WAVE_EDGE + WAVE_HOLD)

## Seconds since the front reached `cell`, or -1 while it has not. The gate is
## `_front` itself, so an islet flares when the light arrives at it and not a
## frame before.
func _arrived(cell: Vector2i, t: float) -> float:
	if _solved_at == -INF or not _depth.has(cell):
		return -1.0
	var d := int(_depth[cell])
	if _front(t) < float(d):
		return -1.0
	return (t - _solved_at) - _wave_at(d)

## What the front says about one lane: how far along it the light has run
## (`u`, 0 to 1) and whether it came in at the lane's low end, so the gold
## grows from the islet the wave reached first rather than from wherever the
## lane happens to be drawn from.
func _wave_of(key: String, t: float) -> Dictionary:
	var f := _front(t)
	if f <= 0.0 or not state.lanes.has(key):
		return {}
	var lane: Dictionary = state.lanes[key]
	if not _depth.has(lane.a) or not _depth.has(lane.b):
		return {}
	var da := int(_depth[lane.a])
	var db := int(_depth[lane.b])
	var u := clampf(f - float(mini(da, db)), 0.0, 1.0)
	if u <= 0.0:
		return {}
	var near: Vector2i = lane.a if da <= db else lane.b
	var far: Vector2i = lane.b if da <= db else lane.a
	var low: bool = (_at(near).x + _at(near).y) <= (_at(far).x + _at(far).y)
	return {"u": u, "low": low}

## Sends up each islet's sparkle as the front reaches it -- `_front` again,
## asked once a frame, so the sparkle and the gold can never be a frame
## apart. Nothing under reduce motion: `ui/fx2d.gd` draws neither a sparkle
## nor a ring there, and the front does not travel to have reached anything.
func _spark(t: float) -> void:
	if _solved_at == -INF or t < _solved_at or Motion.reduce or _sparked.size() >= _depth.size():
		return
	var f := _front(t)
	for cell in _depth:
		if _sparked.has(cell) or f < float(_depth[cell]):
			continue
		_sparked[cell] = true
		fx.sparkle(_at(cell), Pal.SUN)

## How many runs deep the network is from the islet the last plank was laid
## at: the number of steps the wave has to take.
func _wave_depth() -> int:
	var steps := _depth if not _depth.is_empty() else _wave_steps()
	var deepest := 0
	for cell in steps:
		deepest = maxi(deepest, int(steps[cell]))
	return deepest

## The breadth-first walk the wave runs over: every islet the laid runs reach
## from `_last`, and how many runs out it stands. This is the walk, and the
## only one -- `win_delay()` measures the wave with it and the wave itself
## reads it, so the two can never disagree.
func _wave_steps() -> Dictionary:
	var out := {}
	if state.islets.is_empty():
		return out
	var start: Vector2i = _last if _last != State.NOWHERE else state.islets[0]
	out[start] = 0
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var step: int = int(out[cell]) + 1
		for key in state.runs:
			if int(state.runs[key]) <= 0:
				continue
			var lane: Dictionary = state.lanes[key]
			var other := State.NOWHERE
			if lane.a == cell:
				other = lane.b
			elif lane.b == cell:
				other = lane.a
			if other == State.NOWHERE or out.has(other):
				continue
			out[other] = step
			queue.append(other)
	return out

# --- the ghost finger ---

## On Easy and Medium, until the first plank, a ghost finger shows the drag
## on a lane the answer lays: from one islet to the one facing it, a faint
## plank following. It goes the moment anything is laid, and it never runs on
## a judged board, on Insane (the lane is one of the answer's, and nothing
## there is laid or shown for the player) or under reduce motion.
func _pick_coach() -> void:
	_coach_lane = ""
	_coach_from = State.NOWHERE
	if state.judged() or state.band >= 3 or Motion.reduce or state.answer.is_empty():
		return
	var keys: Array = state.answer.keys()
	keys.sort()
	# The lane nearest the middle of the sea, so the hand is easy to follow.
	var best := ""
	var best_d := INF
	var mid := Vector2(state.n, state.n) * 0.5
	for key in keys:
		var lane: Dictionary = state.lanes[key]
		var d := (Vector2(lane.a + lane.b) * 0.5 + Vector2(0.5, 0.5)).distance_to(mid)
		if d < best_d:
			best_d = d
			best = String(key)
	_coach_lane = best
	_coach_from = state.lanes[best].a

## Where the ghost finger is and how solid, at `t`: {} while it rests.
func _coach_at(t: float) -> Dictionary:
	if _coach_lane == "" or not state.lanes.has(_coach_lane) or moves > 0 or is_done():
		return {}
	var e := t - _opened - Motion.ENTER_DELAY - COACH_AFTER
	if e < 0.0:
		return {}
	var u := fmod(e, COACH_DRAG + COACH_LOOP) / COACH_DRAG
	var lane: Dictionary = state.lanes[_coach_lane]
	var a := _at(_coach_from)
	var b := _at(lane.b if _coach_from == lane.a else lane.a)
	var fade := clampf(u * 5.0, 0.0, 1.0) * clampf((1.6 - u) * 3.0, 0.0, 1.0)
	return {"a": a, "at": a.lerp(b, _ease(clampf(u, 0.0, 1.0))), "alpha": fade,
		"press": clampf(u * 8.0, 0.0, 1.0)}

func _draw_coach(t: float) -> void:
	var c := _coach_at(t)
	if c.is_empty() or float(c.alpha) <= 0.01:
		return
	var s := _cell()
	var al: float = c.alpha
	var at: Vector2 = c.at
	var a: Vector2 = c.a
	# The trail: the plank it is laying, faint gold.
	_life_layer.draw_line(a, at, Color(Pal.SUN, 0.45 * al), s * PLANK * 1.6, true)
	# The fingertip: a soft shadow, a ring pressed into the water, the tip.
	_life_layer.draw_circle(at + Vector2(4.0, 8.0), s * 0.2, Color(Pal.TEXT, 0.16 * al))
	_life_layer.draw_arc(at, s * (0.26 + 0.06 * (1.0 - float(c.press))), 0.0, TAU, 32,
		Color(Pal.SURFACE, 0.7 * al), maxf(2.0, s * 0.03), true)
	_life_layer.draw_circle(at, s * 0.17, Color(Pal.SURFACE, 0.92 * al))
	_life_layer.draw_arc(at, s * 0.17, 0.0, TAU, 32, Color(Pal.LINE, al), maxf(2.0, s * 0.025), true)
	# A little hand: the finger's knuckle trailing down and right of the tip.
	var palm := at + Vector2(s * 0.22, s * 0.34)
	_life_layer.draw_line(at + Vector2(s * 0.04, s * 0.1), palm, Color(Pal.SURFACE, 0.92 * al), s * 0.2, true)
	_life_layer.draw_circle(palm + Vector2(s * 0.08, s * 0.12), s * 0.22, Color(Pal.SURFACE, 0.92 * al))
	_life_layer.draw_arc(palm + Vector2(s * 0.08, s * 0.12), s * 0.22, -PI * 0.9, PI * 0.6, 24,
		Color(Pal.LINE, al), maxf(2.0, s * 0.025), true)

# --- rewards ---

## A right plank (on Hard and Insane the answer's; on Easy and Medium one
## that pushes nothing over its number, which reveals nothing) builds the
## streak -- a note up the pentatonic from the second, the bubble from the
## third, confetti at five and ten.
func _on_right(key: String) -> void:
	if is_done() or state.is_solved():
		return
	var land := 0.0 if Motion.reduce else LAY_TIME * LAND_AT
	_streak += 1
	if _streak >= 2:
		var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
		_after(land, func() -> void:
			if not is_done():
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	if _streak >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _streak
		_combo_pos = _lane_middle(key)
		_combo_at = _now()
		_combo_out_at = -INF
		_combo_layer.queue_redraw()
	if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
		_after(land, func() -> void:
			if is_done() or not state.lanes.has(key):
				return
			fx.confetti(_lane_middle(key), 22)
			fx.cue("confetti"))

## The streak ends: a lift, a refusal, a wrong plank, an undo, a reset, the
## hearts running out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
		if _combo_layer != null:
			_combo_layer.queue_redraw()
	else:
		_combo_n = 0

## Three met islets in five play a gag, picked by the islet's hash so a day
## replays the same: a little fish leaps over the water beside it; hearts
## float up off it; or its coin twirls a whole turn. Under reduce motion,
## none.
func _gag(cell: Vector2i) -> void:
	if Motion.reduce or is_done() or state.is_solved():
		return
	var roll := posmod(hash(Vector2i(cell.x * 13 + 7, cell.y * 5 + moves)), GAG_ODDS)
	if roll >= GAGS:
		return
	var now := _now()
	var r := _islet_r()
	match roll:
		0:
			var side := -1.0 if cell.x * 2 >= state.n else 1.0
			var from := _at(cell) + Vector2(side * r * 1.2, r * 0.9)
			_fish.append({"a": from, "b": from + Vector2(side * _cell() * FISH_SPAN, 0.0), "t": now})
			fx.puff(from, Pal.WATER_HI, 4)
			fx.cue("fish")
			_after(FISH_TIME, func() -> void:
				if state.is_islet(cell):
					fx.puff(from + Vector2(side * _cell() * FISH_SPAN, 0.0), Pal.WATER_HI, 4))
		1:
			var at := _at(cell) - Vector2(0.0, r * 0.6)
			for n in LOVE_HEARTS:
				var off := Vector2((n - (LOVE_HEARTS - 1) * 0.5) * 0.22, -0.2) * _cell()
				_love.append({"at": at + off, "t": now + n * 0.08, "phase": _hash(cell.x + n, cell.y + 11) * TAU})
			fx.cue("love")
		2:
			_twirl[cell] = now + COIN_FLIP
			_busy_for(COIN_FLIP + TWIRL_TIME)
			_after(COIN_FLIP, func() -> void:
				if state.is_islet(cell):
					fx.sparkle(_at(cell) - Vector2(0.0, r * 0.8), Pal.SUN)
					fx.cue("twirl"))
	_life_layer.queue_redraw()

# --- failing ---

## `cost` moves go off Insane's counter. The last one gone with the islets
## not yet one network of met numbers ends the board once the plank has
## landed (`land`).
func _spend(cost: int, land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_moves_pill.bump(_now())
	_heart_layer.queue_redraw()
	if moves_left > 0 or is_done() or state.is_solved():
		return
	_lost_ever = true
	out_of_hearts = true
	_running = false
	_after(maxf(0.0, land - _now()), _run_out)

## A plank the answer does not lay there, on Hard or Insane: it rolls out and
## lands like any other, then its islets worry and a heart splits, and
## CRACK_AFTER later it cracks in two and sinks. The state never kept it; the
## lane now carries a buoy for good.
func _wrong_plank(key: String, before: int, from: Vector2i) -> void:
	if hearts <= 0 or is_done():
		return
	var land := 0.0 if Motion.reduce else LAY_TIME
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_split_index = hearts
	_split_at = _now() + land
	_sinking_busy = true
	if hearts <= 0:
		out_of_hearts = true
		_running = false
	var lane: Dictionary = state.lanes[key]
	var src := from if from == lane.a or from == lane.b else State.NOWHERE
	if not Motion.reduce:
		_sinking.append({"key": key, "count": before, "at": _now(), "src": src})
	fx.cue("place")
	_busy_for(land + CRACK_AFTER + SINK_TIME)
	_after(land, func() -> void:
		_heart_layer.queue_redraw()
		fx.cue("heart_lost")
		var t := _now()
		for cell in [lane.a, lane.b]:
			_shiver_at[cell] = t
		_busy_for(Motion.SHIVER_TIME)
		_speak(tr("BR_WRONG"), Face.Expr.WORRIED)
		_refresh())
	_after(land + (0.0 if Motion.reduce else CRACK_AFTER), func() -> void:
		if not Motion.reduce and state.lanes.has(key):
			fx.puff(_lane_middle(key), Pal.WATER_HI, 6)
		fx.cue("sink"))
	_after(land + (0.0 if Motion.reduce else CRACK_AFTER + SINK_TIME), func() -> void:
		_sinking_busy = false
		_sinking = []
		fx.cue("ruled")
		moved.emit()
		_refresh()
		if out_of_hearts:
			_run_out())
	_refresh()

## The last heart is gone: the pool slips to dusk, the line yawns, and the
## card comes up.
func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_break_streak()
	_tip_timer.stop()
	fx.cue("out_of_hearts")
	_say(tr("BR_OUT"), Face.Expr.SLEEPY)
	_dusk_toward(DUSK)
	_refresh()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

func _dusk_toward(tint: Color) -> void:
	Motion.stop(_dusk_tw)
	if Motion.reduce:
		modulate = tint
		return
	_dusk_tw = create_tween()
	_dusk_tw.tween_property(self, "modulate", tint, DUSK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## The card, over the whole screen: laid on the host so it covers the chrome,
## or on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, [], MOVES_BONUS) if max_moves > 0 \
		else load(OUT_OF_HEARTS).new(_heart_used, ["BR_OUT_BODY", "BR_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same sea from bare water in Reset's wave, every heart back
## and the buoys gone, the day's light, the clock and the moves from zero;
## hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_wipe()
	state.ruled = {}
	_deal()
	elapsed = 0.0
	checks = 0
	moves = 0
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_running = true
	_tip_idx = 0
	_hold_until = 0.0
	_say(_tip(0), Face.Expr.HAPPY)
	_tip_timer.start()
	moved.emit()
	_refresh()

## One more heart (the card's video): once a board. The light comes back.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	if max_moves > 0:
		moves_left = MOVES_BONUS
		_moves_pill.bump(_now())
	else:
		hearts = 1
		_back_index = 0
		_back_at = _now()
	_heart_layer.queue_redraw()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_resume_tips()
	_tip_timer.start()
	moved.emit()
	_refresh()

## Back from the card: the board ends unsolved first, so the host logs
## puzzle_complete {solved: false} and not an abandon.
func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

## Holds the host's hint video while a wrong plank is still sinking.
func busy() -> bool:
	return _sinking_busy

# --- the party ---

## After the solve wave: the islets dance on the beat, confetti sweeps the
## pool twice, a paper boat sails across it, on Insane the lanterns flare,
## the seal stamps when the solve earned one (flawless, or any Insane sea),
## and the line shares a silly bit of bridge wisdom. Under reduce motion the
## glow and the seal stand at once.
func _party(after_wave: float) -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else maxf(0.0, after_wave) + PARTY_AT
	_after(lead, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	if not state.lanterns.is_empty():
		_glow_at = now + lead * 0.5
		_busy_for(lead * 0.5 + 1.0)
		_after(lead * 0.5, fx.cue.bind("lanterns_glow"))
	if _flawless or state.band == 3:
		_stamp_at = now if Motion.reduce else now + lead + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		return
	var pool := _pool()
	_after(lead + 0.15, func() -> void:
		fx.confetti(Vector2(pool.get_center().x, pool.position.y + _cell() * 0.5), 30, pool.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.6, func() -> void:
		fx.confetti(pool.get_center(), 24, pool.size.x * 0.7))
	_dance_at = now + lead + 0.35
	_busy_for(lead + 0.35 + DANCE_BEAT * (DANCE_BEATS + 1))
	_after(lead + 0.35, fx.cue.bind("dance"))
	_boat_at = now + lead + 0.2
	_after(lead + 0.2, fx.cue.bind("boat"))

func _twirling(now: float) -> bool:
	for cell in _twirl:
		if now < float(_twirl[cell]) + TWIRL_TIME:
			return true
	for cell in _flip:
		if now < float(_flip[cell]) + COIN_FLIP:
			return true
	return false

func _dancing(now: float) -> bool:
	return now >= _dance_at and now < _dance_at + DANCE_BEAT * (DANCE_BEATS + 1)

## One of CHEERS silly bits of bridge wisdom, picked by the sea itself, so a
## day always gets the same one.
func _cheer() -> String:
	return tr("BR_CHEER_%d" % posmod(hash(state.islets), CHEERS))

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	if get_tree() == null:
		return
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

# --- the layers: hearts, the streak's bubble, and the life over the sea ---

func _tick_layers(now: float) -> void:
	if _heart_layer == null:
		return
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1) \
			or _moves_pill.animating(now - 0.1) \
			or now - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1:
		_heart_layer.queue_redraw()
	if _combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF):
		_combo_layer.queue_redraw()
	var alive := _tick_life(now)
	if alive or _life_alive:
		_life_layer.queue_redraw()
	_life_alive = alive

## The hearts over the pool as one mesh on a paper pill (Queens'): pink with
## a small face and a leaf, a faint ghost where one was, the lost one's halves
## falling apart, and one coming back popping in.
func _draw_hearts() -> void:
	if max_moves > 0 and _cell() > 0.0:
		_moves_pill.draw(_heart_layer, Vector2(size.x * 0.5, _hearts_y()), moves_left, _now())
		return
	if max_hearts <= 0 or _cell() <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _hearts_y()
	var x0 := size.x * 0.5 - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts or (i == _split_index and now < _split_at):
			var r := HEART_R
			if i == _back_index and not Motion.reduce:
				r *= Motion.pop_in_scale(now - _back_at, HEART_BACK_TIME).x
			if r > 0.5:
				b.polygon(_heart(at, r, -1), Pal.FLOWER)
				b.polygon(_heart(at, r, 1), Pal.FLOWER_DEEP)
				_heart_face(b, at, r)
			continue
		b.polygon(_heart(at, HEART_R, 0), Color(Pal.FLOWER, 0.22))
		var u := (now - _split_at) / SPLIT_TIME
		if i == _split_index and u < 1.0 and not Motion.reduce:
			var fade := 1.0 - u * u
			for side in [-1, 1]:
				var turn: float = side * SPLIT_TURN * u
				var shift := Vector2(side * SPLIT_SPREAD * u, SPLIT_FALL * u * u)
				var pts := _heart(Vector2.ZERO, HEART_R, side)
				for n in pts.size():
					pts[n] = at + shift + pts[n].rotated(turn)
				b.polygon(pts, Color(Pal.FLOWER if side < 0 else Pal.FLOWER_DEEP, fade))
	_hearts_shown = b.mesh()
	var c := Vector2(size.x * 0.5, y)
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

## A heart's small face: two dots and a smile in ink, a shine at the top left,
## and a leaf on top.
static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

## A heart `s` half-wide about `at` (side 0), or its left (-1) or right (1)
## half, split along a zigzag crack so the two halves fit together
## (Binairo's; its notes say why the crack leaves the tip straight up).
static func _heart(at: Vector2, s: float, side: int) -> PackedVector2Array:
	const STEPS := 36
	var k := s / 16.0
	var off := Vector2(0.0, -2.5)
	var pts := PackedVector2Array()
	var from := 0.0 if side >= 0 else PI
	var to := TAU if side == 0 else from + PI
	var count := STEPS if side == 0 else STEPS / 2 + 1
	for i in count:
		var t := lerpf(from, to, float(i) / float(STEPS if side == 0 else STEPS / 2))
		var p := Vector2(16.0 * pow(sin(t), 3.0),
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)))
		pts.append(at + (p + off) * k)
	if side == 0:
		return pts
	var zig := [Vector2(0.0, 13.0), Vector2(1.5, 8.0), Vector2(-1.5, 3.0), Vector2(1.0, -2.0)]
	if side < 0:
		zig.reverse()
	for z: Vector2 in zig:
		pts.append(at + (z + off) * k)
	return pts

## The streak's paper bubble over the last right plank, "x3" and up in leaf
## ink: it pops in the first time, bumps at each plank and deflates when the
## streak ends (One Line's).
func _draw_combo() -> void:
	if _combo_n < COMBO_FROM or _cell() <= 0.0:
		return
	var now := _now()
	var k := 1.0
	var alpha := 1.0
	if _combo_out_at == -INF and now - _combo_at >= COMBO_HOLD:
		_combo_out_at = now
	if _combo_out_at > -INF:
		var u := (now - _combo_out_at) / COMBO_DEFLATE
		if u >= 1.0 or Motion.reduce:
			_combo_n = 0
			return
		k = 1.0 - 0.75 * u * u
		alpha = 1.0 - u
	elif not Motion.reduce:
		var e := now - _combo_at
		k = Motion.pop_in_scale(e).x if _combo_popped else Motion.bump_scale(e)
	if k <= 0.01:
		return
	var font: Font = CozyTheme.display(700)
	var text := "x%d" % _combo_n
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT).x
	var box := Vector2(tw + 30.0, COMBO_FONT + 16.0)
	var tail := _combo_pos + Vector2(0.0, -_cell() * 0.2)
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.95)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var b := Face.Builder.new()
	var tip := tail - centre
	var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
	b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
	b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
	b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
	b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	_combo_shown = b.mesh()
	_combo_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_combo_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var ascent := font.get_ascent(COMBO_FONT)
	var descent := font.get_descent(COMBO_FONT)
	_combo_layer.draw_string(font, Vector2(-tw * 0.5, (ascent - descent) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_combo_layer.draw_set_transform(Vector2.ZERO)

## Keeps the life layer drawing while anything on it moves.
func _tick_life(now: float) -> bool:
	var still: Array = []
	for l in _love:
		if now < float(l.t) + LOVE_TIME:
			still.append(l)
	_love = still
	var swim: Array = []
	for f in _fish:
		if now < float(f.t) + FISH_TIME:
			swim.append(f)
	_fish = swim
	return not _love.is_empty() or not _fish.is_empty() \
		or not _coach_at(now).is_empty() \
		or (now >= _boat_at and now - _boat_at < BOAT_TIME) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## The life over the sea: the ghost finger, love hearts floating off an
## islet, a leaping fish, the party's paper boat, and the seal after the
## solve, with its words.
func _draw_life() -> void:
	if _cell() <= 0.0 or state.islets.is_empty():
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	_draw_coach(now)
	if not _love.is_empty():
		var mesh := _love_heart()
		shown.append(mesh)
		for l in _love:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / LOVE_TIME
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.08 * _cell(),
				-LOVE_RISE * _cell() * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	for f in _fish:
		_draw_fish(f, now)
	if now >= _boat_at and now - _boat_at < BOAT_TIME:
		_draw_boat((now - _boat_at) / BOAT_TIME)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_life_shown = shown

## A little orange fish leaping in an arc from `a` to `b`, nose along its
## path.
func _draw_fish(f: Dictionary, now: float) -> void:
	var u := (now - float(f.t)) / FISH_TIME
	if u <= 0.0 or u >= 1.0:
		return
	var s := _cell()
	var a: Vector2 = f.a
	var b: Vector2 = f.b
	var h := s * FISH_LEAP
	var at := a.lerp(b, u) - Vector2(0.0, h * 4.0 * u * (1.0 - u))
	var dx := (b.x - a.x)
	var slope := Vector2(dx, -h * 4.0 * (1.0 - 2.0 * u))
	var ang := slope.angle()
	var r := s * 0.13
	_life_layer.draw_set_transform(at, ang, Vector2.ONE)
	var tail := PackedVector2Array([Vector2(-r * 0.8, 0.0), Vector2(-r * 1.6, -r * 0.6), Vector2(-r * 1.6, r * 0.6)])
	_life_layer.draw_colored_polygon(tail, Pal.SUN_DEEP)
	var body := Face.Builder.ring(Vector2.ZERO, r * 1.05, r * 0.6)
	_life_layer.draw_colored_polygon(body, Pal.SUN_DEEP.lerp(Pal.BERRY, 0.25))
	_life_layer.draw_circle(Vector2(r * 0.5, -r * 0.12), r * 0.14, Pal.OUTLINE)
	_life_layer.draw_set_transform(Vector2.ZERO)

## The party's paper boat, sailing along the bottom of the pool and bobbing.
func _draw_boat(u: float) -> void:
	var pool := _pool()
	var s := _cell()
	var w := s * BOAT_W
	var x := lerpf(pool.position.x - w, pool.end.x + w, u)
	var y := pool.end.y - maxf(s * 0.5, (pool.size.y - _field_size()) * 0.25)
	var bob := sin(u * TAU * 3.0) * s * 0.05
	var tilt := sin(u * TAU * 3.0 + 0.6) * 0.08
	_life_layer.draw_set_transform(Vector2(x, y + bob), tilt, Vector2.ONE)
	var hull := PackedVector2Array([Vector2(-w * 0.6, 0.0), Vector2(w * 0.6, 0.0),
		Vector2(w * 0.4, w * 0.28), Vector2(-w * 0.4, w * 0.28)])
	var sail := PackedVector2Array([Vector2(-w * 0.05, -w * 0.05), Vector2(-w * 0.05, -w * 0.62),
		Vector2(w * 0.42, -w * 0.05)])
	_life_layer.draw_colored_polygon(sail, Pal.SURFACE)
	_life_layer.draw_polyline(PackedVector2Array([sail[0], sail[1], sail[2], sail[0]]), Pal.LINE, 2.0, true)
	_life_layer.draw_colored_polygon(hull, Pal.SURFACE.lerp(Pal.PAPER, 0.5))
	_life_layer.draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[0]]), Pal.LINE, 2.0, true)
	_life_layer.draw_circle(Vector2(w * 0.1, -w * 0.3), w * 0.05, Pal.FLOWER)
	_life_layer.draw_set_transform(Vector2.ZERO)

## A little pink heart for the love gag, built once a layout.
func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := _cell() * LOVE_R
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

## The seal on the pool's lower right, dropping in from STAMP_FROM its size
## and settling with the back ease's overshoot, its words over it.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = state.band == 3
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var pool := _pool()
	var centre := pool.end - Vector2(rad * 0.9, rad * 0.8)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("BR_LANTERN_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)
