extends "res://core/puzzle_base.gd"

## Untangle as a wooden ring: pegs in a ring of holes, a thick twisted rope
## from each peg to its twin, and the job of lifting pegs into the empty holes
## until no two ropes cross. The rules live in puzzles/untangle_state.gd (and
## the dealer in untangle_gen.gd); each rope is a Verlet chain in
## puzzles/untangle_rope.gd; this only draws them and takes the player's
## fingers.
##
## The ropes lie over and under each other as the tangle says: a pair wrapped
## round each other is held to a braid the two share (they swing across each
## other as many times as they cross), and wherever a rope drawn earlier lies
## on top, a short piece of it is laid back over the other (_build_patches).
##
## What is on the cloth. The ring, its holes and the embroidery round it are
## one static mesh; everything that moves -- the target glows, every rope in
## the order it lies, the crossing marks, every peg, the thread row -- is one
## more, rebuilt only on the frames something is moving. So the board costs two
## draw commands at rest plus the kitten's face and the rewards layer.
##
## How it moves. Pegs and ropes are integrated in _process against a clock,
## never tweened: a peg is on the finger, or on a scripted flight (a drop, a
## return, a hint, the kitten's swipe, reset's walk home), or in its hole, and
## the rope hangs from wherever the peg is drawn. The paper-side polish
## (pops, squashes, faces, hats) is the family's vocabulary (core/motion.gd).
##
## Hard and Insane run on thread (a stitch a move) and can be lost; Insane also
## has the kitten, who bats the marked peg after every third move.
## Spec: docs/superpowers/specs/2026-09-29-untangle-knots-design.md.

