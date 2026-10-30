extends "res://versus/chess_skin_classic.gd"

## The clockwork set: brass against gunmetal, a real model a piece
## (art/chess_clockwork.blend, versus/models/clockwork/), each with a wind-up
## key turning in its side and a gear on its front. A move ticks along in
## notches. A key follows its own player's clock: it slows as the time runs
## down and rattles through the last ten seconds, the one set that plays the
## game with you.
##
## The classic drawing it inherits stays for what is not on the board's 3D
## layer: the queued moves' ghosts, the promotion picker, the tutorial.

const NOTCHES := 5
const RATTLE_AT := 10.0
const BRASS_BODY := Color("e0a94a")
const BRASS_TRIM := Color("8a5a1e")
const GUN_BODY := Color("74808b")
const GUN_TRIM := Color("2f3840")
const STEEL := Color("d8d3c6")
const BRASS_GEAR := Color("6e4515")
const GUN_GEAR := Color("c2ccd4")
const DARK := Color("2c2118")

func id() -> String:
	return "clockwork"

## The model's round base shows under the camera's tilt, so the foot stands
## higher than the flat set's, clear of the square's edge.
func foot_drop() -> float:
	return 0.3

func model_dir() -> String:
	return "res://versus/models/clockwork"

func model_hz() -> float:
	return 10.0

func model_tint(material: String, seat: int) -> Color:
	var brass := seat == 0
	match material:
		"Body":
			return BRASS_BODY if brass else GUN_BODY
		"Trim":
			return BRASS_TRIM if brass else GUN_TRIM
		"Steel":
			return STEEL
		"Gear":
			return BRASS_GEAR if brass else GUN_GEAR
	return DARK

func model_parts(piece: Node3D) -> Array:
	return [piece.find_child("*_key", true, false), piece.find_child("*_gear", true, false)]

## `left` and `full` are the wearer's clock in seconds, `full` 0 for a game
## with none: the key then turns at its easy rate.
func model_tick(parts: Array, dt: float, left: float, full: float) -> void:
	var rate := 1.2
	if full > 0.0:
		rate = 0.5 + 2.5 * clampf(left / full, 0.0, 1.0)
		if left <= RATTLE_AT:
			rate = 11.0
	parts[0].rotation.x += rate * dt
	parts[1].rotation.z += rate * dt * 0.6

func move_time(_type: int, from: Vector2, to: Vector2) -> float:
	return 0.26 + 0.05 * from.distance_to(to)

func move_pose(type: int, from: Vector2, to: Vector2, u: float) -> Pose:
	var f := u * NOTCHES
	var notch := floorf(f)
	var v := clampf((notch + _ease_in_out(clampf((f - notch) * 2.0, 0.0, 1.0))) / NOTCHES, 0.0, 1.0)
	var p := Pose.at_cell(from.lerp(to, v))
	p.lift = sin(PI * v) * (0.42 if type == Rules.KNIGHT else 0.06)
	p.tilt = sin(f * TAU) * 0.03
	return p

## A model takes no fade, so the set stands up onto the board instead.
func enter_pose(at: Vector2, u: float) -> Pose:
	var p := Pose.at_cell(at)
	p.squash = Vector2(1.0, _back_out_k(u))
	p.alpha = 1.0 if u > 0.0 else 0.0
	return p
