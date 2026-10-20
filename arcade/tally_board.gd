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
## Info); a finger held still on it for HOLD seconds starts a **pick**: a
## rectangle from that square to the finger, and on release the pieces in
## it get the pick pill (Copy, Duplicate, Remove, Save as part; the user,
## 2026-10-19). "belt" traces a 4-connected path of squares shown as a
## ghost (green where it can be laid, red from the first square it
## cannot), laid as the finger lifts (the user, 2026-10-19: "just keep it as
## preview until user release, no confirm dialog"); a tap lays one belt the
## way of the last trace; "remove" lifts what the finger crosses; a
## machine's tool (and "dig", "crate") drops a **ghost** of the piece on a
## tap with the **builder pill** (Turn, Place, Cancel), moved by a drag from
## it or a tap elsewhere, and pans on a drag from anywhere else. "part"
## does the same with a **template** (a saved part, or the pick in hand
## after Copy), set down as plain pieces.
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
## A pick saved as part `id`.
signal part_saved(id: int)

const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

const U := Art.U
## The desk shown round the paper, in squares.
const RIM := 3.0
const SLOP := 14.0
## The zoom: the default pixels a square (about thirteen squares across the
## phone, the six-square box and some paper round it) and the closest.
const K_START := 62.0
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
## Far out a token is a speck under its belt's bed: none are drawn.
const TOKENS_FROM := 12.0
## A changed square's beds and feeding reach this far (a dig's belts two
## squares off, a bend one): the chunks that far round it are built again.
const REACH := 3
## The numerals' shaped lines are kept up to this many before they go.
const LINES_MOST := 3000
## A numeral smaller than this many pixels is not written.
const FS_MIN := 8
const TOOL_KINDS := {"belt": Sim.BELT, "dig": Sim.DIG, "crate": Sim.CRATE, "add": Sim.ADD, "mul": Sim.MUL, "sub": Sim.SUB, "div": Sim.DIV, "pow": Sim.POW}
## The kinds set down with a ghost and turned before they go.
const TURNS := [Sim.ADD, Sim.MUL, Sim.SUB, Sim.DIV, Sim.POW]
## A pill: round buttons this wide, their captions under, in a paper capsule
## PILL_OFF pixels off the square, which wears a sun ring while it is up.
const BTN := 84.0
const PILL_PAD := 16.0
const PILL_GAP := 14.0
const CAP_FS := 20
const TITLE_FS := 24
const PILL_OFF := 14.0
const PILL_POP := 0.18
const PILL_ICON := {"copy": "copy", "dup": "plus", "save": "puzzle", "undo": "undo_back", "turn": "turn", "flip": "flip", "lift": "bin", "run": "span", "line": "bends", "info": "help", "place": "check", "cancel": "cross"}
const PILL_CAP := {"copy": "TL_COPY", "dup": "TL_DUPLICATE", "save": "TL_SAVE_PART", "undo": "TL_UNDO", "turn": "TL_TURN", "flip": "TL_FLIP", "lift": "TL_LIFT", "run": "TL_ERASE_RUN", "line": "TL_ERASE_LINE", "info": "TL_INFO", "place": "TL_PLACE", "cancel": "TL_CANCEL"}
const PILL_PITCH := {"copy": 1.06, "dup": 1.06, "save": 1.1, "undo": 0.9, "turn": 1.02, "flip": 1.04, "lift": 0.92, "run": 0.9, "line": 0.88, "info": 1.0, "place": 1.08, "cancel": 0.9}
## How far along its last square a token riding into an operator is drawn.
## How long a finger rests still on the paper under Look before a pick
## begins, and how long the Undo pill stays after a pick is removed.
const HOLD := 0.42
const UNDO_PILL := 6.0
## A starving side's pulse ring takes this long a beat.
const STARVE_BEAT := 1.4
## The visor's work (the user, 2026-10-20: "some good looking operation
## module effect using some visor, different animations on addition,
## multiplier, etc ... the sum smash two numbers together"): at or past
## this zoom the operation is drawn on the pane (far out it is a speck, as
## the chevrons are); how long an answer stays on the glass after it is
## handed out, and how long its flash lasts.
const VISOR_FROM := 32.0
const SHOWN := 0.5
const FLASH := 0.35
## The beats of a machine's cycle in the sim's `t`: when the chips are in
## from A and B, and when the operation strikes (the answer is up from then
## to the end, so a four-second adder and a half-second one read alike).
const V_IN := 0.32
const V_HIT := 0.6
## The dig's work (the user, 2026-10-20: "add animation also to extractor
## and the numbers going into core"): a thump as each token is put out,
## read off the sim's clock, and a puff of dust at the edge it left by, at
## most one a PUFF_GAP. A number into the box flies from the rim to the
## panel over FLY, FLY_MAX of them at once.
const THUMP := 0.22
const PUFF := 0.3
const PUFF_GAP := 0.3
const FLY := 0.42
const FLY_MAX := 32

var sim: RefCounted
var tool := "move"
var place_face := 0
var belt_face := 0
## The part the "part" tool sets down, or -1 for the pick in hand.
var part_id := -1
## The pick in hand after Copy: a template set down by the "part" tool
## while `part_id` is -1.
var clip := {}
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
var _beds_c := {}        # chunk -> the beds of its belts, one mesh (or null)
var _decks_c := {}       # chunk -> its crossings' plates
var _dirty_c := {}       # chunks to build again
var _drawn_c := []       # the chunks the beds and decks were last drawn with
var _dirty_all := true
var _lines := {}         # [text, fs] -> TextLine
var _live := {}
var _flat_cache := {}
var _dirty := true
var _printed_at := -1
var _clock := 0.0
var _phase := 0.0
var _ins := {}
## The lanes on the squares in view, in the sim's order, worked out once a
## frame for the chevrons, both token layers and the numerals: walking all
## of `sim.lanes` four times a frame grew with the whole factory.
var _seen := PackedInt32Array()
var _seen_key := []
## Each machine's mouths as drawn: root -> [ins, outs], Art.machine's bits.
var _mouth := {}

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
## With `straight`, the axis the path keeps to (0 across, 1 up and down; -1
## until the finger has gone a square).
var _axis := -1
var _lifted := {}
var _vel := Vector2.ZERO
var _moved_at := 0
var _cam_to := Vector2.INF
## The builder's ghost: {kind, tile, face}; the pill up: {kind
## "piece" or "build", tile, buttons}; the pill button under the finger.
var _ghost := {}
var _pill := {}
var _pill_hit := ""
var _pill_at := -10.0
var _btn_at := {}       # button -> when pressed
var _ghost_spin := -10.0
var _drag_ghost := false
## Where on the ghost the finger took it, from its root.
var _grab := Vector2i.ZERO
var _consumed := false
## A pick: when the finger went down, whether it is being drawn, its two
## corners, and the squares picked once it is let go.
var _down_at := -10.0
var _picking := false
var _pick_a := Vector2i.ZERO
var _pick_b := Vector2i.ZERO
var _picked: Array = []

# moments
var _pop := {}       # square -> when
var _spin := {}      # square -> [when, from face]
var _squash := {}    # square -> when
var _gone: Array = [] # [kind, face, square, when]
var _shown := {}     # machine root -> [when, the answer handed out]
var _vis := {}       # machine root -> this frame's chips on its visor: [at, r, text, colour]
var _live_flat: ArrayMesh  # the visors' panes and chips this frame, cached meshes appended
var _puff := {}      # dig root -> [when, the sim's stamp it answers, where]
var _fly: Array = [] # numbers into the box: [when, value, from, hit]
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

## Far out the view holds about a hundred squares across: the sheet is
## four screens wide then, and nothing under a belt's bed is drawn.
func k_least() -> float:
	return maxf(8.0, size.x / (Sim.W + RIM))

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
	_picking = false
	_picked = []

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
		"flip":
			var tiles: Array = ev.tiles
			for j in tiles.size():
				_pop[tiles[j]] = _clock + j * 0.02
			_dirty = true
		"lift":
			_gone.append([int(ev.kind), 0, ev.tile, _clock])
			_pop[ev.tile] = _clock
			_dirty = true
		"erase":
			var tiles: Array = ev.tiles
			for j in tiles.size():
				_pop[tiles[j]] = _clock + j * 0.02
			_dirty = true
		"undo", "part":
			_dirty = true
		"op":
			_squash[Sim.tile_of(int(ev.i))] = _clock
			_shown[int(ev.i)] = [_clock, int(ev.v)]
		"in":
			# from the slot's edge toward the box (the slot may hold the next
			# token already); the panel's number is where it lands
			var sl := int(ev.s)
			var tl := Sim.tile_of(sl % Sim.N)
			var f := int(sim.face2[sl % Sim.N]) if sl >= Sim.N else int(sim.face[sl % Sim.N])
			_fly.append([_clock, int(ev.v), Art.mid(tl) + Art.dir_v(f) * U * 0.5, int(ev.v) == sim.target()])
			while _fly.size() > FLY_MAX:
				_fly.pop_front()
		"hit":
			_box_bump = _clock
		"level":
			_box_glow = _clock
			_box_bump = _clock

## Something about the paper changed without an event (a load, a harness).
func relay() -> void:
	_dirty = true
	_dirty_all = true
	_printed_at = -1

