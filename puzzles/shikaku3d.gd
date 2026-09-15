extends "res://core/puzzle_base_3d.gd"

## Shikaku on the island stage. The board is a field of stone floor slabs, one
## per cell, with a numbered marker stone standing in each clue's cell. Drag
## corner to corner and the rectangle you enclose becomes a plot: dry-stone
## walls rise around it and its floor turns to tilled earth.
##
## The walls are built from the partition, not from the rectangles. A wall
## stands on a seam exactly when the two sides of that seam belong to
## different plots and at least one of them is claimed -- which is Shikaku's
## rule in stone: two neighbouring plots are divided by one wall, never two,
## and a plot touching the board's edge is closed off by the edge itself. Each
## run of seam becomes one `wall_edge` stretched along its length, and a
## `wall_post` closes every corner and junction, so a board of a dozen plots
## costs a few dozen pieces rather than one per cell of perimeter.
##
## Feedback is on the marker stones: a stone goes green the moment its plot's
## area matches its number and rose when the plot around it is the wrong size,
## so the rule is learned by drawing. A plot holding two numbers, or none, is
## the one thing a stone cannot say, so its floor blushes instead.
## Design: agreed in chat on 2026-09-15 (no spec file by request).

const Gen = preload("res://puzzles/shikaku_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://world/fx.gd")

## The largest area any clue can carry. A marker stone holds one carved
## numeral, the way a plinth does, so the generator is capped at a single
## digit rather than the board growing a two-digit stone: a 12 would have to
## be read off a stone a third of a cell wide at a 68-degree pitch.
const MAX_AREA := 9
## The smallest rectangle worth drawing; a 1 or 2 is forced on sight.
const MIN_AREA := 3

## Wall motion: a run rises out of the floor when its plot is drawn and sinks
## back when the plot goes.
const WALL_RISE := 0.26
const WALL_FALL := 0.18
## Pending drag: the cells inside the rectangle you are dragging lift this far
## and take this much of the accent, so the rectangle reads before you let go.
const PENDING_LIFT := 0.035
const PENDING_TINT := 0.45
## A tap that is refused (a locked plot) answers with a dip instead.
const DIP := 0.035
const DIP_TIME := 0.3
## The blush a floor takes when its plot holds two numbers or none.
const BAD_BLEND := 0.375
const BLUSH_STEPS := 16
const BLUSH_IN := 0.25
const BLUSH_OUT := 0.4
## Check: a marker stone that is not satisfied shakes and flashes.
const CHECK_IN := 0.15
const CHECK_OUT := 0.45
const HINTS := 3
const SPARKLE_LIFT := 0.12
## Entrance and the solved wave.
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.025
const SOLVE_HOP := 0.08
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.04

var w: int = 6
var h: int = 8
var _clues: Array = []          # [{pos: Vector2i, area: int}], the generator's
var _solution: Array = []       # [Rect2i], the partition it came from
var _rects: Array[Rect2i] = []  # the plots the player has drawn
var _locked: Array[bool] = []   # in step with _rects: a plot a hint fixed
## Plot index per cell, -1 where nothing is claimed. Rebuilt from _rects.
var _owner: PackedInt32Array = PackedInt32Array()

var _drag_from := Vector2i(-1, -1)
var _drag_to := Vector2i(-1, -1)
## The pending rectangle last painted, so a drag only repaints when it moves.
var _painted_pending := Rect2i(0, 0, 0, 0)

var fx: Node3D
var _pads: Array = []          # [r][c] -> Node3D pivot at the cell centre
var _pad_models: Array = []    # [r][c] -> the plot_pad model under it
var _blend: Array = []         # [r][c] -> painted blend toward BAD
var _blend_target: Array = []  # [r][c] -> the blend the cell is heading for
var _fades: Array = []         # [r][c] -> a blush fade in flight
var _clue_pivots: Array = []   # [i] -> Node3D at the clue's cell
var _clue_models: Array = []   # [i] -> the clue_stone model
var _clue_tw: Array = []       # [i] -> the dip, shake or flash in flight
## Wall pieces by their own geometry: "<h|v>:<line>:<start>:<len>" -> Node3D.
## A rebuild keeps the runs that survived, so only what changed moves.
var _walls: Dictionary = {}
var _entrance: Array = []
## One entry per move that can be taken back: the plot added (or null when the
## move only cleared one) and the plots it displaced.
var _history: Array[Dictionary] = []

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "shikaku"
func title() -> String: return "Shikaku"

