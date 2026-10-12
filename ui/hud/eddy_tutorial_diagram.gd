extends Control

## One page of Eddy's tutorial: a small pond played by the game itself.
## The page holds a `Pond` -- arcade/eddy_screen.gd with its top bar,
## plates, cards, lettering, sound and record taken out, so what is left is
## the framed pond and the pad beside it -- running a `Round`, the game's
## own sim with a hand added: it leans the pad toward one place after
## another, and the pad's knob is drawn where that hand holds it. So the
## whirlpool goes where the knob leans, a leaf its mouth comes over goes
## round and down as it goes, one a little wide of it is left turning until
## it is waited beside, and a duck sits where it is until the whirlpool has
## grown, exactly as in the pond. `lesson` picks the page
## (set before it enters the tree):
##
## - STEER: the whirlpool taken round a square, at a drift and then flat out.
## - SWEEP: flat out across three leaves, which go down as it goes; a
##   fourth lies wide of the way and is only tugged, until the whirlpool
##   comes back and waits beside it.
## - GROW: beside a duck too big for it; two leaves make the level, and the
##   duck goes down.
## - SPIN: the bar nearly empty; a leaf makes a level and gives some back,
##   then it runs out and the whirlpool unwinds.
## - SHOP: the five upgrades the bank of drops buys, drawn as chips.
## - HUD: the top bar's Reset, gear and ?, drawn as they are (nothing is
##   ever taken back, so no Undo).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/eddy_sim.gd")
const Upgrades = preload("res://arcade/eddy_upgrades.gd")
const Shop = preload("res://arcade/eddy_shop.gd")

enum Lesson { STEER, SWEEP, GROW, SPIN, SHOP, HUD }

var lesson: int = Lesson.STEER

var _pond: Pond
var _begun := false
## When the lesson starts over, and the second a still page stands at.
var _length := 8.0
var _still_at := 2.0
var _rows_shown: ArrayMesh

## The game's sim with a hand on the pad: `plan` is a row of steps, each
## [until (seconds), where (a place from the pond's middle, or null to let
## go), how far the knob is leaned at most].
class Round extends "res://arcade/eddy_sim.gd":
	var clock := 0.0
	var plan: Array = []

	func _init() -> void:
		super(4, 300.0, 300.0)
		things.clear()
		stocks = false
		events.clear()

	func mid() -> Vector2:
		return Vector2(w, h) * 0.5

	## A thing laid still, `from` the pond's middle.
	func lay(kind: int, from: Vector2, look := 0) -> void:
		var th := put(kind, mid() + from)
		th.drift = Vector2.ZERO
		th.look = look
		th.age = 10.0

	## Where the hand leans the pad just now. A step after a thing (its id)
	## is passed over once that thing has gone down.
	func hand() -> Vector2:
		for row: Array in plan:
			if clock >= float(row[0]) or row[1] == null:
				if clock < float(row[0]):
					return Vector2.ZERO
				continue
			var to := Vector2.ZERO
			if row[1] is int:
				var found := false
				for th: Dictionary in things:
					if int(th.id) == int(row[1]) and float(th.sink) < 0.0:
						to = th.pos
						found = true
				if not found:
					continue
			else:
				to = mid() + (row[1] as Vector2)
			var d: Vector2 = to - pos
			return d.normalized() * minf(float(row[2]), d.length() / 12.0)
		return Vector2.ZERO

	## Nothing left afloat, or the run over: the lesson has been told.
	func told() -> bool:
		return things.is_empty() or is_over()

	func step() -> void:
		clock += DT
		super()