func tick(delta: float) -> void:
	_clock += delta
	if sim != null:
		_phase = fposmod(_phase + delta * sim.belt_speed(), 1.0)
	if _cam_to != Vector2.INF and not _gesture:
		cam = cam.lerp(_cam_to, 1.0 - exp(-EASE * delta))
		if cam.distance_to(_cam_to) < 0.01:
			cam = _cam_to
			_cam_to = Vector2.INF
	_hold_pick()
	_edge_pan(delta)
	_place()
	if String(_pill.get("kind", "")) == "undone" and _clock - _pill_at > UNDO_PILL:
		_close_pill()
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
	for i in _shown.keys():
		if _clock - float(_shown[i][0]) > 1.0:
			_shown.erase(i)
	for i in _puff.keys():
		if _clock - float(_puff[i][0]) > 1.0:
			_puff.erase(i)
	_fly = _fly.filter(func(f: Array) -> bool: return _clock - float(f[0]) < FLY)
	for t in _spin.keys():
		if _clock - float(_spin[t][0]) > 1.0:
			_spin.erase(t)
	_gone = _gone.filter(func(g: Array) -> bool: return _clock - float(g[3]) < GONE)

# --- building the still layers ---

func _rebuild() -> void:
	if sim == null:
		return
	if _paper == null:
		_paper = Art.paper(Sim.W, Sim.H, RIM)
	if _dirty_all:
		_dirty_all = false
		_dirty = false
		_beds_c = {}
		_decks_c = {}
		_dirty_c = {}
		_ins = {}
		_mouths()
		sim.changed.clear()
	elif _dirty or not sim.changed.is_empty():
		_dirty = false
		# the chunks the changed squares reach into
		for i: int in sim.changed:
			var t := Sim.tile_of(i)
			for cy in range(maxi(t.y - REACH, 0) / Sim.CH, mini(t.y + REACH, Sim.H - 1) / Sim.CH + 1):
				for cx in range(maxi(t.x - REACH, 0) / Sim.CH, mini(t.x + REACH, Sim.W - 1) / Sim.CH + 1):
					_dirty_c[cy * Sim.CW + cx] = true
		sim.changed.clear()
		_mouths()
	if _printed_at != sim.level:
		_printed_at = sim.level
		var b := Face.Builder.new()
		for i: int in sim.printed:
			var v := int(sim.dep[i])
			if v > 0:
				Art.print_ring(b, Art.mid(Sim.tile_of(i)), sim.can_dig(v))
		_prints = b.mesh() if not b.verts.is_empty() else null
		_layers.ground.queue_redraw()
	# the chunks in sight are built when missing, the dirty ones again; the
	# layers draw again when the view comes onto other chunks too, or a
	# chunk built before shows its chevrons with no bed under them
	var seen := _chunks_seen()
	var built := seen != _drawn_c
	for c: int in seen:
		if _dirty_c.has(c) or not _beds_c.has(c):
			_build_chunk(c)
			_dirty_c.erase(c)
			built = true
	if built:
		_drawn_c = seen
		_layers.beds.queue_redraw()
		_layers.decks.queue_redraw()

## One chunk's beds and crossing plates, each one mesh; its belts' ways in
## worked out first.
func _build_chunk(c: int) -> void:
	var beds := Face.FlatBuilder.new(_flat_cache)
	var decks := Face.FlatBuilder.new(_flat_cache)
	var cell: PackedInt32Array = sim.cells[c]
	for i: int in cell:
		_ins[i] = _ways_in(i)
	for i: int in cell:
		var kd := int(sim.kind[i])
		if kd == Sim.BELT and int(sim.dead[i]) == 1:
			# a line's loose end goes as far as its middle: a stub from each
			# edge it is fed by (a join's L or T), or from its back
			var f := int(sim.face[i])
			var at := Art.mid(Sim.tile_of(i))
			var bits := int(_ins.get(i, 0))
			if bits == 0:
				bits = 1 << f
			for d in 4:
				if bits & (1 << d):
					beds.append(Art.stub(d), Transform2D(0.0, at))
		elif kd == Sim.BELT:
			var f := int(sim.face[i])
			var at := Art.mid(Sim.tile_of(i))
			var a := _entry(i, f)
			# a second way in from a side (a T) gets its bend under the main
			# bed, so a token taking it rides on walnut and not on the paper
			var bits := int(_ins.get(i, 0))
			for d: int in [Sim.left_of(f), Sim.right_of(f)]:
				if bits & (1 << d) and d != a:
					beds.append(Art.bed(d, f), Transform2D(0.0, at))
				# a fork's bend out of a side, the way the branch goes
				if int(sim.fork[i]) & (1 << d):
					beds.append(Art.bed(a, d), Transform2D(0.0, at))
			beds.append(Art.bed(a, f), Transform2D(0.0, at))
		elif kd == Sim.BRIDGE:
			# a crossing: the up-and-down lane's bed, the + plate over it
			# carrying the across lane
			var at := Art.mid(Sim.tile_of(i))
			var v := int(sim.face2[i])
			beds.append(Art.bed(v, v), Transform2D(0.0, at))
			decks.append(Art.cross(int(sim.face[i])), Transform2D(0.0, at))
	_beds_c[c] = beds.mesh() if not cell.is_empty() else null
	_decks_c[c] = decks.mesh() if not cell.is_empty() else null

## Which ways tokens come into belt `i`, as bits of their way of going:
## from the belts handing into it, and from a dig or a crate beside it.
func _ways_in(i: int) -> int:
	var bits := 0
	for s: int in sim.feeders.get(i, PackedInt32Array()):
		for e: int in sim.outs[s]:
			if (e >> 2) == i:
				bits |= 1 << (e & 3)
	var t := Sim.tile_of(i)
	for d in 4:
		var u: Vector2i = t + Sim.DIRS[d]
		if not Sim.inside(u):
			continue
		var j := Sim._i(u)
		var kd := int(sim.kind[j])
		var o: PackedInt32Array
		if kd == Sim.DIG:
			var r := int(sim.root[j])
			r = j if r < 0 else r
			if sim.digs.has(r):
				o = sim.digs[r].outs
		elif kd == Sim.CRATE and sim.crates.has(j):
			o = sim.crates[j].outs
		for e: int in o:
			if (e >> 2) == i:
				bits |= 1 << (e & 3)
	return bits

## Which edges each machine is fed by and hands out of.
func _mouths() -> void:
	_mouth = {}
	for i: int in sim.machines:
		_mouth[i] = sim.ports(i)

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

## The chunks the view touches, row by row.
func _chunks_seen() -> Array:
	var r := _visible()
	var out := []
	for cy in range(maxi(r.position.y, 0) / Sim.CH, mini(r.end.y - 1, Sim.H - 1) / Sim.CH + 1):
		for cx in range(maxi(r.position.x, 0) / Sim.CH, mini(r.end.x - 1, Sim.W - 1) / Sim.CH + 1):
			out.append(cy * Sim.CW + cx)
	return out

## Every lane on a square in view: a belt's, and both of a crossing's,
## read off the chunks' lists, so a frame costs what is on screen.
func _lanes_seen() -> PackedInt32Array:
	var r := _visible()
	var key := [Engine.get_process_frames(), r, sim.lanes.size(), sim]
	if key == _seen_key:
		return _seen
	_seen_key = key
	_seen = PackedInt32Array()
	for c: int in _chunks_seen():
		for i: int in sim.cells[c]:
			if not r.has_point(Sim.tile_of(i)):
				continue
			_seen.append(i)
			if int(sim.kind[i]) == Sim.BRIDGE:
				_seen.append(i + Sim.N)
	return _seen

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
			for c: int in _chunks_seen():
				var m: ArrayMesh = _beds_c.get(c)
				if m != null:
					l.draw_mesh(m, null)
		"chev":
			_draw_mesh_live(l, nm, _build_chevrons())
		"under":
			_draw_mesh_live(l, nm, _build_tokens(true))
		"decks":
			for c: int in _chunks_seen():
				var m: ArrayMesh = _decks_c.get(c)
				if m != null:
					l.draw_mesh(m, null)
		"tokens":
			_draw_mesh_live(l, nm, _build_tokens(false))
		"pieces":
			_draw_mesh_live(l, nm, _build_pieces())
		"live":
			var m := _build_live()
			_draw_mesh_live(l, "live_flat", _live_flat)
			_draw_mesh_live(l, nm, m)

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
	for s: int in _lanes_seen():
		if s >= Sim.N:
			continue
		var i := s
		var t := Sim.tile_of(i)
		if int(sim.kind[i]) != Sim.BELT:
			continue
		var f := int(sim.face[i])
		var a := _entry(i, f)
		var at := Art.mid(t)
		var dead := int(sim.dead[i]) == 1
		for h in [0.0, 0.5]:
			var p := fposmod(_phase + h, 1.0)
			if dead and p > 0.4:
				continue
			var pos := Art.path(at, a, f, p)
			fb.append(chev, Transform2D(Art.path_tan(a, f, p).angle(), pos))
			# a fork's chevrons bend off into its branch past the middle
			for d in 4:
				if int(sim.fork[i]) & (1 << d) and d != f and p > 0.5:
					fb.append(chev, Transform2D(Art.path_tan(a, d, p).angle(), Art.path(at, a, d, p)))
	return fb.mesh()

func _build_tokens(under: bool) -> ArrayMesh:
	if k < TOKENS_FROM:
		return null
	var fb := Face.FlatBuilder.new(_flat_cache)
	var lod := 0 if k >= 100.0 else (1 if k >= 40.0 else 2)
	var plain := Art.token(false, lod)
	var ringed := Art.token(true, lod)
	var aim: int = sim.target()
	for s: int in _lanes_seen():
		if (s >= Sim.N) != under or sim.occ[s] == 0:
			continue
		if sim.op[s % Sim.N] != 0:
			# a machine covers the belts under it, tokens and all
			continue
		fb.append(ringed if int(sim.val[s]) == aim else plain, Transform2D(0.0, token_at(s)))
	return fb.mesh()

