extends SceneTree

## Factory's later things (2026-10-12), played by touches and shot: the
## mine and the kiln it opens, and what later passes add (each a section of
## its own). Windowed, one run at a time:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_factory_works.gd -- <outdir> > <log> 2>&1
##
## (add `--rendering-driver opengl3_angle` before `--script` for the phone's
## driver, and `reduce` after <outdir> for reduce motion). The screen is
## built by hand on a land of its own, kept in a throwaway file that is
## deleted as it ends. tests/_shot_factory.gd is the first session and the
## screen's own checks; this one only adds.

const SEED := 7
const SAVE := "user://factory_works_harness.cfg"
const F := Vector2i(0, -1)
const MINE := Vector2i(1, -1)
const EAST := Vector2i(1, 0)

var Art: GDScript
var Sim: GDScript
var Motion: GDScript
var _out := "/tmp/shot_factory_works"
var _screen: Control
var _sim: RefCounted
var _fails := 0
var _n := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	Art = load("res://factory/art.gd")
	Sim = load("res://factory/sim.gd")
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

func _check(what: String, ok: bool, more := "") -> void:
	if not ok:
		_fails += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", what, "" if more == "" else "  (" + more + ")"])

func _shot(called: String) -> void:
	await _frames(2)
	_n += 1
	var path := "%s/%02d_%s.png" % [_out, _n, called]
	root.get_texture().get_image().save_png(path)
	print("%s  draw calls %d" % [path, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])

## The land goes on `seconds` at once: the screen's own frame, a tick each.
func _run_on(seconds: float) -> void:
	for i in int(seconds / 0.1):
		_screen._process(0.1)

