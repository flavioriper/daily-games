extends "res://core/puzzle_base.gd"

## Queens as a flat board: a court cut into as many coloured regions as it
## has rows, under an ink frame and ink seams, on the host's parchment card.
## Seat one queen in every row, every column and every colour, and never let
## two queens touch, not even at a corner. The rules live in
## puzzles/queens_state.gd, which this only draws.
##
## This is the first board that answers a move for you. A seated queen
## crosses out every cell she can see, in a wave that runs out from her ring
## by ring (WAVE_STEP): as it reaches a cell the cell flashes gold and its
## pebble pops in behind the flash. Lift her and the wave runs backward, the
## far cells first, so her reach draws back into where she stood. The crosses
## a queen lays are derived by the state and never stored, so undo and
## removal need no bookkeeping for them; a queen on a crossed cell is
## refused, so two queens can never conflict and the n-th queen is the win.
##
## How it is drawn. Only the bees are nodes (ui/faces/bee_face.gd), each
## in a slot of its own so the layout and the motion never fight (rule 2 of
## docs/art/flat-motion.md). Everything else is two meshes rebuilt only while
## something moves: the floor (the frame, the region-tinted cells, the grid,
## the seams and the dot on every free cell), built about the court's centre
## so the entrance pop is a transform; and the ground (the wave's washes, the
## blushes, the bees' shadows and every pebble) over it. Every drawn moment
## reads the flat boards' vocabulary as curves off core/motion.gd (rule 8);
## nothing here needed a new reader. Every move -- a tap, a sweep, an undo, a
## hint, a reset -- goes through one _settle that diffs a snapshot of the
## court against the state and hands each changed cell its moment, with one
## Callable saying when: a queen's wave, a sweep's path, Reset's far corner.
## Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md.
## Concept page: docs/brainstorm/concepts.html#queens.

const State = preload("res://puzzles/queens_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const BeeFace = preload("res://ui/faces/bee_face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

# --- the court ---
## The card's inset round the court.
const PAD := 34.0
## The ink frame round the court and the seams between regions, in pixels;
## the faint grid between cells of one region and the dot on a free cell, in
## cells. The mock's own.
const FRAME := 6.0
const FRAME_RADIUS := 16.0
const SEAM := 5.0
const GRID := 2.0
const GRID_ALPHA := 0.28
const DOT_R := 0.055
const DOT_ALPHA := 0.32
## How far a pressed cell goes toward the ink at the bottom of its press. The
## cells are flush, so a press here shades rather than shrinks (a shrunk cell
## would show the frame's ink round it); the piece on the cell sinks.
const SINK_SHADE := 0.18
## The pieces in cells, each a fraction of a cell, and the bee's soft
## shadow on the ground.
const BEE_SIZE := 0.9
const BEE_SHADOW_AT := Vector2(0.0, 0.38)
const BEE_SHADOW_RX := 0.3
const BEE_SHADOW_RY := 0.08
const SHADOW_ALPHA := 0.22
## The family's rose itself rather than the pale tile tint, at less than
## half: the pale tint (0.9 against BAD_TILE) vanishes on the rose and coral
## regions.
const BLUSH_ALPHA := 0.42
## The seat's and the hint's ring, in cells.
const RING_R := 0.6
## How far a refused pebble shivers, in cells.
const SHIVER := 0.03

# --- this board's own motion: the wave ---
## One ring of the wave per Motion.WAVE_STEP: a cell a queen sees arrives its
## king-move distance in rings after her, and leaves in the reverse order.
## WAVE_STEP itself moved to core/motion.gd on 2026-09-20 when Sudoku became
## the second board to read it; this board keeps only the peak below, which
## genuinely differs from Sudoku's.
## The gold wash's peak alpha as the wave reaches a cell.
const WAVE_FLASH := 0.35
## A cross a queen laid, against the player's own at one.
const AUTO_ALPHA := 0.75
## How long a refused given queen strains before her face settles.
const STRAIN_TIME := 0.6
## The pebbles clear away in a scatter on the win, as Nonogram's do.
## The pebbles wait for the last queen's wave to land (far * Motion.WAVE_STEP plus
## the pop) before they clear, which Nonogram's 0.2 never had to.
const CLEAR_DELAY := 0.6
const CLEAR_SPREAD := 0.3
const CLEAR_TIME := 0.5
const CLEAR_SHRINK := 0.4
## The win screen waits for the solve wave to hop every queen and the
## pebbles to clear before it shows.
const WIN_WAIT := 1.6

const HINTS := State.HINTS
## How long a teaching line stands before the next, the family's own cycle.
const TIP_CYCLE := 10.0
const TIPS := [
	"One queen in every row, every column and every colour.",
	"A queen crosses out every seat she can see.",
	"Two queens never touch, not even at a corner.",
]

var state = State.new()
## Kept for the shared tray contract. Queens input is gesture-driven now: taps
## cycle the cell and drags always lay crosses, regardless of this value.
var brush: int = State.QUEEN

## The court's size, the name the win harness reads.
var n: int:
	get: return state.n

var fx: Node2D
var _cell := 0.0
var _grid := Vector2.ZERO
var _bees: Dictionary = {}   # Vector2i -> BeeFace, kept once made
var _slots: Dictionary = {}    # bee -> its slot
var _pos_tw: Dictionary = {}   # bee -> the hop, the shiver, the drop
var _look_tw: Dictionary = {}  # bee -> the pop, the press, the wobble
var _gen := 0

## Every drawn moment, each the second it begins, read off Motion's curve
## readers in _build_floor and _build_ground.
var _cross_in: Dictionary = {}  # cell -> at: its pebble pops in then
var _cross_out: Array = []      # [{"cell", "at", "alpha"}]: pebbles shrinking out
var _wash: Dictionary = {}      # cell -> at: the wave reaches it then
var _blush: Dictionary = {}     # cell -> at: Check pointed at it, or a refusal
var _shiver: Dictionary = {}    # cell -> at: a refused pebble
var _sunk: Dictionary = {}      # cell -> {"down", "up"}: the finger has it
var _floor: ArrayMesh
var _ground: ArrayMesh
var _ground_dirty := true
## The meshes the last _draw handed the canvas item. A canvas command holds a
## mesh by RID and not by reference; dropping the only reference to a mesh
## still on the item's command list leaves the renderer drawing a freed RID.
var _shown: Array = []

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
var _pressed: Control       # the bee under the finger, if one
var _dragged := false
var _lay := true            # retained for the shared sweep bookkeeping
var _swept: Dictionary = {}
var _pending: Array = []
var _last_paint := Vector2i(-1, -1)

var _opened := -1.0e9
var _solved_at := -1.0
var _anim_until := 0.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "queens"
func title() -> String: return "Queens"

func rules() -> String:
	return "Seat one queen in every row, every column and every colour. No two queens may touch, not even at a corner. A queen crosses out every seat she can see."

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
	_stop_all()
	state.setup(rng, difficulty)
	brush = State.QUEEN
	_cross_in = {}
	_cross_out = []
	_wash = {}
	_blush = {}
	_shiver = {}
	_sunk = {}
	_clear_gesture()
	_solved_at = -1.0
	_build_pieces()
	_layout()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

# --- the cast ---

## Only the bees are nodes. The court and the pebbles are drawn.
func _build_pieces() -> void:
	for bee in _slots:
		_slots[bee].queue_free()
	_slots = {}
	_bees = {}

## Puts `bee` in a slot of her own under the board. The slot takes the
## layout; the bee inside it takes the motion.
func _stand(bee: Control, node_name: String) -> void:
	var slot := Control.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	bee.name = "bee"
	bee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bee)
	_slots[bee] = slot

