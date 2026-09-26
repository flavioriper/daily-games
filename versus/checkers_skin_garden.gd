extends "res://versus/checkers_skin.gd"

## The house checkers set: round wooden pieces in chess's cream and rose,
## seen from above, each with a face on its top that looks where the action
## is. A king is two pieces stacked with a little gold crown on top. Every
## move is a small scene:
##
## - a man hops a square, squashing as it leaves and lands, and wobbles to
##   rest the way a dropped coin does;
## - a king glides and twirls a full turn on the way;
## - a capture crouches, leaps high over what it takes -- a front flip on
##   the first jump, a spin on the next, and so on down a chain;
## - a taken piece is squashed flat at the touch, then tossed spinning like
##   a coin into the tray, where it sleeps;
## - crowning drops a crown out of the sky onto the man's head;
## - at rest they breathe, blink, and now and then hop, twirl, wobble or
##   peek left and right; the winners hop in a wave and the losers turn
##   face down.

const EDGE := 0.075
## A king stands this much higher than a man, in cells: the second piece.
const STACK := 0.1
const LINE_CREAM := Color("8a7358")
const FELT := Color("7fa05f")
const FELT_DEEP := Color("5f7f45")

func id() -> String:
	return "garden"

func radius() -> float:
	return 0.36

func shadow_size() -> Vector2:
	return Vector2(0.44, 0.4)

# --- drawing ---

static var _cut := {}

## A disc less a copy of itself nudged by `shift` (both in radii): the
## crescent left along the far side. Cached per size.
static func _crescent(r: float, shift: Vector2) -> Array:
	var key := "%d|%s" % [int(r * 10.0), shift]
	if _cut.has(key):
		return _cut[key]
	var body := Face.Builder.ring(Vector2.ZERO, r, r)
	var moved := PackedVector2Array()
	for p in body:
		moved.append(p + shift * r)
	var out: Array = Geometry2D.clip_polygons(body, moved)
	_cut[key] = out
	return out

static func _colours(side: int) -> Array:
	if side == 0:
		return [Pal.KNIGHT_CREAM, Pal.KNIGHT_CREAM_DEEP, LINE_CREAM]
	return [Pal.KNIGHT_ROSE, Pal.KNIGHT_ROSE_DEEP, Pal.KNIGHT_ROSE_LINE]

## A wooden disc's edge band showing below its top at `c`.
func _edge(b: Face.Builder, c: Vector2, r: float, s: float, deep: Color, line: Color) -> void:
	var edge := c + Vector2(0.0, s * EDGE)
	b.disc(edge, r, deep)
	b.stroke(Face.Builder.ring(edge, r, r), s * 0.026, line, true)
	# grain on the band
	for k in 5:
		var x := (float(k) - 2.0) * r * 0.36
		var y := sqrt(maxf(r * r - x * x, 0.0))
		b.stroke(PackedVector2Array([c + Vector2(x, y + s * 0.012), c + Vector2(x * 1.02, y + s * EDGE * 0.8)]),
			s * 0.01, Color(line, 0.35))

func _top(b: Face.Builder, c: Vector2, r: float, s: float, col: Color, deep: Color, line: Color) -> void:
	# the carved groove, and a lit lip inside it
	b.stroke(Face.Builder.ring(c, r * 0.74, r * 0.74), s * 0.026, Color(deep, 0.6), true)
	b.stroke(Face.Builder.ring(c + Vector2(0.0, s * 0.008), r * 0.7, r * 0.7), s * 0.01, Color(1, 1, 1, 0.35), true)
	for part: PackedVector2Array in _crescent(r, Vector2(-0.12, -0.14)):
		b.polygon(_moved(part, c), Color(deep, 0.35))
	for part: PackedVector2Array in _crescent(r, Vector2(0.06, 0.08)):
		b.polygon(_moved(part, c), Color(1, 1, 1, 0.42))
	b.stroke(Face.Builder.ring(c, r, r), s * 0.03, line, true)

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out

## Where the top of a piece sits: a king's is the upper piece of the stack.
func _top_at(type: int, s: float) -> Vector2:
	return Vector2(0.0, -s * STACK * 0.5) if type == Rules.KING else Vector2.ZERO

