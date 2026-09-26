extends "res://core/puzzle_base.gd"

## Quilt as a flat board: a shaped backing of pale cloth on the card, and
## under it, **inside the same card**, a rack of coloured patches waiting to
## be sewn on. Drag a patch onto the backing and it snaps to the cells; drag
## one that is already on to take it off again. The rules live in
## puzzles/quilt_state.gd, which this only draws.
##
## **Nothing wrong can be sitting on this quilt.** A drop is taken only if
## every cell of the patch lands on the backing and on no other patch, and
## the patches' cells sum to exactly the backing's, so the last patch sewn on
## *is* the solve. There is therefore no Check to put in an actions row: the
## registry drops the row, Reset rides up into the top bar, and the bottom
## slot is the tip card alone at 140 -- Word Trail's shape exactly.
##
## **Patches never turn.** Each one is shown in the one orientation it goes
## on in, on the rack and on the quilt alike, which is what keeps a drag to
## one decision (where) instead of two (where, and which way round).
##
## How it is drawn. Three meshes and no Controls: the quilt (the backing, its
## cell rules, the patches sewn on, the seams between them and the ghost
## under the finger), the rack (the patches still waiting, and any flying
## home), and the hand (the one patch being dragged, which has to draw over
## everything). A patch is **one polygon and not a row of squares**: its
## cells' boundary is traced into a loop, the loop's corners are rounded, and
## the whole silhouette is filled over a slightly deeper copy of itself --
## the family's lip. Cloth is cut in pieces, not tiled.
##
## Spec: docs/superpowers/specs/2026-09-20-quilt-flat-design.md, sections 6
## and 7. Ported from the canvas mock at
## docs/brainstorm/concepts.html#quilt, which is the reference for every
## measure here.