## The screen, quiet: the framed pond and its pad alone, no top bar, plate,
## sheet, card or hint, no sound (its id names no set), no knock, no record
## and no analytics.
class Pond extends "res://arcade/eddy_screen.gd":
	## How much closer than the whole pond a page looks.
	const CLOSE := 2.0
	## The pad's strip beside the pond, as a part of the page's width.
	const PAD_PART := 0.3

	var _frame: PanelContainer

	## The rewards with no lettering but a level's and a toy's, cut to the
	## page, and nothing flown to a plate the page has not got.
	class Quiet extends "res://arcade/rewards.gd":
		func sticker(text: String, where: Vector2, fs: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "", rise := 0.0, keep := false) -> Dictionary:
			if id != "level" and id != "opens" and id != "too_big" and id != "low":
				return {}
			return super(text, where, mini(fs, 34), life, false, col, false, id, rise, keep)

		func spray(from: Vector2, col: Color, n: int, speed: float, kind := "spark", size := 1.0, delay := 0.0, to := Vector2.INF) -> void:
			if to == Vector2.INF:
				super(from, col, n, speed * 0.5, kind, size * 0.6, delay, to)

		func ring(_from: Vector2, _radius: float, _col: Color, _delay := 0.0, _life := 0.45) -> void:
			pass

	func puzzle_id() -> String:
		return "eddy_tutorial"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# the plates are read by the screen and never shown
		var plates := _build_hud()
		plates.visible = false
		add_child(plates)
		_frame = _build_frame()
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame)
		add_child(_build_pad())
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.buzzes = false
		_rw = Quiet.new()
		add_child(_rw)
		resized.connect(_fit)

	func _fit() -> void:
		var pad_w := floorf(size.x * PAD_PART)
		_frame.position = Vector2.ZERO
		_frame.size = Vector2(size.x - pad_w, size.y)
		# now, not on the frame's next sort: a lesson laid this frame is drawn
		# in the field's pixels
		field.position = Vector2(FRAME, FRAME)
		field.size = _frame.size - Vector2(FRAME, FRAME) * 2.0
		pad.position = Vector2(size.x - pad_w, 0.0)
		pad.size = Vector2(pad_w, size.y)

	func _bands() -> Vector2:
		return Vector2.ZERO

	func _turf() -> float:
		return 0.0

	## Nothing is laid out before a round is on the pond.
	func _layout_field() -> void:
		if sim != null:
			super()

	## The page looks at the middle of its small pond, CLOSE times nearer
	## than the whole of it, and the look never moves.
	func _across() -> float:
		return field.size.x / (minf(field.size.x / sim.w, field.size.y / sim.h) * CLOSE)

	func _follow() -> void:
		_cam = Vector2(sim.w, sim.h) * 0.5

	## The knob is where the round's hand holds it.
	func _lean() -> Vector2:
		return (sim as Round).hand() if sim.phase != Sim.Phase.DRAIN and sim.phase != Sim.Phase.OVER else Vector2.ZERO

	func _animate(delta: float) -> void:
		super(delta)
		var lean := _lean()
		_held = -3 if lean.length() > 0.0 else -1
		_knob = _knob.lerp(lean * TRAVEL, minf(1.0, delta * 14.0))

	## The pad is as big as its strip lets it be.
	func _draw_pad() -> void:
		super()

	func _pause(_on: bool) -> void:
		pass

	func _hint(_text: String, _sub_text: String) -> void:
		pass

	func _run_over() -> void:
		pass

	## A round laid on the pond: nothing left of the last.
	func lay(game: RefCounted) -> void:
		sim = game
		_acc = 0.0
		_paused = false
		_bits.clear()
		_knob = Vector2.ZERO
		_held = -1
		_pass_at = -10.0
		_level_at = -10.0
		_low_at = -10.0
		_best = 0
		_beat_best = false
		_shown_score = sim.score
		_shown_level = sim.level
		_milestone = 100000
		_core = sim.core()
		_rw.clear()
		_layout_field()

	## The round run to second `at` and held there, for a page that stands
	## still.
	func hold(at: float) -> void:
		while sim.clock < at and not sim.is_over():
			sim.steer(_lean())
			sim.step()
			_play_events()
			_clock += Sim.DT
			_animate(Sim.DT)
		_paused = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if _played():
		_pond = Pond.new()
		add_child(_pond)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _played() -> bool:
	return lesson != Lesson.SHOP and lesson != Lesson.HUD

func _layout() -> void:
	if not _played():
		queue_redraw()
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# the frame's shadow falls under it
	var room := size - Vector2(0, 14.0)
	_pond.size = Vector2(minf(room.x, room.y * 1.75), room.y).floor()
	_pond.position = ((room - _pond.size) * 0.5).round()
	_pond._fit()
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

