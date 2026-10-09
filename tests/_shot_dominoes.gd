extends SceneTree

## A game of Dominoes, shot at fixed beats, the screen built by hand so
## nothing of the menu (or the network) is started:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_dominoes.gd -- <outdir> [level] [rm] [lang=pt|es] [lose] [speed=N]
##
## The hand is real touches on the board: a tap on the tile the best computer
## would lay (`lose`: on the lightest that fits, so the end card is more
## likely the lost one), a tap on the place when the tile was picked up to
## choose an end, a tap on the boneyard when nothing fits, and once a tap on
## a tile that fits neither end and on the boneyard when a tile does. Shots:
## deal (tiles in the air), start, laid, picked (two places lit), hint, draw
## (the boneyard lit), refused, long (the line at its longest in the first
## hand), hand (a finished hand lying open), end. After the first hand the
## clock runs `speed` times as fast (4). Prints the draw calls at each and
## the peak, and puts user://versus.cfg back.

const AI = preload("res://versus/dominoes_ai.gd")
const Rules = preload("res://versus/dominoes_rules.gd")

var _screen: Control
var _board: Control
var _t := 0.0
var _out := "/tmp"
var _level := 1
var _lose := false
var _speed := 4.0
var _wait := 0.0
var _done := {}
var _rng := RandomNumberGenerator.new()
var _record_before := ""
var _had_record := false
var _hinted := false
var _refused := false
var _peak := 0
var _taps := 0
var _ending := -1.0

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
		elif a.begins_with("speed="):
			_speed = float(a.trim_prefix("speed="))
		elif a.is_valid_int():
			_level = int(a)
	_rng.seed = 4
	_screen = load("res://versus/dominoes_screen.gd").new(_level)
	root.add_child(_screen)

func _restore() -> void:
	Engine.time_scale = 1.0
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
	root.get_texture().get_image().save_png("%s/dom_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d state %d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), _screen._state])

func _tap(at: Vector2) -> void:
	for down: bool in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = down
		ev.position = at
		_board._gui_input(ev)
	_taps += 1

func _process(delta: float) -> bool:
	_t += delta
	if _board == null:
		_board = _screen.board
		# The real pointer over the window must not lay a tile.
		_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return false
	_peak = maxi(_peak, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	var S = _screen.State
	var r: RefCounted = _screen.rules
	if _t > 0.9:
		_shot("deal")
	_wait -= delta
	if _wait > 0.0:
		return false
	if _screen._state == S.OVER:
		if _ending < 0.0:
			_ending = _t
			Engine.time_scale = 1.0
			print("  over: scores %s hands %d laid %d winner %d taps %d" % [str(r.scores), r.hand_no + 1, r.laid, r.winner, _taps])
		elif _t - _ending > 3.6:
			_shot("end")
			print("peak draws ", _peak)
			_restore()
			return true
		return false
	if _screen._state == S.HAND:
		if not _done.has("hand"):
			_wait = 0.6
			_done["hand_due"] = true
			if _done.has("hand_seen"):
				_shot("hand")
				print("  hand %d: winner %d points %d blocked %s, said: %s" % [r.hand_no, r.hand_winner, r.hand_points, str(r.hand_blocked), _screen._toast_label.text])
				Engine.time_scale = _speed
			_done["hand_seen"] = true
		return false
	if _screen._state != S.YOURS or _board.is_busy():
		return false
	_shot("start")
	if r.plays.size() >= 12 and r.hand_no == 0:
		_shot("long")
	if _board._picked >= 0:
		_shot("picked")
		var want: int = _board._picked * 2 + _rng.randi() % 2
		_tap(_board.slot_point(want))
		_wait = 0.5
		return false
	if _board._hint >= 0 and not _done.has("hint"):
		_wait = 0.3
		_done["hint_due"] = true
		if _done.has("hint_seen"):
			_shot("hint")
		_done["hint_seen"] = true
		return false
	if r.can(Rules.DRAW):
		if not _done.has("draw"):
			_wait = 0.35
			if _done.has("draw_seen"):
				_shot("draw")
			_done["draw_seen"] = true
			return false
		_tap(_board.stock_point())
		_wait = 0.4
		return false
	if not _hinted and r.plays.size() >= 3 and _level < 3:
		_hinted = true
		_screen._on_hint()
		_wait = 0.6
		return false
	if not _refused and r.plays.size() >= 2:
		for t: int in r.hands[_screen.player]:
			if not r.fits(t, 0) and not r.fits(t, 1):
				_refused = true
				var laid: int = r.laid
				_tap(_board.tile_point(t))
				print("  a tile that fits neither end: laid still ", r.laid == laid, ", said: ", _screen._toast_label.text)
				_tap(_board.stock_point())
				print("  the boneyard with a tile that fits: stock still ", r.stock.size(), ", said: ", _screen._toast_label.text)
				_wait = 0.25
				_done["refused_due"] = true
				return false
	if _done.has("refused_due"):
		_shot("refused")
	var move := _pick(r)
	_tap(_board.tile_point(move >> 1))
	if _board._picked < 0:
		_shot("laid") if _done.has("laid_due") else _done.set("laid_due", true)
	_wait = 0.45
	return false

func _pick(r: RefCounted) -> int:
	var legal: PackedInt32Array = r.legal_moves()
	if _lose:
		var best := legal[0]
		for m in legal:
			if Rules.weight(m >> 1) < Rules.weight(best >> 1):
				best = m
		return best
	return AI.new().plan(r.view(r.turn), 2, _rng.randi(), 60)
