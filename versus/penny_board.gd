extends Control

## Penny Drop's rack, seen from the front as it stands on the deck: a painted
## wooden face seven holes wide and six high on a wooden foot, the pennies
## showing through the holes. The player's pennies are the sun's (brass, a
## sun stamped on each), the other player's the moon's (a silvery blue, a
## crescent stamped on each), whichever of them drops first. Each side's
## pennies still to play lie in a roll of its own: the moon's above the rack,
## the sun's below it, by the thumb.
##
## The penny about to be dropped waits over the rack. A finger anywhere on a
## column brings it over that column and lights the column, since the thumb
## hides the holes it is on; letting go drops it. It falls behind the face,
## knocks once on what it lands on, and lies still.
##
## Everything that does not move is two baked meshes, the back and the face.
## A penny is one cached mesh a side, drawn under a transform wherever it is:
## lying in a hole, in its roll, waiting, falling. What changes shape (the
## column's light, the rings round a line) is one small mesh rebuilt only
## while it moves.
##
## The board shows what it has been told (`play`, `rewind`), not the rules it
## was set up from, so a penny is in its hole only once it has landed.

## The player let go over a column that has room.
signal chosen(col: int)
## What was being shown has finished: the rack is set, a penny has landed, a
## penny taken back is out.
signal settled
## The finger crossed to another column.
signal moved
## The column let go over is full.
signal refused(reason: String)

