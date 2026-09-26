extends "res://core/puzzle_base.gd"

## Mushroom Patch as a flat board: a meadow of covered cells on the host's
## parchment card, with some of them turned over to show how many mushrooms
## grow in the eight cells touching them. Plant a mushroom where you have
## proved one is, lay a pebble where you have proved one is not, and the
## patch is done the moment the last mushroom is planted. The rules live in
## puzzles/mushroom_state.gd, which this only draws.
##
## **The count wash is this board's signature.** A number is written in ink
## while its neighbourhood is short of mushrooms, turns green the moment
## exactly that many stand around it, and turns rose if one too many is
## planted. The wash *holds* -- it is a state and not a flash that fades --
## and the numeral bumps as it changes. It is honest, and that is worth
## saying plainly because it looks like a tell: the wash is computed from
## what the player already holds, the number printed on the cell and the
## mushrooms they themselves planted, and never from the answer
## (`state.standing()` reads `marks`, not `mushrooms`). A green number means
## *you have put three here*, not *your three are right*; a board can be
## covered in green and still be wrong, and finding that out is what Check
## is for. This does not break Code Break's "a count and never a map" rule
## for the same reason.
##
## A given of nought draws **no numeral** and takes **no green wash**: it is
## turned over and bare, which is the whole of what it has to say, and a
## field of green nothings would drown the wash that matters. It still
## blushes rose when a mushroom is planted beside it, because that is news.
##
## How it is drawn. Only the mushrooms are nodes (ui/faces/mushroom_face.gd),
## each in a slot of its own so the layout and the motion never fight (rule 2
## of docs/art/flat-motion.md), made the first time a cell is planted and kept
## afterwards. Everything else is two meshes rebuilt only while something
## moves: the floor (the cell backs, each shaded by its mark, sunk under the
## finger and washed by its standing), built about the field's centre so the
## entrance pop is one transform; and the ground (the blushes, the soft discs
## under the mushrooms and every pebble) over it. The numerals are drawn text,
## one draw_set_transform a cell, so they pop, bump and take the wash's ink
## off Motion's readers -- Nonogram's clue numbers are the precedent. Every
## drawn moment reads the flat boards' vocabulary as curves off core/motion.gd
## (rule 8); nothing here needed a new reader. Every move -- a tap, a sweep,
## an undo, a hint, a reset -- goes through one _settle that diffs a snapshot
## of the field against the state and hands each changed cell its moment,
## with one Callable saying when: a sweep's path, Reset's far corner, a
## plant's own instant. **_settle is the wash's only entry point.**
## Spec: docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md.
## Concept page: docs/brainstorm/concepts.html#mushroom.

