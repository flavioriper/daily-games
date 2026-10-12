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
