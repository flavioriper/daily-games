extends "res://core/puzzle_base.gd"

## Tents as a flat board: a meadow of pale turf on the host's parchment card,
## conifers standing on it, canvas tents pitched beside them, cairns over the
## ground the player has ruled out, and the line counts on chips along a band
## outside the grid. Built beside the island version
## (legacy/puzzles/tents3d.gd) so the two could be judged against each other
## on the phone; the rules live in puzzles/tents_state.gd, which this only
## draws.
##
## What flat buys here is narrower than it was for Shikaku, and worth saying
## plainly: a meadow with conifers on it is already this puzzle's natural
## home. It buys two things. **The counts**: twenty-six numbers on a hard
## board, consulted constantly, and on a board pitched at seven degrees the
## far band is the smallest and most foreshortened thing on the screen --
## precisely the information you look at most, rendered worst. Flat, a count
## is the same size wherever it sits and can change colour legibly. **And the
## sweep**: ruling ground out is most of the work here (a hard board is 64
## squares and 9 tents, so 55 of them are cairns), and a drag that lays a
## whole row of them is a gesture a grid square-on to the eye invites and a
## tilted one does not.
##
## How it is drawn. The meadow and its grid are one cached mesh; every cairn,
## every shadow on the ground, the shade under a running sweep and the blush
## of a cell go into a second, rebuilt only while something moves. The
## characters are Controls with their own cached meshes -- a conifer per
## tree, a tent per pitched square, a chip per line -- each standing in a
## slot the layout owns, and a tree's sway is a transform on its own draw, so
## a swaying meadow never asks the board for a frame.
##
## How it moves. The characters take the flat boards' vocabulary
## (core/motion.gd, docs/art/flat-motion.md) straight, inside their slots:
## the trees and the chips pop in with the squash along the diagonal, a tent
## pops in and out, sinks under the finger, hops, leans away from a
## neighbour's landing, wobbles on Check and shivers when it refuses. The
## cairns, the shade and the blush are drawn, so they read the same recipes
## as curves (Motion.pop_in_scale and its siblings; the doc's rule 8) and
## never copy a number. This board's own signatures: a tent is pitched up out
## of the ground from its foot and struck back into it, a cairn is stacked a
## stone at a time and taken down cap first, and on the win the cairns sink
## into the turf, tufts come up where some of them stood and every doorway is
## lit.
## Spec: docs/superpowers/specs/2026-09-18-tents-flat-design.md, sections 2
## to 7 and the amendment at its end, and the mock it is ported from
## (docs/brainstorm/concepts.html#tents).

