extends "res://core/puzzle_base.gd"

## Caterpillar as a flat board: a garden of squares with numbered leaves on
## some of them and wooden fences between a few. Press leaf 1 and drag, and
## every square the finger crosses grows the caterpillar one segment; it eats
## the leaves in order, never crosses itself or a fence, and the board is done
## when its body fills every square with its head on the last leaf. The rules
## live in puzzles/caterpillar_state.gd, which this only draws.
##
## **Nothing wrong can sit on this garden.** A fence, a leaf out of turn and
## the last leaf too soon are refused at the step, with the head shivering
## and the tip card saying why, so the only way to be wrong is to be stuck:
## no Check, no tray and no actions row. The tip card stands alone and Undo,
## Reset and Hint ride in the top bar -- Pinwheel's shape.
##
## How it is drawn. Three meshes and the leaf numbers between them:
##   still -- the bare ground and its grid, rebuilt only on a relayout;
##   live  -- the hint's gold wash, the fences, the body and the leaf badges;
##   top   -- the head and, on the solve, the butterfly;
## with the numbers drawn over `live` and under `top`, because the head is the
## one thing the finger is holding and it must never sit under a badge (the
## concept page's first frame hid it under leaf 3). The caterpillar itself is
## `ui/faces/caterpillar.gd`, which the menu card draws too.
##
## Spec: docs/superpowers/specs/2026-09-25-caterpillar-flat-design.md,
## section 7. Ported from the canvas mock at
## docs/brainstorm/concepts.html#caterpillar, the reference for every measure.

