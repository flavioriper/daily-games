extends "res://core/puzzle_base.gd"

## Five Clues (spec docs/superpowers/specs/2026-10-22-clues-design.md): a
## words board. Five clue cards are pinned face down to a cork board on the
## garden shed's wall; the first is turned. Every card names a thing that
## belongs to one hidden idea, the least telling first. Type the idea on the
## phone's own keyboard and Enter: right, and the idea is chalked on the
## slate under the board with a word of praise for how few cards it took;
## wrong, and the line is pinned crossed out under the slate and the next
## card turns. A tap on the next face-down card (or Enter on an empty line)
## turns it without a guess; a slip of a letter is pointed out, free. A
## wrong line with every card up loses the
## round, and the idea is shown. On Insane (Three Tries) a round also ends
## at its third wrong line. Every round done is the day; the score is the
## cards each round needed. The rules are puzzles/clues_state.gd's.
##
## **The shed wall is the whole screen** (`"bleed": true`, `"tray": "none"`).
## Players hated the built-in keyboard (the user, 2026-10-28: "they want to
## use their own device keyboard"), so the board holds an unseen LineEdit
## over the slate and the phone's keyboard types into it; the board lays
## itself out above the keyboard while it is up (`_osk`). A round over moves
## on by itself after a moment; a tap or Enter moves on sooner.
##
## A daily's rounds are written at night (server/functions/src/clues.ts) and
## fetched as Golden Acorn's are: at once when this phone holds them, after
## one short wait when it does not, and from the bank when nobody could.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, dealt `demo_rounds`, and
## ui/hud/clues_tutorial_diagram.gd plays it with `demo_line`.

