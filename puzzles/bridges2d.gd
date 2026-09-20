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
## How it is drawn, and it is Word Trail's arrangement wholesale. One
## `ArrayMesh` carries everything with no glyph on it -- the pool, its rim and
## shallow band, the ripples, the lit lane under the finger, a refusal's band,
## the hint glows, the planks, the islets and their
## rings -- and the numbers go over the top as `draw_string` commands, because
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

# --- the screen, measured (spec section 6) ---
## The sea pool's inset from the card, and the lattice's own inset inside the
## pool. At 1080 wide that is a 1000 card, a 944 pool and a **920 lattice at
## every band**, so the width binds and a cell is 131 / 102 / 84.
const INSET := 28.0
const FIELD_PAD := 12.0
## What those two come to in design space, recorded so a layout that stops
## measuring 920 is caught rather than explained away.
const FIELD := 920.0
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
## The pool's corner, the rim it stands on, and the paler band of shallows
## inside that rim: how far in it sits, how thick it is, its corner and how
## far its colour is let through.
const POOL_RADIUS := 34.0
const POOL_EDGE := 9.0
const SHALLOW_INSET := 9.0
const SHALLOW_W := 26.0
const SHALLOW_RADIUS := 26.0
const SHALLOW_ALPHA := 0.85
## The ripples: how many, how thick, how far they are let through, and the
## box they are sown in -- in from the pool's left, down from its top, and
## how much of the pool's width and height they spread over. The span is
## short of the pool by more than a ripple's length on purpose: the mock
## clipped them to the pool and a mesh cannot, so they are sown clear of the
## rim instead of cut at it.
const RIPPLES := 9
const RIPPLE_W := 8.0
const RIPPLE_ALPHA := 0.24
const RIPPLE_AT := Vector2(60.0, 70.0)
const RIPPLE_SPAN := Vector2(190.0, 140.0)
const RIPPLE_LEN := Vector2(40.0, 60.0)
const RIPPLE_BOW := 8.0

# --- an islet, in cells or in fractions of its own radius ---
## The turf disc's radius as a fraction of the cell, and everything else as a
## fraction of that radius: the coloured shadow under it, the sand rim it
## stands on, the turf itself, the sun cap on the turf's shoulder, the ring a
## satisfied islet wears, and where the number sits.
const ISLET_R := 0.40
const SHADOW_AT := 0.30
const SHADOW_RX := 1.02
const SHADOW_RY := 0.40
const SHADOW_ALPHA := 0.30
const SAND_DROP := 0.07
const TURF_R := 0.80
const TURF_DROP := 0.04
const CAP_AT := Vector2(-0.22, -0.34)
const CAP_R := Vector2(0.30, 0.17)
const CAP_ALPHA := 0.55
const RING_R := 1.13
const RING_W := 0.13
const RING_MIN := 4.0
const RING_ALPHA := 0.95
const NUMBER_SIZE := 0.95
const NUMBER_AT := -0.04
## How far a met islet's ink is let down toward the paper: a number that has
## been answered steps back rather than shouting.
const NUMBER_MET := 0.38
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
const BEAM_ALPHA := 0.72
## The ring round the islet the finger is about to join: its radius and its
## thickness in islet radii, the floor under that thickness so an 11x11 still
## draws a ring rather than a hair, and how far its gold is let through.
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
## **at the peak of its flash**: the mark rides `Motion.flash_level` off the
## moment Check named it, the way Nonogram's `_wrong` does, so it blushes and
## settles rather than standing until the next move.
const BAD_MIX := 0.85
const BAD_DEEP_MIX := 0.6
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
const SEA := 0.46          # WATER_HI into PAPER -- #a4cde6, the open water
const SEA_PALE := 0.74     # WATER_HI into PAPER -- #cfdfe4, the shallows
const SEA_DEEP := 0.20     # WATER_HI into TEXT  -- #5896c2, the pool's edge
const SEA_SHADE := 0.35    # WATER into TEXT     -- #336e99, an islet's shadow
## The islet: turf is BANK on an **ACORN** beach. The beach was STONE in the
## first cut and the islets stopped reading entirely -- STONE is value 237
## against a 230 sea, seven points apart, so the rim disappeared. ACORN sits
## 29 of value below the water and warm against a cool ground.
const BANK_HI := 0.26      # BANK into SURFACE, the turf's sun cap
const BANK_DEEP := 0.28    # BANK into TEXT, the turf's own lip
const SAND_DEEP := 0.22    # ACORN into TEXT, the wet sand at the waterline

