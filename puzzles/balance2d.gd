extends "res://core/puzzle_base.gd"

## Balance as a flat board: a column of wooden scales on the host's parchment
## card, each one a true statement about the fruit in its two dishes, with
## the player's answer in the weight cards under the board
## (ui/flat/weight_tray.gd). The rules live in puzzles/balance_state.gd,
## which this only draws; the island version is in legacy/.
##
## Every beam tilts live under the weights the player has guessed -- the
## heavier dish dips -- so **the board is its own check**: when the last beam
## swings level the puzzle is solved. That is why `capabilities()` has no
## "check" and why this screen has no actions row at all: a button that read
## the board for you would be the puzzle. Reset lives in the top bar
## instead, which is this screen's one structural departure from the other
## flat boards (spec section 5).
##
## Its motion is the flat vocabulary's (core/motion.gd, "the flat boards'
## vocabulary"; docs/art/flat-motion.md is the table): the scales pop in as
## wide things and their fruit land a beat later with the squash, which is
## what swings each beam to its angle; a kind whose weight changed hops in
## every dish it stands in; a beam that comes level rings; the solve is the
## hop wave. What is this board's alone is the tilt itself (`TILT_*`), the
## column's pace (`BAND_STAGGER`: a scale is a row, not a cell) and the
## ground -- a soft shadow under every dish that follows it up and down, the
## stand's own, and the scenery behind the column (ui/flat/scenery.gd).
##
## The wood is drawn as **cached meshes, not canvas commands**: gl_compatibility
## pays per draw command, so a scale is a handful of draw_mesh calls (ground,
## stand, beam, two dishes) rather than a dozen rounded rectangles, and every
## scale of a size shares them. Filled shapes get the Builder's feather,
## since MSAA stays off for the 2D canvas.
## Spec: docs/superpowers/specs/2026-09-18-balance-flat-design.md, sections 2
## to 6 and 10, ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#balance).

