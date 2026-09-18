extends "res://core/puzzle_base.gd"

## Light Up as a flat board: a court of flagstones on the host's parchment
## card, rough blocks of stone standing in it with their numbers carved on
## their crowns, a paper lantern on every stone the player lights, and a slate
## chip on every stone they have ruled out. Built beside the island version
## (puzzles/lightup3d.gd) so the two can be judged against each other on the
## phone; the rules live in puzzles/lightup_state.gd, which this only draws.
##
## What flat buys here is the floor. Light Up has no marker for its main
## condition: a stone no lamp reaches is a cold grey, a lit one is warm, and
## that is the whole of "every stone must be lit" -- so the thing the player
## reads is a field of up to forty-nine flat tints. On the island that field
## is seen at seven degrees, where the far rows are a few pixels tall,
## foreshortened, and half in the shade of the blocks standing in front of
## them: precisely the information you look at most, rendered worst. Flat,
## every stone is the same size and the same tint wherever it sits. **And it
## buys the beam** -- the shaft of light itself, drawn down the row and the
## column cell by cell as it travels, which is the rule made into a picture
## and the one thing on this screen the island cannot do at all.
##
## How it is drawn. The whole court is **one** mesh, rebuilt only while
## something moves: the mortar bed, a flagstone per cell carrying its own
## warmth, the beams over them, the shade under a running sweep, the blocks
## and the chips. The numbers are drawn over it with one draw_string each,
## because a digit in a mesh cache key would multiply every block state by
## five. Only the lamps are Controls, with the face family's own cached meshes
## behind them (ui/faces/court_lantern.gd).
## Spec: docs/superpowers/specs/2026-09-18-lightup-flat-design.md, sections 2
## to 7, and the mock it is ported from
## (docs/brainstorm/concepts.html#lightup).

