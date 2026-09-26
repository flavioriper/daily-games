extends "res://core/puzzle_base.gd"

## Shikaku as a flat board: a field of garden beds on the host's parchment
## card, fenced along the seams of the partition, with a signpost marker
## standing in every clue's cell. Built beside the island version
## (legacy/puzzles/shikaku3d.gd) so the two could be judged against each
## other on the phone; the rules live in puzzles/shikaku_state.gd, which this
## only draws.
##
## This is the board the camera costs most. Shikaku is counting -- you count
## cells against a number and read whether two plots share one boundary --
## and at the island's seven-degree pitch a cell at the back of the field is
## a fraction of the height of one at the front, so counting a three-by-three
## at the top is not the same act as counting one at the bottom. Flat, every
## cell is the same square.
##
## How it is drawn. Nothing here is a node per cell: the ground and its grid
## are one cached ArrayMesh, each bed with its furrows is another, the whole
## fence is a third and the markers' shadows a fourth, so a hard board of
## sixty-three cells costs about sixteen draw commands rather than hundreds.
## The meshes are built through Face.Builder, which is the same tool the
## characters are drawn with and the only one that feathers its shapes --
## MSAA is off for the 2D canvas, so an unfeathered draw_rect would be the
## one hard edge on the screen. A bed is built in its own centre's space, so
## its pop is a transform on the draw and never a rebuild, and the cache is
## keyed by the plot itself, so a commit builds the one bed it drew and
## re-uses the rest.
##
## How it moves. The markers are nodes and take the flat boards' vocabulary
## (core/motion.gd, docs/art/flat-motion.md) straight: pop in along the
## diagonal, hop when their bed lands, lean away from a neighbour's, wobble
## on Check, shiver when they refuse. The beds, the field and the rectangle
## under the finger are drawn, so they read the same recipes as curves
## (Motion.pop_in_scale and its siblings; the doc's rule 8) and never copy a
## number. The crop coming up on the win is this board's own signature; the
## earth thrown at a new bed's corners its placement puff.
## Spec: docs/superpowers/specs/2026-09-18-shikaku-flat-design.md, sections 3
## to 7 and the amendment at its end, and the mock it is ported from
## (docs/brainstorm/concepts.html#shikaku).

const State = preload("res://puzzles/shikaku_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const MarkerFace = preload("res://ui/faces/marker_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## Layout, in the board card's inner pixels (spec section 5).
const PAD := 34.0
const GROUND_RADIUS := 18.0
## The field stands on the parchment the way every card does: on a bottom
## edge of the family's six (docs/art/flat-motion.md, the dressing).
const GROUND_EDGE := 6.0
const GRID_WIDTH := 2.0
const GRID_ALPHA := 0.8
## The marker, as a fraction of a cell, and how far above the cell's centre
## it stands so its stake reads as planted in the ground.
const MARKER := 0.86
const MARKER_LIFT := 0.05
## The marker's shadow on the ground, in the marker's seat: the family's soft
## disc under the foot of its stake, built into one mesh so a hopping marker
## leaves it where it stood. The peak is above the family's band because a
## disc that fades to its rim reads at about half its centre: measured, 0.14
## left the foot floating where the old flat ellipse at 0.10 grounded it.
const SHADOW_AT := Vector2(0.0, 0.54)
const SHADOW_RX := 0.34
const SHADOW_RY := 0.1
const SHADOW_ALPHA := 0.2
## A bed: a raised plot of tilled earth inset from its cells, standing on a
## lip of darker soil, with the inner line a pinned one takes.
const BED_INSET := 2.0
const BED_RADIUS := 10.0
const BED_BLUSH_MIX := 0.55
const BED_LIP := 0.035
const BED_LIP_MIN := 3.0
## The till: two mounds of earth along every row of a bed, broken at every
## column seam, so a bed's cells can still be counted after it has covered
## the grid lines. A mound is a round-ended hump a shade lighter than the
## soil, over the shadow it throws and under a thin lit crest. Positions and
## widths are in cells.
const RIDGES := [0.34, 0.7]
const RIDGE_MARGIN := 0.12
const RIDGE_WIDTH := 0.11
const RIDGE_MIN := 5.0
const RIDGE_LIGHT := 0.1
const CREST_LIGHT := 0.3
const CREST_SHARE := 0.28
const GROOVE_ALPHA := 0.5
## A new bed is raked in: row after row, each ridge drawn left to right,
## over TILL_TIME in TILL_STEPS cached frames.
const TILL_TIME := 0.36
const TILL_ROW := 0.35
const TILL_STEPS := 10
const LOCK_INSET := 6.0
const LOCK_RADIUS := 8.0
const LOCK_WIDTH := 0.05
const LOCK_MIN := 3.0
const LOCK_ALPHA := 0.85
## The fence: a rail along every seam over its shade, a lit line along its
## top, and a post at every lattice point it passes -- a small one mid-run,
## so a side can be counted cell by cell, and a capped one where runs meet,
## turn or cross.
const FENCE_WIDTH := 0.075
const FENCE_MIN := 5.0
const RAIL_SHARE := 0.72
const RAIL_LIT := 0.28
const POST_SHARE := 0.72
const MID_POST_SHARE := 0.46
const POST_CAP := 0.4
## The fence going up: every new stretch of rail grows out of the post
## nearer where the move began, FENCE_STEP a cell further round, over
## RAIL_TIME, and its far post pops as the rail reaches it. A stretch taken
## away shrinks to its middle over the family's POP_OUT.
const FENCE_STEP := 0.035
const FENCE_WAVE := 0.5
const RAIL_TIME := 0.16
## The rectangle under the finger and the disc carrying its area.
const PEND_ALPHA := 0.22
const PEND_DASH := 0.22
const PEND_GAP := 0.16
const PEND_WIDTH := 0.055
const PEND_MIN := 4.0
## The rectangle glides after the finger rather than jumping cell to cell:
## an exponential ease at PEND_EASE a second. Its dashes crawl round it at
## ANTS a second, in cells.
const PEND_EASE := 26.0
const ANTS := 0.9
const DISC_SHARE := 0.42
const DISC_MAX := 54.0
const DISC_RIM := 5.0
const DISC_TEXT := 1.05
## The crop that comes up when the field is done: a flower a cell, the stem
## SEED_SIZE of a cell tall from its foot at SEED_AT, one colour to a bed.
## A bloom is drawn in SEED_STEPS frames of its own, cached.
const SEED_SIZE := 0.5
const SEED_AT := Vector2(0.5, 0.8)
const SEED_STEPS := 24
const SEED_VARIANTS := 3
## Petal and heart colours, one pair to a bed: pink, butter, daisy, lilac
## and cornflower, all already in the palette.
const BLOOMS := [
	[Pal.FLOWER, Pal.SUN_RAY],
	[Pal.SUN_RAY, Pal.ACORN_DEEP],
	[Pal.SURFACE, Pal.SUN],
	[Pal.SHADOW_TINT, Pal.SUN_RAY],
	[Pal.CLOUD, Pal.SUN_TILE],
]
## Hint count, not refunded by reset (HUD spec, section 3).
const HINTS := 3

# --- motion: what is this board's own ---
## A refused marker's shiver, in its seat; the family's 2 px is a tremor on
## a plaque this size.
const SHIVER := 0.04
## The earth thrown at each corner of a bed that has just been fenced.
const CORNER_STARS := 3
## The planting wave: the beds come up one per PLANT_STEP from the top-left
## (a bed is a row, not a cell, so it is paced like one), the wave never
## longer than PLANT_WAVE, and inside a bed the cells a PLANT_CELL apart,
## each flower blooming over PLANT_TIME.
const PLANT_STEP := 0.1
const PLANT_WAVE := 1.2
const PLANT_CELL := 0.04
const PLANT_TIME := 0.7
## How long the host waits before the win screen: the planting wave has to
## run its length first, and a hard board plants fourteen beds.
const WIN_WAIT := 2.4
## The three lines that teach the gestures, cycled while the field is bare.
## Translation keys (locale/ui.csv), read through tr() when said.
const TIPS := [
	"SK_TIP_DRAG",
	"SK_TIP_REDRAW",
	"SK_TIP_BLUSH",
]
const TIP_CYCLE := 10.0

var state = State.new()
## The win harness and anything else that reads the island board find the
## same names here; they are the state's own, under one roof.
var w: int:
	get: return state.w
var h: int:
	get: return state.h
var _solution: Array:
	get: return state.solution
var _rects: Array[Rect2i]:
	get: return state.rects

var fx: Node2D
## Over the markers: the drag's area disc, which a marker standing inside
## the rectangle would otherwise hide -- and it is the one number the drag
## is for.
var _over: Control
var _markers: Array = []      # [i] -> MarkerFace
## [i] -> the Control the marker stands in. The slot is what the layout
## moves and the face is what the motion moves, so a relayout mid-entrance
## cannot fight the pop: build() lays out before the host has given the
## board a size, and the entrance that starts there would otherwise hold
## every marker at the y it was measured at.
var _slots: Array = []
var _pos_tw: Array = []       # [i] -> the hop, the nudge or the shiver
var _look_tw: Array = []      # [i] -> the pop in, the wobble or the bump
## Whether the markers have been set blinking: once, on the first layout
## with a size, which is the first moment the board is certainly in the tree.
var _idling := false
## Bumped on every rebuild; a pending callback from the last board checks it.
var _gen := 0
## "x_y_w_h_locked_blush_planted" -> the bed's mesh, in its own centre's space.
var _bed_cache: Dictionary = {}
## Growth step and variant -> one seedling's mesh.
var _seed_cache: Dictionary = {}
## Bed key -> its BLOOMS index, filled by _colour_beds once the field is done.
var _blooms: Dictionary = {}
var _ground: ArrayMesh
var _fence: ArrayMesh
## Every stretch of fence standing or on its way, one per unit seam:
## Vector3i(vertical, line, index) -> {"at": when it starts to grow, "from_a":
## whether it grows out of its first lattice point, "gone": when it starts to
## leave, or -1}. The fence mesh is rebuilt off it every frame until
## _fence_until, and cached after.
var _edges: Dictionary = {}
var _fence_until := -1.0e9
var _shadows: ArrayMesh
var _cell := 0.0
var _origin := Vector2.ZERO
## When the board opened, and when its entrance is over: the field pops in
## from the first and the shadows follow the markers' scale until the second.
var _opened := -1.0e9
var _enter_until := -1.0e9

# --- the drag ---
var _drag_from := Vector2i(-1, -1)
var _drag_to := Vector2i(-1, -1)
## When the finger went down, and when the count last changed: the wash and
## the disc pop in from the first, the disc bumps from the second.
var _drag_at := -1.0e9
var _count := 0
var _count_at := -1.0e9
## The pending rectangle's mesh and the rectangle-and-colour it was cut for.
var _pend_mesh: ArrayMesh
var _pend_key := ""
## Where the rectangle is drawn, easing after where it is, and the clock the
## ease last read.
var _pend_px := Rect2()
var _pend_t := 0.0
## The clue the rectangle under the finger last fitted, so its sign bobs once
## as the fit arrives and not on every recount.
var _fit_clue := -1

# --- what the beds are doing ---
## Bed key -> {"at": float, "drop": bool}: a bed arriving, popping in wide
## or (a hint's) dropping in from above.
var _bed_in: Dictionary = {}
## Beds leaving: [{"rect": Rect2i, "mesh": ArrayMesh, "at": float}], drawn
## from their own meshes since the state no longer has them, shrinking to
## nothing from `at`.
var _gone: Array = []
## Bed key -> the msec its blush began: Check pointing at its number, or a
## drag refused on a pinned bed.
var _bed_flash: Dictionary = {}
## The planting wave: the msec each bed starts, and whether it has finished
## and been folded into the bed meshes.
var _plant_at: Dictionary = {}
var _planted := false
## The meshes the last _draw handed over that the next may let go of: a
## canvas command holds a mesh by RID, and a frame rendered before the queued
## redraw is flushed would otherwise draw a freed one (see CLAUDE.md).
var _shown: Array = []

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
## Redraw every frame until this msec: a pop, a drag or the crop coming up.
var _anim_until := 0.0

func puzzle_id() -> String: return "shikaku"
func title() -> String: return "Shikaku"

func rules() -> String:
	return tr("SK_RULES") + ("\n\n" + tr("SK_RULES_SHAPE") if state.has_shapes() else "")

## The lines the sprout cycles: a board with shaped signs leads with them.
func _tips() -> Array:
	return (["SK_TIP_SHAPE"] + TIPS) if state.has_shapes() else TIPS

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_over = Overlay.new()
	_over.name = "Over"
	_over.board = self
	_over.z_index = 1
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_over)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_stop_all()
	state.setup(rng, difficulty)
	_bed_cache = {}
	_bed_in = {}
	_gone = []
	_bed_flash = {}
	_plant_at = {}
	_planted = false
	_edges = {}
	_fence_until = -1.0e9
	_clear_drag()
	_build_markers()
	_layout()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

