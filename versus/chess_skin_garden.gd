extends "res://versus/chess_skin.gd"

## The house chess set: Knight's cream and rose, carved and standing up on a
## top-down board, each with a face (ui/faces/chess_piece.gd's knight is the
## family this set grew from, and its outline is shared). Every piece moves
## in its own way:
##
## - a pawn hops, once a square, and lands with a squash;
## - a knight crouches, leaps high round the corner of its L leaning into it,
##   and lands in a puff of dust;
## - a bishop glides low along its diagonal, leaning the way it goes;
## - a rook trundles on the ground, rocking, and settles with a heavy thud;
## - the queen rises and sweeps across in a pirouette;
## - the king waddles, a step a square, rocking side to side.
##
## A taken piece is knocked tumbling into the tray with its eyes spun; the
## mated king goes over; the winners hop in a wave; a promoted pawn spins
## into its new shape.

const ChessPiece = preload("res://ui/faces/chess_piece.gd")

## A piece is drawn in a unit box PIECE cells wide with its foot at FOOT,
## the same box ui/faces/chess_piece.gd draws Knight's pieces in.
const PIECE := 1.25
const FOOT := Vector2(0.0, 0.34)
const CREAM_LINE := Color("6b5640")

func id() -> String:
	return "garden"

func foot_drop() -> float:
	return 0.3

func shadow_size() -> Vector2:
	return Vector2(0.34, 0.1)

# --- drawing ---

static var _outlines := {}

## Mirrors a right half (bottom up to the top centre) into a whole outline.
static func _sym(right: PackedVector2Array) -> PackedVector2Array:
	var pts := right.duplicate()
	for i in range(right.size() - 2, -1, -1):
		pts.append(Vector2(-right[i].x, right[i].y))
	# The mirrored first point repeats the start's twin at the bottom; the
	# loop closes itself.
	return pts

static func _curve(from: Vector2, ctrl: Vector2, to: Vector2, steps := 8) -> PackedVector2Array:
	return Face.Builder.bezier2(from, ctrl, to, steps)

static func _outline(type: int) -> PackedVector2Array:
	if _outlines.has(type):
		return _outlines[type]
	var r := PackedVector2Array()
	match type:
		Rules.PAWN:
			r.append_array(_curve(Vector2(0.2, 0.18), Vector2(0.25, -0.1), Vector2(0.0, -0.11)))
			r.append(Vector2(0.0, -0.11))
		Rules.ROOK:
			r.append_array(PackedVector2Array([Vector2(0.2, 0.18), Vector2(0.17, -0.12),
				Vector2(0.215, -0.15), Vector2(0.215, -0.31), Vector2(0.135, -0.31),
				Vector2(0.135, -0.25), Vector2(0.05, -0.25), Vector2(0.05, -0.31), Vector2(0.0, -0.31)]))
		Rules.BISHOP:
			r.append_array(_curve(Vector2(0.2, 0.18), Vector2(0.24, 0.02), Vector2(0.1, -0.05)))
			r.append(Vector2(0.1, -0.05))
			r.append(Vector2(0.14, -0.09))
			r.append_array(_curve(Vector2(0.14, -0.09), Vector2(0.2, -0.27), Vector2(0.0, -0.39), 10))
			r.append(Vector2(0.0, -0.39))
		Rules.QUEEN:
			r.append_array(_curve(Vector2(0.21, 0.18), Vector2(0.23, -0.01), Vector2(0.1, -0.11)))
			r.append(Vector2(0.1, -0.11))
			r.append(Vector2(0.165, -0.19))
			r.append_array(PackedVector2Array([Vector2(0.195, -0.36), Vector2(0.12, -0.27),
				Vector2(0.075, -0.39), Vector2(0.03, -0.28), Vector2(0.0, -0.43)]))
		Rules.KING:
			r.append_array(_curve(Vector2(0.2, 0.18), Vector2(0.27, -0.06), Vector2(0.14, -0.16)))
			r.append(Vector2(0.14, -0.16))
			r.append(Vector2(0.0, -0.16))
	var pts := _sym(r)
	_outlines[type] = pts
	return pts