func build_base(b: Face.Builder, type: int, side: int, s: float) -> void:
	var cols := _colours(side)
	var r := s * radius()
	if type == Rules.KING:
		var low := Vector2(0.0, s * STACK * 0.5)
		_edge(b, low, r, s, cols[1], cols[2])
		b.disc(low, r, (cols[0] as Color).darkened(0.08))
		b.stroke(Face.Builder.ring(low, r, r), s * 0.03, cols[2], true)
	_edge(b, _top_at(type, s), r, s, cols[1], cols[2])

func build(b: Face.Builder, type: int, side: int, s: float, face: int, gaze: Vector2i) -> void:
	var cols := _colours(side)
	var col: Color = cols[0]
	var deep: Color = cols[1]
	var line: Color = cols[2]
	var r := s * radius()
	var c := _top_at(type, s)
	b.disc(c, r, col)
	_top(b, c, r, s, col, deep, line)
	_face(b, c + Vector2(0.0, r * 0.06), r, s, face, gaze, line)
	if type == Rules.KING:
		_crown(b, c + Vector2(0.0, -r * 0.78), r)

func build_under(b: Face.Builder, type: int, side: int, s: float) -> void:
	var cols := _colours(side)
	var deep: Color = cols[1]
	var line: Color = cols[2]
	var r := s * radius()
	var c := _top_at(type, s)
	b.disc(c, r, deep)
	# a felt pad with a stitched edge
	b.disc(c, r * 0.72, FELT_DEEP)
	b.disc(c + Vector2(0.0, -s * 0.006), r * 0.68, FELT)
	var n := 16
	for k in n:
		var a0 := TAU * float(k) / n
		b.stroke(Face.Builder.arc_points(c, r * 0.6, a0, a0 + TAU / n * 0.5), s * 0.012, Color(1, 1, 1, 0.45))
	b.stroke(Face.Builder.ring(c, r, r), s * 0.03, line, true)

func build_crown(b: Face.Builder, _side: int, s: float) -> void:
	_crown(b, Vector2.ZERO, s * radius())

func crown_seat(s: float) -> Vector2:
	return Vector2(0.0, -s * STACK * 0.5 - s * radius() * 0.78)

