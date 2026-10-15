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
## **The tools** under one finger (`tool`), the builder's hand of spec
## docs/superpowers/specs/2026-10-15-tally-builder-and-tree-design.md: a
## tap never turns or places anything by itself. "move" (Look) pans with a
## fling, and a tap on a piece opens its **piece pill** (Turn, Remove,
## Info); "belt" traces a 4-connected path of squares shown as a ghost
## (green where it can be laid, red from the first square it cannot) and
## lays it on release, each square facing the next, and a tap lays one belt
## facing the last trace and opens its pill; "remove" lifts what the finger
## crosses; a machine's tool (and "dig", "crate") drops a **ghost** of the
## piece on a tap with the **builder pill** (Turn, Place, Cancel), moved by a
## drag from it or a tap elsewhere, and pans on a drag from anywhere else.
## Every gesture that may change the paper calls `sim.mark()` first, so the
## owner's undo chip can take it back.
##
## **The pills** are the board's, drawn in screen space over the paper by
## one layer (`_pills`) and hit by `press`/`release` themselves, so the
## tutorial's scripted finger and the harness press them as a player does;
## `pill_button_rect(name)` says where a button is.
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
## Chevrons are drawn from this many pixels a square.
const CHEV_FROM := 30.0
## A numeral smaller than this many pixels is not written.
const FS_MIN := 8
const TOOL_KINDS := {"belt": Sim.BELT, "dig": Sim.DIG, "crate": Sim.CRATE, "add": Sim.ADD, "mul": Sim.MUL, "sub": Sim.SUB, "div": Sim.DIV, "pow": Sim.POW}
## A pill: round buttons this wide, their captions under, in a paper capsule
## PILL_OFF pixels off the square, which wears a sun ring while it is up.
const BTN := 84.0
const PILL_PAD := 16.0
const PILL_GAP := 14.0
const CAP_FS := 20
const TITLE_FS := 24
const PILL_OFF := 14.0
const PILL_POP := 0.18
const PILL_ICON := {"turn": "turn", "lift": "bin", "info": "help", "place": "check", "cancel": "cross"}
const PILL_CAP := {"turn": "TL_TURN", "lift": "TL_LIFT", "info": "TL_INFO", "place": "TL_PLACE", "cancel": "TL_CANCEL"}
const PILL_PITCH := {"turn": 1.02, "lift": 0.92, "info": 1.0, "place": 1.08, "cancel": 0.9}
## A starving side's pulse ring takes this long a beat.
const STARVE_BEAT := 1.4

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
var _pills: Node2D
var _pill_box: StyleBoxFlat
var _pill_cache := {}
var _pill_live := {}
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
## The squares traced under the finger with Belt, and the way of its last step.
var _path: Array = []
var _trace_f := 0
var _lifted := {}
var _vel := Vector2.ZERO
var _moved_at := 0
var _cam_to := Vector2.INF
## The builder's ghost: {kind, tile, face, swap}; the pill up: {kind
## "piece" or "build", tile, buttons}; the pill button under the finger.
var _ghost := {}
var _pill := {}
var _pill_hit := ""
var _pill_at := -10.0
var _btn_at := {}       # button -> when pressed
var _ghost_spin := -10.0
var _drag_ghost := false
var _consumed := false

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
	_pills = Node2D.new()
	_pills.name = "Pills"
	add_child(_pills)
	_pills.draw.connect(_draw_pills)
	_pill_box = CozyTheme.lifted(Color("fcf7ef"), 36, 8)
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