## The tip card names the rule a gesture just broke; it is the only thing on
## this screen that explains itself, and it is the board's only door to the
## rules sheet.
##
## **There are exactly two refusals and there is no third** (spec section 5).
## An islet pushed *over* its number is not one of them: it is drawn wrong --
## a `BAD` ring and washed turf -- and the finger fixes it, which is the house
## rule that feedback beats a mode.
const TIP_REST := "Press an islet and drag at the one facing it."
const TIP_NONE := "Nothing faces it across the water."
const TIP_CROSS := "Another run crosses that lane."

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
var _shown: ArrayMesh

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

var _tip_text := TIP_REST
var _tip_mood := Face.Expr.HAPPY

func puzzle_id() -> String: return "bridges"
func title() -> String: return "Bridges"

## The four rules of the spec's section 1, in that order and **connectivity
## last**, because it is the one the reference's own rules card leaves out and
## the one this whole board rests on.
func rules() -> String:
	return "Join the islets with plank bridges.\n" \
		+ "Each islet takes exactly its number of planks.\n" \
		+ "Bridges run across or down only, never over an islet.\n" \
		+ "At most three planks join the same two islets, and no two runs may cross.\n" \
		+ "When you are done, every islet must be joined into one single network."

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
	resized.connect(_refresh)
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
	_press_cell = State.NOWHERE
	_press_up = -1.0
	_solved_at = -1.0
	_depth = {}
	_sparked = {}
	_anim_until = 0.0
	_say(TIP_REST, Face.Expr.HAPPY)
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
	var top := minf(a.y, b.y) + r
	var bot := maxf(a.y, b.y) - r
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

# --- the drawing ---

## One mesh for everything with no glyph on it, then the numbers over the top.
## The order is the only one that works: an islet is opaque and a run ends
## under one.
## The whole card pops in wide about the pool's centre and fades as it comes
## (rule 7: a wide thing enters from most of the way, because the back ease's
## tenth of overshoot on a thousand units of width is a wobble), and the
## numbers take the same transform so a glyph never floats off the islet it
## belongs to.
func _draw() -> void:
	if state.islets.is_empty() or _cell() <= 0.0:
		return
	var t := _now()
	if _mesh == null:
		_mesh = _build(t)
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	var grow := Motion.wide_pop_scale(since)
	var mid := _pool().get_center()
	var page := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	if _mesh != null and seen > 0.0:
		draw_mesh(_mesh, null, page, Color(1.0, 1.0, 1.0, seen))
	_shown = _mesh
	if seen > 0.0:
		_draw_numbers(t, page, seen)

