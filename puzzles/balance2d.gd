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
## every dish it stands in; a beam that swings into level rings; the solve
## is the hop wave. What is this board's alone is the swing itself -- a
## damped spring on the board's clock (`SWING_*`), with each dish tipping on
## its cords behind it (`SWAY_*`) -- the pointer whose notch lights when the
## beam arrives level, the column's pace (`BAND_STAGGER`: a scale is a row,
## not a cell) and the ground -- a soft shadow under every dish that follows
## it up and down, the stand's own, and the scenery behind the column
## (ui/flat/scenery.gd).
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
## The bowl's far wall, seen over the lip because the board is looked at a
## little from above, and the lip's own highlight.
const WELL_RY := 9.0
const WELL_Y := 6.0
const LIP_TOP := 3.0
## A fruit in a dish, and how close together three of them stand. The fruit
## sit *in* the bowl: the bowl's front and its lip are a second mesh drawn
## over them (`_dish_front_mesh`), so the bottom of every fruit is hidden
## behind the wood, which PIECE_LIFT sizes -- about a sixth of the seat.
const PIECE := 62.0
const PITCH_MAX := 56.0
const PIECE_LIFT := 28.0
## The pointer: a needle hung from the hub, turning with the beam, over a
## plate on the post with a notch that lights when the beam is level. A lean
## of one is only four degrees of beam, and the needle's tip is what makes
## that readable at a glance.
const NEEDLE_L := 84.0
const NEEDLE_W := 8.0
const PLATE_TOP := 56.0
const PLATE_W := 54.0
const PLATE_H := 50.0
const PLATE_R := 12.0
const PLATE_RIM := 4.0
const MARK_Y := 92.0
const MARK_W := 16.0
const MARK_H := 11.0
const MARK_GLOW := 15.0

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
## The beam swings on a damped spring on the board's own clock rather than a
## tween (Untangle's precedent for a board whose motion is integrated): a
## change can land mid-swing and the beam simply carries its momentum into
## the new target, and a bigger change overshoots by more, which is what
## makes the fruit read as weight. About 20% overshoot, settled in ~0.7 s.
const SWING_K := 150.0
const SWING_C := 11.0
## The dishes on their cords: each tips with the beam's speed (SWAY_GAIN,
## radians per radian a second) on a looser, slower spring, so it leans into
## a swing and rocks back upright after the beam has stopped.
const SWAY_GAIN := 0.06
const SWAY_K := 80.0
const SWAY_C := 5.0
const SWAY_MAX := 0.12
## A swing is over, and snaps to rest, under these.
const REST_ANGLE := 0.0004
const REST_SPEED := 0.004
## How near level the swinging beam has to come before the level moment
## fires: the ring and the notch wait for the beam, not for the arithmetic.
const LEVEL_NEAR := 0.012
const HUB_SPARKLES := 2
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
var _dishes: Array = []                # [i] -> [left, right] Controls, hung from the knot
var _fronts: Array = []                # [i] -> [left, right] the bowl fronts over the fruit
var _marks: Array[Control] = []        # [i] -> the pointer's notch
var _pieces: Array = []                # [i] -> [[Face...], [Face...]]
## The swing, per scale: the beam's angle and speed, the angle it is heading
## for and the one it will head for once `_goal_at` passes (so a reset can
## unwind down the column), and whether it is at rest and costs nothing.
var _ang: Array[float] = []
var _vel: Array[float] = []
var _goal: Array[float] = []
var _next_goal: Array[float] = []
var _goal_at: Array[float] = []
var _resting: Array[bool] = []
## Each dish's own tip on its cords, and its speed: [i * 2 + side].
var _sway: Array[float] = []
var _sway_vel: Array[float] = []
var _level_until: Array[float] = []    # [i] -> seconds the dishes keep beaming to
var _was_level: Array[bool] = []
## The beam has come level in the state and the swing has not got there yet:
## the level moment fires when it does.
var _arriving: Array[bool] = []
var _lit: Array[bool] = []
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
	return tr("BAL_RULES")

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
	# Insane keeps the same five fruit (shapes is already clamped there) and
	# widens the weight range instead, so heavier arithmetic is the challenge.
	var max_w := 12 if difficulty >= 3 else Gen.MAX_W
	state.setup(Gen.generate(rng, shapes, max_w))
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
	_fronts = []
	_marks = []
	_pieces = []
	_ang = []
	_vel = []
	_goal = []
	_next_goal = []
	_goal_at = []
	_resting = []
	_sway = []
	_sway_vel = []
	_level_until = []
	_was_level = []
	_arriving = []
	_lit = []
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

	# Between the stand and the beam, so the needle passes over it.
	var mark := Wood.new()
	mark.name = "Mark"
	lift.add_child(mark)
	_marks.append(mark)

	var beam := Wood.new()
	beam.name = "Beam"
	lift.add_child(beam)
	_beams.append(beam)

	var dishes: Array[Control] = []
	var fronts: Array[Control] = []
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
		# Last, so the bowl's front is drawn over the fruit standing in it.
		var front := Wood.new()
		front.name = "Front"
		dish.add_child(front)
		fronts.append(front)
	_dishes.append(dishes)
	_fronts.append(fronts)
	_pieces.append(pieces)
	_ang.append(0.0)
	_vel.append(0.0)
	_goal.append(0.0)
	_next_goal.append(0.0)
	_goal_at.append(0.0)
	_resting.append(true)
	_sway.append_array([0.0, 0.0])
	_sway_vel.append_array([0.0, 0.0])
	_level_until.append(0.0)
	_was_level.append(state.is_level(i))
	_arriving.append(false)
	_lit.append(state.is_level(i))

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
		var mark: Control = _marks[i]
		mark.position = Vector2(0.0, MARK_Y * _art)
		(mark as Wood).mesh = _mark_mesh(_lit[i])
		var beam: Control = _beams[i]
		beam.pivot_offset = Vector2.ZERO
		(beam as Wood).mesh = _beam_mesh()
		for side in 2:
			var dish: Wood = _dishes[i][side]
			dish.mesh = _dish_mesh()
			(_fronts[i][side] as Wood).mesh = _dish_front_mesh()
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