# --- the markers ---

func _build_markers() -> void:
	for slot in _slots:
		slot.queue_free()
	_markers = []
	_slots = []
	_pos_tw = []
	_look_tw = []
	_idling = false
	for i in state.clues.size():
		var slot := Control.new()
		slot.name = "marker_%d" % i
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		var marker := MarkerFace.new()
		marker.name = "face"
		marker.number = int(state.clues[i].area)
		marker.shape = int(state.clues[i].get("shape", 0))
		# The shadow is the board's, on the ground (see _build_shadows).
		marker.casts = false
		# Nothing until the field is up; _enter pops each one in.
		marker.scale = Vector2.ZERO
		slot.add_child(marker)
		_slots.append(slot)
		_markers.append(marker)
		_pos_tw.append(null)
		_look_tw.append(null)

## Every marker takes the face its state asks for. A face is written only
## when its look changes -- a written face redraws.
func _refresh_markers() -> void:
	for i in _markers.size():
		var marker: MarkerFace = _markers[i]
		var expr := _expression(i)
		if marker.expression != expr:
			marker.expression = expr

## The four states, the four faces: idle smiles, settled beams, a plot of the
## wrong size strains, and one holding two numbers or none is puzzled.
func _expression(i: int) -> int:
	match state.clue_state(i):
		1: return Face.Expr.JOY
		2: return Face.Expr.STRAIN
		3: return Face.Expr.PUZZLED
		_: return Face.Expr.HAPPY

# --- layout ---

## The field is the largest square grid the card holds, centred in it.
func _layout() -> void:
	if state.clues.is_empty():
		return
	_cell = minf((size.x - 2.0 * PAD) / w, (size.y - 2.0 * PAD) / h)
	if _cell <= 0.0:
		return
	_origin = (size - Vector2(_cell * w, _cell * h)) * 0.5
	var seat := _cell * MARKER
	for i in _markers.size():
		var slot: Control = _slots[i]
		var marker: MarkerFace = _markers[i]
		slot.size = Vector2(seat, seat)
		slot.position = _marker_centre(state.clues[i].pos) - slot.size * 0.5
		marker.size = slot.size
		marker.pivot_offset = marker.size * 0.5
		# The face's own place inside the slot is the motion's to own; the
		# layout never writes it, so a resize cannot cut an entrance short.
	# Every mesh is cut to the cell, so a relayout throws all of them away.
	_bed_cache = {}
	_seed_cache = {}
	_ground = _build_ground()
	_fence_sync(Vector2.ZERO, 0.0, true)
	_fence = null
	_shadows = null
	if not _idling:
		_idling = true
		for marker in _markers:
			marker.set_idle(true)
	_refresh_markers()
	_redraw()

## Where a marker's centre stands: its cell's, a touch high, because the
## plaque is the thing being read and the stake goes into the ground.
func _marker_centre(at: Vector2i) -> Vector2:
	return _origin + (Vector2(at) + Vector2(0.5, 0.5 - MARKER_LIFT)) * _cell

## Control-local point over the centre of cell (r, c). The win harness drags
## between these, exactly as it does on the island board.
func cell_to_local(r: int, c: int) -> Vector2:
	return _origin + (Vector2(c, r) + Vector2(0.5, 0.5)) * _cell

## The cell under a control-local point, as (col, row), or (-1, -1) off it.
func _cell_at(local: Vector2) -> Vector2i:
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _origin) / _cell
	var c := int(floor(p.x))
	var r := int(floor(p.y))
	if c < 0 or r < 0 or c >= w or r >= h:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

## A plot's rectangle in board pixels.
func _rect_px(rect: Rect2i) -> Rect2:
	return Rect2(_origin + Vector2(rect.position) * _cell, Vector2(rect.size) * _cell)

## The whole field, in board pixels.
func _field_px() -> Rect2:
	return Rect2(_origin, Vector2(_cell * w, _cell * h))

# --- the meshes ---