const State = preload("res://puzzles/quilt_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
## The cloth itself -- the silhouette, the lip, the stitch and the eight
## colours -- lives in ui/faces/, because the menu card draws the same patch
## and neither should own the other's drawing (ui/faces/mosaic_tile.gd's
## bargain, and for the same reason).
const Cloth = preload("res://ui/faces/patch_cloth.gd")

# --- the screen, measured (spec section 6) ---
## The card's own inset, all round.
const INSET := 28.0
## How the card's content height is split. At the standard 1340 card the
## content is 1284, and the field takes 800 of it, the air 28 and the rack
## the remaining 456. Kept as a share rather than as three constants so a
## card of another height splits in the same proportion instead of spending
## every extra pixel on the rack.
const FIELD_SHARE := 800.0 / 1284.0
const RACK_PAD := 28.0
## The largest cell a small quilt may have. Without it a five-patch board on
## a 5 x 4 box comes out at 188 a cell and reads as a toy.
const CELL_MAX := 150.0
## How much of the rack the cloth on it fills, the air between two patches
## on a shelf (in cells), and how small a patch on the rack is against the
## same patch on the quilt. One rack cell for every patch, so the rack reads
## as one basket of cloth and not as six scales.
const RACK_FILL := 0.86
const RACK_GAP := 0.6
const RACK_RATIO := 0.62

# --- the cloth, in cells ---
## The faint rules between the backing's cells. A patch's corner, its lip
## and its two ink mixes are `PatchCloth`'s, since the menu card wears them
## too, and the backing is drawn as one more patch of cloth so it wears the
## same corner and the same lip rather than a second pair of numbers.
const RULE_W := 0.022
const RULE_ALPHA := 0.55
## The running stitch: its width, and the dash and the gap along it.
const STITCH_W := 0.05
const STITCH_ON := 0.15
const STITCH_OFF := 0.1
## This board's own two numbers, and the only two it needs. The seam wave's
## step per cell of distance from the patch that landed, and how long one
## seam's dashes take to run. Nothing else in the game sews, so these would
## never be read by `core/motion.gd`.
const STITCH_STEP := 0.05
const STITCH_TIME := 0.22
## A dragged patch is held this far above the finger, in cells, so the thumb
## never covers the shape it is placing. Measured on the mock at the hard
## band's cell, which is the smallest.
const HOLD_LIFT := 1.2
## A refused or a lifted patch flying home to its bay.
const FLY_TIME := 0.26
## The ghost under the finger: the cells a drop would take, and the thread
## drawn round them so the footprint reads from under the patch that is
## hiding most of it.
const GHOST_ALPHA := 0.3
const GHOST_W := 0.035
const GHOST_DASH := 0.12
## The rose halo a refused patch wears instead of blushing (see `_blush`).
const HALO_W := 0.11
const HALO_ALPHA := 0.85
## The shape a patch leaves in its bay once it has gone onto the quilt.
const GONE_ALPHA := 0.16
## A patch a hint sewed keeps this glow round it until the board is reset.
const GIVEN_GLOW := 0.32
const GIVEN_W := 0.09
## The ring a hint pulses, in cells, off the patch's centroid.
const RING_R := 0.9
## Long enough for the solve's hem stitch to run all the way round before the
## win screen covers it.
const WIN_WAIT := 1.6
## Three, as every flat board gives.
const HINTS := 3

# --- the polish (spec amendment, 2026-09-26) ---
## The backing is a tufted quilt: every cell a soft puff of batting, inset
## this far, and a tie of thread where four puffs meet.
const PUFF_INSET := 0.07
const PUFF_R := 0.2
const PUFF_ALPHA := 0.26
const TIE_LEN := 0.055
const TIE_W := 0.028
## The rack stands on a felt mat with a stitched border.
const MAT_PAD := 14.0
const MAT_R := 26.0
const MAT := Color("e4e2c6")
const MAT_EDGE := Color("cfcaa6")
const MAT_STITCH := Color("f7f3e4")
## A patch that has left the rack leaves its outline in tailor's chalk.
const CHALK_W := 0.05
const CHALK_ON := 0.14
const CHALK_OFF := 0.1
## Taken hold of, a patch grows from the rack's cell to the quilt's over
## GROW_TIME and rises HOLD_LIFT above the thumb as it does, so it leaves the
## rack from exactly where it lay; it casts HELD_SHADOW (in cells) while it
## is up, and leans with the drag -- SWAY_GAIN radians per pixel a second,
## never past SWAY_MAX -- the way a piece of cloth held by one corner trails.
const GROW_TIME := 0.16
const HELD_SHADOW := Vector2(0.07, 0.24)
const SWAY_GAIN := 0.00005
const SWAY_MAX := 0.07
## Let go where it fits, a patch glides down onto its snapped cells over the
## first LAND_GLIDE of LAND_TIME and lands with a squash of LAND_SQUASH.
## Then a needle runs the quilting stitch round inside its edge over
## SEW_TIME, and the seams it now shares sew themselves after it.
const LAND_TIME := 0.32
const LAND_GLIDE := 0.34
const LAND_SQUASH := 0.06
const SEW_TIME := 0.5
## A patch flying home rises this far (in its starting cells) on the way.
const FLY_ARC := 0.4
## On the solve a light crosses the quilt, lifting each cloth this far toward
## the surface as it passes. A celebration and not a state: it is gone again
## before the win screen comes up.
const SHEEN := 0.36

const TIP_CYCLE := 8.0
const TIPS := [
	"QL_TIP_DRAG",
	"QL_TIP_EDGE",
	"QL_TIP_SHARE",
	"QL_TIP_ALL",
]

var _state = State.new()
## The board's own effects node: the hint's ring and every sparkle come
## through it and nowhere else.
var fx: Node2D

## The patch under the finger: {"patch": int, "grab": Vector2i (which of its
## own cells was taken hold of), "point": Vector2 (the finger, local),
## "from": int (the origin it was lifted off, or -1 from the rack),
## "since": float}. Empty when nothing is held.
var _drag: Dictionary = {}
## Patches on their way home to the rack: patch -> {"from", "to", "c0", "c1",
## "at"}. A refused drop and a lift are the same flight.
var _flying: Dictionary = {}
## When each patch last landed on the quilt, and when each last left it. The
## seam wave and the pops read these; they are the only clock this board
## keeps, and the seams themselves are derived from them every frame.
var _landed: Dictionary = {}
var _lifted: Dictionary = {}
## A refused drop: {"patch": int, "at": float}. The patch shivers on its way
## home and blushes while it goes.
var _refused: Dictionary = {}
## The rings and sparkles a wave still owes: [{"at", "point", "colour",
## "ring"}]. A solve's gold lands on each patch as the hop reaches it, not
## all at once when the last patch went on.
var _pending: Array = []

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
## The three meshes, dropped whenever something changed so the next _draw
## rebuilds them.
var _quilt: ArrayMesh
var _rack: ArrayMesh
var _hand: ArrayMesh
## The tufted backing, which never changes while the card keeps its size:
## built once and kept, rather than retraced on every frame of a drag.
var _ground: ArrayMesh
## Patches that landed out of the hand, with the corner the hand let them go
## at: they glide down from there rather than popping in.
var _glide: Dictionary = {}
## The meshes the last _draw actually handed to the canvas item. A canvas
## command holds a mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: Array = []
## Each patch's boundary loop and its bounding box, in its own cell units.
## Built once a board: a patch never changes shape and never turns.
var _loops: Array = []
var _spans: Array = []
## The backing's own loops and the faint rules inside it, likewise.
var _back_loops: Array = []
var _back_rules: Array = []
var _back_cells: Array = []
## Each patch's quilting line: its loop shrunk by Cloth.QUILT_INSET.
var _insets: Array = []

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "quilt"
func title() -> String: return "Quilt"

func rules() -> String:
	return tr("QL_RULES")

## Undo and Hint, and nothing else. There is no Check because nothing wrong
## can be sitting on the quilt to check: an illegal drop is never taken. So
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
	_drag = {}
	_flying = {}
	_landed = {}
	_lifted = {}
	_glide = {}
	_refused = {}
	_pending = []
	_anim_until = 0.0
	_solved_at = -1.0
	_shape_cache()
	_layout()
	_enter()
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## Every patch's silhouette and the backing's, traced once. A patch is a
## fixed set of cells that never turns, so its loop is worth keeping; the
## alternative is tracing eight boundaries on every frame of a drag.
func _shape_cache() -> void:
	_loops = []
	_spans = []
	_insets = []
	_ground = null
	for p in _state.shapes.size():
		var cells: Array = _state.shapes[p]
		_loops.append(Cloth.loops(cells))
		_insets.append(Cloth.inset_loops(cells))
		var span := Vector2i.ZERO
		for c: Vector2i in cells:
			span.x = maxi(span.x, c.x + 1)
			span.y = maxi(span.y, c.y + 1)
		_spans.append(span)
	var back: Array = []
	for r in _state.rows:
		for c in _state.cols:
			if _state.in_region(c, r):
				back.append(Vector2i(c, r))
	_back_loops = Cloth.loops(back)
	_back_cells = back
	# The rules between two backing cells, drawn once as a hint of the grid
	# the patches snap to. Only the inner edges: the outer ones are the hem.
	_back_rules = []
	for cell: Vector2i in back:
		if _state.in_region(cell.x + 1, cell.y):
			_back_rules.append([Vector2(cell.x + 1, cell.y), Vector2(cell.x + 1, cell.y + 1)])
		if _state.in_region(cell.x, cell.y + 1):
			_back_rules.append([Vector2(cell.x, cell.y + 1), Vector2(cell.x + 1, cell.y + 1)])

# --- layout ---

## The card's content box, inside the inset.
func _content() -> Rect2:
	return Rect2(Vector2.ONE * INSET, size - Vector2.ONE * (2.0 * INSET))

## The box the quilt is laid in: the top share of the content.
func _field_box() -> Rect2:
	var box := _content()
	return Rect2(box.position, Vector2(box.size.x, box.size.y * FIELD_SHARE))

## The box the rack stands in: everything under the field and the air.
func _rack_box() -> Rect2:
	var box := _content()
	var top := box.position.y + box.size.y * FIELD_SHARE + RACK_PAD
	return Rect2(Vector2(box.position.x, top), Vector2(box.size.x, box.position.y + box.size.y - top))

## The quilt's cell. The backing's bounding box is square-ish and its slot is
## wider than it is tall, so the **height binds at every band** -- 160, 133
## and 114 at 1080 wide, capped to 150 on the easy board, against Sudoku's
## 100 and Queens' 103. A quilt is dragged onto rather than tapped, so it
## wants the biggest cell on the shelf.
func _cell() -> float:
	if _state.cols <= 0 or _state.rows <= 0:
		return 0.0
	var box := _field_box()
	return maxf(0.0, minf(CELL_MAX, minf(box.size.x / float(_state.cols), box.size.y / float(_state.rows))))

## The backing's top-left, centred in its box both ways.
func _origin() -> Vector2:
	var box := _field_box()
	var span := Vector2(float(_state.cols), float(_state.rows)) * _cell()
	return box.position + (box.size - span) * 0.5

func _field_centre() -> Vector2:
	return _origin() + Vector2(float(_state.cols), float(_state.rows)) * _cell() * 0.5

## The top-left of the cell an origin index names.
func _corner_of(origin: int) -> Vector2:
	if _state.cols <= 0:
		return Vector2.ZERO
	var c: int = origin % _state.cols
	var r: int = origin / _state.cols
	return _origin() + Vector2(float(c), float(r)) * _cell()

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _origin() + Vector2(float(c) + 0.5, float(r) + 0.5) * _cell()

## The backing cell under a local point, or (-1, -1). A point off the
## backing's own shape still answers with its cell: a drag is judged by where
## the *patch* falls, and the state says whether that is on the quilt.
func _cell_at(local: Vector2) -> Vector2i:
	var cell := _cell()
	if cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _origin()) / cell
	return Vector2i(int(floor(p.x)), int(floor(p.y)))

## The rack is **two shelves, packed to the cloth**, not a grid of equal
## bays. A grid of bays has to size every bay for the tallest patch on the
## board, and one four-cell-tall patch then shrinks all eight: measured, a
## 456 rack over two 228 bays capped the rack cell at 46.7 on all three
## bands, against a field cell of 114 to 150. A shelf takes only the height
## its own patches need.
##
## So: the patches are sorted tallest first and cut in half, which puts the
## tall ones together on one shelf rather than one on each, and each shelf
## is given the share of the rack its own height asks for.
func _shelves() -> Array:
	var order: Array = []
	for p in _state.shapes.size():
		order.append(p)
	order.sort_custom(func(a: int, b: int) -> bool:
		var sa: Vector2i = _spans[a]
		var sb: Vector2i = _spans[b]
		if sa.y != sb.y:
			return sa.y > sb.y
		return sa.x > sb.x)
	var per := int(ceil(order.size() / 2.0))
	var out: Array = [order.slice(0, per)]
	if order.size() > per:
		out.append(order.slice(per))
	return out

