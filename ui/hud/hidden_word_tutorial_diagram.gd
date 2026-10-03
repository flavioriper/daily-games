extends Control

## One page of Hidden Word's tutorial: two rows of the board itself over the
## game's own keyboard, scaled down. The page holds a `Desk` --
## hidden_word2d.gd with its sounds, reactions, party, out-of-rows card and
## grass band taken out -- dealt a word of the player's language, and a real
## `KeyBoard` tray wired to it the way the host wires one, and plays the
## lesson on a loop: a finger taps the keys (each key presses and fires as a
## tap would), taps a bed of the row in hand through the board's own input,
## over a caption that says what it means. So a row turns over in its
## colours, the keys keep them, a refused guess shivers under its toast and
## the snail carries a sealed row exactly as on the board. `lesson` picks the
## page (set before it enters the tree):
##
## - GUESS: a word typed on the keys and Enter; the row turns over, and the
##   caption reads its green, amber and grey.
## - CLUES: with that row in, the keys wear its colours; the answer typed and
##   sent, the row all green.
## - TAP: a tap on a bed puts the next letter there, and the caret wraps
##   round; a wrong letter tapped and taken away with the back key.
## - HINT: the bulb drops a letter of the answer into its place.
## - ROWS: the last row spent and the word still hiding: the tiles droop, and
##   the caption offers one more row or the word.
## - STRICT: Hard and Insane: a guess that drops a green is refused, and the
##   toast names the letter and its place.
## - SNAIL: Insane's Snail Mail: a row turns over sealed, and its colours come
##   with the snail when the next row is sent.
##
## The board checkup, 2026-10-02: Hidden Word had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const State = preload("res://puzzles/hidden_word_state.gd")
const KeyBoard = preload("res://ui/flat/key_board.gd")

enum Lesson { GUESS, CLUES, TAP, HINT, ROWS, STRICT, SNAIL }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 22.0
const FINGER_ALPHA := 0.16
## A letter's tap: the finger over the key, down, up.
const KEY_TIME := 0.42
## The keyboard's share of the page's width.
const KEYS_W := 0.56
const CAPTION_H := 76.0

## The words, per language, each a real word of it (the board accepts any
## word here): the answer, a first guess that finds a green, two ambers and
## two greys, a second guess that keeps every clue it gave and is still
## wrong, and a guess that drops its green (refused on Hard).
const WORDS := {
	"en": {"answer": "about", "first": "coast", "second": "float", "bad": "after"},
	"pt": {"answer": "fazer", "first": "parte", "second": "saber", "bad": "mundo"},
	"es": {"answer": "hacer", "first": "parte", "second": "saber", "bad": "mucho"},
}

var lesson: int = Lesson.GUESS
## HINT: how many hints the band has.
var hints := 2

var _art: Desk
var _keys: Control
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh
var _words: Dictionary

## The board, quiet: no sound set (its id names none), no reactions, party
## or out-of-rows card, no grass band, two rows -- and it never ends: the
## loop deals the word again.
class Desk extends "res://puzzles/hidden_word2d.gd":
	const PAD := 10.0
	const TOP := 34.0
	## ROWS: the tiles droop when the rows run out. Elsewhere the last row
	## landing does nothing at all.
	var droops := false

	func puzzle_id() -> String:
		return "hiddenword_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)

	func check_solved() -> void:
		pass

	func _react(_r: int) -> void:
		pass

	func _party(_landed: float) -> void:
		pass

	func _open_card() -> void:
		pass

	func _run_out(landed: float) -> void:
		if droops:
			super(landed)

	func _build_band() -> ArrayMesh:
		return null

	## The snail at twice the board's size: the page's cells are small.
	func _ride_snail(t: float) -> void:
		super(t)
		if not is_instance_valid(_snail) or not _snail.visible:
			return
		var mid: Vector2 = _snail.position + _snail.size * 0.5
		_snail.size *= 2.0
		_snail.pivot_offset = _snail.size * 0.5
		_snail.position = mid - _snail.size * 0.5

	## The grid alone: no band at its foot, a tighter inset than the card's,
	## and room over it for the toast, which stands TOAST_RISE above the card.
	func _cell_for(available: float) -> float:
		var w := size.x - PAD * 2.0
		var h := available - PAD * 2.0 - TOP
		var n := _rows_f()
		return maxf(0.0, minf((w - GAP * float(State.LEN - 1)) / float(State.LEN),
			(h - GAP * (n - 1.0)) / n))

	func card_height(available: float) -> float:
		var c := _cell_for(available)
		var n := _rows_f()
		return minf(available, n * c + GAP * (n - 1.0) + PAD * 2.0 + TOP)

	func _card_top() -> float:
		return super() + TOP

	func _origin() -> Vector2:
		return Vector2((size.x - _block().x) * 0.5, _card_top() + PAD)

	## The word as the page deals it: `band`'s rules, two rows, `pre`
	## already in and settled, and the grid popped in with the board's
	## entrance when `enter`.
	func lay(band: int, answer: String, pre: Array, enter: bool) -> void:
		var st = state
		st.answer = Locale.fold(answer)
		st.written = answer
		st.rows.clear()
		st.marks.clear()
		st.typed = ""
		st.given.clear()
		st.broken = {}
		st.sent = 0
		st.seen = -1
		st.tries = 2
		st.hints_left = State.HINTS
		st.no_hints = false
		st.keeps_rows = band >= 2
		st.strict = band >= 2
		st.snail = band >= 3
		for word: String in pre:
			st.rows.append(word)
			st.marks.append(State.mark_guess(word, st.answer))
		st.sent = st.rows.size()
		st.seen = st.rows.size()
		_done = false
		out_of_hearts = false
		hints_used = 0
		_gen += 1
		_clear_rows()
		_grow_from = float(st.tries)
		_grow_at = -100.0
		_row_bought = false
		_clear_working()
		_given_at = {}
		_flip_at = -100.0
		_flip_row = -1
		_keys_due = []
		_cue_due = []
		_fx_due = []
		_react_due = []
		_droop_at = -100.0
		_clear_endings()
		var now := _now()
		for r in st.rows.size():
			_row_at[r] = now - 10.0
		if _tray != null:
			_tray.clear_marks()
			var marks: Dictionary = {}
			for word: String in st.rows:
				for i in State.LEN:
					marks[word[i]] = st.key_mark(word[i])
			_tray.set_marks(marks)
		_layout()
		if enter:
			_enter()
		else:
			_opened = now - 10.0
		_refresh()