const Gen = preload("res://puzzles/balance_gen.gd")
const State = preload("res://puzzles/balance_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Fruit = preload("res://ui/faces/fruit.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## Layout, in the board card's inner pixels (spec section 3). A band is
## capped, so easy's two scales make a short board with air above the weight
## cards rather than a tall one half full of nothing.
const PAD := 28.0
const BAND_MAX := 340.0
## The scale's drawing scales with its band, against this reference height,
## and never grows past ART_MAX however tall the band is.
const ART_REF := 250.0
const ART_MAX := 1.15
## How far above the band's middle the fulcrum sits, so the dishes hang into
## the lower half.
const PIVOT_LIFT := 32.0

## The scale, in art units (spec section 3).
const ARM := 300.0
const POST_W := 30.0
const POST_H := 124.0
const POST_R := 10.0
const BASE_W := 152.0
const BASE_H := 24.0
const BASE_R := 12.0
const BASE_Y := 118.0
const BEAM_OVER := 14.0
const BEAM_H := 18.0
const BEAM_R := 9.0
const SHADE_Y := 2.0
const SHADE_H := 7.0
const SHADE_R := 4.0
const HUB_R := 15.0
const HUB_IN := 7.0
## The dish on its cords, and the knot they hang from.
const DISH_W := 176.0
const CORD := 54.0
const CORD_X := 0.42
const CORD_W := 5.0
const KNOT_R := 7.0
const DISH_DEEP := 34.0
const DISH_CTRL := 0.4
const LIP_Y := 7.0
const LIP_H := 12.0
const LIP_R := 6.0
## A fruit in a dish, and how close together three of them stand.
const PIECE := 62.0
const PITCH_MAX := 56.0
const PIECE_LIFT := 12.0

## The ground (spec section 10): the floor the stand's base sits on, in art
## units below the fulcrum, and the shadows on it. A dish's shadow is widest
## and darkest with the dish on the ground and shrinks and fades as the dish
## rises through SHADOW_REACH; the stand's is fixed.
const GROUND_Y := BASE_Y + BASE_H
const SHADOW_RY := 0.16
const SHADOW_NEAR := 0.16
const SHADOW_FAR := 0.06
const SHADOW_SHRINK := 0.4
const SHADOW_REACH := 140.0
const SHADOW_HUG := 4.0
const BASE_SHADOW := 0.12
const BASE_SHADOW_W := 0.6
## The scenery behind the column: a cloud in the top corner of each band,
## alternating sides, a small second one on the first band, tufts either
## side of every base and in the card's bottom corners.
const CLOUD_R := 24.0
const CLOUD_SMALL := 14.0
const CLOUD_X := 0.13
const CLOUD_Y := 0.15
const TUFT_H := 30.0
const TUFT_GAP := 26.0
const CORNER_TUFT := 40.0

## Weight difference at which the beam reaches TILT_MAX. Past three the tilt
## stops growing: the board says "this dish is heavier", never by how much,
## which is what keeps a wildly wrong guess from burying a dish in the card.
const TILT_CAP := 3
const TILT_MAX := 0.22
const TILT_TIME := 0.42
## Hint count, not refunded by reset (HUD spec, section 3).
const HINTS := 3

# --- motion: the vocabulary's, and what is this board's own ---
## The board arrives this long after the chrome starts.
## The column's own pace: a scale is a row and not a cell, so its waves --
## the entrance, a reset, a kind hopping down the board -- step by band.
const BAND_STAGGER := 0.08
## The ring a fulcrum gives when its beam comes level, in art units.
const LEVEL_RING := 90.0
## How long both dishes keep their happy face after a beam comes level.
const LEVEL_JOY := 0.9
const SOLVE_SPARKLES := 3
const HINT_SPARKLES := 5
## How long the host waits before the win screen: the last beam's swing, the
## wave of hops and their sparkles all have to land first.
const WIN_DELAY := 1.5
const WIN_DELAY_STILL := 0.3
## The tip card moves on to the next scale after this long.
const TIP_CYCLE := 8.0

var state = State.new()
var fx: Node2D

var _scales: Array[Control] = []       # [i] -> the band's root, at the fulcrum
var _lifts: Array[Control] = []        # [i] -> the entrance's node, 0 at rest
var _grounds: Array[Control] = []      # [i] -> the shadows on the floor
var _stands: Array[Control] = []       # [i] -> the post and base mesh
var _beams: Array[Control] = []        # [i] -> the turning node
var _dishes: Array = []                # [i] -> [left, right] Controls, always level
var _pieces: Array = []                # [i] -> [[Face...], [Face...]]
var _tilt_tw: Array = []               # [i]
var _shown_angle: Array[float] = []    # [i] -> the angle the dishes were last hung from
var _level_until: Array[float] = []    # [i] -> msec the dishes keep beaming to
var _was_level: Array[bool] = []
var _entrance: Array[Tween] = []
var _hops: Dictionary = {}             # face -> its hop
var _scenery: Control
## Bumped by every rebuild, so a callback waiting on a timer from the board
## before never lands on this one.
var _gen := 0

var _band := 0.0
var _art := 1.0
var _tip := ""
var _tip_mood: int = Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
## Every wood mesh built so far, keyed by shape and art scale, so all the
## scales of a board share three meshes between them.
static var _wood_cache: Dictionary = {}

func puzzle_id() -> String: return "balance"
func title() -> String: return "Balance"

func rules() -> String:
	return "Every scale balances, and one weight is given. Use a fruit's minus and plus to change what it weighs; the beams follow at once. Solve it when every beam sits level."

## No check: every beam already answers that question, every frame. Reading
## the board is the whole puzzle, so there is nothing for a Check to do --
## and with nothing else to put in it, this screen drops the actions row and
## puts Reset in the top bar.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	# The scenery first, so it is drawn under every scale.
	_scenery = Scenery.new()
	_scenery.name = "Scenery"
	add_child(_scenery)
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 1
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_next_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	# Three, four then five kinds. The scale count follows from the kind
	# count rather than being asked for: with the anchor pinning one kind,
	# `shapes - 1` independent scales is exactly what a unique board needs,
	# and the generator trims every scale the others already imply.
	var shapes := clampi(3 + difficulty, 3, Fruit.count())
	state.setup(Gen.generate(rng, shapes))
	_build_scales()
	_layout()
	_tip_idx = 0
	_say(_sentence(0), Face.Expr.HAPPY)
	_enter()

## The card this board wants, given the height the host's slot can spare: the
## bands it needs at up to BAND_MAX each, and no more. The leftover becomes
## air *above* the weight cards, because a gap under the day card would read
## as a mistake and a gap above the cards reads as room.
func card_height(available: float) -> float:
	var n: int = maxi(1, state.scales.size())
	var band: float = minf((available - 2.0 * PAD) / n, BAND_MAX)
	return 2.0 * PAD + band * float(n)

# --- the scales ---

func _build_scales() -> void:
	_stop_all()
	for root in _scales:
		root.queue_free()
	_scales = []
	_lifts = []
	_grounds = []
	_stands = []
	_beams = []
	_dishes = []
	_pieces = []
	_tilt_tw = []
	_shown_angle = []
	_level_until = []
	_was_level = []
	_hops = {}
	for i in state.scales.size():
		_build_scale(i)

## One scale: the shadows on its floor, the stand under the fulcrum, the beam
## turning on it, and a dish hanging from each beam end with that side's
## fruit standing in it.
##
## Two nodes deep on purpose. The **root** is where the layout puts the
## fulcrum, and only the layout ever writes it; the **lift** is what the
## entrance pops, and only the entrance ever writes that. Animating the
## root directly meant the entrance captured a rest position from before the
## card had its real height and then held the scale there for good, which
## stacked every band on top of the first (ui/hud/panel.gd separates `_inner`
## from the panel for exactly this reason).
##
## The dishes are children of the lift and not of the beam: they hang on
## cords, so they stay level and upright while the beam turns, and placing
## them straight from the beam's angle each frame is both simpler and
## steadier than a second tween counter-turning them.
func _build_scale(i: int) -> void:
	var sc: Dictionary = state.scales[i]
	var root := Control.new()
	root.name = "Scale_%d" % i
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_scales.append(root)

	var lift := Control.new()
	lift.name = "Lift"
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lift)
	_lifts.append(lift)

	var ground := Ground.new()
	ground.name = "Ground"
	lift.add_child(ground)
	_grounds.append(ground)

	var stand := Wood.new()
	stand.name = "Stand"
	lift.add_child(stand)
	_stands.append(stand)

	var beam := Wood.new()
	beam.name = "Beam"
	lift.add_child(beam)
	_beams.append(beam)

	var dishes: Array[Control] = []
	var pieces: Array = []
	for side in [-1, 1]:
		var dish := Wood.new()
		dish.name = "Dish_%s" % ("L" if side < 0 else "R")
		lift.add_child(dish)
		dishes.append(dish)
		var row: Array[Control] = []
		var kinds: Array = sc.left if side < 0 else sc.right
		for q in kinds.size():
			var face := Fruit.make(int(kinds[q]), PIECE, Vector2.ZERO)
			face.set_meta("kind", int(kinds[q]))
			dish.add_child(face)
			row.append(face)
			face.set_idle(true)
		pieces.append(row)
	_dishes.append(dishes)
	_pieces.append(pieces)
	_tilt_tw.append(null)
	_shown_angle.append(INF)
	_level_until.append(0.0)
	_was_level.append(state.is_level(i))

