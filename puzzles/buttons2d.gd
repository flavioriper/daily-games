extends "res://core/puzzle_base.gd"

## Button Box as a flat board: a sewing table laid with linen from edge to
## edge (`"bleed": true` in ui/registry.gd), a little picture of dyed cloth
## patches on it with a button of the wrong colour on every one, and a
## wooden tin at the foot. A move is two taps: the first picks a button and
## every one of its colour touching it, and they lift and draw together;
## the second says where they go -- a bare patch of their colour, where
## they are sewn, or the tin. Nothing lands by itself (the user,
## 2026-10-11). The rules are in puzzles/buttons_state.gd, which this only
## draws.
##
## How it is drawn. `_bg` is the linen (a layout); `_still` the stitched
## border and the patches; `_tin` the tin, rebuilt when it gains a place;
## the buttons are unit meshes under transforms baked with Face.FlatBuilder
## into `_rest` and, for the ones in the air, `_top`. The pill, the toast
## and the streak's bubble are on a layer of their own.
##
## How it moves. The flat boards' vocabulary (core/motion.gd,
## docs/art/flat-motion.md) read as curves. This board's own: a run leaving
## one button after another, each in an arc; the cross of thread as one
## lands; a whole colour hopping outward from its last button; the tin's new
## place.

const State = preload("res://puzzles/buttons_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Art = preload("res://ui/faces/button_art.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
## The taps the out-of-moves card's video buys, once a board.
const MOVES_BONUS := 5

# --- the table ---
const PAD := 34.0
const HUD_ROW := 76.0
const GAP := 26.0
const BORDER := 18.0
const TIN_ROW := 6
const TIN_STEP := 96.0
const TIN_PAD := 18.0
const CELL_MAX := 84.0

# --- motion: what is this board's own ---
## One button of a run leaves this long after the one before it.
const RUN_STEP := 0.04
const RUN_STEP_CAP := 0.5
const FLY_TIME := 0.3
const FLY_ARC := 0.55
const FLY_GROW := 0.18
## A button out of the tin leaves once its patch is bare.
const TIN_LAG := 0.16
const WHOLE_STEP := 0.03
const WIN_WAIT := 1.3
const PARTY_EXTRA := 0.6
const WIN_SLIDE := 0.5
const STAMP_AT := 0.7
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.15
const STAMP_TILT := -0.22
const CARD_AFTER := 1.0
const CARD_AFTER_STILL := 0.3
## A picked run draws this far toward the button that was tapped, stands
## this much bigger and higher, and bobs.
const PULL := 0.22
const HELD_SCALE := 1.1
const HELD_RISE := 0.14
const HELD_BOB := 0.03
const HINT_BEAT := 0.5
## A button landing is never the same tick twice (docs/agents/sound.md, rule
## 2), and a run climbs half a step a button, five at the most.
const TICK_VARY := Vector2(0.96, 1.04)
const RUN_CLIMB := 0.5
const RUN_CLIMB_MAX := 5.0
## The least time between two landing ticks of one kind.
const TICK_GAP := 0.075
## A run this long sewn at once is the board's small party.
const BIG_RUN := 5

const PILL_FONT := 30
const PILL_H := 48.0
const LOW := 3
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 24.0

## The streak (docs/agents/flat-screens.md, "The streak's bubble"): taps in a
## row that each sewed a button.
const COMBO_FROM := 3
const COMBO_STEPS := [0, 1, 2, 3, 4, 5]
const COMBO_DB := -3.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
const COMBO_HOLD := 1.2
const COMBO_FONT := 44

## What the phone does under each cue (docs/agents/haptics.md). A button
## lifted is a tick and one into the tin a tap; one sewn is a small yes and
## a long run a firmer one; a colour whole is the milestone.
const HAPTICS := {
	"lift": Haptics.TICK,
	"tin": Haptics.TAP,
	"sew": Haptics.BUMP,
	"run": Haptics.GOOD,
	"combo": Haptics.TICK,
	"whole": Haptics.GOOD,
	"open": Haptics.BUMP,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
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
## Insane's move counter: `max_moves` is 0 on a band that never runs out. Out
## of taps unsolved is `out_of_hearts`, the name the host and the card know.
var hearts := 0
var max_hearts := 0
var moves_left := 0
var max_moves := 0
var out_of_hearts := false
var _heart_used := false
var _asleep := false
var _heart_card: Control

## What the host's rows cover (a `bleed` board), and whether the win screen
## has them.
var _clear := Vector2.ZERO
var _won := false
var _cell := 0.0
var _grid := Vector2.ZERO
var _tin_rect := Rect2()
var _tin_step := TIN_STEP
## The places the tin is drawn with and the most a place is across: the
## tutorial's page has a short tin of one row.
var _tin_places := State.CASE_MAX
var _tin_step_max := TIN_STEP
## The picture before the win's slots moved, for its slide to the middle.
var _from_cell := 0.0
var _from_grid := Vector2.ZERO
var _slid_at := -INF
var _gen := 0

# --- the meshes ---
var _bg: ArrayMesh
var _still: ArrayMesh
var _tin: ArrayMesh
var _tin_units := {}
var _rest: ArrayMesh
var _top: ArrayMesh
var _units := {}
var _flat_cache: Dictionary = {}
var _live_dirty := true
var _shown: Array = []
var _hud_layer: Control
var _hud_shown: ArrayMesh
var _combo_shown: ArrayMesh
var _seal_mesh: ArrayMesh

# --- what the buttons are doing ---
## The second the button on a square (or in a place of the tin) lands: it is
## in the air until then, drawn by its flight.
var _arrive := PackedFloat32Array()
var _tin_arrive := PackedFloat32Array()
var _hop_at := PackedFloat32Array()
var _shiver_at := PackedFloat32Array()
## Buttons in the air: {c, from, to, at, time, sewn}.
var _flights: Array = []
## The pick: the squares of a run off the cloth, or the places of the tin's
## own of one colour; its colour (-1: nothing picked), since when, and the
## point it draws toward.
var _held_cells := PackedInt32Array()
var _held_places := PackedInt32Array()
var _held_c := -1
var _held_at := 0.0
var _held_anchor := Vector2.ZERO
## What the finger went down on: a square, or TIN_HIT and a place.
var _pressed_tin := -2
var _open_at := -INF
var _open_place := -1
var _pressed := -1
var _kept_told := false

var _streak := 0
var _combo_n := 0
var _combo_cell := 0
var _combo_at := -INF
var _combo_out_at := -INF
var _combo_popped := false

var _pill_bump := -INF
var _opened := -1.0e9
## -INF until the day is won (a restored day's is in the past, and early in
## a run that is under zero).
var _solved_at := -INF
var _stamp_at := INF
var _anim_until := 0.0
var _toast := ""
var _toast_at := -100.0
var _toast_high := false
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
var _final_taps := 0
var _final_left := 0

func puzzle_id() -> String: return "buttons"
func title() -> String: return "Button Box"

func rules() -> String:
	var out := tr("BB_RULES")
	if state.band <= State.CORNERS_TO:
		out += " " + tr("BB_RULES_CORNERS")
	out += "\n\n" + tr("BB_RULES_TIN") % (state.capacity() - state.colours_done())
	if max_moves > 0:
		out += "\n\n" + tr("RULES_MOVES_SEQ") % max_moves
	return out

## The tutorial: each page is the board itself on a small hand-made cloth
## (ui/hud/buttons_tutorial_diagram.gd). Loaded, not preloaded: the page's
## board extends this script.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/buttons_tutorial_diagram.gd")
	var hints: int = State.hints_for(state.band)
	var steps := [
		[Diagram.Lesson.LIFT, "HTP_BB_LIFT", tr("HTP_BB_LIFT_BODY")],
		[Diagram.Lesson.SEW, "HTP_BB_SEW", tr("HTP_BB_SEW_BODY")],
		[Diagram.Lesson.TIN, "HTP_BB_TIN", tr("HTP_BB_TIN_BODY")]]
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_BB_HINT",
			tr("HTP_BB_HINT_BODY_ONE") if hints == 1 else tr("HTP_BB_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves, true))
	return pages

## Undo and the bulb up to Hard. Insane counts its taps, so neither. There
## is no Check on any band: a button sewn on says so itself.
func capabilities() -> Array[String]:
	if state.band >= State.COUNTED_FROM:
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
	_hud_layer.z_index = 3
	_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.draw.connect(_draw_hud)
	add_child(_hud_layer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state.setup(rng, difficulty)
	_begin()

## The cloth as `state` has it, from the top.
func _begin() -> void:
	max_moves = state.moves_budget()
	_heart_used = false
	_won = false
	_solved_at = -INF
	_slid_at = -INF
	_stamp_at = INF
	_seal_mesh = null
	_deal()
	_layout()
	_enter()

func _deal() -> void:
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_pressed = -1
	_toast = ""
	_flights = []
	_unhold()
	_streak = 0
	_combo_n = 0
	_open_place = -1
	_kept_told = false
	var n: int = state.slot.size()
	_arrive = _filled(n, -INF)
	_hop_at = _filled(n, -INF)
	_shiver_at = _filled(n, -INF)
	_tin_arrive = _filled(State.CASE_MAX, -INF)
	_tin = null
	_live_dirty = true
	if _hud_layer != null:
		_hud_layer.queue_redraw()

static func _filled(n: int, value: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(value)
	return out

# --- layout ---

## The host's rows over this board (ui/flat/flat_host.gd, a `bleed` board):
## what they cover at the top and the foot, and on the win the span the win
## screen leaves, which the picture slides to the middle of.
func set_clear(top: float, bottom: float, won := false) -> void:
	_clear = Vector2(top, bottom)
	if won and not _won and _cell > 0.0:
		_from_cell = _cell
		_from_grid = _grid
		_slid_at = _now() if is_inside_tree() and _solved_at > _now() - 5.0 else -INF
	_won = won
	_layout()

## The picture as big as the room between the pill and the tin allows, in
## the middle of it, and the tin at the foot.
func _layout() -> void:
	if state.w <= 0 or size.x <= 0.0:
		return
	var top := _clear.x
	var foot := size.y - _clear.y
	_tin_step = minf(_tin_step_max, (size.x - 2.0 * PAD - 2.0 * TIN_PAD) / TIN_ROW)
	var tin_rows := ceili(float(_tin_places) / TIN_ROW)
	var tin_size := Vector2(TIN_ROW * _tin_step + 2.0 * TIN_PAD, tin_rows * _tin_step + 2.0 * TIN_PAD)
	_tin_rect = Rect2(Vector2((size.x - tin_size.x) * 0.5, foot - tin_size.y - GAP * 0.5), tin_size)
	var head := top if _won else top + HUD_ROW
	var floor_y := foot if _won else _tin_rect.position.y - GAP
	var room := Vector2(size.x - 2.0 * (PAD + BORDER), floor_y - head - 2.0 * BORDER)
	_cell = minf(CELL_MAX, minf(room.x / state.w, room.y / state.h))
	if _cell <= 0.0:
		return
	var pic := Vector2(state.w, state.h) * _cell
	_grid = Vector2((size.x - pic.x) * 0.5, head + BORDER + (room.y - pic.y) * 0.5)
	_flat_cache = {}
	var named: Array = []
	for c: String in state.colours:
		named.append(c)
	_units = Art.units(_cell, named)
	_tin_units = Art.units(_tin_step * 0.86, named)
	var b := Face.Builder.new()
	Art.linen(b, size)
	_bg = b.mesh()
	_still = _build_still()
	_tin = null
	_seal_mesh = null
	_live_dirty = true
	_hud_layer.queue_redraw()
	queue_redraw()

## Control-local point over the middle of square `i`. The harnesses press
## these.
func cell_centre(i: int) -> Vector2:
	return _grid + (Vector2(state.xy(i)) + Vector2(0.5, 0.5)) * _cell

func cell_to_local(r: int, c: int) -> Vector2:
	return _grid + (Vector2(c, r) + Vector2(0.5, 0.5)) * _cell

func tin_centre(place: int) -> Vector2:
	return Art.tin_place(_tin_rect, place, TIN_ROW, _tin_step, _tin_places)

func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var p := (local - _grid) / _cell
	return state.at_xy(Vector2i(int(floor(p.x)), int(floor(p.y))))

func _field_px() -> Rect2:
	return Rect2(_grid, Vector2(state.w, state.h) * _cell)

## The stitched border and a dyed patch a square.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var field := _field_px().grow(BORDER * 0.6)
	Art.stitches(b, field, 22.0, Color(Pal.PLAQUE, 0.55))
	for i in state.slot.size():
		if state.slot[i] >= 0:
			Art.patch(b, cell_centre(i), _cell, Art.colour(state.colours[state.slot[i]]))
	return b.mesh()

func _build_tin() -> ArrayMesh:
	var b := Face.Builder.new()
	Art.tin(b, _tin_rect, _tin_places, state.capacity(), TIN_ROW, _tin_step)
	return b.mesh()

# --- the drawing ---

## Where the picture's own pixels are on the screen now: itself, but for the
## win's slide from where it was played to the middle of what is left.
func _slide_xf(now: float) -> Transform2D:
	var e := now - _slid_at
	if Motion.reduce or e >= WIN_SLIDE or _from_cell <= 0.0 or _cell <= 0.0:
		return Transform2D.IDENTITY
	var u := clampf(e / WIN_SLIDE, 0.0, 1.0)
	var s := u * u * (3.0 - 2.0 * u)
	var k := lerpf(_from_cell / _cell, 1.0, s)
	var at := _from_grid.lerp(_grid, s)
	return Transform2D(0.0, at) * Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO) * Transform2D(0.0, -_grid)

func _draw() -> void:
	if _cell <= 0.0 or _bg == null:
		return
	var now := _now()
	var shown: Array = [_bg]
	draw_mesh(_bg, null)
	var since := now - _opened - Motion.ENTER_DELAY
	var seen := 1.0 if Motion.reduce else Motion.appear_level(since)
	var grown := 1.0 if Motion.reduce else Motion.wide_pop_scale(since)
	var centre := _field_px().get_center()
	var slide := _slide_xf(now)
	var xf := slide * Transform2D(0.0, Vector2(grown, grown), 0.0, centre) * Transform2D(0.0, -centre)
	var busy := now < _anim_until
	if seen > 0.0:
		draw_mesh(_still, null, xf, Color(1.0, 1.0, 1.0, seen))
		shown.append(_still)
		var tin_seen := seen
		if _solved_at > -INF:
			tin_seen = 0.0 if Motion.reduce else clampf(1.0 - (now - _solved_at - WIN_WAIT * 0.4) / 0.3, 0.0, 1.0)
			if _won and _slid_at == -INF:
				tin_seen = 0.0
		if tin_seen > 0.0:
			if _tin == null:
				_tin = _build_tin()
			draw_mesh(_tin, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, tin_seen))
			shown.append(_tin)
	if _live_dirty or busy or _rest == null:
		_build_buttons(now)
		_live_dirty = false
	if _rest != null:
		draw_mesh(_rest, null, slide)
		shown.append(_rest)
	if _top != null:
		draw_mesh(_top, null, slide)
		shown.append(_top)
	if now >= _stamp_at:
		_draw_stamp(now, shown, slide)
	_shown = shown

## Every button where it is at `now`: the ones at rest into `_rest`, the
## ones in the air into `_top`, over them.
func _build_buttons(now: float) -> void:
	var rest := Face.FlatBuilder.new(_flat_cache)
	var top := Face.FlatBuilder.new(_flat_cache)
	var busy := false
	var holding := _held_c >= 0
	var held := {}
	if holding:
		busy = true
		# where the pick may go: a ring on every bare patch of its colour,
		# and on the tin's free places for a run off the cloth
		# (Easy and Medium only: Hard and Insane never show where to place)
		var pulse := 1.0 + 0.07 * sin((now - _held_at) * 7.0)
		var guided: bool = state.guides()
		if guided:
			for i in state.bare_of(_held_c):
				rest.append(_units.ring, Transform2D(0.0, Vector2(pulse, pulse) * 0.82, 0.0, cell_centre(i)))
		if guided and not _held_cells.is_empty():
			var free: int = state.capacity() - state.in_tin()
			for p in _tin_places:
				if free > 0 and p < state.capacity() and state.tin[p] < 0:
					free -= 1
					rest.append(_tin_units.ring, Transform2D(0.0, Vector2(pulse, pulse) * 0.8, 0.0, tin_centre(p)))
		for i in _held_cells:
			held[i] = true
	for i in state.slot.size():
		var c: int = state.cur[i]
		if state.slot[i] < 0 or c < 0 or now < _arrive[i] or held.has(i):
			continue
		var at := cell_centre(i)
		var sc := Vector2.ONE
		var lift := 0.0
		var home: bool = state.is_home(i)
		if not Motion.reduce:
			var p: Vector2i = state.xy(i)
			var e := now - _opened - Motion.ENTER_DELAY - Motion.stagger(p.x + p.y, Motion.ENTER_STAGGER)
			if e < Motion.POP_IN:
				busy = true
				if e <= 0.0:
					continue
				sc = Motion.pop_in_scale(e)
			var landed := now - _arrive[i]
			if landed < Motion.BUMP_TIME:
				busy = true
				sc *= Motion.bump_scale(landed, 0.2 if home else 0.1)
			var hop := now - _hop_at[i]
			if hop >= 0.0 and hop < Motion.SOLVE_TIME:
				busy = true
				lift -= Motion.hop_lift(hop, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
			elif hop < 0.0 and hop > -3.0:
				busy = true
			var shiver := now - _shiver_at[i]
			if shiver >= 0.0 and shiver < Motion.SHIVER_TIME:
				busy = true
				at.x += Motion.shiver_offset(shiver, Motion.SHIVER_PX * 2.0)
		if not home or lift > 0.5:
			rest.append(_units.shade, Transform2D(0.0, sc, 0.0, at))
		rest.append(_units.sewn[c] if home else _units.loose[c], Transform2D(0.0, sc, 0.0, at - Vector2(0.0, lift)))
	if _solved_at == -INF or now - _solved_at < WIN_WAIT:
		for p in _tin_places:
			var c: int = state.tin[p]
			if c < 0 or now < _tin_arrive[p] or (holding and _held_places.has(p)):
				continue
			var k := 1.0
			if not Motion.reduce and now - _tin_arrive[p] < Motion.BUMP_TIME:
				busy = true
				k = Motion.bump_scale(now - _tin_arrive[p], 0.12)
			rest.append(_tin_units.loose[c], Transform2D(0.0, Vector2(k, k), 0.0, tin_centre(p)))
	if not Motion.reduce and now - _open_at < Motion.BUMP_TIME * 2.0 and _open_place >= 0:
		busy = true
		var k := Motion.bump_scale(now - _open_at, 0.3, Motion.BUMP_TIME * 2.0)
		rest.append(_tin_units.ring, Transform2D(0.0, Vector2(k, k) * 0.8, 0.0, tin_centre(_open_place)))
	var flying := holding
	if holding:
		var k := Vector2.ONE * _held_grow(now)
		for i in _held_cells:
			var at := _held_pos(i, false, now)
			top.append(_units.shade, Transform2D(0.0, k, 0.0, cell_centre(i).lerp(at, 0.8) + Vector2(0.0, _cell * HELD_RISE)))
			top.append(_units.loose[_held_c], Transform2D(0.0, k, 0.0, at))
		for p in _held_places:
			top.append(_tin_units.loose[_held_c], Transform2D(0.0, k, 0.0, _held_pos(p, true, now)))
	var keep: Array = []
	for f: Dictionary in _flights:
		var e: float = now - float(f.at)
		if e >= float(f.time):
			continue
		keep.append(f)
		busy = true
		flying = true
		var u := clampf(e / float(f.time), 0.0, 1.0)
		var s := u * u * (3.0 - 2.0 * u)
		var arc := sin(PI * u)
		var from: Vector2 = f.from
		var at := from.lerp(f.to, s)
		var grow := lerpf(float(f.k0), float(f.k1), s) * (1.0 + arc * FLY_GROW)
		var lift := arc * FLY_ARC * _cell
		top.append(_units.shade, Transform2D(0.0, Vector2(grow, grow), 0.0, at + Vector2(0.0, lift * 0.2)))
		top.append(_units.loose[int(f.c)], Transform2D(0.0, Vector2(grow, grow), 0.0, at - Vector2(0.0, lift)))
	_flights = keep
	_rest = rest.mesh()
	_top = top.mesh() if flying else null
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

# --- the pill, the toast and the streak ---

func _draw_hud() -> void:
	if _cell <= 0.0 or state.w <= 0:
		return
	var now := _now()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < 0.0 and not Motion.reduce:
		return
	if not _won:
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
		_hud_layer.draw_set_transform(Vector2(size.x * 0.5, _clear.x + HUD_ROW * 0.5), 0.0, Vector2(k, k))
		_hud_layer.draw_mesh(_hud_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
		var rise := (font.get_ascent(PILL_FONT) - font.get_descent(PILL_FONT)) * 0.5
		_hud_layer.draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(ink, alpha))
		_hud_layer.draw_set_transform(Vector2.ZERO)
	_draw_combo(now)
	_draw_toast(now)

## What the pill reads: the buttons sewn of all there are, and on Insane the
## taps left beside it.
func pill_text() -> String:
	var sewn := tr("BB_PILL") % [state.homes(), state.count()]
	if max_moves > 0:
		return (tr("MOVES_LEFT_ONE") if moves_left == 1 else tr("MOVES_LEFT_N") % moves_left) + " · " + sewn
	return sewn

func _bump_pill() -> void:
	_pill_bump = _now()
	_hud_layer.queue_redraw()

func _draw_combo(now: float) -> void:
	if _combo_n < COMBO_FROM:
		return
	var k := 1.0
	var alpha := 1.0
	if _combo_out_at == -INF and now - _combo_at >= COMBO_HOLD:
		_combo_out_at = now
	if _combo_out_at > -INF:
		var u := (now - _combo_out_at) / COMBO_DEFLATE
		if u >= 1.0 or Motion.reduce:
			_combo_n = 0
			return
		k = 1.0 - 0.75 * u * u
		alpha = 1.0 - u
	elif not Motion.reduce:
		var e := now - _combo_at
		k = Motion.pop_in_scale(e).x if _combo_popped else Motion.bump_scale(e)
	if k <= 0.01:
		return
	var font: Font = CozyTheme.display(700)
	var text := "x%d" % _combo_n
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT).x
	var box := Vector2(tw + 30.0, COMBO_FONT + 16.0)
	var tail := cell_centre(_combo_cell) + Vector2(_cell * 0.25, -_cell * 0.4)
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.75)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var b := Face.Builder.new()
	var tip := tail - centre
	var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
	b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
	b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
	b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
	b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	_combo_shown = b.mesh()
	_hud_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_hud_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_hud_layer.draw_string(font, Vector2(-tw * 0.5, (font.get_ascent(COMBO_FONT) - font.get_descent(COMBO_FONT)) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_hud_layer.draw_set_transform(Vector2.ZERO)

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

## A line the player has to see now, on the toast. `near` is the square the
## finger is on, so the toast keeps out of its way.
func _tell(text: String, near := -1) -> void:
	_toast = text
	_toast_at = _now()
	_toast_high = near >= 0 and state.xy(near).y >= state.h * 2 / 3
	_hud_layer.queue_redraw()

# --- the pick ---

func holding() -> bool:
	return _held_c >= 0

func _unhold() -> void:
	_held_cells = PackedInt32Array()
	_held_places = PackedInt32Array()
	_held_c = -1

## How far a pick has come up: 0 as it is tapped, 1 once it is lifted.
func _held_k(now: float) -> float:
	if Motion.reduce:
		return 1.0
	return Motion.back_out(clampf((now - _held_at) / (Motion.LIFT_TIME * 1.6), 0.0, 1.0))

func _held_grow(now: float) -> float:
	return lerpf(1.0, HELD_SCALE, _held_k(now))

## Where a picked button is drawn: drawn toward the tapped one, lifted, and
## bobbing a little, each a beat behind its neighbour.
func _held_pos(i: int, in_tin: bool, now: float) -> Vector2:
	var k := _held_k(now)
	var home := tin_centre(i) if in_tin else cell_centre(i)
	var unit := _tin_step if in_tin else _cell
	var at := home if in_tin else home.lerp(_held_anchor, PULL * k)
	var bob := 0.0 if Motion.reduce else sin((now - _held_at) * 5.0 + i * 0.9) * HELD_BOB * unit
	return at - Vector2(0.0, (HELD_RISE * unit + bob) * k)

func _pick(cells: PackedInt32Array, places: PackedInt32Array, c: int, anchor: Vector2) -> void:
	_held_cells = cells
	_held_places = places
	_held_c = c
	_held_at = _now()
	_held_anchor = anchor
	fx.cue("lift", randf_range(TICK_VARY.x, TICK_VARY.y))
	_redraw()

## Puts the pick down where it was.
func _drop() -> void:
	if not holding():
		return
	_unhold()
	fx.cue("lift", 0.84 * randf_range(TICK_VARY.x, TICK_VARY.y))
	_redraw()

# --- input ---

const TIN_HIT := -3

## Touch and mouse, as every flat board takes them (touch is not mouse here:
## emulate_mouse_from_touch is off). A tap is a press and a release on one
## thing: a square of the cloth, or the tin.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		var over := _cell_at(event.position)
		var over_tin := _tin_at(event.position)
		if event.pressed:
			_pressed = over
			_pressed_tin = over_tin
		else:
			if over >= 0 and over == _pressed:
				tap(over)
			elif over < 0 and over_tin != -2 and _pressed_tin != -2:
				tap_tin(over_tin)
			elif over < 0 and _pressed < 0 and holding():
				_drop()
			_pressed = -1
			_pressed_tin = -2

## The tin under `local`: a place, -1 for its wood between places, -2 off it.
func _tin_at(local: Vector2) -> int:
	if _won or not _tin_rect.grow(_tin_step * 0.2).has_point(local):
		return -2
	for p in _tin_places:
		if tin_centre(p).distance_to(local) < _tin_step * 0.5:
			return p
	return -1

func _can_play() -> bool:
	if is_done() or out_of_hearts or _solved_at > -INF:
		return false
	return max_moves == 0 or moves_left > 0

## A tap on square `i`: picks the run of the button there, puts a pick back
## down, or -- on a bare patch -- sews the pick onto it. The harnesses and
## the tutorial call this too.
func tap(i: int) -> void:
	if not _can_play() or i < 0 or _now() < _arrive[i]:
		return
	if state.cur[i] < 0:
		if not holding():
			_refuse(i, "BB_REFUSE_PICK")
			return
		var places := _held_places
		var starts := {}
		var now := _now()
		for g in _held_cells:
			starts[g] = _held_pos(g, false, now)
		for p in places:
			starts[-1 - p] = _held_pos(p, true, now)
		var res: Dictionary = state.sew(_held_cells, places, i)
		if int(res.why) != State.OK:
			_refuse(i, "BB_REFUSE_WRONG")
			return
		# The ones no patch was left for stay picked, for the next bare patch
		# (the user, 2026-10-11: "it should keep selected until end or use
		# click on it again, so user can select a color and click into
		# different places of board to keep placing"). A pick that outlives
		# its move must never keep the tin's own out of reach: `tap_tin`.
		var kept: PackedInt32Array = res.kept
		if kept.is_empty():
			_unhold()
		elif _held_cells.is_empty():
			_held_places = kept
		else:
			_held_cells = kept
		_play(res, i, starts)
		return
	match state.judge(i):
		State.REFUSED_HOME:
			_refuse(i, "BB_REFUSE_HOME")
		State.OK:
			if _held_cells.has(i):
				_drop()
			else:
				_pick(state.run_of(i), PackedInt32Array(), state.cur[i], cell_centre(i))

## A tap on the tin (`place` -1: its wood): a run picked off the cloth goes
## in; with nothing picked, a button there picks every one of its colour in
## the tin.
func tap_tin(place := -1) -> void:
	if not _can_play():
		return
	# A tap on a button in the tin is always a pick, whatever is held: the
	# tin's own are the way on when it is full, and a run still picked off
	# the cloth once kept them out of reach ("something is causing the game
	# to get stuck"). A run off the cloth goes in on a tap on a free place
	# or on the tin's wood.
	var on_button: bool = place >= 0 and state.tin[place] >= 0
	if not _held_cells.is_empty() and not on_button:
		var starts := {}
		var now := _now()
		for g in _held_cells:
			starts[g] = _held_pos(g, false, now)
		var res: Dictionary = state.stow(_held_cells)
		if int(res.why) != State.OK:
			_tell(tr("BB_REFUSE_FULL"))
			fx.cue("locked")
			return
		# what the tin had no room for stays picked
		var kept: PackedInt32Array = res.kept
		if kept.is_empty():
			_unhold()
		else:
			_held_cells = kept
		_play(res, -1, starts)
		if kept.size() > 0:
			_tell(tr("BB_KEPT_ONE") if kept.size() == 1 else tr("BB_KEPT_N") % kept.size())
		return
	var c: int = state.tin[place] if place >= 0 else -1
	if c < 0 or (holding() and _held_cells.is_empty() and _held_c == c):
		_drop()
		return
	if _now() < _tin_arrive[place]:
		return
	_pick(PackedInt32Array(), state.tin_of(c), c, tin_centre(place))

var _last_land := 0.0
## When the last landing ticked, into the tin (true) and onto a patch.
var _ticked_at := {}

## Sends a move's buttons on their way, one after another, each from where
## it hung (`starts`: a square, or -1 - place for one out of the tin) to
## its patch or its place in the tin. `at_cell` is the patch tapped, -1 for
## the tin.
func _play(res: Dictionary, at_cell: int, starts: Dictionary) -> void:
	var now := _now()
	var moves_: Array = res.moves
	var step := minf(RUN_STEP, RUN_STEP_CAP / maxf(1.0, moves_.size()))
	var fly := 0.0 if Motion.reduce else FLY_TIME
	var order := 0
	var sewn := 0
	var last := now
	var tin_k := _tin_step * 0.86 / _cell
	for m: Array in moves_:
		var kind := int(m[0])
		var at := now + (0.0 if Motion.reduce else order * step)
		var f := {"c": int(m[3]), "time": fly, "at": at, "k0": HELD_SCALE, "k1": 1.0}
		match kind:
			State.TO_PATCH:
				f.from = starts.get(int(m[1]), cell_centre(int(m[1])))
				f.to = cell_centre(int(m[2]))
				_arrive[int(m[2])] = at + fly
				sewn += 1
			State.TO_TIN:
				f.from = starts.get(int(m[1]), cell_centre(int(m[1])))
				f.to = tin_centre(int(m[2]))
				f.k1 = tin_k
				_tin_arrive[int(m[2])] = at + fly
			State.FROM_TIN:
				f.from = starts.get(-1 - int(m[1]), tin_centre(int(m[1])))
				f.to = cell_centre(int(m[2]))
				f.k0 = tin_k * HELD_SCALE
				_arrive[int(m[2])] = at + fly
				sewn += 1
		_flights.append(f)
		last = maxf(last, at + fly)
		_after(at + fly - now, _landed.bind(kind, int(m[2]), order))
		order += 1
	_last_land = last
	_bump_pill()
	_busy_for(last - now + Motion.BUMP_TIME + 0.1)
	# the streak: moves in a row that each sewed something
	if sewn > 0:
		_streak += 1
		if _streak >= 2:
			var semis: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
			_after(last - now, func() -> void:
				if not is_done():
					fx.cue("combo", pow(2.0, semis / 12.0), COMBO_DB))
		if _streak >= COMBO_FROM:
			_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
			_combo_n = _streak
			_combo_cell = at_cell
			_combo_at = _now()
			_combo_out_at = -INF
			if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
				fx.confetti(cell_centre(at_cell), 14, _cell * 3.0)
	else:
		_streak = 0
		if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
			_combo_out_at = now
	if sewn >= BIG_RUN:
		_after(last - now, func() -> void:
			if not is_done():
				fx.cue("run")
				if not Motion.reduce:
					fx.confetti(cell_centre(at_cell), 10 + mini(sewn, 12), _cell * 4.0))
	if not (res.whole as Array).is_empty():
		_after(last - now, _whole.bind(res.whole, int(res.was), int(res.now), at_cell))
	_redraw()
	note_move()
	_spend(1, last)

## One button has landed: its tick, a step up the run, and a ring where it
## was sewn.
func _landed(kind: int, where: int, nth: int) -> void:
	var pitch := pow(2.0, minf(RUN_CLIMB_MAX, nth * RUN_CLIMB) / 12.0) * randf_range(TICK_VARY.x, TICK_VARY.y)
	# A run lands a button every 0.04 s, and all at once with motion reduced:
	# its ticks and its knocks are a wheel spun, one every TICK_GAP, never a
	# rattle (fx.cue holds the sound to one in 60 ms but knocks every time).
	var now := _now()
	var into_tin := kind == State.TO_TIN
	var tick: bool = now - float(_ticked_at.get(into_tin, -INF)) >= TICK_GAP
	if tick:
		_ticked_at[into_tin] = now
		fx.cue("tin" if into_tin else "sew", pitch)
	if not into_tin and nth % 3 == 0:
		fx.ring(cell_centre(where), _cell * 0.6, Art.thread_for(Art.colour(state.colours[state.slot[where]])))
	_bump_pill()
	_busy_for(Motion.BUMP_TIME)
	_redraw()

## A colour is whole: its buttons hop outward from the tapped patch, and
## the tin gains a place.
func _whole(which: Array, was: int, now_open: int, from: int) -> void:
	if is_done():
		return
	var now := _now()
	var origin: Vector2i = state.xy(from)
	var far := 0
	for i in state.slot.size():
		if which.has(state.slot[i]):
			var d: Vector2i = state.xy(i) - origin
			var ring := maxi(absi(d.x), absi(d.y))
			far = maxi(far, ring)
			_hop_at[i] = now + ring * WHOLE_STEP
			if not Motion.reduce and (i * 7) % 5 == 0:
				fx.sparkle(cell_centre(i), Pal.SUN)
	fx.cue("whole")
	_busy_for(Motion.SOLVE_TIME + far * WHOLE_STEP + 0.1)
	if now_open > was:
		_tin = null
		_open_place = now_open - 1
		_open_at = now + 0.25
		_after(0.25, func() -> void:
			fx.cue("open")
			fx.ring(tin_centre(_open_place), _tin_step * 0.5, Pal.SUN)
			_redraw())
		_busy_for(0.25 + Motion.BUMP_TIME * 2.0)
		_tell(tr("BB_WHOLE_OPEN"), from)
	else:
		_tell(tr("BB_WHOLE"), from)
	_redraw()

func _refuse(i: int, why: String) -> void:
	_tell(tr(why), i)
	fx.cue("locked")
	if not Motion.reduce and state.cur[i] >= 0:
		_shiver_at[i] = _now()
		_busy_for(Motion.SHIVER_TIME)
	_redraw()

func tip_line() -> Dictionary:
	return {"text": "", "mood": Face.Expr.HAPPY}

# --- the HUD's actions ---

func can_undo() -> bool:
	return max_moves == 0 and not is_done() and not out_of_hearts and not state.history.is_empty()

## Takes the last tap back: its buttons are where they were, at once.
func undo() -> bool:
	if not can_undo() or not state.undo():
		return false
	_gen += 1
	_flights = []
	_arrive.fill(-INF)
	_tin_arrive.fill(-INF)
	_hop_at.fill(-INF)
	_unhold()
	_streak = 0
	_combo_n = 0
	_tin = null
	_bump_pill()
	fx.cue("undo", randf_range(TICK_VARY.x, TICK_VARY.y))
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return State.hints_for(state.band) + hints_extra - hints_used

## Makes the move the state's own hand would, as the player makes it: the
## pick, a beat, then the tap that says where it goes.
func hint() -> bool:
	if is_done() or out_of_hearts or hints_left() <= 0:
		return false
	var move: Dictionary = state.hint()
	if move.is_empty():
		return false
	hints_used += 1
	_unhold()
	var cells: PackedInt32Array = move.cells
	var places: PackedInt32Array = move.places
	var from_tin := cells.is_empty()
	var c: int = state.tin[places[0]] if from_tin else state.cur[cells[0]]
	var anchor := tin_centre(places[0]) if from_tin else cell_centre(cells[0])
	fx.ring(anchor, _cell * 0.7, Pal.SUN)
	fx.sparkle(anchor, Pal.SUN)
	fx.cue("hint")
	_pick(cells, places, c, anchor)
	var to := int(move.to)
	_tell(tr("BB_HINTED"), to if to >= 0 else cells[0])
	_after(0.0 if Motion.reduce else HINT_BEAT, func() -> void:
		if to >= 0:
			tap(to)
		else:
			tap_tin()
		# the bulb's move is one move: what it could not place is let go
		_unhold()
		_redraw())
	return true

## The cloth as the day opened it, every button popping back on, and on
## Insane every tap back. The hints a player spent are not refunded.
func reset_board() -> void:
	if is_done() or out_of_hearts:
		return
	_restart()
	_tell(tr("BB_RESET"))
	fx.cue("reset")

func _restart() -> void:
	_gen += 1
	state.reset()
	moves = 0
	_running = true
	_deal()
	_opened = _now() - Motion.ENTER_DELAY
	_busy_for(Motion.POP_IN + Motion.stagger(state.w + state.h, Motion.ENTER_STAGGER) + 0.1)
	_bump_pill()
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

func completion_record() -> Dictionary:
	return {"taps": state.taps, "left": moves_left}

## A completed daily is rebuilt from its seed, so the cloth opens scrambled:
## every button is sewn on and the taps it took are put back.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	state.finish(int(completed_record.get("taps", state.par)))
	_deal()
	moves_left = int(completed_record.get("left", 0))
	_opened = now - 10.0
	_solved_at = now - 10.0
	_slid_at = -INF
	_final_taps = state.taps
	_final_left = moves_left
	_anim_until = 0.0
	_stamp_at = now - 10.0 if _stamped() else INF
	_seal_mesh = null
	_hud_layer.queue_redraw()
	_redraw()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	out += "\n🧵 %d" % _final_taps
	if max_moves > 0:
		out += " " + "⭐".repeat(mini(_final_left, 10))
	return out

# --- the win ---

## Whether the day earned the seal: any Insane cloth, or one sewn in no more
## taps than the state's own hand takes.
func _stamped() -> bool:
	return state.band >= State.COUNTED_FROM or _final_taps <= state.par

func flat_win() -> Dictionary:
	var what := tr(state.name_key) if state.name_key != "" else title()
	var sub := tr("BB_WIN_SUB_ONE") % what if _final_taps == 1 else tr("BB_WIN_SUB_N") % [what, _final_taps]
	return {"faces": [], "subtitle": sub}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

## The last buttons land, the whole picture hops along its diagonals, the
## tin is put away and the picture has the table.
func _on_solved() -> void:
	var now := _now()
	_pressed = -1
	_toast = ""
	_unhold()
	_combo_n = 0
	_solved_at = now
	_final_taps = state.taps
	_final_left = moves_left - (1 if max_moves > 0 else 0)
	var lag := 0.0 if Motion.reduce else maxf(0.0, _last_land - now) + Motion.SOLVE_DELAY
	for i in state.slot.size():
		if state.slot[i] >= 0:
			var c: Vector2i = state.xy(i)
			_hop_at[i] = now + lag + Motion.stagger(c.x + c.y, Motion.SOLVE_STAGGER, 1.0)
	_after(lag, fx.cue.bind("solved"))
	_hud_layer.queue_redraw()
	_party(lag)
	_busy_for(lag + Motion.SOLVE_TIME + 1.0 + WIN_SLIDE + 0.3)
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

## The seal on the picture's lower right, dropping in and settling.
func _draw_stamp(now: float, shown: Array, slide: Transform2D) -> void:
	var field := _field_px()
	var rad := maxf(field.size.x, 420.0) * STAMP_R
	var insane: bool = state.band >= State.COUNTED_FROM
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := field.end - Vector2(rad, rad) * 0.6
	var xf := slide * Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	draw_set_transform_matrix(xf)
	draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var neat: bool = _final_taps <= state.par
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("BB_SEAL_NEAT") if neat else tr("BB_SEAL_INSANE"), 0.17, 0.36]]
	else:
		lines = [[tr("BB_SEAL_NEAT"), 0.24, 0.12]]
	Seal.text(self, rad, lines)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# --- Insane's taps ---

## Spends `cost` taps. The last one spent with buttons still loose is the
## board lost, once its buttons have landed.
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
	_pressed = -1
	fx.cue("out_of_hearts")
	_tell(tr("BB_OUT"))
	_redraw()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

## The card, over the whole screen: on the host so it covers the chrome, or
## on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["OUT_MOVES_BODY", "OUT_MOVES_REST"], MOVES_BONUS)
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same cloth from the top, every tap back, the clock from
## zero.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	elapsed = 0.0
	_restart()
	fx.cue("reset")
	moved.emit()

## A few more taps (the card's video): once a board.
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

## The chrome is the host's; here the cloth pops in wide and the buttons pop
## onto it along the diagonals.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP + Motion.POP_IN + Motion.stagger(state.w + state.h, Motion.ENTER_STAGGER))
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
	if now < _anim_until or now - _slid_at < WIN_SLIDE + 0.1:
		queue_redraw()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.DROP_FADE + 0.1 or now - _pill_bump < Motion.BUMP_TIME + 0.1 \
			or (_toast != "" and now - _toast_at < TOAST_HOLD + 0.1) \
			or (_combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF)):
		_hud_layer.queue_redraw()

func _redraw() -> void:
	_live_dirty = true
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
