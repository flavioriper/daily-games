extends SceneTree

## Teacups shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## board on that level and shoots the table at rest, a cup lifted, a miss,
## a pair found, a waltz mid-way (d=3), the win settled and the day reopened
## from its card, with the draw calls of each frame. `tut` shoots a tutorial
## page played a while; `card` the menu card beside Domino Patio's. Puts
## nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 1
var _f := 0
var _step := 0
var _diag: Control

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_band = int(a.substr(2))
		elif a.begins_with("tut"):
			_step = 50
			if a.begins_with("tut="):
				_page = int(a.substr(4))
		elif a == "card":
			_step = 60
		else:
			_dir = a
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_shot_teacups.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("teacups")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/tc_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

func _tap(s: int) -> void:
	_b.demo_tap(s)

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["teacups", "patio"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("e58f7b"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "teacups" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("teacups"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("teacups"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s lifts=%d" % [_b.is_done(), _b.state().lifts])
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	match _step:
		0:
			_shot("rest")
			_tap(st.slot[0])
			_step = 1
			_f = 1000
		1:
			if _f == 1020:
				_shot("lifted")
				var other := 1 if st.partner(0) != 1 else 2
				_tap(st.slot[other])
				_step = 2
				_f = 2000
		2:
			if _f == 2020:
				_shot("miss")
			if _f == 2080:
				var p: int = st.partner(st.hidden()[0])
				_tap(st.slot[st.hidden()[0]])
				_tap(st.slot[p])
				_step = 3
				_f = 3000
		3:
			if _f == 3008:
				_shot("pair_flying")
			if _f == 3040:
				_shot("pair")
				_step = 4 if _band == 3 else 5
				_f = 4000
		4:
			# a second miss sets a waltz going
			if _f == 4001:
				var a: int = st.hidden()[0]
				for c in st.hidden():
					if st.kind[c] != st.kind[a]:
						_tap(st.slot[a])
						_tap(st.slot[c])
						break
			if _f == 4120 and st.misses < 2:
				var a: int = st.hidden()[0]
				for c in st.hidden():
					if st.kind[c] != st.kind[a]:
						_tap(st.slot[a])
						_tap(st.slot[c])
						break
			if _f > 4120 and _b._waltz_at.max() > -INF and _b._t - _b._waltz_at.max() > 0.3:
				_shot("waltz")
				_step = 5
		5:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif _b.phase() == _b.Phase.PLAY and _f % 8 == 0:
				var a: int = st.hidden()[0]
				_tap(st.slot[a])
				_tap(st.slot[st.partner(a)])
		6:
			if _f == 6012:
				_shot("won_early")
			if _f == 6240:
				_shot("won")
				_host.closed.emit()
				_step = 7
				_f = 7000
		50:
			var pages: Array = _b.tutorial_pages()
			_diag = pages[clampi(_page, 0, pages.size() - 1)].diagram
			var holder := ColorRect.new()
			holder.color = Color.WHITE
			holder.size = Vector2(620, 520)
			holder.position = Vector2(95, 300)
			var layer := CanvasLayer.new()
			layer.layer = 100
			root.add_child(layer)
			layer.add_child(holder)
			_diag.size = holder.size
			holder.add_child(_diag)
			_step = 51
			_f = 8000
		51:
			if _f == 8000 + 90:
				_shot("tut%d_a" % _page)
			if _f == 8000 + 200:
				_shot("tut%d_b" % _page)
				return true
	return false