## A little gold crown centred at `c`, sized off the piece's radius `r`.
static func _crown(b: Face.Builder, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for q: Vector2 in [Vector2(-0.4, 0.16), Vector2(0.4, 0.16), Vector2(0.46, -0.2), Vector2(0.2, -0.02),
			Vector2(0.0, -0.3), Vector2(-0.2, -0.02), Vector2(-0.46, -0.2)]:
		pts.append(c + q * r)
	b.polygon(_moved(pts, Vector2(0.0, r * 0.06)), Color(Pal.OUTLINE, 0.3))
	b.polygon(pts, Pal.CROWN)
	b.stroke(pts, r * 0.05, Pal.CROWN_DEEP, true)
	b.stroke(PackedVector2Array([c + Vector2(-0.38, 0.06) * r, c + Vector2(0.38, 0.06) * r]), r * 0.05, Pal.CROWN_DEEP)
	for tip: Vector2 in [Vector2(-0.46, -0.2), Vector2(0.0, -0.3), Vector2(0.46, -0.2)]:
		b.disc(c + tip * r, r * 0.075, Pal.CROWN_DEEP)
		b.disc(c + tip * r + Vector2(-0.01, -0.01) * r, r * 0.05, Pal.CROWN)
		b.disc(c + tip * r + Vector2(-0.02, -0.025) * r, r * 0.02, Color(1, 1, 1, 0.85))
	b.disc(c + Vector2(0.0, 0.05) * r, r * 0.07, Pal.BERRY)
	b.disc(c + Vector2(-0.02, 0.03) * r, r * 0.025, Color(1, 1, 1, 0.7))

## Two eyes that look along `gaze`, two cheeks and a mouth, in the state
## `face`, centred at `c` on a piece of radius `r`.
func _face(b: Face.Builder, c: Vector2, r: float, s: float, face: int, gaze: Vector2i, line: Color) -> void:
	var look := Vector2(gaze).normalized() * r * 0.055 if gaze != Vector2i.ZERO else Vector2.ZERO
	var w := s * 0.018
	for sx: float in [-1.0, 1.0]:
		var e := c + Vector2(sx * 0.25 * r, -0.1 * r)
		b.ellipse(c + Vector2(sx * 0.46 * r, 0.13 * r), r * 0.12, r * 0.075, Color(Pal.CHEEK, 0.8))
		match face:
			F_BLINK:
				b.stroke(Face.Builder.arc_points(e + Vector2(0.0, -0.06 * r), 0.1 * r, PI * 0.2, PI * 0.8), w, line)
			F_SLEEP:
				b.stroke(Face.Builder.arc_points(e + Vector2(0.0, -0.08 * r), 0.1 * r, PI * 0.25, PI * 0.75), w, line)
			F_JOY:
				b.stroke(Face.Builder.arc_points(e + Vector2(0.0, 0.05 * r), 0.1 * r, PI * 1.15, PI * 1.85), w * 1.1, line)
			F_DIZZY:
				var spiral := PackedVector2Array()
				for k in 14:
					var f := float(k) / 13.0
					spiral.append(e + Vector2.from_angle(f * TAU * 1.5 * sx) * 0.12 * r * (1.0 - f * 0.8))
				b.stroke(spiral, w * 0.8, line)
			_:
				var small := face == F_WORRY
				b.ellipse(e, r * 0.135, r * 0.16, Color("fffaf1"))
				b.stroke(Face.Builder.ring(e, r * 0.135, r * 0.16), w * 0.6, Color(line, 0.6), true)
				var pupil := e + look
				b.disc(pupil, r * (0.065 if small else 0.085), line)
				b.disc(pupil + Vector2(-0.03, -0.04) * r, r * 0.028, Color(1, 1, 1, 0.95))
				if face == F_WORRY:
					b.stroke(PackedVector2Array([e + Vector2(sx * 0.14, -0.2) * r, e + Vector2(-sx * 0.08, -0.26) * r]), w, line)
				elif face == F_BRAVE:
					b.stroke(PackedVector2Array([e + Vector2(sx * 0.15, -0.27) * r, e + Vector2(-sx * 0.07, -0.19) * r]), w * 1.2, line)
	var m := c + Vector2(0.0, 0.22 * r)
	match face:
		F_JOY:
			b.fan(Face.Builder.arc_points(m + Vector2(0.0, -0.04 * r), 0.13 * r, PI * 0.05, PI * 0.95), line)
			b.disc(m + Vector2(0.0, 0.05 * r), 0.045 * r, Color(Pal.BERRY, 0.9))
		F_WORRY, F_DIZZY:
			b.stroke(Face.Builder.ring(m + Vector2(0.0, 0.03 * r), 0.045 * r, 0.055 * r), w * 0.8, line, true)
		F_SLEEP:
			b.stroke(PackedVector2Array([m + Vector2(-0.04, 0.02) * r, m + Vector2(0.04, 0.02) * r]), w * 0.8, line)
		F_BRAVE:
			b.stroke(Face.Builder.arc_points(m + Vector2(0.0, -0.06 * r), 0.14 * r, PI * 0.2, PI * 0.8), w * 1.1, line)
			b.stroke(PackedVector2Array([m + Vector2(-0.1, 0.04) * r, m + Vector2(0.1, 0.04) * r]), w * 0.7, line)
		_:
			b.stroke(Face.Builder.arc_points(m + Vector2(0.0, -0.04 * r), 0.1 * r, PI * 0.2, PI * 0.8), w, line)

# --- motion ---

func step_time(type: int, from: Vector2, to: Vector2) -> float:
	if type == Rules.KING:
		return 0.34 + 0.08 * from.distance_to(to)
	return 0.42

func step_pose(type: int, from: Vector2, to: Vector2, u: float) -> Pose:
	var dir := to - from
	var p := Pose.new()
	p.gaze = dir.normalized()
	if type == Rules.KING:
		# a glide with a twirl
		var e := _ease_in_out(u)
		p.at = from.lerp(to, e)
		p.lift = 0.2 * sin(PI * u)
		p.spin = TAU * e * (1.0 if dir.x >= 0.0 else -1.0)
		p.squash = Vector2(1.0 + 0.06 * sin(PI * u), 1.0 - 0.04 * sin(PI * u))
		if u > 0.85:
			p.squash = _land((u - 0.85) / 0.15, 0.1)
		return p
	# a hop, then a coin's wobble as it settles
	if u < 0.78:
		var t := u / 0.78
		p.at = from.lerp(to, _ease_in_out(t))
		p.lift = 0.42 * sin(PI * t)
		p.squash = _hop_squash(t)
		p.spin = 0.18 * sin(TAU * t) * (1.0 if dir.x >= 0.0 else -1.0)
		return p
	p.at = to
	p.squash = _wobble((u - 0.78) / 0.22, 0.09)
	return p

func jump_time(type: int, from: Vector2, to: Vector2, leg: int) -> float:
	if type == Rules.KING:
		return 0.46 + 0.05 * from.distance_to(to)
	return 0.56 if leg == 0 else 0.46

func jump_pose(type: int, from: Vector2, to: Vector2, u: float, leg: int, _legs: int) -> Pose:
	var dir := to - from
	var sgn := 1.0 if dir.x >= 0.0 else -1.0
	var p := Pose.new()
	p.gaze = dir.normalized()
	if u < CROUCH:
		var c := u / CROUCH
		p.at = from
		p.squash = Vector2(1.0 + 0.14 * c, 1.0 - 0.16 * c)
		return p
	var t := (u - CROUCH) / (1.0 - CROUCH)
	var e := _ease_in_out(t)
	p.at = from.lerp(to, e)
	if type == Rules.KING:
		p.lift = 0.75 * sin(PI * t)
		p.spin = TAU * e * sgn
	else:
		p.lift = 0.95 * sin(PI * t)
		if leg % 2 == 0:
			# a front flip over the piece it takes
			p.flip = TAU * e
		else:
			p.spin = TAU * e * sgn
	p.squash = Vector2(1.0 - 0.06 * sin(PI * t), 1.0 + 0.08 * sin(PI * t))
	if t > 0.88:
		p.squash = _land((t - 0.88) / 0.12, 0.2)
	return p

const CROUCH := 0.14

func jump_contact(frac: float) -> float:
	# the ease above run backwards: when is the piece `frac` of the way
	var t := 0.5 - sin(asin(clampf(1.0 - 2.0 * frac, -1.0, 1.0)) / 3.0)
	return CROUCH + (1.0 - CROUCH) * t

func knock_time() -> float:
	return 0.95

## Squashed flat at the touch, then tossed spinning like a coin, up, over
## and down into the tray, shrinking as it goes.
func knock_pose(from: Vector2, to: Vector2, dir: Vector2, u: float, tray_scale: float) -> Pose:
	var p := Pose.new()
	p.gaze = Vector2(0.0, -1.0)
	if u < 0.22:
		var k := minf(u / 0.22 * 3.0, 1.0)
		p.at = from
		p.squash = Vector2(1.0 + 0.3 * k, 1.0 - 0.45 * k)
		return p
	var t := (u - 0.22) / 0.78
	var e := _ease_in_out(t)
	var push := from + dir.normalized() * 0.6
	p.at = from.lerp(push, e).lerp(push.lerp(to, e), e)
	p.lift = 1.5 * sin(PI * t)
	p.flip = 2.0 * TAU * _ease_out(t)
	p.spin = 0.8 * sin(PI * t) * signf(dir.x if dir.x != 0.0 else 1.0)
	p.scale = lerpf(1.0, tray_scale, e)
	var back := minf(t * 5.0, 1.0)
	p.squash = Vector2(1.3, 0.55).lerp(Vector2.ONE, back)
	if t > 0.9:
		p.squash = _land((t - 0.9) / 0.1, 0.2)
	return p

func crown_time() -> float:
	return 1.0

func crown_land() -> float:
	return 0.55

func crown_pose(u: float) -> Pose:
	var p := Pose.new()
	var t := clampf(u / crown_land(), 0.0, 1.0)
	p.lift = 3.2 * (1.0 - t * t)
	p.spin = 1.5 * TAU * (1.0 - t)
	return p

func crowned_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.gaze = Vector2(0.0, -1.0)
	var land := crown_land()
	if u > land:
		var k := (u - land) / (1.0 - land)
		p.squash = _land(minf(k * 2.0, 1.0), 0.24)
		p.lift = 0.22 * sin(PI * k) * (1.0 if k > 0.3 else 0.0)
		p.spin = 0.3 * sin(PI * k) * (1.0 - k)
	return p

func idle_pose(type: int, at: Vector2, clock: float, phase: float, selected: bool) -> Pose:
	var p := Pose.at_cell(at)
	var breath := sin(clock * 1.9 + phase * TAU)
	p.scale = 1.0 + 0.014 * breath
	if selected:
		p.lift = 0.24 + 0.05 * sin(clock * 6.0)
		p.squash = Vector2(1.0, 1.0) + Vector2(-0.02, 0.03) * sin(clock * 6.0)
		p.spin = 0.06 * sin(clock * 3.0)
	elif type == Rules.KING:
		# a king is never quite still: a slow proud turn
		p.spin = 0.06 * sin(clock * 0.9 + phase * TAU)
	return p

func fidget_gap() -> Vector2:
	return Vector2(2.2, 4.5)

func fidget_kinds() -> int:
	return 4

func fidget_time(_type: int, kind: int) -> float:
	return [0.75, 0.8, 1.2, 1.4][kind]

## A double hop; a twirl in place; a coin's wobble, faster as it dies; a
## peek left then right.
func fidget_pose(_type: int, at: Vector2, u: float, kind: int) -> Pose:
	var p := Pose.at_cell(at)
	match kind:
		0:
			var t := fmod(u * 2.0, 1.0)
			p.lift = 0.16 * sin(PI * t)
			p.squash = _hop_squash(t)
		1:
			p.spin = TAU * _ease_in_out(u)
			p.lift = 0.06 * sin(PI * u)
		2:
			p.squash = _wobble(u, 0.12)
			p.lift = 0.04 * sin(PI * u)
		3:
			p.gaze = Vector2(-1.0, 0.0) if u < 0.5 else Vector2(1.0, 0.0)
			p.spin = 0.12 * sin(TAU * u)
			p.lift = 0.05 * sin(PI * u)
	return p

func shiver_time() -> float:
	return 0.42

func shiver_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at + Vector2(sin(u * PI * 7.0) * 0.06 * (1.0 - u), 0.0))
	p.spin = sin(u * PI * 7.0) * 0.14 * (1.0 - u)
	return p

