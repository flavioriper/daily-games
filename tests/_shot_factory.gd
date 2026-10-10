extends SceneTree

## Factory's screen (factory/screen.gd), played by touches and shot; then the
## tab's card (ui/menu/factory_tab.gd) alone. Windowed, one run at a time:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_factory.gd -- <outdir> > <log> 2>&1
##
## (add `--rendering-driver opengl3_angle` before `--script` for the phone's
## driver, and `reduce` after <outdir> for reduce motion). It builds the
## screen by hand on a land of its own (`Sim.new(7)`, kept in a throwaway
## file that is deleted as it ends) and goes through a first session with
## real ScreenTouch and ScreenDrag events handed to the screen's own input
## handler: a tree tapped and bitten down, Belt picked, a belt dragged from
## the log to the market, the log sold, the plate card from a plus, a second
## plate bought. Then a late land of four plates is built through the sim's
## own actions and stepped until its kiln and retort work and the market's
## counter is stacked; a machine is placed by a finger, a belt sold by a
## held one, the view dragged and pinched; the cards, the drawer, the far
## zoom and the tutorial's three pages are shot. Each step that matters
## prints PASS or FAIL, each shot its draw calls.

const SEED := 7
const SAVE := "user://factory_harness.cfg"
## The tree the session fells (seed 7), where its log lies, and the drag.
const TREE := Vector2i(5, 2)
const LOG := Vector2i(5, 3)
const DRAG := [Vector2(5.5, 3.5), Vector2(5.5, 4.5), Vector2(5.5, 5.5), Vector2(5.5, 6.5), Vector2(6.4, 6.5)]
const WANT_BELTS := {Vector2i(5, 3): 1, Vector2i(5, 4): 1, Vector2i(5, 5): 1, Vector2i(5, 6): 0}

var Art: GDScript
var Sim: GDScript
var Motion: GDScript
var _out := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/f811faee-d34c-4697-9443-559f872b4e16/scratchpad"
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
	_borrow_words()
	_run()

## Until Factory's rows are in locale/ui.csv its keys would show raw and
## every line with a figure in it would fail to format: the rows are read
## from `factory_locale_rows.csv` beside <outdir> when the keys are not
## known yet. Once they are merged this does nothing.
func _borrow_words() -> void:
	TranslationServer.set_locale("en")
	if TranslationServer.translate("FACTORY_BELT") != &"FACTORY_BELT":
		return
	var f := FileAccess.open(_out.get_base_dir().path_join("factory_locale_rows.csv"), FileAccess.READ)
	if f == null:
		print("     (no words: the FACTORY_ keys are neither in the locale nor beside the shots)")
		return
	var words := Translation.new()
	words.locale = "en"
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			words.add_message(row[0], row[1])
	TranslationServer.add_translation(words)

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

## Where a tile-space point is on the screen now.
func _at(t: Vector2) -> Vector2:
	return _screen.screen_of(t)

## A tree is tapped on its crown, not on its tile.
func _crown(tile: Vector2i) -> Vector2:
	var look: int = _sim.tree_at(tile).look
	return _at(Vector2(tile) + Vector2(0.5, 0.5)) - Vector2(0.0, Art.height(look) * 0.45 * _screen._zoom)

func _look(t: Vector2, far := false) -> void:
	_screen.set_far(far)
	_screen._cam_raw = _screen.life.seen(t)
	_screen._cam_to = _screen.life.seen(t)
	_screen._cam = _screen.life.seen(t)
	_screen._zoom = _screen._near * (0.5 if far else 1.0)
	await _frames(3)

func _press_button(b: Button) -> void:
	b.pressed.emit()
	await _frames(2)

