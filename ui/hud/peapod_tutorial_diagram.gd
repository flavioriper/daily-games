extends Control

## One page of Peapod's tutorial: a narrow slice of the garden played by the
## screen itself. The page holds a `Garden` -- peapod_screen.gd with its top
## bar, score row, banner, cards, sounds and endings taken out, so what is
## left is the sky over the chalk line, the cart on the grass and the gun's
## line under it -- running the game's own sim (arcade/peapod_sim.gd) on a
## small hand-made wave, and a finger sliding the cart through the screen's
## own grab and slide. So the pod never stops firing, a crate's number runs
## down, a gift's token falls and is caught, a pod's ring runs down on the
## grass, a firecracker takes its neighbours, a plate shot off knocks the
## millipede back, exactly as in a run. Beside the garden a page names what
## is in play with its own picture. `lesson` picks the page (set before it
## enters the tree):
##
## - SLIDE: the finger slides anywhere and the cart rolls, firing all the
##   while.
## - CRATES: a crate takes its number in peas, its paint is the number's
##   weight, and what reaches the chalk line ends the run.
## - GIFTS: a gift crate's token is caught, a rotten one is left to fall; a
##   different pair of gifts each time round.
## - PODS: the Fan, the Dart and the Berry in turn, their ring on the grass.
## - SPECIAL: the golden crate, the iron crate and the firecracker.
## - MILLI: plates shot off the millipede, then its head.
## - HUD: the top bar's Reset and settings, the two boosters and the Second
##   chance, each drawn as it is beside what it does.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/peapod_sim.gd")
const Art = preload("res://arcade/peapod_art.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")

enum Lesson { SLIDE, CRATES, GIFTS, PODS, SPECIAL, MILLI, HUD }

## The wooden rim round the garden, and the gap to what is said beside it.
const RIM := 8.0
const SIDE_GAP := 22.0
const FINGER_ALPHA := 0.16
## The finger's slide, times this, is the cart's (the screen's own).
const GAIN := 1.35
## The paint ladder beside the numbers' page: one number of each weight.
const LADDER := [1, 3, 9, 27, 81, 243]
const SEED := 7
## The HUD page's rows, and where their chips stand.
const HUD_ROWS := 5
const HUD_X := 30.0
## The millipede's head beside its page, in the art's units.
const HEAD_U := 2.6

var lesson: int = Lesson.SLIDE

var _art: Garden
var _over: Control
var _name: Label
var _line: Label
var _begun := false
var _plan := {}
## How many times the lesson has gone round: the gifts and the pods take
## turns.
var _round := 0
## Steps of the sim since the lesson began: its clock.
var _tick := 0
var _said := -1
var _icon: Array = []
## The finger: down or not, where it is in the garden's pixels, and where
## the cart was when it came down.
var _down := false
var _finger := Vector2.ZERO
var _from := 0.0
var _side := Rect2()
var _finger_shown: ArrayMesh
var _frame_shown: ArrayMesh
var _hud_shown: ArrayMesh
var _icon_shown: ArrayMesh
var _badges: Array = []

