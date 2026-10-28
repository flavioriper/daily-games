extends SceneTree

## Hosepipes shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## board on that level and shoots the bed at rest, a hose mid-drag, another
## hose cut by a drag across it, a hose joined (its flower opening, water
## running), an Undo, the bulb's hose drawn out, the bed half done, the win
## settled and the day reopened from its card, with the draw calls of each
## frame. `tut` shoots a tutorial page played a while; `card` the menu card
## beside Market Sums'. Puts nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 0
var _f := 0
var _step := 0
var _diag: Control
var _order: Array = []

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
	progress.path = "user://progress_shot_hoses.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("hoses")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/hs_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

## Hose `c` drawn whole along the answer, as a finger would.
func _draw_answer(c: int) -> void:
	var p: Array = _b.state().answer[c]
	_b.demo_press(int(p[0]))
	for i in range(1, p.size()):
		_b.demo_move(int(p[i]))
	_b.demo_release()

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["hoses", "market"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("4c9a94"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "hoses" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("hoses"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("hoses"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s joined=%d watered=%d" % [_b.is_done(), _b.state().joined_count(), _b.state().watered()])
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	match _step:
		0:
			_shot("rest")
			_order = range(st.count())
			_order.sort_custom(func(a, b): return (st.answer[a] as Array).size() > (st.answer[b] as Array).size())
			print("bed %dx%d, %d hoses, seeds %s" % [st.n, st.n, st.count(), str(st.seeds)])
			# the longest hose half drawn, the finger still down
			var p: Array = st.answer[_order[0]]
			_b.demo_press(int(p[0]))
			for i in range(1, p.size() / 2 + 1):
				_b.demo_move(int(p[i]))
			_step = 1
			_f = 1000
		1:
			if _f == 1008:
				_shot("drawing")
				_b.demo_release()
				_draw_answer(_order[0])
				# another tap dragged across the longest hose
				var path_a: Array = st.answer[_order[0]]
				var mid := int(path_a[path_a.size() / 2])
				for c in st.count():
					var tap := int((st.ends[c] as Array)[0])
					if c != _order[0] and st.adjacent(tap, mid):
						_b.demo_press(tap)
						_b.demo_move(mid)
						break
			if _f == 1012:
				_shot("cut")
				_b.demo_release()
				_b.undo()
				_step = 2
				_f = 2000
		2:
			if _f == 2004:
				_draw_answer(_order[1])
			if _f == 2010:
				_shot("joined")
			if _f == 2060:
				_shot("joined_late")
				if _band < 3:
					_b.undo()
				_step = 3
				_f = 3000
		3:
			if _f == 3006:
				_shot("undone")
			if _f == 3040:
				_b.hint()
			if _f == 3046:
				_shot("reading")
			if _f == 3048:
				_b.hint()
			if _f == 3050:
				_shot("hinting")
			if _f == 3090:
				_shot("hinted")
				_step = 5
				_f = 5000
		5:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif _f % 12 == 0:
				var left := -1
				for c in st.count():
					if st.hoses[c] != st.answer[c]:
						left = c
						break
				if left < 0:
					return false
				_draw_answer(left)
				if st.joined_count() == st.count() / 2 + 1:
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
			if _f == 8000 + 150:
				_shot("tut%d_m" % _page)
			if _f == 8000 + 300:
				_shot("tut%d_b" % _page)
				return true
	return false