# --- the run ---

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
	await _wait(0.8)
	await _shot("new_land")

	# a tree, tapped on its crown
	await _tap(_crown(TREE))
	var tree: Dictionary = _sim.tree_at(TREE)
	_check("a tap on the crown sets a beaver to the tree", tree.state == "bitten", str(tree.state))
	await _wait(1.1)
	await _shot("beaver")
	await _until(func() -> bool: return tree.state == "stump", 4.0)
	await _wait(0.45)
	await _shot("falling")
	var lies := await _until(func() -> bool: return _sim.items.has(LOG), 3.0)
	_check("the tree is felled and its log lies beside the stump", tree.state == "stump" and lies, str(_sim.items.keys()))
	await _wait(0.3)
	await _shot("log")

	# the drawer, Belt, and a drag from the log to the market
	await _press_button(_screen._drawer_b)
	_check("the drawer opens", _screen.drawer_open())
	await _wait(0.3)
	await _shot("drawer")
	await _press_button(_screen._tiles.belt.button)
	_check("Belt is picked and the drawer shut", _sim.picked == "belt" and not _screen.drawer_open())
	var cam: Vector2 = _screen._cam
	# hold and swipe: a straight run down from the log, nothing laid until
	# the finger lifts; then a second from its corner to the market
	await _hold([_at(DRAG[0]), _at(DRAG[3])])
	_check("held, the run is shown and nothing is laid yet", _sim.belts.is_empty() and _screen._run.get("tiles", []).size() == 4, str(_screen._run))
	_touch(_at(DRAG[3]), false)
	await _frames(2)
	var straight: bool = _sim.belts.size() == 4
	for tile: Vector2i in WANT_BELTS:
		straight = straight and _sim.belts.get(tile, -1) == 1
	_check("lifting lays the run, a straight line facing the swipe", straight, str(_sim.belts))
	await _drag([_at(DRAG[3]), _at(DRAG[4])])
	var laid := true
	for tile: Vector2i in WANT_BELTS:
		laid = laid and _sim.belts.get(tile, -1) == WANT_BELTS[tile]
	_check("a swipe from the run's end to the market turns its corner into the market", laid and _sim.belts.size() == WANT_BELTS.size(), str(_sim.belts))
	_check("the drag did not pan the view", _screen._cam == cam)
	_check("four belts cost four coins", _sim.coins == Sim.START_COINS - 4, str(_sim.coins))
	await _wait(1.6)
	await _shot("log_riding")
	var sold := await _until(func() -> bool: return _sim.earned > 0, 14.0)
	_check("the log reaches the market and is sold: coins up", sold and _sim.coins == Sim.START_COINS - 3, "coins %d" % _sim.coins)
	await _wait(0.25)
	await _shot("sold")
	# a tap on a laid belt turns it a quarter, and back round
	await _tap(_at(Vector2(5.5, 4.5)))
	_check("a tap on a belt turns it a quarter", _sim.belts[Vector2i(5, 4)] == 2, str(_sim.belts[Vector2i(5, 4)]))
	for i in 3:
		await _tap(_at(Vector2(5.5, 4.5)))
	await _press_button(_screen._drawer_b)
	_check("the drawer's button puts the belt down", _sim.picked == "")

	# a plus, the plate card, a second plate
	await _tap(_at(Vector2(12.0, 4.0)) + Vector2(-34.0, 0.0))
	_check("a tap on a plus opens the plate card", _screen.card_open() and _screen._card_for == "plate")
	await _wait(0.4)
	await _shot("plate_card")
	var quarry: Button = _screen._card_slot.find_child("Quarry", true, false)
	await _press_button(quarry)
	_check("a plate the coins do not reach is refused", _sim.plates.size() == 1 and _screen.card_open())
	_sim.coins = 60
	await _frames(2)
	await _press_button(quarry)
	_check("the second plate is bought", _sim.plates.size() == 2 and _sim.plates.get(Vector2i(1, 0), "") == "quarry" and not _screen.card_open(), str(_sim.plates))
	await _wait(1.3)
	await _shot("plate_rising")
	await _wait(2.6)
	await _shot("second_plate")
	await _press_button(_screen._drawer_b)
	await _wait(0.3)
	await _shot("drawer_unlocked")
	await _press_button(_screen._drawer_b)

	await _late_land()
	await _hands()
	await _cards()
	await _turns()
	await _swipes()
	await _bends()
	await _tutorial()
	await _tab()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s  %d failed" % ["DONE" if _fails == 0 else "DONE WITH FAILURES", _fails])
	quit()

func _lay(tile: Vector2i, facing: int) -> void:
	if not _sim.can_lay(tile) or not _sim.lay_belt(tile, facing):
		print("     (no belt on %s)" % tile)

