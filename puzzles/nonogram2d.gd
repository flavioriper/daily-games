extends "res://core/puzzle_base.gd"

## Nonogram as a flat board: a mosaic floor of pale sockets on the host's
## parchment card, slate tiles laid into it, a pebble on every cell ruled out,
## and the clue numbers in ink along a band above and to the left. Built
## beside the island version (puzzles/nonogram3d.gd) so the two can be judged
## against each other on the phone; the rules live in
## puzzles/nonogram_state.gd, which this only draws.
##
## What flat buys here is the largest margin of the nine, and it is worth
## saying plainly. **The clues are the puzzle**, and the island puts them on
## marker stones: one stone carries one numeral and needs a whole cell of
## platform to stand on. A hard board has 18 lines and about 47 numbers,
## consulted on every deduction, and on a board pitched at seven degrees the
## far band is the smallest, most foreshortened thing on the screen. Flat, a
## clue is text in a band: it costs 0.55 of a cell, it can say any number, and
## it can change colour legibly. **And it buys the five-cell guides** -- every
## nonogram in the world rules a heavier line every fifth cell, because
## counting to seven along a row of nine is where mistakes come from, and a
## grout line between flagstones is not something the island can thicken.
## What it costs is the relief: the island's finished picture is an object,
## and this screen answers with the reveal rather than with the surface.
##
## How it is drawn. Every socket, guide line, tile and pebble goes into one
## mesh, rebuilt only while something moves, because none of them has a face
## on it and a Control per cell would be eighty-one nodes for a field of
## squares. The clue numbers are drawn over it with one draw_string each, as
## puzzles/lightup2d.gd draws its numerals: a digit in a mesh cache key would
## multiply every state by ten. Everything is drawn, so every moment reads
## the flat boards' vocabulary as curves off core/motion.gd (rule 8 of
## docs/art/flat-motion.md): the floor pops in wide and the numbers pop in
## with the squash; a cell sinks under the finger; a tile pops in, leans its
## neighbours and bumps its line's numbers; a leaving tile shrinks with the
## quarter turn; Check wobbles and blushes; Reset runs its wave from the far
## corner. What is this board's own is the reveal: the pebbles clearing in a
## scatter, the sockets fading back to parchment and the grout closing up.
## The second polish added the paper tabs under the clues, the lit row and
## column under the finger, the stroke's count and the glints.
## Spec: docs/superpowers/specs/2026-09-18-nonogram-flat-design.md, and the
## amendments in its sections 11 and 12; the mock it is ported from is
## docs/brainstorm/concepts.html#nonogram.

