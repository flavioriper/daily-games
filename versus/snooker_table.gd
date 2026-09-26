extends Control

## The snooker table as the player sees it: the wooden frame with its brass
## pocket caps, the cushions and the cloth (baked once into one mesh, rebuilt
## only when the table is resized), and over it one live mesh a frame for
## the balls, the aim guide and the cue.
##
## Balls take the game's soft painted cel (docs/art/shading-direction.md):
## a coloured shadow on the cloth rather than a black one, a darker body
## with the lit face laid over it toward the light, a soft bloom and one
## small highlight -- no outline. The cue ball carries the televised spots,
## turned by its real spin, so screw and side can be seen working.
##
## Input: press on the table to aim at that point and drag to swing the
## aim; with the cue ball in hand, press on the ball to carry it round the D.
## The power and the tip live in the screen's side column; this only draws
## what they say.

signal aimed
signal placed

const Sim = preload("res://versus/snooker_sim.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

## The frame round the playing area, metres: the cushions' green tops, then
## the wooden rail.
const CUSHION := 0.034
const RAIL := 0.095
const FRAME_R := 0.07
## How far the cue can be drawn back at full power, metres.
const PULL := 0.30
const CUE_LEN := 1.45
## How long the cue takes to go through the ball, seconds.
const STROKE := 0.08
const SINK := 0.28
## The guide: dash and gap, px, and how far the object ball's line and the
## cue ball's run are shown, metres.
const DASH := 11.0
const DASH_GAP := 8.0
const OBJ_LINE := 0.42
const CUE_LINE := 0.24

const CLOTH := Color("3f9150")
const CLOTH_EDGE := Color("2f7a40")
const CLOTH_LIT := Color("54a861")
const CUSHION_TOP := Color("2d7a3d")
const CUSHION_LIP := Color("46995a")
const WOOD := Color("8f5a36")
const WOOD_LIT := Color("b0764a")
const WOOD_DEEP := Color("5e3a22")
const BRASS := Color("d2a857")
const BRASS_LIT := Color("f0d189")
const BRASS_DEEP := Color("a37c35")
const HOLE := Color("24170f")
const LEATHER := Color("4a2d1b")
const LINE := Color(1.0, 0.98, 0.9, 0.55)
const INLAY := Color("f3e3c2")
## Ball colours: the regulation set, a shade softer for the painted look.
const BALL := {
	0: Color("f6f0e2"),
	16: Color("f2c233"),
	17: Color("2f9657"),
	18: Color("8b5a33"),
	19: Color("2f6fcb"),
	20: Color("f39ab5"),
	21: Color("2e2b30"),
}
const RED := Color("d63a3f")
const SPOT := Color("d6464a")
## The coloured shadow a ball casts on the cloth, and where the light is.
const SHADOW := Color(0.08, 0.2, 0.12, 0.34)
const LIGHT := Vector2(-0.45, -0.6)

var sim: RefCounted
var aim_dir := Vector2(0.0, -1.0)
## How far the cue is drawn back, 0..1.
var power := 0.0
var tip := Vector2.ZERO
var show_cue := true
var show_guide := true
## Whether touches aim (the player's turn and nothing rolling).
var interactive := false
var in_hand := false
## Balls that can legally be hit first, lit faintly while aiming.
var targets: Array = []
## A suggested aim from the hint, drawn as a faint second line.
var hint_dir := Vector2.ZERO
## A picture, not a game (the Versus tab's card): drawn once per resize and
## never again, so it costs the menu nothing a frame.
var still := false

var ppm := 100.0
var origin := Vector2.ZERO
var _table: ArrayMesh
var _live: ArrayMesh
var _shown: Array = []
var _stroke_t := -1.0
var _stroke_from := 0.0
var _stroke_done: Callable
var _sinking: Array = []
var _drag := ""
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still else Control.MOUSE_FILTER_STOP
	resized.connect(_relayout)

func _relayout() -> void:
	var span := Vector2(Sim.W, Sim.L) + Vector2.ONE * 2.0 * (CUSHION + RAIL)
	ppm = minf(size.x / span.x, size.y / span.y)
	var used := span * ppm
	origin = (size - used) * 0.5 + Vector2.ONE * (CUSHION + RAIL) * ppm
	_table = null
	queue_redraw()

func px(p: Vector2) -> Vector2:
	return origin + p * ppm

func metres(p: Vector2) -> Vector2:
	return (p - origin) / ppm

## The table's outer rectangle in this control's pixels.
func frame_rect() -> Rect2:
	var m := (CUSHION + RAIL) * ppm
	return Rect2(origin - Vector2.ONE * m, Vector2(Sim.W, Sim.L) * ppm + Vector2.ONE * 2.0 * m)

func _process(delta: float) -> void:
	if still:
		return
	_time += delta
	if _stroke_t >= 0.0:
		_stroke_t += delta
		if _stroke_t >= STROKE:
			_stroke_t = -1.0
			var done := _stroke_done
			_stroke_done = Callable()
			if done.is_valid():
				done.call()
	for s in _sinking:
		s.t += delta
	_sinking = _sinking.filter(func(s: Dictionary) -> bool: return s.t < SINK)
	queue_redraw()

## The cue goes through the ball from wherever it is drawn back to, then
## `done` strikes.
func play_stroke(done: Callable) -> void:
	_stroke_from = power
	_stroke_t = 0.0
	_stroke_done = done

## A potted ball drops into its pocket rather than vanishing.
func sink(id: int, at: Vector2, pocket: Vector2) -> void:
	_sinking.append({"id": id, "from": at, "to": pocket, "t": 0.0})

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	var press := false
	var release := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		at = event.position
	else:
		return
	accept_event()
	if release:
		if _drag == "ball":
			placed.emit()
		_drag = ""
		return
	var cue: Vector2 = sim.pos[Sim.CUE]
	if press:
		_drag = "aim"
		if in_hand and px(cue).distance_to(at) < Sim.R * ppm * 3.2:
			_drag = "ball"
	if _drag == "ball":
		var p := Sim.clamp_d(metres(at))
		if sim.free_at(p, Sim.CUE):
			sim.pos[Sim.CUE] = p
		return
	if _drag == "aim":
		var d := metres(at) - cue
		if d.length() > Sim.R * 0.5:
			aim_dir = d.normalized()
			hint_dir = Vector2.ZERO
			aimed.emit()

# --- drawing ---

func _draw() -> void:
	if sim == null or size.x <= 0.0:
		return
	if _table == null:
		_table = _build_table()
	draw_mesh(_table, null)
	_live = _build_live()
	draw_mesh(_live, null)
	_shown = [_table, _live]

func _build_table() -> ArrayMesh:
	var b := Face.Builder.new()
	var outer := frame_rect()
	var r := FRAME_R * ppm
	var lip := CUSHION * ppm
	# The table's own shadow on the floor, soft and warm.
	for k in 4:
		var grow := 6.0 + k * 7.0
		b.fan(Face.Builder.round_rect(outer.position + Vector2(-grow * 0.5, 18.0 - grow * 0.2),
			outer.size + Vector2(grow, grow * 0.6), r + grow), Color(0.24, 0.13, 0.07, 0.09))
	# The wooden frame: a deep base, the lit top, a bevel along its inner edge.
	b.fan(Face.Builder.round_rect(outer.position + Vector2(0.0, 7.0), outer.size, r), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(outer.position, outer.size, r), WOOD)
	_grain(b, outer)
	var inner := Rect2(origin - Vector2.ONE * lip, Vector2(Sim.W, Sim.L) * ppm + Vector2.ONE * 2.0 * lip)
	b.fan(Face.Builder.round_rect(inner.position - Vector2.ONE * 5.0, inner.size + Vector2.ONE * 10.0, 8.0), WOOD_DEEP)
	# Brass caps round every pocket, under the cushions and the cloth.
	for k in sim.pockets.size():
		var hole := _hole(k)
		b.disc(hole.at, hole.r + 0.034 * ppm, BRASS_DEEP)
		b.disc(hole.at + Vector2(-1.5, -2.0), hole.r + 0.03 * ppm, BRASS)
		b.stroke(Face.Builder.arc_points(hole.at, hole.r + 0.022 * ppm, PI * 1.0, PI * 1.5), 3.0, BRASS_LIT)
	# Inlaid diamonds along the rails.
	var rail_mid := (lip + RAIL * ppm * 0.5)
	for i in [1, 2, 3, 5, 6, 7]:
		var y: float = origin.y + Sim.L * ppm * i / 8.0
		_diamond(b, Vector2(origin.x - rail_mid, y))
		_diamond(b, Vector2(origin.x + Sim.W * ppm + rail_mid, y))
	for i in [1, 2, 3]:
		var x: float = origin.x + Sim.W * ppm * i / 4.0
		_diamond(b, Vector2(x, origin.y - rail_mid))
		_diamond(b, Vector2(x, origin.y + Sim.L * ppm + rail_mid))
	# The cushions: one green block per face, cut back along the jaws.
	for q in _cushion_quads():
		b.polygon(q.body, CUSHION_TOP)
		b.stroke(q.nose, 3.0, CUSHION_LIP, false, false)
	# The cloth, lit from its middle and falling off toward the cushions.
	_cloth(b)
	# The markings: the baulk line, the D and the spots.
	var line_w := maxf(1.5, ppm * 0.004)
	b.stroke(PackedVector2Array([px(Vector2(0.0, Sim.BAULK_Y)), px(Vector2(Sim.W, Sim.BAULK_Y))]), line_w, LINE, false, false)
	b.stroke(Face.Builder.arc_points(px(Sim.D_CENTRE), Sim.D_R * ppm, 0.0, PI), line_w, LINE, false, false)
	for id in Sim.SPOTS:
		b.disc(px(Sim.SPOTS[id]), maxf(1.8, ppm * 0.005), Color(LINE, 0.7))
	# The pockets, over the cloth: the leather and the dark drop.
	for k in sim.pockets.size():
		var hole := _hole(k)
		b.disc(hole.at, hole.r + 0.01 * ppm, LEATHER)
		b.disc(hole.at, hole.r, HOLE)
		b.disc(hole.at - (sim.pockets[k].out as Vector2) * hole.r * 0.25, hole.r * 0.62, Color("140c07"))
	return b.mesh()

## A pocket's drawn hole: where it sits and how big, pixels.
func _hole(k: int) -> Dictionary:
	var pk: Dictionary = sim.pockets[k]
	var middle := k == 2 or k == 3
	var at: Vector2 = pk.at + (pk.out as Vector2) * (0.03 if middle else 0.034)
	var r := (0.074 if middle else 0.068) * ppm
	return {"at": px(at), "r": r}

func _cushion_quads() -> Array:
	var out: Array = []
	var cb := CUSHION
	var c := Sim.CORNER
	var m := Sim.MIDDLE
	var h := Sim.L * 0.5
	var W := Sim.W
	var L := Sim.L
	var faces := [
		[Vector2(c, 0), Vector2(W - c, 0), Vector2(W - c + cb, -cb), Vector2(c - cb, -cb)],
		[Vector2(W - c, L), Vector2(c, L), Vector2(c - cb, L + cb), Vector2(W - c + cb, L + cb)],
		[Vector2(0, h - m), Vector2(0, c), Vector2(-cb, c - cb), Vector2(-cb, h - m - 0.004)],
		[Vector2(0, L - c), Vector2(0, h + m), Vector2(-cb, h + m + 0.004), Vector2(-cb, L - c + cb)],
		[Vector2(W, c), Vector2(W, h - m), Vector2(W + cb, h - m - 0.004), Vector2(W + cb, c - cb)],
		[Vector2(W, h + m), Vector2(W, L - c), Vector2(W + cb, L - c + cb), Vector2(W + cb, h + m + 0.004)],
	]
	for f in faces:
		var body := PackedVector2Array()
		for p in f:
			body.append(px(p))
		out.append({"body": body, "nose": PackedVector2Array([body[0], body[1]])})
	return out

func _cloth(b: Face.Builder) -> void:
	var cols := 6
	var rows := 12
	var first := b.verts.size()
	var mid := Vector2(Sim.W * 0.5, Sim.L * 0.46)
	for j in rows + 1:
		for i in cols + 1:
			var p := Vector2(Sim.W * i / cols, Sim.L * j / rows)
			var d := Vector2((p.x - mid.x) / Sim.W, (p.y - mid.y) / Sim.L).length() * 1.9
			var col := CLOTH_LIT.lerp(CLOTH, clampf(d * 1.2, 0.0, 1.0)).lerp(CLOTH_EDGE, clampf(d - 0.55, 0.0, 1.0))
			b.vertex(px(p), col)
	for j in rows:
		for i in cols:
			var a := first + j * (cols + 1) + i
			b.tri(a, a + 1, a + cols + 2)
			b.tri(a, a + cols + 2, a + cols + 1)
	# The cushions' shade falling on the cloth along each face.
	var fall := 0.02 * ppm
	var shade := Color(0.05, 0.18, 0.08, 0.28)
	var clear := Color(shade, 0.0)
	var edges := [
		[px(Vector2(0, 0)), px(Vector2(Sim.W, 0)), Vector2(0, 1)],
		[px(Vector2(0, 0)), px(Vector2(0, Sim.L)), Vector2(1, 0)],
		[px(Vector2(Sim.W, 0)), px(Vector2(Sim.W, Sim.L)), Vector2(-1, 0)],
	]
	for e in edges:
		var a0 := b.vertex(e[0], shade)
		var a1 := b.vertex(e[1], shade)
		var a2 := b.vertex(e[1] + e[2] * fall, clear)
		var a3 := b.vertex(e[0] + e[2] * fall, clear)
		b.tri(a0, a1, a2)
		b.tri(a0, a2, a3)

func _grain(b: Face.Builder, outer: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var lip := (CUSHION + RAIL) * ppm
	for k in 26:
		var horizontal := k % 2 == 0
		var t := rng.randf()
		var off := rng.randf_range(0.15, 0.85) * lip
		var along := rng.randf_range(0.12, 0.3)
		var pts := PackedVector2Array()
		if horizontal:
			var y: float = outer.position.y + off if k % 4 == 0 else outer.end.y - off
			var x0 := outer.position.x + outer.size.x * t
			pts = PackedVector2Array([Vector2(x0, y), Vector2(x0 + outer.size.x * along * 0.5, y + rng.randf_range(-2, 2)),
				Vector2(minf(x0 + outer.size.x * along, outer.end.x - lip * 0.3), y)])
		else:
			var x: float = outer.position.x + off if k % 4 == 1 else outer.end.x - off
			var y0 := outer.position.y + outer.size.y * t
			pts = PackedVector2Array([Vector2(x, y0), Vector2(x + rng.randf_range(-2, 2), y0 + outer.size.y * along * 0.5),
				Vector2(x, minf(y0 + outer.size.y * along, outer.end.y - lip * 0.3))])
		b.stroke(pts, 2.0, Color(WOOD_LIT, 0.35), false, true)

func _diamond(b: Face.Builder, at: Vector2) -> void:
	var s := maxf(4.0, ppm * 0.011)
	b.fan(PackedVector2Array([at + Vector2(0, -s), at + Vector2(s * 0.7, 0), at + Vector2(0, s), at + Vector2(-s * 0.7, 0)]), INLAY)

func _build_live() -> ArrayMesh:
	var b := Face.Builder.new()
	var r := Sim.R * ppm
	# Shadows first, so no ball's shadow lies over its neighbour.
	for i in Sim.COUNT:
		if sim.on[i]:
			var c := px(sim.pos[i]) + Vector2(r * 0.28, r * 0.36)
			b.ellipse(c, r * 1.02, r * 0.92, SHADOW)
	for s in _sinking:
		var u: float = s.t / SINK
		var at: Vector2 = (s.from as Vector2).lerp(s.to, minf(1.0, u * 1.6))
		_ball(b, s.id, px(at), r * lerpf(1.0, 0.55, u), 1.0 - u * u)
	if interactive and not targets.is_empty() and show_guide:
		var glow := 0.5 + 0.5 * sin(_time * 3.2)
		for id in targets:
			if sim.on[id]:
				b.stroke(Face.Builder.ring(px(sim.pos[id]), r * 1.32, r * 1.32), 2.5,
					Color(1.0, 0.97, 0.8, 0.25 + 0.25 * glow), true)
	for i in Sim.COUNT:
		if sim.on[i]:
			_ball(b, i, px(sim.pos[i]), r, 1.0)
	if in_hand and interactive:
		b.stroke(Face.Builder.ring(px(sim.pos[Sim.CUE]), r * 1.7, r * 1.7), 3.0,
			Color(1.0, 1.0, 1.0, 0.45 + 0.25 * sin(_time * 4.0)), true)
	if show_guide and show_cue and sim.on[Sim.CUE]:
		if hint_dir != Vector2.ZERO:
			_guide(b, hint_dir, Color(Pal.SUN_RAY, 0.8))
		_guide(b, aim_dir, Color(1.0, 1.0, 1.0, 0.8))
	if show_cue and sim.on[Sim.CUE]:
		_cue(b)
	return b.mesh()

## One ball: the darker body, the lit face toward the light, a soft bloom
## and a highlight; the cue ball's spots turned by its spin.
func _ball(b: Face.Builder, id: int, at: Vector2, r: float, alpha: float) -> void:
	var base: Color = RED if Sim.is_red(id) else BALL[id]
	var deep := base.darkened(0.32 if id != Sim.BLACK else 0.2)
	var l := LIGHT.normalized()
	b.disc(at, r, Color(deep, alpha))
	b.disc(at + l * r * 0.1, r * 0.88, Color(base, alpha))
	b.disc(at + l * r * 0.3, r * 0.52, Color(base.lightened(0.16 if id != Sim.BLACK else 0.12), alpha * 0.8))
	if id == Sim.CUE:
		for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
			var w: Vector3 = sim.spin_basis * axis
			if w.z <= 0.05:
				continue
			var sp := at + Vector2(w.x, w.y) * r * 0.78
			var s := r * 0.2
			b.ellipse(sp, s * lerpf(0.55, 1.0, w.z) if absf(w.x) > absf(w.y) else s, s * lerpf(0.55, 1.0, w.z) if absf(w.y) >= absf(w.x) else s,
				Color(SPOT, alpha * clampf(w.z * 3.0, 0.0, 1.0)))
	b.ellipse(at + l * r * 0.5, r * 0.2, r * 0.14, Color(1.0, 1.0, 1.0, alpha * 0.85))
	# A soft bounce light from the cloth along the ball's foot.
	b.stroke(Face.Builder.arc_points(at, r * 0.86, PI * 0.15, PI * 0.75), r * 0.14,
		Color(base.lightened(0.25), alpha * 0.35), false, false)

## The dotted line to the first thing the cue ball meets, the ghost ball
## there, and short lines for where the object ball and the cue ball go.
func _guide(b: Face.Builder, dir: Vector2, col: Color) -> void:
	var cue: Vector2 = sim.pos[Sim.CUE]
	var hit: Dictionary = sim.cast(cue, dir)
	if hit.t == INF:
		return
	var from := px(cue + dir * Sim.R * 1.2)
	var to := px(hit.at)
	_dashes(b, from, to, col, 3.0)
	var r := Sim.R * ppm
	b.stroke(Face.Builder.ring(to, r, r), 2.5, col, true)
	if int(hit.id) >= 0:
		var n: Vector2 = hit.normal
		var obj: Vector2 = sim.pos[hit.id]
		var cut := clampf(dir.dot(n), 0.0, 1.0)
		b.stroke(PackedVector2Array([px(obj + n * Sim.R * 1.1), px(obj + n * (Sim.R + OBJ_LINE * (0.35 + 0.65 * cut)))]), 3.0, col)
		var run := dir - n * dir.dot(n)
		if run.length() > 0.02:
			run = run.normalized()
			_dashes(b, to + run * r * 1.1, to + run * (r + CUE_LINE * ppm * (1.0 - cut)), Color(col, col.a * 0.6), 2.5)
	else:
		var n: Vector2 = hit.normal
		var out := dir - n * 2.0 * dir.dot(n)
		_dashes(b, to + out * r, to + out * (r + CUE_LINE * ppm), Color(col, col.a * 0.6), 2.5)

func _dashes(b: Face.Builder, from: Vector2, to: Vector2, col: Color, w: float) -> void:
	var len := from.distance_to(to)
	if len < 1.0:
		return
	var d := (to - from) / len
	var s := 0.0
	while s < len:
		var e := minf(s + DASH, len)
		b.stroke(PackedVector2Array([from + d * s, from + d * e]), w, col)
		s = e + DASH_GAP

## The cue: tip, ferrule, a pale ash shaft and an ebony butt with its brass
## ring, laid along the aim behind the ball and drawn back by the power.
func _cue(b: Face.Builder) -> void:
	var pull := power
	if _stroke_t >= 0.0:
		pull = lerpf(_stroke_from, -0.02, clampf(_stroke_t / STROKE, 0.0, 1.0))
	var d := aim_dir
	var c := px(sim.pos[Sim.CUE])
	var r := Sim.R * ppm
	var gap := r + 5.0 + pull * PULL * ppm
	var tip_at := c - d * gap
	var n := Vector2(-d.y, d.x)
	var len := CUE_LEN * ppm
	var w0 := r * 0.46
	var w1 := r * 0.95
	var shadow_off := Vector2(r * 0.5, r * 0.8)
	b.polygon(_taper(tip_at + shadow_off, d, n, 0.0, len, w0, w1), Color(0.05, 0.12, 0.06, 0.22))
	var parts := [
		[0.0, 0.012, Color("5f86b0")],
		[0.012, 0.03, Color("f3ead8")],
		[0.03, 0.95, Color("e3c18c")],
		[0.95, 1.0, Color("3a2820")],
		[1.0, 1.03, BRASS],
		[1.03, CUE_LEN, Color("4a3024")],
	]
	for p in parts:
		var a: float = float(p[0]) * ppm
		var e: float = float(p[1]) * ppm
		var wa := lerpf(w0, w1, a / len)
		var we := lerpf(w0, w1, e / len)
		b.polygon(_taper(tip_at, d, n, a, e, wa, we), p[2])
	# The ebony's points reaching up the shaft.
	for s in [-1.0, 1.0]:
		var base := tip_at - d * 0.95 * ppm
		var wb := lerpf(w0, w1, 0.95 * ppm / len) * 0.5
		b.polygon(PackedVector2Array([base + n * wb * s, base + n * wb * s * 0.1, base - d * (-0.22 * ppm) + n * wb * s * 0.55]), Color("3a2820"))
	# A highlight down the shaft's lit side.
	b.stroke(PackedVector2Array([tip_at - d * 0.04 * ppm - n * w0 * 0.22, tip_at - d * len * 0.97 - n * w1 * 0.22]),
		maxf(1.5, r * 0.12), Color(1.0, 0.96, 0.85, 0.45), false, false)

func _taper(tip_at: Vector2, d: Vector2, n: Vector2, a: float, e: float, wa: float, we: float) -> PackedVector2Array:
	var pa := tip_at - d * a
	var pe := tip_at - d * e
	return PackedVector2Array([pa + n * wa * 0.5, pe + n * we * 0.5, pe - n * we * 0.5, pa - n * wa * 0.5])
