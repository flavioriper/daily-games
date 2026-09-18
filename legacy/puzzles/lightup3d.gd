extends "res://legacy/core/stage_board.gd"

## Light Up on the island stage. The board is a walled court of flagstones:
## every open cell is a floor slab, and every wall is a block of rough stone
## standing in the court, carrying its clue on its crown the way a Shikaku
## marker stone does. Tap an open cell to cycle through setting down a
## lantern, laying a slate chip on a cell you have ruled out, and clearing it
## again.
##
## The rule *is* the picture here, which is why the floor carries it: a
## flagstone no lamp reaches is a cold grey, one in lamplight is warm, and the
## light travels outward from the lantern you just set down a cell at a time
## rather than snapping on. So placing a lamp shows you, without a word, how
## far its light reaches and what stops it -- which is the whole of Light Up.
##
## The two rules the player can break are both shown where they break. A
## lantern that can see another lantern blushes, and a numbered block goes
## green once it touches exactly its number of lanterns and rose once it
## touches too many. The third condition -- every floor stone lit -- needs no
## marker: the cold stones are the ones still to do.
## Design: agreed in chat on 2026-09-15 (no spec file by request).

const Gen = preload("res://puzzles/lightup_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://legacy/core/models.gd")
const Placeholders = preload("res://legacy/core/placeholders.gd")
const Platform = preload("res://legacy/core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://legacy/world/fx.gd")

## The three states of an open cell, as the flat board had them.
const BLANK := 0
const BULB := 1
const MARK := 2

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## A piece arriving on a cell, and one being taken away.
const POP_TIME := 0.22
const VANISH_LIFT := 0.12
const VANISH_TIME := 0.16
## A refused tap (a wall block, or a lantern a hint lit) answers with a dip.
const DIP := 0.04
const DIP_TIME := 0.3
## The warm-up and cool-down of a floor stone as light reaches or leaves it,
## and the delay per cell of beam it is away from the lamp that changed --
## this is what makes the light read as travelling rather than switching.
const LIGHT_IN := 0.22
const LIGHT_OUT := 0.3
const LIGHT_STEP := 0.035
const LIGHT_CAP := 0.25
## The blush a lantern's glass takes when it can see another lantern, and a
## numbered block when it touches too many. Both are much further toward BAD
## than the 6/16 the other boards use, because neither starts from a neutral
## colour: a lamp's glass is already amber, and at 6/16 it went a slightly
## redder amber that nobody would read as wrong, while a block is already dark
## and went brown. Measured on the stage, not guessed. Both land on the
## 16-step grid _paint uses.
const CLASH_BLEND := 0.875
const OVER_BLEND := 0.75
const BLUSH_STEPS := 16
const BLUSH_IN := 0.25
const BLUSH_OUT := 0.4
const CHECK_IN := 0.15
const CHECK_OUT := 0.45
const HINTS := 3
## Clearance above the globe's crown for the flare a lamp is lit with. Above
## the lamp, not level with it: measured from the pad this used to be 0.35,
## which is inside a 0.52-tall lantern, so the stars were born in the glass.
const SPARKLE_LIFT := 0.08
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.025
const SOLVE_HOP := 0.1
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.04

var w: int = 6
var h: int = 6
var _grid: Array = []                # [y][x] -> Gen.WALL, Gen.WHITE or 0..4
var _solution_bulbs: Array = []
var _marks: Dictionary = {}          # Vector2i -> BLANK / BULB / MARK
var _locked: Dictionary = {}         # Vector2i -> true, a lantern a hint lit
## Vector2i -> how many cells of beam the nearest lantern is away, 0 on the
## lantern's own cell. Absent means the stone is still dark.
var _lit: Dictionary = {}
var _clash: Dictionary = {}          # Vector2i -> true, a lantern that sees another

