extends "res://core/puzzle_base.gd"

## Garden Fence (spec docs/superpowers/specs/2026-11-04-garden-fence-design.md):
## a words board. A garden bed on a lawn, a low fence round it with three
## posts a side, a letter on each post's cap. Tap posts (or drag across
## them) to string twine post to post and spell a word, never two posts in a
## row from one side; tap the last post again, or the sign the word is
## chalked on, to tie it off. The next word starts on the post the last one
## ended on. A post twine has touched opens a daisy; every post in bloom is
## the solve. The rules are puzzles/fence_state.gd's.
##
## **The lawn is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/fence_world.gd) is the board's first child. From the top
## of the span down: the seed tags of the words tied, the line the board
## says things on, the sign, the fence, the count. The stars and the words
## against the par stand on a paper pill in the tools row's gap.
##
## Strung twine is green, gold while it spells a word the garden knows; tied
## it turns jute, a knot pops on its last post and the word's posts hop in
## order. Undo takes back the last letter, or unties the last word (its
## twine recoils); the bin unties them all. The bulb in two presses: the
## first rings the posts the next word of a fewest way starts and ends on
## and says how long it is, the second strings it and ties it. On Insane
## (Gate) the last word must end on the gate post.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/fence_tutorial_diagram.gd plays it with `demo_tap` and `demo_tie`.

const State = preload("res://puzzles/fence_state.gd")
const World = preload("res://puzzles/fence_world.gd")
const Art = preload("res://ui/faces/fence_art.gd")
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

const Said = State.Said

