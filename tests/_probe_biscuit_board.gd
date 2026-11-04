extends SceneTree

## Biscuit Tin's board under a finger, headless: a tap lays a piece on the
## plate, a fifth is refused, a tap on a plate piece takes it back with the
## ones after it, a tap on the bare plate clears it, a word found scores
## and is said again the second time, a biscuit's four pieces bake it and
## leave the tin, and the bulb's two presses lay one whole for nothing.
## Calls the board's own _tap, so no window and no pointer.
##   godot --headless --path . --script tests/_probe_biscuit_board.gd

const Board = preload("res://puzzles/biscuit2d.gd")
const State = preload("res://puzzles/biscuit_state.gd")
const Diagram = preload("res://ui/hud/biscuit_tutorial_diagram.gd")

var _b: Control
var _f := 0
var _bad := 0
var _keep := {}

func _tin(band: int) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/insane/%s.json" % State.BANKS[band]))
	return doc.boards[3]

func _make(band: int) -> void:
	if _b != null:
		_b.queue_free()
	_b = Board.new()
	_b.demo = true
	_b.demo_day = _tin(band)
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

func _tap(i: int) -> void:
	_b._tap(_b.piece_to_local(i))

func _process(_d: float) -> bool:
	_f += 1
	var st = _b.state() if _b != null else null
	match _f:
		1:
			_make(1)
		3:
			var b0: Array = st.biscuits[0]
			var b1: Array = st.biscuits[1]
			_tap(b0[0])
			_check("a tap lays a piece on the plate", st.plate == [b0[0]])
			_tap(b0[1])
			_tap(b1[0])
			_tap(b1[1])
			_check("four on the plate", st.plate.size() == 4)
			_tap(b0[2])
			_check("a fifth is refused", st.plate.size() == 4 and not st.on_plate(b0[2]))
			_keep.b0 = b0
		30:
			# pieces have landed; take back the second and every one after it
			var b0: Array = _keep.b0
			_tap(b0[1])
			_check("a plate piece goes back with the ones after it (%s)" % str(st.plate), st.plate == [b0[0]])
		50:
			var at: Vector2 = (_b._L.plate as Rect2).position + Vector2(20, (_b._L.plate as Rect2).size.y * 0.5)
			_b._tap(at)
			_check("the bare plate tapped clears it", st.plate.is_empty())
		60:
			var run: Array = Diagram.short_word(st)
			_keep.run = run
			_keep.found = st.found.size()
			_keep.points = st.points
			for i in run:
				_tap(i)
			_check("a short word is found (%s, found %s, points %d)" % [st.plate_word(), st.found, st.points], st.found.size() == int(_keep.found) + 1 and st.points == int(_keep.points) + State.POINTS[run.size()])
			_keep.found = st.found.size()
			_keep.points = st.points
		90:
			var run: Array = _keep.run
			_tap(run[0])
			for i in run:
				_tap(i)
			_check("the same word again scores nothing", st.found.size() == int(_keep.found) and st.points == int(_keep.points))
		120:
			st.clear_plate()
			_b._retarget()
			var before: int = st.points
			for i in st.biscuits[0]:
				_tap(int(i))
			_check("a biscuit's four pieces bake it", st.whole == [0] and st.points == before + 8)
			_check("its pieces leave the tin", st.in_tin().size() == st.pieces.size() - 4)
		200:
			var before: int = st.points
			_b.demo_hint()
			_check("the bulb's first press rings a piece", not _b._reading.is_empty())
			_b.hint()
			_keep.before = before
		360:
			_check("the bulb's second press lays a biscuit for nothing", st.whole.size() == 2 and st.points == int(_keep.before) and st.helped == 1)
			_check("nothing still flying (due %d bakes %d)" % [_b._due.size(), _b._bakes.size()], not _b.busy())
		362:
			print("bad ", _bad)
			quit()
	return false