## The bee on `cell`, made the first time a queen is seated there and kept
## afterwards: a cell tapped twice would otherwise build and free a node with
## a mesh cache behind it on every tap.
func _bee_node(cell: Vector2i) -> BeeFace:
	if _bees.has(cell):
		return _bees[cell]
	var bee := BeeFace.new()
	bee.visible = false
	bee.scale = Vector2.ZERO
	_stand(bee, "bee_%d_%d" % [cell.x, cell.y])
	bee.set_idle(true)
	_bees[cell] = bee
	if _cell > 0.0:
		_seat(bee, cell_to_local(cell.y, cell.x), _cell * BEE_SIZE)
	return bee

## Every bee takes the look her state asks for; a bee is written only
## when her look changes, since a written face redraws.
func _refresh_faces() -> void:
	for cell in _bees:
		var bee: BeeFace = _bees[cell]
		if state.mark_at(cell) != State.QUEEN:
			continue
		var pinned: bool = state.locked.has(cell)
		if bee.pinned != pinned:
			bee.pinned = pinned
		# The win writes JOY on each bee as the wave reaches her, and a
		# refusal's strain settles on its own clock.
		if _solved_at >= 0.0 or bee.expression == Face.Expr.STRAIN:
			continue
		_set_expr(bee, Face.Expr.HAPPY)

func _set_expr(face: Face, expr: int) -> void:
	if face.expression != expr:
		face.expression = expr

# --- layout ---

## The court is the largest grid the card holds, and the card is cut to the
## court and centred in the slot (card_height, card_centred): the grid is
## square while its space is tall, so the cell is capped by the width at
## every step and there is slack however the card is cut.
func _layout() -> void:
	if state.region.is_empty():
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var court: Vector2 = Vector2.ONE * (_cell * state.n)
	var tall := minf(size.y, court.y + 2.0 * PAD)
	_grid = Vector2(size.x * 0.5 - court.x * 0.5, (size.y - tall) * 0.5 + (tall - court.y) * 0.5)
	for cell in _bees:
		_seat(_bees[cell], cell_to_local(cell.y, cell.x), _cell * BEE_SIZE)
	_refresh_faces()
	_redraw()

## Seats `bee` `px` square about `centre`: her slot takes the place, and her
## own place inside it is left to the motion.
func _seat(bee: Control, centre: Vector2, px: float) -> void:
	var seat := Vector2.ONE * px
	var slot: Control = _slots[bee]
	slot.size = seat
	slot.position = centre - seat * 0.5
	bee.size = seat
	bee.pivot_offset = seat * 0.5