## Places everything from the card's current size: the band height, the art
## scale that follows from it, every scale's meshes and dishes, and the
## scenery's anchors.
func _layout() -> void:
	if _scales.is_empty():
		return
	var n: int = maxi(1, state.scales.size())
	_band = clampf((size.y - 2.0 * PAD) / float(n), 1.0, BAND_MAX)
	_art = clampf(_band / ART_REF, 0.05, ART_MAX)
	for i in _scales.size():
		var root: Control = _scales[i]
		root.position = Vector2(size.x * 0.5, _pivot_y(i))
		root.pivot_offset = Vector2.ZERO
		var ground: Ground = _grounds[i]
		ground.art = _art
		ground.reach = ARM * _art
		(_stands[i] as Wood).mesh = _stand_mesh()
		var beam: Control = _beams[i]
		beam.pivot_offset = Vector2.ZERO
		(beam as Wood).mesh = _beam_mesh()
		for side in 2:
			var dish: Wood = _dishes[i][side]
			dish.mesh = _dish_mesh()
			_fit_pieces(i, side)
	_place_dishes(true)
	_dress()

func _pivot_y(i: int) -> float:
	return PAD + float(i) * _band + _band * 0.5 - PIVOT_LIFT * _art

## Where every fruit rests in its dish, in the dish's space: the top of a
## piece's seat sits PIECE_LIFT above the rim.
func _piece_rest_y() -> float:
	return (CORD - PIECE_LIFT - PIECE * 0.5) * _art

## The fruit in one dish, in a row across it. Three a side is the most the
## generator ever produces, so they never need a second rank.
func _fit_pieces(i: int, side: int) -> void:
	var row: Array = _pieces[i][side]
	var n := row.size()
	var seat := PIECE * _art
	var pitch: float = minf(PITCH_MAX * _art, (DISH_W * _art - seat * 0.9) / maxf(1.0, float(n) - 0.001))
	for q in n:
		var x: float = (float(q) - float(n - 1) * 0.5) * (pitch if n > 1 else 0.0)
		Fruit.resize(row[q], seat, Vector2(x, CORD * _art - PIECE_LIFT * _art))

