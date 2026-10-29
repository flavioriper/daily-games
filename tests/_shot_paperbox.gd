extends SceneTree

## Paper Box shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## board on that level and shoots the mat at rest, a wrong pick struck, the
## bulb's strike, the fold mid-way, the box turned, the box flying, the
## next round, the win settled and the day reopened from its card, with the
## draw calls of each frame. `tut` shoots a tutorial page played a while;
## `card` the menu card beside Hosepipes'; `lang=<pt|es>` the words. Puts nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 1
var _f := 0
var _step := 0
var _diag: Control
var _ran := false
var _lang := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_band = int(a.substr(2))
		elif a.begins_with("tut"):
			_step = 50
			if a.begins_with("tut="):
				_page = int(a.substr(4))
		elif a.begins_with("lang="):
			_lang = a.substr(5)
		elif a == "card":
			_step = 60
		else:
			_dir = a
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_shot_paperbox.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("paperbox")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/pb_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

## The board stepped `s` seconds on its own clock.
func _run(s: float) -> void:
	var n := int(s / 0.05)
	for i in n:
		_b._process(0.05)

func _wrong(st) -> int:
	for o in st.struck.size():
		if o != int(st.now().answer) and not st.struck[o]:
			return o
	return -1

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["paperbox", "hoses"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("6fa3c9"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "paperbox" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		if _lang != "":
			TranslationServer.set_locale(_lang)
		_menu._open_at(load("res://ui/registry.gd").find("paperbox"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("paperbox"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s wrongs=%d" % [_b.is_done(), _b.state().wrongs])
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	match _step:
		0:
			_shot("rest")
			_b.demo_tap(_wrong(st))
			_step = 1
			_f = 1000
		1:
			if _f == 1030:
				_shot("wrong")
				_b.hint()
				_step = 2
				_f = 2000
		2:
			if _f == 2030:
				_shot("hinted")
				_b.hint()
			if _f == 2050:
				_shot("hinted2")
				_b.demo_tap(int(st.now().answer))
				_step = 3
				_f = 3000
		3:
			# each beat of the fold: the clock stepped on one frame, shot on the next
			var beats := [[0.15, "picked"], [0.45, "tilted"], [0.45, "folding"], [0.5, "folded"], [0.45, "turned"], [0.55, "flying"], [0.6, "next"]]
			var i := (_f - 3001) / 2
			if i >= beats.size():
				_step = 5
				_f = 5000
			elif (_f - 3001) % 2 == 0:
				_run(float(beats[i][0]))
			else:
				_shot(String(beats[i][1]))
		5:
			if not _ran and _b._rw.has_sticker("run"):
				_ran = true
				_run(0.25)
				_shot("run")
			if _b.is_done():
				_step = 6
				_f = 6000
			elif _b.phase() == _b.Phase.PLAY:
				_b.demo_tap(int(st.now().answer))
			else:
				_run(0.5)
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
