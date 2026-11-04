extends SceneTree

## Garden Fence's board under a hand, headless: posts strung by the board's
## own taps; a post from the side of the last refused and said; the trail's
## last post tapped again ties a word and the next starts on its last post;
## a word the garden does not know, one too short and one tied already are
## each refused and said; Undo takes back a letter, then a word; the bulb's
## first press reads a word and its second strings and ties it; the bin
## unties everything; the route tied solves at par and the day restores in
## bloom. On Insane the route ends on the gate.
##   godot --headless --path . --script tests/_probe_fence_board.gd

const Board = preload("res://puzzles/fence2d.gd")
const State = preload("res://puzzles/fence_state.gd")

var _b: Control
var _f := 0
var _bad := 0
var _wait := 0

func _day(band: int) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/insane/%s.json" % State.BANKS[band]))
	return doc.boards[5]

func _make(band: int, record := {}) -> void:
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
	if not record.is_empty():
		_b.completed_record = record
		_b.restore_completed_board()

func _check(what: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_bad += 1

## Taps `w` post by post from the joint, then its last post again.
func _tie_word(w: String) -> void:
	var st = _b.state()
	for k in w.length():
		if k == 0 and st.base() == 1:
			continue
		_b.demo_tap(st.post_of(w[k]))
	_b.demo_tap(st.post_of(w[w.length() - 1]))

## Three posts from three sides that spell nothing the garden knows.
func _nonsense(st) -> Array:
	for a in st.posts.size():
		for b in st.posts.size():
			for c in st.posts.size():
				if st.side_of(a) == st.side_of(b) or st.side_of(b) == st.side_of(c):
					continue
				var w: String = st.posts[a] + st.posts[b] + st.posts[c]
				if not st.knows(w):
					return [a, b, c]
	return []

func _process(_d: float) -> bool:
	if _wait > 0:
		_wait += 1
		if _b.busy() and _wait < 600:
			return false
		_wait = 0
	_f += 1
	var st = _b.state() if _b != null else null
	match _f:
		1:
			Locale._current = "en"
			_make(1)
		3:
			var w: String = st.route[0]
			_b.demo_tap(st.post_of(w[0]))
			_b.demo_tap(st.post_of(w[1]))
			_check("posts strung spell on the sign", st.trail_word() == w.substr(0, 2))
			var same := -1
			for p in st.posts.size():
				if st.side_of(p) == st.side_of(st.trail[-1]) and p != st.trail[-1]:
					same = p
			_b.demo_tap(same)
			_check("a post from the last one's side is refused", st.trail.size() == 2 and _b._say == "FN_SAY_SIDE")
			_b.demo_tap(st.trail[-1])
			_check("two letters are too short to tie", st.tied.is_empty() and _b._say == "FN_SAY_SHORT")
			st.trail.clear()
			_tie_word(w)
			_check("the last post tapped again ties the word", st.tied.size() == 1 and st.tied[0].word == w)
			_check("the next word starts on its last post", st.trail.size() == 1 and st.posts[st.trail[0]] == w.right(1))
			_check("a post the twine touched is used", st.is_used(st.post_of(w[0])))
		5:
			var n: Array = _nonsense(st)
			st.restart()
			for p in n:
				_b.demo_tap(p)
			_b.demo_tie()
			_check("a word the garden does not know is refused", st.tied.is_empty() and _b._say == "FN_SAY_UNKNOWN")
			_check("the refused trail stays to be mended", st.trail.size() == 3)
			_b.undo()
			_check("Undo takes back a letter", st.trail.size() == 2)
			st.trail.clear()
			_tie_word(st.route[0])
			var w: String = st.route[0]
			if w[0] == w.right(1):
				_tie_word(w)
				_check("a word tied already is refused", st.tied.size() == 1 and _b._say == "FN_SAY_AGAIN")
				st._rejoin()
			_b.undo()
			_check("Undo with no letters unties the last word", st.tied.is_empty() and st.trail.is_empty())
			_b.hint()
			_check("the bulb's first press reads a word", _b._say == "FN_READ" and not _b._reading.is_empty())
			_b.hint()
			_wait = 1
		6:
			pass
		7:
			_check("the bulb's second press strings and ties a word", st.tied.size() == 1 and st.tied[0].kind == "bulb")
			_b.reset_board()
			_check("the bin unties everything", st.tied.is_empty() and st.trail.is_empty())
			for w in st.route:
				_tie_word(w)
			_check("the route tied solves at par", st.solved() and st.tied.size() == st.par)
			_check("the board is done", _b.is_done())
			_check("three stars at par", st.stars() == 3)
			var rec: Dictionary = _b.completion_record()
			_make(1, rec)
		9:
			_check("the day restores in bloom", st.solved() and st.tied.size() == st.par)
			_make(3)
		11:
			for w in st.route:
				_tie_word(w)
			_check("Insane's route ends on the gate", st.solved() and st.ends_on_gate())
			_make(2)
		13:
			for w in st.route:
				_tie_word(w)
			_check("Hard's pentagon route solves", st.solved() and st.sides == 5)
			_make(0)
		15:
			for w in st.route:
				_tie_word(w)
			_check("Easy's triangle route solves", st.solved() and st.sides == 3)
		17:
			print("bad: %d" % _bad)
			quit(1 if _bad > 0 else 0)
	return false