## The scenery's anchors, from the bands the card actually has: a cloud in
## the top corner of every band, alternating sides, and a small one in the
## first band's other corner; a tuft either side of every base; a tuft in
## each of the card's bottom corners. Clouds keep to the corners because the
## column spans nearly the card's width and a cloud behind a raised dish is
## clutter.
func _dress() -> void:
	var w := size.x
	var ch := card_height(size.y)
	var clouds: Array[Vector3] = []
	var tufts: Array[Vector3] = []
	for i in _scales.size():
		var top := PAD + float(i) * _band
		var left: bool = i % 2 == 0
		clouds.append(Vector3(w * (CLOUD_X if left else 1.0 - CLOUD_X), top + _band * CLOUD_Y, CLOUD_R * _art))
		if i == 0:
			clouds.append(Vector3(w * (1.0 - CLOUD_X * 0.8), top + _band * CLOUD_Y * 1.6, CLOUD_SMALL * _art))
		var floor_y: float = _pivot_y(i) + GROUND_Y * _art
		for way: float in [-1.0, 1.0]:
			tufts.append(Vector3(w * 0.5 + way * (BASE_W * 0.5 + TUFT_GAP) * _art, floor_y, TUFT_H * _art))
	for way: float in [-1.0, 1.0]:
		tufts.append(Vector3(w * 0.5 + way * (w * 0.5 - PAD - CORNER_TUFT), ch - PAD - 2.0, TUFT_H * 0.8 * _art))
	_scenery.ground = Pal.PARCHMENT
	_scenery.clouds = clouds
	_scenery.tufts = tufts
	_scenery.rebuild()

## Both dishes of every scale, hung from wherever their beam end now is, and
## the ground told the angle so the shadows follow. Driven per frame rather
## than tweened alongside the beam: the beam's own tween can be stopped and
## replaced mid-swing, and a second tween chasing it would drift -- the
## island board's reason for doing the same. A beam that has not moved costs
## nothing: its dishes are left where they hang.
func _place_dishes(force := false) -> void:
	for i in _beams.size():
		var a: float = _beams[i].rotation
		if not force and absf(a - _shown_angle[i]) < 0.0002:
			continue
		_shown_angle[i] = a
		var reach := ARM * _art
		var d := Vector2(cos(a), sin(a)) * reach
		for side in 2:
			# -1 hangs the left dish, +1 the right.
			var way := -1.0 if side == 0 else 1.0
			(_dishes[i][side] as Control).position = d * way
		(_grounds[i] as Ground).angle = a

func _process(delta: float) -> void:
	super(delta)
	_place_dishes()
	_refresh_faces()

# --- the tilt ---

## The beam's angle for scale `i`. A positive angle carries +x downward in
## the canvas's y-down space, and the right dish is at +x, so a heavier left
## side needs a negative angle to dip it.
func _tilt_for(i: int) -> float:
	var d: int = clampi(state.lean(i), -TILT_CAP, TILT_CAP)
	return -float(d) / float(TILT_CAP) * TILT_MAX

## Swings every beam to what the current guess says, each after its band's
## share of `per` (a reset unwinds down the column; a step moves them all at
## once), and rings the fulcrum of any scale that has just come level. The
## tilt is the state itself and not decoration, so under reduce-motion it
## snaps rather than being skipped: Motion.slide sets the angle and returns
## null, which is the board showing the truth without moving.
func _update_scales(per := 0.0) -> void:
	for i in _beams.size():
		var beam: Control = _beams[i]
		var target := _tilt_for(i)
		Motion.stop(_tilt_tw[i])
		_tilt_tw[i] = Motion.slide(beam, "rotation", beam.rotation, target, TILT_TIME, Motion.stagger(i, per))
		var level := state.is_level(i)
		if level and not _was_level[i]:
			fx.ring(_scales[i].position, LEVEL_RING * _art, Pal.LEAF)
			_level_until[i] = _now() + LEVEL_JOY
			fx.cue("level")
		_was_level[i] = level
	_place_dishes()
	_refresh_faces()

