extends "res://core/puzzle_base.gd"

## Four Shelves (spec docs/superpowers/specs/2026-10-22-shelves-design.md): a
## words board. Jam jars stand on an old pantry dresser, a word on each
## jar's label, and every word belongs to exactly one hidden shelf of four.
## Tap four jars and Shelve them: four of one shelf rise to the top of the
## dresser, where a plank in the shelf's colour names them; anything else
## costs a heart, and three of one shelf are said to be close. Every shelf
## up is the day. Out of hearts, a card offers one more heart (a video, once)
## or Show the shelves, which puts the rest up by themselves and ends the
## day unsolved. The rules are puzzles/shelves_state.gd's.
##
## **The pantry is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/shelves_world.gd) is the board's first child. The jars,
## planks and hearts are ui/faces/shelves_art.gd's; the keys under the
## dresser are Honeycomb's (ui/faces/honeycomb_art.gd), the same keys.
##
## A daily's puzzle is written at night (server/functions/src/shelves.ts)
## and fetched as Golden Acorn's is: at once when this phone holds it, after
## one short wait when it does not, and from the bank when nobody could.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, dealt `demo_puzzle`, and
## ui/hud/shelves_tutorial_diagram.gd plays it with `demo_tap`/`demo_key`.

const State = preload("res://puzzles/shelves_state.gd")
const World = preload("res://puzzles/shelves_world.gd")
const Art = preload("res://ui/faces/shelves_art.gd")
const Keys = preload("res://ui/faces/honeycomb_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Backend = preload("res://core/backend.gd")

const Said = State.Said
const Key = Keys.Key

const HAPTICS := {
	"pick": Haptics.TICK,
	"drop": Haptics.TICK,
	"shuffle": Haptics.TAP,
	"clear": Haptics.TICK,
	"shelf": Haptics.GOOD,
	"close": Haptics.WARN,
	"wrong": Haptics.WARN,
	"repeat": Haptics.TICK,
	"hush": Haptics.TICK,
	"out": Haptics.LOSE,
	"reveal": Haptics.TICK,
	"hint": Haptics.GOOD,
	"heart": Haptics.GOOD,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## How long a slow network is waited on before the bank deals instead.
const FETCH_WAIT := 4.0
## A row of the dresser at W, its gap, the jars' room and the keys'.
const ROW_H := 150.0
const ROW_GAP := 18.0
const KEY_R := 62.0
const KEY_GAP := 70.0
const HEART_R := 20.0
## The words, at W.
const WORD_MAX := 40
const WORD_MIN := 18
const LABEL_SIZE := 30
const SHELF_WORDS := 24
const SAY_SIZE := 30
## The motions: jars sliding to new places, a shelf rising, a line said.
const SLIDE_TIME := 0.34
const RISE_TIME := 0.42
const SAY_TIME := 2.2
const CARD_AFTER := 1.1
const REVEAL_STEP := 0.55
const WIN_HOLD := 1.3
## The beat before a verdict (2026-10-28, "nobody likes it"): the four
## picked jars hop one after another, each a pop a little higher, and only
## then is the four judged. The hop's height at W, a jar's start after the
## last's, and the breath after the fourth.
const JUDGE_HOP := 26.0
const JUDGE_STEP := 0.11
const JUDGE_HOLD := 0.14
## The last shelf goes up by itself, this long after the one before it.
const LAST_AFTER := 0.5
## Picked jars hold jam; a shelf's jars hold its colour's.
const JAM := Color("e7748a")
## How many "a shelf went up" cheers there are (FS_CHEER_1..).
const CHEERS := 6

## Built silent and deaf for the tutorial's page, and dealt this puzzle.
var demo := false
var demo_puzzle := {}

var _st = State.new()
var _band := 0
var _gen := 0
var _seed_key := 0
var _dealt := false
var _t := 0.0
var _queue: Array = []
var _enter_at := 0.0
var _won_at := -INF
## Per word: where it was drawn before the last change and since when; when
## it was last tapped; when it last shivered.
var _from := {}
var _moved_at := -INF
var _tap_at := {}
var _shiver_at := -INF
var _shiver: Array[String] = []
## Per shelf: when it went up.
var _up_at := {}
var _heart_at := -INF
var _say := ""
var _say_at := -INF
## Out of hearts: the card, whether its heart was had, a reveal running.
var out_of_hearts := false
var _card: Control
var _heart_bought := false
var _revealing := false
## The four being judged (hopping), since when; the last shelf on its way.
var _judging: Array = []
var _judge_at := -INF
var _last_pending := false
var _last_up_now := false
var _pressing := -2
var _rng := RandomNumberGenerator.new()
## The layout: where the rows let the board be, and what it sets there.
var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _world: Control
var _jar_key := ""
var _planks := {}
var _keys_mesh: ArrayMesh
var _keys_key := ""
var fx: Node

func puzzle_id() -> String: return "shelves"
func title() -> String: return "Four Shelves"

func rules() -> String:
	var n: int = State.GROUPS[_band]
	var out := tr("FS_RULES") % [n * 4, n, State.HEARTS]
	if _band == 3:
		out += "\n\n" + tr("FS_RULES_CROWDED")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/shelves_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.PICK, "HTP_FS_PICK", tr("HTP_FS_PICK_BODY")],
		[Diagram.Lesson.CLOSE, "HTP_FS_CLOSE", tr("HTP_FS_CLOSE_BODY") % State.HEARTS],
	]
	if _band == 3:
		steps.append([Diagram.Lesson.CROWDED, "HTP_FS_CROWDED", tr("HTP_FS_CROWDED_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_FS_HINT", tr("HTP_FS_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Only the bulb: a shelf up stays up, and the board says itself what each
## Shelve was.
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
	resized.connect(_relayout)
	if demo:
		_make_world()
		_relayout()

func _exit_tree() -> void:
	if is_instance_valid(_card):
		_card.queue_free()

## The host says which day the board is right after start(), so nothing is
## dealt here: `_deal` asks once the day is known.
func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	_band = clampi(difficulty, 0, 3)
	_seed_key = int(rng.randi())
	_rng.seed = rng.randi()
	_dealt = false
	_st = State.new()
	_st.band = _band
	if demo:
		_st.setup_fixed(demo_puzzle, _band)
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
	_st.setup(key, _band)
	_begin()

func _begin() -> void:
	_dealt = true
	_queue.clear()
	_from.clear()
	_up_at.clear()
	_tap_at.clear()
	_enter_at = _t
	out_of_hearts = false
	_relayout()
	_cue("enter")

func day_dict() -> Dictionary:
	if not _dealt:
		return {"pending": true}
	if _st.groups.is_empty():
		return {}
	return {
		"source": "bank" if _st.source == "bank" else "server", "kind": "text",
		"payload": {"id": _st.id, "words": Array(_st.tiles), "lang": TranslationServer.get_locale().substr(0, 2)},
		"solution": {"groups": _st.groups},
		"metrics": {"groups": _st.count(), "written_by": _st.source},
	}

# --- the jars ---

func _after(delay: float, what: Callable) -> void:
	_queue.append([_t + delay, what])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

## Every jar's place is about to change: each is drawn from where it stands now.
func _hold_places() -> void:
	var now := {}
	for w in _st.tiles:
		now[w] = _jar_pos(w)
	_from = now
	_moved_at = _t

func busy() -> bool:
	return _revealing or out_of_hearts or _last_pending or not _judging.is_empty() \
		or _t < _moved_at + SLIDE_TIME * 0.6

func _tap(i: int) -> void:
	if not _dealt or is_done() or _won or _st.solved():
		return
	if busy() or i < 0 or i >= _st.tiles.size():
		_cue("hush")
		return
	var w: String = _st.tiles[i]
	var was: bool = _st.picked.has(w)
	if not was and _st.picked.size() >= 4:
		_shiver = _st.picked.duplicate()
		_shiver_at = _t
		_cue("hush")
		return
	_st.toggle(w)
	_tap_at[w] = _t
	_cue("drop" if was else "pick", randf_range(0.96, 1.04) + (0.0 if was else _st.picked.size() * 0.04))

func _press_key(k: int) -> void:
	if not _dealt or is_done() or _won or _st.solved():
		return
	if busy():
		_cue("hush")
		return
	match k:
		Key.SHUFFLE:
			_hold_places()
			_st.shuffle(_rng)
			_cue("shuffle")
		Key.DELETE:
			if _st.picked.is_empty():
				_cue("hush")
				return
			for w in _st.picked:
				_tap_at[w] = _t
			_st.clear_picks()
			_cue("clear")
		_:
			_shelve()

func _shelve() -> void:
	if _st.picked.size() != 4:
		_shiver = _st.picked.duplicate()
		_shiver_at = _t
		_cue("hush")
		return
	var picked: Array = _st.picked.duplicate()
	if Motion.reduce or _st.tried(picked):
		_judge(picked)
		return
	# the beat: each picked jar hops in the order it was picked, then the verdict
	_judging = picked
	_judge_at = _t
	for k in 4:
		_after(k * JUDGE_STEP, func() -> void: _cue("pick", 1.0 + 0.09 * k))
	_after(3 * JUDGE_STEP + Motion.HOP_TIME * 0.5 + JUDGE_HOLD, func() -> void:
		_judging = []
		_judge(picked))

func _judge(picked: Array) -> void:
	if _st.solved() or _st.out():
		return
	var said: int = _st.submit()
	if said == Said.IGNORED:
		return
	if said == Said.REPEAT:
		_say_now(tr("FS_REPEAT"))
		_shiver = picked
		_shiver_at = _t
		_cue("repeat")
		return
	moves += 1
	moved.emit()
	if said == Said.SHELVED or said == Said.SOLVED:
		var g: int = _st.shelved[_st.shelved.size() - 1]
		_up(g, picked)
		if _last_up_now:
			_say_now(tr("FS_LAST"))
		else:
			_cheer(g)
		if said == Said.SOLVED:
			_solved_now()
		elif _st.tiles.size() == 4:
			_last_pending = true
			_after(LAST_AFTER + RISE_TIME, _last_up)
		return
	_shiver = picked
	_shiver_at = _t
	_heart_at = _t
	_cue("close" if said == Said.CLOSE else "wrong")
	if said == Said.CLOSE:
		_say_now(tr("FS_CLOSE"))
	elif said == Said.WRONG:
		_say_now(tr(["FS_WRONG", "FS_WRONG_2", "FS_WRONG_3"][(_st.mistakes - 1) % 3]))
	else:
		_run_out()

## A shelf goes up: its jars slide to its row, the plank pops in under them.
func _up(g: int, words: Array) -> void:
	var now := {}
	for w in words:
		now[w] = _jar_pos_any(w)
	for w in _st.tiles:
		now[w] = _jar_pos_any(w)
	_from = now
	_moved_at = _t
	_up_at[g] = _t
	_cue("shelf", 1.0 + _st.shelved.size() * 0.05)
	if not demo:
		_after(RISE_TIME, func() -> void: fx.sparkle(_row_centre(_st.shelved.find(g)), Pal.SUN))

## A shelf up is cheered: the day's subtlest shelf as a trick seen
## through, the others in a line that changes a shelf to the next.
func _cheer(g: int) -> void:
	if demo:
		return
	if g == _st.count() - 1 and _st.count() > 1:
		_say_now(tr("FS_SNEAKY"))
	else:
		_say_now(tr("FS_CHEER_%d" % (1 + (_st.shelved.size() + _seed_key) % CHEERS)))

## Only one shelf left: its four go up by themselves, as the player's.
func _last_up() -> void:
	_last_pending = false
	if _st.tiles.size() != 4 or is_done() or out_of_hearts:
		return
	_st.picked.assign(_st.tiles)
	_last_up_now = true
	_judge(_st.picked.duplicate())
	_last_up_now = false

func _say_now(text: String) -> void:
	_say = text
	_say_at = _t

## Out of hearts: the picked jars put back, a line, and the card.
func _run_out() -> void:
	out_of_hearts = true
	_st.clear_picks()
	_say_now(tr("FS_OUT_LINE"))
	if demo:
		return
	_after(CARD_AFTER, _open_card)

func _open_card() -> void:
	if not out_of_hearts or _revealing or is_done() or is_instance_valid(_card):
		return
	var card: Control = load("res://ui/hud/out_of_rows.gd").new(_heart_bought, {
		"title": "FS_OUT_TITLE", "body": "FS_OUT_BODY", "body_rest": "FS_OUT_BODY_REST",
		"more": "FS_ONE_HEART", "show": "FS_SHOW", "placement": "heart"})
	_card = card
	card.one_more_row.connect(heart_back)
	card.show_code.connect(show_shelves)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

func _close_card() -> void:
	if is_instance_valid(_card) and not _card.is_queued_for_deletion():
		_card.queue_free()
	_card = null

## One more heart (the card's video), once a board.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_st.add_heart()
	_heart_bought = true
	out_of_hearts = false
	_heart_at = _t
	_cue("heart")
	_say_now(tr("FS_HEART_BACK"))
	moved.emit()

## Show the shelves: every shelf still down goes up by itself, one after
## another, then the day ends unsolved.
func show_shelves() -> void:
	if is_done():
		return
	_close_card()
	_revealing = true
	var left: int = _st.count() - _st.shelved.size()
	var step := 0.05 if Motion.reduce else REVEAL_STEP
	for k in left:
		_after(0.3 + k * step, func() -> void:
			var g: int = _st.reveal_next()
			if g < 0:
				return
			_up(g, _st.groups[g].words)
			_cue("reveal", maxf(1.0 - 0.04 * k, 0.8)))
	_after(0.4 + left * step + RISE_TIME, func() -> void:
		_revealing = false
		out_of_hearts = false
		_say_now(tr("FS_SHOWN_LINE"))
		finish_unsolved())

func _solved_now() -> void:
	_won_at = _t + RISE_TIME
	_after(RISE_TIME * 0.8, func() -> void: _cue("solved"))
	if not demo:
		_after(0.6, func() -> void:
			fx.confetti(Vector2(size.x * 0.5, _l("top_y")), 26, size.x * 0.7)
			_cue("party" if _st.mistakes == 0 else "confetti"))
	check_solved()

## Shelves put up by Show the shelves are not a solve.
func is_solved() -> bool:
	return _st.solved() and _st.shown.is_empty()

## The bulb: the most obvious shelf still down shows one more of its words,
## picked for the player.
func hint() -> bool:
	if hints_left() <= 0 or not _dealt or is_done() or busy():
		return false
	var g: int = _st.hint()
	if g < 0:
		return false
	hints_used += 1
	for w in _st.picked:
		_tap_at[w] = _t
	_cue("hint")
	if not demo:
		for w in _st.picked:
			fx.sparkle(_jar_pos(w), Pal.SUN)
	return true

func _cue(name: String, pitch := 1.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch)

func demo_tap_word(w: String) -> void:
	_tap(_st.tiles.find(w))

func demo_key(k: int) -> void:
	_press_key(k)

func state():
	return _st

func dealt() -> bool:
	return _dealt

## Where a finger tapping jar `i` goes, and one pressing key `k`.
func tile_to_local(i: int) -> Vector2:
	return _jar_pos(_st.tiles[i])

func word_to_local(w: String) -> Vector2:
	return _jar_pos(w)

func key_to_local(k: int) -> Vector2:
	return _key_pos(k)

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	while not _queue.is_empty() and float(_queue[0][0]) <= _t:
		var job: Array = _queue.pop_front()
		(job[1] as Callable).call()
	if _say != "" and _t - _say_at > SAY_TIME and not out_of_hearts:
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
				_press_key(k)
				return
			var i := tile_at(event.position)
			if i >= 0:
				_tap(i)
			elif not is_done() and not _won:
				_cue("hush")
		elif finger == _pressing:
			_pressing = -2

## The jar a finger means: the one whose rect holds it, a little grown.
func tile_at(local: Vector2) -> int:
	if _L.is_empty() or _won or is_done():
		return -1
	var tw := _l("tile_w")
	var th := _l("row_h")
	for i in _st.tiles.size():
		var c := _jar_pos(_st.tiles[i])
		if absf(local.x - c.x) < tw * 0.52 and absf(local.y - c.y) < th * 0.56:
			return i
	return -1

func key_at(local: Vector2) -> int:
	if _L.is_empty() or _won or is_done():
		return -1
	for k in 3:
		if local.distance_to(_key_pos(k)) < _l("key_r") * 1.25:
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
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	_from.clear()
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		_world.set_lines(_L.dresser as Rect2, float(_L.counter))
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 300.0 * u)
	var rows: int = maxi(3, State.GROUPS[_band])
	var ended := _won or is_done()
	var keys_h := 0.0 if ended else KEY_R * 2.0 * u + 30.0 * u
	var hearts_h := 0.0 if ended else 56.0 * u
	var say_h := 0.0 if ended else 50.0 * u
	var room := span - keys_h - hearts_h - say_h - 40.0 * u
	var row_h := minf(ROW_H * u, (room - (rows - 1) * ROW_GAP * u) / rows)
	row_h = maxf(row_h, 60.0 * u)
	var grid_w := minf(w * 0.92, 1000.0 * u)
	var tile_w := grid_w / 4.0
	var grid_h := rows * row_h + (rows - 1) * ROW_GAP * u
	var used := grid_h + hearts_h + say_h + keys_h
	var top_y := top + maxf(20.0 * u, (span - used) * 0.45)
	var dresser := Rect2(w * 0.5 - grid_w * 0.5 - 30.0 * u, top_y - 34.0 * u, grid_w + 60.0 * u, grid_h + 68.0 * u)
	var hearts_y := top_y + grid_h + 34.0 * u + hearts_h * 0.5
	var say_y := hearts_y + hearts_h * 0.5 + say_h * 0.5
	var keys_y := say_y + say_h * 0.5 + KEY_R * u + 10.0 * u
	return {
		"u": u, "top": top, "bottom": bottom, "rows": rows,
		"row_h": row_h, "tile_w": tile_w, "grid_w": grid_w, "top_y": top_y,
		"dresser": dresser, "counter": dresser.end.y,
		"hearts_y": hearts_y, "say_y": say_y, "keys_y": keys_y, "key_r": KEY_R * u,
	}

func _l(key: String) -> float:
	return float(_L.get(key, 0.0))

func _u() -> float:
	return float(_L.get("u", 1.0))

func _row_centre(r: int) -> Vector2:
	return Vector2(size.x * 0.5, _l("top_y") + r * (_l("row_h") + ROW_GAP * _u()) + _l("row_h") * 0.5)

## Where a jar stands now: its place among the jars still down, or, for a
## shelved word, its place on its shelf's row.
func _jar_pos_any(w: String) -> Vector2:
	var g: int = _st.group_of(w)
	var r: int = _st.shelved.find(g)
	if r >= 0:
		var k: int = (_st.groups[g].words as Array).find(w)
		return _cell(r, k)
	return _jar_pos(w)

func _jar_pos(w: String) -> Vector2:
	var i: int = _st.tiles.find(w)
	if i < 0:
		return _jar_pos_any(w) if _st.group_of(w) >= 0 and _st.shelved.has(_st.group_of(w)) else Vector2.ZERO
	var r: int = _st.shelved.size() + i / 4
	return _cell(r, i % 4)

func _cell(r: int, c: int) -> Vector2:
	var rc := _row_centre(r)
	return Vector2(rc.x + (c - 1.5) * _l("tile_w"), rc.y)

## Where a jar is drawn this frame: sliding from its last place.
func _drawn_at(w: String, to: Vector2) -> Vector2:
	if not _from.has(w) or Motion.reduce:
		return to
	var k := clampf((_t - _moved_at) / SLIDE_TIME, 0.0, 1.0)
	if k >= 1.0:
		return to
	var s := k * k * (3.0 - 2.0 * k)
	var from: Vector2 = _from[w]
	return from.lerp(to, s) + Vector2(0.0, -sin(s * PI) * 30.0 * _u())

func _key_pos(k: int) -> Vector2:
	return Vector2(size.x * 0.5 + (k - 1) * (_l("key_r") * 2.0 + KEY_GAP * _u()), _l("keys_y"))

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or not _dealt or _st.groups.is_empty():
		return
	var th := _l("row_h")
	# the rows: shelves up first, then the jars still down
	for r in _st.count():
		if r < _st.shelved.size():
			_draw_shelf(r)
		else:
			draw_mesh(_plank_mesh(-1), null, Transform2D(0.0, _row_centre(r) + Vector2(0.0, th * 0.5)))
	var font: Font = CozyTheme.display(800)
	for i in _st.tiles.size():
		var w: String = _st.tiles[i]
		_draw_jar(w, _jar_pos(w), font)
	# the jars of a shelf going up, still sliding to it
	for r in _st.shelved.size():
		var g: int = _st.shelved[r]
		if _t - float(_up_at.get(g, -INF)) < SLIDE_TIME and not Motion.reduce:
			for w: String in _st.groups[g].words:
				_draw_jar(w, _jar_pos_any(w), font, true)
	if not _won and not is_done():
		_draw_hearts()
		_draw_say()
		_draw_keys()

## A jar, empty or holding `jam`; one mesh a size and a jam, kept.
var _jars := {}

func _jar_mesh(jam := Color.TRANSPARENT) -> ArrayMesh:
	var key := "%d:%d" % [roundi(_l("tile_w")), roundi(_l("row_h"))]
	if key != _jar_key:
		_jar_key = key
		_jars.clear()
	var k := jam.to_html()
	if not _jars.has(k):
		var b := Face.Builder.new()
		Art.jar(b, Vector2.ZERO, Vector2(_l("tile_w") * 0.9, _l("row_h") * 0.92), jam)
		_jars[k] = b.mesh()
	return _jars[k]

func _draw_jar(w: String, at: Vector2, font: Font, rising := false) -> void:
	var u := _u()
	var e: float = _t - _enter_at - Motion.ENTER_DELAY - (_st.tiles.find(w) if not rising else 0) * Motion.ENTER_STAGGER
	if e < 0.0 and not Motion.reduce:
		return
	var a := 1.0
	at = _drawn_at(w, at)
	if e < Motion.DROP_TIME and not Motion.reduce:
		at.y -= Motion.drop_in_lift(e, Motion.DROP * 1.5 * u)
		a = Motion.appear_level(e)
	var picked: bool = _st.picked.has(w) or _judging.has(w)
	if picked:
		at.y -= 16.0 * u
	var judged := _judging.find(w)
	if judged >= 0:
		at.y += Motion.hop_lift(_t - _judge_at - judged * JUDGE_STEP, -JUDGE_HOP * u, Motion.HOP_TIME)
	var tap := _t - float(_tap_at.get(w, -INF))
	var grow := 1.0
	if tap >= 0.0 and tap < Motion.BUMP_TIME and not Motion.reduce:
		grow = Motion.bump_scale(tap, 0.08)
	if _shiver.has(w) and not Motion.reduce:
		at.x += Motion.shiver_offset(_t - _shiver_at, Motion.SHIVER_PX * 3.0 * u, Motion.SHIVER_TIME * 1.6)
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, at)
	if picked:
		draw_mesh(_halo_mesh(), null, xf, Color(1, 1, 1, a))
	var jam := JAM if picked else Color.TRANSPARENT
	if rising:
		jam = Art.SHELF[_st.group_of(w) % Art.SHELF.size()]
	draw_mesh(_jar_mesh(jam), null, xf, Color(1, 1, 1, a))
	var ink: Color = Art.LABEL if picked and not rising else Pal.TEXT
	_word(font, w, at + Vector2(0.0, _l("row_h") * 0.1), _l("tile_w") * 0.74, Color(ink, a), grow)

var _halo: ArrayMesh
var _halo_key := ""

func _halo_mesh() -> ArrayMesh:
	var key := _jar_key
	if key != _halo_key:
		_halo_key = key
		var b := Face.Builder.new()
		Art.halo(b, Vector2.ZERO, Vector2(_l("tile_w") * 0.9, _l("row_h") * 0.92))
		_halo = b.mesh()
	return _halo

## A word centred at `at`, as large as fits `width`.
func _word(font: Font, w: String, at: Vector2, width: float, ink: Color, grow := 1.0) -> void:
	var u := _u()
	var fs := roundi(WORD_MAX * u * grow)
	var tw := font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > width:
		fs = maxi(roundi(WORD_MIN * u), int(fs * width / tw))
		tw = font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

func _plank_mesh(g: int) -> ArrayMesh:
	var key := "%d:%d:%d" % [g, roundi(_l("grid_w")), roundi(_l("row_h"))]
	if not _planks.has(key):
		var b := Face.Builder.new()
		if g < 0:
			Art.plank(b, Vector2.ZERO, _l("grid_w") + 40.0 * _u(), 16.0 * _u())
		else:
			Art.shelf(b, Vector2.ZERO, Vector2(_l("grid_w"), _l("row_h") * 0.92), g)
		_planks[key] = b.mesh()
	return _planks[key]

## A shelf up: its colour's board with its name and its four words.
func _draw_shelf(r: int) -> void:
	var g: int = _st.shelved[r]
	var u := _u()
	var c := _row_centre(r)
	var e := _t - float(_up_at.get(g, -INF)) - SLIDE_TIME * 0.7
	var k := 1.0
	if e < 0.0 and not Motion.reduce:
		return
	if e < Motion.POP_IN and not Motion.reduce:
		k = Motion.pop_in_scale(e).x
	if _won_at > -INF and _t > _won_at and not Motion.reduce:
		var wave := _t - _won_at - r * 0.08
		if wave >= 0.0:
			c.y += Motion.hop_lift(fmod(wave, 1.6), Motion.SOLVE_HOP * 1.5 * u, Motion.SOLVE_TIME)
	draw_mesh(_plank_mesh(g), null, Transform2D(0.0, Vector2(1.0, k), 0.0, c))
	var font: Font = CozyTheme.display(800)
	var ink: Color = Art.SHELF_INK
	var label: String = _st.groups[g].label
	var ls := roundi(LABEL_SIZE * u)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
	if lw > _l("grid_w") * 0.9:
		ls = int(ls * _l("grid_w") * 0.9 / lw)
		lw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
	if k < 0.99:
		return
	draw_string(font, c + Vector2(-lw * 0.5, -_l("row_h") * 0.08), label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, ink)
	var words := ", ".join(_st.groups[g].words)
	var body: Font = CozyTheme.display(700)
	var ws := roundi(SHELF_WORDS * u)
	var ww := body.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, ws).x
	if ww > _l("grid_w") * 0.92:
		ws = int(ws * _l("grid_w") * 0.92 / ww)
		ww = body.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, ws).x
	draw_string(body, c + Vector2(-ww * 0.5, _l("row_h") * 0.26), words, HORIZONTAL_ALIGNMENT_LEFT, -1, ws, Color(ink, 0.85))