## Four plates (forest, quarry, meadow, forest) with belts across all, two
## fires lit, a kiln and a retort working and the market's counter stacked:
## built through the sim's own actions and stepped, not waited for.
func _late_land() -> void:
	_sim.coins = 100000
	_check("the third and fourth plates are bought", _sim.buy_plate(Vector2i(0, 1), "meadow") and _sim.buy_plate(Vector2i(1, 1), "forest"))
	# the meadow: a kiln and a retort, a fire each, a belt in and a belt out
	var built := true
	built = _sim.place("kiln", Vector2i(2, 10), 0) and built
	built = _sim.place("firebox", Vector2i(2, 11), 0) and built
	built = _sim.place("retort", Vector2i(2, 13), 0) and built
	built = _sim.place("firebox", Vector2i(2, 14), 0) and built
	_check("a kiln, a retort and two fire boxes are placed", built)
	for row in [10, 11, 13, 14]:
		_lay(Vector2i(0, row), 0)
		_lay(Vector2i(1, row), 0)
	for x in [4, 5, 6]:
		_lay(Vector2i(x, 10), 0)
	for y in [10, 9, 8]:
		_lay(Vector2i(7, y), 3)
	for x in [4, 5]:
		_lay(Vector2i(x, 13), 0)
	for y in [13, 12, 11]:
		_lay(Vector2i(6, y), 3)
	# the quarry: a row along its front edge into the market's side
	for x in range(14, 7, -1):
		_lay(Vector2i(x, 6), 2)
	# the far forest: down its near edge and round the corner to the market
	for y in range(12, 7, -1):
		_lay(Vector2i(8, y), 3)
	_lay(Vector2i(8, 7), 2)
	_sim.upgrade("market")
	await _frames(2)
	_run_on(4.0)
	await _look(Vector2(3.5, 11.5))
	await _wait(0.4)
	await _shot("building")
	_run_on(45.0)
	var all_built := true
	for id: int in _sim.modules:
		all_built = all_built and _sim.modules[id].built
	_check("the machines are built", all_built)
	# fuel and work, by belt
	for i in 2:
		_sim.put(Vector2i(0, 11), "log")
		_sim.put(Vector2i(0, 14), "log")
		_run_on(2.5)
	_sim.put(Vector2i(0, 10), "stone")
	_sim.put(Vector2i(0, 13), "log")
	_run_on(6.0)
	await _frames(2)
	await _shot("fuel_waiting")
	# the fires are lit by a finger
	for fire: Vector2i in [Vector2i(2, 11), Vector2i(2, 14)]:
		await _tap(_at(Vector2(fire) + Vector2(0.5, 0.5)) + Vector2(0.0, -14.0))
	var lit := true
	for fire: Vector2i in [Vector2i(2, 11), Vector2i(2, 14)]:
		lit = lit and _sim.module_at(fire).lit
	_check("a tap on a fire box with fuel waiting lights it", lit)
	_run_on(4.0)
	var kiln: Dictionary = _sim.module_at(Vector2i(2, 10))
	var retort: Dictionary = _sim.module_at(Vector2i(2, 13))
	_check("the kiln and the retort work on their fires", _sim.working(kiln) and float(kiln.share) > 0.0 and _sim.working(retort) and float(retort.share) > 0.0,
		"kiln %s %.2f, retort %s %.2f" % [kiln.inp, kiln.share, retort.inp, retort.share])
	# things on the way: rocks chipped, trees tapped, the market's counter stacked
	for tile: Vector2i in _sim.rocks:
		_sim.tap(tile)
	var tapped := 0
	for id: int in _sim.trees:
		if _sim.trees[id].state == "standing" and tapped < 4 and id % 2 == 0:
			_sim.tap(_sim.trees[id].tile)
			tapped += 1
	for i in 9:
		_sim.put(Vector2i(7, 9), ["log", "stone", "lime", "charcoal"][i % 4])
		_sim.put(Vector2i(12, 6), "stone")
		_sim.put(Vector2i(8, 11), "log")
		_run_on(1.2)
	_check("the market's counter is stacked", (_sim.market.wait as Array).size() >= 4, str(_sim.market.wait))
	await _look(Vector2(3.5, 11.5))
	await _wait(0.5)
	await _shot("late_meadow")
	await _look(Vector2(6.5, 6.0))
	await _wait(0.3)
	await _shot("late_market")
	await _look(Vector2(11.5, 4.5))
	await _wait(0.3)
	await _shot("late_quarry")
	await _look(Vector2(11.5, 11.5))
	await _wait(0.3)
	await _shot("late_far_forest")
	await _look(Vector2(8.0, 8.0), true)
	await _wait(0.5)
	await _shot("late_zoomed_out")

