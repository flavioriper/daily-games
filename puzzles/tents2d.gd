extends "res://core/puzzle_base.gd"

## Tents as a flat board: a meadow of pale turf on the host's parchment card,
## conifers standing on it, canvas tents pitched beside them, cairns over the
## ground the player has ruled out, and the line counts on chips along a band
## outside the grid. Built beside the island version (puzzles/tents3d.gd) so
## the two can be judged against each other on the phone; the rules live in
## puzzles/tents_state.gd, which this only draws.
##
## What flat buys here is narrower than it was for Shikaku, and worth saying
## plainly: a meadow with conifers on it is already this puzzle's natural
## home. It buys two things. **The counts**: twenty-six numbers on a hard
## board, consulted constantly, and on a board pitched at seven degrees the
## far band is the smallest and most foreshortened thing on the screen --
## precisely the information you look at most, rendered worst. Flat, a count
## is the same size wherever it sits and can change colour legibly. **And the
## sweep**: ruling ground out is most of the work here (a hard board is 64
## squares and 9 tents, so 55 of them are cairns), and a drag that lays a
## whole row of them is a gesture a grid square-on to the eye invites and a
## tilted one does not.
##
## How it is drawn. The meadow and its grid are one cached mesh; every cairn,
## the shade under a running sweep and nothing else go into a second, rebuilt
## only when something moves. The characters are Controls with their own
## cached meshes -- a conifer per tree, a tent per pitched square, a chip per
## line -- and a tree's sway is a transform on its own draw, so a swaying
## meadow never asks the board for a frame.
## Spec: docs/superpowers/specs/2026-09-18-tents-flat-design.md, sections 2
## to 7, and the mock it is ported from
## (docs/brainstorm/concepts.html#tents).

const State = preload("res://puzzles/tents_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const TentFace = preload("res://ui/faces/tent_face.gd")
const ConiferFace = preload("res://ui/faces/conifer_face.gd")
const CountChip = preload("res://ui/faces/count_chip.gd")

# --- the meadow ---
const PAD := 34.0
## The count band, in cells. On the island it is a real extra row and column
## of bare platform, because a stone has to stand on something; here nothing
## stands on it, so it costs less than a cell.
const BAND := 0.72
const TURF_RADIUS := 18.0
const GRID_WIDTH := 2.0
const GRID_ALPHA := 0.9
const SWEEP_ALPHA := 0.07
const SWEEP_INSET := 3.0
const SWEEP_RADIUS := 10.0

# --- the pieces, in cells ---
const TENT_SIZE := 0.9
const TREE_SIZE := 0.94
const CAIRN_SIZE := 0.8

# --- motion ---
const POP_FROM := 0.6
const POP_TIME := 0.22
const DIP := 0.05
const DIP_TIME := 0.3
const FLASH := 0.07
const FLASH_TIME := 0.6
const FLASH_SWINGS := 9.0
const ENTER_CHIP := 0.12
const ENTER_CHIP_STEP := 0.02
const ENTER_CHIP_TIME := 0.35
const ENTER_TREE := 0.2
const ENTER_TREE_STEP := 0.02
const ENTER_TREE_TIME := 0.4
const ENTER_DROP := 26.0
const SOLVE_DELAY := 0.15
const SOLVE_STEP := 0.1
const SOLVE_HOP := 0.12
const SOLVE_HOP_TIME := 0.42
## The cairns clear away on the win: a hard board finishes with 55 of its 64
## squares under pebbles, and without this the last picture is the
## working-out rather than the camp.
const CLEAR_DELAY := 0.2
const CLEAR_SPREAD := 0.3
const CLEAR_TIME := 0.5
const WIN_WAIT := 2.0

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
const TIPS := [
	"One tent orthogonally beside every tree. Tents never touch, not even corner to corner.",
	"Drag across the meadow to lay cairns on ground you have ruled out.",
	"The numbers count the tents in each line.",
]

var state = State.new()
## The names the win harness and the island board share.
var w: int:
	get: return state.w
var h: int:
	get: return state.h
var _solution_tents: Array:
	get: return state.solution

var fx: Node2D
var _cell := 0.0
var _grid := Vector2.ZERO
var _card := Rect2()
var _chips_row: Array = []       # [r] -> CountChip
var _chips_col: Array = []       # [c] -> CountChip
var _trees: Dictionary = {}      # Vector2i -> ConiferFace
var _tents: Dictionary = {}      # Vector2i -> TentFace, kept once made
## Vector2i -> the second a square's piece went down, which drives its pop
## and, on the win, its hop.
var _at: Dictionary = {}
var _dip_at: Dictionary = {}
var _flash_at: Dictionary = {}

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
var _dragged := false
var _sweeping := false
var _lay := true
var _swept: Dictionary = {}
var _pending: Array = []
var _last_paint := Vector2i(-1, -1)

var _opened := 0.0
var _solved_at := -1.0
var _meadow: ArrayMesh
var _ground: ArrayMesh
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "tents"
func title() -> String: return "Tents"

func rules() -> String:
	return "Pitch one tent orthogonally beside every tree. Tents never touch, not even corner to corner, and the numbers count the tents in each line."

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

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
	state.setup(rng, difficulty)
	_at = {}
	_dip_at = {}
	_flash_at = {}
	_clear_gesture()
	_solved_at = -1.0
	_opened = _now()
	_build_pieces()
	_layout()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("enter")

# --- the cast ---

func _build_pieces() -> void:
	for node in _chips_row + _chips_col:
		node.queue_free()
	for cell in _trees:
		_trees[cell].queue_free()
	for cell in _tents:
		_tents[cell].queue_free()
	_chips_row = []
	_chips_col = []
	_trees = {}
	_tents = {}
	for r in state.h:
		_chips_row.append(_chip(int(state.row_counts[r]), "row_%d" % r))
	for c in state.w:
		_chips_col.append(_chip(int(state.col_counts[c]), "col_%d" % c))
	for cell in state.tree_list:
		var tree := ConiferFace.new()
		tree.name = "tree_%d_%d" % [cell.x, cell.y]
		tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tree)
		tree.set_idle(true)
		_trees[cell] = tree

