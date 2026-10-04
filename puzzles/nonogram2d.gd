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
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
## A ruled-out cell takes Queens' X (2026-09-30, the user's call): the pebble
## read as a dot rather than as the player's "not here".
const CrossMark = preload("res://ui/faces/cross_mark.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const BeeFace = preload("res://ui/faces/bee_face.gd")
const Seal = preload("res://ui/flat/seal.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const MovesPill = preload("res://ui/flat/moves_pill.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
## The moves the out-of-moves card's video buys, once a board.
const MOVES_BONUS := 5

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

# --- the third polish (docs/superpowers/specs/2026-09-30-nonogram-polish-design.md) ---
## The hearts over the floor: One Line's, Light Up's, Tents' and Shikaku's
## pill.
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
## A wrong tile on Hard or Insane lands, wobbles rose, and EJECT_AFTER later
## turns out of its socket while a pebble drops in where it was.
const EJECT_AFTER := 0.8
## Out of hearts: the floor slips to dusk and the card comes up after.
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## The streak (Binairo's, Shikaku's, Tents', Light Up's, One Line's).
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
## The bubble shows its number this long, then deflates on its own; the
## streak itself runs on, and the next right move pops it back in.
const COMBO_HOLD := 1.2
const COMBO_FONT := 44
## Gags, three of every GAG_ODDS right strokes by the stroke's own hash.
const GAG_ODDS := 5
const GAGS := 3
const LOVE_HEARTS := 4
const LOVE_TIME := 1.3
const LOVE_RISE := 0.7
const LOVE_R := 0.14
const MUSH_HOLD := 1.4
const MUSH_SIZE := 0.8
const BEE_SIZE := 0.62
const BEE_TIME := 1.1
const BEE_BOB := 0.12
## A line that comes out right lays pebbles in its empty cells on Hard and
## Insane (every tile there is judged, so a line reading right is done),
## rippling out from the stroke AUTO_STEP a cell.
const AUTO_STEP := 0.035
## A line that reads right opens a daisy at the outer end of its tab.
const DAISY_R := 0.2
const DAISY_PETALS := 7
const DAISY_TIME := 0.45
const DAISY_FOLD := 0.2
## Leaf Fall: each tumbled number rides a leaf, tilted by its hash up to
## LEAF_TILT, and on the entrance flutters down LEAF_DROP cells onto its tab.
const LEAF_TILT := 0.32
const LEAF_LEN := 0.54
const LEAF_WIDE := 0.38
## How far below a number's origin its glyph's middle sits, in cells: the
## leaf is centred on the glyph, not on the baseline arithmetic.
const LEAF_DOWN := 0.05
const LEAF_WASH := 0.62
const LEAF_DROP := 0.9
const LEAF_FALL := 0.7
const LEAF_SWAY := 0.5
## The party, after the reveal: the picture is framed like a painting, the
## daisies let their petals go, confetti twice, and on Insane the leaves.
const PARTY_AT := 1.35
const PARTY_EXTRA := 1.7
const FRAME_OUT := 0.1
const FRAME_W := 0.16
const FRAME_TIME := 0.35
const PETALS := 4
const PETAL_TIME := 1.8
const PETAL_FALL := 1.3
const LEAVES := 26
const LEAF_TIME := 2.2
## The seal: One Line's.
const STAMP_AT := 0.5
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22
## What the sprout thinks the picture is, picked by the picture's hash.
const LOOKS := 12

# --- the floor's pieces (the checkup, 2026-10-02) ---
const PART_TAB := 0
const PART_LEAF := 1
const PART_DAISY := 2
const PART_SOCKET := 3
const PART_GUIDES := 4
const PART_GONE := 5
const PART_PIECE := 6
const SHAPE_SOCKET := 0
const SHAPE_TAB_ROW := 1
const SHAPE_TAB_COL := 2
const SHAPE_LEAF := 3
const SHAPE_DAISY := 4
const SHAPE_CROSS := 5
const SHAPE_GUIDES := 6
## SHAPE_TILE + the grout's step, 0 to GROUT_STEPS.
const SHAPE_TILE := 16
const GROUT_STEPS := 12
## A fading pebble's alpha is kept in this many steps.
const ALPHA_STEPS := 16
## How many colour slots a shape can have (`_slot`).
const SLOTS := 8.0
## The painted colours kept before the cache starts again.
const PAINTED_MAX := 4000
## A moment on a cell older than this has played out (`_prune`).
const PRUNE_AFTER := 2.0
const DAISY_INKS := [Pal.PETAL_EDGE, Pal.SURFACE, Pal.SUN]

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
## Translation keys (locale/ui.csv), read through tr() when said.
const TIPS := ["NG_TIP_RUNS", "NG_TIP_DRAG", "NG_TIP_GREEN"]

## Back to camp from the out-of-hearts card: the host leaves the board.
signal leave

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

var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
## Insane's move counter (ui/flat/moves_pill.gd): `max_moves` is 0 on a band
## that does not count. Out of moves unsolved is `out_of_hearts`, the name
## the host and the card already know.
var moves_left := 0
var max_moves := 0
var _moves_pill := MovesPill.new()
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
## Cell -> when a wrong tile landed there: drawn until it is taken back.
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
## Line key -> {"at", "open"}: its daisy opening, or folding when not open.
var _bloom: Dictionary = {}
## The life over the floor: love hearts off a stroke, petals and leaves at
## the party, and the seal.
var _life_layer: Control
var _life_shown: Array = []
var _life_alive := false
var _love: Array = []
var _petals: Array = []
var _falling: Array = []
var _stamp_at := INF
var _frame_at := INF
var _seal_mesh: ArrayMesh
var _love_mesh: ArrayMesh
var _mushroom: MushroomFace
var _mush_tw: Tween
var _bee: BeeFace
var _bee_tw: Tween
var _card := Rect2()

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
var _solved_at := -INF
var _gen := 0
var _floor: ArrayMesh
## The mesh the last _draw actually handed to the canvas item. A canvas
## command holds the mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: ArrayMesh
## The floor's pieces (`_build_floor`): shape id -> [verts, indices, colour
## runs]; painted colours by [shape, colours...]; a shape's indices offset to
## a run's base by Vector2i(shape, base); each piece's run of vertices by
## Vector2i(part, index) -> Vector2i(base, room). Cut to the cell and the
## puzzle, so cleared by `_layout` and a new deal.
var _shapes: Dictionary = {}
var _inked: Dictionary = {}
var _offsets: Dictionary = {}
var _runs: Dictionary = {}
var _fixed := 0
var _cursor := 0
var _run_end := -1
var _fv := PackedVector2Array()
var _fc := PackedColorArray()
var _fi := PackedInt32Array()
var _tv := PackedVector2Array()
var _tc := PackedColorArray()
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "nonogram"
func title() -> String: return "Nonogram"

func rules() -> String:
	var out := tr("NG_RULES")
	if state.has_leaves():
		out += "\n\n" + tr("NG_RULES_LEAF")
	if max_moves > 0:
		out += "\n\n" + tr("RULES_MOVES") % max_moves
	return out

## The lines the sprout cycles: a leafy board leads with the wind's two.
func _tips() -> Array:
	var lead: Array = ["TIP_MOVES"] if max_moves > 0 else []
	if state.has_leaves():
		return lead + ["NG_TIP_LEAF", "NG_TIP_LEAF_2"] + TIPS
	return lead + TIPS

## The tutorial, a page a rule, each a little house painted by the board
## itself (ui/hud/nonogram_tutorial_diagram.gd): the runs, their order and
## the rub-out, the X's, the hint, then hearts on Hard and Insane and Leaf
## Fall on a leafy day.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/nonogram_tutorial_diagram.gd")
	var hints: int = State.HINTS_BY_BAND[clampi(state.band, 0, 3)]
	var steps := [
		[Diagram.Lesson.RUNS, "HTP_NG_RUNS", tr("HTP_NG_RUNS_BODY")],
		[Diagram.Lesson.ORDER, "HTP_NG_ORDER", tr("HTP_NG_ORDER_BODY")],
		[Diagram.Lesson.CROSS, "HTP_NG_CROSS", tr("HTP_NG_CROSS_BODY")]]
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_NG_HINT_BODY_ONE") if hints == 1 else tr("HTP_NG_HINT_BODY_N") % hints])
	if state.has_leaves():
		steps.append([Diagram.Lesson.LEAVES, "NG_LEAF_SEAL", tr("NG_RULES_LEAF")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.hearts = maxi(1, max_hearts)
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves))
	return pages

## Insane counts moves: no Undo (rubbing a tile out is the take-back, and it
## costs one), no hint and no Check, which would each say what is wrong.
func capabilities() -> Array[String]:
	if state.band >= 3:
		return []
	return ["undo", "hint", "check"]

## What the phone does under each cue (docs/agents/haptics.md). A stroke
## knocks once, as it is let go (`_release`, not the `place` cue, which a
## wrong tile's landing fires too): a tap when it laid a tile, a tick when
## it only crossed cells out or rubbed some out, a bump when it brought a
## line to read right (the `bloom` cue also fires for a hint, an Undo and an
## eject). The streak's confetti is the other milestone. The cells sinking
## under the finger, the brush, a grouted tile tapped (`locked`), the
## pebbles a finished line lays, the eject's `slip`, the streak's pluck and
## the gags say nothing. The seal thuds as it lands (`_party`).
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
	_mushroom = MushroomFace.new()
	_mushroom.name = "Mushroom"
	_mushroom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mushroom.z_index = 1
	_mushroom.visible = false
	add_child(_mushroom)
	_bee = BeeFace.new()
	_bee.name = "Bee"
	_bee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bee.z_index = 3
	_bee.visible = false
	add_child(_bee)
	_life_layer = _layer("Life", 2, _draw_life)
	_heart_layer = _layer("Hearts", 1, _draw_hearts)
	_combo_layer = _layer("Combo", 3, _draw_combo)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

## A full-rect layer over the floor, drawn by `draw` (One Line's).
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
	state.setup(rng, difficulty, bank_step)
	max_hearts = State.HEARTS[state.band]
	max_moves = state.moves_budget()
	_heart_used = false
	_lost_ever = false
	_deal()
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
	_solved_at = -INF
	_seed_verdicts()
	_layout()
	_enter()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## The floor as it is dealt, and as Try again deals it back: every heart, the
## day's light, nothing judged, blooming or partying.
func _deal() -> void:
	hearts = max_hearts
	moves_left = max_moves
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
	_petals = []
	_falling = []
	_stamp_at = INF
	_frame_at = INF
	_seal_mesh = null
	Motion.stop(_dusk_tw)
	Motion.stop(_mush_tw)
	Motion.stop(_bee_tw)
	modulate = Color.WHITE
	if _mushroom != null:
		_mushroom.visible = false
	if _bee != null:
		_bee.visible = false
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

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
	var row := _heart_row()
	var tall := minf(size.y, floor_size.y + 2.0 * PAD + row)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - floor_size.x * 0.5,
		_card.position.y + row + (tall - row - floor_size.y) * 0.5) + _band
	# The life's meshes are cut to the cell; a new cell cuts them again.
	_love_mesh = null
	_runs = {}
	_mushroom.size = Vector2.ONE * _cell * MUSH_SIZE
	_mushroom.pivot_offset = _mushroom.size * 0.5
	_bee.size = Vector2.ONE * _cell * BEE_SIZE
	_bee.pivot_offset = _bee.size * 0.5
	_refresh()
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		layer.queue_redraw()

## The strip the hearts take over the floor, on a board that has them.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 or max_moves > 0 else 0.0

## The cell a slot of `available` height holds, capped by the width. The bands
## are measured from the puzzle in hand -- as the island measures its margin
## of bare platform -- so a gentle picture gets a tight board.
func _cell_for(available: float) -> float:
	if state.bitmap.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / (state.w + state.gw * NUM),
		(available - 2.0 * PAD - _heart_row()) / (state.h + state.gh * NUM))

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * (state.h + state.gh * NUM) + 2.0 * PAD + _heart_row())

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
	var now := _now()
	if now < _anim_until:
		_refresh()
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1) \
			or _moves_pill.animating(now - 0.1):
		_heart_layer.queue_redraw()
	if _combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF):
		_combo_layer.queue_redraw()
	# One more redraw once the life goes quiet, so its last frame is not left
	# standing.
	var alive := _tick_life(now)
	if alive or _life_alive:
		_life_layer.queue_redraw()
	_life_alive = alive

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
## bands' tabs, leaves and daisies, the sockets, the five-cell guides over
## them, the pieces on their way out, and what the player has put down.
##
## Building all of that in script was 14 ms on a full Insane floor, on every
## frame anything on it moved (the checkup, docs/agents/boards/nonogram.md):
## play ran at 22 ms a frame. Now every piece is a shape made once about its
## own origin (`_shape`) and copied in natively under its transform, its
## colours filled a run at a time (`_ink`), into a run of vertices laid out
## for it (`_runs`) so its indices, offset once, stay true; only the frame
## round the finished picture is built in script. It is still one indexed
## mesh, so at rest it draws exactly as before.
func _build_floor(t: float) -> ArrayMesh:
	if _runs.is_empty():
		_lay_runs()
	_fv = PackedVector2Array()
	_fc = PackedColorArray()
	_fi = PackedInt32Array()
	_tv = PackedVector2Array()
	_tc = PackedColorArray()
	_prune(t)
	var gone := _gone(t)
	var focus := _focus_level(t)
	_tabs(gone, focus, t)
	_leaves(gone, t)
	_daisies(t)
	var floor_alpha := 1.0 - gone
	for y in state.h:
		for x in state.w:
			var cell := Vector2i(x, y)
			var sink := _sink(cell, t)
			if floor_alpha <= 0.0:
				continue
			var lit := focus if focus > 0.0 and (x == _focus_cell.x or y == _focus_cell.y) else 0.0
			var tint := Color(Pal.SUN, FOCUS * lit)
			var pebble := state.mark_at(cell) == State.MARK
			# Check on Hard and Insane points at pebbles: the socket blushes.
			if pebble and _wrong.has(cell):
				tint = Color(Pal.BAD_TILE, Motion.flash_level(t - float(_wrong[cell])) * 0.85)
			_open_run(PART_SOCKET, y * state.w + x)
			_put(SHAPE_SOCKET, [Mosaic.socket_colour(pebble, floor_alpha, sink, tint)],
				Transform2D(0.0, Vector2.ONE * sink, 0.0, cell_to_local(y, x)))
	_guides(gone)
	_build_leaving(t)
	var grout := _grout(gone)
	for y in state.h:
		for x in state.w:
			var cell := Vector2i(x, y)
			var mark := state.mark_at(cell)
			if mark == State.BLANK:
				continue
			_open_run(PART_PIECE, y * state.w + x)
			if mark == State.MARK:
				_draw_pebble(cell, t)
			else:
				_draw_tile(cell, t, grout)
	_close_run()
	_build_bad(t)
	var b := Face.Builder.new()
	_frame(b, t)
	if not b.verts.is_empty():
		_tail(b.verts, b.cols, b.idx, Transform2D.IDENTITY)
	if _fi.is_empty():
		return null
	_fv.resize(_fixed)
	_fc.resize(_fixed)
	_fv.append_array(_tv)
	_fc.append_array(_tc)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _fv
	arrays[Mesh.ARRAY_COLOR] = _fc
	arrays[Mesh.ARRAY_INDEX] = _fi
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## Forgets every moment on a cell that has played out (each is under a
## second), so a piece at rest skips the curve readers (`_draw_tile`).
func _prune(t: float) -> void:
	for d: Dictionary in [_arrive, _nudge, _hop]:
		for cell in d.keys():
			if t - float(d[cell].at) > PRUNE_AFTER:
				d.erase(cell)
	for d: Dictionary in [_wrong, _shiver]:
		for cell in d.keys():
			if t - float(d[cell]) > PRUNE_AFTER:
				d.erase(cell)
	for key in _glint.keys():
		if t - float(_glint[key]) > PRUNE_AFTER:
			_glint.erase(key)

