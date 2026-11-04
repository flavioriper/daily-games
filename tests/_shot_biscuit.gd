extends SceneTree

## Biscuit Tin shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## tin on that level and shoots it at rest, a piece tapped by a real pointer
## and flying, a short word found, a biscuit knitting and flying to the lid,
## the bulb's reading and its biscuit, the win settled and the day reopened
## from its card, with the draw calls of each frame. `tut` shoots a tutorial
## page played a while; `card` the menu card beside Padlock's. Puts nothing
## in the player's save.

const Diagram = preload("res://ui/hud/biscuit_tutorial_diagram.gd")

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
	progress.path = "user://progress_shot_biscuit.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("biscuit")
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
	root.get_texture().get_image().save_png("%s/bt_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

## A press and a release on the board, in its own coordinates, through its
## _gui_input (the window's pointer stays out of it).
func _touch(local: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = local
	_b._gui_input(e)

func _tap(i: int) -> void:
	var at: Vector2 = _b.piece_to_local(i)
	_touch(at, true)
	_touch(at, false)

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["biscuit", "padlock"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("e2825f"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "biscuit" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			quit()
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("biscuit"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("biscuit"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s solved=%s whole=%s" % [_b.is_done(), _b.is_solved(), _b.state().whole])
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
			print("pieces %s biscuits %s line %d words %d crumbs %s" % [st.pieces, st.biscuit_words, st.line, st.word_list.size(), st.crumbs])
			var run: Array = Diagram.short_word(st)
			if run.size() >= 1:
				_tap(run[0])
			_step = 1
			_f = 1000
		1:
			var run: Array = Diagram.short_word(st)
			if _f == 1003:
				_shot("flying")
			if _f == 1020:
				for k in range(1, run.size()):
					_tap(run[k])
			if _f == 1032:
				_shot("word")
				print("word %s points=%d found=%s stars=%d" % [st.plate_word(), st.points, st.found, st.stars()])
			if _f == 1060:
				# the bare plate tapped clears it
				var pr: Rect2 = _b._L.plate
				_touch(pr.position + Vector2(24, pr.size.y * 0.5), true)
				_touch(pr.position + Vector2(24, pr.size.y * 0.5), false)
			if _f == 1080:
				for i in st.biscuits[0]:
					_tap(int(i))
			if _f == 1098:
				_shot("knit")
			if _f == 1112:
				_shot("to_lid")
			if _f == 1160:
				_shot("biscuit")
				print("biscuit whole=%s points=%d stars=%d tin=%d" % [st.whole, st.points, st.stars(), st.in_tin().size()])
				_step = 3
				_f = 3000
		3:
			if _f == 3001:
				_b.hint()
			if _f == 3020:
				_shot("reading")
				_b.hint()
			if _f == 3090:
				_shot("hinted")
				print("after bulb: whole=%s points=%d helped=%d" % [st.whole, st.points, st.helped])
				_step = 4
				_f = 4000
		4:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif not _b.busy() and _f % 10 == 0:
				var b: int = st.hint_biscuit()
				if b >= 0:
					st.clear_plate()
					for i in st.biscuits[b]:
						_tap(int(i))
			if _f == 4004:
				_shot("midway")
		6:
			if _f == 6012:
				_shot("won_early")
			if _f == 6040:
				_shot("winning")
			if _f == 6240:
				_shot("won")
				print("won points=%d line=%d helped=%d stars=%d quality=%.2f" % [st.points, st.line, st.helped, st.stars(), _b.skill_quality()])
				print(_b.share_glyphs())
				_host.closed.emit()
				_step = 7
				_f = 7000
		7:
			if _f == 7005:
				_menu._open_at(load("res://ui/registry.gd").find("biscuit"), _band)
				_host = _menu.get_child(_menu.get_child_count() - 1)
			if _f == 7200:
				_b = _host._puzzle
				_shot("reopen")
				print("reopen done=%s solved=%s whole=%s" % [_b.is_done(), _b.is_solved(), _b.state().whole])
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
