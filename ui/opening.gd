extends Control

## The opening: what is on the screen from the game's first frame until the
## first screen is ready under it (world/boot.gd), in place of the black the
## game used to open on. It is the app icon coming together: DAILY over
## PUZZLES, the twelve letter tiles the first screen's header wears
## (ui/menu/word_tiles.gd), set down one at a time in reading order, each
## with a puff of light under it (and a pop, which world/boot.gd plays on
## `landed`). When the last is down the day's first Peeplet pops up from behind
## them and the kalimba notes ring. Warm motes of light drift up through it
## while it waits (cozy light has no shape: a mote is a round falloff and
## nothing else). Then a ripple of light runs over the tiles now and then,
## for as long as the first screen takes to load; told to `leave`, the tiles
## pop out in the run they came in and the paper thins to the first screen
## rising under it.
##
## The ground is GROUND, the app icon's own cream: the colour the phone's
## launch screen, the window behind the engine and the engine's first clear
## are all set to (docs/agents/opening.md), so the first tile lands on a
## screen that has been this colour since the icon was tapped.
##
## Everything is read off one clock (`clock`, in seconds since the first
## frame) through core/motion.gd's curve readers: a harness sets `auto` false
## and calls `step`. A tap asks to be let through (`skip`); nothing here
## decides when to go. Under reduce motion it stands finished from the first
## frame and leaves in a short plain fade.

## A tap on the opening: the player has seen it and wants the game.
signal skip
## The `rank`th tile (0 to 11, in the run they come in) has been set down.
## Nothing here plays a sound: world/boot.gd pops one on this.
signal landed(rank: int)
## The Peeplet is popping up behind the tiles: boot's two notes. Neither
## signal is sent under reduce motion or once leaving.
signal bloomed
## Gone: the paper has thinned to nothing and nothing here draws any more.
signal left

const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const GROUND_SHADER := preload("res://shaders/opening_ground_2d.gdshader")

## The app icon's ground (assets/icon/adaptive_background.png), six levels
## paler than the first screen's paper: too near to see in the fade.
const GROUND := Color("fcf5e9")
const MOTE := Color("ffc978")
const MOTE_HEART := Color("ffbe4a")
const PEACH := Color("ffd2a0")

## The layout, in the 1080 by 1920 the game is drawn for. The tiles are
## centred on the screen; `LIFT` is how far the light behind them sits above
## that. The Peeplet's picture is `PEEPLET` square, stands on the tiles' top
## edge and is `SINK` down behind it.
const WORD_TILE := 108.0
const LIFT := 150.0
const PEEPLET := 360.0
const SINK := 60.0
const SOFT_R := 64.0
const SOFT_RINGS := 18
const SOFT_SIDES := 48

## The score, in seconds from the first frame. A tile is `TILE_STEP` behind
## the one before it (the user, 2026-10-15: "the grid being built one by
## one"); it is down `TILE_TIME * TOUCH` after its own start, and that is its
## pop. The twelfth is the Peeplet's cue. SETTLED is when the last of it has
## landed: the soonest the opening is taken off unasked.
const TILE_AT := 0.1
const TILE_STEP := 0.085
const TILE_TIME := 0.32
const TOUCH := 0.37
## The whole word settles a hair under each tile set down.
const THUD := 0.012
const THUD_TIME := 0.2
## The light a tile puffs out from under itself as it lands.
const PUFF := Color("fff3d6")
const PUFF_TIME := 0.42
const PUFF_FROM := 0.9
const PUFF_TO := 1.75
## The Peeplet's pop up from behind the tiles: how far it rises as it grows,
## in px at 1080, and its time.
const PEEPLET_RISE := 60.0
const PEEPLET_TIME := 0.5
const SETTLED := TILE_AT + 12 * TILE_STEP + TILE_TIME + 0.4
const GLOW_TIME := 1.0
const MOTES_AT := 0.6
## Under reduce motion nothing lands; it is only looked at this long.
const HELD := 0.8
## The wait: a ripple of light over the tiles every so often.
const RIPPLE_EVERY := 2.6
const RIPPLE_STEP := 0.06
const RIPPLE_TIME := 0.36
const RIPPLE_LIGHT := 0.5
## Leaving: a tile is gone `LEAVE_STEP` after the one that came in after it,
## the Peeplet shrinks away over `LEAVE_PEEPLET`, the paper thins from
## GROUND_FROM, and it is all gone at LEAVE_TIME.
const LEAVE_STEP := 0.022
const LEAVE_PEEPLET := 0.2
const GROUND_FROM := 0.16
const LEAVE_TIME := 0.5
## The most one frame moves the clock: the frame the first screen is built
## in is a long one, and the opening waits for it rather than jumping.
const MAX_STEP := 0.05
const MOTE_COUNT := 16

