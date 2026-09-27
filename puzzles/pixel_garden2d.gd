extends "res://core/puzzle_base.gd"

## Pixel Garden as a flat board: a pegboard in a wooden tray on the garden
## table, the day's little picture in the corner of the card, and a kit of
## beads in the picture's colours. Pick a colour, tap or drag across the pegs
## to seat beads, and copy the picture peg for peg. The rules live in
## puzzles/pixel_garden_state.gd, which this only draws.
##
## The card holds everything, Quilt's way: the header (the picture, its name,
## the kit's chips with how many beads each has left, and a bar of beads
## seated) over the pegboard, so the tray is a row of the card and not a row
## of the screen, and the actions row (Reset, Check) stands under it.
##
## **The iron is this board's signature.** A finished bead picture is ironed:
## on the solve the beads hop in the family's wave, then a warm band crosses
## the board along the diagonal, each bead's hole closing to a dimple under
## it with a gloss coming up, and the bare pegs fade away behind it, so the
## picture is left standing as one fused thing.
##
## How it is drawn. Four meshes and some text:
##   table -- the card's table, the tray and the board's face, and every
##            peg. Built once a layout (and while the win clears the pegs).
##   head  -- the picture, the chips and the bar. Rebuilt when the kit or
##            the chosen colour changes, or a chip moves.
##   bands -- every resting bead, in bands of BAND rows, one mesh a band,
##            rebuilt only when the look of one of its pegs changes
##            (Hedgehogs' `_band_looks`), so seating a bead redraws its own
##            few rows and not two hundred beads.
##   live  -- every peg with something moving on it (a bead popping in or
##            out, a refusal's shiver, the win), Check's halos, the hint's
##            ring and the iron's band. Rebuilt only while something moves.
## The beads are ui/faces/bead.gd, which the menu card draws too.
##
## Spec: docs/superpowers/specs/2026-09-27-pixel-garden-flat-design.md.

const State = preload("res://puzzles/pixel_garden_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Bead = preload("res://ui/faces/bead.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Rings = preload("res://puzzles/rings2d.gd")

# --- the card ---
const PAD := 30.0
## The header over the board: the picture is HEAD square, and the chips, the
## name and the bar stand beside it.
const HEAD := 212.0
const HEAD_GAP := 26.0
## The tray's rim round the board, and the board's own margin round its pegs.
const RIM := 18.0
const MARGIN := 0.35
const CARD_RADIUS := 32.0
const BOARD_RADIUS := 22.0
## A chip: its box, the bead on it, the gap between two, and how far the
## chosen one stands up.
const CHIP := Vector2(78.0, 124.0)
const CHIP_GAP := 12.0
const CHIP_BEAD := 64.0
const CHIP_RISE := 8.0
const NAME_SIZE := 34
const COUNT_SIZE := 30
const BAR_H := 20.0
## The still beads are cut into bands of this many rows.
const BAND := 4

# --- the motion ---
## How long the held picture takes to grow over the board, and how much of
## the board it covers.
const PEEK_TIME := 0.18
const PEEK_COVER := 0.86
## A bead is seated, not popped: it fades in held above its peg (seen from
## straight above, nearer reads as bigger and higher, its shade left on the
## board), falls onto the peg over the first SEAT_FALL of SEAT_TIME, and
## snaps down with a small press -- the peg shows up its hole only once it
## is home. Lifting runs the other way over LIFT_TIME: up, nearer, gone.
const SEAT_TIME := 0.24
const SEAT_FALL := 0.62
const SEAT_HIGH := 0.34
const SEAT_NEAR := 0.16
const SEAT_PRESS := 0.06
const LIFT_TIME := 0.16
## The win: the solve wave, then the iron crosses along the diagonal, IRON_STEP
## a diagonal, each bead fusing over IRON_TIME, and the bare pegs fade out
## over PEGS_GONE once it has passed.
const IRON_AT := 0.55
const IRON_STEP := 0.045
const IRON_TIME := 0.3
const PEGS_GONE := 0.5
const WIN_WAIT := 1.0
const HINTS := State.HINTS
## The toast: Knight's and Rings' measure for measure.
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 40.0

var _state = State.new()
var fx: Node2D
## The chosen colour: an index into the day's colours.
var brush := 0

## Per peg: when its bead arrived, when a refusal shook it, and when anything
## on it stops moving.
var _arrive_at := PackedFloat64Array()
var _drop := PackedByteArray()
var _shake_at := PackedFloat64Array()
var _until := PackedFloat64Array()
## Beads the state has already forgotten, shrinking out: {peg, colour, at}.
var _leaving: Array = []
## Pegs Check pointed at: their halos hold until the next move.
var _halo := {}
var _halo_at := -100.0
var _moving := {}
var _rings: Array = []
## A chip's moments: when it was chosen, when a refusal shook it.
var _chip_at := PackedFloat64Array()
var _chip_shake := PackedFloat64Array()
var _chip_rects: Array[Rect2] = []
var _bar_bump := -100.0

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
var _cell := 0.0
var _grid := Vector2.ZERO
var _board := Rect2()
var _thumb := Rect2()
var _head_top := 0.0
var _right := Rect2()
var _table: ArrayMesh
var _head: ArrayMesh
var _head_key := ""
var _thumb_mesh: ArrayMesh
var _bands: Array = []
var _band_looks: Array = []
var _live: ArrayMesh
var _shown: Array = []

# --- the gesture ---
var _stroking := false
var _erase := false
var _refused := false
var _last := -1
var _painted := {}
var _peek := false
var _peek_at := -100.0
var _press_finger := -2
var _hinting := false
var _toast := ""
var _toast_arg := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

func puzzle_id() -> String: return "pixelgarden"
func title() -> String: return "Pixel Garden"

func rules() -> String:
	return tr("PG_RULES")

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.setup(rng, difficulty)
	var n: int = _state.size()
	for a in [_arrive_at, _shake_at, _until]:
		a.resize(n)
		a.fill(-100.0)
	_drop.resize(n)
	_drop.fill(0)
	_chip_at.resize(_state.names.size())
	_chip_at.fill(-100.0)
	_chip_shake.resize(_state.names.size())
	_chip_shake.fill(-100.0)
	_leaving = []
	_halo = {}
	_moving = {}
	_rings = []
	_bands = []
	_solved_at = -1.0
	_clear_gesture()
	_toast = ""
	_toast_at = -100.0
	# The first colour the picture uses most of is in hand to begin with.
	brush = 0
	for k in _state.need.size():
		if _state.need[k] > _state.need[brush]:
			brush = k
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP)
	_table = null
	_thumb_mesh = null
	_head = null
	_layout()
	fx.cue("enter")

