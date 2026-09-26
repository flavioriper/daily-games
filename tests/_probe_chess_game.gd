extends SceneTree

## A whole game of chess through the real screen, both sides played by the
## computer (the player's moves chosen at LEVEL_YOU, fed in as if tapped),
## sped up. Proves the state machine never stalls and every ending lands:
##
##     godot --headless --path . --script res://tests/_probe_chess_game.gd
##
## SEED, LEVEL (the bot's), LEVEL_YOU, COLOUR (0 white) and SPEED from the
## environment. Puts user://versus.cfg back afterwards.

const Rules = preload("res://versus/chess_rules.gd")
const AI = preload("res://versus/chess_ai.gd")
var Screen: GDScript

var _s: Node
var _t := 0.0
var _plies := 0
var _last_state := -1
var _stuck := 0.0
var _record := ""
var _had := false
var _you := 0

func _env(name: String, fallback: int) -> int:
	return int(OS.get_environment(name)) if OS.has_environment(name) else fallback

func _initialize() -> void:
	_had = FileAccess.file_exists("user://versus.cfg")
	if _had:
		_record = FileAccess.get_file_as_string("user://versus.cfg")
	var cfg := ConfigFile.new()
	cfg.load("user://versus.cfg")
	cfg.set_value("colour", "chess", _env("COLOUR", 0))
	cfg.save("user://versus.cfg")
	Engine.time_scale = float(_env("SPEED", 6))
	_you = _env("LEVEL_YOU", 0)
	Screen = load("res://versus/chess_screen.gd")
	_s = Screen.new(_env("LEVEL", 0))
	root.add_child(_s)

func _process(delta: float) -> bool:
	_t += delta
	if _s == null or not _s.is_inside_tree():
		return false
	var st: int = _s._state
	if st != _last_state:
		_last_state = st
		_stuck = 0.0
	else:
		_stuck += delta
	if st == _s.State.YOURS and not _s.board.is_busy():
		var m: int = AI.new().plan(_s.rules.copy(), _you, _env("SEED", 1) + _plies, 200)
		_plies += 2
		_s._on_chosen(m)
	if st == _s.State.OVER:
		var g: RefCounted = _s.rules
		print("OVER status=%d move=%d history=%d in_check=%s time=%.1fs" % [g.status(), g.fullmove, _s._history.size(), g.in_check(), _t])
		_done()
	elif _stuck > 30.0:
		print("STUCK in state ", st, " busy=", _s.board.is_busy(), " task=", _s._task, " move=", _s.rules.fullmove)
		_done()
	elif _s.rules.fullmove > 150:
		print("LONG game, move ", _s.rules.fullmove, " status ", _s.rules.status())
		_done()
	return false

func _done() -> void:
	if _had:
		var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
		f.store_string(_record)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
	quit()