## The order the mock draws in, and it is not a preference either: the lit
## lane and a refusal's band go **under** the runs, so a highlight on the run
## in the way reads as a glow beneath it rather than a coat of paint over it,
## and everything goes under the islets, which are opaque.
func _build(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_water(b)
	_aim_band(b)
	_refusal(b, t)
	for key in state.runs:
		_run(b, String(key), t)
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
	_sweep(t)
	_spark(t)
	if t < _anim_until:
		_refresh()

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
		if t - float(ghost["at"]) < Motion.POP_OUT:
			keep.append(ghost)
	if keep.size() != _ghosts.size():
		_ghosts = keep
		_refresh()

## The pool: its face over a bottom edge in the deeper blue, the paler band of
## shallows inside the rim, and a few ripples over the open water.
func _water(b) -> void:
	var p := _pool()
	var deep: Color = Pal.WATER_HI.lerp(Pal.TEXT, SEA_DEEP)
	var sea: Color = Pal.WATER_HI.lerp(Pal.PAPER, SEA)
	var pale: Color = Pal.WATER_HI.lerp(Pal.PAPER, SEA_PALE)
	b.fan(Face.Builder.round_rect(p.position, p.size, POOL_RADIUS), deep)
	b.fan(Face.Builder.round_rect(p.position, Vector2(p.size.x, p.size.y - POOL_EDGE),
		POOL_RADIUS), sea)
	b.stroke(Face.Builder.round_rect(p.position + Vector2.ONE * SHALLOW_INSET,
		p.size - Vector2.ONE * 2.0 * SHALLOW_INSET, SHALLOW_RADIUS),
		SHALLOW_W, Color(pale, SHALLOW_ALPHA), true)
	var ink := Color(Pal.WATER, RIPPLE_ALPHA)
	for i in RIPPLES:
		var at := p.position + RIPPLE_AT + Vector2(
			_hash(i, 7) * (p.size.x - RIPPLE_SPAN.x),
			_hash(i, 11) * (p.size.y - RIPPLE_SPAN.y))
		var span := RIPPLE_LEN.x + _hash(i, 3) * RIPPLE_LEN.y
		b.stroke(Face.Builder.bezier2(at, at + Vector2(span * 0.5, -RIPPLE_BOW),
			at + Vector2(span, 0.0)), RIPPLE_W, ink)

## One run as it stands: the halo if a hint laid it, then a plank per count,
## each on its own coloured shadow. Three recipes meet on a run and every one
## of them is read as a curve -- a plank that has just been laid is still
## falling in with `Motion.drop_in_lift` and fading with `appear_level`, a run
## the last Check marked blushes toward BAD with `flash_level` and rattles
## across its own lane with `shiver_offset`, and a run the solve wave has
## reached wears the lit deck from the end the front came in at.
func _run(b, key: String, t: float) -> void:
	var count: int = state.planks(key)
	if count <= 0:
		return
	if _given.has(key) and not is_done():
		_glow(b, _lane_ends(key), _run_width(count))
	var laid: Dictionary = _laid.get(key, {})
	_planks(b, key, count, 1.0,
		t - float(laid.get("at", 1.0e9)), int(laid.get("from", count)),
		t - float(_wrong.get(key, -1.0e9)), _wave_of(key, t))

## A run that has gone, still shrinking away where it stood: the whole run at
## its old count, its planks closing to nothing with `Motion.pop_out_scale`.
func _ghost(b, ghost: Dictionary, t: float) -> void:
	var key := String(ghost["key"])
	if not state.lanes.has(key):
		return
	var grow := Motion.pop_out_scale(t - float(ghost["at"]))
	if grow <= 0.0:
		return
	_planks(b, key, int(ghost["count"]), grow, 1.0e9, int(ghost["count"]), -1.0e9, {})

## The thickness a run of `count` planks and the air between them comes to:
## what the hint's halo is drawn round.
func _run_width(count: int) -> float:
	var s := _cell()
	return float(count) * s * PLANK + float(count - 1) * s * PLANK_GAP

## The planks themselves. `grow` closes them about their own centres (one
## while they stand, `pop_out_scale` while a ghost of them leaves); `since`
## and `first_new` say which of them are still dropping in and from when;
## `since_wrong` is the moment Check marked the run, or long ago; `wave` is
## what `_front` said about this lane, `{}` when no wave is running.
func _planks(b, key: String, count: int, grow: float, since: float,
		first_new: int, since_wrong: float, wave: Dictionary) -> void:
	var s := _cell()
	var g := _lane_ends(key)
	var horiz: bool = g.horiz
	var thick := s * PLANK
	var air := s * PLANK_GAP
	var total := float(count) * thick + float(count - 1) * air
	var blush := Motion.flash_level(since_wrong)
	var rattle := Motion.shiver_offset(since_wrong)
	var shake := Vector2(0.0, rattle) if horiz else Vector2(rattle, 0.0)
	var face: Color = Pal.DECK.lerp(Pal.BAD, BAD_MIX * blush)
	var deep: Color = Pal.WOOD_DEEP.lerp(Pal.BAD, BAD_DEEP_MIX * blush)
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
		var fade := 1.0
		if i >= first_new:
			fade = Motion.appear_level(since)
			if fade <= 0.0:
				continue
		var r := minf(box.x, box.y) * PLANK_RADIUS
		b.fan(Face.Builder.round_rect(at + PLANK_SHADOW, box, r),
			Color(Pal.TEXT, PLANK_SHADOW_ALPHA * fade))
		if i >= first_new:
			at.y -= Motion.drop_in_lift(since)
		_plank(b, at, box, horiz, r, Color(face, fade), Color(deep, fade), wave)

## A plank: WOOD_DEEP under DECK, with a lip along its lower edge and slats
## across it -- the mock's own shape. `wave` lays the solve wave's gold over
## the part of it the front has already crossed, from the end the front came
## in at, so the light runs along the plank rather than switching it on.
func _plank(b, at: Vector2, box: Vector2, horiz: bool, r: float, face: Color,
		deep: Color, wave: Dictionary) -> void:
	b.fan(Face.Builder.round_rect(at, box, r), deep)
	var top := Vector2(box.x, box.y - PLANK_EDGE) if horiz else Vector2(box.x - PLANK_EDGE, box.y)
	b.fan(Face.Builder.round_rect(at, top, r), face)
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

## An islet: a coloured shadow on the water, a sand rim, the turf disc on it
## with a sun cap on its shoulder, and the ring it wears once its number is
## met -- GOOD when it is met exactly, BAD when the finger has pushed it over.
## An over-filled islet is **drawn wrong and never refused** (spec section 5).
## `lean` is the nudge a refused islet takes, which is why the whole thing is
## drawn about `mid` rather than about its cell.
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
	var met := got == want
	var over := got > want
	# The wave's flare, which is also the gold the planks wear: it rises as
	# the front arrives and settles again behind it, read off `flash_level`.
	var flare := 0.0
	var arrived := _arrived(cell, t)
	if arrived >= 0.0:
		flare = Motion.flash_level(arrived, WAVE_EDGE) * WAVE_FLARE
	b.ellipse(mid + Vector2(0.0, ry * SHADOW_AT), rx * SHADOW_RX, ry * SHADOW_RY,
		Color(Pal.WATER.lerp(Pal.TEXT, SEA_SHADE), SHADOW_ALPHA))
	b.ellipse(mid + Vector2(0.0, ry * SAND_DROP), rx, ry, Pal.ACORN.lerp(Pal.TEXT, SAND_DEEP))
	b.ellipse(mid, rx, ry, Pal.ACORN)
	b.ellipse(mid + Vector2(0.0, ry * TURF_DROP), rx * TURF_R, ry * TURF_R,
		Pal.BANK.lerp(Pal.TEXT, BANK_DEEP))
	var turf: Color = Pal.BANK.lerp(Pal.BAD, OVER_MIX) if over else Pal.BANK
	b.ellipse(mid, rx * TURF_R, ry * TURF_R, turf.lerp(Pal.SUN_RAY, flare))
	b.ellipse(mid + Vector2(CAP_AT.x * rx, CAP_AT.y * ry), rx * CAP_R.x, ry * CAP_R.y,
		Color(Pal.BANK.lerp(Pal.SURFACE, BANK_HI), CAP_ALPHA))
	if met or over:
		var ring: Color = Pal.BAD if over else Pal.GOOD
		b.stroke(Face.Builder.ring(mid, rx * RING_R, ry * RING_R),
			maxf(RING_MIN, r * RING_W),
			Color(ring.lerp(Pal.SUN_RAY, flare), RING_ALPHA), true)

## An islet's scale: the entrance pop it came in on, the bump it took when it
## met its number, and the bump the wave's front gives it on the way past.
## Every one of them is a reader off `core/motion.gd` handed the seconds since
## its own moment began, and they multiply, so an islet that is bumped
## mid-entrance does both rather than losing one.
func _islet_scale(cell: Vector2i, t: float) -> Vector2:
	var sc := Motion.pop_in_scale(t - _opened - _enter_delay(cell.x + cell.y))
	sc *= Motion.bump_scale(t - float(_met_at.get(cell, -1.0e9)))
	if cell == _press_cell:
		sc *= Motion.press_scale(t - _press_at,
			-1.0 if _press_up < 0.0 else t - _press_up)
	var arrived := _arrived(cell, t)
	if arrived >= 0.0:
		sc *= Motion.bump_scale(arrived)
	return sc

## Where an islet stands against its cell: the lean a refused drag gives the
## islet under the finger, the shiver of one the finger has just pushed over
## its number, and the hop Reset's wave carries it away on.
func _islet_off(cell: Vector2i, t: float) -> Vector2:
	var off := _lean(cell, t)
	off.x += Motion.shiver_offset(t - float(_shiver_at.get(cell, -1.0e9)))
	off.y += Motion.hop_lift(t - float(_hop_at.get(cell, -1.0e9)),
		Motion.RESET_HOP, Motion.HOP_TIME)
	return off

## The numbers, over the mesh: one `draw_string` each, as Nonogram draws its
## clues and Word Trail its letters. A met number steps back toward the paper
## and an over-filled one goes to BAD.
## The numbers, over the mesh. Each one takes its islet's own scale and the
## page's entrance through one `draw_set_transform_matrix` -- Nonogram's way
## with its clue lines -- so a glyph pops in, bumps and leans with the turf it
## stands on rather than floating over a piece that has moved out from under
## it.
func _draw_numbers(t: float, page: Transform2D, seen: float) -> void:
	var r := _islet_r()
	var font: Font = CozyTheme.display(700)
	var px := maxi(1, int(round(r * NUMBER_SIZE)))
	var drawn := false
	for cell in state.islets:
		var sc := _islet_scale(cell, t)
		if sc.x <= 0.001 or sc.y <= 0.001:
			continue
		var want: int = int(state.need[cell])
		var got: int = state.degree(cell)
		var ink: Color = Pal.TEXT
		if got > want:
			ink = Pal.BAD
		elif got == want:
			ink = Pal.TEXT.lerp(Pal.PAPER, NUMBER_MET)
		var mid := _at(cell) + _islet_off(cell, t)
		draw_set_transform_matrix(page * Transform2D(0.0, sc, 0.0,
			Vector2(mid.x * (1.0 - sc.x), mid.y * (1.0 - sc.y))))
		drawn = true
		_glyph(font, px, str(want), Color(ink, ink.a * seen),
			mid + Vector2(0.0, r * NUMBER_AT))
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
		_last = from
		_after_move(snap)
		return
	var wipe_snap := _snapshot()
	if wipe != "" and state.clear_run(wipe):
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
	_say(line, Face.Expr.STRAIN)
	if not Motion.reduce:
		_refuse = {"at": _now(), "from": from, "dir": dir, "key": key,
			"blocker": blocker}
		_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)
	_refresh()

