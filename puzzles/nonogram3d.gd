extends "res://core/puzzle_base_3d.gd"

## Nonogram on the island stage. The board is a mosaic floor being laid: every
## cell is an empty socket of pale stone, and a tap lays a slate tile in it,
## then swaps the tile for a pebble mark on ground ruled out, then clears it.
## The finished grid is the picture in relief, which is the whole appeal of
## this puzzle -- so the tile is a real object with a real grout line around
## it rather than a painted square, and the picture is something the player
## has built.
##
## The clues are Shikaku's marker stones, one stone per number, laid on a
## margin of bare platform: the board is built as many cells wider and taller
## as the longest clue on each axis needs, the grid sits inside that, and each
## line's stones run up to the grid's edge in reading order, right-aligned the
## way a nonogram's clues always are. A line with nothing in it gets a single
## zero stone rather than a blank margin, so every line says something.
##
## Because one stone carries one numeral, the grid is at most nine wide: a
## full line of ten would ask for a run of "10" and the stone has no such
## face. That is the layout choosing the difficulty steps, not the other way
## around -- 5, 7 and 9 -- and a 9 x 9 picture is still a picture.
##
## Feedback is per line, which is the help a nonogram player actually wants: a
## line's clue stones go green the moment its filled runs read exactly as its
## clue, and rose once it holds more filled cells than the clue can account
## for. Nothing points at an individual cell; the lines do the talking.
## Design: agreed in chat on 2026-09-15 (no spec file by request).

const Gen = preload("res://puzzles/nonogram_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://world/fx.gd")

## The three states of a cell, as the flat board had them.
const BLANK := 0
const FILL := 1
const MARK := 2

## A piece arriving on a cell, and one being taken away.
const POP_TIME := 0.22
const VANISH_LIFT := 0.12
const VANISH_TIME := 0.16
## A refused tap (a tile a hint laid) answers with a dip.
const DIP := 0.04
const DIP_TIME := 0.3
## A socket warming or cooling as its cell is ruled out and cleared again.
const SOCKET_IN := 0.2
const SOCKET_OUT_TIME := 0.28
## How far a clue stone goes toward BAD when its line is over-filled. Well
## past the 6/16 the other boards use: a marker stone is pale, so a sixth of
## the way to rose leaves it looking merely dusty.
const OVER_BLEND := 0.75
const BLUSH_STEPS := 16
const BLUSH_IN := 0.25
const BLUSH_OUT := 0.4
const CHECK_IN := 0.15
const CHECK_OUT := 0.45
const HINTS := 3
const SPARKLE_LIFT := 0.22
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.02
const SOLVE_HOP := 0.1
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.035

var w: int = 5
var h: int = 5
var _bitmap: Array = []
var _rows: Array = []
var _cols: Array = []
var _marks: Dictionary = {}          # Vector2i -> BLANK / FILL / MARK
var _locked: Dictionary = {}         # Vector2i -> true, a tile a hint laid
## Cells of margin the clue stones need: the longest row clue on the left, the
## longest column clue at the far edge. Measured from the puzzle in hand, not
## from the worst case a grid this wide could produce, so a gentle picture
## gets a tight board.
var _gw: int = 1
var _gh: int = 1

var fx: Node3D
var _sockets: Dictionary = {}        # Vector2i -> Node3D pivot
var _socket_models: Dictionary = {}
var _socket_blend: Dictionary = {}   # Vector2i -> painted blend toward SOCKET_OUT
var _socket_fade: Dictionary = {}
var _pieces: Dictionary = {}         # Vector2i -> Node3D, the tile or mark on it
var _piece_kind: Dictionary = {}
var _piece_tw: Dictionary = {}        # Vector2i -> a dip, shake or pop
var _row_stones: Array = []          # [y] -> Array[Node3D]
var _col_stones: Array = []          # [x] -> Array[Node3D]
var _line_blend: Dictionary = {}     # "r<i>" / "c<i>" -> painted blend
var _line_fade: Dictionary = {}
var _entrance: Array = []
## One entry per tap that can be taken back: the cell and the mark before it.
var _history: Array[Vector3i] = []

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "nonogram"
func title() -> String: return "Nonogram"