const State = preload("res://puzzles/mushroom_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

# --- the patch ---
## The card's inset round the field.
const PAD := 34.0
## The tally strip over the field, inside the card. It comes out of the
## field's height, which is why card_height subtracts it.
const TALLY := 72.0
## A cell's back: the gap it leaves round itself, its corner, and the lip of
## rim left showing under its face -- the mock's own numbers.
const CELL_INSET := 0.035
const CELL_RADIUS := 0.18
const FACE_DROP := 0.015
const FACE_SHORT := 0.05
## The pieces, each as a fraction of a cell: the mushroom's R (the face's
## own radius, which MushroomFace takes as RATIO of the seat it is given),
## the pebble's R and its body against that R, and the numeral's font.
const MUSHROOM := 0.33
const PEBBLE := 0.26
const PEBBLE_BODY := 0.82
const NUM_SIZE := 0.52
## The soft disc under a planted mushroom, in cells.
const SHADOW_AT := Vector2(0.0, 0.3)
const SHADOW_RX := 0.3
const SHADOW_RY := 0.09
const SHADOW_ALPHA := 0.22
## A plant's and a hint's ring, in cells.
const RING_R := 0.45
## How far a refused cell shivers, in cells. The family's SHIVER_PX is two
## pixels on a 147 px tile; a cell here is 116 to 155, so it is read as a
## fraction of the cell the way Queens' and Nonogram's are.
const SHIVER := 0.03
## The family's rose itself rather than the pale tile tint, at less than
## half: a blush on the meadow's yellow-green has to be the colour and not
## the tint to read at all.
const BLUSH_ALPHA := 0.42

# --- this board's own motion: the count wash ---
## How long a number's wash takes to settle when its standing changes: the
## old colour crosses to the new over this, so a number that goes green
## while a wave of mushrooms is still arriving does not snap.
const WASH_TIME := 0.35
## How deep the green sits on the cell.
const WASH_LEVEL := 0.30
## And the rose, deeper, because BAD is darker than LEAF and reads lighter
## on the meadow at the same level.
const WASH_OVER := 0.34
## How long a refused pinned mushroom strains before her face settles.
const STRAIN_TIME := 0.6
## The win screen waits for the solve wave to hop every mushroom.
const WIN_WAIT := 1.6

# --- the second polish (2026-09-25; the spec's section 16) ---
## A covered cell is a sod of turf standing on the card and a turned one is a
## bed sunk into it, so what is still to find and what is known read as
## relief and not only as colour. The turf's face is toned off its cell's
## hash within TONE, lit BEVEL of a cell round its crown TURF_LIT toward
## SURFACE, and stands on a foot TURF_FOOT of the way to TURF.
const TONE := 0.03
const BEVEL := 0.055
const TURF_LIT := 0.34
const TURF_FOOT := 0.6
## A bed's wall is its floor BED_WALL toward TEXT and shows BED_LIP of a cell
## along the top, where the card's edge shades the hole.
const BED_WALL := 0.16
const BED_LIP := 0.06
## One sod in TUFT_SHARE carries a small tuft of three blades TUFT_H of a
## cell tall, in TURF at TUFT_ALPHA, so the meadow reads as grass.
const TUFT_SHARE := 0.42
const TUFT_H := 0.17
const TUFT_ALPHA := 0.75
## The sod lifts off a cell as a mark lands in it, shrinking over SOD_TIME
## and rising SOD_LIFT of a cell, and settles back with the pop when the mark
## is taken away.
const SOD_TIME := 0.18
const SOD_LIFT := 0.12
## The sod settles back this long after the piece on its cell starts to go.
const SOD_BACK_LAG := 0.12
## A mushroom pulled up rises this much of a cell as she shrinks out.
const PLUCK := 0.2
## A number that has just come right glints: its bed shines SHINE toward
## SURFACE over GLINT_TIME, GLINT_LAG after its wash starts crossing.
const GLINT_TIME := 0.42
const GLINT_LAG := 0.12
const SHINE := 0.5
## On the win a light crosses the patch along the diagonal: when it sets off
## and its step a diagonal.
const WIN_GLINT_AT := 0.3
const WIN_GLINT_STEP := 0.035
## Every SWAY_EVERY seconds one planted mushroom sways about her foot.
const SWAY_EVERY := 3.4
const SWAY_ANGLE := 0.06
const SWAY_TIME := 0.9
## The tally's paper pill: its padding round the run, washed LEAF_TILE once
## every mushroom is planted and BAD_TILE past that. It bumps as it recounts.
const PILL_PAD := Vector2(22.0, 10.0)
const PILL_EDGE := 4.0

const HINTS := 3
## How long a teaching line stands before the next, the family's own cycle.
const TIP_CYCLE := 10.0
## Translation keys (locale/ui.csv), read through tr() when said.
const TIPS := ["MP_TIP_COUNT", "MP_TIP_PLANT", "MP_TIP_GREEN"]
## The tally strip and the sprout count in words, as the mock does: the
## strip is a label and not a score, and a numeral there would read as a
## second clue beside the ones on the field.
## Keys MP_NUM_0 to MP_NUM_14 (locale/ui.csv): "no", "one" ... "fourteen".
## A word here always stands alone or counts mushrooms; a sentence that needs
## "one" in front of a noun, or a feminine two, has a key of its own.
const WORDS := 15

## The tally strip's own geometry, the mock's: the little mushroom's seat and
## where it and the line sit in the run, and the line's font.
const TALLY_GLYPH := 53.0
const TALLY_GLYPH_X := 26.0
const TALLY_TEXT_X := 70.0
const TALLY_SIZE := 34

var state = State.new()
## Which chip the tray has armed: State.FOUND or State.CLEAR. The tray only
## asks; this owns it, and tile_tray.gd reads it back.
var brush: int = State.FOUND

## The field's size, the name the win harness reads.
var n: int:
	get: return state.n

var fx: Node2D
var _cell := 0.0
var _grid := Vector2.ZERO
var _tally_y := 0.0
var _caps: Dictionary = {}     # Vector2i -> MushroomFace, kept once made
var _slots: Dictionary = {}    # face -> its slot
var _pos_tw: Dictionary = {}   # face -> the hop, the shiver, the drop
var _look_tw: Dictionary = {}  # face -> the pop, the press, the wobble
var _tally_face: MushroomFace
var _gen := 0

## Every drawn moment, each the second it begins, read off Motion's curve
## readers in _build_floor, _build_ground and _draw_numerals.
var _pebble_in: Dictionary = {}  # cell -> at: its pebble pops in then
var _pebble_out: Array = []      # [{"cell", "at"}]: pebbles shrinking out
var _wash: Dictionary = {}       # cell -> the wash it is crossing from
var _bump: Dictionary = {}       # cell -> at: its numeral was recounted
var _blush: Dictionary = {}      # cell -> at: Check pointed at it, or a refusal
var _shiver: Dictionary = {}     # cell -> at: a refused press
var _wobble: Dictionary = {}     # cell -> at: Check pointed at a drawn pebble
var _sunk: Dictionary = {}       # cell -> {"down", "up"}: the finger has it
var _sod: Dictionary = {}        # cell -> {"at", "back"}: its turf lifting off or settling back
var _glint: Dictionary = {}      # cell -> at: a light crosses its bed then
var _tally_at := -100.0          # the tally recounted then
var _sway_timer: Timer
var _floor: ArrayMesh
var _ground: ArrayMesh
var _ground_dirty := true
## The meshes the last _draw handed the canvas item. A canvas command holds a
## mesh by RID and not by reference; dropping the only reference to a mesh
## still on the item's command list leaves the renderer drawing a freed RID.
var _shown: Array = []

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
var _pressed: Control       # the mushroom under the finger, if one
var _dragged := false
var _lay := true            # a sweep lays pebbles, or rubs the player's out
var _swept: Dictionary = {}
var _pending: Array[Vector2i] = []
var _last_paint := Vector2i(-1, -1)

## Whether a wave was running last frame, so one settled frame follows it.
var _tail := false

var _opened := -1.0e9
var _solved_at := -1.0
var _anim_until := 0.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "mushroom"
func title() -> String: return "Mushroom Patch"

func rules() -> String:
	return tr("MP_RULES")

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
	_sway_timer = Timer.new()
	_sway_timer.wait_time = SWAY_EVERY
	_sway_timer.timeout.connect(_sway)
	add_child(_sway_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_stop_all()
	state.setup(rng, difficulty)
	brush = State.FOUND
	_pebble_in = {}
	_pebble_out = []
	_wash = {}
	_bump = {}
	_blush = {}
	_shiver = {}
	_wobble = {}
	_sunk = {}
	_sod = {}
	_glint = {}
	_tally_at = -100.0
	_clear_gesture()
	_solved_at = -1.0
	_build_pieces()
	_layout()
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_sway_timer.start()
	_enter()

# --- the cast ---

## Only the mushrooms are nodes; the field, the numerals and the pebbles are
## drawn. The tally strip's own little mushroom is the one that is always
## here, so it is made once and kept with the board.
func _build_pieces() -> void:
	for cell in _caps:
		var face = _caps[cell]
		if _slots.has(face):
			_slots[face].queue_free()
			_slots.erase(face)
	_caps = {}
	if _tally_face == null:
		_tally_face = MushroomFace.new()
		_stand(_tally_face, "TallyMushroom")
	_tally_face.visible = state.n > 0

## Puts `face` in a slot of its own under the board. The slot takes the
## layout; the face inside it takes the motion.
func _stand(face: Control, node_name: String) -> void:
	var slot := Control.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	face.name = "mushroom"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(face)
	_slots[face] = slot

## The mushroom on `cell`, made the first time one is planted there and kept
## afterwards: a cell tapped twice would otherwise build and free a node with
## a mesh cache behind it on every tap.
func _cap_node(cell: Vector2i) -> MushroomFace:
	if _caps.has(cell):
		return _caps[cell]
	var face := MushroomFace.new()
	face.visible = false
	face.scale = Vector2.ZERO
	_stand(face, "mushroom_%d_%d" % [cell.x, cell.y])
	_caps[cell] = face
	if _cell > 0.0:
		_seat(face, cell_centre(cell), _seat_px())
	return face

## The seat a mushroom of MUSHROOM of a cell needs: the face takes its own
## radius as MushroomFace.RATIO of the box it is given.
func _seat_px() -> float:
	return _cell * MUSHROOM / MushroomFace.RATIO

## Every planted mushroom takes the look her state asks for; a face is
## written only when her look changes, since a written face redraws.
func _refresh_faces() -> void:
	for cell in _caps:
		var face: MushroomFace = _caps[cell]
		if int(state.marks.get(cell, State.BLANK)) != State.FOUND:
			continue
		var pinned: bool = state.pinned.has(cell)
		if face.sprig != pinned:
			face.sprig = pinned
		# The win writes JOY on each mushroom as the wave reaches her, and a
		# refusal's strain settles on its own clock.
		if _solved_at >= 0.0 or face.expression == Face.Expr.STRAIN:
			continue
		_set_expr(face, Face.Expr.HAPPY)

func _set_expr(face: Face, expr: int) -> void:
	if face.expression != expr:
		face.expression = expr

# --- layout ---

## The field is the largest grid the card holds under the tally strip, and
## the card is cut to the two and centred in the slot (card_height,
## card_centred): the grid is square while its space is tall, so the cell is
## capped by the width at every step and there is slack however the card is
## cut -- about 22 px of it, which moves the card by eleven.
func _layout() -> void:
	if state.n <= 0:
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var field: Vector2 = Vector2.ONE * (_cell * state.n)
	var tall := minf(size.y, field.y + 2.0 * PAD + TALLY)
	var top := (size.y - tall) * 0.5
	_grid = Vector2(size.x * 0.5 - field.x * 0.5, top + PAD + TALLY)
	_tally_y = top + PAD + TALLY * 0.5
	for cell in _caps:
		_seat(_caps[cell], cell_centre(cell), _seat_px())
	_layout_tally()
	_refresh_faces()
	_redraw()

## Seats `face` `px` square about `centre`: her slot takes the place, and her
## own place inside it is left to the motion. She turns and scales about the
## foot of her stem, not her middle (set after the size, which Face resets it
## on): the pop grows her up out of the soil, the press squashes her into it
## and a sway or a wobble rocks her on her root.
func _seat(face: Control, centre: Vector2, px: float) -> void:
	var seat := Vector2.ONE * px
	var slot: Control = _slots[face]
	slot.size = seat
	slot.position = centre - seat * 0.5
	face.size = seat
	face.pivot_offset = seat * 0.5 + Vector2(0.0, px * MushroomFace.RATIO * MushroomFace.FOOT)

## The cell a slot of `available` height holds, capped by the width. The
## tally strip comes out of the height before the field is measured.
func _cell_for(available: float) -> float:
	if state.n <= 0:
		return 0.0
	return minf((size.x - 2.0 * PAD) / state.n,
		(available - 2.0 * PAD - TALLY) / state.n)

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.n + 2.0 * PAD + TALLY)

func card_centred() -> bool:
	return true

## Control-local point over the centre of `cell`. The win harness taps these.
func cell_centre(cell: Vector2i) -> Vector2:
	return _grid + (Vector2(cell) + Vector2.ONE * 0.5) * _cell

## The island boards' name for the same point, in (row, column) order, which
## is what every other flat board answers to.
func cell_to_local(r: int, c: int) -> Vector2:
	return cell_centre(Vector2i(c, r))

func _cell_at(local: Vector2) -> Vector2i:
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _grid) / _cell
	var cell := Vector2i(int(floor(p.x)), int(floor(p.y)))
	return cell if _in_field(cell) else Vector2i(-1, -1)

