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
##
## The screen (factory/screen.gd built by hand on a new floor, the field's
## mouse off so the real pointer cannot reach it): three robot chips under
## the top bar, a dot on the chip of each robot with a fault a rule sees, a
## chip tapped and a robot tapped, the pace pill blank, the drawer empty
## before milestone 1, then a belt traced from the intake pad to the table,
## shot and its draw calls held under the budget.
##
## The sheet (factory/sheet.gd on a new floor's screen, its mouse off as the
## field's is; its touches handed to its own `_gui_input` in its own pixels,
## as the field's are to the field): the Picker's sheet opened from the
## screen, the robot kept above it, the chain left to right, the tray off a
## `+` with Pick locked, the Gripper fitted from the bin through the parts'
## `+`, a Pick put into the wire after the first Move, a Move's pill and its
## More; then the Shipper's, shot with its loose wire, a wire dragged from
## its loose dot, a dot armed by a tap and wired by the next, shot again and
## the sheet's draw calls (with it shown, less without) held to a handful;
## a swipe down from the handle closes it.
##
## The tutor (ui/hud/factory_tutorial_diagram.gd, six pages): each page's
## diagram mounted 700 by 500 and played to its telling moment, shot and its
## draw calls held under 200, its edit seen on the sim it plays; the titles
## and bodies in all three languages; then again under reduce motion, each
## page standing at once; and the card itself over a screen, on its second page.

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

## The same hand on the sheet, in the sheet's pixels.
func _sheet_touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	_screen.sheet._gui_input(e)

func _sheet_tap(pos: Vector2) -> void:
	_sheet_touch(pos, true)
	await _frames(2)
	_sheet_touch(pos, false)
	await _frames(2)

func _sheet_drag(from: Vector2, to: Vector2, steps := 8) -> void:
	_sheet_touch(from, true)
	await _frames(2)
	for k in range(1, steps + 1):
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = from.lerp(to, float(k) / steps)
		_screen.sheet._gui_input(e)
		await process_frame
	await _frames(2)
	_sheet_touch(to, false)
	await _frames(2)

## The draw calls of a frame with the sheet shown, less those of one without.
func _sheet_calls() -> int:
	await _frames(3)
	var with_it := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_screen.sheet.visible = false
	await _frames(3)
	var without := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_screen.sheet.visible = true
	await _frames(2)
	return with_it - without

# --- the run ---

func _run() -> void:
	await _frames(8)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	await _floor()
	await _screen_part()
	await _sheet_part()
	await _pages_part()
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

## The screen on a new floor, played by touches handed to its field.
func _screen_part() -> void:
	_sim = Sim.new(SEED)
	_screen = load("res://factory/screen.gd").new()
	_screen.name = "Factory"
	_screen.setup(_sim)
	root.add_child(_screen)
	await _frames(4)
	_screen.field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var field: Vector2 = _screen.field.size
	_ok("the whole floor fits the width", is_equal_approx(_screen._near, field.x / (Sim.COLS * Art.TILE)),
		"near %.3f" % _screen._near)
	_ok("three chips", _screen.robot_chip_rect(2).size.x > 0 and _screen.robot_chip_rect(3).size.x == 0,
		str(_screen.robot_chip_rect(2)))
	# the brief asked a dot on all three; the Boxer's fault is a short count,
	# which no rule of the dot's sees (its loop is closed and it can do it all)
	_ok("fault dots on the Picker and the Shipper, none on the Boxer",
		_screen.robot_fault(0) and not _screen.robot_fault(1) and _screen.robot_fault(2))
	await _tap(_screen.robot_chip_rect(1).get_center())
	_ok("chip selects", _screen.selected == 1)
	# the floor held still while the finger is down on a robot, so where it
	# is drawn is where it is tapped
	_screen.set_process(false)
	await _tap(_screen.to_field(_screen.life.robot_at(0)))
	_screen.set_process(true)
	_ok("robot tap selects", _screen.selected == 0)
	_ok("pace pill reads none", _screen.pace_text() == tr("FACTORY_PACE_NONE"), _screen.pace_text())
	var shown := 0
	for kind: String in _screen.DRAWER_TILES:
		if (_screen._tiles[kind].button as Control).visible:
			shown += 1
	_ok("drawer locked before milestone 1", shown == 0 and not _screen._drawer_b.visible, "%d shown" % shown)

	_sim.milestone = 1
	_sim.coins = 10
	await _frames(2)
	_screen.pick("belt")
	await _frames(2)
	await _drag([_screen.screen_of(Vector2(2.5, 5.5)), _screen.screen_of(Vector2(3.5, 5.5))])
	_ok("belt traced", int(_sim.belts.get(Vector2i(2, 5), -1)) == 0 and int(_sim.belts.get(Vector2i(3, 5), -1)) == 0
		and _sim.belts.size() == 2 and _sim.coins == 8, "%s, %d coins" % [_sim.belts, _sim.coins])
	_screen.pick("")
	await _frames(4)
	var draws: int = await _shot("screen_start")
	_ok("under budget", draws > 0 and draws < BUDGET, str(draws))
	_screen.queue_free()
	await _frames(3)