## Every move clears the last Check's marks -- the board has changed under
## them -- and the refusal standing over it, hands the pieces that changed
## their moments, and counts itself, which is what ends the puzzle when the
## last plank lands on one single network.
func _after_move(snap: Dictionary) -> void:
	_wrong = {}
	_refuse = {}
	if _tip_text != TIP_REST:
		_say(TIP_REST, Face.Expr.HAPPY)
	_settle(snap)
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
## decides when.
func _settle(snap: Dictionary, when := Callable()) -> void:
	var t := _now()
	var was_runs: Dictionary = snap["runs"]
	var was_islets: Dictionary = snap["islets"]
	var keys := {}
	for key in was_runs:
		keys[key] = true
	for key in state.runs:
		keys[key] = true
	var longest := 0.0
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
		if now_count > was:
			_laid[key] = {"at": t + delay, "from": was}
			fx.puff(_lane_middle(key), Pal.DECK)
		else:
			_laid.erase(key)
			# Only a run that went **to zero** leaves a ghost: a run going 3
			# to 2 re-centres the planks it keeps, so there is no one plank
			# that left for a ghost to stand in for.
			if now_count == 0:
				_ghosts.append({"key": key, "count": was, "at": t + delay})
	for cell in state.islets:
		var was_d := int(was_islets.get(cell, -999))
		var now_d := state.degree(cell) - int(state.need[cell])
		if now_d == was_d:
			continue
		if now_d == 0:
			_met_at[cell] = t
			fx.ring(_at(cell), _islet_r() * RING_R, Pal.GOOD)
		elif now_d > 0 and was_d <= 0:
			_shiver_at[cell] = t
	_busy_for(longest + maxf(Motion.DROP_TIME,
		maxf(Motion.BUMP_TIME, maxf(Motion.POP_OUT, Motion.SHIVER_TIME))))
	_refresh()

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

