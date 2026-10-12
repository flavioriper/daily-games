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
## handler: the forest tapped on a crown, on its floor and on its gate, two
## logs lying past the gate with no belt, the forest filled to twelve; Belt
## picked, a swipe begun inside the forest that lays nothing and one into it
## that stops at its edge, then the nine belts swiped from the gate to the
## market and the logs sold; the forest's card from its badge and its first
## level bought; the plate card from a plus and the first plate bought. Then
## a late land of six plates (three of them forests, each with a belt past a
## gate) is built through the sim's own actions and stepped until its two
## retorts work and the market's hatch has its one; a machine is placed by
## a finger and refused on a forest, a belt sold by a held one, the view
## dragged and pinched; the cards, the drawer, the far zoom, the four turns
## of the view, the swipes, the bends and the tutorial's three pages are
## shot. Each step that matters prints PASS or FAIL, each shot its draw
## calls.

const SEED := 7
const SAVE := "user://factory_harness.cfg"
## The forest a new land has and the tile past the one gate of it that leads
## on to land; the two forests the late land buys.
const F := Vector2i(0, -1)
const PAST := Vector2i(3, 0)
const WEST := Vector2i(-1, 0)
const EAST := Vector2i(1, -1)
## The nine belts of the first session, from the gate to the market.
const WANT_BELTS := {Vector2i(3, 0): 1, Vector2i(3, 1): 1, Vector2i(3, 2): 1, Vector2i(3, 3): 1, Vector2i(3, 4): 1, Vector2i(3, 5): 1,
	Vector2i(3, 6): 0, Vector2i(4, 6): 0, Vector2i(5, 6): 0}

var Art: GDScript
var Sim: GDScript
var Motion: GDScript
var _out := "/tmp/shot_factory"
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

## A sale at the market played out and shot: one lying on the hatch, the
## leaves down under it, its coin up, the leaves shut again. Under reduce
## motion nothing swings, so only the one lying and the "+1" are shot.
func _hatch() -> void:
	var life: RefCounted = _screen.life
	await _look(Vector2(6.0, 6.0))
	var lies: bool = await _until(func() -> bool: return _sim.market.wait.size() == 1 and float(_sim.market.t) > 1.5 and float(_sim.market.t) < 3.5, 12.0)
	_check("a log lies on the market's hatch, in its middle, the leaves shut", lies and life._hatch() == 0.0 and life._lying_off().length() < 0.01,
		"%s %.2f" % [_sim.market.wait, life._lying_off().length()])
	await _shot("hatch_lying")
	var was: int = _sim.earned
	var coins := [0]
	var count := func(n: int) -> void: coins[0] += n
	life.coined.connect(count)
	var sold: bool = await _until(func() -> bool: return _sim.earned > was, 6.0)
	if Motion.reduce:
		_check("under reduce motion a sale is its coin at once, nothing swinging", sold and coins[0] == 1 and life._drops.is_empty() and life._hatch() == 0.0)
		await _shot("hatch_sold_reduce")
	else:
		_check("a sale opens the hatch under it", sold and life._drops.size() == 1 and coins[0] == 0)
		await _wait(0.1)
		await _shot("hatch_open")
		await _wait(0.1)
		await _shot("hatch_fall")
		var paid: bool = await _until(func() -> bool: return coins[0] == 1, 2.0)
		await _wait(0.15)
		_check("its coin comes up as the thing is gone", paid and life._drops.size() == 1)
		await _shot("hatch_coin")
		var shut: bool = await _until(func() -> bool: return life._drops.is_empty(), 3.0)
		_check("and the leaves are shut again", shut and life._hatch() == 0.0)
		await _shot("hatch_shut")
	life.coined.disconnect(count)

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
func _crown(tr: Dictionary) -> Vector2:
	return _at(Vector2(tr.tile) + Vector2(0.5, 0.5)) - Vector2(0.0, Art.height(int(tr.look)) * 0.45 * _screen._zoom)

## The tree nearest the eye as the view is turned now: no other crown is in
## front of its own.
func _front_tree() -> Dictionary:
	var front := {}
	for id: int in _sim.trees:
		var tr: Dictionary = _sim.trees[id]
		if front.is_empty() or _screen.life.depth(Vector2(tr.tile)) > _screen.life.depth(Vector2(front.tile)):
			front = tr
	return front

## Where forest `p`'s badge is drawn, in the field's pixels.
func _badge(p: Vector2i) -> Vector2:
	return _screen.world.position + _screen.badge_at(p) * _screen._zoom

