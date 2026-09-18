extends "res://legacy/core/stage_board.gd"

## Tents & Trees on the island stage. The board is a meadow of turf cells with
## a conifer standing on some of them. Tap a cell to cycle through pitching a
## tent, laying a pebble cairn on ground you have ruled out, and clearing it
## again. The cairn is the mark the puzzle is actually solved with, which is
## why it is an object rather than a shade of grass.
##
## The row and column counts are Shikaku's own marker stones, laid on a margin
## of bare platform the board keeps around the field: the board is built one
## cell wider and one taller than the puzzle, the field sits inside that, and
## the far row and the left column carry the numbers. So the counts are full
## size, on stone rather than crowded onto the moss lip, and the camera frames
## them with the field because they are part of the same board.
##
## Feedback is on the count stones -- green once a line holds exactly its
## number of tents, rose once it holds too many -- and on the tents themselves:
## a tent blushes when it touches another tent, diagonals included, or when it
## stands beside no tree. Both are rules the player can see broken as they
## break them.
## Design: agreed in chat on 2026-09-15 (no spec file by request).

const Gen = preload("res://puzzles/tents_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://legacy/core/models.gd")
const Placeholders = preload("res://legacy/core/placeholders.gd")
const Platform = preload("res://legacy/core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://legacy/world/fx.gd")

## The three states of a cell, as the flat board had them.
const BLANK := 0
const TENT := 1
const GRASS := 2

## A piece arriving on a cell, and one being taken away.
const POP_TIME := 0.22
const VANISH_LIFT := 0.12
const VANISH_TIME := 0.16
## A refused tap (a tree's cell, or a tent a hint pitched) answers with a dip.
const DIP := 0.04
const DIP_TIME := 0.3
## The blush a tent takes when it breaks a rule, and a count stone when its
## line holds too many tents.
const BAD_BLEND := 0.375
const BLUSH_STEPS := 16
const BLUSH_IN := 0.25
const BLUSH_OUT := 0.4
const CHECK_IN := 0.15
const CHECK_OUT := 0.45
const HINTS := 3
const SPARKLE_LIFT := 0.3
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.025
const SOLVE_HOP := 0.1
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.04

var w: int = 7
var h: int = 7
var _trees: Dictionary = {}          # Vector2i -> true
var _row_counts: Array = []
var _col_counts: Array = []
var _solution_tents: Array = []
var _marks: Dictionary = {}          # Vector2i -> BLANK / TENT / GRASS
var _locked: Dictionary = {}         # Vector2i -> true, a tent a hint pitched

var fx: Node3D
var _pads: Array = []                # [r][c] -> Node3D pivot on the field
var _pad_models: Array = []
var _tree_nodes: Dictionary = {}     # Vector2i -> Node3D
var _pieces: Dictionary = {}         # Vector2i -> Node3D, the tent or cairn on it
var _piece_kind: Dictionary = {}     # Vector2i -> which of the two it is
var _piece_blend: Dictionary = {}    # Vector2i -> painted blend toward BAD
var _piece_fade: Dictionary = {}     # Vector2i -> a blush fade in flight
var _piece_tw: Dictionary = {}       # Vector2i -> a dip, shake or pop
var _row_stones: Array = []          # [r] -> Node3D
var _col_stones: Array = []          # [c] -> Node3D
var _line_blend: Dictionary = {}     # "r<i>" / "c<i>" -> painted blend
var _line_fade: Dictionary = {}
var _entrance: Array = []
## One entry per tap that can be taken back: the cell and the mark before it.
var _history: Array[Vector3i] = []

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "tents"
func title() -> String: return "Tents"

func rules() -> String:
	return "Pitch one tent orthogonally beside each tree. Tents never touch, not even diagonally. Numbers count the tents in each line."

## One cell wider and taller than the puzzle: the far row and the left column
## are the margin the count stones sit on.
func board_size() -> Vector2i: return Vector2i(w + 1, h + 1)
func board_height() -> float: return Placeholders.TURF_H + Placeholders.PINE_H
func plane_height() -> float: return Placeholders.TURF_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var pairs := 7
	match difficulty:
		0: w = 6; h = 6; pairs = 5
		1: w = 7; h = 7; pairs = 7
		_: w = 8; h = 8; pairs = 9
	var out: Dictionary = Gen.generate(rng, w, h, pairs)
	_trees = {}
	for t in out.trees:
		_trees[t] = true
	_solution_tents = out.tents
	_row_counts = out.row_counts
	_col_counts = out.col_counts
	_marks = {}
	_locked = {}
	_history = []
	_build_scene()
	_recolour()
	_refit()
	_enter()

