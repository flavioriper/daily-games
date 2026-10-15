extends Control

## Tally's paper under the fingers: the screen's world and the tutorial's
## pages alike (arcade/tally_screen.gd, ui/hud/tally_tutorial_diagram.gd).
## It shows the sim (arcade/tally_sim.gd), takes the touch and calls the
## sim; the owner drains the sim's events and hands each to `play`.
##
## **The view** is a camera over the paper: `cam` the square at the view's
## middle, `k` pixels a square. Two fingers pan and pinch whatever tool is
## in hand; the wheel zooms on a desk. `area` is where the paper shows (the
## whole screen: the world fills it) and `view` the part the chrome leaves
## open, whose middle the camera looks at.
##
## **The tools** under one finger (`tool`): "move" pans and a tap asks about
## a piece; "belt" lays a straight run in the way of the swipe, shown as a
## ghost until the finger lifts, and a tap lays one belt or turns one;
## "remove" lifts what the finger crosses; a machine's tool (and "dig",
## "crate") places on a tap facing `place_face`, turns its own kind on a
## second tap, and pans on a drag.
##
## **The drawing**, all under one transform (`_world`), in a few meshes: the
## desk and the paper with its printed numbers (built once, again when a
## number opens); the belts' beds (again when the belts change); brass
## chevrons, the tokens, the pieces and a live layer of rings and ghosts
## (every frame, only what is in sight). The numerals are written in screen
## space by one layer (`_words`), each size a run of glyphs.

signal refused(why: String, at: Vector2, n: int)
signal touched(pitch: float)
signal asked(t: Vector2i)
signal box_asked

const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

const U := Art.U
## The desk shown round the paper, in squares.
const RIM := 3.0
const SLOP := 14.0
## The zoom: the default pixels a square and the closest.
const K_START := 74.0
const K_MOST := 160.0
const WHEEL := 1.12
const EASE := 12.0
const FLING := 0.2
## A finger this near the view's edge while laying or lifting moves the view.
const EDGE := 70.0
const EDGE_SPEED := 9.0
## How long a piece set down, a belt laid, a turn and a squash take.
const POP := 0.26
const SPIN := 0.16
const SQUASH := 0.22
const GONE := 0.22
## A numeral smaller than this many pixels is not written.
const FS_MIN := 8
const TOOL_KINDS := {"belt": Sim.BELT, "dig": Sim.DIG, "crate": Sim.CRATE, "add": Sim.ADD, "mul": Sim.MUL, "sub": Sim.SUB, "div": Sim.DIV, "pow": Sim.POW}

var sim: RefCounted
var tool := "move"
var place_face := 0
var belt_face := 0
var interactive := true
var view := Rect2()
var cam := Vector2(Sim.HUB_AT) + Vector2(Sim.HUB, Sim.HUB) * 0.5
var k := K_START
var font: Font

var _world: Node2D
var _layers := {}
var _words: Node2D
var _paper: ArrayMesh
var _prints: ArrayMesh
var _beds: ArrayMesh
var _decks: ArrayMesh
var _live := {}
var _flat_cache := {}
var _dirty := true
var _printed_at := -1
var _clock := 0.0
var _phase := 0.0
var _ins := {}

# fingers
var _touch := {}
var _last := {}
var _gesture := false
var _finger := -99
var _start := Vector2.ZERO
var _at := Vector2.ZERO
var _moved := false
var _run := {}
var _lifted := {}
var _vel := Vector2.ZERO
var _moved_at := 0
var _cam_to := Vector2.INF

# moments
var _pop := {}       # square -> when
var _spin := {}      # square -> [when, from face]
var _squash := {}    # square -> when
var _gone: Array = [] # [kind, face, square, when]
var _box_bump := -10.0
var _box_glow := -10.0
var _shown_got := 0
var _shown_target := 0