## What a finger does on the late land: a machine placed under a ghost, a
## belt sold by holding, the view dragged, two fingers pinching.
func _hands() -> void:
	await _look(Vector2(4.0, 12.0))
	_screen.pick("retort")
	_screen._facing = 1
	var before: int = _sim.modules.size()
	_touch(_at(Vector2(4.5, 14.5)), true)
	await _frames(2)
	_move(_at(Vector2(4.5, 14.8)))
	await _frames(3)
	await _shot("ghost")
	_touch(_at(Vector2(4.5, 14.8)), false)
	await _frames(2)
	var stood: Dictionary = _sim.module_at(Vector2i(4, 14))
	_check("a machine picked is stood where the finger lifts, facing as the last belt",
		_sim.modules.size() == before + 1 and not stood.is_empty() and stood.kind == "retort" and stood.facing == 1 and _sim.picked == "", str(stood))
	# on the market it does not fit: nothing is placed and it stays picked
	_screen.pick("firebox")
	_touch(_at(Vector2(6.5, 6.5)), true)
	await _frames(2)
	_touch(_at(Vector2(6.5, 6.5)), false)
	await _frames(2)
	_check("a machine that does not fit is not placed", _sim.modules.size() == before + 1 and _sim.picked == "firebox")
	_screen.pick("")
	# a finger held on a belt sells it back
	var coins: int = _sim.coins
	var belt := Vector2i(0, 14)
	_touch(_at(Vector2(belt) + Vector2(0.5, 0.5)), true)
	await _wait(0.34)
	await _shot("sell_ring")
	await _wait(0.4)
	_touch(_at(Vector2(belt) + Vector2(0.5, 0.5)), false)
	await _frames(2)
	_check("a finger held on a belt sells it back for its coin", not _sim.belts.has(belt) and _sim.coins == coins + 1, "coins %d" % (_sim.coins - coins))
	# a drag on open ground pans, and the view comes to rest
	var cam: Vector2 = _screen._cam
	var from := _at(Vector2(5.5, 15.5))
	await _drag([from, from + Vector2(-260.0, -120.0)], 8)
	_check("a drag on open ground pans the view", _screen._cam.distance_to(cam) > 150.0, str(_screen._cam - cam))
	await _wait(0.6)
	await _shot("panned")
	# far out past the land the view is held and comes back inside
	await _drag([Vector2(900.0, 1500.0), Vector2(100.0, 500.0)], 6)
	await _drag([Vector2(900.0, 1500.0), Vector2(100.0, 500.0)], 6)
	await _drag([Vector2(900.0, 1500.0), Vector2(100.0, 500.0)], 6)
	await _wait(0.8)
	_check("the view stops at the land's bounds", _screen._clamp(_screen._cam_to).distance_to(_screen._cam_to) < 1.0 and _screen._cam.distance_to(_screen._cam_to) < 40.0, str(_screen._cam_to))
	await _shot("at_the_bounds")
	# two fingers closing zoom out, opening zoom in
	_touch(Vector2(300.0, 900.0), true, 0)
	_touch(Vector2(800.0, 1300.0), true, 1)
	await _frames(2)
	_move(Vector2(480.0, 1040.0), 0)
	_move(Vector2(620.0, 1160.0), 1)
	await _frames(2)
	_touch(Vector2(480.0, 1040.0), false, 0)
	_touch(Vector2(620.0, 1160.0), false, 1)
	var out: bool = _screen._far
	_touch(Vector2(480.0, 1040.0), true, 0)
	_touch(Vector2(620.0, 1160.0), true, 1)
	await _frames(2)
	_move(Vector2(300.0, 900.0), 0)
	_move(Vector2(800.0, 1300.0), 1)
	await _frames(2)
	_touch(Vector2(300.0, 900.0), false, 0)
	_touch(Vector2(800.0, 1300.0), false, 1)
	_check("a pinch goes to the far zoom and back", out and not _screen._far)
	await _press_button(_screen._zoom_b)
	_check("the zoom button does the same", _screen._far)
	await _press_button(_screen._zoom_b)

func _cards() -> void:
	await _look(Vector2(3.5, 11.5))
	await _tap(_at(Vector2(2.5, 10.5)) + Vector2(0.0, -24.0))
	_check("a tap on a machine opens its card", _screen.card_open() and _screen._card_for == "module")
	await _wait(0.4)
	await _shot("kiln_card")
	_screen.close_card()
	await _tap(_at(Vector2(2.5, 13.5)) + Vector2(0.0, -24.0))
	await _wait(0.4)
	await _shot("retort_card")
	_screen.close_card()
	await _tap(_at(Vector2(2.5, 11.5)) + Vector2(0.0, -14.0))
	_check("a tap on a lit fire box opens its card", _screen.card_open() and _screen._card_for == "module")
	await _wait(0.4)
	await _shot("firebox_card")
	_screen.close_card()
	await _look(Vector2(6.5, 6.0))
	await _tap(_at(Vector2(7.0, 7.0)) + Vector2(0.0, -60.0))
	_check("a tap on the market opens its card", _screen.card_open() and _screen._card_for == "market")
	await _wait(0.4)
	await _shot("market_card")
	_screen.go_back()
	_check("back closes the card first", not _screen.card_open())
	await _press_button(_screen._drawer_b)
	await _wait(0.3)
	await _shot("drawer_late")
	_screen.go_back()
	_check("then the drawer", not _screen.drawer_open())