const State = preload("res://puzzles/nonogram_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

# --- the floor ---
const PAD := 30.0
## The clue band, per number, in cells. On the island it is a whole extra row
## and column of bare platform, because a stone has to stand on something;
## here nothing stands on it, and this is most of why a 9x9 fits at all.
const NUM := 0.55
const NUM_SIZE := 0.42
## The heavier line every fifth cell, which only a board with more than five
## of them needs.
const GUIDE_EVERY := 5
const GUIDE_WIDTH := 3.0
const GUIDE_ALPHA := 0.85
## The hint's ring, in cells: it starts just outside the tile.
const RING_R := 0.62
## How far a nudged piece leans, in cells; the family's NUDGE is in pixels on
## a 147 px tile, and a cell here is 88 to 150.
const NUDGE := 0.03
const SHIVER := 0.03

# --- this board's own motion: the reveal ---
## The scaffolding leaves after the last tile has hopped: the grout closes,
## the sockets and the guides fade back to parchment.
const GONE_DELAY := 0.6
const GONE_TIME := 0.7
## How far the clue numbers fade with it. Not all the way: a picture with the
## numbers that made it still faintly beside it reads as an answer, where a
## bare picture reads as a screensaver.
const CLUE_GONE := 0.85
## The pebbles clear away in a scatter.
const CLEAR_DELAY := 0.2
const CLEAR_SPREAD := 0.3
const CLEAR_TIME := 0.5
const WIN_WAIT := 1.6

# --- the second polish (2026-09-25) ---
## The clue tabs: a strip of paper behind each line's numbers, TAB_INSET of a
## cell in from its neighbours' and TAB_GAP clear of the floor, so a number
## reads as belonging to its line rather than floating beside it. A tab
## washes toward its line's verdict over WASH_TIME -- TAB_OK of the way to the
## family's green, TAB_OVER to the pale rose -- as the tile that decided it
## lands.
const TAB_INSET := 0.07
const TAB_GAP := 0.1
const TAB_RADIUS := 0.16
const TAB_A := 0.7
const TAB_OK := 0.32
const TAB_OVER := 0.75
const WASH_TIME := 0.25
## The row and the column under the finger wash toward the sun, sockets
## FOCUS and tabs FOCUS_TAB of the way, in over FOCUS_IN and out over
## FOCUS_OUT: the clues a stroke is being checked against are lit while it is
## drawn.
const FOCUS := 0.2
const FOCUS_TAB := 0.5
const FOCUS_IN := 0.1
const FOCUS_OUT := 0.2
## The stroke's count: a pill BADGE_OFF cells off the finger, BADGE_H of a
## cell tall, saying how long the run being drawn is, from two cells on.
const BADGE_OFF := 0.95
const BADGE_H := 0.56
const BADGE_SIZE := 0.36
## A line that comes out right: its numbers hop and a glint runs out of its
## clue along its tiles, WAVE_STEP a cell, each tile's shine a bell over
## GLINT_TIME, starting GLINT_DELAY after the tile that decided it lands.
const GLINT_DELAY := 0.1
const GLINT_TIME := 0.3
## The win's glint: once the grout has closed, a light crosses the picture
## along the diagonal, WIN_GLINT_STEP a diagonal.
const WIN_GLINT_AT := 1.1
const WIN_GLINT_STEP := 0.06
const WIN_GLINT_TIME := 0.3

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
## Translation keys (locale/ui.csv), read through tr() when said.
const TIPS := ["NG_TIP_RUNS", "NG_TIP_DRAG", "NG_TIP_GREEN"]

var state = State.new()
## Which chip the tray has armed: State.FILL or State.MARK. The tray only
## asks; this owns it, and tile_tray.gd reads it back.
var brush: int = State.FILL

## The names the win harness and the island board share.
var w: int:
	get: return state.w
var h: int:
	get: return state.h
var _bitmap: Array:
	get: return state.bitmap

var fx: Node2D
var _cell := 0.0
## The grid's top-left, past the bands, and the bands' own width and height.
var _grid := Vector2.ZERO
var _band := Vector2.ZERO

## Every drawn thing's moments, each the second it began, read off Motion's
## curve readers in _build_floor and _draw_clues.
var _arrive: Dictionary = {}    # cell -> {"at", "drop"}: its piece pops or drops in
var _leaving: Array = []        # [{"cell", "kind", "held", "at"}]: pieces shrinking out
var _sunk: Dictionary = {}      # cell -> {"down", "up"}: the finger has it
var _hop: Dictionary = {}       # cell -> {"at", "height", "time"}
var _nudge: Dictionary = {}     # cell -> {"at", "dir"}
var _wrong: Dictionary = {}     # cell -> at: Check pointed at it (wobble and blush)
var _shiver: Dictionary = {}    # cell -> at: a refused press
var _clue_bump: Dictionary = {} # "r3" / "c5" -> at: the line was recounted
var _clue_hop: Dictionary = {}  # line key -> {"at", "height", "time"}
var _lines: Dictionary = {}     # line key -> {"state", "was", "to", "at"}: its tab's wash
var _glint: Dictionary = {}     # line key -> at: the glint runs out of its clue
## The cell the finger is on, and when it went down and came up (INF while
## down): the row and the column it lights.
var _focus_cell := Vector2i(-1, -1)
var _focus_down := -100.0
var _focus_up := -100.0
## When the stroke's count first showed, and when it last changed.
var _badge_at := -1.0
var _badge_bump := -100.0
var _badge_n := 0
var _badge_shown: ArrayMesh

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
var _dragged := false
## 0 none yet, 1 locked to the row, 2 locked to the column.
var _axis := 0
var _erase := false
var _painted: Dictionary = {}
var _pending: Array = []
var _last_paint := Vector2i(-1, -1)

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
var _gen := 0
var _floor: ArrayMesh
## The mesh the last _draw actually handed to the canvas item. A canvas
## command holds the mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: ArrayMesh
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "nonogram"
func title() -> String: return "Nonogram"

func rules() -> String:
	return tr("NG_RULES")

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
	_gen += 1
	state.setup(rng, difficulty)
	brush = State.FILL
	_arrive = {}
	_leaving = []
	_sunk = {}
	_hop = {}
	_nudge = {}
	_wrong = {}
	_shiver = {}
	_clue_bump = {}
	_clue_hop = {}
	_glint = {}
	_focus_cell = Vector2i(-1, -1)
	_clear_gesture()
	_solved_at = -1.0
	_seed_verdicts()
	_layout()
	_enter()
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()

# --- layout ---

## The floor is the largest grid the card holds, and the card is cut to it and
## centred in the slot rather than pinned under the day card. This is the
## fourth board whose grid is square while its space is tall: the cell is
## capped by the width, so there is slack however it is cut, and air above and
## below reads as centring where all of it below reads as a board that fell
## over.
func _layout() -> void:
	if state.bitmap.is_empty():
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	_band = Vector2(_cell * state.gw * NUM, _cell * state.gh * NUM)
	var floor_size := Vector2(_cell * state.w, _cell * state.h) + _band
	_grid = Vector2(size.x * 0.5 - floor_size.x * 0.5,
		(size.y - floor_size.y) * 0.5) + _band
	_refresh()

## The cell a slot of `available` height holds, capped by the width. The bands
## are measured from the puzzle in hand -- as the island measures its margin
## of bare platform -- so a gentle picture gets a tight board.
func _cell_for(available: float) -> float:
	if state.bitmap.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / (state.w + state.gw * NUM),
		(available - 2.0 * PAD) / (state.h + state.gh * NUM))

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * (state.h + state.gh * NUM) + 2.0 * PAD)

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
	return cell if state.in_grid(cell) else Vector2i(-1, -1)

## The centre of the whole floor, bands included: what the entrance pops
## about.
func _floor_centre() -> Vector2:
	return _grid - _band * 0.5 + Vector2(state.w, state.h) * _cell * 0.5

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or state.bitmap.is_empty():
		return
	if _now() < _anim_until:
		_refresh()

## Keeps the floor redrawing for `seconds` more: something on it is moving. A
## floor left alone costs nothing: it has no character on it to sway or
## blink, which is the one thing this screen has less of than the other
## eight.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _refresh() -> void:
	_floor = _build_floor(_now())
	queue_redraw()

# --- the drawing ---

## The floor pops in wide about its centre (rule 7: a wide thing comes from
## most of the way) while it fades in, as one draw transform over the mesh;
## the numbers pop in over it on their own.
func _draw() -> void:
	_shown = _floor
	if _shown != null:
		var elapsed := _now() - _opened - Motion.ENTER_DELAY
		var grow := Motion.wide_pop_scale(elapsed)
		var c := _floor_centre()
		draw_mesh(_shown, null, Transform2D(0.0, Vector2.ONE * grow, 0.0, c * (1.0 - grow)),
			Color(1.0, 1.0, 1.0, Motion.appear_level(elapsed)))
	_draw_clues()
	_draw_badge()

