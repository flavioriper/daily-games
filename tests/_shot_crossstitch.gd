extends SceneTree

## Cross Stitch shots: `-- <dir> [d=<0..3>] [out] [tut[=<page>]] [card]`
## opens the board on that level and shoots the sampler at rest, a patch
## picked, a swap in the air and landed, a stitched patch refused, the
## bulb's reading and its swap, a word sewn round, the win settled and the
## day reopened from its card, with the draw calls of each frame. `out`
## spends the swaps badly: the sag, the card, three more swaps, then Show
## the sampler. `tut` shoots a tutorial page played a while; `card` the
## menu card beside Honeycomb's. Puts nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 0
var _f := 0
var _step := 0
var _out := false
var _diag: Control
var _at := 90
var _sewn := false

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
		elif a == "out":
			_out = true
		else:
			_dir = a
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_shot_crossstitch.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("crossstitch")
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
	root.get_texture().get_image().save_png("%s/cs_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

## Two open patches neither of which a swap would stitch.
func _bad_pair() -> Vector2i:
	var st = _b.state()
	for a in 25:
		for c in 25:
			if c > a and st.can_swap(a, c) and st.cells[a] != st.goal[c] and st.cells[c] != st.goal[a] and st.cells[a] != st.cells[c]:
				return Vector2i(a, c)
	return Vector2i(-1, -1)

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["crossstitch", "honeycomb"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("e2825f"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "crossstitch" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			quit()
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("crossstitch"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("crossstitch"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s solved=%s shown=%s used=%d" % [_b.is_done(), _b.is_solved(), _b._shown, _b.state().used])
			_finish()
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	match _step:
		0:
			_shot("rest")
			print("words %s fewest %d budget %d marks %s" % [st.words, st.fewest, st.budget(), st.marks])
			if _out:
				_step = 20
				_f = 20000
				return false
			var h: Vector2i = st.hint_swap()
			_b.demo_pick(h.x)
			_step = 1
			_f = 1000
		1:
			if _f == 1012:
				_shot("picked")
				var h: Vector2i = st.hint_swap()
				_b._picked = -1
				_b.demo_swap(h.x, h.y)
			if _f == 1020:
				_shot("swapping")
			if _f == 1050:
				_shot("swapped")
				# a stitched patch pressed: refused
				var i: int = st.marks.find(0)
				if i >= 0:
					_b._press(_b.tile_to_local(i))
			if _f == 1058:
				_shot("refused")
				_step = 2
				_f = 2000
		2:
			if _f == 2060:
				_b.hint()
			if _f == 2080:
				_shot("reading")
				_b.hint()
			if _f == 2120:
				_shot("hinted")
				_step = 3
				_f = 3000
		3:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif not _b.busy() and _f % 10 == 0:
				var done: int = _b._done_count()
				var h: Vector2i = st.hint_swap()
				_b.demo_swap(h.x, h.y)
				if not _sewn and _b._done_count() > done:
					_sewn = true
					_step = 4
					_f = 4000
		4:
			if _f == 4030:
				_shot("sewing")
			if _f == 4080:
				_shot("sewn")
				_step = 3
				_f = 3000
		6:
			if _f == 6012:
				_shot("won_early")
			if _f == 6240:
				_shot("won")
				print("won used=%d fewest=%d stars=%d quality=%.2f" % [st.used, st.fewest, st.stars(), _b.skill_quality()])
				print(_b.share_glyphs())
				_host.closed.emit()
				_step = 7
				_f = 7000
		7:
			if _f == 7005:
				_menu._open_at(load("res://ui/registry.gd").find("crossstitch"), _band)
				_host = _menu.get_child(_menu.get_child_count() - 1)
			if _f == 7200:
				_b = _host._puzzle
				_shot("reopen")
				print("reopen done=%s solved=%s shown=%s used=%d" % [_b.is_done(), _b.is_solved(), _b._shown, _b.state().used])
				_finish()
				return true
		20:
			if _b.out_of_hearts:
				_step = 21
				_f = 21000
			elif not _b.busy() and _f % 6 == 0:
				var p := _bad_pair()
				if p.x < 0:
					print("no bad pair left")
					_finish()
					return true
				_b.demo_swap(p.x, p.y)
		21:
			if _f == 21030:
				_shot("sagging")
			if _f == 21110:
				_shot("out_card")
				print("card=%s left=%d to_go=%d" % [is_instance_valid(_b._card), st.left(), st.to_go])
				_b.more_swaps()
			if _f == 21130:
				_shot("more")
				print("after more: left=%d out=%s" % [st.left(), _b.out_of_hearts])
				_b.show_sampler()
			if _f == 21140:
				_shot("showing")
			if _f == 21220:
				_shot("shown")
				print("shown done=%s solved=%s quality=%.1f" % [_b.is_done(), _b.is_solved(), _b.skill_quality()])
				_host.closed.emit()
				_step = 7
				_f = 7000
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
