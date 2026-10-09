extends Control

## Toy Boats' two grids, seen from straight above, as the folding wooden box
## has them: the **pond**, the player's own water with their five wooden
## boats on it and whatever has landed there, and the **slate**, a chalk
## board on which the player keeps what they have learned of the other pond
## -- a ring for a miss, a cross for a hit, a boat's outline once it is sunk.
##
## While the boats are being laid out the pond is the big one, at the bottom
## where the thumb is, and the slate waits small above it. When play begins
## the two change places: the slate is where the player throws.
##
## Each grid is one baked mesh (the frame, the water or the slate, the lines)
## drawn under a transform, so the change of places rebuilds nothing, and one
## live mesh over it for the boats and the marks, rebuilt only while
## something on it moves. The slate's letters and numbers are the only text.
##
## Input (a touch is not a mouse here, so both are read). Laying out: drag a
## boat to move it, tap it to turn it; a place it cannot lie is refused and it
## goes back. Playing: put a finger on the slate, slide to the square -- its
## row and column light up, since the thumb hides the square itself -- and
## let go to throw.

## The player let go on an untried square of the slate.
signal aimed(c: int)
## What was being shown has finished: the boats are in, a pebble's answer is
## on the slate, a pebble has landed on the pond.
signal settled
## A boat was moved or turned while laying out.
signal moved
## A boat could not go there, or the square was tried already.
signal refused(reason: String)

