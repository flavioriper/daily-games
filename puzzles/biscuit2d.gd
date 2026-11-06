extends "res://core/puzzle_base.gd"

## Biscuit Tin (spec docs/superpowers/specs/2026-11-04-biscuit-tin-design.md):
## a words board. An open biscuit tin on a kitchen table, full of broken
## pieces with two to four letters iced on each. Tap pieces to lay them on
## the plate in order (four at most); whenever the plate spells a word the
## tin knows it is found and scores by the pieces it takes. Four pieces that
## spell one of the tin's long words knit into a whole biscuit, which flies
## to its dimple on the lid. Every biscuit whole is the solve. The rules are
## puzzles/biscuit_state.gd's.
##
## **The table is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/biscuit_world.gd) is the board's first child. From the top
## of the span down: the lid with a dimple per biscuit (its word written
## beside it once whole), the line the board says things on, the plate,
## the tin, the count. The stars and the points stand on a paper pill in
## the tools row's gap.
##
## A piece tapped hops from the tin to the end of the plate; tapped on the
## plate it goes back with every piece after it; the plate tapped where no
## piece is goes back whole. A word found hops the plate's pieces, lights
## them gold and floats its points up. A biscuit's pieces close up, knit
## into a round biscuit and fly to the lid. The bulb in two presses: the
## first rings the first piece of a biscuit and says how long its word is,
## the second lays it whole, free. On Insane four crumbs of a sixth word
## fit nowhere; they are swept off when the last biscuit is whole.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/biscuit_tutorial_diagram.gd plays it with `demo_tap`.

