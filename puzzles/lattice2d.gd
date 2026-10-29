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
##
## The garden wall is the whole screen (the registry's `bleed`):
## puzzles/lattice_world.gd lies edge to edge as the board's first child from
## the first `set_clear`, and the lattice is laid in the span the host's rows
## leave, its slats on the host's margin under the pill's strip, with no
## card behind it. On the win the board slides and shrinks into the win's
## span under its own one transform, the world held still against it. A
## board never told a clear (the tutorial's, one in a card) is laid and
## drawn in its card as before.

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
const World = preload("res://puzzles/lattice_world.gd")
const FLAT_HOST := "res://ui/flat/flat_host.gd"
const ToastCard = preload("res://ui/flat/toast_card.gd")
const StarLine = preload("res://ui/flat/star_line.gd")
## The slide into the win's span (the host's SLOT_TIME), and the air kept
## round the block inside it.
const WIN_SLIDE := 0.45
const WIN_PAD := 28.0
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
const TOAST_MARGIN := 24.0

## Made fun (2026-10-29). Stars by slips (a swap that sent nothing home, a
## bulb read): three at none, two up to two, one past that. A run of swaps
## that each send a tile home climbs the home cue a step a swap, and says so
## every third. The guide over a picked tile: a tile its number cannot go to
## is veiled, one that can only take that number is rimmed in sun.
const STARS_CUT := [0, 2]
const RUN_PITCH := 0.035
const RUN_PITCH_MAX := 1.3
const RUN_SAY := 3
const VEIL_ALPHA := 0.62
const RIM_W := 0.07
const TOAST_FS := 30
const TOAST_PAD_IN := Vector2(26.0, 16.0)

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
## The world, once the host has said what its rows cover (set_clear), and
## what they cover, top and bottom, while playing.
var _world: Control
var _bled := false
var _clear := Vector2.ZERO
## The board's own transform on the win: the block's middle while playing,
## how far it moves and how small it gets, and how far along it is.
var _slid_from := Vector2.ZERO
var _slid_by := Vector2.ZERO
var _slid_scale := 1.0
var _slid := 0.0
var _won := false
var _win_clear := Vector2.ZERO
var _placed := false
## The host's slide on a change of level (set_shift).
var _shift := 0.0
var _slide_tw: Tween
var _no_entrance := false
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
var _toast_high := false
var _tip_idx := 0
var _tip_timer: Timer
var _final_swaps := 0
var _final_left := 0

# --- made fun ---
var _card_toast := ToastCard.new()
var _stars := StarLine.new()
var _slips := 0
var _run := 0
var _best_run := 0
## The bulb's first press: State.read()'s reading, until a move puts it out.
var _reading: Dictionary = {}
## The guide over the tile picked or held: cell -> 0 its number cannot go
## there, 2 only its number can; the number it was made for.
var _guide: Dictionary = {}
var _guide_for := -1
var _guide_mesh: ArrayMesh
var _rim_mesh: ArrayMesh
## Squares rimmed rose: a tile set where the rules say its number cannot go.
var _wrong_at: Array = []

func puzzle_id() -> String: return "lattice"
func title() -> String: return "Lattice"

func rules() -> String:
	var out := tr("LA_RULES") % state.n
	out += "\n\n" + tr("LA_RULES_KNOTS")
	out += "\n\n" + tr("LA_RULES_GUIDE")
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
## Insane has the bulb again since 2026-10-13, as many hints as Hard: what is
## said of it above is the history (docs/agents/flat-screens.md).
func capabilities() -> Array[String]:
	if state.band >= 3:
		return ["hint"]
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

