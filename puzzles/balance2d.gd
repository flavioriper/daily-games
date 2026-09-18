extends "res://core/puzzle_base.gd"

## Balance as a flat board: a column of wooden scales on the host's parchment
## card, each one a true statement about the fruit in its two dishes, with
## the player's answer in the weight cards under the board
## (ui/flat/weight_tray.gd). Built beside the island version
## (puzzles/balance3d.gd) so the two can be judged against each other on the
## phone; the rules live in puzzles/balance_state.gd, which this only draws.
##
## Every beam tilts live under the weights the player has guessed -- the
## heavier dish dips -- so **the board is its own check**: when the last beam
## swings level the puzzle is solved. That is why `capabilities()` has no
## "check" and why this screen has no actions row at all: a button that read
## the board for you would be the puzzle. Reset lives in the top bar
## instead, which is this screen's one structural departure from the other
## two flat boards (spec section 5).
##
## This is the board the flat view should win on most clearly: a tilt is an
## angle, and an angle read through the island's seven-degree camera is an
## angle plus a lie.
##
## The wood is drawn as **cached meshes, not canvas commands**: gl_compatibility
## pays per draw command, so a scale is three draw_mesh calls (stand, beam,
## dish) rather than a dozen rounded rectangles, and every scale of a size
## shares them. Filled shapes get the Builder's feather, since MSAA stays off
## for the 2D canvas.
## Spec: docs/superpowers/specs/2026-09-18-balance-flat-design.md, sections 2
## to 6, ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#balance).

const Gen = preload("res://puzzles/balance_gen.gd")
const State = preload("res://puzzles/balance_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Fruit = preload("res://ui/faces/fruit.gd")

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
## The dish on its cords.
const DISH_W := 176.0
const CORD := 54.0
const CORD_X := 0.42
const CORD_W := 5.0
const DISH_DEEP := 34.0
const DISH_CTRL := 0.4
const LIP_Y := 7.0
const LIP_H := 12.0
const LIP_R := 6.0
## A fruit in a dish, and how close together three of them stand.
const PIECE := 62.0
const PITCH_MAX := 56.0
const PIECE_LIFT := 12.0

## Weight difference at which the beam reaches TILT_MAX. Past three the tilt
## stops growing: the board says "this dish is heavier", never by how much,
## which is what keeps a wildly wrong guess from burying a dish in the card.
const TILT_CAP := 3
const TILT_MAX := 0.22
const TILT_TIME := 0.42
## Hint count, not refunded by reset (HUD spec, section 3).
const HINTS := 3

# --- motion (spec section 6) ---
const ENTER_DELAY := 0.15
const ENTER_STAGGER := 0.08
const ENTER_TIME := 0.35
const ENTER_DROP := 40.0
const RING_R0 := 40.0
const RING_GROW := 130.0
const RING_TIME := 0.55
## How long both dishes keep their happy face after a beam comes level.
const LEVEL_JOY := 0.9
const SOLVE_HOP := -12.0
const SOLVE_TIME := 0.42
const SOLVE_DELAY := 0.1
const SOLVE_STAGGER := 0.12
const SOLVE_PIECE := 0.05
const SOLVE_SPARKLES := 3
const RESET_STAGGER := 0.05
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
var _stands: Array[Control] = []       # [i] -> the post and base mesh
var _beams: Array[Control] = []        # [i] -> the turning node
var _dishes: Array = []                # [i] -> [left, right] Controls, always level
var _pieces: Array = []                # [i] -> [[Face...], [Face...]]
var _tilt_tw: Array = []               # [i]
var _level_until: Array[float] = []    # [i] -> msec the dishes keep beaming to
var _was_level: Array[bool] = []
var _entrance: Array[Tween] = []

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
	_stands = []
	_beams = []
	_dishes = []
	_pieces = []
	_tilt_tw = []
	_level_until = []
	_was_level = []
	for i in state.scales.size():
		_build_scale(i)

## One scale: the stand under the fulcrum, the beam turning on it, and a dish
## hanging from each beam end with that side's fruit standing in it.
##
## Two nodes deep on purpose. The **root** is where the layout puts the
## fulcrum, and only the layout ever writes it; the **lift** is what the
## entrance slides, and only the entrance ever writes that. Animating the
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
			dish.add_child(face)
			row.append(face)
			face.set_idle(true)
		pieces.append(row)
	_dishes.append(dishes)
	_pieces.append(pieces)
	_tilt_tw.append(null)
	_level_until.append(0.0)
	_was_level.append(state.is_level(i))

## Places everything from the card's current size: the band height, the art
## scale that follows from it, and every scale's meshes and dishes.
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
		(_stands[i] as Wood).mesh = _stand_mesh()
		var beam: Control = _beams[i]
		beam.pivot_offset = Vector2.ZERO
		(beam as Wood).mesh = _beam_mesh()
		for side in 2:
			var dish: Wood = _dishes[i][side]
			dish.mesh = _dish_mesh()
			_fit_pieces(i, side)
	_place_dishes()

func _pivot_y(i: int) -> float:
	return PAD + float(i) * _band + _band * 0.5 - PIVOT_LIFT * _art

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

## Both dishes of every scale, hung from wherever their beam end now is.
## Driven per frame rather than tweened alongside the beam: the beam's own
## tween can be stopped and replaced mid-swing, and a second tween chasing
## it would drift -- the island board's reason for doing the same.
func _place_dishes() -> void:
	for i in _beams.size():
		var a: float = _beams[i].rotation
		var reach := ARM * _art
		var d := Vector2(cos(a), sin(a)) * reach
		for side in 2:
			# -1 hangs the left dish, +1 the right.
			var way := -1.0 if side == 0 else 1.0
			(_dishes[i][side] as Control).position = d * way

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

## Swings every beam to what the current guess says, and rings the fulcrum of
## any scale that has just come level. The tilt is the state itself and not
## decoration, so under reduce-motion it snaps rather than being skipped:
## Motion.slide sets the angle and returns null, which is the board showing
## the truth without moving.
func _update_scales() -> void:
	for i in _beams.size():
		var beam: Control = _beams[i]
		var target := _tilt_for(i)
		Motion.stop(_tilt_tw[i])
		_tilt_tw[i] = Motion.slide(beam, "rotation", beam.rotation, target, TILT_TIME)
		var level := state.is_level(i)
		if level and not _was_level[i]:
			_ring(i)
			_level_until[i] = _now() + LEVEL_JOY
			fx.cue("level")
		_was_level[i] = level
	_place_dishes()
	_refresh_faces()

## A ring pulses out of the fulcrum of a scale that has just come level.
func _ring(i: int) -> void:
	if Motion.reduce:
		return
	var ring := Ring.new()
	ring.art = _art
	_scales[i].add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "t", 1.0, RING_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ring.queue_free)