## The meadow is cleared: every tent and cairn is taken away at once. Hints are
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
	if _trees.is_empty():
		return false
	return Gen.is_valid_solution(_tents(), _trees.keys(), _row_counts, _col_counts, w, h)

func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if _trees.has(c):
				out += "🌲"
			elif int(_marks.get(c, BLANK)) == TENT:
				out += "⛺"
			else:
				out += "🟩"
		out += "\n"
	return out

# --- the rules, as the board reads them ---

## Every cell the player has pitched a tent on.
func _tents() -> Array:
	var out: Array = []
	for cell in _marks:
		if int(_marks[cell]) == TENT:
			out.append(cell)
	return out

## Tents in row `r` / column `c`.
func _row_tents(r: int) -> int:
	var n := 0
	for cell in _marks:
		if cell.y == r and int(_marks[cell]) == TENT:
			n += 1
	return n

func _col_tents(c: int) -> int:
	var n := 0
	for cell in _marks:
		if cell.x == c and int(_marks[cell]) == TENT:
			n += 1
	return n

## Whether a tent on `cell` breaks a rule the player can see: it touches
## another tent (diagonals included) or it stands beside no tree. A tree with
## no tent yet is not an error -- that is just an unfinished puzzle.
func _tent_blushes(cell: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var at := cell + Vector2i(dx, dy)
			if int(_marks.get(at, BLANK)) == TENT:
				return true
	for d in Gen.DIRS:
		if _trees.has(cell + d):
			return false
	return true

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for store in [_piece_fade, _piece_tw, _line_fade]:
		for key in store:
			Motion.stop(store[key])

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pads = []
	_pad_models = []
	_tree_nodes = {}
	_pieces = {}
	_piece_kind = {}
	_piece_blend = {}
	_piece_fade = {}
	_piece_tw = {}
	_row_stones = []
	_col_stones = []
	_line_blend = {}
	_line_fade = {}

	board.add_child(Platform.build(w + 1, h + 1))
	fx = Fx.new()
	board.add_child(fx)

	for r in h:
		var pad_row := []
		var model_row := []
		for c in w:
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [r, c]
			pivot.position = _field_at(r, c)
			board.add_child(pivot)
			var pad := Models.instance("turf_pad")
			pivot.add_child(pad)
			pad_row.append(pivot)
			model_row.append(pad)
			if _trees.has(Vector2i(c, r)):
				var tree := Models.instance("camp_tree")
				tree.position.y = Placeholders.TURF_H
				pivot.add_child(tree)
				_tree_nodes[Vector2i(c, r)] = tree
		_pads.append(pad_row)
		_pad_models.append(model_row)

	# The counts: a marker stone on the margin at the head of every line.
	for c in w:
		_col_stones.append(_count_stone("col_%d" % c, _col_count_at(c), _col_counts[c]))
	for r in h:
		_row_stones.append(_count_stone("row_%d" % r, _row_count_at(r), _row_counts[r]))

## One count stone: a marker showing `n`, on the bare platform margin.
func _count_stone(node_name: String, at: Vector3, n: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = at
	board.add_child(pivot)
	var stone := Models.instance("clue_stone")
	for d in range(0, 10):
		Models.set_layer_visible(stone, "Clue_Num_%d" % d, d == n)
	pivot.add_child(stone)
	return pivot

## World point of field cell (r, c). The field sits inside the board's own
## grid, one cell in from the far edge and one from the left, so the margin
## the counts stand on is a whole cell rather than a sliver of lip.
func _field_at(r: int, c: int, y := 0.0) -> Vector3:
	return BoardMath.cell_center(r + 1, c + 1, w + 1, h + 1, y)

func _col_count_at(c: int) -> Vector3:
	return BoardMath.cell_center(0, c + 1, w + 1, h + 1)

func _row_count_at(r: int) -> Vector3:
	return BoardMath.cell_center(r + 1, 0, w + 1, h + 1)

# --- pieces on the field ---

## Puts the piece cell `cell` should be carrying on the board, taking away
## whatever was there. A tent pops up, a cairn is set down, and a piece that
## has gone shrinks away and is freed.
func _set_piece(cell: Vector2i) -> void:
	var mark := int(_marks.get(cell, BLANK))
	var want := "" if mark == BLANK else ("tent" if mark == TENT else "cairn")
	if _piece_kind.get(cell, "") == want:
		_paint_piece(_piece_blend.get(cell, 0.0), cell)
		return
	_drop_piece(cell)
	if want == "":
		return
	var pivot := Node3D.new()
	pivot.name = "%s_%d_%d" % [want, cell.y, cell.x]
	pivot.position = _field_at(cell.y, cell.x, Placeholders.TURF_H)
	board.add_child(pivot)
	pivot.add_child(Models.instance(want))
	_pieces[cell] = pivot
	_piece_kind[cell] = want
	_piece_blend[cell] = 0.0
	pivot.scale = Vector3.ONE * 0.01
	Motion.settle(pivot, "scale", Vector3.ONE, POP_TIME)
	_paint_piece(0.0, cell)
	fx.cue("pitch" if want == "tent" else "cairn")

## Takes the piece off `cell`, if it has one.
func _drop_piece(cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	var gone: Node3D = _pieces[cell]
	_pieces.erase(cell)
	_piece_kind.erase(cell)
	_piece_blend.erase(cell)
	Motion.stop(_piece_fade.get(cell))
	_piece_fade.erase(cell)
	Motion.stop(_piece_tw.get(cell))
	_piece_tw.erase(cell)
	var tw: Tween = Motion.vanish(gone, VANISH_LIFT, VANISH_TIME)
	if tw == null:
		gone.queue_free()
	else:
		tw.finished.connect(gone.queue_free)

# --- colour ---

## Repaints everything the state has moved under: the turf, the tents and
## cairns, and the count stone at the head of every line.
func _recolour() -> void:
	for r in h:
		for c in w:
			var cell := Vector2i(c, r)
			Models.tint_named(_pad_models[r][c], "Turf",
				Pal.TURF_TREE if _trees.has(cell) else Pal.TURF)
	for cell in _pieces.keys():
		var target := BAD_BLEND if (int(_marks.get(cell, BLANK)) == TENT
			and _tent_blushes(cell)) else 0.0
		_fade_piece(cell, target)
	for r in h:
		_fade_line("r%d" % r, _row_stones[r], _row_tents(r), _row_counts[r])
	for c in w:
		_fade_line("c%d" % c, _col_stones[c], _col_tents(c), _col_counts[c])

## Eases one piece's blush to `target`, leaving a fade already heading there
## alone.
func _fade_piece(cell: Vector2i, target: float) -> void:
	var now: float = _piece_blend.get(cell, 0.0)
	if is_equal_approx(now, target):
		return
	Motion.stop(_piece_fade.get(cell))
	var setter := _paint_piece.bind(cell)
	_piece_fade[cell] = Motion.fade(_pieces[cell], setter, now, target,
		BLUSH_IN if target > now else BLUSH_OUT, BLUSH_STEPS)

## A tent's canvas, or a cairn's pebbles, at a blend toward BAD. A hinted
## tent's canvas is duller, the language every board uses for a fixed piece.
func _paint_piece(blend: float, cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_piece_blend[cell] = blend
	var node: Node3D = _pieces[cell]
	if _piece_kind.get(cell, "") == "tent":
		var base: Color = Pal.CANVAS_LOCK if _locked.has(cell) else Pal.CANVAS
		Models.tint_named(node, "Canvas", base.lerp(Pal.BAD, blend))
	else:
		Models.tint_named(node, "Pebble", Pal.PEBBLE.lerp(Pal.BAD, blend))

## A count stone goes green once its line holds exactly its number of tents
## and rose once it holds too many; short of the number it is plain stone.
func _fade_line(key: String, stone: Node3D, have: int, want: int) -> void:
	var target := BAD_BLEND if have > want else 0.0
	var now: float = _line_blend.get(key, 0.0)
	# The green is a base colour rather than a blend, so it lands with the
	# count; only the rose is faded.
	if is_equal_approx(now, target):
		_paint_line(now, key, stone, have, want)
		return
	Motion.stop(_line_fade.get(key))
	var setter := _paint_line.bind(key, stone, have, want)
	_line_fade[key] = Motion.fade(stone, setter, now, target,
		BLUSH_IN if target > now else BLUSH_OUT, BLUSH_STEPS)

func _paint_line(blend: float, key: String, stone: Node3D, have: int, want: int) -> void:
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_line_blend[key] = blend
	var base: Color = Pal.GOOD if have == want else Pal.STONE_GIVEN
	Models.tint_named(stone, "Stone", base.lerp(Pal.BAD, blend))

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var big := BoardMath.world_to_cell(hit, w + 1, h + 1)
	if big.x < 1 or big.y < 1:
		# The count margin, not the field.
		return
	var cell := Vector2i(big.x - 1, big.y - 1)
	if _trees.has(cell):
		# A tree's cell is never a tent's; the pad dips to say so.
		_dip_pad(cell)
		fx.cue("locked")
		return
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

## Control-local point over the centre of field cell (r, c). The win harness
## taps this.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(_field_at(r, c, plane_height()))

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

## Pitches one tent from the answer and pins it: the first solution tent the
## board does not already carry. Three per puzzle; reset unpins them but does
## not refund them. Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var target := Vector2i(-1, -1)
	for t in _solution_tents:
		if int(_marks.get(t, BLANK)) != TENT:
			target = t
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
	_marks[target] = TENT
	_locked[target] = true
	_set_piece(target)
	fx.sparkle(_field_at(target.y, target.x, Placeholders.TURF_H + SPARKLE_LIFT))
	fx.cue("hint")
	hints_used += 1
	_recolour()
	moved.emit()
	check_solved()
	return true

## Shakes and flashes every tent that is not where the answer puts one, and
## returns how many. Solving stays automatic; this only points.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong := 0
	for cell in _tents():
		if _solution_tents.has(cell):
			continue
		wrong += 1
		_flash_piece(cell)
	fx.cue("check" if wrong > 0 else "check_ok")
	return wrong

# --- motion on one cell ---

func _dip_pad(cell: Vector2i) -> void:
	var pivot: Node3D = _pads[cell.y][cell.x]
	Motion.stop(_piece_tw.get(cell))
	pivot.position.y = 0.0
	_piece_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, 0.0)

func _dip_piece(cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	var pivot: Node3D = _pieces[cell]
	Motion.stop(_piece_tw.get(cell))
	pivot.position.y = Placeholders.TURF_H
	_piece_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, Placeholders.TURF_H)

## A tent shakes and blushes, then settles back to whatever blend its own
## rules ask for: Check pointing at it.
func _flash_piece(cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	var pivot: Node3D = _pieces[cell]
	Motion.stop(_piece_tw.get(cell))
	pivot.rotation.z = 0.0
	_piece_tw[cell] = Motion.wobble(pivot)
	Motion.stop(_piece_fade.get(cell))
	var setter := _paint_piece.bind(cell)
	var back: float = BAD_BLEND if _tent_blushes(cell) else 0.0
	var tw: Tween = Motion.fade(_pieces[cell], setter, _piece_blend.get(cell, 0.0), 1.0,
		CHECK_IN, BLUSH_STEPS)
	if tw == null:
		setter.call(back)
		_piece_fade[cell] = null
		return
	tw.tween_method(setter, 1.0, back, CHECK_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_piece_fade[cell] = tw

# --- entrance and solve ---

## The board arrives: the platform rises out of the water, the turf pops in
## along a diagonal wave, the trees grow once their ground is there, and the
## count stones land last so the eye reads the field before the numbers.
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
	for cell in _tree_nodes:
		_pop_in(_tree_nodes[cell],
			ENTER_PLATFORM + ENTER_POP + Motion.stagger(cell.y + cell.x, ENTER_STAGGER))
	for stones in [_row_stones, _col_stones]:
		for i in stones.size():
			_pop_in(stones[i], ENTER_PLATFORM + ENTER_POP + Motion.stagger(i, ENTER_STAGGER))
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
	for cell in _tree_nodes:
		(_tree_nodes[cell] as Node3D).scale = Vector3.ONE
	for stones in [_row_stones, _col_stones]:
		for pivot in stones:
			(pivot as Node3D).scale = Vector3.ONE

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## Every tent hops once, row by row from the far edge: the camp is pitched.
func _on_solved() -> void:
	for cell in _pieces.keys():
		if _piece_kind.get(cell, "") != "tent":
			continue
		Motion.stop(_piece_tw.get(cell))
		_piece_tw[cell] = Motion.hop(_pieces[cell], SOLVE_HOP, SOLVE_TIME,
			Motion.stagger(cell.y, SOLVE_STAGGER), Placeholders.TURF_H)
	fx.cue("solved")