## The cell a slot of `available` height holds, capped by the width.
func _cell_for(available: float) -> float:
	if state.region.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / state.n, (available - 2.0 * PAD) / state.n)

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.n + 2.0 * PAD)

func card_centred() -> bool:
	return true

## Control-local point over the centre of cell (r, c). The win harness taps
## these.
func cell_to_local(r: int, c: int) -> Vector2:
	return _grid + Vector2(c + 0.5, r + 0.5) * _cell

func _cell_at(local: Vector2) -> Vector2i:
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _grid) / _cell
	var cell := Vector2i(int(floor(p.x)), int(floor(p.y)))
	return cell if state.in_field(cell) else Vector2i(-1, -1)

## The court's centre in board pixels: what the floor pops about.
func _court_centre() -> Vector2:
	return _grid + Vector2.ONE * (_cell * state.n * 0.5)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _now() < _anim_until:
		queue_redraw()

## Keeps the court redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Something on the court changed: rebuild it on the next draw.
func _redraw() -> void:
	_ground_dirty = true
	queue_redraw()

# --- the drawing ---

## The court pops in wide about its centre once the chrome has slid in
## (rule 7), as one draw transform over the floor mesh; the ground is drawn
## over it as it is.
func _draw() -> void:
	if _cell <= 0.0 or state.region.is_empty():
		return
	var now := _now()
	var busy := false
	var shown: Array = []
	if _ground_dirty or now < _anim_until:
		_floor = _build_floor(now)
		var out := _build_ground(now)
		_ground = out.mesh
		busy = out.busy
		_ground_dirty = false
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.ENTER_POP:
		busy = true
	var seen := Motion.appear_level(since)
	if seen > 0.0 and _floor != null:
		var grown := Motion.wide_pop_scale(since)
		draw_mesh(_floor, null, Transform2D(0.0, Vector2(grown, grown), 0.0, _court_centre()),
			Color(1.0, 1.0, 1.0, seen))
		shown.append(_floor)
	if _ground != null:
		draw_mesh(_ground, null)
		shown.append(_ground)
	_shown = shown
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## The court, built about its centre: the ink frame (a filled round rect the
## cells lie flush on, so its rounded corners are ink and not parchment), a
## cell per region colour shaded toward the ink while the finger holds it,
## the faint grid over them, the seams where two regions meet, and the dot
## on every cell nothing stands on.
func _build_floor(now: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var field: Vector2 = Vector2.ONE * (_cell * state.n)
	var origin: Vector2 = -field * 0.5
	b.fan(Face.Builder.round_rect(origin - Vector2.ONE * FRAME,
		field + Vector2.ONE * (2.0 * FRAME), FRAME_RADIUS), Pal.TEXT)
	var gone: Array = []
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var col: Color = Pal.REGION[state.region_at(cell) % Pal.REGION.size()]
			if _sunk.has(cell):
				var pr: Dictionary = _sunk[cell]
				var released := -1.0 if now < float(pr.up) else now - float(pr.up)
				if released >= Motion.RELEASE_TIME:
					gone.append(cell)
				else:
					var grown := Motion.press_scale(now - float(pr.down), released)
					var depth := clampf((1.0 - grown) / (1.0 - Motion.PRESS_SCALE), 0.0, 1.0)
					col = col.lerp(Pal.TEXT, SINK_SHADE * depth)
			b.fan(_square(origin + Vector2(x, y) * _cell, _cell), col)
	for cell in gone:
		_sunk.erase(cell)
	# The grid: every line across the whole court, faint and flat-ended.
	var grid_ink := Color(Pal.TEXT, GRID_ALPHA)
	for i in range(1, state.n):
		b.stroke(PackedVector2Array([origin + Vector2(i * _cell, 0.0),
			origin + Vector2(i * _cell, field.y)]), GRID, grid_ink, false, false)
		b.stroke(PackedVector2Array([origin + Vector2(0.0, i * _cell),
			origin + Vector2(field.x, i * _cell)]), GRID, grid_ink, false, false)
	# The seams: the edge between two cells of different regions, in ink,
	# round-capped so they meet cleanly at corners.
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var g := state.region_at(cell)
			var at: Vector2 = origin + Vector2(x, y) * _cell
			if x + 1 < state.n and state.region_at(cell + Vector2i.RIGHT) != g:
				b.stroke(PackedVector2Array([at + Vector2(_cell, 0.0), at + Vector2.ONE * _cell]),
					SEAM, Pal.TEXT)
			if y + 1 < state.n and state.region_at(cell + Vector2i.DOWN) != g:
				b.stroke(PackedVector2Array([at + Vector2(0.0, _cell), at + Vector2.ONE * _cell]),
					SEAM, Pal.TEXT)
	# The dot on a cell nothing stands on: blank, or crossed but with its
	# pebble still on its way in the wave.
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var mark := state.mark_at(cell)
			var bare := mark == State.BLANK
			if _crossed(mark) and _cross_in.has(cell) and float(_cross_in[cell]) > now:
				bare = true
			if bare:
				b.disc(origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell, DOT_R * _cell,
					Color(Pal.TEXT, DOT_ALPHA))
	return b.mesh()

## A cell's square from its top-left corner.
static func _square(at: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(s, 0.0), at + Vector2.ONE * s, at + Vector2(0.0, s)])

