extends SceneTree

## Padlock shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## lock on that level and shoots it at rest, a dial dragged by a real
## pointer (mid-drag and settling), a word dialled and lit, the same word
## again, the bulb's reading and its word, the win settled and the day
## reopened from its card, with the draw calls of each frame. On d=3 the
## rusty dial is pushed up (refused) and down past its last letter (round).
## `tut` shoots a tutorial page played a while; `card` the menu card beside
## Cross Stitch's. Puts nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 0
var _f := 0
var _step := 0
var _diag: Control
var _at := 90
var _word := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_band = int(a.substr(2))
		elif a.begins_with("tut"):
			_step = 50
			if a.begins_with("tut="):
				_page = int(a.substr(4))
		elif a.begins_with("at="):
			_at = int(a.substr(3))
		elif a == "card":
			_step = 60
		else:
			_dir = a
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_shot_padlock.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("padlock")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _finish() -> void:
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	quit()

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/pl_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

## A press, a move or a release on the board, in its own coordinates,
## through its _gui_input (the window's pointer stays out of it).
func _touch(local: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = local
	_b._gui_input(e)

func _drag_to(local: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = local
	_b._gui_input(e)

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["padlock", "crossstitch"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("e2825f"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "padlock" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			quit()
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("padlock"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("padlock"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s solved=%s found=%s" % [_b.is_done(), _b.is_solved(), _b.state().found])
			_finish()
			return true
		return false
	if _b == null:
		_b = _host._puzzle
		_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st = _b.state()
	match _step:
		0:
			_shot("rest")
			print("dials %s window %s par %d words %d rusty %d" % [st.dials, st.window(), st.par, st.words.size(), st.rusty])
			# a real finger drags the first plain dial down two letters' worth
			var k := 0 if st.rusty != 0 else 1
			var at: Vector2 = _b.cell_to_local(k, st.pos[k])
			_touch(at, true)
			_step = 1
			_f = 1000
		1:
			var k := 0 if st.rusty != 0 else 1
			pass
			if _f >= 1001 and _f <= 1010:
				var c: float = _b._l("cell")
				_drag_to(_b.get("_press_pos") + Vector2(0.0, c * 0.17 * (_f - 1000) * (-1.0 if st.pos[k] == 0 else 1.0)))
			if _f == 1011:
				_shot("dragging")
				print("held=%d vis=%.2f" % [_b._held, _b._vis[k]])
				_touch(_b.get("_press_pos") + Vector2(0.0, _b._l("cell") * 1.7 * (-1.0 if st.pos[k] == 0 else 1.0)), false)
			if _f == 1015:
				_shot("settling")
			if _f == 1040:
				print("after drag: pos=%s window=%s" % [st.pos, st.window()])
				_step = 2
				_f = 2000
		2:
			if _f == 2001:
				_word = st.hint_word()
				for k in st.length():
					var i: int = st.dials[k].find(_word[k])
					if i != st.pos[k] and st.can_turn(k, i):
						_b.demo_turn(k, i)
					elif i != st.pos[k]:
						st.dial_to(_word)
						_b._fresh()
			if _f == 2012:
				_shot("lighting")
			if _f == 2040:
				_shot("word")
				print("word %s found=%s lit dark=%d counted=%d stars=%d to_go=%d" % [_word, st.found, st.dark_count(), st.counted, st.stars(), st.to_go])
				# the same word again: nudge a dial off and back
				var k := 0
				var other: int = (int(st.pos[k]) + 1) % String(st.dials[k]).length()
				_b.demo_turn(k, other)
			if _f == 2060:
				var k := 0
				_b.demo_turn(k, st.dials[k].find(_word[k]))
			if _f == 2080:
				_shot("again")
				_step = 3
				_f = 3000
		3:
			if _f == 3001:
				_b.hint()
			if _f == 3020:
				_shot("reading")
				_b.hint()
			if _f == 3060:
				_shot("hinted")
				print("after bulb: counted=%d helped=%d dark=%d" % [st.counted, st.helped, st.dark_count()])
				if st.rusty >= 0:
					_step = 10
					_f = 10000
				else:
					_step = 4
					_f = 4000
		10:
			# the rusty dial: pushed up (refused), then down past its end
			var k: int = st.rusty
			if _f == 10001:
				_touch(_b.cell_to_local(k, st.pos[k]), true)
			if _f >= 10002 and _f <= 10008:
				_drag_to(_b.get("_press_pos") + Vector2(0.0, _b._l("cell") * 0.2 * (_f - 10001)))
			if _f == 10009:
				_shot("rusty_up")
				_touch(_b.get("_press_pos") + Vector2(0.0, _b._l("cell") * 1.4), false)
				print("rusty up: pos=%d said=%s" % [st.pos[k], _b._say])
			if _f == 10030:
				_touch(_b.cell_to_local(k, st.pos[k]), true)
			if _f >= 10031 and _f <= 10060:
				_drag_to(_b.get("_press_pos") - Vector2(0.0, _b._l("cell") * 0.3 * (_f - 10030)))
			if _f == 10061:
				_shot("rusty_round")
				_touch(_b.get("_press_pos"), false)
				print("rusty round: pos=%d" % st.pos[k])
			if _f == 10090:
				_step = 4
				_f = 4000
		4:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif not _b.busy() and _f % 12 == 0:
				var w: String = st.hint_word()
				for k in st.length():
					var i: int = st.dials[k].find(w[k])
					if i != st.pos[k]:
						if st.can_turn(k, i):
							_b.demo_turn(k, i)
						else:
							st.turn(k, st.dials[k].length() - 1)
							st.turn(k, 0)
							_b._vis[k] = 0.0
							_b.demo_turn(k, i)
		6:
			if _f == 6012:
				_shot("won_early")
			if _f == 6040:
				_shot("opening")
			if _f == 6240:
				_shot("won")
				print("won counted=%d helped=%d par=%d stars=%d quality=%.2f" % [st.counted, st.helped, st.par, st.stars(), _b.skill_quality()])
				print(_b.share_glyphs())
				_host.closed.emit()
				_step = 7
				_f = 7000
		7:
			if _f == 7005:
				_menu._open_at(load("res://ui/registry.gd").find("padlock"), _band)
				_host = _menu.get_child(_menu.get_child_count() - 1)
			if _f == 7200:
				_b = _host._puzzle
				_shot("reopen")
				print("reopen done=%s solved=%s found=%s" % [_b.is_done(), _b.is_solved(), _b.state().found])
				_finish()
				return true
		50:
			if _f == 61:
				var pages: Array = _b.tutorial_pages()
				_diag = pages[clampi(_page, 0, pages.size() - 1)].diagram
				var layer := CanvasLayer.new()
				layer.layer = 100
				root.add_child(layer)
				var holder := ColorRect.new()
				holder.color = Color.WHITE
				holder.size = Vector2(620, 620)
				holder.position = Vector2(95, 300)
				layer.add_child(holder)
				_diag.size = holder.size
				holder.add_child(_diag)
				print("page %d of %d: %s" % [_page, pages.size(), pages[clampi(_page, 0, pages.size() - 1)].title])
			if _f == 61 + _at:
				_shot("tut%d_a" % _page)
			if _f == 61 + _at + 40:
				_shot("tut%d_b" % _page)
				_finish()
				return true
	return false