## Scale `i` as the swing has it now: the beam at its angle, both dishes hung
## from wherever their beam end is and tipped on their cords, and the ground
## told the angle so the shadows follow. The dish hangs from its knot (the
## dish mesh is drawn from the knot down), so its rotation is a tip about
## the knot and the fruit in it ride along.
func _hang(i: int) -> void:
	var a: float = _ang[i]
	_beams[i].rotation = a
	var d := Vector2(cos(a), sin(a)) * ARM * _art
	for side in 2:
		# -1 hangs the left dish, +1 the right.
		var way := -1.0 if side == 0 else 1.0
		var dish: Control = _dishes[i][side]
		dish.position = d * way
		dish.rotation = _sway[i * 2 + side]
	(_grounds[i] as Ground).angle = a

## Every scale hung afresh, whether or not it is swinging: after a layout.
func _place_dishes(_force := false) -> void:
	for i in _beams.size():
		_hang(i)

func _process(delta: float) -> void:
	super(delta)
	_swing(delta)
	_refresh_faces()

## One frame of every swing. A scale at rest is skipped entirely, so a
## settled board costs nothing here. Sub-stepped at 240 Hz so the spring
## stays stable on a slow frame, and a frame is never taken as more than a
## twentieth of a second, so a hitch does not fling the beam.
func _swing(delta: float) -> void:
	var now := _now()
	var dt: float = minf(delta, 0.05)
	var steps: int = maxi(1, ceili(dt * 240.0))
	var h: float = dt / float(steps)
	for i in _ang.size():
		if _goal_at[i] <= now and _goal[i] != _next_goal[i]:
			_goal[i] = _next_goal[i]
			_resting[i] = false
		if _resting[i]:
			continue
		if Motion.reduce:
			_rest(i)
			continue
		for s in steps:
			var acc: float = SWING_K * (_goal[i] - _ang[i]) - SWING_C * _vel[i]
			_vel[i] += acc * h
			_ang[i] += _vel[i] * h
			for side in 2:
				var k := i * 2 + side
				var want: float = clampf(_vel[i] * SWAY_GAIN, -SWAY_MAX, SWAY_MAX)
				_sway_vel[k] += (SWAY_K * (want - _sway[k]) - SWAY_C * _sway_vel[k]) * h
				_sway[k] = clampf(_sway[k] + _sway_vel[k] * h, -SWAY_MAX, SWAY_MAX)
		if _arriving[i] and absf(_ang[i] - _goal[i]) < LEVEL_NEAR:
			_arrive(i)
		var still: bool = absf(_ang[i] - _goal[i]) < REST_ANGLE and absf(_vel[i]) < REST_SPEED
		for side in 2:
			var k := i * 2 + side
			still = still and absf(_sway[k]) < REST_ANGLE and absf(_sway_vel[k]) < REST_SPEED
		if still:
			_rest(i)
		else:
			_hang(i)

