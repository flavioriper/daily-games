extends SceneTree

## Domino Patio shots: `-- <dir> [d=<0..3>] [tut|card]` opens the board on
## that level and shoots it at rest, a tile held by a real touch over its
## ghost, half the answer laid (tags ticked), a refused tile, a broken bed,
## the bulb's reading (`hinted`), the win early and settled, the day reopened from its card and a tutorial
## page, with the draw calls of each frame. `tut` shoots the first tutorial
## page over the board; `card` the menu card beside Lattice's. Puts
## nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _f := 0
var _step := 0
var _diag: Control

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_band = int(a.substr(2))
		elif a != "tut" and a != "card":
			_dir = a
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_shot_patio.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if OS.get_cmdline_user_args().has("card"):
		_step = 20
		return
	if not OS.get_cmdline_user_args().has("tut"):
		progress.mark_tutorial_seen("patio")
	else:
		_step = 9
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/dp_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

func _touch(local: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = _b.get_global_transform_with_canvas() * local
	root.push_input(ev, true)

func _drag(local: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = _b.get_global_transform_with_canvas() * local
	root.push_input(ev, true)

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 20:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["patio", "lattice"]:
				var e: Dictionary = Reg.find(id)
				if e.is_empty():
					continue
				var card: Control = load(e.card).new(e, Color("e2825f"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "patio" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("patio"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay") and _step != 9:
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 12:
		return false
	if _step == 10:
		if _f == 5005:
			_menu._open_at(load("res://ui/registry.gd").find("patio"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 5100:
			_shot("reopen")
			_b = _host._puzzle
			print("reopen done=%s covered=%s" % [_b.is_done(), _b.state().covered()])
			_step = 7
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	match _step:
		0:
			if _f == 80:
				_shot("rest")
				_step = 1
		1:
			# a real touch lifts tile 0 and carries it over its answer
			var t := 0
			while st.answer[t].x < 0:
				t += 1
			_touch(_b._bay(t), true)
			_drag(_b._bay(t) + Vector2(0, -40))
			_drag(_b.answer_to_local(t) + Vector2(0, _b.HOLD_LIFT * _b._l("cell")))
			_step = 2
			_f = 1000
		2:
			if _f == 1020:
				_shot("held")
				_touch(_b.answer_to_local(0) + Vector2(0, _b.HOLD_LIFT * _b._l("cell")), false)
				_step = 3
		3:
			# half the answer laid
			if _f == 1040:
				var n := 0
				for t in st.tiles.size():
					if st.answer[t].x >= 0 and not st.right(t) and n < st.laid_count() / 2:
						_b.demo_lay(t)
						n += 1
			if _f == 1080:
				_shot("half")
				# a tile turned where it cannot turn is refused
				for t in st.tiles.size():
					if st.at[t] >= 0:
						_b._refuse(t)
						break
				_f = 1100
				_step = 4
		4:
			if _f == 1106:
				_shot("refuse")
				# any laying that breaks a bed
				var done := false
				for t in st.tiles.size():
					if done or st.at[t] >= 0:
						continue
					for a in st.bed_of.size():
						if done:
							break
						for d in 4:
							if st.fits(t, a, d):
								st.remember()
								st.place(t, a, d)
								var broke := false
								for b in st.beds.size():
									broke = broke or st.bed(b) == st.Bed.BROKEN
								if broke:
									_b._changed("set")
									done = true
									break
								st.undo()
				_f = 1200
				_step = 5
		5:
			if _f == 1210:
				_shot("broken")
				# the bulb's first press: a reading, rimmed and said
				_b.undo()
				_b.hint()
			if _f == 1226:
				_shot("hinted")
				st.restart()
				_b._reading = {}
				_b._judge_beds()
			if _f == 1240:
				for t in st.tiles.size():
					if st.answer[t].x >= 0:
						_b.demo_lay(t)
				_b.check_solved()
				if _b.is_done():
					_b._solved_now()
				_step = 6
				_f = 3000
		6:
			if _f == 3015:
				_shot("won_early")
			if _f == 3240:
				_shot("won")
				_host.closed.emit()
				_step = 10
				_f = 5000
		7:
			var pages: Array = _b.tutorial_pages()
			_diag = pages[0].diagram
			var holder := ColorRect.new()
			holder.color = Color.WHITE
			holder.size = Vector2(620, 520)
			holder.position = Vector2(95, 300)
			root.add_child(holder)
			_diag.size = holder.size
			holder.add_child(_diag)
			_step = 8
			_f = 4000
		8:
			if _f == 4130:
				_shot("tutorial")
				return true
		9:
			if _f == 150:
				_shot("tut_page1")
			if _f == 330:
				_shot("tut_page1_late")
				return true
	return false
