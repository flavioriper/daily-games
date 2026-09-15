extends "res://core/puzzle_base_3d.gd"

## Balance on the island stage. A column of stone scales stands on the
## platform, each one a true statement about the shapes in its two pans, and a
## row of plinths at the near edge holds the player's answer: a stack of discs
## per shape, its height the weight, with the same number carved on the pad in
## front of it. Every beam tilts live under the weights the player has guessed
## -- the heavier side dips -- so the board is its own check: when the last
## beam swings level the puzzle is solved. One shape's weight is given and its
## plinth takes no taps; without it the scales would only ever pin down
## ratios, never values.
## Spec: the design agreed in chat on 2026-09-15 (no spec file by request).

const Gen = preload("res://puzzles/balance_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Shapes = preload("res://core/shapes.gd")
const Fx = preload("res://world/fx.gd")

## The board is as wide as a scale needs and no wider: a beam reaches
## SCALE_ARM each way and its pan another PAN_R, which is 2.17 -- inside this
## half-width, with the rim clear of the dish.
const COLS := 5
const HINTS := 3
## A scale's band, in rows: the stand plus the room its pans swing through.
const BAND := 2
## Weight difference at which the beam reaches TILT_MAX. Past three the tilt
## stops growing: the board says "this side is heavier", not by how much, and
## a saturating beam keeps a wildly wrong guess from burying a pan in stone.
const TILT_CAP := 3
const TILT_MAX := 0.26
const TILT_TIME := 0.42
## Room above a fully lifted pan and the token standing in it, so the camera's
## fit never clips an outline.
const FRAME_SLACK := 0.14

# --- motion ---
const DISC_DROP := 0.45
const DISC_TIME := 0.26
const DISC_POP := 0.2
const DIP := 0.025
const DIP_TIME := 0.3
const WOBBLE_ANGLE := 0.1
const WOBBLE_TIME := 0.4
const SOLVE_HOP := 0.1
const SOLVE_TIME := 0.45
const SOLVE_STAGGER := 0.07
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.28
const ENTER_STAGGER := 0.05
const SPARKLE_LIFT := 0.12
const RESET_STAGGER := 0.04

var shapes: int = 3

var _secret: Array = []
var _scales: Array = []
var _anchor: Dictionary = {}
var _guess: Array = []
## Per shape: the weight is fixed and the plinth takes no taps. The anchor
## from the start, plus anything a hint has revealed.
var _locked: Array = []
## One entry per weight change, newest last: {"shape": i, "from": w}. Undo pops one.
var _history: Array[Dictionary] = []

# --- scene ---
var fx: Node3D
var _stands: Array = []       # [i] -> scale_stand model
var _beams: Array = []        # [i] -> the turning node at the fulcrum
var _pans: Array = []         # [i] -> [left, right] counter-turning nodes
var _plinths: Array = []      # [i] -> pivot Node3D at the plinth centre
var _pads: Array = []         # [i] -> plinth model (carries the numerals)
var _stacks: Array = []       # [i] -> Node3D the discs stack under
var _discs: Array = []        # [i] -> Array of disc models, bottom first
# --- tweens ---
var _tilt_tw: Array = []      # [i] per scale
var _dip_tw: Array = []       # [i] per plinth
var _wobble_tw: Array = []    # [i] per plinth
var _disc_tw: Array = []      # [i] the newest disc's drop
var _entrance: Array = []

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "balance"
func title() -> String: return "Balance"

func rules() -> String:
	return "Every scale balances, and one weight is given. Tap a shape's far pad to add a disc, its near pad to take one away. Solve it when every beam sits level."

func board_size() -> Vector2i:
	return Vector2i(COLS, BAND * maxi(_scales.size(), 1) + 2)

## A pan lifted as far as the beam goes, with a token standing in it.
func board_height() -> float:
	return Placeholders.SCALE_POST_H - Placeholders.PAN_DROP + _tilt_rise() \
		+ Placeholders.TOKEN_H + FRAME_SLACK

## Taps land on the plinth pads; nothing else on the board is tappable.
func plane_height() -> float: return Placeholders.PLINTH_H

## Balance is the one board that must be seen from the side. Both of its
## channels are vertical -- the beam tilts, the stack grows -- and at the
## island's own 68 degrees the camera looks almost straight down on them, so a
## six-disc stack projects to the same circle as a one-disc stack and a fully
## tilted beam barely shifts. At this pitch the scales read as scales, and a
## plinth's two pads are still a cell apart on screen.
func board_pitch() -> float: return 44.0
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

## How far a beam end rises or falls at full tilt.
func _tilt_rise() -> float:
	return Placeholders.SCALE_ARM * sin(TILT_MAX)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	# Three, four then five shapes. The scale count follows from the shape
	# count rather than being asked for: the generator trims every scale the
	# others already imply, and with the anchor pinning one shape, `shapes - 1`
	# independent scales is exactly what a unique board needs -- a further one
	# would be redundant and the trim would delete it again.
	shapes = clampi(3 + difficulty, 3, 5)
	var out: Dictionary = Gen.generate(rng, shapes)
	_secret = out.secret
	_scales = out.scales
	_anchor = out.anchor
	_guess = []
	_locked = []
	for i in shapes:
		var anchored := i == int(_anchor.shape)
		_guess.append(int(_anchor.value) if anchored else 1)
		_locked.append(anchored)
	_history = []
	_build_scene()
	_refit()
	_enter()

## Every unlocked shape falls back to one, disc by disc from the left. Hints
## already spent stay spent, and the weights they revealed stay locked.
func reset_board() -> void:
	_stop_entrance()
	for i in shapes:
		_settle(i)
		if _locked[i]:
			continue
		_guess[i] = 1
		_restack(i, Motion.stagger(i, RESET_STAGGER))
	_history = []
	_running = true
	moves = 0
	_update_scales(true)
	fx.cue("reset")

func is_solved() -> bool:
	return _guess == _secret

func share_glyphs() -> String:
	return "⚖️ %d shapes · %d scales" % [shapes, _scales.size()]

# --- capabilities ---

## No check: every beam already answers that question, every frame. Reading
## the board is the whole puzzle, so a button that reads it for you would be
## the puzzle.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _open() -> bool:
	return not is_done()

func can_undo() -> bool:
	return _open() and not _history.is_empty()

func undo() -> bool:
	if not _open() or _history.is_empty():
		return false
	var last: Dictionary = _history.pop_back()
	var i := int(last.shape)
	_guess[i] = int(last.from)
	_restack(i)
	_update_scales(true)
	fx.cue("undo")
	moved.emit()
	check_solved()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Reveals one shape's true weight: its stack rebuilds to the answer with a
## sparkle and its plinth locks, so the rest of the board has one more fixed
## point to reason from. Prefers a shape the player currently has wrong --
## revealing one already correct would teach nothing. Counts no move.
func hint() -> bool:
	if not _open() or hints_left() <= 0:
		return false
	var pick := -1
	for i in shapes:
		if not _locked[i] and _guess[i] != _secret[i]:
			pick = i
			break
	if pick < 0:
		for i in shapes:
			if not _locked[i]:
				pick = i
				break
	if pick < 0:
		return false
	_locked[pick] = true
	_guess[pick] = int(_secret[pick])
	var kept: Array[Dictionary] = []
	for h in _history:
		if int(h.shape) != pick:
			kept.append(h)
	_history = kept
	_restack(pick)
	_paint_plinth(pick)
	_update_scales(true)
	fx.sparkle(_plinth_at(pick, Placeholders.PLINTH_H + SPARKLE_LIFT))
	hints_used += 1
	fx.cue("hint")
	moved.emit()
	check_solved()
	return true

# --- geometry ---

## Board-space centre of scale `i`'s band: the stand stands here.
func _scale_at(i: int) -> Vector3:
	var size := board_size()
	var o := BoardMath.cell_origin(size.x, size.y)
	return Vector3(0.0, 0.0, o.z + (BAND * i + 1) * BoardMath.CELL)

## The plinth row's centre line: the seam between the last two rows, so the
## far pad covers one whole cell and the near pad the other.
func _plinth_z() -> float:
	var size := board_size()
	var o := BoardMath.cell_origin(size.x, size.y)
	return o.z + (size.y - 1) * BoardMath.CELL

## Plinths share the board's width evenly, whatever the shape count.
func _plinth_span() -> float:
	return float(COLS) / float(shapes)

func _plinth_at(i: int, y: float) -> Vector3:
	return Vector3(-COLS * 0.5 + (i + 0.5) * _plinth_span(), y, _plinth_z())

# --- the scales ---

## What scale `i` reads under the player's current guess: right total minus
## left, so a positive number means the right pan is heavier.
func _diff(i: int) -> int:
	var sc: Dictionary = _scales[i]
	return _side_total(sc.right) - _side_total(sc.left)

func _side_total(side: Array) -> int:
	var t := 0
	for s in side:
		t += int(_guess[int(s)])
	return t

## The beam's angle for scale `i`. Rotating about +Z by a positive angle
## carries +X upward, and the right pan is at +X, so a heavier right side
## needs a negative angle to dip it.
func _tilt_for(i: int) -> float:
	var d := clampi(_diff(i), -TILT_CAP, TILT_CAP)
	return -float(d) / float(TILT_CAP) * TILT_MAX

## Swings every beam to what the current guess says, and greens the fulcrum
## cap of each scale that now balances. The tilt is the state itself, not
## decoration, so it is essential and survives reduce-motion shortened.
func _update_scales(animate: bool) -> void:
	for i in _scales.size():
		var pivot: Node3D = _beams[i]
		var target := _tilt_for(i)
		Motion.stop(_tilt_tw[i])
		_tilt_tw[i] = null
		if animate:
			_tilt_tw[i] = Motion.settle(pivot, "rotation:z", target, TILT_TIME, 0.0, true)
		if _tilt_tw[i] == null:
			pivot.rotation.z = target
		Models.tint_named(_stands[i], "Cap", Pal.GOOD if _diff(i) == 0 else Pal.STEEL_HI)

## The pans hang from the beam's ends but must stay level, the way a real
## scale's do, so each counter-turns by whatever its beam is doing. Driven per
## frame rather than tweened alongside the beam: the beam's own tween can be
## stopped and replaced mid-swing, and a second tween chasing it would drift.
func _process(delta: float) -> void:
	super(delta)
	for i in _beams.size():
		var angle: float = (_beams[i] as Node3D).rotation.z
		for pan in _pans[i]:
			(pan as Node3D).rotation.z = -angle

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for group in [_tilt_tw, _dip_tw, _wobble_tw, _disc_tw]:
		for tw in group:
			Motion.stop(tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_stands = []
	_beams = []
	_pans = []
	_plinths = []
	_pads = []
	_stacks = []
	_discs = []
	_tilt_tw = []
	_dip_tw = []
	_wobble_tw = []
	_disc_tw = []

	var size := board_size()
	board.add_child(Platform.build(size.x, size.y))
	fx = Fx.new()
	board.add_child(fx)

	for i in _scales.size():
		_build_scale(i)
	for i in shapes:
		_build_plinth(i)
	_update_scales(false)

## One scale: the stand, the beam turning on its fulcrum cap, and a pan under
## each beam end holding that side's tokens. Both the beam and the pans are
## modelled base-at-origin like every other slot, so each hangs at a negative
## offset under the node that carries its true pivot.
func _build_scale(i: int) -> void:
	var sc: Dictionary = _scales[i]
	var root := Node3D.new()
	root.name = "scale_%d" % i
	root.position = _scale_at(i)
	board.add_child(root)

	var stand := Models.instance("scale_stand")
	root.add_child(stand)
	_stands.append(stand)

	var pivot := Node3D.new()
	pivot.name = "beam"
	pivot.position.y = Placeholders.SCALE_POST_H
	root.add_child(pivot)
	_beams.append(pivot)

	var beam := Models.instance("scale_beam")
	beam.position.y = -Placeholders.BEAM_HUB_R
	pivot.add_child(beam)

	var pans: Array = []
	for side in [-1, 1]:
		var hang := Node3D.new()
		hang.name = "hang_%s" % ("l" if side < 0 else "r")
		hang.position.x = side * Placeholders.SCALE_ARM
		pivot.add_child(hang)
		# Counter-turns in _process so the dish stays level under the tilt.
		var level := Node3D.new()
		level.name = "level"
		hang.add_child(level)
		pans.append(level)
		var pan := Models.instance("scale_pan")
		pan.position.y = -Placeholders.PAN_DROP
		level.add_child(pan)
		_place_tokens(pan, sc.left if side < 0 else sc.right)
	_pans.append(pans)
	_tilt_tw.append(null)

## The shapes resting in one pan, in a row across the dish. Three is the most
## the generator ever puts on a side, so they never need a second rank.
func _place_tokens(pan: Node3D, side: Array) -> void:
	var n := side.size()
	for k in n:
		var idx := int(side[k])
		var token := Models.instance(Models.TOKENS[idx % Models.TOKENS.size()])
		token.name = "token_%d" % k
		token.position = Vector3((k - (n - 1) * 0.5) * Placeholders.TOKEN_GAP,
			Placeholders.PAN_LIP, 0.0)
		Models.tint_named(token, "Token", Pal.CAT[idx % Pal.CAT.size()])
		pan.add_child(token)

## One plinth: two pads, the far one carrying the disc stack, the near one the
## numeral, plus the shape's own token standing on the near pad so the player
## can tell at a glance which shape this stack is for.
func _build_plinth(i: int) -> void:
	var pivot := Node3D.new()
	pivot.name = "plinth_%d" % i
	pivot.position = _plinth_at(i, 0.0)
	board.add_child(pivot)
	_plinths.append(pivot)

	var pad := Models.instance("plinth")
	pivot.add_child(pad)
	_pads.append(pad)

	var token := Models.instance(Models.TOKENS[i % Models.TOKENS.size()])
	token.name = "shape"
	# Beside the numeral on the near pad, clear of the digit's bars.
	token.position = Vector3(-Placeholders.NUM_W * 0.5 - Placeholders.TOKEN_R - 0.09,
		Placeholders.PLINTH_H, Placeholders.PLINTH_HALF)
	Models.tint_named(token, "Token", Pal.CAT[i % Pal.CAT.size()])
	pivot.add_child(token)

	var stack := Node3D.new()
	stack.name = "stack"
	stack.position = Vector3(0.0, Placeholders.PLINTH_H, -Placeholders.PLINTH_HALF)
	pivot.add_child(stack)
	_stacks.append(stack)
	_discs.append([])
	_dip_tw.append(null)
	_wobble_tw.append(null)
	_disc_tw.append(null)
	_restack(i)
	_paint_plinth(i)

## Where disc `k` rests in a stack, counting from the pad.
func _disc_y(k: int) -> float:
	return k * (Placeholders.DISC_H + Placeholders.DISC_GAP)

## Rebuilds shape `i`'s stack to its current weight at once, no drop: used by
## reset, undo and hint, where several discs change together.
func _restack(i: int, delay := 0.0) -> void:
	Motion.stop(_disc_tw[i])
	_disc_tw[i] = null
	for disc in _discs[i]:
		(disc as Node3D).queue_free()
	_discs[i] = []
	for k in int(_guess[i]):
		var disc := _make_disc(i, k)
		if delay > 0.0:
			disc.scale = Vector3.ONE * 0.01
			var pop: Tween = Motion.settle(disc, "scale", Vector3.ONE, DISC_POP,
				delay + Motion.stagger(k, 0.02))
			if pop == null:
				disc.scale = Vector3.ONE
	_paint_plinth(i)

func _make_disc(i: int, k: int) -> Node3D:
	var disc := Models.instance("weight_disc")
	disc.name = "disc_%d" % k
	disc.position.y = _disc_y(k)
	Models.tint_named(disc, "Disc", Pal.CAT[i % Pal.CAT.size()])
	_stacks[i].add_child(disc)
	_discs[i].append(disc)
	return disc

## Shows the numeral matching the weight and tints the pad by whether the
## player may still change it. A locked plinth reads as given: darker stone,
## dimmed numeral, the same language the other boards use for a fixed cell.
func _paint_plinth(i: int) -> void:
	var pad: Node3D = _pads[i]
	var w := int(_guess[i])
	for d in range(1, 10):
		Models.set_layer_visible(pad, "Plinth_Num_%d" % d, d == w)
	Models.tint_named(pad, "Stone", Pal.STONE_GIVEN if _locked[i] else Pal.STONE)
	Models.tint_named(pad, "Num_flat", Pal.TEXT_DIM if _locked[i] else Pal.SLATE)

# --- changing a weight ---

## Adds one disc to shape `i`, or refuses at the top of the range with a
## wobble. The new disc drops onto the stack; the beams follow it.
func _add(i: int) -> void:
	if int(_guess[i]) >= Gen.MAX_W:
		_wobble(i)
		fx.cue("full")
		return
	_history.append({"shape": i, "from": int(_guess[i])})
	_guess[i] = int(_guess[i]) + 1
	var k := int(_guess[i]) - 1
	var disc := _make_disc(i, k)
	disc.position.y = _disc_y(k) + DISC_DROP
	Motion.stop(_disc_tw[i])
	_disc_tw[i] = Motion.settle(disc, "position:y", _disc_y(k), DISC_TIME, 0.0, true)
	_paint_plinth(i)
	_update_scales(true)
	fx.cue("add")
	note_move()

## Takes the top disc off shape `i`, or refuses at one -- a shape always
## weighs something, so an empty stack is never a state the board can show.
func _remove(i: int) -> void:
	if int(_guess[i]) <= 1:
		_wobble(i)
		fx.cue("empty")
		return
	_history.append({"shape": i, "from": int(_guess[i])})
	_guess[i] = int(_guess[i]) - 1
	var disc: Node3D = (_discs[i] as Array).pop_back()
	Motion.stop(_disc_tw[i])
	_disc_tw[i] = null
	# The tween is left untracked on purpose: the stack has already forgotten
	# the disc, and the tween is bound to it, so it dies with the node and its
	# own `finished` is what frees it.
	var away: Tween = Motion.vanish(disc, DISC_POP, DISC_TIME)
	if away == null:
		disc.queue_free()
	else:
		away.finished.connect(disc.queue_free)
	_paint_plinth(i)
	_update_scales(true)
	fx.cue("remove")
	note_move()

func _dip(i: int) -> void:
	Motion.stop(_dip_tw[i])
	(_plinths[i] as Node3D).position.y = 0.0
	_dip_tw[i] = Motion.hop(_plinths[i], -DIP, DIP_TIME, 0.0, 0.0)

func _wobble(i: int) -> void:
	Motion.stop(_wobble_tw[i])
	(_plinths[i] as Node3D).rotation.z = 0.0
	_wobble_tw[i] = Motion.wobble(_plinths[i], WOBBLE_ANGLE, WOBBLE_TIME)

func _settle(i: int) -> void:
	Motion.stop(_dip_tw[i])
	Motion.stop(_wobble_tw[i])
	_dip_tw[i] = null
	_wobble_tw[i] = null
	var pivot: Node3D = _plinths[i]
	pivot.position.y = 0.0
	pivot.rotation.z = 0.0

# --- entrance, solve ---

## The board arrives: the platform rises and rings the water, then the scales
## pop in from the far edge with the plinths last, so the eye lands on the
## statements before the answer row.
func _enter() -> void:
	_stop_entrance()
	var platform: Node3D = board.get_node("Platform")
	platform.position.y = -ENTER_DROP
	var rise: Tween = Motion.settle(platform, "position:y", 0.0, ENTER_PLATFORM)
	if rise != null:
		_entrance.append(rise)
		var splash := board.create_tween()
		splash.tween_interval(ENTER_PLATFORM * 0.9)
		splash.tween_callback(_splash)
		_entrance.append(splash)
	var step := 0
	for i in _scales.size():
		_pop_in(_stands[i].get_parent(), ENTER_PLATFORM + Motion.stagger(step, ENTER_STAGGER))
		step += 1
	for i in shapes:
		_pop_in(_plinths[i], ENTER_PLATFORM + Motion.stagger(step + i, ENTER_STAGGER))
	fx.cue("enter")

func _pop_in(node: Node3D, delay: float) -> void:
	node.scale = Vector3.ONE * 0.01
	var pop: Tween = Motion.settle(node, "scale", Vector3.ONE, ENTER_POP, delay)
	if pop != null:
		_entrance.append(pop)
	else:
		node.scale = Vector3.ONE

func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	if _plinths.is_empty():
		return
	var platform: Node3D = board.get_node_or_null("Platform")
	if platform != null:
		platform.position.y = 0.0
	for stand in _stands:
		(stand as Node3D).get_parent().scale = Vector3.ONE
	for pivot in _plinths:
		(pivot as Node3D).scale = Vector3.ONE

func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## Every beam is level: the plinths hop in a wave from the left and each
## fulcrum sparkles, since the caps are already green.
func _on_solved() -> void:
	for i in shapes:
		_settle(i)
		Motion.stop(_dip_tw[i])
		_dip_tw[i] = Motion.hop(_plinths[i], SOLVE_HOP, SOLVE_TIME,
			Motion.stagger(i, SOLVE_STAGGER), 0.0)
	for i in _scales.size():
		fx.sparkle(_scale_at(i) + Vector3(0.0, Placeholders.SCALE_POST_H + SPARKLE_LIFT, 0.0))
	fx.cue("solved")

# --- input ---

## The plinth row is the only live surface. A tap on a shape's far pad adds a
## disc, on its near pad takes one away; a locked shape only dips, the way a
## given cell does on the other boards.
func on_board_press(hit: Vector3) -> void:
	var span := _plinth_span()
	var i := floori((hit.x + COLS * 0.5) / span)
	if i < 0 or i >= shapes:
		return
	var seam := _plinth_z()
	if hit.z < seam - BoardMath.CELL or hit.z > seam + BoardMath.CELL:
		return
	if not _open() or _locked[i]:
		_dip(i)
		fx.cue("focus")
		return
	_settle(i)
	if hit.z < seam:
		_add(i)
	else:
		_remove(i)

## Control-local point over the centre of shape `i`'s far (adding) pad and
## near (removing) pad. The win harness drives the board through these.
func pad_to_local(i: int, add: bool) -> Vector2:
	var at := _plinth_at(i, plane_height())
	at.z += (-0.5 if add else 0.5) * BoardMath.CELL
	return board_to_local(at)