## Scale `i` stops where it was going, with its dishes upright.
func _rest(i: int) -> void:
	_ang[i] = _goal[i]
	_vel[i] = 0.0
	for side in 2:
		_sway[i * 2 + side] = 0.0
		_sway_vel[i * 2 + side] = 0.0
	_resting[i] = true
	if _arriving[i]:
		_arrive(i)
	_hang(i)

## Sends scale `i` swinging toward `goal` once `delay` has passed. Under
## reduce motion the swing is not skipped but snapped: the tilt is the state
## itself, so the board still shows the truth, only without moving.
func _aim(i: int, goal: float, delay := 0.0) -> void:
	_next_goal[i] = goal
	_goal_at[i] = _now() + delay
	if delay <= 0.0:
		_goal[i] = goal
	_resting[i] = false
	if Motion.reduce:
		_goal[i] = goal
		_rest(i)

## The beam has swung into level: the fulcrum rings, a glint comes off the
## hub, the notch under the needle lights with a bump, and both dishes beam
## for a moment. This waits for the swing to get there, rather than firing
## on the press, so the eye sees the cause before the praise.
func _arrive(i: int) -> void:
	_arriving[i] = false
	var hub: Vector2 = _scales[i].position
	fx.ring(hub, LEVEL_RING * _art, Pal.LEAF)
	for s in HUB_SPARKLES:
		fx.sparkle(hub + Vector2((randf() - 0.5) * HUB_R * 2.0 * _art, -HUB_R * _art), Pal.SUN)
	_level_until[i] = maxf(_level_until[i], _now() + LEVEL_JOY)
	_light(i, true)
	fx.cue("level")

## The notch under the needle, lit or not. Lighting bumps it; going out is
## quiet, because a beam leaving level is already moving and needs no help.
func _light(i: int, on: bool) -> void:
	if _lit[i] == on:
		return
	_lit[i] = on
	var mark: Wood = _marks[i]
	mark.mesh = _mark_mesh(on)
	if on:
		mark.scale = Vector2.ONE
		Motion.bump(mark)

# --- the tilt ---

## The beam's angle for scale `i`. A positive angle carries +x downward in
## the canvas's y-down space, and the right dish is at +x, so a heavier left
## side needs a negative angle to dip it.
func _tilt_for(i: int) -> float:
	var d: int = clampi(state.lean(i), -TILT_CAP, TILT_CAP)
	return -float(d) / float(TILT_CAP) * TILT_MAX