func _touch(pos: Vector2, pressed: bool, finger := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = pos
	e.pressed = pressed
	_screen._on_field_input(e)

func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	await _frames(2)
	_touch(pos, false)
	await _frames(2)

func _at(t: Vector2) -> Vector2:
	return _screen.screen_of(t)

func _badge(p: Vector2i) -> Vector2:
	return _screen.world.position + _screen.badge_at(p) * _screen._zoom

func _look(t: Vector2, far := false) -> void:
	_screen.set_far(far)
	_screen._cam_raw = _screen.life.seen(t)
	_screen._cam_to = _screen.life.seen(t)
	_screen._cam = _screen.life.seen(t)
	_screen._zoom = _screen._near * (0.5 if far else 1.0)
	await _frames(3)

func _lay(from: Vector2i, n: int, facing: int) -> void:
	for i in n:
		_sim.lay_belt(from + Sim.DIRS[facing] * i, facing)

func _run() -> void:
	await _frames(8)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_sim = Sim.new(SEED)
	_screen = load("res://factory/screen.gd").new()
	_screen.name = "Factory"
	_screen.setup(_sim)
	root.add_child(_screen)
	await _frames(4)
	# the harness is the hand: the real pointer over the window is not
	_screen.field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _wait(0.6)
	await _mine()
	await _belts()
	await _steam()
	await _bridge()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s  %d failed" % ["DONE" if _fails == 0 else "DONE WITH FAILURES", _fails])
	quit()

## The mine: offered on the plate card, bought, tapped on a rock, its card
## from its badge, and a stone burnt to lime by the kiln it opens.
func _mine() -> void:
	_sim.coins = 5000
	_sim.buy_plate(EAST, "neutral")
	await _look(Vector2(12.0, -2.0))
	var plus: Vector2 = _screen.world.position + _screen.life.plus_at(MINE) * _screen._zoom
	await _tap(plus)
	await _wait(0.5)
	_check("the plus opens the plate card", _screen.card_open())
	await _shot("plate_card_three_kinds")
	var tile: Button = _screen._card.find_child("Mine", true, false)
	_check("which offers a mine", tile != null)
	if tile != null:
		tile.pressed.emit()
	await _wait(0.3)
	_check("a mine is bought there", _sim.plates.get(MINE, "") == "mine" and not _screen.card_open())
	_run_on(4.0)
	await _wait(0.4)
	await _shot("mine_new")
	# a rock is tapped on its body
	var rock := {}
	for id: int in _sim.trees:
		var tr: Dictionary = _sim.trees[id]
		if Sim.plate_of(tr.tile) == MINE and (rock.is_empty() or _screen.life.depth(Vector2(tr.tile)) > _screen.life.depth(Vector2(rock.tile))):
			rock = tr
	var body: Vector2 = _at(Vector2(rock.tile) + Vector2(0.5, 0.5)) - Vector2(0.0, 20.0 * _screen._zoom)
	var h: Dictionary = _screen.hit(body)
	_check("a rock reads as the mine, at its tile", h.what == "source" and h.tile == rock.tile, str(h))
	for i in 3:
		await _tap(body)
	_run_on(0.4)
	await _frames(3)
	var out: Vector2i = Sim.gate(MINE, 1) + Sim.DIRS[1]
	var lying: int = (_sim.items.get(out, []) as Array).size()
	_check("three taps are three stones, two lying past its gate", lying == 2 and int(_sim.sources[MINE].stock) == 1 and _sim.items[out][0].kind == "stone",
		"%d lying, %d held" % [lying, int(_sim.sources[MINE].stock)])
	await _shot("mine_tapped")
	await _tap(_badge(MINE))
	await _wait(0.5)
	_check("its badge opens its card", _screen.card_open() and _screen._card_for == "mine")
	await _shot("mine_card")
	_sim.upgrade(MINE * Sim.PLATE)
	await _frames(3)
	_check("its first level is a stone a second", _sim.source_rate(MINE) == 1.0)
	_screen.close_card()
	await _wait(0.3)
	# the gate's belt to a kiln, a fire beside it, the lime on to the market
	_lay(out, 2, 1)
	_check("the kiln is in the drawer now and stands", _sim.unlocked("kiln") and _sim.place("kiln", out + Vector2i(0, 2), 1) and _sim.place("firebox", out + Vector2i(-1, 2), 0))
	_lay(out + Vector2i(0, 4), 2, 1)
	_lay(out + Vector2i(0, 6), 5, 2)
	_run_on(45.0)
	var fire: Dictionary = _sim.module_at(out + Vector2i(-1, 2))
	fire.hopper.append("log")
	_sim.tap(fire.root)
	_run_on(260.0)
	await _look(Vector2(10.0, 2.0))
	await _wait(0.5)
	var kiln: Dictionary = _sim.module_at(out + Vector2i(0, 2))
	_check("the kiln burns the mine's stone and lime has been sold", kiln.built and _sim.earned >= 10, "earned %d, inp %s" % [_sim.earned, kiln.inp])
	await _shot("mine_kiln_lime")
	await _look(Vector2(10.0, 0.0), true)
	await _shot("mine_far")

## The goal chip and its card, the drawer in two columns, a splitter with
## three ways out and fast belts on one of them, laid by the hand.
func _belts() -> void:
	_sim.coins = 5000
	await _look(Vector2(4.0, 2.0))
	_check("the goal chip shows the first goal", _screen._goal_b.visible and _sim.next_goal().id == "splitter")
	await _shot("goal_chip")
	_screen._goal_b.pressed.emit()
	await _wait(0.5)
	_check("and opens the goals' card", _screen.card_open() and _screen._card_for == "goals")
	await _shot("goals_card")
	_screen.close_card()
	_sim.sold["log"] = 30
	_sim.sold["charcoal"] = 10
	await _frames(3)
	_check("two goals reached, the chip shows the third", _screen._goal_b.visible and _sim.next_goal().id == "bridge" and _sim.unlocked("fast") and _sim.unlocked("splitter"))
	_screen.open_drawer()
	await _wait(0.4)
	_check("the drawer has taken a second column", _screen._drawer.columns == 2 and _screen._tiles["fast"].button.visible and _screen._tiles["splitter"].button.visible,
		"columns %d" % _screen._drawer.columns)
	await _shot("drawer_two_columns")
	# the belts by the sim, the splitter and one fast belt by the hand
	_lay(Vector2i(3, 0), 6, 1)
	_lay(Vector2i(3, 6), 3, 0)
	(_screen._tiles["splitter"].button as Button).pressed.emit()
	await _frames(3)
	_check("Splitter is picked and the drawer shut", _sim.picked == "splitter" and not _screen.drawer_open())
	await _tap(_at(Vector2(3.5, 2.5)) + Art.BELT_LIFT * _screen._zoom)
	_check("a tap on a belt with Splitter in hand makes it one, facing as it lay", _sim.belt_kind(Vector2i(3, 2)) == "splitter" and int(_sim.belts[Vector2i(3, 2)]) == 1,
		_sim.belt_kind(Vector2i(3, 2)))
	_screen.pick("")
	_sim.lay_belt(Vector2i(4, 2), 0)
	_sim.lay_belt(Vector2i(5, 2), 0)
	_lay(Vector2i(6, 2), 4, 1)
	_sim.lay_belt(Vector2i(2, 2), 2)
	_lay(Vector2i(1, 2), 5, 1)
	_lay(Vector2i(1, 7), 5, 0)
	_sim.lay_belt(Vector2i(6, 7), 3)
	_screen.pick("fast")
	await _frames(2)
	# a swipe of Fast over the belts that lie there
	_touch(_at(Vector2(6.5, 2.5)) + Art.BELT_LIFT * _screen._zoom, true)
	await _frames(2)
	for k in range(1, 9):
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = (_at(Vector2(6.5, 2.5)) + Art.BELT_LIFT * _screen._zoom).lerp(_at(Vector2(6.5, 5.5)) + Art.BELT_LIFT * _screen._zoom, k / 8.0)
		_screen._on_field_input(e)
		await process_frame
	await _frames(2)
	_touch(_at(Vector2(6.5, 5.5)) + Art.BELT_LIFT * _screen._zoom, false)
	await _frames(3)
	var fast := true
	for y in range(2, 6):
		fast = fast and _sim.belt_kind(Vector2i(6, y)) == "fast" and int(_sim.belts[Vector2i(6, y)]) == 1
	_check("a swipe of Fast over four plain belts makes them fast, facing as they lay", fast, str(_sim.kinds))
	_screen.pick("")
	for i in 3:
		_sim.upgrade(F * Sim.PLATE)
	for i in 3:
		_sim.upgrade("market")
	var before: int = _sim.earned
	_run_on(60.0)
	await _wait(0.5)
	var ways := 0
	for way: Array in [[Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5)], [Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5)], [Vector2i(1, 3), Vector2i(1, 4), Vector2i(1, 5)]]:
		for t: Vector2i in way:
			if _sim.items.has(t):
				ways += 1
				break
	_check("logs leave the splitter by all three ways and are sold", ways == 3 and _sim.earned > before + 20, "%d ways, %d sold" % [ways, _sim.earned - before])
	await _shot("splitter_three_ways")
	_screen.turn_view()
	await _wait(0.5)
	await _look(Vector2(4.0, 3.0))
	await _shot("splitter_turned")
	_screen.turn_view()
	_screen.turn_view()
	_screen.turn_view()
	await _wait(0.4)