## The lesson from its top: a fresh round on the pond.
func _reset() -> void:
	if not _played() or not is_inside_tree() or size.x <= 0.0:
		return
	var game := Round.new()
	match lesson:
		Lesson.STEER:
			# round a square at a drift, then again in a hurry
			for row: Array in [[Sim.Kind.LEAF, Vector2(-44, -30), 0], [Sim.Kind.PETAL, Vector2(46, 28), 2], [Sim.Kind.LEAF, Vector2(44, -32), 1]]:
				game.lay(row[0], row[1], row[2])
			game.plan = [[0.6, null, 0.0], [3.2, Vector2(20, 0), 0.4], [5.0, Vector2(20, 14), 0.4], [9.4, Vector2(-20, 14), 0.4],
				[10.2, null, 0.0], [11.8, Vector2(-20, -12), 1.0], [13.8, Vector2(18, -12), 1.0], [15.0, Vector2(0, 0), 1.0], [16.0, null, 0.0]]
			_length = 16.2
			_still_at = 4.0
		Lesson.SWEEP:
			# flat out across three leaves, then back to wait beside the one
			# that lay wide of the way
			for k in 3:
				game.lay(Sim.Kind.LEAF, Vector2(-16.0 + 20.0 * k, -7.0 if k % 2 == 0 else -13.0), k)
			game.lay(Sim.Kind.LEAF, Vector2(4.0, 13.0), 1)
			game.pos = game.mid() + Vector2(-46, -10)
			var wide: int = game.things[3].id
			game.plan = [[0.7, null, 0.0], [5.4, Vector2(56, -10), 1.0], [6.4, null, 0.0], [16.0, wide, 0.3]]
			_length = 16.0
			_still_at = 2.6
		Lesson.GROW:
			# beside a duck too big for it, then two leaves for the level, then
			# the duck again (the things are numbered as they are laid)
			game.level = Sim.level_for(Sim.Kind.DUCK) - 1
			game.grown = game.need() - 2
			game.lay(Sim.Kind.DUCK, Vector2(34, -8))
			game.lay(Sim.Kind.LEAF, Vector2(-48, 26), 1)
			game.lay(Sim.Kind.LEAF, Vector2(-54, -26), 0)
			game.pos = game.mid() + Vector2(-6, -8)
			var first: int = game.things[0].id
			game.plan = [[0.5, null, 0.0], [3.4, first, 0.25], [11.0, first + 1, 0.6], [19.0, first + 2, 0.6], [32.0, first, 0.5]]
			_length = 32.0
			_still_at = 2.8
		Lesson.SPIN:
			# a short spin nearly out: one leaf makes the level and gives some
			# back, and then it runs out
			game.level = 2
			game.grown = game.need() - 1
			game.spin_full = 14.0
			game.spin = 4.6
			game.lay(Sim.Kind.LEAF, Vector2(12, 4), 2)
			game.lay(Sim.Kind.PETAL, Vector2(-44, -28), 0)
			game.lay(Sim.Kind.ACORN, Vector2(-40, 34), 0)
			var leaf: int = game.things[0].id
			game.plan = [[0.5, null, 0.0], [4.0, leaf, 0.3], [5.0, null, 0.0], [20.0, Vector2(0, 0), 0.2]]
			_length = 16.0
			_still_at = 1.2
	game.steer(Vector2.RIGHT * 0.01)
	game.steer(Vector2.ZERO)
	game.events.clear()
	_pond.lay(game)
	if Motion.reduce:
		_pond.hold(_still_at)

func _process(_delta: float) -> void:
	if not _played() or not _begun or Motion.reduce:
		return
	var game: Round = _pond.sim
	if game.clock >= _length:
		_reset()
	elif lesson != Lesson.STEER and game.told():
		# a breath after the last thing is down, or the whirlpool unwound
		_length = minf(_length, game.clock + 1.6)

# --- drawing ---

## The chip pages: the shop's upgrades with what each does, and the top bar's
## buttons drawn as they are on the screen beside what they do here.
func _draw() -> void:
	if _played() or size.x <= 0.0:
		return
	var rows: Array = []
	if lesson == Lesson.SHOP:
		for id: String in Upgrades.IDS:
			rows.append([String(Upgrades.ICON[id]), tr("TUT_EDDY_UP_" + id.to_upper())])
	else:
		rows = [
			["reset", tr("TUT_EDDY_HUD_RESET")],
			["gear", tr("TUT_EDDY_HUD_GEAR")],
			["help", tr("TUT_EDDY_HUD_HELP")],
		]
	var boosts := lesson == Lesson.SHOP
	var row_h := size.y / rows.size()
	var chip := minf(104.0, row_h * 0.72)
	var x0 := 36.0
	var b := Face.Builder.new()
	var centres: Array = []
	for k in rows.size():
		var c := Vector2(x0 + chip * 0.5, row_h * (k + 0.5))
		centres.append(c)
		if boosts:
			# an upgrade is a disc in the pond's colour, as in the shop
			b.disc(c + Vector2(0, 6.0), chip * 0.5, Color(Pal.TEXT, 0.16))
			b.disc(c, chip * 0.5, Shop.TINT)
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
			Pal.SURFACE if boosts else Pal.TEXT, Color.TRANSPARENT if boosts else Pal.SURFACE)
		var line := String(rows[k][1])
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30)
		draw_multiline_string(font, Vector2(tx, c.y - lines.y * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30, -1, Pal.TEXT)