## Swings every beam to what the current guess says, each after its band's
## share of `per` (a reset unwinds down the column; a step moves them all at
## once). A scale that has just come level is marked as arriving, and its
## level moment fires when the swing gets there (`_arrive`); one that has
## just left level puts its notch out at once.
func _update_scales(per := 0.0) -> void:
	for i in _beams.size():
		var target := _tilt_for(i)
		if target != _next_goal[i]:
			_aim(i, target, Motion.stagger(i, per))
		var level := state.is_level(i)
		if level and not _was_level[i]:
			_arriving[i] = true
			if _resting[i]:
				_arrive(i)
		elif not level:
			_arriving[i] = false
			_light(i, false)
		_was_level[i] = level
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
## already says, and none of them ever reacts to being *correct*. Read off
## where the beam is heading rather than where the spring has it, so an
## overshoot past level does not flash a worried face. A face is only
## written when its look changes, since writing it redraws it.
func _refresh_faces() -> void:
	var now := _now()
	for i in _beams.size():
		var a: float = _next_goal[i]
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
	var dish: Control = _dishes[i][side]
	return _scales[i].position + _lifts[i].position \
		+ dish.position + Vector2(0.0, CORD * _art).rotated(dish.rotation)

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
			_say(tr("BAL_GIVEN"), Face.Expr.HAPPY)
		elif delta < 0:
			_say(tr("BAL_MIN"), Face.Expr.WORRIED)
		else:
			_say(tr("BAL_MAX_12") if state.max_w == 12 else tr("BAL_MAX_9"), Face.Expr.WORRIED)
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
	_say(tr("BAL_HINT"), Face.Expr.HAPPY)
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
	_say(tr("BAL_CLEARED"), Face.Expr.HAPPY)
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
		_next_goal[i] = _tilt_for(i)
		_goal[i] = _next_goal[i]
		_goal_at[i] = 0.0
		_arriving[i] = false
		_rest(i)
		_level_until[i] = INF
		_was_level[i] = true
		_light(i, true)
	_refresh_faces()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return "⚖️ " + tr("BAL_SHARE") % [state.shapes, state.scales.size()]

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
	var line: String = tr("BAL_SAYS_1") if (sc.left as Array).size() == 1 else tr("BAL_SAYS_N")
	return line % [left.substr(0, 1).to_upper() + left.substr(1), _side_words(sc.right)]

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
		parts.append(_counted(i, int(counts[i])))
	if parts.size() == 1:
		return parts[0]
	var last: String = parts.pop_back()
	return tr("BAL_AND") % [", ".join(parts), last]

## "one apple", "three pumpkins", in the player's language: Fruit.counted's
## English, keyed. One and two are per fruit (pt's um/uma and dois/duas agree
## with the noun); three and up put a number word into the fruit's plural.
## Ten and up fall back to the digit, which the generator never reaches.
func _counted(i: int, n: int) -> String:
	var f: int = i % Fruit.count()
	if n == 1:
		return tr("BAL_FRUIT_%d_ONE" % f)
	if n == 2:
		return tr("BAL_FRUIT_%d_TWO" % f)
	var word: String = tr("BAL_NUM_%d" % n) if n < 10 else str(n)
	return tr("BAL_FRUIT_%d_MANY" % f) % word

# --- the win ---

## Every beam is level: the fruit hop in the vocabulary's solve wave, down
## the column and across each dish, with JOY eyes, and sparkles rise over
## each fulcrum as its wave passes. The host brings the win screen in after
## this (win_delay).
func _on_solved() -> void:
	_tip_timer.stop()
	_say(tr("BAL_SOLVED"), Face.Expr.JOY)
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
	return {"faces": faces, "labels": labels, "subtitle": tr("BAL_WIN")}

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
		# Level first, then swung to the weights as they land.
		_next_goal[i] = 0.0
		_goal[i] = 0.0
		_rest(i)
		_aim(i, _tilt_for(i), land + Motion.POP_IN * 0.6)
		_was_level[i] = state.is_level(i)
		_arriving[i] = false
		_light(i, _was_level[i])
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

## The wood's lit face: SCALE_WOOD lifted toward paper, for the strip of
## light along the top of every piece -- the soft cel's one highlight, never
## a specular.
static func _lit_wood(amount := 0.35) -> Color:
	return Pal.SCALE_WOOD.lerp(Pal.PAPER, amount)

