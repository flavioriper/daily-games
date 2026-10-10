extends "res://core/puzzle_base.gd"

## Lattice as a flat board: a garden lattice of wooden slats with a paper
## number tile on every crossing and between them, and in the gaps a dark
## knot that points at the tiles beside it and carries what they must add up
## to. The tiles are all there, scrambled; the one move is to swap two, by
## dragging one onto the other or by tapping one and then the other. A tile
## that lands on its own cell turns leaf green and stays. The rules are in
## puzzles/lattice_state.gd, which this only draws.
##
## How it is drawn. `_still` is the card, the slats and the sockets (a
## layout); `_knots` the knots, rebuilt when one is settled; the tiles are
## unit meshes under transforms baked with Face.FlatBuilder into `_rest` and,
## for the ones in the air, `_top`, each followed by its numerals. The pill
## and the toast are on a layer of their own.
##
## How it moves. The flat boards' vocabulary (core/motion.gd,
## docs/art/flat-motion.md) read as curves: tiles pop in along the diagonals,
## a held tile lifts, a refused one shivers, a line hops when it is whole.
## This board's own: the two tiles of a swap crossing in a shallow arc, and
## the turn to green as a tile lands at home.

const State = preload("res://puzzles/lattice_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Art = preload("res://ui/faces/lattice_art.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
## The swaps the out-of-moves card's video buys, once a board.
const MOVES_BONUS := 5

# --- the lattice ---
const PAD := 30.0
## The strip the pill stands in over the lattice.
const HUD_ROW := 76.0
const CARD_RADIUS := 26.0
const CARD_EDGE := 6.0
const DIGIT := 0.5
const KNOT_DIGIT := 0.3

# --- motion: what is this board's own ---
## Two tiles cross in a shallow arc, growing a little at the top of it.
const SWAP_TIME := 0.24
## A tile picked, put back, swapped, landed or taken back is never the same
## sound twice (docs/agents/sound.md, rule 2): all of them played at 1.0
## every time until 2026-10-10.
const TICK_VARY := Vector2(0.94, 1.06)
const SWAP_ARC := 0.16
const SWAP_GROW := 0.12
## A dragged tile goes back to its cell.
const BACK_TIME := 0.16
## The finger has to leave its tile by this much of a cell to be a drag.
const DRAG_SLOP := 0.2
const HOLD_SCALE := 1.12
const HOLD_RISE := 0.1
const LINE_STEP := 0.045
const WIN_WAIT := 1.3
const PARTY_EXTRA := 0.6
const STAMP_AT := 0.7
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.15
const STAMP_TILT := -0.22
const CARD_AFTER := 1.0
const CARD_AFTER_STILL := 0.3
const PILL_FONT := 30
const PILL_H := 48.0
## The count turns rose from here down.
const LOW := 3
## The toast: the board's own line for what just happened, on a dark pill
## over the foot of the card -- or over its head when the finger is working
## down there (Knight's and Horse Pen's toast, measure for measure).
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 40.0

const TIP_CYCLE := 10.0
const TIPS := ["LA_TIP_SWAP", "LA_TIP_LINE", "LA_TIP_KNOT", "LA_TIP_HOME"]

## What the phone does under each cue (docs/agents/haptics.md). A tile picked
## up is a tick and a swap a tap; a tile home is a small yes and two at once
## a firmer one; a whole line is the milestone; a swap that sent nothing home
## is only heard and faintly felt.
const HAPTICS := {
	"pick": Haptics.TICK,
	"drop": Haptics.TICK,
	"undo": Haptics.TICK,
	"swap": Haptics.TAP,
	"reset": Haptics.TAP,
	"miss": Haptics.ECHO,
	"home": Haptics.BUMP,
	"home2": Haptics.GOOD,
	"line": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"locked": Haptics.WARN,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

var state = State.new()
## Back to camp from the out-of-moves card; the host listens for it.
signal leave

var fx: Node2D
## Insane's swap counter: `max_moves` is 0 on a band that never runs out. Out
## of swaps unsolved is `out_of_hearts`, the name the host and the card
## already know. No band has hearts.
var hearts := 0
var max_hearts := 0
var moves_left := 0
var max_moves := 0
var out_of_hearts := false
var _heart_used := false
var _asleep := false
var _heart_card: Control

var _cell := 0.0
var _grid := Vector2.ZERO
var _card := Rect2()
## Bumped on every rebuild; a pending callback from the last board checks it.
var _gen := 0

# --- the meshes ---
var _still: ArrayMesh
var _knots: ArrayMesh
var _rest: ArrayMesh
var _top: ArrayMesh
var _units := {}
var _flat_cache: Dictionary = {}
var _live_dirty := true
var _knots_dirty := true
## The meshes the last _draw handed over (docs/agents/flat-screens.md: a
## canvas command holds a mesh by RID).
var _shown: Array = []
var _hud_layer: Control
var _hud_shown: ArrayMesh
var _seal_mesh: ArrayMesh
## What the last build left for the numerals: [cell, at, scale, alpha, home].
var _rest_ink: Array = []
var _top_ink: Array = []

# --- what the tiles are doing ---
## Where the tile on a cell is flying in from, since when and for how long.
var _fly_from := PackedVector2Array()
var _fly_at := PackedFloat32Array()
var _fly_time := PackedFloat32Array()
## The second the tile on a cell shows itself home (it flies in plain).
var _home_at := PackedFloat32Array()
var _hop_at := PackedFloat32Array()
var _shiver_at := PackedFloat32Array()
var _knot_at := PackedFloat32Array()
var _knot_was: Array = []
var _line_was: Array = []
## The tile under the finger, where the finger took it and where it is.
var _held := -1
var _held_grab := Vector2.ZERO
var _held_at := Vector2.ZERO
var _held_since := 0.0
var _dragged := false
## The tile a tap picked, waiting for its partner.
var _picked := -1
var _picked_since := 0.0

var _pill_bump := -INF
var _opened := -1.0e9
var _solved_at := -1.0
var _stamp_at := INF
var _anim_until := 0.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _toast := ""
var _toast_at := -100.0
var _toast_high := false
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
var _tip_idx := 0
var _tip_timer: Timer
var _final_swaps := 0
var _final_left := 0

func puzzle_id() -> String: return "lattice"
func title() -> String: return "Lattice"

func rules() -> String:
	var out := tr("LA_RULES") % state.n
	out += "\n\n" + tr("LA_RULES_KNOTS")
	if max_moves > 0:
		out += "\n\n" + tr("LA_RULES_COUNTED") % [max_moves, state.par]
	else:
		out += "\n\n" + tr("LA_RULES_FREE") % state.par
	return out

func _tips() -> Array:
	return ["LA_TIP_COUNT"] + TIPS if max_moves > 0 else TIPS

## The tutorial: each page is the board itself on a small hand-made lattice
## (ui/hud/lattice_tutorial_diagram.gd). Loaded, not preloaded: the page's
## board extends this script.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/lattice_tutorial_diagram.gd")
	var hints: int = State.hints_for(state.band)
	var steps := [
		[Diagram.Lesson.SWAP, "HTP_LA_SWAP", tr("HTP_LA_SWAP_BODY")],
		[Diagram.Lesson.LINES, "HTP_LA_LINES", tr("HTP_LA_LINES_BODY")],
		[Diagram.Lesson.KNOT, "HTP_LA_KNOT", tr("HTP_LA_KNOT_BODY")]]
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_LA_HINT",
			tr("HTP_LA_HINT_BODY_ONE") if hints == 1 else tr("HTP_LA_HINT_BODY_N") % hints])
	if max_moves > 0:
		steps.append([Diagram.Lesson.COUNT, "HTP_LA_COUNT", tr("HTP_LA_COUNT_BODY") % [max_moves, state.par, max_moves - state.par]])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Undo and the bulb up to Hard. Insane counts its swaps, so neither: a swap
