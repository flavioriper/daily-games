extends "res://versus/chess_skin.gd"

## The tournament set: Staunton shapes in flat white and black on a wooden
## board, no faces, nothing that fidgets (the user, 2026-10-30: real players
## asked for "more professional tools", with a wooden board in the pictures).
## Every piece is told from its neighbours by its head at a glance, the pieces
## wear their true colours (`true_colours`), and a move is a quick slide. The
## board reads `cartoon()` and leaves off the garden's speed lines, dust, sweat
## and sleepers. The garden set (versus/chess_skin_garden.gd) is one tap away
## in the game's options.

const ChessPiece = preload("res://ui/faces/chess_piece.gd")

const PIECE := 1.0
const FOOT := Vector2(0.0, 0.4)
const WHITE_FILL := Color("f7f0e2")
const WHITE_DEEP := Color("cdbda3")
const WHITE_LINE := Color("3b2f26")
const BLACK_FILL := Color("3a3330")
const BLACK_DEEP := Color("231e1c")
const BLACK_LINE := Color("120f0e")
const BLACK_LIT := Color("c9bfb4")

func id() -> String:
	return "classic"

func cartoon() -> bool:
	return false

func true_colours() -> bool:
	return true

func frame() -> float:
	return 0.12

func foot_drop() -> float:
	return 0.4

func shadow_size() -> Vector2:
	return Vector2(0.27, 0.05)

# --- drawing ---

static var _outlines := {}

static func _sym(right: PackedVector2Array) -> PackedVector2Array:
	var pts := right.duplicate()
	for i in range(right.size() - 2, -1, -1):
		pts.append(Vector2(-right[i].x, right[i].y))
	return pts

## The foot every piece stands on, up to its waist at `w` wide, `y` high.
static func _base(w: float, y: float, width := 0.31) -> PackedVector2Array:
	var r := PackedVector2Array([Vector2(width, 0.4), Vector2(width, 0.33), Vector2(width - 0.05, 0.28)])
	r.append_array(Face.Builder.bezier2(Vector2(width - 0.05, 0.28), Vector2(w + 0.02, 0.2), Vector2(w, y), 8))
	return r

static func _outline(type: int) -> PackedVector2Array:
	if _outlines.has(type):
		return _outlines[type]
	var r := PackedVector2Array()
	match type:
		Rules.PAWN:
			r = _base(0.075, -0.02, 0.26)
			r.append_array(PackedVector2Array([Vector2(0.15, -0.04), Vector2(0.15, -0.075), Vector2(0.0, -0.075)]))
		Rules.ROOK:
			r = _base(0.145, -0.12, 0.3)
			r.append_array(PackedVector2Array([Vector2(0.215, -0.17), Vector2(0.215, -0.33), Vector2(0.125, -0.33),
				Vector2(0.125, -0.26), Vector2(0.05, -0.26), Vector2(0.05, -0.33), Vector2(0.0, -0.33)]))
		Rules.BISHOP:
			r = _base(0.085, 0.02, 0.29)
			r.append_array(PackedVector2Array([Vector2(0.15, -0.005), Vector2(0.15, -0.04), Vector2(0.09, -0.05)]))
			r.append_array(Face.Builder.bezier2(Vector2(0.09, -0.05), Vector2(0.23, -0.17), Vector2(0.0, -0.355), 10))
		Rules.QUEEN:
			r = _base(0.09, -0.03, 0.31)
			r.append_array(PackedVector2Array([Vector2(0.16, -0.06), Vector2(0.16, -0.095), Vector2(0.1, -0.11),
				Vector2(0.17, -0.135), Vector2(0.285, -0.3), Vector2(0.175, -0.205), Vector2(0.14, -0.345),
				Vector2(0.07, -0.205), Vector2(0.0, -0.37)]))
		Rules.KING:
			r = _base(0.095, -0.03, 0.31)
			r.append_array(PackedVector2Array([Vector2(0.16, -0.06), Vector2(0.16, -0.095), Vector2(0.09, -0.11)]))
			r.append_array(Face.Builder.bezier2(Vector2(0.09, -0.11), Vector2(0.34, -0.25), Vector2(0.125, -0.27), 8))
			r.append_array(Face.Builder.bezier2(Vector2(0.125, -0.27), Vector2(0.07, -0.275), Vector2(0.0, -0.2), 6))
	var pts := _sym(r)
	_outlines[type] = pts
	return pts

