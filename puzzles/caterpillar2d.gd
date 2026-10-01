extends "res://core/puzzle_base.gd"

## Caterpillar as a flat board: a garden of squares with numbered leaves on
## some of them and wooden fences between a few. Press leaf 1 and drag, and
## every square the finger crosses grows the caterpillar one segment; it eats
## the leaves in order, never crosses itself or a fence, and the board is done
## when its body fills every square with its head on the last leaf. The rules
## live in puzzles/caterpillar_state.gd, which this only draws.
##
## **Nothing wrong can sit on this garden.** A fence, a leaf out of turn and
## the last leaf too soon are refused at the step, with the head shivering,
## so the only way to be wrong is to be stuck: no Check, no tray and no
## actions row. Undo, Reset and Hint ride in the top bar -- Pinwheel's shape.
## On Hard and Insane a legal step can still cost a heart (the polish of
## 2026-10-01): one that strands a square, and on Insane any step off the
## garden's one walk. The caterpillar steps there, worries, the stranded
## squares blush, a heart splits, and it scoots back. Insane is Peckish: the
## middle leaves carry no number and the tummy holds five bare squares.
##
## How it is drawn. **A frame must not cost more as the body grows** -- the
## first cut rebuilt every leaf, fence and segment every frame of a drag, 8 ms
## at one segment and 29 ms at sixty-two on this Mac, which players felt as a
## line that lagged more the longer it got. So the picture is layered meshes,
## each rebuilt only when what it shows changes:
##   still     -- the lawn, the bed and its tiles, rebuilt only on a relayout;
##   under     -- the hint's wash, the leaves, the fences, a stranded square's
##                blush: rebuilt when the body takes or gives back a leaf, and
##                while one of them moves (a chew, a flash);
##   tail lo/hi -- the settled body (shadows and legs, then tube and rounds),
##                baked once every TAIL_STEP squares;
##   live lo/hi -- the last DYN segments, where every wave and the walk happen,
##                copied from baked parts each frame while anything moves,
##                with their tube between and the pops and rings over;
##   over      -- the badges, rebuilt like `under`;
##   top       -- the head; the leaf numbers go between `over` and `top`.
## The rewards (bubble, love hearts, ladybug, the party's butterflies, the
## streak's bubble and the seal) are cached meshes on their own layer.
##
## Spec: docs/superpowers/specs/2026-09-25-caterpillar-flat-design.md (the
## board) and 2026-10-01-caterpillar-polish-design.md (hearts, Peckish,
## rewards, the frame's cost).