func _in_field(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < state.n and cell.y < state.n

## The field's centre in board pixels: what the floor pops about.
func _field_centre() -> Vector2:
	return _grid + Vector2.ONE * (_cell * state.n * 0.5)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _now() < _anim_until:
		_tail = true
		queue_redraw()
	elif _tail:
		# One last **rebuilt** frame once everything has landed, and the
		# rebuild is the whole of it: _draw only rebuilds the cached meshes
		# while `_ground_dirty` or `now < _anim_until`, so a plain
		# queue_redraw() here would re-issue the stale floor and leave a
		# half-faded field under numerals that had recomputed -- worse than
		# the freeze it is here to prevent. _redraw() sets the flag.
		#
		# It is needed because this board bakes the entrance's per-cell fade
		# into the floor mesh's vertex colours (_build_floor writes
		# _entered(cell, now) into every rim and face), which it has to: the
		# fade runs as a diagonal wave, a cell at a time. Queens has no wave
		# -- its whole floor fades together, as one modulate on the draw call
		# (queens2d.gd:355-358), recomputed every frame -- so it cannot freeze
		# mid-fade and needs nothing like this. Measured on this Mac on
		# 2026-09-20: the first, cold run of tests/_shot_anim.gd on this board
		# stalled one frame clean over the end of the wave and kept a field
		# frozen at four fifths for the whole run.
		_tail = false
		_redraw()

## Keeps the field redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Something on the field changed: rebuild it on the next draw.
func _redraw() -> void:
	_ground_dirty = true
	queue_redraw()

# --- the drawing ---

## The field pops in wide about its centre once the chrome has slid in
## (rule 7), as one draw transform over the floor mesh, with the cells fading
## in in a diagonal wave under it; the numerals ride the same transform, and
## the ground is drawn over it as it is, the way Queens draws its pebbles.
func _draw() -> void:
	if _cell <= 0.0 or state.n <= 0:
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
	if since < Motion.ENTER_POP + Motion.stagger(2 * state.n - 2, Motion.ENTER_STAGGER):
		busy = true
	var grown := Motion.wide_pop_scale(since)
	if _floor != null:
		draw_mesh(_floor, null,
			Transform2D(0.0, Vector2(grown, grown), 0.0, _field_centre()))
		shown.append(_floor)
	_draw_numerals(now, grown)
	if _ground != null:
		draw_mesh(_ground, null)
		shown.append(_ground)
	_draw_tally(now)
	_shown = shown
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## The second cell `cell` begins to fade in, and how far it has got: the
## field arrives in a diagonal wave after the family's delay.
func _enter_at(cell: Vector2i) -> float:
	return _opened + Motion.ENTER_DELAY + Motion.stagger(cell.x + cell.y, Motion.ENTER_STAGGER)

func _entered(cell: Vector2i, now: float) -> float:
	if Motion.reduce:
		return 1.0
	return clampf((now - _enter_at(cell)) / Motion.ENTER_POP, 0.0, 1.0)

## The field, built about its centre: one back per cell, in the colour its
## mark asks for, sunk under the finger, shivering when refused and washed by
## its standing. Each back is a faint rim with its face laid on top a little
## lower and a little shorter, so every cell wears the family's bottom lip.
func _build_floor(now: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var origin: Vector2 = -Vector2.ONE * (_cell * state.n * 0.5)
	var gone: Array = []
	var settled: Array = []
	var lifted: Array = []
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var seen := _entered(cell, now)
			if seen <= 0.0:
				continue
			var given: bool = state.given.has(cell)
			var mark: int = int(state.marks.get(cell, State.BLANK))
			var base: Color = Pal.SURFACE if given else Pal.SOCKET_OUT
			if not given and mark == State.FOUND:
				base = Pal.MUSHROOM_TILE
			if given:
				var w := _wash_of(cell, now)
				if not bool(w.moving):
					# It has finished crossing: the record it was crossing
					# from says nothing any more, and _worn without it draws
					# the same colour.
					settled.append(cell)
				base = base.lerp(w.from_colour, float(w.from_level)) \
					.lerp(w.colour, float(w.level))
			var sink := 1.0
			if _sunk.has(cell):
				var pr: Dictionary = _sunk[cell]
				var released := -1.0 if now < float(pr.up) else now - float(pr.up)
				if released >= Motion.RELEASE_TIME:
					gone.append(cell)
				else:
					sink = Motion.press_scale(now - float(pr.down), released)
			var at := origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell
			at.x += Motion.shiver_offset(now - float(_shiver.get(cell, -100.0)), _cell * SHIVER)
			var side := _cell * (1.0 - 2.0 * CELL_INSET) * sink
			var radius := _cell * CELL_RADIUS * sink
			var shine := _shine(cell, now)
			var sod := _sod_pose(cell, now, not given and mark == State.BLANK, lifted)
			# The bed shows wherever the sod is not wholly down: under a mark,
			# and under a sod on its way off or back.
			if given or mark != State.BLANK or sod.x < 1.0 or sod.z < 1.0:
				_bed(b, at, side, radius, base.lerp(Pal.SURFACE, shine * SHINE), seen)
			if sod.z > 0.0:
				_turf(b, at + Vector2(0.0, sod.y * _cell), side, radius,
					Vector2(sod.x, sod.z), cell, seen, shine)
	for cell in gone:
		_sunk.erase(cell)
	for cell in lifted:
		_sod.erase(cell)
	gone = []
	for cell in _glint:
		if now - float(_glint[cell]) >= GLINT_TIME:
			gone.append(cell)
	for cell in gone:
		_glint.erase(cell)
	for cell in settled:
		_wash.erase(cell)
		_bump.erase(cell)
	# Nothing has entered yet on the board's first frames, and a mesh with no
	# surface in it is an error rather than an empty drawing.
	if b.verts.is_empty():
		return null
	return b.mesh()

## Where `cell`'s sod is at `now`: x and z its scale across and down, y how
## far it has risen, in cells (negative is up); z of nought means no sod is
## drawn. A covered cell with no moment owed stands in its sod; a sod lifting
## off shrinks and rises with pop_out's curve, and one settling back pops in.
## A finished moment is added to `lifted` for the caller to forget.
func _sod_pose(cell: Vector2i, now: float, covered: bool, lifted: Array) -> Vector3:
	if not _sod.has(cell):
		return Vector3(1.0, 0.0, 1.0) if covered else Vector3.ZERO
	var e: float = now - float(_sod[cell].at)
	if bool(_sod[cell].back):
		if e >= Motion.POP_IN:
			lifted.append(cell)
		var grow := Motion.pop_in_scale(e)
		return Vector3(grow.x, 0.0, grow.y)
	if e >= SOD_TIME:
		lifted.append(cell)
		return Vector3.ZERO
	var u := Motion.pop_out_scale(e, SOD_TIME)
	return Vector3(u, -SOD_LIFT * (1.0 - u), u)

## A bed sunk into the card about `at`: its wall in a shade of `floor_col`,
## showing BED_LIP of a cell along the top, and its floor under it.
func _bed(b: Face.Builder, at: Vector2, side: float, radius: float, floor_col: Color,
		alpha: float) -> void:
	var corner := at - Vector2.ONE * (side * 0.5)
	var lip := _cell * BED_LIP
	b.fan(Face.Builder.round_rect(corner, Vector2.ONE * side, radius),
		Color(floor_col.lerp(Pal.TEXT, BED_WALL), alpha))
	b.fan(Face.Builder.round_rect(corner + Vector2(0.0, lip), Vector2(side, side - lip), radius),
		Color(floor_col, alpha))

## A sod of turf about `at`, drawn at `grow` of its size: a foot in TURF, a lit
## rim and the crown toned off the cell's hash, and on some sods a tuft.
## `shine` is the win's light crossing it.
func _turf(b: Face.Builder, at: Vector2, side: float, radius: float, grow: Vector2,
		cell: Vector2i, alpha: float, shine: float) -> void:
	var tone := _hash(cell) * 2.0 - 1.0
	var face: Color = Pal.TURF_REACH.lightened(tone * TONE) if tone > 0.0 \
		else Pal.TURF_REACH.darkened(-tone * TONE)
	var foot: Color = face.lerp(Pal.TURF, TURF_FOOT)
	var rim: Color = face.lerp(Pal.SURFACE, TURF_LIT)
	if shine > 0.0:
		face = face.lerp(Pal.SURFACE, shine * SHINE)
		rim = rim.lerp(Pal.SURFACE, shine * SHINE)
	var xf := Transform2D(0.0, grow, 0.0, at)
	var corner := -Vector2.ONE * (side * 0.5)
	var edge := side * (FACE_SHORT + FACE_DROP)
	var bev := _cell * BEVEL
	b.fan(xf * Face.Builder.round_rect(corner, Vector2.ONE * side, radius), Color(foot, alpha))
	b.fan(xf * Face.Builder.round_rect(corner, Vector2(side, side - edge), radius), Color(rim, alpha))
	b.fan(xf * Face.Builder.round_rect(corner + Vector2(bev * 0.7, bev),
		Vector2(side - bev * 1.4, side - edge - bev), maxf(radius - bev * 0.5, 0.0)),
		Color(face, alpha))
	if _hash(cell, 1) < TUFT_SHARE:
		var root := Vector2((_hash(cell, 2) - 0.5) * 0.5, 0.2 + 0.12 * _hash(cell, 3)) * side
		_tuft(b, xf, root, _cell * TUFT_H, Color(Pal.TURF, TUFT_ALPHA * alpha))

## Three slim blades from `root`, the middle one tallest, under `xf`.
static func _tuft(b: Face.Builder, xf: Transform2D, root: Vector2, h: float, col: Color) -> void:
	for blade in [Vector2(0.0, -1.0), Vector2(-0.52, -0.7), Vector2(0.55, -0.66)]:
		var tip: Vector2 = root + blade * h
		var side := (tip - root).orthogonal().normalized() * h * 0.13
		b.fan(xf * PackedVector2Array([root - side, tip, root + side]), col)

## How far into its glint `cell` is, 0 to 1 and back.
func _shine(cell: Vector2i, now: float) -> float:
	if Motion.reduce or not _glint.has(cell):
		return 0.0
	var e: float = now - float(_glint[cell])
	if e <= 0.0 or e >= GLINT_TIME:
		return 0.0
	return sin(PI * e / GLINT_TIME)

## A steady 0-1 value per cell, so a sod's tone and tuft never change.
static func _hash(cell: Vector2i, salt := 0) -> float:
	var h := sin(float(cell.x) * 12.9898 + float(cell.y) * 78.233 + float(salt) * 37.719) * 43758.5453
	return h - floorf(h)

## What `cell`'s number is washed with now: the colour its standing asks for
## at the level it asks for, crossed over WASH_TIME from whatever it wore
## when it last changed. `standing()` is derived from the player's own marks
## and never from the answer -- the wash's whole honesty is in that one call.
## A given of nought takes no green: it is settled from the moment the board
## is built, and a field of green nothings would drown the wash that matters.
func _wash_of(cell: Vector2i, now: float) -> Dictionary:
	return _worn(cell, now, state.standing(cell))

## The same, against a standing named rather than read: _settle_wash needs
## what the number was wearing a moment ago, and the state's own standing()
## already describes the move that has just been made.
func _worn(cell: Vector2i, now: float, standing: int) -> Dictionary:
	var target := _wash_target(standing, int(state.given.get(cell, 0)))
	if not _wash.has(cell):
		return {"colour": target.colour, "level": target.level, "ink": target.ink,
			"from_colour": target.colour, "from_level": 0.0, "moving": false}
	var was: Dictionary = _wash[cell]
	var u := 1.0 if Motion.reduce else clampf((now - float(was.at)) / WASH_TIME, 0.0, 1.0)
	return {
		"colour": target.colour,
		"level": float(target.level) * u,
		"ink": (was.ink as Color).lerp(target.ink, u),
		"from_colour": was.colour,
		"from_level": float(was.level) * (1.0 - u),
		"moving": u < 1.0,
	}

## The wash a number of `value` standing `standing` asks for, with nothing
## moving. Nought takes no green, as the file comment says.
static func _wash_target(standing: int, value: int) -> Dictionary:
	if standing == State.OVER:
		return {"colour": Pal.BAD, "level": WASH_OVER, "ink": Pal.BAD}
	if standing == State.SETTLED and value > 0:
		return {"colour": Pal.LEAF, "level": WASH_LEVEL, "ink": Pal.LEAF_DEEP}
	return {"colour": Pal.LEAF, "level": 0.0, "ink": Pal.TEXT}

## The numerals, over the floor's mesh and inside the entrance pop: one
## draw_set_transform a cell, so a numeral sinks with its cell, bumps when it
## is recounted and takes the wash's ink off Motion's readers. **A given of
## nought draws nothing**: it is turned over and bare, and that is all it has
## to say.
func _draw_numerals(now: float, grown: float) -> void:
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell * NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	var centre := _field_centre()
	for cell in state.given:
		var v: int = int(state.given[cell])
		if v <= 0:
			continue
		var seen := _entered(cell, now)
		if seen <= 0.0:
			continue
		var ink: Color = _wash_of(cell, now).ink
		var scale := grown * _sink(cell, now) * Motion.bump_scale(now - float(_bump.get(cell, -100.0)))
		if scale <= 0.0:
			continue
		var at := cell_centre(cell) + Vector2(0.0, _cell * BED_LIP * 0.5)
		at.x += Motion.shiver_offset(now - float(_shiver.get(cell, -100.0)), _cell * SHIVER)
		at = centre + (at - centre) * grown
		draw_set_transform(at, 0.0, Vector2.ONE * scale)
		var text := str(v)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, Vector2(-wide * 0.5, rise), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Color(ink, seen))
	draw_set_transform(Vector2.ZERO)

## The tally strip: a small mushroom and what the field is worth against what
## is spoken for. It is the only number this screen gives you free, and it is
## a clue and not decoration -- the generator carves against the global count,
## so a board played without it would be unfair. It counts in words, because a
## numeral here would read as a fourteenth clue on the field -- but only as
## far as the words go (see _word).
func _draw_tally(now: float) -> void:
	var font: Font = CozyTheme.display(700)
	var left := state.left()
	var line := _tally_line(left)
	var start := size.x * 0.5 - _tally_run() * 0.5
	var grow := _tally_grow(now)
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var ink: Color = Pal.TEXT if left >= 0 else Pal.BAD
	if left == 0:
		ink = Pal.LEAF_DEEP
	var at := Vector2(start + TALLY_TEXT_X, _tally_y)
	draw_set_transform(at, 0.0, grow)
	draw_string(font, Vector2(0.0, font.get_ascent(TALLY_SIZE) * 0.5), line,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TALLY_SIZE, ink)
	draw_set_transform(Vector2.ZERO)
	if _tally_face != null and _slots.has(_tally_face):
		var slot: Control = _slots[_tally_face]
		var want := Vector2(start + TALLY_GLYPH_X, _tally_y) - Vector2.ONE * (TALLY_GLYPH * 0.5)
		if slot.position != want:
			slot.position = want

## The tally's run, its little mushroom and its line, in pixels.
func _tally_run() -> float:
	var font: Font = CozyTheme.display(700)
	return font.get_string_size(_tally_line(state.left()), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		TALLY_SIZE).x + TALLY_TEXT_X

## The tally's scale at `now`: its pop in with the field, and its bump when it
## recounts.
func _tally_grow(now: float) -> Vector2:
	return Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY) \
		* Motion.bump_scale(now - _tally_at, Motion.BUMP * 0.4)