func _chip(number: int, node_name: String) -> CountChip:
	var chip := CountChip.new()
	chip.name = node_name
	chip.number = number
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	return chip

## The tent on `cell`, made the first time one is pitched there and kept
## afterwards: a square the player taps twice would otherwise build and free a
## node with a mesh cache behind it on every tap.
func _tent_node(cell: Vector2i) -> TentFace:
	if _tents.has(cell):
		return _tents[cell]
	var tent := TentFace.new()
	tent.name = "tent_%d_%d" % [cell.x, cell.y]
	tent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tent)
	tent.set_idle(true)
	_tents[cell] = tent
	return tent

# --- layout ---

## The meadow is the largest grid the card holds, and the card is cut to the
## meadow and centred in the slot rather than pinned under the day card the
## way the other flat boards are. This is the one board of the six whose grid
## is square while its space is tall: the cell is capped by the width, so
## there is slack however it is cut, and air above and below reads as centring
## where all of it below reads as a board that fell over.
func _layout() -> void:
	if state.tree_list.is_empty():
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var grid := Vector2(_cell * (state.w + BAND), _cell * (state.h + BAND))
	var tall := minf(size.y, grid.y + 2.0 * PAD)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - grid.x * 0.5, _card.position.y + (tall - grid.y) * 0.5) \
		+ Vector2.ONE * (_cell * BAND)
	_meadow = _build_meadow()
	_refresh()

## The cell a slot of `available` height holds, capped by the width.
func _cell_for(available: float) -> float:
	if state.tree_list.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / (state.w + BAND),
		(available - 2.0 * PAD) / (state.h + BAND))

## The host cuts its card to the meadow and centres it, which is what these
## two say. A board that wants neither says nothing and fills the slot.
func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * (state.h + BAND) + 2.0 * PAD)

func card_centred() -> bool:
	return true

## Control-local point over the centre of cell (r, c). The win harness taps
## these, exactly as it does on the island board.
func cell_to_local(r: int, c: int) -> Vector2:
	return _grid + Vector2(c + 0.5, r + 0.5) * _cell

func _cell_at(local: Vector2) -> Vector2i:
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _grid) / _cell
	var cell := Vector2i(int(floor(p.x)), int(floor(p.y)))
	return cell if state.in_field(cell) else Vector2i(-1, -1)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or state.tree_list.is_empty():
		return
	if _animating(_now()):
		_refresh()

## True while anything is still moving. A meadow left alone costs its trees'
## own sway and blinks, which are their tweens and not the board's frames.
func _animating(t: float) -> bool:
	if _sweeping:
		return true
	if t < _opened + ENTER_TREE + (state.w + state.h) * ENTER_TREE_STEP + ENTER_TREE_TIME:
		return true
	if _solved_at >= 0.0 and t < _solved_at + WIN_WAIT:
		return true
	for cell in _at:
		if t < float(_at[cell]) + maxf(POP_TIME, SOLVE_HOP_TIME):
			return true
	for cell in _dip_at:
		if t < float(_dip_at[cell]) + DIP_TIME:
			return true
	for cell in _flash_at:
		if t < float(_flash_at[cell]) + FLASH_TIME:
			return true
	return false