const Rules = preload("res://versus/boats_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## A square's side in the meshes' own space, and the border round the grid in
## squares: the wooden frame, then a band of water (or slate) inside it.
const U := 100.0
const BORDER := 0.5
const WOOD_W := 0.17
## A grid's side in the meshes' space.
const SIDE := (Rules.N + 2.0 * BORDER) * U
## The small grid's side for the big one's, and the gap between them, pixels.
const SMALL := 0.5
const GAP := 18.0

const WOOD := Color("b98457")
const WOOD_LIT := Color("d3a273")
const WOOD_DEEP := Color("7d5334")
const WATER := Color("4f9fd0")
const WATER_DEEP := Color("3d86b8")
const WATER_LINE := Color(1, 1, 1, 0.2)
const SLATE := Color("38404a")
const SLATE_LIT := Color("454e59")
const CHALK := Color("f3efe6")
const CHALK_LINE := Color(0.95, 0.94, 0.9, 0.3)
const CHALK_HIT := Color("ffb7a3")
const HULL := Color("e6c79b")
const HULL_RIM := Color("a57a48")
const HOLE := Color(0.3, 0.19, 0.1, 0.55)
const PEG := Color("e0574f")
const PEG_LIT := Color("f48c80")
const PEBBLE := Color("8f979f")
const PEBBLE_LIT := Color("b9c0c6")
const SHADE := Color(0.08, 0.2, 0.32, 0.28)
## Under water: what a sunk boat is tinted.
const SUNKEN := Color(0.62, 0.8, 0.95, 0.5)
## The paint line round each boat's deck, by boat.
const PAINT := [Color("e0574f"), Color("4c9a94"), Color("f5a623"), Color("e58fb5"), Color("7d8fd9")]
const HINT := Color("f9c04a")

## Seconds: a pebble's fall onto the pond, how long a landing is watched
## before the game goes on (a sinking a little longer), a mark's splash.
const FALL := 0.42
const WATCH := 0.5
const WATCH_SUNK := 0.95
const SPLASH := 0.55
const SWAP := 0.55
const LETTERS := "ABCDEFGHIJ"

var pond: RefCounted
var slate: RefCounted
## True while the boats are being laid out (the pond big, boats movable).
var laying := false
var interactive := false
## A picture, not a game (the Versus tab's card, a tutorial page): the two
## grids side by side, drawn when asked, no input.
var still := false
## The rectangle the two grids and the panel beside the small one take.
var used_rect := Rect2()

## 0 with the pond big (laying out), 1 with the slate big (play).
var _swap := 0.0
var _swap_tw: Tween
var _big := Rect2()
var _small := Rect2()
var _pond_base: ArrayMesh
var _slate_base: ArrayMesh
var _pond_live: ArrayMesh
var _slate_live: ArrayMesh
var _tally: ArrayMesh
var _hulls: Array = []
var _shown: Array = []
var _dirty := true
var _t := 0.0
## Something on the live meshes moves until then.
var _busy_until := 0.0
var _font: Font
var _fx: Node2D
var _run := 0
## When each mark appeared, by square: the pond's and the slate's.
var _born := [{}, {}]
## When each of the player's boats went under, and each chalked outline came.
var _sank := [{}, {}]
var _enter_at := -1.0
## The pebble in the air over the pond: {c, at, r, boat}; empty when none.
var _pebble := {}
## The square thrown at on the slate and not answered yet, -1 none.
var _aim := -1
var _hint := -1
## The square under the finger on the slate, -1 none.
var _over := -1
## The boat held while laying out: {i, k, from, at, slid, ok}.
var _drag := {}
## A boat shaking its head: [index, when].
var _shake := [-1, -10.0]
## The other player's boats shown at the end, chalked on the slate.
var _fleet: Array = []
var _outcome := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still else Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	resized.connect(_layout)
	if not still:
		_fx = Fx2D.new()
		add_child(_fx)
	_layout()

# --- setting up ---

## Two fresh grids. `lay` opens with the pond big and its boats movable;
## `enter` slides the boats in and says `settled` once they are down.
func setup(the_pond: RefCounted, the_slate: RefCounted, lay := false, enter := false) -> void:
	_run += 1
	pond = the_pond
	slate = the_slate
	laying = lay
	Motion.stop(_swap_tw)
	_swap = 0.0 if lay else 1.0
	_born = [{}, {}]
	_sank = [{}, {}]
	_pebble = {}
	_aim = -1
	_hint = -1
	_over = -1
	_drag = {}
	_fleet = []
	_outcome = ""
	_enter_at = -1.0
	if enter and not Motion.reduce and not still:
		_enter_at = _t
		_busy(0.8)
		_cue("enter")
		_after(0.6, func() -> void: settled.emit())
	elif enter:
		_after(0.05, func() -> void: settled.emit())
	_touch()

## The boats are laid: the slate comes down to the thumb and the pond goes up
## small. Says `settled` when they have changed places.
func begin_play() -> void:
	laying = false
	_drag = {}
	Motion.stop(_swap_tw)
	if Motion.reduce or still:
		_swap = 1.0
		_touch()
		_after(0.05, func() -> void: settled.emit())
		return
	_cue("fold")
	_swap_tw = create_tween()
	_swap_tw.tween_method(func(v: float) -> void:
		_swap = v
		_touch(), _swap, 1.0, SWAP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_swap_tw.tween_callback(func() -> void: settled.emit())

## The player's pebble is on its way to `c` of the other pond.
func aim(c: int) -> void:
	_aim = c
	_hint = -1
	_over = -1
	_busy(60.0)
	_cue("throw")

## The answer to the pebble at `c`, already written on the slate: the mark is
## chalked in, and `settled` follows.
func answer(c: int, r: int, boat := -1) -> void:
	_aim = -1
	_born[1][c] = _t
	if r == Rules.SUNK:
		_sank[1][boat] = _t
	_busy(1.2)
	var at := point_of(1, c)
	if r == Rules.MISS:
		_cue("miss")
		_puff(at, CHALK, 4)
	else:
		_cue("sunk" if r == Rules.SUNK else "hit")
		_puff(at, CHALK_HIT, 8 if r == Rules.SUNK else 5)
		if r == Rules.SUNK and _fx != null:
			_fx.sparkle(at, HINT)
	_touch()
	_after(_watch(r), func() -> void: settled.emit())

## The other player's pebble at `c` of the pond, already answered by the
## rules: it falls, lands, and `settled` follows.
func strike(c: int, r: int, boat := -1) -> void:
	var fall := 0.0 if Motion.reduce else FALL
	_pebble = {"c": c, "at": _t, "r": r, "boat": boat, "fall": fall}
	_busy(fall + 1.4)
	_cue("lob")
	_after(fall, func() -> void:
		_pebble = {}
		_born[0][c] = _t
		var at := point_of(0, c)
		if r == Rules.MISS:
			_cue("splash")
			_puff(at, Pal.WATER_HI, 6)
		else:
			_cue("glug" if r == Rules.SUNK else "knock")
			_puff(at, PEG, 6)
			_shake = [boat, _t]
			if r == Rules.SUNK:
				_sank[0][boat] = _t
		_touch())
	_after(fall + _watch(r), func() -> void: settled.emit())

func _watch(r: int) -> float:
	if Motion.reduce:
		return 0.12
	return WATCH_SUNK if r == Rules.SUNK else WATCH

## The bulb's square on the slate, -1 to take it away.
func set_hint(c: int) -> void:
	_hint = c
	if c >= 0 and _fx != null:
		_fx.ring(point_of(1, c), _unit(1) * 0.6, HINT)
		_fx.sparkle(point_of(1, c), HINT)
	_touch()

## The end: the other player's boats still afloat are chalked on the slate
## (`fleet` empty when they are not known).
func finish(outcome: String, fleet: Array = []) -> void:
	_outcome = outcome
	_fleet = fleet
	_aim = -1
	_hint = -1
	_over = -1
	_busy(1.0)
	_touch()

## The room beside the small grid: where the screen puts what it has to say
## (the buttons while laying out; the board draws the boats left to sink).
func panel_rect() -> Rect2:
	return Rect2(_small.end.x + GAP, _small.position.y, _big.end.x - _small.end.x - GAP, _small.size.y)

## The middle of square `c` of the pond (0) or the slate (1), in this control:
## where the board's own effects go, and a harness's finger.
func point_of(grid: int, c: int) -> Vector2:
	var at := Rules.xy(c)
	return _xf(grid) * (Vector2(at.x + 0.5 + BORDER, at.y + 0.5 + BORDER) * U)

# --- layout ---

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if still:
		# Side by side, the pond first.
		var h := floorf(minf(size.y, (size.x - GAP) * 0.5))
		var left := (size.x - 2.0 * h - GAP) * 0.5
		_small = Rect2(left, (size.y - h) * 0.5, h, h)
		_big = Rect2(left + h + GAP, (size.y - h) * 0.5, h, h)
		used_rect = _small.merge(_big)
	else:
		var b := floorf(minf(size.x, (size.y - GAP) / (1.0 + SMALL)))
		var s := floorf(b * SMALL)
		var top := floorf((size.y - b - s - GAP) * 0.5)
		var left := floorf((size.x - b) * 0.5)
		_small = Rect2(left, top, s, s)
		_big = Rect2(left, top + s + GAP, b, b)
		used_rect = Rect2(left, top, b, b + s + GAP)
	_dirty = true
	queue_redraw()

## Where grid `g` (0 the pond, 1 the slate) is drawn now, from the meshes'
## space to this control's.
func _xf(g: int) -> Transform2D:
	var k := _swap if g == 0 else 1.0 - _swap
	if still:
		k = 1.0 if g == 0 else 0.0
	var at := _big.position.lerp(_small.position, k)
	var side := lerpf(_big.size.x, _small.size.x, k)
	return Transform2D(0.0, Vector2.ONE * (side / SIDE), 0.0, at)

## A square's side on the screen for grid `g`.
func _unit(g: int) -> float:
	return _xf(g).get_scale().x * U

## The square of grid `g` under `p`, as a point (off the grid allowed).
func _square_at(g: int, p: Vector2) -> Vector2i:
	var q := _xf(g).affine_inverse() * p / U - Vector2.ONE * BORDER
	return Vector2i(floori(q.x), floori(q.y))

static func _on_grid(q: Vector2i) -> bool:
	return q.x >= 0 and q.y >= 0 and q.x < Rules.N and q.y < Rules.N

# --- time ---

func _process(delta: float) -> void:
	_t += delta
	if _t < _busy_until or not _drag.is_empty():
		_dirty = true
		queue_redraw()

func _busy(seconds: float) -> void:
	_busy_until = maxf(_busy_until, _t + seconds)

func _touch() -> void:
	_dirty = true
	queue_redraw()

## The builder's mesh, or none when nothing was drawn into it (a mesh with no
## vertices is an error, and a slate begins empty).
static func _mesh_of(b: Face.Builder) -> ArrayMesh:
	return null if b.verts.is_empty() else b.mesh()

func _after(seconds: float, what: Callable) -> void:
	var run := _run
	if not is_inside_tree():
		return
	get_tree().create_timer(maxf(seconds, 0.01)).timeout.connect(func() -> void:
		if run == _run and is_inside_tree():
			what.call())

func _cue(cue_name: String, pitch := 1.0) -> void:
	if _fx != null:
		_fx.cue(cue_name, pitch)

func _puff(at: Vector2, colour: Color, n: int) -> void:
	if _fx != null and not Motion.reduce:
		_fx.puff(at, colour, n)

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if still or not interactive:
		return
	var press := false
	var release := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		at = event.position
	else:
		return
	accept_event()
	if laying:
		if press:
			_lift(at)
		elif release:
			_drop()
		else:
			_carry(at)
	elif _aim < 0:
		var q := _square_at(1, at)
		var c := Rules.cell(q.x, q.y) if _on_grid(q) else -1
		if release:
			_over = -1
			if c >= 0:
				if slate.marks[c] == Rules.UNKNOWN:
					aimed.emit(c)
				else:
					refused.emit("tried")
					_cue("refused")
		elif c != _over:
			_over = c
			if c >= 0 and slate.marks[c] == Rules.UNKNOWN:
				_cue("tick")
		_touch()

func _lift(p: Vector2) -> void:
	var q := _square_at(0, p)
	if not _on_grid(q):
		return
	var i: int = pond.boat_at(Rules.cell(q.x, q.y))
	if i < 0:
		return
	var b: Vector3i = pond.boats[i]
	var k := (q.x - b.x) + (q.y - b.y)
	_drag = {"i": i, "k": k, "from": b, "at": b, "slid": false, "ok": true, "sq": q}
	_cue("lift")
	_touch()

func _carry(p: Vector2) -> void:
	if _drag.is_empty():
		return
	var q := _square_at(0, p)
	if q == _drag.sq:
		return
	_drag.sq = q
	var i: int = _drag.i
	var from: Vector3i = _drag.from
	var d := Rules.step(from.z)
	var n: int = Rules.FLEET[i]
	var bow := q - d * int(_drag.k)
	# Held to the pond: a boat carried past the edge stops at it.
	bow.x = clampi(bow.x, 0, Rules.N - 1 - (n - 1) * d.x)
	bow.y = clampi(bow.y, 0, Rules.N - 1 - (n - 1) * d.y)
	var to := Vector3i(bow.x, bow.y, from.z)
	if to == _drag.at:
		return
	_drag.at = to
	_drag.slid = true
	_drag.ok = Rules.free_for(pond.boats, i, to)
	_cue("tick")
	_touch()

func _drop() -> void:
	if _drag.is_empty():
		return
	var i: int = _drag.i
	var from: Vector3i = _drag.from
	var to: Vector3i = _drag.at
	if not bool(_drag.slid):
		to = _turned(i, from, int(_drag.k))
	_drag = {}
	if to == from or to.x < 0 or not Rules.free_for(pond.boats, i, to):
		_shake = [i, _t]
		_busy(0.4)
		_cue("refused")
		refused.emit("room")
	else:
		pond.boats[i] = to
		_cue("turn" if to.z != from.z else "place")
		moved.emit()
	_touch()

## Boat `i` turned a quarter about the square it was touched on (`k` squares
## from its bow), or about the nearest square of it that leaves it room; x < 0
## when there is none.
func _turned(i: int, b: Vector3i, k: int) -> Vector3i:
	var n: int = Rules.FLEET[i]
	var d := Rules.step(b.z)
	var pivot := Vector2i(b.x, b.y) + d * k
	var nd := Rules.step(1 - b.z)
	# Try the turn with each of its squares on the pivot, the touched one first.
	var order := [k]
	for j in n:
		if j != k:
			order.append(j)
	for clamped: bool in [false, true]:
		for j: int in order:
			var bow := pivot - nd * j
			if clamped:
				bow.x = clampi(bow.x, 0, Rules.N - 1 - (n - 1) * nd.x)
				bow.y = clampi(bow.y, 0, Rules.N - 1 - (n - 1) * nd.y)
			var to := Vector3i(bow.x, bow.y, 1 - b.z)
			if Rules.free_for(pond.boats, i, to):
				return to
	return Rules.HIDDEN

# --- drawing ---

func _draw() -> void:
	if pond == null or _big.size.x <= 0.0:
		return
	if _pond_base == null:
		_pond_base = _build_base(false)
		_slate_base = _build_base(true)
		for i in Rules.FLEET.size():
			_hulls.append(_build_hull(i))
	if _dirty:
		_dirty = false
		_pond_live = _build_pond_live()
		_slate_live = _build_slate_live()
		_tally = null if still else _build_tally()
	_shown = [_pond_base, _slate_base, _pond_live, _slate_live, _tally]
	if _tally != null:
		draw_mesh(_tally, null)
	# The grid coming down to the thumb is drawn over the one going up.
	for g: int in ([1, 0] if _swap < 0.5 and not still else [0, 1]):
		var xf := _xf(g)
		draw_mesh(_pond_base if g == 0 else _slate_base, null, xf)
		if g == 1:
			_draw_letters(xf)
		var live := _pond_live if g == 0 else _slate_live
		if live != null:
			draw_mesh(live, null, xf)

## The slate's letters down its side and numbers across its top, in chalk.
func _draw_letters(xf: Transform2D) -> void:
	if xf.get_scale().x * U < 30.0:
		return
	draw_set_transform_matrix(xf)
	var fs := int(U * 0.3)
	var ink := Color(CHALK, 0.6)
	var edge := (WOOD_W + (BORDER - WOOD_W) * 0.5) * U
	for i in Rules.N:
		var mid := (BORDER + i + 0.5) * U
		var num := str(i + 1)
		var w := _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(mid - w * 0.5, edge + fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		var letter := LETTERS[i]
		var w2 := _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(edge - w2 * 0.5, mid + fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## A grid's box: the wooden frame, the water or the slate inside it, and the
## lines. In the meshes' space, SIDE square.
func _build_base(is_slate: bool) -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if is_slate else 3
	var all := Vector2.ONE * SIDE
	Scenery.soft_disc(b, all * 0.5 + Vector2(0.0, U * 0.22), SIDE * 0.54, SIDE * 0.54, Color(0.2, 0.1, 0.04, 0.2))
	b.fan(Face.Builder.round_rect(Vector2(0.0, U * 0.08), all, U * 0.34), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(Vector2.ZERO, all - Vector2(0.0, U * 0.02), U * 0.34), WOOD)
	b.stroke(Face.Builder.round_rect(Vector2.ONE * U * 0.045, all - Vector2.ONE * U * 0.11, U * 0.3), U * 0.035, Color(WOOD_LIT, 0.8), true)
	var w := WOOD_W * U
	var inner := all - Vector2.ONE * 2.0 * w
	b.fan(Face.Builder.round_rect(Vector2.ONE * w, inner, U * 0.2), SLATE if is_slate else WATER_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(w, w + U * 0.07), inner - Vector2(0.0, U * 0.07), U * 0.2), SLATE_LIT if is_slate else WATER)
	var o := BORDER * U
	if is_slate:
		# Chalk that was wiped away, never quite.
		for k in 9:
			var at := Vector2(rng.randf_range(o, SIDE - o), rng.randf_range(o, SIDE - o))
			Scenery.soft_disc(b, at, rng.randf_range(U * 0.9, U * 1.8), rng.randf_range(U * 0.3, U * 0.6), Color(1, 1, 1, 0.035))
	else:
		# Light on the water, and a few ripples lying across it.
		Scenery.soft_disc(b, Vector2(SIDE * 0.34, SIDE * 0.3), SIDE * 0.3, SIDE * 0.22, Color(1, 1, 1, 0.1))
		for k in 16:
			var at := Vector2(rng.randf_range(o, SIDE - o - U * 0.8), rng.randf_range(o, SIDE - o))
			var len := rng.randf_range(U * 0.35, U * 0.8)
			var pts := PackedVector2Array()
			for s in 7:
				pts.append(at + Vector2(len * s / 6.0, sin(s * 1.1) * U * 0.035))
			b.stroke(pts, U * 0.03, Color(1, 1, 1, 0.16))
	var line := CHALK_LINE if is_slate else WATER_LINE
	for i in Rules.N + 1:
		var p := o + i * U
		var wide := U * (0.035 if i == 0 or i == Rules.N else 0.022)
		b.stroke(PackedVector2Array([Vector2(p, o), Vector2(p, SIDE - o)]), wide, line)
		b.stroke(PackedVector2Array([Vector2(o, p), Vector2(SIDE - o, p)]), wide, line)
	return b.mesh()

## A boat's outline, its bow's square at the origin and the rest along +x.
static func hull_points(i: int, grow := 0.0) -> PackedVector2Array:
	var n: int = Rules.FLEET[i]
	var x0 := -0.4 * U - grow
	var x1 := (n - 1) * U + 0.44 * U + grow
	var w := 0.32 * U + grow
	var turn := 0.16 * U
	var nose := 0.62 * U
	var pts := PackedVector2Array()
	pts.append_array(Face.Builder.bezier2(Vector2(x0, 0.0), Vector2(x0, -w), Vector2(x0 + turn, -w), 6))
	pts.append_array(Face.Builder.bezier2(Vector2(x1 - nose, -w), Vector2(x1 - 0.14 * U, -w), Vector2(x1, 0.0), 10))
	pts.append_array(Face.Builder.bezier2(Vector2(x1, 0.0), Vector2(x1 - 0.14 * U, w), Vector2(x1 - nose, w), 10).slice(1))
	pts.append_array(Face.Builder.bezier2(Vector2(x0 + turn, w), Vector2(x0, w), Vector2(x0, 0.0), 6).slice(0, 6))
	return pts

## A wooden toy boat from above: the hull and its lit deck, a line of paint
## round the deck in the boat's own colour, and a peg hole a square.
func _build_hull(i: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var n: int = Rules.FLEET[i]
	b.fan(hull_points(i), HULL_RIM)
	var deck := PackedVector2Array()
	for p in hull_points(i, -0.055 * U):
		deck.append(p + Vector2(-0.01 * U, -0.02 * U))
	b.fan(deck, HULL)
	b.stroke(hull_points(i, -0.13 * U), 0.05 * U, PAINT[i], true)
	# the grain along the deck
	b.stroke(PackedVector2Array([Vector2(-0.2 * U, -0.07 * U), Vector2((n - 1) * U + 0.05 * U, -0.07 * U)]), 0.018 * U, Color(HULL_RIM, 0.3))
	b.stroke(PackedVector2Array([Vector2(-0.12 * U, 0.08 * U), Vector2((n - 1) * U - 0.1 * U, 0.08 * U)]), 0.018 * U, Color(HULL_RIM, 0.3))
	for k in n:
		b.disc(Vector2(k * U, 0.0), 0.085 * U, HOLE)
		b.disc(Vector2(k * U + 0.012 * U, 0.02 * U), 0.06 * U, Color(0.2, 0.12, 0.06, 0.5))
	return b.mesh()

## From a boat's own space to a grid's: its bow's square, turned south when
## it runs down the pond.
static func _boat_xf(boat: Vector3i, scale_by := 1.0, slip := Vector2.ZERO) -> Transform2D:
	var at := Vector2(boat.x + 0.5 + BORDER, boat.y + 0.5 + BORDER) * U + slip
	return Transform2D(PI * 0.5 if boat.z == 1 else 0.0, Vector2.ONE * scale_by, 0.0, at)

static func _mid(c: int) -> Vector2:
	var at := Rules.xy(c)
	return Vector2(at.x + 0.5 + BORDER, at.y + 0.5 + BORDER) * U

func _build_pond_live() -> ArrayMesh:
	var b := Face.Builder.new()
	var held: int = _drag.i if not _drag.is_empty() else -1
	var flying: int = _pebble.c if not _pebble.is_empty() else -1
	# The boats, the held one last.
	var order := range(Rules.FLEET.size())
	if held >= 0:
		order.erase(held)
		order.append(held)
	for i: int in order:
		var boat: Vector3i = pond.boats[i]
		if boat.x < 0:
			continue
		var grow := 1.0
		var slip := Vector2.ZERO
		if _enter_at >= 0.0:
			var e := _t - _enter_at - 0.07 * i
			if e <= 0.0:
				continue
			grow = Motion.pop_in_scale(e).x
		if i == held:
			boat = _drag.at
			grow = Motion.LIFT_SCALE
		if int(_shake[0]) == i:
			slip = Vector2(Motion.shiver_offset(_t - float(_shake[1]), U * 0.06, 0.3), 0.0)
		var under: bool = pond.sunk[i] and not (flying >= 0 and int(_pebble.boat) == i)
		var xf := _boat_xf(boat, grow, slip)
		if under:
			# Going down: it settles lower and the water closes over it.
			var u := clampf((_t - float(_sank[0].get(i, -10.0))) / 0.7, 0.0, 1.0)
			b.append(_hulls[i], xf, Color.WHITE.lerp(SUNKEN, u))
			if u < 1.0:
				for k in 3:
					var at := xf * Vector2((Rules.FLEET[i] - 1) * U * (0.2 + 0.3 * k), 0.0)
					b.stroke(Face.Builder.ring(at, U * (0.1 + 0.5 * u), U * (0.1 + 0.5 * u)), U * 0.04, Color(1, 1, 1, 0.6 * (1.0 - u)), true)
		else:
			var lift := U * (0.16 if i == held else 0.06)
			var shade := PackedVector2Array()
			for p in hull_points(i):
				shade.append(xf * p + Vector2(lift * 0.5, lift))
			b.fan(shade, SHADE)
			b.append(_hulls[i], xf)
			if i == held and not bool(_drag.ok):
				# No room here: said by a ring and a hatch, not by a colour of the boat.
				var ring := PackedVector2Array()
				for p in hull_points(i, 0.09 * U):
					ring.append(xf * p)
				b.stroke(ring, U * 0.06, Pal.BAD, true)
				for k in Rules.FLEET[i]:
					var m := xf * Vector2(k * U, 0.0)
					b.stroke(PackedVector2Array([m + Vector2(-0.2, -0.2) * U, m + Vector2(0.2, 0.2) * U]), U * 0.07, Pal.BAD)
					b.stroke(PackedVector2Array([m + Vector2(0.2, -0.2) * U, m + Vector2(-0.2, 0.2) * U]), U * 0.07, Pal.BAD)
	# What has landed: a ripple where a pebble found water, a peg where it
	# found a boat.
	for c in Rules.CELLS:
		var mark: int = pond.marks[c]
		if mark == Rules.UNKNOWN or c == flying:
			continue
		var m := _mid(c)
		var age := _t - float(_born[0].get(c, -10.0))
		var pop := Motion.pop_in_scale(age).x if age < Motion.POP_IN else 1.0
		if mark == Rules.MISS:
			b.stroke(Face.Builder.ring(m, U * 0.2 * pop, U * 0.2 * pop), U * 0.04, Color(1, 1, 1, 0.75), true)
			b.disc(m, U * 0.06 * pop, Color(1, 1, 1, 0.75))
			if age < SPLASH:
				var u := age / SPLASH
				b.stroke(Face.Builder.ring(m, U * (0.2 + 0.5 * u), U * (0.2 + 0.5 * u)), U * 0.05, Color(1, 1, 1, 0.8 * (1.0 - u)), true)
		else:
			b.disc(m + Vector2(0.03, 0.06) * U, U * 0.2 * pop, Color(0.25, 0.1, 0.05, 0.3))
			b.disc(m, U * 0.2 * pop, PEG)
			b.disc(m + Vector2(-0.05, -0.06) * U, U * 0.1 * pop, PEG_LIT)
			if age < SPLASH:
				var u := age / SPLASH
				b.stroke(Face.Builder.ring(m, U * (0.25 + 0.4 * u), U * (0.25 + 0.4 * u)), U * 0.06, Color(PEG_LIT, 0.8 * (1.0 - u)), true)
	if flying >= 0:
		var u := clampf((_t - float(_pebble.at)) / maxf(float(_pebble.fall), 0.001), 0.0, 1.0)
		var m := _mid(flying)
		var e := u * u
		Scenery.soft_disc(b, m + Vector2(0.04, 0.08) * U, U * 0.3 * (1.6 - 0.6 * e), U * 0.3 * (1.6 - 0.6 * e), Color(0.05, 0.15, 0.25, 0.3 * e))
		var at := m + Vector2(-0.5, -1.7) * U * (1.0 - e)
		var r := U * 0.19 * (2.3 - 1.3 * e)
		b.disc(at, r, PEBBLE)
		b.disc(at + Vector2(-0.25, -0.3) * r, r * 0.5, PEBBLE_LIT)
	return _mesh_of(b)

func _build_slate_live() -> ArrayMesh:
	var b := Face.Builder.new()
	# The square under the finger: its row and its column.
	if _over >= 0:
		var at := Rules.xy(_over)
		var o := BORDER * U
		var open: bool = slate.marks[_over] == Rules.UNKNOWN
		var band := Color(1, 1, 1, 0.1 if open else 0.05)
		b.fan(PackedVector2Array([Vector2(o, o + at.y * U), Vector2(SIDE - o, o + at.y * U), Vector2(SIDE - o, o + (at.y + 1) * U), Vector2(o, o + (at.y + 1) * U)]), band)
		b.fan(PackedVector2Array([Vector2(o + at.x * U, o), Vector2(o + (at.x + 1) * U, o), Vector2(o + (at.x + 1) * U, SIDE - o), Vector2(o + at.x * U, SIDE - o)]), band)
		if open:
			b.stroke(Face.Builder.round_rect(Vector2(o + at.x * U, o + at.y * U) + Vector2.ONE * U * 0.06, Vector2.ONE * U * 0.88, U * 0.14), U * 0.06, CHALK, true)
	# Boats said sunk, and at the end the ones never found: their outlines.
	for i in Rules.FLEET.size():
		var boat: Vector3i = slate.boats[i]
		var found := boat.x >= 0
		if not found and i < _fleet.size():
			boat = _fleet[i]
		if boat.x < 0:
			continue
		var age := _t - float(_sank[1].get(i, -10.0))
		var grow := 1.0 + 0.12 * Motion.flash_level(age) if found else 1.0
		var xf := _boat_xf(boat, grow)
		var pts := PackedVector2Array()
		for p in hull_points(i):
			pts.append(xf * p)
		if found:
			b.fan(pts, Color(1, 1, 1, 0.1))
			b.stroke(pts, U * 0.055, CHALK, true)
		else:
			# Never found: dashed, so it is not read as one that was sunk.
			for k in range(0, pts.size() - 1, 2):
				b.stroke(PackedVector2Array([pts[k], pts[k + 1]]), U * 0.05, Color(CHALK, 0.75))
	for c in Rules.CELLS:
		var mark: int = slate.marks[c]
		if mark == Rules.UNKNOWN:
			continue
		var m := _mid(c)
		var age := _t - float(_born[1].get(c, -10.0))
		var pop := Motion.pop_in_scale(age).x if age < Motion.POP_IN else 1.0
		if mark == Rules.MISS:
			b.stroke(Face.Builder.ring(m, U * 0.24 * pop, U * 0.24 * pop), U * 0.07, Color(CHALK, 0.9), true)
		else:
			var r := U * 0.25 * pop
			b.stroke(PackedVector2Array([m + Vector2(-r, -r), m + Vector2(r, r)]), U * 0.085, CHALK_HIT)
			b.stroke(PackedVector2Array([m + Vector2(r, -r), m + Vector2(-r, r)]), U * 0.085, CHALK_HIT)
	if _aim >= 0:
		# A pebble thrown and not yet heard: a chalk dot that breathes.
		var m := _mid(_aim)
		var beat := 0.5 + 0.5 * sin(_t * 9.0)
		b.disc(m, U * (0.1 + 0.05 * beat), Color(CHALK, 0.9))
		b.stroke(Face.Builder.ring(m, U * (0.22 + 0.1 * beat), U * (0.22 + 0.1 * beat)), U * 0.03, Color(CHALK, 0.5 * (1.0 - beat)), true)
	if _hint >= 0 and slate.marks[_hint] == Rules.UNKNOWN:
		var m := _mid(_hint)
		b.stroke(Face.Builder.ring(m, U * 0.34, U * 0.34), U * 0.07, HINT, true)
		b.disc(m, U * 0.08, HINT)
	return _mesh_of(b)

## Beside the small grid while playing: the five boats the player is after,
## as chalk on a strip of slate -- an outline while afloat, filled and crossed
## out once sunk.
func _build_tally() -> ArrayMesh:
	var b := Face.Builder.new()
	var room := panel_rect()
	if laying or _swap < 1.0 or room.size.x < 60.0:
		return _mesh_of(b)
	var rows := Rules.FLEET.size()
	var top := room.position.y + room.size.y * 0.2
	var pitch := (room.end.y - top - room.size.y * 0.05) / rows
	var c := minf(pitch * 0.62, room.size.x / 6.2)
	var plate := Rect2(room.position.x, top - pitch * 0.12, room.size.x, room.end.y - top + pitch * 0.12)
	b.fan(Face.Builder.round_rect(plate.position + Vector2(0.0, 5.0), plate.size, 22.0), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(plate.position, plate.size, 22.0), WOOD)
	b.fan(Face.Builder.round_rect(plate.position + Vector2.ONE * 9.0, plate.size - Vector2.ONE * 18.0, 15.0), SLATE_LIT)
	for i in rows:
		var n: int = Rules.FLEET[i]
		var mid := top + pitch * (i + 0.5) - pitch * 0.06
		var left := room.position.x + (room.size.x - (n - 1) * c) * 0.5
		var xf := Transform2D(0.0, Vector2.ONE * (c / U), 0.0, Vector2(left, mid))
		var pts := PackedVector2Array()
		for p in hull_points(i):
			pts.append(xf * p)
		if slate.sunk[i]:
			b.fan(pts, Color(CHALK, 0.3))
			b.stroke(pts, 3.0, Color(CHALK, 0.6), true)
			var a := xf * Vector2(-0.5 * U, 0.0)
			var z := xf * Vector2((n - 1) * U + 0.55 * U, 0.0)
			b.stroke(PackedVector2Array([a, z]), 5.0, CHALK_HIT)
		else:
			b.stroke(pts, 3.5, CHALK, true)
	return _mesh_of(b)