func rules() -> String:
	return "The numbers give the lengths of the filled runs in each line, in order, with a gap between runs."

func board_size() -> Vector2i: return Vector2i(w + _gw, h + _gh)
## The tallest thing on a cell: a pebble mark stands higher than a laid tile.
func board_height() -> float:
	return Placeholders.PLOT_H + maxf(Placeholders.MOSAIC_H, Placeholders.CAIRN_H)
func plane_height() -> float: return Placeholders.PLOT_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	match difficulty:
		0: w = 5; h = 5
		1: w = 7; h = 7
		_: w = 9; h = 9
	var out: Dictionary = Gen.generate(rng, w, h)
	_bitmap = out.bitmap
	_rows = out.rows
	_cols = out.cols
	_gw = 1
	_gh = 1
	for clue in _rows:
		_gw = maxi(_gw, (clue as Array).size())
	for clue in _cols:
		_gh = maxi(_gh, (clue as Array).size())
	_marks = {}
	_locked = {}
	_history = []
	_build_scene()
	_recolour()
	_refit()
	_enter()

## The floor is cleared: every tile and mark is taken up at once. Hints are
## unpinned but not refunded.
func reset_board() -> void:
	_stop_entrance()
	for cell in _marks.keys():
		_drop_piece(cell)
	_marks = {}
	_locked = {}
	_history = []
	moves = 0
	_recolour()
	fx.cue("reset")

func is_solved() -> bool:
	if _bitmap.is_empty():
		return false
	for y in h:
		for x in w:
			var filled: bool = int(_marks.get(Vector2i(x, y), BLANK)) == FILL
			if filled != (int(_bitmap[y][x]) == 1):
				return false
	return true

## The finished picture, not the player's grid: the share is the image.
func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			out += "⬛" if int(_bitmap[y][x]) == 1 else "⬜"
		out += "\n"
	return out

# --- the rules, as the board reads them ---

## Row `y` as the player has it, ready for Gen.clue_for: 1 filled, 0 not.
func _row_line(y: int) -> Array:
	var out: Array = []
	for x in w:
		out.append(1 if int(_marks.get(Vector2i(x, y), BLANK)) == FILL else 0)
	return out

func _col_line(x: int) -> Array:
	var out: Array = []
	for y in h:
		out.append(1 if int(_marks.get(Vector2i(x, y), BLANK)) == FILL else 0)
	return out

## How many cells of `line` are filled, and how many the clue accounts for.
static func _totals(line: Array, clue: Array) -> Array:
	var have := 0
	for v in line:
		have += int(v)
	var want := 0
	for v in clue:
		want += int(v)
	return [have, want]

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for store in [_socket_fade, _piece_tw, _line_fade]:
		for key in store:
			Motion.stop(store[key])

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_sockets = {}
	_socket_models = {}
	_socket_blend = {}
	_socket_fade = {}
	_pieces = {}
	_piece_kind = {}
	_piece_tw = {}
	_row_stones = []
	_col_stones = []
	_line_blend = {}
	_line_fade = {}

	var size := board_size()
	board.add_child(Platform.build(size.x, size.y))
	fx = Fx.new()
	board.add_child(fx)

	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var pivot := Node3D.new()
			pivot.name = "socket_%d_%d" % [y, x]
			pivot.position = _cell_at(y, x)
			board.add_child(pivot)
			var pad := Models.instance("plot_pad")
			pivot.add_child(pad)
			_sockets[cell] = pivot
			_socket_models[cell] = pad
			_socket_blend[cell] = 0.0
			# Painted here rather than left to _recolour: a fade only runs when
			# the blend has to move, so a socket that starts pale and stays
			# pale would keep whatever colour the slab was modelled in.
			_paint_socket(0.0, cell)

	# The clues: one stone per number, running up to the grid's edge.
	for y in h:
		_row_stones.append(_clue_run(_rows[y], true, y))
	for x in w:
		_col_stones.append(_clue_run(_cols[x], false, x))

