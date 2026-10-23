extends "res://puzzles/sudoku2d.gd"

## Picket Sums, flat: Sudoku's grid fenced into garden plots. Every row,
## column and region holds each number once, and each plot's numbers add up
## to the number on its tag, never one twice. Insane is **Lost Tags**: some
## plots have lost theirs, and only never repeat.
##
## **This is Sudoku's board** (puzzles/sudoku2d.gd), its tray, panels,
## washes, pad, pencil, waves, daisies, undo, hint and party, with the plots
## laid over it; the rules are puzzles/picket_state.gd and the days
## puzzles/picket_gen.gd (Hard and Insane from banks mined on the Mac). What
## is its own: the fences, the tags, and what a plot does when it comes
## right (its cells light leaf-gold one after another and its tag hops) or
## can no longer come true (its fence and tag turn rose and the tag shakes).
##
## **The fences are one mesh** with the tags' wooden markers in it, rebuilt
## only when what they show changes: the cell size, the selected plot, a
## plot's standing, or a tag hopping or shaking. The tags' numbers are
## strings over it, as the grid's numerals are.
## Spec: docs/superpowers/specs/2026-10-22-picket-design.md.

const PicketState = preload("res://puzzles/picket_state.gd")
const PicketWorld = preload("res://puzzles/picket_world.gd")

## The fence: one soft line inset from the cells' rules, unbroken round the
## plot (a dashed one read as a web page's border, the user's "canvas
## game"), at a 100 cell. It thickens and takes the state's colour when its
## plot is selected, right or past saving.
const FENCE_INSET := 8.0
const FENCE_W := 2.4
const FENCE := Color("ac9475")
const FENCE_SEL := Color("e08a12")
const FENCE_SEL_W := 1.45
## The tag: the plot's sum in its top-left corner, on a little paper pill
## the fence's corner tucks under. Paper while the plot is open; the
## state's colour, its number in paper, once selected, right or past saving.
const TAG_AT := Vector2(3.0, 3.0)
const TAG_SIZE := 23.0
const TAG_PAD := Vector2(5.0, 1.5)
const TAG_R := 6.0
const TAG_INK := Color("6e5a44")
const TAG_FACE := Color("fffcf5")
const TAG_WEIGHT := 700
const TAG_LOST := "?"
## The cells' rules under the fences.
const THIN_FAINT := 0.38
## A plot come right: its cells light one after another, its tag hops.
const PLOT_STEP := 0.06
const TAG_HOP := -11.0
const TAG_HOP_TIME := 0.42
## The pencil marks sit a little down and right of Sudoku's, clear of a tag.
const NOTE_NUDGE := Vector2(0.05, 0.08)
const NOTE_PACK := 0.9

const TIPS_PK := ["PK_TIP_SUM", "PK_TIP_SMALL", "PK_TIP_UNIT"]

## Each plot's standing as last diffed (PicketState.plot_standing).
var _stand := PackedInt32Array()
var _tag_hop: Dictionary = {}     # plot -> at
var _tag_shake: Dictionary = {}   # plot -> at
var _fence_mesh: ArrayMesh
var _fence_shown: ArrayMesh
var _fence_key := ""

## Sudoku's map, and a plot come right bumps as a finished row does
## (docs/agents/haptics.md).
const PICKET_HAPTICS := {"plot": Haptics.BUMP}

func puzzle_id() -> String: return "picket"
func title() -> String: return "Picket Sums"

func _ready() -> void:
	super()
	fx.haptics = HAPTICS.merged(PICKET_HAPTICS)

func _new_state() -> State:
	return PicketState.new()

func _new_world() -> Control:
	return PicketWorld.new()

func rules() -> String:
	var out: String = tr("PK_RULES") % [Gen.BOX_R, Gen.BOX_C, Gen.N]
	if state != null and state.lost_count() > 0:
		out += "\n\n" + tr("PK_RULES_LOST")
	return out

