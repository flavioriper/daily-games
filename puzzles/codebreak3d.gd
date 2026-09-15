extends "res://core/puzzle_base_3d.gd"

## Code Break on the island stage. Eight guess rows of socket slabs stand on
## a plank dock under a shielded code row: the code's pegs sit hidden under
## stone lids on row 0 and the guesses fill rows 1 to 8 from the far edge
## toward the player. A colour picked on the HUD's tray drops a peg into the
## first empty slot of the active row; a tap on a placed peg pops it out;
## Check scores the row on its feedback slab -- a slate pip per right colour
## in the right place, a cream pip per right colour in the wrong place -- and
## the next row takes the lighter tint and starts to breathe. When the game
## ends the lids slide off the far edge into the river. Every peg is a tinted
## dome carrying one of seven pip marks, so colour never stands alone.
## Spec: docs/superpowers/specs/2026-09-14-codebreak-3d-design.md,
## docs/superpowers/specs/2026-09-15-codebreak-screen-design.md for the dock
## and scenery.

const Gen = preload("res://puzzles/mastermind_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://world/fx.gd")
const Stage = preload("res://world/stage.gd")
const CodebreakScenery = preload("res://puzzles/codebreak_scenery.gd")

const CODE_ROW := 0
const HINTS := 3
const MARKS := 7
const PIP_GAP := 0.26
## Tints (spec section 1): the socket blend runs 0 (STONE, active) to 1
## (STONE_GIVEN, resting) on an 8-step grid.
const ROW_FADE := 0.3
const ROW_STEPS := 8
const MARK_SHADE := 0.35
## Motion (spec section 4).
const BREATH_RISE := 0.02
const BREATH_PERIOD := 2.4
const PLACE_DROP := 0.5
const PLACE_TIME := 0.3
const POP_LIFT := 0.25
const POP_TIME := 0.22
const NUDGE_HOP := 0.05
const NUDGE_TIME := 0.25
const DIP := 0.02
const DIP_TIME := 0.35
const COMMIT_DIP := 0.03
const BALL_POP := 0.25
const BALL_STAGGER := 0.06
const WOBBLE_ANGLE := 0.1
const WOBBLE_TIME := 0.4
const LID_SLIDE := 2.7
const LID_SLIDE_TIME := 0.4
## Deck top to the river's surface: a lid that slides off falls this far.
const RIVER_DROP := 1.4
const LID_FALL := RIVER_DROP
## Where the entrance splash rings the river, in board space.
const SPLASH_AT := Vector3(0.0, 0.0, -7.0)
const LID_FALL_TIME := 0.5
const LID_STAGGER := 0.12
const LID_DROP := 0.6
const LID_DROP_TIME := 0.45
const LID_RETURN_STAGGER := 0.06
const SOLVE_HOP := 0.08
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.05
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.02
const ENTER_LIDS := 0.3
const RESET_STAGGER := 0.02
const SPARKLE_LIFT := 0.1
const LOCKED_STAGGER := 0.05
## Room the camera's fit leaves above a seated peg, so its outline is never
## clipped by the top of the board's frame (spec section 1, Camera).
const FRAME_SLACK := 0.04

var length: int = 4
var palette_size: int = 6
var max_guesses: int = 8

var _code: Array = []
var _guesses: Array = []
var _marks: Array = []
var _row: Array = []          # the active row's colours, -1 empty
var _locked: Array = []       # per slot: filled by a hint, fixed for the game
var _revealed := false
## Places and pops in the active row, newest last; undo pops one.
var _history: Array[Dictionary] = []

# --- scene ---
var fx: Node3D                # pooled one-shot particles, a child of the board
var _pivots: Array = []       # [g][s] -> Node3D at the cell centre: dips, wobbles
var _breaths: Array = []      # [g][s] -> Node3D under the pivot: the active row's rise
var _sockets: Array = []      # [g][s] -> socket model
var _pegs: Array = []         # [g][s] -> peg model or null
var _feedback: Array = []     # [g] -> feedback slab
var _pips: Array = []         # [g][k] -> pip model on the slab
var _lids: Array = []         # [s] -> lid over code slot s
var _lid_gone: Array = []     # [s] -> true once the lid has slid off
var _code_pegs: Array = []    # [s] -> the code peg, hidden until revealed
# --- tweens ---
var _dips: Array = []         # [g][s]
var _wobbles: Array = []      # [g][s]
var _peg_tw: Array = []       # [g][s] the peg's drop, hop or nudge
var _breath_tw: Array = []    # [g][s]
var _fades: Array = []        # [g][s] socket tint fade
var _blend: Array = []        # [g][s] painted blend, 0 active .. 1 resting
var _pip_tw: Array = []       # [g][k]
var _lid_tw: Array = []       # [s]
var _code_tw: Array = []      # [s]
var _entrance: Array = []     # the board entrance, killed by reset

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "mastermind"
func title() -> String: return "Code Break"

