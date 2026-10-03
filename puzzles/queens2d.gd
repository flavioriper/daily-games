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
## X pops in behind the flash. Lift her and the wave runs backward, the
## far cells first, so her reach draws back into where she stood. The crosses
## a queen lays are derived by the state and never stored, so undo and
## removal need no bookkeeping for them; a queen on a crossed cell is
## refused, so two queens can never conflict and the n-th queen is the win.
##
## How it is drawn. Only the bees are nodes (ui/faces/bee_face.gd), each
## in a slot of its own so the layout and the motion never fight (rule 2 of
## docs/art/flat-motion.md). Everything else is two meshes: the floor (the
## frame, the region-tinted cells, the grid, and the seams), made once a court
## about its centre so the entrance pop is a transform; and the ground (the
## finger's sink, the wave's washes, the blushes, the flowers, the bees'
## shadows and every X) over it, put together while something moves from
## shapes made once and copied natively into each cell's run of vertices
## (ui/flat/run_mesh.gd, since the checkup of 2026-10-02). Every drawn moment
## reads the flat boards' vocabulary as curves off core/motion.gd (rule 8);
## nothing here needed a new reader. Every move -- a tap, a sweep, an undo, a
## hint, a reset -- goes through one _settle that diffs a snapshot of the
## court against the state and hands each changed cell its moment, with one
## Callable saying when: a queen's wave, a sweep's path, Reset's far corner.
## Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md.
## Concept page: docs/brainstorm/concepts.html#queens.
##
## The polish (docs/superpowers/specs/2026-09-30-queens-polish-design.md):
## Hard and Insane judge every seat and can be failed (hearts, the wrong bee
## buzzing off, a cross left for good, dusk and the out-of-hearts card);
## Insane is Morning Mist, a court where misty patches take two queens;
## a patch that has its queens opens flowers; right seats build a streak and
## now and then a gag; and the win turns the court into a meadow, the bees
## dance, and the queens issue a royal decree.

