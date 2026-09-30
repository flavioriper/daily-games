extends "res://core/puzzle_base.gd"

## Quilt as a flat board: a shaped backing of pale cloth on the card, and
## under it, **inside the same card**, a rack of coloured patches waiting to
## be sewn on. Drag a patch onto the backing and it snaps to the cells; drag
## one that is already on to take it off again. The rules live in
## puzzles/quilt_state.gd, which this only draws.
##
## **Nothing wrong can be sitting on this quilt.** A drop is taken only if
## every cell of the patch lands on the backing and on no other patch, and
## the patches' cells sum to exactly the backing's, so the last patch sewn on
## *is* the solve. There is therefore no Check to put in an actions row: the
## registry drops the row, Reset rides up into the top bar, and the bottom
## slot is the tip card alone at 140 -- Word Trail's shape exactly.
##
## **Patches never turn.** Each one is shown in the one orientation it goes
## on in, on the rack and on the quilt alike, which is what keeps a drag to
## one decision (where) instead of two (where, and which way round).
##
## How it is drawn. Three meshes and no Controls: the quilt (the backing, its
## cell rules, the patches sewn on, the seams between them and the ghost
## under the finger), the rack (the patches still waiting, and any flying
## home), and the hand (the one patch being dragged, which has to draw over
## everything). A patch is **one polygon and not a row of squares**: its
## cells' boundary is traced into a loop, the loop's corners are rounded, and
## the whole silhouette is filled over a slightly deeper copy of itself --
## the family's lip. Cloth is cut in pieces, not tiled.
##
## The polish (2026-09-30): a tap wiggles, a drop snaps to the nearest fit,
## a dead end is named on Easy and Medium, a sewn-in label counts the bare
## squares and a ghost finger shows the drag; Hard and Insane judge every
## patch against hearts (a wrong one snips, peels and flutters home), and
## Insane's rack is Scrap Basket's wicker. Over the meshes sit two layer
## Controls, the hearts' pill and the life (the ghost finger, and the
## rewards'), each one mesh.
##
## Spec: docs/superpowers/specs/2026-09-20-quilt-flat-design.md, sections 6
## and 7, and 2026-09-30-quilt-polish-design.md, sections 1 to 3. Ported from the canvas mock at
## docs/brainstorm/concepts.html#quilt, which is the reference for every
## measure here.

## Back to camp from the out-of-hearts card (the host listens for it).
signal leave

const State = preload("res://puzzles/quilt_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
## The cloth itself -- the silhouette, the lip, the stitch and the eight
## colours -- lives in ui/faces/, because the menu card draws the same patch
## and neither should own the other's drawing (ui/faces/mosaic_tile.gd's
## bargain, and for the same reason).
const Cloth = preload("res://ui/faces/patch_cloth.gd")
const CozyTheme = preload("res://ui/theme.gd")

# --- the screen, measured (spec section 6) ---
## The card's own inset, all round.
const INSET := 28.0
## How the card's content height is split. At the standard 1340 card the
## content is 1284, and the field takes 800 of it, the air 28 and the rack
## the remaining 456. Kept as a share rather than as three constants so a
## card of another height splits in the same proportion instead of spending
## every extra pixel on the rack.
const FIELD_SHARE := 800.0 / 1284.0
const RACK_PAD := 28.0
## The largest cell a small quilt may have. Without it a five-patch board on
## a 5 x 4 box comes out at 188 a cell and reads as a toy.
const CELL_MAX := 150.0
## How much of the rack the cloth on it fills, the air between two patches
## on a shelf (in cells), and how small a patch on the rack is against the
## same patch on the quilt. One rack cell for every patch, so the rack reads
## as one basket of cloth and not as six scales.
const RACK_FILL := 0.86
const RACK_GAP := 0.6
const RACK_RATIO := 0.62

# --- the cloth, in cells ---
## The faint rules between the backing's cells. A patch's corner, its lip
## and its two ink mixes are `PatchCloth`'s, since the menu card wears them
## too, and the backing is drawn as one more patch of cloth so it wears the
## same corner and the same lip rather than a second pair of numbers.
const RULE_W := 0.022
const RULE_ALPHA := 0.55
## The running stitch: its width, and the dash and the gap along it.
const STITCH_W := 0.05
const STITCH_ON := 0.15
const STITCH_OFF := 0.1
## This board's own two numbers, and the only two it needs. The seam wave's
## step per cell of distance from the patch that landed, and how long one
## seam's dashes take to run. Nothing else in the game sews, so these would
## never be read by `core/motion.gd`.
const STITCH_STEP := 0.05
const STITCH_TIME := 0.22
## A dragged patch is held this far above the finger, in cells, so the thumb
## never covers the shape it is placing. Measured on the mock at the hard
## band's cell, which is the smallest.
const HOLD_LIFT := 1.2
## A refused or a lifted patch flying home to its bay.
const FLY_TIME := 0.26
## The ghost under the finger: the cells a drop would take, and the thread
## drawn round them so the footprint reads from under the patch that is
## hiding most of it.
const GHOST_ALPHA := 0.3
const GHOST_W := 0.035
const GHOST_DASH := 0.12
## The rose halo a refused patch wears instead of blushing (see `_blush`).
const HALO_W := 0.11
const HALO_ALPHA := 0.85
## The shape a patch leaves in its bay once it has gone onto the quilt.
const GONE_ALPHA := 0.16
## A patch a hint sewed keeps this glow round it until the board is reset.
const GIVEN_GLOW := 0.32
const GIVEN_W := 0.09
## The ring a hint pulses, in cells, off the patch's centroid.
const RING_R := 0.9
## Long enough for the solve's hem stitch to run all the way round before the
## win screen covers it.
const WIN_WAIT := 1.6

# --- the polish (spec amendment, 2026-09-26) ---
## The backing is a tufted quilt: every cell a soft puff of batting, inset
## this far, and a tie of thread where four puffs meet.
const PUFF_INSET := 0.07
const PUFF_R := 0.2
const PUFF_ALPHA := 0.26
const TIE_LEN := 0.055
const TIE_W := 0.028
## The rack stands on a felt mat with a stitched border.
const MAT_PAD := 14.0
const MAT_R := 26.0
const MAT := Color("e4e2c6")
const MAT_EDGE := Color("cfcaa6")
const MAT_STITCH := Color("f7f3e4")
## A patch that has left the rack leaves its outline in tailor's chalk.
const CHALK_W := 0.05
const CHALK_ON := 0.14
const CHALK_OFF := 0.1
## Taken hold of, a patch grows from the rack's cell to the quilt's over
## GROW_TIME and rises HOLD_LIFT above the thumb as it does, so it leaves the
## rack from exactly where it lay; it casts HELD_SHADOW (in cells) while it
## is up, and leans with the drag -- SWAY_GAIN radians per pixel a second,
## never past SWAY_MAX -- the way a piece of cloth held by one corner trails.
const GROW_TIME := 0.16
const HELD_SHADOW := Vector2(0.07, 0.24)
const SWAY_GAIN := 0.00005
const SWAY_MAX := 0.07
## Let go where it fits, a patch glides down onto its snapped cells over the
## first LAND_GLIDE of LAND_TIME and lands with a squash of LAND_SQUASH.
## Then a needle runs the quilting stitch round inside its edge over
## SEW_TIME, and the seams it now shares sew themselves after it.
const LAND_TIME := 0.32
const LAND_GLIDE := 0.34
const LAND_SQUASH := 0.06
const SEW_TIME := 0.5
## A patch flying home rises this far (in its starting cells) on the way.
const FLY_ARC := 0.4
## On the solve a light crosses the quilt, lifting each cloth this far toward
## the surface as it passes. A celebration and not a state: it is gone again
## before the win screen comes up.
const SHEEN := 0.36

# --- the polish (spec 2026-09-30-quilt-polish-design.md, sections 1-3) ---
## The tips cycle every TIP_CYCLE seconds, and a spoken line owns the card
## for SAY_HOLD before they come back (Bridges' and Sudoku's).
const TIP_CYCLE := 7.0
const SAY_HOLD := 3.2
const TIPS := ["QL_TIP_DRAG", "QL_TIP_TURN", "QL_TIP_GHOST", "QL_TIP_OFF", "QL_TIP_ALL"]
## A judged board: a patch taken off cannot be, and every patch does fit
## somewhere only on a board without scraps.
const TIPS_HEARTS := ["QL_TIP_HEARTS", "QL_TIP_DRAG", "QL_TIP_TURN", "QL_TIP_GHOST", "QL_TIP_ALL"]
const TIPS_SCRAPS := ["QL_TIP_SCRAPS", "QL_TIP_SCRAPS_2", "QL_TIP_HEARTS", "QL_TIP_TURN", "QL_TIP_GHOST"]
## A tap: a press let go within TAP_PX of where it went down and inside
## TAP_TIME. It wiggles the patch where it lies rather than lifting it, so a
## patch pressed is not grown until the finger has moved or GROW_WAIT passed.
const TAP_PX := 14.0
const TAP_TIME := 0.3
const GROW_WAIT := 0.12
const WIGGLE_ANGLE := 0.16
const WIGGLE_TIME := 0.5
## Sticky snap: when the rounded cell does not fit, the nearest cell that
## does within STICKY cells of the held corner is taken instead.
const STICKY := 0.75
## The dead end's pulse on Easy and Medium: every bare cell no patch left
## can reach, a rose halo, DEAD_PULSES beats of DEAD_BEAT.
const DEAD_PULSES := 3
const DEAD_BEAT := 0.42
const DEAD_W := 0.08
## The sewn-in label: a little cloth tag on the backing's top-right corner
## counting the bare squares, bumping when the count changes.
const TAG_SIZE := Vector2(74.0, 84.0)
const TAG_GAP := 7.0
const TAG_R := 10.0
const TAG_FONT := 40
const TAG := Color("fbf6e8")
const TAG_EDGE := Color("d9cfb4")
const TAG_BAND := Color("c26b6b")
## The ghost finger on Easy and Medium (Bridges'): after COACH_AFTER of rest
## it drags the patch with the fewest spots to its place in COACH_DRAG, then
## waits COACH_LOOP, until the first patch lands.
const COACH_AFTER := 1.6
const COACH_DRAG := 1.1
const COACH_LOOP := 2.4
const COACH_ALPHA := 0.45
## Hearts on Hard and Insane (Bridges' pill, strip and split).
const HEART_ROW := 64.0
const HEART_R := 21.0
const HEART_GAP := 12.0
const HEART_PILL_PAD := Vector2(18.0, 8.0)
const HEART_PILL_RIM := 2.0
const SPLIT_TIME := 0.7
const SPLIT_FALL := 56.0
const SPLIT_SPREAD := 14.0
const SPLIT_TURN := 0.7
const HEART_BACK_TIME := 0.3
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
## A wrong patch, on the clock from its release: it glides down and lands
## (LAND_TIME), its needle sews until SNIP_AT, the thread snaps and the
## stitch unravels backward over UNRAVEL_TIME, the patch peels up by a
## corner over PEEL_TIME (tilting PEEL_TILT and rising PEEL_RISE cells), and
## flutters home over FLUTTER_TIME with a wobble of FLUTTER_WOBBLE.
const SNIP_AT := 0.5
const UNRAVEL_TIME := 0.24
const PEEL_TIME := 0.28
const PEEL_TILT := 0.32
const PEEL_RISE := 0.35
const FLUTTER_TIME := 0.62
const FLUTTER_WOBBLE := 0.22
## The chalk cross a ruled spot shows under a held patch: tailor's blue
## chalk, since the white of the mat's stitch is lost on the pale backing.
const CROSS := Color("6f86b0")
const CROSS_W := 0.06
## Scrap Basket's wicker: the body, its deep lip, the light of a strand and
## the rim's twist.
const WICKER := Color("eddcb6")
const WICKER_DEEP := Color("c29a62")
const WICKER_HI := Color("f8eed6")
const WICKER_LINE := Color("c9a56f")
const RIM_H := 30.0
## The basket's woven band along its foot, and the stakes' spacing.
const BAND_H := 32.0
const STAKE := 38.0

var _state = State.new()
## The board's own effects node: the hint's ring and every sparkle come
## through it and nowhere else.
var fx: Node2D

## The patch under the finger: {"patch": int, "grab": Vector2i (which of its
## own cells was taken hold of), "point": Vector2 (the finger, local),
## "from": int (the origin it was lifted off, or -1 from the rack),
## "since": float}. Empty when nothing is held.
var _drag: Dictionary = {}
## Patches on their way home to the rack: patch -> {"from", "to", "c0", "c1",
## "at"}. A refused drop and a lift are the same flight.
var _flying: Dictionary = {}
## When each patch last landed on the quilt, and when each last left it. The
## seam wave and the pops read these; they are the only clock this board
## keeps, and the seams themselves are derived from them every frame.
var _landed: Dictionary = {}
var _lifted: Dictionary = {}
## A refused drop: {"patch": int, "at": float}. The patch shivers on its way
## home and blushes while it goes.
var _refused: Dictionary = {}
## The rings and sparkles a wave still owes: [{"at", "point", "colour",
## "ring"}]. A solve's gold lands on each patch as the hop reaches it, not
## all at once when the last patch went on.
var _pending: Array = []

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
## The three meshes, dropped whenever something changed so the next _draw
## rebuilds them.
var _quilt: ArrayMesh
var _rack: ArrayMesh
var _hand: ArrayMesh
## The tufted backing, which never changes while the card keeps its size:
## built once and kept, rather than retraced on every frame of a drag.
var _ground: ArrayMesh
## The rack's mat (Scrap Basket's wicker), which never changes while the card
## keeps its size either: the basket's weave is hundreds of strands, far too
## many to retrace on every frame a patch flies home.
var _mat_mesh: ArrayMesh
## Patches that landed out of the hand, with the corner the hand let them go
## at: they glide down from there rather than popping in.
var _glide: Dictionary = {}
## The meshes the last _draw actually handed to the canvas item. A canvas
## command holds a mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: Array = []
## Each patch's boundary loop and its bounding box, in its own cell units.
## Built once a board: a patch never changes shape and never turns.
var _loops: Array = []
var _spans: Array = []
## The backing's own loops and the faint rules inside it, likewise.
var _back_loops: Array = []
var _back_rules: Array = []
var _back_cells: Array = []
## Each patch's quilting line: its loop shrunk by Cloth.QUILT_INSET.
var _insets: Array = []

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
var _hold_until := 0.0
## Anything `_after` still owes a board that has since been rebuilt or wiped
## does nothing (Bridges').
var _gen := 0

## Hearts, on a judged board (Hard and Insane): Bridges' names throughout.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _asleep := false
var _heart_card: Control
var _split_index := -1
var _split_at := -INF
var _back_index := -1
var _back_at := -INF
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _dusk_tw: Tween
## The wrong patch on its way back: {"patch", "origin", "at", "hand"}, empty
## when none. Input, undo, hint and reset wait while it is set.
var _peel: Dictionary = {}
## Easy and Medium: whether the quilt was ever left unfinishable, which
## costs the flawless seal. `_flawless` is set on the solve.
var _stuck_ever := false
var _flawless := false
## patch -> when a tap (or a tap on a sewn patch) set it wiggling.
var _wiggle: Dictionary = {}
## The dead end's cells and when their pulse starts: {"cells", "at"}.
var _dead: Dictionary = {}
## The sewn-in label: the count it shows, when it last changed, its mesh.
var _tag_count := -1
var _tag_at := -INF
var _tag_mesh: ArrayMesh
var _tag_left := false
## The ghost finger: the patch it drags and the origin it takes it to, the
## moment the board last came to rest, and whether it has retired.
var _coach_patch := -1
var _coach_origin := -1
var _rest_at := 0.0
var _coach_off := false
var _life_layer: Control
var _life_shown: Array = []
var _life_alive := false
## The rack's shelves, cached per board (see `_shelves`).
var _shelf_cache: Array = []

func puzzle_id() -> String: return "quilt"
func title() -> String: return "Quilt"

## The rules in plain words, then the band's own closing: the basket's
## scraps on Insane, and either what a heart is for or that nothing here can
## be lost.
func rules() -> String:
	var out: String = tr("QL_RULES")
	if not _state.scraps().is_empty():
		out += "\n\n" + tr("QL_RULES_SCRAPS")
	if max_hearts > 0:
		out += "\n\n" + tr("QL_RULES_HEARTS") % max_hearts
	else:
		out += "\n\n" + tr("QL_RULES_SAFE")
	return out

## Undo and Hint, and nothing else. There is no Check because nothing wrong
## can be sitting on the quilt to check: an illegal drop is never taken, and
## on Hard and Insane a wrong one is judged as it lands. So the registry
## drops the actions row and Reset rides up into the top bar.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

## The lines the tips cycle: Scrap Basket leads with its two, a judged board
## with the hearts'.
func _tips() -> Array:
	if not _state.scraps().is_empty():
		return TIPS_SCRAPS
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

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
	_heart_layer = _layer("Hearts", 1, _draw_hearts)
	_life_layer = _layer("Life", 3, _draw_life)
	resized.connect(_layout)
	solved.connect(_on_solved)

## A full-rect layer over the board, drawn by `draw` (One Line's).
func _layer(nm: String, z: int, draw: Callable) -> Control:
	var layer := Control.new()
	layer.name = nm
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(draw)
	add_child(layer)
	return layer

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	_state.setup(rng, difficulty, bank_step)
	max_hearts = State.hearts_for(_state.band) if _state.judged() else 0
	_heart_used = false
	_lost_ever = false
	_stuck_ever = false
	_drag = {}
	_flying = {}
	_landed = {}
	_lifted = {}
	_glide = {}
	_refused = {}
	_pending = []
	_anim_until = 0.0
	_solved_at = -1.0
	_shape_cache()
	_deal()
	_layout()
	_enter()
	_pick_coach()
	_tip_idx = 0
	_hold_until = 0.0
	_say(_tip(0), Face.Expr.HAPPY)
	_tip_timer.start()

## The board as it is dealt, and as Try again deals it back: every heart,
## the day's light, nothing peeling, pulsing or wiggling.
func _deal() -> void:
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_back_index = -1
	_peel = {}
	_wiggle = {}
	_dead = {}
	_flawless = false
	_tag_count = -1
	_tag_at = -INF
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	for layer: Control in [_heart_layer, _life_layer]:
		if layer != null:
			layer.queue_redraw()

## Every patch's silhouette and the backing's, traced once. A patch is a
## fixed set of cells that never turns, so its loop is worth keeping; the
## alternative is tracing eight boundaries on every frame of a drag.
func _shape_cache() -> void:
	_loops = []
	_spans = []
	_insets = []
	_ground = null
	_mat_mesh = null
	_shelf_cache = []
	for p in _state.shapes.size():
		var cells: Array = _state.shapes[p]
		_loops.append(Cloth.loops(cells))
		_insets.append(Cloth.inset_loops(cells))
		var span := Vector2i.ZERO
		for c: Vector2i in cells:
			span.x = maxi(span.x, c.x + 1)
			span.y = maxi(span.y, c.y + 1)
		_spans.append(span)
	var back: Array = []
	for r in _state.rows:
		for c in _state.cols:
			if _state.in_region(c, r):
				back.append(Vector2i(c, r))
	_back_loops = Cloth.loops(back)
	_back_cells = back
	# The rules between two backing cells, drawn once as a hint of the grid
	# the patches snap to. Only the inner edges: the outer ones are the hem.
	_back_rules = []
	for cell: Vector2i in back:
		if _state.in_region(cell.x + 1, cell.y):
			_back_rules.append([Vector2(cell.x + 1, cell.y), Vector2(cell.x + 1, cell.y + 1)])
		if _state.in_region(cell.x, cell.y + 1):
			_back_rules.append([Vector2(cell.x, cell.y + 1), Vector2(cell.x + 1, cell.y + 1)])

# --- layout ---

## The card's content box, inside the inset.
func _content() -> Rect2:
	return Rect2(Vector2.ONE * INSET, size - Vector2.ONE * (2.0 * INSET))

## The box the quilt is laid in: the top share of the content, less the
## strip the hearts take on a board that has them. The rack keeps its size:
## the field gives up the 64.
func _field_box() -> Rect2:
	var box := _content()
	var row := _heart_row()
	return Rect2(box.position + Vector2(0.0, row),
		Vector2(box.size.x, maxf(0.0, box.size.y * FIELD_SHARE - row)))

## The strip the hearts take over the field, on a board that has them.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

## Where the hearts' pill is centred: in the strip over the field.
func _hearts_y() -> float:
	return INSET + HEART_ROW * 0.5

## The box the rack stands in: everything under the field and the air.
func _rack_box() -> Rect2:
	var box := _content()
	var top := box.position.y + box.size.y * FIELD_SHARE + RACK_PAD
	return Rect2(Vector2(box.position.x, top), Vector2(box.size.x, box.position.y + box.size.y - top))

## The quilt's cell. The backing's bounding box is square-ish and its slot is
## wider than it is tall, so the **height binds at every band** -- 160, 133
## and 114 at 1080 wide, capped to 150 on the easy board, against Sudoku's
## 100 and Queens' 103. A quilt is dragged onto rather than tapped, so it
## wants the biggest cell on the shelf.
func _cell() -> float:
	if _state.cols <= 0 or _state.rows <= 0:
		return 0.0
	var box := _field_box()
	return maxf(0.0, minf(CELL_MAX, minf(box.size.x / float(_state.cols), box.size.y / float(_state.rows))))

## The backing's top-left, centred in its box both ways.
func _origin() -> Vector2:
	var box := _field_box()
	var span := Vector2(float(_state.cols), float(_state.rows)) * _cell()
	return box.position + (box.size - span) * 0.5

func _field_centre() -> Vector2:
	return _origin() + Vector2(float(_state.cols), float(_state.rows)) * _cell() * 0.5

## The top-left of the cell an origin index names.
func _corner_of(origin: int) -> Vector2:
	if _state.cols <= 0:
		return Vector2.ZERO
	var c: int = origin % _state.cols
	var r: int = origin / _state.cols
	return _origin() + Vector2(float(c), float(r)) * _cell()

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _origin() + Vector2(float(c) + 0.5, float(r) + 0.5) * _cell()

## The backing cell under a local point, or (-1, -1). A point off the
## backing's own shape still answers with its cell: a drag is judged by where
## the *patch* falls, and the state says whether that is on the quilt.
func _cell_at(local: Vector2) -> Vector2i:
	var cell := _cell()
	if cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _origin()) / cell
	return Vector2i(int(floor(p.x)), int(floor(p.y)))

