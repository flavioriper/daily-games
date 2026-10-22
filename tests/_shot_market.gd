extends SceneTree

## Market Sums shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## board on that level and shoots the stall at rest, a crate and a sign
## picked, a refused share, a crate mid-slide, an Undo, the bulb, the win
## settled and the day reopened from its card, with the draw calls of each
## frame. `tut` shoots a tutorial page played a while; `card` the menu card
## beside Teacups'. Puts nothing in the player's save.

const Gen = preload("res://puzzles/market_gen.gd")

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 0
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
	progress.path = "user://progress_shot_market.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("market")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/mk_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

## The answer's next step's places on the stall as it is.
func _places(st, s: Array) -> Array:
	var from: int = st.slots.find(int(s[0]))
	for i in 6:
		if i != from and st.slots[i] == int(s[1]):
			return [from, i, int(s[2])]
	return []

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["market", "teacups"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("4c9a94"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "market" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("market"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("market"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s steps=%d slots=%s" % [_b.is_done(), _b.state().steps, str(_b.state().slots)])
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	match _step:
		0:
			_shot("rest")
			print("day %s -> %d par %d answer %s" % [str(st.numbers), st.target, st.par, str(st.answer)])
			var p := _places(st, st.answer[0])
			_b.demo_crate(p[0])
			_b.demo_sign(p[2])
			_step = 1
			_f = 1000
		1:
			if _f == 1020:
				_shot("picked")
				# a refused share, if the stall has one
				_b._op = -1
				_b._pick = -1
				for i in range(5, -1, -1):
					for j in 6:
						if i != j and st.would(i, j, Gen.Op.DIV) == Gen.UNEVEN and _b.picked() < 0:
							_b.demo_crate(i)
							_b.demo_sign(Gen.Op.DIV)
							_b.demo_crate(j)
				_step = 2
				_f = 2000
		2:
			if _f == 2010:
				_shot("refused")
				_b._pick = -1
				var p := _places(st, st.answer[0])
				_b.demo_crate(p[0])
				_b.demo_sign(p[2])
				_b.demo_crate(p[1])
			if _f == 2018:
				_shot("sliding")
			if _f == 2050:
				_shot("made")
				if _band < 3:
					_b.undo()
				_step = 3
				_f = 3000
		3:
			if _f == 3008:
				_shot("undoing")
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
			elif not _b.sliding() and _f % 10 == 0:
				var h: Array = st.hint_step()
				if h.is_empty():
					return false
				if _b.picked() != h[0]:
					_b._pick = -1
					_b.demo_crate(h[0])
				_b.demo_sign(h[2])
				_b.demo_crate(h[1])
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
