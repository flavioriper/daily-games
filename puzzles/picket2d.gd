extends "res://puzzles/sudoku2d.gd"

## Picket Sums, flat: Sudoku's grid fenced into garden plots. Every row,
## column and region holds each number once, and each plot's numbers add up
## to the number on its tag, never one twice. Insane is a harder nine:
## bigger plots, every tag shown (Lost Tags retired 2026-10-26).
##
## **This is Sudoku's board** (puzzles/sudoku2d.gd), its tray, panels,
## washes, pad, pencil, waves, daisies, undo, hint and party, with the plots
## laid over it; the rules are puzzles/picket_state.gd and the days
## puzzles/picket_gen.gd (Hard and Insane from banks mined on the Mac). What
## is its own: the fences, the tags, and what a plot does when it comes
## right (its cells light leaf-gold one after another and its tag hops) or
## can no longer come true (its fence and tag turn rose and the tag shakes).
##
## **What makes it play (2026-10-26, the user: "nobody likes it")**: the
## plot card under the grid. Tap a square and it says the plot's tag, how
## many squares and how much are left, and every set of numbers that can
## still fill it (killer players' table, the sets struck as the plot's own
## numbers rule them out): "16 in 2" is 7 and 9, read off the card rather
## than worked out on paper. A plot come right keeps a soft leaf wash, so
## the garden greens as it is solved.
##
## **The fences are one mesh** with the tags' wooden markers in it, rebuilt
## only when what they show changes: the cell size, the selected plot, a
## plot's standing, or a tag hopping or shaking. The tags' numbers are
## strings over it, as the grid's numerals are.
## Spec: docs/superpowers/specs/2026-10-22-picket-design.md.

const PicketState = preload("res://puzzles/picket_state.gd")
const PicketWorld = preload("res://puzzles/picket_world.gd")
const ThemedPictures = preload("res://core/themed_pictures.gd")

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

## A plot come right keeps this wash, inset as Sudoku's washes are.
const GREEN_A := 0.17
## The plot card, at W 1080: its height at most, its margins from the tray
## and the pad, the gap under which it is not drawn; the text, the tag and
## the sets' chips.
const CARD_H := 132.0
const CARD_MARGIN := 10.0
const CARD_MIN := 70.0
const CARD_R := 18.0
const CARD_PAD := 18.0
const CARD_TEXT := 27
const CARD_TAG := 34
const CHIP_TEXT := 30
const CHIP_H := 46.0
const CHIP_PAD := 13.0
const CHIP_GAP := 9.0
const CARD_W := 1080.0
## Under this height the sets ride on the line's row, behind a smaller pad.
const CARD_TWO := 100.0
const CARD_PAD_ONE := 9.0

## The daily theme (2026-11-07). On a daily whose night pictures this phone
## holds (never New, never the tutorial's sheet), the day's thing lies in
## beads under the grid, the 24 first (about three beads a square), else the
## 12. A plot come right lets its squares' beads through, faint (BEAD_A)
## under the numbers, rippling out from its tag (REVEAL_STEP a bead, each
## swelling in over REVEAL_TIME), so the garden grows the picture plot by
## plot, its name kept for the win. On the win, once Sudoku's wave has
## passed (THEME_AT), a paper sheet settles over the grid (SHEET_TIME) and
## the picture pours onto it whole, bottom row first (POUR), with the theme
## cue and a sparkle; the card waits THEME_HOLD longer and names it. The
## deal never reads the theme. Pale beads are shaded so they read on paper.
const THEMED_SIZES := [24, 12]
const BEAD_A := 0.32
const REVEAL_STEP := 0.022
const REVEAL_TIME := 0.32
const THEME_AT := 0.85
const SHEET_TIME := 0.3
const POUR := 0.75
const THEME_HOLD := 0.6
const PAINT_PALE := 0.82
const PAINT_PALE_SHADE := 0.12