## The rack is **two shelves, packed to the cloth**, not a grid of equal
## bays. A grid of bays has to size every bay for the tallest patch on the
## board, and one four-cell-tall patch then shrinks all eight: measured, a
## 456 rack over two 228 bays capped the rack cell at 46.7 on all three
## bands, against a field cell of 114 to 150. A shelf takes only the height
## its own patches need.
##
## So: the patches are sorted tallest first and cut in half, which puts the
## tall ones together on one shelf rather than one on each, and each shelf
## is given the share of the rack its own height asks for. Scrap Basket's
## twelve may take three shelves instead, whichever gives the bigger cell:
## six patches abreast bind the width.
func _shelves() -> Array:
	if not _shelf_cache.is_empty():
		return _shelf_cache
	var order: Array = []
	for p in _state.shapes.size():
		order.append(p)
	order.sort_custom(func(a: int, b: int) -> bool:
		var sa: Vector2i = _spans[a]
		var sb: Vector2i = _spans[b]
		if sa.y != sb.y:
			return sa.y > sb.y
		return sa.x > sb.x)
	var best: Array = []
	var best_cell := -1.0
	for count in ([2, 3] if order.size() >= 9 else [2]):
		var per := int(ceil(order.size() / float(count)))
		var out: Array = []
		var k := 0
		while k < order.size():
			out.append(order.slice(k, mini(k + per, order.size())))
			k += per
		var cell := _cell_for(out)
		if cell > best_cell + 0.5:
			best = out
			best_cell = cell
	if _cell() > 0.0:
		_shelf_cache = best
	return best

## A shelf's width and height, in cells, with the air between its patches.
func _shelf_span(shelf: Array) -> Vector2:
	var w := 0.0
	var h := 1.0
	for p in shelf:
		w += float(_spans[p].x)
		h = maxf(h, float(_spans[p].y))
	return Vector2(w + RACK_GAP * float(maxi(shelf.size() - 1, 0)), h)

## One cell for every patch on the rack -- a rack of two sizes reads as two
## kinds of thing -- and the smallest of the three things that can bind it:
## a shelf's width, the shelves' heights together, and the cap that keeps a
## waiting patch visibly smaller than a sewn one.
func _rack_cell() -> float:
	return _cell_for(_shelves())

func _cell_for(shelves: Array) -> float:
	var box := _rack_box()
	var tall := 0.0
	var best := RACK_RATIO * _cell()
	for shelf: Array in shelves:
		var span := _shelf_span(shelf)
		tall += span.y
		best = minf(best, RACK_FILL * box.size.x / span.x)
	if tall > 0.0:
		best = minf(best, RACK_FILL * box.size.y / tall)
	return maxf(0.0, best)

## Where a patch waits: along its shelf in order, the shelf centred across
## the rack, and the patch centred in the band its shelf was given.
func _bay_home(p: int) -> Vector2:
	var box := _rack_box()
	var shelves := _shelves()
	var rc := _rack_cell()
	var tall := 0.0
	for shelf: Array in shelves:
		tall += _shelf_span(shelf).y
	var top := box.position.y
	for shelf: Array in shelves:
		var span := _shelf_span(shelf)
		var band := box.size.y * (span.y / maxf(tall, 1.0))
		if shelf.has(p):
			var x := box.position.x + (box.size.x - span.x * rc) * 0.5
			for q in shelf:
				if int(q) == p:
					break
				x += (float(_spans[q].x) + RACK_GAP) * rc
			return Vector2(x, top + (band - float(_spans[p].y) * rc) * 0.5)
		top += band
	return box.position

## The card this board wants: every pixel it is given. The field takes the
## share above and the rack the rest, so there is never any slack.
func card_height(available: float) -> float:
	return available

## False, and honestly so: card_height() hands back everything it is given,
## so the slack is zero and there is nothing to centre.
func card_centred() -> bool:
	return false

func _layout() -> void:
	_ground = null
	_mat_mesh = null
	_tag_mesh = null
	_shelf_cache = []
	_refresh()
	if _heart_layer != null:
		_heart_layer.queue_redraw()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.shapes.is_empty():
		return
	var t := _now()
	_sway(delta)
	_retire(t)
	_fire_pending(t)
	_tick_layers(t)
	if _animating(t):
		_refresh()