## The screen, quiet: only the garden is built, no top bar, score row,
## banner or cards; no sound (a puzzle id with no sounds), no knock, no
## record and no ending. The field is a slice: so much of the sky over the
## foot of the field, and a strip of grass under it for the finger.
class Garden extends "res://arcade/peapod_screen.gd":
	const VIEW := 270.0
	const FOOT := 34.0

	## Called before every step of the sim: the page's finger, on the sim's
	## own clock.
	var drive := Callable()
	var _still := false

	## The rewards with only the lettering a slice has room for, smaller.
	class Quiet extends "res://arcade/rewards.gd":
		const SAID := ["got", "boom", "gold", "head", "warn", "over"]

		func sticker(text: String, where: Vector2, fs: int, life: float, rainbow := true, col := Color.WHITE, _rays := false, id := "", rise := 0.0, keep := false) -> Dictionary:
			if not SAID.has(id):
				return {}
			return super(text, where, int(fs * 0.6), life, rainbow, col, false, id, rise * 0.6, keep)

		func rain(_seconds: float, _kinds: Array = [], _cols: Array = []) -> void:
			pass

	func puzzle_id() -> String:
		return "peapod_tutorial"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		field = Control.new()
		field.clip_contents = true
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		field.draw.connect(_draw_field)
		field.resized.connect(_layout_field)
		add_child(field)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_over.draw.connect(_draw_over)
		field.add_child(_over)
		_fx = Fx2D.new()
		_fx.buzzes = false
		field.add_child(_fx)
		_quiet = Fx2D.new()
		_quiet.buzzes = false
		field.add_child(_quiet)
		# the banner's box, which the layout places: never shown on a page
		var box := Control.new()
		box.visible = false
		field.add_child(box)
		_banner = Label.new()
		box.add_child(_banner)
		_banner.set_meta("box", box)
		_rw = Quiet.new()
		add_child(_rw)

	func _fit(s: Vector2) -> void:
		_u = s.y / (VIEW + FOOT)
		_origin = Vector2((s.x - Sim.W * _u) * 0.5, s.y - (Sim.H + FOOT) * _u)

	## A hand-made run: `s` is the sim, already in play.
	func lay(s: RefCounted) -> void:
		sim = s
		_still = false
		_acc = 0.0
		_hit_at.clear()
		_sparks.clear()
		_pops.clear()
		_shot_at = -10.0
		_last_x = sim.x
		_lean = 0.0
		_shake = 0.0
		_shake_off = Vector2.ZERO
		_heat = 0.0
		_alarm = 0.0
		_flash = 0.0
		_rw.clear()
		_redraw_all()

	## One step of the run: the finger, the sim, and what it said -- played
	## when `shown`, dropped on the way to a page that stands still.
	func beat(shown := true) -> void:
		if drive.is_valid():
			drive.call()
		sim.step()
		if shown:
			_play_events()
		else:
			sim.events.clear()

	## The run held where it is, for a page that stands still.
	func hold() -> void:
		_still = true
		_alarm = sim.danger()
		_redraw_all()

	func _process(delta: float) -> void:
		if sim == null or _still:
			return
		_clock += delta
		_acc += minf(delta, Sim.DT * MAX_STEPS)
		while _acc >= Sim.DT:
			_acc -= Sim.DT
			beat()
		_animate(delta)
		_redraw_all()

	## The run's own events, less the ones a page has no part of: the Ready
	## banner, the wave's, the clear. An ending is lettered and goes no
	## further (no record, no card).
	func _play_events() -> void:
		var keep: Array = []
		for ev: Dictionary in sim.events:
			match String(ev.type):
				"ready", "go", "wave", "clear", "revive":
					pass
				"over":
					_shake = maxf(_shake, 0.9)
					_flash_now(ALARM, 0.5)
					_rw.sticker(tr("FF_GAME_OVER"), _rw.at(field, field.size * Vector2(0.5, 0.36)), 84, 2.2, false, Color("fffaf0"), false, "over")
				_:
					keep.append(ev)
		sim.events = keep
		super()

	## The finger, in the field's pixels: the screen's own grab and slide.
	func press(at: Vector2) -> void:
		_grab(at)

	func slide(at: Vector2) -> void:
		_slide(at)

	func lift() -> void:
		sim.target_x = NAN

	func _keys() -> void:
		pass

	func _pause(_on: bool) -> void:
		pass

	func _refresh_hud(_delta := 0.0) -> void:
		pass

	func _game_over() -> void:
		pass

	## There is no score plate for a golden crate's stars to fly home to:
	## they leave by the top of the garden.
	func _plate_at(_l: Label) -> Vector2:
		return _rw.at(field, Vector2(field.size.x * 0.5, -20.0))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if lesson == Lesson.HUD:
		for id: String in ["pp_pea", "pp_quick", Boosters.CHANCE]:
			var badge := BoosterIcon.new(id, 76.0)
			add_child(badge)
			_badges.append(badge)
	else:
		_art = Garden.new()
		_art.drive = _drive
		add_child(_art)
		_name = Label.new()
		_name.theme_type_variation = "CardTitle"
		_line = Label.new()
		_line.theme_type_variation = "SheetBodyDim"
		# a narrow column: a size down, so a name is one line and a line four
		_name.add_theme_font_size_override("font_size", 36)
		_line.add_theme_font_size_override("font_size", 30)
		for l: Label in [_name, _line]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(l)
		_line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.z_index = 6
		_over.draw.connect(_draw_finger)
		add_child(_over)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	queue_redraw()
	if lesson == Lesson.HUD:
		for k in _badges.size():
			var badge: Control = _badges[k]
			badge.size = Vector2(_hud_chip(), _hud_chip())
			badge.position = Vector2(HUD_X, size.y / HUD_ROWS * (k + 2.5) - _hud_chip() * 0.5)
		return
	# The garden as tall as the page; the first page has nothing to name, so
	# its garden stands in the middle.
	var h := size.y - RIM * 2.0
	var w := Sim.W * h / (Garden.VIEW + Garden.FOOT)
	var alone: bool = lesson == Lesson.SLIDE
	var x0 := (size.x - w) * 0.5 if alone else RIM
	_art.position = Vector2(x0, RIM).round()
	_art.size = Vector2(w, h).round()
	var sx := x0 + w + RIM + SIDE_GAP
	_side = Rect2(sx, 0.0, maxf(0.0, size.x - sx - 8.0), size.y)
	_name.visible = not alone and lesson != Lesson.CRATES
	_line.visible = _name.visible
	_name.position = Vector2(_side.position.x, size.y * 0.36)
	_name.size = Vector2(_side.size.x, size.y * 0.14)
	_line.position = Vector2(_side.position.x, size.y * 0.52)
	_line.size = Vector2(_side.size.x, size.y * 0.46)
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))