## The bare ground on its bottom edge and the faint grid over it, about the
## field's own centre, so its pop on the entrance is a transform.
func _build_ground() -> ArrayMesh:
	var b := Face.Builder.new()
	var field := Vector2(_cell * w, _cell * h)
	var at := -field * 0.5
	# The edge is the card at full height plus its lip and the ground the
	# same card short of it, which is how every card on the flat screens
	# gets its soft foot.
	b.fan(Face.Builder.round_rect(at, field + Vector2(0.0, GROUND_EDGE), GROUND_RADIUS), Pal.LINE)
	b.fan(Face.Builder.round_rect(at, field, GROUND_RADIUS), Pal.BED_GROUND)
	var line := Color(Pal.BED_LINE, GRID_ALPHA)
	for x in range(1, w):
		b.stroke(PackedVector2Array([at + Vector2(x * _cell, 0.0), at + Vector2(x * _cell, field.y)]),
			GRID_WIDTH, line, false, false)
	for y in range(1, h):
		b.stroke(PackedVector2Array([at + Vector2(0.0, y * _cell), at + Vector2(field.x, y * _cell)]),
			GRID_WIDTH, line, false, false)
	return b.mesh()

## Every marker's shadow in one mesh, on the ground under the foot of its
## stake: the family's soft disc, read off the marker's own height so it
## arrives with the pop-in, and anchored at the slot so a hop leaves it
## behind. Rebuilt each frame only while the entrance runs.
func _build_shadows() -> ArrayMesh:
	var b := Face.Builder.new()
	var seat := _cell * MARKER
	for i in _markers.size():
		var marker: Control = _markers[i]
		var slot: Control = _slots[i]
		var seen := clampf(marker.scale.y, 0.0, 1.0)
		if seen <= 0.0:
			continue
		var at: Vector2 = slot.position + slot.size * 0.5 + SHADOW_AT * seat
		Scenery.soft_disc(b, at, SHADOW_RX * seat * seen, SHADOW_RY * seat * seen,
			Color(Pal.TEXT, SHADOW_ALPHA * seen))
	if b.verts.is_empty():
		return null
	return b.mesh()

## One bed: a raised plot of tilled earth inset from its cells on a lip of
## darker soil, two ridges along each of its rows broken at every column, the
## pinned line when a hint drew it, and the crop once the field is planted.
## `till` is how far the rake has come, 0 to 1. Built about the plot's own
## centre, so the pop is a transform.
func _build_bed(rect: Rect2i, lock: bool, blush: bool, planted: bool, till := 1.0) -> ArrayMesh:
	var b := Face.Builder.new()
	var span := Vector2(rect.size) * _cell
	var at := -span * 0.5
	var soil: Color = Pal.BED_SOIL.lerp(Pal.BED_BLUSH, BED_BLUSH_MIX) if blush else Pal.BED_SOIL
	var deep: Color = Pal.BED_FURROW.lerp(Pal.BED_BLUSH, BED_BLUSH_MIX * 0.6) if blush else Pal.BED_FURROW
	var inner := span - Vector2.ONE * 2.0 * BED_INSET
	var lip := maxf(BED_LIP_MIN, _cell * BED_LIP)
	# The lip is the plot at full height and the soil the same plot short of
	# it, the family's soft foot, so the bed stands proud of the ground.
	b.fan(Face.Builder.round_rect(at + Vector2.ONE * BED_INSET, inner, BED_RADIUS), deep)
	b.fan(Face.Builder.round_rect(at + Vector2.ONE * BED_INSET, inner - Vector2(0.0, lip),
		BED_RADIUS), soil)
	var rw := maxf(RIDGE_MIN, _cell * RIDGE_WIDTH)
	var mound: Color = soil.lerp(Pal.SURFACE, RIDGE_LIGHT)
	var crest: Color = soil.lerp(Pal.SURFACE, CREST_LIGHT)
	var groove := Color(deep, GROOVE_ALPHA)
	var rows := rect.size.y
	for k in rows:
		# Each row's rake sets off TILL_ROW of the whole later than the top
		# row's, spread over the rows, and crosses its bed in the rest.
		var start := TILL_ROW * k / maxf(1.0, rows - 1.0)
		var reach := _phase(till, start, start + 1.0 - TILL_ROW) * rect.size.x
		if reach <= 0.0:
			continue
		for c in rect.size.x:
			var grown := clampf(reach - c, 0.0, 1.0)
			if grown <= 0.0:
				break
			var x0 := at.x + (c + RIDGE_MARGIN) * _cell
			var x1 := lerpf(x0, at.x + (c + 1.0 - RIDGE_MARGIN) * _cell, grown)
			for r in RIDGES:
				var y: float = at.y + (k + float(r)) * _cell - lip * 0.5
				b.stroke(PackedVector2Array([Vector2(x0, y + rw * 0.35), Vector2(x1, y + rw * 0.35)]),
					rw, groove)
				b.stroke(PackedVector2Array([Vector2(x0, y), Vector2(x1, y)]), rw, mound)
				var top := y - rw * 0.2
				var pull := minf(rw * 0.5, (x1 - x0) * 0.5)
				if x1 - x0 > rw:
					b.stroke(PackedVector2Array([Vector2(x0 + pull, top), Vector2(x1 - pull, top)]),
						rw * CREST_SHARE, crest)
	if lock:
		b.stroke(Face.Builder.round_rect(at + Vector2.ONE * LOCK_INSET,
			span - Vector2.ONE * 2.0 * LOCK_INSET - Vector2(0.0, lip), LOCK_RADIUS),
			maxf(LOCK_MIN, _cell * LOCK_WIDTH), Color(Pal.LEAF, LOCK_ALPHA), true)
	if planted:
		for x in rect.size.x:
			for y in rect.size.y:
				_seedling(b, at + (Vector2(x, y) + SEED_AT) * _cell, 1.0,
					_seed_variant(rect, x, y), _bloom_of(rect))
	return b.mesh()

# --- the fence ---

## The unit seam `key`'s two lattice points, in cells.
func _edge_ends(key: Vector3i) -> Array:
	if key.x == 1:
		return [Vector2i(key.y, key.z), Vector2i(key.y, key.z + 1)]
	return [Vector2i(key.z, key.y), Vector2i(key.z + 1, key.y)]

## Brings the fence in line with the partition: every seam the state now has
## and the fence does not starts to grow, out of its end nearer `from` (a
## point in cells), FENCE_STEP a cell of distance later than the one before
## it, all of it `delay` from now; every stretch the partition no longer has
## starts to leave on the same wave. `instant` stands the fence as it is,
## with no wave, as a layout or a restored daily wants it.
func _fence_sync(from: Vector2, delay := 0.0, instant := false) -> void:
	var now := _now()
	var still := instant or Motion.reduce
	var live: Dictionary = {}
	for v in 2:
		var lines := (w if v == 1 else h) + 1
		var count := h if v == 1 else w
		for line in lines:
			for index in count:
				if state.is_seam(v == 1, line, index):
					live[Vector3i(v, line, index)] = true
	var far := now
	for key: Vector3i in live:
		var had: Dictionary = _edges.get(key, {})
		if not had.is_empty() and float(had.gone) < 0.0:
			continue
		var ends := _edge_ends(key)
		var a := Vector2(ends[0])
		var b := Vector2(ends[1])
		var near := minf(a.distance_to(from), b.distance_to(from))
		var at := now - 10.0 if still else now + delay + minf(near * FENCE_STEP, FENCE_WAVE)
		_edges[key] = {"at": at, "from_a": a.distance_to(from) <= b.distance_to(from), "gone": -1.0}
		far = maxf(far, at + RAIL_TIME * 2.0 + Motion.POP_IN)
	for key: Vector3i in _edges.keys():
		if live.has(key):
			continue
		var e: Dictionary = _edges[key]
		if float(e.gone) >= 0.0:
			continue
		if still:
			_edges.erase(key)
			continue
		var ends := _edge_ends(key)
		var mid := (Vector2(ends[0]) + Vector2(ends[1])) * 0.5
		e.gone = now + delay + minf(mid.distance_to(from) * FENCE_STEP, FENCE_WAVE)
		far = maxf(far, float(e.gone) + Motion.POP_OUT)
	if not still:
		_fence_until = maxf(_fence_until, far)
		_anim_until = maxf(_anim_until, far)
	_fence = null

## How far a stretch has grown at `now`, 0 to 1 -- and as it leaves, how much
## of it is left.
func _edge_level(e: Dictionary, now: float) -> float:
	if float(e.gone) >= 0.0 and now >= float(e.gone):
		return Motion.pop_out_scale(now - float(e.gone))
	var u := clampf((now - float(e.at)) / RAIL_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)