func rules() -> String:
	var count := "five" if length == 5 else "four"
	return "Crack the hidden row of %s colours. Fill a row from the tray and press Check. A slate pip is a right colour in the right place, a cream pip a right colour in the wrong place." % count

func board_size() -> Vector2i: return Vector2i(length + 1, max_guesses + 1)
## A socket with a peg on it; nothing stands higher at rest. A placed peg
## drops from PLACE_DROP above, which the camera's margin absorbs.
func board_height() -> float: return Placeholders.PEG_SEAT + Placeholders.PEG_H + FRAME_SLACK
func plane_height() -> float: return Placeholders.SOCKET_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var repeats := true
	match difficulty:
		0: length = 4; palette_size = 6; repeats = false
		1: length = 4; palette_size = 6; repeats = true
		_: length = 5; palette_size = 7; repeats = true
	max_guesses = 8
	_code = Gen.make_code(rng, length, palette_size, repeats)
	_guesses = []
	_marks = []
	_revealed = false
	_history = []
	_row = []
	_locked = []
	for s in length:
		_row.append(-1)
		_locked.append(false)
	_build_scene()
	_activate_row(0, true)
	_refit()
	_enter()

## Reset as a wave: every peg in a guess row vanishes from the far row to the
## near one, the pips hide, any lid that slid off drops back, and the first
## row takes the active tint again. Hints already used stay used.
func reset_board() -> void:
	_stop_entrance()
	for g in max_guesses:
		for s in length:
			_settle(g, s)
			_vanish_peg(g, s, Motion.stagger(g * length + s, RESET_STAGGER))
		for k in length:
			Motion.stop(_pip_tw[g][k])
			_pip_tw[g][k] = null
			Models.set_layer_visible(_pips[g][k], "Pip_Ball", false)
	for s in length:
		_lid_back(s, Motion.stagger(s, LID_RETURN_STAGGER))
		_locked[s] = false
		_row[s] = -1
	_guesses = []
	_marks = []
	_history = []
	_revealed = false
	_running = true
	moves = 0
	_activate_row(0)
	fx.cue("reset")

func is_solved() -> bool:
	return _marks.size() > 0 and int(_marks[-1].exact) == length

func share_glyphs() -> String:
	# Structurally identical to Wordle's share grid, with zero language content.
	var out := ""
	for m in _marks:
		out += "🟩".repeat(int(m.exact)) + "🟨".repeat(int(m.colour))
		out += "⬛".repeat(length - int(m.exact) - int(m.colour)) + "\n"
	return out

# --- capabilities (HUD spec section 3, codebreak spec sections 2 and 3) ---

func capabilities() -> Array[String]:
	return ["undo", "hint", "check", "palette"]

## The board takes picks, pops, undos and hints: not solved, not lost.
func _open() -> bool:
	return not is_done() and not _revealed

## Index of the active guess; its board row is one more.
func _active() -> int:
	return _guesses.size()

func palette() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in palette_size:
		out.append({"colour": Pal.PEGS[i % Pal.PEGS.size()], "mark": i + 1, "enabled": _open()})
	return out

## A tray colour drops into the first empty, unlocked slot of the active row.
## With none free the row's pegs nudge and nothing is placed.
func pick(i: int) -> bool:
	if not _open() or i < 0 or i >= palette_size:
		return false
	var g := _active()
	var slot := _free_slot()
	if slot < 0:
		for s in length:
			var peg: Node3D = _pegs[g][s]
			if peg == null:
				continue
			Motion.stop(_peg_tw[g][s])
			peg.position.y = Placeholders.PEG_SEAT
			_peg_tw[g][s] = Motion.hop(peg, NUDGE_HOP, NUDGE_TIME, 0.0, Placeholders.PEG_SEAT)
		fx.cue("full")
		return false
	_row[slot] = i
	_history.append({"op": "place", "slot": slot, "colour": i})
	_place(g, slot, i)
	moved.emit()
	return true