# --- layout ---

func _cell_for(available: float) -> float:
	if _state.n == 0:
		return 0.0
	var span := float(_state.n) + 2.0 * MARGIN
	return maxf(0.0, minf((size.x - 2.0 * PAD - 2.0 * RIM) / span,
		(available - 2.0 * PAD - HEAD - HEAD_GAP - 2.0 * RIM) / span))

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * (float(_state.n) + 2.0 * MARGIN) + 2.0 * RIM + 2.0 * PAD + HEAD + HEAD_GAP)

func card_centred() -> bool:
	return true

func _layout() -> void:
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var face := _cell * (float(_state.n) + 2.0 * MARGIN)
	var tall := minf(size.y, face + 2.0 * RIM + 2.0 * PAD + HEAD + HEAD_GAP)
	var top := (size.y - tall) * 0.5 + PAD
	_head_top = top
	var span := maxf(face + 2.0 * RIM, minf(size.x - 2.0 * PAD, 940.0))
	var left := size.x * 0.5 - span * 0.5
	_thumb = Rect2(left, top, HEAD, HEAD)
	_right = Rect2(left + HEAD + 26.0, top, span - HEAD - 26.0, HEAD)
	var board_top := top + HEAD + HEAD_GAP
	_board = Rect2(size.x * 0.5 - face * 0.5 - RIM, board_top, face + 2.0 * RIM, face + 2.0 * RIM)
	_grid = _board.position + Vector2.ONE * (RIM + MARGIN * _cell)
	_place_chips()
	_table = null
	_thumb_mesh = null
	_head = null
	_bands = []
	_refresh()

## The chips stand in a row under the picture's name, centred in the room
## beside the picture, closing up when a day has many colours.
func _place_chips() -> void:
	_chip_rects = []
	var k: int = _state.names.size()
	if k == 0:
		return
	var gap := minf(CHIP_GAP, maxf(2.0, (_right.size.x - CHIP.x * k) / maxf(1.0, k - 1)))
	var chip := Vector2(minf(CHIP.x, (_right.size.x - gap * (k - 1)) / k), CHIP.y)
	var run := chip.x * k + gap * (k - 1)
	var x0 := _right.position.x + (_right.size.x - run) * 0.5
	var y := _right.position.y + 50.0
	for i in k:
		_chip_rects.append(Rect2(Vector2(x0 + i * (chip.x + gap), y), chip))

func _centre(c: int) -> Vector2:
	return _grid + (Vector2(c % _state.n, c / _state.n) + Vector2(0.5, 0.5)) * _cell

## Control-local point over the centre of the peg at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.n + c)

func _peg_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var v := (local - _grid) / _cell
	var x := int(floor(v.x))
	var y := int(floor(v.y))
	if x < 0 or y < 0 or x >= _state.n or y >= _state.n:
		return -1
	return y * _state.n + x

## The local centre of chip `i`, which the win harness taps.
func chip_to_local(i: int) -> Vector2:
	return _chip_rects[i].get_center() if i < _chip_rects.size() else Vector2.ZERO

func _chip_at_point(local: Vector2) -> int:
	for i in _chip_rects.size():
		if _chip_rects[i].grow(4.0).has_point(local):
			return i
	return -1

# --- frames ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or _state.n == 0:
		return
	var t := _now()
	var settled := false
	for c: int in _moving.keys():
		if float(_until[c]) <= t:
			_moving.erase(c)
			settled = true
	if settled or t < _anim_until:
		_refresh()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds + 0.05)