## A shelf's width and height, in cells, with the air between its patches.
func _shelf_span(shelf: Array) -> Vector2:
	var w := 0.0
	var h := 1.0
	for p in shelf:
		w += float(_spans[p].x)
		h = maxf(h, float(_spans[p].y))
	return Vector2(w + RACK_GAP * float(maxi(shelf.size() - 1, 0)), h)

## One cell for every patch on the rack -- a rack of two sizes reads as two
## kinds of thing -- and the smallest of the three things that can bind it:
## a shelf's width, the two shelves' heights together, and the cap that
## keeps a waiting patch visibly smaller than a sewn one.
func _rack_cell() -> float:
	var box := _rack_box()
	var shelves := _shelves()
	var tall := 0.0
	var best := RACK_RATIO * _cell()
	for shelf: Array in shelves:
		var span := _shelf_span(shelf)
		tall += span.y
		best = minf(best, RACK_FILL * box.size.x / span.x)
	if tall > 0.0:
		best = minf(best, RACK_FILL * box.size.y / tall)
	return maxf(0.0, best)

## Where a patch waits: along its shelf in order, the shelf centred across
## the rack, and the patch centred in the band its shelf was given.
func _bay_home(p: int) -> Vector2:
	var box := _rack_box()
	var shelves := _shelves()
	var rc := _rack_cell()
	var tall := 0.0
	for shelf: Array in shelves:
		tall += _shelf_span(shelf).y
	var top := box.position.y
	for shelf: Array in shelves:
		var span := _shelf_span(shelf)
		var band := box.size.y * (span.y / maxf(tall, 1.0))
		if shelf.has(p):
			var x := box.position.x + (box.size.x - span.x * rc) * 0.5
			for q in shelf:
				if int(q) == p:
					break
				x += (float(_spans[q].x) + RACK_GAP) * rc
			return Vector2(x, top + (band - float(_spans[p].y) * rc) * 0.5)
		top += band
	return box.position

## The card this board wants: every pixel it is given. The field takes the
## share above and the rack the rest, so there is never any slack.
func card_height(available: float) -> float:
	return available

## False, and honestly so: card_height() hands back everything it is given,
## so the slack is zero and there is nothing to centre.
func card_centred() -> bool:
	return false

func _layout() -> void:
	_ground = null
	_refresh()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.shapes.is_empty():
		return
	var t := _now()
	_sway(delta)
	_retire(t)
	_fire_pending(t)
	if _animating(t):
		_refresh()

## The lean of the patch in the hand: toward the drag's own speed across,
## eased so a jerk of the finger swings it rather than snapping it, and back
## to upright when the finger rests. Nothing under reduce-motion.
func _sway(delta: float) -> void:
	if _drag.is_empty():
		return
	var point: Vector2 = _drag["point"]
	var last: Vector2 = _drag.get("last", point)
	_drag["last"] = point
	var want := 0.0
	if not Motion.reduce and delta > 0.0:
		want = clampf((point.x - last.x) / delta * SWAY_GAIN, -SWAY_MAX, SWAY_MAX)
	_drag["sway"] = lerpf(float(_drag.get("sway", 0.0)), want, 1.0 - exp(-delta * 10.0))

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

## A flight that has landed stops being a flight; otherwise `_animating`
## would have to keep asking about it for ever.
func _retire(t: float) -> void:
	if _flying.is_empty():
		return
	for p in _flying.keys():
		if t - float((_flying[p] as Dictionary)["at"]) >= FLY_TIME:
			_flying.erase(p)

## Whether anything on this card is still moving, asked wave by wave rather
## than by one deadline. **Every** wave has to be in here: One Line shipped
## two lines frozen at four fifths of a fade because one was left out, and it
## showed in a rendered frame and in no test.
func _animating(t: float) -> bool:
	if not _drag.is_empty() or not _flying.is_empty() or not _pending.is_empty():
		return true
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	# The entrance: the backing's wide pop, then the rack's patches popping in.
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(maxi(_state.shapes.size() - 1, 0), Motion.ENTER_STAGGER) + Motion.POP_IN
	if t - _opened < entrance:
		return true
	# Every patch's landing pop and the seam wave that ran out of it, and
	# every lift's pop-out.
	for p in _landed:
		if t - _sewn_at(int(p)) < maxf(maxf(Motion.POP_IN, SEW_TIME), _seam_span(int(p))):
			return true
	for p in _lifted:
		if t - float(_lifted[p]) < Motion.POP_OUT:
			return true
	if not _refused.is_empty() and t - float(_refused["at"]) < Motion.FLASH_IN + Motion.FLASH_OUT:
		return true
	if _solved_at >= 0.0 and t - _solved_at < Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME:
		return true
	return false

## How long the seam wave out of patch `p` runs: the far end of the longest
## seam it made, plus the run of that seam's own dashes.
func _seam_span(p: int) -> float:
	if Motion.reduce or p < 0 or p >= _state.shapes.size():
		return STITCH_TIME
	var span: Vector2i = _spans[p]
	var reach := float(span.x + span.y)
	return reach * STITCH_STEP + STITCH_TIME

## When patch `p`'s stitching starts: the moment it landed, or, for one that
## glided down out of the hand, the moment it touched the backing.
func _sewn_at(p: int) -> float:
	var at := float(_landed.get(p, -100.0))
	if _glide.has(p) and not Motion.reduce:
		at += LAND_TIME * LAND_GLIDE
	return at

## How long the solve wave takes to cross the quilt: the far corner's delay.
func _solve_span() -> float:
	return Motion.stagger(maxi(_state.cols + _state.rows - 2, 0), Motion.SOLVE_STAGGER)

## Keeps the card redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the three meshes so the next _draw rebuilds them, and asks for that
## draw. What the last _draw handed over is still held by _shown, so the
## renderer is never left pointing at a freed RID.
func _refresh() -> void:
	if _state.shapes.is_empty():
		_ground = null
	_quilt = null
	_rack = null
	_hand = null
	queue_redraw()

# --- where each patch is, this frame ---