## The post with its lit edge, the pointer's plate on it, and the carved base
## in two steps, below the fulcrum.
func _stand_mesh() -> ArrayMesh:
	return _wood("stand", func(b: Face.Builder, k: float) -> void:
		b.fan(Face.Builder.round_rect(Vector2(-POST_W * 0.5, 0.0) * k,
			Vector2(POST_W, POST_H) * k, POST_R * k), Pal.SCALE_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(-POST_W * 0.5 + 5.0, 16.0) * k,
			Vector2(6.0, POST_H - 32.0) * k, 3.0 * k), Color(_lit_wood(0.2), 0.55))
		# The plate: a wood rim round a pale face, low on the post where
		# the needle's tip sweeps.
		b.fan(Face.Builder.round_rect(Vector2(-PLATE_W * 0.5, PLATE_TOP) * k,
			Vector2(PLATE_W, PLATE_H) * k, PLATE_R * k), Pal.SCALE_DARK)
		b.fan(Face.Builder.round_rect(Vector2(-PLATE_W * 0.5 + PLATE_RIM, PLATE_TOP + PLATE_RIM) * k,
			Vector2(PLATE_W - PLATE_RIM * 2.0, PLATE_H - PLATE_RIM * 2.0) * k, (PLATE_R - PLATE_RIM) * k),
			_lit_wood(0.5))
		# The base: a narrow step on a wide plinth, each with its lit top.
		b.fan(Face.Builder.round_rect(Vector2(-BASE_W * 0.5, BASE_Y) * k,
			Vector2(BASE_W, BASE_H) * k, BASE_R * k), Pal.SCALE_DARK)
		b.fan(Face.Builder.round_rect(Vector2(-BASE_W * 0.5 + 10.0, BASE_Y + 3.0) * k,
			Vector2(BASE_W - 20.0, 4.0) * k, 2.0 * k), Color(_lit_wood(0.1), 0.45))
		b.fan(Face.Builder.round_rect(Vector2(-BASE_W * 0.33, BASE_Y - 10.0) * k,
			Vector2(BASE_W * 0.66, 14.0) * k, 7.0 * k), Pal.SCALE_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(-BASE_W * 0.33 + 7.0, BASE_Y - 8.0) * k,
			Vector2(BASE_W * 0.66 - 14.0, 3.5) * k, 1.75 * k), Color(_lit_wood(0.2), 0.5)))

## The notch under the needle's tip: a small caret in faint wood, or in leaf
## green on a soft glow when the beam is level. Its own mesh on its own node,
## so lighting it swaps one mesh and the bump scales it about the notch.
func _mark_mesh(lit: bool) -> ArrayMesh:
	return _wood("mark_lit" if lit else "mark", func(b: Face.Builder, k: float) -> void:
		if lit:
			b.disc(Vector2(0.0, 1.0) * k, MARK_GLOW * k, Color(Pal.LEAF, 0.22))
		b.polygon(PackedVector2Array([Vector2(0.0, -MARK_H * 0.5) * k,
			Vector2(MARK_W * 0.5, MARK_H * 0.5) * k, Vector2(-MARK_W * 0.5, MARK_H * 0.5) * k]),
			Pal.LEAF if lit else Color(Pal.SCALE_DARK, 0.45)))

## The beam, its lit top, its underside shade, the capped ends past the
## knots, the needle hanging under it and the hub it turns on. The needle is
## laid first, so the beam covers its root; the hub's two circles are
## concentric with the fulcrum, so they can live in the turning mesh without
## ever looking turned.
func _beam_mesh() -> ArrayMesh:
	return _wood("beam", func(b: Face.Builder, k: float) -> void:
		b.polygon(PackedVector2Array([Vector2(-NEEDLE_W * 0.5, 0.0) * k,
			Vector2(NEEDLE_W * 0.5, 0.0) * k, Vector2(1.2, NEEDLE_L) * k,
			Vector2(-1.2, NEEDLE_L) * k]), Pal.SCALE_DARK)
		var end := (ARM + BEAM_OVER) * k
		var w := end * 2.0
		b.fan(Face.Builder.round_rect(Vector2(-end, -BEAM_H * 0.5 * k),
			Vector2(w, BEAM_H * k), BEAM_R * k), Pal.SCALE_WOOD)
		b.fan(Face.Builder.round_rect(Vector2(-end, SHADE_Y * k),
			Vector2(w, SHADE_H * k), SHADE_R * k), Color(Pal.SCALE_DEEP, 0.55))
		b.fan(Face.Builder.round_rect(Vector2(-end + 8.0 * k, (-BEAM_H * 0.5 + 3.0) * k),
			Vector2(w - 16.0 * k, 3.5 * k), 1.75 * k), Color(_lit_wood(), 0.8))
		for sx: float in [-1.0, 1.0]:
			var cap_x: float = (ARM + 4.0) * k if sx > 0.0 else -end
			b.fan(Face.Builder.round_rect(Vector2(cap_x, (-BEAM_H * 0.5 - 1.0) * k),
				Vector2((BEAM_OVER - 4.0) * k, (BEAM_H + 2.0) * k), BEAM_R * k), Pal.SCALE_DEEP)
		b.disc(Vector2.ZERO, HUB_R * k, Pal.SCALE_DARK)
		b.disc(Vector2.ZERO, HUB_IN * k, Color(Pal.SCALE_WOOD, 0.9))
		b.disc(Vector2(-2.5, -2.5) * k, HUB_IN * 0.4 * k, Color(_lit_wood(0.6), 0.9)))