## The view turned a quarter at a time by its button, four times round. At
## each turn: every tile of the land is seen at a place of its own and read
## back from it; a belt dragged across two empty neighbours, pressed where
## they are seen, lands on those very tiles facing from the first to the
## second in the sim's own terms; and a tap where a standing tree's crown is
## drawn reaches that tree.
const TURN_BELTS := [[Vector2i(1, 8), Vector2i(2, 8), 0], [Vector2i(4, 8), Vector2i(4, 9), 1],
	[Vector2i(1, 15), Vector2i(0, 15), 2], [Vector2i(6, 15), Vector2i(6, 14), 3]]

func _turns() -> void:
	var home: Vector2 = _screen.life.seen(Vector2(3.5, 2.5))
	for q in 4:
		await _look(Vector2(8.0, 8.0), true)
		await _press_button(_screen._turn_b)
		var turn: int = _screen.life.turn
		_check("turn %d: the button turns the view a quarter" % (q + 1), turn == (q + 1) % 4, str(turn))
		await _wait(0.4)
		await _shot("turn_%d_far" % turn)
		await _look(Vector2(3.5, 11.5))
		await _wait(0.2)
		await _shot("turn_%d_meadow" % turn)
		await _look(Vector2(6.5, 6.0))
		await _wait(0.2)
		await _shot("turn_%d_market" % turn)
		# every tile seen at a place of its own, and read back from it
		var places := {}
		var back := true
		for p: Vector2i in _sim.plates:
			for y in Sim.PLATE:
				for x in Sim.PLATE:
					var tile: Vector2i = p * Sim.PLATE + Vector2i(x, y)
					var at: Vector2 = _screen.life.seen(Vector2(tile) + Vector2(0.5, 0.5))
					places[Vector2i(at.round())] = true
					back = back and Vector2i((_screen.life.tile_at(at) as Vector2).floor()) == tile \
						and Vector2i((_screen.tile_under(_screen.screen_of(Vector2(tile) + Vector2(0.5, 0.5))) as Vector2).floor()) == tile
		_check("turn %d: every tile has a place of its own and is read back from it" % turn, back and places.size() == _sim.plates.size() * 64, "%d places" % places.size())
		# a belt dragged across two empty neighbours
		var pair: Array = TURN_BELTS[q]
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var free: bool = _sim.tile_free(a) and _sim.tile_free(b)
		var had: int = _sim.belts.size()
		await _look(Vector2(a + b) * 0.5 + Vector2(0.5, 0.5))
		_screen.pick("belt")
		await _drag([_at(Vector2(a) + Vector2(0.5, 0.5)), _at(Vector2(b) + Vector2(0.5, 0.5))])
		_screen.pick("")
		_check("turn %d: a drag lays belts on the tiles under the finger, facing in the sim's terms" % turn,
			free and _sim.belts.size() == had + 2 and _sim.belts.get(a, -1) == pair[2] and _sim.belts.get(b, -1) == pair[2],
			"%s %s, %s %s, %d laid" % [a, _sim.belts.get(a, -1), b, _sim.belts.get(b, -1), _sim.belts.size() - had])
		# a tree, the nearest standing one to the eye, tapped on its crown
		var front: Dictionary = {}
		for id: int in _sim.trees:
			var tr: Dictionary = _sim.trees[id]
			if tr.state == "standing" and not tr.queued and (front.is_empty()
					or _screen.life.depth(Vector2(tr.tile)) > _screen.life.depth(Vector2(front.tile))):
				front = tr
		if front.is_empty():
			_check("turn %d: a standing tree to tap" % turn, false)
			continue
		await _look(Vector2(front.tile) + Vector2(0.5, 0.5))
		await _tap(_crown(front.tile))
		_check("turn %d: a tap where a tree's crown is drawn reaches that tree" % turn, front.state == "bitten" or front.queued, "%s %s" % [front.tile, front.state])
	_check("four turns come back to the first view", _screen.life.turn == 0 and (_screen.life.seen(Vector2(3.5, 2.5)) as Vector2).is_equal_approx(home))
	await _look(Vector2(8.0, 8.0), true)
	await _wait(0.3)
	await _shot("turned_home")
	_screen.set_far(false)

