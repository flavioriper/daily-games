extends "res://core/puzzle_base.gd"

## Honeycomb (spec docs/superpowers/specs/2026-10-22-honeycomb-design.md): a
## words board. Seven letters in a comb of wax cells, the queen bee sitting
## on the middle one. Tap the cells to spell a word of four letters or more
## (letters used as often as you like, the middle one always), then the
## tick key to send it: a word pours honey into the jar's strip at the top,
## and the day is done when the honey reaches the band's line. On Insane
## (Wandering Queen) she flies to another cell every few words, and her
## letter is the one every word must hold after. The rules are
## puzzles/honeycomb_state.gd's and the words puzzles/honeycomb_words.gd's.
##
## **The meadow is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/honeycomb_world.gd) is the board's first child. From the
## top of the span down: the honey strip, the words found, the word being
## spelt, the comb, the three keys (take a letter back, shuffle, send) and
## the count line under them.
##
## A cell tapped bumps and its letter pops onto the end of the word; a word
## taken flies up into the strip, which swells, and the praise says how
## sweet it was; a full comb rings every cell. A word refused shivers, says
## why and fades. Shuffle slides the six outer letters to new cells. The
## bulb spells the first half of a word not yet found, the rest of it shown
## as dots. The queen's flight on Insane: she flies to the cell of her next
## letter, and the two letters trade cells so hers is in the middle again.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/honeycomb_tutorial_diagram.gd plays it with `demo_tap`/`demo_key`.

const State = preload("res://puzzles/honeycomb_state.gd")
const Words = preload("res://puzzles/honeycomb_words.gd")
const World = preload("res://puzzles/honeycomb_world.gd")
const Art = preload("res://ui/faces/honeycomb_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")

const Said = State.Said
const Key = Art.Key

