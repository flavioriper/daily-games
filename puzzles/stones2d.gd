extends "res://core/puzzle_base.gd"

## Stepping Stones (spec docs/superpowers/specs/2026-11-04-stepping-stones-design.md):
## a words board. A brook runs across the screen between two grassy banks;
## a slab on the near bank (top) bears the start word, one on the far bank
## (bottom) the word to reach. A stone is a word one letter from the one
## before: type it on the phone's own keyboard and it drops into the brook
## under the last. A stone a step from the far bank's word makes the
## crossing. Letters already matching the far bank stand on moss; the letter
## a stone changed is inked gold. The rules are puzzles/stones_state.gd's.
##
## **The brook is the whole screen** (`"bleed": true`, `"tray": "none"`):
## the flat host lays this board full rect and says what its rows cover
## (`set_clear`); the world (puzzles/stones_world.gd) is the board's first
## child. As Five Clues does, the board holds an unseen LineEdit the phone's
## keyboard types into and lays itself out above the keyboard while it is up
## (`_osk`): the near bank under the tools row, the stones, the waiting
## stone, the line the board says things on, the far bank just above the
## keys. Past what fits, the oldest stones fold into one pebble ("+3").
##
## A line is judged the moment it holds the band's length (Enter judges
## sooner): laid, the stone drops in with a splash; refused, the waiting
## stone shivers and the board says why. Undo lifts the last stone, the bin
## all of them. The bulb in two presses: the first rings the letter to change
## (or names the stone to go back to from a dead end), the second lays the
## stone. On Easy the middle stone waits mossy at the brook's side and comes
## into the way when a stone reaches it; on Insane (Slippery) a swap of two
## letters side by side is a stone too.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/stones_tutorial_diagram.gd plays it with `type_letter` and
## `commit_row`.

