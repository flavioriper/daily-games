extends SceneTree
const SEED := 7
const SAVE := "user://factory_tmp_shot.cfg"
var Art: GDScript
var Sim: GDScript
var Motion: GDScript
var _out := ""
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


func _run() -> void:
	await _frames(8)
	_sim = Sim.new(SEED)
	_screen = load("res://factory/screen.gd").new()
	_screen.name = "Factory"
	_screen.setup(_sim)
	root.add_child(_screen)
	await _frames(4)
	_screen.field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _wait(0.8)
	await _shot("new_land")
	await _look(Vector2(4.0, -1.0))
	await _shot("forest_near")
	# three taps on the forest, on a crown, on the floor and on the rim
	for t: Vector2 in [Vector2(3.5, -3.5), Vector2(5.5, -5.5), Vector2(1.5, -0.5)]:
		await _tap(_at(t))
		await _wait(0.12)
	await _shot("tapped")
	_check("three taps are three logs out or held", _sim.forests[Vector2i(0, -1)].stock + (_sim.items.get(Vector2i(3, 0), []) as Array).size() == 3, str(_sim.forests))
	for i in 14:
		await _tap(_at(Vector2(3.5, -3.5)))
	await _wait(0.3)
	await _shot("full")
	_check("the forest fills", _sim.forests[Vector2i(0, -1)].stock == Sim.FOREST_ROOM, str(_sim.forests))
	# a belt cannot be swiped into the forest
	_screen.pick("belt")
	await _drag([_at(Vector2(3.5, -2.5)), _at(Vector2(3.5, 6.5))])
	_check("a swipe begun in the forest lays nothing", _sim.belts.is_empty(), str(_sim.belts.size()))
	await _drag([_at(Vector2(3.5, 0.5)), _at(Vector2(3.5, 6.5))])
	await _drag([_at(Vector2(3.5, 6.5)), _at(Vector2(5.5, 6.5))])
	_check("nine belts from the gate to the market", _sim.belts.size() == 9, str(_sim.belts))
	_screen.pick("")
	await _look(Vector2(4.0, 2.5))
	_run_on(9.0)
	await _wait(0.3)
	await _shot("riding")
	_run_on(60.0)
	_check("logs are sold", _sim.earned > 0, str(_sim.earned))
	# the badge opens the card
	await _look(Vector2(4.0, -3.0))
	var badge: Vector2 = _screen.world.position + _screen.badge_at(Vector2i(0, -1)) * _screen._zoom
	await _tap(badge)
	await _wait(0.4)
	_check("the badge opens the forest's card", _screen.card_open() and _screen._card_for == "forest")
	await _shot("forest_card")
	_sim.coins = 100
	await _wait(0.2)
	var up: Button = _screen._card_slot.find_child("Buttons", true, false).get_child(0)
	await _press_button(up)
	_check("the first level is bought", _sim.forest_rate(Vector2i(0, -1)) == 1.0)
	await _wait(0.3)
	await _shot("forest_card_auto")
	_screen.close_card()
	_run_on(6.0)
	await _wait(1.2)
	await _shot("auto")
	# the plate card, and a land of four
	await _look(Vector2(4.0, 2.0), true)
	_screen.open_plate(Vector2i(1, 0))
	await _wait(0.4)
	await _shot("plate_card")
	_screen.close_card()
	_sim.coins = 5000
	_sim.buy_plate(Vector2i(1, 0), "neutral")
	_sim.buy_plate(Vector2i(1, -1), "forest")
	_sim.buy_plate(Vector2i(-1, 0), "forest")
	_sim.buy_plate(Vector2i(0, 1), "neutral")
	_sim.upgrade(Vector2i(8, -8))
	_sim.upgrade(Vector2i(-8, 0))
	for y in range(1, 6):
		_sim.lay_belt(Vector2i(0, 3), 0)
	for x in range(0, 6):
		_sim.lay_belt(Vector2i(x, 3), 0)
	_sim.place("firebox", Vector2i(10, 4), 0)
	_sim.place("retort", Vector2i(11, 4), 0)
	_run_on(40.0)
	await _wait(3.5)
	await _look(Vector2(4.0, 2.0), true)
	await _shot("five_plates")
	for q in 3:
		_screen.turn_view()
		await _wait(0.5)
		await _look(Vector2(4.0, 2.0), true)
		await _shot("turn_%d" % (q + 1))
	_screen.turn_view()
	await _wait(0.4)
	await _look(Vector2(4.0, 2.0))
	_screen.open_drawer()
	await _wait(0.4)
	await _shot("drawer")
	_screen.close_drawer()
	_screen.tutor.open() if _screen.tutor.has_method("open") else null
	await _wait(1.6)
	await _shot("tutorial")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("fails %d" % _fails)
	quit()