## Steam: a fire box with a stoker, an engine on it, a saw and a joiner on
## the engine, logs in from the splitter's side and chairs out to the market.
func _steam() -> void:
	_sim.coins = 9000
	_sim.buy_plate(Vector2i(0, 1), "neutral")
	_sim.sold["charcoal"] = 25
	_sim.sold["plank"] = 100
	_run_on(4.0)
	await _look(Vector2(3.0, 11.0))
	_screen.open_drawer()
	await _wait(0.4)
	_check("the engine, the saw and the joiner are in the drawer", _screen._tiles["engine"].button.visible and _screen._tiles["saw"].button.visible and _screen._tiles["joiner"].button.visible
		and _screen._drawer.columns == 2)
	await _shot("drawer_steam")
	# the engine by the hand, the rest by the sim
	(_screen._tiles["engine"].button as Button).pressed.emit()
	await _frames(3)
	await _tap(_at(Vector2(2.5, 10.5)))
	var engine: Dictionary = _sim.module_at(Vector2i(2, 10))
	_check("a tap with Engine in hand stands one, one tile", not engine.is_empty() and engine.kind == "engine" and engine.tiles.size() == 1 and _sim.picked == "")
	_check("a saw, a joiner and a fire box stand round it", _sim.place("saw", Vector2i(1, 10), 1) and _sim.place("joiner", Vector2i(2, 11), 0) and _sim.place("firebox", Vector2i(2, 9), 0))
	_sim.lay_belt(Vector2i(1, 7), 1)
	_lay(Vector2i(1, 8), 2, 1)
	_sim.lay_belt(Vector2i(1, 12), 0)
	_sim.lay_belt(Vector2i(2, 12), 3)
	_lay(Vector2i(4, 11), 2, 0)
	_lay(Vector2i(6, 11), 4, 3)
	await _wait(0.3)
	await _shot("steam_building")
	_run_on(62.0)
	var fire: Dictionary = _sim.module_at(Vector2i(2, 9))
	fire.hopper.append("log")
	fire.hopper.append("log")
	_sim.tap(fire.root)
	await _frames(2)
	await _tap(_at(Vector2(2.5, 9.5)) - Vector2(0.0, 20.0 * _screen._zoom))
	await _wait(0.5)
	_check("the fire box's card offers a stoker", _screen.card_open() and _screen._card.find_child("Stoker", true, false) != null and _screen._card.find_child("Stoker", true, false).visible)
	await _shot("firebox_card_stoker")
	var stoke: Button = _screen._card.find_child("Stoker", true, false).get_child(0)
	stoke.pressed.emit()
	await _frames(3)
	_check("which is fitted from it", fire.stoker and not _screen._card.find_child("Stoker", true, false).visible)
	_screen.close_card()
	await _wait(0.3)
	_run_on(150.0)
	await _wait(0.6)
	var saw: Dictionary = _sim.module_at(Vector2i(1, 10))
	var joiner: Dictionary = _sim.module_at(Vector2i(2, 11))
	_check("the engine turns on the fire's heat and the saw has sawn", float(engine.share) > 0.0 and float(saw.share) > 0.0 and (int(_sim.sold.get("chair", 0)) > 0 or int(joiner.got) > 0 or joiner.inp != "" or joiner.out != ""),
		"engine %.2f saw %.2f joiner got %d" % [float(engine.share), float(saw.share), int(joiner.got)])
	await _shot("steam_working")
	await _tap(_at(Vector2(1.5, 10.5)) - Vector2(0.0, 10.0 * _screen._zoom))
	await _wait(0.5)
	_check("a machine's card says its cycle", _screen.card_open() and _screen._card_for == "module")
	await _shot("machine_card")
	_screen.close_card()
	_run_on(240.0)
	await _wait(0.5)
	_check("chairs have been sold", int(_sim.sold.get("chair", 0)) > 0, str(_sim.sold))
	await _shot("steam_chairs")
	_screen._zoom = _screen._near * 2.2
	_screen._cam = _screen.life.seen(Vector2(2.5, 11.0))
	await _frames(3)
	await _shot("steam_close")
	for q in 3:
		_screen.turn_view()
		await _wait(0.4)
		await _look(Vector2(3.0, 11.0))
		await _shot("steam_turn_%d" % (q + 1))
	_screen.turn_view()
	await _wait(0.4)
	await _look(Vector2(4.0, 8.0), true)
	await _shot("steam_far")