const State = preload("res://puzzles/biscuit_state.gd")
const World = preload("res://puzzles/biscuit_world.gd")
const Art = preload("res://ui/faces/biscuit_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")
const StarLine = preload("res://ui/flat/star_line.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const ThemedPictures = preload("res://core/themed_pictures.gd")
const FLAT_HOST := "res://ui/flat/flat_host.gd"

const HAPTICS := {
	"pick": Haptics.TICK,
	"back": Haptics.TICK,
	"clear": Haptics.TICK,
	"word": Haptics.GOOD,
	"again": Haptics.TICK,
	"full": Haptics.WARN,
	"biscuit": Haptics.BUMP,
	"land": Haptics.TAP,
	"star": Haptics.GOOD,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
	"theme": Haptics.GOOD,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## The lid: a row's height, its padding, its width.
const LID_ROW := 70.0
const LID_PAD := 20.0
const LID_W := 1010.0
const GAP := 22.0
const SAY_H := 64.0
## The plate: its oval's size, and the pieces on it at this share.
const PLATE_W := 1000.0
const PLATE_H := 196.0
const PLATE_GAP := 8.0
## The tin: a place's size, the columns, its wall, the floor's margin.
const CELL := Vector2(240.0, 126.0)
const COLS := 4
const WALL := 30.0
const MARGIN := 14.0
const COUNT_H := 52.0
## A piece in the tin at this share of its size.
const TIN_K := 0.94

const LETTER_K := 0.5
const SAY_SIZE := 38
const LID_FONT := 34
const COUNT_SIZE := 30
const PILL_FONT := 28
const PILL_R := 21.0
const PILL_PAD := Vector2(18.0, 8.0)
const PILL_RIM := 2.0
const FLOAT_SIZE := 46

## A finger moves this far (design px) before a press is not a tap.
const TAP_SLOP := 30.0
## A piece's hop between tin and plate, a word's light, a refusal's shiver.
const FLY := 0.26
const FLY_ARC := 70.0
const LIGHT_TIME := 0.7
const SHIVER_TIME := 0.35
const SAY_TIME := 2.2
const FLOAT_TIME := 0.9
## A biscuit's making: the pieces close up, it knits whole, it flies.
const CLOSE := 0.22
const KNIT := 0.24
const TO_LID := 0.5
## The crumbs swept off on the solve, and the win's hold.
const SWEEP := 0.45
const WIN_HOLD := 1.8

## The daily theme (2026-11-06): on a daily dealt from its day the tin is
## the band's banked tin holding the strongest of the day's theme words
## (ThemedPictures.theme_pool / bank_pick), one of its biscuits by
## preference, else any word it credits. A little paper tag with a sun
## hangs on the lid's lower rim from the start, never the word; when the
## word is made the tag opens to name it (popping in over TAG_POP), the
## theme cue rings THEME_CUE after the word's own, a sparkle, and the say
## line reads "Today's word". A theme biscuit wears a gold ring on the lid.
## A theme word missed by the solve is named on the tag at the win, quietly;
## the win card waits THEME_HOLD longer when the win carries either beat.
const TAG_H := 54.0
const TAG_FONT := 32
const TAG_POP := 0.35
const THEME_CUE := 0.14
const THEME_HOLD := 0.6

var demo := false
var demo_day := {}

var _st = State.new()
var _band := 0
var _t := 0.0
var _enter_at := 0.0
var _won_at := -INF

## Each piece as drawn: where it flies from, when it set off, where it is
## going (position and scale).
var _from: Array[Vector2] = []
var _from_k: Array[float] = []
var _fly_at: Array[float] = []
var _to: Array[Vector2] = []
var _to_k: Array[float] = []
var _hop_at: Array[float] = []
var _light_at: Array[float] = []
var _shiver_at: Array[float] = []
## Pieces gone from the state but still drawn: a biscuit's on their way to
## knitting (piece -> the bake), crumbs being swept (piece -> when).
var _baking := {}
var _sweeping := {}
## The biscuits being made: [{"b", "at", "slot"}]; the lid draws this many
## whole (the rest still on their way).
var _bakes: Array = []
var _lid_shown := 0
var _lid_bump_at := -INF
## Points floating up off the plate: [{"text", "at", "pos"}].
var _floats: Array = []
## The bulb's first press: the biscuit and its first piece.
var _reading := {}
var _reading_at := -INF
var _say := ""
var _say_arg := ""
var _say_n := -1
var _say_at := -INF
var _stars := StarLine.new()
## Things to do later on the board's own clock: [{"at", "fn"}].
var _due: Array = []
var _rng := RandomNumberGenerator.new()
var _pressing := -2
var _press_pos := Vector2.ZERO

var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _world: Control
var _pill: Control
var _scene: ArrayMesh
var _scene_key := ""
var _lid_mesh: ArrayMesh
var _lid_key := ""
var _pieces: Array = []
var _pieces_lit: Array = []
var _ghosts: ArrayMesh
var _ghosts_key := ""
var _reading_mesh: ArrayMesh
var _bake_mesh: ArrayMesh
var _bake_key := ""
var _pill_mesh: ArrayMesh
var _tag_mesh: ArrayMesh
var _tag_key := ""
var fx: Node

## The day's theme word as the bank has it ("" on a plain day), its biscuit
## (-1 when a shorter word), when the tag opened (INF while shut), and
## whether the win carries a theme beat (the theme biscuit made last, or
## the word named at the win).
var _theme := ""
## The bank entry this board was dealt (a reopened day deals it back).
var _dealt: Dictionary = {}
var _theme_b := -1
var _theme_at := INF
var _theme_beat := false
## The harness's seam: a pool used in place of the day's (folded words,
## strongest first). Never set by the game.
static var pool_for_shots: Array = []

func puzzle_id() -> String: return "biscuit"
func title() -> String: return "Biscuit Tin"

func rules() -> String:
	var out: String = tr("BT_RULES") % _st.biscuits.size()
	out += "\n\n" + tr("BT_RULES_WORDS")
	out += "\n\n" + tr("BT_RULES_BISCUIT")
	if not _st.crumbs.is_empty():
		out += "\n\n" + tr("BT_RULES_CRUMBS")
	out += "\n\n" + tr("BT_RULES_LINE") % [_st.line, _st.two_line()]
	out += "\n\n" + tr("BT_RULES_HINT")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/biscuit_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.WORD, "HTP_BT_WORD", tr("HTP_BT_WORD_BODY")],
		[Diagram.Lesson.BISCUIT, "HTP_BT_BISCUIT", tr("HTP_BT_BISCUIT_BODY") % _st.biscuits.size()],
	]
	if not _st.crumbs.is_empty():
		steps.append([Diagram.Lesson.CRUMBS, "HTP_BT_CRUMBS", tr("HTP_BT_CRUMBS_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_BT_HINT", tr("HTP_BT_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The bulb only: a word found stays found and the plate empties with a
## tap, so there is nothing to undo and nothing to start over.
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
	_theme = ""
	_theme_b = -1
	var themed := _themed_tin()
	_dealt = {}
	if demo and not demo_day.is_empty():
		_st.band = _band
		_st.load_day(demo_day)
	elif not themed.is_empty():
		_st.band = _band
		_st.load_day(themed.day)
		_dealt = themed.day
		_theme = String(themed.word)
		_theme_b = _st.biscuit_of(_theme)
	else:
		_st.deal(rng, _band, bank_step)
		_dealt = InsaneBank.pick(State.BANKS[_band], bank_step)
	_fresh()
	_enter_at = _t
	_cue("enter")

## Every piece in the tin as dealt, nothing moving.
func _fresh() -> void:
	var n: int = _st.pieces.size()
	_from.resize(n)
	_from_k.resize(n)
	_fly_at.resize(n)
	_to.resize(n)
	_to_k.resize(n)
	_hop_at.resize(n)
	_light_at.resize(n)
	_shiver_at.resize(n)
	for i in n:
		_fly_at[i] = -INF
		_hop_at[i] = -INF
		_light_at[i] = -INF
		_shiver_at[i] = -INF
	_baking = {}
	_sweeping = {}
	_bakes.clear()
	_lid_shown = _st.whole.size()
	_floats.clear()
	_reading = {}
	_say = ""
	_pieces = []
	_pieces_lit = []
	_ghosts_key = ""
	_lid_key = ""
	_tag_key = ""
	_theme_at = INF
	_theme_beat = false
	_stars.clear(_st.stars())
	_relayout()

func day_dict() -> Dictionary:
	if _st.pieces.is_empty():
		return {}
	return {
		"source": "theme" if themed() else "bank", "kind": "text",
		"theme": _st.written(_theme) if themed() else "",
		"payload": {"pieces": Array(_st.pieces), "biscuits": _st.biscuits.duplicate(true)},
		"solution": {"biscuits": Array(_st.biscuit_words)},
		"metrics": {"line": _st.line, "words": _st.word_list.size(), "pieces": _st.pieces.size(), "crumbs": _st.crumbs.size()},
	}

# --- the moves ---

func _tap(p: Vector2) -> void:
	if is_done() or _won or _L.is_empty():
		return
	# a piece on the plate: it goes back with every piece after it
	for k in range(_st.plate.size() - 1, -1, -1):
		var i: int = _st.plate[k]
		if _piece_rect(i).grow(6.0 * _s()).has_point(p):
			var off: Array[int] = _st.back(i)
			for j in off:
				_hop_at[j] = _t
			_retarget()
			_cue("back", 1.0 + 0.04 * _st.plate.size())
			moved.emit()
			return
	# a piece in the tin
	for i in _st.in_tin():
		if _st.on_plate(i) or _baking.has(i):
			continue
		if _piece_rect(i).grow(4.0 * _s()).has_point(p):
			_take(i)
			return
	# the plate where no piece is: everything back
	if (_L.plate as Rect2).has_point(p) and not _st.plate.is_empty():
		_st.clear_plate()
		_retarget()
		_cue("clear")
		moved.emit()

## Piece `i` from the tin to the end of the plate; the plate is read as it
## lands.
func _take(i: int) -> void:
	if _st.plate.size() >= State.PLATE:
		_shiver_at[i] = _t
		for j in _st.plate:
			_shiver_at[j] = _t
		_say_now("BT_SAY_FULL")
		_cue("full")
		return
	_st.add(i)
	_retarget()
	_cue("pick", 0.94 + 0.06 * _st.plate.size() + _rng.randf_range(-0.02, 0.02))
	if _reading.has("piece") and int(_reading.piece) == i:
		_reading_at = _t
	_read(_t + FLY * 0.8, false)
	moved.emit()

## Reads the plate; what it found lands at `land`.
func _read(land: float, free: bool) -> void:
	var before: int = _st.stars()
	var plate: Array = _st.plate.duplicate()
	var r: Dictionary = _st.read(free)
	if r.is_empty():
		return
	var w: String = r.word
	if bool(r.get("again", false)):
		_later(land, func() -> void:
			for k in plate.size():
				_hop_at[plate[k]] = _t + k * 0.03
			_say_now("BT_SAY_AGAIN", _st.written(w).to_upper())
			_cue("again"))
		return
	if not free and not demo:
		moves += 1
	var b: int = r.biscuit
	if b >= 0:
		_bake(b, plate, land, free)
	else:
		var got: int = r.points
		_later(land, func() -> void:
			for k in plate.size():
				_hop_at[plate[k]] = _t + k * Motion.SOLVE_STAGGER
				_light_at[plate[k]] = _t + k * Motion.SOLVE_STAGGER
			_cue("word", 1.0 + 0.06 * plate.size() + 0.01 * mini(_st.found.size(), 10))
			if fx != null:
				fx.ring(_plate_mid(), _l("cell_h") * 0.9, Art.GOLD)
			_floats.append({"text": "+%d" % got, "at": _t, "pos": _plate_mid()})
			_say_now("BT_SAY_WORD", _st.written(w).to_upper(), got)
			if themed() and w == _theme:
				_theme_found(_plate_mid(), "BT_SAY_THEME", got)
			_rate(before))
	_refresh_pill()

## A biscuit made from the plate's pieces `parts`: they fly on to their
## places on the plate (if still flying), close up, knit and fly to the
## lid, where it lands at `slot`.
func _bake(b: int, parts: Array, land: float, free: bool) -> void:
	var slot: int = _st.whole.size() - 1
	var bake := {"b": b, "at": land, "slot": slot, "parts": parts, "mid": _plate_mid()}
	_bakes.append(bake)
	for i in parts:
		_baking[i] = bake
	_reading = {}
	var before_crumbs := []
	if _st.solved():
		for c in _st.crumbs:
			if not _baking.has(c):
				before_crumbs.append(c)
				# drawn where they lie until the sweep
				_sweeping[c] = INF
	_later(land, func() -> void:
		_cue("biscuit", 1.0 + 0.04 * slot)
		if free:
			_say_now("BT_SAY_BISCUIT_FREE", _st.written(_st.biscuit_words[b]).to_upper())
		else:
			_say_now("BT_SAY_BISCUIT", _st.written(_st.biscuit_words[b]).to_upper(), State.POINTS[State.PLATE])
		if b == _theme_b:
			_theme_found(bake.mid, "BT_SAY_THEME_FREE" if free else "BT_SAY_THEME", -1 if free else State.POINTS[State.PLATE])
		if not free:
			# above the biscuit as it knits, clear of its word
			_floats.append({"text": "+%d" % State.POINTS[State.PLATE], "at": _t + CLOSE, "pos": _plate_mid() - Vector2(0.0, _l("cell_h") * 0.6)}))
	_later(land + CLOSE + KNIT * 0.5, func() -> void:
		for i in parts:
			_baking.erase(i)
		if fx != null:
			fx.ring(bake.mid, _l("cell_h") * 1.1, Art.GOLD)
			fx.puff(bake.mid, Art.BISCUIT_LIT, 6)
		# the rest of the tin closes up behind them
		_retarget())
	var lands := land + CLOSE + KNIT + TO_LID
	_later(lands, func() -> void:
		_bakes.erase(bake)
		_lid_shown = maxi(_lid_shown, slot + 1)
		_lid_key = ""
		_lid_bump_at = _t
		_cue("land", 1.0 + 0.05 * slot)
		if fx != null:
			fx.sparkle(_lid_dot(slot), Art.GOLD)
			if b == _theme_b:
				fx.ring(_lid_dot(slot), LID_ROW * 0.42 * _s() * 1.6, Art.GOLD)
		_rate(-1))
	if _st.solved():
		if not before_crumbs.is_empty():
			_later(lands + 0.15, func() -> void:
				for c in before_crumbs:
					_sweeping[c] = _t
					if fx != null:
						fx.puff(_pos_now(c), Art.BISCUIT, 4)
				_cue("sweep"))
		_phase_solved(lands)

func _phase_solved(land: float) -> void:
	if themed() and _st.solved():
		# the win carries a theme beat: the theme biscuit was the last made,
		# or the word was missed and is named now
		_theme_beat = not Motion.reduce and (_st.whole.back() == _theme_b or not _st.found.has(_theme))
	check_solved()
	if not is_done():
		return
	_won_at = land + 0.2
	_later(land + 0.2, func() -> void:
		_lid_bump_at = _t
		_say_now("BT_PERFECT" if _st.points >= _st.line else "BT_DONE")
		if themed() and _theme_at == INF:
			# missed: the tag names the word, quietly
			_theme_at = _t
			_tag_key = "")
	_later(land + 0.45, func() -> void:
		_cue("solved")
		if fx != null:
			fx.confetti(Vector2(size.x * 0.5, float((_L.lid as Rect2).get_center().y)), 28, size.x * 0.7)
		var perfect: bool = _st.points >= _st.line and hints_used == 0
		_cue("party" if perfect else "confetti"))

func is_solved() -> bool:
	return _st.solved()

## The bulb in two presses. The first, one hint, rings the first piece of a
## biscuit not yet whole and says how long its word is; the second lays
## that biscuit on the plate and bakes it, free.
func hint() -> bool:
	if is_done():
		return false
	if _reading.is_empty():
		if _hints_held() <= 0:
			return false
		var b: int = _st.hint_biscuit()
		if b < 0:
			return false
		hints_used += 1
		var first: int = _st.biscuits[b][0]
		_reading = {"b": b, "piece": first}
		_reading_at = _t
		_say_now("BT_READ", _st.pieces[first].to_upper(), _st.biscuit_words[b].length())
		_cue("hint")
		if fx != null:
			fx.ring(_pos_now(first), _l("cell_h") * 0.7, Art.GOLD)
		moved.emit()
		_refresh_pill()
		return true
	var bb: int = _reading.b
	_reading = {}
	if _st.whole.has(bb):
		bb = _st.hint_biscuit()
		if bb < 0:
			return false
	_st.clear_plate()
	var parts: Array = _st.biscuits[bb]
	for i in parts:
		_st.add(int(i))
	_retarget(0.07)
	_cue("hint", 1.12)
	_read(_t + FLY + 0.07 * 3 + 0.1, true)
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

func _later(at: float, fn: Callable) -> void:
	_due.append({"at": at, "fn": fn})

func _cue(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch, volume_db)

## The stars read again (`before`: the stars before the points moved, -1
## to read them as they stand): a star earned pops in with two wraps.
func _rate(before: int) -> void:
	if demo:
		return
	var now: int = _st.stars()
	if _stars.rate(now, _t, true) > 0 or (before >= 0 and now > before):
		_cue("star", 1.0 + 0.06 * now)
	_refresh_pill()

func _refresh_pill() -> void:
	if _pill != null:
		_pill.queue_redraw()

func busy() -> bool:
	if not _due.is_empty() or not _bakes.is_empty():
		return true
	for i in _fly_at.size():
		if _t - _fly_at[i] < FLY:
			return true
	return false

# --- where things are ---

## Where piece `i` belongs now: its place on the plate, or in the tin.
func _home(i: int) -> Array:
	var k: int = _st.plate.find(i)
	if k >= 0:
		return [_plate_slot(k), float(_L.plate_k)]
	var j: int = _st.in_tin().find(i)
	if j < 0:
		j = 0
	return [_tin_slot(j), float(_L.tin_k)]

## Every piece sets off for where it belongs, from where it is drawn now
## (`stagger`: each after the one before, in plate order).
func _retarget(stagger := 0.0) -> void:
	if _L.is_empty():
		return
	var n := 0
	for i in _st.pieces.size():
		if _st.gone.has(i) and not _baking.has(i):
			continue
		if _baking.has(i):
			continue
		var h := _home(i)
		if (h[0] as Vector2).distance_to(_to[i]) < 0.5 and absf(float(h[1]) - _to_k[i]) < 0.001:
			continue
		var now := _pos_now(i)
		var nk := _k_now(i)
		_from[i] = now
		_from_k[i] = nk
		_to[i] = h[0]
		_to_k[i] = h[1]
		var d := 0.0
		if stagger > 0.0 and _st.on_plate(i):
			d = stagger * _st.plate.find(i)
		_fly_at[i] = _t + d
		n += 1
	_ghosts_key = ""

## Every piece where it belongs, nothing flying (a new layout).
func _snap() -> void:
	for i in _st.pieces.size():
		if _baking.has(i):
			continue
		var h := _home(i)
		_to[i] = h[0]
		_to_k[i] = h[1]
		_from[i] = h[0]
		_from_k[i] = h[1]
		_fly_at[i] = -INF

func _fly_e(i: int) -> float:
	if Motion.reduce:
		return 1.0
	return clampf((_t - _fly_at[i]) / FLY, 0.0, 1.0)

## Where piece `i` is drawn now, flying or not (its hop and shiver left out).
func _pos_now(i: int) -> Vector2:
	var e := _fly_e(i)
	if e >= 1.0:
		return _to[i]
	var q := Motion.back_out(e) if e > 0.0 else 0.0
	var at := _from[i].lerp(_to[i], q)
	at.y -= sin(e * PI) * FLY_ARC * _s() * clampf(_from[i].distance_to(_to[i]) / (300.0 * _s()), 0.0, 1.0)
	return at

func _k_now(i: int) -> float:
	var e := _fly_e(i)
	return lerpf(_from_k[i], _to_k[i], e)

## Piece `i`'s size at scale 1 (design px).
func _size_of(i: int) -> Vector2:
	var n := clampi(int(_st.pieces[i].length()), 2, 4)
	return Vector2(Art.PIECE_W[n], Art.PIECE_H)

func _piece_rect(i: int) -> Rect2:
	var sz := _size_of(i) * _k_now(i) * _s()
	return Rect2(_pos_now(i) - sz * 0.5, sz)

func _tin_slot(j: int) -> Vector2:
	var inner: Rect2 = _L.tin
	var c := Vector2(j % COLS, j / COLS)
	return inner.position + (Vector2(MARGIN, MARGIN) + (c + Vector2(0.5, 0.5)) * CELL) * _s()

## Where the `k`-th piece on the plate sits: the plate's pieces laid in a
## row about its middle, as many as there are.
func _plate_slot(k: int) -> Vector2:
	var n: int = _st.plate.size()
	var pk: float = _L.plate_k
	var total := -PLATE_GAP
	for j in n:
		total += _size_of(_st.plate[j]).x * pk + PLATE_GAP
	var x := _plate_mid().x - total * _s() * 0.5
	for j in k:
		x += (_size_of(_st.plate[j]).x * pk + PLATE_GAP) * _s()
	return Vector2(x + _size_of(_st.plate[k]).x * pk * _s() * 0.5, _plate_mid().y)

func _plate_mid() -> Vector2:
	return (_L.plate as Rect2).get_center() + Vector2(0.0, -6.0 * _s())

## The middle of the lid's place `k` (biscuits fill it in the order made:
## two a row, the last alone in the middle when odd).
func _lid_slot(k: int) -> Vector2:
	var lid: Rect2 = _L.lid
	var nb: int = _st.biscuits.size()
	var rows := (nb + 1) / 2
	var row := k / 2
	var col := k % 2
	var y := lid.position.y + (LID_PAD + (row + 0.5) * LID_ROW) * _s()
	var half := (lid.size.x - LID_PAD * 2.0 * _s()) * 0.25
	var x := lid.get_center().x + (-half if col == 0 else half)
	if row == rows - 1 and nb % 2 == 1:
		x = lid.get_center().x
	return Vector2(x, y)

# --- the tutorial's hands ---

## The tutorial's finger tapping piece `i` (in the tin or on the plate).
func demo_tap(i: int) -> void:
	_tap(_pos_now(i))

func demo_hint() -> void:
	hints_extra += 1
	hint()

func state():
	return _st

## The middle of piece `i` as drawn now.
func piece_to_local(i: int) -> Vector2:
	return _pos_now(i)

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
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
			if is_instance_valid(self):
				(d.fn as Callable).call()
	if _say != "" and _t - _say_at > SAY_TIME:
		_say = ""
	var keep_f: Array = []
	for f: Dictionary in _floats:
		if _t - float(f.at) < FLOAT_TIME:
			keep_f.append(f)
	_floats = keep_f
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
			_press_pos = event.position
		elif finger == _pressing:
			_pressing = -2
			if event.position.distance_to(_press_pos) <= TAP_SLOP * _s():
				_tap(_press_pos)
	elif event is InputEventScreenDrag:
		if event.index == _pressing:
			accept_event()

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
	if size.x <= 0.0 or size.y <= 0.0 or _st.pieces.is_empty():
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	_scene_key = ""
	_lid_key = ""
	_ghosts_key = ""
	_pieces = []
	_pieces_lit = []
	_snap()
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		var tin: Rect2 = _L.tin
		_world.set_lines(tin.grow(WALL * _s()), 0.0 if demo else float(_L.count_y))
	_refresh_pill()
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 300.0 * u)
	var nb: int = _st.biscuits.size()
	var lid_rows := (nb + 1) / 2
	var lid_h := LID_PAD * 2.0 + LID_ROW * lid_rows
	var rows := ceili(float(_st.pieces.size()) / COLS)
	var tin_w := CELL.x * COLS + MARGIN * 2.0
	var tin_h := CELL.y * rows + MARGIN * 2.0
	var below := GAP * 0.6 + COUNT_H if not (demo or _won) else 0.0
	var need := lid_h + GAP + SAY_H + PLATE_H + GAP + tin_h + WALL * 2.0 + below
	var k := minf(1.0, span / (need * u))
	k = minf(k, (w * 0.97) / ((tin_w + WALL * 2.0) * u))
	var s := u * k
	var y := top + maxf(0.0, (span - need * s) * (0.4 if not _won else 0.5))
	var mid := w * 0.5
	var lid_w := minf(LID_W * s, w * 0.95)
	var lid := Rect2(mid - lid_w * 0.5, y, lid_w, lid_h * s)
	y = lid.end.y + GAP * s
	var say_y := y + SAY_H * 0.5 * s
	y += SAY_H * s
	var plate_w := minf(PLATE_W * s, w * 0.96)
	var plate := Rect2(mid - plate_w * 0.5, y, plate_w, PLATE_H * s)
	y = plate.end.y + GAP * s + WALL * s
	var tin := Rect2(mid - tin_w * s * 0.5, y, tin_w * s, tin_h * s)
	var widest := Art.PIECE_W[4] * 4.0 + PLATE_GAP * 3.0
	var plate_k := minf(0.94, plate_w / s * 0.84 / widest)
	return {
		"u": u, "s": s, "top": top, "bottom": bottom,
		"lid": lid, "say_y": say_y, "plate": plate, "tin": tin,
		"plate_k": plate_k, "tin_k": TIN_K, "cell_h": CELL.y * s,
		"count_y": tin.end.y + (WALL + GAP * 0.6 + COUNT_H * 0.55) * s,
	}

## A layout value.
func _l(key: String) -> float:
	return float(_L.get(key, 0.0))

func _s() -> float:
	return float(_L.get("s", 1.0))

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.pieces.is_empty():
		return
	_draw_scene()
	_draw_lid()
	_draw_tag()
	_draw_ghosts()
	var font: Font = CozyTheme.display(800)
	# the tin's pieces first, then the plate's, then any flying on top
	var order: Array[int] = []
	var flying: Array[int] = []
	for i in _st.pieces.size():
		if _st.gone.has(i) and not _baking.has(i) and not _sweeping.has(i):
			continue
		if _fly_e(i) < 1.0 or _baking.has(i):
			flying.append(i)
		elif _st.on_plate(i):
			order.append(i)
		else:
			order.push_front(i)
	for i in order:
		_draw_piece(i, font)
	for i in flying:
		_draw_piece(i, font)
	_draw_bakes(font)
	_draw_reading()
	_draw_floats()
	_draw_say()
	_draw_count()

## The plate and the tin: one mesh, rebuilt with the layout.
func _draw_scene() -> void:
	var key := "%s:%s" % [str(_L.plate), str(_L.tin)]
	if key != _scene_key or _scene == null:
		_scene_key = key
		var b := Face.Builder.new()
		Art.plate(b, _L.plate)
		var tin: Rect2 = _L.tin
		Art.tin(b, tin, WALL * _s())
		var rows := ceili(float(_st.pieces.size()) / COLS)
		for j in rows * COLS:
			Art.case(b, _tin_slot(j), CELL * _s() * 0.92)
		_scene = b.mesh()
	var e := 1.0
	if not Motion.reduce:
		var d := _t - _enter_at - Motion.ENTER_DELAY * 0.5
		e = Motion.pop_in_scale(d, Motion.POP_IN * 1.4).x if d < Motion.POP_IN * 1.4 else 1.0
		if d < 0.0:
			e = 0.0
	if e <= 0.0:
		return
	var c := (_L.tin as Rect2).get_center()
	draw_set_transform(c * (1.0 - e), 0.0, Vector2.ONE * e)
	draw_mesh(_scene, null)
	draw_set_transform(Vector2.ZERO)

## The lid: its dimples, the biscuits made with their words. One mesh while
## nothing on it moves.
func _draw_lid() -> void:
	var nb: int = _st.biscuits.size()
	var key := "%d:%s" % [_lid_shown, str(_L.lid)]
	var r := LID_ROW * 0.42 * _s()
	if key != _lid_key or _lid_mesh == null:
		_lid_key = key
		var b := Face.Builder.new()
		Art.lid(b, _L.lid)
		for k in nb:
			var at := _lid_slot(k)
			var dot := _lid_dot(k)
			if k < _lid_shown:
				if _st.whole[k] == _theme_b:
					# the day's word: a gold ring round its biscuit
					b.stroke(Face.Builder.ring(dot, r * 1.2, r * 1.2), maxf(2.0, r * 0.12), Art.GOLD, true)
				Art.whole(b, dot, r, _st.whole[k])
			else:
				Art.dimple(b, dot, r)
		_lid_mesh = b.mesh()
	var bump := 1.0
	if _t - _lid_bump_at < Motion.BUMP_TIME and not Motion.reduce:
		bump = Motion.bump_scale(_t - _lid_bump_at, 0.05)
	var c := (_L.lid as Rect2).get_center()
	draw_set_transform(c * (1.0 - bump), 0.0, Vector2.ONE * bump)
	draw_mesh(_lid_mesh, null)
	# the words of the biscuits made, and dashes for the rest
	var font: Font = CozyTheme.display(800)
	for k in nb:
		var at := _lid_slot(k)
		var text := ""
		var ink := Color("fdf4dc")
		if k < _lid_shown:
			var bk: int = _st.whole[k]
			text = _st.written(_st.biscuit_words[bk]).to_upper()
			if bk == _theme_b:
				# the day's word written in gold
				ink = Art.RIM_LIT
		else:
			text = "? ? ?"
			ink = Color(ink, 0.5)
		var fs := roundi(LID_FONT * _s())
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var span := _lid_label(k)
		var room := span.y - span.x
		if tw > room:
			fs = maxi(1, roundi(fs * room / tw))
			tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := span.x + (room - tw) * 0.5
		var base := at.y + font.get_ascent(fs) * 0.36
		draw_string_outline(font, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(6 * _s()), Color(Art.TIN_DEEP, 0.8))
		draw_string(font, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_set_transform(Vector2.ZERO)

## A lid place's width: half the lid inside its rim (a place alone on the
## last row is as wide, centred).
func _lid_place_w(_k: int) -> float:
	return ((_L.lid as Rect2).size.x - LID_PAD * 2.0 * _s()) * 0.5

## Where the biscuit of lid place `k` sits: at the left of its place.
func _lid_dot(k: int) -> Vector2:
	var r := LID_ROW * 0.42 * _s()
	return _lid_slot(k) - Vector2(_lid_place_w(k) * 0.5 - r * 1.3, 0.0)

## The span a lid place gives its word, right of the biscuit: [x0, x1].
func _lid_label(k: int) -> Vector2:
	var r := LID_ROW * 0.42 * _s()
	var d := _lid_dot(k)
	return Vector2(d.x + r * 1.5, _lid_slot(k).x + _lid_place_w(k) * 0.5 - r * 0.5)

## Faint outlines in the tin where the plate's pieces came from.
func _draw_ghosts() -> void:
	if _st.plate.is_empty():
		return
	var key := "%s:%s" % [str(_st.plate), str(_L.tin)]
	if key != _ghosts_key or _ghosts == null:
		_ghosts_key = key
		var b := Face.Builder.new()
		var slots: Array[int] = _st.in_tin()
		for i in _st.plate:
			var j := slots.find(i)
			if j < 0:
				continue
			var sz := _size_of(i) * TIN_K * _s()
			var g := Face.Builder.new()
			Art.piece(g, sz, i, 0.0, true)
			b.append(g.mesh(), Transform2D(0.0, _tin_slot(j)))
		_ghosts = b.mesh()
	draw_mesh(_ghosts, null)

## One piece where it is drawn now: its cached mesh under a transform
## (gold while a word it is in is lit), its letters over it.
func _draw_piece(i: int, font: Font) -> void:
	if _pieces.size() != _st.pieces.size():
		_pieces.resize(_st.pieces.size())
		_pieces_lit.resize(_st.pieces.size())
	var lit := 0.0
	var le := _t - _light_at[i]
	if le >= 0.0 and le < LIGHT_TIME:
		lit = 1.0 - le / LIGHT_TIME
	var at := _pos_now(i)
	var k := _k_now(i) * _s()
	var alpha := 1.0
	if not Motion.reduce:
		# dropping into the tin, row by row
		if not _st.on_plate(i) and _fly_at[i] == -INF:
			var j: int = _st.in_tin().find(i)
			var d := _t - _enter_at - Motion.ENTER_DELAY - 0.15 - (j / COLS) * 0.07 - (j % COLS) * 0.025
			if d < 0.0:
				return
			if d < Motion.POP_IN * 1.4:
				at.y -= _l("cell_h") * 0.8 * (1.0 - Motion.back_out(d / (Motion.POP_IN * 1.4)))
		var h := _t - _hop_at[i]
		if h >= 0.0 and h < Motion.SOLVE_TIME:
			at.y += Motion.hop_lift(h, Motion.SOLVE_HOP * 1.4 * _s(), Motion.SOLVE_TIME)
		var sh := _t - _shiver_at[i]
		if sh >= 0.0 and sh < SHIVER_TIME:
			at.x += sin(sh * 48.0) * 7.0 * _s() * (1.0 - sh / SHIVER_TIME)
	if _baking.has(i):
		var bake: Dictionary = _baking[i]
		var e := (_t - float(bake.at)) / CLOSE if not Motion.reduce else 1.0
		if e > 0.0:
			var q := clampf(e, 0.0, 1.0)
			at = at.lerp(bake.mid, Motion.back_out(q) * 0.85)
			k *= lerpf(1.0, 0.7, q)
			alpha = 1.0 - clampf(e - 0.6, 0.0, 0.4) / 0.4
	if _sweeping.has(i):
		var se := maxf(0.0, (_t - float(_sweeping[i])) / SWEEP) if not Motion.reduce else 1.0
		if float(_sweeping[i]) > _t:
			se = 0.0
		if se >= 1.0:
			return
		k *= 1.0 - se * 0.6
		at.x += se * 60.0 * _s() * (1.0 if i % 2 == 0 else -1.0)
		at.y += se * se * 120.0 * _s()
		alpha = 1.0 - se
	if alpha <= 0.0:
		return
	var m: ArrayMesh = _pieces_lit[i] if lit > 0.5 else _pieces[i]
	if m == null:
		var b := Face.Builder.new()
		Art.piece(b, _size_of(i), i, 1.0 if lit > 0.5 else 0.0)
		m = b.mesh()
		if lit > 0.5:
			_pieces_lit[i] = m
		else:
			_pieces[i] = m
	draw_set_transform(at, 0.0, Vector2.ONE * k)
	draw_mesh(m, null, Transform2D.IDENTITY, Color(1, 1, 1, alpha))
	var text: String = _st.pieces[i].to_upper()
	var fs := roundi(Art.PIECE_H * LETTER_K)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var room := _size_of(i).x * 0.84
	if tw > room:
		fs = maxi(1, roundi(fs * room / tw))
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := font.get_ascent(fs) * 0.36
	draw_string_outline(font, Vector2(-tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(Art.BISCUIT_LIT, 0.7 * alpha))
	draw_string(font, Vector2(-tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Art.INK, alpha))
	draw_set_transform(Vector2.ZERO)

## The biscuits being made: once the pieces have closed up, a whole biscuit
## pops at the plate's middle and flies to its place on the lid.
func _draw_bakes(font: Font) -> void:
	if _bakes.is_empty():
		return
	var r := LID_ROW * 0.42 * _s()
	for bake: Dictionary in _bakes:
		var e := _t - float(bake.at) - CLOSE * 0.7
		if e < 0.0:
			continue
		var big := _l("cell_h") * 0.95
		var at: Vector2 = bake.mid
		var rad := big
		if e < KNIT:
			rad = big * (Motion.pop_in_scale(e, KNIT).x if not Motion.reduce else 1.0)
		else:
			var f := clampf((e - KNIT) / TO_LID, 0.0, 1.0) if not Motion.reduce else 1.0
			var q := f * f * (3.0 - 2.0 * f)
			var slot := _lid_dot(int(bake.slot))
			at = (bake.mid as Vector2).lerp(slot, q)
			at.y -= sin(f * PI) * 90.0 * _s()
			rad = lerpf(big, r, q)
		if rad <= 0.0:
			continue
		# built once at its full size (strokes and holes keep their weight),
		# drawn scaled down as it flies
		var key := "%d:%d" % [int(bake.b), roundi(big)]
		if key != _bake_key or _bake_mesh == null:
			_bake_key = key
			var b := Face.Builder.new()
			Art.whole(b, Vector2.ZERO, big, int(bake.b))
			_bake_mesh = b.mesh()
		draw_set_transform(at, (e - KNIT) * 3.0 if e > KNIT and not Motion.reduce else 0.0, Vector2.ONE * (rad / big))
		draw_mesh(_bake_mesh, null)
		draw_set_transform(Vector2.ZERO)
		if e < KNIT + TO_LID * 0.3 and rad > big * 0.4:
			var text: String = _st.written(_st.biscuit_words[int(bake.b)]).to_upper()
			var fs := roundi(SAY_SIZE * _s())
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if tw > rad * 1.8:
				fs = maxi(1, roundi(fs * rad * 1.8 / tw))
				tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var base := at.y + font.get_ascent(fs) * 0.36
			draw_string_outline(font, Vector2(at.x - tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(6 * _s()), Color(Art.BISCUIT_LIT, 0.8))
			draw_string(font, Vector2(at.x - tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)

## The bulb's first press: a gold ring round the first piece of a biscuit,
## pulsing.
func _draw_reading() -> void:
	if _reading.is_empty():
		return
	var i: int = _reading.piece
	if _st.gone.has(i):
		return
	var r := _piece_rect(i).grow(8.0 * _s())
	var pulse := 0.6 + 0.4 * sin((_t - _reading_at) * 5.0) if not Motion.reduce else 1.0
	var b := Face.Builder.new()
	b.stroke(Face.Builder.round_rect(r.position, r.size, r.size.y * 0.32), 8.0 * _s(), Color(Art.GOLD, 0.95 * pulse), true)
	_reading_mesh = b.mesh()
	draw_mesh(_reading_mesh, null)

## The points of a word floating up off the plate.
func _draw_floats() -> void:
	if _floats.is_empty():
		return
	var font: Font = CozyTheme.display(800)
	for f: Dictionary in _floats:
		var e := (_t - float(f.at)) / FLOAT_TIME
		if e < 0.0:
			continue
		var fs := roundi(FLOAT_SIZE * _s())
		var text: String = f.text
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at: Vector2 = f.pos + Vector2(-tw * 0.5, -_l("cell_h") * 0.5 - e * 80.0 * _s())
		var a := 1.0 - clampf((e - 0.5) / 0.5, 0.0, 1.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(10 * _s()), Color(Pal.SURFACE, 0.9 * a))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Art.GOLD_DEEP.darkened(0.25), a))

## What the board says, between the lid and the plate.
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
	var good := _say in ["BT_SAY_WORD", "BT_SAY_BISCUIT", "BT_SAY_BISCUIT_FREE", "BT_SAY_THEME", "BT_SAY_THEME_FREE", "BT_PERFECT", "BT_DONE", "BT_READ"]
	var fs := roundi(SAY_SIZE * (1.15 if good else 1.0) * _s())
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > size.x * 0.94:
		fs = maxi(1, roundi(fs * size.x * 0.94 / tw))
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var e := _t - _say_at
	var pk := Motion.pop_in_scale(e, 0.25).x if e < 0.25 and not Motion.reduce else 1.0
	var fade := clampf((SAY_TIME - e) / 0.4, 0.0, 1.0)
	var ink := Art.BISCUIT_DARK.darkened(0.25) if good else Pal.TEXT
	var asc := font.get_ascent(fs)
	draw_set_transform(Vector2(size.x * 0.5, _l("say_y")), 0.0, Vector2.ONE * pk)
	draw_string_outline(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(12 * _s()), Color(Pal.SURFACE, 0.92 * fade))
	draw_string(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, fade))
	draw_set_transform(Vector2.ZERO)

## At the foot: the words found, and on Insane the rule.
func _draw_count() -> void:
	if demo or _won or is_done():
		return
	var font: Font = CozyTheme.display(700)
	var n: int = _st.found.size()
	var text: String = tr("BT_FOUND_ONE") if n == 1 else tr("BT_FOUND_N") % n
	if not _st.crumbs.is_empty():
		text += "  ·  " + tr("BT_CRUMBS")
	var cs := roundi(COUNT_SIZE * float(_L.u))
	var cw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	if cw > size.x * 0.94:
		cs = maxi(1, roundi(cs * size.x * 0.94 / cw))
		cw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	var at := Vector2(size.x * 0.5 - cw * 0.5, _l("count_y"))
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, roundi(10 * float(_L.u)), Color(Pal.SURFACE, 0.92))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Pal.TEXT)

## The pill in the tools row's gap: the stars the points stand at, then the
## points against the line.
func _draw_pill() -> void:
	if not _bled or _won or _st.pieces.is_empty():
		return
	var enter := 1.0 if Motion.reduce else Motion.pop_in_scale(_t - _enter_at - Motion.ENTER_DELAY).x
	if enter <= 0.0:
		return
	var font: Font = CozyTheme.body(700)
	var text: String = tr("BT_POINTS") % [_st.points, _st.line]
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
	return WIN_HOLD + (THEME_HOLD if _theme_beat else 0.0)

func skill_quality() -> float:
	if _st.pieces.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🍪 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var line: String
	if _st.points >= _st.line:
		line = tr("BT_WIN_LINE") % [_st.points, _st.found.size()]
	else:
		line = tr("BT_WIN") % [_st.points, _st.line]
	if themed():
		var key := "BT_WIN_THEME" if _st.found.has(_theme) else "BT_WIN_THEME_MISSED"
		line = tr(key) % [_st.written(_theme).to_upper(), line]
	return {"faces": [], "subtitle": line}

func completion_record() -> Dictionary:
	return {"points": _st.points, "helped": _st.helped, "stars": _st.stars(),
		"found": Array(_st.found), "whole": Array(_st.whole), "bulb": _st.by_bulb.keys(),
		"entry": _dealt, "theme": _theme}

## A finished day reopens whole, its words and biscuits kept.
func restore_completed_board() -> void:
	# a day played before the night's words reached this phone (or after)
	# reopens on the entry it was played on, not on today's deal
	var was = completed_record.get("entry")
	if was is Dictionary and not (was as Dictionary).is_empty() and was != _dealt:
		_st.band = _band
		_st.load_day(was)
		_dealt = was
		_theme = String(completed_record.get("theme", ""))
		_theme_b = _st.biscuit_of(_theme) if _theme != "" else -1
		_fresh()
	var order: Array = completed_record.get("whole", [])
	_st.whole.clear()
	for b in order:
		if int(b) >= 0 and int(b) < _st.biscuits.size() and not _st.whole.has(int(b)):
			_st.whole.append(int(b))
	_st.finish()
	_st.points = int(completed_record.get("points", _st.line))
	_st.helped = int(completed_record.get("helped", 0))
	_st.by_bulb = {}
	for b in completed_record.get("bulb", []):
		_st.by_bulb[int(b)] = true
	_st.found.clear()
	for w in completed_record.get("found", []):
		_st.found.append(String(w))
	for w in _st.biscuit_words:
		if not _st.found.has(w):
			_st.found.append(w)
	_lid_shown = _st.whole.size()
	_lid_key = ""
	if themed():
		# a reopened themed day shows the tag open on the word
		_theme_at = _t - 10.0
		_tag_key = ""
	_snap()
	queue_redraw()

# --- the daily theme (2026-11-06) ---

func themed() -> bool:
	return _theme != ""

## The tin a themed daily deals ({day, word}, the word as the bank spells
## it), or {}: only a daily dealt from its day, never New, never the
## tutorial's tin. A tin with the word among its biscuits first, else
## among any word it credits.
func _themed_tin() -> Dictionary:
	if demo or bank_step != 0 or daily_key == 0:
		return {}
	var pool: Array = pool_for_shots if not pool_for_shots.is_empty() else ThemedPictures.theme_pool(daily_key)
	if pool.is_empty():
		return {}
	var boards: Array = InsaneBank.boards(State.BANKS[clampi(_band, 0, 3)])
	var got := ThemedPictures.bank_pick(boards, pool, daily_key, _biscuit_words)
	if got.is_empty():
		got = ThemedPictures.bank_pick(boards, pool, daily_key, _credited_words)
	if got.is_empty():
		return {}
	var day: Dictionary = boards[int(got.index)]
	# the word as the tin spells it (the pool's is folded)
	for w in _credited_words(day):
		if Locale.fold(String(w)) == String(got.word):
			return {"day": day, "word": String(w)}
	return {}

## A banked tin's biscuit words.
static func _biscuit_words(day: Dictionary) -> Array:
	var out: Array = []
	var pieces: Array = day.get("pieces", [])
	for b in day.get("biscuits", []):
		var w := ""
		for i in b:
			if int(i) >= 0 and int(i) < pieces.size():
				w += String(pieces[int(i)])
		out.append(w)
	return out

## Every word a banked tin credits (its biscuits among them).
static func _credited_words(day: Dictionary) -> Array:
	var out: Array = []
	for e in day.get("words", []):
		out.append(String(e[0]) if e is Array else String(e))
	return out

## The theme word made, at `at`: the tag opens, a sparkle, the theme cue a
## breath after the word's own, and the say line names it.
func _theme_found(at: Vector2, say: String, got: int) -> void:
	if _theme_at != INF:
		return
	_theme_at = _t
	_tag_key = ""
	_say_now(say, _st.written(_theme).to_upper(), got)
	if fx != null:
		fx.sparkle(at, Art.GOLD)
		fx.sparkle(_tag_mid(), Art.GOLD)
	_later(_t + THEME_CUE, func() -> void: _cue("theme"))

## The tag's middle: on the lid's lower rim, in the middle.
func _tag_mid() -> Vector2:
	var lid: Rect2 = _L.get("lid", Rect2())
	return Vector2(lid.get_center().x, lid.end.y)

## The tag on the lid's rim: a paper label with a sun while the word is
## unmade, opened to name it once made (or at the win).
func _draw_tag() -> void:
	if not themed() or _L.is_empty():
		return
	var open := _theme_at != INF and _t >= _theme_at
	var font: Font = CozyTheme.display(800)
	var s := _s()
	var h := TAG_H * s
	var text := _st.written(_theme).to_upper() if open else ""
	var fs := roundi(TAG_FONT * s)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if open else 0.0
	var sun_r := h * 0.25
	var w := h if not open else h * 1.45 + tw
	var c := _tag_mid()
	var key := "%s:%s:%d" % [str(c), text, roundi(h)]
	if key != _tag_key or _tag_mesh == null:
		_tag_key = key
		var b := Face.Builder.new()
		var corner := Vector2(-w * 0.5, -h * 0.5)
		b.polygon(Face.Builder.round_rect(corner + Vector2(0.0, h * 0.08), Vector2(w, h), h * 0.5), Color(Art.TIN_DEEP, 0.5))
		b.polygon(Face.Builder.round_rect(corner, Vector2(w, h), h * 0.5), Pal.SURFACE)
		b.stroke(Face.Builder.round_rect(corner, Vector2(w, h), h * 0.5), maxf(1.5, h * 0.07), Art.GOLD, true)
		var sun_at := Vector2(0.0 if not open else -w * 0.5 + h * 0.55, 0.0)
		Art.sun(b, sun_at, sun_r)
		_tag_mesh = b.mesh()
	var k := 1.0
	if open and not Motion.reduce and _t - _theme_at < TAG_POP:
		k = Motion.pop_in_scale(_t - _theme_at, TAG_POP).x
	draw_set_transform(c, 0.0, Vector2.ONE * k)
	draw_mesh(_tag_mesh, null)
	if open:
		var x := -w * 0.5 + h * 1.0
		var base := font.get_ascent(fs) * 0.36
		draw_string(font, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.GOLD_DEEP.darkened(0.35))
	draw_set_transform(Vector2.ZERO)