## made is a swap spent. There is no Check on any band -- a tile says for
## itself whether it is home.
func capabilities() -> Array[String]:
	if state.band >= 3:
		return []
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_hud_layer = Control.new()
	_hud_layer.name = "Hud"
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.z_index = 1
	_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.draw.connect(_draw_hud)
	add_child(_hud_layer)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state.setup(rng, difficulty)
	_begin()

## The lattice as `state` has it, from the top: Insane's swaps, nothing in
## the air, the entrance.
func _begin() -> void:
	max_moves = state.moves_budget()
	_heart_used = false
	_solved_at = -1.0
	_stamp_at = INF
	_seal_mesh = null
	_deal()
	_layout()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

func _deal() -> void:
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_held = -1
	_picked = -1
	_toast = ""
	var count: int = state.count()
	_fly_from = PackedVector2Array()
	_fly_from.resize(count)
	_fly_at = _filled(count, -INF)
	_fly_time = _filled(count, 0.0)
	_home_at = _filled(count, -INF)
	_hop_at = _filled(count, -INF)
	_shiver_at = _filled(count, -INF)
	_knot_at = _filled(state.knots.size(), -INF)
	_remember()
	_knots_dirty = true
	_live_dirty = true
	if _hud_layer != null:
		_hud_layer.queue_redraw()