## Where the face sits on each piece, in unit coordinates; the knight's is
## its own (one eye in profile).
const FACE_AT := {
	Rules.PAWN: Vector2(0.0, 0.03),
	Rules.ROOK: Vector2(0.0, -0.02),
	Rules.BISHOP: Vector2(0.0, 0.06),
	Rules.QUEEN: Vector2(0.0, 0.03),
	Rules.KING: Vector2(0.0, -0.04),
}

func build(b: Face.Builder, type: int, side: int, s: float, face: int, look: float, bare := false) -> void:
	var col: Color = Pal.KNIGHT_CREAM if side == 0 else Pal.KNIGHT_ROSE
	var deep: Color = Pal.KNIGHT_CREAM_DEEP if side == 0 else Pal.KNIGHT_ROSE_DEEP
	# Knight's cream line, taken deeper: on the chessboard's sandstone the
	# cream pieces have to hold their own edge.
	var line: Color = CREAM_LINE if side == 0 else Pal.KNIGHT_ROSE_LINE
	var u := s * PIECE
	# The knight's outline looks left; a knight looking right is mirrored.
	var flip := -1.0 if type == Rules.KNIGHT and look > 0.0 else 1.0
	var map := func(p: Vector2) -> Vector2: return Vector2(p.x * flip, p.y - FOOT.y) * u
	var shape := func(pts: PackedVector2Array) -> PackedVector2Array:
		var m := ChessPiece._mapped(pts, map)
		if flip < 0.0:
			m.reverse()
		return m
	# the plinth
	b.fan(shape.call(Face.Builder.round_rect(Vector2(-0.3, 0.2), Vector2(0.6, 0.14), 0.06)), deep)
	b.fan(shape.call(Face.Builder.round_rect(Vector2(-0.3, 0.17), Vector2(0.6, 0.12), 0.06)), col)
	b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.25, 0.185), Vector2(0.25, 0.185)]), map),
		u * 0.018, Color(1.0, 1.0, 1.0, 0.45))
	var outline := ChessPiece._knight_outline() if type == Rules.KNIGHT else _outline(type)
	var key := "garden_%d" % type
	var body: PackedVector2Array = shape.call(outline)
	b.polygon(body, col)
	# Type details under the shading, so the shade and the light lie over
	# them as over the rest of the body.
	match type:
		Rules.ROOK:
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.17, -0.12), Vector2(0.17, -0.12)]), map),
				u * 0.03, deep)
			for y: float in [0.08]:
				b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.18, y), Vector2(0.18, y)]), map),
					u * 0.014, Color(deep, 0.6))
		Rules.QUEEN:
			for part: PackedVector2Array in Geometry2D.intersect_polygons(outline,
					Face.Builder.round_rect(Vector2(-0.4, -0.5), Vector2(0.8, 0.31), 0.0)):
				b.polygon(shape.call(part), Pal.CROWN)
		Rules.KING:
			for part: PackedVector2Array in Geometry2D.intersect_polygons(outline,
					Face.Builder.round_rect(Vector2(-0.4, 0.07), Vector2(0.8, 0.07), 0.0)):
				b.polygon(shape.call(part), deep)
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.215, 0.07), Vector2(0.215, 0.07)]), map),
				u * 0.02, Color(Pal.PAPER, 0.85))
	for part: PackedVector2Array in ChessPiece._crescent(key + "_shade", outline, Vector2(-0.07, -0.03)):
		b.polygon(shape.call(part), Color(deep, 0.55))
	for part: PackedVector2Array in ChessPiece._crescent(key + "_light", outline, Vector2(0.03, 0.035)):
		b.polygon(shape.call(part), Color(1.0, 1.0, 1.0, 0.4))
	b.stroke(body, u * (0.034 if side == 0 else 0.028), line, true)
	match type:
		Rules.PAWN:
			var head := Vector2(0.0, -0.17)
			b.disc(map.call(head), u * 0.085, line)
			b.disc(map.call(head), u * 0.072, col)
			b.disc(map.call(head + Vector2(-0.02, 0.02)), u * 0.05, Color(deep, 0.4))
			b.disc(map.call(head + Vector2(0.02, -0.025)), u * 0.022, Color(1.0, 1.0, 1.0, 0.7))
		Rules.BISHOP:
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(0.08, -0.29), Vector2(-0.01, -0.17)]), map),
				u * 0.03, line)
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.11, -0.07), Vector2(0.11, -0.07)]), map),
				u * 0.03, deep)
			b.disc(map.call(Vector2(0.0, -0.42)), u * 0.042, Pal.CROWN_DEEP)
			b.disc(map.call(Vector2(0.0, -0.42)), u * 0.03, Pal.CROWN)
		Rules.QUEEN:
			b.stroke(ChessPiece._mapped(Face.Builder.arc_points(Vector2(0.0, -0.3), 0.14, PI * 0.25, PI * 0.75), map),
				u * 0.03, Color(Pal.PAPER, 0.9))
			for tip: Vector2 in [Vector2(-0.195, -0.37), Vector2(-0.075, -0.4), Vector2(0.075, -0.4), Vector2(0.195, -0.37), Vector2(0.0, -0.44)]:
				b.disc(map.call(tip), u * 0.03, Pal.CROWN_DEEP)
				b.disc(map.call(tip + Vector2(-0.006, -0.006)), u * 0.018, Pal.PAPER)
			b.disc(map.call(Vector2(0.0, -0.225)), u * 0.028, Pal.BERRY)
		Rules.KING:
			if bare:
				# the crown gone: a bald crown of the head, and a sprig of
				# three hairs standing up where it was
				for dx: float in [-0.035, 0.0, 0.035]:
					b.stroke(ChessPiece._mapped(Face.Builder.bezier2(Vector2(dx * 0.4, -0.16), Vector2(dx * 1.6, -0.22),
						Vector2(dx * 2.2, -0.25), 6), map), u * 0.016, line)
			else:
				_crown(b, map, u)
		Rules.KNIGHT:
			for i in 3:
				var yy := -0.28 + float(i) * 0.13
				var x0 := 0.1 + float(i) * 0.03
				var curve := Face.Builder.bezier2(Vector2(x0, yy), Vector2(0.19 + float(i) * 0.02, yy + 0.05),
					Vector2(0.15 + float(i) * 0.03, yy + 0.1), 6)
				curve.append(Vector2(0.15 + float(i) * 0.03, yy + 0.1))
				b.stroke(ChessPiece._mapped(curve, map), u * 0.05, Color(deep, 0.9))
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(0.03, -0.4), Vector2(0.0, -0.34)]), map), u * 0.022,
				Color(deep, 0.8))
	if type == Rules.KNIGHT:
		_knight_face(b, map, u, face, line)
	else:
		_face(b, map, u, FACE_AT[type], face, line)