func rules() -> String:
	return "Split the field into plots. Each one holds exactly one number, and that number is its area."

func board_size() -> Vector2i: return Vector2i(w, h)
## The floor slab plus the walls standing on it; the marker stones are shorter.
func board_height() -> float: return Placeholders.PLOT_H + Placeholders.WALL_POST_H
func plane_height() -> float: return Placeholders.PLOT_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var max_area := MAX_AREA
	match difficulty:
		0: w = 5; h = 6; max_area = 6
		1: w = 6; h = 8; max_area = MAX_AREA
		_: w = 7; h = 9; max_area = MAX_AREA
	var out: Dictionary = Gen.generate(rng, w, h, max_area, MIN_AREA)
	_clues = out.clues
	_solution = out.rects
	_rects = []
	_locked = []
	_history = []
	_reown()
	_build_scene()
	_recolour()
	_refit()
	_enter()

## Every plot goes: the walls sink back into the floor, the earth turns to
## stone again and the hints a player spent are not refunded, only unpinned.
func reset_board() -> void:
	_stop_entrance()
	_clear_drag()
	_rects = []
	_locked = []
	_history = []
	moves = 0
	_reown()
	_rebuild_walls()
	_recolour()
	fx.cue("reset")

func is_solved() -> bool:
	# Checked against the rules, not against the stored answer.
	if _clues.is_empty():
		return false
	var covered: Dictionary = {}
	for r in _rects:
		var inside := 0
		for c in _clues:
			if r.has_point(c.pos):
				inside += 1
				if int(c.area) != r.size.x * r.size.y:
					return false
		if inside != 1:
			return false
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
				if covered.has(Vector2i(x, y)):
					return false
				covered[Vector2i(x, y)] = true
	return covered.size() == w * h

func share_glyphs() -> String:
	return "▦ %dx%d · %d moves" % [w, h, moves]

# --- the partition ---

## Plot index at cell (r, c), -1 when nothing claims it. Anything off the
## board counts as unclaimed, so the board's edge closes a plot that reaches it.
func _owner_at(r: int, c: int) -> int:
	if r < 0 or c < 0 or r >= h or c >= w:
		return -1
	return _owner[r * w + c]

## Rebuilds the owner map from `_rects`. The plots never overlap, so the last
## writer is the only writer.
func _reown() -> void:
	_owner = PackedInt32Array()
	_owner.resize(w * h)
	_owner.fill(-1)
	for i in _rects.size():
		var rect: Rect2i = _rects[i]
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				_owner[y * w + x] = i

## The clues inside plot `i`.
func _clues_in(i: int) -> Array:
	var out: Array = []
	var rect: Rect2i = _rects[i]
	for c in _clues:
		if rect.has_point(c.pos):
			out.append(c)
	return out

## A plot the board should point at: one holding two numbers or none. A plot
## holding one number of the wrong size is the marker stone's own business.
func _plot_blushes(i: int) -> bool:
	return _clues_in(i).size() != 1

## Whether the plot around clue `i` satisfies it: exactly one number in the
## plot and the areas equal. False when the clue's cell is unclaimed.
func _clue_ok(i: int) -> bool:
	var clue: Dictionary = _clues[i]
	var owner := _owner_at(clue.pos.y, clue.pos.x)
	if owner < 0:
		return false
	var rect: Rect2i = _rects[owner]
	return _clues_in(owner).size() == 1 and rect.size.x * rect.size.y == int(clue.area)

# --- walls ---

## Whether a wall stands on one unit of seam. `vertical` seams run along Z at
## lattice line `line` (0 to w) and separate the cells either side of it in X;
## horizontal ones run along X at line `line` (0 to h) and separate in Z.
## `index` is the segment along that line.
func _is_seam(vertical: bool, line: int, index: int) -> bool:
	var a: int
	var b: int
	if vertical:
		a = _owner_at(index, line - 1)
		b = _owner_at(index, line)
	else:
		a = _owner_at(line - 1, index)
		b = _owner_at(line, index)
	return a != b and (a >= 0 or b >= 0)

## Every maximal run of seam that carries a wall, as [vertical, line, start, length].
func _wall_runs() -> Array:
	var runs: Array = []
	for pair in [[false, h, w], [true, w, h]]:
		var vertical: bool = pair[0]
		for line in range(pair[1] + 1):
			var start := -1
			for index in range(pair[2] + 1):
				var on: bool = index < int(pair[2]) and _is_seam(vertical, line, index)
				if on and start < 0:
					start = index
				elif not on and start >= 0:
					runs.append([vertical, line, start, index - start])
					start = -1
	return runs

