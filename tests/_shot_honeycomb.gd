extends SceneTree

## Honeycomb shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## board on that level and shoots the comb at rest, a word half spelt, a
## refused entry, a word flying into the jar, a shuffle mid-slide, the bulb,
## a busy jar, the queen's flight (Insane), the win settled and the day
## reopened from its card, with the draw calls of each frame. `tut` shoots a
## tutorial page played a while; `card` the menu card beside Market Sums'.
## Puts nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 0
var _f := 0
var _step := 0
var _diag: Control
var _queue: Array = []
## A tutorial page's first shot, in frames after it starts (`at=`).
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
	progress.path = "user://progress_shot_honeycomb.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("honeycomb")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/hc_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

func _type(word: String) -> void:
	for ch in word:
		_b.demo_tap(_b.cell_of(ch))

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["honeycomb", "market"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("e2825f"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "honeycomb" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("honeycomb"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("honeycomb"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s words=%d honey=%d" % [_b.is_done(), _b.state().found.size(), _b.state().honey])
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	match _step:
		0:
			_shot("rest")
			print("hive %s queen %s: %d words, honey %d, line %d" % [st.letters, st.queen, st.answers.size(), st.total, st.goal])
			var w: String = st.hint_word()
			_type(w.left(3))
			_step = 1
			_f = 1000
		1:
			if _f == 1012:
				_shot("spelling")
				_b.demo_key(0)
				_b.demo_key(0)
				_b.demo_key(0)
				var wrong := ""
				for ch in st.ring:
					if wrong.length() < 4:
						wrong += ch
				_type(wrong)
				_b.demo_key(2)
				_step = 2
				_f = 2000
		2:
			if _f == 2010:
				_shot("refused")
			if _f == 2060:
				var w: String = st.hint_word()
				st.hinted.append(w)
				_type(w)
				_b.demo_key(2)
			if _f == 2068:
				_shot("taken")
			if _f == 2110:
				_b.demo_key(1)
			if _f == 2116:
				_shot("shuffling")
				_step = 3
				_f = 3000
		3:
			if _f == 3040:
				_b.hint()
			if _f == 3080:
				_shot("hinted")
				_b._st.entry = ""
				_b._typed_at.clear()
				_b._hint_word = ""
				_step = 5
				_f = 5000
		5:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif not _b.busy() and _f % 8 == 0:
				var w: String = st.hint_word()
				if w == "":
					return false
				st.hinted.append(w)
				_type(w)
				_b.demo_key(2)
				if st.flights == 1 and not _queue.has("flight"):
					_queue.append("flight")
					_step = 4
					_f = 4000
				elif st.rank() >= 1 and not _queue.has("rank"):
					_queue.append("rank")
					_step = 8
					_f = 8500
				elif st.found.size() == 6 and not _queue.has("busy"):
					_queue.append("busy")
					_shot("busy")
		4:
			if _f == 4050:
				_shot("flying")
			if _f == 4078:
				_shot("trading")
			if _f == 4140:
				_shot("flown")
				_step = 5
				_f = 5000
		6:
			if _f == 6012:
				_shot("won_early")
			if _f == 6240:
				_shot("won")
				_host.closed.emit()
				_step = 7
				_f = 7000
		8:
			# the rank lit, then the first word sent again lights its chip
			if _f == 8528:
				_shot("ranked")
				_type(st.found[0])
				_b.demo_key(2)
			if _f == 8540:
				_shot("again")
				_step = 5
				_f = 5000
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
			if _f == 8000 + _at:
				_shot("tut%d_a" % _page)
			if _f == 8000 + _at + 170:
				_shot("tut%d_b" % _page)
				return true
	return false