const HAPTICS := {
	"tap": Haptics.TICK,
	"delete": Haptics.TICK,
	"shuffle": Haptics.TICK,
	"word": Haptics.TAP,
	"full": Haptics.GOOD,
	"refuse": Haptics.WARN,
	"found": Haptics.TICK,
	"fly": Haptics.TAP,
	"hint": Haptics.GOOD,
	"reset": Haptics.TAP,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## The pieces at W: a cell's radius to its corners and the gap between
## cells, a key's radius and the gap between keys.
const CELL_R := 122.0
const CELL_GAP := 12.0
const KEY_R := 70.0
const KEY_GAP := 90.0
## The rows at W: the strip, the words found, the word spelt, the gaps.
const STRIP_W := 760.0
const STRIP_H := 58.0
const FOUND_H := 196.0
const ENTRY_H := 120.0
const GAP := 26.0
const COUNT_H := 64.0
## Type at W: a cell's letter, the word spelt, the words found, the strip's
## numbers, the count line and the toast.
const CELL_SIZE := 92
const ENTRY_SIZE := 84
const FOUND_SIZE := 36
const FOUND_MIN := 26
const STRIP_SIZE := 30
const COUNT_SIZE := 32
const SAY_SIZE := 34
## The longest word spelt is drawn smaller past this many letters.
const ENTRY_FIT := 9
## A refused word's shiver and fade; a word taken flying to the strip; the
## shuffle's slide; the queen's flight (out to the cell, then the trade).
const REFUSE_TIME := 0.5
const TAKE_TIME := 0.45
const SHUFFLE_TIME := 0.32
const FLY_OUT := 0.55
const FLY_TRADE := 0.4
const SAY_TIME := 2.0
## The win: the cells' wave, how long the board's own win plays.
const WIN_HOLD := 1.4
const WAVE_STEP := 0.07
## The drifting bees: how many, their size in a cell's radius.
const DRIFTERS := 2
const DRIFT_SIZE := 0.32

## Built silent and deaf for the tutorial's page, and the hive it shows
## (a bank entry, never today's).
var demo := false
var demo_day := {}

var _st = State.new()
var _band := 0
var _t := 0.0
var _enter_at := 0.0
var _won_at := -INF
## Per cell: when it was last pressed.
var _press_at: Array[float] = []
## When each letter of the word spelt arrived.
var _typed_at: Array[float] = []
## A word leaving the line: {text, at, taken (into the strip) or refused}.
var _leaving := {}
## The shuffle under way: per ring cell, the cell its letter came from.
var _shuffle_from: Array[int] = []
var _shuffle_at := -INF
## The queen's flight under way: {cell, at, letter (her new), old}.
var _flight := {}
var _strip_at := -INF
var _say := ""
var _say_at := -INF
var _praise := ""
var _hint_word := ""
var _hint_at := -INF
var _pressing := -2
var _key_at: Array[float] = [-INF, -INF, -INF]
var _rng := RandomNumberGenerator.new()
## The layout.
var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _from := {}
var _lay_at := -INF
var _world: Control
var _units := {}
var _units_r := -1.0
var _bees: Array[ArrayMesh] = []
var _bee_s := -1.0
var _still: ArrayMesh
var _still_key := ""
var _rows: Array = []
var _rows_key := ""
var _rows_size := FOUND_SIZE
var fx: Node

func puzzle_id() -> String: return "honeycomb"
func title() -> String: return "Honeycomb"

func rules() -> String:
	var out := tr("HC_RULES")
	out += "\n\n" + tr("HC_RULES_HONEY")
	if _st.wandering():
		out += "\n\n" + tr("HC_RULES_WANDER") % State.FLIGHT
	out += "\n\n" + tr("HC_RULES_SCORE")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/honeycomb_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.SPELL, "HTP_HC_SPELL", tr("HTP_HC_SPELL_BODY")],
		[Diagram.Lesson.QUEEN, "HTP_HC_QUEEN", tr("HTP_HC_QUEEN_BODY")],
		[Diagram.Lesson.FULL, "HTP_HC_FULL", tr("HTP_HC_FULL_BODY")],
	]
	if _st.wandering():
		steps.append([Diagram.Lesson.WANDER, "HTP_HC_WANDER", tr("HTP_HC_WANDER_BODY") % State.FLIGHT])
	steps.append([Diagram.Lesson.HINT, "HTP_HC_HINT", tr("HTP_HC_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The bulb only: a word found is never taken back, and the keys under the
## comb do the rest. The bin empties the jar and starts the day over.
func capabilities() -> Array[String]:
	return ["hint"]

func hints_left() -> int:
	return maxi(0, int(State.HINTS[_band]) + hints_extra - hints_used)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if demo else Control.MOUSE_FILTER_STOP
	if not demo:
		fx = Fx2D.new()
		fx.name = "Fx"
		fx.haptics = HAPTICS
		add_child(fx)
	resized.connect(_relayout)
	if demo:
		_make_world()
		_relayout()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_band = clampi(difficulty, 0, 3)
	_rng.seed = rng.randi()
	if demo and not demo_day.is_empty():
		_st.band = _band
		_st.load_day(demo_day)
	else:
		_st.deal(rng, _band, bank_step)
	_fresh()
	_enter_at = _t
	_cue("enter")

## Every cell as dealt, nothing spelt, nothing moving.
func _fresh() -> void:
	_press_at.clear()
	for i in 7:
		_press_at.append(-INF)
	_typed_at.clear()
	_leaving = {}
	_shuffle_from.clear()
	_shuffle_at = -INF
	_flight = {}
	_say = ""
	_praise = ""
	_hint_word = ""
	_still_key = ""
	_rows_key = ""
	_relayout()

func day_dict() -> Dictionary:
	if _st.letters.is_empty():
		return {}
	var words: Array = []
	for i in _st.answers:
		words.append(_st.words.words[i])
	return {
		"source": "bank", "kind": "text",
		"payload": {"letters": _st.letters, "queen": _st.first_queen, "flight": _st.flight},
		"solution": {"words": words},
		"metrics": {"words": words.size(), "honey": _st.total, "line": _st.goal},
	}

# --- the moves ---

## The letter in cell `i`: 0 the middle (the queen's), 1..6 round it.
func letter_at(i: int) -> String:
	if i == 0:
		return _st.queen
	return _st.ring[i - 1] if i - 1 < _st.ring.size() else ""

## The player tapped cell `i`.
func _tap_cell(i: int) -> void:
	if is_done() or _won:
		return
	_settle()
	var ch: String = letter_at(i)
	if ch == "" or not _st.type(ch):
		_cue("refuse", 1.2, -6.0)
		return
	_press_at[i] = _t
	_typed_at.append(_t)
	_cue("tap", 1.0 + 0.03 * mini(_st.entry.length(), 12))
	if _hint_word != "" and not _hint_word.begins_with(_st.entry):
		_hint_word = ""

## The player pressed key `k`.
func _tap_key(k: int) -> void:
	if is_done() or _won:
		return
	_key_at[k] = _t
	match k:
		Key.DELETE:
			_settle()
			if _st.delete():
				_typed_at.pop_back()
				_cue("delete")
			else:
				_cue("refuse", 1.2, -8.0)
		Key.SHUFFLE:
			_shuffle()
		_:
			_send()

func _shuffle() -> void:
	_settle()
	var before: Array[String] = _st.ring.duplicate()
	_st.shuffle(_rng)
	_shuffle_from.clear()
	for ch in _st.ring:
		_shuffle_from.append(before.find(ch))
	_shuffle_at = _t
	_cue("shuffle")

## The word spelt, sent.
func _send() -> void:
	_settle()
	var text: String = _st.entry
	var said: int = _st.submit()
	_typed_at.clear()
	match said:
		Said.EMPTY:
			_cue("refuse", 1.2, -8.0)
			return
		Said.WORD, Said.FULL:
			if not demo:
				moves += 1
				moved.emit()
			var pts := Words.points(text, said == Said.FULL)
			_leaving = {"text": text, "at": _t, "taken": true, "points": pts}
			_strip_at = _t + TAKE_TIME
			_rows_key = ""
			_hint_word = ""
			if said == Said.FULL:
				_praise = "HC_FULL"
				_cue("full")
				if not demo and fx != null:
					for c in 7:
						fx.ring(_cell_pos(c), _l("r") * 1.1, Pal.SUN)
			else:
				_praise = "HC_NICE_1" if pts <= 1 else ("HC_NICE_2" if pts <= 6 else "HC_NICE_3")
				_cue("word", 1.0 + 0.04 * mini(text.length() - 4, 6))
				if not demo and fx != null:
					fx.sparkle(Vector2(size.x * 0.5, _l("entry_y")), Pal.SUN)
			_say_now(_praise)
			if _st.solved():
				_phase_solved()
			elif _st.flies_now():
				_fly()
		_:
			_leaving = {"text": text, "at": _t, "taken": false}
			match said:
				Said.SHORT: _say_now("HC_SAY_SHORT")
				Said.NO_QUEEN: _say_now("HC_SAY_QUEEN")
				Said.FOUND: _say_now("HC_SAY_FOUND")
				_: _say_now("HC_SAY_NOT")
			_cue("found" if said == Said.FOUND else "refuse")

## Insane: the queen flies on to the cell of her next letter.
func _fly() -> void:
	var old: String = _st.queen
	var cell: int = _st.fly()
	if cell < 0:
		return
	_flight = {"cell": cell + 1, "at": _t + TAKE_TIME, "letter": _st.queen, "old": old}
	_hint_word = ""
	var tree := get_tree()
	if tree != null and not demo:
		tree.create_timer(TAKE_TIME + 0.1, false).timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			_say_now("HC_SAY_FLY")
			_cue("fly"))

## Whatever is moving is finished at once (a quick finger never waits).
func _settle() -> void:
	_leaving = {}
	if not _flight.is_empty() and _t < float(_flight.at):
		_flight.at = _t - FLY_OUT - FLY_TRADE

func _phase_solved() -> void:
	check_solved()
	if not is_done():
		return
	var after := TAKE_TIME if not Motion.reduce else 0.0
	_won_at = _t + after + 0.25
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(after + 0.2, false).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		_cue("solved")
		if not demo and fx != null:
			fx.confetti(Vector2(size.x * 0.5, _l("comb_y")), 26, size.x * 0.7)
			# a full comb found on the way, with no bulb: the party
			_cue("party" if _st.fulls > 0 and hints_used == 0 else "confetti"))

func is_solved() -> bool:
	return _st.solved()

## The bulb: the first half of a day's word not yet found is spelt, the
## rest shown as dots.
func hint() -> bool:
	if hints_left() <= 0 or is_done():
		return false
	_settle()
	var word: String = _st.hint_word()
	if word == "":
		return false
	hints_used += 1
	_st.hinted.append(word)
	_st.entry = ""
	_typed_at.clear()
	var n := State.hint_letters(word)
	for k in n:
		_st.type(word[k])
		_typed_at.append(_t + k * 0.08)
	_hint_word = word
	_hint_at = _t
	_cue("hint")
	if not demo and fx != null:
		for c in 7:
			if word.left(n).contains(letter_at(c)):
				fx.ring(_cell_pos(c), _l("r"), Pal.SUN)
	return true

## The bin: the jar emptied, the day from the start.
func reset_board() -> void:
	if is_done():
		return
	_st.restart()
	moves = 0
	_fresh()
	_enter_at = _t
	_cue("reset")

func _say_now(key: String) -> void:
	_say = key
	_say_at = _t

func _cue(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch, volume_db)

## The tutorial's finger on cell `i`, and on key `k`.
func demo_tap(i: int) -> void:
	_tap_cell(i)

func demo_key(k: int) -> void:
	_tap_key(k)

func state():
	return _st

## The cell showing letter `ch`, or -1.
func cell_of(ch: String) -> int:
	for i in 7:
		if letter_at(i) == ch:
			return i
	return -1

func busy() -> bool:
	return not _leaving.is_empty() or (not _flight.is_empty() and _t < float(_flight.at) + FLY_OUT + FLY_TRADE)

## Where a finger tapping cell `i` goes, in this board's pixels, and one
## pressing key `k`.
func cell_to_local(i: int) -> Vector2:
	return _cell_pos(i)

func key_to_local(k: int) -> Vector2:
	return _key_pos(k)

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	if not _leaving.is_empty() and _t - float(_leaving.at) > (TAKE_TIME if bool(_leaving.taken) else REFUSE_TIME):
		_leaving = {}
	if not _flight.is_empty() and _t > float(_flight.at) + FLY_OUT + FLY_TRADE:
		_flight = {}
	if _say != "" and _t - _say_at > SAY_TIME:
		_say = ""
	queue_redraw()

# --- the fingers ---

func _gui_input(event: InputEvent) -> void:
	if demo:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var finger: int = event.index if event is InputEventScreenTouch else -1
		if event.pressed:
			if _pressing != -2:
				return
			_pressing = finger
			var k := key_at(event.position)
			if k >= 0:
				_tap_key(k)
				return
			var c := cell_at(event.position)
			if c >= 0:
				_tap_cell(c)
		elif finger == _pressing:
			_pressing = -2

## The cell a finger at `local` means: the nearest, within a cell's reach.
func cell_at(local: Vector2) -> int:
	if _L.is_empty():
		return -1
	var best := -1
	var far := INF
	for i in 7:
		var d := local.distance_to(_cell_pos(i))
		if d < far:
			far = d
			best = i
	return best if far < _l("r") * 0.95 else -1

## The key a finger at `local` means, within a key and a third of it.
func key_at(local: Vector2) -> int:
	if _L.is_empty():
		return -1
	for k in 3:
		if local.distance_to(_key_pos(k)) < _l("kr") * 1.3:
			return k
	return -1

# --- the layout ---

func _make_world() -> void:
	if _world != null:
		return
	_world = World.new()
	_world.name = "World"
	_world.show_behind_parent = true
	add_child(_world)
	move_child(_world, 0)

## What the host's rows cover, in this board's own pixels (laid full rect).
## On the win the board eases into the win's span.
func set_clear(top: float, bottom: float, won := false) -> void:
	if not _bled:
		_bled = true
		_make_world()
	_clear = Vector2(top, bottom)
	var was := _won
	_won = won
	if won and not was and not _L.is_empty():
		_from = _L.duplicate()
		_lay_at = _t
	_relayout()

func set_shift(x: float, leaving := false) -> void:
	_shift = x
	position.x = x
	if _world != null:
		_world.position.x = -x
		_world.visible = not leaving

func skip_entrance() -> void:
	_enter_at = -10.0

func _relayout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	_rows_key = ""
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		var horizon := float(_from.horizon) if _won and not _from.is_empty() else float(_L.horizon)
		_world.set_lines(horizon, Vector2(size.x * 0.5, float(_L.comb_y)), float(_L.comb_h) * 0.5, float(_L.keys_y) + float(_L.kr))
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 300.0 * u)
	var count_h := 0.0 if demo else COUNT_H
	var d := CELL_R * sqrt(3.0) + CELL_GAP
	var comb_h := 2.0 * d + CELL_R * sqrt(3.0)
	var comb_w := d * sqrt(3.0) + 2.0 * CELL_R
	# on the win the keys and the count are put away: the strip, the words
	# and the comb fill the win's span
	var keys_h := 0.0 if _won else GAP + KEY_R * 2.0 + 16.0 + count_h
	var found_h := FOUND_H if not demo else FOUND_H * 0.6
	var need := STRIP_H + GAP + found_h + GAP * 0.5 + ENTRY_H + GAP + comb_h + keys_h
	var k := minf(1.0, span / (need * u))
	# a narrow, tall span would leave the comb wider than the screen
	k = minf(k, (w * 0.96) / (comb_w * u))
	var s := u * k
	var y := top + (span - need * s) * 0.5 if span > need * s else top
	if span > need * s:
		# whatever the span leaves over is shared: most of it above the comb
		y = top + (span - need * s) * 0.3
	var strip_y := y + STRIP_H * 0.5 * s
	var found_top := strip_y + (STRIP_H * 0.5 + GAP) * s
	var entry_y := found_top + (found_h + GAP * 0.5 + ENTRY_H * 0.5) * s
	var comb_y := entry_y + (ENTRY_H * 0.5 + GAP) * s + comb_h * 0.5 * s
	var keys_y := comb_y + comb_h * 0.5 * s + (GAP + KEY_R) * s
	return {
		"u": u, "s": s, "top": top, "bottom": bottom,
		"horizon": entry_y - ENTRY_H * 0.25 * s,
		"strip_y": strip_y, "sw": STRIP_W * s, "sh": STRIP_H * s,
		"found_top": found_top, "found_h": found_h * s,
		"entry_y": entry_y, "comb_y": comb_y, "comb_h": comb_h * s,
		"r": CELL_R * s, "gap": CELL_GAP * s,
		"kr": KEY_R * s, "keys_y": keys_y, "count_y": keys_y + KEY_R * s + 50.0 * s,
	}