const State = preload("res://puzzles/lightup_state.gd")
const Gen = preload("res://puzzles/lightup_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const CourtLantern = preload("res://ui/faces/court_lantern.gd")
const CozyTheme = preload("res://ui/theme.gd")

# --- the court ---
const PAD := 34.0
## The mortar bed the stones are set into: a hair of shade outside the grid,
## which is what keeps a court of pale tints from floating on the parchment.
const MORTAR := 6.0
const MORTAR_RADIUS := 20.0
const MORTAR_ALPHA := 0.07
## The joint between two stones, the corner they are cut with and the soft lip
## along the bottom of each, all in cells.
const GAP := 0.035
const STONE_RADIUS := 0.13
const STONE_EDGE := 0.05
## The beam: how wide it runs down a line, how strong it is on the stone next
## to the lamp, and how it thins per cell travelled.
const BEAM_HALF := 0.19
const BEAM_ALPHA := 0.45
const BEAM_FALL := 0.22
## Below this there is no light on the stone worth drawing.
const BEAM_MIN := 0.02
const SWEEP_ALPHA := 0.07

# --- the pieces, in cells ---
const BLOCK_SIZE := 0.94
const CHIP_SIZE := 0.9
## The lamp's seat. The mock draws it at R = 0.38 of a cell and the lantern's
## drawing is SEAT (2.4) R tall, so this is the seat that gives it that R.
const LAMP_SIZE := 0.38 * CourtLantern.SEAT
const NUM_SIZE := 0.4

# --- motion ---
## A stone warms over LIGHT_IN and cools over LIGHT_OUT, and waits LIGHT_STEP
## per cell of beam it is away from the lamp that changed, capped at
## LIGHT_CAP. This is what makes the light read as travelling out rather than
## switching on along the whole line at once, and it is the island's own
## quartet.
const LIGHT_IN := 0.22
const LIGHT_OUT := 0.3
const LIGHT_STEP := 0.035
const LIGHT_CAP := 0.25
const POP_FROM := 0.6
const POP_TIME := 0.22
const DIP := 0.05
const DIP_TIME := 0.3
const FLASH := 0.07
const FLASH_TIME := 0.6
const FLASH_SWINGS := 9.0
const ENTER_STONE := 0.12
const ENTER_STONE_STEP := 0.025
const ENTER_STONE_TIME := 0.4
const ENTER_BLOCK := 0.2
const ENTER_BLOCK_STEP := 0.03
const ENTER_BLOCK_TIME := 0.4
const ENTER_DROP := 24.0
const BLOCK_FROM := 0.7
const SOLVE_DELAY := 0.15
const SOLVE_STEP := 0.1
const SOLVE_HOP := 0.12
const SOLVE_HOP_TIME := 0.42
const SPARK_DELAY := 0.05
## The chips clear away on the win, so the last picture is the lit court
## rather than the working-out.
const CLEAR_DELAY := 0.2
const CLEAR_SPREAD := 0.3
const CLEAR_TIME := 0.5
const WIN_WAIT := 2.0

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
const TIPS := [
	"Light every floor stone. A lantern lights its row and column until a block stops it.",
	"No lantern may light another. Drag across the court to chip the stones you have ruled out.",
	"A number counts the lanterns touching that block. Half the blocks carry none.",
]

var state = State.new()
## The names the win harness and the island board share, so one driver solves
## both twins.
var w: int:
	get: return state.w
var h: int:
	get: return state.h
var _solution_bulbs: Array:
	get: return state.solution

var fx: Node2D
var _cell := 0.0
var _grid := Vector2.ZERO
var _card := Rect2()
var _lamps: Dictionary = {}      # Vector2i -> CourtLantern, kept once made
## Vector2i -> the second a piece went down on that stone, which drives its
## pop and, on the win, its hop.
var _at: Dictionary = {}
var _dip_at: Dictionary = {}
var _flash_at: Dictionary = {}
## Vector2i -> {"from", "to", "at", "dur"}: the warmth actually painted on a
## stone, which is what a retarget has to start from. Ask for a lamp and take
## it away again inside the fade and a single target would carry the stone all
## the way to lamplight and leave it there -- a lit floor with nothing
## lighting it.
var _warm: Dictionary = {}
## Sparks waiting to be thrown: [{"at": float, "pos": Vector2}].
var _sparks: Array = []

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
var _dragged := false
var _sweeping := false
var _lay := true
var _swept: Dictionary = {}
var _pending: Array = []
var _last_paint := Vector2i(-1, -1)

var _opened := 0.0
var _solved_at := -1.0
var _court: ArrayMesh
## The mesh the last _draw actually handed to the canvas item. A canvas
## command holds the mesh by RID and not by reference, so dropping the only
## reference to a mesh that is still on the item's command list leaves the
## renderer drawing a freed RID ("Parameter mesh is null", and nothing on the
## card). Keeping it here until the next _draw replaces it is what makes
## rebuilding the court safe.
var _shown: ArrayMesh
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "lightup"
func title() -> String: return "Light Up"

func rules() -> String:
	return "Light every floor stone. A lantern lights its row and column until a block stops it. No lantern may light another. Numbers count the lanterns touching a block."

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
	state.setup(rng, difficulty)
	_at = {}
	_dip_at = {}
	_flash_at = {}
	_sparks = []
	_clear_gesture()
	_solved_at = -1.0
	_opened = _now()
	_build_pieces()
	_settle()
	_layout()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("enter")

# --- the cast ---

## Only the lamps are nodes. The court, the blocks and the chips are drawn.
func _build_pieces() -> void:
	for cell in _lamps:
		_lamps[cell].queue_free()
	_lamps = {}

## The lamp on `cell`, made the first time one is set down there and kept
## afterwards: a stone the player taps twice would otherwise build and free a
## node with a mesh cache behind it on every tap.
func _lamp_node(cell: Vector2i) -> CourtLantern:
	if _lamps.has(cell):
		return _lamps[cell]
	var lamp := CourtLantern.new()
	lamp.name = "lamp_%d_%d" % [cell.x, cell.y]
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lamp)
	lamp.set_idle(true)
	_lamps[cell] = lamp
	return lamp