## Seconds since the first frame.
var clock := 0.0
## False on an opening something else steps (a harness, with `step`).
var auto := true

var _leave_at := INF
var _gone := false
var _steps := 0
var _tiles: WordTiles
var _peeplet: Control
var _peeplet_tried := false
var _soft: ArrayMesh
var _mote: ArrayMesh
var _motes: Array = []
var _ground: ColorRect
var _ground_mat: ShaderMaterial

func _init() -> void:
	name = "Opening"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The paper and the light on it, under everything this draws.
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = GROUND_SHADER
	_ground_mat.set_shader_parameter("ground", GROUND)
	_ground_mat.set_shader_parameter("heart", Color(1.0, 1.0, 1.0, 0.75))
	_ground_mat.set_shader_parameter("skirt", Color(PEACH, 0.22))
	_ground_mat.set_shader_parameter("lit", 0.0)
	_ground = ColorRect.new()
	_ground.name = "Ground"
	_ground.color = GROUND
	_ground.material = _ground_mat
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.show_behind_parent = true
	_ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ground)
	# The twelve tiles, one WordTiles; `shown` is how many are down.
	_tiles = WordTiles.new()
	_tiles.name = "Tiles"
	_tiles.tile = WORD_TILE
	_tiles.shown = 0
	_tiles.size = _tiles.total_size()
	add_child(_tiles)
	var soft := Face.Builder.new()
	_soften(soft, Vector2.ZERO, SOFT_R, Color.WHITE)
	_soft = soft.mesh()
	var mote := Face.Builder.new()
	_soften(mote, Vector2.ZERO, SOFT_R, Color(MOTE, 0.34))
	_soften(mote, Vector2.ZERO, SOFT_R * 0.36, Color(MOTE_HEART, 0.95))
	_mote = mote.mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in MOTE_COUNT:
		_motes.append({
			"x": rng.randf_range(-500.0, 500.0), "at": rng.randf(),
			"rate": rng.randf_range(0.035, 0.075), "amp": rng.randf_range(10.0, 30.0),
			"turn": rng.randf_range(0.5, 1.2), "seed": rng.randf_range(0.0, TAU),
			"r": rng.randf_range(20.0, 40.0),
		})

func _process(delta: float) -> void:
	if auto:
		step(minf(delta, MAX_STEP))

func _gui_input(event: InputEvent) -> void:
	# The project has mouse-from-touch off: a finger is a ScreenTouch.
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		accept_event()
		skip.emit()

## Moves the clock on and draws; says `left` once the leaving is over.
func step(delta: float) -> void:
	var before := clock
	clock += delta
	_steps += 1
	queue_redraw()
	if not Motion.reduce and not leaving():
		for rank in WordTiles.count():
			var beat := touch_at(rank)
			if before < beat and beat <= clock:
				landed.emit(rank)
		if before < peeplet_at() and peeplet_at() <= clock:
			bloomed.emit()
	# The Peeplet is built on the frame its cue passes (under reduce motion,
	# on the second frame, so the first is the paper and the tiles): its load
	# is a long frame, which the clock waits out (MAX_STEP).
	if not _peeplet_tried and _steps > (1 if Motion.reduce else 0) and clock >= peeplet_at():
		_seat_peeplet()
	if not _gone and clock - _leave_at >= (Motion.REDUCED_TIME if Motion.reduce else LEAVE_TIME):
		_gone = true
		left.emit()

## Starts the leaving, from wherever the opening has got to.
func leave() -> void:
	if _leave_at == INF:
		_leave_at = clock

func leaving() -> bool:
	return _leave_at != INF

## When the `rank`th tile starts to come down.
static func drop_at(rank: int) -> float:
	return TILE_AT + rank * TILE_STEP

## When the `rank`th tile is down: its pop and its puff.
static func touch_at(rank: int) -> float:
	return drop_at(rank) + TILE_TIME * TOUCH

## When the Peeplet pops up: as the last tile is down.
static func peeplet_at() -> float:
	if Motion.reduce:
		return 0.0
	return touch_at(WordTiles.count() - 1)

## Whether the opening has played: the soonest it is taken off unasked.
func settled() -> bool:
	return clock >= (HELD if Motion.reduce else SETTLED)

