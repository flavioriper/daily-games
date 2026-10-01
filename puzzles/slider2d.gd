extends "res://core/puzzle_base.gd"

## Super Slider as a flat board: a walnut tray of painted wooden blocks on a
## lawn, after the handheld the user brought (a red big block, blue bars,
## yellow squares, and a green mat at the gate). Drag a block and it follows
## the finger through the empty cells, round corners too, never over another;
## bring the big block down onto the mat in the gate and the doors swing open
## and it walks out. The rules live in puzzles/slider_state.gd, which this
## only draws.
##
## **Nothing wrong can sit in the tray**, so there is no Check, no tray row
## and no actions row: Undo, Reset and Hint ride in the top bar -- Pinwheel's
## shape. A line over the tray keeps the count against the day's shortest.
##
## The polish (2026-10-01, spec 2026-10-01-slider-polish-design.md):
##   - **hard wood**: a block never stretches, squashes or leans; it slides,
##     settles without overshoot, recoils once off a wall and sits down with
##     its shadow (players read the old motion as jelly);
##   - **hearts on Hard and Insane**: on Hard a move that takes the big block
##     farther from the gate costs one (it frets, a sweat drop, while such a
##     move is held, so nothing is a surprise); on Insane, **Homesick**, the
##     big block never steps back up, and a move that leaves it no way home
##     costs one. Either way the block slides back. Out of hearts: dusk and
##     the card, Try again or One more heart;
##   - **rewards**: a streak of moves that bring the big block nearer, gags
##     (love hearts, a butterfly on its head, a twirl), the latch jiggling as
##     it gets one move from home, and the party -- confetti, the nap cat,
##     the seal and a bit of sliding wisdom.
##
## How it is drawn. Two meshes:
##   still -- the lawn, the path out of the gate and the tray, rebuilt only on
##            a relayout;
##   live  -- the mat's glow, the blocks and the gate's doors, rebuilt only
##            while something moves. An idle tray costs nothing.
## Two layers over them: the hearts' pill, and the life (love hearts, the
## butterfly, the streak's bubble, the seal). The blocks are
## ui/faces/slider_block.gd, which the menu card draws too.
##
## Spec: docs/superpowers/specs/2026-09-26-super-slider-flat-design.md.

signal leave

