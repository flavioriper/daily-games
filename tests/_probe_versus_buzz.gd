extends SceneTree

## What the phone knocks for on a Versus game, read like `_probe_perf.gd`'s
## `x=buzz` reads a board: each thing the hand can do through the real screen
## and the kinds that landed for it (`Haptics.trace`), then a game played on
## and the whole trace (docs/agents/haptics.md).
##
##     godot --headless --path . --script res://tests/_probe_versus_buzz.gd -- snooker
##     godot --headless --path . --script res://tests/_probe_versus_buzz.gd -- chess
##
## `rm` after the game runs it under reduce motion. SPEED, LEVEL (the
## computer's), YOU (chess: the hand's level, 0 to lose) and SHOTS (snooker)
## from the environment. Puts user://versus.cfg back afterwards.

const Haptics = preload("res://core/haptics.gd")
const Motion = preload("res://core/motion.gd")
const SnookerAI = preload("res://versus/snooker_ai.gd")
const ChessAI = preload("res://versus/chess_ai.gd")
const ChessRules = preload("res://versus/chess_rules.gd")

var _game := "snooker"
var _s: Node
var _seen := 0
var _record := ""
var _had := false
var _begun := false

func _env(name: String, fallback: int) -> int:
	return int(OS.get_environment(name)) if OS.has_environment(name) else fallback

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_game = args[0]
	_had = FileAccess.file_exists("user://versus.cfg")
	if _had:
		_record = FileAccess.get_file_as_string("user://versus.cfg")
	var cfg := ConfigFile.new()
	cfg.load("user://versus.cfg")
	cfg.set_value("colour", "chess", 0)
	cfg.save("user://versus.cfg")
	Motion.settings_path = "user://_probe_versus_buzz.cfg"
	Motion.reduce = args.has("rm")
	Haptics.on = true
	Haptics.trace = []
	Engine.time_scale = float(_env("SPEED", 4))
	# Loaded at run time: a preload compiles before the Ads autoload exists.
	_s = (load("res://versus/%s_screen.gd" % _game) as GDScript).new(_env("LEVEL", 0))
	root.add_child(_s)

func _process(_delta: float) -> bool:
	if not _begun:
		_begun = true
		_run()
	return false

func _run() -> void:
	if _game == "chess":
		await _chess()
	else:
		await _snooker()
	print("haptics: ", " ".join(Haptics.trace))
	if _had:
		var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
		f.store_string(_record)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_probe_versus_buzz.cfg"))
	quit()

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

## Waits for the screen to reach `state` (60 s of game time at most).
func _until(state: int) -> bool:
	var t := 0.0
	while _s._state != state and t < 60.0:
		await process_frame
		t += root.get_process_delta_time()
	return _s._state == state

## Prints what landed since the last call, against what was done. A hand is
## slower than the motor (one knock holds it 40 ms, real time): wait after a
## step, or the next one's weaker knock is dropped.
func _say(what: String) -> void:
	var all: Array = Haptics.trace
	print("  %-34s %s" % [what, " ".join(all.slice(_seen)) if all.size() > _seen else "-"])
	_seen = all.size()