## One lesson a page, each played by a quiet board on a fixed little grid
## (ui/hud/picket_tutorial_diagram.gd): a plot's tag, the rows and regions,
## Lost Tags on Insane, Undo, and the bulb.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/picket_tutorial_diagram.gd")
	var band: int = state.band if state != null else 0
	var hints: int = PicketState.PICKET_HINTS[band]
	var steps := [
		[Diagram.Lesson.PLOT, "HTP_PK_PLOT", tr("HTP_PK_PLOT_BODY")],
		[Diagram.Lesson.LINES, "HTP_PK_LINES", tr("HTP_PK_LINES_BODY") % Gen.N],
	]
	if state != null and state.lost_count() > 0:
		steps.append([Diagram.Lesson.LOST, "PK_LOST_SEAL", tr("PK_RULES_LOST")])
	steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO", tr("HTP_SD_UNDO_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_SD_HINT_BODY_ONE") if hints == 1 else tr("HTP_SD_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Undo and the bulb on every band: nothing here counts moves.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _tips() -> Array:
	if state != null and state.lost_count() > 0:
		return ["PK_TIP_LOST"] + TIPS_PK
	return TIPS_PK

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	super(rng, difficulty)
	_stand = state.standings()
	_tag_hop = {}
	_tag_shake = {}
	_fence_key = ""

func day_dict() -> Dictionary:
	if state == null or state.sol.is_empty():
		return {}
	var n: int = Gen.N
	var puzzle: Array = []
	var answer: Array = []
	for i in n * n:
		var v := int(state.given[i])
		var cell := {}
		if v > 0:
			cell = {"t": str(v), "given": true}
		var p: int = state.cage_of[i]
		if int(state.plots[p][0]) == i:
			cell["note"] = "?" if state.sums[p] < 0 else str(state.sums[p])
		puzzle.append(cell)
		answer.append({"t": str(int(state.sol[i])), "given": v > 0})
	var banked: bool = state.band >= 2 and InsaneBank.size("picket" if state.band == 3 else "picket_hard") > 0
	return {
		"source": "bank" if banked else "generator", "kind": "grid",
		"payload": {"n": n, "puzzle": Array(state.given), "plots": Array(state.cage_of),
			"sums": Array(state.sums)},
		"solution": {"grid": Array(state.sol)},
		"metrics": {"size": n, "clues": n * n - int(state.target), "blanks": int(state.target),
			"plots": state.plots.size(), "lost": state.lost_count(), "hints": state.hints_left},
		"view": {"w": n, "h": n, "puzzle": puzzle, "solution": answer, "regions": Array(state.cage_of)},
	}

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("PK_WIN")}