## A tool taken up: whatever the hand held (a path, a ghost, a pill) is put down.
func set_tool(id: String) -> void:
	tool = id
	_path = []
	_ghost = {}
	_pill = {}
	_pill_hit = ""

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
		"undo":
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
	_pills.queue_redraw()
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
	var beds := Face.FlatBuilder.new(_flat_cache)
	var decks := Face.FlatBuilder.new(_flat_cache)
	for i in Sim.N:
		var kd := int(sim.kind[i])
		if kd == Sim.BELT:
			var f := int(sim.face[i])
			var at := Art.mid(Sim.tile_of(i))
			var a := _entry(i, f)
			# a second way in from a side (a merge) and a way out to a side
			# (a split) each get their bend under the main bed, so a token
			# taking it rides on walnut and not on the paper
			var bits := int(_ins.get(i, 0))
			for d: int in [Sim.left_of(f), Sim.right_of(f)]:
				if bits & (1 << d) and d != a:
					beds.append(Art.bed(d, f), Transform2D(0.0, at))
			for e: int in sim.outs.get(i, PackedInt32Array()):
				if (e & 3) != f:
					beds.append(Art.bed(a, e & 3), Transform2D(0.0, at))
			beds.append(Art.bed(a, f), Transform2D(0.0, at))
		elif kd == Sim.BRIDGE:
			var at := Art.mid(Sim.tile_of(i))
			var v := int(sim.face2[i])
			beds.append(Art.bed(v, v), Transform2D(0.0, at))
			decks.append(Art.deck(int(sim.face[i])), Transform2D(0.0, at))
	_beds = beds.mesh()
	_decks = decks.mesh()
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
	# far out a chevron is a speck: the tokens show the way
	if k < CHEV_FROM:
		return null
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
	var lod := 0 if k >= 100.0 else (1 if k >= 40.0 else 2)
	var plain := Art.token(false, lod)
	var ringed := Art.token(true, lod)
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
	# a machine waiting on one side: that side's pips in amber, with a slow pulse
	for i: int in sim.machines:
		var side: int = sim.starving(i)
		if side < 0:
			continue
		var t := Sim.tile_of(i)
		if not _sees(t, r):
			continue
		var xf := Transform2D(int(sim.face[i]) * PI * 0.5, Art.mid(t))
		var pips: Array = [Vector2(0, -U * 0.31)] if side == 0 else [Vector2(-U * 0.07, U * 0.31), Vector2(U * 0.07, U * 0.31)]
		for p: Vector2 in pips:
			b.disc(xf * p, U * 0.07, Art.AMBER)
		if not Motion.reduce:
			var u := fposmod(_clock, STARVE_BEAT) / STARVE_BEAT
			var c: Vector2 = xf * (Vector2(0, -U * 0.31) if side == 0 else Vector2(0, U * 0.31))
			b.stroke(Face.Builder.ring(c, U * (0.1 + 0.16 * u), U * (0.1 + 0.16 * u)), U * 0.04 * (1.0 - u), Color(Art.AMBER, 0.9 * (1.0 - u)), true)
	# the path traced in hand, as it would be laid
	if not _path.is_empty():
		var p: Dictionary = sim.trim_path(_path, _trace_f)
		var tiles: Array = p.tiles
		var faces: Array = p.faces
		var cut := int(p.cut)
		for j in tiles.size():
			var at := Art.mid(tiles[j])
			var f := int(faces[j])
			var ok := j < cut
			var c := Color(Art.GHOST, 0.55) if ok else Color(Art.WARN, 0.45)
			# from the edge it is entered by (a corner bends at the middle) to the one it leaves by
			var entry := at - Art.dir_v(f) * U * 0.5
			if j > 0:
				var back: int = Sim.DIRS.find((tiles[j - 1] as Vector2i) - (tiles[j] as Vector2i))
				if back >= 0:
					entry = at + Art.dir_v(back) * U * 0.5
			b.stroke(PackedVector2Array([entry, at, at + Art.dir_v(f) * U * 0.5]), U * 0.6, c, false, false)
			if ok:
				var n := Art.dir_v(f).orthogonal() * U * 0.14
				var tip := at + Art.dir_v(f) * U * 0.16
				b.stroke(PackedVector2Array([tip - Art.dir_v(f) * U * 0.2 + n, tip, tip - Art.dir_v(f) * U * 0.2 - n]), U * 0.07, Color(Art.CREAM, 0.95))
	# the builder's ghost: the square green where the piece can go, red where
	# not, and the piece itself seen through
	if not _ghost.is_empty():
		var t: Vector2i = _ghost.tile
		var kd := int(_ghost.kind)
		var ok := _ghost_why() == ""
		var c := Color(Art.GHOST, 0.45) if ok else Color(Art.WARN, 0.4)
		b.polygon(Face.Builder.round_rect(Art.mid(t) - Vector2.ONE * U * 0.47, Vector2.ONE * U * 0.94, 18.0), c)
		var rot := 0.0
		if Sim.is_op(kd):
			rot = int(_ghost.face) * PI * 0.5
			if not Motion.reduce:
				var u := clampf((_clock - _ghost_spin) / SPIN, 0.0, 1.0)
				rot -= (1.0 - (1.0 - pow(1.0 - u, 3.0))) * PI * 0.5
		var m: ArrayMesh = Art.machine(kd) if Sim.is_op(kd) else Art.icon(kd)
		b.append(m, Transform2D(rot, Vector2.ONE * 0.92, 0.0, Art.mid(t)), Color(1, 1, 1, 0.7))
	# the square under a pill wears a sun ring
	if not _pill.is_empty():
		var t: Vector2i = _pill.tile
		b.stroke(Face.Builder.round_rect(Art.mid(t) - Vector2.ONE * U * 0.5, Vector2.ONE * U, 20.0), 9.0, Color(Art.TARGET, 0.95), true)
	if tool == "remove" and _finger != -99 and not _consumed:
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

