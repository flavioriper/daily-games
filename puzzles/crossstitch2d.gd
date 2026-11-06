extends "res://core/puzzle_base.gd"

## Cross Stitch (spec docs/superpowers/specs/2026-11-04-cross-stitch-design.md):
## a words board. A sampler in a wooden frame on a sewing table: six
## five-letter words, three across and three down, crossing on a 5 by 5
## linen with four holes, their letters sewn on in the wrong places. Drag a
## letter onto another (or tap one, then the other) to swap them. A letter
## in its place is stitched, green, and stays put; one in the right word
## but the wrong place is on the right thread, amber; a stray is plain
## linen. Stitch every letter within the swaps the band allows. The rules
## are puzzles/crossstitch_state.gd's.
##
## **The table is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/crossstitch_world.gd) is the board's first child. From
## the top of the span down: the framed sampler, the line the board says
## things on, the words stitched. The stars and the swaps left stand on a
## paper pill in the tools row's gap.
##
## A patch picked lifts; dragged, it rides the finger. A swap trades two
## patches along two arcs, one over and one under, and their colours turn
## as they land: a patch stitched rings and sparkles, a word stitched whole
## has a gold running stitch sewn round it by a needle. A stitched patch
## pressed shivers and says why. The bulb in two presses: the first rings
## two letters that belong in each other's place and threads them, the
## second swaps them, free. Out of swaps the patches sag and a card asks:
## three more swaps (a video) or show the sampler.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/crossstitch_tutorial_diagram.gd plays it with `demo_swap`.