## The desk under everything, past the paper's own rim of it.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Art.DESK)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if font == null:
		font = CozyTheme.display(700)
	_world = Node2D.new()
	_world.name = "Paper"
	add_child(_world)
	for nm in ["ground", "beds", "chev", "under", "decks", "tokens", "pieces", "live"]:
		var l := Node2D.new()
		l.name = nm
		_world.add_child(l)
		RenderingServer.canvas_item_set_custom_rect(l.get_canvas_item(), true, Rect2(-1e6, -1e6, 2e6, 2e6))
		l.draw.connect(_draw_layer.bind(nm, l))
		_layers[nm] = l
	_words = Node2D.new()
	_words.name = "Words"
	add_child(_words)
	_words.draw.connect(_draw_words)
	resized.connect(_on_resized)

func _on_resized() -> void:
	queue_redraw()
	if view.size == Vector2.ZERO:
		view = Rect2(Vector2.ZERO, size)
	_clamp_k()
	_place()

## Where the chrome leaves the paper open, in this Control's pixels.
func set_view(r: Rect2) -> void:
	view = r
	_clamp_k()
	_place()

func k_least() -> float:
	return maxf(14.0, size.x / (Sim.W + RIM))

func _clamp_k() -> void:
	k = clampf(k, k_least(), K_MOST)

func _place() -> void:
	if _world == null:
		return
	cam = cam.clamp(Vector2.ZERO, Vector2(Sim.W, Sim.H))
	_world.scale = Vector2(k / U, k / U)
	_world.position = view.get_center() - cam * k

## A point of the paper in squares (a square's middle is t + 0.5) as this
## Control's pixels.
func screen_of(t: Vector2) -> Vector2:
	return view.get_center() + (t - cam) * k

func squares_at(p: Vector2) -> Vector2:
	return cam + (p - view.get_center()) / k

func tile_under(p: Vector2) -> Vector2i:
	return Vector2i(squares_at(p).floor())

## The view glides to put square point `t` at the middle.
func look_at_square(t: Vector2, at_once := false) -> void:
	if at_once or Motion.reduce:
		cam = t
		_cam_to = Vector2.INF
		_place()
	else:
		_cam_to = t

func set_tool(id: String) -> void:
	tool = id
	_run = {}

# --- the sim's events ---

func play(ev: Dictionary) -> void:
	match String(ev.type):
		"place":
			_pop[ev.tile] = _clock
			_dirty = true
		"lay":
			var tiles: Array = ev.tiles
			for j in tiles.size():
				_pop[tiles[j]] = _clock + j * 0.025
			_dirty = true
		"turn":
			_spin[ev.tile] = [_clock, (int(ev.face) + 3) % 4]
			_dirty = true
		"lift":
			_gone.append([int(ev.kind), 0, ev.tile, _clock])
			_pop[ev.tile] = _clock
			_dirty = true
		"op":
			_squash[Sim.tile_of(int(ev.i))] = _clock
		"hit":
			_box_bump = _clock
		"level":
			_box_glow = _clock
			_box_bump = _clock

## Something about the paper changed without an event (a load, a harness).
func relay() -> void:
	_dirty = true

func tick(delta: float) -> void:
	_clock += delta
	if sim != null:
		_phase = fposmod(_phase + delta * sim.belt_speed(), 1.0)
	if _cam_to != Vector2.INF and not _gesture:
		cam = cam.lerp(_cam_to, 1.0 - exp(-EASE * delta))
		if cam.distance_to(_cam_to) < 0.01:
			cam = _cam_to
			_cam_to = Vector2.INF
	_edge_pan(delta)
	_place()
	if _dirty:
		_rebuild()
	for nm in ["chev", "under", "tokens", "pieces", "live"]:
		_layers[nm].queue_redraw()
	_words.queue_redraw()
	# old moments forget themselves
	for d: Dictionary in [_pop, _squash]:
		for t in d.keys():
			if _clock - float(d[t]) > 1.0:
				d.erase(t)
	for t in _spin.keys():
		if _clock - float(_spin[t][0]) > 1.0:
			_spin.erase(t)
	_gone = _gone.filter(func(g: Array) -> bool: return _clock - float(g[3]) < GONE)

# --- building the still layers ---