## `side` is the piece's true colour here: 0 white, 1 black.
func build(b: Face.Builder, type: int, side: int, s: float, _face: int, _look: float, _bare := false) -> void:
	var col := WHITE_FILL if side == 0 else BLACK_FILL
	var deep := WHITE_DEEP if side == 0 else BLACK_DEEP
	var line := WHITE_LINE if side == 0 else BLACK_LINE
	var lit := Color(1, 1, 1, 0.75) if side == 0 else Color(BLACK_LIT, 0.55)
	var u := s * PIECE
	var map := func(p: Vector2) -> Vector2: return (p - FOOT) * u
	var shape := func(pts: PackedVector2Array) -> PackedVector2Array: return ChessPiece._mapped(pts, map)
	var heavy := u * 0.03
	if type == Rules.KNIGHT:
		_knight(b, shape, map, u, col, deep, line, lit)
		return
	var outline := _outline(type)
	var body: PackedVector2Array = shape.call(outline)
	b.polygon(body, col)
	var key := "classic_%d" % type
	for part: PackedVector2Array in ChessPiece._crescent(key + "_shade", outline, Vector2(-0.055, -0.02)):
		b.polygon(shape.call(part), Color(deep, 0.75))
	b.stroke(body, heavy, line, true)
	# the foot's band, a ring across the collar
	b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.25, 0.285), Vector2(0.25, 0.285)]), map), u * 0.018, Color(line, 0.8))
	match type:
		Rules.PAWN:
			var head := Vector2(0.0, -0.17)
			b.disc(map.call(head), u * 0.122, line)
			b.disc(map.call(head), u * 0.098, col)
			b.disc(map.call(head + Vector2(-0.03, 0.03)), u * 0.05, Color(deep, 0.65))
			b.disc(map.call(head + Vector2(0.03, -0.035)), u * 0.02, lit)
		Rules.ROOK:
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.16, -0.14), Vector2(0.16, -0.14)]), map), u * 0.022, line)
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.165, 0.2), Vector2(0.165, 0.2)]), map), u * 0.016, Color(line, 0.7))
		Rules.BISHOP:
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(0.075, -0.235), Vector2(-0.01, -0.13)]), map), u * 0.028, line)
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.04, -0.17), Vector2(0.04, -0.17)]), map), u * 0.024, line)
			b.disc(map.call(Vector2(0.0, -0.385)), u * 0.05, line)
			b.disc(map.call(Vector2(0.0, -0.385)), u * 0.03, col)
		Rules.QUEEN:
			for tip: Vector2 in [Vector2(-0.285, -0.31), Vector2(-0.14, -0.36), Vector2(0.0, -0.385), Vector2(0.14, -0.36), Vector2(0.285, -0.31)]:
				b.disc(map.call(tip), u * 0.047, line)
				b.disc(map.call(tip), u * 0.027, col)
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.12, -0.13), Vector2(0.12, -0.13)]), map), u * 0.02, line)
		Rules.KING:
			var cross := Vector2(0.0, -0.2)
			var tip := Vector2(0.0, -0.45)
			b.stroke(ChessPiece._mapped(PackedVector2Array([cross, tip]), map), u * 0.075, line)
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.085, -0.355), Vector2(0.085, -0.355)]), map), u * 0.075, line)
			b.stroke(ChessPiece._mapped(PackedVector2Array([cross, tip + Vector2(0.0, 0.012)]), map), u * 0.03, col)
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.073, -0.355), Vector2(0.073, -0.355)]), map), u * 0.03, col)
			b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.13, -0.13), Vector2(0.13, -0.13)]), map), u * 0.02, line)

## The knight: the horse's head on the same foot, looking left as a set's
## does, an eye, a nostril and the mane's cuts.
func _knight(b: Face.Builder, shape: Callable, map: Callable, u: float, col: Color, deep: Color, line: Color, lit: Color) -> void:
	var outline := PackedVector2Array([Vector2(-0.29, 0.4), Vector2(-0.29, 0.33), Vector2(-0.23, 0.28),
		Vector2(-0.13, 0.16), Vector2(-0.03, 0.03), Vector2(-0.015, -0.035), Vector2(-0.1, -0.015),
		Vector2(-0.17, 0.05), Vector2(-0.225, 0.075), Vector2(-0.285, 0.035), Vector2(-0.285, -0.005),
		Vector2(-0.19, -0.115), Vector2(-0.12, -0.2), Vector2(-0.07, -0.285), Vector2(-0.065, -0.375),
		Vector2(0.0, -0.31), Vector2(0.075, -0.345), Vector2(0.09, -0.29),
		Vector2(0.2, -0.205), Vector2(0.27, -0.06), Vector2(0.275, 0.1), Vector2(0.23, 0.28),
		Vector2(0.29, 0.33), Vector2(0.29, 0.4)])
	var body: PackedVector2Array = shape.call(outline)
	b.polygon(body, col)
	for part: PackedVector2Array in ChessPiece._crescent("classic_knight_shade", outline, Vector2(-0.06, -0.015)):
		b.polygon(shape.call(part), Color(deep, 0.75))
	b.stroke(body, u * 0.03, line, true)
	b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.25, 0.285), Vector2(0.24, 0.285)]), map), u * 0.018, Color(line, 0.8))
	# the eye and the nostril
	b.disc(map.call(Vector2(-0.09, -0.155)), u * 0.032, line)
	b.disc(map.call(Vector2(-0.235, 0.015)), u * 0.016, line)
	# the mane's cuts, down the neck
	for k in 3:
		var at := Vector2(0.115 + 0.04 * k, -0.15 + 0.115 * k)
		b.stroke(ChessPiece._mapped(Face.Builder.bezier2(at, at + Vector2(0.015, 0.045), at + Vector2(-0.045, 0.085), 5), map), u * 0.02, Color(line, 0.85))
	b.stroke(ChessPiece._mapped(PackedVector2Array([Vector2(-0.02, -0.03), Vector2(0.01, -0.09)]), map), u * 0.018, Color(lit, 0.8))

# --- motion ---

func move_time(_type: int, from: Vector2, to: Vector2) -> float:
	return 0.13 + 0.022 * from.distance_to(to)

func move_pose(_type: int, from: Vector2, to: Vector2, u: float) -> Pose:
	return Pose.at_cell(from.lerp(to, _ease_in_out(u)))

func contact_at(_type: int) -> float:
	return 0.95

func takeoff_cue(_type: int) -> String:
	return ""

func knock_time() -> float:
	return 0.18

func knock_pose(from: Vector2, to: Vector2, _dir: Vector2, u: float, tray_scale: float) -> Pose:
	var p := Pose.at_cell(from.lerp(to, _ease_in_out(u)))
	p.scale = lerpf(1.0, tray_scale, u)
	return p

func tremble_time() -> float:
	return 0.3

func enter_time() -> float:
	return 0.16

func promote_time() -> float:
	return 0.2

func topple_time() -> float:
	return 0.5