const State = preload("res://puzzles/crossstitch_state.gd")
const World = preload("res://puzzles/crossstitch_world.gd")
const Art = preload("res://ui/faces/crossstitch_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")
const StarLine = preload("res://ui/flat/star_line.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const FLAT_HOST := "res://ui/flat/flat_host.gd"
const OUT_OF_ROWS := "res://ui/hud/out_of_rows.gd"

const Mark = State.Mark
const ThemedPictures = preload("res://core/themed_pictures.gd")

const HAPTICS := {
	"pick": Haptics.TICK,
	"drop": Haptics.TICK,
	"swap": Haptics.TAP,
	"stitch": Haptics.GOOD,
	"word": Haptics.BUMP,
	"refuse": Haptics.WARN,
	"tight": Haptics.WARN,
	"fall": Haptics.TICK,
	"out": Haptics.LOSE,
	"more": Haptics.GOOD,
	"reveal": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
	"theme": Haptics.GOOD,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## A patch's side, the gap between patches, the linen round them.
const TILE := 150.0
const TILE_GAP := 14.0
const MARGIN := 30.0
## The frame's bar, as a share of a patch (crossstitch_world.gd draws it).
const FRAME_K := 0.24
const GAP := 34.0
const SAY_H := 84.0
const COUNT_H := 64.0

const LETTER_SIZE := 92
const SAY_SIZE := 38
const COUNT_SIZE := 30
const PILL_FONT := 28
const PILL_R := 21.0
const PILL_PAD := Vector2(18.0, 8.0)
const PILL_RIM := 2.0

## A finger moves this far (design px) before a press is a drag.
const DRAG_START := 18.0
## The swap's flight, its arc's height as a share of the distance, a
## picked patch's lift, the stitch ring.
const SWAP_TIME := 0.3
const ARC := 0.22
const LIFT_K := 1.1
## A word's border sewn round it, its stitch, a refusal's shiver.
const SEW_TIME := 0.75
const SEW_W := 5.0
const SHIVER_TIME := 0.35
const SAY_TIME := 2.2
## The sag when the swaps run out, the card after it.
const DROOP_TIME := 0.5
const CARD_AFTER := 1.1
## The win's wave across the patches and how long the board holds it.
const WAVE_STEP := 0.045
const WIN_HOLD := 1.6
## The daily theme (2026-11-06): the theme word's line wears a sun at its
## start (a knot until it is stitched) and its border is sewn in gold and
## rose. On the win, when the word was stitched before the last swap, its
## five patches hop again one by one THEME_AT after the wave starts, the
## sun sparkling; the card waits THEME_HOLD longer on a themed day.
const THEME_AT := 0.9
const THEME_STEP := 0.07
const THEME_HOLD := 0.7
## The sun's linen as a share of a patch's side.
const SUN_K := 0.34

## The day's theme words a harness hands the deal in place of the night's
## (tests/_shot_crossstitch.gd `theme`); empty in the game.
static var theme_pool_override: Array = []

var demo := false
var demo_day := {}
## Out of swaps unsolved: the host reads it (puzzle_host.gd).
var out_of_hearts := false
## Show the sampler was pressed: the letters are home, but it is no solve
## (Four Shelves' rule: a revealed day is not a solve).
var _shown := false

var _st = State.new()
var _band := 0
var _t := 0.0
var _enter_at := 0.0
var _won_at := -INF
var _droop_at := -INF
## The themed win's hop along the theme word (INF: none).
var _theme_at := INF

## What each cell shows until its new mark lands, and when it lands.
var _old_marks: Array[int] = []
var _land_at: Array[float] = []
var _bump_at: Array[float] = []
var _shiver_at: Array[float] = []
## The swap in the air: {"at", "moves": {cell: from Vector2}}.
var _swap := {}
## Words being sewn: [{"slot", "at"}].
var _sewing: Array = []
## The finger: the patch held, where it went down, where it is, a drag.
var _pressing := -2
var _held := -1
var _press_pos := Vector2.ZERO
var _finger := Vector2.ZERO
var _drag := false
## A patch picked by a tap, waiting for the second.
var _picked := -1
var _picked_at := -INF
## A patch flying back to its cell from where a drag let it go.
var _back := {}
## The bulb's first press: the two patches it rings.
var _reading := Vector2i(-1, -1)
var _reading_at := -INF
var _say := ""
var _say_arg := ""
var _say_at := -INF
var _warned := false
var _bought := false
var _card: Control
var _stars := StarLine.new()
## Things to do later on the board's own clock: [{"at", "fn"}].
var _due: Array = []
var _rng := RandomNumberGenerator.new()

var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _from := {}
var _lay_at := -INF
var _world: Control
var _pill: Control
var _units := {}
var _units_s := -1.0
var _borders: ArrayMesh
var _borders_key := ""
var _over: ArrayMesh
var fx: Node

func puzzle_id() -> String: return "crossstitch"
func title() -> String: return "Cross Stitch"

func rules() -> String:
	var out := tr("CS_RULES")
	out += "\n\n" + (tr("CS_RULES_LOOSE") if _st.loose() else tr("CS_RULES_COLOURS"))
	out += "\n\n" + tr("CS_RULES_SWAPS") % [_st.fewest, _st.budget()]
	out += "\n\n" + tr("CS_RULES_HINT")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/crossstitch_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.SWAP, "HTP_CS_SWAP", tr("HTP_CS_SWAP_BODY")],
	]
	if _st.loose():
		steps.append([Diagram.Lesson.LOOSE, "HTP_CS_LOOSE", tr("HTP_CS_LOOSE_BODY")])
	else:
		steps.append([Diagram.Lesson.THREAD, "HTP_CS_THREAD", tr("HTP_CS_THREAD_BODY")])
	steps.append([Diagram.Lesson.WORD, "HTP_CS_WORD", tr("HTP_CS_WORD_BODY") % [_st.fewest, _st.budget()]])
	steps.append([Diagram.Lesson.HINT, "HTP_CS_HINT", tr("HTP_CS_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The bulb only. A swap is sewn in: there is no Undo, and the bin stays
## shut (a swap made is spent, as a committed row is on Hidden Word).
func capabilities() -> Array[String]:
	return ["hint"]

func can_reset() -> bool:
	return false

func hints_left() -> int:
	return _hints_held() + (1 if _reading.x >= 0 else 0)

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
		_st.deal(rng, _band, bank_step, _theme_pool(), daily_key)
	_shown = false
	_bought = false
	_fresh()
	_enter_at = _t
	_cue("enter")

## The day's theme words for the deal: only a daily dealt from its day,
## never New, never the tutorial's sampler.
func _theme_pool() -> Array:
	if demo or bank_step != 0 or daily_key == 0:
		return []
	if not theme_pool_override.is_empty():
		return theme_pool_override
	return ThemedPictures.theme_pool(daily_key)

func themed() -> bool:
	return _st.theme_slot >= 0

## Every patch as dealt, nothing moving.
func _fresh() -> void:
	_old_marks = _st.marks.duplicate()
	_land_at.clear()
	_bump_at.clear()
	_shiver_at.clear()
	for i in 25:
		_land_at.append(-INF)
		_bump_at.append(-INF)
		_shiver_at.append(-INF)
	_swap = {}
	_sewing.clear()
	_held = -1
	_picked = -1
	_drag = false
	_back = {}
	_reading = Vector2i(-1, -1)
	_say = ""
	_warned = false
	_borders_key = ""
	_droop_at = -INF
	_theme_at = INF
	out_of_hearts = false
	_stars.clear(_st.stars())
	_relayout()

func day_dict() -> Dictionary:
	if _st.words.is_empty():
		return {}
	var out := {
		"source": "theme" if themed() else "bank", "kind": "text",
		"payload": {"start": _st.start},
		"solution": {"words": Array(_st.shown)},
		"metrics": {"fewest": _st.fewest, "budget": _st.budget(), "loose": _st.loose()},
	}
	if themed():
		out["theme"] = _st.theme_word
	return out

# --- the moves ---

## The letter on cell `i` ("" a hole).
func letter_at(i: int) -> String:
	return _st.cells[i] if i >= 0 and i < _st.cells.size() else ""

func _press(p: Vector2) -> void:
	if is_done() or _won or out_of_hearts:
		return
	_settle()
	var i := tile_at(p)
	if i < 0:
		if _picked >= 0:
			_picked = -1
			_cue("drop")
		return
	if _st.stitched(i):
		_refuse(i, "CS_SAY_STITCHED")
		return
	_held = i
	_press_pos = p
	_finger = p
	_drag = false
	if _picked < 0:
		_picked_at = _t
		_cue("pick", 1.0 + _rng.randf_range(-0.04, 0.04))

func _move(p: Vector2) -> void:
	if _held < 0:
		return
	_finger = p
	if not _drag and p.distance_to(_press_pos) > DRAG_START * _s():
		_drag = true
		if _picked >= 0 and _picked != _held:
			_picked = -1

func _release(p: Vector2) -> void:
	if _held < 0:
		return
	var i := _held
	_held = -1
	if _drag:
		_drag = false
		var target := tile_at(p)
		if target >= 0 and target != i and not _st.stitched(target):
			_picked = -1
			_try_swap(i, target, p)
			return
		# let go over nothing: it flies home
		_back = {"i": i, "from": p, "at": _t}
		_picked = -1
		_cue("drop")
		if target >= 0 and _st.stitched(target):
			_say_now("CS_SAY_STITCHED")
			_shiver_at[target] = _t
		return
	if _picked < 0:
		_picked = i
	elif _picked == i:
		_picked = -1
		_cue("drop")
	else:
		var a := _picked
		_picked = -1
		_try_swap(a, i)

func _refuse(i: int, key: String) -> void:
	_shiver_at[i] = _t
	_say_now(key)
	_cue("refuse")

## Swaps the patch `a` (dragged and let go at `finger`, or picked) with `b`.
func _try_swap(a: int, b: int, finger := Vector2.INF) -> void:
	if not _st.can_swap(a, b):
		_refuse(b, "CS_SAY_STITCHED" if _st.stitched(b) else "CS_SAY_NONE")
		return
	_do_swap(a, b, finger, false)

func _do_swap(a: int, b: int, finger: Vector2, free: bool) -> void:
	var before: Array[int] = _st.marks.duplicate()
	var theme_before: bool = _st.theme_done()
	var shown := _shown_marks()
	var r: Dictionary = _st.swap(a, b, free)
	if r.is_empty():
		return
	if not free and not demo:
		moves += 1
		moved.emit()
	_reading = Vector2i(-1, -1)
	var land := _t + (SWAP_TIME if not Motion.reduce else 0.0)
	# the letter that was on `a` now stands on `b`, and the other way round
	_swap = {"at": _t, "moves": {
		b: finger if finger != Vector2.INF else _cell_pos(a),
		a: _cell_pos(b),
	}}
	_old_marks = shown
	_old_marks[a] = shown[b]
	_old_marks[b] = shown[a]
	for i in 25:
		if before[i] != _st.marks[i] or i == a or i == b:
			_land_at[i] = land
			if before[i] != _st.marks[i] and i != a and i != b:
				_bump_at[i] = land
	_bump_at[a] = land
	_bump_at[b] = land
	_cue("swap", 1.0 + _rng.randf_range(-0.04, 0.04))
	var stitched: Array = r.get("stitched", [])
	var words: Array = r.get("words", [])
	_later(land, func() -> void:
		if not stitched.is_empty():
			_cue("stitch", 1.0 + 0.06 * stitched.size() + 0.02 * mini(_st.used, 10))
			if fx != null:
				for c in stitched:
					fx.ring(_cell_pos(c), _l("tile") * 0.62, Pal.GOOD)
		for k in words.size():
			var s: int = words[k]
			_sewing.append({"slot": s, "at": _t + k * 0.2})
		if not words.is_empty():
			_cue("word", 1.0 + 0.04 * _done_count())
			if fx != null:
				fx.sparkle(_word_mid(int(words[0])), Art.GOLD)
			if words.has(_st.theme_slot):
				_theme_sewn(_t + words.find(_st.theme_slot) * 0.2)
			elif not _st.solved():
				_say_now("CS_SAY_WORD", _st.shown[int(words[0])].to_upper())
		_rate(true))
	if _st.solved():
		_phase_solved(land, theme_before)
	elif _st.out():
		_run_out(land)
	elif not _st.reachable() and not _warned and not demo:
		_warned = true
		_later(land + 0.3, func() -> void:
			_say_now("CS_SAY_TIGHT")
			_cue("tight"))
	_refresh_pill()

## Whatever is in the air lands at once (a quick finger never waits).
func _settle() -> void:
	if not _swap.is_empty():
		_swap.at = _t - SWAP_TIME
	_back = {}

## `theme_before`: the theme word was stitched before this last swap (its
## sun already out), so the win hops along it again; stitched by this swap,
## its sun coming out is the win's themed beat and the toast names it.
func _phase_solved(land: float, theme_before := false) -> void:
	check_solved()
	if not is_done():
		return
	_won_at = land + 0.25
	_later(land + 0.15, func() -> void:
		_cue("solved")
		if fx != null:
			fx.confetti(Vector2(size.x * 0.5, _l("grid_y")), 28, size.x * 0.7)
		var perfect: bool = _st.used <= _st.fewest and hints_used == 0
		_cue("party" if perfect else "confetti")
		if not (themed() and not theme_before):
			_say_now("CS_PERFECT" if _st.used <= _st.fewest else "CS_DONE"))
	if themed() and theme_before:
		_theme_at = _won_at + (THEME_AT if not Motion.reduce else 0.0)
		_later(_theme_at, func() -> void:
			_cue("theme", 1.06)
			if fx != null:
				fx.sparkle(_sun_pos(), Pal.SUN)
			_say_now("CS_SAY_THEME", _st.theme_word.to_upper()))

## The theme word has just been stitched whole, its border starting to sew
## at `sew_at`: the toast names it, and as the needle ties off the sun comes
## out on its linen with the `theme` cue and a sparkle.
func _theme_sewn(sew_at: float) -> void:
	_say_now("CS_SAY_THEME", _st.theme_word.to_upper())
	var at := sew_at + (SEW_TIME if not Motion.reduce else 0.0)
	_later(at, func() -> void:
		_cue("theme")
		if fx != null:
			fx.sparkle(_sun_pos(), Pal.SUN)
			fx.ring(_sun_pos(), _l("tile") * SUN_K * 1.3, Pal.SUN))

func is_solved() -> bool:
	return _st.solved() and not _shown

## The bulb in two presses. The first, one hint, rings two letters the
## sampler wants in each other's place (or one and the place it wants) and
## threads them; the second swaps them, free.
func hint() -> bool:
	if is_done() or out_of_hearts:
		return false
	_settle()
	if _reading.x < 0:
		if _hints_held() <= 0:
			return false
		var h: Vector2i = _st.hint_swap()
		if h.x < 0:
			return false
		hints_used += 1
		_picked = -1
		_reading = h
		_reading_at = _t
		_say_now("CS_READ")
		_cue("hint")
		if fx != null:
			fx.ring(_cell_pos(h.x), _l("tile") * 0.62, Art.GOLD)
			fx.ring(_cell_pos(h.y), _l("tile") * 0.62, Art.GOLD)
		moved.emit()
		_refresh_pill()
		return true
	var pair := _reading
	_reading = Vector2i(-1, -1)
	_do_swap(pair.x, pair.y, Vector2.INF, true)
	_cue("hint", 1.12)
	moved.emit()
	return true

func reset_board() -> void:
	pass

# --- out of swaps ---

## The last swap is spent and letters still stray: the patches sag, and a
## card asks -- three more swaps, or show the sampler. Until it is answered
## the board takes no touches; the host's Back ends it unsolved.
func _run_out(land: float) -> void:
	out_of_hearts = true
	_droop_at = land + 0.1
	_later(land + 0.3, func() -> void:
		_cue("out")
		_say_now("CS_SAY_OUT"))
	_later(land + (CARD_AFTER if not Motion.reduce else 0.2), _open_card)

func _open_card() -> void:
	if demo or not out_of_hearts or is_done() or is_instance_valid(_card) or not is_inside_tree():
		return
	var card: Control = load(OUT_OF_ROWS).new(_bought, {
		"title": "CS_OUT_TITLE", "body": "CS_OUT_BODY", "body_rest": "CS_OUT_BODY_REST",
		"more": "CS_MORE", "show": "CS_SHOW", "placement": "row"})
	_card = card
	card.one_more_row.connect(more_swaps)
	card.show_code.connect(show_sampler)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

func _close_card() -> void:
	if is_instance_valid(_card) and not _card.is_queued_for_deletion():
		_card.queue_free()
	_card = null

## Three more swaps (the card's video), once a day: the patches perk up.
func more_swaps() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_st.bought += State.MORE
	_bought = true
	out_of_hearts = false
	_droop_at = -INF
	_warned = false
	_cue("more")
	_say_now("CS_SAY_MORE", str(State.MORE))
	for i in 25:
		if State.is_letter(i):
			_bump_at[i] = _t + Motion.stagger(i, 0.02)
	_refresh_pill()

## Show the sampler: every letter flies home and the day ends unsolved.
func show_sampler() -> void:
	if is_done():
		return
	_close_card()
	var was: Array[String] = _st.cells.duplicate()
	var homes := {}
	var taken := {}
	for i in 25:
		if not State.is_letter(i) or was[i] == _st.goal[i]:
			continue
		for j in 25:
			if State.is_letter(j) and not taken.has(j) and was[j] == _st.goal[i] and was[j] != _st.goal[j]:
				taken[j] = true
				homes[i] = _cell_pos(j)
				break
	_shown = true
	_st.finish()
	_old_marks = _st.marks.duplicate()
	_droop_at = -INF
	_swap = {"at": _t, "moves": homes, "long": true}
	for i in homes:
		_bump_at[i] = _t + SWAP_TIME * 1.6
	for s in 6:
		_sewing.append({"slot": s, "at": _t + SWAP_TIME * 1.6 + s * 0.12})
	_cue("reveal")
	# still out of swaps until it ends: the host's Back ends it unsolved
	_later(_t + SWAP_TIME * 1.6 + 0.9, func() -> void:
		finish_unsolved())

# --- helpers ---

func _say_now(key: String, arg := "") -> void:
	_say = key
	_say_arg = arg
	_say_at = _t

func _later(at: float, fn: Callable) -> void:
	_due.append({"at": at, "fn": fn})

func _cue(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch, volume_db)

## The stars read once a swap (`heard`: a star lost falls with a low note).
func _rate(heard: bool) -> void:
	if demo:
		return
	if _stars.rate(_st.stars(), _t, heard and not is_done()) < 0:
		_cue("fall", 0.9)
	_refresh_pill()

func _refresh_pill() -> void:
	if _pill != null:
		_pill.queue_redraw()

func _done_count() -> int:
	var n := 0
	for d in _st.done_words:
		if d:
			n += 1
	return n

## The marks the cells show now: a cell whose new mark has not landed
## shows its old one.
func _shown_marks() -> Array[int]:
	var out: Array[int] = []
	for i in 25:
		out.append(_mark_shown(i))
	return out

func _mark_shown(i: int) -> int:
	if i < _land_at.size() and _t < _land_at[i] and i < _old_marks.size():
		return _old_marks[i]
	return _st.marks[i] if i < _st.marks.size() else Mark.STRAY

func busy() -> bool:
	return not _swap.is_empty() or not _back.is_empty() or not _sewing.is_empty()

# --- the tutorial's hands ---

## The tutorial's finger holding patch `i` at `at` (it rides the finger),
## then letting it go on patch `b`.
func demo_drag(i: int, at: Vector2) -> void:
	_held = i
	_drag = true
	_finger = at

func demo_swap(a: int, b: int) -> void:
	var f := _finger if _held == a and _drag else Vector2.INF
	_held = -1
	_drag = false
	_picked = -1
	_do_swap(a, b, f, false)

func demo_pick(i: int) -> void:
	_picked = i
	_picked_at = _t

func demo_hint() -> void:
	hints_extra += 1
	hint()

func state():
	return _st

func tile_to_local(i: int) -> Vector2:
	return _cell_pos(i)

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	if not _swap.is_empty() and _t - float(_swap.at) > SWAP_TIME * (1.6 if _swap.has("long") else 1.0):
		_swap = {}
	if not _back.is_empty() and _t - float(_back.at) > SWAP_TIME:
		_back = {}
	var still: Array = []
	for s: Dictionary in _sewing:
		if _t - float(s.at) < SEW_TIME:
			still.append(s)
	if still.size() != _sewing.size():
		_borders_key = ""
	_sewing = still
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

## The patch a finger at `local` means: the nearest letter cell, within
## half a patch and the gap.
func tile_at(local: Vector2) -> int:
	if _L.is_empty():
		return -1
	var reach := (_l("tile") + _l("gap")) * 0.5
	var best := -1
	var far := INF
	for i in 25:
		if not State.is_letter(i):
			continue
		var d := (local - _cell_pos(i)).abs()
		if d.x <= reach and d.y <= reach:
			var dd := d.length()
			if dd < far:
				far = dd
				best = i
	return best

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
	_borders_key = ""
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		var holes: Array[Vector2] = []
		for h in State.HOLES:
			holes.append(_rest_pos(h, _L))
		var foot := float(_L.count_y) + COUNT_H * float(_L.s)
		_world.set_lines(_L.linen, holes, float(_L.tile), foot)
	_refresh_pill()
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 300.0 * u)
	var grid := TILE * 5.0 + TILE_GAP * 4.0
	var linen := grid + MARGIN * 2.0
	var outer := linen + TILE * FRAME_K * 2.0
	var below := 0.0 if (_won or demo) else GAP + SAY_H + COUNT_H
	if demo:
		below = GAP * 0.5 + SAY_H
	var need := outer + below
	var k := minf(1.0, span / (need * u))
	k = minf(k, (w * 0.96) / (outer * u))
	var s := u * k
	var y := top + maxf(0.0, (span - need * s) * 0.4)
	var lx := w * 0.5 - linen * s * 0.5
	var ly := y + TILE * FRAME_K * s
	var grid_y := ly + linen * s * 0.5
	var say_y := ly + linen * s + TILE * FRAME_K * s + (GAP + SAY_H * 0.5) * s
	return {
		"u": u, "s": s, "top": top, "bottom": bottom,
		"linen": Rect2(lx, ly, linen * s, linen * s),
		"x0": lx + (MARGIN + TILE * 0.5) * s, "y0": ly + (MARGIN + TILE * 0.5) * s,
		"tile": TILE * s, "gap": TILE_GAP * s, "grid_y": grid_y,
		"say_y": say_y if not demo else ly + linen * s + TILE * FRAME_K * s + (GAP * 0.5 + SAY_H * 0.5) * s,
		"count_y": say_y + (SAY_H * 0.5 + COUNT_H * 0.6) * s,
	}

## A layout value, eased from the play's layout into the win's.
func _l(key: String) -> float:
	var v := float(_L.get(key, 0.0))
	if _from.is_empty() or not _from.has(key) or typeof(_from[key]) != TYPE_FLOAT:
		return v
	var e := (_t - _lay_at) / 0.5
	if e >= 1.0:
		return v
	return lerpf(float(_from[key]), v, Motion.back_out(clampf(e, 0.0, 1.0)))

func _s() -> float:
	return float(_L.get("s", 1.0))

func _rest_pos(i: int, L: Dictionary) -> Vector2:
	var step := float(L.tile) + float(L.gap)
	return Vector2(float(L.x0) + (i % 5) * step, float(L.y0) + (i / 5) * step)

## The middle of cell `i` as it rests on the linen.
func _cell_pos(i: int) -> Vector2:
	var step := _l("tile") + _l("gap")
	return Vector2(_l("x0") + (i % 5) * step, _l("y0") + (i / 5) * step)

func _word_mid(s: int) -> Vector2:
	var cs := State.cells_of(s)
	return (_cell_pos(cs[0]) + _cell_pos(cs[4])) * 0.5

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.cells.is_empty():
		return
	var ts := _l("tile")
	if absf(ts - _units_s) > 0.5:
		_units_s = ts
		_units = {}
		for m in 3:
			for lift in [0, 1]:
				var b := Face.Builder.new()
				Art.patch(b, Vector2.ZERO, ts, m, float(lift))
				_units["%d:%d" % [m, lift]] = b.mesh()
		var sb := Face.Builder.new()
		Scenery.soft_disc(sb, Vector2(0.0, ts * 0.16), ts * 0.62, ts * 0.5, Color(0.2, 0.12, 0.05, 0.28))
		_units["shadow"] = sb.mesh()
	var font: Font = CozyTheme.display(800)
	var fs := roundi(LETTER_SIZE * _s())
	var moving := _moving()
	# the patches at rest, then the borders, then whatever is in the air
	for i in 25:
		if not State.is_letter(i) or moving.has(i):
			continue
		_draw_patch(i, _patch_xf(i), font, fs, false)
	_draw_borders()
	_draw_reading()
	for i in moving:
		var xf: Transform2D = moving[i]
		draw_mesh(_units.shadow, null, xf)
		_draw_patch(i, xf, font, fs, true)
	_draw_say()
	_draw_count()

## Where each patch in the air is drawn: {cell: Transform2D}.
func _moving() -> Dictionary:
	var out := {}
	var ts := _l("tile")
	if not _swap.is_empty() and not Motion.reduce:
		var time := SWAP_TIME * (1.6 if _swap.has("long") else 1.0)
		var e := clampf((_t - float(_swap.at)) / time, 0.0, 1.0)
		if e < 1.0:
			var k := e * e * (3.0 - 2.0 * e)
			var side := 1.0
			for c in _swap.moves:
				var from: Vector2 = _swap.moves[c]
				var to := _cell_pos(c)
				var d := to - from
				var n := Vector2(-d.y, d.x).normalized() if d.length() > 1.0 else Vector2.ZERO
				var at := from.lerp(to, k) + n * sin(k * PI) * d.length() * ARC * side
				side = -side
				var sc := 1.0 + (LIFT_K - 1.0) * sin(k * PI)
				out[c] = Transform2D(0.0, Vector2.ONE * sc, 0.0, at)
	if not _back.is_empty() and not Motion.reduce:
		var e := clampf((_t - float(_back.at)) / SWAP_TIME, 0.0, 1.0)
		if e < 1.0:
			var k := 1.0 - (1.0 - e) * (1.0 - e)
			var i := int(_back.i)
			out[i] = Transform2D(0.0, Vector2.ONE * lerpf(LIFT_K, 1.0, k), 0.0, (_back.from as Vector2).lerp(_cell_pos(i), k))
	if _held >= 0 and _drag:
		out[_held] = Transform2D(0.0, Vector2.ONE * LIFT_K, 0.0, _finger + Vector2(0.0, -ts * 0.18))
	elif _held >= 0 or _picked >= 0:
		var i := _held if _held >= 0 else _picked
		var e := _t - _picked_at
		var k := LIFT_K if Motion.reduce else lerpf(1.0, LIFT_K, clampf(e / Motion.LIFT_TIME, 0.0, 1.0))
		var bob := 0.0 if Motion.reduce else sin(_t * 4.0) * ts * 0.02
		out[i] = Transform2D(0.0, Vector2.ONE * k, 0.0, _cell_pos(i) + Vector2(0.0, -ts * 0.08 + bob))
	return out

## Where patch `i` rests and how it sits: popping in, bumped, shivering,
## hopping in the win's wave, sagging when the swaps ran out.
func _patch_xf(i: int) -> Transform2D:
	var at := _cell_pos(i)
	var k := 1.0
	var rot := 0.0
	if not Motion.reduce:
		var d: float = _t - _enter_at - Motion.ENTER_DELAY - (i / 5 + i % 5) * Motion.ENTER_STAGGER * 2.0
		if d < 0.0:
			k = 0.0
		elif d < Motion.POP_IN:
			k = Motion.pop_in_scale(d).x
		var b := _t - _bump_at[i]
		if b >= 0.0 and b < Motion.BUMP_TIME:
			k *= Motion.bump_scale(b, 0.14)
		var sh := _t - _shiver_at[i]
		if sh >= 0.0 and sh < SHIVER_TIME:
			at.x += sin(sh * 48.0) * 8.0 * _s() * (1.0 - sh / SHIVER_TIME)
		if _phase_won():
			var wave := _t - _won_at - (i / 5 + i % 5) * WAVE_STEP
			if wave >= 0.0 and wave < 1.6:
				at.y -= Motion.hop_lift(fmod(wave, 1.6), Motion.SOLVE_HOP * 2.4 * float(_L.u), Motion.SOLVE_TIME)
			if _theme_at < INF and themed():
				var tk := State.cells_of(_st.theme_slot).find(i)
				if tk >= 0:
					var th := _t - _theme_at - tk * THEME_STEP
					if th >= 0.0 and th < Motion.SOLVE_TIME:
						at.y -= Motion.hop_lift(th, Motion.SOLVE_HOP * 3.0 * float(_L.u), Motion.SOLVE_TIME)
		if out_of_hearts and _t >= _droop_at and not _st.stitched(i):
			var dr := clampf((_t - _droop_at - (i % 5) * 0.03) / DROOP_TIME, 0.0, 1.0)
			at.y += dr * 10.0 * _s()
			rot = dr * (0.09 if (i * 7) % 3 == 0 else -0.07)
	return Transform2D(rot, Vector2.ONE * k, 0.0, at)

func _phase_won() -> bool:
	return is_done() and _won_at > -INF and _t >= _won_at

func _draw_patch(i: int, xf: Transform2D, font: Font, fs: int, lifted: bool) -> void:
	if xf.get_scale().x <= 0.01:
		return
	var m := _mark_shown(i)
	draw_mesh(_units["%d:%d" % [m, 1 if lifted else 0]], null, xf)
	var ch := letter_at(i).to_upper()
	if ch == "":
		return
	var tw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := font.get_ascent(fs)
	draw_set_transform_matrix(xf)
	var up := -_l("tile") * Art.RIM * (1.0 if lifted else 0.0)
	draw_string(font, Vector2(-tw * 0.5, asc * 0.36 + up), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.LETTER[clampi(m, 0, 2)])
	draw_set_transform(Vector2.ZERO)

## The gold running stitch round every word stitched whole, sewn by a
## needle as it is made. One mesh while nothing is being sewn.
func _draw_borders() -> void:
	var key := "%s:%d:%d:%d" % [str(_st.done_words), roundi(_l("x0")), roundi(_l("y0") * 7.0 + _l("tile")), _st.theme_slot]
	var sewing := not _sewing.is_empty() and not Motion.reduce
	if key != _borders_key or sewing:
		_borders_key = key
		var b := Face.Builder.new()
		var tips: Array = []
		var w := SEW_W * _s()
		var dash := 22.0 * _s()
		for s in 6:
			if not _st.done_words[s]:
				continue
			var upto := 1.0
			for sw: Dictionary in _sewing:
				if int(sw.slot) == s:
					upto = clampf((_t - float(sw.at)) / SEW_TIME, 0.0, 1.0)
			if upto <= 0.0:
				continue
			var tip: Vector2 = Art.border(b, _ring_of(s), w, upto, dash)
			if s == _st.theme_slot:
				# the theme word's second thread, rose in the gold's gaps
				Art.border(b, _ring_of(s), w * 0.8, upto, dash, Art.ROSE, 0.62, 0.32)
			if upto < 1.0:
				tips.append(tip)
		if themed():
			Art.sun(b, _sun_pos(), _l("tile") * SUN_K, _sun_bloom())
		for tip in tips:
			Art.needle(b, tip, Vector2(1.0, -0.6), _l("tile") * 0.55)
		_borders = b.mesh() if b.verts.size() > 0 else null
	if _borders != null:
		draw_mesh(_borders, null)

## Where the theme word's sun is pinned: on the frame before the word's
## first letter (left of an across word, above a down one).
func _sun_pos() -> Vector2:
	if not themed():
		return Vector2.ZERO
	var s: int = _st.theme_slot
	var k := _l("tile") / TILE
	var back := TILE * 0.5 + MARGIN + TILE * FRAME_K * 0.35
	var dir := Vector2.LEFT if s < 3 else Vector2.UP
	return _cell_pos(State.cells_of(s)[0]) + dir * back * k

## How far the sun is out: 0 the knot while the word is open, rising to 1
## over the end of its border's sewing.
func _sun_bloom() -> float:
	if not _st.theme_done():
		return 0.0
	if Motion.reduce:
		return 1.0
	for sw: Dictionary in _sewing:
		if int(sw.slot) == _st.theme_slot:
			var upto := clampf((_t - float(sw.at)) / SEW_TIME, 0.0, 1.0)
			return clampf((upto - 0.55) / 0.45, 0.0, 1.0) if upto < 1.0 else 1.0
	return 1.0

## The ring a word's border runs along: round its five patches, in the
## gap.
func _ring_of(s: int) -> PackedVector2Array:
	var cs := State.cells_of(s)
	var a := _cell_pos(cs[0])
	var z := _cell_pos(cs[4])
	var h := _l("tile") * 0.5 + _l("gap") * 0.5
	var lo := Vector2(minf(a.x, z.x), minf(a.y, z.y)) - Vector2.ONE * h
	var hi := Vector2(maxf(a.x, z.x), maxf(a.y, z.y)) + Vector2.ONE * h
	return PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])

