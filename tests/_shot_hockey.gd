extends SceneTree

## A match of air hockey, shot at its moments, the screen built by hand so
## nothing of the menu (or the network) is started:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_hockey.gd -- <outdir> [level] [rm] [lang=pt|es]
##
## `level` 0-2 is the computer's, 4 two players. The bottom mallet is played
## by a second computer (level 2) writing where it wants the mallet, as a
## finger would.
##
## The shots are taken when the thing is on the table, not on a clock:
## `serve` and `ring` (the puck set down), `idle` (nobody has played it:
## the mallets breathe, the puck glows), then fourteen seconds of play in
## which `hit`, `wall`, `post`, `trail`, `save` and a goal are shot as they
## come up (`goal_a` the puck sinking, `goal_b` the hop and the sag,
## `served` the puck back). What play did not bring is then **staged** --
## the puck put where the moment needs it and let go, the sim doing the rest
## -- and the log says which were: a goal, a save, `point` (6-5, the mouth
## glowing), and the last goal: `win_a` and `win_b` (the light down the
## rails, the hops) and `end` (the card). Prints the draw calls at each
## shot, their peak, and what the live mesh and a frame cost, and puts
## user://versus.cfg back.

const AI = preload("res://versus/hockey_ai.gd")
const Sim = preload("res://versus/hockey_sim.gd")

enum Phase { OPEN, PLAY, STAGE_GOAL, STAGE_SAVE, POINT, WIN, DONE }

var _screen: Control
var _hand: RefCounted
var _hand2: RefCounted
var _t := 0.0
var _out := "/tmp"
var _level := 1
var _phase := Phase.OPEN
var _phase_t := 0.0
var _taken := {}
var _staged: Array = []
var _goals := 0
var _goal_clock := -1.0
var _hands_off := 0.0
var _armed := false
var _peak := 0
var _record_before := ""
var _had_record := false
var _ms := 0.0
var _ms_n := 0
var _frame := 0.0

func _initialize() -> void:
	_had_record = FileAccess.file_exists("user://versus.cfg")
	if _had_record:
		_record_before = FileAccess.get_file_as_string("user://versus.cfg")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1 and args[1].is_valid_int():
		_level = int(args[1])
	for a in args:
		if a == "rm":
			load("res://core/motion.gd").reduce = true
		elif a.begins_with("lang="):
			TranslationServer.set_locale(a.trim_prefix("lang="))
	_screen = load("res://versus/hockey_screen.gd").new(_level)
	root.add_child(_screen)
	_hand = AI.new(0, 2, 5)
	_hand2 = AI.new(1, 1, 6)

func _restore() -> void:
	if _had_record:
		var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
		f.store_string(_record_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))

func _leave() -> void:
	print("peak draws=%d; staged: %s; never shot: %s" % [_peak, str(_staged), str(_missing())])
	print("live mesh %.3f ms, frame %.2f ms, means over %d frames of play" % [_ms / maxf(1.0, _ms_n), _frame / maxf(1.0, _ms_n), _ms_n])
	_restore()
	quit()

func _missing() -> Array:
	var out := []
	for n in ["serve", "ring", "idle", "hit", "wall", "post", "trail", "save", "goal_a", "goal_b", "served", "point", "win_a", "win_b", "end"]:
		if not _taken.has(n):
			out.append(n)
	return out

## One shot a name, the first time its moment is on the table.
func _shot(name: String) -> void:
	if _taken.has(name):
		return
	_taken[name] = true
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/hky_%s.png" % [_out, name])
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_peak = maxi(_peak, draws)
	print("shot %s at %.1f draws=%d score %s" % [name, _t, draws, str(_screen.sim.scores)])

func _to(phase: Phase) -> void:
	_phase = phase
	_phase_t = 0.0
	_armed = false

## The puck put in front of the goal at `end` and sent in.
func _send_in(end: int) -> void:
	var sim: RefCounted = _screen.sim
	var keeper := end
	sim.mallet[keeper] = Sim.clamp_half(keeper, Vector2(0.14, Sim.L * 0.5))
	sim.aim[keeper] = sim.mallet[keeper]
	sim.puck_on = true
	sim.puck = Vector2(0.5, Sim.L - 0.1 if end == 0 else 0.1)
	sim.puck_vel = Vector2(0.0, 3.0 if end == 0 else -3.0)
	_hands_off = 0.3