func _rebuild() -> void:
	_dirty = false
	if _paper == null:
		_paper = Art.paper(Sim.W, Sim.H, RIM)
	if _printed_at != sim.level:
		_printed_at = sim.level
		var b := Face.Builder.new()
		for i in Sim.N:
			var v := int(sim.dep[i])
			if v > 0:
				Art.print_ring(b, Art.mid(Sim.tile_of(i)), sim.can_dig(v))
		_prints = b.mesh() if not b.verts.is_empty() else null
	_work_ins()
	var beds := Face.Builder.new()
	var decks := Face.Builder.new()
	for i in Sim.N:
		var kd := int(sim.kind[i])
		if kd == Sim.BELT:
			var f := int(sim.face[i])
			Art.bed_into(beds, Art.mid(Sim.tile_of(i)), _entry(i, f), f)
		elif kd == Sim.BRIDGE:
			var at := Art.mid(Sim.tile_of(i))
			var v := int(sim.face2[i])
			Art.bed_into(beds, at, v, v)
			decks.append(Art.deck(int(sim.face[i])), Transform2D(0.0, at))
	_beds = beds.mesh() if not beds.verts.is_empty() else null
	_decks = decks.mesh() if not decks.verts.is_empty() else null
	_layers.ground.queue_redraw()
	_layers.beds.queue_redraw()
	_layers.decks.queue_redraw()

## Which ways tokens come into each slot, as bits of their way of going.
func _work_ins() -> void:
	_ins = {}
	for s: int in sim.lanes:
		for e: int in sim.outs[s]:
			_mark(e)
	for i: int in sim.machines:
		_mark(int(sim.machines[i].front))
		_mark(int(sim.machines[i].back))
	for i: int in sim.digs:
		for e: int in sim.digs[i].outs:
			_mark(e)
	for i: int in sim.crates:
		for e: int in sim.crates[i].outs:
			_mark(e)

func _mark(e: int) -> void:
	if e < 0:
		return
	var id := e >> 2
	if id < Sim.N2:
		_ins[id] = int(_ins.get(id, 0)) | (1 << (e & 3))

## The way a belt's bed comes in: from its back, or round from the one side
## that feeds it alone.
func _entry(i: int, f: int) -> int:
	var bits := int(_ins.get(i, 0))
	if bits & (1 << f) or bits == 0:
		return f
	var l := Sim.left_of(f)
	var r := Sim.right_of(f)
	var from_r := bits & (1 << l) != 0   # going `l` means it came from the right side
	var from_l := bits & (1 << r) != 0
	if from_l and not from_r:
		return r
	if from_r and not from_l:
		return l
	return f

# --- drawing ---

func _visible() -> Rect2i:
	var a := squares_at(Vector2.ZERO).floor()
	var b := squares_at(size).ceil()
	return Rect2i(Vector2i(a) - Vector2i(1, 1), Vector2i(b - a) + Vector2i(3, 3))

func _sees(t: Vector2i, r: Rect2i) -> bool:
	return r.has_point(t)

func _draw_layer(nm: String, l: Node2D) -> void:
	if sim == null:
		return
	match nm:
		"ground":
			if _paper != null:
				l.draw_mesh(_paper, null)
			if _prints != null:
				l.draw_mesh(_prints, null)
		"beds":
			if _beds != null:
				l.draw_mesh(_beds, null)
		"chev":
			_draw_mesh_live(l, nm, _build_chevrons())
		"under":
			_draw_mesh_live(l, nm, _build_tokens(true))
		"decks":
			if _decks != null:
				l.draw_mesh(_decks, null)
		"tokens":
			_draw_mesh_live(l, nm, _build_tokens(false))
		"pieces":
			_draw_mesh_live(l, nm, _build_pieces())
		"live":
			_draw_mesh_live(l, nm, _build_live())

## A mesh made for this frame, held until the next is drawn.
func _draw_mesh_live(l: Node2D, nm: String, m: ArrayMesh) -> void:
	_live[nm] = m
	if m != null:
		l.draw_mesh(m, null)

func _build_chevrons() -> ArrayMesh:
	var fb := Face.FlatBuilder.new(_flat_cache)
	var chev := Art.chevron()
	var r := _visible()
	for s: int in sim.lanes:
		if s >= Sim.N:
			continue
		var i := s
		var t := Sim.tile_of(i)
		if not _sees(t, r) or int(sim.kind[i]) != Sim.BELT:
			continue
		var f := int(sim.face[i])
		var a := _entry(i, f)
		var at := Art.mid(t)
		for h in [0.0, 0.5]:
			var p := fposmod(_phase + h, 1.0)
			var pos := Art.path(at, a, f, p)
			fb.append(chev, Transform2D(Art.path_tan(a, f, p).angle(), pos))
	return fb.mesh()