var fx: Node3D
var _pads: Dictionary = {}           # Vector2i -> Node3D pivot, open cells only
var _pad_models: Dictionary = {}
var _pad_blend: Dictionary = {}      # Vector2i -> painted blend toward LAMPLIGHT
var _pad_fade: Dictionary = {}
var _blocks: Dictionary = {}         # Vector2i -> Node3D pivot, wall cells only
var _block_blend: Dictionary = {}    # Vector2i -> painted blend toward BAD
var _block_fade: Dictionary = {}
var _pieces: Dictionary = {}         # Vector2i -> Node3D, the lantern or chip on it
var _piece_kind: Dictionary = {}     # Vector2i -> which of the two it is
var _piece_blend: Dictionary = {}    # Vector2i -> painted blend toward BAD
var _piece_fade: Dictionary = {}
var _piece_tw: Dictionary = {}       # Vector2i -> a dip, shake or pop
var _entrance: Array = []
## One entry per tap that can be taken back: the cell and the mark before it.
var _history: Array[Vector3i] = []

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "lightup"
func title() -> String: return "Light Up"

func rules() -> String:
	return "Light every floor stone. A lantern lights its row and column until a block stops it. No lantern may light another. Numbers count the lanterns touching a block."

func board_size() -> Vector2i: return Vector2i(w, h)
## The tallest thing on the court: a lantern standing on a floor slab.
func board_height() -> float: return Placeholders.PLOT_H + Placeholders.LANTERN_H
func plane_height() -> float: return Placeholders.PLOT_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var pct := 0.22
	match difficulty:
		0: w = 5; h = 5; pct = 0.24
		1: w = 6; h = 6; pct = 0.22
		_: w = 7; h = 7; pct = 0.20
	var out: Dictionary = Gen.generate(rng, w, h, pct)
	_grid = out.grid
	_solution_bulbs = out.bulbs
	_marks = {}
	_locked = {}
	_history = []
	_recompute()
	_build_scene()
	_recolour()
	_refit()
	_enter()

## The court is cleared: every lantern and chip is taken away at once. Hints
## are unpinned but not refunded.
func reset_board() -> void:
	_stop_entrance()
	for cell in _marks.keys():
		_drop_piece(cell)
	_marks = {}
	_locked = {}
	_history = []
	moves = 0
	_recompute()
	_recolour()
	fx.cue("reset")

func is_solved() -> bool:
	if _grid.is_empty():
		return false
	var bulbs := _bulbs()
	if bulbs.is_empty():
		return false
	if Gen.bulbs_see_each_other(_grid, bulbs, w, h):
		return false
	if not Gen._clues_exact(_grid, bulbs, w, h):
		return false
	return Gen._all_lit(_grid, bulbs, w, h)

func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if _grid[y][x] != Gen.WHITE:
				out += "⬛"
			elif int(_marks.get(c, BLANK)) == BULB:
				out += "💡"
			elif _lit.has(c):
				out += "🟨"
			else:
				out += "⬜"
		out += "\n"
	return out

# --- the rules, as the board reads them ---

## Every cell the player has set a lantern on.
func _bulbs() -> Array:
	var out: Array = []
	for cell in _marks:
		if int(_marks[cell]) == BULB:
			out.append(cell)
	return out

## Recomputes what the light reaches and which lanterns see each other. `_lit`
## holds the distance in cells of beam to the nearest lantern, which is what
## the colour wave staggers on.
func _recompute() -> void:
	_lit = {}
	_clash = {}
	if _grid.is_empty():
		return
	var bulbs := _bulbs()
	var set: Dictionary = {}
	for b in bulbs:
		set[b] = true
	for b in bulbs:
		_lit[b] = 0
		for d in DIRS:
			var p: Vector2i = b + d
			var n := 1
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and _grid[p.y][p.x] == Gen.WHITE:
				if not _lit.has(p) or int(_lit[p]) > n:
					_lit[p] = n
				if set.has(p):
					_clash[b] = true
					_clash[p] = true
				p += d
				n += 1

