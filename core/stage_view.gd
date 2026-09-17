class_name StageView
extends Control

## A Control whose picture is a Node3D on the shared stage. It turns its own
## rectangle into a camera frame and its touches into board-plane hits, and
## knows nothing about puzzles or turns: PuzzleBase3D and TurnBase both stand
## on it.
##
## Nothing mounts by itself. A subclass calls stage_enter() from its own
## _ready and stage_exit() from its own _exit_tree, so a Control that
## inherits this and wants no board pays nothing for it.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 2.1.

const BoardMath = preload("res://core/board_math.gd")

var board: Node3D
var _stage: Node
var _pressing := false

# --- to override ---
## Columns and rows of the board, in cells.
func board_size() -> Vector2i: return Vector2i(1, 1)
## How tall the tallest piece is; frames the camera.
func board_height() -> float: return 0.5
## Height of the surface taps land on (the tile tops).
func plane_height() -> float: return 0.0
## The angle this board's face wants to be seen at, in degrees above the
## horizontal; NAN takes the island's own (Stage.DEFAULT_FACE). The camera
## itself never moves off Stage.CAMERA_PITCH -- the board leans to bring its
## face around to that angle instead. Only a board whose pieces mean
## something by their height should ask for a shallower one and lean less
## (see Stage.fit_camera): Balance, whose beams tilt and whose discs stack.
func board_pitch() -> float: return NAN
## Camera projection this board wants, a Camera3D.PROJECTION_* value. Depth is
## the default; a board of stacked blocks reads as a diorama only when its
## parallel edges stay parallel, so it asks for PROJECTION_ORTHOGONAL.
func board_projection() -> int: return Camera3D.PROJECTION_PERSPECTIVE
## Camera yaw this board wants, in degrees around Y. Zero is the island's own,
## which is what every board that does not care should say: the rig keeps
## whatever it was last given, so a board that left the yaw alone would inherit
## the 45 degrees Pipes' island is looked at from and come out standing on its
## corner. A board that can be turned answers with the stop it is showing, so
## that the re-fit after a resize agrees with where the turn left the camera;
## NAN still means "leave it alone" for anything that wants that.
func board_yaw() -> float: return 0.0
## Extra world units framed around the tiles on each side (a platform lip).
func board_margin() -> float: return 0.0
## Depth framed below the tile plane (the platform's thickness).
func board_depth() -> float: return 0.0
## Whether a touch reaches the on_board_* hooks. A finished board says no.
func accepts_input() -> bool: return true
func on_board_press(_hit: Vector3) -> void: pass
func on_board_drag(_hit: Vector3) -> void: pass
func on_board_release(_hit: Vector3) -> void: pass
# -------------------

## Takes a board onto the stage and starts following this control's rect.
func stage_enter(board_name: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	board = Node3D.new()
	board.name = board_name
	_stage = get_tree().get_first_node_in_group("stage")
	if _stage != null:
		_stage.mount(board)
		# Nothing behind a board for now but flat colour; see Stage.show_setting.
		_stage.show_setting(false)
	else:
		push_warning("StageView: no Stage in group 'stage'; %s will not render and taps will miss" % board.name)
		add_child(board)
	resized.connect(_refit)
	_refit()

## Hands the stage back the way it was found: the menu campsite keeps its
## island.
func stage_exit() -> void:
	if _stage != null and is_instance_valid(_stage):
		_stage.show_setting(true)
	if is_instance_valid(board):
		if _stage != null and is_instance_valid(_stage):
			_stage.unmount(board)
		board.queue_free()

func board_aabb() -> AABB:
	var s := board_size()
	var box := BoardMath.board_aabb(s.x, s.y, board_height())
	var m := board_margin()
	var d := board_depth()
	return AABB(box.position - Vector3(m, d, m), box.size + Vector3(2.0 * m, d, 2.0 * m))

## This control's rectangle in viewport pixels, the space the camera projects into.
func viewport_rect() -> Rect2:
	return get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)

func _refit() -> void:
	if _stage == null or not is_inside_tree():
		return
	_stage.fit_camera(board_aabb(), viewport_rect(), board_pitch(), board_projection(), board_yaw())

func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()

## Board-plane point under a control-local position, or null when the ray
## misses. The board leans (see Stage._lean), so the plane at plane_height()
## is horizontal in the *board's* space and nowhere else: the ray is taken
## into that space before it is intersected.
func local_to_board(local: Vector2) -> Variant:
	var cam := _camera()
	if cam == null:
		return null
	var vp := get_global_transform_with_canvas() * local
	var inv := board.global_transform.affine_inverse()
	var origin: Vector3 = inv * cam.project_ray_origin(vp)
	var dir: Vector3 = (inv.basis * cam.project_ray_normal(vp)).normalized()
	return BoardMath.ray_plane(origin, dir, plane_height())

## The picking ray through a control-local position, as
## [origin: Vector3, direction: Vector3] in the *board's* own space, or [] when
## there is no camera.
func local_ray(local: Vector2) -> Array:
	var cam := _camera()
	if cam == null:
		return []
	var vp := get_global_transform_with_canvas() * local
	var inv := board.global_transform.affine_inverse()
	return [inv * cam.project_ray_origin(vp),
		(inv.basis * cam.project_ray_normal(vp)).normalized()]

## Control-local position of a board-space point; the inverse of
## local_to_board. The point goes out through the board's transform before it
## is projected, because the board leans.
func board_to_local(point: Vector3) -> Vector2:
	var cam := _camera()
	if cam == null:
		return Vector2.INF
	var world: Vector3 = board.global_transform * point
	return get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(world)

## Touch events only. The project emulates touch from mouse, and the viewport
## hands a control both the mouse event and the emulated touch, so listening
## to both would fire twice per click.
func _gui_input(event: InputEvent) -> void:
	if not accepts_input():
		return
	if event is InputEventScreenTouch:
		var hit = local_to_board(event.position)
		if event.pressed:
			if hit == null:
				return
			_pressing = true
			on_board_press(hit)
		elif _pressing:
			_pressing = false
			if hit != null:
				on_board_release(hit)
	elif event is InputEventScreenDrag and _pressing:
		var hit = local_to_board(event.position)
		if hit != null:
			on_board_drag(hit)
