extends RefCounted

## A chess skin: how the pieces look and how they move. The board
## (versus/chess_board.gd) owns the rules' truth, the clock and the order
## things happen in; a skin only answers "draw this piece" and "where is
## this piece, and how is it standing, this far into this moment". So a new
## set of pieces -- a skin bought later, with its own walk, leap and fall --
## is one subclass and nothing else.
##
## This base is a plain working skin: round tokens that slide. The house
## skin is versus/chess_skin_garden.gd. `ChessSkin.named(id)` picks one.
##
## Units. A pose's `at` is where the piece's foot stands, in display cells
## (column, row, fractional, row 0 the far side); `lift` is height above the
## board in cells. A mesh is built with its origin at the foot, in pixels,
## for a cell of `s` pixels, so the board turns and squashes it about the
## foot with one transform and never rebuilds it to move it.

const Rules = preload("res://versus/chess_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

## A piece's face, one mesh each: the board picks one per frame.
enum { F_OPEN, F_BLINK, F_JOY, F_WORRY, F_DIZZY, F_SLEEP }

## How a piece stands at one instant.
class Pose:
	var at := Vector2.ZERO
	var lift := 0.0
	var squash := Vector2.ONE
	var tilt := 0.0
	var scale := 1.0
	var alpha := 1.0
	## -1 or 1 to face that way (a knight looks where it leaps); 0 keeps the
	## piece's own.
	var look := 0.0

	static func at_cell(p: Vector2) -> Pose:
		var pose := Pose.new()
		pose.at = p
		return pose

static func named(id: String) -> RefCounted:
	match id:
		"plain":
			return load("res://versus/chess_skin.gd").new()
		_:
			return load("res://versus/chess_skin_garden.gd").new()

func id() -> String:
	return "plain"

# --- drawing ---

## The foot sits this far below a square's centre, in cells: the board
## stands a piece's foot here.
func foot_drop() -> float:
	return 0.2

## Appends a piece to `b`, foot at the origin, in pixels for a cell of `s`.
## `side` is the player's (0, cream) or the computer's (1, rose), never
## white or black: the player's pieces look the same whichever colour they
## move as. `look` -1 faces left, 1 right.
func build(b: Face.Builder, type: int, side: int, s: float, face: int, _look: float) -> void:
	var col := Pal.KNIGHT_CREAM if side == 0 else Pal.KNIGHT_ROSE
	var deep := Pal.KNIGHT_CREAM_LINE if side == 0 else Pal.KNIGHT_ROSE_LINE
	var r := s * (0.26 + 0.02 * type)
	var c := Vector2(0.0, -r * 0.8)
	b.disc(c + Vector2(0.0, r * 0.18), r, deep)
	b.disc(c, r, col)
	for i in type:
		var a := TAU * i / maxf(type, 1) - PI * 0.5
		b.disc(c + Vector2.from_angle(a) * r * 0.55, s * 0.035, deep)
	if face == F_DIZZY:
		b.stroke(Face.Builder.ring(c, r * 0.4, r * 0.4), s * 0.02, deep, true)

## The soft shadow under a piece, as a fraction of a cell across.
func shadow_size() -> Vector2:
	return Vector2(0.32, 0.1)

# --- motion ---

## Seconds a move from `from` to `to` (display cells) takes.
func move_time(_type: int, from: Vector2, to: Vector2) -> float:
	return 0.18 + 0.05 * from.distance_to(to)

## The piece `u` of the way (0 to 1) through its move.
func move_pose(_type: int, from: Vector2, to: Vector2, u: float) -> Pose:
	var e := _ease_in_out(u)
	var p := Pose.at_cell(from.lerp(to, e))
	p.lift = 0.15 * sin(PI * u)
	return p

## The fraction of a move at which the piece reaches what it takes, so the
## taken piece is knocked away at the touch and not before.
func contact_at(_type: int) -> float:
	return 0.85

## The sound a move starts with and the one it lands with (Fx2D cues in
## assets/sfx/chess/); "" for none.
func takeoff_cue(_type: int) -> String:
	return "lift"

func land_cue(_type: int) -> String:
	return "place"

## Whether a landing throws up a little dust.
func lands_with_dust(_type: int) -> bool:
	return false

## A taken piece's flight from `from` to its place in the tray `to`.
func knock_time() -> float:
	return 0.6

func knock_pose(from: Vector2, to: Vector2, _dir: Vector2, u: float, tray_scale: float) -> Pose:
	var p := Pose.at_cell(from.lerp(to, _ease_in_out(u)))
	p.lift = 0.6 * sin(PI * u)
	p.scale = lerpf(1.0, tray_scale, u)
	return p

## At rest. `clock` is the board's time in seconds, `phase` a per-piece
## offset so the set does not breathe in step; `selected` is the piece the
## player has picked up.
func idle_pose(_type: int, at: Vector2, _clock: float, _phase: float, selected: bool) -> Pose:
	var p := Pose.at_cell(at)
	p.lift = 0.12 if selected else 0.0
	return p

## A refused tap: the piece shakes its head.
func shiver_time() -> float:
	return 0.35

func shiver_pose(at: Vector2, u: float) -> Pose:
	return Pose.at_cell(at + Vector2(sin(u * PI * 6.0) * 0.05 * (1.0 - u), 0.0))

## The king in check trembles for a moment.
func tremble_time() -> float:
	return 0.7

func tremble_pose(at: Vector2, u: float) -> Pose:
	return shiver_pose(at, u)

## The mated king goes over, `dir` -1 to the left or 1 to the right.
func topple_time() -> float:
	return 0.7

func topple_pose(at: Vector2, u: float, dir: float) -> Pose:
	var p := Pose.at_cell(at)
	p.tilt = dir * PI * 0.5 * _ease_in_out(u)
	return p

## The winning side's hop, `u` running 0 to 1 once.
func cheer_time() -> float:
	return 0.5

func cheer_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.lift = 0.3 * sin(PI * u)
	return p

## A pawn turning into what it was promoted to: the board swaps the type at
## the half.
func promote_time() -> float:
	return 0.6

func promote_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.squash = Vector2(absf(cos(u * PI)), 1.0)
	return p

## The set coming onto the board at the start of a game: `u` 0 to 1 for one
## piece, the board staggers them.
func enter_time() -> float:
	return 0.4

func enter_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.alpha = u
	return p

## Now and then a resting piece fidgets, one at a time: seconds between two
## (0 for never), how long one lasts, and the pose `u` of the way through.
func fidget_gap() -> Vector2:
	return Vector2.ZERO

func fidget_time(_type: int) -> float:
	return 0.6

func fidget_pose(type: int, at: Vector2, u: float) -> Pose:
	return idle_pose(type, at, 0.0, 0.0, false)

## How long a blink lasts and how long between them, in seconds.
func blink_time() -> float:
	return 0.12

func blink_gap() -> Vector2:
	return Vector2(3.0, 7.0)

static func _ease_in_out(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)

## Overshoots a little past 1 and settles: a mark or a badge popping in.
static func _back_out_k(u: float) -> float:
	var c := 1.7
	var t := u - 1.0
	return 1.0 + (c + 1.0) * t * t * t + c * t * t