## Every fruit of the kinds in `kinds` hops in its dish, down the column at
## the band's pace: the card that was pressed and the pieces it weighs are
## one thing, and this is what says so.
func _hop_kinds(kinds: Array) -> void:
	if kinds.is_empty():
		return
	var rest := _piece_rest_y()
	for i in _pieces.size():
		for side in 2:
			for face in _pieces[i][side]:
				if not kinds.has(int(face.get_meta("kind", -1))):
					continue
				Motion.stop(_hops.get(face))
				_hops[face] = Motion.hop(face, Motion.HOP, Motion.HOP_TIME, Motion.stagger(i, BAND_STAGGER), rest)

## What every fruit should be showing: both dishes of a scale that just came
## level beam for a moment, the low dish's fruit look strained, and the high
## dish's rides up content. Nothing is hidden on this board -- the beams are
## the whole information channel -- so a face may say whatever the beam
## already says, and none of them ever reacts to being *correct*. A face is
## only written when its look changes, since writing it redraws it.
func _refresh_faces() -> void:
	var now := _now()
	for i in _beams.size():
		var a: float = _beams[i].rotation
		var beaming: bool = now < _level_until[i]
		for side in 2:
			var way := -1.0 if side == 0 else 1.0
			var low: bool = way * a > 0.001
			var expr: int = Face.Expr.JOY if beaming else (Face.Expr.WORRIED if low else Face.Expr.HAPPY)
			for face in _pieces[i][side]:
				if (face as Control).expression != expr:
					(face as Control).expression = expr

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

## Control-local point over the centre of scale `i`'s dish on `side` (0 left,
## 1 right), at the beam's current angle. The win harness checks with this
## that every dish lands inside the card, which is what TILT_MAX and the
## band cap exist to guarantee; it is the flat counterpart of the island
## board's `pad_to_local`.
func dish_to_local(i: int, side: int) -> Vector2:
	if i < 0 or i >= _dishes.size():
		return Vector2.ZERO
	return _scales[i].position + _lifts[i].position \
		+ (_dishes[i][side] as Control).position + Vector2(0.0, CORD * _art)

# --- the weight cards ---

## What ui/flat/weight_tray.gd draws: one entry per kind, in the order the
## kinds are introduced, which is also the order ui/faces/fruit.gd lists
## them. A given kind takes no presses; an unlocked one greys the button
## whose direction has run out.
func weights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in state.shapes:
		out.append({
			"weight": int(state.guess[i]),
			"given": bool(state.locked[i]),
			"can_minus": state.can_step(i, -1),
			"can_plus": state.can_step(i, 1),
		})
	return out

## The tray's minus or plus. A press the rules refuse costs no move and is
## answered in words, since the card's own shiver does not say why.
func step_weight(i: int, delta: int) -> bool:
	if is_done() or i < 0 or i >= state.shapes:
		return false
	if not state.step(i, delta):
		if state.locked[i]:
			_say("That one is given. The scales do the rest.", Face.Expr.HAPPY)
		elif delta < 0:
			_say("A thing always weighs at least one.", Face.Expr.WORRIED)
		else:
			_say("Nine is as heavy as anything gets.", Face.Expr.WORRIED)
		fx.cue("refused")
		return false
	_update_scales()
	_hop_kinds([i])
	fx.cue("step")
	_after_change()
	note_move()
	return true

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Puts the last weight back and re-settles the beams. Counts no move.
func undo() -> bool:
	if is_done():
		return false
	var last: Dictionary = state.undo()
	if last.is_empty():
		return false
	_update_scales()
	_hop_kinds([int(last.shape)])
	fx.cue("undo")
	_after_change()
	moved.emit()
	check_solved()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Reveals one kind's true weight: its card takes the given look and loses
## its buttons, sparkles rise off it, and the beams settle into whatever that
## made true, so the rest of the board has one more fixed point to reason
## from. Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var was: Array = state.guess.duplicate()
	var i := state.apply_hint()
	if i < 0:
		return false
	hints_used += 1
	_update_scales()
	if int(was[i]) != int(state.guess[i]):
		_hop_kinds([i])
	# Over the bottom edge of the *card*, which is where the weight card it
	# belongs to stands just below. The board Control fills the whole slot,
	# which is taller than the card whenever the bands are capped.
	var at := Vector2(size.x * (float(i) + 0.5) / float(state.shapes), card_height(size.y) - PAD)
	for k in HINT_SPARKLES:
		fx.sparkle(at + Vector2((randf() - 0.5) * size.x / float(state.shapes) * 0.7, 0.0),
			Fruit.colour(i))
	_say("That one is settled. The scales do the rest.", Face.Expr.HAPPY)
	fx.cue("hint")
	moved.emit()
	check_solved()
	return true