func _stock(p: Vector2i = F) -> int:
	return int(_sim.sources[p].stock)

func _lying(tile: Vector2i) -> int:
	return (_sim.items.get(tile, []) as Array).size()

## Every log the first forest ever gave, wherever it is now: held, lying,
## riding, on the hatch or sold (a land with nothing else on it yet).
func _logs() -> int:
	var n: int = _stock() + (_sim.market.wait as Array).size() + int(_sim.earned)
	for tile: Vector2i in _sim.items:
		n += _lying(tile)
	return n

## The one button of a forest's or the market's card, and the plate card's
## tile for a kind of land.
func _card_button() -> Button:
	return _screen._card_slot.find_child("Buttons", true, false).get_child(0)

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
	var field := Rect2(Vector2.ZERO, _screen.field.size)
	_check("the screen opens on the seam: the forest's badge, its gate and the market are all seen",
		(_screen._cam as Vector2).is_equal_approx(_screen.life.seen(Vector2(4.0, 0.0))) and field.has_point(_badge(F))
		and field.has_point(_at(Vector2(3.5, -0.5))) and field.has_point(_at(Vector2(7.0, 7.0))), str(_badge(F)))
	await _shot("new_land")

	await _first_taps()
	await _first_belts()
	await _first_level()
	await _first_plate()
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

## The forest by hand: what a point of it reads as, a tap a log, two lying
## past the gate with no belt, twelve held and no more.
func _first_taps() -> void:
	var front := _front_tree()
	var floor_at := Vector2(1.5, -0.5)
	var h: Dictionary = _screen.hit(_crown(front))
	_check("a crown reads as the forest, at its tree", h.what == "source" and h.tile == front.tile, str(h))
	h = _screen.hit(_at(floor_at))
	_check("so does the forest's floor where no tree stands", h.what == "source" and h.tile == Vector2i(1, -1), str(h))
	h = _screen.hit(_badge(F))
	_check("its badge reads as the badge of its plate", h.what == "badge" and h.get("plate", null) == F, str(h))
	h = _screen.hit(_at(Vector2(1.5, 2.5)))
	_check("open ground past it reads as ground", h.what == "ground" and h.tile == Vector2i(1, 2), str(h))
	await _tap(_crown(front))
	_check("a tap on a crown is one log", _stock() + _lying(PAST) == 1, "%d held, %d lying" % [_stock(), _lying(PAST)])
	await _wait(0.12)
	await _tap(_at(floor_at))
	await _wait(0.12)
	await _tap(_at(Vector2(3.5, -0.5)))
	await _shot("tapped")
	_check("three taps, on a crown, on the floor and on the gate, are three logs", _stock() + _lying(PAST) == 3, "%d held, %d lying" % [_stock(), _lying(PAST)])
	var out := await _until(func() -> bool: return _lying(PAST) == 2 and _stock() == 1, 2.0)
	_check("with no belt two lie on the ground past the gate and the third waits in the forest", out and _sim.items.size() == 1, "%d held, %s" % [_stock(), _sim.items.keys()])
	await _wait(0.3)
	await _shot("logs_past_gate")
	for i in 14:
		await _tap(_crown(front))
	_check("the forest fills to twelve and a tap more gives nothing", _stock() == Sim.SOURCE_ROOM and Sim.SOURCE_ROOM == 12 and _lying(PAST) == 2 and _sim.coins == Sim.START_COINS,
		"%d held" % _stock())
	await _wait(0.3)
	await _shot("forest_full")