## The tally's paper pill under its run, washed with how the count stands,
## growing about the run's own centre with the tally's pop and bump.
func _tally_pill(b: Face.Builder, now: float) -> void:
	var grow := _tally_grow(now)
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var left := state.left()
	var paper: Color = Pal.SURFACE
	if left == 0:
		paper = Pal.LEAF_TILE
	elif left < 0:
		paper = Pal.BAD_TILE
	var box := Vector2(_tally_run(), TALLY_GLYPH) + PILL_PAD * 2.0
	var xf := Transform2D(0.0, grow, 0.0, Vector2(size.x * 0.5, _tally_y))
	var corner := -box * 0.5
	b.fan(xf * Face.Builder.round_rect(corner + Vector2(0.0, PILL_EDGE), box, box.y * 0.5),
		Color(Pal.LINE, 0.55))
	b.fan(xf * Face.Builder.round_rect(corner, box, box.y * 0.5), paper)

## How many mushrooms are still hidden, in words; nought is *every mushroom
## is planted*, and an over-planted field says so rather than clamping.
func _tally_line(left: int) -> String:
	if left > 0:
		return tr("MP_TALLY_ONE") if left == 1 else tr("MP_TALLY_N") % _word(left)
	if left == 0:
		return tr("MP_TALLY_ALL")
	return tr("MP_TALLY_OVER") % _word(-left)