## Every unlocked kind falls back to one. Hints already spent stay spent and
## the weights they revealed stay locked, as on the island. The column
## unwinds from the top rather than snapping: each beam's swing and each
## kind's hop are staggered by band, so the eye follows the change down the
## board.
func reset_board() -> void:
	if is_done():
		return
	_stop_entrance()
	var changed: Array = state.reset()
	moves = 0
	_running = true
	_update_scales(BAND_STAGGER)
	_hop_kinds(changed)
	_say("Back to one each. Start from the scales.", Face.Expr.HAPPY)
	fx.cue("reset")

## A completed daily is rebuilt from its seed, so its transient weights start
## at the unsolved arrangement when the player opens it again. Restore the
## secret directly and settle the visible board without emitting `solved` a
## second time; the host owns the completion presentation.
func restore_completed_board() -> void:
	_stop_entrance()
	state.guess = state.secret.duplicate()
	state.history.clear()
	for i in _beams.size():
		Motion.stop(_tilt_tw[i])
		_tilt_tw[i] = null
		_beams[i].rotation = _tilt_for(i)
		_shown_angle[i] = INF
		_level_until[i] = INF
		_was_level[i] = true
	_place_dishes(true)
	_refresh_faces()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return "⚖️ %d kinds · %d scales" % [state.shapes, state.scales.size()]

# --- the tip card ---

## The sprout's line: the scale it is pointing at read out in words, or the
## reason a press was just refused. It cycles to the next scale every
## TIP_CYCLE seconds, and a line it was given holds for that long before the
## cycle takes over again.
func tip_line() -> Dictionary:
	return {"text": _tip, "mood": _tip_mood}

func _say(text: String, mood: int) -> void:
	_tip_timer.start()
	if _tip == text and _tip_mood == mood:
		return
	_tip = text
	_tip_mood = mood
	focus_changed.emit()

func _next_tip() -> void:
	if is_done() or state.scales.is_empty():
		return
	_tip_idx = (_tip_idx + 1) % state.scales.size()
	_say(_sentence(_tip_idx), Face.Expr.HAPPY)

## After any change: the sprout goes back to reading a scale out, so a
## refusal's line does not sit there once the board has moved on.
func _after_change() -> void:
	if is_done() or state.scales.is_empty():
		return
	_say(_sentence(_tip_idx), Face.Expr.HAPPY)

## Scale `i` as a sentence: "Two apples weigh the same as one pumpkin." The
## scales are already sentences -- that is the whole idea of the board -- so
## the card's job is to say one out loud for whoever cannot yet read a beam.
func _sentence(i: int) -> String:
	if i < 0 or i >= state.scales.size():
		return ""
	var sc: Dictionary = state.scales[i]
	var left: String = _side_words(sc.left)
	var verb := " weighs" if (sc.left as Array).size() == 1 else " weigh"
	return "%s%s the same as %s." % [left.substr(0, 1).to_upper() + left.substr(1), verb, _side_words(sc.right)]

## One side in words: "two apples", or "one pear and two acorns".
func _side_words(side: Array) -> String:
	var counts: Dictionary = {}
	var order: Array[int] = []
	for s in side:
		var i := int(s)
		if not counts.has(i):
			counts[i] = 0
			order.append(i)
		counts[i] = int(counts[i]) + 1
	var parts: Array[String] = []
	for i in order:
		parts.append(Fruit.counted(i, int(counts[i])))
	if parts.size() == 1:
		return parts[0]
	var last: String = parts.pop_back()
	return "%s and %s" % [", ".join(parts), last]

# --- the win ---

## Every beam is level: the fruit hop in the vocabulary's solve wave, down
## the column and across each dish, with JOY eyes, and sparkles rise over
## each fulcrum as its wave passes. The host brings the win screen in after
## this (win_delay).
func _on_solved() -> void:
	_tip_timer.stop()
	_say("Everything sits level. Beautifully weighed.", Face.Expr.JOY)
	var rest := _piece_rest_y()
	var k := 0
	for i in _beams.size():
		_level_until[i] = _now() + INF
		var first := Motion.SOLVE_DELAY + Motion.stagger(k, Motion.SOLVE_STAGGER)
		for side in 2:
			for face in _pieces[i][side]:
				Motion.stop(_hops.get(face))
				_hops[face] = Motion.hop(face, Motion.SOLVE_HOP, Motion.SOLVE_TIME,
					Motion.SOLVE_DELAY + Motion.stagger(k, Motion.SOLVE_STAGGER), rest)
				k += 1
		var at: Vector2 = _scales[i].position
		var spread := ARM * _art
		_after(first, func() -> void:
			for s in SOLVE_SPARKLES:
				fx.sparkle(at + Vector2((randf() - 0.5) * spread, 0.0), Pal.SUN))
	fx.cue("solved")