const State = preload("res://puzzles/untangle_state.gd")
const Gen = preload("res://puzzles/untangle_gen.gd")
const Rope = preload("res://puzzles/untangle_rope.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const KittenFace = preload("res://ui/faces/kitten_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Seal = preload("res://ui/flat/seal.gd")
const Rewards = preload("res://arcade/rewards.gd")
const CozyTheme = preload("res://ui/theme.gd")
const OUT_CARD := "res://ui/hud/out_of_rows.gd"
const OUT_WORDS := {"title": "UT_OUT_TITLE", "body": "UT_OUT_BODY", "body_rest": "UT_OUT_BODY_REST",
	"more": "UT_ONE_SPOOL", "show": "UT_SHOW_ANSWER", "placement": "spool"}

# --- the layout, in the board's own pixels ---
const PAD_X := 34.0
const TOP_ROOM := 176.0
const TOP_ROOM_PLAIN := 96.0
const BOTTOM_ROOM := 30.0
## The ring's inner edge as a share of its outer, and a peg's size against the
## ring's width.
const RING_IN := 0.79
const PEG_OF_RING := 0.44
const HOLE_OF_PEG := 1.1
## The rope's width, in peg radii.
const ROPE_OF_PEG := 1.1
## A rope's own length is the span it can reach, plus this much.
const LENGTH_OVER := 1.012

# --- the colours ---
## Each rope's fill, its deep edge and its pale strip.
const ROPES := [
	[Color("f3e7cf"), Color("bfa77e"), Color("fffaf0")],
	[Color("f7d766"), Color("c99d2c"), Color("fff0a8")],
	[Color("f08f7a"), Color("bd5b48"), Color("ffc9ba")],
	[Color("a7c98c"), Color("6f9756"), Color("d8eec4")],
	[Color("86bfe8"), Color("4f8bb8"), Color("c8e6fb")],
	[Color("b8a2e2"), Color("8468b8"), Color("e2d6fa")],
	[Color("f3a6c2"), Color("c4739a"), Color("fdd4e4")],
	[Color("7ecfbf"), Color("459a8b"), Color("bcefe4")],
	[Color("f4a85a"), Color("c4772a"), Color("fdd8a4")],
]
const WOOD := Color("e7c795")
const WOOD_EDGE := Color("c39b63")
const WOOD_HI := Color("f6e2bd")
const WOOD_GRAIN := Color("b98c55")
const HOLE := Color("5f4229")
const HOLE_DEEP := Color("452e1c")
const HOLE_RIM := Color("a98246")
const CAP := Color("d7a56e")
const CAP_SIDE := Color("b98552")
const CAP_DEEP := Color("8d6034")
const CAP_HI := Color("f2d5a9")
const THREAD := Color("e8806a")
const THREAD_DEEP := Color("bd5b48")
const THREAD_GONE := Color("b9a58a")
const PAW := Color("e58a86")
const KNOT_HALO := Color("e0604a")
const CLOTH_LEAF := Color("a9b98d")
const CLOTH_LEAF_DEEP := Color("859a6c")
const CLOTH_PETAL := Color("f7eedb")
const CLOTH_PETAL_DEEP := Color("dcc9a4")
const CLOTH_GOLD := Color("e8b84a")
const CLOTH_BERRY := Color("98a6c4")

# --- the hand ---
## A press grabs the nearest peg within this many peg radii.
const GRAB_R := 1.9
## A peg is over a hole when within this many peg radii of it.
const SNAP_R := 1.9
## A press has to travel this far to be a drag, not a tap, in px.
const DRAG_SLOP := 16.0
## A held peg rides this far above the finger (in peg radii) so it shows.
const HOLD_LIFT := 0.9
const LIFT_TIME := 0.14
const PEG_LIFT_SCALE := 1.16

# --- the ropes' life ---
const WHIP_DROP := 5.5
const WHIP_PICK := 2.2
const WHIP_HOME := 3.0
const SLACK_DROP := 0.022
const IDLE_WHIP_EVERY := 7.0
const SLEEP_ENERGY := 0.2
const SLEEP_STEPS := 24
## Seconds of nothing touching the ring before a rope still moving is damped
## down to rest.
const QUIET_AFTER := 1.2

# --- flights, in seconds ---
const FLY_MIN := 0.22
const FLY_MAX := 0.42
const FLY_ARC := 1.5
const HOME_TIME := 0.24
const WALK_STEP := 0.05
const LAND_SQUASH := 0.2
const ENTER_LAG := 0.12

# --- the crossing marks ---
const KNOT_FADE := 14.0
const KNOT_SPAN := 5.0

## A braid: rope widths along it per crossing, how far each rope swings off
## its line (in widths), how hard its points are held to it per step, how much
## longer the way through it is than its line, and how fast one cinches and
## lets go (s).
const BRAID_PITCH := 1.6
const BRAID_SIDE := 0.52
const BRAID_PULL := 0.32
## How gently a wrapped rope's legs are held to the straight way between.
const BRAID_LEG := 0.05
const BRAID_WAY := 1.14
const BRAID_CINCH := 0.34
const BRAID_LET_GO := 0.3
## The way a wrapped rope may be sent round a braid, peg to braid to peg, as
## a share of the rope's own length.
const BRAID_WAY_OF_LENGTH := 0.85
## The shortest a braid is let get when its rope has no room for all of its
## braids, as a share of its length.
const BRAID_SHORTEST := 0.45
## How far (radians) a braid's twist turns as it cinches in or lets go.
const BRAID_SPIN := 2.4 * PI
## A piece laid back over a lone crossing reaches this many rope widths either
## way (in a braid, halfway to the next crossing).
const PATCH_HALF := 0.9

# --- rewards ---
const STAMP_STEPS := [0, 1, 3, 6]
const STAMP_R := 150.0
const WIN_HOLD := 2.6
const HAT_AT := 0.9
const STAMP_AT := 1.7
const WAVE_STEP := 0.09
const STREAK_AT := 3
## How long a rope left with no crossings grins.
const FREE_JOY := 1.1

# --- the thread ---
const STITCH_W := 27.0
const STITCH_H := 10.0
const STITCH_GAP := 9.0
const THREAD_Y := 46.0
const LOW_THREAD := 3
const OUT_CARD_AFTER := 1.7

# --- the kitten ---
const KITTEN_SIZE := 172.0
const POUNCE_LEAD := 0.34
const POUNCE_FLY := 0.5
const SWIPE_BUSY := 1.15

const TIP_CYCLE := 9.0
## The toast: a dark label over the ring's top for a few seconds.
const TOAST_HOLD := 2.8
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32

var state: State = State.new()
var nodes: int:
	get: return state.holes

var fx: Node2D
var _rw: Rewards
var _kitten: Face
var _gen := 0
var _difficulty := 0

# geometry
var _c := Vector2.ZERO
var _ro := 0.0
var _ri := 0.0
var _rh := 0.0
var _peg_r := 0.0
var _hole_r := 0.0
var _wd := 0.0
var _top := TOP_ROOM
var _kitten_at := Vector2.ZERO
var _yarn_at := Vector2.ZERO

# the rope and peg cast
var _ropes: Array = []                       # [r] -> Rope
var _calm := PackedInt32Array()              # [r] -> consecutive still steps
var _mv: Array = []                          # [peg] -> {"from","to","t0","dur","arc"} or null
var _peg_px := PackedVector2Array()          # [peg] -> where it is drawn (on the cloth)
var _lift := PackedFloat32Array()            # [peg] -> how high it is held, 0..1
var _sq_at := PackedFloat32Array()           # [peg] -> when it last landed
var _shake_at := PackedFloat32Array()        # [peg] -> when it last refused
var _face := PackedInt32Array()              # [peg] -> 0 blank, 1 joy, 2 asleep, 3 strained
var _face_at := PackedFloat32Array()
var _hat_at := PackedFloat32Array()
var _accum := 0.0

# the hand
var _held := -1
var _sel := -1
var _press_peg := -1
var _press_at := Vector2.ZERO
var _finger := Vector2.ZERO
var _grab := Vector2.ZERO
var _dragged := false
var _held_pos := Vector2.ZERO
## Where the finger says the held peg should be; the peg drawn chases it.
var _held_want := Vector2.ZERO
var _hot := -1
var _hot_far := -1
var _taut_sent := false
var _ghost: Array = []                       # the kitten's foreseen swipe

# the clock
var _last := -1.0
var _opened := 0.0
## When the solve began; -INF while unsolved. Never a sign test: the clock
## is seconds since launch, and a restore stamps a moment before it.
var _solved_at := -INF
var _busy_until := 0.0
var _later: Array = []
var _idle_at := 0.0
var _needle_x := 0.0
var _needle_dip := -100.0
var _stitch_at := PackedFloat32Array()
var _spent_shown := 0

# the day
var _all_moves := 0
var _streak := 0
var _out_card := false
var _card: Control
var _shown_answer := false
var _stamp: Control
var _stamp_rad := STAMP_R
var _party := false
var _paw := {}
var _kitten_mood_until := 0.0

# what is drawn
var _ring_mesh: ArrayMesh
var _under_mesh: ArrayMesh
var _over_mesh: ArrayMesh
var _extra_mesh: ArrayMesh
var _paw_mesh: ArrayMesh
var _rope_mesh: Array = []                   # [r] -> that rope's own mesh
var _rope_sig: Array = []                    # [r] -> what it was built from
var _peg_mesh: Array = []                    # [rope] -> [cap with inlay, cap blank]
var _peg_arrays: Array = []                  # the same, as surface arrays, for the bake
var _rest_mesh: ArrayMesh                    # every peg at rest, shadows and caps, as one mesh
var _rest_for: Array = []                    # what _rest_mesh was baked from
## The meshes the last _draw handed over, kept until the next replaces them.
var _shown: Array = []
var _knot_alpha := 0.0
var _tw_px := PackedInt32Array()
var _wraps := {}
## The braids as last laid by `_bind_all`, spaced along their ropes: pair ->
## `_braid` entry. What the crossing search and the rewards read.
var _laid := {}
var _cross: Array = []
var _cross_kept := {}            # pair -> [what it was found from, its crossings]
var _stack: Array = []
var _look: Array = []                         # [r] -> what its mesh was drawn with
var _patch_mesh: ArrayMesh
var _over_for: Array = []
var _bound_for: Array = []
var _stir_at := 0.0
var _lines_moved := true
var _cross_for := PackedInt32Array()
var _hot_preview: Array = []                  # [crossing change, wraps] for the hole under the peg
var _dirty := true

var _stuck_key := PackedByteArray()
var _was_settled := true
var _rebuilt_at := 0.0
var _restored := false
var _toast := ""
var _toast_at := -100.0
var _toast_hold := TOAST_HOLD
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

## The host's Back ends a board that says this unsolved: true from the step
## that spent the last of the thread, not only once the card is up.
var out_of_hearts: bool:
	get:
		return _out_card or (state.out_of_thread() and not is_done())
	set(v):
		_out_card = v

func puzzle_id() -> String: return "untangle"
func title() -> String: return "Untangle"

func rules() -> String:
	return tr("UT_RULES")

func capabilities() -> Array[String]:
	return ["undo", "hint"]

## The tutorial, a page a rule, drawn from the board's own ring, pegs and
## ropes (ui/hud/untangle_tutorial_diagram.gd): lift a peg over the top, the
## rope underneath wraps tighter, a short rope's reach; then the hint where
## the band has one, the thread on Hard and Insane, and Insane's kitten.
func tutorial_pages() -> Array:
	const Diagram = preload("res://ui/hud/untangle_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.LIFT, "HTP_UT_LIFT", tr("HTP_UT_LIFT_BODY")],
		[Diagram.Lesson.WRAP, "HTP_UT_WRAP", tr("HTP_UT_WRAP_BODY")],
		[Diagram.Lesson.REACH, "HTP_UT_REACH", tr("HTP_UT_REACH_BODY")]]
	var hints: int = State.HINTS_BY_BAND[clampi(_difficulty, 0, 3)]
	if hints > 0:
		var body := tr("HTP_UT_HINT_BODY_ONE") if hints == 1 else tr("HTP_UT_HINT_BODY_N") % hints
		if _difficulty >= 2:
			body += " " + tr("HTP_UT_HINT_THREAD")
		steps.append([Diagram.Lesson.HINT, "HTP_UT_HINT", body])
	if _difficulty >= 2:
		steps.append([Diagram.Lesson.THREAD, "HTP_UT_THREAD", tr("HTP_UT_THREAD_BODY")])
	if _difficulty >= 3:
		steps.append([Diagram.Lesson.CAT, "HTP_UT_CAT", tr("HTP_UT_CAT_BODY")])
	var pages := []
	for step in steps:
		var d := Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## What the phone does under each cue (docs/agents/haptics.md). The `drop`
## cue is not here: the kitten's swat and a hint's flight fire it too, so the
## peg the hand let go knocks from `_landed` (a tap, or a bump when a rope
## comes free or two crossings go at once). The rope going taut in the hand
## ticks once (`_update_held`), which is the reach rule felt, and the pluck
## that shares its cue does not. The win knocks on `solved`, which waits for
## the last peg to land; the seal thuds as it lands (`_stamp_down`). A peg
## lifted, put back or selected, a hole hovered, a braid cinching under the
## hand, a refused peg, a stitch sewn, the kitten petted or swatting and the
## shown answer say nothing.
const HAPTICS := {
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"hint": Haptics.GOOD,
	"spool_back": Haptics.GOOD,
	"thread_low": Haptics.WARN,
	"thread_out": Haptics.LOSE,
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
	_kitten = KittenFace.new()
	_kitten.name = "Kitten"
	_kitten.visible = false
	_kitten.z_index = 1
	add_child(_kitten)
	_rw = Rewards.new()
	_rw.z_index = 4
	add_child(_rw)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

# --- building the day ---

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_difficulty = clampi(difficulty, 0, Gen.BANDS.size() - 1)
	state.setup(rng, _difficulty)
	_tw_px = state.tw.duplicate()
	_wraps = {}
	_cross = []
	_cross_kept = {}
	_hot_preview = []
	_over_for = []
	_bound_for = []
	_stop_all()
	_close_card()
	_clear_stamp()
	if _rw != null:
		_rw.clear()
	out_of_hearts = false
	_shown_answer = false
	_party = false
	_held = -1
	_sel = -1
	_press_peg = -1
	_hot = -1
	_hot_far = -1
	_ghost = []
	_paw = {}
	_later = []
	_all_moves = 0
	_restored = false
	_streak = 0
	_stuck_key = PackedByteArray()
	_solved_at = -INF
	_last = -1.0
	_opened = _now()
	_busy_until = 0.0
	_idle_at = _now() + IDLE_WHIP_EVERY
	_top = TOP_ROOM if (state.budget > 0 or state.cat) else TOP_ROOM_PLAIN
	var pegs: int = state.at.size()
	_mv = []
	_lift = PackedFloat32Array(); _lift.resize(pegs)
	_sq_at = PackedFloat32Array(); _sq_at.resize(pegs); _sq_at.fill(-100.0)
	_shake_at = PackedFloat32Array(); _shake_at.resize(pegs); _shake_at.fill(-100.0)
	_face = PackedInt32Array(); _face.resize(pegs)
	_face_at = PackedFloat32Array(); _face_at.resize(pegs); _face_at.fill(-100.0)
	_hat_at = PackedFloat32Array(); _hat_at.resize(pegs); _hat_at.fill(-100.0)
	_peg_px = PackedVector2Array(); _peg_px.resize(pegs)
	for i in pegs:
		_mv.append(null)
	_ropes = []
	_calm = PackedInt32Array(); _calm.resize(state.ropes)
	for r in state.ropes:
		_ropes.append(Rope.new())
	_stitch_at = PackedFloat32Array(); _stitch_at.resize(maxi(state.budget, 0)); _stitch_at.fill(-100.0)
	_spent_shown = 0
	_needle_x = 0.0
	_kitten.visible = state.cat
	if state.cat:
		_kitten.expression = Face.Expr.HAPPY
		_kitten.look = _gaze()
		_kitten.set_idle(true)
	# Nothing of the last board's geometry outlives it, so a frame that runs
	# before the layout has (a card with no size yet) draws nothing.
	_ro = 0.0
	_layout()
	_tip_idx = 0
	_toast = ""
	_say(tr("UT_TIP_DRAG"), Face.Expr.HAPPY)
	_tip_timer.start()
	# The first thing to know about this day, once the pegs are in.
	var first := "UT_TIP_CAT" if state.cat else ("UT_TIP_THREAD" if state.budget > 0 else "UT_TIP_DRAG")
	_later_call(1.1, func() -> void:
		if not is_done():
			_tell(first, Face.Expr.HAPPY, 4.6))
	fx.cue("enter")
	_dirty = true

# --- layout ---

func _layout() -> void:
	if _ropes.size() != state.ropes or size.x < 100.0 or size.y < 100.0:
		return
	var avail_h := size.y - _top - BOTTOM_ROOM
	var diameter := minf(size.x - 2.0 * PAD_X, avail_h)
	_ro = diameter * 0.5
	_ri = _ro * RING_IN
	_rh = (_ro + _ri) * 0.5
	_c = Vector2(size.x * 0.5, _top + avail_h * 0.5)
	var spacing := TAU * _rh / state.holes
	_peg_r = minf((_ro - _ri) * PEG_OF_RING, spacing * 0.36)
	_hole_r = _peg_r * HOLE_OF_PEG
	_wd = _peg_r * ROPE_OF_PEG
	_kitten_at = Vector2(size.x - PAD_X - KITTEN_SIZE * 0.5, 8.0 + KITTEN_SIZE * 0.5)
	_kitten.size = Vector2.ONE * KITTEN_SIZE
	_kitten.position = _kitten_at - _kitten.size * 0.5
	_kitten.pivot_offset = _kitten.size * 0.5
	_yarn_at = _kitten_at + Vector2(-KITTEN_SIZE * 0.98, KITTEN_SIZE * 0.2)
	_place_stamp()
	# A flight is in the old geometry's pixels: the pegs settle where they belong.
	for p in state.at.size():
		_mv[p] = null
		_peg_px[p] = _peg_home(p)
	_paw = {}
	for r in state.ropes:
		var rope: Rope = _ropes[r]
		rope.setup(_peg_px[2 * r], _peg_px[2 * r + 1], _span_px(state.reach[r]) * LENGTH_OVER, (6.0 if r % 2 == 0 else -6.0))
	_set_shown(_tw_px if _tw_px.size() == Gen.pair_count(state.ropes) else state.tw, true)
	_settle_ropes(70)
	_ring_mesh = _build_ring()
	_build_peg_meshes()
	_rope_sig = []
	_rope_sig.resize(state.ropes)
	_rope_mesh = []
	_rope_mesh.resize(state.ropes)
	_look = []
	_look.resize(state.ropes)
	_over_for = []
	_dirty = true

## The straight length of a rope reaching `holes` holes round the ring.
func _span_px(holes_apart: int) -> float:
	return 2.0 * _rh * sin(PI * float(holes_apart) / state.holes)

func _hole_px(h: int) -> Vector2:
	return _c + Vector2.from_angle(TAU * float(h) / state.holes - PI * 0.5) * _rh

func _peg_home(p: int) -> Vector2:
	return _hole_px(state.at[p])

## Board-local centre of the peg in `p`'s hole (the win harness drags between
## these), and of hole `h`.
func peg_to_local(p: int) -> Vector2:
	return _peg_px[p]

func hole_to_local(h: int) -> Vector2:
	return _hole_px(h)

func _rope_col(r: int) -> Array:
	return ROPES[r % ROPES.size()]

# --- the static picture: the cloth's flowers, the ring and its holes ---

func _build_ring() -> ArrayMesh:
	var b := Face.Builder.new()
	_embroider(b)
	# A running stitch round the ring.
	var stitches := 56
	for i in stitches:
		var a0 := TAU * (float(i) + 0.15) / stitches
		var a1 := TAU * (float(i) + 0.62) / stitches
		var rr := _ro + _peg_r * 0.55
		b.stroke(Face.Builder.arc_points(_c, rr, a0, a1), 5.0, Color(CLOTH_GOLD, 0.55), false, true)
	# Its shadow on the cloth, in two soft passes, then the wood.
	var soft := _ro - _ri
	b.stroke(Face.Builder.arc_points(_c + Vector2(0.012, 0.03) * _ro, _rh, 0.0, TAU), soft + 22.0, Color(Pal.TEXT, 0.05), true)
	b.stroke(Face.Builder.arc_points(_c + Vector2(0.01, 0.022) * _ro, _rh, 0.0, TAU), soft + 10.0, Color(Pal.TEXT, 0.09), true)
	b.stroke(Face.Builder.arc_points(_c, _rh, 0.0, TAU), soft, WOOD, true)
	b.stroke(Face.Builder.arc_points(_c, _ro - 3.0, 0.0, TAU), 6.0, WOOD_EDGE, true)
	b.stroke(Face.Builder.arc_points(_c, _ri + 3.0, 0.0, TAU), 6.0, WOOD_EDGE, true)
	# The light on the ring's upper left, a bevel.
	b.stroke(Face.Builder.arc_points(_c, _ro - 11.0, PI * 1.02, PI * 1.62), 5.0, Color(WOOD_HI, 0.85), false, true)
	b.stroke(Face.Builder.arc_points(_c, _ri + 11.0, PI * 0.02, PI * 0.6), 4.0, Color(WOOD_HI, 0.4), false, true)
	# Grain: long thin arcs at a few radii.
	var grain := RandomNumberGenerator.new()
	grain.seed = 4471
	for k in 22:
		var rr := grain.randf_range(_ri + 9.0, _ro - 9.0)
		var a0 := grain.randf_range(0.0, TAU)
		var sweep := grain.randf_range(0.25, 0.9)
		b.stroke(Face.Builder.arc_points(_c, rr, a0, a0 + sweep), grain.randf_range(1.6, 2.6), Color(WOOD_GRAIN, grain.randf_range(0.12, 0.26)), false, true)
	# The holes.
	for h in state.holes:
		var at := _hole_px(h)
		b.disc(at, _hole_r * 1.14, Color(HOLE_RIM, 0.7))
		b.disc(at, _hole_r, HOLE)
		b.disc(at + Vector2(0.0, _hole_r * 0.16), _hole_r * 0.82, HOLE_DEEP)
		b.ellipse(at + Vector2(0.0, _hole_r * 0.5), _hole_r * 0.6, _hole_r * 0.26, Color(HOLE, 0.9))
	return b.mesh()

## Flowers, leaves and berries stitched on the linen where the ring leaves
## room: the two lower corners, and small sprigs up the sides.
func _embroider(b: Face.Builder) -> void:
	var w := size.x
	var h := size.y
	_sprig(b, Vector2(PAD_X * 0.2 + 46.0, h - 52.0), 46.0, 0.2, 1.0)
	_sprig(b, Vector2(w - PAD_X * 0.2 - 46.0, h - 56.0), 40.0, PI - 0.2, -1.0)
	if _top > TOP_ROOM_PLAIN + 1.0:
		return
	_sprig(b, Vector2(50.0, 44.0), 34.0, 0.9, 1.0)
	_sprig(b, Vector2(w - 50.0, 44.0), 34.0, PI - 0.9, -1.0)

## A stitched flower with two leaves and a pair of berries at `at`.
func _sprig(b: Face.Builder, at: Vector2, r: float, tilt: float, side: float) -> void:
	for k in 2:
		var a := tilt + side * (0.55 + 0.9 * k)
		var lc := at + Vector2.from_angle(a) * r * 1.35
		Rewards.petal(b, lc, r * 0.78, r * 0.3, a, CLOTH_LEAF)
		b.stroke(PackedVector2Array([at + Vector2.from_angle(a) * r * 0.7, at + Vector2.from_angle(a) * r * 1.9]), 2.4, CLOTH_LEAF_DEEP, false, false)
	for k in 6:
		var a := TAU * k / 6.0 + tilt
		Rewards.petal(b, at + Vector2.from_angle(a) * r * 0.5, r * 0.5, r * 0.28, a, CLOTH_PETAL_DEEP)
	for k in 6:
		var a := TAU * k / 6.0 + tilt
		Rewards.petal(b, at + Vector2.from_angle(a) * r * 0.48 + Vector2(-1.0, -1.5), r * 0.46, r * 0.24, a, CLOTH_PETAL)
	b.disc(at, r * 0.28, CLOTH_GOLD)
	b.disc(at + Vector2(-r * 0.06, -r * 0.08), r * 0.1, Color("f9dc8a"))
	for k in 3:
		var d := at + Vector2(side * (r * 1.6 + k * r * 0.34), -r * 0.9 - k * r * 0.14)
		b.disc(d, r * 0.17, CLOTH_BERRY)
		b.disc(d + Vector2(-2.0, -2.0), r * 0.05, Color(1, 1, 1, 0.7))

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _ropes.size() != state.ropes or _ro <= 0.0:
		return
	var t := _now()
	var dt := 0.0 if _last < 0.0 else minf(0.05, t - _last)
	_last = t
	if _rw != null:
		_rw.step(dt)
	_run_later(t)
	_update_pegs(t, dt)
	_update_wraps(dt)
	var moving := _step_ropes(dt, t)
	_idle_whip(t)
	if moving or _animating(t):
		_dirty = true
	if _dirty:
		_dirty = false
		_rebuild(t)
		_rebuilt_at = t
		queue_redraw()
	elif _sel >= 0 and t - _rebuilt_at >= 1.0 / 30.0:
		# A peg selected by a tap only pulses the glow on the holes it can go
		# to: half rate is plenty.
		_rebuild(t)
		_rebuilt_at = t
		queue_redraw()
	elif _pulses(t):
		queue_redraw()
	# The HUD reads can_undo() and can_reset(), which wait for the board to
	# settle, and only re-reads when told: tell it when the board has settled.
	var settled := _settled(t)
	if settled and not _was_settled:
		focus_changed.emit()
	_was_settled = settled
	_flow(t)

## Things to do later, on the board's own clock: [when, Callable].
func _later_call(delay: float, what: Callable) -> void:
	_later.append([_now() + maxf(delay, 0.0), what, _gen])

func _run_later(t: float) -> void:
	if _later.is_empty():
		return
	var keep: Array = []
	var due: Array = []
	for entry in _later:
		if float(entry[0]) <= t:
			due.append(entry)
		else:
			keep.append(entry)
	_later = keep
	for entry in due:
		if int(entry[2]) == _gen:
			(entry[1] as Callable).call()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

## True while anything is in the air, in the hand or still finishing a pop.
func _animating(t: float) -> bool:
	if _held >= 0 or not _paw.is_empty():
		return true
	if t < _opened + Motion.ENTER_DELAY + Motion.stagger(state.at.size(), Motion.ENTER_STAGGER) + Motion.POP_IN + ENTER_LAG + 0.3:
		return true
	if _solved_at > -INF and t < _solved_at + WIN_HOLD + 2.0:
		return true
	if t < _needle_dip + 0.5 or t < _kitten_mood_until:
		return true
	for p in _mv.size():
		if _mv[p] != null:
			return true
		if absf(_lift[p] - _lift_goal(p)) > 0.001:
			return true
		if t < _sq_at[p] + LAND_SQUASH + 0.1 or t < _shake_at[p] + 0.5 or t < _face_at[p] + 0.5 or t < _hat_at[p] + 0.6:
			return true
	for s in _stitch_at.size():
		if t < _stitch_at[s] + 0.5:
			return true
	return false

## Anything that needs a redraw of the same mesh but not a rebuild: the
## sleepers' z's rising.
func _pulses(t: float) -> bool:
	if _toast != "" and t - _toast_at < _toast_hold + 0.1:
		return true
	return _out_card and not Motion.reduce

func _lift_goal(p: int) -> float:
	return 1.0 if (p == _held or p == _sel) else 0.0

# --- pegs ---

## Where every peg is drawn: on the finger, on a flight, or in its hole.
func _update_pegs(t: float, dt: float) -> void:
	if _held >= 0:
		_update_held()
		# The peg drawn chases the finger a hair behind it, which is what
		# gives it weight.
		_held_pos = _held_want if Motion.reduce else _held_pos.lerp(_held_want, 1.0 - exp(-dt * 38.0))
		_carry_tangle()
	for p in _peg_px.size():
		var goal := _lift_goal(p)
		_lift[p] = goal if Motion.reduce else move_toward(_lift[p], goal, dt / LIFT_TIME)
		if p == _held:
			_peg_px[p] = _held_pos
			continue
		var m = _mv[p]
		if m != null:
			var u := _dec((t - float(m.t0)) / float(m.dur))
			if t < float(m.t0):
				_peg_px[p] = m.from
			else:
				_peg_px[p] = (m.from as Vector2).lerp(m.to, _ease(u))
			if u >= 1.0 and t >= float(m.t0):
				# A flight may have another queued behind it (the kitten
				# batting the peg the player has just dropped).
				_mv[p] = m.get("then")
				_peg_px[p] = m.to
		else:
			_peg_px[p] = _peg_home(p)

## The tangle under the hand: the held peg carried straight from its hole to
## where it is now passes over the top of every rope whose line that crosses,
## and each of those wraps round it or slides off it right then (the rule,
## `Gen.apply_toward`, taken toward where the carry held straight on would
## meet the ring). So a rope reacts as the peg goes over it, and the drop only
## confirms what the hand already did: carried to a hole this is `state.move`.
func _carry_tangle() -> void:
	var p := _held
	var a := _hole_px(state.at[p])
	var pt := _held_pos
	var d := pt - a
	var tw := state.tw.duplicate()
	if d.length_squared() > 1.0:
		var over := 0
		for y in state.ropes:
			if y == p >> 1:
				continue
			if Geometry2D.segment_intersects_segment(a, pt, _hole_px(state.at[2 * y]), _hole_px(state.at[2 * y + 1])) != null:
				over |= 1 << y
		if over != 0:
			# The other end of the chord through the hand: a sits on the circle.
			var far := a + d * (-2.0 * (a - _c).dot(d) / d.length_squared())
			var to := fposmod(((far - _c).angle() + PI * 0.5) / TAU * state.holes, float(state.holes))
			Gen.apply_toward(state.at, tw, state.ropes, p, to, over)
	if tw == _tw_px:
		return
	var tighter := false
	var looser := false
	for k in tw.size():
		var was := _tw_px[k] >> 1 if k < _tw_px.size() else 0
		var now := tw[k] >> 1
		if now > was and was > 0:
			tighter = true
		if was >= 2 and now <= 1:
			looser = true
	_set_shown(tw)
	if tighter:
		fx.cue("cinch", 1.0 + 0.05 * randf(), -6.0)
	if looser:
		fx.cue("unwind", 1.0, -5.0)

func _ease(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)

## A flight for peg `p`: from where it is drawn to `to`, after `delay`. The
## return is the flight's end time.
func _fly(p: int, from: Vector2, to: Vector2, delay: float, dur: float, arc := 0.0) -> float:
	var t := _now() + delay
	if Motion.reduce:
		dur = 0.001
	_mv[p] = {"from": from, "to": to, "t0": t, "dur": dur, "arc": arc}
	return t + dur

func _fly_time(a: Vector2, b: Vector2) -> float:
	return clampf(a.distance_to(b) / (_ro * 3.2), FLY_MIN, FLY_MAX)

## The lift a flying peg carries above the cloth: its arc's height at `t`.
func _arc_lift(p: int, t: float) -> float:
	var m = _mv[p]
	if m == null or float(m.arc) <= 0.0 or t < float(m.t0):
		return 0.0
	var u := clampf((t - float(m.t0)) / float(m.dur), 0.0, 1.0)
	return sin(PI * u) * float(m.arc)

# --- ropes ---

## Steps every rope that is awake, at the fixed rate; returns whether any is.
func _step_ropes(dt: float, t: float) -> bool:
	var awake := false
	# The braids are laid out again only when a peg or a braid has moved.
	var key := [_peg_px, _wraps.hash()]
	if key != _bound_for:
		_bound_for = key.duplicate(true)
		_bind_all()
		_stir_at = t
		_lines_moved = true
	if Motion.reduce:
		# No swing: the ropes go straight to where they hang, a few still
		# steps a frame while anything is moving.
		var busy := _held >= 0
		for p in _mv.size():
			busy = busy or _mv[p] != null
		if busy or _dirty:
			_settle_ropes(6)
		return false
	_accum += dt
	var steps := 0
	while _accum >= Rope.SIM_DT and steps < 8:
		_accum -= Rope.SIM_DT
		steps += 1
		for r in _ropes.size():
			var rope: Rope = _ropes[r]
			if _calm[r] >= SLEEP_STEPS and not _pegs_moved(r):
				continue
			rope.extra = maxf(0.0, rope.extra - rope.extra * Rope.SIM_DT / 0.28 - 0.0004 * Rope.SIM_DT)
			if t - _stir_at > QUIET_AFTER:
				# Nothing has touched the ring for a while: a rope still
				# humming (three wrapped round each other can pull in a
				# circle) is let down to rest.
				for i in Rope.SEGS:
					rope.q[i] = rope.q[i].lerp(rope.p[i], 0.5)
			rope.step(_peg_px[2 * r], _peg_px[2 * r + 1])
			_lines_moved = true
			if rope.energy() < SLEEP_ENERGY and rope.extra < 0.0005:
				_calm[r] += 1
			else:
				_calm[r] = 0
	_accum = minf(_accum, Rope.SIM_DT * 2.0)
	for r in _ropes.size():
		if _calm[r] < SLEEP_STEPS:
			awake = true
	return awake

## Steps every rope `steps` times with no speed kept: the shape it hangs in,
## at once (a new layout, reduce-motion).
func _settle_ropes(steps: int) -> void:
	_bind_all()
	_bound_for = []
	for r in _ropes.size():
		var rope: Rope = _ropes[r]
		for i in steps:
			rope.q = rope.p.duplicate()
			rope.step(_peg_px[2 * r], _peg_px[2 * r + 1])
		rope.q = rope.p.duplicate()
		rope.extra = 0.0
	_lines_moved = true

func _pegs_moved(r: int) -> bool:
	return _held >= 0 and (_held >> 1) == r or _mv[2 * r] != null or _mv[2 * r + 1] != null

func _wake(r: int) -> void:
	_calm[r] = 0
	_stir_at = _now()

## A rope kicked sideways (`amp` px a step), given a little slack to swing.
func _whip(r: int, amp: float, slack := 0.0) -> void:
	if Motion.reduce:
		return
	(_ropes[r] as Rope).kick(amp, slack)
	_wake(r)

## Every so often one rope stirs a little, so a board left alone still
## breathes.
func _idle_whip(t: float) -> void:
	if Motion.reduce or t < _idle_at or _held >= 0 or is_done():
		return
	_idle_at = t + IDLE_WHIP_EVERY * randf_range(0.7, 1.3)
	if state.ropes > 0:
		var r := randi() % state.ropes
		_whip(r, randf_range(-1.6, 1.6), 0.006)

# --- the picture ---

func _draw() -> void:
	# A board built before its card has a size has no geometry yet.
	if _ro <= 0.0 or _rope_mesh.size() != state.ropes:
		return
	var t := _now()
	# A canvas command holds its mesh by RID, so every mesh handed over stays
	# referenced until the next draw replaces the list (see CLAUDE.md).
	var shown: Array = []
	if _ring_mesh != null:
		draw_mesh(_ring_mesh, null, Transform2D.IDENTITY, Color(1, 1, 1, _dec((t - _opened) / 0.3)))
		shown.append(_ring_mesh)
	if _under_mesh != null:
		draw_mesh(_under_mesh, null)
		shown.append(_under_mesh)
	for r in _stack:
		if int(r) >= _rope_mesh.size():
			continue
		var m: ArrayMesh = _rope_mesh[int(r)]
		if m != null:
			draw_mesh(m, null)
			shown.append(m)
	if _patch_mesh != null:
		draw_mesh(_patch_mesh, null)
		shown.append(_patch_mesh)
	if _over_mesh != null:
		draw_mesh(_over_mesh, null)
		shown.append(_over_mesh)
	_draw_peg_meshes(t, shown)
	if _extra_mesh != null:
		draw_mesh(_extra_mesh, null)
		shown.append(_extra_mesh)
	if _paw_mesh != null:
		draw_mesh(_paw_mesh, null)
		shown.append(_paw_mesh)
	_draw_toast(t, shown)
	_shown = shown
	_draw_numbers()
	_draw_zzz(t)

## A line on a dark label over the ring's top, for `hold` seconds: what the
## board wants to say that no sticker covers (a refusal, the thread running low,
## the first hint of how it plays). The line also goes to the sprout.
func _tell(key: String, mood := Face.Expr.HAPPY, hold := TOAST_HOLD) -> void:
	_say(tr(key), mood)
	_toast = key
	_toast_at = _now()
	_toast_hold = hold
	queue_redraw()

func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= _toast_hold:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE), Motion.appear_level(_toast_hold - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var line := tr(_toast)
	var font: Font = CozyTheme.body(600)
	# Under the ring, where the card is empty, clear of the corner flowers.
	var room := maxf(TOAST_PAD, size.x - 280.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / font.get_height(TOAST_FONT))))
		text_w = minf(text_room, wrapped.x)
	var w := minf(room, text_w + TOAST_PAD)
	var h := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [line, int(w), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -h) * 0.5, Vector2(w, h), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh()
		_toast_mesh_for = key
	var mid := Vector2(size.x * 0.5, minf(_c.y + _ro + _peg_r * 0.55 + 46.0 + h * 0.5, size.y - 24.0 - h * 0.5))
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