## The king's crown and its cross, in the piece's unit box.
static func _crown(b: Face.Builder, map: Callable, u: float) -> void:
	ChessPiece._crown_into(b, map, u)
	b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(0.0, -0.44), Vector2(0.0, -0.56)]), map), u * 0.04, Pal.CROWN_DEEP)
	b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.05, -0.51), Vector2(0.05, -0.51)]), map), u * 0.04, Pal.CROWN_DEEP)

## The crown's centre in the piece's unit box: halfway up the band and the
## points, below the cross.
const CROWN_AT := Vector2(0.0, -0.33)

func has_crown(type: int) -> bool:
	return type == Rules.KING

func build_crown(b: Face.Builder, _type: int, _side: int, s: float) -> void:
	var u := s * PIECE
	_crown(b, func(p: Vector2) -> Vector2: return (p - CROWN_AT) * u, u)

func crown_seat(_type: int, s: float) -> Vector2:
	return Vector2(0.0, (CROWN_AT.y - FOOT.y) * s * PIECE)

func crown_pop() -> float:
	# as the wobble ends and he starts to go over
	return 0.32

func crown_time() -> float:
	return 1.15

## Knocked up and away the way he falls, turning over once; it lands, hops
## once, and rolls to a stop leaning on its rim.
func crown_pose(u: float, dir: float, seat: float) -> Pose:
	var p := Pose.new()
	if u < 0.55:
		var t := u / 0.55
		p.at = Vector2(dir * 1.05 * t, 0.0)
		p.lift = lerpf(seat, 0.0, t) + 0.75 * sin(PI * t)
		p.tilt = dir * TAU * _ease_out(t)
		if t > 0.85:
			p.squash = _land((t - 0.85) / 0.15, 0.2)
		return p
	if u < 0.8:
		var t := (u - 0.55) / 0.25
		p.at = Vector2(dir * (1.05 + 0.3 * t), 0.0)
		p.lift = 0.18 * sin(PI * t)
		p.tilt = dir * (TAU + 0.6 * t)
		return p
	var t := (u - 0.8) / 0.2
	var e := _ease_out(t)
	p.at = Vector2(dir * (1.35 + 0.12 * e), 0.0)
	# rocks on its rim and settles askew
	p.tilt = dir * (TAU + 0.6 - 0.25 * e) + 0.12 * sin(t * PI * 3.0) * (1.0 - t)
	return p