## The bridge: the row of belts to the market's side crossed by a column,
## logs under and stones over.
func _bridge() -> void:
	_sim.coins = 5000
	_sim.sold["lime"] = 5
	_screen.set_far(false)
	await _look(Vector2(4.5, 4.5))
	# a column down x = 4 from y = 3 to y = 5, across the splitter's two branches' gap
	_lay(Vector2i(4, 3), 3, 1)
	_sim.lay_belt(Vector2i(4, 2), 0)
	_screen.pick("bridge")
	await _frames(2)
	await _tap(_at(Vector2(4.5, 2.5)) + Art.BELT_LIFT * _screen._zoom)
	_check("a tap on a belt with Bridge in hand makes it a bridge, facing as it lay", _sim.belt_kind(Vector2i(4, 2)) == "bridge" and int(_sim.belts[Vector2i(4, 2)]) == 0)
	_screen.pick("")
	_lay(Vector2i(4, 0), 2, 1)
	for i in 14:
		_sim.put(Vector2i(4, 0), "stone")
		_run_on(1.0)
	await _wait(0.4)
	var over: int = _sim.over.get(Vector2i(4, 2), {"items": []}).items.size()
	var stones := 0
	for t: Vector2i in [Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5)]:
		for it: Dictionary in _sim.items.get(t, []):
			stones += 1 if it.kind == "stone" else 0
	_check("stones cross over the logs' belt and go on down the column", stones > 0 and _sim.over.has(Vector2i(4, 2)), "%d past it, %d on it" % [stones, over])
	await _wait(0.6)
	print("     the bridge is at ", _at(Vector2(4.5, 2.5)) * 0.75)
	await _shot("bridge")
	_screen.turn_view()
	await _wait(0.8)
	await _look(Vector2(4.5, 3.0))
	await _wait(0.4)
	print("     the bridge is at ", _at(Vector2(4.5, 2.5)) * 0.75)
	await _shot("bridge_turned")
	_screen.turn_view()
	_screen.turn_view()
	_screen.turn_view()
	await _wait(0.3)
	_screen.open_drawer()
	await _wait(0.4)
	_check("the drawer holds eleven tiles in three columns", _screen._drawer.columns == 3, "columns %d" % _screen._drawer.columns)
	await _shot("drawer_all")
	_screen.close_drawer()