const State = preload("res://puzzles/tents_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const TentFace = preload("res://ui/faces/tent_face.gd")
const ConiferFace = preload("res://ui/faces/conifer_face.gd")
const CountChip = preload("res://ui/faces/count_chip.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

# --- the meadow ---
const PAD := 34.0
## The count band, in cells. On the island it is a real extra row and column
## of bare platform, because a stone has to stand on something; here nothing
## stands on it, so it costs less than a cell.
const BAND := 0.72
const TURF_RADIUS := 18.0
## The meadow stands on the parchment the way every card does: on a bottom
## edge of the family's six (docs/art/flat-motion.md, the dressing).
const TURF_EDGE := 6.0
const GRID_WIDTH := 2.0
const GRID_ALPHA := 0.9
## The shade under a pressed cell and a running sweep, and the blush a cell
## takes when Check points at its tent or a tap is refused on it.
const SHADE_ALPHA := 0.07
const SHADE_INSET := 3.0
const SHADE_RADIUS := 10.0
const BLUSH_ALPHA := 0.9

# --- the pieces, in cells ---
const TENT_SIZE := 0.9
const TREE_SIZE := 0.94
const CAIRN_SIZE := 0.8
## The shadows on the ground, in the piece's seat: the mock's ellipses, as
## the family's soft disc. The peak is above the doc's band because a disc
## that fades to its rim reads at about half its centre (Shikaku measured it).
const TREE_SHADOW_AT := Vector2(0.0, 0.46)
const TREE_SHADOW_RX := 0.34
const TREE_SHADOW_RY := 0.09
const TENT_SHADOW_AT := Vector2(0.0, 0.42)
const TENT_SHADOW_RX := 0.42
const TENT_SHADOW_RY := 0.1
const SHADOW_ALPHA := 0.2

# --- motion: what is this board's own ---
## A refused tree's shiver, in cells; the family's 2 px is a tremor on a
## conifer this size.
const SHIVER := 0.04
## The cairns clear away on the win, in a scatter rather than a wave: a hard
## board finishes with 55 of its 64 squares under pebbles, and without this
## the last picture is the working-out rather than the camp.
const CLEAR_DELAY := 0.2
const CLEAR_SPREAD := 0.3
const CLEAR_TIME := 0.5
const CLEAR_SHRINK := 0.4
## How long the host waits before the win screen: the solve wave and the
## clearing both have to run their length first.
const WIN_WAIT := 1.6
## A tent is pitched up out of the ground rather than popped from its middle:
## it stands on a pivot at the foot of its fabric (FOOT, in its seat), comes
## up from flat and wide, stretches past its height and settles on the back
## ease. Struck, it folds back down into the ground the same way.
const FOOT := 0.9
const PITCH_TIME := 0.3
const PITCH_FROM := Vector2(1.2, 0.0)
const PITCH_STRETCH := Vector2(0.92, 1.12)
const STRIKE_TIME := 0.16
## A cairn is stacked a stone at a time -- the two at its foot, the middle
## one, the cap -- each dropping on from STACK_DROP of the cairn's height with
## the pop's squash; taken away, the cap goes first.
const STACK_STEP := 0.07
const STACK_TIME := 0.18
const STACK_DROP := 0.3
const UNSTACK_STEP := 0.04
const UNSTACK_LIFT := 0.12
const CAIRN_IN := 2.0 * STACK_STEP + STACK_TIME
const CAIRN_OUT := 2.0 * UNSTACK_STEP + Motion.POP_OUT
## Every square leans its cairn and sizes it a little differently, so a row
## of them is a row of cairns and not one stamped seven times.
const CAIRN_TILT := 0.14
const CAIRN_JITTER := 0.06
const CAIRN_SHIFT := 0.05
## Each stone's lit crest, toward white.
const CREST := 0.3
## The meadow's dressing: a tuft of grass on some of the grid's crossings and
## a flower on a few more, never inside a square, so nothing a player puts
## down stands on one. And the light along the turf's top edge.
const TUFT_SHARE := 0.3
const FLOWER_SHARE := 0.1
const TUFT_H := 0.16
const FLOWER_R := 0.045
const RIM_LIGHT := 0.35
## The win: the cairns sink into the turf, and on some of the squares they
## leave a tuft grows up where they stood, so the last picture is a camp in a
## meadow. Each lamp-lit doorway throws a warm pool on the grass in front.
const WIN_TUFT_SHARE := 0.4
const WIN_TUFT_H := 0.24
const GLOW_TIME := 0.4
const GLOW_AT := Vector2(0.0, 0.43)
const GLOW_RX := 0.36
const GLOW_RY := 0.1
const GLOW_ALPHA := 0.5

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
const TIPS := [
	"TN_TIP_BESIDE",
	"TN_TIP_CAIRNS",
	"TN_TIP_NUMBERS",
]

var state = State.new()
## The names the win harness and the island board share.
var w: int:
	get: return state.w
var h: int:
	get: return state.h
var _solution_tents: Array:
	get: return state.solution

var fx: Node2D
var _cell := 0.0
var _grid := Vector2.ZERO
var _card := Rect2()
var _chips_row: Array = []       # [r] -> CountChip
var _chips_col: Array = []       # [c] -> CountChip
var _trees: Dictionary = {}      # Vector2i -> ConiferFace
var _tents: Dictionary = {}      # Vector2i -> TentFace, kept once made
## Tree or tent -> the Control it stands in. The slot is what the layout
## moves and the face is what the motion moves (a hop, a nudge, a shiver),
## so a relayout mid-entrance cannot fight a pop: build() lays out before
## the host has given the board a size. A chip only ever scales, so it
## stands under the board with no slot.
var _slots: Dictionary = {}
var _pos_tw: Dictionary = {}     # face -> the hop, the nudge, the shiver, the drop
var _look_tw: Dictionary = {}    # face -> the pop, the press, the wobble, the bump
## Bumped on every rebuild; a pending callback from the last board checks it.
var _gen := 0

# --- what the ground is doing ---
## Vector2i -> the second a cairn's pebbles begin to arrive.
var _cairn_in: Dictionary = {}
## Cairns leaving: [{"cell": Vector2i, "at": float}], drawn shrinking from
## `at` since the state no longer has them.
var _cairn_out: Array = []
## Vector2i -> the second a cell began to blush.
var _blush: Dictionary = {}
## Vector2i -> {"at": float, "until": float}: the shade under a pressed cell
## or a swept one, popping in wide from `at` and gone from `until` (INF while
## the gesture still runs).
var _shade: Dictionary = {}
var _meadow: ArrayMesh
var _ground: ArrayMesh
var _ground_dirty := true
## The meshes the last _draw handed over that the next may let go of: a
## canvas command holds a mesh by RID, and a frame rendered before the queued
## redraw is flushed would otherwise draw a freed one (see CLAUDE.md).
var _shown: Array = []

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
## The face under the finger, sunk by the press, if the press landed on one.
var _pressed: Control
var _dragged := false
var _lay := true
var _swept: Dictionary = {}
var _pending: Array = []
var _last_paint := Vector2i(-1, -1)

var _opened := -1.0e9
var _solved_at := -1.0
## Redraw every frame until this second: a pop, a wave, the clearing.
var _anim_until := 0.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "tents"
func title() -> String: return "Tents"

func rules() -> String:
	return tr("TN_RULES")

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
	_cairn_in = {}
	_cairn_out = []
	_blush = {}
	_shade = {}
	_clear_gesture()
	_solved_at = -1.0
	_build_pieces()
	_layout()
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

# --- the cast ---

func _build_pieces() -> void:
	for face in _slots:
		_slots[face].queue_free()
	for chip in _chips_row + _chips_col:
		chip.queue_free()
	_slots = {}
	_chips_row = []
	_chips_col = []
	_trees = {}
	_tents = {}
	for r in state.h:
		_chips_row.append(_chip(int(state.row_counts[r]), "row_%d" % r))
	for c in state.w:
		_chips_col.append(_chip(int(state.col_counts[c]), "col_%d" % c))
	for cell in state.tree_list:
		var tree := ConiferFace.new()
		# The shadow is the board's, on the ground (see _build_ground).
		tree.casts = false
		# Nothing until the meadow is up; _enter pops each one in.
		tree.scale = Vector2.ZERO
		_stand(tree, "tree_%d_%d" % [cell.x, cell.y])
		tree.set_idle(true)
		_trees[cell] = tree

## A chip stands straight under the board, with no slot: nothing ever moves
## its position, only its scale (the pop in, the bump), so the layout and the
## motion never write the same property. Fourteen fewer nodes on a board.
func _chip(number: int, node_name: String) -> CountChip:
	var chip := CountChip.new()
	chip.name = node_name
	chip.number = number
	chip.scale = Vector2.ZERO
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	return chip

## Puts `face` in a slot of its own under the board. The slot takes the
## layout; the face inside it takes the motion.
func _stand(face: Control, node_name: String) -> void:
	var slot := Control.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	face.name = "face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(face)
	_slots[face] = slot

## The tent on `cell`, made the first time one is pitched there and kept
## afterwards: a square the player taps twice would otherwise build and free a
## node with a mesh cache behind it on every tap.
func _tent_node(cell: Vector2i) -> TentFace:
	if _tents.has(cell):
		return _tents[cell]
	var tent := TentFace.new()
	tent.casts = false
	tent.visible = false
	tent.scale = Vector2.ZERO
	_stand(tent, "tent_%d_%d" % [cell.x, cell.y])
	tent.set_idle(true)
	_tents[cell] = tent
	if _cell > 0.0:
		_seat(tent, cell_to_local(cell.y, cell.x), _cell * TENT_SIZE, Vector2(0.5, FOOT))
	return tent

## The tree or the standing tent on `cell`, or null for bare ground and a
## cairn.
func _face_on(cell: Vector2i) -> Control:
	if _trees.has(cell):
		return _trees[cell]
	if state.mark_at(cell) == State.TENT and _tents.has(cell):
		return _tents[cell]
	return null

## Every face takes the look its state asks for. A face is written only when
## its look changes -- a written face redraws.
func _refresh_faces() -> void:
	for c in _chips_col.size():
		_set_expr(_chips_col[c], _chip_face(state.col_tents(c), int(state.col_counts[c])))
	for r in _chips_row.size():
		_set_expr(_chips_row[r], _chip_face(state.row_tents(r), int(state.row_counts[r])))
	for cell in _tents:
		var tent: TentFace = _tents[cell]
		if state.mark_at(cell) != State.TENT:
			continue
		var pegged: bool = state.locked.has(cell)
		if tent.pegged != pegged:
			tent.pegged = pegged
		# The win writes JOY on each tent as the wave reaches it.
		if _solved_at >= 0.0:
			continue
		_set_expr(tent, Face.Expr.STRAIN if state.tent_bad(cell) else Face.Expr.HAPPY)

func _set_expr(face: Face, expr: int) -> void:
	if face.expression != expr:
		face.expression = expr

func _chip_face(have: int, want: int) -> int:
	match State.line_state(have, want):
		State.LINE_OK: return Face.Expr.JOY
		State.LINE_OVER: return Face.Expr.STRAIN
		_: return Face.Expr.HAPPY

# --- layout ---

## The meadow is the largest grid the card holds, and the card is cut to the
## meadow and centred in the slot rather than pinned under the day card the
## way the other flat boards are. This is the one board of the six whose grid
## is square while its space is tall: the cell is capped by the width, so
## there is slack however it is cut, and air above and below reads as centring
## where all of it below reads as a board that fell over.
func _layout() -> void:
	if state.tree_list.is_empty():
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var grid := Vector2(_cell * (state.w + BAND), _cell * (state.h + BAND))
	var tall := minf(size.y, grid.y + 2.0 * PAD)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - grid.x * 0.5, _card.position.y + (tall - grid.y) * 0.5) \
		+ Vector2.ONE * (_cell * BAND)
	for c in _chips_col.size():
		_seat(_chips_col[c], Vector2(_grid.x + (c + 0.5) * _cell, _grid.y - _cell * BAND * 0.5), _cell)
	for r in _chips_row.size():
		_seat(_chips_row[r], Vector2(_grid.x - _cell * BAND * 0.5, _grid.y + (r + 0.5) * _cell), _cell)
	for cell in _trees:
		_seat(_trees[cell], cell_to_local(cell.y, cell.x), _cell * TREE_SIZE)
	for cell in _tents:
		_seat(_tents[cell], cell_to_local(cell.y, cell.x), _cell * TENT_SIZE, Vector2(0.5, FOOT))
	_meadow = _build_meadow()
	_refresh_faces()
	_redraw()

## Seats `face` `px` square about `centre`: its slot, when it stands in one,
## with the face's own place inside the slot left to the motion; the face
## itself when it does not (a chip). `pivot` is where it scales and turns
## about, as a share of the seat: a tent's is the foot of its fabric, so it
## is pitched up out of the ground and rocks on it.
func _seat(face: Control, centre: Vector2, px: float, pivot := Vector2(0.5, 0.5)) -> void:
	var seat := Vector2.ONE * px
	var slot: Control = _slots.get(face)
	if slot != null:
		slot.size = seat
		slot.position = centre - seat * 0.5
	else:
		face.position = centre - seat * 0.5
	face.size = seat
	face.pivot_offset = seat * pivot

## The cell a slot of `available` height holds, capped by the width.
func _cell_for(available: float) -> float:
	if state.tree_list.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / (state.w + BAND),
		(available - 2.0 * PAD) / (state.h + BAND))

