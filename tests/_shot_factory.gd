extends SceneTree

## Factory's floor, shot; later its screen and its sheet, played by touches.
## Windowed, one run at a time:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_factory.gd -- <outdir> > <log> 2>&1
##
## (add `--rendering-driver opengl3_angle` before `--script` for the phone's
## driver, and `reduce` after <outdir> for reduce motion). It works on a
## floor of its own (`Sim.new(7)`, kept in a throwaway file that is deleted
## as it ends). Each step that matters prints PASS or FAIL, each shot its
## draw calls.
##
## The floor (factory/life.gd mounted on a bare Control, fitted to the
## window's width; the screen proper comes with its own section): stepped
## 300 ticks, the three robots drawn where their tiles are, the Picker
## sliding through a step and its last tick without a stop at the tile, the
## floor shot and its draw calls held under the budget, the Shipper's "?"
## batched over it; then things lying, a box on the floor, a belt from the
## intake pad to the table with a square on it, shot again.

const SEED := 7
const SAVE := "user://factory_harness.cfg"
const BUDGET := 855

var Art: GDScript
var Sim: GDScript
var Bots: GDScript
var Life: GDScript
var Motion: GDScript
var _out := "/tmp/shot_factory"
## The screen, from its own section on (factory/screen.gd); the touch
## helpers hand it their events.
var _screen: Control
var _sim: RefCounted
var _life: RefCounted
var _field: Control
var _fails := 0
var _n := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	Art = load("res://factory/art.gd")
	Sim = load("res://factory/sim.gd")
	Bots = load("res://factory/bots.gd")
	Life = load("res://factory/life.gd")
	Motion = load("res://core/motion.gd")
	Motion.reduce = args.has("reduce")
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	Sim.path = SAVE
	TranslationServer.set_locale("en")
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

## Waits until `test` says so, `most` seconds at the longest.
func _until(test: Callable, most: float) -> bool:
	var until := Time.get_ticks_msec() + int(most * 1000.0)
	while Time.get_ticks_msec() < until:
		if test.call():
			return true
		await process_frame
	return test.call()

func _ok(what: String, ok: bool, more := "") -> void:
	if not ok:
		_fails += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", what, "" if more == "" else "  (" + more + ")"])

## Shoots the window and prints its draw calls; returns them.
func _shot(called: String) -> int:
	await _frames(2)
	_n += 1
	var path := "%s/%02d_%s.png" % [_out, _n, called]
	root.get_texture().get_image().save_png(path)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("%s  draw calls %d" % [path, draws])
	return draws

## The floor goes on `ticks` ticks at once, its events to the life as a
## holder hands them.
func _ticks(ticks: int) -> void:
	for i in ticks:
		_sim.step(Sim.TICK)
		for e: Dictionary in _sim.events:
			_life.event(e)
		_sim.events.clear()
		_life.step(Sim.TICK)

# --- the hand ---