func _build_tokens(under: bool) -> ArrayMesh:
	var fb := Face.FlatBuilder.new(_flat_cache)
	var plain := Art.token(false)
	var ringed := Art.token(true)
	var aim: int = sim.target()
	var r := _visible()
	for s: int in sim.lanes:
		if (s >= Sim.N) != under or sim.occ[s] == 0:
			continue
		var t := Sim.tile_of(s % Sim.N)
		if not _sees(t, r):
			continue
		fb.append(ringed if int(sim.val[s]) == aim else plain, Transform2D(0.0, token_at(s)))
	return fb.mesh()

## Where the token in slot `s` is, in mesh units.
func token_at(s: int) -> Vector2:
	var t := Sim.tile_of(s % Sim.N)
	return Art.path(Art.mid(t), int(sim.from_d[s]), sim.exit_dir(s), clampf(sim.prog[s], 0.0, 1.0))

## How much a piece is grown as it is set down (0 to 1, with a bounce).
func _grow(t: Vector2i) -> float:
	if Motion.reduce or not _pop.has(t):
		return 1.0
	var u := (_clock - float(_pop[t])) / POP
	if u < 0.0:
		return 0.0
	if u >= 1.0:
		return 1.0
	return 1.0 + sin(u * PI) * 0.16 * (1.0 - u) - (1.0 - u) * (1.0 - u) * 0.6

func _build_pieces() -> ArrayMesh:
	var fb := Face.FlatBuilder.new(_flat_cache)
	var r := _visible()
	# the box first: the pieces round it stand over its shadow
	var bx := Vector2(Sim.HUB_AT) * U
	var bump := 1.0
	if not Motion.reduce:
		var u := (_clock - _box_bump) / 0.24
		if u >= 0.0 and u < 1.0:
			bump = 1.0 + 0.035 * sin(u * PI)
	var half := Sim.HUB * U * 0.5
	fb.append(Art.box(), Transform2D(0.0, Vector2(bump, bump), 0.0, bx + Vector2(half, half) - Vector2(half, half) * bump))
	for y in range(maxi(r.position.y, 0), mini(r.end.y, Sim.H)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, Sim.W)):
			var i := y * Sim.W + x
			var kd := int(sim.kind[i])
			if kd == Sim.EMPTY or kd == Sim.BELT or kd == Sim.BRIDGE or kd == Sim.BOX:
				continue
			var t := Vector2i(x, y)
			var at := Art.mid(t)
			var g := _grow(t)
			if g <= 0.01:
				continue
			var sc := Vector2(g, g)
			if _squash.has(t) and not Motion.reduce:
				var u := (_clock - float(_squash[t])) / SQUASH
				if u < 1.0:
					var w := sin(u * PI) * 0.09
					sc *= Vector2(1.0 + w, 1.0 - w)
			var rot := 0.0
			var m: ArrayMesh
			if kd == Sim.DIG:
				m = Art.dig()
			elif kd == Sim.CRATE:
				m = Art.crate()
			else:
				m = Art.machine(kd)
				rot = int(sim.face[i]) * PI * 0.5
				if _spin.has(t) and not Motion.reduce:
					var u := clampf((_clock - float(_spin[t][0])) / SPIN, 0.0, 1.0)
					rot -= (1.0 - (1.0 - pow(1.0 - u, 3.0))) * PI * 0.5
			fb.append(m, Transform2D(rot, sc, 0.0, at))
	for g: Array in _gone:
		var u := (_clock - float(g[3])) / GONE
		if Motion.reduce or u >= 1.0:
			continue
		var kd := int(g[0])
		var m: ArrayMesh = Art.icon(kd) if kd != Sim.BELT else null
		if m != null:
			fb.append(m, Transform2D(0.0, Vector2.ONE * (1.0 - u), 0.0, Art.mid(g[2])), Color(1, 1, 1, 1.0 - u))
	return fb.mesh()