const State = preload("res://puzzles/caterpillar_state.gd")
const Gen = preload("res://puzzles/caterpillar_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
## Rings' garden pieces -- a leaf, a daisy and the stable hash -- are statics,
## shared so the two terraces grow the same plants.
const Rings = preload("res://puzzles/rings2d.gd")

# --- the screen, measured ---
## The card's inset, the largest cell any band asks for, the card's corner the
## garden is clipped to, and the bed: its lawn's pad round the grid, the
## wooden frame round that, and the tiles' gap and corner.
const INSET := 40.0
const CELL_CAP := 180.0
const CARD_RADIUS := 32.0
const GROUND_PAD := 6.0
const FRAME := 20.0
const FRAME_R := 24.0
const TILE_GAP := 3.0
const TILE_R := 0.12
## While a finger is dragging, only the middle of a square counts, so a fast
## drag along one row cannot clip the corner of the next.
const DRAG_CORE := 0.1
## The lawn round the bed: its two mown tones and the share of tiles with a
## clover on them.
const CLOVER_SHARE := 0.3

# --- the pieces, in cells ---
## A leaf: the leaf itself lying under the square (its length, width and
## angle), then the ink badge over the body with its number, and the gold
## ring an eaten one wears.
const LEAF_LEN := 0.9
const LEAF_WIDE := 0.5
const LEAF_ANGLE := -0.72
const BADGE_R := 0.25
const EATEN_RING := 0.03
const EATEN_RING_W := 0.05
const NUMBER := 1.2
## The bite an eaten leaf shows: three rounds out of its edge near the tip.
const BITE_R := 0.085
## A fence: its length and thickness, the lit rail's share of the width, and
## its posts.
const FENCE_LEN := 1.02
const FENCE_TH := 0.13
const RAIL := 0.62
const POST := 0.2
## The gold wash under a square a hint grew.
const GIVEN_R := 0.42
const GIVEN_ALPHA := 0.4

# --- this board's own motion ---
## The head easing in from the square it left, its breath at rest (amplitude,
## rate, phase), the antennae's sway, and the munch. Only the head moves at
## rest: see _process.
const SLIDE_TIME := 0.11
const CRAWL := 0.035
const CRAWL_RATE := 4.2
const CRAWL_PHASE := 0.7
const SWAY := 0.13
const SWAY_RATE := 2.3
## Eating: CHEWS chews of CHEW each once the head has landed on a leaf, the
## head squashing and leaning into the leaf, its mouth opening and closing
## on a scrap that shrinks with every chew, a bite coming out of the leaf and
## a few crumbs on each; then a gulp, a bigger swell than the crawl's, runs
## back down the body GULP_STEP a segment, fading over GULP_REACH.
const CHEWS := 3
const CHEW := 0.17
const CHEW_SQUASH := 0.12
const CHEW_LEAN := 0.05
const BITE_OPEN := 0.09
const GULP := 0.2
const GULP_STEP := 0.045
const GULP_TIME := 0.26
const GULP_REACH := 14
## The crawl: every step sends a swell back down the body from the head,
## RIPPLE_STEP a segment, fading out over RIPPLE_REACH segments.
const RIPPLE := 0.13
const RIPPLE_STEP := 0.035
const RIPPLE_TIME := 0.2
const RIPPLE_REACH := 9
## The walk while a finger drags it: each leg pair steps WALK_RATE radians a
## second, the wave running tail to head WALK_LAG a segment, the body
## wiggling across by WIGGLE of a cell, all easing out over WALK_FADE after
## the last square it moved.
const WALK_RATE := 16.0
const WALK_LAG := 0.9
const WALK_FADE := 0.4
const WIGGLE := 0.025
## A cut back to an earlier square: the head runs back along its own body,
## RETREAT_STEP a square but never longer than RETREAT_MAX in all, folding
## the body up behind it as it goes.
const RETREAT_STEP := 0.05
const RETREAT_MAX := 0.6
## A segment cut away pops out over this, and a Reset's pop tail first.
const GHOST_TIME := 0.18
## The solve: the hop runs tail to head over SOLVE_SPAN whatever the length,
## warming each segment toward sun as it passes, then the butterfly unfolds
## out of the head and flies a loop over the garden and away.
const SOLVE_SPAN := 0.7
const BUTTERFLY_LAG := 0.05
const BUTTERFLY_TIME := 2.1
const BUTTERFLY_OPEN := 0.35
## The butterfly's half-span, in cells, the height it leaves by and the
## loop's radius, in cells.
const BUTTERFLY_W := 0.75
const BUTTERFLY_RISE := 1000.0
const BUTTERFLY_LOOP := 1.1
const WIN_WAIT := 2.8
## A refusal repeated on the same square is not said twice inside this.
const REFUSE_QUIET := 0.5
const HINTS := 3
## A hint's segments arrive this far apart.
const HINT_STEP := 0.08

const TIP_CYCLE := 8.0
const TIPS := ["CP_TIP_START", "CP_TIP_ORDER", "CP_TIP_FILL", "CP_TIP_BACK", "CP_TIP_FENCE"]

var _state = State.new()
var fx: Node2D

## When each body segment appeared, parallel to the body.
var _seg_at: Array[float] = []
var _head_from := -1
var _head_at := -100.0
var _munch_at := -100.0
var _dragging := false
var _stroke_from := PackedInt32Array()
## The last refusal: {"at", "cell", "kind"}.
var _refused := {"at": -100.0, "cell": -1, "kind": ""}
var _rings: Array = []
## Segments cut away, popping out: {"at", "from", "dir", "r", "fill"}.
var _ghosts: Array = []
## Swells running down the body: the time each step landed.
var _ripples: Array[float] = []
## Gulps running down the body: the time each chewing ended.
var _gulps: Array[float] = []
## When each eaten leaf's chewing began, by its square.
var _munched := {}
## When the body last moved a square, for the walk.
var _walked_at := -100.0
## A cut the head is running back over: the squares cut away, tail end
## first, when it set off, and how long each square takes.
var _retreat := PackedInt32Array()
var _retreat_at := -100.0
var _retreat_step := 0.05

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
var _still: ArrayMesh
var _live: ArrayMesh
var _top: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "caterpillar"
func title() -> String: return "Caterpillar"

func rules() -> String:
	return tr("CP_RULES")

## Undo and Hint; Reset is the host's. No Check: nothing wrong can sit here.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	_state.build(rng, difficulty)
	_seg_at = []
	_head_from = -1
	_dragging = false
	_refused = {"at": -100.0, "cell": -1, "kind": ""}
	_rings = []
	_ghosts = []
	_retreat = PackedInt32Array()
	_ripples = []
	_gulps = []
	_munched = {}
	_anim_until = 0.0
	_solved_at = -1.0
	_layout()
	_opened = _now()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()

# --- layout ---

func _cell() -> float:
	if _state.cols <= 0:
		return 0.0
	return maxf(0.0, minf(CELL_CAP, minf((size.x - 2.0 * INSET) / _state.cols,
		(size.y - 2.0 * INSET) / _state.rows)))

func _grid_size() -> Vector2:
	return Vector2(_state.cols, _state.rows) * _cell()

func _origin() -> Vector2:
	return (size - _grid_size()) * 0.5

func _mid() -> Vector2:
	return _origin() + _grid_size() * 0.5

func _centre(c: int) -> Vector2:
	return _origin() + (Vector2(c % _state.cols, c / _state.cols) + Vector2(0.5, 0.5)) * _cell()

## Control-local point over the centre of the square at (row, column), the
## name every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.cols + c)

## The square under a local point, or -1. While dragging only its core counts.
func _cell_at(local: Vector2, core := false) -> int:
	var s := _cell()
	if s <= 0.0:
		return -1
	var p := (local - _origin()) / s
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if x < 0 or y < 0 or x >= _state.cols or y >= _state.rows:
		return -1
	if core:
		var f := p - Vector2(x, y)
		if f.x < DRAG_CORE or f.x > 1.0 - DRAG_CORE or f.y < DRAG_CORE or f.y > 1.0 - DRAG_CORE:
			return -1
	return y * _state.cols + x

func card_height(available: float) -> float:
	return available

## The grid is square and the slot is tall, so the slack is halved.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_refresh()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	if _animating(t):
		_refresh()
	elif not Motion.reduce and not _state.body.is_empty():
		# At rest only the head moves -- its breath and its blink -- and it is
		# its own small mesh, so an idle garden rebuilds that and nothing
		# else. The first cut breathed every segment and rebuilt the whole
		# body a frame: 12 ms an idle frame on this Mac against Pinwheel's 3.
		_top = null
		queue_redraw()

## Asked wave by wave: the entrance, a slide, a pop, a refusal, a ring and
## the solve all ask for time by the clock through _busy_for.
func _animating(t: float) -> bool:
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(_state.last_leaf(), Motion.ENTER_STAGGER) + Motion.POP_IN
	return t - _opened < entrance

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _refresh() -> void:
	_live = null
	_top = null
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _mid()
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	var shown: Array = []
	if _still == null:
		_still = _build_still()
	if _live == null:
		_live = _build_live(t)
	if _top == null:
		_top = _build_top(t)
	for m in [_still, _live]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_numbers(t, xf, seen)
	if _top != null:
		draw_mesh(_top, null, xf, tint)
		shown.append(_top)
	_draw_butterfly_mesh(t, shown)
	_shown = shown

# --- the garden, built once a layout ---

## The garden: a mown lawn over the whole card with dappled shade, tufts and
## daisies, foliage hanging into the top corners and bushes along the foot,
## and in the middle the bed -- a wooden frame round a checker of pale grass
## tiles, a clover on some. It never moves, so it is one mesh built once a
## layout, and the live mesh rebuilt while anything moves stays as small as
## before.
func _build_still() -> ArrayMesh:
	pass
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	var w := size.x
	var h := size.y
	var seed_i: int = _state.cols * 131 + _state.last_leaf() * 7 + _state.hedges.size()
	var clip := Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0)
	Rings._clip_polygon(b, clip, Pal.MEADOW.lerp(Pal.PAPER, 0.55), clip)
	# Mown stripes across the lawn, a shade apart.
	var band := 90.0
	for k in int(ceil(h / band)):
		if k % 2 == 1:
			Rings._clip_polygon(b, PackedVector2Array([Vector2(0.0, k * band), Vector2(w, k * band),
				Vector2(w, (k + 1) * band), Vector2(0.0, (k + 1) * band)]), Pal.MEADOW.lerp(Pal.PAPER, 0.45), clip)
	var shade := Color(Pal.LEAF_DEEP, 0.07)
	for d in 7:
		var at := Vector2(w * Rings._h(seed_i, d + 200), h * Rings._h(seed_i, d + 300))
		for q in 5:
			var off := Vector2((Rings._h(d, q + 1) - 0.5) * 220.0, (Rings._h(d, q + 7) - 0.5) * 120.0)
			var r := 45.0 + 40.0 * Rings._h(d, q + 13)
			var c := (at + off).clamp(Vector2(r, r * 0.6), Vector2(w - r, h - r * 0.6))
			Scenery.soft_disc(b, c, r, r * 0.6, shade)
	# Tufts and daisies on the open lawn, never under the bed.
	var bed := Rect2(o - Vector2.ONE * (GROUND_PAD + FRAME + 16.0), g + Vector2.ONE * (GROUND_PAD + FRAME + 16.0) * 2.0)
	var ident := func(p: Vector2) -> Vector2: return p
	for f in 26:
		var at := Vector2(30.0 + (w - 60.0) * Rings._h(seed_i, f + 500), 40.0 + (h - 80.0) * Rings._h(seed_i, f + 600))
		if bed.has_point(at):
			continue
		if f % 3 == 0:
			Rings._append_daisy(b, at, 13.0 + 5.0 * Rings._h(seed_i, f + 700), ident)
		else:
			Scenery.tuft(b, at, 16.0 + 10.0 * Rings._h(seed_i, f + 800))
	_foliage(b, Vector2(0.0, 0.0), 1.0, seed_i + 1, clip)
	_foliage(b, Vector2(w, 0.0), -1.0, seed_i + 2, clip)
	_bush(b, Vector2(44.0, h + 6.0), 100.0, seed_i + 3, clip)
	_bush(b, Vector2(w - 50.0, h + 6.0), 112.0, seed_i + 4, clip)
	_bush(b, Vector2(w * 0.6, h + 4.0), 54.0, seed_i + 5, clip)
	# The bed: a shadow, the wooden frame with its grain, the grout, then the tiles.
	var lawn := o - Vector2.ONE * GROUND_PAD
	var lawn_size := g + Vector2.ONE * GROUND_PAD * 2.0
	var out := lawn - Vector2.ONE * FRAME
	var out_size := lawn_size + Vector2.ONE * FRAME * 2.0
	Scenery.soft_disc(b, out + out_size * Vector2(0.5, 1.0) + Vector2(0.0, 6.0), out_size.x * 0.55, 34.0, Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 6.0), out_size, FRAME_R), Pal.PLAQUE_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R), Pal.PLAQUE)
	b.fan(Face.Builder.round_rect(out + Vector2.ONE * 3.0, out_size - Vector2.ONE * 6.0, FRAME_R - 3.0), Pal.WOOD)
	var grain := Color(Pal.PLAQUE_DEEP, 0.25)
	var mid := FRAME * 0.5
	for k: float in [-1.0, 1.0]:
		var off := k * 3.5
		b.stroke(PackedVector2Array([lawn + Vector2(lawn_size.x * 0.1, -mid + off), lawn + Vector2(lawn_size.x * 0.44, -mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([lawn + Vector2(lawn_size.x * 0.6, lawn_size.y + mid + off), lawn + Vector2(lawn_size.x * 0.92, lawn_size.y + mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([lawn + Vector2(-mid + off, lawn_size.y * 0.3), lawn + Vector2(-mid + off, lawn_size.y * 0.72)]), 1.5, grain)
		b.stroke(PackedVector2Array([lawn + Vector2(lawn_size.x + mid + off, lawn_size.y * 0.14), lawn + Vector2(lawn_size.x + mid + off, lawn_size.y * 0.5)]), 1.5, grain)
	b.fan(Face.Builder.round_rect(lawn - Vector2.ONE * 3.0, lawn_size + Vector2.ONE * 6.0, FRAME_R - 6.0), Pal.PLAQUE)
	b.fan(Face.Builder.round_rect(lawn, lawn_size, FRAME_R - 8.0), Pal.MEADOW_LINE)
	for c in _state.size():
		var x: int = c % _state.cols
		var y: int = c / _state.cols
		var at := o + Vector2(x, y) * s + Vector2.ONE * TILE_GAP
		var side := s - TILE_GAP * 2.0
		var tone := Pal.MEADOW.lerp(Pal.SURFACE, 0.34 if (x + y) % 2 == 0 else 0.18)
		b.fan(Face.Builder.round_rect(at + Vector2(0.0, 3.0), Vector2.ONE * side, s * TILE_R), Pal.MEADOW_LINE.lerp(Pal.LEAF, 0.18))
		b.fan(Face.Builder.round_rect(at, Vector2.ONE * side, s * TILE_R), tone)
		b.fan(Face.Builder.round_rect(at + Vector2(side * 0.1, side * 0.06), Vector2(side * 0.5, side * 0.05), side * 0.025),
			Color(Pal.SURFACE, 0.35))
		if Rings._h(seed_i + c, 41) < CLOVER_SHARE and _state.clue[c] == 0:
			var corner := at + Vector2(0.2 + 0.6 * Rings._h(c, 42), 0.72 + 0.1 * Rings._h(c, 43)) * side
			_clover(b, corner, s * 0.06, tone.lerp(Pal.LEAF, 0.35))
		elif Rings._h(seed_i + c, 44) < 0.35:
			var root := at + Vector2(0.18 + 0.64 * Rings._h(c, 45), 0.86) * side
			for q in 3:
				var tip := root + Vector2((float(q) - 1.0) * s * 0.035, -s * (0.07 + 0.03 * float(q % 2)))
				b.stroke(PackedVector2Array([root + Vector2((float(q) - 1.0) * s * 0.012, 0.0), tip]), s * 0.018, tone.lerp(Pal.LEAF, 0.3))
	return b.mesh()

## Three small rounds and a stalk: a clover lying on a tile.
func _clover(b, at: Vector2, r: float, col: Color) -> void:
	for q in 3:
		var a := -PI * 0.5 + TAU * float(q) / 3.0
		b.disc(at + Vector2.from_angle(a) * r * 0.75, r * 0.62, col)
	b.stroke(PackedVector2Array([at, at + Vector2(r * 0.5, r * 1.5)]), r * 0.22, col)

## Leaves hanging in from a top corner, `out` +1 at the left and -1 at the
## right, deep behind and lit in front.
func _foliage(b, root: Vector2, out: float, seed_i: int, clip: PackedVector2Array) -> void:
	var layers := [[Pal.LEAF_DEEP, 8, 1.0], [Pal.LEAF, 6, 0.78], [Pal.LEAF_LIGHT, 4, 0.52]]
	for li in layers.size():
		var layer: Array = layers[li]
		var n: int = layer[1]
		for q in n:
			var ang := lerpf(0.0, PI * 0.5, float(q) / float(n - 1))
			if out < 0.0:
				ang = PI - ang
			ang += (Rings._h(seed_i, q + li * 11) - 0.5) * 0.3
			var lng := 104.0 * float(layer[2]) * (0.7 + 0.5 * Rings._h(seed_i, q + li * 11 + 40))
			_clip_leaf(b, root + Vector2(out * 14.0 * Rings._h(seed_i, q + 90), -8.0), ang, lng, layer[0], clip)

## A bush along the foot: a dome of leaves with a daisy or two on it.
func _bush(b, root: Vector2, bush: float, seed_i: int, clip: PackedVector2Array) -> void:
	var layers := [[Pal.LEAF_DEEP, 9, 1.0], [Pal.LEAF, 7, 0.78], [Pal.LEAF_LIGHT, 4, 0.52]]
	for li in layers.size():
		var layer: Array = layers[li]
		var n: int = layer[1]
		for q in n:
			var ang := lerpf(-PI + 0.25, -0.25, float(q) / float(n - 1)) + (Rings._h(seed_i, q + li * 11) - 0.5) * 0.3
			var lng := bush * float(layer[2]) * (0.75 + 0.4 * Rings._h(seed_i, q + li * 11 + 40))
			_clip_leaf(b, root, ang, lng, layer[0], clip)
	var ident := func(p: Vector2) -> Vector2: return p
	for q in 2:
		var a := lerpf(-PI + 0.7, -0.7, (float(q) + 0.5) / 2.0)
		var at := root + Vector2.from_angle(a) * bush * (0.45 + 0.2 * Rings._h(seed_i, q + 80))
		if Geometry2D.is_point_in_polygon(at, clip):
			Rings._append_daisy(b, at, bush * 0.2, ident)

func _clip_leaf(b, root: Vector2, ang: float, lng: float, col: Color, clip: PackedVector2Array) -> void:
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal() * lng * 0.3
	var tip := root + dir * lng
	var pts := Face.Builder.bezier2(root, root + dir * lng * 0.45 + side, tip, 7)
	pts.append_array(Face.Builder.bezier2(tip, root + dir * lng * 0.45 - side, root, 7))
	Rings._clip_polygon(b, pts, col, clip)

# --- the live mesh ---

func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	for c in _state.given:
		if _state.body.has(c):
			b.fan(Face.Builder.round_rect(_centre(c) - Vector2.ONE * s * GIVEN_R,
				Vector2.ONE * s * GIVEN_R * 2.0, s * 0.18), Color(Pal.SUN_RAY, GIVEN_ALPHA))
	for k in _state.leaves.size():
		_leaf(b, _state.leaves[k], t)
	for e in _state.hedges:
		_fence(b, e, t)
	_draw_ghosts(b, t)
	_body(b, t)
	for k in _state.leaves.size():
		_badge(b, _state.leaves[k], t)
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r["at"])) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			b.stroke(Face.Builder.ring(_centre(r["cell"]), s * (0.34 + 0.3 * u), s * (0.34 + 0.3 * u)),
				s * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	return b.mesh() if not b.verts.is_empty() else null

## A fence on the edge between two squares: a soft shadow, a wooden rail with
## its lit top and grain, and a capped post at either end and in the middle,
## flashing and shivering when the head was just refused across it.
func _fence(b, e: int, t: float) -> void:
	var s := _cell()
	var a := e / 4096
	var z := e % 4096
	var mid := (_centre(a) + _centre(z)) * 0.5
	var vertical: bool = a / _state.cols == z / _state.cols
	var hot := String(_refused["kind"]) == "hedge" and (int(_refused["cell"]) == a or int(_refused["cell"]) == z) \
		and (_state.head() == a or _state.head() == z)
	var since := t - float(_refused["at"]) if hot else -1.0
	var fl := Motion.flash_level(since) if hot else 0.0
	var sh := Motion.shiver_offset(since) * 2.0 if hot else 0.0
	var along := Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)
	var across := Vector2(1.0, 0.0) if vertical else Vector2(0.0, 1.0)
	var at := mid + across * sh
	var ln := s * FENCE_LEN
	var th := s * FENCE_TH
	var xf := Transform2D(across, along, at)
	Scenery.soft_disc(b, at + Vector2(0.0, th * 0.9), (ln * 0.55 if not vertical else th * 1.6), (th * 1.3 if not vertical else ln * 0.55),
		Color(Pal.TEXT, 0.16))
	b.fan(xf * Face.Builder.round_rect(Vector2(-th * 0.5, -ln * 0.5 + th * 0.35), Vector2(th, ln), th * 0.4),
		Pal.PLAQUE_DEEP.lerp(Pal.BAD, fl * 0.7))
	b.fan(xf * Face.Builder.round_rect(Vector2(-th * 0.5, -ln * 0.5), Vector2(th, ln), th * 0.4),
		Pal.FENCE_DARK.lerp(Pal.BAD, fl * 0.7))
	b.fan(xf * Face.Builder.round_rect(Vector2(-th * 0.42, -ln * 0.5), Vector2(th * RAIL, ln), th * 0.3),
		Pal.FENCE_RAIL.lerp(Pal.BAD, fl * 0.5))
	b.stroke(xf * PackedVector2Array([Vector2(-th * 0.1, -ln * 0.3), Vector2(-th * 0.1, -ln * 0.05)]), 1.5, Color(Pal.FENCE_DARK, 0.4))
	b.stroke(xf * PackedVector2Array([Vector2(-th * 0.2, ln * 0.12), Vector2(-th * 0.2, ln * 0.36)]), 1.5, Color(Pal.FENCE_DARK, 0.4))
	var p := s * POST
	for y: float in [-ln * 0.5 + p * 0.45, 0.0, ln * 0.5 - p * 0.45]:
		var sq := Face.Builder.round_rect(Vector2(-p * 0.5, y - p * 0.5), Vector2.ONE * p, p * 0.25)
		b.fan(xf * Face.Builder.round_rect(Vector2(-p * 0.5, y - p * 0.5 + p * 0.22), Vector2.ONE * p, p * 0.25), Pal.PLAQUE_DEEP)
		b.fan(xf * sq, Pal.FENCE_POST.lerp(Pal.BAD, fl * 0.5))
		b.fan(xf * Face.Builder.round_rect(Vector2(-p * 0.36, y - p * 0.38), Vector2(p * 0.6, p * 0.5), p * 0.18),
			Pal.FENCE_RAIL.lerp(Pal.BAD, fl * 0.4))

## Every body point this frame, tail first: each square's centre, the head's
## eased in from the square it left, and the solve's hop running tail to head.
func _points(t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = _state.body.size()
	# While the head runs back over a cut, the squares it has not reached yet
	# are still body: the chain runs on through them to wherever it is now.
	var chain: PackedInt32Array = _state.body.duplicate()
	var left := _retreat_left(t)
	if left > 0.0:
		chain.append_array(_retreat.slice(0, int(ceil(left))))
	var last := chain.size() - 1
	var walk := _walk(t)
	for i in chain.size():
		var p := _centre(chain[i])
		if left > 0.0 and i == last:
			# The head, part-way between the square it is leaving and the
			# next one back.
			var frac := left - floorf(left)
			if frac > 0.0:
				p = _centre(chain[last - 1]).lerp(p, frac)
		elif i == n - 1 and left <= 0.0 and _head_from >= 0 and not Motion.reduce:
			var u := clampf((t - _head_at) / SLIDE_TIME, 0.0, 1.0)
			if u < 1.0:
				p = _centre(_head_from).lerp(p, 0.5 - 0.5 * cos(PI * u))
		if walk > 0.0 and i < last:
			var d := _centre(chain[mini(i + 1, last)]) - _centre(chain[maxi(i - 1, 0)])
			if d.length() > 0.01:
				p += d.normalized().orthogonal() * _cell() * WIGGLE * walk * sin(_gait_phase(i, t) + 0.8)
		if _solved_at >= 0.0:
			p.y += Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY - _wave(i, n),
				Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		pts.append(p)
	return pts

## How many squares of a cut the head has still to run back over, counted
## from the square it is cutting to; 0 once it is there.
func _retreat_left(t: float) -> float:
	if _retreat.is_empty() or Motion.reduce:
		return 0.0
	var m := float(_retreat.size())
	var u := clampf((t - _retreat_at) / (_retreat_step * m), 0.0, 1.0)
	return m * (1.0 - u * u * (3.0 - 2.0 * u))

## How hard the body is walking, 0 to 1: full while squares keep coming,
## easing to rest over WALK_FADE after the last.
func _walk(t: float) -> float:
	if Motion.reduce:
		return 0.0
	var u := clampf((t - _walked_at) / WALK_FADE, 0.0, 1.0)
	return 1.0 - u * u * (3.0 - 2.0 * u)

## Where segment `i` is in its step.
func _gait_phase(i: int, t: float) -> float:
	return t * WALK_RATE - float(i) * WALK_LAG

## When the solve's hop reaches segment `i` of `n`: SOLVE_SPAN tail to head.
static func _wave(i: int, n: int) -> float:
	return SOLVE_SPAN * float(i) / float(maxi(n - 1, 1))

func _body(b, t: float) -> void:
	if _state.body.is_empty():
		return
	var pts := _points(t)
	var n := pts.size()
	var scales: Array = []
	var breath := PackedFloat32Array()
	var glow := PackedFloat32Array()
	for i in n:
		scales.append(Motion.pop_in_scale(t - _seg_at[i]) if i < _seg_at.size() else Vector2.ONE)
		breath.append(_swell(i, n, t))
		glow.append(Motion.flash_level(t - _solved_at - Motion.SOLVE_DELAY - _wave(i, n), 0.1, 0.6)
			if _solved_at >= 0.0 else 0.0)
	var gait := PackedVector2Array()
	var walk := _walk(t)
	if walk > 0.0:
		for i in n:
			var ph := _gait_phase(i, t)
			gait.append(Vector2(sin(ph), cos(ph)) * walk)
	Cat.body(b, pts, _cell(), scales, breath, glow, gait)

## How swollen segment `i` of `n` is by the crawl: each step's swell leaves
## the head and runs back RIPPLE_STEP a segment, fading as it goes.
func _swell(i: int, n: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var k := n - 1 - i
	if k >= maxi(RIPPLE_REACH, GULP_REACH):
		return 1.0
	var out := 1.0
	for at in _gulps:
		var g := (t - at - float(k) * GULP_STEP) / GULP_TIME
		if g > 0.0 and g < 1.0 and k < GULP_REACH:
			out = maxf(out, 1.0 + GULP * sin(PI * g) * (1.0 - float(k) / float(GULP_REACH)))
	for at in _ripples:
		var u := (t - at - float(k) * RIPPLE_STEP) / RIPPLE_TIME
		if u > 0.0 and u < 1.0 and k < RIPPLE_REACH:
			out = maxf(out, 1.0 + RIPPLE * sin(PI * u) * (1.0 - float(k) / float(RIPPLE_REACH)))
	return out

## The segments cut away, each popping out where it stood.
func _draw_ghosts(b, t: float) -> void:
	var keep: Array = []
	for g: Dictionary in _ghosts:
		var e := t - float(g["at"])
		if e < 0.0:
			Cat.segment(b, g["from"], g["dir"], g["r"], Vector2.ONE, g["fill"])
			keep.append(g)
		elif e < GHOST_TIME:
			var k := Motion.pop_out_scale(e, GHOST_TIME)
			Cat.segment(b, g["from"], g["dir"], g["r"], Vector2(k * (1.0 + 0.3 * (1.0 - k)), k), g["fill"], k)
			keep.append(g)
	_ghosts = keep

## Every square of `old` the body no longer has pops out, `stagger` apart
## from the tail end.
func _ghost_diff(old: PackedInt32Array, t: float, stagger := 0.0) -> void:
	if Motion.reduce:
		return
	var k := 0
	for i in old.size():
		var c := old[i]
		if _state.body.has(c):
			continue
		var dir := Vector2(1.0, 0.0)
		if old.size() > 1:
			var a := _centre(old[maxi(i - 1, 0)])
			var z := _centre(old[mini(i + 1, old.size() - 1)])
			dir = (z - a).normalized() if a.distance_to(z) > 0.01 else dir
		_ghosts.append({"at": t + float(k) * stagger, "from": _centre(c), "dir": dir,
			"r": _cell() * Cat.SEG_R, "fill": Pal.LEAF if i % 2 == 1 else Pal.LEAF_LIGHT})
		k += 1
	_busy_for(float(k) * stagger + GHOST_TIME)

## The leaf lying on a leaf's square, under the body: it pops in with its
## badge, and once eaten carries three bites out of its edge.
func _leaf(b, c: int, t: float) -> void:
	var f := _badge_frame(c, t)
	if f.scale.x <= 0.01:
		return
	var s := _cell()
	var xf := Transform2D(LEAF_ANGLE, f.scale, 0.0, f.at + Vector2(s * 0.03, s * 0.02))
	var ln := s * LEAF_LEN
	var wd := s * LEAF_WIDE
	var root := Vector2(-ln * 0.5, 0.0)
	var tip := Vector2(ln * 0.5, 0.0)
	var pts := Face.Builder.bezier3(root, Vector2(-ln * 0.2, -wd * 0.75), Vector2(ln * 0.3, -wd * 0.55), tip, 12)
	pts.append_array(Face.Builder.bezier3(tip, Vector2(ln * 0.3, wd * 0.55), Vector2(-ln * 0.2, wd * 0.75), root, 12))
	for q in CHEWS:
		var bitten := _bite(c, t, q)
		if bitten <= 0.0:
			continue
		var at := Vector2(ln * (0.08 + 0.13 * float(q)), -wd * (0.36 - 0.06 * float(q)))
		var cut := Geometry2D.clip_polygons(pts, Face.Builder.ring(at, s * BITE_R * bitten, s * BITE_R * bitten))
		if not cut.is_empty():
			pts = cut[0]
	var ghost: Color = Pal.LEAF_LIGHT if not _state.body.has(c) else Pal.LEAF_LIGHT.lerp(Pal.LEAF, 0.35)
	var under := PackedVector2Array()
	for p in pts:
		under.append(p + Vector2(0.0, s * 0.03).rotated(-LEAF_ANGLE))
	b.polygon(xf * under, Pal.LEAF_DEEP)
	b.polygon(xf * pts, ghost)
	b.stroke(xf * PackedVector2Array([root + Vector2(ln * 0.02, 0.0), tip - Vector2(ln * 0.08, 0.0)]), s * 0.022, Pal.LEAF)
	for q in 3:
		var x := -ln * 0.28 + ln * 0.22 * float(q)
		for side: float in [-1.0, 1.0]:
			b.stroke(xf * PackedVector2Array([Vector2(x, 0.0), Vector2(x + ln * 0.12, side * wd * 0.26)]), s * 0.014, Color(Pal.LEAF, 0.8))
	b.stroke(xf * PackedVector2Array([root, root - Vector2(ln * 0.1, -wd * 0.05)]), s * 0.028, Pal.LEAF_DEEP)

## How far bite `q` of a leaf has come, 0 to 1: nothing until eaten, then
## each opens on its own chew, as the jaw closes.
func _bite(c: int, t: float, q: int) -> float:
	if not _state.body.has(c):
		return 0.0
	if Motion.reduce or not _munched.has(c):
		return 1.0
	return clampf((t - float(_munched[c]) - (float(q) + 0.35) * CHEW) / BITE_OPEN, 0.0, 1.0)

## A leaf's badge over the body: an ink disc with a gold ring once eaten. It
## pops in on the entrance by its number, bumps when eaten, and flashes and
## shivers when a step onto it was refused.
func _badge(b, c: int, t: float) -> void:
	var f := _badge_frame(c, t)
	if f.scale.x <= 0.01:
		return
	var s := _cell()
	var r := s * BADGE_R
	var xf := Transform2D(0.0, f.scale, 0.0, f.at)
	var got: bool = _state.body.has(c)
	Scenery.soft_disc(b, f.at + Vector2(0.0, s * 0.04), r * 1.3 * f.scale.x, r * 1.15 * f.scale.x, Color(Pal.TEXT, 0.18))
	if got:
		var ring := r + s * (EATEN_RING + EATEN_RING_W * 0.5)
		b.fan(xf * Face.Builder.ring(Vector2(0.0, s * 0.02), ring, ring), Pal.SUN_DEEP)
		b.fan(xf * Face.Builder.ring(Vector2.ZERO, ring, ring), Pal.SUN)
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, r, r), Pal.TEXT.lerp(Pal.BAD, f.flash * 0.7))
	b.fan(xf * Face.Builder.ring(Vector2(-0.3, -0.42) * r, r * 0.34, r * 0.16), Color(1.0, 1.0, 1.0, 0.12))

## Where a badge is and how big this frame: {at, scale, flash}.
func _badge_frame(c: int, t: float) -> Dictionary:
	var k: int = _state.clue[c]
	var hot := int(_refused["cell"]) == c and String(_refused["kind"]) in ["order", "last"]
	var since := t - float(_refused["at"]) if hot else -1.0
	var pop := Motion.pop_in_scale(t - _opened - Motion.ENTER_DELAY - Motion.ENTER_POP * 0.4
		- Motion.stagger(k, Motion.ENTER_STAGGER))
	var bump := 1.0
	for r: Dictionary in _rings:
		if int(r["cell"]) == c:
			bump = maxf(bump, Motion.bump_scale(t - float(r["at"]), 0.14, 0.3))
	return {"at": _centre(c) + Vector2(Motion.shiver_offset(since) * 3.0 if hot else 0.0, 0.0),
		"scale": pop * bump, "flash": Motion.flash_level(since) if hot else 0.0}

## The leaf numbers, over the badges and under the head.
func _draw_numbers(t: float, xf: Transform2D, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	var px := int(round(_cell() * BADGE_R * NUMBER))
	for k in _state.leaves.size():
		var c: int = _state.leaves[k]
		var f := _badge_frame(c, t)
		if f.scale.x <= 0.01:
			continue
		var text := str(k + 1)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		var rise := font.get_height(px) * 0.5 - font.get_descent(px)
		draw_set_transform_matrix(xf * Transform2D(0.0, f.scale, 0.0, f.at))
		draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
			Color(Pal.SURFACE, seen))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## The head, over everything the finger is not holding.
func _build_top(t: float) -> ArrayMesh:
	if _state.body.is_empty():
		return null
	var b := Face.Builder.new()
	var pts := _points(t)
	var n := pts.size()
	var at := pts[n - 1]
	var dir := Vector2(0.0, -1.0)
	if n > 1:
		dir = (at - pts[n - 2]).normalized() if at.distance_to(pts[n - 2]) > 0.01 else \
			(_centre(_state.body[mini(n, _state.body.size()) - 1]) - _centre(_state.body[maxi(mini(n, _state.body.size()) - 2, 0)])).normalized()
	var since := t - float(_refused["at"])
	var strain := String(_refused["kind"]) != "" and since < Motion.SHIVER_TIME * 2.0
	at.x += Motion.shiver_offset(since) * 4.0 if strain else 0.0
	var expr := Face.Expr.JOY if _solved_at >= 0.0 else (Face.Expr.STRAIN if strain else Face.Expr.HAPPY)
	var grow := 1.0 if Motion.reduce else 1.0 + CRAWL * 0.6 * sin(t * CRAWL_RATE + CRAWL_PHASE)
	var sq := Vector2.ONE
	var sway := 0.0 if Motion.reduce else SWAY * sin(t * SWAY_RATE)
	var eye := _blink(t)
	var snack := 0.0
	var k := (t - _munch_at) / CHEW
	if not Motion.reduce and k >= 0.0 and k < float(CHEWS) and _solved_at < 0.0:
		# Each chew is one smooth cosine: the jaw drops, the head squashes and
		# leans into the leaf, and it closes again, a little softer each time.
		var w := (0.5 - 0.5 * cos(TAU * fmod(k, 1.0))) * (1.0 - 0.2 * floorf(k))
		sq = Vector2(1.0 + CHEW_SQUASH * 0.6 * w, 1.0 - CHEW_SQUASH * w)
		at += dir * _cell() * CHEW_LEAN * w
		sway += 0.3 * w
		expr = Face.Expr.JOY if w > 0.45 else Face.Expr.HAPPY
		eye = 0.1
		snack = 1.0 - clampf((k - 0.5) / float(CHEWS), 0.0, 1.0)
	if strain and not Motion.reduce:
		sway -= 0.3 * sin(PI * clampf(since / (Motion.SHIVER_TIME * 2.0), 0.0, 1.0))
	Cat.head(b, at, dir, _cell(), grow, sq, expr, eye, sway, snack)
	return b.mesh()

func _blink(t: float) -> float:
	if Motion.reduce:
		return 1.0
	var m := fmod(t + 0.4, 3.8)
	return 1.0 - 0.9 * sin(PI * m / 0.14) if m < 0.14 else 1.0

## The butterfly the solve ends in: it unfolds out of the head once the hop
## has reached it, flies a loop over the garden and leaves over the top of
## the card. It is drawn outside the entrance transform and is not clipped,
## so it can fly over the chrome.
func _draw_butterfly_mesh(t: float, shown: Array) -> void:
	if _solved_at < 0.0 or Motion.reduce:
		return
	var u := t - _solved_at - Motion.SOLVE_DELAY - SOLVE_SPAN - BUTTERFLY_LAG
	if u < 0.0 or u > BUTTERFLY_TIME:
		return
	var s := _cell()
	var start := _centre(_state.head())
	var at := _flight(u, start, s)
	var ahead := _flight(u + 0.05, start, s)
	var open := clampf(u / BUTTERFLY_OPEN, 0.0, 1.0)
	var alpha := 1.0 - clampf((u - (BUTTERFLY_TIME - 0.35)) / 0.35, 0.0, 1.0)
	var beat := lerpf(0.15, 0.3 + 0.7 * absf(sin(u * 12.0)), Motion.back_out(open))
	var w := s * BUTTERFLY_W * lerpf(0.35, 1.0, Motion.back_out(open))
	var b := Face.Builder.new()
	Scenery.soft_disc(b, Vector2(at.x, start.y + s * 0.3), w * 0.9 * alpha, w * 0.3 * alpha, Color(Pal.TEXT, 0.12 * (1.0 - clampf(u, 0.0, 1.0))))
	Cat.butterfly(b, at, w, beat, clampf((ahead.x - at.x) * 0.02, -0.4, 0.4), alpha)
	var m := b.mesh()
	draw_mesh(m, null)
	shown.append(m)

## Where the butterfly is `u` seconds after it left the head at `start`: a
## loop round and over the head, then away up and out over the top.
func _flight(u: float, start: Vector2, s: float) -> Vector2:
	var rise := clampf((u - BUTTERFLY_OPEN) / (BUTTERFLY_TIME - BUTTERFLY_OPEN), 0.0, 1.0)
	var loop := BUTTERFLY_LOOP * s * sin(PI * minf(rise * 1.6, 1.0))
	var ang := rise * TAU * 0.9
	var side := -1.0 if start.x > _mid().x else 1.0
	var p := start + Vector2(side * sin(ang) * loop, -(1.0 - cos(ang)) * loop * 0.6)
	p.y -= pow(rise, 2.2) * BUTTERFLY_RISE + s * 0.35 * clampf(u / BUTTERFLY_OPEN, 0.0, 1.0)
	p.x += side * pow(rise, 2.0) * s * 1.5
	p.y += sin(u * 9.0) * s * 0.06 * rise
	return p

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release()
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _dragging:
		var c := _cell_at(event.position, true)
		if c >= 0:
			_step(c)
		accept_event()

func _press(c: int) -> void:
	if c < 0:
		return
	var t := _now()
	_stroke_from = _state.body.duplicate()
	if _state.body.is_empty():
		if _state.start(c):
			_busy_for(Motion.POP_IN)
			_seg_at = [t]
			_head_from = -1
			_head_at = t
			_dragging = true
			_ring_at(c, t)
			fx.cue("place")
			_refresh()
		else:
			_say(tr("CP_START"), Face.Expr.HAPPY)
		return
	if _state.body.has(c):
		_dragging = true
		if c != _state.head():
			_cut(c, t)
	else:
		_say(tr("CP_FROM_HEAD"), Face.Expr.HAPPY)

func _step(c: int) -> void:
	if c == _state.head():
		return
	var t := _now()
	if _state.body.has(c):
		_cut(c, t)
		return
	var why: String = _state.why(c)
	if why == "far":
		return
	if why != "":
		if int(_refused["cell"]) != c or t - float(_refused["at"]) > REFUSE_QUIET:
			_refuse(why, c, t)
		return
	_retreat = PackedInt32Array()
	_head_from = _state.head()
	_head_at = t
	_state.grow(c)
	_seg_at.append(t)
	_crawl(t)
	_busy_for(maxf(SLIDE_TIME, Motion.POP_IN))
	if _state.clue[c] != 0:
		_eat(c, t + SLIDE_TIME)
		fx.cue("munch")
		_speak_leaf(_state.clue[c])
	else:
		fx.cue("step")
	_refresh()
	if _state.is_solved():
		_release()

## The head has landed on leaf `c` at `at`: it chews, a bite and a few
## crumbs a chew, and swallows.
func _eat(c: int, at: float) -> void:
	_munch_at = at
	_munched[c] = at
	_ring_at(c, at)
	var chewing := float(CHEWS) * CHEW
	_busy_for(at - _now() + chewing)
	if Motion.reduce:
		return
	for q in CHEWS:
		get_tree().create_timer(at - _now() + (float(q) + 0.4) * CHEW).timeout.connect(func():
			if _state.body.has(c):
				fx.puff(_centre(c) + Vector2(0.0, _cell() * 0.2), Pal.LEAF_LIGHT, 3))
	var keep: Array[float] = []
	for g in _gulps:
		if _now() - g < float(GULP_REACH) * GULP_STEP + GULP_TIME:
			keep.append(g)
	keep.append(at + chewing)
	_gulps = keep
	_busy_for(at - _now() + chewing + float(GULP_REACH) * GULP_STEP + GULP_TIME)

## A swell leaves the head and runs back down the body.
func _crawl(t: float) -> void:
	if Motion.reduce:
		return
	_walked_at = t
	_busy_for(WALK_FADE)
	var keep: Array[float] = []
	for at in _ripples:
		if t - at < float(RIPPLE_REACH) * RIPPLE_STEP + RIPPLE_TIME:
			keep.append(at)
	keep.append(t)
	_ripples = keep
	_busy_for(float(RIPPLE_REACH) * RIPPLE_STEP + RIPPLE_TIME)

func _cut(c: int, t: float) -> void:
	_busy_for(Motion.POP_IN)
	# A run already under way lands at once: the new one sets off from the
	# square the state's head is on.
	var old: PackedInt32Array = _state.body.duplicate()
	_state.cut_to(c)
	if not Motion.reduce:
		_retreat = old.slice(_state.body.size())
		_retreat_at = t
		_retreat_step = minf(RETREAT_STEP, RETREAT_MAX / float(maxi(_retreat.size(), 1)))
		var run := _retreat_step * float(_retreat.size())
		_walked_at = t + run
		_busy_for(run + WALK_FADE)
	_seg_at.resize(_state.body.size())
	_head_from = -1
	_head_at = t
	fx.cue("step")
	_refresh()

func _refuse(kind: String, c: int, t: float) -> void:
	_refused = {"at": t, "cell": c, "kind": kind}
	_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)
	fx.cue("refuse")
	match kind:
		"hedge": _say(tr("CP_NO_FENCE"), Face.Expr.STRAIN)
		"order": _say(tr("CP_NO_ORDER") % [_state.clue[c], _state.eaten() + 1], Face.Expr.STRAIN)
		"last": _say(tr("CP_NO_LAST") % _state.last_leaf(), Face.Expr.STRAIN)
	_refresh()

## The finger is up: a stroke that changed the body is one move.
func _release() -> void:
	if not _dragging:
		return
	_dragging = false
	if _state.commit(_stroke_from):
		note_move()

func _ring_at(c: int, at: float) -> void:
	if Motion.reduce:
		return
	_rings.append({"cell": c, "at": at})
	_busy_for(at - _now() + Motion.RING_TIME)

func _drop_rings(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rings:
		if t - float(r["at"]) < Motion.RING_TIME:
			keep.append(r)
	_rings = keep

# --- the sprout's line ---

func _speak_leaf(k: int) -> void:
	var left: int = _state.last_leaf() - k
	if left > 0:
		_say(tr("CP_LEAF_ONE") % k if left == 1 else tr("CP_LEAF_N") % [k, left], Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or not _state.body.is_empty():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return _state.can_undo() and not is_done()

## Puts the body back as it was before the last stroke. Counts no move.
func undo() -> bool:
	var old: PackedInt32Array = _state.body.duplicate()
	if is_done() or not _state.undo():
		return false
	_retreat = PackedInt32Array()
	_ghost_diff(old, _now())
	_restored(_now())
	_say(tr("CP_UNDONE"), Face.Expr.HAPPY)
	fx.cue("undo")
	moved.emit()
	return true

## A body that came back whole: the segments it has that the old one did not
## pop back in, tail first.
func _restored(t: float) -> void:
	var n: int = _state.body.size()
	var had := _seg_at.size()
	_seg_at.resize(n)
	for i in range(had, n):
		_seg_at[i] = t + Motion.stagger(i - had, Motion.RESET_STAGGER)
	_head_from = -1
	_head_at = t
	_busy_for(Motion.stagger(maxi(n - had, 0), Motion.RESET_STAGGER) + Motion.POP_IN)
	_refresh()

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Cuts back to the right stretch and grows the answer on to the next leaf.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var t := _now()
	var old: PackedInt32Array = _state.body.duplicate()
	var grown: PackedInt32Array = _state.hint()
	if grown.is_empty():
		return false
	_retreat = PackedInt32Array()
	_ghost_diff(old, t)
	hints_used += 1
	var n: int = _state.body.size()
	_seg_at.resize(n)
	for k in grown.size():
		_seg_at[n - grown.size() + k] = t + float(k) * HINT_STEP
	_head_from = -1
	_head_at = t
	_ring_at(grown[grown.size() - 1], t + float(grown.size() - 1) * HINT_STEP)
	_busy_for(float(grown.size()) * HINT_STEP + Motion.POP_IN)
	_say(tr("CP_HINT"), Face.Expr.HAPPY)
	fx.cue("hint")
	_refresh()
	moved.emit()
	check_solved()
	return true

func reset_board() -> void:
	var old: PackedInt32Array = _state.body.duplicate()
	_state.reset_board()
	_retreat = PackedInt32Array()
	_ghost_diff(old, _now(), Motion.RESET_STAGGER)
	_seg_at = []
	_head_from = -1
	_dragging = false
	_rings = []
	_solved_at = -1.0
	moves = 0
	_running = true
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

## The shape of the day and never its walk: the garden's size, the leaves.
func share_glyphs() -> String:
	return "🐛" + "🍃".repeat(_state.last_leaf()) + "🦋"

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("CP_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

func _on_solved() -> void:
	var t := _now()
	_dragging = false
	_solved_at = t + SLIDE_TIME
	_tip_timer.stop()
	var n: int = _state.body.size()
	for c in _state.leaves:
		var i: int = _state.body.find(c)
		var after := _solved_at - t + Motion.SOLVE_DELAY + _wave(i, n)
		if not Motion.reduce:
			get_tree().create_timer(after).timeout.connect(func(): fx.sparkle(_centre(c), Pal.SUN))
	_busy_for(_solved_at - t + Motion.SOLVE_DELAY + SOLVE_SPAN + Motion.SOLVE_TIME
		+ BUTTERFLY_LAG + BUTTERFLY_TIME)
	_say(tr("CP_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

## A reopened daily that was already solved: the whole walk laid at once,
## nothing left to run. Never check_solved(): `solved` must not fire twice.
func restore_completed_board() -> void:
	_state.body = _state.path.duplicate()
	_seg_at = []
	for i in _state.body.size():
		_seg_at.append(-100.0)
	_head_from = -1
	_solved_at = -1.0
	_anim_until = 0.0
	_opened = _now() - 100.0
	_tip_timer.stop()
	_say(tr("CP_WIN"), Face.Expr.JOY)
	_refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
