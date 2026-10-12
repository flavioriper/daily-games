extends Control

## One page of Furrow's tutorial: a small field played by the game itself.
## The page holds the game's own field (arcade/furrow_field.gd) on a sim of
## eight plots (arcade/furrow_sim.gd), never saved, and a finger that goes
## from place to place along the page's script and presses as a player's
## would: what it touches is picked, sown or bought by the same calls the
## screen makes. `lesson` picks the page (set before it enters the tree):
##
## - PICK: three ripe radishes picked one by one, each lot left bare, and a
##   touch on one still growing, which only nods.
## - CHAIN: the whole field ripe and picked in one stroke, the sum lettered
##   as it grows.
## - AWAY: slow crops growing while the clock runs on, ripe and waiting,
##   then one stroke.
## - SOW: a packet taken in hand, a row of bare lots sown with it, the
##   packet put back.
## - BUY: the next plot's signboard pressed twice, the seeds paid.
## - PENS: the two pens alone: a finger drawn through the coop gathers the
##   eggs, and a touch on the cow that shows her bottle milks her.
## - HUD: the shed, the gear and the ?, drawn as they are.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/furrow_sim.gd")
const Art = preload("res://arcade/furrow_art.gd")
const Field = preload("res://arcade/furrow_field.gd")
const Shop = preload("res://arcade/furrow_shop.gd")
const Screen = preload("res://arcade/furrow_screen.gd")

enum Lesson { PICK, CHAIN, AWAY, SOW, BUY, HUD, PENS }

## A finger's target that is not a plot: off the field, the next plot's
## sign, and PACKET + k the tray's packet k.
const REST := -1
const SIGN := 200
const PACKET := 100
## The coop's near side from its left to its right, and the first cow.
const COOP_A := 300
const COOP_B := 301
const COW := 310
const STRIP := 96.0
## Each lesson's script: [second, target, down from here on], and its length.
## A plot is named by its place as the land is read (the field's `place`):
## 0 to 2 the far row, 3 and 4 the middle, 5 to 7 the near one.
const SCRIPTS := {
	Lesson.PICK: [[0.0, REST, false], [0.8, 1, false], [1.0, 1, true], [1.2, 1, false], [2.2, 5, false], [2.4, 5, true], [2.7, 5, false],
		[3.6, 2, false], [3.8, 2, true], [4.0, 2, false], [5.0, 0, false], [5.2, 0, true], [5.4, 0, false], [6.2, REST, false]],
	Lesson.CHAIN: [[0.0, REST, false], [0.6, 0, false], [0.9, 0, true], [1.6, 2, true], [2.0, 4, true], [2.4, 3, true], [2.8, 5, true], [3.5, 7, true],
		[3.7, 7, false], [4.6, REST, false]],
	Lesson.AWAY: [[0.0, REST, false], [5.0, REST, false], [5.5, 0, false], [5.7, 0, true], [6.3, 2, true], [6.6, 4, true], [6.9, 3, true], [7.2, 5, true],
		[7.8, 7, true], [8.0, 7, false], [8.8, REST, false]],
	Lesson.SOW: [[0.0, REST, false], [0.8, PACKET + 1, false], [1.0, PACKET + 1, true], [1.2, PACKET + 1, false], [2.0, 0, false], [2.2, 0, true], [3.2, 2, true],
		[3.4, 2, false], [4.2, PACKET + 1, false], [4.4, PACKET + 1, true], [4.6, PACKET + 1, false], [5.4, REST, false]],
	Lesson.BUY: [[0.0, REST, false], [1.0, SIGN, false], [1.2, SIGN, true], [1.4, SIGN, false], [2.6, SIGN, false], [2.8, SIGN, true], [3.0, SIGN, false], [4.0, REST, false]],
	Lesson.PENS: [[0.0, REST, false], [0.8, COOP_A, false], [1.0, COOP_A, true], [2.4, COOP_B, true], [2.6, COOP_B, false], [3.5, COW, false], [3.7, COW, true], [3.9, COW, false],
		[5.0, REST, false]],
}
const LENGTHS := {Lesson.PICK: 7.4, Lesson.CHAIN: 6.6, Lesson.AWAY: 10.0, Lesson.SOW: 7.0, Lesson.BUY: 5.6, Lesson.PENS: 6.6}