func _refresh() -> void:
	var t := _now()
	_place_chips(t)
	_place_pieces(t)
	_ground = _build_ground(t)
	queue_redraw()

func _place_chips(t: float) -> void:
	var seat := Vector2.ONE * _cell
	for c in _chips_col.size():
		var chip: CountChip = _chips_col[c]
		chip.size = seat
		chip.position = Vector2(_grid.x + (c + 0.5) * _cell,
			_grid.y - _cell * BAND * 0.5) - seat * 0.5
		chip.modulate.a = _dec((t - _opened - ENTER_CHIP - c * ENTER_CHIP_STEP) / ENTER_CHIP_TIME)
		chip.expression = _chip_face(state.col_tents(c), int(state.col_counts[c]))
	for r in _chips_row.size():
		var chip: CountChip = _chips_row[r]
		chip.size = seat
		chip.position = Vector2(_grid.x - _cell * BAND * 0.5,
			_grid.y + (r + 0.5) * _cell) - seat * 0.5
		chip.modulate.a = _dec((t - _opened - ENTER_CHIP - r * ENTER_CHIP_STEP) / ENTER_CHIP_TIME)
		chip.expression = _chip_face(state.row_tents(r), int(state.row_counts[r]))

func _chip_face(have: int, want: int) -> int:
	match State.line_state(have, want):
		State.LINE_OK: return Face.Expr.JOY
		State.LINE_OVER: return Face.Expr.STRAIN
		_: return Face.Expr.HAPPY

func _place_pieces(t: float) -> void:
	for cell in _trees:
		var tree: ConiferFace = _trees[cell]
		var seat := Vector2.ONE * (_cell * TREE_SIZE)
		var u := _dec((t - _opened - ENTER_TREE - (cell.x + cell.y) * ENTER_TREE_STEP) / ENTER_TREE_TIME)
		tree.size = seat
		tree.pivot_offset = seat * 0.5
		var drop := 0.0 if Motion.reduce else -ENTER_DROP * (1.0 - _back_out(u))
		tree.position = cell_to_local(cell.y, cell.x) - seat * 0.5 + Vector2(0.0, drop)
		tree.modulate.a = u
		tree.visible = u > 0.0
	for cell in _tents:
		var tent: TentFace = _tents[cell]
		var up: bool = state.mark_at(cell) == State.TENT
		tent.visible = up
		if not up:
			continue
		var seat := Vector2.ONE * (_cell * TENT_SIZE)
		tent.size = seat
		tent.pivot_offset = seat * 0.5
		var grow := 1.0 if Motion.reduce else lerpf(POP_FROM, 1.0, _back_out(_pop_u(cell, t)))
		tent.scale = Vector2.ONE * grow
		tent.position = cell_to_local(cell.y, cell.x) - seat * 0.5 + _jitter(cell, t)
		tent.pegged = state.locked.has(cell)
		if _solved_at >= 0.0 and t >= float(_at.get(cell, 0.0)):
			tent.expression = Face.Expr.JOY
		elif not is_done() and state.tent_bad(cell):
			tent.expression = Face.Expr.STRAIN
		else:
			tent.expression = Face.Expr.HAPPY

func _pop_u(cell: Vector2i, t: float) -> float:
	return clampf((t - float(_at.get(cell, -100.0))) / POP_TIME, 0.0, 1.0)

## What a square's piece is doing besides standing there: the shake a failed
## Check gave it, the dip a refused tap gave it, and the hop of the win.
func _jitter(cell: Vector2i, t: float) -> Vector2:
	if Motion.reduce:
		return Vector2.ZERO
	var out := Vector2.ZERO
	var flash := (t - float(_flash_at.get(cell, -100.0))) / FLASH_TIME
	if flash >= 0.0 and flash < 1.0:
		out.x += _cell * FLASH * sin(FLASH_SWINGS * PI * flash) * (1.0 - flash)
	var dip := (t - float(_dip_at.get(cell, -100.0))) / DIP_TIME
	if dip >= 0.0 and dip < 1.0:
		out.y += _cell * DIP * sin(PI * dip)
	if _solved_at >= 0.0:
		var hop := (t - float(_at.get(cell, 0.0))) / SOLVE_HOP_TIME
		if hop >= 0.0 and hop < 1.0:
			out.y -= _cell * SOLVE_HOP * sin(PI * hop)
	return out

# --- the drawing ---

func _draw() -> void:
	if _meadow != null:
		draw_mesh(_meadow, null)
	if _ground != null:
		draw_mesh(_ground, null)