func _touch(c: int, until: float) -> void:
	_until[c] = maxf(_until[c], until)
	_moving[c] = true
	_busy_for(until - _now())

func _refresh() -> void:
	_live = null
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.n == 0 or _cell <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := size * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	var shown: Array = []
	if _table == null or _pegs_fading(t):
		_table = _build_table(t)
	draw_mesh(_table, null, xf, tint)
	shown.append(_table)
	_update_bands(t)
	if _live == null:
		_live = _build_live(t)
	for m in _bands + [_live]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	var key := _head_state(t)
	if _head == null or key != _head_key or _head_moving(t):
		_head = _build_head(t)
		_head_key = key
	draw_mesh(_head, null, xf, tint)
	shown.append(_head)
	_draw_head_text(t, xf, seen)
	_draw_peek(t, shown)
	_draw_toast(t, shown)
	draw_set_transform(Vector2.ZERO)
	_shown = shown

## The card's table, the wooden tray, the board's face with its soft bevel,
## and every peg -- the bare ones fading out once the iron has passed.
func _build_table(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var clip := Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0)
	Rings._clip_polygon(b, clip, Pal.PG_TABLE.lerp(Pal.PARCHMENT, 0.5), clip)
	# A few soft leaf shadows over the table, the way light falls through
	# the garden onto it.
	var seed_i: int = _state.n * 31 + _state.target
	for d in 5:
		var at := Vector2(size.x * _h01(seed_i, d + 10), size.y * _h01(seed_i, d + 20))
		Scenery.soft_disc(b, at, 140.0, 90.0, Color(Pal.LAWN_DEEP, 0.07))
	var r := _board
	Scenery.soft_disc(b, r.get_center() + Vector2(0.0, r.size.y * 0.5 + 6.0), r.size.x * 0.56, 30.0,
		Color(Pal.TEXT, 0.16))
	b.fan(Face.Builder.round_rect(r.position + Vector2(0.0, 6.0), r.size, BOARD_RADIUS + 6.0), Pal.PG_TRAY_DEEP)
	b.fan(Face.Builder.round_rect(r.position, r.size, BOARD_RADIUS + 6.0), Pal.PG_TRAY)
	b.fan(Face.Builder.round_rect(r.position + Vector2.ONE * 3.0, r.size - Vector2.ONE * 6.0, BOARD_RADIUS + 3.0),
		Pal.PG_TRAY_HI)
	var inner := r.grow(-RIM)
	b.fan(Face.Builder.round_rect(inner.position - Vector2.ONE * 2.0, inner.size + Vector2.ONE * 4.0, BOARD_RADIUS),
		Pal.PG_TRAY_DEEP)
	b.fan(Face.Builder.round_rect(inner.position, inner.size, BOARD_RADIUS - 2.0), Pal.PG_BOARD_DEEP)
	b.fan(Face.Builder.round_rect(inner.position, inner.size - Vector2(0.0, 4.0), BOARD_RADIUS - 2.0), Pal.PG_BOARD)
	var gone := _pegs_gone(t)
	for c in _state.size():
		# Under a bead the peg is hidden anyway; the fade only matters where
		# the picture leaves the board bare.
		var a := 1.0 - gone if _state.want[c] == State.EMPTY else 1.0
		Bead.peg(b, _centre(c), _cell, a)
	return b.mesh()