## The whole fence as it stands at `now`, in the grid's own space: every
## stretch's shade, then every rail and its lit top, then the posts over them.
## A post takes the largest of its stretches' pops -- a growing stretch's
## near post as it sets off, its far one as the rail arrives -- and is capped
## where the fence meets, turns or crosses.
func _build_fence(now: float) -> ArrayMesh:
	var fw := maxf(FENCE_MIN, _cell * FENCE_WIDTH)
	var shades := []
	var rails := []
	var posts: Dictionary = {}   # Vector2i -> scale
	for key: Vector3i in _edges.keys():
		var e: Dictionary = _edges[key]
		var leaving := float(e.gone) >= 0.0 and now >= float(e.gone)
		if leaving and now >= float(e.gone) + Motion.POP_OUT:
			_edges.erase(key)
			continue
		var level := _edge_level(e, now)
		var ends := _edge_ends(key)
		var a := _lattice(ends[0].x, ends[0].y)
		var b := _lattice(ends[1].x, ends[1].y)
		var p0: Vector2
		var p1: Vector2
		if leaving:
			var mid := (a + b) * 0.5
			p0 = mid.lerp(a, level)
			p1 = mid.lerp(b, level)
			for end in ends:
				posts[end] = maxf(float(posts.get(end, 0.0)), level)
		else:
			var start: Vector2i = ends[0] if e.from_a else ends[1]
			var stop: Vector2i = ends[1] if e.from_a else ends[0]
			var t := now - float(e.at)
			posts[start] = maxf(float(posts.get(start, 0.0)), Motion.pop_in_scale(t).x)
			posts[stop] = maxf(float(posts.get(stop, 0.0)), Motion.pop_in_scale(t - RAIL_TIME * 0.8).x)
			p0 = _lattice(start.x, start.y)
			p1 = p0.lerp(_lattice(stop.x, stop.y), level)
		if level <= 0.0 or p0.distance_to(p1) < 0.5:
			continue
		shades.append([p0, p1])
		rails.append([p0, p1, key.x == 1])
	if shades.is_empty() and posts.is_empty():
		return null
	var b := Face.Builder.new()
	var shade := Vector2(0.0, fw * 0.5)
	for s in shades:
		b.stroke(PackedVector2Array([s[0] + shade, s[1] + shade]), fw, Pal.FENCE_DARK)
	var lit: Color = Pal.FENCE_RAIL.lerp(Pal.SURFACE, 0.55)
	for r in rails:
		b.stroke(PackedVector2Array([r[0], r[1]]), fw * RAIL_SHARE, Pal.FENCE_RAIL)
		# The light falls from above, so a lying rail is lit along its top
		# edge; an upright one is seen end on to it and takes none.
		if not r[2]:
			var up := Vector2(0.0, -fw * RAIL_SHARE * 0.22)
			b.stroke(PackedVector2Array([r[0] + up, r[1] + up]), fw * RAIL_SHARE * RAIL_LIT, lit)
	for at: Vector2i in posts:
		var grown: float = posts[at]
		if grown <= 0.0:
			continue
		var big := _is_junction(at)
		var r := fw * (POST_SHARE if big else MID_POST_SHARE) * grown
		var c := _lattice(at.x, at.y)
		b.disc(c + Vector2(0.0, r * 0.35), r, Pal.FENCE_DARK)
		b.disc(c, r, Pal.FENCE_POST if big else Pal.FENCE_RAIL.lerp(Pal.FENCE_POST, 0.5))
		if big:
			b.disc(c + Vector2(-r, -r) * 0.25, r * POST_CAP, lit)
	if b.verts.is_empty():
		return null
	return b.mesh()

## Whether the fence meets, turns or crosses at lattice point `at`, in the
## stretches standing now: the state's own rule for where a post goes.
func _is_junction(at: Vector2i) -> bool:
	var up := at.y > 0 and state.is_seam(true, at.x, at.y - 1)
	var down := at.y < h and state.is_seam(true, at.x, at.y)
	var left := at.x > 0 and state.is_seam(false, at.y, at.x - 1)
	var right := at.x < w and state.is_seam(false, at.y, at.x)
	var count := int(up) + int(down) + int(left) + int(right)
	return count != 2 or not ((up and down) or (left and right))

## A lattice point in the grid's own space.
func _lattice(i: int, j: int) -> Vector2:
	return Vector2(i, j) * _cell

## Dashes along the polyline `pts`, measured by its own arc length so a dash
## rides round a corner rather than restarting at every vertex -- the pending
## rectangle's edge is a rounded rect whose outline points are three pixels
## apart. The dashes have flat ends: a round cap on each of the three hundred
## a hard board carries would cost more triangles than the beds.
##
## The walk is a bounded `for` over the dashes the path has room for, never a
## `while` that advances by a computed step. The first draft was the latter
## and its step could round to zero on a segment boundary, which is not a slow
## frame but an endless one appending vertices until the machine gives out.
##
## `phase` slides the dashes along the path, the crawl. A closed path is cut
## into a whole number of periods, so the dash crossing its first point joins
## up with itself rather than leaving a stub there.
func _dash_path(b, pts: PackedVector2Array, closed: bool, width: float,
		colour: Color, dash: float, gap: float, phase := 0.0) -> void:
	var n := pts.size()
	var period := dash + maxf(gap, 0.0)
	if n < 2 or dash <= 0.0 or period <= 0.0:
		return
	# Arc length at each vertex, so a dash is a pair of distances into it.
	var segs := n if closed else n - 1
	var acc := PackedFloat64Array()
	acc.resize(segs + 1)
	acc[0] = 0.0
	for i in segs:
		acc[i + 1] = acc[i] + (pts[(i + 1) % n] - pts[i]).length()
	var total: float = acc[segs]
	if total <= 0.0:
		return
	if closed:
		var fit := maxf(1.0, roundf(total / period))
		dash *= total / (fit * period)
		period = total / fit
	var shift := fposmod(phase, period) - period
	for k in int(ceil(total / period)) + 1:
		var from := maxf(k * period + shift, 0.0)
		var to := minf(k * period + shift + dash, total)
		if to - from <= 0.0:
			continue
		var out := PackedVector2Array()
		for i in segs:
			var s0: float = acc[i]
			var s1: float = acc[i + 1]
			if s1 <= from or s0 >= to or s1 <= s0:
				continue
			var p0 := pts[i]
			var p1 := pts[(i + 1) % n]
			var span := s1 - s0
			if out.is_empty():
				out.append(p0.lerp(p1, clampf((from - s0) / span, 0.0, 1.0)))
			var end := p0.lerp(p1, clampf((to - s0) / span, 0.0, 1.0))
			if not end.is_equal_approx(out[out.size() - 1]):
				out.append(end)
		if out.size() >= 2:
			b.stroke(out, width, colour, false, false)

## One flower at `at`, `u` of the way through its bloom, drawn into `b` in
## the space it is handed. It comes up in overlapping stages, each on its
## own back ease so every part lands with the family's overshoot: the earth
## heaves, the stem rises with a bend, the leaves unfurl off it, a bud
## swells at the tip and opens into petals that turn as they spread, and the
## heart pops in last.
func _seedling(b, at: Vector2, u: float, variant: int, bloom: int) -> void:
	if u <= 0.0:
		return
	var s := _cell * SEED_SIZE
	var lean := (variant - 1) * 0.16
	var petal: Color = BLOOMS[bloom][0]
	var heart: Color = BLOOMS[bloom][1]
	# The earth heaved up round the foot.
	var heave := Motion.back_out(_phase(u, 0.0, 0.22))
	if heave > 0.0:
		b.ellipse(at + Vector2(0.0, s * 0.02), s * 0.26 * heave, s * 0.08 * heave,
			Color(Pal.BED_FURROW, 0.75))
	# The stem, bending the way the variant leans.
	var rise := Motion.back_out(_phase(u, 0.08, 0.5))
	if rise <= 0.0:
		return
	var tip := at + Vector2(s * lean * 0.5, -s * rise)
	var bend := at + Vector2(s * lean * -0.25, -s * rise * 0.55)
	b.stroke(Face.Builder.bezier2(at, bend, tip, 8), maxf(2.0, s * 0.09), Pal.LEAF)
	# Two leaves, folded up against the stem and opening out to the sides.
	var unfurl := Motion.back_out(_phase(u, 0.3, 0.62))
	if unfurl > 0.0:
		var node := at.lerp(bend, 0.7)
		_leaf(b, node, s * 0.42 * unfurl, lerpf(-1.75, -0.35 - lean, unfurl), Pal.LEAF_LIGHT)
		_leaf(b, node + Vector2(0.0, s * 0.06), s * 0.38 * unfurl,
			lerpf(-1.4, -2.8 - lean, unfurl), Pal.LEAF)
	# The bud, then the head opening out of it.
	var swell := Motion.back_out(_phase(u, 0.42, 0.66))
	var open := Motion.back_out(_phase(u, 0.58, 0.94))
	var r := s * 0.34
	if open > 0.0:
		var n := 5 + variant % 2
		var turn := (1.0 - open) * -0.9 + lean
		for k in n:
			var ang := turn + TAU * k / n - PI * 0.5
			var dir := Vector2.from_angle(ang)
			_petal(b, tip + dir * r * 0.15 * open, r * open, ang, petal)
	elif swell > 0.0:
		b.ellipse(tip + Vector2(0.0, -r * 0.3 * swell), r * 0.42 * swell, r * 0.6 * swell,
			petal.lerp(Pal.LEAF, 0.3))
	var pop := Motion.back_out(_phase(u, 0.72, 1.0))
	if pop > 0.0:
		b.disc(tip, r * 0.36 * pop, heart)
		b.disc(tip + Vector2(-r, -r) * 0.1 * pop, r * 0.13 * pop, Color(Pal.SURFACE, 0.55))

