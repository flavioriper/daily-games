extends Control

## One page of Factory's tutorial (factory/screen.gd's `tutorial_pages`): a
## stretch of the pond and the land drawn by the game's own path
## (factory/life.gd) and played by the game's own sim (factory/sim.gd) with a
## finger that does what the page says. `lesson` picks the page, set before
## it enters the tree:
##
## - TREE: three taps on the forest, a log each, out of its gate.
## - BELT: Belt picked, the finger swipes a straight run down from the gate
##   and a second from its corner to the market; each is laid as the finger
##   lifts, and the logs ride and are sold.
## - PLATE: from further off, a tap on a plus and a plate comes up.
##
## A page starts over every LENGTH seconds on a land of the same seed, so it
## is the same little film each time. Under reduce motion it stands still at
## its telling moment (STILL).

const Sim = preload("res://factory/sim.gd")
const Art = preload("res://factory/art.gd")
const Life = preload("res://factory/life.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { TREE, BELT, PLATE }

const SEED := 7
const LENGTH := {Lesson.TREE: 6.5, Lesson.BELT: 28.0, Lesson.PLATE: 7.0}
const STILL := {Lesson.TREE: 2.4, Lesson.BELT: 6.0, Lesson.PLATE: 5.5}
## What each page looks at, in tile space, and how many view units it shows
## across.
const LOOK := {Lesson.TREE: Vector2(3.5, -2.2), Lesson.BELT: Vector2(4.0, 3.0), Lesson.PLATE: Vector2(6.5, 1.5)}
const ACROSS := {Lesson.TREE: 1000.0, Lesson.BELT: 1250.0, Lesson.PLATE: 2900.0}
## Where the pages tap the forest (the new land's, behind the market's
## plate), and the belt's way from its gate to the market: [tile, facing]
## each, the corner at CORNER.
const TREE := Vector2i(3, -4)
const TAPS := [1.1, 1.8, 2.5]
const WAY := [[Vector2i(3, 0), 1], [Vector2i(3, 1), 1], [Vector2i(3, 2), 1], [Vector2i(3, 3), 1], [Vector2i(3, 4), 1],
	[Vector2i(3, 5), 1], [Vector2i(3, 6), 0], [Vector2i(4, 6), 0], [Vector2i(5, 6), 0]]
const CORNER := 6
const DRAG_FROM := 1.2
const DRAG_TIME := 1.8
const DRAG_REST := 0.6
const NEW_PLATE := Vector2i(1, 0)

var lesson: int = Lesson.TREE

var _sim: RefCounted
var _life: RefCounted
var _world: Node2D
var _water: ArrayMesh
var _t := 0.0
var _done := 0
## The finger: where it is (tile space) and how long ago it pressed.
var _finger := Vector2.ZERO
var _pressed := 10.0
var _shows := false
var _finger_l: Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	draw.connect(func() -> void:
		if _water != null:
			draw_mesh(_water, null))
	_life = Life.new()
	_life.plus = lesson == Lesson.PLATE
	_start()
	_world = _life.mount(self, _sim)
	_finger_l = _life.layer(_draw_finger)
	resized.connect(_layout)
	_layout()
	if Motion.reduce:
		_advance(float(STILL[lesson]))
		set_process(false)

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_water = Art.water(size, 28.0)
	var u: float = size.x / float(ACROSS[lesson])
	_world.scale = Vector2(u, u)
	_world.position = size * 0.5 - Art.at(LOOK[lesson]) * u
	queue_redraw()

## The page's land, as it opens: for the belt's page two logs lie past the
## gate; for the plate's the coins are there.
func _start() -> void:
	_t = 0.0
	_done = 0
	_pressed = 10.0
	_shows = false
	_sim = Sim.new(SEED)
	if lesson == Lesson.BELT:
		for i in 2:
			_sim.tap(TREE)
			_sim.step(Sim.TICK)
	elif lesson == Lesson.PLATE:
		_sim.coins = _sim.plate_price()
	_sim.events.clear()
	if _world != null:
		_life.hold(_sim)

func _process(delta: float) -> void:
	_advance(minf(delta, 0.1))

func _advance(delta: float) -> void:
	var left := delta
	while left > 0.0:
		var dt := minf(left, 0.05)
		left -= dt
		_t += dt
		if _t >= float(LENGTH[lesson]):
			_start()
		_act()
		_pressed += dt
		_sim.step(dt)
		for e: Dictionary in _sim.events:
			_life.event(e)
		_sim.events.clear()
		_life.step(dt)
	if _finger_l != null:
		_finger_l.queue_redraw()

## What the finger does at this moment of the page.
func _act() -> void:
	match lesson:
		Lesson.TREE:
			_finger = Vector2(TREE) + Vector2(0.5, 0.5)
			_shows = _t > 0.5 and _t < 3.4
			if _done < TAPS.size() and _t >= float(TAPS[_done]):
				_done += 1
				_pressed = 0.0
				_sim.tap(TREE)
		Lesson.BELT:
			# two swipes, each laid as the finger lifts: down from the gate,
			# then from the corner to the market
			_life.ghosts = []
			var down := (_t - DRAG_FROM) / DRAG_TIME
			var over := (_t - DRAG_FROM - DRAG_TIME - DRAG_REST) / (DRAG_TIME * 0.5)
			var first: Vector2 = Vector2(WAY[0][0]) + Vector2(0.5, 0.5)
			var corner: Vector2 = Vector2(WAY[CORNER][0]) + Vector2(0.5, 0.5)
			var last: Vector2 = Vector2(WAY[WAY.size() - 1][0]) + Vector2(0.5, 0.5)
			_shows = (_t > 0.5 and down < 1.0) or (over > -0.4 and over < 1.0)
			if down < 1.0:
				_finger = first.lerp(corner, clampf(down, 0.0, 1.0))
				if down > 0.0:
					_pressed = 0.1
					for i in CORNER + 1:
						if Vector2(WAY[i][0]).y <= _finger.y:
							_life.ghosts.append([Art.belt(), Transform2D(0.0, Art.BELT_LIFT) * Art.flat(Vector2(WAY[i][0]), 1), Color(1.0, 1.0, 1.0, 0.72)])
			else:
				if _done == 0:
					_done = 1
					for i in CORNER + 1:
						_sim.lay_belt(WAY[i][0], 1)
				_finger = corner.lerp(last, clampf(over, 0.0, 1.0))
				if over > 0.0 and over < 1.0:
					_pressed = 0.1
					for i in range(CORNER + 1, WAY.size()):
						if Vector2(WAY[i][0]).x <= _finger.x:
							_life.ghosts.append([Art.belt(), Transform2D(0.0, Art.BELT_LIFT) * Art.flat(Vector2(WAY[i][0]), 0), Color(1.0, 1.0, 1.0, 0.72)])
				if _done == 1 and over >= 1.0:
					_done = 2
					for i in range(CORNER, WAY.size()):
						_sim.lay_belt(WAY[i][0], 0)
		Lesson.PLATE:
			_finger = Vector2(NEW_PLATE * Art.PLATE) + Vector2(Art.PLATE, Art.PLATE) * 0.5
			_shows = _t > 0.6 and _t < 2.6
			if _done == 0 and _t >= 1.6:
				_done = 1
				_pressed = 0.0
				_sim.buy_plate(NEW_PLATE, "neutral")

## The finger: a pale ring that closes on a dot as it presses, drawn over the
## land at a size the page's scale leaves readable.
func _draw_finger(ci: CanvasItem) -> void:
	if not _shows:
		return
	var s: float = 1.0 / maxf(0.01, _world.scale.x)
	var at := Art.at(_finger)
	var down := 1.0 - clampf(_pressed / 0.3, 0.0, 1.0)
	var r := (30.0 - 8.0 * down) * s
	ci.draw_circle(at, r, Color(1.0, 1.0, 1.0, 0.35 + 0.3 * down), true, -1.0, true)
	ci.draw_arc(at, r, 0.0, TAU, 40, Color(0.23, 0.19, 0.16, 0.7), 4.0 * s, true)
	ci.draw_circle(at, 8.0 * s, Pal.ACCENT, true, -1.0, true)