const Rules = preload("res://versus/penny_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## A hole's pitch in the meshes' own space, whose origin is the top left of
## the grid of holes.
const U := 100.0
const GRID := Vector2(Rules.W * U, Rules.H * U)
## The frame round the grid, the foot's reach past the frame and its height.
const FRAME := 30.0
const FOOT_OUT := 30.0
const FOOT_H := 36.0
## A hole's radius and a penny's.
const HOLE_R := 41.0
const PENNY_R := 45.0
## Where the waiting penny hangs, and the middle of each roll.
const HOVER_Y := -74.0
const ROLL_R := 34.0
const ROLL_TOP_Y := -176.0
const ROLL_BOTTOM_Y := 708.0
## The space the rack takes, without its rolls and with them.
const SPACE := Rect2(-(FRAME + FOOT_OUT), -128.0, GRID.x + 2.0 * (FRAME + FOOT_OUT), 128.0 + 664.0)
const SPACE_ROLLS := Rect2(-(FRAME + FOOT_OUT), -216.0, GRID.x + 2.0 * (FRAME + FOOT_OUT), 216.0 + 748.0)

const PAINT := Color("4c9a94")
const PAINT_LIT := Color("6cb5ae")
const PAINT_DEEP := Color("357a75")
const INSIDE := Color("1f4f4c")
const WOOD := Color("b98457")
const WOOD_LIT := Color("d3a273")
const WOOD_DEEP := Color("7d5334")
## A penny's rim, face, shine and stamp, by look: the sun's, the moon's.
const RIM := [Color("c47f17"), Color("5767b4")]
const COIN := [Color("f4b23a"), Color("8c9ce4")]
const SHINE := [Color("ffd980"), Color("bcc7f6")]
const STAMP := [Color("d18d1c"), Color("6878c8")]
const HALO := Color("fff6e0")
const HINT := Color("f9c04a")

## Local units a second squared, and what a penny keeps of its speed when it
## knocks. Seconds: the look at a landing before the game goes on, a penny
## taken back, the rack emptied.
const GRAVITY := 4600.0
const BOUNCE := 0.24
const WATCH := 0.14
const REWIND := 0.22
const SPILL := 0.7
## What repeats is never the same sound twice (the cozy rules): the finger's
## tick, the penny let go, one taken back and a full column each play a
## little either way. They were 1.0 every time. `land` is pitched by its
## fall alone (1.08 down to 0.92), so it is left out.
const TICK_VARY := Vector2(0.94, 1.06)
const HOVER_SPEED := 14.0

var rules: RefCounted
## The rules' side the player is: its pennies are the sun's.
var player := 0
var interactive := false
## A picture, not a game (the Versus tab's card): drawn when asked, no input,
## no rolls, as wide as the control and standing on its bottom edge.
var still := false
## Whether the rolls of pennies still to play are drawn (not on a tutorial
## page).
var rolls := true
## A tutorial page's rack: it moves as a game's does, but hears no finger and
## makes no sound.
var deaf := false
## The rectangle the rack takes.
var used_rect := Rect2()

var _xf := Transform2D.IDENTITY
var _back: ArrayMesh
var _front: ArrayMesh
var _penny: Array[ArrayMesh] = []
var _glow: ArrayMesh
var _over_mesh: ArrayMesh
var _shown: Array = []
var _fx: Node2D
var _run := 0
var _t := 0.0
var _busy_until := 0.0
## What lies in each hole as shown: 0 empty, else a look plus one.
var _cells := PackedByteArray()
## Pennies in the air: {look, x, y, v, to, cell, hit, from, wait, spill}.
var _air: Array[Dictionary] = []
## A penny going back up: {look, x, from, at}.
var _back_up := {}
## The waiting penny: whose (-1 none), where it is and where it is going, in
## columns, and how much of it is there.
var _hover_look := -1
var _hover_x := 3.0
var _hover_to := 3.0
var _hover_a := 0.0
var _thinking := false
## The column under the finger (-1 none), and whether a finger is down.
var _over := -1
var _down := false
var _hint := -1
var _last := -1
var _line := PackedInt32Array()
## How the game ended, "" while it is on.
var _mood := ""
var _won_at := -1.0
var _shake_at := -10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still or deaf else Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	if not still and not deaf:
		_fx = Fx2D.new()
		add_child(_fx)
	_layout()

# --- setting up ---

## A rack showing `the_rules` as they stand, the player being `side`. With
## `enter`, whatever lay in the rack before falls out of it first, and
## `settled` is said once it is empty and ready.
func setup(the_rules: RefCounted, side: int, enter := false) -> void:
	_run += 1
	var old := _cells
	rules = the_rules
	player = side
	_cells = PackedByteArray()
	_cells.resize(Rules.CELLS)
	for c in Rules.CELLS:
		if rules.cells[c] != Rules.EMPTY:
			_cells[c] = look_of(rules.cells[c] - 1) + 1
	_air.clear()
	_back_up = {}
	_hover_look = -1
	_hover_a = 0.0
	_thinking = false
	_over = -1
	_down = false
	_hint = -1
	_last = -1
	_line = PackedInt32Array()
	_mood = ""
	_won_at = -1.0
	var wait := 0.0
	if enter and not Motion.reduce and old.size() == Rules.CELLS:
		# The bar under the rack is drawn and everything in it drops out, the
		# bottom row first.
		var any := false
		for c in Rules.CELLS:
			if old[c] != 0:
				any = true
				var at := mid(c)
				_air.append({"look": old[c] - 1, "x": at.x, "y": at.y, "v": 0.0, "to": SPACE_ROLLS.end.y + 300.0,
					"cell": -1, "hit": true, "from": at.y, "wait": 0.03 * (c / Rules.W) + 0.012 * (c % Rules.W), "spill": true})
		if any:
			_cue("spill")
			wait = SPILL
	if enter:
		_after(wait + (0.05 if Motion.reduce else 0.25), func() -> void: settled.emit())
	_busy(wait + 0.4)
	_touch()

## The look of a rules' side: 0 the sun's (the player's), 1 the moon's.
func look_of(side: int) -> int:
	return 0 if side == player else 1

## The middle of a hole, in the meshes' space.
static func mid(c: int) -> Vector2:
	return Vector2((c % Rules.W + 0.5) * U, (Rules.H - (c / Rules.W) - 0.5) * U)

## A point of the meshes' space, in the board's own.
func point_of(p: Vector2) -> Vector2:
	return _xf * p

## Where a line of words can stand without hiding the rack: over the far
## roll.
func toast_point() -> Vector2:
	return _xf * Vector2(GRID.x * 0.5, ROLL_TOP_Y if rolls else HOVER_Y)

# --- what the screen tells it ---

## The penny of the rules' `side` is dropped, to land in `cell`.
func play(cell: int, side: int) -> void:
	var look := look_of(side)
	var to := mid(cell)
	_hint = -1
	_over = -1
	_down = false
	_thinking = false
	_hover_look = -1
	_hover_a = 0.0
	if Motion.reduce:
		_cells[cell] = look + 1
		_last = cell
		_cue("land", 1.0)
		_after(Motion.REDUCED_TIME, func() -> void: settled.emit())
		_touch()
		return
	_cue("drop", randf_range(TICK_VARY.x, TICK_VARY.y))
	_air.append({"look": look, "x": to.x, "y": HOVER_Y, "v": 0.0, "to": to.y, "cell": cell, "hit": false,
		"from": HOVER_Y, "wait": 0.0, "spill": false})
	_busy(2.0)

## The penny in `cell` is taken back out of the top of its column.
func rewind(cell: int) -> void:
	var look := _cells[cell] - 1
	_cells[cell] = 0
	_last = -1
	_hint = -1
	_line = PackedInt32Array()
	if Motion.reduce or look < 0:
		_after(Motion.REDUCED_TIME, func() -> void: settled.emit())
		_touch()
		return
	_cue("lift", randf_range(TICK_VARY.x, TICK_VARY.y))
	_back_up = {"look": look, "x": mid(cell).x, "from": mid(cell).y, "at": _t}
	_busy(REWIND + 0.1)
	_after(REWIND, func() -> void:
		_back_up = {}
		settled.emit())

## The bulb's column, -1 for none.
func set_hint(col: int) -> void:
	_hint = col
	if col >= 0:
		_hover_to = float(col)
	_busy(0.2)
	_touch()

## Whose penny waits over the rack: the rules' `side`, or -1 for nobody's.
func set_waiting(side: int) -> void:
	_hover_look = -1 if side < 0 else look_of(side)
	if side < 0:
		_thinking = false
	_busy(0.3)
	_touch()

## The other player is choosing: its penny drifts over the columns.
func set_thinking(on: bool) -> void:
	_thinking = on
	_busy(0.3)

## The other player has chosen `col`: its penny goes over it.
func set_lifted(col: int) -> void:
	_thinking = false
	if col >= 0:
		_hover_to = float(col)
	_busy(0.5)

## The game is over. A line, if there is one, is ringed.
func finish(outcome: String, line := PackedInt32Array()) -> void:
	_mood = outcome
	_line = line
	_won_at = _t
	_hover_look = -1
	_hint = -1
	_over = -1
	_down = false
	_thinking = false
	if not line.is_empty() and not Motion.reduce and _fx != null:
		for i in line.size():
			var at := point_of(mid(line[i]))
			_after(0.1 + 0.09 * i, func() -> void: _fx.sparkle(at, Pal.SUN_SPARK))
	_busy(1.2)
	_touch()

## Whether a penny is in the air, on its way down or back up.
func is_busy() -> bool:
	return not _air.is_empty() or not _back_up.is_empty()

# --- layout and time ---

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var space := SPACE_ROLLS if rolls and not still else SPACE
	var s := size.x / space.size.x if still else minf(size.x / space.size.x, size.y / space.size.y)
	var at := Vector2((size.x - space.size.x * s) * 0.5, size.y - space.size.y * s if still else (size.y - space.size.y * s) * 0.5)
	_xf = Transform2D(0.0, Vector2(s, s), 0.0, at - space.position * s)
	used_rect = Rect2(at, space.size * s)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var live := _t < _busy_until or not _air.is_empty() or _down or _thinking
	# The waiting penny comes and goes, and follows its column.
	var want := 1.0 if _hover_look >= 0 else 0.0
	if _hover_a != want:
		_hover_a = move_toward(_hover_a, want, delta * 6.0)
		live = true
	if _hover_look >= 0:
		if _thinking and not Motion.reduce:
			_hover_to = 3.0 + 2.3 * sin(_t * 1.25)
		if _hover_x != _hover_to:
			_hover_x = _hover_to if Motion.reduce else lerpf(_hover_x, _hover_to, minf(1.0, delta * HOVER_SPEED))
			if absf(_hover_x - _hover_to) < 0.004:
				_hover_x = _hover_to
			live = true
		# Waiting for the player it bobs a little, so it is seen to be theirs.
		if interactive and not Motion.reduce:
			live = true
	_fall(delta)
	if live:
		queue_redraw()

## Moves what is in the air: a dropped penny falls, knocks once and lies
## still; a spilled one falls away.
func _fall(delta: float) -> void:
	var i := 0
	while i < _air.size():
		var p: Dictionary = _air[i]
		if float(p.wait) > 0.0:
			p.wait = float(p.wait) - delta
			i += 1
			continue
		p.v = float(p.v) + GRAVITY * delta
		p.y = float(p.y) + float(p.v) * delta
		if float(p.y) >= float(p.to):
			if bool(p.spill):
				_air.remove_at(i)
				continue
			if not bool(p.hit):
				# The knock: louder and lower the further it fell.
				var fell := clampf((float(p.to) - float(p.from)) / GRID.y, 0.0, 1.0)
				_cue("land", 1.12 - 0.2 * fell, lerpf(-7.0, 0.0, fell))
				p.hit = true
				p.y = float(p.to)
				p.v = -float(p.v) * BOUNCE
			else:
				_cells[int(p.cell)] = int(p.look) + 1
				_last = int(p.cell)
				_air.remove_at(i)
				_busy(WATCH + 0.3)
				_after(WATCH, func() -> void: settled.emit())
				continue
		i += 1

func _busy(seconds: float) -> void:
	_busy_until = maxf(_busy_until, _t + seconds)

func _touch() -> void:
	queue_redraw()

func _after(seconds: float, what: Callable) -> void:
	var run := _run
	if not is_inside_tree():
		return
	get_tree().create_timer(maxf(seconds, 0.01)).timeout.connect(func() -> void:
		if run == _run and is_inside_tree():
			what.call())

func _cue(cue_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if _fx != null:
		_fx.cue(cue_name, pitch, volume_db)

# --- input ---

## The column a point of the board is over, -1 off the rack's sides.
func column_at(p: Vector2) -> int:
	var q := _xf.affine_inverse() * p
	if q.x < -FRAME or q.x > GRID.x + FRAME:
		return -1
	return clampi(int(floorf(q.x / U)), 0, Rules.W - 1)

func _gui_input(event: InputEvent) -> void:
	if still or deaf or not interactive:
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
	var col := column_at(at)
	if release:
		if not _down:
			return
		_down = false
		_over = -1
		if col >= 0:
			if rules.can(col):
				_hover_x = float(col)
				_hover_to = float(col)
				chosen.emit(col)
			else:
				_shake_at = _t
				_busy(0.4)
				_cue("refused", randf_range(TICK_VARY.x, TICK_VARY.y))
				refused.emit("full")
		_touch()
		return
	if press:
		_down = true
	if not _down:
		return
	if col != _over:
		_over = col
		if col >= 0:
			_hover_to = float(col)
			if not press:
				_cue("tick", randf_range(TICK_VARY.x, TICK_VARY.y))
				moved.emit()
		_busy(0.3)
	_touch()

# --- drawing ---

func _draw() -> void:
	if rules == null or used_rect.size.x <= 0.0:
		return
	if _back == null:
		_back = _build_back()
		_front = _build_front()
		_penny = [_build_penny(0), _build_penny(1)]
		_glow = _build_glow()
	_over_mesh = _build_over()
	_shown = [_back, _front, _penny, _glow, _over_mesh]
	draw_mesh(_back, null, _xf)
	var lit := _over if _down else -1
	if lit >= 0:
		draw_mesh(_glow, null, _xf * Transform2D(0.0, Vector2(lit * U, 0.0)))
	for c in Rules.CELLS:
		if _cells[c] != 0:
			draw_mesh(_penny[_cells[c] - 1], null, _xf * Transform2D(0.0, mid(c)))
	for p: Dictionary in _air:
		var a := 1.0
		if bool(p.spill):
			a = clampf((SPACE_ROLLS.end.y + 200.0 - float(p.y)) / 300.0, 0.0, 1.0)
		draw_mesh(_penny[int(p.look)], null, _xf * Transform2D(0.0, Vector2(float(p.x), float(p.y))), Color(1, 1, 1, a))
	if not _back_up.is_empty():
		var f := clampf((_t - float(_back_up.at)) / REWIND, 0.0, 1.0)
		var y := lerpf(float(_back_up.from), HOVER_Y, ease(f, 0.5))
		draw_mesh(_penny[int(_back_up.look)], null, _xf * Transform2D(0.0, Vector2(float(_back_up.x), y)), Color(1, 1, 1, 1.0 - f * f))
	draw_mesh(_front, null, _xf)
	if rolls and not still:
		_draw_rolls()
	if _hover_look >= 0 and _hover_a > 0.0:
		var at := Vector2((_hover_x + 0.5) * U, HOVER_Y)
		if interactive and not _down and not Motion.reduce:
			at.y += sin(_t * 3.2) * 5.0
		var shake := _t - _shake_at
		if shake < 0.3 and not Motion.reduce:
			at.x += sin(shake * 60.0) * 7.0 * (1.0 - shake / 0.3)
		draw_mesh(_penny[_hover_look], null, _xf * Transform2D(0.0, Vector2.ONE * (0.8 + 0.2 * _hover_a), 0.0, at), Color(1, 1, 1, _hover_a))
	if _over_mesh != null:
		draw_mesh(_over_mesh, null, _xf)

## Each side's pennies not yet played, lying in a roll: one fewer for the one
## waiting over the rack or in the air.
func _draw_rolls() -> void:
	var left := [Rules.CELLS / 2, Rules.CELLS / 2]
	for c in Rules.CELLS:
		if _cells[c] != 0:
			left[_cells[c] - 1] -= 1
	for p: Dictionary in _air:
		if not bool(p.spill):
			left[int(p.look)] -= 1
	if not _back_up.is_empty():
		left[int(_back_up.look)] -= 1
	if _hover_look >= 0:
		left[_hover_look] -= 1
	var step := (GRID.x - 2.0 * ROLL_R) / (Rules.CELLS / 2 - 1)
	var k := ROLL_R / PENNY_R
	for look in 2:
		var y := ROLL_BOTTOM_Y if look == 0 else ROLL_TOP_Y
		for i in maxi(0, left[look]):
			draw_mesh(_penny[look], null, _xf * Transform2D(0.0, Vector2(k, k), 0.0, Vector2(ROLL_R + i * step, y)))

## The shadow the rack throws on the deck, its wooden foot, and the dark
## inside seen through the holes.
func _build_back() -> ArrayMesh:
	var b := Face.Builder.new()
	var foot_at := Vector2(-(FRAME + FOOT_OUT), GRID.y + FRAME * 0.5)
	var foot := Vector2(GRID.x + 2.0 * (FRAME + FOOT_OUT), FOOT_H)
	Scenery.soft_disc(b, Vector2(GRID.x * 0.5, GRID.y + FRAME + FOOT_H * 0.7), GRID.x * 0.62, 30.0, Color(0.15, 0.08, 0.03, 0.3))
	b.fan(Face.Builder.round_rect(foot_at + Vector2(0.0, 5.0), foot, 14.0), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(foot_at, foot - Vector2(0.0, 5.0), 14.0), WOOD)
	b.stroke(PackedVector2Array([foot_at + Vector2(18.0, 8.0), foot_at + Vector2(foot.x - 18.0, 8.0)]), 5.0, Color(WOOD_LIT, 0.8))
	b.fan(Face.Builder.round_rect(Vector2(-4.0, -4.0), GRID + Vector2(8.0, 8.0), 10.0), INSIDE)
	return b.mesh()

## The painted face: a tile a hole, each a square with a round hole through
## it, then the frame round them and each hole's rim and the shade the face
## throws into it.
func _build_front() -> ArrayMesh:
	var b := Face.Builder.new()
	var n := 32
	for c in Rules.CELLS:
		var centre := mid(c)
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var d0 := Vector2.from_angle(a0)
			var d1 := Vector2.from_angle(a1)
			var v0 := b.vertex(centre + d0 * HOLE_R, PAINT)
			var v1 := b.vertex(centre + d1 * HOLE_R, PAINT)
			var v2 := b.vertex(centre + d1 * (U * 0.5 / maxf(absf(d1.x), absf(d1.y))), PAINT)
			var v3 := b.vertex(centre + d0 * (U * 0.5 / maxf(absf(d0.x), absf(d0.y))), PAINT)
			b.tri(v0, v1, v2)
			b.tri(v0, v2, v3)
	# the frame, lit along its top and shaded along its bottom
	var half := FRAME * 0.5
	b.stroke(Face.Builder.round_rect(Vector2(-half, -half + 4.0), GRID + Vector2(FRAME, FRAME), 26.0), FRAME + 2.0, PAINT_DEEP, true)
	b.stroke(Face.Builder.round_rect(Vector2(-half, -half), GRID + Vector2(FRAME, FRAME - 4.0), 26.0), FRAME + 2.0, PAINT_LIT, true)
	b.stroke(PackedVector2Array([Vector2(8.0, -FRAME + 9.0), Vector2(GRID.x - 8.0, -FRAME + 9.0)]), 5.0, Color(1, 1, 1, 0.28))
	for c in Rules.CELLS:
		var centre := mid(c)
		b.stroke(Face.Builder.ring(centre, HOLE_R + 1.0, HOLE_R + 1.0), 5.0, PAINT_DEEP, true)
		b.stroke(Face.Builder.arc_points(centre, HOLE_R + 4.5, PI * 0.15, PI * 0.85), 3.0, Color(1, 1, 1, 0.22))
		b.stroke(Face.Builder.arc_points(centre, HOLE_R - 4.0, PI * 1.1, PI * 1.9), 7.0, Color(0.05, 0.12, 0.12, 0.22))
	return b.mesh()

## One penny about the origin: a rim, a face, a raised ring, a shine, and the
## side's stamp -- a sun with its rays, or a crescent -- so the two are told
## apart by more than their colour.
func _build_penny(look: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var r := PENNY_R
	b.disc(Vector2(0.0, 2.0), r, RIM[look].darkened(0.25))
	b.disc(Vector2.ZERO, r - 1.0, RIM[look])
	b.disc(Vector2(0.0, -1.5), r - 6.0, COIN[look])
	b.stroke(Face.Builder.ring(Vector2.ZERO, r - 12.0, r - 12.0), 2.5, Color(STAMP[look], 0.7), true)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, r - 8.5, PI * 1.08, PI * 1.55), 4.0, Color(SHINE[look], 0.9))
	if look == 0:
		b.disc(Vector2.ZERO, 11.0, STAMP[look])
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0)
			b.stroke(PackedVector2Array([d * 16.5, d * 23.0]), 5.0, STAMP[look])
	else:
		# a crescent: the outer arc of one disc, then back along another's
		var pts := Face.Builder.arc_points(Vector2(-2.0, 0.0), 19.0, PI * 0.32, PI * 1.68)
		var inner := Face.Builder.arc_points(Vector2(7.0, 0.0), 15.5, PI * 1.5, PI * 0.5)
		pts.append_array(inner)
		b.polygon(pts, STAMP[look])
	return b.mesh()