## Where `u` stands inside the stage running from `from` to `to`, 0 to 1.
func _phase(u: float, from: float, to: float) -> float:
	return clampf((u - from) / (to - from), 0.0, 1.0)

## One petal: a round-ended paddle of length `ln` out from `at` along `ang`,
## deepened a shade at the root so the head reads as a cup.
func _petal(b, at: Vector2, ln: float, ang: float, colour: Color) -> void:
	if ln <= 0.5:
		return
	var turn := Transform2D(ang, at)
	var pts := Face.Builder.bezier2(Vector2.ZERO, Vector2(ln * 0.2, -ln * 0.5), Vector2(ln * 0.72, -ln * 0.34), 6)
	pts.append_array(Face.Builder.bezier2(Vector2(ln * 0.72, -ln * 0.34), Vector2(ln * 1.12, 0.0), Vector2(ln * 0.72, ln * 0.34), 8))
	pts.append_array(Face.Builder.bezier2(Vector2(ln * 0.72, ln * 0.34), Vector2(ln * 0.2, ln * 0.5), Vector2.ZERO, 6))
	var out := PackedVector2Array()
	for p in pts:
		out.append(turn * p)
	b.polygon(out, colour)
	b.ellipse(turn * Vector2(ln * 0.28, 0.0), ln * 0.2, ln * 0.12,
		colour.lerp(Pal.FLOWER_DEEP, 0.18))

## One leaf: a lens of length `ln` from `at`, turned by `ang`.
func _leaf(b, at: Vector2, ln: float, ang: float, colour: Color) -> void:
	var turn := Transform2D(ang, at)
	var pts := Face.Builder.bezier2(Vector2.ZERO, Vector2(ln * 0.55, -ln * 0.42), Vector2(ln, 0.0))
	pts.append_array(Face.Builder.bezier2(Vector2(ln, 0.0), Vector2(ln * 0.55, ln * 0.42), Vector2.ZERO))
	var out := PackedVector2Array()
	for p in pts:
		out.append(turn * p)
	b.polygon(out, colour)

## Which of BLOOMS a bed flowers in: worked out for the whole field at once,
## the first time it is asked after the field is done, so no two beds that
## touch (corners included) flower alike.
func _bloom_of(rect: Rect2i) -> int:
	if _blooms.is_empty():
		_colour_beds()
	return int(_blooms.get(_bed_key(rect), 0))

## Greedy, in the beds' own order, each starting from a colour of its own so
## the field is not striped in palette order.
func _colour_beds() -> void:
	var done: Array = []
	for rect: Rect2i in state.rects:
		var taken: Dictionary = {}
		for other: Rect2i in done:
			if rect.grow(1).intersects(other):
				taken[_blooms[_bed_key(other)]] = true
		var start := posmod(hash(rect.position * 31 + rect.size), BLOOMS.size())
		var pick := start
		for k in BLOOMS.size():
			if not taken.has((start + k) % BLOOMS.size()):
				pick = (start + k) % BLOOMS.size()
				break
		_blooms[_bed_key(rect)] = pick
		done.append(rect)

## Which of the three seedling drawings a cell grows, fixed per cell.
func _seed_variant(rect: Rect2i, x: int, y: int) -> int:
	return posmod(hash(Vector2i(rect.position.x + x, rect.position.y + y)), SEED_VARIANTS)

## A seedling's mesh at growth step `step` of SEED_STEPS, about its own foot.
func _seed_mesh(step: int, variant: int, bloom: int) -> ArrayMesh:
	var key := "%d|%d|%d|%d" % [step, variant, bloom, int(_cell)]
	var mesh: ArrayMesh = _seed_cache.get(key)
	if mesh == null:
		var b := Face.Builder.new()
		_seedling(b, Vector2.ZERO, float(step) / SEED_STEPS, variant, bloom)
		mesh = b.mesh()
		_seed_cache[key] = mesh
	return mesh

func _bed_key(rect: Rect2i) -> String:
	return "%d_%d_%d_%d" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

## The bed's mesh, built the first time it is asked for at this state.
func _bed_mesh(i: int) -> ArrayMesh:
	var rect: Rect2i = state.rects[i]
	return _bed_variant(rect, state.locked[i], state.plot_blushes(i))

## A bed's mesh for the look asked for. The blushing variant of a bed that
## is not blushing is what a flash draws over it.
## `till` is the rake's step of TILL_STEPS, the whole bed by default.
func _bed_variant(rect: Rect2i, lock: bool, blush: bool, till := TILL_STEPS) -> ArrayMesh:
	var key := "%s_%d_%d_%d_%d" % [_bed_key(rect), int(lock), int(blush), int(_planted), till]
	var mesh: ArrayMesh = _bed_cache.get(key)
	if mesh == null:
		mesh = _build_bed(rect, lock, blush, _planted, float(till) / TILL_STEPS)
		_bed_cache[key] = mesh
	return mesh

## The rake's step for a bed that arrived `e` seconds ago.
func _till_step(e: float) -> int:
	if Motion.reduce:
		return TILL_STEPS
	return clampi(int(ceil(e / TILL_TIME * TILL_STEPS)), 0, TILL_STEPS)

# --- drawing ---

func _draw() -> void:
	if _cell <= 0.0 or state.clues.is_empty():
		return
	var now := _now()
	var busy := false
	var shown: Array = []
	# The field pops in wide once the chrome has slid in, drawn.
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.ENTER_POP:
		busy = true
	var seen := Motion.appear_level(since)
	if seen > 0.0:
		var grown := Motion.wide_pop_scale(since)
		draw_mesh(_ground, null,
			Transform2D(0.0, Vector2(grown, grown), 0.0, _field_px().get_center()),
			Color(1.0, 1.0, 1.0, seen))
	# Beds on their way out go under the beds that are here: a plot drawn over
	# another lands on top of what it displaced.
	var still: Array = []
	for gone in _gone:
		var e: float = now - float(gone.at)
		var shrunk := Motion.pop_out_scale(e)
		if shrunk <= 0.0:
			continue
		still.append(gone)
		busy = true
		var mesh: ArrayMesh = gone.mesh
		shown.append(mesh)
		draw_mesh(mesh, null, Transform2D(0.0, Vector2(shrunk, shrunk), 0.0,
			_rect_px(gone.rect).get_center()))
	_gone = still
	for i in state.rects.size():
		var rect: Rect2i = state.rects[i]
		var key := _bed_key(rect)
		var px := _rect_px(rect)
		var xf := Transform2D(0.0, px.get_center())
		var tint := Color.WHITE
		var till := TILL_STEPS
		var arrival: Dictionary = _bed_in.get(key, {})
		if not arrival.is_empty():
			var e: float = now - float(arrival.at)
			tint.a = Motion.appear_level(e)
			till = _till_step(e)
			if till < TILL_STEPS:
				busy = true
			if arrival.drop:
				xf.origin.y -= Motion.drop_in_lift(e)
				if e < Motion.DROP_TIME:
					busy = true
				elif till >= TILL_STEPS:
					_bed_in.erase(key)
			else:
				var grown := Motion.wide_pop_scale(e, Motion.POP_IN)
				xf = xf.scaled_local(Vector2(grown, grown))
				if e < Motion.POP_IN:
					busy = true
				elif till >= TILL_STEPS:
					_bed_in.erase(key)
		var bed: ArrayMesh = _bed_mesh(i) if till >= TILL_STEPS \
			else _bed_variant(rect, state.locked[i], state.plot_blushes(i), till)
		draw_mesh(bed, null, xf, tint)
		if _bed_flash.has(key):
			var e: float = now - float(_bed_flash[key])
			var level := Motion.flash_level(e)
			if e < Motion.FLASH_IN + Motion.FLASH_OUT:
				busy = true
			else:
				_bed_flash.erase(key)
			if level > 0.0:
				draw_mesh(_bed_variant(rect, state.locked[i], true), null, xf,
					Color(1.0, 1.0, 1.0, level * tint.a))
		if _plant_at.has(key) and not _planted:
			busy = _draw_crop(i, now) or busy
	# The shadows follow the markers up while they pop in, then stand.
	if _shadows == null or now < _enter_until:
		_shadows = _build_shadows()
		if now < _enter_until:
			busy = true
	if _shadows != null:
		draw_mesh(_shadows, null)
	# The fence is cached while it stands and rebuilt every frame it moves.
	if _fence == null or now < _fence_until:
		_fence = _build_fence(now)
		if now < _fence_until:
			busy = true
	if _fence != null:
		draw_mesh(_fence, null, Transform2D(0.0, _origin))
		shown.append(_fence)
	if _drag_from.x >= 0 and not is_done():
		busy = _draw_pending(now) or busy
		shown.append(_pend_mesh)
	_shown = shown
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## The crop coming up in bed `i`, cell by cell. True while any of it is still
## growing; once the whole field is up it is folded into the bed meshes and
## this stops being drawn at all.
func _draw_crop(i: int, now: float) -> bool:
	var rect: Rect2i = state.rects[i]
	var at: float = _plant_at[_bed_key(rect)]
	var origin := _rect_px(rect).position
	var growing := false
	for x in rect.size.x:
		for y in rect.size.y:
			var u := (now - at - (x + y) * PLANT_CELL) / PLANT_TIME
			if u <= 0.0:
				growing = true
				continue
			if u < 1.0:
				growing = true
			var step := clampi(int(ceil(minf(u, 1.0) * SEED_STEPS)), 1, SEED_STEPS)
			draw_mesh(_seed_mesh(step, _seed_variant(rect, x, y), _bloom_of(rect)), null,
				Transform2D(0.0, origin + (Vector2(x, y) + SEED_AT) * _cell))
	return growing

