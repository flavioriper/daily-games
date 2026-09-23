extends "res://core/puzzle_base.gd"

## Pinwheel as a flat board: a frame of cells with a handful of paper pieces
## lying on it, each held down through one of its own squares by a pinwheel.
## Tap a pinwheel and its piece swings a quarter turn clockwise about the pin
## -- **the pin itself never moves**. The rules live in
## puzzles/pinwheel_state.gd, which this only draws.
##
## **Overlap is the working state, and the board says so.** A square two
## pieces are on is washed and hatched; a square nobody is on stays bare
## ground. So there is nothing to check: the board already answers,
## continuously, the only question a Check could ask. That is Word Trail's
## and Quilt's shape reached by a third route -- no tray because nothing is
## picked up, no actions row because there is no Check, Reset up in the top
## bar and the tip card alone at 140 -- and it is the first flat board that
## lets a player hold an illegal position **and shows them it is illegal**,
## rather than refusing the move or waiting to be asked.
##
## How it is drawn. Three meshes and no Controls:
##
##  1. `_frame` -- the ground and its cell rules, which never change;
##  2. `_still` -- every piece not swinging;
##  3. `_live`  -- the swinging pieces, so they draw over their neighbours,
##                 then the stain over all of them, then every pinwheel.
##
## A piece is one silhouette and not a row of squares (`ui/faces/patch_cloth.gd`,
## reused unchanged: `loops()` is shape-agnostic, so a turned piece is just
## another cell set), and the cached loops are per **(piece, orientation)** --
## four entries a piece at most -- rather than traced on the frame.
##
## `Cloth.laid()` takes a scale but no angle, so the swing cannot go through
## it: a swinging piece is laid out in board pixels and then turned about its
## pin, point by point. It pops about its pin too, which `laid` does carry --
## the span it squashes about is `2 * pin + 1`, whose middle is exactly the
## pin's own centre.
##
## Spec: docs/superpowers/specs/2026-09-20-pinwheel-flat-design.md, section 7.
## Ported from the canvas mock at docs/brainstorm/concepts.html#pinwheel,
## which is the reference for every measure here.