## Where the token in slot `s` is, in mesh units.
func token_at(s: int) -> Vector2:
	var t := Sim.tile_of(s % Sim.N)
	var x: int = sim.exit_dir(s)
	var p := clampf(sim.prog[s], 0.0, 1.0)
	return Art.path(Art.mid(t), int(sim.from_d[s]), x, p)

## Where a machine drawn from `at` (its root's middle) goes turned by
## `rot`: about the middle of the squares it covers, so a square one spins
## in place.
func _about(kd: int, t: Vector2i, f: int, at: Vector2, rot: float) -> Vector2:
	if rot == 0.0 or not Sim.is_op(kd):
		return at
	var sq: Array = Sim.footprint(kd, t, f)
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for q: Array in sq:
		lo = lo.min(Art.mid(q[0]))
		hi = hi.max(Art.mid(q[0]))
	var c := (lo + hi) * 0.5
	return c + (at - c).rotated(rot)

## How far dig `i` is squashed by its thump, a token just put out: 0 at
## rest, read off the sim's clock against the dig's last put.
func _thump(i: int) -> float:
	if Motion.reduce or not sim.digs.has(i):
		return 0.0
	var u := (float(sim.clock) - float(sim.digs[i].at)) / THUMP
	if u < 0.0 or u >= 1.0:
		return 0.0
	return sin(u * PI) * 0.04

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
	# a machine is drawn from its root, seen when any of it may be
	var wide := r.grow(2)
	var roots: Array = []
	for i: int in sim.digs:
		roots.append(i)
	for i: int in sim.crates:
		roots.append(i)
	for i: int in sim.machines:
		roots.append(i)
	for i: int in roots:
		var t := Sim.tile_of(i)
		if not _sees(t, wide):
			continue
		var kd: int = sim.kind_at(t)
		var at := Art.mid(t)
		var g := _grow(t)
		if g <= 0.01:
			continue
		var sc := Vector2(g, g)
		if _squash.has(t) and not Motion.reduce:
			var u := (_clock - float(_squash[t])) / SQUASH
			if u < 1.0:
				var w := sin(u * PI) * 0.06
				sc *= Vector2(1.0 + w, 1.0 - w)
		var rot := 0.0
		var m: ArrayMesh
		if kd == Sim.DIG:
			m = Art.dig()
			var w := _thump(i)
			sc *= Vector2(1.0 + w, 1.0 - w)
		elif kd == Sim.CRATE:
			m = Art.crate()
		else:
			var mo: Array = _mouth.get(i, [0, 0])
			m = Art.machine(kd, sim.face_at(t), int(mo[0]), int(mo[1]))
			if _spin.has(t) and not Motion.reduce:
				var u := clampf((_clock - float(_spin[t][0])) / SPIN, 0.0, 1.0)
				rot -= (1.0 - (1.0 - pow(1.0 - u, 3.0))) * PI * 0.5
		fb.append(m, Transform2D(rot, sc, 0.0, _about(kd, t, sim.face_at(t), at, rot)))
	for g: Array in _gone:
		var u := (_clock - float(g[3])) / GONE
		if Motion.reduce or u >= 1.0:
			continue
		var kd := int(g[0])
		var m: ArrayMesh = Art.icon(kd) if kd != Sim.BELT and kd != Sim.PART else null
		if m != null:
			fb.append(m, Transform2D(0.0, Vector2.ONE * (1.0 - u), 0.0, Art.mid(g[2])), Color(1, 1, 1, 1.0 - u))
	return fb.mesh()

func _build_live() -> ArrayMesh:
	var b := Face.Builder.new()
	b.feather = 1.5 * U / maxf(k, 1.0)
	var r := _visible()
	# a machine at work: the operation on its visor (its panes and chips
	# appended whole, drawn under this mesh)
	var fb := Face.FlatBuilder.new(_flat_cache)
	_live_visors(fb, b, r)
	_live_digs(fb, r)
	_live_fly(fb)
	_live_flat = fb.mesh()
	# the box: its bar, and a glow when a level is done
	_live_box(b)
	_live_rest(b, r)
	return b.mesh() if not b.verts.is_empty() else null

func _live_box(b: Face.Builder) -> void:
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

func _live_rest(b: Face.Builder, r: Rect2i) -> void:
	# a belt just laid: a puff of dust round it
	if not Motion.reduce:
		for t: Vector2i in _pop:
			var u := (_clock - float(_pop[t])) / POP
			if u < 0.0 or u >= 1.0 or not _sees(t, r):
				continue
			b.stroke(Face.Builder.ring(Art.mid(t), U * (0.3 + 0.3 * u), U * (0.3 + 0.3 * u)), U * 0.06 * (1.0 - u), Color(Art.CREAM, 0.8 * (1.0 - u)), true)
	# a machine waiting on one side: that side's mouth in amber, with a slow pulse
	for i: int in sim.machines:
		var side: int = sim.starving(i)
		if side < 0:
			continue
		var t := Sim.tile_of(i)
		if not _sees(t, r.grow(2)):
			continue
		var f: int = sim.face_at(t)
		var want := Sim.R_A if side == 0 else Sim.R_B
		var fp := Sim.footprint(sim.kind_at(t), t, f)
		var mo: Array = _mouth.get(i, [0, 0])
		for ci in fp.size():
			if int(fp[ci][1]) != want:
				continue
			var at := Art.mid(fp[ci][0])
			for d: int in Art.ways(int(mo[0]), ci, f):
				var v := Art.dir_v(d)
				b.polygon(Art.notch_poly(at, v), Art.AMBER)
				for ch: PackedVector2Array in Art.notch_chevrons(at, v, side + 1):
					b.stroke(ch, Art.MOUTH_W, Art.INK)
				if not Motion.reduce:
					var u := fposmod(_clock, STARVE_BEAT) / STARVE_BEAT
					var pc := Art.notch_mid(at, v)
					b.stroke(Face.Builder.ring(pc, U * (0.14 + 0.16 * u), U * (0.14 + 0.16 * u)), U * 0.04 * (1.0 - u), Color(Art.AMBER, 0.9 * (1.0 - u)), true)
	# the path traced in hand, as it will be laid
	if not _path.is_empty():
		_path_into(b, _path, _trace_f)
	# the builder's ghost: the square green where the piece can go, red where
	# not, and the piece itself seen through
	if not _ghost.is_empty():
		_ghost_into(b)
	# a pick being drawn, or picked: the rectangle, its pieces lit
	if _picking or String(_pill.get("kind", "")) == "pick":
		_pick_into(b)
	# the square under a pill wears a sun ring
	if not _pill.is_empty() and _pill.has("tile"):
		var t: Vector2i = _pill.tile
		var sqs: Array = [t]
		if String(_pill.kind) == "build" and not _ghost.is_empty():
			sqs = _ghost_squares()
		elif Sim.inside(t):
			sqs = sim.piece_squares(t)
		var lo := Vector2(sqs[0] as Vector2i)
		var hi := lo
		for q: Vector2i in sqs:
			lo = lo.min(Vector2(q))
			hi = hi.max(Vector2(q))
		b.stroke(Face.Builder.round_rect(lo * U, (hi - lo + Vector2.ONE) * U, 14.0), 9.0, Color(Art.TARGET, 0.95), true)
	if tool == "remove" and _finger != -99 and not _consumed:
		var t := tile_under(_at)
		b.stroke(Face.Builder.round_rect(Art.mid(t) - Vector2.ONE * U * 0.47, Vector2.ONE * U * 0.94, 18.0), 8.0, Color(Art.WARN, 0.8), true)

# --- the visors ---

## The operation on each working machine's visor: the glass painted over
## the resting sign, the two numbers as cream chips riding in from their A
## and B squares, the kind's own strike, and the answer popping up and
## staying SHOWN after it is handed out. `_vis` keeps where each chip is
## and what it says, for `_draw_words`. Phased by the sim's `t`, never the
## clock, so a slow adder and a fast one play the same beats. The panes
## and chips are cached meshes appended to `fb`; `b` takes the strikes'
## rings, sparks and crumbs, over them.
func _live_visors(fb: Face.FlatBuilder, b: Face.Builder, r: Rect2i) -> void:
	_vis = {}
	if k < VISOR_FROM:
		return
	var wide := r.grow(2)
	var anim := not Motion.reduce
	for i: int in sim.machines:
		var t := Sim.tile_of(i)
		if not _sees(t, wide):
			continue
		var m: Dictionary = sim.machines[i]
		var busy := bool(m.busy)
		var after := -1.0
		if _shown.has(i):
			after = _clock - float(_shown[i][0])
			if after >= SHOWN:
				after = -1.0
		var kd := int(sim.op[i])
		var f := int(sim.oface[i])
		var at := Art.mid(t)
		var vr: Rect2 = Art.visor_rect(kd, f)
		vr.position += at
		if busy or after >= 0.0:
			fb.append(Art.visor_part("glass", kd, f), Transform2D(0.0, at))
		# the gauge in the pane's foot, at rest and at work
		_gauge(fb, Art.pane_gauge(vr), float(m.eff))
		if not busy and after < 0.0:
			continue
		var chips: Array = []
		if after >= 0.0:
			# the answer handed out stays on the glass and fades, under a flash
			var v := after / SHOWN
			_chip(fb, chips, vr.get_center(), _chip_r(vr) * 1.15, Sim.short(int(_shown[i][1])), 1.0 - v * v)
			if anim and after < FLASH:
				fb.append(Art.visor_part("flash", kd, f, _a8(0.35 * (1.0 - after / FLASH))), Transform2D(0.0, at))
		if busy:
			_beat(fb, b, chips, i, kd, f, at, vr, m, anim)
		fb.append(Art.visor_part("glint", kd, f), Transform2D(0.0, at))
		_vis[i] = chips