## The bulb's first press: a gold ring round each of the two patches and a
## thread between them.
func _draw_reading() -> void:
	if _reading.x < 0:
		return
	var b := Face.Builder.new()
	var a := _cell_pos(_reading.x)
	var z := _cell_pos(_reading.y)
	var pulse := 0.6 + 0.4 * sin((_t - _reading_at) * 5.0) if not Motion.reduce else 1.0
	var h := _l("tile") * 0.56
	for c in [a, z]:
		b.stroke(Face.Builder.round_rect(c - Vector2.ONE * h, Vector2.ONE * h * 2.0, h * 0.35), 6.0 * _s(), Color(Art.GOLD, 0.9 * pulse), true)
	var d := z - a
	var n := Vector2(-d.y, d.x).normalized() * d.length() * 0.18
	var pts := PackedVector2Array()
	for k in 25:
		var f := k / 24.0
		pts.append(a.lerp(z, f) + n * sin(f * PI))
	for k in range(0, 24, 2):
		b.stroke(PackedVector2Array([pts[k], pts[k + 1]]), 4.0 * _s(), Color(Art.GOLD, 0.85))
	_over = b.mesh()
	draw_mesh(_over, null)

## What the board says, under the sampler: praise, a word stitched, why a
## touch was refused.
func _draw_say() -> void:
	if _say == "" or _t < _say_at:
		return
	var font: Font = CozyTheme.display(800)
	var text := tr(_say)
	if _say_arg != "" and text.contains("%s"):
		text = text % _say_arg
	var good := _say in ["CS_SAY_WORD", "CS_SAY_THEME", "CS_PERFECT", "CS_DONE", "CS_SAY_MORE", "CS_READ"]
	var fs := roundi(SAY_SIZE * (1.25 if good else 1.0) * _s())
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > size.x * 0.94:
		fs = roundi(fs * size.x * 0.94 / tw)
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var e := _t - _say_at
	var pk := Motion.pop_in_scale(e, 0.25).x if e < 0.25 and not Motion.reduce else 1.0
	var fade := clampf((SAY_TIME - e) / 0.4, 0.0, 1.0)
	var ink := Art.FRAME_DEEP.darkened(0.35) if good else Pal.TEXT
	var asc := font.get_ascent(fs)
	var y := _l("say_y")
	draw_set_transform(Vector2(size.x * 0.5, y), 0.0, Vector2.ONE * pk)
	draw_string_outline(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(12 * _s()), Color(Pal.SURFACE, 0.92 * fade))
	draw_string(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, fade))
	draw_set_transform(Vector2.ZERO)