const HAPTICS := {
	"post": Haptics.TICK,
	"back": Haptics.TICK,
	"side": Haptics.WARN,
	"refuse": Haptics.WARN,
	"again": Haptics.TICK,
	"tie": Haptics.GOOD,
	"bloom": Haptics.TAP,
	"undo": Haptics.TICK,
	"clear": Haptics.TICK,
	"fall": Haptics.TICK,
	"gate": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
	"theme": Haptics.GOOD,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## The seed tags: a row's height, the gap between tags, the rows at most.
const TAG_H := 54.0
const TAG_GAP := 12.0
const TAG_ROWS := 2
const TAG_FONT := 30
const SAY_H := 60.0
const SAY_SIZE := 36
## The sign: its size, and its letters' share of its height.
const SIGN := Vector2(640.0, 112.0)
const SIGN_K := 0.5
const GAP := 24.0
## The fence's widest (design px), a post's radius as a share of it, where
## a side's three posts stand along it.
const FENCE_MAX := 960.0
const POST_K := 0.064
const ALONG := [0.2, 0.5, 0.8]
## The triangle's corners are sharp: its posts stand further from them.
const ALONG_TRI := [0.25, 0.5, 0.75]
const LETTER_K := 0.95
const COUNT_H := 50.0
const COUNT_SIZE := 30
const PILL_FONT := 28
const PILL_R := 21.0
const PILL_PAD := Vector2(18.0, 8.0)
const PILL_RIM := 2.0
## A finger moves this far (design px) before a press is a drag; a post
## answers this far past its rim.
const TAP_SLOP := 26.0
const HIT_K := 1.3
## A dragging finger strings a post only nearer its middle, so one it
## passes on the way to another is left alone.
const DRAG_HIT_K := 0.8
## The motions: a strand of twine running out to its post, a refusal's
## shiver, a tied word's hops, a daisy opening, untied twine recoiling, the
## bulb's letters strung one by one, the solve's wave round the fence.
const SEG_TIME := 0.12
const SHIVER_TIME := 0.35
const HOP_STEP := 0.06
const BLOOM_TIME := 0.42
const RECOIL_TIME := 0.32
const BULB_STEP := 0.16
const WAVE_STEP := 0.05
const SAY_TIME := 2.4
const WIN_HOLD := 1.7
## The daily theme (2026-11-06): on a daily dealt from its day, the fence
## dealt is one the day's theme word can be strung on (fence_state.gd's
## `theme_words`, ThemedPictures.bank_pick), never another fence or par. A
## seed packet with a sun on it hangs on the sign while the word is hidden,
## and the board says so THEME_TEASE_AT after it enters. Tied, the word's
## twine is a rose ribbon with a bow on its first strand (a colour and a
## shape no twine state uses), its tag gets a bow, the theme cue rings THEME_CUE_AT
## after the tie with a sparkle on each of its posts, and the line names it.
## The win waits THEME_HOLD longer when it was found (the ribbon sparkles
## again); its line names the word either way.
const THEME_TEASE_AT := 1.1
const THEME_CUE_AT := 0.22
const THEME_HOLD := 0.6
const BOW_TIME := 0.36

var demo := false
var demo_day := {}
## The day's theme word the fence was dealt for (folded), "" on a plain day;
## when it was tied (the bow's pop-in).
var theme_word := ""
## The harness's seam: a pool (folded, strongest first) dealt from in place
## of the day's, set before the board is built (Backend never starts in a
## harness). null in the game.
static var theme_pool_seam = null
var _theme_at := -INF
var _bow_mesh: ArrayMesh
var _bow_key := ""

var _st = State.new()
var _band := 0
var _t := 0.0
var _enter_at := 0.0
var _won_at := -INF
## When each post last hopped, shivered, bloomed; when the trail's last
## strand set off.
var _hop_at: Array[float] = []
var _shiver_at: Array[float] = []
var _bloom_at: Array[float] = []
var _seg_at := -INF
var _knot_at := -INF
var _sign_shiver_at := -INF
var _tag_at: Array[float] = []
## Untied twine still recoiling: [{"posts", "at"}].
var _recoil: Array = []
## The bulb's first press: {"word", "from", "to"}; the bulb stringing.
var _reading := {}
var _reading_at := -INF
var _stringing := false
var _say := ""
var _say_args: Array = []
var _say_at := -INF
var _stars := StarLine.new()
var _due: Array = []
var _rng := RandomNumberGenerator.new()
## The finger: which, where it went down, whether it is dragging, what it
## pressed (a post, -1 none; the sign).
var _pressing := -2
var _press_pos := Vector2.ZERO
var _finger := Vector2.ZERO
var _dragging := false
var _press_post := -1
var _press_end := false
var _press_sign := false
var _over := -1

var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _world: Control
var _pill: Control
var _bed: ArrayMesh
var _bed_key := ""
var _tied_mesh: ArrayMesh
var _tied_key := ""
var _trail_mesh: ArrayMesh
var _trail_key := ""
var _sign_mesh: ArrayMesh
var _sign_key := ""
var _tags_mesh: ArrayMesh
var _tags_key := ""
var _posts_plain: Array = []
var _posts_used: Array = []
var _daisy: ArrayMesh
var _daisy_r := 0.0
var _gate_mesh: ArrayMesh
var _gate_key := ""
var _pill_mesh: ArrayMesh
## This frame's passing meshes, held until the next frame's draw (a mesh
## let go of inside _draw is freed before it renders).
var _frame: Array = []
var fx: Node

func puzzle_id() -> String: return "fence"
func title() -> String: return "Garden Fence"

func rules() -> String:
	var out: String = tr("FN_RULES") % [_st.posts.size(), _st.sides]
	out += "\n\n" + tr("FN_RULES_CHAIN")
	if _st.gate >= 0:
		out += "\n\n" + tr("FN_RULES_GATE")
	out += "\n\n" + tr("FN_RULES_PAR") % [_st.par, _st.par + State.THREE]
	out += "\n\n" + tr("FN_RULES_UNDO")
	out += "\n\n" + tr("FN_RULES_HINT")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/fence_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.STRING, "HTP_FN_STRING", tr("HTP_FN_STRING_BODY")],
		[Diagram.Lesson.CHAIN, "HTP_FN_CHAIN", tr("HTP_FN_CHAIN_BODY")],
		[Diagram.Lesson.BLOOM, "HTP_FN_BLOOM", tr("HTP_FN_BLOOM_BODY") % _st.par],
	]
	if _st.gate >= 0:
		steps.append([Diagram.Lesson.GATE, "HTP_FN_GATE", tr("HTP_FN_GATE_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_FN_HINT", tr("HTP_FN_HINT_BODY")])
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
	return not is_done() and not _stringing and (_st.trail.size() > _st.base() or not _st.tied.is_empty())

func can_reset() -> bool:
	return not is_done() and not _stringing

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
	_st.band = _band
	theme_word = ""
	if demo and not demo_day.is_empty():
		_st.load_day(demo_day)
	elif demo or bank_step != 0 or daily_key == 0 or not _theme_deal(_theme_pool()):
		_st.deal(rng, _band, bank_step)
	_fresh()
	_enter_at = _t
	_cue("enter")
	_tease()

## The day's theme words, or the harness's (theme_pool_seam).
func _theme_pool() -> Array:
	if theme_pool_seam is Array:
		return theme_pool_seam
	return ThemedPictures.theme_pool(daily_key)

## The daily theme's deal: of the band's bank, the fence the strongest word
## of `pool` (theme_pool: folded, strongest first) can be strung on, as
## ThemedPictures.bank_pick chooses it. False, and nothing dealt, when no
## fence holds one.
func _theme_deal(pool: Array) -> bool:
	if pool.is_empty():
		return false
	var accepted: Array = State.theme_accepted(pool)
	if accepted.is_empty():
		return false
	var boards: Array = InsaneBank.boards(State.BANKS[_band])
	var bits: PackedInt64Array = State.theme_bits(accepted)
	var hit: Dictionary = ThemedPictures.bank_pick(boards, accepted, daily_key,
		func(e: Dictionary) -> Array: return State.theme_words(e, accepted, bits))
	if hit.is_empty():
		return false
	_st.band = _band
	_st.load_day(boards[int(hit.index)])
	theme_word = String(hit.word)
	return true

func themed() -> bool:
	return theme_word != ""

## Whether the day's theme word is tied (an untied one is hidden again).
func theme_found() -> bool:
	if not themed():
		return false
	for t: Dictionary in _st.tied:
		if String(t.word) == theme_word:
			return true
	return false

## The word as the list writes it (accents), upper case.
func _theme_shown() -> String:
	return _st.written(theme_word).to_upper()

## A themed fence says, once it is in, that the day's word is in it.
func _tease() -> void:
	if not themed() or demo:
		return
	_say_now("FN_SAY_THEME_HIDDEN")
	_say_at = _t + THEME_TEASE_AT

## Every post as dealt, nothing moving.
func _fresh() -> void:
	var n: int = _st.posts.size()
	_hop_at.resize(n)
	_shiver_at.resize(n)
	_bloom_at.resize(n)
	for i in n:
		_hop_at[i] = -INF
		_shiver_at[i] = -INF
		_bloom_at[i] = -INF
	_tag_at.clear()
	for k in _st.tied.size():
		_tag_at.append(-INF)
	_recoil.clear()
	_reading = {}
	_say = ""
	_posts_plain = []
	_posts_used = []
	_stars.clear(_st.stars())
	_dirty()
	_relayout()

func _dirty() -> void:
	_bow_key = ""
	_tied_key = ""
	_trail_key = ""
	_sign_key = ""
	_tags_key = ""
	_gate_key = ""

func day_dict() -> Dictionary:
	if _st.posts.is_empty():
		return {}
	return {
		"source": "theme" if themed() else "bank", "kind": "text",
		"theme": theme_word,
		"payload": {"posts": "".join(_st.posts), "sides": _st.sides, "gate": _st.gate},
		"solution": {"route": Array(_st.route)},
		"metrics": {"par": _st.par, "words": _st.word_count()},
	}

# --- the moves ---

## Post `p` strung next. A post from the side of the last shivers and is
## refused; a post already the trail's end is the caller's (a tie).
func _string(p: int, quiet := false) -> bool:
	if is_done() or _stringing or _st.solved():
		return false
	if not _st.can_add(p):
		if not quiet:
			_shiver_at[p] = _t
			_say_now("FN_SAY_SIDE")
			_cue("side")
		return false
	_st.add(p)
	_seg_at = _t
	_trail_key = ""
	_sign_key = ""
	_cue("post", 0.94 + 0.04 * mini(_st.trail.size(), 10) + _rng.randf_range(-0.02, 0.02))
	if _st.knows(_st.trail_word()) and not demo:
		# the twine goes gold: a word the garden knows
		_cue("ready", 1.0 + 0.03 * mini(_st.trail.size(), 8), -4.0)
	moved.emit()
	return true

## The last letter taken back off the trail.
func _unstring() -> bool:
	if not _st.back():
		return false
	_trail_key = ""
	_sign_key = ""
	_seg_at = -INF
	_cue("back", 1.0 + 0.03 * _st.trail.size())
	moved.emit()
	return true

## Ties the trail off.
func _tie(kind := "hand") -> void:
	if is_done():
		return
	var word: String = _st.trail_word()
	var posts: Array = _st.trail.duplicate()
	var before: int = _st.used()
	var said: Said = _st.tie(kind)
	match said:
		Said.SHORT:
			_refuse("FN_SAY_SHORT")
			return
		Said.UNKNOWN:
			_refuse("FN_SAY_UNKNOWN", [word.to_upper()])
			return
		Said.AGAIN:
			_sign_shiver_at = _t
			_say_now("FN_SAY_AGAIN", [_st.written(word).to_upper()])
			_cue("again")
			return
	if kind == "hand" and not demo:
		moves += 1
	_reading = {}
	_tag_at.append(_t)
	_knot_at = _t
	_seg_at = -INF
	_dirty()
	for k in posts.size():
		_hop_at[posts[k]] = _t + k * HOP_STEP
	var fresh: Array[int] = []
	var now: int = _st.used()
	for i in _st.posts.size():
		if now & (1 << i) != 0 and before & (1 << i) == 0:
			fresh.append(i)
	_cue("tie", 1.0 + 0.04 * mini(word.length(), 10))
	for k in fresh.size():
		var i: int = fresh[k]
		var at := _t + 0.08 + k * HOP_STEP
		_bloom_at[i] = at
		_later(at, func() -> void:
			_cue("bloom", 1.0 + 0.05 * mini(k, 8), -3.0)
			if fx != null:
				fx.sparkle(_post_at(i), Art.HEART))
	if fx != null:
		fx.ring(_post_at(posts[-1]), _l("r") * 1.6, Art.GOLD)
	var gain := fresh.size()
	if said == Said.SOLVED:
		_say_now("FN_SAY_TIED", [_st.written(word).to_upper(), gain])
		_phase_solved(_t + 0.08 + fresh.size() * HOP_STEP + 0.3)
	elif said == Said.OPEN:
		_say_now("FN_SAY_OPEN")
		_later(_t + 0.3, func() -> void: _cue("gate", 0.9))
	elif gain > 0:
		_say_now("FN_SAY_TIED", [_st.written(word).to_upper(), gain])
	else:
		_say_now("FN_SAY_TIED_NONE", [_st.written(word).to_upper()])
	if themed() and word == theme_word:
		_theme_tied(posts, said == Said.SOLVED)
	_rate(true)
	moved.emit()

## The day's theme word tied: its twine turns ribbon and a bow pops on its
## first strand, the line names it, the theme cue rings a beat after the tie
## with a sparkle on each of its posts.
func _theme_tied(posts: Array, solving: bool) -> void:
	_theme_at = _t
	_tied_key = ""
	_tags_key = ""
	_sign_key = ""
	if not solving:
		_say_now("FN_SAY_THEME", [_theme_shown()])
	_later(_t + THEME_CUE_AT, func() -> void:
		_cue("theme")
		if fx != null:
			for p in posts:
				fx.sparkle(_post_at(int(p)), Art.RIBBON_LIT))

func _refuse(key: String, args: Array = []) -> void:
	_sign_shiver_at = _t
	for p in _st.trail:
		_shiver_at[p] = _t
	_say_now(key, args)
	_cue("refuse")

func _phase_solved(land: float) -> void:
	check_solved()
	if not is_done():
		return
	_won_at = land
	var n: int = _st.posts.size()
	_later(land, func() -> void:
		for i in n:
			_hop_at[i] = _t + i * WAVE_STEP
		_say_now("FN_PERFECT" if _st.tied.size() <= _st.par else "FN_DONE")
		_cue("solved"))
	_later(land + 0.3, func() -> void:
		if fx != null:
			fx.confetti(Vector2(size.x * 0.5, (_L.fence as Rect2).get_center().y), 28, size.x * 0.7)
			if theme_found():
				# the ribbon sparkles again under the confetti
				for ch in theme_word:
					fx.sparkle(_post_at(_st.post_of(ch)), Art.RIBBON_LIT)
		var perfect: bool = _st.tied.size() <= _st.par and hints_used == 0
		_cue("party" if perfect else "confetti"))

func is_solved() -> bool:
	return _st.solved()

func undo() -> bool:
	if not can_undo():
		return false
	_reading = {}
	if _st.trail.size() > _st.base():
		_unstring()
		return true
	var gone: Array = []
	var w: String = _st.tied[-1].word
	for ch in w:
		gone.append(_st.post_of(ch))
	_untie_word()
	_recoil.append({"posts": gone, "at": _t})
	_cue("undo")
	_say_now("FN_SAY_UNTIED", [_st.written(w).to_upper()])
	_rate(false)
	moved.emit()
	return true

func _untie_word() -> void:
	var before: int = _st.used()
	_st.untie()
	if not _tag_at.is_empty():
		_tag_at.pop_back()
	var now: int = _st.used()
	for i in _st.posts.size():
		if before & (1 << i) != 0 and now & (1 << i) == 0:
			_bloom_at[i] = -INF
	_dirty()

func reset_board() -> void:
	if is_done() or _stringing:
		return
	var had: bool = not _st.tied.is_empty() or not _st.trail.is_empty()
	for t: Dictionary in _st.tied:
		var gone: Array = []
		for ch in String(t.word):
			gone.append(_st.post_of(ch))
		_recoil.append({"posts": gone, "at": _t})
	_st.clear()
	_tag_at.clear()
	for i in _st.posts.size():
		_bloom_at[i] = -INF
	moves = 0
	_reading = {}
	_dirty()
	if had:
		_cue("clear")
	_rate(false)
	moved.emit()

## The bulb in two presses. The first, one hint, rings the posts the next
## word of a fewest way starts and ends on and says how long it is (from a
## dead end: the word to untie); the second strings that word and ties it.
func hint() -> bool:
	if is_done() or _stringing:
		return false
	if _reading.is_empty():
		if _hints_held() <= 0:
			return false
		var h: Dictionary = _st.hint_word()
		if h.is_empty():
			return false
		hints_used += 1
		_reading = h
		_reading_at = _t
		if h.has("back"):
			# the first word to untie
			var w: String = _st.tied[clampi(int(h.back), 0, _st.tied.size() - 1)].word
			_say_now("FN_READ_BACK", [_st.written(w).to_upper()])
			if fx != null:
				fx.ring(_post_at(_st.post_of(w.substr(w.length() - 1))), _l("r") * 1.5, Art.GOLD)
		else:
			var hw: String = h.word
			_say_now("FN_READ", [hw.length(), hw.substr(0, 1).to_upper(), hw.substr(hw.length() - 1).to_upper()])
			if fx != null:
				fx.ring(_post_at(_st.post_of(hw.substr(0, 1))), _l("r") * 1.5, Art.GOLD)
		_cue("hint")
		moved.emit()
		_refresh_pill()
		return true
	var r: Dictionary = _reading
	_reading = {}
	if r.has("back"):
		while _st.tied.size() > int(r.back):
			var gone: Array = []
			for ch in String(_st.tied[-1].word):
				gone.append(_st.post_of(ch))
			_recoil.append({"posts": gone, "at": _t})
			_untie_word()
		_rate(false)
		r = _st.hint_word()
		if r.is_empty() or r.has("back"):
			_cue("undo")
			moved.emit()
			return true
	var word: String = r.word
	if not _st.string_word(word):
		# the fence moved on since the first press: read it again
		r = _st.hint_word()
		if r.is_empty() or r.has("back") or not _st.string_word(String(r.word)):
			return false
		word = r.word
	# laid again a post at a time, from the joint
	var posts: Array = _st.trail.duplicate()
	_st.trail.clear()
	if _st.base() > 0:
		_st.trail.append(posts[0])
	_trail_key = ""
	_sign_key = ""
	_stringing = true
	_cue("hint", 1.12)
	var from := _st.base()
	for k in range(from, posts.size()):
		var p: int = posts[k]
		_later(_t + (k - from + 1) * BULB_STEP, func() -> void:
			_st.trail.append(p)
			_seg_at = _t
			_trail_key = ""
			_sign_key = ""
			_cue("post", 0.94 + 0.04 * _st.trail.size()))
	_later(_t + (posts.size() - from + 1) * BULB_STEP + 0.12, func() -> void:
		_stringing = false
		_tie("bulb"))
	moved.emit()
	return true

# --- helpers ---

func _say_now(key: String, args: Array = []) -> void:
	_say = key
	_say_args = args
	_say_at = _t

func _later(at: float, fn: Callable) -> void:
	_due.append({"at": at, "fn": fn})

func _cue(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch, volume_db)

## The stars read again: a star lost falls with the lip.
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
	return not _due.is_empty() or _stringing

# --- the tutorial's hands ---

## The tutorial's finger tapping post `p` (the trail's end ties).
func demo_tap(p: int) -> void:
	if not _st.trail.is_empty() and _st.trail[-1] == p:
		_tie()
	else:
		_string(p)

func demo_tie() -> void:
	_tie()

func demo_hint() -> void:
	hints_extra += 1
	hint()

func state():
	return _st

## The middle of post `p` as laid.
func post_to_local(p: int) -> Vector2:
	return _post_at(p)

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
	var keep_r: Array = []
	for r: Dictionary in _recoil:
		if _t - float(r.at) < RECOIL_TIME:
			keep_r.append(r)
	_recoil = keep_r
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
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		var finger: int = event.index if event is InputEventScreenDrag else -1
		if _pressing == -2 or finger != _pressing:
			return
		if event is InputEventMouseMotion and _pressing != -1:
			return
		accept_event()
		_drag(event.position)

func _press(p: Vector2) -> void:
	_press_pos = p
	_finger = p
	_dragging = false
	_press_post = -1
	_press_end = false
	_press_sign = false
	_over = -1
	if is_done() or _L.is_empty() or _stringing:
		return
	var at := _post_under(p)
	if at >= 0:
		_press_post = at
		_over = at
		if not _st.trail.is_empty() and _st.trail[-1] == at:
			_press_end = true
		else:
			_string(at)
		return
	if (_L.sign as Rect2).grow(10.0 * _s()).has_point(p):
		_press_sign = true

func _drag(p: Vector2) -> void:
	_finger = p
	if not _dragging and p.distance_to(_press_pos) > TAP_SLOP * _s():
		_dragging = true
	if not _dragging or _press_sign or is_done() or _stringing:
		return
	var at := _post_under(p, DRAG_HIT_K)
	if at == _over:
		return
	_over = at
	if at < 0 or _st.trail.is_empty():
		return
	var n: int = _st.trail.size()
	if at == _st.trail[-1]:
		return
	# back over the post before: the last strand comes off
	if n >= 2 and at == _st.trail[n - 2] and n > _st.base():
		_unstring()
		return
	_string(at, true)

func _release(p: Vector2) -> void:
	_finger = p
	var was_drag := _dragging
	_dragging = false
	_over = -1
	if is_done() or _stringing:
		return
	if not was_drag and _press_end:
		_tie()
	elif not was_drag and _press_sign and (_L.sign as Rect2).grow(10.0 * _s()).has_point(p):
		if _st.trail.size() > _st.base():
			_tie()
	_press_end = false
	_press_sign = false

func _post_under(p: Vector2, k := HIT_K) -> int:
	if _L.is_empty():
		return -1
	var r := _l("r") * k
	var best := -1
	var near := INF
	for i in _st.posts.size():
		var d := p.distance_to(_post_at(i))
		if d < r and d < near:
			near = d
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
	if size.x <= 0.0 or size.y <= 0.0 or _st.posts.is_empty():
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	_bed_key = ""
	_posts_plain = []
	_posts_used = []
	_daisy = null
	_dirty()
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		_world.set_keep((_L.fence as Rect2).grow(_l("r") * 1.6))
	_refresh_pill()
	queue_redraw()

## The fence's corners for `sides` about the origin, radius 1: a flat top
## edge for the square, a point up for the triangle and the pentagon.
static func corners(sides: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var start := -PI * 0.5 - (PI / sides if sides % 2 == 0 else 0.0)
	for k in sides:
		var a := start + TAU * k / sides
		out.append(Vector2(cos(a), sin(a)))
	return out

## Where each post stands on a fence of `ring`'s corners: three a side,
## side by side clockwise from the top.
static func post_spots(ring: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ring.size()
	var along: Array = ALONG_TRI if n == 3 else ALONG
	for s in n:
		var a := ring[s]
		var c := ring[(s + 1) % n]
		for t in along:
			out.append(a.lerp(c, t))
	return out

## How tall the fence of `sides` stands against its width.
static func aspect(sides: int) -> float:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in corners(sides):
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return (hi.y - lo.y) / (hi.x - lo.x)

## The fence's corners and posts fitted in `box`, with room `pad` round.
static func fit(sides: int, box: Rect2, pad: float) -> Dictionary:
	var unit := corners(sides)
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in unit:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var room := box.size - Vector2.ONE * pad * 2.0
	var k := minf(room.x / (hi.x - lo.x), room.y / (hi.y - lo.y))
	var mid := (lo + hi) * 0.5
	var ring := PackedVector2Array()
	for p in unit:
		ring.append(box.get_center() + (p - mid) * k)
	return {"ring": ring, "posts": post_spots(ring), "k": k}

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 400.0 * u)
	var chrome := TAG_H * TAG_ROWS + TAG_GAP + SAY_H + SIGN.y + GAP * 2.0
	var below := COUNT_H + GAP * 0.5 if not (demo or _won) else 0.0
	if demo:
		# the page clips: room for the bottom posts' hops
		chrome = SAY_H * 0.2 + SIGN.y + GAP * 3.0
	# the fence takes what the rest leaves, up to its widest; a triangle
	# stands shorter than it is wide
	var tall := aspect(_st.sides)
	var fence_h := span / u - chrome - below
	var side := minf(FENCE_MAX, minf(fence_h / tall, (w / u) * 0.94))
	var k := 1.0
	if side < 420.0:
		# too little room: everything scales down
		k = maxf(0.4, span / u / (chrome + below + 420.0))
		side = 420.0
	var s := u * k
	var need := (chrome + below + side * tall) * s
	var y := top + maxf(0.0, (span - need) * (0.35 if not _won else 0.5))
	var mid := w * 0.5
	var tags := Rect2(0.0, y, w, 0.0)
	var say_y := 0.0
	if not demo:
		tags = Rect2(w * 0.03, y, w * 0.94, (TAG_H * TAG_ROWS + TAG_GAP) * s)
		y = tags.end.y
		say_y = y + SAY_H * 0.5 * s
		y += SAY_H * s
	else:
		y += SAY_H * 0.2 * s
		say_y = -1000.0
	var sign_sz := SIGN * s
	sign_sz.x = minf(sign_sz.x, w * 0.8)
	var sign := Rect2(mid - sign_sz.x * 0.5, y, sign_sz.x, sign_sz.y)
	y = sign.end.y + GAP * s
	var r := POST_K * minf(side, FENCE_MAX) * s
	var fence := Rect2(mid - side * s * 0.5, y, side * s, side * tall * s + r * 2.2 * (1.0 - tall))
	var f := fit(_st.sides, fence, r * 1.1)
	# posts no wider than their spacing allows (the pentagon's sides are
	# short): a third of the spacing between neighbours left clear
	var spots: PackedVector2Array = f.posts
	var near := INF
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			near = minf(near, spots[i].distance_to(spots[j]))
	if r > near * 0.34:
		r = near * 0.34
		f = fit(_st.sides, fence, r * 1.1)
	return {
		"u": u, "s": s, "top": top, "bottom": bottom,
		"tags": tags, "say_y": say_y, "sign": sign, "fence": fence,
		"ring": f.ring, "posts": f.posts, "r": r,
		"count_y": fence.end.y + (GAP * 0.5 + COUNT_H * 0.55) * s,
	}

## A layout value.
func _l(key: String) -> float:
	return float(_L.get(key, 0.0))

func _s() -> float:
	return float(_L.get("s", 1.0))

func _post_at(p: int) -> Vector2:
	if _L.is_empty() or p < 0:
		return Vector2.ZERO
	return (_L.posts as PackedVector2Array)[p]

## The way out of the fence at post `p` (unit).
func _out_of(p: int) -> Vector2:
	var c := (_L.fence as Rect2).get_center()
	var s: int = _st.side_of(p)
	var ring: PackedVector2Array = _L.ring
	var a := ring[s]
	var b := ring[(s + 1) % ring.size()]
	var n := (b - a).orthogonal().normalized()
	if n.dot(a - c) < 0.0:
		n = -n
	return n

# --- drawing ---

func _draw() -> void:
	_frame = []
	if _L.is_empty() or _st.posts.is_empty():
		return
	var e := _enter_e()
	if e <= 0.0:
		return
	var c := (_L.fence as Rect2).get_center()
	draw_set_transform(c * (1.0 - e), 0.0, Vector2.ONE * e)
	_draw_bed()
	_draw_tied()
	_draw_recoil()
	_draw_trail()
	_draw_gate()
	_draw_posts()
	_draw_bow()
	_draw_reading()
	draw_set_transform(Vector2.ZERO)
	_draw_sign()
	_draw_tags()
	_draw_say()
	_draw_count()

func _keep(m: ArrayMesh) -> ArrayMesh:
	_frame.append(m)
	return m

func _enter_e() -> float:
	if Motion.reduce:
		return 1.0
	var d := _t - _enter_at - Motion.ENTER_DELAY * 0.5
	if d < 0.0:
		return 0.0
	return Motion.pop_in_scale(d, Motion.POP_IN * 1.4).x if d < Motion.POP_IN * 1.4 else 1.0

## The bed and its rail: one mesh, rebuilt with the layout.
func _draw_bed() -> void:
	var key := str(_L.fence)
	if key != _bed_key or _bed == null:
		_bed_key = key
		var b := Face.Builder.new()
		Art.bed(b, _L.ring, _s())
		_bed = b.mesh()
	draw_mesh(_bed, null)

## The twine of the words tied: one mesh while they stand, a knot on each
## word's last post.
func _draw_tied() -> void:
	if _st.tied.is_empty():
		return
	var key := "%s:%s" % [str(_st.tied.size()), str(_L.fence)]
	for t: Dictionary in _st.tied:
		key += String(t.word)
	if key != _tied_key or _tied_mesh == null:
		_tied_key = key
		var b := Face.Builder.new()
		var wd := _l("r") * 0.16
		for t: Dictionary in _st.tied:
			var w: String = t.word
			# the day's theme word is a rose ribbon, a little wider, below
			if themed() and w == theme_word:
				continue
			for k in w.length() - 1:
				var a := _post_at(_st.post_of(w[k]))
				var z := _post_at(_st.post_of(w[k + 1]))
				Art.twine(b, a, z, wd + 2.0 * _s(), Art.TWINE_DEEP, _sag(a, z))
				Art.twine(b, a, z, wd, Art.TWINE, _sag(a, z))
		if theme_found():
			var w2 := theme_word
			for k in w2.length() - 1:
				var a := _post_at(_st.post_of(w2[k]))
				var z := _post_at(_st.post_of(w2[k + 1]))
				Art.twine(b, a, z, wd * 1.35 + 3.0 * _s(), Art.RIBBON_DEEP, _sag(a, z))
				Art.twine(b, a, z, wd * 1.35, Art.RIBBON, _sag(a, z))
		_tied_mesh = b.mesh()
	draw_mesh(_tied_mesh, null)

## The bow on the theme word's ribbon, at its first strand's middle:
## one cached mesh, popping in when the word is tied.
func _draw_bow() -> void:
	if not theme_found():
		return
	var a := _post_at(_st.post_of(theme_word[0]))
	var z := _post_at(_st.post_of(theme_word[1]))
	var at := (a + z) * 0.5 + (z - a).orthogonal().normalized() * _sag(a, z) * 0.5
	var key := "%s:%s" % [str(_L.fence), theme_word]
	if key != _bow_key or _bow_mesh == null:
		_bow_key = key
		var b := Face.Builder.new()
		var dir := (z - a).normalized()
		if dir.x < 0.0:
			dir = -dir
		Art.bow(b, Vector2.ZERO, _l("r") * 0.8, dir)
		_bow_mesh = b.mesh()
	var k := 1.0
	if not Motion.reduce and _t - _theme_at < BOW_TIME:
		k = Motion.pop_in_scale(maxf(0.0, _t - _theme_at), BOW_TIME).x
	if k <= 0.0:
		return
	var c := (_L.fence as Rect2).get_center()
	var e := _enter_e()
	draw_set_transform(c * (1.0 - e) + at * e, 0.0, Vector2.ONE * e * k)
	draw_mesh(_bow_mesh, null)
	draw_set_transform(c * (1.0 - e), 0.0, Vector2.ONE * e)

## A strand's sag: longer strands hang lower.
func _sag(a: Vector2, z: Vector2) -> float:
	return a.distance_to(z) * 0.035

## Untied twine recoiling back along its posts.
func _draw_recoil() -> void:
	if _recoil.is_empty():
		return
	var b := Face.Builder.new()
	var wd := _l("r") * 0.16
	for r: Dictionary in _recoil:
		var e := clampf((_t - float(r.at)) / RECOIL_TIME, 0.0, 1.0) if not Motion.reduce else 1.0
		var posts: Array = r.posts
		var n := posts.size() - 1
		if n <= 0:
			continue
		# what is left of the twine, from its start
		var left := clampf(float(n) * (1.0 - e * e), 0.0, float(n))
		for k in n:
			if left <= k:
				break
			var a := _post_at(posts[k])
			var z := _post_at(posts[k + 1])
			var f := clampf(left - k, 0.0, 1.0)
			z = a.lerp(z, f)
			Art.twine(b, a, z, wd, Color(Art.TWINE, 1.0 - e * 0.6), _sag(a, z))
	if b.verts.is_empty():
		return
	draw_mesh(_keep(b.mesh()), null)

## The trail: green twine post to post, gold while it spells a word the
## garden knows; its newest strand runs out to its post; while a finger
## drags, a strand from the last post to it.
func _draw_trail() -> void:
	var trail: Array = _st.trail
	var gold: bool = _st.trail.size() >= State.SHORTEST and _st.knows(_st.trail_word())
	var wd := _l("r") * 0.17
	var ink := Art.GOLD if gold else Art.STRING
	var n := trail.size()
	var growing := not Motion.reduce and _t - _seg_at < SEG_TIME and n >= 2
	var key := "%s:%s:%s:%s" % [str(trail), str(gold), str(growing), str(_L.fence)]
	if key != _trail_key or _trail_mesh == null:
		_trail_key = key
		var b := Face.Builder.new()
		var last := n - 1 if growing else n
		for k in last - 1:
			var a := _post_at(trail[k])
			var z := _post_at(trail[k + 1])
			Art.twine(b, a, z, wd + 2.0 * _s(), ink.darkened(0.3), _sag(a, z))
			Art.twine(b, a, z, wd, ink, _sag(a, z))
		_trail_mesh = b.mesh() if not b.verts.is_empty() else null
	if _trail_mesh != null:
		draw_mesh(_trail_mesh, null)
	if growing:
		var e := clampf((_t - _seg_at) / SEG_TIME, 0.0, 1.0)
		var a := _post_at(trail[n - 2])
		var z := a.lerp(_post_at(trail[n - 1]), Motion.back_out(e) if e < 1.0 else 1.0)
		var g := Face.Builder.new()
		Art.twine(g, a, z, wd + 2.0 * _s(), ink.darkened(0.3), _sag(a, z))
		Art.twine(g, a, z, wd, ink, _sag(a, z))
		draw_mesh(_keep(g.mesh()), null)
	if _dragging and n > 0 and _pressing != -2 and not _press_sign:
		var a := _post_at(trail[-1])
		if a.distance_to(_finger) > _l("r"):
			var g := Face.Builder.new()
			Art.twine(g, a, _finger, wd * 0.8, Color(ink, 0.6), 0.0)
			draw_mesh(_keep(g.mesh()), null)

## Insane's gate outside its post.
func _draw_gate() -> void:
	if _st.gate < 0:
		return
	var key := str(_L.fence)
	if key != _gate_key or _gate_mesh == null:
		_gate_key = key
		var b := Face.Builder.new()
		Art.gate(b, _post_at(_st.gate), _out_of(_st.gate), _l("r"))
		_gate_mesh = b.mesh()
	var bump := 1.0
	if _st.solved() and not Motion.reduce and _t - _won_at < Motion.BUMP_TIME and _t >= _won_at:
		bump = Motion.bump_scale(_t - _won_at, 0.08)
	var at := _post_at(_st.gate)
	draw_set_transform(at * (1.0 - bump), 0.0, Vector2.ONE * bump)
	draw_mesh(_gate_mesh, null)
	var c := (_L.fence as Rect2).get_center()
	var e := _enter_e()
	draw_set_transform(c * (1.0 - e), 0.0, Vector2.ONE * e)

## Every post where it stands (hopping, shivering), its cap's letter, its
## daisy once twine has touched it; the trail's posts ringed green, its end
## pulsing; posts the next letter cannot come from dimmed.
func _draw_posts() -> void:
	var n: int = _st.posts.size()
	var r := _l("r")
	if _posts_plain.size() != n:
		_posts_plain.resize(n)
		_posts_used.resize(n)
	if _daisy == null or absf(_daisy_r - r) > 0.5:
		_daisy_r = r
		var db := Face.Builder.new()
		Art.daisy(db, Vector2.ZERO, r * 0.42, 0.3)
		_daisy = db.mesh()
	var font: Font = CozyTheme.display(800)
	var used: int = _st.used()
	var trail: Array = _st.trail
	var end: int = trail[-1] if not trail.is_empty() else -1
	var dim_side: int = _st.side_of(end) if end >= 0 and not _st.solved() else -1
	var ring := Face.Builder.new()
	# under the entrance's scale about the fence's middle
	var fc := (_L.fence as Rect2).get_center()
	var fe := _enter_e()
	for i in n:
		var at := _post_at(i)
		if not Motion.reduce:
			var h := _t - _hop_at[i]
			if h >= 0.0 and h < Motion.SOLVE_TIME:
				at.y += Motion.hop_lift(h, Motion.SOLVE_HOP * 1.2 * _s(), Motion.SOLVE_TIME)
			var sh := _t - _shiver_at[i]
			if sh >= 0.0 and sh < SHIVER_TIME:
				at.x += sin(sh * 48.0) * 7.0 * _s() * (1.0 - sh / SHIVER_TIME)
		var is_used := used & (1 << i) != 0
		var m: ArrayMesh = _posts_used[i] if is_used else _posts_plain[i]
		if m == null:
			var b := Face.Builder.new()
			Art.post(b, r, i, is_used)
			m = b.mesh()
			if is_used:
				_posts_used[i] = m
			else:
				_posts_plain[i] = m
		draw_set_transform(fc * (1.0 - fe) + at * fe, 0.0, Vector2.ONE * fe)
		draw_mesh(m, null)
		if trail.has(i):
			ring.stroke(Face.Builder.ring(at, r * 0.86, r * 0.86), maxf(2.0, r * 0.1), Color(Art.STRING, 0.9), true)
		if i == end:
			var pulse := 0.55 + 0.45 * sin(_t * 5.0) if not Motion.reduce else 1.0
			ring.stroke(Face.Builder.ring(at, r * 1.12, r * 1.12), maxf(2.0, r * 0.08), Color(Art.STRING, 0.5 * pulse), true)
		# the letter
		var text: String = _st.posts[i].to_upper()
		var fs := roundi(r * LETTER_K)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ink := Art.INK
		if dim_side >= 0 and _st.side_of(i) == dim_side and i != end:
			ink = Art.INK_DIM
		draw_string(font, Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		# the daisy, opening when twine first touches the post
		if is_used:
			var be := 1.0
			if not Motion.reduce:
				var d := _t - _bloom_at[i]
				if d < 0.0:
					be = 0.0
				elif d < BLOOM_TIME:
					be = Motion.pop_in_scale(d, BLOOM_TIME).x
			if be > 0.0:
				var out := _out_of(i)
				var dat := out * r * 0.78 + out.orthogonal() * r * 0.62
				draw_set_transform(fc * (1.0 - fe) + (at + dat) * fe, 0.0, Vector2.ONE * be * fe)
				draw_mesh(_daisy, null)
		draw_set_transform(Vector2.ZERO)
	# the rings and the knot on top
	if _knot_at > -INF and not _st.tied.is_empty():
		var w: String = _st.tied[-1].word
		var kp := _post_at(_st.post_of(w.substr(w.length() - 1)))
		var ke := 1.0
		if not Motion.reduce and _t - _knot_at < Motion.POP_IN:
			ke = Motion.pop_in_scale(_t - _knot_at, Motion.POP_IN).x
		if ke > 0.0:
			var out := _out_of(_st.post_of(w.substr(w.length() - 1)))
			Art.knot(ring, kp - out * r * 0.95 + Vector2(0.0, 0.0), r * 0.17 * ke)
	if not ring.verts.is_empty():
		var c := (_L.fence as Rect2).get_center()
		var e := _enter_e()
		draw_set_transform(c * (1.0 - e), 0.0, Vector2.ONE * e)
		draw_mesh(_keep(ring.mesh()), null)

## The bulb's first press: gold rings, pulsing, round the posts named.
func _draw_reading() -> void:
	if _reading.is_empty():
		return
	var pulse := 0.6 + 0.4 * sin((_t - _reading_at) * 5.0) if not Motion.reduce else 1.0
	var r := _l("r")
	var b := Face.Builder.new()
	var marks: Array = []
	if _reading.has("word"):
		var w: String = _reading.word
		marks = [_st.post_of(w.substr(0, 1)), _st.post_of(w.substr(w.length() - 1))]
	elif not _st.tied.is_empty():
		var w2: String = _st.tied[-1].word
		marks = [_st.post_of(w2.substr(w2.length() - 1))]
	for p in marks:
		if p >= 0:
			b.stroke(Face.Builder.ring(_post_at(p), r * 1.2, r * 1.2), maxf(3.0, r * 0.12), Color(Art.GOLD, 0.95 * pulse), true)
	if not b.verts.is_empty():
		draw_mesh(_keep(b.mesh()), null)

## The sign over the fence: the word being strung chalked on it, gold when
## the garden knows it; empty, what to do.
func _draw_sign() -> void:
	var rect: Rect2 = _L.sign
	var hidden := themed() and not theme_found() and not _st.solved()
	var key := "%s:%s" % [str(rect), str(hidden)]
	if key != _sign_key or _sign_mesh == null:
		_sign_key = key
		var b := Face.Builder.new()
		Art.sign(b, rect)
		if hidden:
			# the day's word is in the fence: a seed packet hung by the
			# sign's left end, clear of the fence below
			var pw := rect.size.y * 0.56
			Art.packet(b, Vector2(rect.position.x - pw * 0.3, rect.position.y + rect.size.y * 0.16), pw)
		_sign_mesh = b.mesh()
	var at := Vector2.ZERO
	if not Motion.reduce:
		var sh := _t - _sign_shiver_at
		if sh >= 0.0 and sh < SHIVER_TIME:
			at.x = sin(sh * 48.0) * 8.0 * _s() * (1.0 - sh / SHIVER_TIME)
	var e := _enter_e()
	var c := rect.get_center()
	draw_set_transform(c * (1.0 - e) + at, 0.0, Vector2.ONE * e)
	draw_mesh(_sign_mesh, null)
	var font: Font = CozyTheme.display(800)
	var word: String = _st.trail_word()
	var text := word.to_upper()
	var ink := Color("fdf4dc")
	var fs := roundi(rect.size.y * SIGN_K)
	if word == "" or (_st.trail.size() == 1 and _st.base() == 1 and not demo):
		if _st.solved():
			text = tr("FN_SIGN_DONE")
		elif _st.tied.is_empty():
			text = tr("FN_SIGN_START")
		else:
			text = tr("FN_SIGN_NEXT") % _st.joint().to_upper()
		ink = Color(ink, 0.75)
		fs = roundi(rect.size.y * 0.32)
	elif _st.knows(word) and word.length() >= State.SHORTEST:
		ink = Color("ffe08a")
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var room := rect.size.x * 0.88
	if tw > room:
		fs = maxi(1, roundi(fs * room / tw))
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := c.y + font.get_ascent(fs) * 0.36
	draw_string_outline(font, Vector2(c.x - tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(8 * _s()), Color(Art.SIGN_DEEP, 0.9))
	draw_string(font, Vector2(c.x - tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_set_transform(Vector2.ZERO)

## The seed tags of the words tied, in rows from the top, the newest
## popping in; arrows between them read the chain.
func _draw_tags() -> void:
	if demo or _st.tied.is_empty():
		return
	var spots := _tag_spots()
	var font: Font = CozyTheme.display(800)
	var fs: int = spots.fs
	var rects: Array = spots.rects
	var key := "%s:%d" % [str(rects), _st.tied.size()]
	for t: Dictionary in _st.tied:
		key += String(t.kind) + String(t.word)
	if key != _tags_key or _tags_mesh == null:
		_tags_key = key
		var b := Face.Builder.new()
		for k in rects.size():
			Art.tag(b, rects[k], String(_st.tied[k].kind) == "bulb", _is_theme(k))
		_tags_mesh = b.mesh()
	var newest := _tag_at[-1] if not _tag_at.is_empty() else -INF
	var popping := not Motion.reduce and _t - newest < Motion.POP_IN
	if not popping:
		draw_mesh(_tags_mesh, null)
	for k in rects.size():
		var rect: Rect2 = rects[k]
		var e := 1.0
		if popping and k == rects.size() - 1:
			e = Motion.pop_in_scale(_t - newest, Motion.POP_IN).x
			if e <= 0.0:
				continue
			var g := Face.Builder.new()
			Art.tag(g, rect, String(_st.tied[k].kind) == "bulb", _is_theme(k))
			draw_set_transform(rect.get_center() * (1.0 - e), 0.0, Vector2.ONE * e)
			draw_mesh(_keep(g.mesh()), null)
		elif popping:
			var g2 := Face.Builder.new()
			Art.tag(g2, rect, String(_st.tied[k].kind) == "bulb", _is_theme(k))
			draw_mesh(_keep(g2.mesh()), null)
		var text: String = _st.written(String(_st.tied[k].word)).to_upper()
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := rect.position.x + rect.size.y * 0.55 + (rect.size.x - rect.size.y * 0.55 - tw) * 0.5
		draw_string(font, Vector2(x, rect.get_center().y + font.get_ascent(fs) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)
		draw_set_transform(Vector2.ZERO)

func _is_theme(k: int) -> bool:
	return themed() and String(_st.tied[k].word) == theme_word

## The tags laid out: [Rect2] in reading order and their font size, shrunk
## until they fit the rows.
func _tag_spots() -> Dictionary:
	var area: Rect2 = _L.tags
	var font: Font = CozyTheme.display(800)
	var k := 1.0
	while true:
		var fs := roundi(TAG_FONT * _s() * k)
		var h := TAG_H * _s() * k
		var gap := TAG_GAP * _s() * k
		var rows: Array = [[]]
		var widths: Array = [0.0]
		var ok := true
		for t: Dictionary in _st.tied:
			var text: String = _st.written(String(t.word)).to_upper()
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + h * 0.55 + h * 0.5
			var row: int = rows.size() - 1
			if float(widths[row]) + w > area.size.x and not (rows[row] as Array).is_empty():
				rows.append([])
				widths.append(0.0)
				row += 1
			(rows[row] as Array).append(w)
			widths[row] = float(widths[row]) + w + gap
		if rows.size() * h + (rows.size() - 1) * gap > area.size.y + 0.5:
			ok = false
		if ok or k < 0.45:
			var rects: Array = []
			var y := area.position.y + maxf(0.0, (area.size.y - rows.size() * h - (rows.size() - 1) * gap) * 0.5)
			for r in rows.size():
				var row_w := float(widths[r]) - gap
				var x := area.get_center().x - row_w * 0.5
				for w2 in rows[r]:
					rects.append(Rect2(x, y, float(w2), h))
					x += float(w2) + gap
				y += h + gap
			return {"rects": rects, "fs": fs}
		k *= 0.88
	return {}

## What the board says, between the tags and the sign.
func _draw_say() -> void:
	if _say == "" or _t < _say_at or demo:
		return
	var font: Font = CozyTheme.display(800)
	var text := tr(_say)
	if not _say_args.is_empty():
		text = text % _say_args
	var good := _say in ["FN_SAY_TIED", "FN_SAY_TIED_NONE", "FN_SAY_OPEN", "FN_PERFECT", "FN_DONE", "FN_READ", "FN_SAY_THEME", "FN_SAY_THEME_HIDDEN"]
	var fs := roundi(SAY_SIZE * (1.1 if good else 1.0) * _s())
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > size.x * 0.94:
		fs = maxi(1, roundi(fs * size.x * 0.94 / tw))
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var e := _t - _say_at
	var pk := Motion.pop_in_scale(e, 0.25).x if e < 0.25 and not Motion.reduce else 1.0
	var fade := clampf((SAY_TIME - e) / 0.4, 0.0, 1.0)
	var ink := Art.GOLD_DEEP.darkened(0.3) if good else Pal.TEXT
	var asc := font.get_ascent(fs)
	draw_set_transform(Vector2(size.x * 0.5, _l("say_y")), 0.0, Vector2.ONE * pk)
	draw_string_outline(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(12 * _s()), Color(Pal.SURFACE, 0.92 * fade))
	draw_string(font, Vector2(-tw * 0.5, asc * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, fade))
	draw_set_transform(Vector2.ZERO)

## Under the fence: the posts still to bloom, or on Insane the gate.
func _draw_count() -> void:
	if demo or _won or is_done():
		return
	var font: Font = CozyTheme.display(700)
	var left: int = _st.posts_left()
	var text: String
	if left == 0 and _st.gate >= 0:
		text = tr("FN_COUNT_GATE") % _st.posts[_st.gate].to_upper()
	elif left == 1:
		text = tr("FN_COUNT_ONE")
	else:
		text = tr("FN_COUNT_N") % left
	if _st.gate >= 0 and left > 0:
		text += "  ·  " + tr("FN_COUNT_END") % _st.posts[_st.gate].to_upper()
	var cs := roundi(COUNT_SIZE * float(_L.u))
	var cw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	if cw > size.x * 0.94:
		cs = maxi(1, roundi(cs * size.x * 0.94 / cw))
		cw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	var at := Vector2(size.x * 0.5 - cw * 0.5, minf(_l("count_y"), size.y - _clear.y - 8.0))
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, roundi(10 * float(_L.u)), Color(Pal.SURFACE, 0.92))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Pal.TEXT)

## The pill in the tools row's gap: the stars the fence stands at, then the
## words tied against the par.
func _draw_pill() -> void:
	if not _bled or _won or _st.posts.is_empty():
		return
	var enter := 1.0 if Motion.reduce else Motion.pop_in_scale(_t - _enter_at - Motion.ENTER_DELAY).x
	if enter <= 0.0:
		return
	var font: Font = CozyTheme.body(700)
	var n: int = _st.tied.size()
	var text: String = (tr("FN_PILL_ONE") % _st.par) if n == 1 else (tr("FN_PILL_N") % [n, _st.par])
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
	return WIN_HOLD + _st.posts.size() * WAVE_STEP + (THEME_HOLD if theme_found() else 0.0)

func skill_quality() -> float:
	if _st.posts.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🌼 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var n: int = _st.tied.size()
	var line: String = tr("FN_WIN_ONE") if n == 1 else tr("FN_WIN_N") % n
	if n <= _st.par:
		line += " " + tr("FN_WIN_AT_PAR")
	else:
		line += " " + tr("FN_WIN_PAR_WAS") % _st.par
	if theme_found():
		line = tr("FN_WIN_THEME") % [_theme_shown(), line]
	elif themed():
		line = tr("FN_WIN_THEME_WAS") % [line, _theme_shown()]
	return {"faces": [], "subtitle": line}

func completion_record() -> Dictionary:
	var words: Array = []
	var kinds: Array = []
	for t: Dictionary in _st.tied:
		words.append(String(t.word))
		kinds.append(String(t.kind))
	return {"words": words, "kinds": kinds, "helped": _st.helped, "stars": _st.stars(),
		"posts": "".join(_st.posts), "theme": theme_word}

## A finished day reopens in bloom, its words as tied.
func restore_completed_board() -> void:
	# the fence the day was played on, should the theme's pool have come or
	# gone since (the deal reads the cached day): dealt again from the bank
	var was := String(completed_record.get("posts", ""))
	if was != "" and was != "".join(_st.posts):
		for e in InsaneBank.boards(State.BANKS[_band]):
			if e is Dictionary and String(e.get("posts", "")) == was:
				_st.load_day(e)
				break
	if completed_record.has("theme"):
		theme_word = String(completed_record.theme)
	var words: Array = completed_record.get("words", [])
	var kinds: Array = completed_record.get("kinds", [])
	_st.restart()
	for k in words.size():
		var w := String(words[k])
		if not _st.string_word(w):
			break
		_st.tie(String(kinds[k]) if k < kinds.size() else "hand")
	if not _st.solved():
		_st.finish()
	_st.trail.clear()
	_st.helped = int(completed_record.get("helped", 0))
	_fresh()
	_enter_at = -10.0
	_theme_at = -10.0
	queue_redraw()