# --- layout ---

## The court is the largest grid the card holds, and the card is cut to the
## court and centred in the slot rather than pinned under the day card the way
## most of the flat boards are. This is the second board of the seven whose
## grid is square while its space is tall -- and here there is no count band
## to spend width on, so the cell is capped by the width at every step and
## there is slack however the card is cut.
func _layout() -> void:
	if state.grid.is_empty():
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var court := Vector2(_cell * state.w, _cell * state.h)
	var tall := minf(size.y, court.y + 2.0 * PAD)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - court.x * 0.5, _card.position.y + (tall - court.y) * 0.5)
	_refresh()

## The cell a slot of `available` height holds, capped by the width.
func _cell_for(available: float) -> float:
	if state.grid.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / state.w, (available - 2.0 * PAD) / state.h)

## The host cuts its card to the court and centres it, which is what these two
## say. A board that wants neither says nothing and fills the slot.
func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.h + 2.0 * PAD)

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
	return cell if state.in_field(cell) else Vector2i(-1, -1)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or state.grid.is_empty():
		return
	var t := _now()
	_throw_sparks(t)
	if _animating(t):
		_refresh()

## True while anything is still moving. A court left alone costs its lamps'
## own blinks, which are their tweens and not the board's frames.
func _animating(t: float) -> bool:
	if _sweeping or not _sparks.is_empty():
		return true
	if t < _opened + ENTER_BLOCK + (state.w + state.h) * ENTER_BLOCK_STEP + ENTER_BLOCK_TIME:
		return true
	if _solved_at >= 0.0 and t < _solved_at + WIN_WAIT:
		return true
	for cell in _warm:
		var rec: Dictionary = _warm[cell]
		if float(rec.from) != float(rec.to) and t < float(rec.at) + float(rec.dur):
			return true
	for cell in _at:
		if t < float(_at[cell]) + maxf(POP_TIME, SOLVE_HOP_TIME):
			return true
	for cell in _dip_at:
		if t < float(_dip_at[cell]) + DIP_TIME:
			return true
	for cell in _flash_at:
		if t < float(_flash_at[cell]) + FLASH_TIME:
			return true
	return false

func _refresh() -> void:
	var t := _now()
	_place_lamps(t)
	_court = _build_court(t)
	queue_redraw()

func _place_lamps(t: float) -> void:
	var seat := Vector2.ONE * (_cell * LAMP_SIZE)
	for cell in _lamps:
		var lamp: CourtLantern = _lamps[cell]
		var up: bool = state.mark_at(cell) == State.LAMP
		lamp.visible = up
		if not up:
			continue
		lamp.size = seat
		lamp.pivot_offset = seat * 0.5
		var grow := 1.0 if Motion.reduce else lerpf(POP_FROM, 1.0, _back_out(_pop_u(cell, t)))
		lamp.scale = Vector2.ONE * grow
		lamp.position = cell_to_local(cell.y, cell.x) - seat * 0.5 + _jitter(cell, t)
		lamp.lit = _warmth(cell, t)
		lamp.pinned = state.locked.has(cell)
		lamp.bad = not is_done() and state.clash.has(cell)
		if _solved_at >= 0.0 and t >= float(_at.get(cell, 0.0)):
			lamp.expression = Face.Expr.JOY
		elif lamp.bad:
			lamp.expression = Face.Expr.STRAIN
		else:
			lamp.expression = Face.Expr.HAPPY

func _pop_u(cell: Vector2i, t: float) -> float:
	return clampf((t - float(_at.get(cell, -100.0))) / POP_TIME, 0.0, 1.0)