var lesson: int = Lesson.PICK

var _field: Control
var _over_l: Control
var _sim: RefCounted
var _begun := false
var _t := 0.0
## How fast the page's field grows beside the clock.
var _speed := 1.0
var _down := false
var _last := -1
## The chain's sum as lettered, and when it last grew.
var _sum := 0
var _links := 0
var _sum_at := -10.0
var _hours := 0.0
var _rows_shown: ArrayMesh
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = CozyTheme.display(700)
	if _played():
		_field = Field.new()
		_field.playable = false
		_field.only_pens = lesson == Lesson.PENS
		_field.asked_plot.connect(func() -> void: _sim.buy_plot())
		add_child(_field)
		_over_l = Control.new()
		_over_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over_l.draw.connect(_draw_over)
		add_child(_over_l)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _played() -> bool:
	return lesson != Lesson.HUD

func _layout() -> void:
	if not _played():
		queue_redraw()
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_field.position = Vector2.ZERO
	_field.size = size
	_over_l.size = size
	var foot := STRIP if lesson == Lesson.SOW else 16.0
	_field.area = Rect2(24.0, 64.0, size.x - 48.0, size.y - 64.0 - foot)
	# what is picked flies to where the sum is lettered
	_field.fly_to = Vector2(size.x * 0.5, 40.0)
	if not _begun and is_inside_tree():
		_begun = true
		_reset()
	else:
		_field.layout()

# --- the lessons ---

## The lesson from its top: a fresh field of eight plots.
func _reset() -> void:
	_sim = Sim.new(9, 4, 2, 6 if lesson == Lesson.BUY else 8)
	_sim.crops = 3
	_t = 0.0
	_speed = 0.1
	_down = false
	_last = -1
	_sum = 0
	_links = 0
	_sum_at = -10.0
	_hours = 0.0
	# laid once so the places are known, and again once the plots are set
	_field.lay(_sim)
	for i in _sim.plots.size():
		var p: Dictionary = _sim.plots[_field.place(i)]
		match lesson:
			Lesson.PICK:
				p.t = _sim.grow_time(0) * (1.0 if i < 3 else 0.3 + 0.08 * i)
				p.ripe = i < 3
			Lesson.CHAIN:
				p.crop = [0, 1, 2, 1, 1, 2, 0, 2][i]
				p.t = _sim.grow_time(p.crop)
				p.ripe = true
			Lesson.AWAY:
				p.crop = 2
				p.t = 0.0
				_speed = _sim.grow_time(2) / 3.6
			Lesson.SOW:
				# the far row is bare, for the packet
				if i < 3:
					p.crop = Sim.BARE
				p.t = _sim.grow_time(0) * 0.6
			Lesson.BUY:
				p.t = _sim.grow_time(0) * (0.25 + 0.1 * i)
	if lesson == Lesson.BUY:
		_sim.seeds = 120
	if lesson == Lesson.PENS:
		_sim.coop = true
		_sim.hens = 3
		_sim.eggs = 4
		_sim.fence_t = Sim.FENCE_HOLDS
		_sim.pasture = true
		_sim.cows = [_sim.milk_time(), _sim.milk_time() * 0.3]
	_field.armed = -1
	_field.finger = Vector2(-1, -1)
	_field.lay(_sim)
	if Motion.reduce:
		# a still page: the field as the lesson leaves it
		if lesson == Lesson.AWAY:
			_sim.away(_sim.grow_time(2) + 1.0)
		_field.lay(_sim)
	if lesson == Lesson.PENS:
		# the eggs along the finger's way, the cows side by side
		_field.set_eggs([Vector2(-0.42, 0.36), Vector2(-0.14, 0.42), Vector2(0.16, 0.38), Vector2(0.44, 0.34)])
		_field.set_cows([Vector2(-0.3, 0.2), Vector2(0.32, 0.5)])

