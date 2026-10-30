extends "res://versus/checkers_skin.gd"

## The classic set: turned wooden discs on a wooden board, seen from above,
## in their true colours, no faces. A move is a quick slide, a capture a clean
## jump. The default set; the garden's is versus/checkers_skin_garden.gd.

const LIGHT_FILL := Color("f0e0c0")
const LIGHT_DEEP := Color("c7a878")
const LIGHT_EDGE := Color("9c7c52")
const DARK_FILL := Color("3a2a22")
const DARK_DEEP := Color("241813")
const DARK_EDGE := Color("140d0a")
const GOLD := Color("e2b33f")
const GOLD_DEEP := Color("9a6f1e")

func id() -> String:
	return "classic"

func cartoon() -> bool:
	return false

func true_colours() -> bool:
	return true

func frame() -> float:
	return 0.12

func radius() -> float:
	return 0.4

func shadow_size() -> Vector2:
	return Vector2(0.42, 0.4)

static func _fill(side: int) -> Color:
	return LIGHT_FILL if side == 0 else DARK_FILL

static func _deep(side: int) -> Color:
	return LIGHT_DEEP if side == 0 else DARK_DEEP

static func _edge(side: int) -> Color:
	return LIGHT_EDGE if side == 0 else DARK_EDGE

## The disc's side showing under the top; a king is two discs, stacked.
func build_base(b: Face.Builder, type: int, side: int, s: float) -> void:
	var r := s * radius()
	if type == Rules.KING:
		b.disc(Vector2(0.0, s * 0.11), r, _edge(side))
		b.disc(Vector2(0.0, s * 0.08), r * 0.985, _deep(side))
	b.disc(Vector2(0.0, s * 0.045), r, _edge(side))

func _top(type: int, s: float) -> Vector2:
	return Vector2(0.0, -s * 0.03) if type == Rules.KING else Vector2.ZERO

func build(b: Face.Builder, type: int, side: int, s: float, _face: int, _gaze: Vector2i) -> void:
	var r := s * radius()
	var c := _top(type, s)
	var lit := Color.WHITE if side == 0 else Color("a8927f")
	b.disc(c, r, _deep(side))
	b.disc(c, r * 0.95, _fill(side))
	# the turned rings, and the light on the rim
	b.stroke(Face.Builder.ring(c, r * 0.76, r * 0.76), s * 0.022, _deep(side), true)
	b.stroke(Face.Builder.ring(c + Vector2(s * 0.004, s * 0.006), r * 0.72, r * 0.72), s * 0.01, Color(lit, 0.28), true)
	b.stroke(Face.Builder.ring(c, r * 0.5, r * 0.5), s * 0.014, Color(_deep(side), 0.8), true)
	b.stroke(Face.Builder.arc_points(c, r * 0.87, PI * 1.05, PI * 1.6), s * 0.022, Color(lit, 0.45))
	if type == Rules.KING:
		_crown(b, c, r * 0.46)

func build_under(b: Face.Builder, _type: int, side: int, s: float) -> void:
	var r := s * radius()
	b.disc(Vector2.ZERO, r, _edge(side))
	b.disc(Vector2.ZERO, r * 0.9, _deep(side))

func build_crown(b: Face.Builder, _side: int, s: float) -> void:
	_crown(b, Vector2.ZERO, s * radius() * 0.46)

func crown_seat(s: float) -> Vector2:
	return Vector2(0.0, -s * 0.03)

## A gold crown laid into the top: five points on a band.
static func _crown(b: Face.Builder, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in [Vector2(-1.0, 0.72), Vector2(-1.0, -0.42), Vector2(-0.5, 0.08), Vector2(0.0, -0.72),
			Vector2(0.5, 0.08), Vector2(1.0, -0.42), Vector2(1.0, 0.72)]:
		pts.append(c + p * r)
	var shade := PackedVector2Array()
	for q in pts:
		shade.append(q + Vector2(0.0, r * 0.1))
	b.polygon(shade, GOLD_DEEP)
	b.polygon(pts, GOLD)
	b.stroke(PackedVector2Array([c + Vector2(-0.92, 0.46) * r, c + Vector2(0.92, 0.46) * r]), r * 0.1, GOLD_DEEP)
	for p: Vector2 in [Vector2(-1.0, -0.5), Vector2(0.0, -0.82), Vector2(1.0, -0.5)]:
		b.disc(c + p * r, r * 0.13, Color("fff0b8"))

func step_time(_type: int, from: Vector2, to: Vector2) -> float:
	return 0.16 + 0.035 * from.distance_to(to)

func jump_time(_type: int, from: Vector2, to: Vector2, _leg: int) -> float:
	return 0.2 + 0.035 * from.distance_to(to)

func knock_time() -> float:
	return 0.34

func crown_time() -> float:
	return 0.4

## No dust on a wooden board, and the capture's own sound is the mark of it.
func lands_with_dust(_type: int, _capture: bool) -> bool:
	return false
