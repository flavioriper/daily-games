extends SceneTree

## The performance checkup's probe (2026-10-01): opens one board at one
## difficulty, idles, then plays right moves through the board's own input
## path, and prints where each window's frame time goes -- the whole frame,
## the script/process share and the renderer's CPU share -- with the peak
## draw calls and the node count. Vsync is off, so a frame is its real cost.
##
##     godot --path . --resolution 810x1440 --always-on-top \
##         --rendering-driver opengl3_angle \
##         --script res://tests/_probe_perf.gd -- <id> d=<0..3>
##
## A single ms reading off this Mac is noise; run it twice and quote the
## second, and compare windows within one run (idle against play) rather
## than across runs. A board with no `_play_<id>` here only idles.

const IDLE_FROM := 1.5
const IDLE_TO := 6.5
const PLAY_EVERY := 0.25
const PLAY_TO := 13.0  # (a `howto` run with five pages needs ~10 s)

const Haptics = preload("res://core/haptics.gd")

var _buzz_seen := 0
## Seconds a board's `_buzz_<id>` adds to the run after it, where the moves
## wait on the board (Code Break holds a scored row a second or two).
var _buzz_more := 0.0
var _menu: Node
var _host: Node
var _puzzle: Node
var _entry: Dictionary
var _id := "binairo"
var _level := 3
var _t := -0.3
var _opened := false
var _windows := {"idle": [], "play": []}
var _draws := {"idle": 0, "play": 0}
var _draw_sum := {"idle": 0.0, "play": 0.0}
var _next_move := IDLE_TO
var _moves: Array = []
var _vp: RID
## `x=<name>` switches one thing off at IDLE_FROM to see what it costs:
## faces (stop every face's idle), board (hide the board), page (hide all
## but the board's own subtree), host (hide the whole host).
var _exp := ""
## `fill` plays every right move but the last two before the idle window.
var _fill := false
## How many moves `fill` leaves: two, or two whole gestures on a board whose
## moves are a gesture's events (Shikaku's drags are five).
var _keep := 2
## `howto` leaves the first-play tutorial up; `shot=<s>` saves the screen to
## /tmp/probe_<id>.png that many seconds after opening.
var _howto := false
var _shot_at := INF
## `gap=<s>`: with the tutorial up, how long each page plays before its shot.
var _gap := 1.8
## `to=<s>`: when the run ends (PLAY_TO by default; a long `gap` needs more).
var _play_to := PLAY_TO
var _page := 0
var _exp_done := false
## `rm`: reduce motion, set as the board opens (the settings load over it
## at launch).
var _rm := false
## `lang=<code>`: the language the board opens in (the Mac's own otherwise),
## to read a tutorial's pages in each.
var _lang := ""
## `song=<id>`: Drumbeat's song (the day's otherwise): parade, festival, gallop.
var _song := ""

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "howto":
			_howto = true
		elif a == "rm":
			_rm = true
		elif a.begins_with("song="):
			_song = a.substr(5)
		elif a.begins_with("lang="):
			_lang = a.substr(5)
		elif a.begins_with("shot="):
			_shot_at = float(a.substr(5))
		elif a.begins_with("gap="):
			_gap = float(a.substr(4))
		elif a.begins_with("to="):
			_play_to = float(a.substr(3))
		elif a == "fill":
			_fill = true
		elif a.begins_with("x="):
			_exp = a.substr(2)
		elif a.begins_with("d="):
			_level = int(a.substr(2))
		else:
			_id = a
	var progress_path := "user://_probe_perf_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
	var progress = load("res://core/progress.gd")
	progress.path = progress_path
	for e in load("res://ui/registry.gd").PUZZLES:
		if not _howto:
			progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")
	_vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)

var _log_until := -1.0