# --- the floor's shapes and runs ---

## Every piece's run of vertices, in the order `_build_floor` visits them,
## each as long as the piece's largest look: a line's tab, leaves and daisy,
## then every cell's socket, the guides, every cell's leaving piece and every
## cell's piece (a tile with its gaps open is the largest).
func _lay_runs() -> void:
	_runs = {}
	_shapes = {}
	_inked = {}
	_offsets = {}
	_fixed = 0
	var room := func(part: int, index: int, verts: int) -> void:
		_runs[Vector2i(part, index)] = Vector2i(_fixed, verts)
		_fixed += verts
	var lines: int = state.h + state.w
	for k in lines:
		room.call(PART_TAB, k, _shape(SHAPE_TAB_ROW if k < state.h else SHAPE_TAB_COL)[0].size())
	for k in lines:
		if _tumbled(k):
			room.call(PART_LEAF, k, _shape(SHAPE_LEAF)[0].size() * _numbers(k, _now()).size())
	for k in lines:
		room.call(PART_DAISY, k, _shape(SHAPE_DAISY)[0].size())
	var socket: int = _shape(SHAPE_SOCKET)[0].size()
	for k in state.w * state.h:
		room.call(PART_SOCKET, k, socket)
	room.call(PART_GUIDES, 0, _shape(SHAPE_GUIDES)[0].size())
	var piece := maxi(_shape(SHAPE_TILE)[0].size(), 2 * _shape(SHAPE_CROSS)[0].size())
	for k in state.w * state.h:
		room.call(PART_GONE, k, piece)
	for k in state.w * state.h:
		room.call(PART_PIECE, k, piece)

