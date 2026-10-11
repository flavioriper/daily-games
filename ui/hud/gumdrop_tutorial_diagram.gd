extends Control

## Gumdrop's tutorial pages (arcade/gumdrop_screen.gd's `tutorial_pages`):
## the game itself, small, played by a hand that is written down. A page is
## a `Round` (the sim with a clock and a plan of what the hand does when)
## laid on a `Bench` (the screen without its chrome: the tray on the left,
## the card, the pots and the two buttons beside it). The pressed button,
## the picked pot's ring and the dropper are the screen's own drawing, so
## the page shows exactly what a finger does. The last two pages are rows
## of an icon and a line.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/gumdrop_sim.gd")
const Mould = preload("res://arcade/gumdrop_mould.gd")
const Boosters = preload("res://arcade/boosters.gd")

enum Lesson { FILL, SOAK, MATCH, MIX, BOOSTS, HUD }

var lesson: int = Lesson.FILL

var _bench: Bench
var _begun := false
## Seconds a lesson runs before it starts again, and where it is held
## under reduce motion.
var _length := 8.0
var _still_at := 2.0
var _rows_shown: ArrayMesh

## The sim with a clock and a hand: `plan` rows are [second, what, with],
## in order: "pick" a pot, "aim" at a point of the mould (the tip travels
## there), "squeeze" true or false, "serve".
class Round extends "res://arcade/gumdrop_sim.gd":
	const TRAVEL := 70.0

	var clock := 0.0
	var plan: Array = []
	var _next := 0
	var _goal := Vector2.ZERO

	func _init() -> void:
		super(1)

	## A round mould in two halves, wanted in these two flavours, with these
	## pots stood by it.
	func lay(want: Array, stood: Array) -> void:
		var m := Mould.build(Mould.Shape.ROUND, Mould.Cut.SECTORS, 2)
		m.want = want
		m.pots = stood
		m.mixed = -1
		deal(m)
		_goal = tip
		events.clear()

	## A cell already coloured this far toward the card's shade of a flavour.
	func filled(c: int, flavour: int, part: float) -> void:
		var pig: Vector3 = Mould.PIGMENT[flavour]
		var conc := part * C_FULL
		for i in N * N:
			if reg[i] == c:
				red[i] = conc * pig.x
				yel[i] = conc * pig.y
				blu[i] = conc * pig.z
		poured += conc * count[c]
		moving = true
		phase = Phase.PLAY
		measure()

	## Rows that squeeze `n` times from `from`, `on` seconds each with `off`
	## between. Returns the second the last one ends.
	func pulses(from: float, n: int, on: float, off: float) -> float:
		var at := from
		for k in n:
			plan.append([at, "squeeze", true])
			plan.append([at + on, "squeeze", false])
			at += on + off
		return at

	func step() -> void:
		clock += DT
		while _next < plan.size() and clock >= float(plan[_next][0]):
			var row: Array = plan[_next]
			_next += 1
			match String(row[1]):
				"pick":
					pick(int(row[2]))
				"aim":
					_goal = row[2]
				"squeeze":
					squeeze(bool(row[2]))
				"serve":
					serve()
		if tip.distance_to(_goal) > 0.01:
			aim(tip.move_toward(_goal, TRAVEL * DT))
		super()

## The screen without its chrome, laid out on a bench of its own size and
## scaled to the page.
class Bench extends "res://arcade/gumdrop_screen.gd":
	const BENCH := Vector2(1040.0, 640.0)

	var frozen := false

	## The rewards kept small: the words a lesson is about and nothing that
	## flies over the page.
	class Quiet extends "res://arcade/rewards.gd":
		func sticker(text: String, where: Vector2, fs: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "", rise := 0.0, keep := false) -> Dictionary:
			if id != "pct" and id != "word":
				return {}
			return super(text, where, mini(fs, 60), life, false, col, false, id, rise, keep)

		func spray(_from: Vector2, _col: Color, _n: int, _speed: float, _kind := "spark", _size := 1.0, _delay := 0.0, _to := Vector2.INF) -> void:
			pass

		func ring(_from: Vector2, _radius: float, _col: Color, _delay := 0.0, _life := 0.45) -> void:
			pass

		func rain(_seconds: float, _kinds: Array = ["confetti", "star"], _cols: Array = CONFETTI) -> void:
			pass

	func puzzle_id() -> String:
		return "gumdrop_tutorial"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = BENCH
		# the plates are read by the screen and never shown
		var plates := _build_hud()
		plates.visible = false
		add_child(plates)
		add_child(_build_field())
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.size = BENCH
		# the card is narrow here: the number alone, in its middle
		_need_l.visible = false
		_fx.buzzes = false
		_rw = Quiet.new()
		add_child(_rw)

	func _bands() -> Vector2:
		return Vector2.ZERO

	func _place() -> void:
		_tray = Rect2(24.0, 30.0, 580.0, 580.0)
		_u = _tray.size.x / Mould.SIDE
		_card = Rect2(642.0, 34.0, 370.0, CARD.y)
		_pot_at.clear()
		var n := _pots()
		for i in n:
			_pot_at.append(Vector2(827.0 + (i - (n - 1) * 0.5) * 124.0, 384.0))
		_squeeze_at = Vector2(896.0, 512.0)
		_serve_at = Vector2(712.0, 522.0)

	func _place_labels() -> void:
		super()
		_match_l.position.y += 20.0

	func _hand() -> void:
		pass

	func _process(delta: float) -> void:
		if not frozen:
			super(delta)

	func _hint(_text: String, _sub_text: String) -> void:
		pass

	func _run_over() -> void:
		pass

	func lay(game: RefCounted) -> void:
		sim = game
		frozen = false
		_acc = 0.0
		_bits.clear()
		_deal_at = -10.0
		_verdict_at = -10.0
		_slid = false
		_best = 0
		_beat_best = true
		_shown_score = sim.score
		_shown_level = -1
		_shown_match = -1
		_milestone = 1000000
		_tip = sim.tip
		_stale = true
		_rw.clear()
		_layout_field()

	## Runs the lesson to `at` and stops it there: the page under reduce
	## motion.
	func hold(at: float) -> void:
		while sim.clock < at:
			sim.step()
			_play_events()
		_tip = sim.tip
		_stale = true
		_animate(0.0)
		_refresh_hud()
		_redraw()
		frozen = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if _played():
		_bench = Bench.new()
		add_child(_bench)
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
	var k := minf(size.x / Bench.BENCH.x, size.y / Bench.BENCH.y)
	_bench.scale = Vector2(k, k)
	_bench.position = ((size - Bench.BENCH * k) * 0.5).round()
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

