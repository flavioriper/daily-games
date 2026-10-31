extends Control

## The air hockey table as the players see it, standing on end: the wooden
## frame with a goal's slot cut in each short rail, the pale top with its
## air holes and painted lines (baked once into one mesh, rebuilt only when
## the table is resized), and over it one live mesh a frame for the puck,
## the two mallets, their shadows and whatever just happened.
##
## The table is the house's (2026-10-10): the sprout painted in the middle
## circle and stamped in cream on the puck, a sprig painted in two corners of
## the top, a pool of warm lamplight over the cool one, brass studs at the
## frame's corners and a brass inlay in each long rail where the middle line
## meets it. The gold mallet carries the sun's rays round its skirt as dots
## and the blue one the moon's crescent on its knob.
##
## The pieces take the game's soft painted cel (docs/art/shading-direction.md):
## a coloured shadow rather than a black one, a darker body with the lit face
## laid over it toward the light, one small highlight, no outline. The bottom
## mallet is the sun's gold and the top one the moon's blue, the two sides
## every Versus scoreboard already has. **The three pieces are built once a
## resize** (`_build_pieces`) and laid into the live mesh under a transform:
## their vertices head the mesh, so their indices never change, and a squash,
## a hop or a slump is that transform and nothing else. Nothing drawn here is
## ever read back by the sim.
##
## The moments, all in the live mesh, none under reduce motion, all light
## soft and round (`Scenery.soft_disc`): a strike squashes the mallet along
## the blow, stretches the puck and leaves a pulse of the striker's light; a
## rail gives a little under the puck, which flattens against it; a fast puck
## trails the light of whoever struck it last and sheds motes of it; a goal
## lights the mouth and the slot in the scorer's colour and sends motes back
## up the table while the puck sinks, the scorer's mallet hops and the other
## one sags with a shake; the puck is set down with a pop and a ring of light;
## a block right in front of the goal rings the crease; at match point the
## mouth the leader shoots at breathes their light; the last goal runs light
## down both long rails to the winner's end and the winner hops three times;
## and while the puck lies still the mallets breathe and the puck glows.
##
## Input: a finger anywhere on the table leads a mallet, which rides a little
## ahead of it (LIFT) so the thumb does not cover what it is steering. With
## one hand (`hands` [true, false]) every touch is the bottom mallet's. With
## two (`hands` [true, true], two players on one phone) a press belongs to
## the half it lands in, one finger a mallet. The table only says where each
## hand wants its mallet (`sim.aim`); the sim moves it.

## A finger came down for `seat`.
signal touched(seat: int)
## A save was made in front of `seat`'s goal.
signal saved(seat: int)

