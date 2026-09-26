extends "res://core/puzzle_base.gd"

## Bridges as a flat board: a pale sea inset in the card, islets standing on
## it with the number of plank-ends each one wants, and runs of one to three
## planks laid in the lanes between the pairs that face each other. The rules
## live in puzzles/bridges_state.gd, which this only draws.
##
## **The fourth rule is the puzzle.** Every number met is not a solve: the
## islets have to end on one single network, and the board says nothing at
## all about the near-miss where the numbers are all met and the islets stand
## in two rings. Seeing the split network is the thing being solved, and
## Check is the only door to it (spec section 10).
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
## Three, as every other board gives.
const HINTS := 3
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
var _mesh: ArrayMesh
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
var _solved_at := -1.0
var _depth: Dictionary = {}
var _sparked: Dictionary = {}

var _tip_text := tr(TIP_REST)
var _tip_mood := Face.Expr.HAPPY

func puzzle_id() -> String: return "bridges"
func title() -> String: return "Bridges"

## The four rules of the spec's section 1, in that order and **connectivity
## last**, because it is the one the reference's own rules card leaves out and
## the one this whole board rests on.
func rules() -> String:
	return tr("BR_RULES")

## Undo, Hint and Check: the plainest shape on the shelf. It picks nothing up,
## so the registry gives it no tray, and it has a real Check, so unlike
## Balance and Untangle it keeps the actions row.
func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	resized.connect(_resized)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	state.build(rng, difficulty)
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
	_press_cell = State.NOWHERE
	_press_up = -1.0
	_solved_at = -1.0
	_depth = {}
	_sparked = {}
	_anim_until = 0.0
	_lap_rng.seed = hash(state.islets)
	_say(tr(TIP_REST), Face.Expr.HAPPY)
	_enter()
	_refresh()

# --- the layout, ported from the mock ---

## The sea pool, inset from the card on every side.
func _pool() -> Rect2:
	return Rect2(INSET, INSET, maxf(0.0, size.x - 2.0 * INSET), maxf(0.0, size.y - 2.0 * INSET))

## The largest cell the pool holds, with the lattice's own pad inside it.
## **The width binds at every band** -- 920 of lattice against 1110 of pool
## height at 1080 wide -- because the lattice is square and the slot is tall.
func _cell() -> float:
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
	_refresh()

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
	if _mesh == null:
		_mesh = _build(t)
	var lap := _build_laps(t)
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	var grow := Motion.wide_pop_scale(since)
	var mid := _pool().get_center()
	var page := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	if seen > 0.0:
		for m in [_sea, lap, _mesh]:
			if m != null:
				draw_mesh(m, null, page, Color(1.0, 1.0, 1.0, seen))
		_draw_numbers(t, page, seen)
	_shown = [_sea, lap, _mesh]

