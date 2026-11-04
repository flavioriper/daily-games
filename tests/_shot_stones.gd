extends SceneTree

## Stepping Stones shots: `-- <dir> [d=<0..3>] [osk=<px>] [tut=<page>] [card]`
## opens the board on that level and shoots it at rest, a line half typed,
## a stone laid, a refusal, the bulb's read, the bulb's stone, a long way
## folded, the crossing mid-wave, the win settled and the day reopened from
## its card, with the draw calls of each frame. `osk=<px>` lays the board
## out above a stand-in phone keyboard that tall. `tut` shoots a tutorial
## page played a while; `card` the menu card beside Padlock's. Puts nothing
## in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 1
var _f := 0
var _step := 0
var _diag: Control
var _osk := -1.0
var _queue: Array = []

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
		elif a.begins_with("osk="):
			_osk = float(a.substr(4))
		else:
			_dir = a
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_shot_stones.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("stones")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/ss_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

func _type(w: String) -> void:
	for c in w.to_upper():
		_b.type_letter(c)

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["stones", "padlock"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("6fa3c9"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "stones" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("stones"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("stones"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s stones=%d" % [_b.is_done(), _b.state().stones()])
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	if _osk >= 0.0 and _b.osk_override != _osk:
		_b.osk_override = _osk
		return false
	while not _queue.is_empty() and st.used(String(_queue[0])):
		_queue.pop_front()
	if not _queue.is_empty() and _b._typed == "":
		_type(String(_queue.pop_front()))
	match _step:
		0:
			print("day %s > %s par %d route %s given %s" % [st.from, st.to, st.par, st.route, st.given])
			_shot("rest")
			_type(String(st.route[0]).substr(0, st.n - 1))
			_step = 1
			_f = 1000
		1:
			if _f == 1004:
				_shot("typing")
				_b.type_letter(String(st.route[0])[st.n - 1].to_upper())
			if _f == 1010:
				_shot("laid_drop")
			if _f == 1040:
				_shot("laid")
				_type("q".repeat(st.n))
			if _f == 1046:
				_shot("refused")
				_b._clear_line()
				_b.hint()
			if _f == 1070:
				_shot("read")
				_b.hint()
			if _f == 1110:
				_shot("bulb_laid")
				# wander: lay stones off the way until the way folds
				_step = 2
				_f = 2000
		2:
			if st.crossed:
				_step = 4
				_f = 4000
			elif _f % 6 == 0 and _b._typed == "" and not st.crossed:
				var next := ""
				for y in st.neighbours(st.last()):
					if not st.used(y) and not st.step_ok(y, st.to) and (st.given == "" or not st.step_ok(y, st.given)):
						next = y
						break
				if next == "" or st.stones() >= 12:
					_shot("folded")
					_step = 3
					_f = 3000
				else:
					_type(next)
		3:
			if _f == 3002:
				_b.reset_board()
			if _f == 3030:
				_shot("cleared")
				_queue = st.route.duplicate()
			if _b.is_done() and _step == 3:
				_step = 4
				_f = 4000
		4:
			if _f == 4008:
				_shot("crossing")
			if _f == 4040:
				_shot("crossed")
			if _f == 4240:
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
