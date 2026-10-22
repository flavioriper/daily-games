extends Control

## One page of Honeycomb's tutorial, played by the board itself
## (puzzles/honeycomb2d.gd built with `demo`: silent, deaf, laid in this
## rect) and a finger that taps its cells and keys. `lesson` and `band` are
## set before it enters the tree. The hive is a fixed one from the band's
## bank, never today's, so a page never gives the day's words away.
##
## - SPELL: a short word of the hive spelt and sent; it flies into the jar.
## - QUEEN: four outer letters sent without the middle one, refused; then a
##   word with it, taken.
## - FULL: the hive's full comb spelt and sent: every cell rings.
## - WANDER (Insane): four words sent, and the queen flies to a new letter.
## - HINT: the bulb spells half a word, the finger spells the rest.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/honeycomb2d.gd")
const State = preload("res://puzzles/honeycomb_state.gd")
const Art = preload("res://ui/faces/honeycomb_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { SPELL, QUEEN, FULL, WANDER, HINT }

## The bank entry the pages show (today's is skipped for the next).
const ENTRY := 7
const FINGER_R := 26.0
const FINGER_ALPHA := 0.22
## How long the finger waits before each tap, and the page's rest at the end.
const TAP_WAIT := 0.32
const SEND_WAIT := 0.55
const REST := 1.8

var lesson: int = Lesson.SPELL
var band := 0
var _board: Control
var _over: Control
## What the finger does next: ["cell", letter], ["key", k], ["bulb"],
## ["rest", seconds].
var _steps: Array = []
var _wait := 0.0
var _rest := -1.0
var _bulb_at := -INF
var _finger := Vector2(-1, -1)
var _finger_at := -INF
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	resized.connect(func() -> void: _over.size = size)
	add_child(_over)
	_deal()

## The hive the pages show: a fixed entry of the band's bank, never today's.
static func hive(the_band: int) -> Dictionary:
	var bank: String = State.BANKS[the_band]
	var pool := InsaneBank.boards(bank)
	if pool.is_empty():
		return State.SPARE
	var today := InsaneBank.pick(bank, 0)
	var at := ENTRY % pool.size()
	if pool[at] == today:
		at = (at + 1) % pool.size()
	return pool[at]

func _deal() -> void:
	if _board != null:
		_board.queue_free()
	_board = Board.new()
	_board.demo = true
	_board.demo_day = hive(band)
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board)
	if _over != null:
		move_child(_over, -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022 + lesson
	_board.start(rng, band)
	_board.skip_entrance()
	_rest = -1.0
	_wait = 0.0
	_bulb_at = -INF
	_steps = _script(_board.state())

## The day's words of the hive, never shy, five letters first (a four is
## too often a clipped word), then six, then the rest.
static func _plain(st) -> Array[String]:
	var out: Array[String] = []
	for i in st.open_words():
		if not st.words.shy.has(i) and st.words.tier(i) == 0:
			out.append(st.words.words[i])
	out.sort_custom(func(a: String, b: String) -> bool:
		var ka := absi(a.length() - 5) * 2 + (1 if a.length() < 5 else 0)
		var kb := absi(b.length() - 5) * 2 + (1 if b.length() < 5 else 0)
		return ka < kb or (ka == kb and a < b))
	return out

func _spell(word: String) -> Array:
	var out := []
	for ch in word:
		out.append(["cell", ch])
	out.append(["key", Art.Key.ENTER])
	out.append(["rest", SEND_WAIT])
	return out

func _script(st) -> Array:
	var out := []
	var plain := _plain(st)
	var first: String = plain[mini(2, plain.size() - 1)] if not plain.is_empty() else ""
	match lesson:
		Lesson.SPELL:
			out += _spell(first)
		Lesson.QUEEN:
			var wrong := ""
			for ch in st.ring:
				if wrong.length() < 4:
					wrong += ch
			out += _spell(wrong)
			out += _spell(first)
		Lesson.FULL:
			out += _spell(_full_word(st))
		Lesson.WANDER:
			for k in State.FLIGHT:
				if k < plain.size():
					out += _spell(plain[k])
			out.append(["rest", 1.4])
		_:
			out.append(["bulb"])
	return out

## The hive's full comb: a day's word with all seven letters.
static func _full_word(st) -> String:
	var best := ""
	for i in st.words.inside(st.hive_mask, st.words.mask_of(st.queen), 3):
		var w: String = st.words.words[i]
		if st.words.masks[i] == st.hive_mask and not st.words.shy.has(i) and (best == "" or w.length() < best.length()):
			best = w
	return best

func _process(delta: float) -> void:
	if Motion.reduce:
		return
	_t += delta
	_over.queue_redraw()
	if _rest >= 0.0:
		_rest -= delta
		if _rest < 0.0:
			_deal()
		return
	if _steps.is_empty():
		if not _board.busy():
			_rest = REST
		return
	_wait += delta
	if _wait < (TAP_WAIT * 0.6 if lesson == Lesson.WANDER else TAP_WAIT):
		return
	_wait = 0.0
	var next: Array = _steps.pop_front()
	match String(next[0]):
		"cell":
			var c: int = _board.cell_of(String(next[1]))
			if c < 0:
				return
			_finger = _board.cell_to_local(c)
			_finger_at = _t
			_board.demo_tap(c)
		"key":
			_finger = _board.key_to_local(int(next[1]))
			_finger_at = _t
			_board.demo_key(int(next[1]))
		"rest":
			_wait = -float(next[1])
		_:
			_bulb_at = _t
			_board.hints_extra += 1
			_board.hint()
			# the finger spells the rest of the bulb's word
			var st = _board.state()
			var word: String = st.hinted[st.hinted.size() - 1] if not st.hinted.is_empty() else ""
			_wait = -0.8
			var rest := []
			for k in range(st.entry.length(), word.length()):
				rest.append(["cell", word[k]])
			rest.append(["key", Art.Key.ENTER])
			_steps = rest + _steps

func _draw_over() -> void:
	var e := _t - _finger_at
	if e < 0.35:
		var a := FINGER_ALPHA * (1.0 - e / 0.35)
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R * (1.0 + e), Color(Pal.TEXT, a))
	if lesson == Lesson.HINT and _t - _bulb_at < 2.0 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
