extends SceneTree

## Four Shelves shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## board on that level and shoots the mat at rest, a wrong pick struck, the
## bulb's strike, the fold mid-way, the box turned, the box flying, the
## next round, the win settled and the day reopened from its card, with the
## draw calls of each frame. `tut` shoots a tutorial page played a while;
## `card` the menu card beside Hosepipes'. Puts nothing in the player's save.

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
		elif a == "out":
			_step = 40
		else:
			_dir = a
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_shot_shelves.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("shelves")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/fs_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

## The board stepped `s` seconds on its own clock.
func _run(s: float) -> void:
	var n := int(s / 0.05)
	for i in n:
		_b._process(0.05)

func _pick(words: Array) -> void:
	for w in words:
		_b.demo_tap_word(w)
	_b.demo_key(_b.Key.ENTER)

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["shelves", "hoses"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("6fa3c9"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "shelves" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("shelves"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("shelves"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s wrongs=%d" % [_b.is_done(), _b.state().mistakes])
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	if not _b.dealt():
		return false
	match _step:
		0:
			_shot("rest")
			var g0: Array = st.groups[0].words
			for w in [g0[0], g0[1], g0[2]]:
				_b.demo_tap_word(w)
			_b.demo_tap_word(st.groups[1].words[0])
			_step = 1
			_f = 1000
		1:
			if _f == 1010:
				_shot("picked")
				_b.demo_key(_b.Key.ENTER)
			if _f == 1060:
				_shot("close")
				_b.demo_key(_b.Key.DELETE)
				_b.hint()
				_step = 2
				_f = 2000
		2:
			if _f == 2010:
				_shot("hinted")
				var g0: Array = st.groups[0].words
				for w in g0:
					if not st.picked.has(w):
						_b.demo_tap_word(w)
				_b.demo_key(_b.Key.ENTER)
			if _f == 2044:
				_shot("rising")
			if _f == 2090:
				_shot("shelved")
				_step = 5
				_f = 5000
		5:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif not _b.busy() and _f % 10 == 0:
				var g: int = -1
				for k in st.count():
					if not st.shelved.has(k):
						g = k
						break
				st.clear_picks()
				_pick(st.groups[g].words)
		6:
			if _f == 6012:
				_shot("won_early")
			if _f == 6240:
				_shot("won")
				_host.closed.emit()
				_step = 7
				_f = 7000
		40:
			# four wrong fours, each a different mix: the card
			if _f % 12 == 0 and st.hearts > 0 and not _b.busy():
				var n: int = st.HEARTS - st.hearts
				st.clear_picks()
				var mix := [st.groups[0].words[n], st.groups[1].words[n], st.groups[2].words[0], st.groups[2].words[1]]
				_pick(mix)
			if st.hearts == 0 and _f % 12 == 0:
				_f = 4000
				_step = 41
		41:
			if _f == 4200:
				_shot("out_card")
				_b.show_shelves()
			if _f == 4900:
				_shot("shown")
				print("shown done=%s solved=%s q=%s" % [_b.is_done(), st.solved(), st.quality()])
				return true
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