func _mid(tile: Vector2i) -> Vector2:
	return _at(Vector2(tile) + Vector2(0.5, 0.5))

## Whether every tile from `a` to `b` (a straight line) has a belt facing
## `f` and `n` belts were laid since `had`.
func _line(a: Vector2i, b: Vector2i, f: int, had: int) -> bool:
	var step := (b - a).sign()
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y)) + 1
	for i in n:
		if _sim.belts.get(a + step * i, -1) != f:
			return false
	return _sim.belts.size() == had + n

func _unlay(a: Vector2i, b: Vector2i) -> void:
	var step := (b - a).sign()
	for i in maxi(absi(b.x - a.x), absi(b.y - a.y)) + 1:
		if _sim.belts.has(a + step * i):
			_sim.sell(a + step * i)

## Hold and swipe, and the way a run flows, on a fifth plate of open meadow
## (and beside the market): at no turn of the view, then a quarter round.
func _swipes() -> void:
	_check("a fifth plate, open meadow, for the swipes", _sim.buy_plate(Vector2i(0, 2), "meadow"))
	_run_on(4.0)
	_screen.pick("belt")
	for turn in 2:
		var say := "turn %d: " % turn
		if turn == 1:
			await _press_button(_screen._turn_b)
		await _look(Vector2(4.0, 19.0))
		# a free run: four tiles, the finger wandering off the line
		var had: int = _sim.belts.size()
		await _hold([_mid(Vector2i(3, 17)), _at(Vector2(6.6, 17.9))])
		_check(say + "a diagonal drag stays on one axis, and nothing is laid while held",
			_sim.belts.size() == had and _screen._run.get("tiles", []) == [Vector2i(3, 17), Vector2i(4, 17), Vector2i(5, 17), Vector2i(6, 17)] and _screen._run.facing == 0, str(_screen._run))
		await _shot("swipe_free_turn_%d" % turn)
		_touch(_at(Vector2(6.6, 17.9)), false)
		await _frames(2)
		_check(say + "a swipe of four tiles lays four belts in a line facing the swipe", _line(Vector2i(3, 17), Vector2i(6, 17), 0, had), str(_sim.belts.size() - had))
		# from behind the run's tail, dragged away from it: it flows into the run
		had = _sim.belts.size()
		await _hold([_mid(Vector2i(2, 17)), _mid(Vector2i(0, 17))])
		_check(say + "held, the line already points into the placed belt", _screen._run.get("facing", -1) == 0 and _screen._run.tiles.size() == 3, str(_screen._run))
		await _shot("swipe_settled_turn_%d" % turn)
		_touch(_mid(Vector2i(0, 17)), false)
		await _frames(2)
		_check(say + "a swipe away from a placed belt's tail flows into it", _line(Vector2i(0, 17), Vector2i(2, 17), 0, had), str(_sim.belts))
		# from the run's front, off to the side: it flows on from it
		had = _sim.belts.size()
		await _drag([_mid(Vector2i(7, 17)), _mid(Vector2i(7, 20))])
		_check(say + "a swipe from a placed belt's front flows on from it", _line(Vector2i(7, 17), Vector2i(7, 20), 1, had), str(_sim.belts.size() - had))
		# the coins short: only what they reach
		had = _sim.belts.size()
		var purse: int = _sim.coins
		_sim.coins = 2
		await _hold([_mid(Vector2i(1, 19)), _mid(Vector2i(4, 19))])
		_sim.coins = 2
		await _frames(2)
		_check(say + "held with two coins, two of the four are within reach", _screen._run.get("lay", -1) == 2 and _screen._run.tiles.size() == 4, str(_screen._run))
		await _shot("swipe_short_turn_%d" % turn)
		# the market sold meanwhile: the purse is two again as the finger lifts
		_sim.coins = 2
		_touch(_mid(Vector2i(4, 19)), false)
		await _frames(2)
		_check(say + "coins short: only what they reach is laid", _line(Vector2i(1, 19), Vector2i(2, 19), 0, had), "%d laid" % (_sim.belts.size() - had))
		_sim.coins = purse
		# back to the first tile and up: just that one; a tap: one more
		had = _sim.belts.size()
		await _drag([_mid(Vector2i(1, 21)), _mid(Vector2i(3, 21)), _mid(Vector2i(1, 21))])
		await _tap(_mid(Vector2i(5, 22)))
		_check(say + "dragged back to its first tile a swipe lays one, and a tap lays one", _sim.belts.size() == had + 2 and _sim.belts.has(Vector2i(1, 21)) and _sim.belts.has(Vector2i(5, 22)), str(_sim.belts.size() - had))
		# into the market from the open side, and away from its edge
		await _look(Vector2(5.0, 7.5))
		had = _sim.belts.size()
		await _drag([_mid(Vector2i(3, 7)), _mid(Vector2i(6, 7))])
		_check(say + "a swipe ending at the market stops at it and flows into it", _line(Vector2i(3, 7), Vector2i(5, 7), 0, had), str(_sim.belts.size() - had))
		_unlay(Vector2i(3, 7), Vector2i(5, 7))
		await _frames(2)
		had = _sim.belts.size()
		await _drag([_mid(Vector2i(5, 7)), _mid(Vector2i(3, 7))])
		_check(say + "a swipe from the market's edge, dragged away, still flows into it", _line(Vector2i(3, 7), Vector2i(5, 7), 0, had), str(_sim.belts))
		_unlay(Vector2i(3, 7), Vector2i(5, 7))
		# the rule itself, as the one function has it
		var rule: bool = _screen.run_facing(_sim, [Vector2i(2, 22), Vector2i(3, 22)], 0) == 0 \
			and _screen.run_facing(_sim, [Vector2i(3, 18), Vector2i(3, 19)], 1) == 3 \
			and _screen.run_facing(_sim, [Vector2i(7, 21), Vector2i(7, 22)], 1) == 1 \
			and _screen.run_facing(_sim, [Vector2i(7, 22), Vector2i(7, 21)], 3) == 1
		_check(say + "the rule: a free run follows the finger, one swiped off a belt's side joins it, one off a belt's front flows on either way it is swiped", rule)
		for row in [17, 19, 21, 22]:
			_unlay(Vector2i(0, row), Vector2i(7, row))
		_unlay(Vector2i(7, 17), Vector2i(7, 20))
		await _frames(2)
	_screen.pick("")
	# raised belts with things riding, a quarter round: by the market, by the kiln, from far
	for i in 6:
		_sim.put(Vector2i(4 + i % 3, 10), ["stone", "log", "lime"][i % 3])
		_sim.put(Vector2i(10 + i % 3, 6), "stone")
		_run_on(0.8)
	await _look(Vector2(6.5, 6.0))
	await _wait(0.4)
	await _shot("raised_market_turn_1")
	await _look(Vector2(3.5, 11.5))
	await _shot("raised_kiln_turn_1")
	await _look(Vector2(8.0, 10.0), true)
	await _wait(0.3)
	await _shot("raised_far_turn_1")
	for i in 3:
		await _press_button(_screen._turn_b)
	await _look(Vector2(6.5, 6.0))
	await _wait(0.4)
	await _shot("raised_market_turn_0")
	await _look(Vector2(3.5, 11.5))
	await _shot("raised_kiln_turn_0")
	await _look(Vector2(8.0, 10.0), true)
	await _wait(0.3)
	await _shot("raised_far_turn_0")
	_screen.set_far(false)