## Everything on the floor in one mesh, in the order the mock paints it: the
## sockets, the five-cell guides over them, the pieces on their way out, and
## what the player has put down.
func _build_floor(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var gone := _gone(t)
	var focus := _focus_level(t)
	_tabs(b, gone, focus, t)
	for y in state.h:
		for x in state.w:
			var cell := Vector2i(x, y)
			var lit := focus if focus > 0.0 and (x == _focus_cell.x or y == _focus_cell.y) else 0.0
			Mosaic.socket(b, _grid + Vector2(x, y) * _cell, _cell,
				state.mark_at(cell) == State.MARK, 1.0 - gone, _sink(cell, t),
				Color(Pal.SUN, FOCUS * lit))
	_guides(b, gone)
	_build_leaving(b, t)
	for cell in state.marks:
		if int(state.marks[cell]) == State.MARK:
			_draw_pebble(b, cell, t)
		else:
			_draw_tile(b, cell, t, gone)
	if b.verts.is_empty():
		return null
	return b.mesh()

## The paper tabs behind the clue numbers, one a line, each washed toward its
## line's verdict and toward the sun while the finger is on its line. They
## leave with the rest of the scaffolding on the win.
func _tabs(b, gone: float, focus: float, t: float) -> void:
	var alpha := TAB_A * (1.0 - gone)
	if alpha <= 0.0:
		return
	var inset := _cell * TAB_INSET
	var r := _cell * TAB_RADIUS
	for y in state.h:
		var ink := _tab_colour("r%d" % y, state.row_state(y), t)
		if focus > 0.0 and y == _focus_cell.y:
			ink = ink.lerp(Pal.SUN_TILE, FOCUS_TAB * focus)
		b.fan(Face.Builder.round_rect(Vector2(_grid.x - _band.x, _grid.y + y * _cell + inset),
			Vector2(_band.x - _cell * TAB_GAP, _cell - 2.0 * inset), r), Color(ink, alpha))
	for x in state.w:
		var ink := _tab_colour("c%d" % x, state.col_state(x), t)
		if focus > 0.0 and x == _focus_cell.x:
			ink = ink.lerp(Pal.SUN_TILE, FOCUS_TAB * focus)
		b.fan(Face.Builder.round_rect(Vector2(_grid.x + x * _cell + inset, _grid.y - _band.y),
			Vector2(_cell - 2.0 * inset, _band.y - _cell * TAB_GAP), r), Color(ink, alpha))

## What a tab is washed to for a line in `line_state`.
func _verdict_ink(line_state: int) -> Color:
	match line_state:
		State.LINE_OK: return Pal.SURFACE.lerp(Pal.GOOD, TAB_OK)
		State.LINE_OVER: return Pal.SURFACE.lerp(Pal.BAD_TILE, TAB_OVER)
		_: return Pal.SURFACE

## A tab's colour now, partway through its wash.
func _tab_colour(key: String, line_state: int, t: float) -> Color:
	if not _lines.has(key):
		return _verdict_ink(line_state)
	var l: Dictionary = _lines[key]
	var u := _dec((t - float(l.at)) / WASH_TIME)
	return (l.was as Color).lerp(l.to, u * u * (3.0 - 2.0 * u))

## Every line's verdict as it stands, with no wash: a fresh or restored board.
func _seed_verdicts() -> void:
	_lines = {}
	for y in state.h:
		var ink := _verdict_ink(state.row_state(y))
		_lines["r%d" % y] = {"state": state.row_state(y), "was": ink, "to": ink, "at": -100.0}
	for x in state.w:
		var ink := _verdict_ink(state.col_state(x))
		_lines["c%d" % x] = {"state": state.col_state(x), "was": ink, "to": ink, "at": -100.0}

## Every line whose verdict a move changed washes its tab as the last of its
## own cells in `arrivals` lands; one that has just come out right hops its
## numbers and runs a glint along its tiles -- unless the move finished the
## picture, whose own wave says it louder.
func _verdicts(t: float, arrivals: Dictionary) -> void:
	for y in state.h:
		_verdict("r%d" % y, state.row_state(y), _line_lands(arrivals, t, y, -1), state.w)
	for x in state.w:
		_verdict("c%d" % x, state.col_state(x), _line_lands(arrivals, t, -1, x), state.h)

func _verdict(key: String, line_state: int, at: float, length: int) -> void:
	if not _lines.has(key):
		_seed_verdicts()
		return
	var l: Dictionary = _lines[key]
	if int(l.state) == line_state:
		return
	l.was = _tab_colour(key, int(l.state), _now())
	l.to = _verdict_ink(line_state)
	l.state = line_state
	l.at = at
	_busy_for(at - _now() + WASH_TIME)
	if line_state != State.LINE_OK or Motion.reduce or state.is_solved():
		return
	var go := at + GLINT_DELAY
	_glint[key] = go
	_clue_hop[key] = {"at": go, "height": Motion.HOP, "time": Motion.HOP_TIME}
	_busy_for(go - _now() + maxf(Motion.stagger(length - 1, Motion.WAVE_STEP, 9.0) + GLINT_TIME,
		Motion.HOP_TIME))

## When the last of a line's cells in `arrivals` lands (row `y`, or column `x`
## when `y` is negative), or `t` when none of them moved.
func _line_lands(arrivals: Dictionary, t: float, y: int, x: int) -> float:
	var out := t
	for cell in arrivals:
		if (y >= 0 and cell.y == y) or (y < 0 and cell.x == x):
			out = maxf(out, float(arrivals[cell]))
	return out

## How far a tile shines now: the glint of a line that came out right, running
## out of its clue, and on the win the light crossing the picture.
func _shine(cell: Vector2i, t: float) -> float:
	if Motion.reduce:
		return 0.0
	var out := 0.0
	if _glint.has("r%d" % cell.y):
		out = _bell(t - float(_glint["r%d" % cell.y]) - cell.x * Motion.WAVE_STEP, GLINT_TIME)
	if _glint.has("c%d" % cell.x):
		out = maxf(out, _bell(t - float(_glint["c%d" % cell.x]) - cell.y * Motion.WAVE_STEP, GLINT_TIME))
	if _solved_at >= 0.0:
		out = maxf(out, _bell(t - _solved_at - WIN_GLINT_AT - (cell.x + cell.y) * WIN_GLINT_STEP,
			WIN_GLINT_TIME))
	return out

static func _bell(elapsed: float, time: float) -> float:
	if elapsed <= 0.0 or elapsed >= time:
		return 0.0
	return sin(PI * elapsed / time)

## How lit the finger's row and column are now.
func _focus_level(t: float) -> float:
	if _focus_cell.x < 0:
		return 0.0
	var held := is_inf(_focus_up)
	if Motion.reduce:
		return 1.0 if held else 0.0
	var level := clampf((t - _focus_down) / FOCUS_IN, 0.0, 1.0)
	if not held:
		level = minf(level, 1.0 - clampf((t - _focus_up) / FOCUS_OUT, 0.0, 1.0))
	return level

## The heavier line every fifth cell. A 5x5 has none to rule; on the 9x9 it is
## the difference between counting and glancing.
func _guides(b, gone: float) -> void:
	if state.w <= GUIDE_EVERY and state.h <= GUIDE_EVERY:
		return
	var alpha := 1.0 - gone
	if alpha <= 0.0:
		return
	var ink := Color(Pal.LINE, GUIDE_ALPHA * alpha)
	var field := Vector2(_cell * state.w, _cell * state.h)
	for i in range(GUIDE_EVERY, state.w, GUIDE_EVERY):
		b.stroke(PackedVector2Array([_grid + Vector2(i * _cell, 0.0),
			_grid + Vector2(i * _cell, field.y)]), GUIDE_WIDTH, ink, false, false)
	for i in range(GUIDE_EVERY, state.h, GUIDE_EVERY):
		b.stroke(PackedVector2Array([_grid + Vector2(0.0, i * _cell),
			_grid + Vector2(field.x, i * _cell)]), GUIDE_WIDTH, ink, false, false)

## press_scale for the cell under the finger, one when it is not.
func _sink(cell: Vector2i, t: float) -> float:
	if not _sunk.has(cell):
		return 1.0
	var pr: Dictionary = _sunk[cell]
	var released := -1.0 if is_inf(float(pr.up)) else t - float(pr.up)
	var s := Motion.press_scale(t - float(pr.down), released)
	if s >= 1.0 and released >= 0.0:
		_sunk.erase(cell)
	return s

## A laid tile: it pops in with the squash (or drops in, from a hint), sinks
## under the finger, leans when a neighbour lands, wobbles and blushes when
## Check points at it, shivers when it refuses, and hops on the win.
func _draw_tile(b, cell: Vector2i, t: float, gone: float) -> void:
	var grow := _grow(cell, t)
	if grow.x <= 0.0:
		return
	var at := cell_to_local(cell.y, cell.x) + _offset(cell, t)
	var angle := Motion.wobble_angle(t - float(_wrong.get(cell, -100.0)))
	var blush := Motion.flash_level(t - float(_wrong.get(cell, -100.0)))
	Mosaic.tile(b, at, _cell, grow, state.locked.has(cell), gone, _alpha(cell, t), angle, blush,
		_tone(cell), _shine(cell, t))

## A pebble: the same arrival, sink and lean, and on the win it clears away
## in a scatter -- a hard board finishes with 38 of its 81 cells under
## pebbles, and the picture has to be left standing on its own.
func _draw_pebble(b, cell: Vector2i, t: float) -> void:
	var alpha := _alpha(cell, t)
	if _solved_at >= 0.0:
		var clear := _dec((t - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD) / CLEAR_TIME)
		if clear >= 1.0:
			return
		alpha *= 1.0 - clear
	var grow := _grow(cell, t)
	if grow.x <= 0.0:
		return
	Mosaic.pebble(b, cell_to_local(cell.y, cell.x) + _offset(cell, t), _cell, grow, alpha)

## The pieces Reset, an undo or a fresh stroke took away: each shrinks to
## nothing with the quarter turn where it lay, after the state has forgotten
## it (the Remove moment).
func _build_leaving(b, t: float) -> void:
	var keep: Array = []
	for g in _leaving:
		var elapsed: float = t - float(g.at)
		var grow := Motion.pop_out_scale(elapsed)
		if grow <= 0.0:
			continue
		keep.append(g)
		var cell: Vector2i = g.cell
		var at := cell_to_local(cell.y, cell.x)
		var angle := 0.0 if Motion.reduce else PI * 0.5 * clampf(elapsed / Motion.POP_OUT, 0.0, 1.0)
		if int(g.kind) == State.MARK:
			Mosaic.pebble(b, at, _cell, Vector2.ONE * grow, 1.0, angle)
		else:
			Mosaic.tile(b, at, _cell, Vector2.ONE * grow, bool(g.held), 0.0, 1.0, angle, 0.0, _tone(cell))
	_leaving = keep

## A piece's scale now: its arrival's pop (the squash) or one, times the sink
## under the finger.
func _grow(cell: Vector2i, t: float) -> Vector2:
	var grow := Vector2.ONE
	if _arrive.has(cell):
		var a: Dictionary = _arrive[cell]
		if not bool(a.drop):
			grow = Motion.pop_in_scale(t - float(a.at))
		elif t < float(a.at) and not Motion.reduce:
			grow = Vector2.ZERO
	return grow * _sink(cell, t)

## A piece's alpha now: a dropping piece fades in over its first tenth.
func _alpha(cell: Vector2i, t: float) -> float:
	if _arrive.has(cell) and bool(_arrive[cell].drop):
		return Motion.appear_level(t - float(_arrive[cell].at))
	return 1.0

## Where a piece is besides its cell: a hint's drop from above, the lean a
## neighbour's landing gave it, the shiver of a refusal, the hop of the win.
func _offset(cell: Vector2i, t: float) -> Vector2:
	var out := Vector2.ZERO
	if _arrive.has(cell) and bool(_arrive[cell].drop):
		out.y -= Motion.drop_in_lift(t - float(_arrive[cell].at))
	if _nudge.has(cell):
		var n: Dictionary = _nudge[cell]
		out += (n.dir as Vector2) * Motion.nudge_offset(t - float(n.at), _cell * NUDGE)
	out.x += Motion.shiver_offset(t - float(_shiver.get(cell, -100.0)), _cell * SHIVER)
	if _hop.has(cell):
		var hop: Dictionary = _hop[cell]
		out.y += Motion.hop_lift(t - float(hop.at), hop.height, hop.time)
	return out

## How far the scaffolding has left on the win: the grout closes, the sockets
## and the guides fade back to parchment, and the clue numbers go faint.
func _gone(t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	return _dec((t - _solved_at - GONE_DELAY) / GONE_TIME)

## The clue numbers, over the floor's mesh: right-aligned along the left band
## and bottom-aligned up the top one, as a nonogram's clues always are, and
## coloured per line -- green the moment the line's runs read exactly as they
## say, rose the moment it holds more filled cells than they allow. A line
## with nothing in it says 0 rather than nothing, so every line speaks. Each
## line's numbers pop in with the squash along the band a beat after the
## floor, bump when the line is recounted and hop on Reset, through one draw
## transform per line.
func _draw_clues() -> void:
	if _cell <= 0.0 or state.bitmap.is_empty():
		return
	var t := _now()
	var faded := 1.0 - _gone(t) * CLUE_GONE
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell * NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	for y in state.h:
		var key := "r%d" % y
		var scale := _clue_scale(key, y, t)
		if scale.x <= 0.0:
			continue
		var ink := Color(_clue_ink(state.row_state(y)), faded)
		var clue: Array = state.row_clues[y] if not (state.row_clues[y] as Array).is_empty() else [0]
		var centre := Vector2(_grid.x - _band.x * 0.5, _grid.y + (y + 0.5) * _cell + _clue_lift(key, t))
		draw_set_transform(centre, 0.0, scale)
		for i in clue.size():
			var slot: int = clue.size() - 1 - i
			_number(font, px, rise, str(clue[i]),
				Vector2(_band.x * 0.5 - _cell * NUM * (slot + 0.5), 0.0), ink)
	for x in state.w:
		var key := "c%d" % x
		var scale := _clue_scale(key, x, t)
		if scale.x <= 0.0:
			continue
		var ink := Color(_clue_ink(state.col_state(x)), faded)
		var clue: Array = state.col_clues[x] if not (state.col_clues[x] as Array).is_empty() else [0]
		var centre := Vector2(_grid.x + (x + 0.5) * _cell, _grid.y - _band.y * 0.5 + _clue_lift(key, t))
		draw_set_transform(centre, 0.0, scale)
		for i in clue.size():
			var slot: int = clue.size() - 1 - i
			_number(font, px, rise, str(clue[i]),
				Vector2(0.0, _band.y * 0.5 - _cell * NUM * (slot + 0.5)), ink)
	draw_set_transform(Vector2.ZERO)

## A line's numbers' scale now: the entrance pop along the band, times the
## Count bump.
func _clue_scale(key: String, index: int, t: float) -> Vector2:
	var grow := Motion.pop_in_scale(t - _opened - _enter_clue_delay(index))
	return grow * Motion.bump_scale(t - float(_clue_bump.get(key, -100.0)))

## A line's numbers' lift now: the hop Reset gives them.
func _clue_lift(key: String, t: float) -> float:
	if not _clue_hop.has(key):
		return 0.0
	var hop: Dictionary = _clue_hop[key]
	return Motion.hop_lift(t - float(hop.at), hop.height, hop.time)

func _clue_ink(line_state: int) -> Color:
	if is_done():
		return Pal.CLUE_OK
	match line_state:
		State.LINE_OK: return Pal.CLUE_OK
		State.LINE_OVER: return Pal.CLUE_OVER
		_: return Pal.TEXT

## One number centred on `centre`, in the transform already set.
func _number(font: Font, px: int, rise: float, text: String, centre: Vector2, ink: Color) -> void:
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	draw_string(font, centre + Vector2(-wide * 0.5, rise), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)

# --- the moments ---

## The chrome is the host's; here the floor pops in wide (in _draw) after the
## family's delay, and each line's numbers pop in with the squash along their
## band a beat later.
func _enter() -> void:
	_opened = _now()
	_busy_for(maxf(Motion.ENTER_DELAY + Motion.ENTER_POP,
		_enter_clue_delay(maxi(state.w, state.h) - 1) + Motion.POP_IN))
	fx.cue("enter")

func _enter_clue_delay(index: int) -> float:
	return Motion.ENTER_DELAY + Motion.ENTER_FACE_LAG + Motion.stagger(index, Motion.ENTER_STAGGER)

## The cell under the finger sinks (the Press moment), and stays down until
## the piece it is waiting for lands or the finger lets it go.
func _sink_cell(cell: Vector2i) -> void:
	if _sunk.has(cell) and is_inf(float(_sunk[cell].up)):
		return
	_sunk[cell] = {"down": _now(), "up": INF}
	_busy_for(Motion.PRESS_TIME)

## Lets go of every cell the gesture still holds down: each springs back when
## the piece it is under arrives, or now.
func _end_sinks(now: float, arrivals: Dictionary = {}) -> void:
	if _focus_cell.x >= 0 and is_inf(_focus_up):
		_focus_up = now
		_busy_for(FOCUS_OUT)
	var last := now
	for cell in _sunk:
		var pr: Dictionary = _sunk[cell]
		if is_inf(float(pr.up)):
			pr.up = float(arrivals.get(cell, now))
			last = maxf(last, float(pr.up))
	_anim_until = maxf(_anim_until, last + Motion.RELEASE_TIME)

## Every cell in `cells` moves from what `before` had on it to what the state
## has now, the k-th one `per` seconds after the first: a piece pops in (or
## drops in, from a hint) or shrinks out, and a line a tile joined or left is
## recounted. Returns the second each cell's piece arrives.
func _transition(before: Dictionary, cells: Array, t: float, per: float, drop := false) -> Dictionary:
	var arrivals: Dictionary = {}
	for k in cells.size():
		var cell: Vector2i = cells[k]
		var at := t + (0.0 if Motion.reduce else Motion.stagger(k, per))
		arrivals[cell] = at
		var prev := int(before.get(cell, State.BLANK))
		var mark := state.mark_at(cell)
		if prev == mark:
			continue
		if prev != State.BLANK:
			_leave(cell, prev, at)
		if mark != State.BLANK:
			_arrive[cell] = {"at": at, "drop": drop}
			_busy_for(at - t + (Motion.DROP_TIME if drop else Motion.POP_IN))
		else:
			_arrive.erase(cell)
		if prev == State.FILL or mark == State.FILL:
			_recount(cell, at)
	_verdicts(t, arrivals)
	return arrivals

## The piece `kind` on `cell` leaves at `at`: kept on a list, since the state
## has already forgotten it, and drawn shrinking with the quarter turn.
func _leave(cell: Vector2i, kind: int, at: float, held := false) -> void:
	_wrong.erase(cell)
	_shiver.erase(cell)
	if Motion.reduce:
		return
	_leaving.append({"cell": cell, "kind": kind, "held": held, "at": at})
	_busy_for(at - _now() + Motion.POP_OUT)

## The Count moment: the row's and the column's numbers have just been
## recounted, and bump as the tile arrives or leaves.
func _recount(cell: Vector2i, at: float) -> void:
	if Motion.reduce:
		return
	_clue_bump["r%d" % cell.y] = at
	_clue_bump["c%d" % cell.x] = at
	_busy_for(at - _now() + Motion.BUMP_TIME)

## The pieces on the four sides of a piece that has just landed lean away
## from it and back.
func _nudge_around(cell: Vector2i, t: float) -> void:
	if Motion.reduce:
		return
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = cell + d
		if state.in_grid(n) and state.mark_at(n) != State.BLANK:
			_nudge[n] = {"at": t, "dir": Vector2(d)}
	_busy_for(Motion.NUDGE_LAG + Motion.NUDGE_TIME)

## A press refused on `cell` (a tile a hint grouted in): it shivers and
## blushes toward the family's rose, and the sprout says why.
func _refuse(cell: Vector2i) -> void:
	_say(tr("NG_GROUTED"), Face.Expr.PUZZLED)
	fx.cue("locked")
	if Motion.reduce:
		return
	var now := _now()
	_shiver[cell] = now
	_wrong[cell] = now
	_busy_for(maxf(Motion.SHIVER_TIME, maxf(Motion.WOBBLE_TIME, Motion.FLASH_IN + Motion.FLASH_OUT)))

## The wave from the far corner Reset runs, per cell.
func _reset_wave(cell: Vector2i) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.stagger(state.w + state.h - 2 - cell.x - cell.y, Motion.RESET_STAGGER)

func _solve_delay(cell: Vector2i) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.SOLVE_DELAY + Motion.stagger(cell.x + cell.y, Motion.SOLVE_STAGGER)

# --- input ---

## Touch and drag only, as every flat board takes them. A press paints the
## cell it landed on with the armed chip -- or rubs it out, if that cell
## already holds what the chip paints -- and a drag carries that decision
## along one line.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _press_cell.x >= 0:
		_drag(event.position)

func _press(cell: Vector2i) -> void:
	_end_sinks(_now())
	_clear_gesture()
	if is_done() or cell.x < 0:
		return
	_press_cell = cell
	_focus_cell = cell
	_focus_down = _now()
	_focus_up = INF
	_busy_for(FOCUS_IN)
	# The stroke's job is read off the cell it began on, exactly as Tents' and
	# Light Up's sweeps are, so there is no eraser chip to arm and no mode to
	# get stuck in.
	_erase = state.mark_at(cell) == brush
	_paint(cell)
	_refresh()

func _drag(at: Vector2) -> void:
	var cell := _cell_at(at)
	if cell.x < 0:
		return
	# A stroke locks to a row or a column the moment it leaves the first cell,
	# by whichever direction is larger. A nonogram is played in lines, and a
	# finger dragged across a phone wanders; without the lock, painting a run
	# of six in the middle of a 9x9 reliably catches a cell in the row above.
	if _axis == 0:
		if cell == _press_cell:
			return
		_dragged = true
		_axis = 1 if absi(cell.x - _press_cell.x) >= absi(cell.y - _press_cell.y) else 2
	var on_line := Vector2i(cell.x, _press_cell.y) if _axis == 1 \
		else Vector2i(_press_cell.x, cell.y)
	# Every cell between the last one painted and this one, so a fast finger
	# does not leave holes in its run.
	if _last_paint.x >= 0:
		var steps := maxi(absi(on_line.x - _last_paint.x), absi(on_line.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(
				roundi(lerpf(_last_paint.x, on_line.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, on_line.y, float(i) / steps))))
	_paint(on_line)
	_focus_cell = on_line
	var n := absi(on_line.x - _press_cell.x) + absi(on_line.y - _press_cell.y) + 1
	if n != _badge_n:
		var now := _now()
		if _badge_at < 0.0 and n >= 2:
			_badge_at = now
			_busy_for(Motion.POP_IN)
		elif n >= 2:
			_badge_bump = now
			_busy_for(Motion.BUMP_TIME)
		_badge_n = n
	_refresh()

## A stroke never disturbs a tile a hint grouted in, and never paints a cell
## twice: crossing back over your own stroke is how a finger wanders, not a
## second decision. Every cell the finger can change sinks under it as it
## passes.
func _paint(cell: Vector2i) -> void:
	if not state.in_grid(cell):
		return
	_last_paint = cell
	if _painted.has(cell):
		return
	_painted[cell] = true
	if state.locked.has(cell):
		return
	_sink_cell(cell)
	var to: int = State.BLANK if _erase else brush
	if state.mark_at(cell) == to:
		return
	_pending.append({"cell": cell, "to": to})

func _release() -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var pending := _pending
	var now := _now()
	_clear_gesture()
	if cell.x < 0 or is_done():
		_end_sinks(now)
		_refresh()
		return
	if not pending.is_empty():
		var before: Dictionary = state.marks.duplicate()
		var changed: Array = state.apply(pending)
		# One stroke is one move, however many cells it painted, which is
		# what makes a painted run come back on a single Undo. A sweep lays
		# its pieces in a wave along the finger's path and puffs none; a
		# single tap puffs and leans the neighbours.
		var arrivals := _commit(before, changed, now,
			Motion.ENTER_STAGGER if was_drag else 0.0, Vector2i(-1, -1) if was_drag else cell)
		_end_sinks(now, arrivals)
		return
	_end_sinks(now)
	# Nothing changed: a hint has grouted the cell in.
	if state.locked.has(cell):
		_refuse(cell)
	_refresh()

## Puts the cells `changed` by a move on the floor (see _transition), puffs
## and leans the neighbours when the move was one tap on `tapped`, and counts
## the move. Returns each cell's arrival time.
func _commit(before: Dictionary, changed: Array, t: float, per: float, tapped: Vector2i) -> Dictionary:
	if changed.is_empty():
		_refresh()
		return {}
	var arrivals := _transition(before, changed, t, per)
	if tapped.x >= 0:
		var mark := state.mark_at(tapped)
		if mark != State.BLANK:
			fx.puff(cell_to_local(tapped.y, tapped.x),
				Pal.MOSAIC if mark == State.FILL else Pal.SOCKET_PEBBLE)
			_nudge_around(tapped, t)
	fx.cue("place")
	_speak()
	_refresh()
	note_move()
	return arrivals

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_dragged = false
	_axis = 0
	_erase = false
	_painted = {}
	_pending = []
	_last_paint = Vector2i(-1, -1)
	_badge_at = -1.0
	_badge_n = 0

## The tray armed a chip.
func set_brush(v: int) -> void:
	brush = v

# --- the sprout's line ---

## What the tip card says: the rules while the floor is bare, then the lines
## that are over-filled, then how many tiles are still to lay. And because the
## picture is the answer, a grid can have every line reading correctly and
## still be wrong -- which it says in those words rather than pretending the
## board is finished.
func _speak() -> void:
	if is_done():
		return
	var over: int = state.over_lines()
	if over > 0:
		_say(tr("NG_OVER_ONE") if over == 1 else tr("NG_OVER_N") % over,
			Face.Expr.STRAIN)
		return
	var settled: int = state.settled_lines()
	var lines: int = state.w + state.h
	if settled == lines:
		_say(tr("NG_LINES_OK"),
			Face.Expr.STRAIN)
		return
	var left: int = state.tiles_left()
	if left > 0:
		_say((tr("NG_LEFT_ONE") if left == 1 else tr("NG_LEFT_N")) % left,
			Face.Expr.HAPPY)
		return
	_say(tr("NG_DISAGREE") % (lines - settled),
		Face.Expr.HAPPY)

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
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Takes back the last stroke, however many cells it painted, in the wave it
## was laid in: the reverse of Place. Counts no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var now := _now()
	_end_sinks(now)
	_clear_gesture()
	var before: Dictionary = state.marks.duplicate()
	var touched: Array = state.undo()
	_transition(before, touched, now, Motion.ENTER_STAGGER)
	_speak()
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Lays one tile the picture wants and grouts it in for good: the first cell
## in reading order the player has not filled. It drops in from above under a
## ring with a sparkle; a pebble there pops out first. Counts no move but can
## finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var now := _now()
	_end_sinks(now)
	_clear_gesture()
	var before: Dictionary = state.marks.duplicate()
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	hints_used += 1
	_transition(before, [target], now, 0.0, true)
	var at := cell_to_local(target.y, target.x)
	fx.ring(at, _cell * RING_R, Pal.MOSAIC_LOCK)
	fx.sparkle(at, Pal.MOSAIC_LOCK)
	fx.cue("hint")
	_say(tr("NG_HINT"),
		Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	check_solved()
	return true

## Every tile the picture does not want wobbles and blushes toward the
## family's rose, and the sprout says how many. Crosses are left alone: a
## cross is a note, not a claim, so Check looks only at tiles.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var t := _now()
	var wrong: Array = state.wrong_tiles()
	if not Motion.reduce and not wrong.is_empty():
		for cell in wrong:
			_wrong[cell] = t
		_busy_for(maxf(Motion.WOBBLE_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
	_say((tr("NG_WRONG_ONE") if wrong.size() == 1 else tr("NG_WRONG_N")) % wrong.size()
		if not wrong.is_empty() else tr("NG_ALL_RIGHT"),
		Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_refresh()
	return wrong.size()

## Every tile and pebble goes, in a wave from the far corner, the clue
## numbers hopping as the floor clears under them. The hints spent are not
## refunded, only unpinned.
func reset_board() -> void:
	var now := _now()
	_end_sinks(now)
	_clear_gesture()
	var before: Dictionary = state.marks.duplicate()
	var held: Dictionary = state.locked.duplicate()
	var last := now
	for cell in state.reset():
		var at: float = now + _reset_wave(cell)
		last = maxf(last, at)
		_leave(cell, int(before[cell]), at, held.has(cell))
		if int(before[cell]) == State.FILL:
			_recount(cell, at)
	if not Motion.reduce:
		for y in state.h:
			_clue_hop["r%d" % y] = {"at": now + _reset_wave(Vector2i(-1, y)),
				"height": Motion.RESET_HOP, "time": Motion.HOP_TIME}
		for x in state.w:
			_clue_hop["c%d" % x] = {"at": now + _reset_wave(Vector2i(x, -1)),
				"height": Motion.RESET_HOP, "time": Motion.HOP_TIME}
		_busy_for(_reset_wave(Vector2i(-1, -1)) + Motion.HOP_TIME)
	_arrive = {}
	_hop = {}
	_nudge = {}
	_wrong = {}
	_shiver = {}
	_glint = {}
	_verdicts(now, {})
	moves = 0
	_running = true
	_say(tr("NG_RESET"),
		Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

## A completed daily is rebuilt from its seed with an empty floor. Lay every
## tile of the picture and settle the board as a finished solve leaves it: the
## scaffolding gone, no pebbles, every clue in its satisfied ink, nothing
## popping in or hopping. `solved` is not emitted a second time.
func restore_completed_board() -> void:
	var t := _now()
	_gen += 1
	_clear_gesture()
	_tip_timer.stop()
	state.marks = {}
	state.locked = {}
	for y in state.h:
		for x in state.w:
			if int(state.bitmap[y][x]) == 1:
				state.marks[Vector2i(x, y)] = State.FILL
	state.history = []
	_arrive = {}
	_leaving = []
	_sunk = {}
	_hop = {}
	_nudge = {}
	_wrong = {}
	_shiver = {}
	_clue_bump = {}
	_clue_hop = {}
	_glint = {}
	_focus_cell = Vector2i(-1, -1)
	_seed_verdicts()
	_opened = t - 10.0
	_solved_at = t - 10.0
	_anim_until = 0.0
	_say(tr("NG_SOLVED"), Face.Expr.JOY)
	_refresh()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The board *is* the reward here, more than on any other screen, so the
## reveal is the win: the win screen shows no cast, and what stays on the card
## under it is the picture as a single shape.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("NG_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The tiles hop in the family's wave along the diagonal; then the crosses
## clear, the sockets fade back to parchment and the grout lines close up. The
## scaffolding leaves and the picture is left standing on the card.
func _on_solved() -> void:
	var now := _now()
	_end_sinks(now)
	_clear_gesture()
	_tip_timer.stop()
	_solved_at = now
	_wrong = {}
	_shiver = {}
	if not Motion.reduce:
		for y in state.h:
			for x in state.w:
				if int(state.bitmap[y][x]) == 1:
					var cell := Vector2i(x, y)
					_hop[cell] = {"at": now + _solve_delay(cell), "height": Motion.SOLVE_HOP,
						"time": Motion.SOLVE_TIME}
	_say(tr("NG_SOLVED"), Face.Expr.JOY)
	fx.cue("solved")
	_busy_for(maxf(_solve_delay(Vector2i(state.w, state.h)) + Motion.SOLVE_TIME,
		maxf(GONE_DELAY + GONE_TIME, CLEAR_DELAY + CLEAR_SPREAD + CLEAR_TIME)))
	_busy_for(WIN_GLINT_AT + (state.w + state.h) * WIN_GLINT_STEP + WIN_GLINT_TIME)
	_refresh()

# --- the stroke's count ---

## While a stroke is being dragged, a pill over the finger says how long the
## run is: counting cells is what every deduction on this board comes down
## to, and a finger covers the cells it is counting. It pops in at two cells
## and bumps each time the run grows or shrinks. Two draw commands, and only
## while a finger is dragging.
func _draw_badge() -> void:
	if not _dragged or _badge_at < 0.0 or _badge_n < 2 or _focus_cell.x < 0:
		return
	var t := _now()
	var grow := Motion.pop_in_scale(t - _badge_at) * Motion.bump_scale(t - _badge_bump)
	if grow.x <= 0.0:
		return
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell * BADGE_SIZE))
	var text := str(_badge_n)
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var box := Vector2(maxf(wide + _cell * 0.3, _cell * BADGE_H), _cell * BADGE_H)
	var b := Face.Builder.new()
	Scenery.soft_disc(b, Vector2(0.0, box.y * 0.5), box.x * 0.6, box.y * 0.3,
		Color(Pal.TEXT, 0.18))
	b.fan(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.TEXT)
	_badge_shown = b.mesh()
	# Beside the stroke, toward the floor's inside: never over a band, where it
	# would cover the very clue the run is being counted against.
	var off := Vector2(0.0, -1.0 if _focus_cell.y > 0 else 1.0) if _axis == 1 \
		else Vector2(-1.0 if _focus_cell.x > 0 else 1.0, 0.0)
	var centre := cell_to_local(_focus_cell.y, _focus_cell.x) + off * _cell * BADGE_OFF
	draw_set_transform(centre, 0.0, grow)
	draw_mesh(_badge_shown, null)
	draw_string(font, Vector2(-wide * 0.5, font.get_ascent(px) * 0.5 - 1.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Pal.PAPER)
	draw_set_transform(Vector2.ZERO)

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

## A tile's tone, -1 to 1 off the cell's hash, so the floor reads as laid by
## hand and every tile keeps its own shade from one day to the next.
static func _tone(cell: Vector2i) -> float:
	return _hash(cell + Vector2i(17, 31)) * 2.0 - 1.0

## A fixed pseudo-random number per cell, so the crosses clear away in a
## scatter rather than a wave.
static func _hash(cell: Vector2i) -> float:
	return float(posmod(hash(cell), 1000)) / 1000.0