## One line's clue stones, right-aligned against the grid so the last number
## is the one nearest the cells it describes. An empty clue gets a single zero
## stone: a blank margin would read as a line nobody had got round to.
func _clue_run(clue: Array, is_row: bool, index: int) -> Array:
	var numbers: Array = clue.duplicate() if not clue.is_empty() else [0]
	var out: Array = []
	var margin: int = _gw if is_row else _gh
	for k in numbers.size():
		var slot: int = margin - numbers.size() + k
		var at: Vector3
		if is_row:
			at = BoardMath.cell_center(_gh + index, slot, w + _gw, h + _gh)
		else:
			at = BoardMath.cell_center(slot, _gw + index, w + _gw, h + _gh)
		var pivot := Node3D.new()
		pivot.name = "clue_%s%d_%d" % ["r" if is_row else "c", index, k]
		pivot.position = at
		board.add_child(pivot)
		var stone := Models.instance("clue_stone")
		var n: int = int(numbers[k])
		for d in range(0, 10):
			Models.set_layer_visible(stone, "Clue_Num_%d" % d, d == n)
		pivot.add_child(stone)
		out.append(pivot)
	return out

## World point of grid cell (r, c). The grid sits inside the board, past the
## margin the clue stones stand on.
func _cell_at(r: int, c: int, y := 0.0) -> Vector3:
	return BoardMath.cell_center(_gh + r, _gw + c, w + _gw, h + _gh, y)

# --- pieces on the floor ---

## Puts the piece cell `cell` should be carrying on the board, taking away
## whatever was there.
func _set_piece(cell: Vector2i) -> void:
	var mark := int(_marks.get(cell, BLANK))
	var want := "" if mark == BLANK else ("mosaic_tile" if mark == FILL else "cairn")
	if _piece_kind.get(cell, "") == want:
		_paint_piece(cell)
		return
	_drop_piece(cell)
	if want == "":
		return
	var pivot := Node3D.new()
	pivot.name = "%s_%d_%d" % [want, cell.y, cell.x]
	pivot.position = _cell_at(cell.y, cell.x, Placeholders.PLOT_H)
	board.add_child(pivot)
	pivot.add_child(Models.instance(want))
	_pieces[cell] = pivot
	_piece_kind[cell] = want
	pivot.scale = Vector3.ONE * 0.01
	Motion.settle(pivot, "scale", Vector3.ONE, POP_TIME)
	_paint_piece(cell)
	fx.cue("lay" if want == "mosaic_tile" else "rule_out")