static func _filled(count: int, value: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	out.fill(value)
	return out

## Which knots and lines are settled now, to tell the ones a swap settles.
func _remember() -> void:
	_knot_was = []
	for k in state.knots.size():
		_knot_was.append(state.knot_done(k))
	_line_was = []
	for l in state.lines.size():
		_line_was.append(state.line_done(l))

# --- layout ---

## The lattice is the largest square the card holds under its strip, and the
## card is cut to it and centred in the slot (Tents' reason: the cell is
## capped by the width, so there is slack however it is cut).
func _layout() -> void:
	if state.n <= 0:
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var side: float = _cell * state.n
	var tall := minf(size.y, side + 2.0 * PAD + HUD_ROW)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - side * 0.5, _card.position.y + HUD_ROW + (tall - HUD_ROW - side) * 0.5)
	_flat_cache = {}
	_units = Art.units(_cell)
	_still = _build_still()
	_seal_mesh = null
	_knots_dirty = true
	_live_dirty = true
	_hud_layer.queue_redraw()
	queue_redraw()

func _cell_for(available: float) -> float:
	if state.n <= 0:
		return 0.0
	return minf((size.x - 2.0 * PAD) / state.n, (available - 2.0 * PAD - HUD_ROW) / state.n)

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.n + 2.0 * PAD + HUD_ROW)

func card_centred() -> bool:
	return true

## Control-local point over the centre of `cell`. The harnesses press these.
func cell_centre(cell: int) -> Vector2:
	return _square_centre(state.xy(cell))

func _square_centre(c: Vector2i) -> Vector2:
	return _grid + (Vector2(c) + Vector2(0.5, 0.5)) * _cell

## The same by row and column, the name the win harness knows.
func cell_to_local(r: int, c: int) -> Vector2:
	return _square_centre(Vector2i(c, r))

func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var p := (local - _grid) / _cell
	return state.at_xy(Vector2i(int(floor(p.x)), int(floor(p.y))))

func _field_px() -> Rect2:
	return Rect2(_grid, Vector2.ONE * _cell * state.n)

# --- the still drawings ---

## The card, the slats of the lattice (the columns under the rows) and a
## socket a cell.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(_card.position, _card.size, CARD_RADIUS), Pal.LINE)
	b.fan(Face.Builder.round_rect(_card.position, _card.size - Vector2(0.0, CARD_EDGE), CARD_RADIUS), Pal.SURFACE_HI)
	var side: float = _cell * state.n
	for across in [false, true]:
		for a in range(0, state.n, 2):
			var at := _grid + (Vector2(0.0, a * _cell) if across else Vector2(a * _cell, 0.0))
			Art.slat(b, at, Vector2(side, _cell) if across else Vector2(_cell, side), _cell)
	for i in state.count():
		Art.socket(b, cell_centre(i), _cell)
	return b.mesh()

## The knots: a dark bead with a point toward each tile it adds up, leaf
## green once those tiles are all home.
func _build_knots(now: float) -> ArrayMesh:
	if state.knots.is_empty():
		return null
	var b := Face.Builder.new()
	for k in state.knots.size():
		var knot: Dictionary = state.knots[k]
		var grown := 1.0
		if not Motion.reduce:
			grown = Motion.bump_scale(now - _knot_at[k], 0.2)
		Art.knot(b, _square_centre(knot.at), _cell * grown, String(knot.dirs), _knot_shows_done(k, now))
	return b.mesh()

## A knot is settled on the screen once its last tile has landed.
func _knot_shows_done(k: int, now: float) -> bool:
	for i: int in state.knots[k].cells:
		if not _shows_home(i, now):
			return false
	return true

func _shows_home(i: int, now: float) -> bool:
	return state.is_home(i) and now >= _home_at[i]

# --- the drawing ---