## Lanterns touching the wall at `cell`, orthogonally.
func _touching(cell: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if int(_marks.get(cell + d, BLANK)) == BULB:
			n += 1
	return n

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for store in [_pad_fade, _block_fade, _piece_fade, _piece_tw]:
		for key in store:
			Motion.stop(store[key])

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pads = {}
	_pad_models = {}
	_pad_blend = {}
	_pad_fade = {}
	_blocks = {}
	_block_blend = {}
	_block_fade = {}
	_pieces = {}
	_piece_kind = {}
	_piece_blend = {}
	_piece_fade = {}
	_piece_tw = {}

	board.add_child(Platform.build(w, h))
	fx = Fx.new()
	board.add_child(fx)

	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var pivot := Node3D.new()
			pivot.position = _cell_at(y, x)
			board.add_child(pivot)
			if _grid[y][x] == Gen.WHITE:
				pivot.name = "stone_%d_%d" % [y, x]
				# Shikaku's own floor slab: the same island masonry, so the
				# court needs no flagstone model of its own.
				var pad := Models.instance("plot_pad")
				pivot.add_child(pad)
				_pads[cell] = pivot
				_pad_models[cell] = pad
				_pad_blend[cell] = 0.0
				# Painted here rather than left to _recolour: a fade only runs
				# when the blend has to move, so a stone that starts dark and
				# stays dark would never be painted at all and would keep the
				# cream the floor slab was modelled in.
				_paint_pad(0.0, cell)
			else:
				pivot.name = "block_%d_%d" % [y, x]
				var block := Models.instance("wall_block")
				var clue: int = _grid[y][x]
				for d in range(0, 5):
					Models.set_layer_visible(block, "Block_Num_%d" % d, d == clue)
				pivot.add_child(block)
				_blocks[cell] = pivot
				_block_blend[cell] = 0.0
				# Same reason, and the only paint an unnumbered wall ever gets:
				# it has no count to go green or rose on.
				_paint_block(0.0, cell, 0, clue)

## World point of cell (r, c) on the court.
func _cell_at(r: int, c: int, y := 0.0) -> Vector3:
	return BoardMath.cell_center(r, c, w, h, y)

# --- pieces on the court ---

## Puts the piece cell `cell` should be carrying on the board, taking away
## whatever was there. A lantern is set down with a flare, a chip is laid, and
## a piece that has gone shrinks away and is freed.
func _set_piece(cell: Vector2i) -> void:
	var mark := int(_marks.get(cell, BLANK))
	var want := "" if mark == BLANK else ("lantern" if mark == BULB else "cairn")
	if _piece_kind.get(cell, "") == want:
		_paint_piece(_piece_blend.get(cell, 0.0), cell)
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
	_piece_blend[cell] = 0.0
	pivot.scale = Vector3.ONE * 0.01
	Motion.settle(pivot, "scale", Vector3.ONE, POP_TIME)
	_paint_piece(0.0, cell)
	if want == "lantern":
		fx.sparkle(_cell_at(cell.y, cell.x,
			Placeholders.PLOT_H + Placeholders.LANTERN_H + SPARKLE_LIFT))
		fx.cue("light")
	else:
		fx.cue("chip")

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

## Repaints everything the state has moved under: the floor stones the light
## has reached or left, the lanterns, and the numbered blocks. `from` is the
## cell the player just changed, if any: the floor wave is delayed by the
## distance from it, so the light spreads out of the lamp rather than
## appearing everywhere at once.
func _recolour(from := Vector2i(-1, -1)) -> void:
	for cell in _pads:
		_fade_pad(cell, 1.0 if _lit.has(cell) else 0.0, _light_delay(from, cell))
	for cell in _pieces.keys():
		var bad := int(_marks.get(cell, BLANK)) == BULB and _clash.has(cell)
		_fade_piece(cell, CLASH_BLEND if bad else 0.0)
	for cell in _blocks:
		_fade_block(cell)

## How long the wave takes to reach `cell` from the cell that changed. Beams
## run along a row or a column, so the number of cells of beam between the two
## is their Manhattan distance; a cell the change did not touch keeps whatever
## colour it had, so its delay is never used.
func _light_delay(from: Vector2i, cell: Vector2i) -> float:
	if from.x < 0:
		return 0.0
	return Motion.stagger(absi(cell.x - from.x) + absi(cell.y - from.y),
		LIGHT_STEP, LIGHT_CAP)

## Eases one floor stone between cold grey and lamplight.
##
## A fade in flight is killed even when the stone already shows the colour it
## is being asked for, and that is the whole point of the guard: `_pad_blend`
## is the colour *painted so far*, so a stone one tap into warming up still
## reads 0.0. Taking the lamp away again in that moment used to leave the
## first fade running, and it would carry the stone all the way to lamplight
## and leave it there -- a lit floor with nothing lighting it. Cycling a cell
## lantern -> chip does exactly that, twice in a row, which is how it was
## found.
func _fade_pad(cell: Vector2i, target: float, delay: float) -> void:
	var now: float = _pad_blend.get(cell, 0.0)
	var settled := is_equal_approx(now, target)
	if settled and not Motion.running(_pad_fade.get(cell)):
		return
	Motion.stop(_pad_fade.get(cell))
	_pad_fade.erase(cell)
	if settled:
		_paint_pad(target, cell)
		return
	var setter := _paint_pad.bind(cell)
	_pad_fade[cell] = Motion.fade(_pads[cell], setter, now, target,
		LIGHT_IN if target > now else LIGHT_OUT, BLUSH_STEPS, delay)

func _paint_pad(blend: float, cell: Vector2i) -> void:
	if not _pad_models.has(cell):
		return
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_pad_blend[cell] = blend
	Models.tint_named(_pad_models[cell], "Stone", Pal.FLAGSTONE.lerp(Pal.LAMPLIGHT, blend))

## Eases one piece's blush to `target`. Kills a fade in flight even when the
## piece already shows `target`, for the reason _fade_pad sets out.
func _fade_piece(cell: Vector2i, target: float) -> void:
	var now: float = _piece_blend.get(cell, 0.0)
	var settled := is_equal_approx(now, target)
	if settled and not Motion.running(_piece_fade.get(cell)):
		return
	Motion.stop(_piece_fade.get(cell))
	_piece_fade.erase(cell)
	if settled:
		_paint_piece(target, cell)
		return
	var setter := _paint_piece.bind(cell)
	_piece_fade[cell] = Motion.fade(_pieces[cell], setter, now, target,
		BLUSH_IN if target > now else BLUSH_OUT, BLUSH_STEPS)

## A lantern's glass, or a chip's slate, at a blend toward BAD.
##
## A lantern a hint lit says so with its iron, not with its glass. Deeper
## amber was tried first, the language Shikaku's plots and Tents' canvas use
## for a given, and beside a lamp the player had placed it was invisible: the
## toon ramp under the island sun leaves nothing between SUN and SUN_DEEP that
## the eye can find on a globe this small. The collar is a value flip instead
## -- pale stone where the iron is normally near black -- and it reads at a
## glance without touching the one thing the glass has to mean, which is the
## light. A locked lamp refuses taps, so the player has to be able to see
## which ones they are.
func _paint_piece(blend: float, cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_piece_blend[cell] = blend
	var node: Node3D = _pieces[cell]
	if _piece_kind.get(cell, "") == "lantern":
		Models.tint_named(node, "Glass", Pal.SUN.lerp(Pal.BAD, blend))
		Models.tint_named(node, "Iron",
			Pal.STONE_GIVEN if _locked.has(cell) else Pal.LANTERN)
	else:
		Models.tint_named(node, "Pebble", Pal.CHIP.lerp(Pal.BAD, blend))

## A numbered block goes green once it touches exactly its number of lanterns
## and rose once it touches too many; short of the number it is plain stone.
## An unnumbered wall has nothing to say and never changes.
func _fade_block(cell: Vector2i) -> void:
	var want: int = _grid[cell.y][cell.x]
	if want < 0:
		return
	var have := _touching(cell)
	var target := OVER_BLEND if have > want else 0.0
	var now: float = _block_blend.get(cell, 0.0)
	# The green is a base colour rather than a blend, so it lands with the
	# count; only the rose is faded. A block already showing `target` still has
	# to be repainted, since its base may have just changed, and a fade in
	# flight still has to be killed -- see _fade_pad.
	if is_equal_approx(now, target):
		Motion.stop(_block_fade.get(cell))
		_block_fade.erase(cell)
		_paint_block(now, cell, have, want)
		return
	Motion.stop(_block_fade.get(cell))
	var setter := _paint_block.bind(cell, have, want)
	_block_fade[cell] = Motion.fade(_blocks[cell], setter, now, target,
		BLUSH_IN if target > now else BLUSH_OUT, BLUSH_STEPS)

func _paint_block(blend: float, cell: Vector2i, have: int, want: int) -> void:
	if not _blocks.has(cell):
		return
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_block_blend[cell] = blend
	var base: Color = Pal.GOOD if have == want else Pal.BLOCK_STONE
	Models.tint_named(_blocks[cell], "Block", base.lerp(Pal.BAD, blend))

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var at := BoardMath.world_to_cell(hit, w, h)
	if at.x < 0:
		return
	var cell := Vector2i(at.x, at.y)
	if _grid[cell.y][cell.x] != Gen.WHITE:
		# A block is never a lantern's cell; it dips to say so.
		_dip_block(cell)
		fx.cue("locked")
		return
	if _locked.has(cell):
		_dip_piece(cell)
		fx.cue("locked")
		return
	var was := int(_marks.get(cell, BLANK))
	_history.append(Vector3i(cell.x, cell.y, was))
	_marks[cell] = (was + 1) % 3
	_recompute()
	_set_piece(cell)
	_recolour(cell)
	note_move()

## Control-local point over the centre of cell (r, c). The win harness taps
## this.
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
	_recompute()
	_set_piece(cell)
	_recolour(cell)
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Lights one lantern from the answer and pins it: the first solution cell the
## board does not already carry one on. Three per puzzle; reset unpins them but
## does not refund them. Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var target := Vector2i(-1, -1)
	for b in _solution_bulbs:
		if int(_marks.get(b, BLANK)) != BULB:
			target = b
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
	_marks[target] = BULB
	_locked[target] = true
	_recompute()
	_set_piece(target)
	fx.cue("hint")
	hints_used += 1
	_recolour(target)
	moved.emit()
	check_solved()
	return true

## Shakes and flashes every lantern that is not where the answer puts one, and
## returns how many. Solving stays automatic; this only points.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong := 0
	for cell in _bulbs():
		if _solution_bulbs.has(cell):
			continue
		wrong += 1
		_flash_piece(cell)
	fx.cue("check" if wrong > 0 else "check_ok")
	return wrong

# --- motion on one cell ---

func _dip_block(cell: Vector2i) -> void:
	var pivot: Node3D = _blocks[cell]
	Motion.stop(_piece_tw.get(cell))
	pivot.position.y = 0.0
	_piece_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, 0.0)

func _dip_piece(cell: Vector2i) -> void:
	if not _pieces.has(cell):
		return
	var pivot: Node3D = _pieces[cell]
	Motion.stop(_piece_tw.get(cell))
	pivot.position.y = Placeholders.PLOT_H
	_piece_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, Placeholders.PLOT_H)