## A dish's back, drawn from the knot it hangs from: the cords out to the rim,
## the knot, and the bowl's far wall, which shows over the lip because the
## board is looked at a little from above. The fruit stand on this; the
## front is `_dish_front_mesh`, drawn over them.
func _dish_mesh() -> ArrayMesh:
	return _wood("dish", func(b: Face.Builder, k: float) -> void:
		var ry := CORD * k
		var half := DISH_W * 0.5 * k
		for sx: float in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(sx * DISH_W * CORD_X * k, ry)]),
				CORD_W * k, Color(Pal.SCALE_DARK, 0.8))
		b.disc(Vector2.ZERO, KNOT_R * k, Pal.SCALE_DARK)
		b.disc(Vector2(-1.5, -1.5) * k, KNOT_R * 0.4 * k, Color(_lit_wood(0.3), 0.7))
		b.ellipse(Vector2(0.0, ry - WELL_Y * k), half - 3.0 * k, WELL_RY * k, Pal.SCALE_DARK))

## A dish's front, laid over the fruit: the bowl swung under the rim with a
## band of shade low in it and a glint of light high on its near side, and
## the lip laid over the top with its own lit edge.
func _dish_front_mesh() -> ArrayMesh:
	return _wood("dish_front", func(b: Face.Builder, k: float) -> void:
		var ry := CORD * k
		var half := DISH_W * 0.5 * k
		var deep := DISH_DEEP * k
		# bezier2 includes its start and drops its end, so the rim's right
		# corner comes from the first curve and nothing is doubled --
		# a repeated vertex makes triangulate_polygon hand back nothing.
		var bowl := PackedVector2Array([Vector2(-half, ry)])
		bowl.append_array(Face.Builder.bezier2(Vector2(half, ry),
			Vector2(DISH_W * DISH_CTRL * k, ry + deep), Vector2(0.0, ry + deep)))
		bowl.append_array(Face.Builder.bezier2(Vector2(0.0, ry + deep),
			Vector2(-DISH_W * DISH_CTRL * k, ry + deep), Vector2(-half, ry)))
		b.polygon(bowl, Pal.SCALE_DEEP)
		# The shade: the same curve, shallower, following the bowl's bottom.
		var shade := Face.Builder.bezier2(Vector2(half * 0.72, ry + deep * 0.52),
			Vector2(DISH_W * DISH_CTRL * 0.7 * k, ry + deep * 0.9), Vector2(0.0, ry + deep * 0.9))
		shade.append_array(Face.Builder.bezier2(Vector2(0.0, ry + deep * 0.9),
			Vector2(-DISH_W * DISH_CTRL * 0.7 * k, ry + deep * 0.9), Vector2(-half * 0.72, ry + deep * 0.52)))
		b.stroke(shade, 5.0 * k, Color(Pal.SCALE_DARK, 0.3))
		b.stroke(Face.Builder.bezier2(Vector2(-half * 0.74, ry + 10.0 * k),
			Vector2(-half * 0.6, ry + deep * 0.62), Vector2(-half * 0.3, ry + deep * 0.72)),
			4.0 * k, Color(_lit_wood(0.25), 0.55))
		b.fan(Face.Builder.round_rect(Vector2(-half, ry - LIP_Y * k),
			Vector2(DISH_W * k, LIP_H * k), LIP_R * k), Color(Pal.SCALE_WOOD, 0.97))
		b.fan(Face.Builder.round_rect(Vector2(-half + 8.0 * k, ry - (LIP_Y - 2.0) * k),
			Vector2(DISH_W * k - 16.0 * k, LIP_TOP * k), LIP_TOP * 0.5 * k), Color(_lit_wood(), 0.85)))

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