## The gifts and the pods take turns, one a time round.
static func gift_a(turn: int) -> int:
	return [Sim.Kind.PEA, Sim.Kind.RATE, Sim.Kind.POWER][turn % 3]

static func gift_b(turn: int) -> int:
	return [Sim.Kind.TWIN, Sim.Kind.MAGNET, Sim.Kind.FROST, Sim.Kind.SHOVE][turn % 4]

static func pod_of(turn: int) -> int:
	return [Sim.Kind.FAN, Sim.Kind.PIERCE, Sim.Kind.BURST][turn % 3]

## What is said beside the garden of a gift or a pod: its token, the name the
## run letters when it is caught, and what it does.
static func _gift_word(kind: int) -> Dictionary:
	var line := ""
	match kind:
		Sim.Kind.PEA:
			line = _t("TUT_PEAPOD_G_PEA") % Sim.MAX_PEAS
		Sim.Kind.RATE:
			line = _t("TUT_PEAPOD_G_RATE")
		Sim.Kind.POWER:
			line = _t("TUT_PEAPOD_G_POWER")
		Sim.Kind.TWIN:
			line = _t("TUT_PEAPOD_G_TWIN") % int(Sim.TWIN_TIME)
		Sim.Kind.MAGNET:
			line = _t("TUT_PEAPOD_G_MAGNET") % int(Sim.MAGNET_TIME)
		Sim.Kind.FROST:
			line = _t("TUT_PEAPOD_G_FROST") % int(Sim.FROST_TIME)
		Sim.Kind.SHOVE:
			line = _t("TUT_PEAPOD_G_SHOVE")
		Sim.Kind.FAN:
			line = _t("TUT_PEAPOD_P_FAN")
		Sim.Kind.PIERCE:
			line = _t("TUT_PEAPOD_P_PIERCE") % Sim.PIERCES
		Sim.Kind.BURST:
			line = _t("TUT_PEAPOD_P_BURST")
		Sim.Kind.ROT:
			return {"icon": ["token", kind], "title": _t("TUT_PEAPOD_ROT"), "line": _t("TUT_PEAPOD_ROT_LINE")}
	var names := {Sim.Kind.PEA: "PP_GOT_PEA", Sim.Kind.RATE: "PP_GOT_RATE", Sim.Kind.POWER: "PP_GOT_POWER",
		Sim.Kind.TWIN: "PP_GOT_TWIN", Sim.Kind.FAN: "PP_GOT_FAN", Sim.Kind.PIERCE: "PP_GOT_PIERCE",
		Sim.Kind.BURST: "PP_GOT_BURST", Sim.Kind.MAGNET: "PP_GOT_MAGNET", Sim.Kind.FROST: "PP_GOT_FROST",
		Sim.Kind.SHOVE: "PP_GOT_SHOVE"}
	return {"icon": ["token", kind], "title": _t(names[kind]), "line": line}