## The z's that rise off the sleeping pegs once the thread is gone.
func _draw_zzz(t: float) -> void:
	if not _out_card or _peg_px.is_empty():
		return
	var font: Font = CozyTheme.display(700)
	var fs := int(_peg_r * 0.9)
	for p in _peg_px.size():
		if p % 2 != 0 or _face[p] != 2:
			continue
		var phase := fposmod(t * 0.55 + p * 0.37, 1.0)
		var a := sin(PI * phase)
		var at: Vector2 = _peg_px[p] + Vector2(_peg_r * 0.5 + phase * _peg_r * 0.6, -_peg_r * (1.1 + phase * 1.4))
		var size_px := int(fs * (0.6 + 0.6 * phase))
		draw_string_outline(font, at, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(size_px * 0.25), Color(Pal.TEXT, 0.5 * a))
		draw_string(font, at, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color("dfe7ff", a))

## The ropes bottom to top: those that lie under most often first (so few
## crossings need a piece laid back), then the rope moved last on top, and the
## one in the hand last of all so it lies over the rest.
func _rope_stack() -> Array:
	var score := {}
	for r in state.ropes:
		score[r] = 0
	for c in _cross:
		score[int(c[0])] += 1
		score[int(c[1])] -= 1
	var stack: Array = state.order.duplicate()
	stack.sort_custom(func(a: int, b: int) -> bool:
		if int(score[a]) != int(score[b]):
			return int(score[a]) < int(score[b])
		return state.order.find(a) < state.order.find(b))
	var lifted_rope := -1
	if _held >= 0:
		lifted_rope = _held >> 1
	elif _sel >= 0:
		lifted_rope = _sel >> 1
	if lifted_rope >= 0:
		stack.erase(lifted_rope)
		stack.append(lifted_rope)
	return stack

## Rebuilds what changed: the glow under the holes, each rope that moved (a
## rope at rest keeps the mesh it has), the crossing marks with the thread and
## the kitten's yarn, the faces and hats on the pegs, and the paw.
func _rebuild(t: float) -> void:
	# The crossings are found again only when a rope's line has moved (or
	# the tangle drawn has changed); a frame that only beats a glow keeps them.
	if _lines_moved or _cross_for != _tw_px:
		_lines_moved = false
		_cross_for = _tw_px.duplicate()
		_find_crossings()
	_stack = _rope_stack()
	var b := Face.Builder.new()
	_draw_knots(b, t)
	_draw_targets(b, t)
	_under_mesh = b.mesh() if not b.verts.is_empty() else null
	for r in _ropes.size():
		_refresh_rope(r, t)
	var patches := Face.Builder.new()
	_build_patches(patches)
	_patch_mesh = patches.mesh() if not patches.verts.is_empty() else null
	# The thread row and the kitten's yarn only change when a stitch is used
	# or beats, or her count moves: kept until then.
	var over_key := _over_key(t)
	if over_key.is_empty() or over_key != _over_for:
		var over := Face.Builder.new()
		_draw_thread(over, t)
		_draw_cat_badge(over, t)
		_over_mesh = over.mesh() if not over.verts.is_empty() else null
		_over_for = over_key
	var extra := Face.Builder.new()
	_build_extras(extra, t)
	_extra_mesh = extra.mesh() if not extra.verts.is_empty() else null
	var paw := Face.Builder.new()
	_draw_paw(paw, t)
	_paw_mesh = paw.mesh() if not paw.verts.is_empty() else null

## What the thread row and the yarn are drawn from, or [] while any of it is
## moving (a stitch popping, the needle dipping or gliding, the last stitches
## or the yarn beating), when it is drawn afresh every frame.
func _over_key(t: float) -> Array:
	if Motion.reduce:
		return [state.spent, state.budget, state.moves_here, is_done(), _out_card]
	var low := state.budget > 0 and state.thread_left() <= LOW_THREAD and not is_done()
	var soon := state.cat and not state.cat_next().is_empty() and int(state.cat_next()["in"]) == 1
	if low or soon or t < _needle_dip + 0.5:
		return []
	for i in _stitch_at.size():
		if t < _stitch_at[i] + 0.5:
			return []
	if state.budget > 0 and absf(_needle_x - (_stitch_x(mini(state.spent, state.budget)) - 6.0)) > 0.5:
		return []
	return [state.spent, state.budget, state.moves_here, is_done(), _out_card, _target_peg()]

func _enter_u(p: int, t: float) -> float:
	return _dec((t - _opened - Motion.ENTER_DELAY - Motion.stagger(p, Motion.ENTER_STAGGER)) / Motion.ENTER_POP)

## Rope `r`'s mesh, rebuilt only when what it is drawn from has changed: its
## pegs, how far it is lifted or faded in, the light on it, or the rope itself
## still swinging.
func _refresh_rope(r: int, t: float) -> void:
	var col: Array = _rope_col(r)
	# The ropes come in a beat after the pegs they hang from.
	var alpha := minf(_enter_u(2 * r, t - ENTER_LAG - 0.08), _enter_u(2 * r + 1, t - ENTER_LAG - 0.08))
	if alpha <= 0.0:
		_rope_mesh[r] = null
		_rope_sig[r] = null
		_look[r] = null
		return
	var rope: Rope = _ropes[r]
	var lift := 0.0
	if (_held >= 0 and (_held >> 1) == r) or (_sel >= 0 and (_sel >> 1) == r):
		lift = maxf(_lift[2 * r], _lift[2 * r + 1])
	var flying := maxf(_arc_lift(2 * r, t), _arc_lift(2 * r + 1, t))
	lift = maxf(lift, clampf(flying / (_peg_r * FLY_ARC), 0.0, 1.0) * 0.8)
	var glow := Color(0, 0, 0, 0)
	var from := 0.0
	var to := 0.0
	if _solved_at > -INF:
		var since := t - _solved_at - Motion.SOLVE_DELAY - WAVE_STEP * float(state.order.find(r))
		if since > 0.0 and since < 1.0:
			glow = Color(Color("fff2b8"), 0.6 * sin(PI * since))
			from = clampf(since * 1.2 - 0.2, 0.0, 1.0)
			to = clampf(since * 1.2 + 0.2, 0.0, 1.0)
	var tight := clampf((rope.taut(_peg_px[2 * r], _peg_px[2 * r + 1]) - 0.965) / 0.035, 0.0, 1.0)
	_look[r] = [lift, alpha, glow, from, to, tight]
	var sig := [_peg_px[2 * r], _peg_px[2 * r + 1], lift, alpha, glow.a, from, to, tight]
	if _calm[r] >= SLEEP_STEPS and _rope_sig[r] == sig and _rope_mesh[r] != null:
		return
	_rope_sig[r] = sig
	var b := Face.Builder.new()
	rope.draw(b, _wd, col[0], col[1], col[2], lift, alpha, glow, from, to, tight)
	_rope_mesh[r] = b.mesh() if not b.verts.is_empty() else null