## The lattice points where walls meet, end or cross, and so need a post. A
## point two collinear segments simply pass through needs none: the run
## covering it is one unbroken wall.
func _wall_posts() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(w + 1):
		for j in range(h + 1):
			var up := j > 0 and _is_seam(true, i, j - 1)
			var down := j < h and _is_seam(true, i, j)
			var left := i > 0 and _is_seam(false, j, i - 1)
			var right := i < w and _is_seam(false, j, i)
			var count := int(up) + int(down) + int(left) + int(right)
			if count == 0:
				continue
			if count == 2 and ((up and down) or (left and right)):
				continue
			out.append(Vector2i(i, j))
	return out

## Lays the walls the current partition asks for. Runs and posts that were
## already there are left alone, ones that have gone sink away and are freed,
## and new ones rise out of the floor, so a commit only moves what it changed.
func _rebuild_walls() -> void:
	var wanted: Dictionary = {}
	for run in _wall_runs():
		var key := "%s:%d:%d:%d" % ["v" if run[0] else "h", run[1], run[2], run[3]]
		wanted[key] = run
	for post in _wall_posts():
		wanted["p:%d:%d:0" % [post.x, post.y]] = post

	for key in _walls.keys():
		if wanted.has(key):
			continue
		var gone: Node3D = _walls[key]
		_walls.erase(key)
		# A negative lift, so the run sinks back into the floor it rose from
		# rather than floating off it.
		var tw: Tween = Motion.vanish(gone, -WALL_FALL, WALL_FALL)
		if tw == null:
			gone.queue_free()
		else:
			tw.finished.connect(gone.queue_free)

	var walls: Node3D = board.get_node("Walls")
	for key in wanted.keys():
		if _walls.has(key):
			continue
		var piece: Node3D
		if key.begins_with("p:"):
			piece = _post_piece(wanted[key])
		else:
			piece = _wall_piece(wanted[key])
		walls.add_child(piece)
		_walls[key] = piece
		# The piece grows out of the floor rather than appearing on it. Only
		# the height is animated: the run's own length lives in scale.x.
		var rest: float = piece.scale.y
		piece.scale.y = 0.01
		Motion.settle(piece, "scale:y", rest, WALL_RISE)

## One wall run: a `wall_edge` stretched along its length, standing on the
## floor slabs either side of its seam.
func _wall_piece(run: Array) -> Node3D:
	var vertical: bool = run[0]
	var line: int = run[1]
	var start: int = run[2]
	var length: int = run[3]
	var piece := Models.instance("wall_edge")
	piece.name = "wall_%s_%d_%d" % ["v" if vertical else "h", line, start]
	var mid := float(start) + length * 0.5
	piece.position = _lattice(float(line) if vertical else mid, mid if vertical else float(line))
	if vertical:
		piece.rotation.y = PI * 0.5
	piece.scale.x = float(length)
	return piece

## The block closing a corner or junction at a lattice point.
func _post_piece(at: Vector2i) -> Node3D:
	var piece := Models.instance("wall_post")
	piece.name = "post_%d_%d" % [at.x, at.y]
	piece.position = _lattice(float(at.x), float(at.y))
	return piece

