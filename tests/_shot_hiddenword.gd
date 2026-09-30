extends SceneTree

## Shots and probes of Hidden Word, played through the board's own moves
## (type_letter, erase_letter, commit_row -- the keyboard's signals land on
## the same three). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_hiddenword.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the grid as dealt), `refuse` (a non-word, then on Hard and
## Insane a guess that drops a clue), `rows` (wrong guesses a row every 2.2 s,
## shots as each lands -- the reactions, and on Insane the snail), `solve`
## (two wrong rows, then the word, shots through the party), `out` (every row
## wrong, shots at the droop and the card, then One more row, a last wrong
## row, and Show the word), `restore` (a solved day reopened). Frames go to
## <dir>/hw_<mode>_d<level>_<n>.png. Every mode prints the peak draw calls
## from 0.5 s on (or its own window).

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/78b53668-8a1f-437d-9baa-ef327881bd37/scratchpad"

var _t := 0.0
var _level := 0
var _mode := "rest"
var _reduce := false
var _dir := SHOT_DIR
var _menu: Node
var _host: Node
var _puzzle: Node
var _opened := false
var _plan: Array = []
var _n := 0
var _end := 6.0
var _ms_from := 0.5
var _ms_sum := 0.0
var _ms_n := 0
var _draws_max := 0

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_level = int(a.substr(2))
		elif a == "rm":
			_reduce = true
		elif a.begins_with("out="):
			_dir = a.substr(4)
		else:
			_mode = a
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_hw_progress.cfg"))
	progress.path = "user://_shot_hw_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		_opened = true
		_t = 0.0
		var entry: Dictionary = {}
		for e in load("res://ui/registry.gd").PUZZLES:
			if e.id == "hiddenword":
				entry = e
		# Settings load after _initialize, so reduce motion is set here, right
		# before the board opens.
		load("res://core/motion.gd").reduce = _reduce
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
		print("answer: ", _puzzle.state.answer, " snail ", _puzzle.state.snail, " strict ", _puzzle.state.strict, " hints ", _puzzle.hints_left())
		_script()
		return false
	while not _plan.is_empty() and float(_plan[0][0]) <= _t:
		var step: Array = _plan.pop_front()
		(step[1] as Callable).call()
	if _t >= _ms_from and _t < _end:
		_ms_sum += delta * 1000.0
		_ms_n += 1
		_draws_max = maxi(_draws_max, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= _end:
		if _ms_n > 0:
			print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		var st = _puzzle.state
		print("board: rows %s, delivered %d of %d, tries %d, out %s, done %s, solved %s, hints %d, can_reset %s" % [
			st.rows, st.delivered(), st.rows.size(), st.tries, _puzzle.out_of_hearts, _puzzle.is_done(),
			_puzzle.is_solved(), _puzzle.hints_left(), _puzzle.can_reset()])
		print("tip: ", _puzzle.tip_line().text)
		print("share: ", _puzzle.share_glyphs())
		var loaded: Array = []
		for k in _puzzle.fx._streams:
			if _puzzle.fx._streams[k] != null:
				loaded.append(k)
		print("cues loaded: ", loaded)
		quit()
		return true
	return false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/hw_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _type(word: String, enter := true) -> void:
	while not _puzzle.state.typed.is_empty():
		_puzzle.erase_letter()
	for ch in word:
		_puzzle.type_letter(ch)
	if enter:
		var before: int = _puzzle.state.rows.size()
		_puzzle.commit_row()
		print("typed %s -> rows %d (was %d), delivered %d, toast '%s'" % [word, _puzzle.state.rows.size(), before,
			_puzzle.state.delivered(), _puzzle._toast_text if _puzzle._toast > 0 else ""])

## A left press or release over bed `c` of the row in hand, in window
## coordinates.
func _tap_cell(c: int, down: bool) -> void:
	var local: Vector2 = _puzzle.cell_to_local(_puzzle.state.rows.size(), c)
	var at: Vector2 = _puzzle.get_viewport().get_screen_transform() * _puzzle.get_global_transform_with_canvas() * local
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)