## Everything standing on the court, in one mesh: the wave's gold washes, the
## blushes, the bees' shadows, the pebbles on their way out and the pebbles
## that are here.
func _build_ground(now: float) -> Dictionary:
	var b := Face.Builder.new()
	var busy := not _sunk.is_empty()
	# The wave: as it reaches a cell the cell flashes toward gold and back,
	# read off flash_level; a cell it has not reached yet keeps us drawing.
	var gone: Array = []
	for cell in _wash:
		var e: float = now - float(_wash[cell])
		if e < 0.0:
			busy = true
			continue
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			gone.append(cell)
			continue
		busy = true
		_cell_wash(b, cell, Color(Pal.QUEEN_WASH, WAVE_FLASH * Motion.flash_level(e)))
	for cell in gone:
		_wash.erase(cell)
	# The blush: toward the family's rose and back.
	gone = []
	for cell in _blush:
		var e: float = now - float(_blush[cell])
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			gone.append(cell)
			continue
		busy = true
		_cell_wash(b, cell, Color(Pal.BAD, BLUSH_ALPHA * Motion.flash_level(e)))
	for cell in gone:
		_blush.erase(cell)
	# The bees' shadows, anchored at the cell and read off each bee's own
	# scale and alpha, so one arrives with the pop and stays put when she hops.
	for cell in _bees:
		var bee: BeeFace = _bees[cell]
		if bee.visible:
			_bee_shadow(b, bee, cell)
	# Pebbles on their way out, drawn from the shape the state has forgotten.
	var still: Array = []
	for out in _cross_out:
		var e: float = now - float(out.at)
		var shrunk := Motion.pop_out_scale(e)
		if shrunk <= 0.0:
			continue
		still.append(out)
		busy = true
		var turn := PI * 0.5 * clampf(e / Motion.POP_OUT, 0.0, 1.0)
		Mosaic.pebble(b, cell_to_local(out.cell.y, out.cell.x), _cell, Vector2.ONE * shrunk,
			float(out.alpha), turn)
	_cross_out = still
	# The pebbles that are here: waiting for the wave, popping in with the
	# squash, standing, shivering when refused, or clearing away on the win.
	gone = []
	var shook_gone: Array = []
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var mark := state.mark_at(cell)
			if not _crossed(mark):
				continue
			var grow := Vector2.ONE
			if _cross_in.has(cell):
				var e: float = now - float(_cross_in[cell])
				if e < 0.0:
					busy = true
					continue
				grow = Motion.pop_in_scale(e)
				if e < Motion.POP_IN:
					busy = true
				else:
					gone.append(cell)
			grow *= _sink(cell, now)
			var alpha := AUTO_ALPHA if mark == State.AUTO else 1.0
			if _solved_at >= 0.0:
				var cleared := _dec((now - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD) / CLEAR_TIME)
				if cleared >= 1.0:
					continue
				busy = true
				alpha *= 1.0 - cleared
				grow *= 1.0 - cleared * CLEAR_SHRINK
			if grow.x <= 0.0 or grow.y <= 0.0:
				continue
			var at := cell_to_local(cell.y, cell.x)
			var shook: float = now - float(_shiver.get(cell, -100.0))
			if shook < Motion.SHIVER_TIME:
				busy = true
				at.x += Motion.shiver_offset(shook, _cell * SHIVER)
			elif _shiver.has(cell):
				shook_gone.append(cell)
			Mosaic.pebble(b, at, _cell, grow, alpha)
	for cell in gone:
		_cross_in.erase(cell)
	for cell in shook_gone:
		_shiver.erase(cell)
	if b.verts.is_empty():
		return {"mesh": null, "busy": busy}
	return {"mesh": b.mesh(), "busy": busy}

## A wash over the whole of `cell`.
func _cell_wash(b: Face.Builder, cell: Vector2i, colour: Color) -> void:
	b.fan(_square(_grid + Vector2(cell) * _cell, _cell), colour)

## The family's soft disc under `bee` on `cell`, scaled by how much of her
## is there and faded with her while she drops in.
func _bee_shadow(b: Face.Builder, bee: Control, cell: Vector2i) -> void:
	var seen := clampf(bee.scale.y, 0.0, 1.0) * clampf(bee.modulate.a, 0.0, 1.0)
	if seen <= 0.0:
		return
	Scenery.soft_disc(b, cell_to_local(cell.y, cell.x) + BEE_SHADOW_AT * _cell,
		BEE_SHADOW_RX * _cell * seen, BEE_SHADOW_RY * _cell * seen,
		Color(Pal.TEXT, SHADOW_ALPHA * seen))

## press_scale for the cell under the finger, one when it is not.
func _sink(cell: Vector2i, now: float) -> float:
	if not _sunk.has(cell):
		return 1.0
	var pr: Dictionary = _sunk[cell]
	var released := -1.0 if now < float(pr.up) else now - float(pr.up)
	return Motion.press_scale(now - float(pr.down), released)