## A chip's radius on a pane: a fifth of a square, or less on a narrow one
## so two sit apart at its ends (its numeral still FS_MIN at the usual zoom).
func _chip_r(vr: Rect2) -> float:
	return minf(U * 0.2, maxf(vr.size.x, vr.size.y) * 0.21)

## The efficiency gauge's strip in its trough `r`, `eff` of its length.
func _gauge(fb: Face.FlatBuilder, r: Rect2, eff: float) -> void:
	var w := r.size.x * clampf(eff, 0.0, 1.0)
	if w < 3.0:
		return
	fb.append(Art.gauge(Art.gauge_level(eff)), Transform2D(0.0, Vector2(w / U, 1.0), 0.0, r.position))

## Each dig in view: its gauge along its foot, and a puff of dust at the
## edge a token just left by (one a PUFF_GAP, so a fast dig does not
## shimmer; the thump is in `_build_pieces`). Each crate's gauge too (the
## user: "efficiency indicator to all modules that has output").
func _live_digs(fb: Face.FlatBuilder, r: Rect2i) -> void:
	if k < VISOR_FROM:
		return
	var wide := r.grow(2)
	for i: int in sim.crates:
		var t := Sim.tile_of(i)
		if not _sees(t, wide):
			continue
		var gr := Art.crate_gauge()
		gr.position += Art.mid(t)
		_gauge(fb, gr, float(sim.crates[i].get("eff", 0.0)))
	for i: int in sim.digs:
		var t := Sim.tile_of(i)
		if not _sees(t, wide):
			continue
		var g: Dictionary = sim.digs[i]
		var at := Art.mid(t)
		var gr := Art.dig_gauge()
		gr.position += at
		_gauge(fb, gr, float(g.eff))
		if Motion.reduce or int(g.e) < 0:
			continue
		var stamp := float(g.at)
		var p: Array = _puff.get(i, [])
		if p.is_empty() or (float(p[1]) != stamp and _clock - float(p[0]) >= PUFF_GAP):
			var e := int(g.e) >> 2
			var to := Art.mid(Sim.tile_of(e % Sim.N))
			p = [_clock, stamp, at.lerp(to, 0.78)]
			_puff[i] = p
		var u := (_clock - float(p[0])) / PUFF
		if u < 1.0:
			var sc := U * (0.1 + 0.3 * (1.0 - (1.0 - u) * (1.0 - u))) / Art.BURST_R
			fb.append(Art.burst(0, _a8(0.8 * (1.0 - u))), Transform2D(0.0, Vector2.ONE * sc, 0.0, p[2]))

## The numbers into the box: each flies from the rim it came in by to the
## panel's number, up in an arc, shrinking and fading, and lands with a
## small ring. Their numerals go through `_vis` under the box's key.
func _live_fly(fb: Face.FlatBuilder) -> void:
	if _fly.is_empty() or k < VISOR_FROM:
		return
	var panel := Art.box_panel()
	var to := Vector2(Sim.HUB_AT) * U + panel.position + Vector2(panel.size.x * 0.5, panel.size.y * 0.46)
	var chips: Array = []
	for f: Array in _fly:
		var u := clampf((_clock - float(f[0])) / FLY, 0.0, 1.0)
		if Motion.reduce:
			u = 1.0 if u > 0.5 else 0.0
		var e := _ss(u)
		var at: Vector2 = (f[2] as Vector2).lerp(to, e) + Vector2(0, -U * 0.35 * sin(u * PI))
		var r := U * (0.24 if bool(f[3]) else 0.2) * (1.0 - 0.5 * e)
		var a := 1.0 - _span(u, 0.7, 1.0)
		_chip(fb, chips, at, r, Sim.short(int(f[1])), a)
		var land := _span(u, 0.8, 1.0)
		if land > 0.0 and land < 1.0 and not Motion.reduce:
			var sc := U * (0.1 + 0.25 * land) / Art.BURST_R
			fb.append(Art.burst(0, _a8(1.0 - land)), Transform2D(0.0, Vector2.ONE * sc, 0.0, to))
	_vis[-1] = chips

## One beat of machine `i`'s cycle: the chips in from A and B over V_IN,
## then the kind's own strike.
func _beat(fb: Face.FlatBuilder, b: Face.Builder, chips: Array, i: int, kd: int, f: int, at: Vector2, vr: Rect2, m: Dictionary, anim: bool) -> void:
	var u := clampf(float(m.t), 0.0, 1.0)
	var x := int(m.x)
	var y := int(m.y)
	var c := vr.get_center()
	var cr := _chip_r(vr)
	# the pane's long way, A's end negative
	var ax := Vector2(1, 0) if vr.size.x >= vr.size.y else Vector2(0, 1)
	var pa := c
	var pb := c
	var pr := c
	for q: Array in Sim.footprint(kd, Sim.tile_of(i), f):
		match int(q[1]):
			Sim.R_A:
				pa = Art.mid(q[0])
			Sim.R_B:
				pb = Art.mid(q[0])
			Sim.R_REM:
				pr = Art.mid(q[0])
	if (pb - pa).dot(ax) < 0.0:
		ax = -ax
	var hw := absf(vr.size.dot(ax)) * 0.5
	var hh := absf(vr.size.dot(ax.orthogonal())) * 0.5
	var ra := c - ax * (hw - cr * 1.1)
	var rb := c + ax * (hw - cr * 1.1)
	var sa := Sim.short(x)
	var sb := Sim.short(y)
	if u < V_IN:
		var w := _ss(u / V_IN) if anim else 1.0
		var g := Motion.back_out(minf(1.0, u / 0.1)) if anim else 1.0
		_chip(fb, chips, pa.lerp(ra, w), cr * g, sa)
		_chip(fb, chips, pb.lerp(rb, w), cr * g, sb)
		return
	var res := int(Sim.divide(x, y)[0]) if kd == Sim.DIV else Sim.apply(kd, x, y)
	var d := {"u": u, "x": x, "y": y, "c": c, "cr": cr, "rr": cr * 1.15, "ax": ax, "hw": hw, "hh": hh,
		"ra": ra, "rb": rb, "pr": pr, "sa": sa, "sb": sb, "sr": Sim.short(res), "anim": anim, "vr": vr,
		"kd": kd, "f": f, "at": at}
	match kd:
		Sim.ADD:
			_beat_add(fb, b, chips, d)
		Sim.SUB:
			_beat_sub(fb, b, chips, d)
		Sim.MUL:
			_beat_mul(fb, b, chips, d)
		Sim.DIV:
			_beat_div(fb, b, chips, d)
		Sim.POW:
			_beat_pow(fb, b, chips, d)

## The sum: both chips lean back, rush together and smash at the middle,
## and the sum pops up out of the hit with a squash, a ring and sparks.
func _beat_add(fb: Face.FlatBuilder, b: Face.Builder, chips: Array, d: Dictionary) -> void:
	var u: float = d.u
	var ax: Vector2 = d.ax
	if u < V_HIT:
		var pa: Vector2 = d.ra
		var pb: Vector2 = d.rb
		if d.anim:
			var w := _ss(_span(u, V_IN, 0.44)) * U * 0.06
			var rush := _span(u, 0.44, V_HIT)
			rush = rush * rush * rush
			pa = (d.ra - ax * w).lerp(d.c - ax * d.cr * 0.15, rush)
			pb = (d.rb + ax * w).lerp(d.c + ax * d.cr * 0.15, rush)
		_chip(fb, chips, pa, d.cr, d.sa)
		_chip(fb, chips, pb, d.cr, d.sb)
		return
	var v := _span(u, V_HIT, V_HIT + 0.18)
	var g := Motion.back_out(v) if d.anim else 1.0
	var sq := sin(PI * v) * 0.22 if d.anim else 0.0
	var sc := Vector2.ONE + (Vector2(sq, -sq) if ax.x != 0.0 else Vector2(-sq, sq))
	_chip(fb, chips, d.c, d.rr * g, d.sr, 1.0, sc)
	if d.anim:
		_burst(fb, d.c, _span(u, V_HIT, V_HIT + 0.25), 6, 1.0)
		_flash(fb, d, _span(u, V_HIT, V_HIT + 0.15))

## The difference: B leans back and rams A; A shivers and slides to the
## middle as the difference, B bounces off, shrinking away, crumbs fall.
func _beat_sub(fb: Face.FlatBuilder, b: Face.Builder, chips: Array, d: Dictionary) -> void:
	var u: float = d.u
	var ax: Vector2 = d.ax
	var touch: Vector2 = d.ra + ax * d.cr * 1.7
	if u < V_HIT:
		var pb: Vector2 = d.rb
		if d.anim:
			# B draws back past the pane's end, then rams A
			var w := _ss(_span(u, V_IN, 0.44)) * U * 0.14
			var rush := _span(u, 0.44, V_HIT)
			pb = (d.rb + ax * w).lerp(touch, rush * rush * rush)
		_chip(fb, chips, d.ra, d.cr, d.sa)
		_chip(fb, chips, pb, d.cr, d.sb)
		return
	var v := _span(u, V_HIT, V_HIT + 0.2)
	var pa: Vector2 = d.ra.lerp(d.c, _ss(v))
	if d.anim:
		pa += ax * sin(v * 40.0) * (1.0 - v) * U * 0.03
	var g := 1.0 + 0.25 * Motion.back_out(v) if d.anim else 1.25
	_chip(fb, chips, pa, d.cr * g, d.sr if v > 0.3 else d.sa)
	if d.anim and v < 1.0:
		var e := 1.0 - (1.0 - v) * (1.0 - v)
		_chip(fb, chips, touch.lerp(d.rb + ax * U * 0.25, e), d.cr * (1.0 - v), d.sb, 1.0 - v)
		_crumbs(b, touch, ax, v)
		_burst(fb, touch, _span(u, V_HIT, V_HIT + 0.2), 0, 0.6)