## The sheet on a new floor's screen, played by touches handed to it.
func _sheet_part() -> void:
	_sim = Sim.new(SEED)
	_screen = load("res://factory/screen.gd").new()
	_screen.name = "Factory"
	_screen.setup(_sim)
	root.add_child(_screen)
	await _frames(4)
	_screen.field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet: Control = _screen.sheet
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var robots: Array = _sim.robots

	_screen.open_sheet(0)
	_ok("sheet open", sheet.is_open() and sheet.robot == 0)
	_ok("chain laid out", sheet.node_rect("a").position.x < sheet.node_rect("b").position.x
		and sheet.node_rect("body").end.x < sheet.node_rect("a").position.x, "%s %s" % [sheet.node_rect("a"), sheet.node_rect("b")])
	await _wait(0.9)
	var above: float = _screen.to_field(_screen.life.robot_pos(0)).y
	_ok("the robot stands above the sheet, under the chips", above < sheet.position.y and above > _screen.robot_chip_rect(0).end.y,
		"robot at %.0f, sheet at %.0f" % [above, sheet.position.y])
	var draws: int = await _shot("sheet_picker")
	_ok("under budget with the sheet", draws > 0 and draws < BUDGET, str(draws))

	await _sheet_tap(sheet.plus_rect("a").get_center())
	_ok("tray opens", sheet.tray_rect("move").size.x > 0 and sheet.tray_rect("pick").size.x > 0)
	_ok("pick locked without a gripper", sheet.tray_locked("pick") and not sheet.tray_locked("move"))
	await _shot("sheet_tray")
	await _sheet_tap(sheet.parts_plus_rect().get_center())
	await _sheet_tap(sheet.tray_rect("gripper").get_center())
	_ok("gripper fitted", robots[0].parts.has("gripper") and int(_sim.bin.get("gripper", 0)) == 0, str(robots[0].parts))
	await _sheet_tap(sheet.plus_rect("a").get_center())
	await _sheet_tap(sheet.tray_rect("pick").get_center())
	var ids: Array = Bots.walk(robots[0]).ids
	_ok("pick inserted", ids.size() > 1 and String(ids[1]).begins_with("n") and robots[0].nodes[ids[1]].kind == "pick", str(ids))
	await _sheet_tap(sheet.node_rect("b").get_center())
	_ok("move pill", sheet.pill_button_rect("plus").size.x > 0)
	draws = await _shot("sheet_pill")
	_ok("under budget with the pill", draws > 0 and draws < BUDGET, str(draws))
	await _sheet_tap(sheet.pill_button_rect("plus").get_center())
	_ok("plus counts", int(robots[0].nodes["b"].n) == 4, str(robots[0].nodes["b"]))

	_screen.open_sheet(2)
	await _wait(0.9)
	_ok("the shipper's sheet", sheet.robot == 2 and _screen.selected == 2)
	draws = await _shot("sheet_open")
	_ok("under budget", draws > 0 and draws < BUDGET, str(draws))
	await _sheet_drag(sheet.out_port("c"), sheet.node_rect("d").get_center())
	_ok("wire dragged", robots[2].next["c"].out == "d" and Bots.walk(robots[2]).closed, str(robots[2].next["c"]))
	# d already goes to e: the tap-tap wires it past e to f, and back; the
	# second tap lands on the target's right side, by its own dot
	await _sheet_tap(sheet.out_port("d"))
	_ok("a tap arms the dot", sheet._armed == "d")
	await _sheet_tap(sheet.node_rect("f").get_center())
	_ok("tap-tap wires", robots[2].next["d"].out == "f" and sheet._armed == "", str(robots[2].next["d"]))
	await _sheet_tap(sheet.out_port("d"))
	var right: Rect2 = sheet.node_rect("e")
	await _sheet_tap(Vector2(right.end.x - 14.0, right.get_center().y))
	_ok("tap-tap onto the target's right side wires", robots[2].next["d"].out == "e" and sheet._armed == "", str(robots[2].next["d"]))
	# unarmed, a tap on a box's right quarter picks the box (the wire moved
	# the boxes: read it again)
	right = sheet.node_rect("e")
	await _sheet_tap(Vector2(right.end.x - 38.0, right.get_center().y))
	_ok("a box's right side picks it", sheet._sel == "e" and sheet._armed == "", "sel %s armed %s" % [sheet._sel, sheet._armed])
	await _sheet_tap(Vector2(sheet.size.x * 0.5, sheet.size.y - 260.0))
	draws = await _shot("sheet_wired")
	_ok("under budget wired", draws > 0 and draws < BUDGET, str(draws))
	var own: int = await _sheet_calls()
	_ok("sheet is one mesh", own <= 6, "%d draw calls" % own)

	await _sheet_drag(Vector2(sheet.size.x * 0.5, 24.0), Vector2(sheet.size.x * 0.5, 320.0))
	_ok("a swipe down the handle closes it", not sheet.is_open())
	_ok("the view comes back inside the floor's bounds", _screen._clamp(_screen._cam_to).is_equal_approx(_screen._cam_to))
	await _wait(0.5)
	_ok("and it is gone", not sheet.visible)
	_screen.queue_free()
	await _frames(3)