const State = preload("res://puzzles/caterpillar_state.gd")
const Gen = preload("res://puzzles/caterpillar_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
## Rings' garden pieces -- a leaf, a daisy and the stable hash -- are statics,
## shared so the two terraces grow the same plants.
const Rings = preload("res://puzzles/rings2d.gd")

# --- the screen, measured ---
## The card's inset, the largest cell any band asks for, the card's corner the
## garden is clipped to, and the bed: its lawn's pad round the grid, the
## wooden frame round that, and the tiles' gap and corner.
const INSET := 40.0
const CELL_CAP := 180.0
const CARD_RADIUS := 32.0
const GROUND_PAD := 6.0
const FRAME := 20.0
const FRAME_R := 24.0
const TILE_GAP := 3.0
const TILE_R := 0.12
## While a finger is dragging, only the middle of a square counts, so a fast
## drag along one row cannot clip the corner of the next.
const DRAG_CORE := 0.1
## A drag is walked in steps this fraction of a square long, so a flick that
## crosses three squares between two touch events still grows all three.
const DRAG_SAMPLE := 0.2
## The lawn round the bed: the share of tiles with a clover on them.
const CLOVER_SHARE := 0.3

# --- the pieces, in cells ---
## A leaf: the leaf itself lying under the square (its length, width and
## angle), then the ink badge over the body with its number, and the gold
## ring an eaten one wears.
const LEAF_LEN := 0.9
const LEAF_WIDE := 0.5
const LEAF_ANGLE := -0.72
const BADGE_R := 0.25
const EATEN_RING := 0.03
const EATEN_RING_W := 0.05
const NUMBER := 1.2
## The bite an eaten leaf shows: three rounds out of its edge near the tip.
const BITE_R := 0.085
## A fence: its length and thickness, the lit rail's share of the width, and
## its posts.
const FENCE_LEN := 1.02
const FENCE_TH := 0.13
const RAIL := 0.62
const POST := 0.2
## The gold wash under a square a hint grew.
const GIVEN_R := 0.42
const GIVEN_ALPHA := 0.4
## Peckish's unnumbered leaves lie a little bigger, having no badge.
const PECK_LEAF := 1.12

# --- the frame's cost ---
## The last DYN segments are rebuilt every moving frame; the rest is the
## settled tail, baked once every TAIL_STEP squares of growth. DYN covers the
## gulp's reach (GULP_REACH) and the walk's (WALK_REACH), so nothing that
## moves ever reaches the tail; the walk and wiggle fade in over SEAM
## segments from the seam, so the tube meets the tail's exactly.
const DYN := 16
const TAIL_STEP := 8
const WALK_REACH := 12
const SEAM := 3.0

# --- this board's own motion ---
## The head trails the finger along the squares it has walked by a lag (in
## squares) that melts away exponentially, SLIDE_TAU its time constant; a
## new step adds a square to whatever lag is left, at most LAG_MAX. The first
## cut restarted a slide from the last square's centre on every step, so a
## fast drag jumped the head back and stuttered; a lag along the path never
## jumps and never cuts a corner. SLIDE_TIME is how long a step is waited on.
## Then the head's breath at rest (amplitude, rate, phase), the antennae.
const SLIDE_TIME := 0.09
const SLIDE_TAU := 0.045
const LAG_MAX := 2.5
const CRAWL := 0.035
const CRAWL_RATE := 4.2
const CRAWL_PHASE := 0.7
const SWAY := 0.13
const SWAY_RATE := 2.3
## A press on the head or leaf 1: a quick squash.
const PRESS_SQUASH := 0.1
const PRESS_TIME := 0.16
## Eating: CHEWS chews of CHEW each once the head has landed on a leaf, the
## head squashing and leaning into the leaf, its mouth opening and closing
## on a scrap that shrinks with every chew, a bite coming out of the leaf and
## a few crumbs on each; then a gulp runs back down the body.
const CHEWS := 3
const CHEW := 0.17
const CHEW_SQUASH := 0.12
const CHEW_LEAN := 0.05
const BITE_OPEN := 0.09
const GULP := 0.2
const GULP_STEP := 0.045
const GULP_TIME := 0.26
const GULP_REACH := 14
## The crawl: every step sends a swell back down the body from the head.
const RIPPLE := 0.13
const RIPPLE_STEP := 0.035
const RIPPLE_TIME := 0.2
const RIPPLE_REACH := 9
## The walk while a finger drags it.
const WALK_RATE := 16.0
const WALK_LAG := 0.9
const WALK_FADE := 0.4
const WIGGLE := 0.025
## A cut back to an earlier square: the head runs back along its own body.
const RETREAT_STEP := 0.05
const RETREAT_MAX := 0.6
## A segment cut away pops out over this, and a Reset's pop tail first.
const GHOST_TIME := 0.18
## The solve: the hop runs tail to head over SOLVE_SPAN, then the butterfly
## unfolds out of the head and flies a loop over the garden and away.
const SOLVE_SPAN := 0.7
const BUTTERFLY_LAG := 0.05
const BUTTERFLY_TIME := 2.1
const BUTTERFLY_OPEN := 0.35
const BUTTERFLY_W := 0.75
const BUTTERFLY_RISE := 1000.0
const BUTTERFLY_LOOP := 1.1
const WIN_WAIT := 2.8
## A refusal repeated on the same square is not said twice inside this.
const REFUSE_QUIET := 0.5
## A hint's segments arrive this far apart.
const HINT_STEP := 0.08

# --- hearts (Hard and Insane) ---
## A wrong step: the head lands, worries for EJECT_AFTER while the stranded
## squares blush and wobble, then scoots back over SLIP_TIME.
const EJECT_AFTER := 0.75
const SLIP_TIME := 0.22
const BLUSH := 0.42
const BLUSH_TIME := 1.1
const HEART_ROW := 64.0
const HEART_TOP := 6.0
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
## Peckish's tummy pill: a leaf pip a square of room, beside the hearts.
const PIP_R := 13.0
const PIP_GAP := 8.0
const PILL_GAP := 18.0

# --- the rewards ---
## The streak: leaves eaten in a row (a cut, an undo, a reset, a wrong step
## or the hearts running out ends it): a note up the pentatonic from the
## second, the bubble from the third, confetti at 4, 7 and every 5.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_DEFLATE := 0.25
const COMBO_FONT := 44
## Gags on one eaten leaf in three (any nine leaves play each kind once).
enum Gag { NONE = -1, BUBBLE, LOVE, LADYBUG }
const GAG_SPAN := 9
const GAG_ODDS := 3
const GAG_STEP := 5
const BUBBLE_TIME := 1.6
const BUBBLE_RISE := 1.6
const BUBBLE_R := 0.32
const LOVE_HEARTS := 3
const LOVE_TIME := 1.2
const LOVE_RISE := 0.9
const LOVE_R := 0.13
## The ladybug flies in from the card's edge, sits on the leaf's segment and
## flies off the other way.
const BUG_IN := 0.6
const BUG_SIT := 1.1
const BUG_OUT := 0.6
const BUG_R := 0.15
## A row or column the body has just filled: sparkles run along it.
const ROW_STEP := 0.035
## The party.
const PARTY_AT := 0.6
const PARTY_TIME := 3.4
const CHEERS := 12
const FLUTTER_AT := 0.9
const FLUTTER_TIME := 2.2
const FLUTTERS := 5
const CAT_PX := 0.18
const CAT_AT := 0.9
const CAT_POP := 0.22
const CAT_HOPS := 3
const CAT_HOP_TIME := 0.32
const CAT_HOP_H := 0.45
const CAT_SETTLE := 0.25
const CURL_AT := 2.7
const STAMP_AT := 1.6
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22

const AGO := -1.0e9
const TIP_CYCLE := 8.0
const TIPS := ["CP_TIP_START", "CP_TIP_ORDER", "CP_TIP_FILL", "CP_TIP_BACK", "CP_TIP_FENCE"]
const TIPS_HEARTS := ["CP_TIP_START", "CP_TIP_STRAND", "CP_TIP_HEARTS", "CP_TIP_BACK"]
const TIPS_PECKISH := ["CP_TIP_PECKISH", "CP_TIP_TUMMY", "CP_TIP_ANY", "CP_TIP_HEARTS"]

## The out-of-hearts card's Back: the board ends unsolved and the host
## leaves.
signal leave

var _state = State.new()
var fx: Node2D

## When each body segment appeared, parallel to the body.
var _seg_at: Array[float] = []
## The head's lag behind the body's last square: `_lag0` squares at
## `_lag_at`, melting away (see SLIDE_TAU).
var _lag0 := 0.0
var _lag_at := -100.0
var _head_at := -100.0
var _munch_at := -100.0
var _dragging := false
var _drag_pos := Vector2.ZERO
## The touch index of the finger holding the stroke (-1 the mouse).
var _finger := -1
## The last square whose margin the finger crossed: which side a corner was
## cut by.
var _via := -1
var _press_at := AGO
var _stroke_from := PackedInt32Array()
## The last refusal: {"at", "cell", "kind"}.
var _refused := {"at": -100.0, "cell": -1, "kind": ""}
var _rings: Array = []
## Segments cut away, popping out: {"at", "from", "dir", "r", "fill"}.
var _ghosts: Array = []
var _ripples: Array[float] = []
var _gulps: Array[float] = []
## When each eaten leaf's chewing began, by its square.
var _munched := {}
var _walked_at := -100.0
## A cut the head is running back over.
var _retreat := PackedInt32Array()
var _retreat_at := -100.0
var _retreat_step := 0.05

var _opened := 0.0
var _anim_until := 0.0
## The leaves' and badges' meshes rebuild every frame until this.
var _decor_until := 0.0
var _solved_at := -1.0
var _still: ArrayMesh
var _under: ArrayMesh
var _over: ArrayMesh
var _tail_lo: ArrayMesh
var _tail_hi: ArrayMesh
var _tail_key: Array = []
var _tail_b_lo: Face.Builder
var _tail_b_hi: Face.Builder
## A segment's parts as triangle lists, baked once a layout (`_part`), and
## every leaf and fence as it has looked, by its look (`_leaf`, `_fence`).
var _parts := {}
var _cache := {}
var _live_lo: ArrayMesh
var _live_tube: ArrayMesh
var _live_hi: ArrayMesh
## The segments cut away popping out, and the rings round a leaf just eaten.
var _live_fx: ArrayMesh
var _top: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

## Hearts.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _undo_ever := false
var _flawless := false
var _asleep := false
var _heart_card: Control
var _split_index := -1
var _split_at := AGO
var _back_index := -1
var _back_at := AGO
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _dusk_tw: Tween
var _gen := 0
var _busy_until := 0.0
var _was_busy := false
## The wrong step playing out: {"at", "cell", "cells" (the stranded squares)}.
var _wrong := {}
var _hungry_at := AGO

## The rewards. `force_gag` is the harness's: a Gag kind every eaten leaf
## plays (-1 none at all, -2 the day's own roll).
var force_gag := -2
var _streak := 0
var _streak_gen := 0
var _eats := 0
var _gag_until := 0.0
var _gag_gen := 0
var _combo_n := 0
var _combo_at := -INF
var _combo_pos := Vector2.ZERO
var _combo_popped := false
var _combo_out_at := -INF
var _combo_shown: ArrayMesh
var _combo_key: Array = []
var _life_layer: Control
var _life_shown: Array = []
var _love: Array = []      # [{"at", "t", "phase"}]
var _bubbles: Array = []   # [{"at", "t"}]
var _bugs: Array = []      # [{"cell", "t", "from"}]
var _love_mesh: ArrayMesh
var _bubble_mesh: ArrayMesh
var _bug_mesh: ArrayMesh
var _seal_mesh: ArrayMesh
var _party_at := INF
var _stamp_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false

func puzzle_id() -> String: return "caterpillar"
func title() -> String: return "Caterpillar"

## The rules, then the band's own closing: nothing can be lost (Easy,
## Medium), what a heart is for (Hard), or Peckish (Insane).
func rules() -> String:
	var out := tr("CP_RULES")
	if _state.peckish():
		out += "\n\n" + tr("CP_RULES_PECKISH") % [_state.hunger, max_hearts]
	elif max_hearts > 0:
		out += "\n\n" + tr("CP_RULES_HEARTS") % max_hearts
	else:
		out += "\n\n" + tr("CP_RULES_SAFE")
	return out

func _tips() -> Array:
	if _state.peckish():
		return TIPS_PECKISH
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

## Undo and Hint; Reset is the host's. No Check: nothing wrong can sit here.
## No hint on Insane (Peckish), and no undo there either: can_undo() says so.
func capabilities() -> Array[String]:
	if _state.difficulty >= 3:
		return ["undo"]
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	_heart_layer = Control.new()
	_heart_layer.name = "Hearts"
	_heart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heart_layer.z_index = 1
	_heart_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heart_layer.draw.connect(_draw_hearts)
	add_child(_heart_layer)
	_life_layer = Control.new()
	_life_layer.name = "Life"
	_life_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_life_layer.z_index = 3
	_life_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_life_layer.draw.connect(_draw_life)
	add_child(_life_layer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	_close_card()
	_state.build(rng, difficulty, bank_step)
	max_hearts = State.hearts_for(difficulty)
	_heart_used = false
	_lost_ever = false
	_undo_ever = false
	_flawless = false
	_deal()
	_reset_rewards()
	_layout()
	_opened = _now()
	_decor_for(_entrance())
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## The garden as it is dealt, and as Try again deals it back: every heart,
## the day's light, an empty bed.
func _deal() -> void:
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_split_at = AGO
	_back_index = -1
	_back_at = AGO
	_busy_until = 0.0
	_wrong = {}
	_hungry_at = AGO
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	_seg_at = []
	_lag0 = 0.0
	_dragging = false
	_refused = {"at": -100.0, "cell": -1, "kind": ""}
	_rings = []
	_ghosts = []
	_retreat = PackedInt32Array()
	_ripples = []
	_gulps = []
	_munched = {}
	_anim_until = 0.0
	_solved_at = -1.0
	_dirty()

# --- layout ---

func _cell() -> float:
	if _state.cols <= 0:
		return 0.0
	return maxf(0.0, minf(CELL_CAP, minf((size.x - 2.0 * INSET) / _state.cols,
		(size.y - _heart_row() - 2.0 * INSET) / _state.rows)))

## The strip the hearts take over the bed, on a band that has them.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

func _grid_size() -> Vector2:
	return Vector2(_state.cols, _state.rows) * _cell()

func _origin() -> Vector2:
	var row := _heart_row()
	var g := _grid_size()
	return Vector2((size.x - g.x) * 0.5, row + (size.y - row - g.y) * 0.5)

func _mid() -> Vector2:
	return _origin() + _grid_size() * 0.5

func _centre(c: int) -> Vector2:
	return _origin() + (Vector2(c % _state.cols, c / _state.cols) + Vector2(0.5, 0.5)) * _cell()

## Control-local point over the centre of the square at (row, column), the
## name every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.cols + c)

## The square under a local point, or -1. While dragging only its core counts.
func _cell_at(local: Vector2, core := false) -> int:
	var s := _cell()
	if s <= 0.0:
		return -1
	var p := (local - _origin()) / s
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if x < 0 or y < 0 or x >= _state.cols or y >= _state.rows:
		return -1
	if core:
		var f := p - Vector2(x, y)
		if f.x < DRAG_CORE or f.x > 1.0 - DRAG_CORE or f.y < DRAG_CORE or f.y > 1.0 - DRAG_CORE:
			return -1
	return y * _state.cols + x

func card_height(available: float) -> float:
	return available

## The grid is square and the slot is tall, so the slack is halved.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_tail_key = []
	_parts = {}
	_cache = {}
	_love_mesh = null
	_bubble_mesh = null
	_bug_mesh = null
	_seal_mesh = null
	_combo_shown = null
	_lag0 = 0.0
	if is_instance_valid(_cat):
		_place_cat(_now())
	if _life_layer != null:
		_life_layer.queue_redraw()
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	_dirty()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	# A wrong step ending lets go of the HUD: it greyed Undo, Hint and Reset.
	var b := busy()
	if _was_busy and not b:
		moved.emit()
	_was_busy = b
	if _animating(t) or _lag(t) > 0.0:
		_refresh()
	elif not Motion.reduce and not _state.body.is_empty():
		# At rest only the head moves -- its breath and its blink -- and it is
		# its own small mesh, so an idle garden rebuilds that and nothing
		# else. The first cut breathed every segment and rebuilt the whole
		# body a frame: 12 ms an idle frame on this Mac against Pinwheel's 3.
		_top = null
		queue_redraw()
	if _tick_life(t):
		_life_layer.queue_redraw()
	if t >= _cat_at and not _cat_curled:
		_place_cat(t)
	if max_hearts > 0 and (t - _split_at < SPLIT_TIME + 0.1 or t - _back_at < HEART_BACK_TIME + 0.1 \
			or t - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1 or t - _hungry_at < Motion.SHIVER_TIME * 2.0 + 0.1):
		_heart_layer.queue_redraw()

func _entrance() -> float:
	return Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(_state.last_leaf(), Motion.ENTER_STAGGER) + Motion.POP_IN

## Asked wave by wave: the entrance, a slide, a pop, a refusal, a ring and
## the solve all ask for time by the clock through _busy_for.
func _animating(t: float) -> bool:
	if t < _anim_until or t < _decor_until:
		return true
	if Motion.reduce:
		return false
	return t - _opened < _entrance()

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## The leaves, fences and badges move for this long: their meshes rebuild
## every frame until then.
func _decor_for(seconds: float) -> void:
	_decor_until = maxf(_decor_until, _now() + seconds)
	_anim_until = maxf(_anim_until, _decor_until)

## Whether a wrong step is still playing out: input, Undo, Hint and Reset
## wait, and the host holds its hint video.
func busy() -> bool:
	return _now() < _busy_until

## The body moved: the meshes that follow it every frame.
func _refresh() -> void:
	_live_lo = null
	_live_hi = null
	_top = null
	queue_redraw()

## What the body covers changed (a leaf, a hint's square, a cut, a deal):
## the leaves and badges too.
func _dirty() -> void:
	_under = null
	_over = null
	_refresh()

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _mid()
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	var shown: Array = []
	var moving := t < _decor_until
	if _still == null:
		_still = _build_still()
	if _under == null or moving:
		_under = _build_under(t)
	if _live_lo == null:
		_build_body(t)
	if _over == null or moving:
		_over = _build_over(t)
	if _top == null:
		_top = _build_top(t)
	for m in [_still, _under, _tail_lo, _live_lo, _tail_hi, _live_tube, _live_hi, _live_fx, _over]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_numbers(t, xf, seen)
	if _top != null:
		draw_mesh(_top, null, xf, tint)
		shown.append(_top)
	_draw_butterfly_mesh(t, shown)
	_shown = shown

# --- the garden, built once a layout ---

## The garden: a mown lawn over the whole card with dappled shade, tufts and
## daisies, foliage hanging into the top corners and bushes along the foot,
## and in the middle the bed -- a wooden frame round a checker of pale grass
## tiles, a clover on some. It never moves, so it is one mesh built once a
## layout, and the live mesh rebuilt while anything moves stays as small as
## before.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	var w := size.x
	var h := size.y
	var seed_i: int = _state.cols * 131 + _state.last_leaf() * 7 + _state.hedges.size()
	var clip := Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0)
	Rings._clip_polygon(b, clip, Pal.MEADOW.lerp(Pal.PAPER, 0.55), clip)
	# Mown stripes across the lawn, a shade apart.
	var band := 90.0
	for k in int(ceil(h / band)):
		if k % 2 == 1:
			Rings._clip_polygon(b, PackedVector2Array([Vector2(0.0, k * band), Vector2(w, k * band),
				Vector2(w, (k + 1) * band), Vector2(0.0, (k + 1) * band)]), Pal.MEADOW.lerp(Pal.PAPER, 0.45), clip)
	var shade := Color(Pal.LEAF_DEEP, 0.07)
	for d in 7:
		var at := Vector2(w * Rings._h(seed_i, d + 200), h * Rings._h(seed_i, d + 300))
		for q in 5:
			var off := Vector2((Rings._h(d, q + 1) - 0.5) * 220.0, (Rings._h(d, q + 7) - 0.5) * 120.0)
			var r := 45.0 + 40.0 * Rings._h(d, q + 13)
			var c := (at + off).clamp(Vector2(r, r * 0.6), Vector2(w - r, h - r * 0.6))
			Scenery.soft_disc(b, c, r, r * 0.6, shade)
	# Tufts and daisies on the open lawn, never under the bed.
	var bed := Rect2(o - Vector2.ONE * (GROUND_PAD + FRAME + 16.0), g + Vector2.ONE * (GROUND_PAD + FRAME + 16.0) * 2.0)
	var ident := func(p: Vector2) -> Vector2: return p
	for f in 26:
		var at := Vector2(30.0 + (w - 60.0) * Rings._h(seed_i, f + 500), 40.0 + (h - 80.0) * Rings._h(seed_i, f + 600))
		if bed.has_point(at):
			continue
		if f % 3 == 0:
			Rings._append_daisy(b, at, 13.0 + 5.0 * Rings._h(seed_i, f + 700), ident)
		else:
			Scenery.tuft(b, at, 16.0 + 10.0 * Rings._h(seed_i, f + 800))
	_foliage(b, Vector2(0.0, 0.0), 1.0, seed_i + 1, clip)
	_foliage(b, Vector2(w, 0.0), -1.0, seed_i + 2, clip)
	_bush(b, Vector2(44.0, h + 6.0), 100.0, seed_i + 3, clip)
	_bush(b, Vector2(w - 50.0, h + 6.0), 112.0, seed_i + 4, clip)
	_bush(b, Vector2(w * 0.6, h + 4.0), 54.0, seed_i + 5, clip)
	# The bed: a shadow, the wooden frame with its grain, the grout, then the tiles.
	var lawn := o - Vector2.ONE * GROUND_PAD
	var lawn_size := g + Vector2.ONE * GROUND_PAD * 2.0
	var out := lawn - Vector2.ONE * FRAME
	var out_size := lawn_size + Vector2.ONE * FRAME * 2.0
	Scenery.soft_disc(b, out + out_size * Vector2(0.5, 1.0) + Vector2(0.0, 6.0), out_size.x * 0.55, 34.0, Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 6.0), out_size, FRAME_R), Pal.PLAQUE_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R), Pal.PLAQUE)
	b.fan(Face.Builder.round_rect(out + Vector2.ONE * 3.0, out_size - Vector2.ONE * 6.0, FRAME_R - 3.0), Pal.WOOD)
	var grain := Color(Pal.PLAQUE_DEEP, 0.25)
	var mid := FRAME * 0.5
	for k: float in [-1.0, 1.0]:
		var off := k * 3.5
		b.stroke(PackedVector2Array([lawn + Vector2(lawn_size.x * 0.1, -mid + off), lawn + Vector2(lawn_size.x * 0.44, -mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([lawn + Vector2(lawn_size.x * 0.6, lawn_size.y + mid + off), lawn + Vector2(lawn_size.x * 0.92, lawn_size.y + mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([lawn + Vector2(-mid + off, lawn_size.y * 0.3), lawn + Vector2(-mid + off, lawn_size.y * 0.72)]), 1.5, grain)
		b.stroke(PackedVector2Array([lawn + Vector2(lawn_size.x + mid + off, lawn_size.y * 0.14), lawn + Vector2(lawn_size.x + mid + off, lawn_size.y * 0.5)]), 1.5, grain)
	b.fan(Face.Builder.round_rect(lawn - Vector2.ONE * 3.0, lawn_size + Vector2.ONE * 6.0, FRAME_R - 6.0), Pal.PLAQUE)
	b.fan(Face.Builder.round_rect(lawn, lawn_size, FRAME_R - 8.0), Pal.MEADOW_LINE)
	for c in _state.size():
		var x: int = c % _state.cols
		var y: int = c / _state.cols
		var at := o + Vector2(x, y) * s + Vector2.ONE * TILE_GAP
		var side := s - TILE_GAP * 2.0
		var tone := Pal.MEADOW.lerp(Pal.SURFACE, 0.34 if (x + y) % 2 == 0 else 0.18)
		b.fan(Face.Builder.round_rect(at + Vector2(0.0, 3.0), Vector2.ONE * side, s * TILE_R), Pal.MEADOW_LINE.lerp(Pal.LEAF, 0.18))
		b.fan(Face.Builder.round_rect(at, Vector2.ONE * side, s * TILE_R), tone)
		b.fan(Face.Builder.round_rect(at + Vector2(side * 0.1, side * 0.06), Vector2(side * 0.5, side * 0.05), side * 0.025),
			Color(Pal.SURFACE, 0.35))
		if Rings._h(seed_i + c, 41) < CLOVER_SHARE and _state.clue[c] == 0:
			var corner := at + Vector2(0.2 + 0.6 * Rings._h(c, 42), 0.72 + 0.1 * Rings._h(c, 43)) * side
			_clover(b, corner, s * 0.06, tone.lerp(Pal.LEAF, 0.35))
		elif Rings._h(seed_i + c, 44) < 0.35:
			var root := at + Vector2(0.18 + 0.64 * Rings._h(c, 45), 0.86) * side
			for q in 3:
				var tip := root + Vector2((float(q) - 1.0) * s * 0.035, -s * (0.07 + 0.03 * float(q % 2)))
				b.stroke(PackedVector2Array([root + Vector2((float(q) - 1.0) * s * 0.012, 0.0), tip]), s * 0.018, tone.lerp(Pal.LEAF, 0.3))
	return b.mesh()

## Three small rounds and a stalk: a clover lying on a tile.
func _clover(b, at: Vector2, r: float, col: Color) -> void:
	for q in 3:
		var a := -PI * 0.5 + TAU * float(q) / 3.0
		b.disc(at + Vector2.from_angle(a) * r * 0.75, r * 0.62, col)
	b.stroke(PackedVector2Array([at, at + Vector2(r * 0.5, r * 1.5)]), r * 0.22, col)

## Leaves hanging in from a top corner, `out` +1 at the left and -1 at the
## right, deep behind and lit in front.
func _foliage(b, root: Vector2, out: float, seed_i: int, clip: PackedVector2Array) -> void:
	var layers := [[Pal.LEAF_DEEP, 8, 1.0], [Pal.LEAF, 6, 0.78], [Pal.LEAF_LIGHT, 4, 0.52]]
	for li in layers.size():
		var layer: Array = layers[li]
		var n: int = layer[1]
		for q in n:
			var ang := lerpf(0.0, PI * 0.5, float(q) / float(n - 1))
			if out < 0.0:
				ang = PI - ang
			ang += (Rings._h(seed_i, q + li * 11) - 0.5) * 0.3
			var lng := 104.0 * float(layer[2]) * (0.7 + 0.5 * Rings._h(seed_i, q + li * 11 + 40))
			_clip_leaf(b, root + Vector2(out * 14.0 * Rings._h(seed_i, q + 90), -8.0), ang, lng, layer[0], clip)

## A bush along the foot: a dome of leaves with a daisy or two on it.
func _bush(b, root: Vector2, bush: float, seed_i: int, clip: PackedVector2Array) -> void:
	var layers := [[Pal.LEAF_DEEP, 9, 1.0], [Pal.LEAF, 7, 0.78], [Pal.LEAF_LIGHT, 4, 0.52]]
	for li in layers.size():
		var layer: Array = layers[li]
		var n: int = layer[1]
		for q in n:
			var ang := lerpf(-PI + 0.25, -0.25, float(q) / float(n - 1)) + (Rings._h(seed_i, q + li * 11) - 0.5) * 0.3
			var lng := bush * float(layer[2]) * (0.75 + 0.4 * Rings._h(seed_i, q + li * 11 + 40))
			_clip_leaf(b, root, ang, lng, layer[0], clip)
	var ident := func(p: Vector2) -> Vector2: return p
	for q in 2:
		var a := lerpf(-PI + 0.7, -0.7, (float(q) + 0.5) / 2.0)
		var at := root + Vector2.from_angle(a) * bush * (0.45 + 0.2 * Rings._h(seed_i, q + 80))
		if Geometry2D.is_point_in_polygon(at, clip):
			Rings._append_daisy(b, at, bush * 0.2, ident)

func _clip_leaf(b, root: Vector2, ang: float, lng: float, col: Color, clip: PackedVector2Array) -> void:
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal() * lng * 0.3
	var tip := root + dir * lng
	var pts := Face.Builder.bezier2(root, root + dir * lng * 0.45 + side, tip, 7)
	pts.append_array(Face.Builder.bezier2(tip, root + dir * lng * 0.45 - side, root, 7))
	Rings._clip_polygon(b, pts, col, clip)

# --- the leaves and fences under the body ---

func _build_under(t: float) -> ArrayMesh:
	var soup := Soup.new()
	var b := Face.Builder.new()
	var s := _cell()
	for c in _state.given:
		if _state.body.has(c):
			b.fan(Face.Builder.round_rect(_centre(c) - Vector2.ONE * s * GIVEN_R,
				Vector2.ONE * s * GIVEN_R * 2.0, s * 0.18), Color(Pal.SUN_RAY, GIVEN_ALPHA))
	_blush(b, t)
	soup.add_builder(b)
	for k in _state.leaves.size():
		_leaf(soup, _state.leaves[k], t)
	for e in _state.hedges:
		_fence(soup, e, t)
	return soup.mesh() if not soup.verts.is_empty() else null

## The squares a wrong step stranded: a rose wash that wobbles in and fades,
## so the player sees exactly what the heart bought.
func _blush(b, t: float) -> void:
	if _wrong.is_empty():
		return
	var e := t - float(_wrong["at"])
	if e < 0.0 or e > BLUSH_TIME:
		return
	var s := _cell()
	var level := Motion.flash_level(e, 0.15, BLUSH_TIME - 0.15)
	var cells: PackedInt32Array = _wrong["cells"]
	for i in cells.size():
		var c := cells[i]
		var wob := 0.0 if Motion.reduce else sin(e * 22.0 + float(i)) * (1.0 - e / BLUSH_TIME) * 0.06
		var r := s * (0.4 + wob)
		b.fan(Face.Builder.round_rect(_centre(c) - Vector2.ONE * r, Vector2.ONE * r * 2.0, s * 0.16),
			Color(Pal.FLOWER, BLUSH * level))
	# The square it stepped onto, ringed.
	var at := _centre(int(_wrong["cell"]))
	b.stroke(Face.Builder.ring(at, s * 0.44, s * 0.44), s * 0.05, Color(Pal.FLOWER_DEEP, 0.7 * level), true)

## A fence on the edge between two squares: a soft shadow, a wooden rail with
## its lit top and grain, and a capped post at either end and in the middle,
## flashing and shivering when the head was just refused across it.
func _fence(soup: Soup, e: int, t: float) -> void:
	var a := e / 4096
	var z := e % 4096
	var mid := (_centre(a) + _centre(z)) * 0.5
	var hot := String(_refused["kind"]) == "hedge" and (int(_refused["cell"]) == a or int(_refused["cell"]) == z) \
		and (_state.head() == a or _state.head() == z)
	var since := t - float(_refused["at"]) if hot else -1.0
	var level := roundi(Motion.flash_level(since) * 6.0) if hot else 0
	var sh := Motion.shiver_offset(since) * 2.0 if hot else 0.0
	var vertical: bool = a / _state.cols == z / _state.cols
	var key := "f%d|%d" % [e, level]
	if not _cache.has(key):
		var b := Face.Builder.new()
		_fence_shape(b, vertical, float(level) / 6.0)
		var piece := Soup.new()
		piece.add_builder(b)
		_cache[key] = piece
	var across := Vector2(1.0, 0.0) if vertical else Vector2(0.0, 1.0)
	soup.add(_cache[key], Transform2D(0.0, mid + across * sh))

## A fence about the origin: a soft shadow, a wooden rail with its lit top and
## grain, and a capped post at either end and in the middle, flashed `fl`
## toward the refusal's colour.
func _fence_shape(b, vertical: bool, fl: float) -> void:
	var s := _cell()
	var along := Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)
	var across := Vector2(1.0, 0.0) if vertical else Vector2(0.0, 1.0)
	var at := Vector2.ZERO
	var ln := s * FENCE_LEN
	var th := s * FENCE_TH
	var xf := Transform2D(across, along, at)
	Scenery.soft_disc(b, at + Vector2(0.0, th * 0.9), (ln * 0.55 if not vertical else th * 1.6), (th * 1.3 if not vertical else ln * 0.55),
		Color(Pal.TEXT, 0.16))
	b.fan(xf * Face.Builder.round_rect(Vector2(-th * 0.5, -ln * 0.5 + th * 0.35), Vector2(th, ln), th * 0.4),
		Pal.PLAQUE_DEEP.lerp(Pal.BAD, fl * 0.7))
	b.fan(xf * Face.Builder.round_rect(Vector2(-th * 0.5, -ln * 0.5), Vector2(th, ln), th * 0.4),
		Pal.FENCE_DARK.lerp(Pal.BAD, fl * 0.7))
	b.fan(xf * Face.Builder.round_rect(Vector2(-th * 0.42, -ln * 0.5), Vector2(th * RAIL, ln), th * 0.3),
		Pal.FENCE_RAIL.lerp(Pal.BAD, fl * 0.5))
	b.stroke(xf * PackedVector2Array([Vector2(-th * 0.1, -ln * 0.3), Vector2(-th * 0.1, -ln * 0.05)]), 1.5, Color(Pal.FENCE_DARK, 0.4))
	b.stroke(xf * PackedVector2Array([Vector2(-th * 0.2, ln * 0.12), Vector2(-th * 0.2, ln * 0.36)]), 1.5, Color(Pal.FENCE_DARK, 0.4))
	var p := s * POST
	for y: float in [-ln * 0.5 + p * 0.45, 0.0, ln * 0.5 - p * 0.45]:
		var sq := Face.Builder.round_rect(Vector2(-p * 0.5, y - p * 0.5), Vector2.ONE * p, p * 0.25)
		b.fan(xf * Face.Builder.round_rect(Vector2(-p * 0.5, y - p * 0.5 + p * 0.22), Vector2.ONE * p, p * 0.25), Pal.PLAQUE_DEEP)
		b.fan(xf * sq, Pal.FENCE_POST.lerp(Pal.BAD, fl * 0.5))
		b.fan(xf * Face.Builder.round_rect(Vector2(-p * 0.36, y - p * 0.38), Vector2(p * 0.6, p * 0.5), p * 0.18),
			Pal.FENCE_RAIL.lerp(Pal.BAD, fl * 0.4))

# --- the body ---

## Every body point this frame, tail first: each square's centre, the head's
## eased in from wherever it was drawn, the walk's wiggle near the head, and
## the solve's hop running tail to head.
func _points(t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = _state.body.size()
	# While the head runs back over a cut, the squares it has not reached yet
	# are still body: the chain runs on through them to wherever it is now.
	var chain := _chain(t)
	var left := _retreat_left(t)
	var last := chain.size() - 1
	var walk := _walk(t)
	var lag := _lag(t)
	var seam := float(maxi(0, last - WALK_REACH))
	for i in chain.size():
		var p := _centre(chain[i])
		if left > 0.0 and i == last:
			# The head, part-way between the square it is leaving and the
			# next one back.
			var frac := left - floorf(left)
			if frac > 0.0 and last > 0:
				p = _centre(chain[last - 1]).lerp(p, frac)
		elif left <= 0.0 and lag > 0.0 and float(i) > float(last) - lag:
			# Not reached yet: under the head, wherever it has got to.
			p = _along(chain, float(last) - lag)
		if walk > 0.0 and i < last and float(i) > seam:
			var d := _centre(chain[mini(i + 1, last)]) - _centre(chain[maxi(i - 1, 0)])
			var ramp := clampf((float(i) - seam) / SEAM, 0.0, 1.0)
			if d.length() > 0.01:
				p += d.normalized().orthogonal() * _cell() * WIGGLE * walk * ramp * sin(_gait_phase(i, t) + 0.8)
		if _solved_at >= 0.0:
			p.y += Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY - _wave(i, n),
				Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		pts.append(p)
	return pts

## The squares the body is drawn over: the body, and while the head runs back
## over a cut, the squares it has not reached yet.
func _chain(t: float) -> PackedInt32Array:
	var chain: PackedInt32Array = _state.body.duplicate()
	var left := _retreat_left(t)
	if left > 0.0:
		chain.append_array(_retreat.slice(0, int(ceil(left))))
	return chain

## How many squares the head still trails the body's last square by.
func _lag(t: float) -> float:
	if Motion.reduce or _lag0 <= 0.0:
		return 0.0
	var k := _lag0 * exp(-(t - _lag_at) / SLIDE_TAU)
	return k if k > 0.02 else 0.0

## The point `u` squares along `chain` from its tail, between centres.
func _along(chain: PackedInt32Array, u: float) -> Vector2:
	var i := clampi(int(floor(u)), 0, chain.size() - 1)
	var f := u - float(i)
	if i >= chain.size() - 1 or f <= 0.0:
		return _centre(chain[i])
	return _centre(chain[i]).lerp(_centre(chain[i + 1]), f)

func _retreat_left(t: float) -> float:
	if _retreat.is_empty() or Motion.reduce:
		return 0.0
	var m := float(_retreat.size())
	var u := clampf((t - _retreat_at) / (_retreat_step * m), 0.0, 1.0)
	return m * (1.0 - u * u * (3.0 - 2.0 * u))

func _walk(t: float) -> float:
	if Motion.reduce:
		return 0.0
	var u := clampf((t - _walked_at) / WALK_FADE, 0.0, 1.0)
	return 1.0 - u * u * (3.0 - 2.0 * u)

func _gait_phase(i: int, t: float) -> float:
	return t * WALK_RATE - float(i) * WALK_LAG

static func _wave(i: int, n: int) -> float:
	return SOLVE_SPAN * float(i) / float(maxi(n - 1, 1))

## Where the settled tail ends this frame: DYN segments back from the head,
## rounded down to TAIL_STEP so it is baked once every TAIL_STEP squares,
## and back to the start while the solve's hop runs or a segment below it is
## still popping in.
func _settled(t: float, n: int) -> int:
	if _solved_at >= 0.0 and t - _solved_at < Motion.SOLVE_DELAY + SOLVE_SPAN + Motion.SOLVE_TIME + 0.2:
		return 0
	var m := maxi(0, (n - DYN) / TAIL_STEP * TAIL_STEP)
	if not Motion.reduce:
		for i in mini(m, _seg_at.size()):
			if t - _seg_at[i] < Motion.POP_IN:
				return i / TAIL_STEP * TAIL_STEP
	return m

## The body's four meshes: the settled tail and the stretch near the head,
## each in two layers (shadows and legs under, tube and rounds over).
##
## **The tail is appended to, never rebuilt**: when the seam moves on by
## TAIL_STEP squares the new segments are added to the builders it already
## has (a cut, an undo or a relayout below the seam starts it again). **The
## stretch near the head is copied, not drawn**: every part of a segment --
## its shadow, a leg, a foot, its round, its spots, the solve's glow -- is a
## triangle list baked once a layout (`_part`), and each frame only appends
## those lists through a transform, which is native array work. Building the
## same stretch with the builder cost 0.4 ms a segment on this Mac.
func _build_body(t: float) -> void:
	_live_lo = null
	_live_hi = null
	_live_tube = null
	_live_fx = null
	var hi := Soup.new()
	var gb := Face.Builder.new()
	_draw_ghosts(gb, t)
	if _state.body.is_empty():
		_tail_lo = null
		_tail_hi = null
		_tail_key = []
	else:
		var pts := _points(t)
		var n := pts.size()
		var m := mini(_settled(t, n), n - 1)
		var chain := _chain(t)
		_bake_tail(chain, m, t)
		var lo := Soup.new()
		_soup_body(lo, hi, pts, m, t)
		if not lo.verts.is_empty():
			_live_lo = lo.mesh()
	var s := _cell()
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r["at"])) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			gb.stroke(Face.Builder.ring(_centre(r["cell"]), s * (0.34 + 0.3 * u), s * (0.34 + 0.3 * u)),
				s * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	if not gb.verts.is_empty():
		_live_fx = gb.mesh()
	if not hi.verts.is_empty():
		_live_hi = hi.mesh()

## The settled tail up to segment `m`, at rest on its squares' centres:
## appended to when the seam has moved on, started again when anything
## under it changed.
func _bake_tail(chain: PackedInt32Array, m: int, t: float) -> void:
	if m <= 0:
		_tail_lo = null
		_tail_hi = null
		_tail_key = []
		return
	var from := 0
	var glowing := _solved_at >= 0.0
	if _tail_key.size() == 4 and float(_tail_key[1]) == _cell() and bool(_tail_key[2]) == glowing:
		var had: PackedInt32Array = _tail_key[3]
		var m0: int = _tail_key[0]
		if m0 <= m and chain.slice(0, m0 + 1) == had:
			from = m0
	if from == m and _tail_lo != null:
		return
	if from == 0:
		_tail_b_lo = Face.Builder.new()
		_tail_b_hi = Face.Builder.new()
	var rest := PackedVector2Array()
	var scales: Array = []
	var breath := PackedFloat32Array()
	for i in m + 1:
		rest.append(_centre(chain[i]))
		scales.append(Vector2.ONE)
		breath.append(1.0)
	Cat.body(_tail_b_lo, rest, _cell(), scales, breath, PackedFloat32Array(), PackedVector2Array(), from, m, 1)
	Cat.body(_tail_b_hi, rest, _cell(), scales, breath, PackedFloat32Array(), PackedVector2Array(), from, m, 2)
	_tail_lo = _tail_b_lo.mesh()
	_tail_hi = _tail_b_hi.mesh()
	_tail_key = [m, _cell(), glowing, chain.slice(0, m + 1)]

## Segments m.. of `pts` into the two soups, the head's point last (its
## shadow only: the head is `_top`).
func _soup_body(lo: Soup, hi: Soup, pts: PackedVector2Array, m: int, t: float) -> void:
	var n := pts.size()
	var s := _cell()
	var big := s * Cat.SEG_R
	var walk := _walk(t)
	var seam := float(maxi(m, n - 1 - WALK_REACH))
	var shadow := _part("shadow")
	for i in range(m, n):
		var sc: Vector2 = _seg_scale(i, t) if i < n - 1 else Vector2.ONE
		if sc.x <= 0.01:
			continue
		var k := Cat._taper(i) * sc.x
		lo.add(shadow, Transform2D(0.0, Vector2(k, k), 0.0, pts[i]))
	var leg := _part("leg")
	var foot := _part("foot")
	for i in range(m, n - 1):
		var sc := _seg_scale(i, t)
		if sc.x <= 0.01:
			continue
		var r := big * Cat._taper(i) * sc.x
		var dir := Cat._dir(pts, i)
		var nrm := dir.orthogonal()
		var step := Vector2.ZERO
		if walk > 0.0:
			var ph := _gait_phase(i, t)
			step = Vector2(sin(ph), cos(ph)) * walk * clampf((float(i) - seam) / SEAM, 0.0, 1.0)
		for side: float in [-1.0, 1.0]:
			var fwd := step.x * side
			var lift := maxf(0.0, step.y * side)
			var root := pts[i] + nrm * side * r * Cat.LEG_ROOT
			var tip := pts[i] + nrm * side * r * (Cat.LEG_REACH - Cat.LEG_TUCK * lift) + dir * r * (0.12 + Cat.LEG_STRIDE * fwd)
			var ax := tip - root
			lo.add(leg, Transform2D(ax, ax.normalized().orthogonal() * sc.x, root))
			var f := sc.x * (1.0 - 0.15 * lift)
			lo.add(foot, Transform2D(0.0, Vector2(f, f), 0.0, tip))
	var line := pts.slice(m, n)
	if line.size() > 1:
		var tube := Face.Builder.new()
		tube.stroke(line, s * Cat.TUBE_DEEP, Pal.LEAF_DEEP)
		tube.stroke(line, s * Cat.TUBE, Pal.LEAF)
		_live_tube = tube.mesh()
	var spots := _part("spots")
	for i in range(m, n - 1):
		var sc := _seg_scale(i, t)
		if sc.x <= 0.01:
			continue
		var k := Cat._taper(i) * _swell(i, n, t)
		var xf := Transform2D(0.0, sc * k, 0.0, pts[i])
		hi.add(_part("round1" if i % 2 == 1 else "round0"), xf)
		hi.add(spots, Transform2D(Cat._dir(pts, i).angle(), sc * k, 0.0, pts[i]))
		if _solved_at >= 0.0:
			var g := Motion.flash_level(t - _solved_at - Motion.SOLVE_DELAY - _wave(i, n), 0.1, 0.6)
			var level := clampi(roundi(g * 5.0), 0, 5)
			if level > 0:
				hi.add(_part("glow%d" % level), xf)

## Segment `i`'s pop-in this frame.
func _seg_scale(i: int, t: float) -> Vector2:
	return Motion.pop_in_scale(t - _seg_at[i]) if i < _seg_at.size() else Vector2.ONE

## A segment's parts, each a triangle list at the segment's full radius,
## baked once a layout: its shadow, a leg (a unit stroke along +x, stretched
## to its tip by the transform), a foot, its round (rim, face and shine,
## never turned, so the light stays top left), its two spots (turned the way
## it faces) and the solve's warm glow in five strengths.
func _part(key: String) -> Soup:
	if _parts.has(key):
		return _parts[key]
	var s := _cell()
	var r := s * Cat.SEG_R
	var b := Face.Builder.new()
	match key:
		"shadow":
			Scenery.soft_disc(b, Vector2(0.0, s * Cat.SHADOW_DROP), r * 1.25, r * 1.1, Color(Pal.TEXT, Cat.SHADOW_ALPHA))
		"leg":
			b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(1.0, 0.0)]), s * Cat.LEG_W, Pal.LEAF_DEEP, false, false)
		"foot":
			b.disc(Vector2.ZERO, s * Cat.FOOT_R, Pal.LEAF_DEEP.lerp(Pal.TEXT, 0.25))
		"round0", "round1":
			var fill: Color = Pal.LEAF if key == "round1" else Pal.LEAF_LIGHT
			b.fan(Face.Builder.ring(Vector2(0.0, r * Cat.RIM_DROP / Cat.SEG_R), r, r), Pal.LEAF_DEEP)
			b.fan(Face.Builder.ring(Vector2.ZERO, r * Cat.FACE_IN, r * Cat.FACE_IN), fill)
			b.fan(Face.Builder.ring(Vector2(-0.3, -0.38) * r, r * 0.3, r * 0.17), Color(1.0, 1.0, 1.0, Cat.SHINE_ALPHA))
		"spots":
			for side: float in [-1.0, 1.0]:
				b.fan(Face.Builder.ring(Vector2(0.0, side * r * Cat.SPOT_OUT), r * Cat.SPOT_R, r * Cat.SPOT_R), Pal.SUN)
		_:
			var level := int(key.substr(4))
			b.fan(Face.Builder.ring(Vector2.ZERO, r * Cat.FACE_IN, r * Cat.FACE_IN), Color(Pal.SURFACE, 0.1 * level))
	var soup := Soup.new()
	soup.add_builder(b)
	_parts[key] = soup
	return soup

## Triangles as a flat list -- three vertices each, no index -- so whole
## lists can be appended through a transform with native array calls.
class Soup:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()

	func add(part: Soup, xf: Transform2D) -> void:
		verts.append_array(xf * part.verts)
		cols.append_array(part.cols)

	func add_builder(b) -> void:
		for i in b.idx:
			verts.append(b.verts[i])
			cols.append(b.cols[i])

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return out

## How swollen segment `i` of `n` is by the crawl and the gulps.
func _swell(i: int, n: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var k := n - 1 - i
	if k >= maxi(RIPPLE_REACH, GULP_REACH):
		return 1.0
	var out := 1.0
	for at in _gulps:
		var g := (t - at - float(k) * GULP_STEP) / GULP_TIME
		if g > 0.0 and g < 1.0 and k < GULP_REACH:
			out = maxf(out, 1.0 + GULP * sin(PI * g) * (1.0 - float(k) / float(GULP_REACH)))
	for at in _ripples:
		var u := (t - at - float(k) * RIPPLE_STEP) / RIPPLE_TIME
		if u > 0.0 and u < 1.0 and k < RIPPLE_REACH:
			out = maxf(out, 1.0 + RIPPLE * sin(PI * u) * (1.0 - float(k) / float(RIPPLE_REACH)))
	return out

## The segments cut away, each popping out where it stood.
func _draw_ghosts(b, t: float) -> void:
	var keep: Array = []
	for g: Dictionary in _ghosts:
		var e := t - float(g["at"])
		if e < 0.0:
			Cat.segment(b, g["from"], g["dir"], g["r"], Vector2.ONE, g["fill"])
			keep.append(g)
		elif e < GHOST_TIME:
			var k := Motion.pop_out_scale(e, GHOST_TIME)
			Cat.segment(b, g["from"], g["dir"], g["r"], Vector2(k * (1.0 + 0.3 * (1.0 - k)), k), g["fill"], k)
			keep.append(g)
	_ghosts = keep

## Every square of `old` the body no longer has pops out, `stagger` apart
## from the tail end.
func _ghost_diff(old: PackedInt32Array, t: float, stagger := 0.0) -> void:
	if Motion.reduce:
		return
	var now := {}
	for c in _state.body:
		now[c] = true
	var k := 0
	for i in old.size():
		var c := old[i]
		if now.has(c):
			continue
		var dir := Vector2(1.0, 0.0)
		if old.size() > 1:
			var a := _centre(old[maxi(i - 1, 0)])
			var z := _centre(old[mini(i + 1, old.size() - 1)])
			dir = (z - a).normalized() if a.distance_to(z) > 0.01 else dir
		_ghosts.append({"at": t + float(k) * stagger, "from": _centre(c), "dir": dir,
			"r": _cell() * Cat.SEG_R, "fill": Pal.LEAF if i % 2 == 1 else Pal.LEAF_LIGHT})
		k += 1
	_busy_for(float(k) * stagger + GHOST_TIME)

## The leaf lying on a leaf's square, under the body: it pops in with its
## badge, and once eaten carries three bites out of its edge.
func _leaf(soup: Soup, c: int, t: float) -> void:
	var f := _badge_frame(c, t)
	if f.scale.x <= 0.01:
		return
	var got: bool = _state.body.has(c) and c != _misstepped()
	var bites := ""
	for q in CHEWS:
		bites += str(roundi(_bite(c, t, q) * 4.0))
	var key := "l%d|%s|%s" % [c, got, bites]
	if not _cache.has(key):
		var b := Face.Builder.new()
		_leaf_shape(b, c, got, bites)
		var piece := Soup.new()
		piece.add_builder(b)
		_cache[key] = piece
	soup.add(_cache[key], Transform2D(0.0, f.scale, 0.0, f.at))

## A leaf about its square's centre: its shadow side, its face, the vein and
## its side veins, the stalk, and the bites in `bites` (one digit a chew,
## quarters of the way open).
func _leaf_shape(b, c: int, got: bool, bites: String) -> void:
	var s := _cell()
	var big := PECK_LEAF if _unmarked(c) else 1.0
	var xf := Transform2D(LEAF_ANGLE, Vector2(big, big), 0.0, Vector2(s * 0.03, s * 0.02))
	var ln := s * LEAF_LEN
	var wd := s * LEAF_WIDE
	var root := Vector2(-ln * 0.5, 0.0)
	var tip := Vector2(ln * 0.5, 0.0)
	var pts := Face.Builder.bezier3(root, Vector2(-ln * 0.2, -wd * 0.75), Vector2(ln * 0.3, -wd * 0.55), tip, 12)
	pts.append_array(Face.Builder.bezier3(tip, Vector2(ln * 0.3, wd * 0.55), Vector2(-ln * 0.2, wd * 0.75), root, 12))
	for q in CHEWS:
		var bitten := float(bites.substr(q, 1)) / 4.0
		if bitten <= 0.0:
			continue
		var at := Vector2(ln * (0.08 + 0.13 * float(q)), -wd * (0.36 - 0.06 * float(q)))
		var cut := Geometry2D.clip_polygons(pts, Face.Builder.ring(at, s * BITE_R * bitten, s * BITE_R * bitten))
		if not cut.is_empty():
			pts = cut[0]
	var ghost: Color = Pal.LEAF_LIGHT if not got else Pal.LEAF_LIGHT.lerp(Pal.LEAF, 0.35)
	var under := PackedVector2Array()
	for p in pts:
		under.append(p + Vector2(0.0, s * 0.03).rotated(-LEAF_ANGLE))
	b.polygon(xf * under, Pal.LEAF_DEEP)
	b.polygon(xf * pts, ghost)
	b.stroke(xf * PackedVector2Array([root + Vector2(ln * 0.02, 0.0), tip - Vector2(ln * 0.08, 0.0)]), s * 0.022, Pal.LEAF)
	for q in 3:
		var x := -ln * 0.28 + ln * 0.22 * float(q)
		for side: float in [-1.0, 1.0]:
			b.stroke(xf * PackedVector2Array([Vector2(x, 0.0), Vector2(x + ln * 0.12, side * wd * 0.26)]), s * 0.014, Color(Pal.LEAF, 0.8))
	b.stroke(xf * PackedVector2Array([root, root - Vector2(ln * 0.1, -wd * 0.05)]), s * 0.028, Pal.LEAF_DEEP)

## On Peckish only the first and the last leaf carry a badge.
func _unmarked(c: int) -> bool:
	var k: int = _state.clue[c]
	return _state.peckish() and k != 1 and k != _state.last_leaf()

func _bite(c: int, t: float, q: int) -> float:
	if not _state.body.has(c) or c == _misstepped():
		return 0.0
	if Motion.reduce or not _munched.has(c):
		return 1.0
	return clampf((t - float(_munched[c]) - (float(q) + 0.35) * CHEW) / BITE_OPEN, 0.0, 1.0)

# --- the badges over the body ---

func _build_over(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	for k in _state.leaves.size():
		_badge(b, _state.leaves[k], t)
	return b.mesh() if not b.verts.is_empty() else null

## A leaf's badge over the body: an ink disc with a gold ring once eaten. It
## pops in on the entrance by its number, bumps when eaten, and flashes and
## shivers when a step onto it was refused. On Peckish the last leaf's badge
## carries a star instead of a number, and the middle leaves have none.
func _badge(b, c: int, t: float) -> void:
	if _unmarked(c):
		return
	var f := _badge_frame(c, t)
	if f.scale.x <= 0.01:
		return
	var s := _cell()
	var r := s * BADGE_R
	var xf := Transform2D(0.0, f.scale, 0.0, f.at)
	var got: bool = _state.body.has(c) and c != _misstepped()
	Scenery.soft_disc(b, f.at + Vector2(0.0, s * 0.04), r * 1.3 * f.scale.x, r * 1.15 * f.scale.x, Color(Pal.TEXT, 0.18))
	if got:
		var ring := r + s * (EATEN_RING + EATEN_RING_W * 0.5)
		b.fan(xf * Face.Builder.ring(Vector2(0.0, s * 0.02), ring, ring), Pal.SUN_DEEP)
		b.fan(xf * Face.Builder.ring(Vector2.ZERO, ring, ring), Pal.SUN)
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, r, r), Pal.TEXT.lerp(Pal.BAD, f.flash * 0.7))
	b.fan(xf * Face.Builder.ring(Vector2(-0.3, -0.42) * r, r * 0.34, r * 0.16), Color(1.0, 1.0, 1.0, 0.12))
	if _state.peckish() and _state.clue[c] == _state.last_leaf():
		b.polygon(xf * Seal.star(Vector2(0.0, r * 0.04), r * 0.62), Pal.SUN)

func _badge_frame(c: int, t: float) -> Dictionary:
	var k: int = _state.clue[c]
	var hot := int(_refused["cell"]) == c and String(_refused["kind"]) in ["order", "last"]
	var since := t - float(_refused["at"]) if hot else -1.0
	var pop := Motion.pop_in_scale(t - _opened - Motion.ENTER_DELAY - Motion.ENTER_POP * 0.4
		- Motion.stagger(k, Motion.ENTER_STAGGER))
	var bump := 1.0
	for r: Dictionary in _rings:
		if int(r["cell"]) == c:
			bump = maxf(bump, Motion.bump_scale(t - float(r["at"]), 0.14, 0.3))
	return {"at": _centre(c) + Vector2(Motion.shiver_offset(since) * 3.0 if hot else 0.0, 0.0),
		"scale": pop * bump, "flash": Motion.flash_level(since) if hot else 0.0}

## The leaf numbers, over the badges and under the head.
func _draw_numbers(t: float, xf: Transform2D, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	var px := int(round(_cell() * BADGE_R * NUMBER))
	for k in _state.leaves.size():
		var c: int = _state.leaves[k]
		if _state.peckish() and k != 0:
			continue
		var f := _badge_frame(c, t)
		if f.scale.x <= 0.01:
			continue
		var text := str(k + 1)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		var rise := font.get_height(px) * 0.5 - font.get_descent(px)
		draw_set_transform_matrix(xf * Transform2D(0.0, f.scale, 0.0, f.at))
		draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
			Color(Pal.SURFACE, seen))
	draw_set_transform_matrix(Transform2D.IDENTITY)

# --- the head ---

func _build_top(t: float) -> ArrayMesh:
	if _state.body.is_empty():
		return null
	var b := Face.Builder.new()
	var chain := _chain(t)
	var n := chain.size()
	var at := _points_head(t)
	var dir := Vector2(0.0, -1.0)
	if n > 1:
		# Along the path just behind wherever the head has got to.
		var u := float(n - 1) - _lag(t)
		var prev := _along(chain, maxf(0.0, u - 0.5))
		dir = (at - prev).normalized() if at.distance_to(prev) > 0.01 else \
			(_centre(chain[n - 1]) - _centre(chain[n - 2])).normalized()
	var since := t - float(_refused["at"])
	var strain := String(_refused["kind"]) != "" and since < Motion.SHIVER_TIME * 2.0
	at.x += Motion.shiver_offset(since) * 4.0 if strain else 0.0
	var worried := not _wrong.is_empty() and t - float(_wrong["at"]) < EJECT_AFTER + SLIP_TIME
	var expr := Face.Expr.JOY if _solved_at >= 0.0 else (Face.Expr.STRAIN if strain else Face.Expr.HAPPY)
	if worried:
		expr = Face.Expr.WORRIED
	elif _asleep:
		expr = Face.Expr.SLEEPY
	elif _state.peckish() and _solved_at < 0.0 and _state.tummy() <= 1 and not strain:
		expr = Face.Expr.WORRIED
	var grow := 1.0 if Motion.reduce else 1.0 + CRAWL * 0.6 * sin(t * CRAWL_RATE + CRAWL_PHASE)
	var sq := Vector2.ONE
	var sway := 0.0 if Motion.reduce else SWAY * sin(t * SWAY_RATE)
	var eye := _blink(t) if not _asleep else 0.0
	var snack := 0.0
	var k := (t - _munch_at) / CHEW
	if not Motion.reduce and k >= 0.0 and k < float(CHEWS) and _solved_at < 0.0:
		# Each chew is one smooth cosine: the jaw drops, the head squashes and
		# leans into the leaf, and it closes again, a little softer each time.
		var w := (0.5 - 0.5 * cos(TAU * fmod(k, 1.0))) * (1.0 - 0.2 * floorf(k))
		sq = Vector2(1.0 + CHEW_SQUASH * 0.6 * w, 1.0 - CHEW_SQUASH * w)
		at += dir * _cell() * CHEW_LEAN * w
		sway += 0.3 * w
		expr = Face.Expr.JOY if w > 0.45 else Face.Expr.HAPPY
		eye = 0.1
		snack = 1.0 - clampf((k - 0.5) / float(CHEWS), 0.0, 1.0)
	var pe := t - _press_at
	if not Motion.reduce and pe >= 0.0 and pe < PRESS_TIME:
		var w := sin(PI * pe / PRESS_TIME)
		sq *= Vector2(1.0 + PRESS_SQUASH * w, 1.0 - PRESS_SQUASH * w)
	if worried and not Motion.reduce:
		var e := t - float(_wrong["at"])
		at.x += sin(e * 30.0) * _cell() * 0.03 * maxf(0.0, 1.0 - e / EJECT_AFTER)
		sway += 0.25 * sin(e * 9.0)
	if strain and not Motion.reduce:
		sway -= 0.3 * sin(PI * clampf(since / (Motion.SHIVER_TIME * 2.0), 0.0, 1.0))
	Cat.head(b, at, dir, _cell(), grow, sq, expr, eye, sway, snack)
	return b.mesh()

## The head's point this frame, as `_points` would place it, without
## walking the whole chain.
func _points_head(t: float) -> Vector2:
	var chain := _chain(t)
	var last := chain.size() - 1
	var p := _centre(chain[last])
	var left := _retreat_left(t)
	if left > 0.0:
		var frac := left - floorf(left)
		if frac > 0.0 and last > 0:
			p = _centre(chain[last - 1]).lerp(p, frac)
	elif _lag(t) > 0.0:
		p = _along(chain, float(last) - _lag(t))
	if _solved_at >= 0.0:
		p.y += Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY - _wave(last, _state.body.size()),
			Motion.SOLVE_HOP, Motion.SOLVE_TIME)
	return p

func _blink(t: float) -> float:
	if Motion.reduce:
		return 1.0
	var m := fmod(t + 0.4, 3.8)
	return 1.0 - 0.9 * sin(PI * m / 0.14) if m < 0.14 else 1.0

## The butterfly the solve ends in: it unfolds out of the head once the hop
## has reached it, flies a loop over the garden and leaves over the top of
## the card. It is drawn outside the entrance transform and is not clipped,
## so it can fly over the chrome.
func _draw_butterfly_mesh(t: float, shown: Array) -> void:
	if _solved_at < 0.0 or Motion.reduce:
		return
	var u := t - _solved_at - Motion.SOLVE_DELAY - SOLVE_SPAN - BUTTERFLY_LAG
	if u < 0.0 or u > BUTTERFLY_TIME:
		return
	var s := _cell()
	var start := _centre(_state.head())
	var at := _flight(u, start, s)
	var ahead := _flight(u + 0.05, start, s)
	var open := clampf(u / BUTTERFLY_OPEN, 0.0, 1.0)
	var alpha := 1.0 - clampf((u - (BUTTERFLY_TIME - 0.35)) / 0.35, 0.0, 1.0)
	var beat := lerpf(0.15, 0.3 + 0.7 * absf(sin(u * 12.0)), Motion.back_out(open))
	var w := s * BUTTERFLY_W * lerpf(0.35, 1.0, Motion.back_out(open))
	var b := Face.Builder.new()
	Scenery.soft_disc(b, Vector2(at.x, start.y + s * 0.3), w * 0.9 * alpha, w * 0.3 * alpha, Color(Pal.TEXT, 0.12 * (1.0 - clampf(u, 0.0, 1.0))))
	Cat.butterfly(b, at, w, beat, clampf((ahead.x - at.x) * 0.02, -0.4, 0.4), alpha)
	var m := b.mesh()
	draw_mesh(m, null)
	shown.append(m)

func _flight(u: float, start: Vector2, s: float) -> Vector2:
	var rise := clampf((u - BUTTERFLY_OPEN) / (BUTTERFLY_TIME - BUTTERFLY_OPEN), 0.0, 1.0)
	var loop := BUTTERFLY_LOOP * s * sin(PI * minf(rise * 1.6, 1.0))
	var ang := rise * TAU * 0.9
	var side := -1.0 if start.x > _mid().x else 1.0
	var p := start + Vector2(side * sin(ang) * loop, -(1.0 - cos(ang)) * loop * 0.6)
	p.y -= pow(rise, 2.2) * BUTTERFLY_RISE + s * 0.35 * clampf(u / BUTTERFLY_OPEN, 0.0, 1.0)
	p.x += side * pow(rise, 2.0) * s * 1.5
	p.y += sin(u * 9.0) * s * 0.06 * rise
	return p

# --- input ---

## Only the finger that started a stroke moves it (Quilt's rule): a second
## finger's press, drag and release are ignored while one is held, or the
## walked drag would crawl the line between two fingers -- and on Hard and
## Insane, price the squares it crossed.
func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts:
		return
	var finger: int = event.index if (event is InputEventScreenTouch or event is InputEventScreenDrag) else -1
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if _dragging:
				accept_event()
				return
			_finger = finger
			_drag_pos = event.position
			_via = -1
			_press(_cell_at(event.position))
		elif finger == _finger:
			_release()
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _dragging and finger == _finger:
		_drag_to(event.position)
		accept_event()

## Walks the finger from where it was to `to` in short steps, so a flick that
## crosses several squares between two touch events grows every one of them
## in order -- the first cut read only the square under the newest event and
## dropped the ones in between, which a fast drag felt as the line lagging
## behind and catching up in jumps.
func _drag_to(to: Vector2) -> void:
	var from := _drag_pos
	_drag_pos = to
	var s := _cell()
	if s <= 0.0:
		return
	var steps := maxi(1, int(ceil(from.distance_to(to) / (s * DRAG_SAMPLE))))
	for k in steps:
		if not _dragging:
			return
		var p := from.lerp(to, float(k + 1) / float(steps))
		var c := _cell_at(p, true)
		if c >= 0:
			_follow(c, p)
		else:
			# Over a square's margin, not its core: not a step, but the side
			# a corner was taken by.
			_via = _cell_at(p)

## The finger is over square `c` at `p`: step onto it, cut back to it, or,
## when it went through a corner into a diagonal square, step through a side
## square first -- the one whose margin the finger crossed, else the nearer,
## of the two the board allows **and the judge prices at nothing**. A finger crossing a corner has not said which side it
## meant, so that gesture never costs a heart: when both sides would, the
## head simply waits for the finger to come round.
func _follow(c: int, p: Vector2) -> void:
	var h: int = _state.head()
	if c == h or h < 0:
		return
	if _state.body.has(c) or _state.adjacent(h, c):
		_step(c)
		return
	var dx: int = c % _state.cols - h % _state.cols
	var dy: int = c / _state.cols - h / _state.cols
	if absi(dx) != 1 or absi(dy) != 1:
		return
	var sides := [h + dx, h + dy * _state.cols]
	sides.sort_custom(func(a, b): return _centre(a).distance_to(p) < _centre(b).distance_to(p))
	if sides[1] == _via:
		sides.reverse()
	for m: int in sides:
		if not _state.body.has(m) and _state.why(m) == "" and _state.judge(m) == "":
			_step(m)
			if _dragging and _state.head() == m:
				_step(c)
			return

func _press(c: int) -> void:
	if c < 0 or busy():
		return
	var t := _now()
	_stroke_from = _state.body.duplicate()
	if _state.body.is_empty():
		if _state.start(c):
			_busy_for(Motion.POP_IN)
			_seg_at = [t]
			_lag0 = 0.0
			_head_at = t
			_press_at = t
			_dragging = true
			_ring_at(c, t)
			fx.cue("place")
			_dirty()
		else:
			_say(tr("CP_START"), Face.Expr.HAPPY)
		return
	if _state.body.has(c):
		_dragging = true
		if c != _state.head():
			_cut(c, t)
		else:
			_press_at = t
			_busy_for(PRESS_TIME)
			_refresh()
	else:
		_say(tr("CP_FROM_HEAD"), Face.Expr.HAPPY)

func _step(c: int) -> void:
	if c == _state.head() or busy():
		return
	var t := _now()
	if _state.body.has(c):
		_cut(c, t)
		return
	var why: String = _state.why(c)
	if why == "far":
		return
	if why != "":
		if int(_refused["cell"]) != c or t - float(_refused["at"]) > REFUSE_QUIET:
			_refuse(why, c, t)
		return
	var cost: String = _state.judge(c)
	if cost != "":
		_misstep(c, cost, t)
		return
	_retreat = PackedInt32Array()
	_lag0 = minf(_lag(t) + 1.0, LAG_MAX)
	_lag_at = t
	_head_at = t
	_state.grow(c)
	_seg_at.append(t)
	_crawl(t)
	_busy_for(maxf(SLIDE_TIME, Motion.POP_IN))
	if _state.clue[c] != 0:
		_eat(c, t + SLIDE_TIME)
		fx.cue("munch")
		if _state.peckish() and not _state.is_solved():
			_after(SLIDE_TIME + float(CHEWS) * CHEW, fx.cue.bind("fill", 1.0, -3.0))
			_heart_layer.queue_redraw()
		_speak_leaf(_state.clue[c])
		_dirty()
		_on_leaf(c)
	else:
		fx.cue("step")
		if _state.peckish():
			_heart_layer.queue_redraw()
	_rows_filled(c, t)
	_refresh()
	if _state.is_solved():
		_release()

## The head has landed on leaf `c` at `at`: it chews, a bite and a few
## crumbs a chew, and swallows.
func _eat(c: int, at: float) -> void:
	_munch_at = at
	_munched[c] = at
	_ring_at(c, at)
	var chewing := float(CHEWS) * CHEW
	_busy_for(at - _now() + chewing)
	_decor_for(at - _now() + chewing + Motion.RING_TIME * 0.6)
	if Motion.reduce:
		return
	for q in CHEWS:
		get_tree().create_timer(at - _now() + (float(q) + 0.4) * CHEW).timeout.connect(func():
			if _state.body.has(c):
				fx.puff(_centre(c) + Vector2(0.0, _cell() * 0.2), Pal.LEAF_LIGHT, 3))
	var keep: Array[float] = []
	for g in _gulps:
		if _now() - g < float(GULP_REACH) * GULP_STEP + GULP_TIME:
			keep.append(g)
	keep.append(at + chewing)
	_gulps = keep
	_busy_for(at - _now() + chewing + float(GULP_REACH) * GULP_STEP + GULP_TIME)

## A swell leaves the head and runs back down the body.
func _crawl(t: float) -> void:
	if Motion.reduce:
		return
	_walked_at = t
	_busy_for(WALK_FADE)
	var keep: Array[float] = []
	for at in _ripples:
		if t - at < float(RIPPLE_REACH) * RIPPLE_STEP + RIPPLE_TIME:
			keep.append(at)
	keep.append(t)
	_ripples = keep
	_busy_for(float(RIPPLE_REACH) * RIPPLE_STEP + RIPPLE_TIME)

func _cut(c: int, t: float) -> void:
	_busy_for(Motion.POP_IN)
	var old: PackedInt32Array = _state.body.duplicate()
	var leaves_before: int = _state.eaten()
	_state.cut_to(c)
	if not Motion.reduce:
		_retreat = old.slice(_state.body.size())
		_retreat_at = t
		_retreat_step = minf(RETREAT_STEP, RETREAT_MAX / float(maxi(_retreat.size(), 1)))
		var run := _retreat_step * float(_retreat.size())
		_walked_at = t + run
		_busy_for(run + WALK_FADE)
	_seg_at.resize(_state.body.size())
	_lag0 = 0.0
	_head_at = t
	if _state.eaten() < leaves_before:
		_break_streak()
		_clear_gags()
	fx.cue("step")
	_heart_layer.queue_redraw()
	_dirty()

func _refuse(kind: String, c: int, t: float) -> void:
	_refused = {"at": t, "cell": c, "kind": kind}
	_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)
	_decor_for(Motion.FLASH_IN + Motion.FLASH_OUT)
	match kind:
		"hedge": _say(tr("CP_NO_FENCE"), Face.Expr.STRAIN)
		"order": _say(tr("CP_NO_ORDER") % [_state.clue[c], _state.eaten() + 1], Face.Expr.STRAIN)
		"last": _say(tr("CP_NO_LAST") % _state.last_leaf() if not _state.peckish() else tr("CP_NO_LAST_PECK"), Face.Expr.STRAIN)
		"hungry":
			_say(tr("CP_HUNGRY"), Face.Expr.WORRIED)
			_hungry_at = t
			_heart_layer.queue_redraw()
	fx.cue("hungry" if kind == "hungry" else "refuse")
	_refresh()