const State = preload("res://puzzles/clues_state.gd")
const World = preload("res://puzzles/clues_world.gd")
const Art = preload("res://ui/faces/clues_art.gd")
const Hearts = preload("res://ui/faces/shelves_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Backend = preload("res://core/backend.gd")

const Said = State.Said
enum Phase { WAIT, PLAY, OVER, DONE }

const HAPTICS := {
	"type": Haptics.TICK,
	"erase": Haptics.TICK,
	"turn": Haptics.TICK,
	"right": Haptics.GOOD,
	"wrong": Haptics.WARN,
	"lost": Haptics.LOSE,
	"repeat": Haptics.TICK,
	"hush": Haptics.TICK,
	"next": Haptics.TAP,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
}

const W := 1080.0
const FETCH_WAIT := 4.0
## The cards at W: their size and gap; the slate's height; the pills'.
const CARD := Vector2(560.0, 92.0)
const CARD_GAP := 14.0
const SLATE_H := 130.0
const PILL_R := 26.0
## The words, at W.
const CARD_SIZE := 44
const CARD_MIN := 22
const LINE_SIZE := 50
const LABEL_SIZE := 44
const SAY_SIZE := 28
## The motions.
const TURN_TIME := 0.36
const SAY_TIME := 2.0
const ROUND_SLIDE := 0.4
const WIN_HOLD := 1.2
## A round over moves on by itself after this long (lost: the idea read
## first), and ignores Enter for the first moment so a typed Enter held
## over does not skip the cards turning.
const NEXT_RIGHT := 2.6
const NEXT_LOST := 3.6
const NEXT_GUARD := 0.6
## The tried lines under the slate, and the praise stamped on the cork.
const TRIED_SIZE := 26
const PRAISE_SIZE := 64
const PRAISE_TIME := 1.6
## Room left between the slate's row and the phone's keyboard, at W.
const OSK_GAP := 18.0

var demo := false
var demo_rounds: Array = []

var _st = State.new()
var _band := 0
var _gen := 0
var _seed_key := 0
var _dealt := false
var _phase := Phase.WAIT
var _t := 0.0
var _queue: Array = []
var _typed := ""
## Per card of the round in hand: when it turned.
var _turned_at: Array[float] = []
var _round_at := -INF
var _over_at := -INF
var _shake_at := -INF
var _won_at := -INF
var _say := ""
var _say_at := -INF
var _field: LineEdit
## The phone's keyboard's height in the board's pixels (0 while down), and a
## stand-in a harness sets to see the layout above one off a phone.
var _osk := 0.0
var osk_override := -1.0
## This round's wrong lines as typed, and the praise of the last found.
var _tried: Array[String] = []
var _praise := ""
var _round_no := 0
var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _world: Control
var _cards := {}
var fx: Node

func puzzle_id() -> String: return "clues"
func title() -> String: return "Five Clues"

func rules() -> String:
	var out := tr("FC_RULES") % [State.ROUNDS[_band]]
	if _band == 3:
		out += "\n\n" + tr("FC_RULES_TRIES") % State.TRIES[3]
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/clues_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.GUESS, "HTP_FC_GUESS", tr("HTP_FC_GUESS_BODY")],
		[Diagram.Lesson.WRONG, "HTP_FC_WRONG", tr("HTP_FC_WRONG_BODY")],
		[Diagram.Lesson.TURN, "HTP_FC_TURN", tr("HTP_FC_TURN_BODY")],
	]
	if _band == 3:
		steps.append([Diagram.Lesson.TRIES, "HTP_FC_TRIES", tr("HTP_FC_TRIES_BODY") % State.TRIES[3]])
	steps.append([Diagram.Lesson.HINT, "HTP_FC_HINT", tr("HTP_FC_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func capabilities() -> Array[String]:
	return ["hint"]

func can_reset() -> bool:
	return false

func hints_left() -> int:
	return maxi(0, int(State.HINTS[_band]) + hints_extra - hints_used)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if demo else Control.MOUSE_FILTER_STOP
	if not demo:
		fx = Fx2D.new()
		fx.name = "Fx"
		fx.haptics = HAPTICS
		add_child(fx)
		_make_field()
	resized.connect(_relayout)
	if demo:
		_make_world()
		_relayout()

## The line the phone's keyboard types into: unseen, laid over the slate,
## never touched itself (the board's own _gui_input calls it up), so the
## slate stays drawn as chalk. It keeps editing across Enter so the keyboard
## stays up from one guess to the next.
func _make_field() -> void:
	_field = LineEdit.new()
	_field.name = "Field"
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.max_length = State.TYPE_MAX
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
	_field.text_submitted.connect(func(_t: String) -> void: commit_row())
	add_child(_field)

## Calls the phone's keyboard up, while a round is played.
func _summon() -> void:
	if _field == null or _phase != Phase.PLAY or is_done() or clock_held:
		return
	if not _field.has_focus():
		_field.edit()
	elif _osk <= 0.0 and osk_override < 0.0 and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		# Android's back hides the keyboard and leaves the field focused:
		# shown again, or a tap could never bring it back
		_field.unedit()
		_field.edit()

## Leaving the board puts the keyboard away with it.
func _exit_tree() -> void:
	_dismiss()

func _dismiss() -> void:
	if _field != null and _field.has_focus():
		_field.unedit()
		_field.release_focus()

## What the keyboard typed, as the slate shows it.
func _on_typed(text: String) -> void:
	if _phase != Phase.PLAY or is_done():
		if text != "":
			_field.text = ""
		return
	var was := _typed
	_typed = text.to_upper()
	if _typed.length() > was.length():
		_cue("type", randf_range(0.97, 1.03))
	elif _typed.length() < was.length():
		_cue("erase")

func _clear_line() -> void:
	_typed = ""
	if _field != null and _field.text != "":
		_field.text = ""

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	_band = clampi(difficulty, 0, 3)
	_seed_key = int(rng.randi())
	_dealt = false
	_phase = Phase.WAIT
	_st = State.new()
	_st.band = _band
	if demo:
		_st.setup_fixed(demo_rounds, _band)
		_begin()
		return
	_deal.call_deferred(_gen)

func _deal(gen: int) -> void:
	if gen != _gen or _dealt:
		return
	var key := daily_key
	if key == 0:
		_from_bank(_seed_key)
		return
	var doc: Dictionary = Backend.cached_day(State.GAME, key)
	if doc.is_empty() and Backend.started():
		get_tree().create_timer(FETCH_WAIT).timeout.connect(func() -> void:
			if gen == _gen and not _dealt:
				_from_bank(key))
		var got: Dictionary = await Backend.day_content(State.GAME, key)
		if gen != _gen or _dealt or not is_inside_tree():
			return
		doc = got.data if bool(got.ok) else {}
	if _st.setup_day(doc, key, _band):
		_begin()
	else:
		_from_bank(key)

func _from_bank(key: int) -> void:
	if _st.setup(key, _band):
		_begin()

func _begin() -> void:
	_dealt = true
	_queue.clear()
	_typed = ""
	_fresh_round()
	_cue("enter")
	_summon.call_deferred()

func _fresh_round() -> void:
	_phase = Phase.PLAY
	_round_no += 1
	_round_at = _t
	_over_at = -INF
	_tried.clear()
	_praise = ""
	_clear_line()
	_turned_at.clear()
	for i in State.CLUES:
		_turned_at.append(-INF)
	_turned_at[0] = _t + (0.0 if Motion.reduce else 0.25)
	_relayout()

func day_dict() -> Dictionary:
	if not _dealt:
		return {"pending": true}
	if _st.rounds.is_empty():
		return {}
	return {
		"source": "bank" if _st.source == "bank" else "server", "kind": "text",
		"payload": {"rounds": _st.rounds.map(func(r: Dictionary) -> Array: return r.clues), "lang": TranslationServer.get_locale().substr(0, 2)},
		"solution": {"labels": _st.rounds.map(func(r: Dictionary) -> String: return r.label)},
		"metrics": {"rounds": _st.count(), "written_by": _st.source},
	}

# --- the keyboard ---

func _after(delay: float, what: Callable) -> void:
	_queue.append([_t + delay, what])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

## The tutorial's hands type through these; a player types into _field.
func type_letter(letter: String) -> void:
	if _phase != Phase.PLAY or is_done() or _typed.length() >= State.TYPE_MAX:
		return
	_typed += letter.to_upper()
	_cue("type", randf_range(0.97, 1.03))

func erase_letter() -> void:
	if _phase != Phase.PLAY or is_done() or _typed == "":
		return
	_typed = _typed.substr(0, _typed.length() - 1)
	_cue("erase")

## Enter: the line offered, the next card when the line is empty, or once a
## round is over (and its cards have had a moment), the next round (after
## the last, the end of the day).
func commit_row() -> void:
	if not _dealt or is_done():
		return
	match _phase:
		Phase.OVER:
			if _t - _over_at >= NEXT_GUARD or demo:
				_next()
		Phase.PLAY:
			_offer()

## A tap on a face-down card: the next one turns, no guess spent.
func turn_next() -> bool:
	if _phase != Phase.PLAY or is_done():
		return false
	var said: int = _st.turn()
	if said == Said.TURNED:
		_turn(_st.shown - 1)
		return true
	if said == Said.EMPTY:
		_say_now(tr("FC_ALL_UP"))
		_cue("hush")
	return false

func _offer() -> void:
	var said: int = _st.offer(_typed)
	match said:
		Said.IGNORED:
			return
		Said.EMPTY:
			_say_now(tr("FC_ALL_UP"))
			_cue("hush")
			return
		Said.REPEAT:
			_say_now(tr("FC_REPEAT"))
			_shake_at = _t
			_cue("repeat")
			return
		Said.NEAR:
			_say_now(tr("FC_CLOSE"))
			_shake_at = _t
			_cue("repeat")
			return
		Said.TURNED:
			_turn(_st.shown - 1)
			return
	moves += 1
	moved.emit()
	if said == Said.RIGHT:
		_clear_line()
		_round_over(true)
		return
	_shake_at = _t
	_tried.append(_typed.strip_edges())
	_clear_line()
	if said == Said.LOST:
		_round_over(false)
		return
	_cue("wrong")
	_say_now(tr("FC_WRONG") if _st.tries() <= 0 else (tr("FC_TRIES_ONE") if _st.tries_left() == 1 else tr("FC_TRIES_N") % _st.tries_left()))
	_after(0.25, func() -> void: _turn(_st.shown - 1))

func _turn(i: int) -> void:
	if i < 0 or i >= _turned_at.size():
		return
	_turned_at[i] = _t
	_cue("turn", 1.0 + i * 0.05)

func _round_over(right: bool) -> void:
	_phase = Phase.OVER
	_over_at = _t
	_say = ""
	# every card turns once the idea is out
	for i in State.CLUES:
		if _turned_at[i] == -INF:
			_turned_at[i] = _t + 0.25 + i * 0.08
	_cue("right" if right else "lost")
	var cards: int = _st.results[_st.results.size() - 1]
	if right:
		_praise = tr("FC_PRAISE_%d" % clampi(cards, 1, State.CLUES))
	if right and not demo:
		fx.sparkle(_slate_centre(), Pal.SUN)
		fx.ring(_slate_centre(), _l("slate_w") * 0.4, Pal.GOOD)
		if cards <= 2:
			fx.confetti(_card_pos(2), 14, _l("card_w"))
	# on to the next by itself once the cards have been read
	if not demo:
		var no := _round_no
		_after(NEXT_RIGHT if right else NEXT_LOST, func() -> void:
			if no == _round_no and _phase == Phase.OVER:
				_next())

func _next() -> void:
	if _st.index + 1 >= _st.count():
		_solved_now()
		return
	_st.next_round()
	_cue("next")
	_fresh_round()

func _solved_now() -> void:
	_phase = Phase.DONE
	_won_at = _t
	_dismiss()
	_cue("solved")
	if not demo:
		_after(0.4, func() -> void:
			fx.confetti(Vector2(size.x * 0.5, _l("pills_y")), 26, size.x * 0.7)
			_cue("party" if not _st.results.has(0) and _st.quality() >= 0.5 else "confetti"))
	check_solved()

func is_solved() -> bool:
	return _st.solved() and _phase == Phase.DONE

func hint() -> bool:
	if hints_left() <= 0 or _phase != Phase.PLAY or is_done():
		return false
	if _st.hint() < 0:
		return false
	hints_used += 1
	_cue("hint")
	_summon()
	if not demo:
		fx.sparkle(_slate_centre() + Vector2(0.0, _l("slate_h") * 0.42), Pal.SUN)
	return true

func _say_now(text: String) -> void:
	_say = text
	_say_at = _t

func _cue(name: String, pitch := 1.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch)

## The tutorial's hands: a whole line typed and Entered (an empty one turns
## a card).
func demo_line(line: String) -> void:
	_typed = line.to_upper()
	commit_row()

func state():
	return _st

func phase() -> int:
	return _phase

func dealt() -> bool:
	return _dealt

func slate_to_local() -> Vector2:
	return _slate_centre()

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if not demo:
		_watch_osk()
	if clock_held and not demo:
		_dismiss()
		return
	_t += delta
	while not _queue.is_empty() and float(_queue[0][0]) <= _t:
		var job: Array = _queue.pop_front()
		(job[1] as Callable).call()
	if _say != "" and _t - _say_at > SAY_TIME:
		_say = ""
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if demo:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		match _phase:
			Phase.OVER:
				# any tap moves on once the cards have had their moment
				if _t - _over_at >= NEXT_GUARD:
					_next()
			Phase.PLAY:
				# a face-down card turns the next; anywhere else calls the
				# keyboard back up
				if _card_at(event.position) >= _st.shown:
					turn_next()
				_summon()

## The card under `at`, or -1.
func _card_at(at: Vector2) -> int:
	for i in State.CLUES:
		if Rect2(_card_pos(i) - Vector2(_l("card_w"), _l("card_h")) * 0.5, Vector2(_l("card_w"), _l("card_h"))).grow(_l("gap") * 0.5).has_point(at):
			return i
	return -1

## The phone's keyboard's top, followed: the board lays itself out above
## it while it is up. Its height comes in the window's pixels.
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
	_round_at = -10.0
	if not _turned_at.is_empty():
		_turned_at[0] = minf(_turned_at[0], -10.0)

func _relayout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	if _osk > 0.0:
		bottom = minf(bottom, size.y - _osk - OSK_GAP * size.x / W)
	_L = _layout_for(top, bottom)
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		_world.set_lines(_L.cork as Rect2, _L.slate as Rect2)
	if _field != null:
		var r: Rect2 = _L.slate
		_field.position = r.position
		_field.size = r.size
	queue_redraw()

## Laid in the span between the rows; tight while the phone's keyboard is up
## (a 16:9 phone leaves the board some 600 of its 1920): the pills, slate
## and gaps shrink, and the passing word rides the cork's foot, not a row.
func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var tight := _osk > 0.0
	var span := maxf(bottom - top, 300.0 * u)
	var gap := (8.0 if tight else CARD_GAP) * u
	var pills_h := (PILL_R * 2.0 * u + 20.0 * u) * (0.75 if tight else 1.0)
	var say_h := 0.0 if tight else 44.0 * u
	var tried_h := 40.0 * u
	var hearts_h := (32.0 if tight else 44.0) * u if State.TRIES[_band] > 0 else 0.0
	var slate_h := SLATE_H * u * (0.74 if tight else 1.0)
	var air := (14.0 if tight else 70.0) * u
	var after_pills := (10.0 if tight else 24.0) * u
	var after_cards := (16.0 if tight else 34.0) * u
	var room := span - pills_h - after_pills - after_cards - say_h - tried_h - hearts_h - slate_h - air
	var card_h := minf(CARD.y * u, (room - (State.CLUES - 1) * gap) / State.CLUES)
	card_h = maxf(card_h, 40.0 * u)
	var card_w := minf(CARD.x * u, w * 0.8)
	var stack_h := State.CLUES * card_h + (State.CLUES - 1) * gap
	var used := pills_h + after_pills + stack_h + after_cards + slate_h + tried_h + hearts_h + say_h + air
	var y := top + maxf((4.0 if tight else 10.0) * u, (span - used) * 0.4)
	var pills_y := y + pills_h * 0.5
	y += pills_h + after_pills
	var cards_top := y
	var cork := Rect2(w * 0.5 - card_w * 0.5 - 40.0 * u, cards_top - 22.0 * u * (0.5 if tight else 1.0), card_w + 80.0 * u, stack_h + 44.0 * u * (0.5 if tight else 1.0))
	y += stack_h + after_cards
	var slate_w := minf(w * 0.86, 820.0 * u)
	var slate := Rect2(w * 0.5 - slate_w * 0.5, y, slate_w, slate_h)
	y += slate_h + (6.0 if tight else 12.0) * u
	var tried_y := y + tried_h * 0.5
	y += tried_h
	var hearts_y := y + hearts_h * 0.5
	y += hearts_h
	return {
		"u": u, "top": top, "bottom": bottom, "pills_y": pills_y, "pill_k": 0.75 if tight else 1.0,
		"cards_top": cards_top, "card_w": card_w, "card_h": card_h, "gap": gap,
		"cork": cork, "slate": slate, "slate_w": slate_w, "slate_h": slate_h,
		"hearts_y": hearts_y, "say_y": cork.end.y - 6.0 * u if tight else y + say_h * 0.5, "tried_y": tried_y,
	}

func _l(key: String) -> float:
	return float(_L.get(key, 0.0))

func _u() -> float:
	return float(_L.get("u", 1.0))

func _card_pos(i: int) -> Vector2:
	return Vector2(size.x * 0.5, _l("cards_top") + _l("card_h") * 0.5 + i * (_l("card_h") + _l("gap")))

func _slate_centre() -> Vector2:
	var r: Rect2 = _L.get("slate", Rect2())
	return r.get_center()

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or not _dealt or _st.rounds.is_empty():
		return
	_draw_pills()
	for i in State.CLUES:
		_draw_card(i)
	_draw_slate()
	_draw_tried()
	_draw_tries()
	_draw_say()
	_draw_praise()

func _card_mesh(face: bool) -> ArrayMesh:
	var key := "%s:%d:%d" % [face, roundi(_l("card_w")), roundi(_l("card_h"))]
	if not _cards.has(key):
		var b := Face.Builder.new()
		if face:
			Art.card(b, Vector2.ZERO, Vector2(_l("card_w"), _l("card_h")))
		else:
			Art.back(b, Vector2.ZERO, Vector2(_l("card_w"), _l("card_h")))
		_cards[key] = b.mesh()
	return _cards[key]

## A clue card: its back until it turns, then flipping over to its word.
func _draw_card(i: int) -> void:
	var u := _u()
	var at := _card_pos(i)
	var e := _t - _round_at - Motion.ENTER_DELAY - i * 0.06
	if e < 0.0 and not Motion.reduce:
		return
	var a := 1.0
	if e < Motion.DROP_TIME and not Motion.reduce:
		at.y -= Motion.drop_in_lift(e, Motion.DROP * u)
		a = Motion.appear_level(e)
	var turn := _t - _turned_at[i]
	var up := _turned_at[i] > -INF and turn >= 0.0
	var sx := 1.0
	var face := up
	if up and turn < TURN_TIME and not Motion.reduce:
		var k := turn / TURN_TIME
		sx = absf(cos(k * PI))
		face = k >= 0.5
	if i == _st.shown - 1 and _shake_at > -INF and _phase == Phase.PLAY and not Motion.reduce:
		at.x += Motion.shiver_offset(_t - _shake_at, Motion.SHIVER_PX * 2.0 * u, Motion.SHIVER_TIME * 1.4)
	var hop := 0.0
	if _phase == Phase.OVER and _st.results.size() > 0 and _st.results[_st.results.size() - 1] > 0 and not Motion.reduce:
		var he := _t - _over_at - 0.3 - i * 0.05
		if he >= 0.0 and he < Motion.SOLVE_TIME:
			hop = Motion.hop_lift(he, Motion.SOLVE_HOP * u, Motion.SOLVE_TIME)
	at.y += hop
	draw_mesh(_card_mesh(face), null, Transform2D(0.0, Vector2(sx, 1.0), 0.0, at), Color(1, 1, 1, a))
	var font: Font = CozyTheme.display(800)
	if face:
		var word: String = String(_st.round_now().clues[i]).to_upper()
		_text(font, word, at + Vector2(0.0, 2.0 * u), _l("card_w") * 0.8 * sx, CARD_SIZE * u, CARD_MIN * u, Color(Art.INK, a))
	elif i == _st.shown and _phase == Phase.PLAY and not demo:
		# the next card asks to be tapped
		var breathe := 1.0 if Motion.reduce else 0.75 + 0.25 * sin(_t * 3.2)
		var body: Font = CozyTheme.display(700)
		_text(body, "%d  ·  %s" % [i + 1, tr("FC_TAP_TURN")], at + Vector2(0.0, 2.0 * u), _l("card_w") * 0.86 * sx, 30.0 * u, 16.0 * u, Color(Art.BACK_INK, a * breathe))
	else:
		var n := str(i + 1)
		_text(font, n, at + Vector2(0.0, 2.0 * u), _l("card_w") * sx, CARD_SIZE * u, CARD_MIN * u, Color(Art.BACK_INK, a))

func _text(font: Font, s: String, at: Vector2, width: float, size_px: float, min_px: float, ink: Color) -> void:
	if width <= 4.0:
		return
	var fs := roundi(size_px)
	var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > width:
		fs = maxi(roundi(min_px), int(fs * width / tw))
		tw = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

## The slate: the line being typed, the bulb's letters under it, and once a
## round is over the idea chalked on it (leaf ink when found).
func _draw_slate() -> void:
	var u := _u()
	var c := _slate_centre()
	var sw := _l("slate_w")
	var sh := _l("slate_h")
	var font: Font = CozyTheme.display(800)
	if _phase == Phase.OVER or _phase == Phase.DONE:
		var r: Dictionary = _st.round_now()
		var found: bool = _st.results.size() > _st.index and _st.results[_st.index] > 0
		var e := _t - _over_at
		var k := clampf(e / Motion.POP_IN, 0.0, 1.0) if not Motion.reduce else 1.0
		var label: String = r.label
		if not found:
			label = tr("FC_IT_WAS") % label
		_text(font, label, c + Vector2(0.0, -sh * 0.12), sw * 0.9 * k, LABEL_SIZE * u, 20.0 * u, Art.CHALK_LEAF if found else Art.CHALK_DIM)
		var body: Font = CozyTheme.display(700)
		var cards: int = _st.results[_st.index]
		var note: String = ((tr("FC_FOUND_ONE") if cards == 1 else tr("FC_FOUND_N")) % cards) if found else tr("FC_LOST")
		note += "  ·  " + (tr("FC_NEXT") if _st.index + 1 < _st.count() else tr("FC_DONE"))
		_text(body, note, c + Vector2(0.0, sh * 0.26), sw * 0.9, 24.0 * u, 16.0 * u, Color(Art.CHALK, 0.8))
		return
	var shown := _typed if _typed != "" else ""
	if shown == "":
		# the bulb's letters, once lit, stand in for the prompt
		if _st.hinted == 0:
			var body: Font = CozyTheme.display(700)
			_text(body, tr("FC_TYPE"), c + Vector2(0.0, -sh * 0.08), sw * 0.9, 30.0 * u, 16.0 * u, Color(Art.CHALK, 0.45))
	else:
		var x := 0.0
		if _shake_at > -INF and not Motion.reduce:
			x = Motion.shiver_offset(_t - _shake_at, Motion.SHIVER_PX * 3.0 * u, Motion.SHIVER_TIME * 1.4)
		_text(font, shown, c + Vector2(x, -sh * 0.08), sw * 0.9, LINE_SIZE * u, 22.0 * u, Art.CHALK)
	if _st.hinted > 0:
		var body: Font = CozyTheme.display(700)
		var hy := sh * 0.3 if shown != "" else -sh * 0.04
		_text(body, _st.hint_line(), c + Vector2(0.0, hy), sw * 0.9, 28.0 * u, 16.0 * u, Color(Pal.SUN_RAY, 0.95))

## A pill a round along the top: its count of cards once done (a cross for a
## round lost), the round in hand ringed.
func _draw_pills() -> void:
	var u := _u()
	var n: int = _st.count()
	var gap := PILL_R * 2.8 * u * _l("pill_k")
	var font: Font = CozyTheme.display(800)
	for i in n:
		var at := Vector2(size.x * 0.5 + (i - (n - 1) * 0.5) * gap, _l("pills_y"))
		var r := PILL_R * u * _l("pill_k")
		var done: bool = i < _st.results.size()
		var res: int = _st.results[i] if done else -1
		var wave := 0.0
		if _won_at > -INF and not Motion.reduce:
			var we := _t - _won_at - i * 0.08
			if we >= 0.0:
				wave = Motion.hop_lift(fmod(we, 1.6), Motion.SOLVE_HOP * 1.5 * u, Motion.SOLVE_TIME)
		at.y += wave
		Art.draw_pill(self, at, r, res, i == _st.index and _phase != Phase.DONE)
		if done:
			_text(font, "✕" if res == 0 else str(res), at + Vector2(0.0, 1.0 * u), r * 1.6, 28.0 * u, 14.0 * u, Pal.SURFACE)

func _draw_tries() -> void:
	if _st.tries() <= 0 or _phase == Phase.DONE:
		return
	var u := _u()
	var n: int = _st.tries()
	var gap := 20.0 * 2.6 * u
	for i in n:
		var at := Vector2(size.x * 0.5 + (i - (n - 1) * 0.5) * gap, _l("hearts_y"))
		Hearts.draw_heart(self, at, 18.0 * u, i < n - _st.wrongs)

func _draw_say() -> void:
	if _say == "":
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var fs := roundi(SAY_SIZE * u)
	var tw := font.get_string_size(_say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var a := clampf((SAY_TIME - (_t - _say_at)) / 0.4, 0.0, 1.0)
	var at := Vector2(size.x * 0.5 - tw * 0.5, _l("say_y") + fs * 0.35)
	draw_string_outline(font, at, _say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(8 * u), Color(Pal.SURFACE, 0.85 * a))
	draw_string(font, at, _say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.TEXT, a))

## This round's wrong lines in a row under the slate, each struck through,
## so what was tried stays in sight.
func _draw_tried() -> void:
	if _tried.is_empty() or _phase == Phase.DONE:
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var fs := roundi(TRIED_SIZE * u)
	var gap := 26.0 * u
	var widths: Array[float] = []
	var total := 0.0
	for line in _tried:
		var tw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(tw)
		total += tw
	total += gap * (_tried.size() - 1)
	var room := _l("slate_w")
	if total > room:
		fs = maxi(roundi(14.0 * u), int(fs * room / total))
		total = 0.0
		for k in _tried.size():
			widths[k] = font.get_string_size(_tried[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			total += widths[k]
		total += gap * (_tried.size() - 1)
	var x := size.x * 0.5 - total * 0.5
	var y := _l("tried_y")
	var ink := Color(Pal.TEXT, 0.7)
	for k in _tried.size():
		var base := Vector2(x, y + fs * 0.35)
		draw_string_outline(font, base, _tried[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(7 * u), Color(Pal.SURFACE, 0.8))
		draw_string(font, base, _tried[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		draw_line(Vector2(x - 4.0 * u, y), Vector2(x + widths[k] + 4.0 * u, y), Color(Pal.BAD, 0.85), maxf(2.0, 3.0 * u))
		x += widths[k] + gap

## The word of praise for a round found, stamped over the cork as the cards
## turn, and gone before the next round.
func _draw_praise() -> void:
	if _praise == "" or _phase != Phase.OVER:
		return
	var e := _t - _over_at - 0.15
	if e < 0.0 or e > PRAISE_TIME:
		return
	var u := _u()
	var font: Font = CozyTheme.display(800)
	var fs := roundi(PRAISE_SIZE * u)
	var tw := font.get_string_size(_praise, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var k := clampf(e / 0.22, 0.0, 1.0)
	var sc := 1.0 if Motion.reduce else lerpf(1.6, 1.0, 1.0 - pow(1.0 - k, 3.0))
	var a := clampf((PRAISE_TIME - e) / 0.35, 0.0, 1.0) * (1.0 if Motion.reduce else k)
	var c: Vector2 = (_L.cork as Rect2).get_center()
	draw_set_transform(c, -0.07, Vector2(sc, sc))
	var at := Vector2(-tw * 0.5, fs * 0.35)
	draw_string_outline(font, at, _praise, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(14 * u), Color(Pal.SURFACE, a))
	draw_string(font, at, _praise, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.GOOD, a))
	draw_set_transform(Vector2.ZERO)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func skill_quality() -> float:
	if _st.rounds.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🔎\n" + _st.share_glyphs()

func flat_win() -> Dictionary:
	var found := 0
	var cards := 0
	for n in _st.results:
		if n > 0:
			found += 1
			cards += n
	var line: String = tr("FC_WIN") % [found, _st.count()]
	if found > 0:
		line += " " + tr("FC_WIN_CARDS") % (float(cards) / found)
	return {"faces": [], "subtitle": line}

func completion_record() -> Dictionary:
	return {"results": Array(_st.results)}

func restore_completed_board() -> void:
	_gen += 1
	var key := daily_key if daily_key != 0 else _seed_key
	if not _st.setup_day(Backend.cached_day(State.GAME, key) if daily_key != 0 else {}, key, _band):
		_st.setup(key, _band)
	_st.finish(completed_record.get("results", []) as Array)
	_dealt = true
	_queue.clear()
	_fresh_round()
	for i in State.CLUES:
		_turned_at[i] = -10.0
	_round_at = -10.0
	_phase = Phase.DONE
	_over_at = -10.0
	_won_at = _t
	queue_redraw()