## The host cuts its card to the meadow and centres it, which is what these
## two say. A board that wants neither says nothing and fills the slot.
func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * (state.h + BAND) + 2.0 * PAD)

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

## The meadow's rectangle in board pixels.
func _field_px() -> Rect2:
	return Rect2(_grid, Vector2(_cell * state.w, _cell * state.h))

# --- the drawing ---

func _draw() -> void:
	if _cell <= 0.0 or state.tree_list.is_empty():
		return
	var now := _now()
	var busy := false
	var shown: Array = []
	# The meadow pops in wide once the chrome has slid in, drawn.
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.ENTER_POP:
		busy = true
	var seen := Motion.appear_level(since)
	if seen > 0.0 and _meadow != null:
		var grown := Motion.wide_pop_scale(since)
		draw_mesh(_meadow, null,
			Transform2D(0.0, Vector2(grown, grown), 0.0, _field_px().get_center()),
			Color(1.0, 1.0, 1.0, seen))
		shown.append(_meadow)
	if _ground_dirty or now < _anim_until:
		var out := _build_ground(now)
		_ground = out.mesh
		busy = busy or out.busy
		_ground_dirty = false
	if _ground != null:
		draw_mesh(_ground, null)
		shown.append(_ground)
	_shown = shown
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## The turf on its bottom edge and the faint grid over it, about the meadow's
## own centre, so its pop on the entrance is a transform.
func _build_meadow() -> ArrayMesh:
	var b := Face.Builder.new()
	var field := Vector2(_cell * state.w, _cell * state.h)
	var at := -field * 0.5
	# The edge is the card at full height plus its lip and the turf the same
	# card short of it, which is how every card on the flat screens gets its
	# soft foot.
	b.fan(Face.Builder.round_rect(at, field + Vector2(0.0, TURF_EDGE), TURF_RADIUS), Pal.LINE)
	b.fan(Face.Builder.round_rect(at, field, TURF_RADIUS), Pal.MEADOW)
	# The light along the turf's top edge, where the card's own light falls.
	b.stroke(PackedVector2Array([at + Vector2(TURF_RADIUS, GRID_WIDTH),
		at + Vector2(field.x - TURF_RADIUS, GRID_WIDTH)]), GRID_WIDTH * 1.5,
		Color(1.0, 1.0, 1.0, RIM_LIGHT))
	var line := Color(Pal.MEADOW_LINE, GRID_ALPHA)
	for x in range(1, state.w):
		b.stroke(PackedVector2Array([at + Vector2(x * _cell, 0.0),
			at + Vector2(x * _cell, field.y)]), GRID_WIDTH, line, false, false)
	for y in range(1, state.h):
		b.stroke(PackedVector2Array([at + Vector2(0.0, y * _cell),
			at + Vector2(field.x, y * _cell)]), GRID_WIDTH, line, false, false)
	# The dressing, on the inner crossings only: a crossing belongs to no
	# square, so nothing the player puts down ever stands on it.
	for y in range(1, state.h):
		for x in range(1, state.w):
			var lot := _hash2(Vector2i(x + 100, y + 100))
			var p := at + Vector2(x, y) * _cell
			if lot < TUFT_SHARE:
				Scenery.tuft(b, p + Vector2(0.0, TUFT_H * _cell * 0.35), TUFT_H * _cell)
			elif lot < TUFT_SHARE + FLOWER_SHARE:
				_flower(b, p, FLOWER_R * _cell)
	return b.mesh()