func _draw() -> void:
	if _cell <= 0.0 or _still == null:
		return
	var now := _now()
	var shown: Array = []
	# The lattice pops in wide once the chrome has slid in.
	var since := now - _opened - Motion.ENTER_DELAY
	var seen := 1.0 if Motion.reduce else Motion.appear_level(since)
	var grown := 1.0 if Motion.reduce else Motion.wide_pop_scale(since)
	var centre := _card.get_center()
	var xf := Transform2D(0.0, Vector2(grown, grown), 0.0, centre) * Transform2D(0.0, -centre)
	var busy := now < _anim_until
	if seen > 0.0:
		draw_mesh(_still, null, xf, Color(1.0, 1.0, 1.0, seen))
		shown.append(_still)
		if _knots_dirty or busy:
			_knots = _build_knots(now)
			_knots_dirty = false
		if _knots != null:
			draw_mesh(_knots, null, xf, Color(1.0, 1.0, 1.0, seen))
			shown.append(_knots)
		var font: Font = CozyTheme.display(700)
		var px := int(_cell * KNOT_DIGIT)
		var rise := (font.get_ascent(px) - font.get_descent(px)) * 0.5
		draw_set_transform_matrix(xf)
		for k in state.knots.size():
			var text := str(int(state.knots[k].sum))
			var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
			draw_string(font, _square_centre(state.knots[k].at) + Vector2(-wide * 0.5, rise), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Color(Pal.PAPER, seen))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if _live_dirty or busy or _rest == null:
		_build_tiles(now)
		_live_dirty = false
	if _rest != null:
		draw_mesh(_rest, null)
		shown.append(_rest)
	_draw_ink(_rest_ink)
	if _top != null:
		draw_mesh(_top, null)
		shown.append(_top)
	_draw_ink(_top_ink)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_shown = shown

## The numerals of the tiles a build just laid, each under its tile's own
## transform so it pops, flies and hops with it.
func _draw_ink(ink: Array) -> void:
	if ink.is_empty():
		return
	var font: Font = CozyTheme.display(700)
	var px := int(_cell * DIGIT)
	var rise := (font.get_ascent(px) - font.get_descent(px)) * 0.5
	for e: Array in ink:
		var text := str(int(state.cur[e[0]]))
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_set_transform(e[1], 0.0, e[2])
		draw_string(font, Vector2(-wide * 0.5, rise - _cell * Art.FACE_RISE), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
			Color(Pal.SURFACE if e[4] else Pal.TEXT, e[3]))
	draw_set_transform(Vector2.ZERO)

## Every tile where it is at `now`: the ones at rest into `_rest`, the ones
## in the air, picked or under the finger into `_top`, over them.
func _build_tiles(now: float) -> void:
	var rest := Face.FlatBuilder.new(_flat_cache)
	var top := Face.FlatBuilder.new(_flat_cache)
	_rest_ink = []
	_top_ink = []
	var busy := false
	var late: Array = []
	for i in state.count():
		if i == _held:
			continue
		var at := cell_centre(i)
		var sc := Vector2.ONE
		var alpha := 1.0
		var up := false
		var lift := 0.0
		if not Motion.reduce:
			var c: Vector2i = state.xy(i)
			var e := now - _opened - Motion.ENTER_DELAY - Motion.stagger(c.x + c.y, Motion.ENTER_STAGGER)
			if e < Motion.POP_IN:
				busy = true
				sc = Motion.pop_in_scale(e)
				alpha = Motion.appear_level(e)
				if alpha <= 0.0:
					continue
			var fly := now - _fly_at[i]
			if fly < _fly_time[i]:
				busy = true
				up = true
				var u := clampf(fly / _fly_time[i], 0.0, 1.0)
				var s := u * u * (3.0 - 2.0 * u)
				var arc := sin(PI * u)
				at = _fly_from[i].lerp(at, s)
				lift += arc * SWAP_ARC * _cell
				sc *= 1.0 + arc * SWAP_GROW
			var landed := now - _home_at[i]
			if state.is_home(i) and landed >= 0.0 and landed < Motion.BUMP_TIME:
				busy = true
				sc *= Motion.bump_scale(landed, 0.16)
			var hop := now - _hop_at[i]
			if hop >= 0.0 and hop < Motion.SOLVE_TIME:
				busy = true
				lift -= Motion.hop_lift(hop, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
			elif hop < 0.0 and hop > -2.0:
				busy = true
			var shiver := now - _shiver_at[i]
			if shiver >= 0.0 and shiver < Motion.SHIVER_TIME:
				busy = true
				at.x += Motion.shiver_offset(shiver, Motion.SHIVER_PX * 2.0)
		if i == _picked:
			up = true
			var k := 1.0 if Motion.reduce else Motion.back_out(clampf((now - _picked_since) / Motion.LIFT_TIME, 0.0, 1.0))
			busy = busy or now - _picked_since < Motion.LIFT_TIME
			sc *= lerpf(1.0, HOLD_SCALE, k)
			lift += HOLD_RISE * _cell * k
		if up:
			late.append([i, at, sc, alpha, lift])
		else:
			_tile(rest, _rest_ink, i, at, sc, alpha, lift, now, false)
	for e: Array in late:
		_tile(top, _top_ink, e[0], e[1], e[2], e[3], e[4], now, e[0] == _picked)
	if _held >= 0:
		var k := 1.0 if Motion.reduce else Motion.back_out(clampf((now - _held_since) / Motion.LIFT_TIME, 0.0, 1.0))
		busy = busy or now - _held_since < Motion.LIFT_TIME
		_tile(top, _top_ink, _held, _held_at, Vector2.ONE * lerpf(1.0, HOLD_SCALE, k), 1.0, HOLD_RISE * _cell * k, now, true)
	_rest = rest.mesh()
	_top = top.mesh() if not _top_ink.is_empty() else null
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## One tile of cell `i` at `at`, raised `lift` over its shadow; `ring` wears
## the picked tile's sun rim.
func _tile(fb, ink: Array, i: int, at: Vector2, sc: Vector2, alpha: float, lift: float, now: float, ring: bool) -> void:
	var home := _shows_home(i, now)
	if lift > 0.5:
		fb.append(_units.shade, Transform2D(0.0, sc, 0.0, at + Vector2(0.0, _cell * 0.06)), Color(1.0, 1.0, 1.0, alpha))
	var where := at - Vector2(0.0, lift)
	if ring:
		fb.append(_units.ring, Transform2D(0.0, sc, 0.0, where), Color(1.0, 1.0, 1.0, alpha))
	fb.append(_units.home if home else _units.free, Transform2D(0.0, sc, 0.0, where), Color(1.0, 1.0, 1.0, alpha))
	ink.append([i, where, sc, alpha, home])

# --- the pill and the toast ---

## One pill over the lattice: the swaps made against the fewest the deal can
## be done in, or on Insane the swaps left.
func _draw_hud() -> void:
	if _cell <= 0.0 or state.n <= 0:
		return
	var now := _now()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < 0.0 and not Motion.reduce:
		return
	var font: Font = CozyTheme.display(700)
	var text := pill_text()
	var ink := Pal.TEXT
	if max_moves > 0 and moves_left <= LOW:
		ink = Pal.BAD
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
	var box := Vector2(wide + 52.0, PILL_H)
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2.ONE * 2.0, box + Vector2.ONE * 4.0, box.y * 0.5 + 2.0), Pal.LINE)
	b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	_hud_shown = b.mesh()
	var alpha := 1.0 if Motion.reduce else Motion.appear_level(since)
	var k := 1.0 if Motion.reduce else Motion.bump_scale(now - _pill_bump, 0.12)
	_hud_layer.draw_set_transform(Vector2(size.x * 0.5, _card.position.y + HUD_ROW * 0.5 + 6.0), 0.0, Vector2(k, k))
	_hud_layer.draw_mesh(_hud_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var rise := (font.get_ascent(PILL_FONT) - font.get_descent(PILL_FONT)) * 0.5
	_hud_layer.draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(ink, alpha))
	_hud_layer.draw_set_transform(Vector2.ZERO)
	_draw_toast(now)

