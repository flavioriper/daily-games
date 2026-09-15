extends "res://core/puzzle_base_3d.gd"

## Enclose the Horse on the island stage. The board is a meadow of turf cells
## with a few ponds sunk into it, a horse standing somewhere on it and a
## couple of apples lying about. Tap a grass cell to build a fence on it, tap
## the fence to take it down again. The horse walks up, down, left and right,
## never through a fence or a pond; the pen is closed once it can no longer
## reach the edge of the meadow. Every cell it can still reach is penned and
## worth a point, an apple in the pen three more.
##
## The daily framing: the fences come from a limited stock, and the day sets
## a target -- the score of a pen the generator itself managed to close within
## that stock. The puzzle is solved the moment the horse is penned with at
## least the target's worth of meadow. A bigger pen is a better day, and the
## player can keep rebuilding until the stock is spent the way they like.
##
## Tapping the horse shows where it can get to: the reachable meadow goes
## pale, and any edge cell it reaches blushes rose -- that is where the pen
## is open. Check does the same and counts those gaps. The stock and the pen
## are read off the status card in the action row.
## Design: agreed in chat on 2026-09-15 (no spec file by request).

const Gen = preload("res://puzzles/horse_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Toon = preload("res://core/toon.gd")
const Fx = preload("res://world/fx.gd")

## A fence arriving on a cell, and one being taken away.
const POP_TIME := 0.22
const VANISH_LIFT := 0.12
const VANISH_TIME := 0.16
## A refused tap (a pond, an apple, a hinted fence, an empty stock) dips.
const DIP := 0.04
const DIP_TIME := 0.3
const HINTS := 3
const SPARKLE_LIFT := 0.3
## The reach preview: the meadow the horse can get to goes pale, holds, and
## fades back. Quantised so the toon material cache stays bounded.
const REACH_STEPS := 16
const REACH_IN := 0.25
const REACH_HOLD := 1.1
const REACH_OUT := 0.45
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.025
const SOLVE_HOP := 0.18
const SOLVE_TIME := 0.5
const SOLVE_STAGGER := 0.04
## A pond's surface sits this far below the turf top.
const POND_TOP := 0.04

var w: int = 7
var h: int = 7
var _water: Dictionary = {}          # Vector2i -> true
var _horse := Vector2i(-1, -1)
var _apples: Dictionary = {}         # Vector2i -> true
var _budget: int = 8
var _target: int = 0
var _solution_walls: Array = []
var _walls: Dictionary = {}          # Vector2i -> true, a fence the player built
var _locked: Dictionary = {}         # Vector2i -> true, a fence a hint built

var fx: Node3D
var _pads: Array = []                # [r][c] -> Node3D pivot
var _pad_models: Array = []          # [r][c] -> turf model, or null on a pond
var _horse_pivot: Node3D
var _apple_nodes: Dictionary = {}    # Vector2i -> Node3D
var _fences: Dictionary = {}         # Vector2i -> Node3D pivot
var _fence_tw: Dictionary = {}       # Vector2i -> a dip or pop in flight
var _pad_tw: Dictionary = {}         # Vector2i -> a dip in flight
var _reach_tw: Tween
var _reach_cells: Dictionary = {}    # Vector2i -> true when it is a gap on the edge
var _reach_blend := 0.0
var _horse_tw: Tween
var _entrance: Array = []
## One entry per tap that can be taken back: the cell and whether it held a
## fence before the tap.
var _history: Array[Vector3i] = []

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "horse"
func title() -> String: return "Horse Pen"

func rules() -> String:
	return ("Tap grass to build a fence, and tap a fence to take it down. "
		+ "The horse walks up, down, left and right, never through a fence or a pond. "
		+ "Pen it in before it reaches the edge, with at least the target's worth of meadow. "
		+ "Grass counts one, an apple counts three.")

func board_size() -> Vector2i: return Vector2i(w, h)
func board_height() -> float: return Placeholders.TURF_H + Placeholders.HORSE_H
func plane_height() -> float: return Placeholders.TURF_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var ponds := 2
	var apples := 2
	match difficulty:
		0: w = 7; h = 7; _budget = 8; ponds = 2; apples = 2
		1: w = 8; h = 8; _budget = 10; ponds = 3; apples = 3
		_: w = 9; h = 9; _budget = 12; ponds = 4; apples = 3
	var out: Dictionary = Gen.generate(rng, w, h, _budget, ponds, apples)
	_water = {}
	for c in out.water:
		_water[c] = true
	_apples = {}
	for c in out.apples:
		_apples[c] = true
	_horse = out.horse
	_target = int(out.target)
	_solution_walls = out.solution_walls
	_walls = {}
	_locked = {}
	_history = []
	_build_scene()
	_recolour()
	_refit()
	_enter()

## Every fence comes down at once. Hints are unpinned but not refunded.
func reset_board() -> void:
	_stop_entrance()
	_end_reach()
	for cell in _walls.keys():
		_drop_fence(cell)
	_walls = {}
	_locked = {}
	_history = []
	moves = 0
	_recolour()
	fx.cue("reset")

func is_solved() -> bool:
	if _horse.x < 0:
		return false
	return Gen.is_valid_solution(_horse, w, h, _water, _walls, _apples, _budget, _target)

func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if c == _horse:
				out += "🐴"
			elif _water.has(c):
				out += "🟦"
			elif _walls.has(c):
				out += "🟫"
			elif _apples.has(c):
				out += "🍎"
			else:
				out += "🟩"
		out += "\n"
	return out

# --- the rules, as the board reads them ---

## Where the horse can get to right now.
func _reach() -> Dictionary:
	return Gen.reach(_horse, w, h, _water, _walls)

## The pen's score: every reachable cell, apples counting extra. Read by the
## status card and the win harness.
func score() -> int:
	return Gen.score_of(_reach().cells, _apples)

## The stock, then the pen against the target -- but only once there is a
## pen: while the horse is loose the whole meadow is "reachable", and that
## number would only mislead, so the card names the target instead.
func status_text() -> String:
	var r := _reach()
	if r.escaped:
		return "Fences %d / %d  ·  Target %d  ·  Horse loose" % [_walls.size(), _budget, _target]
	var penned := Gen.score_of(r.cells, _apples)
	return "Fences %d / %d  ·  Penned %d / %d  ·  Horse penned" % [_walls.size(), _budget, penned, _target]

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for store in [_fence_tw, _pad_tw]:
		for key in store:
			Motion.stop(store[key])
	Motion.stop(_reach_tw)
	Motion.stop(_horse_tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pads = []
	_pad_models = []
	_apple_nodes = {}
	_fences = {}
	_fence_tw = {}
	_pad_tw = {}
	_reach_cells = {}
	_reach_blend = 0.0

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
			if _water.has(cell):
				pivot.add_child(_pond())
				model_row.append(null)
			else:
				var pad := Models.instance("turf_pad")
				pivot.add_child(pad)
				model_row.append(pad)
				if _apples.has(cell):
					var apple := Models.instance("apple")
					apple.position.y = Placeholders.TURF_H
					pivot.add_child(apple)
					_apple_nodes[cell] = apple
			pad_row.append(pivot)
		_pads.append(pad_row)
		_pad_models.append(model_row)

	_horse_pivot = Node3D.new()
	_horse_pivot.name = "horse"
	_horse_pivot.position = BoardMath.cell_center(_horse.y, _horse.x, w, h, Placeholders.TURF_H)
	board.add_child(_horse_pivot)
	_horse_pivot.add_child(Models.instance("horse"))

## A pond: Shikaku's flagstone sunk into the meadow and wearing the water
## material, so the surface catches the same bands and sparkle as the sea
## around the island. Lower than the turf, so the bank reads as a bank.
func _pond() -> Node3D:
	var pond := Models.instance("plot_pad")
	pond.name = "pond"
	var tall := Models.height(pond)
	if tall > 0.0:
		pond.scale.y = POND_TOP / tall
	for mi in Models.meshes(pond):
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, Toon.water())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pond

# --- fences ---

## Puts the fence cell `cell` should be carrying on the board, or takes the
## one there away. A fence pops up; one that has gone shrinks away and is
## freed. Neighbouring fences are turned so a run reads as one rail.
func _set_fence(cell: Vector2i) -> void:
	if _walls.has(cell) and not _fences.has(cell):
		var pivot := Node3D.new()
		pivot.name = "fence_%d_%d" % [cell.y, cell.x]
		pivot.position = BoardMath.cell_center(cell.y, cell.x, w, h, Placeholders.TURF_H)
		board.add_child(pivot)
		pivot.add_child(Models.instance("fence"))
		_fences[cell] = pivot
		pivot.scale = Vector3.ONE * 0.01
		Motion.stop(_fence_tw.get(cell))
		_fence_tw[cell] = Motion.settle(pivot, "scale", Vector3.ONE, POP_TIME)
		fx.cue("fence")
	elif not _walls.has(cell) and _fences.has(cell):
		_drop_fence(cell)
		fx.cue("unfence")
	for d in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		_orient_fence(cell + d)

## A fence runs along the rail its neighbours make: across when the fences
## beside it are left and right, down the board when they are above and
## below, across by default.
func _orient_fence(cell: Vector2i) -> void:
	if not _fences.has(cell):
		return
	var across := int(_walls.has(cell + Vector2i.LEFT)) + int(_walls.has(cell + Vector2i.RIGHT))
	var down := int(_walls.has(cell + Vector2i.UP)) + int(_walls.has(cell + Vector2i.DOWN))
	(_fences[cell] as Node3D).rotation.y = PI * 0.5 if down > across else 0.0

func _drop_fence(cell: Vector2i) -> void:
	if not _fences.has(cell):
		return
	var gone: Node3D = _fences[cell]
	_fences.erase(cell)
	Motion.stop(_fence_tw.get(cell))
	_fence_tw.erase(cell)
	var tw: Tween = Motion.vanish(gone, VANISH_LIFT, VANISH_TIME)
	if tw == null:
		gone.queue_free()
	else:
		tw.finished.connect(gone.queue_free)

# --- colour ---

## Repaints the fences by whether a hint built them. The meadow keeps its
## colour except during a reach preview, which paints over it and back.
func _recolour() -> void:
	for cell in _fences:
		Models.tint_named(_fences[cell], "Timber", Pal.TIMBER_LOCK if _locked.has(cell) else Pal.TIMBER)

## Shows where the horse can get to: the reachable meadow goes pale, and any
## edge cell it reaches blushes rose. Holds a moment, then fades back.
func _show_reach() -> void:
	_end_reach()
	var r := _reach()
	_reach_cells = {}
	for c in r.cells:
		_reach_cells[c] = false
	for g in r.gaps:
		_reach_cells[g] = true
	var tw := board.create_tween()
	tw.tween_method(_paint_reach, 0.0, 1.0, REACH_IN)
	tw.tween_interval(REACH_HOLD)
	tw.tween_method(_paint_reach, 1.0, 0.0, REACH_OUT)
	_reach_tw = tw

## Puts the meadow back to plain turf at once.
func _end_reach() -> void:
	Motion.stop(_reach_tw)
	_reach_tw = null
	if not _reach_cells.is_empty():
		_paint_reach(0.0)
	_reach_cells = {}

func _paint_reach(blend: float) -> void:
	blend = roundf(blend * REACH_STEPS) / REACH_STEPS
	_reach_blend = blend
	for cell in _reach_cells:
		var pad = _pad_models[cell.y][cell.x]
		if pad == null:
			continue
		var target: Color = Pal.BAD if _reach_cells[cell] else Pal.TURF_REACH
		Models.tint_named(pad, "Turf", Pal.TURF.lerp(target, blend))

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var cell := BoardMath.world_to_cell(hit, w, h)
	if not Gen.in_bounds(cell, w, h):
		return
	if cell == _horse:
		_show_reach()
		fx.cue("horse")
		return
	if _water.has(cell) or _apples.has(cell):
		_dip_pad(cell)
		fx.cue("locked")
		return
	if _locked.has(cell):
		_dip_fence(cell)
		fx.cue("locked")
		return
	if _walls.has(cell):
		_history.append(Vector3i(cell.x, cell.y, 1))
		_walls.erase(cell)
	else:
		if _walls.size() >= _budget:
			# The stock is spent: take one down first.
			_dip_pad(cell)
			fx.cue("locked")
			return
		_history.append(Vector3i(cell.x, cell.y, 0))
		_walls[cell] = true
	_set_fence(cell)
	_recolour()
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

## Takes back the last tap. Counts no move; no state in the history was
## solved, or the game would have ended there.
func undo() -> bool:
	if is_done() or _history.is_empty():
		return false
	var last: Vector3i = _history.pop_back()
	var cell := Vector2i(last.x, last.y)
	if last.z == 1:
		_walls[cell] = true
	else:
		_walls.erase(cell)
	_set_fence(cell)
	_recolour()
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Builds one fence of the generator's own pen and pins it: the first of them
## not already standing. Refused when the stock is spent. Three per puzzle;
## reset unpins them but does not refund them. Counts no move but can finish
## the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	if _walls.size() >= _budget:
		return false
	var target := Vector2i(-1, -1)
	for c in _solution_walls:
		if not _walls.has(c):
			target = c
			break
	if target.x < 0:
		return false
	var kept: Array[Vector3i] = []
	for entry in _history:
		if entry.x != target.x or entry.y != target.y:
			kept.append(entry)
	_history = kept
	_walls[target] = true
	_locked[target] = true
	_set_fence(target)
	fx.sparkle(BoardMath.cell_center(target.y, target.x, w, h, Placeholders.TURF_H + SPARKLE_LIFT))
	fx.cue("hint")
	hints_used += 1
	_recolour()
	moved.emit()
	check_solved()
	return true

## Shows the horse's reach and counts the edge cells it gets to -- the gaps in
## the pen. A closed pen that is still short of the target counts as one
## thing wrong, and the horse shakes its head about it.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var r := _reach()
	_show_reach()
	var wrong: int = r.gaps.size()
	if wrong == 0 and Gen.score_of(r.cells, _apples) < _target:
		wrong = 1
		_wobble_horse()
	fx.cue("check" if wrong > 0 else "check_ok")
	return wrong

# --- motion on one cell ---

func _dip_pad(cell: Vector2i) -> void:
	var pivot: Node3D = _pads[cell.y][cell.x]
	Motion.stop(_pad_tw.get(cell))
	pivot.position.y = 0.0
	_pad_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, 0.0)