# --- the pills ---

func pill_open() -> bool:
	return not _pill.is_empty()

## Where pill button `name` is, in this Control's pixels (its disc and the
## caption under it); Rect2() when no pill with it is up.
func pill_button_rect(name: String) -> Rect2:
	var lay := _pill_layout()
	if lay.is_empty():
		return Rect2()
	return lay.buttons.get(name, Rect2())

## What the pill is for, written over its buttons: the piece's name, or the
## side a machine has been waiting on.
func _pill_title() -> String:
	if _pill.is_empty():
		return ""
	var kd: int
	if String(_pill.kind) == "build":
		kd = int(_ghost.kind)
	else:
		var t: Vector2i = _pill.tile
		kd = sim.kind_at(t)
		if Sim.is_op(kd):
			var side: int = sim.starving(Sim._i(t))
			if side >= 0:
				return tr("TL_WAITING") % tr("TL_SIDE_A" if side == 0 else "TL_SIDE_B")
	return tr("TL_PIECE_" + String(Sim.KIND_IDS.get(kd, "box")).to_upper())

## The pill's capsule and buttons in this Control's pixels, from where its
## square is now: under the square, over it when the square is in the lower
## third of the view, and kept inside the view.
func _pill_layout() -> Dictionary:
	if _pill.is_empty():
		return {}
	var names: Array = _pill.buttons
	var n := names.size()
	var w := PILL_PAD * 2.0 + n * BTN + (n - 1) * PILL_GAP
	var title_h := TITLE_FS + 10.0
	var h := PILL_PAD + title_h + BTN + 6.0 + CAP_FS + PILL_PAD * 0.75
	var c := screen_of(Vector2(_pill.tile) + Vector2(0.5, 0.5))
	var low := c.y > view.position.y + view.size.y * 2.0 / 3.0
	var y := c.y - k * 0.5 - PILL_OFF - h if low else c.y + k * 0.5 + PILL_OFF
	var r := Rect2(c.x - w * 0.5, y, w, h)
	r.position.x = clampf(r.position.x, view.position.x + 8.0, maxf(view.position.x + 8.0, view.end.x - w - 8.0))
	r.position.y = clampf(r.position.y, view.position.y + 8.0, maxf(view.position.y + 8.0, view.end.y - h - 8.0))
	var btns := {}
	for j in n:
		btns[names[j]] = Rect2(r.position.x + PILL_PAD + j * (BTN + PILL_GAP), r.position.y + PILL_PAD + title_h, BTN, BTN + 6.0 + CAP_FS)
	return {"rect": r, "buttons": btns, "title_at": r.position + Vector2(w * 0.5, PILL_PAD + TITLE_FS * 0.8)}

func _pill_button_at(p: Vector2) -> String:
	var lay := _pill_layout()
	if lay.is_empty():
		return ""
	for nm: String in lay.buttons:
		if (lay.buttons[nm] as Rect2).grow(6.0).has_point(p):
			return nm
	return ""

## Why the ghost cannot be set down where it is, or "" when it can: a swap
## of one operator for another is always possible.
func _ghost_why() -> String:
	if _ghost.is_empty():
		return "taken"
	if bool(_ghost.swap):
		return "" if sim.has(int(_ghost.kind)) else "locked"
	return sim.why_not(int(_ghost.kind), _ghost.tile)