## The drawer, Belt, what a swipe does at a forest's edge, and the belts from
## the gate to the market.
func _first_belts() -> void:
	await _press_button(_screen._drawer_b)
	_check("the drawer opens", _screen.drawer_open())
	_check("on a new land it holds the belt and the market, and no machine", _screen._tiles.belt.button.visible and _screen._tiles.market.button.visible
		and not _screen._tiles.firebox.button.visible and not _screen._tiles.retort.button.visible and not _screen._tiles.kiln.button.visible)
	await _wait(0.3)
	await _shot("drawer")
	await _press_button(_screen._tiles.belt.button)
	_check("Belt is picked and the drawer shut", _sim.picked == "belt" and not _screen.drawer_open())
	await _look(Vector2(4.0, 2.5))
	var cam: Vector2 = _screen._cam
	# begun inside the forest: no run, nothing laid
	await _hold([_at(Vector2(3.5, -2.5)), _at(Vector2(3.5, 4.5))])
	_check("a swipe begun inside a forest shows no run", _screen._run.is_empty() and _sim.belts.is_empty(), str(_screen._run))
	await _shot("swipe_from_forest")
	_touch(_at(Vector2(3.5, 4.5)), false)
	await _frames(2)
	_check("and lays nothing as the finger lifts: no belt, no coin spent", _sim.belts.is_empty() and _sim.coins == Sim.START_COINS, "%d belts" % _sim.belts.size())
	# from open ground up into the forest: cut at its edge
	await _hold([_at(Vector2(5.5, 2.5)), _at(Vector2(5.5, -3.5))])
	_check("a swipe from open ground into a forest stops at its edge", _screen._run.get("tiles", []) == [Vector2i(5, 2), Vector2i(5, 1), Vector2i(5, 0)], str(_screen._run))
	await _shot("swipe_into_forest")
	_touch(_at(Vector2(5.5, -3.5)), false)
	await _frames(2)
	var none: bool = _sim.belts.size() == 3
	for tile: Vector2i in _sim.belts:
		none = none and not _sim.is_forest(tile)
	_check("and lays only the three on open ground", none, str(_sim.belts))
	for y in 3:
		_sim.sell(Vector2i(5, y))
	await _frames(2)
	# hold and swipe: a straight run down from the tile past the gate, nothing
	# laid until the finger lifts; then a second from its corner to the market
	await _hold([_at(Vector2(3.5, 0.5)), _at(Vector2(3.5, 6.5))])
	_check("held from the tile past the gate, the run is shown and nothing is laid yet", _sim.belts.is_empty() and _screen._run.get("tiles", []).size() == 7, str(_screen._run))
	await _shot("swipe_held")
	_touch(_at(Vector2(3.5, 6.5)), false)
	await _frames(2)
	var straight: bool = _sim.belts.size() == 7
	for y in 7:
		straight = straight and _sim.belts.get(Vector2i(3, y), -1) == 1
	_check("lifting lays the run, a straight line facing the swipe", straight, str(_sim.belts))
	await _drag([_at(Vector2(3.5, 6.5)), _at(Vector2(5.5, 6.5))])
	var laid := true
	for tile: Vector2i in WANT_BELTS:
		laid = laid and _sim.belts.get(tile, -1) == WANT_BELTS[tile]
	_check("a swipe from the run's end to the market turns its corner into the market", laid and _sim.belts.size() == WANT_BELTS.size(), str(_sim.belts))
	_check("the drags did not pan the view", _screen._cam == cam)
	_check("nine belts cost nine coins", _sim.coins - _sim.earned == Sim.START_COINS - 9, str(_sim.coins))
	_run_on(7.0)
	await _wait(0.3)
	await _shot("logs_riding")
	for i in 40:
		if _sim.earned > 0:
			break
		_run_on(1.0)
	_check("the logs ride from the gate to the market and are sold: coins up", _sim.earned > 0 and _sim.coins == Sim.START_COINS - 9 + _sim.earned, "coins %d" % _sim.coins)
	_check("none of the fourteen tapped is lost: held, riding, on the hatch or sold", _logs() == 14, str(_logs()))
	await _wait(0.25)
	await _shot("sold")
	await _hatch()
	# a tap on a laid belt turns it a quarter, and back round
	await _tap(_at(Vector2(3.5, 2.5)))
	_check("a tap on a belt turns it a quarter", _sim.belts[Vector2i(3, 2)] == 2, str(_sim.belts[Vector2i(3, 2)]))
	for i in 3:
		await _tap(_at(Vector2(3.5, 2.5)))
	_check("and four taps bring it round", _sim.belts[Vector2i(3, 2)] == 1)
	await _press_button(_screen._drawer_b)
	_check("the drawer's button puts the belt down", _sim.picked == "")

## The forest's card, from its badge, and its first level.
func _first_level() -> void:
	await _look(Vector2(4.0, -3.0))
	await _tap(_badge(F))
	_check("a tap on a forest's badge opens its card", _screen.card_open() and _screen._card_for == "forest", _screen._card_for)
	_check("and takes no log: the badge is not the forest", _screen.hit(_badge(F)).what == "badge")
	await _wait(0.4)
	await _shot("forest_card")
	var up := _card_button()
	_sim.coins = 40
	await _frames(2)
	await _press_button(up)
	_check("a level the coins do not reach is refused", int(_sim.sources[F].level) == 0 and _sim.coins >= 40 and _screen.card_open())
	_sim.coins = 60
	await _frames(2)
	_check("its one button names the first level's price", up.label_text == TranslationServer.translate("FACTORY_FOREST_AUTO_FOR") % "60", up.label_text)
	await _press_button(up)
	_check("the forest's first level is bought for 60: a log a second by itself", _sim.source_rate(F) == 1.0 and int(_sim.sources[F].level) == 1 and _sim.coins < 10, "coins %d" % _sim.coins)
	await _wait(0.3)
	_check("and the button offers the second for 180", _screen.card_open() and up.label_text == TranslationServer.translate("FACTORY_LEVEL_FOR") % [2, "180"], up.label_text)
	await _shot("forest_card_level_1")
	_screen.close_card()
	var had := _logs()
	_run_on(6.0)
	_check("it works with no hand on it: six seconds on, six more logs than there were", _logs() == had + 6, "%d to %d" % [had, _logs()])
	await _wait(1.2)
	await _shot("forest_by_itself")