## Each plot's standing as last diffed (PicketState.plot_standing).
var _stand := PackedInt32Array()
var _tag_hop: Dictionary = {}     # plot -> at
var _tag_shake: Dictionary = {}   # plot -> at
var _fence_mesh: ArrayMesh
var _fence_shown: ArrayMesh
var _fence_key := ""
var _card_shown: ArrayMesh
## The day's thing ({id, name, rows}) on a themed daily, else {}; its beads
## as [row, col, cell, colour]; when each plot's beads began to ripple in;
## when the win's sheet began (INF none); the two bead meshes, their keys,
## and until when the play one must be built every frame.
var _theme: Dictionary = {}
var _theme_beads: Array = []
var _reveal_at: Dictionary = {}   # plot -> at
var _theme_at := INF
var _beads_mesh: ArrayMesh
var _beads_shown: ArrayMesh
var _beads_key := ""
var _beads_until := -INF
var _sheet_mesh: ArrayMesh
var _sheet_shown: ArrayMesh

## Sudoku's map, and a plot come right bumps as a finished row does
## (docs/agents/haptics.md).
const PICKET_HAPTICS := {"plot": Haptics.BUMP, "theme": Haptics.GOOD}

func puzzle_id() -> String: return "picket"
func title() -> String: return "Picket Sums"

## Sudoku's auto notes read only the lines, not the plots' sums, and its
## taught hint reads Sudoku's singles: Picket keeps its own bulb and no notes.
func notes_offered() -> bool:
	return false

func _teaches() -> bool:
	return false

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
	_theme = _night_picture()
	_theme_beads = _lay_beads()
	_reveal_at = {}
	_theme_at = INF
	_beads_key = ""
	_beads_until = -INF

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
		"source": "theme" if themed() else ("bank" if banked else "generator"), "kind": "grid",
		"theme": String(_theme.get("id", "")),
		"payload": {"n": n, "puzzle": Array(state.given), "plots": Array(state.cage_of),
			"sums": Array(state.sums)},
		"solution": {"grid": Array(state.sol)},
		"metrics": {"size": n, "clues": n * n - int(state.target), "blanks": int(state.target),
			"plots": state.plots.size(), "lost": state.lost_count(), "hints": state.hints_left},
		"view": {"w": n, "h": n, "puzzle": puzzle, "solution": answer, "regions": Array(state.cage_of)},
	}

func flat_win() -> Dictionary:
	if themed():
		return {"faces": [], "subtitle": tr("PK_WIN_THEME") % [String(_theme.name), tr("PK_WIN")]}
	return {"faces": [], "subtitle": tr("PK_WIN")}

func win_delay() -> float:
	return super() + (THEME_HOLD if themed() and not Motion.reduce else 0.0)

func share_glyphs() -> String:
	if state == null:
		return ""
	if state.band == 3:
		return "🌙" + (" " + tr("BN_FLAWLESS") if _flawless else "")
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
	_reveal_at = {}
	_beads_key = ""
	# a reopened themed day shows the picture the plots grew
	_theme_at = _now() - 10.0 if themed() else INF

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
	if themed() and not Motion.reduce:
		_reveal_at[p] = now
		_beads_until = maxf(_beads_until, now + REVEAL_TIME + REVEAL_STEP * 40.0)
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
	return super(now) or now < _beads_until or _live(_tag_hop, now, TAG_HOP_TIME) \
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
	if themed():
		_draw_beads(now, xf)
	if _fence_shown != null:
		draw_mesh(_fence_shown, null, xf)
	super(now, pop, centre)
	_draw_tags(now, pop, centre)
	if themed() and now >= _theme_at:
		_draw_sheet(now, xf)

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
	# A plot come right keeps a soft leaf wash: the garden greens as it is
	# solved. Off on the solved board, which has its own wave.
	if not done:
		var wi := WASH_INSET * k
		for i in Gen.CELLS:
			var p: int = state.cage_of[i]
			if p < _stand.size() and _stand[p] == 1:
				b.fan(Face.Builder.round_rect(_corner_of(i) + Vector2.ONE * wi, Vector2.ONE * (_cell - 2.0 * wi),
					WASH_R * k), Color(Pal.LEAF, GREEN_A))
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

## Sudoku's board, then the plot card under it.
func _draw() -> void:
	super()
	_draw_card()