## The lean of the patch in the hand: toward the drag's own speed across,
## eased so a jerk of the finger swings it rather than snapping it, and back
## to upright when the finger rests. Nothing under reduce-motion.
func _sway(delta: float) -> void:
	if _drag.is_empty():
		return
	var point: Vector2 = _drag["point"]
	var last: Vector2 = _drag.get("last", point)
	_drag["last"] = point
	var want := 0.0
	if not Motion.reduce and delta > 0.0:
		want = clampf((point.x - last.x) / delta * SWAY_GAIN, -SWAY_MAX, SWAY_MAX)
	_drag["sway"] = lerpf(float(_drag.get("sway", 0.0)), want, 1.0 - exp(-delta * 10.0))

## Every ring and sparkle whose moment has come.
func _fire_pending(t: float) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	for e: Dictionary in _pending:
		if t < float(e["at"]):
			keep.append(e)
			continue
		if bool(e["ring"]):
			fx.ring(e["point"], _cell() * RING_R, e["colour"])
		fx.sparkle(e["point"], e["colour"])
		_busy_for(Motion.RING_TIME)
	_pending = keep

## Queues one sparkle, and optionally a ring, on a local point `after`
## seconds from now. Nothing at all under reduce-motion: ui/fx2d.gd already
## draws neither, so this only spares the board the frames it would spend
## waiting for them.
func _fx_at(point: Vector2, colour: Color, after := 0.0, ring := true) -> void:
	if Motion.reduce:
		return
	_pending.append({"at": _now() + after, "point": point, "colour": colour, "ring": ring})
	_busy_for(after + Motion.RING_TIME)

## A flight that has landed stops being a flight; otherwise `_animating`
## would have to keep asking about it for ever.
func _retire(t: float) -> void:
	if _flying.is_empty():
		return
	for p in _flying.keys():
		if t - float((_flying[p] as Dictionary)["at"]) >= FLY_TIME:
			_flying.erase(p)

## Whether anything on this card is still moving, asked wave by wave rather
## than by one deadline. **Every** wave has to be in here: One Line shipped
## two lines frozen at four fifths of a fade because one was left out, and it
## showed in a rendered frame and in no test.
func _animating(t: float) -> bool:
	if not _drag.is_empty() or not _flying.is_empty() or not _pending.is_empty() \
			or not _peel.is_empty():
		return true
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	for p in _wiggle:
		if t - float(_wiggle[p]) < WIGGLE_TIME:
			return true
	if not _dead.is_empty() and t - float(_dead["at"]) < DEAD_BEAT * DEAD_PULSES:
		return true
	if t - _tag_at < Motion.BUMP_TIME:
		return true
	# The entrance: the backing's wide pop, then the rack's patches popping in.
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(maxi(_state.shapes.size() - 1, 0), Motion.ENTER_STAGGER) + Motion.POP_IN
	if t - _opened < entrance:
		return true
	# Every patch's landing pop and the seam wave that ran out of it, and
	# every lift's pop-out.
	for p in _landed:
		if t - _sewn_at(int(p)) < maxf(maxf(Motion.POP_IN, SEW_TIME), _seam_span(int(p))):
			return true
	for p in _lifted:
		if t - float(_lifted[p]) < Motion.POP_OUT:
			return true
	if not _refused.is_empty() and t - float(_refused["at"]) < Motion.FLASH_IN + Motion.FLASH_OUT:
		return true
	if _solved_at >= 0.0 and t - _solved_at < Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME:
		return true
	return false

## How long the seam wave out of patch `p` runs: the far end of the longest
## seam it made, plus the run of that seam's own dashes.
func _seam_span(p: int) -> float:
	if Motion.reduce or p < 0 or p >= _state.shapes.size():
		return STITCH_TIME
	var span: Vector2i = _spans[p]
	var reach := float(span.x + span.y)
	return reach * STITCH_STEP + STITCH_TIME

## When patch `p`'s stitching starts: the moment it landed, or, for one that
## glided down out of the hand, the moment it touched the backing.
func _sewn_at(p: int) -> float:
	var at := float(_landed.get(p, -100.0))
	if _glide.has(p) and not Motion.reduce:
		at += LAND_TIME * LAND_GLIDE
	return at

## How long the solve wave takes to cross the quilt: the far corner's delay.
func _solve_span() -> float:
	return Motion.stagger(maxi(_state.cols + _state.rows - 2, 0), Motion.SOLVE_STAGGER)

## Keeps the card redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the three meshes so the next _draw rebuilds them, and asks for that
## draw. What the last _draw handed over is still held by _shown, so the
## renderer is never left pointing at a freed RID.
func _refresh() -> void:
	if _state.shapes.is_empty():
		_ground = null
	_quilt = null
	_rack = null
	_hand = null
	queue_redraw()

# --- where each patch is, this frame ---

## A patch's place on the card right now: the top-left of its bounding box,
## the cell it is drawn at, the squash and the lean on it, how solid it is,
## how far off the cloth it is held (its shadow) and the colour of its face.
## One function for the four states a patch can be in -- waiting, held,
## flying home and sewn on -- so no two of them can disagree about where it
## is.
func _frame_of(p: int, t: float) -> Dictionary:
	var sc := Vector2.ONE
	var alpha := 1.0
	var pos: Vector2
	var cell := _cell()
	var rot := 0.0
	var lift := 0.0
	var face: Color = Cloth.cloth(p)
	if not _peel.is_empty() and int(_peel["patch"]) == p:
		return _peel_frame(t)
	if not _drag.is_empty() and int(_drag["patch"]) == p:
		var g := _grow(t)
		cell = lerpf(float(_drag["c0"]), _cell(), g)
		pos = _held_corner_at(cell, g)
		sc = Vector2.ONE * lerpf(1.0, Motion.LIFT_SCALE, g)
		rot = float(_drag.get("sway", 0.0))
		lift = g
	elif _flying.has(p):
		var f: Dictionary = _flying[p]
		var u := clampf((t - float(f["at"])) / FLY_TIME, 0.0, 1.0)
		var e := Motion.back_out(u)
		pos = (f["from"] as Vector2).lerp(f["to"] as Vector2, e)
		cell = lerpf(float(f["c0"]), float(f["c1"]), e)
		if not Motion.reduce:
			pos.y -= sin(u * PI) * FLY_ARC * float(f["c0"])
			lift = sin(u * PI)
		if _refused.has("patch") and int(_refused["patch"]) == p:
			pos.x += Motion.shiver_offset(t - float(_refused["at"]))
	elif int(_state.at[p]) >= 0:
		pos = _corner_of(int(_state.at[p]))
		var since := t - float(_landed.get(p, -100.0))
		if _glide.has(p):
			var land := _land(p, pos, since)
			pos = land["pos"]
			sc = land["sc"]
			lift = float(land["lift"])
		else:
			sc = Motion.pop_in_scale(since)
		# A given refusing to be picked up shivers where it lies; it has no
		# flight to shiver along.
		if not _refused.is_empty() and int(_refused["patch"]) == p:
			pos.x += Motion.shiver_offset(t - float(_refused["at"]))
		rot = _wiggle_angle(p, t)
		if _solved_at >= 0.0:
			pos.y += _solve_hop(p, t)
			face = face.lerp(Pal.SURFACE, SHEEN * _sheen(p, t))
	else:
		pos = _bay_home(p)
		cell = _rack_cell()
		var since := t - _opened - Motion.ENTER_DELAY - Motion.stagger(p, Motion.ENTER_STAGGER)
		sc = Motion.pop_in_scale(since)
		alpha = Motion.appear_level(since, Motion.ENTER_POP)
		rot = _wiggle_angle(p, t)
	return {"pos": pos, "cell": cell, "sc": sc, "alpha": alpha, "rot": rot,
		"lift": lift, "face": face}

## How far the patch in the hand has grown from the cell it was picked up at
## to the quilt's, 0 to 1, with the back ease so it overshoots a touch.
##
## It waits GROW_WAIT, or until the finger has moved, before it grows: a tap
## is let go inside that and must not have lifted anything.
func _grow(t: float) -> float:
	var go := float(_drag.get("go", float(_drag["since"]) + GROW_WAIT))
	if Motion.reduce:
		return 1.0 if t >= go else 0.0
	return Motion.back_out(clampf((t - go) / GROW_TIME, 0.0, 1.0))

## A tapped patch's wiggle where it lies: WIGGLE_TIME of Motion's wobble.
func _wiggle_angle(p: int, t: float) -> float:
	if not _wiggle.has(p):
		return 0.0
	return Motion.wobble_angle(t - float(_wiggle[p]), WIGGLE_ANGLE, WIGGLE_TIME)

## The wrong patch, read off its own clock (see SNIP_AT and the rest): it
## glides down onto the spot it was let go over, lands, sits while its
## needle sews, then peels up by a corner and flutters home to its bay,
## wobbling as it goes. Drawn in the hand's mesh, over everything.
func _peel_frame(t: float) -> Dictionary:
	var p := int(_peel["patch"])
	var e := t - float(_peel["at"])
	var corner := _corner_of(int(_peel["origin"]))
	var cell := _cell()
	var face: Color = Cloth.cloth(p)
	var out := {"pos": corner, "cell": cell, "sc": Vector2.ONE, "alpha": 1.0, "rot": 0.0,
		"lift": 0.0, "face": face}
	if e < LAND_TIME:
		var u := clampf(e / LAND_TIME, 0.0, 1.0)
		if u < LAND_GLIDE:
			var g := u / LAND_GLIDE
			var k := g * g * (3.0 - 2.0 * g)
			out["pos"] = (_peel["hand"] as Vector2).lerp(corner, k)
			out["sc"] = Vector2.ONE * lerpf(Motion.LIFT_SCALE, 1.0, k)
			out["lift"] = 1.0 - k
		else:
			var v := (u - LAND_GLIDE) / (1.0 - LAND_GLIDE)
			var a := LAND_SQUASH * sin(v * TAU) * (1.0 - v)
			out["sc"] = Vector2(1.0 + a, 1.0 - a)
		return out
	var peel_at := SNIP_AT + UNRAVEL_TIME
	if e < peel_at:
		out["pos"] = corner + Vector2(Motion.shiver_offset(e - SNIP_AT, 3.0, 0.24), 0.0)
		return out
	var risen := corner + Vector2(PEEL_RISE * 0.4, -PEEL_RISE) * cell
	if e < peel_at + PEEL_TIME:
		var u := clampf((e - peel_at) / PEEL_TIME, 0.0, 1.0)
		var k := 1.0 - (1.0 - u) * (1.0 - u)
		out["pos"] = corner.lerp(risen, k)
		out["rot"] = PEEL_TILT * k
		out["lift"] = k
		out["sc"] = Vector2.ONE * lerpf(1.0, Motion.LIFT_SCALE, k)
		return out
	var u := clampf((e - peel_at - PEEL_TIME) / FLUTTER_TIME, 0.0, 1.0)
	var k := u * u * (3.0 - 2.0 * u)
	var home := _bay_home(p)
	var rc := _rack_cell()
	out["cell"] = lerpf(cell, rc, k)
	out["pos"] = risen.lerp(home, k) - Vector2(0.0, sin(u * PI) * FLY_ARC * cell)
	out["rot"] = PEEL_TILT * (1.0 - k) + FLUTTER_WOBBLE * sin(u * 3.0 * PI) * (1.0 - u)
	out["lift"] = 1.0 - k
	out["sc"] = Vector2.ONE * lerpf(Motion.LIFT_SCALE, 1.0, k)
	return out

## How much of the wrong patch's quilting stitch is sewn at `t`: the needle
## runs until the snip, then the stitch unravels backward to nothing.
func _peel_stitch(t: float) -> float:
	var e := t - float(_peel["at"])
	var sewn := LAND_TIME * LAND_GLIDE
	var at_snip := clampf((SNIP_AT - sewn) / SEW_TIME, 0.0, 1.0)
	if e < SNIP_AT:
		return clampf((e - sewn) / SEW_TIME, 0.0, 1.0)
	return at_snip * clampf(1.0 - (e - SNIP_AT) / UNRAVEL_TIME, 0.0, 1.0)

## The whole of a wrong patch's way home, from its release.
func _peel_span() -> float:
	return SNIP_AT + UNRAVEL_TIME + PEEL_TIME + FLUTTER_TIME

## The patch in the hand drawn at `cell` and `g` of the way up: the cell it
## was taken hold of stays under the finger, and it rises HOLD_LIFT above
## the thumb as it grows. At g = 1 this is `_held_corner()` exactly.
func _held_corner_at(cell: float, g: float) -> Vector2:
	var grab: Vector2i = _drag["grab"]
	var point: Vector2 = _drag["point"]
	return point - Vector2(float(grab.x) + 0.5, float(grab.y) + 0.5 + HOLD_LIFT * g) * cell

## A patch let go where it fits: it glides from where the hand held it onto
## its snapped cells, shrinking from the hand's lift as its shadow closes
## under it, then lands -- wide and low, and back, once. {"pos", "sc",
## "lift"}.
func _land(p: int, corner: Vector2, since: float) -> Dictionary:
	if Motion.reduce or since >= LAND_TIME:
		return {"pos": corner, "sc": Vector2.ONE, "lift": 0.0}
	var u := clampf(since / LAND_TIME, 0.0, 1.0)
	if u < LAND_GLIDE:
		var g := u / LAND_GLIDE
		var e := g * g * (3.0 - 2.0 * g)
		return {"pos": (_glide[p] as Vector2).lerp(corner, e),
			"sc": Vector2.ONE * lerpf(Motion.LIFT_SCALE, 1.0, e), "lift": 1.0 - e}
	var v := (u - LAND_GLIDE) / (1.0 - LAND_GLIDE)
	var a := LAND_SQUASH * sin(v * TAU) * (1.0 - v)
	return {"pos": corner, "sc": Vector2(1.0 + a, 1.0 - a), "lift": 0.0}