func _free_slot() -> int:
	for s in length:
		if _row[s] == -1 and not _locked[s]:
			return s
	return -1

func can_undo() -> bool:
	return _open() and not _history.is_empty()

## Takes back the last place or pop in the active row. Submitted guesses
## stay: their feedback is information the player has already seen.
func undo() -> bool:
	if not _open() or _history.is_empty():
		return false
	var last: Dictionary = _history.pop_back()
	var g := _active()
	var s: int = int(last.slot)
	if last.op == "place":
		_row[s] = -1
		_vanish_peg(g, s)
	else:
		_row[s] = int(last.colour)
		_place(g, s, int(last.colour))
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Reveals the leftmost code slot not yet revealed: its lid slides off, the
## code peg drops into the active row there with a sparkle, and the slot is
## locked so every later row starts with it in place. Counts no move; not
## refunded by reset.
func hint() -> bool:
	if not _open() or hints_left() <= 0:
		return false
	var slot := -1
	for s in length:
		if not _locked[s]:
			slot = s
			break
	if slot < 0:
		return false
	var g := _active()
	_locked[slot] = true
	_lid_away(slot)
	var kept: Array[Dictionary] = []
	for h in _history:
		if int(h.slot) != slot:
			kept.append(h)
	_history = kept
	_vanish_peg(g, slot)
	_row[slot] = _code[slot]
	_place(g, slot, _code[slot])
	fx.sparkle(_cell(g, slot, Placeholders.SOCKET_H + SPARKLE_LIFT))
	hints_used += 1
	fx.cue("hint")
	moved.emit()
	return true

## Check submits the active row. An incomplete row only wobbles its empty
## sockets and returns -1. A full row is scored and locked; then the game is
## won, lost, or the next row activates. Returns the count of wrong places.
func check() -> int:
	if not _open():
		return -1
	checks += 1
	var g := _active()
	var missing := false
	for s in length:
		if _row[s] != -1:
			continue
		missing = true
		Motion.stop(_wobbles[g][s])
		_pivots[g][s].rotation.z = 0.0
		_wobbles[g][s] = Motion.wobble(_pivots[g][s], WOBBLE_ANGLE, WOBBLE_TIME)
	if missing:
		fx.cue("check")
		return -1
	var m: Dictionary = Gen.score(_row, _code)
	_guesses.append(_row.duplicate())
	_marks.append(m)
	_history = []
	_score_row(g, m)
	var fresh := []
	for s in length:
		fresh.append(-1)
	_row = fresh
	if int(m.exact) == length:
		pass  # note_move ends the game; _on_solved does the rest
	elif _guesses.size() >= max_guesses:
		_lose()
	else:
		_activate_row(g + 1)
	note_move()
	return length - int(m.exact)

# --- scene ---