const State = preload("res://puzzles/pinwheel_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
## The cloth -- the silhouette, the lip and the eight colours -- and the
## pinwheel over it. Both live in ui/faces/ because the menu card draws the
## same two things and neither should own the other's drawing.
const Cloth = preload("res://ui/faces/patch_cloth.gd")
const PinWheel = preload("res://ui/faces/pin_wheel.gd")

# --- the screen, measured (spec section 4) ---
## The card's own inset, all round. At the standard 1000 x 1340 card that
## leaves 944 x 1284, so band 1's cell is 183 -- the largest cell of any flat
## board, and not indulgence: the tap target is the pin cell and nothing
## else, so a generous cell is what stops a mis-tap turning a neighbour.
const INSET := 28.0
## The ground's border round the grid, its corner and its rim, in design
## pixels. It is drawn **outside** the cells, so on the band where the cell
## is bound by the width it eats into the inset rather than into the grid --
## 10 px of card is still clear of it, and shrinking the cell for it would
## cost the spec's measured 183.
const FRAME_PAD := 18.0
const FRAME_RADIUS := 26.0
const FRAME_RIM := 7.0

# --- the cloth and the ground, in cells ---
## The faint rules between two cells of the frame.
const RULE_W := 0.018
## A piece's own edge: **solid**, in `Cloth.cloth_stitch`. `Cloth.dash_loop`
## in `Pal.BAD` is Quilt's refusal idiom and a permanent dashed edge would
## steal it.
const EDGE_W := 0.04
## The rose halo a refused piece wears instead of blushing (see `_halo`).
const HALO_W := 0.085
## The pinwheel's radius, in cells. One of this board's own two constants,
## and both are shape rather than timing.
const PIN_R := 0.19
## How far a pinwheel's hub is taken toward the ink off its own piece's
## cloth. That the hub wears the piece's colour is the only thing saying
## whose handle it is, and on a board where a pin can sit underneath another
## piece -- nothing prevents it -- that started as prettiness and is now
## load-bearing.
const HUB_MIX := 0.42

# --- the stain ---
## The wash a stained cell takes, and the hatch over it. This board's other
## own constant.
##
## **A wash alone cannot signal state on pieces coloured by index**, which is
## Quilt's "a patch cannot blush" lesson from the other end. A flat wash over
## a piece is a fourth-darker version of that piece's cloth, and on a board
## where every piece is already a different colour the eye reads it as
## *another cloth*: the first rendered frame had a coral under a wash reading
## as maroon and a butter reading as olive. A hatch cannot be a cloth --
## nothing else on this screen is drawn in lines -- so a hatched cell is
## unambiguously "two pieces here" whatever is under it.
const STAIN_ALPHA := 0.30
const HATCH_ALPHA := 0.20
const HATCH_W := 0.035
const HATCH_STEP := 0.24
## A stained cell's corner, and how it arrives: from a third of its size with
## the back ease. A corner is rounded only where the cell has no stained
## neighbour on either of its two sides, so a group of stained cells reads as
## one contested region with one outline and never double-darkens a seam.
const STAIN_RADIUS := 0.22
const STAIN_POP := 0.20
const STAIN_FROM := 0.35

# --- the swing ---
## A multi-quarter spin -- a hint, or the undo of one -- is longer than one
## quarter but **not n times longer**: at n times a three-quarter spin reads
## as a stall rather than as a spin.
const SWING_EXTRA := 0.6
## The blades keep turning a moment past the cloth, reading the same
## `Motion.turn_angle` with a longer time, so the pinwheel carries the
## overshoot the piece does not.
const HUB_FACTOR := 1.55
## The nudge a pinwheel gives when the player taps a piece somewhere that is
## not its pin: the vocabulary's wobble, wider and slower than a chip's,
## through the recipe's own parameters and never a copied constant.
const WOB_ANGLE := 0.42
const WOB_TIME := 0.46
## The ring a hint pulses, in cells, off the piece's pin.
const RING_R := 0.9
## How long a solved piece's edge takes to warm toward the sun, and how far.
const WARM_TIME := 0.3
const WARM_MIX := 0.7
## Long enough for the solve wave to cross the frame before the win screen
## covers it.
const WIN_WAIT := 1.6
## Three, as every flat board gives.
const HINTS := 3

const TIP_CYCLE := 8.0
const TIPS := [
	"Tap a pinwheel. Its piece turns a quarter, round the pin.",
	"A pin never moves. Only the piece round it turns.",
	"A darker cell is two pieces on one square. Turn one away.",
	"No bare ground, no dark cells, and the frame is done.",
]

var _state = State.new()
## The board's own effects node: the hint's ring and every sparkle come
## through it and nowhere else.
var fx: Node2D

## The pieces mid-swing: piece -> {"at": float, "quarters": int}. Clockwise
## is positive, so an undo's swing is negative and goes back the way it came.
var _swing: Dictionary = {}
## Per piece, the moment its swing **lands**. The stain wave keys on this and
## not on the tap: keyed on the tap, a mid-swing frame shows the wash sitting
## on a cell the piece is still seventy degrees away from.
var _turned_at := PackedFloat32Array()
## Per piece, when its pinwheel was last nudged by a tap on the wrong cell.
var _wob: Dictionary = {}
## A refused tap on a pinned-fast piece: {"piece": int, "at": float}.
var _refused: Dictionary = {}
## The rings and sparkles a wave still owes: [{"at", "point", "colour", "ring"}].
var _pending: Array = []
## The cell a press landed on, so a release somewhere else is not a tap.
var _pressed := Vector2i(-1, -1)

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
## The piece the last gesture moved: the solve wave runs out of its pin.
var _last_turned := 0

## The ground, the still pieces, and everything that is moving. Dropped
## whenever something changed so the next _draw rebuilds them.
var _frame_mesh: ArrayMesh
var _still: ArrayMesh
var _live: ArrayMesh
## The meshes the last _draw actually handed to the canvas item. A canvas
## command holds a mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: Array = []

## Each piece's boundary loops, per orientation, in cell units: [p][o] ->
## Array[PackedVector2Array]. Four entries a piece at most, and tracing on
## the frame is exactly what this cache exists to avoid.
var _loops: Array = []
## Each orientation's quarter turn off the grown one, so a resting pinwheel
## faces the way its piece is lying.
var _quarter: Array = []
## The longest wave any pin can send across this frame, so `_animating` can
## ask one question about the stain instead of one per cell.
var _wave_span := 0.0

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "pinwheel"
func title() -> String: return "Pinwheel"

func rules() -> String:
	return "Every piece is pinned through one of its own squares by a pinwheel, and that pin never moves. Tap a pinwheel and its piece turns a quarter clockwise about the pin. A quarter that would carry the piece off the frame is skipped rather than refused, so a tap always does something and every way round is reachable. Pieces may lie across each other while you work: a square two pieces are on goes dark and hatched, and a square nobody is on stays bare ground. A piece with only one way to lie is pinned fast; tapping it says so and nothing else. Turn them until there is no dark and no bare ground, and the frame is covered exactly once."

## Undo and Hint, and nothing else. There is no Check because nothing is
## hidden: a bare cell is drawn bare and a stained cell is drawn stained. So
## the registry drops the actions row and Reset rides up into the top bar.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.setup(rng, difficulty)
	_swing = {}
	_wob = {}
	_refused = {}
	_pending = []
	_pressed = Vector2i(-1, -1)
	_anim_until = 0.0
	_solved_at = -1.0
	_last_turned = 0
	_turned_at = PackedFloat32Array()
	_turned_at.resize(_state.shapes.size())
	_shape_cache()
	_layout()
	_enter()
	# The opening stain arrives **with the pieces that make it**, not before
	# them: a piece's landing moment starts as the moment its entrance pop
	# finishes, so the wash and its hatch fan out of the pins as the frame
	# fills rather than lying on bare ground waiting for pieces to appear.
	# The mock draws it from the first frame and reads as a ghost for it.
	for p in _state.shapes.size():
		_turned_at[p] = _opened + Motion.ENTER_DELAY \
			+ Motion.stagger(p, Motion.ENTER_STAGGER) + Motion.POP_IN
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()

## Every piece's silhouette in every way it can lie, traced once, plus which
## quarter turn off the grown shape each of those is. A piece has at most
## four orientations because the pin will not let it translate, so the whole
## cache is at most four loops a piece -- the alternative is tracing a
## boundary per piece on every frame of a swing.
func _shape_cache() -> void:
	_loops = []
	_quarter = []
	for p in _state.shapes.size():
		var list: Array = _state.shapes[p]
		var pin := _state.pin_cell(p)
		var loops: Array = []
		var quarters: Array = []
		for o in list.size():
			loops.append(Cloth.loops(list[o]))
			quarters.append(_quarter_of(list[0], list[o], pin))
		_loops.append(loops)
		_quarter.append(quarters)
	# The far corner of the frame from the nearest pin is the longest any
	# stain wave can run; one number, asked once.
	_wave_span = float(maxi(_state.cols, _state.rows)) * Motion.WAVE_STEP + STAIN_POP

## Which quarter turn about `pin` carries `base` onto `want`. A symmetric
## piece matches on more than one; the first is taken, because the pinwheel
## only has to look as though it is lying the way its piece is.
func _quarter_of(base: Array, want: Array, pin: Vector2i) -> int:
	var key := _cell_key(want)
	for q in 4:
		if _cell_key(_rotated(base, pin, q)) == key:
			return q
	return 0

func _rotated(cells: Array, pin: Vector2i, quarters: int) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		var d := c - pin
		for _i in posmod(quarters, 4):
			d = Vector2i(-d.y, d.x)
		out.append(pin + d)
	return out

func _cell_key(cells: Array) -> String:
	var ids: Array = []
	for c: Vector2i in cells:
		ids.append("%d,%d" % [c.x, c.y])
	ids.sort()
	return ";".join(ids)

# --- layout ---

## The cell, bound by whichever of the card's two sides runs out first. The
## frame's border is drawn outside it and takes its 18 out of the inset, so
## the cell itself is the spec's measured one: 188 on band 0, 183 on band 1
## and 157 on band 2.
func _cell() -> float:
	if _state.cols <= 0 or _state.rows <= 0:
		return 0.0
	return minf((size.x - 2.0 * INSET) / float(_state.cols),
		(size.y - 2.0 * INSET) / float(_state.rows))

## The top-left of the grid, centred in the card both ways.
func _origin() -> Vector2:
	var cell := _cell()
	return Vector2((size.x - float(_state.cols) * cell) * 0.5,
		(size.y - float(_state.rows) * cell) * 0.5)

func _grid_centre() -> Vector2:
	var cell := _cell()
	return _origin() + Vector2(float(_state.cols), float(_state.rows)) * cell * 0.5

## The middle of a cell, in board pixels.
func cell_to_local(c: int, r: int) -> Vector2:
	return _origin() + (Vector2(float(c), float(r)) + Vector2(0.5, 0.5)) * _cell()

## The pin of piece `p`, in board pixels.
func _pin_point(p: int) -> Vector2:
	var pin := _state.pin_cell(p)
	return cell_to_local(pin.x, pin.y)

## The cell under a local point, or (-1, -1) off the frame. **Never pack a
## cell as `row * cols + column` here**: Quilt shipped that and a hold one
## cell off the left edge wrapped onto the far right, 2,386 of them coming
## back legal across 120 boards. The column is bounds-checked before
## anything is packed, and `State.idx()` checks it again.
func _cell_at(local: Vector2) -> Vector2i:
	var cell := _cell()
	if cell <= 0.0:
		return Vector2i(-1, -1)
	var at := local - _origin()
	var c := int(floor(at.x / cell))
	var r := int(floor(at.y / cell))
	if c < 0 or r < 0 or c >= _state.cols or r >= _state.rows:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

## The card takes the whole slot it is given, so there is no slack for the
## host to place.
func card_height(available: float) -> float:
	return available

## True, and the answer does nothing on this phone -- Hidden Word's
## precedent. `card_height()` hands every pixel back, so the slack the host
## would halve is zero; the frame is centred *inside* the card instead. It
## says true because on a squarer screen the width would bind and the host's
## half would be the right place for the leftover.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_frame_mesh = null
	_refresh()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.shapes.is_empty():
		return
	var t := _now()
	# A swing that has just ended changes the draw order -- the piece drops
	# out of `_live` and back into index order -- so the frame it ends on has
	# to be redrawn even if nothing else on the card is moving.
	var settled := _retire(t)
	_fire_pending(t)
	if settled or _animating(t):
		_refresh()

## Every ring and sparkle whose moment has come.
func _fire_pending(t: float) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	for e: Dictionary in _pending:
		if t < float(e["at"]):
			keep.append(e)
			continue
		if bool(e["ring"]):
			fx.ring(e["point"], _cell() * RING_R, e["colour"])
		fx.sparkle(e["point"], e["colour"])
		_busy_for(Motion.RING_TIME)
	_pending = keep

## Queues one sparkle, and optionally a ring, on a local point `after`
## seconds from now. Nothing at all under reduce-motion: ui/fx2d.gd already
## draws neither, so this only spares the board the frames it would spend
## waiting for them.
func _fx_at(point: Vector2, colour: Color, after := 0.0, ring := true) -> void:
	if Motion.reduce:
		return
	_pending.append({"at": _now() + after, "point": point, "colour": colour, "ring": ring})
	_busy_for(after + Motion.RING_TIME)

## A swing that has settled -- blades and all -- stops being a swing;
## otherwise `_animating` would have to keep asking about it for ever. The
## landing moment is kept in `_turned_at`, which the stain reads long after
## the piece has stopped moving.
func _retire(t: float) -> bool:
	if _swing.is_empty():
		return false
	var gone := false
	for p in _swing.keys():
		var a: Dictionary = _swing[p]
		if t - float(a["at"]) >= _hub_time(int(a["quarters"])):
			_swing.erase(p)
			gone = true
	return gone

## Whether anything on this card is still moving, asked wave by wave rather
## than by one deadline. **Every** wave has to be in here -- the entrance,
## the swing and its blades, the stain settling behind it, the refusal and
## the solve hop: One Line shipped two lines frozen at four fifths of a fade
## because one was left out, and it showed in a rendered frame and in no
## test.
func _animating(t: float) -> bool:
	if not _pending.is_empty():
		return true
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	# The entrance: the frame's wide pop, then the pieces popping in.
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(maxi(_state.shapes.size() - 1, 0), Motion.ENTER_STAGGER) + Motion.POP_IN
	if t - _opened < entrance:
		return true
	if not _swing.is_empty():
		return true
	# The stain fans out of a pin *after* the piece that moved has landed.
	for p in _turned_at.size():
		if t - float(_turned_at[p]) < _wave_span:
			return true
	for p in _wob:
		if t - float(_wob[p]) < WOB_TIME:
			return true
	if not _refused.is_empty():
		var since := t - float(_refused["at"])
		if since < maxf(Motion.FLASH_IN + Motion.FLASH_OUT, Motion.SHIVER_TIME):
			return true
	if _solved_at >= 0.0 and t - _solved_at < Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME:
		return true
	return false

## How long the solve wave takes to cross the frame: the far pin's delay.
func _solve_span() -> float:
	if Motion.reduce:
		return 0.0
	return float(maxi(_state.cols, _state.rows)) * Motion.WAVE_STEP

## How long a swing of `quarters` quarters runs. Nothing at all under
## reduce-motion, so the piece is already home and the stain lands with it.
func _swing_time(quarters: int) -> float:
	if Motion.reduce:
		return 0.0
	var n := absi(quarters)
	if n <= 1:
		return Motion.TURN_TIME
	return Motion.TURN_TIME * (1.0 + SWING_EXTRA * float(n - 1))

func _hub_time(quarters: int) -> float:
	return _swing_time(quarters) * HUB_FACTOR

## Keeps the card redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the meshes so the next _draw rebuilds them, and asks for that draw.
## What the last _draw handed over is still held by _shown, so the renderer
## is never left pointing at a freed RID.
func _refresh() -> void:
	_still = null
	_live = null
	queue_redraw()

# --- where each piece is, this frame ---

## How far piece `p` still has to swing, in radians: zero once it has
## settled. The piece is already drawn in the orientation it has turned *to*,
## so this is the residual that starts it back where it came from --
## `Motion.turn_angle` less the full angle, which is the vocabulary's reader
## read backwards rather than a second curve.
func _swung(p: int, t: float, time_scale := 1.0) -> float:
	if not _swing.has(p):
		return 0.0
	var a: Dictionary = _swing[p]
	var q := int(a["quarters"])
	var full := float(q) * PI * 0.5
	return Motion.turn_angle(t - float(a["at"]), q, _swing_time(q) * time_scale) - full

## Everything the drawing needs to know about one piece this frame: its pop,
## how far round it still is, where the shiver and the solve hop have moved
## it, and how warm its edge has gone.
func _frame_of(p: int, t: float) -> Dictionary:
	var sc := Motion.pop_in_scale(t - _opened - Motion.ENTER_DELAY
		- Motion.stagger(p, Motion.ENTER_STAGGER))
	var offset := Vector2.ZERO
	if not _refused.is_empty() and int(_refused["piece"]) == p:
		offset.x += Motion.shiver_offset(t - float(_refused["at"]))
	var warm := 0.0
	if _solved_at >= 0.0:
		var at := _solved_at + _solve_delay(p)
		offset.y += Motion.hop_lift(t - at, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		warm = 1.0 if Motion.reduce else clampf((t - at) / WARM_TIME, 0.0, 1.0)
	return {"sc": sc, "angle": _swung(p, t), "offset": offset, "warm": warm}

## When the solve wave reaches piece `p`: the delay, then a king move a cell
## out from the pin of the piece that finished the board.
func _solve_delay(p: int) -> float:
	if Motion.reduce:
		return 0.0
	var a := _state.pin_cell(p)
	var b := _state.pin_cell(_last_turned)
	var k := maxi(absi(a.x - b.x), absi(a.y - b.y))
	return Motion.SOLVE_DELAY + float(k) * Motion.WAVE_STEP

# --- the drawing ---

## The ground first, then every piece that is standing still, then everything
## that is moving: the swinging pieces over their neighbours, the stain over
## all of them, and the pinwheels over the lot. The whole group pops in wide
## about the grid's centre while it fades (rule 7: a wide thing comes from
## most of the way).
func _draw() -> void:
	if _state.shapes.is_empty() or _cell() <= 0.0:
		_shown = []
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		_shown = []
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _grid_centre()
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	var shown: Array = []
	if _frame_mesh == null:
		_frame_mesh = _build_frame()
	if _frame_mesh != null:
		draw_mesh(_frame_mesh, null, xf, tint)
		shown.append(_frame_mesh)
	if _still == null:
		_still = _build_still(t)
	if _still != null:
		draw_mesh(_still, null, xf, tint)
		shown.append(_still)
	if _live == null:
		_live = _build_live(t)
	if _live != null:
		draw_mesh(_live, null, xf, tint)
		shown.append(_live)
	_shown = shown

## The ground: one panel of Shikaku's unclaimed plot behind the grid, the
## faint rules between its cells, and a rim round the lot. It carries no
## clock at all, so it is built once a layout and not once a frame.
func _build_frame() -> ArrayMesh:
	var b := Face.Builder.new()
	var cell := _cell()
	var at := _origin() - Vector2.ONE * FRAME_PAD
	var box := Vector2(float(_state.cols), float(_state.rows)) * cell + Vector2.ONE * (2.0 * FRAME_PAD)
	var panel := Face.Builder.round_rect(at, box, FRAME_RADIUS)
	b.polygon(panel, Pal.QUILT_BACK)
	var rule := Pal.QUILT_RULE
	var w := maxf(2.0, cell * RULE_W)
	for c in range(1, _state.cols):
		var x := _origin().x + float(c) * cell
		b.stroke(PackedVector2Array([Vector2(x, _origin().y),
			Vector2(x, _origin().y + float(_state.rows) * cell)]), w, rule, false, false)
	for r in range(1, _state.rows):
		var y := _origin().y + float(r) * cell
		b.stroke(PackedVector2Array([Vector2(_origin().x, y),
			Vector2(_origin().x + float(_state.cols) * cell, y)]), w, rule, false, false)
	b.stroke(panel, FRAME_RIM, Pal.LINE, true)
	return _mesh(b)

## Every piece that is not swinging, in index order.
func _build_still(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	for p in _state.shapes.size():
		if _lifted(p, t):
			continue
		_piece(b, p, _frame_of(p, t))
	return _mesh(b)

## Whether piece `p` is off the pile this frame: it is lifted **only while
## its cloth is actually turning**, and not for the extra moment its blades
## keep spinning. Dropping it back into index order is a visible change of
## which neighbour is on top, so it happens on the frame the piece lands --
## the same frame the stain arrives on the cells it has taken, which is
## where the eye already is -- rather than a sixth of a second later with
## nothing else moving to explain it.
func _lifted(p: int, t: float) -> bool:
	if not _swing.has(p):
		return false
	var a: Dictionary = _swing[p]
	return t - float(a["at"]) < _swing_time(int(a["quarters"]))

## Everything that is moving, in the one order that works: a swinging piece
## has to draw over the neighbours it is turning across, the stain has to
## draw over every piece or it says nothing, and a pinwheel is the handle and
## draws over all of it.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	for p in _state.shapes.size():
		if not _lifted(p, t):
			continue
		_piece(b, p, _frame_of(p, t))
	_stain(b, t)
	_pins(b, t)
	return _mesh(b)

## A builder's mesh, or null when it has nothing in it. Asking an empty
## builder for a mesh is an engine error ("array_len == 0"), and the live
## mesh is empty on any frame with nothing swinging, no stain and the
## entrance still scaling every pinwheel up from nothing.
func _mesh(b) -> ArrayMesh:
	return b.mesh() if not b.verts.is_empty() else null

## One piece's silhouette, laid out in board pixels and then turned about its
## pin. `Cloth.laid()` carries a scale but no angle, so the turn is applied
## point by point after it -- the same bargain `quilt2d.gd` makes with its
## entrance `grow`, one level further in.
##
## The span handed to `laid` is `2 * pin + 1`, whose middle is exactly the
## pin's own centre, so the pop squashes about the pin rather than about the
## piece's bounding box. A piece of five cells cannot enclose a hole -- it
## takes eight -- so every loop off `Cloth.loops` here is an outer one.
func _piece_pts(p: int, o: int, sc: Vector2, angle: float, offset: Vector2) -> Array:
	var cell := _cell()
	var pin := _state.pin_cell(p)
	var span := Vector2i(pin.x * 2 + 1, pin.y * 2 + 1)
	var at := _pin_point(p)
	var out: Array = []
	for loop: PackedVector2Array in (_loops[p] as Array)[o]:
		var pts := Cloth.laid(loop, _origin(), cell, span, sc)
		if absf(angle) > 0.0001 or offset != Vector2.ZERO:
			for i in pts.size():
				pts[i] = at + (pts[i] - at).rotated(angle) + offset
		out.append(pts)
	return out

## One piece: its cloth over its own lip, a solid edge round it, and the rose
## halo if it has just been refused.
func _piece(b, p: int, f: Dictionary) -> void:
	var sc: Vector2 = f["sc"]
	if sc.x <= 0.0 or sc.y <= 0.0:
		return
	var cell := _cell()
	var ci := int(_state.cloth[p])
	var warm := float(f["warm"])
	var edge := Cloth.cloth_stitch(ci)
	if warm > 0.0:
		edge = edge.lerp(Pal.SUN_RAY, warm * WARM_MIX)
	var lip := Vector2(0.0, Cloth.EDGE * cell)
	var pts_all := _piece_pts(p, int(_state.turned[p]), sc, float(f["angle"]), f["offset"])
	for pts: PackedVector2Array in pts_all:
		b.polygon(_moved(pts, lip), Cloth.cloth_deep(ci))
		b.polygon(pts, Cloth.cloth(ci))
		b.stroke(pts, EDGE_W * cell, edge, true)
	_halo(b, p, pts_all)

## A piece that is being turned down wears a rose **halo** round its
## silhouette. It does not blush.
##
## **The cloth cannot blush**, and Quilt measured why: the eight cloths run
## right round the wheel, so at 0.30 toward `Pal.BAD` the teal drops to 0.07
## saturation and comes back dead grey, the sage comes back khaki and the sky
## mauve. A greyed piece reads as *disabled* rather than as refused, which on
## a piece that is genuinely pinned fast would be exactly the wrong word. So
## the halo is drawn beside the cloth and the cloth is left alone:
## `docs/art/flat-motion.md`'s rule 9 read for a piece that is its own shape.
func _halo(b, p: int, pts_all: Array) -> void:
	if _refused.is_empty() or int(_refused["piece"]) != p:
		return
	var level := Motion.flash_level(_now() - float(_refused["at"]))
	if level <= 0.0:
		return
	for pts: PackedVector2Array in pts_all:
		b.stroke(pts, HALO_W * _cell(), Color(Pal.BAD, level), true)

## The stain: every cell more than one piece is sitting on, washed and then
## hatched.
##
## **Derived and never stored.** A cell's moment is the *later* of its
## pieces' landings -- the moment that piece finished arriving, not the
## moment it was tapped -- fanned out from that piece's own pin by king-move
## distance. So undo, reset and a hint's three-quarter spin all settle
## correctly, and none of them leaves a wave behind to clean up.
##
## Cells are drawn one at a time and their rects never overlap: a corner is
## rounded only where the cell has no stained neighbour on either of its two
## sides, which merges a group into one outline without laying a second wash
## over the seam between two of them.
func _stain(b, t: float) -> void:
	var cell := _cell()
	var occ := _owners()
	var stained := {}
	for r in _state.rows:
		for c in _state.cols:
			var os: Array = occ[r * _state.cols + c]
			if os.size() > 1:
				stained[Vector2i(c, r)] = os
	if stained.is_empty():
		return
	var wash := Color(Pal.TEXT, STAIN_ALPHA)
	var ink := Color(Pal.TEXT, HATCH_ALPHA)
	var step := cell * HATCH_STEP
	# The hatch's phase comes off the grid, not off a cell, so two stained
	# cells side by side carry one unbroken line across the seam.
	var phase := _origin().x - _origin().y
	for at: Vector2i in stained:
		var k := _stain_level(t, at, stained[at])
		if k <= 0.0:
			continue
		var half := cell * k * 0.5
		var centre := cell_to_local(at.x, at.y)
		var x0 := centre.x - half
		var y0 := centre.y - half
		var x1 := centre.x + half
		var y1 := centre.y + half
		b.polygon(_stain_box(at, stained, Vector2(x0, y0), Vector2(x1, y1),
			minf(cell * STAIN_RADIUS, half)), wash)
		var j := int(ceil(((x0 - y1) - phase) / step))
		while true:
			var cc := phase + float(j) * step
			if cc > x1 - y0:
				break
			var lo := maxf(y0, x0 - cc)
			var hi := minf(y1, x1 - cc)
			if hi > lo:
				b.stroke(PackedVector2Array([Vector2(lo + cc, lo), Vector2(hi + cc, hi)]),
					maxf(3.0, cell * HATCH_W), ink, false, false)
			j += 1

## How far a stained cell has arrived: nothing before its moment, then from a
## third of its size to all of it with the back ease.
func _stain_level(t: float, at: Vector2i, owners: Array) -> float:
	if Motion.reduce:
		return 1.0
	var src := int(owners[0])
	for i: int in owners:
		if _turned_at[i] >= _turned_at[src]:
			src = i
	var pin := _state.pin_cell(src)
	var k := maxi(absi(at.x - pin.x), absi(at.y - pin.y))
	var u := (t - (float(_turned_at[src]) + float(k) * Motion.WAVE_STEP)) / STAIN_POP
	if u <= 0.0:
		return 0.0
	return lerpf(STAIN_FROM, 1.0, Motion.back_out(clampf(u, 0.0, 1.0)))

## One stained cell's box, with a corner rounded only where the cell has no
## stained neighbour on either of the two sides that meet there.
func _stain_box(at: Vector2i, stained: Dictionary, lo: Vector2, hi: Vector2, r: float) -> PackedVector2Array:
	var left := stained.has(at + Vector2i(-1, 0))
	var right := stained.has(at + Vector2i(1, 0))
	var up := stained.has(at + Vector2i(0, -1))
	var down := stained.has(at + Vector2i(0, 1))
	var out := PackedVector2Array()
	_corner(out, Vector2(lo.x + r, lo.y + r), Vector2(lo.x, lo.y), r, PI, PI * 1.5, left or up)
	_corner(out, Vector2(hi.x - r, lo.y + r), Vector2(hi.x, lo.y), r, PI * 1.5, TAU, right or up)
	_corner(out, Vector2(hi.x - r, hi.y - r), Vector2(hi.x, hi.y), r, 0.0, PI * 0.5, right or down)
	_corner(out, Vector2(lo.x + r, hi.y - r), Vector2(lo.x, hi.y), r, PI * 0.5, PI, left or down)
	return out

func _corner(out: PackedVector2Array, centre: Vector2, sharp: Vector2, r: float,
		from: float, to: float, square: bool) -> void:
	if square or r <= 0.5:
		out.append(sharp)
		return
	out.append_array(Face.Builder.arc_points(centre, r, from, to))

## Who is sitting on every cell, once a frame. Asking the state per cell
## would walk every piece per cell; this walks every piece once.
func _owners() -> Array:
	var occ: Array = []
	occ.resize(_state.cols * _state.rows)
	for i in occ.size():
		occ[i] = []
	for p in _state.shapes.size():
		for c: Vector2i in _state.cells_of(p):
			var i := _state.idx(c.x, c.y)
			if i >= 0:
				(occ[i] as Array).append(p)
	return occ

## Every pinwheel, over everything. A piece with nowhere to turn gets a plain
## pin instead of a wheel: **a pinwheel that does not turn is a lie**, and
## drawing the difference is cheaper than explaining it in the tip card after
## the tap.
##
## The blades read the same swing with a longer time, so they carry the
## overshoot the cloth does not, and they sit at the quarter their piece is
## lying at, so a settled wheel says which way round its piece is.
func _pins(b, t: float) -> void:
	var cell := _cell()
	for p in _state.shapes.size():
		var f := _frame_of(p, t)
		var sc: Vector2 = f["sc"]
		if sc.x <= 0.0 or sc.y <= 0.0:
			continue
		# A wheel is a disc; the pop's squash on it is invisible at this size,
		# so it takes the scale that keeps its area rather than two axes it
		# cannot use.
		var r := cell * PIN_R * sqrt(sc.x * sc.y)
		var at := _pin_point(p) + (f["offset"] as Vector2)
		PinWheel.shadow(b, at, r, Pal.TEXT)
		if _state.fixed(p):
			PinWheel.pin(b, at, r, Pal.LINE, Pal.SURFACE)
			continue
		var rest := float((_quarter[p] as Array)[int(_state.turned[p])]) * PI * 0.5
		var wob := 0.0
		if _wob.has(p):
			wob = Motion.wobble_angle(t - float(_wob[p]), WOB_ANGLE, WOB_TIME)
		var hub := Cloth.cloth(int(_state.cloth[p])).lerp(Pal.TEXT, HUB_MIX)
		PinWheel.wheel(b, at, r, rest + _swung(p, t, HUB_FACTOR) + wob,
			Pal.LINE, Pal.SURFACE, hub)

func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out

## The chrome is the host's. The frame's entrance is one wide pop about its
## centre while it fades, and the pieces pop in behind it; both are read off
## the clock in _draw, so all this has to do is start it.
func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	_refresh()

# --- input ---

## A press names a cell and a release on the same cell is the tap. The pin is
## the only tap target on the board: pins never share a cell -- each sits on
## one of its own solution cells and the solution is a partition -- so a tap
## on a pin is never ambiguous, however deep the pieces are stacked over it.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	if event.pressed:
		_pressed = _cell_at(event.position)
		return
	var at := _cell_at(event.position)
	var was := _pressed
	_pressed = Vector2i(-1, -1)
	if at.x < 0 or at != was:
		return
	_tap(at)
	accept_event()

func _tap(at: Vector2i) -> void:
	var t := _now()
	var p := _state.piece_at_pin(at.x, at.y)
	if p >= 0 and not _state.fixed(p):
		var before: PackedInt32Array = _state.turned.duplicate()
		if not _state.turn(p):
			return
		_refused = {}
		_settle(before, t, false)
		fx.cue("place")
		_speak()
		_refresh()
		note_move()
		return
	if p >= 0:
		# The board's one refusal: a piece with a single in-frame orientation.
		# It costs no move, because nothing moved.
		_refused = {"piece": p, "at": t}
		_wob[p] = t
		_busy_for(maxf(Motion.FLASH_IN + Motion.FLASH_OUT, WOB_TIME))
		fx.cue("refused")
		_say("That one is pinned fast. It has nowhere else to go.", Face.Expr.STRAIN)
		_refresh()
		return
	# Any other cell: point at the handle rather than only naming it. This is
	# the board's answer to "which pin reaches this square", and it is why the
	# pin can be the only tap target.
	var over: Array = _state.pieces_over(at.x, at.y)
	if over.is_empty():
		_say("Bare ground. Something has to cover it.", Face.Expr.HAPPY)
	else:
		for i: int in over:
			_wob[i] = t
		_busy_for(WOB_TIME)
		_say("Turn a piece by its pinwheel.", Face.Expr.HAPPY)
	_refresh()

# --- the sprout's line ---

func _left_line() -> String:
	var bare := 0
	var stained := 0
	for i in _state.cover.size():
		var n := int(_state.cover[i])
		if n == 0:
			bare += 1
		elif n > 1:
			stained += 1
	if bare == 0 and stained == 0:
		return "Not a gap, not a fold."
	if stained == 0:
		return "One square bare." if bare == 1 else "%d squares bare." % bare
	if bare == 0:
		return "One square doubled." if stained == 1 else "%d squares doubled." % stained
	return "%d bare, %d doubled." % [bare, stained]

func _speak() -> void:
	if is_done():
		return
	_say(_left_line(), Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY or not _state.history.is_empty():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules: this
## board answers a turn with a count, and a refusal with the rule.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

## One diff of which way round every piece was against the way it is now,
## turned into the swings the drawing reads.
##
## **Every move goes through here** -- a tap, a hint's three-quarter spin, the
## undo that takes the whole spin back, a reset that turns thirteen pieces at
## once -- so no gesture can forget to animate a piece it moved, and none of
## them has to know which pieces those were. Queens' and Sudoku's `_settle`
## diff derived state and Quilt's diffs the pieces themselves; this one diffs
## the pieces too.
##
## The diff cannot see which way round a piece went, so `back` says it: a tap
## and a hint turn clockwise, an undo and a reset take the same quarters back
## the way they came.
func _settle(before: PackedInt32Array, t: float, back: bool, delays := {}) -> void:
	var longest := 0.0
	for p in _state.shapes.size():
		var was := int(before[p])
		var now := int(_state.turned[p])
		if was == now:
			continue
		var m: int = (_state.shapes[p] as Array).size()
		var quarters := -posmod(was - now, m) if back else posmod(now - was, m)
		var at := t + float(delays.get(p, 0.0))
		# Under reduce-motion nothing swings, so nothing is lifted out of
		# index order either: a piece that was raised into `_live` for a
		# swing it never takes would drop back a frame later and the player
		# would see two neighbours swap which is on top for no reason.
		if not Motion.reduce:
			_swing[p] = {"at": at, "quarters": quarters}
		_turned_at[p] = at + _swing_time(quarters)
		_last_turned = p
		longest = maxf(longest, at - t + _hub_time(quarters))
	if longest > 0.0 or not delays.is_empty():
		_busy_for(longest + _wave_span)

func can_undo() -> bool:
	return not _state.history.is_empty()

## Takes back the last move -- one quarter for a tap, a hint's whole spin for
## a hint, because an undo that left a hinted piece three quarters wrong
## would be a hint the player had to pay for twice. Counts no move.
func undo() -> bool:
	if is_done():
		return false
	var before: PackedInt32Array = _state.turned.duplicate()
	var back: Dictionary = _state.undo()
	if back.is_empty():
		return false
	_refused = {}
	_settle(before, _now(), true)
	_say("Turned back. " + _left_line(), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	check_solved()
	return true

func hints_left() -> int:
	return _state.hints_left()

## Turns the piece furthest from home all the way home, in one spin and one
## history entry. Counts no move, and the hint is not refunded by the undo
## that takes it back.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var before: PackedInt32Array = _state.turned.duplicate()
	var out: Dictionary = _state.hint()
	if out.is_empty():
		_say("Every piece is already home.", Face.Expr.HAPPY)
		return false
	hints_used = _state.hints_used
	var p := int(out["piece"])
	_refused = {}
	_settle(before, _now(), false)
	_fx_at(_pin_point(p), Pal.LEAF)
	fx.cue("hint")
	_say("That one was facing the wrong way. " + _left_line(), Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	# A hint can finish the frame, and a board that ends on one still ends.
	check_solved()
	return true

## Every piece goes back the way it opened, in a wave out of the far corner.
## A hint's piece goes back too: nothing here is a given, because a hint only
## turns a piece and the player could have turned it themselves.
func reset_board() -> void:
	var before: PackedInt32Array = _state.turned.duplicate()
	var moved_list: Array = _state.reset()
	if moved_list.is_empty():
		return
	# The far corner first, by the pin's distance down the diagonal.
	var order: Array = []
	for e: Dictionary in moved_list:
		var pin := _state.pin_cell(int(e["piece"]))
		order.append({"piece": int(e["piece"]), "rank": pin.x + pin.y})
	order.sort_custom(func(a, b): return int(a["rank"]) > int(b["rank"]))
	var delays := {}
	for k in order.size():
		delays[int((order[k] as Dictionary)["piece"])] = Motion.stagger(k, Motion.RESET_STAGGER)
	_refused = {}
	_pending = []
	_solved_at = -1.0
	_settle(before, _now(), true, delays)
	moves = 0
	_running = true
	_say("Back to the start. " + _left_line(), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

## A completed daily is rebuilt from its seed, so it reopens on its opening
## orientations. Put every piece on its answer and settle the picture at once:
## no swing, no stain wave, no entrance, and the solve wave already run, so
## every edge wears its full warmth and no piece is mid-hop -- exactly a frame
## whose solve has finished. Never `check_solved()`: the host owns the win for
## an already-completed daily and `solved` must not fire a second time.
func restore_completed_board() -> void:
	var t := _now()
	_state.turned = _state.answer.duplicate()
	_state.history = []
	_state.recompute()
	_swing = {}
	_wob = {}
	_refused = {}
	_pending = []
	_pressed = Vector2i(-1, -1)
	_anim_until = 0.0
	_opened = t - 10.0
	for p in _turned_at.size():
		_turned_at[p] = t - 10.0
	# In the past, so `_frame_of` reads a landed hop and a full warm edge and
	# `_animating` finds nothing left of the wave.
	_solved_at = t - 10.0
	_tip_timer.stop()
	_say("Not a gap, not a fold.", Face.Expr.JOY)
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

func share_glyphs() -> String:
	return _state.share_glyphs()

# --- the win ---

## No cast: this board seats no character at all, which puts it with
## Nonogram, Sudoku, Bridges and Quilt. What it adds to `ui/faces/` is a
## **drawing and not a character** -- `ui/faces/pin_wheel.gd`, builder shapes
## exactly as `mosaic_tile.gd` and `patch_cloth.gd` are, because thirteen
## pinwheels batch into one mesh and a Control per pin would be a node per
## pin of a thing with no face on it.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "Every piece turned home."}

## Long enough for the solve wave to cross the frame. Under reduce-motion
## there is no wave, so the win follows the last turn.
func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

func _on_solved() -> void:
	_solved_at = _now()
	_tip_timer.stop()
	# Gold on each piece as the hop reaches it, and no ring: thirteen rings
	# over a finished frame is a firework.
	for p in _state.shapes.size():
		_fx_at(_pin_point(p), Pal.SUN, _solve_delay(p), false)
	_busy_for(Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME)
	_say("Not a gap, not a fold.", Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