func _draw_hearts() -> void:
	var u := _u()
	var n: int = maxi(State.HEARTS, _st.hearts)
	var gap := HEART_R * 2.6 * u
	for i in n:
		var at := Vector2(size.x * 0.5 + (i - (n - 1) * 0.5) * gap, _l("hearts_y"))
		var full: bool = i < _st.hearts
		var e := _t - _heart_at
		var s := 1.0
		if i == _st.hearts and e >= 0.0 and e < Motion.POP_IN * 2.0 and not Motion.reduce:
			s = 1.0 + 0.4 * (1.0 - e / (Motion.POP_IN * 2.0))
		Art.draw_heart(self, at, HEART_R * u * s, full)

func _draw_say() -> void:
	if _say == "":
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var fs := roundi(SAY_SIZE * u)
	var tw := font.get_string_size(_say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var a := clampf((SAY_TIME - (_t - _say_at)) / 0.4, 0.0, 1.0) if not out_of_hearts else 1.0
	var at := Vector2(size.x * 0.5 - tw * 0.5, _l("say_y") + fs * 0.35)
	draw_string_outline(font, at, _say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(8 * u), Color(Pal.SURFACE, 0.85 * a))
	draw_string(font, at, _say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.TEXT, a))

func _draw_keys() -> void:
	var ready: bool = _st.picked.size() == 4
	var key := "%d:%d:%s" % [roundi(_l("keys_y")), roundi(size.x), ready]
	if key != _keys_key:
		_keys_key = key
		var b := Face.Builder.new()
		for k in 3:
			# left to right: Clear, Shuffle, Shelve (the Key enum's order)
			Keys.key(b, _key_pos(k), _l("key_r"), k, k == Key.ENTER and ready)
		_keys_mesh = b.mesh()
	draw_mesh(_keys_mesh, null)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func skill_quality() -> float:
	if _st.groups.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🫙\n" + _st.share_glyphs()

func flat_win() -> Dictionary:
	var line: String
	if _st.mistakes == 0:
		line = tr("FS_WIN_CLEAN")
	else:
		line = (tr("FS_WIN_MISTAKES_ONE") if _st.mistakes == 1 else tr("FS_WIN_MISTAKES_N")) % _st.mistakes
	return {"faces": [], "subtitle": tr("FS_WIN") + " " + line}

func completion_record() -> Dictionary:
	return {"guesses": _st.guesses.duplicate(true), "shown": Array(_st.shown), "id": _st.id}

## A finished day reopens with every shelf up, from the day this phone holds
## (or the bank's), as it was filled.
func restore_completed_board() -> void:
	_gen += 1
	var key := daily_key if daily_key != 0 else _seed_key
	if not _st.setup_day(Backend.cached_day(State.GAME, key) if daily_key != 0 else {}, key, _band):
		_st.setup(key, _band)
	_st.finish(completed_record.get("guesses", []) as Array, completed_record.get("shown", []) as Array)
	_dealt = true
	_queue.clear()
	_enter_at = -10.0
	for g in _st.count():
		_up_at[g] = -10.0
	_won_at = _t
	_relayout()
	queue_redraw()