## A run already in play, with nothing dealt.
static func fresh() -> RefCounted:
	var sim: RefCounted = Sim.new(SEED)
	sim.events.clear()
	sim.phase = Sim.Phase.PLAY
	sim.phase_t = 0.0
	sim.wave = 1
	return sim

## A wall laid by hand, lowest row first: null is a gap, a number a crate of
## it, [kind, number] any other.
static func _wall(sim: RefCounted, rows: Array, wall_y: float, speed: float) -> void:
	sim.rows.clear()
	for spec: Array in rows:
		var row: Array = []
		for c in spec:
			if c == null:
				row.append(null)
			elif c is Array:
				row.append(sim._cell(c[0], c[1]))
			else:
				row.append(sim._cell(Sim.Kind.CRATE, c))
		sim.rows.append(row)
	sim.wave_kind = Sim.Wave.WALL
	sim.wall_y = wall_y
	sim.wall_speed = speed

## A millipede laid by hand: its head `at` along the path and worth `head`,
## and a plate for each number behind it.
static func _milli(sim: RefCounted, head: int, plates: Array, at: float, speed: float) -> void:
	sim.segs.clear()
	var h: Dictionary = sim._cell(Sim.Kind.HEAD, head)
	h.s = at
	h.dying = -1.0
	sim.segs.append(h)
	for i in plates.size():
		var sg: Dictionary = sim._cell(Sim.Kind.CRATE, plates[i])
		sg.s = at - (i + 1) * Sim.SPACING
		sg.dying = -1.0
		sim.segs.append(sg)
	sim.wave_kind = Sim.Wave.MILLI
	sim.milli_n = plates.size()
	sim.milli_speed = speed