## A layout value, eased from the play's layout into the win's.
func _l(key: String) -> float:
	var v := float(_L.get(key, 0.0))
	if _from.is_empty() or not _from.has(key):
		return v
	var e := (_t - _lay_at) / 0.5
	if e >= 1.0:
		return v
	return lerpf(float(_from[key]), v, Motion.back_out(clampf(e, 0.0, 1.0)))

func _s() -> float:
	return float(_L.get("s", 1.0))

## The middle of cell `i` as it rests in the comb.
func _cell_pos(i: int) -> Vector2:
	return Vector2(size.x * 0.5, _l("comb_y")) + Art.cell_offset(i, _l("r"), _l("gap"))

func _key_pos(k: int) -> Vector2:
	var step := _l("kr") * 2.0 + KEY_GAP * _s()
	return Vector2(size.x * 0.5 + (k - 1) * step, _l("keys_y"))

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.letters.is_empty():
		return
	var r := _l("r")
	if absf(r - _units_r) > 0.5:
		_units_r = r
		_units = Art.units(r)
	_draw_still()
	_draw_found()
	for i in 7:
		_draw_cell(i)
	_draw_letters()
	_draw_bee()
	_draw_drifters()
	_draw_entry()
	_draw_count()

## The strip and the keys, one mesh while nothing changes.
func _draw_still() -> void:
	var swell := _t - _strip_at
	var pulse := []
	for k in 3:
		pulse.append(_t - _key_at[k] < Motion.BUMP_TIME)
	var share := clampf(float(_st.honey) / float(maxi(1, _st.goal)), 0.0, 1.0)
	var key := "%d:%d:%d:%.3f:%s:%s:%s" % [roundi(size.x), roundi(_l("strip_y")), roundi(_l("keys_y") * 4.0), share, str(pulse), _won, swell >= 0.0 and swell < Motion.BUMP_TIME]
	if key != _still_key or pulse.has(true) or (swell >= 0.0 and swell < Motion.BUMP_TIME):
		_still_key = key
		_still = _build_still(share, swell)
	draw_mesh(_still, null)
	# the strip's numbers: the honey over the line
	var font: Font = CozyTheme.display(800)
	var fs := roundi(STRIP_SIZE * _s())
	var text := "%d / %d" % [_st.honey, _st.goal]
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(size.x * 0.5 - tw * 0.5, _l("strip_y") + font.get_ascent(fs) * 0.36)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(8 * _s()), Color(Art.JAR, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)

