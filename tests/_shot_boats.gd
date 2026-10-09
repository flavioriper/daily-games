extends SceneTree

## A game of Toy Boats, shot at fixed beats, the screen built by hand so
## nothing of the menu (or the network) is started:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_boats.gd -- <outdir> [level] [rm] [lang=pt|es] [lose]
##
## The hand is real touches on the board: a boat dragged where it has no
## room, dropped where it has, another tapped round, Ready, then a throw a
## turn at the square the best computer would pick (`lose`: at the worst, so
## the end card is the lost one). Shots: lay, drag (no room), laid, play,
## over (a finger on the slate), flying, hit, struck, sunk, hint, end. Prints
## the draw calls at each and puts user://versus.cfg back.

const AI = preload("res://versus/boats_ai.gd")
const Rules = preload("res://versus/boats_rules.gd")

var _screen: Control
var _board: Control
var _t := 0.0
var _out := "/tmp"
var _level := 1
var _lose := false
var _step := 0
var _wait := 0.0
var _done := {}
var _rng := RandomNumberGenerator.new()
var _record_before := ""
var _had_record := false
var _pressed := -1

func _initialize() -> void:
	_had_record = FileAccess.file_exists("user://versus.cfg")
	if _had_record:
		_record_before = FileAccess.get_file_as_string("user://versus.cfg")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for a in args.slice(1):
		if a == "rm":
			load("res://core/motion.gd").reduce = true
		elif a == "lose":
			_lose = true
		elif a.begins_with("lang="):
			TranslationServer.set_locale(a.trim_prefix("lang="))
		elif a.is_valid_int():
			_level = int(a)
	_rng.seed = 4
	_screen = load("res://versus/boats_screen.gd").new(_level)
	root.add_child(_screen)

func _restore() -> void:
	if _had_record:
		var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
		f.store_string(_record_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))

func _shot(name: String) -> void:
	if _done.has(name):
		return
	_done[name] = true
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/bts_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d state %d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), _screen._state])

func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = at
	_board._gui_input(ev)

func _slide(at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = at
	_board._gui_input(ev)

func _process(delta: float) -> bool:
	_t += delta
	if _board == null:
		_board = _screen.board
		# The real pointer over the window must not carry a boat.
		_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return false
	var S = _screen.State
	_wait -= delta
	if _wait > 0.0:
		return false
	match _step:
		0:
			if _screen._state == S.PLACE and _t > 1.4:
				_shot("lay")
				# Boat 4 is lifted and carried onto boat 0: no room.
				var b: Vector3i = _screen.pond.boats[4]
				_touch(_board.point_of(0, Rules.cell(b.x, b.y)), true)
				var onto: Vector3i = _screen.pond.boats[0]
				_slide(_board.point_of(0, Rules.cell(onto.x, onto.y)))
				_step = 1
				_wait = 0.25
		1:
			_shot("drag")
			var b: Vector3i = _screen.pond.boats[4]
			_touch(_board.point_of(0, Rules.cell(b.x, b.y)), false)
			print("  dropped where there is no room: boat 4 still at ", _screen.pond.boats[4] == b)
			# Boat 1 is tapped round.
			var b1: Vector3i = _screen.pond.boats[1]
			_touch(_board.point_of(0, Rules.cell(b1.x, b1.y)), true)
			_touch(_board.point_of(0, Rules.cell(b1.x, b1.y)), false)
			print("  tapped: boat 1 turned ", _screen.pond.boats[1].z != b1.z, ", fleet valid ", Rules.valid(_screen.pond.boats))
			# Boat 2 is carried to a free place.
			for c in Rules.CELLS:
				var at := Rules.xy(c)
				var to := Vector3i(at.x, at.y, _screen.pond.boats[2].z)
				if to != _screen.pond.boats[2] and Rules.free_for(_screen.pond.boats, 2, to):
					var b2: Vector3i = _screen.pond.boats[2]
					_touch(_board.point_of(0, Rules.cell(b2.x, b2.y)), true)
					_slide(_board.point_of(0, c))
					_touch(_board.point_of(0, c), false)
					print("  carried: boat 2 at ", _screen.pond.boats[2] == to)
					break
			_step = 2
			_wait = 0.4
		2:
			_shot("laid")
			_screen._ready_b.pressed.emit()
			_step = 3
		3:
			if _screen._state == S.YOURS:
				_shot("play")
				var c := _pick()
				_touch(_board.point_of(1, c), true)
				_pressed = c
				_step = 4
				_wait = 0.2
			elif _screen._state == S.ANIM or _screen._state == S.THEIRS:
				_look()
		4:
			_shot("over")
			_touch(_board.point_of(1, _pressed), false)
			_step = 5
			_wait = 0.2
		5:
			_shot("flying")
			_step = 6
		6:
			_look()
			if _screen._state == S.YOURS:
				if _screen.slate.shots == 6 and _level < 3:
					_screen._on_hint()
					_wait = 0.3
					_step = 7
					return false
				var c := _pick()
				_touch(_board.point_of(1, c), true)
				_touch(_board.point_of(1, c), false)
				if _done.has("sunk") and _done.has("struck"):
					Engine.time_scale = 6.0
			elif _screen._state == S.OVER:
				Engine.time_scale = 1.0
				_step = 8
				_wait = 3.2
		7:
			_shot("hint")
			_step = 6
			var c := _pick()
			_touch(_board.point_of(1, c), true)
			_touch(_board.point_of(1, c), false)
		8:
			_shot("end")
			_restore()
			return true
	return false

## Shots taken as the things they show come by.
func _look() -> void:
	var S = _screen.State
	if _screen._state != S.ANIM:
		return
	var marks: PackedByteArray = _screen.slate.marks
	if marks.has(Rules.HIT) and not _done.has("hit"):
		_wait = 0.2
		_shot.call_deferred("hit")
	if _screen.slate.afloat() < 5 and not _done.has("sunk"):
		_wait = 0.3
		_shot.call_deferred("sunk")
	if not _board._pebble.is_empty() and not _done.has("struck") and _t - 0.0 > 0.0 and _board._t - float(_board._pebble.at) > 0.25:
		_shot("struck")

func _pick() -> int:
	if _lose:
		# The worst throw there is: a square known to be open water.
		for c in Rules.CELLS:
			if _screen.slate.marks[c] == Rules.UNKNOWN and _screen._their_pond.boat_at(c) < 0:
				return c
	return AI.plan(_screen.slate, 2, _rng)