func _build_meadow() -> ArrayMesh:
	var b := Face.Builder.new()
	var field := Vector2(_cell * state.w, _cell * state.h)
	b.fan(Face.Builder.round_rect(_grid, field, TURF_RADIUS), Pal.MEADOW)
	var line := Color(Pal.MEADOW_LINE, GRID_ALPHA)
	for x in range(1, state.w):
		b.stroke(PackedVector2Array([_grid + Vector2(x * _cell, 0.0),
			_grid + Vector2(x * _cell, field.y)]), GRID_WIDTH, line, false, false)
	for y in range(1, state.h):
		b.stroke(PackedVector2Array([_grid + Vector2(0.0, y * _cell),
			_grid + Vector2(field.x, y * _cell)]), GRID_WIDTH, line, false, false)
	return b.mesh()

## The cairns and the shade under a running sweep: everything on the ground
## that is not a character, in one mesh.
func _build_ground(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	if _sweeping:
		for key in _swept:
			var cell: Vector2i = key
			b.fan(Face.Builder.round_rect(
				_grid + Vector2(cell) * _cell + Vector2.ONE * SWEEP_INSET,
				Vector2.ONE * (_cell - 2.0 * SWEEP_INSET), SWEEP_RADIUS),
				Color(Pal.TEXT, SWEEP_ALPHA))
	for cell in state.marks:
		if int(state.marks[cell]) != State.GRASS:
			continue
		var grow := 1.0 if Motion.reduce else lerpf(POP_FROM, 1.0, _back_out(_pop_u(cell, t)))
		var alpha := 1.0
		if _solved_at >= 0.0:
			var gone := _dec((t - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD) / CLEAR_TIME)
			if gone >= 1.0:
				continue
			alpha = 1.0 - gone
			grow *= 1.0 - gone * 0.4
		_cairn(b, cell_to_local(cell.y, cell.x), _cell * CAIRN_SIZE * grow, alpha)
	if b.verts.is_empty():
		return null
	return b.mesh()

## A cairn: the mark the puzzle is actually solved with, so it is a thing on
## the ground and not a shade of grass.
func _cairn(b, at: Vector2, s: float, alpha: float) -> void:
	b.ellipse(at + Vector2(0.0, 0.32) * s, 0.33 * s, 0.09 * s, Color(Pal.TEXT, 0.13 * alpha))
	var deep := Color(Pal.CAIRN_DEEP, alpha)
	b.ellipse(at + Vector2(-0.15, 0.19) * s, 0.19 * s, 0.13 * s, deep)
	b.ellipse(at + Vector2(0.16, 0.21) * s, 0.17 * s, 0.12 * s, deep)
	var stone := Color(Pal.CAIRN_STONE, alpha)
	b.ellipse(at + Vector2(0.0, 0.01) * s, 0.2 * s, 0.14 * s, stone)
	b.ellipse(at + Vector2(-0.03, -0.2) * s, 0.14 * s, 0.11 * s, stone)
	b.ellipse(at + Vector2(-0.06, -0.24) * s, 0.06 * s, 0.04 * s, Color(1.0, 1.0, 1.0, 0.3 * alpha))

# --- input ---

## Touch and drag only, as every flat board takes them. A tap puts a tent up
## or takes whatever is there away; a drag sweeps cairns, and its direction is
## read off the square it started on.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release()
	elif event is InputEventScreenDrag and _press_cell.x >= 0:
		_drag(event.position)

func _press(cell: Vector2i) -> void:
	_clear_gesture()
	if is_done() or cell.x < 0:
		return
	_press_cell = cell

func _drag(at: Vector2) -> void:
	var cell := _cell_at(at)
	if cell.x < 0:
		return
	if not _dragged and cell != _press_cell:
		_dragged = true
		_sweeping = true
		# Begin on a cairn and the sweep rubs out; begin anywhere else and it
		# lays.
		_lay = state.mark_at(_press_cell) != State.GRASS
		_paint(_press_cell)
	if not _dragged:
		return
	# Every square between the last one painted and this one, so a fast finger
	# does not leave holes in its row. The mock paints only what it is handed.
	if _last_paint.x >= 0:
		var steps := maxi(absi(cell.x - _last_paint.x), absi(cell.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(
				roundi(lerpf(_last_paint.x, cell.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, cell.y, float(i) / steps))))
	_paint(cell)
	_refresh()

## A sweep never disturbs a tent or a tree: the gesture is for ruling ground
## out, and losing a tent to a stray finger would be the worst bug here.
func _paint(cell: Vector2i) -> void:
	_last_paint = cell
	if _swept.has(cell):
		return
	_swept[cell] = true
	if state.fixed(cell) or state.mark_at(cell) == State.TENT:
		return
	var to := State.GRASS if _lay else State.BLANK
	if state.mark_at(cell) == to:
		return
	_pending.append({"cell": cell, "to": to})

func _release() -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var pending := _pending
	_clear_gesture()
	if cell.x < 0 or is_done():
		_refresh()
		return
	if was_drag:
		if not pending.is_empty():
			_commit(state.apply(pending))
		_refresh()
		return
	if state.fixed(cell):
		# A tree's square, or a tent a hint pegged down: a dip and a word,
		# rather than a move.
		_dip_at[cell] = _now()
		_say("A tree stands there. Tents go beside them." if state.trees.has(cell)
			else "That tent is pegged down. A hint pitched it.", Face.Expr.PUZZLED)
		fx.cue("locked")
		_refresh()
		return
	_commit(state.tap(cell))

## One gesture is one move, however many squares it touched.
func _commit(changed: Array) -> void:
	if changed.is_empty():
		_refresh()
		return
	var t := _now()
	for cell in changed:
		_at[cell] = t
		if state.mark_at(cell) == State.TENT:
			_tent_node(cell)
	fx.cue("place")
	_speak()
	_refresh()
	note_move()

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_dragged = false
	_sweeping = false
	_swept = {}
	_pending = []
	_last_paint = Vector2i(-1, -1)

# --- the sprout's line ---

## What the tip card says: the rules while the meadow is bare, then whichever
## rule the board can currently see being broken, then the count of tents
## still to pitch.
func _speak() -> void:
	if is_done():
		return
	var bad := state.bad_tents()
	if bad > 0:
		_say("One tent is in trouble: it touches another, or it has no tree beside it."
			if bad == 1 else
			"%d tents are in trouble: touching another, or with no tree beside them." % bad,
			Face.Expr.STRAIN)
		return
	var over := state.over_lines()
	if over > 0:
		_say("One line has more tents than its number allows." if over == 1
			else "%d lines have more tents than their numbers allow." % over,
			Face.Expr.STRAIN)
		return
	var left := state.tents_left()
	if left <= 0:
		_say("Every tent is pitched. Something is still not matched up.", Face.Expr.STRAIN)
		return
	_say("%d %s still to pitch." % [left, "tent" if left == 1 else "tents"], Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY or not state.marks.is_empty():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Takes back the last gesture, however many squares it swept. Counts no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var t := _now()
	for cell in state.undo():
		_at[cell] = t
		if state.mark_at(cell) == State.TENT:
			_tent_node(cell)
	_speak()
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Pitches one tent from the answer and pegs it down for good. Counts no move
## but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	_at[target] = _now()
	_tent_node(target)
	hints_used += 1
	fx.sparkle(cell_to_local(target.y, target.x), Pal.GOOD)
	fx.cue("hint")
	_say("That tent is pegged down for good.", Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	check_solved()
	return true

## Shakes every tent the answer does not put there, and says how many.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var t := _now()
	var wrong: Array = state.wrong_tents()
	for cell in wrong:
		_flash_at[cell] = t
	_say("%d %s in the wrong place." % [wrong.size(), "tent is" if wrong.size() == 1 else "tents are"]
		if not wrong.is_empty() else "Every tent you have pitched is right.",
		Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_refresh()
	return wrong.size()

func reset_board() -> void:
	var t := _now()
	_clear_gesture()
	for cell in state.reset():
		_at[cell] = t
	_dip_at = {}
	_flash_at = {}
	moves = 0
	_running = true
	_say("The meadow is cleared. The hints you spent are not refunded, only unpinned.",
		Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The board is the answer, so the win screen shows no cast: the pitched camp
## stays on the card under it.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "Every tree has its camp."}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The tents hop in reading order, and the cairns clear away.
func _on_solved() -> void:
	var t := _now()
	_clear_gesture()
	_tip_timer.stop()
	_solved_at = t
	var pitched: Array = state.tents()
	pitched.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y * state.w + a.x < b.y * state.w + b.x)
	for i in pitched.size():
		_at[pitched[i]] = t + SOLVE_DELAY + i * SOLVE_STEP
	_say("Every tree has its tent. The camp is pitched.", Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

func _back_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	const C := 1.70158
	return 1.0 + (C + 1.0) * pow(u - 1.0, 3.0) + C * pow(u - 1.0, 2.0)

## A fixed pseudo-random number per square, so the cairns clear away in a
## scatter rather than a wave.
static func _hash(cell: Vector2i) -> float:
	return float(posmod(hash(cell), 1000)) / 1000.0