## Shape `id` about its own origin, made the first time it is asked for, as
## [verts, indices, colour runs]. It is drawn in slot colours (`_slot`), and
## its colour runs are (count, slot * 2 + clear) pairs: a fan's body is one
## run and its feather another, so painting it is a fill a run.
func _shape(id: int) -> Array:
	var hit = _shapes.get(id)
	if hit != null:
		return hit
	var b := Face.Builder.new()
	var inset := _cell * TAB_INSET
	match id:
		SHAPE_SOCKET:
			b.fan(Mosaic.socket_outline(_cell), _slot(0))
		SHAPE_TAB_ROW:
			b.fan(Face.Builder.round_rect(Vector2.ZERO, Vector2(_band.x - _cell * TAB_GAP, _cell - 2.0 * inset),
				_cell * TAB_RADIUS), _slot(0))
		SHAPE_TAB_COL:
			b.fan(Face.Builder.round_rect(Vector2.ZERO, Vector2(_cell - 2.0 * inset, _band.y - _cell * TAB_GAP),
				_cell * TAB_RADIUS), _slot(0))
		SHAPE_LEAF:
			var len := _cell * LEAF_LEN
			b.fan(_leaf_shape(len, _cell * LEAF_WIDE), _slot(0))
			b.stroke(PackedVector2Array([Vector2(-len * 0.4, 0.0), Vector2(len * 0.56, 0.0)]),
				maxf(1.5, _cell * 0.018), _slot(1), false, false)
		SHAPE_DAISY:
			_daisy(b, Vector2.ZERO, _cell * DAISY_R, 0.0, [_slot(0), _slot(1), _slot(2)])
		SHAPE_CROSS:
			CrossMark._x(b, Transform2D.IDENTITY, _cell, CrossMark.WIDTH * _cell, _slot(0))
		SHAPE_GUIDES:
			if state.w > GUIDE_EVERY or state.h > GUIDE_EVERY:
				var field := Vector2(_cell * state.w, _cell * state.h)
				for i in range(GUIDE_EVERY, state.w, GUIDE_EVERY):
					b.stroke(PackedVector2Array([_grid + Vector2(i * _cell, 0.0),
						_grid + Vector2(i * _cell, field.y)]), GUIDE_WIDTH, _slot(0), false, false)
				for i in range(GUIDE_EVERY, state.h, GUIDE_EVERY):
					b.stroke(PackedVector2Array([_grid + Vector2(0.0, i * _cell),
						_grid + Vector2(field.x, i * _cell)]), GUIDE_WIDTH, _slot(0), false, false)
		_:
			# SHAPE_TILE + a step of the grout closing on the win.
			var outlines := Mosaic.tile_outlines(_cell, float(id - SHAPE_TILE) / GROUT_STEPS)
			for k in outlines.size():
				b.fan(outlines[k], _slot(k))
	var runs := PackedInt32Array()
	var last := -1
	for c in b.cols:
		var code := roundi(c.r * SLOTS) * 2 + (1 if c.a < 0.5 else 0)
		if code == last:
			runs[runs.size() - 2] += 1
		else:
			runs.append(1)
			runs.append(code)
			last = code
	var shape := [b.verts, b.idx, runs]
	_shapes[id] = shape
	return shape

## The colour a shape is drawn in for slot `k`, read back by `_shape`.
static func _slot(k: int) -> Color:
	return Color(float(k) / SLOTS, 0.0, 0.0, 1.0)

## Shape `id`'s colours with its slots painted `colours`: kept, since most
## pieces wear the same ones frame after frame.
func _ink(id: int, colours: Array) -> PackedColorArray:
	var key := [id] + colours
	var hit = _inked.get(key)
	if hit != null:
		return hit
	if _inked.size() > PAINTED_MAX:
		_inked = {}
	var runs: PackedInt32Array = _shape(id)[2]
	var out := PackedColorArray()
	var run := PackedColorArray()
	for i in range(0, runs.size(), 2):
		var code := runs[i + 1]
		var c: Color = colours[code >> 1]
		run.resize(runs[i])
		run.fill(Color(c, 0.0) if code & 1 else c)
		out.append_array(run)
	_inked[key] = out
	return out

## The next pieces go into run (`part`, `index`).
func _open_run(part: int, index: int) -> void:
	var run: Vector2i = _runs[Vector2i(part, index)]
	_cursor = run.x
	_run_end = run.x + run.y

## The next pieces go on the tail.
func _close_run() -> void:
	_cursor = 0
	_run_end = -1

## Shape `id` painted `colours` under `xf`, into the open run while it has
## room, or on the tail.
func _put(id: int, colours: Array, xf: Transform2D) -> void:
	var shape := _shape(id)
	var verts: PackedVector2Array = shape[0]
	var n := verts.size()
	var cols := _ink(id, colours)
	if _cursor + n > _run_end:
		_tail(verts, cols, shape[1], xf)
		return
	_fv.resize(_cursor)
	_fc.resize(_cursor)
	_fv.append_array(xf * verts)
	_fc.append_array(cols)
	var key := Vector2i(id, _cursor)
	var ix = _offsets.get(key)
	if ix == null:
		ix = (shape[1] as PackedInt32Array).duplicate()
		for k in ix.size():
			ix[k] += _cursor
		_offsets[key] = ix
	_fi.append_array(ix)
	_cursor += n

## A drawing with no run of its own, after every run, its indices offset in
## script (One Line's).
func _tail(verts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, xf: Transform2D) -> void:
	var base := _fixed + _tv.size()
	_tv.append_array(verts if xf == Transform2D.IDENTITY else xf * verts)
	_tc.append_array(cols)
	var ix := idx.duplicate()
	for k in ix.size():
		ix[k] += base
	_fi.append_array(ix)

## The grout's step now: the tile's shape is kept at GROUT_STEPS of them.
static func _grout(gone: float) -> float:
	return roundf(gone * GROUT_STEPS) / GROUT_STEPS

## A tile painted `colours` under `xf`, its gaps closed by `grout`.
func _put_tile(grout: float, colours: Array, xf: Transform2D) -> void:
	_put(SHAPE_TILE + roundi(grout * GROUT_STEPS), colours, xf)

## A pebble -- Queens' X and its shadow -- at `at`, scaled `grow`, turned
## `angle`, at `alpha` (in ALPHA_STEPS, so a fading one keeps its colours).
func _put_cross(at: Vector2, grow: Vector2, alpha: float, angle := 0.0) -> void:
	if grow.x <= 0.0 or grow.y <= 0.0 or alpha <= 0.0:
		return
	alpha = ceilf(alpha * ALPHA_STEPS) / ALPHA_STEPS
	_put(SHAPE_CROSS, [Color(Pal.TEXT, CrossMark.SHADOW_ALPHA * alpha)],
		Transform2D(angle, grow, 0.0, at + Vector2(0.0, CrossMark.DROP * _cell * grow.y)))
	_put(SHAPE_CROSS, [Color(Pal.BARK, alpha)], Transform2D(angle, grow, 0.0, at))