func _where(target: int) -> Vector2:
	if target == REST:
		return Vector2(size.x * 0.88, size.y + 40.0)
	if target == SIGN:
		var i: int = _sim.next_plot()
		return _field.bed_at(i) - Vector2(0, 30.0) if i >= 0 else _where(REST)
	if target == COOP_A or target == COOP_B:
		return _field.pen_point("coop", Vector2(-0.7 if target == COOP_A else 0.7, 0.36))
	if target == COW:
		return _field.cow_at(0)
	if target >= PACKET:
		return _packet_at(target - PACKET)
	return _field.plant_at(_field.place(target))

func _packet_at(k: int) -> Vector2:
	return Vector2(size.x * 0.5 + (k - 1) * 110.0, size.y - STRIP * 0.5)

func _process(delta: float) -> void:
	if not _played() or not _begun or Motion.reduce or _sim == null:
		return
	_t += delta
	if _t >= float(LENGTHS[lesson]):
		_reset()
		return
	_sim.step(delta * _speed)
	if lesson == Lesson.AWAY and _sim.ripe_count() < _sim.opened():
		_hours += delta * _speed
	_move_finger()
	for ev: Dictionary in _sim.events:
		_field.play(ev)
		match String(ev.type):
			"pick", "gather", "milk":
				_links = int(ev.n)
				_sum = _sim.chain_sum
				_sum_at = _t
			"chain_end":
				_sum_at = _t
	_sim.events.clear()
	_field.tick(delta)
	_over_l.queue_redraw()

## The finger along the script, pressing what it comes to as a player's would.
func _move_finger() -> void:
	var steps: Array = SCRIPTS[lesson]
	var a: Array = steps[0]
	var b: Array = steps[steps.size() - 1]
	for n in steps.size() - 1:
		if _t >= float(steps[n][0]) and _t < float(steps[n + 1][0]):
			a = steps[n]
			b = steps[n + 1]
			break
	if _t >= float(b[0]):
		a = b
	var long := maxf(0.001, float(b[0]) - float(a[0]))
	var k := clampf((_t - float(a[0])) / long, 0.0, 1.0)
	# a drag goes at an even pace, a move between presses eases
	var e := k if bool(a[2]) and bool(b[2]) else k * k * (3.0 - 2.0 * k)
	var at := _where(int(a[1])).lerp(_where(int(b[1])), e)
	var down := bool(a[2])
	_field.finger = at
	_field.finger_down = down
	var first := down and not _down
	_down = down
	if not down:
		_last = -1
		return
	if lesson == Lesson.PENS:
		_field.press(at, first)
		return
	if first and int(a[1]) >= PACKET and int(a[1]) < SIGN:
		var crop := int(a[1]) - PACKET
		_field.armed = -1 if _field.armed == crop else crop
		return
	var i: int = _field.plot_at(at)
	if i >= 0 and (first or i != _last):
		_last = i
		_field.poke(i, first)

# --- drawing ---

