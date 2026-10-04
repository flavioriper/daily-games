extends Control

## One page of Molehill's tutorial: a small lawn played by the game itself.
## The page holds a `Lawn` -- arcade/molehill_screen.gd with its top bar,
## cards, banners, lettering, sound and record taken out, so what is left is
## the three plates and one row of three real hills in the wooden frame --
## running a `Round`, the game's own sim with the dice taken out: a hand-made
## list of who comes up where, and a finger that whacks through the sim's own
## `whack`. So a mole pops and is knocked dizzy, a pot clangs and breaks, the
## rabbit costs its thirty, the streak steps to x2 on the plate and is lost
## to a mole let go, and the last ten seconds pay double, exactly as on the
## lawn. `lesson` picks the page (set before it enters the tree):
##
## - WHACK: tap a mole while it is up; a quick whack earns a little more.
## - CAST: the golden mole, and the flowerpot that takes two whacks.
## - RABBIT: the rabbit left alone goes home; whacked, it costs points.
## - STREAK: five in a row step the multiplier; a mole let go ends it.
## - FRENZY: the clock runs into its last ten seconds and a whack doubles.
## - BOOSTS: the two boosters and the Second chance, drawn as chips.
## - HUD: the top bar's Reset, gear and ?, drawn as they are (a whack is
##   never taken back, so no Undo).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/molehill_sim.gd")
const Boosters = preload("res://arcade/boosters.gd")

enum Lesson { WHACK, CAST, RABBIT, STREAK, FRENZY, BOOSTS, HUD }

## A tap's finger stays down this long, and sets out for the next this early.
const TAP_DOWN := 0.14
const REACH := 0.42
const FINGER_ALPHA := 0.16

var lesson: int = Lesson.WHACK

var _lawn: Lawn
var _over: Control
var _begun := false
## The lesson's cast, [second, hill, kind, seconds up], and its whacks,
## [second, hill]; where the round's clock starts, when the lesson starts
## over, and the second a still page stands at.
var _ups: Array = []
var _taps: Array = []
var _from := 0.0
var _length := 6.0
var _still_at := 0.0
var _finger_shown: ArrayMesh
var _rows_shown: ArrayMesh

## The game's sim with its dice taken out: nobody comes up but the lesson's
## cast, each on its second, and the lesson's whacks land on their own step.
class Round extends "res://arcade/molehill_sim.gd":
	var clock := 0.0
	var ups: Array = []
	var whacks: Array = []
	var on_tap := Callable()
	var up_next := 0
	var tap_next := 0

	func _spawn() -> void:
		clock += DT
		while up_next < ups.size() and clock >= float(ups[up_next][0]):
			var row: Array = ups[up_next]
			up_next += 1
			_pop(int(row[1]), int(row[2]), float(row[3]))
		while tap_next < whacks.size() and clock >= float(whacks[tap_next][0]):
			tap_next += 1
			on_tap.call(int(whacks[tap_next - 1][1]))

	## `kind` up out of hill `i` for `stay` seconds, as a spawn sends one.
	func _pop(i: int, kind: int, stay: float) -> void:
		var h: Dictionary = hills[i]
		h.kind = kind
		h.up = stay
		h.hp = 2 if kind == Kind.POT else 1
		h.hit_t = -1.0
		h.done = false
		_put(h, St.RISE)
		events.append({"type": "up", "hill": i, "kind": kind})