const State = preload("res://puzzles/queens_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const BeeFace = preload("res://ui/faces/bee_face.gd")
const CrossMark = preload("res://ui/faces/cross_mark.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Seal = preload("res://ui/flat/seal.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"

# --- the court ---
## The card's inset round the court.
const PAD := 34.0
## The ink frame round the court and the seams between regions, in pixels;
## the faint grid between cells of one region, in cells. The mock's own.
const FRAME := 6.0
const FRAME_RADIUS := 16.0
const SEAM := 5.0
const GRID := 2.0
const GRID_ALPHA := 0.28
## Each cell's own shade, off its hash, within this much lighter or darker,
## so a region reads as laid by hand rather than poured.
const TONE := 0.035
## The lit top edge and the shaded foot every cell carries, in cells, and how
## far toward paper and ink they go.
const BEVEL := 0.07
const BEVEL_LIT := 0.3
const BEVEL_SHADE := 0.07
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
## How far a refused X shivers, in cells.
const SHIVER := 0.03

# --- this board's own motion: the wave ---
## One ring of the wave per Motion.WAVE_STEP: a cell a queen sees arrives its
## king-move distance in rings after her, and leaves in the reverse order.
## WAVE_STEP itself moved to core/motion.gd on 2026-09-20 when Sudoku became
## the second board to read it; this board keeps only the peak below, which
## genuinely differs from Sudoku's.
## The gold wash's peak alpha as the wave reaches a cell.
const WAVE_FLASH := 0.35
## A cross a queen laid, against the player's own at one: fainter and smaller,
## so the player's own notes stand out from what the queens derived.
const AUTO_ALPHA := 0.7
const AUTO_SCALE := 0.8
## The warm wash a seated queen's cell takes, so a claimed seat reads at a
## glance under her. A disc under her was tried first and she covered it.
const HALO_ALPHA := 0.42
## A stroke's note rises this much a cell, up to this many cells.
const STROKE_PITCH := 0.03
const STROKE_PITCH_CAP := 8
## On the win a light crosses the court along the diagonal once the Xs
## have gone: when it sets off, and its step a diagonal.
const WIN_GLINT_AT := 0.35
const WIN_GLINT_STEP := 0.035
## The light is paper-pale and not the wave's gold: gold over the blue and
## lilac regions mixed to grey on the first rendered frame.
const WIN_GLINT_ALPHA := 0.55
## How long a refused given queen strains before her face settles.
const STRAIN_TIME := 0.6
## The Xs clear away in a scatter on the win, as Nonogram's do.
## The Xs wait for the last queen's wave to land (far * Motion.WAVE_STEP plus
## the pop) before they clear, which Nonogram's 0.2 never had to.
const CLEAR_DELAY := 0.6
const CLEAR_SPREAD := 0.3
const CLEAR_TIME := 0.5
const CLEAR_SHRINK := 0.4
## The win screen waits for the solve wave to hop every queen and the
## Xs to clear before it shows.
const WIN_WAIT := 1.6

# --- the polish (docs/superpowers/specs/2026-09-30-queens-polish-design.md) ---
## The hearts over the court: One Line's, Light Up's, Tents', Shikaku's and
## Nonogram's pill.
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
## A wrong queen on Hard or Insane sits, goes WORRIED and blushes, and
## EJECT_AFTER later buzzes off: FLY_TIME up FLY_RISE cells, wiggling
## FLY_WIGGLE, while a cross drops in where she sat.
const EJECT_AFTER := 0.8
const FLY_TIME := 0.55
const FLY_RISE := 1.1
const FLY_WIGGLE := 0.18
## Out of hearts: the court slips to dusk and the card comes up after.
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## A cross a heart showed: the family's rose, deepened, so it reads as the
## board's word and not the player's note.
const SHOWN_INK := Color(0.72, 0.36, 0.4)
## The streak (Binairo's, Shikaku's, Tents', Light Up's, One Line's, Nonogram's).
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
const COMBO_FONT := 44
## Gags, three of every GAG_ODDS right seats by the seat's own hash.
const GAG_ODDS := 5
const GAGS := 3
const LOVE_HEARTS := 4
const LOVE_TIME := 1.3
const LOVE_RISE := 0.7
const LOVE_R := 0.14
## The drone: a little bee flies a loop round the queen.
const DRONE_SIZE := 0.42
const DRONE_TIME := 1.25
const DRONE_R := 0.62
const DRONE_BOB := 0.07
## The twirl: the queen spins a whole turn on a little hop.
const TWIRL_TIME := 0.55
const TWIRL_HOP := 0.16
## A patch with every queen it takes opens flowers on its free seats, in the
## top-right corner of each so the cross beside it still reads.
const BLOOMS := 2
const BLOOMS_MIST := 3
const BLOOM_R := 0.13
const BLOOM_AT := Vector2(0.27, -0.27)
const BLOOM_PETALS := 5
const BLOOM_TIME := 0.45
const BLOOM_FOLD := 0.2
const BLOOM_STAGGER := 0.07
## Morning Mist: a misty patch's cells go MIST_PALE of the way to paper, and
## two soft wisps a cell drift over them, MIST_DRIFT of a cell either way.
## Its crowns: a paper pill on the patch's first cell, one crown a queen it
## takes, gold once she sits.
const MIST_PALE := 0.25
const MIST_ALPHA := 0.55
const MIST_DRIFT := 0.07
const MIST_SPEED := 0.45
const MIST_IN := 1.2
const MIST_LIFT := 1.4
const PIP_H := 0.4
const PIP_CROWN := 0.15
## The party, after the solve wave: the court turns into a meadow (a flower
## on every free seat, along the diagonal), the bees dance, confetti twice,
## the mist lifts, and the queens issue a royal decree.
const PARTY_AT := 1.2
const PARTY_EXTRA := 1.6
const MEADOW_STEP := 0.04
const DANCE_BEATS := 4
const DANCE_BEAT := 0.22
const DANCE_TILT := 0.22
const DECREES := 12
## The seal: One Line's.
const STAMP_AT := 0.9
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22

## The ground's shapes (`_shape`), each made once about its own origin.
const SHAPE_SQUARE := 0
const SHAPE_DISC := 1
const SHAPE_CROSS := 2
const SHAPE_FLOWER := 3
## The ground's runs, in paint order: a cell's sink, its washes (the wave,
## the glint, the blush), its flowers (a patch's bloom and the party's), its
## halo and shadow, its leaving X and its X.
const PART_SINK := 0
const PART_WASH := 1
const PART_FLOWER := 2
const PART_BEE := 3
const PART_GONE := 4
const PART_CROSS := 5
## A fading X or wash keeps its colours in this many alpha steps.
const ALPHA_STEPS := 16
const WASH_STEPS := 32

const HINTS := State.HINTS
## How long a teaching line stands before the next, the family's own cycle.
const TIP_CYCLE := 10.0
## Translation keys (locale/ui.csv), read through tr() when said.
const TIPS := ["QN_TIP_ONE_EACH", "QN_TIP_SEES", "QN_TIP_TOUCH"]

## Back to camp from the out-of-hearts card: the host leaves the board.
signal leave

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
var _cross_in: Dictionary = {}  # cell -> at: its X pops in then
var _cross_out: Array = []      # [{"cell", "at", "alpha"}]: Xs shrinking out
var _wash: Dictionary = {}      # cell -> at: the wave reaches it then
var _glint: Dictionary = {}     # cell -> at: the win's light crosses it then
var _blush: Dictionary = {}     # cell -> at: Check pointed at it, or a refusal
var _shiver: Dictionary = {}    # cell -> at: a refused X
var _sunk: Dictionary = {}      # cell -> {"down", "up"}: the finger has it
var _floor: ArrayMesh          # the court's still floor, made once a layout
var _ground: ArrayMesh
var _ground_dirty := true
## The ground is one mesh put together from shapes made once (Queens'
## checkup, 2026-10-02): a full Insane court's ground was built in script on
## every frame anything moved, 9-13 ms a build.
var _rm := RunMesh.new(_shape)
## The cell size the ground's shapes and the floor were made at: a relayout
## (the win card's slide) draws them scaled rather than making them again.
var _ref := 0.0
var _floor_cell := 0.0
var _laid_n := -1
## The meshes the last _draw handed the canvas item. A canvas command holds a
## mesh by RID and not by reference; dropping the only reference to a mesh
## still on the item's command list leaves the renderer drawing a freed RID.
var _shown: Array = []

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
var _pressed: Control       # the bee under the finger, if one
var _dragged := false
var _lay := true            # the stroke lays Xs (true) or picks them up
var _swept: Dictionary = {}
var _pending: Array = []
var _last_paint := Vector2i(-1, -1)

var _opened := -1.0e9
## When the solve began; -INF while unsolved. Never a sign test: the clock
## is seconds since launch, and a restore stamps a moment before it.
var _solved_at := -INF
var _anim_until := 0.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

# --- the polish ---
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _asleep := false
var _ejecting := false
var _heart_card: Control
var _split_index := -1
var _split_at := -INF
var _back_index := -1
var _back_at := -INF
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _dusk_tw: Tween
## Cell -> true: a wrong queen, WORRIED, before she buzzes off.
var _bad: Dictionary = {}
var _flawless := false
var _streak := 0
var _combo_n := 0
var _combo_cell := Vector2i.ZERO
var _combo_at := -INF
var _combo_popped := false
var _combo_out_at := -INF
var _combo_layer: Control
var _combo_shown: ArrayMesh
## Patch -> {"at", "open"}: its flowers opening, or folding when not open.
var _bloom: Dictionary = {}
## Patch -> its flowers' cells, picked once a court.
var _bloom_cells: Dictionary = {}
## The party's meadow sets off then (INF until the win).
var _meadow_at := INF
## The mist's wisps, one mesh cut to the cell, drifting as a whole; when it
## rolled in and when it lifts.
var _mist_mesh: ArrayMesh
var _mist_in_at := -INF
var _mist_out_at := INF
## The life over the court: love hearts off a seat, and the seal.
var _life_layer: Control
var _life_shown: Array = []
var _life_alive := false
var _love: Array = []
var _love_mesh: ArrayMesh
var _stamp_at := INF
var _seal_mesh: ArrayMesh
var _drone: BeeFace
var _drone_tw: Tween
var _card := Rect2()

func puzzle_id() -> String: return "queens"
func title() -> String: return "Queens"

func rules() -> String:
	var out := tr("QN_RULES")
	if state.has_mist():
		out += "\n\n" + tr("QN_RULES_MIST")
	if max_hearts > 0:
		out += "\n\n" + (tr("QN_RULES_HEARTS_1") if max_hearts == 1 else tr("QN_RULES_HEARTS_N") % max_hearts)
	return out

## The lines the sprout cycles: a misty court leads with the mist's two, a
## judged one with the hearts'.
func _tips() -> Array:
	if state.has_mist():
		return ["QN_TIP_MIST", "QN_TIP_MIST_2", "QN_TIP_HEARTS"] + TIPS
	if max_hearts > 0:
		return ["QN_TIP_HEARTS"] + TIPS
	return TIPS

## The tutorial (the board checkup, 2026-10-02): one page a rule, each a
## little court played by the board itself (ui/hud/queens_tutorial_diagram.gd),
## with the hearts page on a judged band and Morning Mist's on Insane.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/queens_tutorial_diagram.gd")
	var hints: int = State.HINTS_BY_BAND[clampi(state.band, 0, 3)]
	var steps := [
		[Diagram.Lesson.SEAT, "HTP_QN_SEAT", tr("HTP_QN_SEAT_BODY")],
		[Diagram.Lesson.TOUCH, "HTP_QN_TOUCH", tr("HTP_QN_TOUCH_BODY")],
		[Diagram.Lesson.CROSS, "HTP_QN_CROSS", tr("HTP_QN_CROSS_BODY")],
		[Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_QN_HINT_BODY_ONE") if hints == 1 else tr("HTP_QN_HINT_BODY_N") % hints]]
	if max_hearts > 0:
		steps.append([Diagram.Lesson.HEARTS, "HTP_TN_HEARTS",
			tr("HTP_QN_HEARTS_BODY_1") if max_hearts == 1 else tr("HTP_QN_HEARTS_BODY_N") % max_hearts])
	if state.has_mist():
		steps.append([Diagram.Lesson.MIST, "QN_MIST_SEAL", tr("QN_RULES_MIST")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.hearts = maxi(1, max_hearts)
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

## What the phone does under each cue (docs/agents/haptics.md). `place` and
## `remove` are not mapped: a cross, a queen and every cell of a sweep share
## them. The hand's own tap knocks instead (`_tap_cycle`, `_tap_queen`): a
## tick for a cross laid and a queen lifted, a tap for a queen seated, a
## bump for the second queen of a misty patch; a sweep ticks once as it is
## let go (`_release`). The streak's confetti is the other milestone. A seen,
## pinned or shown cell refused (`locked`), the wave, the flowers (`bloom`
## opens on every seat), the wrong queen's `buzz_off`, the streak's pluck
## and the gags say nothing. The seal thuds as it lands (`_party`).
const HAPTICS := {
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"confetti": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"check_ok": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"check": Haptics.WARN,
	"heart_lost": Haptics.BAD,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_drone = BeeFace.new()
	_drone.name = "Drone"
	_drone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drone.z_index = 3
	_drone.visible = false
	add_child(_drone)
	_life_layer = _layer("Life", 2, _draw_life)
	_heart_layer = _layer("Hearts", 1, _draw_hearts)
	_combo_layer = _layer("Combo", 3, _draw_combo)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

## A full-rect layer over the court, drawn by `draw` (One Line's).
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
	_stop_all()
	state.setup(rng, difficulty, bank_step)
	max_hearts = State.HEARTS[state.band]
	_heart_used = false
	_lost_ever = false
	_deal()
	_pick_blooms()
	_mist_in_at = -INF
	_mist_out_at = INF
	brush = State.QUEEN
	_cross_in = {}
	_cross_out = []
	_wash = {}
	_glint = {}
	_blush = {}
	_shiver = {}
	_sunk = {}
	_clear_gesture()
	_solved_at = -INF
	_laid_n = -1
	_build_pieces()
	_layout()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

## The court as it is dealt, and as Try again deals it back: every heart, the
## day's light, nothing judged, blooming or partying.
func _deal() -> void:
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_ejecting = false
	_split_index = -1
	_back_index = -1
	_bad = {}
	_flawless = false
	_streak = 0
	_combo_n = 0
	_combo_out_at = -INF
	_love = []
	_bloom = {}
	_meadow_at = INF
	_stamp_at = INF
	_seal_mesh = null
	Motion.stop(_dusk_tw)
	Motion.stop(_drone_tw)
	modulate = Color.WHITE
	if _drone != null:
		_drone.visible = false
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

## Each patch's flower seats, picked once a court by the cells' own hash:
## the free cells of the patch in that order, BLOOMS of them (a misty patch
## BLOOMS_MIST). The queens' own cells are skipped when the flowers are drawn.
func _pick_blooms() -> void:
	_bloom_cells = {}
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var g := state.region_at(cell)
			if not _bloom_cells.has(g):
				_bloom_cells[g] = []
			(_bloom_cells[g] as Array).append(cell)
	for g in _bloom_cells:
		var cells: Array = _bloom_cells[g]
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _hash(a + Vector2i(5, 11)) < _hash(b + Vector2i(5, 11)))

# --- the cast ---

## Only the bees are nodes. The court and the Xs are drawn.
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
		if _solved_at > -INF or bee.expression == Face.Expr.STRAIN:
			continue
		if _asleep:
			_set_expr(bee, Face.Expr.SLEEPY)
		elif _bad.has(cell):
			_set_expr(bee, Face.Expr.WORRIED)
		else:
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
	var row := _heart_row()
	var tall := minf(size.y, court.y + 2.0 * PAD + row)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - court.x * 0.5, _card.position.y + row + (tall - row - court.y) * 0.5)
	for cell in _bees:
		_seat(_bees[cell], cell_to_local(cell.y, cell.x), _cell * BEE_SIZE)
	_drone.size = Vector2.ONE * _cell * DRONE_SIZE
	_drone.pivot_offset = _drone.size * 0.5
	_love_mesh = null
	_mist_mesh = null
	# A new court, or a new size mid-play, makes the floor and the shapes
	# again; the finished court sliding into the win card keeps them, scaled.
	if _laid_n != state.n or (not is_done() and _ref > 0.0 and absf(_cell / _ref - 1.0) > 0.01):
		_laid_n = state.n
		_floor = null
		_rm.reset()
	_refresh_faces()
	_redraw()
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		layer.queue_redraw()

## The strip the hearts take over the court, on a board that has them.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

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
	return minf((size.x - 2.0 * PAD) / state.n, (available - 2.0 * PAD - _heart_row()) / state.n)

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.n + 2.0 * PAD + _heart_row())

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
	var now := _now()
	# The mist drifts for as long as it hangs over the court.
	if now < _anim_until or (state.has_mist() and not Motion.reduce and now < _mist_out_at + MIST_LIFT):
		queue_redraw()
	if _cell <= 0.0:
		return
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1):
		_heart_layer.queue_redraw()
	if _combo_n >= COMBO_FROM and (now - _combo_at < Motion.POP_IN + 0.1 or _combo_out_at > -INF):
		_combo_layer.queue_redraw()
	# One more redraw once the life goes quiet, so its last frame is not left
	# standing.
	var alive := _tick_life(now)
	if alive or _life_alive:
		_life_layer.queue_redraw()
	_life_alive = alive

## Keeps the court redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Something on the court changed: rebuild it on the next draw.
func _redraw() -> void:
	_ground_dirty = true
	queue_redraw()
	# The misty patches' crowns ride the life layer, over the bees.
	if _life_layer != null and state.has_mist():
		_life_layer.queue_redraw()

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
	if _floor == null:
		_floor = _build_floor()
		_floor_cell = _cell
	if _ground_dirty or now < _anim_until:
		var out := _build_ground(now)
		_ground = out.mesh
		busy = out.busy
		_ground_dirty = false
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.ENTER_POP:
		busy = true
	var seen := Motion.appear_level(since)
	if seen > 0.0 and _floor != null:
		var grown := Motion.wide_pop_scale(since) * _cell / _floor_cell
		draw_mesh(_floor, null, Transform2D(0.0, Vector2(grown, grown), 0.0, _court_centre()),
			Color(1.0, 1.0, 1.0, seen))
		shown.append(_floor)
	if _ground != null:
		draw_mesh(_ground, null)
		shown.append(_ground)
	# Morning Mist: the wisps drift over the misty patches as one cached mesh
	# under a transform, rolling in after the court and lifting at the party.
	if state.has_mist():
		var mist := _mist_level(now)
		if mist > 0.0:
			if _mist_mesh == null:
				_mist_mesh = _build_mist()
			if _mist_mesh != null:
				var drift := 0.0 if Motion.reduce else sin(now * MIST_SPEED) * MIST_DRIFT * _cell
				var rise := 0.0 if Motion.reduce or now < _mist_out_at else (1.0 - mist) * _cell * 0.6
				draw_mesh(_mist_mesh, null, Transform2D(0.0, Vector2(drift, -rise)), Color(1.0, 1.0, 1.0, mist))
				shown.append(_mist_mesh)
	_shown = shown
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## The court, built about its centre once a layout: the ink frame (a filled
## round rect the cells lie flush on, so its rounded corners are ink and not
## parchment), a cell per region colour, the faint grid over them and the
## seams where two regions meet. The finger's sink is the ground's.
func _build_floor() -> ArrayMesh:
	var b := Face.Builder.new()
	var field: Vector2 = Vector2.ONE * (_cell * state.n)
	var origin: Vector2 = -field * 0.5
	b.fan(Face.Builder.round_rect(origin - Vector2.ONE * FRAME,
		field + Vector2.ONE * (2.0 * FRAME), FRAME_RADIUS), Pal.TEXT)
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var col: Color = Pal.REGION[state.region_at(cell) % Pal.REGION.size()]
			if state.is_misty(state.region_at(cell)):
				col = col.lerp(Pal.PAPER, MIST_PALE)
			if _hash(cell) > 0.5:
				col = col.lightened(TONE * 2.0 * (_hash(cell) - 0.5))
			else:
				col = col.darkened(TONE * 2.0 * (0.5 - _hash(cell)))
			var at: Vector2 = origin + Vector2(x, y) * _cell
			b.fan(_square(at, _cell), col)
			var lip := _cell * BEVEL
			b.fan(_rect(at, Vector2(_cell, lip)), col.lerp(Pal.PAPER, BEVEL_LIT))
			b.fan(_rect(at + Vector2(0.0, _cell - lip), Vector2(_cell, lip)), col.lerp(Pal.TEXT, BEVEL_SHADE))
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
	return b.mesh()

## A rectangle from its top-left corner.
static func _rect(at: Vector2, s: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(s.x, 0.0), at + s, at + Vector2(0.0, s.y)])

## A cell's square from its top-left corner.
static func _square(at: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(s, 0.0), at + Vector2.ONE * s, at + Vector2(0.0, s)])

## Everything on the court that comes and goes, as one mesh put together
## from shapes made once (`_rm`), each piece into its own cell's run: the
## finger's sink, the wave's and the win's flashes, the blushes, the flowers,
## the bees' halos and shadows, and the Xs, leaving or here. Busy while any
## of it is moving.
func _build_ground(now: float) -> Dictionary:
	if not _rm.laid():
		_lay_runs()
	_rm.begin()
	var busy := false
	var n2: int = state.n
	# The finger's sink: the cell shaded toward the ink while it is held.
	var gone: Array = []
	for cell in _sunk:
		busy = true
		var pr: Dictionary = _sunk[cell]
		var released := -1.0 if now < float(pr.up) else now - float(pr.up)
		if released >= Motion.RELEASE_TIME:
			gone.append(cell)
			continue
		var grown := Motion.press_scale(now - float(pr.down), released)
		var depth := clampf((1.0 - grown) / (1.0 - Motion.PRESS_SCALE), 0.0, 1.0)
		if depth > 0.0:
			_rm.open(PART_SINK, _ix(cell))
			_wash_put(cell, Pal.TEXT, SINK_SHADE * depth)
	for cell in gone:
		_sunk.erase(cell)
	# The wave: as it reaches a cell the cell flashes toward gold and back,
	# read off flash_level; a cell it has not reached yet keeps us drawing.
	# Then the win's glint, and the blush toward the family's rose and back.
	var washes: Dictionary = {}  # cell -> [[colour, alpha]...]
	for kind in 3:
		var d: Dictionary = [_wash, _glint, _blush][kind]
		var ink: Color = [Pal.QUEEN_WASH, Pal.SUN_TILE, Pal.BAD][kind]
		var top: float = [WAVE_FLASH, WIN_GLINT_ALPHA, BLUSH_ALPHA][kind]
		gone = []
		for cell in d:
			var e: float = now - float(d[cell])
			if e < 0.0:
				busy = true
				continue
			if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
				gone.append(cell)
				continue
			busy = true
			if not washes.has(cell):
				washes[cell] = []
			washes[cell].append([ink, top * Motion.flash_level(e)])
		for cell in gone:
			d.erase(cell)
	for y in n2:
		for x in n2:
			var cell := Vector2i(x, y)
			if washes.has(cell):
				_rm.open(PART_WASH, _ix(cell))
				for w: Array in washes[cell]:
					_wash_put(cell, w[0], w[1])
	# The flowers: a patch's when it has its queens, and the party's meadow.
	if _flowers(now):
		busy = true
	# The bees' halos and shadows, anchored at the cell and read off each
	# bee's own scale and alpha, so one arrives with the pop and stays put
	# when she hops.
	for y in n2:
		for x in n2:
			var cell := Vector2i(x, y)
			var bee: BeeFace = _bees.get(cell)
			if bee == null or not bee.visible:
				continue
			var seen := clampf(bee.scale.y, 0.0, 1.0) * clampf(bee.modulate.a, 0.0, 1.0)
			if seen <= 0.0:
				continue
			_rm.open(PART_BEE, _ix(cell))
			_wash_put(cell, Pal.QUEEN_WASH, HALO_ALPHA * seen)
			seen = ceilf(seen * WASH_STEPS) / WASH_STEPS
			_rm.put(SHAPE_DISC, [Color(Pal.TEXT, SHADOW_ALPHA * seen)],
				Transform2D(0.0, Vector2(seen, seen) * _cell / _ref, 0.0, cell_to_local(cell.y, cell.x) + BEE_SHADOW_AT * _cell))
	# Xs on their way out, drawn from the shape the state has forgotten.
	var still: Array = []
	var leaving: Dictionary = {}  # cell -> [entries]
	for out in _cross_out:
		var e: float = now - float(out.at)
		var shrunk := Motion.pop_out_scale(e)
		if shrunk <= 0.0:
			continue
		still.append(out)
		busy = true
		if not leaving.has(out.cell):
			leaving[out.cell] = []
		leaving[out.cell].append([out, e, shrunk])
	_cross_out = still
	for y in n2:
		for x in n2:
			var cell := Vector2i(x, y)
			if not leaving.has(cell):
				continue
			_rm.open(PART_GONE, _ix(cell))
			for l: Array in leaving[cell]:
				var out: Dictionary = l[0]
				var shrunk: float = l[2]
				var turn := PI * 0.5 * clampf(float(l[1]) / Motion.POP_OUT, 0.0, 1.0)
				if float(out.alpha) < 1.0:
					shrunk *= AUTO_SCALE
				_put_cross(cell_to_local(cell.y, cell.x), Vector2.ONE * shrunk, float(out.alpha),
					turn, _ink(float(out.alpha) < 1.0))
	# The Xs that are here: waiting for the wave, popping in with the
	# squash, standing, shivering when refused, or clearing away on the win.
	gone = []
	var shook_gone: Array = []
	for y in n2:
		for x in n2:
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
			if _sunk.has(cell):
				grow *= _sink(cell, now)
			var alpha := AUTO_ALPHA if mark == State.AUTO else 1.0
			if mark == State.AUTO:
				grow *= AUTO_SCALE
			if _solved_at > -INF:
				var cleared := _dec((now - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD) / CLEAR_TIME)
				if cleared >= 1.0:
					continue
				busy = true
				alpha *= 1.0 - cleared
				grow *= 1.0 - cleared * CLEAR_SHRINK
			if grow.x <= 0.0 or grow.y <= 0.0:
				continue
			var at := cell_to_local(cell.y, cell.x)
			if _shiver.has(cell):
				var shook: float = now - float(_shiver[cell])
				if shook < Motion.SHIVER_TIME:
					busy = true
					at.x += Motion.shiver_offset(shook, _cell * SHIVER)
				else:
					shook_gone.append(cell)
			var ink := SHOWN_INK if state.shown.has(cell) else _ink(mark == State.AUTO)
			_rm.open(PART_CROSS, _ix(cell))
			_put_cross(at, grow, alpha, 0.0, ink)
	for cell in gone:
		_cross_in.erase(cell)
	for cell in shook_gone:
		_shiver.erase(cell)
	return {"mesh": _rm.mesh(), "busy": busy}

## Every cell's runs, in the order `_build_ground` visits them, each as long
## as the piece's largest look: a sink, three washes, two flowers, a halo and
## a shadow, a leaving X and an X (each with its drop).
func _lay_runs() -> void:
	_rm.reset()
	_ref = _cell
	var cells: int = state.n * state.n
	var sq := _rm.size_of(SHAPE_SQUARE)
	var x2 := 2 * _rm.size_of(SHAPE_CROSS)
	var sizes := {PART_SINK: sq, PART_WASH: 3 * sq, PART_FLOWER: 2 * _rm.size_of(SHAPE_FLOWER),
		PART_BEE: sq + _rm.size_of(SHAPE_DISC), PART_GONE: x2, PART_CROSS: x2}
	for part in [PART_SINK, PART_WASH, PART_FLOWER, PART_BEE, PART_GONE, PART_CROSS]:
		for k in cells:
			_rm.room(part, k, sizes[part])

## A cell's run index.
func _ix(cell: Vector2i) -> int:
	return cell.y * state.n + cell.x

## Shape `id` about its own origin, in slot colours (`RunMesh.slot`), at the
## cell size of this layout.
func _shape(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	match id:
		SHAPE_SQUARE:
			b.fan(_square(Vector2.ZERO, _ref), RunMesh.slot(0))
		SHAPE_DISC:
			Scenery.soft_disc(b, Vector2.ZERO, BEE_SHADOW_RX * _ref, BEE_SHADOW_RY * _ref, RunMesh.slot(0))
		SHAPE_CROSS:
			CrossMark._x(b, Transform2D.IDENTITY, _ref, CrossMark.WIDTH * _ref, RunMesh.slot(0))
		SHAPE_FLOWER:
			_flower(b, Vector2.ZERO, _ref * BLOOM_R, 0.0, RunMesh.slot(1))
	return b

## A wash of `ink` at `alpha` over the whole of `cell`, into the open run.
func _wash_put(cell: Vector2i, ink: Color, alpha: float) -> void:
	alpha = ceilf(alpha * WASH_STEPS) / WASH_STEPS
	if alpha <= 0.0:
		return
	var k := _cell / _ref
	_rm.put(SHAPE_SQUARE, [Color(ink, alpha)], Transform2D(0.0, Vector2(k, k), 0.0, _grid + Vector2(cell) * _cell))

## CrossMark's X and its drop about `at`, scaled `grow`, turned `angle`, at
## `alpha` (in ALPHA_STEPS, so a fading one keeps its colours), in `ink`.
func _put_cross(at: Vector2, grow: Vector2, alpha: float, angle: float, ink: Color) -> void:
	if grow.x <= 0.0 or grow.y <= 0.0 or alpha <= 0.0:
		return
	alpha = ceilf(alpha * ALPHA_STEPS) / ALPHA_STEPS
	var drop := CrossMark.DROP * _cell * grow.y
	grow *= _cell / _ref
	_rm.put(SHAPE_CROSS, [Color(Pal.TEXT, CrossMark.SHADOW_ALPHA * alpha)],
		Transform2D(angle, grow, 0.0, at + Vector2(0.0, drop)))
	_rm.put(SHAPE_CROSS, [Color(ink, alpha)], Transform2D(angle, grow, 0.0, at))

## press_scale for the cell under the finger, one when it is not.
func _sink(cell: Vector2i, now: float) -> float:
	if not _sunk.has(cell):
		return 1.0
	var pr: Dictionary = _sunk[cell]
	var released := -1.0 if now < float(pr.up) else now - float(pr.up)
	return Motion.press_scale(now - float(pr.down), released)

## The flowers on the court: each patch's BLOOMS in the corners of its free
## seats while it has its queens, opening with a twist and folding when it
## loses one; and on the win a flower on every free seat, along the diagonal.
## True while any is moving.
func _flowers(now: float) -> bool:
	var busy := false
	var at_cell: Dictionary = {}  # cell -> [[at, r, turn, petal]...]
	for g in _bloom:
		var d: Dictionary = _bloom[g]
		var e: float = now - float(d.at)
		var k := 0.0
		if bool(d.open):
			if Motion.reduce or e >= BLOOM_TIME + BLOOM_STAGGER * BLOOMS_MIST:
				k = 1.0
			else:
				busy = true
				k = 0.5
		elif not Motion.reduce and e < BLOOM_FOLD:
			busy = true
			k = 1.0 - clampf(e / BLOOM_FOLD, 0.0, 1.0)
		if k <= 0.0:
			continue
		var want := BLOOMS_MIST if state.is_misty(g) else BLOOMS
		var i := 0
		for cell: Vector2i in _bloom_cells.get(g, []):
			if i >= want:
				break
			if state.queens.has(cell):
				continue
			var kk := k
			if bool(d.open) and k < 1.0:
				var u := (e - i * BLOOM_STAGGER) / BLOOM_TIME
				kk = 0.0 if u <= 0.0 else Motion.back_out(minf(u, 1.0))
			i += 1
			if kk <= 0.01:
				continue
			if not at_cell.has(cell):
				at_cell[cell] = []
			at_cell[cell].append([cell_to_local(cell.y, cell.x) + BLOOM_AT * _cell, _cell * BLOOM_R * kk,
				(1.0 - minf(kk, 1.0)) * 1.2 + _hash(cell) * TAU, Pal.SURFACE])
	if now >= _meadow_at:
		for y in state.n:
			for x in state.n:
				var cell := Vector2i(x, y)
				if state.queens.has(cell):
					continue
				var e: float = now - _meadow_at - (0.0 if Motion.reduce else (x + y) * MEADOW_STEP)
				if e <= 0.0:
					busy = true
					continue
				var kk := 1.0 if Motion.reduce or e >= BLOOM_TIME else Motion.back_out(e / BLOOM_TIME)
				if kk < 1.0:
					busy = true
				var h := _hash(cell + Vector2i(3, 9))
				var petal: Color = [Pal.SURFACE, Pal.FLOWER, Pal.SUN_TILE, Pal.SURFACE][int(h * 4.0) % 4]
				var at := cell_to_local(y, x) + Vector2(h - 0.5, _hash(cell + Vector2i(7, 1)) - 0.5) * _cell * 0.3
				if not at_cell.has(cell):
					at_cell[cell] = []
				at_cell[cell].append([at, _cell * BLOOM_R * 1.4 * kk, h * TAU + (1.0 - kk) * 1.2, petal])
	if at_cell.is_empty():
		return busy
	var base := _ref * BLOOM_R
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			if not at_cell.has(cell):
				continue
			_rm.open(PART_FLOWER, _ix(cell))
			for f: Array in at_cell[cell]:
				var r: float = f[1]
				if r <= 0.5:
					continue
				var k := r / base
				_rm.put(SHAPE_FLOWER, [Pal.PETAL_EDGE, f[3], Pal.SUN],
					Transform2D(float(f[2]), Vector2(k, k), 0.0, f[0]))
	return busy

## One flower of radius `r` about `at`, turned `turn`: BLOOM_PETALS petals
## rimmed in the daisies' edge, and a sun-gold heart. Made once as a shape,
## in slots: the rim 0, `petal` 1, the heart 2.
func _flower(b: Face.Builder, at: Vector2, r: float, turn: float, petal: Color) -> void:
	for p in BLOOM_PETALS:
		var a := turn + TAU * p / BLOOM_PETALS
		var dir := Vector2.from_angle(a)
		b.fan(_oval(at + dir * r * 0.55, r * 0.52, r * 0.3, a), RunMesh.slot(0))
		b.fan(_oval(at + dir * r * 0.55, r * 0.45, r * 0.23, a), petal)
	b.fan(Face.Builder.ring(at, r * 0.32, r * 0.32), RunMesh.slot(2))

static func _oval(at: Vector2, rx: float, ry: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts

## A misty patch's crowns: a paper pill tucked in its first cell's top-left
## corner, over the bees (the life layer draws it), one crown for each queen
## it takes, gold once she sits and faint until then. They go with the win.
func _pips(b: Face.Builder) -> void:
	if not state.has_mist() or _solved_at > -INF:
		return
	for g in state.mist:
		var first := Vector2i(-1, -1)
		for y in state.n:
			for x in state.n:
				if first.x < 0 and state.region_at(Vector2i(x, y)) == g:
					first = Vector2i(x, y)
		if first.x < 0:
			continue
		var q := state.quota_of(g)
		var seated := state.queens_in(g)
		var h := _cell * PIP_H
		var w := h * (0.4 + 0.75 * q)
		var centre := _grid + Vector2(first) * _cell + Vector2(w, h) * 0.5 + Vector2.ONE * _cell * 0.05
		var corner := centre - Vector2(w, h) * 0.5
		b.fan(Face.Builder.round_rect(corner - Vector2.ONE * 2.0, Vector2(w, h) + Vector2.ONE * 4.0, h * 0.5 + 2.0), Pal.LINE)
		b.fan(Face.Builder.round_rect(corner, Vector2(w, h), h * 0.5), Pal.SURFACE)
		for i in q:
			var at := centre + Vector2((i - (q - 1) * 0.5) * h * 0.75, h * 0.08)
			var crown := _crown(at, _cell * PIP_CROWN)
			if i < seated:
				b.fan(_crown(at, _cell * PIP_CROWN * 1.25), Pal.OUTLINE)
				b.fan(crown, Pal.SUN)
			else:
				b.fan(crown, Color(Pal.LINE, 0.7))

## A little crown `r` half-wide about `at`: a band and three points.
static func _crown(at: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		at + Vector2(-r, r * 0.6), at + Vector2(-r, -r * 0.5), at + Vector2(-r * 0.45, 0.0),
		at + Vector2(0.0, -r * 0.8), at + Vector2(r * 0.45, 0.0), at + Vector2(r, -r * 0.5),
		at + Vector2(r, r * 0.6)])

## The mist's wisps: two soft white ovals a misty cell, each shifted and
## sized by the cell's own hash, cut once to the cell.
func _build_mist() -> ArrayMesh:
	var b := Face.Builder.new()
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			if not state.is_misty(state.region_at(cell)):
				continue
			for k in 2:
				var h := _hash(cell + Vector2i(k * 13 + 1, 17))
				var h2 := _hash(cell + Vector2i(29, k * 7 + 3))
				var at := cell_to_local(y, x) + Vector2(h - 0.5, h2 - 0.5) * _cell * 0.3
				Scenery.soft_disc(b, at, _cell * (0.5 + 0.2 * h2), _cell * (0.26 + 0.1 * h),
					Color(Pal.SURFACE, MIST_ALPHA))
	if b.verts.is_empty():
		return null
	return b.mesh()

## How much of the mist hangs over the court: rolling in after the court's
## entrance, lifting from the party on.
func _mist_level(now: float) -> float:
	if Motion.reduce:
		return 0.0 if now >= _mist_out_at else 1.0
	var into := clampf((now - _mist_in_at) / MIST_IN, 0.0, 1.0)
	var out := 1.0 - clampf((now - _mist_out_at) / MIST_LIFT, 0.0, 1.0)
	return into * out

## The player's own X is bark; one a queen laid is the dimmer ink, so what the
## player noted stands out from what the queens derived.
static func _ink(auto: bool) -> Color:
	return Pal.TEXT_DIM if auto else Pal.BARK

static func _crossed(mark: int) -> bool:
	return mark == State.CROSS or mark == State.AUTO

# --- the moments ---

## The chrome is the host's; here the court pops in wide after the family's
## delay. Nothing stands on it yet.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP)
	fx.cue("enter")
	# Morning Mist rolls in over the court once it has popped in.
	if state.has_mist():
		var lead := Motion.ENTER_DELAY + Motion.ENTER_POP * 0.5
		_mist_in_at = _opened + lead
		_after(lead, fx.cue.bind("mist"))

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
## shrinks out, an X pops in or shrinks out -- `delay_of.call(cell,
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
## draws back after her, rather than her hanging on while her far Xs go
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

## A X leaves `cell` at `at`, at the ink it had. Under reduce-motion it
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

## A queen refused on `cell`, which a queen already sees: the X there
## shivers and the cell blushes, and the sprout says why.
func _refuse_seen(cell: Vector2i) -> void:
	_say(tr("QN_SEEN"), Face.Expr.WORRIED)
	fx.cue("locked")
	if Motion.reduce:
		return
	_shiver[cell] = _now()
	_blush_cell(cell)
	_busy_for(Motion.SHIVER_TIME)
	# The queen who sees it answers too, so the refusal says whose reach the
	# cell is in rather than only that it is taken.
	for q in state.queens:
		if (state.reach_of(q) as Array).has(cell) and _bees.has(q):
			_wobble(_bees[q])

## A lift refused on a given queen: she shivers and strains for a beat while
## her cell blushes, and the sprout says why.
func _refuse_pinned(cell: Vector2i) -> void:
	_say(tr("QN_PINNED"), Face.Expr.WORRIED)
	fx.cue("locked")
	_blush_cell(cell)
	var bee: BeeFace = _bees.get(cell)
	if bee == null or Motion.reduce:
		return
	_set_expr(bee, Face.Expr.STRAIN)
	_after(STRAIN_TIME, func() -> void:
		if bee.expression == Face.Expr.STRAIN and _solved_at == -INF:
			bee.expression = Face.Expr.HAPPY)
	Motion.stop(_pos_tw.get(bee))
	bee.position = Vector2.ZERO
	bee.modulate.a = 1.0
	_pos_tw[bee] = Motion.shiver(bee, _cell * SHIVER)
	_busy_for(Motion.SHIVER_TIME)

# --- input ---

## A tap cycles a cell blank -> player cross -> queen -> blank. A drag that
## starts on one of the player's own Xs picks Xs up along its path;
## any other drag lays them. Either way the court answers under the finger.
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
	if is_done() or cell.x < 0 or out_of_hearts or _ejecting:
		return
	_press_cell = cell
	var mark := state.mark_at(cell)
	# A bee under the finger sinks whichever mark is already there. The actual
	# tap transition happens on release, so a short press can become a drag.
	if mark == State.QUEEN and _bees.has(cell):
		_pressed = _bees[cell]
		Motion.stop(_look_tw.get(_pressed))
		# A twirl or a dance stopped halfway would leave her crooked.
		_pressed.rotation = 0.0
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
## finger leaves no holes. A stroke that starts on one of the player's own
## Xs picks Xs up; any other stroke lays them.
func _drag(at: Vector2) -> void:
	var cell := _cell_at(at)
	if cell.x < 0 or cell == _last_paint:
		return
	# Delay painting until movement proves this is a drag, but once it is,
	# include the cell where the finger first went down in the stroke, and
	# let that cell say what the stroke does.
	if not _dragged:
		_dragged = true
		_lay = state.mark_at(_press_cell) != State.CROSS
	if _last_paint.x < 0:
		_paint(_press_cell)
	if _last_paint.x >= 0:
		var steps := maxi(absi(cell.x - _last_paint.x), absi(cell.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(roundi(lerpf(_last_paint.x, cell.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, cell.y, float(i) / steps))))
	_paint(cell)
	_redraw()

## A stroke paints a cell once, and at once: a laying stroke drops an X on
## a bare cell as the finger reaches it, a lifting stroke takes the player's
## X off. A queen, and a cross a queen laid, are left alone. The whole
## stroke is still one move (State.sweep_step folds it into one entry).
func _paint(cell: Vector2i) -> void:
	if not state.in_field(cell):
		return
	_last_paint = cell
	if _swept.has(cell):
		return
	_swept[cell] = true
	var mark := state.mark_at(cell)
	if mark != (State.BLANK if _lay else State.CROSS):
		return
	var before := _snapshot()
	if not state.sweep_step(cell, _lay, _pending.is_empty()):
		return
	_pending.append(cell)
	var now := _now()
	if _lay:
		_sink_cell(cell)
		_settle(before, now, _at_once())
		# The cell springs back as its X lands, and not when the finger
		# lets go: the finger has already moved on.
		_sunk[cell].up = now + Motion.PRESS_TIME
	else:
		_settle(before, now, _at_once())
		if not Motion.reduce:
			fx.puff(cell_to_local(cell.y, cell.x), Pal.WOOD, 3)
	# The stroke's note climbs as it grows, as Word Trail's trace does.
	fx.cue("place" if _lay else "remove", 1.0 + STROKE_PITCH * mini(_pending.size() - 1, STROKE_PITCH_CAP))

func _release(at_cell: Vector2i) -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var pending := _pending
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	if cell.x < 0 or is_done():
		_redraw()
		return
	# A tap is the only gesture that advances the cell through its three
	# states. A finger that wandered off is a drag, even if it painted nothing.
	if at_cell == cell and not was_drag:
		_tap_cycle(cell, now)
		_redraw()
		return
	# A stroke already laid or lifted its Xs as the finger went; all that
	# is left is to count it, once, however many cells it crossed.
	if not pending.is_empty():
		fx.buzz(Haptics.TICK)
		_speak()
		note_move()
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
		if not Motion.reduce:
			fx.puff(cell_to_local(cell.y, cell.x), Pal.QUEEN_WASH, 4)
		fx.cue("remove")
		fx.buzz(Haptics.TICK)
		_break_streak()
		_update_blooms()
		_speak()
		note_move()
		return
	var seated: Dictionary = state.seat(cell)
	if not seated.ok:
		if int(seated.why) == State.SEEN:
			_refuse_seen(cell)
			_break_streak()
		elif int(seated.why) == State.SHOWN:
			_refuse_shown(cell)
		return
	_settle(before, now, _wave_from(cell), false, state.reach_of(cell))
	var at := cell_to_local(cell.y, cell.x)
	fx.ring(at, _cell * RING_R, Pal.SUN)
	fx.puff(at, Pal.SUN)
	fx.cue("place")
	fx.buzz(Haptics.TAP)
	# On Hard and Insane every seat is judged as she lands: a wrong one costs
	# a heart and buzzes off.
	if state.judged() and not state.right_seat(cell):
		note_move()
		_wrong_seat(cell, now + (0.0 if Motion.reduce else Motion.POP_IN * 0.6))
		return
	_update_blooms(0.0 if Motion.reduce else Motion.POP_IN)
	var g := state.region_at(cell)
	if state.is_misty(g) and not state.patch_full(g):
		_say(tr("QN_MIST_HALF"), Face.Expr.HAPPY)
	else:
		_speak()
		# A misty patch given its second queen is the milestone.
		if state.is_misty(g):
			fx.buzz(Haptics.BUMP)
	note_move()
	_on_right_seat(cell, 0.0 if Motion.reduce else Motion.POP_IN * 0.5)

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
		fx.buzz(Haptics.TICK)
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
		_say(tr(_tips()[_tip_idx % _tips().size()]), Face.Expr.HAPPY)
		return
	var seated: int = state.queens.size()
	var left := state.queens_left()
	if seated == 0:
		_say(tr("QN_TO_SEAT") % left, Face.Expr.HAPPY)
		return
	_say((tr("QN_SEATED_ONE") if seated == 1 else tr("QN_SEATED_N")) % [seated, left],
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
	_tip_idx = (_tip_idx + 1) % _tips().size()
	_say(tr(_tips()[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and not _ejecting and not state.history.is_empty()

## The host holds its hint video while a wrong queen is being seen off.
func busy() -> bool:
	return _ejecting

## Takes back the last gesture: a queen's seat or lift runs her wave the other
## way, a sweep comes back along its path. Counts no move.
func undo() -> bool:
	if is_done() or out_of_hearts or _ejecting or state.history.is_empty():
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
		var wash: Array = state.reach_of(origin) if state.queens.has(origin) else []
		_settle(before, now, _wave_from(origin), false, wash)
	else:
		_settle(before, now, _along(cells))
	_break_streak()
	_update_blooms()
	_speak()
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

## Zero on an unproved court (state.ok false): the answer the generator
## stored there is only one of several seatings, so it cannot be handed out
## as a hint, and the button stays disabled.
func hints_left() -> int:
	return 0 if not state.ok else State.HINTS_BY_BAND[state.band] + hints_extra - hints_used

## Seats the answer's queen in the first row that lacks her and pins her: a
## wrong queen in her way pops out first, a ring pulses out of the cell, the
## bee drops in from above, sparkles rise, and her wave runs. Counts no
## move but can finish the puzzle.
func hint() -> bool:
	if is_done() or out_of_hearts or _ejecting or hints_left() <= 0:
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
	# wave lays their cells' Xs like any other.
	for q in out.lifted:
		_bee_down(q, 0.0)
		before[q] = State.BLANK
	_settle(before, now, _wave_from(target), true, state.reach_of(target))
	_update_blooms(0.0 if Motion.reduce else Motion.DROP_TIME)
	var at := cell_to_local(target.y, target.x)
	fx.ring(at, _cell * RING_R, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_say(tr("QN_HINT") if (out.lifted as Array).is_empty() else tr("QN_HINT_MOVED"),
		Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every queen the answer does not seat there wobbles and her cell blushes,
## and the sprout says how many. Crosses are left alone: a cross is a note,
## not a claim.
func check() -> int:
	if is_done() or out_of_hearts or _ejecting:
		return 0
	checks += 1
	# On Hard and Insane no wrong queen ever stays, so Check looks at the
	# crosses instead: one on a seat the answer wants shivers and blushes.
	if state.judged():
		return _check_crosses()
	var wrong: Array = state.wrong_queens()
	for cell in wrong:
		if _bees.has(cell):
			_wobble(_bees[cell])
		_blush_cell(cell)
	if not wrong.is_empty():
		_say((tr("QN_WRONG_ONE") if wrong.size() == 1 else tr("QN_WRONG_N")) % wrong.size(),
			Face.Expr.WORRIED)
	elif state.queens.is_empty():
		_say(tr("QN_SEAT_FIRST"), Face.Expr.HAPPY)
	else:
		_say(tr("QN_ALL_RIGHT"), Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_redraw()
	return wrong.size()

## Every queen and cross the player laid goes, in a wave from the far corner;
## a given queen hops and keeps her crosses. Hints spent are not refunded.
func reset_board() -> void:
	if out_of_hearts or _ejecting:
		return
	_break_streak()
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
	_update_blooms()
	moves = 0
	_running = true
	_say(tr("QN_RESET"), Face.Expr.HAPPY)
	fx.cue("reset")
	_redraw()

## A completed daily is rebuilt from its seed with an empty court. Seat every
## queen of the generator's answer and settle the court as a finished solve
## wave leaves it: each bee standing on her colour in JOY, the crosses she
## derives already cleared away, nothing popping, washing or hopping.
## `solved` is not emitted a second time.
func restore_completed_board() -> void:
	var t := _now()
	_stop_all()
	_release_press()
	_clear_gesture()
	_tip_timer.stop()
	state.queens = {}
	state.crosses = {}
	state.locked = {}
	for r in state.n:
		state.queens[Vector2i(int(state.solution[r]), r)] = true
	state.history = []
	state.recompute()
	_cross_in = {}
	_cross_out = []
	_wash = {}
	_glint = {}
	_blush = {}
	_shiver = {}
	_sunk = {}
	_opened = t - 10.0
	_solved_at = t - 10.0
	_anim_until = 0.0
	# The meadow stands and the mist has lifted; a restore keeps the seal on
	# Insane (the day was won there), and cannot know whether it was flawless.
	_deal()
	_meadow_at = t - 10.0
	_mist_in_at = t - 20.0
	_mist_out_at = t - 10.0
	for g in _bloom_cells:
		_bloom[g] = {"at": t - 10.0, "open": true}
	if state.band == 3:
		_stamp_at = t - 10.0
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		layer.queue_redraw()
	for cell in _bees:
		_bees[cell].visible = false
	for cell in state.queens:
		var bee := _bee_node(cell)
		bee.visible = true
		bee.scale = Vector2.ONE
		bee.position = Vector2.ZERO
		bee.rotation = 0.0
		bee.modulate.a = 1.0
		bee.pinned = false
		_set_expr(bee, Face.Expr.JOY)
	_say(tr("QN_WIN"), Face.Expr.JOY)
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	if state.band == 3:
		out += "🌙 " + (tr("QN_MIST_SEAL") if state.has_mist() else tr("BN_INSANE_SEAL")) + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += "🏅 " + tr("BN_FLAWLESS")
	return out

# --- the win ---

## One bee in JOY, and the words. The board stays on the card as it slides
## down, every queen on her colour and the crosses gone.
func flat_win() -> Dictionary:
	return {"faces": [BeeFace.new()], "subtitle": tr("QN_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

## The bees hop in the family's wave along the diagonal with JOY and a
## spark each, and the Xs clear away in a scatter, leaving the queens on
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
	if not Motion.reduce:
		for y in state.n:
			for x in state.n:
				_glint[Vector2i(x, y)] = now + WIN_GLINT_AT + (x + y) * WIN_GLINT_STEP
	_say(tr("QN_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_busy_for(maxf(_solve_delay(Vector2i(state.n, state.n)) + Motion.SOLVE_TIME,
		CLEAR_DELAY + CLEAR_SPREAD + CLEAR_TIME))
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else checks == 0)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = now
		_combo_layer.queue_redraw()
	_update_blooms()
	_party()
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

# --- the flowers ---

## Every patch with all the queens it takes opens its flowers `delay` from
## now (when the queen lands), and one that has lost a queen folds them.
func _update_blooms(delay := 0.0) -> void:
	var now := _now()
	var opened := false
	for g in _bloom_cells:
		var full: bool = state.patch_full(g)
		var was: bool = bool(_bloom.get(g, {}).get("open", false))
		if full and not was:
			_bloom[g] = {"at": now + delay, "open": true}
			opened = true
		elif not full and was:
			_bloom[g] = {"at": now, "open": false}
	if opened and not is_done():
		_after(delay, fx.cue.bind("bloom"))
	_busy_for(delay + BLOOM_TIME + BLOOM_STAGGER * BLOOMS_MIST)
	_redraw()

# --- judging a seat ---

## Checks the crosses on Hard and Insane: every cross the player laid on a
## seat the answer wants shivers and blushes, and the sprout says how many.
func _check_crosses() -> int:
	var wrong: Array = state.wrong_crosses()
	var t := _now()
	if not Motion.reduce:
		for cell in wrong:
			_shiver[cell] = t
			_blush_cell(cell)
		_busy_for(Motion.SHIVER_TIME)
	if not wrong.is_empty():
		_say((tr("QN_CROSS_ONE") if wrong.size() == 1 else tr("QN_CROSS_N")) % wrong.size(),
			Face.Expr.WORRIED)
	elif state.queens.is_empty() and state.crosses.is_empty():
		_say(tr("QN_SEAT_FIRST"), Face.Expr.HAPPY)
	elif state.queens.is_empty():
		_say(tr("QN_CROSSES_RIGHT"), Face.Expr.JOY)
	else:
		_say(tr("QN_ALL_RIGHT"), Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_redraw()
	return wrong.size()

## A press on a cross a heart showed: it shivers, and the sprout says why.
func _refuse_shown(cell: Vector2i) -> void:
	_say(tr("QN_SHOWN"), Face.Expr.WORRIED)
	fx.cue("locked")
	if Motion.reduce:
		return
	_shiver[cell] = _now()
	_busy_for(Motion.SHIVER_TIME)
	_redraw()

## A right seat builds the streak (the combo pitched up the pentatonic from
## the second, the bubble from the third, confetti at five and ten) and now
## and then plays a gag. `land` is when her pop has landed, from now.
func _on_right_seat(cell: Vector2i, land: float) -> void:
	if is_done():
		return
	_streak += 1
	if _streak >= 2:
		var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
		_after(land, fx.cue.bind("combo", pow(2.0, step / 12.0), COMBO_DB))
	if _streak >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _streak
		_combo_cell = cell
		_combo_at = _now()
		_combo_out_at = -INF
		_combo_layer.queue_redraw()
	if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
		_after(land, func() -> void:
			fx.confetti(cell_to_local(cell.y, cell.x), 22)
			fx.cue("confetti"))
	_gag(cell, land)

## The streak ends: a lift, a refused seat, a wrong queen, an undo, a reset,
## the hearts running out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
		if _combo_layer != null:
			_combo_layer.queue_redraw()
	else:
		_combo_n = 0

# --- failing ---

## A queen the answer does not seat there, on Hard or Insane: she lands like
## any other, then goes WORRIED as her cell blushes, a heart goes (its halves
## fall), and EJECT_AFTER later she buzzes off and a cross drops in where she
## sat, for good.
func _wrong_seat(cell: Vector2i, land_at: float) -> void:
	if hearts <= 0 or is_done():
		return
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_split_index = hearts
	_split_at = land_at
	_ejecting = true
	if hearts <= 0:
		out_of_hearts = true
		_running = false
	_bad[cell] = true
	var wait := land_at - _now()
	_after(wait, func() -> void:
		_heart_layer.queue_redraw()
		fx.cue("heart_lost")
		if not Motion.reduce:
			fx.puff(cell_to_local(cell.y, cell.x), Pal.BAD, 4)
		_blush_cell(cell)
		_refresh_faces()
		_say(tr("QN_WRONG_SEAT"), Face.Expr.WORRIED)
		_redraw())
	_busy_for(wait + EJECT_AFTER + FLY_TIME)
	moved.emit()
	_after(wait + (0.0 if Motion.reduce else EJECT_AFTER), _eject.bind(cell))

## The wrong queen buzzes off: she rises and wiggles away, fading, the
## crosses she laid draw back into where she sat, and a cross in the family's
## rose drops into her seat and stays -- the heart has shown it empty.
func _eject(cell: Vector2i) -> void:
	_ejecting = false
	if is_done() or not _bad.has(cell):
		return
	_bad.erase(cell)
	var now := _now()
	var before := _snapshot()
	# She leaves on her own flight below, not in the wave's pop-out.
	before[cell] = State.BLANK
	state.reveal(cell)
	_fly_off(cell)
	_settle(before, now, _wave_from(cell))
	_cross_in[cell] = now + (0.0 if Motion.reduce else FLY_TIME * 0.45)
	_busy_for(FLY_TIME + Motion.POP_IN)
	fx.cue("buzz_off")
	_update_blooms()
	moved.emit()
	_redraw()
	if out_of_hearts:
		_after(0.0 if Motion.reduce else FLY_TIME, _run_out)
	else:
		_after(0.0 if Motion.reduce else FLY_TIME, _speak)

## The wrong queen's own flight out of her seat, up and wiggling, fading and
## shrinking; she is hidden and put back as she was once gone.
func _fly_off(cell: Vector2i) -> void:
	var bee: BeeFace = _bees.get(cell)
	if bee == null:
		return
	Motion.stop(_pos_tw.get(bee))
	Motion.stop(_look_tw.get(bee))
	var home := func() -> void:
		if state.mark_at(cell) != State.QUEEN:
			bee.visible = false
		bee.position = Vector2.ZERO
		bee.rotation = 0.0
		bee.scale = Vector2.ONE
		bee.modulate.a = 1.0
	if Motion.reduce:
		home.call()
		return
	var tw := bee.create_tween()
	tw.tween_method(func(u: float) -> void:
		bee.position = Vector2(sin(u * TAU * 2.0) * _cell * FLY_WIGGLE, -u * u * _cell * FLY_RISE)
		bee.rotation = sin(u * TAU * 2.0) * 0.3
		bee.scale = Vector2.ONE * (1.0 - 0.4 * u)
		bee.modulate.a = 1.0 - u * u, 0.0, 1.0, FLY_TIME)
	tw.tween_callback(home)
	_pos_tw[bee] = tw

## The last heart is gone: the court slips to dusk, the bees doze off along
## the diagonal, and the card comes up.
func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_release_press()
	_clear_gesture()
	_end_sinks(_now())
	_break_streak()
	fx.cue("out_of_hearts")
	_say(tr("QN_OUT"), Face.Expr.SLEEPY)
	for cell in state.queens:
		var bee: BeeFace = _bees.get(cell)
		if bee != null:
			_after(0.0 if Motion.reduce else (cell.x + cell.y) * 0.04,
				func() -> void:
					if _asleep:
						_set_expr(bee, Face.Expr.SLEEPY))
	_dusk_toward(DUSK)
	_redraw()
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
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["QN_OUT_BODY", "QN_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same court from the top in Reset's wave, every heart back,
## the shown crosses gone, the day's light, the clock and the moves from
## zero; hints spent stay spent, and a hint's queens keep their seats.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	elapsed = 0.0
	checks = 0
	moves = 0
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	state.reset(true)
	_deal()
	_settle(before, now, _from_far_corner())
	_blush = {}
	_shiver = {}
	_update_blooms()
	# _deal() puts the light back at once; hold the dusk so it fades.
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_running = true
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()
	_redraw()

## One more heart (the card's video): once a board. The light comes back and
## the bees wake.
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
	_refresh_faces()
	_speak()
	moved.emit()
	_redraw()

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

# --- the hearts ---

## The hearts over the court as one mesh on a paper pill (One Line's): pink
## with a small face and a leaf, a faint ghost where one was, the lost one's
## halves falling apart, and one coming back popping in.
func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _card.position.y + 12.0 + HEART_ROW * 0.5
	var x0 := size.x * 0.5 - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
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
				for k in pts.size():
					pts[k] = at + shift + pts[k].rotated(turn)
				b.polygon(pts, Color(Pal.FLOWER if side < 0 else Pal.FLOWER_DEEP, fade))
	_hearts_shown = b.mesh()
	_heart_layer.draw_mesh(_hearts_shown, null)

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

# --- the streak's bubble ---

## The streak's paper bubble at the upper right of the seat, "x3" and up in
## ink: it pops in the first time, bumps at each seat and deflates when the
## streak ends (One Line's).
func _draw_combo() -> void:
	if _combo_n < COMBO_FROM or _cell <= 0.0:
		return
	var now := _now()
	var k := 1.0
	var alpha := 1.0
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
	var cell := cell_to_local(_combo_cell.y, _combo_cell.x)
	var tail := cell + Vector2(_cell * 0.25, -_cell * 0.4)
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
	_combo_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_combo_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var ascent := font.get_ascent(COMBO_FONT)
	var descent := font.get_descent(COMBO_FONT)
	_combo_layer.draw_string(font, Vector2(-tw * 0.5, (ascent - descent) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_combo_layer.draw_set_transform(Vector2.ZERO)

# --- gags and the life over the court ---

## A right seat now and then plays a gag, picked by the seat's hash so a day
## replays the same: little hearts float up off her; a little drone bee flies
## a loop round her; or she twirls a whole turn on a hop. Under reduce-motion,
## none.
func _gag(cell: Vector2i, land: float) -> void:
	if Motion.reduce or is_done():
		return
	var roll := posmod(hash(Vector2i(cell.x * 13 + 7, cell.y * 5 + _streak)), GAG_ODDS)
	if roll >= GAGS:
		return
	match roll:
		0:
			var at := cell_to_local(cell.y, cell.x)
			var now := _now() + land
			for k in LOVE_HEARTS:
				var off := Vector2((k - (LOVE_HEARTS - 1) * 0.5) * 0.22, -0.2) * _cell
				_love.append({"at": at + off, "t": now + k * 0.08, "phase": _hash(cell + Vector2i(k, 7)) * TAU})
			_after(land, fx.cue.bind("love"))
		1:
			_fly_drone(cell, land)
		2:
			_twirl(cell)

## A little drone bee flies a loop and a quarter round the queen on `cell`,
## bobbing, facing the way she flies.
func _fly_drone(cell: Vector2i, land: float) -> void:
	var centre := cell_to_local(cell.y, cell.x)
	Motion.stop(_drone_tw)
	_drone.visible = true
	_drone.set_idle(true)
	_drone.modulate.a = 0.0
	_drone.position = centre + Vector2(0.0, -_cell * DRONE_R) - _drone.size * 0.5
	_drone_tw = create_tween()
	_drone_tw.tween_interval(land)
	_drone_tw.tween_property(_drone, "modulate:a", 1.0, 0.12)
	_drone_tw.parallel().tween_method(func(u: float) -> void:
		var a := -PI * 0.5 + u * TAU * 1.25
		var at := centre + Vector2(cos(a), sin(a) * 0.75) * _cell * DRONE_R \
			+ Vector2(0.0, sin(u * TAU * 4.0) * _cell * DRONE_BOB)
		_drone.position = at - _drone.size * 0.5
		_drone.scale = Vector2(-1.0 if sin(a) > 0.0 else 1.0, 1.0), 0.0, 1.0, DRONE_TIME)
	_drone_tw.tween_property(_drone, "modulate:a", 0.0, 0.15)
	_drone_tw.tween_callback(func() -> void: _drone.visible = false)
	_after(land, fx.cue.bind("drone"))

## The queen on `cell` twirls a whole turn on a little hop with a sparkle,
## once her pop has landed.
func _twirl(cell: Vector2i) -> void:
	var bee: BeeFace = _bees.get(cell)
	if bee == null:
		return
	_after(Motion.POP_IN, func() -> void:
		if is_done() or state.mark_at(cell) != State.QUEEN or _bad.has(cell):
			return
		Motion.stop(_look_tw.get(bee))
		bee.scale = Vector2.ONE
		var tw := bee.create_tween()
		tw.tween_property(bee, "rotation", TAU, TWIRL_TIME).from(0.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func() -> void: bee.rotation = 0.0)
		_look_tw[bee] = tw
		_hop(bee, _cell * TWIRL_HOP, TWIRL_TIME)
		fx.sparkle(cell_to_local(cell.y, cell.x) - Vector2(0.0, _cell * 0.3), Pal.SUN)
		fx.cue("twirl"))

## Keeps the life layer drawing while anything on it moves.
func _tick_life(now: float) -> bool:
	var still: Array = []
	for l in _love:
		if now < float(l.t) + LOVE_TIME:
			still.append(l)
	_love = still
	return not _love.is_empty() or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## The life over the court: love hearts floating off a seat, and the seal
## after the solve, with its words.
func _draw_life() -> void:
	if _cell <= 0.0:
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	if not _love.is_empty():
		var mesh := _love_heart()
		shown.append(mesh)
		for l in _love:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / LOVE_TIME
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.08 * _cell,
				-LOVE_RISE * _cell * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	if state.has_mist() and _solved_at == -INF:
		var pb := Face.Builder.new()
		_pips(pb)
		if not pb.verts.is_empty():
			var mesh := pb.mesh()
			shown.append(mesh)
			_life_layer.draw_mesh(mesh, null)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_life_shown = shown

## A little pink heart for the love gag, built once.
func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := _cell * LOVE_R
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

# --- the party ---

## After the solve wave: the court turns into a meadow, a flower opening on
## every free seat along the diagonal; the bees dance; confetti sweeps the
## court twice; on Insane the mist lifts; the seal stamps when the solve
## earned one (flawless, or any Insane court); and the queens issue a royal
## decree. Under reduce-motion the meadow and the seal stand at once.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else PARTY_AT
	_meadow_at = now + lead
	_busy_for(lead + BLOOM_TIME + 2.0 * state.n * MEADOW_STEP)
	_after(lead, func() -> void:
		_say(_decree(), Face.Expr.JOY)
		fx.cue("bloom"))
	if state.has_mist():
		_mist_out_at = now + lead * 0.5
		_after(lead * 0.5, fx.cue.bind("mist_lift"))
	if _flawless or state.band == 3:
		_stamp_at = now if Motion.reduce else now + lead + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		return
	var field := Rect2(_grid, Vector2.ONE * state.n * _cell)
	_after(lead + 0.15, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell * 0.3), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.6, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_after(lead + 0.35, _dance)

## Every bee sways left and right on the beat, DANCE_BEATS times, and
## settles.
func _dance() -> void:
	fx.cue("dance")
	for cell in state.queens:
		var bee: BeeFace = _bees.get(cell)
		if bee == null or not bee.visible:
			continue
		Motion.stop(_look_tw.get(bee))
		var tw := bee.create_tween()
		for i in DANCE_BEATS:
			var side := DANCE_TILT * (1.0 if (i + cell.x + cell.y) % 2 == 0 else -1.0)
			tw.tween_property(bee, "rotation", side, DANCE_BEAT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(bee, "rotation", 0.0, DANCE_BEAT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_look_tw[bee] = tw
	_busy_for(DANCE_BEAT * (DANCE_BEATS + 1))

## The queens' royal decree: one of DECREES silly ones, picked by the court
## itself, so a day always gets the same one.
func _decree() -> String:
	var cells := ""
	for row in state.region:
		for v in row:
			cells += str(v)
	return tr("QN_DECREE_%d" % posmod(hash(cells), DECREES))

## The seal on the card's lower right, dropping in from STAMP_FROM its size
## and settling with the back ease's overshoot, its words over it.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, state.band == 3)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := _card.end - Vector2(rad * 1.2, rad * 0.95)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if state.band == 3:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else (tr("QN_MIST_SEAL") if state.has_mist() else ""), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

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

## A fixed pseudo-random number per cell, so the Xs clear away in a
## scatter rather than a wave.
static func _hash(cell: Vector2i) -> float:
	return float(posmod(hash(cell), 1000)) / 1000.0
