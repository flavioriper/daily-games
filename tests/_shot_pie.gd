extends SceneTree

## Who Ate the Pie? shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens
## the board on that level and shoots the table at rest, a baker picked, a
## refused mark, a card turning, a baker marked and their clue, a slip, the
## bulb, the win settled and the day reopened from its card, with the draw
## calls of each frame. `tut` shoots a tutorial page played a while; `card`
## the menu card beside Market Sums'; `lang=pt` plays it in that language. Puts nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 0
var _f := 0
var _step := 0
var _diag: Control
var _lang := ""

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
		elif a.begins_with("lang="):
			_lang = a.substr(5)
		else:
			_dir = a
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_shot_pie.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("pie")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/pi_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["pie", "market"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("4c9a94"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "pie" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 4 and _lang != "":
		TranslationServer.set_locale(_lang)
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("pie"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("pie"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s slips=%d marked=%d" % [_b.is_done(), _b.state().slips, _b.state().marked])
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	match _step:
		0:
			_shot("rest")
			print("day %dx%d ate=%d dish=%d start=%d" % [st.cols, st.rows, st.ate, st.dish, st.start])
			for i in st.count():
				print("  %s %s: %s" % [st.names[i], "ATE" if st.did_eat(i) else "-", _b.clue_text(i)])
			# a baker nothing proves yet, marked: refused
			for i in st.count():
				if not st.is_marked(i) and not st.proven(i):
					_b.demo_select(i)
					break
			_step = 1
			_f = 1000
		1:
			if _f == 1010:
				_shot("picked")
				_b.demo_mark(false)
			if _f == 1016:
				_shot("refused")
				var p: int = st.hint_baker(-1)
				_b.demo_select(p)
				_b.demo_mark(st.did_eat(p))
			if _f == 1025:
				_shot("turning")
			if _f == 1050:
				_shot("marked")
				var p: int = st.hint_baker(-1)
				_b.demo_select(p)
				_b.demo_mark(not st.did_eat(p))
			if _f == 1056:
				_shot("slip")
				_step = 3
				_f = 3000
		3:
			if _f == 3040:
				_b.hint()
			if _f == 3080:
				_shot("hinted")
				_step = 5
				_f = 5000
		5:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif _f % 8 == 0:
				var i: int = st.hint_baker(-1)
				if i < 0:
					return false
				_b.demo_select(i)
				_b.demo_mark(st.did_eat(i))
			if _f == 5040:
				_shot("midway")
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
			holder.size = Vector2(620, 620)
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
			if _f == 8000 + 260:
				_shot("tut%d_b" % _page)
				return true
	return false