## The product: B folds into A at the middle; copies of A fan out of it,
## spin up and fold back in at the strike, and the product pops up larger.
func _beat_mul(fb: Face.FlatBuilder, b: Face.Builder, chips: Array, d: Dictionary) -> void:
	var u: float = d.u
	var n := clampi(int(d.y), 0, 4)
	if u < V_HIT:
		var w := _ss(_span(u, V_IN, 0.42)) if d.anim else 1.0
		_chip(fb, chips, (d.ra as Vector2).lerp(d.c, w), d.cr, d.sa)
		if w < 1.0:
			_chip(fb, chips, (d.rb as Vector2).lerp(d.c, w), d.cr * (1.0 - w), d.sb, 1.0 - w)
		if d.anim and u >= 0.42:
			var s := _span(u, 0.42, V_HIT)
			var out := minf(1.0, sin(PI * s) * 1.4)
			var spin := s * s * TAU * 1.5
			for j in n:
				var a := spin + TAU * j / n - PI * 0.5
				var p: Vector2 = d.c + Vector2(cos(a) * d.hw * 0.55, sin(a) * d.hh * 0.5) * out
				_chip(fb, chips, p, d.cr * 0.75 * out, d.sa, 0.75 * out)
		return
	var v := _span(u, V_HIT, V_HIT + 0.18)
	var g := Motion.back_out(v) if d.anim else 1.0
	_chip(fb, chips, d.c, d.rr * 1.1 * g, d.sr)
	if d.anim:
		_burst(fb, d.c, _span(u, V_HIT, V_HIT + 0.25), 8, 1.0)
		_flash(fb, d, _span(u, V_HIT, V_HIT + 0.15))

## The quotient: A slides to the middle while B flattens into a blade and
## sweeps across it; the chip parts in two and comes back together as the
## quotient; a remainder leaves as a small chip towards the R square.
func _beat_div(fb: Face.FlatBuilder, b: Face.Builder, chips: Array, d: Dictionary) -> void:
	var u: float = d.u
	var ax: Vector2 = d.ax
	var c: Vector2 = d.c
	if u < V_HIT:
		var w := _ss(_span(u, V_IN, 0.42)) if d.anim else 1.0
		var pa: Vector2 = (d.ra as Vector2).lerp(c, w)
		var part := sin(PI * _span(u, 0.48, V_HIT)) if d.anim else 0.0
		if part <= 0.0:
			_chip(fb, chips, pa, d.cr, d.sa)
		else:
			var gap := part * U * 0.07
			_half(fb, c, d.cr, ax, -1.0, gap)
			_half(fb, c, d.cr, ax, 1.0, gap)
			chips.append([c + Vector2(0, -d.cr * 0.06), d.cr, d.sa, Color(Art.INK, 1.0 - part)])
		if d.anim:
			# B is the blade: it thins along the pane as it comes to the chip's
			# edge, sweeps across it, and is gone
			var cut := _span(u, 0.42, 0.5)
			var gone := _span(u, 0.5, 0.54)
			if gone < 1.0:
				var thin := 1.0 - 0.88 * w
				var sc := Vector2(thin, 1.15) if ax.x != 0.0 else Vector2(1.15, thin)
				var pb: Vector2 = (d.rb as Vector2).lerp(c, w) + ax.orthogonal() * d.cr * 1.5 * (1.0 - 2.0 * cut) * w
				_chip(fb, chips, pb, d.cr, d.sb, 1.0 - gone, sc)
		else:
			_chip(fb, chips, d.rb, d.cr, d.sb)
		return
	var v := _span(u, V_HIT, V_HIT + 0.18)
	var g := Motion.back_out(v) if d.anim else 1.0
	_chip(fb, chips, c, d.rr * g, d.sr)
	if d.anim:
		_burst(fb, c, _span(u, V_HIT, V_HIT + 0.22), 4, 0.7)
	var qr := Sim.divide(int(d.x), int(d.y))
	if int(qr[1]) != 0 or int(d.y) == 0:
		var e := _span(u, 0.66, 1.0)
		if e > 0.0:
			_chip(fb, chips, c.lerp(d.pr, _ss(e) if d.anim else 1.0), d.cr * 0.7, Sim.short(int(qr[1])), 1.0 - e * e)

## The power: A settles low on the pane and B shrinks into its shoulder;
## copies of A stack up into a tower that is pressed down into one, and
## the power pops up with sparkles rising off it.
func _beat_pow(fb: Face.FlatBuilder, b: Face.Builder, chips: Array, d: Dictionary) -> void:
	var u: float = d.u
	var foot: Vector2 = d.c + Vector2(0, d.hh * 0.28)
	var n := clampi(int(d.y) - 1, 0, 3)
	if u < V_HIT:
		var w := _ss(_span(u, V_IN, 0.42)) if d.anim else 1.0
		_chip(fb, chips, (d.ra as Vector2).lerp(foot, w), d.cr, d.sa)
		if w < 1.0:
			_chip(fb, chips, (d.rb as Vector2).lerp(foot + Vector2(d.cr * 1.1, -d.cr * 0.9), w), d.cr * (1.0 - 0.5 * w), d.sb, 1.0 - w)
		if d.anim:
			var press := _span(u, 0.56, V_HIT)
			for j in n:
				var s := _span(u, 0.42 + j * 0.045, 0.5 + j * 0.045)
				if s <= 0.0:
					continue
				var p: Vector2 = foot + Vector2((0.02 if j % 2 == 0 else -0.02) * U, -U * 0.07 * (j + 1) * (1.0 - press))
				_chip(fb, chips, p, d.cr * Motion.back_out(s), d.sa)
		return
	var v := _span(u, V_HIT, V_HIT + 0.18)
	var g := Motion.back_out(v) if d.anim else 1.0
	_chip(fb, chips, d.c, d.rr * 1.15 * g, d.sr)
	if d.anim:
		_flash(fb, d, _span(u, V_HIT, V_HIT + 0.15))
		_sparkles(b, d.c, _span(u, V_HIT, 0.95))

## A number's chip on a pane: a cream token (its shade, its rim, its face),
## `sc` a squash, and its numeral noted for `_draw_words`.
func _chip(fb: Face.FlatBuilder, chips: Array, at: Vector2, r: float, text: String, alpha := 1.0, sc := Vector2.ONE) -> void:
	if alpha <= 0.02 or r <= 1.0:
		return
	fb.append(Art.chip(), Transform2D(0.0, sc * r / Art.CHIP_R, 0.0, at), Color(1, 1, 1, alpha))
	chips.append([at + Vector2(0, -r * 0.06), r * minf(sc.x, sc.y), text, Color(Art.INK, alpha)])

## Half a chip, the half on `side` of `ax`, `gap` out from `c`.
func _half(fb: Face.FlatBuilder, c: Vector2, r: float, ax: Vector2, side: float, gap: float) -> void:
	var dir := ax * side
	fb.append(Art.chip(true), Transform2D(dir.angle(), Vector2.ONE * r / Art.CHIP_R, 0.0, c + dir * gap))

## A strike's ring and `n` sparks out of `c`, over `u` 0 to 1, `s` its size:
## the cached burst growing out and fading.
func _burst(fb: Face.FlatBuilder, c: Vector2, u: float, n: int, s: float) -> void:
	if u <= 0.0 or u >= 1.0:
		return
	var e := 1.0 - (1.0 - u) * (1.0 - u)
	var sc := U * (0.12 + 0.38 * e) * s / Art.BURST_R
	fb.append(Art.burst(n, _a8(1.0 - u)), Transform2D(0.0, Vector2.ONE * sc, 0.0, c))

## An alpha as the eighths a cached fading mesh is baked at.
static func _a8(a: float) -> int:
	return clampi(int(ceil(a * 8.0)), 1, 8)

## The glass lit cream for a moment at a strike.
func _flash(fb: Face.FlatBuilder, d: Dictionary, u: float) -> void:
	if u <= 0.0 or u >= 1.0:
		return
	fb.append(Art.visor_part("flash", int(d.kd), int(d.f), _a8(0.55 * (1.0 - u))), Transform2D(0.0, d.at))

## Three crumbs knocked off `at` along `ax`, falling as they fade.
func _crumbs(b: Face.Builder, at: Vector2, ax: Vector2, v: float) -> void:
	if v <= 0.0 or v >= 1.0:
		return
	var e := 1.0 - (1.0 - v) * (1.0 - v)
	var n := ax.orthogonal()
	for j in 3:
		var side := float(j - 1)
		var p := at + ax * U * (0.06 + 0.05 * j) * e + n * side * U * 0.1 * e + Vector2(0, U * 0.3 * v * v)
		b.disc(p, U * 0.035 * (1.0 - v * 0.5), Color(Art.TOKEN, 1.0 - v))

