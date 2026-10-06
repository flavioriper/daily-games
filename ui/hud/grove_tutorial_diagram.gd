extends Control

## One page of the Grove's tutorial: a stretch of the pond and the land drawn
## with the game's own art (valley/grove_art.gd) at the game's own scale and,
## where something is chopped, played by the game's own sim
## (valley/grove_sim.gd) with a finger that never leaves its tree. `lesson`
## picks the page (set before it enters the tree):
##
## - CHOP: the circle on a sapling, a beaver at it, a number a bite, and the
##   tree comes down.
## - GIFTS: what a felled tree leaves: a log for the shared wood, motes of
##   light for the grove's own energy (ui/motes.gd, the screen's own layer
##   stepped by this page), each to its plate.
## - WAIT: an empty land filling up by itself, a tree at a time.
##
## Under reduce motion each page stands still at its telling moment.

const Sim = preload("res://valley/grove_sim.gd")
const Art = preload("res://valley/grove_art.gd")
const Life = preload("res://valley/grove_life.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Motes = preload("res://ui/motes.gd")

enum Lesson { CHOP, GIFTS, WAIT }

## Seconds a page plays before it starts over, and where a still page stands.
const LENGTH := {Lesson.CHOP: 4.2, Lesson.GIFTS: 3.8, Lesson.WAIT: 6.0}
const STILL := {Lesson.CHOP: 1.2, Lesson.GIFTS: 2.5, Lesson.WAIT: 5.0}
## Where the lesson's trees stand, in land units: five places about the
## middle of the land, which the picture is centred on (the first of them),
## and how much of the land's width the picture shows.
const SPOTS := [Vector2(520, 520), Vector2(330, 360), Vector2(720, 420), Vector2(420, 760), Vector2(660, 780)]
const ACROSS := 700.0
const PLATE := Vector2(250, 92)
const NUM := 0.7
const FLIGHT := 0.9

var lesson: int = Lesson.CHOP

var _sim: RefCounted
## The trees, their shadows, the beaver and the fall, as the screen shows
## them (valley/grove_life.gd), on two layers over the pond's ground.
var _life: RefCounted
var _t := 0.0
var _pond: Control
var _shade: Control
var _stand: Control
var _over: Control
var _ground: ArrayMesh
var _grass: Array[MultiMesh] = []
var _u := 1.0
var _origin := Vector2.ZERO
var _nums: Array = []
var _fell_at := -1.0
## When the felled tree went into what it gives, and where its crown lay
## (view units): the log leaves from there.
var _gave_at := -1.0
var _gave_from := Vector2.ZERO
var _motes: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pond = Control.new()
	_pond.clip_contents = true
	_pond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pond.draw.connect(_draw_pond)
	# the land's own wind: only what stands on a foot of its own leans
	_pond.material = Art.wind()
	add_child(_pond)
	_shade = _layer(func() -> void: _life.draw_shade(_shade, _sim))
	_stand = _layer(_draw_stand)
	_stand.material = Art.wind()
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_gifts)
	add_child(_over)
	if lesson == Lesson.GIFTS:
		_motes = Motes.new()
		_motes.auto = false
		_motes.always = true
		add_child(_motes)
	resized.connect(_layout)
	_start()
	_layout()
	Art.blow()
	if Motion.reduce:
		_advance(float(STILL[lesson]))
		set_process(false)

func _layer(draws: Callable) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(draws)
	_pond.add_child(layer)
	return layer

func _start() -> void:
	_t = 0.0
	_nums.clear()
	_fell_at = -1.0
	_gave_at = -1.0
	_life = Life.new()
	_life.gave.connect(_on_gave)
	_shade.material = _life.shade
	_life.place(_origin, _u, _pond.get_global_transform())
	if _motes != null:
		_motes.clear()
		_motes.rng.seed = 11
	_sim = Sim.new(11)
	_sim.trees.clear()
	_sim.events.clear()
	var n := 0 if lesson == Lesson.WAIT else (1 if lesson == Lesson.GIFTS else 3)
	for i in n:
		_sim.trees.append({"id": i + 1, "tier": 0, "pos": SPOTS[i], "hp": Sim.hp_of(0), "born": -Sim.GROW})