## Two eyes, two cheeks and a mouth at `c`, in the state `face`.
func _face(b: Face.Builder, map: Callable, u: float, c: Vector2, face: int, line: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		var e := c + Vector2(sx * 0.068, 0.0)
		b.ellipse(map.call(c + Vector2(sx * 0.125, 0.05)), u * 0.038, u * 0.024, Color(Pal.CHEEK, 0.8))
		match face:
			F_BLINK, F_SLEEP:
				b.stroke(ChessPiece._mapped(Face.Builder.arc_points(e + Vector2(0.0, -0.022), 0.024, PI * 0.2, PI * 0.8), map),
					u * 0.017, line)
			F_JOY:
				b.stroke(ChessPiece._mapped(Face.Builder.arc_points(e + Vector2(0.0, 0.012), 0.025, PI * 1.15, PI * 1.85), map),
					u * 0.018, line)
			F_DIZZY:
				var spiral := PackedVector2Array()
				for k in 12:
					var f := float(k) / 11.0
					spiral.append(e + Vector2.from_angle(f * TAU * 1.4 * sx) * 0.03 * (1.0 - f * 0.75))
				b.stroke(ChessPiece._mapped(spiral, map), u * 0.013, line)
			_:
				b.ellipse(map.call(e), u * 0.02, u * 0.026, line)
				b.disc(map.call(e + Vector2(-0.007, -0.01)), u * 0.008, Color(1.0, 1.0, 1.0, 0.9))
				if face == F_WORRY:
					b.stroke(ChessPiece._mapped(PackedVector2Array([e + Vector2(sx * 0.035, -0.05), e + Vector2(-sx * 0.02, -0.065)]), map),
						u * 0.014, line)
	match face:
		F_JOY:
			var m := Face.Builder.arc_points(c + Vector2(0.0, 0.035), 0.04, PI * 0.1, PI * 0.9)
			b.fan(ChessPiece._mapped(m, map), line)
		F_WORRY, F_DIZZY:
			b.stroke(ChessPiece._mapped(Face.Builder.ring(c + Vector2(0.0, 0.065), 0.016, 0.018), map), u * 0.012, line, true)
		F_SLEEP:
			pass
		_:
			b.stroke(ChessPiece._mapped(Face.Builder.arc_points(c + Vector2(0.0, 0.03), 0.03, PI * 0.2, PI * 0.8), map),
				u * 0.014, line)

## The knight's one eye in profile, the way ui/faces/chess_piece.gd draws it.
func _knight_face(b: Face.Builder, map: Callable, u: float, face: int, line: Color) -> void:
	var ec := Vector2(-0.1, -0.2)
	match face:
		F_DIZZY:
			var spiral := PackedVector2Array()
			for k in 14:
				var f := float(k) / 13.0
				spiral.append(ec + Vector2.from_angle(f * TAU * 1.4) * 0.042 * (1.0 - f * 0.75))
			b.stroke(ChessPiece._mapped(spiral, map), u * 0.016, line)
		F_JOY:
			b.stroke(ChessPiece._mapped(Face.Builder.arc_points(ec + Vector2(0.0, 0.01), 0.035, PI * 1.1, PI * 1.9), map),
				u * 0.022, line)
		F_BLINK, F_SLEEP:
			b.stroke(ChessPiece._mapped(Face.Builder.arc_points(ec + Vector2(0.0, -0.03), 0.035, PI * 0.2, PI * 0.8), map),
				u * 0.02, line)
		_:
			b.ellipse(map.call(ec), u * 0.03, u * 0.036, line)
			b.disc(map.call(ec + Vector2(-0.01, -0.015)), u * 0.011, Color(1.0, 1.0, 1.0, 0.9))
			if face == F_WORRY:
				b.stroke(ChessPiece._mapped(PackedVector2Array([ec + Vector2(-0.05, -0.06), ec + Vector2(0.03, -0.075)]), map),
					u * 0.018, line)
	b.ellipse(map.call(Vector2(-0.14, -0.1)), u * 0.045, u * 0.028, Color(Pal.CHEEK, 0.75))
	b.disc(map.call(Vector2(-0.265, -0.06)), u * 0.012, line)

# --- motion ---

func move_time(type: int, from: Vector2, to: Vector2) -> float:
	var d := from.distance_to(to)
	match type:
		Rules.PAWN:
			return 0.3 * maxf(1.0, roundf(d))
		Rules.KNIGHT:
			return 0.66
		Rules.BISHOP:
			return 0.3 + 0.07 * d
		Rules.ROOK:
			return 0.34 + 0.07 * d
		Rules.QUEEN:
			return 0.5 + 0.06 * d
		Rules.KING:
			return 0.36 * maxf(1.0, roundf(d))
	return super.move_time(type, from, to)

func move_pose(type: int, from: Vector2, to: Vector2, u: float) -> Pose:
	var dir := to - from
	var look := signf(dir.x)
	match type:
		Rules.PAWN:
			# One hop a square: each a little arc, squashed at both ends.
			var hops := maxf(1.0, roundf(dir.length()))
			var k := minf(u * hops, hops - 0.0001)
			var hop := floorf(k)
			var t := k - hop
			var p := Pose.at_cell(from + dir * ((hop + _ease_in_out(t)) / hops))
			p.lift = 0.3 * sin(PI * t)
			p.squash = _hop_squash(t)
			return p
		Rules.KNIGHT:
			# Crouch, leap round the corner of the L, land.
			var corner := from + (Vector2(dir.x, 0.0) if absf(dir.x) > absf(dir.y) else Vector2(0.0, dir.y))
			var p := Pose.new()
			p.look = look
			if u < 0.18:
				var c := u / 0.18
				p.at = from
				p.squash = Vector2(1.0 + 0.12 * c, 1.0 - 0.16 * c)
				p.tilt = -look * 0.12 * c
				return p
			var t := (u - 0.18) / 0.82
			var e := _ease_in_out(t)
			var a := from.lerp(corner, e)
			var bb := corner.lerp(to, e)
			p.at = a.lerp(bb, e)
			p.lift = 1.1 * sin(PI * t)
			p.tilt = look * 0.28 * sin(PI * t) - look * 0.12 * (1.0 - t) * (1.0 - t)
			p.squash = Vector2(1.0 - 0.08 * sin(PI * t), 1.0 + 0.1 * sin(PI * t))
			if t > 0.9:
				p.squash = _land(( t - 0.9) / 0.1)
			return p
		Rules.BISHOP:
			var e := _ease_in_out(u)
			var p := Pose.at_cell(from.lerp(to, e))
			p.lift = 0.14 * sin(PI * u) + 0.02 * sin(u * PI * 6.0)
			p.tilt = look * 0.2 * sin(PI * u)
			return p
		Rules.ROOK:
			var e := _back_out(u)
			var p := Pose.at_cell(from.lerp(to, e))
			p.tilt = 0.07 * sin(u * PI * 7.0) * (1.0 - u) - look * 0.08 * sin(PI * minf(u * 1.2, 1.0))
			if u > 0.8:
				p.squash = _land((u - 0.8) / 0.2, 0.14)
			return p
		Rules.QUEEN:
			var e := _ease_in_out(u)
			var p := Pose.at_cell(from.lerp(to, e))
			p.lift = 0.55 * sin(PI * u)
			# A pirouette: one turn, read as the width going through a turn.
			p.squash = Vector2(lerpf(1.0, absf(cos(u * TAU)), sin(PI * u)), 1.0 + 0.06 * sin(PI * u))
			p.tilt = look * 0.1 * sin(PI * u)
			return p
		Rules.KING:
			var steps := maxf(1.0, roundf(dir.length())) * 2.0
			var k := minf(u * steps, steps - 0.0001)
			var step := floorf(k)
			var t := k - step
			var p := Pose.at_cell(from + dir * ((step + _ease_in_out(t)) / steps))
			p.lift = 0.08 * sin(PI * t)
			p.tilt = (0.13 if int(step) % 2 == 0 else -0.13) * sin(PI * t)
			if u > 0.85:
				p.squash = _land((u - 0.85) / 0.15, 0.08)
			return p
	return super.move_pose(type, from, to, u)

func contact_at(type: int) -> float:
	match type:
		Rules.PAWN:
			return 0.8
		Rules.KNIGHT:
			return 0.93
		Rules.ROOK:
			return 0.72
	return 0.82

func takeoff_cue(type: int) -> String:
	match type:
		Rules.KNIGHT:
			return "hop"
		Rules.ROOK, Rules.BISHOP, Rules.QUEEN:
			return "slide"
	return "lift"

func land_cue(_type: int) -> String:
	return "place"

func lands_with_dust(type: int) -> bool:
	return type == Rules.KNIGHT or type == Rules.ROOK

func knock_time() -> float:
	return 0.8

## Knocked away the way it was hit, up, over and down into the tray,
## spinning, shrinking as it goes.
func knock_pose(from: Vector2, to: Vector2, dir: Vector2, u: float, tray_scale: float) -> Pose:
	var push := from + dir.normalized() * 0.5
	var e := _ease_in_out(u)
	var a := from.lerp(push, e)
	var bb := push.lerp(to, e)
	var p := Pose.at_cell(a.lerp(bb, e))
	p.lift = 1.2 * sin(PI * u)
	p.tilt = signf(dir.x if dir.x != 0.0 else 1.0) * TAU * 1.25 * _ease_out(u)
	p.scale = lerpf(1.0, tray_scale, e)
	if u > 0.9:
		p.squash = _land((u - 0.9) / 0.1, 0.18)
	return p

func idle_pose(type: int, at: Vector2, clock: float, phase: float, selected: bool) -> Pose:
	var p := Pose.at_cell(at)
	var breath := sin(clock * 1.9 + phase * TAU)
	p.squash = Vector2(1.0 - 0.012 * breath, 1.0 + 0.022 * breath)
	if selected:
		p.lift = 0.16 + 0.05 * sin(clock * 6.0)
		p.squash = Vector2(1.0, 1.0) + Vector2(-0.02, 0.03) * sin(clock * 6.0)
	elif type == Rules.QUEEN:
		# She never quite stands still: a slow sway.
		p.tilt = 0.025 * sin(clock * 1.1 + phase * TAU)
	return p

func fidget_gap() -> Vector2:
	return Vector2(2.5, 5.0)

func fidget_time(type: int) -> float:
	return 0.9 if type == Rules.QUEEN or type == Rules.BISHOP else 0.7

## Each piece's own fidget: a pawn bounces twice, a knight rears, a bishop
## turns to look round, a rook rocks on its base, the queen twirls, the
## king straightens his crown with a little hop.
func fidget_pose(type: int, at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	match type:
		Rules.PAWN:
			var t := fmod(u * 2.0, 1.0)
			p.lift = 0.14 * sin(PI * t)
			p.squash = _hop_squash(t)
		Rules.KNIGHT:
			p.tilt = 0.3 * sin(PI * u) * (1.0 if int(at.x) % 2 == 0 else -1.0)
			p.lift = 0.06 * sin(PI * u)
		Rules.BISHOP:
			p.squash = Vector2(lerpf(1.0, absf(cos(u * PI)), sin(PI * u) * 0.7), 1.0)
		Rules.ROOK:
			p.tilt = 0.09 * sin(u * PI * 4.0) * (1.0 - u)
		Rules.QUEEN:
			p.lift = 0.1 * sin(PI * u)
			p.squash = Vector2(absf(cos(u * TAU)), 1.0 + 0.04 * sin(PI * u))
		Rules.KING:
			p.lift = 0.1 * sin(PI * u)
			p.tilt = 0.06 * sin(u * TAU)
			p.squash = _hop_squash(u)
	return p

func shiver_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at + Vector2(sin(u * PI * 6.0) * 0.06 * (1.0 - u), 0.0))
	p.tilt = sin(u * PI * 6.0) * 0.1 * (1.0 - u)
	return p

func tremble_time() -> float:
	return 0.9

func tremble_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at + Vector2(sin(u * PI * 16.0) * 0.035 * (1.0 - u), 0.0))
	p.squash = Vector2(1.0 + 0.05 * (1.0 - u), 1.0 - 0.05 * (1.0 - u))
	p.lift = 0.08 * sin(PI * minf(u * 3.0, 1.0))
	return p