## What every fruit should be showing: both dishes of a scale that just came
## level beam for a moment, the low dish's fruit look strained, and the high
## dish's rides up content. Nothing is hidden on this board -- the beams are
## the whole information channel -- so a face may say whatever the beam
## already says, and none of them ever reacts to being *correct*.
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
	fx.cue("step")
	_after_change()
	note_move()
	return true

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Puts the last weight back and re-settles the beams. Counts no move.
func undo() -> bool:
	if is_done() or state.undo().is_empty():
		return false
	_update_scales()
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
	var i := state.apply_hint()
	if i < 0:
		return false
	hints_used += 1
	_update_scales()
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
## unwinds from the left rather than snapping: each beam's swing is staggered
## by its band, so the eye follows the change down the board.
func reset_board() -> void:
	if is_done():
		return
	_stop_entrance()
	state.reset()
	moves = 0
	_running = true
	for i in _beams.size():
		var beam: Control = _beams[i]
		Motion.stop(_tilt_tw[i])
		_tilt_tw[i] = Motion.slide(beam, "rotation", beam.rotation, _tilt_for(i),
			TILT_TIME, Motion.stagger(i, RESET_STAGGER))
		_was_level[i] = state.is_level(i)
	_say("Back to one each. Start from the scales.", Face.Expr.HAPPY)
	fx.cue("reset")

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

## Every beam is level: the fruit hop in a wave down the column, each dish a
## beat after the one above it, with sparkles over every fulcrum. The host
## brings the win screen in after this wave (win_delay).
func _on_solved() -> void:
	_tip_timer.stop()
	_say("Everything sits level. Beautifully weighed.", Face.Expr.JOY)
	for i in _beams.size():
		_level_until[i] = _now() + INF
		var delay: float = SOLVE_DELAY + Motion.stagger(i, SOLVE_STAGGER, 1.0)
		for side in 2:
			var row: Array = _pieces[i][side]
			for q in row.size():
				var face: Control = row[q]
				Motion.hop(face, SOLVE_HOP * _art, SOLVE_TIME,
					delay + float(q) * SOLVE_PIECE, face.position.y)
		for k in SOLVE_SPARKLES:
			fx.sparkle(_scales[i].position + Vector2((randf() - 0.5) * ARM * _art, 0.0), Pal.SUN)
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

# --- entrance ---

## The board arrives: the scales drop in from the top down, one band per
## ENTER_STAGGER, each beam already swung to the angle its guess asks for.
func _enter() -> void:
	_stop_entrance()
	for i in _scales.size():
		var root: Control = _scales[i]
		var delay := ENTER_DELAY + Motion.stagger(i, ENTER_STAGGER, 1.0)
		# The drop is on the lift, in the root's own space, so it says nothing
		# about where the band sits and the layout stays free to move it.
		var drop: Tween = Motion.slide(_lifts[i], "position:y", -ENTER_DROP, 0.0, ENTER_TIME, delay)
		if drop != null:
			_entrance.append(drop)
		var fade: Tween = Motion.appear(root, 0.0, 1.0, ENTER_TIME, delay)
		if fade != null:
			_entrance.append(fade)
		var beam: Control = _beams[i]
		Motion.stop(_tilt_tw[i])
		_tilt_tw[i] = Motion.slide(beam, "rotation", 0.0, _tilt_for(i), TILT_TIME, delay)
		_was_level[i] = state.is_level(i)
	fx.cue("enter")

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for i in _scales.size():
		_lifts[i].position.y = 0.0
		_scales[i].modulate.a = 1.0

func _stop_all() -> void:
	_stop_entrance()
	for tw in _tilt_tw:
		Motion.stop(tw)

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
## out to the rim, the bowl swung under them, and the rim laid over the top.
func _dish_mesh() -> ArrayMesh:
	return _wood("dish", func(b: Face.Builder, k: float) -> void:
		var ry := CORD * k
		var half := DISH_W * 0.5 * k
		for sx: float in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(sx * DISH_W * CORD_X * k, ry)]),
				CORD_W * k, Color(Pal.SCALE_DARK, 0.8))
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

## The pulse that leaves a fulcrum the moment its beam comes level.
class Ring extends Control:
	var art := 1.0
	var t := 0.0:
		set(v):
			t = v
			queue_redraw()

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(Vector2.ZERO, (RING_R0 + RING_GROW * t) * art, 0.0, TAU, 48,
			Color(Pal.LEAF, 0.8 * (1.0 - t)), 6.0 * art, true)