func _open_piece_pill(t: Vector2i) -> void:
	var kd: int = sim.kind_at(t)
	var buttons := ["lift", "info"]
	if kd == Sim.BELT or Sim.is_op(kd):
		buttons.push_front("turn")
	_ghost = {}
	_pill = {"kind": "piece", "tile": t, "buttons": buttons}
	_pill_at = _clock
	touched.emit(1.0)

func _set_ghost(kd: int, t: Vector2i, f: int, swap: bool) -> void:
	var fresh := _ghost.is_empty() or Vector2i(_ghost.tile) != t or int(_ghost.kind) != kd
	_ghost = {"kind": kd, "tile": t, "face": f, "swap": swap}
	var buttons := ["place", "cancel"]
	if Sim.is_op(kd):
		buttons.push_front("turn")
	_pill = {"kind": "build", "tile": t, "buttons": buttons}
	if fresh:
		_pill_at = _clock
		_pop[t] = _clock
	touched.emit(1.0)

func _close_pill() -> void:
	_pill = {}
	_pill_hit = ""

## A pill button let go on: what it does.
func _pill_press(name: String) -> void:
	if _pill.is_empty():
		return
	var t: Vector2i = _pill.tile
	var build := String(_pill.kind) == "build"
	_btn_at[name] = _clock
	# a button whose deed the sim names (turn, lift, place) is heard through
	# that event alone; the others are heard here
	if name == "info" or name == "cancel" or (name == "turn" and build):
		touched.emit(float(PILL_PITCH.get(name, 1.0)))
	match name:
		"turn":
			if build:
				_ghost.face = (int(_ghost.face) + 1) % 4
				_ghost_spin = _clock
			else:
				sim.mark()
				sim.turn(t)
		"lift":
			sim.mark()
			sim.remove(t)
			_close_pill()
		"info":
			_close_pill()
			asked.emit(t)
		"cancel":
			_ghost = {}
			_close_pill()
		"place":
			var why := _ghost_why()
			if why != "":
				# the refusal is the answer to this touch: the screen cues nope
				refused.emit(why, screen_of(Vector2(t) + Vector2(0.5, 0.5)), sim.dep_at(t))
				return
			var kd := int(_ghost.kind)
			var f := int(_ghost.face)
			sim.mark()
			if bool(_ghost.swap):
				sim.remove(t)
			sim.place(kd, t, f)
			place_face = f
			_ghost = {}
			_close_pill()