## A patch's place on the card right now: the top-left of its bounding box,
## the cell it is drawn at, the squash and the lean on it, how solid it is,
## how far off the cloth it is held (its shadow) and the colour of its face.
## One function for the four states a patch can be in -- waiting, held,
## flying home and sewn on -- so no two of them can disagree about where it
## is.
func _frame_of(p: int, t: float) -> Dictionary:
	var sc := Vector2.ONE
	var alpha := 1.0
	var pos: Vector2
	var cell := _cell()
	var rot := 0.0
	var lift := 0.0
	var face: Color = Cloth.cloth(p)
	if not _drag.is_empty() and int(_drag["patch"]) == p:
		var g := _grow(t)
		cell = lerpf(float(_drag["c0"]), _cell(), g)
		pos = _held_corner_at(cell, g)
		sc = Vector2.ONE * lerpf(1.0, Motion.LIFT_SCALE, g)
		rot = float(_drag.get("sway", 0.0))
		lift = g
	elif _flying.has(p):
		var f: Dictionary = _flying[p]
		var u := clampf((t - float(f["at"])) / FLY_TIME, 0.0, 1.0)
		var e := Motion.back_out(u)
		pos = (f["from"] as Vector2).lerp(f["to"] as Vector2, e)
		cell = lerpf(float(f["c0"]), float(f["c1"]), e)
		if not Motion.reduce:
			pos.y -= sin(u * PI) * FLY_ARC * float(f["c0"])
			lift = sin(u * PI)
		if _refused.has("patch") and int(_refused["patch"]) == p:
			pos.x += Motion.shiver_offset(t - float(_refused["at"]))
	elif int(_state.at[p]) >= 0:
		pos = _corner_of(int(_state.at[p]))
		var since := t - float(_landed.get(p, -100.0))
		if _glide.has(p):
			var land := _land(p, pos, since)
			pos = land["pos"]
			sc = land["sc"]
			lift = float(land["lift"])
		else:
			sc = Motion.pop_in_scale(since)
		# A given refusing to be picked up shivers where it lies; it has no
		# flight to shiver along.
		if not _refused.is_empty() and int(_refused["patch"]) == p:
			pos.x += Motion.shiver_offset(t - float(_refused["at"]))
		if _solved_at >= 0.0:
			pos.y += _solve_hop(p, t)
			face = face.lerp(Pal.SURFACE, SHEEN * _sheen(p, t))
	else:
		pos = _bay_home(p)
		cell = _rack_cell()
		var since := t - _opened - Motion.ENTER_DELAY - Motion.stagger(p, Motion.ENTER_STAGGER)
		sc = Motion.pop_in_scale(since)
		alpha = Motion.appear_level(since, Motion.ENTER_POP)
	return {"pos": pos, "cell": cell, "sc": sc, "alpha": alpha, "rot": rot,
		"lift": lift, "face": face}

## How far the patch in the hand has grown from the cell it was picked up at
## to the quilt's, 0 to 1, with the back ease so it overshoots a touch.
func _grow(t: float) -> float:
	if Motion.reduce:
		return 1.0
	return Motion.back_out(clampf((t - float(_drag["since"])) / GROW_TIME, 0.0, 1.0))

## The patch in the hand drawn at `cell` and `g` of the way up: the cell it
## was taken hold of stays under the finger, and it rises HOLD_LIFT above
## the thumb as it grows. At g = 1 this is `_held_corner()` exactly.
func _held_corner_at(cell: float, g: float) -> Vector2:
	var grab: Vector2i = _drag["grab"]
	var point: Vector2 = _drag["point"]
	return point - Vector2(float(grab.x) + 0.5, float(grab.y) + 0.5 + HOLD_LIFT * g) * cell

## A patch let go where it fits: it glides from where the hand held it onto
## its snapped cells, shrinking from the hand's lift as its shadow closes
## under it, then lands -- wide and low, and back, once. {"pos", "sc",
## "lift"}.
func _land(p: int, corner: Vector2, since: float) -> Dictionary:
	if Motion.reduce or since >= LAND_TIME:
		return {"pos": corner, "sc": Vector2.ONE, "lift": 0.0}
	var u := clampf(since / LAND_TIME, 0.0, 1.0)
	if u < LAND_GLIDE:
		var g := u / LAND_GLIDE
		var e := g * g * (3.0 - 2.0 * g)
		return {"pos": (_glide[p] as Vector2).lerp(corner, e),
			"sc": Vector2.ONE * lerpf(Motion.LIFT_SCALE, 1.0, e), "lift": 1.0 - e}
	var v := (u - LAND_GLIDE) / (1.0 - LAND_GLIDE)
	var a := LAND_SQUASH * sin(v * TAU) * (1.0 - v)
	return {"pos": corner, "sc": Vector2(1.0 + a, 1.0 - a), "lift": 0.0}

## The solve's light on patch `p`: 0 to 1 and back as the diagonal front
## crosses its middle.
func _sheen(p: int, t: float) -> float:
	var mid := _centroid(p)
	return Motion.flash_level(t - _solved_at - Motion.SOLVE_DELAY
		- Motion.stagger(int(mid.x + mid.y), Motion.SOLVE_STAGGER), Motion.FLASH_IN, Motion.SOLVE_TIME)

## The top-left of the patch in the hand: the cell under the finger, less the
## cell of the patch that was taken hold of, and lifted HOLD_LIFT above the
## thumb so the shape being placed is never under it.
func _held_corner() -> Vector2:
	var cell := _cell()
	var grab: Vector2i = _drag["grab"]
	var point: Vector2 = _drag["point"]
	return point - Vector2(float(grab.x) + 0.5, float(grab.y) + 0.5 + HOLD_LIFT) * cell

## The cell the held patch's own (0, 0) is over, snapped: what a release
## would try to place it at.
func _held_cell() -> Vector2i:
	var cell := _cell()
	if cell <= 0.0:
		return Vector2i(-1000, -1000)
	var p := (_held_corner() - _origin()) / cell
	return Vector2i(int(round(p.x)), int(round(p.y)))

## The origin index a release would ask for, or -1 when the patch's own
## (0, 0) is not over the grid at all.
##
## **The bounds have to be exactly the grid**, because the origin is packed
## into one int as `row * cols + column` and an out-of-range column wraps
## onto another row: held one cell off the left edge at row 2 of a 5-wide
## quilt, `-1` encodes as origin 9, which decodes as column 4 of row 1 --
## the far side of the board. Measured before it was fixed: of the holds a
## looser guard admitted, **2,386 came back `fits() == OK`** across 120
## boards, so a patch dragged off one edge could be sewn on at the other.
##
## Nothing is lost by the tight test. A shape is normalised, so some cell of
## it has an x-offset of 0 and some cell has a y-offset of 0; for every cell
## to land on the grid, the origin itself must therefore be on it.
func _held_origin() -> int:
	var at := _held_cell()
	if at.x < 0 or at.y < 0 or at.x >= _state.cols or at.y >= _state.rows:
		return -1
	return at.y * _state.cols + at.x

## The solve wave's hop for a patch, off its top-left cell's diagonal.
func _solve_hop(p: int, t: float) -> float:
	var origin := int(_state.at[p])
	if origin < 0:
		return 0.0
	var c: int = origin % _state.cols
	var r: int = origin / _state.cols
	var since := t - _solved_at - Motion.SOLVE_DELAY - Motion.stagger(c + r, Motion.SOLVE_STAGGER)
	return Motion.hop_lift(since, Motion.SOLVE_HOP, Motion.SOLVE_TIME)

# --- the seams, derived every frame ---

## Every seam on the quilt as it stands: an edge between two patches, or one
## between a patch and the world off the quilt -- the hem. **Nothing here is
## stored.** A seam exists because two patches are where they are, so lifting
## either takes it away and undo keeps no book for it; that is Queens' and
## Sudoku's `_settle` in a third shape.
##
## Each seam carries the moment it came into being (the later of its two
## patches' landings) and the colour of the patch that made it, so the wave
## runs out of the patch that was just sewn on and not out of its neighbour.
func _seams() -> Array:
	var out: Array = []
	var cell := _cell()
	var o := _origin()
	for r in _state.rows:
		for c in _state.cols:
			var p := _state.patch_at_cell(c, r)
			if p < 0:
				continue
			var here := Vector2(float(c), float(r))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q := _state.patch_at_cell(c + d.x, r + d.y)
				var off := not _state.in_region(c + d.x, r + d.y)
				if not off and q == p:
					continue
				if not off and q < 0:
					continue      # a raw edge: there is nothing yet to sew to
				if not off and (d.x < 0 or d.y < 0):
					continue      # the neighbour's own pass draws this seam
				var a: Vector2
				var b: Vector2
				if d == Vector2i(1, 0):
					a = here + Vector2(1.0, 0.0); b = here + Vector2(1.0, 1.0)
				elif d == Vector2i(0, 1):
					a = here + Vector2(0.0, 1.0); b = here + Vector2(1.0, 1.0)
				elif d == Vector2i(-1, 0):
					a = here; b = here + Vector2(0.0, 1.0)
				else:
					a = here; b = here + Vector2(1.0, 0.0)
				var owner := p
				var when := _sewn_at(p)
				if q >= 0 and _sewn_at(q) > when:
					owner = q
					when = _sewn_at(q)
				out.append({
					"a": o + a * cell, "b": o + b * cell,
					"owner": owner, "at": when,
					"reach": (a + b) * 0.5 - _centroid(owner),
					"hem": off,
				})
	return out