## The keys as the page reads them: Desk's accept list is the language's,
## so a word that list lacks is let through here, as the lesson needs.
class DeskState extends "res://puzzles/hidden_word_state.gd":
	func accepts(_word: String) -> bool:
		return true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_words = WORDS.get(Locale.current(), WORDS.en)
	_art = Desk.new()
	_art.state = DeskState.new()
	add_child(_art)
	_keys = KeyBoard.new()
	add_child(_keys)
	# The page's keys are the finger's: a real tap on them would type into
	# the lesson.
	for chip: Control in _keys._chips:
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.set_meta("still", true)  # (it clicks, the phone does not knock)
	_keys.key.connect(func(l: String) -> void: _art.type_letter(l))
	_keys.commit.connect(func() -> void: _art.commit_row())
	_keys.erase.connect(func() -> void: _art.erase_letter())
	_art.set_tray(_keys)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 4
	_over.draw.connect(_draw_finger)
	add_child(_over)
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# One short line: a wrapping label measured before layout grows tall and
	# its centred text sinks under the buttons.
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	resized.connect(_layout)
	call_deferred("_layout")
	call_deferred("_start")

func _exit_tree() -> void:
	Motion.stop(_loop)
	_loop = null

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun and _loop == null:
		call_deferred("_start")

func _layout() -> void:
	if _art == null:
		return
	var k := size.x * KEYS_W / 1000.0
	var keys_h := KeyBoard.HEIGHT * k
	_keys.size = Vector2(1000.0, KeyBoard.HEIGHT)
	_keys.scale = Vector2(k, k)
	_keys.position = Vector2((size.x - 1000.0 * k) * 0.5, size.y - CAPTION_H - keys_h)
	_art.position = Vector2.ZERO
	_art.size = Vector2(size.x, maxf(0.0, size.y - CAPTION_H - keys_h))
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	Motion.stop(_loop)
	_reset(not _begun)
	_begun = true
	if Motion.reduce:
		_still()
		return
	var w: Dictionary = _words
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.2)
	match lesson:
		Lesson.GUESS:
			_type(String(w.first), "HTP_HW_TYPE_CAP")
			_enter("HTP_HW_ENTER_CAP")
			_loop.tween_interval(1.6)
			_say_for("HTP_HW_GREEN_CAP", 2.0)
			_say_for("HTP_HW_AMBER_CAP", 2.0)
			_say_for("HTP_HW_GREY_CAP", 2.4)
		Lesson.CLUES:
			_say_for("HTP_HW_KEYS_CAP", 2.2)
			_type(String(w.answer), "HTP_HW_USE_CAP")
			_enter("")
			_loop.tween_interval(1.4)
			_say_for("HTP_HW_FOUND_CAP", 2.8)
		Lesson.TAP:
			var a := String(w.answer)
			# Into bed four first; the caret wraps round to the first empty
			# bed after the fifth. A wrong third letter is tapped and taken
			# back, and the right one goes in its place.
			_tap_bed(3, "HTP_HW_BED_CAP")
			_type(a[3] + a[4] + a[0] + a[1], "")
			_type("x" if a[2] != "x" else "z", "")
			_loop.tween_interval(0.5)
			_tap_bed(2, "")
			_tap_key("Key_Erase", "HTP_HW_BACK_CAP")
			_loop.tween_interval(0.8)
			_type(a[2], "")
			_loop.tween_interval(0.4)
			_say_for("HTP_HW_READY_CAP", 2.6)
		Lesson.HINT:
			_say_for("HTP_HW_HINT_CAP", 0.6)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(1.8)
			_say_for("HTP_HW_GIVEN_CAP", 2.6)
		Lesson.ROWS:
			_type(String(w.second), "HTP_HW_LAST_CAP")
			_enter("")
			_loop.tween_interval(2.2)
			_say_for("HTP_HW_OUT_CAP", 3.2)
		Lesson.STRICT:
			_say_for("HTP_HW_STRICT_CAP", 1.2)
			_type(String(w.bad), "")
			_enter("")
			_loop.tween_interval(0.3)
			_say_for("HTP_HW_REFUSED_CAP", 2.8)
		Lesson.SNAIL:
			_type(String(w.first), "HTP_HW_SEALED_CAP")
			_enter("")
			_loop.tween_interval(1.4)
			_say_for("HTP_HW_WAIT_CAP", 1.6)
			_type(String(w.second), "")
			_enter("HTP_HW_MAIL_CAP")
			_loop.tween_interval(3.4)
	_loop.tween_callback(_reset)

