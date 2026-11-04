extends SceneTree

## Stepping Stones' board under a hand, headless: a full line typed is laid
## at once; a word the brook does not know, one more than a letter off, one
## already on the way and the near bank's own are each refused and said; Undo
## lifts the last stone; the bulb's first press reads a letter and its second
## lays the stone; the bin lifts every stone; the route typed crosses at par
## and solves. On Easy the stone before the given calls it in, and Undo
## lifts the two together. Types through the board's own type_letter, as the
## tutorial does, so no window and no keyboard.
##   godot --headless --path . --script tests/_probe_stones_board.gd

const Board = preload("res://puzzles/stones2d.gd")
const State = preload("res://puzzles/stones_state.gd")

var _b: Control
var _f := 0
var _bad := 0
## Words still to type, one a frame once the line is clear.
var _queue: Array = []

func _day(band: int) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/insane/%s.json" % State.BANKS[band]))
	return doc.boards[5]

func _make(band: int) -> void:
	if _b != null:
		_b.queue_free()
	_b = Board.new()
	_b.demo = true
	_b.demo_day = _day(band)
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

func _type(w: String) -> void:
	for c in w:
		_b.type_letter(c)

func _process(_d: float) -> bool:
	_f += 1
	var st = _b.state() if _b != null else null
	if not _queue.is_empty() and _b != null and _b._typed == "":
		_type(String(_queue.pop_front()))
	match _f:
		1:
			Locale._current = "en"
			_make(1)
		3:
			_type(st.route[0])
		5:
			_check("a full line lays its stone", st.stones() == 1 and st.last() == st.route[0])
			_check("the line clears", _b._typed == "")
			var x: String = "q".repeat(st.n)
			_type(x)
		7:
			_check("a word not known is refused", st.stones() == 1 and _b._say == "SS_SAY_UNKNOWN")
			_check("the refused line stays to be mended", _b._typed.length() == st.n)
			_b._clear_line()
			_type(st.from)
		9:
			_check("the near bank's word is refused as used", st.stones() == 1 and _b._say == "SS_SAY_USED")
			_b._clear_line()
			# a real word two letters off: the far bank's word itself
			_type(st.to)
		11:
			_check("a word too far off is refused", st.stones() == 1 and _b._say in ["SS_SAY_OFF", "SS_SAY_OFF_SLIP"])
			_b._clear_line()
			_check("Undo is open", _b.can_undo())
			_b.undo()
			_check("Undo lifts the stone", st.stones() == 0)
			_b.demo_hint()
			_check("the bulb's first press reads", not _b._reading.is_empty() and st.stones() == 0 and _b._say == "SS_READ")
			_b.hint()
			_check("the second lays the stone", st.stones() == 1 and st.way[0].kind == "bulb" and _b._reading.is_empty())
			_b.reset_board()
			_check("the bin lifts every stone", st.stones() == 0)
			_queue = st.route.duplicate()
		20:
			_check("the route crosses", st.crossed and _b.is_solved())
			_check("at par with three stars", st.stones() == st.par and st.stars() == 3)
			_check("Undo is shut once across", not _b.can_undo())
			_make(0)
		22:
			_type(st.route[0])
		24:
			_check("Easy: the given is called in", st.stones() == 2 and st.given_in() and st.way[1].kind == "given")
			_b.undo()
			_check("Easy: Undo lifts the given with its stone", st.stones() == 0 and not st.given_in())
			_type(st.route[0])
		26:
			_type(st.route[2])
		28:
			_check("Easy: crossed at par", st.crossed and st.stones() == st.par)
			_make(3)
		30:
			var prev: String = st.from
			var swapped := false
			for w in st.route:
				if State.is_swap(prev, w):
					swapped = true
				prev = w
			_queue = st.route.duplicate()
			print("insane route has a swap: ", swapped)
		40:
			_check("Insane: the route crosses (swaps allowed)", st.crossed)
			# Easy: a stone a step from both the given and the far bank crosses
			var e = State.new()
			e.band = 0
			e.load_day({"from": "cold", "to": "card", "par": 1, "given": "word", "route": ["cord"]})
			e.offer("cord")
			_check("Easy: a stone a step from given and far bank crosses", e.crossed and e.stones() == 1 and not e.given_in())
			print("bad ", _bad)
			quit()
	return false
