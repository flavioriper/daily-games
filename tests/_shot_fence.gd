extends SceneTree

## Garden Fence shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## fence on that level and shoots it at rest, a word strung by a real
## pointer (its twine running out), tied (posts hopping, daisies opening),
## the next word dragged across the posts, the bulb's reading and its word,
## the win settled and the day reopened from its card, with the draw calls
## of each frame. `tut` shoots a tutorial page played a while; `card` the
## menu card beside Stepping Stones'. Puts nothing in the player's save.

var _menu: Node
var _host: Node
var _b: Node
var _dir := "/tmp"
var _band := 1
var _page := 0
var _f := 0
var _step := 0
var _diag: Control
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
	progress.path = "user://progress_shot_fence.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	if _step == 60:
		return
	progress.mark_tutorial_seen("fence")
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
	root.get_texture().get_image().save_png("%s/fn_%s.png" % [_dir, name])
	print("shot %s draw_calls=%d" % [name, calls])

## A press, a drag or a release on the board, in its own coordinates,
## through its _gui_input (the window's pointer stays out of it).
func _touch(local: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = local
	_b._gui_input(e)

func _move(local: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = local
	_b._gui_input(e)

func _tap(p: int) -> void:
	var at: Vector2 = _b.post_to_local(p)
	_touch(at, true)
	_touch(at, false)

func _process(_delta: float) -> bool:
	_f += 1
	if _step == 60:
		if _f == 3:
			var Reg = load("res://ui/registry.gd")
			for id in ["fence", "stones"]:
				var card: Control = load(Reg.find(id).card).new(Reg.find(id), Color("e2825f"))
				card.size = Vector2(730, 246)
				card.position = Vector2(40, 200 if id == "fence" else 500)
				root.add_child(card)
		if _f == 20:
			_shot("card")
			quit()
			return true
		return false
	if _f == 5:
		_menu._open_at(load("res://ui/registry.gd").find("fence"), _band)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
		return false
	if _f < 60:
		return false
	if _step == 7:
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("fence"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s solved=%s tied=%s" % [_b.is_done(), _b.is_solved(), _b.state().tied])
			_finish()
			return true
		return false
	if _b == null:
		_b = _host._puzzle
		_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st = _b.state()
	match _step:
		0:
			_shot("rest")
			print("posts %s sides %d gate %d par %d route %s words %d" % ["".join(st.posts), st.sides, st.gate, st.par, st.route, st.word_count()])
			var w: String = st.route[0]
			for k in w.length() - 1:
				_tap(st.post_of(w[k]))
			_step = 1
			_f = 1000
		1:
			var w: String = st.route[0]
			if _f == 1002:
				_tap(st.post_of(w.right(1)))
			if _f == 1004:
				_shot("stringing")
			if _f == 1030:
				_shot("strung")
				_tap(st.post_of(w.right(1)))
			if _f == 1036:
				_shot("tied")
			if _f == 1080:
				_shot("tied_settled")
				print("tied %s used %d left %d stars %d" % [w, st.used(), st.posts_left(), st.stars()])
				# the next word dragged post to post, held before its end
				var v: String = st.route[1] if st.route.size() > 1 else ""
				if v != "":
					var at: Vector2 = _b.post_to_local(st.post_of(v[0]))
					_touch(at, true)
					for k in range(1, v.length() - 1):
						var to: Vector2 = _b.post_to_local(st.post_of(v[k]))
						for s in 4:
							_move(at.lerp(to, (s + 1) / 4.0))
						at = to
					_move(at + Vector2(60, 40))
			if _f == 1090:
				_shot("dragging")
				_touch(_b.post_to_local(st.trail[-1]), false)
				print("dragged trail %s" % st.trail_word())
			if _f == 1100:
				_b.undo()
				_b.undo()
				_step = 3
				_f = 3000
		3:
			if _f == 3001:
				# back to the tied first word, then the bulb
				while st.trail.size() > st.base():
					st.back()
				_b.hint()
			if _f == 3020:
				_shot("reading")
				_b.hint()
			if _f == 3110:
				_shot("hinted")
				print("after bulb: tied %s helped %d stars %d" % [st.tied, st.helped, st.stars()])
				_step = 4
				_f = 4000
		4:
			if _b.is_done():
				_step = 6
				_f = 6000
			elif not _b.busy() and _f % 20 == 0:
				_b.hint()
				_b.hint()
		6:
			if _f == 6012:
				_shot("won_early")
			if _f == 6040:
				_shot("winning")
			if _f == 6260:
				_shot("won")
				print("won tied=%s helped=%d stars=%d quality=%.2f" % [st.tied, st.helped, st.stars(), _b.skill_quality()])
				print(_b.share_glyphs())
				_host.closed.emit()
				_step = 7
				_f = 7000
		7:
			if _f == 7005:
				_menu._open_at(load("res://ui/registry.gd").find("fence"), _band)
				_host = _menu.get_child(_menu.get_child_count() - 1)
			if _f == 7200:
				_b = _host._puzzle
				_shot("reopen")
				print("reopen done=%s solved=%s tied=%s" % [_b.is_done(), _b.is_solved(), _b.state().tied])
				_finish()
				return true
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