## Over the field: the chain's sum, the clock of the page that goes away,
## the seeds of the page that buys, and the packets of the page that sows.
func _draw_over() -> void:
	if _sim == null:
		return
	var c := _over_l
	match lesson:
		Lesson.PICK, Lesson.CHAIN, Lesson.AWAY, Lesson.PENS:
			if _links > 0 and _t - _sum_at < 2.4:
				var pop := 1.0 + 0.3 * maxf(0.0, 1.0 - (_t - _sum_at) / 0.2)
				var fs := int(40.0 * pop)
				var text := "+%d" % _sum if _links < 2 else "+%d  ×%d" % [_sum, _links]
				_lettered(c, text, Vector2(size.x * 0.5, 44.0), fs, Color("fff4c2"))
			if lesson == Lesson.AWAY:
				_lettered(c, Screen.span(_hours), Vector2(size.x - 90.0, 44.0), 30, Color("fffaf0"))
		Lesson.BUY:
			c.draw_mesh(Art.seed_icon(34.0), null, Transform2D(0.0, Vector2(40.0, 34.0)))
			_lettered(c, str(_sim.seeds), Vector2(96.0, 46.0), 34, Color("fffaf0"))
		Lesson.SOW:
			var b := Face.Builder.new()
			b.fan(Face.Builder.round_rect(Vector2(size.x * 0.5 - 190.0, size.y - STRIP + 4.0), Vector2(380.0, STRIP - 8.0), 26.0), Color("fcf7ef"))
			if _field.armed >= 0:
				var held := _packet_at(_field.armed)
				b.fan(Face.Builder.round_rect(held - Vector2(41, 41), Vector2(82, 82), 20.0), Pal.SUN)
			_rows_shown = b.mesh()
			c.draw_mesh(_rows_shown, null)
			for k in 3:
				c.draw_mesh(Art.packet(k, 70.0), null, Transform2D(0.0, _packet_at(k)))
			# the finger is the field's, and the strip lies over it: once more here
			if _field.finger.x >= 0.0 and _field.finger.y > size.y - STRIP:
				c.draw_circle(_field.finger, 26.0 if _field.finger_down else 30.0, Color(1, 1, 1, 0.5), true, -1.0, true)
				c.draw_circle(_field.finger, 26.0 if _field.finger_down else 30.0, Color(Art.INK, 0.5), false, 4.0, true)

func _lettered(c: Control, text: String, mid: Vector2, fs: int, col: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(mid.x - w * 0.5, mid.y + fs * 0.36)
	c.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Art.INK)
	c.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## The chip page: the shed with what it sells, and the top
## bar's gear and ? drawn as they are on the screen.
func _draw() -> void:
	if _played() or size.x <= 0.0:
		return
	var rows: Array = [
		["trend", tr("TUT_FURROW_HUD_SHED"), true],
		["gear", tr("TUT_FURROW_HUD_GEAR"), false],
		["help", tr("TUT_FURROW_HUD_HELP"), false],
	]
	var row_h := size.y / rows.size()
	var chip := minf(104.0, row_h * 0.72)
	var x0 := 36.0
	var b := Face.Builder.new()
	var centres: Array = []
	for k in rows.size():
		var c := Vector2(x0 + chip * 0.5, row_h * (k + 0.5))
		centres.append(c)
		if bool(rows[k][2]):
			b.disc(c + Vector2(0, 6.0), chip * 0.5, Color(Pal.TEXT, 0.16))
			b.disc(c, chip * 0.5, Shop.TINT)
		else:
			var at := c - Vector2(chip, chip) * 0.5
			b.polygon(Face.Builder.round_rect(at + Vector2(0, 6.0), Vector2(chip, chip), 26.0), Color(Pal.TEXT, 0.16))
			b.polygon(Face.Builder.round_rect(at, Vector2(chip, chip), 26.0), Pal.SURFACE)
	_rows_shown = b.mesh()
	draw_mesh(_rows_shown, null)
	var tx := x0 + chip + 28.0
	var wide := size.x - tx - 24.0
	for k in rows.size():
		var c: Vector2 = centres[k]
		var shed := bool(rows[k][2])
		Icons.paint(self, String(rows[k][0]), Rect2(c - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54),
			Pal.SURFACE if shed else Pal.TEXT, Color.TRANSPARENT if shed else Pal.SURFACE)
		var line := String(rows[k][1])
		var lines := _font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30)
		draw_multiline_string(_font, Vector2(tx, c.y - lines.y * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30, -1, Pal.TEXT)