## The light down a column, drawn behind the pennies for column 0.
func _build_glow() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(Vector2(4.0, 0.0), Vector2(U - 8.0, GRID.y), 8.0), Color(1.0, 0.96, 0.8, 0.26))
	return b.mesh()

## What lies over the face: the arrow over the column under the finger, the
## dot on the last penny dropped, the bulb's ring, the rings round a line.
func _build_over() -> ArrayMesh:
	var b := Face.Builder.new()
	if _down and _over >= 0:
		var x := (_over + 0.5) * U
		var full: bool = not rules.can(_over)
		var col := Color(Pal.BAD, 0.9) if full else Color(HALO, 0.95)
		b.stroke(Face.Builder.round_rect(Vector2(_over * U + 3.0, 3.0), Vector2(U - 6.0, GRID.y - 6.0), 12.0), 5.0, col, true)
		var land: int = rules.landing(_over)
		if land >= 0:
			b.stroke(Face.Builder.ring(mid(land), HOLE_R - 7.0, HOLE_R - 7.0), 5.0, Color(HALO, 0.8), true)
		else:
			b.stroke(PackedVector2Array([Vector2(x - 16.0, HOVER_Y - 16.0), Vector2(x + 16.0, HOVER_Y + 16.0)]), 8.0, col)
			b.stroke(PackedVector2Array([Vector2(x + 16.0, HOVER_Y - 16.0), Vector2(x - 16.0, HOVER_Y + 16.0)]), 8.0, col)
	if _last >= 0 and _line.is_empty():
		b.disc(mid(_last), 7.0, Color(HALO, 0.95))
	if _hint >= 0 and rules.landing(_hint) >= 0:
		var at := mid(rules.landing(_hint))
		var beat := 0.0 if Motion.reduce else 0.5 + 0.5 * sin(_t * 5.0)
		b.stroke(Face.Builder.ring(at, HOLE_R - 8.0 + 3.0 * beat, HOLE_R - 8.0 + 3.0 * beat), 7.0, HINT, true)
		var x := (_hint + 0.5) * U
		var tip := Vector2(x, HOVER_Y + 26.0 + 6.0 * beat)
		b.polygon(PackedVector2Array([tip + Vector2(-20.0, -28.0), tip + Vector2(20.0, -28.0), tip]), HINT)
		_busy(0.2)
	if not _line.is_empty():
		var since := _t - _won_at
		for i in _line.size():
			var grow := 1.0 if Motion.reduce else clampf((since - 0.09 * i) / 0.25, 0.0, 1.0)
			if grow <= 0.0:
				continue
			var beat := 0.0 if Motion.reduce else sin(_t * 4.0 + i * 0.7)
			var r := (PENNY_R + 1.0 + 2.5 * beat) * (0.6 + 0.4 * ease(grow, 0.4))
			b.stroke(Face.Builder.ring(mid(_line[i]), r, r), 9.0, HALO, true)
			b.stroke(Face.Builder.ring(mid(_line[i]), r + 7.0, r + 7.0), 3.0, Color(Pal.SUN_RAY, 0.9), true)
		if not Motion.reduce:
			_busy(0.2)
	return null if b.verts.is_empty() else b.mesh()