func _build_still(share: float, swell: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var sz := Vector2(_l("sw"), _l("sh"))
	if swell >= 0.0 and swell < Motion.BUMP_TIME and not Motion.reduce:
		sz *= Motion.bump_scale(swell, 0.08)
	Art.strip(b, Vector2(size.x * 0.5, _l("strip_y")), sz, share)
	if not _won:
		for k in 3:
			var kr := _l("kr")
			var e: float = _t - _key_at[k]
			var lit: bool = e >= 0.0 and e < Motion.BUMP_TIME
			if lit and not Motion.reduce:
				kr *= Motion.bump_scale(e, 0.12)
			Art.key(b, _key_pos(k), kr, k, lit)
	return b.mesh()

## The words found, alphabetical, laid in rows across the box; smaller as
## they grow, and past what fits the newest are shown and the rest counted.
func _draw_found() -> void:
	var font: Font = CozyTheme.display(700)
	var key := "%d:%d:%d" % [_st.found.size(), roundi(size.x), roundi(_l("found_h"))]
	if key != _rows_key:
		_rows_key = key
		_lay_rows(font)
	var top := _l("found_top")
	var fs := roundi(_rows_size * _s())
	var line := fs * 1.3
	if _st.found.is_empty():
		var hint := tr("HC_NONE_YET")
		var hs := roundi(FOUND_MIN * _s())
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		draw_string(font, Vector2(size.x * 0.5 - hw * 0.5, top + line), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(Art.INK, 0.45))
		return
	for i in _rows.size():
		var row: String = _rows[i]
		var tw := font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(size.x * 0.5 - tw * 0.5, top + line * (i + 0.8))
		draw_string_outline(font, at, row, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(8 * _s()), Color(Pal.SURFACE, 0.85))
		draw_string(font, at, row, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)

func _lay_rows(font: Font) -> void:
	var shown: Array[String] = []
	for w in _st.found:
		var i: int = _st.words.find(w)
		var s: String = _st.words.shown(i) if i >= 0 else w.to_upper()
		shown.append(s.left(1) + s.substr(1).to_lower())
	shown.sort()
	var width := _l("sw") * 1.15
	var size_now := FOUND_SIZE
	while true:
		var fs := roundi(size_now * _s())
		var rows := _rows_for(shown, font, fs, width)
		var fit := floori(_l("found_h") / (fs * 1.3))
		if rows.size() <= fit or size_now <= FOUND_MIN:
			if rows.size() > fit:
				# the rest counted in the last row
				rows = rows.slice(0, maxi(1, fit))
				rows[rows.size() - 1] = tr("HC_MORE") % (shown.size() - _counted(rows))
			_rows = rows
			_rows_size = size_now
			return
		size_now -= 2

func _rows_for(shown: Array[String], font: Font, fs: int, width: float) -> Array:
	var rows := []
	var row := ""
	for s in shown:
		var next := s if row == "" else row + "   " + s
		if row != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			rows.append(row)
			row = s
		else:
			row = next
	if row != "":
		rows.append(row)
	return rows

func _counted(rows: Array) -> int:
	var n := 0
	for i in rows.size() - 1:
		n += String(rows[i]).split("   ").size()
	return n

## Where cell `i` is drawn now and how big.
func _cell_xf(i: int) -> Transform2D:
	var at := _cell_pos(i)
	var k := 1.0
	var e := _t - _press_at[i]
	if e >= 0.0 and e < Motion.BUMP_TIME and not Motion.reduce:
		k = Motion.bump_scale(e, -0.1)
	var d: float = _t - _enter_at - Motion.ENTER_DELAY - i * Motion.ENTER_STAGGER * 2.0
	if d >= 0.0 and d < Motion.POP_IN and not Motion.reduce:
		k *= Motion.pop_in_scale(d).x
	elif d < 0.0 and not Motion.reduce:
		k = 0.0
	if _phase_won() and not Motion.reduce:
		var wave := _t - _won_at - i * WAVE_STEP
		if wave >= 0.0:
			at.y -= Motion.hop_lift(fmod(wave, 1.3), Motion.SOLVE_HOP * 2.0 * float(_L.u), Motion.SOLVE_TIME)
	return Transform2D(0.0, Vector2.ONE * k, 0.0, at)

func _phase_won() -> bool:
	return is_done() and _won_at > -INF and _t >= _won_at

func _draw_cell(i: int) -> void:
	var xf := _cell_xf(i)
	if xf.get_scale().x <= 0.01:
		return
	draw_mesh(_units.shade, null, Transform2D(0.0, _cell_pos(i)))
	var e := _t - _press_at[i]
	if e >= 0.0 and e < Motion.BUMP_TIME * 1.5:
		draw_mesh(_units.press, null, xf, Color(1, 1, 1, 1.0 - e / (Motion.BUMP_TIME * 1.5)))
	draw_mesh(_units.queen if i == 0 else _units.cell, null, xf)

## The letters on the cells, sliding through a shuffle and the queen's trade.
func _draw_letters() -> void:
	var font: Font = CozyTheme.display(800)
	var fs := roundi(CELL_SIZE * _s())
	var asc := font.get_ascent(fs)
	var shuffle_k := clampf((_t - _shuffle_at) / SHUFFLE_TIME, 0.0, 1.0) if not Motion.reduce else 1.0
	shuffle_k = shuffle_k * shuffle_k * (3.0 - 2.0 * shuffle_k)
	for i in 7:
		var ch := letter_at(i)
		if ch == "":
			continue
		var xf := _cell_xf(i)
		if xf.get_scale().x <= 0.01:
			continue
		var at := xf.origin
		if i > 0 and shuffle_k < 1.0 and i - 1 < _shuffle_from.size() and _shuffle_from[i - 1] >= 0:
			at = _cell_pos(_shuffle_from[i - 1] + 1).lerp(at, shuffle_k)
		at = _flight_place(i, at)
		var up := ch.to_upper()
		var tw := font.get_string_size(up, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(at, 0.0, xf.get_scale())
		draw_string(font, Vector2(-tw * 0.5, asc * 0.36), up, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)
		draw_set_transform(Vector2.ZERO)

## Through the queen's trade, cell `i`'s letter rides from the other cell.
func _flight_place(i: int, at: Vector2) -> Vector2:
	if _flight.is_empty() or Motion.reduce:
		return at
	var cell := int(_flight.cell)
	if i != 0 and i != cell:
		return at
	var e := (_t - float(_flight.at) - FLY_OUT) / FLY_TRADE
	if e >= 1.0:
		return at
	var k := clampf(e, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var other := _cell_pos(cell if i == 0 else 0)
	return other.lerp(at, k)

## The queen on her cell, bobbing; through her flight, out to the cell of
## her next letter and back in with it.
func _draw_bee() -> void:
	var r := _l("r")
	var s := r * 0.62
	_bee_meshes(s)
	var home := _cell_pos(0) + Vector2(r * 0.42, -r * 0.62)
	var at := home
	if not _flight.is_empty() and not Motion.reduce:
		var cell := int(_flight.cell)
		var there := _cell_pos(cell) + Vector2(r * 0.42, -r * 0.62)
		var e := _t - float(_flight.at)
		if e >= 0.0 and e < FLY_OUT:
			var k := e / FLY_OUT
			k = k * k * (3.0 - 2.0 * k)
			at = home.lerp(there, k) + Vector2(0.0, -sin(k * PI) * r * 0.8)
		elif e >= FLY_OUT and e < FLY_OUT + FLY_TRADE:
			var k := (e - FLY_OUT) / FLY_TRADE
			k = k * k * (3.0 - 2.0 * k)
			at = there.lerp(home, k)
	if not Motion.reduce:
		at.y += sin(_t * 2.4) * r * 0.04
		if _phase_won():
			at.y -= Motion.hop_lift(fmod(_t - _won_at, 0.9), Motion.SOLVE_HOP * 2.0 * float(_L.u), Motion.SOLVE_TIME)
	var flap := 0 if Motion.reduce else int(_t * 14.0) % 2
	draw_mesh(_bees[flap], null, Transform2D(0.0, at))

func _bee_meshes(s: float) -> void:
	if absf(s - _bee_s) < 0.5 and _bees.size() == 2:
		return
	_bee_s = s
	_bees.clear()
	for flap in [0.0, 0.5]:
		var b := Face.Builder.new()
		Art.bee(b, Vector2.ZERO, s, flap)
		_bees.append(b.mesh())

## Two worker bees wandering round the comb, small, on slow loops that
## keep them off its letters.
func _draw_drifters() -> void:
	if Motion.reduce or demo or _bees.is_empty():
		return
	var flap := int(_t * 16.0) % 2
	var mid := Vector2(size.x * 0.5, _l("comb_y"))
	var reach := _l("comb_h") * 0.62
	for k in DRIFTERS:
		var ph := _t * (0.23 + 0.06 * k) * (1.0 if k == 0 else -1.0) + k * PI
		var wob := 1.0 + 0.08 * sin(_t * 1.3 + k * 2.0)
		var at := mid + Vector2(cos(ph) * minf(reach * 1.08, size.x * 0.46), sin(ph) * reach * 0.92) * wob
		var face := -signf(sin(ph)) * (1.0 if k == 0 else -1.0)
		if face == 0.0:
			face = 1.0
		var sc := DRIFT_SIZE / 0.62
		draw_mesh(_bees[flap], null, Transform2D(0.0, Vector2(sc * face, sc), 0.0, at))

## The word being spelt, its queen letters in honey; a word leaving flies
## up into the strip, or shivers and fades; the bulb's dots after it.
func _draw_entry() -> void:
	var font: Font = CozyTheme.display(800)
	var y := _l("entry_y")
	var text: String = _st.entry
	var e := 0.0
	var taken := false
	if not _leaving.is_empty():
		text = String(_leaving.text)
		e = _t - float(_leaving.at)
		taken = bool(_leaving.taken)
	var dots := ""
	if _leaving.is_empty() and _hint_word != "" and _hint_word.begins_with(text):
		dots = "·".repeat(_hint_word.length() - text.length())
	var n: int = text.length() + dots.length()
	var fs := roundi(ENTRY_SIZE * _s() * (1.0 if n <= ENTRY_FIT else float(ENTRY_FIT) / float(n)))
	var asc := font.get_ascent(fs)
	var up: String = text.to_upper()
	var full_w := font.get_string_size(up + dots, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := size.x * 0.5 - full_w * 0.5
	var shift := Vector2.ZERO
	var alpha := 1.0
	var k := 1.0
	if not _leaving.is_empty():
		if taken:
			var f := clampf(e / TAKE_TIME, 0.0, 1.0)
			f = f * f
			shift = Vector2(0.0, (_l("strip_y") - y) * f)
			k = lerpf(1.0, 0.35, f)
			alpha = 1.0 - f * 0.7
		else:
			var f := clampf(e / REFUSE_TIME, 0.0, 1.0)
			if not Motion.reduce:
				shift.x = sin(e * 46.0) * 10.0 * float(_L.u) * (1.0 - f)
			alpha = 1.0 - f
	draw_set_transform(Vector2(size.x * 0.5, y) + shift, 0.0, Vector2.ONE * k)
	var cx := x - size.x * 0.5
	for i in up.length():
		var ch := up[i]
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pk := 1.0
		if _leaving.is_empty() and i < _typed_at.size():
			var te := _t - _typed_at[i]
			if te < 0.0:
				cx += cw
				continue
			if te < Motion.POP_IN and not Motion.reduce:
				pk = Motion.pop_in_scale(te).x
		var colour := Art.HONEY_DEEP if text[i] == _st.queen else Art.INK
		if not _leaving.is_empty() and not taken:
			colour = Pal.BAD.lerp(Art.INK, 0.3)
		colour.a = alpha
		draw_set_transform(Vector2(size.x * 0.5, y) + shift + Vector2((cx + cw * 0.5) * k, 0.0), 0.0, Vector2.ONE * k * pk)
		draw_string(font, Vector2(-cw * 0.5, asc * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colour)
		cx += cw
	if dots != "":
		var pulse := 0.55 + 0.25 * sin((_t - _hint_at) * 4.0) if not Motion.reduce else 0.7
		draw_set_transform(Vector2(size.x * 0.5, y), 0.0, Vector2.ONE)
		draw_string(font, Vector2(cx, asc * 0.36), dots, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Art.HONEY_DEEP, pulse))
	draw_set_transform(Vector2.ZERO)
	# the caret, while nothing is spelt
	if text.is_empty() and _leaving.is_empty() and not is_done() and not demo:
		var blink := 1.0 if Motion.reduce else (0.5 + 0.5 * signf(sin(_t * 5.0)))
		var ch := asc * 0.8
		draw_line(Vector2(size.x * 0.5, y - ch * 0.5), Vector2(size.x * 0.5, y + ch * 0.4), Color(Art.HONEY_DEEP, 0.7 * blink), 5.0 * _s(), true)
	# the honey a word poured, floating up from where it left
	if not _leaving.is_empty() and taken and not demo:
		var pts := "+%d" % int(_leaving.points)
		var ps := roundi(SAY_SIZE * _s())
		var pw := font.get_string_size(pts, HORIZONTAL_ALIGNMENT_LEFT, -1, ps).x
		var f := clampf(e / TAKE_TIME, 0.0, 1.0)
		var at := Vector2(size.x * 0.5 + _l("sw") * 0.5 - pw, _l("strip_y") - _l("sh") * (0.6 + f * 0.8))
		draw_string_outline(font, at, pts, HORIZONTAL_ALIGNMENT_LEFT, -1, ps, roundi(8 * _s()), Color(Pal.SURFACE, 1.0 - f))
		draw_string(font, at, pts, HORIZONTAL_ALIGNMENT_LEFT, -1, ps, Color(Art.HONEY_DEEP, 1.0 - f))

## The words found and, on Insane, when the queen flies next; or the toast.
func _draw_count() -> void:
	if demo or _won:
		return
	var font: Font = CozyTheme.display(700)
	var y := _l("count_y")
	var s := float(_L.u)
	if _say != "":
		var text := tr(_say)
		if _say == "HC_SAY_FLY":
			text = text % _st.queen.to_upper()
		var fs := roundi(SAY_SIZE * s)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pk := Motion.pop_in_scale(_t - _say_at, 0.25).x if _t - _say_at < 0.25 and not Motion.reduce else 1.0
		draw_set_transform(Vector2(size.x * 0.5, y), 0.0, Vector2.ONE * pk)
		draw_string_outline(font, Vector2(-tw * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(10 * s), Color(Pal.SURFACE, 0.92))
		draw_string(font, Vector2(-tw * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
		draw_set_transform(Vector2.ZERO)
		return
	if is_done():
		return
	var n: int = _st.found.size()
	var text: String = (tr("HC_WORDS_ONE") if n == 1 else tr("HC_WORDS_N")) % n
	if _st.wandering():
		var left := State.FLIGHT - n % State.FLIGHT
		text += "  ·  " + (tr("HC_FLIES_ONE") if left == 1 else tr("HC_FLIES_N") % left)
	var cs := roundi(COUNT_SIZE * s)
	var cw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	var at := Vector2(size.x * 0.5 - cw * 0.5, y)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, roundi(10 * s), Color(Pal.SURFACE, 0.92))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Pal.TEXT)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func skill_quality() -> float:
	if _st.letters.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🐝 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var n: int = _st.found.size()
	var line: String = (tr("HC_WIN_ONE") if n == 1 else tr("HC_WIN_N")) % [n, _st.honey]
	if _st.fulls > 0:
		line += " " + tr("HC_WIN_FULL")
	elif _st.misses == 0:
		line += " " + tr("HC_WIN_CLEAN")
	return {"faces": [], "subtitle": line}

func completion_record() -> Dictionary:
	return {"found": Array(_st.found), "misses": _st.misses}

## A finished day reopens with its words in the jar.
func restore_completed_board() -> void:
	_st.finish(completed_record.get("found", []) as Array, int(completed_record.get("misses", 0)))
	_fresh()
	_enter_at = -10.0
	_won_at = -INF
	queue_redraw()