const Sim = preload("res://versus/hockey_sim.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The wooden rail round the top, metres, and its corner.
const RAIL := 0.062
const FRAME_R := 0.085
## How far ahead of the finger its mallet rides, metres.
const LIFT := 0.085
## The air holes' pitch, metres.
const HOLES := 0.064

const TOP := Color("eef3ea")
const TOP_LIT := Color("fbfdf8")
const TOP_EDGE := Color("d5dfd3")
const HOLE_DOT := Color(0.32, 0.42, 0.4, 0.2)
const WOOD := Color("9a6540")
const WOOD_LIT := Color("b98052")
const WOOD_DEEP := Color("64402a")
const LIP := Color("f6ead2")
const SLOT := Color("2a1c14")
const INK := Color(0.3, 0.6, 0.57, 0.5)
## The lamp's warmth on the top, the brass in the frame, the cream of the
## puck's stamp and the cream every light here has at its heart.
const LAMP := Color("fff0cf")
const BRASS := Color("d9a441")
const STAMP := Color("fbeedd")
const HALO := Color("fff6e0")
## The two sides: the body, its lit face, its shade.
const SIDE := [
	[Color("f5a623"), Color("fbc75c"), Color("c97c12")],
	[Color("7d8fd9"), Color("a9b6ec"), Color("5262ad")],
]
const PUCK := Color("3f4652")
const PUCK_LIT := Color("5a6272")
const PUCK_DEEP := Color("2b303a")
const SHADOW := Color(0.2, 0.26, 0.3, 0.22)
const LIGHT := Vector2(-0.45, -0.6)
## The motion: how many frames of trail a fast puck leaves and the speed under
## which it has none, how long a contact's light and a goal's glow last, and
## how long a struck mallet takes to settle.
const TRAIL := 8
const TRAIL_SPEED := 1.4
const FLASH := 0.3
const GLOW := 0.9
const BUMP := 0.22
## A strike as hard as a strike gets, m/s closing: the screen's FULL_HIT, what
## `flash`'s strength is a share of.
const FULL := 6.0
## How far a mallet squashes along a full blow and the puck stretches off it
## (shares of their size), and how far the lip of a rail gives, pixels.
const SQUASH := 0.14
const STRETCH := 0.2
const GIVE := 5.0
## Motes: one shed every MOTE_EVERY seconds by a puck over MOTE_SPEED, each
## living MOTE_LIFE; a goal sends GOAL_MOTES back up the table. Never more
## than MOTES at once.
const MOTE_EVERY := 0.05
const MOTE_SPEED := 2.4
const MOTE_LIFE := 0.6
const GOAL_MOTES := 9
const MOTES := 40
## A block counts as a save inside SAVE_NEAR of its own goal's middle when
## the puck came at it at SAVE_SPEED or more on a line that ends in the
## mouth; the crease rings for SAVE_TIME.
const SAVE_NEAR := 0.45
const SAVE_SPEED := 1.4
const SAVE_TIME := 0.6
## The scorer's hop and the winner's three (pixels a hop_lift is scaled to),
## how far the other mallet sags, and how long light takes down the rails.
const CHEER := 1.6
const WIN_HOPS := 3
const SLUMP := 0.09
const LAP := 1.3
const LAP_MOTES := 6
## A puck slower than STILL for STILL_WAIT seconds is lying still: the
## mallets breathe by BREATH of their size every BREATH_TIME seconds and the
## puck glows. Match point's glow breathes on the same clock.
const STILL := 0.05
const STILL_WAIT := 0.8
const BREATH := 0.025
const BREATH_TIME := 2.4
## A token's bob and how long before it goes it starts to blink; the rings
## that say how long a power has left; the table's jolt on a goal.
const TOKEN_R := 0.07
const BLINK := 2.5
const POWER_RING := 0.02
const QUAKE_TIME := 0.32

var sim: RefCounted
## Which seats a finger leads.
var hands := [true, false]
var interactive := false
## A picture, not a game (the Versus tab's card): drawn once per resize.
var still := false

var ppm := 100.0
var origin := Vector2.ZERO
var _table: ArrayMesh
var _live: ArrayMesh
var _shown: Array = []
## The pieces as built at this size about their own middles -- the puck, the
## gold mallet, the blue one: each one's vertices, all their colours in a
## run, and each one's indices as they stand at the head of the live mesh.
var _piece_verts: Array = []
var _piece_cols := PackedColorArray()
var _piece_idx: Array = []
## The touch leading each seat (-1 none; MOUSE for the desktop's pointer).
var _finger := [-1, -1]
const MOUSE := 99
var _trail: Array[Vector2] = []
## Lights still showing: {kind ("mallet", "wall", "post", "save"), at
## (metres), t, life, strength, seat, n (into the table from a rail)}.
var _flashes: Array = []
## Each goal's glow, seconds left (the goal at the bottom is 0).
var _glow := [0.0, 0.0]
## Each mallet's squash after a hit: seconds left, which way and how hard.
var _bump := [0.0, 0.0]
var _bump_n := [Vector2.UP, Vector2.DOWN]
var _bump_by := [0.0, 0.0]
## The puck dropping into a goal: where from, into which end, seconds in.
var _sink := {}
## The puck's own squash: seconds since, along what, how hard, and whether it
## stretches (off a mallet) or flattens (on a rail).
var _puck_t := 99.0
var _puck_n := Vector2.UP
var _puck_by := 0.0
var _puck_long := true
## Soft lights adrift: {at, vel (metres), t, life, r (metres), col}.
var _motes: Array = []
var _mote_due := 0.0
var _rng := RandomNumberGenerator.new()
## Seconds since the puck was last set down, since the last goal and who
## scored it, how far each mallet has sagged, how long the puck has lain
## still, and the clock the breathing goes by. Every one runs out by itself.
var _serve_t := 99.0
var _goal_t := 99.0
var _goal_by := -1
var _slump := [0.0, 0.0]
var _still_t := 0.0
var _clock := 0.0
var _was_on := true
var _sim_seen: RefCounted
var _quake_at := -10.0
var _quake_px := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still else Control.MOUSE_FILTER_STOP
	_rng.seed = 5
	resized.connect(_relayout)
	_relayout()

func _relayout() -> void:
	var span := Vector2(Sim.W, Sim.L) + Vector2.ONE * 2.0 * RAIL
	if size.x <= 0.0 or size.y <= 0.0:
		return
	ppm = minf(size.x / span.x, size.y / span.y)
	origin = (size - span * ppm) * 0.5 + Vector2.ONE * RAIL * ppm
	_table = null
	queue_redraw()

func px(p: Vector2) -> Vector2:
	return origin + p * ppm

func metres(p: Vector2) -> Vector2:
	return (p - origin) / ppm

## The table's outer rectangle in this control's pixels.
func frame_rect() -> Rect2:
	return Rect2(origin - Vector2.ONE * RAIL * ppm, Vector2(Sim.W, Sim.L) * ppm + Vector2.ONE * 2.0 * RAIL * ppm)

func _process(delta: float) -> void:
	if still:
		return
	for f in _flashes:
		f.t += delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return f.t < float(f.life))
	for m in _motes:
		m.t += delta
		m.at += m.vel * delta
	_motes = _motes.filter(func(m: Dictionary) -> bool: return m.t < float(m.life))
	for k in 2:
		_glow[k] = maxf(0.0, _glow[k] - delta)
		_bump[k] = maxf(0.0, _bump[k] - delta)
	if not _sink.is_empty():
		_sink.t += delta
		if _sink.t > 0.3:
			_sink = {}
	_clock += delta
	_puck_t += delta
	_serve_t += delta
	_goal_t += delta
	if sim != null:
		# The puck set down: a new match's first, or the one after a goal.
		if sim != _sim_seen or (sim.puck_on and not _was_on):
			if sim != _sim_seen:
				_goal_t = 99.0
				_goal_by = -1
			_sim_seen = sim
			_serve_t = 0.0 if sim.puck_on else 99.0
			_still_t = 0.0
		_was_on = sim.puck_on
		var lying: bool = sim.puck_on and not sim.over and sim.puck_vel.length() < STILL
		_still_t = _still_t + delta if lying else 0.0
		for k in 2:
			var sag: bool = not sim.puck_on and _goal_by == 1 - k and _goal_t < 90.0 and not Motion.reduce
			_slump[k] = move_toward(_slump[k], 1.0 if sag else 0.0, delta / Motion.DROP_TIME)
	_track_trail(delta)
	queue_redraw()

func _track_trail(delta: float) -> void:
	if sim == null or Motion.reduce:
		_trail.clear()
		_motes.clear()
		return
	var speed: float = sim.puck_vel.length() if sim.puck_on else 0.0
	if speed > TRAIL_SPEED:
		_trail.append(sim.puck)
		if _trail.size() > TRAIL:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
	_mote_due -= delta
	if speed > MOTE_SPEED and _mote_due <= 0.0:
		_mote_due = MOTE_EVERY
		var back: Vector2 = -sim.puck_vel.normalized()
		_mote(sim.puck + back * Sim.PUCK_R * 0.6 + back.orthogonal() * _rng.randf_range(-0.6, 0.6) * Sim.PUCK_R,
			back * 0.12 + Vector2.from_angle(_rng.randf() * TAU) * 0.05, MOTE_LIFE * _rng.randf_range(0.7, 1.0),
			_rng.randf_range(0.012, 0.02), _touch_tint())

func _mote(at: Vector2, vel: Vector2, life: float, r: float, col: Color) -> void:
	if _motes.size() >= MOTES:
		_motes.pop_front()
	_motes.append({"at": at, "vel": vel, "t": 0.0, "life": life, "r": r, "col": col})

## The light of whoever struck the puck last; the lamp's before anyone has.
func _touch_tint() -> Color:
	var who: int = sim.last_touch
	return SIDE[who][0] if who >= 0 else LAMP.darkened(0.12)