## What the pill reads.
func pill_text() -> String:
	if max_moves > 0:
		return tr("LA_LEFT_ONE") if moves_left == 1 else tr("LA_LEFT_N") % moves_left
	if state.swaps == 1:
		return tr("LA_PILL_ONE") % state.par
	return tr("LA_PILL_N") % [state.swaps, state.par]

func _bump_pill() -> void:
	_pill_bump = _now()
	_hud_layer.queue_redraw()

func _draw_toast(now: float) -> void:
	if _toast == "":
		return
	var since := now - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(_toast, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / font.get_height(TOAST_FONT))))
		text_w = minf(text_room, wrapped.x)
	var wide := minf(room, text_w + TOAST_PAD)
	var tall := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [_toast, int(wide), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-wide, -tall) * 0.5, Vector2(wide, tall), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh()
		_toast_mesh_for = key
	var field := _field_px()
	var mid := Vector2(size.x * 0.5, field.end.y - TOAST_MARGIN - tall * 0.5)
	if _toast_high:
		mid.y = field.position.y + TOAST_MARGIN + tall * 0.5
	_hud_layer.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha * 0.94))
	var top := mid.y - tall * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - wide * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		_hud_layer.draw_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		_hud_layer.draw_multiline_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_CENTER,
			wide - TOAST_PAD, TOAST_FONT, lines, Color(Pal.PAPER, alpha))

# --- input ---

## Touch and mouse, as every flat board takes them (touch is not mouse here:
## emulate_mouse_from_touch is off). A tile dragged onto another swaps with
## it; a tile tapped is picked, and the next tile tapped swaps with it.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _held >= 0:
		_held_at = event.position - _held_grab
		if not _dragged and event.position.distance_to(cell_centre(_held) + _held_grab) > DRAG_SLOP * _cell:
			_dragged = true
		_redraw()