## Under the say line: the words stitched, and on Insane the rule.
func _draw_count() -> void:
	if demo or _won or is_done():
		return
	var font: Font = CozyTheme.display(700)
	var n := _done_count()
	var text: String = tr("CS_WORDS_N") % [n, 6]
	if _st.loose():
		text += "  ·  " + tr("CS_LOOSE")
	var cs := roundi(COUNT_SIZE * float(_L.u))
	var cw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	if cw > size.x * 0.94:
		cs = roundi(cs * size.x * 0.94 / cw)
		cw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	var at := Vector2(size.x * 0.5 - cw * 0.5, _l("count_y"))
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, roundi(10 * float(_L.u)), Color(Pal.SURFACE, 0.92))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Pal.TEXT)

## The count pill in the tools row's gap: the stars the way stands at,
## then the swaps left (red when two or fewer).
func _draw_pill() -> void:
	if not _bled or _won or _st.cells.is_empty():
		return
	var enter := 1.0 if Motion.reduce else Motion.pop_in_scale(_t - _enter_at - Motion.ENTER_DELAY).x
	if enter <= 0.0:
		return
	var font: Font = CozyTheme.body(700)
	var left: int = _st.left()
	var text: String = tr("CS_LEFT_ONE") if left == 1 else tr("CS_LEFT_N") % left
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
	var ink := Pal.BAD if left <= 2 and not _st.solved() else Color(Pal.TEXT, 0.8)
	_pill.draw_string(font, Vector2(x0 + sw + 14.0, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	_pill.draw_set_transform(Vector2.ZERO)

var _pill_mesh: ArrayMesh

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD + (THEME_HOLD if themed() else 0.0)

func skill_quality() -> float:
	if _st.cells.is_empty() or _shown:
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🧵 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	# the bulb's swaps are free for the stars, but the count is every swap
	var all: int = _st.used + _st.helped
	var line: String
	if all <= _st.fewest:
		line = tr("CS_WIN_PERFECT") % all
	else:
		line = tr("CS_WIN") % [all, _st.fewest]
	if themed():
		var word: String = _st.theme_word
		return {"faces": [], "subtitle": tr("CS_WIN_THEME") % [word.left(1).to_upper() + word.substr(1), line]}
	return {"faces": [], "subtitle": line}

func completion_record() -> Dictionary:
	return {"used": _st.used, "helped": _st.helped, "stars": 0 if _shown else _st.stars(), "shown": _shown}

## A finished day reopens stitched, its count kept.
func restore_completed_board() -> void:
	_st.finish()
	_st.used = int(completed_record.get("used", _st.fewest))
	_st.helped = int(completed_record.get("helped", 0))
	_fresh()
	_shown = bool(completed_record.get("shown", false))
	if _shown:
		_stars.clear(0)
	_sewing.clear()
	_enter_at = -10.0
	_won_at = -INF
	queue_redraw()