## Types `word` on the keys, a tap a letter, the caption turned to `say`
## first (when not "").
func _type(word: String, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	for i in word.length():
		_tap_key("Key_%s" % word[i].to_upper(), "")

func _enter(say: String) -> void:
	_tap_key("Key_Enter", say)

## The finger over the key `name`, down, and up -- which fires it.
func _tap_key(name: String, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point_key.bind(name))
	_loop.tween_interval(KEY_TIME * 0.5)
	_loop.tween_callback(_key_button.bind(name, true))
	_loop.tween_interval(KEY_TIME * 0.3)
	_loop.tween_callback(_key_button.bind(name, false))
	_loop.tween_interval(KEY_TIME * 0.2)

## A tap on bed `c` of the row in hand, through the board's own input.
func _tap_bed(c: int, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point_bed.bind(c))
	_loop.tween_interval(0.45)
	_loop.tween_callback(_bed_button.bind(c, true))
	_loop.tween_interval(0.15)
	_loop.tween_callback(_bed_button.bind(c, false))
	_loop.tween_interval(0.5)

func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_callback(_lift)
	_loop.tween_interval(hold)

## Every lesson back to its question: the word with what the lesson starts
## from, the keys untouched or wearing it, nothing in flight. `fresh` is the
## first deal, which pops the grid in with the board's entrance.
func _reset(fresh := false) -> void:
	var w: Dictionary = _words
	var pre: Array = []
	var band := 0
	match lesson:
		Lesson.CLUES, Lesson.TAP, Lesson.HINT, Lesson.ROWS:
			pre = [Locale.fold(String(w.first))]
		Lesson.STRICT:
			pre = [Locale.fold(String(w.first))]
			band = 2
		Lesson.SNAIL:
			band = 3
	_art.droops = lesson == Lesson.ROWS
	_art.lay(band, String(w.answer), pre, fresh)
	_lift()
	match lesson:
		Lesson.HINT:
			_say("HTP_HW_STUCK_CAP")
		Lesson.STRICT:
			_say("HTP_HW_STRICT_CAP")
		Lesson.SNAIL:
			_say("HTP_HW_SEALED_CAP")
		_:
			_say("HTP_HW_START_CAP")

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var w: Dictionary = _words
	match lesson:
		Lesson.GUESS:
			_art.lay(0, String(w.answer), [Locale.fold(String(w.first))], false)
			_say("HTP_HW_GREEN_CAP")
		Lesson.CLUES:
			_art.lay(0, String(w.answer), [Locale.fold(String(w.first)), Locale.fold(String(w.answer))], false)
			_say("HTP_HW_FOUND_CAP")
		Lesson.TAP:
			_art.state.typed = Locale.fold(String(w.answer))
			_say("HTP_HW_BED_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_HW_GIVEN_CAP")
		Lesson.ROWS:
			_say("HTP_HW_OUT_CAP")
		Lesson.STRICT:
			_say("HTP_HW_REFUSED_CAP")
		Lesson.SNAIL:
			_say("HTP_HW_MAIL_CAP")
	_art._refresh()

func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the keys' and the board's own input ---

func _chip(name: String) -> Control:
	return _keys.find_child(name, true, false)

func _point_key(name: String) -> void:
	var chip := _chip(name)
	if chip == null:
		return
	_finger = get_global_transform().affine_inverse() * (chip.get_global_transform() * (chip.size * 0.5))
	_down = false

func _key_button(name: String, pressed: bool) -> void:
	var chip := _chip(name) as Button
	if chip == null:
		return
	_down = pressed
	if pressed:
		chip.button_down.emit()
	else:
		chip.button_up.emit()
		chip.pressed.emit()

func _point_bed(c: int) -> void:
	var r: int = _art.state.rows.size()
	_finger = _art.position + _art.cell_to_local(r, c)
	_down = false

func _bed_button(c: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _art.cell_to_local(_art.state.rows.size(), c)
	_down = pressed
	_art._gui_input(ev)

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

# --- drawing ---

func _draw_finger() -> void:
	if _finger.x < 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var at := _finger + Vector2(FINGER_R * 0.8, FINGER_R)
	var r := FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