## A meadow flower: five petals round a pale eye.
func _flower(b, at: Vector2, r: float) -> void:
	for k in 5:
		var a := TAU * k / 5.0 - PI * 0.5
		b.disc(at + Vector2(cos(a), sin(a)) * r, r * 0.75, Pal.FLOWER)
	b.disc(at, r * 0.6, Pal.FLOWER_EYE)

## Everything on the ground that is not a character, in one mesh: the shade
## under the finger, the blush of a pointed-at cell, the shadow under every
## tree and tent, and the cairns arriving, standing and leaving. Returns the
## mesh and whether any of it is still moving.
func _build_ground(now: float) -> Dictionary:
	var b := Face.Builder.new()
	var busy := false
	# The shade: popping in wide under a pressed or swept cell, shrinking
	# away once the gesture has let it go.
	var gone: Array = []
	for cell in _shade:
		var sh: Dictionary = _shade[cell]
		var grown := 0.0
		if now < float(sh.until):
			var e: float = now - float(sh.at)
			grown = Motion.wide_pop_scale(e, Motion.POP_IN)
			busy = busy or e < Motion.POP_IN
		else:
			grown = Motion.pop_out_scale(now - float(sh.until))
			if grown <= 0.0:
				gone.append(cell)
				continue
			busy = true
		_cell_wash(b, cell, grown, Color(Pal.TEXT, SHADE_ALPHA))
	for cell in gone:
		_shade.erase(cell)
	# The blush: toward the family's rose and back, read off flash_level.
	gone = []
	for cell in _blush:
		var e: float = now - float(_blush[cell])
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			gone.append(cell)
			continue
		busy = true
		var level := Motion.flash_level(e)
		if level > 0.0:
			_cell_wash(b, cell, 1.0, Color(Pal.BAD_TILE, BLUSH_ALPHA * level))
	for cell in gone:
		_blush.erase(cell)
	# The shadows, anchored at the slot and read off the piece's own height,
	# so one arrives with its pop and stays put when the piece hops.
	for cell in _trees:
		_shadow(b, _trees[cell], cell, TREE_SIZE, TREE_SHADOW_AT, TREE_SHADOW_RX, TREE_SHADOW_RY)
	for cell in _tents:
		var tent: TentFace = _tents[cell]
		if tent.visible:
			_shadow(b, tent, cell, TENT_SIZE, TENT_SHADOW_AT, TENT_SHADOW_RX, TENT_SHADOW_RY)
	# Cairns on their way out, cap first, drawn from the shape the state has
	# forgotten.
	var still: Array = []
	for out in _cairn_out:
		var e: float = now - float(out.at)
		if e >= CAIRN_OUT or Motion.reduce:
			continue
		still.append(out)
		busy = true
		_cairn(b, out.cell, INF, e, 0.0)
	_cairn_out = still
	# The cairns that are here: stacking, standing, or sinking into the turf
	# on the win.
	gone = []
	for cell in state.marks:
		if int(state.marks[cell]) != State.GRASS:
			continue
		var since := INF
		if _cairn_in.has(cell):
			since = now - float(_cairn_in[cell])
			if since < CAIRN_IN and not Motion.reduce:
				busy = true
			else:
				gone.append(cell)
				since = INF
		var sunk := 0.0
		if _solved_at >= 0.0:
			sunk = _cleared(cell, now)
			if sunk >= 1.0:
				continue
			busy = true
		_cairn(b, cell, since, -1.0, sunk)
	for cell in gone:
		_cairn_in.erase(cell)
	if _solved_at >= 0.0:
		busy = _build_camp(b, now) or busy
	if b.verts.is_empty():
		return {"mesh": null, "busy": busy}
	return {"mesh": b.mesh(), "busy": busy}

## A rounded wash over `cell`, `grown` of its size about its centre.
func _cell_wash(b, cell: Vector2i, grown: float, colour: Color) -> void:
	if grown <= 0.0:
		return
	var span := (_cell - 2.0 * SHADE_INSET) * grown
	b.fan(Face.Builder.round_rect(cell_to_local(cell.y, cell.x) - Vector2.ONE * span * 0.5,
		Vector2.ONE * span, SHADE_RADIUS * grown), colour)

## The family's soft disc under `face` on `cell`, scaled by how much of the
## face is there.
func _shadow(b, face: Control, cell: Vector2i, share: float, at: Vector2, rx: float, ry: float) -> void:
	var seen := clampf(face.scale.y, 0.0, 1.0)
	if seen <= 0.0:
		return
	var seat := _cell * share
	Scenery.soft_disc(b, cell_to_local(cell.y, cell.x) + at * seat,
		rx * seat * seen, ry * seat * seen, Color(Pal.TEXT, SHADOW_ALPHA * seen))