# --- how the ropes lie round each other ---

## The tangle as drawn. It follows state.tw, but a move's change lands with
## its peg (and the kitten's with her swat), so a wrap cinches as the peg
## drops in, not while it is still in the air.
func _set_shown(tw: PackedInt32Array, instant := false) -> void:
	_tw_px = tw.duplicate()
	for k in _tw_px.size():
		var n := _tw_px[k] >> 1
		if n >= 2:
			var e: Dictionary = _wraps.get(k, {"n": n, "w": 0.0, "goal": 1.0})
			if n > int(e.n):
				# Once more round: the braid lets go a little and cinches again.
				e.w = minf(float(e.w), 0.45)
			e.n = n
			e.goal = 1.0
			if instant or Motion.reduce:
				e.w = 1.0
			_wraps[k] = e
			_wake_pair(k)
		elif _wraps.has(k):
			if instant or Motion.reduce:
				_wraps.erase(k)
			else:
				_wraps[k].goal = 0.0
			_wake_pair(k)
	_dirty = true

func _wake_pair(k: int) -> void:
	var pr := Gen.pair_of(k, state.ropes)
	if pr.y < _calm.size():
		_calm[pr.x] = 0
		_calm[pr.y] = 0

## Braids cinch in and let go on their own clock.
func _update_wraps(dt: float) -> void:
	var gone: Array = []
	for k in _wraps:
		var e: Dictionary = _wraps[k]
		var goal: float = e.goal
		if absf(float(e.w) - goal) > 0.0001:
			var rate := BRAID_CINCH if goal > float(e.w) else BRAID_LET_GO
			e.w = goal if Motion.reduce else move_toward(float(e.w), goal, dt / rate)
			_wake_pair(k)
		if goal <= 0.0 and float(e.w) <= 0.0:
			gone.append(k)
	for k in gone:
		_wraps.erase(k)

## Where a wrapped pair's braid lies: where two ropes pulled tight round each
## other meet, the point nearest all four pegs -- the crossing of the lines
## between them (where the pegs interleave, the ropes' own crossing; side by
## side, where the diagonals of the four pegs cross) -- along the way both run,
## as long as its turns need. {"c", "axis", "perp", "len", "n", "sb" (+1 when
## the second rope runs the same way as the first), "a", "b", "w"}.
func _braid(k: int) -> Dictionary:
	var pr := Gen.pair_of(k, state.ropes)
	var e: Dictionary = _wraps[k]
	var n: int = e.n
	var a0 := _peg_px[2 * pr.x]
	var a1 := _peg_px[2 * pr.x + 1]
	var b0 := _peg_px[2 * pr.y]
	var b1 := _peg_px[2 * pr.y + 1]
	var c := (a0 + a1 + b0 + b1) * 0.25
	var axis: Vector2
	var sb := 1.0
	var hit = Geometry2D.segment_intersects_segment(a0, a1, b0, b1)
	if hit != null:
		c = hit
		var da := (a1 - a0).normalized()
		var db := (b1 - b0).normalized()
		sb = 1.0 if da.dot(db) >= 0.0 else -1.0
		axis = da + db * sb
	else:
		# Side by side: a0 shares a side of the braid with the end of the
		# other rope it can be joined to without crossing, a1 with the other.
		var with0: bool = Geometry2D.segment_intersects_segment(a0, b0, a1, b1) == null
		var bx := b0 if with0 else b1
		var by := b1 if with0 else b0
		sb = 1.0 if with0 else -1.0
		var mid = Geometry2D.segment_intersects_segment(a0, by, a1, bx)
		if mid != null:
			c = mid
		axis = (a1 + by) * 0.5 - (a0 + bx) * 0.5
	axis = axis.normalized() if axis.length_squared() > 0.0001 else (a1 - a0).normalized()
	var L := float(n) * BRAID_PITCH * _wd
	# A wrap takes no rope further than it reaches: the point nearest all four
	# pegs can be far out of a short rope's way (its pegs side by side, the
	# other rope across the ring), and the rope would be sent out there and
	# back in a hairpin. The braid is pulled toward the shorter rope instead,
	# and is never longer than the gap between a rope's pegs.
	for r in [pr.x, pr.y]:
		var p0 := _peg_px[2 * r]
		var p1 := _peg_px[2 * r + 1]
		L = minf(L, maxf(p0.distance_to(p1) * 0.9, L * BRAID_SHORTEST))
	for r in [pr.x, pr.y]:
		var p0 := _peg_px[2 * r]
		var p1 := _peg_px[2 * r + 1]
		var most: float = (_ropes[r] as Rope).length * BRAID_WAY_OF_LENGTH
		if p0.distance_to(c) + c.distance_to(p1) <= most:
			continue
		var mid := (p0 + p1) * 0.5
		var lo := 0.0
		var hi := 1.0
		for it in 12:
			var m := (lo + hi) * 0.5
			var q := c.lerp(mid, m)
			if p0.distance_to(q) + q.distance_to(p1) > most:
				lo = m
			else:
				hi = m
		c = c.lerp(mid, hi)
	# A braid lies on the cloth inside the ring, never over the wood: its
	# middle is kept far enough in that both its ends are.
	var out := (c - _c).normalized() if c.distance_to(_c) > 0.001 else Vector2.RIGHT
	var room := _ri - _wd * 1.1 - absf(axis.dot(out)) * L * 0.5
	if c.distance_to(_c) > room:
		c = _c + out * maxf(room, 0.0)
	var perp := axis.orthogonal()
	var b_start := b0 if sb > 0.0 else b1
	if (a0 - c).dot(perp) - (b_start - c).dot(perp) < 0.0:
		perp = -perp
	return {"c": c, "axis": axis, "perp": perp, "len": L, "n": n, "sb": sb,
		"a": pr.x, "b": pr.y, "w": float(e.w), "k": k}

## A point of a braid: `side` +1 for its first rope, -1 for its second, `u`
## from 0 to 1 along it. The two swing across each other `n` times.
func _braid_point(br: Dictionary, side: float, u: float) -> Vector2:
	var L: float = br.len
	return (br.c as Vector2) + (br.axis as Vector2) * (u - 0.5) * L \
		+ (br.perp as Vector2) * side * BRAID_SIDE * _wd * cos(PI * float(br.n) * u)