## The day as dealt, for tools/export_days.gd (PuzzleBase.day_dict): the
## tiles on their squares, a knot's sum in its hole with the ways it points.
## The deal is the bank's when the bank is there (State.setup).
func day_dict() -> Dictionary:
	if state.n == 0:
		return {}
	var n: int = state.n
	var arrows := {"L": "←", "U": "↑", "R": "→", "D": "↓"}
	var puzzle: Array = []
	var answer: Array = []
	for i in n * n:
		puzzle.append({"wall": true})
		answer.append({"wall": true})
	var home := 0
	for i in state.count():
		var c: Vector2i = state.cells[i]
		var is_home: bool = state.start[i] == state.sol[i]
		if is_home:
			home += 1
		puzzle[c.y * n + c.x] = {"t": str(state.start[i]), "given": is_home}
		answer[c.y * n + c.x] = {"t": str(state.sol[i]), "given": is_home}
	var knots: Array = []
	for k: Dictionary in state.knots:
		var at: Vector2i = k.at
		var ways := ""
		for d in String(k.dirs):
			ways += String(arrows[d])
		knots.append([at.x, at.y, String(k.dirs), int(k.sum)])
		puzzle[at.y * n + at.x] = {"t": str(int(k.sum)), "note": ways}
		answer[at.y * n + at.x] = {"t": str(int(k.sum)), "note": ways}
	var banked: bool = not State.pool(state.band).is_empty()
	return {
		"source": "bank" if banked else "generator", "kind": "grid",
		"payload": {"n": n, "tiles": Array(state.start), "knots": knots},
		"solution": {"tiles": Array(state.sol)},
		"metrics": {"size": n, "tiles": state.count(), "knots": knots.size(), "par": state.par,
			"home": home, "astray": state.count() - home, "unique": banked,
			"hints": State.hints_for(state.band), "moves": state.moves_budget()},
		"view": {"w": n, "h": n, "puzzle": puzzle, "solution": answer},
	}

## The lattice as `state` has it, from the top: Insane's swaps, nothing in
## the air, the entrance.
func _begin() -> void:
	max_moves = state.moves_budget()
	_heart_used = false
	_slips = 0
	_best_run = 0
	_stars.clear(3)
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
	_card_toast.clear()
	_reading = {}
	_guide = {}
	_guide_for = -1
	_wrong_at = []
	_rim_mesh = null
	_run = 0
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
	if _bled:
		_world.size = size
		_place()
		# The slats' ends on the host's margin, the pill's strip over them,
		# at the top of the span; what is left is open garden under it.
		var span := size.y - _clear.x - _clear.y
		var wide := size.x - 2.0 * _side()
		_cell = minf(wide, span - HUD_ROW) / state.n
		if _cell <= 0.0:
			return
		var g: float = _cell * state.n
		_card = Rect2((size.x - g) * 0.5, _clear.x, g, HUD_ROW + g)
		_grid = _card.position + Vector2(0.0, HUD_ROW)
		_world.set_foot(_card.end.y)
		if _won:
			# Laid out under a win (a resize, or a day reopened solved): the
			# slide is aimed again, and set at its end if it never ran.
			_aim()
			if _slid <= 0.0 and not (_slide_tw != null and _slide_tw.is_valid()):
				_slid = 1.0
			_place()
	else:
		_cell = _cell_for(size.y)
		if _cell <= 0.0:
			return
		var side: float = _cell * state.n
		var tall := minf(size.y, side + 2.0 * PAD + HUD_ROW)
		_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
		_grid = Vector2(size.x * 0.5 - side * 0.5, _card.position.y + HUD_ROW + (tall - HUD_ROW - side) * 0.5)
	_flat_cache = {}
	_units = Art.units(_cell)
	_guide_mesh = null
	_rim_mesh = null
	_still = _build_still()
	_seal_mesh = null
	_knots_dirty = true
	_live_dirty = true
	_hud_layer.queue_redraw()
	queue_redraw()