## `k` in words while there is a word for it, and as a numeral past that.
## Counting in words is a choice about how the strip and the sprout read;
## clamping at fourteen would have been a choice to state a number the board
## knows is false -- on hard a player can plant fifty-two wrong marks, and
## "Fourteen marks are wrong" is worse than a numeral, not better.
func _word(k: int) -> String:
	if k < 0 or k >= WORDS:
		return str(k)
	return tr("MP_NUM_%d" % k)

func _layout_tally() -> void:
	if _tally_face == null or not _slots.has(_tally_face):
		return
	_seat(_tally_face, Vector2(size.x * 0.5, _tally_y), TALLY_GLYPH)

## Everything standing on the field, in one mesh: the blushes, the soft discs
## under the mushrooms, the pebbles on their way out and the pebbles that are
## here.
func _build_ground(now: float) -> Dictionary:
	var b := Face.Builder.new()
	var busy := not _sunk.is_empty()
	_tally_pill(b, now)
	# The blush: toward the family's rose and back.
	var gone: Array = []
	for cell in _blush:
		var e: float = now - float(_blush[cell])
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			gone.append(cell)
			continue
		busy = true
		var side := _cell * (1.0 - 2.0 * CELL_INSET)
		b.fan(Face.Builder.round_rect(cell_centre(cell) - Vector2.ONE * (side * 0.5),
			Vector2.ONE * side, _cell * CELL_RADIUS),
			Color(Pal.BAD, BLUSH_ALPHA * Motion.flash_level(e)))
	for cell in gone:
		_blush.erase(cell)
	# The soft discs under the mushrooms, anchored at the cell and read off
	# each face's own scale and alpha, so one arrives with the pop and stays
	# put when she hops.
	for cell in _caps:
		var face: MushroomFace = _caps[cell]
		if not face.visible:
			continue
		var seen := clampf(face.scale.y, 0.0, 1.0) * clampf(face.modulate.a, 0.0, 1.0)
		if seen <= 0.0:
			continue
		Scenery.soft_disc(b, cell_centre(cell) + SHADOW_AT * _cell,
			SHADOW_RX * _cell * seen, SHADOW_RY * _cell * seen,
			Color(Pal.TEXT, SHADOW_ALPHA * seen))
	# Pebbles on their way out, drawn from the shape the state has forgotten.
	var still: Array = []
	for out in _pebble_out:
		var e: float = now - float(out.at)
		var shrunk := Motion.pop_out_scale(e)
		if shrunk <= 0.0:
			continue
		still.append(out)
		busy = true
		var turn := PI * 0.5 * clampf(e / Motion.POP_OUT, 0.0, 1.0)
		Mosaic.pebble(b, cell_centre(out.cell), _pebble_px(), Vector2.ONE * shrunk, 1.0, turn)
	_pebble_out = still
	# The pebbles that are here: waiting for their wave, popping in with the
	# squash, standing, shivering when refused or wobbling under Check.
	gone = []
	var shook: Array = []
	for cell in state.marks:
		if int(state.marks[cell]) != State.CLEAR:
			continue
		var seen := _entered(cell, now)
		if seen <= 0.0:
			continue
		var grow := Vector2.ONE
		if _pebble_in.has(cell):
			var e: float = now - float(_pebble_in[cell])
			if e < 0.0:
				busy = true
				continue
			grow = Motion.pop_in_scale(e)
			if e < Motion.POP_IN:
				busy = true
			else:
				gone.append(cell)
		grow *= _sink(cell, now)
		if _solved_at >= 0.0:
			# The pebbles clear away in the solve wave, leaving the patch to
			# the mushrooms and their numbers.
			grow *= Motion.pop_out_scale(now - _solved_at - _solve_delay(cell))
			busy = true
		if grow.x <= 0.0 or grow.y <= 0.0:
			continue
		var at := cell_centre(cell)
		var since: float = now - float(_shiver.get(cell, -100.0))
		if since < Motion.SHIVER_TIME:
			busy = true
			at.x += Motion.shiver_offset(since, _cell * SHIVER)
		elif _shiver.has(cell):
			shook.append(cell)
		var turn := Motion.wobble_angle(now - float(_wobble.get(cell, -100.0)))
		if turn != 0.0:
			busy = true
		Mosaic.pebble(b, at, _pebble_px(), grow, seen, turn)
	for cell in gone:
		_pebble_in.erase(cell)
	for cell in shook:
		_shiver.erase(cell)
	if b.verts.is_empty():
		return {"mesh": null, "busy": busy}
	return {"mesh": b.mesh(), "busy": busy}