## A wrong guess the board will take: an answer-list word, not the answer,
## not guessed yet, keeping every clue on Hard and Insane. Prefers one that
## shares no letter with the answer on `miss`, or shares every letter on
## `all`, so the reactions can be seen.
func _wrong(kind := "") -> String:
	var st = _puzzle.state
	var pool: Array = st._answers
	var fallback := ""
	for w in pool:
		var word: String = Locale.fold(String(w))
		if word == st.answer or st.rows.has(word) or word.length() != 5:
			continue
		if st.strict and st.keeps_clues(word) != 0:
			continue
		if fallback.is_empty():
			fallback = word
		var shared := 0
		for ch in word:
			if st.answer.contains(ch):
				shared += 1
		if kind == "miss" and shared == 0:
			return word
		if kind == "all":
			var m: Array[int] = st.mark_guess(word, st.answer)
			if not m.has(2):
				return word
		if kind == "" and shared >= 2:
			return word
	return fallback

func _script() -> void:
	match _mode:
		"rest":
			_at(0.3, _shot.bind("_enter"))
			_at(1.2, func() -> void: _type("pla", false))
			_at(1.35, _shot.bind("_typing"))
			_at(1.6, func() -> void: _type(_wrong().substr(0, 5), false))
			_at(2.4, _shot)
			_end = 2.6
		"select":
			# A real tap on the fifth bed of the row in hand, then a letter:
			# it lands there and the caret goes back to the first empty bed.
			_at(1.2, func() -> void: _type("pla", false))
			_at(1.5, _tap_cell.bind(4, true))
			_at(1.55, _tap_cell.bind(4, false))
			_at(2.1, _shot.bind("_chosen"))
			_at(2.2, func() -> void: _puzzle.type_letter("s"))
			_at(2.8, func() -> void:
				print("typed '%s' cursor %d" % [_puzzle.state.typed, _puzzle.state.cursor])
				_shot("_typed"))
			_end = 3.0
		"refuse":
			_at(1.0, func() -> void: _type("zzzqq"))
			_at(1.25, _shot.bind("_notword"))
			_at(2.6, func() -> void: _type(_wrong()))
			_at(5.0, func() -> void:
				var st = _puzzle.state
				for w in st._answers:
					var word: String = Locale.fold(String(w))
					if st.accepts(word) and st.strict and st.keeps_clues(word) != 0 and not st.rows.has(word):
						_type(word)
						return
				print("no clue-breaking word found (not strict, or nothing delivered)"))
			_at(5.3, _shot.bind("_clue"))
			_end = 6.0
		"rows":
			var kinds := ["miss", "", "all", ""]
			for k in kinds.size():
				var t0 := 1.0 + k * 2.4
				var kind: String = kinds[k]
				_at(t0, func() -> void: _type(_wrong(kind)))
				_at(t0 + 0.55, _shot.bind("_turn"))
				_at(t0 + 1.35, _shot.bind("_react"))
				_at(t0 + 2.0, _shot)
			_end = 1.0 + kinds.size() * 2.4 + 0.3
		"solve":
			_at(1.0, func() -> void: _type(_wrong()))
			_at(3.0, func() -> void: _type(_wrong()))
			_at(5.0, func() -> void: _type(_puzzle.state.answer))
			for k in 10:
				_at(5.5 + k * 0.45, _shot)
			_ms_from = 5.0
			_end = 10.4
		"out":
			for k in 6:
				_at(1.0 + k * 1.6, func() -> void: _type(_wrong()))
			var t_out := 1.0 + 6 * 1.6
			_at(t_out + 0.2, _shot.bind("_last"))
			_at(t_out + 1.0, _shot.bind("_droop"))
			_at(t_out + 2.2, _shot.bind("_card"))
			_at(t_out + 2.4, func() -> void:
				print("out %s, card %s" % [_puzzle.out_of_hearts, is_instance_valid(_puzzle._card)])
				_puzzle.row_back())
			_at(t_out + 2.6, _shot.bind("_grow"))
			_at(t_out + 3.4, _shot.bind("_seven"))
			_at(t_out + 3.6, func() -> void: _type(_wrong()))
			_at(t_out + 6.2, _shot.bind("_card2"))
			_at(t_out + 6.4, func() -> void: _puzzle.show_word())
			_at(t_out + 7.4, _shot.bind("_shown"))
			_end = t_out + 7.6
		"restore":
			_at(1.0, func() -> void:
				var a := _wrong()
				var b := ""
				for w in _puzzle.state._answers:
					var f: String = Locale.fold(String(w))
					if f != a and f != _puzzle.state.answer:
						b = f
						break
				_puzzle.completed_record = {"guesses": [a, b, _puzzle.state.answer]}
				_puzzle.restore_completed_board())
			_at(1.8, _shot)
			_end = 2.0
