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
##
## The polish of 2026-09-30 (docs/superpowers/specs/2026-09-30-tents-polish-design.md)
## added hearts on Hard and Insane (a fair tent that is not the answer's
## wilts and is struck), Insane's Old Oaks with hidden counts, trees that
## beam once they have their tents, lamp-lit right tents, the streak, gags,
## butterflies, the seal and a party with hats and bunting.

const State = preload("res://puzzles/tents_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const TentFace = preload("res://ui/faces/tent_face.gd")
const ConiferFace = preload("res://ui/faces/conifer_face.gd")
const CountChip = preload("res://ui/faces/count_chip.gd")
const OakFace = preload("res://ui/faces/oak_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"

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

# --- the polish of 2026-09-30 (docs/superpowers/specs/2026-09-30-tents-polish-design.md) ---
## The hearts' strip over the counts, on Hard and Insane only; Shikaku's pill.
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
## A wrong tent sags under a worried face, then is struck.
const WILT_LAG := 0.2
const EJECT_AFTER := 0.75
const SLEEP_STAGGER := 0.05
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## The streak: right tents in a row, a pentatonic step each from the second.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
## The bubble shows its number this long, then deflates on its own; the
## streak itself runs on, and the next right move pops it back in.
const COMBO_HOLD := 1.2
const COMBO_FONT := 44
## Gags: three of every five right tents, by the square's own hash.
const GAG_ODDS := 5
const GAGS := 3
const GAG_AT := 0.35
const PEEK_TIME := 1.6
const PEEK_RISE := 0.28
const GLASSES_IN := 0.28
const GLASSES_HOLD := 0.9
const GLASSES_OUT := 0.2
const BUNNY_TIME := 1.3
const BUNNY_HOPS := 3
const BUNNY_SIZE := 0.26
## A tree that has just got the tents it wants gives a little hop.
const CHEER_HOP := -5.0
## Trees and tents within this many squares of the finger look at it.
const GLANCE_REACH := 2
## Butterflies perch on happy trees and lit tents.
const BUTTERFLY_SECOND := 0.4
const BUTTERFLY_SPEED := 1.6
const BUTTERFLY_PERCH := 2.0
const BUTTERFLY_JITTER := 2.5
const BUTTERFLY_SIZE := 0.2
const BUTTERFLY_PARTY := 4
const FLIES_STAY := 5.0
const BUTTERFLY_WINGS := [Pal.FLOWER, Pal.SUN_RAY, Pal.CLOUD, Pal.SHADOW_TINT]
## The seal, the party and its bunting.
const STAMP_AT := 0.35
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.14
const STAMP_TILT := -0.22
const PARTY_AT := 0.15
const PARTY_HAT := 0.3
const PARTY_HAT_STAGGER := 0.03
const PARTY_EXTRA := 1.1
const BUNTING_TIME := 0.6
const BUNTING_FLAGS := 11
const BUNTING_SAG := 0.28
const BUNTING_COLOURS := [Pal.FLOWER, Pal.SUN, Pal.LEAF, Pal.MOON_DEEP, Pal.TENT_CANVAS]
## The sweep ticks up a little per square, as Shikaku's drag does.
const SWEEP_PITCH := 0.04
const SWEEP_PITCH_MAX := 1.6

## The parts of the ground baked while they stand still (see _rest_parts).
enum RestPart { CAIRN, TREE_SHADOW, TENT_SHADOW, LAMP }

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
const TIPS := [
	"TN_TIP_BESIDE",
	"TN_TIP_CAIRNS",
	"TN_TIP_NUMBERS",
]

var state = State.new()
## Back to camp from the out-of-hearts card; the host listens for it.
signal leave
## The names the win harness and the island board share.
var w: int:
	get: return state.w
var h: int:
	get: return state.h
var _solution_tents: Array:
	get: return state.solution

var fx: Node2D
## Hearts (Hard 3, Insane 1) and failing.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _flawless := false
var _asleep := false
var _ejecting := false
var _heart_card: Control
var _split_index := -1
var _split_at := -INF
var _back_index := -1
var _back_at := -INF
## The tents wilting while a heart goes: Vector2i -> true.
var _wilting: Dictionary = {}
## The tents a tap was judged right on (or a hint pitched): Vector2i -> true.
## Only these light their lamp. A tent that turns fair some other way -- a
## neighbour taken off, an undo -- was never charged for, so lighting it would
## tell the player for free what a heart is meant to cost.
var _judged: Dictionary = {}
## The streak and its bubble.
var _streak := 0
var _combo_n := 0
var _combo_cell := Vector2i.ZERO
var _combo_at := -INF
var _combo_popped := false
var _combo_out_at := -INF
## The gags and the life on the meadow.
var _peek: Dictionary = {}
var _bunny: Dictionary = {}
var _flies: Array = []
var _stamp_at := INF
var _bunting_at := INF
var _seal_mesh: ArrayMesh
var _heart_layer: Control
var _combo_layer: Control
var _life_layer: Control
var _hearts_shown: ArrayMesh
var _combo_shown: ArrayMesh
var _life_shown: Array = []
var _sweep_n := 0
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
## The checkup (2026-10-01): a full Insane meadow carries some seventy
## cairns, and rebuilding every one of them with every shadow cost ~28 ms a
## frame for as long as anything on the ground moved -- every tap, every
## sweep. Now each part that stands still on a square (a cairn, a tree's or
## a tent's shadow, a lit tent's pool) is made once a square (`_rest_parts`,
## Vector3i(kind, x, y) -> ArrayMesh) and every one at rest is baked into
## `_still` with native copies (Face.FlatBuilder over `_flat_cache`), made
## again only when that set changes (`_still_key`). `_ground` keeps only
## what moves; `_under` is the shade and the blush, which lie under the
## cairns; `_sinking` the cairns the win takes into the turf, each its
## standing mesh under a transform.
## The checkup (2026-10-01): every tree, tent and chip drew itself, a
## canvas command a layer and one more for a chip's numeral -- about a
## hundred of a full Insane meadow's 182 draw calls. The faces still move as
## ever (pops, hops, sways, blinks and expressions are theirs) but draw only
## their hats and glasses: `_cast`, under them, draws every body in one
## MultiMesh per mesh on show (a meadow shows a handful of expressions and
## eye levels at once, not sixty) and every numeral in one run of glyphs.
## `_sync_cast` copies their transforms in every frame, since the trees
## always sway, and hands a buffer over only when it changed.
var _cast: Control
var _cast_mm: Dictionary = {}     # ArrayMesh -> MultiMesh, the meshes on show
var _cast_order: Array = []       # the meshes on show, in drawing order
var _cast_sent: Dictionary = {}   # MultiMesh -> the buffer last handed over
var _numerals: Array = []         # [Transform2D, baseline, text, px, colour]
var _rest_parts: Dictionary = {}
var _flat_cache: Dictionary = {}
var _still: ArrayMesh
var _still_key := 0
var _under: ArrayMesh
var _sinking: Array = []          # [[mesh, xf, tint]]
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
	var out := tr("TN_RULES")
	if state.has_oaks():
		out += "\n\n" + tr("TN_RULES_OAK")
	if max_hearts > 0:
		out += "\n\n" + (tr("TN_RULES_HEARTS_1") if max_hearts == 1 else tr("TN_RULES_HEARTS_N") % max_hearts)
	return out

## The lines the sprout cycles: an oak meadow leads with its oaks.
func _tips() -> Array:
	var out: Array = TIPS
	if state.has_oaks():
		out = ["TN_TIP_OAK", "TN_TIP_HIDDEN"] + out
	return out

## The tutorial (board checkup, 2026-10-01), four to six pages, each a small
## meadow the board itself plays (ui/hud/tents_tutorial_diagram.gd): beside
## a tree, never touching, the line counts and the sweep, the hint, then
## hearts on Hard and Insane and the old oaks on Insane. Loaded, not
## preloaded: the page's meadow extends this script.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/tents_tutorial_diagram.gd")
	var hints: int = State.HINTS_BY_BAND[clampi(state.band, 0, 3)]
	var steps := [
		[Diagram.Lesson.PITCH, "HTP_TN_PITCH", tr("HTP_TN_PITCH_BODY")],
		[Diagram.Lesson.TOUCH, "HTP_TN_TOUCH", tr("HTP_TN_TOUCH_BODY")],
		[Diagram.Lesson.LINES, "HTP_TN_LINES", tr("HTP_TN_LINES_BODY")],
		[Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_TN_HINT_BODY_ONE") if hints == 1 else tr("HTP_TN_HINT_BODY_N") % hints]]
	if max_hearts > 0:
		steps.append([Diagram.Lesson.HEARTS, "HTP_TN_HEARTS",
			tr("TN_RULES_HEARTS_1") if max_hearts == 1 else tr("TN_RULES_HEARTS_N") % max_hearts])
	if state.has_oaks():
		steps.append([Diagram.Lesson.OAK, "HTP_TN_OAK", tr("TN_RULES_OAK")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.hearts = maxi(1, max_hearts)
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Undo, Hint and Check on every band; Reset is the host's.
func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

## What the phone does under each cue (docs/agents/haptics.md). A tent
## pitched is the faintest knock, fair or not (its face and the chips say
## that), and one struck or undone fainter still; an oak given its second
## tent and the streak's confetti are the milestones. The sweep's `cairn`
## and `clear` fire a square and are not here: a row of them would hum, so
## the sweep ticks once as it is let go (`_release`). A tree or a pegged
## tent tapped, the trees' hops, the streak's pluck and the gags say
## nothing. The seal thuds as it lands (`_party`).
const HAPTICS := {
	"strike": Haptics.TICK,
	"undo": Haptics.TICK,
	"place": Haptics.TAP,
	"reset": Haptics.TAP,
	"oak": Haptics.BUMP,
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
	_life_layer = _layer("Life", 1, _draw_life)
	_heart_layer = _layer("Hearts", 1, _draw_hearts)
	_combo_layer = _layer("Combo", 2, _draw_combo)
	# Before the slots, so the bodies draw where the faces stand and their
	# hats over them.
	_cast = _layer("Cast", 0, _draw_cast)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

## A full-rect layer over the pieces, drawn by `draw`.
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
	_solved_at = -1.0
	_build_pieces()
	_layout()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

## The meadow as it is dealt, and as Try again deals it back: every heart,
## nothing on the ground, nothing in flight.
func _deal() -> void:
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_ejecting = false
	_flawless = false
	_split_index = -1
	_back_index = -1
	_wilting = {}
	_judged = {}
	_cairn_in = {}
	_cairn_out = []
	_blush = {}
	_shade = {}
	_streak = 0
	_combo_n = 0
	_combo_out_at = -INF
	_peek = {}
	_bunny = {}
	_flies = []
	_stamp_at = INF
	_bunting_at = INF
	_clear_gesture()
	for layer: Control in [_heart_layer, _combo_layer, _life_layer]:
		if layer != null:
			layer.queue_redraw()

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
		var tree: ConiferFace = OakFace.new() if state.oaks.has(cell) else ConiferFace.new()
		# The shadow is the board's, on the ground (see _build_ground).
		tree.casts = false
		tree.skip_layers = ["body"]
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
	chip.skip_layers = ["card", "numeral"]
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
	tent.skip_layers = ["ground", "body"]
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
		if _solved_at >= 0.0 or _wilting.has(cell):
			continue
		_set_expr(tent, _tent_expr(cell))
	if _solved_at >= 0.0:
		return
	for cell in _trees:
		_set_expr(_trees[cell], _tree_expr(cell))

## A tent's look: asleep with the camp, rose in trouble, lamp-lit (JOY) on a
## board with hearts once a tap on it was judged right and the board can
## still fault nothing about it -- the judging is what a heart pays for, so
## the lamp tells the player nothing new -- and otherwise simply pitched.
func _tent_expr(cell: Vector2i) -> int:
	if _asleep:
		return Face.Expr.SLEEPY
	if state.tent_bad(cell):
		return Face.Expr.STRAIN
	if max_hearts > 0 and _judged.has(cell) and state.tent_fair(cell):
		return Face.Expr.JOY
	return Face.Expr.HAPPY

## A tree beams once it has as many tents beside it as it wants -- one, or an
## oak's two. Which of them are its own is still the player's problem.
func _tree_expr(cell: Vector2i) -> int:
	if _asleep:
		return Face.Expr.SLEEPY
	return Face.Expr.JOY if state.tents_beside(cell) >= state.need(cell) else Face.Expr.HAPPY

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
	var tall := minf(size.y, grid.y + 2.0 * PAD + _heart_row())
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - grid.x * 0.5,
		_card.position.y + _heart_row() + (tall - _heart_row() - grid.y) * 0.5) \
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
	_forget_rest()
	_refresh_faces()
	for layer: Control in [_heart_layer, _combo_layer, _life_layer]:
		layer.queue_redraw()
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
		(available - 2.0 * PAD - _heart_row()) / (state.h + BAND))

## The strip the hearts stand in over the counts, on a board with hearts.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

## The host cuts its card to the meadow and centres it, which is what these
## two say. A board that wants neither says nothing and fills the slot.
func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * (state.h + BAND) + 2.0 * PAD + _heart_row())

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
		_under = out.under
		_sinking = out.sinking
		busy = busy or out.busy
		_ground_dirty = false
	if _under != null:
		draw_mesh(_under, null)
		shown.append(_under)
	if _still != null:
		draw_mesh(_still, null)
		shown.append(_still)
	for part in _sinking:
		draw_mesh(part[0], null, part[1], part[2])
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

## Everything on the ground that is not a character: the shade under the
## finger and the blush of a pointed-at cell (`under`), the shadow under every
## tree and tent, and the cairns arriving, standing and leaving. What stands
## still goes into `_still` (see `_rest_parts`); the rest is `mesh`, and the
## cairns sinking on the win are `sinking`. Returns those and whether any of
## it is still moving.
func _build_ground(now: float) -> Dictionary:
	var u := Face.Builder.new()
	var b := Face.Builder.new()
	var busy := false
	var rest: Array = []
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
		_cell_wash(u, cell, grown, Color(Pal.TEXT, SHADE_ALPHA))
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
			_cell_wash(u, cell, 1.0, Color(Pal.BAD_TILE, BLUSH_ALPHA * level))
	for cell in gone:
		_blush.erase(cell)
	# The shadows, anchored at the slot and read off the piece's own height,
	# so one arrives with its pop and stays put when the piece hops. A piece
	# at its full height casts its standing shadow.
	for cell in _trees:
		var seen := clampf(_trees[cell].scale.y, 0.0, 1.0)
		if seen >= 1.0:
			rest.append(_rest_part(RestPart.TREE_SHADOW, cell))
		else:
			_shadow(b, cell, TREE_SIZE, TREE_SHADOW_AT, TREE_SHADOW_RX, TREE_SHADOW_RY, seen)
	for cell in _tents:
		var tent: TentFace = _tents[cell]
		if not tent.visible:
			continue
		var seen := clampf(tent.scale.y, 0.0, 1.0)
		# A lamp-lit tent throws its warm pool before the win does it for
		# every tent.
		var lit: bool = _solved_at < 0.0 and tent.expression == Face.Expr.JOY \
			and state.mark_at(cell) == State.TENT
		if seen >= 1.0:
			rest.append(_rest_part(RestPart.TENT_SHADOW, cell))
			if lit:
				rest.append(_rest_part(RestPart.LAMP, cell))
		else:
			_shadow(b, cell, TENT_SIZE, TENT_SHADOW_AT, TENT_SHADOW_RX, TENT_SHADOW_RY, seen)
			if lit:
				_lamp(b, cell, seen)
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
	var sinking: Array = []
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
		if _solved_at >= 0.0:
			var sunk := _cleared(cell, now)
			if sunk >= 1.0:
				continue
			busy = true
			sinking.append([_rest_part(RestPart.CAIRN, cell), _sink_xf(cell, sunk),
				Color(1.0, 1.0, 1.0, 1.0 - sunk)])
		elif since < INF:
			_cairn(b, cell, since, -1.0, 0.0)
		else:
			rest.append(_rest_part(RestPart.CAIRN, cell))
	for cell in gone:
		_cairn_in.erase(cell)
	if _solved_at >= 0.0:
		busy = _build_camp(b, now) or busy
	_bake_still(rest)
	return {"mesh": null if b.verts.is_empty() else b.mesh(),
		"under": null if u.verts.is_empty() else u.mesh(),
		"sinking": sinking, "busy": busy}

## The still parts as one mesh, baked again only when the set changes.
func _bake_still(parts: Array) -> void:
	var ids := PackedInt64Array()
	ids.resize(parts.size())
	for i in parts.size():
		ids[i] = parts[i].get_instance_id()
	var key := hash(ids)
	if key == _still_key:
		return
	_still_key = key
	var fb := Face.FlatBuilder.new(_flat_cache)
	for m: ArrayMesh in parts:
		fb.append(m, Transform2D.IDENTITY)
	_still = fb.mesh()

## One part of the ground as it stands on `cell`, made the first time it is
## asked for and kept until the layout changes.
func _rest_part(kind: int, cell: Vector2i) -> ArrayMesh:
	var key := Vector3i(kind, cell.x, cell.y)
	var m: ArrayMesh = _rest_parts.get(key)
	if m != null:
		return m
	var b := Face.Builder.new()
	match kind:
		RestPart.CAIRN:
			_cairn(b, cell, INF, -1.0, 0.0)
		RestPart.TREE_SHADOW:
			_shadow(b, cell, TREE_SIZE, TREE_SHADOW_AT, TREE_SHADOW_RX, TREE_SHADOW_RY, 1.0)
		RestPart.TENT_SHADOW:
			_shadow(b, cell, TENT_SIZE, TENT_SHADOW_AT, TENT_SHADOW_RX, TENT_SHADOW_RY, 1.0)
		RestPart.LAMP:
			_lamp(b, cell, 1.0)
	m = b.mesh()
	_rest_parts[key] = m
	return m

## The parts of the ground a layout made, forgotten when the cell changes.
func _forget_rest() -> void:
	_rest_parts = {}
	_flat_cache = {}
	_still_key = 0
	_still = null
	_ground_dirty = true

## The standing cairn on `cell` as the win has taken it `sunk` into the turf:
## pressed toward its foot in its own frame (see _cairn).
func _sink_xf(cell: Vector2i, sunk: float) -> Transform2D:
	var xf := _cairn_xf(cell)
	var foot := Vector2(0.0, 0.4) * _cell * CAIRN_SIZE
	var press := Transform2D(0.0, Vector2(1.0, 1.0 - sunk), 0.0, foot) * Transform2D(0.0, -foot)
	return xf * press * xf.affine_inverse()

## A rounded wash over `cell`, `grown` of its size about its centre.
func _cell_wash(b, cell: Vector2i, grown: float, colour: Color) -> void:
	if grown <= 0.0:
		return
	var span := (_cell - 2.0 * SHADE_INSET) * grown
	b.fan(Face.Builder.round_rect(cell_to_local(cell.y, cell.x) - Vector2.ONE * span * 0.5,
		Vector2.ONE * span, SHADE_RADIUS * grown), colour)

## The family's soft disc under the face on `cell`, scaled by how much of
## the face is there (`seen`, its height).
func _shadow(b, cell: Vector2i, share: float, at: Vector2, rx: float, ry: float, seen: float) -> void:
	if seen <= 0.0:
		return
	var seat := _cell * share
	Scenery.soft_disc(b, cell_to_local(cell.y, cell.x) + at * seat,
		rx * seat * seen, ry * seat * seen, Color(Pal.TEXT, SHADOW_ALPHA * seen))

## A lamp-lit tent's warm pool, grown with the tent.
func _lamp(b, cell: Vector2i, seen: float) -> void:
	var seat := _cell * TENT_SIZE
	Scenery.soft_disc(b, cell_to_local(cell.y, cell.x) + GLOW_AT * seat,
		GLOW_RX * seat * seen, GLOW_RY * seat * seen, Color(Pal.SUN, GLOW_ALPHA * 0.8 * seen))

## A cairn: the mark the puzzle is actually solved with, so it is a thing on
## the ground and not a shade of grass. Three tiers of stones -- the two at
## its foot with the shadow, the middle one, the cap -- each lit along its
## crest, leaned and sized by its square so no two stand alike.
## `since` is the seconds since it began to be stacked (INF once it stands),
## `leaving` the seconds since it began to come apart (negative while it
## stays), and `sunk` how far into the turf the win has taken it, 0 to 1.
func _cairn(b, cell: Vector2i, since: float, leaving: float, sunk: float) -> void:
	var s := _cell * CAIRN_SIZE
	var h2 := _hash2(cell)
	var xf := _cairn_xf(cell)
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

## The cairn's own frame on `cell`: leaned and sized by its square.
func _cairn_xf(cell: Vector2i) -> Transform2D:
	var grown := 1.0 + (_hash2(cell) - 0.5) * 2.0 * CAIRN_JITTER
	return Transform2D((_hash(cell) - 0.5) * 2.0 * CAIRN_TILT, Vector2(grown, grown), 0.0,
		cell_to_local(cell.y, cell.x))

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
	if is_done() or cell.x < 0 or out_of_hearts or _ejecting:
		return
	_press_cell = cell
	_glance(cell)
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
	if cell != _last_paint:
		_glance(cell)
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
	# The sweep ticks a little higher per square it will change, so a long row
	# can be heard growing (Shikaku's drag does the same).
	_sweep_n += 1
	fx.cue("cairn" if _lay else "clear", minf(SWEEP_PITCH_MAX, 1.0 + SWEEP_PITCH * (_sweep_n - 1)))

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
	_glance(Vector2i(-1, -1))
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
			fx.buzz(Haptics.TICK)
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
	if state.mark_at(cell) == State.TENT:
		_judge(cell)
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
		else:
			fx.cue("strike")
	_speak()
	_redraw()
	note_move()
	return arrivals

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_pressed = null
	_dragged = false
	_lay = true
	_sweep_n = 0
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
			_judged.erase(cell)
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
	_want_flies()
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

## A wrong tent is wilting: the host holds a hint video until it has gone.
func busy() -> bool:
	return _ejecting

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and not _ejecting and not state.history.is_empty()

## Takes back the last gesture, however many squares it swept: the reverse of
## Place, square by square along the same path. Counts no move.
func undo() -> bool:
	if not can_undo():
		return false
	var before: Dictionary = state.marks.duplicate()
	_transition(before, state.undo(), _now(), Motion.ENTER_STAGGER)
	_speak()
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return State.HINTS_BY_BAND[state.band] + hints_extra - hints_used

## Pitches one tent from the answer and pegs it down for good: a ring pulses
## out of the square, the tent drops in from above, sparkles rise. Counts no
## move but can finish the puzzle.
func hint() -> bool:
	if is_done() or out_of_hearts or _ejecting or hints_left() <= 0:
		return false
	var before: Dictionary = state.marks.duplicate()
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	hints_used += 1
	_judged[target] = true
	_transition(before, [target], _now(), 0.0, true)
	var at := cell_to_local(target.y, target.x)
	fx.ring(at, _cell * 0.5, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_cheer_trees(target)
	_say(tr("TN_PEGGED"), Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every tent the answer does not put there wobbles and its cell blushes, and
## the sprout says how many.
func check() -> int:
	if is_done() or out_of_hearts or _ejecting:
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
	if is_done() or out_of_hearts or _ejecting:
		return
	_break_streak()
	_wilting = {}
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
	_want_flies()
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
	# The bunting stays up, and an Old Oaks board keeps its night seal; a
	# restore cannot know whether the solve was flawless, so a gold seal is
	# not claimed.
	_flies = []
	_bunting_at = now - 10.0
	_stamp_at = now - 10.0 if state.has_oaks() else INF
	_seal_mesh = null
	_life_layer.queue_redraw()
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

## The meadow, and the seal's words when one was stamped.
func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	if state.has_oaks():
		out += "\n🌙 " + tr("TN_OAK_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += "\n🏅 " + tr("BN_FLAWLESS")
	return out

# --- the win ---

## The board is the answer, so the win screen shows no cast: the pitched camp
## stays on the card under it.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("TN_WIN_SUB")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

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
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else checks == 0)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = now
		_combo_layer.queue_redraw()
	_peek = {}
	_bunny = {}
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
	var far := 0
	for cell in _trees:
		far = maxi(far, cell.x + cell.y)
	for cell in state.tents():
		far = maxi(far, cell.x + cell.y)
	_party(_solve_delay(Vector2i(far, 0)))
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

# --- judging a tent, and the streak ---

## A tent just pitched by a tap. On Hard and Insane a tent the board cannot
## fault that is not the answer's costs a heart; anything else the board
## cannot fault is right (the answer on a board with hearts, a fair tent on
## Easy and Medium, which says no more than its face does). A right tent
## builds the streak, cheers the trees beside it and may play a gag; a tent
## in trouble ends the streak.
func _judge(cell: Vector2i) -> void:
	# The winning tap: the solve wave owns every hop and spark from here.
	if is_done():
		return
	var fair: bool = state.tent_fair(cell)
	if max_hearts > 0 and fair and not state.is_answer(cell):
		_wrong_tent(cell)
		return
	_cheer_trees(cell)
	if not fair:
		_break_streak()
		return
	if max_hearts > 0:
		_judged[cell] = true
		_refresh_faces()
		_redraw()
	_streak += 1
	if _streak >= 2:
		var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
		fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB)
	if _streak >= COMBO_FROM and not is_done():
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _streak
		_combo_cell = cell
		_combo_at = _now()
		_combo_out_at = -INF
		_combo_layer.queue_redraw()
	if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
		fx.confetti(cell_to_local(cell.y, cell.x), 22)
		fx.cue("confetti")
	if not is_done():
		_gag(cell)
	_want_flies()

func _break_streak() -> void:
	_streak = 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
		_combo_layer.queue_redraw()
	else:
		_combo_n = 0

## Every tree beside `cell` that has just got the tents it wants gives a
## little hop; an oak getting its second also sparkles and chimes.
func _cheer_trees(cell: Vector2i) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var tree_at: Vector2i = cell + d
		if not _trees.has(tree_at):
			continue
		if state.tents_beside(tree_at) != state.need(tree_at):
			continue
		if not Motion.reduce:
			_hop(_trees[tree_at], CHEER_HOP, Motion.HOP_TIME, Motion.NUDGE_LAG + 0.06)
		if state.oaks.has(tree_at):
			fx.sparkle(cell_to_local(tree_at.y, tree_at.x) - Vector2(0.0, _cell * 0.3), Pal.LEAF_LIGHT)
			fx.cue("oak")

## A wrong tent: a heart goes (its halves fall), the tent fades and sags
## under a worried face, and after EJECT_AFTER it is struck as though never
## pitched.
func _wrong_tent(cell: Vector2i) -> void:
	if out_of_hearts or hearts <= 0:
		return
	var now := _now()
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_split_index = hearts
	_split_at = now
	_heart_layer.queue_redraw()
	_ejecting = true
	if hearts <= 0:
		# Input stops now; the sleep waits for the tent to go.
		out_of_hearts = true
		_running = false
	_wilting[cell] = true
	var tent: TentFace = _tent_node(cell)
	tent.expression = Face.Expr.WORRIED
	_after(WILT_LAG, func() -> void:
		Motion.stop(_look_tw.get(tent))
		tent.scale = Vector2.ONE
		_look_tw[tent] = Motion.squash(tent, 0.14, 0.2))
	_blush_cell(cell)
	_say(tr("TN_WRONG_TENT"), Face.Expr.WORRIED)
	fx.cue("heart_lost")
	_busy_for(EJECT_AFTER + STRIKE_TIME)
	moved.emit()
	_after(EJECT_AFTER, _eject.bind(cell))

## The wrong tent is struck: its tap is taken back with no history left of
## it, and a grey puff goes up where it stood.
func _eject(cell: Vector2i) -> void:
	_ejecting = false
	# Left mid-wilt through the card or the host: the board is over.
	if is_done():
		return
	var before: Dictionary = state.marks.duplicate()
	var last: Array = [] if state.history.is_empty() else state.history.back()
	if last.size() == 1 and last[0].cell == cell:
		state.undo()
	elif state.mark_at(cell) == State.TENT and not state.locked.has(cell):
		state.marks.erase(cell)
	_transition(before, [cell], _now(), 0.0)
	_wilting.erase(cell)
	if not Motion.reduce:
		fx.puff(cell_to_local(cell.y, cell.x), Pal.TENT_DEEP.lerp(Pal.LINE, 0.5), 6)
	if not out_of_hearts:
		_speak()
	moved.emit()
	_redraw()
	if out_of_hearts:
		_run_out()

## The last heart is gone: trees and tents nod off along the diagonal, the
## butterflies go, and the card comes up once they have.
func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_clear_gesture()
	_break_streak()
	fx.cue("out_of_hearts")
	_say(tr("TN_OUT"), Face.Expr.SLEEPY)
	_nod_all()
	for f in _flies:
		f.leave = true
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

## Every tree and tent takes its look along the diagonal: asleep, or awake
## again after a heart came back.
func _nod_all() -> void:
	for cell in _trees:
		_after(Motion.stagger(cell.x + cell.y, SLEEP_STAGGER), func() -> void:
			if _solved_at < 0.0:
				_trees[cell].expression = _tree_expr(cell))
	for cell in _tents:
		_after(Motion.stagger(cell.x + cell.y, SLEEP_STAGGER), func() -> void:
			if _solved_at < 0.0 and state.mark_at(cell) == State.TENT and not _wilting.has(cell):
				_tents[cell].expression = _tent_expr(cell))

## The card, over the whole screen: laid on the host so it covers the chrome,
## or on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["TN_OUT_BODY", "TN_OUT_BODY_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same meadow from the top, every heart back, the clock and
## the moves from zero; hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	moves = 0
	elapsed = 0.0
	checks = 0
	_running = true
	var now := _now()
	var before: Dictionary = state.marks.duplicate()
	var cleared := state.reset()
	_deal()
	for cell in cleared:
		var at := now + Motion.stagger((state.h - 1 - cell.y) + (state.w - 1 - cell.x), Motion.RESET_STAGGER)
		if int(before[cell]) == State.GRASS:
			_cairn_leaves(cell, at)
		else:
			_tent_down(cell, at - now)
	for cell in _trees:
		_hop(_trees[cell], Motion.RESET_HOP, Motion.HOP_TIME,
			Motion.stagger((state.h - 1 - cell.y) + (state.w - 1 - cell.x), Motion.RESET_STAGGER))
	for chip in _chips_row + _chips_col:
		_bump(chip)
	_refresh_faces()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()
	_redraw()

## One more heart (the card's video): once a board. The camp wakes along the
## diagonal.
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
	_nod_all()
	_speak()
	moved.emit()

## Back to camp from the card: the board ends unsolved first, so the host logs
## puzzle_complete {solved: false} and not an abandon.
func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- the hearts ---

## The hearts over the counts as one mesh on a paper pill, Shikaku's and
## Binairo's: pink with a small face and a leaf, a faint ghost where one was,
## the lost one's halves falling apart, and one coming back popping in.
func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _grid.y - _cell * BAND - HEART_ROW * 0.5
	var x0 := size.x * 0.5 - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts:
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

## The streak's paper bubble at the upper right of its tent, "x3" and up in
## ink: it pops in the first time, bumps at each step and deflates when the
## streak ends. One mesh for the paper and one string (Binairo's).
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
	var centre_cell := cell_to_local(_combo_cell.y, _combo_cell.x)
	var tail := centre_cell + Vector2(_cell * 0.25, -_cell * 0.3)
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

# --- gags, glances and the life on the meadow ---

## A right tent now and then plays a gag, picked by the square's own hash so a
## board replays the same: a camper peeks out of the doorway and waves, the
## tent slides on sunglasses, or a bunny hops past in front of it. Under
## reduce-motion, none.
func _gag(cell: Vector2i) -> void:
	if Motion.reduce:
		return
	var roll := posmod(hash(cell * 13 + Vector2i(7, 3)), GAG_ODDS)
	if roll >= GAGS:
		return
	var now := _now()
	match roll:
		0:
			_peek = {"cell": cell, "at": now + GAG_AT, "hat": posmod(hash(cell), BUNTING_COLOURS.size())}
			_after(GAG_AT, func() -> void: fx.cue("peek"))
			_anim_until = maxf(_anim_until, now + GAG_AT + PEEK_TIME)
		1:
			var tent: TentFace = _tent_node(cell)
			var tw := tent.create_tween()
			tw.tween_property(tent, "glasses", 1.0, GLASSES_IN).from(0.0).set_delay(GAG_AT) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(GLASSES_HOLD)
			tw.tween_property(tent, "glasses", 0.0, GLASSES_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			_after(GAG_AT, func() -> void: fx.cue("cool"))
		2:
			_bunny = {"cell": cell, "at": now + GAG_AT, "dir": 1.0 if posmod(cell.x + cell.y, 2) == 0 else -1.0}
			_after(GAG_AT, func() -> void: fx.cue("bunny"))
			_anim_until = maxf(_anim_until, now + GAG_AT + BUNNY_TIME)

## The trees and tents within GLANCE_REACH of `cell` look at it; (-1, -1) and
## every one looks ahead again. One on the square itself looks up.
func _glance(cell: Vector2i) -> void:
	var faces: Dictionary = {}
	for at in _trees:
		faces[at] = _trees[at]
	for at in _tents:
		if _tents[at].visible:
			faces[at] = _tents[at]
	for at in faces:
		var face: Face = faces[at]
		var look := Vector2.ZERO
		if cell.x >= 0 and not Motion.reduce:
			var d := Vector2(cell - at)
			if maxf(absf(d.x), absf(d.y)) <= GLANCE_REACH:
				look = d.normalized() if d != Vector2.ZERO else Vector2(0.0, -1.0)
		if face.look != look:
			face.look = look

## Where butterflies may perch: the top of every beaming tree and the ridge of
## every lamp-lit tent.
func _perches() -> Array:
	var out: Array = []
	if _asleep:
		return out
	for at in _trees:
		if _trees[at].expression == Face.Expr.JOY:
			out.append(cell_to_local(at.y, at.x) + Vector2(_cell * 0.1, -_cell * TREE_SIZE * 0.5))
	for at in _tents:
		var tent: TentFace = _tents[at]
		if tent.visible and tent.expression == Face.Expr.JOY and state.mark_at(at) == State.TENT:
			out.append(cell_to_local(at.y, at.x) + Vector2(0.0, -_cell * TENT_SIZE * 0.44))
	return out

## Butterflies come to a meadow with happy trees: one from the first, a second
## past BUTTERFLY_SECOND of the trees, none under reduce-motion. One too many
## flies off.
func _want_flies() -> void:
	if Motion.reduce or _cell <= 0.0 or _asleep or _solved_at >= 0.0:
		return
	var happy := 0
	for at in _trees:
		if state.tents_beside(at) >= state.need(at):
			happy += 1
	var want := 0
	if happy > 0:
		want = 1
		if float(happy) / maxf(1.0, _trees.size()) >= BUTTERFLY_SECOND:
			want = 2
	var staying := 0
	for f in _flies:
		if not f.leave:
			staying += 1
	while staying < want:
		_spawn_fly(_flies.size())
		staying += 1
	for f in _flies:
		if staying > want and not f.leave:
			f.leave = true
			staying -= 1

## A butterfly flying in from off the card's nearer side.
func _spawn_fly(k: int) -> void:
	var from_left := k % 2 == 0
	var start := Vector2(-40.0 if from_left else size.x + 40.0, _grid.y + _cell * state.h * (0.2 + 0.25 * (k % 3)))
	_flies.append({"pos": start, "to": start, "perch": -1, "perch_until": 0.0,
		"wing": (k + posmod(hash(start), 7)) % BUTTERFLY_WINGS.size(), "phase": k * 1.7, "leave": false})
	_life_layer.queue_redraw()

## Moves every butterfly `dt` along: toward its perch, resting there a while,
## then on to another; a leaving one flies off the top and is gone.
func _fly(dt: float) -> void:
	var now := _now()
	var perches := _perches()
	var speed := BUTTERFLY_SPEED * _cell
	var keep: Array = []
	for f in _flies:
		if not f.leave and (f.perch < 0 or f.perch >= perches.size() or f.to.distance_to(perches[f.perch]) > 1.0):
			if perches.is_empty():
				f.leave = true
			else:
				f.perch = posmod(hash(Vector2i(int(now * 10.0), int(f.phase * 10.0))), perches.size())
				f.to = perches[f.perch]
				f.perch_until = -1.0
		if f.leave:
			f.to = Vector2(f.pos.x + (1.0 if f.pos.x > size.x * 0.5 else -1.0) * 60.0, -80.0)
		var d: Vector2 = f.to - f.pos
		if d.length() > 2.0:
			var bob := Vector2(0.0, sin(now * 5.0 + f.phase) * _cell * 0.4)
			var step := minf(d.length(), speed * dt)
			f.pos += d.normalized() * step + bob * dt
		elif not f.leave:
			if f.perch_until < 0.0:
				f.perch_until = now + BUTTERFLY_PERCH + fposmod(f.phase * 3.1, 1.0) * BUTTERFLY_JITTER
			elif now >= f.perch_until and perches.size() > 1:
				var pick := posmod(hash(Vector2i(int(now * 10.0), int(f.phase * 10.0))), perches.size() - 1)
				if pick >= f.perch:
					pick += 1
				f.perch = pick
				f.to = perches[pick]
				f.perch_until = -1.0
		if f.leave and f.pos.y < -60.0:
			continue
		keep.append(f)
	_flies = keep

## The life on the meadow, over the pieces, as one mesh a frame: the
## butterflies, a camper peeking, a bunny hopping past and the party's
## bunting; the seal after the solve, with its words.
func _draw_life() -> void:
	if _cell <= 0.0:
		return
	var now := _now()
	var b := Face.Builder.new()
	if now >= _bunting_at:
		_draw_bunting(b, now - _bunting_at)
	for f in _flies:
		var perched: bool = not f.leave and f.pos.distance_to(f.to) <= 2.0
		var beat: float = absf(sin(now * (5.0 if perched else 16.0) + f.phase))
		_butterfly(b, f.pos, _cell * BUTTERFLY_SIZE, 0.25 + 0.75 * beat, BUTTERFLY_WINGS[f.wing])
	if not _peek.is_empty():
		var e: float = now - float(_peek.at)
		if e > PEEK_TIME or state.mark_at(_peek.cell) != State.TENT:
			_peek = {}
		elif e > 0.0:
			_draw_peek(b, e)
	if not _bunny.is_empty():
		var e: float = now - float(_bunny.at)
		if e > BUNNY_TIME:
			_bunny = {}
		elif e > 0.0:
			_draw_bunny(b, e)
	var shown: Array = []
	if not b.verts.is_empty():
		var mesh := b.mesh()
		shown.append(mesh)
		_life_layer.draw_mesh(mesh, null)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_life_shown = shown

## A butterfly at `at`, `s` its wingspan's half, its wings opened `open`.
func _butterfly(b, at: Vector2, s: float, open: float, wing: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		var w_ := s * open
		b.ellipse(at + Vector2(sx * w_ * 0.55, -s * 0.28), w_ * 0.6, s * 0.5, wing)
		b.ellipse(at + Vector2(sx * w_ * 0.4, s * 0.28), w_ * 0.42, s * 0.34, wing.darkened(0.12))
		b.disc(at + Vector2(sx * w_ * 0.62, -s * 0.34), s * 0.13 * maxf(open, 0.3), Color(Pal.SURFACE, 0.8))
	b.ellipse(at, s * 0.12, s * 0.5, Pal.OUTLINE)
	for sx: float in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([at + Vector2(0.0, -s * 0.45), at + Vector2(sx * s * 0.3, -s * 0.85)]),
			maxf(1.5, s * 0.06), Pal.OUTLINE)

## A camper, `e` seconds into the gag: a round face in a bobble hat comes up
## in the doorway, looks round, waves a mitten and ducks back in.
func _draw_peek(b, e: float) -> void:
	var cell: Vector2i = _peek.cell
	var R := _cell * TENT_SIZE
	var door := cell_to_local(cell.y, cell.x) + Vector2(0.0, 0.4 * R)
	var up := Motion.back_out(clampf(e / PEEK_RISE, 0.0, 1.0))
	var down := clampf((e - (PEEK_TIME - PEEK_RISE)) / PEEK_RISE, 0.0, 1.0)
	var rise := up * (1.0 - down * down)
	if rise <= 0.02:
		return
	var r := 0.12 * R
	var head := door + Vector2(0.0, -r - 0.16 * R * rise)
	var look := sin((e - PEEK_RISE) * 3.4) if e > PEEK_RISE else 0.0
	var hat: Color = BUNTING_COLOURS[int(_peek.hat)]
	# The doorway's dark behind it, so it comes out of the tent.
	b.polygon(PackedVector2Array([door + Vector2(-0.14, 0.0) * R, door + Vector2(0.14, 0.0) * R,
		door + Vector2(0.0, -0.46) * R]), Pal.TENT_DARK)
	b.disc(head, r, Pal.SURFACE)
	b.disc(head + Vector2(-0.45, 0.25) * r, r * 0.22, Color(Pal.CHEEK, 0.8))
	b.disc(head + Vector2(0.45, 0.25) * r, r * 0.22, Color(Pal.CHEEK, 0.8))
	for sx: float in [-1.0, 1.0]:
		b.disc(head + Vector2(sx * 0.32 + look * 0.15, -0.05) * r, r * 0.12, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(head + Vector2(look * 0.15, 0.12) * r, r * 0.28, PI * 0.15, PI * 0.85),
		maxf(1.2, r * 0.1), Pal.OUTLINE)
	# The bobble hat.
	b.polygon(Face.Builder.arc_points(head + Vector2(0.0, -0.15) * r, r * 1.02, PI, TAU), hat)
	b.stroke(PackedVector2Array([head + Vector2(-1.0, -0.15) * r, head + Vector2(1.0, -0.15) * r]),
		r * 0.3, hat.darkened(0.15))
	b.disc(head + Vector2(0.0, -1.15) * r, r * 0.3, Pal.SURFACE)
	# The wave: a mitten on a short arm, rocking once the camper is up.
	if e > PEEK_RISE:
		var wave := sin((e - PEEK_RISE) * 12.0) * 0.5
		var shoulder := head + Vector2(0.9, 0.9) * r
		var hand := shoulder + Vector2(0.0, -1.3 * r).rotated(0.5 + wave)
		b.stroke(PackedVector2Array([shoulder, hand]), r * 0.32, hat)
		b.disc(hand, r * 0.3, hat.darkened(0.1))

## A bunny, `e` seconds into the gag: BUNNY_HOPS hops across the front of the
## tent's square, ears back in the air and down on landing.
func _draw_bunny(b, e: float) -> void:
	var cell: Vector2i = _bunny.cell
	var dir: float = _bunny.dir
	var u := e / BUNNY_TIME
	var centre := cell_to_local(cell.y, cell.x)
	var ground := centre.y + _cell * 0.44
	var x := centre.x + dir * lerpf(-0.9, 0.9, u) * _cell
	var hop := absf(sin(u * BUNNY_HOPS * PI))
	var s := _cell * BUNNY_SIZE
	var at := Vector2(x, ground - s * 0.5 - hop * s * 0.9)
	var fade := clampf(minf(u, 1.0 - u) * 8.0, 0.0, 1.0)
	var fur := Color(Pal.SURFACE, fade)
	var ink := Color(Pal.OUTLINE, fade)
	Scenery.soft_disc(b, Vector2(x, ground), s * 0.5 * (1.0 - hop * 0.4), s * 0.12, Color(Pal.TEXT, 0.15 * fade))
	# Body, head toward the way it goes, a tail behind.
	b.ellipse(at, s * 0.5, s * 0.36, fur)
	b.disc(at + Vector2(-dir * 0.5, -0.05) * s, s * 0.16, fur)
	var head := at + Vector2(dir * 0.42, -0.3) * s
	var lean := -dir * (0.35 + hop * 0.4)
	for k: float in [-0.12, 0.12]:
		var root := head + Vector2(k * s, -0.12 * s)
		var tip := root + Vector2(0.0, -0.55 * s).rotated(lean + k)
		b.stroke(PackedVector2Array([root, tip]), s * 0.14, fur)
		b.stroke(PackedVector2Array([root.lerp(tip, 0.25), root.lerp(tip, 0.8)]), s * 0.06, Color(Pal.CHEEK, fade))
	b.disc(head, s * 0.26, fur)
	b.disc(head + Vector2(dir * 0.1, -0.03) * s, s * 0.05, ink)
	b.disc(head + Vector2(dir * 0.24, 0.06) * s, s * 0.05, Color(Pal.CHEEK, fade))

## The party's bunting: a garland of pennants strung across the top of the
## meadow, dropping in and swinging to rest, `e` seconds after it began.
func _draw_bunting(b, e: float) -> void:
	var field := _field_px()
	# Strung between the column counts and the meadow, so it hangs in front of
	# the top row rather than through it.
	var left := field.position + Vector2(-_cell * BAND * 0.3, -_cell * BAND * 0.12)
	var right := Vector2(field.end.x + _cell * BAND * 0.1, left.y)
	var drop := 1.0 if Motion.reduce else Motion.back_out(clampf(e / BUNTING_TIME, 0.0, 1.0))
	var sag := _cell * BUNTING_SAG * drop
	var swing := 0.0 if Motion.reduce else sin(e * 4.0) * 0.12 * maxf(0.0, 1.0 - e / 2.5)
	var pts := PackedVector2Array()
	const STEPS := 24
	for i in STEPS + 1:
		var u := float(i) / STEPS
		pts.append(left.lerp(right, u) + Vector2(0.0, sag * 4.0 * u * (1.0 - u)))
	b.stroke(pts, maxf(2.0, _cell * 0.03), Pal.TENT_DARK)
	var flag := _cell * 0.22
	for k in BUNTING_FLAGS:
		var u := (k + 0.5) / BUNTING_FLAGS
		var p := left.lerp(right, u) + Vector2(0.0, sag * 4.0 * u * (1.0 - u))
		var slope := (right - left).normalized().rotated(4.0 * (1.0 - 2.0 * u) * sag / maxf(1.0, right.x - left.x))
		var down := Vector2(-slope.y, slope.x).rotated(swing * (1.0 if k % 2 == 0 else -1.0))
		var a := p - slope * flag * 0.45
		var c := p + slope * flag * 0.45
		var tip := p + down * flag * 1.1 * drop
		var colour: Color = BUNTING_COLOURS[k % BUNTING_COLOURS.size()]
		b.polygon(PackedVector2Array([a, c, tip]), colour)
		b.polygon(PackedVector2Array([a, a.lerp(c, 0.5), a.lerp(tip, 0.5)]), colour.lightened(0.2))

## After the solve wave (`lead` from now): the seal, when the solve earned one
## (flawless, or any Old Oaks board), stamps onto the meadow's lower right;
## hats pop onto every tree and tent along the diagonal, the bunting drops in
## across the top, confetti sweeps the meadow and the butterflies come out.
## Under reduce-motion the seal and the bunting stand still and there is no
## more.
func _party(lead: float) -> void:
	var now := _now()
	if _flawless or state.has_oaks():
		_stamp_at = now if Motion.reduce else now + lead + CLEAR_TIME + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	_bunting_at = now if Motion.reduce else now + lead + PARTY_AT
	_after(_bunting_at - now, func() -> void: _life_layer.queue_redraw())
	if Motion.reduce:
		return
	var at := lead + PARTY_AT
	var faces: Array = []
	for cell in _trees:
		faces.append([cell, _trees[cell]])
	for cell in state.tents():
		faces.append([cell, _tent_node(cell)])
	for pair in faces:
		var cell: Vector2i = pair[0]
		var face: Face = pair[1]
		face.hat_style = posmod(hash(cell), 7)
		var tw: Tween = face.create_tween()
		tw.tween_property(face, "hat", 1.0, PARTY_HAT).from(0.0) \
			.set_delay(at + Motion.stagger(cell.x + cell.y, PARTY_HAT_STAGGER)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_after(at, func() -> void:
		var field := _field_px()
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell), 30, field.size.x * 0.8)
		fx.cue("party")
		for k in BUTTERFLY_PARTY:
			_spawn_fly(_flies.size() + k))
	_after(at + 0.45, func() -> void:
		var field := _field_px()
		fx.confetti(field.get_center(), 24, field.size.x * 0.6))
	# The butterflies stay for the win screen's first look and then fly off,
	# so the solved board goes quiet instead of redrawing for ever.
	_after(at + FLIES_STAY, func() -> void:
		for f in _flies:
			f.leave = true)
	_anim_until = maxf(_anim_until, now + at + PARTY_HAT + 1.0)

## The seal on the meadow's lower right, dropping in from STAMP_FROM its size
## and settling with the back ease's overshoot, its words over it.
func _draw_stamp(now: float, shown: Array) -> void:
	var field := _field_px()
	var rad := field.size.x * STAMP_R
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, state.has_oaks())
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := field.end - Vector2(rad, rad) * 1.05
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if state.has_oaks():
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("TN_OAK_SEAL") if not _flawless else tr("BN_FLAWLESS"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

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
	_sync_cast()
	var now := _now()
	if now < _anim_until:
		queue_redraw()
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1):
		_heart_layer.queue_redraw()
	if _combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF):
		_combo_layer.queue_redraw()
	if not _flies.is_empty() or not _peek.is_empty() or not _bunny.is_empty() \
			or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1) \
			or (now >= _bunting_at and now - _bunting_at < BUNTING_TIME + 0.1):
		_fly(delta)
		_life_layer.queue_redraw()

# --- the cast: every face's body in a few MultiMesh draws ---

## Copies every chip's, tree's and tent's place, turn, look and tint into the
## cast's MultiMeshes (see `_cast`).
func _sync_cast() -> void:
	if _cell <= 0.0 or _cast == null:
		return
	var groups: Dictionary = {}   # mesh -> [Transform2D, Color, ...]
	var order: Array = []
	var nums: Array = []
	for chip in _chips_col + _chips_row:
		if _cast_face(chip, null, groups, order):
			var n: Array = chip.numeral()
			if not n.is_empty():
				nums.append([chip.get_transform()] + n)
	for cell in _trees:
		var tree: Control = _trees[cell]
		_cast_face(tree, _slots[tree], groups, order)
	for cell in _tents:
		var tent: Control = _tents[cell]
		_cast_face(tent, _slots[tent], groups, order)
	for mesh in _cast_mm.keys():
		if not groups.has(mesh):
			_cast_sent.erase(_cast_mm[mesh])
			_cast_mm.erase(mesh)
	for mesh: ArrayMesh in order:
		var list: Array = groups[mesh]
		var count := list.size() / 2
		var buf := PackedFloat32Array()
		buf.resize(count * 12)
		for k in count:
			_put(buf, k, list[2 * k], list[2 * k + 1])
		var mm: MultiMesh = _cast_mm.get(mesh)
		if mm == null:
			mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			mm.use_colors = true
			mm.mesh = mesh
			_cast_mm[mesh] = mm
		if mm.instance_count != count:
			mm.instance_count = count
			_cast_sent.erase(mm)
		if _cast_sent.get(mm) != buf:
			mm.buffer = buf
			_cast_sent[mm] = buf
	if order != _cast_order or nums != _numerals:
		_cast_order = order
		_numerals = nums
		_cast.queue_redraw()

## Puts the layers of `f` the cast draws (its `skip_layers`) into `groups`,
## under its slot's transform when it stands in one. Returns whether the face
## is on show at all.
func _cast_face(f: Face, slot: Control, groups: Dictionary, order: Array) -> bool:
	if not f.visible or (slot != null and not slot.visible):
		return false
	var xf := f.get_transform()
	var tone := f.modulate * f.self_modulate
	if slot != null:
		xf = slot.get_transform() * xf
		tone *= slot.modulate
	if is_zero_approx(xf.determinant()) or tone.a <= 0.0:
		return false
	var R := roundf(f._R_for(minf(f.size.x, f.size.y)) / Face.R_STEP) * Face.R_STEP
	if R <= 0.0:
		return false
	var eye := f._eye_level()
	var centre := f.size * 0.5
	for layer in f._layers():
		if not f.skip_layers.has(layer[0]):
			continue
		var mesh: ArrayMesh = f._mesh_for(layer[0], layer[1], R, eye)
		if not groups.has(mesh):
			groups[mesh] = []
			order.append(mesh)
		groups[mesh].append(xf * f._layer_transform(layer[0], R, centre))
		groups[mesh].append(tone)
	return true

## Instance `i` of a 2D MultiMesh buffer: the basis and origin in the
## server's row order, then the colour (Binairo's).
static func _put(buf: PackedFloat32Array, i: int, xf: Transform2D, col: Color) -> void:
	var o := i * 12
	buf[o] = xf.x.x
	buf[o + 1] = xf.y.x
	buf[o + 3] = xf.origin.x
	buf[o + 4] = xf.x.y
	buf[o + 5] = xf.y.y
	buf[o + 7] = xf.origin.y
	buf[o + 8] = col.r
	buf[o + 9] = col.g
	buf[o + 10] = col.b
	buf[o + 11] = col.a

func _draw_cast() -> void:
	for mesh in _cast_order:
		var mm: MultiMesh = _cast_mm.get(mesh)
		if mm != null:
			_cast.draw_multimesh(mm, null)
	var font: Font = CozyTheme.display(700)
	for n in _numerals:
		_cast.draw_set_transform_matrix(n[0])
		_cast.draw_string(font, n[1], n[2], HORIZONTAL_ALIGNMENT_LEFT, -1.0, n[3], n[4])
	_cast.draw_set_transform_matrix(Transform2D.IDENTITY)

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