func _process(delta: float) -> bool:
	_t += delta
	_phase_t += delta
	var table: Control = _screen.table
	var sim: RefCounted = _screen.sim
	# The real pointer over the window must not lead the mallet.
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _screen._state == _screen.State.PLAY and _t > 1.0:
		var t0 := Time.get_ticks_usec()
		table._build_live()
		_ms += float(Time.get_ticks_usec() - t0) / 1000.0
		_frame += delta * 1000.0
		_ms_n += 1
	_hands_off -= delta
	if _phase != Phase.OPEN and _hands_off <= 0.0 and _screen._state != _screen.State.OVER:
		_hand.drive(sim, delta)
		if _screen.two_players():
			_hand2.drive(sim, delta)

	# Whatever is on the table now.
	for f in table._flashes:
		if float(f.t) < 0.07:
			continue
		match String(f.kind):
			"mallet":
				if float(f.strength) > 0.45:
					_shot("hit")
			"wall":
				if float(f.strength) > 0.3:
					_shot("wall")
			"post":
				_shot("post")
			"save":
				if float(f.t) > 0.14:
					_shot("save")
	if table._trail.size() >= table.TRAIL and table._motes.size() >= 4:
		_shot("trail")
	var goals := int(sim.scores[0]) + int(sim.scores[1])
	if goals > _goals and _phase != Phase.POINT:
		_goal_clock = 0.0
	_goals = goals
	if _goal_clock >= 0.0:
		_goal_clock += delta
		var last: bool = sim.over
		if _goal_clock > 0.12 and not last:
			_shot("goal_a")
		if _goal_clock > 0.5:
			_shot("win_a" if last else "goal_b")
		if _goal_clock > 0.95 and last:
			_shot("win_b")
		if not last and sim.puck_on and float(table._serve_t) > 0.1 and _taken.has("goal_b"):
			_shot("served")
			_goal_clock = -1.0

	match _phase:
		Phase.OPEN:
			if float(table._serve_t) > 0.1 and float(table._serve_t) < 1.0:
				_shot("serve")
			if float(table._serve_t) > 0.3 and float(table._serve_t) < 1.0:
				_shot("ring")
			if _phase_t > 3.2:
				_shot("idle")
				_to(Phase.PLAY)
		Phase.PLAY:
			if _phase_t > 14.0 and _goal_clock < 0.0 and _screen._state == _screen.State.PLAY:
				_to(Phase.STAGE_GOAL)
		Phase.STAGE_GOAL:
			if _taken.has("served"):
				if _screen._state == _screen.State.PLAY and _goal_clock < 0.0 and _phase_t > 0.6:
					_to(Phase.STAGE_SAVE)
			elif not _armed and _screen._state == _screen.State.PLAY:
				_armed = true
				_staged.append("goal")
				_send_in(1)
		Phase.STAGE_SAVE:
			if _taken.has("save") and not _armed:
				_to(Phase.POINT)
			elif not _armed:
				# The puck straight at the bottom goal, the gold mallet at home.
				_armed = true
				_staged.append("save")
				sim.mallet[0] = Sim.home(0)
				sim.aim[0] = Sim.home(0)
				sim.puck_on = true
				sim.puck = Vector2(0.5, Sim.L - 0.8)
				sim.puck_vel = Vector2(0.0, 3.2)
				_hands_off = 0.5
			elif _phase_t > 1.2:
				_to(Phase.POINT)
		Phase.POINT:
			if not _armed:
				_armed = true
				sim.scores = [6, 5]
				_screen._refresh_board()
			elif _phase_t > 0.7:
				_shot("point")
				_to(Phase.WIN)
		Phase.WIN:
			if not _armed and _screen._state == _screen.State.PLAY:
				_armed = true
				_staged.append("last goal")
				_send_in(1)
			elif _screen._state == _screen.State.OVER and _screen._end != null and _phase_t > _screen.WIN_HOLD + 1.6:
				_shot("end")
				_to(Phase.DONE)
				_leave()
	if _t > 120.0 and _phase != Phase.DONE:
		print("ran out of time in phase %d" % _phase)
		_to(Phase.DONE)
		_leave()
	return false
