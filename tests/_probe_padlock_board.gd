extends SceneTree

## Padlock's board under a finger, headless: a tap on a letter below the
## window brings it there, a tap mid-spring picks the letter drawn under the
## finger, a word dialled again says so, and on Insane the rusty dial
## refuses a tap above and a drag up. Calls the board's own _press/_move/
## _release, so no window and no pointer.
##   godot --headless --path . --script tests/_probe_padlock_board.gd

const Board = preload("res://puzzles/padlock2d.gd")
const State = preload("res://puzzles/padlock_state.gd")

var _b: Control
var _f := 0
var _band := 1
var _bad := 0

func _lock(band: int) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/insane/%s.json" % State.BANKS[band]))
	return doc.boards[3]

func _make(band: int) -> void:
	if _b != null:
		_b.queue_free()
	_b = Board.new()
	_b.demo = true
	_b.demo_day = _lock(band)
	_b.size = Vector2(1080, 1920)
	root.add_child(_b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_b.start(rng, band)
	_b.skip_entrance()

func _check(what: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_bad += 1

func _tap(k: int, i: int) -> void:
	var at: Vector2 = _b.cell_to_local(k, i)
	_b._press(at)
	_b._release(at)

func _process(_d: float) -> bool:
	_f += 1
	var st = _b.state() if _b != null else null
	match _f:
		1:
			_make(1)
		3:
			# a plain dial, tapped one letter below the window
			var k := 0
			var n: int = st.dials[k].length()
			var to: int = (st.pos[k] + 1) % n if st.pos[k] + 1 < n else st.pos[k] - 1
			_tap(k, to)
			_check("tap brings letter %d to the window (pos %d)" % [to, st.pos[k]], st.pos[k] == to)
			# tapped again at once, mid-spring, on the letter drawn under the finger
			var drawn_at: float = _b._vis_now(k)
			var target: int = 0 if to != 0 else n - 1
			var at := Vector2(_b._dial_x(k), _b._l("win_y") + (float(target) - drawn_at) * _b._l("cell"))
			_b._press(at)
			_b._release(at)
			_check("a tap mid-spring takes the letter drawn there (%d, pos %d)" % [target, st.pos[k]], st.pos[k] == target)
		30:
			# a word dialled, then dialled again
			var w: String = st.hint_word()
			st.dial_to(w)
			st.read()
			_b._fresh()
			var k := 0
			var n: int = st.dials[k].length()
			var away: int = (st.pos[k] + 1) % n
			var home: int = st.pos[k]
			_tap(k, away)
			_b._vis[k] = float(away)
			_b._anim[k] = {}
			_tap(k, home)
		60:
			_check("the same word again says so (%s)" % _b._say, _b._say == "PL_SAY_AGAIN")
			print("three_line par=%d line=%d" % [st.par, st.three_line()])
			_make(3)
		63:
			var k: int = st.rusty
			if st.pos[k] == 0:
				st.turn(k, 1)
				_b._fresh()
		65:
			var k: int = st.rusty
			var was: int = st.pos[k]
			_tap(k, was - 1)
			_check("rusty dial refuses a tap above (pos %d, said %s)" % [st.pos[k], _b._say], st.pos[k] == was and _b._say == "PL_SAY_RUSTY")
			_b._say = ""
			var at: Vector2 = _b.cell_to_local(k, was)
			_b._press(at)
			for step in 6:
				_b._move(at + Vector2(0.0, _b._l("cell") * 0.25 * (step + 1)))
			_b._release(at + Vector2(0.0, _b._l("cell") * 1.5))
			_check("rusty dial refuses a drag up (pos %d)" % st.pos[k], st.pos[k] == was)
			var n: int = st.dials[k].length()
			_tap(k, n - 1)
			_b._vis[k] = float(n - 1)
			_b._anim[k] = {}
			at = _b.cell_to_local(k, n - 1)
			_b._press(at)
			# pushed just past its last letter, then let go
			for step in 3:
				_b._move(at - Vector2(0.0, _b._l("cell") * 0.2 * (step + 1)))
			_b._release(at - Vector2(0.0, _b._l("cell") * 0.6))
			_check("rusty dial comes round past its last letter (pos %d)" % st.pos[k], st.pos[k] == 0)
		80:
			print("failed ", _bad)
			quit()
			return true
	return false