## The solve's light on patch `p`: 0 to 1 and back as the diagonal front
## crosses its middle.
func _sheen(p: int, t: float) -> float:
	var mid := _centroid(p)
	return Motion.flash_level(t - _solved_at - Motion.SOLVE_DELAY
		- Motion.stagger(int(mid.x + mid.y), Motion.SOLVE_STAGGER), Motion.FLASH_IN, Motion.SOLVE_TIME)

## The top-left of the patch in the hand: the cell under the finger, less the
## cell of the patch that was taken hold of, and lifted HOLD_LIFT above the
## thumb so the shape being placed is never under it.
func _held_corner() -> Vector2:
	var cell := _cell()
	var grab: Vector2i = _drag["grab"]
	var point: Vector2 = _drag["point"]
	return point - Vector2(float(grab.x) + 0.5, float(grab.y) + 0.5 + HOLD_LIFT) * cell

## The cell the held patch's own (0, 0) is over, snapped: what a release
## would try to place it at.
func _held_cell() -> Vector2i:
	var cell := _cell()
	if cell <= 0.0:
		return Vector2i(-1000, -1000)
	var p := (_held_corner() - _origin()) / cell
	return Vector2i(int(round(p.x)), int(round(p.y)))

## The origin index a release would ask for, or -1 when the patch's own
## (0, 0) is not over the grid at all.
##
## **The bounds have to be exactly the grid**, because the origin is packed
## into one int as `row * cols + column` and an out-of-range column wraps
## onto another row: held one cell off the left edge at row 2 of a 5-wide
## quilt, `-1` encodes as origin 9, which decodes as column 4 of row 1 --
## the far side of the board. Measured before it was fixed: of the holds a
## looser guard admitted, **2,386 came back `fits() == OK`** across 120
## boards, so a patch dragged off one edge could be sewn on at the other.
##
## Nothing is lost by the tight test. A shape is normalised, so some cell of
## it has an x-offset of 0 and some cell has a y-offset of 0; for every cell
## to land on the grid, the origin itself must therefore be on it.
func _held_origin() -> int:
	var at := _held_cell()
	if at.x < 0 or at.y < 0 or at.x >= _state.cols or at.y >= _state.rows:
		return -1
	return at.y * _state.cols + at.x

## The solve wave's hop for a patch, off its top-left cell's diagonal.
func _solve_hop(p: int, t: float) -> float:
	var origin := int(_state.at[p])
	if origin < 0:
		return 0.0
	var c: int = origin % _state.cols
	var r: int = origin / _state.cols
	var since := t - _solved_at - Motion.SOLVE_DELAY - Motion.stagger(c + r, Motion.SOLVE_STAGGER)
	return Motion.hop_lift(since, Motion.SOLVE_HOP, Motion.SOLVE_TIME)

# --- the seams, derived every frame ---

## Every seam on the quilt as it stands: an edge between two patches, or one
## between a patch and the world off the quilt -- the hem. **Nothing here is
## stored.** A seam exists because two patches are where they are, so lifting
## either takes it away and undo keeps no book for it; that is Queens' and
## Sudoku's `_settle` in a third shape.
##
## Each seam carries the moment it came into being (the later of its two
## patches' landings) and the colour of the patch that made it, so the wave
## runs out of the patch that was just sewn on and not out of its neighbour.
func _seams() -> Array:
	var out: Array = []
	var cell := _cell()
	var o := _origin()
	for r in _state.rows:
		for c in _state.cols:
			var p := _state.patch_at_cell(c, r)
			if p < 0:
				continue
			var here := Vector2(float(c), float(r))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q := _state.patch_at_cell(c + d.x, r + d.y)
				var off := not _state.in_region(c + d.x, r + d.y)
				if not off and q == p:
					continue
				if not off and q < 0:
					continue      # a raw edge: there is nothing yet to sew to
				if not off and (d.x < 0 or d.y < 0):
					continue      # the neighbour's own pass draws this seam
				var a: Vector2
				var b: Vector2
				if d == Vector2i(1, 0):
					a = here + Vector2(1.0, 0.0); b = here + Vector2(1.0, 1.0)
				elif d == Vector2i(0, 1):
					a = here + Vector2(0.0, 1.0); b = here + Vector2(1.0, 1.0)
				elif d == Vector2i(-1, 0):
					a = here; b = here + Vector2(0.0, 1.0)
				else:
					a = here; b = here + Vector2(1.0, 0.0)
				var owner := p
				var when := _sewn_at(p)
				if q >= 0 and _sewn_at(q) > when:
					owner = q
					when = _sewn_at(q)
				out.append({
					"a": o + a * cell, "b": o + b * cell,
					"owner": owner, "at": when,
					"reach": (a + b) * 0.5 - _centroid(owner),
					"hem": off,
				})
	return out

## A patch's middle, in cells of the quilt: where its seam wave starts.
func _centroid(p: int) -> Vector2:
	var origin := int(_state.at[p])
	if origin < 0:
		return Vector2.ZERO
	var at := Vector2(float(origin % _state.cols), float(origin / _state.cols))
	var sum := Vector2.ZERO
	var cells: Array = _state.shapes[p]
	for c: Vector2i in cells:
		sum += at + Vector2(c) + Vector2(0.5, 0.5)
	return sum / float(maxi(cells.size(), 1))

# --- the drawing ---

## The backing under everything, which pops in wide about its centre while it
## fades (rule 7: a wide thing comes from most of the way); the patches sewn
## on it; the seams over them; then the rack, and last of all the patch in
## the hand, which has to draw over the lot.
func _draw() -> void:
	if _state.shapes.is_empty() or _cell() <= 0.0:
		return
	var t := _now()
	var shown: Array = []
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	var grow := Motion.wide_pop_scale(since)
	if _rack == null:
		_rack = _build_rack(t)
	if seen > 0.0:
		var mid := _field_centre()
		var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
		if _ground == null:
			_ground = _build_ground()
		if _ground != null:
			draw_mesh(_ground, null, xf, Color(1.0, 1.0, 1.0, seen))
			shown.append(_ground)
		if _quilt == null:
			_quilt = _build_quilt(t)
		if _quilt != null:
			draw_mesh(_quilt, null, xf, Color(1.0, 1.0, 1.0, seen))
			shown.append(_quilt)
		_draw_tag(t, xf, seen, shown)
	if _mat_mesh == null:
		var mb := Face.Builder.new()
		_mat(mb)
		_mat_mesh = _mesh(mb)
	if _mat_mesh != null:
		draw_mesh(_mat_mesh, null)
		shown.append(_mat_mesh)
	if _rack == null:
		_rack = _build_rack(t)
	if _rack != null:
		draw_mesh(_rack, null)
		shown.append(_rack)
	if _hand == null:
		_hand = _build_hand(t)
	if _hand != null:
		draw_mesh(_hand, null)
		shown.append(_hand)
	_shown = shown

## The sewn-in label on the backing's corner: a little cloth tag, woven band
## and stitched edge, counting the squares still bare. It bumps when the
## count changes. One mesh, cached until the layout moves, and one string.
func _draw_tag(t: float, xf: Transform2D, seen: float, shown: Array) -> void:
	var count: int = maxi(0, _state.quilt_cells - _state.covered())
	if count != _tag_count:
		if _tag_count >= 0 and not Motion.reduce:
			_tag_at = t
		_tag_count = count
	var box := _tag_rect()
	if _tag_mesh == null:
		_tag_mesh = _build_tag(box)
	var mid := box.get_center()
	var k := Motion.bump_scale(t - _tag_at, 0.22) if t - _tag_at < Motion.BUMP_TIME else 1.0
	var at := xf * Transform2D(0.0, Vector2.ONE * k, 0.0, mid * (1.0 - k))
	draw_mesh(_tag_mesh, null, at, Color(1.0, 1.0, 1.0, seen))
	shown.append(_tag_mesh)
	var font: Font = CozyTheme.display(700)
	var text := str(count)
	var px := TAG_FONT if count < 100 else int(TAG_FONT * 0.75)
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var rise := font.get_height(px) * 0.5 - font.get_descent(px)
	var c := mid + Vector2(TAG_SIZE.x * (-0.1 if _tag_left else 0.1), 0.0)
	draw_set_transform_matrix(at)
	draw_string(font, c + Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
		Color(Pal.TEXT, seen))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## Where the label hangs: sewn to the right-hand end of the backing's top
## row, in whatever is right of it -- the empty corner of the bounding box,
## or the field's side margin -- so it never covers a backing cell. Mirrored
## onto the row's left end when the right has no room.
func _tag_rect() -> Rect2:
	var o := _origin()
	var cell := _cell()
	var lo: int = _state.cols
	var hi := -1
	for c in _state.cols:
		if _state.in_region(c, 0):
			lo = mini(lo, c)
			hi = maxi(hi, c)
	var y := o.y + maxf(0.0, (minf(cell, TAG_SIZE.y + 24.0) - TAG_SIZE.y) * 0.5)
	var right := o.x + float(hi + 1) * cell + TAG_GAP
	_tag_left = right + TAG_SIZE.x > size.x - INSET * 0.4
	if not _tag_left:
		return Rect2(Vector2(right, y), TAG_SIZE)
	return Rect2(Vector2(o.x + float(lo) * cell - TAG_GAP - TAG_SIZE.x, y), TAG_SIZE)

## The tag itself: cream cloth over a deeper lip, a rose woven band down the
## edge it is sewn by, a running stitch round inside it, and two tacks of
## thread holding it to the backing.
func _build_tag(box: Rect2) -> ArrayMesh:
	var b := Face.Builder.new()
	var left := _tag_left
	var pts := Face.Builder.round_rect(box.position, box.size, TAG_R)
	b.polygon(Cloth._moved(pts, Vector2(0.0, 4.0)), TAG_EDGE)
	b.polygon(pts, TAG)
	var band_w := box.size.x * 0.2
	var band_x := box.end.x - band_w if left else box.position.x
	b.polygon(Face.Builder.round_rect(Vector2(band_x, box.position.y), Vector2(band_w, box.size.y),
		TAG_R * 0.7), TAG_BAND)
	# The weave across the band: fine light ticks.
	var y := box.position.y + 7.0
	while y < box.end.y - 5.0:
		b.stroke(PackedVector2Array([Vector2(band_x + 3.0, y), Vector2(band_x + band_w - 3.0, y)]),
			1.6, Color(TAG, 0.45), false, false)
		y += 6.0
	var inner := Rect2(box.position + Vector2(5.0, 5.0), box.size - Vector2(10.0, 10.0))
	if left:
		inner.size.x -= band_w
	else:
		inner.position.x += band_w
		inner.size.x -= band_w
	Cloth.dash_loop(b, Face.Builder.round_rect(inner.position, inner.size, TAG_R * 0.6),
		2.0, 6.0, 4.0, Color(TAG_BAND, 0.7))
	# The tacks: three short stitches of thread from the band onto the
	# backing's edge.
	var edge := box.end.x if left else box.position.x
	var dir := 1.0 if left else -1.0
	for fy in [0.22, 0.5, 0.78]:
		var at := Vector2(edge, box.position.y + box.size.y * fy)
		b.stroke(PackedVector2Array([at + Vector2(-dir * 7.0, 0.0), at + Vector2(dir * (TAG_GAP + 7.0), 0.0)]),
			3.0, Pal.LINE, false, true)
	return _mesh(b)