## The day's first Peeplet, a held portrait behind the tiles. Loaded here,
## when it is wanted, and not preloaded: it is the heaviest thing the opening
## touches (docs/agents/opening.md has what it costs).
func _seat_peeplet() -> void:
	_peeplet_tried = true
	var view: Control = load("res://ui/peeplet_view.gd").new()
	load("res://core/cast.gd").dress(view, 0)
	view.frame_height = 0.88
	view.aim_y = 0.46
	view.idle_fps = 0.0
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.modulate.a = 0.0
	add_child(view)
	# Behind the tiles: its feet are under them.
	move_child(view, _tiles.get_index())
	_peeplet = view

# --- the drawing ---

func _draw() -> void:
	_ground.visible = not _gone
	if _gone:
		return
	var u := minf(size.x / 1080.0, size.y / 1920.0)
	var mid := Vector2(size.x * 0.5, size.y * 0.5 - LIFT * u)
	var away := clock - _leave_at
	# Under reduce motion the whole of it goes in one plain fade.
	var fade := 1.0 - clampf(away / Motion.REDUCED_TIME, 0.0, 1.0) if Motion.reduce else 1.0
	var ground := fade if Motion.reduce else 1.0 - smoothstep(GROUND_FROM, LEAVE_TIME, away)
	# The paper, and the light on it behind the tiles: a pale heart and a
	# warm skirt (shaders/opening_ground_2d.gdshader).
	_ground_mat.set_shader_parameter("size", size)
	_ground_mat.set_shader_parameter("heart_at", mid)
	_ground_mat.set_shader_parameter("heart_reach", 680.0 * u)
	_ground_mat.set_shader_parameter("skirt_at", mid + Vector2(0.0, 170.0) * u)
	_ground_mat.set_shader_parameter("skirt_reach", 1040.0 * u)
	_ground_mat.set_shader_parameter("lit", _eased(0.0, GLOW_TIME))
	_ground_mat.set_shader_parameter("level", ground)
	var t := 0.0 if Motion.reduce else clock
	_draw_motes(mid, u, t, ground)
	_lay_tiles(u, fade)
	_draw_lights(u, fade)
	_lay_peeplet(u, away, fade)

## How many tiles are down: all of them under reduce motion, else the ones
## whose time has come, less the ones the leaving has taken.
func _down() -> int:
	var n := WordTiles.count()
	if Motion.reduce:
		return n
	var arrived := clampi(floori((clock - touch_at(0)) / TILE_STEP) + 1, 0, n)
	if leaving():
		arrived = mini(arrived, n - floori((clock - _leave_at) / LEAVE_STEP))
	return maxi(arrived, 0)

## The tiles' place and how many are down, with the word's settle as each
## lands. Sized for this screen once; a new size redraws them.
func _lay_tiles(u: float, fade: float) -> void:
	var px := WORD_TILE * u
	if absf(_tiles.tile - px) > 0.01:
		_tiles.tile = px
	_tiles.size = _tiles.total_size()
	_tiles.position = ((size - _tiles.size) * 0.5).round()
	_tiles.pivot_offset = _tiles.size * 0.5
	var n := _down()
	_tiles.shown = n
	var thud := 1.0
	if n > 0 and not leaving() and not Motion.reduce:
		thud = Motion.bump_scale(clock - touch_at(n - 1), -THUD, THUD_TIME)
	_tiles.scale = Vector2.ONE * thud
	_tiles.modulate.a = fade

## The light under each tile: a puff as it lands, and the ripple that runs
## over the twelve in the wait. Both are behind the tiles, so what shows is
## the glow round their edges.
func _draw_lights(u: float, fade: float) -> void:
	if Motion.reduce:
		return
	var px := WORD_TILE * u
	var ripple := _ripple()
	for i in WordTiles.count():
		var at := _tiles.position + _tiles.size * 0.5 + (_tiles.tile_rect(i).get_center() - _tiles.size * 0.5) * _tiles.scale
		# The puff a tile pushes out from under it as it lands.
		var puff := (clock - touch_at(i)) / PUFF_TIME
		if puff > 0.0 and puff < 1.0:
			var grow := lerpf(PUFF_FROM, PUFF_TO, 1.0 - pow(1.0 - puff, 3.0)) * px * 0.5 / SOFT_R
			draw_mesh(_soft, null, Transform2D(0.0, Vector2.ONE * grow, 0.0, at),
				Color(PUFF, 0.85 * (1.0 - puff) * (1.0 - puff) * fade))
		# The ripple: the same light, fainter, from tile to tile.
		var wave := (ripple - i * RIPPLE_STEP) / RIPPLE_TIME
		if wave > 0.0 and wave < 1.0:
			var swell := lerpf(PUFF_FROM, PUFF_TO, sin(wave * PI * 0.5)) * px * 0.5 / SOFT_R
			draw_mesh(_soft, null, Transform2D(0.0, Vector2.ONE * swell, 0.0, at),
				Color(PUFF, RIPPLE_LIGHT * sin(wave * PI) * fade))