## Kills every tween the previous board still tracks, so a rebuild never
## inherits motion aimed at nodes about to go.
func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for rows in [_dips, _wobbles, _peg_tw, _breath_tw, _fades, _pip_tw]:
		for row in rows:
			for tw in row:
				Motion.stop(tw)
	for tws in [_lid_tw, _code_tw]:
		for tw in tws:
			Motion.stop(tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pivots = []
	_breaths = []
	_sockets = []
	_pegs = []
	_feedback = []
	_pips = []
	_lids = []
	_lid_gone = []
	_code_pegs = []
	_dips = []
	_wobbles = []
	_peg_tw = []
	_breath_tw = []
	_fades = []
	_blend = []
	_pip_tw = []
	_lid_tw = []
	_code_tw = []

	var size := board_size()
	board.add_child(CodebreakScenery.dock(size.x, size.y))
	fx = Fx.new()
	board.add_child(fx)

	for g in max_guesses:
		var pivots := []
		var breaths := []
		var sockets := []
		var pegs := []
		var dips := []
		var wobbles := []
		var peg_tw := []
		var breath_tw := []
		var fades := []
		var blend := []
		for s in length:
			# The pivot carries the dip and the Check wobble; the breath under
			# it carries the active row's rise; the socket and the peg ride
			# both, so no node ever runs two height tweens.
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [g, s]
			pivot.position = _cell(g, s, 0.0)
			board.add_child(pivot)
			var breath := Node3D.new()
			breath.name = "breath"
			pivot.add_child(breath)
			var socket := Models.instance("socket")
			breath.add_child(socket)
			pivots.append(pivot)
			breaths.append(breath)
			sockets.append(socket)
			pegs.append(null)
			dips.append(null)
			wobbles.append(null)
			peg_tw.append(null)
			breath_tw.append(null)
			fades.append(null)
			blend.append(1.0)
		_pivots.append(pivots)
		_breaths.append(breaths)
		_sockets.append(sockets)
		_pegs.append(pegs)
		_dips.append(dips)
		_wobbles.append(wobbles)
		_peg_tw.append(peg_tw)
		_breath_tw.append(breath_tw)
		_fades.append(fades)
		_blend.append(blend)
		# The feedback slab: a socket without its well, always resting tint,
		# with `length` pips on it, two across.
		var slab := Models.instance("socket")
		slab.name = "feedback_%d" % g
		slab.position = _cell(g, length, 0.0)
		Models.set_layer_visible(slab, "Socket_Well", false)
		Models.tint_named(slab, "Stone", Pal.STONE_GIVEN)
		board.add_child(slab)
		_feedback.append(slab)
		var pips := []
		var pip_tw := []
		for k in length:
			var pip := Models.instance("pip")
			pip.name = "pip_%d" % k
			pip.position = _pip_offset(k, Placeholders.SOCKET_H + Placeholders.WELL_PROUD)
			Models.set_layer_visible(pip, "Pip_Ball", false)
			slab.add_child(pip)
			pips.append(pip)
			pip_tw.append(null)
		_pips.append(pips)
		_pip_tw.append(pip_tw)

	# The code row: a hidden peg per slot under a lid.
	for s in length:
		var peg := _make_peg(int(_code[s]))
		peg.name = "code_%d" % s
		peg.position = _code_pos(s)
		peg.visible = false
		board.add_child(peg)
		_code_pegs.append(peg)
		_code_tw.append(null)
		var lid := Models.instance("lid")
		lid.name = "lid_%d" % s
		lid.position = _code_pos(s)
		board.add_child(lid)
		_lids.append(lid)
		_lid_tw.append(null)
		_lid_gone.append(false)

	for g in max_guesses:
		for s in length:
			_paint(1.0, g, s)

## Board-space centre of guess `g`, slot `s` (the feedback slab is slot `length`).
func _cell(g: int, s: int, y: float) -> Vector3:
	var size := board_size()
	return BoardMath.cell_center(g + 1, s, size.x, size.y, y)

func _code_pos(s: int) -> Vector3:
	var size := board_size()
	return BoardMath.cell_center(CODE_ROW, s, size.x, size.y, 0.0)

## Where pip `k` sits on its slab: two columns, ceil(length / 2) rows, centred;
## an odd last pip takes the middle.
func _pip_offset(k: int, y: float) -> Vector3:
	var deep := (length + 1) / 2
	var col := k % 2
	var row := k / 2
	var x := (col - 0.5) * PIP_GAP
	if length % 2 == 1 and k == length - 1:
		x = 0.0
	var z := (row - (deep - 1) * 0.5) * PIP_GAP
	return Vector3(x, y, z)

## A peg of colour index `colour`: the dome tinted, its mark a darker shade,
## and only the matching one of the seven marks shown.
func _make_peg(colour: int) -> Node3D:
	var peg := Models.instance("peg")
	var c: Color = Pal.PEGS[colour % Pal.PEGS.size()]
	Models.tint_named(peg, "Shell", c)
	Models.tint_named(peg, "Mark_flat", c.darkened(MARK_SHADE))
	for k in range(1, MARKS + 1):
		Models.set_layer_visible(peg, "Peg_Mark_%d" % k, k == colour + 1)
	return peg

# --- pieces ---

## Drops a peg of `colour` onto socket (g, s), replacing whatever is there at
## once. The drop is the state change, so it is essential and survives
## reduce-motion shortened. `cue` false places silently: a row that activates
## re-places its locked pegs, which is one event, not one per slot.
func _place(g: int, s: int, colour: int, delay := 0.0, cue := true) -> void:
	_clear_peg(g, s)
	var peg := _make_peg(colour)
	peg.name = "peg"
	peg.position = Vector3(0.0, Placeholders.PEG_SEAT + PLACE_DROP, 0.0)
	_breaths[g][s].add_child(peg)
	_pegs[g][s] = peg
	var tw: Tween = Motion.settle(peg, "position:y", Placeholders.PEG_SEAT, PLACE_TIME, delay, true)
	if tw != null:
		tw.finished.connect(_on_peg_landed.bind(g, s))
		_peg_tw[g][s] = tw
	else:
		_on_peg_landed(g, s)
	if cue:
		fx.cue("place")

func _on_peg_landed(g: int, s: int) -> void:
	fx.puff(_cell(g, s, Placeholders.PEG_SEAT))
	fx.cue("land")

## Removes the peg on (g, s) at once, no motion.
func _clear_peg(g: int, s: int) -> void:
	Motion.stop(_peg_tw[g][s])
	_peg_tw[g][s] = null
	var peg: Node3D = _pegs[g][s]
	if peg != null:
		peg.queue_free()
		_pegs[g][s] = null

## The pop: the peg lifts and shrinks away, then is freed. The slot forgets it
## at once, so a place that follows never fights it.
func _vanish_peg(g: int, s: int, delay := 0.0) -> void:
	var peg: Node3D = _pegs[g][s]
	if peg == null:
		return
	Motion.stop(_peg_tw[g][s])
	_peg_tw[g][s] = null
	_pegs[g][s] = null
	# The tween stays untracked on purpose: the slot has already forgotten the
	# peg, and the tween is bound to the peg, so it dies with it and its
	# `finished` is what frees it.
	var tw: Tween = Motion.vanish(peg, POP_LIFT, POP_TIME, delay)
	if tw == null:
		peg.queue_free()
	else:
		tw.finished.connect(peg.queue_free)

## Scores guess `g` on its slab: the row's sockets dip together, then one ball
## per hit pops in, slate for exact then cream for colour, with a sparkle
## when anything was exact.
func _score_row(g: int, m: Dictionary) -> void:
	for s in length:
		_dip(g, s, COMMIT_DIP)
	var exact := int(m.exact)
	var hits := exact + int(m.colour)
	for k in hits:
		var pip: Node3D = _pips[g][k]
		Models.tint_named(pip, "Pip", Pal.SLATE if k < exact else Pal.MOON)
		Models.set_layer_visible(pip, "Pip_Ball", true)
		var ball := pip.find_child("Pip_Ball", true, false)
		if ball is Node3D:
			(ball as Node3D).scale = Vector3.ONE * 0.01
			Motion.stop(_pip_tw[g][k])
			_pip_tw[g][k] = Motion.settle(ball, "scale", Vector3.ONE, BALL_POP, Motion.stagger(k, BALL_STAGGER))
			if _pip_tw[g][k] == null:
				(ball as Node3D).scale = Vector3.ONE
	if exact > 0:
		fx.sparkle(_cell(g, length, Placeholders.SOCKET_H + SPARKLE_LIFT))
	fx.cue("score")

## Row `g` becomes the active one: its sockets fade to STONE and breathe, every
## other row rests in STONE_GIVEN and stands still, and each locked slot gets
## its code peg. `g == max_guesses` means no row is active (the game is lost).
## `instant` paints without a fade (the first build).
func _activate_row(g: int, instant := false) -> void:
	for gg in max_guesses:
		var active := gg == g
		var target := 0.0 if active else 1.0
		for s in length:
			Motion.stop(_breath_tw[gg][s])
			_breath_tw[gg][s] = null
			_breaths[gg][s].position.y = 0.0
			if instant:
				Motion.stop(_fades[gg][s])
				_fades[gg][s] = null
				_paint(target, gg, s)
			elif not is_equal_approx(_blend[gg][s], target):
				Motion.stop(_fades[gg][s])
				_fades[gg][s] = Motion.fade(_sockets[gg][s], _paint.bind(gg, s), _blend[gg][s], target, ROW_FADE, ROW_STEPS)
			if active:
				_breath_tw[gg][s] = Motion.pulse(_breaths[gg][s], "position:y", 0.0, BREATH_RISE, BREATH_PERIOD)
	if g >= max_guesses:
		return
	for s in length:
		if _locked[s] and _row[s] == -1:
			_row[s] = _code[s]
			_place(g, s, int(_code[s]), Motion.stagger(s, LOCKED_STAGGER), false)

## The socket's tint at a blend from STONE (0) to STONE_GIVEN (1), snapped to
## the 8-step grid so a fade asks the toon cache for at most nine colours.
func _paint(blend: float, g: int, s: int) -> void:
	blend = roundf(blend * ROW_STEPS) / ROW_STEPS
	_blend[g][s] = blend
	Models.tint_named(_sockets[g][s], "Stone", Pal.STONE.lerp(Pal.STONE_GIVEN, blend))

## The lid over code slot `s` slides off the far edge, falls to the water and
## rings it; the code peg pops in beneath as the slide ends.
func _lid_away(s: int, delay := 0.0) -> void:
	if _lid_gone[s]:
		return
	_lid_gone[s] = true
	var lid: Node3D = _lids[s]
	Motion.stop(_lid_tw[s])
	var rest := _code_pos(s)
	lid.position = rest
	lid.visible = true
	var tw: Tween = Motion.slide(lid, "position:z", rest.z, rest.z - LID_SLIDE, LID_SLIDE_TIME, delay, false)
	if tw == null:
		lid.visible = false
		_show_code_peg(s, 0.0)
		return
	tw.tween_property(lid, "position:y", rest.y - LID_FALL, LID_FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_lid_sunk.bind(s))
	_lid_tw[s] = tw
	_show_code_peg(s, delay + LID_SLIDE_TIME)
	fx.cue("lid")

func _on_lid_sunk(s: int) -> void:
	var lid: Node3D = _lids[s]
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(lid.global_position)
	lid.visible = false
	fx.cue("splash")

func _show_code_peg(s: int, delay: float) -> void:
	var peg: Node3D = _code_pegs[s]
	Motion.stop(_code_tw[s])
	peg.visible = true
	peg.scale = Vector3.ONE * 0.01
	_code_tw[s] = Motion.settle(peg, "scale", Vector3.ONE, ENTER_POP, delay)
	if _code_tw[s] == null:
		peg.scale = Vector3.ONE

## A lid that slid off drops back onto its slot (reset); the code peg hides.
func _lid_back(s: int, delay := 0.0) -> void:
	Motion.stop(_code_tw[s])
	_code_tw[s] = null
	_code_pegs[s].visible = false
	if not _lid_gone[s]:
		return
	_lid_gone[s] = false
	var lid: Node3D = _lids[s]
	Motion.stop(_lid_tw[s])
	var rest := _code_pos(s)
	lid.visible = true
	lid.position = rest + Vector3(0.0, LID_DROP, 0.0)
	_lid_tw[s] = Motion.settle(lid, "position:y", rest.y, LID_DROP_TIME, delay)
	if _lid_tw[s] == null:
		lid.position = rest

# --- motion helpers ---

## A dip and return on socket (g, s), replacing any dip already on it.
func _dip(g: int, s: int, depth: float) -> void:
	Motion.stop(_dips[g][s])
	_pivots[g][s].position.y = 0.0
	_dips[g][s] = Motion.hop(_pivots[g][s], -depth, DIP_TIME, 0.0, 0.0)

## Ends every motion on cell (g, s) at once: the socket flat and level, the
## peg (if any) seated at full size.
func _settle(g: int, s: int) -> void:
	Motion.stop(_dips[g][s])
	Motion.stop(_wobbles[g][s])
	Motion.stop(_peg_tw[g][s])
	_dips[g][s] = null
	_wobbles[g][s] = null
	_peg_tw[g][s] = null
	var pivot: Node3D = _pivots[g][s]
	pivot.position.y = 0.0
	pivot.rotation.z = 0.0
	var peg: Node3D = _pegs[g][s]
	if peg != null:
		peg.position.y = Placeholders.PEG_SEAT
		peg.scale = Vector3.ONE

## The board arrives: the platform rises and rings the water, the sockets and
## slabs pop in along a diagonal wave, then the lids drop onto the code row.
func _enter() -> void:
	_stop_entrance()
	var dock: Node3D = board.get_node("Dock")
	dock.position.y = -ENTER_DROP
	var rise: Tween = Motion.settle(dock, "position:y", 0.0, ENTER_PLATFORM)
	if rise != null:
		_entrance.append(rise)
		var splash := board.create_tween()
		splash.tween_interval(ENTER_PLATFORM * 0.9)
		splash.tween_callback(_splash)
		_entrance.append(splash)
	for g in max_guesses:
		for s in length:
			_pop_in(_pivots[g][s], ENTER_PLATFORM + Motion.stagger(g + s, ENTER_STAGGER))
		_pop_in(_feedback[g], ENTER_PLATFORM + Motion.stagger(g + length, ENTER_STAGGER))
	for s in length:
		if _lid_gone[s]:
			continue
		var lid: Node3D = _lids[s]
		var rest := _code_pos(s)
		lid.position = rest + Vector3(0.0, LID_DROP, 0.0)
		var drop: Tween = Motion.settle(lid, "position:y", rest.y, LID_DROP_TIME,
			ENTER_PLATFORM + ENTER_LIDS + Motion.stagger(s, LID_RETURN_STAGGER))
		if drop != null:
			_entrance.append(drop)
	fx.cue("enter")

func _pop_in(node: Node3D, delay: float) -> void:
	node.scale = Vector3.ONE * 0.01
	var pop: Tween = Motion.settle(node, "scale", Vector3.ONE, ENTER_POP, delay)
	if pop != null:
		_entrance.append(pop)

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	if _pivots.is_empty():
		return
	var dock: Node3D = board.get_node_or_null("Dock")
	if dock != null:
		dock.position.y = 0.0
	for g in max_guesses:
		for s in length:
			_pivots[g][s].scale = Vector3.ONE
		_feedback[g].scale = Vector3.ONE
	for s in length:
		if not _lid_gone[s]:
			_lids[s].position = _code_pos(s)

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.to_global(SPLASH_AT))