func nudge_time() -> float:
	return 0.6

func nudge_pose(at: Vector2, dir: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at + dir.normalized() * 0.14 * sin(PI * minf(u * 2.0, 1.0)))
	p.gaze = dir.normalized()
	p.lift = 0.08 * sin(PI * u)
	return p

func cheer_time() -> float:
	return 0.6

func cheer_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.lift = 0.45 * sin(PI * u)
	p.squash = _hop_squash(u)
	p.spin = TAU * _ease_in_out(u)
	return p

func yield_time() -> float:
	return 0.6

func yield_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.lift = 0.4 * sin(PI * u)
	p.flip = PI * _ease_in_out(u)
	if u > 0.85:
		p.squash = _land((u - 0.85) / 0.15, 0.12)
	return p

func enter_time() -> float:
	return 0.6

## Dealt onto the board like coins: falling, turning over twice, and
## wobbling to rest.
func enter_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	if u < 0.6:
		var t := u / 0.6
		p.lift = 2.4 * (1.0 - t * t)
		p.flip = 2.0 * TAU * _ease_out(t)
		p.alpha = clampf(t * 4.0, 0.0, 1.0)
		return p
	p.squash = _wobble((u - 0.6) / 0.4, 0.12)
	return p

func takeoff_cue(type: int, capture: bool) -> String:
	if capture:
		return "hop"
	return "slide" if type == Rules.KING else "lift"