## The win screen's cast: the five kinds with their true weights under them,
## laid across the space the sun and the moon usually fill. The board is the
## answer here, so it stays on screen level underneath.
func flat_win() -> Dictionary:
	var faces: Array[Control] = []
	var labels: Array[String] = []
	for i in state.shapes:
		faces.append(Fruit.make(i, 140.0, Vector2.ZERO))
		labels.append(str(int(state.secret[i])))
	return {"faces": faces, "labels": labels, "subtitle": "Everything balances!"}

func win_delay() -> float:
	return WIN_DELAY_STILL if Motion.reduce else WIN_DELAY

# --- entrance and housekeeping ---

## The board arrives the way a flat board does: each scale pops in level, a
## wide thing so from ENTER_WIDE_FROM rather than nothing, one band after
## another at the column's pace; its fruit land in the dishes a beat later
## with the squash, one after another; and as they land the beam swings to
## the angle their weights ask for. The weights arriving is what tilts the
## scale, which is the whole board in one gesture.
func _enter() -> void:
	_stop_entrance()
	for i in _scales.size():
		var root: Control = _scales[i]
		var at := Motion.ENTER_DELAY + Motion.stagger(i, BAND_STAGGER)
		# The pop is on the lift, about the fulcrum in the root's own space,
		# so it says nothing about where the band sits and the layout stays
		# free to move it.
		var pop: Tween = Motion.slide(_lifts[i], "scale", Vector2.ONE * Motion.ENTER_WIDE_FROM, Vector2.ONE, Motion.ENTER_POP, at)
		if pop != null:
			_entrance.append(pop)
		var fade: Tween = Motion.appear(root, 0.0, 1.0, Motion.ENTER_POP, at)
		if fade != null:
			_entrance.append(fade)
		var land := at + Motion.ENTER_FACE_LAG
		var q := 0
		for side in 2:
			for face in _pieces[i][side]:
				var drop: Tween = Motion.pop_in(face, Motion.POP_IN, land + Motion.stagger(q, Motion.ENTER_STAGGER))
				if drop != null:
					_entrance.append(drop)
				q += 1
		var beam: Control = _beams[i]
		Motion.stop(_tilt_tw[i])
		_tilt_tw[i] = Motion.slide(beam, "rotation", 0.0, _tilt_for(i), TILT_TIME, land + Motion.POP_IN * 0.6)
		_was_level[i] = state.is_level(i)
	fx.cue("enter")

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for i in _scales.size():
		_lifts[i].scale = Vector2.ONE
		_scales[i].modulate.a = 1.0
		for side in 2:
			for face in _pieces[i][side]:
				(face as Control).scale = Vector2.ONE

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at a dish that is gone.
func _stop_all() -> void:
	_gen += 1
	_stop_entrance()
	for tw in _tilt_tw:
		Motion.stop(tw)
	for tw in _hops.values():
		Motion.stop(tw)
	_hops = {}

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	var gen := _gen
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

# --- the wood, as meshes ---

## The post and its carved base, below the fulcrum.
func _stand_mesh() -> ArrayMesh:
	return _wood("stand", func(b: Face.Builder, k: float) -> void:
		b.fan(Face.Builder.round_rect(Vector2(-POST_W * 0.5, 0.0) * k,
			Vector2(POST_W, POST_H) * k, POST_R * k), Pal.SCALE_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(-BASE_W * 0.5, BASE_Y) * k,
			Vector2(BASE_W, BASE_H) * k, BASE_R * k), Pal.SCALE_DARK))

## The beam, its underside shade and the hub it turns on. The hub's two
## circles are concentric with the fulcrum, so they can live in the turning
## mesh without ever looking turned.
func _beam_mesh() -> ArrayMesh:
	return _wood("beam", func(b: Face.Builder, k: float) -> void:
		var w := (ARM + BEAM_OVER) * 2.0 * k
		b.fan(Face.Builder.round_rect(Vector2(-(ARM + BEAM_OVER) * k, -BEAM_H * 0.5 * k),
			Vector2(w, BEAM_H * k), BEAM_R * k), Pal.SCALE_WOOD)
		b.fan(Face.Builder.round_rect(Vector2(-(ARM + BEAM_OVER) * k, SHADE_Y * k),
			Vector2(w, SHADE_H * k), SHADE_R * k), Color(Pal.SCALE_DEEP, 0.55))
		b.disc(Vector2.ZERO, HUB_R * k, Pal.SCALE_DARK)
		b.disc(Vector2.ZERO, HUB_IN * k, Color(Pal.SCALE_WOOD, 0.9)))