## What the host's rows cover, in this board's own pixels (it is laid full
## rect). The first call makes the world. While playing the lattice is laid
## in what is left; on the win it is not laid out again: the board slides
## and shrinks into the win's span.
func set_clear(top: float, bottom: float, won := false) -> void:
	Motion.stop(_slide_tw)
	if not _bled:
		_bled = true
		_world = World.new()
		_world.name = "World"
		_world.show_behind_parent = true
		add_child(_world)
		move_child(_world, 0)
		if won:
			_clear = Vector2(top, bottom)
	_won = won
	if not won:
		_clear = Vector2(top, bottom)
		_slid = 0.0
		_layout()
		return
	_win_clear = Vector2(top, bottom)
	# A day reopened solved is told before it has been laid out: _layout
	# sets the slide when it has a lattice to aim.
	if _cell <= 0.0:
		_layout()
		return
	_aim()
	if Motion.reduce or not is_inside_tree() or _slid >= 1.0:
		_slide(1.0)
		return
	_slide_tw = create_tween()
	_slide_tw.tween_method(_slide, _slid, 1.0, WIN_SLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Where the win's slide ends, from the block as it is laid (the pill's
## strip and the lattice) and the win's span.
func _aim() -> void:
	var span := size.y - _win_clear.x - _win_clear.y
	_slid_from = _card.get_center()
	_slid_scale = clampf(minf((size.x - 2.0 * _side() - 2.0 * WIN_PAD) / _card.size.x,
		(span - 2.0 * WIN_PAD) / _card.size.y), 0.1, 1.0)
	_slid_by = Vector2(size.x * 0.5, _win_clear.x + span * 0.5) - _slid_from

## The host's side margin, which the lattice keeps although the world does
## not.
func _side() -> float:
	return float(load(FLAT_HOST).MARGIN)

func _slide(t: float) -> void:
	_slid = t
	_place()

## The host slides the board `x` aside on a change of level; the world stays
## where it is, and the board that is leaving shows none, so the one
## arriving under it is not hidden.
func set_shift(x: float, leaving := false) -> void:
	_shift = x
	if _world != null:
		_world.visible = not leaving
	_place()

## The host deals this board into a screen already standing: it arrives
## whole, without the lattice's pop or the tiles' entrance.
func skip_entrance() -> void:
	_no_entrance = true
	_opened = -1.0e9
	_redraw()
	_hud_layer.queue_redraw()

## The board's transform at `_slid`, and the world's against it, so the
## world stays where it is while the lattice and everything on it goes.
func _place() -> void:
	if _world == null:
		return
	if _slid <= 0.0 and _shift == 0.0 and not _placed:
		return
	_placed = _slid > 0.0 or _shift != 0.0
	var k := lerpf(1.0, _slid_scale, _slid)
	var by := _slid_by * _slid + Vector2(_shift, 0.0)
	pivot_offset = _slid_from
	scale = Vector2(k, k)
	position = by
	_world.pivot_offset = _slid_from
	_world.scale = Vector2.ONE / k
	_world.position = -by / k

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
	# The card, where the board stands in one; in a world of its own the
	# lattice stands straight on the garden wall.
	if not _bled:
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
	_draw_guide(shown)
	if _top != null:
		draw_mesh(_top, null)
		shown.append(_top)
	_draw_ink(_top_ink)
	_draw_rims(shown)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_shown = shown

## Made fun: the guide over the tile picked or held. Every other plain tile
## its number cannot go to by the rules is veiled; one whose square only that
## number fits is rimmed in sun. Read from the rules, never the answer; one
## mesh, made when the tile is picked.
func _draw_guide(shown: Array) -> void:
	var src := _held if _held >= 0 else _picked
	if src < 0 or is_done() or state.is_home(src):
		_guide_for = -1
		return
	var key := src * 1000 + int(state.cur[src]) * 100 + state.homes()
	if _guide_for != key or _guide_mesh == null:
		_guide_for = key
		var v := int(state.cur[src])
		var b := Face.Builder.new()
		var s := _cell * Art.TILE
		for j in state.count():
			if j == src or state.is_home(j):
				continue
			var c: PackedInt32Array = state.candidates(j)
			var at := cell_centre(j) - Vector2.ONE * s * 0.5 - Vector2(0.0, _cell * Art.FACE_RISE)
			var box := Face.Builder.round_rect(at, Vector2.ONE * s, _cell * Art.TILE_RADIUS)
			if not c.has(v):
				b.fan(box, Color(Pal.SURFACE, VEIL_ALPHA))
			elif c.size() == 1:
				b.stroke(box, _cell * RIM_W, Pal.SUN, true)
		_guide_mesh = b.mesh()
	draw_mesh(_guide_mesh, null)
	shown.append(_guide_mesh)

## Made fun: the reading's rims (the square in sun, thick; the tile to bring
## in sun; the line or the knot that decided it, fine) and a rose rim on a
## square holding a number the rules say cannot be there.
func _draw_rims(shown: Array) -> void:
	if is_done() or (_reading.is_empty() and _wrong_at.is_empty()):
		return
	if _rim_mesh == null:
		var b := Face.Builder.new()
		var s := _cell * (Art.TILE + 0.08)
		if not _reading.is_empty():
			var line := int(_reading.line)
			if line >= 0:
				for j: int in state.lines[line]:
					b.stroke(_box(j, s), _cell * RIM_W * 0.5, Color(Pal.SUN, 0.7), true)
			var knot := int(_reading.knot)
			if knot >= 0:
				var at: Vector2 = _square_centre(state.knots[knot].at)
				b.stroke(Face.Builder.ring(at, _cell * 0.4, _cell * 0.4), _cell * RIM_W, Pal.SUN, true)
				for j: int in state.knots[knot].cells:
					b.stroke(_box(j, s), _cell * RIM_W * 0.5, Color(Pal.SUN, 0.7), true)
			if int(_reading.cell) >= 0:
				b.stroke(_box(int(_reading.cell), s + _cell * 0.04), _cell * RIM_W * 1.6, Pal.SUN, true)
			if int(_reading.tile) >= 0:
				b.stroke(_box(int(_reading.tile), s), _cell * RIM_W, Pal.SUN, true)
		for j: int in _wrong_at:
			b.stroke(_box(j, s), _cell * RIM_W * 1.2, Pal.BAD, true)
		_rim_mesh = b.mesh()
	draw_mesh(_rim_mesh, null)
	shown.append(_rim_mesh)

func _box(j: int, s: float) -> PackedVector2Array:
	var at := cell_centre(j) - Vector2.ONE * s * 0.5 - Vector2(0.0, _cell * Art.FACE_RISE)
	return Face.Builder.round_rect(at, Vector2.ONE * s, _cell * (Art.TILE_RADIUS + 0.03))

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
	if not is_done() and not _won:
		# made fun: the live stars, on the strip's left over the lattice
		_stars.draw(_hud_layer, Vector2(_card.position.x + StarLine.R, _card.position.y + HUD_ROW * 0.5 + 6.0), 1.0, now, alpha)
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

## The toast (the shared paper card, ui/flat/toast_card.gd since the made-fun
## pass): in the open garden under the lattice when there is room, else over
## the lattice's foot, or its head when what it is about is down there.
func _draw_toast(now: float) -> void:
	if not _card_toast.showing(now):
		return
	var field := _field_px()
	var wide := minf(size.x - 2.0 * _side(), maxf(field.size.x, 560.0))
	var tall: float = _card_toast.tall(wide, TOAST_FS, TOAST_PAD_IN)
	var mid := Vector2(size.x * 0.5, field.end.y + TOAST_MARGIN + tall * 0.5)
	var room := size.y - _clear.y - field.end.y if _bled else size.y - field.end.y
	if room < tall + 2.0 * TOAST_MARGIN:
		mid.y = field.end.y - TOAST_MARGIN - tall * 0.5
		if _toast_high:
			mid.y = field.position.y + TOAST_MARGIN + tall * 0.5
	_card_toast.draw(_hud_layer, mid, wide, now, TOAST_FS, TOAST_PAD_IN)

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
func _swap(a: int, b: int, from: Vector2, by_hint := false) -> bool:
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
	if not by_hint:
		_drop_reading()
	var now := _now()
	_fly(b, from, SWAP_TIME)
	_fly(a, cell_centre(b), SWAP_TIME)
	var land := now + (0.0 if Motion.reduce else SWAP_TIME)
	_home_at[a] = land
	_home_at[b] = land
	fx.cue("swap", randf_range(TICK_VARY.x, TICK_VARY.y))
	_bump_pill()
	_after(land - now, _landed.bind(a, b, false, by_hint))
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
func _landed(a: int, b: int, quiet := false, by_hint := false) -> void:
	var sent := 0
	for i: int in [a, b]:
		if state.is_home(i):
			sent += 1
			fx.ring(cell_centre(i), _cell * 0.55, Pal.LEAF)
	if not quiet and not is_done():
		if sent == 0:
			fx.cue("miss", randf_range(TICK_VARY.x, TICK_VARY.y))
		else:
			# a run climbs the home cue a step a swap
			var up := minf(1.0 + RUN_PITCH * _run, RUN_PITCH_MAX)
			fx.cue("home2" if sent == 2 else "home", up * randf_range(0.98, 1.02))
	if not quiet:
		_judge_swap(a, b, sent, by_hint)
	_settle(quiet)
	_knots_dirty = true
	_busy_for(Motion.BUMP_TIME)
	_redraw()

## Made fun: what a swap came to, past its sound. Nothing home is a slip (a
## clean solve sends one or two home every swap) and ends the run; a tile set
## where the rules say its number cannot go is rimmed rose and the toast
## says why; a run of swaps sending tiles home says so every third.
func _judge_swap(a: int, b: int, sent: int, by_hint: bool) -> void:
	var kept: Array = []
	for i: int in _wrong_at:
		if i != a and i != b and not state.is_home(i) and not state.candidates(i).has(int(state.cur[i])):
			kept.append(i)
	_wrong_at = kept
	var why := ""
	for i: int in [b, a]:
		if state.is_home(i) or state.candidates(i).has(int(state.cur[i])):
			continue
		_wrong_at.append(i)
		if why == "":
			why = _why_not(i)
	_rim_mesh = null
	if sent == 0:
		_run = 0
		_slips += 1
		_rate(true)
	else:
		_run += 1
		_best_run = maxi(_best_run, _run)
	if is_done():
		return
	var near := a if why != "" else b
	if why != "":
		_tell(why, Face.Expr.PUZZLED, _wrong_at[-1])
	elif sent == 2 and not Motion.reduce:
		fx.sparkle(cell_centre(a), Pal.SUN)
		fx.sparkle(cell_centre(b), Pal.SUN)
	if sent > 0 and _run >= RUN_SAY and _run % RUN_SAY == 0:
		_tell(tr("LA_RUN") % _run, Face.Expr.JOY, near)
		for i: int in [a, b]:
			fx.sparkle(cell_centre(i), Pal.SUN)

## Why the number on `i` cannot be there, by the rules: a whole line it
## stands in has that number home already, or a knot cannot make its sum.
func _why_not(i: int) -> String:
	var v := int(state.cur[i])
	var rows: int = (state.n + 1) / 2
	for l: int in state.lines_of(i):
		for j: int in state.lines[l]:
			if j != i and state.is_home(j) and int(state.cur[j]) == v:
				return tr("LA_NOT_ROW" if l < rows else "LA_NOT_COL") % v
	for k in state.knots.size():
		if (state.knots[k].cells as PackedInt32Array).has(i) and not state._knot_allows(i, v):
			return tr("LA_NOT_KNOT") % [int(state.knots[k].sum), v]
	return tr("LA_NOT_GONE") % v

## The stars the day's slips leave; `heard`: a lost one falls.
func _rate(heard: bool) -> void:
	var w := _slips
	_stars.rate(3 if w <= int(STARS_CUT[0]) else (2 if w <= int(STARS_CUT[1]) else 1), _now(), heard)
	_hud_layer.queue_redraw()

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
	_card_toast.say(text, _now())
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
	_drop_reading()
	_run = 0
	_wrong_at = []
	_rim_mesh = null
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
	return _hints_held() + (0 if _reading.is_empty() else 1)

func _hints_held() -> int:
	return maxi(0, State.hints_for(state.band) + hints_extra - hints_used)

## Made fun (2026-10-29): the bulb teaches, in two presses. The first reads
## the lattice the way a player can (State.read: a line's last square, a knot
## with its other tiles home, a square only one number fits, a number only
## one square of a line takes): it rims the square in sun, the line or the
## knot that decided it, and the tile to bring, and the toast says why, for
## one hint. The player may make the swap themselves; a second press while
## the reading stands makes it, free.
func hint() -> bool:
	if is_done() or out_of_hearts:
		return false
	if not _reading.is_empty():
		var pair: Array = _reading.pair
		_drop_reading()
		_picked = -1
		_held = -1
		for i: int in pair:
			fx.ring(cell_centre(i), _cell * 0.5, Pal.SUN)
			fx.sparkle(cell_centre(i), Pal.LEAF)
		fx.cue("hint")
		var made := _swap(pair[0], pair[1], cell_centre(pair[0]), true)
		_redraw()
		moved.emit()
		return made
	if _hints_held() <= 0:
		return false
	var got: Dictionary = state.read()
	if got.is_empty() or int(got.tile) < 0:
		return false
	hints_used += 1
	_picked = -1
	_held = -1
	_reading = got
	_rim_mesh = null
	var at := int(got.cell) if int(got.cell) >= 0 else int(got.tile)
	fx.ring(cell_centre(at), _cell * 0.55, Pal.SUN)
	fx.cue("hint")
	_tell(_why(got) + " " + tr("LA_READ_AGAIN"), Face.Expr.HAPPY, at)
	_card_toast.hold = true
	_slips += 1
	_rate(true)
	_redraw()
	moved.emit()
	return true

## What the reading says.
func _why(got: Dictionary) -> String:
	var v := int(got.value)
	var rows: int = (state.n + 1) / 2
	var row: bool = int(got.line) >= 0 and int(got.line) < rows
	match int(got.why):
		State.WHY_LAST:
			return tr("LA_WHY_LAST_ROW" if row else "LA_WHY_LAST_COL") % v
		State.WHY_KNOT:
			var k: Dictionary = state.knots[int(got.knot)]
			return tr("LA_WHY_KNOT") % [int(k.sum), v]
		State.WHY_ONLY:
			return tr("LA_WHY_ONLY") % v
		State.WHY_HIDDEN:
			return tr("LA_WHY_HIDDEN_ROW" if row else "LA_WHY_HIDDEN_COL") % v
	return tr("LA_WHY_PAIR")

## The reading goes out (a swap by hand, Undo, Reset, its own second press),
## and its toast with it.
func _drop_reading() -> void:
	if _reading.is_empty():
		return
	_reading = {}
	_rim_mesh = null
	if _card_toast.hold:
		_card_toast.clear()
	_hud_layer.queue_redraw()
	queue_redraw()

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

## The win's brain report: the fewest swaps against the swaps made (spec 2026-10-22-brain-skills, section 6).
func skill_quality() -> float:
	var par := int(state.par)
	if par <= 0:
		return -1.0
	return clampf(float(par) / float(maxi(state.swaps, par)), 0.0, 1.0)

func completion_record() -> Dictionary:
	return {"swaps": state.swaps, "left": moves_left, "slips": _slips, "run": _best_run}

## A completed daily is rebuilt from its seed, so the lattice opens
## scrambled: every tile goes home and the swaps it took are put back.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	_tip_timer.stop()
	state.finish(int(completed_record.get("swaps", state.par)))
	_deal()
	moves_left = int(completed_record.get("left", 0))
	_slips = int(completed_record.get("slips", 0))
	_best_run = int(completed_record.get("run", 0))
	_rate(false)
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
	if _best_run >= RUN_SAY:
		sub += " " + tr("LA_WIN_RUN") % _best_run
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
	_card_toast.clear()
	_reading = {}
	_guide = {}
	_wrong_at = []
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
	_slips = 0
	_best_run = 0
	_stars.clear(3)
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
	if _no_entrance:
		return
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
			or _card_toast.showing(now) or _stars.busy(now):
		_hud_layer.queue_redraw()

func _redraw() -> void:
	_live_dirty = true
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
