extends SceneTree

## Picket Sums shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## board on that level and shoots it at rest, a cell selected (its plot's
## fence lit), a plot gone wrong (rose), a plot come right (green, its tag
## hopping), the win settled and the day reopened from its card, with the
## draw calls of each frame. `tut` shoots a tutorial page played a while;
## `card` the menu card beside Sudoku's. Puts nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 0
var _f := 0
var _step := 0
var _diag: Control
var _plot := -1

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
	progress.path = "user://progress_shot_picket.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("picket")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/pk_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

func _tap(i: int) -> void:
	var n: int = load("res://puzzles/sudoku_gen.gd").N
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = _b.cell_to_local(i / n, i % n)
	_b._gui_input(ev)

func _put(i: int, d: int) -> void:
	if _b._sel != i:
		_tap(i)
	_b.pick(d - 1)

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["picket", "sudoku"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("8fb36a"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "picket" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("picket"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("picket"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s" % _b.is_done())
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state
	match _step:
		0:
			_shot("rest")
			print("plots=%d lost=%d givens=%d" % [st.plots.size(), st.lost_count(),
				st.given.size() - st.given.count(0)])
			# The first open plot of two or more.
			for p in st.plots.size():
				var cells: PackedInt32Array = st.plots[p]
				if cells.size() >= 2 and st.grid[cells[0]] == 0 and st.grid[cells[1]] == 0:
					_plot = p
					break
			_tap(st.plots[_plot][0])
			_step = 1
			_f = 1000
		1:
			if _f == 1020:
				_shot("selected")
				# A number too big for the plot: the tag less one, or a
				# number twice.
				var cells: PackedInt32Array = st.plots[_plot]
				var big := mini(9 if st.sol.size() == 81 else 6, maxi(1, st.sums[_plot] - 1))
				_put(cells[0], big)
				_put(cells[1], big)
				_step = 2
				_f = 2000
		2:
			if _f == 2012:
				_shot("wrong")
			if _f == 2030:
				var cells: PackedInt32Array = st.plots[_plot]
				for i in cells:
					if st.grid[i] != st.sol[i]:
						_put(i, st.sol[i])
				_step = 3
				_f = 3000
		3:
			if _f == 3008:
				_shot("plot_up")
			if _f == 3040:
				_shot("plot_done")
				_step = 5
				_f = 5000
		5:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif _f % 2 == 0:
				for i in st.sol.size():
					if st.grid[i] != st.sol[i]:
						_put(i, st.sol[i])
						break
		6:
			if _f == 6030:
				_shot("won_early")
			if _f == 6260:
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