## A plus, the plate card, the first plate bought.
func _first_plate() -> void:
	await _look(Vector2(12.0, 4.0))
	await _tap(_screen.to_field(_screen.life.plus_at(Vector2i(1, 0))))
	_check("a tap on a plus opens the plate card", _screen.card_open() and _screen._card_for == "plate")
	var kinds: Node = _screen._card_slot.find_child("Kinds", true, false)
	var neutral: Button = kinds.get_node_or_null("Neutral") if kinds != null else null
	_check("it offers the three kinds of land: a forest, a mine and neutral ground", kinds != null and kinds.get_child_count() == 3 and kinds.get_node_or_null("Forest") != null
		and kinds.get_node_or_null("Mine") != null and neutral != null)
	await _wait(0.4)
	await _shot("plate_card")
	_sim.coins = 30
	await _frames(2)
	await _press_button(neutral)
	_check("a plate the coins do not reach is refused", _sim.plates.size() == 2 and _screen.card_open())
	_sim.coins = 50
	await _frames(2)
	await _press_button(neutral)
	_check("the first plate is bought for 50: neutral ground beside the market's", _sim.plates.size() == 3 and _sim.plates.get(Vector2i(1, 0), "") == "neutral" and not _screen.card_open() and _sim.coins < 10,
		str(_sim.plates))
	await _wait(1.3)
	await _shot("plate_rising")
	await _wait(2.6)
	await _shot("first_plate")
	await _press_button(_screen._drawer_b)
	await _wait(0.3)
	_check("the plate brings the fire box and the retort to the drawer, and no kiln", _screen._tiles.firebox.button.visible and _screen._tiles.retort.button.visible
		and not _screen._tiles.kiln.button.visible)
	await _shot("drawer_unlocked")
	await _press_button(_screen._drawer_b)

func _lay(tile: Vector2i, facing: int) -> void:
	if not _sim.can_lay(tile) or not _sim.lay_belt(tile, facing):
		print("     (no belt on %s)" % tile)