## Three sparkles rising off `c` as it fades, each a little cross.
func _sparkles(b: Face.Builder, c: Vector2, u: float) -> void:
	if u <= 0.0 or u >= 1.0:
		return
	for j in 3:
		var s := _span(u, j * 0.12, 0.7 + j * 0.12)
		if s <= 0.0 or s >= 1.0:
			continue
		var p := c + Vector2([-0.16, 0.13, 0.0][j] * U, [0.0, -0.05, 0.06][j] * U - U * 0.3 * s)
		var a := U * 0.045 * (1.0 - s)
		var col := Color(Art.TARGET, 1.0 - s)
		b.stroke(PackedVector2Array([p + Vector2(-a, 0), p + Vector2(a, 0)]), U * 0.02, col)
		b.stroke(PackedVector2Array([p + Vector2(0, -a), p + Vector2(0, a)]), U * 0.02, col)

## Smootherstep, and where `u` lies between `a` and `b`, 0 to 1.
static func _ss(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)

static func _span(u: float, a: float, b: float) -> float:
	return clampf((u - a) / (b - a), 0.0, 1.0)

## A belt path as it would be laid: green to where it is cut, red past it,
## corners bent at the middle, a cream chevron each square.
func _path_into(b: Face.Builder, path: Array, pf: int) -> void:
	var p: Dictionary = sim.trim_path(path, pf)
	var tiles: Array = p.tiles
	var faces: Array = p.faces
	var cut := int(p.cut)
	var merge := bool(p.merge)
	var forks := bool(p.get("fork", false))
	for j in tiles.size():
		var at := Art.mid(tiles[j])
		var f := int(faces[j])
		# the square a path runs into the side of is drawn to its middle, green
		var ok := j < cut or (merge and j == cut)
		var c := Color(Art.GHOST, 0.55) if ok else Color(Art.WARN, 0.45)
		# from the edge it is entered by (a corner bends at the middle) to the one it leaves by
		var entry := at - Art.dir_v(f) * U * 0.5
		if j == 0 and forks:
			# a fork leaves the line from its middle
			entry = at
		if j > 0:
			var back: int = Sim.DIRS.find((tiles[j - 1] as Vector2i) - (tiles[j] as Vector2i))
			if back >= 0:
				entry = at + Art.dir_v(back) * U * 0.5
		# a loose end goes as far as its middle, as it will be laid
		var stops: bool = (merge and j == cut) or (j == cut - 1 and not merge and not sim._takes(tiles[j] + Sim.DIRS[f], f))
		var pts := PackedVector2Array([entry, at]) if stops else PackedVector2Array([entry, at, at + Art.dir_v(f) * U * 0.5])
		b.stroke(pts, U * 0.6, c, false, false)
		if ok and not (merge and j == cut):
			var n := Art.dir_v(f).orthogonal() * U * 0.14
			var tip := at + Art.dir_v(f) * U * 0.16
			b.stroke(PackedVector2Array([tip - Art.dir_v(f) * U * 0.2 + n, tip, tip - Art.dir_v(f) * U * 0.2 - n]), U * 0.07, Color(Art.CREAM, 0.95))

## The builder's ghost of a piece.
func _ghost_into(b: Face.Builder) -> void:
	var t: Vector2i = _ghost.tile
	var kd := int(_ghost.kind)
	var gf := int(_ghost.face)
	var ok := _ghost_why() == ""
	var c := Color(Art.GHOST, 0.45) if ok else Color(Art.WARN, 0.4)
	# every square it would cover, green where it can go, red where not
	for sq: Vector2i in ([] if kd == Sim.PART else _ghost_squares()):
		b.polygon(Face.Builder.round_rect(Art.mid(sq) - Vector2.ONE * U * 0.48, Vector2.ONE * U * 0.96, 6.0), c)
	var rot := 0.0
	if not Motion.reduce:
		var u := clampf((_clock - _ghost_spin) / SPIN, 0.0, 1.0)
		rot -= (1.0 - (1.0 - pow(1.0 - u, 3.0))) * PI * 0.5
	var m: ArrayMesh
	if kd == Sim.PART:
		_template_into(b)
		return
	if Sim.is_op(kd):
		m = Art.machine(kd, gf)
	elif kd == Sim.DIG:
		m = Art.dig()
		rot = 0.0
	else:
		m = Art.icon(kd)
		rot = 0.0
	if m != null:
		b.append(m, Transform2D(rot, Vector2.ONE * 0.96, 0.0, _about(kd, t, gf, Art.mid(t), rot)), Color(1, 1, 1, 0.7))

## A template's ghost: each square green or red, its machines and crates
## seen through, a chevron the way each belt runs.
func _template_into(b: Face.Builder) -> void:
	var d: Dictionary = _ghost.tpl
	var t: Vector2i = _ghost.tile
	var rot := int(_ghost.face)
	var bad: Dictionary = sim.template_blocked(d, t, rot)
	for row: Array in sim.template_squares(d, t, rot):
		var sq: Vector2i = row[0]
		var c := Color(Art.WARN, 0.4) if bad.has(sq) else Color(Art.GHOST, 0.45)
		b.polygon(Face.Builder.round_rect(Art.mid(sq) - Vector2.ONE * U * 0.48, Vector2.ONE * U * 0.96, 6.0), c)
	for pc: Array in d.pieces:
		var at: Vector2i = t + Sim.turned_at(int(pc[0]), int(pc[1]), int(d.w), int(d.h), rot)
		var kd := int(pc[2])
		var f := (int(pc[3]) + rot) % 4
		if Sim.is_op(kd):
			b.append(Art.machine(kd, f), Transform2D(0.0, Vector2.ONE * 0.96, 0.0, _about(kd, at, f, Art.mid(at), 0.0)), Color(1, 1, 1, 0.7))
		elif kd == Sim.DIG:
			b.append(Art.dig(), Transform2D(0.0, Vector2.ONE * 0.96, 0.0, Art.mid(at)), Color(1, 1, 1, 0.7))
		elif kd == Sim.CRATE:
			b.append(Art.crate(), Transform2D(0.0, Art.mid(at)), Color(1, 1, 1, 0.7))
		else:
			var ways := [f]
			if kd == Sim.BRIDGE:
				ways.append((int(pc[4]) + rot) % 4)
			for w: int in ways:
				var v := Art.dir_v(w)
				var n := v.orthogonal() * U * 0.16
				var tip := Art.mid(at) + v * U * 0.2
				b.stroke(PackedVector2Array([tip - v * U * 0.24 + n, tip, tip - v * U * 0.24 - n]), U * 0.09, Color(Art.CREAM, 0.95))

## The pick: its rectangle, and a wash over every square of what it holds.
func _pick_into(b: Face.Builder) -> void:
	var r := pick_rect()
	for sq: Vector2i in (sim.picked(_pick_tiles()) if _picking else _picked):
		b.polygon(Face.Builder.round_rect(Art.mid(sq) - Vector2.ONE * U * 0.46, Vector2.ONE * U * 0.92, 8.0), Color(Art.TARGET, 0.32))
	b.polygon(Face.Builder.round_rect(Vector2(r.position) * U, Vector2(r.size) * U, 10.0), Color(Art.TARGET, 0.08))
	b.stroke(Face.Builder.round_rect(Vector2(r.position) * U, Vector2(r.size) * U, 10.0), 7.0, Color(Art.TARGET, 0.95), true)

## The numerals, in this Control's pixels: printed numbers, the digs', the
## crates', the tokens' (one size a run), and the box's panel.
func _draw_words() -> void:
	if sim == null or font == null:
		return
	var r := _visible()
	var printed := int(clampf(k * 0.4, 0.0, 64.0))
	var aim: int = sim.target()
	if printed >= FS_MIN:
		for i: int in sim.printed:
			var t := Sim.tile_of(i)
			if not r.has_point(t):
				continue
			var x := t.x
			var y := t.y
			var v := int(sim.dep[i])
			var kd := int(sim.kind[i])
			if v == 0 or (kd != Sim.EMPTY and kd != Sim.DIG) or sim.op[i] != 0:
				continue
			var col: Color = Art.PENCIL if sim.can_dig(v) else Art.PENCIL_SHUT
			if kd == Sim.DIG and int(sim.root[i]) >= 0 and int(sim.root[i]) != i:
				continue
			if kd == Sim.DIG:
				# the dig's face is three squares' worth: its numeral grows with
				# it, hops with the thump, and its efficiency is written under it
				var hop := _thump(i) * 1.2
				_write(str(v), screen_of(Vector2(x, y) + Vector2(0.5, 0.45 - hop)), int(clampf(k * (0.62 if v < 10 else 0.5) * (1.0 + hop), 0.0, 120.0)), Art.INK)
				if k >= VISOR_FROM and sim.digs.has(i):
					_write("%d%%" % roundi(float(sim.digs[i].eff) * 100.0), screen_of(Vector2(x, y) + Vector2(0.5, 0.86)), int(k * 0.15), Color(Art.INK, 0.6))
				continue
			_write(str(v), screen_of(Vector2(x, y) + Vector2(0.5, 0.5)), printed, col.darkened(0.15))
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
			_write("×%d" % int(c.n), at + Vector2(0, k * 0.21), int(printed * 0.45), Color(Art.CREAM, 0.95))
	# the tokens, a run of glyphs a size (none far out: no lane is walked)
	var runs := {}
	for s: int in (_lanes_seen() if k * 0.36 >= FS_MIN else PackedInt32Array()):
		if sim.occ[s] == 0 or sim.op[s % Sim.N] != 0:
			continue
		var txt := Sim.short(int(sim.val[s]))
		var n := txt.length()
		var fs := int(k * (0.36 if n <= 2 else (0.3 if n == 3 else (0.24 if n == 4 else 0.19))))
		if fs < FS_MIN:
			continue
		if not runs.has(fs):
			runs[fs] = []
		var p: Vector2 = _world.transform * token_at(s)
		runs[fs].append([txt, p + Vector2(0, -k * 0.02), int(sim.val[s]) == aim, Art.INK])
	# the chips on the visors: the numbers at work, sized to their chip
	for i: int in _vis:
		for ch: Array in _vis[i]:
			var txt: String = ch[2]
			var n := txt.length()
			var fs := int(k * float(ch[1]) / U * (1.16 if n <= 2 else (0.97 if n == 3 else (0.77 if n == 4 else 0.61))))
			if fs < FS_MIN:
				continue
			if not runs.has(fs):
				runs[fs] = []
			runs[fs].append([txt, _world.transform * (ch[0] as Vector2) + Vector2(0, -k * 0.02), false, ch[3]])
	for fs: int in runs:
		for w: Array in runs[fs]:
			_write(w[0], w[1], fs, w[3])
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
	# shaped once a text and size, drawn from the cache every frame after
	var key := [text, fs]
	var line: TextLine = _lines.get(key)
	if line == null:
		if _lines.size() >= LINES_MOST:
			_lines = {}
		line = TextLine.new()
		line.add_string(text, font, fs)
		_lines[key] = line
	var w := line.get_line_width()
	line.draw(_words.get_canvas_item(), Vector2(at.x - w * 0.5, at.y + fs * 0.36 - line.get_line_ascent()), col)

