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

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "howto":
			_howto = true
		elif a == "rm":
			_rm = true
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
			print("  diagram size ", c0._diagram.size, " slot ", c0._diagram_slot.size, " caption ", c0._diagram._caption.position, " ", c0._diagram._caption.size)
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
	if _t >= _play_to:
		_report()
		quit()
		return true
	return false

func _open() -> void:
	_opened = true
	if _rm:
		load("res://core/motion.gd").reduce = true
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
		"undo":
			var m: Dictionary = _moves[0]
			_click(m.at.call())
			var cell: Vector2i = _puzzle._cell_at(m.at.call())
			var before: int = _puzzle.state.grid[cell.y][cell.x]
			print("  undo visible=", _host.top_bar.undo_button.visible, " enabled=", _puzzle.can_undo())
			_host._on_undo()
			print("  cell ", cell, " after tap=", before, " after undo=", _puzzle.state.grid[cell.y][cell.x], " hearts=", _puzzle.hearts)
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
	print("experiment ", _exp, " moves left ", _moves.size(), " done ", _puzzle.is_done(), " moves ", _puzzle.moves, " out ", _puzzle.out_of_hearts)

func _all(n: Node, pred: Callable) -> Array:
	var out := []
	for c in n.get_children():
		if pred.call(c):
			out.append(c)
		out.append_array(_all(c, pred))
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

func _report() -> void:
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

## Code Break: every row but the last a wrong guess (the code turned by one
## friend, so it scores), then the code as it sits at that moment.
func _moves_mastermind() -> Array:
	var out := []
	var st = _puzzle.state
	for g in st.tries - 1:
		for s in st.length:
			out.append({"do": func() -> void: _puzzle.pick((int(st.code[s]) + 1 + g % (st.palette_size - 1)) % st.palette_size)})
		out.append({"do": func() -> void: _puzzle.check()})
	for s in st.length:
		out.append({"do": func() -> void: _puzzle.pick(int(st.code[s]))})
	out.append({"do": func() -> void: _puzzle.check()})
	return out

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
			if st.place(f, st.answer[f]):
				_puzzle._hop(f, st.answer[f], 0.0)
				_puzzle._spend()
				_puzzle.note_move()
				_puzzle._moving = true})
	return out

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

## Light Up: the answer's lamps tapped in, one tap a step.
func _moves_lightup() -> Array:
	_keep = 2
	var out := []
	for cell: Vector2i in _puzzle.state.solution:
		out.append({"at": _puzzle.cell_to_local.bind(cell.y, cell.x)})
	return out

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