## Six plates (three neutral, three forests) with a belt past a gate of each
## forest, two fires lit, two retorts working and the market's hatch
## holding its one: built through the sim's own actions and stepped, not waited for.
func _late_land() -> void:
	_sim.coins = 100000
	_check("a second neutral plate and two more sources are bought", _sim.buy_plate(Vector2i(0, 1), "neutral") and _sim.buy_plate(EAST, "forest") and _sim.buy_plate(WEST, "forest")
		and _sim.plates.size() == 6 and _sim.sources.size() == 3 and _sim.trees.size() == 3 * Sim.TREES)
	# the neutral plate in front: two retorts, a fire each, a belt in and a belt out
	var built := true
	built = _sim.place("retort", Vector2i(2, 10), 0) and built
	built = _sim.place("firebox", Vector2i(2, 11), 0) and built
	built = _sim.place("retort", Vector2i(2, 13), 0) and built
	built = _sim.place("firebox", Vector2i(2, 14), 0) and built
	_check("two retorts and two fire boxes are placed", built)
	var had: int = _sim.modules.size()
	_check("a kiln is not to be had, and nothing stands in a forest", not _sim.place("kiln", Vector2i(4, 12), 0) and not _sim.place("firebox", Vector2i(-4, 4), 0)
		and not _sim.place("retort", Vector2i(0, 2), 2) and _sim.modules.size() == had)
	for row in [10, 11, 13, 14]:
		_lay(Vector2i(0, row), 0)
		_lay(Vector2i(1, row), 0)
	for x in [4, 5, 6]:
		_lay(Vector2i(x, 10), 0)
	for y in [10, 9, 8, 7]:
		_lay(Vector2i(7, y), 3)
	for x in [4, 5]:
		_lay(Vector2i(x, 13), 0)
	for y in [13, 12, 11]:
		_lay(Vector2i(6, y), 3)
	# the neutral plate beside the market: a row along the market's own into its side
	for x in range(14, 6, -1):
		_lay(Vector2i(x, 6), 2)
	# the forest behind that plate: from its gate down to the row
	for y in range(0, 6):
		_lay(Vector2i(11, y), 1)
	# the forest beside the market's plate: from its gate across to the first belt
	for x in range(0, 3):
		_lay(Vector2i(x, 4), 0)
	_check("each new forest's gate has a belt past it", _sim.belts.get(Sim.gate(EAST, 1) + Vector2i(0, 1), -1) == 1 and _sim.belts.get(Sim.gate(WEST, 0) + Vector2i(1, 0), -1) == 0)
	_sim.upgrade(EAST * Sim.PLATE)
	_sim.upgrade(WEST * Sim.PLATE)
	_sim.upgrade(WEST * Sim.PLATE)
	_check("their levels are their own", int(_sim.source_rate(F)) == 1 and int(_sim.source_rate(EAST)) == 1 and int(_sim.source_rate(WEST)) == 2)
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
	_sim.put(Vector2i(0, 10), "log")
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
	var first: Dictionary = _sim.module_at(Vector2i(2, 10))
	var second: Dictionary = _sim.module_at(Vector2i(2, 13))
	_check("the two retorts work on their fires", _sim.working(first) and float(first.share) > 0.0 and _sim.working(second) and float(second.share) > 0.0,
		"%s %.2f, %s %.2f" % [first.inp, first.share, second.inp, second.share])
	# things on the way, one on the market's hatch and the belts behind it waiting
	for i in 9:
		_sim.put(Vector2i(7, 9), ["log", "stone", "lime", "charcoal"][i % 4])
		_sim.put(Vector2i(12, 6), "charcoal")
		_run_on(1.2)
	_check("the market's hatch has its one and the belt behind it waits", (_sim.market.wait as Array).size() == 1 and _lying(Vector2i(7, 6)) > 0, str(_sim.market.wait))
	var rides := true
	for tile: Vector2i in [Vector2i(11, 3), Vector2i(1, 4), Vector2i(3, 2)]:
		rides = rides and _lying(tile) > 0
	_check("logs of all three sources ride the belts past their gates", rides, "%d %d %d" % [_lying(Vector2i(11, 3)), _lying(Vector2i(1, 4)), _lying(Vector2i(3, 2))])
	var shut := true
	for tile: Vector2i in _sim.belts:
		shut = shut and not _sim.is_forest(tile)
	for tile: Vector2i in _sim.items:
		shut = shut and not _sim.is_forest(tile)
	for id: int in _sim.modules:
		for tile: Vector2i in _sim.modules[id].tiles:
			shut = shut and not _sim.is_forest(tile)
	_check("no belt, no machine and nothing lying is inside any forest", shut)
	await _look(Vector2(3.5, 11.5))
	await _wait(0.5)
	await _shot("late_machines")
	await _look(Vector2(6.5, 6.0))
	await _wait(0.3)
	await _shot("late_market")
	await _look(Vector2(4.0, 0.5))
	await _wait(0.3)
	await _shot("late_first_gate")
	await _look(Vector2(11.5, 1.0))
	await _wait(0.3)
	await _shot("late_east_forest")
	await _look(Vector2(-1.5, 4.0))
	await _wait(0.3)
	await _shot("late_west_forest")
	await _look(Vector2(6.0, 2.0), true)
	await _wait(0.5)
	await _shot("late_zoomed_out")