## The paper tabs behind the clue numbers, one a line, each washed toward its
## line's verdict and toward the sun while the finger is on its line. They
## leave with the rest of the scaffolding on the win.
func _tabs(gone: float, focus: float, t: float) -> void:
	var alpha := TAB_A * (1.0 - gone)
	if alpha <= 0.0:
		return
	var inset := _cell * TAB_INSET
	for y in state.h:
		var ink := _tab_colour("r%d" % y, state.row_state(y), t)
		if focus > 0.0 and y == _focus_cell.y:
			ink = ink.lerp(Pal.SUN_TILE, FOCUS_TAB * focus)
		_open_run(PART_TAB, y)
		_put(SHAPE_TAB_ROW, [Color(ink, alpha)],
			Transform2D(0.0, Vector2(_grid.x - _band.x, _grid.y + y * _cell + inset)))
	for x in state.w:
		var ink := _tab_colour("c%d" % x, state.col_state(x), t)
		if focus > 0.0 and x == _focus_cell.x:
			ink = ink.lerp(Pal.SUN_TILE, FOCUS_TAB * focus)
		_open_run(PART_TAB, state.h + x)
		_put(SHAPE_TAB_COL, [Color(ink, alpha)],
			Transform2D(0.0, Vector2(_grid.x + x * _cell + inset, _grid.y - _band.y)))

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
	_bloom = {}
	for k in state.h + state.w:
		if _line_state(k) == State.LINE_OK:
			_bloom[_key(k)] = {"at": -100.0, "open": true}
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
	var was_ok := int(l.state) == State.LINE_OK
	l.was = _tab_colour(key, int(l.state), _now())
	l.to = _verdict_ink(line_state)
	l.state = line_state
	l.at = at
	_busy_for(at - _now() + WASH_TIME)
	# The daisy at the tab's end opens as the line comes out right, and
	# folds when it stops being right.
	if line_state == State.LINE_OK:
		_bloom[key] = {"at": at, "open": true}
		_busy_for(at - _now() + DAISY_TIME)
		if not state.is_solved():
			_after(at - _now(), fx.cue.bind("bloom"))
	elif was_ok:
		_bloom[key] = {"at": at, "open": false}
		_busy_for(at - _now() + DAISY_FOLD)
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
	if _solved_at > -INF:
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
func _guides(gone: float) -> void:
	if state.w <= GUIDE_EVERY and state.h <= GUIDE_EVERY:
		return
	var alpha := 1.0 - gone
	if alpha <= 0.0:
		return
	_open_run(PART_GUIDES, 0)
	_put(SHAPE_GUIDES, [Color(Pal.LINE, GUIDE_ALPHA * alpha)], Transform2D.IDENTITY)

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
func _draw_tile(cell: Vector2i, t: float, grout: float) -> void:
	if _resting(cell):
		_put_tile(grout, Mosaic.tile_colours(state.locked.has(cell), grout, 1.0, 0.0, _tone(cell)),
			Transform2D(0.0, cell_to_local(cell.y, cell.x)))
		return
	var grow := _grow(cell, t)
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var at := cell_to_local(cell.y, cell.x) + _offset(cell, t)
	var since := t - float(_wrong.get(cell, -100.0))
	_put_tile(grout, Mosaic.tile_colours(state.locked.has(cell), grout, _alpha(cell, t),
		Motion.flash_level(since), _tone(cell), _shine(cell, t)),
		Transform2D(Motion.wobble_angle(since), grow, 0.0, at))

## A pebble: the same arrival, sink and lean, and on the win it clears away
## in a scatter -- a hard board finishes with 38 of its 81 cells under
## pebbles, and the picture has to be left standing on its own.
func _draw_pebble(cell: Vector2i, t: float) -> void:
	var alpha := _alpha(cell, t)
	if _solved_at > -INF:
		var clear := _dec((t - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD) / CLEAR_TIME)
		if clear >= 1.0:
			return
		alpha *= 1.0 - clear
	if alpha >= 1.0 and _resting(cell):
		_put_cross(cell_to_local(cell.y, cell.x), Vector2.ONE, 1.0)
		return
	_put_cross(cell_to_local(cell.y, cell.x) + _offset(cell, t), _grow(cell, t), alpha)

## Nothing is happening to the piece on `cell`: it is drawn as it lies.
func _resting(cell: Vector2i) -> bool:
	return not (_arrive.has(cell) or _sunk.has(cell) or _nudge.has(cell) or _hop.has(cell)
		or _wrong.has(cell) or _shiver.has(cell)) and _glint.is_empty() and _solved_at == -INF

## The pieces Reset, an undo or a fresh stroke took away: each shrinks to
## nothing with the quarter turn where it lay, after the state has forgotten
## it (the Remove moment), each in its cell's leaving run (a second one on
## the same cell goes on the tail).
func _build_leaving(t: float) -> void:
	var keep: Array = []
	for g in _leaving:
		if Motion.pop_out_scale(t - float(g.at)) > 0.0:
			keep.append(g)
	_leaving = keep
	if keep.is_empty():
		return
	var order := keep.duplicate()
	order.sort_custom(func(a, b) -> bool:
		return a.cell.y * state.w + a.cell.x < b.cell.y * state.w + b.cell.x)
	var last := -1
	for g in order:
		var cell: Vector2i = g.cell
		var index: int = cell.y * state.w + cell.x
		if index != last:
			_open_run(PART_GONE, index)
			last = index
		var elapsed: float = t - float(g.at)
		var grow := Vector2.ONE * Motion.pop_out_scale(elapsed)
		var at := cell_to_local(cell.y, cell.x)
		var angle := 0.0 if Motion.reduce else PI * 0.5 * clampf(elapsed / Motion.POP_OUT, 0.0, 1.0)
		if int(g.kind) == State.MARK:
			_put_cross(at, grow, 1.0, angle)
		else:
			_put_tile(0.0, Mosaic.tile_colours(bool(g.held), 0.0, 1.0, 0.0, _tone(cell)),
				Transform2D(angle, grow, 0.0, at))
	_close_run()

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
	if _solved_at == -INF:
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
	var faded := 1.0 - _gone(t) * _clue_gone(t)
	if faded <= 0.0:
		return
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell * NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	for k in state.h + state.w:
		var key := _key(k)
		var index: int = k if k < state.h else k - state.h
		var scale := _clue_scale(key, index, t)
		if scale.x <= 0.0:
			continue
		var ink := Color(_clue_ink(_line_state(k)), faded)
		for n in _numbers(k, t):
			draw_set_transform_matrix(_line_xf(k, scale, t) * Transform2D(float(n.rot), n.at))
			_number(font, px, rise, str(n.value), Vector2.ZERO, ink)
	draw_set_transform(Vector2.ZERO)

## Line `k` (rows, then columns) as a key and as a verdict.
func _key(k: int) -> String:
	return "r%d" % k if k < state.h else "c%d" % (k - state.h)

func _line_state(k: int) -> int:
	return state.row_state(k) if k < state.h else state.col_state(k - state.h)

func _tumbled(k: int) -> bool:
	return state.row_tumbled(k) if k < state.h else state.col_tumbled(k - state.h)

## Line `k`'s numbers' frame: the middle of its band, popped, bumped and
## hopped.
func _line_xf(k: int, scale: Vector2, t: float) -> Transform2D:
	var key := _key(k)
	var centre: Vector2
	if k < state.h:
		centre = Vector2(_grid.x - _band.x * 0.5, _grid.y + (k + 0.5) * _cell + _clue_lift(key, t))
	else:
		centre = Vector2(_grid.x + (k - state.h + 0.5) * _cell, _grid.y - _band.y * 0.5 + _clue_lift(key, t))
	return Transform2D(0.0, scale, 0.0, centre)

## Line `k`'s numbers as drawn, each {"value", "at", "rot"} in the line's
## frame: right-aligned along a row band, bottom-aligned up a column one, as a
## nonogram's clues always are. A line with nothing in it says 0, so every
## line speaks. A tumbled line (Leaf Fall) shows its numbers largest first --
## an order that says nothing -- each on a leaf tilted by its own hash, and
## on the entrance each flutters down onto the tab.
func _numbers(k: int, t: float) -> Array:
	var clue: Array = (state.row_clues[k] if k < state.h else state.col_clues[k - state.h]).duplicate()
	if clue.is_empty():
		clue = [0]
	var tumble := _tumbled(k)
	if tumble:
		clue.sort()
		clue.reverse()
	var out: Array = []
	var index: int = k if k < state.h else k - state.h
	for i in clue.size():
		var slot: int = clue.size() - 1 - i
		var along := _band.x * 0.5 - _cell * NUM * (slot + 0.5) if k < state.h \
			else _band.y * 0.5 - _cell * NUM * (slot + 0.5)
		var at := Vector2(along, 0.0) if k < state.h else Vector2(0.0, along)
		var rot := 0.0
		if tumble:
			var h := _hash(Vector2i(k * 7 + 3, i * 13 + 5))
			rot = (h - 0.5) * 2.0 * LEAF_TILT
			at += Vector2(_hash(Vector2i(i, k)) - 0.5, h - 0.5) * _cell * 0.06
			if not Motion.reduce:
				var e := t - _opened - _enter_clue_delay(index) - i * 0.07
				var u := clampf(e / LEAF_FALL, 0.0, 1.0)
				var settle := 1.0 - (1.0 - u) * (1.0 - u)
				at.y -= LEAF_DROP * _cell * (1.0 - settle)
				rot += sin(e * 9.0 + h * TAU) * LEAF_SWAY * (1.0 - u)
		out.append({"value": clue[i], "at": at, "rot": rot})
	return out