func _press(at: Vector2) -> void:
	_held = -1
	var cell := _cell_at(at)
	if is_done() or out_of_hearts or cell < 0 or _now() < _fly_at[cell] + _fly_time[cell]:
		return
	if state.is_home(cell):
		# A tile at home is not picked up; the release says why.
		_held = -2 - cell
		return
	_held = cell
	_held_grab = at - cell_centre(cell)
	_held_at = cell_centre(cell)
	_held_since = _now()
	_dragged = false
	if cell != _picked:
		fx.cue("pick", randf_range(TICK_VARY.x, TICK_VARY.y))
	_busy_for(Motion.LIFT_TIME)
	_redraw()

func _release(at: Vector2) -> void:
	var held := _held
	_held = -1
	if held == -1 or is_done() or out_of_hearts:
		_redraw()
		return
	var over := _cell_at(at)
	if held < -1:
		if over == -2 - held:
			_refuse(over, "LA_REFUSE_HOME")
		return
	if not _dragged or over == held:
		_fly(held, _held_at, BACK_TIME)
		if _dragged:
			_picked = -1
			fx.cue("drop", randf_range(TICK_VARY.x, TICK_VARY.y))
		else:
			tap(held)
		_redraw()
		return
	_picked = -1
	if over < 0 or not _swap(held, over, _held_at):
		_fly(held, _held_at, BACK_TIME)
		if over < 0:
			fx.cue("drop", randf_range(TICK_VARY.x, TICK_VARY.y))
	_redraw()

## A tap on `cell`: picks it, puts it back, or swaps it with the tile picked
## before. The harnesses and the tutorial call this too.
func tap(cell: int) -> void:
	if is_done() or out_of_hearts or cell < 0:
		return
	if state.is_home(cell):
		_refuse(cell, "LA_REFUSE_HOME")
		return
	if _picked == cell:
		_picked = -1
		fx.cue("drop", randf_range(TICK_VARY.x, TICK_VARY.y))
	elif _picked < 0:
		_picked = cell
		_picked_since = _now()
		_busy_for(Motion.LIFT_TIME)
	else:
		var first := _picked
		_picked = -1
		_swap(first, cell, cell_centre(first))
	_redraw()

## Swaps the tiles on `a` and `b`, `a`'s leaving from `from` (where the finger
## let it go). False when the rules refuse it.
func _swap(a: int, b: int, from: Vector2) -> bool:
	# Insane counts its swaps, and one the count cannot pay for is not made.
	var cost := 1 if max_moves > 0 else 0
	if cost > moves_left and max_moves > 0:
		return false
	match state.swap(a, b):
		State.REFUSED_HOME:
			_refuse(b if state.is_home(b) else a, "LA_REFUSE_HOME")
			return false
		State.REFUSED_SAME:
			_refuse(b, "LA_REFUSE_SAME")
			return false
		State.REFUSED_SELF:
			return false
	var now := _now()
	_fly(b, from, SWAP_TIME)
	_fly(a, cell_centre(b), SWAP_TIME)
	var land := now + (0.0 if Motion.reduce else SWAP_TIME)
	_home_at[a] = land
	_home_at[b] = land
	fx.cue("swap", randf_range(TICK_VARY.x, TICK_VARY.y))
	_bump_pill()
	_after(land - now, _landed.bind(a, b))
	note_move()
	_spend(cost, land)
	return true

## The tile on `cell` flies in from `from`.
func _fly(cell: int, from: Vector2, time: float) -> void:
	_fly_from[cell] = from
	_fly_at[cell] = _now()
	_fly_time[cell] = 0.0 if Motion.reduce else time
	_busy_for(time + Motion.BUMP_TIME)

## The two tiles of a swap have landed: the ones now home say so, and so do
## the knots and the lines they settle.
func _landed(a: int, b: int, quiet := false) -> void:
	var sent := 0
	for i: int in [a, b]:
		if state.is_home(i):
			sent += 1
			fx.ring(cell_centre(i), _cell * 0.55, Pal.LEAF)
	if not quiet and not is_done():
		if sent == 0:
			fx.cue("miss", randf_range(TICK_VARY.x, TICK_VARY.y))
		else:
			fx.cue("home2" if sent == 2 else "home", randf_range(TICK_VARY.x, TICK_VARY.y))
	_settle(quiet)
	_knots_dirty = true
	_busy_for(Motion.BUMP_TIME)
	_redraw()