## What a lamp is doing besides standing there: the shake a failed Check gave
## it, the dip a refused tap gave it, and the hop of the win.
func _jitter(cell: Vector2i, t: float) -> Vector2:
	if Motion.reduce:
		return Vector2.ZERO
	var out := Vector2.ZERO
	var flash := (t - float(_flash_at.get(cell, -100.0))) / FLASH_TIME
	if flash >= 0.0 and flash < 1.0:
		out.x += _cell * FLASH * sin(FLASH_SWINGS * PI * flash) * (1.0 - flash)
	var dip := (t - float(_dip_at.get(cell, -100.0))) / DIP_TIME
	if dip >= 0.0 and dip < 1.0:
		out.y += _cell * DIP * sin(PI * dip)
	if _solved_at >= 0.0:
		var hop := (t - float(_at.get(cell, 0.0))) / SOLVE_HOP_TIME
		if hop >= 0.0 and hop < 1.0:
			out.y -= _cell * SOLVE_HOP * sin(PI * hop)
	return out

# --- the light ---

## The warmth painted on a stone right now: 0 is the cold grey of FLAGSTONE, 1
## is full lamplight.
func _warmth(cell: Vector2i, t: float) -> float:
	var rec: Dictionary = _warm.get(cell, {})
	if rec.is_empty():
		return 0.0
	if Motion.reduce:
		return float(rec.to)
	var u := (t - float(rec.at)) / float(rec.dur)
	if u <= 0.0:
		return float(rec.from)
	if u >= 1.0:
		return float(rec.to)
	return lerpf(float(rec.from), float(rec.to), _sine_io(u))

## Sends every stone toward the light it now stands in, staggered by how far
## it is from the stone that changed, so the light travels. `from` of (-1, -1)
## is a change with no one place to travel from -- an undo, a reset, a swept
## run -- and lands everywhere at once.
func _relight(from: Vector2i, t: float) -> void:
	for cell in state.white_cells():
		var target := 1.0 if state.lit.has(cell) else 0.0
		var cur := _warmth(cell, t)
		var rec: Dictionary = _warm.get(cell, {})
		if rec.is_empty():
			_warm[cell] = {"from": cur, "to": target, "at": t, "dur": LIGHT_IN}
			continue
		if float(rec.to) == target and absf(cur - target) < 0.001:
			continue
		if float(rec.to) == target and t >= float(rec.at):
			continue
		var delay := 0.0
		if from.x >= 0:
			delay = minf(LIGHT_STEP * float(absi(cell.x - from.x) + absi(cell.y - from.y)),
				LIGHT_CAP)
		rec.from = cur
		rec.to = target
		rec.at = t + delay
		rec.dur = LIGHT_IN if target > cur else LIGHT_OUT

## The court as it opens: every stone already at the light it stands in, so
## the entrance is the stones fading in and not a wave crossing an empty
## court.
func _settle() -> void:
	_warm = {}
	for cell in state.white_cells():
		var target := 1.0 if state.lit.has(cell) else 0.0
		_warm[cell] = {"from": target, "to": target, "at": -100.0, "dur": LIGHT_IN}

func _throw_sparks(t: float) -> void:
	while not _sparks.is_empty() and float(_sparks[0].at) <= t:
		var spark: Dictionary = _sparks.pop_front()
		fx.sparkle(spark.pos, Pal.SUN)

# --- the drawing ---

func _draw() -> void:
	_shown = _court
	if _shown != null:
		draw_mesh(_shown, null)
	_draw_numbers()