static func _crossed(mark: int) -> bool:
	return mark == State.CROSS or mark == State.AUTO

# --- the moments ---

## The chrome is the host's; here the court pops in wide after the family's
## delay. Nothing stands on it yet.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP)
	fx.cue("enter")

## The cell under the finger sinks (the Press moment) and stays down until the
## piece it is waiting for lands or the finger lets it go.
func _sink_cell(cell: Vector2i) -> void:
	if _sunk.has(cell) and is_inf(float(_sunk[cell].up)):
		return
	_sunk[cell] = {"down": _now(), "up": INF}
	_busy_for(Motion.PRESS_TIME)

## Lets go of every cell the gesture still holds down: each springs back when
## the piece it is under arrives, or now.
func _end_sinks(now: float, arrivals: Dictionary = {}) -> void:
	var last := now
	for cell in _sunk:
		var pr: Dictionary = _sunk[cell]
		if is_inf(float(pr.up)):
			pr.up = float(arrivals.get(cell, now))
			last = maxf(last, float(pr.up))
	_anim_until = maxf(_anim_until, last + Motion.RELEASE_TIME)

## Every cell of the court as the state marks it now: what _settle diffs
## against after a move.
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			out[cell] = state.mark_at(cell)
	return out

## Every cell whose mark differs between `before` (a _snapshot) and the state
## now takes its moment -- a bee pops in (or drops in, from a hint) or
## shrinks out, a pebble pops in or shrinks out -- `delay_of.call(cell,
## leaving)` seconds after `t`; and every cell in `wash` flashes gold as the
## wave reaches it. A cross changing hands between the player and a queen is
## not a change. Returns the second each changed cell's piece arrives, for
## the sinks to wait on.
func _settle(before: Dictionary, t: float, delay_of: Callable, drop := false, wash: Array = []) -> Dictionary:
	var arrivals: Dictionary = {}
	if not Motion.reduce:
		for cell in wash:
			var at: float = t + float(delay_of.call(cell, false))
			_wash[cell] = at
			_busy_for(at - t + Motion.FLASH_IN + Motion.FLASH_OUT)
	for cell in before:
		var prev := int(before[cell])
		var mark := state.mark_at(cell)
		if prev == mark or (_crossed(prev) and _crossed(mark)):
			continue
		var going: float = t + float(delay_of.call(cell, true))
		var coming: float = t + float(delay_of.call(cell, false))
		if prev == State.QUEEN:
			_bee_down(cell, going - t)
		elif _crossed(prev):
			_cross_leaves(cell, going, prev)
		if mark == State.QUEEN:
			_bee_up(cell, coming - t, drop)
			arrivals[cell] = coming
		elif _crossed(mark):
			_cross_arrives(cell, coming)
			arrivals[cell] = coming
	_refresh_faces()
	return arrivals

## The wave out of a queen at `q`: a cell she sees arrives its king-move
## distance in rings after her, and leaves in the reverse order, the far
## cells first, so her reach draws back into where she stood. On a lift the
## queen herself leaves at once, not last: she goes and her reach
## draws back after her, rather than her hanging on while her far pebbles go
## first. Nothing waits under reduce-motion.
func _wave_from(q: Vector2i) -> Callable:
	var far := maxi(maxi(q.x, state.n - 1 - q.x), maxi(q.y, state.n - 1 - q.y))
	return func(cell: Vector2i, leaving: bool) -> float:
		if leaving and cell == q:
			return 0.0
		if Motion.reduce:
			return 0.0
		var d := State.distance(q, cell)
		return float((far - d) if leaving else d) * Motion.WAVE_STEP

## A sweep's wave: along the finger's path at the family's stagger.
func _along(path: Array) -> Callable:
	return func(cell: Vector2i, _leaving: bool) -> float:
		if Motion.reduce:
			return 0.0
		return Motion.stagger(maxi(path.find(cell), 0), Motion.ENTER_STAGGER)

## Reset's wave from the far corner.
func _from_far_corner() -> Callable:
	return func(cell: Vector2i, _leaving: bool) -> float:
		if Motion.reduce:
			return 0.0
		return Motion.stagger(2 * state.n - 2 - cell.x - cell.y, Motion.RESET_STAGGER)

func _at_once() -> Callable:
	return func(_cell_: Vector2i, _leaving: bool) -> float:
		return 0.0

## A queen is seated on `cell`: she pops in with the squash after
## `delay`, or drops in from above when a hint seated her.
func _bee_up(cell: Vector2i, delay: float, drop: bool) -> void:
	var bee := _bee_node(cell)
	bee.visible = true
	Motion.stop(_look_tw.get(bee))
	Motion.stop(_pos_tw.get(bee))
	bee.rotation = 0.0
	bee.position = Vector2.ZERO
	bee.modulate.a = 1.0
	_set_expr(bee, Face.Expr.HAPPY)
	if drop:
		bee.scale = Vector2.ONE
		_pos_tw[bee] = Motion.drop_in(bee, Motion.DROP, Motion.DROP_TIME, delay)
		_busy_for(delay + Motion.DROP_TIME)
	else:
		_look_tw[bee] = Motion.pop_in(bee, Motion.POP_IN, delay)
		_busy_for(delay + Motion.POP_IN)

