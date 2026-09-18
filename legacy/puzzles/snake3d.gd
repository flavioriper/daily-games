extends "res://legacy/core/stage_board.gd"

## Snake Apple on the island stage. The board is a small walled meadow: turf
## cells with boulders on some of them, a few apples lying about, a burrow,
## and the snake itself -- a head from Blender on a body the board builds as a
## tube along its cells, the way Untangle builds its ropes. Tap the cell in
## front of the head (or anywhere along that row or column), or swipe, and the
## snake slides one cell that way; the tail follows. It may not cross a
## boulder or its own body, and it never turns back on itself. Eating an apple
## makes it a cell longer. Once every apple is eaten the burrow opens, and
## slipping the head into it ends the day: the whole snake pours in after it.
##
## The room is the puzzle. A careless route coils the snake up with nowhere to
## go, so Check asks the solver whether the day can still be finished from
## here, and a hint makes the next move of the shortest way out. Undo takes a
## move back.
## Design: agreed in chat on 2026-09-15 (no spec file by request).

const Gen = preload("res://legacy/puzzles/snake_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://legacy/core/models.gd")
const Placeholders = preload("res://legacy/core/placeholders.gd")
const Platform = preload("res://legacy/core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Toon = preload("res://legacy/core/toon.gd")
const Fx = preload("res://legacy/world/fx.gd")

## One cell of travel. The state change itself, so it plays under
## reduce-motion too, shortened.
const SLIDE_TIME := 0.16
## The snake pouring into the burrow at the end.
const SWALLOW_TIME := 0.9
## A refused move: the head shakes.
const HINTS := 3
const SPARKLE_LIFT := 0.5
## A swipe shorter than this, in cells, is a tap.
const SWIPE_MIN := 0.45
## The body tube: radius, sides, and samples per cell of spine.
const TUBE_R := 0.13
const TUBE_RADIAL := 8
const TUBE_SAMPLES := 6
## How far the tube starts behind the head's centre, so the joint is inside
## the head model.
const TUBE_SETBACK := 0.1
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.03
const VANISH_LIFT := 0.25
const VANISH_TIME := 0.2
const DIP := 0.04
const DIP_TIME := 0.3

var w: int = 5
var h: int = 6
var _walls: Dictionary = {}          # Vector2i -> true, a boulder
var _apples: Dictionary = {}         # Vector2i -> true, every apple the day has
var _eaten: Dictionary = {}          # Vector2i -> true
var _hole := Vector2i(-1, -1)
var _snake: Array = []               # head first
var _start_snake: Array = []
var _solution: Array = []            # the generator's shortest run, for the harness
## One entry per move that can be taken back: the snake and the apples eaten
## before it.
var _history: Array = []

var fx: Node3D
var _pads: Array = []                # [r][c] -> Node3D pivot
var _pad_models: Array = []
var _pad_tw: Dictionary = {}
var _apple_nodes: Dictionary = {}    # Vector2i -> Node3D
var _apple_tw: Dictionary = {}
var _stone_nodes: Dictionary = {}
var _burrow: Node3D
var _snake_root: Node3D              # head and body together, for the entrance
var _head: Node3D
var _body: MeshInstance3D
var _slide_tw: Tween
var _swallow_tw: Tween
var _head_tw: Tween
var _entrance: Array = []
## The spine being drawn: the cells before and after the move in flight, and
## how far along it is.
var _spine_from: Array = []
var _spine_to: Array = []
var _spine_t := 1.0
var _press_hit := Vector3.ZERO

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "snake"
func title() -> String: return "Snake Apple"

func rules() -> String:
	return ("Tap ahead of the snake, or swipe, to slide it one cell. "
		+ "It cannot cross boulders or its own body, and it never turns back. "
		+ "Every apple eaten makes it longer. "
		+ "Eat them all, then slip into the burrow.")

func board_size() -> Vector2i: return Vector2i(w, h)
func board_height() -> float: return Placeholders.TURF_H + Placeholders.SNAKE_HEAD_H
func plane_height() -> float: return Placeholders.TURF_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var length := 3
	var apples := 2
	var steps := Vector2i(10, 14)
	var fill := 0.6
	match difficulty:
		0: w = 5; h = 6; length = 3; apples = 2; steps = Vector2i(10, 14); fill = 0.6
		1: w = 6; h = 7; length = 4; apples = 3; steps = Vector2i(16, 22); fill = 0.7
		_: w = 6; h = 8; length = 5; apples = 4; steps = Vector2i(22, 30); fill = 0.8
	var out: Dictionary = Gen.generate(rng, w, h, length, apples, steps.x, steps.y, fill)
	_walls = {}
	for c in out.walls:
		_walls[c] = true
	_apples = {}
	for c in out.apples:
		_apples[c] = true
	_eaten = {}
	_hole = out.hole
	_start_snake = (out.snake as Array).duplicate()
	_snake = _start_snake.duplicate()
	_solution = out.solution
	_history = []
	_build_scene()
	_refit()
	_enter()

## Back to the start: the snake where it lay, every apple back on the grass.
func reset_board() -> void:
	_stop_entrance()
	Motion.stop(_slide_tw)
	_snake = _start_snake.duplicate()
	_eaten = {}
	_history = []
	moves = 0
	_snap_spine()
	_refresh_apples()
	_paint_burrow()
	fx.cue("reset")

## The head is in the burrow with every apple eaten.
func is_solved() -> bool:
	if _snake.is_empty():
		return false
	return _snake[0] == _hole and _eaten.size() == _apples.size()

func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not _snake.is_empty() and c == _snake[0]:
				out += "🐍"
			elif _snake.has(c):
				out += "🟢"
			elif _walls.has(c):
				out += "⬜"
			elif c == _hole:
				out += "🕳️"
			elif _apples.has(c) and not _eaten.has(c):
				out += "🍎"
			else:
				out += "🟩"
		out += "\n"
	return out

func status_text() -> String:
	var burrow := "burrow open" if _eaten.size() == _apples.size() else "burrow shut"
	return "Apples %d / %d  ·  Length %d\n%s" % [_eaten.size(), _apples.size(), _snake.size(), burrow]

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for store in [_pad_tw, _apple_tw]:
		for key in store:
			Motion.stop(store[key])
	Motion.stop(_slide_tw)
	Motion.stop(_swallow_tw)
	Motion.stop(_head_tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pads = []
	_pad_models = []
	_pad_tw = {}
	_apple_nodes = {}
	_apple_tw = {}
	_stone_nodes = {}

	board.add_child(Platform.build(w, h))
	fx = Fx.new()
	board.add_child(fx)

	for r in h:
		var pad_row := []
		var model_row := []
		for c in w:
			var cell := Vector2i(c, r)
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [r, c]
			pivot.position = BoardMath.cell_center(r, c, w, h)
			board.add_child(pivot)
			var pad := Models.instance("turf_pad")
			pivot.add_child(pad)
			if _walls.has(cell):
				Models.tint_named(pad, "Turf", Pal.TURF_TREE)
				var stone := _boulder()
				stone.position.y = Placeholders.TURF_H
				pivot.add_child(stone)
				_stone_nodes[cell] = stone
			elif _apples.has(cell):
				var apple := Models.instance("apple")
				apple.position.y = Placeholders.TURF_H
				pivot.add_child(apple)
				_apple_nodes[cell] = apple
			elif cell == _hole:
				_burrow = Models.instance("burrow")
				_burrow.position.y = Placeholders.TURF_H
				pivot.add_child(_burrow)
			pad_row.append(pivot)
			model_row.append(pad)
		_pads.append(pad_row)
		_pad_models.append(model_row)

	_snake_root = Node3D.new()
	_snake_root.name = "snake"
	board.add_child(_snake_root)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = ArrayMesh.new()
	_snake_root.add_child(_body)
	_head = Node3D.new()
	_head.name = "head"
	_snake_root.add_child(_head)
	_head.add_child(Models.instance("snake_head"))
	_snap_spine()
	_paint_burrow()

## A boulder: Light Up's wall block with its numerals hidden, in the grey of
## Shikaku's dry-stone walls, as Horse Pen lays them.
func _boulder() -> Node3D:
	var block := Models.instance("wall_block")
	block.name = "boulder"
	for d in range(0, 5):
		Models.set_layer_visible(block, "Block_Num_%d" % d, false)
	Models.tint_named(block, "Block", Pal.WALL_STONE)
	block.scale = Vector3(0.8, 0.9, 0.8)
	return block

## The burrow's rim: earth while apples remain, moss once it is open.
func _paint_burrow() -> void:
	if _burrow == null or not is_instance_valid(_burrow):
		return
	var open := _eaten.size() == _apples.size()
	Models.tint_named(_burrow, "Earth", Pal.MOSS if open else Pal.EARTH)

## Every apple not yet eaten stands on its cell; the rest are hidden. Undo and
## reset call this; a move eats its apple with a vanish instead.
func _refresh_apples() -> void:
	for cell in _apple_nodes:
		var node: Node3D = _apple_nodes[cell]
		Motion.stop(_apple_tw.get(cell))
		var show := not _eaten.has(cell)
		node.visible = show
		if show:
			node.scale = Vector3.ONE
			node.position.y = Placeholders.TURF_H

# --- the spine ---

func _cell_world(c: Vector2i) -> Vector3:
	return BoardMath.cell_center(c.y, c.x, w, h, Placeholders.TURF_H + TUBE_R)

## Draws the snake exactly on its cells, no move in flight.
func _snap_spine() -> void:
	Motion.stop(_slide_tw)
	_spine_from = _snake.duplicate()
	_spine_to = _snake.duplicate()
	_spine_t = 1.0
	_draw_spine()

## Starts the slide from the cells before the move to the cells after it.
func _slide(before: Array) -> void:
	Motion.stop(_slide_tw)
	_spine_from = before
	_spine_to = _snake.duplicate()
	_spine_t = 0.0
	if Motion.reduce:
		_spine_t = 1.0
		_draw_spine()
		return
	_draw_spine()
	_slide_tw = board.create_tween()
	_slide_tw.tween_method(_slide_step, 0.0, 1.0, SLIDE_TIME)

func _slide_step(t: float) -> void:
	_spine_t = t
	_draw_spine()

## The spine's world points right now, head first: the head partway into its
## new cell, the tail partway out of its old one (or still on it while the
## snake grows), the cells between where they are.
func _spine_points() -> Array:
	var pts: Array = []
	var to: Array = _spine_to
	var from: Array = _spine_from
	if to.is_empty():
		return pts
	if is_equal_approx(_spine_t, 1.0) or from.is_empty():
		for c in to:
			pts.append(_cell_world(c))
		return pts
	# The head: from its old cell toward its new one.
	pts.append(_cell_world(from[0]).lerp(_cell_world(to[0]), _spine_t))
	# The cells the body still covers: to[1..] are from[0..]; the last of them
	# is the tail, which slides toward the cell ahead of it unless the snake
	# grew this move (then `to` is longer and the tail stays).
	var grew := to.size() > from.size()
	for i in range(1, to.size()):
		var c: Vector2i = to[i]
		if i == to.size() - 1 and not grew:
			pts.append(_cell_world(from[from.size() - 1]).lerp(_cell_world(c), _spine_t))
		else:
			pts.append(_cell_world(c))
	return pts

## Rebuilds the body tube and places the head from the spine points.
func _draw_spine() -> void:
	var pts := _spine_points()
	if pts.is_empty():
		return
	var head_at: Vector3 = pts[0]
	var facing: Vector3 = Vector3.RIGHT
	if pts.size() > 1:
		facing = (head_at - (pts[1] as Vector3))
		if facing.length() < 1e-4:
			facing = Vector3.RIGHT
		facing = facing.normalized()
	elif not _spine_to.is_empty() and not _spine_from.is_empty():
		var d: Vector2i = _spine_to[0] - _spine_from[0]
		if d != Vector2i.ZERO:
			facing = Vector3(d.x, 0.0, d.y).normalized()
	_head.position = head_at - Vector3(0.0, TUBE_R, 0.0)
	_head.rotation.y = atan2(-facing.z, facing.x)
	# The tube runs from just behind the head to the tail.
	var spine: Array = pts.duplicate()
	spine[0] = head_at - facing * TUBE_SETBACK
	_build_tube(_smooth(spine))

## Catmull-Rom through the control points, TUBE_SAMPLES per span, so a turn
## reads as a curve rather than a hinge.
func _smooth(ctrl: Array) -> Array:
	if ctrl.size() < 2:
		return ctrl
	var out: Array = []
	for i in ctrl.size() - 1:
		var p0: Vector3 = ctrl[maxi(i - 1, 0)]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[mini(i + 2, ctrl.size() - 1)]
		for s in TUBE_SAMPLES:
			var t := float(s) / float(TUBE_SAMPLES)
			out.append(_catmull(p0, p1, p2, p3, t))
	out.append(ctrl[ctrl.size() - 1])
	return out

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## The tube along `pts`, as Untangle builds a rope: a ring of TUBE_RADIAL
## vertices at each point, quads between rings, a cap at the tail. The outline
## shell shares the mesh, so it follows.
func _build_tube(pts: Array) -> void:
	var mesh: ArrayMesh = _body.mesh
	mesh.clear_surfaces()
	if pts.size() < 2:
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := pts.size()
	for k in n:
		var tangent: Vector3
		if k == 0:
			tangent = (pts[1] as Vector3) - (pts[0] as Vector3)
		elif k == n - 1:
			tangent = (pts[k] as Vector3) - (pts[k - 1] as Vector3)
		else:
			tangent = (pts[k + 1] as Vector3) - (pts[k - 1] as Vector3)
		if tangent.length() < 1e-6:
			tangent = Vector3.RIGHT
		tangent = tangent.normalized()
		var side := tangent.cross(Vector3.UP)
		if side.length() < 1e-4:
			side = tangent.cross(Vector3.FORWARD)
		side = side.normalized()
		var up := side.cross(tangent).normalized()
		# The tail tapers over its last cell.
		var taper := 1.0
		var from_end := n - 1 - k
		if from_end < TUBE_SAMPLES:
			taper = 0.35 + 0.65 * float(from_end) / float(TUBE_SAMPLES)
		for r in TUBE_RADIAL:
			var ang := TAU * float(r) / float(TUBE_RADIAL)
			var dir := side * cos(ang) + up * sin(ang)
			verts.append((pts[k] as Vector3) + dir * TUBE_R * taper)
			norms.append(dir)
	for k in n - 1:
		for r in TUBE_RADIAL:
			var r2 := (r + 1) % TUBE_RADIAL
			var a0 := k * TUBE_RADIAL + r
			var a1 := k * TUBE_RADIAL + r2
			var b0 := (k + 1) * TUBE_RADIAL + r
			var b1 := (k + 1) * TUBE_RADIAL + r2
			idx.append_array([a0, a1, b0, a1, b1, b0])
	# Caps at both ends: a fan to a centre vertex each.
	var centre := verts.size()
	var tail_tangent: Vector3 = ((pts[n - 1] as Vector3) - (pts[n - 2] as Vector3)).normalized()
	verts.append(pts[n - 1] as Vector3)
	norms.append(tail_tangent)
	for r in TUBE_RADIAL:
		var r2 := (r + 1) % TUBE_RADIAL
		idx.append_array([(n - 1) * TUBE_RADIAL + r, centre, (n - 1) * TUBE_RADIAL + r2])
	var front := verts.size()
	var front_tangent: Vector3 = ((pts[0] as Vector3) - (pts[1] as Vector3)).normalized()
	verts.append(pts[0] as Vector3)
	norms.append(front_tangent)
	for r in TUBE_RADIAL:
		var r2 := (r + 1) % TUBE_RADIAL
		idx.append_array([r2, front, r])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_body.set_surface_override_material(0, Toon.material(Pal.SCALE))
	Toon.add_outline(_body)

# --- moves ---

## Slides the snake by `d` if the rules allow. Eats the apple it lands on.
func _try_move(d: Vector2i) -> bool:
	if is_done() or _snake.is_empty():
		return false
	if not Gen.can_move(d, _snake, _walls, _apples, _eaten, _hole, w, h):
		_shake_head()
		fx.cue("locked")
		return false
	_history.append({"snake": _snake.duplicate(), "eaten": _eaten.duplicate()})
	var before: Array = _snake.duplicate()
	var n: Vector2i = _snake[0] + d
	_snake = Gen.moved(d, _snake, _apples, _eaten)
	if _apples.has(n) and not _eaten.has(n):
		_eaten[n] = true
		_eat(n)
	_slide(before)
	_paint_burrow()
	fx.cue("slide")
	return true

## The apple on `cell` is gone: it lifts and shrinks, with a puff.
func _eat(cell: Vector2i) -> void:
	var node: Node3D = _apple_nodes.get(cell)
	if node == null:
		return
	Motion.stop(_apple_tw.get(cell))
	node.visible = true
	var tw: Tween = Motion.vanish(node, VANISH_LIFT, VANISH_TIME)
	_apple_tw[cell] = tw
	fx.puff(BoardMath.cell_center(cell.y, cell.x, w, h, Placeholders.TURF_H + 0.2), Pal.FRUIT)
	fx.cue("eat")

func _shake_head() -> void:
	Motion.stop(_head_tw)
	_head.rotation.z = 0.0
	_head_tw = Motion.wobble(_head)

# --- input ---

func on_board_press(hit: Vector3) -> void:
	_press_hit = hit

## A swipe of at least SWIPE_MIN cells moves along its longer axis; anything
## shorter is a tap, which moves toward the tapped cell when it lies in the
## head's row or column.
func on_board_release(hit: Vector3) -> void:
	if _snake.is_empty():
		return
	var delta := Vector2(hit.x - _press_hit.x, hit.z - _press_hit.z)
	var d := Vector2i.ZERO
	if delta.length() >= SWIPE_MIN:
		d = Vector2i(signi(int(roundf(delta.x * 100.0))), 0) if absf(delta.x) >= absf(delta.y) \
			else Vector2i(0, signi(int(roundf(delta.y * 100.0))))
	else:
		var cell := BoardMath.world_to_cell(_press_hit, w, h)
		if not Gen.in_bounds(cell, w, h):
			return
		var head: Vector2i = _snake[0]
		if cell == head:
			_shake_head()
			fx.cue("horse")
			return
		if cell.x == head.x:
			d = Vector2i(0, signi(cell.y - head.y))
		elif cell.y == head.y:
			d = Vector2i(signi(cell.x - head.x), 0)
		else:
			_dip_pad(cell)
			fx.cue("locked")
			return
	if d == Vector2i.ZERO:
		return
	if _try_move(d):
		note_move()

## Control-local point over the centre of cell (r, c). The win harness taps
## this.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, w, h, plane_height()))

# --- capabilities ---

func capabilities() -> Array[String]:
	return ["undo", "hint", "check", "status"]

func can_undo() -> bool:
	return not is_done() and not _history.is_empty()

## Takes the last move back: the snake and the apples as they were.
func undo() -> bool:
	if is_done() or _history.is_empty():
		return false
	var last: Dictionary = _history.pop_back()
	_snake = (last.snake as Array).duplicate()
	_eaten = (last.eaten as Dictionary).duplicate()
	_snap_spine()
	_refresh_apples()
	_paint_burrow()
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Makes the next move of the shortest way to finish from here. Refused when
## there is none -- the snake is stuck, and Check will say so. Counts no move
## but can finish the day.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or _snake.is_empty():
		return false
	var path: Array = Gen.solve(w, h, _walls, _apples, _hole, _snake, _eaten)
	if path.is_empty():
		_shake_head()
		fx.cue("locked")
		return false
	if not _try_move(path[0]):
		return false
	hints_used += 1
	fx.sparkle(_cell_world(_snake[0]) + Vector3(0.0, SPARKLE_LIFT, 0.0))
	fx.cue("hint")
	moved.emit()
	check_solved()
	return true

## Asks the solver whether the day can still be finished from here: 0 when it
## can, 1 when the snake has coiled itself into a corner.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var path: Array = Gen.solve(w, h, _walls, _apples, _hole, _snake, _eaten)
	if path.is_empty():
		_shake_head()
		fx.cue("check")
		return 1
	fx.cue("check_ok")
	return 0

# --- motion on one cell ---

func _dip_pad(cell: Vector2i) -> void:
	var pivot: Node3D = _pads[cell.y][cell.x]
	Motion.stop(_pad_tw.get(cell))
	pivot.position.y = 0.0
	_pad_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, 0.0)

# --- entrance and solve ---

## The board arrives: the platform rises out of the water, the meadow pops in
## along a diagonal wave, then the boulders, the apples, the burrow and the
## snake land on it.
func _enter() -> void:
	_stop_entrance()
	var platform: Node3D = board.get_node("Platform")
	platform.position.y = -ENTER_DROP
	var rise: Tween = Motion.settle(platform, "position:y", 0.0, ENTER_PLATFORM)
	if rise != null:
		_entrance.append(rise)
		var splash := board.create_tween()
		splash.tween_interval(ENTER_PLATFORM * 0.9)
		splash.tween_callback(_splash)
		_entrance.append(splash)
	for r in h:
		for c in w:
			_pop_in(_pads[r][c], ENTER_PLATFORM + Motion.stagger(r + c, ENTER_STAGGER))
	for store in [_apple_nodes, _stone_nodes]:
		for cell in store:
			_pop_in(store[cell], ENTER_PLATFORM + ENTER_POP + Motion.stagger(cell.x + cell.y, ENTER_STAGGER))
	if _burrow != null:
		_pop_in(_burrow, ENTER_PLATFORM + ENTER_POP + Motion.stagger(_hole.x + _hole.y, ENTER_STAGGER))
	_pop_in(_snake_root, ENTER_PLATFORM + ENTER_POP * 2.0)
	fx.cue("enter")

func _pop_in(node: Node3D, delay: float) -> void:
	node.scale = Vector3.ONE * 0.01
	var pop: Tween = Motion.settle(node, "scale", Vector3.ONE, ENTER_POP, delay)
	if pop != null:
		_entrance.append(pop)

func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	var platform: Node3D = board.get_node_or_null("Platform")
	if platform != null:
		platform.position.y = 0.0
	for row in _pads:
		for pivot in row:
			(pivot as Node3D).scale = Vector3.ONE
	for cell in _apple_nodes:
		(_apple_nodes[cell] as Node3D).scale = Vector3.ONE
	for cell in _stone_nodes:
		(_stone_nodes[cell] as Node3D).scale = Vector3(0.8, 0.9, 0.8)
	if _burrow != null and is_instance_valid(_burrow):
		_burrow.scale = Vector3.ONE
	if _snake_root != null and is_instance_valid(_snake_root):
		_snake_root.scale = Vector3.ONE

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## The snake pours into the burrow: the head shrinks away first, then the
## body follows it down cell by cell until nothing is left on the grass.
func _on_solved() -> void:
	Motion.stop(_slide_tw)
	_spine_t = 1.0
	_spine_from = _snake.duplicate()
	_spine_to = _snake.duplicate()
	Motion.stop(_head_tw)
	_head_tw = Motion.settle(_head, "scale", Vector3.ONE * 0.01, SLIDE_TIME * 1.5, 0.0, true)
	fx.puff(_cell_world(_hole), Pal.EARTH)
	fx.cue("solved")
	Motion.stop(_swallow_tw)
	if Motion.reduce:
		_body.visible = false
		return
	_swallow_tw = board.create_tween()
	_swallow_tw.tween_method(_swallow_step, 0.0, 1.0, SWALLOW_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_swallow_tw.tween_callback(func() -> void: _body.visible = false)

## Progress `s` of the pour: the tube's front has travelled `s` of the spine's
## length from the head toward the tail, and everything ahead of it is gone.
func _swallow_step(s: float) -> void:
	var ctrl: Array = []
	for c in _snake:
		ctrl.append(_cell_world(c))
	if ctrl.size() < 2:
		return
	var pts := _smooth(ctrl)
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i + 1] as Vector3).distance_to(pts[i])
	var cut := s * total
	var run := 0.0
	var kept: Array = []
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := a.distance_to(b)
		if run + seg <= cut:
			run += seg
			continue
		if kept.is_empty():
			var t := (cut - run) / maxf(seg, 1e-6)
			kept.append(a.lerp(b, t))
		kept.append(b)
		run += seg
	if kept.size() < 2:
		_body.visible = false
		return
	_build_tube(kept)