## Knots and lines newly whole: a knot bumps, a line hops end to end.
func _settle(quiet := false) -> void:
	var now := _now()
	for k in state.knots.size():
		var done: bool = state.knot_done(k)
		if done and not _knot_was[k]:
			_knot_at[k] = now
		_knot_was[k] = done
	var whole := false
	for l in state.lines.size():
		var done: bool = state.line_done(l)
		if done and not _line_was[l] and not is_done():
			whole = true
			var order := 0
			for i: int in state.lines[l]:
				_hop_at[i] = now + order * LINE_STEP
				order += 1
		_line_was[l] = done
	if whole:
		_busy_for(Motion.SOLVE_TIME + LINE_STEP * state.n)
		if not quiet:
			fx.cue("line")
			_tell(tr("LA_LINE"), Face.Expr.JOY)

func _refuse(cell: int, why: String) -> void:
	_tell(tr(why), Face.Expr.PUZZLED, cell)
	fx.cue("locked")
	if not Motion.reduce:
		_shiver_at[cell] = _now()
		_busy_for(Motion.SHIVER_TIME)
	_redraw()

# --- the sprout's line ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

## A line the player has to see now: said, and shown on the toast. `near` is
## the cell the finger is on, so the toast keeps out of its way.
func _tell(text: String, mood: int, near := -1) -> void:
	_say(text, mood)
	_toast = text
	_toast_at = _now()
	_toast_high = near >= 0 and state.xy(near).y >= state.n * 2 / 3
	_hud_layer.queue_redraw()

func _cycle_tip() -> void:
	if is_done() or out_of_hearts:
		return
	_tip_idx = (_tip_idx + 1) % _tips().size()
	_say(tr(_tips()[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return max_moves == 0 and not is_done() and not out_of_hearts and not state.history.is_empty()

func undo() -> bool:
	if not can_undo():
		return false
	var pair: Array = state.undo()
	if pair.is_empty():
		return false
	_picked = -1
	var now := _now()
	_fly(pair[0], cell_centre(pair[1]), SWAP_TIME)
	_fly(pair[1], cell_centre(pair[0]), SWAP_TIME)
	_home_at[pair[0]] = now
	_home_at[pair[1]] = now
	_remember()
	_knots_dirty = true
	_bump_pill()
	fx.cue("undo", randf_range(TICK_VARY.x, TICK_VARY.y))
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return State.hints_for(state.band) + hints_extra - hints_used

## Makes one swap of the answer, two tiles home at once when there is such a
## pair: a ring out of each cell, then the swap as the player would make it.
func hint() -> bool:
	if is_done() or out_of_hearts or hints_left() <= 0:
		return false
	var pair: Array = state.hint()
	if pair.is_empty():
		return false
	hints_used += 1
	_picked = -1
	_held = -1
	for i: int in pair:
		fx.ring(cell_centre(i), _cell * 0.5, Pal.SUN)
		fx.sparkle(cell_centre(i), Pal.LEAF)
	fx.cue("hint")
	_swap(pair[0], pair[1], cell_centre(pair[0]))
	_tell(tr("LA_HINTED"), Face.Expr.HAPPY, pair[1])
	_redraw()
	return true

## The deal as it was dealt, every tile popping back in along the diagonals,
## and on Insane every swap back. The hints a player spent are not refunded.
func reset_board() -> void:
	if is_done() or out_of_hearts:
		return
	_restart()
	_tell(tr("LA_RESET"), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")

func _restart() -> void:
	_gen += 1  # (a swap still in the air must not land on the fresh deal)
	state.reset()
	moves = 0
	_running = true
	_deal()
	_opened = _now() - Motion.ENTER_DELAY
	_busy_for(Motion.POP_IN + Motion.stagger(2 * state.n, Motion.ENTER_STAGGER) + 0.1)
	_bump_pill()
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

func completion_record() -> Dictionary:
	return {"swaps": state.swaps, "left": moves_left}

## A completed daily is rebuilt from its seed, so the lattice opens
## scrambled: every tile goes home and the swaps it took are put back.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	_tip_timer.stop()
	state.finish(int(completed_record.get("swaps", state.par)))
	_deal()
	moves_left = int(completed_record.get("left", 0))
	_opened = now - 10.0
	_solved_at = now - 10.0
	_final_swaps = state.swaps
	_final_left = moves_left
	_anim_until = 0.0
	_stamp_at = now - 10.0 if _stamped() else INF
	_seal_mesh = null
	_say(tr("LA_WIN"), Face.Expr.JOY)
	_hud_layer.queue_redraw()
	_redraw()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	out += "\n🔁 %d / %d" % [_final_swaps, state.par]
	if max_moves > 0:
		out += " " + "⭐".repeat(_final_left)
	return out

# --- the win ---

## Whether the day earned the seal: any Insane lattice, or one done in the
## fewest swaps there are.
func _stamped() -> bool:
	return state.band >= 3 or _final_swaps <= state.par

func flat_win() -> Dictionary:
	var sub := ""
	if max_moves > 0:
		if _final_left == 0:
			sub = tr("LA_WIN_SUB_LAST")
		else:
			sub = tr("LA_WIN_SUB_SPARE_ONE") if _final_left == 1 else tr("LA_WIN_SUB_SPARE_N") % _final_left
	elif _final_swaps <= state.par:
		sub = tr("LA_WIN_SUB_BEST") % _final_swaps
	else:
		sub = tr("LA_WIN_SUB") % [_final_swaps, state.par]
	return {"faces": [], "subtitle": sub}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

## The last two tiles land, the whole lattice hops along its diagonals, and a
## day done in the fewest swaps (or any Insane one) is stamped.
func _on_solved() -> void:
	var now := _now()
	_held = -1
	_picked = -1
	_tip_timer.stop()
	_toast = ""
	_solved_at = now
	_final_swaps = state.swaps
	_final_left = moves_left - (1 if max_moves > 0 else 0)
	var lag := 0.0 if Motion.reduce else SWAP_TIME + Motion.SOLVE_DELAY
	for i in state.count():
		var c: Vector2i = state.xy(i)
		_hop_at[i] = now + lag + Motion.stagger(c.x + c.y, Motion.SOLVE_STAGGER)
	_say(tr("LA_WIN"), Face.Expr.JOY)
	_after(lag, fx.cue.bind("solved"))
	_hud_layer.queue_redraw()
	_party(lag)
	_busy_for(lag + Motion.SOLVE_TIME + Motion.stagger(2 * state.n, Motion.SOLVE_STAGGER) + 0.3)
	_redraw()

func _party(lag: float) -> void:
	var now := _now()
	if _stamped():
		_stamp_at = now if Motion.reduce else now + lag + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
			_busy_for(lag + STAMP_AT + STAMP_DROP * 3.0)
	if Motion.reduce:
		return
	_after(lag + 0.15, func() -> void:
		var field := _field_px()
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell), 30, field.size.x * 0.8)
		fx.cue("party"))
	_after(lag + 0.6, func() -> void:
		var field := _field_px()
		fx.confetti(field.get_center(), 24, field.size.x * 0.6))

## The seal on the lattice's lower right, dropping in and settling.
func _draw_stamp(now: float, shown: Array) -> void:
	var field := _field_px()
	var rad := field.size.x * STAMP_R
	var insane: bool = state.band >= 3
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := field.end - Vector2(rad, rad) * 1.05
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	draw_set_transform_matrix(xf)
	draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var best: bool = _final_swaps <= state.par
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("LA_SEAL_BEST") if best else tr("LA_SEAL_INSANE"), 0.17, 0.36]]
	else:
		lines = [[tr("LA_SEAL_BEST"), 0.24, 0.12]]
	Seal.text(self, rad, lines)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# --- Insane's swaps ---

