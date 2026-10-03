extends SceneTree

## Drumbeat through the real menu and flat host, played by a bot through the
## board's own strokes, shot at fixed moments:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_drumbeat.gd -- <outdir> [d=<level>] [miss] [full] [reduce]
##
## 1 the start card, 2 early in the song, 3 in the first Go-Go section, 4 on
## the first balloon, and with `full` 5 the win (or, with `miss`, where the bot
## plays nothing, the retry card). Prints the draw calls and the mean frame
## time over the second before each shot. The solve goes to a harness copy of
## the progress file, never this Mac's save.

const State = preload("res://puzzles/drumbeat_state.gd")

var _menu: Node
var _host: Node
var _b: Node
var _out := "/tmp"
var _level := 2
var _miss := false
var _full := false
var _reduce := false
var _tune := false
var _revive := false
var _t := 0.0
var _step := 0
var _struck := {}
var _last_roll := -10.0
var _shots: Array = []
var _frames: Array = []

## The tap-along writes the phone's timing: the harness puts this Mac's back.
var _cfg_was: Variant = null

func _finalize() -> void:
	var path := "user://drumbeat.cfg"
	if _cfg_was == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(_cfg_was)

func _initialize() -> void:
	if FileAccess.file_exists("user://drumbeat.cfg"):
		_cfg_was = FileAccess.get_file_as_bytes("user://drumbeat.cfg")
	# its own throwaway progress file, emptied first, so a solve from an
	# earlier run never restores the board instead of playing it
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progress_drumbeat_shot.cfg"))
	load("res://core/progress.gd").path = "user://progress_drumbeat_shot.cfg"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for a: String in args:
		if a.begins_with("d="):
			_level = int(a.substr(2))
		elif a == "miss":
			_miss = true
		elif a == "full":
			_full = true
		elif a == "revive":
			_revive = true
		elif a == "tune":
			_tune = true
		elif a == "reduce":
			_reduce = true
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/db_%s.png" % [_out, name])
	var mean := 0.0
	for f: float in _frames:
		mean += f
	mean /= maxf(1.0, _frames.size())
	var st = _b._st if _b != null else null
	print("shot %s at %.1f song %.2f draws=%d mean=%.2fms score=%d combo=%d gauge=%.0f good=%d ok=%d bad=%d" % [name, _t,
		_b.song_now() if _b != null else 0.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		mean * 1000.0, st.score if st else 0, st.max_combo if st else 0, st.gauge if st else 0.0,
		st.goods if st else 0, st.oks if st else 0, st.bads if st else 0])

## Strikes every note on its drum as it reaches the line, holds a ribbon to
## its end, rolls at twelve a second and drums a balloon until it pops.
func _bot() -> void:
	var st = _b._st
	if _b._phase != "play" or _miss:
		return
	var vt: float = _b.view_t()
	for i in st.notes.size():
		var n: Dictionary = st.notes[i]
		if float(n.t) > vt + 0.01:
			break
		if State.is_long(n.type):
			if vt <= float(n.end) and n.st == State.St.WAIT and vt - _last_roll >= 1.0 / 12.0:
				_last_roll = vt
				_b.strike(int(n.lane))
			continue
		if n.type == State.Type.HOLD and n.held and vt >= float(n.end):
			_b._lift(int(n.lane))
			continue
		if _struck.has(i) or n.st != State.St.WAIT:
			continue
		_struck[i] = true
		_b.strike(int(n.lane))

func _process(delta: float) -> bool:
	_t += delta
	_frames.append(delta)
	if _frames.size() > 120:
		_frames.pop_front()
	if _b != null and _b._phase == "paused":
		_b._pause(false)
	match _step:
		0:
			if _t > 0.8:
				# set here, not at start: main.tscn loads the saved setting over it
				if _reduce:
					load("res://core/motion.gd").reduce = true
				var entry: Dictionary = load("res://ui/registry.gd").find("drumbeat")
				_menu._open_at(entry, _level)
				_host = _menu.get_child(_menu.get_child_count() - 1)
				_b = _host._puzzle
				if _host.has_node("HowToPlay"):
					_host.get_node("HowToPlay").free()
				_step = 1
		1:
			if _t > 2.2:
				_shot("1_ready")
				if _tune:
					_b._begin_tune(false)
					_step = 10
					_t = 0.0
					return false
				_b.strike(0)
				var song: Dictionary = _b._song
				var gogo: Array = song.gogo
				var first_balloon := INF
				for n: Dictionary in _b._st.notes:
					if int(n.type) == State.Type.BALLOON:
						first_balloon = float(n.t)
						break
				_shots = [["2_early", 7.0], ["2b_count", float(_b._st.notes[0].t) - float(song.beat) * 2.5], ["3_gogo", float(gogo[0][0]) + 1.2 if not gogo.is_empty() else 20.0],
					["4_balloon", first_balloon + 0.35]]
				for n: Dictionary in _b._st.notes:
					if int(n.type) == State.Type.HOLD and not n.hidden:
						_shots.append(["2c_hold", float(n.t) + 0.15])
						break
				var echo: Array = song.get("echo", [])
				if _level == 3 and echo.size() > 2:
					_shots.append(["4b_echo", float(echo[2][0]) + 0.4])
				# a short song may have no balloon at all
				_shots = _shots.filter(func(s: Array) -> bool: return float(s[1]) < INF)
				_shots.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
				print("song %s level %d, %d notes" % [song.id, _level, _b._st.notes.size()])
				_step = 2
		2:
			_bot()
			if not _shots.is_empty() and _b.song_now() >= float(_shots[0][1]):
				_shot(String(_shots[0][0]))
				_shots.pop_front()
			if _shots.is_empty() and not _full:
				quit()
			if _full and _b._phase in ["won", "missed", "out"]:
				_step = 3
				_t = 0.0
		3:
			if _revive and _b._phase == "out" and _t > 1.9:
				# One more heart, as the card's video would give it: the bot
				# plays from here on
				_revive = false
				_miss = false
				print("revived from %.2f" % _b._stopped_at)
				_b.heart_back()
				_step = 2
				_shots = []
				return false
			if not _miss and _t > 0.9 and not _struck.has(-1):
				_struck[-1] = true
				_shot("5a_finale")
			if _t > (2.0 if _miss else 6.5):
				_shot("5_end")
				print("phase %s solved %s all_good %s" % [_b._phase, _b.is_solved(), _b._st.all_good()])
				quit()
		10:
			# the tap-along: taps a hair late on every knock, shot halfway
			var clicks: Array = State.calib().clicks
			var now: float = _b.song_now()
			for k in clicks.size():
				if not _struck.has(1000 + k) and now >= float(clicks[k]) + 0.09:
					_struck[1000 + k] = true
					_b.strike(k % int(_b._st.lanes))
			if not _struck.has(-2) and now > float(clicks[6]) + 0.2:
				_struck[-2] = true
				_shot("1b_tune")
			if _b._phase == "ready" and _t > 2.0:
				print("tuned offset %.3f" % _b._offset)
				_shot("1c_tuned")
				quit()
	return false