## The Peeplet, once it is built: it pops up from its feet behind the tiles'
## top edge, a little rising as it grows (`Motion.drop_in_lift`, from below),
## and shrinks back down behind them as they go. Its feet are under the tiles.
func _lay_peeplet(u: float, away: float, fade: float) -> void:
	if _peeplet == null:
		return
	var e := clock - peeplet_at()
	var side := PEEPLET * u
	_peeplet.size = Vector2.ONE * side
	_peeplet.pivot_offset = Vector2(side * 0.5, side)
	var rest := Vector2(_tiles.position.x + _tiles.size.x * 0.5 - side * 0.5, _tiles.position.y + SINK * u - side)
	_peeplet.position = rest - Vector2(0.0, Motion.drop_in_lift(e, -PEEPLET_RISE, PEEPLET_TIME) * u)
	var out := 1.0 if Motion.reduce or away <= 0.0 else Motion.pop_out_scale(away, LEAVE_PEEPLET)
	# Not quite nothing: a scale of nothing is a transform that cannot be
	# turned back.
	_peeplet.scale = (Motion.pop_in_scale(e, PEEPLET_TIME) * out).max(Vector2.ONE * 0.001)
	_peeplet.modulate.a = fade

## The motes: each rises through the block, swaying, and is brightest in the
## middle of its way.
func _draw_motes(mid: Vector2, u: float, t: float, ground: float) -> void:
	var shown := _eased(MOTES_AT, 0.6) * ground
	if shown <= 0.0:
		return
	for m: Dictionary in _motes:
		var along := fposmod(m.at + m.rate * t, 1.0)
		var at := mid + Vector2(m.x + sin(t * m.turn + m.seed) * m.amp, lerpf(700.0, -520.0, along)) * u
		var level := pow(sin(along * PI), 0.8) * (0.72 + 0.28 * sin(t * m.turn * 1.7 + m.seed)) * shown
		draw_mesh(_mote, null, Transform2D(0.0, Vector2.ONE * (m.r / SOFT_R * u), 0.0, at), Color(1.0, 1.0, 1.0, level))

# --- the clock's readers ---

## 0 to 1 over `time` from `at`, eased out; with `spring`, on the back ease,
## which overshoots. One under reduce motion.
func _eased(at: float, time: float, spring := false) -> float:
	if Motion.reduce:
		return 1.0
	var p := clampf((clock - at) / time, 0.0, 1.0)
	return Motion.back_out(p) if spring else 1.0 - pow(1.0 - p, 3.0)

## Seconds into the ripple now running over the tiles; below zero before
## the first, and once leaving.
func _ripple() -> float:
	var since := clock - SETTLED - 0.5
	if since < 0.0 or leaving():
		return -1.0
	return fmod(since, RIPPLE_EVERY)

# --- the meshes ---

## Joins two outlines of one count, already in `b`, in a band.
static func _band(b: Face.Builder, a: int, o: int, n: int) -> void:
	for i in n:
		var j := (i + 1) % n
		b.tri(a + i, o + i, o + j)
		b.tri(a + i, o + j, a + j)

## A light with no edge, into `b`: `colour` at `c`, thinning to nothing at
## `r` along a curve level at both ends (ui/motes.gd's glow, in more rings:
## these are drawn large).
static func _soften(b: Face.Builder, c: Vector2, r: float, colour: Color) -> void:
	var heart := b.vertex(c, colour)
	var first := b.verts.size()
	for ring in SOFT_RINGS:
		var t := float(ring + 1) / SOFT_RINGS
		var tint := Color(colour, colour.a * pow(cos(t * PI * 0.5), 2.0))
		for k in SOFT_SIDES:
			b.vertex(c + Vector2.from_angle(TAU * k / SOFT_SIDES) * r * t, tint)
	for k in SOFT_SIDES:
		b.tri(heart, first + k, first + (k + 1) % SOFT_SIDES)
	for ring in SOFT_RINGS - 1:
		_band(b, first + ring * SOFT_SIDES, first + (ring + 1) * SOFT_SIDES, SOFT_SIDES)