## The cell Mosaic.pebble is handed. It measures everything off that cell and
## draws its body at Mosaic.PEBBLE_R of it; this board's mock draws a pebble
## PEBBLE of a cell in its own R, PEBBLE_BODY of that across, so the cell it
## is handed is scaled to put it there.
func _pebble_px() -> float:
	return _cell * PEBBLE * PEBBLE_BODY / Mosaic.PEBBLE_R

## press_scale for the cell under the finger, one when it is not.
func _sink(cell: Vector2i, now: float) -> float:
	if not _sunk.has(cell):
		return 1.0
	var pr: Dictionary = _sunk[cell]
	var released := -1.0 if now < float(pr.up) else now - float(pr.up)
	return Motion.press_scale(now - float(pr.down), released)

# --- the moments ---

## The chrome is the host's; here the field pops in wide after the family's
## delay, its cells fading in in a diagonal wave. Nothing stands on it yet.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP
		+ Motion.stagger(2 * state.n - 2, Motion.ENTER_STAGGER))
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

## Every cell of the field as the state marks it now: what _settle diffs
## against after a move.
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			out[cell] = int(state.marks.get(cell, State.BLANK))
	return out

## Every cell whose mark differs between `before` (a _snapshot) and the state
## now takes its moment -- a mushroom pops in (or drops in, from a hint) or
## shrinks out, a pebble pops in or shrinks out -- `delay_of.call(cell,
## leaving)` seconds after `t`. **And every given whose standing changed bumps
## and takes its wash**: this is the wash's only entry point, so a number can
## never go green by any route but a move that was actually made. Returns the
## second each changed cell's piece arrives, for the sinks to wait on.
func _settle(before: Dictionary, t: float, delay_of: Callable, drop := false) -> Dictionary:
	var arrivals: Dictionary = {}
	var planted_before := 0
	for cell in before:
		if int(before[cell]) == State.FOUND:
			planted_before += 1
	for cell in before:
		var prev := int(before[cell])
		var mark := int(state.marks.get(cell, State.BLANK))
		if prev == mark:
			continue
		var going: float = t + float(delay_of.call(cell, true))
		var coming: float = t + float(delay_of.call(cell, false))
		# The sod lifts off as a mark lands in a covered cell and settles back
		# as the last mark leaves it; a mushroom swapped for a pebble keeps
		# the bed open.
		if not Motion.reduce and not state.given.has(cell):
			if prev == State.BLANK:
				_sod[cell] = {"at": coming, "back": false}
				_busy_for(coming - t + SOD_TIME)
			elif mark == State.BLANK:
				# Once the piece leaving it is most of the way gone.
				var back := going + SOD_BACK_LAG
				_sod[cell] = {"at": back, "back": true}
				_busy_for(back - t + Motion.POP_IN)
		if prev == State.FOUND:
			_cap_down(cell, going - t)
		elif prev == State.CLEAR:
			_pebble_leaves(cell, going)
		if mark == State.FOUND:
			_cap_up(cell, coming - t, drop)
			arrivals[cell] = coming
		elif mark == State.CLEAR:
			_pebble_arrives(cell, coming)
			arrivals[cell] = coming
	_settle_wash(before, t, delay_of)
	var planted := 0
	for cell in state.marks:
		if int(state.marks[cell]) == State.FOUND:
			planted += 1
	if planted != planted_before:
		_recount()
	_refresh_faces()
	return arrivals

## The tally has a new count: its pill bumps and its little mushroom hops.
func _recount() -> void:
	if Motion.reduce:
		return
	_tally_at = _now()
	_busy_for(Motion.BUMP_TIME)
	if _tally_face != null:
		_hop(_tally_face, Motion.HOP, Motion.HOP_TIME)

## The count wash, after a move: every given whose standing changed takes the
## colour its new standing asks for, crossing from the one it wore, and its
## numeral bumps. A given of nought is left alone unless the change is to or
## from OVER -- it draws no numeral and takes no green, so a bump and a wash
## on it would be a beat with nothing behind it.
func _settle_wash(before: Dictionary, t: float, delay_of: Callable) -> void:
	for g in state.given:
		var was := _standing_in(before, g)
		var is_now: int = state.standing(g)
		if was == is_now:
			continue
		if int(state.given[g]) == 0 and was != State.OVER and is_now != State.OVER:
			continue
		var at: float = t + float(delay_of.call(g, false))
		var worn := _worn(g, t, was)
		_wash[g] = {"at": at, "colour": worn.colour, "level": float(worn.level),
			"ink": worn.ink}
		if not Motion.reduce:
			_bump[g] = at
			# A number that has just come right catches the light.
			if is_now == State.SETTLED and int(state.given[g]) > 0:
				_glint[g] = at + GLINT_LAG
		_busy_for(at - t + maxf(WASH_TIME, GLINT_LAG + GLINT_TIME))

## `g`'s standing read off a snapshot rather than off the state: what the
## number said before the move. The state's own standing() reads `marks`,
## which the move has already changed.
func _standing_in(before: Dictionary, g: Vector2i) -> int:
	var need: int = int(state.given[g])
	var have := 0
	for p in State.Gen.neighbours(g, state.n):
		if int(before.get(p, State.BLANK)) == State.FOUND:
			have += 1
	if have > need:
		return State.OVER
	return State.SETTLED if have == need else State.SHORT

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

## A mushroom is planted on `cell`: she pops in with the squash after
## `delay`, or drops in from above when a hint planted her.
func _cap_up(cell: Vector2i, delay: float, drop: bool) -> void:
	var face := _cap_node(cell)
	face.visible = true
	Motion.stop(_look_tw.get(face))
	Motion.stop(_pos_tw.get(face))
	face.rotation = 0.0
	face.position = Vector2.ZERO
	face.modulate.a = 1.0
	_set_expr(face, Face.Expr.HAPPY)
	if drop:
		face.scale = Vector2.ONE
		_pos_tw[face] = Motion.drop_in(face, Motion.DROP, Motion.DROP_TIME, delay)
		_busy_for(delay + Motion.DROP_TIME)
	else:
		_look_tw[face] = Motion.pop_in(face, Motion.POP_IN, delay)
		_busy_for(delay + Motion.POP_IN)

## A mushroom is pulled up off `cell`: she shrinks to nothing with the quarter
## turn after `delay` and is hidden once gone, unless something planted her
## again.
func _cap_down(cell: Vector2i, delay: float) -> void:
	var face: MushroomFace = _caps.get(cell)
	if face == null:
		return
	Motion.stop(_look_tw.get(face))
	Motion.stop(_pos_tw.get(face))
	face.position = Vector2.ZERO
	face.modulate.a = 1.0
	var tw := Motion.pop_out(face, Motion.POP_OUT * 1.5, delay, _cell * PLUCK)
	if tw == null:
		face.visible = false
		return
	_look_tw[face] = tw
	_busy_for(delay + Motion.POP_OUT * 1.5)
	tw.chain().tween_callback(func() -> void:
		if int(state.marks.get(cell, State.BLANK)) != State.FOUND:
			face.visible = false
			face.rotation = 0.0
			face.position = Vector2.ZERO)

func _pebble_arrives(cell: Vector2i, at: float) -> void:
	_pebble_in[cell] = at
	_busy_for(at - _now() + Motion.POP_IN)

## A pebble leaves `cell` at `at`. Under reduce-motion it is simply gone, as
## pop_out would have it.
func _pebble_leaves(cell: Vector2i, at: float) -> void:
	_pebble_in.erase(cell)
	_shiver.erase(cell)
	if Motion.reduce:
		return
	_pebble_out.append({"cell": cell, "at": at})
	_busy_for(at - _now() + Motion.POP_OUT)