## The finger is up: a stroke that changed the body is one move.
func _release() -> void:
	if not _dragging:
		return
	_dragging = false
	if _state.commit(_stroke_from):
		note_move()

func _ring_at(c: int, at: float) -> void:
	if Motion.reduce:
		return
	_rings.append({"cell": c, "at": at})
	_busy_for(at - _now() + Motion.RING_TIME)
	_decor_for(at - _now() + 0.3)

func _drop_rings(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rings:
		if t - float(r["at"]) < Motion.RING_TIME:
			keep.append(r)
	_rings = keep

# --- the wrong step (Hard and Insane) ---

## A legal step the judge says costs a heart: the stroke so far is kept as
## its own move, the caterpillar steps onto `c` and worries, the squares it
## stranded blush and wobble, a heart splits, and EJECT_AFTER later it
## scoots back to where it was. The state takes the square back at once in
## spirit -- nothing else can happen until it has (`busy()`) -- and for real
## when the scoot starts.
func _misstep(c: int, kind: String, t: float) -> void:
	_release()
	_lost_ever = true
	_break_streak()
	_clear_gags()
	var cells: PackedInt32Array = _state.stranded(c)
	hearts = maxi(0, hearts - 1)
	_split_index = hearts
	_split_at = t + (0.0 if Motion.reduce else SLIDE_TIME)
	var room: int = _state.tummy()
	_retreat = PackedInt32Array()
	_lag0 = minf(_lag(t) + 1.0, LAG_MAX)
	_lag_at = t
	_head_at = t
	_state.grow(c)
	_seg_at.append(t)
	_crawl(t)
	# A leaf stepped onto in error is not eaten: no bites, no gold ring, and
	# the tummy shows what it had (`_misstepped`).
	_munched[c] = INF
	_wrong = {"at": t, "cell": c, "cells": cells, "room": room}
	var eject := Motion.REDUCED_TIME if Motion.reduce else EJECT_AFTER
	_busy_until = t + eject + (0.0 if Motion.reduce else SLIP_TIME) + 0.05
	_was_busy = true
	_busy_for(eject + SLIP_TIME + 0.1)
	_decor_for(maxf(BLUSH_TIME, eject + SLIP_TIME))
	if hearts <= 0:
		out_of_hearts = true
	fx.cue("strand")
	_after(SLIDE_TIME, func() -> void:
		fx.cue("heart_lost")
		_heart_layer.queue_redraw())
	var line := "CP_STRAND"
	if kind == "doom" and cells.is_empty():
		line = "CP_DOOM"
	elif _state.peckish() and cells.is_empty():
		line = "CP_STARVE"
	_say(tr(line) + " " + (tr("CP_HEARTS_ONE") if hearts == 1 else (tr("CP_HEARTS_N") % hearts if hearts > 1 else "")),
		Face.Expr.WORRIED)
	_heart_layer.queue_redraw()
	_dirty()
	moved.emit()
	_after(eject, _slip_back.bind(c))

## The square a wrong step is standing on until it scoots back, or -1.
func _misstepped() -> int:
	if _wrong.is_empty() or _state.head() != int(_wrong["cell"]):
		return -1
	return int(_wrong["cell"])

## The scoot home: the square comes off the body and the head runs back.
func _slip_back(c: int) -> void:
	if _state.head() != c:
		return
	var t := _now()
	_state.take_back()
	_munched.erase(c)
	_seg_at.resize(_state.body.size())
	if not Motion.reduce:
		_retreat = PackedInt32Array([c])
		_retreat_at = t
		_retreat_step = SLIP_TIME
	_lag0 = 0.0
	_head_at = t
	fx.cue("slip")
	_busy_for(SLIP_TIME + 0.05)
	_heart_layer.queue_redraw()
	_dirty()
	if out_of_hearts:
		_after(SLIP_TIME, _run_out)

## A row or a column the step at `c` has just filled sparkles along its
## length, out from the head.
func _rows_filled(c: int, t: float) -> void:
	if Motion.reduce or _state.is_solved():
		return
	var on := {}
	for q in _state.body:
		on[q] = true
	var x: int = c % _state.cols
	var y: int = c / _state.cols
	var lines: Array = []
	var row := PackedInt32Array()
	var col := PackedInt32Array()
	for k in _state.cols:
		row.append(y * _state.cols + k)
	for k in _state.rows:
		col.append(k * _state.cols + x)
	for line: PackedInt32Array in [row, col]:
		var full := true
		for q in line:
			if not on.has(q):
				full = false
				break
		if full:
			lines.append(line)
	if lines.is_empty():
		return
	fx.cue("row", 1.0, -4.0)
	for line: PackedInt32Array in lines:
		for q in line:
			var d: int = absi(q % _state.cols - x) + absi(q / _state.cols - y)
			_after(float(d) * ROW_STEP, func() -> void:
				fx.sparkle(_centre(q), Pal.SUN))
	_busy_for(float(maxi(_state.cols, _state.rows)) * ROW_STEP + Motion.RING_TIME)

# --- the sprout's line ---

func _speak_leaf(k: int) -> void:
	if _state.peckish():
		var left: int = _state.last_leaf() - _state.eaten()
		if left > 0:
			_say(tr("CP_YUM_ONE") if left == 1 else tr("CP_YUM_N") % left, Face.Expr.HAPPY)
		return
	var left: int = _state.last_leaf() - k
	if left > 0:
		_say(tr("CP_LEAF_ONE") % k if left == 1 else tr("CP_LEAF_N") % [k, left], Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or not _state.body.is_empty():
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	var line := tr(tips[_tip_idx])
	if tips[_tip_idx] == "CP_TIP_TUMMY":
		line = line % _state.hunger
	_say(line, Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

## No Undo on Insane: dragging back over the body still takes steps back, but
## a stroke cannot be wished away.
func can_undo() -> bool:
	return _state.can_undo() and not is_done() and not out_of_hearts and not busy() \
		and _state.difficulty < 3

## Puts the body back as it was before the last stroke. Counts no move.
func undo() -> bool:
	if not can_undo():
		return false
	var old: PackedInt32Array = _state.body.duplicate()
	if not _state.undo():
		return false
	_undo_ever = true
	_break_streak()
	_clear_gags()
	_retreat = PackedInt32Array()
	_ghost_diff(old, _now())
	_restored(_now())
	_say(tr("CP_UNDONE"), Face.Expr.HAPPY)
	fx.cue("undo")
	_heart_layer.queue_redraw()
	moved.emit()
	return true

## A body that came back whole: the segments it has that the old one did not
## pop back in, tail first.
func _restored(t: float) -> void:
	var n: int = _state.body.size()
	var had := mini(_seg_at.size(), n)
	_seg_at.resize(n)
	for i in range(had, n):
		_seg_at[i] = t + Motion.stagger(i - had, Motion.RESET_STAGGER)
	_lag0 = 0.0
	_head_at = t
	_busy_for(Motion.stagger(maxi(n - had, 0), Motion.RESET_STAGGER) + Motion.POP_IN)
	_dirty()

func add_hint() -> void:
	hints_extra += 1

func hints_left() -> int:
	return maxi(0, State.hints_for(_state.difficulty) + hints_extra - hints_used)

## Cuts back to the right stretch and grows the answer on to the next leaf.
func hint() -> bool:
	if is_done() or out_of_hearts or busy() or hints_left() <= 0:
		return false
	var t := _now()
	var old: PackedInt32Array = _state.body.duplicate()
	var grown: PackedInt32Array = _state.hint()
	if grown.is_empty():
		return false
	_retreat = PackedInt32Array()
	_ghost_diff(old, t)
	hints_used += 1
	_break_streak()
	var n: int = _state.body.size()
	_seg_at.resize(n)
	for k in grown.size():
		_seg_at[n - grown.size() + k] = t + float(k) * HINT_STEP
	_lag0 = 0.0
	_head_at = t
	_ring_at(grown[grown.size() - 1], t + float(grown.size() - 1) * HINT_STEP)
	_busy_for(float(grown.size()) * HINT_STEP + Motion.POP_IN)
	_say(tr("CP_HINT"), Face.Expr.HAPPY)
	fx.cue("hint")
	_heart_layer.queue_redraw()
	_dirty()
	moved.emit()
	check_solved()
	return true

func can_reset() -> bool:
	return not (is_done() or out_of_hearts or busy())

func reset_board() -> void:
	if not can_reset():
		return
	_wave_home()
	moves = 0
	_running = true
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	fx.cue("reset")
	moved.emit()

## The body pops away tail first and the garden is empty again.
func _wave_home() -> void:
	var old: PackedInt32Array = _state.body.duplicate()
	_state.reset_board()
	_retreat = PackedInt32Array()
	_ghost_diff(old, _now(), Motion.RESET_STAGGER)
	_seg_at = []
	_lag0 = 0.0
	_dragging = false
	_rings = []
	_solved_at = -1.0
	_break_streak()
	_clear_gags()
	_heart_layer.queue_redraw()
	_dirty()

func is_solved() -> bool:
	return _state.is_solved()

## What a reopened daily needs: the hearts kept and whether it was flawless.
func completion_record() -> Dictionary:
	return {"hearts": hearts, "flawless": _flawless}

## The shape of the day and never its walk: the leaves, then the seal's words.
func share_glyphs() -> String:
	var out := "🐛" + "🍃".repeat(_state.last_leaf()) + "🦋"
	if _state.peckish() and is_solved():
		out += " 😋 " + tr("CP_PECKISH_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += " 🏅 " + tr("BN_FLAWLESS")
	return out

# --- hearts ---

func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell() <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := maxf(HEART_TOP + HEART_PILL_PAD.y + HEART_R,
		_origin().y - GROUND_PAD - FRAME - HEART_PILL_PAD.y - HEART_R - 8.0)
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var pip_step := 2.0 * PIP_R + PIP_GAP
	var tummy_pill := Vector2(pip_step * (_state.hunger - 1) + 2.0 * PIP_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var whole := pill.x + ((PILL_GAP + tummy_pill.x) if _state.peckish() else 0.0)
	var left := size.x * 0.5 - whole * 0.5
	var corner := Vector2(left, y - pill.y * 0.5)
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
	if enter <= 0.0:
		return
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	var x0 := left + HEART_PILL_PAD.x + HEART_R
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
	if _state.peckish():
		# The tummy: a leaf pip for every bare square it still has room for.
		var e := now - _hungry_at
		var shake := Motion.shiver_offset(e) * 3.0 if e < Motion.SHIVER_TIME * 2.0 else 0.0
		var tc := Vector2(left + pill.x + PILL_GAP + shake, y - tummy_pill.y * 0.5)
		b.polygon(Face.Builder.round_rect(tc - rim, tummy_pill + 2.0 * rim, tummy_pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
		b.polygon(Face.Builder.round_rect(tc, tummy_pill, tummy_pill.y * 0.5), Pal.SURFACE)
		var room: int = _state.tummy() if not _state.body.is_empty() else _state.hunger
		if _misstepped() >= 0:
			room = int(_wrong["room"])
		var low: bool = room <= 1 and not _state.body.is_empty()
		for i in _state.hunger:
			var at := Vector2(tc.x + HEART_PILL_PAD.x + PIP_R + pip_step * i, y)
			var full: bool = i < room
			var col: Color = (Pal.FLOWER if low else Pal.LEAF) if full else Color(Pal.LEAF, 0.2)
			_pip(b, at, PIP_R, col, Pal.LEAF_DEEP if full else Color(Pal.LEAF_DEEP, 0.15))
	_hearts_shown = b.mesh()
	var c := Vector2(size.x * 0.5, y)
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

## A small leaf lying across the tummy pill.
static func _pip(b, at: Vector2, r: float, col: Color, deep: Color) -> void:
	var xf := Transform2D(-0.6, at)
	var pts := Face.Builder.bezier2(Vector2(-r, 0.0), Vector2(0.0, -r * 1.1), Vector2(r, 0.0), 8)
	pts.append_array(Face.Builder.bezier2(Vector2(r, 0.0), Vector2(0.0, r * 1.1), Vector2(-r, 0.0), 8))
	var under := PackedVector2Array()
	for p in pts:
		under.append(p * 1.15 + Vector2(0.0, 1.5))
	b.polygon(xf * under, deep)
	b.polygon(xf * pts, col)
	b.stroke(xf * PackedVector2Array([Vector2(-r * 0.8, 0.0), Vector2(r * 0.7, 0.0)]), 1.5, deep)

static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

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

## The last heart is gone: dusk falls on the garden, the caterpillar curls
## up asleep, and the out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts or is_done():
		return
	_asleep = true
	_dragging = false
	_break_streak()
	_clear_gags()
	_tip_timer.stop()
	fx.cue("out_of_hearts")
	_say(tr("CP_OUT"), Face.Expr.SLEEPY)
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

func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["CP_OUT_BODY", "CP_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same garden, empty, every heart back, the clock and the
## moves from zero. Hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_gen += 1
	_deal()
	_wave_home()
	_state.history.clear()
	elapsed = 0.0
	moves = 0
	_running = true
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()

## One more heart (the card's video): once a garden. It wakes where it lay.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	var now := _now()
	_heart_used = true
	hearts = 1
	_back_index = 0
	_back_at = now
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_refresh()
	_say(tr("CP_HEART_BACK"), Face.Expr.HAPPY)
	_tip_timer.start()
	moved.emit()

func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

## Runs `what` after `delay`, unless the garden has been dealt again
## meanwhile.
func _after(delay: float, what: Callable) -> void:
	if not is_inside_tree():
		return
	var gen := _gen
	if delay <= 0.0:
		what.call()
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

# --- the rewards ---

func _reset_rewards() -> void:
	_streak = 0
	_streak_gen += 1
	_eats = 0
	_gag_until = 0.0
	_gag_gen += 1
	_combo_n = 0
	_combo_at = -INF
	_combo_out_at = -INF
	_love = []
	_bubbles = []
	_bugs = []
	_party_at = INF
	_stamp_at = INF
	_seal_mesh = null
	_cat_at = INF
	_cat_curled = false
	if is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null
	if _life_layer != null:
		_life_layer.queue_redraw()

## The day's own number, so a day always deals the same gags and wisdom.
func _day_hash() -> int:
	if _state.leaves.is_empty():
		return 0
	return absi(hash([_state.cols, _state.leaves.size(), int(_state.leaves[0]), _state.hedges.size()]))

## The player's own step has just eaten leaf `c`: the streak grows -- a note
## up the pentatonic from the second, the bubble over the leaf from the
## third, confetti at 4, 7 and every 5 -- and one leaf in GAG_ODDS a gag.
## The last leaf does none of it: the party is coming.
func _on_leaf(c: int) -> void:
	if _state.is_solved():
		return
	_eats += 1
	_streak += 1
	var count := _streak
	var gen := _streak_gen
	var lands := _now() + SLIDE_TIME + float(CHEWS) * CHEW
	if count >= 2:
		var step: int = COMBO_STEPS[mini(count - 2, COMBO_STEPS.size() - 1)]
		_after(SLIDE_TIME + 0.05, func() -> void:
			if gen == _streak_gen:
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	var at := _centre(c)
	if count >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = count
		_combo_pos = at - Vector2(0.0, _cell() * 0.35)
		_combo_at = _now()
		_combo_out_at = -INF
	if _confetti_at(count) and not Motion.reduce:
		_after(SLIDE_TIME, func() -> void:
			if gen == _streak_gen:
				fx.confetti(at, 22)
				fx.cue("confetti"))
	_start_gag(c, _pick_gag(), lands)
	_life_layer.queue_redraw()

static func _confetti_at(count: int) -> bool:
	return count == 4 or count == 7 or (count >= 10 and count % 5 == 0)

func _pick_gag() -> int:
	var t := _now()
	if Motion.reduce or t < _gag_until or force_gag == Gag.NONE:
		return Gag.NONE
	if force_gag >= 0:
		return force_gag
	var roll := posmod(_day_hash() + _eats * GAG_STEP, GAG_SPAN)
	if roll >= GAG_SPAN / GAG_ODDS:
		return Gag.NONE
	return roll % 3

## The streak ends: a cut past a leaf, a wrong step, an undo, a hint, a
## reset, the hearts running out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	_streak_gen += 1
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
	else:
		_combo_n = 0
	if _life_layer != null:
		_life_layer.queue_redraw()

func _clear_gags() -> void:
	_love = []
	_bubbles = []
	_bugs = []
	_gag_until = 0.0
	_gag_gen += 1
	if _life_layer != null:
		_life_layer.queue_redraw()

## The gag for leaf `c`, once the chewing is done: a happy hiccup blows a
## soap bubble that floats up off the head and pops (`burp`); love hearts
## float off the leaf (`love`); or a ladybug flies in, sits on the segment
## that ate the leaf a moment and flies off (`ladybug`).
func _start_gag(c: int, gag: int, lands: float) -> void:
	if gag == Gag.NONE:
		return
	var wait := maxf(0.0, lands - _now())
	var gg := _gag_gen
	var at := _centre(c)
	match gag:
		Gag.BUBBLE:
			_bubbles.append({"at": at - Vector2(0.0, _cell() * 0.3), "t": lands})
			_after(wait, func() -> void:
				if gg == _gag_gen:
					fx.cue("burp"))
			_after(wait + BUBBLE_TIME, func() -> void:
				if gg == _gag_gen and not Motion.reduce:
					fx.puff(at - Vector2(0.0, _cell() * (0.3 + BUBBLE_RISE)), Pal.SKY_TOP, 5))
			_gag_until = lands + BUBBLE_TIME
		Gag.LOVE:
			for k in LOVE_HEARTS:
				var side := float(k - 1)
				_love.append({"at": at + Vector2(side * 0.28, -0.1) * _cell(),
					"t": lands + 0.12 * float(k), "phase": float(k) * 2.1})
			_after(wait, func() -> void:
				if gg == _gag_gen:
					fx.cue("love"))
			_gag_until = lands + 0.24 + LOVE_TIME
		Gag.LADYBUG:
			var from := -1.0 if at.x > size.x * 0.5 else 1.0
			_bugs.append({"cell": c, "t": lands, "from": from})
			_after(wait, func() -> void:
				if gg == _gag_gen:
					fx.cue("ladybug"))
			_gag_until = lands + BUG_IN + BUG_SIT + BUG_OUT

# --- the win and the party ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("CP_WIN")}

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	var party := (_party_at - _now()) if _party_at < INF else PARTY_AT
	return maxf(WIN_WAIT, maxf(0.0, party) + PARTY_TIME)

func _on_solved() -> void:
	var t := _now()
	_dragging = false
	_solved_at = t + SLIDE_TIME
	_tip_timer.stop()
	# Flawless: no hint, and no heart lost on Hard and Insane, or never an
	# Undo on Easy and Medium.
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else not _undo_ever)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = t
	_streak_gen += 1
	_gag_gen += 1
	var n: int = _state.body.size()
	for c in _state.leaves:
		var i: int = _state.body.find(c)
		var after := _solved_at - t + Motion.SOLVE_DELAY + _wave(i, n)
		if not Motion.reduce:
			_after(after, func(): fx.sparkle(_centre(c), Pal.SUN))
	_busy_for(_solved_at - t + Motion.SOLVE_DELAY + SOLVE_SPAN + Motion.SOLVE_TIME
		+ BUTTERFLY_LAG + BUTTERFLY_TIME)
	_say(tr("CP_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_heart_layer.queue_redraw()
	_party()
	_dirty()

## After the hop: the butterfly loops away (`_draw_butterfly_mesh`), confetti
## twice, a flutter of little butterflies rises off the leaves, the nap cat
## hops onto the bed's foot and curls up, the sprout shares a bit of
## caterpillar wisdom, and the seal stamps when the solve earned one
## (flawless, or any Peckish). Under reduce motion the cat and the seal are
## simply there.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else SOLVE_SPAN + PARTY_AT
	_party_at = now + lead
	_after(lead + 0.8, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	_cat_at = now if Motion.reduce else _party_at + CAT_AT
	if _flawless or _state.peckish():
		_stamp_at = now if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
	if Motion.reduce:
		_life_layer.queue_redraw()
		return
	var field := _field_rect()
	_after(lead + 0.1, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell() * 0.5), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.7, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_after(lead + FLUTTER_AT, fx.cue.bind("flutter"))
	_life_layer.queue_redraw()

func _cheer() -> String:
	return tr("CP_CHEER_%d" % posmod(_day_hash(), CHEERS))

func _field_rect() -> Rect2:
	return Rect2(_origin(), _grid_size())

## The bed's outer edge: the grid, its lawn pad and the wooden frame.
func _frame_rect() -> Rect2:
	return _field_rect().grow(GROUND_PAD + FRAME)

## A reopened daily that was already solved: the whole walk laid at once,
## the cat asleep and the seal when it earned one. Never check_solved():
## `solved` must not fire twice.
func restore_completed_board() -> void:
	var t := _now()
	_gen += 1
	_close_card()
	_deal()
	_reset_rewards()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_flawless = bool(completed_record.get("flawless", false))
	_state.body = _state.path.duplicate()
	_state.history.clear()
	_seg_at = []
	for i in _state.body.size():
		_seg_at.append(-100.0)
	_lag0 = 0.0
	_solved_at = -1.0
	_anim_until = 0.0
	_decor_until = 0.0
	_opened = t - 100.0
	_cat_at = t - 100.0
	_place_cat(t)
	if _flawless or _state.peckish():
		_stamp_at = t - 100.0
	_tip_timer.stop()
	_say(tr("CP_WIN"), Face.Expr.JOY)
	_heart_layer.queue_redraw()
	_life_layer.queue_redraw()
	_dirty()

# --- the nap cat ---

func _cat_px() -> float:
	return size.x * CAT_PX

## Where she curls up: on the bed's foot, a fifth of the way along from its
## left (the seal takes the right).
func _cat_spot() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x + box.size.x * 0.22, box.end.y - _cat_px() * 0.3)

func _cat_start() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x + _cat_px() * 0.5, box.end.y - _cat_px() * 0.3)

func _cat_walk() -> float:
	return CAT_POP + CAT_HOPS * CAT_HOP_TIME

func _place_cat(t: float) -> void:
	if t < _cat_at or _cell() <= 0.0:
		return
	if not is_instance_valid(_cat):
		_cat = NapCat.new()
		_cat.name = "Cat"
		_cat.need = 0
		_cat.z_index = 3
		_cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cat.expression = Face.Expr.JOY
		add_child(_cat)
		_cat.set_idle(true)
		_cat_curled = false
	var px := _cat_px()
	if _cat.size.x != px:
		_cat.size = Vector2(px, px)
		_cat.pivot_offset = _cat.size * Vector2(0.5, 0.85)
	var e := t - _cat_at
	var spot := _cat_spot()
	var start := _cat_start()
	var at := spot
	var sc := Vector2.ONE
	if Motion.reduce or e >= CURL_AT - CAT_AT or _cat_curled:
		if not _cat_curled:
			_curl_cat(e > CURL_AT - CAT_AT + 1.0)
		else:
			_cat.position = _cat_spot() - _cat.size * 0.5
		return
	elif e < CAT_POP:
		at = start
		sc = Motion.pop_in_scale(e, CAT_POP)
	elif e < _cat_walk():
		var h := (e - CAT_POP) / CAT_HOP_TIME
		var n := int(h)
		var u := h - float(n)
		var from := start.lerp(spot, float(n) / CAT_HOPS)
		var to := start.lerp(spot, float(n + 1) / CAT_HOPS)
		at = from.lerp(to, u) - Vector2(0.0, 4.0 * u * (1.0 - u) * CAT_HOP_H * px)
		var s := 0.1 * sin(u * PI)
		sc = Vector2(1.0 - s, 1.0 + s)
	elif e < _cat_walk() + CAT_SETTLE:
		var u := (e - _cat_walk()) / CAT_SETTLE
		var s := 0.14 * sin(u * PI)
		sc = Vector2(1.0 + s, 1.0 - s)
	_cat.position = at - _cat.size * Vector2(0.5, 0.5)
	_cat.scale = sc

func _curl_cat(quiet: bool) -> void:
	_cat_curled = true
	_cat.expression = Face.Expr.SLEEPY
	_cat.scale = Vector2.ONE
	_cat.rotation = 0.0
	_cat.position = _cat_spot() - _cat.size * 0.5
	if not quiet:
		fx.cue("purr")

# --- the life over the garden ---

func _tick_life(now: float) -> bool:
	_love = _love.filter(func(l): return now < float(l.t) + LOVE_TIME)
	_bubbles = _bubbles.filter(func(l): return now < float(l.t) + BUBBLE_TIME)
	_bugs = _bugs.filter(func(f): return now < float(f.t) + BUG_IN + BUG_SIT + BUG_OUT)
	var party := not Motion.reduce and now >= _party_at - 0.05 and now < _party_at + PARTY_TIME + 0.5
	return not (_love.is_empty() and _bubbles.is_empty() and _bugs.is_empty()) or party \
		or (_combo_n >= COMBO_FROM and (now - _combo_at < Motion.POP_IN + 0.1 or _combo_out_at > -INF)) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## Each thing one cached mesh through a transform: love hearts, bubbles and
## ladybugs, the party's flutter (one mesh a frame for all of them), then the
## seal and the streak's bubble with their words.
func _draw_life() -> void:
	if _cell() <= 0.0 or _state.size() == 0:
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	var s := _cell()
	if not _love.is_empty():
		var mesh := _love_heart()
		shown.append(mesh)
		for l in _love:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / LOVE_TIME
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.1 * s,
				-LOVE_RISE * s * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	if not _bubbles.is_empty():
		var mesh := _bubble()
		shown.append(mesh)
		for l in _bubbles:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / BUBBLE_TIME
			# Blown out of the mouth: it swells, then drifts up wobbling.
			var k := minf(1.0, e / 0.35)
			k = k * k * (3.0 - 2.0 * k)
			var at: Vector2 = l.at + Vector2(sin(u * 7.0) * 0.12 * s, -BUBBLE_RISE * s * u * u)
			var wob := 1.0 + 0.06 * sin(e * 13.0)
			_life_layer.draw_mesh(mesh, null, Transform2D(0.0, Vector2(k * wob, k / wob), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.15, 0.0, 1.0)))
	for f in _bugs:
		_draw_bug(f, now, shown)
	if not Motion.reduce and now >= _party_at + FLUTTER_AT and now < _party_at + FLUTTER_AT + FLUTTER_TIME:
		_draw_flutter(now - _party_at - FLUTTER_AT, shown)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_combo(now, shown)
	_life_shown = shown

func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := maxf(12.0, _cell() * LOVE_R)
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

## A soap bubble: a pale film, a rim a shade bluer, and two shines.
func _bubble() -> ArrayMesh:
	if _bubble_mesh == null:
		var b := Face.Builder.new()
		var r := maxf(18.0, _cell() * BUBBLE_R)
		b.disc(Vector2.ZERO, r, Color(Pal.SKY_TOP, 0.4))
		b.disc(Vector2(r * 0.12, r * 0.15), r * 0.75, Color(Pal.SURFACE, 0.25))
		b.stroke(Face.Builder.arc_points(Vector2.ZERO, r, 0.0, TAU), maxf(2.5, r * 0.1), Color(Pal.MOON_DEEP.lerp(Pal.SKY_TOP, 0.4), 0.75), true)
		b.stroke(Face.Builder.arc_points(Vector2.ZERO, r * 0.72, PI * 1.05, PI * 1.45), maxf(2.0, r * 0.12), Color(1.0, 1.0, 1.0, 0.85))
		b.disc(Vector2(r * 0.38, r * 0.4), r * 0.09, Color(1.0, 1.0, 1.0, 0.7))
		b.stroke(Face.Builder.arc_points(Vector2.ZERO, r * 0.86, 0.2, 0.9), maxf(1.5, r * 0.06), Color(Pal.FLOWER, 0.45))
		_bubble_mesh = b.mesh()
	return _bubble_mesh

## A ladybug from above, its head to +x: a red dome split down the back,
## spots, an ink head with two white eyes.
func _bug() -> ArrayMesh:
	if _bug_mesh == null:
		var b := Face.Builder.new()
		var r := maxf(14.0, _cell() * BUG_R)
		Scenery.soft_disc(b, Vector2(0.0, r * 0.35), r * 1.15, r * 0.7, Color(Pal.TEXT, 0.18))
		b.disc(Vector2(r * 0.78, 0.0), r * 0.45, Pal.TEXT)
		for sy in [-1.0, 1.0]:
			b.disc(Vector2(r * 0.95, sy * r * 0.2), r * 0.12, Pal.SURFACE)
		var red := Color("e2584f")
		b.disc(Vector2.ZERO, r * 1.02, red.darkened(0.3))
		b.disc(Vector2(-r * 0.04, -r * 0.04), r * 0.94, red)
		b.stroke(PackedVector2Array([Vector2(r * 0.75, 0.0), Vector2(-r * 0.95, 0.0)]), maxf(1.5, r * 0.08), Pal.TEXT)
		for p in [Vector2(0.35, 0.45), Vector2(0.35, -0.45), Vector2(-0.35, 0.5), Vector2(-0.35, -0.5), Vector2(-0.05, 0.0)]:
			b.disc(p * r, r * 0.17, Pal.TEXT)
		b.ellipse(Vector2(-r * 0.2, -r * 0.45), r * 0.3, r * 0.12, Color(1.0, 1.0, 1.0, 0.35))
		_bug_mesh = b.mesh()
	return _bug_mesh

## The ladybug's clock: flying in on a curve from the card's side, sitting
## on the segment that ate the leaf (a wiggle of a bow now and then), and
## flying off up and away the other way. Its wings blur while it flies.
func _draw_bug(f: Dictionary, now: float, shown: Array) -> void:
	var e := now - float(f.t)
	if e <= 0.0:
		return
	var s := _cell()
	var mesh := _bug()
	shown.append(mesh)
	var spot := _centre(int(f.cell)) + Vector2(s * 0.05, -s * 0.12)
	var side: float = f.from
	var at := spot
	var ang := 0.0
	var flying := false
	if e < BUG_IN:
		var u := e / BUG_IN
		var eased := 1.0 - (1.0 - u) * (1.0 - u)
		var from := spot + Vector2(side * s * 3.2, -s * 2.4)
		at = from.lerp(spot, eased) + Vector2(0.0, -sin(PI * u) * s * 0.6)
		ang = (spot - from).angle() + sin(e * 20.0) * 0.15
		flying = true
	elif e < BUG_IN + BUG_SIT:
		var w := e - BUG_IN
		ang = -PI * 0.5 + sin(w * 6.0) * 0.25
		at = spot + Vector2(0.0, -absf(sin(w * 6.0)) * s * 0.03)
	else:
		var u := (e - BUG_IN - BUG_SIT) / BUG_OUT
		var to := spot + Vector2(-side * s * 3.0, -s * 3.6)
		at = spot.lerp(to, u * u) + Vector2(sin(u * 18.0) * s * 0.06, 0.0)
		ang = (to - spot).angle()
		flying = true
	if flying:
		var wing := absf(sin(e * 40.0))
		var b := Face.Builder.new()
		var r := maxf(14.0, s * BUG_R)
		for sy in [-1.0, 1.0]:
			b.ellipse(Vector2(-r * 0.1, sy * r * (0.7 + 0.35 * wing)), r * 0.85, r * 0.4, Color(Pal.SURFACE, 0.55))
		var wm := b.mesh()
		shown.append(wm)
		_life_layer.draw_mesh(wm, null, Transform2D(ang, at))
	_life_layer.draw_mesh(mesh, null, Transform2D(ang, at))

## The party's flutter: a little butterfly rises off each of up to FLUTTERS
## leaves, staggered, spiralling up and out of the card. All in one mesh a
## frame.
func _draw_flutter(e: float, shown: Array) -> void:
	var s := _cell()
	var b := Face.Builder.new()
	var count := mini(FLUTTERS, _state.leaves.size())
	var stride := maxi(1, _state.leaves.size() / maxi(count, 1))
	for k in count:
		var c: int = _state.leaves[mini(k * stride, _state.leaves.size() - 1)]
		var u := (e - 0.12 * float(k)) / (FLUTTER_TIME - 0.5)
		if u <= 0.0 or u >= 1.0:
			continue
		var side := 1.0 if k % 2 == 0 else -1.0
		var start := _centre(c)
		var at := start + Vector2(side * sin(u * 5.0) * s * 0.6, -u * u * size.y * 0.9 - u * s)
		var open := clampf(u * 6.0, 0.0, 1.0)
		var beat := lerpf(0.2, 0.3 + 0.7 * absf(sin(e * 14.0 + float(k))), open)
		var alpha := clampf((1.0 - u) / 0.25, 0.0, 1.0)
		Cat.butterfly(b, at, s * 0.32 * lerpf(0.4, 1.0, open), beat, cos(u * 5.0) * 0.3 * side, alpha)
	if b.verts.is_empty():
		return
	var m := b.mesh()
	shown.append(m)
	_life_layer.draw_mesh(m, null)

func _draw_combo(now: float, shown: Array) -> void:
	if _combo_n < COMBO_FROM:
		return
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
	var tail := _combo_pos
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.95)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var tip := (tail - centre).round()
	var key := [text, tip]
	if _combo_shown == null or _combo_key != key:
		var b := Face.Builder.new()
		var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
		b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
		b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
		b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
		b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
		_combo_shown = b.mesh()
		_combo_key = key
	shown.append(_combo_shown)
	_life_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_life_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var ascent := font.get_ascent(COMBO_FONT)
	var descent := font.get_descent(COMBO_FONT)
	_life_layer.draw_string(font, Vector2(-tw * 0.5, (ascent - descent) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_life_layer.draw_set_transform(Vector2.ZERO)

## The seal on the bed's lower right corner, dropping in and settling, its
## words over it: Flawless; on Peckish "Insane" over Flawless or Peckish, on
## the night seal.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = _state.peckish()
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var corner := _frame_rect().end
	var centre := corner - Vector2(rad * 0.85, rad * 0.72)
	centre.x = minf(centre.x, size.x - rad * 1.08)
	centre.y = minf(centre.y, size.y - rad * 1.02)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("CP_PECKISH_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