## How far the numbers go on the win: CLUE_GONE, then all the way once the
## frame is hung round the picture.
func _clue_gone(t: float) -> float:
	if _frame_at == INF:
		return CLUE_GONE
	return lerpf(CLUE_GONE, 1.0, _dec((t - _frame_at) / FRAME_TIME))

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
	_say(tr("NG_GROUTED") if state.mark_at(cell) == State.FILL else tr("NG_SHOWN"), Face.Expr.PUZZLED)
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
	if is_done() or cell.x < 0 or out_of_hearts or _ejecting:
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
		# Hard and Insane judge every tile as it goes down: the stroke stops
		# at the first one the picture does not want, and the cells after it
		# are let go (Nonogram.com's rule, and every phone picross's).
		var bad := Vector2i(-1, -1)
		if state.judged():
			var kept: Array = []
			for c in pending:
				if int(c.to) == State.FILL and not state.wants(c.cell):
					bad = c.cell
					break
				kept.append(c)
			pending = kept
		# Insane counts moves: the stroke stops where the budget does.
		var cost := 0
		if max_moves > 0:
			var afford: Array = []
			for c in pending:
				var one: int = state.move_cost(c.cell, int(c.to))
				if cost + one > moves_left:
					break
				cost += one
				afford.append(c)
			pending = afford
		var settled := state.settled_lines()
		var ok_before := _ok_lines()
		var before: Dictionary = state.marks.duplicate()
		var changed: Array = state.apply(pending)
		var per := Motion.ENTER_STAGGER if was_drag else 0.0
		# One stroke is one move, however many cells it painted, which is
		# what makes a painted run come back on a single Undo. A sweep lays
		# its pieces in a wave along the finger's path and puffs none; a
		# single tap puffs and leans the neighbours.
		var arrivals := _commit(before, changed, now, per, Vector2i(-1, -1) if was_drag else cell)
		_knock(changed, ok_before)
		if cost > 0:
			_spend(cost, now + (0.0 if Motion.reduce else Motion.stagger(changed.size(), per)))
		if bad.x >= 0:
			var land := now + (0.0 if Motion.reduce else Motion.stagger(changed.size(), per))
			# A run painted one cell too far still finishes its line.
			_auto_pebbles(arrivals, ok_before, false, bad)
			arrivals[bad] = land
			_wrong_tile(bad, land)
		elif not changed.is_empty():
			_judge_stroke(before, changed, arrivals, settled, ok_before)
		_end_sinks(now, arrivals)
		return
	_end_sinks(now)
	# Nothing changed: a hint has grouted the cell in, or a heart showed it
	# empty.
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
				Pal.MOSAIC if mark == State.FILL else Pal.BARK)
			_nudge_around(tapped, t)
	fx.cue("place")
	_speak()
	_refresh()
	note_move()
	return arrivals