## Every rope's way round the braids it is in: pulled tight, a wrapped rope
## runs straight from its peg into the first braid, along it, straight on to
## the next and so to its other peg. The chain is held to that way -- firmly
## along a braid, gently along the legs, so it still swings when it is kicked
## and a braid cinches and lets go -- and its rest length is the way's.
func _bind_all() -> void:
	_laid = {}
	for k in _wraps:
		if float(_wraps[k].w) > 0.001:
			_laid[k] = _braid(k)
	_space_braids(_laid)
	var per_rope := {}
	for k in _laid:
		var br: Dictionary = _laid[k]
		for which in 2:
			var r: int = br.a if which == 0 else br.b
			var side := 1.0 if which == 0 else -1.0
			var dir := 1.0 if which == 0 else float(br.sb)
			var a := _peg_px[2 * r]
			var b := _peg_px[2 * r + 1]
			var ab := b - a
			var u := clampf((br.c - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.05, 0.95)
			if not per_rope.has(r):
				per_rope[r] = []
			per_rope[r].append([u, br, side, dir])
	for r in _ropes.size():
		var rope: Rope = _ropes[r]
		if not per_rope.has(r):
			rope.set_binds(PackedInt32Array(), PackedVector2Array(), PackedFloat32Array(), [], 0.0)
			continue
		var bi := PackedInt32Array()
		var bat := PackedVector2Array()
		var bk := PackedFloat32Array()
		var wg: Array = []
		var list: Array = per_rope[r]
		list.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		var a := _peg_px[2 * r]
		var b := _peg_px[2 * r + 1]
		# The way: corners, and which stretches of it are braids.
		var way := PackedVector2Array([a])
		var firm: Array[bool] = [false]
		var most := 0.0
		for item in list:
			var br: Dictionary = item[1]
			var dir: float = item[3]
			# Each rope comes into the braid on its own side of its line and
			# leaves on the side its turns bring it to, so the two never meet
			# on the way in; the twist between is drawn (Rope._twist).
			var enter := _braid_point(br, float(item[2]), 0.0 if dir > 0.0 else 1.0)
			var leave := _braid_point(br, float(item[2]), 1.0 if dir > 0.0 else 0.0)
			way.append(enter)
			firm.append(false)
			way.append(leave)
			firm.append(true)
			most = maxf(most, float(br.w))
			var turn := (1.0 - float(br.w)) * BRAID_SPIN * (1.0 if float(_wraps[br.k].goal) > 0.0 else -1.0)
			wg.append({"c": br.c, "axis": br.axis, "perp": br.perp, "len": br.len, "n": br.n,
				"side": item[2], "w": br.w, "swing": BRAID_SIDE * _wd, "spin": turn})
		way.append(b)
		firm.append(false)
		var cum := Rope.lengths(way)
		var total: float = cum[cum.size() - 1]
		var way_len := lerpf(a.distance_to(b), total, most)
		var seg := 1
		for i in range(1, Rope.SEGS - 1):
			var s := total * float(i) / float(Rope.SEGS - 1)
			while seg < cum.size() - 1 and cum[seg] < s:
				seg += 1
			var span := cum[seg] - cum[seg - 1]
			var u := (s - cum[seg - 1]) / span if span > 0.0 else 0.0
			var at := way[seg - 1].lerp(way[seg], u)
			var k := BRAID_PULL if firm[seg] else BRAID_LEG
			if firm[seg]:
				k *= 0.35 + 0.65 * smoothstep(0.0, 0.25, u) * smoothstep(1.0, 0.75, u)
			bi.append(i)
			bat.append(at)
			bk.append(k * most)
		# Each braid's twist is laid only on the stretch of chain held to it
		# (way pieces: peg, enter, leave, enter, leave ... peg), so a twist
		# never reaches into the next braid's stretch or the legs.
		for m in list.size():
			var per := float(Rope.SEGS - 1) / maxf(total, 1.0)
			wg[m]["i0"] = cum[2 * m + 1] * per
			wg[m]["i1"] = cum[2 * m + 2] * per
		rope.set_binds(bi, bat, bk, wg, way_len)

## A braid laid out now, spaced along its ropes when `_bind_all` has laid it.
func _braid_laid(k: int) -> Dictionary:
	return _laid[k] if _laid.has(k) else _braid(k)

## A rope's braids lie one after another along it. A rope wrapped round
## several ropes that cross close together (one carry over a bunch does it)
## would have them overlap: the way would run into one, out past the start of
## the next and back -- a fold, drawn as a torn knot. So where two of a rope's
## braids overlap along it they are pushed apart along it, and a rope without
## the room for all of them has them shortened first.
func _space_braids(brs: Dictionary) -> void:
	var per := {}
	for k in brs:
		for r in [int(brs[k].a), int(brs[k].b)]:
			if not per.has(r):
				per[r] = []
			per[r].append(k)
	var gap := _wd * 0.5
	for r in per:
		var list: Array = per[r]
		if list.size() < 2:
			continue
		var ab := _peg_px[2 * r + 1] - _peg_px[2 * r]
		var dir := ab.normalized()
		var need := 0.0
		for k in list:
			need += float(brs[k].len) * absf((brs[k].axis as Vector2).dot(dir)) + gap
		var fit := clampf(ab.length() * 0.8 / maxf(need, 1.0), BRAID_SHORTEST, 1.0)
		for k in list:
			brs[k].len = float(brs[k].len) * fit
	for it in 6:
		var moved := false
		for r in per:
			var list: Array = per[r]
			if list.size() < 2:
				continue
			var a := _peg_px[2 * r]
			var dir := (_peg_px[2 * r + 1] - a).normalized()
			list.sort_custom(func(x, y) -> bool: return ((brs[x].c as Vector2) - a).dot(dir) < ((brs[y].c as Vector2) - a).dot(dir))
			for i in range(1, list.size()):
				var b0: Dictionary = brs[list[i - 1]]
				var b1: Dictionary = brs[list[i]]
				var h0 := float(b0.len) * 0.5 * absf((b0.axis as Vector2).dot(dir))
				var h1 := float(b1.len) * 0.5 * absf((b1.axis as Vector2).dot(dir))
				var over := h0 + h1 + gap - ((b1.c as Vector2) - a).dot(dir) + ((b0.c as Vector2) - a).dot(dir)
				if over > 0.5:
					b0.c = (b0.c as Vector2) - dir * over * 0.5
					b1.c = (b1.c as Vector2) + dir * over * 0.5
					moved = true
		if not moved:
			break
	for k in brs:
		_keep_in(brs[k])

## A braid lies on the cloth inside the ring, never over the wood: its middle
## is kept far enough in that both its ends are.
func _keep_in(br: Dictionary) -> void:
	var c: Vector2 = br.c
	var axis: Vector2 = br.axis
	var out := (c - _c).normalized() if c.distance_to(_c) > 0.001 else Vector2.RIGHT
	var room := _ri - _wd * 1.1 - absf(axis.dot(out)) * float(br.len) * 0.5
	if c.distance_to(_c) > room:
		br.c = _c + out * maxf(room, 0.0)

## Every crossing as it is drawn, off the ropes as they hang: for each pair
## that crosses, where their lines meet, and at each meeting which of the two
## the tangle says is on top (a wrapped pair's alternate along the first
## rope). [over rope, under rope, s on over, s on under, point].
func _find_crossings() -> void:
	_cross = []
	var cache := {}
	for k in _tw_px.size():
		if _tw_px[k] >> 1 == 0:
			continue
		# A pair is searched again only when either rope's line (its `ver`),
		# its pegs, the tangle or its braid has changed: carrying one peg
		# moves one rope, and the other pairs keep what they had.
		var pr := Gen.pair_of(k, state.ropes)
		var key := [(_ropes[pr.x] as Rope).ver, (_ropes[pr.y] as Rope).ver, _tw_px[k],
			_peg_px[2 * pr.x], _peg_px[2 * pr.x + 1], _peg_px[2 * pr.y], _peg_px[2 * pr.y + 1]]
		if _wraps.has(k):
			var br := _braid_laid(k)
			key.append_array([float(_wraps[k].w) > 0.3, br.c, br.len])
		var kept = _cross_kept.get(k)
		if kept != null and kept[0] == key:
			_cross.append_array(kept[1])
			cache[k] = kept
			continue
		var from := _cross.size()
		_pair_crossings(k, pr)
		cache[k] = [key, _cross.slice(from)]
	_cross_kept = cache

## Pair `k`'s crossings appended to _cross.
func _pair_crossings(k: int, pr: Vector2i) -> void:
	var near: Vector2
	var radius: float
	if _wraps.has(k) and float(_wraps[k].w) > 0.3:
		var br := _braid_laid(k)
		near = br.c
		radius = float(br.len) * 0.55 + _wd * 1.2
	else:
		var hit = Geometry2D.segment_intersects_segment(_peg_px[2 * pr.x], _peg_px[2 * pr.x + 1], _peg_px[2 * pr.y], _peg_px[2 * pr.y + 1])
		var bent := not (_ropes[pr.x] as Rope).wiggles.is_empty() or not (_ropes[pr.y] as Rope).wiggles.is_empty()
		if bent:
			# A rope bent round a braid of its own crosses this one
			# somewhere else than the pegs' lines say (two to nine widths
			# off, measured): search wide, and keep the meeting nearest
			# where the lines cross.
			var aim: Vector2 = hit if hit != null else (_peg_px[2 * pr.x] + _peg_px[2 * pr.x + 1] + _peg_px[2 * pr.y] + _peg_px[2 * pr.y + 1]) * 0.25
			var all: Array = (_ropes[pr.x] as Rope).hits(_ropes[pr.y], aim, _wd * 10.0, BRAID_SIDE * _wd)
			if all.is_empty():
				return
			var best: Array = all[0]
			for h in all:
				if (h[2] as Vector2).distance_to(aim) < (best[2] as Vector2).distance_to(aim):
					best = h
			var top := _tw_px[k] & 1
			var reach := _wd * PATCH_HALF * 2.0
			if top == 1:
				_cross.append([pr.x, pr.y, best[0], best[1], best[2], reach])
			else:
				_cross.append([pr.y, pr.x, best[1], best[0], best[2], reach])
			return
		if hit == null:
			return
		near = hit
		radius = _wd * 1.8
	var hs: Array = (_ropes[pr.x] as Rope).hits(_ropes[pr.y], near, radius, BRAID_SIDE * _wd if _wraps.has(k) else 2.0)
	var t0 := _tw_px[k] & 1
	for i in hs.size():
		var top := t0 if i % 2 == 0 else 1 - t0
		var h: Array = hs[i]
		# A piece laid back reaches halfway to the pair's next crossing
		# (in a braid, where the two have swung furthest apart), so it
		# never ends where the other still lies over it.
		var reach := _wd * PATCH_HALF * 2.0
		var here: float = h[0] if top == 1 else h[1]
		for j in [i - 1, i + 1]:
			if j >= 0 and j < hs.size():
				var there: float = hs[j][0] if top == 1 else hs[j][1]
				reach = minf(reach, absf(there - here) * 0.5)
		reach = maxf(reach, _wd * 0.55)
		if top == 1:
			_cross.append([pr.x, pr.y, h[0], h[1], h[2], reach])
		else:
			_cross.append([pr.y, pr.x, h[1], h[0], h[2], reach])

## A soft coral halo under each crossing, once few enough remain to read, so
## what is left to undo shows round the ropes without covering which lies on
## top.
func _draw_knots(b: Face.Builder, t: float) -> void:
	_knot_alpha = clampf((KNOT_FADE - _cross.size()) / KNOT_SPAN, 0.0, 1.0)
	if _knot_alpha <= 0.0 or _solved_at > -INF or _out_card:
		return
	for c in _cross:
		var at: Vector2 = c[4]
		var beat := 1.0 if Motion.reduce else 0.5 + 0.5 * sin(t * 3.6 + int(c[0]) * 1.7)
		var r := _wd * (1.05 + 0.12 * beat)
		Scenery.soft_disc(b, at, r * 1.6, r * 1.6, Color(KNOT_HALO, (0.22 + 0.08 * beat) * _knot_alpha))

## The short pieces of rope laid back over the ropes they cross on top of,
## where the stack has them under: a crossing's own over and under, whatever
## order the ropes are drawn in.
func _build_patches(b: Face.Builder) -> void:
	var rank := {}
	for i in _stack.size():
		rank[int(_stack[i])] = i
	for c in _cross:
		var half: float = c[5]
		var o: int = c[0]
		var u: int = c[1]
		if int(rank.get(o, 0)) > int(rank.get(u, 0)) or o >= _look.size() or _look[o] == null:
			continue
		var look: Array = _look[o]
		var col: Array = _rope_col(o)
		var s: float = c[2]
		(_ropes[o] as Rope).draw(b, _wd, col[0], col[1], col[2], look[0], look[1], look[2], look[3], look[4], look[5],
			s - half, s + half, 0.85)

## The glow on every empty hole the lifted peg can go to, and the reticle on
## the one it is over.
func _draw_targets(b: Face.Builder, t: float) -> void:
	var lifted := _held if _held >= 0 else _sel
	if lifted < 0:
		return
	var pulse := 1.0 if Motion.reduce else 0.5 + 0.5 * sin(t * 6.0)
	var u := _lift[lifted]
	for h in state.holes:
		if state.occ[h] >= 0:
			continue
		var code := state.drop_check(lifted, h)
		var at := _hole_px(h)
		if code == 0:
			var r := _hole_r * (1.25 + 0.12 * pulse)
			Scenery.soft_disc(b, at, r * 1.7, r * 1.7, Color(Pal.SUN, (0.20 + 0.10 * pulse) * u))
			b.stroke(Face.Builder.arc_points(at, r, 0.0, TAU), 4.0, Color(Pal.SUN, (0.75 - 0.2 * pulse) * u), true)
		elif h == _hot_far:
			b.stroke(Face.Builder.arc_points(at, _hole_r * 1.1, 0.0, TAU), 4.0, Color(KNOT_HALO, 0.6 * u), true)
			var k := _hole_r * 0.42
			b.stroke(PackedVector2Array([at + Vector2(-k, -k), at + Vector2(k, k)]), 5.0, Color(KNOT_HALO, 0.7 * u), false, true)
			b.stroke(PackedVector2Array([at + Vector2(k, -k), at + Vector2(-k, k)]), 5.0, Color(KNOT_HALO, 0.7 * u), false, true)
	if _hot >= 0:
		var at := _hole_px(_hot)
		var r := _hole_r * (1.42 - 0.08 * pulse)
		b.stroke(Face.Builder.arc_points(at, r, 0.0, TAU), 5.0, Color(KNOT_HALO, 0.95 * u), true)
		for k in 4:
			var d := Vector2.from_angle(k * PI * 0.5)
			b.stroke(PackedVector2Array([at + d * r * 0.7, at + d * r * 1.32]), 5.0, Color(KNOT_HALO, 0.95 * u), false, true)
	# The kitten's foreseen swipe: her peg's ghost on the hole it would land in.
	if not _ghost.is_empty():
		var gp: int = _ghost[0]
		var to := _hole_px(int(_ghost[2]))
		var col: Array = _rope_col(gp >> 1)
		b.disc(to, _peg_r * 0.95, Color(col[0], 0.42))
		b.stroke(Face.Builder.arc_points(to, _peg_r * 1.05, 0.0, TAU), 4.0, Color(PAW, 0.9), true)
		_paw_glyph(b, to, _peg_r * 0.6, Color(PAW, 0.95))

## The peg meshes, built once per layout: for each rope the cap with its
## coloured inlay, and the cap without it (under a face). Drawn scaled about the
## peg's centre, so a squash or a lift is a transform and not a rebuild.
func _build_peg_meshes() -> void:
	_peg_mesh = []
	_peg_arrays = []
	_rest_mesh = null
	_rest_for = []
	var R := _peg_r
	for r in state.ropes:
		var col: Array = _rope_col(r)
		var pair: Array = []
		for inlay in [true, false]:
			var b := Face.Builder.new()
			b.ellipse(Vector2(0.0, R * 0.1), R, R, CAP_DEEP)
			b.ellipse(Vector2.ZERO, R * 0.97, R * 0.97, CAP_SIDE)
			b.ellipse(Vector2(0.0, -R * 0.06), R * 0.8, R * 0.78, CAP)
			b.ellipse(Vector2(-0.27, -0.32) * R, R * 0.27, R * 0.19, Color(CAP_HI, 0.85))
			if inlay:
				# The inlay in the rope's own colour, so a peg's twin can be found.
				b.disc(Vector2(0.0, -R * 0.06), R * 0.4, col[1])
				b.disc(Vector2(0.0, -R * 0.08), R * 0.32, col[0])
				b.disc(Vector2(-0.1, -0.16) * R, R * 0.1, Color(col[2], 0.9))
			pair.append(b.mesh())
		_peg_mesh.append(pair)
		_peg_arrays.append([pair[0].surface_get_arrays(0), pair[1].surface_get_arrays(0)])

func _peg_height(p: int, t: float) -> float:
	return _lift[p] + _arc_lift(p, t) / maxf(_peg_r, 1.0)

## Every peg, held and flying ones last so they ride over the rest: its shadow
## (the family's soft disc, parted from it while it is lifted) and its cap.
## The pegs sitting still in their holes -- all of them, most of the time --
## are one baked mesh, made again only when one starts or stops moving or
## changes face (a peg was two draw calls of its own, eighteen pegs on
## Insane: the board's biggest share of a frame at rest).
func _draw_peg_meshes(t: float, shown: Array) -> void:
	if _peg_mesh.is_empty() or _peg_px.is_empty():
		return
	var order: Array = range(_peg_px.size())
	order.sort_custom(func(a: int, c: int) -> bool:
		return _peg_height(a, t) < _peg_height(c, t))
	var soft := Scenery.shadow()
	shown.append(soft)
	var R := _peg_r
	var still: Array = []
	var moving: Array = []
	for p in order:
		var pop := Motion.pop_in_scale(maxf(0.0, t - _opened - Motion.ENTER_DELAY - Motion.stagger(p, Motion.ENTER_STAGGER) - ENTER_LAG), Motion.POP_IN)
		if Motion.reduce:
			pop = Vector2.ONE
		if _enter_u(p, t) <= 0.0 and t < _opened + Motion.ENTER_DELAY + 0.2:
			continue
		var up := _peg_height(p, t)
		var c := _peg_px[p]
		var sq := 1.0
		var since := t - _sq_at[p]
		if since >= 0.0 and since < LAND_SQUASH and not Motion.reduce:
			sq = 1.0 + 0.16 * sin(PI * since / LAND_SQUASH)
		var shake := 0.0
		var sh := t - _shake_at[p]
		if sh >= 0.0 and sh < 0.4 and not Motion.reduce:
			shake = sin(sh * 54.0) * (1.0 - sh / 0.4) * R * 0.22
		var variant := 1 if _face[p] != 0 else 0
		if up == 0.0 and sq == 1.0 and shake == 0.0 and pop == Vector2.ONE:
			still.append_array([p, variant, c])
			continue
		var scale := 1.0 + (PEG_LIFT_SCALE - 1.0) * clampf(up, 0.0, 1.6)
		var sx := scale * pop.x * (1.0 / sq if sq > 1.0 else 1.0)
		var sy := scale * pop.y * sq
		var lift_px := HOLD_LIFT * R * _lift[p] + _arc_lift(p, t)
		var at := c + Vector2(shake, -lift_px)
		var shadow_at := c + Vector2(0.1, 0.26) * R + Vector2(0.14, 0.3) * lift_px
		var spread := 1.0 + 0.5 * clampf(up, 0.0, 1.5)
		var alpha := (0.24 - 0.09 * clampf(up, 0.0, 1.0)) * clampf(pop.y, 0.0, 1.0)
		moving.append([soft, Transform2D(0.0, Vector2(R * 1.02 * spread * pop.x, R * 0.66 * spread * pop.y) / Scenery.SHADOW_UNIT, 0.0, shadow_at), Color(Pal.TEXT, alpha)])
		moving.append([_peg_mesh[p >> 1][variant], Transform2D(0.0, Vector2(sx, sy), 0.0, at), Color.WHITE])
	if still != _rest_for:
		_rest_for = still
		_rest_mesh = _bake_rest(still) if not still.is_empty() else null
	if _rest_mesh != null:
		draw_mesh(_rest_mesh, null)
		shown.append(_rest_mesh)
	for d in moving:
		draw_mesh(d[0], null, d[1], d[2])
		shown.append(d[0])

## The still pegs (`still` is [peg, variant, centre] flat) as one mesh: each
## peg's shadow then its cap, as _draw_peg_meshes draws a peg at rest.
func _bake_rest(still: Array) -> ArrayMesh:
	var R := _peg_r
	var shadow: Array = Scenery.shadow().surface_get_arrays(0)
	var shade := Color(Pal.TEXT, 0.24)
	var b := Face.Builder.new()
	for i in range(0, still.size(), 3):
		var p: int = still[i]
		var c: Vector2 = still[i + 2]
		_append_arrays(b, shadow, Transform2D(0.0, Vector2(R * 1.02, R * 0.66) / Scenery.SHADOW_UNIT, 0.0, c + Vector2(0.1, 0.26) * R), shade)
		_append_arrays(b, _peg_arrays[p >> 1][int(still[i + 1])], Transform2D(0.0, c), Color.WHITE)
	return b.mesh()

## Builder.append for arrays already read off a mesh.
static func _append_arrays(b: Face.Builder, a: Array, xf: Transform2D, tint: Color) -> void:
	var base := b.verts.size()
	var vs: PackedVector2Array = a[Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for v in vs:
		b.verts.append(xf * v)
	if tint == Color.WHITE:
		b.cols.append_array(cs)
	else:
		for c in cs:
			b.cols.append(c * tint)
	for i in ix:
		b.idx.append(base + i)

## Faces, hats and the kitten's paw print, over the caps: everything on a peg
## that is not the cap.
func _build_extras(b: Face.Builder, t: float) -> void:
	if _peg_px.is_empty():
		return
	var order: Array = range(_peg_px.size())
	var target := _target_peg()
	for p in order:
		var mode: int = _face[p]
		var hat: bool = _hat_at[p] > -50.0
		var paw: bool = state.cat and mode == 0 and target == p and not is_done() and not _out_card
		if mode == 0 and not hat and not paw:
			continue
		var R := _peg_r
		var up := _peg_height(p, t)
		var pop := Motion.pop_in_scale(maxf(0.0, t - _opened - Motion.ENTER_DELAY - Motion.stagger(p, Motion.ENTER_STAGGER) - ENTER_LAG), Motion.POP_IN)
		if Motion.reduce:
			pop = Vector2.ONE
		var scale := 1.0 + (PEG_LIFT_SCALE - 1.0) * clampf(up, 0.0, 1.6)
		var shake := 0.0
		var sh := t - _shake_at[p]
		if sh >= 0.0 and sh < 0.4 and not Motion.reduce:
			shake = sin(sh * 54.0) * (1.0 - sh / 0.4) * R * 0.22
		var at: Vector2 = _peg_px[p] + Vector2(shake, -(HOLD_LIFT * R * _lift[p] + _arc_lift(p, t)))
		if mode != 0:
			_draw_face(b, at, R * Vector2(scale * pop.x, scale * pop.y), p, mode, t)
		if hat:
			_draw_hat(b, at, R * scale, p, t)
		if paw:
			_paw_glyph(b, at + Vector2(0.0, R * 0.02), R * 0.5, Color(PAW, 0.95))

func _target_peg() -> int:
	var nxt: Dictionary = state.cat_next()
	if nxt.is_empty():
		return -1
	return int(nxt.peg)

## Joy, sleep or strain drawn on a cap, replacing the inlay.
func _draw_face(b: Face.Builder, at: Vector2, R: Vector2, p: int, mode: int, t: float) -> void:
	var grow := Motion.back_out(_dec((t - _face_at[p]) / 0.3))
	var expr := Face.Expr.JOY
	if mode == 2:
		expr = Face.Expr.SLEEPY
	elif mode == 3:
		expr = Face.Expr.STRAIN
	var eye := 0.3 if mode == 2 else 1.0
	var r := R.x * 0.82 * clampf(grow, 0.0, 1.3)
	Face.face_parts(b, r, at + Vector2(0.0, R.y * 0.0), Pal.TEXT, eye, expr)

## A party hat on a peg's cap.
func _draw_hat(b: Face.Builder, at: Vector2, R: float, p: int, t: float) -> void:
	var grow := Motion.back_out(_dec((t - _hat_at[p]) / 0.34))
	if grow <= 0.0:
		return
	var hb := Face.Builder.new()
	var style := p % 3
	Face._build_hat(hb, R * 1.0, Face.HAT_STYLES[style])
	_append(b, hb, at + Vector2(0.0, -R * 0.48), grow)

## Copies `src` into `dst`, scaled by `k` about the origin and moved to `at`.
func _append(dst: Face.Builder, src: Face.Builder, at: Vector2, k: float) -> void:
	var base := dst.verts.size()
	for i in src.verts.size():
		dst.verts.append(src.verts[i] * k + at)
		dst.cols.append(src.cols[i])
	for i in src.idx.size():
		dst.idx.append(base + src.idx[i])

## A paw print: a pad and four toes.
func _paw_glyph(b: Face.Builder, at: Vector2, r: float, col: Color) -> void:
	b.ellipse(at + Vector2(0.0, r * 0.32), r * 0.62, r * 0.5, col)
	for k in 4:
		var x := (k - 1.5) * r * 0.5
		var y := -r * (0.34 if k == 1 or k == 2 else 0.12)
		b.ellipse(at + Vector2(x, y), r * 0.2, r * 0.26, col)

# --- the thread ---

func _stitch_x(i: int) -> float:
	return PAD_X + 44.0 + i * (STITCH_W + STITCH_GAP)

func _draw_thread(b: Face.Builder, t: float) -> void:
	if state.budget <= 0:
		return
	var left := state.thread_left()
	var low := left <= LOW_THREAD and not is_done()
	var wobble := 0.0 if Motion.reduce else sin(t * 9.0) * 2.0
	# The spool.
	var sp := Vector2(PAD_X + 14.0, THREAD_Y)
	b.polygon(Face.Builder.round_rect(sp + Vector2(-13.0, -15.0), Vector2(26.0, 30.0), 6.0), Color(THREAD, 1.0))
	b.polygon(Face.Builder.round_rect(sp + Vector2(-18.0, -19.0), Vector2(36.0, 8.0), 4.0), CAP)
	b.polygon(Face.Builder.round_rect(sp + Vector2(-18.0, 11.0), Vector2(36.0, 8.0), 4.0), CAP)
	for k in 3:
		b.stroke(PackedVector2Array([sp + Vector2(-11.0, -8.0 + k * 8.0), sp + Vector2(11.0, -4.0 + k * 8.0)]), 2.4, Color(THREAD_DEEP, 0.7), false, false)
	for i in state.budget:
		var spent := i < state.spent
		var at := Vector2(_stitch_x(i) + STITCH_W * 0.5, THREAD_Y)
		var since := t - _stitch_at[i]
		if spent:
			# A used stitch is a faint ghost; the one just used pops.
			var pop := 1.0
			if since >= 0.0 and since < 0.4 and not Motion.reduce:
				pop = 1.0 + 0.5 * sin(PI * since / 0.4)
			b.polygon(_stitch_shape(at, pop), Color(THREAD_GONE, 0.32))
		else:
			var beat := 0.0
			if low and not Motion.reduce:
				beat = 0.5 + 0.5 * sin(t * 6.0 - i)
			var bounce := 0.0
			if since >= 0.0 and since < 0.5 and not Motion.reduce:
				bounce = -sin(PI * since / 0.5) * 8.0
			var col := THREAD.lerp(KNOT_HALO, beat * 0.5)
			b.polygon(_stitch_shape(at + Vector2(0.0, bounce), 1.0 + 0.1 * beat), THREAD_DEEP)
			b.polygon(_stitch_shape(at + Vector2(0.0, bounce - 1.5), 0.9 + 0.1 * beat), col)
	# The needle sits at the next stitch, and dips as one is made.
	var goal := _stitch_x(mini(state.spent, state.budget)) - 6.0
	_needle_x = goal if Motion.reduce else lerpf(_needle_x, goal, 0.2)
	var dip := 0.0
	var since_dip := t - _needle_dip
	if since_dip >= 0.0 and since_dip < 0.5 and not Motion.reduce:
		dip = sin(PI * since_dip / 0.5) * 12.0
	var ny := THREAD_Y - 22.0 + dip + wobble * 0.3
	var tip := Vector2(_needle_x + 8.0, ny + 22.0)
	var tail := Vector2(_needle_x - 46.0, ny - 18.0)
	b.stroke(PackedVector2Array([tail, tip]), 4.2, Color("b6bcc4"), false, true)
	b.stroke(PackedVector2Array([tail + Vector2(2.0, -1.0), tip + Vector2(-2.0, -2.0)]), 1.6, Color("f4f7fa"), false, false)
	b.stroke(Face.Builder.arc_points(tail + Vector2(3.0, 2.0), 4.0, 0.0, TAU), 1.8, Color("8b929b"), true)
	# The thread from the needle's eye back toward the spool.
	var curve := Face.Builder.bezier2(tail + Vector2(3.0, 2.0), Vector2((tail.x + sp.x) * 0.5, tail.y - 12.0 + wobble), sp + Vector2(16.0, -12.0))
	curve.append(sp + Vector2(16.0, -12.0))
	b.stroke(curve, 3.0, Color(THREAD, 0.8), false, false)

func _stitch_shape(at: Vector2, k: float) -> PackedVector2Array:
	return Face.Builder.round_rect(at - Vector2(STITCH_W, STITCH_H) * 0.5 * k, Vector2(STITCH_W, STITCH_H) * k, STITCH_H * 0.5 * k)

# --- the kitten's marks ---

## Her toy: a ball of yarn in the colour of the peg she is eyeing, beside her,
## with the moves until she pounces on it; and a beat of halo on the peg
## itself once she is about to.
func _draw_cat_badge(b: Face.Builder, t: float) -> void:
	if not state.cat or is_done() or _out_card:
		return
	var p := _target_peg()
	if p < 0:
		return
	var nxt: Dictionary = state.cat_next()
	var soon := int(nxt["in"]) == 1
	var beat := 0.0 if Motion.reduce else ((0.5 + 0.5 * sin(t * 7.0)) if soon else 0.0)
	var col: Array = _rope_col(p >> 1)
	var r := KITTEN_SIZE * 0.2 * (1.0 + 0.06 * beat)
	var at := _yarn_at
	Scenery.soft_disc(b, at + Vector2(r * 0.15, r * 0.95), r * 1.15, r * 0.36, Color(Pal.TEXT, 0.2))
	b.disc(at, r, col[1])
	b.disc(at + Vector2(-0.03, -0.05) * r, r * 0.93, col[0])
	for k in 3:
		var a0 := 0.5 + k * 1.05
		b.stroke(Face.Builder.arc_points(at + Vector2.from_angle(a0 + 2.2) * r * 0.5, r * 0.85, a0, a0 + 1.4), 3.0, Color(col[1], 0.75), false, false)
	b.disc(at + Vector2(-0.34, -0.38) * r, r * 0.2, Color(col[2], 0.8))
	# The loose end, curling away.
	var tail := Face.Builder.bezier2(at + Vector2(0.62, 0.7) * r, at + Vector2(1.5, 1.35) * r, at + Vector2(1.9, 0.55) * r)
	tail.append(at + Vector2(1.9, 0.55) * r)
	b.stroke(tail, 6.0, Color(col[1], 1.0), false, true)
	b.stroke(tail, 3.6, col[0], false, false)
	if soon:
		var pr := _peg_r * (1.32 + 0.1 * beat)
		b.stroke(Face.Builder.arc_points(_peg_px[p], pr, 0.0, TAU), 4.0, Color(PAW, 0.85), true)

## The number over the yarn: the moves until the kitten pounces.
func _draw_numbers() -> void:
	_draw_preview()
	if not state.cat or is_done() or _out_card or _peg_px.is_empty():
		return
	var nxt: Dictionary = state.cat_next()
	var font: Font = CozyTheme.display(700)
	var fs := int(KITTEN_SIZE * 0.22)
	var text := str(int(nxt["in"]))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := _yarn_at + Vector2(-w * 0.5, fs * 0.36)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.3), Color(Pal.TEXT, 0.85))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fffaf0"))