## The quilt: the backing and its rules, the ghost of a drop under the
## finger, every patch sewn on, the glow round a patch a hint sewed, and the
## seams over the lot. The order is the only one that works -- a seam drawn
## under a patch is a seam nobody sees.
func _build_quilt(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_ghost(b, t)
	# Landed patches first and the one still gliding down last, so a patch
	# on its way onto the quilt passes over its neighbours and not under.
	var order: Array = []
	for p in _state.shapes.size():
		if int(_state.at[p]) < 0 or (not _drag.is_empty() and int(_drag["patch"]) == p):
			continue
		order.append(p)
	order.sort_custom(func(a: int, z: int) -> bool:
		return float(_landed.get(a, -100.0)) < float(_landed.get(z, -100.0)))
	for p: int in order:
		var f := _frame_of(p, t)
		_patch(b, p, f, true)
		if int(_state.locked[p]) == 1:
			_hint_glow(b, p, f)
	_stitches(b, t)
	_dead_pulse(b, t)
	return _mesh(b)

## The dead end on Easy and Medium: every bare cell no patch left can reach
## wears a rose halo that pulses DEAD_PULSES times. Under reduce motion it
## stands, steady, until the board changes.
func _dead_pulse(b, t: float) -> void:
	if _dead.is_empty():
		return
	var e := t - float(_dead["at"])
	var level := 1.0
	if not Motion.reduce:
		if e < 0.0 or e >= DEAD_BEAT * DEAD_PULSES:
			return
		level = sin(fmod(e, DEAD_BEAT) / DEAD_BEAT * PI)
	if level <= 0.01:
		return
	var cell := _cell()
	var o := _origin()
	for i: int in (_dead["cells"] as PackedInt32Array):
		var at := o + Vector2(float(i % _state.cols), float(i / _state.cols)) * cell
		var pts := Face.Builder.round_rect(at + Vector2.ONE * cell * 0.08, Vector2.ONE * cell * 0.84,
			cell * 0.18)
		b.polygon(pts, Color(Pal.BAD, 0.16 * level))
		b.stroke(pts, DEAD_W * cell, Color(Pal.BAD, HALO_ALPHA * level), true)

## The backing, built once a layout: a pale piece of cloth with the
## patches' own silhouette and lip, the faint rules of the grid the patches
## snap to, a puff of batting in every cell and a tie of thread wherever four
## puffs meet. A tufted quilt top, before anything is sewn onto it.
func _build_ground() -> ArrayMesh:
	var b := Face.Builder.new()
	var cell := _cell()
	var o := _origin()
	Cloth.patch(b, _back_loops, o, cell, Vector2i.ZERO, Pal.QUILT_BACK, Pal.LINE)
	var rule := Color(Pal.QUILT_RULE, RULE_ALPHA)
	for pair: Array in _back_rules:
		b.stroke(PackedVector2Array([o + (pair[0] as Vector2) * cell,
			o + (pair[1] as Vector2) * cell]), RULE_W * cell, rule, false, false)
	var puff := Color(Pal.SURFACE, PUFF_ALPHA)
	for c: Vector2i in _back_cells:
		b.polygon(Face.Builder.round_rect(o + (Vector2(c) + Vector2.ONE * PUFF_INSET) * cell,
			Vector2.ONE * (1.0 - 2.0 * PUFF_INSET) * cell, PUFF_R * cell), puff)
	var tie := Color(Pal.LINE, 0.85)
	for c: Vector2i in _back_cells:
		# The tie at this cell's top-left corner, where it meets three others.
		if not (_state.in_region(c.x - 1, c.y) and _state.in_region(c.x, c.y - 1)
				and _state.in_region(c.x - 1, c.y - 1)):
			continue
		var at := o + Vector2(c) * cell
		var d := TIE_LEN * cell
		b.stroke(PackedVector2Array([at + Vector2(-d, -d), at + Vector2(d, d)]), TIE_W * cell, tie)
		b.stroke(PackedVector2Array([at + Vector2(d, -d), at + Vector2(-d, d)]), TIE_W * cell, tie)
	return _mesh(b)

## The rack: every patch still waiting, any flying home to it, and the faint
## shape of every one that has gone.
##
## **The empty bays are drawn, and they have to be.** Without them the rack
## empties as the quilt fills and the bottom four hundred pixels of the card
## go blank -- the last patch is dragged across a void. The cut shape left
## behind keeps the rack's composition, says which patch came from where,
## and is honest about the one thing the player can still do with it: drag
## it back. It is the patch's own silhouette at GONE_ALPHA, with no lip,
## because a lip is what says a thing is sitting on top of something.
func _build_rack(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var cell := _rack_cell()
	var chalk := Color(MAT_STITCH, 0.95)
	for p in _state.shapes.size():
		var held: bool = (not _drag.is_empty() and int(_drag["patch"]) == p) \
			or (not _peel.is_empty() and int(_peel["patch"]) == p)
		if held or (int(_state.at[p]) >= 0 and not _flying.has(p)):
			for loop: PackedVector2Array in _loops[p]:
				var pts := Cloth.laid(loop, _bay_home(p), cell, _spans[p])
				b.polygon(pts, Color(Cloth.cloth(p), GONE_ALPHA))
				Cloth.dash_loop(b, pts, CHALK_W * cell, CHALK_ON * cell, CHALK_OFF * cell, chalk)
			continue
		if not _flying.has(p):
			_patch(b, p, _frame_of(p, t))
	# The flights last, so a patch on its way home passes over the ones
	# still waiting rather than under them.
	for p in _flying:
		_patch(b, int(p), _frame_of(int(p), t))
	return _mesh(b)

## The felt mat the rack's patches wait on: a soft sage felt with a lip and
## a stitched border, so the rack reads as a place the cloth is kept and not
## as patches floating on the card.
func _mat(b) -> void:
	var box := _rack_box().grow(MAT_PAD)
	box.size.y = minf(box.size.y, size.y - INSET * 0.5 - box.position.y)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	if not _state.scraps().is_empty():
		_basket(b, box)
		return
	var pts := Face.Builder.round_rect(box.position, box.size, MAT_R)
	b.polygon(Cloth._moved(pts, Vector2(0.0, 5.0)), MAT_EDGE)
	b.polygon(pts, MAT)
	var inner := box.grow(-12.0)
	Cloth.dash_loop(b, Face.Builder.round_rect(inner.position, inner.size, MAT_R - 10.0),
		3.5, 12.0, 8.0, MAT_STITCH)

## Scrap Basket's rack: the felt mat becomes a wicker basket -- pale straw
## with faint stakes and weavers, a woven band of over-and-under strands
## along its foot, and a thick twisted rim along the top -- so the twelve
## patches read as a basket of cloth with some in it that do not belong. The
## body is kept pale and faint: it is a ground, and every cloth on it,
## the yellows included, has to stay the strongest thing on the card.
func _basket(b, box: Rect2) -> void:
	var pts := Face.Builder.round_rect(box.position, box.size, MAT_R)
	b.polygon(Cloth._moved(pts, Vector2(0.0, 6.0)), WICKER_DEEP)
	b.polygon(pts, WICKER)
	var inner := box.grow(-12.0)
	inner.position.y += RIM_H * 0.5
	inner.size.y -= RIM_H * 0.5 + BAND_H
	# The stakes, upright, and the weavers passing between them: a row of
	# soft lenses offset by half a stake from the row above, faint.
	var x := inner.position.x + STAKE * 0.5
	while x < inner.end.x:
		b.stroke(PackedVector2Array([Vector2(x, inner.position.y), Vector2(x, inner.end.y)]),
			2.0, Color(WICKER_LINE, 0.22), false, false)
		x += STAKE
	var row := 0
	var y := inner.position.y + 4.0
	while y + 12.0 < inner.end.y:
		var sx := inner.position.x + (STAKE * 0.5 if row % 2 == 1 else 0.0)
		while sx < inner.end.x - 6.0:
			var a := maxf(sx + 3.0, inner.position.x)
			var z := minf(sx + STAKE - 3.0, inner.end.x)
			if z - a > 10.0:
				b.ellipse(Vector2((a + z) * 0.5, y + 6.0), (z - a) * 0.5, 5.0, Color(WICKER_HI, 0.5))
			sx += STAKE
		y += 16.0
		row += 1
	# The woven band at the foot: short strands alternately across and
	# upright, a basket weave, in the deeper straw.
	var band := Rect2(Vector2(box.position.x + 10.0, box.end.y - BAND_H - 10.0),
		Vector2(box.size.x - 20.0, BAND_H))
	b.polygon(Face.Builder.round_rect(band.position, band.size, 10.0), Color(WICKER_DEEP, 0.35))
	var cells := int(floor(band.size.x / BAND_H))
	var w := band.size.x / float(maxi(cells, 1))
	for k in cells:
		var at := Vector2(band.position.x + w * k, band.position.y)
		for n in 3:
			var f := (float(n) + 0.5) / 3.0
			if k % 2 == 0:
				b.stroke(PackedVector2Array([at + Vector2(5.0, BAND_H * f), at + Vector2(w - 5.0, BAND_H * f)]),
					BAND_H / 3.0 - 4.0, WICKER_HI, false, true)
			else:
				b.stroke(PackedVector2Array([at + Vector2(w * f, 5.0), at + Vector2(w * f, BAND_H - 5.0)]),
					w / 3.0 - 4.0, WICKER_HI.lerp(WICKER, 0.5), false, true)
	# The rim: a thick rounded band along the top, its twist drawn as slanted
	# strokes.
	var rim := Rect2(box.position - Vector2(4.0, 4.0), Vector2(box.size.x + 8.0, RIM_H))
	var rp := Face.Builder.round_rect(rim.position, rim.size, RIM_H * 0.5)
	b.polygon(Cloth._moved(rp, Vector2(0.0, 4.0)), WICKER_DEEP)
	b.polygon(rp, WICKER_LINE)
	var tx := rim.position.x + RIM_H * 0.5
	while tx < rim.end.x - RIM_H * 0.5:
		b.stroke(PackedVector2Array([Vector2(tx, rim.end.y - 5.0), Vector2(tx + 12.0, rim.position.y + 5.0)]),
			4.0, Color(WICKER_HI, 0.8), false, true)
		tx += 16.0

## The patch in the hand, alone, so it draws over the quilt and the rack
## alike -- and a wrong patch on its way home, which has to pass over both.
func _build_hand(t: float) -> ArrayMesh:
	if _drag.is_empty() and _peel.is_empty():
		return null
	var b := Face.Builder.new()
	if not _peel.is_empty():
		var p := int(_peel["patch"])
		_patch(b, p, _frame_of(p, t), true, _peel_stitch(t))
	if not _drag.is_empty():
		var p := int(_drag["patch"])
		var f := _frame_of(p, t)
		_patch(b, p, f)
		if _hold_state() == CROSSED:
			_chalk_cross(b, p, f)
	return _mesh(b)

## Tailor's chalk crossed over every square of the held patch: it was tried
## here and was wrong. Drawn on the patch itself, because the footprint
## under it is hidden by the patch the finger holds over it.
func _chalk_cross(b, p: int, f: Dictionary) -> void:
	var cell := float(f["cell"])
	var d := cell * 0.2
	var ink := Color(CROSS, 0.9)
	for c: Vector2i in (_state.shapes[p] as Array):
		var mid := Cloth.place(Vector2(c) + Vector2(0.5, 0.5), f["pos"], cell, _spans[p], f["sc"],
			float(f.get("rot", 0.0)))
		b.stroke(PackedVector2Array([mid + Vector2(-d, -d), mid + Vector2(d, d)]), CROSS_W * cell, ink)
		b.stroke(PackedVector2Array([mid + Vector2(d, -d), mid + Vector2(-d, d)]), CROSS_W * cell, ink)

## A builder's mesh, or null when it has nothing in it. Asking an empty
## builder for a mesh is an engine error ("array_len == 0"), and each of
## these three is empty at some point: the rack while the entrance is still
## scaling its patches up from nothing, the quilt before a patch is on it,
## and the hand between drags.
func _mesh(b) -> ArrayMesh:
	return b.mesh() if not b.verts.is_empty() else null

## One patch, in its cloth -- or in the family's rose while it is being
## refused, which is the one thing that can change a patch's colour.
##
## Every patch wears its print; a patch sewn on the quilt (`sewn`) also wears
## the quilting stitch just inside its edge, which is what tells a patch that
## is sewn from one only lying there -- and a lifted one casts its shadow.
func _patch(b, p: int, f: Dictionary, sewn := false, reach := -1.0) -> void:
	var cell := float(f["cell"])
	var lift := float(f.get("lift", 0.0))
	Cloth.shadow(b, _loops[p], f["pos"], cell, _spans[p], HELD_SHADOW * cell * lift,
		minf(lift * 1.5, 1.0) * float(f["alpha"]), f["sc"], float(f.get("rot", 0.0)))
	Cloth.patch(b, _loops[p], f["pos"], cell, _spans[p],
		f.get("face", Cloth.cloth(p)), Cloth.cloth_deep(p), f["sc"], float(f["alpha"]),
		float(f.get("rot", 0.0)))
	Cloth.print_cloth(b, _state.shapes[p], p, f["pos"], cell, _spans[p],
		f["sc"], float(f["alpha"]), float(f.get("rot", 0.0)))
	if sewn:
		_quilting(b, p, f, reach)
	_blush(b, p, f)

## The quilting stitch round inside a sewn patch's edge, run by a needle over
## SEW_TIME from the moment the patch touched the backing. It is there the
## moment the patch is under reduce-motion.
##
## `reach` overrides how much is sewn: the wrong patch's stitch, which runs
## and then unravels, is on its own clock.
func _quilting(b, p: int, f: Dictionary, reach := -1.0) -> void:
	var t := _now()
	var u := 1.0 if Motion.reduce else clampf((t - _sewn_at(p)) / SEW_TIME, 0.0, 1.0)
	var needle := u < 1.0
	if reach >= 0.0:
		u = reach
		needle = u > 0.0 and t - float(_peel.get("at", t)) < SNIP_AT
	if u <= 0.0:
		return
	var cell := float(f["cell"])
	var ink := Cloth.cloth_thread(p)
	if _solved_at >= 0.0:
		ink = ink.lerp(Pal.SUN_RAY, _sheen(p, t))
	for loop: PackedVector2Array in _insets[p]:
		var pts := Cloth.laid(loop, f["pos"], cell, _spans[p], f["sc"],
			float(f.get("rot", 0.0)), Cloth.RADIUS * 0.6)
		var total := Cloth.perimeter(pts)
		Cloth.dash_loop(b, pts, Cloth.QUILT_W * cell, Cloth.QUILT_ON * cell,
			Cloth.QUILT_OFF * cell, ink, total * u)
		if needle:
			var head: Array = Cloth.along(pts, total * u)
			Cloth.needle(b, head[0], head[1], cell, ink)

## A patch that is being turned down wears a rose **halo** round its
## silhouette. It does not blush.
##
## **The cloth cannot blush**, and this is measured rather than felt. The
## eight cloths run right round the wheel, so there is no one rose they can
## all be taken toward: at 0.30 the teal drops from 0.34 saturation to
## **0.07** and comes back dead grey, the sage swings from hue 91 to 49 and
## comes back khaki, and the sky goes to 265 and comes back mauve. Only the
## four warm cloths blush at all. A wash that means "wrong" on half a rack
## and "muddy" on the other half is worse than no wash.
##
## That is `docs/art/flat-motion.md`'s **rule 9** -- a piece with no
## blushing variant blushes through its cell -- read for a piece that *is*
## its own shape and covers several cells: the halo is drawn beside the
## cloth rather than mixed into it, so it reads the same on all eight. The
## piece still moves; the halo carries the colour.
func _blush(b, p: int, f: Dictionary) -> void:
	var level := 0.0
	if not _refused.is_empty() and int(_refused["patch"]) == p and bool(_refused.get("halo", true)):
		level = Motion.flash_level(_now() - float(_refused["at"]))
	elif not _drag.is_empty() and int(_drag["patch"]) == p and _hold_state() == SNAG:
		# Held over the quilt somewhere it will not go. The hand says so
		# while it is held, rather than the board waiting for the release --
		# a drag is a question, and this is the only moment the board can
		# answer it before the answer costs anything.
		level = 1.0
	if level <= 0.0:
		return
	var cell := float(f["cell"])
	for loop: PackedVector2Array in _loops[p]:
		b.stroke(Cloth.laid(loop, f["pos"], cell, _spans[p], f["sc"], float(f.get("rot", 0.0))),
			HALO_W * cell, Color(Pal.BAD, HALO_ALPHA * level), true)

## The glow a hint's patch keeps: a soft sun ring round its silhouette, so a
## patch that was given is never mistaken for one that was worked out.
func _hint_glow(b, p: int, f: Dictionary) -> void:
	var cell := float(f["cell"])
	for loop: PackedVector2Array in _loops[p]:
		b.stroke(Cloth.laid(loop, f["pos"], cell, _spans[p], f["sc"]),
			GIVEN_W * cell, Color(Pal.SUN, GIVEN_GLOW), true)

## What the hand is over: CLEAR when no cell of the held patch is on the
## quilt at all, FITS when a release would sew it on, and SNAG when it is
## over the quilt and will not go.
##
## The three are not the same as `fits()`'s two, and the difference is the
## whole of the drag's feedback: a patch on its way up from the rack spends
## most of the journey not fitting anywhere, and blushing all the way would
## be a board shouting at a player who has not done anything yet.
const CLEAR := 0
const FITS := 1
const SNAG := 2
## A judged board: the held patch is over a spot a heart already proved
## wrong for its shape. A drop there is refused for free.
const CROSSED := 3

func _hold_state() -> int:
	if _drag.is_empty():
		return CLEAR
	if not _drag.has("go") and _now() < float(_drag["since"]) + GROW_WAIT:
		return CLEAR
	var p := int(_drag["patch"])
	var target := _target()
	if target >= 0:
		return CROSSED if _state.judged() and _state.is_ruled(p, target) else FITS
	var origin := _held_origin()
	if origin < 0:
		return CLEAR
	var over := 0
	for c: Vector2i in (_state.patch_cells(p, origin) as Array):
		if _state.in_region(c.x, c.y):
			over += 1
	return SNAG if over > 0 else CLEAR

## Where a release would sew the held patch: the rounded cell when the patch
## fits there, else **the nearest cell within STICKY that it fits at** --
## sticky snap, so a patch let go half a cell off a fit is not refused. -1
## when nothing fits that near. The ghost reads this, so the outline under
## the finger is always exactly where the patch will go.
##
## `fits()` is geometry alone, so a spot a heart ruled is still a candidate
## and comes back here: the ghost then wears the chalk cross, and the drop is
## refused for free.
func _target() -> int:
	if _drag.is_empty():
		return -1
	var p := int(_drag["patch"])
	var raw := _held_origin()
	if raw >= 0 and _state.fits(p, raw) == State.OK:
		return raw
	var cell := _cell()
	if cell <= 0.0:
		return -1
	var at := (_held_corner() - _origin()) / cell
	var best := -1
	var best_d := STICKY + 0.0001
	for r in range(int(floor(at.y - STICKY)), int(ceil(at.y + STICKY)) + 1):
		for c in range(int(floor(at.x - STICKY)), int(ceil(at.x + STICKY)) + 1):
			if c < 0 or r < 0 or c >= _state.cols or r >= _state.rows:
				continue
			var d := at.distance_to(Vector2(float(c), float(r)))
			if d >= best_d:
				continue
			var origin: int = r * _state.cols + c
			if _state.fits(p, origin) == State.OK:
				best = origin
				best_d = d
	return best

## Where the patch in the hand would land, on whole cells while the patch
## above it follows the finger: a wash in its own cloth with a thread drawn
## round it when it fits, a **dashed rose thread alone** when it will not
## go, and on a judged board a **chalk cross** over a spot a heart already
## ruled for it.
##
## **The outline is not decoration.** The patch is held above the thumb and
## the footprint snaps underneath it, so the patch covers most of the wash
## and only its edges peek out; a wash on its own is a hint of a hint. The
## thread is what makes the footprint readable. And the refusing case gets
## no wash at all, because a patch that will not go is partly *off* the
## backing by definition and a rose wash would be painted onto the card.
func _ghost(b, _t: float) -> void:
	var state := _hold_state()
	if state == CLEAR:
		return
	var p := int(_drag["patch"])
	var origin := _target() if state != SNAG else _held_origin()
	var cells: Array = _state.patch_cells(p, origin)
	if cells.is_empty():
		return
	var cell := _cell()
	for loop: PackedVector2Array in Cloth.loops(cells):
		var pts := Cloth.laid(loop, _origin(), cell, Vector2i.ZERO)
		if state == FITS:
			b.polygon(pts, Color(Cloth.cloth(p), GHOST_ALPHA))
			b.stroke(pts, GHOST_W * cell, Cloth.cloth_stitch(p), true)
		elif state == CROSSED:
			Cloth.dash_loop(b, pts, CROSS_W * cell * 0.7, GHOST_DASH * cell,
				GHOST_DASH * cell, Color(CROSS, 0.9))
		else:
			Cloth.dash_loop(b, pts, GHOST_W * cell,
				GHOST_DASH * cell, GHOST_DASH * cell, Pal.BAD)

## The running stitch along every seam: the board's signature. Each seam's
## dashes run out from the patch that made it, one cell of distance per
## STITCH_STEP, and take STITCH_TIME to cross their own edge. A seam whose
## moment has not come is not drawn at all, so the wave is the drawing and
## not a fade over it.
func _stitches(b, t: float) -> void:
	var cell := _cell()
	for s: Dictionary in _seams():
		var owner := int(s["owner"])
		var wait := (s["reach"] as Vector2).length() * _stitch_step()
		var u := clampf((t - float(s["at"]) - wait) / _stitch_time(), 0.0, 1.0)
		if u <= 0.0:
			continue
		var ink := Cloth.cloth_stitch(owner)
		if bool(s["hem"]) and _solved_at >= 0.0:
			# On the solve the hem warms all the way round, which is the one
			# moment the quilt is spoken of as a whole thing.
			var mid: Vector2 = ((s["a"] as Vector2) + (s["b"] as Vector2)) * 0.5
			var at := (mid - _origin()) / cell
			var lit := Motion.flash_level(t - _solved_at - Motion.SOLVE_DELAY
				- Motion.stagger(int(at.x + at.y), Motion.SOLVE_STAGGER), Motion.FLASH_IN, Motion.SOLVE_TIME)
			ink = ink.lerp(Pal.SUN_RAY, lit)
		Cloth.stitch(b, s["a"] as Vector2, s["b"] as Vector2, STITCH_W * cell,
			STITCH_ON * cell, STITCH_OFF * cell, ink, u)

## Nothing under reduce-motion: a seam is simply there the moment its two
## patches are.
func _stitch_step() -> float:
	return 0.0 if Motion.reduce else STITCH_STEP

func _stitch_time() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else STITCH_TIME

# --- the moments ---

## The chrome is the host's. The backing's entrance is one wide pop about its
## centre while it fades in (rule 7), and the rack's patches pop in behind
## it; both are read off the clock in _draw, so all this has to do is start
## it. _animating() knows how long it runs.
func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	_refresh()

# --- input ---

## A press, a drag and a release. A press finds the patch under the finger --
## one sewn on the quilt first, then one waiting on the rack -- and takes
## hold of it by the cell it was pressed on, so a patch dragged by its corner
## stays held by that corner.
func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts or not _peel.is_empty():
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_rest_at = _now()
			_grab(event.position)
		elif not _drag.is_empty():
			_release()
			accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _drag.is_empty():
		_drag["point"] = event.position
		if not _drag.has("go") and (event.position as Vector2).distance_to(_drag["press"]) > TAP_PX:
			# The finger has left the tap's circle: grow it now, not later.
			_drag["go"] = minf(_now(), float(_drag["since"]) + GROW_WAIT)
		_rest_at = _now()
		_refresh()
		accept_event()

func _grab(local: Vector2) -> void:
	# One hand at a time. A second press while a patch is held -- a second
	# finger on a phone, a second mouse button here -- used to overwrite
	# `_drag` outright, and the patch it dropped had already been taken off
	# the quilt by `take()`, which pushes no history because the matching
	# `drop()` is meant to. So the first patch was stranded in the rack with
	# no undo entry and no move counted, and only the second one was ever
	# resolved.
	if not _drag.is_empty():
		return
	var hit := _hit(local)
	if hit.is_empty():
		return
	var p := int(hit["patch"])
	if int(_state.at[p]) >= 0 and int(_state.locked[p]) == 1:
		# A hint's patch is a given: it is not the player's to move.
		_refused = {"patch": p, "at": _now()}
		_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)
		_speak(tr("QL_HINTED_FAST"), Face.Expr.WORRIED)
		_refresh()
		return
	var from := int(_state.at[p])
	if from >= 0 and _state.take(p) == State.STAYS:
		# Hard and Insane: a right patch stays for good. It shivers where it
		# lies, with no halo -- it is not wrong, it is simply staying.
		_refused = {"patch": p, "at": _now(), "halo": false}
		_busy_for(Motion.SHIVER_TIME)
		_speak(tr("QL_STAYS"), Face.Expr.HAPPY)
		fx.cue("wiggle")
		_refresh()
		accept_event()
		return
	# The cell it is picked up at: the quilt's, or the rack's smaller one, so
	# it grows from exactly the size it was lying at.
	var c0 := _cell() if from >= 0 else _rack_cell()
	_glide.erase(p)
	var landed_was := float(_landed.get(p, -100.0))
	if from >= 0:
		# Taken off the quilt (`take` above, which pushed no history): one
		# gesture is one undo, so the entry is pushed when the hand lets go
		# and knows where the patch ended up -- back on the quilt, or home.
		_lifted[p] = _now()
		_landed.erase(p)
	_drag = {"patch": p, "grab": hit["cell"], "point": local, "press": local, "from": from,
		"since": _now(), "c0": c0, "landed_was": landed_was}
	_refused = {}
	_flying.erase(p)
	_wiggle.erase(p)
	fx.cue("lift")
	_refresh()
	accept_event()

## What is under a local point: a patch sewn on the quilt, else one waiting
## on the rack. Returns {"patch": int, "cell": Vector2i (which of the
## patch's own cells)}.
func _hit(local: Vector2) -> Dictionary:
	var at := _cell_at(local)
	var p := _state.patch_at_cell(at.x, at.y)
	if p >= 0:
		var origin := int(_state.at[p])
		var corner := Vector2i(origin % _state.cols, origin / _state.cols)
		return {"patch": p, "cell": at - corner}
	var rc := _rack_cell()
	if rc <= 0.0:
		return {}
	for i in _state.shapes.size():
		if int(_state.at[i]) >= 0:
			continue
		var home := _bay_home(i)
		var rel := (local - home) / rc
		var cell := Vector2i(int(floor(rel.x)), int(floor(rel.y)))
		if (_state.shapes[i] as Array).has(cell):
			return {"patch": i, "cell": cell}
	return {}

## Whether the press now ending was a tap: let go within TAP_PX of where it
## went down and inside TAP_TIME.
func _was_tap() -> bool:
	return (_drag["point"] as Vector2).distance_to(_drag["press"]) <= TAP_PX \
		and _now() - float(_drag["since"]) <= TAP_TIME

## Let go. The endings, and telling them apart is the whole of whether this
## board feels fair:
##
## - **A tap.** Nothing is lifted: the patch wiggles where it lies and the
##   line says how it is moved (a rack patch), or how one is taken off (a
##   sewn one, on Easy and Medium, which goes straight back).
## - **Sewn on.** The drop fits (sticky snap: the ghost's spot). Dropped back
##   exactly where it was lifted from, nothing happened, so nothing is said
##   and nothing is counted. On Easy and Medium a drop that leaves the quilt
##   unfinishable is named: the dead end.
## - **Taken off.** The patch was let go **clear of the quilt** -- no cell
##   of it over the backing at all. That is not a refusal, it is *the*
##   gesture for taking a patch off, and the board must not scold a player
##   for doing the thing it told them to do. It goes home quietly, with the
##   count and no blush. A patch that came from the rack and went back to
##   the rack is the same ending with nothing to count.
## - **Refused.** The patch was let go **over the quilt** somewhere it will
##   not go. Only this one blushes, and the sprout names the rule. On a
##   judged board a spot already ruled for it is refused the same way, for
##   free, with the chalk's own line.
## - **Wrong** (Hard and Insane). It fits, but the answer has no patch of its
##   shape there: it lands, its stitch snaps and it flutters home, and a
##   heart goes (`_wrong_patch`).
func _release() -> void:
	var p := int(_drag["patch"])
	var from := int(_drag["from"])
	if _was_tap():
		_tapped(p, from)
		return
	var target := _target()
	var raw := _held_origin()
	# Both read before _drag is cleared: the hand's place, because a patch
	# that goes home flies from under the finger and not from wherever it
	# came, and whether it was over the quilt at all.
	var hand := _held_corner()
	var hold := _hold_state()
	_drag = {}
	if target >= 0:
		var code: int = _state.drop(p, target, from)
		match code:
			State.OK:
				_sewn(p, target, from, hand)
				return
			State.WRONG:
				_wrong_patch(p, target, hand)
				return
			State.RULED:
				_fly_home(p, hand)
				_refused = {"patch": p, "at": _now()}
				_busy_for(maxf(FLY_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
				fx.cue("ruled")
				_speak(tr("QL_RULED"), Face.Expr.WORRIED)
				_break_streak()
				_refresh()
				return
	_state.drop(p, -1, from)
	_fly_home(p, hand)
	_dead = {}
	if hold == CLEAR:
		# Taken off, not turned down.
		_busy_for(FLY_TIME)
		fx.cue("undo" if from >= 0 else "lift")
		if from >= 0:
			_break_streak()
			_speak_left()
	else:
		_refused = {"patch": p, "at": _now()}
		_busy_for(maxf(FLY_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
		fx.cue("refused")
		_speak(_reason(State.OFF if raw < 0 else _state.fits(p, raw)), Face.Expr.WORRIED)
		_break_streak()
	_refresh()
	if from >= 0:
		# It was on the quilt and is not any more, which is a move whichever
		# way the drop was judged.
		note_move()

## A tap on a patch: it goes back exactly as it was, wiggles where it lies,
## and the line says what to do with it. A sewn patch on Easy and Medium was
## taken off by the press, so it is put straight back with its seams whole.
func _tapped(p: int, from: int) -> void:
	var landed_was := float(_drag.get("landed_was", -100.0))
	_drag = {}
	_state.drop(p, from, from)
	if from >= 0:
		_landed[p] = landed_was
		_lifted.erase(p)
	_wiggle[p] = _now()
	_busy_for(WIGGLE_TIME)
	fx.cue("wiggle")
	_speak(tr("QL_TIP_OFF") if from >= 0 else tr("QL_TAP"), Face.Expr.HAPPY)
	_refresh()

## A patch sewn on at `origin`: it glides down out of the hand and sews its
## seams, the ghost finger retires, and on Easy and Medium the board asks
## whether what is left can still finish the quilt.
func _sewn(p: int, origin: int, from: int, hand: Vector2) -> void:
	_landed[p] = _now()
	_glide[p] = hand
	_lifted.erase(p)
	_dead = {}
	_coach_off = true
	_busy_for(LAND_TIME + maxf(SEW_TIME, _seam_span(p)))
	fx.cue("place")
	if from == origin:
		# Back where it came from. Nothing happened, so nothing is said
		# and nothing is counted.
		_refresh()
		return
	var stuck := not _state.judged() and not _state.is_solved() and not _state.finishable()
	if stuck:
		_dead_end()
	else:
		_speak_left()
		_on_good_drop(p)
	_refresh()
	# note_move() counts the move and ends the puzzle if that was the
	# last patch; the host raises the win screen after win_delay().
	note_move()

## Easy and Medium: the patches left can no longer cover the bare squares.
## The line says so, and every bare cell nothing left can reach pulses rose
## once the patch has landed. When every bare cell is reachable but no set of
## the patches covers them all, there is nothing to point at, so only the
## line.
func _dead_end() -> void:
	_stuck_ever = true
	_break_streak()
	var land := 0.0 if Motion.reduce else LAND_TIME * LAND_GLIDE
	var cells: PackedInt32Array = _state.dead_cells()
	if not cells.is_empty():
		_dead = {"cells": cells, "at": _now() + land}
		_busy_for(land + DEAD_BEAT * DEAD_PULSES)
	_speak(tr("QL_STUCK"), Face.Expr.WORRIED)
	fx.cue("stuck")

## The sprout's line for a refusal. A refusal is never a silence -- and it
## is only ever said about a patch let go *over* the quilt, since a patch
## let go clear of it was taken off rather than turned down.
func _reason(code: int) -> String:
	match code:
		State.OVER:
			return tr("QL_REFUSE_OVER")
		_:
			return tr("QL_REFUSE_OFF")

## Sends a patch home to its bay from the point `at`, which is where the
## hand let go of it, or where it was sitting on the quilt. `after` delays
## the start, which is what lets Reset send them home in a wave rather than
## all at once; `_frame_of` holds a flight at its start until its moment.
func _fly_home(p: int, at: Vector2, after := 0.0) -> void:
	_flying[p] = {
		"from": at, "to": _bay_home(p),
		"c0": _cell(), "c1": _rack_cell(), "at": _now() + after,
	}
	_lifted[p] = _now()
	_landed.erase(p)
	_glide.erase(p)

# --- the sprout's line ---

## How many of the quilt's patches are still to go on. On Scrap Basket the
## scraps are not counted: they are never going on.
func _left_line() -> String:
	var on := 0
	for p in _state.shapes.size():
		if int(_state.at[p]) >= 0:
			on += 1
	var left := maxi(0, _state.quilt_patches - on)
	if left <= 0:
		return tr("QL_WIN")
	return tr("QL_ONE_LEFT") if left == 1 else tr("QL_N_LEFT") % left

func _speak_left() -> void:
	if is_done():
		return
	_speak(_left_line(), Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

## A line that owns the card for SAY_HOLD seconds, after which the cycling
## tips resume (Sudoku's and Bridges').
func _speak(line: String, mood: int) -> void:
	_say(line, mood)
	_hold_until = _now() + SAY_HOLD
	if get_tree() == null:
		return
	get_tree().create_timer(SAY_HOLD).timeout.connect(_resume_tips)

func _resume_tips() -> void:
	if is_done() or out_of_hearts or _now() < _hold_until - 0.01:
		return
	_say(_tip(_tip_idx), Face.Expr.HAPPY)

func _tip(k: int) -> String:
	var tips := _tips()
	return tr(tips[k % tips.size()])

func _cycle_tip() -> void:
	if is_done() or out_of_hearts or _now() < _hold_until:
		return
	_tip_idx = (_tip_idx + 1) % _tips().size()
	_say(_tip(_tip_idx), Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules: this
## board answers a drop with a count, and a refusal with the rule.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

## Where every patch stands right now, as plain ints: the before half of
## `_settle`.
func _snapshot() -> Array:
	var out: Array = []
	for i in _state.shapes.size():
		out.append(int(_state.at[i]))
	return out

## One diff of where every patch was against where it is now, turned into
## the moments the drawing reads: a patch that arrived pops in and starts
## its seam wave, a patch that left flies home from exactly where it stood.
##
## **Every move that can shift more than one patch goes through here** -- a
## hint that displaces two, an undo that puts them back -- so no move can
## forget to animate a patch it moved, and none of them has to know which
## patches those were. Queens' and Sudoku's `_settle` diff derived state;
## this one diffs the pieces themselves, which is the plainest form of it.
func _settle(before: Array, t: float) -> void:
	for i in _state.shapes.size():
		var was := int(before[i])
		var now := int(_state.at[i])
		if was == now:
			continue
		if now >= 0:
			_landed[i] = t
			_glide.erase(i)
			_lifted.erase(i)
			_flying.erase(i)
		elif was >= 0:
			_fly_home(i, _corner_of(was))

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and _peel.is_empty() and _state.can_undo()

## Reverses the last gesture -- a patch sewn on, a patch taken off, or a
## hint with everything it displaced. Counts no move. Easy and Medium only:
## on Hard and Insane every patch on the quilt is right and stays, so the
## state has nothing to take back.
func undo() -> bool:
	if is_done() or out_of_hearts or not _peel.is_empty():
		return false
	var before := _snapshot()
	var back: Dictionary = _state.undo()
	if back.is_empty():
		return false
	var t := _now()
	_drag = {}
	_refused = {}
	_dead = {}
	_break_streak()
	_settle(before, t)
	_busy_for(maxf(Motion.POP_IN, FLY_TIME))
	_speak(tr("QL_TAKEN_BACK") + " " + _left_line(), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	check_solved()
	return true

## One more hint beyond the budget (a rewarded video's), kept here and in
## the state, which guards its own hint.
func add_hint() -> void:
	hints_extra += 1
	_state.hints_extra += 1

## The band's hints (3, 3, 1, 0) and any a video gave, less those spent:
## the state's own count, which its `hint()` guards on.
func hints_left() -> int:
	return _state.hints_left()

## Sews one patch of the answer where the board has not got it, taking up
## anything in its way first. The patch it sews is a given from then on: it
## keeps its sun glow and it will not be dragged off. Never a scrap.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or out_of_hearts or not _peel.is_empty():
		return false
	var before := _snapshot()
	var out: Dictionary = _state.hint()
	if out.is_empty():
		return false
	hints_used += 1
	var p := int(out["patch"])
	var t := _now()
	_dead = {}
	_coach_off = true
	# The hint's own patch and everything it took up on the way, off one
	# diff: the state says which patches it displaced, but the board never
	# has to read that list to draw them leaving.
	_settle(before, t)
	_fx_at(_origin() + _centroid(p) * _cell(), Pal.LEAF)
	_busy_for(maxf(Motion.RING_TIME, Motion.POP_IN + _seam_span(p)))
	fx.cue("hint")
	_speak(tr("QL_HINT") + " " + _left_line(), Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	# A hint can finish the quilt, and a board that ends on one still ends.
	check_solved()
	return true

## Every patch the player laid comes home in a wave from the far corner.
## What a hint gave stays given: it keeps its place, and the hints spent are
## not refunded. The hearts and the chalk marks stay as they are -- only Try
## again gives those back.
func reset_board() -> void:
	if out_of_hearts or not _peel.is_empty():
		return
	_wipe()
	_break_streak()
	_speak(tr("QL_CLEAN") + " " + _left_line(), Face.Expr.HAPPY)

## Reset's half that Try again shares: every patch the player laid carried
## home in a wave from the far corner, the state back to a bare backing
## (bar the hints' givens), every moment gone.
func _wipe() -> void:
	_gen += 1
	# Where each of them is, and how far it stands from the far corner, both
	# read before the state clears them.
	var was: Dictionary = {}
	for p in _state.shapes.size():
		var origin := int(_state.at[p])
		if origin < 0 or int(_state.locked[p]) == 1:
			continue
		var c: int = origin % _state.cols
		var r: int = origin / _state.cols
		was[p] = {"at": _corner_of(origin),
			"step": (_state.cols - 1 - c) + (_state.rows - 1 - r)}
	_drag = {}
	_flying = {}
	_refused = {}
	_pending = []
	_peel = {}
	_wiggle = {}
	_dead = {}
	_state.reset()
	for p in was:
		var e: Dictionary = was[p]
		_fly_home(int(p), e["at"], Motion.stagger(int(e["step"]), Motion.RESET_STAGGER))
	_solved_at = -1.0
	_busy_for(Motion.stagger(_state.cols + _state.rows - 2, Motion.RESET_STAGGER) + FLY_TIME)
	moves = 0
	_running = true
	_rest_at = _now()
	fx.cue("reset")
	_refresh()

## A completed daily is dealt again from its seed, so the fresh board comes up
## with an empty quilt mid-entrance. Sew every patch on at its answer origin
## with every clock in the past: the entrance over, each landing pop and seam
## wave long run (so every stitch is drawn whole), nothing held, flying or
## pending, and the rack left showing only the gone shapes -- and on Scrap
## Basket the three scraps, which the answer leaves in the basket. The
## hearts and the flawless mark come back from the record. Never
## check_solved(): the host owns the win for a restore.
func restore_completed_board() -> void:
	var t := _now()
	_gen += 1
	_tip_timer.stop()
	_drag = {}
	_flying = {}
	_lifted = {}
	_glide = {}
	_refused = {}
	_pending = []
	_anim_until = 0.0
	_solved_at = -1.0
	_opened = t - 10.0
	_deal()
	_coach_off = true
	for p in _state.shapes.size():
		_state.at[p] = int(_state.answer[p])
		_state.locked[p] = 0
		if int(_state.answer[p]) >= 0:
			_landed[p] = t - 10.0
	_state.history = []
	_state.recompute()
	var rec := completed_record
	_flawless = bool(rec.get("flawless", false))
	if rec.has("hearts") and max_hearts > 0:
		hearts = clampi(int(rec.hearts), 0, max_hearts)
	_tag_count = -1
	_say(tr("QL_WIN"), Face.Expr.JOY)
	_heart_layer.queue_redraw()
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

func share_glyphs() -> String:
	return _state.share_glyphs()

## Whether the solve was flawless, so a reopened daily keeps its seal, and
## how many hearts it kept.
func completion_record() -> Dictionary:
	return {"flawless": _flawless, "hearts": hearts}

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("QL_WIN")}

## Long enough for the hem's stitch to run all the way round the finished
## quilt. Under reduce-motion there is no wave, so the win follows the last
## patch (spec section 9's reduce-motion row).
func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

func _on_solved() -> void:
	_solved_at = _now()
	_drag = {}
	_dead = {}
	_tip_timer.stop()
	# Flawless: no hint, and no heart lost on a judged board, or on Easy and
	# Medium never a dead end. The seal is the rewards' to stamp.
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else not _stuck_ever)
	# Gold on each patch as the hop reaches it, and no ring: eight rings over
	# a finished quilt is a firework, where the hem's stitch is the point.
	for p in _state.shapes.size():
		var origin := int(_state.at[p])
		if origin < 0:
			continue
		var at := Vector2i(origin % _state.cols, origin / _state.cols)
		_fx_at(_origin() + _centroid(p) * _cell(), Pal.SUN,
			Motion.SOLVE_DELAY + Motion.stagger(at.x + at.y, Motion.SOLVE_STAGGER), false)
	_busy_for(Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME)
	_say(tr("QL_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

# --- rewards: the hooks (spec section 4 builds on these) ---

## A good drop: on Hard and Insane a right patch, on Easy and Medium one that
## leaves the quilt finishable. Called once the patch is in the state and
## before `note_move()`, so a drop that solves the quilt comes through here
## too (check `_state.is_solved()`). The streak, the gags and the row
## sparkle belong here.
func _on_good_drop(_p: int) -> void:
	pass

## The streak ends: a refusal, a chalked spot, a wrong patch, a dead end, a
## take-off, an undo, a reset, the hearts running out.
func _break_streak() -> void:
	pass

# --- failing ---

## A patch the answer has no place for there, on Hard or Insane (the state
## has already ruled the spot and left the patch in the rack): it lands like
## any other and its needle starts the quilting stitch, then the thread
## snaps, the stitch unravels backward, and it peels up by a corner and
## flutters home to its bay with a wobble. The heart splits at the snip.
## Under reduce motion all of it is at once: the patch is simply home.
func _wrong_patch(p: int, origin: int, hand: Vector2) -> void:
	if hearts <= 0 or is_done():
		return
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_dead = {}
	_split_index = hearts
	if hearts <= 0:
		out_of_hearts = true
		_running = false
	var scrap := int(_state.answer[p]) < 0
	var line := tr("QL_WRONG_SCRAP") if scrap else tr("QL_WRONG")
	fx.cue("place")
	if Motion.reduce:
		_split_at = _now()
		_lifted[p] = _now()
		fx.cue("heart_lost")
		_speak(line, Face.Expr.WORRIED)
		_heart_layer.queue_redraw()
		_after(0.25, func() -> void:
			fx.cue("ruled")
			moved.emit()
			if out_of_hearts:
				_run_out())
		_refresh()
		return
	_peel = {"patch": p, "origin": origin, "at": _now(), "hand": hand}
	_split_at = _now() + SNIP_AT
	_busy_for(_peel_span())
	_after(SNIP_AT, func() -> void:
		fx.cue("snip")
		fx.cue("heart_lost")
		var cell := _cell()
		var head := _corner_of(origin) + Vector2(_spans[p]) * cell * 0.5
		fx.puff(head, Cloth.cloth_thread(p), 4)
		_heart_layer.queue_redraw()
		_speak(line, Face.Expr.WORRIED))
	_after(SNIP_AT + UNRAVEL_TIME + PEEL_TIME * 0.5, fx.cue.bind("flutter"))
	_after(_peel_span(), func() -> void:
		_peel = {}
		_lifted[p] = _now()
		_wiggle[p] = _now()
		_busy_for(WIGGLE_TIME)
		fx.cue("ruled")
		moved.emit()
		_refresh()
		if out_of_hearts:
			_run_out())
	_refresh()

## The last heart is gone: the card slips to dusk, the line yawns, and the
## out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_break_streak()
	_tip_timer.stop()
	fx.cue("out_of_hearts")
	_say(tr("QL_OUT"), Face.Expr.SLEEPY)
	_dusk_toward(DUSK)
	_refresh()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

func _dusk_toward(tint: Color) -> void:
	Motion.stop(_dusk_tw)
	if Motion.reduce:
		modulate = tint
		return
	_dusk_tw = create_tween()
	_dusk_tw.tween_property(self, "modulate", tint, DUSK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## The card, over the whole screen: laid on the host so it covers the chrome,
## or on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["QL_OUT_BODY", "QL_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same quilt from a bare backing in Reset's wave, every heart
## back and the chalk marks gone, the day's light, the clock and the moves
## from zero; hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_wipe()
	_state.clear_ruled()
	_deal()
	elapsed = 0.0
	moves = 0
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_running = true
	_tip_idx = 0
	_hold_until = 0.0
	_say(_tip(0), Face.Expr.HAPPY)
	_tip_timer.start()
	moved.emit()
	_refresh()

## One more heart (the card's video): once a board. The light comes back.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	hearts = 1
	_back_index = 0
	_back_at = _now()
	_heart_layer.queue_redraw()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_resume_tips()
	_tip_timer.start()
	moved.emit()
	_refresh()

## Back from the card: the board ends unsolved first, so the host logs
## puzzle_complete {solved: false} and not an abandon.
func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

## Holds the host's hint video while a wrong patch is still on its way home.
func busy() -> bool:
	return not _peel.is_empty()

## Runs `what` after `delay`, unless the board has been rebuilt or wiped
## meanwhile.
func _after(delay: float, what: Callable) -> void:
	if get_tree() == null:
		return
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

# --- the ghost finger ---

## On Easy and Medium, until the first patch lands, a ghost finger drags the
## patch with the fewest legal spots from the rack to its answer place. Never
## on a judged board or under reduce motion.
func _pick_coach() -> void:
	_coach_patch = -1
	_coach_origin = -1
	_coach_off = false
	_rest_at = _opened + Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(maxi(_state.shapes.size() - 1, 0), Motion.ENTER_STAGGER)
	if _state.band >= 2 or Motion.reduce:
		return
	var fewest := 1 << 30
	for p in _state.shapes.size():
		if int(_state.answer[p]) < 0 or int(_state.at[p]) >= 0:
			continue
		var n: int = _state.legal_origins(p).size()
		if n < fewest:
			fewest = n
			_coach_patch = p
	if _coach_patch >= 0:
		_coach_origin = int(_state.answer[_coach_patch])

## Where the ghost finger is and how solid, at `t`: {} while it rests.
## {"at": the fingertip, "g": 0..1 of the way up, "alpha", "press"}.
func _coach_at(t: float) -> Dictionary:
	if _coach_patch < 0 or _coach_off or is_done() or not _drag.is_empty() \
			or int(_state.at[_coach_patch]) >= 0:
		return {}
	var e := t - _rest_at - COACH_AFTER
	if e < 0.0:
		return {}
	var u := fmod(e, COACH_DRAG + COACH_LOOP) / COACH_DRAG
	var first: Vector2i = (_state.shapes[_coach_patch] as Array)[0]
	var a := _bay_home(_coach_patch) + (Vector2(first) + Vector2(0.5, 0.5)) * _rack_cell()
	var b := _corner_of(_coach_origin) + (Vector2(first) + Vector2(0.5, 0.5 + HOLD_LIFT)) * _cell()
	var k := clampf(u, 0.0, 1.0)
	var fade := clampf(u * 5.0, 0.0, 1.0) * clampf((1.7 - u) * 3.0, 0.0, 1.0)
	var go := 1.0 - pow(1.0 - k, 3.0)
	return {"at": a.lerp(b, go), "g": go, "alpha": fade, "press": clampf(u * 8.0, 0.0, 1.0),
		"first": first}

## The ghost finger and the faint patch it carries: the patch grows from the
## rack's cell to the quilt's as it rises, held HOLD_LIFT above the tip as a
## real hand holds it, and once it is over its place the landing outline
## shows under it.
func _draw_coach(t: float, shown: Array) -> void:
	var c := _coach_at(t)
	if c.is_empty() or float(c.alpha) <= 0.01:
		return
	var p := _coach_patch
	var al: float = c.alpha
	var at: Vector2 = c.at
	var g: float = c.g
	var first: Vector2i = c.first
	var cell := lerpf(_rack_cell(), _cell(), g)
	var corner := at - (Vector2(first) + Vector2(0.5, 0.5 + HOLD_LIFT * g)) * cell
	var b := Face.Builder.new()
	if g > 0.98:
		for loop: PackedVector2Array in Cloth.loops(_state.patch_cells(p, _coach_origin)):
			b.stroke(Cloth.laid(loop, _origin(), _cell(), Vector2i.ZERO), GHOST_W * _cell(),
				Color(Cloth.cloth_stitch(p), al), true)
	Cloth.patch(b, _loops[p], corner, cell, _spans[p], Cloth.cloth(p), Cloth.cloth_deep(p),
		Vector2.ONE, COACH_ALPHA * al)
	var mesh := _mesh(b)
	if mesh != null:
		_life_layer.draw_mesh(mesh, null)
		shown.append(mesh)
	var s := _cell()
	# The fingertip: a soft shadow, a ring pressed into the cloth, the tip.
	_life_layer.draw_circle(at + Vector2(4.0, 8.0), s * 0.2, Color(Pal.TEXT, 0.16 * al))
	_life_layer.draw_arc(at, s * (0.26 + 0.06 * (1.0 - float(c.press))), 0.0, TAU, 32,
		Color(Pal.SURFACE, 0.7 * al), maxf(2.0, s * 0.03), true)
	_life_layer.draw_circle(at, s * 0.17, Color(Pal.SURFACE, 0.92 * al))
	_life_layer.draw_arc(at, s * 0.17, 0.0, TAU, 32, Color(Pal.LINE, al), maxf(2.0, s * 0.025), true)
	# A little hand: the finger's knuckle trailing down and right of the tip.
	var palm := at + Vector2(s * 0.22, s * 0.34)
	_life_layer.draw_line(at + Vector2(s * 0.04, s * 0.1), palm, Color(Pal.SURFACE, 0.92 * al), s * 0.2, true)
	_life_layer.draw_circle(palm + Vector2(s * 0.08, s * 0.12), s * 0.22, Color(Pal.SURFACE, 0.92 * al))
	_life_layer.draw_arc(palm + Vector2(s * 0.08, s * 0.12), s * 0.22, -PI * 0.9, PI * 0.6, 24,
		Color(Pal.LINE, al), maxf(2.0, s * 0.025), true)

# --- the layers: the hearts, and the life over the card ---

func _tick_layers(now: float) -> void:
	if _heart_layer == null:
		return
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1) \
			or now - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1:
		_heart_layer.queue_redraw()
	var alive := not _coach_at(now).is_empty()
	if alive or _life_alive:
		_life_layer.queue_redraw()
	_life_alive = alive

## The life over the card: today the ghost finger. The rewards (love hearts,
## the cat, the bunting, the seal) draw here too.
func _draw_life() -> void:
	if _cell() <= 0.0 or _state.shapes.is_empty():
		_life_shown = []
		return
	var shown: Array = []
	_draw_coach(_now(), shown)
	_life_shown = shown

## The hearts over the field as one mesh on a paper pill (Queens' and
## Bridges'): pink with a small face and a leaf, a faint ghost where one was,
## the lost one's halves falling apart, and one coming back popping in.
func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell() <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _hearts_y()
	var x0 := size.x * 0.5 - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts or (i == _split_index and now < _split_at):
			var r := HEART_R
			if i == _back_index and not Motion.reduce:
				r *= Motion.pop_in_scale(now - _back_at, HEART_BACK_TIME).x
			if r > 0.5:
				b.polygon(_heart(at, r, -1), Pal.FLOWER)
				b.polygon(_heart(at, r, 1), Pal.FLOWER_DEEP)
				_heart_face(b, at, r)
			continue
		b.polygon(_heart(at, HEART_R, 0), Color(Pal.FLOWER, 0.22))
		var u := (now - _split_at) / SPLIT_TIME
		if i == _split_index and u < 1.0 and not Motion.reduce:
			var fade := 1.0 - u * u
			for side in [-1, 1]:
				var turn: float = side * SPLIT_TURN * u
				var shift := Vector2(side * SPLIT_SPREAD * u, SPLIT_FALL * u * u)
				var pts := _heart(Vector2.ZERO, HEART_R, side)
				for n in pts.size():
					pts[n] = at + shift + pts[n].rotated(turn)
				b.polygon(pts, Color(Pal.FLOWER if side < 0 else Pal.FLOWER_DEEP, fade))
	_hearts_shown = b.mesh()
	var c := Vector2(size.x * 0.5, y)
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

## A heart's small face: two dots and a smile in ink, a shine at the top left,
## and a leaf on top.
static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

## A heart `s` half-wide about `at` (side 0), or its left (-1) or right (1)
## half, split along a zigzag crack so the two halves fit together
## (Binairo's; its notes say why the crack leaves the tip straight up).
static func _heart(at: Vector2, s: float, side: int) -> PackedVector2Array:
	const STEPS := 36
	var k := s / 16.0
	var off := Vector2(0.0, -2.5)
	var pts := PackedVector2Array()
	var from := 0.0 if side >= 0 else PI
	var to := TAU if side == 0 else from + PI
	var count := STEPS if side == 0 else STEPS / 2 + 1
	for i in count:
		var t := lerpf(from, to, float(i) / float(STEPS if side == 0 else STEPS / 2))
		var p := Vector2(16.0 * pow(sin(t), 3.0),
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)))
		pts.append(at + (p + off) * k)
	if side == 0:
		return pts
	var zig := [Vector2(0.0, 13.0), Vector2(1.5, 8.0), Vector2(-1.5, 3.0), Vector2(1.0, -2.0)]
	if side < 0:
		zig.reverse()
	for z: Vector2 in zig:
		pts.append(at + (z + off) * k)
	return pts

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