const State = preload("res://puzzles/slider_state.gd")
const Gen = preload("res://puzzles/slider_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Block = preload("res://ui/faces/slider_block.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")

# --- the screen, measured ---
## The card's inset round the tray, the largest cell, the card's corner, the
## band over the tray the count line takes, and how far the path out of the
## gate runs below the frame, in cells.
const INSET := 44.0
const CELL_CAP := 230.0
const CARD_RADIUS := 32.0
const COUNT_BAND := 90.0
const COUNT_FONT := 38
const PATH := 0.9

# --- this board's own motion ---
## A let-go block settles onto its cell over SNAP_TIME, easing in with no
## overshoot; a hint's, an undo's or a slip's block slides its path at
## SLIDE_SPEED cells a second. A block pushed at a wall gives RUBBER of a
## cell and no more.
const SNAP_TIME := 0.13
const SLIDE_SPEED := 7.0
const RUBBER := 0.03
## The win: the big block lands, the mat lights over GLOW_TIME, the doors
## swing open over DOOR_TIME, and the big block walks EXIT cells out of the
## gate over EXIT_TIME while the others hop in a wave from the gate; the win
## screen waits WIN_HOLD past that.
const GLOW_TIME := 0.3
const DOOR_TIME := 0.35
const EXIT := 1.8
const EXIT_TIME := 0.85
const WIN_HOLD := 0.9
## The drawn anchor of a held block chases the finger's at FOLLOW a second,
## so a step glides rather than snaps. A knocked block recoils KNOCK of a
## cell once over KNOCK_TIME (in fast, back slower, never a wobble) and the
## block in its way flinches FLINCH. The big block watches the held one, its
## face moving up to GAZE of a cell, and blinks every BLINK_MIN to BLINK_MAX
## seconds. The hint leaves a trail of dots that fades over TRAIL_FADE. The
## big block walks out in EXIT_STEPS hops.
const FOLLOW := 26.0
const KNOCK := 0.028
const KNOCK_TIME := 0.2
const FLINCH := 0.016
const GAZE := 0.07
const BLINK_MIN := 2.8
const BLINK_MAX := 5.5
const TRAIL_FADE := 0.6
const EXIT_STEPS := 3
## The blocks are set into the tray one by one: each falls ENTER_DROP of a
## cell over ENTER_FALL, its shadow tightening, and lands with a puff.
const ENTER_DROP := 0.45
const ENTER_FALL := 0.2
## The toast: Knight's, measure for measure.
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 66.0

const TIP_CYCLE := 8.0
const TIPS := ["SL_TIP_DRAG", "SL_TIP_GOAL", "SL_TIP_CORNER"]
const TIPS_HEARTS := ["SL_TIP_DRAG", "SL_TIP_FRET", "SL_TIP_HEARTS", "SL_TIP_CORNER"]
const TIPS_HOME := ["SL_TIP_HOME", "SL_TIP_HOME_PLAN", "SL_TIP_HOME_HEARTS", "SL_TIP_CORNER"]

# --- hearts (Knight's, measure for measure) ---
## A move that costs a heart lands, holds SLIP_HOLD with the big block upset,
## and slides back.
const SLIP_HOLD := 0.45
const HEART_ROW := 66.0
const HEART_TOP := 4.0
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
const CARD_AFTER := 0.9
const CARD_AFTER_STILL := 0.3
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const AGO := -1.0e9
## A refused upward step on Homesick: the big block shakes its head, rigid,
## SHAKE of a cell over SHAKE_TIME.
const SHAKE := 0.04
const SHAKE_TIME := 0.32

# --- the rewards ---
## The streak: kept moves that bring the big block nearer the gate. A note up
## the pentatonic from the second, the bubble from the third, confetti at 4,
## 7 and every 5.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_DEFLATE := 0.25
const COMBO_FONT := 44
## A gag on one nearer move in GAG_ODDS, off the day's hash.
enum Gag { NONE = -1, TWIRL, LOVE, BUTTERFLY }
const GAG_SPAN := 9
const GAG_ODDS := 3
const GAG_STEP := 5
const LOVE_HEARTS := 3
const LOVE_TIME := 1.2
const LOVE_RISE := 0.9
const LOVE_R := 0.13
const FLY_IN := 0.7
const FLY_SIT := 1.1
const FLY_OUT := 0.7
## The twirl: the big block hops and turns once round, rigid, over
## TWIRL_TIME.
const TWIRL_TIME := 0.55
const TWIRL_HOP := 0.16
## One move from home the gate's doors rattle on their latch.
const LATCH_TIME := 0.6
const LATCH := 0.07
## The party, after the big block has walked out.
const PARTY_AT := 0.2
const PARTY_TIME := 2.6
const CHEERS := 12
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
const SWEAT := Color("a9dcf5")

var _state = State.new()
var fx: Node2D

## How each block is travelling: {"pts" (anchors in cells, float), "at",
## "dur", "land" (sits down as it arrives)}.
var _disp: Array = []
## A drag: {"p", "grab" (finger less anchor, cells), "before", "key", "at",
## "v" (the anchor as drawn), "want", "bumped", "huffed"}; empty when none.
var _drag := {}
var _rings: Array = []
## Knocks, flinches and head shakes: {"p", "at", "dir" (unit, cells), "amp",
## "shake"}.
var _knocks: Array = []
## The hint's trail: {"pts" (centres, cells), "at", "dur"}; empty when none.
var _trail := {}
## Where the big block's face is looking (fraction of a cell), eased.
var _gaze := Vector2.ZERO
var _blink_at := 0.0
var _last_dust := 0.0
var _opened := 0.0
var _anim_until := 0.0
## When the big block stood on the mat, and the gate starts to open.
var _solved_at := -1.0
var _still: ArrayMesh
var _live: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _toast := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
## Bumped by every deal, Try again and restore: a delayed callback from
## before it does nothing.
var _gen := 0

# --- hearts ---
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
## A costly move is still playing out until then: input and the HUD wait.
var _busy_until := -100.0
var _was_busy := false
## Hard's peek: the held move would take the big block farther from home.
var _fret := false
## The big block is upset (a costly move landed) until then.
var _upset_until := -100.0

# --- the rewards ---
## A harness sets it to force (or, with Gag.NONE, forbid) the next gag.
var force_gag := -2
var _streak := 0
var _streak_gen := 0
var _nearer := 0
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
var _love: Array = []       # [{"t", "phase", "k"}] off the big block's head
var _flies: Array = []      # [{"t", "from"}] a butterfly visiting the big block
var _twirl_at := AGO
var _latch_at := AGO
var _halfway := false
var _love_mesh: ArrayMesh
var _seal_mesh: ArrayMesh
var _party_at := INF
var _stamp_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false

func puzzle_id() -> String: return "slider"
func title() -> String: return "Super Slider"

## The rules, then the band's own closing: nothing can be lost (Easy,
## Medium), hearts (Hard), or Homesick (Insane).
func rules() -> String:
	var out := tr("SL_RULES")
	if _state.homesick:
		out += "\n\n" + tr("SL_RULES_HOME") % max_hearts
	elif max_hearts > 0:
		out += "\n\n" + tr("SL_RULES_HEARTS") % max_hearts
	return out

func _tips() -> Array:
	if _state.homesick:
		return TIPS_HOME
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

## Undo and Hint; Reset is the host's. No Check: nothing wrong can sit here.
## Insane has neither undo nor hint: can_undo() says so, and no hint button.
func capabilities() -> Array[String]:
	if _state.difficulty >= 3:
		return ["undo"]
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
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

func _exit_tree() -> void:
	_state.abandon()
	_close_card()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_close_card()
	_state.build(rng, difficulty, bank_step)
	max_hearts = State.hearts_for(difficulty)
	_heart_used = false
	_lost_ever = false
	_undo_ever = false
	_flawless = false
	_deal()
	_reset_rewards()
	_opened = _now()
	_blink_at = _opened + 2.0
	_layout()
	fx.cue("enter")
	if not Motion.reduce:
		for p in _state.blocks.size():
			var pp: int = p
			_after(_entry_time(p) - _opened + ENTER_FALL, func(): fx.puff(_foot(pp), Pal.SURFACE, 2))
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## The tray as it is dealt, and as Try again deals it back: every heart,
## every block still, nothing moving.
func _deal() -> void:
	_gen += 1
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_split_at = AGO
	_back_index = -1
	_back_at = AGO
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	_disp = []
	for p in _state.blocks.size():
		_disp.append(_still_at(p))
	_drag = {}
	_rings = []
	_knocks = []
	_trail = {}
	_gaze = Vector2.ZERO
	_toast = ""
	_toast_at = -100.0
	_anim_until = 0.0
	_busy_until = -100.0
	_upset_until = -100.0
	_fret = false
	_solved_at = -1.0
	_halfway = false
	if _heart_layer != null:
		_heart_layer.queue_redraw()

func _still_at(p: int) -> Dictionary:
	return {"pts": PackedVector2Array([_xy(_state.at(p))]), "at": -100.0, "dur": 0.0, "land": false}

# --- layout ---

## The band over the tray: the count line, and the hearts' pill over it on
## Hard and Insane.
func _top_band() -> float:
	return COUNT_BAND + (HEART_ROW if max_hearts > 0 else 0.0)

func _cell() -> float:
	var w := float(Gen.COLS) + 2.0 * Block.FRAME
	var h := float(Gen.ROWS) + 2.0 * Block.FRAME + PATH
	return maxf(0.0, minf(CELL_CAP, minf((size.x - 2.0 * INSET) / w, (size.y - 2.0 * INSET - _top_band()) / h)))

func _grid_size() -> Vector2:
	return Vector2(Gen.COLS, Gen.ROWS) * _cell()

## The floor's top-left: the tray, its frame and the path below it centred
## in the room under the count line.
func _origin() -> Vector2:
	var s := _cell()
	var tall := (float(Gen.ROWS) + 2.0 * Block.FRAME + PATH) * s
	var top := _top_band() + (size.y - _top_band() - tall) * 0.5
	return Vector2((size.x - _grid_size().x) * 0.5, top + Block.FRAME * s)

## A cell index as its column and row.
static func _xy(c: int) -> Vector2:
	return Vector2(c % Gen.COLS, c / Gen.COLS)

func _pt(v: Vector2) -> Vector2:
	return _origin() + v * _cell()

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _pt(Vector2(c, r) + Vector2(0.5, 0.5))

func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_love_mesh = null
	_refresh()
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	if _life_layer != null:
		_life_layer.queue_redraw()

## Block `p`'s foot: the middle of its bottom edge where it stands.
func _foot(p: int) -> Vector2:
	return _pt(_xy(_state.at(p)) + Vector2(_state.size_of(p)) * Vector2(0.5, 1.0)) - Vector2(0.0, _cell() * 0.08)

# --- where a block is drawn ---

## Block `p`'s anchor as drawn at `t`, in cells: the finger's while dragged,
## else along its travel.
func _vis(p: int, t: float) -> Vector2:
	if not _drag.is_empty() and int(_drag.p) == p:
		return _drag.v
	var d: Dictionary = _disp[p]
	var pts: PackedVector2Array = d.pts
	var home := _xy(_state.at(p))
	var dur: float = d.dur
	if Motion.reduce or pts.size() < 2 or dur <= 0.0:
		return home
	var u := (t - float(d.at)) / dur
	if u >= 1.0:
		return pts[pts.size() - 1]
	if u <= 0.0:
		return pts[0]
	# a short settle eases onto its cell and stops dead, the way wood does;
	# a path eases along its length
	var e := 1.0 - pow(1.0 - u, 3.0) if pts.size() == 2 else u * u * (3.0 - 2.0 * u)
	return _along(pts, e)

static func _along(pts: PackedVector2Array, e: float) -> Vector2:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	if total <= 0.0:
		return pts[pts.size() - 1]
	var want := total * e
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if want <= seg or i == pts.size() - 1:
			return pts[i - 1].lerp(pts[i], want / maxf(seg, 1e-6))
		want -= seg
	return pts[pts.size() - 1]

## A block's lift off the floor: up as a finger takes it, down as it lands,
## and up as it falls into the tray on the entrance.
func _lift(p: int, t: float) -> float:
	if not _drag.is_empty() and int(_drag.p) == p:
		return 1.0 if Motion.reduce else clampf((t - float(_drag.at)) / Motion.LIFT_TIME, 0.0, 1.0)
	if Motion.reduce:
		return 0.0
	var fall := _entry_drop(p, t)
	if fall > 0.0:
		return fall / ENTER_DROP
	var d: Dictionary = _disp[p]
	if not d.land:
		return 0.0
	return 1.0 - clampf((t - float(d.at)) / maxf(float(d.dur), 1e-3), 0.0, 1.0)

func _entry_time(i: int) -> float:
	return _opened + Motion.ENTER_DELAY + 0.15 + Motion.stagger(i, 0.05)

## How far block `i` still has to fall into the tray as it enters, in cells;
## -1 before it is shown. It accelerates as it falls and lands without a
## bounce.
func _entry_drop(i: int, t: float) -> float:
	if Motion.reduce:
		return 0.0
	var e := t - _entry_time(i)
	if e < 0.0:
		return -1.0
	var u := clampf(e / ENTER_FALL, 0.0, 1.0)
	return ENTER_DROP * (1.0 - u * u)

## The big block's eyes: shut for a blink, else open.
func _eye(t: float) -> float:
	if Motion.reduce or _solved_at >= 0.0:
		return 1.0
	var e := t - _blink_at
	if e < 0.0 or e > Face.BLINK_TIME:
		return 1.0
	return absf(cos(PI * e / Face.BLINK_TIME))

## A knock's, a flinch's or a head shake's offset on block `p`, in cells. A
## knock is one recoil: in fast against what it hit, then eased back.
func _knock(p: int, t: float) -> Vector2:
	if Motion.reduce:
		return Vector2.ZERO
	var off := Vector2.ZERO
	for k: Dictionary in _knocks:
		if int(k.p) != p:
			continue
		var e := t - float(k.at)
		if k.get("shake", false):
			if e >= 0.0 and e < SHAKE_TIME:
				var u := e / SHAKE_TIME
				off.x += float(k.amp) * sin(TAU * 2.0 * u) * (1.0 - u)
			continue
		if e < 0.0 or e >= KNOCK_TIME:
			continue
		var u := e / KNOCK_TIME
		var hump := u / 0.2 if u < 0.2 else pow(1.0 - (u - 0.2) / 0.8, 2.0)
		off += Vector2(k.dir) * float(k.amp) * hump
	return off

# --- the win's clock ---

func _glow(t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	if Motion.reduce:
		return 1.0
	return clampf((t - _solved_at) / GLOW_TIME, 0.0, 1.0)

func _door(t: float) -> float:
	if _solved_at < 0.0:
		var e := t - _latch_at
		if Motion.reduce or e < 0.0 or e >= LATCH_TIME:
			return 0.0
		# one move from home: the doors rattle on their latch
		var u := e / LATCH_TIME
		return LATCH * absf(sin(TAU * 2.5 * u)) * (1.0 - u)
	if Motion.reduce:
		return 1.0
	return Motion.back_out(clampf((t - _solved_at - GLOW_TIME) / DOOR_TIME, 0.0, 1.0))

## How far the big block has walked out of the gate, in cells.
func _exit(t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	if Motion.reduce:
		return EXIT
	var u := clampf((t - _solved_at - GLOW_TIME - DOOR_TIME * 0.6) / EXIT_TIME, 0.0, 1.0)
	# EXIT_STEPS hops: each one eases its own share of the way
	var n := float(EXIT_STEPS)
	var k := minf(floorf(u * n), n - 1.0)
	var f := u * n - k
	return EXIT * (k + f * f * (3.0 - 2.0 * f)) / n

## The big block's hop as it walks out: up and down once a step, in cells.
func _exit_hop(t: float) -> float:
	if _solved_at < 0.0 or Motion.reduce:
		return 0.0
	var u := (t - _solved_at - GLOW_TIME - DOOR_TIME * 0.6) / EXIT_TIME
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return 0.22 * sin(PI * fmod(u * float(EXIT_STEPS), 1.0))

## The others' hop as the big block leaves: a wave out from the gate.
func _cheer(p: int, t: float) -> float:
	if _solved_at < 0.0 or Motion.reduce:
		return 0.0
	var c := _xy(_state.at(p)) + Vector2(_state.size_of(p)) * 0.5
	var far := c.distance_to(_xy(Gen.GOAL) + Vector2.ONE)
	var e := t - _solved_at - GLOW_TIME - DOOR_TIME - far * 0.08
	return Motion.hop_lift(e, Motion.SOLVE_HOP, Motion.SOLVE_TIME) * 0.012

## The twirl's turn and hop at `t`: [angle, cells up].
func _twirl(t: float) -> Array:
	var e := t - _twirl_at
	if Motion.reduce or e < 0.0 or e >= TWIRL_TIME:
		return [0.0, 0.0]
	var u := e / TWIRL_TIME
	return [TAU * u * u * (3.0 - 2.0 * u), TWIRL_HOP * sin(PI * u)]

# --- the frame loop ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.blocks.is_empty():
		return
	var t := _now()
	# A costly move lets go of the HUD as it ends: it greyed Undo and Hint.
	var bz := busy()
	if _was_busy and not bz:
		moved.emit()
	_was_busy = bz
	if _tick_life(t):
		_life_layer.queue_redraw()
	if t >= _cat_at and not _cat_curled:
		_place_cat(t)
	if max_hearts > 0 and (t - _split_at < SPLIT_TIME + 0.1 or t - _back_at < HEART_BACK_TIME + 0.1 \
			or t - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1):
		_heart_layer.queue_redraw()
	_ease_gaze(t, delta)
	if not Motion.reduce and _solved_at < 0.0 and t > _blink_at + Face.BLINK_TIME:
		_blink_at = t + randf_range(BLINK_MIN, BLINK_MAX)
	if not _drag.is_empty():
		_chase(delta)
	if _animating(t) or _blinking(t):
		_refresh()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		# the toast is drawn apart from the meshes: a redraw, not a rebuild
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _animating(t: float) -> bool:
	if t < _anim_until or not _drag.is_empty():
		return true
	if Motion.reduce:
		return false
	if not _flies.is_empty():
		return true
	var entrance := _entry_time(_state.blocks.size()) - _opened + ENTER_FALL + 0.1
	return t - _opened < entrance

func _blinking(t: float) -> bool:
	return not Motion.reduce and t >= _blink_at and t <= _blink_at + Face.BLINK_TIME + 0.05

## Where the big block wants to look: at the held block, else at the gate
## when it stands over the mat, else ahead. Eased toward it; while it is still
## turning its eyes the tray keeps drawing.
func _ease_gaze(t: float, delta: float) -> void:
	var want := Vector2.ZERO
	var big: int = _state.big()
	if big < 0:
		return
	var me := _xy(_state.at(big)) + Vector2.ONE
	if not _drag.is_empty() and int(_drag.p) != big:
		var p: int = _drag.p
		var there: Vector2 = Vector2(_drag.v) + Vector2(_state.size_of(p)) * 0.5
		want = (there - me).limit_length(1.0) * GAZE
	elif _solved_at >= 0.0:
		want = Vector2(0.0, GAZE)
	if Motion.reduce:
		_gaze = want
		return
	var was := _gaze
	_gaze = _gaze.lerp(want, 1.0 - exp(-delta * 10.0))
	if _gaze.distance_to(was) > 0.0005:
		_busy_for(0.05)

## The drawn anchor of the held block chases the finger's, so a step between
## cells glides. It moves whole: nothing about it bends with its speed.
func _chase(delta: float) -> void:
	var want: Vector2 = _drag.want
	var was: Vector2 = _drag.v
	var v := want if Motion.reduce else was.lerp(want, 1.0 - exp(-delta * FOLLOW))
	if v.distance_to(want) < 0.002:
		v = want
	_drag.v = v

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _refresh() -> void:
	_live = null
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.blocks.is_empty() or _cell() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := 1.0 if Motion.reduce else Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := 1.0 if Motion.reduce else Motion.wide_pop_scale(since)
	var mid := size * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	if _still == null:
		_still = _build_still()
	if _live == null:
		_live = _build_live(t)
	var shown: Array = []
	for m in [_still, _live]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_count(seen)
	_draw_toast(t, shown)
	_shown = shown

## The lawn round the tray, a few tufts, the stepping stones out of the gate,
## and the tray itself. None of it ever moves.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	b.fan(Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0), Pal.SLIDE_LAWN)
	# mown stripes, very faint
	var stripe := s * 0.9
	var k := 0
	var x0 := 2.0
	while x0 < size.x - 2.0:
		if k % 2 == 0:
			b.fan(PackedVector2Array([Vector2(x0, 12.0), Vector2(minf(x0 + stripe, size.x - 2.0), 12.0),
				Vector2(minf(x0 + stripe, size.x - 2.0), size.y - 12.0), Vector2(x0, size.y - 12.0)]), Color(1.0, 1.0, 1.0, 0.07))
		x0 += stripe
		k += 1
	var inside := Rect2(o - Vector2.ONE * s * 0.45, g + Vector2(s * 0.9, s * (0.45 + PATH + 0.45)))
	var gx := o.x + s * float(Gen.GOAL % Gen.COLS)
	var path := Rect2(Vector2(gx - s * 0.3, o.y + g.y), Vector2(s * 2.6, size.y))
	var pill := Rect2(Vector2(size.x * 0.5 - 120.0, 0.0), Vector2(240.0, _top_band()))
	# bushes tucked into the card's corners, clipped by its edge
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := Vector2(corner.x * size.x, corner.y * size.y) + (Vector2.ONE - corner * 2.0) * s * 0.42
		_bush(b, at, s * 0.3, int(corner.x + corner.y * 2.0))
	# clover and tufts, and daisies here and there, off the tray and the path
	for i in 120:
		var at := Vector2(_hash(i, 3) * size.x, 14.0 + _hash(i, 11) * (size.y - 28.0))
		if inside.has_point(at) or path.has_point(at) or pill.has_point(at):
			continue
		match i % 4:
			0, 1:
				_tuft(b, at, s * (0.13 + 0.08 * _hash(i, 17)))
			2:
				_clover(b, at, s * (0.07 + 0.03 * _hash(i, 19)), _hash(i, 23) * TAU)
			3:
				_daisy(b, at, s * (0.06 + 0.02 * _hash(i, 29)))
	# the path out of the gate: flat stones down to the card's hem, a tuft
	# beside every other one
	var y := o.y + g.y + Block.FRAME * s + s * 0.18
	var n := 0
	while y < size.y + s * 0.3 and n < 7:
		var w := s * (1.3 - 0.06 * float(n))
		var c := Vector2(gx + s + (s * 0.12 if n % 2 == 0 else -s * 0.12), y + s * 0.2)
		b.ellipse(c + Vector2(0.0, s * 0.05), w * 0.52, s * 0.21, Pal.SLIDE_LAWN_DEEP)
		b.ellipse(c, w * 0.5, s * 0.18, Pal.SLIDE_STONE)
		b.ellipse(c + Vector2(-w * 0.08, -s * 0.05), w * 0.3, s * 0.07, Pal.SLIDE_STONE_HI)
		if n % 2 == 1:
			_tuft(b, c + Vector2(w * 0.62, s * 0.12), s * 0.14)
		else:
			_tuft(b, c + Vector2(-w * 0.62, s * 0.12), s * 0.12)
		y += s * 0.5
		n += 1
	Block.tray(b, o, s)
	return b.mesh()

static func _tuft(b: Face.Builder, at: Vector2, h: float) -> void:
	for k in 3:
		var ang := -PI * 0.5 + (float(k) - 1.0) * 0.45
		var tip := at + Vector2(cos(ang), sin(ang)) * h
		b.fan(PackedVector2Array([at + Vector2(-h * 0.12, 0.0), tip, at + Vector2(h * 0.12, 0.0)]), Pal.SLIDE_LAWN_DEEP)

## A round bush of three lobes in two greens, a few leaves lit on top.
static func _bush(b: Face.Builder, at: Vector2, r: float, k: int) -> void:
	var lobes := [Vector2(-0.7, 0.15), Vector2(0.7, 0.2), Vector2(0.0, -0.25)]
	for l: Vector2 in lobes:
		b.disc(at + l * r + Vector2(0.0, r * 0.12), r * 0.75, Pal.SLIDE_BUSH_DEEP)
	for l: Vector2 in lobes:
		b.disc(at + l * r, r * 0.7, Pal.SLIDE_BUSH)
	for i in 4:
		var a := -PI * 0.5 + (_hash(k, i) - 0.5) * 2.4
		b.ellipse(at + Vector2(cos(a), sin(a)) * r * 0.75, r * 0.14, r * 0.08, Pal.SLIDE_BUSH_HI)

## A three-leaf clover at `at`, leaves `r` across, turned `turn`.
static func _clover(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	for k in 3:
		var a := turn + TAU * float(k) / 3.0
		b.disc(at + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.55, Pal.SLIDE_CLOVER)
	b.disc(at, r * 0.18, Pal.SLIDE_LAWN_DEEP)

## A small daisy: five white petals and a yellow eye.
static func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	for k in 5:
		var a := TAU * float(k) / 5.0
		b.ellipse(at + Vector2(cos(a), sin(a)) * r * 0.6, r * 0.42, r * 0.42, Pal.PAPER)
	b.disc(at, r * 0.36, Pal.SLIDE_SQ)

static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / float(0x7fffffff)

## The mat's glow, a hint's ring, Homesick's line, every block where it is
## drawn (the held one last, over the rest), and the gate's doors.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var glow := _glow(t)
	if glow > 0.0:
		Block.mat(b, o, s, glow)
	for c in Gen.N:
		if _state.block_at(c) < 0:
			Block.hollow(b, _pt(_xy(c)), s)
	_draw_home_line(b, t)
	_draw_trail(b, t)
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			var rad := s * (0.5 + 0.5 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), s * 0.06 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	var order: Array = range(_state.blocks.size())
	var held: int = int(_drag.p) if not _drag.is_empty() else -1
	var big: int = _state.big()
	# the big block walks out over the frame, so it is drawn after the doors
	order.sort_custom(func(a, z): return _rank(a, held, big) < _rank(z, held, big))
	var doors_drawn := false
	for p: int in order:
		if p == big and _solved_at >= 0.0 and not doors_drawn:
			Block.doors(b, o, s, _door(t))
			doors_drawn = true
		_block(b, p, t)
	if not doors_drawn:
		Block.doors(b, o, s, _door(t))
	return b.mesh() if not b.verts.is_empty() else null

## Homesick's line: a row of brass dots across the floor at the big block's
## top edge, and a brass notch on each side of the frame -- the line it
## never goes back over. It only ever moves down.
func _draw_home_line(b: Face.Builder, t: float) -> void:
	if not _state.homesick or _solved_at >= 0.0:
		return
	var big: int = _state.big()
	if big < 0:
		return
	var s := _cell()
	var o := _origin()
	var y := o.y + _vis(big, t).y * s
	var dots := 16
	for i in dots:
		var x := o.x + s * 0.12 + (float(Gen.COLS) * s - s * 0.24) * float(i) / float(dots - 1)
		b.disc(Vector2(x, y), s * 0.022, Color(Pal.SLIDE_BRASS, 0.55))
	var f := Block.FRAME * s
	for side in [-1.0, 1.0]:
		var edge: float = o.x - f * 0.5 if side < 0.0 else o.x + float(Gen.COLS) * s + f * 0.5
		var tip := Vector2(edge - side * f * 0.38, y)
		var back := Vector2(edge + side * f * 0.3, y)
		b.fan(PackedVector2Array([tip, back + Vector2(0.0, -f * 0.42), back + Vector2(0.0, f * 0.42)]), Pal.SLIDE_BRASS)
		b.disc(back, f * 0.12, Pal.SLIDE_BRASS_HI)

## The hint's trail: a dotted line down the way the block goes, drawn ahead
## of it as it slides and fading once it has landed.
func _draw_trail(b: Face.Builder, t: float) -> void:
	if _trail.is_empty() or Motion.reduce:
		return
	var e := t - float(_trail.at)
	var dur: float = _trail.dur
	var fade := 1.0 - clampf((e - dur) / TRAIL_FADE, 0.0, 1.0)
	if e < 0.0 or fade <= 0.0:
		if e >= dur + TRAIL_FADE:
			_trail = {}
		return
	var pts: PackedVector2Array = _trail.pts
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var s := _cell()
	var n := int(total / 0.22)
	for k in range(1, n):
		var u := float(k) / float(n)
		var at := _pt(_along(pts, u))
		# dots pop in down the way, a beat ahead of the block
		var shown := clampf((e / maxf(dur, 1e-3) + 0.25 - u) * 5.0, 0.0, 1.0)
		if shown <= 0.0:
			continue
		b.disc(at, s * 0.045 * shown, Color(Pal.SUN, 0.8 * fade))

static func _rank(p: int, held: int, big: int) -> int:
	if p == held:
		return 2
	if p == big:
		return 1
	return 0

func _block(b: Face.Builder, p: int, t: float) -> void:
	var fall := _entry_drop(p, t)
	if fall < 0.0:
		return
	var s := _cell()
	var cells := _state.size_of(p)
	var v := _vis(p, t)
	var lift := _lift(p, t)
	var expr := Face.Expr.HAPPY
	var look := Vector2.ZERO
	var eye := 1.0
	var turn := 0.0
	var is_big := p == _state.big()
	if is_big:
		v.y += _exit(t)
		look = _gaze
		eye = _eye(t)
		if _solved_at >= 0.0:
			expr = Face.Expr.JOY
			var hop := _exit_hop(t)
			v.y -= hop
			lift = maxf(lift, hop * 3.0)
		elif out_of_hearts:
			expr = Face.Expr.SLEEPY
		elif t < _upset_until or _fret:
			expr = Face.Expr.WORRIED
		elif _knocked(p, t):
			expr = Face.Expr.STRAIN
		else:
			var tw := _twirl(t)
			turn = float(tw[0])
			v.y -= float(tw[1])
			lift = maxf(lift, float(tw[1]) * 4.0)
			if turn > 0.0:
				expr = Face.Expr.JOY
	else:
		v.y += _cheer(p, t)
	v += _knock(p, t)
	v.y -= fall
	var at := _pt(v)
	var from := b.verts.size()
	Block.block(b, at, cells, s, _state.kind(p), lift, expr, look, eye)
	if turn > 0.0:
		# the twirl turns the whole block, rigid, round its middle
		var mid := at + Vector2(cells) * s * 0.5
		for i in range(from, b.verts.size()):
			b.verts[i] = mid + (b.verts[i] - mid).rotated(turn)
	if is_big and _fret and not out_of_hearts:
		_sweat(b, at + Vector2(cells.x * s * 0.86, s * 0.28), s)

## A sweat drop by the big block's brow: Hard's peek at a move that would
## take it farther from the gate.
static func _sweat(b: Face.Builder, at: Vector2, s: float) -> void:
	var r := s * 0.07
	b.disc(at, r, SWEAT)
	b.fan(PackedVector2Array([at + Vector2(-r * 0.9, -r * 0.3), at + Vector2(0.0, -r * 2.4), at + Vector2(r * 0.9, -r * 0.3)]), SWEAT)
	b.disc(at + Vector2(-r * 0.3, -r * 0.2), r * 0.3, Color(1.0, 1.0, 1.0, 0.8))

func _knocked(p: int, t: float) -> bool:
	for k: Dictionary in _knocks:
		if int(k.p) == p and t - float(k.at) < KNOCK_TIME * 2.0:
			return true
	return false

## The count over the tray: moves so far against the day's shortest.
func _draw_count(alpha: float) -> void:
	var font: Font = CozyTheme.body(700)
	var text: String = tr("SL_COUNT_ONE") % _state.par if moves == 1 else tr("SL_COUNT") % [moves, _state.par]
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT).x
	var band_top := _top_band() - COUNT_BAND
	var top := _origin().y - Block.FRAME * _cell()
	var y := band_top + minf(COUNT_BAND, top - band_top) * 0.5 + font.get_ascent(COUNT_FONT) * 0.5 + 8.0
	draw_string(font, Vector2((size.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT,
		Color(Pal.TEXT, 0.75 * alpha))

## The count line's middle, for the halfway sparkle.
func _count_at() -> Vector2:
	var band_top := _top_band() - COUNT_BAND
	var top := _origin().y - Block.FRAME * _cell()
	return Vector2(size.x * 0.5, band_top + minf(COUNT_BAND, top - band_top) * 0.5 + 8.0)

## The toast over the foot of the card -- Knight's `_draw_toast`.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var line := tr(_toast)
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		var lh := font.get_height(TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / lh)))
		text_w = minf(text_room, wrapped.x)
	var w := minf(room, text_w + TOAST_PAD)
	var h := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [line, int(w), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -h) * 0.5, Vector2(w, h), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = key
	if _toast_mesh == null:
		return
	var mid := Vector2(size.x * 0.5, size.y - TOAST_MARGIN - h * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if not busy():
				_press(event.position)
		else:
			_release()
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _drag.is_empty():
		_move(event.position)
		accept_event()

## A local point in cells (a cell's top-left is its column and row).
func _to_cells(local: Vector2) -> Vector2:
	return (local - _origin()) / maxf(_cell(), 1e-3)

func _press(local: Vector2) -> void:
	var v := _to_cells(local)
	if v.x < 0.0 or v.y < 0.0 or v.x >= Gen.COLS or v.y >= Gen.ROWS:
		return
	var p: int = _state.block_at(int(v.y) * Gen.COLS + int(v.x))
	if p < 0:
		return
	var t := _now()
	var a := _xy(_state.at(p))
	_drag = {"p": p, "grab": v - a, "before": _state.snapshot(), "key": _state.key, "at": t, "v": a, "want": a,
		"bumped": {}, "huffed": false}
	fx.cue("lift")
	_refresh()

## The block under the finger steps a cell at a time toward where the finger
## would carry it, the longer way first, and round a corner when that way is
## shut; what is left over is drawn as an offset, half a cell toward an open
## way and RUBBER toward a shut one.
func _move(local: Vector2) -> void:
	var p: int = _drag.p
	var target := _to_cells(local) - Vector2(_drag.grab)
	for i in 12:
		var a := _xy(_state.at(p))
		var d := target - a
		var axes: Array = [0, 1] if absf(d.x) >= absf(d.y) else [1, 0]
		var stepped := false
		for axis: int in axes:
			var comp: float = d.x if axis == 0 else d.y
			if absf(comp) < 0.5:
				continue
			var dx := int(signf(comp)) if axis == 0 else 0
			var dy := int(signf(comp)) if axis == 1 else 0
			if _state.step(p, dx, dy):
				fx.cue("step", 1.0 + 0.04 * float(randi() % 3))
				_dust(p, Vector2(dx, dy))
				stepped = true
				break
			if not _state.may_step(p, dy):
				_huff(p)
			else:
				_bump(p, dx, dy)
		if not stepped:
			break
	var a := _xy(_state.at(p))
	var d := target - a
	var off := Vector2(_give(p, d.x, 1, 0), _give(p, d.y, 0, 1))
	if absf(off.x) >= absf(off.y):
		off.y = 0.0
	else:
		off.x = 0.0
	_drag.want = a + off
	if Motion.reduce:
		_drag.v = _drag.want
	_peek()
	_refresh()

## Hard's peek: while the held move would take the big block farther from
## the gate, it frets. Never on Homesick (where a dead end is the player's
## to see) and never before the solver is done.
func _peek() -> void:
	var was := _fret
	_fret = false
	if max_hearts > 0 and not _state.homesick and not _drag.is_empty():
		var d0: int = _state.dist_of(int(_drag.key))
		var d1: int = _state.dist_of(_state.key)
		_fret = d0 >= 0 and d1 > d0
	if _fret and not was:
		fx.cue("fret")

## How far a block drawn under the finger may lean off its cell along one
## axis: toward an open cell up to half of one, toward a shut one RUBBER.
func _give(p: int, comp: float, ux: int, uy: int) -> float:
	if absf(comp) < 1e-4:
		return 0.0
	var dir := int(signf(comp))
	var open := _can_step(p, ux * dir, uy * dir)
	var lim := 0.5 if open else RUBBER
	if not _state.may_step(p, uy * dir):
		lim = 0.0
	return clampf(comp, -lim, lim)

func _can_step(p: int, dx: int, dy: int) -> bool:
	if _state.step(p, dx, dy):
		_state.step(p, -dx, -dy)
		return true
	return false

## A block pushed into a wall or another block knocks once, the first time
## the finger drags it half a cell that way from a cell.
func _bump(p: int, dx: int, dy: int) -> void:
	var key := "%d|%d|%d" % [_state.at(p), dx, dy]
	if _drag.bumped.has(key):
		return
	_drag.bumped[key] = true
	fx.cue("bump")
	var t := _now()
	var dir := Vector2(dx, dy)
	_knocks.append({"p": p, "at": t, "dir": dir, "amp": KNOCK})
	# whatever stands just past the leading edge flinches away from the knock,
	# one cell per row or column the block spans
	var here := _xy(_state.at(p))
	var sz := Vector2(_state.size_of(p))
	var edge := here + (Vector2(sz.x, 0.0) if dx > 0 else Vector2(0.0, sz.y) if dy > 0 else dir)
	var along := Vector2(0.0, 1.0) if dx != 0 else Vector2(1.0, 0.0)
	var hit := {}
	for i in int(sz.y if dx != 0 else sz.x):
		var ahead := edge + along * float(i)
		if ahead.x < 0 or ahead.y < 0 or ahead.x >= Gen.COLS or ahead.y >= Gen.ROWS:
			continue
		var q: int = _state.block_at(int(ahead.y) * Gen.COLS + int(ahead.x))
		if q >= 0 and q != p and not hit.has(q):
			hit[q] = true
			_knocks.append({"p": q, "at": t + 0.03, "dir": dir, "amp": FLINCH})
	_drop_knocks(t)
	_busy_for(KNOCK_TIME * 2.0 + 0.05)

## Homesick: the big block dragged upward shakes its head (once a drag) and
## says why.
func _huff(p: int) -> void:
	if _drag.huffed:
		return
	_drag.huffed = true
	var t := _now()
	_knocks.append({"p": p, "at": t, "dir": Vector2.RIGHT, "amp": SHAKE, "shake": true})
	fx.cue("huff")
	_tell("SL_HOME_UP", Face.Expr.STRAIN)
	_busy_for(SHAKE_TIME + 0.05)

func _drop_knocks(t: float) -> void:
	var keep: Array = []
	for k: Dictionary in _knocks:
		if t - float(k.at) < maxf(KNOCK_TIME, SHAKE_TIME) * 2.0:
			keep.append(k)
	_knocks = keep

## A wisp of dust off the trailing edge of block `p` as it steps `dir`.
func _dust(p: int, dir: Vector2) -> void:
	if Motion.reduce:
		return
	var t := _now()
	if t - _last_dust < 0.07:
		return
	_last_dust = t
	var sz := Vector2(_state.size_of(p))
	var mid := _xy(_state.at(p)) + sz * 0.5
	var back := mid - dir * (sz * 0.5 + Vector2.ONE * 0.1)
	fx.puff(_pt(back), Pal.SLIDE_GROOVE, 3)

func _release() -> void:
	if _drag.is_empty():
		return
	var t := _now()
	var p: int = _drag.p
	var from: Vector2 = _drag.v
	var before: Array = _drag.before
	var before_key: int = _drag.key
	_drag = {}
	_fret = false
	_disp[p] = {"pts": PackedVector2Array([from, _xy(_state.at(p))]), "at": t, "dur": SNAP_TIME, "land": true}
	_busy_for(SNAP_TIME + 0.1)
	if State._same(before, _state.blocks):
		fx.cue("drop")
		_refresh()
		return
	# Homesick judges every move, so the first one waits for the solver if it
	# has to (it only can in the first second or two)
	if _state.homesick and max_hearts > 0:
		_state.finish()
	var d0: int = _state.dist_of(before_key)
	var d1: int = _state.dist_of(_state.key)
	var why := _verdict(d0, d1)
	if why != "":
		_cost(p, before, why)
		_refresh()
		return
	_state.commit(before)
	_land_puff(p, SNAP_TIME)
	fx.cue("slide")
	if d0 >= 0 and d1 >= 0:
		if d1 < d0:
			_on_nearer(p, t + SNAP_TIME, d1)
		elif d1 > d0:
			_break_streak()
	_refresh()
	note_move()

## What a kept move would cost, as the toast's key; "" when nothing. Hard: a
## move that takes the big block farther from the gate. Homesick: a move
## after which it can never get home. Unjudged while the solver runs.
func _verdict(d0: int, d1: int) -> String:
	if max_hearts <= 0 or out_of_hearts:
		return ""
	if _state.homesick:
		return "SL_DOOMED" if d1 == -1 else ""
	return "SL_SETBACK" if d0 >= 0 and d1 > d0 else ""

## A move that costs a heart: it lands, the big block is upset, a heart
## splits, and after SLIP_HOLD the block slides back the way it came.
func _cost(p: int, before: Array, why: String) -> void:
	var t := _now()
	var land := t + SNAP_TIME
	var back: PackedInt32Array = _state.path(p, int(before[p][1]), true)
	var pts := PackedVector2Array()
	for c in back:
		pts.append(_xy(c))
	if pts.size() < 2:
		pts = PackedVector2Array([_xy(_state.at(p)), _xy(int(before[p][1]))])
	var dur := _travel(pts)
	_lose_heart(land)
	_break_streak()
	_clear_gags()
	_upset_until = land + SLIP_HOLD + dur
	_busy_until = land + SLIP_HOLD + dur + 0.05
	_busy_for(SNAP_TIME + SLIP_HOLD + dur + 0.2)
	var foot := _foot(p)
	_after(SNAP_TIME, func() -> void:
		fx.cue("heart_lost")
		if not Motion.reduce:
			fx.puff(foot, Pal.FLOWER, 4))
	_tell_hearts(why)
	_after(SNAP_TIME + SLIP_HOLD, func() -> void: _slip_back(p, before, pts))
	moved.emit()

func _slip_back(p: int, before: Array, pts: PackedVector2Array) -> void:
	_state.revert(before)
	var t := _now()
	var dur := _travel(pts)
	_disp[p] = {"pts": pts, "at": t, "dur": dur, "land": true}
	_busy_for(dur + 0.1)
	fx.cue("slip")
	_land_puff(p, dur)
	_refresh()
	moved.emit()
	if out_of_hearts:
		_after(dur, _run_out)

## A little puff where block `p` lands, as it lands.
func _land_puff(p: int, after: float) -> void:
	if Motion.reduce:
		return
	var at := _foot(p)
	_after(after, func(): fx.puff(at, Pal.SURFACE, 4))

func _ring_at(at: Vector2, when: float) -> void:
	if Motion.reduce:
		return
	_rings.append({"pos": at, "at": when})
	_busy_for(when - _now() + Motion.RING_TIME)

func _drop_rings(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rings:
		if t - float(r.at) < Motion.RING_TIME:
			keep.append(r)
	_rings = keep

## Runs `what` after `delay`, unless the tray has been dealt again meanwhile.
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

# --- the sprout's line and the toast ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

## An explanation of what just happened: the sprout's line and the toast.
func _tell(key: String, mood: int) -> void:
	_say(tr(key), mood)
	_toast = key
	_toast_at = _now()
	queue_redraw()

## A line about a lost heart, with how many are left after it.
func _tell_hearts(key: String) -> void:
	_tell(key, Face.Expr.WORRIED)
	if hearts > 0:
		_say(tr(key) + " " + (tr("SB_HEARTS_ONE") if hearts == 1 else tr("SB_HEARTS_N") % hearts), Face.Expr.WORRIED)

func _cycle_tip() -> void:
	if is_done() or _state.can_undo():
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

## Every block whose cell changed since `before` travels to its new one:
## along the way it could slide when only it moved (an undo), straight and
## staggered when several did (a reset).
func _settle(before: Array, t: float, stagger := 0.0) -> void:
	var moved_ps: Array = []
	for p in before.size():
		if int(before[p][1]) != _state.at(p):
			moved_ps.append(p)
	var k := 0
	var longest := 0.0
	for p: int in moved_ps:
		var from := _xy(int(before[p][1]))
		var pts := PackedVector2Array()
		if moved_ps.size() == 1:
			var back: PackedInt32Array = _state.path(p, int(before[p][1]), true)
			for i in range(back.size() - 1, -1, -1):
				pts.append(_xy(back[i]))
		if pts.size() < 2:
			pts = PackedVector2Array([from, _xy(_state.at(p))])
		var dur := _travel(pts)
		var at := t + Motion.stagger(k, stagger)
		_disp[p] = {"pts": pts, "at": at, "dur": dur, "land": true}
		longest = maxf(longest, at - t + dur)
		k += 1
	_busy_for(longest + 0.1)

static func _travel(pts: PackedVector2Array) -> float:
	var len := 0.0
	for i in range(1, pts.size()):
		len += pts[i].distance_to(pts[i - 1])
	return maxf(SNAP_TIME, len / SLIDE_SPEED)

## Whether a costly move is still playing out: input, Undo, Hint and Reset
## wait, and the host holds its hint video.
func busy() -> bool:
	return _now() < _busy_until

func can_undo() -> bool:
	return _state.can_undo() and not is_done() and not out_of_hearts and not busy() \
		and _state.difficulty < 3

## Puts the blocks back as they were before the last move. Counts no move.
func undo() -> bool:
	if not can_undo():
		return false
	var before: Array = _state.snapshot()
	if not _state.undo():
		return false
	_drag = {}
	_undo_ever = true
	_break_streak()
	_clear_gags()
	_settle(before, _now())
	_tell("SL_UNDONE", Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, State.hints_for(_state.difficulty) + hints_extra - hints_used)

## Plays the next move of a shortest way out, sliding its block along the
## way it goes.
func hint() -> bool:
	if is_done() or out_of_hearts or busy() or hints_left() <= 0:
		return false
	var m: Dictionary = _state.hint_move()
	if m.is_empty():
		return false
	var p: int = m.p
	var pts := PackedVector2Array()
	for c in m.path:
		pts.append(_xy(c))
	if not _state.play(p, m.to):
		return false
	_drag = {}
	hints_used += 1
	_break_streak()
	var t := _now()
	var dur := _travel(pts)
	_disp[p] = {"pts": pts, "at": t, "dur": dur, "land": true}
	var centres := PackedVector2Array()
	for q in pts:
		centres.append(q + Vector2(_state.size_of(p)) * 0.5)
	_trail = {"pts": centres, "at": t, "dur": dur}
	_busy_for(dur + 0.1 + TRAIL_FADE)
	_ring_at(_pt(_xy(m.to) + Vector2(_state.size_of(p)) * 0.5), t + dur)
	_land_puff(p, dur)
	_tell("SL_HINT", Face.Expr.HAPPY)
	fx.cue("hint")
	_refresh()
	moved.emit()
	check_solved()
	return true

func can_reset() -> bool:
	return not (is_done() or out_of_hearts or busy())

## Back to the opening. Hearts lost stay lost.
func reset_board() -> void:
	if not can_reset():
		return
	var before: Array = _state.snapshot()
	_drag = {}
	_trail = {}
	_knocks = []
	_fret = false
	if _state.reset_board():
		_settle(before, _now(), Motion.RESET_STAGGER)
	_break_streak()
	_clear_gags()
	_solved_at = -1.0
	moves = 0
	_running = true
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()
	moved.emit()

func is_solved() -> bool:
	return _state.is_solved()

## The shape of the day and never its answer: the day's blocks by colour;
## Homesick and Flawless when earned.
func share_glyphs() -> String:
	var bars := 0
	var squares := 0
	for p in _state.blocks.size():
		match _state.kind(p):
			Gen.SQ: squares += 1
			Gen.V0, Gen.H0: bars += 1
	var out := "🟥" + "🟦".repeat(bars) + "🟨".repeat(squares)
	if _state.homesick and is_solved():
		out += " 🏡 " + tr("SL_HOME_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += " 🏅 " + tr("BN_FLAWLESS")
	return out

# --- hearts ---

func _lose_heart(at: float) -> void:
	_lost_ever = true
	hearts = maxi(0, hearts - 1)
	_split_index = hearts
	_split_at = at
	if hearts <= 0:
		out_of_hearts = true
	_heart_layer.queue_redraw()

func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell() <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := HEART_TOP + HEART_PILL_PAD.y + HEART_R
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var left := size.x * 0.5 - pill.x * 0.5
	var corner := Vector2(left, y - pill.y * 0.5)
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := 1.0 if Motion.reduce else Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
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
	_hearts_shown = b.mesh()
	var c := Vector2(size.x * 0.5, y)
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

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

## The last heart is gone: dusk falls on the lawn, the big block nods off,
## and the out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts or is_done():
		return
	_asleep = true
	_drag = {}
	_break_streak()
	_clear_gags()
	_tip_timer.stop()
	fx.cue("out_of_hearts")
	_say(tr("SL_OUT"), Face.Expr.SLEEPY)
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
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["SL_OUT_BODY", "SL_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same tray as dealt, every heart back, the clock and the
## moves from zero. Hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	var before: Array = _state.snapshot()
	_state.restart()
	_deal()
	_settle(before, _now(), Motion.RESET_STAGGER)
	_break_streak()
	_clear_gags()
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
	_refresh()
	moved.emit()

## One more heart (the card's video): once a tray. Morning comes back; the
## tray is as it was before the move that cost the last heart.
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
	_say(tr("SL_HEART_BACK"), Face.Expr.HAPPY)
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

# --- the rewards ---

func _reset_rewards() -> void:
	_streak = 0
	_streak_gen += 1
	_nearer = 0
	_gag_until = 0.0
	_gag_gen += 1
	_combo_n = 0
	_combo_at = -INF
	_combo_out_at = -INF
	_love = []
	_flies = []
	_twirl_at = AGO
	_latch_at = AGO
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
	return absi(hash([_state.start_key, _state.par]))

## A kept move that brought the big block nearer the gate: the streak grows
## -- a note up the pentatonic from the second, the bubble over the moved
## block from the third, confetti at 4, 7 and every 5 -- a gag now and then,
## the latch rattling one move from home, a sparkle on the count line the
## first time the way left is half the day's.
func _on_nearer(p: int, land: float, left: int) -> void:
	_streak += 1
	var count := _streak
	var gen := _streak_gen
	var at := _pt(_xy(_state.at(p)) + Vector2(_state.size_of(p)) * Vector2(0.5, 0.0))
	var wait := maxf(0.0, land - _now())
	if count >= 2:
		var step: int = COMBO_STEPS[mini(count - 2, COMBO_STEPS.size() - 1)]
		_after(wait + 0.05, func() -> void:
			if gen == _streak_gen:
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	if count >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = count
		_combo_pos = at
		_combo_at = land
		_combo_out_at = -INF
	if _confetti_at(count) and not Motion.reduce:
		_after(wait, func() -> void:
			if gen == _streak_gen:
				fx.confetti(at, 22)
				fx.cue("confetti"))
	if left == 1 and not Motion.reduce:
		_after(wait, func() -> void:
			_latch_at = _now()
			_busy_for(LATCH_TIME)
			fx.cue("latch"))
	if not _halfway and left > 0 and left * 2 <= _state.par:
		_halfway = true
		if not Motion.reduce:
			_after(wait, func() -> void:
				fx.sparkle(_count_at(), Pal.SUN)
				fx.sparkle(_count_at() + Vector2(-90.0, 0.0), Pal.SUN)
				fx.sparkle(_count_at() + Vector2(90.0, 0.0), Pal.SUN))
	if left > 1:
		_start_gag(_pick_gag(), land)
	_life_layer.queue_redraw()

static func _confetti_at(count: int) -> bool:
	return count == 4 or count == 7 or (count >= 10 and count % 5 == 0)

## The gag for the next nearer move, off the day's hash: one in GAG_ODDS,
## never while one is still on.
func _pick_gag() -> int:
	_nearer += 1
	var t := _now()
	if Motion.reduce or t < _gag_until or force_gag == Gag.NONE:
		return Gag.NONE
	if force_gag >= 0:
		return force_gag
	var roll := posmod(_day_hash() + _nearer * GAG_STEP, GAG_SPAN)
	if roll >= GAG_SPAN / GAG_ODDS:
		return Gag.NONE
	return roll % 3

## The streak ends: a step back, a heart, an undo, a hint, a reset, the
## hearts running out. The bubble deflates.
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
	_flies = []
	_twirl_at = AGO
	_gag_until = 0.0
	_gag_gen += 1
	if _life_layer != null:
		_life_layer.queue_redraw()

## The gag: the big block twirls (a hop and a turn, rigid); love hearts float
## off its head; or a butterfly flutters in, sits on its head a moment and
## flies off.
func _start_gag(gag: int, lands: float) -> void:
	if gag == Gag.NONE:
		return
	var wait := maxf(0.0, lands - _now())
	var gg := _gag_gen
	var cue := ""
	match gag:
		Gag.TWIRL:
			_twirl_at = lands + 0.05
			_busy_for(wait + TWIRL_TIME + 0.1)
			cue = "twirl"
			_gag_until = lands + TWIRL_TIME + 0.2
		Gag.LOVE:
			for k in LOVE_HEARTS:
				_love.append({"t": lands + 0.12 * float(k), "phase": float(k) * 2.1, "k": k})
			cue = "love"
			_gag_until = lands + 0.24 + LOVE_TIME
		Gag.BUTTERFLY:
			var big := _state.big()
			var mid := _pt(_xy(_state.at(big)) + Vector2.ONE)
			_flies.append({"t": lands, "from": -1.0 if mid.x > size.x * 0.5 else 1.0})
			cue = "flutter"
			_gag_until = lands + FLY_IN + FLY_SIT + FLY_OUT
	_after(wait, func() -> void:
		if gg == _gag_gen:
			fx.cue(cue))

## The top of the big block's head where it is drawn, for the love hearts
## and the butterfly.
func _head(t: float) -> Vector2:
	var big := _state.big()
	if big < 0:
		return Vector2.ZERO
	var v := _vis(big, t) + Vector2(1.0, 0.08)
	v.y += _exit(t) - _exit_hop(t) - float(_twirl(t)[1])
	return _pt(v)

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("SL_WIN") % [moves, _state.par]}

## The win screen waits for the landing, the mat, the doors, the walk out
## and the party's moment.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	var walk := maxf(0.0, _solved_at - _now()) + GLOW_TIME + DOOR_TIME * 0.6 + EXIT_TIME + WIN_HOLD
	var party := maxf(0.0, _party_at - _now()) + PARTY_TIME if _party_at < INF else walk
	return maxf(walk, party)

func _on_solved() -> void:
	var t := _now()
	_drag = {}
	_fret = false
	var big: int = _state.big()
	var d: Dictionary = _disp[big]
	# the gate waits for the big block to land on the mat
	_solved_at = t + (0.0 if Motion.reduce else maxf(0.0, float(d.at) + float(d.dur) - t) + 0.06)
	_tip_timer.stop()
	# Flawless: no hint, and no heart lost on Hard and Insane, or never an
	# Undo on Easy and Medium.
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else not _undo_ever)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = t
	_streak_gen += 1
	_clear_gags()
	var total := _solved_at - t + GLOW_TIME + DOOR_TIME + EXIT_TIME + Motion.SOLVE_TIME + 0.6
	_busy_for(total)
	if not Motion.reduce:
		var s := _cell()
		var gate := _pt(_xy(Gen.GOAL) + Vector2(1.0, 2.0)) + Vector2(0.0, Block.FRAME * s * 0.5)
		_after(_solved_at - t, func():
			fx.ring(_pt(_xy(Gen.GOAL) + Vector2.ONE), s * 1.1, Pal.GOOD))
		_after(_solved_at - t + GLOW_TIME, func(): fx.cue("gate"))
		_after(_solved_at - t + GLOW_TIME + DOOR_TIME * 0.6, func():
			fx.puff(gate, Pal.SURFACE, 6))
		var walk := _solved_at - t + GLOW_TIME + DOOR_TIME * 0.6
		for k in EXIT_STEPS:
			var y := EXIT * float(k + 1) / float(EXIT_STEPS)
			_after(walk + EXIT_TIME * float(k + 1) / float(EXIT_STEPS), func():
				fx.puff(_pt(_xy(Gen.GOAL) + Vector2(1.0, 2.0 + y)), Pal.SLIDE_STONE, 4)
				fx.cue("hop", 1.0 + 0.06 * float(k)))
		_after(_solved_at - t + GLOW_TIME + DOOR_TIME + EXIT_TIME * 0.5, func():
			fx.sparkle(gate + Vector2(0.0, s * 0.6), Pal.SUN)
			fx.cue("solved"))
		# the others cheer: a sparkle over each as its hop comes round
		for p in _state.blocks.size():
			if p == big:
				continue
			var c := _xy(_state.at(p)) + Vector2(_state.size_of(p)) * 0.5
			var far := c.distance_to(_xy(Gen.GOAL) + Vector2.ONE)
			var col: Color = Pal.SLIDE_SQ_HI if _state.kind(p) == Gen.SQ else Pal.SLIDE_BAR_HI
			_after(_solved_at - t + GLOW_TIME + DOOR_TIME + far * 0.08 + Motion.SOLVE_TIME * 0.4, func():
				fx.sparkle(_pt(c), col))
	else:
		fx.cue("solved")
	_say(tr("SL_WIN") % [moves, _state.par], Face.Expr.JOY)
	_heart_layer.queue_redraw()
	_party()
	_refresh()

## The tray as it was solved, kept with the day's completion, so a reopened
## day shows the player's own ending without searching for one; and the
## hearts kept and whether it was flawless.
func completion_record() -> Dictionary:
	return {"key": Gen.encode(_state.key), "moves": moves, "hearts": hearts, "flawless": _flawless}

## A reopened daily that was already solved: the tray as it was solved (or,
## with no record, the opening played down its shortest way), the big block
## already out of the gate, the cat asleep and the seal. Never
## check_solved(): `solved` must not fire twice.
func restore_completed_board() -> void:
	_close_card()
	_deal()
	_reset_rewards()
	var k := String(completed_record.get("key", ""))
	if k.length() == Gen.N and Gen.is_goal(Gen.decode(k)):
		_state.restore_key(Gen.decode(k))
		moves = int(completed_record.get("moves", moves))
	else:
		_state.play_out()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_flawless = bool(completed_record.get("flawless", false))
	var t := _now()
	for p in _disp.size():
		_disp[p] = _still_at(p)
	_drag = {}
	_solved_at = t - 100.0
	_anim_until = 0.0
	_opened = t - 100.0
	_cat_at = t - 100.0
	_place_cat(t)
	if _flawless or _state.homesick:
		_stamp_at = t - 100.0
	_tip_timer.stop()
	_say(tr("SL_DONE"), Face.Expr.JOY)
	_heart_layer.queue_redraw()
	_life_layer.queue_redraw()
	_refresh()

# --- the party ---

## After the big block has walked out: confetti twice, the nap cat hopping
## onto the frame's foot and curling up, a bit of sliding wisdom, and the
## seal when the solve earned one (flawless, or any Homesick). Under reduce
## motion the cat and the seal are simply there.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else maxf(0.0, _solved_at - now) + GLOW_TIME + DOOR_TIME + EXIT_TIME + PARTY_AT
	_party_at = now + lead
	_after(lead + 0.8, func() -> void:
		_say(_wisdom(), Face.Expr.JOY))
	_cat_at = now if Motion.reduce else _party_at + CAT_AT
	if _flawless or _state.homesick:
		_stamp_at = now if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
	if Motion.reduce:
		_life_layer.queue_redraw()
		return
	var field := _frame_rect()
	_after(lead + 0.1, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell() * 0.5), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.7, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_life_layer.queue_redraw()

func _wisdom() -> String:
	return tr("SL_CHEER_%d" % posmod(_day_hash(), CHEERS))

func _frame_rect() -> Rect2:
	return Rect2(_origin(), _grid_size()).grow(Block.FRAME * _cell())

# --- the nap cat ---

func _cat_px() -> float:
	return size.x * CAT_PX

## Where she curls up: on the frame's foot, left of the gate (the seal takes
## the right).
func _cat_spot() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x + box.size.x * 0.17, box.end.y - _cat_px() * 0.3)

func _cat_start() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x - _cat_px() * 0.2, box.end.y - _cat_px() * 0.3)

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
		var sq := 0.1 * sin(u * PI)
		sc = Vector2(1.0 - sq, 1.0 + sq)
	elif e < _cat_walk() + CAT_SETTLE:
		var u := (e - _cat_walk()) / CAT_SETTLE
		var sq := 0.14 * sin(u * PI)
		sc = Vector2(1.0 + sq, 1.0 - sq)
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

# --- the life over the tray ---

func _tick_life(now: float) -> bool:
	_love = _love.filter(func(l): return now < float(l.t) + LOVE_TIME)
	_flies = _flies.filter(func(f): return now < float(f.t) + FLY_IN + FLY_SIT + FLY_OUT)
	return not (_love.is_empty() and _flies.is_empty()) \
		or (_combo_n >= COMBO_FROM and (now - _combo_at < Motion.POP_IN + 0.1 or _combo_out_at > -INF)) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## Love hearts (one cached mesh through a transform each), the butterfly
## (one mesh a frame), the seal and the streak's bubble with their words.
func _draw_life() -> void:
	if _cell() <= 0.0 or _state.blocks.is_empty():
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	var s := _cell()
	if not _love.is_empty():
		var mesh := _love_heart()
		shown.append(mesh)
		var head := _head(now)
		for l in _love:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / LOVE_TIME
			var at: Vector2 = head + Vector2((float(l.k) - 1.0) * 0.28 * s + sin(u * TAU + float(l.phase)) * 0.1 * s,
				-0.2 * s - LOVE_RISE * s * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	if not _flies.is_empty():
		var b := Face.Builder.new()
		for f in _flies:
			_fly(b, f, now)
		if not b.verts.is_empty():
			var m := b.mesh()
			shown.append(m)
			_life_layer.draw_mesh(m, null)
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

## A butterfly's visit: in on a curve from the card's side, a rest on the big
## block's head (following it if it slides away), and off up the other way.
func _fly(b: Face.Builder, f: Dictionary, now: float) -> void:
	var e := now - float(f.t)
	if e <= 0.0:
		return
	var s := _cell()
	var spot := _head(now) + Vector2(s * 0.35, -s * 0.06)
	var side: float = f.from
	var at := spot
	var beat := 0.3 + 0.7 * absf(sin(e * 14.0))
	var lean := 0.0
	if e < FLY_IN:
		var u := e / FLY_IN
		var from := spot + Vector2(side * s * 3.0, -s * 2.2)
		at = from.lerp(spot, 1.0 - (1.0 - u) * (1.0 - u)) + Vector2(0.0, -sin(PI * u) * s * 0.5)
		lean = -side * 0.3
	elif e < FLY_IN + FLY_SIT:
		var w := e - FLY_IN
		beat = 0.25 + 0.5 * absf(sin(w * 3.0))
	else:
		var u := (e - FLY_IN - FLY_SIT) / FLY_OUT
		var to := spot + Vector2(-side * s * 2.8, -s * 3.4)
		at = spot.lerp(to, u * u) + Vector2(sin(u * 14.0) * s * 0.08, 0.0)
		lean = side * 0.3
	Cat.butterfly(b, at, s * 0.36, beat, lean)

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
		if e < 0.0:
			return
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
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.SUN_DEEP, alpha))
	_life_layer.draw_set_transform(Vector2.ZERO)

## The seal on the frame's lower right corner, dropping in and settling, its
## words over it: Flawless; on Homesick "Insane" over Flawless or Homesick,
## on the night seal.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = _state.homesick
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var box := _frame_rect()
	var centre := box.end - Vector2(rad * 0.85, rad * 0.72)
	centre.x = clampf(centre.x, rad * 1.08, size.x - rad * 1.08)
	centre.y = minf(centre.y, size.y - rad * 1.02)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("SL_HOME_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