## A patch's middle, in cells of the quilt: where its seam wave starts.
func _centroid(p: int) -> Vector2:
	var origin := int(_state.at[p])
	if origin < 0:
		return Vector2.ZERO
	var at := Vector2(float(origin % _state.cols), float(origin / _state.cols))
	var sum := Vector2.ZERO
	var cells: Array = _state.shapes[p]
	for c: Vector2i in cells:
		sum += at + Vector2(c) + Vector2(0.5, 0.5)
	return sum / float(maxi(cells.size(), 1))

# --- the drawing ---

## The backing under everything, which pops in wide about its centre while it
## fades (rule 7: a wide thing comes from most of the way); the patches sewn
## on it; the seams over them; then the rack, and last of all the patch in
## the hand, which has to draw over the lot.
func _draw() -> void:
	if _state.shapes.is_empty() or _cell() <= 0.0:
		return
	var t := _now()
	var shown: Array = []
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	var grow := Motion.wide_pop_scale(since)
	if _rack == null:
		_rack = _build_rack(t)
	if seen > 0.0:
		var mid := _field_centre()
		var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
		if _ground == null:
			_ground = _build_ground()
		if _ground != null:
			draw_mesh(_ground, null, xf, Color(1.0, 1.0, 1.0, seen))
			shown.append(_ground)
		if _quilt == null:
			_quilt = _build_quilt(t)
		if _quilt != null:
			draw_mesh(_quilt, null, xf, Color(1.0, 1.0, 1.0, seen))
			shown.append(_quilt)
	if _rack == null:
		_rack = _build_rack(t)
	if _rack != null:
		draw_mesh(_rack, null)
		shown.append(_rack)
	if _hand == null:
		_hand = _build_hand(t)
	if _hand != null:
		draw_mesh(_hand, null)
		shown.append(_hand)
	_shown = shown