## Over the hole the held peg would drop into, what the drop would do: the
## crossings it undoes in green ("-2"), or the ones it makes in coral ("+1"),
## with a small loop when it would wrap a pair tighter. The knot rule is read
## off the rope on top, and this is where the player learns it.
func _draw_preview() -> void:
	if _held < 0 or _hot < 0 or _hot_preview.size() < 2 or is_done():
		return
	var delta: int = _hot_preview[0]
	var wraps: int = _hot_preview[1]
	var text := ("+%d" % delta) if delta > 0 else ("%d" % delta).replace("-", "\u2212")
	if delta == 0:
		text = "0"
	var col := Pal.GOOD.darkened(0.15) if delta < 0 else (KNOT_HALO if delta > 0 else Pal.TEXT)
	var font: Font = CozyTheme.display(700)
	var fs := int(_peg_r * 0.95)
	var hole := _hole_px(_hot)
	var out := (hole - _c).normalized()
	var at := hole + out * _peg_r * 2.25
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := at + Vector2(-w * 0.5, fs * 0.36)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.34), Color("fffaf0"))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if wraps > 0:
		var loop := at + Vector2(w * 0.5 + fs * 0.42, -fs * 0.18)
		draw_arc(loop, fs * 0.2, 0.0, TAU, 18, Color("fffaf0"), fs * 0.16)
		draw_arc(loop, fs * 0.2, 0.0, TAU, 18, KNOT_HALO, fs * 0.08)

## The paw that swats at the peg, out and back.
func _draw_paw(b: Face.Builder, t: float) -> void:
	if _paw.is_empty():
		return
	var u := (t - float(_paw.t0)) / float(_paw.dur)
	if u < 0.0:
		return
	if u > 1.0:
		_paw = {}
		return
	var out := sin(PI * minf(u * 1.05, 1.0))
	var at: Vector2 = (_paw.from as Vector2).lerp(_paw.to, out)
	var dir: Vector2 = ((_paw.to as Vector2) - (_paw.from as Vector2)).normalized()
	var arm := PackedVector2Array([_paw.from, at])
	b.stroke(arm, _peg_r * 0.9, Color(KittenFace.FUR_DEEP, 1.0), false, true)
	b.stroke(arm, _peg_r * 0.72, KittenFace.FUR, false, true)
	b.disc(at, _peg_r * 0.62, KittenFace.FUR)
	_paw_glyph(b, at + dir * _peg_r * 0.02, _peg_r * 0.5, Color(KittenFace.EAR_IN, 0.95))

# --- input ---

## Touch and drag only, as every flat board takes them: the viewport hands a
## Control both the mouse event and the emulated touch, and two would fire
## twice.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _press_peg >= 0 or _held >= 0:
			_drag(event.position)

func _can_touch() -> bool:
	return not is_done() and not _out_card and not state.is_solved() and not state.out_of_thread() and _now() >= _busy_until

func _nearest_peg(at: Vector2) -> int:
	var best := -1
	var closest := _peg_r * GRAB_R
	for p in _peg_px.size():
		var d := at.distance_to(_peg_px[p])
		if d < closest:
			closest = d
			best = p
	return best

func _nearest_hole(at: Vector2, within: float) -> int:
	var best := -1
	var closest := within
	for h in state.holes:
		var d := at.distance_to(_hole_px(h))
		if d < closest:
			closest = d
			best = h
	return best

func _press(at: Vector2) -> void:
	if not _can_touch():
		return
	# A press while a peg is still in the hand (a release that never came, a
	# second finger) puts that peg back first, so a lost release cannot lock
	# the board.
	if _held >= 0:
		var stale := _held
		_held = -1
		_hot = -1
		_hot_far = -1
		_ghost = []
		if _face[stale] == 3:
			_face[stale] = 0
		_go_home(stale, false)
	_press_at = at
	_finger = at
	_dragged = false
	var p := _nearest_peg(at)
	_press_peg = p
	if p < 0:
		# Nothing to lift: the kitten is petted, a rope is plucked.
		if state.cat and _kitten.visible and Rect2(_kitten.position, _kitten.size).grow(-KITTEN_SIZE * 0.12).has_point(at):
			_pet_kitten()
		elif _sel < 0:
			_pluck_at(at)
		return
	if not state.can_go(p) and p != _sel:
		_press_peg = -1
		_refuse(p, "UT_STUCK")
		return
	_held = p
	_grab = _peg_px[p] - at
	_held_pos = _peg_px[p]
	_held_want = _peg_px[p]
	_hot = -1
	_hot_far = -1
	_taut_sent = false
	_wake(p >> 1)
	_whip(p >> 1, WHIP_PICK, 0.012)
	fx.cue("pick")
	_dirty = true

func _drag(at: Vector2) -> void:
	_finger = at
	if _held < 0:
		return
	if not _dragged and at.distance_to(_press_at) > DRAG_SLOP:
		_dragged = true
		if _sel != _held:
			_sel = -1
	_update_held()
	_dirty = true

## Where the held peg is: on the finger, kept inside what its rope can
## reach; and which hole it is over.
func _update_held() -> void:
	var p := _held
	var want := _finger + _grab if _dragged else _held_want
	# A lifted peg hovers over the ring, not out on the cloth.
	want = _c + (want - _c).limit_length(_ro * 1.06)
	var other: Vector2 = _peg_px[p ^ 1]
	var max_len: float = (_ropes[p >> 1] as Rope).length
	var d := want.distance_to(other)
	var strain := 0.0
	if d > max_len and d > 0.0:
		# Pulled tight: the rope gives a hair, the peg strains against it.
		var over := d - max_len
		want = other + (want - other) / d * (max_len + over * 0.1)
		strain = clampf(over / (_peg_r * 2.5), 0.0, 1.0)
	_held_want = want
	if strain > 0.05 and not _taut_sent:
		_taut_sent = true
		fx.cue("taut")
		Haptics.play(Haptics.TICK)
		_whip(p >> 1, -WHIP_PICK, 0.0)
	elif strain <= 0.0:
		_taut_sent = false
	if strain > 0.35 and _face[p] != 3:
		_face[p] = 3
		_face_at[p] = _now()
	elif strain <= 0.1 and _face[p] == 3:
		_face[p] = 0
	# Which hole is it over?
	var old_hot := _hot
	_hot = -1
	_hot_far = -1
	if _dragged:
		var h := _nearest_hole(_held_want, _peg_r * SNAP_R)
		if h >= 0 and state.occ[h] < 0:
			var code := state.drop_check(p, h)
			if code == 0:
				_hot = h
			elif code == 2:
				_hot_far = h
	if _hot != old_hot:
		_ghost = []
		_hot_preview = state.preview(p, _hot) if _hot >= 0 else []
		if _hot >= 0:
			_ghost = state.foresee(p, _hot)
			fx.cue("hover", 1.0 + 0.02 * (_hot % 5), -12.0)