func _process(delta: float) -> bool:
	_t += delta
	if _t < _log_until:
		print("  frame %.1f ms process %.1f render-cpu %.1f" % [delta * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(_vp)])
	if not _opened:
		if _t >= 0.0:
			_open()
		return false
	if _fill and _t >= 0.3 and _t < IDLE_FROM - 0.4:
		# Every right move but the last two, one a frame, so the idle window
		# measures a nearly full board.
		for k in 4:
			if _moves.size() > _keep:
				_step()
		# A board whose moves animate (Code Break's Check) fills slower than
		# the window allows: hold the clock until it is full.
		if _moves.size() > _keep and not _puzzle.is_done():
			_t = minf(_t, IDLE_FROM - 0.5)
	if _exp != "" and not _exp_done and _t >= IDLE_FROM - 0.3:
		_exp_done = true
		_experiment()
	if _t >= _shot_at:
		_shot_at = INF
		var name := "/tmp/probe_%s%s.png" % [_id, "_p%d" % _page if _howto else ""]
		root.get_viewport().get_texture().get_image().save_png(name)
		print("shot ", name)
		var c0 = _host.get_node_or_null("HowToPlay")
		if c0 != null:
			print("  diagram size ", c0._diagram.size, " slot ", c0._diagram_slot.size, " caption ", c0._diagram._caption.position, " ", c0._diagram._caption.size,
				" body lines ", c0._body.get_line_count(), " \"", c0._diagram._caption.text, "\"")
		# With the tutorial up, every page in turn, `gap` apart.
		var card = _host.get_node_or_null("HowToPlay")
		if _howto and card != null and _page < card._pages.size() - 1:
			_page += 1
			card._turn(1)
			_shot_at = _t + _gap
	var window := ""
	if _t >= IDLE_FROM and _t < IDLE_TO:
		window = "idle"
	elif _t >= IDLE_TO and _t < _play_to:
		window = "play"
	if window != "":
		_windows[window].append(Vector3(delta * 1000.0,
			RenderingServer.viewport_get_measured_render_time_gpu(_vp),
			RenderingServer.viewport_get_measured_render_time_cpu(_vp)))
		if delta * 1000.0 > 25.0:
			print("  spike %.1f ms at t=%.2f (%s) moves=%d done=%s | process %.1f render-cpu %.1f draws %d" % [delta * 1000.0, _t, window, _puzzle.get("moves") if _puzzle.get("moves") != null else -1, _puzzle.is_done(),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(_vp), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
		_draws[window] = maxi(_draws[window], int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_draw_sum[window] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		if window == "play" and _t >= _next_move:
			_next_move += PLAY_EVERY
			if _exp == "log":
				_log_until = _t + 0.12
				print("  step at %.2f" % _t)
			_step()
	if _id == "drumbeat" and not _howto and (_t >= IDLE_TO or _exp == "db_hud"):
		_db_bot()
	if _exp == "db_spike":
		var nl: int = _puzzle._looks.size()
		if delta > 0.02 and _t > 2.0:
			print("  SPIKE %.1f ms t=%.2f song %.2f looks +%d (%d) bits %d stickers %s fw %d warm %d draws %d" % [delta * 1000.0, _t, _puzzle.song_now(), nl - _db_looks, nl, _puzzle._rw.bits.size(), _puzzle._rw.stickers.map(func(st): return "%s@%.2f" % [st.text, st.t]), _puzzle._fireworks.size(), _puzzle._warm.size(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
		_db_looks = nl
	if _exp == "db_count" and _t >= _db_next:
		# Drumbeat: where the song is, every two seconds, with the frame's
		# script time and draw calls.
		_db_next = _t + 2.0
		print("  db t=%.1f %s song %.1f gogo=%s combo=%d bits=%d stickers=%d fireworks=%d draws=%d process %.2f ms looks=%d" % [_t, _puzzle._phase,
			_puzzle.song_now(), _puzzle._st.in_gogo, _puzzle._st.combo, _puzzle._rw.bits.size(), _puzzle._rw.stickers.size(), _puzzle._fireworks.size(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, _puzzle._looks.size()])
	if _exp == "tr_win":
		# where a frame goes: the nodes' process (to pre-draw), the draw
		# (to post-draw), and the rest (to the next frame's start)
		var now_us := Time.get_ticks_usec()
		if not _tr_hooked:
			_tr_hooked = true
			RenderingServer.frame_pre_draw.connect(func() -> void: _tr_pre = Time.get_ticks_usec())
			RenderingServer.frame_post_draw.connect(func() -> void: _tr_post = Time.get_ticks_usec())
		elif _t < _log_until or delta > 0.025:
			var pf: Dictionary = _puzzle.perf if _opened else {}
			print("  parts: process %.1f draw %.1f rest %.1f ms (done=%s) board: process %.2f bridge %.2f front %.2f" % [(_tr_pre - _tr_start) / 1000.0, (_tr_post - _tr_pre) / 1000.0, (now_us - _tr_post) / 1000.0, _puzzle.is_done() if _opened else false,
				int(pf.get("process_max", 0)) / 1000.0, int(pf.get("bridge_max", 0)) / 1000.0, int(pf.get("front_max", 0)) / 1000.0], " ", pf)
			if _opened:
				_puzzle.perf_on = true
				_puzzle.perf = {}
		_tr_start = now_us
	if _exp == "tr_win" and _opened:
		# Trestle: every frame from just before the cart is over until the
		# win has played a moment, to see what the solve's frames cost.
		if not _tr_logged and _puzzle._testing and _puzzle.sim.cart == 3:
			_tr_logged = true
			_log_until = _t + 2.6
	if _exp == "tr_count" and _t >= _db_next:
		# Trestle: every 1.5 s, what the board's script cost a frame (the
		# process with the sim's steps in it, a bridge build, the front
		# layer), with the frame's draw calls and the meshes' vertices.
		_db_next = _t + 1.5
		_puzzle.perf_on = true
		var pf: Dictionary = _puzzle.perf
		var n := maxi(1, int(pf.get("frames", 0)))
		var line := "  tr t=%.1f testing=%s members=%d frames=%d steps=%d draws=%d |" % [_t, _puzzle._testing, _puzzle.state.design.size(), n,
			int(pf.get("steps", 0)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
		for k in ["process", "bridge", "front"]:
			line += " %s %.2f" % [k, float(pf.get(k, 0)) / n / 1000.0]
		for m in [["bridge", _puzzle._frame], ["front", _puzzle._front_mesh]]:
			if m[1] != null:
				line += " %s verts %d" % [m[0], (m[1].surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector2Array).size()]
		print(line)
		_puzzle.perf = {}
	if _t >= _play_to:
		_report()
		quit()
		return true
	return false

func _open() -> void:
	_opened = true
	Haptics.trace = []
	if _rm:
		load("res://core/motion.gd").reduce = true
	if _lang != "":
		TranslationServer.set_locale(_lang)
	_t = 0.0
	for e in load("res://ui/registry.gd").PUZZLES:
		if e.id == _id:
			_entry = e
	if bool(_entry.get("pick_difficulty", false)):
		_menu._open_at(_entry, _level)
	else:
		_menu._open(_entry)
	_host = _menu.get_child(_menu.get_child_count() - 1)
	_puzzle = _host._puzzle
	if not _howto and _host.has_node("HowToPlay"):
		_host.get_node("HowToPlay").free()
		_host._hold_clock(false)
	if _song != "" and _id == "drumbeat":
		# Drumbeat: another of its songs than the day's
		for sg: Dictionary in _puzzle._songs:
			if String(sg.id) == _song:
				_puzzle._song = sg
				_puzzle._fresh()
				_puzzle._layout()
	if has_method("_moves_" + _id):
		_moves = call("_moves_" + _id)

func _experiment() -> void:
	match _exp:
		"faces":
			for f in _all(_host, func(n): return n.has_method("set_idle")):
				f.set_idle(false)
		"board":
			_puzzle.visible = false
		"host":
			_host.visible = false
		"buzz":
			# The haptics checkup (docs/agents/haptics.md): each thing the
			# player can do, and the kind that landed for it.
			_buzzed("open")
			_next_move = INF
			_play_to = INF  # (a long routine outlasts PLAY_TO)
			await call("_buzz_" + _id)
			_next_move = _t + 0.5
			_play_to = _t + 0.5 + _moves.size() * PLAY_EVERY + 5.0 + _buzz_more
		"undo":
			var m: Dictionary = _moves[0]
			_click(m.at.call())
			var cell: Vector2i = _puzzle._cell_at(m.at.call())
			var before: int = _puzzle.state.grid[cell.y][cell.x]
			print("  undo visible=", _host.top_bar.undo_button.visible, " enabled=", _puzzle.can_undo())
			_host._on_undo()
			print("  cell ", cell, " after tap=", before, " after undo=", _puzzle.state.grid[cell.y][cell.x], " hearts=", _puzzle.hearts)
		"tr_hud":
			# Trestle: the ?, Undo, Reset and Go as the player reaches them,
			# and a running test held while the card is up.
			var bar = _host.top_bar
			var acts = _host.action_bar
			print("  tr ? visible=%s undo visible=%s hint visible=%s reset (bar) visible=%s reset (actions)=%s go (actions)=%s" % [bar.help_button.visible,
				bar.undo_button.visible, bar.hint_button.visible if bar.get("hint_button") != null else "-", bar.reset_button.visible,
				acts != null and acts.reset_button.visible, acts != null and acts.get("check_button") != null and acts.check_button.visible])
			var road: Array = []
			for p: Dictionary in _puzzle.state.proof:
				if int(p.m) == 0:
					road.append(p)
			_tr_lay(road[0].a, road[0].b, 0)
			_tr_lay(road[1].a, road[1].b, 0)
			await create_timer(0.5).timeout
			_host._refresh()
			print("  tr laid: members=%d can_undo=%s undo enabled=%s" % [_puzzle.state.design.size(), _puzzle.can_undo(), not bar.undo_button.disabled])
			_host._on_undo()
			await create_timer(0.4).timeout
			print("  tr after undo: members=%d" % _puzzle.state.design.size())
			_host._on_check()
			await create_timer(0.6).timeout
			var t0: float = _puzzle.sim.t
			bar.help.emit()
			await create_timer(0.3).timeout
			var card = _host.get_node_or_null("HowToPlay")
			print("  tr Go, then ?: opened=%s pages=%d testing=%s clock_held=%s" % [card != null, card._pages.size() if card != null else 0, _puzzle._testing, _puzzle.clock_held])
			var t1: float = _puzzle.sim.t
			await create_timer(1.5).timeout
			print("  tr under the card: sim %.2f -> %.2f (before it %.2f)" % [t1, _puzzle.sim.t, t0])
			if card != null:
				card.free()
			await create_timer(1.0).timeout
			print("  tr card gone: clock_held=%s sim %.2f" % [_puzzle.clock_held, _puzzle.sim.t])
			await create_timer(6.0).timeout
			_host._refresh()
			print("  tr test over: testing=%s hearts=%d/%d can_reset=%s reset enabled=%s" % [_puzzle._testing, _puzzle.hearts, _puzzle.max_hearts, _puzzle.can_reset(),
				acts != null and not acts.reset_button.disabled])
			_host._on_reset()
			await create_timer(0.5).timeout
			print("  tr after reset: members=%d moves=%d" % [_puzzle.state.design.size(), _puzzle.moves])
		"hh_hud":
			# Hedgehogs: the ?, Undo and Reset as the player reaches them.
			var bar = _host.top_bar
			var acts = _host.action_bar
			print("  hh ? visible=%s undo visible=%s reset (bar) visible=%s reset (actions)=%s" % [bar.help_button.visible,
				bar.undo_button.visible, bar.reset_button.visible, acts != null and acts.reset_button.visible])
			bar.help.emit()
			await create_timer(0.3).timeout
			var card = _host.get_node_or_null("HowToPlay")
			print("  hh ? opened: %s, pages %d" % [card != null, card._pages.size() if card != null else 0])
			if card != null:
				card.queue_free()
			await create_timer(0.3).timeout
			var st = _puzzle._state
			var pick := -1
			for c in st.size():
				if st.open[c] == 0 and not st.is_hog(c):
					pick = c
					break
			_click(_puzzle.cell_to_local(pick / st.cols(), pick % st.cols()))
			await create_timer(1.2).timeout
			_host._refresh()
			print("  hh raked %d: open=%d can_undo=%s undo enabled=%s" % [pick, st.open[pick], _puzzle.can_undo(), bar.undo_button.disabled == false])
			_host._on_undo()
			await create_timer(0.8).timeout
			print("  hh after undo: open=%d" % st.open[pick])
			_click(_puzzle.cell_to_local(pick / st.cols(), pick % st.cols()))
			await create_timer(1.2).timeout
			_host._refresh()
			print("  hh can_reset=%s" % _puzzle.can_reset())
			_host._on_reset()
			await create_timer(0.8).timeout
			print("  hh after reset: open=%d moves=%d" % [st.open[pick], _puzzle.moves])
		"hh_calm":
			# Hedgehogs: no breeze, so a shot at rest is the same run to run.
			_puzzle._next_breeze = INF
			print("  hh calm: done=%s woken=%d hearts=%d moving=%d moves left=%d" % [_puzzle.is_done(), _puzzle._state.woken, _puzzle.hearts, _puzzle._moving.size(), _moves.size()])
		"hh_relay":
			# Hedgehogs: what the win card's relayout makes again -- the lawn, and
			# the bands when the reference is not kept.
			for k in 3:
				var t0 := Time.get_ticks_usec()
				_puzzle._build_lawn()
				var t1 := Time.get_ticks_usec()
				_puzzle._layout()
				_puzzle._update_bands(_puzzle._now())
				var t2 := Time.get_ticks_usec()
				print("  hh lawn %.2f ms, relayout and bands %.2f ms" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
		"hh_count":
			# Hedgehogs: every band of the still made again, the live mesh
			# built as it stands, and a whole row rustling built live, every
			# 1.5 s, with their vertices.
			for k in 5:
				await create_timer(1.5).timeout
				var now: float = _puzzle._now()
				var t0 := Time.get_ticks_usec()
				for b in _puzzle._band_looks.size():
					_puzzle._band_looks[b] = PackedInt32Array()
				_puzzle._update_bands(now)
				var t1 := Time.get_ticks_usec()
				var live = _puzzle._build_live(now)
				var t2 := Time.get_ticks_usec()
				var vs := 0
				for m in _puzzle._bands:
					if m != null:
						vs += m.surface_get_array_len(0)
				var saved: Dictionary = _puzzle._moving.duplicate()
				var cols: int = _puzzle._state.cols()
				for x in cols:
					_puzzle._moving[3 * cols + x] = true
					_puzzle._rustle_at[3 * cols + x] = now - 0.35
				var t3 := Time.get_ticks_usec()
				var row = _puzzle._build_live(now)
				var t4 := Time.get_ticks_usec()
				for x in cols:
					_puzzle._rustle_at[3 * cols + x] = -100.0
				_puzzle._moving = saved
				var rm0 = _puzzle._band_rms[1]
				var cols0: int = _puzzle._state.cols()
				_puzzle._into_ref()
				var u0 := Time.get_ticks_usec()
				rm0.begin()
				for c in range(3 * cols0, 6 * cols0):
					if not _puzzle._moving.has(c):
						rm0.open(0, c)
						_puzzle._put_rest(rm0, c, now)
				var u1 := Time.get_ticks_usec()
				var mm = rm0.mesh()
				var u2 := Time.get_ticks_usec()
				var looks := 0
				for c in _puzzle._state.size():
					looks += _puzzle._look(c, now)
				var u3 := Time.get_ticks_usec()
				_puzzle._out_of_ref()
				print("  band 1: puts %.2f ms, mesh %.2f ms (%d vertices); every look %.2f ms" % [(u1 - u0) / 1000.0, (u2 - u1) / 1000.0, mm.surface_get_array_len(0), (u3 - u2) / 1000.0])
				var L = _puzzle._looks
				print("  looks: ground %d raked %d pile %d pressed %d back %d leaf %d flag %d pin %d paws %d" % [L.size_of(_puzzle._id(0, 5)), L.size_of(_puzzle._id(1, 5)), L.size_of(_puzzle._id(3, 5)), L.size_of(_puzzle._id(4, 5)), L.size_of(_puzzle._id(5, 5)), L.size_of(_puzzle._id(6, 2)), L.size_of(_puzzle._id(7, 0)), L.size_of(_puzzle._id(8, 0)), L.size_of(_puzzle._id(9, 0))])
				print("  hh bands %.2f ms, %d vertices; live %.2f ms, %d vertices; a rustling row %.2f ms, %d vertices; moving %d" % [
					(t1 - t0) / 1000.0, vs, (t2 - t1) / 1000.0, live.surface_get_array_len(0) if live != null else 0,
					(t4 - t3) / 1000.0, row.surface_get_array_len(0) if row != null else 0, saved.size()])
		"pg_count":
			# Pixel Garden: every per-frame builder timed against the board as
			# it stands, every half second through the play window, with
			# vertices: the bands all made again, the live layers, the head's
			# four layers made again, the table and the pegs.
			while _t < _play_to - 0.6:
				await create_timer(0.5).timeout
				var now: float = _puzzle._now()
				var vs := func(m) -> int: return m.surface_get_array_len(0) if m != null else 0
				var t0 := Time.get_ticks_usec()
				_puzzle._band_looks = []
				_puzzle._update_bands(now)
				var t1 := Time.get_ticks_usec()
				_puzzle._build_live(now)
				var t2 := Time.get_ticks_usec()
				_puzzle._head_under = null
				_puzzle._update_head(now)
				var h1 := Time.get_ticks_usec()
				_puzzle._heaps = null
				_puzzle._update_head(now)
				var h2 := Time.get_ticks_usec()
				_puzzle._head_lid = null
				_puzzle._update_head(now)
				var t3 := Time.get_ticks_usec()
				print("  pg head: box %.2f ms, heaps %.2f ms, lid %.2f ms" % [(h1 - t2) / 1000.0, (h2 - h1) / 1000.0, (t3 - h2) / 1000.0])
				var table = _puzzle._build_table(now)
				var t4 := Time.get_ticks_usec()
				_puzzle._build_pegs()
				var t5 := Time.get_ticks_usec()
				var band_vs := 0
				for m in _puzzle._bands:
					band_vs += vs.call(m)
				print("  pg bands %.2f ms (%d v); live %.2f ms (beads %d v, air %d v, marks %d v, moving %d); head %.2f ms (under %d, heaps %d, over %d, lid %d v); table %.2f ms (%d v); pegs %.2f ms (%d v)" % [
					(t1 - t0) / 1000.0, band_vs, (t2 - t1) / 1000.0, vs.call(_puzzle._live_beads), vs.call(_puzzle._live), vs.call(_puzzle._marks), _puzzle._moving.size(),
					(t3 - t2) / 1000.0, vs.call(_puzzle._head_under), vs.call(_puzzle._heaps), vs.call(_puzzle._head_over), vs.call(_puzzle._head_lid),
					(t4 - t3) / 1000.0, vs.call(table), (t5 - t4) / 1000.0, vs.call(_puzzle._pegs_under) + vs.call(_puzzle._pegs_bare)])
		"pg_relay":
			# Pixel Garden: what the win card's relayout makes again, timed.
			for k in 3:
				await create_timer(0.4).timeout
				var now: float = _puzzle._now()
				var t0 := Time.get_ticks_usec()
				_puzzle._layout()
				_puzzle._ensure_kits()
				var t1 := Time.get_ticks_usec()
				_puzzle._table = _puzzle._build_table(now)
				var t2 := Time.get_ticks_usec()
				_puzzle._build_pegs()
				var t3 := Time.get_ticks_usec()
				_puzzle._update_bands(now)
				_puzzle._build_live(now)
				var t4 := Time.get_ticks_usec()
				_puzzle._update_head(now)
				var t5 := Time.get_ticks_usec()
				print("  pg relay: layout %.2f, table %.2f, pegs %.2f, bands+live %.2f, head %.2f ms" % [(t1 - t0) / 1000.0,
					(t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0, (t5 - t4) / 1000.0])
		"pg_hud":
			# Pixel Garden: the ?, Undo and Reset as the player reaches them.
			var bar = _host.top_bar
			var acts = _host.action_bar
			print("  pg ? visible=%s undo visible=%s reset (bar) visible=%s reset (actions)=%s check (actions)=%s" % [bar.help_button.visible,
				bar.undo_button.visible, bar.reset_button.visible, acts != null and acts.reset_button.visible,
				acts != null and acts.get("check_button") != null and acts.check_button.visible])
			bar.help.emit()
			await create_timer(0.3).timeout
			var card = _host.get_node_or_null("HowToPlay")
			print("  pg ? opened: %s, pages %d" % [card != null, card._pages.size() if card != null else 0])
			if card != null:
				card.queue_free()
			await create_timer(0.3).timeout
			var st = _puzzle._state
			var n: int = st.n
			var run: Array = []
			for c in st.size():
				if st.want[c] != st.EMPTY and (run.is_empty() or (c == int(run[-1]) + 1 and st.want[c] == st.want[run[0]] and c / n == int(run[0]) / n)):
					run.append(c)
				elif not run.is_empty():
					break
			_click(_puzzle.chip_to_local(st.want[run[0]]))
			_ut_button(_puzzle.cell_to_local(int(run[0]) / n, int(run[0]) % n), true)
			for c in run:
				_ut_motion(_puzzle.cell_to_local(int(c) / n, int(c) % n))
			_ut_button(_puzzle.cell_to_local(int(run[-1]) / n, int(run[-1]) % n), false)
			await create_timer(0.6).timeout
			_host._refresh()
			print("  pg stroke: placed %d can_undo=%s undo enabled=%s" % [st.placed(), _puzzle.can_undo(), not bar.undo_button.disabled])
			_host._on_undo()
			await create_timer(0.6).timeout
			print("  pg after undo: placed %d" % st.placed())
			_ut_button(_puzzle.cell_to_local(int(run[0]) / n, int(run[0]) % n), true)
			_ut_button(_puzzle.cell_to_local(int(run[0]) / n, int(run[0]) % n), false)
			await create_timer(0.6).timeout
			_host._refresh()
			print("  pg tapped: placed %d" % st.placed())
			_host._on_reset()
			await create_timer(0.8).timeout
			print("  pg after reset: placed %d moves %d" % [st.placed(), _puzzle.moves])
		"db_hud":
			# Drumbeat: the ? and Reset as the player reaches them, mid-song.
			var bar = _host.top_bar
			print("  db ? visible=%s undo visible=%s reset visible=%s enabled=%s" % [bar.help_button.visible, bar.undo_button.visible,
				bar.reset_button.visible, not bar.reset_button.disabled])
			_puzzle.strike(0)
			await create_timer(4.0).timeout
			print("  db playing: phase %s song %.2f" % [_puzzle._phase, _puzzle.song_now()])
			bar.help.emit()
			await create_timer(0.5).timeout
			var card = _host.get_node_or_null("HowToPlay")
			var held: float = _puzzle.song_now()
			print("  db ? opened: %s pages %d phase %s music paused=%s" % [card != null, card._pages.size() if card != null else 0, _puzzle._phase, _puzzle._music.stream_paused])
			await create_timer(1.5).timeout
			print("  db under the card: song %.2f -> %.2f" % [held, _puzzle.song_now()])
			if card != null:
				card._continue()
			await create_timer(0.5).timeout
			print("  db card closed: phase %s clock_held=%s" % [_puzzle._phase, _puzzle.clock_held])
			_puzzle.strike(0)
			await create_timer(1.0).timeout
			print("  db a tap goes on: phase %s song %.2f" % [_puzzle._phase, _puzzle.song_now()])
			_host._open_settings()
			await create_timer(0.8).timeout
			print("  db settings up: phase %s" % _puzzle._phase)
			_host.settings_sheet.close()
			await create_timer(0.8).timeout
			_puzzle.strike(0)
			await create_timer(0.5).timeout
			print("  db settings closed, a tap: phase %s clock_held=%s" % [_puzzle._phase, _puzzle.clock_held])
			_host._on_reset()
			await create_timer(0.5).timeout
			print("  db after reset: phase %s song %.2f hearts %d moves %d music playing=%s" % [_puzzle._phase, _puzzle.song_now(), _puzzle._st.hearts, _puzzle.moves, _puzzle._music.playing])
			# reset while paused, then started again: the music must sound
			_puzzle.strike(0)
			await create_timer(1.0).timeout
			bar.help.emit()
			await create_timer(0.4).timeout
			_host.get_node("HowToPlay")._continue()
			_host._on_reset()
			await create_timer(0.3).timeout
			_puzzle.strike(0)
			await create_timer(0.6).timeout
			print("  db reset under a pause, started again: phase %s music playing=%s paused=%s" % [_puzzle._phase, _puzzle._music.playing, _puzzle._music.stream_paused])
		"mg_hud":
			# Marigold: the ?, Undo and Reset as the player reaches them.
			var bar = _host.top_bar
			var acts = _host.action_bar
			print("  mg ? visible=%s undo visible=%s reset (bar) visible=%s reset (actions)=%s" % [bar.help_button.visible,
				bar.undo_button.visible, bar.reset_button.visible, acts != null and acts.reset_button.visible])
			bar.help.emit()
			await create_timer(0.3).timeout
			var card = _host.get_node_or_null("HowToPlay")
			print("  mg ? opened: %s, pages %d" % [card != null, card._pages.size() if card != null else 0])
			if card != null:
				card.queue_free()
			await create_timer(0.3).timeout
			var st = _puzzle._state
			var seeds0: int = st.seeds
			_puzzle._aim = 1.3
			_puzzle._shoot()
			while _puzzle.busy():
				await process_frame
			_host._refresh()
			print("  mg shot: seeds %d -> %d score %d can_undo=%s undo enabled=%s hearts %d" % [seeds0, st.seeds, st.score,
				_puzzle.can_undo(), not bar.undo_button.disabled, _puzzle.hearts])
			_host._on_undo()
			await create_timer(0.5).timeout
			print("  mg after undo: seeds %d score %d hearts %d" % [st.seeds, st.score, _puzzle.hearts])
			_puzzle._aim = 0.9
			_puzzle._shoot()
			while _puzzle.busy():
				await process_frame
			_host._refresh()
			print("  mg can_reset=%s" % _puzzle.can_reset())
			_host._on_reset()
			await create_timer(0.5).timeout
			print("  mg after reset: seeds %d score %d hearts %d moves %d" % [st.seeds, st.score, _puzzle.hearts, _puzzle.moves])
		"mg_count":
			# Marigold: every per-frame builder timed against the board as it
			# stands, every half second through the play window, with vertices.
			while _t < _play_to - 0.6:
				await create_timer(0.5).timeout
				var now: float = _puzzle._now()
				var row := []
				for name in ["_build_lit", "_build_live_back", "_build_live", "_build_air", "_build_trail", "_build_buds"]:
					var t0 := Time.get_ticks_usec()
					var m: ArrayMesh
					var vs := 0
					if name == "_build_buds":
						for k in _puzzle.BUD_BANDS:
							m = _puzzle._build_buds(now, k)
							vs += m.surface_get_array_len(0) if m != null else 0
					else:
						m = _puzzle.call(name, now) if name != "_build_trail" else _puzzle._build_trail()
						vs = m.surface_get_array_len(0) if m != null else 0
					row.append("%s %.2f/%d" % [name.substr(7), (Time.get_ticks_usec() - t0) / 1000.0, vs])
				print("  mg t=%.1f %s bits %d air %d stickers %d lit %d phase %s | %s" % [_t, _puzzle._phase, _puzzle._bits.size(), _puzzle._air_bits.size(), _puzzle._stickers.size(), _puzzle._order.size(), _puzzle._phase, " ".join(row)])
		"kn_relay":
			# What the win card's relayout makes again: the table and the still.
			for k in 3:
				var t0 := Time.get_ticks_usec()
				_puzzle._build_table()
				var t1 := Time.get_ticks_usec()
				_puzzle._build_still()
				var t2 := Time.get_ticks_usec()
				print("  kn table %.2f ms, still %.2f ms" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
		"kn_count":
			# One live build, timed every 1.5 s, with its vertices.
			for k in 5:
				create_timer(1.5 * k).timeout.connect(func():
					var now: float = _puzzle._now()
					_puzzle._lb = load("res://ui/faces/face.gd").Builder.new()
					var t0 := Time.get_ticks_usec()
					_puzzle._ground_key = []
					_puzzle._build_ground(now)
					var t1 := Time.get_ticks_usec()
					_puzzle._build_ground(now)
					var t2 := Time.get_ticks_usec()
					var m: ArrayMesh = _puzzle._build_pieces(now)
					var t3 := Time.get_ticks_usec()
					var g: ArrayMesh = _puzzle._ground
					print("  kn ground %.2f ms (handed back %.2f), %d vertices; pieces %.2f ms, %d vertices; hops %d, brambles %d" % [
						(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, g.surface_get_array_len(0) if g != null else 0,
						(t3 - t2) / 1000.0, m.surface_get_array_len(0) if m != null else 0,
						_puzzle._state.route().size() - 1, _puzzle._grown.size()]))
		"sb_frozen":
			# The board stops redrawing: what drawing its meshes costs as they
			# stand, against re-recording them every frame.
			for what in ["live", "frozen"]:
				var sum := 0.0
				var n := 0
				var t_end := _t + 1.5
				if what == "frozen":
					_puzzle.set_process(false)
				while _t < t_end:
					await process_frame
					sum += RenderingServer.viewport_get_measured_render_time_cpu(_vp)
					n += 1
				print("  %s: render-cpu %.2f over %d frames" % [what, sum / maxf(n, 1), n])
			_puzzle.set_process(true)
		"sb_parts":
			# Sunbeam's meshes dropped one at a time over the idle window, the
			# renderer's CPU share read over each second.
			for what in ["all", "lower", "upper", "still", "none"]:
				var sum := 0.0
				var n := 0
				var t_end := _t + 1.0
				match what:
					"lower":
						_puzzle.set("_lower", null)
						if "_live" in _puzzle:
							_puzzle.set("_live", ArrayMesh.new())
					"upper":
						_puzzle.set("_upper", null)
					"still":
						_puzzle._still = ArrayMesh.new()
				while _t < t_end:
					await process_frame
					sum += RenderingServer.viewport_get_measured_render_time_cpu(_vp)
					n += 1
				print("  without %s: render-cpu %.2f over %d frames" % [what, sum / maxf(n, 1), n])
		"cue_late":
			# Every cue the streak plays, one at a time inside the idle window.
			for c in ["combo", "confetti", "rainbow", "love", "flutter", "dew", "slide"]:
				await create_timer(0.4).timeout
				var t0 := Time.get_ticks_usec()
				_puzzle.fx.cue(c, 1.2, -4.0)
				print("  cue %s %.2f ms at t=%.2f" % [c, (Time.get_ticks_usec() - t0) / 1000.0, _t])
				_log_until = _t + 0.1
		"confetti_late":
			# One burst inside the idle window, so a first burst's hitch shows.
			await create_timer(2.0).timeout
			_puzzle.fx.confetti(_puzzle.size * 0.5, 22)
			print("  confetti fired at t=%.2f" % _t)
			_log_until = _t + 0.2
		"confetti":
			var t0 := Time.get_ticks_usec()
			_puzzle.fx.confetti(_puzzle.size * 0.5, 22)
			print("  confetti call %.2f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
			_log_until = _t + 0.2
		"sk_count":
			await create_timer(3.0).timeout
			print("  draws now ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			var vis := 0
			for m in _puzzle._markers:
				vis += int(m.visible)
			print("  markers drawn by themselves ", vis, "/", _puzzle._markers.size(), " beds ", _puzzle.state.rects.size(), " flies ", _puzzle._flies.size(), " fence ", _puzzle._fence != null, " anim ", _puzzle._anim_until - _puzzle._now(), " flies ", _puzzle._flies.size(), " purrs ", _puzzle._purrs.size(), " shown ", _puzzle._life_shown.size(), " snail ", _puzzle._snail.size())
		"sk_markers":
			for m in _puzzle._markers:
				m.visible = false
		"sk_numbers":
			for m in _puzzle._markers:
				m.number = 0
		"tn_count":
			await create_timer(2.0).timeout
			var t0 := Time.get_ticks_usec()
			_puzzle._build_ground(_puzzle._now())
			print("  ground build %.2f ms cairns %d anim %.2f flies %d" % [(Time.get_ticks_usec() - t0) / 1000.0,
				_puzzle.state.cairns(), _puzzle._anim_until - _puzzle._now(), _puzzle._flies.size()])
			print("  draws now ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " process ", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			_log_until = _t + 0.1
		"tn_trees", "tn_tents", "tn_chips":
			var hide: Array = {"tn_trees": _puzzle._trees.values(), "tn_tents": _puzzle._tents.values(),
				"tn_chips": _puzzle._chips_row + _puzzle._chips_col}[_exp]
			for f in hide:
				f.visible = false
		"lu_count":
			# One court build as a frame does it, then one with every bake made
			# again (the cost of a change to what is at rest), then the beams.
			await create_timer(2.0).timeout
			for k in 3:
				var t0 := Time.get_ticks_usec()
				_puzzle._build_court(_puzzle._now())
				var t1 := Time.get_ticks_usec()
				_puzzle._floor_key = PackedInt32Array()
				_puzzle._ground_key = PackedInt32Array()
				_puzzle._beams_dirty = true
				_puzzle._build_court(_puzzle._now())
				var t2 := Time.get_ticks_usec()
				_puzzle._build_beams(load("res://ui/faces/face.gd").Builder.new(), _puzzle._now(), Vector2.ZERO)
				var t3 := Time.get_ticks_usec()
				print("  court %.2f ms rebake %.2f ms beams %.2f ms" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0])
			print("  draws now ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " lamps ", _puzzle.state.lamps().size(),
				" cats ", _puzzle._cats.size(), " anim ", _puzzle._anim_until - _puzzle._now(), " moths ", _puzzle._flies.size())
		"rg_count":
			# Every station's mesh made again and the ring in hand built, as an
			# animating frame does them, every 1.5 s, with their vertices.
			for n in 6:
				await create_timer(1.5).timeout
				var t: float = _puzzle._now()
				var t0 := Time.get_ticks_usec()
				var vs := 0
				for i in _puzzle._state.pegs.size():
					var look: Dictionary = _puzzle._station_look(i, t, 0.0)
					var st: Dictionary = _puzzle._station(i)
					var m: ArrayMesh = _puzzle._build_station(float(st["cx"]), float(st["ground"]), look)
					vs += 0 if m == null else m.surface_get_array_len(0)
				var t1 := Time.get_ticks_usec()
				var held: bool = _puzzle._state.held != -1
				if not held:
					_puzzle._state.lift(_first_liftable())
					_puzzle._held_at = t
				var t2 := Time.get_ticks_usec()
				var l = _puzzle._build_live(t + 1.0)
				var t3 := Time.get_ticks_usec()
				if not held:
					_puzzle._state.put_back()
					_puzzle._held_at = -100.0
				if n == 1:
					var lk = _puzzle._looks
					var a0 := Time.get_ticks_usec()
					for r in 100:
						lk.begin()
						_puzzle._put_ring(500.0, 500.0, 9, Vector2.ONE, 0.0, 0.0, 0.0)
					var a1 := Time.get_ticks_usec()
					lk.begin()
					for r in 100:
						_puzzle._put_post(500.0, 300.0, 500.0)
					var a2 := Time.get_ticks_usec()
					lk.begin()
					for r in 4:
						_puzzle._put_ring(500.0, 500.0, 9, Vector2.ONE, 0.0, 0.0, 0.0)
					var a3 := Time.get_ticks_usec()
					for r in 100:
						lk.mesh()
					var a4 := Time.get_ticks_usec()
					for r in 100:
						var_to_str(_puzzle._station_look(0, t, 0.0))
					var a5 := Time.get_ticks_usec()
					print("  ring %.3f post %.3f mesh(4 rings) %.3f look+key %.3f ms each" % [(a1 - a0) / 100000.0, (a2 - a1) / 100000.0, (a4 - a3) / 100000.0, (a5 - a4) / 100000.0])
				print("  frame with every station rebuilt %.2f ms v%d | held ring %.2f ms v%d" % [(t1 - t0) / 1000.0, vs,
					(t3 - t2) / 1000.0, 0 if l == null else l.surface_get_array_len(0)])
		"pw_count":
			# The still and live builds as an animating frame does them, every
			# 1.5 s, with their vertices: the still mesh made again, and handed
			# back.
			for n in 7:
				await create_timer(1.5).timeout
				var t: float = _puzzle._now()
				_puzzle._in_ref = true
				var t0 := Time.get_ticks_usec()
				_puzzle._still_built = false
				var s = _puzzle._build_still(t)
				var t1 := Time.get_ticks_usec()
				_puzzle._build_still(t)
				var t2 := Time.get_ticks_usec()
				var l = _puzzle._build_live(t)
				_puzzle._stain_plan = null
				_puzzle._rib_plan = null
				_puzzle._wheel_plan = null
				var w0 := Time.get_ticks_usec()
				_puzzle._build_stain(t)
				var w1 := Time.get_ticks_usec()
				_puzzle._build_ribbons(t)
				var w2 := Time.get_ticks_usec()
				_puzzle._build_wheels(t)
				var w3 := Time.get_ticks_usec()
				_puzzle._build_wheels(t)
				var w4 := Time.get_ticks_usec()
				print("  stain %.2f ribbons %.2f wheels %.2f (handed back %.2f)" % [(w1 - w0) / 1000.0, (w2 - w1) / 1000.0, (w3 - w2) / 1000.0, (w4 - w3) / 1000.0])
				var t3 := Time.get_ticks_usec()
				_puzzle._in_ref = false
				var vc := func(m): return 0 if m == null else m.surface_get_array_len(0)
				print("  still %.2f ms v%d (handed back %.2f) | live %.2f ms v%d | pieces %d %dx%d anim %s" % [(t1 - t0) / 1000.0, vc.call(s),
					(t2 - t1) / 1000.0, (t3 - t2) / 1000.0, vc.call(l), _puzzle._state.shapes.size(), _puzzle._state.cols, _puzzle._state.rows, _puzzle._animating(t)])
		"br_count":
			# One board build as an animating frame does it (the bands, the
			# runs, the islets), every 1.5 s, with the meshes' vertices.
			for n in 6:
				await create_timer(1.5).timeout
				var t: float = _puzzle._now()
				_puzzle._in_ref = true
				var t0 := Time.get_ticks_usec()
				var ms: Array = _puzzle._build(t)
				var t1 := Time.get_ticks_usec()
				_puzzle._runs_sig = []
				_puzzle._islets_sig = []
				_puzzle._build_runs(t)
				var t2 := Time.get_ticks_usec()
				_puzzle._build_islets(t)
				var t3 := Time.get_ticks_usec()
				_puzzle._in_ref = false
				print("  runs %.2f ms islets %.2f ms" % [(t2 - t1) / 1000.0, (t3 - t2) / 1000.0])
				var verts := []
				for m in ms:
					verts.append(m.surface_get_array_len(0) if m != null else 0)
				print("  board %.2f ms verts %s runs %d shapes %d" % [(t1 - t0) / 1000.0, verts,
					_puzzle.state.runs.size(), _puzzle._run_ids.size()])
				if n == 0:
					var rmi = _puzzle._rm_islets
					_puzzle._in_ref = true
					print("  sea %d body %d flag %d coin %d lantern %d ring2 %d islets %d cell %.1f" % [_puzzle._sea.surface_get_array_len(0),
						rmi.size_of(0), rmi.size_of(100000), rmi.size_of(200000), rmi.size_of(200001), rmi.size_of(300000 + 2004),
						_puzzle.state.islets.size(), _puzzle._cell()])
					for id in _puzzle._run_looks:
						print("   run ", _puzzle._run_looks[id].count, " verts ", _puzzle._rm_runs.size_of(id))
						break
					_puzzle._in_ref = false
		"ql_count":
			# The quilt, rack and hand built as an animating frame builds them,
			# timed, every 1.5 s, with their vertices.
			for n in 6:
				await create_timer(1.5).timeout
				var t: float = _puzzle._now()
				var t0 := Time.get_ticks_usec()
				var q: ArrayMesh = _puzzle._build_quilt(t)
				var t1 := Time.get_ticks_usec()
				var r: ArrayMesh = _puzzle._build_rack(t)
				var t2 := Time.get_ticks_usec()
				var h: ArrayMesh = _puzzle._build_hand(t)
				var t3 := Time.get_ticks_usec()
				var sm := Time.get_ticks_usec()
				var seams: Array = _puzzle._seams()
				var t4 := Time.get_ticks_usec()
				var vc := func(m) -> int: return m.surface_get_array_len(0) if m != null else 0
				print("  quilt %.2f ms v%d | rack %.2f ms v%d | hand %.2f ms v%d | seams %.2f ms n%d | sewn %d drag %s" % [
					(t1 - t0) / 1000.0, vc.call(q), (t2 - t1) / 1000.0, vc.call(r), (t3 - t2) / 1000.0, vc.call(h),
					(t4 - sm) / 1000.0, seams.size(), _puzzle._state.covered(), not _puzzle._drag.is_empty()])
		"fl_count":
			# One garden build as an animating frame does it, every 1.5 s,
			# with its vertices, and the still layer's.
			for n in 6:
				await create_timer(1.5).timeout
				var t: float = _puzzle._now()
				_puzzle._in_ref(true)
				_puzzle._rest_plan = PackedInt32Array()
				var t0 := Time.get_ticks_usec()
				var m: ArrayMesh = _puzzle._build(t)
				var t1 := Time.get_ticks_usec()
				var st: ArrayMesh = _puzzle._build_still()
				var t2 := Time.get_ticks_usec()
				var m2: ArrayMesh = _puzzle._build(t)
				var t3 := Time.get_ticks_usec()
				_puzzle._in_ref(false)
				var vc := func(x) -> int: return x.surface_get_array_len(0) if x != null else 0
				print("  garden %.2f ms (handed back %.2f) live v%d rest v%d | still %.2f ms v%d | lit %d" % [(t1 - t0) / 1000.0, (t3 - t2) / 1000.0, vc.call(m),
					vc.call(_puzzle._rest_mesh), (t2 - t1) / 1000.0, vc.call(st), Array(_puzzle.state.depths()).filter(func(d): return d >= 0).size()])
				var l0 := Time.get_ticks_usec()
				_puzzle._lanterns_mesh()
				print("  lanterns %.2f ms" % ((Time.get_ticks_usec() - l0) / 1000.0))
		"sb_count":
			# The light traced and the live, air and still meshes built as a
			# frame builds them, every 1.5 s, with their vertices; once with a
			# piece held (the drag frame).
			for n in 6:
				await create_timer(1.5).timeout
				var t: float = _puzzle._now()
				if n % 2 == 1 and _puzzle._drag.is_empty():
					var p0: int = 0
					while _puzzle._state.pinned.has(p0):
						p0 += 1
					_puzzle._drag = {"p": p0, "s": float(_puzzle._state.pos[p0]) + 0.3, "off": 0.0, "before": _puzzle._state.pos.duplicate(), "at": t - 1.0}
				var vc := func(x) -> int: return x.surface_get_array_len(0) if x != null else 0
				var t0 := Time.get_ticks_usec()
				_puzzle._tr = _puzzle._trace_live(t)
				var t1 := Time.get_ticks_usec()
				_puzzle._in_ref = true
				_puzzle._build_live(t)
				var t2 := Time.get_ticks_usec()
				_puzzle._beam_key = []
				_puzzle._build_live(t)
				var t2b := Time.get_ticks_usec()
				var a = _puzzle._build_air(t)
				var t3 := Time.get_ticks_usec()
				var s = _puzzle._build_bed()
				var t4 := Time.get_ticks_usec()
				_puzzle._in_ref = false
				var gl = _puzzle._build_glass()
				var t5 := Time.get_ticks_usec()
				print("  trace %.2f | live %.2f ms (beam made %.2f) v%d+%d+%d | air %.2f ms v%d | bed %.2f ms v%d | glass %.2f ms v%d | drag %s" % [(t1 - t0) / 1000.0,
					(t2 - t1) / 1000.0, (t2b - t2) / 1000.0, vc.call(_puzzle._lower), vc.call(_puzzle._beam_mesh), vc.call(_puzzle._upper),
					(t3 - t2b) / 1000.0, vc.call(a), (t4 - t3) / 1000.0, vc.call(s), (t5 - t4) / 1000.0, vc.call(gl), not _puzzle._drag.is_empty()])
				_puzzle._drag = {}
		"pp_count":
			# One field and one still build as an animating frame does them,
			# every 1.5 s, with their vertices and what is moving.
			for n in 6:
				await create_timer(1.5).timeout
				var t: float = _puzzle._now()
				var mv: Dictionary = _puzzle._moving(t)
				var t0 := Time.get_ticks_usec()
				var f: ArrayMesh = _puzzle._build_field(t, mv)
				var t1 := Time.get_ticks_usec()
				var s: ArrayMesh = _puzzle._build_still(mv)
				var t2 := Time.get_ticks_usec()
				var vc := func(x) -> int: return x.surface_get_array_len(0) if x != null else 0
				print("  field %.2f ms v%d | still %.2f ms v%d | moving %d left %d flying %d" % [(t1 - t0) / 1000.0, vc.call(f),
					(t2 - t1) / 1000.0, vc.call(s), mv.size(), _puzzle._state.left(), _puzzle._fly.size()])
				var B = load("res://ui/faces/face.gd").Builder
				var p0 := Time.get_ticks_usec()
				_puzzle._dots(B.new(), _puzzle._covers(t), t)
				var p1 := Time.get_ticks_usec()
				_puzzle._draw_sprigs(B.new(), t)
				var p2 := Time.get_ticks_usec()
				var bb = B.new()
				for i in _puzzle._fly:
					_puzzle._contrail(bb, i, t)
				var p3 := Time.get_ticks_usec()
				var bp = B.new()
				for i in mv:
					if _puzzle._fly.has(i) or not _puzzle._state.planes[i]["gone"]:
						_puzzle._plane(bp, i, t, 0.0)
				var p4 := Time.get_ticks_usec()
				print("   dots %.2f sprigs %.2f (%d) contrails %.2f planes %.2f" % [(p1 - p0) / 1000.0, (p2 - p1) / 1000.0, _puzzle._sprigs.size(), (p3 - p2) / 1000.0, (p4 - p3) / 1000.0])
		"fl_lanterns":
			# Every lantern hidden: what the painted lanterns cost.
			for slot in _puzzle._slots.values():
				slot.visible = false
		"sd_count":
			# One grid build as a frame does it, every 2 s, with its vertices.
			for n in 5:
				await create_timer(2.0).timeout
				var t0 := Time.get_ticks_usec()
				var m: ArrayMesh = _puzzle._build_grid(_puzzle._now())
				var t1 := Time.get_ticks_usec()
				_puzzle.queue_redraw()
				print("  grid build %.2f ms verts %d filled %d" % [(t1 - t0) / 1000.0,
					m.surface_get_array_len(0) if m != null else 0, _puzzle.state.grid.count(0)])
		"lu_lamps", "lu_cats", "lu_life", "lu_veil":
			match _exp:
				"lu_lamps":
					for c in _puzzle._lamps:
						_puzzle._slots[_puzzle._lamps[c]].visible = false
				"lu_cats":
					for c in _puzzle._cats:
						_puzzle._slots[_puzzle._cats[c]].visible = false
				"lu_life":
					_puzzle._life_layer.visible = false
				"lu_veil":
					_puzzle._veil_layer.visible = false
		"ol_count":
			# One figure cast as a frame does it, timed, and what it draws.
			await create_timer(2.0).timeout
			for k in 3:
				var t0 := Time.get_ticks_usec()
				_puzzle._cast_figure(_puzzle._now())
				var t1 := Time.get_ticks_usec()
				var a = _puzzle._figure.surface_get_arrays(0)
				print("  cast %.2f ms verts %d (runs %d) indices %d looks %d lines %d posts %d" % [(t1 - t0) / 1000.0,
					a[0].size(), _puzzle._fixed, a[Mesh.ARRAY_INDEX].size(), _puzzle._looks.size(), _puzzle.state.edges.size(), _puzzle.state.nodes.size()])
			print("  draws now ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " anim ", _puzzle._anim_until - _puzzle._now())
		"ng_count":
			# One floor build as a frame does it, timed, and what it draws.
			await create_timer(2.0).timeout
			for k in 3:
				var t0 := Time.get_ticks_usec()
				var m: ArrayMesh = _puzzle._build_floor(_puzzle._now())
				var t1 := Time.get_ticks_usec()
				var a = m.surface_get_arrays(0)
				print("  floor %.2f ms verts %d (runs %d) indices %d shapes %d painted %d" % [(t1 - t0) / 1000.0,
					a[0].size(), _puzzle._fixed, a[Mesh.ARRAY_INDEX].size(), _puzzle._shapes.size(), _puzzle._inked.size()])
			print("  size %dx%d marks %d draws now %d" % [_puzzle.state.w, _puzzle.state.h, _puzzle.state.marks.size(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		"hw_count":
			# One grid build as an animating frame does it, timed, a few times
			# over the run (a flip, a typed row, a sealed row).
			for k in 6:
				await create_timer(2.0).timeout
				var t0 := Time.get_ticks_usec()
				var m: ArrayMesh = _puzzle._build_grid(_puzzle._now())
				var t1 := Time.get_ticks_usec()
				var a = m.surface_get_arrays(0) if m != null else [[]]
				print("  grid %.2f ms verts %d rows %d" % [(t1 - t0) / 1000.0, a[0].size(), _puzzle.state.rows.size()])
		"wt_count":
			# One field, slots and air build as an animating frame does them,
			# timed, a few times over the run.
			for k in 6:
				await create_timer(2.0).timeout
				var now: float = _puzzle._now()
				var t0 := Time.get_ticks_usec()
				var m: ArrayMesh = _puzzle._build_field(now)
				var t1 := Time.get_ticks_usec()
				_puzzle._build_slots(now)
				var t2 := Time.get_ticks_usec()
				_puzzle._build_air(now)
				var t3 := Time.get_ticks_usec()
				var a = m.surface_get_arrays(0) if m != null else [[]]
				print("  field %.2f ms verts %d | slots %.2f | air %.2f | found %d" % [(t1 - t0) / 1000.0, a[0].size(),
					(t2 - t1) / 1000.0, (t3 - t2) / 1000.0, _puzzle._state.found_count()])
		"mp_count":
			# One floor and one ground build as an animating frame does them,
			# timed, a few times over the run.
			for k in 6:
				await create_timer(2.0).timeout
				var now: float = _puzzle._now()
				var t0 := Time.get_ticks_usec()
				var fl: ArrayMesh = _puzzle._build_floor(now)
				var t1 := Time.get_ticks_usec()
				var gr: Dictionary = _puzzle._build_ground(now)
				var t2 := Time.get_ticks_usec()
				var fa = fl.surface_get_arrays(0) if fl != null else [[]]
				var ga = gr.mesh.surface_get_arrays(0) if gr.mesh != null else [[]]
				print("  floor %.2f ms verts %d | ground %.2f ms verts %d | marks %d" % [(t1 - t0) / 1000.0, fa[0].size(),
					(t2 - t1) / 1000.0, ga[0].size(), _puzzle.state.marks.size()])
		"trivialwash":
			var sh := Shader.new()
			sh.code = "shader_type canvas_item;\nvoid fragment() { COLOR.rgb *= 1.0; }"
			load("res://ui/theme.gd").paper().shader = sh
		"bn_tints":
			for row in _puzzle._tints:
				for t in row:
					t.visible = false
		"bn_faces":
			for row in _puzzle._faces:
				for f in row:
					if f != null:
						f.visible = false
		"bn_coins":
			for row in _puzzle._styles:
				for sb in row:
					sb.draw_center = false
					sb.border_width_bottom = 0
		"bn_layers":
			for l in [_puzzle._sign_layer, _puzzle._heart_layer, _puzzle._combo_layer]:
				l.visible = false
		"bn_fx":
			_puzzle.fx.visible = false
		"cb_faces", "cb_sockets", "cb_pouches", "cb_cards", "cb_nums", "cb_marks", "cb_code", "cb_rings":
			var arr: Array = {"cb_faces": _puzzle._face, "cb_sockets": _puzzle._socket,
				"cb_pouches": [_puzzle._pouch], "cb_cards": [_puzzle._row_card],
				"cb_nums": [_puzzle._row_num], "cb_marks": [_puzzle._mark],
				"cb_code": [_puzzle._lid_seat], "cb_rings": _puzzle._ring}[_exp]
			for row in arr:
				for n in row:
					if n != null:
						n.visible = false
		"cb_reset":
			var baked := func() -> int:
				return _puzzle._baked.filter(func(b): return b.visible).size()
			print("  baked before reset ", baked.call(), " can_reset ", _puzzle.can_reset())
			_puzzle.reset_board()
			_puzzle._process(0.0)
			print("  baked after reset ", baked.call(), " guesses ", _puzzle.state.guesses.size())
		"cb_live":
			_puzzle.set_process(false)
			for g in _puzzle._rows.size():
				_puzzle._show_nodes(g, true)
		"bal_warm":
			# the solve's lettering once, early, to see whether its first
			# draw (glyph rasterising) is the solve's hitch
			_puzzle._rw.sticker(_puzzle.tr("BAL_W_BALANCED"), _puzzle._word_at(), 112, 0.3, true, Color.WHITE, true, "closer")
			_puzzle._rw.sticker(_puzzle.tr("BAL_W_NO_HINTS"), _puzzle._word_at(), 46, 0.3, false, Color.WHITE, false, "nohints")
		"nowash":
			for c in _all(_host, func(n): return n is CanvasItem and n.material != null):
				c.material = null
		_:
			if _exp.begins_with("hide:"):
				for name in _exp.substr(5).split(","):
					var hit := _host.find_child(name, true, false)
					if hit != null:
						hit.visible = false
					else:
						print("no node ", name)
	if _exp == "parts":
		for k in 3:
			for name in ["_host._refresh", "_puzzle._recolour", "_puzzle._focus", "_puzzle._glance", "_puzzle.state.refresh_bad", "_puzzle.state.broken_rule", "_host.top_bar.refresh", "_host.action_bar.refresh", "_host.tray.refresh", "flip", "puff", "cue", "hop", "nudge", "note_move", "celebrate", "after_change", "sync_under"]:
				var t0 := Time.get_ticks_usec()
				for j in 10:
					match name:
						"_host._refresh": _host._refresh()
						"_puzzle._recolour": _puzzle._recolour()
						"_puzzle._focus": _puzzle._focus(3, 3)
						"_puzzle._glance": _puzzle._glance(3, 3)
						"_puzzle.state.refresh_bad": _puzzle.state.refresh_bad()
						"_puzzle.state.broken_rule": _puzzle.state.broken_rule()
						"_host.top_bar.refresh": _host.top_bar.refresh(_puzzle)
						"_host.action_bar.refresh": _host.action_bar.refresh(_puzzle)
						"_host.tray.refresh": _host.tray.refresh(_puzzle)
						"flip": _puzzle._flip_face(3, 3, j % 2)
						"puff": _puzzle.fx.puff(Vector2(300, 300), Color.RED, 5)
						"cue": _puzzle.fx.cue("place")
						"hop": _puzzle._hop(3, 3, -10.0, 0.2)
						"nudge": _puzzle._nudge_neighbours(3, 3)
						"note_move": _puzzle.note_move()
						"celebrate": _puzzle._celebrate(_puzzle.state.line_just_completed(3, 3), 3, 3)
						"after_change": _puzzle._after_change(3, 3)
						"sync_under": _puzzle._sync_under()
				if k == 2:
					print("  part %s %.2f ms" % [name, (Time.get_ticks_usec() - t0) / 10000.0])
	print("experiment ", _exp, " moves left ", _moves.size(), " done ", _puzzle.is_done(), " moves ", _puzzle.moves, " out ", _puzzle.get("out_of_hearts"))

func _all(n: Node, pred: Callable) -> Array:
	var out := []
	for c in n.get_children():
		if pred.call(c):
			out.append(c)
		out.append_array(_all(c, pred))
	return out

## Rings: the solver's own line from the deal, each move a tap lifting the
## top ring off its peg and a tap dropping it on the other, at the middle of
## each station's column.
func _first_liftable() -> int:
	for i in _puzzle._state.pegs.size():
		if _puzzle._state.can_lift(i):
			return i
	return 0

func _moves_rings() -> Array:
	var out := []
	for m: Vector2i in load("res://puzzles/rings_gen.gd").solve(_puzzle._state.pegs):
		for i in [m.x, m.y]:
			out.append({"at": func() -> Vector2:
				var st: Dictionary = _puzzle._station(i)
				return Vector2(float(st["cx"]), float(st["ground"]) - 120.0) * _puzzle._s})
	return out

func _step() -> void:
	# The tutorial is up over the board: a move under it would play the board
	# on (and could solve it out from under the pages).
	if _howto:
		return
	if _moves.is_empty() or _puzzle.is_done() or _puzzle.get("_busy") == true:
		return
	var m: Dictionary = _moves.pop_front()
	if m.has("do"):
		var t1 := Time.get_ticks_usec()
		m.do.call()
		var took1 := (Time.get_ticks_usec() - t1) / 1000.0
		if took1 > 4.0:
			print("  slow move %.1f ms at t=%.2f" % [took1, _t])
		return
	# Positions are asked for at the move, after the board has laid out.
	var t0 := Time.get_ticks_usec()
	_click(m.at.call() if m.at is Callable else m.at)
	var took := (Time.get_ticks_usec() - t0) / 1000.0
	if took > 4.0:
		print("  slow move %.1f ms at t=%.2f" % [took, _t])

## A press and its release at a point in the board's own space, through
## the board's _gui_input as a finger would reach it.
func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		var t0 := Time.get_ticks_usec()
		_puzzle._gui_input(ev)
		if _exp == "parts":
			print("  click %s %.2f ms" % ["down" if pressed else "up", (Time.get_ticks_usec() - t0) / 1000.0])

## `x=buzz`: what the phone did since the last call, under `what`.
func _buzzed(what: String) -> void:
	var all: Array = Haptics.trace
	print("  buzz %-28s %s" % [what, " ".join(all.slice(_buzz_seen)) if all.size() > _buzz_seen else "-"])
	_buzz_seen = all.size()

func _report() -> void:
	print("haptics: ", " ".join(Haptics.trace))
	print("perf %s d=%d nodes=%d" % [_id, _level, root.get_child_count() + _count(root)])
	for w in ["idle", "play"]:
		var f: Array = _windows[w]
		if f.is_empty():
			continue
		var frame: Array[float] = []
		var proc: Array[float] = []
		var cpu: Array[float] = []
		for v: Vector3 in f:
			frame.append(v.x)
			proc.append(v.y)
			cpu.append(v.z)
		print("  %-4s frames=%d frame mean=%.2f p95=%.2f max=%.2f | gpu mean=%.2f max=%.2f | render-cpu mean=%.2f max=%.2f | draws=%d (mean %.0f)" % [
			w, f.size(), _mean(frame), _pct(frame, 0.95), frame.max(),
			_mean(proc), proc.max(), _mean(cpu), cpu.max(), _draws[w], _draw_sum[w] / f.size()])

static func _count(n: Node) -> int:
	var k := 0
	for c in n.get_children():
		k += 1 + _count(c)
	return k

static func _mean(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(1.0, a.size())

static func _pct(a: Array[float], p: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(s.size() * p), 0, s.size() - 1)]

# --- per-board moves: right moves, one a step ---

func _moves_binairo() -> Array:
	var out := []
	for r in _puzzle.n:
		for c in _puzzle.n:
			if _puzzle.state.given[r][c]:
				continue
			var at: Callable = _puzzle.cell_to_local.bind(r, c)
			out.append({"at": at})
			if _puzzle.state.solution[r][c] == 1:
				out.append({"at": at})
	return out

## Binairo's buzzes: a given, a right tile, a tile cleared, a wrong tile (a
## blush on Easy and Medium, a heart on Hard and Insane), Undo, the brush,
## a hint, Check and Reset. The plain run then plays to the win.
func _buzz_binairo() -> void:
	var st = _puzzle.state
	var free: Array = []
	var given := Vector2i(-1, -1)
	for r in _puzzle.n:
		for c in _puzzle.n:
			if not st.given[r][c]:
				free.append(Vector2i(c, r))
			elif given.x < 0:
				given = Vector2i(c, r)
	_click(_puzzle.cell_to_local(given.y, given.x))
	_buzzed("a given touched")
	var pause := func() -> void: await create_timer(0.7).timeout
	# a right tile: a sun is one tap, a moon two
	var a: Vector2i = free[0]
	for i in 1 + int(st.solution[a.y][a.x]):
		_click(_puzzle.cell_to_local(a.y, a.x))
	await pause.call()
	_buzzed("a right tile")
	_host._on_undo()
	await pause.call()
	_buzzed("undo")
	# a wrong one, left to be judged
	var b: Vector2i = free[1]
	for i in 2 - int(st.solution[b.y][b.x]):
		_click(_puzzle.cell_to_local(b.y, b.x))
	await create_timer(1.6).timeout
	_buzzed("a wrong tile, judged")
	if st.grid[b.y][b.x] != -1:
		while st.grid[b.y][b.x] != -1:
			_click(_puzzle.cell_to_local(b.y, b.x))
		await pause.call()
		_buzzed("tapped back to empty")
	_puzzle.set_brush(0)
	await pause.call()
	_buzzed("brush armed")
	_puzzle.set_brush(0)
	await pause.call()
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await pause.call()
		_buzzed("hint")
	_puzzle.check()
	await pause.call()
	_buzzed("check")
	_puzzle.reset_board()
	await pause.call()
	_buzzed("reset")

## Code Break: every row but the last a wrong guess (the code turned by one
## friend, so it scores), then the code as it sits at that moment.
func _moves_mastermind() -> Array:
	var out := []
	var st = _puzzle.state
	# (a seat a hint already filled is skipped: pick takes the first free one)
	for g in st.tries - 1:
		for s in st.length:
			out.append({"do": func() -> void:
				if st.row[s] == -1:
					_puzzle.pick((int(st.code[s]) + 1 + g % (st.palette_size - 1)) % st.palette_size)})
		out.append({"do": func() -> void: _puzzle.check()})
	for s in st.length:
		out.append({"do": func() -> void:
			if st.row[s] == -1:
				_puzzle.pick(int(st.code[s]))})
	out.append({"do": func() -> void: _puzzle.check()})
	return out

## Code Break's buzzes: a friend seated, one sent back, Undo, Check on a
## short row, a palette tap on a full row, Reset, a hint and a tap on the
## hinted seat. The plain run then scores every row and cracks the last
## (the row's knock, a new best, the lids, the seal).
func _buzz_mastermind() -> void:
	var st = _puzzle.state
	_buzz_more = st.tries * 2.0 + 4.0
	var pause := func() -> void: await create_timer(0.8).timeout
	_puzzle.pick(0)
	await pause.call()
	_buzzed("a friend seated")
	_click(_puzzle.cell_to_local(st.active(), 0))
	await pause.call()
	_buzzed("sent back with a tap")
	_puzzle.pick(1)
	await pause.call()
	_buzzed("another seated")
	_host._on_undo()
	await pause.call()
	_buzzed("undo")
	_puzzle.check()
	await pause.call()
	_buzzed("check on a short row")
	for s in st.length:
		_puzzle.pick(s % st.palette_size)
	await pause.call()
	_buzzed("the row filled")
	_puzzle.pick(0)
	await pause.call()
	_buzzed("a tap on a full row")
	_puzzle.reset_board()
	await pause.call()
	_buzzed("reset")
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await pause.call()
		_buzzed("hint")
		for s in st.length:
			if st.locked[s] and st.row[s] != -1:
				_click(_puzzle.cell_to_local(st.active(), s))
		await pause.call()
		_buzzed("the hinted seat tapped")

## Balance: each loose fruit dropped into its answer cup, in the safe order
## (Insane's bales bounce a low side home), through the board's own hop.
func _moves_balance() -> Array:
	var out := []
	var st = _puzzle.state
	var order: Array[int] = []
	if st.boing:
		order = st.safe_order()
	if order.is_empty():
		order.assign(range(st.fruit.size()))
	for f: int in order:
		if not st.loose(f) or st.at[f] == st.answer[f]:
			continue
		out.append({"do": func() -> void:
			# (a hint may have pinned a twin of this fruit in its cup: it
			# takes the twin's)
			var x: int = st.answer[f]
			var o: int = st.occupant(x)
			if o >= 0 and o != f:
				x = st.answer[o]
			if st.place(f, x):
				_puzzle._hop(f, x, 0.0)
				_puzzle._by_hand[f] = true  # the hand's release, for x=buzz
				_puzzle._spend()
				_puzzle.note_move()
				_puzzle._moving = true})
	return out

## A fruit carried from where it is to over cup `x` and let go, through the
## board's own input (two drags a frame apart, so it is let go at rest).
func _bal_carry(f: int, x: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _puzzle.fruit_to_local(f)
	_puzzle._gui_input(ev)
	var over: Vector2 = _puzzle.cup_to_local(x) + Vector2(0.0, -_puzzle.sim.r * 1.5)
	for i in 2:
		await process_frame
		var mv := InputEventMouseMotion.new()
		mv.position = over
		_puzzle._gui_input(mv)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = over
	_puzzle._gui_input(up)

## Balance's buzzes: a pinned fruit touched, a fruit carried to a cup and
## left to settle, tapped home, a toss, Undo, a hint, the sun
## tapped and Reset. On Insane a drop may bounce (the bale's `bad`). The
## plain run then drops every fruit in its cup and ends level.
func _buzz_balance() -> void:
	var st = _puzzle.state
	_buzz_more = 8.0  # (the beam settles before the solve, the seal after)
	var rest := func() -> void: await create_timer(2.6).timeout
	var loose: Array = []
	var pinned := -1
	for f in st.fruit.size():
		if st.loose(f):
			loose.append(f)
		else:
			pinned = f
	if pinned >= 0:
		_click(_puzzle.fruit_to_local(pinned))
		await create_timer(0.6).timeout
		_buzzed("a pinned fruit touched")
	var a: int = loose[0]
	await _bal_carry(a, st.answer[a])
	await create_timer(0.1).timeout
	_buzzed("a fruit lifted and let go")
	await rest.call()
	_buzzed("it lands, the beam rests")
	if st.at[a] != 0:
		_click(_puzzle.fruit_to_local(a))
		await rest.call()
		_buzzed("tapped home")
	var b: int = loose[1]
	# (a toss is a fast let-go far from the cup it lands in, which a free
	# cup under the hand rarely allows: the carry is marked one by hand)
	await _bal_carry(b, st.answer[b])
	_puzzle._tossed[b] = true
	await rest.call()
	_buzzed("a toss that lands")
	if _puzzle.can_undo():
		_host._on_undo()
		await rest.call()
		_buzzed("undo")
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await rest.call()
		_buzzed("hint")
	_click(_puzzle._sun_at())
	await create_timer(0.6).timeout
	_buzzed("the sun tapped")
	_puzzle.reset_board()
	await rest.call()
	_buzzed("reset")

## Untangle: the way home, a peg at a time, carried by hand -- a press, a
## drag in steps over the ropes (the tangle reacts under the hand, which is
## the Insane cost to watch), a release on the hole. A step that finds the
## board busy waits for the next.
func _moves_untangle() -> Array:
	var out := []
	for k in 10:
		out.append({"do": _ut_carry})
	return out

func _ut_carry() -> void:
	if not _puzzle._settled(_puzzle._now()) or _puzzle._now() < _puzzle._busy_until:
		_moves.push_front({"do": _ut_carry})
		return
	var t0 := Time.get_ticks_usec()
	var step: Array = _puzzle.state.hint_step()
	var took := (Time.get_ticks_usec() - t0) / 1000.0
	if took > 4.0:
		print("  hint_step %.1f ms" % took)
	if step.is_empty():
		return
	var p: int = step[0]
	var from: Vector2 = _puzzle._peg_px[p]
	var to: Vector2 = _puzzle._hole_px(int(step[2]))
	var seq := [{"do": func() -> void: _ut_button(from, true)}]
	for i in range(1, 7):
		var at := from.lerp(to, i / 6.0)
		seq.append({"do": func() -> void: _ut_motion(at)})
	seq.append({"do": func() -> void: _ut_button(to, false)})
	seq.reverse()
	for m in seq:
		_moves.push_front(m)

func _ut_button(at: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	_puzzle._gui_input(ev)

func _ut_motion(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_puzzle._gui_input(ev)

## A peg carried from where it is to `to` and let go, through the board's own
## input, an event a frame.
func _ut_carry_to(p: int, to: Vector2) -> void:
	var from: Vector2 = _puzzle._peg_px[p]
	_ut_button(from, true)
	for i in range(1, 7):
		await process_frame
		_ut_motion(from.lerp(to, i / 6.0))
	await process_frame
	_ut_button(to, false)

## Untangle's buzzes: a peg tapped (selected) and tapped again, a rope
## plucked, a peg pulled past its rope's reach and let go, a peg carried the
## way home, Undo, a hint, the kitten petted and Reset. The plain run then
## carries pegs home to the win (or, on a day with thread, as far as the
## thread these moves left goes).
func _buzz_untangle() -> void:
	var st = _puzzle.state
	_buzz_more = 14.0
	var rest := func() -> void: await create_timer(1.2).timeout
	var free := -1
	for p in st.at.size():
		if st.can_go(p):
			free = p
			break
	_click(_puzzle._peg_px[free])
	await create_timer(0.3).timeout
	_buzzed("a peg tapped: selected")
	_click(_puzzle._peg_px[free])
	await create_timer(0.3).timeout
	_buzzed("tapped again: let go")
	var chain: PackedVector2Array = _puzzle._ropes[0].p
	_click(chain[chain.size() / 2])
	await create_timer(0.3).timeout
	_buzzed("a rope plucked")
	# a peg pulled to the far side of the ring from its rope's other end
	for p in st.at.size():
		var other: Vector2 = _puzzle._peg_px[p ^ 1]
		var far: Vector2 = _puzzle._c + (_puzzle._c - other).normalized() * _puzzle._ro
		if st.can_go(p) and far.distance_to(other) > _puzzle._ropes[p >> 1].length * 1.15 \
				and _puzzle._nearest_peg(far) < 0:
			await _ut_carry_to(p, far)
			await create_timer(0.1).timeout
			_buzzed("pulled taut and let go")
			await rest.call()
			_buzzed("it flies home")
			break
	var step: Array = st.hint_step()
	if not step.is_empty():
		await _ut_carry_to(int(step[0]), _puzzle._hole_px(int(step[2])))
		await create_timer(0.1).timeout
		_buzzed("a peg carried and let go")
		await create_timer(2.4).timeout  # (the kitten's swat, on Insane)
		_buzzed("it lands")
	if _puzzle.can_undo():
		_host._on_undo()
		await rest.call()
		_buzzed("undo")
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await create_timer(2.4).timeout
		_buzzed("hint")
	if st.cat:
		_click(_puzzle._kitten.position + _puzzle._kitten.size * 0.5)
		await create_timer(0.4).timeout
		_buzzed("the kitten petted")
	_puzzle.reset_board()
	await create_timer(2.0).timeout
	_buzzed("reset")

## Shikaku: each answer bed dragged by hand, corner to corner -- a press, a
## few motions as the wash grows, the release -- one event a step.
func _moves_shikaku() -> Array:
	_keep = 10
	var out := []
	for rect: Rect2i in _puzzle.state.solution:
		var a := Vector2i(rect.position.y, rect.position.x)
		var b := Vector2i(rect.end.y - 1, rect.end.x - 1)
		out.append({"do": func() -> void: _ut_button(_puzzle.cell_to_local(a.x, a.y), true)})
		for i in range(1, 4):
			var f := i / 3.0
			out.append({"do": func() -> void:
				_ut_motion(_puzzle.cell_to_local(a.x, a.y).lerp(_puzzle.cell_to_local(b.x, b.y), f))})
		out.append({"do": func() -> void: _ut_button(_puzzle.cell_to_local(b.x, b.y), false)})
	return out

## A bed dragged corner to corner through the board's own input, an event a
## frame.
func _sk_drag(rect: Rect2i) -> void:
	var a: Vector2 = _puzzle.cell_to_local(rect.position.y, rect.position.x)
	var b: Vector2 = _puzzle.cell_to_local(rect.end.y - 1, rect.end.x - 1)
	_ut_button(a, true)
	for i in range(1, 4):
		await process_frame
		_ut_motion(a.lerp(b, i / 3.0))
	await process_frame
	_ut_button(b, false)

## Shikaku's buzzes: a tap on bare ground, a bed that fits no sign, a drag
## over it from outside, a tap that clears it, a right bed, Undo, on a board
## with hearts a bed that fits its sign and is not the answer, a hint and a
## press on its pinned bed, Check and Reset. The plain run then drags the
## answer (the streak's confetti, the win, the seal when it is earned).
func _buzz_shikaku() -> void:
	var st = _puzzle.state
	_buzz_more = 8.0
	var pause := func() -> void: await create_timer(0.8).timeout
	var first: Rect2i = st.solution[0]
	_click(_puzzle.cell_to_local(first.position.y, first.position.x))
	await pause.call()
	_buzzed("a tap on bare ground")
	# a two-cell bed in the first answer bed: it fits no sign there
	var stub := Rect2i(first.position, Vector2i(2, 1) if first.size.x >= 2 else Vector2i(1, 2))
	if st.fitted_clue(stub) < 0:
		await _sk_drag(stub)
		await pause.call()
		_buzzed("a bed that fits no sign")
		for other: Rect2i in st.solution:
			if other != first and other.grow(1).intersects(stub):
				# (pressed in the neighbour's far corner, so the stub is not its own)
				var from: Vector2 = _puzzle.cell_to_local(other.end.y - 1, other.end.x - 1)
				var to: Vector2 = _puzzle.cell_to_local(stub.position.y, stub.position.x)
				_ut_button(from, true)
				await process_frame
				_ut_motion(to)
				await process_frame
				_ut_button(to, false)
				await pause.call()
				_buzzed("a drag over it, refused")
				break
		_click(_puzzle.cell_to_local(stub.position.y, stub.position.x))
		await pause.call()
		_buzzed("tapped away")
	await _sk_drag(first)
	await pause.call()
	_buzzed("a right bed")
	_host._on_undo()
	await pause.call()
	_buzzed("undo")
	if _puzzle.max_hearts > 1:
		# a bed that fits its sign and is not the answer
		var wrong := Rect2i()
		for x in st.w:
			for y in st.h:
				for ww in range(1, st.w - x + 1):
					for hh in range(1, st.h - y + 1):
						var r := Rect2i(x, y, ww, hh)
						if wrong.size == Vector2i.ZERO and r.get_area() > 1 and st.fitted_clue(r) >= 0 and not st.is_answer(r):
							wrong = r
		if wrong.size != Vector2i.ZERO:
			await _sk_drag(wrong)
			await create_timer(2.5).timeout
			_buzzed("a bed that costs a heart")
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await pause.call()
		_buzzed("hint")
		for i in st.rects.size():
			if st.locked[i]:
				_click(_puzzle.cell_to_local(st.rects[i].position.y, st.rects[i].position.x))
		await pause.call()
		_buzzed("the pinned bed pressed")
	_puzzle.check()
	await pause.call()
	_buzzed("check")
	_puzzle.reset_board()
	await pause.call()
	_buzzed("reset")

## Tents: every row swept into cairns a run at a time (press, a motion a
## square, release; a run stops at the answer's tents, and a lone square is
## left bare, since a press without a drag would pitch a tent), then the
## answer's tents tapped in, one event a step.
func _moves_tents() -> Array:
	_keep = 2
	var out := []
	var st = _puzzle.state
	var tents: Dictionary = {}
	for t: Vector2i in st.solution:
		tents[t] = true
	for r in st.h:
		var run: Array = []
		for c in st.w + 1:
			var cell := Vector2i(c, r)
			if c < st.w and not tents.has(cell):
				run.append(cell)
				continue
			if run.size() >= 2:
				var cells := run.duplicate()
				out.append({"do": func() -> void: _ut_button(_puzzle.cell_to_local(cells[0].y, cells[0].x), true)})
				for k in range(1, cells.size()):
					var at: Vector2i = cells[k]
					out.append({"do": func() -> void: _ut_motion(_puzzle.cell_to_local(at.y, at.x))})
				var last: Vector2i = cells[cells.size() - 1]
				out.append({"do": func() -> void: _ut_button(_puzzle.cell_to_local(last.y, last.x), false)})
			run = []
	for t: Vector2i in st.solution:
		out.append({"at": _puzzle.cell_to_local.bind(t.y, t.x)})
	return out

## Tents' buzzes: a tree tapped, a tent pitched where the answer has one and
## tapped away, a tent with no tree beside it, a run swept into cairns and
## rubbed out, Undo, on Hard a tent the board cannot fault that is not the
## answer's, a hint and a tap on its pegged tent, Check and Reset. The plain
## run then sweeps the rows and pitches the answer (the oaks, the streak's
## confetti, the win, the seal when it is earned).
func _buzz_tents() -> void:
	var st = _puzzle.state
	_buzz_more = 8.0
	var pause := func() -> void: await create_timer(0.8).timeout
	var at := func(cell: Vector2i) -> Vector2: return _puzzle.cell_to_local(cell.y, cell.x)
	var tree: Vector2i = st.tree_list[0]
	_click(at.call(tree))
	await pause.call()
	_buzzed("a tree tapped")
	var first: Vector2i = st.solution[0]
	_click(at.call(first))
	await create_timer(1.6).timeout
	_buzzed("a right tent")
	_click(at.call(first))
	await pause.call()
	_buzzed("tapped away")
	# two bare squares side by side, neither the answer's nor a tree's
	var run: Array = []
	var lone := Vector2i(-1, -1)
	var wrong := Vector2i(-1, -1)
	for y in st.h:
		for x in st.w:
			var cell := Vector2i(x, y)
			if st.trees.has(cell) or st.solution.has(cell):
				continue
			var beside := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				beside = beside or st.trees.has(cell + d)
			if not beside and lone.x < 0:
				lone = cell
			if beside and wrong.x < 0 and int(st.row_counts[y]) != 0 and int(st.col_counts[x]) != 0:
				wrong = cell
			var next := Vector2i(x + 1, y)
			if run.is_empty() and x + 1 < st.w and not st.trees.has(next) and not st.solution.has(next):
				run = [cell, next]
	if lone.x >= 0:
		_click(at.call(lone))
		await pause.call()
		_buzzed("a tent with no tree by it")
		_click(at.call(lone))
		await pause.call()
	_buzz_seen = Haptics.trace.size()
	if not run.is_empty():
		for k in 2:
			_ut_button(at.call(run[0]), true)
			await process_frame
			_ut_motion(at.call(run[1]))
			await process_frame
			_buzzed("the sweep under the finger")
			_ut_button(at.call(run[1]), false)
			await pause.call()
			_buzzed("two cairns swept" if k == 0 else "and rubbed out")
		_host._on_undo()
		await pause.call()
		_buzzed("undo")
		_host._on_undo()
		await pause.call()
		_buzz_seen = Haptics.trace.size()
	if _puzzle.max_hearts > 1 and wrong.x >= 0:
		_click(at.call(wrong))
		await create_timer(2.5).timeout
		_buzzed("a tent that costs a heart")
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await pause.call()
		_buzzed("hint")
		for cell: Vector2i in st.locked:
			_click(at.call(cell))
		await pause.call()
		_buzzed("the pegged tent tapped")
	_puzzle.check()
	await pause.call()
	_buzzed("check")
	_puzzle.reset_board()
	await pause.call()
	_buzzed("reset")

## Light Up: the answer's lamps tapped in, one tap a step.
func _moves_lightup() -> Array:
	_keep = 2
	var out := []
	for cell: Vector2i in _puzzle.state.solution:
		out.append({"at": _puzzle.cell_to_local.bind(cell.y, cell.x)})
	return out

## Light Up's buzzes: a block tapped, a lamp set where the answer has one
## and tapped away, two lamps in sight of each other, a run swept into chips,
## a chip tapped up, Undo, on Hard a lamp the board cannot fault that is not
## the answer's, a hint and a tap on its pinned lamp, Check and Reset. The
## plain run then taps the answer in (the cats' numbers met, the streak's
## confetti, the win, the seal when it is earned).
func _buzz_lightup() -> void:
	var st = _puzzle.state
	_buzz_more = 8.0
	var pause := func() -> void: await create_timer(0.8).timeout
	var at := func(cell: Vector2i) -> Vector2: return _puzzle.cell_to_local(cell.y, cell.x)
	var block := Vector2i(-1, -1)
	var run: Array = []
	var wrong := Vector2i(-1, -1)
	for y in st.h:
		for x in st.w:
			var cell := Vector2i(x, y)
			if _puzzle._is_block(cell):
				if block.x < 0:
					block = cell
				continue
			if not st.is_white(cell) or st.solution.has(cell):
				continue
			var clear := true
			for d: Vector2i in st.DIRS:
				clear = clear and not _puzzle._is_block(cell + d)
			if clear and wrong.x < 0:
				wrong = cell
			var next := Vector2i(x + 1, y)
			if run.is_empty() and st.is_white(next) and not st.solution.has(next):
				run = [cell, next]
	if block.x >= 0:
		_click(at.call(block))
		await pause.call()
		_buzzed("a block tapped")
	var first: Vector2i = st.solution[0]
	_click(at.call(first))
	await create_timer(1.6).timeout
	_buzzed("a right lamp")
	# (a stone beside it, in its light: the two see each other)
	for d: Vector2i in st.DIRS:
		if st.is_white(first + d):
			_click(at.call(first + d))
			await pause.call()
			_buzzed("a lamp in sight of another")
			_click(at.call(first + d))
			await pause.call()
			_buzz_seen = Haptics.trace.size()
			break
	_click(at.call(first))
	await pause.call()
	_buzzed("tapped away")
	if not run.is_empty():
		_ut_button(at.call(run[0]), true)
		await process_frame
		_ut_motion(at.call(run[1]))
		await process_frame
		_buzzed("the sweep under the finger")
		_ut_button(at.call(run[1]), false)
		await pause.call()
		_buzzed("two chips swept")
		_click(at.call(run[0]))
		await pause.call()
		_buzzed("a chip tapped up")
		_host._on_undo()
		await pause.call()
		_buzzed("undo")
		_host._on_undo()
		await pause.call()
		_buzz_seen = Haptics.trace.size()
	if _puzzle.max_hearts > 1 and wrong.x >= 0:
		_click(at.call(wrong))
		await create_timer(3.0).timeout
		_buzzed("a lamp that costs a heart")
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await pause.call()
		_buzzed("hint")
		for cell: Vector2i in st.locked:
			_click(at.call(cell))
		await pause.call()
		_buzzed("the pinned lamp tapped")
	_puzzle.check()
	await pause.call()
	_buzzed("check")
	_puzzle.reset_board()
	await pause.call()
	_buzzed("reset")

## One Line's buzzes: a post that may not start, the walker set down, a
## line walked by a tap and two by a drag, a walked line refused, Undo, a
## step that leaves no finish (the warn as it strands a line on Easy and
## Medium, a heart on Hard and Insane), a hint, Check and Reset. The plain
## run then draws the planted walk to the win.
func _buzz_oneline() -> void:
	var st = _puzzle.state
	_buzz_more = 8.0
	var pause := func() -> void: await create_timer(0.8).timeout
	var path: Array = st.solution_path()
	for n in st.nodes:
		if not st.may_start(int(n)):
			_click(_puzzle.node_to_local(int(n)))
			await pause.call()
			_buzzed("a post that may not start")
			break
	_click(_puzzle.node_to_local(int(path[0])))
	await pause.call()
	_buzzed("the walker set down")
	_click(_puzzle.node_to_local(int(path[1])))
	await pause.call()
	_buzzed("a line walked")
	if st.edge_between(int(path[0]), int(path[1])) >= 0 and not st.may_step(int(path[0])):
		_click(_puzzle.node_to_local(int(path[0])))
		await pause.call()
		_buzzed("a walked line refused")
	_host._on_undo()
	await pause.call()
	_buzzed("undo")
	_ut_button(_puzzle.node_to_local(int(path[0])), true)
	await process_frame
	_buzz_seen = Haptics.trace.size()
	for k in range(1, mini(3, path.size())):
		_ut_motion(_puzzle.node_to_local(int(path[k])))
		await create_timer(0.3).timeout
	_ut_button(_puzzle.node_to_local(int(path[mini(2, path.size() - 1)])), false)
	await pause.call()
	_buzzed("two lines in one drag")
	# along the planted walk, the first step off it that leaves no finish
	var k := mini(2, path.size() - 1)
	var found := false
	while not found and k < path.size() - 1:
		for q: Dictionary in st.adj.get(st.current, []):
			var to := int(q.to)
			if not st.may_step(to) or st.step_leaves_finish(to):
				continue
			var hearts: int = _puzzle.hearts
			_click(_puzzle.node_to_local(to))
			if _puzzle.max_hearts > 0:
				await create_timer(3.0).timeout
				_buzzed("a step that costs a heart (%d -> %d)" % [hearts, _puzzle.hearts])
				found = true
			elif not st.stranded().is_empty():
				await pause.call()
				_buzzed("a step that strands a line")
				for r: Dictionary in st.adj.get(st.current, []):
					if st.may_step(int(r.to)):
						_click(_puzzle.node_to_local(int(r.to)))
						await pause.call()
						_buzzed("the next step, still stranded")
						_host._on_undo()
						await pause.call()
						break
				_puzzle.check()
				await pause.call()
				_buzzed("check, a line stranded")
				_host._on_undo()
				await pause.call()
				found = true
			else:
				await pause.call()
				_host._on_undo()
				await pause.call()
			_buzz_seen = Haptics.trace.size()
			if found:
				break
		if not found:
			k += 1
			_click(_puzzle.node_to_local(int(path[k])))
			await pause.call()
			_buzz_seen = Haptics.trace.size()
	if not found:
		print("  buzz (no step off the walk loses the figure)")
	if _puzzle.out_of_hearts:
		return
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await create_timer(1.2).timeout
		_buzzed("hint")
	_puzzle.check()
	await pause.call()
	_buzzed("check")
	_puzzle.reset_board()
	await create_timer(1.5).timeout
	_buzzed("reset")

## Nonogram's buzzes: a tile tapped down and tapped away, a run swept, a
## cross, a stroke that brings a line to read right, Undo, a tile the
## picture does not want (it stays on Easy and Medium, a heart on Hard and
## Insane), a hint and its grouted tile tapped, Check and Reset. The plain
## run then sweeps the picture to the win.
func _buzz_nonogram() -> void:
	var st = _puzzle.state
	_buzz_more = 8.0
	var pause := func() -> void: await create_timer(0.8).timeout
	var at := func(cell: Vector2i) -> Vector2: return _puzzle.cell_to_local(cell.y, cell.x)
	# the picture's longest run in a row, and a row it would finish
	var run: Array = []
	var whole: Array = []
	var bare := Vector2i(-1, -1)
	for y in st.h:
		var here: Array = []
		var runs := 0
		for x in st.w + 1:
			if x < st.w and int(st.bitmap[y][x]) == 1:
				here.append(Vector2i(x, y))
				continue
			if x < st.w and bare.x < 0:
				bare = Vector2i(x, y)
			if not here.is_empty():
				runs += 1
				if here.size() > run.size():
					run = here.duplicate()
				if runs == 1 and (st.row_clues[y] as Array).size() == 1 and whole.is_empty():
					whole = here.duplicate()
			here = []
	var first: Vector2i = run[0]
	_click(at.call(first))
	await pause.call()
	_buzzed("a right tile tapped down")
	if st.mark_at(first) == st.FILL and not st.locked.has(first):
		_click(at.call(first))
		await pause.call()
		_buzzed("tapped away")
	_buzz_seen = Haptics.trace.size()
	if not whole.is_empty():
		_ut_button(at.call(whole[0]), true)
		for k in range(1, whole.size()):
			await process_frame
			_ut_motion(at.call(whole[k]))
		await process_frame
		_buzzed("the sweep under the finger")
		_ut_button(at.call(whole[whole.size() - 1]), false)
		await create_timer(1.6).timeout
		_buzzed("a stroke that finishes a row")
		_host._on_undo()
		await pause.call()
		_buzzed("undo")
	if bare.x >= 0 and st.mark_at(bare) == st.BLANK:
		_puzzle.set_brush(st.MARK)
		_buzzed("the cross armed")
		_click(at.call(bare))
		await pause.call()
		_buzzed("a cross")
		_click(at.call(bare))
		await pause.call()
		_buzzed("the cross rubbed out")
		_puzzle.set_brush(st.FILL)
	# a tile the picture does not want, in a row that still wants some
	var wrong := Vector2i(-1, -1)
	for y in st.h:
		for x in st.w:
			var cell := Vector2i(x, y)
			if wrong.x < 0 and int(st.bitmap[y][x]) == 0 and st.mark_at(cell) == st.BLANK \
					and not (st.row_clues[y] as Array).is_empty() and int(st.row_clues[y][0]) > 0:
				wrong = cell
	if wrong.x >= 0:
		var hearts: int = _puzzle.hearts
		_click(at.call(wrong))
		await create_timer(2.5).timeout
		_buzzed("a wrong tile (hearts %d -> %d)" % [hearts, _puzzle.hearts])
		if _puzzle.max_hearts == 0:
			_puzzle.check()
			await pause.call()
			_buzzed("check, a tile wrong")
	if _puzzle.out_of_hearts:
		return
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await pause.call()
		_buzzed("hint")
		for cell: Vector2i in st.locked:
			if st.mark_at(cell) == st.FILL:
				_click(at.call(cell))
				break
		await pause.call()
		_buzzed("the grouted tile tapped")
	if _puzzle.max_hearts > 0:
		_puzzle.check()
		await pause.call()
		_buzzed("check")
	_puzzle.reset_board()
	await create_timer(1.5).timeout
	_buzzed("reset")

## One Line: the planted walk drawn as one drag -- the press on its first
## post, a motion to each next post, the release -- one event a step.
func _moves_oneline() -> Array:
	_keep = 3
	var out := []
	var path: Array = _puzzle.state.solution_path()
	out.append({"do": func() -> void: _ut_button(_puzzle.node_to_local(int(path[0])), true)})
	for k in range(1, path.size()):
		var n := int(path[k])
		out.append({"do": func() -> void: _ut_motion(_puzzle.node_to_local(n))})
	out.append({"do": func() -> void: _ut_button(_puzzle.node_to_local(int(path[-1])), false)})
	return out

## Nonogram: every row's runs of the picture dragged as strokes -- a press
## on its first cell, a motion a cell, the release -- one event a step.
func _moves_nonogram() -> Array:
	_keep = 3
	var out := []
	var st = _puzzle.state
	for y in st.h:
		var run: Array = []
		for x in st.w + 1:
			if x < st.w and int(st.bitmap[y][x]) == 1:
				run.append(Vector2i(x, y))
				continue
			if not run.is_empty():
				var cells := run.duplicate()
				out.append({"do": func() -> void: _ut_button(_puzzle.cell_to_local(cells[0].y, cells[0].x), true)})
				for k in range(1, cells.size()):
					var at: Vector2i = cells[k]
					out.append({"do": func() -> void: _ut_motion(_puzzle.cell_to_local(at.y, at.x))})
				var last: Vector2i = cells[cells.size() - 1]
				out.append({"do": func() -> void: _ut_button(_puzzle.cell_to_local(last.y, last.x), false)})
			run = []
	return out

## Queens: a row's stroke of crosses dragged across it a row at a time (one
## event a step), then every queen of the answer tapped in -- a tap on a
## crossed cell seats her -- so the play has both waves and strokes.
func _moves_queens() -> Array:
	_keep = 2
	var out := []
	var st = _puzzle.state
	var taps := []
	for r in st.n:
		var c := int(st.solution[r])
		if r % 2 == 0:
			out.append({"do": func() -> void: _ut_button(_puzzle.cell_to_local(r, 0), true)})
			for x in range(1, st.n):
				out.append({"do": func() -> void: _ut_motion(_puzzle.cell_to_local(r, x))})
			out.append({"do": func() -> void: _ut_button(_puzzle.cell_to_local(r, st.n - 1), false)})
		else:
			taps.append({"at": _puzzle.cell_to_local.bind(r, c)})
		taps.append({"at": _puzzle.cell_to_local.bind(r, c)})
	out.append_array(taps)
	return out

## Queens' buzzes: a bare cell tapped (a cross), tapped again (a queen), a
## cell she sees tapped, the queen tapped away, two crosses swept and rubbed
## out, Undo, on Hard a queen the answer does not seat there, a hint and a
## tap on its pinned queen, Check and Reset. The plain run then sweeps the
## rows and seats the answer (a misty patch's second queen, the streak's
## confetti, the win, the seal when it is earned).
func _buzz_queens() -> void:
	var st = _puzzle.state
	_buzz_more = 8.0
	var pause := func() -> void: await create_timer(0.8).timeout
	var at := func(cell: Vector2i) -> Vector2: return _puzzle.cell_to_local(cell.y, cell.x)
	var first := Vector2i(int(st.solution[0]), 0)
	_click(at.call(first))
	await pause.call()
	_buzzed("a bare cell tapped: a cross")
	_click(at.call(first))
	await create_timer(1.6).timeout
	_buzzed("tapped again: a queen")
	_click(at.call(Vector2i((first.x + 2) % st.n, 0)))
	await pause.call()
	_buzzed("a cell she sees tapped")
	_click(at.call(first))
	await pause.call()
	_buzzed("the queen tapped away")
	var run := [Vector2i(0, st.n - 1), Vector2i(1, st.n - 1)]
	for k in 2:
		_ut_button(at.call(run[0]), true)
		await process_frame
		_ut_motion(at.call(run[1]))
		await process_frame
		_buzzed("the sweep under the finger")
		_ut_button(at.call(run[1]), false)
		await pause.call()
		_buzzed("two crosses swept" if k == 0 else "and rubbed out")
	_host._on_undo()
	await pause.call()
	_buzzed("undo")
	_host._on_undo()
	await pause.call()
	_buzz_seen = Haptics.trace.size()
	if _puzzle.max_hearts > 1:
		var wrong := Vector2i((int(st.solution[st.n - 1]) + 1) % st.n, st.n - 1)
		_click(at.call(wrong))
		await pause.call()
		_buzz_seen = Haptics.trace.size()
		_click(at.call(wrong))
		await create_timer(3.0).timeout
		_buzzed("a queen that costs a heart")
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await create_timer(1.6).timeout
		_buzzed("hint")
		for cell: Vector2i in st.locked:
			_click(at.call(cell))
		await pause.call()
		_buzzed("the pinned queen tapped")
	_puzzle.check()
	await pause.call()
	_buzzed("check")
	_puzzle.reset_board()
	await pause.call()
	_buzzed("reset")

## Hidden Word: five wrong guesses that keep every clue the rows before them
## gave (so Hard's and Insane's clue rule never refuses them), then the
## answer, each typed a letter a step and committed -- a commit waits while
## the row before it is still turning, as a player would.
func _moves_hiddenword() -> Array:
	_keep = 6
	var out := []
	var st = _puzzle.state
	var rows: Array[String] = []
	var marks: Array = []
	var words: Array = st._accept.keys()
	words.sort()
	var k := 0
	while rows.size() < st.tries - 1:
		var w := ""
		while k < words.size():
			var cand := String(words[(k * 7919) % words.size()])
			k += 1
			if cand != st.answer and not rows.has(cand) and _hw_keeps(cand, rows, marks):
				w = cand
				break
		if w == "":
			break
		rows.append(w)
		marks.append(st.mark_guess(w, st.answer))
	rows.append(st.answer)
	for w in rows:
		for i in w.length():
			var ch := w[i]
			out.append({"do": func() -> void: _puzzle.type_letter(ch)})
		out.append({"do": _hw_commit})
	return out

## Hidden Word's buzzes: a letter typed, a bed of the row tapped, a letter
## erased, Enter on a short row and on five letters that are no word, a
## hint, Reset, then the plain run's first wrong word typed and entered (the
## row's one knock as it lands, and its word if it earns one). The plain run
## plays the rest: the rows' words, the win, the seal.
func _buzz_hiddenword() -> void:
	_buzz_more = 25.0
	var pause := func() -> void: await create_timer(0.8).timeout
	_puzzle.type_letter("q")
	await pause.call()
	_buzzed("a letter typed")
	_puzzle.type_letter("x")
	await pause.call()
	_buzz_seen = Haptics.trace.size()
	_click(_puzzle._tile_at(_puzzle.state.rows.size(), 3) + Vector2.ONE * _puzzle._cell() * 0.5)
	await pause.call()
	_buzzed("a bed tapped: the caret")
	_puzzle.erase_letter()
	await pause.call()
	_buzzed("a letter erased")
	_puzzle.commit_row()
	await pause.call()
	_buzzed("enter on a short row")
	_puzzle.reset_board()
	await pause.call()
	_buzzed("reset")
	for ch in "qxzjq":
		_puzzle.type_letter(ch)
		await process_frame
		await process_frame
	await pause.call()
	_buzzed("five letters, the row ready")
	_puzzle.commit_row()
	await pause.call()
	_buzzed("enter on no word")
	for i in 5:
		_puzzle.erase_letter()
		await create_timer(0.1).timeout
	_buzz_seen = Haptics.trace.size()
	if _puzzle.hints_left() > 0:
		_puzzle.hint()
		await pause.call()
		_buzzed("hint")
	for i in 5:
		(_moves.pop_front().do as Callable).call()
		await create_timer(0.1).timeout
	_buzz_seen = Haptics.trace.size()
	_puzzle.commit_row()
	await create_timer(0.5).timeout
	_buzzed("enter: the row turning")
	_moves.pop_front()
	await create_timer(3.0).timeout
	_buzzed("the row landed")

func _hw_commit() -> void:
	if _puzzle.busy():
		_moves.push_front({"do": _hw_commit})
		return
	_puzzle.commit_row()

## The clue rule against every row, delivered or not (a word that keeps them
## all keeps any fewer).
func _hw_keeps(w: String, rows: Array[String], marks: Array) -> bool:
	for r in rows.size():
		var need: Dictionary = {}
		for i in 5:
			if int(marks[r][i]) == 0 and w[i] != rows[r][i]:
				return false
			if int(marks[r][i]) != 2:
				need[rows[r][i]] = int(need.get(rows[r][i], 0)) + 1
		for ch in need:
			if w.count(ch) < int(need[ch]):
				return false
	return true

## Word Trail: every word traced along its own path -- a press on its first
## tile, a motion a tile, the release -- one event a step.
func _moves_wordtrail() -> Array:
	var out := []
	var words: Array = _puzzle._state.words
	for w in words:
		var path: Array = w["path"]
		out.append({"do": func() -> void: _ut_button(_puzzle._centre(path[0]), true)})
		for k in range(1, path.size()):
			var at: Vector2i = path[k]
			out.append({"do": func() -> void: _ut_motion(_puzzle._centre(at))})
		out.append({"do": func() -> void: _ut_button(_puzzle._centre(path[-1]), false)})
	_keep = (words[-1]["path"] as Array).size() + 1
	return out

## Mushroom Patch: a row at a time, a pebble tapped on every bare cell of it,
## then its mushrooms planted, the chip switched as a player would.
func _moves_mushroom() -> Array:
	_keep = 2
	var out := []
	var st = _puzzle.state
	for r in st.n:
		var safe := []
		var shrooms := []
		for c in st.n:
			var cell := Vector2i(c, r)
			if st.given.has(cell):
				continue
			(shrooms if st.mushrooms.has(cell) else safe).append(cell)
		if not safe.is_empty():
			out.append({"do": func() -> void: _puzzle.set_brush(st.CLEAR)})
			for cell: Vector2i in safe:
				out.append({"at": _puzzle.cell_to_local.bind(cell.y, cell.x)})
		if not shrooms.is_empty():
			out.append({"do": func() -> void: _puzzle.set_brush(st.FOUND)})
			for cell: Vector2i in shrooms:
				out.append({"at": _puzzle.cell_to_local.bind(cell.y, cell.x)})
	return out

## Sudoku: every empty cell in reading order, tapped (it only selects) and
## then its answer's chip picked, as a player would.
func _moves_sudoku() -> Array:
	_keep = 4
	var out := []
	var st = _puzzle.state
	for i in st.sol.size():
		if st.grid[i] != 0:
			continue
		var n: int = _puzzle.Gen.N
		out.append({"at": _puzzle.cell_to_local.bind(i / n, i % n)})
		var d: int = int(st.sol[i]) - 1
		out.append({"do": func() -> void: _puzzle.pick(d)})
	return out

## Bridges: every plank of the answer, a drag from one islet to the other
## (a press on the islet, a motion over the far one, the release), run by run
## in the answer's order.
func _moves_bridges() -> Array:
	var out := []
	var st = _puzzle.state
	for key in st.answer:
		for k in int(st.answer[key]):
			out.append({"do": _br_drag.bind(String(key))})
	return out

func _br_drag(key: String) -> void:
	var lane: Dictionary = _puzzle.state.lanes[key]
	var a: Vector2 = _puzzle._at(lane.a)
	var b: Vector2 = _puzzle._at(lane.b)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = a
	_puzzle._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = b
	_puzzle._gui_input(drag)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = b
	_puzzle._gui_input(up)

## Quilt: every answer patch carried from its bay to its spot by hand -- a
## press on its first cell, motions across in steps (the ghost, the snag and
## the sway under the hand are the cost to watch), the release over the
## spot -- one event a step.
func _moves_quilt() -> Array:
	_keep = 8
	var out := []
	var st = _puzzle._state
	for p in st.shapes.size():
		if int(st.answer[p]) < 0:
			continue
		out.append({"do": _ql_press.bind(p)})
		for i in range(1, 6):
			out.append({"do": _ql_move.bind(p, i / 5.0)})
		out.append({"do": _ql_release.bind(p)})
	return out

func _ql_from(p: int) -> Vector2:
	var c: Vector2i = _puzzle._state.shapes[p][0]
	return _puzzle._bay_home(p) + (Vector2(c) + Vector2(0.5, 0.5)) * _puzzle._rack_cell()

func _ql_to(p: int) -> Vector2:
	var c: Vector2i = _puzzle._state.shapes[p][0]
	return _puzzle._corner_of(int(_puzzle._state.answer[p])) \
		+ (Vector2(c) + Vector2(0.5, 0.5 + _puzzle.HOLD_LIFT)) * _puzzle._cell()

func _ql_press(p: int) -> void:
	if int(_puzzle._state.at[p]) >= 0:
		return
	_ut_button(_ql_from(p), true)

func _ql_move(p: int, f: float) -> void:
	_ut_motion(_ql_from(p).lerp(_ql_to(p), f))

func _ql_release(p: int) -> void:
	_ut_button(_ql_to(p), false)

## Fairy Lights: every piece tapped round to its answer in reading order, a
## tap a step (never past the answer, which on a judged garden is a fuse).
func _moves_fairylights() -> Array:
	var out := []
	var st = _puzzle.state
	for i in st.n * st.n:
		if st.pinned[i] == 1:
			continue
		var at: Callable = _puzzle.cell_centre.bind(i)
		for q in _puzzle._quarters(st.grid[i], st.sol[i]):
			out.append({"at": at})
	return out

## Paper Planes: the deal's own launch order (on a Windy Day sky the one
## order known to replay without a gust), each plane tapped on its head
## cell, a tap a step.
func _moves_planes() -> Array:
	var out := []
	var st = _puzzle._state
	for i in st.solve_order():
		out.append({"at": _pp_head.bind(i)})
	return out

func _pp_head(i: int) -> Vector2:
	var cells: Array = _puzzle._state.planes[i]["cells"]
	var c: Vector2i = cells[cells.size() - 1]
	return _puzzle.cell_to_local(c.y, c.x)

## Pinwheel: every wrong piece tapped round to its answer, roots of the
## ribbons first (a tap tugs only what hangs below it), worked out on a copy
## of where the pieces lie so the list is exactly the taps that solve it.
func _moves_pinwheel() -> Array:
	var out := []
	var st = _puzzle._state
	var keep: PackedInt32Array = st.turned.duplicate()
	var order: Array = []
	var seen := {}
	var parent := {}
	for p in st._kids.size():
		for k: Array in (st._kids[p] as Array):
			parent[int(k[0])] = p
	var queue: Array = []
	for p in st.shapes.size():
		if not parent.has(p):
			queue.append(p)
	while not queue.is_empty():
		var p: int = queue.pop_front()
		if seen.has(p):
			continue
		seen[p] = true
		order.append(p)
		if p < st._kids.size():
			for k: Array in (st._kids[p] as Array):
				queue.append(int(k[0]))
	for p: int in order:
		if st.fixed(p) or st.is_tacked(p):
			continue
		var guard := 0
		while st.steps_home(p) > 0 and guard < 8:
			guard += 1
			out.append({"at": _puzzle._pin_point.bind(p)})
			for pull: Array in st.tugged(p):
				var q := int(pull[0])
				st.turned[q] = posmod(int(st.turned[q]) + int(pull[1]), (st.shapes[q] as Array).size())
	st.turned = keep
	return out

## Caterpillar: the answer's walk drawn as one drag -- a press on its first
## square, a motion a square, the release -- one event a step (`_keep` 3).
func _moves_caterpillar() -> Array:
	_keep = 3
	var out := []
	var path: PackedInt32Array = _puzzle._state.path
	var cols: int = _puzzle._state.cols
	var at := func(c: int) -> Vector2: return _puzzle.cell_to_local(c / cols, c % cols)
	out.append({"do": func() -> void: _ut_button(at.call(path[0]), true)})
	for k in range(1, path.size()):
		var c := int(path[k])
		out.append({"do": func() -> void: _ut_motion(at.call(c))})
	out.append({"do": func() -> void: _ut_button(at.call(path[-1]), false)})
	return out

## Knight: the shortest line from the opening (the rose side answers by a
## fixed rule, so it is the whole game), a tap a hop on the square; a hop
## waits, put back at the front, while the last one still plays out.
func _moves_knight() -> Array:
	var st = _puzzle._state
	var Gen = load("res://puzzles/knight_gen.gd")
	var line: PackedInt32Array = Gen.solve(st.g, st.you, st.foes, 64, 0, st.mask)
	var out := []
	for c: int in line:
		var m := {}
		m["do"] = func() -> void:
			if _puzzle.busy():
				_moves.push_front(m)
				return
			_click(_puzzle.cell_to_local(c / st.w, c % st.w))
		out.append(m)
	return out

## Sunbeam: every piece dragged home along its rail -- a press on it, a
## motion a third of a peg, the release on its home peg -- in an order
## worked out on a copy of the floor so no let-go move leaves the light on a
## sleeper (Hard's snails, Shy Dew's drops) unless it is the solve. One event
## a step (`_keep` the last two drags' events).
func _moves_sunbeam() -> Array:
	var st = _puzzle._state
	var order: Array = _sb_dark_way(st) if not st.sleepers().is_empty() else []
	if order.is_empty():
		order = _sb_greedy(st)
	var out := []
	var counts: Array = []
	for mv: Array in order:
		var p: int = mv[0]
		var a := float(mv[1])
		var z := float(mv[2])
		var at := func(s: float) -> Vector2: return _puzzle._pt(_puzzle._piece_mid(p, s))
		out.append({"do": func() -> void: _ut_button(at.call(a), true)})
		var n := maxi(1, int(ceil(absf(z - a) * 3.0)))
		for k in range(1, n + 1):
			var s := lerpf(a, z, float(k) / float(n))
			out.append({"do": func() -> void: _ut_motion(at.call(s))})
		out.append({"do": func() -> void: _ut_button(at.call(z), false)})
		counts.append(n + 2)
	_keep = 0
	for k in mini(2, counts.size()):
		_keep += int(counts[counts.size() - 1 - k])
	return out

## A greedy order home: each piece in turn whose move home is free and
## leaves the light off every sleeper, [piece, from, to] each.
func _sb_greedy(st) -> Array:
	var Gen = load("res://puzzles/sunbeam_gen.gd")
	var pos: PackedInt32Array = st.pos.duplicate()
	var order: Array = []
	var left: Array = range(pos.size()).filter(func(p): return pos[p] != st.home(p))
	var guard := 0
	while not left.is_empty() and guard < 64:
		guard += 1
		var pick := -1
		for p: int in left:
			var free := true
			for o in pos.size():
				if o != p:
					for c in st.cells_of(o, pos[o]):
						if st.cells_of(p, st.home(p)).has(c):
							free = false
			if not free:
				continue
			pick = p
			break
		if pick < 0:
			pick = left[0]
		order.append([pick, pos[pick], st.home(pick)])
		pos[pick] = st.home(pick)
		left.erase(pick)
	return order

## The shortest way home that never lets go with the light on a sleeper
## (sunbeam_gen.gd's dark_path, keeping the moves): [piece, from, to] each.
func _sb_dark_way(st) -> Array:
	var Gen = load("res://puzzles/sunbeam_gen.gd")
	var g: Dictionary = st.g
	var f = Gen.Fast.new(g, st.sleepers())
	var np: int = f.np
	var mul := PackedInt32Array()
	var total := 1
	for p in np:
		mul.append(total)
		total *= f.rails[p]
	var home := 0
	var at := 0
	for p in np:
		home += int(g.pieces[p].home) * mul[p]
		at += st.pos[p] * mul[p]
	var parent := {at: -1}
	var queue := PackedInt32Array([at])
	var head := 0
	var pos := PackedInt32Array()
	pos.resize(np)
	var found := false
	while head < queue.size() and not found:
		var s := queue[head]
		head += 1
		for p in np:
			pos[p] = (s / mul[p]) % f.rails[p]
		for p in np:
			var was: int = pos[p]
			for q in f.rails[p]:
				if q == was or not f.fits(pos, p, q):
					continue
				var t: int = s + (q - was) * mul[p]
				if parent.has(t):
					continue
				if t == home:
					parent[t] = s
					found = true
					break
				pos[p] = q
				var r: Vector2i = f.probe(pos)
				pos[p] = was
				if r.x == 0 and r.y == 0:
					parent[t] = s
					queue.append(t)
			if found:
				break
	if not found:
		return []
	var chain: Array = []
	var k := home
	while k != at:
		chain.push_front(k)
		k = parent[k]
	chain.push_front(at)
	var out: Array = []
	for i in range(1, chain.size()):
		for p in np:
			var a: int = (int(chain[i - 1]) / mul[p]) % f.rails[p]
			var z: int = (int(chain[i]) / mul[p]) % f.rails[p]
			if a != z:
				out.append([p, a, z])
	return out

## Hedgehogs: the lawn cleared in reading order, each move the first cell
## still to do -- a sleeping hedgehog flagged (the flag chip armed for the
## tap) or a bare pile raked -- picked at the move, since on Sleepwalkers the
## hedgehogs walk. Waits while a wake or a walk holds input. After each move
## the list is cut to what a copy of the lawn still needs (floods clear cells
## for free, and a walk changes the numbers), so `fill` leaves two.
func _moves_hedgehogs() -> Array:
	var m := {}
	m["do"] = func() -> void:
		var st = _puzzle._state
		if _puzzle.busy():
			_moves.push_front(m)
			return
		for c in st.size():
			if st.open[c] == 1 or st.woke[c] == 1:
				continue
			if st.is_hog(c):
				if st.flag[c] == 1:
					continue
				_puzzle.set_brush(st.FLAG)
				_click(_puzzle.cell_to_local(c / st.cols(), c % st.cols()))
				_puzzle.set_brush(st.RAKE)
			else:
				_click(_puzzle.cell_to_local(c / st.cols(), c % st.cols()))
			break
		var left := _hh_need()
		_moves.clear()
		for k in left:
			_moves.append(m)
	var out := []
	for k in _hh_need():
		out.append(m)
	return out

func _hh_need() -> int:
	var st = _puzzle._state
	var Gen = load("res://puzzles/hedgehogs_gen.gd")
	var open: PackedByteArray = st.open.duplicate()
	# Moves up to the last rake: a flag after it would come once the lawn is
	# already done.
	var n := 0
	var upto := 0
	for c in st.size():
		if st.is_hog(c):
			if st.flag[c] == 0 and st.woke[c] == 0:
				n += 1
		elif open[c] == 0:
			Gen.flood(st.g, open, c)
			n += 1
			upto = n
	return upto

## Drumbeat's: no moves a step -- a song is played on the frame. A stroke
## starts the song as the play window opens, then every berry is struck on
## its drum as it reaches the ring, a ribbon held to its end, a golden bar
## rolled at twelve a second (`tests/_shot_drumbeat.gd`'s bot). `to=38` plays
## a whole song through the win.
var _db_next := 0.0
var _tr_logged := false
var _tr_hooked := false
var _tr_start := 0
var _tr_pre := 0
var _tr_post := 0
var _db_looks := 0
var _db_struck := {}
var _db_roll := -10.0

func _db_bot() -> void:
	var b = _puzzle
	if _exp == "db_hud":
		# the experiment starts, pauses and goes on by its own strokes
		if b._phase != "play":
			return
	elif b._phase == "paused":
		b._pause(false)
	if b._phase == "ready":
		if not _db_struck.has(-1):
			_db_struck[-1] = true
			b.strike(0)
		return
	if b._phase != "play":
		return
	const DbState = preload("res://puzzles/drumbeat_state.gd")
	var st = b._st
	var vt: float = b.view_t()
	for i in st.notes.size():
		var n: Dictionary = st.notes[i]
		if float(n.t) > vt + 0.01:
			break
		if DbState.is_long(n.type):
			if vt <= float(n.end) and n.st == DbState.St.WAIT and vt - _db_roll >= 1.0 / 12.0:
				_db_roll = vt
				b.strike(int(n.lane))
			continue
		if n.type == DbState.Type.HOLD and n.held and vt >= float(n.end):
			b._lift(int(n.lane))
			continue
		if _db_struck.has(i) or n.st != DbState.St.WAIT:
			continue
		_db_struck[i] = true
		b.strike(int(n.lane))

## Marigold's: a shot a move, the aim set to the angle and the seed shot:
## Sweethearts plays its banked proof from the opening, the other
## bands the sun's own best line (a third of a second each, the probe's cost).
func _moves_marigold() -> Array:
	if _exp == "mg_hud":
		return []
	var plan := {}
	plan["do"] = func() -> void:
		if _puzzle.is_done():
			return
		_moves.push_front(plan)
		if _puzzle.busy() or _puzzle._phase != "aim":
			return
		var st = _puzzle._state
		var a: float
		if st.sweethearts and st.tries == 1 and st.shots < st.proof.size():
			a = float(st.proof[st.shots])
		else:
			a = st.clone().best_angle()
		# a press and release turns the aim to a pixel; the proof is chaotic
		# and needs the angle exact, so the aim is set and the seed shot
		_puzzle._aim = a
		_puzzle._shoot()
	_keep = 0
	return [plan]

## Pixel Garden: the picture copied row by row, a stroke a run of one
## colour -- the chip picked when the colour changes, a press on the run's
## first peg, a motion a peg at a time, the release -- one event a step, so
## the play window holds real strokes and plates being ironed.
func _moves_pixelgarden() -> Array:
	if _exp == "pg_hud":
		return []
	var plan := {}
	plan["do"] = func() -> void:
		var st = _puzzle._state
		var n: int = st.n
		var at := func(c: int) -> Vector2:
			return _puzzle.cell_to_local(c / n, c % n)
		var held := -1
		var counts: Array = []
		for r in n:
			var x := 0
			while x < n:
				var k: int = st.want[r * n + x]
				if k == st.EMPTY:
					x += 1
					continue
				var run: Array = []
				while x < n and st.want[r * n + x] == k:
					run.append(r * n + x)
					x += 1
				var steps := 0
				if k != held:
					held = k
					var chip: int = k
					_moves.append({"do": func() -> void: _click(_puzzle.chip_to_local(chip))})
					steps += 1
				var first: int = run[0]
				_moves.append({"do": func() -> void: _ut_button(at.call(first), true)})
				for i in range(1, run.size()):
					var c: int = run[i]
					_moves.append({"do": func() -> void: _ut_motion(at.call(c))})
				var last: int = run[run.size() - 1]
				_moves.append({"do": func() -> void: _ut_button(at.call(last), false)})
				counts.append(steps + run.size() + 1)
		_keep = 0
		for k in mini(2, counts.size()):
			_keep += int(counts[counts.size() - 1 - k])
	_keep = 0
	return [plan]

## Super Slider: the shortest way out, each move a drag through the board's
## own input -- a press on the block, a motion a cell at a time along the
## way it slides, the release -- one event a step, so the play window holds
## real drags. The line is worked out once the solver is done (on a copy:
## hint moves played and the tray put back).
func _moves_slider() -> Array:
	var plan := {}
	plan["do"] = func() -> void:
		var st = _puzzle._state
		if not st.solver_ready() or _puzzle.busy():
			_moves.push_front(plan)
			return
		var keep: Array = st.snapshot()
		var hist: int = st.history.size()
		var line: Array = []
		for i in 400:
			var m: Dictionary = st.hint_move()
			if m.is_empty():
				break
			line.append([int(m.p), m.path])
			st.play(m.p, m.to)
		st._restore(keep)
		st.history.resize(hist)
		var counts: Array = []
		var Gen = load("res://puzzles/slider_gen.gd")
		for mv: Array in line:
			var path: PackedInt32Array = mv[1]
			var at := func(c: int) -> Vector2:
				return _puzzle._pt(Vector2(c % Gen.COLS, c / Gen.COLS) + Vector2(0.5, 0.5))
			_moves.append({"do": func() -> void: _ut_button(at.call(path[0]), true)})
			for k in range(1, path.size()):
				var c: int = path[k]
				_moves.append({"do": func() -> void: _ut_motion(at.call(c))})
			_moves.append({"do": func() -> void: _ut_button(at.call(path[path.size() - 1]), false)})
			counts.append(path.size() + 1)
		_keep = 0
		for k in mini(2, counts.size()):
			_keep += int(counts[counts.size() - 1 - k])
	_keep = 0
	return [plan]

## Trestle: the day's proof laid a member a move, each a drag from one end
## to the other through the board's own input (the chip picked first when
## the material changes), then Go -- so the play window holds the building,
## the whole test (the sim stepped on the frame, the bridge drawn bent) and,
## past `to=30`, the win. `fill` leaves only Go, so the idle window is the
## whole bridge standing.
func _moves_trestle() -> Array:
	if _exp == "tr_hud":
		return []
	var out := []
	for p: Dictionary in _puzzle.state.proof:
		out.append({"do": _tr_lay.bind(p.a, p.b, int(p.m))})
	out.append({"do": func() -> void: _host._on_check()})
	_keep = 1
	return out

func _tr_lay(a: Vector2i, b: Vector2i, m: int) -> void:
	if _puzzle._mat != m:
		_click(_puzzle.chip_to_local(m))
	_ut_button(_puzzle.point_to_local(a), true)
	_ut_motion(_puzzle.point_to_local(b))
	_ut_button(_puzzle.point_to_local(b), false)
