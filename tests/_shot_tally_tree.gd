extends SceneTree

## Tally's upgrades tree (arcade/tally_shop.gd) on its own, shot at fixed
## beats:
##
##     godot --resolution 810x1440 --always-on-top --script tests/_shot_tally_tree.gd -- <outdir> [en|pt|es]
##
## A sim at level 9 whose tally meets the belts' next rank (the digs at their
## top, the adders half way): 1 the card as it opens (the belts chosen, since
## they can be bought), 2 the adders by a real tap on their plate, 3 the
## belts again, 4 a rank bought by a real press on the sun bar, 5 a shut
## track (the raisers) by a tap, 6 the card at level 1, then, unshot, the
## card on a host 1300 tall where the tree pans under a finger. Checks that the foot
## names what was tapped, that the belt's rank went up, that no plate meets
## another and that the tree fits the field without a pan, and prints the
## draw calls at each shot. Headless it shoots nothing and prints 0 failed.

const Sim = preload("res://arcade/tally_sim.gd")
const Shop = preload("res://arcade/tally_shop.gd")
const CozyTheme = preload("res://ui/theme.gd")

var _host: Control
var _shop: Control
var _sim: RefCounted
var _t := 0.0
var _at := 0.0
var _step := 0
var _out := "/tmp"
var _blind := false
var _fails := 0
var _closed := false
var _short: Control
var _before_y := 0.0

func _initialize() -> void:
	_blind = DisplayServer.get_name() == "headless"
	var lang := "en"
	for a: String in OS.get_cmdline_user_args():
		if a in ["en", "pt", "es"]:
			lang = a
		else:
			_out = a
	CozyTheme.dress(self)
	# the words in English unless asked, whatever this Mac speaks (there is
	# no Locale autoload: the statics are called as world/main.gd calls them)
	load("res://core/locale.gd")._current = lang
	load("res://core/locale.gd").apply()
	_host = Control.new()
	_host.name = "Host"
	_host.theme = CozyTheme.make()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_host)
	_sim = Sim.new(7)
	_sim.level = 9
	_sim.lv.dig = int(Sim.TRACK_TOP.dig)
	for a: Array in _sim.asks("belt"):
		_sim.ledger[int(a[0])] = int(a[1]) + 5
	for a: Array in _sim.asks("add"):
		_sim.ledger[int(a[0])] = int(a[1]) / 2
	_mount()

func _mount() -> void:
	_closed = false
	_shop = Shop.new()
	_shop.name = "Shop"
	_shop.sim = _sim
	_shop.closed.connect(func() -> void:
		_closed = true)
	_host.add_child(_shop)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

func _shot(name: String) -> void:
	if not _blind:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/tree_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

func _win(c: Control, at: Vector2) -> Vector2:
	return root.get_final_transform() * (c.get_global_transform_with_canvas() * at)