## Spends `cost` swaps. The last one spent with tiles still out is the board
## lost, once the swap has landed.
func _spend(cost: int, land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_hud_layer.queue_redraw()
	if moves_left > 0 or is_done():
		return
	out_of_hearts = true
	_running = false
	_after(maxf(0.0, land - _now()) + (0.0 if Motion.reduce else 0.5), _run_out)

func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_held = -1
	_picked = -1
	fx.cue("out_of_hearts")
	_tell(tr("LA_OUT"), Face.Expr.SLEEPY)
	_redraw()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

## The card, over the whole screen: on the host so it covers the chrome, or
## on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["LA_OUT_BODY", "LA_OUT_REST"], MOVES_BONUS,
		{"title": "LA_OUT_TITLE", "more": "LA_OUT_MORE"})
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same deal from the top, every swap back, the clock from
## zero.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	elapsed = 0.0
	_restart()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()

## A few more swaps (the card's video): once a board.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	moves_left = MOVES_BONUS
	_bump_pill()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	moved.emit()

func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- entrance ---

## The chrome is the host's; here the lattice pops in wide and the tiles pop
## onto it along the diagonals.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP + Motion.POP_IN + Motion.stagger(2 * state.n, Motion.ENTER_STAGGER))
	fx.cue("enter")

# --- odds and ends ---

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	if delay <= 0.0:
		what.call()
		return
	var gen := _gen
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0:
		return
	var now := _now()
	if now < _anim_until:
		queue_redraw()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.DROP_FADE + 0.1 or now - _pill_bump < Motion.BUMP_TIME + 0.1 \
			or (_toast != "" and now - _toast_at < TOAST_HOLD + 0.1):
		_hud_layer.queue_redraw()

func _redraw() -> void:
	_live_dirty = true
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