## Takes the piece off `cell`, if it has one.
func _drop_piece(cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	var gone: Node3D = _pieces[cell]
	_pieces.erase(cell)
	_piece_kind.erase(cell)
	Motion.stop(_piece_tw.get(cell))
	_piece_tw.erase(cell)
	var tw: Tween = Motion.vanish(gone, VANISH_LIFT, VANISH_TIME)
	if tw == null:
		gone.queue_free()
	else:
		tw.finished.connect(gone.queue_free)

# --- colour ---

## Repaints everything the state has moved under: the sockets, the tiles and
## marks, and both sets of clue stones.
func _recolour() -> void:
	for cell in _sockets:
		_fade_socket(cell, 1.0 if int(_marks.get(cell, BLANK)) == MARK else 0.0)
	for cell in _pieces.keys():
		_paint_piece(cell)
	for y in h:
		_fade_line("r%d" % y, _row_stones[y], _row_line(y), _rows[y])
	for x in w:
		_fade_line("c%d" % x, _col_stones[x], _col_line(x), _cols[x])

## Eases one socket between pale stone and the darker shade of a ruled-out
## cell. Kills a fade in flight even when the socket already shows the target,
## for the reason puzzles/lightup3d.gd's _fade_pad sets out: the blend is the
## colour painted so far, so a cell cycled twice in a frame would otherwise
## leave the first fade running.
func _fade_socket(cell: Vector2i, target: float) -> void:
	var now: float = _socket_blend.get(cell, 0.0)
	var settled := is_equal_approx(now, target)
	if settled and not Motion.running(_socket_fade.get(cell)):
		return
	Motion.stop(_socket_fade.get(cell))
	_socket_fade.erase(cell)
	if settled:
		_paint_socket(target, cell)
		return
	_socket_fade[cell] = Motion.fade(_sockets[cell], _paint_socket.bind(cell),
		now, target, SOCKET_IN if target > now else SOCKET_OUT_TIME, BLUSH_STEPS)

func _paint_socket(blend: float, cell: Vector2i) -> void:
	if not _socket_models.has(cell):
		return
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_socket_blend[cell] = blend
	Models.tint_named(_socket_models[cell], "Stone",
		Pal.SOCKET.lerp(Pal.SOCKET_OUT, blend))

## A tile is slate, or teal if a hint laid it; a mark is pebble. Neither
## blushes: nothing in a nonogram is wrong until a whole line says so, and
## the clue stones are where that is said.
func _paint_piece(cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	var node: Node3D = _pieces[cell]
	if _piece_kind.get(cell, "") == "mosaic_tile":
		Models.tint_named(node, "Mosaic",
			Pal.MOSAIC_LOCK if _locked.has(cell) else Pal.MOSAIC)
	else:
		Models.tint_named(node, "Pebble", Pal.PEBBLE)

## A line's stones go green together the moment its runs read exactly as its
## clue, and rose once it holds more filled cells than the clue accounts for.
func _fade_line(key: String, stones: Array, line: Array, clue: Array) -> void:
	var totals := _totals(line, clue)
	var over: bool = int(totals[0]) > int(totals[1])
	var exact: bool = Gen.clue_for(line) == clue
	var target := OVER_BLEND if over else 0.0
	var now: float = _line_blend.get(key, 0.0)
	# The green is a base colour rather than a blend, so it lands with the
	# last cell of the line; only the rose is faded.
	if is_equal_approx(now, target):
		Motion.stop(_line_fade.get(key))
		_line_fade.erase(key)
		_paint_line(now, key, stones, exact)
		return
	Motion.stop(_line_fade.get(key))
	var setter := _paint_line.bind(key, stones, exact)
	_line_fade[key] = Motion.fade(board, setter, now, target,
		BLUSH_IN if target > now else BLUSH_OUT, BLUSH_STEPS)

func _paint_line(blend: float, key: String, stones: Array, exact: bool) -> void:
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_line_blend[key] = blend
	var base: Color = Pal.GOOD if exact else Pal.STONE_GIVEN
	var col: Color = base.lerp(Pal.BAD, blend)
	for stone in stones:
		if is_instance_valid(stone):
			Models.tint_named(stone, "Stone", col)

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var at := BoardMath.world_to_cell(hit, w + _gw, h + _gh)
	if at.x < _gw or at.y < _gh:
		# The clue margin, not the floor.
		return
	var cell := Vector2i(at.x - _gw, at.y - _gh)
	if _locked.has(cell):
		_dip_piece(cell)
		fx.cue("locked")
		return
	var was := int(_marks.get(cell, BLANK))
	_history.append(Vector3i(cell.x, cell.y, was))
	_marks[cell] = (was + 1) % 3
	_set_piece(cell)
	_recolour()
	note_move()

## Control-local point over the centre of grid cell (r, c). The win harness
## taps this.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(_cell_at(r, c, plane_height()))

# --- capabilities ---

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func can_undo() -> bool:
	return not is_done() and not _history.is_empty()

## Takes back the last tap. Counts no move; no state in the history was
## solved, or the game would have ended there.
func undo() -> bool:
	if is_done() or _history.is_empty():
		return false
	var last: Vector3i = _history.pop_back()
	var cell := Vector2i(last.x, last.y)
	_marks[cell] = last.z
	_set_piece(cell)
	_recolour()
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Lays one tile the picture wants and pins it: the first cell in reading
## order the player has not filled. Three per puzzle; reset unpins them but
## does not refund them. Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or _bitmap.is_empty():
		return false
	var target := Vector2i(-1, -1)
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			if int(_bitmap[y][x]) == 1 and int(_marks.get(cell, BLANK)) != FILL:
				target = cell
				break
		if target.x >= 0:
			break
	if target.x < 0:
		return false
	# What came before the hint still describes this board, except for the one
	# cell the hint has taken over.
	var kept: Array[Vector3i] = []
	for entry in _history:
		if entry.x != target.x or entry.y != target.y:
			kept.append(entry)
	_history = kept
	_marks[target] = FILL
	_locked[target] = true
	_set_piece(target)
	fx.sparkle(_cell_at(target.y, target.x, Placeholders.PLOT_H + SPARKLE_LIFT))
	fx.cue("hint")
	hints_used += 1
	_recolour()
	moved.emit()
	check_solved()
	return true

## Shakes every tile the picture does not want, and returns how many. Solving
## stays automatic; this only points.
func check() -> int:
	if is_done() or _bitmap.is_empty():
		return 0
	checks += 1
	var wrong := 0
	for cell in _pieces.keys():
		if _piece_kind.get(cell, "") != "mosaic_tile":
			continue
		if int(_bitmap[cell.y][cell.x]) == 1:
			continue
		wrong += 1
		_flash_piece(cell)
	fx.cue("check" if wrong > 0 else "check_ok")
	return wrong

# --- motion on one cell ---

func _dip_piece(cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	var pivot: Node3D = _pieces[cell]
	Motion.stop(_piece_tw.get(cell))
	pivot.position.y = Placeholders.PLOT_H
	_piece_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, Placeholders.PLOT_H)

## A tile shakes and flashes rose, then settles back to slate: Check pointing
## at it. The flash is a straight tint rather than a fade, because a tile has
## no standing blend of its own to return to.
func _flash_piece(cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	var pivot: Node3D = _pieces[cell]
	Motion.stop(_piece_tw.get(cell))
	pivot.rotation.z = 0.0
	_piece_tw[cell] = Motion.wobble(pivot)
	var setter := func(blend: float) -> void:
		if not _pieces.has(cell):
			return
		var q := roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
		Models.tint_named(_pieces[cell], "Mosaic", Pal.MOSAIC.lerp(Pal.BAD, q))
	var tw: Tween = Motion.fade(pivot, setter, 0.0, 1.0, CHECK_IN, BLUSH_STEPS)
	if tw == null:
		_paint_piece(cell)
		return
	tw.tween_method(setter, 1.0, 0.0, CHECK_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- entrance and solve ---

## The board arrives: the platform rises out of the water, the sockets pop in
## along a diagonal wave, and the clue stones land last, so the eye reads the
## floor before the numbers around it.
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
	for cell in _sockets:
		_pop_in(_sockets[cell], ENTER_PLATFORM + Motion.stagger(cell.x + cell.y, ENTER_STAGGER))
	for runs in [_row_stones, _col_stones]:
		for i in runs.size():
			for stone in runs[i]:
				_pop_in(stone, ENTER_PLATFORM + ENTER_POP + Motion.stagger(i, ENTER_STAGGER))
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
	for cell in _sockets:
		(_sockets[cell] as Node3D).scale = Vector3.ONE
	for runs in [_row_stones, _col_stones]:
		for run in runs:
			for stone in run:
				(stone as Node3D).scale = Vector3.ONE

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## Every tile hops once, row by row from the far edge: the picture rises out
## of the floor it was laid in.
func _on_solved() -> void:
	for cell in _pieces.keys():
		if _piece_kind.get(cell, "") != "mosaic_tile":
			continue
		Motion.stop(_piece_tw.get(cell))
		_piece_tw[cell] = Motion.hop(_pieces[cell], SOLVE_HOP, SOLVE_TIME,
			Motion.stagger(cell.y, SOLVE_STAGGER), Placeholders.PLOT_H)
	fx.cue("solved")