## The pond takes the page, under the plates on the page that has them; the
## land is as wide as it lets it be and runs off the top and the bottom.
func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := PLATE.y + 16.0 if lesson == Lesson.GIFTS else 0.0
	_pond.position = Vector2(0.0, top)
	_pond.size = size - Vector2(0.0, top)
	_u = _pond.size.x / ACROSS
	_origin = _pond.size * 0.5 - (Art.see(SPOTS[0]) + Vector2(0.0, -20.0)) * _u
	_ground = Art.ground(_pond.size, _origin, _u)
	_grass = Art.grass(_origin, _u)
	_life.place(_origin, _u, _pond.get_global_transform())
	# a still page's motes hang where the last size put them: play it again
	if _motes != null and not is_processing():
		_start()
		_advance(float(STILL[lesson]))
	_redraw()

func _redraw() -> void:
	_pond.queue_redraw()
	_shade.queue_redraw()
	_stand.queue_redraw()
	_over.queue_redraw()

func _process(delta: float) -> void:
	_advance(delta)
	Art.blow()
	if _t >= float(LENGTH[lesson]):
		_start()
	# the card slides in: the shadows are kept to where the land is now
	_life.place(_origin, _u, _pond.get_global_transform())
	_redraw()

func _advance(delta: float) -> void:
	var left := delta
	while left > 0.0:
		var dt := minf(left, 1.0 / 30.0)
		left -= dt
		_t += dt
		for n: Dictionary in _nums:
			n.t += dt
		if lesson == Lesson.WAIT:
			if _sim.trees.size() < SPOTS.size() and _t >= 0.5 + _sim.trees.size() * 1.0:
				_sim.trees.append({"id": _sim.trees.size() + 1, "tier": 0, "pos": SPOTS[_sim.trees.size()],
					"hp": Sim.hp_of(0), "born": _sim.clock})
			_sim.clock += dt
		else:
			_sim.step(dt, _holding(), _finger())
		_life.step(dt, _sim, _holding(), _finger())
		for e: Dictionary in _sim.events:
			if e.kind == "hit":
				_life.hit(e.tree)
				_nums.append({"at": Art.see(e.tree.pos) + Vector2(0.0, -Art.height(0) * 0.9 * Art.TREE), "text": Art.amount(float(e.amount)), "t": 0.0})
			elif e.kind == "fell":
				_fell_at = _t
				_life.fell(e.tree, int(e.give))
		_sim.events.clear()
		if _motes != null:
			_motes.step(dt)
		_nums = _nums.filter(func(n: Dictionary) -> bool: return n.t < NUM)

## The felled tree, lying with its crown at `at` (view units), goes into
## what it gives: the log leaves for its plate and the motes are let go.
func _on_gave(_tree: Dictionary, _give: int, at: Vector2) -> void:
	_gave_at = _t
	_gave_from = at
	if _motes != null:
		_motes.u = size.x / 810.0 * 2.2
		_motes.to = Vector2(size.x * 0.5 - 10.0 - PLATE.x + 56.0, PLATE.y * 0.5)
		_motes.drop(get_global_transform() * (_pond.position + _origin + at * _u), 4.0, 4)

func _holding() -> bool:
	return lesson != Lesson.WAIT and _t > 0.4 and _fell_at < 0.0

## The circle's centre, in land units: on the first tree, a little up from
## its foot as the land is seen.
func _finger() -> Vector2:
	return (SPOTS[0] as Vector2) + Vector2(0.0, -Sim.RADIUS[0] * 1.4)