## A belt fed by its side alone is a bend: an L and an S laid by swipes on
## the open plate, a T that stays straight, and what rides drawn round the
## arc; at no turn and a quarter round, shot near and at twice that.
func _bends() -> void:
	var life: RefCounted = _screen.life
	for turn in 2:
		var say := "turn %d: " % turn
		if turn == 1:
			await _press_button(_screen._turn_b)
		await _look(Vector2(3.5, 19.5))
		_screen.pick("belt")
		await _drag([_mid(Vector2i(1, 17)), _mid(Vector2i(4, 17))])
		await _drag([_mid(Vector2i(4, 17)), _mid(Vector2i(4, 20))])
		_check(say + "a run swiped off the end of another turns the corner into itself",
			_sim.belts.get(Vector2i(4, 17), -1) == 1 and _sim.belts.get(Vector2i(4, 20), -1) == 1 and _sim.belts.get(Vector2i(3, 17), -1) == 0, str(_sim.belts.get(Vector2i(4, 17), -1)))
		await _drag([_mid(Vector2i(4, 20)), _mid(Vector2i(7, 20))])
		await _frames(2)
		_check(say + "the L's corner is a bend from the side it is fed by, and the S's the other bend",
			life.shape(Vector2i(4, 17)) == 1 and life.shape(Vector2i(4, 20)) == 2 and life.shape(Vector2i(3, 17)) == 0 and life.shape(Vector2i(4, 18)) == 0,
			"%d %d" % [life.shape(Vector2i(4, 17)), life.shape(Vector2i(4, 20))])
		# what rides the corner at its half way is on the arc: off both centre lines, in the tile
		var corner := Vector2i(4, 17)
		var it := {"id": -1, "kind": "log", "at": 0.5, "from": 0, "was": Vector2(corner) + Vector2(0.5, 0.5)}
		var rel: Vector2 = life.item_at(corner, it) - (Vector2(corner) + Vector2(0.5, 0.5))
		_check(say + "an item half way round the bend is drawn on the arc", absf(rel.x) > 0.08 and absf(rel.y) > 0.08 and absf(rel.x) < 0.5 and absf(rel.y) < 0.5 and rel.x < 0.0 and rel.y > 0.0, str(rel))
		# a T: a side belt into a through belt leaves it straight
		await _drag([_mid(Vector2i(0, 22)), _mid(Vector2i(3, 22))])
		await _drag([_mid(Vector2i(1, 20)), _mid(Vector2i(1, 22))])
		await _frames(2)
		_check(say + "a belt loaded from the side as well as from behind stays straight",
			_sim.belts.get(Vector2i(1, 21), -1) == 1 and _sim.belts.get(Vector2i(1, 22), -1) == 0 and life.shape(Vector2i(1, 22)) == 0, "%s %d" % [_sim.belts.get(Vector2i(1, 21), -1), life.shape(Vector2i(1, 22))])
		_screen.pick("")
		for i in 7:
			_sim.put(Vector2i(1, 17), ["log", "stone", "lime", "charcoal"][i % 4])
			_run_on(1.5)
		await _look(Vector2(4.5, 19.0))
		await _wait(0.4)
		await _shot("bends_turn_%d" % turn)
		var near: float = _screen._near
		_screen._near = near * 2.0
		await _look(Vector2(4.5, 17.8))
		await _shot("bend_l_2x_turn_%d" % turn)
		await _look(Vector2(4.6, 20.2))
		await _shot("bend_s_2x_turn_%d" % turn)
		_screen._near = near
		await _look(Vector2(4.5, 19.0))
		for row in [17, 20, 22]:
			_unlay(Vector2i(0, row), Vector2i(7, row))
		_unlay(Vector2i(4, 17), Vector2i(4, 20))
		_unlay(Vector2i(1, 20), Vector2i(1, 22))
		await _frames(2)
	for i in 3:
		await _press_button(_screen._turn_b)