## Everything on the court in one mesh, in the order the mock paints it: the
## mortar, the stones with their own warmth, the beams over them, the shade
## under a running sweep, the blocks, and the chips.
func _build_court(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var field := Vector2(_cell * state.w, _cell * state.h)
	b.fan(Face.Builder.round_rect(_grid - Vector2.ONE * MORTAR,
		field + Vector2.ONE * 2.0 * MORTAR, MORTAR_RADIUS), Color(Pal.TEXT, MORTAR_ALPHA))
	_build_stones(b, t)
	_build_beams(b, t)
	if _sweeping:
		for key in _swept:
			var cell: Vector2i = key
			b.fan(_tile(cell, 0.0), Color(Pal.TEXT, SWEEP_ALPHA))
	_build_blocks(b, t)
	_build_chips(b, t)
	if b.verts.is_empty():
		return null
	return b.mesh()

## A flagstone per cell, each carrying its own warmth: the stones *are* the
## display, which is why every one is its own tile rather than a tint over a
## shared field.
func _build_stones(b, t: float) -> void:
	for y in state.h:
		for x in state.w:
			if int(state.grid[y][x]) != Gen.WHITE:
				continue
			var cell := Vector2i(x, y)
			var en := _dec((t - _opened - ENTER_STONE - (x + y) * ENTER_STONE_STEP)
				/ ENTER_STONE_TIME)
			if en <= 0.0:
				continue
			var warm := _warmth(cell, t)
			b.fan(_tile(cell, 0.0),
				Color(Pal.FLAGSTONE_DEEP.lerp(Pal.LAMPLIT_DEEP, warm), en))
			b.fan(_tile(cell, STONE_EDGE),
				Color(Pal.FLAGSTONE.lerp(Pal.LAMPLIT_FLOOR, warm), en))

## The outline of one stone, `short` of a cell shorter than the joint allows:
## the fill sits on the deeper tile, which is the soft lip every card and tile
## on the flat screens wears.
func _tile(cell: Vector2i, short: float) -> PackedVector2Array:
	var gap := _cell * GAP
	return Face.Builder.round_rect(_grid + Vector2(cell) * _cell + Vector2.ONE * gap,
		Vector2(_cell - 2.0 * gap, _cell - 2.0 * gap - _cell * short), _cell * STONE_RADIUS)

## The shafts themselves, cell by cell out from each lamp, each one as bright
## as the warmth already painted on the stone it crosses -- so the beam
## travels with the light rather than switching on along the whole line.
func _build_beams(b, t: float) -> void:
	var half := _cell * BEAM_HALF
	for cell in state.lamps():
		var centre := cell_to_local(cell.y, cell.x)
		for d in State.DIRS:
			var p: Vector2i = cell + d
			var n := 1
			while state.is_white(p):
				var warm := _warmth(p, t)
				if warm > BEAM_MIN:
					var at := _grid + Vector2(p) * _cell
					var shine := Color(1.0, 1.0, 1.0,
						BEAM_ALPHA * warm / (1.0 + BEAM_FALL * n))
					if d.x != 0:
						b.fan(_quad(Vector2(at.x, centre.y - half),
							Vector2(_cell, half * 2.0)), shine)
					else:
						b.fan(_quad(Vector2(centre.x - half, at.y),
							Vector2(half * 2.0, _cell)), shine)
				p += d
				n += 1

static func _quad(at: Vector2, extent: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(extent.x, 0.0), at + extent,
		at + Vector2(0.0, extent.y)])