# --- the pills ---

## Part `id`'s name as the player reads it.
func part_name(id: int) -> String:
	if not sim.defs.has(id):
		return tr("TL_PIECE_PART")
	return Sim.part_title(sim.defs[id])

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
	match String(_pill.kind):
		"pick":
			var n := _pieces_in(_picked)
			return tr("TL_PICKED_ONE") if n == 1 else tr("TL_PICKED_N") % n
		"undone":
			return tr("TL_REMOVED_N") % int(_pill.n)
		"build":
			kd = int(_ghost.kind)
			if kd == Sim.PART:
				if bool(_ghost.get("once", false)):
					return tr("TL_DUPLICATE")
				return part_name(part_id) if part_id >= 0 else tr("TL_COPY_HELD")
		_:
			var t: Vector2i = _pill.tile
			kd = sim.kind_at(t)
			if Sim.is_op(kd):
				var side: int = sim.starving(Sim._i(sim.root_of(t)))
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
	var top: Vector2
	var foot: Vector2
	if _pill.has("rect"):
		# a pick's pill: under its rectangle, over it when that is low
		var pr: Rect2i = _pill.rect
		top = screen_of(Vector2(pr.position.x + pr.size.x * 0.5, pr.position.y))
		foot = screen_of(Vector2(pr.position.x + pr.size.x * 0.5, pr.end.y))
	else:
		var m := screen_of(Vector2(_pill.tile) + Vector2(0.5, 0.5))
		top = m - Vector2(0, k * 0.5)
		foot = m + Vector2(0, k * 0.5)
	var c := (top + foot) * 0.5
	var low := foot.y > view.position.y + view.size.y * 2.0 / 3.0
	var y := top.y - PILL_OFF - h if low else foot.y + PILL_OFF
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

## Why the ghost cannot be set down where it is, or "" when it can.
## A dig's ghost goes onto the printed number under it or beside it (the
## dig is three wide about its number); anything else where it is.
func _snap(kd: int, t: Vector2i) -> Vector2i:
	if kd != Sim.DIG or sim.dep_at(t) != 0:
		return t
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		if sim.dep_at(t + d) != 0:
			return t + d
	return t

func _ghost_why() -> String:
	if _ghost.is_empty():
		return "taken"
	if int(_ghost.kind) == Sim.PART:
		return sim.why_not_template(_ghost.tpl, _ghost.tile, int(_ghost.face))
	return sim.why_not(int(_ghost.kind), _ghost.tile, int(_ghost.face))

## The squares the ghost would cover.
func _ghost_squares() -> Array:
	var out := []
	if _ghost.is_empty():
		return out
	var t: Vector2i = _ghost.tile
	if int(_ghost.kind) == Sim.PART:
		for row: Array in sim.template_squares(_ghost.tpl, t, int(_ghost.face)):
			out.append(row[0])
		return out
	for sq: Array in Sim.footprint(int(_ghost.kind), t, int(_ghost.face)):
		out.append(sq[0])
	return out

func _open_piece_pill(t: Vector2i) -> void:
	t = sim.root_of(t)
	var kd: int = sim.kind_at(t)
	var buttons := ["lift", "info"]
	if kd == Sim.BELT:
		# a belt turns its whole line round with Flip, and lifts its straight
		# run or its whole line (to a join or a crossing) in one go
		buttons = ["flip", "lift", "run", "line", "info"]
	if kd == Sim.BELT or TURNS.has(kd):
		buttons.push_front("turn")
	_ghost = {}
	_pill = {"kind": "piece", "tile": t, "buttons": buttons}
	_pill_at = _clock
	touched.emit(1.0)

func _set_ghost(kd: int, t: Vector2i, f: int) -> void:
	var fresh := _ghost.is_empty() or Vector2i(_ghost.tile) != t or int(_ghost.kind) != kd
	_ghost = {"kind": kd, "tile": t, "face": f}
	var buttons := ["place", "cancel"]
	if TURNS.has(kd):
		buttons.push_front("turn")
	_pill = {"kind": "build", "tile": t, "buttons": buttons}
	if fresh:
		_pill_at = _clock
		_pop[t] = _clock
	touched.emit(1.0)

## A template's ghost with its corner on `t`, turned `rot`, and the builder
## pill; `once`: it goes after one Place (Duplicate), else the hand keeps
## the template for the next tap.
func _set_template(d: Dictionary, t0: Vector2i, rot: int, once := false) -> void:
	var t := _snap_template(d, t0, rot, 2)
	var fresh := _ghost.is_empty() or Vector2i(_ghost.tile) != t
	_ghost = {"kind": Sim.PART, "tile": t, "face": rot, "tpl": d, "once": once}
	_pill = {"kind": "build", "tile": _template_mid(), "buttons": ["turn", "place", "cancel"]}
	if fresh:
		_pill_at = _clock
	touched.emit(1.0)

## The template in hand: the part held, or the pick copied.
func _held_template() -> Dictionary:
	if part_id >= 0:
		return sim.defs.get(part_id, {})
	return clip

## The square the template ghost's pill stands by: its bottom row's middle.
func _template_mid() -> Vector2i:
	var sz := Sim.turned_size(int(_ghost.tpl.w), int(_ghost.tpl.h), int(_ghost.face))
	return Vector2i(_ghost.tile) + Vector2i(sz.x >> 1, sz.y - 1)

## The template ghost's corner moved to `t`: with a dig in it, onto the
## nearest corner within two squares where its digs stand on numbers.
func _move_template(t: Vector2i) -> void:
	_ghost.tile = _snap_template(_ghost.tpl, t, int(_ghost.face), 2)
	_pill.tile = _template_mid()

## Where template `d` near `t` turned `rot` has every dig on a number it can
## dig, looking `reach` squares about `t` (nearest first); `t` with none.
func _snap_template(d: Dictionary, t: Vector2i, rot: int, reach: int) -> Vector2i:
	var digs := []
	for pc: Array in d.pieces:
		if int(pc[2]) == Sim.DIG:
			digs.append(Sim.turned_at(int(pc[0]), int(pc[1]), int(d.w), int(d.h), rot))
	if digs.is_empty():
		return t
	var best := t
	var far := 1 << 30
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := t + Vector2i(dx, dy)
			var n := dx * dx + dy * dy
			if n >= far:
				continue
			var ok := true
			for at: Vector2i in digs:
				var v: int = sim.dep_at(c + at) if Sim.inside(c + at) else 0
				if v == 0 or not sim.can_dig(v):
					ok = false
					break
			if ok:
				best = c
				far = n
	return best

func _close_pill() -> void:
	_pill = {}
	_pill_hit = ""
	_picked = []

# --- the pick ---

## The pick's rectangle in squares, kept on the paper.
func pick_rect() -> Rect2i:
	var lo := _pick_a.min(_pick_b)
	var hi := _pick_a.max(_pick_b)
	return Rect2i(lo, hi - lo + Vector2i.ONE)

func _pick_tiles() -> Array:
	var out := []
	var r := pick_rect()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out

## How many pieces the squares hold (a machine once).
func _pieces_in(sqs: Array) -> int:
	var roots := {}
	for t: Vector2i in sqs:
		roots[sim.root_of(t)] = true
	return roots.size()

func picking() -> bool:
	return _picking

## A finger held still under Look begins a pick on its square.
func _hold_pick() -> void:
	if tool != "move" or _finger == -99 or _moved or _consumed or _gesture or _picking or _drag_ghost:
		return
	if _clock - _down_at < HOLD:
		return
	var t := tile_under(_start)
	if not Sim.inside(t):
		return
	_picking = true
	_pick_a = t
	_pick_b = t
	_close_pill()
	touched.emit(1.12)

## The pick let go: its pieces get the pick pill, or nothing happens when it
## holds none.
func _end_pick() -> void:
	_picking = false
	_picked = sim.picked(_pick_tiles())
	if _picked.is_empty():
		touched.emit(0.85)
		return
	var buttons := []
	if not sim.template_of(_picked).is_empty():
		buttons = ["copy", "dup"]
	buttons.append("lift")
	if sim.parts_open() and buttons.has("copy"):
		buttons.append("save")
	_pill = {"kind": "pick", "rect": pick_rect(), "buttons": buttons}
	_pill_at = _clock
	touched.emit(1.0)