func land_cue(_type: int, _capture: bool) -> String:
	return "place"

func lands_with_dust(type: int, capture: bool) -> bool:
	return capture or type == Rules.KING

# --- curves ---

## A hop's squash: crouched at the start, stretched in the air, squashed on
## landing, `t` 0 to 1.
static func _hop_squash(t: float) -> Vector2:
	if t < 0.15:
		var c := t / 0.15
		return Vector2(1.0 + 0.1 * (1.0 - c), 1.0 - 0.12 * (1.0 - c))
	if t > 0.85:
		return _land((t - 0.85) / 0.15)
	return Vector2(0.95, 1.06)

## Landing: squashed flat then springing back, `t` 0 to 1.
static func _land(t: float, amount := 0.18) -> Vector2:
	var k := sin(PI * t) * amount
	return Vector2(1.0 + k * 0.8, 1.0 - k)

## A dropped coin settling: it rocks one way and the other, faster and
## smaller, `t` 0 to 1.
static func _wobble(t: float, amount: float) -> Vector2:
	var a := amount * (1.0 - t) * (1.0 - t)
	var ph := TAU * (1.5 * t + 2.5 * t * t)
	return Vector2(1.0 + a * cos(ph), 1.0 + a * sin(ph))

static func _ease_out(u: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u)