## A lesson: `lay` deals its wave into a fresh sim, the cart starts at `x`,
## the finger comes down at the first of `keys` ([time, where the cart is
## wanted]) and lifts at `up`, `says` ([time, what]) names what is in play,
## and it starts again after `length`. `still` is its telling moment, for a
## page that stands still.
static func plan(which: int, turn: int) -> Dictionary:
	var K := Sim.Kind
	match which:
		Lesson.SLIDE:
			return {"x": 150.0, "up": 7.5, "length": 8.3, "still": 3.6, "says": [],
				"keys": [[0.7, 150.0], [1.7, 150.0], [2.2, 30.0], [2.8, 30.0], [3.3, 90.0], [4.6, 90.0], [5.2, 210.0],
					[5.8, 210.0], [6.2, 270.0], [7.5, 270.0]],
				"lay": func(sim: RefCounted) -> void:
					_wall(sim, [[2, 3, null, 2, 3], [null, 3, 4, null, 2]], 262.0, 3.0)}
		Lesson.CRATES:
			return {"x": 30.0, "up": 7.9, "length": 10.2, "still": 7.0, "says": [],
				"keys": [[0.6, 30.0], [1.2, 30.0], [1.6, 90.0], [3.0, 90.0], [3.5, 210.0], [7.9, 210.0]],
				"lay": func(sim: RefCounted) -> void:
					_wall(sim, [[2, 6, null, 30, 12], [null, null, 90, null, null]], 286.0, 12.5)}
		Lesson.GIFTS:
			var a := gift_a(turn)
			var b := gift_b(turn)
			return {"x": 30.0, "up": 8.2, "length": 8.6, "still": 1.7,
				"says": [[0.0, _gift_word(a)], [3.2, _gift_word(K.ROT)], [4.0, _gift_word(b)]],
				"keys": [[0.6, 30.0], [2.7, 30.0], [3.1, 150.0], [3.5, 150.0], [3.9, 270.0], [8.2, 270.0]],
				"lay": func(sim: RefCounted) -> void:
					_wall(sim, [[[a, 2], null, [K.ROT, 1], null, [b, 2]], [null, 5, null, 6, null]], 262.0, 5.0)}
		Lesson.PODS:
			var pod := pod_of(turn)
			return {"x": 150.0, "up": 7.6, "length": 8.2, "still": 2.8, "says": [[0.0, _gift_word(pod)]],
				"keys": [[0.6, 150.0], [2.6, 150.0], [3.2, 120.0], [4.6, 120.0], [5.2, 180.0], [7.6, 180.0]],
				"lay": func(sim: RefCounted) -> void:
					_wall(sim, [[null, null, [pod, 1], null, null], [4, 5, 4, 5, 4], [6, 5, 6, 5, 6]], 262.0, 6.0)}
		Lesson.SPECIAL:
			return {"x": 210.0, "up": 6.4, "length": 7.0, "still": 3.0,
				"says": [[0.0, {"icon": ["crate", K.GOLD], "title": _t("TUT_PEAPOD_S_GOLD"), "line": _t("TUT_PEAPOD_S_GOLD_LINE") % Sim.GOLD_WORTH}],
					[1.9, {"icon": ["crate", K.IRON], "title": _t("TUT_PEAPOD_S_IRON"), "line": _t("TUT_PEAPOD_S_IRON_LINE")}],
					[4.1, {"icon": ["crate", K.BOMB], "title": _t("TUT_PEAPOD_S_BOMB"), "line": _t("TUT_PEAPOD_S_BOMB_LINE")}]],
				"keys": [[0.6, 210.0], [1.9, 210.0], [2.4, 270.0], [4.1, 270.0], [4.9, 90.0], [6.4, 90.0]],
				"lay": func(sim: RefCounted) -> void:
					# a pea worth three, so the iron crate's one a pea shows
					sim.power = 3
					_wall(sim, [[6, [K.BOMB, 3], 6, null, [K.IRON, 6]], [5, 8, 5, [K.GOLD, 18], null]], 262.0, 3.0)}
		_:
			return {"x": 245.0, "up": 6.4, "length": 7.4, "still": 2.2,
				"says": [[0.0, {"icon": ["plate", K.CRATE], "title": _t("TUT_PEAPOD_M_PLATE"), "line": _t("TUT_PEAPOD_M_PLATE_LINE")}],
					[3.3, {"icon": ["head", 0], "title": _t("TUT_PEAPOD_M_HEAD"), "line": _t("TUT_PEAPOD_M_HEAD_LINE")}]],
				"keys": [[0.5, 245.0], [3.1, 245.0], [3.8, 95.0], [4.3, 70.0], [4.8, 45.0], [5.2, 32.0], [6.4, 32.0]],
				"lay": func(sim: RefCounted) -> void:
					sim.peas = 2
					_milli(sim, 20, [6, 6, 6, 6, 6, 6], 1580.0, 34.0)}

## Where `keys` want the cart at `t`: eased from one to the next.
static func cart_at(keys: Array, t: float) -> float:
	for i in range(keys.size() - 1, -1, -1):
		if t >= float(keys[i][0]):
			if i == keys.size() - 1:
				return float(keys[i][1])
			var k := (t - float(keys[i][0])) / maxf(0.001, float(keys[i + 1][0]) - float(keys[i][0]))
			return lerpf(float(keys[i][1]), float(keys[i + 1][1]), smoothstep(0.0, 1.0, k))
	return float(keys[0][1])