func topple_time() -> float:
	return 0.9

func topple_pose(at: Vector2, u: float, dir: float) -> Pose:
	var p := Pose.at_cell(at)
	# A wobble first, then over, and a bounce as it lands on its side.
	if u < 0.3:
		p.tilt = dir * 0.12 * sin(u / 0.3 * PI * 2.0)
		return p
	var t := (u - 0.3) / 0.7
	p.tilt = dir * PI * 0.5 * _bounce_out(t)
	p.at += Vector2(dir * 0.12 * t, 0.0)
	return p

func cheer_time() -> float:
	return 0.55

func cheer_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.lift = 0.4 * sin(PI * u)
	p.squash = _hop_squash(u)
	return p

func promote_time() -> float:
	return 0.8

func promote_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.lift = 0.45 * sin(PI * u)
	p.squash = Vector2(maxf(0.05, absf(cos(u * PI * 3.0))), 1.0)
	p.scale = 1.0 + 0.15 * sin(PI * u)
	return p

func enter_time() -> float:
	return 0.5

func enter_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.lift = 2.2 * (1.0 - _bounce_out(u))
	p.alpha = clampf(u * 3.0, 0.0, 1.0)
	if u > 0.55:
		p.squash = _land((u - 0.55) / 0.45, 0.12)
	return p

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

static func _ease_out(u: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u)

static func _back_out(u: float) -> float:
	var c := 1.4
	var t := u - 1.0
	return 1.0 + (c + 1.0) * t * t * t + c * t * t

static func _bounce_out(u: float) -> float:
	if u < 1.0 / 2.75:
		return 7.5625 * u * u
	if u < 2.0 / 2.75:
		var t := u - 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	if u < 2.5 / 2.75:
		var t := u - 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	var t := u - 2.625 / 2.75
	return 7.5625 * t * t + 0.984375