## A dish on its two cords, drawn from the beam end it hangs under: the cords
## out to the rim, the knot they hang from, the bowl swung under them, and
## the rim laid over the top.
func _dish_mesh() -> ArrayMesh:
	return _wood("dish", func(b: Face.Builder, k: float) -> void:
		var ry := CORD * k
		var half := DISH_W * 0.5 * k
		for sx: float in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(sx * DISH_W * CORD_X * k, ry)]),
				CORD_W * k, Color(Pal.SCALE_DARK, 0.8))
		b.disc(Vector2.ZERO, KNOT_R * k, Pal.SCALE_DARK)
		# bezier2 includes its start and drops its end, so the rim's right
		# corner comes from the first curve and nothing is doubled --
		# a repeated vertex makes triangulate_polygon hand back nothing.
		var bowl := PackedVector2Array([Vector2(-half, ry)])
		bowl.append_array(Face.Builder.bezier2(Vector2(half, ry),
			Vector2(DISH_W * DISH_CTRL * k, ry + DISH_DEEP * k), Vector2(0.0, ry + DISH_DEEP * k)))
		bowl.append_array(Face.Builder.bezier2(Vector2(0.0, ry + DISH_DEEP * k),
			Vector2(-DISH_W * DISH_CTRL * k, ry + DISH_DEEP * k), Vector2(-half, ry)))
		b.polygon(bowl, Pal.SCALE_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(-half, ry - LIP_Y * k),
			Vector2(DISH_W * k, LIP_H * k), LIP_R * k), Color(Pal.SCALE_WOOD, 0.95)))

## Builds `shape` at the current art scale, or hands back the one already
## built: every scale on the board is the same size, so the whole column
## costs three meshes however many bands it has.
func _wood(shape: String, paint: Callable) -> ArrayMesh:
	var k: float = roundf(_art * 100.0) / 100.0
	var key := "%s|%d" % [shape, int(k * 100.0)]
	var mesh: ArrayMesh = _wood_cache.get(key)
	if mesh == null:
		var b := Face.Builder.new()
		paint.call(b, k)
		mesh = b.mesh()
		_wood_cache[key] = mesh
	return mesh

## One wood mesh, drawn as a single command. gl_compatibility pays per draw
## command, so the whole stand is one of these rather than two rounded
## rectangles (see CLAUDE.md on canvas primitives).
class Wood extends Control:
	var mesh: ArrayMesh:
		set(v):
			mesh = v
			queue_redraw()

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, null)

## The ground under one scale: the stand's shadow, and under each dish a
## shadow that follows it -- widest and darkest with the dish down on the
## ground, narrower and fainter as it rises -- so the beam's tilt reads as
## height and not only as an angle. Three draws of Scenery's one radial disc,
## redrawn only when the beam's angle changes.
class Ground extends Control:
	var art := 1.0
	var reach := 0.0
	var angle := 0.0:
		set(v):
			angle = v
			queue_redraw()

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var floor_y := GROUND_Y * art
		_shadow(Vector2(0.0, floor_y), BASE_W * BASE_SHADOW_W * art, BASE_SHADOW)
		for way: float in [-1.0, 1.0]:
			var end := Vector2(cos(angle), sin(angle)) * reach * way
			var bottom := end.y + (CORD + DISH_DEEP) * art
			var lift := clampf((floor_y - bottom) / (SHADOW_REACH * art), 0.0, 1.0)
			var rx := DISH_W * 0.5 * art * (1.0 - SHADOW_SHRINK * lift)
			# A dish the tilt carries below the floor keeps its shadow just
			# under itself rather than above its bottom.
			var y := maxf(floor_y, bottom + SHADOW_HUG * art)
			_shadow(Vector2(end.x, y), rx, lerpf(SHADOW_NEAR, SHADOW_FAR, lift))

	func _shadow(at: Vector2, rx: float, alpha: float) -> void:
		draw_mesh(Scenery.shadow(), null,
			Transform2D(0.0, Vector2(rx, rx * SHADOW_RY) / Scenery.SHADOW_UNIT, 0.0, at),
			Color(Pal.TEXT, alpha))