## The blocks of rough stone. A block with no number has nothing to be
## satisfied about, so it never goes green: half of a generated court's stone
## says nothing, and a blank block is information too -- it stops the light.
func _build_blocks(b, t: float) -> void:
	for y in state.h:
		for x in state.w:
			if int(state.grid[y][x]) == Gen.WHITE:
				continue
			var cell := Vector2i(x, y)
			var step := _block_entrance(cell, t)
			if step.x <= 0.0:
				continue
			var s := _cell * BLOCK_SIZE * step.y
			var at := cell_to_local(y, x) + Vector2(0.0, step.z)
			var alpha := step.x
			var face: Color = Pal.BLOCK_STONE
			var deep: Color = Pal.BLOCK_DEEP
			match state.block_state(cell):
				State.BLOCK_OK:
					face = face.lerp(Pal.LEAF, 0.55)
					deep = deep.lerp(Pal.LEAF_DEEP, 0.55)
				State.BLOCK_OVER:
					face = face.lerp(Pal.BAD, 0.6)
					deep = deep.lerp(Pal.MARKER_DEEP, 0.6)
			b.ellipse(at + Vector2(0.0, 0.44 * s), 0.42 * s, 0.1 * s, Color(Pal.TEXT, 0.14 * alpha))
			b.fan(Face.Builder.round_rect(at - Vector2.ONE * 0.46 * s,
				Vector2.ONE * 0.92 * s, 0.15 * s), Color(deep, alpha))
			b.fan(Face.Builder.round_rect(at - Vector2.ONE * 0.46 * s,
				Vector2(0.92, 0.8) * s, 0.15 * s), Color(face, alpha))
			b.fan(Face.Builder.round_rect(at + Vector2(-0.36, -0.38) * s,
				Vector2(0.34, 0.15) * s, 0.06 * s), Color(1.0, 1.0, 1.0, 0.08 * alpha))
			b.fan(Face.Builder.round_rect(at + Vector2(0.06, 0.1) * s,
				Vector2(0.3, 0.14) * s, 0.06 * s), Color(0.0, 0.0, 0.0, 0.07 * alpha))

## A block's alpha, its scale and how far it still has to drop onto the court.
func _block_entrance(cell: Vector2i, t: float) -> Vector3:
	var en := _dec((t - _opened - ENTER_BLOCK - (cell.x + cell.y) * ENTER_BLOCK_STEP)
		/ ENTER_BLOCK_TIME)
	if en <= 0.0:
		return Vector3.ZERO
	if Motion.reduce:
		return Vector3(en, 1.0, 0.0)
	var eased := _back_out(en)
	return Vector3(en, lerpf(BLOCK_FROM, 1.0, eased), -ENTER_DROP * (1.0 - eased))

## The chips the player has ruled stones out with: cool slate, never a small
## warm block of the court's own stone.
func _build_chips(b, t: float) -> void:
	for cell in state.marks:
		if int(state.marks[cell]) != State.CHIP:
			continue
		var grow := 1.0 if Motion.reduce else lerpf(POP_FROM, 1.0, _back_out(_pop_u(cell, t)))
		var alpha := 1.0
		if _solved_at >= 0.0:
			var gone := _dec((t - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD)
				/ CLEAR_TIME)
			if gone >= 1.0:
				continue
			alpha = 1.0 - gone
			grow *= 1.0 - gone * 0.4
		_chip(b, cell_to_local(cell.y, cell.x), _cell * CHIP_SIZE * grow, alpha)

func _chip(b, at: Vector2, s: float, alpha: float) -> void:
	b.ellipse(at + Vector2(0.0, 0.16 * s), 0.26 * s, 0.08 * s, Color(Pal.TEXT, 0.13 * alpha))
	b.fan(Face.Builder.round_rect(at + Vector2(-0.26, -0.16) * s,
		Vector2(0.52, 0.3) * s, 0.09 * s), Color(Pal.CHIP_DEEP, alpha))
	b.fan(Face.Builder.round_rect(at + Vector2(-0.26, -0.16) * s,
		Vector2(0.52, 0.24) * s, 0.09 * s), Color(Pal.CHIP, alpha))
	b.fan(Face.Builder.round_rect(at + Vector2(-0.19, -0.11) * s,
		Vector2(0.2, 0.07) * s, 0.035 * s), Color(1.0, 1.0, 1.0, 0.16 * alpha))