func _release() -> void:
	if _held >= 0:
		_update_held()
		var p := _held
		var was_far := _hot_far >= 0
		_held = -1
		_ghost = []
		# A strained face is for the hand; the peg lets go of it with the rope.
		if _face[p] == 3:
			_face[p] = 0
		if _dragged:
			var target := _hot
			_hot = -1
			_hot_far = -1
			if target >= 0:
				_sel = -1
				_drop(p, target, _held_pos)
			else:
				_sel = -1
				_go_home(p, was_far)
		else:
			# A tap on a peg selects it, or lets it go.
			if _sel == p:
				_sel = -1
				fx.cue("put", 1.0, -10.0)
			else:
				_sel = p
				_hot = -1
				_hot_far = -1
				_tell("UT_TIP_PICKED", Face.Expr.HAPPY, 2.4)
		_press_peg = -1
		_dirty = true
		return
	_press_peg = -1
	if _sel >= 0 and _can_touch():
		# A tap on a hole while a peg is selected drops it there.
		var h := _nearest_hole(_press_at, _peg_r * SNAP_R)
		var p := _sel
		if h >= 0 and state.occ[h] < 0:
			var code := state.drop_check(p, h)
			if code == 0:
				_sel = -1
				_drop(p, h, _peg_px[p] + Vector2(0.0, -_peg_r * HOLD_LIFT))
				return
			if code == 2:
				_refuse(p, "UT_TAUT")
				return
		_sel = -1
		fx.cue("put", 1.0, -10.0)
		_dirty = true

## Ends every flight and every hold at once and runs what was waiting: for a
## harness that plays a move a frame, and for a board restored.
func settle_now() -> void:
	_busy_until = 0.0
	_paw = {}
	for p in _mv.size():
		if _mv[p] != null:
			var last: Dictionary = _mv[p]
			while last.has("then"):
				last = last.then
			_peg_px[p] = last.to
			_mv[p] = null
	var pending := _later
	_later = []
	for entry in pending:
		if int(entry[2]) == _gen:
			(entry[1] as Callable).call()
	_set_shown(state.tw, true)
	_dirty = true

## The peg goes back where it was picked up.
func _go_home(p: int, refused: bool) -> void:
	var to := _peg_home(p)
	# Put back: whatever the hand wrapped or slid off on the way comes undone.
	_set_shown(state.tw)
	_fly(p, _peg_px[p], to, 0.0, HOME_TIME)
	_whip(p >> 1, WHIP_HOME, 0.01)
	if refused:
		_shake_at[p] = _now()
		fx.cue("refused")
		_tell("UT_TAUT", Face.Expr.WORRIED)
	else:
		fx.cue("put", 1.0, -10.0)
	_later_call(HOME_TIME, func() -> void:
		_sq_at[p] = _now())
	_dirty = true

func _refuse(p: int, key: String) -> void:
	_shake_at[p] = _now()
	fx.cue("refused")
	_tell(key, Face.Expr.WORRIED)
	_dirty = true

# --- a move ---

## The player drops `p` in `hole`; the peg flies the last of the way in.
func _drop(p: int, hole: int, from: Vector2, hint := false) -> void:
	var t := _now()
	var res: Dictionary = state.move(p, hole)
	if res.is_empty():
		_go_home(p, true)
		return
	_all_moves += 1
	_dirty = true
	var to := _hole_px(hole)
	var dur := _fly_time(from, to)
	var arc := _peg_r * (0.6 if hint else 0.25)
	_fly(p, from, to, 0.0, dur, arc)
	_busy_until = maxf(_busy_until, t + dur * 0.5)
	var rope := p >> 1
	_wake(rope)
	_later_call(dur * 0.85, func() -> void:
		_landed(p, hole, res, hint))
	# Thread: a stitch is used.
	if state.budget > 0:
		_use_stitch(t + dur * 0.5)
	# The kitten's swipe, if this move was the one before it.
	var swipe: Dictionary = res.cat
	if not swipe.is_empty():
		_schedule_swipe(swipe, t + dur + POUNCE_LEAD)
	_streak_update(int(res.cleared))
	if hint:
		moved.emit()
	else:
		note_move()

func _landed(p: int, hole: int, res: Dictionary, hint: bool) -> void:
	var t := _now()
	var cleared: int = res.cleared
	var left: int = res.left
	_sq_at[p] = t
	var at := _hole_px(hole)
	# A peg carried by hand has already wrapped and slid off on the way (and
	# creaked as it did); a hint's or a tapped drop's lands here.
	var fresh: bool = _tw_px != res.tw_mid
	_set_shown(res.tw_mid)
	if fresh and int(res.wrapped) > 0:
		# Round the other rope once more: the braid cinches with a creak.
		fx.cue("cinch", 1.0 + 0.05 * randf(), -4.0)
	if fresh and int(res.unwound) > 0:
		_later_call(0.12, fx.cue.bind("unwind", 1.0, -3.0))
	_whip(p >> 1, WHIP_DROP * (1.0 if p % 2 == 0 else -1.0), SLACK_DROP)
	fx.cue("drop")
	if not hint:
		# The hand's peg is home: a bump when that freed a rope or undid two
		# crossings at once (the sticker's moments), a tap otherwise.
		Haptics.play(Haptics.BUMP if cleared >= 2 or not (res.freed as Array).is_empty() else Haptics.TAP)
	fx.puff(at + Vector2(0.0, _peg_r * 0.4), Pal.WOOD, 3)
	if hint:
		fx.ring(at, _peg_r * 1.4, Pal.SUN)
		fx.sparkle(at, Pal.SUN)
	if cleared > 0:
		fx.ring(at, _peg_r * 1.6, Pal.GOOD)
		fx.sparkle(at, Pal.GOOD)
		if left > 0:
			fx.cue("untie", 1.0 + 0.06 * mini(cleared, 5), -6.0)
	if _solved_at == -INF and left > 0:
		_speak(cleared, left)
	_rewards(p, cleared, left)
	_rewards_knots(p, res)
	_dirty = true

func _streak_update(cleared: int) -> void:
	if cleared > 0:
		_streak += 1
	else:
		_streak = 0

## The words: an untied pair or two, and a run of moves that each undid one.
func _rewards(p: int, cleared: int, left: int) -> void:
	if _rw == null or is_done():
		return
	var mid := _c + Vector2(0.0, -_ro * 0.05)
	if cleared >= 2:
		var key := "UT_W_2"
		if cleared >= 6:
			key = "UT_W_6"
		elif cleared >= 4:
			key = "UT_W_4"
		elif cleared >= 3:
			key = "UT_W_3"
		_rw.sticker(tr(key), mid, 84, 1.3, true, Color.WHITE, cleared >= 4, "untie", 20.0)
		if not Motion.reduce:
			_rw.spray(_hole_px(state.at[p]), Pal.GOOD, 8 + cleared * 2, 640.0, "star", 1.0)
			_rw.spray(_hole_px(state.at[p]), Color("fffaf0"), 6, 560.0, "spark", 1.2)
		fx.cue("combo")
	elif cleared <= -3:
		_rw.sticker(tr("UT_W_OOPS"), mid + Vector2(0.0, _ro * 0.3), 52, 1.1, false, KNOT_HALO, false, "oops", 10.0)
		fx.cue("oops")
		if not Motion.reduce:
			fx.puff(_hole_px(state.at[p]), Color("f6efe3"), 4)
	if _streak >= STREAK_AT and cleared > 0:
		_rw.sticker(tr("UT_W_STREAK"), mid + Vector2(0.0, -_ro * 0.36), 60, 1.2, false, Pal.SUN_DEEP, false, "streak", 14.0)
		_streak = 0
	if left == 1 and cleared > 0:
		_rw.sticker(tr("UT_W_LAST"), mid + Vector2(0.0, _ro * 0.36), 50, 1.2, false, Pal.GOOD, false, "last", 12.0)

## The knot's own rewards: a wrap undone spins free with a sticker and a puff
## of hearts where the braid was; a rope left with no crossing at all does a
## happy wiggle, its pegs grin for a moment and it shines end to end; a wrap
## made tighter gets a sheepish "wrapped!".
func _rewards_knots(p: int, res: Dictionary) -> void:
	if _rw == null or is_done() or state.is_solved():
		return
	var mid := _c + Vector2(0.0, -_ro * 0.05)
	var t := _now()
	if int(res.unwound) > 0 and int(res.cleared) < 4:
		_rw.sticker(tr("UT_W_UNWOUND"), mid + Vector2(0.0, -_ro * 0.2), 64, 1.2, true, Color.WHITE, false, "unwound", 16.0)
		if not Motion.reduce:
			for k in _wraps:
				if float(_wraps[k].goal) <= 0.0:
					var at: Vector2 = _braid_laid(k).c
					_rw.spray(at, Color("f2a7a0"), 7, 380.0, "heart", 1.0)
					fx.ring(at, _wd * 2.2, Pal.GOOD)
	for r in res.freed:
		var rr: int = r
		for e in 2:
			var pp := 2 * rr + e
			if _face[pp] == 0:
				_face[pp] = 1
				_face_at[pp] = t + 0.1 * e
		_whip(rr, 4.5 * (1.0 if rr % 2 == 0 else -1.0), 0.02)
		if not Motion.reduce:
			var a := _peg_px[2 * rr]
			var b := _peg_px[2 * rr + 1]
			for i in 5:
				fx.sparkle(a.lerp(b, (i + 0.5) / 5.0), (_rope_col(rr)[0] as Color).lightened(0.3))
		_later_call(FREE_JOY, func() -> void:
			for e in 2:
				var pp := 2 * rr + e
				if _face[pp] == 1 and not state.is_solved() and not is_done():
					_face[pp] = 0
			_dirty = true)
	if not res.freed.is_empty() and int(res.cleared) < 2 and int(res.unwound) == 0:
		_rw.sticker(tr("UT_W_FREE"), mid + Vector2(0.0, _ro * 0.2), 48, 1.0, false, Pal.GOOD, false, "free", 10.0)
		fx.cue("free", 1.0 + 0.04 * float(res.freed.size()), -6.0)
	if int(res.wrapped) > 0 and int(res.cleared) > -3:
		_rw.sticker(tr("UT_W_WRAPPED"), mid + Vector2(0.0, _ro * 0.3), 46, 1.0, false, KNOT_HALO, false, "wrapped", -8.0)

## The words on the sprout's line.
func _speak(gone: int, left: int) -> void:
	if is_done():
		return
	if gone <= 0:
		return
	if left == 1:
		_say(tr("UT_ONE_KNOT_LEFT"), Face.Expr.HAPPY)
	elif gone == 1:
		_say(tr("UT_GONE_ONE") % left, Face.Expr.HAPPY)
	else:
		_say(tr("UT_GONE_N") % [gone, left], Face.Expr.HAPPY)

# --- thread ---

func _use_stitch(when: float) -> void:
	var i := clampi(state.spent - 1, 0, maxi(state.budget - 1, 0))
	if i < _stitch_at.size():
		_later_call(when - _now(), func() -> void:
			if i < _stitch_at.size():
				_stitch_at[i] = _now()
			_needle_dip = _now()
			fx.cue("stitch", 1.0, -14.0)
			var left := state.thread_left()
			if left == LOW_THREAD and _difficulty >= 2:
				fx.cue("thread_low", 1.0, -8.0)
				_tell("UT_THREAD_LOW", Face.Expr.WORRIED)
			_dirty = true)

# --- the kitten ---

## She stalks the marked peg and swats it into the hole she was aiming for:
## the paw comes out from the corner, the peg hops across.
func _schedule_swipe(entry: Dictionary, at_time: float) -> void:
	var p: int = entry.peg
	var from_px := _hole_px(int(entry.from))
	var to_px := _hole_px(int(entry.to))
	# Until she swipes, the peg is drawn where she found it.
	var delay := maxf(0.0, at_time - _now())
	var flight := {"from": from_px, "to": to_px, "t0": at_time + 0.22, "dur": POUNCE_FLY, "arc": _peg_r * 1.5}
	if Motion.reduce:
		flight.dur = 0.001
	if _mv[p] == null:
		_mv[p] = flight
	else:
		# The peg is still flying in from the player's drop: hers waits behind it.
		var last: Dictionary = _mv[p]
		while last.has("then"):
			last = last.then
		last["then"] = flight
	_busy_until = maxf(_busy_until, at_time + SWIPE_BUSY)
	_later_call(delay, func() -> void:
		_pounce(p, from_px, to_px))
	_later_call(delay + 0.22 + POUNCE_FLY * 0.9, func() -> void:
		_swiped(p, int(entry.to)))

## A tap on the kitten: she squints with joy and purrs, hearts float up.
func _pet_kitten() -> void:
	if _now() < _kitten_mood_until:
		return
	_kitten.expression = Face.Expr.JOY
	_kitten_mood_until = _now() + 1.2
	fx.cue("purr")
	if not Motion.reduce:
		Motion.squash(_kitten, 0.12, 0.3)
		_rw.spray(_kitten_at + Vector2(0.0, -KITTEN_SIZE * 0.2), Color("f2a7a0"), 5, 300.0, "heart", 0.9)
	_later_call(1.2, func() -> void:
		if _kitten.expression == Face.Expr.JOY and not is_done():
			_kitten.expression = Face.Expr.HAPPY)
	_dirty = true

## A press on a rope plucks it like a string: it whips and rings once. Free.
func _pluck_at(at: Vector2) -> void:
	var best := -1
	var closest := _wd * 0.9
	for r in _ropes.size():
		var chain: PackedVector2Array = (_ropes[r] as Rope).p
		for i in chain.size() - 1:
			var d := Geometry2D.get_closest_point_to_segment(at, chain[i], chain[i + 1]).distance_to(at)
			if d < closest:
				closest = d
				best = r
	if best < 0:
		return
	_whip(best, 6.0 * (1.0 if at.x < _c.x else -1.0), 0.012)
	fx.cue("taut", 1.1, -10.0)
	_dirty = true

## Where the kitten looks when she is not swatting: at her yarn.
func _gaze() -> Vector2:
	return Vector2(-1.0, 0.45)

func _pounce(p: int, from_px: Vector2, _to_px: Vector2) -> void:
	_kitten.expression = Face.Expr.JOY
	_kitten_mood_until = _now() + 1.0
	fx.cue("pounce")
	_paw = {"from": _kitten_at + Vector2(0.0, KITTEN_SIZE * 0.25), "to": from_px, "t0": _now(), "dur": 0.45}
	var dir := (from_px - _kitten_at).normalized()
	_kitten.look = dir
	if not Motion.reduce:
		Motion.squash(_kitten, 0.18, 0.3)
	_say(tr("UT_CAT_SWIPE"), Face.Expr.HAPPY)
	_dirty = true

func _swiped(p: int, hole: int) -> void:
	_sq_at[p] = _now()
	_set_shown(state.tw)
	_whip(p >> 1, WHIP_DROP, SLACK_DROP * 1.4)
	fx.cue("drop")
	fx.ring(_hole_px(hole), _peg_r * 1.5, KittenFace.FUR_DEEP)
	fx.puff(_hole_px(hole) + Vector2(0.0, _peg_r * 0.4), Pal.WOOD, 3)
	_later_call(0.6, func() -> void:
		_kitten.expression = Face.Expr.HAPPY
		_kitten.look = _gaze()
		_dirty = true)
	_dirty = true