func _touch(pos: Vector2, pressed: bool, finger := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = pos
	e.pressed = pressed
	_screen._on_field_input(e)

func _move(pos: Vector2, finger := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = finger
	e.position = pos
	_screen._on_field_input(e)

func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	await _frames(2)
	_touch(pos, false)
	await _frames(2)

## A finger down at the first point, through the others a few steps a
## stretch, and up at the last.
func _drag(points: Array, steps := 6) -> void:
	_touch(points[0], true)
	await _frames(2)
	for i in range(1, points.size()):
		for k in range(1, steps + 1):
			_move((points[i - 1] as Vector2).lerp(points[i], float(k) / steps))
			await process_frame
	await _frames(2)
	_touch(points[points.size() - 1], false)
	await _frames(2)

## A finger down at the first point and through the others, left down.
func _hold(points: Array, steps := 6) -> void:
	_touch(points[0], true)
	await _frames(2)
	for i in range(1, points.size()):
		for k in range(1, steps + 1):
			_move((points[i - 1] as Vector2).lerp(points[i], float(k) / steps))
			await process_frame
	await _frames(3)

func _press_button(b: Button) -> void:
	b.pressed.emit()
	await _frames(2)

# --- the run ---

func _run() -> void:
	await _frames(8)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	await _floor()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s  %d failed" % ["DONE" if _fails == 0 else "DONE WITH FAILURES", _fails])
	quit()

## Whether `p` lies strictly between `a` and `b` on the line through them.
func _between(p: Vector2, a: Vector2, b: Vector2) -> bool:
	return p.distance_to(a) > 1.0 and p.distance_to(b) > 1.0 and is_equal_approx(p.distance_to(a) + p.distance_to(b), a.distance_to(b))

## The floor alone: life mounted on a bare field the window's size, the
## floor fitted to its width and stood in its middle, the field's wash
## under it and the light over it, as a holder does.
func _floor() -> void:
	_sim = Sim.new(SEED)
	var size := root.get_visible_rect().size
	_field = Control.new()
	_field.name = "Field"
	_field.size = size
	_field.clip_contents = true
	var wash: ArrayMesh = Art.water(size, 0.0)
	_field.draw.connect(func() -> void: _field.draw_mesh(wash, null))
	root.add_child(_field)
	_life = Life.new()
	var world: Node2D = _life.mount(_field, _sim)
	var box: Rect2 = _life.bounds()
	var u := size.x / box.size.x
	world.scale = Vector2(u, u)
	world.position = Vector2(0.0, (size.y - box.size.y * u) * 0.5) - box.position * u
	var light := Control.new()
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.size = size
	var shine: ArrayMesh = Art.light(size)
	light.draw.connect(func() -> void: light.draw_mesh(shine, null))
	_field.add_child(light)
	await _frames(3)
	_ok("the field is the design space, 1080 wide", is_equal_approx(size.x, 1080.0), str(size))

	_ticks(300)
	var robots: Array = _sim.robots
	_ok("three robots drawn", robots.size() == 3 and (_life.robot_pos(0) != _life.robot_pos(1) or robots[0].tile == robots[1].tile),
		"%s %s" % [_life.robot_pos(0), _life.robot_pos(1)])
	var placed := true
	for i in robots.size():
		var b: Dictionary = robots[i]
		if b.was == b.tile:
			placed = placed and _life.robot_pos(i).is_equal_approx(_life.mid(b.tile))
	_ok("a robot standing is drawn on its tile's middle", placed)

	# the Picker sets out on a step: drawn between the two tiles through it,
	# and through its last tick too, never parked on the tile it steps to
	var picker: Dictionary = robots[0]
	var set_out := false
	for i in 400:
		_ticks(1)
		if picker.was != picker.tile and int(picker.t) == 1:
			set_out = true
			break
	var from: Vector2 = _life.mid(picker.was)
	var to: Vector2 = _life.mid(picker.tile)
	_ticks(2)
	_sim.alpha = 0.5
	var mid_way: Vector2 = _life.robot_pos(0)
	_ok("picker walks between tiles", set_out and _between(mid_way, from, to), "%s from %s to %s" % [mid_way, from, to])
	_ticks(1)
	_sim.alpha = 0.5
	var last: Vector2 = _life.robot_pos(0)
	_ok("and through the step's last tick, no stop at the tile", _between(last, from, to) and last.distance_to(to) < mid_way.distance_to(to),
		"%s, t %d" % [last, int(picker.t)])
	_ticks(1)

	# the Shipper's loose wire: a "?" over it, batched
	var shipper: Dictionary = robots[2]
	for i in 3000:
		if shipper.stuck == "?":
			break
		_ticks(1)
	_ticks(1)
	await _frames(2)
	var draws: int = await _shot("floor_start")
	_ok("draw calls under budget", draws > 0 and draws < BUDGET, str(draws))
	_ok("bubble over the shipper", shipper.stuck == "?" and shipper.bubble == "?" and int(_life._bubbles["?"].n) >= 1,
		"stuck %s bubble %s, tick %d" % [shipper.stuck, shipper.bubble, _sim.tick_n])

	# things about: a box of three and two squares lying on open floor, a
	# belt from the intake pad to the table with a square riding it
	_sim.no_cost = true
	_sim.milestone = 1
	var laid: bool = _sim.lay_belt(Vector2i(2, 5), 0) and _sim.lay_belt(Vector2i(3, 5), 0)
	laid = _sim.lay_belt(Vector2i(6, 3), 1) and _sim.lay_belt(Vector2i(6, 4), 0) and _sim.lay_belt(Vector2i(7, 4), 0) and laid
	_sim.put(Vector2i(2, 5), {"id": 9001, "kind": "square", "at": 0.5, "from": -1, "was": Vector2.INF})
	_sim.put(Vector2i(6, 2), {"id": 9002, "kind": "box", "n": 3, "at": 0.5, "from": -1, "was": Vector2.INF})
	_sim.put(Vector2i(2, 2), {"id": 9003, "kind": "square", "at": 0.5, "from": -1, "was": Vector2.INF})
	_sim.put(Vector2i(2, 2), {"id": 9004, "kind": "square", "at": 0.5, "from": -1, "was": Vector2.INF})
	_sim.put(Vector2i(6, 3), {"id": 9005, "kind": "box", "n": 1, "at": 0.5, "from": -1, "was": Vector2.INF})
	_ticks(6)
	await _frames(2)
	var lying: int = _life._squares.n
	var boxes := 0
	for bx: RefCounted in _life._boxes:
		boxes += int(bx.n)
	_ok("belts laid by the sim are drawn, a bend among them", laid and _life._shapes.size() >= 1, "shapes %d" % _life._shapes.size())
	_ok("squares and boxes are batched", lying >= 3 and boxes >= 2, "squares %d boxes %d" % [lying, boxes])
	draws = await _shot("floor_things")
	_ok("draw calls under budget with things about", draws > 0 and draws < BUDGET, str(draws))
	_field.queue_free()
	await _frames(3)