## The lesson from its top: its wave dealt, the finger up.
func _reset() -> void:
	if lesson == Lesson.HUD or not is_inside_tree() or size.x <= 0.0:
		return
	_plan = plan(lesson, _round)
	_tick = 0
	_said = -1
	_down = false
	var sim := fresh()
	sim.x = float(_plan.x)
	_plan.lay.call(sim)
	_art.lay(sim)
	_finger = _art.px(Vector2(sim.x, Sim.H + Garden.FOOT * 0.5))
	_speak(0.0)
	if Motion.reduce:
		# standing still: the lesson run to its telling moment, unseen
		for i in int(float(_plan.still) / Sim.DT):
			_art.beat(false)
		_art.hold()
	_over.queue_redraw()

func _process(_delta: float) -> void:
	if lesson == Lesson.HUD or not _begun or Motion.reduce:
		return
	if _tick * Sim.DT >= float(_plan.length):
		_round += 1
		_reset()
	_over.queue_redraw()

## Before each step of the sim: what is named beside the garden, and the
## finger -- down at the first key, slid so the cart is where the keys want
## it (the cart goes GAIN times as far as the finger, so the finger goes that
## much less), up at the lesson's `up`.
func _drive() -> void:
	var t := _tick * Sim.DT
	_tick += 1
	var sim: RefCounted = _art.sim
	_speak(t)
	# a cleared sky stays clear: no wave is dealt on a page
	if sim.gap_t > 0.0:
		sim.gap_t = Sim.GAP_TIME
	var keys: Array = _plan.keys
	if t < float(keys[0][0]) or t >= float(_plan.up):
		if _down:
			_down = false
			_art.lift()
		return
	if not _down:
		_down = true
		_from = sim.x
		_finger = _art.px(Vector2(sim.x, Sim.H + Garden.FOOT * 0.5))
		_art.press(_finger)
	_finger.x = _art.px(Vector2(_from + (cart_at(keys, t) - _from) / GAIN, 0.0)).x
	_art.slide(_finger)

## What the lesson names at `t`.
func _speak(t: float) -> void:
	var says: Array = _plan.says
	while _said + 1 < says.size() and t >= float(says[_said + 1][0]):
		_said += 1
		var word: Dictionary = says[_said][1]
		_icon = word.icon
		_name.text = word.title
		_line.text = word.line
		queue_redraw()

# --- drawing ---

func _draw_finger() -> void:
	if _art == null or _art.sim == null:
		_finger_shown = null
		return
	var u: float = _art._u
	var at := _art.position + _finger + (Vector2.ZERO if _down else Vector2(0, -5.0 * u))
	var r := 15.0 * u * (0.85 if _down else 1.0)
	var b := Face.Builder.new()
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.8 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.5), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

func _draw() -> void:
	if size.x <= 0.0:
		return
	if lesson == Lesson.HUD:
		_draw_hud()
		return
	if _art == null or _art.size.x <= 0.0:
		return
	# the Arcade's wooden frame round the garden
	var b := Face.Builder.new()
	var at := _art.position - Vector2(RIM, RIM)
	var s := _art.size + Vector2(RIM, RIM) * 2.0
	b.fan(Face.Builder.round_rect(at, s, 18.0), Color("9c6b45"))
	b.fan(Face.Builder.round_rect(at + Vector2(3, 3), s - Vector2(6, 6), 15.0), Color("6e4a2f"))
	_frame_shown = b.mesh()
	draw_mesh(_frame_shown, null)
	if lesson == Lesson.CRATES:
		_draw_ladder()
	elif not _icon.is_empty():
		_draw_icon(Vector2(_side.get_center().x, size.y * 0.2))