## The guess matched: the lids slide off one by one and the winning row's
## pegs hop in a wave. Its sockets keep the active tint; the breathing stops.
func _on_solved() -> void:
	var g := _guesses.size() - 1
	for gg in max_guesses:
		for s in length:
			Motion.stop(_breath_tw[gg][s])
			_breath_tw[gg][s] = null
			_breaths[gg][s].position.y = 0.0
	for s in length:
		_lid_away(s, Motion.stagger(s, LID_STAGGER))
		var peg: Node3D = _pegs[g][s]
		if peg == null:
			continue
		Motion.stop(_peg_tw[g][s])
		peg.position.y = Placeholders.PEG_SEAT
		_peg_tw[g][s] = Motion.hop(peg, SOLVE_HOP, SOLVE_TIME, Motion.stagger(s, SOLVE_STAGGER), Placeholders.PEG_SEAT)
	fx.cue("solved")

## Out of guesses: the lids slide off to show the code, the timer stops, and
## the board goes quiet until reset.
func _lose() -> void:
	_revealed = true
	_running = false
	_activate_row(max_guesses)
	for s in length:
		_lid_away(s, Motion.stagger(s, LID_STAGGER))
	fx.cue("reveal")

# --- input ---

## A tap on a placed, unlocked peg in the active row pops it; any other
## socket only dips. The feedback column and the code row do nothing.
func on_board_press(hit: Vector3) -> void:
	var size := board_size()
	var cell := BoardMath.world_to_cell(hit, size.x, size.y)
	if cell.x < 0 or cell.y == CODE_ROW or cell.x >= length:
		return
	var g := cell.y - 1
	var s := cell.x
	if _open() and g == _active() and _row[s] != -1 and not _locked[s]:
		_settle(g, s)
		_history.append({"op": "pop", "slot": s, "colour": _row[s]})
		_row[s] = -1
		_vanish_peg(g, s)
		fx.cue("pop")
		moved.emit()
		return
	_dip(g, s, DIP)
	fx.cue("focus")

## Control-local point over the centre of socket (g, s). The win harness
## checks the camera fit with this.
func cell_to_local(g: int, s: int) -> Vector2:
	return board_to_local(_cell(g, s, plane_height()))