# --- what settles ---

## True when nothing is in the hand or in flight and no hold is running.
func _settled(t: float) -> bool:
	if _held >= 0 or t < _busy_until:
		return false
	for p in _mv.size():
		if _mv[p] != null:
			return false
	return _paw.is_empty() or t > float(_paw.t0) + float(_paw.dur)

## The board is won only once everything has landed, so the win never rises
## over a peg still in the air.
func is_solved() -> bool:
	if _shown_answer:
		return false
	if is_done():
		return state.is_solved()
	return state.is_solved() and _settled(_now())

## Called every frame: a solved or ruined board that has settled ends.
func _flow(t: float) -> void:
	if is_done() or _out_card or _shown_answer:
		return
	if not _settled(t):
		return
	if state.is_solved():
		check_solved()
	elif state.out_of_thread():
		_run_out(t)
	elif state.stuck():
		# Every free hole is out of every rope's reach (the kitten can leave
		# it so): say so once for this layout.
		var key := state.at.to_byte_array()
		if key != _stuck_key:
			_stuck_key = key
			_tell("UT_STUCK_ALL", Face.Expr.WORRIED, 4.2)

# --- losing: the thread runs out ---

func _run_out(t: float) -> void:
	out_of_hearts = true
	_running = false
	_held = -1
	_sel = -1
	for p in _face.size():
		_face[p] = 2
		_face_at[p] = t + Motion.stagger(p, 0.04)
	fx.cue("thread_out")
	_tell("UT_THREAD_OUT", Face.Expr.SLEEPY, 2.4)
	_kitten.expression = Face.Expr.SLEEPY
	_busy_until = t + OUT_CARD_AFTER + 0.5
	_later_call(0.3 if Motion.reduce else OUT_CARD_AFTER, _open_card)
	_dirty = true

func _open_card() -> void:
	if not _out_card or is_done() or is_instance_valid(_card):
		return
	var card: Control = load(OUT_CARD).new(state.bought, OUT_WORDS)
	_card = card
	card.one_more_row.connect(spool_back)
	card.show_code.connect(show_answer)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

func _close_card() -> void:
	if is_instance_valid(_card) and not _card.is_queued_for_deletion():
		_card.queue_free()
	_card = null

## One more spool (the card's video), once a board: a few stitches more, and
## the pegs wake.
func spool_back() -> void:
	if is_done() or not _out_card:
		return
	_close_card()
	state.buy_spool()
	var grown := state.budget
	_stitch_at.resize(grown)
	for i in grown:
		if i >= state.spent:
			_stitch_at[i] = _now() + 0.06 * (i - state.spent)
	out_of_hearts = false
	_running = true
	for p in _face.size():
		_face[p] = 0
	_kitten.expression = Face.Expr.HAPPY
	fx.cue("spool_back")
	_rw.sticker(tr("UT_W_SPOOL"), _c, 64, 1.4, true, Color.WHITE, true, "spool", 24.0)
	if not Motion.reduce:
		_rw.spray(Vector2(size.x * 0.25, THREAD_Y), THREAD, 10, 520.0, "star", 0.9)
	_busy_until = _now() + 0.6
	moved.emit()
	_dirty = true

## Show the answer: the pegs walk to a layout where no rope crosses, and the
## day ends unsolved.
func show_answer() -> void:
	if is_done():
		return
	_close_card()
	out_of_hearts = false
	_shown_answer = true
	var t := _now()
	var walking: Array[int] = state.show_answer()
	_set_shown(state.tw)
	var k := 0
	for p in walking:
		_fly(p, _peg_px[p], _hole_px(state.at[p]), Motion.stagger(k, 0.1, 1.2), 0.42, _peg_r * 0.5)
		var pp: int = p
		_later_call(Motion.stagger(k, 0.1, 1.2) + 0.42, func() -> void:
			_sq_at[pp] = _now()
			_whip(pp >> 1, WHIP_DROP, SLACK_DROP))
		k += 1
	for p in _face.size():
		_face[p] = 0
	fx.cue("reveal")
	_tell("UT_SHOWN")
	_busy_until = t + 1.6
	finish_unsolved()
	_dirty = true

# --- the win ---

func _on_solved() -> void:
	var t := _now()
	_solved_at = t
	_held = -1
	_sel = -1
	_hot = -1
	_ghost = []
	_tip_timer.stop()
	fx.cue("solved")
	_say(tr("UT_WIN"), Face.Expr.JOY)
	_busy_until = t + WIN_HOLD
	_later_call(0.0 if Motion.reduce else HAT_AT, _party_on)
	_later_call(0.0 if Motion.reduce else STAMP_AT, _stamp_down)
	var mid := _c
	_rw.sticker(tr("UT_W_WIN"), mid + Vector2(0.0, -_ro * 0.1), 112, WIN_HOLD + 0.3, true, Color.WHITE, true, "win")
	if hints_used == 0:
		_later_call(0.5, func() -> void:
			_rw.sticker(tr("UT_W_NO_HINTS"), mid + Vector2(0.0, _ro * 0.22), 46, WIN_HOLD - 0.3, false, Pal.SUN, false, "nohints"))
	if not Motion.reduce:
		fx.ring(mid, _ro * 0.4, Pal.SUN)
		_rw.ring(mid, _ro * 0.9, Color(Pal.SUN, 0.9))
		_rw.ring(mid, _ro * 1.3, Color(Pal.GOOD, 0.6), 0.15)
		_rw.spray(mid, Pal.SUN, 18, 900.0, "star", 1.2)
		_rw.spray(mid, Color("fffaf0"), 12, 760.0, "spark", 1.3)
		_rw.rain(2.6, ["confetti", "star", "confetti"], Rewards.CONFETTI)
		# Every peg wakes with a grin, in the order the ropes lie.
		for p in _face.size():
			var wait := Motion.SOLVE_DELAY + WAVE_STEP * float(state.order.find(p >> 1))
			var pp: int = p
			_later_call(wait, func() -> void:
				_face[pp] = 1
				_face_at[pp] = _now()
				_sq_at[pp] = _now()
				var at := _peg_px[pp]
				_rw.spray(at, (_rope_col(pp >> 1)[0] as Color), 6, 560.0, "confetti", 1.0)
				fx.sparkle(at, Pal.SUN)
				_dirty = true)
		for r in state.ropes:
			_whip(r, 4.0 * (1.0 if r % 2 == 0 else -1.0), 0.02)
	else:
		for p in _face.size():
			_face[p] = 1
			_face_at[p] = t
	_kitten.expression = Face.Expr.JOY
	_dirty = true

func _party_on(quiet := false) -> void:
	if _party or not state.is_solved():
		return
	_party = true
	var t := _now()
	for p in _hat_at.size():
		_hat_at[p] = t + (0.0 if quiet or Motion.reduce else Motion.stagger(state.order.find(p >> 1), 0.07, 0.8)) - (10.0 if quiet else 0.0)
	if quiet:
		_dirty = true
		return
	fx.cue("party")
	if not Motion.reduce:
		fx.confetti(_c + Vector2(0.0, -_ro * 0.7), 44, _ro * 1.6)
		_later_call(0.25, fx.cue.bind("confetti"))
	_dirty = true

## The stamp's word: by moves beyond par (UT_STAMP_1..5), or UT_STAMP_MORE when
## the day needed one more spool. A restored daily reads it back.
func stamp_key() -> String:
	if completed_record.has("stamp") and _all_moves == 0:
		return String(completed_record.stamp)
	if _restored or (_all_moves == 0 and is_done()):
		return ""
	if state.bought:
		return "UT_STAMP_MORE"
	var extra := _all_moves - state.par + hints_used
	for i in STAMP_STEPS.size():
		if extra <= int(STAMP_STEPS[i]):
			return "UT_STAMP_%d" % (i + 1)
	return "UT_STAMP_5"

func completion_record() -> Dictionary:
	return {"stamp": stamp_key()} if stamp_key() != "" else {}

func _clear_stamp() -> void:
	if is_instance_valid(_stamp):
		_stamp.queue_free()
	_stamp = null

func _stamp_down(quiet := false) -> void:
	if is_instance_valid(_stamp) or not state.is_solved() or _shown_answer or stamp_key() == "":
		return
	# A board restored before its first layout has no ring yet: the seal is cut
	# at full size and _place_stamp scales it once the ring is known.
	var rad := STAMP_R if _ri <= 0.0 else minf(STAMP_R, _ri * 0.5)
	var insane := state.cat
	var stamp := Control.new()
	stamp.name = "Stamp"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.z_index = 3
	stamp.size = Vector2.ONE * rad * 2.0
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation = -0.12
	var mesh := Seal.mesh(rad, insane)
	var word: String = tr(stamp_key())
	var lines := [[Seal.tr_static("UT_CAT_SEAL"), 0.24, 0.02], [word, 0.22, 0.36]] if insane \
		else [[word, 0.28, 0.12]]
	stamp.draw.connect(func() -> void:
		stamp.draw_mesh(mesh, null, Transform2D(0.0, stamp.pivot_offset))
		Seal.text(stamp, rad, lines))
	add_child(stamp)
	_stamp = stamp
	_stamp_rad = rad
	stamp.position = _c + Vector2(_ri * 0.02, _ri * 0.18) - stamp.pivot_offset
	if quiet or Motion.reduce:
		return
	fx.cue("stamp")
	stamp.scale = Vector2.ONE * 2.2
	stamp.modulate.a = 0.0
	var tw := stamp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(stamp, "modulate:a", 1.0, 0.16)
	tw.chain().tween_callback(func() -> void:
		Motion.squash(stamp, 0.22, 0.26)
		Haptics.play(Haptics.THUD)
		fx.ring(stamp.position + stamp.pivot_offset, rad * 0.9, Pal.MOON_INK if insane else Pal.SUN)
		fx.puff(stamp.position + stamp.pivot_offset + Vector2(0.0, rad * 0.8), Pal.WHEAT, 5))

## The seal sits over the ring's middle, sized to it, and follows the ring when
## the host lays the board out again for the win screen.
func _place_stamp() -> void:
	if not is_instance_valid(_stamp) or _stamp_rad <= 0.0 or _ri <= 0.0:
		return
	var rad := minf(STAMP_R, _ri * 0.5)
	_stamp.scale = Vector2.ONE * (rad / _stamp_rad)
	_stamp.position = _c + Vector2(_ri * 0.02, _ri * 0.18) - _stamp.pivot_offset

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("UT_WIN_SUB")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_HOLD + 0.6

## A completed daily reopens with the answer laid down, pegs grinning under
## party hats and the seal on the ring.
func restore_completed_board() -> void:
	var t := _now()
	_restored = true
	_stop_all()
	state.show_answer()
	_set_shown(state.tw, true)
	for p in _peg_px.size():
		_mv[p] = null
		_peg_px[p] = _peg_home(p)
		_face[p] = 1
		_face_at[p] = t - 10.0
	if _ro > 0.0:
		_settle_ropes(50)
	_solved_at = t - 100.0
	_opened = t - 10.0
	_held = -1
	_party = false
	_party_on(true)
	_stamp_down(true)
	_dirty = true

func share_glyphs() -> String:
	var out := "🧶 " + tr("UT_SHARE") % [state.holes, state.ropes]
	if state.is_solved() and not _shown_answer and stamp_key() != "":
		var word: String = tr(stamp_key())
		out += "\n" + (("🌙 %s · %s" % [tr("UT_CAT_SEAL"), word]) if state.cat else ("🏅 " + word))
	return out

# --- the HUD's actions ---

func can_undo() -> bool:
	return state.can_undo() and not is_done() and not out_of_hearts and _settled(_now())

## The last drop taken back: the peg goes home on a flight. On Hard it is a
## stitch like any move.
func undo() -> bool:
	if not can_undo():
		return false
	_drop_held()
	var t := _now()
	var back: Dictionary = state.undo()
	if back.is_empty():
		return false
	_set_shown(state.tw)
	var p: int = back.peg
	_fly(p, _peg_px[p], _hole_px(int(back.to)), 0.0, 0.3, _peg_r * 0.5)
	_whip(p >> 1, WHIP_DROP, SLACK_DROP)
	_later_call(0.3, func() -> void:
		_sq_at[p] = _now())
	if state.budget > 0:
		_use_stitch(t + 0.15)
	_streak = 0
	fx.cue("undo")
	_busy_until = t + 0.32
	moved.emit()
	_dirty = true
	return true

## A peg in the hand when a HUD button takes over goes home first.
func _drop_held() -> void:
	if _held >= 0:
		var p := _held
		_held = -1
		_hot = -1
		_hot_far = -1
		if _face[p] == 3:
			_face[p] = 0
		_fly(p, _peg_px[p], _peg_home(p), 0.0, 0.1)
		_set_shown(state.tw)
	_sel = -1
	_ghost = []

## Insane gives none of its own; a video's (which cost thread, like any move)
## are the only ones there.
func hints_left() -> int:
	var budget: int = State.HINTS_BY_BAND[clampi(_difficulty, 0, 3)]
	if out_of_hearts or state.out_of_thread():
		return 0
	return maxi(0, budget + hints_extra - hints_used)

## One peg flies to where the shortest way I can find puts it, and the thread
## pays for it like any move.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or out_of_hearts or state.out_of_thread() or not _settled(_now()):
		return false
	_drop_held()
	var step: Array = state.hint_step()
	if step.is_empty():
		return false
	hints_used += 1
	var p: int = step[0]
	fx.cue("hint")
	_say(tr("UT_HINT"), Face.Expr.HAPPY)
	_drop(p, int(step[2]), _peg_px[p], true)
	return true

## Reset sends every peg walking home, one after another. On a day with thread
## the stitches already used stay used, and once the thread is gone or the day
## is over there is nothing to reset.
func can_reset() -> bool:
	return not (is_done() or out_of_hearts or state.out_of_thread()) and _settled(_now())

func reset_board() -> void:
	if not can_reset():
		return
	_drop_held()
	var t := _now()
	var walking: Array[int] = state.reset()
	_set_shown(state.tw)
	var k := 0
	for p in walking:
		_fly(p, _peg_px[p], _peg_home(p), Motion.stagger(k, WALK_STEP, 1.0), 0.32, _peg_r * 0.3)
		var pp: int = p
		_later_call(Motion.stagger(k, WALK_STEP, 1.0) + 0.32, func() -> void:
			_sq_at[pp] = _now()
			_whip(pp >> 1, WHIP_HOME, 0.01))
		k += 1
	_solved_at = -INF
	_streak = 0
	moves = 0
	_running = true
	if not walking.is_empty():
		_tell("UT_RESET_THREAD" if state.budget > 0 else "UT_RESET")
	fx.cue("reset")
	_busy_until = t + 0.4 + Motion.stagger(walking.size(), WALK_STEP, 1.0)
	_dirty = true

# --- the sprout's line ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood == Face.Expr.JOY:
		return
	var tips: Array[String] = ["UT_TIP_DRAG", "UT_TIP_KNOT", "UT_TIP_WRAP", "UT_TIP_REACH"]
	if state.budget > 0:
		tips.append("UT_TIP_THREAD")
	if state.cat:
		tips.append("UT_TIP_CAT")
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- odds and ends ---

func _stop_all() -> void:
	_gen += 1
	if is_instance_valid(_card):
		_card.queue_free()
	_card = null