## The pill, in this Control's pixels: a paper capsule, its title, the round
## buttons with their glyphs as one cached mesh, the captions under them.
func _draw_pills() -> void:
	var lay := _pill_layout()
	if lay.is_empty() or sim == null:
		return
	var r: Rect2 = lay.rect
	var pop := 1.0
	if not Motion.reduce:
		var u := clampf((_clock - _pill_at) / PILL_POP, 0.0, 1.0)
		pop = lerpf(0.86, 1.0, Motion.back_out(u))
	var c := r.get_center()
	_pills.draw_set_transform(c - c * pop, 0.0, Vector2(pop, pop))
	_pills.draw_style_box(_pill_box, r)
	var names: Array = _pill.buttons
	var dim := names.has("place") and _ghost_why() != ""
	var swap := names.has("place") and not _ghost.is_empty() and bool(_ghost.swap)
	var key := [String(_pill.kind), names, dim]
	var m: ArrayMesh = _pill_cache.get(key)
	if m == null:
		var b := Face.Builder.new()
		for j in names.size():
			var nm: String = names[j]
			var at := Vector2(PILL_PAD + j * (BTN + PILL_GAP) + BTN * 0.5, BTN * 0.5)
			var off := nm == "place" and dim
			var fill := Color("f3ead6")
			if nm == "place":
				fill = Color("e4dccb") if off else Art.TARGET
			b.disc(at + Vector2(0, 4.0), BTN * 0.5, Color(Art.INK, 0.14))
			b.disc(at, BTN * 0.5, fill)
			Art.glyph_into(b, String(PILL_ICON[nm]), Rect2(at - Vector2.ONE * 21.0, Vector2.ONE * 42.0), Color(Art.INK, 0.35 if off else 1.0))
		m = b.mesh()
		_pill_cache[key] = m
	var origin: Vector2 = (lay.buttons[names[0]] as Rect2).position
	_pills.draw_mesh(m, null, Transform2D(0.0, origin))
	# a button just pressed sinks and rings
	var live := Face.Builder.new()
	for nm: String in names:
		var u := (_clock - float(_btn_at.get(nm, -10.0))) / 0.3
		if u < 0.0 or u >= 1.0 or Motion.reduce:
			continue
		var at: Vector2 = (lay.buttons[nm] as Rect2).position + Vector2(BTN * 0.5, BTN * 0.5)
		live.stroke(Face.Builder.ring(at, BTN * (0.5 + 0.3 * u), BTN * (0.5 + 0.3 * u)), 6.0 * (1.0 - u), Color(Art.TARGET, 1.0 - u), true)
	_pill_live["ring"] = live.mesh() if not live.verts.is_empty() else null
	if _pill_live["ring"] != null:
		_pills.draw_mesh(_pill_live["ring"], null)
	for nm: String in names:
		var cap := tr("TL_SWAP") if nm == "place" and swap else tr(String(PILL_CAP[nm]))
		var br: Rect2 = lay.buttons[nm]
		var col := Color(Art.INK, 0.4 if nm == "place" and dim else 0.85)
		_pills.draw_string(font, Vector2(br.position.x - 20.0, br.position.y + BTN + 6.0 + CAP_FS * 0.9), cap, HORIZONTAL_ALIGNMENT_CENTER, BTN + 40.0, CAP_FS, col)
	var title := _pill_title()
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FS).x
	var title_at: Vector2 = lay.title_at
	_pills.draw_string(font, Vector2(title_at.x - tw * 0.5, title_at.y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FS, Art.INK)
	_pills.draw_set_transform(Vector2.ZERO)

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
		_path = []
		_pill_hit = ""
		_consumed = false
		_drag_ghost = false
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
## A pill's button takes the press; a press anywhere else closes a piece
## pill and does nothing more. With a ghost up, a press on its square will
## drag it.
func press(p: Vector2, id := -1) -> void:
	_finger = id
	_start = p
	_at = p
	_moved = false
	_path = []
	_lifted = {}
	_vel = Vector2.ZERO
	_cam_to = Vector2.INF
	_pill_hit = ""
	_drag_ghost = false
	_consumed = false
	if not _pill.is_empty():
		var hit := _pill_button_at(p)
		if hit != "":
			_pill_hit = hit
			_consumed = true
			return
		if String(_pill.kind) == "piece":
			_close_pill()
			_consumed = true
			return
	match tool:
		"belt":
			var t := tile_under(p)
			if Sim.inside(t):
				_path = [t]
		"remove":
			sim.mark()
		_:
			if not _ghost.is_empty() and tile_under(p) == Vector2i(_ghost.tile):
				_drag_ghost = true

func drag(p: Vector2, was := Vector2.INF) -> void:
	if was == Vector2.INF:
		was = _at
	_at = p
	if _consumed:
		return
	if not _moved and p.distance_to(_start) >= SLOP:
		_moved = true
		if tool == "remove":
			_lift_at(_start)
	if not _moved:
		return
	match tool:
		"belt":
			_trace_to(tile_under(p))
		"remove":
			# every square crossed since the last event, so a quick swipe misses none
			var steps := int(ceilf(was.distance_to(p) / maxf(k * 0.3, 4.0)))
			for j in range(1, steps + 1):
				_lift_at(was.lerp(p, float(j) / steps))
		_:
			if _drag_ghost:
				var t := tile_under(p)
				if Sim.inside(t) and t != Vector2i(_ghost.tile):
					_ghost.tile = t
					_pill.tile = t
				return
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
	if _consumed:
		_consumed = false
		if _pill_hit != "" and _pill_button_at(p) == _pill_hit:
			_pill_press(_pill_hit)
		_pill_hit = ""
		_path = []
		return
	match tool:
		"belt":
			if moved:
				_lay_traced(p)
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
				if not _drag_ghost and Time.get_ticks_msec() - _moved_at < 90 and not Motion.reduce:
					_cam_to = cam + _vel * FLING
			else:
				_tap(p)
	_path = []
	_drag_ghost = false

## While a path is traced or a swipe lifts near the view's edge, the view
## moves that way.
func _edge_pan(delta: float) -> void:
	if _finger == -99 or not _moved or _consumed or (tool != "belt" and tool != "remove"):
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
		_trace_to(tile_under(_at))
	else:
		_lift_at(_at)

## The path follows the finger to square `t`: between the path's end and
## `t` it steps the larger axis first, then the other, a square at a time.
## A step onto a square already on the path takes the path back to it (a
## step back onto the one before takes the last square off).
func _trace_to(t: Vector2i) -> void:
	if _path.is_empty():
		if Sim.inside(t):
			_path = [t]
		return
	var cur: Vector2i = _path[-1]
	var d := t - cur
	if d == Vector2i.ZERO:
		return
	var along_x := absi(d.x) >= absi(d.y)
	var first := Vector2i(signi(d.x), 0) if along_x else Vector2i(0, signi(d.y))
	var second := Vector2i(0, signi(d.y)) if along_x else Vector2i(signi(d.x), 0)
	var steps := []
	for j in (absi(d.x) if along_x else absi(d.y)):
		steps.append(first)
	for j in (absi(d.y) if along_x else absi(d.x)):
		steps.append(second)
	for s: Vector2i in steps:
		var nxt: Vector2i = (_path[-1] as Vector2i) + s
		if not Sim.inside(nxt):
			break
		var at := _path.find(nxt)
		if at >= 0:
			_path.resize(at + 1)
		else:
			_path.append(nxt)
		if _path.size() >= 2:
			_trace_f = Sim.DIRS.find((_path[-1] as Vector2i) - (_path[-2] as Vector2i))

## The traced path laid, each square facing the next; a path that cannot
## begin where it was drawn is refused there.
func _lay_traced(p: Vector2) -> void:
	if _path.is_empty():
		return
	if _path.size() == 1:
		var swipe := p - _start
		if absf(swipe.x) >= absf(swipe.y):
			_trace_f = 0 if swipe.x >= 0.0 else 2
		else:
			_trace_f = 1 if swipe.y >= 0.0 else 3
	var trimmed: Dictionary = sim.trim_path(_path, _trace_f)
	if int(trimmed.cut) <= 0:
		var tiles: Array = trimmed.tiles
		var t: Vector2i = tiles[0] if not tiles.is_empty() else _path[0]
		refused.emit("taken", screen_of(Vector2(t) + Vector2(0.5, 0.5)), 0)
		return
	belt_face = _trace_f
	sim.mark()
	sim.lay_path(_path, _trace_f)

func _lift_at(p: Vector2) -> void:
	var t := tile_under(p)
	if _lifted.has(t) or not Sim.inside(t):
		return
	_lifted[t] = true
	var kd := int(sim.kind[Sim._i(t)])
	if kd != Sim.EMPTY and kd != Sim.BOX:
		sim.remove(t)

## A tap: what it does is the tool's. It never turns or places by itself:
## a piece tapped gets its pill, a square tapped with a piece in hand gets
## the piece's ghost.
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
			if kd != Sim.EMPTY:
				_open_piece_pill(t)
			elif int(sim.dep[i]) > 0:
				refused.emit("printed", at, int(sim.dep[i]))
			else:
				touched.emit(0.9)
		"belt":
			if kd == Sim.EMPTY:
				sim.mark()
				if sim.lay_path([t], belt_face) > 0:
					_open_piece_pill(t)
			else:
				_open_piece_pill(t)
		"remove":
			pass
		_:
			var want := int(TOOL_KINDS[tool])
			if Sim.is_op(kd) and Sim.is_op(want) and kd != want:
				# another machine's tool on a machine: the ghost of the swap, as the old one faces
				_set_ghost(want, t, int(sim.face[i]), true)
			elif kd == Sim.EMPTY or kd == Sim.BELT or kd == Sim.BRIDGE:
				var f := int(_ghost.face) if not _ghost.is_empty() else place_face
				_set_ghost(want, t, f, false)
			else:
				_open_piece_pill(t)

## Every finger let go: a card went up.
func let_go() -> void:
	_touch.clear()
	_last.clear()
	_gesture = false
	_finger = -99
	_path = []
	_moved = false
	_consumed = false
	_drag_ghost = false
	_ghost = {}
	_pill = {}
	_pill_hit = ""