## The world point of a lattice coordinate (i along the columns, j along the
## rows), on top of the floor slabs where the walls stand.
func _lattice(i: float, j: float) -> Vector3:
	var origin := BoardMath.cell_origin(w, h)
	return Vector3(origin.x + i * BoardMath.CELL, Placeholders.PLOT_H,
		origin.z + j * BoardMath.CELL)

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for row in _fades:
		for tw in row:
			Motion.stop(tw)
	for tw in _clue_tw:
		Motion.stop(tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pads = []
	_pad_models = []
	_blend = []
	_blend_target = []
	_fades = []
	_clue_pivots = []
	_clue_models = []
	_clue_tw = []
	_walls = {}
	_clear_drag()
	_painted_pending = Rect2i(0, 0, 0, 0)

	board.add_child(Platform.build(w, h))
	fx = Fx.new()
	board.add_child(fx)
	var walls := Node3D.new()
	walls.name = "Walls"
	board.add_child(walls)

	for r in h:
		var pad_row := []
		var model_row := []
		var blend_row := []
		var target_row := []
		var fade_row := []
		for c in w:
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [r, c]
			pivot.position = BoardMath.cell_center(r, c, w, h)
			board.add_child(pivot)
			var pad := Models.instance("plot_pad")
			pivot.add_child(pad)
			pad_row.append(pivot)
			model_row.append(pad)
			blend_row.append(0.0)
			target_row.append(0.0)
			fade_row.append(null)
		_pads.append(pad_row)
		_pad_models.append(model_row)
		_blend.append(blend_row)
		_blend_target.append(target_row)
		_fades.append(fade_row)

	for i in _clues.size():
		var clue: Dictionary = _clues[i]
		var pivot := Node3D.new()
		pivot.name = "clue_%d" % i
		pivot.position = BoardMath.cell_center(clue.pos.y, clue.pos.x, w, h, Placeholders.PLOT_H)
		board.add_child(pivot)
		var stone := Models.instance("clue_stone")
		# One carved numeral of the nine is shown, the way a plinth shows a
		# weight. MAX_AREA keeps the generator inside that range.
		for d in range(1, 10):
			Models.set_layer_visible(stone, "Clue_Num_%d" % d, d == int(clue.area))
		pivot.add_child(stone)
		_clue_pivots.append(pivot)
		_clue_models.append(stone)
		_clue_tw.append(null)

# --- colour ---

## Repaints every floor and marker stone the state has moved under, fading a
## floor that has just started or stopped blushing.
func _recolour() -> void:
	for r in h:
		for c in w:
			var owner := _owner_at(r, c)
			var target := BAD_BLEND if (owner >= 0 and _plot_blushes(owner)) else 0.0
			if is_equal_approx(_blend_target[r][c], target):
				# The blend has not moved, but the claim under it may have.
				_paint(_blend[r][c], r, c)
				continue
			_blend_target[r][c] = target
			Motion.stop(_fades[r][c])
			var setter := _paint.bind(r, c)
			_fades[r][c] = Motion.fade(_pad_models[r][c], setter, _blend[r][c], target,
				BLUSH_IN if target > _blend[r][c] else BLUSH_OUT, BLUSH_STEPS)
	for i in _clues.size():
		_paint_clue(0.0, i)

## One floor slab at a blend toward BAD: tilled earth once a plot claims it,
## darker earth when a hint pinned that plot, bare stone otherwise, and a wash
## of accent while it sits inside the rectangle being dragged. The blend snaps
## to the 16-step grid, so a fade asks the toon cache for a bounded set.
func _paint(blend: float, r: int, c: int) -> void:
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_blend[r][c] = blend
	var owner := _owner_at(r, c)
	var base: Color = Pal.PLOT_BARE
	if owner >= 0:
		base = Pal.PLOT_LOCK if _locked[owner] else Pal.PLOT_SOIL
	if _drag_from.x >= 0 and _pending().has_point(Vector2i(c, r)):
		base = base.lerp(Pal.ACCENT, PENDING_TINT)
	Models.tint_named(_pad_models[r][c], "Stone", base.lerp(Pal.BAD, blend))

## A marker stone: green once its plot's area matches its number, rose when a
## plot of the wrong size encloses it, plain stone while its cell is open.
func _paint_clue(blend: float, i: int) -> void:
	var clue: Dictionary = _clues[i]
	var owner := _owner_at(clue.pos.y, clue.pos.x)
	var base: Color = Pal.STONE_GIVEN
	if owner >= 0:
		base = Pal.GOOD if _clue_ok(i) else Pal.BAD_TILE
	Models.tint_named(_clue_models[i], "Stone", base.lerp(Pal.BAD, blend))

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var cell := BoardMath.world_to_cell(hit, w, h)
	if cell.x < 0:
		return
	var owner := _owner_at(cell.y, cell.x)
	if owner >= 0 and _locked[owner]:
		# A hinted plot is fixed. The board says so with a dip on its number
		# rather than by letting a drag start and refusing it on release.
		_dip_clue(_clue_index_in(owner))
		fx.cue("locked")
		return
	_drag_from = cell
	_drag_to = cell
	_repaint_pending()

func on_board_drag(hit: Vector3) -> void:
	if _drag_from.x < 0:
		return
	# Clamped rather than dropped: a drag that wanders off the field holds its
	# far corner on the edge cell, the way the 2D board clamped the cell it
	# was handed. world_to_cell would answer (-1, -1) out there instead.
	var origin := BoardMath.cell_origin(w, h)
	_drag_to = Vector2i(
		clampi(floori((hit.x - origin.x) / BoardMath.CELL), 0, w - 1),
		clampi(floori((hit.z - origin.z) / BoardMath.CELL), 0, h - 1))
	_repaint_pending()

func on_board_release(_hit: Vector3) -> void:
	if _drag_from.x < 0:
		return
	var pending := _pending()
	_clear_drag()
	_commit(pending)
	_repaint_pending()

func _pending() -> Rect2i:
	var x0: int = mini(_drag_from.x, _drag_to.x)
	var y0: int = mini(_drag_from.y, _drag_to.y)
	var x1: int = maxi(_drag_from.x, _drag_to.x)
	var y1: int = maxi(_drag_from.y, _drag_to.y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

func _clear_drag() -> void:
	_drag_from = Vector2i(-1, -1)
	_drag_to = Vector2i(-1, -1)

## Lifts and tints the cells inside the rectangle being dragged, and puts back
## the ones that have left it. Only runs when the rectangle actually moved, so
## a drag across the board repaints a band rather than the whole field.
func _repaint_pending() -> void:
	var now := _pending() if _drag_from.x >= 0 else Rect2i(0, 0, 0, 0)
	if now == _painted_pending:
		return
	var touched: Array[Vector2i] = []
	for rect in [_painted_pending, now]:
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				var at := Vector2i(x, y)
				if not touched.has(at):
					touched.append(at)
	_painted_pending = now
	for at in touched:
		if at.x < 0 or at.y < 0 or at.x >= w or at.y >= h:
			continue
		var inside := now.has_point(at)
		(_pads[at.y][at.x] as Node3D).position.y = PENDING_LIFT if inside else 0.0
		_paint(_blend[at.y][at.x], at.y, at.x)

## Turns the rectangle just dragged into a plot. Drawing over existing plots
## replaces them, which is far more forgiving than refusing the drag; a single
## tap inside a plot clears it. A plot a hint pinned blocks both.
func _commit(rect: Rect2i) -> void:
	if rect.size == Vector2i(1, 1):
		var owner := _owner_at(rect.position.y, rect.position.x)
		if owner >= 0:
			# on_board_press refuses to start a drag on a pinned plot, so this
			# only guards the plot a hint pinned under a drag already running.
			if _locked[owner]:
				_dip_clue(_clue_index_in(owner))
				fx.cue("locked")
				return
			_take(owner)
			return
	var displaced: Array[Rect2i] = []
	var keep: Array[Rect2i] = []
	var keep_locked: Array[bool] = []
	for i in _rects.size():
		if not _rects[i].intersects(rect):
			keep.append(_rects[i])
			keep_locked.append(_locked[i])
			continue
		if _locked[i]:
			# Hitting a pinned plot: nothing moves, and its number says why.
			_dip_clue(_clue_index_in(i))
			fx.cue("locked")
			return
		displaced.append(_rects[i])
	_rects = keep
	_locked = keep_locked
	_rects.append(rect)
	_locked.append(false)
	_history.append({"added": rect, "displaced": displaced})
	_settle_board()
	_puff_corners(rect)
	fx.cue("plot")
	note_move()

## Clears plot `i`, the single tap inside it.
func _take(i: int) -> void:
	var gone: Array[Rect2i] = [_rects[i]]
	_rects.remove_at(i)
	_locked.remove_at(i)
	_history.append({"added": null, "displaced": gone})
	_settle_board()
	fx.cue("clear")
	note_move()

## Everything the partition drives, after `_rects` has changed.
func _settle_board() -> void:
	_reown()
	_rebuild_walls()
	_recolour()

## Stone dust at the four corners of a plot that has just been walled.
func _puff_corners(rect: Rect2i) -> void:
	for corner in [Vector2i(0, 0), Vector2i(rect.size.x, 0),
			Vector2i(0, rect.size.y), rect.size]:
		fx.puff(_lattice(rect.position.x + corner.x, rect.position.y + corner.y))

## Control-local point over the centre of cell (r, c). The win harness drags
## between these, the 3D counterpart of the 2D board's origin + cell maths.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, w, h, plane_height()))

# --- capabilities ---

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func can_undo() -> bool:
	return not is_done() and not _history.is_empty()

## Takes back the last plot drawn or cleared, putting back whatever it
## displaced. Counts no move; no state in the history was solved, or the game
## would have ended there.
func undo() -> bool:
	if is_done() or _history.is_empty():
		return false
	var last: Dictionary = _history.pop_back()
	if last.added != null:
		var added: Rect2i = last.added
		for i in _rects.size():
			if _rects[i] == added:
				_rects.remove_at(i)
				_locked.remove_at(i)
				break
	for rect in last.displaced:
		_rects.append(rect)
		_locked.append(false)
	_settle_board()
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Draws one plot from the answer and pins it: the first solution rectangle
## the board does not already have. Three per puzzle; reset unpins them but
## does not refund them. Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var target := Rect2i(0, 0, 0, 0)
	for rect in _solution:
		if not _rects.has(rect):
			target = rect
			break
	if target.size == Vector2i(0, 0):
		return false
	var keep: Array[Rect2i] = []
	var keep_locked: Array[bool] = []
	for i in _rects.size():
		if _rects[i].intersects(target):
			continue
		keep.append(_rects[i])
		keep_locked.append(_locked[i])
	_rects = keep
	_locked = keep_locked
	_rects.append(target)
	_locked.append(true)
	# A hint may displace a pinned plot's neighbours, so what came before it
	# no longer describes a board that can be gone back to.
	_history = []
	_settle_board()
	var centre := Vector2(target.position) + Vector2(target.size) * 0.5
	fx.sparkle(_lattice(centre.x, centre.y) + Vector3(0.0, SPARKLE_LIFT, 0.0))
	fx.cue("hint")
	hints_used += 1
	moved.emit()
	check_solved()
	return true

## Shakes and flashes every number the board does not yet satisfy, and returns
## how many. Solving stays automatic; this only points.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong := 0
	for i in _clues.size():
		if _clue_ok(i):
			continue
		wrong += 1
		_flash_clue(i)
	fx.cue("check" if wrong > 0 else "check_ok")
	return wrong

## The index of a clue inside plot `i`, or -1 when it holds none.
func _clue_index_in(i: int) -> int:
	var rect: Rect2i = _rects[i]
	for j in _clues.size():
		if rect.has_point(_clues[j].pos):
			return j
	return -1

## A marker stone dips: a refused tap.
func _dip_clue(i: int) -> void:
	if i < 0:
		return
	Motion.stop(_clue_tw[i])
	(_clue_pivots[i] as Node3D).position.y = Placeholders.PLOT_H
	_clue_tw[i] = Motion.hop(_clue_pivots[i], -DIP, DIP_TIME, 0.0, Placeholders.PLOT_H)

## A marker stone shakes and blushes, then settles back: Check pointing at it.
func _flash_clue(i: int) -> void:
	Motion.stop(_clue_tw[i])
	var pivot: Node3D = _clue_pivots[i]
	pivot.rotation.z = 0.0
	Motion.wobble(pivot)
	var setter := _paint_clue.bind(i)
	var tw: Tween = Motion.fade(_clue_models[i], setter, 0.0, 1.0, CHECK_IN, BLUSH_STEPS)
	if tw == null:
		setter.call(0.0)
		_clue_tw[i] = null
		return
	tw.tween_method(setter, 1.0, 0.0, CHECK_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_clue_tw[i] = tw

# --- entrance and solve ---

## The board arrives: the platform rises out of the water, the floor slabs pop
## in along a diagonal wave from the far-left corner, and the marker stones
## follow once the ground they stand on is there.
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
	for i in _clue_pivots.size():
		var clue: Dictionary = _clues[i]
		_pop_in(_clue_pivots[i], ENTER_PLATFORM + ENTER_POP
			+ Motion.stagger(clue.pos.y + clue.pos.x, ENTER_STAGGER))
	fx.cue("enter")

func _pop_in(node: Node3D, delay: float) -> void:
	node.scale = Vector3.ONE * 0.01
	var pop: Tween = Motion.settle(node, "scale", Vector3.ONE, ENTER_POP, delay)
	if pop != null:
		_entrance.append(pop)

## Cuts the entrance short: everything lands where it was going.
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
	for pivot in _clue_pivots:
		(pivot as Node3D).scale = Vector3.ONE

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## Every floor slab hops once, row by row from the far edge.
func _on_solved() -> void:
	_clear_drag()
	_repaint_pending()
	for r in h:
		for c in w:
			Motion.hop(_pads[r][c], SOLVE_HOP, SOLVE_TIME, Motion.stagger(r, SOLVE_STAGGER), 0.0)
	fx.cue("solved")