## The quilt: the backing and its rules, the ghost of a drop under the
## finger, every patch sewn on, the glow round a patch a hint sewed, and the
## seams over the lot. The order is the only one that works -- a seam drawn
## under a patch is a seam nobody sees.
func _build_quilt(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_ghost(b, t)
	# Landed patches first and the one still gliding down last, so a patch
	# on its way onto the quilt passes over its neighbours and not under.
	var order: Array = []
	for p in _state.shapes.size():
		if int(_state.at[p]) < 0 or (not _drag.is_empty() and int(_drag["patch"]) == p):
			continue
		order.append(p)
	order.sort_custom(func(a: int, z: int) -> bool:
		return float(_landed.get(a, -100.0)) < float(_landed.get(z, -100.0)))
	for p: int in order:
		var f := _frame_of(p, t)
		_patch(b, p, f, true)
		if int(_state.locked[p]) == 1:
			_hint_glow(b, p, f)
	_stitches(b, t)
	return _mesh(b)

## The backing, built once a layout: a pale piece of cloth with the
## patches' own silhouette and lip, the faint rules of the grid the patches
## snap to, a puff of batting in every cell and a tie of thread wherever four
## puffs meet. A tufted quilt top, before anything is sewn onto it.
func _build_ground() -> ArrayMesh:
	var b := Face.Builder.new()
	var cell := _cell()
	var o := _origin()
	Cloth.patch(b, _back_loops, o, cell, Vector2i.ZERO, Pal.QUILT_BACK, Pal.LINE)
	var rule := Color(Pal.QUILT_RULE, RULE_ALPHA)
	for pair: Array in _back_rules:
		b.stroke(PackedVector2Array([o + (pair[0] as Vector2) * cell,
			o + (pair[1] as Vector2) * cell]), RULE_W * cell, rule, false, false)
	var puff := Color(Pal.SURFACE, PUFF_ALPHA)
	for c: Vector2i in _back_cells:
		b.polygon(Face.Builder.round_rect(o + (Vector2(c) + Vector2.ONE * PUFF_INSET) * cell,
			Vector2.ONE * (1.0 - 2.0 * PUFF_INSET) * cell, PUFF_R * cell), puff)
	var tie := Color(Pal.LINE, 0.85)
	for c: Vector2i in _back_cells:
		# The tie at this cell's top-left corner, where it meets three others.
		if not (_state.in_region(c.x - 1, c.y) and _state.in_region(c.x, c.y - 1)
				and _state.in_region(c.x - 1, c.y - 1)):
			continue
		var at := o + Vector2(c) * cell
		var d := TIE_LEN * cell
		b.stroke(PackedVector2Array([at + Vector2(-d, -d), at + Vector2(d, d)]), TIE_W * cell, tie)
		b.stroke(PackedVector2Array([at + Vector2(d, -d), at + Vector2(-d, d)]), TIE_W * cell, tie)
	return _mesh(b)

## The rack: every patch still waiting, any flying home to it, and the faint
## shape of every one that has gone.
##
## **The empty bays are drawn, and they have to be.** Without them the rack
## empties as the quilt fills and the bottom four hundred pixels of the card
## go blank -- the last patch is dragged across a void. The cut shape left
## behind keeps the rack's composition, says which patch came from where,
## and is honest about the one thing the player can still do with it: drag
## it back. It is the patch's own silhouette at GONE_ALPHA, with no lip,
## because a lip is what says a thing is sitting on top of something.
func _build_rack(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var cell := _rack_cell()
	_mat(b)
	var chalk := Color(MAT_STITCH, 0.95)
	for p in _state.shapes.size():
		var held: bool = not _drag.is_empty() and int(_drag["patch"]) == p
		if held or (int(_state.at[p]) >= 0 and not _flying.has(p)):
			for loop: PackedVector2Array in _loops[p]:
				var pts := Cloth.laid(loop, _bay_home(p), cell, _spans[p])
				b.polygon(pts, Color(Cloth.cloth(p), GONE_ALPHA))
				Cloth.dash_loop(b, pts, CHALK_W * cell, CHALK_ON * cell, CHALK_OFF * cell, chalk)
			continue
		if not _flying.has(p):
			_patch(b, p, _frame_of(p, t))
	# The flights last, so a patch on its way home passes over the ones
	# still waiting rather than under them.
	for p in _flying:
		_patch(b, int(p), _frame_of(int(p), t))
	return _mesh(b)

## The felt mat the rack's patches wait on: a soft sage felt with a lip and
## a stitched border, so the rack reads as a place the cloth is kept and not
## as patches floating on the card.
func _mat(b) -> void:
	var box := _rack_box().grow(MAT_PAD)
	box.size.y = minf(box.size.y, size.y - INSET * 0.5 - box.position.y)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var pts := Face.Builder.round_rect(box.position, box.size, MAT_R)
	b.polygon(Cloth._moved(pts, Vector2(0.0, 5.0)), MAT_EDGE)
	b.polygon(pts, MAT)
	var inner := box.grow(-12.0)
	Cloth.dash_loop(b, Face.Builder.round_rect(inner.position, inner.size, MAT_R - 10.0),
		3.5, 12.0, 8.0, MAT_STITCH)

## The patch in the hand, alone, so it draws over the quilt and the rack
## alike. Refused, it is drawn in the family's rose instead of its cloth.
func _build_hand(t: float) -> ArrayMesh:
	if _drag.is_empty():
		return null
	var b := Face.Builder.new()
	_patch(b, int(_drag["patch"]), _frame_of(int(_drag["patch"]), t))
	return _mesh(b)

## A builder's mesh, or null when it has nothing in it. Asking an empty
## builder for a mesh is an engine error ("array_len == 0"), and each of
## these three is empty at some point: the rack while the entrance is still
## scaling its patches up from nothing, the quilt before a patch is on it,
## and the hand between drags.
func _mesh(b) -> ArrayMesh:
	return b.mesh() if not b.verts.is_empty() else null

## One patch, in its cloth -- or in the family's rose while it is being
## refused, which is the one thing that can change a patch's colour.
##
## Every patch wears its print; a patch sewn on the quilt (`sewn`) also wears
## the quilting stitch just inside its edge, which is what tells a patch that
## is sewn from one only lying there -- and a lifted one casts its shadow.
func _patch(b, p: int, f: Dictionary, sewn := false) -> void:
	var cell := float(f["cell"])
	var lift := float(f.get("lift", 0.0))
	Cloth.shadow(b, _loops[p], f["pos"], cell, _spans[p], HELD_SHADOW * cell * lift,
		minf(lift * 1.5, 1.0) * float(f["alpha"]), f["sc"], float(f.get("rot", 0.0)))
	Cloth.patch(b, _loops[p], f["pos"], cell, _spans[p],
		f.get("face", Cloth.cloth(p)), Cloth.cloth_deep(p), f["sc"], float(f["alpha"]),
		float(f.get("rot", 0.0)))
	Cloth.print_cloth(b, _state.shapes[p], p, f["pos"], cell, _spans[p],
		f["sc"], float(f["alpha"]), float(f.get("rot", 0.0)))
	if sewn:
		_quilting(b, p, f)
	_blush(b, p, f)

## The quilting stitch round inside a sewn patch's edge, run by a needle over
## SEW_TIME from the moment the patch touched the backing. It is there the
## moment the patch is under reduce-motion.
func _quilting(b, p: int, f: Dictionary) -> void:
	var t := _now()
	var u := 1.0 if Motion.reduce else clampf((t - _sewn_at(p)) / SEW_TIME, 0.0, 1.0)
	if u <= 0.0:
		return
	var cell := float(f["cell"])
	var ink := Cloth.cloth_thread(p)
	if _solved_at >= 0.0:
		ink = ink.lerp(Pal.SUN_RAY, _sheen(p, t))
	for loop: PackedVector2Array in _insets[p]:
		var pts := Cloth.laid(loop, f["pos"], cell, _spans[p], f["sc"],
			float(f.get("rot", 0.0)), Cloth.RADIUS * 0.6)
		var total := Cloth.perimeter(pts)
		Cloth.dash_loop(b, pts, Cloth.QUILT_W * cell, Cloth.QUILT_ON * cell,
			Cloth.QUILT_OFF * cell, ink, total * u)
		if u < 1.0:
			var head: Array = Cloth.along(pts, total * u)
			Cloth.needle(b, head[0], head[1], cell, ink)

## A patch that is being turned down wears a rose **halo** round its
## silhouette. It does not blush.
##
## **The cloth cannot blush**, and this is measured rather than felt. The
## eight cloths run right round the wheel, so there is no one rose they can
## all be taken toward: at 0.30 the teal drops from 0.34 saturation to
## **0.07** and comes back dead grey, the sage swings from hue 91 to 49 and
## comes back khaki, and the sky goes to 265 and comes back mauve. Only the
## four warm cloths blush at all. A wash that means "wrong" on half a rack
## and "muddy" on the other half is worse than no wash.
##
## That is `docs/art/flat-motion.md`'s **rule 9** -- a piece with no
## blushing variant blushes through its cell -- read for a piece that *is*
## its own shape and covers several cells: the halo is drawn beside the
## cloth rather than mixed into it, so it reads the same on all eight. The
## piece still moves; the halo carries the colour.
func _blush(b, p: int, f: Dictionary) -> void:
	var level := 0.0
	if not _refused.is_empty() and int(_refused["patch"]) == p:
		level = Motion.flash_level(_now() - float(_refused["at"]))
	elif not _drag.is_empty() and int(_drag["patch"]) == p and _hold_state() == SNAG:
		# Held over the quilt somewhere it will not go. The hand says so
		# while it is held, rather than the board waiting for the release --
		# a drag is a question, and this is the only moment the board can
		# answer it before the answer costs anything.
		level = 1.0
	if level <= 0.0:
		return
	var cell := float(f["cell"])
	for loop: PackedVector2Array in _loops[p]:
		b.stroke(Cloth.laid(loop, f["pos"], cell, _spans[p], f["sc"], float(f.get("rot", 0.0))),
			HALO_W * cell, Color(Pal.BAD, HALO_ALPHA * level), true)

## The glow a hint's patch keeps: a soft sun ring round its silhouette, so a
## patch that was given is never mistaken for one that was worked out.
func _hint_glow(b, p: int, f: Dictionary) -> void:
	var cell := float(f["cell"])
	for loop: PackedVector2Array in _loops[p]:
		b.stroke(Cloth.laid(loop, f["pos"], cell, _spans[p], f["sc"]),
			GIVEN_W * cell, Color(Pal.SUN, GIVEN_GLOW), true)

## What the hand is over: CLEAR when no cell of the held patch is on the
## quilt at all, FITS when a release would sew it on, and SNAG when it is
## over the quilt and will not go.
##
## The three are not the same as `fits()`'s two, and the difference is the
## whole of the drag's feedback: a patch on its way up from the rack spends
## most of the journey not fitting anywhere, and blushing all the way would
## be a board shouting at a player who has not done anything yet.
const CLEAR := 0
const FITS := 1
const SNAG := 2

func _hold_state() -> int:
	if _drag.is_empty():
		return CLEAR
	var p := int(_drag["patch"])
	var origin := _held_origin()
	if origin < 0:
		return CLEAR
	var over := 0
	for c: Vector2i in (_state.patch_cells(p, origin) as Array):
		if _state.in_region(c.x, c.y):
			over += 1
	if over == 0:
		return CLEAR
	return FITS if _state.fits(p, origin) == State.OK else SNAG

## Where the patch in the hand would land, on whole cells while the patch
## above it follows the finger: a wash in its own cloth with a thread drawn
## round it when it fits, and a **dashed rose thread alone** when it will
## not go.
##
## **The outline is not decoration.** The patch is held above the thumb and
## the footprint snaps underneath it, so the patch covers most of the wash
## and only its edges peek out; a wash on its own is a hint of a hint. The
## thread is what makes the footprint readable. And the refusing case gets
## no wash at all, because a patch that will not go is partly *off* the
## backing by definition and a rose wash would be painted onto the card.
func _ghost(b, _t: float) -> void:
	var state := _hold_state()
	if state == CLEAR:
		return
	var p := int(_drag["patch"])
	var cells: Array = _state.patch_cells(p, _held_origin())
	if cells.is_empty():
		return
	var cell := _cell()
	for loop: PackedVector2Array in Cloth.loops(cells):
		var pts := Cloth.laid(loop, _origin(), cell, Vector2i.ZERO)
		if state == FITS:
			b.polygon(pts, Color(Cloth.cloth(p), GHOST_ALPHA))
			b.stroke(pts, GHOST_W * cell, Cloth.cloth_stitch(p), true)
		else:
			Cloth.dash_loop(b, pts, GHOST_W * cell,
				GHOST_DASH * cell, GHOST_DASH * cell, Pal.BAD)

## The running stitch along every seam: the board's signature. Each seam's
## dashes run out from the patch that made it, one cell of distance per
## STITCH_STEP, and take STITCH_TIME to cross their own edge. A seam whose
## moment has not come is not drawn at all, so the wave is the drawing and
## not a fade over it.
func _stitches(b, t: float) -> void:
	var cell := _cell()
	for s: Dictionary in _seams():
		var owner := int(s["owner"])
		var wait := (s["reach"] as Vector2).length() * _stitch_step()
		var u := clampf((t - float(s["at"]) - wait) / _stitch_time(), 0.0, 1.0)
		if u <= 0.0:
			continue
		var ink := Cloth.cloth_stitch(owner)
		if bool(s["hem"]) and _solved_at >= 0.0:
			# On the solve the hem warms all the way round, which is the one
			# moment the quilt is spoken of as a whole thing.
			var mid: Vector2 = ((s["a"] as Vector2) + (s["b"] as Vector2)) * 0.5
			var at := (mid - _origin()) / cell
			var lit := Motion.flash_level(t - _solved_at - Motion.SOLVE_DELAY
				- Motion.stagger(int(at.x + at.y), Motion.SOLVE_STAGGER), Motion.FLASH_IN, Motion.SOLVE_TIME)
			ink = ink.lerp(Pal.SUN_RAY, lit)
		Cloth.stitch(b, s["a"] as Vector2, s["b"] as Vector2, STITCH_W * cell,
			STITCH_ON * cell, STITCH_OFF * cell, ink, u)

## Nothing under reduce-motion: a seam is simply there the moment its two
## patches are.
func _stitch_step() -> float:
	return 0.0 if Motion.reduce else STITCH_STEP

func _stitch_time() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else STITCH_TIME

# --- the moments ---

## The chrome is the host's. The backing's entrance is one wide pop about its
## centre while it fades in (rule 7), and the rack's patches pop in behind
## it; both are read off the clock in _draw, so all this has to do is start
## it. _animating() knows how long it runs.
func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	_refresh()

# --- input ---

## A press, a drag and a release. A press finds the patch under the finger --
## one sewn on the quilt first, then one waiting on the rack -- and takes
## hold of it by the cell it was pressed on, so a patch dragged by its corner
## stays held by that corner.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_grab(event.position)
		elif not _drag.is_empty():
			_release()
			accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _drag.is_empty():
		_drag["point"] = event.position
		_refresh()
		accept_event()

func _grab(local: Vector2) -> void:
	# One hand at a time. A second press while a patch is held -- a second
	# finger on a phone, a second mouse button here -- used to overwrite
	# `_drag` outright, and the patch it dropped had already been taken off
	# the quilt by `take()`, which pushes no history because the matching
	# `drop()` is meant to. So the first patch was stranded in the rack with
	# no undo entry and no move counted, and only the second one was ever
	# resolved.
	if not _drag.is_empty():
		return
	var hit := _hit(local)
	if hit.is_empty():
		return
	var p := int(hit["patch"])
	if int(_state.at[p]) >= 0 and int(_state.locked[p]) == 1:
		# A hint's patch is a given: it is not the player's to move.
		_refused = {"patch": p, "at": _now()}
		_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)
		_say(tr("QL_HINTED_FAST"), Face.Expr.WORRIED)
		_refresh()
		return
	var from := int(_state.at[p])
	# The cell it is picked up at: the quilt's, or the rack's smaller one, so
	# it grows from exactly the size it was lying at.
	var c0 := _cell() if from >= 0 else _rack_cell()
	_glide.erase(p)
	if from >= 0:
		# Taken off the quilt with no history of its own: one gesture is one
		# undo, so the entry is pushed when the hand lets go and knows where
		# the patch ended up -- back on the quilt, or home to the rack.
		_state.take(p)
		_lifted[p] = _now()
		_landed.erase(p)
	_drag = {"patch": p, "grab": hit["cell"], "point": local, "from": from, "since": _now(),
		"c0": c0}
	_refused = {}
	_flying.erase(p)
	fx.cue("lift")
	_refresh()
	accept_event()

## What is under a local point: a patch sewn on the quilt, else one waiting
## on the rack. Returns {"patch": int, "cell": Vector2i (which of the
## patch's own cells)}.
func _hit(local: Vector2) -> Dictionary:
	var at := _cell_at(local)
	var p := _state.patch_at_cell(at.x, at.y)
	if p >= 0:
		var origin := int(_state.at[p])
		var corner := Vector2i(origin % _state.cols, origin / _state.cols)
		return {"patch": p, "cell": at - corner}
	var rc := _rack_cell()
	if rc <= 0.0:
		return {}
	for i in _state.shapes.size():
		if int(_state.at[i]) >= 0:
			continue
		var home := _bay_home(i)
		var rel := (local - home) / rc
		var cell := Vector2i(int(floor(rel.x)), int(floor(rel.y)))
		if (_state.shapes[i] as Array).has(cell):
			return {"patch": i, "cell": cell}
	return {}

## Let go. Three endings, and telling them apart is the whole of whether
## this board feels fair:
##
## - **Sewn on.** The drop fits. Dropped back exactly where it was lifted
##   from, nothing happened, so nothing is said and nothing is counted.
## - **Taken off.** The patch was let go **clear of the quilt** -- no cell
##   of it over the backing at all. That is not a refusal, it is *the*
##   gesture for taking a patch off, and the board must not scold a player
##   for doing the thing it told them to do. It goes home quietly, with the
##   count and no blush. A patch that came from the rack and went back to
##   the rack is the same ending with nothing to count.
## - **Refused.** The patch was let go **over the quilt** somewhere it will
##   not go. Only this one blushes, and the sprout names the rule.
func _release() -> void:
	var p := int(_drag["patch"])
	var from := int(_drag["from"])
	var origin := _held_origin()
	# Both read before _drag is cleared: the hand's place, because a patch
	# that goes home flies from under the finger and not from wherever it
	# came, and whether it was over the quilt at all.
	var hand := _held_corner()
	var clear := _hold_state() == CLEAR
	var code := State.OFF if origin < 0 else _state.fits(p, origin)
	_drag = {}
	if code == State.OK:
		_state.drop(p, origin, from)
		_landed[p] = _now()
		_glide[p] = hand
		_lifted.erase(p)
		_busy_for(LAND_TIME + maxf(SEW_TIME, _seam_span(p)))
		fx.cue("place")
		if from == origin:
			# Back where it came from. Nothing happened, so nothing is said
			# and nothing is counted.
			_refresh()
			return
		_speak()
		_refresh()
		# note_move() counts the move and ends the puzzle if that was the
		# last patch; the host raises the win screen after win_delay().
		note_move()
		return
	_state.drop(p, -1, from)
	_fly_home(p, hand)
	if clear:
		# Taken off, not turned down.
		_busy_for(FLY_TIME)
		fx.cue("undo" if from >= 0 else "lift")
		_speak()
	else:
		_refused = {"patch": p, "at": _now()}
		_busy_for(maxf(FLY_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
		fx.cue("refused")
		_say(_reason(code), Face.Expr.WORRIED)
	_refresh()
	if from >= 0:
		# It was on the quilt and is not any more, which is a move whichever
		# way the drop was judged.
		note_move()

## The sprout's line for a refusal. A refusal is never a silence -- and it
## is only ever said about a patch let go *over* the quilt, since a patch
## let go clear of it was taken off rather than turned down.
func _reason(code: int) -> String:
	match code:
		State.OVER:
			return tr("QL_REFUSE_OVER")
		_:
			return tr("QL_REFUSE_OFF")

## Sends a patch home to its bay from the point `at`, which is where the
## hand let go of it, or where it was sitting on the quilt. `after` delays
## the start, which is what lets Reset send them home in a wave rather than
## all at once; `_frame_of` holds a flight at its start until its moment.
func _fly_home(p: int, at: Vector2, after := 0.0) -> void:
	_flying[p] = {
		"from": at, "to": _bay_home(p),
		"c0": _cell(), "c1": _rack_cell(), "at": _now() + after,
	}
	_lifted[p] = _now()
	_landed.erase(p)
	_glide.erase(p)

# --- the sprout's line ---

func _left_line() -> String:
	var left := 0
	for p in _state.shapes.size():
		if int(_state.at[p]) < 0:
			left += 1
	if left <= 0:
		return tr("QL_WIN")
	return tr("QL_ONE_LEFT") if left == 1 else tr("QL_N_LEFT") % left

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
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules: this
## board answers a drop with a count, and a refusal with the rule.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

## Where every patch stands right now, as plain ints: the before half of
## `_settle`.
func _snapshot() -> Array:
	var out: Array = []
	for i in _state.shapes.size():
		out.append(int(_state.at[i]))
	return out

## One diff of where every patch was against where it is now, turned into
## the moments the drawing reads: a patch that arrived pops in and starts
## its seam wave, a patch that left flies home from exactly where it stood.
##
## **Every move that can shift more than one patch goes through here** -- a
## hint that displaces two, an undo that puts them back -- so no move can
## forget to animate a patch it moved, and none of them has to know which
## patches those were. Queens' and Sudoku's `_settle` diff derived state;
## this one diffs the pieces themselves, which is the plainest form of it.
func _settle(before: Array, t: float) -> void:
	for i in _state.shapes.size():
		var was := int(before[i])
		var now := int(_state.at[i])
		if was == now:
			continue
		if now >= 0:
			_landed[i] = t
			_glide.erase(i)
			_lifted.erase(i)
			_flying.erase(i)
		elif was >= 0:
			_fly_home(i, _corner_of(was))

func can_undo() -> bool:
	return not _state.history.is_empty()

## Reverses the last gesture -- a patch sewn on, a patch taken off, or a
## hint with everything it displaced. Counts no move.
func undo() -> bool:
	if is_done():
		return false
	var before := _snapshot()
	var back: Dictionary = _state.undo()
	if back.is_empty():
		return false
	var t := _now()
	_drag = {}
	_refused = {}
	_settle(before, t)
	_busy_for(maxf(Motion.POP_IN, FLY_TIME))
	_say(tr("QL_TAKEN_BACK") + " " + _left_line(), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Sews one patch of the answer where the board has not got it, taking up
## anything in its way first. The patch it sews is a given from then on: it
## keeps its sun glow and it will not be dragged off.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var before := _snapshot()
	var out: Dictionary = _state.hint()
	if out.is_empty():
		return false
	hints_used += 1
	var p := int(out["patch"])
	var t := _now()
	# The hint's own patch and everything it took up on the way, off one
	# diff: the state says which patches it displaced, but the board never
	# has to read that list to draw them leaving.
	_settle(before, t)
	_fx_at(_origin() + _centroid(p) * _cell(), Pal.LEAF)
	_busy_for(maxf(Motion.RING_TIME, Motion.POP_IN + _seam_span(p)))
	fx.cue("hint")
	_say(tr("QL_HINT") + " " + _left_line(), Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	# A hint can finish the quilt, and a board that ends on one still ends.
	check_solved()
	return true

## Every patch the player laid comes home in a wave from the far corner.
## What a hint gave stays given: it keeps its place, and the hints spent are
## not refunded.
func reset_board() -> void:
	# Where each of them is, and how far it stands from the far corner, both
	# read before the state clears them.
	var was: Dictionary = {}
	for p in _state.shapes.size():
		var origin := int(_state.at[p])
		if origin < 0 or int(_state.locked[p]) == 1:
			continue
		var c: int = origin % _state.cols
		var r: int = origin / _state.cols
		was[p] = {"at": _corner_of(origin),
			"step": (_state.cols - 1 - c) + (_state.rows - 1 - r)}
	_drag = {}
	_flying = {}
	_refused = {}
	_pending = []
	_state.reset()
	for p in was:
		var e: Dictionary = was[p]
		_fly_home(int(p), e["at"], Motion.stagger(int(e["step"]), Motion.RESET_STAGGER))
	_solved_at = -1.0
	_busy_for(Motion.stagger(_state.cols + _state.rows - 2, Motion.RESET_STAGGER) + FLY_TIME)
	moves = 0
	_running = true
	_say(tr("QL_CLEAN") + " " + _left_line(), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

## A completed daily is dealt again from its seed, so the fresh board comes up
## with an empty quilt mid-entrance. Sew every patch on at its answer origin
## with every clock in the past: the entrance over, each landing pop and seam
## wave long run (so every stitch is drawn whole), nothing held, flying or
## pending, and the rack left showing only the gone shapes. Never
## check_solved(): the host owns the win for a restore.
func restore_completed_board() -> void:
	var t := _now()
	_tip_timer.stop()
	_drag = {}
	_flying = {}
	_lifted = {}
	_glide = {}
	_refused = {}
	_pending = []
	_anim_until = 0.0
	_solved_at = -1.0
	_opened = t - 10.0
	for p in _state.shapes.size():
		_state.at[p] = int(_state.answer[p])
		_state.locked[p] = 0
		_landed[p] = t - 10.0
	_state.history = []
	_state.recompute()
	_say(tr("QL_WIN"), Face.Expr.JOY)
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

func share_glyphs() -> String:
	return _state.share_glyphs()

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("QL_WIN")}

## Long enough for the hem's stitch to run all the way round the finished
## quilt. Under reduce-motion there is no wave, so the win follows the last
## patch (spec section 9's reduce-motion row).
func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

func _on_solved() -> void:
	_solved_at = _now()
	_drag = {}
	_tip_timer.stop()
	# Gold on each patch as the hop reaches it, and no ring: eight rings over
	# a finished quilt is a firework, where the hem's stitch is the point.
	for p in _state.shapes.size():
		var origin := int(_state.at[p])
		if origin < 0:
			continue
		var at := Vector2i(origin % _state.cols, origin / _state.cols)
		_fx_at(_origin() + _centroid(p) * _cell(), Pal.SUN,
			Motion.SOLVE_DELAY + Motion.stagger(at.x + at.y, Motion.SOLVE_STAGGER), false)
	_busy_for(Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME)
	_say(tr("QL_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
