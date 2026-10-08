extends Control

## One page of Air Hockey's tutorial: the whole table lying on its side to
## fit the card (the gold mallet's end on the left), played by the table
## itself. The page holds a `Quiet` -- versus/hockey_table.gd, deaf to the
## player's own hands -- over a sim of its own (versus/hockey_sim.gd), and a
## finger that leads the mallet the way a thumb does, by saying where it
## wants it. So the mallet rides ahead of the finger, stops at the middle
## line, sends the puck and stops it, exactly as in a match. `lesson` picks
## the page (set before it enters the tree):
##
## - LEAD: the finger wanders and the mallet goes with it, up to the line.
## - SCORE: a swing through the puck, into the far slot.
## - BLOCK: the blue mallet shoots; the gold one stands in the way, then
##   swings and sends it back.
## - BANK: the straight way is blocked, so off the long rail and in.
## - TWO: two fingers, a rally (both hands are versus/hockey_ai.gd).
##
## Every scene is a script of where each hand wants its mallet over time and
## was tried on the sim, which steps a fixed 1/240 s, so it repeats exactly
## (tests/_probe_hockey.gd checks that SCORE and BANK go in and BLOCK does
## not). Under reduce motion a page stands still on one moment of its lesson.
##
## A page plays no sound and buzzes nothing: the screen's Fx2D is not here.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Sim = preload("res://versus/hockey_sim.gd")
const AI = preload("res://versus/hockey_ai.gd")
const Table = preload("res://versus/hockey_table.gd")

enum Lesson { LEAD, SCORE, BLOCK, BANK, TWO }

const PAD := 6.0
const FINGER_R := 30.0
const FINGER_ALPHA := 0.18
## How long the TWO page's rally runs before it starts over, and the beat a
## goal is looked at.
const RALLY := 16.0
const AFTER_GOAL := 1.3

var lesson: int = Lesson.LEAD
var sim: RefCounted
var _art: Quiet
var _over: Control
var _t := 0.0
var _acc := 0.0
var _scene := {}
var _bots: Array = []
var _goal_t := -1.0
var _laid := false

## The table, quiet: it takes no touch at all.
class Quiet extends "res://versus/hockey_table.gd":
	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Nothing left over from the last run of the scene.
	func wipe() -> void:
		_trail.clear()
		_flashes.clear()
		_glow = [0.0, 0.0]
		_sink = {}

## A lesson's scene: how long it runs, where the puck starts (none: off the
## table), which seats show a finger, and each seat's path as [seconds, x, y]
## waypoints in metres (the mallet's own place, eased between), and `still`,
## the moment a page under reduce motion stands on.
static func scene_of(the_lesson: int) -> Dictionary:
	var h0 := Sim.home(0)
	var h1 := Sim.home(1)
	match the_lesson:
		Lesson.LEAD:
			return {"len": 7.6, "puck": Vector2(0.5, 0.4), "fingers": [0], "still": 2.2, "paths": {
				0: [[0.0, h0.x, h0.y], [0.7, h0.x, h0.y], [1.6, 0.24, 1.16], [2.5, 0.72, 1.36], [3.3, 0.76, 0.98],
					[4.2, 0.5, 0.7], [4.9, 0.5, 0.7], [5.8, 0.26, 1.0], [6.8, h0.x, h0.y], [7.6, h0.x, h0.y]],
				1: [[0.0, h1.x, h1.y]]}}
		Lesson.SCORE:
			return {"len": 5.2, "puck": Vector2(0.5, 1.08), "fingers": [0], "still": 1.5, "paths": {
				0: [[0.0, h0.x, h0.y], [0.9, h0.x, h0.y], [1.5, 0.5, 1.36], [1.72, 0.5, 0.94], [2.6, 0.5, 1.2], [5.2, h0.x, h0.y]],
				1: [[0.0, 0.2, 0.3]]}}
		Lesson.BLOCK:
			return {"len": 6.6, "puck": Vector2(0.5, 0.52), "fingers": [0], "still": 1.9, "paths": {
				0: [[0.0, 0.5, 1.4], [3.62, 0.5, 1.4], [3.84, 0.5, 1.06], [4.62, 0.5, 1.4], [6.6, 0.5, 1.4]],
				1: [[0.0, h1.x, h1.y], [0.9, 0.5, 0.2], [1.5, 0.5, 0.2], [1.78, 0.5, 0.5], [2.4, 0.5, 0.2], [6.6, 0.5, 0.2]]}}
		Lesson.BANK:
			return {"len": 5.6, "puck": Vector2(0.62, 1.1), "fingers": [0], "still": 1.6, "paths": {
				0: [[0.0, h0.x, h0.y], [0.8, h0.x, h0.y], [1.6, 0.774, 1.264], [1.86, 0.52, 0.994], [2.8, 0.6, 1.2], [5.6, h0.x, h0.y]],
				1: [[0.0, 0.56, 0.2]]}}
	return {"len": RALLY, "puck": Vector2(0.5, Sim.L - Sim.SERVE), "fingers": [0, 1], "still": 0.0, "paths": {}}

