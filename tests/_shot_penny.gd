extends SceneTree

## A game of Penny Drop, shot at fixed beats, the screen built by hand so
## nothing of the menu (or the network) is started:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_penny.gd -- <outdir> [level] [rm] [lang=pt|es] [lose]
##
## The hand is real touches on the board: a finger put down on one slot and
## slid to another, let go; then a drop a turn in the slot the best computer
## would pick (`lose`: in any slot, so the end card is the lost one), the bulb
## once, a full slot tried once it exists, Undo once. Shots: start, over (the
## finger down), falling, landed, hint, back (a penny going back up), end,
## spill (Play again emptying the rack). Prints the draw calls at each and
## puts user://versus.cfg back.

const AI = preload("res://versus/penny_ai.gd")
const Rules = preload("res://versus/penny_rules.gd")

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
var _undone := false
var _hinted := false
var _peak := 0

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
	_screen = load("res://versus/penny_screen.gd").new(_level)
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
	root.get_texture().get_image().save_png("%s/pny_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d state %d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), _screen._state])

## A point of the board over column `col`, where a thumb would be.
func _at(col: int) -> Vector2:
	return _board.point_of(Vector2((col + 0.5) * 100.0, 420.0))

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
		# The real pointer over the window must not drop a penny.
		_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return false
	_peak = maxi(_peak, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	var S = _screen.State
	_wait -= delta
	if _wait > 0.0:
		return false
	match _step:
		0:
			if _screen._state == S.YOURS and _t > 1.6:
				_shot("start")
				_touch(_at(1), true)
				_slide(_at(2))
				_slide(_at(_pick()))
				_step = 1
				_wait = 0.3
		1:
			_shot("over")
			_touch(_at(_pick()), false)
			_step = 2
			_wait = 0.16
		2:
			_shot("falling")
			_step = 3
			_wait = 0.7
		3:
			_shot("landed")
			_step = 4
		4:
			if _screen._state == S.YOURS:
				var r: RefCounted = _screen.rules
				if not _hinted and r.ply >= 4 and _level < 3:
					_hinted = true
					_screen._on_hint()
					_step = 5
					return false
				if not _undone and r.ply >= 8 and _level < 3:
					_undone = true
					print("  undo: can ", _screen.can_undo(), " at ply ", r.ply)
					_screen._on_undo()
					_step = 6
					_wait = 0.1
					return false
				# A full slot, once there is one: refused, and nothing is played.
				for c in Rules.W:
					if r.heights[c] == Rules.H and not _done.has("full"):
						var ply: int = r.ply
						_touch(_at(c), true)
						_wait = 0.2
						_step = 7
						print("  a full slot: column ", c, " ply ", ply)
						return false
				var col := _pick()
				_touch(_at(col), true)
				_touch(_at(col), false)
				_wait = 0.1
			elif _screen._state == S.OVER:
				print("  over: status %d winner %d line %s ply %d" % [_screen.rules.status(), _screen.rules.winner, str(_screen.rules.line), _screen.rules.ply])
				_step = 8
				_wait = 0.9
		5:
			if _screen._hint_col >= 0:
				_wait = 0.3
				_step = 51
		51:
			_shot("hint")
			_step = 4
		6:
			_shot("back")
			_step = 61
		61:
			if _screen._state == S.YOURS:
				print("  after undo: ply ", _screen.rules.ply)
				_step = 4
		7:
			_shot("full")
			var before: int = _screen.rules.ply
			for c in Rules.W:
				if _screen.rules.heights[c] == Rules.H:
					_touch(_at(c), false)
					break
			print("  refused: ply still ", _screen.rules.ply == before, ", said: ", _screen._toast_label.text)
			_step = 4
			_wait = 0.4
		8:
			_shot("line")
			_step = 9
			_wait = 3.0
		9:
			_shot("end")
			if _screen._end != null and _screen.online == null:
				# Play again is the card's first button.
				(_screen._end.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
			_step = 10
			_wait = 0.3
		10:
			_shot("spill")
			print("peak draws ", _peak)
			_restore()
			return true
	return false

func _pick() -> int:
	var r: RefCounted = _screen.rules
	if _lose:
		var open: PackedInt32Array = r.legal_moves()
		return open[_rng.randi() % open.size()]
	return AI.new().plan(r, 2, _rng.randi(), 80)
