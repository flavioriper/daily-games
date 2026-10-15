extends SceneTree

## The Arcade tab and Tally, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_tally.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab (Tally's card on its page), 2 a new sheet, then real
## touches: the Dig tool from the tray, a tap on the nearest 1 (its ghost
## and the builder pill come up: shot 2b) and a tap on the pill's Place (a
## dig stands there), the Belt tool and a path traced from beside the dig
## to the box in one gesture, round the route's corner (the run is laid and
## leads into the box), the undo chip pressed (the run is gone) and the path
## traced again, 3 the first 1s riding, 4 level 1 done, 5 a grown paper
## close (digs, an adder, a multiplier, a divider, a bridge and a crate,
## every token sliding), 6 the same far after a real two-finger pinch out,
## 7 the adder's pill by a real tap with Look (shot 6b) and its card by a
## tap on Info, 8 the box's card by a real tap on the plate, 9 the upgrades,
## one bought, 10 a refusal, then the tutorial: 11 its Dig page with the
## finger on the pill's Place, 12 its Machine page with the adder's ghost
## turned (and what each page's own paper ends with is checked). Prints the
## draw calls at each shot.
## With no display it shoots nothing and still drives every beat, so it
## serves as a smoke run. The paper is kept in a file of the harness's own
## (`Sim.path`), so this machine's paper is never touched.

const Sim = preload("res://arcade/tally_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _blind := false
var _fails := 0
var _dig := Vector2i(-1, -1)
var _card: Control

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	Sim.path = "user://_shot_tally.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sim.path))
	_blind = DisplayServer.get_name() == "headless"
	for a: String in OS.get_cmdline_user_args():
		if a == "reduce":
			load("res://core/motion.gd").reduce = true
		elif a in ["en", "pt", "es"]:
			load("res://core/locale.gd")._current = a
		else:
			_out = a
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

func _shot(name: String) -> void:
	var sim = _s.sim if _s != null else null
	if not _blind:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/tl_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d level=%d made=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.level if sim != null else 0, sim.made if sim != null else 0])

func _win(c: Control, at: Vector2) -> Vector2:
	return root.get_final_transform() * (c.get_global_transform_with_canvas() * at)

