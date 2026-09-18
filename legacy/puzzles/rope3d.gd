extends "res://legacy/core/stage_board.gd"

## The Rope on the island stage. The board is a plank ruled into squares with
## numbered pegs turned out of the same timber standing on some of them. Lay
## one rope from peg 1 over every square, meeting the pegs in their order:
## press the rope's end and drag, and the rope follows your finger a square at
## a time. Drag back over the square behind and it takes itself in again; press
## a square the rope already lies on and it winds back to there.
##
## Why it can be drawn by tapping as well as dragging: a tap on a square next
## to the rope's end lays that one square. It is the precise way to place the
## last squares on a phone, and it is what lets the win harness draw a whole
## rope through real touch events.
##
## Winning is checked against the rule -- every square covered, every peg in
## turn, the last peg last -- and never against the rope the generator laid.
## That rope is only the hint's shortcut: while the player is still on it the
## hint reads the next square straight off it, and only once they have left it
## does the solver run (puzzles/rope_gen.gd has the measurements).
## Design: agreed in chat on 2026-09-17 (no spec file by request).

const Gen = preload("res://legacy/puzzles/rope_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://legacy/core/models.gd")
const Placeholders = preload("res://legacy/core/placeholders.gd")
const Platform = preload("res://legacy/core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Toon = preload("res://legacy/core/toon.gd")
const Fx = preload("res://legacy/world/fx.gd")

const HINTS := 3
## The rope: radius, sides, and samples per square of spine. Eight sides and
## four samples keep a 49-square rope under three thousand vertices, which is
## the mesh the board rebuilds on every square laid.
const TUBE_R := 0.15
const TUBE_RADIAL := 8
const TUBE_SAMPLES := 4
## A peg stands this much taller and this much narrower than the marker stone
## it is cut from. Both are needed: at the stone's own height the rope laid
## over its square buried it and its number with it, and at the stone's own
## width there was no square left around it for the rope to read through.
const PEG_TALL := 2.4
const PEG_SLIM := 0.72
## A refused square: the peg it was refused for dips, or the rope's end does.
const DIP := 0.05
const DIP_TIME := 0.3
const CHECK_IN := 0.15
const CHECK_OUT := 0.45
const BLUSH_STEPS := 16
const SPARKLE_LIFT := 0.3
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.025
const SOLVE_HOP := 0.08
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.04

var w: int = 5
var h: int = 5
var _pegs: Array = []            # Vector2i, in playing order
var _peg_at: Dictionary = {}     # Vector2i -> its place in the order
var _path: Array = []            # the rope the generator laid
var _rope: Array = []            # the rope the player has laid
var _on: Dictionary = {}         # Vector2i -> its place along _rope
## Where the last check said the rope stopped being finishable, -1 when it
## said nothing. Cleared by the next square laid or taken in.
var _bad_from: int = -1
## One entry per gesture that changed the rope: the rope as it was before.
var _history: Array = []
## The rope as this gesture found it, and whether a press is still down.
var _gesture: Array = []
var _drag: bool = false

var fx: Node3D
var _pads: Array = []            # [r][c] -> Node3D pivot
var _pad_models: Array = []      # [r][c] -> the plot_pad under it
var _peg_pivots: Array = []
var _peg_models: Array = []
var _peg_tw: Array = []
var _rope_mesh: MeshInstance3D
var _entrance: Array = []

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "rope"
func title() -> String: return "The Rope"

func rules() -> String:
	return "Lay one rope from peg 1 over every square, meeting the pegs in order. Drag from the rope's end, drag back to take it in, and press a square it already covers to wind back to there."

func board_size() -> Vector2i: return Vector2i(w, h)
func board_height() -> float: return Placeholders.PLOT_H + Placeholders.CLUE_H * PEG_TALL
func plane_height() -> float: return Placeholders.PLOT_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var pegs := 4
	match difficulty:
		0: w = 5; h = 5; pegs = 4
		1: w = 6; h = 6; pegs = 6
		_: w = 7; h = 7; pegs = 8
	var out: Dictionary = Gen.generate(rng, w, h, pegs)
	_pegs = out.pegs
	_path = out.path
	_peg_at = {}
	for i in _pegs.size():
		_peg_at[_pegs[i]] = i
	_clear_rope()
	_history = []
	_build_scene()
	_recolour()
	_draw_rope()
	_refit()
	_enter()

## The rope comes off the board and the pegs are all to meet again.
func reset_board() -> void:
	_stop_entrance()
	_clear_rope()
	_history = []
	moves = 0
	_recolour()
	_draw_rope()
	fx.cue("reset")

func _clear_rope() -> void:
	_rope = []
	_on = {}
	_bad_from = -1
	_drag = false
	_gesture = []

## Checked against the rule, not against the stored rope: every square
## covered once, every peg met in its turn, and the last peg last.
func is_solved() -> bool:
	if _pegs.is_empty() or _rope.size() != w * h:
		return false
	var need := 0
	for i in _rope.size():
		var c: Vector2i = _rope[i]
		if i > 0 and not Gen.adjacent(_rope[i - 1], c):
			return false
		if _peg_at.has(c):
			if int(_peg_at[c]) != need:
				return false
			need += 1
	return need == _pegs.size() and _rope[_rope.size() - 1] == _pegs[_pegs.size() - 1]

func share_glyphs() -> String:
	return "🪢 %d squares, one rope" % (w * h)

func status_text() -> String:
	return "Squares %d / %d  ·  Pegs %d / %d" % [_rope.size(), w * h, _pegs_met(), _pegs.size()]

# --- the rule, as the board reads it ---

## How many pegs the rope has met. They can only be met in order, so this is
## how far along the pegs it has got.
func _pegs_met() -> int:
	var met := 0
	for peg in _pegs:
		if not _on.has(peg):
			break
		met += 1
	return met

## Whether the rope may be taken into square `c` next.
func _may_extend(c: Vector2i) -> bool:
	if is_done() or c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or _on.has(c):
		return false
	if _rope.is_empty():
		return c == _pegs[0]
	if not Gen.adjacent(_rope[_rope.size() - 1], c):
		return false
	if not _peg_at.has(c):
		return true
	var peg: int = _peg_at[c]
	if peg != _pegs_met():
		return false
	# The rope ends on the last peg, so it is reached on the last square of
	# all: laying it sooner would end the rope with the board half bare.
	return peg < _pegs.size() - 1 or _rope.size() + 1 == w * h

func _extend(c: Vector2i) -> void:
	_on[c] = _rope.size()
	_rope.append(c)
	_bad_from = -1

## Takes the rope's last square back in. False when there is none.
func _unwind() -> bool:
	if _rope.is_empty():
		return false
	_on.erase(_rope.pop_back())
	_bad_from = -1
	return true

## Winds the rope back to `length` squares.
func _wind_to(length: int) -> void:
	while _rope.size() > length:
		_unwind()

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var cell := BoardMath.world_to_cell(hit, w, h)
	if cell.x < 0:
		return
	_gesture = _rope.duplicate()
	_drag = true
	if _on.has(cell):
		# A square the rope already covers: wind back to it. Pressing its own
		# end changes nothing and simply takes hold of the rope.
		_wind_to(int(_on[cell]) + 1)
		_after_change()
		return
	_step_to(cell)

func on_board_drag(hit: Vector3) -> void:
	if not _drag:
		return
	var cell := BoardMath.world_to_cell(hit, w, h)
	if cell.x < 0:
		return
	if _on.has(cell):
		# Dragging back over the square behind takes the rope in, one square
		# at a time. Dragging across the middle of it winds back to there.
		if int(_on[cell]) + 1 == _rope.size():
			return
		_wind_to(int(_on[cell]) + 1)
		_after_change()
		return
	_step_to(cell)

func on_board_release(_hit: Vector3) -> void:
	if not _drag:
		return
	_drag = false
	_commit()

## Lays one square if the rule allows, and says why with a dip if it does not.
## A finger crossing two squares in one frame lays neither: only a square next
## to the rope's end is ever taken, so a fast drag lays a shorter rope rather
## than a rope that jumps.
func _step_to(cell: Vector2i) -> void:
	if _may_extend(cell):
		_extend(cell)
		_after_change()
		return
	if not _drag:
		return
	_refuse(cell)

## The board's answer to a square it will not take: the peg that is out of
## turn dips, or the one the rope has still to reach does.
func _refuse(cell: Vector2i) -> void:
	var point := _pegs_met()
	if _peg_at.has(cell) and int(_peg_at[cell]) != point:
		point = int(_peg_at[cell])
	if point < _pegs.size():
		_dip_peg(point)
	fx.cue("locked")

## Everything a change to the rope drives, short of ending the gesture.
func _after_change() -> void:
	_recolour()
	_draw_rope()
	if _drag and is_solved():
		# The last square can land mid-drag; the day ends there rather than
		# waiting for the finger to come up.
		_drag = false
		_commit()

## Ends a gesture: one move if the rope came out different, nothing if the
## finger only rested on it.
func _commit() -> void:
	if _rope == _gesture:
		return
	_history.append(_gesture)
	_gesture = _rope.duplicate()
	note_move()

## Control-local point over the centre of square (r, c). The win harness taps
## these, as it does on every other board.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, w, h, plane_height()))

# --- capabilities ---

func capabilities() -> Array[String]:
	return ["undo", "hint", "check", "status"]

func can_undo() -> bool:
	return not is_done() and not _history.is_empty()

## Takes back the last stroke, however many squares it laid or took in.
func undo() -> bool:
	if is_done() or _history.is_empty():
		return false
	var before: Array = _history.pop_back()
	_rope = before.duplicate()
	_on = {}
	for i in _rope.size():
		_on[_rope[i]] = i
	_bad_from = -1
	_gesture = _rope.duplicate()
	_recolour()
	_draw_rope()
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## One square of a rope that can still be finished. While the player is on the
## generator's own route that square is read straight off it; once they have
## left it the solver finds a way home from where they actually are. A rope
## that cannot be finished at all gets the other kind of hint: it is wound
## back to the last square it could have been finished from, which is the one
## thing worth knowing at that point.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var next := Vector2i(-1, -1)
	if _rope.is_empty():
		next = _pegs[0]
	elif _follows_stored():
		next = _path[_rope.size()]
	else:
		var out: Dictionary = Gen.complete(w, h, _pegs, _rope, 1)
		if out.paths.is_empty():
			var cut: int = Gen.longest_playable(w, h, _pegs, _rope)
			if cut >= _rope.size():
				return false
			_history.append(_rope.duplicate())
			_wind_to(cut)
			_spend_hint()
			return true
		var answer: Array = out.paths[0]
		next = answer[_rope.size()]
	if not _may_extend(next):
		return false
	_history.append(_rope.duplicate())
	_extend(next)
	_spend_hint()
	return true

## Whether the rope is still on the route the generator laid. A hint on one of
## those costs no search at all, which is what keeps the first hint on a 7 x 7
## instant.
func _follows_stored() -> bool:
	if _rope.size() >= _path.size():
		return false
	for i in _rope.size():
		if _rope[i] != _path[i]:
			return false
	return true

func _spend_hint() -> void:
	_gesture = _rope.duplicate()
	_recolour()
	_draw_rope()
	if not _rope.is_empty():
		fx.sparkle(_cell_world(_rope[_rope.size() - 1]) + Vector3(0.0, SPARKLE_LIFT, 0.0))
	fx.cue("hint")
	hints_used += 1
	moved.emit()
	check_solved()

## Asks whether the rope can still be finished from where it lies, and returns
## how many squares would have to come back off before it can. The squares it
## names blush until the next one is laid. Nothing is undone: the check
## points, the player decides.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	if _rope.size() < 2:
		fx.cue("check_ok")
		return 0
	var cut: int = Gen.longest_playable(w, h, _pegs, _rope)
	var over := _rope.size() - cut
	_bad_from = cut if over > 0 else -1
	_recolour()
	if over > 0:
		_flash_peg(mini(_pegs_met(), _pegs.size() - 1))
	fx.cue("check" if over > 0 else "check_ok")
	return over

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for tw in _peg_tw:
		Motion.stop(tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pads = []
	_pad_models = []
	_peg_pivots = []
	_peg_models = []
	_peg_tw = []

	board.add_child(Platform.build(w, h))
	fx = Fx.new()
	board.add_child(fx)

	for r in h:
		var pad_row := []
		var model_row := []
		for c in w:
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [r, c]
			pivot.position = BoardMath.cell_center(r, c, w, h)
			board.add_child(pivot)
			var pad := Models.instance("plot_pad")
			pivot.add_child(pad)
			pad_row.append(pivot)
			model_row.append(pad)
		_pads.append(pad_row)
		_pad_models.append(model_row)

	for i in _pegs.size():
		var at: Vector2i = _pegs[i]
		var pivot := Node3D.new()
		pivot.name = "peg_%d" % i
		pivot.position = BoardMath.cell_center(at.y, at.x, w, h, Placeholders.PLOT_H)
		board.add_child(pivot)
		var peg := Models.instance("clue_stone")
		# One carved numeral, the way Shikaku's marker stone carries its area.
		# The board never asks for more than eight pegs, so the stone's nine
		# digits are more than it can run out of.
		for d in range(0, 10):
			Models.set_layer_visible(peg, "Clue_Num_%d" % d, d == i + 1)
		peg.scale = Vector3(PEG_SLIM, PEG_TALL, PEG_SLIM)
		pivot.add_child(peg)
		_peg_pivots.append(pivot)
		_peg_models.append(peg)
		_peg_tw.append(null)

	_rope_mesh = MeshInstance3D.new()
	_rope_mesh.name = "Rope"
	_rope_mesh.mesh = ArrayMesh.new()
	board.add_child(_rope_mesh)

# --- colour ---

## Every square and every peg. A square the rope lies on is shaded under it,
## one the last check named blushes, and a peg goes green as its turn passes.
func _recolour() -> void:
	for r in h:
		for c in w:
			var at := Vector2i(c, r)
			var base: Color = Pal.ROPE_FACE
			if _on.has(at):
				base = Pal.ROPE_BAD if (_bad_from >= 0 and int(_on[at]) >= _bad_from) else Pal.ROPE_UNDER
			Models.tint_named(_pad_models[r][c], "Stone", base)
	for i in _peg_models.size():
		_paint_peg(0.0, i)

func _paint_peg(blend: float, i: int) -> void:
	var base: Color = Pal.GOOD if _on.has(_pegs[i]) else Pal.TIMBER
	Models.tint_named(_peg_models[i], "Stone", base.lerp(Pal.BAD, blend))

## A peg dips: a square the board would not take.
func _dip_peg(i: int) -> void:
	if i < 0 or i >= _peg_pivots.size():
		return
	Motion.stop(_peg_tw[i])
	(_peg_pivots[i] as Node3D).position.y = Placeholders.PLOT_H
	_peg_tw[i] = Motion.hop(_peg_pivots[i], -DIP, DIP_TIME, 0.0, Placeholders.PLOT_H)

## A peg shakes and blushes: the check pointing at where the rope went wrong.
func _flash_peg(i: int) -> void:
	if i < 0 or i >= _peg_pivots.size():
		return
	Motion.stop(_peg_tw[i])
	var pivot: Node3D = _peg_pivots[i]
	pivot.rotation.z = 0.0
	Motion.wobble(pivot)
	var setter := _paint_peg.bind(i)
	var tw: Tween = Motion.fade(_peg_models[i], setter, 0.0, 1.0, CHECK_IN, BLUSH_STEPS)
	if tw == null:
		setter.call(0.0)
		_peg_tw[i] = null
		return
	tw.tween_method(setter, 1.0, 0.0, CHECK_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_peg_tw[i] = tw

# --- the rope ---

## Where the rope's middle runs over square `c`: flat on the plank the whole
## way, so it passes behind a peg rather than over it.
func _cell_world(c: Vector2i) -> Vector3:
	return BoardMath.cell_center(c.y, c.x, w, h, Placeholders.PLOT_H + TUBE_R)

func _draw_rope() -> void:
	var pts: Array = []
	for c in _rope:
		pts.append(_cell_world(c))
	_build_tube(_smooth(pts))

## Catmull-Rom through the square centres, TUBE_SAMPLES per span, so a corner
## reads as a bend in a rope rather than a hinge.
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
			out.append(_catmull(p0, p1, p2, p3, float(s) / float(TUBE_SAMPLES)))
	out.append(ctrl[ctrl.size() - 1])
	return out

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## The rope along `pts`, as Snake builds its body and Untangle its mooring
## lines: a ring of TUBE_RADIAL vertices at each point, quads between rings
## and a cap at each end. The outline shell shares the mesh, so it follows.
func _build_tube(pts: Array) -> void:
	var mesh: ArrayMesh = _rope_mesh.mesh
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
		for r in TUBE_RADIAL:
			var ang := TAU * float(r) / float(TUBE_RADIAL)
			var dir := side * cos(ang) + up * sin(ang)
			verts.append((pts[k] as Vector3) + dir * TUBE_R)
			norms.append(dir)
	for k in n - 1:
		for r in TUBE_RADIAL:
			var r2 := (r + 1) % TUBE_RADIAL
			var a0 := k * TUBE_RADIAL + r
			var a1 := k * TUBE_RADIAL + r2
			var b0 := (k + 1) * TUBE_RADIAL + r
			var b1 := (k + 1) * TUBE_RADIAL + r2
			idx.append_array([a0, a1, b0, a1, b1, b0])
	var tail := verts.size()
	verts.append(pts[n - 1] as Vector3)
	norms.append(((pts[n - 1] as Vector3) - (pts[n - 2] as Vector3)).normalized())
	for r in TUBE_RADIAL:
		var r2 := (r + 1) % TUBE_RADIAL
		idx.append_array([(n - 1) * TUBE_RADIAL + r, tail, (n - 1) * TUBE_RADIAL + r2])
	var front := verts.size()
	verts.append(pts[0] as Vector3)
	norms.append(((pts[0] as Vector3) - (pts[1] as Vector3)).normalized())
	for r in TUBE_RADIAL:
		var r2 := (r + 1) % TUBE_RADIAL
		idx.append_array([r2, front, r])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_rope_mesh.set_surface_override_material(0, Toon.material(Pal.ROPE_HEMP))
	Toon.add_outline(_rope_mesh)

# --- entrance and solve ---

## The board arrives: the platform rises out of the water, the squares pop in
## along a diagonal wave, and the pegs follow once their square is there.
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
	for i in _peg_pivots.size():
		var at: Vector2i = _pegs[i]
		_pop_in(_peg_pivots[i], ENTER_PLATFORM + ENTER_POP
			+ Motion.stagger(at.y + at.x, ENTER_STAGGER))
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
	for pivot in _peg_pivots:
		(pivot as Node3D).scale = Vector3.ONE

func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## Every square hops once, in a wave that runs along the rope from peg 1.
func _on_solved() -> void:
	_drag = false
	for i in _rope.size():
		var c: Vector2i = _rope[i]
		Motion.hop(_pads[c.y][c.x], SOLVE_HOP, SOLVE_TIME, Motion.stagger(i, SOLVE_STAGGER, 1.2), 0.0)
	fx.cue("solved")
