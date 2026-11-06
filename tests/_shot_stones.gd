extends SceneTree

## Stepping Stones shots: `-- <dir> [d=<0..3>] [osk=<px>] [tut=<page>] [card]`
## opens the board on that level and shoots it at rest, a line half typed,
## a stone laid, a refusal, the bulb's read, the bulb's stone, a long way
## folded, the crossing mid-wave, the win settled and the day reopened from
## its card, with the draw calls of each frame. `osk=<px>` lays the board
## out above a stand-in phone keyboard that tall. `tut` shoots a tutorial
## page played a while; `card` the menu card beside Padlock's. Puts nothing
## in the player's save.
##
## `theme` (the daily theme, 2026-11-06): the board deals from the scratch
## fixture pool (theme_pool_override, set before the board is opened, as
## Backend is not started here), shots prefixed `theme_`; `theme=<word>`
## puts that one word in the pool instead (`theme=moss` on Easy: a route
## stone, shot as `theme_stone` once laid). `lang=pt` plays in Portuguese.

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
var _theme := ""
var _lang := ""
var _pre := ""
var _stone_at := 0
var _toasted := 0
const FIXTURE := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/34d2447a-148c-4075-8921-873314a4eae3/scratchpad/theme_pool_fixture.json"

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
		elif a == "theme" or a.begins_with("theme="):
			_theme = a.substr(6) if a.begins_with("theme=") else "*"
			_pre = "theme_"
		elif a.begins_with("lang="):
			_lang = a.substr(5)
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
	root.get_texture().get_image().save_png("%s/ss_%s%s.png" % [_dir, _pre, name])
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
	if _f == 4 and _lang != "":
		# the content and the pool read Locale's language; nothing is saved
		Locale._current = _lang
		TranslationServer.set_locale(_lang)
	if _f == 5 and _theme != "":
		_set_pool()
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
			print("reopen done=%s stones=%d theme=%s" % [_b.is_done(), _b.state().stones(), _b._theme])
			return true
		return false
	if _b == null:
		_b = _host._puzzle
	var st = _b.state()
	if _osk >= 0.0 and _b.osk_override != _osk:
		_b.osk_override = _osk
		return false
	if _pre != "" and _b._say == "SS_SAY_THEME" and _toasted == 0:
		_toasted = _f + 12
	if _toasted > 0 and _f == _toasted:
		_shot("toast")
	while not _queue.is_empty() and st.used(String(_queue[0])):
		_queue.pop_front()
	if not _queue.is_empty() and _b._typed == "":
		_type(String(_queue.pop_front()))
	match _step:
		0:
			print("day %s > %s par %d route %s given %s" % [st.from, st.to, st.par, st.route, st.given])
			print("daily_key=%d bank_step=%d theme=%s" % [_b.daily_key, _b.bank_step, _b._theme])
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
			if _pre != "" and _stone_at == 0 and _b._theme_in_way() and String(_b._theme.at) == "way":
				_stone_at = _f + 22
			if _stone_at > 0 and _f == _stone_at:
				_shot("stone")
			if _b.is_done() and _step == 3:
				_step = 4
				_f = 4000
		4:
			if _pre != "" and _stone_at >= 0 and _b._won_at > -INF and _b._t >= _b._won_at + _b.THEME_AT + 0.12:
				_stone_at = -1
				_shot("reach")
			if _f == 4008:
				_shot("crossing")
			if _f == 4040:
				_shot("crossed")
			if _f == 4240:
				_shot("won")
				print("win: ", _b.flat_win().subtitle)
				print("day_dict: ", _b.day_dict())
				print("win_delay: ", _b.win_delay())
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

## The fixture's words in the playing language, folded, or the one word
## named: the pool the board deals from.
func _set_pool() -> void:
	var pool: Array = []
	if _theme == "*":
		var doc = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
		var lang: String = Locale.current()
		for w in (doc.get(lang, []) if doc is Dictionary else []):
			var f := Locale.fold(String(w))
			if not pool.has(f):
				pool.append(f)
	else:
		pool = [Locale.fold(_theme)]
	load("res://puzzles/stones2d.gd").theme_pool_override = pool
	print("pool %s: %s" % [Locale.current(), pool.slice(0, 8)])