## What a finger does on the late land: a machine placed under a ghost and
## refused on a forest, a belt sold by holding, the view dragged, two
## fingers pinching.
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
	# nor in a forest: the ghost says no and nothing stands
	await _look(Vector2(4.0, -3.0))
	_touch(_at(Vector2(4.5, -3.5)), true)
	await _frames(2)
	_move(_at(Vector2(4.5, -3.2)))
	await _frames(3)
	var ghosts: Array = _screen._ghosts()
	await _shot("ghost_on_forest")
	_touch(_at(Vector2(4.5, -3.2)), false)
	await _frames(2)
	_check("a machine held over a forest shows the ghost that says no, and lifting stands nothing", ghosts.size() == 1 and ghosts[0][0] == Art.ghost(1, 1, false)
		and _sim.modules.size() == before + 1 and _sim.picked == "firebox" and _sim.module_at(Vector2i(4, -4)).is_empty())
	_screen.pick("")
	await _look(Vector2(4.0, 12.0))
	# a finger held on a belt sells it back
	var coins: int = _sim.coins
	var earned: int = _sim.earned
	var belt := Vector2i(0, 14)
	_touch(_at(Vector2(belt) + Vector2(0.5, 0.5)), true)
	await _wait(0.34)
	await _shot("sell_ring")
	await _wait(0.4)
	_touch(_at(Vector2(belt) + Vector2(0.5, 0.5)), false)
	await _frames(2)
	_check("a finger held on a belt sells it back for its coin", not _sim.belts.has(belt) and _sim.coins - (_sim.earned - earned) == coins + 1, "coins %d" % (_sim.coins - coins))
	# a finger held on a forest sells nothing and takes no log by holding
	await _look(Vector2(4.0, -3.0))
	var trees: int = _sim.trees.size()
	_touch(_at(Vector2(4.5, -3.5)), true)
	await _wait(0.8)
	var ring: bool = _screen._long.is_empty()
	_touch(_at(Vector2(4.5, -3.5)), false)
	await _frames(2)
	_check("a finger held on a forest sells nothing of it", ring and _sim.trees.size() == trees and _sim.sources.has(F) and _sim.plates.get(F, "") == "forest")
	await _look(Vector2(4.0, 12.0))
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
	# a forest two levels up, by its badge; then at its last level
	await _look(Vector2(-4.0, 1.0))
	await _tap(_badge(WEST))
	var up: Button = _card_button() if _screen.card_open() else null
	_check("a bought forest's badge opens that forest's card, at its own level", _screen._card_for == "forest" and up != null
		and up.label_text == TranslationServer.translate("FACTORY_LEVEL_FOR") % [3, "540"], "" if up == null else up.label_text)
	await _wait(0.4)
	await _shot("forest_card_level_2")
	if up != null:
		await _press_button(up)
		await _press_button(up)
		await _wait(0.3)
		_check("its last level bought from the card, the card offers no more", int(_sim.sources[WEST].level) == 4 and _sim.source_rate(WEST) == 4.0 and not up.visible
			and _sim.upgrade_price(WEST * Sim.PLATE) == -1 and int(_sim.sources[F].level) == 1)
		await _shot("forest_card_top")
	_screen.go_back()
	await _press_button(_screen._drawer_b)
	await _wait(0.3)
	await _shot("drawer_late")
	_screen.go_back()
	_check("then the drawer", not _screen.drawer_open())

## The view turned a quarter at a time by its button, four times round. At
## each turn: every tile of the land is seen at a place of its own and read
## back from it; a belt dragged across two empty neighbours, pressed where
## they are seen, lands on those very tiles facing from the first to the
## second in the sim's own terms; every forest's badge is hit where it is
## drawn; a swipe begun on a forest tile lays nothing; and a tap where the
## crown nearest the eye is drawn is a log from that tree's forest.
const TURN_BELTS := [[Vector2i(1, 8), Vector2i(2, 8), 0], [Vector2i(4, 8), Vector2i(4, 9), 1],
	[Vector2i(1, 15), Vector2i(0, 15), 2], [Vector2i(6, 15), Vector2i(6, 14), 3]]

