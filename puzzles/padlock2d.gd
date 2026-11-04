extends "res://core/puzzle_base.gd"

## Padlock (spec docs/superpowers/specs/2026-11-04-padlock-design.md): a
## words board. A brass combination padlock hangs on a garden shed door; its
## face holds a row of letter dials, one per letter of the band's word
## length, each a strip of letters sliding behind a glass window. Drag a
## dial (or tap a letter on it) to bring a letter to the window; when the
## window spells a word the lock knows, its letters light gold on their
## dials and stay lit, and the word is hung on a brass tag under the lock.
## Light every letter on every dial and the shackle springs open. The rules
## are puzzles/padlock_state.gd's.
##
## **The door is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/padlock_world.gd) is the board's first child. From the top
## of the span down: the shackle, the lock, the line the board says things
## on, the found words' tags, the count. The stars and the letters still
## dark stand on a paper pill in the tools row's gap.
##
## A dial dragged rides the finger and ticks a notch for every letter that
## crosses the window; let go, it springs to the nearest letter. A word
## found makes the dials hop left to right, rings each letter it lights and
## swings its tag onto the ring. The bulb in two presses: the first rings
## the first letter of a word on a fewest path and every dark letter it
## would light, the second turns the dials to it, free. On Insane one dial
## is rusty and only turns down; pushed past its last letter it comes
## round to its first.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/padlock_tutorial_diagram.gd plays it with `demo_turn`.