## A queen is lifted off `cell`: she shrinks to nothing with the quarter
## turn after `delay` and is hidden once gone, unless something seated her
## again.
func _bee_down(cell: Vector2i, delay: float) -> void:
	var bee: BeeFace = _bees.get(cell)
	if bee == null:
		return
	Motion.stop(_look_tw.get(bee))
	var tw := Motion.pop_out(bee, Motion.POP_OUT, delay)
	if tw == null:
		bee.visible = false
		return
	_look_tw[bee] = tw
	_busy_for(delay + Motion.POP_OUT)
	tw.chain().tween_callback(func() -> void:
		if state.mark_at(cell) != State.QUEEN:
			bee.visible = false
			bee.rotation = 0.0)

func _cross_arrives(cell: Vector2i, at: float) -> void:
	_cross_in[cell] = at
	_busy_for(at - _now() + Motion.POP_IN)

## A pebble leaves `cell` at `at`, at the ink it had. Under reduce-motion it
## is simply gone, as pop_out would have it.
func _cross_leaves(cell: Vector2i, at: float, prev: int) -> void:
	_cross_in.erase(cell)
	_shiver.erase(cell)
	if Motion.reduce:
		return
	_cross_out.append({"cell": cell, "at": at, "alpha": AUTO_ALPHA if prev == State.AUTO else 1.0})
	_busy_for(at - _now() + Motion.POP_OUT)

## A cell blushes toward the family's rose and settles: Check pointing at its
## queen, or a press refused on it.
func _blush_cell(cell: Vector2i) -> void:
	if Motion.reduce:
		return
	_blush[cell] = _now()
	_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)

## `bee` hops `height` over `time` after `delay`; she rests at her slot's
## origin, so the base is always zero.
func _hop(bee: Control, height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_pos_tw.get(bee))
	bee.position = Vector2.ZERO
	# A drop's fade is stopped here too (drop_in and hop share _pos_tw), and it
	# must not be left half done: a hop or shiver always finds her fully seen.
	bee.modulate.a = 1.0
	_pos_tw[bee] = Motion.hop(bee, height, time, delay, 0.0)
	_busy_for(delay + time)

## Check pointing at a bee: she wobbles where she stands.
func _wobble(bee: Control) -> void:
	Motion.stop(_look_tw.get(bee))
	bee.rotation = 0.0
	bee.scale = Vector2.ONE
	_look_tw[bee] = Motion.wobble2d(bee)
	_busy_for(Motion.WOBBLE_TIME)

## A queen refused on `cell`, which a queen already sees: the pebble there
## shivers and the cell blushes, and the sprout says why.
func _refuse_seen(cell: Vector2i) -> void:
	_say("A queen already sees that seat.", Face.Expr.WORRIED)
	fx.cue("locked")
	if Motion.reduce:
		return
	_shiver[cell] = _now()
	_blush_cell(cell)
	_busy_for(Motion.SHIVER_TIME)

## A lift refused on a given queen: she shivers and strains for a beat while
## her cell blushes, and the sprout says why.
func _refuse_pinned(cell: Vector2i) -> void:
	_say("That queen was given. She stays.", Face.Expr.WORRIED)
	fx.cue("locked")
	_blush_cell(cell)
	var bee: BeeFace = _bees.get(cell)
	if bee == null or Motion.reduce:
		return
	_set_expr(bee, Face.Expr.STRAIN)
	_after(STRAIN_TIME, func() -> void:
		if bee.expression == Face.Expr.STRAIN and _solved_at < 0.0:
			bee.expression = Face.Expr.HAPPY)
	Motion.stop(_pos_tw.get(bee))
	bee.position = Vector2.ZERO
	bee.modulate.a = 1.0
	_pos_tw[bee] = Motion.shiver(bee, _cell * SHIVER)
	_busy_for(Motion.SHIVER_TIME)

# --- input ---

## A tap cycles a cell blank -> player cross -> queen -> blank. A drag always
## lays player crosses, including when it starts on a queen or an existing
## cross.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release(_cell_at(event.position))
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _press_cell.x >= 0:
		_drag(event.position)

func _press(cell: Vector2i) -> void:
	_release_press()
	_end_sinks(_now())
	_clear_gesture()
	if is_done() or cell.x < 0:
		return
	_press_cell = cell
	var mark := state.mark_at(cell)
	# A bee under the finger sinks whichever mark is already there. The actual
	# tap transition happens on release, so a short press can become a drag.
	if mark == State.QUEEN and _bees.has(cell):
		_pressed = _bees[cell]
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, true)
	_sink_cell(cell)
	_redraw()

## The bee under the finger springs back.
func _release_press() -> void:
	if _pressed == null:
		return
	if is_instance_valid(_pressed):
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, false)
		_busy_for(Motion.RELEASE_TIME)
	_pressed = null