## A contact the players should see: "mallet" (with its seat), "wall", "post".
## `strength` is the closing speed as a share of FULL.
func flash(kind: String, at: Vector2, strength: float, seat := -1) -> void:
	var s := clampf(strength, 0.15, 1.0)
	if seat >= 0:
		_bump[seat] = BUMP
		_bump_by[seat] = s
		var away: Vector2 = at - sim.mallet[seat]
		_bump_n[seat] = away.normalized() if away.length() > 0.0001 else Vector2.UP
	if Motion.reduce:
		return
	# Into the table from the rail that was struck; off the mallet for a blow.
	var n := Vector2.ZERO
	if seat >= 0:
		n = _bump_n[seat]
	elif kind == "wall":
		if at.x <= 0.001:
			n = Vector2.RIGHT
		elif at.x >= Sim.W - 0.001:
			n = Vector2.LEFT
		else:
			n = Vector2.DOWN if at.y < Sim.L * 0.5 else Vector2.UP
	else:
		n = Vector2.DOWN if at.y < Sim.L * 0.5 else Vector2.UP
	_puck_t = 0.0
	_puck_n = n
	_puck_by = s
	_puck_long = seat >= 0
	_flashes.append({"kind": kind, "at": at, "t": 0.0, "life": FLASH, "strength": s, "seat": seat, "n": n})
	# A block in front of its own goal, the puck having come at the mouth:
	# the blow's own line, carried on behind the mallet, ends between the posts.
	var own: Vector2 = Sim.goal_of(seat) if seat >= 0 else Vector2.ZERO
	if seat >= 0 and at.distance_to(own) < SAVE_NEAR and absf(n.y) > 0.3 and signf(n.y) == signf(at.y - own.y) \
			and absf(at.x + n.x * (own.y - at.y) / n.y - own.x) < Sim.GOAL_HALF \
			and strength * FULL - sim.mallet_vel[seat].length() >= SAVE_SPEED:
		_flashes.append({"kind": "save", "at": Sim.goal_of(seat), "t": 0.0, "life": SAVE_TIME, "strength": s, "seat": seat, "n": n})
		saved.emit(seat)

## The puck went in at `end` (0 the bottom goal) from `at`.
func goal(end: int, at: Vector2) -> void:
	_glow[end] = GLOW
	_trail.clear()
	if Motion.reduce:
		return
	_sink = {"from": at, "end": end, "t": 0.0}
	_goal_t = 0.0
	_goal_by = 1 - end
	# The scorer's light comes back up the table out of the mouth.
	var up := Vector2.UP if end == 0 else Vector2.DOWN
	for k in GOAL_MOTES:
		var x := Sim.W * 0.5 + _rng.randf_range(-1.0, 1.0) * Sim.GOAL_HALF * 0.85
		_mote(Vector2(x, Sim.goal_of(end).y) + up * _rng.randf_range(0.0, 0.05),
			up * _rng.randf_range(0.12, 0.34) + Vector2(_rng.randf_range(-0.06, 0.06), 0.0),
			_rng.randf_range(0.6, 1.1), _rng.randf_range(0.014, 0.026), SIDE[1 - end][1])

## The table jolts by `by` pixels: a goal.
func quake(by: float) -> void:
	if Motion.reduce:
		return
	_quake_at = _clock
	_quake_px = by

## Nobody is leading a mallet any more (a goal, the end, a card going up).
func let_go() -> void:
	_finger = [-1, -1]

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if not interactive or sim == null:
		return
	var id := -1
	var press := false
	var release := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		id = event.index
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag:
		id = event.index
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		id = MOUSE
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		id = MOUSE
		at = event.position
	else:
		return
	accept_event()
	var seat := _finger.find(id)
	if release:
		if seat != -1:
			_finger[seat] = -1
		return
	if press and seat == -1:
		seat = _seat_for(at)
		if seat == -1 or _finger[seat] != -1:
			return
		_finger[seat] = id
		touched.emit(seat)
	if seat == -1:
		return
	var lift := Vector2(0.0, -LIFT if seat == 0 else LIFT)
	sim.aim[seat] = Sim.clamp_half(seat, metres(at) + lift)

## Whose press this is: with one hand always the bottom mallet's, with two
## the half it landed in.
func _seat_for(at: Vector2) -> int:
	if hands[0] and hands[1]:
		return 0 if metres(at).y >= Sim.L * 0.5 else 1
	if hands[0]:
		return 0
	return 1 if hands[1] else -1

# --- drawing ---

func _draw() -> void:
	if sim == null or size.x <= 0.0:
		return
	if _table == null:
		_table = _build_table()
		_build_pieces()
	var since := _clock - _quake_at
	if since < QUAKE_TIME and not still:
		draw_set_transform(Vector2(Motion.shiver_offset(since, _quake_px, QUAKE_TIME), Motion.nudge_offset(since, _quake_px * 0.7, QUAKE_TIME, 0.0)))
	draw_mesh(_table, null)
	_live = _build_live()
	draw_mesh(_live, null)
	_shown = [_table, _live]