func _reset() -> void:
	if not _played() or not is_inside_tree() or size.x <= 0.0:
		return
	var game := Round.new()
	var F := Mould.Flavour
	match lesson:
		Lesson.FILL:
			# to the middle of one half, squeezed full a little at a time, then
			# the other pot and the other half
			game.lay([F.CHERRY, F.BLUEBERRY], [F.CHERRY, F.BLUEBERRY])
			game.aim(Vector2(50, 22))
			game._goal = game.tip
			game.plan = [[0.5, "aim", game.centre_of(0)]]
			var at := game.pulses(1.4, 5, 1.0, 0.45)
			game.plan.append([at, "pick", 1])
			game.plan.append([at + 0.3, "aim", game.centre_of(1)])
			at = game.pulses(at + 1.4, 5, 1.0, 0.45)
			_length = at + 1.6
			_still_at = 5.0
		Lesson.SOAK:
			# one long squeeze off the middle: the colour blooms as far as the
			# wall and no further, evens out once let go, and a second squeeze
			# makes it stronger
			game.lay([F.LEMON, F.BLUEBERRY], [F.LEMON, F.BLUEBERRY])
			var by: Vector2 = game.centre_of(0).lerp(game.centre_of(1), 0.3)
			game.plan = [[0.5, "aim", by], [1.4, "squeeze", true], [4.2, "squeeze", false],
				[7.4, "squeeze", true], [9.0, "squeeze", false]]
			_length = 12.0
			_still_at = 6.4
		Lesson.MATCH:
			# one half as the card has it, the other topped up, and served
			game.lay([F.LIME, F.ORANGE], [F.LIME, F.ORANGE])
			game.filled(0, F.LIME, 1.0)
			game.filled(1, F.ORANGE, 0.55)
			game.pick(1)
			game.plan = [[0.4, "aim", game.centre_of(1)]]
			var at := game.pulses(1.4, 2, 1.0, 0.5)
			game.plan.append([at + 0.6, "serve", null])
			_length = at + 0.6 + Sim.SETTLE_T + Sim.SHOW_T - 0.5
			_still_at = at + 0.6 + Sim.SETTLE_T + 0.8
		Lesson.MIX:
			# orange has no pot: half cherry, half lemon, in the same half
			game.lay([F.ORANGE, F.BLUEBERRY], [F.CHERRY, F.LEMON, F.BLUEBERRY])
			game.filled(1, F.BLUEBERRY, 1.0)
			game.plan = [[0.4, "aim", game.centre_of(0)]]
			var at := game.pulses(1.3, 3, 0.95, 0.4)
			game.plan.append([at, "pick", 1])
			at = game.pulses(at + 0.8, 3, 0.95, 0.4)
			_length = at + 3.0
			_still_at = at + 2.0
	_bench.lay(game)
	if Motion.reduce:
		_bench.hold(_still_at)

func _process(_delta: float) -> void:
	if not _played() or not _begun or Motion.reduce:
		return
	var game: Round = _bench.sim
	if game.clock >= _length:
		_reset()

# --- drawing ---

## The two pages that are rows of an icon and a line: the boosters and the
## bar's buttons.
func _draw() -> void:
	if _played() or size.x <= 0.0:
		return
	var rows: Array = []
	if lesson == Lesson.BOOSTS:
		rows = [
			[Boosters.icon("gd_soft"), tr("TUT_GUMDROP_BOOST_SOFT")],
			[Boosters.icon("gd_kind"), tr("TUT_GUMDROP_BOOST_KIND")],
			[Boosters.icon(Boosters.CHANCE), tr("TUT_GUMDROP_BOOST_CHANCE")],
		]
	else:
		rows = [
			["reset", tr("TUT_GUMDROP_HUD_RESET")],
			["gear", tr("TUT_GUMDROP_HUD_GEAR")],
			["help", tr("TUT_GUMDROP_HUD_HELP")],
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
			var tint: Color = Boosters.tint(Boosters.CHANCE if k == 2 else "gd_soft")
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
			Pal.SURFACE if boosts else Pal.TEXT, Color.TRANSPARENT if boosts else Pal.SURFACE)
		var line := String(rows[k][1])
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30)
		draw_multiline_string(font, Vector2(tx, c.y - lines.y * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30, -1, Pal.TEXT)