func _px(p: Vector2) -> Vector2:
	return _origin + Art.see(p) * _u

func _draw_pond() -> void:
	if _ground == null:
		return
	_pond.draw_mesh(_ground, null)
	for mm: MultiMesh in _grass:
		_pond.draw_multimesh(mm, null)

## What stands on the land and what is drawn over it: the bars, the circle
## and the numbers lie where they are drawn, so the wind leaves them alone.
func _draw_stand() -> void:
	if _ground == null:
		return
	_life.draw(_stand, _sim)
	for tree: Dictionary in _sim.trees:
		if float(tree.hp) < Sim.hp_of(0):
			var w := 54.0 * _u
			var bar := Rect2(_px(tree.pos) + Vector2(-w * 0.5, 12.0 * _u), Vector2(w, 12.0 * _u))
			_stand.draw_rect(bar, Color(0.23, 0.19, 0.16, 0.35))
			_stand.draw_rect(Rect2(bar.position, Vector2(w * float(tree.hp) / Sim.hp_of(0), bar.size.y)), Color("fff6e6"))
	if _holding():
		# a circle on the ground: flatter than it is wide from here
		var r: float = _sim.reach() * _u
		var c := _px(_finger())
		_stand.draw_colored_polygon(Art.oval(c, r), Color(1.0, 1.0, 1.0, 0.26))
		for line: Array in [[r, Color(0.23, 0.19, 0.16, 0.75), 5.0], [r - 5.0, Color(1.0, 1.0, 1.0, 0.8), 3.0]]:
			var edge := Art.oval(c, line[0])
			edge.append(edge[0])
			_stand.draw_polyline(edge, line[1], line[2], true)
	var font := get_theme_font("font", "SheetTitle")
	for n: Dictionary in _nums:
		var k: float = n.t / NUM
		var fs := int(40.0 * _u)
		var w := font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := _origin + (n.at as Vector2) * _u + Vector2(-w * 0.5, -k * 56.0 * _u)
		_stand.draw_string_outline(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.23, 0.19, 0.16, 0.7 * (1.0 - k * k * k)))
		_stand.draw_string(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 1.0, 1.0, 1.0 - k * k * k))

## The two plates over the pond, and the log on its way (the motes are their
## own layer's).
func _draw_gifts() -> void:
	if lesson != Lesson.GIFTS:
		return
	var gap := 20.0
	var left := Rect2(Vector2(size.x * 0.5 - PLATE.x - gap * 0.5, 0.0), PLATE)
	var right := Rect2(Vector2(size.x * 0.5 + gap * 0.5, 0.0), PLATE)
	var box := CozyTheme.lifted(Color("fcf7ef"), 30, 8)
	var body := get_theme_font("font", "SheetBody")
	for row: Array in [[left, "energy", "GROVE_ENERGY"], [right, "wood", "GROVE_WOOD"]]:
		var r: Rect2 = row[0]
		_over.draw_style_box(box, r)
		_over.draw_mesh(Art.icon(row[1]), null, Transform2D(-0.3 if row[1] == "wood" else 0.0, Vector2(0.8, 0.8), 0.0, r.position + Vector2(56.0, r.size.y * 0.5)))
		_over.draw_string(body, r.position + Vector2(104.0, r.size.y * 0.5 + 11.0), tr(row[2]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 112.0, 32, Pal.TEXT)
	if _gave_at < 0.0:
		return
	var k := clampf((_t - _gave_at) / FLIGHT, 0.0, 1.0)
	if k >= 1.0:
		return
	var from := _pond.position + _origin + _gave_from * _u
	var to := right.position + Vector2(56.0, PLATE.y * 0.5)
	var at := from.lerp(to, k * k) + Vector2(0.0, -sin(k * PI) * 50.0)
	_over.draw_mesh(Art.log_mesh(), null, Transform2D(k * 3.0, Vector2(0.9, 0.9), 0.0, at))