func _build_table() -> ArrayMesh:
	var b := Face.Builder.new()
	var outer := frame_rect()
	var r := FRAME_R * ppm
	var top := Rect2(origin, Vector2(Sim.W, Sim.L) * ppm)
	# The table's own shadow on the deck, soft and warm.
	for k in 4:
		var grow := 6.0 + k * 7.0
		b.fan(Face.Builder.round_rect(outer.position + Vector2(-grow * 0.5, 18.0 - grow * 0.2),
			outer.size + Vector2(grow, grow * 0.6), r + grow), Color(0.24, 0.13, 0.07, 0.09))
	# The wooden frame: a deep base, the lit top, the grain.
	b.fan(Face.Builder.round_rect(outer.position + Vector2(0.0, 7.0), outer.size, r), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(outer.position, outer.size, r), WOOD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 26:
		var long := k % 2 == 0
		var side := 1.0 if (k / 2) % 2 == 0 else 0.0
		var t := rng.randf_range(0.08, 0.72)
		var len := rng.randf_range(0.1, 0.22)
		var off := rng.randf_range(0.2, 0.8) * RAIL * ppm
		var a: Vector2
		var d: Vector2
		if long:
			a = Vector2(outer.position.x + off + side * (outer.size.x - RAIL * ppm), outer.position.y + outer.size.y * t)
			d = Vector2(0.0, outer.size.y * len)
		else:
			a = Vector2(outer.position.x + outer.size.x * t, outer.position.y + off + side * (outer.size.y - RAIL * ppm))
			d = Vector2(outer.size.x * len, 0.0)
		b.stroke(PackedVector2Array([a, a + d]), 2.0, Color(WOOD_LIT if k % 3 != 0 else WOOD_DEEP, 0.4), false, true)
	b.stroke(Face.Builder.round_rect(outer.position + Vector2.ONE * 3.0, outer.size - Vector2.ONE * 6.0, r - 3.0),
		2.5, Color(WOOD_LIT, 0.7), true, false)
	# The brass: a stud at each corner of the frame, and an inlay in each long
	# rail where the middle line meets it.
	var half_rail := RAIL * ppm * 0.5
	for cx in 2:
		for cy in 2:
			_stud(b, outer.position + Vector2(outer.size.x * cx, outer.size.y * cy)
				+ Vector2(1.0 - 2.0 * cx, 1.0 - 2.0 * cy) * half_rail * 1.15, half_rail * 0.3)
		var mx := outer.position.x + half_rail + cx * (outer.size.x - RAIL * ppm)
		var my := origin.y + Sim.L * ppm * 0.5
		var plate := Vector2(half_rail * 0.62, half_rail * 2.3)
		b.fan(Face.Builder.round_rect(Vector2(mx, my + 1.5) - plate * 0.5, plate, plate.x * 0.5), BRASS.darkened(0.35))
		b.fan(Face.Builder.round_rect(Vector2(mx, my) - plate * 0.5, plate, plate.x * 0.5), BRASS)
		b.stroke(PackedVector2Array([Vector2(mx - plate.x * 0.16, my - plate.y * 0.32), Vector2(mx - plate.x * 0.16, my + plate.y * 0.1)]),
			maxf(1.5, plate.x * 0.16), Color(1, 1, 1, 0.4))
	# The top's well: a dark edge, the cream lip, then the top itself.
	var well := 0.016 * ppm
	b.fan(Face.Builder.round_rect(top.position - Vector2.ONE * (well + 4.0), top.size + Vector2.ONE * (well + 4.0) * 2.0, well + 8.0), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(top.position - Vector2.ONE * well, top.size + Vector2.ONE * well * 2.0, well + 4.0), LIP)
	# The goals: a slot through the lip into the rail, trimmed in its side's colour.
	for end in 2:
		var y := origin.y + (Sim.L * ppm if end == 0 else 0.0)
		var out := 1.0 if end == 0 else -1.0
		var half := Sim.GOAL_HALF * ppm
		var deep := RAIL * ppm * 0.7
		var at := Vector2(origin.x + Sim.W * ppm * 0.5 - half, y if end == 0 else y - deep)
		b.fan(Face.Builder.round_rect(at - Vector2(5.0, 0.0 if end == 0 else 5.0), Vector2(half * 2.0 + 10.0, deep + 5.0), 9.0), SIDE[end][2])
		b.fan(Face.Builder.round_rect(at, Vector2(half * 2.0, deep), 6.0), SLOT)
		b.fan(Face.Builder.round_rect(at + Vector2(6.0, 6.0 if end == 0 else 0.0), Vector2(half * 2.0 - 12.0, deep - 6.0), 5.0), Color("1a100a"))
		# the mouth through the lip
		b.fan(PackedVector2Array([Vector2(at.x, y), Vector2(at.x + half * 2.0, y),
			Vector2(at.x + half * 2.0, y + out * (well + 1.0)), Vector2(at.x, y + out * (well + 1.0))]), SLOT)
	b.fan(Face.Builder.round_rect(top.position, top.size, 7.0), TOP_EDGE)
	b.fan(Face.Builder.round_rect(top.position + Vector2.ONE * 3.0, top.size - Vector2.ONE * 6.0, 6.0), TOP)
	# Lit from its middle, falling off toward the rails; and the lamp's own
	# warm pool over that.
	var mid := top.get_center()
	for k in 12:
		var f := 1.0 - k * 0.075
		b.ellipse(mid + Vector2(-top.size.x * 0.04, -top.size.y * 0.05), top.size.x * 0.49 * f, top.size.y * 0.47 * f, Color(TOP_LIT, 0.07))
	Scenery.soft_disc(b, mid, top.size.x * 0.5, top.size.y * 0.42, Color(LAMP, 0.5))
	# The air holes.
	var nx := int(floor(Sim.W / HOLES))
	var ny := int(floor(Sim.L / HOLES))
	var dot := maxf(1.2, ppm * 0.0028)
	for i in nx:
		for j in ny:
			var p := Vector2((i + 0.5) * Sim.W / nx, (j + 0.5) * Sim.L / ny)
			b.fan(_square(px(p), dot), HOLE_DOT)
	# A sprig painted in two corners, the way the lines are.
	var leaf_ink := Color(INK, 0.3)
	_sprig(b, px(Vector2(0.035, 0.035)), ppm * 0.0052, Vector2(1.0, 1.0), leaf_ink)
	_sprig(b, px(Vector2(Sim.W - 0.035, Sim.L - 0.035)), ppm * 0.0052, Vector2(-1.0, -1.0), leaf_ink)
	# The lines: the middle, its circle with the house's sprout in it, a ring
	# to face off in each quarter, and each goal's crease in its side's colour.
	var w := maxf(2.5, ppm * 0.007)
	b.stroke(PackedVector2Array([px(Vector2(0.0, Sim.L * 0.5)), px(Vector2(Sim.W, Sim.L * 0.5))]), w, INK, false, false)
	b.disc(px(Vector2(Sim.W, Sim.L) * 0.5), 0.132 * ppm, Color(TOP, 1.0))
	b.stroke(Face.Builder.ring(px(Vector2(Sim.W, Sim.L) * 0.5), 0.13 * ppm, 0.13 * ppm), w, INK, true, false)
	_sprout(b, px(Vector2(Sim.W, Sim.L) * 0.5) + Vector2(0.0, 0.006 * ppm), ppm * 0.0042, Color(INK, 0.32))
	for end in 2:
		var tint: Color = SIDE[end][0]
		var gy := Sim.L if end == 0 else 0.0
		var crease := Face.Builder.arc_points(px(Vector2(Sim.W * 0.5, gy)), (Sim.GOAL_HALF + 0.06) * ppm,
			PI if end == 0 else 0.0, TAU if end == 0 else PI)
		b.fan(crease, Color(tint, 0.13))
		b.stroke(crease, w, Color(tint, 0.62), false, false)
		for sx in [0.25, 0.75]:
			var c := px(Vector2(Sim.W * sx, Sim.L * (0.74 if end == 0 else 0.26)))
			b.stroke(Face.Builder.ring(c, 0.085 * ppm, 0.085 * ppm), w * 0.8, Color(INK, 0.34), true, false)
			b.disc(c, 0.011 * ppm, Color(INK, 0.4))
	return b.mesh()

static func _square(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

## A brass stud in the wood, lit from the lamp's side.
static func _stud(b: Face.Builder, c: Vector2, r: float) -> void:
	b.disc(c + Vector2(0.0, r * 0.3), r, BRASS.darkened(0.4))
	b.disc(c, r, BRASS)
	b.disc(c + LIGHT * r * 0.4, r * 0.3, Color(1, 1, 1, 0.55))

## A leaf from its foot to its tip, `bulge` wide at the middle.
static func _leaf(b: Face.Builder, foot: Vector2, tip: Vector2, bulge: float, col: Color) -> void:
	var mid := (foot + tip) * 0.5
	var n := (tip - foot).orthogonal().normalized() * bulge
	var pts := Face.Builder.bezier2(foot, mid + n, tip, 8)
	pts.append_array(Face.Builder.bezier2(tip, mid - n, foot, 8))
	b.fan(pts, col)

## The house's sprout about `c`: a stem and its two leaves, `k` times 30 tall
## (the one stamped on the dominoes' backs).
static func _sprout(b: Face.Builder, c: Vector2, k: float, col: Color) -> void:
	b.stroke(Face.Builder.bezier2(c + Vector2(1.0, 16.0) * k, c + Vector2(-3.0, 6.0) * k, c + Vector2(0.0, -4.0) * k, 6), 3.4 * k, col)
	_leaf(b, c + Vector2(0.0, -3.0) * k, c + Vector2(-17.0, -17.0) * k, 9.0 * k, col)
	_leaf(b, c + Vector2(0.0, -1.0) * k, c + Vector2(14.0, -12.0) * k, 7.0 * k, col)

## A sprig out of a corner at `c`: a stem curving along the diagonal `way`
## with three leaves a side, `k` pixels a unit.
static func _sprig(b: Face.Builder, c: Vector2, k: float, way: Vector2, col: Color) -> void:
	var tip := c + Vector2(26.0, 20.0) * way * k
	var stem := Face.Builder.bezier2(c, c + Vector2(18.0, 4.0) * way * k, tip, 10)
	stem.append(tip)
	b.stroke(stem, 1.6 * k, col)
	for i in 3:
		var foot := stem[2 + i * 3]
		var along := (stem[3 + i * 3] - foot).normalized()
		var size_by := 1.0 - i * 0.18
		_leaf(b, foot, foot + (along * 6.0 + along.orthogonal() * 7.0) * k * size_by, 2.6 * k * size_by, col)
		_leaf(b, foot, foot + (along * 6.0 - along.orthogonal() * 7.0) * k * size_by, 2.6 * k * size_by, col)
	_leaf(b, tip, tip + (tip - stem[8]).normalized() * 8.0 * k, 2.4 * k, col)

## The three pieces about their own middles at this size, kept as arrays: the
## live mesh opens with their vertices every frame, so these indices hold.
func _build_pieces() -> void:
	_piece_verts.clear()
	_piece_idx.clear()
	_piece_cols = PackedColorArray()
	var base := 0
	for i in 3:
		var b := Face.Builder.new()
		if i == 0:
			_puck(b)
		else:
			_mallet(b, i - 1)
		var ix := b.idx
		for k in ix.size():
			ix[k] += base
		_piece_verts.append(b.verts)
		_piece_cols.append_array(b.cols)
		_piece_idx.append(ix)
		base += b.verts.size()

## A piece's place: at `at`, `along` times its size along `n` and `across`
## times across it. A stretch, not a turn: the lit side stays where it was.
static func _place(at: Vector2, n: Vector2, along: float, across: float) -> Transform2D:
	var turn := Transform2D(n.angle(), Vector2.ZERO)
	return Transform2D(0.0, at) * turn * Transform2D(0.0, Vector2(along, across), 0.0, Vector2.ZERO) * turn.affine_inverse()

## A fan lit at `centre` and clear along `rim`, an open run of points: half a
## soft disc, for light that must stop at a rail.
static func _soft_fan(b: Face.Builder, centre: Vector2, rim: PackedVector2Array, colour: Color) -> void:
	var first := b.verts.size()
	b.verts.append(centre)
	b.cols.append(colour)
	var clear := Color(colour, 0.0)
	for p in rim:
		b.verts.append(p)
		b.cols.append(clear)
	for i in rim.size() - 1:
		b.idx.append(first)
		b.idx.append(first + 1 + i)
		b.idx.append(first + 2 + i)

## A soft light with the cream at its heart.
static func _glow_at(b: Face.Builder, at: Vector2, r: float, col: Color, level: float) -> void:
	Scenery.soft_disc(b, at, r, r, Color(col, col.a * level))
	Scenery.soft_disc(b, at, r * 0.5, r * 0.5, Color(HALO, 0.8 * level))

## The breath every idle thing here takes, -1 to 1.
func _breath(lag := 0.0) -> float:
	return sin((_clock / BREATH_TIME + lag) * TAU)

## Where light is `d` metres along the lip from the middle of the goal at
## `end`, round by the `side` rail (-1 the left) to the middle of the other.
func _rim(end: int, side: float, d: float) -> Vector2:
	var near := Sim.L if end == 0 else 0.0
	var far := Sim.L - near
	var x := Sim.W * 0.5 + side * Sim.W * 0.5
	if d < Sim.W * 0.5:
		return px(Vector2(Sim.W * 0.5 + side * d, near))
	d -= Sim.W * 0.5
	if d < Sim.L:
		return px(Vector2(x, lerpf(near, far, d / Sim.L)))
	d -= Sim.L
	return px(Vector2(x - side * minf(d, Sim.W * 0.5), far))

func _build_live() -> ArrayMesh:
	var b := Face.Builder.new()
	var moving: bool = not Motion.reduce and not still
	var lying: bool = moving and _still_t > STILL_WAIT
	var shade := Vector2(0.009, 0.016) * ppm
	var puck_r := Sim.PUCK_R * ppm
	var mallet_r := Sim.MALLET_R * ppm

	# --- where each piece stands this frame (drawn only) ---
	var puck_shown: bool = sim.puck_on or not _sink.is_empty()
	var puck_at := px(sim.puck)
	var puck_size := 1.0
	var puck_pop := Vector2.ONE
	var puck_lift := 0.0
	if sim.puck_on:
		if moving:
			# Set down: it pops onto the table from a little above it.
			puck_pop = Motion.pop_in_scale(_serve_t)
			puck_lift = Motion.drop_in_lift(_serve_t, Motion.DROP * 0.4)
	elif puck_shown:
		var u2: float = clampf(float(_sink.t) / 0.3, 0.0, 1.0)
		var gy2 := Sim.L + RAIL * 0.4 if int(_sink.end) == 0 else -RAIL * 0.4
		puck_at = px((_sink.from as Vector2).lerp(Vector2((_sink.from as Vector2).x, gy2), u2))
		puck_size = 1.0 - 0.75 * u2
	var puck_sq := Motion.bump_scale(_puck_t, STRETCH * _puck_by, BUMP) - 1.0
	var puck_xf := _place(puck_at - Vector2(0.0, puck_lift), _puck_n,
		puck_size * (1.0 + puck_sq if _puck_long else 1.0 - puck_sq),
		puck_size * (1.0 - puck_sq * 0.5 if _puck_long else 1.0 + puck_sq * 0.5)) \
		* Transform2D(0.0, puck_pop, 0.0, Vector2.ZERO)
	var mallet_xf: Array = []
	var mallet_lift := [0.0, 0.0]
	for p in 2:
		var at := px(sim.mallet[p])
		var grown: float = sim.radius[p] / Sim.MALLET_R
		var along := grown
		var across := grown
		var n: Vector2 = _bump_n[p]
		if _bump[p] > 0.0 and moving:
			var sq: float = Motion.bump_scale(BUMP - _bump[p], SQUASH * _bump_by[p], BUMP) - 1.0
			along -= sq * grown
			across += sq * 0.6 * grown
		elif _slump[p] > 0.0:
			# Scored on: it sags, wider than it is tall, with a shake of the head.
			n = Vector2.DOWN
			along -= SLUMP * _slump[p] * grown
			across += SLUMP * 0.4 * _slump[p] * grown
			at += Vector2(Motion.shiver_offset(_goal_t, Motion.SHIVER_PX * 2.0, Motion.SHIVER_TIME * 2.0), SLUMP * 0.5 * mallet_r * _slump[p])
		elif lying:
			along += BREATH * _breath(p * 0.5) * grown
			across = along
		if moving and _goal_by == p:
			# The scorer hops once; whoever took the match, three times.
			var hops: int = WIN_HOPS if sim.over else 1
			for k in hops:
				mallet_lift[p] -= Motion.hop_lift(_goal_t - 0.12 - k * Motion.SOLVE_TIME, Motion.SOLVE_HOP * CHEER, Motion.SOLVE_TIME)
			var up: float = mallet_lift[p] / absf(Motion.SOLVE_HOP * CHEER)
			along *= 1.0 + 0.06 * up
			across *= 1.0 + 0.06 * up
		mallet_xf.append(_place(at - Vector2(0.0, mallet_lift[p]), n, along, across))

	# The pieces' vertices head the mesh, where their indices expect them;
	# the indices themselves go in further down, in drawing order.
	b.verts = puck_xf * (_piece_verts[0] as PackedVector2Array)
	b.verts.append_array(mallet_xf[0] * (_piece_verts[1] as PackedVector2Array))
	b.verts.append_array(mallet_xf[1] * (_piece_verts[2] as PackedVector2Array))
	b.cols = _piece_cols.duplicate()

	# --- under the pieces ---
	for end in 2:
		var gy := Sim.L if end == 0 else 0.0
		var out := 1.0 if end == 0 else -1.0
		var c := px(Vector2(Sim.W * 0.5, gy))
		var from := PI if end == 0 else 0.0
		var slot_at := c + Vector2(0.0, out * RAIL * ppm * 0.38)
		# A goal: the slot lights and the crease warms, in the scorer's colour.
		if _glow[end] > 0.0:
			var u: float = _glow[end] / GLOW
			var tint: Color = SIDE[1 - end][1]
			_soft_fan(b, c, Face.Builder.arc_points(c, (Sim.GOAL_HALF + 0.1 + 0.16 * (1.0 - u)) * ppm, from, from + PI), Color(tint, 0.75 * u))
			Scenery.soft_disc(b, slot_at, Sim.GOAL_HALF * ppm * 1.15, RAIL * ppm * 0.75, Color(tint, 0.9 * u))
			Scenery.soft_disc(b, slot_at, Sim.GOAL_HALF * ppm * 0.7, RAIL * ppm * 0.4, Color(HALO, 0.7 * u))
		# Match point: the mouth the leader shoots at breathes their light.
		elif moving and not sim.over and int(sim.scores[1 - end]) == Sim.TARGET - 1:
			var level := 0.75 + 0.25 * _breath()
			Scenery.soft_disc(b, c, Sim.GOAL_HALF * ppm * 1.25, Sim.GOAL_HALF * ppm * 0.8, Color(SIDE[1 - end][0], 0.55 * level))
			var lead: Color = SIDE[1 - end][0]
			_soft_fan(b, c, Face.Builder.arc_points(c, (Sim.GOAL_HALF + 0.05) * ppm, from, from + PI), Color(lead, 0.75 * level))
			Scenery.soft_disc(b, slot_at, Sim.GOAL_HALF * ppm * 1.1, RAIL * ppm * 0.7, Color(lead, 0.95 * level))
			Scenery.soft_disc(b, slot_at, Sim.GOAL_HALF * ppm * 0.6, RAIL * ppm * 0.35, Color(HALO, 0.5 * level))
	for f in _flashes:
		if String(f.kind) != "save":
			continue
		# A save: the crease rings in the keeper's colour, out and away.
		var su: float = float(f.t) / float(f.life)
		var keeper := int(f.seat)
		var sc := px(f.at)
		var sfrom := PI if keeper == 0 else 0.0
		var reach := (Sim.GOAL_HALF + 0.06 + 0.12 * Motion.back_out(su)) * ppm
		_soft_fan(b, sc, Face.Builder.arc_points(sc, reach, sfrom, sfrom + PI), Color(SIDE[keeper][1], 0.7 * (1.0 - su)))
		b.stroke(Face.Builder.arc_points(sc, reach, sfrom, sfrom + PI), maxf(2.0, ppm * 0.012 * (1.0 - su)), Color(HALO, 0.85 * (1.0 - su)), false, true)
	# A puck lying still glows, waiting to be played.
	if lying and sim.puck_on:
		var wait := 0.5 + 0.5 * _breath(0.25)
		# In the colour of the half it lies in: whose it is to play.
		Scenery.soft_disc(b, puck_at, puck_r * (2.1 + 0.5 * wait), puck_r * (2.1 + 0.5 * wait), Color(SIDE[sim.side()][0], 0.45 + 0.4 * wait))
	# shadows first, so no piece shades another's top
	for p in 2:
		var high: float = mallet_lift[p] / maxf(1.0, mallet_r)
		b.disc(px(sim.mallet[p]) + shade * (1.3 + 2.0 * high), sim.radius[p] * ppm * (1.02 - 0.2 * high), SHADOW)
	if sim.puck_on:
		b.disc(puck_at + shade * 0.7, puck_r * minf(1.0, puck_pop.y), Color(SHADOW, SHADOW.a * Motion.appear_level(_serve_t) if moving else SHADOW.a))
	# The puck's trail: the light of whoever struck it last, and what it sheds.
	if not _trail.is_empty():
		var tint2 := _touch_tint()
		# Beads a bead apart, newest first, clear of the puck: never a smear.
		var last_bead := puck_at
		for i in range(_trail.size() - 1, -1, -1):
			var bead := px(_trail[i])
			if bead.distance_to(last_bead) < puck_r * 1.5:
				continue
			last_bead = bead
			var f2 := float(i + 1) / float(_trail.size() + 1)
			Scenery.soft_disc(b, bead, puck_r * (0.4 + 0.45 * f2), puck_r * (0.4 + 0.45 * f2), Color(tint2, 0.6 * f2))
	for m in _motes:
		var mu: float = float(m.t) / float(m.life)
		_glow_at(b, px(m.at), float(m.r) * ppm * (1.6 - 0.5 * mu), Color(m.col as Color, 0.9), minf(1.0, mu * 8.0) * (1.0 - mu))
	# The puck set down: a ring of light opens under it as it lands.
	if moving and sim.puck_on and _serve_t < Motion.RING_TIME:
		var ru: float = _serve_t / Motion.RING_TIME
		Scenery.soft_disc(b, puck_at, puck_r * (1.2 + 2.6 * ru), puck_r * (1.2 + 2.6 * ru), Color(SIDE[sim.side()][0], 0.8 * (1.0 - ru)))

	_power_under(b, moving, puck_at, puck_r)

	# --- the pieces ---
	if puck_shown:
		b.idx.append_array(_piece_idx[0])
	b.idx.append_array(_piece_idx[1])
	b.idx.append_array(_piece_idx[2])

	if sim.twin_on:
		_second_puck(b, puck_r)
	_power_over(b)

	# --- over them ---
	var well := 0.016 * ppm
	for f in _flashes:
		var kind := String(f.kind)
		if kind == "save":
			continue
		var u3: float = float(f.t) / float(f.life)
		var c2 := px(f.at)
		var s: float = f.strength
		var n2: Vector2 = f.n
		var fade := 1.0 - u3
		var grow := 0.45 + 0.55 * sin(u3 * PI * 0.5)
		if kind == "mallet":
			# A pulse of the striker's light where the two met.
			_glow_at(b, c2, ppm * (0.05 + 0.11 * s) * grow, Color(SIDE[int(f.seat)][0], 0.95), fade)
			continue
		if kind == "wall":
			# The rail gives: its lip swells outward where it was struck.
			var give := Motion.nudge_offset(float(f.t), GIVE * s + 1.0, float(f.life), 0.0)
			var run := ppm * (0.045 + 0.05 * s)
			var bulge := Face.Builder.ring(Vector2.ZERO, run, well * 0.5 + give)
			var turn := Transform2D(n2.angle() + PI * 0.5, c2 - n2 * (well * 0.5 + give * 0.5))
			b.fan(turn * bulge, LIP)
		# Light off the wood, wide along the rail it left; a post's is its goal's.
		var lit: Color = LAMP.darkened(0.1) if kind == "wall" else (SIDE[0 if f.at.y > Sim.L * 0.5 else 1][0] as Color).lerp(HALO, 0.3)
		var reach2 := ppm * (0.04 + 0.08 * s) * grow
		var across2 := Vector2(absf(n2.y), absf(n2.x))
		Scenery.soft_disc(b, c2, reach2 * (1.0 + 0.7 * across2.x), reach2 * (1.0 + 0.7 * across2.y), Color(lit, 0.85 * fade))
	# The match's last goal: light runs from the mouth down both long rails
	# and meets at the winner's end.
	if moving and sim.over and _goal_by >= 0 and _goal_t < LAP + 0.4:
		var end2 := 1 - _goal_by
		var way := Sim.W + Sim.L
		for side in [-1.0, 1.0]:
			for k in LAP_MOTES:
				var lu := (_goal_t - k * 0.045) / LAP
				if lu <= 0.0 or lu >= 1.0:
					continue
				var eased := lu * lu * (3.0 - 2.0 * lu)
				var size_by := 1.0 - float(k) / LAP_MOTES
				_glow_at(b, _rim(end2, side, eased * way), ppm * 0.05 * (0.5 + 0.5 * size_by), Color(SIDE[_goal_by][1], 0.95), sin(lu * PI) * (0.4 + 0.6 * size_by))
	return b.mesh()

## What lies under the pieces of the power table: a goal stood open, the
## token, the gold puck's light.
func _power_under(b: Face.Builder, moving: bool, puck_at: Vector2, puck_r: float) -> void:
	for end in 2:
		if sim.wide_t[end] <= 0.0:
			continue
		# The mouth run out along the rail, trimmed in the side's colour.
		var half: float = sim.goal_half(end) * ppm
		var y := origin.y + (Sim.L * ppm if end == 0 else -RAIL * ppm * 0.7)
		var at := Vector2(origin.x + Sim.W * ppm * 0.5 - half, y)
		var deep := RAIL * ppm * 0.7
		b.fan(Face.Builder.round_rect(at - Vector2(5.0, 0.0 if end == 0 else 5.0), Vector2(half * 2.0 + 10.0, deep + 5.0), 9.0), SIDE[end][2])
		b.fan(Face.Builder.round_rect(at, Vector2(half * 2.0, deep), 6.0), SLOT)
		var lip := origin.y + (Sim.L * ppm if end == 0 else 0.0)
		var well := 0.016 * ppm + 1.0
		var out := 1.0 if end == 0 else -1.0
		b.fan(PackedVector2Array([Vector2(at.x, lip), Vector2(at.x + half * 2.0, lip),
			Vector2(at.x + half * 2.0, lip + out * well), Vector2(at.x, lip + out * well)]), SLOT)
	if sim.pick_kind != Sim.NONE:
		var c := px(sim.pick_at)
		var r := TOKEN_R * ppm
		var blinking: bool = sim.pick_t < BLINK and fmod(sim.pick_t, 0.5) < 0.2
		var beat: float = 1.0 + (0.06 * sin(_clock * 5.0) if moving else 0.0)
		Scenery.soft_disc(b, c, r * 1.9, r * 1.9, Color(BRASS, 0.5 if not blinking else 0.2))
		if not blinking:
			b.disc(c + Vector2(0.0, r * 0.14), r * beat, BRASS.darkened(0.3))
			b.disc(c, r * beat, BRASS)
			b.disc(c, r * 0.86 * beat, STAMP)
			power_icon(b, sim.pick_kind, c, r * 0.72 * beat)
	if sim.gold and sim.puck_on:
		Scenery.soft_disc(b, puck_at, puck_r * 2.6, puck_r * 2.6, Color(BRASS, 0.9))

## The second puck, its own light round it.
func _second_puck(b: Face.Builder, puck_r: float) -> void:
	var at := px(sim.twin)
	Scenery.soft_disc(b, at, puck_r * 1.9, puck_r * 1.9, Color(HALO, 0.75))
	b.disc(at + Vector2(0.009, 0.016) * ppm * 0.7, puck_r, SHADOW)
	var base := b.verts.size()
	var verts: PackedVector2Array = _piece_verts[0]
	b.verts.append_array(Transform2D(0.0, at) * verts)
	b.cols.append_array(_piece_cols.slice(0, verts.size()))
	for i: int in _piece_idx[0]:
		b.idx.append(base + i)

## Over a mallet, how long its power has left: an arc round it that runs down.
func _power_over(b: Face.Builder) -> void:
	for p in 2:
		var c := px(sim.mallet[p])
		var r: float = sim.radius[p] * ppm + POWER_RING * ppm
		if sim.big_t[p] > 0.0:
			_time_arc(b, c, r, sim.big_t[p] / Sim.BIG_TIME, BRASS)
		if sim.slow_t[p] > 0.0:
			_time_arc(b, c, r + POWER_RING * ppm * 0.8, sim.slow_t[p] / Sim.SLOW_TIME, Color("6f93d0"))
			for k in 6:
				var a := TAU * k / 6.0 + _clock * 0.5
				b.disc(c + Vector2.from_angle(a) * r * 0.88, r * 0.07, Color("dfe9fb"))

func _time_arc(b: Face.Builder, c: Vector2, r: float, left: float, col: Color) -> void:
	b.stroke(Face.Builder.arc_points(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(left, 0.02, 1.0)), maxf(3.0, ppm * 0.009), col, false, true)

## A token's drawing about `c`, in a box of side 2r.
static func power_icon(b: Face.Builder, kind: int, c: Vector2, r: float) -> void:
	match kind:
		Sim.TWIN:
			for k in 2:
				var at := c + Vector2((k * 2 - 1) * r * 0.42, (1 - k * 2) * r * 0.2)
				b.disc(at + Vector2(0.0, r * 0.08), r * 0.5, PUCK_DEEP)
				b.disc(at, r * 0.5, PUCK)
				b.stroke(Face.Builder.ring(at, r * 0.32, r * 0.32), r * 0.07, Color(PUCK_LIT, 0.9), true, false)
		Sim.BIG:
			b.disc(c, r * 0.86, SIDE[0][2])
			b.disc(c + LIGHT * r * 0.1, r * 0.76, SIDE[0][0])
			b.disc(c + LIGHT * r * 0.14, r * 0.34, SIDE[0][1])
		Sim.WIDE:
			var y := c.y + r * 0.34
			b.stroke(PackedVector2Array([c + Vector2(-r * 0.9, r * 0.34), Vector2(c.x + r * 0.9, y)]), r * 0.26, SLOT, false, true)
			for sx: float in [-1.0, 1.0]:
				var tip := c + Vector2(sx * r * 0.86, -r * 0.34)
				b.stroke(PackedVector2Array([c + Vector2(sx * r * 0.2, -r * 0.34), tip]), r * 0.15, BRASS.darkened(0.2), false, true)
				b.stroke(PackedVector2Array([tip + Vector2(-sx * r * 0.28, -r * 0.26), tip, tip + Vector2(-sx * r * 0.28, r * 0.26)]), r * 0.15, BRASS.darkened(0.2), false, true)
		Sim.SLOW:
			for k in 3:
				var d := Vector2.from_angle(PI * k / 3.0 + PI * 0.5) * r * 0.86
				b.stroke(PackedVector2Array([c - d, c + d]), r * 0.15, Color("6f93d0"), false, true)
				for e: float in [-1.0, 1.0]:
					var at := c + d * 0.62 * e
					b.stroke(PackedVector2Array([at + d.rotated(0.9 * e) * 0.3, at, at + d.rotated(-0.9 * e) * 0.3]), r * 0.11, Color("6f93d0"), false, true)
		Sim.GOLD:
			b.disc(c + Vector2(0.0, r * 0.08), r * 0.86, BRASS.darkened(0.35))
			b.disc(c, r * 0.84, BRASS)
			b.stroke(Face.Builder.ring(c, r * 0.62, r * 0.62), r * 0.08, Color(STAMP, 0.9), true, false)
			# two pips: it counts double
			b.disc(c + Vector2(-r * 0.25, 0.0), r * 0.17, STAMP)
			b.disc(c + Vector2(r * 0.25, 0.0), r * 0.17, STAMP)

## The puck from straight above, about nothing: the house's, the sprout
## stamped in cream inside its ring.
func _puck(b: Face.Builder) -> void:
	var at := Vector2.ZERO
	var r := Sim.PUCK_R * ppm
	b.disc(at, r, PUCK_DEEP)
	b.disc(at + LIGHT * r * 0.08, r * 0.9, PUCK)
	b.stroke(Face.Builder.ring(at + LIGHT * r * 0.08, r * 0.66, r * 0.66), maxf(1.5, r * 0.08), Color(PUCK_LIT, 0.9), true, false)
	_sprout(b, at + LIGHT * r * 0.08 + Vector2(0.0, r * 0.06), r * 0.024, Color(STAMP, 0.9))
	b.disc(at + LIGHT * r * 0.86, r * 0.09, Color(1, 1, 1, 0.5))

## A mallet from straight above, about nothing: the skirt, the dished top and
## the knob. The sun's has its rays round the skirt as dots, the moon's a
## crescent on its knob and three specks of night round it.
func _mallet(b: Face.Builder, seat: int) -> void:
	var at := Vector2.ZERO
	var r := Sim.MALLET_R * ppm
	var body: Color = SIDE[seat][0]
	var lit: Color = SIDE[seat][1]
	var deep: Color = SIDE[seat][2]
	b.disc(at, r, deep)
	b.disc(at + LIGHT * r * 0.06, r * 0.93, body)
	b.stroke(Face.Builder.arc_points(at + LIGHT * r * 0.06, r * 0.8, PI * 0.95, PI * 1.55), maxf(2.0, r * 0.07), Color(lit, 0.9), false, true)
	if seat == 0:
		for k in 12:
			var ray := Vector2.from_angle(TAU * (k + 0.5) / 12.0)
			b.disc(at + LIGHT * r * 0.06 + ray * r * 0.765, r * (0.058 if k % 2 == 0 else 0.04), Color(HALO, 0.8))
	else:
		for ang: float in [0.5, 2.3, 5.4]:
			b.disc(at + LIGHT * r * 0.06 + Vector2.from_angle(ang) * r * 0.765, r * 0.045, Color(HALO, 0.8))
	b.disc(at - LIGHT * r * 0.05, r * 0.6, deep)
	b.disc(at + LIGHT * r * 0.03, r * 0.55, body.darkened(0.06))
	# the knob, standing up toward the light
	b.disc(at - LIGHT * r * 0.14, r * 0.4, Color(deep, 0.8))
	b.disc(at + LIGHT * r * 0.1, r * 0.36, deep)
	b.disc(at + LIGHT * r * 0.16, r * 0.33, lit)
	if seat == 1:
		var knob := at + LIGHT * r * 0.16
		b.disc(knob, r * 0.2, HALO)
		b.disc(knob + Vector2(r * 0.09, -r * 0.05), r * 0.17, lit)
	else:
		b.disc(at + LIGHT * r * 0.3, r * 0.1, Color(1, 1, 1, 0.75))