## Where a template from the pick first stands: beside the pick, right,
## below, left or above, the first where it can go (right when none).
func _beside_pick(d: Dictionary) -> Vector2i:
	var r: Rect2i = _pill.rect
	var lo := Vector2i(Sim.W, Sim.H)
	for t: Vector2i in _picked:
		lo = lo.min(t)
	var w := int(d.w)
	var h := int(d.h)
	var tries := [lo + Vector2i(r.end.x - lo.x + 1, 0), lo + Vector2i(0, r.end.y - lo.y + 1), lo - Vector2i(w + 1 + lo.x - r.position.x, 0), lo - Vector2i(0, h + 1 + lo.y - r.position.y)]
	for t: Vector2i in tries:
		if sim.why_not_template(d, t, 0) == "":
			return t
	# with a dig in it: the nearest place about those where it can go
	for reach in [4, 8, 14]:
		for t: Vector2i in tries:
			var c := _snap_template(d, t, 0, reach)
			if sim.why_not_template(d, c, 0) == "":
				return c
	return tries[0]

## A pill button let go on: what it does.
func _pill_press(name: String) -> void:
	if _pill.is_empty():
		return
	var t: Vector2i = _pill.get("tile", Vector2i.ZERO)
	var kind := String(_pill.kind)
	var build := kind == "build"
	_btn_at[name] = _clock
	# a button whose deed the sim names (turn, lift, place) is heard through
	# that event alone; the others are heard here
	if name == "info" or name == "cancel" or name == "copy" or name == "dup" or (build and name == "turn"):
		touched.emit(float(PILL_PITCH.get(name, 1.0)))
	match name:
		"turn":
			if build and int(_ghost.kind) == Sim.PART:
				# a template turns about its middle
				var d: Dictionary = _ghost.tpl
				var nf := (int(_ghost.face) + 1) % 4
				var dz := Sim.turned_size(int(d.w), int(d.h), int(_ghost.face)) - Sim.turned_size(int(d.w), int(d.h), nf)
				_ghost.face = nf
				_move_template(Vector2i(_ghost.tile) + Vector2i(floori(dz.x / 2.0), floori(dz.y / 2.0)))
				_ghost_spin = _clock
			elif build:
				# a square machine turns on the squares it stands on
				var nf := (int(_ghost.face) + 1) % 4
				var nt: Vector2i = Sim.turned_root(int(_ghost.kind), _ghost.tile, int(_ghost.face), nf)
				_ghost.face = nf
				_ghost.tile = nt
				_pill.tile = nt
				_ghost_spin = _clock
			else:
				sim.mark()
				# a turn with no room is refused by the sim's own event
				if sim.turn(t):
					_pill.tile = sim.root_of(t)
		"flip":
			sim.mark()
			sim.flip_line(t)
		"lift":
			sim.mark()
			if kind == "pick":
				# a pick goes in one go; an Undo stands where it was a while
				var n: int = _pieces_in(_picked)
				var r: Rect2i = _pill.rect
				sim.lift_all(_picked)
				_close_pill()
				_pill = {"kind": "undone", "rect": r, "buttons": ["undo"], "n": n}
				_pill_at = _clock
				return
			sim.remove(t)
			_close_pill()
		"undo":
			sim.undo()
			_close_pill()
		"run", "line":
			sim.mark()
			sim.erase(sim.line_squares(t, name == "run"))
			_close_pill()
		"info":
			_close_pill()
			asked.emit(t)
		"copy", "dup":
			# Copy: the pick in hand, set down by a tap as often as wanted;
			# Duplicate: one ghost of it beside the pick, placed once
			var d: Dictionary = sim.template_of(_picked)
			var at := _beside_pick(d)
			_close_pill()
			if name == "copy":
				clip = d
				part_id = -1
				tool = "part"
			_set_template(d, at, 0, name == "dup")
			# the ghost may stand off the view: the view goes to it
			var sz := Vector2(int(d.w), int(d.h))
			if not view.grow(-40.0).encloses(Rect2(screen_of(Vector2(at)), sz * k)):
				look_at_square(Vector2(at) + sz * 0.5)
		"save":
			var id: int = sim.save_part(_picked)
			_close_pill()
			if id >= 0:
				part_saved.emit(id)
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
			if kd == Sim.PART:
				sim.stamp_template(_ghost.tpl, _ghost.tile, f)
			else:
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
		var cap := tr(String(PILL_CAP[nm]))
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
	_axis = -1
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
		if String(_pill.kind) != "build":
			_close_pill()
			_consumed = true
			return
	_down_at = _clock
	_picking = false
	match tool:
		"belt":
			var t := tile_under(p)
			if Sim.inside(t):
				_path = [t]
		"remove":
			sim.mark()
		_:
			if not _ghost.is_empty() and _ghost_squares().has(tile_under(p)):
				_drag_ghost = true
				_grab = tile_under(p) - Vector2i(_ghost.tile)

func drag(p: Vector2, was := Vector2.INF) -> void:
	if was == Vector2.INF:
		was = _at
	_at = p
	if _consumed:
		return
	if _picking:
		_moved = true
		_pick_b = tile_under(p).clamp(Vector2i.ZERO, Vector2i(Sim.W - 1, Sim.H - 1))
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
				var t := _snap(int(_ghost.kind), tile_under(p) - _grab)
				if Sim.inside(t) and t != Vector2i(_ghost.tile):
					if int(_ghost.kind) == Sim.PART:
						_move_template(t)
					else:
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
	if _picking:
		_end_pick()
		_drag_ghost = false
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
	if _finger == -99 or not _moved or _consumed or _drag_ghost or (tool != "belt" and tool != "remove" and not _picking):
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
	if _picking:
		_pick_b = tile_under(_at).clamp(Vector2i.ZERO, Vector2i(Sim.W - 1, Sim.H - 1))
	elif tool == "belt":
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
	if sim.straight:
		_trace_straight(t)
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

## Straight: the path is the run from its first square along the axis the
## finger first left it by, as far as the finger has gone along that axis;
## going back over the first square turns it round. A finger gone off that
## axis bends it once (the user, 2026-10-19: "if user moves finger up or
## down, it make a L shape"): the run to the finger's square along it, then
## a second leg across to the finger; back on the axis, the leg goes.
func _trace_straight(t: Vector2i) -> void:
	var p0: Vector2i = _path[0]
	var d := t - p0
	if _axis < 0:
		if d == Vector2i.ZERO:
			return
		_axis = 0 if absi(d.x) >= absi(d.y) else 1
	var n := d.x if _axis == 0 else d.y
	# off the axis by the finger itself, not its square: a quarter square of
	# slack past a row's edge before the line bends into it
	var off := squares_at(_at) - (Vector2(p0) + Vector2(0.5, 0.5))
	var across := off.y if _axis == 0 else off.x
	var m := int(signf(across) * floorf(absf(across) + 0.25))
	var step := Vector2i(signi(n), 0) if _axis == 0 else Vector2i(0, signi(n))
	var step2 := Vector2i(0, signi(m)) if _axis == 0 else Vector2i(signi(m), 0)
	_path = [p0]
	var out := false
	for j in absi(n):
		var nxt: Vector2i = (_path[-1] as Vector2i) + step
		if not Sim.inside(nxt):
			out = true
			break
		_path.append(nxt)
	if not out:
		for j in absi(m):
			var nxt: Vector2i = (_path[-1] as Vector2i) + step2
			if not Sim.inside(nxt):
				break
			_path.append(nxt)
	if m != 0 and not out:
		_trace_f = Sim.DIRS.find(step2)
	elif n != 0:
		_trace_f = Sim.DIRS.find(step)

## The traced path laid as the finger lifts, each square facing the next
## (the user, 2026-10-19: "keep it as preview until user release, no
## confirm dialog").
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
	var kd: int = sim.kind_at(t)
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
	var kd: int = sim.kind_at(t)
	var at := screen_of(Vector2(t) + Vector2(0.5, 0.5))
	if kd == Sim.BOX:
		box_asked.emit()
		return
	match tool:
		"move":
			if not _ghost.is_empty() and kd == Sim.EMPTY and int(_ghost.kind) == Sim.PART:
				# a Duplicate's ghost goes where the tap is
				_move_template(t)
				_pill_at = _clock
				touched.emit(1.0)
			elif kd != Sim.EMPTY:
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
		"part":
			var d := _held_template()
			if d.is_empty():
				touched.emit(0.85)
			elif kd == Sim.EMPTY or kd == Sim.BELT or kd == Sim.BRIDGE:
				var f := int(_ghost.face) if not _ghost.is_empty() else 0
				_set_template(d, t, f)
			else:
				_open_piece_pill(t)
		"turn":
			# the Rotate tool: a tap turns what it lands on, a quarter clockwise
			if kd == Sim.EMPTY:
				touched.emit(0.9)
			elif kd == Sim.BELT or TURNS.has(kd):
				sim.mark()
				sim.turn(t)
			else:
				refused.emit("no_turn", at, 0)
		_:
			var want := int(TOOL_KINDS[tool])
			if kd == Sim.EMPTY or kd == Sim.BELT or kd == Sim.BRIDGE:
				var f := int(_ghost.face) if not _ghost.is_empty() else place_face
				_set_ghost(want, _snap(want, t), f)
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
	_picking = false
	_picked = []
