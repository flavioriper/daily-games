extends SceneTree

## Birdsong shots: `-- <dir> [d=<0..3>]` opens the board on that level and
## shoots the bird singing (a drum lit), the player's turn with a berry
## played back, a slip, a tutorial page, and the settled win, with the draw
## calls of each frame. Puts nothing in the player's save.

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
	progress.path = "user://progress_shot_birdsong.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if OS.get_cmdline_user_args().has("card"):
		_step = 20
		return
	if not OS.get_cmdline_user_args().has("tut"):
		progress.mark_tutorial_seen("birdsong")
	else:
		_step = 9
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png("%s/bs_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 20:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["birdsong", "drumbeat"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("6bb1d6"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "birdsong" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("birdsong"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay") and _step != 9:
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 12:
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	match _step:
		0:
			# the bird's song, a drum lit mid-note
			if _b.phase() == _b.Phase.LISTEN and _b._t - _b._sing_at > 0.1 and _b._t - _b._sing_at < 0.16 and _b._sing_at > 0.0:
				_shot("listen")
				_step = 1
		1:
			if _b.phase() == _b.Phase.PLAY:
				_b.demo_strike(st.tune[st.pos])
				_step = 2
				_f = 1000
		2:
			if _f == 1006:
				_shot("played")
				# play the round out, then slip on the next
				while _b.phase() == _b.Phase.PLAY and st.round_no() == 1:
					_b.demo_strike(st.tune[st.pos])
				_step = 3
		3:
			if _b.phase() == _b.Phase.PLAY:
				_b.demo_strike((st.tune[st.pos] + 1) % st.drums())
				_step = 4
				_f = 2000
		4:
			if _f == 2008:
				_shot("slip")
				_step = 5
		5:
			# the rest of the day played back
			if _b.is_done():
				_step = 6
				_f = 3000
			elif _b.phase() == _b.Phase.PLAY:
				_b.demo_strike(st.tune[st.pos])
			else:
				_b._process(0.05)
		6:
			if _f == 3015:
				_shot("won_early")
			if _f == 3240:
				_shot("won")
				_step = 7
		7:
			var pages: Array = _b.tutorial_pages()
			_diag = pages[1].diagram
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
			if _f == 4200:
				_shot("tutorial")
				return true
		9:
			if _f == 150:
				_shot("tut_page1")
			if _f == 400:
				_shot("tut_page1_late")
				return true
	return false