## The stroke's one knock, as the finger lets it go: a bump when it brought
## a line to read right, a tap when it laid a tile, a tick for crosses and
## rub-outs. Nothing when it changed nothing, or solved the picture (the win
## has spoken).
func _knock(changed: Array, ok_before: Dictionary) -> void:
	if changed.is_empty() or is_done():
		return
	var kind: int = Haptics.TICK
	for cell in changed:
		if state.mark_at(cell) == State.FILL:
			kind = Haptics.TAP
	for k in _ok_lines():
		if not ok_before.has(k):
			kind = Haptics.BUMP
	fx.buzz(kind)

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
	_tip_idx = (_tip_idx + 1) % _tips().size()
	_say(tr(_tips()[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and not _ejecting and not state.history.is_empty()

## The host holds its hint video while a wrong tile is being taken back.
func busy() -> bool:
	return _ejecting

## Takes back the last stroke, however many cells it painted, in the wave it
## was laid in: the reverse of Place. Counts no move.
func undo() -> bool:
	if is_done() or out_of_hearts or _ejecting or state.history.is_empty():
		return false
	var now := _now()
	_end_sinks(now)
	_clear_gesture()
	var before: Dictionary = state.marks.duplicate()
	var touched: Array = state.undo()
	_transition(before, touched, now, Motion.ENTER_STAGGER)
	_break_streak()
	_speak()
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return State.HINTS_BY_BAND[state.band] + hints_extra - hints_used

## Lays one tile the picture wants and grouts it in for good: the first cell
## in reading order the player has not filled. It drops in from above under a
## ring with a sparkle; a pebble there pops out first. Counts no move but can
## finish the puzzle.
func hint() -> bool:
	if is_done() or out_of_hearts or _ejecting or hints_left() <= 0:
		return false
	var now := _now()
	_end_sinks(now)
	_clear_gesture()
	var before: Dictionary = state.marks.duplicate()
	var ok_before := _ok_lines()
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	hints_used += 1
	var arrivals := _transition(before, [target], now, 0.0, true)
	# A hint's pebbles are their own entry: the hint itself leaves none, and
	# they must not ride on whatever stroke came last.
	_auto_pebbles(arrivals, ok_before, true)
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
	if is_done() or out_of_hearts or _ejecting:
		return 0
	checks += 1
	var t := _now()
	# On Hard and Insane no wrong tile ever stays down, so Check looks at the
	# pebbles instead: one on a cell the picture wants blushes its socket
	# and shivers.
	var pebbles := state.judged()
	var wrong: Array = state.wrong_pebbles() if pebbles else state.wrong_tiles()
	if not Motion.reduce and not wrong.is_empty():
		for cell in wrong:
			_wrong[cell] = t
			if pebbles:
				_shiver[cell] = t
		_busy_for(maxf(Motion.WOBBLE_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
	if pebbles:
		_say((tr("NG_PEBBLE_ONE") if wrong.size() == 1 else tr("NG_PEBBLE_N")) % wrong.size()
			if not wrong.is_empty() else tr("NG_PEBBLES_RIGHT"),
			Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
	else:
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
	if out_of_hearts or _ejecting:
		return
	_clear_floor()
	# A cleared floor is the board from the top, so the moves come back too.
	moves_left = max_moves
	_heart_layer.queue_redraw()
	_break_streak()
	_say(tr("NG_RESET"),
		Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

## Every tile and pebble goes in Reset's wave. Reset and Try again share it.
func _clear_floor() -> void:
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
	_bad = {}
	_verdicts(now, {})
	moves = 0
	_running = true

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
	_frame_at = t - 10.0
	_anim_until = 0.0
	_say(_looks(), Face.Expr.JOY)
	# A restore keeps the seal on Insane: the day was won there.
	if state.band == 3:
		_stamp_at = t - 10.0
		_life_layer.queue_redraw()
	_refresh()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	if state.band == 3:
		out += "🌙 " + (tr("NG_LEAF_SEAL") if state.has_leaves() else tr("BN_INSANE_SEAL")) + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += "🏅 " + tr("BN_FLAWLESS")
	return out

# --- the win ---

## The board *is* the reward here, more than on any other screen, so the
## reveal is the win: the win screen shows no cast, and what stays on the card
## under it is the picture as a single shape.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("NG_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

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
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 or max_moves > 0 else checks == 0)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = now
		_combo_layer.queue_redraw()
	for k in state.h + state.w:
		if _line_state(k) == State.LINE_OK and not bool(_bloom.get(_key(k), {}).get("open", false)):
			_bloom[_key(k)] = {"at": now, "open": true}
	_party()
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

# --- the third polish: the floor's new pieces ---

## A leaf under each tumbled number (Leaf Fall), in the line's own frame so
## it pops, bumps and flutters with the number it carries. They leave with
## the rest of the scaffolding on the win.
func _leaves(gone: float, t: float) -> void:
	if not state.has_leaves():
		return
	var alpha := 1.0 - gone
	if alpha <= 0.0:
		return
	for k in state.h + state.w:
		if not _tumbled(k):
			continue
		var index: int = k if k < state.h else k - state.h
		var scale := _clue_scale(_key(k), index, t)
		if scale.x <= 0.0:
			continue
		_open_run(PART_LEAF, k)
		var xf := _line_xf(k, scale, t)
		var i := 0
		for n in _numbers(k, t):
			var h := _hash(Vector2i(k * 5 + 1, i * 3 + 2))
			var tint: Color = Pal.AUTUMN_LEAVES[int(h * 97.0) % Pal.AUTUMN_LEAVES.size()]
			_put(SHAPE_LEAF, [Color(tint.lerp(Pal.SURFACE, LEAF_WASH), alpha),
				Color(tint.lerp(Pal.SURFACE, LEAF_WASH * 0.5), alpha * 0.8)],
				xf * Transform2D(float(n.rot), n.at) * Transform2D(-0.55, Vector2(0.0, _cell * LEAF_DOWN)))
			i += 1

## A leaf `len` long and `wide` across, pointed at both ends, about the
## origin along x.
static func _leaf_shape(len: float, wide: float) -> PackedVector2Array:
	const STEPS := 9
	var pts := PackedVector2Array()
	for k in STEPS + 1:
		var u := float(k) / STEPS
		pts.append(Vector2((u - 0.5) * len, -sin(u * PI) * wide * 0.5 * (1.0 - 0.25 * u)))
	for k in range(STEPS - 1, 0, -1):
		var u := float(k) / STEPS
		pts.append(Vector2((u - 0.5) * len, sin(u * PI) * wide * 0.5 * (1.0 - 0.25 * u)))
	return pts

## The daisies at the outer end of every tab whose line reads right: they
## open with a twist, fold when the line stops being right, and let their
## petals go at the party.
func _daisies(t: float) -> void:
	for line in state.h + state.w:
		var key := _key(line)
		if not _bloom.has(key):
			continue
		var d: Dictionary = _bloom[key]
		var e: float = t - float(d.at)
		var k := 0.0
		if bool(d.open):
			if Motion.reduce or e >= DAISY_TIME:
				k = 1.0
			elif e > 0.0:
				k = Motion.back_out(e / DAISY_TIME)
		elif not Motion.reduce and e < DAISY_FOLD:
			k = 1.0 - clampf(e / DAISY_FOLD, 0.0, 1.0)
		if _frame_at != INF and not Motion.reduce:
			# The petals have gone to the party.
			k *= 1.0 - clampf((t - _frame_at) / 0.3, 0.0, 1.0)
		if k <= 0.01:
			continue
		var i := int(key.substr(1))
		var at: Vector2
		if key.begins_with("r"):
			at = Vector2(_grid.x - _band.x, _grid.y + (i + 0.5) * _cell)
		else:
			at = Vector2(_grid.x + (i + 0.5) * _cell, _grid.y - _band.y)
		_open_run(PART_DAISY, line)
		_put(SHAPE_DAISY, DAISY_INKS, Transform2D((1.0 - minf(k, 1.0)) * 1.2 + _hash(Vector2i(i, key.length())) * TAU,
			Vector2.ONE * k, 0.0, at))

## One daisy of radius `r` about `at`, turned `turn`, in `inks` (petal edge,
## petal, heart).
func _daisy(b, at: Vector2, r: float, turn: float, inks: Array = DAISY_INKS) -> void:
	for p in DAISY_PETALS:
		var a := turn + TAU * p / DAISY_PETALS
		var dir := Vector2.from_angle(a)
		b.fan(_oval(at + dir * r * 0.55, r * 0.5, r * 0.26, a), inks[0])
		b.fan(_oval(at + dir * r * 0.55, r * 0.44, r * 0.2, a), inks[1])
	b.fan(Face.Builder.ring(at, r * 0.3, r * 0.3), inks[2])

static func _oval(at: Vector2, rx: float, ry: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts

## The wrong tiles on Hard and Insane, before they are taken back: they pop
## in like any tile, blushing, and wobble.
func _build_bad(t: float) -> void:
	for cell in _bad:
		var at: float = _bad[cell]
		if t < at and not Motion.reduce:
			continue
		var e := t - at
		var grow := Motion.pop_in_scale(e) * _sink(cell, t)
		if grow.x <= 0.0 or grow.y <= 0.0:
			continue
		_put_tile(0.0, Mosaic.tile_colours(false, 0.0, 1.0, maxf(0.75, Motion.flash_level(e)), _tone(cell)),
			Transform2D(Motion.wobble_angle(e), grow, 0.0, cell_to_local(cell.y, cell.x) + _offset(cell, t)))

## The frame hung round the finished picture: wood a FRAME_W of a cell wide,
## FRAME_OUT clear of the tiles, with a darker lip inside and a brass nail at
## each corner. It pops in wide about the picture's middle.
func _frame(b, t: float) -> void:
	if _frame_at == INF or t < _frame_at:
		return
	var grow := 1.0 if Motion.reduce else Motion.wide_pop_scale(t - _frame_at)
	if grow <= 0.0:
		return
	var field := Rect2(_grid, Vector2(state.w, state.h) * _cell)
	var c := field.get_center()
	var out := _cell * FRAME_OUT
	var wide := _cell * FRAME_W
	var inner := field.grow(out)
	var outer := inner.grow(wide)
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, c * (1.0 - grow))
	var r := wide * 0.6
	# A soft shadow under it, then the wood as four rails.
	Scenery.soft_disc(b, xf * (c + Vector2(0.0, outer.size.y * 0.5 + wide * 0.6)), outer.size.x * 0.5 * grow,
		wide * 0.8 * grow, Color(Pal.TEXT, 0.12))
	for rail in [Rect2(outer.position, Vector2(outer.size.x, wide)),
			Rect2(Vector2(outer.position.x, inner.end.y), Vector2(outer.size.x, wide)),
			Rect2(outer.position, Vector2(wide, outer.size.y)),
			Rect2(Vector2(inner.end.x, outer.position.y), Vector2(wide, outer.size.y))]:
		b.fan(xf * Face.Builder.round_rect(rail.position, rail.size, r * 0.5), Pal.WOOD)
	for rail in [Rect2(inner.position - Vector2.ONE * wide * 0.25, Vector2(inner.size.x + wide * 0.5, wide * 0.25)),
			Rect2(inner.position - Vector2.ONE * wide * 0.25, Vector2(wide * 0.25, inner.size.y + wide * 0.5))]:
		b.fan(xf * Face.Builder.round_rect(rail.position, rail.size, 1.0), Pal.WOOD_DEEP)
	for corner in [outer.position, Vector2(outer.end.x, outer.position.y),
			Vector2(outer.position.x, outer.end.y), outer.end]:
		var toward: Vector2 = (c - corner).normalized() * wide * 0.7
		b.fan(Face.Builder.ring(xf * (corner + toward), wide * 0.22 * grow, wide * 0.22 * grow), Pal.SUN_TILE.darkened(0.25))

# --- judging a stroke ---

## A stroke with nothing wrong in it: on Hard and Insane one that laid a
## tile (each is judged as it lands); on Easy and Medium one that brought a
## line to read right and left none over-filled, which the board already
## shows. It builds the streak and may play a gag. Neutral strokes (pebbles,
## a rub-out) leave the streak as it is; an over-filling one ends it.
func _judge_stroke(before: Dictionary, changed: Array, arrivals: Dictionary, settled: int,
		ok_before: Dictionary) -> void:
	_auto_pebbles(arrivals, ok_before)
	if state.is_solved():
		return
	var laid := false
	for cell in changed:
		if state.mark_at(cell) == State.FILL and int(before.get(cell, State.BLANK)) != State.FILL:
			laid = true
	var right := false
	if state.judged():
		right = laid
	elif state.over_lines() > 0:
		_break_streak()
		return
	else:
		right = laid and state.settled_lines() > settled
	if not right:
		return
	var last: Vector2i = changed[-1]
	var land := 0.0
	for cell in arrivals:
		land = maxf(land, float(arrivals[cell]) - _now())
	_on_right_stroke(changed, last, land)

## On Hard and Insane, a line that has just come out right lays a pebble in
## each of its empty cells, rippling out from where the stroke touched it:
## every tile there was judged, so a line reading right is finished.
func _auto_pebbles(arrivals: Dictionary, ok_before: Dictionary, own_entry := false,
		skip := Vector2i(-1, -1)) -> void:
	if not state.judged() or arrivals.is_empty() or state.is_solved():
		return
	var cells: Array = []
	var when: Dictionary = {}
	for k in state.h + state.w:
		# Only a line this move brought to read right: one that already did
		# (an empty line does from the start) keeps whatever the player
		# rubs out of it.
		if _line_state(k) != State.LINE_OK or ok_before.has(k):
			continue
		var y: int = k if k < state.h else -1
		var x: int = -1 if k < state.h else k - state.h
		# Only a line this move touched.
		var from := Vector2i(-1, -1)
		var at := -1.0
		for cell in arrivals:
			if (y >= 0 and cell.y == y) or (y < 0 and cell.x == x):
				if float(arrivals[cell]) > at:
					at = float(arrivals[cell])
					from = cell
		if from.x < 0:
			continue
		for cell in state.blanks_in(y, x):
			if when.has(cell) or cell == skip:
				continue
			var d: int = absi(cell.x - from.x) + absi(cell.y - from.y)
			when[cell] = at + Motion.POP_IN * 0.5 + (0.0 if Motion.reduce else d * AUTO_STEP)
			cells.append({"cell": cell, "to": State.MARK})
	if cells.is_empty():
		return
	var changed: Array = state.apply(cells) if own_entry else state.apply_more(cells)
	var first := INF
	for cell in changed:
		_arrive[cell] = {"at": float(when[cell]), "drop": false}
		first = minf(first, float(when[cell]))
		_busy_for(float(when[cell]) - _now() + Motion.POP_IN)
	if not changed.is_empty():
		_after(first - _now(), fx.cue.bind("pebbles"))

## The lines reading right now, as a set of line indices (rows, then columns).
func _ok_lines() -> Dictionary:
	var out: Dictionary = {}
	for k in state.h + state.w:
		if _line_state(k) == State.LINE_OK:
			out[k] = true
	return out

## The streak (the combo pitched up the pentatonic from the second, the
## bubble from the third, confetti at five and ten) and a gag now and then.
func _on_right_stroke(cells: Array, last: Vector2i, land: float) -> void:
	_streak += 1
	if _streak >= 2:
		var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
		_after(land, fx.cue.bind("combo", pow(2.0, step / 12.0), COMBO_DB))
	if _streak >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _streak
		_combo_cell = last
		_combo_at = _now()
		_combo_out_at = -INF
		_combo_layer.queue_redraw()
	if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
		_after(land, func() -> void:
			fx.confetti(cell_to_local(last.y, last.x), 22)
			fx.cue("confetti"))
	_gag(cells, last, land)

## The streak ends: an over-filled line, a wrong tile, an undo, a reset, the
## hearts running out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
		if _combo_layer != null:
			_combo_layer.queue_redraw()
	else:
		_combo_n = 0

# --- failing ---

## `cost` moves go off Insane's counter. The last one gone with the picture
## unfinished ends the board once the stroke has landed (`land`).
func _spend(cost: int, land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_moves_pill.bump(_now())
	_heart_layer.queue_redraw()
	if moves_left > 0 or is_done() or state.is_solved():
		return
	_lost_ever = true
	out_of_hearts = true
	_running = false
	_after(maxf(0.0, land - _now()) + (0.0 if Motion.reduce else Motion.DROP_TIME), _run_out)

## A tile the picture does not want, on Hard or Insane: it lands like any
## other, blushing, a heart goes (its halves fall), and EJECT_AFTER later the
## tile turns out of its socket and a pebble drops in where it was, for good.
func _wrong_tile(cell: Vector2i, land: float) -> void:
	if hearts <= 0 or is_done():
		return
	var now := _now()
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_split_index = hearts
	_split_at = land
	_ejecting = true
	if hearts <= 0:
		out_of_hearts = true
		_running = false
	_bad[cell] = land
	_wrong[cell] = land
	_sink_cell(cell)
	var wait := land - now
	_after(wait, func() -> void:
		_heart_layer.queue_redraw()
		fx.cue("place")
		fx.cue("heart_lost")
		if not Motion.reduce:
			fx.puff(cell_to_local(cell.y, cell.x), Pal.BAD, 4)
		_say(tr("NG_WRONG_TILE"), Face.Expr.WORRIED)
		_refresh())
	_busy_for(wait + EJECT_AFTER + Motion.DROP_TIME)
	moved.emit()
	_after(wait + (0.0 if Motion.reduce else EJECT_AFTER), _eject.bind(cell))

## The wrong tile is taken back: it turns out of its socket, and a pebble
## drops in where it was and stays -- the heart has shown the cell empty.
func _eject(cell: Vector2i) -> void:
	_ejecting = false
	if is_done() or not _bad.has(cell):
		return
	var now := _now()
	_bad.erase(cell)
	_wrong.erase(cell)
	_leave(cell, State.FILL, now)
	var before: Dictionary = state.marks.duplicate()
	state.reveal(cell)
	_arrive[cell] = {"at": now + (0.0 if Motion.reduce else Motion.POP_OUT * 0.6), "drop": true}
	_busy_for(Motion.POP_OUT + Motion.DROP_TIME)
	_verdicts(now, {})
	fx.cue("slip")
	if before.get(cell, State.BLANK) != State.MARK and not Motion.reduce:
		_after(Motion.POP_OUT * 0.6 + Motion.DROP_TIME * 0.6,
			fx.puff.bind(cell_to_local(cell.y, cell.x), Pal.BARK, 4))
	moved.emit()
	_refresh()
	if out_of_hearts:
		_after(0.0 if Motion.reduce else Motion.DROP_TIME, _run_out)
	else:
		_after(0.0 if Motion.reduce else Motion.DROP_TIME, _speak)

## The last heart is gone: the floor slips to dusk, the sprout dozes off,
## and the card comes up.
func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_end_sinks(_now())
	_clear_gesture()
	_break_streak()
	fx.cue("out_of_hearts")
	_say(tr("NG_OUT"), Face.Expr.SLEEPY)
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
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, [], MOVES_BONUS) if max_moves > 0 \
		else load(OUT_OF_HEARTS).new(_heart_used, ["NG_OUT_BODY", "NG_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same picture from the top, every heart back, the day's
## light, the clock and the moves from zero; hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	elapsed = 0.0
	checks = 0
	_clear_floor()
	_deal()
	# _deal() puts the light back at once; hold the dusk so it fades.
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()
	_refresh()

## One more heart (the card's video): once a board. The light comes back.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	if max_moves > 0:
		moves_left = MOVES_BONUS
		_moves_pill.bump(_now())
	else:
		hearts = 1
		_back_index = 0
		_back_at = _now()
	_heart_layer.queue_redraw()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_speak()
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

# --- the hearts ---

## The hearts over the floor as one mesh on a paper pill (One Line's): pink
## with a small face and a leaf, a faint ghost where one was, the lost one's
## halves falling apart, and one coming back popping in.
func _draw_hearts() -> void:
	if max_moves > 0 and _cell > 0.0:
		_moves_pill.draw(_heart_layer, Vector2(size.x * 0.5, _card.position.y + 12.0 + HEART_ROW * 0.5),
			moves_left, _now())
		return
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

## The streak's paper bubble at the upper right of the stroke's last cell,
## "x3" and up in ink: it pops in the first time, bumps at each stroke and
## deflates when the streak ends (One Line's).
func _draw_combo() -> void:
	if _combo_n < COMBO_FROM or _cell <= 0.0:
		return
	var now := _now()
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

# --- gags and the life over the floor ---

## A right stroke now and then plays a gag, picked by its last cell's hash so
## a picture replays the same: little hearts float up off the tiles just
## laid; a mushroom pops up out of a pebble nearby and grins; or the queen
## bee from Queens zooms along the line. Under reduce-motion, none.
func _gag(cells: Array, last: Vector2i, land: float) -> void:
	if Motion.reduce or is_done():
		return
	var roll := posmod(hash(Vector2i(last.x * 13 + 7, last.y * 5 + _streak)), GAG_ODDS)
	if roll >= GAGS:
		return
	if roll == 1 and not _pop_mushroom(last, land):
		roll = 0
	match roll:
		0:
			var tiles: Array = []
			for cell in cells:
				if state.mark_at(cell) == State.FILL:
					tiles.append(cell)
			if tiles.is_empty():
				tiles = [last]
			var now := _now() + land
			for k in LOVE_HEARTS:
				var cell: Vector2i = tiles[mini(tiles.size() - 1, k * tiles.size() / LOVE_HEARTS)]
				_love.append({"at": cell_to_local(cell.y, cell.x), "t": now + k * 0.08,
					"phase": _hash(cell + Vector2i(k, 7)) * TAU})
			_after(land, fx.cue.bind("love"))
		2:
			_fly_bee(cells, last, land)

## The mushroom pops up out of the ruled-out cell nearest `near`, grins, and
## sinks back after MUSH_HOLD. False when there is no pebble to grow from.
func _pop_mushroom(near: Vector2i, land: float) -> bool:
	var best := Vector2i(-1, -1)
	var far := 1 << 30
	for cell in state.marks:
		if int(state.marks[cell]) != State.MARK:
			continue
		var d: int = absi(cell.x - near.x) + absi(cell.y - near.y)
		if d < far:
			far = d
			best = cell
	if best.x < 0 or far > 4:
		return false
	var at := cell_to_local(best.y, best.x) - Vector2(0.0, _cell * 0.18)
	Motion.stop(_mush_tw)
	_mushroom.position = at - _mushroom.size * 0.5
	_mushroom.expression = Face.Expr.JOY
	_mushroom.visible = true
	_mushroom.scale = Vector2.ZERO
	_mush_tw = Motion.pop_in(_mushroom, Motion.POP_IN, land)
	_after(land, fx.cue.bind("mushroom"))
	_after(land + MUSH_HOLD, func() -> void:
		Motion.stop(_mush_tw)
		_mush_tw = Motion.pop_out(_mushroom)
		_after(Motion.POP_OUT, func() -> void: _mushroom.visible = false))
	return true

## The queen bee zooms along the stroke's line, from off the floor on one
## side to off it on the other, bobbing.
func _fly_bee(cells: Array, last: Vector2i, land: float) -> void:
	var first: Vector2i = cells[0]
	var across := first.y == last.y or cells.size() == 1
	var dir := 1.0 if (last.x >= first.x if across else last.y >= first.y) else -1.0
	var from: Vector2
	var to: Vector2
	if across:
		var y := cell_to_local(last.y, 0).y - _cell * 0.3
		from = Vector2(_grid.x - _cell if dir > 0 else _grid.x + (state.w + 1) * _cell, y)
		to = Vector2(_grid.x + (state.w + 1) * _cell if dir > 0 else _grid.x - _cell, y)
	else:
		var x := cell_to_local(0, last.x).x + _cell * 0.3
		from = Vector2(x, _grid.y + (state.h + 1) * _cell if dir < 0 else _grid.y - _cell)
		to = Vector2(x, _grid.y - _cell if dir < 0 else _grid.y + (state.h + 1) * _cell)
	Motion.stop(_bee_tw)
	_bee.visible = true
	_bee.set_idle(true)
	_bee.position = from - _bee.size * 0.5
	_bee.scale = Vector2(-1.0 if (to - from).x < 0.0 else 1.0, 1.0)
	_bee.modulate.a = 0.0
	_bee_tw = create_tween()
	_bee_tw.tween_interval(land)
	_bee_tw.tween_property(_bee, "modulate:a", 1.0, 0.12)
	_bee_tw.parallel().tween_method(func(u: float) -> void:
		var at := from.lerp(to, u) + Vector2(0.0, sin(u * TAU * 2.0) * _cell * BEE_BOB)
		_bee.position = at - _bee.size * 0.5, 0.0, 1.0, BEE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bee_tw.tween_callback(func() -> void: _bee.visible = false)
	_after(land, fx.cue.bind("bee"))

## Keeps the life layer drawing while anything on it moves.
func _tick_life(now: float) -> bool:
	var still: Array = []
	for l in _love:
		if now < float(l.t) + LOVE_TIME:
			still.append(l)
	_love = still
	still = []
	for p in _petals:
		if now < float(p.t) + PETAL_TIME:
			still.append(p)
	_petals = still
	still = []
	for p in _falling:
		if now < float(p.t) + LEAF_TIME:
			still.append(p)
	_falling = still
	return not _love.is_empty() or not _petals.is_empty() or not _falling.is_empty() \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## The life over the floor: love hearts floating off a stroke, and petals
## and leaves falling at the party, each group one mesh; and the seal after
## the solve, with its words.
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
	if not _petals.is_empty() or not _falling.is_empty():
		# Every petal and leaf in one mesh, rebuilt while they fall: one draw
		# call for the whole shower.
		var pb := Face.Builder.new()
		var r := _cell * DAISY_R
		for p in _petals:
			var e: float = now - float(p.t)
			if e <= 0.0:
				continue
			var u := e / PETAL_TIME
			var v: Vector2 = p.v
			var at: Vector2 = p.at + v * _cell * u + Vector2(sin(e * 4.0 + float(p.phase)) * 0.12 * _cell,
				PETAL_FALL * _cell * u * u)
			var spin: float = float(p.phase) + e * float(p.spin)
			var flat := absf(cos(e * 5.0 + float(p.phase))) * 0.7 + 0.3
			var fade := clampf((1.0 - u) / 0.35, 0.0, 1.0)
			pb.fan(_oval(at, r * 0.5, r * 0.26 * flat, spin), Color(Pal.PETAL_EDGE, fade))
			pb.fan(_oval(at, r * 0.44, r * 0.2 * flat, spin), Color(Pal.SURFACE, fade))
		for p in _falling:
			var e: float = now - float(p.t)
			if e <= 0.0:
				continue
			var u := e / LEAF_TIME
			var at: Vector2 = p.at + Vector2(sin(e * 2.2 + float(p.phase)) * 0.5 * _cell,
				float(p.fall) * u)
			var flat := absf(cos(e * 3.0 + float(p.phase))) * 0.6 + 0.4
			var fade := clampf((1.0 - u) / 0.3, 0.0, 1.0)
			var xf := Transform2D(float(p.phase) + e * float(p.spin), Vector2(1.0, flat), 0.0, at)
			pb.fan(xf * _leaf_shape(_cell * LEAF_LEN * 0.8, _cell * LEAF_WIDE * 0.8), Color(p.tint, fade))
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

## After the reveal: the picture is hung in a frame, every daisy lets its
## petals go, confetti sweeps the floor twice, on Insane the leaves come
## down, the seal stamps when the solve earned one (flawless, or any Insane
## picture), and the sprout says what the picture looks like to it. Under
## reduce-motion only the frame and the seal, standing still.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else PARTY_AT
	_frame_at = now + lead
	_after(lead, func() -> void:
		fx.cue("frame")
		_say(_looks(), Face.Expr.JOY))
	if _flawless or state.band == 3:
		_stamp_at = now if Motion.reduce else now + lead + FRAME_TIME + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		return
	_busy_for(lead + FRAME_TIME + 0.4)
	var field := Rect2(_grid, Vector2(state.w, state.h) * _cell)
	_after(lead + 0.15, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell * 0.3), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.6, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	var any := false
	for key in _bloom:
		if not bool(_bloom[key].open):
			continue
		any = true
		var i := int((key as String).substr(1))
		var at := Vector2(_grid.x - _band.x, _grid.y + (i + 0.5) * _cell) if (key as String).begins_with("r") \
			else Vector2(_grid.x + (i + 0.5) * _cell, _grid.y - _band.y)
		for k in PETALS:
			var a := _hash(Vector2i(i * 11 + k, key.length())) * TAU
			_petals.append({"at": at, "t": now + lead + k * 0.03 + i * 0.02, "v": Vector2.from_angle(a) * 0.6,
				"phase": a, "spin": lerpf(-4.0, 4.0, _hash(Vector2i(k, i)))})
	if any:
		_after(lead, fx.cue.bind("petals"))
	if state.has_leaves():
		for k in LEAVES:
			var hx := _hash(Vector2i(k, 91))
			_falling.append({"at": Vector2(lerpf(field.position.x - _cell, field.end.x + _cell, hx),
				_card.position.y - _cell * (0.5 + _hash(Vector2i(k, 3)))), "t": now + lead + 0.3 + k * 0.05,
				"phase": hx * TAU, "spin": lerpf(-2.0, 2.0, _hash(Vector2i(3, k))),
				"fall": _card.size.y + _cell * 2.0,
				"tint": Pal.AUTUMN_LEAVES[k % Pal.AUTUMN_LEAVES.size()]})
		_after(lead + 0.3, fx.cue.bind("leaves"))

## What the sprout thinks the finished picture looks like: one of LOOKS
## silly guesses, picked by the picture itself, so a day always gets the
## same one.
func _looks() -> String:
	var bits := ""
	for row in state.bitmap:
		for v in row:
			bits += str(v)
	return tr("NG_LOOKS_%d" % posmod(hash(bits), LOOKS))

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
			[tr("BN_FLAWLESS") if _flawless else (tr("NG_LEAF_SEAL") if state.has_leaves() else ""), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

## Runs `what` after `delay` seconds unless the board has been dealt again
## since.
func _after(delay: float, what: Callable) -> void:
	if delay <= 0.0:
		what.call()
		return
	var gen := _gen
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())