func _turns() -> void:
	var home: Vector2 = _screen.life.seen(Vector2(3.5, 2.5))
	for q in 4:
		await _look(Vector2(6.0, 2.0), true)
		await _press_button(_screen._turn_b)
		var turn: int = _screen.life.turn
		_check("turn %d: the button turns the view a quarter" % (q + 1), turn == (q + 1) % 4, str(turn))
		await _wait(0.4)
		await _shot("turn_%d_far" % turn)
		await _look(Vector2(3.5, 11.5))
		await _wait(0.2)
		await _shot("turn_%d_machines" % turn)
		await _look(Vector2(6.5, 6.0))
		await _wait(0.2)
		await _shot("turn_%d_market" % turn)
		await _look(Vector2(4.0, -1.0))
		await _wait(0.2)
		await _shot("turn_%d_forest" % turn)
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
		_check("turn %d: a drag lays belts on the tiles under the finger, facing in the sim's terms" % turn,
			free and _sim.belts.size() == had + 2 and _sim.belts.get(a, -1) == pair[2] and _sim.belts.get(b, -1) == pair[2],
			"%s %s, %s %s, %d laid" % [a, _sim.belts.get(a, -1), b, _sim.belts.get(b, -1), _sim.belts.size() - had])
		# a swipe begun on a forest tile, out over open ground
		had = _sim.belts.size()
		await _look(Vector2(0.0, 1.5))
		await _drag([_mid(Vector2i(-3, 1)), _mid(Vector2i(1, 1))])
		_screen.pick("")
		_check("turn %d: a swipe begun inside a forest lays nothing" % turn, _sim.belts.size() == had and not _sim.belts.has(Vector2i(0, 1)) and not _sim.belts.has(Vector2i(1, 1)),
			"%d laid" % (_sim.belts.size() - had))
		# every forest's badge, where it is drawn
		var badges := true
		for p: Vector2i in _sim.sources:
			var h: Dictionary = _screen.hit(_badge(p))
			badges = badges and h.what == "badge" and h.get("plate", null) == p
		_check("turn %d: every forest's badge is hit where it is drawn" % turn, badges)
		# the tree nearest the eye, tapped on its crown
		var front := _front_tree()
		var p: Vector2i = Sim.plate_of(front.tile)
		await _look(Vector2(front.tile) + Vector2(0.5, 0.5))
		var crown := _crown(front)
		var hit: Dictionary = _screen.hit(crown)
		_touch(crown, true)
		var held := _stock(p)
		_touch(crown, false)
		# what the sim said of it, before the screen's next frame drains it: a
		# log off that very tree, or that tree shaking its head when its forest
		# is full (a late forest mostly is: its belt carries less than it makes)
		var said: Dictionary = _sim.events.back() if not _sim.events.is_empty() else {}
		var now := _stock(p)
		await _frames(2)
		var took: bool = said.get("type", "") == "chop" and int(said.id) == int(front.id) and not said.auto and now == held + 1
		var full: bool = said.get("type", "") == "refused" and said.why == "full" and said.tile == front.tile and held == Sim.SOURCE_ROOM and now == held
		_check("turn %d: a tap where a tree's crown is drawn reaches that tree, a log of its forest or its no when full" % turn,
			hit.what == "source" and hit.tile == front.tile and (took or full), "%s of %s: %d to %d, %s" % [front.tile, p, held, now, said.get("type", "nothing")])
	_check("four turns come back to the first view", _screen.life.turn == 0 and (_screen.life.seen(Vector2(3.5, 2.5)) as Vector2).is_equal_approx(home))
	await _look(Vector2(6.0, 2.0), true)
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

## Hold and swipe, and the way a run flows, on a seventh plate of open
## neutral ground (and beside the market): at no turn of the view, then a
## quarter round.
func _swipes() -> void:
	_check("a seventh plate, open neutral ground, for the swipes", _sim.buy_plate(Vector2i(0, 2), "neutral"))
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
		await _look(Vector2(6.5, 4.5))
		had = _sim.belts.size()
		await _drag([_mid(Vector2i(6, 3)), _mid(Vector2i(6, 6))])
		_check(say + "a swipe ending at the market stops at it and flows into it", _line(Vector2i(6, 3), Vector2i(6, 5), 1, had), str(_sim.belts.size() - had))
		_unlay(Vector2i(6, 3), Vector2i(6, 5))
		await _frames(2)
		had = _sim.belts.size()
		await _drag([_mid(Vector2i(6, 5)), _mid(Vector2i(6, 3))])
		_check(say + "a swipe from the market's edge, dragged away, still flows into it", _line(Vector2i(6, 3), Vector2i(6, 5), 1, had), str(_sim.belts))
		_unlay(Vector2i(6, 3), Vector2i(6, 5))
		# the rule itself, as the one function has it
		var rule: bool = _screen.run_facing(_sim, [Vector2i(2, 22), Vector2i(3, 22)], 0) == 0 \
			and _screen.run_facing(_sim, [Vector2i(3, 18), Vector2i(3, 19)], 1) == 3 \
			and _screen.run_facing(_sim, [Vector2i(7, 21), Vector2i(7, 22)], 1) == 1 \
			and _screen.run_facing(_sim, [Vector2i(7, 22), Vector2i(7, 21)], 3) == 1
		_check(say + "the rule: a free run follows the finger, one swiped off a belt's side joins it, one off a belt's front flows on either way it is swiped", rule)
		# a forest's gate is not something a run meets: one laid toward it keeps the finger's way
		_check(say + "the rule at a forest: a run swiped up to a gate, or away from it, flows as the finger went",
			_screen.run_facing(_sim, [Vector2i(-1, 9), Vector2i(-1, 8)], 3) == 3 and _screen.run_facing(_sim, [Vector2i(-1, 8), Vector2i(-1, 9)], 1) == 1)
		for row in [17, 19, 21, 22]:
			_unlay(Vector2i(0, row), Vector2i(7, row))
		_unlay(Vector2i(7, 17), Vector2i(7, 20))
		await _frames(2)
	_screen.pick("")
	# raised belts with things riding, a quarter round: by the market, by the retorts, from far
	for i in 6:
		_sim.put(Vector2i(4 + i % 3, 10), ["stone", "log", "lime"][i % 3])
		_sim.put(Vector2i(10 + i % 3, 6), "charcoal")
		_run_on(0.8)
	await _look(Vector2(6.5, 6.0))
	await _wait(0.4)
	await _shot("raised_market_turn_1")
	await _look(Vector2(3.5, 11.5))
	await _shot("raised_retorts_turn_1")
	await _look(Vector2(4.0, 8.0), true)
	await _wait(0.3)
	await _shot("raised_far_turn_1")
	for i in 3:
		await _press_button(_screen._turn_b)
	await _look(Vector2(6.5, 6.0))
	await _wait(0.4)
	await _shot("raised_market_turn_0")
	await _look(Vector2(3.5, 11.5))
	await _shot("raised_retorts_turn_0")
	await _look(Vector2(4.0, 8.0), true)
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
	# the belt past the first forest's gate is fed by nothing the sim calls a
	# belt: it is drawn straight, and so is the corner into the market's row
	_check("the belt past a gate is drawn straight, and the corner of the first way a bend", life.shape(PAST) == 0 and life.shape(Vector2i(3, 6)) != 0,
		"%d %d" % [life.shape(PAST), life.shape(Vector2i(3, 6))])
	for i in 3:
		await _press_button(_screen._turn_b)