## What is named, drawn with the garden's own picture of it.
func _draw_icon(c: Vector2) -> void:
	var kind := int(_icon[1])
	match String(_icon[0]):
		"token":
			draw_mesh(Art.token(kind, 4.0), null, Transform2D(0.0, c))
		"crate":
			draw_mesh(Art.crate(kind, 0, 2.2), null, Transform2D(0.0, c))
		"plate":
			draw_mesh(Art.plate(kind, 1, 3.4), null, Transform2D(0.0, c))
		"head":
			draw_mesh(Art.head(HEAD_U), null, Transform2D(0.0, c))
			# the pupils, which the garden lays itself (they watch the cart)
			var r := Sim.HEAD_R * HEAD_U
			var b := Face.Builder.new()
			for side in [-1.0, 1.0]:
				b.disc(c + Vector2(r * 0.36, side * r * 0.4 - HEAD_U) + Vector2(0.0, r * 0.12), r * 0.15, Art.FEELER)
			_icon_shown = b.mesh()
			draw_mesh(_icon_shown, null)

## A crate of each paint, lightest at the top, with the least number that
## wears it.
func _draw_ladder() -> void:
	var n := LADDER.size()
	var step := size.y / n
	var u := minf(step / Sim.CELL_H, 2.0) * 0.92
	var font := Art.font()
	var x := _side.get_center().x
	for k in n:
		var c := Vector2(x, step * (k + 0.5))
		draw_mesh(Art.crate(Sim.Kind.CRATE, Art.tier_of(LADDER[k]), u), null, Transform2D(0.0, c))
	for k in n:
		Art.number(self, font, Vector2(x, step * (k + 0.5) - 2.2 * u), LADDER[k], (Sim.CELL_H - 3.0) * u)

func _hud_chip() -> float:
	return minf(76.0, size.y / HUD_ROWS * 0.82)

## The HUD page: the top bar's Reset and settings, the two boosters and the
## Second chance (their badges are laid by `_layout`), each drawn as it is on
## the screen beside what it does.
func _draw_hud() -> void:
	var rows := [["reset", tr("TUT_PEAPOD_HUD_RESET")], ["gear", tr("TUT_PEAPOD_HUD_PAUSE")],
		["", "%s: %s" % [tr(Boosters.name_key("pp_pea")), tr(Boosters.line_key("pp_pea"))]],
		["", "%s: %s" % [tr(Boosters.name_key("pp_quick")), tr(Boosters.line_key("pp_quick"))]],
		["", "%s: %s" % [tr(Boosters.name_key(Boosters.CHANCE)), tr(Boosters.chance_key("peapod"))]]]
	var row_h := size.y / HUD_ROWS
	var chip := _hud_chip()
	var x0 := HUD_X
	var b := Face.Builder.new()
	for k in 2:
		var at := Vector2(x0, row_h * (k + 0.5) - chip * 0.5)
		b.polygon(Face.Builder.round_rect(at + Vector2(0, 5.0), Vector2(chip, chip), 22.0), Color(Pal.TEXT, 0.16))
		b.polygon(Face.Builder.round_rect(at, Vector2(chip, chip), 22.0), Pal.SURFACE)
	_hud_shown = b.mesh()
	draw_mesh(_hud_shown, null)
	var font: Font = CozyTheme.display(700)
	var fs := 28
	var tx := x0 + chip + 26.0
	var wide := size.x - tx - 20.0
	for k in rows.size():
		var cy := row_h * (k + 0.5)
		if k < 2:
			Icons.paint(self, String(rows[k][0]), Rect2(Vector2(x0 + chip * 0.5, cy) - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54), Pal.TEXT, Pal.SURFACE)
		var text := String(rows[k][1])
		var lines := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wide, fs)
		draw_multiline_string(font, Vector2(tx, cy - lines.y * 0.5 + fs * 0.82), text, HORIZONTAL_ALIGNMENT_LEFT, wide, fs, -1, Pal.TEXT)