func _touch(at: Vector2, down: bool, index := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = down
	ev.position = at
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _drag_ev(at: Vector2, index := 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = at
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _tap(at: Vector2) -> void:
	_touch(at, true)
	_touch(at, false)

func _square(t: Vector2i) -> Vector2:
	return _win(_s.board, _s.board.screen_of(Vector2(t) + Vector2(0.5, 0.5)))

func _tap_tray(slot: int) -> void:
	_tap(_win(_s.tray, _s._slot_mid(slot)))

## A real path traced through the squares `pts` in one gesture: pressed on
## the first, dragged in samples three to a square along each leg, let go
## on the last.
func _trace(pts: Array) -> void:
	_touch(_square(pts[0]), true)
	for j in range(1, pts.size()):
		var a: Vector2i = pts[j - 1]
		var b: Vector2i = pts[j]
		var n: int = maxi(1, (absi(b.x - a.x) + absi(b.y - a.y)) * 3)
		var p0 := _square(a)
		var p1 := _square(b)
		for s in range(1, n + 1):
			_drag_ev(p0.lerp(p1, float(s) / n))
	_touch(_square(pts[-1]), false)

## A pill button pressed for real, where the board says it is.
func _tap_pill(name: String) -> void:
	var r: Rect2 = _s.board.pill_button_rect(name)
	_tap(_win(_s.board, r.position + Vector2(r.size.x * 0.5, 42.0)))

## The route from beside the dig into the box as the squares a finger
## traces through: [start, end] or [start, corner, end].
func _route_points(dig: Vector2i) -> Array:
	var r: Array = _route(dig)
	if r.size() > 3:
		return [r[0], r[1], r[3]]
	return [r[0], r[1]]

func _close(node: String) -> void:
	var n: Node = _s.get_node_or_null(node)
	if n != null:
		n.closed.emit()
		n.queue_free()

func _done() -> bool:
	Sim.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_tally.cfg"))
	print("%d failed" % _fails)
	return true

func _next() -> void:
	_at = _t
	_step += 1

## The printed 1 nearest the box with three clear squares toward it.
func _nearest_one(sim) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	for i in Sim.N:
		if int(sim.dep[i]) != 1:
			continue
		var t := Sim.tile_of(i)
		var d := Vector2(t).distance_to(Vector2(Sim.HUB_AT) + Vector2(2, 2))
		if d < best_d:
			best_d = d
			best = t
	return best

## A straight-then-turn path from beside the dig into the box, as two runs:
## [start, corner, end, way1, way2].
func _route(dig: Vector2i) -> Array:
	var box := Rect2i(Sim.HUB_AT, Vector2i(Sim.HUB, Sim.HUB))
	# go along x first to a column of the box, then along y into it
	var tx := clampi(dig.x, box.position.x, box.end.x - 1)
	var ty := clampi(dig.y, box.position.y, box.end.y - 1)
	if dig.x >= box.position.x and dig.x < box.end.x:
		# straight down or up into the box
		var f := 1 if dig.y < box.position.y else 3
		var start: Vector2i = dig + Sim.DIRS[f]
		var end := Vector2i(dig.x, box.position.y - 1 if f == 1 else box.end.y)
		return [start, end, f]
	if dig.y >= box.position.y and dig.y < box.end.y:
		var f := 0 if dig.x < box.position.x else 2
		var start: Vector2i = dig + Sim.DIRS[f]
		var end := Vector2i(box.position.x - 1 if f == 0 else box.end.x, dig.y)
		return [start, end, f]
	return [dig + Vector2i(0, 1 if dig.y < ty else -1), Vector2i(dig.x, ty), 1 if dig.y < ty else 3, Vector2i(tx, ty)]

## A grown paper laid by hand: a few digs near the box with numbers written
## for the harness, an adder, a multiplier, a divider, a bridge and a crate.
func _grow(sim) -> void:
	sim.level = 23
	var b := Sim.HUB_AT
	var put := func(t: Vector2i, v: int) -> void:
		sim.dep[Sim._i(t)] = v
		sim.place(Sim.DIG, t, 0)
	# an adder west of the box: 3 from the north, 4 from the south, 7 east into the box
	var m := b + Vector2i(-4, 1)
	sim.place(Sim.ADD, m, 0)
	put.call(m + Vector2i(0, -3), 3)
	put.call(m + Vector2i(0, 3), 4)
	sim.lay_run([m + Vector2i(0, -2), m + Vector2i(0, -1)], 1)
	sim.lay_run([m + Vector2i(0, 2), m + Vector2i(0, 1)], 3)
	sim.lay_run([m + Vector2i(1, 0), m + Vector2i(2, 0), m + Vector2i(3, 0)], 0)
	# a multiplier north of the box: 6 × 5, down into it
	var x := b + Vector2i(1, -4)
	sim.place(Sim.MUL, x, 1)
	put.call(x + Vector2i(3, 0), 6)
	put.call(x + Vector2i(-3, 0), 5)
	sim.lay_run([x + Vector2i(2, 0), x + Vector2i(1, 0)], 2)
	sim.lay_run([x + Vector2i(-2, 0), x + Vector2i(-1, 0)], 0)
	sim.lay_run([x + Vector2i(0, 1), x + Vector2i(0, 2), x + Vector2i(0, 3)], 1)
	# a divider east of the box: 9 ÷ 2, the quotient into the box, the remainder off to a crate
	var d := b + Vector2i(7, 2)
	sim.place(Sim.DIV, d, 2)
	put.call(d + Vector2i(0, 3), 9)
	put.call(d + Vector2i(0, -3), 2)
	sim.lay_run([d + Vector2i(0, 2), d + Vector2i(0, 1)], 3)
	sim.lay_run([d + Vector2i(0, -2), d + Vector2i(0, -1)], 1)
	sim.lay_run([d + Vector2i(-1, 0), d + Vector2i(-2, 0), d + Vector2i(-3, 0)], 2)
	sim.lay_run([d + Vector2i(1, 0), d + Vector2i(2, 0)], 0)
	sim.place(Sim.CRATE, d + Vector2i(3, 0), 0)
	# a 1s line south of the box crossing a 2s line: a bridge
	var s := b + Vector2i(0, 8)
	put.call(s + Vector2i(-6, 0), 1)
	var row := []
	for j in range(-5, 3):
		row.append(s + Vector2i(j, 0))
	sim.lay_run(row, 0)
	var up := []
	for j in range(0, 4):
		up.append(s + Vector2i(3, -j))
	sim.lay_run(up, 3)
	put.call(s + Vector2i(-2, 3), 2)
	var col := []
	for j in range(2, -4, -1):
		col.append(s + Vector2i(-2, j))
	sim.lay_run(col, 3)
	sim.lay_run([s + Vector2i(-2, -4), s + Vector2i(-1, -4), s + Vector2i(0, -4)], 0)
	# a merge: 8s up into the side of the adder's run to the box, and a
	# split: a belt off that run's side going north
	put.call(m + Vector2i(2, 3), 8)
	sim.lay_run([m + Vector2i(2, 2), m + Vector2i(2, 1)], 3)
	sim.lay_run([m + Vector2i(1, -1), m + Vector2i(1, -2)], 3)
	# a subtractor south-east of the box fed on A alone (3s from the south):
	# it starves on B, and its two-pip side goes amber
	var w := b + Vector2i(6, 6)
	sim.place(Sim.SUB, w, 2)
	put.call(w + Vector2i(0, 3), 3)
	sim.lay_run([w + Vector2i(0, 2), w + Vector2i(0, 1)], 3)
	sim.events.clear()
	_s.board.relay()

func _process(delta: float) -> bool:
	_t += delta
	if _t > 150.0:
		print("gave up at step %d" % _step)
		_fails += 1
		return _done()
	var sim = _s.sim if _s != null else null
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_next()
		1:
			if _t > _at + 1.0:
				# Tally stands on the tab's second page
				_menu._turn_page(1)
				_next()
		2:
			if _t > _at + 0.8:
				_shot("1_tab")
				_menu._open_arcade("tally")
				_s = _menu.get_node("Tally")
				_next()
		3:
			if _t > _at + 1.2:
				_shot("2_new")
				_dig = _nearest_one(sim)
				_s.board.look_at_square(Vector2(_dig) + Vector2(0.5, 0.5), true)
				_next()
		4:
			if _t > _at + 0.3:
				_tap_tray(2)
				_tap(_square(_dig))
				_check("a real tap with Dig on the nearest 1 drops its ghost and the builder pill", _s.board.pill_open() and sim.kind_at(_dig) == Sim.EMPTY)
				_check("the pill's Place button has a place on the board", _s.board.pill_button_rect("place").size.x > 0.0)
				_next()
		5:
			if _t > _at + 0.4:
				_shot("2b_pill")
				_tap_pill("place")
				_check("a real tap on Place sets the dig there and shuts the pill", sim.kind_at(_dig) == Sim.DIG and not _s.board.pill_open())
				_tap_tray(1)
				_trace(_route_points(_dig))
				var outs: PackedInt32Array = sim.digs[Sim._i(_dig)].outs
				_check("the traced path laid a run leading away from the dig (%d belts)" % sim.lanes.size(), outs.size() == 1 and sim.lanes.size() >= 2)
				var pts: Array = _route_points(_dig)
				if pts.size() == 3:
					var corner: Vector2i = pts[1]
					var next_f: int = Sim.DIRS.find(((pts[2] as Vector2i) - corner).sign())
					_check("the path's corner square faces the next leg", sim.kind_at(corner) == Sim.BELT and sim.face_at(corner) == next_f)
				_step = 21
				_at = _t
		21:
			if _t > _at + 0.3:
				_check("the undo chip is up after the path", _s.undo_chip.visible)
				_tap(_win(_s.undo_chip, _s.undo_chip.size * 0.5))
				_check("a real tap on the chip takes the path back (%d belts)" % sim.lanes.size(), sim.lanes.size() == 0 and not sim.can_undo())
				_trace(_route_points(_dig))
				_check("traced again, the run is back (%d belts)" % sim.lanes.size(), sim.lanes.size() >= 2)
				_s.board.look_at_square(Vector2(Sim.HUB_AT) + Vector2(2, 2) + (Vector2(_dig) - Vector2(Sim.HUB_AT)) * 0.4, true)
				_step = 5
				_next()
		6:
			if _t > _at + 4.0:
				_shot("3_riding")
				# hurry the first level along
				sim.step(25.0)
				_next()
		7:
			if _t > _at + 0.3:
				_check("ten 1s through the real run finish level 1 (level %d, made %d)" % [sim.level, sim.made], sim.level >= 2)
				_shot("4_level")
				_next()
		8:
			if _t > _at + 2.4:
				_grow(sim)
				_s.board.look_at_square(Vector2(Sim.HUB_AT) + Vector2(2, 3), true)
				_next()
		9:
			if _t > _at + 6.0:
				_check("the subtractor fed on A alone is starving on B", sim.starving(Sim._i(Sim.HUB_AT + Vector2i(6, 6))) == 1)
				_shot("5_grown")
				_s.board.k = 150.0
				_s.board.look_at_square(Vector2(Sim.HUB_AT + Vector2i(-4, 1)) + Vector2(2.0, 0.5), true)
				_next()
		10:
			if _t > _at + 1.0:
				_shot("5b_close")
				_s.board.k = 74.0
				_s.board.look_at_square(Vector2(Sim.HUB_AT) + Vector2(2, 3), true)
				# a real two-finger pinch out about the middle
				var mid: Vector2 = _win(_s.board, _s.board.view.get_center())
				_touch(mid + Vector2(-160, 0), true, 0)
				_touch(mid + Vector2(160, 0), true, 1)
				for j in range(1, 7):
					_drag_ev(mid + Vector2(-160 + j * 20, 0), 0)
					_drag_ev(mid + Vector2(160 - j * 20, 0), 1)
				_touch(mid + Vector2(-40, 0), false, 0)
				_touch(mid + Vector2(40, 0), false, 1)
				_next()
		11:
			if _t > _at + 0.6:
				_check("a real pinch in zooms out (k %.1f from 74)" % _s.board.k, _s.board.k < 74.0 * 0.6 or _blind)
				_shot("6_far")
				_s.board.k = 74.0
				_s.board.look_at_square(Vector2(Sim.HUB_AT) + Vector2(-2, 2), true)
				_tap_tray(0)
				_next()
		12:
			if _t > _at + 0.5:
				_tap(_square(Sim.HUB_AT + Vector2i(-4, 1)))
				_check("a real tap with Look on the adder opens its pill, with Turn", _s.board.pill_open() and _s.board.pill_button_rect("turn").size.x > 0.0)
				_step = 22
				_at = _t
		22:
			if _t > _at + 0.4:
				_shot("6b_pill")
				_tap_pill("info")
				_check("a real tap on the pill's Info opens the adder's card", _s.get_node_or_null("Card") != null and not _s.board.pill_open())
				_step = 12
				_next()
		13:
			if _t > _at + 0.6:
				_shot("7_card")
				_close("Card")
				_next()
		14:
			if _t > _at + 0.4:
				_tap(_win(_s.hud, _s._goal_rect().get_center()))
				_check("a real tap on the goal plate opens the box's card", _s.get_node_or_null("Card") != null and _s.get_node("Card").box)
				_next()
		15:
			if _t > _at + 0.6:
				_shot("8_box")
				_close("Card")
				for a: Array in sim.asks("belt"):
					sim.ledger[int(a[0])] = int(a[1]) + 5
				for a: Array in sim.asks("add"):
					sim.ledger[int(a[0])] = int(a[1]) / 2
				_next()
		16:
			if _t > _at + 0.3:
				_tap(_win(_s.hud, _s._up_rect().get_center()))
				_check("a real tap on the upgrades button opens them", _s.get_node_or_null("Shop") != null)
				_next()
		17:
			if _t > _at + 0.6:
				_shot("9_shop")
				var shop: Node = _s.get_node_or_null("Shop")
				if shop == null:
					_fails += 1
					return _done()
				var before := int(sim.lv.belt)
				shop._buy("belt")
				_check("the belt's rank is bought", int(sim.lv.belt) == before + 1)
				_next()
		18:
			if _t > _at + 0.5:
				_shot("9b_bought")
				_close("Shop")
				_tap_tray(1)
				_tap(_square(Sim.HUB_AT + Vector2i(1, 1)))
				_next()
		19:
			if _t > _at + 0.4:
				_tap_tray(9)
				_next()
		20:
			if _t > _at + 0.4:
				_shot("10_say")
				_close("Card")
				_s.tutor.show()
				_card = _s.get_node_or_null("HowToPlay")
				_check("the tutorial card opens", _card != null)
				if _card == null:
					return _done()
				_step = 23
				_at = _t
		23:
			# the Dig page: the finger is on the pill's Place from 1.85 to 2.0 s
			if _t > _at + 1.75:
				var page: Control = _card._pages[0].diagram
				_shot("11_tut_dig")
				_check("the Dig page's finger has the builder pill up with Place", page._board.pill_open() and page._board.pill_button_rect("place").size.x > 0.0)
				_next()
		24:
			if _t > _at + 3.5:
				var page: Control = _card._pages[0].diagram
				var dug: bool = page._sim.kind_at(Vector2i(16, 22)) == Sim.DIG
				var laid: bool = page._sim.kind_at(Vector2i(17, 22)) == Sim.BELT and page._sim.kind_at(Vector2i(20, 22)) == Sim.BELT and page._sim.face_at(Vector2i(20, 22)) == 0
				_check("the Dig page placed the dig through Place and traced the belt to the box", dug and laid)
				_card._turn(1)
				_card._turn(1)
				_next()
		25:
			# the Machine page: the ghost dropped facing north at 1.15 s, turned east by 2.2 s
			if _t > _at + 2.6:
				var page: Control = _card._pages[2].diagram
				_shot("12_tut_machine")
				_check("the Machine page's ghost was turned once, to face east", page._board.pill_open() and not page._board._ghost.is_empty() and int(page._board._ghost.face) == 0)
				_next()
		26:
			if _t > _at + 1.4:
				var page: Control = _card._pages[2].diagram
				_check("the Machine page placed the adder facing east", page._sim.kind_at(Vector2i(18, 22)) == Sim.ADD and page._sim.face_at(Vector2i(18, 22)) == 0)
				_card._turn(1)
				_next()
		27:
			if _t > _at + 5.2:
				var page: Control = _card._pages[3].diagram
				_check("the Belts page's trace across the line made a bridge", page._sim.kind_at(Vector2i(16, 22)) == Sim.BRIDGE)
				_card.free()
				return _done()
	return false
