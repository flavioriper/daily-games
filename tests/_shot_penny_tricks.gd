extends SceneTree

## A Penny Drop match with its tricks, by real touches: a drop under a read
## slot, the heavy penny, the spark, the twin, and a hand that then plays the
## best column to the end card and the match's end.
##
##     caffeinate -d -i -u godot --path . --rendering-driver opengl3_angle --resolution 810x1440 --always-on-top --script res://tests/_shot_penny_tricks.gd -- <outdir> [level] [lose]
##
## Shots: start, marks (a finger on a read slot), heavy_hand, smash, spark_aim,
## fuse, pop, twin, each sticker while it shows, rack (a rack won), next (the
## next rack), end. Prints draw calls and puts user://versus.cfg back.

const AI = preload("res://versus/penny_ai.gd")
const Rules = preload("res://versus/penny_rules.gd")
## The screen's State: RACK and YOURS, by value, since preloading the screen
## here would compile it before the autoloads exist.
const RACK := 6
const YOURS := 2

var _s: Control
var _b: Control
var _out := "/tmp"
var _level := 1
var _lose := false
var _had := false
var _keep := ""
var _t := 0.0
var _wait := 0.0
var _phase := 0
var _done := {}
var _peak := 0
var _rng := RandomNumberGenerator.new()
var _racks := 0
var _seen := {}

func _initialize() -> void:
	_had = FileAccess.file_exists("user://versus.cfg")
	if _had:
		_keep = FileAccess.get_file_as_string("user://versus.cfg")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for a in args.slice(1):
		if a == "lose":
			_lose = true
		elif a.is_valid_int():
			_level = int(a)
	_rng.seed = 11
	_s = load("res://versus/penny_screen.gd").new(_level)
	root.add_child(_s)

func _finish() -> void:
	if _had:
		FileAccess.open("user://versus.cfg", FileAccess.WRITE).store_string(_keep)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
	print("peak draws ", _peak)
	quit()

func _shot(n: String) -> void:
	if _done.has(n):
		return
	_done[n] = true
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/t_%s.png" % [_out, n])
	var d := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_peak = maxi(_peak, d)
	print("shot %s t=%.1f draws=%d state=%d score=%s rack=%d" % [n, _t, d, _s._state, str(_s._score), _s._rack])

func _at(col: int) -> Vector2:
	return _b.point_of(Vector2((col + 0.5) * 100.0, 420.0))

func _press(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = at
	_b._gui_input(ev)

func _drop(col: int) -> void:
	_press(_at(col), true)
	_press(_at(col), false)

func _best() -> int:
	if _lose:
		var m: PackedInt32Array = _s.rules.legal_moves()
		return m[_rng.randi() % m.size()]
	return AI.new().plan(_s.rules, 2, _rng.randi(), 120)

func _trick(kind: int) -> void:
	_s.tricks.button(kind).pressed.emit()

func _process(delta: float) -> bool:
	_t += delta
	_b = _s.board
	if _b == null or _s._rw == null:
		return false
	if _t > 240.0:
		print("timed out, phase ", _phase, " state ", _s._state)
		_finish()
		return true
	# stickers, while they show
	for id in ["smash", "pop", "fork", "blocked", "four", "twin"]:
		if _s._rw.has_sticker(id):
			# a sticker is shot once it has grown
			_seen[id] = float(_seen.get(id, 0.0)) + delta
			if _seen[id] > 0.22:
				_shot("st_" + id)
	if _s._armed == 0 and not _b._fuse.is_empty():
		_shot("fuse")
	if not _b._flung.is_empty() and _b._air.size() > 0:
		_shot("smash")
	if _s._state == RACK:
		_wait = 0.0
		if int(_s._score[0]) + int(_s._score[1]) > _racks:
			_racks += 1
			_shot("rack_%d" % _racks)
		return false
	if _s._end != null:
		_wait += delta
		if _wait > 0.9:
			_shot("end")
			_finish()
		return false
	if _s._state != YOURS or not _s.board.interactive:
		return false
	_wait += delta
	if _wait < 0.5:
		return false
	_wait = 0.0
	var r: RefCounted = _s.rules
	match _phase:
		0:
			_shot("start")
			_drop(3)
			_phase = 1
		1:
			# a finger on a slot the marks read, if there is one
			# a slot told it hands the moon its place: the ghost and the ring
			var col: int = (int(r.history[r.history.size() - 1]) + 1) % Rules.W
			_b.set_marks({col: AI.MARK_GIVES})
			_press(_at(col), true)
			_phase = 2
		2:
			_shot("marks")
			print("mark line: ", _s._toast_label.text)
			_press(_at(_b._over), false)
			_b.set_marks({})
			_phase = 3
		3:
			_trick(Rules.HEAVY)
			_phase = 4
		4:
			_shot("heavy_hand")
			var tall := 0
			for c in Rules.W:
				if r.heights[c] > r.heights[tall]:
					tall = c
			_drop(tall)
			_phase = 5
		5:
			_trick(Rules.SPARK)
			_phase = 6
		6:
			_shot("spark_aim")
			var hit := -1
			for c in Rules.CELLS:
				if r.cells[c] == 1 - r.turn + 1:
					hit = c
			if hit < 0:
				_trick(Rules.SPARK)
				_phase = 7
			else:
				_press(_b.point_of(_b.mid(hit)), true)
				_press(_b.point_of(_b.mid(hit)), false)
				_phase = 7
		7:
			_trick(Rules.TWIN)
			_phase = 8
		8:
			_shot("twin")
			_drop(_best())
			_phase = 9
		9:
			if _racks > 0:
				_shot("next")
			_drop(_best())
	return false