## The screen, quiet: the plates and the framed lawn alone, one row of hills,
## no top bar, sheet, card, banner or sticker, no sound (its id names no
## set), no knock, no record and no analytics.
class Lawn extends "res://arcade/molehill_screen.gd":
	const COLS_SHOWN := 3
	## A hill's width, where the row's holes are and how tall the field is,
	## in field units; the lawn left over above and below it, in pixels.
	const STEP := 100.0
	const MOUTH := 104.0
	const TALL := 132.0
	const PAD := 10.0
	const PLATES_GAP := 10.0

	var _plates: Control
	var _frame: PanelContainer

	## The rewards with no lettering: a page has no room for a sticker, but
	## for the multiplier's own, cut to the lawn's size.
	class Quiet extends "res://arcade/rewards.gd":
		func sticker(text: String, where: Vector2, fs: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "", rise := 0.0, keep := false) -> Dictionary:
			if id != "combo":
				return {}
			return super(text, where, mini(fs, 84), life, rainbow, col, rays, id, rise, keep)

	func puzzle_id() -> String:
		return "molehill_tutorial"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plates = _build_hud()
		_plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_plates)
		_frame = _build_frame()
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame)
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.buzzes = false
		_rw = Quiet.new()
		add_child(_rw)
		resized.connect(_fit)

	## The size the lawn takes in `room`: as wide as its row while its height
	## fits.
	static func size_for(room: Vector2) -> Vector2:
		var u := minf((room.x - 2.0 * FRAME) / (STEP * COLS_SHOWN),
			(room.y - HUD_H - PLATES_GAP - 2.0 * FRAME - 2.0 * PAD) / TALL)
		return Vector2(STEP * COLS_SHOWN * u + 2.0 * FRAME, HUD_H + PLATES_GAP + TALL * u + 2.0 * PAD + 2.0 * FRAME).floor()

	func _fit() -> void:
		_plates.position = Vector2.ZERO
		_plates.size = Vector2(size.x, HUD_H)
		_frame.position = Vector2(0, HUD_H + PLATES_GAP)
		_frame.size = Vector2(size.x, size.y - HUD_H - PLATES_GAP)
		# now, not on the frame's next sort: a lesson laid this frame is drawn
		# and thrown about in the field's pixels
		field.position = Vector2(FRAME, FRAME)
		field.size = _frame.size - Vector2(FRAME, FRAME) * 2.0

	func _hill_count() -> int:
		return COLS_SHOWN

	func _hill_pos(i: int) -> Vector2:
		return Vector2(STEP * (i + 0.5), MOUTH)

	func _field_units() -> Vector2:
		return Vector2(STEP * COLS_SHOWN, TALL)

	func _pause(_on: bool) -> void:
		pass

	func _show_banner(_text: String, _sub_text: String, _hold: float) -> void:
		pass

	func _time_up() -> void:
		pass

	## A round laid on the lawn, already playing: nothing left of the last.
	func lay(game: RefCounted) -> void:
		sim = game
		_acc = 0.0
		_paused = false
		_mallets.clear()
		_bursts.clear()
		_pops.clear()
		_impacts.clear()
		for i in _hit_at.size():
			_hit_at[i] = -10.0
		_shake = 0.0
		_shake_off = Vector2.ZERO
		_roll = 0.0
		_best = 0
		_beat_best = false
		_shown_score = -1
		_flurry = 0
		_last_whack = -10.0
		_heat = 0.0
		_flash = 0.0
		_milestone = 0
		_count_n = 0
		_rw.clear()

	## The round run to second `at` and held there, for a page that stands
	## still.
	func hold(at: float) -> void:
		while sim.clock < at:
			sim.step()
			_play_events()
			_clock += Sim.DT
			_animate(Sim.DT)
		_paused = true

	## The lesson's finger down on hill `i`: the mallet, through the sim.
	func whack_hill(i: int) -> void:
		swing(i, finger_at(i))

	## Where a finger lands on hill `i`, in field units.
	func finger_at(i: int) -> Vector2:
		return _hill_pos(i) + Vector2(0, -34.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if _played():
		_lawn = Lawn.new()
		add_child(_lawn)
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

func _played() -> bool:
	return lesson != Lesson.BOOSTS and lesson != Lesson.HUD

func _layout() -> void:
	if not _played():
		queue_redraw()
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# the frame's shadow falls under it
	var room := size - Vector2(0, 14.0)
	_lawn.size = Lawn.size_for(room)
	_lawn.position = ((room - _lawn.size) * 0.5).round()
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

## A lesson's cast and whacks. A whack lands late in a mole's time up unless
## the lesson is the quick one, so the numbers on the lawn are the plain ones.
## A still page stands a tenth of a second after its whack, the mallet still
## down and the number up, the white of the knock gone.
func _plan() -> void:
	var K := Sim.Kind
	_from = 0.0
	match lesson:
		Lesson.WHACK:
			# two plain whacks, then one the moment it is out: the quick bonus
			_ups = [[0.5, 1, K.MOLE, 1.6], [2.6, 0, K.MOLE, 1.6], [4.6, 2, K.MOLE, 1.6]]
			_taps = [[1.6, 1], [3.7, 0], [4.95, 2]]
			_length = 6.4
			_still_at = 1.7
		Lesson.CAST:
			_ups = [[0.4, 0, K.MOLE, 2.2], [0.7, 1, K.GOLD, 2.6], [1.0, 2, K.POT, 4.5]]
			_taps = [[1.7, 0], [2.6, 1], [3.5, 2], [4.2, 2]]
			_length = 6.0
			_still_at = 2.7
		Lesson.RABBIT:
			# two moles whacked beside a rabbit left to go home, then the
			# rabbit whacked
			_ups = [[0.4, 0, K.MOLE, 1.8], [0.6, 2, K.BUNNY, 2.4], [1.0, 1, K.MOLE, 1.6], [3.6, 1, K.BUNNY, 2.0]]
			_taps = [[1.3, 0], [2.0, 1], [4.6, 1]]
			_length = 6.4
			_still_at = 2.1
		Lesson.STREAK:
			# as many in a row as the first step asks and one more, then one
			# let go
			var n: int = Sim.STEPS[0] + 1
			_ups = []
			_taps = []
			for k in n:
				_ups.append([0.3 + 0.62 * k, k % Lawn.COLS_SHOWN, K.MOLE, 1.2])
				_taps.append([0.99 + 0.62 * k, k % Lawn.COLS_SHOWN])
			_ups.append([0.3 + 0.62 * n, n % Lawn.COLS_SHOWN, K.MOLE, 0.9])
			_length = 0.3 + 0.62 * n + 2.4
			_still_at = 0.99 + 0.62 * (n - 2) + 0.1
		Lesson.FRENZY:
			# two whacks before the last stretch and two in it
			_from = Sim.ROUND - Sim.FRENZY - 2.5
			_ups = [[0.3, 1, K.MOLE, 1.4], [1.3, 0, K.MOLE, 1.4], [2.7, 2, K.MOLE, 1.4], [3.7, 1, K.MOLE, 1.4]]
			_taps = [[1.1, 1], [2.1, 0], [3.5, 2], [4.5, 1]]
			_length = 6.0
			_still_at = 3.6

## The lesson from its top: a fresh round on the lawn, already under way.
func _reset() -> void:
	if not _played() or not is_inside_tree() or size.x <= 0.0:
		return
	_plan()
	var game := Round.new(1)
	game.events.clear()
	game.phase = Sim.Phase.PLAY
	game.phase_t = 1.0
	game.t = _from
	game.ups = _ups
	game.whacks = _taps
	game.on_tap = _lawn.whack_hill
	_lawn.lay(game)
	if Motion.reduce:
		_lawn.hold(_still_at)
	_over.queue_redraw()

func _process(_delta: float) -> void:
	if not _played() or not _begun or Motion.reduce:
		return
	_over.queue_redraw()
	if _lawn.sim.clock >= _length:
		_reset()

# --- drawing ---

## Where the finger is, in field units, and whether it is down: on the last
## whack's hill while it is pressed, then on its way to the next one's.
func _finger() -> Array:
	var game: Round = _lawn.sim
	var c := game.clock
	var k := game.tap_next
	var last := k - 1
	if last >= 0 and (c - float(_taps[last][0]) < TAP_DOWN or Motion.reduce):
		return [_lawn.finger_at(int(_taps[last][1])), true]
	if k >= _taps.size():
		return [_lawn.finger_at(int(_taps[last][1])), false] if last >= 0 else []
	var to: Vector2 = _lawn.finger_at(int(_taps[k][1]))
	if last < 0:
		return [to, false]
	var from: Vector2 = _lawn.finger_at(int(_taps[last][1]))
	var t1 := float(_taps[k][0])
	var t0 := maxf(float(_taps[last][0]) + TAP_DOWN, t1 - REACH)
	return [from.lerp(to, smoothstep(t0, t1, c)), false]

func _draw_finger() -> void:
	if _lawn.sim == null or _taps.is_empty():
		return
	var f := _finger()
	if f.is_empty():
		_finger_shown = null
		return
	var u: float = _lawn._u
	var down: bool = f[1]
	var field: Control = _lawn.field
	var at: Vector2 = _over.get_global_transform().affine_inverse() * (field.get_global_transform() * _lawn.px(f[0]))
	if not down:
		at += Vector2(0, -8.0 * u)
	var r := 15.0 * u * (0.85 if down else 1.0)
	var b := Face.Builder.new()
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 4.0, Color(Pal.TEXT, 0.55), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

## The chip pages: the boosters with what each does, and the top bar's
## buttons drawn as they are on the screen beside what they do here.
func _draw() -> void:
	if _played() or size.x <= 0.0:
		return
	var rows: Array = []
	if lesson == Lesson.BOOSTS:
		rows = [
			[Boosters.icon("mh_time"), tr("TUT_MOLEHILL_BOOST_TIME") % int(Boosters.MH_TIME)],
			[Boosters.icon("mh_steady"), tr("TUT_MOLEHILL_BOOST_STEADY") % Boosters.MH_FORGIVE],
			[Boosters.icon(Boosters.CHANCE), tr("TUT_MOLEHILL_BOOST_CHANCE") % int(Boosters.MH_CHANCE_TIME)],
		]
	else:
		rows = [
			["reset", tr("TUT_MOLEHILL_HUD_RESET")],
			["gear", tr("TUT_MOLEHILL_HUD_GEAR")],
			["help", tr("TUT_MOLEHILL_HUD_HELP")],
		]
	var boosts := lesson == Lesson.BOOSTS
	var row_h := size.y / rows.size()
	var chip := minf(104.0, row_h * 0.72)
	var x0 := 36.0
	var b := Face.Builder.new()
	var centres: Array = []
	for k in rows.size():
		var c := Vector2(x0 + chip * 0.5, row_h * (k + 0.5))
		centres.append(c)
		if boosts:
			# a booster is a disc in its game's colour, the Second chance gold
			var tint: Color = Boosters.tint(Boosters.CHANCE if k == 2 else "mh_time")
			b.disc(c + Vector2(0, 6.0), chip * 0.5, Color(Pal.TEXT, 0.16))
			b.disc(c, chip * 0.5, tint)
		else:
			var at := c - Vector2(chip, chip) * 0.5
			b.polygon(Face.Builder.round_rect(at + Vector2(0, 6.0), Vector2(chip, chip), 26.0), Color(Pal.TEXT, 0.16))
			b.polygon(Face.Builder.round_rect(at, Vector2(chip, chip), 26.0), Pal.SURFACE)
	_rows_shown = b.mesh()
	draw_mesh(_rows_shown, null)
	var font: Font = CozyTheme.display(700)
	var tx := x0 + chip + 28.0
	var wide := size.x - tx - 24.0
	for k in rows.size():
		var c: Vector2 = centres[k]
		Icons.paint(self, String(rows[k][0]), Rect2(c - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54),
			Pal.SURFACE if boosts else Pal.TEXT)
		var line := String(rows[k][1])
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30)
		draw_multiline_string(font, Vector2(tx, c.y - lines.y * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30, -1, Pal.TEXT)