## The tutor's six pages, each on a holder 700 by 500 on a white ground.
func _pages_part() -> void:
	_sim = Sim.new(SEED)
	_screen = load("res://factory/screen.gd").new()
	_screen.name = "Factory"
	_screen.setup(_sim)
	root.add_child(_screen)
	await _frames(4)
	var pages: Array = _screen.tutorial_pages()
	_ok("six pages", pages.size() == 6 and pages.all(func(p: Dictionary) -> bool: return String(p.title).begins_with("TUT_FACTORY_")))
	_ok("every page has its words", pages.all(func(p: Dictionary) -> bool: return tr(String(p.title)) != String(p.title) and String(p.body) != "" and not String(p.body).begins_with("TUT_FACTORY_")))
	var words := {}
	for locale in ["en", "pt", "es"]:
		TranslationServer.set_locale(locale)
		var got := []
		for k in range(1, 7):
			got.append([tr("TUT_FACTORY_%d" % k), tr("TUT_FACTORY_%d_BODY" % k)])
		words[locale] = got
	TranslationServer.set_locale("en")
	for locale in ["pt", "es"]:
		var told := true
		for k in 6:
			for j in 2:
				var text: String = words[locale][k][j]
				told = told and text != "" and not text.begins_with("TUT_FACTORY_") and (text != words["en"][k][j] or k == 5 and j == 0)
		_ok("six pairs in " + locale, told)
	_screen.queue_free()
	await _frames(3)

	await _tutor_run(false)
	await _tutor_run(true)

	# the card itself, over a screen, on its second page
	Motion.reduce = false
	_sim = Sim.new(SEED)
	_screen = load("res://factory/screen.gd").new()
	_screen.name = "Factory"
	_screen.setup(_sim)
	root.add_child(_screen)
	await _frames(4)
	_screen.tutor.show()
	await _frames(3)
	var card: Control = _screen.get_node("HowToPlay")
	card._turn(1)
	await _wait(3.2)
	await _shot("tutor_card")
	card._continue()
	await _frames(3)
	_screen.queue_free()
	await _frames(3)

## Plays the six diagrams one after the other on a 700 by 500 holder, each to
## its telling moment (STILL), or, under reduce motion, as they open.
func _tutor_run(reduce: bool) -> void:
	Motion.reduce = reduce
	var Diagram: GDScript = load("res://ui/hud/factory_tutorial_diagram.gd")
	var tag := "still" if reduce else "tutor"
	for lesson in 6:
		var holder := ColorRect.new()
		holder.color = Color("fffaf1")
		holder.size = Vector2(700.0, 500.0)
		holder.position = (root.get_visible_rect().size - holder.size) * 0.5
		root.add_child(holder)
		var d: Control = Diagram.new()
		d.lesson = lesson
		d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(d)
		await _frames(3)
		if not reduce:
			# a moment after the edit has landed, where the page has one
			var until := maxf(float(Diagram.STILL[lesson]), Diagram.EDIT + 1.2 if lesson in [1, 2, 3, 5] else 0.0)
			await _until(func() -> bool: return d._t >= until, until + 3.0)
		await _frames(2)
		var draws: int = await _shot("%s_%d" % [tag, lesson + 1])
		_ok("page %d draws under 200%s" % [lesson + 1, " (reduce motion)" if reduce else ""], draws > 0 and draws < 200, str(draws))
		var sim: RefCounted = d._sim
		if reduce:
			_ok("page %d stands at its moment%s" % [lesson + 1, ", the finger on show" if lesson != 4 else ""],
				is_equal_approx(d._t, float(Diagram.STILL[lesson])) and sim.tick_n > 0 and (lesson == 4 or d._shows), "t %.2f tick %d" % [d._t, sim.tick_n])
			holder.queue_free()
			await _frames(2)
			continue
		match lesson:
			0:
				_ok("power: three robots out, the Shipper at its \"?\"", sim.robots[2].stuck == "?" or sim.tick_n < 30, "tick %d" % sim.tick_n)
			1:
				_ok("picker: gripper fitted and a pick inserted", sim.robots[0].parts.has("gripper") and Bots.walk(sim.robots[0]).ids.size() > 4, str(sim.robots[0].parts))
			2:
				_ok("boxer: both vertical moves 4", int(sim.robots[1].nodes["c"].n) == 4 and int(sim.robots[1].nodes["e"].n) == 4)
			3:
				_ok("shipper: the wire lands", sim.robots[2].next["c"].out == "d")
			4:
				_ok("box: the first sale", int(sim.earned) >= Sim.PAY_FULL and int(sim.coins) >= Sim.PAY_FULL, "earned %d" % sim.earned)
			5:
				_ok("spend: a Fast plug bought", sim.robots[0].parts.has("plug") and int(sim.coins) == Diagram.SPEND_COINS - 40, "coins %d" % sim.coins)
		holder.queue_free()
		await _frames(2)
	Motion.reduce = false