func _dip_fence(cell: Vector2i) -> void:
	if not _fences.has(cell):
		return
	var pivot: Node3D = _fences[cell]
	Motion.stop(_fence_tw.get(cell))
	pivot.position.y = Placeholders.TURF_H
	_fence_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, Placeholders.TURF_H)

func _wobble_horse() -> void:
	Motion.stop(_horse_tw)
	_horse_pivot.rotation.z = 0.0
	_horse_tw = Motion.wobble(_horse_pivot)

# --- entrance and solve ---

## The board arrives: the platform rises out of the water, the meadow pops in
## along a diagonal wave, then the horse and the apples land on it.
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
	_pop_in(_horse_pivot, ENTER_PLATFORM + ENTER_POP + Motion.stagger(_horse.x + _horse.y, ENTER_STAGGER))
	for cell in _apple_nodes:
		_pop_in(_apple_nodes[cell], ENTER_PLATFORM + ENTER_POP + Motion.stagger(cell.x + cell.y, ENTER_STAGGER))
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
	if _horse_pivot != null and is_instance_valid(_horse_pivot):
		_horse_pivot.scale = Vector3.ONE
	for cell in _apple_nodes:
		(_apple_nodes[cell] as Node3D).scale = Vector3.ONE

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## The horse kicks up its heels and every fence in the pen hops once, in the
## order they were built: the pen is closed.
func _on_solved() -> void:
	_end_reach()
	Motion.stop(_horse_tw)
	_horse_tw = Motion.hop(_horse_pivot, SOLVE_HOP, SOLVE_TIME, 0.0, Placeholders.TURF_H)
	var i := 0
	for cell in _fences.keys():
		Motion.stop(_fence_tw.get(cell))
		_fence_tw[cell] = Motion.hop(_fences[cell], SOLVE_HOP * 0.5, SOLVE_TIME,
			Motion.stagger(i, SOLVE_STAGGER), Placeholders.TURF_H)
		i += 1
	fx.sparkle(_horse_pivot.position + Vector3(0.0, Placeholders.HORSE_H, 0.0))
	fx.cue("solved")
