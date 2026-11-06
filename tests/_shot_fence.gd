extends SceneTree

## Garden Fence shots: `-- <dir> [d=<0..3>] [tut[=<page>]] [card]` opens the
## fence on that level and shoots it at rest, a word strung by a real
## pointer (its twine running out), tied (posts hopping, daisies opening),
## the next word dragged across the posts, the bulb's reading and its word,
## the win settled and the day reopened from its card, with the draw calls
## of each frame. `tut` shoots a tutorial page played a while; `card` the
## menu card beside Stepping Stones'. Puts nothing in the player's save.
##
## `theme` (2026-11-06): the day's theme pool is the fixture at FIXTURE
## (keys en/pt/es, folded here), handed to the board's seam before it is
## built, so the fence is dealt as a themed daily would be. It prints the
## themed fences of every band and how long the pick takes, strings the
## theme word first (`theme_tease`, `theme_strung`, `theme_tied`,
## `theme_found`), then the bulb finishes and the win and the reopened day
## are shot as above. `theme=miss` never strings it (the win's softer line,
## unless the bulb strings it); `theme=drop` strings it and takes the pool
## away before the reopen. `lang=<pt|es>` plays in that language.

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
var _theme := ""
var _lang := ""
const FIXTURE := "res://tests/fixtures/theme_pool.json"
const Board = preload("res://puzzles/fence2d.gd")
const State = preload("res://puzzles/fence_state.gd")
const ThemedPictures = preload("res://core/themed_pictures.gd")

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
		elif a == "theme" or a.begins_with("theme="):
			_theme = "hit" if a == "theme" else a.substr(6)
		elif a.begins_with("lang="):
			_lang = a.substr(5)
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
	Board.theme_pool_seam = null
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
	if _f == 4:
		if _lang != "":
			# the banks, the words and the pool read Locale's language;
			# nothing is saved
			Locale._current = _lang
			TranslationServer.set_locale(_lang)
		if _theme != "":
			_seed_pool()
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
		if _f == 7004 and _theme == "drop":
			# the day's pool gone by the reopen: the played fence comes back
			# from the record
			Board.theme_pool_seam = null
		if _f == 7005:
			_menu._open_at(load("res://ui/registry.gd").find("fence"), _band)
			_host = _menu.get_child(_menu.get_child_count() - 1)
		if _f == 7200:
			_b = _host._puzzle
			_shot("reopen")
			print("reopen done=%s solved=%s tied=%s themed=%s found=%s" % [_b.is_done(), _b.is_solved(), _b.state().tied, _b.themed(), _b.theme_found()])
			_finish()
			return true
		return false
	if _b == null:
		_b = _host._puzzle
		_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st = _b.state()
	if _theme != "" and _step == 0:
		print("themed=%s word=%s daily_key=%d bank_step=%d day=%s" % [_b.themed(), _b.theme_word, _b.daily_key, _b.bank_step, _b.day_dict()])
		_step = 20 if _theme in ["hit", "drop"] and _b.themed() else 4
		_f = 2000 if _step == 20 else 4000
		_shot("theme_rest")
		return false
	match _step:
		20:
			var w: String = _b.theme_word
			if _f == 2060:
				_shot("theme_tease")
				for k in w.length() - 1:
					_tap(st.post_of(w[k]))
			if _f == 2062:
				_tap(st.post_of(w.right(1)))
			if _f == 2090:
				_shot("theme_strung")
				_tap(st.post_of(w.right(1)))
			if _f == 2098:
				_shot("theme_tied")
			if _f == 2112:
				_shot("theme_sparkle")
			if _f == 2150:
				_shot("theme_found")
				print("theme tied %s found=%s tied=%s stars=%d" % [w, _b.theme_found(), st.tied, st.stars()])
				_step = 4
				_f = 4000
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
				print("win line: %s | delay %.2f | found=%s" % [_b.flat_win().subtitle, _b.win_delay(), _b.theme_found()])
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
				print("reopen done=%s solved=%s tied=%s themed=%s found=%s" % [_b.is_done(), _b.is_solved(), _b.state().tied, _b.themed(), _b.theme_found()])
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

## The fixture's words for the player's language, folded and kept as
## ThemedPictures.theme_pool keeps them, handed to the board's seam; then
## every band's bank walked as a themed deal would walk it.
func _seed_pool() -> void:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var lang := Locale.current()
	var pool: Array = []
	for w in doc.get(lang, []):
		var f := Locale.fold(String(w).strip_edges())
		if f.length() < 3 or f.length() > 16 or pool.has(f):
			continue
		var ok := true
		for ch in f:
			if not Locale.alphabet().contains(ch):
				ok = false
				break
		if ok:
			pool.append(f)
	Board.theme_pool_seam = pool
	var t0 := Time.get_ticks_usec()
	var accepted: Array = State.theme_accepted(pool)
	var t_acc := Time.get_ticks_usec() - t0
	print("theme pool %s: %d words, %d the garden takes (%d us): %s" % [lang, pool.size(), accepted.size(), t_acc, accepted])
	for bank in State.BANKS:
		var boards: Array = InsaneBank.boards(bank)
		var t1 := Time.get_ticks_usec()
		var bits: PackedInt64Array = State.theme_bits(accepted)
		var hit := ThemedPictures.bank_pick(boards, accepted, 20261106, func(e: Dictionary) -> Array: return State.theme_words(e, accepted, bits))
		var t_pick := Time.get_ticks_usec() - t1
		var n := 0
		for e in boards:
			if not State.theme_words(e, accepted).is_empty():
				n += 1
		print("  %s: %d of %d fences themed; pick %s in %d us" % [bank, n, boards.size(), hit, t_pick])