## The rectangle under the finger: its cells washed in the colour the count
## has earned, under a dashed edge crawling round it, popping in wide as the
## finger lands and gliding after it from cell to cell. The disc carrying the
## count is drawn by the overlay, over the markers. True while any of it is
## still moving.
func _draw_pending(now: float) -> bool:
	var pend := _pending()
	var colour := _pending_colour(pend)
	var px := _pend_rect(now)
	var moving := not px.is_equal_approx(_rect_px(pend))
	var crawl := 0.0 if Motion.reduce else now * ANTS * _cell
	# Cut again only when the drawn rectangle, its colour or the crawl has
	# moved: a finger held still over a still rectangle still crawls, but a
	# reduced one costs one mesh a rectangle. Built about the rectangle's own
	# centre, so the pop is a transform.
	var key := "%d_%d_%s_%d" % [roundi(px.size.x), roundi(px.size.y), colour.to_html(false),
		roundi(crawl)]
	if key != _pend_key:
		_pend_key = key
		var at := -px.size * 0.5
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(at + Vector2.ONE * BED_INSET,
			px.size - Vector2.ONE * 2.0 * BED_INSET, BED_RADIUS), Color(colour, PEND_ALPHA))
		_dash_path(b, Face.Builder.round_rect(at + Vector2.ONE * 3.0,
			px.size - Vector2.ONE * 6.0, BED_RADIUS), true,
			maxf(PEND_MIN, _cell * PEND_WIDTH), colour, _cell * PEND_DASH, _cell * PEND_GAP, crawl)
		_pend_mesh = b.mesh()
	var e := now - _drag_at
	var grown := Motion.wide_pop_scale(e, Motion.POP_IN)
	draw_mesh(_pend_mesh, null, Transform2D(0.0, Vector2(grown, grown), 0.0, px.get_center()))
	return e < Motion.POP_IN or moving or not Motion.reduce

## Where the rectangle under the finger is drawn at `now`: easing after the
## cells it covers, read once a frame, so its edges glide rather than jump.
func _pend_rect(now: float) -> Rect2:
	var goal := _rect_px(_pending())
	if Motion.reduce or not _pend_px.has_area():
		_pend_px = goal
	else:
		var k := 1.0 - exp(-maxf(now - _pend_t, 0.0) * PEND_EASE)
		_pend_px = Rect2(_pend_px.position.lerp(goal.position, k), _pend_px.size.lerp(goal.size, k))
		if _pend_px.position.distance_to(goal.position) < 0.5 \
				and _pend_px.size.distance_to(goal.size) < 0.5:
			_pend_px = goal
	_pend_t = now
	return _pend_px

## Green when the rectangle is the size and shape the single clue inside it
## asks for, rose when it is not, and plain ink when it holds no clue or two.
func _pending_colour(pend: Rect2i) -> Color:
	var inside: Array = []
	for c in state.clues:
		if pend.has_point(c.pos):
			inside.append(c)
	if inside.size() != 1:
		return Pal.TEXT_DIM
	return Pal.LEAF if State.Gen.fits(inside[0], pend.size.x, pend.size.y) else Pal.BAD

# --- input ---

## Touch and drag only, as every flat board takes them: the viewport hands a
## control both the mouse event and the emulated touch, and two would fire
## twice.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _drag_from.x >= 0:
		_drag_to = _clamped(event.position)
		_recount()
		_redraw()

## The press: the wash and its count pop in on the cell. A pinned bed refuses
## before the drag starts, rather than letting one run and turning it down on
## release.
func _press(cell: Vector2i) -> void:
	if is_done() or cell.x < 0:
		return
	var who := state.owner_at(cell.y, cell.x)
	if who >= 0 and state.locked[who]:
		_refuse(who)
		return
	_drag_from = cell
	_drag_to = cell
	_drag_at = _now()
	_count = 1
	_count_at = -1.0e9
	_pend_key = ""
	_pend_px = Rect2()
	_fit_clue = -1
	_anim_until = maxf(_anim_until, _drag_at + Motion.POP_IN)
	fx.cue("select")
	_redraw()

## The count moment: a number that was recounted bumps.
func _recount() -> void:
	var area := _pending().get_area()
	if area == _count:
		return
	_count = area
	_count_at = _now()
	# The tick climbs as the bed grows, so its size can be heard.
	fx.cue("select", minf(1.0 + 0.04 * (area - 1), 1.6))
	_anim_until = maxf(_anim_until, _count_at + Motion.BUMP_TIME)
	# The sign the rectangle has just come to fit bobs: that one is mine.
	var fit := _fitted_clue(_pending())
	if fit != _fit_clue:
		_fit_clue = fit
		if fit >= 0:
			_bump(fit)

## The one clue `rect` holds when it is exactly the plot that clue asks for,
## or -1.
func _fitted_clue(rect: Rect2i) -> int:
	var found := -1
	for i in state.clues.size():
		if rect.has_point(state.clues[i].pos):
			if found >= 0:
				return -1
			found = i
	if found < 0 or not State.Gen.fits(state.clues[found], rect.size.x, rect.size.y):
		return -1
	return found

func _release() -> void:
	if _drag_from.x < 0:
		return
	var pend := _pending()
	# The fence goes up from where the finger went down.
	var start := Vector2(_drag_from) + Vector2(0.5, 0.5)
	_clear_drag()
	if is_done():
		_redraw()
		return
	var before := _snapshot()
	var out: Dictionary = state.commit(pend)
	match String(out.get("kind", "none")):
		"locked":
			var clue := int(out.get("clue", -1))
			_refuse(state.owner_at(state.clues[clue].pos.y, state.clues[clue].pos.x) if clue >= 0 else -1)
		"plot":
			var rect: Rect2i = out.rect
			_leave_missing(before, _now())
			_arrive(rect, false)
			_hop_inside(rect, Motion.HOP, Motion.HOP_TIME)
			_nudge_around(rect)
			_puff_corners(rect, Pal.BED_FURROW)
			fx.cue("plot")
			_after_move(start)
		"clear":
			_leave_missing(before, _now())
			_hop_inside(out.rect, Motion.HOP, Motion.HOP_TIME)
			fx.cue("clear")
			_after_move(Vector2(out.rect.position) + Vector2(out.rect.size) * 0.5)
	_redraw()

## A drag that wanders off the field holds its far corner on the edge cell,
## clamped rather than dropped.
func _clamped(local: Vector2) -> Vector2i:
	var p := (local - _origin) / _cell
	return Vector2i(clampi(int(floor(p.x)), 0, w - 1), clampi(int(floor(p.y)), 0, h - 1))