## A cairn: the mark the puzzle is actually solved with, so it is a thing on
## the ground and not a shade of grass. Three tiers of stones -- the two at
## its foot with the shadow, the middle one, the cap -- each lit along its
## crest, leaned and sized by its square so no two stand alike.
## `since` is the seconds since it began to be stacked (INF once it stands),
## `leaving` the seconds since it began to come apart (negative while it
## stays), and `sunk` how far into the turf the win has taken it, 0 to 1.
func _cairn(b, cell: Vector2i, since: float, leaving: float, sunk: float) -> void:
	var s := _cell * CAIRN_SIZE
	var h := _hash(cell)
	var h2 := _hash2(cell)
	var grown := 1.0 + (h2 - 0.5) * 2.0 * CAIRN_JITTER
	var xf := Transform2D((h - 0.5) * 2.0 * CAIRN_TILT, Vector2(grown, grown), 0.0,
		cell_to_local(cell.y, cell.x))
	var shift := (h2 - 0.5) * 2.0 * CAIRN_SHIFT
	var flat := 1.0 - sunk
	var alpha := 1.0 - sunk
	for tier in 3:
		var sc := Vector2.ONE
		var lift := 0.0
		if since < INF:
			var e := since - tier * STACK_STEP
			if e <= 0.0:
				continue
			sc = Motion.pop_in_scale(e, STACK_TIME)
			lift = Motion.drop_in_lift(e, STACK_DROP * s, STACK_TIME)
		if leaving >= 0.0:
			var k := Motion.pop_out_scale(leaving - (2 - tier) * UNSTACK_STEP)
			if k <= 0.0:
				continue
			sc *= k
			lift += (1.0 - k) * UNSTACK_LIFT * s
		var foot := Vector2(0.0, 0.4) * s
		match tier:
			0:
				_pebble(b, xf, Vector2(0.0, 0.32) * s, 0.33 * s, 0.09 * s,
					Color(Pal.TEXT, 0.13 * alpha), sc, 0.0, flat, foot, false)
				var deep := Color(Pal.CAIRN_DEEP, alpha)
				_pebble(b, xf, Vector2(-0.15, 0.19) * s, 0.19 * s, 0.13 * s, deep, sc, lift, flat, foot)
				_pebble(b, xf, Vector2(0.16, 0.21) * s, 0.17 * s, 0.12 * s, deep, sc, lift, flat, foot)
			1:
				_pebble(b, xf, Vector2(0.0, 0.01) * s, 0.2 * s, 0.14 * s,
					Color(Pal.CAIRN_STONE, alpha), sc, lift, flat, foot)
			2:
				var cap := Vector2(-0.03 + shift, -0.2) * s
				_pebble(b, xf, cap, 0.14 * s, 0.11 * s,
					Color(Pal.CAIRN_STONE, alpha), sc, lift, flat, foot)
				# The glint grows with the cap it sits on, not about itself.
				_ellipse(b, xf, cap, cap + Vector2(-0.03, -0.04) * s, 0.06 * s, 0.04 * s,
					Color(1.0, 1.0, 1.0, 0.3 * alpha), sc, lift, flat, foot)

## One stone of the cairn: grown `sc` about its own centre, pressed `flat`
## toward the cairn's `foot`, put through the cairn's transform and raised
## `lift` pixels. A stone with a `crest` is lit along its top.
func _pebble(b, xf: Transform2D, centre: Vector2, rx: float, ry: float, colour: Color,
		sc: Vector2, lift: float, flat: float, foot: Vector2, crest := true) -> void:
	_ellipse(b, xf, centre, centre, rx, ry, colour, sc, lift, flat, foot)
	if crest:
		_ellipse(b, xf, centre, centre + Vector2(-0.18 * rx, -0.32 * ry), rx * 0.55, ry * 0.4,
			Color(colour.lerp(Color.WHITE, CREST), colour.a), sc, lift, flat, foot)

func _ellipse(b, xf: Transform2D, pivot: Vector2, centre: Vector2, rx: float, ry: float,
		colour: Color, sc: Vector2, lift: float, flat: float, foot: Vector2) -> void:
	var pts := Face.Builder.ring(centre, rx, ry)
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		var p := pivot + (pts[i] - pivot) * sc
		p = foot + (p - foot) * Vector2(1.0, flat)
		out[i] = xf * p - Vector2(0.0, lift)
	b.fan(out, colour)

## How far the win has taken the cairn on `cell` into the turf, 0 to 1: in a
## scatter rather than a wave.
func _cleared(cell: Vector2i, now: float) -> float:
	return _dec((now - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD) / CLEAR_TIME)

## The camp once it is done: a tuft grown on some of the squares nothing
## stands on, each as the cairn that may have been there has half sunk, and a
## warm pool in front of each tent as its lamp is lit. Returns whether any of
## it is still growing.
func _build_camp(b, now: float) -> bool:
	var busy := false
	var seat := _cell * TENT_SIZE
	for cell in state.tents():
		var e := now - _solved_at - _solve_delay(cell)
		var lit := _dec(e / GLOW_TIME)
		if lit < 1.0:
			busy = true
		if lit > 0.0:
			Scenery.soft_disc(b, cell_to_local(cell.y, cell.x) + GLOW_AT * seat,
				GLOW_RX * seat * lit, GLOW_RY * seat * lit, Color(Pal.SUN, GLOW_ALPHA * lit))
	for r in state.h:
		for c in state.w:
			var cell := Vector2i(c, r)
			if state.trees.has(cell) or state.mark_at(cell) == State.TENT:
				continue
			if _hash2(cell) >= WIN_TUFT_SHARE:
				continue
			var e := now - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD - CLEAR_TIME * 0.5
			var grow := Motion.pop_in_scale(e)
			if e < Motion.POP_IN and not Motion.reduce:
				busy = true
			if grow.y <= 0.0:
				continue
			var root := cell_to_local(r, c) + Vector2((_hash(cell) - 0.5) * 0.3, 0.22) * _cell
			Scenery.tuft(b, root, WIN_TUFT_H * _cell * grow.y)
	return busy

# --- input ---

## Touch and drag only, as every flat board takes them. A tap puts a tent up
## or takes whatever is there away; a drag sweeps cairns, and its direction is
## read off the square it started on.
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

## The press: a tree or a tent sinks under the finger; bare ground and a
## cairn take a shade that pops in wide under it. Every tappable square does
## this, including one that will refuse on release.
func _press(cell: Vector2i) -> void:
	_clear_gesture()
	if is_done() or cell.x < 0:
		return
	_press_cell = cell
	var now := _now()
	var face := _face_on(cell)
	if face != null:
		_pressed = face
		Motion.stop(_look_tw.get(face))
		_look_tw[face] = Motion.press(face, true)
		_busy_for(Motion.PRESS_TIME)
	else:
		_shade[cell] = {"at": now, "until": INF}
		_busy_for(Motion.POP_IN)
	_redraw()

## The pressed face springs back, on release or when the finger leaves it
## for a sweep.
func _release_press() -> void:
	if _pressed == null:
		return
	Motion.stop(_look_tw.get(_pressed))
	_look_tw[_pressed] = Motion.press(_pressed, false)
	_busy_for(Motion.RELEASE_TIME)
	_pressed = null