func _build_live() -> ArrayMesh:
	var b := Face.Builder.new()
	b.feather = 1.5 * U / maxf(k, 1.0)
	var r := _visible()
	# a machine at work: an arc round its sign
	for i: int in sim.machines:
		var t := Sim.tile_of(i)
		if not _sees(t, r):
			continue
		var m: Dictionary = sim.machines[i]
		if bool(m.busy):
			var at := Art.mid(t)
			var u := clampf(float(m.t), 0.0, 1.0)
			if u > 0.02:
				b.stroke(Face.Builder.arc_points(at, U * 0.3, -PI * 0.5, -PI * 0.5 + TAU * u), U * 0.05, Color(Art.CREAM, 0.85), false)
	# the box: its bar, and a glow when a level is done
	var panel := Art.box_panel()
	var bx := Vector2(Sim.HUB_AT) * U
	var bar := Rect2(bx + panel.position + Vector2(36, panel.size.y - 64), Vector2(panel.size.x - 72, 22))
	b.polygon(Face.Builder.round_rect(bar.position, bar.size, 11.0), Color(Art.INK, 0.12))
	var fill := clampf(float(sim.got) / maxf(1.0, float(sim.count())), 0.0, 1.0)
	if fill > 0.0:
		b.polygon(Face.Builder.round_rect(bar.position, Vector2(maxf(bar.size.x * fill, 22.0), bar.size.y), 11.0), Color("7cb06b"))
	if not Motion.reduce:
		var u := (_clock - _box_glow) / 0.9
		if u >= 0.0 and u < 1.0:
			var c := bx + Vector2.ONE * Sim.HUB * U * 0.5
			b.stroke(Face.Builder.ring(c, Sim.HUB * U * (0.55 + 0.5 * u), Sim.HUB * U * (0.55 + 0.5 * u)), 18.0 * (1.0 - u), Color(Art.TARGET, 1.0 - u), true)
	# a belt just laid: a puff of dust round it
	if not Motion.reduce:
		for t: Vector2i in _pop:
			var u := (_clock - float(_pop[t])) / POP
			if u < 0.0 or u >= 1.0 or not _sees(t, r):
				continue
			b.stroke(Face.Builder.ring(Art.mid(t), U * (0.3 + 0.3 * u), U * (0.3 + 0.3 * u)), U * 0.06 * (1.0 - u), Color(Art.CREAM, 0.8 * (1.0 - u)), true)
	# the run in hand
	if not _run.is_empty():
		var tiles: Array = _run.tiles
		var f := int(_run.f)
		var cut := int(_run.cut)
		for j in tiles.size():
			var at := Art.mid(tiles[j])
			var ok := j < cut
			var c := Color(Art.GHOST, 0.55) if ok else Color(Art.WARN, 0.45)
			var pts := PackedVector2Array([at - Art.dir_v(f) * U * 0.5, at + Art.dir_v(f) * U * 0.5])
			b.stroke(pts, U * 0.6, c, false, false)
			if ok:
				var n := Art.dir_v(f).orthogonal() * U * 0.14
				var tip := at + Art.dir_v(f) * U * 0.16
				b.stroke(PackedVector2Array([tip - Art.dir_v(f) * U * 0.2 + n, tip, tip - Art.dir_v(f) * U * 0.2 - n]), U * 0.07, Color(Art.CREAM, 0.95))
	# a finger pressing with a piece in hand: where it would go
	if _finger != -99 and not _moved and TOOL_KINDS.has(tool) and tool != "belt":
		var t := tile_under(_at)
		var why: String = sim.why_not(int(TOOL_KINDS[tool]), t)
		var same := Sim.inside(t) and int(sim.kind[Sim._i(t)]) == int(TOOL_KINDS[tool])
		var c := Color(Art.GHOST, 0.5) if why == "" or same else Color(Art.WARN, 0.4)
		b.polygon(Face.Builder.round_rect(Art.mid(t) - Vector2.ONE * U * 0.47, Vector2.ONE * U * 0.94, 18.0), c)
	if tool == "remove" and _finger != -99:
		var t := tile_under(_at)
		b.stroke(Face.Builder.round_rect(Art.mid(t) - Vector2.ONE * U * 0.47, Vector2.ONE * U * 0.94, 18.0), 8.0, Color(Art.WARN, 0.8), true)
	return b.mesh() if not b.verts.is_empty() else null