func undo() -> bool:
	if is_done():
		return false
	var snap := _snapshot()
	if not state.undo():
		return false
	_wrong = {}
	_refuse = {}
	_say(TIP_REST, Face.Expr.HAPPY)
	_settle(snap)
	moved.emit()
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
	_say("A plank the answer wants is in.", Face.Expr.HAPPY)
	_settle(snap)
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
	_say("%d %s in the way." % [wrong.size(), "run is" if wrong.size() == 1 else "runs are"]
		if not wrong.is_empty() else "Nothing you have laid is wrong.",
		Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
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
	_press_cell = State.NOWHERE
	_press_up = -1.0
	_solved_at = -1.0
	_depth = {}
	_sparked = {}
	moves = 0
	_running = true
	_say(TIP_REST, Face.Expr.HAPPY)
	_settle(snap, _reset_wave)
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
	return {"faces": [], "subtitle": "One network, every islet on it."}

## Long enough for the wave that lights the network, which runs outward from
## the islet the player finished at. It spends the wave's own clock
## (`_wave_at`), so the win screen and the wave can never disagree about how
## long the wave is.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return _wave_at(_wave_depth())

## The solve: the wave's graph is the network the player built, walked once
## from the islet the last plank was laid at and then never walked again.
func _on_solved() -> void:
	_solved_at = _now()
	_depth = _wave_steps()
	_sparked = {}
	_refuse = {}
	_wrong = {}
	_busy_for(_wave_at(_wave_depth()) + Motion.FLASH_IN + Motion.FLASH_OUT
		+ Motion.BUMP_TIME)
	fx.cue("solved")
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
	if _solved_at < 0.0 or Motion.reduce or _sparked.size() >= _depth.size():
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