func _pegs_gone(t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	if Motion.reduce:
		return 1.0
	var start := _solved_at + IRON_AT + float(_state.n) * IRON_STEP
	return clampf((t - start) / PEGS_GONE, 0.0, 1.0)

func _pegs_fading(t: float) -> bool:
	var g := _pegs_gone(t)
	return g > 0.0 and t < _solved_at + IRON_AT + (2.0 * _state.n) * IRON_STEP + IRON_TIME + PEGS_GONE + 0.1

func _update_bands(t: float) -> void:
	var n: int = _state.n
	var count := int(ceil(float(n) / float(BAND)))
	if _bands.size() != count:
		_bands.resize(count)
		_bands.fill(null)
		_band_looks.resize(count)
		_band_looks.fill(PackedInt32Array())
	for k in count:
		var first := k * BAND * n
		var last := mini(_state.size(), (k + 1) * BAND * n)
		var looks := PackedInt32Array()
		looks.resize(last - first)
		for c in range(first, last):
			looks[c - first] = -2 if _moving.has(c) else _look(c, t)
		if _bands[k] != null and looks == _band_looks[k]:
			continue
		var b := Face.Builder.new()
		for c in range(first, last):
			if not _moving.has(c):
				_draw_peg(b, c, t)
		_bands[k] = b.mesh() if not b.verts.is_empty() else null
		_band_looks[k] = looks

## Everything a resting peg's drawing depends on.
func _look(c: int, t: float) -> int:
	var fused := 1 if _fused(c, t) >= 1.0 else 0
	return (_state.beads[c] + 1) | (int(_halo.has(c)) << 8) | (fused << 9) | (int(_state.locked[c]) << 10)

func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var keep: Array = []
	for g: Dictionary in _leaving:
		var u: float = t - float(g.at)
		if u < LIFT_TIME and not Motion.reduce:
			keep.append(g)
		if u >= 0.0 and u < LIFT_TIME and not Motion.reduce:
			# Lifted off its peg: rising, nearer, fading.
			var k := u / LIFT_TIME
			var h := 1.0 - (1.0 - k) * (1.0 - k)
			Bead.bead(b, _centre(int(g.peg)), _cell, g.colour, Vector2.ONE * (1.0 + SEAT_NEAR * h),
				1.0 - k * k, _cell * SEAT_HIGH * h)
	_leaving = keep
	for c: int in _moving:
		_draw_peg(b, c, t)
	_draw_iron(b, t)
	var rings: Array = []
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u < 1.0:
			rings.append(r)
		if u >= 0.0 and u < 1.0:
			var rad := _cell * (0.5 + 0.5 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), _cell * 0.08 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	_rings = rings
	return b.mesh() if not b.verts.is_empty() else null

## One peg's bead: popping in (or dropping in, from a hint), shaking when a
## press is refused, hopping on the solve, fused by the iron, and haloed
## when Check pointed at it.
func _draw_peg(b: Face.Builder, c: int, t: float) -> void:
	var k: int = _state.beads[c]
	var at := _centre(c)
	at.x += Motion.shiver_offset(t - float(_shake_at[c]), _cell * 0.05)
	if k == State.EMPTY:
		if _state.locked[c] == 1:
			# A peg a hint cleared: a small sun dot says it is fused bare.
			b.disc(at + Vector2(_cell * 0.24, _cell * 0.24), _cell * 0.06, Color(Pal.SUN, 0.8))
		return
	var since := t - float(_arrive_at[c])
	var grow := Vector2.ONE
	var lift := 0.0
	var alpha := 1.0
	if _drop[c] == 1:
		lift = Motion.drop_in_lift(since, _cell * 0.9)
		alpha = Motion.appear_level(since)
	elif since < SEAT_TIME and not Motion.reduce:
		var seat := _seat(since)
		lift = seat.x
		grow = Vector2.ONE * seat.y
		alpha = seat.z
	lift += _hop(c, t)
	var fused := _fused(c, t)
	Bead.bead(b, at, _cell, _state.colours[k], grow, alpha, lift, fused, _shine(c, t))
	if _state.locked[c] == 1 and fused <= 0.0:
		b.disc(at + Vector2(_cell * 0.3, _cell * 0.3), _cell * 0.07, Pal.SUN)
	if _halo.has(c):
		var ha := Motion.appear_level(t - _halo_at, 0.12)
		Bead.halo(b, at - Vector2(0.0, lift), _cell, ha)

## A seating bead `since` seconds in: its lift, its scale and its alpha.
## The fall is gravity's (slow at the top, fastest at the peg), the fade is
## done a third of the way down, and the press after it is one dip and home.
func _seat(since: float) -> Vector3:
	var u := clampf(since / SEAT_TIME, 0.0, 1.0)
	if u < SEAT_FALL:
		var k := u / SEAT_FALL
		var h := 1.0 - k * k
		return Vector3(_cell * SEAT_HIGH * h, 1.0 + SEAT_NEAR * h, clampf(k * 3.0, 0.0, 1.0))
	var v := (u - SEAT_FALL) / (1.0 - SEAT_FALL)
	return Vector3(0.0, 1.0 - SEAT_PRESS * sin(v * PI), 1.0)

## The diagonal a peg stands on, from the top left.
func _diag(c: int) -> int:
	return c % _state.n + c / _state.n

func _hop(c: int, t: float) -> float:
	if _solved_at < 0.0 or Motion.reduce:
		return 0.0
	var at := _solved_at + Motion.stagger(_diag(c), Motion.SOLVE_STAGGER * 0.5, 0.5)
	return -Motion.hop_lift(t - at, Motion.SOLVE_HOP * _cell / 90.0, Motion.SOLVE_TIME)

func _fused(c: int, t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	if Motion.reduce:
		return 1.0
	return clampf((t - _solved_at - IRON_AT - _diag(c) * IRON_STEP) / IRON_TIME, 0.0, 1.0)

## The glint as the iron passes a bead: a bell over IRON_TIME.
func _shine(c: int, t: float) -> float:
	var u := _fused(c, t)
	return sin(u * PI) if u > 0.0 and u < 1.0 else 0.0

## The iron's band: a warm soft strip along the diagonal it has reached,
## crossing the board from the top left to the bottom right.
func _draw_iron(b: Face.Builder, t: float) -> void:
	if _solved_at < 0.0 or Motion.reduce:
		return
	var d := (t - _solved_at - IRON_AT) / IRON_STEP
	var n := float(_state.n)
	if d < -2.0 or d > 2.0 * n + 2.0:
		return
	# The strip runs perpendicular to the diagonal through the pegs whose
	# row + column is d.
	var along := Vector2(1.0, -1.0).normalized()
	var across := Vector2(1.0, 1.0).normalized()
	var centre := _grid + Vector2(d + 1.0, d + 1.0) * 0.5 * _cell
	var reach := n * _cell * 1.5
	var wide := _cell * 1.1
	var a := 0.28 * clampf(minf(d + 2.0, 2.0 * n + 2.0 - d) / 3.0, 0.0, 1.0)
	var inner := _board.grow(-RIM)
	var clip := Face.Builder.round_rect(inner.position, inner.size, BOARD_RADIUS - 2.0)
	for k in 3:
		var w := wide * (1.0 - k * 0.3)
		var strip := PackedVector2Array([centre - along * reach - across * w, centre + along * reach - across * w,
			centre + along * reach + across * w, centre - along * reach + across * w])
		Rings._clip_polygon(b, strip, Color(Pal.SUN.lerp(Color.WHITE, 0.4), a * (0.5 + 0.25 * k)), clip)

# --- the header ---

func _head_state(t: float) -> String:
	var out := "%d|%d|%d" % [brush, _state.placed(), 1 if _solved_at >= 0.0 else 0]
	for k in _state.seated.size():
		out += ",%d" % _state.seated[k]
	return out

func _head_moving(t: float) -> bool:
	for k in _chip_at.size():
		if t - float(_chip_at[k]) < Motion.BUMP_TIME + 0.05 or t - float(_chip_shake[k]) < Motion.SHIVER_TIME + 0.05:
			return true
	return t - _bar_bump < Motion.BUMP_TIME + 0.05

## The picture on its little pegboard, the chips, and the bar.
func _build_head(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_draw_thumb_frame(b, _thumb)
	if _thumb_mesh == null:
		_thumb_mesh = _build_thumb_pixels(_thumb)
	for i in _chip_rects.size():
		_draw_chip(b, i, t)
	# The bar of beads seated.
	var bar := Rect2(_right.position.x, _right.end.y - BAR_H - 4.0, _right.size.x - 150.0, BAR_H)
	var bump := Motion.bump_scale(t - _bar_bump, 0.08)
	bar = Rect2(bar.position - Vector2(0.0, (bump - 1.0) * BAR_H * 0.5), Vector2(bar.size.x, BAR_H * bump))
	b.fan(Face.Builder.round_rect(bar.position + Vector2(0.0, 2.0), bar.size, BAR_H * 0.5), Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(bar.position, bar.size, BAR_H * 0.5), Pal.PG_BOARD_DEEP)
	var frac := float(_state.placed()) / maxf(1.0, float(_state.target))
	if frac > 0.0:
		var full := Vector2(maxf(BAR_H, bar.size.x * frac), BAR_H * bump)
		var ink: Color = Pal.GOOD if _solved_at >= 0.0 or frac < 1.0 else Pal.SUN
		b.fan(Face.Builder.round_rect(bar.position, full, BAR_H * 0.5), ink)
		b.fan(Face.Builder.round_rect(bar.position + Vector2(4.0, 3.0), Vector2(maxf(0.0, full.x - 8.0), 5.0), 2.5),
			Color(Color.WHITE, 0.35))
	return b.mesh()

func _draw_thumb_frame(b: Face.Builder, r: Rect2) -> void:
	Scenery.soft_disc(b, r.get_center() + Vector2(0.0, r.size.y * 0.5 + 2.0), r.size.x * 0.55, 14.0,
		Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(r.position + Vector2(0.0, 4.0), r.size, 20.0), Pal.PG_TRAY_DEEP)
	b.fan(Face.Builder.round_rect(r.position, r.size, 20.0), Pal.PG_TRAY)
	b.fan(Face.Builder.round_rect(r.position + Vector2.ONE * 8.0, r.size - Vector2.ONE * 16.0, 13.0), Pal.PG_BOARD)

## The picture's pixels, in the thumbnail's own frame so the peek can grow
## the one mesh over the board by a transform alone.
func _build_thumb_pixels(r: Rect2) -> ArrayMesh:
	var b := Face.Builder.new()
	var n: int = _state.n
	var inner := r.grow(-8.0)
	var s := (inner.size.x - 12.0) / float(n)
	var at := inner.position + Vector2.ONE * 6.0
	for c in _state.size():
		var p := at + (Vector2(c % n, c / n) + Vector2(0.5, 0.5)) * s
		var k: int = _state.want[c]
		Bead.pixel(b, p, s, _state.colours[k] if k != State.EMPTY else Color.WHITE, k == State.EMPTY)
	return b.mesh()

## A chip: a paper tile standing up, a bead of its colour on it, and a pill
## under the bead for the count. The chosen one stands higher with an ink
## rim; a spent colour's bead is drawn hollow.
func _draw_chip(b: Face.Builder, i: int, t: float) -> void:
	var r := _chip_rects[i]
	var chosen := i == brush and _solved_at < 0.0
	var rise := CHIP_RISE if chosen else 0.0
	var bump := Motion.bump_scale(t - float(_chip_at[i]), 0.14)
	var shake := Motion.shiver_offset(t - float(_chip_shake[i]), 4.0)
	var mid := r.get_center() + Vector2(shake, -rise)
	var sz := r.size * bump
	var pos := mid - sz * 0.5
	Scenery.soft_disc(b, Vector2(mid.x, r.end.y + 2.0), sz.x * 0.55, 10.0, Color(Pal.TEXT, 0.12 + rise * 0.01))
	b.fan(Face.Builder.round_rect(pos + Vector2(0.0, 4.0), sz, 18.0), Pal.PG_BOARD_DEEP)
	if chosen:
		b.fan(Face.Builder.round_rect(pos - Vector2.ONE * 4.0, sz + Vector2.ONE * 8.0, 21.0), Pal.TEXT)
	b.fan(Face.Builder.round_rect(pos, sz, 18.0), Pal.SURFACE)
	var bead_at := pos + Vector2(sz.x * 0.5, sz.y * 0.34)
	var s := minf(CHIP_BEAD * bump, sz.x * 0.86) / (Bead.R * 2.0)
	var spent: bool = _state.left(i) <= 0
	Bead.bead(b, bead_at, s, _state.colours[i], Vector2.ONE, 0.45 if spent else 1.0, 0.0, 0.0, 0.0, Pal.SURFACE, false)
	var pill := Rect2(pos + Vector2(8.0, sz.y * 0.66), Vector2(sz.x - 16.0, sz.y * 0.26))
	b.fan(Face.Builder.round_rect(pill.position, pill.size, pill.size.y * 0.5), Pal.PAPER.darkened(0.03))

func _draw_head_text(t: float, xf: Transform2D, seen: float) -> void:
	draw_set_transform_matrix(xf)
	var font: Font = CozyTheme.display(700)
	var name := tr(_state.pic_name)
	draw_string(font, Vector2(_right.position.x + 4.0, _right.position.y + font.get_ascent(NAME_SIZE)),
		name, HORIZONTAL_ALIGNMENT_LEFT, _right.size.x - 8.0, NAME_SIZE, Color(Pal.TEXT, seen))
	for i in _chip_rects.size():
		var r := _chip_rects[i]
		var rise := CHIP_RISE if i == brush and _solved_at < 0.0 else 0.0
		var shake := Motion.shiver_offset(t - float(_chip_shake[i]), 4.0)
		var left: int = maxi(0, _state.left(i))
		var text := str(left)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, COUNT_SIZE).x
		var y := r.position.y + r.size.y * 0.79 - rise + font.get_ascent(COUNT_SIZE) * 0.38
		draw_string(font, Vector2(r.get_center().x + shake - wide * 0.5, y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, COUNT_SIZE, Color(Pal.TEXT_DIM if left == 0 else Pal.TEXT, seen))
	var tally := "%d / %d" % [_state.placed(), _state.target]
	var tw := font.get_string_size(tally, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAME_SIZE).x
	var bar_y := _right.end.y - BAR_H * 0.5 - 4.0
	draw_string(font, Vector2(_right.end.x - tw, bar_y + font.get_ascent(NAME_SIZE) * 0.38), tally,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAME_SIZE, Color(Pal.TEXT, seen))
	draw_set_transform(Vector2.ZERO)
	if _thumb_mesh != null:
		draw_mesh(_thumb_mesh, null, xf, Color(1.0, 1.0, 1.0, seen))

## The held picture: the thumbnail's pixels grown over the board on a paper
## card, so it can be read peg for peg beside nothing at all.
func _draw_peek(t: float, shown: Array) -> void:
	if _thumb_mesh == null:
		return
	var u := clampf((t - _peek_at) / PEEK_TIME, 0.0, 1.0)
	if Motion.reduce:
		u = 1.0
	var k := u if _peek else 1.0 - u
	if k <= 0.0:
		return
	var e := Motion.back_out(k) if _peek else k * k
	var target := _board.size.x * PEEK_COVER
	var big := Rect2(_board.get_center() - Vector2.ONE * target * 0.5, Vector2.ONE * target)
	var r := Rect2(_thumb.position.lerp(big.position, e), _thumb.size.lerp(big.size, e))
	var sc := r.size.x / _thumb.size.x
	var xf := Transform2D(0.0, Vector2.ONE * sc, 0.0, r.position - _thumb.position * sc)
	var b := Face.Builder.new()
	_draw_thumb_frame(b, _thumb)
	var frame := b.mesh()
	draw_mesh(frame, null, xf, Color(1.0, 1.0, 1.0, minf(1.0, k * 2.0)))
	draw_mesh(_thumb_mesh, null, xf, Color(1.0, 1.0, 1.0, minf(1.0, k * 2.0)))
	shown.append(frame)

# --- the toast ---

func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var line := tr(_toast)
	if _toast_arg != "":
		line = line % _toast_arg
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		var lh := font.get_height(TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / lh)))
		text_w = minf(text_room, wrapped.x)
	var w := minf(room, text_w + TOAST_PAD)
	var h := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [line, int(w), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -h) * 0.5, Vector2(w, h), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = key
	if _toast_mesh == null:
		return
	var mid := Vector2(size.x * 0.5, _board.end.y - TOAST_MARGIN - h * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _tell(key: String, arg := "") -> void:
	_toast = key
	_toast_arg = arg
	_toast_at = _now()
	queue_redraw()

# --- input ---

## One finger holds the gesture. A press on a chip picks its colour; on the
## picture it holds the picture up over the board; on a peg it starts a
## stroke that seats the chosen colour -- or lifts it, when the peg it began
## on already holds that colour -- on every peg the finger crosses.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var finger: int = event.index if event is InputEventScreenTouch else -1
		if event.pressed:
			if _press_finger != -2:
				return
			_press_finger = finger
			_press(event.position)
		else:
			if finger != _press_finger:
				return
			_press_finger = -2
			_release()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		var finger: int = event.index if event is InputEventScreenDrag else -1
		if _stroking and finger == _press_finger:
			_drag(event.position)

func _press(at: Vector2) -> void:
	_clear_gesture()
	if _thumb.has_point(at):
		_peek = true
		_peek_at = _now()
		_busy_for(PEEK_TIME)
		fx.cue("peek")
		queue_redraw()
		return
	if is_done():
		return
	var chip := _chip_at_point(at)
	if chip >= 0:
		_pick(chip)
		return
	var c := _peg_at(at)
	if c < 0:
		return
	_stroking = true
	_erase = _state.beads[c] == brush
	_state.begin_stroke()
	_paint(c)
	_refresh()

func _drag(at: Vector2) -> void:
	var c := _peg_at(at)
	if c < 0 or c == _last:
		return
	# Every peg between the last one painted and this one, so a quick finger
	# leaves no gaps in its run.
	if _last >= 0:
		var n: int = _state.n
		var a := Vector2i(_last % n, _last / n)
		var z := Vector2i(c % n, c / n)
		var steps := maxi(absi(z.x - a.x), absi(z.y - a.y))
		for i in range(1, steps):
			var p := Vector2i(roundi(lerpf(a.x, z.x, float(i) / steps)), roundi(lerpf(a.y, z.y, float(i) / steps)))
			_paint(p.y * n + p.x)
	_paint(c)
	_refresh()

## Seats or lifts on peg `c` once a stroke; a stroke never repaints a peg it
## has already crossed.
func _paint(c: int) -> void:
	_last = c
	if _painted.has(c):
		return
	_painted[c] = true
	var had: int = _state.beads[c]
	var r: String = _state.put(c, State.EMPTY if _erase else brush)
	var t := _now()
	match r:
		"put":
			if had != State.EMPTY:
				_leaving.append({"peg": c, "colour": _state.colours[had], "at": t})
			if _state.beads[c] != State.EMPTY:
				_arrive_at[c] = t
				_drop[c] = 0
				_touch(c, t + SEAT_TIME)
				fx.cue("place", 0.94 + 0.12 * _h01(c, _painted.size()), 0.0)
			else:
				_touch(c, t + LIFT_TIME)
				fx.cue("lift", 0.96 + 0.08 * _h01(c, 3))
			_bar_bump = t
			_busy_for(Motion.BUMP_TIME)
		"locked":
			_shake_at[c] = t
			_touch(c, t + Motion.SHIVER_TIME)
			if not _refused:
				_refused = true
				fx.cue("refuse")
				_tell("PG_FUSED")
		"none_left":
			_shake_at[c] = t
			_touch(c, t + Motion.SHIVER_TIME)
			if not _refused:
				_refused = true
				_chip_shake[brush] = t
				_busy_for(Motion.SHIVER_TIME)
				fx.cue("refuse")
				_tell("PG_NONE_LEFT")

func _release() -> void:
	if _peek:
		_peek = false
		_peek_at = _now()
		_busy_for(PEEK_TIME)
		queue_redraw()
		return
	if not _stroking:
		return
	_stroking = false
	var changed: PackedInt32Array = _state.end_stroke()
	_clear_gesture()
	if changed.is_empty():
		_refresh()
		return
	_halo = {}
	note_move()
	if not is_done() and _state.placed() == _state.target:
		_tell("PG_ALL_SEATED")
	_refresh()

func _pick(i: int) -> void:
	if i != brush:
		fx.cue("pick")
	brush = i
	_chip_at[i] = _now()
	_busy_for(Motion.BUMP_TIME)
	queue_redraw()

func _clear_gesture() -> void:
	_stroking = false
	_erase = false
	_refused = false
	_last = -1
	_painted = {}

## The chosen colour, for a harness.
func set_brush(v: int) -> void:
	_pick(clampi(v, 0, _state.names.size() - 1))

# --- the HUD's actions ---

func can_undo() -> bool:
	return _state.can_undo() and not is_done()

## Takes back the last stroke: its beads pop back off (or back on), last
## first.
func undo() -> bool:
	if is_done() or _stroking:
		return false
	var before: PackedInt32Array = _state.beads.duplicate()
	var pegs: PackedInt32Array = _state.undo()
	if pegs.is_empty():
		return false
	_show_changes(before, pegs, Motion.RESET_STAGGER)
	_halo = {}
	fx.cue("undo")
	moved.emit()
	_refresh()
	return true

## Every peg in `pegs` goes from what `before` had to what the state has
## now, the i-th `per` seconds after the first.
func _show_changes(before: PackedInt32Array, pegs: PackedInt32Array, per: float, drop := false) -> void:
	var t := _now()
	for i in pegs.size():
		var c := pegs[i]
		var at := t + (0.0 if Motion.reduce else Motion.stagger(i, per))
		if before[c] != State.EMPTY and before[c] != _state.beads[c]:
			_leaving.append({"peg": c, "colour": _state.colours[before[c]], "at": at})
		if _state.beads[c] != State.EMPTY and before[c] != _state.beads[c]:
			_arrive_at[c] = at
			_drop[c] = 1 if drop else 0
			_touch(c, at + (Motion.DROP_TIME if drop else SEAT_TIME))
		else:
			_touch(c, at + LIFT_TIME)
	_bar_bump = t
	_busy_for(Motion.BUMP_TIME + Motion.stagger(pegs.size(), per))

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Puts one peg right and fuses it: a bead out of place is lifted (or turned
## the right colour), else a missing bead drops in, under the hint's ring.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or _stroking:
		return false
	var before: PackedInt32Array = _state.beads.duplicate()
	var h: Dictionary = _state.hint()
	if h.is_empty():
		return false
	hints_used += 1
	var c: int = h.peg
	var pegs := PackedInt32Array()
	for o in _state.size():
		if before[o] != _state.beads[o]:
			pegs.append(o)
	_show_changes(before, pegs, 0.0, true)
	_halo = {}
	if not Motion.reduce:
		_rings.append({"pos": _centre(c), "at": _now()})
		_busy_for(Motion.RING_TIME)
	fx.sparkle(_centre(c), Pal.SUN)
	fx.cue("hint")
	if int(h.was) != State.EMPTY and _state.beads[c] == State.EMPTY:
		_tell("PG_HINT_LIFT")
	elif int(h.was) != State.EMPTY:
		_tell("PG_HINT_SWAP")
	else:
		_tell("PG_HINT_SEAT")
	moved.emit()
	check_solved()
	_refresh()
	return true

## Every bead that is not where the picture wants it gets a rose halo and a
## shake, held until the next move. Counts a check.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: PackedInt32Array = _state.wrong()
	var t := _now()
	_halo = {}
	_halo_at = t
	for c in wrong:
		_halo[c] = true
		_shake_at[c] = t
		_touch(c, t + Motion.SHIVER_TIME)
	if wrong.is_empty():
		var missing: int = _state.target - _state.placed()
		if missing > 0:
			_tell("PG_CHECK_OK_ONE" if missing == 1 else "PG_CHECK_OK_N", "" if missing == 1 else str(missing))
		else:
			_tell("PG_CHECK_OK")
		fx.cue("check_ok")
	else:
		_tell("PG_CHECK_ONE" if wrong.size() == 1 else "PG_CHECK_N", "" if wrong.size() == 1 else str(wrong.size()))
		fx.cue("check")
	_refresh()
	return wrong.size()

## Every bead back in the kit but the ones a hint fused, in a wave from the
## far corner.
func reset_board() -> void:
	var before: PackedInt32Array = _state.beads.duplicate()
	var pegs: PackedInt32Array = _state.reset()
	var t := _now()
	var far: int = 2 * (_state.n - 1)
	for c in pegs:
		var at := t + (0.0 if Motion.reduce else Motion.stagger(far - _diag(c), Motion.RESET_STAGGER))
		_leaving.append({"peg": c, "colour": _state.colours[before[c]], "at": at})
		_touch(c, at + LIFT_TIME)
	_halo = {}
	_bar_bump = t
	moves = 0
	_running = true
	_tell("PG_RESET")
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

func share_glyphs() -> String:
	return _state.share_glyphs()

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("PG_WIN") % tr(_state.pic_name)}

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return IRON_AT + 2.0 * _state.n * IRON_STEP + IRON_TIME + WIN_WAIT

func _on_solved() -> void:
	var t := _now()
	_solved_at = t
	_clear_gesture()
	_halo = {}
	# Every bead is live while the wave and the iron cross it.
	var span: float = IRON_AT + 2.0 * _state.n * IRON_STEP + IRON_TIME
	for c in _state.size():
		if _state.beads[c] != State.EMPTY:
			_touch(c, t + span)
	_busy_for(span + PEGS_GONE)
	fx.cue("solved")
	if not Motion.reduce:
		get_tree().create_timer(IRON_AT).timeout.connect(func():
			if is_inside_tree() and _solved_at == t:
				fx.cue("iron"))
	_refresh()

## A reopened daily that was already solved: the whole picture seated and
## fused, the bare pegs gone. Never check_solved(): `solved` must not fire
## twice.
func restore_completed_board() -> void:
	_state.fill()
	var t := _now()
	_solved_at = t - 100.0
	_opened = t - 100.0
	_moving = {}
	_leaving = []
	_halo = {}
	_table = null
	_bands = []
	_refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A fixed pseudo-random number per pair, 0..1.
static func _h01(a: int, b: int) -> float:
	return float(posmod(hash(Vector2i(a, b)), 1000)) / 1000.0