## The numerals, in this Control's pixels: printed numbers, the digs', the
## crates', the tokens' (one size a run), and the box's panel.
func _draw_words() -> void:
	if sim == null or font == null:
		return
	var r := _visible()
	var printed := int(clampf(k * 0.4, 0.0, 64.0))
	var aim: int = sim.target()
	if printed >= FS_MIN:
		for y in range(maxi(r.position.y, 0), mini(r.end.y, Sim.H)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, Sim.W)):
				var i := y * Sim.W + x
				var v := int(sim.dep[i])
				var kd := int(sim.kind[i])
				if v == 0 or (kd != Sim.EMPTY and kd != Sim.DIG):
					continue
				var col: Color = Art.PENCIL if sim.can_dig(v) else Art.PENCIL_SHUT
				if kd == Sim.DIG:
					col = Art.INK
				_write(str(v), screen_of(Vector2(x, y) + Vector2(0.5, 0.5)), printed if kd == Sim.EMPTY else int(printed * 0.85), col.darkened(0.15) if kd == Sim.EMPTY else col)
	# crates: the number kept and how many
	if printed >= FS_MIN:
		for i: int in sim.crates:
			var t := Sim.tile_of(i)
			if not _sees(t, r):
				continue
			var c: Dictionary = sim.crates[i]
			var at := screen_of(Vector2(t) + Vector2(0.5, 0.5))
			if int(c.n) > 0:
				_write(Sim.short(int(c.v)), at + Vector2(0, -k * 0.02), int(printed * 0.7), Art.INK)
			_write("×%d" % int(c.n), at + Vector2(0, k * 0.27), int(printed * 0.45), Color(Art.CREAM, 0.95))
	# the tokens, a run of glyphs a size
	var runs := {}
	for s: int in sim.lanes:
		if sim.occ[s] == 0:
			continue
		var t := Sim.tile_of(s % Sim.N)
		if not _sees(t, r):
			continue
		var txt := Sim.short(int(sim.val[s]))
		var n := txt.length()
		var fs := int(k * (0.36 if n <= 2 else (0.3 if n == 3 else (0.24 if n == 4 else 0.19))))
		if fs < FS_MIN:
			continue
		if not runs.has(fs):
			runs[fs] = []
		var p: Vector2 = _world.transform * token_at(s)
		runs[fs].append([txt, p + Vector2(0, -k * 0.02), int(sim.val[s]) == aim])
	for fs: int in runs:
		for w: Array in runs[fs]:
			_write(w[0], w[1], fs, Art.INK)
	# the box's panel: the number asked, how many, the level
	var panel := Art.box_panel()
	var bx := Vector2(Sim.HUB_AT) * U
	var xf := _world.transform
	var top: Vector2 = xf * (bx + panel.position)
	var span: Vector2 = (xf * (bx + panel.end)) - top
	var big := int(span.y * 0.36)
	var txt := Sim.short(aim)
	big = mini(big, int(span.x * 1.6 / maxf(1.0, txt.length())))
	if big >= FS_MIN:
		_write(tr("TL_LEVEL") % sim.level, top + Vector2(span.x * 0.5, span.y * 0.17), int(span.y * 0.11), Color(Art.INK, 0.7))
		_write(txt, top + Vector2(span.x * 0.5, span.y * 0.46), big, Art.INK)
		_write("%s / %s" % [Sim.short(sim.got), Sim.short(sim.count())], top + Vector2(span.x * 0.5, span.y * 0.7), int(span.y * 0.12), Color(Art.INK, 0.75))