## A cell blushes toward the family's rose and settles: Check pointing at a
## mark on it, or a press refused on it.
func _blush_cell(cell: Vector2i) -> void:
	if Motion.reduce:
		return
	_blush[cell] = _now()
	_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)

## `face` hops `height` over `time` after `delay`; she rests at her slot's
## origin, so the base is always zero.
func _hop(face: Control, height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_pos_tw.get(face))
	face.position = Vector2.ZERO
	# A drop's fade is stopped here too (drop_in and hop share _pos_tw), and
	# it must not be left half done: a hop always finds her fully seen.
	face.modulate.a = 1.0
	_pos_tw[face] = Motion.hop(face, height, time, delay, 0.0)
	_busy_for(delay + time)

## Check pointing at a mushroom: she wobbles where she stands.
func _wobble_cap(face: Control) -> void:
	Motion.stop(_look_tw.get(face))
	face.rotation = 0.0
	face.scale = Vector2.ONE
	_look_tw[face] = Motion.wobble2d(face)
	_busy_for(Motion.WOBBLE_TIME)

## A press refused on a given: the cell shivers and blushes, and the sprout
## says why. There is nothing there to be right or wrong about, which is the
## only reason this board ever turns a move down -- a *wrong* mark is never
## refused, or tapping every cell in turn would read the answer off what
## stuck.
func _refuse_given(cell: Vector2i) -> void:
	_say(tr("MP_TURNED"), Face.Expr.STRAIN)
	fx.cue("locked")
	if Motion.reduce:
		return
	_shiver[cell] = _now()
	_blush_cell(cell)
	_busy_for(Motion.SHIVER_TIME)

## A press refused on a hint's mushroom, with either chip: she shivers and
## strains for a beat while her cell blushes, and the sprout says why.
func _refuse_pinned(cell: Vector2i) -> void:
	_say(tr("MP_PINNED"), Face.Expr.PUZZLED)
	fx.cue("locked")
	_blush_cell(cell)
	var face: MushroomFace = _caps.get(cell)
	if face == null:
		return
	# The face is the refusal's answer and not its decoration: reduce-motion
	# stills the shiver, the blush and the ring (spec section 10), and a
	# player who has reduce-motion on would otherwise get no answer at all.
	_set_expr(face, Face.Expr.STRAIN)
	_after(STRAIN_TIME, func() -> void:
		if face.expression == Face.Expr.STRAIN and _solved_at < 0.0:
			face.expression = Face.Expr.HAPPY)
	if Motion.reduce:
		return
	_shiver[cell] = _now()
	Motion.stop(_pos_tw.get(face))
	face.position = Vector2.ZERO
	face.modulate.a = 1.0
	_pos_tw[face] = Motion.shiver(face, _cell * SHIVER)
	_busy_for(Motion.SHIVER_TIME)

# --- input ---

## Touch and drag only, as every flat board takes them. With the mushroom
## chip a tap plants or pulls up on the cell it was pressed on, and only if
## the finger is let go over that cell; with the pebble chip a tap lays or
## rubs out, and a drag sweeps.
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
	var mark := int(state.marks.get(cell, State.BLANK))
	# A mushroom under the finger sinks whichever chip is armed: every
	# tappable piece takes the press, including one that will do nothing on
	# release.
	if mark == State.FOUND and _caps.has(cell):
		_pressed = _caps[cell]
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, true)
	if brush == State.FOUND:
		_sink_cell(cell)
	else:
		# The stroke's job is read off the cell it began on: a stroke that
		# begins on the player's own pebble rubs out, any other lays.
		_lay = mark != State.CLEAR
		_paint(cell, true)
	_redraw()

## The mushroom under the finger springs back.
func _release_press() -> void:
	if _pressed == null:
		return
	if is_instance_valid(_pressed):
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, false)
		_busy_for(Motion.RELEASE_TIME)
	_pressed = null

## With the pebble chip, every cell between the last one painted and this one
## is swept, so a fast finger leaves no holes. **No line lock**: this field's
## deductions run round a number as often as along a row. The mushroom chip
## does not sweep and does not place on release either -- see below.
func _drag(at: Vector2) -> void:
	# The mushroom chip does not sweep and does not follow the finger either:
	# the gesture is abandoned if it leaves the cell it pressed, which is
	# Queens' rule and every other flat board's. A slide that committed a
	# placement is how a scroll becomes an accidental move on a phone, and
	# this would be the only board where that happened.
	if brush != State.CLEAR:
		return
	var cell := _cell_at(at)
	if cell.x < 0 or cell == _last_paint:
		return
	_dragged = true
	if _last_paint.x >= 0:
		var steps := maxi(absi(cell.x - _last_paint.x), absi(cell.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(roundi(lerpf(_last_paint.x, cell.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, cell.y, float(i) / steps))))
	_paint(cell)
	_redraw()

## A stroke paints a cell once. The cell the finger landed on (`pressed`)
## always takes the press, even a given's or a planted one's, which the
## stroke cannot change; a cell the stroke only passes over sinks only when it
## can change it, Light Up's own rule for a sweep. A stroke runs past a given
## and a planted mushroom without stopping and without refusing.
func _paint(cell: Vector2i, pressed := false) -> void:
	if not _in_field(cell):
		return
	_last_paint = cell
	if _swept.has(cell):
		return
	_swept[cell] = true
	if pressed:
		_sink_cell(cell)
	if state.given.has(cell) or state.pinned.has(cell):
		return
	var mark := int(state.marks.get(cell, State.BLANK))
	if _lay:
		if mark != State.BLANK:
			return
	elif mark != State.CLEAR:
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
	if brush == State.CLEAR and was_drag:
		if not pending.is_empty():
			var before := _snapshot()
			var changed: Array = state.sweep(pending, lay)
			var arrivals := _settle(before, now, _along(pending))
			_end_sinks(now, arrivals)
			if not changed.is_empty():
				# One stroke is one move, however many cells it crossed, and
				# a sweep puffs none of its pebbles.
				fx.cue("place")
				_speak()
				_redraw()
				note_move()
				return
		_end_sinks(now)
		_redraw()
		return
	_end_sinks(now)
	# A press is a tap only if it is let go on the cell it landed on; a
	# finger that wandered off has changed its mind.
	if at_cell == cell:
		_tap(cell, now)
	_redraw()

## The armed chip on `cell`. The state answers with a reason code and this
## answers the reason: a given and a hint's mushroom are refused, a pebble
## aimed at a planted mushroom does nothing at all (Queens' rule -- a pebble
## must never be the thing that lifts a mushroom), and anything else is a
## move.
func _tap(cell: Vector2i, now: float) -> void:
	var before := _snapshot()
	var why: int = state.place(cell, brush)
	match why:
		State.GIVEN:
			_refuse_given(cell)
			return
		State.PINNED:
			_refuse_pinned(cell)
			return
		State.COVERED:
			return
	_settle(before, now, _at_once())
	var at := cell_centre(cell)
	var mark := int(state.marks.get(cell, State.BLANK))
	# A mark on a covered cell throws its sod off in a puff of turf.
	var dug: bool = int(before.get(cell, State.BLANK)) == State.BLANK
	if mark == State.FOUND:
		fx.ring(at, _cell * RING_R, Pal.SUN_RAY)
		fx.puff(at, Pal.TURF if dug else Pal.LEAF)
		fx.cue("place")
	elif mark == State.CLEAR:
		fx.puff(at, Pal.TURF if dug else Pal.SOCKET_PEBBLE)
		fx.cue("place")
	else:
		fx.cue("remove")
	_speak()
	note_move()

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

## What the tip card says: the rules while the field is bare, then how many
## mushrooms are planted and how many are to go.
func _speak() -> void:
	if is_done():
		return
	var planted: int = state.mushrooms.size() - state.left()
	var left: int = state.left()
	if planted <= 0:
		_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)
		return
	if left > 0:
		_say(tr("MP_FOUND_ONE") % _word(left) if planted == 1
			else tr("MP_FOUND_N") % [_word(planted), _word(left)], Face.Expr.HAPPY)
		return
	_say(tr("MP_MISPLACED"),
		Face.Expr.STRAIN)

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

