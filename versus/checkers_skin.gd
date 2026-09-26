extends RefCounted

## A checkers skin: how the pieces look and how they move. The board
## (versus/checkers_board.gd) owns the rules' truth, the clock, the order
## things happen in, where every piece's eyes are looking, and everything
## drawn round the pieces (marks, ripples, the trays); a skin only answers
## "draw this piece" and "where is this piece, and how is it lying, this far
## into this moment". A new set -- bought later, with its own hop, leap and
## fall -- is one subclass and nothing else.
##
## This base is a plain working skin: flat discs that slide. The house skin
## is versus/checkers_skin_garden.gd. `CheckersSkin.named(id)` picks one.
##
## The board is seen from straight above. A pose's `at` is the piece's
## centre in display cells (column, row, fractional, row 0 the far side);
## `lift` is height in cells, which the board draws as the piece growing,
## rising a little up the screen and its shadow sliding away. `flip` turns
## the piece over about the screen's horizontal axis (PI lies face down, and
## the board draws the underside); `spin` turns it in the board's plane. A
## mesh is built centred on the origin, in pixels, for a cell of `s`
## pixels, so the board moves, turns and squashes it with one transform and
## never rebuilds it to move it.

const Rules = preload("res://versus/checkers_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

## A piece's face, one mesh each: the board picks one per frame. BRAVE is
## the look on a piece in the middle of a capture.
enum { F_OPEN, F_BLINK, F_JOY, F_WORRY, F_DIZZY, F_SLEEP, F_BRAVE }

## How a piece lies at one instant.
class Pose:
	var at := Vector2.ZERO
	var lift := 0.0
	var squash := Vector2.ONE
	var spin := 0.0
	var flip := 0.0
	var scale := 1.0
	var alpha := 1.0
	## Where the eyes look, overriding the board's choice; zero leaves it
	## to the board.
	var gaze := Vector2.ZERO

	static func at_cell(p: Vector2) -> Pose:
		var pose := Pose.new()
		pose.at = p
		return pose

static func named(id: String) -> RefCounted:
	match id:
		"plain":
			return load("res://versus/checkers_skin.gd").new()
		_:
			return load("res://versus/checkers_skin_garden.gd").new()

func id() -> String:
	return "plain"

# --- drawing ---

## A piece's radius, in cells.
func radius() -> float:
	return 0.36

## Appends what shows of a piece below its top -- its edge, and for a
## king the lower piece of the stack -- to `b`, centred on the origin, in
## pixels for a cell of `s`. The board draws it unturned, so a twirl does
## not swing the thickness round the piece.
func build_base(b: Face.Builder, _type: int, side: int, s: float) -> void:
	var deep := Pal.KNIGHT_CREAM_DEEP if side == 0 else Pal.KNIGHT_ROSE_DEEP
	b.disc(Vector2(0.0, s * 0.05), s * radius(), deep)

## Appends a piece's top to `b`, centred on the origin, in pixels for a cell
## of `s`: it turns with the piece. `side` is the player's (0, cream) or the
## computer's (1, rose), never light or dark: the player's pieces look the
## same whichever colour they move as. `gaze` is where the eyes look, each
## of x and y -1, 0 or 1.
func build(b: Face.Builder, type: int, side: int, s: float, _face: int, _gaze: Vector2i) -> void:
	var col := Pal.KNIGHT_CREAM if side == 0 else Pal.KNIGHT_ROSE
	var deep := Pal.KNIGHT_CREAM_DEEP if side == 0 else Pal.KNIGHT_ROSE_DEEP
	var r := s * radius()
	b.disc(Vector2.ZERO, r, col)
	b.stroke(Face.Builder.ring(Vector2.ZERO, r * 0.7, r * 0.7), s * 0.02, deep, true)
	if type == Rules.KING:
		b.disc(Vector2.ZERO, r * 0.3, Pal.CROWN)

## The piece's underside, seen when it lies face down or is turning over;
## the base is drawn under it as under the top.
func build_under(b: Face.Builder, _type: int, side: int, s: float) -> void:
	var deep := Pal.KNIGHT_CREAM_DEEP if side == 0 else Pal.KNIGHT_ROSE_DEEP
	b.disc(Vector2.ZERO, s * radius(), deep)

## The crown a man is crowned with, alone, centred on the origin: it drops
## onto the man and the board swaps the man for a king as it lands.
func build_crown(b: Face.Builder, _side: int, s: float) -> void:
	b.disc(Vector2.ZERO, s * radius() * 0.3, Pal.CROWN)

## Where the crown sits on a crowned piece: pixels from its centre.
func crown_seat(_s: float) -> Vector2:
	return Vector2.ZERO

## The soft shadow under a piece, as a fraction of a cell across.
func shadow_size() -> Vector2:
	return Vector2(0.4, 0.36)

# --- motion ---

## A quiet move from `from` to `to` (display cells).
func step_time(_type: int, from: Vector2, to: Vector2) -> float:
	return 0.18 + 0.05 * from.distance_to(to)

func step_pose(_type: int, from: Vector2, to: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(from.lerp(to, _ease_in_out(u)))
	p.lift = 0.12 * sin(PI * u)
	return p

## One leg of a capture, `leg` of `legs` (0-based), over what it takes.
func jump_time(_type: int, from: Vector2, to: Vector2, _leg: int) -> float:
	return 0.25 + 0.04 * from.distance_to(to)

func jump_pose(_type: int, from: Vector2, to: Vector2, u: float, _leg: int, _legs: int) -> Pose:
	var p := Pose.at_cell(from.lerp(to, _ease_in_out(u)))
	p.lift = 0.5 * sin(PI * u)
	return p

## The fraction of a leg at which the piece is over a point `frac` of the
## way along it -- where what it takes lies -- so the taken piece is
## squashed then and not before.
func jump_contact(frac: float) -> float:
	var t := 0.5 - sin(asin(clampf(1.0 - 2.0 * frac, -1.0, 1.0)) / 3.0)
	return t

## A taken piece's trip from `from` to its place in the tray `to`, pushed
## along `dir`, shrinking to `tray_scale`.
func knock_time() -> float:
	return 0.6

func knock_pose(from: Vector2, to: Vector2, _dir: Vector2, u: float, tray_scale: float) -> Pose:
	var p := Pose.at_cell(from.lerp(to, _ease_in_out(u)))
	p.lift = 0.6 * sin(PI * u)
	p.scale = lerpf(1.0, tray_scale, u)
	return p

## Crowning: the crown's fall onto a piece at the origin (`at` 0, `lift`
## in cells above its seat), and the fraction at which it lands.
func crown_time() -> float:
	return 0.5

func crown_land() -> float:
	return 0.6

func crown_pose(u: float) -> Pose:
	var p := Pose.new()
	p.lift = 2.0 * (1.0 - clampf(u / crown_land(), 0.0, 1.0))
	return p

## The piece being crowned, while the crown falls onto it.
func crowned_pose(at: Vector2, _u: float) -> Pose:
	return Pose.at_cell(at)

## At rest. `clock` is the board's time in seconds, `phase` a per-piece
## offset so the set does not breathe in step; `selected` is the piece the
## player has picked up.
func idle_pose(_type: int, at: Vector2, _clock: float, _phase: float, selected: bool) -> Pose:
	var p := Pose.at_cell(at)
	p.lift = 0.15 if selected else 0.0
	return p

## Now and then one resting piece fidgets: seconds between two (zero for
## never), how long one lasts, and the pose. `kind` is picked by the board
## at random below fidget_kinds(), so a set can have several.
func fidget_gap() -> Vector2:
	return Vector2.ZERO

func fidget_kinds() -> int:
	return 1

func fidget_time(_type: int, _kind: int) -> float:
	return 0.6

func fidget_pose(type: int, at: Vector2, _u: float, _kind: int) -> Pose:
	return idle_pose(type, at, 0.0, 0.0, false)

## A refused tap: the piece shakes its head.
func shiver_time() -> float:
	return 0.35

func shiver_pose(at: Vector2, u: float) -> Pose:
	return Pose.at_cell(at + Vector2(sin(u * PI * 6.0) * 0.05 * (1.0 - u), 0.0))

## A piece that must capture, pointed out: a nudge toward what it takes.
func nudge_time() -> float:
	return 0.5

func nudge_pose(at: Vector2, dir: Vector2, u: float) -> Pose:
	return Pose.at_cell(at + dir * 0.1 * sin(PI * u))

## The winners' hop, once, `u` 0 to 1.
func cheer_time() -> float:
	return 0.5

func cheer_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.lift = 0.3 * sin(PI * u)
	return p

## The losers turn over, one by one; they stay face down after.
func yield_time() -> float:
	return 0.5

func yield_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.flip = PI * _ease_in_out(u)
	return p

## The set coming onto the board at the start of a game: `u` 0 to 1 for one
## piece, the board staggers them.
func enter_time() -> float:
	return 0.4

func enter_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.alpha = u
	return p

## How long a blink lasts and how long between them, in seconds.
func blink_time() -> float:
	return 0.12

func blink_gap() -> Vector2:
	return Vector2(3.0, 7.0)

## The sounds a move starts and lands with (Fx2D cues in
## assets/sfx/checkers/); "" for none. `capture` says it is a jump.
func takeoff_cue(_type: int, capture: bool) -> String:
	return "hop" if capture else "lift"

func land_cue(_type: int, _capture: bool) -> String:
	return "place"

## Whether a landing throws up a little dust.
func lands_with_dust(_type: int, capture: bool) -> bool:
	return capture

static func _ease_in_out(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)

## Overshoots a little past 1 and settles: a mark or a badge popping in.
static func _back_out_k(u: float) -> float:
	var c := 1.7
	var t := u - 1.0
	return 1.0 + (c + 1.0) * t * t * t + c * t * t