func share_glyphs() -> String:
	if state == null:
		return ""
	if state.band == 3:
		return "🌙 " + tr("PK_LOST_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	if _flawless:
		return "🏅 " + tr("BN_FLAWLESS")
	return ""

func restore_completed_board() -> void:
	super()
	if state == null:
		return
	_stand = state.standings()
	_tag_hop = {}
	_tag_shake = {}
	_fence_key = ""

# --- the plots' moments ---

## Every move ends here (Sudoku's daisies are diffed in the same place), so
## a plot's standing is diffed once a move: one come right lights and hops,
## one that can no longer come true shakes its tag.
func _update_stickers(now: float) -> void:
	super(now)
	if state == null:
		return
	var after: PackedInt32Array = state.standings()
	if after.size() == _stand.size():
		for p in after.size():
			if after[p] == 1 and _stand[p] != 1:
				_plot_up(p, now)
			elif after[p] == -1 and _stand[p] != -1:
				_tag_shake[p] = now
				_busy_for(Motion.SHIVER_TIME)
	_stand = after
	_fence_key = ""

func _plot_up(p: int, now: float) -> void:
	var cells: PackedInt32Array = state.plots[p]
	_tag_hop[p] = now
	_busy_for(TAG_HOP_TIME)
	if not Motion.reduce:
		for k in cells.size():
			var i := cells[k]
			var when := now + k * PLOT_STEP
			if not _flash.has(i) or float(_flash[i]) < when:
				_flash[i] = when
			_busy_for(when - now + WAVE_FLASH)
	if not state.is_solved():
		fx.cue("plot")
		fx.sparkle(_tag_mid(p), Pal.LEAF)

func _moving(now: float) -> bool:
	return super(now) or _live(_tag_hop, now, TAG_HOP_TIME) \
		or _live(_tag_shake, now, Motion.SHIVER_TIME)

# --- the drawing ---

## The fences go over the grid's mesh and under the numerals, the tags over
## the numerals, all under the entrance's pop.
func _draw_numerals(now: float, pop: float, centre: Vector2) -> void:
	var moving := _live(_tag_hop, now, TAG_HOP_TIME) or _live(_tag_shake, now, Motion.SHIVER_TIME)
	var key := "%s|%s|%d|%s" % [_cell, _grid, _sel_plot(), _stand]
	if moving or key != _fence_key or _fence_mesh == null:
		_fence_mesh = _build_fences(now)
		_fence_key = "" if moving else key
	_fence_shown = _fence_mesh
	var xf := Transform2D(0.0, Vector2.ONE * pop, 0.0, centre * (1.0 - pop))
	if _fence_shown != null:
		draw_mesh(_fence_shown, null, xf)
	super(now, pop, centre)
	_draw_tags(now, pop, centre)

func _sel_plot() -> int:
	return state.cage_of[_sel] if _sel >= 0 and state != null else -1

func _ink_of(p: int) -> Color:
	var s: int = _stand[p] if p < _stand.size() else 0
	if s == 1:
		return Pal.LEAF_DEEP
	if s == -1:
		return Pal.BAD
	return FENCE_SEL if p == _sel_plot() else FENCE

func _same(p: int, r: int, c: int) -> bool:
	return r >= 0 and r < Gen.N and c >= 0 and c < Gen.N and state.cage_of[r * Gen.N + c] == p

func _build_fences(now: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var k := _scale()
	var sel := _sel_plot()
	# A solved board keeps its fences thin and its tags paper, numbers in
	# leaf: twenty-odd filled pills at once shouted over the win.
	var done: bool = state.is_solved()
	# The open plots' fences first, so a lit one is never crossed by a
	# neighbour's.
	for lit in [false, true]:
		for i in Gen.CELLS:
			var p: int = state.cage_of[i]
			var ink := _ink_of(p)
			if (ink != FENCE) != lit:
				continue
			var r := Gen.row_of(i)
			var c := Gen.col_of(i)
			var w := FENCE_W * k * (FENCE_SEL_W if (lit and not done) or p == sel else 1.0)
			fence_cell(b, _corner_of(i), _cell, FENCE_INSET * k,
				func(dr: int, dc: int) -> bool: return _same(p, r + dr, c + dc), w, ink)
	var font: Font = CozyTheme.body(TAG_WEIGHT)
	var px := int(roundf(TAG_SIZE * k))
	for p in state.plots.size():
		var ink := _ink_of(p)
		var quiet: bool = ink == FENCE or (done and p != sel)
		tag_pill(b, _tag_box(p, now, font, px), k, TAG_FACE if quiet else ink, quiet)
	return b.mesh()

## The fence round one cell of a plot, cell's top left at `o`, `cl` wide,
## `ins` in from its rules: a side wherever `same(dr, dc)` says the
## neighbour is another plot's, each side running on into the next cell's
## where the plot turns a corner, so the line is unbroken. Shared with the
## menu card (ui/menu/cards/picket.gd).
static func fence_cell(b: Face.Builder, o: Vector2, cl: float, ins: float, same: Callable, w: float,
		ink: Color) -> void:
	if not same.call(-1, 0):
		var x0 := ins if not same.call(0, -1) else (-ins if same.call(-1, -1) else 0.0)
		var x1 := cl - ins if not same.call(0, 1) else (cl + ins if same.call(-1, 1) else cl)
		b.stroke(PackedVector2Array([o + Vector2(x0, ins), o + Vector2(x1, ins)]), w, ink)
	if not same.call(1, 0):
		var x0 := ins if not same.call(0, -1) else (-ins if same.call(1, -1) else 0.0)
		var x1 := cl - ins if not same.call(0, 1) else (cl + ins if same.call(1, 1) else cl)
		b.stroke(PackedVector2Array([o + Vector2(x0, cl - ins), o + Vector2(x1, cl - ins)]), w, ink)
	if not same.call(0, -1):
		var y0 := ins if not same.call(-1, 0) else (-ins if same.call(-1, -1) else 0.0)
		var y1 := cl - ins if not same.call(1, 0) else (cl + ins if same.call(1, -1) else cl)
		b.stroke(PackedVector2Array([o + Vector2(ins, y0), o + Vector2(ins, y1)]), w, ink)
	if not same.call(0, 1):
		var y0 := ins if not same.call(-1, 0) else (-ins if same.call(-1, 1) else 0.0)
		var y1 := cl - ins if not same.call(1, 0) else (cl + ins if same.call(1, 1) else cl)
		b.stroke(PackedVector2Array([o + Vector2(cl - ins, y0), o + Vector2(cl - ins, y1)]), w, ink)

## A tag's pill in `box`: paper with a hairline while its plot is open
## (`quiet`), else filled in its state's colour over a soft drop.
static func tag_pill(b: Face.Builder, box: Rect2, k: float, fill: Color, quiet: bool) -> void:
	var r := TAG_R * k
	if quiet:
		b.fan(Face.Builder.round_rect(box.position, box.size, r), Color(FENCE, 0.55))
		var e := maxf(1.0 * k, 0.75)
		b.fan(Face.Builder.round_rect(box.position + Vector2.ONE * e, box.size - Vector2.ONE * 2.0 * e,
			maxf(r - e, 1.0)), fill)
	else:
		b.fan(Face.Builder.round_rect(box.position + Vector2(0.0, 1.5 * k), box.size, r), Color(Pal.TEXT, 0.16))
		b.fan(Face.Builder.round_rect(box.position, box.size, r), fill)

## The pill round `wide` of a tag's number at `px`, its top left at `at`.
static func tag_rect(at: Vector2, wide: float, font: Font, px: int, k: float) -> Rect2:
	return Rect2(at, Vector2(maxf(wide + 2.0 * TAG_PAD.x * k, font.get_height(px) * 0.78 + 2.0 * TAG_PAD.y * k),
		font.get_height(px) * 0.78 + 2.0 * TAG_PAD.y * k))

## Where a tag's number stands in its pill.
static func tag_base(box: Rect2, wide: float, font: Font, px: int) -> Vector2:
	return Vector2(box.get_center().x - wide * 0.5,
		box.get_center().y + font.get_ascent(px) * 0.5 - font.get_descent(px) * 0.2)

func _tag_text(p: int) -> String:
	return TAG_LOST if state.sums[p] < 0 else str(state.sums[p])

## The tag's pill, hopped or shaken as its plot's moment says.
func _tag_box(p: int, now: float, font: Font, px: int) -> Rect2:
	var k := _scale()
	var wide := font.get_string_size(_tag_text(p), HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var at := _corner_of(int(state.plots[p][0])) + TAG_AT * k
	if not Motion.reduce:
		var hop := now - float(_tag_hop.get(p, -INF))
		if hop < TAG_HOP_TIME:
			at.y += TAG_HOP * k * sin(PI * hop / TAG_HOP_TIME)
		var shake := now - float(_tag_shake.get(p, -INF))
		if shake < Motion.SHIVER_TIME:
			at.x += Motion.shiver_offset(shake, Motion.SHIVER_PX * 2.0 * k)
	return tag_rect(at, wide, font, px, k)

func _tag_mid(p: int) -> Vector2:
	var font: Font = CozyTheme.body(TAG_WEIGHT)
	return _tag_box(p, _now(), font, int(roundf(TAG_SIZE * _scale()))).get_center()

func _draw_tags(now: float, pop: float, centre: Vector2) -> void:
	var font: Font = CozyTheme.body(TAG_WEIGHT)
	var px := int(roundf(TAG_SIZE * _scale()))
	if px <= 0:
		return
	draw_set_transform(centre * (1.0 - pop), 0.0, Vector2.ONE * pop)
	var done: bool = state.is_solved()
	for p in state.plots.size():
		var box := _tag_box(p, now, font, px)
		var text := _tag_text(p)
		var ink: Color = TAG_INK if state.sums[p] >= 0 else Pal.TEXT_DIM
		if _ink_of(p) != FENCE:
			ink = Pal.LEAF_DEEP if done and p != _sel_plot() else TAG_FACE
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, tag_base(box, wide, font, px), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)
	draw_set_transform(Vector2.ZERO)

## Every panel plain paper: the fences are the pattern here, and a chequer
## under them read as plots of its own.
func _panel_shaded(_br: int, _bc: int) -> bool:
	return false

## The cells' rules faint, so a plot's fence is the line the eye follows.
func _thin_alpha() -> float:
	return THIN_FAINT

## Sudoku's pencil marks packed a little tighter and moved off the tag.
func _note_spot(n: int) -> Vector2:
	return super(n) * NOTE_PACK + NOTE_NUDGE * _cell