func _drag(at: Vector2) -> void:
	var cell := _cell_at(at)
	if cell.x < 0:
		return
	if not _dragged and cell != _press_cell:
		_dragged = true
		# Begin on a cairn and the sweep rubs out; begin anywhere else and it
		# lays.
		_lay = state.mark_at(_press_cell) != State.GRASS
		_release_press()
		_paint(_press_cell)
	if not _dragged:
		return
	# Every square between the last one painted and this one, so a fast finger
	# does not leave holes in its row. The mock paints only what it is handed.
	if _last_paint.x >= 0:
		var steps := maxi(absi(cell.x - _last_paint.x), absi(cell.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(
				roundi(lerpf(_last_paint.x, cell.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, cell.y, float(i) / steps))))
	_paint(cell)
	_redraw()

## A sweep never disturbs a tent or a tree: the gesture is for ruling ground
## out, and losing a tent to a stray finger would be the worst bug here. The
## shade follows the finger over the ground it can change.
func _paint(cell: Vector2i) -> void:
	_last_paint = cell
	if _swept.has(cell):
		return
	_swept[cell] = true
	if state.fixed(cell) or state.mark_at(cell) == State.TENT:
		return
	if not _shade.has(cell):
		_shade[cell] = {"at": _now(), "until": INF}
		_busy_for(Motion.POP_IN)
	var to := State.GRASS if _lay else State.BLANK
	if state.mark_at(cell) == to:
		return
	_pending.append(cell)

func _release() -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var lay := _lay
	var pending := _pending
	var now := _now()
	# The pressed face springs back before the gesture is forgotten: the
	# other order leaves a refused tree sunk at PRESS_SCALE for good.
	_release_press()
	_clear_gesture()
	if cell.x < 0 or is_done():
		_end_shades(now)
		_redraw()
		return
	if was_drag:
		var arrivals: Dictionary = {}
		if not pending.is_empty():
			var moves_: Array = []
			for c in pending:
				moves_.append({"cell": c, "to": State.GRASS if lay else State.BLANK})
			var before: Dictionary = state.marks.duplicate()
			# One gesture is one move, however many squares it touched; the
			# cairns arrive in a wave along the finger's path.
			arrivals = _commit(before, state.apply(moves_), Motion.ENTER_STAGGER, false)
		_end_shades(now, arrivals)
		_redraw()
		return
	if state.fixed(cell):
		# A tree's square, or a tent a hint pegged down: a shiver, a blush
		# and a word, rather than a move.
		_refuse(cell)
		_end_shades(now)
		_redraw()
		return
	var before: Dictionary = state.marks.duplicate()
	var arrivals := _commit(before, state.tap(cell), 0.0, true)
	_end_shades(now, arrivals)
	_redraw()

## Puts the squares `changed` by a move on the screen (see _transition) and
## counts the move. A tap that pitched a tent also puffs and leans the
## neighbours away. Returns each square's arrival time.
func _commit(before: Dictionary, changed: Array, per: float, tapped: bool) -> Dictionary:
	if changed.is_empty():
		_redraw()
		return {}
	var arrivals := _transition(before, changed, _now(), per)
	if tapped:
		var cell: Vector2i = changed[0]
		if state.mark_at(cell) == State.TENT:
			fx.puff(cell_to_local(cell.y, cell.x), Pal.TENT_CANVAS)
			_nudge_around(cell)
	fx.cue("place")
	_speak()
	_redraw()
	note_move()
	return arrivals

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_pressed = null
	_dragged = false
	_lay = true
	_swept = {}
	_pending = []
	_last_paint = Vector2i(-1, -1)

## Lets go of every shade the gesture still holds: each goes when the piece
## it was under arrives, or now.
func _end_shades(now: float, arrivals: Dictionary = {}) -> void:
	var last := now
	for cell in _shade:
		var sh: Dictionary = _shade[cell]
		if is_inf(float(sh.until)):
			sh.until = float(arrivals.get(cell, now))
			last = maxf(last, float(sh.until))
	_anim_until = maxf(_anim_until, last + Motion.POP_OUT)

# --- what the pieces do ---

## Every square in `cells` moves from what `before` had on it to what the
## state has now, the k-th one `per` seconds after the first: a tent pops in
## or out, a cairn arrives or leaves, and each line a tent joined or left has
## its chip recounted. Returns the second each square's piece arrives.
func _transition(before: Dictionary, cells: Array, t: float, per: float, drop := false) -> Dictionary:
	var arrivals: Dictionary = {}
	var cols: Dictionary = {}
	var rows: Dictionary = {}
	for k in cells.size():
		var cell: Vector2i = cells[k]
		var at := t + Motion.stagger(k, per)
		arrivals[cell] = at
		var prev := int(before.get(cell, State.BLANK))
		var mark := state.mark_at(cell)
		if prev == mark:
			continue
		if prev == State.GRASS:
			_cairn_leaves(cell, at)
		elif prev == State.TENT:
			_tent_down(cell, at - t)
		if mark == State.GRASS:
			_cairn_arrives(cell, at)
		elif mark == State.TENT:
			_tent_up(cell, at - t, drop)
		if prev == State.TENT or mark == State.TENT:
			cols[cell.x] = true
			rows[cell.y] = true
	for c in cols:
		_bump(_chips_col[c])
	for r in rows:
		_bump(_chips_row[r])
	_refresh_faces()
	return arrivals

## A tent goes up on `cell`: it is pitched up out of the ground after
## `delay`, or drops in from above when a hint pitched it.
func _tent_up(cell: Vector2i, delay: float, drop: bool) -> void:
	var tent := _tent_node(cell)
	tent.visible = true
	Motion.stop(_look_tw.get(tent))
	Motion.stop(_pos_tw.get(tent))
	tent.rotation = 0.0
	tent.position = Vector2.ZERO
	tent.modulate.a = 1.0
	if drop:
		tent.scale = Vector2.ONE
		_pos_tw[tent] = Motion.drop_in(tent, Motion.DROP, Motion.DROP_TIME, delay)
		_busy_for(delay + Motion.DROP_TIME)
	else:
		_look_tw[tent] = _pitch(tent, delay)
		_busy_for(delay + PITCH_TIME)

## A tent comes down off `cell`: it folds back down into the ground after
## `delay`, and is hidden once gone unless something put it back.
func _tent_down(cell: Vector2i, delay: float) -> void:
	var tent: TentFace = _tents.get(cell)
	if tent == null:
		return
	Motion.stop(_look_tw.get(tent))
	var tw := _strike(tent, delay)
	if tw == null:
		tent.visible = false
		return
	_look_tw[tent] = tw
	_busy_for(delay + STRIKE_TIME)
	tw.chain().tween_callback(func() -> void:
		if state.mark_at(cell) != State.TENT:
			tent.visible = false
			tent.rotation = 0.0)

## The pitch: from flat and wide on the ground, up past its height and home
## on the back ease, about the pivot at its foot. Under reduce-motion it is
## simply up.
func _pitch(tent: Control, delay: float) -> Tween:
	if Motion.reduce:
		tent.scale = Vector2.ONE
		return null
	tent.scale = PITCH_FROM
	var tw := tent.create_tween()
	tw.tween_property(tent, "scale", PITCH_STRETCH, PITCH_TIME * 0.55).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(tent, "scale", Vector2.ONE, PITCH_TIME * 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

## The strike: the pitch run back, flat and wide into the ground. Null under
## reduce-motion, and the caller hides the tent itself.
func _strike(tent: Control, delay: float) -> Tween:
	if Motion.reduce:
		return null
	var tw := tent.create_tween()
	tw.tween_property(tent, "scale", PITCH_FROM, STRIKE_TIME).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw

func _cairn_arrives(cell: Vector2i, at: float) -> void:
	_cairn_in[cell] = at
	_anim_until = maxf(_anim_until, at + CAIRN_IN)

## A cairn leaves `cell` from `at`. Under reduce-motion it is simply gone, as
## pop_out would have it.
func _cairn_leaves(cell: Vector2i, at: float) -> void:
	_cairn_in.erase(cell)
	if Motion.reduce:
		return
	_cairn_out.append({"cell": cell, "at": at})
	_anim_until = maxf(_anim_until, at + CAIRN_OUT)

## A cell blushes toward the family's rose and settles: Check pointing at its
## tent, or a tap refused on it.
func _blush_cell(cell: Vector2i) -> void:
	if Motion.reduce:
		return
	_blush[cell] = _now()
	_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)

## The trees and tents beside a tent that has just been pitched lean away
## from it and back. One already mid-hop is left to land.
func _nudge_around(cell: Vector2i) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var face := _face_on(cell + d)
		if face == null or Motion.running(_pos_tw.get(face)):
			continue
		_pos_tw[face] = Motion.nudge(face, Vector2(d), Vector2.ZERO)
	_busy_for(Motion.NUDGE_LAG + Motion.NUDGE_TIME)

## `face` hops `height` over `time` after `delay`; it rests at its slot's
## origin, so the base is always zero.
func _hop(face: Control, height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_pos_tw.get(face))
	face.position = Vector2.ZERO
	_pos_tw[face] = Motion.hop(face, height, time, delay, 0.0)
	_busy_for(delay + time)

## A chip whose line was recounted: the family's bump.
func _bump(chip: Control) -> void:
	Motion.stop(_look_tw.get(chip))
	chip.scale = Vector2.ONE
	_look_tw[chip] = Motion.bump(chip)

## Check pointing at a tent: it wobbles where it stands.
func _wobble(face: Control) -> void:
	Motion.stop(_look_tw.get(face))
	face.rotation = 0.0
	face.scale = Vector2.ONE
	_look_tw[face] = Motion.wobble2d(face)

## A tap refused on `cell`, a tree's or a pegged tent's: the piece shivers,
## the cell blushes and the sprout says why.
func _refuse(cell: Vector2i) -> void:
	_say(tr("TN_REFUSE_TREE") if state.trees.has(cell)
		else tr("TN_REFUSE_PEGGED"), Face.Expr.PUZZLED)
	fx.cue("locked")
	_blush_cell(cell)
	var face := _face_on(cell)
	if face == null:
		return
	Motion.stop(_pos_tw.get(face))
	face.position = Vector2.ZERO
	_pos_tw[face] = Motion.shiver(face, _cell * SHIVER)

# --- the sprout's line ---

## What the tip card says: the rules while the meadow is bare, then whichever
## rule the board can currently see being broken, then the count of tents
## still to pitch.
func _speak() -> void:
	if is_done():
		return
	var bad := state.bad_tents()
	if bad > 0:
		_say(tr("TN_BAD_ONE")
			if bad == 1 else
			tr("TN_BAD_N") % bad,
			Face.Expr.STRAIN)
		return
	var over := state.over_lines()
	if over > 0:
		_say(tr("TN_OVER_ONE") if over == 1
			else tr("TN_OVER_N") % over,
			Face.Expr.STRAIN)
		return
	var left := state.tents_left()
	if left <= 0:
		_say(tr("TN_UNMATCHED"), Face.Expr.STRAIN)
		return
	_say((tr("TN_LEFT_ONE") if left == 1 else tr("TN_LEFT_N")) % left, Face.Expr.HAPPY)

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

## Takes back the last gesture, however many squares it swept: the reverse of
## Place, square by square along the same path. Counts no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var before: Dictionary = state.marks.duplicate()
	_transition(before, state.undo(), _now(), Motion.ENTER_STAGGER)
	_speak()
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Pitches one tent from the answer and pegs it down for good: a ring pulses
## out of the square, the tent drops in from above, sparkles rise. Counts no
## move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var before: Dictionary = state.marks.duplicate()
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	hints_used += 1
	_transition(before, [target], _now(), 0.0, true)
	var at := cell_to_local(target.y, target.x)
	fx.ring(at, _cell * 0.5, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_say(tr("TN_PEGGED"), Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every tent the answer does not put there wobbles and its cell blushes, and
## the sprout says how many.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: Array = state.wrong_tents()
	for cell in wrong:
		if _tents.has(cell):
			_wobble(_tents[cell])
		_blush_cell(cell)
	_say((tr("TN_WRONG_ONE") if wrong.size() == 1 else tr("TN_WRONG_N")) % wrong.size()
		if not wrong.is_empty() else tr("TN_ALL_RIGHT"),
		Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_redraw()
	return wrong.size()

## Every tent and cairn goes, in a wave from the far corner, and the trees hop
## as the meadow clears around them. The hints a player spent are not
## refunded, only unpinned.
func reset_board() -> void:
	var now := _now()
	_clear_gesture()
	_release_press()
	_end_shades(now)
	var before: Dictionary = state.marks.duplicate()
	var cleared := state.reset()
	var cols: Dictionary = {}
	var rows: Dictionary = {}
	for cell in cleared:
		var at := now + Motion.stagger((state.h - 1 - cell.y) + (state.w - 1 - cell.x), Motion.RESET_STAGGER)
		if int(before[cell]) == State.GRASS:
			_cairn_leaves(cell, at)
		else:
			_tent_down(cell, at - now)
			cols[cell.x] = true
			rows[cell.y] = true
	for cell in _trees:
		_hop(_trees[cell], Motion.RESET_HOP, Motion.HOP_TIME,
			Motion.stagger((state.h - 1 - cell.y) + (state.w - 1 - cell.x), Motion.RESET_STAGGER))
	for c in cols:
		_bump(_chips_col[c])
	for r in rows:
		_bump(_chips_row[r])
	_blush = {}
	_cairn_in = {}
	moves = 0
	_running = true
	_refresh_faces()
	_say(tr("TN_RESET"),
		Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	_redraw()

## A completed daily is rebuilt from its seed, so the meadow opens bare. Pitch
## the generator's tents back and settle everything as the finished solve
## leaves it: every tent and tree standing and grinning, every chip satisfied,
## no cairns (the win clears them), no entrance. Not check_solved(): the host
## owns the win presentation for a daily that was already solved.
func restore_completed_board() -> void:
	var now := _now()
	_stop_all()
	_clear_gesture()
	_tip_timer.stop()
	state.marks = {}
	state.locked = {}
	state.history.clear()
	for cell in state.solution:
		state.marks[cell] = State.TENT
	_cairn_in = {}
	_cairn_out = []
	_blush = {}
	_shade = {}
	# The entrance and the clearing both long over.
	_opened = now - 10.0
	_solved_at = now - 10.0
	_anim_until = 0.0
	for cell in _tents:
		_tents[cell].visible = false
	for cell in state.solution:
		var tent := _tent_node(cell)
		tent.visible = true
		_settle_face(tent)
	for cell in _trees:
		_settle_face(_trees[cell])
	for chip in _chips_row + _chips_col:
		chip.scale = Vector2.ONE
		chip.rotation = 0.0
	_refresh_faces()
	_say(tr("TN_WIN"), Face.Expr.JOY)
	_redraw()

## A tree or a tent at rest in its slot, beaming.
func _settle_face(face: Face) -> void:
	face.position = Vector2.ZERO
	face.rotation = 0.0
	face.scale = Vector2.ONE
	face.modulate.a = 1.0
	face.expression = Face.Expr.JOY

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The board is the answer, so the win screen shows no cast: the pitched camp
## stays on the card under it.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("TN_WIN_SUB")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## Every tree and tent hops the solve wave along the diagonal, each tent
## grinning as the wave reaches it with a spark, and the cairns clear away in
## a scatter behind them.
func _on_solved() -> void:
	var now := _now()
	_clear_gesture()
	_release_press()
	_end_shades(now)
	_tip_timer.stop()
	_solved_at = now
	var k := 0
	for cell in _trees:
		var tree: ConiferFace = _trees[cell]
		var delay := _solve_delay(cell)
		_hop(tree, Motion.SOLVE_HOP, Motion.SOLVE_TIME, delay)
		_grin(tree, delay)
	for cell in state.tents():
		var tent: TentFace = _tent_node(cell)
		var delay := _solve_delay(cell)
		_hop(tent, Motion.SOLVE_HOP, Motion.SOLVE_TIME, delay)
		_grin(tent, delay)
		_after(delay, _spark_at.bind(k, cell_to_local(cell.y, cell.x)))
		k += 1
	_refresh_faces()
	_say(tr("TN_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_busy_for(CLEAR_DELAY + CLEAR_SPREAD + CLEAR_TIME)
	_redraw()

func _solve_delay(cell: Vector2i) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.SOLVE_DELAY + Motion.stagger(cell.x + cell.y, Motion.SOLVE_STAGGER)

## `face` goes to JOY as the wave reaches it; at once under reduce-motion.
func _grin(face: Face, delay: float) -> void:
	if delay <= 0.0:
		face.expression = Face.Expr.JOY
	else:
		_after(delay, func() -> void: face.expression = Face.Expr.JOY)

## A spark as tent `k` hops. The two pools are used in turn: a run of nine a
## few hundredths apart would otherwise recycle one pool fast enough to cut
## each burst in half.
func _spark_at(k: int, at: Vector2) -> void:
	if k % 2 == 0:
		fx.sparkle(at, Pal.SUN)
	else:
		fx.puff(at, Pal.TENT_CANVAS, 4)

# --- entrance ---

## The chrome is the host's; here the meadow pops in wide and the chips and
## the trees pop onto it a beat later with the squash, along the diagonal
## from the top-left corner, each tree's shadow arriving with it.
func _enter() -> void:
	_opened = _now()
	var far := 0
	for c in _chips_col.size():
		_look_tw[_chips_col[c]] = Motion.pop_in(_chips_col[c], Motion.POP_IN, _enter_delay(c))
	for r in _chips_row.size():
		_look_tw[_chips_row[r]] = Motion.pop_in(_chips_row[r], Motion.POP_IN, _enter_delay(r))
	for cell in _trees:
		far = maxi(far, cell.x + cell.y)
		_look_tw[_trees[cell]] = Motion.pop_in(_trees[cell], Motion.POP_IN, _enter_delay(cell.x + cell.y))
	_busy_for(maxf(_enter_delay(far) + Motion.POP_IN, Motion.ENTER_DELAY + Motion.ENTER_POP))
	fx.cue("enter")

func _enter_delay(diagonal: int) -> float:
	return Motion.ENTER_DELAY + Motion.ENTER_FACE_LAG + Motion.stagger(diagonal, Motion.ENTER_STAGGER)

# --- odds and ends ---

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at a tree that is gone.
func _stop_all() -> void:
	_gen += 1
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

## Keeps the ground redrawing for `seconds` more: something on it, or a
## shadow's owner, is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _process(delta: float) -> void:
	super(delta)
	if _now() < _anim_until:
		queue_redraw()

## Something on the ground changed: rebuild it on the next draw.
func _redraw() -> void:
	_ground_dirty = true
	queue_redraw()

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

## A fixed pseudo-random number per square, so the cairns clear away in a
## scatter rather than a wave.
static func _hash(cell: Vector2i) -> float:
	return float(posmod(hash(cell), 1000)) / 1000.0

## A second one, unrelated to the first: a cairn's size and a tuft's lot.
static func _hash2(cell: Vector2i) -> float:
	return float(posmod(hash(Vector2i(cell.x * 31 + 7, cell.y * 17 + 3)), 1000)) / 1000.0