## The plot card's rect: the gap between the tray and the pad, the tray's
## width; empty when there is no room, nothing is in play, or the board
## is a tutorial's.
func _card_rect() -> Rect2:
	if not _bled or state == null or _won or _cell <= 0.0 or is_done() or state.is_solved():
		return Rect2()
	var u := size.x / CARD_W
	var f := FRAME * _scale()
	var field: float = _cell * Gen.N
	var top := _grid.y + field + f + TRAY_LIP + CARD_MARGIN * u
	var bottom := size.y - _clear.y - CARD_MARGIN * u
	var h := minf(bottom - top, CARD_H * u)
	if h < CARD_MIN * u:
		return Rect2()
	return Rect2(_grid.x - f, (top + bottom - h) * 0.5, field + 2.0 * f, h)

## What the selected square's plot asks: its tag on the left, a line of
## what is left, and the sets of numbers it can still hold as chips (as
## many as fit, then "+n"). No square selected, a quiet line says so.
func _draw_card() -> void:
	var box := _card_rect()
	if box.size.y <= 0.0:
		return
	var u := size.x / CARD_W
	var b := Face.Builder.new()
	var r := CARD_R * u
	b.fan(Face.Builder.round_rect(box.position + Vector2(0.0, 2.0 * u), box.size, r), Color(Pal.TEXT, 0.1))
	b.fan(Face.Builder.round_rect(box.position, box.size, r), Color(FENCE, 0.5))
	var e := 1.5 * u
	b.fan(Face.Builder.round_rect(box.position + Vector2.ONE * e, box.size - Vector2.ONE * 2.0 * e, r - e), TAG_FACE)
	var body: Font = CozyTheme.body(700)
	var big: Font = CozyTheme.display(800)
	var ts := roundi(CARD_TEXT * u)
	var texts: Array = []   # [at, text, font, size, colour]
	# A card with room for two lines puts the sets under the line; a short
	# one (the nine, on a phone) keeps them all on one row after it.
	var two := box.size.y >= CARD_TWO * u
	var pad := (CARD_PAD if two else CARD_PAD_ONE) * u
	if _sel < 0:
		var line := tr("PK_CARD_TAP")
		var lw := body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		texts.append([box.get_center() + Vector2(-lw * 0.5, body.get_ascent(ts) * 0.36), line, body, ts, Pal.TEXT_DIM])
	else:
		var p: int = state.cage_of[_sel]
		var stand: int = _stand[p] if p < _stand.size() else 0
		# the tag, big, in the state's colour
		var gs := roundi(CARD_TAG * u)
		var tag := _tag_text(p)
		var tw := big.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
		var th := box.size.y - 2.0 * pad
		var tag_box := Rect2(box.position + Vector2(pad, pad), Vector2(maxf(th, tw + 24.0 * u), th))
		var fill := Pal.LEAF_DEEP if stand == 1 else (Pal.BAD if stand == -1 else FENCE_SEL)
		b.fan(Face.Builder.round_rect(tag_box.position, tag_box.size, TAG_R * 2.0 * u), fill)
		texts.append([tag_box.get_center() + Vector2(-tw * 0.5, big.get_ascent(gs) * 0.36), tag, big, gs, TAG_FACE])
		var x0 := tag_box.end.x + pad
		var right := box.end.x - pad
		var n: int = state.plots[p].size()
		var empty := 0
		for i in state.plots[p]:
			if state.grid[i] == 0:
				empty += 1
		var left: int = state.sums[p] - state.sum_now(p)
		var line: String
		var ink := Pal.TEXT
		if state.lost(p):
			line = tr("PK_TIP_LOST")
		elif stand == 1:
			line = tr("PK_CARD_RIGHT")
			ink = Pal.LEAF_DEEP
		elif stand == -1:
			ink = Pal.BAD
			line = tr("PK_CARD_OVER") % -left if left < 0 else (tr("PK_CARD_SHORT") % left if empty == 0 else tr("PK_CARD_TWICE"))
		elif two:
			line = (tr("PK_CARD_LEFT_ONE") if empty == 1 else tr("PK_CARD_LEFT_N")) % [empty, n, left]
		else:
			line = tr("PK_CARD_TO_GO") % left
		var line_y := tag_box.position.y + body.get_ascent(ts) * 0.9
		if not two:
			line_y = tag_box.get_center().y + body.get_ascent(ts) * 0.36
		texts.append([Vector2(x0, line_y), line, body, ts, ink])
		# the sets, as chips under the line, as many as fit
		if not state.lost(p) and stand == 0:
			var sets: Array = state.sets_left(p)
			var cs := roundi(CHIP_TEXT * u)
			var ch := minf(CHIP_H * u, th)
			var cy := tag_box.end.y - ch
			var x := x0
			if not two:
				cy = tag_box.get_center().y - ch * 0.5
				x = x0 + body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x + pad * 2.0
			var shown := 0
			if sets.is_empty():
				texts.append([Vector2(x, cy + ch * 0.5 + big.get_ascent(cs) * 0.36), tr("PK_CARD_NONE"), body, ts, Pal.BAD])
			for k in sets.size():
				var digits := PackedStringArray()
				for d in sets[k]:
					digits.append(str(d))
				var text := " ".join(digits)
				var w := big.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x + 2.0 * CHIP_PAD * u
				var more := "+%d" % (sets.size() - k)
				var mw := big.get_string_size(more, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
				var last := k == sets.size() - 1
				if x + w > right - (0.0 if last else mw + CHIP_GAP * u):
					texts.append([Vector2(x, cy + ch * 0.5 + big.get_ascent(cs) * 0.36), more, big, cs, Pal.TEXT_DIM])
					break
				b.fan(Face.Builder.round_rect(Vector2(x, cy), Vector2(w, ch), ch * 0.5), Color(FENCE, 0.18))
				texts.append([Vector2(x + CHIP_PAD * u, cy + ch * 0.5 + big.get_ascent(cs) * 0.36), text, big, cs, TAG_INK])
				x += w + CHIP_GAP * u
				shown += 1
	_card_shown = b.mesh()
	draw_mesh(_card_shown, null)
	for t in texts:
		draw_string(t[2], t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, t[3], t[4])

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

# --- the daily theme (2026-11-07) ---

func themed() -> bool:
	return not _theme.is_empty()

## The night's thing, the first size this phone holds; {} on New, on the
## tutorial's sheet, or with no night cached.
func _night_picture() -> Dictionary:
	if bank_step != 0 or daily_key == 0:
		return {}
	for side in THEMED_SIZES:
		var pic := ThemedPictures.picture(daily_key, int(side))
		if not pic.is_empty():
			return pic
	return {}

## Every bead the picture has, with the square under its middle and its
## colour (pale ones shaded to read on paper).
func _lay_beads() -> Array:
	var out: Array = []
	if not themed():
		return out
	var rows: Array = _theme.rows
	var n := rows.size()
	var letters: Dictionary = ThemedPictures.letters()
	for r in n:
		var row: String = rows[r]
		for c in row.length():
			if row[c] == ".":
				continue
			var bead = Pal.PG_BEADS.get(String(letters.get(row[c], "")))
			if bead == null:
				continue
			var face: Color = bead
			if face.get_luminance() > PAINT_PALE:
				face = face.darkened(PAINT_PALE_SHADE)
			var cell := int((r + 0.5) * Gen.N / n) * Gen.N + int((c + 0.5) * Gen.N / n)
			out.append([r, c, cell, face])
	return out

## One bead, `bead` wide at `at` (its top left), grown by `grow`, at `a`.
func _bead(b: Face.Builder, at: Vector2, bead: float, grow: float, face: Color, a: float) -> void:
	var sz := Vector2.ONE * bead * 0.9 * lerpf(0.3, 1.0, grow)
	var lo := at + (Vector2.ONE * bead - sz) * 0.5
	b.fan(Face.Builder.round_rect(lo + Vector2(0.0, bead * 0.06), sz, bead * 0.22), Color(face.darkened(0.3), a))
	b.fan(Face.Builder.round_rect(lo, sz, bead * 0.22), Color(face, a))

## The beads of the plots come right, faint under the fences and numbers;
## one mesh, built again only while a plot's beads ripple in or the grid
## moves.
func _draw_beads(now: float, xf: Transform2D) -> void:
	var key := "%s|%s|%s" % [_cell, _grid, _stand]
	if key != _beads_key or now <= _beads_until or _beads_mesh == null:
		_beads_key = key
		_beads_mesh = _bead_mesh(now)
	_beads_shown = _beads_mesh
	if _beads_shown != null:
		draw_mesh(_beads_shown, null, xf)

func _bead_mesh(now: float) -> ArrayMesh:
	var n: int = (_theme.rows as Array).size()
	var bead: float = _cell * Gen.N / float(n)
	var b := Face.Builder.new()
	for d in _theme_beads:
		var p: int = state.cage_of[int(d[2])]
		if p >= _stand.size() or _stand[p] != 1:
			continue
		var k := 1.0
		if _reveal_at.has(p) and not Motion.reduce:
			var tag := _corner_of(int(state.plots[p][0]))
			var at := _grid + Vector2(int(d[1]), int(d[0])) * bead
			k = clampf((now - float(_reveal_at[p]) - at.distance_to(tag) / bead * REVEAL_STEP) / REVEAL_TIME, 0.0, 1.0)
		if k <= 0.0:
			continue
		_bead(b, _grid + Vector2(int(d[1]), int(d[0])) * bead, bead, Motion.back_out(k), d[3], BEAD_A * minf(k * 2.0, 1.0))
	return b.mesh() if not b.verts.is_empty() else null

## The win's sheet: paper settling over the grid, then the picture poured
## onto it whole, bottom row first. Built every frame while it pours.
func _draw_sheet(now: float, xf: Transform2D) -> void:
	var since := now - _theme_at
	var settled := since > SHEET_TIME + POUR + REVEAL_TIME
	if not settled or _sheet_mesh == null:
		_sheet_mesh = _build_sheet(since)
	_sheet_shown = _sheet_mesh
	if _sheet_shown != null:
		draw_mesh(_sheet_shown, null, xf)

func _build_sheet(since: float) -> ArrayMesh:
	var n: int = (_theme.rows as Array).size()
	var field: float = _cell * Gen.N
	var bead := field / float(n)
	var k := _scale()
	var b := Face.Builder.new()
	var sheet := clampf(since / SHEET_TIME, 0.0, 1.0)
	var inset := WASH_INSET * k
	b.fan(Face.Builder.round_rect(_grid - Vector2.ONE * inset, Vector2.ONE * (field + 2.0 * inset), WASH_R * k * 2.0),
		Color(TAG_FACE, ease(sheet, 0.5) if not Motion.reduce else 1.0))
	for d in _theme_beads:
		var r: int = d[0]
		var g := 1.0
		if not Motion.reduce:
			var e := since - SHEET_TIME * 0.5 - float(n - 1 - r) / float(maxi(n - 1, 1)) * POUR
			g = clampf(e / REVEAL_TIME, 0.0, 1.0)
		if g <= 0.0:
			continue
		_bead(b, _grid + Vector2(int(d[1]), r) * bead, bead, Motion.back_out(g), d[3], minf(g * 2.0, 1.0))
	return b.mesh() if not b.verts.is_empty() else null

## The last number on a themed day: Sudoku's wave and party, then the sheet
## and the picture poured onto it as the theme cue rings. Under reduce
## motion the picture is simply there.
func _on_solved() -> void:
	super()
	if not themed():
		return
	var now := _now()
	if Motion.reduce:
		_theme_at = now
		fx.cue("theme")
		return
	_theme_at = now + THEME_AT
	_busy_for(THEME_AT + SHEET_TIME + POUR + REVEAL_TIME + 0.1)
	_after(THEME_AT + SHEET_TIME * 0.5, fx.cue.bind("theme"))
	_after(THEME_AT + SHEET_TIME * 0.5 + POUR + REVEAL_TIME * 0.5, func() -> void:
		fx.sparkle(_centre(), Pal.SUN))