## Takes back the last gesture, however many cells it painted, in a wave along
## the cells it touched. Counts no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	var cells: Array = state.undo()
	_settle(before, now, _along(cells) if cells.size() > 1 else _at_once())
	_speak()
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Plants the answer's next mushroom in reading order and pins it: a ring
## pulses out of the cell, she drops in from above, sparkles rise, and she
## wears a leaf sprig from then on. Counts no move but can finish the patch.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	hints_used += 1
	_settle(before, now, _at_once(), true)
	var at := cell_centre(target)
	fx.ring(at, _cell * RING_R, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_say(tr("MP_HINT"), Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every mark that contradicts the patch wobbles and its cell blushes -- a
## mushroom on bare ground **and** a pebble on a mushroom, checked both ways,
## since a wrong pebble is exactly as wrong as a wrong mushroom. It plants
## nothing and rubs nothing out. The pebble counts for nothing towards the
## win, but it is still a claim, and Check answers claims.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: Array = state.wrong_marks()
	for cell in wrong:
		if int(state.marks.get(cell, State.BLANK)) == State.FOUND and _caps.has(cell):
			_wobble_cap(_caps[cell])
		else:
			_wobble[cell] = _now()
			_busy_for(Motion.WOBBLE_TIME)
		_blush_cell(cell)
	if not wrong.is_empty():
		var count := wrong.size()
		_say(tr("MP_WRONG_ONE") if count == 1 else tr("MP_WRONG_TWO") if count == 2
			else tr("MP_WRONG_N") % _word(count).capitalize(), Face.Expr.STRAIN)
	elif state.marks.is_empty():
		_say(tr("MP_PLANT_FIRST"), Face.Expr.HAPPY)
	else:
		_say(tr("MP_ALL_RIGHT"), Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_redraw()
	return wrong.size()

## Everything the player laid shrinks out in a wave from the far corner; a
## hint's mushroom hops and stays. Hints spent are not refunded.
func reset_board() -> void:
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	state.reset_board()
	var wave := _from_far_corner()
	_settle(before, now, wave)
	if not Motion.reduce:
		for cell in state.pinned:
			if _caps.has(cell):
				_hop(_caps[cell], Motion.RESET_HOP, Motion.HOP_TIME,
					float(wave.call(cell, false)))
	_blush = {}
	_shiver = {}
	_wobble = {}
	moves = 0
	_running = true
	_say(tr("MP_RESET"), Face.Expr.HAPPY)
	fx.cue("reset")
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## One mushroom in JOY, and the words. The board stays on the card as it
## slides down, every mushroom planted and every number green.
func flat_win() -> Dictionary:
	return {"faces": [MushroomFace.new()], "subtitle": tr("MP_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The mushrooms hop in the family's wave along the diagonal with JOY and a
## spark each, and the pebbles clear away in the same wave, leaving the patch
## to the mushrooms and their numbers -- every one of which is already green.
func _on_solved() -> void:
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	_tip_timer.stop()
	_solved_at = now
	_blush = {}
	_shiver = {}
	_wobble = {}
	var k := 0
	for cell in state.mushrooms:
		var face := _cap_node(cell)
		var delay := _solve_delay(cell)
		_hop(face, Motion.SOLVE_HOP, Motion.SOLVE_TIME, delay)
		_grin(face, delay)
		_after(delay, _spark_at.bind(k, cell_centre(cell)))
		k += 1
	# A light crosses the patch along the diagonal behind the hops.
	if not Motion.reduce:
		for y in state.n:
			for x in state.n:
				_glint[Vector2i(x, y)] = now + WIN_GLINT_AT + float(x + y) * WIN_GLINT_STEP
		_busy_for(WIN_GLINT_AT + float(2 * state.n - 2) * WIN_GLINT_STEP + GLINT_TIME)
	_say(tr("MP_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_busy_for(_solve_delay(Vector2i(state.n, state.n)) + Motion.SOLVE_TIME)
	_redraw()

## A completed daily is rebuilt from its seed, so it opens on a bare patch.
## Plant every mushroom of the answer and settle the patch as it stands once
## the solve's wave has passed: every mushroom standing in JOY, every number
## in its settled green, the entrance over and no moment still owed. Not
## check_solved(): the host owns the win screen and `solved` must not fire a
## second time.
func restore_completed_board() -> void:
	var now := _now()
	_stop_all()
	_clear_gesture()
	_tip_timer.stop()
	state.marks = {}
	for cell in state.mushrooms:
		state.marks[cell] = State.FOUND
	state.pinned = {}
	state.history = []
	_pebble_in = {}
	_pebble_out = []
	_wash = {}
	_bump = {}
	_blush = {}
	_shiver = {}
	_wobble = {}
	_sunk = {}
	_sod = {}
	_glint = {}
	_tally_at = -100.0
	_opened = now - 10.0
	_solved_at = now - 10.0
	_anim_until = 0.0
	_tail = false
	for cell in state.mushrooms:
		var face := _cap_node(cell)
		face.visible = true
		face.scale = Vector2.ONE
		face.rotation = 0.0
		face.position = Vector2.ZERO
		face.modulate.a = 1.0
		face.sprig = false
		_set_expr(face, Face.Expr.JOY)
	_say(tr("MP_WIN"), Face.Expr.JOY)
	_layout()
	_redraw()

func _solve_delay(cell: Vector2i) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.SOLVE_DELAY + Motion.stagger(cell.x + cell.y, Motion.SOLVE_STAGGER)

## `face` goes to JOY as the wave reaches her; at once under reduce-motion.
func _grin(face: Face, delay: float) -> void:
	if delay <= 0.0:
		face.expression = Face.Expr.JOY
	else:
		_after(delay, func() -> void: face.expression = Face.Expr.JOY)

## A spark as mushroom `k` hops, the two pools used in turn so a run of twelve
## a few hundredths apart does not recycle one pool fast enough to cut each
## burst in half.
func _spark_at(k: int, at: Vector2) -> void:
	if k % 2 == 0:
		fx.sparkle(at, Pal.SUN)
	else:
		fx.puff(at, Pal.SUN, 4)

# --- odds and ends ---

## Now and then one planted mushroom sways on her root, so a patch left alone
## still breathes. Only a mushroom with nothing else moving her takes it, and
## the sway is her own node turning: nothing on the field is rebuilt for it.
func _sway() -> void:
	if Motion.reduce or _cell <= 0.0:
		return
	var standing: Array = []
	for cell in _caps:
		var face: MushroomFace = _caps[cell]
		if face.visible and face != _pressed \
				and int(state.marks.get(cell, State.BLANK)) == State.FOUND \
				and not _tweening(_look_tw.get(face)) and not _tweening(_pos_tw.get(face)):
			standing.append(face)
	if standing.is_empty():
		return
	var face: MushroomFace = standing[randi() % standing.size()]
	_look_tw[face] = Motion.wobble2d(face, SWAY_ANGLE, SWAY_TIME)

static func _tweening(tw) -> bool:
	return tw != null and (tw as Tween).is_valid() and (tw as Tween).is_running()

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at a mushroom that is
## gone.
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