## The numerals, over the court's mesh. One draw_string each rather than
## geometry in the cache: a hard court carries about seven of them, and a
## digit in a mesh key would multiply every block state by five.
func _draw_numbers() -> void:
	if _cell <= 0.0 or state.grid.is_empty():
		return
	var font: Font = CozyTheme.display(700)
	var t := _now()
	for y in state.h:
		for x in state.w:
			var number := int(state.grid[y][x])
			if number < 0:
				continue
			var cell := Vector2i(x, y)
			var step := _block_entrance(cell, t)
			if step.x <= 0.0:
				continue
			var s := _cell * BLOCK_SIZE * step.y
			var px := int(roundf(s * NUM_SIZE))
			if px <= 0:
				continue
			var ink: Color = Pal.BLOCK_NUM
			if state.block_state(cell) != State.BLOCK_IDLE:
				ink = Color.WHITE
			var text := str(number)
			var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
			var at := cell_to_local(y, x) + Vector2(0.0, step.z - 0.02 * s) \
				+ Vector2(-wide * 0.5, font.get_ascent(px) * 0.5)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
				Color(ink, step.x))

# --- input ---

## Touch and drag only, as every flat board takes them. A tap sets a lantern
## down, takes one up or clears a chip; a drag sweeps chips, and its direction
## is read off the stone it started on.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release()
	elif event is InputEventScreenDrag and _press_cell.x >= 0:
		_drag(event.position)

func _press(cell: Vector2i) -> void:
	_clear_gesture()
	if is_done() or cell.x < 0:
		return
	_press_cell = cell