func _press(c: Control, at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	if pressed:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	c._gui_input(e)

func _move(c: Control, at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	c._gui_input(e)

func _end_button() -> BaseButton:
	var found: Array = _s._end.find_children("*", "BaseButton", true, false)
	return found[0] if not found.is_empty() else null

# --- snooker ---

func _snooker() -> void:
	var st: Dictionary = _s.State
	var table: Control = _s.table
	await _until(st.AIM)
	await _wait(0.3)
	print("snooker, level ", _s.level, ", reduce ", Motion.reduce)
	_seen = Haptics.trace.size()
	# the cue ball carried in the D
	var from: Vector2 = table.px(_s.sim.pos[0])
	var to: Vector2 = table.px(_s.sim.pos[0] + Vector2(0.15, 0.03))
	_press(table, from, true)
	_move(table, from.lerp(to, 0.5))
	_move(table, to)
	_press(table, to, false)
	_say("cue ball placed in the D")
	await _wait(0.4)
	# a tap on the cloth aims
	var aim: Vector2 = table.px(_s.sim.pos[15] + Vector2(0.04, 0.0))
	_press(table, aim, true)
	_press(table, aim, false)
	_say("aimed")
	await _wait(0.4)
	var pad: Control = _s.spin_pad
	_press(pad, pad.size * Vector2(0.5, 0.3), true)
	_say("spin set")
	await _wait(0.4)
	_press(pad, pad.size * 0.5, true)
	# the cue drawn to its end, held there, eased and drawn again, put back
	var grab: Vector2 = table.px(_s.sim.pos[0]) - table.aim_dir * 90.0
	_press(table, grab, true)
	var back := func(part: float) -> Vector2: return grab - table.aim_dir * table.reach() * part
	_move(table, back.call(0.5))
	_say("cue drawn halfway")
	await _wait(0.4)
	_move(table, back.call(1.1))
	_say("cue drawn to its end")
	await _wait(0.4)
	_move(table, back.call(1.2))
	_move(table, back.call(0.97))
	_say("held at its end")
	await _wait(0.4)
	_move(table, back.call(0.5))
	_move(table, back.call(1.05))
	_say("eased and drawn again")
	await _wait(0.4)
	_move(table, back.call(0.0))
	_press(table, grab, false)
	_say("cue put back")
	await _wait(0.4)
	# the break, by the cue
	_press(table, grab, true)
	_move(table, back.call(0.7))
	_press(table, back.call(0.7), false)
	await _until(st.ROLL)
	_say("cue let go: the strike")
	await _snooker_turn("the break")
	if _s._state == st.AIM:
		_s._on_hint()
		var t := 0.0
		while _s.table.hint_dir == Vector2.ZERO and t < 20.0:
			await process_frame
			t += root.get_process_delta_time()
		_say("hint")
		await _wait(0.5)
	# the frame played on, the hand's shots planned like the computer's
	for k in _env("SHOTS", 14):
		if _s._state != st.AIM:
			break
		var state := {"phase": _s.rules.phase, "free_ball": _s.rules.free_ball,
			"in_hand": _s.rules.in_hand, "break_off": _s._break_off}
		var plan: Dictionary = SnookerAI.plan(_s.sim.copy(), state, 2)
		if plan.is_empty():
			break
		if _s.rules.in_hand:
			_s.sim.pos[0] = plan.get("cue_at", _s.sim.pos[0])
		table.aim_dir = plan.dir
		table.tip = plan.tip
		pad.set_tip(plan.tip)
		_s._on_release(_s._power_for(float(plan.speed)))
		await _snooker_turn("shot %d" % (k + 1))
	if _s._state == st.AIM:
		_s._on_reset()
		_say("Reset")
		await _until(st.AIM)
	for won: bool in [true, false]:
		_s.rules.scores = [72, 41] if won else [41, 72]
		_s.rules.over = true
		_s.rules.winner = 0 if won else 1
		_s._finish()
		_say("frame %s" % ("won" if won else "lost"))
		await _wait(1.5)
		_say("  ... the card")
		var again := _end_button()
		if again != null:
			again.pressed.emit()
			_say("Play again")
		await _until(st.AIM)
		if _s._state != st.AIM:
			# the computer breaks this frame: wait it out
			await _wait(1.0)
	await _wait(0.5)

## Waits out the hand's shot and the computer's visit after it, and says
## what the referee made of the shot and what landed.
func _snooker_turn(what: String) -> void:
	var st: Dictionary = _s.State
	await _until(st.WAIT)
	var last: Dictionary = _s.rules.last
	var made := "foul" if bool(last.get("foul", false)) else ("scored %d" % int(last.get("scored", 0)))
	await _wait(0.1)
	_say("%s: %s" % [what, made])
	var t := 0.0
	await process_frame
	while _s._state != st.AIM and _s._state != st.OVER and t < 240.0:
		await process_frame
		t += root.get_process_delta_time()
	_say("  ... the computer's visit")

# --- chess ---

func _chess() -> void:
	var st: Dictionary = _s.State
	var board: Control = _s.board
	await _until(st.YOURS)
	await _wait(0.2)
	print("chess, level ", _s.level, ", reduce ", Motion.reduce)
	_seen = Haptics.trace.size()
	var at := func(sq: int) -> Vector2: return board.px(board.cell_of(sq))
	var tap := func(sq: int) -> void:
		_press(board, at.call(sq), true)
		_press(board, at.call(sq), false)
	# a piece that cannot move, a piece picked up, put down, and moved by taps
	var m := _chess_plan()
	var stuck := -1
	for sq in 64:
		if _s.rules.side_of(_s.rules.board[sq]) == _s.player and _s.rules.board[sq] != 0 and _s.rules.moves_from(sq).is_empty():
			stuck = sq
			break
	if stuck >= 0:
		tap.call(stuck)
		_say("a piece with no move")
	tap.call(ChessRules.mv_from(m))
	_say("piece picked up")
	tap.call(ChessRules.mv_from(m))
	_say("the same piece again")
	tap.call(ChessRules.mv_to(m))
	_say("moved by taps")
	await _chess_reply()
	# a move carried by the finger
	m = _chess_plan()
	var a: Vector2 = at.call(ChessRules.mv_from(m))
	var z: Vector2 = at.call(ChessRules.mv_to(m))
	_press(board, a, true)
	_move(board, a.lerp(z, 0.5))
	_move(board, z)
	_say("piece carried")
	_press(board, z, false)
	_say("let go on its square")
	await _chess_reply()
	_s._on_undo()
	_say("Undo")
	await _until(st.YOURS)
	_say("  ... both moves back")
	_s._on_hint()
	var t := 0.0
	while board._hint.x < 0 and t < 20.0:
		await process_frame
		t += root.get_process_delta_time()
	_say("hint")
	# the hint's knock is still in the motor for a moment and outranks a tap
	await _wait(0.5)
	_s._on_reset()
	_say("Reset")
	await _until(st.YOURS)
	_say("  ... the set comes in")
	# the game played on: the hand strong, the computer on LEVEL
	var plies := 0
	while _s._state == st.YOURS and plies < 150:
		while board.is_busy():
			await process_frame
		# a hand is slower than the motor: let a check's warn play out
		await _wait(0.3)
		m = ChessAI.new().plan(_s.rules.copy(), _env("YOU", 2), 7 + plies, 300)
		var d: Dictionary = _s.rules.describe(m)
		var kind := "takes" if int(d.captured) != 0 else "moves"
		if int(d.promo) != 0:
			kind += ", promotes"
		if int(d.rook_from) >= 0:
			kind = "castles"
		plies += 1
		_s._on_chosen(m)
		while _s._state == st.ANIM and _s.rules.turn != _s.player:
			await process_frame
		if _s.rules.in_check() and _s.rules.turn != _s.player:
			kind += ", check"
		_say("%d. %s" % [plies, kind])
		await _chess_reply()
	print("  over: status ", _s.rules.status(), ", state ", _s._state)
	await _wait(4.0)
	_say("  ... the card")
	if _s._end != null:
		var again := _end_button()
		if again != null:
			again.pressed.emit()
			_say("Play again")
	await _wait(0.5)

func _chess_plan() -> int:
	return ChessAI.new().plan(_s.rules.copy(), 2, 3, 200)

## Waits for the computer's answer to land and says what it did to you.
func _chess_reply() -> void:
	var st: Dictionary = _s.State
	var before: int = _s._history.size()
	var t := 0.0
	await process_frame
	while _s._state != st.YOURS and _s._state != st.OVER and t < 60.0:
		await process_frame
		t += root.get_process_delta_time()
	var what := "the reply"
	if _s._history.size() > before:
		var d: Dictionary = _s._history[_s._history.size() - 1]
		if int(d.side) != _s.player:
			what = "the reply takes" if int(d.captured) != 0 else "the reply"
			if _s.rules.in_check():
				what += ", check"
	if _s._state == st.OVER:
		what = "the end"
	_say("  ... " + what)