const State = preload("res://puzzles/stones_state.gd")
const World = preload("res://puzzles/stones_world.gd")
const Art = preload("res://ui/faces/stones_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")
const StarLine = preload("res://ui/flat/star_line.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const FLAT_HOST := "res://ui/flat/flat_host.gd"
const ThemedPictures = preload("res://core/themed_pictures.gd")

const Said = State.Said

const HAPTICS := {
	"type": Haptics.TICK,
	"erase": Haptics.TICK,
	"lay": Haptics.TAP,
	"join": Haptics.GOOD,
	"refuse": Haptics.WARN,
	"again": Haptics.TICK,
	"undo": Haptics.TICK,
	"clear": Haptics.TICK,
	"fall": Haptics.TICK,
	"bank": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
	"theme": Haptics.GOOD,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## A row (a stone and the water round it) at most and at least, the letter
## cell at most, a stone's height as a share of its row.
const ROW_MAX := 150.0
const ROW_MIN := 70.0
const ROW_TIGHT := 60.0
const CELL_MAX := 92.0
const STONE_K := 0.74
const PAD := 0.5
const SAY_H := 64.0
const MARGIN := 14.0
## How far each stone sits off the middle, alternately, as the way zigzags.
const ZIG := 34.0
const LETTER_K := 0.62
const SAY_SIZE := 36
const PILL_FONT := 28
const PILL_R := 21.0
const PILL_PAD := Vector2(18.0, 8.0)
const PILL_RIM := 2.0
## Room left between the far bank and the phone's keyboard.
const OSK_GAP := 10.0
## The motions: a stone's drop, a lifted one's rise, Easy's given sliding
## in, the crossing's wave, what the board says.
const DROP_H := 70.0
const LIFT_TIME := 0.3
const JOIN_TIME := 0.45
const WAVE_STEP := 0.09
const SAY_TIME := 2.4
const WIN_HOLD := 1.5
## The current's drift, design px a second.
const DRIFT := 18.0
## The daily theme (2026-11-06): on a daily dealt from its day the crossing
## comes from the band's bank entry holding the night's strongest theme
## word, a bank's word first, else a stone of its route (Easy's given too).
## The word wears a sun (Art.sun_mark) baked into its slab's or stone's mesh:
## a bank's from the start, a stone's as it is laid. Reaching it plays the
## theme cue with a sparkle THEME_AT after the far bank's, the solve waiting
## THEME_SHIFT more; a stone laid says SS_SAY_THEME. The win card waits
## THEME_HOLD longer and names the word.
const THEME_AT := 0.12
const THEME_SHIFT := 0.2
const THEME_HOLD := 0.45
## The sun's radius against a stone's height.
const MARK_K := 0.22

var demo := false
var demo_day := {}

var _st = State.new()
var _band := 0
var _t := 0.0
var _enter_at := 0.0
var _cross_at := -INF
var _won_at := -INF
var _typed := ""
## The line last refused (so the same letters are not judged twice).
var _refused := ""
var _field: LineEdit
var _osk := 0.0
var osk_override := -1.0
## When each stone of the way was laid (by index), lifted stones still
## rising [{"word", "at", "t", "size"}], when Easy's given joined.
var _born: Array[float] = []
var _gone: Array = []
var _join_at := -INF
var _join_from := Vector2.ZERO
var _shake_at := -INF
## The bulb's first press: the stone it reads.
var _reading := {}
var _reading_at := -INF
var _say := ""
var _say_args: Array = []
var _say_at := -INF
var _stars := StarLine.new()
var _due: Array = []
var _rng := RandomNumberGenerator.new()
## The day's theme: {"word" (folded), "at": "to", "from" or "way"}, {} on a
## plain deal. The harness's seam: a pool set here before the deal stands in
## for the night's (Backend is not started in a --script run).
var _theme := {}
static var theme_pool_override: Array = []

var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _world: Control
var _pill: Control
var _meshes := {}
var _current: ArrayMesh
var _current_key := ""
var _pill_mesh: ArrayMesh
var fx: Node

func puzzle_id() -> String: return "stones"
func title() -> String: return "Stepping Stones"

func rules() -> String:
	var out := tr("SS_RULES") % _st.n
	if _st.swaps:
		out += "\n\n" + tr("SS_RULES_SLIP")
	if _st.given != "":
		out += "\n\n" + tr("SS_RULES_GIVEN")
	out += "\n\n" + tr("SS_RULES_MOSS")
	out += "\n\n" + tr("SS_RULES_PAR") % [_st.par, _st.par + State.THREE]
	out += "\n\n" + tr("SS_RULES_UNDO")
	out += "\n\n" + tr("SS_RULES_HINT")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/stones_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.STEP, "HTP_SS_STEP", tr("HTP_SS_STEP_BODY")],
		[Diagram.Lesson.CROSS, "HTP_SS_CROSS", tr("HTP_SS_CROSS_BODY") % _st.par],
	]
	if _st.given != "":
		steps.append([Diagram.Lesson.GIVEN, "HTP_SS_GIVEN", tr("HTP_SS_GIVEN_BODY")])
	if _st.swaps:
		steps.append([Diagram.Lesson.SLIP, "HTP_SS_SLIP", tr("HTP_SS_SLIP_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_SS_HINT", tr("HTP_SS_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func capabilities() -> Array[String]:
	return ["undo", "hint"]

func can_undo() -> bool:
	return _st.can_undo() and not is_done()

func can_reset() -> bool:
	return not is_done()

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
		_make_field()
	resized.connect(_relayout)
	if demo:
		_make_world()
		_relayout()

# --- the keyboard (Five Clues' way) ---

## The line the phone's keyboard types into: unseen, laid over the waiting
## stone, never touched itself (the board's _gui_input calls it up). It
## keeps editing across Enter so the keyboard stays up between stones.
func _make_field() -> void:
	_field = LineEdit.new()
	_field.name = "Field"
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.max_length = 8
	_field.context_menu_enabled = false
	_field.selecting_enabled = false
	_field.middle_mouse_paste_enabled = false
	_field.keep_editing_on_text_submit = true
	_field.virtual_keyboard_enabled = true
	var none := StyleBoxEmpty.new()
	for box in ["normal", "focus", "read_only"]:
		_field.add_theme_stylebox_override(box, none)
	for ink in ["font_color", "font_placeholder_color", "caret_color", "selection_color", "font_selected_color"]:
		_field.add_theme_color_override(ink, Color(0, 0, 0, 0))
	_field.text_changed.connect(_on_typed)
	_field.text_submitted.connect(func(_s: String) -> void: commit_row())
	add_child(_field)

func _summon() -> void:
	if _field == null or is_done() or clock_held or _st.crossed:
		return
	if not _field.has_focus():
		_field.edit()
	elif _osk <= 0.0 and osk_override < 0.0 and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		# Android's back hides the keyboard and leaves the field focused
		_field.unedit()
		_field.edit()

func _exit_tree() -> void:
	_dismiss()

func _dismiss() -> void:
	if _field != null and _field.has_focus():
		_field.unedit()
		_field.release_focus()

## What the keyboard typed: letters only, as many as a stone holds; a full
## line is judged at once.
func _on_typed(text: String) -> void:
	if is_done() or _st.crossed:
		if text != "":
			_field.text = ""
		return
	var kept := ""
	for c in text.to_upper():
		if c.to_lower() != c.to_upper() and kept.length() < _st.n:
			kept += c
	if kept != text.to_upper():
		_field.text = kept
		_field.caret_column = kept.length()
	_set_typed(kept)

func _set_typed(kept: String) -> void:
	var was := _typed
	_typed = kept
	if _typed.length() > was.length():
		_cue("type", 0.96 + 0.03 * _typed.length() + _rng.randf_range(-0.02, 0.02))
	elif _typed.length() < was.length():
		_cue("erase")
	if _typed.length() == _st.n and _typed != _refused:
		_offer.call_deferred()

func _clear_line() -> void:
	_typed = ""
	_refused = ""
	if _field != null and _field.text != "":
		_field.text = ""

## The tutorial's hands type through these; a player types into _field.
func type_letter(letter: String) -> void:
	if is_done() or _st.crossed or _typed.length() >= _st.n:
		return
	_set_typed(_typed + letter.to_upper())

func erase_letter() -> void:
	if _typed == "":
		return
	_set_typed(_typed.substr(0, _typed.length() - 1))

## Enter: the line offered.
func commit_row() -> void:
	if is_done() or _st.crossed:
		return
	_offer()

# --- the deal ---

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_band = clampi(difficulty, 0, 3)
	_rng.seed = rng.randi()
	_st = State.new()
	_st.band = _band
	if demo and not demo_day.is_empty():
		_theme = {}
		_st.load_day(demo_day)
	else:
		var entry := _themed_entry()
		if entry.is_empty():
			_st.deal(rng, _band, bank_step)
		else:
			_st.load_day(entry)
	if _field != null:
		_field.max_length = _st.n
	_fresh()
	_enter_at = _t
	_cue("enter")
	_summon.call_deferred()

func _fresh() -> void:
	_born.clear()
	for i in _st.way.size():
		_born.append(-INF)
	_gone.clear()
	_join_at = -INF
	_reading = {}
	_say = ""
	_cross_at = -INF
	_won_at = -INF
	_clear_line()
	_stars.clear(_st.stars())
	_relayout()

func day_dict() -> Dictionary:
	if _st.from == "":
		return {}
	var out := {
		"source": "theme" if themed() else "bank", "kind": "text",
		"payload": {"from": _st.written(_st.from), "to": _st.written(_st.to), "given": _st.written(_st.given) if _st.given != "" else ""},
		"solution": {"route": _st.route.map(func(w: String) -> String: return _st.written(w))},
		"metrics": {"par": _st.par, "ways": _st.ways, "letters": _st.n, "slippery": _st.swaps},
	}
	if themed():
		out["theme"] = _st.written(String(_theme.word))
	return out

# --- the moves ---

func _offer() -> void:
	if is_done() or _st.crossed:
		return
	var typed := _typed
	var r: Dictionary = _st.offer(typed)
	match int(r.said):
		Said.SHORT:
			if typed == "":
				_summon()
				return
			_refuse("SS_SAY_SHORT", [_st.n])
		Said.UNKNOWN:
			_refuse("SS_SAY_UNKNOWN", [typed])
		Said.USED:
			_refuse("SS_SAY_USED", [typed], "again")
		Said.FAR_OFF:
			var last: String = _st.written(_st.last()).to_upper()
			if int(r.off) == 0:
				_refuse("SS_SAY_SAME", [last], "again")
			else:
				_refuse("SS_SAY_OFF_SLIP" if _st.swaps else "SS_SAY_OFF", [int(r.off), last])
		Said.LAID:
			_clear_line()
			_laid(r, false)
		Said.CROSSED:
			_clear_line()
			_reading = {}
			if not demo:
				moves += 1
				moved.emit()
			_crossed_now()

func _refuse(key: String, args: Array, cue := "refuse") -> void:
	_refused = _typed
	_shake_at = _t
	_say_now(key, args)
	_cue(cue)

## A stone (or two, Easy's given called in) laid: each drops into the
## brook with a splash.
func _laid(r: Dictionary, free: bool) -> void:
	_reading = {}
	if not free and not demo:
		moves += 1
		moved.emit()
	var added: int = _st.way.size() - _born.size()
	var joined: bool = r.joined
	for k in added:
		_born.append(_t)
	_relayout()
	var first := _born.size() - added
	_cue("lay", 0.94 + 0.04 * mini(_st.stones(), 8))
	if fx != null:
		_later(_t + Motion.DROP_TIME, func() -> void:
			if fx != null:
				fx.ring(_stone_pos(first), _l("stone_w") * 0.45, Art.WATER_HI)
				fx.puff(_stone_pos(first) + Vector2(0.0, _l("stone_h") * 0.3), Art.WATER_HI, 4))
	if themed():
		for idx in range(first, _st.way.size()):
			if String(_st.way[idx].word) == String(_theme.word):
				var j := idx
				var gave: bool = _st.way[idx].kind == "given"
				_later(_t + (0.25 + JOIN_TIME if gave else Motion.DROP_TIME), func() -> void: _theme_stone(j))
	if joined:
		var gi := _born.size() - 1
		_born[gi] = -INF
		_join_at = _t + 0.25
		_join_from = _given_side()
		_later(_join_at, func() -> void:
			_cue("join")
			if not _theme_is(_st.given):
				_say_now("SS_SAY_GIVEN", [_st.written(_st.given).to_upper()])
			if fx != null:
				fx.sparkle(_stone_pos(gi), Art.MOSS))
	if _st.crossed:
		_crossed_now(_t + Motion.DROP_TIME + (JOIN_TIME if joined else 0.0))
	elif _st.to_go() >= State.FAR:
		_say_now("SS_SAY_DEAD", [_st.written(_st.last()).to_upper()])
	_rate(true)

## The crossing made: the stones hop near bank to far in a wave, the far
## bank's slab last, then the confetti.
func _crossed_now(at := -1.0) -> void:
	if at < 0.0:
		at = _t
	_dismiss()
	check_solved()
	_cross_at = at + 0.15
	var n: int = _st.stones()
	for i in n:
		var k := i
		_later(_cross_at + k * WAVE_STEP, func() -> void:
			_cue("hop", 1.0 + 0.06 * mini(k, 10), -2.0, 0))
	var end := _cross_at + n * WAVE_STEP
	_won_at = end
	_later(end, func() -> void:
		_cue("bank")
		_say_now("SS_PERFECT" if _st.stones() <= _st.par else "SS_DONE", [])
		if fx != null:
			fx.ring(_far_pos(), _l("slab_w") * 0.55, Pal.SUN)
			fx.sparkle(_far_pos(), Pal.SUN))
	var slab := themed() and String(_theme.at) != "way"
	if slab:
		_later(end + THEME_AT, func() -> void:
			_cue("theme")
			var mark := _slab_mark_pos(String(_theme.at) == "from")
			if fx != null:
				fx.ring(mark, _l("stone_h") * 0.6, Pal.SUN)
				fx.sparkle(mark, Pal.SUN_RAY))
	_later(end + 0.3 + (THEME_SHIFT if slab else 0.0), func() -> void:
		_cue("solved")
		if fx != null:
			fx.confetti(Vector2(size.x * 0.5, _far_pos().y - _l("row") * 2.0), 28, size.x * 0.7)
		var perfect: bool = _st.stones() <= _st.par and hints_used == 0
		_cue("party" if perfect else "confetti"))
	_rate(true)
	_refresh_pill()

func is_solved() -> bool:
	return _st.crossed

func undo() -> bool:
	if not can_undo():
		return false
	var before: Array = _st.way.duplicate()
	var lifted: Array = _st.undo()
	if lifted.is_empty():
		return false
	_lift(before, _st.way.size())
	_reading = {}
	_clear_line()
	_cue("undo")
	_rate(false)
	_summon()
	moved.emit()
	return true

## The stones past `keep` of `before` rise out of the water and fade.
func _lift(before: Array, keep: int) -> void:
	for i in range(before.size() - 1, keep - 1, -1):
		_gone.append({"word": String(before[i].word), "at": _stone_pos(i), "t": _t + (before.size() - 1 - i) * 0.05, "i": i, "w": _l("stone_w")})
	_born.resize(keep)
	_relayout()

func reset_board() -> void:
	if is_done() or _st.crossed:
		return
	var before: Array = _st.way.duplicate()
	_st.restart()
	_lift(before, 0)
	moves = 0
	_reading = {}
	_clear_line()
	if not before.is_empty():
		_cue("clear")
	_rate(false)
	_summon()

## The bulb in two presses. The first, one hint, rings the letter of the
## last stone to change on a fewest way (or names the stone to go back to);
## the second lays that stone.
func hint() -> bool:
	if is_done() or _st.crossed:
		return false
	if _reading.is_empty():
		if _hints_held() <= 0:
			return false
		var step: Dictionary = _st.hint_step()
		if step.is_empty():
			return false
		hints_used += 1
		_reading = step
		_reading_at = _t
		var from: String = _st.written(String(step.from)).to_upper()
		if int(step.keep) < _st.stones():
			_say_now("SS_READ_BACK", [from])
		elif State.is_swap(String(step.from), String(step.word)):
			_say_now("SS_READ_SWAP", [int(step.at) + 1, int(step.at) + 2, from])
		else:
			_say_now("SS_READ", [int(step.at) + 1, from])
		_cue("hint")
		if fx != null:
			fx.ring(_letter_pos(int(step.keep) - 1, int(step.at)), _l("cell") * 0.55, Pal.SUN)
		moved.emit()
		_refresh_pill()
		_summon()
		return true
	var step: Dictionary = _reading
	_reading = {}
	var keep := int(step.keep)
	if keep < _st.stones():
		var before: Array = _st.way.duplicate()
		_st.cut_to(keep)
		_lift(before, keep)
	_clear_line()
	var r: Dictionary = _st.offer(String(step.word), "bulb")
	_cue("hint", 1.12)
	if int(r.said) == Said.LAID:
		_laid(r, true)
	elif int(r.said) == Said.CROSSED:
		_crossed_now()
	moved.emit()
	_summon()
	return true

# --- helpers ---

func _say_now(key: String, args: Array) -> void:
	_say = key
	_say_args = args
	_say_at = _t

func _later(at: float, fn: Callable) -> void:
	_due.append({"at": at, "fn": fn})

func _cue(name: String, pitch := 1.0, volume_db := 0.0, gap := -1) -> void:
	if demo or fx == null:
		return
	if gap >= 0:
		fx.cue(name, pitch, volume_db, gap)
	else:
		fx.cue(name, pitch, volume_db)

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
	return not _due.is_empty()

# --- the tutorial's hands ---

func demo_hint() -> void:
	hints_extra += 1
	hint()

func state():
	return _st

## The middle of stone `i` of the way (-1 the near bank's slab).
func stone_to_local(i: int) -> Vector2:
	return _stone_pos(i) if i >= 0 else _near_pos()

func ghost_to_local() -> Vector2:
	return _ghost_pos()

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if not demo:
		_watch_osk()
	if clock_held and not demo:
		_dismiss()
		return
	_t += delta
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
			(d.fn as Callable).call()
	if not _gone.is_empty():
		_gone = _gone.filter(func(g: Dictionary) -> bool: return _t - float(g.t) < LIFT_TIME)
	if _say != "" and _t - _say_at > SAY_TIME:
		_say = ""
	queue_redraw()
	if _pill != null and (_stars.busy(_t) or _t - _enter_at < 1.0):
		_pill.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if demo:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		_summon()

## The phone's keyboard's top, followed: the board lays itself out above it.
func _watch_osk() -> void:
	var h := osk_override
	if h < 0.0:
		h = 0.0
		if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			_osk = 0.0
			return
		var win := DisplayServer.window_get_size()
		var kb := DisplayServer.virtual_keyboard_get_height()
		if kb > 0 and win.y > 0:
			h = float(kb) * get_viewport_rect().size.y / float(win.y)
			h = maxf(0.0, h - (get_viewport_rect().size.y - get_global_rect().end.y))
	if _st.crossed and osk_override >= 0.0:
		h = 0.0
	if absf(h - _osk) > 0.5:
		_osk = h
		_relayout()

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
	if size.x <= 0.0 or size.y <= 0.0 or _st.from == "":
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	if _osk > 0.0:
		bottom = minf(bottom, size.y - _osk - OSK_GAP * size.x / W)
	_L = _layout_for(top, bottom)
	_meshes = {}
	_current_key = ""
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		_world.set_lines(_l("near_edge"), _l("far_edge"))
	if _field != null:
		var g := _ghost_pos()
		_field.position = g - Vector2(_l("stone_w"), _l("stone_h")) * 0.5
		_field.size = Vector2(_l("stone_w"), _l("stone_h"))
	_refresh_pill()
	queue_redraw()

## The banks at the span's ends, the stones stacked down from the near
## bank's edge, the waiting stone under them and the line the board says
## things on under that. Rows shrink as stones come; past the least, the
## oldest fold into one pebble.
func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var tight := _osk > 0.0
	var span := maxf(bottom - top, 300.0 * u)
	var n: int = _st.n
	var laid: int = _st.stones()
	var ghost := 0 if _st.crossed else 1
	var say_h := SAY_H * u * (0.8 if tight else 1.0)
	var margin := MARGIN * u
	var room := span - say_h - margin * 2.0
	var least := (ROW_TIGHT if tight else ROW_MIN) * u
	var rows := laid + ghost + 2
	var row := minf(ROW_MAX * u, room / rows)
	var shown := laid
	var folded := 0
	if row < least:
		row = least
		# the banks, the waiting stone and the fold's pebble keep their rows
		shown = maxi(1, int(floor(room / row)) - 2 - ghost - 1)
		folded = laid - shown
		if folded <= 0:
			folded = 0
			shown = laid
	var stone_h := row * STONE_K
	var cell := minf(CELL_MAX * u, stone_h * 0.92)
	cell = minf(cell, w * 0.62 / (n + PAD * 2.0))
	var stone_w := cell * (n + PAD * 2.0)
	var slab_h := stone_h * 1.04
	var slab_w := stone_w * 1.12
	var near_y := top + margin + row * 0.5
	var far_y := bottom - margin - row * 0.5
	var near_edge := near_y + row * 0.5
	var far_edge := far_y - row * 0.5
	# Easy's way runs left of the middle, clear of the given stone waiting
	var col_x := w * (0.42 if _st.given != "" else 0.5)
	var first_y := near_edge + row * 0.5 + (row * 0.62 if folded > 0 else 0.0)
	return {
		"u": u, "top": top, "bottom": bottom, "row": row, "stone_w": stone_w, "stone_h": stone_h,
		"cell": cell, "slab_w": slab_w, "slab_h": slab_h, "near_y": near_y, "far_y": far_y,
		"near_edge": near_edge, "far_edge": far_edge, "col_x": col_x, "first_y": first_y,
		"shown": shown, "folded": folded, "say_h": say_h, "tight": tight,
	}

func _l(key: String) -> float:
	return float(_L.get(key, 0.0))

func _u() -> float:
	return float(_L.get("u", 1.0))

func _near_pos() -> Vector2:
	return Vector2(size.x * 0.5, _l("near_y"))

func _far_pos() -> Vector2:
	return Vector2(size.x * 0.5, _l("far_y"))

## Where stone `i` of the way stands (a folded one sits on the fold's
## pebble).
func _stone_pos(i: int) -> Vector2:
	var folded := int(_L.get("folded", 0))
	var k := i - folded
	if k < 0:
		return Vector2(_l("col_x"), _l("near_edge") + _l("row") * 0.42)
	var zig := ZIG * _u() * (1.0 if i % 2 == 0 else -1.0)
	return Vector2(_l("col_x") + zig, _l("first_y") + k * _l("row"))

func _ghost_pos() -> Vector2:
	var i: int = _st.stones()
	return _stone_pos(i)

## Easy's given stone, waiting at the brook's right.
func _given_side() -> Vector2:
	var y := lerpf(_l("near_edge"), _l("far_edge"), 0.45)
	return Vector2(size.x * 0.8, y)

## The middle of letter `k` on stone `i` (-1 the near bank's slab).
func _letter_pos(i: int, k: int) -> Vector2:
	var c := stone_to_local(i)
	return c + Vector2((k - (_st.n - 1) * 0.5) * _l("cell"), 0.0)

# --- drawing ---

func _draw() -> void:
	if _L.is_empty():
		return
	_draw_current()
	_draw_slab(_near_pos(), _st.from, true)
	_draw_fold()
	for i in _st.way.size():
		_draw_stone(i)
	_draw_gone()
	_draw_given()
	if not _st.crossed:
		_draw_ghost()
	_draw_slab(_far_pos(), _st.to, false)
	_draw_say()

## The current's streaks, one kept mesh drawn twice as it drifts across.
func _draw_current() -> void:
	var u := _u()
	var key := "%d:%d:%d" % [roundi(size.x), roundi(_l("near_edge")), roundi(_l("far_edge"))]
	if key != _current_key:
		_current_key = key
		var b := Face.Builder.new()
		Art.current(b, size.x, _l("near_edge"), _l("far_edge"), u)
		_current = b.mesh()
	var x := 0.0 if Motion.reduce else fmod(_t * DRIFT * u, size.x)
	draw_mesh(_current, null, Transform2D(0.0, Vector2(x, 0.0)))
	draw_mesh(_current, null, Transform2D(0.0, Vector2(x - size.x, 0.0)))

func _stone_mesh(word: String, i: int, moss: float) -> ArrayMesh:
	var key := "s:%s:%d:%d:%d" % [word, i, roundi(_l("stone_w")), roundi(moss * 10.0)]
	if not _meshes.has(key):
		var b := Face.Builder.new()
		var sz := Vector2(_l("stone_w"), _l("stone_h"))
		Art.stone(b, Vector2.ZERO, sz, 17 + i * 31 + word.hash() % 97, moss)
		_add_moss(b, word, Vector2.ZERO)
		if _theme_is(word):
			Art.sun_mark(b, _mark_off(sz), _l("stone_h") * MARK_K)
		_meshes[key] = b.mesh()
	return _meshes[key]

## The moss under each letter of `word` already matching the far bank.
func _add_moss(b, word: String, c: Vector2) -> void:
	for k in mini(word.length(), _st.to.length()):
		if word[k] == _st.to[k]:
			Art.moss(b, c + Vector2((k - (_st.n - 1) * 0.5) * _l("cell"), 0.0), _l("cell") * 0.4)

func _draw_slab(at: Vector2, word: String, near: bool) -> void:
	var u := _u()
	var key := "b:%s:%s:%d" % [word, near, roundi(_l("slab_w"))]
	if not _meshes.has(key):
		var b := Face.Builder.new()
		Art.slab(b, Vector2.ZERO, Vector2(_l("slab_w"), _l("slab_h")))
		if near:
			_add_moss(b, word, Vector2.ZERO)
		if _theme_is(word):
			Art.sun_mark(b, _mark_off(Vector2(_l("slab_w"), _l("slab_h"))), _l("stone_h") * MARK_K * 1.15)
		_meshes[key] = b.mesh()
	var e := _t - _enter_at - Motion.ENTER_DELAY - (0.0 if near else 0.12)
	var sc := 1.0 if Motion.reduce else Motion.pop_in_scale(e).x
	if sc <= 0.0:
		return
	var hop := 0.0
	if not near and _won_at > -INF and not Motion.reduce:
		var he := _t - _won_at
		if he >= 0.0 and he < Motion.SOLVE_TIME * 1.4:
			hop = Motion.hop_lift(he, Motion.SOLVE_HOP * 2.0 * u, Motion.SOLVE_TIME * 1.4)
	var c := at + Vector2(0.0, hop)
	draw_mesh(_meshes[key], null, Transform2D(0.0, Vector2.ONE * sc, 0.0, c))
	draw_set_transform(c, 0.0, Vector2.ONE * sc)
	_letters(Vector2.ZERO, word, "", near, Color.WHITE)
	draw_set_transform(Vector2.ZERO)

## Stone `i` of the way: dropping in, hopping in the crossing's wave, or
## (Easy's given) sliding in from the brook's side.
func _draw_stone(i: int) -> void:
	var folded := int(_L.get("folded", 0))
	if i < folded:
		return
	var u := _u()
	var s: Dictionary = _st.way[i]
	var word: String = s.word
	var at := _stone_pos(i)
	var a := 1.0
	var born: float = _born[i] if i < _born.size() else -INF
	if born > -INF and not Motion.reduce:
		var e := _t - born
		if e < Motion.DROP_TIME:
			at.y -= Motion.drop_in_lift(maxf(e, 0.0), DROP_H * u)
			a = Motion.appear_level(maxf(e, 0.0))
	var given: bool = s.kind == "given"
	if given and _join_at > -INF and not Motion.reduce:
		var je := _t - _join_at
		if je < 0.0:
			at = _join_from
		elif je < JOIN_TIME:
			var k := Motion.back_out(je / JOIN_TIME)
			at = _join_from.lerp(at, k)
			at.y += Motion.hop_lift(je, Motion.SOLVE_HOP * 2.0 * u, JOIN_TIME)
	if _cross_at > -INF and not Motion.reduce:
		var he := _t - _cross_at - i * WAVE_STEP
		if he >= 0.0 and he < Motion.SOLVE_TIME:
			at.y += Motion.hop_lift(he, Motion.SOLVE_HOP * 1.6 * u, Motion.SOLVE_TIME)
	var prev: String = String(_st.way[i - 1].word) if i > 0 else _st.from
	draw_mesh(_stone_mesh(word, i, 1.0 if given else 0.0), null, Transform2D(0.0, at), Color(1, 1, 1, a))
	_letters(at, word, prev, true, Color(1, 1, 1, a), s.kind == "bulb")
	# the bulb's first press: the letter to change, ringed
	if not _reading.is_empty() and int(_reading.keep) - 1 == i:
		_ring_letter(i, int(_reading.at))

func _ring_letter(i: int, k: int) -> void:
	var pulse := 1.0 if Motion.reduce else 0.6 + 0.4 * sin((_t - _reading_at) * 6.0)
	draw_arc(_letter_pos(i, k), _l("cell") * 0.5, 0.0, TAU, 32, Color(Pal.SUN, pulse), maxf(3.0, 5.0 * _u()), true)
	if State.is_swap(String(_reading.from), String(_reading.word)):
		draw_arc(_letter_pos(i, k + 1), _l("cell") * 0.5, 0.0, TAU, 32, Color(Pal.SUN, pulse), maxf(3.0, 5.0 * _u()), true)

## A word's letters about `c`: gold where it changed from `prev`, moss ink
## where it matches the far bank (when `moss`).
func _letters(c: Vector2, word: String, prev: String, moss: bool, tint: Color, bulb := false) -> void:
	var font: Font = CozyTheme.display(800)
	var fs := roundi(_l("cell") * LETTER_K)
	var shown: String = _st.written(word).to_upper()
	if shown.length() != word.length():
		shown = word.to_upper()
	for k in shown.length():
		var ch := shown[k]
		var ink := Art.INK
		if moss and k < _st.to.length() and word[k] == _st.to[k]:
			ink = Art.MOSS_INK
		if prev != "" and k < prev.length() and prev[k] != word[k]:
			ink = Art.CHANGED if not bulb else Pal.MOON_DEEP
		var tw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := c + Vector2((k - (shown.length() - 1) * 0.5) * _l("cell") - tw * 0.5, font.get_ascent(fs) * 0.36)
		draw_string(font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, ink.a * tint.a))

## The oldest stones folded into one pebble, "+3".
func _draw_fold() -> void:
	var folded := int(_L.get("folded", 0))
	if folded <= 0:
		return
	var u := _u()
	var at := _stone_pos(0)
	var key := "f:%d" % roundi(_l("stone_h"))
	if not _meshes.has(key):
		var b := Face.Builder.new()
		var h := _l("stone_h") * 0.7
		Art.stone(b, Vector2.ZERO, Vector2(h * 2.2, h), 5)
		_meshes[key] = b.mesh()
	draw_mesh(_meshes[key], null, Transform2D(0.0, at))
	var font: Font = CozyTheme.display(800)
	var fs := roundi(_l("stone_h") * 0.42)
	var text := "+%d" % folded
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK_DIM)

## Stones lifted (Undo, the bin, the bulb going back): rising and fading.
func _draw_gone() -> void:
	var u := _u()
	var folded := int(_L.get("folded", 0))
	for g: Dictionary in _gone:
		if int(g.i) < folded:
			continue
		var e := maxf(0.0, _t - float(g.t))
		var k := clampf(e / LIFT_TIME, 0.0, 1.0)
		# drawn at the size it was lifted at, though the rows have grown since
		var sc := float(g.get("w", _l("stone_w"))) / maxf(1.0, _l("stone_w")) * (1.0 - 0.15 * k)
		var at: Vector2 = (g.at as Vector2) + Vector2(0.0, -40.0 * u * k)
		var a := 1.0 - k
		draw_mesh(_stone_mesh(String(g.word), int(g.i), 0.0), null, Transform2D(0.0, Vector2.ONE * sc, 0.0, at), Color(1, 1, 1, a))
		draw_set_transform(at, 0.0, Vector2.ONE * sc)
		_letters(Vector2.ZERO, String(g.word), "", false, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO)

## Easy's given stone, mossy, waiting at the brook's side.
func _draw_given() -> void:
	if _st.given == "" or _st.given_in() or _st.crossed:
		return
	var at := _given_side()
	var e := _t - _enter_at - Motion.ENTER_DELAY - 0.2
	var sc := 1.0 if Motion.reduce else Motion.pop_in_scale(e).x
	if sc <= 0.0:
		return
	if not Motion.reduce:
		at.y += sin(_t * 1.6) * 3.0 * _u()
	var m := _stone_mesh(_st.given, 99, 1.0)
	var k := 0.84 * sc
	draw_mesh(m, null, Transform2D(0.0, Vector2.ONE * k, 0.0, at))
	draw_set_transform(at, 0.0, Vector2.ONE * k)
	_letters(Vector2.ZERO, _st.given, "", true, Color.WHITE)
	draw_set_transform(Vector2.ZERO)

## The waiting stone: ripples on the water and the letters typed so far,
## gold where they differ from the last stone; the bulb's word ringed.
func _draw_ghost() -> void:
	var u := _u()
	var at := _ghost_pos()
	if _shake_at > -INF and not Motion.reduce:
		at.x += Motion.shiver_offset(_t - _shake_at, Motion.SHIVER_PX * 4.0 * u, Motion.SHIVER_TIME * 1.6)
	var sz := Vector2(_l("stone_w"), _l("stone_h"))
	var key := "g:%d" % roundi(sz.x)
	if not _meshes.has(key):
		var b := Face.Builder.new()
		Art.ripples(b, Vector2.ZERO, sz)
		_meshes[key] = b.mesh()
	var breathe := 1.0 if Motion.reduce else 1.0 + 0.03 * sin(_t * 2.4)
	var e := _t - _enter_at - Motion.ENTER_DELAY - 0.3
	var sc := (1.0 if Motion.reduce else Motion.pop_in_scale(e).x) * breathe
	if sc <= 0.0:
		return
	draw_mesh(_meshes[key], null, Transform2D(0.0, Vector2.ONE * sc, 0.0, at))
	var font: Font = CozyTheme.display(800)
	var fs := roundi(_l("cell") * LETTER_K)
	var last: String = _st.last()
	if _typed == "":
		var body: Font = CozyTheme.display(700)
		var hint := tr("SS_TYPE_SLIP") if _st.swaps else tr("SS_TYPE")
		var hs := roundi(minf(30.0 * u, _l("stone_h") * 0.3))
		var tw := body.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		if tw > sz.x * 1.5:
			hs = roundi(hs * sz.x * 1.5 / tw)
			tw = body.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		var blink := 1.0 if Motion.reduce else 0.6 + 0.4 * sin(_t * 3.0)
		draw_string_outline(body, at + Vector2(-tw * 0.5, body.get_ascent(hs) * 0.36), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, roundi(8 * u), Color(Art.WATER_HI, 0.7 * blink))
		draw_string(body, at + Vector2(-tw * 0.5, body.get_ascent(hs) * 0.36), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(Art.INK, 0.65 * blink))
		return
	var folded_last := Locale.fold(_typed.to_lower())
	for k in _st.n:
		var p := at + Vector2((k - (_st.n - 1) * 0.5) * _l("cell"), 0.0)
		if k >= _typed.length():
			draw_line(p + Vector2(-_l("cell") * 0.26, fs * 0.42), p + Vector2(_l("cell") * 0.26, fs * 0.42), Color(Art.INK, 0.4), maxf(2.0, 4.0 * u), true)
			continue
		var ch := _typed[k]
		var ink := Art.INK
		if k < last.length() and k < folded_last.length() and folded_last[k] != last[k]:
			ink = Art.CHANGED
		var tw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := p + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36)
		draw_string_outline(font, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(10 * u), Color(Art.WATER_HI, 0.9))
		draw_string(font, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

## What the board says, under the waiting stone (on the win, over the far
## bank).
func _draw_say() -> void:
	if _say == "" or _t < _say_at:
		return
	var font: Font = CozyTheme.display(800)
	var text := tr(_say)
	if not _say_args.is_empty():
		text = text % _say_args
	var good := _say in ["SS_SAY_THEME", "SS_SAY_GIVEN", "SS_PERFECT", "SS_DONE", "SS_READ", "SS_READ_SWAP", "SS_READ_BACK"]
	var fs := roundi(SAY_SIZE * (1.15 if good else 1.0) * _u() * (0.9 if bool(_L.get("tight", false)) else 1.0))
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > size.x * 0.94:
		fs = roundi(fs * size.x * 0.94 / tw)
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var e := _t - _say_at
	var pk := Motion.pop_in_scale(e, 0.25).x if e < 0.25 and not Motion.reduce else 1.0
	var fade := clampf((SAY_TIME - e) / 0.4, 0.0, 1.0)
	var ink := Art.CHANGED.darkened(0.25) if good else Pal.TEXT
	var asc := font.get_ascent(fs)
	var y: float
	if _st.crossed:
		y = _l("far_y") - _l("row") * 0.95
	else:
		y = _ghost_pos().y + _l("stone_h") * 0.5 + _l("say_h") * 0.5
		y = minf(y, _l("far_edge") - _l("say_h") * 0.35)
	draw_set_transform(Vector2(size.x * 0.5, y), 0.0, Vector2.ONE * pk)
	draw_string_outline(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(12 * _u()), Color(Pal.SURFACE, 0.92 * fade))
	draw_string(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, fade))
	draw_set_transform(Vector2.ZERO)

## The pill in the tools row's gap: the stars the way stands at, then the
## stones laid against par.
func _draw_pill() -> void:
	if not _bled or _won or _st.from == "":
		return
	var enter := 1.0 if Motion.reduce else Motion.pop_in_scale(_t - _enter_at - Motion.ENTER_DELAY).x
	if enter <= 0.0:
		return
	var font: Font = CozyTheme.body(700)
	var n: int = _st.stones()
	var text: String = (tr("SS_PILL_ONE") % _st.par) if n == 1 else (tr("SS_PILL_N") % [n, _st.par])
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
	return WIN_HOLD + _st.stones() * WAVE_STEP + (THEME_HOLD if themed() else 0.0)

func skill_quality() -> float:
	if _st.from == "":
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🌊 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var n: int = _st.stones()
	var line: String = tr("SS_WIN_ONE") if n == 1 else tr("SS_WIN_N") % n
	if n < _st.par:
		line += " " + tr("SS_WIN_UNDER")
	elif n == _st.par:
		line += " " + tr("SS_WIN_AT_PAR")
	else:
		line += " " + tr("SS_WIN_PAR_WAS") % _st.par
	if themed():
		var shown: String = _st.written(String(_theme.word)).to_upper()
		if String(_theme.at) != "way" or _theme_in_way():
			line = tr("SS_WIN_THEME") % [shown, line]
		else:
			line = tr("SS_WIN_THEME_WAY") % [shown, line]
	return {"faces": [], "subtitle": line}

func completion_record() -> Dictionary:
	return {"way": _st.way.duplicate(true), "helped": _st.helped, "stars": _st.stars(), "from": _st.from, "to": _st.to, "theme": _theme.duplicate()}

## A finished day reopens crossed, its stones as laid: on the crossing it was
## played on, should the night's theme have changed the deal since.
func restore_completed_board() -> void:
	_redeal_as_played()
	_st.finish(completed_record.get("way", []) as Array)
	_st.helped = int(completed_record.get("helped", 0))
	_fresh()
	_enter_at = -10.0
	_dismiss()
	queue_redraw()

# --- the daily theme (2026-11-06) ---

func themed() -> bool:
	return not _theme.is_empty()

func _theme_is(word: String) -> bool:
	return themed() and word != "" and word == String(_theme.word)

func _theme_in_way() -> bool:
	for s: Dictionary in _st.way:
		if _theme_is(String(s.word)):
			return true
	return false

## The bank entry a daily dealt from its day takes on a themed day (never
## New, never the tutorial's): the one holding the night's strongest theme
## word on a bank, else on its route (or Easy's given). {} deals as ever.
## Sets `_theme`.
func _themed_entry() -> Dictionary:
	_theme = {}
	if demo or bank_step != 0 or daily_key == 0:
		return {}
	var pool: Array = theme_pool_override if not theme_pool_override.is_empty() else ThemedPictures.theme_pool(daily_key)
	if pool.is_empty():
		return {}
	var boards: Array = InsaneBank.boards(State.BANKS[_band])
	var easy := _band == 0
	var got := ThemedPictures.bank_pick(boards, pool, daily_key, func(e) -> Array:
		return [String(e.get("from", "")), String(e.get("to", ""))])
	if got.is_empty():
		got = ThemedPictures.bank_pick(boards, pool, daily_key, func(e) -> Array:
			var words: Array = (e.get("route", []) as Array).duplicate()
			if easy and String(e.get("given", "")) != "":
				words.append(String(e.given))
			return words)
	if got.is_empty():
		return {}
	var entry: Dictionary = boards[int(got.index)]
	var word := String(got.word)
	var at := "way"
	if Locale.fold(String(entry.get("to", ""))) == word:
		at = "to"
	elif Locale.fold(String(entry.get("from", ""))) == word:
		at = "from"
	_theme = {"word": word, "at": at}
	return entry

## A reopened day whose record names another crossing than the one dealt
## now (the night's words came in after it was played): the record's.
func _redeal_as_played() -> void:
	var from := String(completed_record.get("from", ""))
	var to := String(completed_record.get("to", ""))
	if from == "" or (from == _st.from and to == _st.to):
		return
	for e in InsaneBank.boards(State.BANKS[_band]):
		if e is Dictionary and Locale.fold(String(e.get("from", ""))) == from and Locale.fold(String(e.get("to", ""))) == to:
			_st.load_day(e)
			var t = completed_record.get("theme", {})
			_theme = (t as Dictionary).duplicate() if t is Dictionary else {}
			return

## A themed stone laid (or Easy's given come in): the cue, a sparkle at its
## sun and the board says the word.
func _theme_stone(i: int) -> void:
	if i >= _st.way.size() or not _theme_is(String(_st.way[i].word)):
		return
	_cue("theme")
	_say_now("SS_SAY_THEME", [_st.written(String(_theme.word)).to_upper()])
	if fx != null:
		var at := _stone_pos(i) + _mark_off(Vector2(_l("stone_w"), _l("stone_h")))
		fx.ring(at, _l("stone_h") * 0.5, Pal.SUN)
		fx.sparkle(at, Pal.SUN_RAY)

## Where the sun sits on a stone or slab of `sz`, from its middle: on the
## top right corner.
func _mark_off(sz: Vector2) -> Vector2:
	var r := _l("stone_h") * MARK_K
	return Vector2(sz.x * 0.5 - r * 0.55, -sz.y * 0.5 + r * 0.25)

func _slab_mark_pos(near: bool) -> Vector2:
	return (_near_pos() if near else _far_pos()) + _mark_off(Vector2(_l("slab_w"), _l("slab_h")))