## A lantern shakes and blushes, then settles back to whatever blend its own
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
	var back: float = CLASH_BLEND if _clash.has(cell) else 0.0
	var tw: Tween = Motion.fade(pivot, setter, _piece_blend.get(cell, 0.0), 1.0,
		CHECK_IN, BLUSH_STEPS)
	if tw == null:
		setter.call(back)
		_piece_fade[cell] = null
		return
	tw.tween_method(setter, 1.0, back, CHECK_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_piece_fade[cell] = tw

# --- entrance and solve ---

## The board arrives: the platform rises out of the water, the flagstones pop
## in along a diagonal wave, and the blocks rise out of the finished floor, so
## the eye reads the court first and then what divides it.
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
	for cell in _pads:
		_pop_in(_pads[cell], ENTER_PLATFORM + Motion.stagger(cell.x + cell.y, ENTER_STAGGER))
	for cell in _blocks:
		_pop_in(_blocks[cell],
			ENTER_PLATFORM + ENTER_POP + Motion.stagger(cell.x + cell.y, ENTER_STAGGER))
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
	for store in [_pads, _blocks]:
		for cell in store:
			(store[cell] as Node3D).scale = Vector3.ONE

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## Every lantern hops once, row by row from the far edge: the court is lit.
func _on_solved() -> void:
	for cell in _pieces.keys():
		if _piece_kind.get(cell, "") != "lantern":
			continue
		Motion.stop(_piece_tw.get(cell))
		_piece_tw[cell] = Motion.hop(_pieces[cell], SOLVE_HOP, SOLVE_TIME,
			Motion.stagger(cell.y, SOLVE_STAGGER), Placeholders.PLOT_H)
	fx.cue("solved")