func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = at
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _drag_ev(at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = at
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _tap(at: Vector2) -> void:
	_touch(at, true)
	_touch(at, false)

func _plate(id: String) -> Vector2:
	return _win(_shop._field, _shop.plate_center(id))

func _label(nm: String) -> Label:
	return _shop.find_child(nm, true, false) as Label

## No plate's rect (a shut one's tag counted) meets another's.
func _check_layout(when: String) -> void:
	var rects: Dictionary = _shop.plate_rects()
	var clear := true
	var ids := rects.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if (rects[ids[i]] as Rect2).intersects(rects[ids[j]]):
				clear = false
				print("  %s meets %s" % [ids[i], ids[j]])
	_check("no plate meets another (%s)" % when, clear)
	var field: Control = _shop._field
	var inside := true
	for id in ids:
		var r: Rect2 = rects[id]
		if r.position.y < 0.0 or r.end.y > field.size.y:
			inside = false
	_check("every plate lies within the field (%s)" % when, inside)
	_check("the tree fits the field without a pan (%s): field %s, cell %d" % [when, str(field.size), int(_shop._cell_y)], _shop._pan_most == 0.0)

func _next() -> void:
	_at = _t
	_step += 1

func _done() -> bool:
	print("%d failed" % _fails)
	return true

func _process(delta: float) -> bool:
	_t += delta
	match _step:
		0:
			if _t > 0.5:
				print("root %s" % str(root.get_visible_rect().size))
				_shot("1_open")
				_check("the words are English", tr("TL_UPGRADES") == "Upgrades")
				_check("the belts are chosen on opening (they can be bought)", _shop._chosen == "belt")
				_check("the foot names the belts", _label("Name").text == tr("TL_TRACK_BELT"))
				_check("the bar says Up", _shop._bar.label_text == tr("TL_BUY") and not _shop._bar.disabled)
				_check_layout("level 9")
				_tap(_plate("add"))
				_next()
		1:
			if _t > _at + 0.4:
				_check("a real tap on the adders' plate chooses them", _shop._chosen == "add")
				_check("the foot names the adders", _label("Name").text == tr("TL_TRACK_ADD"))
				_check("the bar says what is short", _shop._bar.disabled and _shop._bar.label_text.begins_with(tr("TL_SHORT_OF").split(" ")[0]))
				_shot("2_adders")
				_tap(_plate("belt"))
				_next()
		2:
			if _t > _at + 0.4:
				_check("a tap on the belts' plate chooses them", _shop._chosen == "belt")
				_shot("3_belts")
				_touch(_win(_shop._bar, _shop._bar.size * 0.5), true)
				_next()
		3:
			if _t > _at + 0.15:
				_touch(_win(_shop._bar, _shop._bar.size * 0.5), false)
				_next()
		4:
			if _t > _at + 0.5:
				_check("a real press on the sun bar buys the belts' rank", int(_sim.lv.belt) == 2)
				_check("the bar is off once the tally is spent", _shop._bar.disabled)
				_check("the foot's line moved on to level 2", _label("Status").text.begins_with(tr("TL_TRACK_LINE").split(" ")[0] + " 2"))
				_shot("4_bought")
				_tap(_plate("pow"))
				_next()
		5:
			if _t > _at + 0.4:
				_check("a tap on a shut plate chooses it", _shop._chosen == "pow")
				_check("the foot says when it opens", _label("Status").text == tr("TL_OPENS_AT") % 20)
				_check("no bar on a shut track", not _shop._bar.visible)
				_shot("5_shut")
				_tap(_plate("dig"))
				_next()
		6:
			if _t > _at + 0.4:
				_check("the digs at their top say so", _label("Status").text.ends_with(tr("TL_AT_TOP").split("·")[-1]))
				_shot("6_top")
				var x: Control = _shop.find_child("Close", true, false)
				_tap(_win(x, x.size * 0.5))
				_next()
		7:
			if _t > _at + 0.4:
				_check("the X closes the card", _closed and (_shop == null or not is_instance_valid(_shop) or _shop.is_queued_for_deletion()))
				_sim = Sim.new(7)
				_mount()
				_next()
		8:
			if _t > _at + 0.5:
				_check("at level 1 the belts are chosen", _shop._chosen == "belt")
				_check_layout("level 1")
				_shot("7_level1")
				_shop.close()
				# a short screen: the card on a host 1300 tall, so the tree is
				# taller than its field and pans under a finger
				_short = Control.new()
				_short.name = "Short"
				_short.theme = CozyTheme.make()
				_short.size = Vector2(1080.0, 1300.0)
				root.add_child(_short)
				_shop = Shop.new()
				_shop.name = "Shop"
				_shop.sim = _sim
				_short.add_child(_shop)
				_next()
		9:
			if _t > _at + 0.5:
				_check("on a short screen the tree is taller than the field (field %s, pan %d)" % [str(_shop._field.size), int(_shop._pan_most)], _shop._pan_most > 0.0)
				var p: Control = _shop._plates["belt"]
				_before_y = p.position.y
				var mid: Vector2 = _shop._field.size * 0.5
				_touch(_win(_shop._field, mid), true)
				for j in range(1, 7):
					_drag_ev(_win(_shop._field, mid + Vector2(0.0, 50.0 * j)))
				_next()
		10:
			# the finger rests before it lifts, so the tree stands where it was left
			if _t > _at + 0.25:
				_touch(_win(_shop._field, _shop._field.size * 0.5 + Vector2(0.0, 300.0)), false)
				_next()
		11:
			if _t > _at + 0.3:
				var p: Control = _shop._plates["belt"]
				_check("a finger drawn down 300 px pans the tree down (pan %d)" % int(_shop._pan), _shop._pan > 200.0 and _shop._pan <= 300.0)
				_check("the plates went with it", absf((p.position.y - _before_y) - _shop._pan) < 1.0)
				_check("a drag chooses nothing", _shop._chosen == "belt")
				_shop.close()
				_next()
		12:
			if _t > _at + 0.2:
				return _done()
	return false
