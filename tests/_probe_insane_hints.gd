extends SceneTree

## Insane's hint on every board of the registry, headless and with no window
## (2026-10-13, the day Insane got its bulb back). Each board is started on
## band 3 as the host starts it, and then:
##
## - it must offer the bulb (`capabilities()` has "hint") and hold as many
##   hints as Hard does (`hints_left()` on a board started on band 2);
## - its lessons and its rules are built (`tutorial_pages`, `rules_text`);
## - it is played by the bulb alone: `hint()` again and again, a video's
##   hint added (`add_hint`) whenever the band's own are spent, until the day
##   is done or the bulb has nothing more to say. A board whose bulb cannot
##   carry a day by itself (a letter, an option struck, an aim shown) is
##   not a failure; one whose bulb says no while hints are left, on a board
##   that is not done, is.
##
##   godot --headless --path . --script tests/_probe_insane_hints.gd [-- seeds=2] [id=<board>] [band=3]

const Motion = preload("res://core/motion.gd")
const Registry = preload("res://ui/registry.gd")

## Seconds a board may say no in a row (a hint that thinks on a thread, a
## piece still landing, an Untangle rope leaving) before the bulb is
## called silent. Headless frames are far shorter than a board's clocks.
const PATIENCE := 6.0
## Boards whose day comes from the backend, which a probe never starts: the
## card waits and the bulb has nothing to tell.
const WAITS := ["pearl"]
## Hints one day may take before it is given up on.
const MOST := 600

var _seeds := 2
var _only := ""
var _band := 3
var _jobs: Array = []
var _at := 0
var _board: Control
var _hard := 0
var _said := 0
var _no := 0.0
var _frames := 0
var _wait := 0
var _bad := 0
var _rows: Array = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			_seeds = int(a.trim_prefix("seeds="))
		elif a.begins_with("id="):
			_only = a.trim_prefix("id=")
		elif a.begins_with("band="):
			_band = int(a.trim_prefix("band="))
	for e in Registry.PUZZLES:
		if _only != "" and String(e.id) != _only:
			continue
		if not e.has("script"):
			continue
		for s in _seeds:
			_jobs.append([e, s])

func _open(e: Dictionary, band: int, s: int) -> Control:
	var board: Control = load(String(e.script)).new()
	board.size = Vector2(810, 1440)
	root.add_child(board)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(e.id), s, 20261013])
	board.start(rng, band)
	return board

func _busy() -> bool:
	return _board.has_method("busy") and _board.busy()

func _close(how: String) -> void:
	var e: Dictionary = _jobs[_at][0]
	var done: bool = _board.is_done()
	_rows.append("%-12s seed %d: %s, %d hints said, done=%s" % [String(e.id), _jobs[_at][1], how, _said, done])
	print(_rows[-1])
	_board.queue_free()
	_board = null
	_at += 1

func _process(delta: float) -> bool:
	Motion.reduce = true
	if _at >= _jobs.size():
		Motion.reduce = false
		print("probe_insane_hints: %d days, %d failures" % [_jobs.size(), _bad])
		quit(1 if _bad > 0 else 0)
		return true
	var e: Dictionary = _jobs[_at][0]
	if _board == null:
		# what Hard holds, off a board of its own
		var hard: Control = _open(e, 2, _jobs[_at][1])
		_hard = hard.hints_left() if hard.capabilities().has("hint") else -1
		hard.free()
		_board = _open(e, _band, _jobs[_at][1])
		_said = 0
		_no = 0.0
		_frames = 0
		_wait = 3
		return false
	_frames += 1
	if _wait > 0:
		_wait -= 1
		return false
	if _frames == 4:
		if _hard < 0:
			_close("no bulb on Hard either (left=%d)" % _board.hints_left())
			return false
		var caps: Array = _board.capabilities()
		var left: int = _board.hints_left()
		if not caps.has("hint") or left != _hard:
			_bad += 1
			print("FAIL %s: caps %s, %d hints (Hard has %d)" % [String(e.id), str(caps), left, _hard])
			if not caps.has("hint"):
				_close("no bulb")
				return false
		# the lessons and the rules are built for the band as it is now
		if _board.has_method("tutorial_pages"):
			_board.tutorial_pages()
		if _board.has_method("rules_text"):
			_board.rules_text()
	if _board.is_done():
		_close("carried by the bulb")
		return false
	if _busy():
		return false
	if _said >= MOST:
		_close("still going after %d" % MOST)
		return false
	if _board.hints_left() <= 0:
		if not _board.capabilities().has("hint"):
			_close("the bulb went away")
			return false
		_board.add_hint()
		if _board.hints_left() <= 0:
			_close("nothing more to say")
			return false
	if _board.hint():
		_said += 1
		_no = 0.0
		_wait = 2
	else:
		_no += delta
		if _no > PATIENCE:
			if _said == 0 and not WAITS.has(String(e.id)):
				_bad += 1
				print("FAIL %s: the bulb said nothing at all" % String(e.id))
			_close("the bulb fell silent")
	return false