func _pending() -> Rect2i:
	var x0: int = mini(_drag_from.x, _drag_to.x)
	var y0: int = mini(_drag_from.y, _drag_to.y)
	var x1: int = maxi(_drag_from.x, _drag_to.x)
	var y1: int = maxi(_drag_from.y, _drag_to.y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

func _clear_drag() -> void:
	_drag_from = Vector2i(-1, -1)
	_drag_to = Vector2i(-1, -1)

## Everything a change to the partition drives.
func _after_move(from: Vector2) -> void:
	_fence_sync(from)
	_refresh_markers()
	_speak()
	note_move()

# --- what the beds do ---

## Every bed as it is drawn now, so the ones a move takes away can leave
## from their own picture after the state has forgotten them.
func _snapshot() -> Array:
	var out: Array = []
	for i in state.rects.size():
		out.append({"rect": state.rects[i], "mesh": _bed_mesh(i)})
	return out

## The beds in `before` the state no longer has shrink to nothing from `at`
## (Remove, and what a new plot displaced). Under reduce-motion they are
## simply gone, as pop_out would have them.
func _leave_missing(before: Array, at: float) -> void:
	for was in before:
		var rect: Rect2i = was.rect
		if state.rects.has(rect):
			continue
		_bed_in.erase(_bed_key(rect))
		_bed_flash.erase(_bed_key(rect))
		if Motion.reduce:
			continue
		_gone.append({"rect": rect, "mesh": was.mesh, "at": at})
		_anim_until = maxf(_anim_until, at + Motion.POP_OUT)

## A bed arriving: popping in wide, or dropping in from above when a hint
## drew it.
func _arrive(rect: Rect2i, drop: bool) -> void:
	_bed_in[_bed_key(rect)] = {"at": _now(), "drop": drop}
	_anim_until = maxf(_anim_until, _now() + maxf(Motion.POP_IN, Motion.DROP_TIME))

## A bed blushes toward its own rose and settles: Check pointing at its
## number, or a drag refused on it.
func _blush(rect: Rect2i) -> void:
	if Motion.reduce:
		return
	_bed_flash[_bed_key(rect)] = _now()
	_anim_until = maxf(_anim_until, _now() + Motion.FLASH_IN + Motion.FLASH_OUT)

## Earth thrown up at the four corners of a bed that has just been fenced:
## this board's placement puff, where the posts go in.
func _puff_corners(rect: Rect2i, colour: Color) -> void:
	var px := _rect_px(rect)
	for corner in [px.position, px.position + Vector2(px.size.x, 0.0),
			px.position + Vector2(0.0, px.size.y), px.end]:
		fx.puff(corner, colour, CORNER_STARS)

# --- what the markers do ---

## The markers standing in `rect` hop `height`.
func _hop_inside(rect: Rect2i, height: float, time: float, delay := 0.0) -> void:
	for i in state.clues.size():
		if rect.has_point(state.clues[i].pos):
			_hop(i, height, time, delay)

## The markers in the cells bordering `rect` lean away from it and back, the
## way a landing's neighbours do. One already mid-hop is left to land.
func _nudge_around(rect: Rect2i) -> void:
	var ring := rect.grow(1)
	for i in state.clues.size():
		var at: Vector2i = state.clues[i].pos
		if rect.has_point(at) or not ring.has_point(at):
			continue
		if Motion.running(_pos_tw[i]):
			continue
		var away := Vector2(
			signf(float(at.x) - clampf(float(at.x), float(rect.position.x), float(rect.end.x - 1))),
			signf(float(at.y) - clampf(float(at.y), float(rect.position.y), float(rect.end.y - 1))))
		_pos_tw[i] = Motion.nudge(_markers[i], away.normalized(), Vector2.ZERO)

## Marker `i` hops `height` over `time` after `delay`; it rests at the slot's
## origin, so the base is always zero.
func _hop(i: int, height: float, time: float, delay := 0.0) -> void:
	if i < 0 or i >= _markers.size():
		return
	Motion.stop(_pos_tw[i])
	_markers[i].position = Vector2.ZERO
	_pos_tw[i] = Motion.hop(_markers[i], height, time, delay, 0.0)

## A refused drag on pinned bed `who`: its marker shivers, the bed blushes
## and the sprout says why.
func _refuse(who: int) -> void:
	_say(tr("SK_PINNED"), Face.Expr.PUZZLED)
	fx.cue("locked")
	if who < 0 or who >= state.rects.size():
		return
	_blush(state.rects[who])
	var i := state.clue_index_in(who)
	if i < 0:
		return
	Motion.stop(_pos_tw[i])
	_markers[i].position = Vector2.ZERO
	_pos_tw[i] = Motion.shiver(_markers[i], _cell * MARKER * SHIVER)

## Check pointing at a number: it wobbles where it stands.
func _wobble(i: int) -> void:
	if i < 0 or i >= _markers.size():
		return
	Motion.stop(_look_tw[i])
	_markers[i].rotation = 0.0
	_markers[i].scale = Vector2.ONE
	_look_tw[i] = Motion.wobble2d(_markers[i])

## A hint's number is recounted as its bed is pinned: the family's bump.
func _bump(i: int) -> void:
	if i < 0 or i >= _markers.size():
		return
	Motion.stop(_look_tw[i])
	_markers[i].rotation = 0.0
	_markers[i].scale = Vector2.ONE
	_look_tw[i] = Motion.bump(_markers[i])

# --- the sprout's line ---

## What the tip card says: the rule while the field is bare, then the count
## of bare squares, and the blushing beds before either.
func _speak() -> void:
	if is_done():
		_say(tr("SK_SOLVED"), Face.Expr.JOY)
		return
	var blush := state.blushing()
	if blush > 0:
		_say(tr("SK_BLUSH_1") if blush == 1
			else tr("SK_BLUSH_N") % blush,
			Face.Expr.PUZZLED)
		return
	var bare := state.bare_cells()
	if bare == 0:
		_say(tr("SK_WRONG_SIZE"), Face.Expr.STRAIN)
		return
	_say(tr("SK_BARE_1") if bare == 1 else tr("SK_BARE_N") % bare, Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal; nothing else on this screen has a focus.
	focus_changed.emit()

## The three teaching lines, while there is nothing better to say.
func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY or not state.rects.is_empty():
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Takes back the last plot drawn or cleared: the reverse of Place. Counts
## no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var before := _snapshot()
	var back := state.undo()
	var now := _now()
	_leave_missing(before, now)
	for was in before:
		if not state.rects.has(was.rect):
			_hop_inside(was.rect, Motion.HOP, Motion.HOP_TIME)
	var from := Vector2(w, h) * 0.5
	for rect in back:
		_arrive(rect, false)
		_hop_inside(rect, Motion.HOP, Motion.HOP_TIME)
		from = Vector2(rect.position) + Vector2(rect.size) * 0.5
	_fence_sync(from)
	_refresh_markers()
	_speak()
	fx.cue("undo")
	moved.emit()
	_redraw()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Draws one plot from the answer and pins it: a ring pulses out of the bed,
## the bed drops in from above, sparkles rise and its number is recounted.
## Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var before := _snapshot()
	var target := state.apply_hint()
	if target.size == Vector2i(0, 0):
		return false
	_leave_missing(before, _now())
	_arrive(target, true)
	var who: int = state.rects.find(target)
	_bump(state.clue_index_in(who))
	var px := _rect_px(target)
	fx.ring(px.get_center(), minf(px.size.x, px.size.y) * 0.5, Pal.LEAF)
	fx.sparkle(px.get_center(), Pal.LEAF)
	fx.cue("hint")
	hints_used += 1
	_fence_sync(Vector2(target.position) + Vector2(target.size) * 0.5, Motion.DROP_TIME * 0.6)
	_refresh_markers()
	_say(tr("SK_FENCED"), Face.Expr.HAPPY)
	moved.emit()
	_redraw()
	check_solved()
	return true

## Every number the board does not yet satisfy wobbles, its bed blushes, and
## the sprout says how many. Solving stays automatic; this only points.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong := state.wrong_clues()
	for i in wrong:
		_wobble(i)
		var at: Vector2i = state.clues[i].pos
		var who := state.owner_at(at.y, at.x)
		if who >= 0:
			_blush(state.rects[who])
	if wrong.is_empty():
		_say(tr("SK_CHECK_OK"), Face.Expr.JOY)
	else:
		_say(tr("SK_CHECK_1") if wrong.size() == 1 else tr("SK_CHECK_N") % wrong.size(),
			Face.Expr.STRAIN)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_redraw()
	return wrong.size()

## Every bed goes, in a wave from the far corner, and the markers hop as the
## field clears under them. The hints a player spent are not refunded, only
## unpinned.
func reset_board() -> void:
	_clear_drag()
	var before := _snapshot()
	state.reset()
	var now := _now()
	var last := now
	for was in before:
		var rect: Rect2i = was.rect
		var at := now + Motion.stagger((h - rect.end.y) + (w - rect.end.x), Motion.RESET_STAGGER)
		last = maxf(last, at)
		_gone.append({"rect": rect, "mesh": was.mesh, "at": at})
	if Motion.reduce:
		_gone = []
	_bed_in = {}
	_bed_flash = {}
	for i in state.clues.size():
		var at: Vector2i = state.clues[i].pos
		_hop(i, Motion.RESET_HOP, Motion.HOP_TIME,
			Motion.stagger((h - 1 - at.y) + (w - 1 - at.x), Motion.RESET_STAGGER))
	moves = 0
	# The fence comes down stretch by stretch on the beds' own wave, from the
	# far corner.
	_fence_sync(Vector2(w, h))
	_anim_until = maxf(_anim_until, last + Motion.POP_OUT)
	_refresh_markers()
	_say(tr("SK_CLEARED"), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	_redraw()

## A completed daily is rebuilt from its seed, so the field opens bare. Lay the
## generator's partition back down and settle everything as the finished
## planting wave leaves it: every bed planted, every marker standing and
## beaming, no entrance, no drag. Not check_solved(): the host owns the win
## presentation for a daily that was already solved.
func restore_completed_board() -> void:
	var now := _now()
	_stop_all()
	_clear_drag()
	_tip_timer.stop()
	var rects: Array[Rect2i] = []
	var locked: Array[bool] = []
	for rect in state.solution:
		rects.append(rect)
		locked.append(false)
	state.rects = rects
	state.locked = locked
	state.history.clear()
	state.reown()
	_bed_cache = {}
	_bed_in = {}
	_gone = []
	_bed_flash = {}
	_plant_at = {}
	_blooms = {}
	_planted = true
	_pend_key = ""
	# The entrance long over, so the field and the shadows stand still.
	_opened = now - 10.0
	_enter_until = now - 10.0
	_anim_until = 0.0
	for i in _markers.size():
		_pos_tw[i] = null
		_look_tw[i] = null
		var marker: MarkerFace = _markers[i]
		marker.position = Vector2.ZERO
		marker.rotation = 0.0
		marker.scale = Vector2.ONE
	_shadows = null
	_edges = {}
	_fence_sync(Vector2.ZERO, 0.0, true)
	_refresh_markers()
	_say(tr("SK_SOLVED"), Face.Expr.JOY)
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The board is the answer, so the win screen shows no cast: the planted
## field stays on the card under it, which is what the player made.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("SK_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The beds are planted in a wave, nearest first, so the field finishes by
## filling in rather than by a banner arriving; each bed's marker hops the
## solve wave's hop as its crop comes up, and sparkles.
func _on_solved() -> void:
	_blooms = {}
	_clear_drag()
	_tip_timer.stop()
	var order: Array = []
	for i in state.rects.size():
		order.append(i)
	order.sort_custom(func(a, b) -> bool:
		var ra: Rect2i = state.rects[a]
		var rb: Rect2i = state.rects[b]
		return ra.position.y * w + ra.position.x < rb.position.y * w + rb.position.x)
	var now := _now()
	var last := now
	for k in order.size():
		var rect: Rect2i = state.rects[order[k]]
		var at := now if Motion.reduce else now + Motion.SOLVE_DELAY + Motion.stagger(k, PLANT_STEP, PLANT_WAVE)
		last = maxf(last, at)
		_plant_at[_bed_key(rect)] = at
		_hop_inside(rect, Motion.SOLVE_HOP, Motion.SOLVE_TIME, at - now)
		var opens := 0.0 if Motion.reduce else PLANT_TIME * 0.6
		_after(at - now + opens, _spark_at.bind(k, _rect_px(rect).get_center(),
			BLOOMS[_bloom_of(rect)][0]))
	_speak()
	fx.cue("solved")
	# Once the whole field is up, the crop is folded into the bed meshes and
	# the per-seedling draws stop; under reduce-motion it is already there.
	var grow := 0.0 if Motion.reduce else (last - now) + PLANT_TIME + (w + h) * PLANT_CELL
	if grow <= 0.0:
		_finish_planting()
	else:
		_after(grow, _finish_planting)
	_anim_until = maxf(_anim_until, now + grow + 0.2)
	_redraw()

## A spark as bed `k` opens, in its petals' colour. The two pools are used
## in turn: a run of fourteen a tenth of a second apart would otherwise
## recycle one pool fast enough to cut each burst in half.
func _spark_at(k: int, at: Vector2, colour: Color) -> void:
	if k % 2 == 0:
		fx.sparkle(at, colour)
	else:
		fx.puff(at, colour, 4)

func _finish_planting() -> void:
	_planted = true
	_redraw()

# --- entrance ---

## The chrome is the host's; here the field pops in wide and each marker pops
## onto it a beat later with the squash, along the diagonal from the top-left
## corner, its shadow arriving with it.
func _enter() -> void:
	_opened = _now()
	var far := 0
	for i in _markers.size():
		var clue: Dictionary = state.clues[i]
		far = maxi(far, clue.pos.x + clue.pos.y)
		var delay := Motion.ENTER_DELAY + Motion.stagger(clue.pos.x + clue.pos.y, Motion.ENTER_STAGGER) \
			+ Motion.ENTER_FACE_LAG
		Motion.stop(_look_tw[i])
		_look_tw[i] = Motion.pop_in(_markers[i], Motion.POP_IN, delay)
	_enter_until = _opened if Motion.reduce else _opened + Motion.ENTER_DELAY \
		+ Motion.stagger(far, Motion.ENTER_STAGGER) + Motion.ENTER_FACE_LAG + Motion.POP_IN
	_anim_until = maxf(_anim_until, maxf(_enter_until, _opened + Motion.ENTER_DELAY + Motion.ENTER_POP))
	fx.cue("enter")

# --- odds and ends ---

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at a marker that is
## gone.
func _stop_all() -> void:
	_gen += 1
	for tw in _pos_tw:
		Motion.stop(tw)
	for tw in _look_tw:
		Motion.stop(tw)

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

func _process(delta: float) -> void:
	super(delta)
	if _now() < _anim_until:
		_redraw()

## The field and the disc over it are two canvas items, and every change
## that moves one moves the other.
func _redraw() -> void:
	queue_redraw()
	if _over != null:
		_over.queue_redraw()

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## The drag's area disc, drawn over the markers: a marker standing inside the
## rectangle would hide the one number the drag is for. It pops in from
## nothing as the finger lands and bumps whenever the count changes.
class Overlay extends Control:
	var board
	## Kept, not local. A mesh handed to draw_mesh has to stay referenced
	## until the frame is actually rendered (see ui/faces/face.gd): a local
	## is freed the moment _draw returns, the renderer is then given a dead
	## RID, and the disc silently does not draw while every redraw logs
	## `Parameter "mesh" is null`. The one before it is kept a frame longer
	## for the same reason.
	var _mesh: ArrayMesh
	var _last: ArrayMesh
	var _key := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if board == null or board._drag_from.x < 0 or board.is_done():
			return
		var pend: Rect2i = board._pending()
		var px: Rect2 = board._pend_px if board._pend_px.has_area() else board._rect_px(pend)
		var colour: Color = board._pending_colour(pend)
		var r: float = minf(board._cell * DISC_SHARE, DISC_MAX)
		var centre := px.get_center()
		var key := "%.1f_%s" % [r, colour.to_html(false)]
		if key != _key:
			_key = key
			_last = _mesh
			var b := Face.Builder.new()
			b.disc(Vector2.ZERO, r, Pal.SURFACE)
			b.stroke(Face.Builder.ring(Vector2.ZERO, r, r), DISC_RIM, colour, true)
			_mesh = b.mesh()
		var now: float = board._now()
		var grown: Vector2 = Motion.pop_in_scale(now - board._drag_at) \
			* Motion.bump_scale(now - board._count_at)
		if grown.x <= 0.0 or grown.y <= 0.0:
			return
		draw_set_transform(centre, 0.0, grown)
		draw_mesh(_mesh, null, Transform2D.IDENTITY)
		var font: Font = CozyTheme.display(700)
		var text := str(pend.get_area())
		var px_size := int(roundf(r * DISC_TEXT))
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px_size).x
		draw_string(font, Vector2(-wide * 0.5, font.get_ascent(px_size) * 0.5),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px_size, colour)
		draw_set_transform_matrix(Transform2D.IDENTITY)