## Where `seat` wants its mallet `t` seconds into `scene`.
static func want(scene: Dictionary, seat: int, t: float) -> Vector2:
	var path: Array = scene.paths.get(seat, [])
	if path.is_empty():
		return Sim.home(seat)
	var at := Vector2(path[0][1], path[0][2])
	for k in range(1, path.size()):
		var a: Array = path[k - 1]
		var b: Array = path[k]
		if t >= float(b[0]):
			at = Vector2(b[1], b[2])
			continue
		var u := clampf((t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
		# In and out of every stop, so a swing gathers pace as an arm does.
		u = u * u * (3.0 - 2.0 * u)
		return Vector2(a[1], a[2]).lerp(Vector2(b[1], b[2]), u)
	return at

## The sim as a scene starts it.
static func lay(scene: Dictionary) -> RefCounted:
	var s: RefCounted = Sim.new()
	s.reset(0)
	if scene.puck == null:
		s.puck_on = false
	else:
		s.puck = scene.puck
	for p in 2:
		s.mallet[p] = want(scene, p, 0.0)
		s.aim[p] = s.mallet[p]
	return s

## One step of a scene `t` seconds in: the hands, then the sim.
static func advance(scene: Dictionary, s: RefCounted, t: float) -> void:
	for p in 2:
		if scene.paths.has(p):
			s.aim[p] = want(scene, p, t)
	s.step()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_scene = scene_of(lesson)
	_art = Quiet.new()
	add_child(_art)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_fingers)
	add_child(_over)
	resized.connect(_layout)
	_restart()
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _laid:
		_restart()

## The table on its side, as big as the page holds, turned about its middle
## so the gold mallet's end is on the left.
func _layout() -> void:
	if _art == null or size.x <= 0.0:
		return
	var span := Vector2(Sim.W, Sim.L) + Vector2.ONE * 2.0 * Table.RAIL
	var long := minf(size.x - PAD * 2.0, (size.y - PAD * 2.0) * span.y / span.x)
	_art.size = Vector2(long * span.x / span.y, long)
	_art.pivot_offset = _art.size * 0.5
	_art.rotation = PI * 0.5
	_art.position = size * 0.5 - _art.size * 0.5
	_over.position = Vector2.ZERO
	_over.size = size
	_over.queue_redraw()

func _restart() -> void:
	_laid = true
	_t = 0.0
	_acc = 0.0
	_goal_t = -1.0
	sim = lay(_scene)
	_art.sim = sim
	_art.wipe()
	_bots.clear()
	if lesson == Lesson.TWO:
		_bots = [AI.new(0, 1, 21), AI.new(1, 1, 22)]
		for b in _bots:
			b.served()
	if Motion.reduce:
		_stand_still()

## Reduce motion: the scene run, unseen, to its `still` moment and left there.
func _stand_still() -> void:
	var t := 0.0
	while t < float(_scene.still):
		t += Sim.DT
		advance(_scene, sim, t)
	sim.events.clear()
	_t = t
	_art.queue_redraw()
	if _over != null:
		_over.queue_redraw()

func _process(delta: float) -> void:
	if Motion.reduce or sim == null:
		return
	_acc += minf(delta, 0.05)
	while _acc >= Sim.DT:
		_acc -= Sim.DT
		_t += Sim.DT
		if lesson == Lesson.TWO:
			for b in _bots:
				b.drive(sim, Sim.DT)
			sim.step()
		else:
			advance(_scene, sim, _t)
	for e in sim.events:
		match String(e.kind):
			"mallet":
				_art.flash("mallet", e.at, float(e.speed) / 6.0, int(e.who))
			"wall", "post":
				if float(e.speed) > 0.2:
					_art.flash("wall", e.at, float(e.speed) / 6.0)
			"goal":
				_art.goal(1 - int(e.by), e.at)
				_goal_t = _t
	sim.events.clear()
	if _t >= float(_scene.len) or (lesson == Lesson.TWO and _goal_t >= 0.0 and _t >= _goal_t + AFTER_GOAL):
		_restart()
	_over.queue_redraw()

## A finger behind each mallet that has one: where a thumb would be to want
## the mallet where it is, pressed a little darker while it swings.
func _draw_fingers() -> void:
	if sim == null or _art == null:
		return
	var xf := _art.get_transform()
	for seat: int in _scene.fingers:
		var lift := Vector2(0.0, Table.LIFT if seat == 0 else -Table.LIFT)
		var at: Vector2 = xf * _art.px(sim.mallet[seat] + lift)
		var fast: float = clampf(sim.mallet_vel[seat].length() / 2.5, 0.0, 1.0)
		_over.draw_circle(at, FINGER_R, Color(Pal.TEXT, FINGER_ALPHA + 0.08 * fast), true, -1.0, true)
		_over.draw_circle(at, FINGER_R, Color(Pal.TEXT, 0.34), false, 3.0, true)