## The order the mock draws in, and it is not a preference either: the lit
## lane and a refusal's band go **under** the runs, so a highlight on the run
## in the way reads as a glow beneath it rather than a coat of paint over it,
## and everything goes under the islets, which are opaque. The lane under the
## finger is drawn with the runs even while it is bare, because its preview
## is the plank the drag would lay.
func _build(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_aim_band(b)
	_refusal(b, t)
	for key in state.runs:
		_run(b, String(key), t)
	if _aim != "" and state.planks(_aim) <= 0:
		_run(b, _aim, t)
	for ghost: Dictionary in _ghosts:
		_ghost(b, ghost, t)
	for cell in state.islets:
		_islet(b, cell, t)
	return b.mesh() if not b.verts.is_empty() else null

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
	return b.mesh()

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
	var count: int = state.planks(key)
	var next := _preview(key)
	if count <= 0 and next <= 0:
		return
	if _given.has(key) and not is_done() and count > 0:
		_glow(b, _lane_ends(key), _run_width(count))
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
	_planks(b, key, count, look)

## What the lane under the finger would hold once the finger lets go, or -1
## when `key` is not that lane or the lane is refused.
func _preview(key: String) -> int:
	if key != _aim or _from == State.NOWHERE or not state.lanes.has(key):
		return -1
	if state.blocked_by(key) != "":
		return -1
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
		if i >= first_new and i < faint_from and not Motion.reduce:
			u = _ease(since / LAY_TIME)
			a *= Motion.appear_level(since)
		if u <= 0.0 or a <= 0.0:
			continue
		var lift := 0.0
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
	var want: int = int(state.need[cell])
	var got: int = state.degree(cell)
	var over := got > want
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
		_sprout(b, root, r * TUFT_H * sc.y, Pal.LEAF_DEEP.lerp(Pal.BANK, 0.3))
	if _hash(seed_i, 67) < FLOWER_SHARE:
		var side := -1.0 if _hash(seed_i, 69) < 0.5 else 1.0
		_flower(b, mid + Vector2(side * rx * 0.72, top_y * 0.3), r * 0.16)
	# The coin: its shadow on the moss, its edge, its face.
	var coin := _coin_colour(cell, t, want, got)
	var cx := rx * COIN_R
	var cy := ry * COIN_R
	var at := mid - Vector2(0.0, ry * COIN_LIFT)
	Scenery.soft_disc(b, mid + Vector2(0.0, ry * COIN_LIP * 0.8), cx * 1.14, cy * 1.08,
		Color(Pal.TEXT, COIN_SHADOW))
	b.ellipse(at + Vector2(0.0, ry * COIN_LIP), cx, cy, coin.lerp(Pal.TEXT, COIN_EDGE))
	b.ellipse(at, cx, cy, coin)

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
	elif got == want:
		coin = Pal.LEAF_TILE.lerp(Pal.GOOD, COIN_MET)
	var arrived := _arrived(cell, t)
	if arrived >= 0.0:
		coin = coin.lerp(Pal.SUN_TILE, clampf(arrived / WAVE_EDGE, 0.0, 1.0))
		coin = coin.lerp(Pal.SUN_RAY, Motion.flash_level(arrived, WAVE_EDGE) * WAVE_FLARE)
	return coin.lerp(Pal.SURFACE, _shine(_glint, cell, t) * SHINE)

## The ink an islet's number is drawn in: TEXT, LEAF_DEEP met, BAD over, and
## the plaque's brown once the wave has turned its coin gold.
func _number_ink(cell: Vector2i, t: float) -> Color:
	var want: int = int(state.need[cell])
	var got: int = state.degree(cell)
	var ink: Color = Pal.TEXT
	if got > want:
		ink = Pal.BAD
	elif got == want:
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
	var drawn := false
	for cell in state.islets:
		var sc := _islet_scale(cell, t)
		if sc.x <= 0.001 or sc.y <= 0.001:
			continue
		var ink := _number_ink(cell, t)
		var mid := _at(cell) + _islet_off(cell, t)
		draw_set_transform_matrix(page * Transform2D(0.0, sc, 0.0,
			Vector2(mid.x * (1.0 - sc.x), mid.y * (1.0 - sc.y))))
		drawn = true
		_glyph(font, px, str(int(state.need[cell])), Color(ink, ink.a * seen),
			mid + Vector2(0.0, r * (NUMBER_AT - COIN_LIFT)))
	if drawn:
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

## Press an islet, drag at the one facing it, let go: the run cycles
## 0-1-2-3-0. A tap on the water of a laid run wipes it in one go.
##
## The lit lane under the finger, the two refusals and everything they put on
## the tip card land with the rest of the gesture; this is the path the win
## harness drives, and it goes through `state.cycle` exactly as a finger does.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			if _press(event.position):
				accept_event()
		else:
			if _from != State.NOWHERE or _on_run != "":
				_release()
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
	_on_run = _run_over(cell)
	return _on_run != ""

## The laid run whose water covers `cell`, or "".
func _run_over(cell: Vector2i) -> String:
	for key in state.runs:
		if (state.lanes[key].cells as Array).has(cell):
			return String(key)
	return ""

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

## Let go. The three ways it can end, and there is no fourth: the lit lane
## cycles, a refused lane flashes and names its rule, or the tap wipes a run.
##
## **A press that never travelled half a cell is not a gesture and is not
## refused** -- the finger went down on an islet and came up again, which is
## how a player reads a number without meaning anything by it.
func _release() -> void:
	var from := _from
	var lane := _aim
	var dir := _aim_dir
	var wipe := _on_run
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	if _press_cell != State.NOWHERE and _press_up < 0.0:
		_press_up = _now()
		_busy_for(Motion.RELEASE_TIME)
	if from != State.NOWHERE:
		if dir == Vector2i.ZERO:
			_refresh()
			return
		if lane == "":
			_refuse_at(from, dir, "", "", TIP_NONE)
			return
		var blocker := state.blocked_by(lane)
		if blocker != "":
			_refuse_at(from, dir, lane, blocker, TIP_CROSS)
			return
		var before: int = state.planks(lane)
		var snap := _snapshot()
		if state.cycle(lane) == before:
			_refresh()
			return
		# The cycle runs 0-1-2-3 and back to 0: a plank laid, or the run lifted.
		fx.cue("place" if state.planks(lane) > before else "remove")
		_last = from
		_after_move(snap, from)
		return
	var wipe_snap := _snapshot()
	if wipe != "" and state.clear_run(wipe):
		fx.cue("remove")
		_after_move(wipe_snap)
	else:
		_refresh()

## A refused drag: the rule on the tip card, and the flash and the lean that
## carry it. The two refusals are the whole list -- an islet pushed over its
## number is drawn wrong and never comes through here.
##
## Reduce motion keeps the line and drops the movement, so nothing is recorded
## and the board does not redraw for six tenths of a second to show nothing.
func _refuse_at(from: Vector2i, dir: Vector2i, key: String, blocker: String,
		line: String) -> void:
	_say(tr(line), Face.Expr.STRAIN)
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
func _after_move(snap: Dictionary, src := State.NOWHERE) -> void:
	_wrong = {}
	_refuse = {}
	if _tip_text != tr(TIP_REST):
		_say(tr(TIP_REST), Face.Expr.HAPPY)
	_settle(snap, Callable(), src)
	note_move()

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
		islets[cell] = state.degree(cell) - int(state.need[cell])
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
		var now_d := state.degree(cell) - int(state.need[cell])
		if now_d == was_d:
			continue
		if now_d == 0:
			_met_at[cell] = t + landed
			_glint[cell] = t + landed + GLINT_LAG
			_later(t + landed, _met.bind(cell))
		elif now_d > 0 and was_d <= 0:
			_shiver_at[cell] = t
			fx.cue("over")
	_busy_for(maxf(longest + maxf(LAY_TIME, maxf(Motion.BUMP_TIME,
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

## An islet that has just come right: its ring and its note.
func _met(cell: Vector2i) -> void:
	fx.ring(_at(cell), _islet_r() * RING_R, Pal.GOOD)
	fx.cue("met")

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

# --- the HUD's actions ---

func can_undo() -> bool:
	return state.can_undo()

## An undo is not a move, so it does not go through `note_move()` and has to
## ask the contract itself -- `core/puzzle_base.gd` says hints and undos call
## `check_solved()` directly. Undo can only ever return to a position that was
## already checked when it was made, so today it never fires; leaving the call
## out would make that invariant load-bearing and nothing states or tests it.
func undo() -> bool:
	if is_done():
		return false
	var snap := _snapshot()
	if not state.undo():
		return false
	_wrong = {}
	_refuse = {}
	_say(tr(TIP_REST), Face.Expr.HAPPY)
	_settle(snap)
	fx.cue("undo")
	moved.emit()
	check_solved()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Lays one plank the answer has and the board lacks -- never an overshoot, so
## a hint can never itself be the thing that pushes an islet over its number.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var snap := _snapshot()
	var key := state.hint()
	if key == "":
		return false
	hints_used += 1
	_given[key] = true
	_wrong = {}
	_refuse = {}
	_say(tr("BR_HINT"), Face.Expr.HAPPY)
	_settle(snap)
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
## do (spec section 10). The near-miss -- every number met and the islets in
## two rings -- is left unsignposted on purpose, and this is its only door.
func check() -> int:
	if is_done():
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
	_say((tr("BR_CHECK_ONE") if wrong.size() == 1 else tr("BR_CHECK_N") % wrong.size())
		if not wrong.is_empty() else tr("BR_CHECK_OK"),
		Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_refresh()
	return wrong.size()

## Every plank goes, in a wave from the far corner with the islets hopping as
## it passes -- the table's Reset row, in this board's pieces. The hints a
## player spent are not refunded, only unpinned.
func reset_board() -> void:
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
	_solved_at = -1.0
	_depth = {}
	_sparked = {}
	moves = 0
	_running = true
	_say(tr(TIP_REST), Face.Expr.HAPPY)
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
	return state.share_glyphs()

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
	return _land_lag() + _wave_at(_wave_depth()) + Motion.SOLVE_TIME * 0.5

## How long after the last move the wave sets off: the last plank has to land
## before the light can run along it.
func _land_lag() -> float:
	return 0.0 if Motion.reduce else LAY_TIME * LAND_AT

## The solve: the wave's graph is the network the player built, walked once
## from the islet the last plank was laid at and then never walked again.
func _on_solved() -> void:
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
	_say(tr(TIP_REST), Face.Expr.HAPPY)
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
	if _solved_at < 0.0:
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
	if _solved_at < 0.0 or not _depth.has(cell):
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
	if _solved_at < 0.0 or t < _solved_at or Motion.reduce or _sparked.size() >= _depth.size():
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