## A string centred on `at` (its middle), `fs` pixels.
func _write(text: String, at: Vector2, fs: int, col: Color) -> void:
	if fs < FS_MIN:
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_words.draw_string(font, Vector2(at.x - w * 0.5, at.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

# --- fingers ---

func _gui_input(event: InputEvent) -> void:
	if not interactive or sim == null:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index, e.position)
		accept_event()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		_move(e.index, e.position)
		accept_event()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			if b.pressed:
				_down(-1, b.position)
			else:
				_up(-1, b.position)
		elif b.pressed and (b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var keep := squares_at(b.position)
			k *= WHEEL if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL
			_clamp_k()
			cam = keep - (b.position - view.get_center()) / k
			_cam_to = Vector2.INF
			_place()
		accept_event()
	elif event is InputEventMouseMotion and _touch.has(-1):
		_move(-1, (event as InputEventMouseMotion).position)
		accept_event()

func _down(id: int, p: Vector2) -> void:
	_touch[id] = p
	_last[id] = p
	if _touch.size() >= 2:
		# a second finger: whatever the first was doing is a pinch now
		_gesture = true
		_finger = -99
		_run = {}
		_cam_to = Vector2.INF
		return
	press(p, id)

func _move(id: int, p: Vector2) -> void:
	if not _touch.has(id):
		return
	var was: Vector2 = _touch[id]
	_touch[id] = p
	if _gesture:
		if _touch.size() >= 2:
			_pinch()
		return
	if id == _finger:
		drag(p, was)

func _up(id: int, p: Vector2) -> void:
	if not _touch.has(id):
		return
	_touch.erase(id)
	_last.erase(id)
	if _gesture:
		if _touch.is_empty():
			_gesture = false
		else:
			_last = _touch.duplicate()
		return
	if id == _finger:
		release(p)

## Two fingers: the paper under their middle stays under it as they move
## and spread.
func _pinch() -> void:
	var ids := _touch.keys()
	var a0: Vector2 = _last.get(ids[0], _touch[ids[0]])
	var b0: Vector2 = _last.get(ids[1], _touch[ids[1]])
	var a1: Vector2 = _touch[ids[0]]
	var b1: Vector2 = _touch[ids[1]]
	var keep := squares_at((a0 + b0) * 0.5)
	var d0 := maxf(a0.distance_to(b0), 1.0)
	var d1 := maxf(a1.distance_to(b1), 1.0)
	k *= d1 / d0
	_clamp_k()
	cam = keep - ((a1 + b1) * 0.5 - view.get_center()) / k
	_last = _touch.duplicate()
	_place()

## One finger down at `p` (a harness or the tutorial presses through here).
func press(p: Vector2, id := -1) -> void:
	_finger = id
	_start = p
	_at = p
	_moved = false
	_run = {}
	_lifted = {}
	_vel = Vector2.ZERO
	_cam_to = Vector2.INF

func drag(p: Vector2, was := Vector2.INF) -> void:
	if was == Vector2.INF:
		was = _at
	_at = p
	if not _moved and p.distance_to(_start) >= SLOP:
		_moved = true
		if tool == "remove":
			_lift_at(_start)
	if not _moved:
		return
	match tool:
		"belt":
			_run = run_to(tile_under(_start), tile_under(p), p - _start)
		"remove":
			# every square crossed since the last event, so a quick swipe misses none
			var steps := int(ceilf(was.distance_to(p) / maxf(k * 0.3, 4.0)))
			for j in range(1, steps + 1):
				_lift_at(was.lerp(p, float(j) / steps))
		_:
			var now := Time.get_ticks_msec()
			var d := (p - was) / k
			_vel = _vel.lerp(-d / maxf(0.008, (now - _moved_at) / 1000.0), 0.5)
			_moved_at = now
			cam -= d
			_place()

func release(p: Vector2) -> void:
	_at = p
	_finger = -99
	var moved := _moved
	_moved = false
	match tool:
		"belt":
			if moved:
				var run := run_to(tile_under(_start), tile_under(p), p - _start)
				_run = {}
				_lay(run)
			else:
				_tap(p)
		"remove":
			if not moved:
				var t := tile_under(p)
				var kd: int = sim.kind_at(t)
				if kd == Sim.EMPTY or kd < 0:
					touched.emit(0.85)
				elif kd == Sim.BOX:
					box_asked.emit()
				else:
					_lift_at(p)
			_lifted = {}
		_:
			if moved:
				if Time.get_ticks_msec() - _moved_at < 90 and not Motion.reduce:
					_cam_to = cam + _vel * FLING
			else:
				_tap(p)
	_run = {}

## While a run is laid or a swipe lifts near the view's edge, the view moves
## that way.
func _edge_pan(delta: float) -> void:
	if _finger == -99 or not _moved or (tool != "belt" and tool != "remove"):
		return
	var push := Vector2.ZERO
	if _at.x < view.position.x + EDGE:
		push.x = -1.0
	elif _at.x > view.end.x - EDGE:
		push.x = 1.0
	if _at.y < view.position.y + EDGE:
		push.y = -1.0
	elif _at.y > view.end.y - EDGE:
		push.y = 1.0
	if push == Vector2.ZERO:
		return
	cam += push * EDGE_SPEED * delta
	_place()
	if tool == "belt":
		_run = run_to(tile_under(_start), tile_under(_at), _at - _start)
	else:
		_lift_at(_at)

## A straight run from `a` toward `b` along whichever way the finger went
## further, cut at the first square that cannot take belt.
func run_to(a: Vector2i, b: Vector2i, swipe: Vector2) -> Dictionary:
	var d := b - a
	var f: int
	if d == Vector2i.ZERO:
		if absf(swipe.x) >= absf(swipe.y):
			f = 0 if swipe.x >= 0.0 else 2
		else:
			f = 1 if swipe.y >= 0.0 else 3
	elif absi(d.x) >= absi(d.y):
		f = 0 if d.x > 0 else 2
	else:
		f = 1 if d.y > 0 else 3
	var n := absi(d.x) if f % 2 == 0 else absi(d.y)
	var tiles := []
	for j in n + 1:
		var t: Vector2i = a + Sim.DIRS[f] * j
		if not Sim.inside(t):
			break
		tiles.append(t)
	# a swipe begun on a dig, a machine or the box starts beside it
	if tiles.size() > 1 and not sim.can_lay(tiles[0]):
		tiles.pop_front()
	var cut := -1
	for j in tiles.size():
		if not sim.can_lay(tiles[j]):
			cut = j
			break
	return {"tiles": tiles, "f": f, "cut": cut if cut >= 0 else tiles.size()}

func _lay(run: Dictionary) -> void:
	var tiles: Array = run.tiles
	var cut := int(run.cut)
	if cut <= 0:
		if not tiles.is_empty():
			refused.emit("taken", screen_of(Vector2(tiles[0]) + Vector2(0.5, 0.5)), 0)
		return
	belt_face = int(run.f)
	sim.lay_run(tiles.slice(0, cut), int(run.f))

func _lift_at(p: Vector2) -> void:
	var t := tile_under(p)
	if _lifted.has(t) or not Sim.inside(t):
		return
	_lifted[t] = true
	var kd := int(sim.kind[Sim._i(t)])
	if kd != Sim.EMPTY and kd != Sim.BOX:
		sim.remove(t)

## A tap: what it does is the tool's.
func _tap(p: Vector2) -> void:
	var t := tile_under(p)
	if not Sim.inside(t):
		return
	var i := Sim._i(t)
	var kd := int(sim.kind[i])
	var at := screen_of(Vector2(t) + Vector2(0.5, 0.5))
	if kd == Sim.BOX:
		box_asked.emit()
		return
	match tool:
		"move":
			if kd == Sim.BELT:
				sim.turn(t)
			elif kd != Sim.EMPTY:
				asked.emit(t)
			elif int(sim.dep[i]) > 0:
				refused.emit("printed", at, int(sim.dep[i]))
			else:
				touched.emit(0.9)
		"belt":
			if kd == Sim.BELT or Sim.is_op(kd):
				sim.turn(t)
			elif kd == Sim.EMPTY:
				sim.lay_run([t], belt_face)
			else:
				asked.emit(t)
		"remove":
			pass
		_:
			var want := int(TOOL_KINDS[tool])
			if kd == want and Sim.is_op(kd):
				sim.turn(t)
				place_face = int(sim.face[i])
			elif kd == want:
				asked.emit(t)
			elif Sim.is_op(kd) and Sim.is_op(want):
				var f := int(sim.face[i])
				sim.remove(t)
				sim.place(want, t, f)
			else:
				sim.place(want, t, place_face)

## Every finger let go: a card went up.
func let_go() -> void:
	_touch.clear()
	_last.clear()
	_gesture = false
	_finger = -99
	_run = {}
	_moved = false
