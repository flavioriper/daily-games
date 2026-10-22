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

## The fence: inset from the cell's edge, its pickets (dashes) and the rail
## under them, at a 100 cell.
const FENCE_INSET := 7.5
const FENCE_W := 3.4
const RAIL_W := 1.6
const RAIL_A := 0.35
const PICKET := 8.0
const PICKET_GAP := 5.0
const FENCE := Color("8f6a45")
const FENCE_SEL := Color("e08a12")
const FENCE_SEL_W := 1.3
## The tag: a little wooden plant marker over the plot's top-left corner.
const TAG_AT := Vector2(2.5, 2.5)
const TAG_SIZE := 22.0
const TAG_PAD := Vector2(6.0, 2.0)
const TAG_R := 5.0
const TAG_EDGE := 2.0
const TAG_FACE := Color("fff6e2")
const TAG_LOST := "?"
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
	var ins := FENCE_INSET * k
	var cl := _cell
	for i in Gen.CELLS:
		var p: int = state.cage_of[i]
		var r := Gen.row_of(i)
		var c := Gen.col_of(i)
		var o := _corner_of(i)
		var ink := _ink_of(p)
		var w := FENCE_W * k * (FENCE_SEL_W if p == _sel_plot() else 1.0)
		if not _same(p, r - 1, c):
			var x0 := ins if not _same(p, r, c - 1) else (-ins if _same(p, r - 1, c - 1) else 0.0)
			var x1 := cl - ins if not _same(p, r, c + 1) else (cl + ins if _same(p, r - 1, c + 1) else cl)
			_fence(b, o + Vector2(x0, ins), o + Vector2(x1, ins), w, ink, k)
		if not _same(p, r + 1, c):
			var x0 := ins if not _same(p, r, c - 1) else (-ins if _same(p, r + 1, c - 1) else 0.0)
			var x1 := cl - ins if not _same(p, r, c + 1) else (cl + ins if _same(p, r + 1, c + 1) else cl)
			_fence(b, o + Vector2(x0, cl - ins), o + Vector2(x1, cl - ins), w, ink, k)
		if not _same(p, r, c - 1):
			var y0 := ins if not _same(p, r - 1, c) else (-ins if _same(p, r - 1, c - 1) else 0.0)
			var y1 := cl - ins if not _same(p, r + 1, c) else (cl + ins if _same(p, r + 1, c - 1) else cl)
			_fence(b, o + Vector2(ins, y0), o + Vector2(ins, y1), w, ink, k)
		if not _same(p, r, c + 1):
			var y0 := ins if not _same(p, r - 1, c) else (-ins if _same(p, r - 1, c + 1) else 0.0)
			var y1 := cl - ins if not _same(p, r + 1, c) else (cl + ins if _same(p, r + 1, c + 1) else cl)
			_fence(b, o + Vector2(cl - ins, y0), o + Vector2(cl - ins, y1), w, ink, k)
	# The tags' markers, over the fences' corners.
	var font: Font = CozyTheme.body(800)
	var px := int(roundf(TAG_SIZE * k))
	for p in state.plots.size():
		var box := _tag_box(p, now, font, px)
		var ink := _ink_of(p)
		var edge: Color = ink if ink != FENCE else Pal.WOOD_DEEP
		b.fan(Face.Builder.round_rect(box.position + Vector2(0.0, 1.5 * k), box.size, TAG_R * k),
			Color(Pal.TEXT, 0.18))
		b.fan(Face.Builder.round_rect(box.position, box.size, TAG_R * k), edge)
		var e := TAG_EDGE * k
		b.fan(Face.Builder.round_rect(box.position + Vector2.ONE * e, box.size - Vector2.ONE * 2.0 * e,
			maxf(TAG_R * k - e, 1.0)), TAG_FACE)
	return b.mesh()

## One run of fence from `a` to `z`: a faint rail and the pickets on it.
func _fence(b: Face.Builder, a: Vector2, z: Vector2, w: float, ink: Color, k: float) -> void:
	var length := a.distance_to(z)
	if length <= 0.5:
		return
	b.stroke(PackedVector2Array([a, z]), RAIL_W * k, Color(ink, RAIL_A), false, false)
	var dir := (z - a) / length
	var dash := PICKET * k
	var step := dash + PICKET_GAP * k
	# Pickets centred on the run, so two runs meeting at a corner both end
	# on a picket.
	var count := maxi(1, int(floor((length + PICKET_GAP * k) / step)))
	var lead := (length - (count * step - PICKET_GAP * k)) * 0.5
	for n in count:
		var s := lead + n * step
		b.stroke(PackedVector2Array([a + dir * s, a + dir * minf(s + dash, length)]), w, ink, false, true)

func _tag_text(p: int) -> String:
	return TAG_LOST if state.sums[p] < 0 else str(state.sums[p])

## The tag's marker, hopped or shaken as its plot's moment says.
func _tag_box(p: int, now: float, font: Font, px: int) -> Rect2:
	var k := _scale()
	var text := _tag_text(p)
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var size_ := Vector2(wide + 2.0 * TAG_PAD.x * k, font.get_height(px) * 0.82 + 2.0 * TAG_PAD.y * k)
	var at := _corner_of(int(state.plots[p][0])) + TAG_AT * k
	if not Motion.reduce:
		var hop := now - float(_tag_hop.get(p, -INF))
		if hop < TAG_HOP_TIME:
			at.y += TAG_HOP * k * sin(PI * hop / TAG_HOP_TIME)
		var shake := now - float(_tag_shake.get(p, -INF))
		if shake < Motion.SHIVER_TIME:
			at.x += Motion.shiver_offset(shake, Motion.SHIVER_PX * 2.0 * k)
	return Rect2(at, size_)

func _tag_mid(p: int) -> Vector2:
	var font: Font = CozyTheme.body(800)
	return _tag_box(p, _now(), font, int(roundf(TAG_SIZE * _scale()))).get_center()

func _draw_tags(now: float, pop: float, centre: Vector2) -> void:
	var font: Font = CozyTheme.body(800)
	var px := int(roundf(TAG_SIZE * _scale()))
	if px <= 0:
		return
	draw_set_transform(centre * (1.0 - pop), 0.0, Vector2.ONE * pop)
	var rise := font.get_ascent(px)
	for p in state.plots.size():
		var box := _tag_box(p, now, font, px)
		var ink: Color = Pal.TEXT if state.sums[p] >= 0 else Pal.TEXT_DIM
		var text := _tag_text(p)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		var base := Vector2(box.get_center().x - wide * 0.5,
			box.get_center().y + rise * 0.5 - font.get_descent(px) * 0.15)
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)
	draw_set_transform(Vector2.ZERO)

## Sudoku's pencil marks packed a little tighter and moved off the tag.
func _note_spot(n: int) -> Vector2:
	return super(n) * NOTE_PACK + NOTE_NUDGE * _cell