## Every cell between the last one painted and this one is swept, so a fast
## finger leaves no holes. Queens always lays crosses while dragging.
func _drag(at: Vector2) -> void:
	var cell := _cell_at(at)
	if cell.x < 0 or cell == _last_paint:
		return
	_dragged = true
	# Delay painting until movement proves this is a drag, but once it is,
	# include the cell where the finger first went down in the stroke.
	if _last_paint.x < 0:
		_paint(_press_cell)
	if _last_paint.x >= 0:
		var steps := maxi(absi(cell.x - _last_paint.x), absi(cell.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(roundi(lerpf(_last_paint.x, cell.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, cell.y, float(i) / steps))))
	_paint(cell)
	_redraw()

## A stroke paints a cell once. A queen or an existing cross is left alone;
## only blank cells can receive a new player cross.
func _paint(cell: Vector2i) -> void:
	if not state.in_field(cell):
		return
	_last_paint = cell
	if _swept.has(cell):
		return
	_swept[cell] = true
	var mark := state.mark_at(cell)
	if mark != State.BLANK:
		return
	_sink_cell(cell)
	_pending.append(cell)

func _release(at_cell: Vector2i) -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var lay := _lay
	var pending := _pending
	var now := _now()
	_release_press()
	_clear_gesture()
	if cell.x < 0 or is_done():
		_end_sinks(now)
		_redraw()
		return
	_end_sinks(now)
	# A tap is the only gesture that advances the cell through its three
	# states. A finger that wandered off is a drag, even if it painted nothing.
	if at_cell == cell and not was_drag:
		_tap_cycle(cell, now)
		_redraw()
		return
	if not pending.is_empty():
		var before := _snapshot()
		var changed: Array = state.sweep(pending, lay)
		var arrivals := _settle(before, now, _along(pending) if was_drag else _at_once())
		_end_sinks(now, arrivals)
		if not changed.is_empty():
			# One stroke is one move, however many cells it crossed. A sweep
			# lays its pebbles in a wave along the finger's path and puffs
			# none; a single tap puffs.
			if not was_drag and lay:
				fx.puff(cell_to_local(cell.y, cell.x), Pal.SOCKET_PEBBLE)
			fx.cue("place")
			_speak()
			_redraw()
			note_move()
			return
	_end_sinks(now)
	_redraw()

## The queen chip on `cell`: a queen there is lifted (or refuses, if given),
## a bare cell or the player's cross seats one, a seen cell refuses.
func _tap_queen(cell: Vector2i, now: float) -> void:
	var before := _snapshot()
	if state.queens.has(cell):
		var lifted: Dictionary = state.lift(cell)
		if not lifted.ok:
			if int(lifted.why) == State.PINNED:
				_refuse_pinned(cell)
			return
		_settle(before, now, _wave_from(cell))
		fx.cue("remove")
		_speak()
		note_move()
		return
	var seated: Dictionary = state.seat(cell)
	if not seated.ok:
		if int(seated.why) == State.SEEN:
			_refuse_seen(cell)
		return
	_settle(before, now, _wave_from(cell), false, state.sees(cell))
	var at := cell_to_local(cell.y, cell.x)
	fx.ring(at, _cell * RING_R, Pal.SUN)
	fx.puff(at, Pal.SUN)
	fx.cue("place")
	_speak()
	note_move()

## One tap advances the player's mark. Cross -> queen deliberately uses the
## normal seating rules, so an already-seen cell still refuses the queen.
func _tap_cycle(cell: Vector2i, now: float) -> void:
	var mark := state.mark_at(cell)
	if mark == State.BLANK:
		var before := _snapshot()
		if not state.cross(cell):
			return
		_settle(before, now, _at_once())
		fx.cue("place")
		_speak()
		note_move()
		return
	if mark == State.CROSS:
		_tap_queen(cell, now)
		return
	if mark == State.QUEEN:
		_tap_queen(cell, now)
		return
	_refuse_seen(cell)

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_dragged = false
	_lay = true
	_swept = {}
	_pending = []
	_last_paint = Vector2i(-1, -1)

## The tray armed a chip.
func set_brush(v: int) -> void:
	brush = v

# --- the sprout's line ---

## What the tip card says: the rules while the court is bare, then how many
## queens are seated and how many are to go.
func _speak() -> void:
	if is_done():
		return
	if state.queens.is_empty() and state.crosses.is_empty():
		_say(TIPS[_tip_idx], Face.Expr.HAPPY)
		return
	var seated: int = state.queens.size()
	var left := state.queens_left()
	if seated == 0:
		_say("%d queens to seat." % left, Face.Expr.HAPPY)
		return
	_say("%d %s seated, %d to go." % [seated, "queen" if seated == 1 else "queens", left],
		Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY or not state.queens.is_empty() \
			or not state.crosses.is_empty():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Takes back the last gesture: a queen's seat or lift runs her wave the other
## way, a sweep comes back along its path. Counts no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	var cells: Array = state.undo()
	var origin := Vector2i(-1, -1)
	for cell in cells:
		if int(before[cell]) == State.QUEEN or state.mark_at(cell) == State.QUEEN:
			origin = cell
	if origin.x >= 0:
		var wash: Array = state.sees(origin) if state.queens.has(origin) else []
		_settle(before, now, _wave_from(origin), false, wash)
	else:
		_settle(before, now, _along(cells))
	_speak()
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

## Zero on an unproved court (state.ok false): the answer the generator
## stored there is only one of several seatings, so it cannot be handed out
## as a hint, and the button stays disabled.
func hints_left() -> int:
	return 0 if not state.ok else HINTS - hints_used

## Seats the answer's queen in the first row that lacks her and pins her: a
## wrong queen in her way pops out first, a ring pulses out of the cell, the
## bee drops in from above, sparkles rise, and her wave runs. Counts no
## move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	var out: Dictionary = state.hint()
	var target: Vector2i = out.cell
	if target.x < 0:
		return false
	hints_used += 1
	# The wrong queens go first and at once; the snapshot forgets them so the
	# wave lays their cells' pebbles like any other.
	for q in out.lifted:
		_bee_down(q, 0.0)
		before[q] = State.BLANK
	_settle(before, now, _wave_from(target), true, state.sees(target))
	var at := cell_to_local(target.y, target.x)
	fx.ring(at, _cell * RING_R, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_say("This queen was given, and she stays." if (out.lifted as Array).is_empty()
		else "That queen was in the wrong seat. This one was given, and she stays.",
		Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every queen the answer does not seat there wobbles and her cell blushes,
## and the sprout says how many. Crosses are left alone: a cross is a note,
## not a claim.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: Array = state.wrong_queens()
	for cell in wrong:
		if _bees.has(cell):
			_wobble(_bees[cell])
		_blush_cell(cell)
	if not wrong.is_empty():
		_say("%d %s in the wrong seat." % [wrong.size(), "queen is" if wrong.size() == 1 else "queens are"],
			Face.Expr.WORRIED)
	elif state.queens.is_empty():
		_say("Seat a queen first.", Face.Expr.HAPPY)
	else:
		_say("Every queen you have seated is right.", Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_redraw()
	return wrong.size()

## Every queen and cross the player laid goes, in a wave from the far corner;
## a given queen hops and keeps her crosses. Hints spent are not refunded.
func reset_board() -> void:
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	state.reset()
	var wave := _from_far_corner()
	_settle(before, now, wave)
	if not Motion.reduce:
		for cell in state.queens:
			if _bees.has(cell):
				_hop(_bees[cell], Motion.RESET_HOP, Motion.HOP_TIME, float(wave.call(cell, false)))
	_blush = {}
	_shiver = {}
	moves = 0
	_running = true
	_say("The court is cleared. A given queen keeps her seat.", Face.Expr.HAPPY)
	fx.cue("reset")
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## One bee in JOY, and the words. The board stays on the card as it slides
## down, every queen on her colour and the crosses gone.
func flat_win() -> Dictionary:
	return {"faces": [BeeFace.new()], "subtitle": "Every queen has her seat."}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The bees hop in the family's wave along the diagonal with JOY and a
## spark each, and the pebbles clear away in a scatter, leaving the queens on
## their colours.
func _on_solved() -> void:
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	_tip_timer.stop()
	_solved_at = now
	_blush = {}
	_shiver = {}
	var k := 0
	for cell in state.queens:
		var bee := _bee_node(cell)
		var delay := _solve_delay(cell)
		_hop(bee, Motion.SOLVE_HOP, Motion.SOLVE_TIME, delay)
		_grin(bee, delay)
		_after(delay, _spark_at.bind(k, cell_to_local(cell.y, cell.x)))
		k += 1
	_say("Every queen has her seat.", Face.Expr.JOY)
	fx.cue("solved")
	_busy_for(maxf(_solve_delay(Vector2i(state.n, state.n)) + Motion.SOLVE_TIME,
		CLEAR_DELAY + CLEAR_SPREAD + CLEAR_TIME))
	_redraw()

func _solve_delay(cell: Vector2i) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.SOLVE_DELAY + Motion.stagger(cell.x + cell.y, Motion.SOLVE_STAGGER)

## `bee` goes to JOY as the wave reaches her; at once under reduce-motion.
func _grin(bee: Face, delay: float) -> void:
	if delay <= 0.0:
		bee.expression = Face.Expr.JOY
	else:
		_after(delay, func() -> void: bee.expression = Face.Expr.JOY)

## A spark as bee `k` hops, the two pools used in turn so a run of nine a
## few hundredths apart does not recycle one pool fast enough to cut each
## burst in half.
func _spark_at(k: int, at: Vector2) -> void:
	if k % 2 == 0:
		fx.sparkle(at, Pal.SUN)
	else:
		fx.puff(at, Pal.SUN, 4)

# --- odds and ends ---

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at a bee that is gone.
func _stop_all() -> void:
	_gen += 1
	_pressed = null
	for tw in _pos_tw.values():
		Motion.stop(tw)
	for tw in _look_tw.values():
		Motion.stop(tw)
	_pos_tw = {}
	_look_tw = {}

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

## A fixed pseudo-random number per cell, so the pebbles clear away in a
## scatter rather than a wave.
static func _hash(cell: Vector2i) -> float:
	return float(posmod(hash(cell), 1000)) / 1000.0