func _tutorial() -> void:
	_screen.tutor.show()
	await _wait(2.2)
	await _shot("tutorial_tree")
	var card: Control = _screen.get_node("HowToPlay")
	card._turn(1)
	await _wait(2.7)
	await _shot("tutorial_belt")
	card._turn(1)
	await _wait(4.4)
	await _shot("tutorial_plate")
	_screen.go_back()
	await _frames(3)
	_check("back closes the tutorial", not _screen.tutor.is_open())

## The tab alone, at the column's size. The screen leaves first and keeps
## the land; the tab reads that file, so its card is the late land.
func _tab() -> void:
	# something on its way to the market, for the tab to be seen selling
	for x in [4, 5, 6]:
		_sim.put(Vector2i(x, 10), "log")
	var closed := [false]
	_screen.closed.connect(func() -> void: closed[0] = true)
	_screen.go_back()
	_check("back leaves the screen, the land kept", closed[0] and FileAccess.file_exists(SAVE))
	_screen.queue_free()
	await _frames(3)
	var page := ColorRect.new()
	page.color = load("res://core/palette.gd").PAPER
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.theme = load("res://ui/theme.gd").make()
	root.add_child(page)
	var tab: Control = load("res://ui/menu/factory_tab.gd").new()
	tab.name = "FactoryTab"
	tab.position = Vector2(40.0, 330.0)
	tab.size = Vector2(1000.0, 1340.0)
	page.add_child(tab)
	await _frames(4)
	tab.refresh()
	_check("the tab reads the land the screen kept", tab.sim.plates.size() == _sim.plates.size() and tab.sim.coins == _sim.coins, "plates %d" % tab.sim.plates.size())
	var earned: int = tab.sim.earned
	await _wait(1.5)
	await _shot("tab")
	await _until(func() -> bool: return tab.sim.earned > earned, 12.0)
	_check("the land runs on the tab: something was sold there", tab.sim.earned > earned)
	var lent: RefCounted = tab.lend()
	_check("lent, the tab stops stepping", lent == tab.sim and not tab.is_processing())
	tab.returned()
	_check("handed back, it steps again", tab.is_processing())
	tab.visible = false
	await _frames(2)
	_check("hidden, it does not", not tab.is_processing())
	page.queue_free()
	await _frames(3)