func _drag(at: Vector2) -> void:
	var cell := _cell_at(at)
	if cell.x < 0:
		return
	if not _dragged and cell != _press_cell:
		_dragged = true
		_sweeping = true
		# Begin on a chip and the sweep rubs out; begin anywhere else and it
		# lays.
		_lay = state.mark_at(_press_cell) != State.CHIP
		_paint(_press_cell)
	if not _dragged:
		return
	# Every stone between the last one painted and this one, so a fast finger
	# does not leave holes in its run. The mock paints only what it is handed.
	if _last_paint.x >= 0:
		var steps := maxi(absi(cell.x - _last_paint.x), absi(cell.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(
				roundi(lerpf(_last_paint.x, cell.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, cell.y, float(i) / steps))))
	_paint(cell)
	_refresh()

## A sweep never disturbs a lantern or a block: the gesture is for ruling
## stones out, and losing a lamp to a stray finger would be the worst bug on
## the board.
func _paint(cell: Vector2i) -> void:
	_last_paint = cell
	if _swept.has(cell):
		return
	_swept[cell] = true
	if state.fixed(cell) or state.mark_at(cell) == State.LAMP:
		return
	var to := State.CHIP if _lay else State.BLANK
	if state.mark_at(cell) == to:
		return
	_pending.append({"cell": cell, "to": to})

func _release() -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var pending := _pending
	_clear_gesture()
	if cell.x < 0 or is_done():
		_refresh()
		return
	if was_drag:
		# A swept run has no one place for the light to travel from, and it
		# changes no light in any case: chips are the player's own working-out.
		if not pending.is_empty():
			_commit(state.apply(pending), Vector2i(-1, -1))
		_refresh()
		return
	if state.fixed(cell):
		# A block's stone, or a lamp a hint lit: a dip and a word, rather than
		# a move.
		_dip_at[cell] = _now()
		_say("A block of stone stands there. It is what stops the light."
			if not state.is_white(cell)
			else "That lantern is lit for good. A hint set it down.", Face.Expr.PUZZLED)
		fx.cue("locked")
		_refresh()
		return
	_commit(state.tap(cell), cell)

## One gesture is one move, however many stones it touched. `from` is the
## stone the light travels out from, when there is one.
func _commit(changed: Array, from: Vector2i) -> void:
	if changed.is_empty():
		_refresh()
		return
	var t := _now()
	for cell in changed:
		_at[cell] = t
		if state.mark_at(cell) == State.LAMP:
			_lamp_node(cell)
	_relight(from, t)
	fx.cue("place")
	_speak()
	_refresh()
	note_move()

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_dragged = false
	_sweeping = false
	_swept = {}
	_pending = []
	_last_paint = Vector2i(-1, -1)

# --- the sprout's line ---

## What the tip card says: the rules while the court is dark, then whichever
## rule the board can currently see being broken, then the count of stones
## still in the dark -- which is the one rule the court itself has no marker
## for.
func _speak() -> void:
	if is_done():
		return
	var seen: int = state.clash.size()
	if seen > 0:
		_say("Two lanterns can see each other down that line." if seen <= 2
			else "%d lanterns are lighting each other." % seen, Face.Expr.STRAIN)
		return
	var over := state.over_blocks()
	if over > 0:
		_say("A block has more lanterns beside it than its number allows." if over == 1
			else "%d blocks have more lanterns beside them than their numbers allow." % over,
			Face.Expr.STRAIN)
		return
	var dark := state.dark()
	if dark > 0:
		_say("One stone is still in the dark." if dark == 1
			else "%d stones are still in the dark." % dark, Face.Expr.HAPPY)
		return
	_say("Every stone is lit. A number is still not satisfied.", Face.Expr.HAPPY)

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
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Takes back the last gesture, however many stones it swept. Counts no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var t := _now()
	for cell in state.undo():
		_at[cell] = t
		if state.mark_at(cell) == State.LAMP:
			_lamp_node(cell)
	_relight(Vector2i(-1, -1), t)
	_speak()
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Lights one lantern from the answer and pins it for good. Counts no move but
## can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	var t := _now()
	_at[target] = t
	_lamp_node(target)
	hints_used += 1
	_relight(target, t)
	fx.sparkle(cell_to_local(target.y, target.x), Pal.LEAF)
	fx.cue("hint")
	_say("That lantern is lit for good.", Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	check_solved()
	return true

## Shakes every lantern the answer does not put there, and says how many.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var t := _now()
	var wrong: Array = state.wrong_lamps()
	for cell in wrong:
		_flash_at[cell] = t
	_say("%d %s in the wrong place." % [wrong.size(),
		"lantern stands" if wrong.size() == 1 else "lanterns stand"]
		if not wrong.is_empty() else "Every lantern you have set down is right.",
		Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_refresh()
	return wrong.size()

func reset_board() -> void:
	var t := _now()
	_clear_gesture()
	for cell in state.reset():
		_at[cell] = t
	_dip_at = {}
	_flash_at = {}
	moves = 0
	_running = true
	_relight(Vector2i(-1, -1), t)
	_say("The court is cleared. The hints you spent are not refunded, only unpinned.",
		Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The board is the answer, so the win screen shows no cast: the lit court
## stays on the card under it.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "Not a stone left in the dark."}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The lanterns hop in reading order, each throwing sparks as it lands, and
## the chips clear away.
func _on_solved() -> void:
	var t := _now()
	_clear_gesture()
	_tip_timer.stop()
	_solved_at = t
	_sparks = []
	var down: Array = state.lamps()
	down.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y * state.w + a.x < b.y * state.w + b.x)
	for i in down.size():
		var cell: Vector2i = down[i]
		var at: float = t + SOLVE_DELAY + i * SOLVE_STEP
		_at[cell] = at
		if not Motion.reduce:
			_sparks.append({"at": at + SPARK_DELAY, "pos": cell_to_local(cell.y, cell.x)})
	_say("Not a stone left in the dark.", Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

func _back_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	const C := 1.70158
	return 1.0 + (C + 1.0) * pow(u - 1.0, 3.0) + C * pow(u - 1.0, 2.0)

## The light's own easing: in and out, so a stone warms the way a lamp is
## carried in rather than the way a switch is thrown.
static func _sine_io(u: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(u, 0.0, 1.0))

## A fixed pseudo-random number per stone, so the chips clear away in a
## scatter rather than a wave.
static func _hash(cell: Vector2i) -> float:
	return float(posmod(hash(cell), 1000)) / 1000.0