## One page of the tutorial played on its own for `seconds` from its start,
## off the screen: the land its film has made by then.
func _page(lesson: int, seconds: float) -> RefCounted:
	var d: Control = load("res://ui/hud/factory_tutorial_diagram.gd").new()
	d.lesson = lesson
	d.position = Vector2(-4000.0, 0.0)
	d.size = Vector2(900.0, 700.0)
	root.add_child(d)
	await _frames(2)
	d.set_process(false)
	d._start()
	d._advance(seconds)
	var land: RefCounted = d._sim
	d.queue_free()
	await _frames(2)
	return land

func _tutorial() -> void:
	_screen.tutor.show()
	await _wait(2.2)
	await _shot("tutorial_forest")
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
	# what each page's film does, on the game's own sim
	var Diagram: GDScript = load("res://ui/hud/factory_tutorial_diagram.gd")
	_check("the tutorial has three pages", _screen.tutorial_pages().size() == 3)
	var land: RefCounted = await _page(Diagram.Lesson.TREE, 3.2)
	_check("the first page taps the forest three times: three logs, two past the gate", int(land.sources[F].stock) + (land.items.get(PAST, []) as Array).size() == 3
		and (land.items.get(PAST, []) as Array).size() == 2 and land.belts.is_empty(), "%s %s" % [land.sources[F], land.items.keys()])
	land = await _page(Diagram.Lesson.BELT, 27.0)
	var way: bool = land.belts.size() == WANT_BELTS.size()
	for tile: Vector2i in WANT_BELTS:
		way = way and land.belts.get(tile, -1) == WANT_BELTS[tile]
	_check("the second lays the nine belts from the gate to the market and a log is sold", way and land.earned > 0 and land.coins == Sim.START_COINS - 9 + land.earned,
		"%d belts, %d sold" % [land.belts.size(), land.earned])
	land = await _page(Diagram.Lesson.PLATE, 5.5)
	_check("the third buys neutral ground beside the market's plate", land.plates.size() == 3 and land.plates.get(Vector2i(1, 0), "") == "neutral" and land.coins == 0, str(land.plates))

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
	var kept: Dictionary = _sim.pack()
	_screen.queue_free()
	await _frames(3)
	var read: RefCounted = Sim.new(1)
	_check("the file the screen kept reads back as the very land it left", read.load_saved() and var_to_str(read.pack()) == var_to_str(kept) and int(kept.version) == 3)
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
	var levels: bool = tab.sim.sources.size() == 3
	for p: Vector2i in _sim.sources:
		levels = levels and tab.sim.sources.has(p) and int(tab.sim.sources[p].level) == int(_sim.sources[p].level)
	_check("the tab reads the land the screen kept, its sources at their levels", tab.sim.plates.size() == _sim.plates.size() and tab.sim.plates.size() == 7 and levels
		and tab.sim.belts.size() == _sim.belts.size(), "plates %d" % tab.sim.plates.size())
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