const State = preload("res://puzzles/padlock_state.gd")
const World = preload("res://puzzles/padlock_world.gd")
const Art = preload("res://ui/faces/padlock_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")
const StarLine = preload("res://ui/flat/star_line.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const FLAT_HOST := "res://ui/flat/flat_host.gd"

const HAPTICS := {
	"set": Haptics.TICK,
	"word": Haptics.GOOD,
	"plain": Haptics.TICK,
	"again": Haptics.TICK,
	"refuse": Haptics.WARN,
	"round": Haptics.TAP,
	"fall": Haptics.TICK,
	"open": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## A dial's width at most, the gap between dials, a letter cell's height
## as a share of the dial's width, the brass round the slots.
const DIAL_W := 168.0
const DIAL_GAP := 18.0
const CELL_K := 0.74
const BODY_PAD := 40.0
## The shackle: its height and its steel's thickness.
const SHACKLE_H := 250.0
const SHACKLE_T := 36.0
const GAP := 26.0
const SAY_H := 76.0
const TAGS_H := 210.0
const COUNT_H := 56.0
const TAG_H := 62.0
const TAG_FONT := 36
const TAG_GAP := 12.0

const LETTER_K := 0.62
const SAY_SIZE := 38
const COUNT_SIZE := 30
const PILL_FONT := 28
const PILL_R := 21.0
const PILL_PAD := Vector2(18.0, 8.0)
const PILL_RIM := 2.0

## A finger moves this far (design px) before a press is a drag.
const DRAG_START := 14.0
## A dial's spring to its letter, how far it may be pulled past its ends,
## a word's hop, a tag's flight.
const SETTLE_TIME := 0.22
const OVERPULL := 0.4
const HOP_STEP := 0.05
const TAG_TIME := 0.45
const SHIVER_TIME := 0.35
const SAY_TIME := 2.2
## The win: the shackle's spring, the lock's swing, how long it holds.
const OPEN_TIME := 0.45
const SWING := 0.07
const WIN_HOLD := 1.7

var demo := false
var demo_day := {}

var _st = State.new()
var _band := 0
var _t := 0.0
var _enter_at := 0.0
var _won_at := -INF
var _open_at := -INF

## Each dial as drawn: where it is (letters from the top in the window,
## a float), its spring {from, to, at}, its hop and its shiver.
var _vis: Array[float] = []
var _anim: Array = []
var _hop_at: Array[float] = []
var _shiver_at: Array[float] = []
var _notch: Array[int] = []
## The letters drawn lit (the state's, once a word's light lands).
var _shown_lit := 0
## The finger: the dial held, where it went down, the dial's place then, a
## drag, the rusty dial's floor in this gesture.
var _pressing := -2
var _held := -1
var _press_pos := Vector2.ZERO
var _grab_v := 0.0
var _drag := false
var _floor := 0
var _rust_said := false
## The found words as tags: [{"word", "lit", "at"}], newest last.
var _tags: Array = []
var _bump_tag := -1
var _bump_tag_at := -INF
## The bulb's first press: the word and the cells it rings.
var _reading := {}
var _reading_at := -INF
var _say := ""
var _say_arg := ""
var _say_at := -INF
var _stars := StarLine.new()
## Things to do later on the board's own clock: [{"at", "fn"}].
var _due: Array = []
var _rng := RandomNumberGenerator.new()

var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _world: Control
var _pill: Control
var _body: ArrayMesh
var _body_key := ""
var _glass: ArrayMesh
var _strips := {}
var _strip_keys := {}
var _shackle: ArrayMesh
var _shackle_lift := -1.0
var _tags_mesh: ArrayMesh
var _tags_key := ""
var _pill_mesh: ArrayMesh
var fx: Node

func puzzle_id() -> String: return "padlock"
func title() -> String: return "Padlock"

func rules() -> String:
	var out := tr("PL_RULES")
	out += "\n\n" + tr("PL_RULES_LIGHT")
	if _st.rusty >= 0:
		out += "\n\n" + tr("PL_RULES_RUSTY")
	out += "\n\n" + tr("PL_RULES_PAR") % _st.par
	out += "\n\n" + tr("PL_RULES_HINT")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/padlock_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.TURN, "HTP_PL_TURN", tr("HTP_PL_TURN_BODY")],
		[Diagram.Lesson.LIGHT, "HTP_PL_LIGHT", tr("HTP_PL_LIGHT_BODY") % _st.par],
	]
	if _st.rusty >= 0:
		steps.append([Diagram.Lesson.RUSTY, "HTP_PL_RUSTY", tr("HTP_PL_RUSTY_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_PL_HINT", tr("HTP_PL_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The bulb only: dialling is free and a word found stays found, so there
## is nothing to undo and nothing to start over.
func capabilities() -> Array[String]:
	return ["hint"]

func can_reset() -> bool:
	return false

func hints_left() -> int:
	return _hints_held() + (1 if not _reading.is_empty() else 0)

func _hints_held() -> int:
	return maxi(0, int(State.HINTS[_band]) + hints_extra - hints_used)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if demo else Control.MOUSE_FILTER_STOP
	if not demo:
		fx = Fx2D.new()
		fx.name = "Fx"
		fx.haptics = HAPTICS
		add_child(fx)
		_pill = Control.new()
		_pill.name = "Pill"
		_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pill.z_index = 1
		_pill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pill.draw.connect(_draw_pill)
		add_child(_pill)
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

## Every dial as dealt, nothing moving.
func _fresh() -> void:
	var n: int = _st.length()
	_vis.clear()
	_anim.clear()
	_hop_at.clear()
	_shiver_at.clear()
	_notch.clear()
	for k in n:
		_vis.append(float(_st.pos[k]))
		_anim.append({})
		_hop_at.append(-INF)
		_shiver_at.append(-INF)
		_notch.append(_st.pos[k])
	_shown_lit = _st.lit
	_held = -1
	_drag = false
	_reading = {}
	_say = ""
	_tags.clear()
	for w in _st.found:
		_tags.append({"word": w, "lit": true, "at": -INF})
	_strip_keys = {}
	_body_key = ""
	_tags_key = ""
	_open_at = -INF
	_stars.clear(_st.stars())
	_relayout()

func day_dict() -> Dictionary:
	if _st.dials.is_empty():
		return {}
	var fair: Array = []
	for i in _st.fair:
		fair.append(_st.written(_st.words[i]))
	return {
		"source": "bank", "kind": "text",
		"payload": {"dials": Array(_st.dials), "start": Array(_st._start)},
		"solution": {"fair": fair},
		"metrics": {"par": _st.par, "words": _st.words.size(), "letters": _st.letter_count(), "rusty": _st.rusty},
	}

# --- the moves ---

func _press(p: Vector2) -> void:
	if is_done() or _won:
		return
	var k := dial_at(p)
	if k < 0:
		return
	_held = k
	_press_pos = p
	_grab_v = _vis_now(k)
	_anim[k] = {}
	_vis[k] = _grab_v
	_drag = false
	_floor = _st.pos[k]
	_rust_said = false

func _move(p: Vector2) -> void:
	if _held < 0:
		return
	var k := _held
	if not _drag and absf(p.y - _press_pos.y) > DRAG_START * _s():
		_drag = true
		_cue("pick", 1.0 + _rng.randf_range(-0.04, 0.04))
	if not _drag:
		return
	var n: int = _st.dials[k].length()
	var v := _grab_v - (p.y - _press_pos.y) / _l("cell")
	if k == _st.rusty:
		if v < float(_floor) - 0.12:
			v = float(_floor) - 0.12
			if not _rust_said:
				_rust_said = true
				_shiver_at[k] = _t
				_say_now("PL_SAY_RUSTY")
				_cue("refuse")
		if v > float(n - 1) + 0.45:
			# pushed past its last letter: round to the first
			_st.turn(k, n - 1)
			_st.turn(k, 0)
			_floor = 0
			_press_pos = p
			_grab_v = 0.0
			v = 0.0
			_notch[k] = 0
			_hop_at[k] = _t
			_cue("round")
	else:
		if v < 0.0:
			v = -OVERPULL * (1.0 - 1.0 / (1.0 - v / OVERPULL * 0.6))
		elif v > float(n - 1):
			var o := v - float(n - 1)
			v = float(n - 1) + OVERPULL * (1.0 - 1.0 / (1.0 + o / OVERPULL * 0.6))
	_vis[k] = v

func _release(p: Vector2) -> void:
	if _held < 0:
		return
	var k := _held
	_held = -1
	var n: int = _st.dials[k].length()
	if _drag:
		_drag = false
		var to := clampi(roundi(_vis[k]), 0, n - 1)
		if k == _st.rusty:
			to = maxi(to, _floor)
		_set_dial(k, to, _vis[k])
		return
	# a tap: the letter under the finger comes to the window
	var i: int = _st.pos[k] + roundi((p.y - _l("win_y")) / _l("cell"))
	if i < 0 or i >= n:
		return
	if i == _st.pos[k]:
		_hop_at[k] = _t
		_cue("set", 1.1)
		return
	if not _st.can_turn(k, i):
		_shiver_at[k] = _t
		_say_now("PL_SAY_RUSTY")
		_cue("refuse")
		return
	_set_dial(k, i, _vis[k])

## Dial `k` springs from `from` to letter `to`; the window is read as it
## lands.
func _set_dial(k: int, to: int, from: float) -> void:
	_st.turn(k, to)
	_anim[k] = {"from": from, "to": float(to), "at": _t}
	var land := _t + (SETTLE_TIME * 0.7 if not Motion.reduce else 0.0)
	if is_equal_approx(from, float(to)):
		_cue("set", 0.95 + 0.03 * k)
	else:
		_later(land, func() -> void: _cue("set", 0.95 + 0.03 * k))
	_read(land, false)

## Reads the window as the dials land: a word lights its letters, hops the
## dials and hangs its tag.
func _read(land: float, free: bool) -> void:
	var r: Dictionary = _st.read(free)
	if r.is_empty():
		return
	var w: String = r.word
	if bool(r.get("again", false)):
		_later(land, func() -> void:
			_bump_tag = _tag_index(w)
			_bump_tag_at = _t
			_say_now("PL_SAY_AGAIN", _st.written(w).to_upper())
			_cue("again"))
		return
	if not free and not demo:
		moves += 1
		moved.emit()
	_reading = {}
	var fresh: int = r.new
	var lit_now: int = _st.lit
	var cells := _cells_of(fresh)
	_tags.append({"word": w, "lit": fresh != 0, "at": land})
	_tags_key = ""
	_later(land, func() -> void:
		_shown_lit = lit_now
		for k in _st.length():
			_hop_at[k] = _t + k * HOP_STEP
		if fresh != 0:
			_cue("word", 1.0 + 0.05 * cells.size() + 0.02 * mini(_st.counted, 8))
			if fx != null:
				for c: Vector2i in cells:
					fx.ring(_cell_pos(c.x, c.y), _l("cell") * 0.6, Art.GOLD)
				fx.sparkle(Vector2(_l("mid_x"), _l("win_y")), Art.GOLD)
			if not _st.solved():
				_say_now("PL_SAY_WORD_ONE" if cells.size() == 1 else "PL_SAY_WORD_N", _st.written(w).to_upper(), cells.size())
		else:
			_cue("plain")
			_say_now("PL_SAY_PLAIN", _st.written(w).to_upper())
		_rate(true)
		_refresh_pill())
	if _st.solved():
		_phase_solved(land)
	_refresh_pill()

func _cells_of(m: int) -> Array:
	var out := []
	for k in _st.length():
		for i in _st.dials[k].length():
			if m & _st.bit(k, i) != 0:
				out.append(Vector2i(k, i))
	return out

func _tag_index(w: String) -> int:
	for i in _tags.size():
		if String(_tags[i].word) == w:
			return i
	return -1

func _phase_solved(land: float) -> void:
	check_solved()
	if not is_done():
		return
	_open_at = land + 0.3
	_won_at = land + 0.3
	_later(land + 0.3, func() -> void:
		_cue("open")
		_say_now("PL_PERFECT" if _st.counted + _st.helped <= _st.par else "PL_DONE"))
	_later(land + 0.6, func() -> void:
		_cue("solved")
		if fx != null:
			fx.confetti(Vector2(size.x * 0.5, _l("body_y")), 28, size.x * 0.7)
		var perfect: bool = _st.counted <= _st.par and hints_used == 0
		_cue("party" if perfect else "confetti"))

func is_solved() -> bool:
	return _st.solved()

## The bulb in two presses. The first, one hint, rings the first letter of
## a word on a fewest path and every dark letter it would light; the
## second turns the dials to it, free.
func hint() -> bool:
	if is_done():
		return false
	if _reading.is_empty():
		if _hints_held() <= 0:
			return false
		var w: String = _st.hint_word()
		if w == "":
			return false
		hints_used += 1
		var m: int = _st.mask_of(w)
		var cells := _cells_of(m & ~_st.lit)
		var first := Vector2i(0, _st.dials[0].find(w[0]))
		if not cells.has(first):
			cells.push_front(first)
		_reading = {"word": w, "cells": cells, "first": first}
		_reading_at = _t
		var n := _cells_of(m & ~_st.lit).size()
		_say_now("PL_READ", w[0].to_upper(), n)
		_cue("hint")
		if fx != null:
			for c: Vector2i in cells:
				fx.ring(_cell_pos(c.x, c.y), _l("cell") * 0.6, Art.GOLD)
		moved.emit()
		_refresh_pill()
		return true
	var word: String = _reading.word
	_reading = {}
	_held = -1
	_drag = false
	for k in _st.length():
		var i: int = _st.dials[k].find(word[k])
		_anim[k] = {"from": _vis_now(k), "to": float(i), "at": _t + k * 0.04}
	_st.dial_to(word)
	_cue("hint", 1.12)
	_read(_t + SETTLE_TIME + _st.length() * 0.04, true)
	moved.emit()
	return true

func reset_board() -> void:
	pass

# --- helpers ---

func _say_now(key: String, arg := "", n := -1) -> void:
	_say = key
	_say_arg = arg
	_say_n = n
	_say_at = _t

var _say_n := -1

func _later(at: float, fn: Callable) -> void:
	_due.append({"at": at, "fn": fn})

func _cue(name: String, pitch := 1.0, volume_db := 0.0, gap := -1) -> void:
	if demo or fx == null:
		return
	if gap >= 0:
		fx.cue(name, pitch, volume_db, gap)
	else:
		fx.cue(name, pitch, volume_db)

## The stars read once a word (`heard`: a star lost falls with a low note).
func _rate(heard: bool) -> void:
	if demo:
		return
	if _stars.rate(_st.stars(), _t, heard and not is_done()) < 0:
		_cue("fall", 0.9)
	_refresh_pill()

func _refresh_pill() -> void:
	if _pill != null:
		_pill.queue_redraw()

func busy() -> bool:
	for a: Dictionary in _anim:
		if not a.is_empty():
			return true
	return not _due.is_empty()

## Where dial `k` stands now as drawn, springing or not.
func _vis_now(k: int) -> float:
	var a: Dictionary = _anim[k]
	if a.is_empty():
		return _vis[k]
	var e := clampf((_t - float(a.at)) / SETTLE_TIME, 0.0, 1.0) if not Motion.reduce else 1.0
	return lerpf(float(a.from), float(a.to), Motion.back_out(e) if e > 0.0 else 0.0)

# --- the tutorial's hands ---

## The tutorial's finger turning dial `k` to letter `i`.
func demo_turn(k: int, i: int) -> void:
	_set_dial(k, i, _vis_now(k))

func demo_hint() -> void:
	hints_extra += 1
	hint()

func state():
	return _st

## The middle of the letter cell `i` of dial `k`, where the dial stands now.
func cell_to_local(k: int, i: int) -> Vector2:
	return _cell_pos(k, i)

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	for k in _anim.size():
		var a: Dictionary = _anim[k]
		if not a.is_empty() and (Motion.reduce or _t - float(a.at) > SETTLE_TIME):
			_vis[k] = float(a.to)
			_anim[k] = {}
	# a notch for every letter that crosses the window, dragged or springing
	for k in _notch.size():
		var v := roundi(_vis_now(k))
		if v != _notch[k]:
			_notch[k] = v
			_cue("notch", 0.92 + 0.05 * k + 0.02 * clampi(v, 0, 6), 0.0, 25)
	if not _due.is_empty():
		var now: Array = []
		var keep: Array = []
		for d: Dictionary in _due:
			if _t >= float(d.at):
				now.append(d)
			else:
				keep.append(d)
		_due = keep
		for d: Dictionary in now:
			if is_instance_valid(self):
				(d.fn as Callable).call()
	if _say != "" and _t - _say_at > SAY_TIME:
		_say = ""
	queue_redraw()
	if _pill != null and (_stars.busy(_t) or _t - _enter_at < 1.0):
		_pill.queue_redraw()

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
			_press(event.position)
		elif finger == _pressing:
			_pressing = -2
			_release(event.position)
	elif event is InputEventScreenDrag:
		if event.index == _pressing:
			accept_event()
			_move(event.position)
	elif event is InputEventMouseMotion:
		if _pressing == -1:
			accept_event()
			_move(event.position)

## The dial a finger at `local` means: the column it is over, inside the
## lock's body (and a little round it).
func dial_at(local: Vector2) -> int:
	if _L.is_empty():
		return -1
	var body: Rect2 = _L.body
	if not body.grow(_l("cell") * 0.4).has_point(local):
		return -1
	var best := -1
	var far := INF
	for k in _st.length():
		var d := absf(local.x - _dial_x(k))
		if d < far:
			far = d
			best = k
	return best if far <= (_l("dial_w") + _l("dial_gap")) * 0.5 else -1

# --- the layout ---

func _make_world() -> void:
	if _world != null:
		return
	_world = World.new()
	_world.name = "World"
	_world.show_behind_parent = true
	add_child(_world)
	move_child(_world, 0)

func set_clear(top: float, bottom: float, won := false) -> void:
	if not _bled:
		_bled = true
		_make_world()
	_clear = Vector2(top, bottom)
	_won = won
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
	if size.x <= 0.0 or size.y <= 0.0 or _st.dials.is_empty():
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	_body_key = ""
	_strip_keys = {}
	_tags_key = ""
	_shackle_lift = -1.0
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		_world.set_lines(_L.staple, (_L.body as Rect2).size.x * 0.42, Vector2.ZERO, 0.0 if demo else float(_L.count_y) + COUNT_H * float(_L.s))
	_refresh_pill()
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 300.0 * u)
	var n: int = _st.length()
	var deep := 1
	for d in _st.dials:
		deep = maxi(deep, d.length())
	var rows := 2 * deep - 1
	var dial_w := minf(DIAL_W, (W * 0.9 - BODY_PAD * 2.0 - DIAL_GAP * (n - 1)) / float(n))
	var cell := dial_w * CELL_K
	var body_w := dial_w * n + DIAL_GAP * (n - 1) + BODY_PAD * 2.0
	var body_h := cell * rows + BODY_PAD * 2.0
	var shackle_h := minf(SHACKLE_H, body_w * 0.42)
	var below := 0.0 if (_won or demo) else GAP + SAY_H + TAGS_H + COUNT_H
	if demo:
		below = GAP * 0.4 + SAY_H
	var need := shackle_h + body_h + below
	var k := minf(1.0, span / (need * u))
	k = minf(k, (w * 0.96) / (body_w * u))
	var s := u * k
	var y := top + maxf(0.0, (span - need * s) * (0.35 if not _won else 0.5))
	var body := Rect2(w * 0.5 - body_w * s * 0.5, y + shackle_h * s, body_w * s, body_h * s)
	var win_y := body.position.y + body.size.y * 0.5
	var say_y := body.end.y + (GAP + SAY_H * 0.5) * s
	var tags_y := say_y + SAY_H * 0.5 * s
	return {
		"u": u, "s": s, "top": top, "bottom": bottom,
		"body": body, "body_y": body.get_center().y, "mid_x": w * 0.5,
		"dial_w": dial_w * s, "dial_gap": DIAL_GAP * s, "cell": cell * s, "pad": BODY_PAD * s,
		"win_y": win_y, "shackle_h": shackle_h * s, "shackle_t": SHACKLE_T * s,
		"staple": Vector2(w * 0.5, body.position.y - shackle_h * s * 0.82),
		"say_y": say_y if not demo else body.end.y + (GAP * 0.4 + SAY_H * 0.5) * s,
		"tags_y": tags_y, "tags_h": TAGS_H * s,
		"count_y": tags_y + (TAGS_H + COUNT_H * 0.6) * s,
	}

## A layout value.
func _l(key: String) -> float:
	return float(_L.get(key, 0.0))

func _s() -> float:
	return float(_L.get("s", 1.0))

func _dial_x(k: int) -> float:
	var n: int = _st.length()
	var span := _l("dial_w") * n + _l("dial_gap") * (n - 1)
	return _l("mid_x") - span * 0.5 + _l("dial_w") * 0.5 + k * (_l("dial_w") + _l("dial_gap"))

## The middle of letter `i` on dial `k` where the dial is drawn now (its
## hop and the lock's swing left out).
func _cell_pos(k: int, i: int) -> Vector2:
	return Vector2(_dial_x(k), _l("win_y") + (float(i) - _vis_now(k)) * _l("cell"))

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.dials.is_empty():
		return
	var lock := _lock_xf()
	_draw_shackle(lock)
	_draw_body(lock)
	var font: Font = CozyTheme.display(800)
	var fs := roundi(_l("cell") * LETTER_K)
	for k in _st.length():
		_draw_dial(k, lock, font, fs)
	draw_set_transform_matrix(lock)
	draw_mesh(_glass, null)
	draw_set_transform(Vector2.ZERO)
	_draw_reading(lock)
	_draw_tags()
	_draw_say()
	_draw_count()

## The lock's swing on the win, about the staple; and its drop in.
func _lock_xf() -> Transform2D:
	var at: Vector2 = _L.staple
	var rot := 0.0
	var k := 1.0
	if not Motion.reduce:
		var e := _t - _enter_at - Motion.ENTER_DELAY
		if e < 0.0:
			k = 0.0
		elif e < Motion.POP_IN * 1.5:
			k = Motion.pop_in_scale(e / 1.5).x
		if _open_at > -INF and _t >= _open_at:
			var o := _t - _open_at
			rot = SWING * sin(o * 7.0) * exp(-o * 1.6)
	return Transform2D(rot, Vector2.ONE * k, 0.0, at) * Transform2D(0.0, -at)

func _draw_shackle(lock: Transform2D) -> void:
	var lift := 0.0
	if _open_at > -INF and _t >= _open_at:
		var e := clampf((_t - _open_at) / OPEN_TIME, 0.0, 1.0)
		lift = Motion.back_out(e) if not Motion.reduce else 1.0
	elif is_done() and _won_at == -INF:
		lift = 1.0
	if _shackle == null or absf(lift - _shackle_lift) > 0.001:
		_shackle_lift = lift
		var b := Face.Builder.new()
		var body: Rect2 = _L.body
		Art.shackle(b, body.get_center().x, body.position.y, body.size.x * 0.62, _l("shackle_h") + _l("shackle_t"), _l("shackle_t"), lift)
		_shackle = b.mesh()
	draw_set_transform_matrix(lock)
	draw_mesh(_shackle, null)
	draw_set_transform(Vector2.ZERO)

func _draw_body(lock: Transform2D) -> void:
	var key := "%s:%d" % [str(_L.body), _st.rusty]
	if key != _body_key or _body == null:
		_body_key = key
		var b := Face.Builder.new()
		var body: Rect2 = _L.body
		Art.body(b, body, 1.0 if _st.rusty >= 0 else 0.0)
		var cell := _l("cell")
		for k in _st.length():
			var n: int = _st.dials[k].length()
			var h := cell * (2 * n - 1) + cell * 0.3
			var r := Rect2(_dial_x(k) - _l("dial_w") * 0.5, _l("win_y") - h * 0.5, _l("dial_w"), h)
			Art.slot(b, r, k == _st.rusty)
			if k == _st.rusty:
				Art.arrow(b, Vector2(_dial_x(k), r.position.y - _l("pad") * 0.5), _l("pad") * 0.28)
		_body = b.mesh()
		var g := Face.Builder.new()
		var n_all: int = _st.length()
		var x0 := _dial_x(0) - _l("dial_w") * 0.5
		var x1 := _dial_x(n_all - 1) + _l("dial_w") * 0.5
		Art.window(g, Rect2(x0, _l("win_y") - cell * 0.56, x1 - x0, cell * 1.12))
		_glass = g.mesh()
	draw_set_transform_matrix(lock)
	draw_mesh(_body, null)
	draw_set_transform(Vector2.ZERO)

## One dial: its strip of cells (one cached mesh under a transform, rebuilt
## when its lit letters change) and a letter on each.
func _draw_dial(k: int, lock: Transform2D, font: Font, fs: int) -> void:
	var n: int = _st.dials[k].length()
	var cell := _l("cell")
	var lit_bits := 0
	for i in n:
		if _shown_lit & _st.bit(k, i) != 0:
			lit_bits |= 1 << i
	var key := "%d:%d:%d" % [lit_bits, roundi(cell * 10.0), 1 if _st.rusty == k else 0]
	if _strip_keys.get(k, "") != key:
		_strip_keys[k] = key
		var b := Face.Builder.new()
		var sz := Vector2(_l("dial_w") * 0.84, cell * 0.9)
		for i in n:
			Art.cell(b, Vector2(0.0, i * cell), sz, lit_bits & (1 << i) != 0)
		_strips[k] = b.mesh()
	var v := _vis_now(k)
	var y := _l("win_y") - v * cell
	var x := _dial_x(k)
	if not Motion.reduce:
		# dropping in, left to right
		var d := _t - _enter_at - Motion.ENTER_DELAY - 0.12 - k * Motion.ENTER_STAGGER * 3.0
		if d < 0.0:
			y -= cell * 1.5
		elif d < Motion.POP_IN * 1.6:
			y -= cell * 1.5 * (1.0 - Motion.back_out(d / (Motion.POP_IN * 1.6)))
		var h := _t - _hop_at[k]
		if h >= 0.0 and h < Motion.SOLVE_TIME:
			y += Motion.hop_lift(h, Motion.SOLVE_HOP * 1.6 * _s(), Motion.SOLVE_TIME)
		var sh := _t - _shiver_at[k]
		if sh >= 0.0 and sh < SHIVER_TIME:
			x += sin(sh * 48.0) * 7.0 * _s() * (1.0 - sh / SHIVER_TIME)
	var xf := lock * Transform2D(0.0, Vector2(x, y))
	draw_set_transform_matrix(xf)
	draw_mesh(_strips[k], null)
	var asc := font.get_ascent(fs)
	for i in n:
		var ly := i * cell
		var off := absf(float(i) - v)
		var lit := lit_bits & (1 << i) != 0
		var ink: Color = Art.GOLD_INK if lit else Art.INK
		if off > 0.5:
			ink = Color(ink, 0.72)
		var ch := _st.letter(k, i).to_upper()
		var tw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(-tw * 0.5, ly + asc * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_set_transform(Vector2.ZERO)

## The bulb's first press: a gold ring round the word's first letter and
## every dark letter it would light, pulsing.
func _draw_reading(lock: Transform2D) -> void:
	if _reading.is_empty():
		return
	var b := Face.Builder.new()
	var pulse := 0.6 + 0.4 * sin((_t - _reading_at) * 5.0) if not Motion.reduce else 1.0
	var h := Vector2(_l("dial_w") * 0.48, _l("cell") * 0.52)
	for c: Vector2i in _reading.cells:
		var at := _cell_pos(c.x, c.y)
		var wide := 9.0 * _s() if c == _reading.first else 7.0 * _s()
		b.stroke(Face.Builder.round_rect(at - h, h * 2.0, h.y * 0.35), wide, Color(Art.GOLD_DEEP if c != _reading.first else Pal.GOOD, 0.95 * pulse), true)
	_reading_mesh = b.mesh()
	draw_set_transform_matrix(lock)
	draw_mesh(_reading_mesh, null)
	draw_set_transform(Vector2.ZERO)

var _reading_mesh: ArrayMesh

## The found words' tags under the lock, in rows from the key ring, newest
## last; a new one swings in from the window. One mesh while none moves.
func _tag_slots() -> Array:
	var font: Font = CozyTheme.display(700)
	var out := []
	if _tags.is_empty():
		return out
	var s := _s()
	var fs := TAG_FONT
	var widths: Array[float] = []
	var k := 1.0
	for attempt in 6:
		widths.clear()
		var rows := 1
		var x := 0.0
		var limit := size.x * 0.9 / (s * k)
		for t: Dictionary in _tags:
			var tw := font.get_string_size(_st.written(String(t.word)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + TAG_H * 0.9
			widths.append(tw)
			if x > 0.0 and x + tw > limit:
				rows += 1
				x = 0.0
			x += tw + TAG_GAP
		if rows * (TAG_H + TAG_GAP) * k <= TAGS_H:
			break
		k *= 0.84
	# lay them out row by row, each row centred
	var limit2 := size.x * 0.9 / (s * k)
	var rows_of: Array = [[]]
	var x2 := 0.0
	for i in _tags.size():
		if x2 > 0.0 and x2 + widths[i] > limit2:
			rows_of.append([])
			x2 = 0.0
		rows_of[-1].append(i)
		x2 += widths[i] + TAG_GAP
	out.resize(_tags.size())
	var y := _l("tags_y") + TAG_GAP * s
	for row: Array in rows_of:
		var total := -TAG_GAP
		for i in row:
			total += widths[i] + TAG_GAP
		var x := size.x * 0.5 - total * s * k * 0.5
		for i in row:
			out[i] = {"rect": Rect2(x, y, widths[i] * s * k, TAG_H * s * k), "fs": roundi(fs * s * k)}
			x += (widths[i] + TAG_GAP) * s * k
		y += (TAG_H + TAG_GAP) * s * k
	return out

func _draw_tags() -> void:
	if demo or _won or _tags.is_empty():
		return
	var slots := _tag_slots()
	var moving := false
	for t: Dictionary in _tags:
		if _t - float(t.at) < TAG_TIME and not Motion.reduce:
			moving = true
	var bumping := _bump_tag >= 0 and _t - _bump_tag_at < Motion.BUMP_TIME
	var key := "%d:%s" % [_tags.size(), str(_L.get("tags_y", 0))]
	var b := Face.Builder.new()
	var font: Font = CozyTheme.display(700)
	var texts := []
	for i in _tags.size():
		var t: Dictionary = _tags[i]
		var r: Rect2 = slots[i].rect
		var e := (_t - float(t.at)) / TAG_TIME if not Motion.reduce else 1.0
		if e < 0.0:
			continue
		var at := r.position
		var k := 1.0
		if e < 1.0:
			var from := Vector2(_l("mid_x") - r.size.x * 0.5, _l("win_y"))
			var q := Motion.back_out(clampf(e, 0.0, 1.0))
			at = from.lerp(r.position, q) + Vector2(0.0, -sin(clampf(e, 0.0, 1.0) * PI) * 60.0 * _s())
			k = lerpf(0.6, 1.0, q)
		if bumping and i == _bump_tag:
			k *= Motion.bump_scale(_t - _bump_tag_at, 0.16)
		var rr := Rect2(at + r.size * (1.0 - k) * 0.5, r.size * k)
		Art.tag(b, rr, bool(t.lit))
		texts.append([rr, _st.written(String(t.word)).to_upper(), roundi(int(slots[i].fs) * k), bool(t.lit)])
	if b.verts.is_empty():
		return
	if moving or bumping or key != _tags_key or _tags_mesh == null:
		_tags_key = key if not moving and not bumping else ""
		_tags_mesh = b.mesh()
	draw_mesh(_tags_mesh, null)
	for tx: Array in texts:
		var rr: Rect2 = tx[0]
		var fs: int = tx[2]
		var tw := font.get_string_size(tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var hole := rr.size.y * 0.55
		var at := Vector2(rr.position.x + hole + (rr.size.x - hole - tw) * 0.5, rr.get_center().y + font.get_ascent(fs) * 0.36)
		draw_string(font, at, tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.GOLD_INK if tx[3] else Color(Art.INK, 0.75))

## What the board says, under the lock: a word found, praise, why a dial
## would not turn.
func _draw_say() -> void:
	if _say == "" or _t < _say_at:
		return
	var font: Font = CozyTheme.display(800)
	var text := tr(_say)
	if _say_n >= 0 and _say_arg != "":
		text = text % [_say_arg, _say_n]
	elif _say_n >= 0:
		text = text % _say_n
	elif _say_arg != "" and text.contains("%s"):
		text = text % _say_arg
	var good := _say in ["PL_SAY_WORD_ONE", "PL_SAY_WORD_N", "PL_PERFECT", "PL_DONE", "PL_READ"]
	var fs := roundi(SAY_SIZE * (1.2 if good else 1.0) * _s())
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > size.x * 0.94:
		fs = roundi(fs * size.x * 0.94 / tw)
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var e := _t - _say_at
	var pk := Motion.pop_in_scale(e, 0.25).x if e < 0.25 and not Motion.reduce else 1.0
	var fade := clampf((SAY_TIME - e) / 0.4, 0.0, 1.0)
	var ink := Art.BRASS_DARK.darkened(0.3) if good else Pal.TEXT
	var asc := font.get_ascent(fs)
	var y := _l("say_y") if not _won else float((_L.body as Rect2).end.y) + 60.0 * _s()
	draw_set_transform(Vector2(size.x * 0.5, y), 0.0, Vector2.ONE * pk)
	draw_string_outline(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(12 * _s()), Color(Pal.SURFACE, 0.92 * fade))
	draw_string(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, fade))
	draw_set_transform(Vector2.ZERO)

## At the foot: the words found of all the lock knows, and on Insane the
## rule.
func _draw_count() -> void:
	if demo or _won or is_done():
		return
	var font: Font = CozyTheme.display(700)
	var text: String = tr("PL_FOUND_N") % [_st.found.size(), _st.words.size()]
	if _st.rusty >= 0:
		text += "  ·  " + tr("PL_RUSTY")
	var cs := roundi(COUNT_SIZE * float(_L.u))
	var cw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	if cw > size.x * 0.94:
		cs = roundi(cs * size.x * 0.94 / cw)
		cw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	var at := Vector2(size.x * 0.5 - cw * 0.5, _l("count_y"))
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, roundi(10 * float(_L.u)), Color(Pal.SURFACE, 0.92))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Pal.TEXT)

## The count pill in the tools row's gap: the stars the way stands at, then
## the letters still dark.
func _draw_pill() -> void:
	if not _bled or _won or _st.dials.is_empty():
		return
	var enter := 1.0 if Motion.reduce else Motion.pop_in_scale(_t - _enter_at - Motion.ENTER_DELAY).x
	if enter <= 0.0:
		return
	var font: Font = CozyTheme.body(700)
	var dark: int = _st.dark_count()
	var text: String = tr("PL_DARK_ONE") if dark == 1 else tr("PL_DARK_N") % dark
	var fs := PILL_FONT
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ss := 0.9
	var sw := StarLine.width(ss)
	var pill := Vector2(sw + 14.0 + tw, 2.0 * PILL_R) + 2.0 * PILL_PAD
	var gap := float(load(FLAT_HOST).GAP)
	var c := Vector2(size.x * 0.5, _clear.x - gap - FlatTopBar.BUTTON.y * 0.5)
	var corner := c - pill * 0.5
	var rim := Vector2.ONE * PILL_RIM
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	_pill_mesh = b.mesh()
	_pill.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_pill.draw_mesh(_pill_mesh, null)
	var x0 := corner.x + PILL_PAD.x
	_stars.draw(_pill, Vector2(x0 + StarLine.R * ss, c.y), ss, _t)
	var base := c.y - font.get_height(fs) * 0.5 + font.get_ascent(fs)
	_pill.draw_string(font, Vector2(x0 + sw + 14.0, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.TEXT, 0.8))
	_pill.draw_set_transform(Vector2.ZERO)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func skill_quality() -> float:
	if _st.dials.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🔓 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	# the bulb's words are free for the stars, but the count is every word
	var all: int = _st.counted + _st.helped
	var line: String
	if all <= _st.par:
		line = tr("PL_WIN_PAR") % all
	else:
		line = tr("PL_WIN") % [all, _st.par]
	return {"faces": [], "subtitle": line}

func completion_record() -> Dictionary:
	return {"counted": _st.counted, "helped": _st.helped, "stars": _st.stars(), "found": Array(_st.found)}

## A finished day reopens open, its words kept.
func restore_completed_board() -> void:
	_st.finish()
	_st.counted = int(completed_record.get("counted", _st.par))
	_st.helped = int(completed_record.get("helped", 0))
	_st.found.clear()
	for w in completed_record.get("found", []):
		_st.found.append(String(w))
	if not _st.found.is_empty():
		_st.dial_to(_st.found[-1])
	_fresh()
	_enter_at = -10.0
	_won_at = -INF
	_open_at = -INF
	queue_redraw()
